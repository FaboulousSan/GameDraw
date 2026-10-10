import type { Game, GameLibrary } from "./types";

// Logique de tirage — côté frontend, en fonctions PURES (aucune I/O) :
// - testable unitairement sans Tauri
// - la Phase 2 (animations) a besoin du résultat AVANT de jouer l'animation,
//   et d'un échantillon de noms du pool (bandeau, cartes en cascade)
// Le backend Rust ne fait plus que la persistance disque.

export interface DrawResult {
  /** Le jeu tiré. */
  game: Game;
  /** Bibliothèque mise à jour (dejaFait, éventuel reset de cycle) — à persister par l'appelant. */
  library: GameLibrary;
  /** true si le pool était épuisé et a été réinitialisé (nouveau cycle). */
  cycleReset: boolean;
}

/**
 * Tire un jeu au hasard parmi ceux non encore faits (`dejaFait === false`).
 * Si tous les jeux ont déjà été faits, réinitialise le pool (nouveau cycle)
 * avant de tirer — comportement identique au script PowerShell.
 *
 * `eviterRepetitions` (Phase 7, réglage Options > Tirage) : à `false`, le
 * tirage devient un pur hasard sur toute la bibliothèque à chaque fois —
 * `dejaFait` n'est ni consulté ni modifié.
 *
 * Ne mute PAS la bibliothèque passée en argument : retourne une copie mise
 * à jour, que l'appelant persiste via api.saveGames().
 */
export function drawFromLibrary(library: GameLibrary, eviterRepetitions = true): DrawResult | null {
  if (library.jeux.length === 0) return null;

  if (!eviterRepetitions) {
    const chosen = library.jeux[Math.floor(Math.random() * library.jeux.length)];
    return { game: chosen, library, cycleReset: false };
  }

  let jeux = library.jeux;
  let cycleReset = false;

  let pool = jeux.filter((j) => !j.dejaFait);
  if (pool.length === 0) {
    jeux = jeux.map((j) => ({ ...j, dejaFait: false }));
    pool = jeux;
    cycleReset = true;
  }

  const chosen = pool[Math.floor(Math.random() * pool.length)];
  const updated = jeux.map((j) => (j.id === chosen.id ? { ...j, dejaFait: true } : j));

  return {
    game: { ...chosen, dejaFait: true },
    library: { ...library, jeux: updated },
    cycleReset,
  };
}

/**
 * Échantillon de noms du pool pour habiller une animation (bandeau défilant,
 * cartes en cascade…) : `count` noms au hasard, en excluant éventuellement le
 * résultat réel (qui sera ajouté en dernier par l'animation elle-même).
 */
export function sampleNames(library: GameLibrary, count: number, excludeId?: string): string[] {
  const candidats = library.jeux.filter((j) => j.id !== excludeId).map((j) => j.nom);
  // Fisher-Yates partiel
  const arr = [...candidats];
  for (let i = arr.length - 1; i > 0; i--) {
    const k = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[k]] = [arr[k], arr[i]];
  }
  const sample = arr.slice(0, count);
  // Si la bibliothèque est plus petite que count, on répète pour remplir
  while (sample.length < count && candidats.length > 0) {
    sample.push(candidats[Math.floor(Math.random() * candidats.length)]);
  }
  return sample;
}

// --- Filtres de tirage (v24) ------------------------------------------------
//
// Restreindre le pool AVANT le tirage : par statut, par tag, ou en excluant
// les jeux déjà terminés/abandonnés. Séparé de drawFromLibrary() pour rester
// des fonctions pures composables (et testables indépendamment).

export interface FiltresTirage {
  /** Ids de statuts autorisés — vide = tous. */
  statuts: string[];
  /** Tags requis (au moins un) — vide = pas de filtre par tag. */
  tags: string[];
  /** Exclut les jeux marqués Terminé ou Abandonné. */
  exclureTermines: boolean;
  /** Ne garde que les jeux marqués "envie de faire". */
  seulementEnvie: boolean;
}

export const FILTRES_VIDES: FiltresTirage = {
  statuts: [],
  tags: [],
  exclureTermines: false,
  seulementEnvie: false,
};

export function filtresActifs(f: FiltresTirage): boolean {
  return f.statuts.length > 0 || f.tags.length > 0 || f.exclureTermines || f.seulementEnvie;
}

/** Applique les filtres à une bibliothèque. Retourne une nouvelle
 * GameLibrary (jamais de mutation) dont `jeux` est le sous-ensemble retenu. */
export function appliquerFiltres(library: GameLibrary, f: FiltresTirage): GameLibrary {
  if (!filtresActifs(f)) return library;

  const tagsRecherches = f.tags.map((t) => t.trim().toLowerCase()).filter(Boolean);

  const jeux = library.jeux.filter((j) => {
    if (f.exclureTermines && (j.statut === "Termine" || j.statut === "Abandonne")) return false;
    if (f.seulementEnvie && !j.envieDeFaire) return false;
    if (f.statuts.length > 0 && !f.statuts.includes(j.statut)) return false;
    if (tagsRecherches.length > 0) {
      const tagsDuJeu = j.tags.split(",").map((t) => t.trim().toLowerCase()).filter(Boolean);
      if (!tagsRecherches.some((t) => tagsDuJeu.includes(t))) return false;
    }
    return true;
  });

  return { ...library, jeux };
}

// --- Tirage multiple (v24) ---------------------------------------------------

export interface MultiDrawResult {
  /** Les jeux tirés, dans l'ordre. */
  games: Game[];
  /** Bibliothèque après TOUS les tirages — à persister une seule fois. */
  library: GameLibrary;
  cycleReset: boolean;
}

/** Tire `count` jeux DISTINCTS en une passe. Chaque tirage s'appuie sur la
 * bibliothèque mise à jour par le précédent, donc le pool anti-répétition
 * reste cohérent et aucun doublon n'est possible dans un même lot.
 * Retourne moins de `count` jeux si la bibliothèque est plus petite. */
export function drawMultiple(library: GameLibrary, count: number, eviterRepetitions = true): MultiDrawResult | null {
  if (library.jeux.length === 0 || count < 1) return null;

  const games: Game[] = [];
  let courante = library;
  let cycleReset = false;
  const dejaTires = new Set<string>();

  // Borne dure : on ne peut pas sortir plus de jeux qu'il n'en existe.
  const cible = Math.min(count, library.jeux.length);

  // La garde `tentatives` évite une boucle infinie si le hasard retombe
  // sans cesse sur des jeux déjà sortis dans ce lot (possible quand
  // eviterRepetitions est désactivé).
  let tentatives = 0;
  const maxTentatives = cible * 40;

  while (games.length < cible && tentatives < maxTentatives) {
    tentatives++;
    const r = drawFromLibrary(courante, eviterRepetitions);
    if (!r) break;
    courante = r.library;
    if (r.cycleReset) cycleReset = true;
    if (dejaTires.has(r.game.id)) continue;
    dejaTires.add(r.game.id);
    games.push(r.game);
  }

  if (games.length === 0) return null;
  return { games, library: courante, cycleReset };
}
