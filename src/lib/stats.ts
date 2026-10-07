import type { GameLibrary, Historique } from "./types";

export interface StatsPlateforme {
  totalJeux: number;
  jeuxNotes: number;
  tauxNotationPct: number; // 0-100
  dejaFaits: number;
  dejaFaitsPct: number; // 0-100 — avancement du cycle anti-répétition en cours
  nombreTirages: number;
  minutesCumulees: number; // somme des objectifs de session passés (approximation : suppose la session menée à terme)
}

/** Calcule les statistiques d'une plateforme à partir de sa bibliothèque
 * (peut être null si jamais chargée) et de l'historique complet des tirages
 * (déjà filtré ici par platformId). */
export function calculerStats(library: GameLibrary | null, historique: Historique, platformId: string): StatsPlateforme {
  const totalJeux = library?.jeux.length ?? 0;
  const jeuxNotes = library ? library.jeux.filter((j) => j.note > 0).length : 0;
  const dejaFaits = library ? library.jeux.filter((j) => j.dejaFait).length : 0;
  const entrees = historique.entrees.filter((e) => e.platformId === platformId);
  const minutesCumulees = entrees.reduce((somme, e) => somme + (e.goalMinutes ?? 0), 0);

  return {
    totalJeux,
    jeuxNotes,
    tauxNotationPct: totalJeux > 0 ? Math.round((jeuxNotes / totalJeux) * 100) : 0,
    dejaFaits,
    dejaFaitsPct: totalJeux > 0 ? Math.round((dejaFaits / totalJeux) * 100) : 0,
    nombreTirages: entrees.length,
    minutesCumulees,
  };
}

/** Formate un nombre de minutes en texte court (ex. "1h30", "45 min"). */
export function formaterMinutes(minutes: number): string {
  if (minutes <= 0) return "0 min";
  const h = Math.floor(minutes / 60);
  const m = Math.round(minutes % 60);
  if (h === 0) return `${m} min`;
  return m === 0 ? `${h}h` : `${h}h${String(m).padStart(2, "0")}`;
}

// --- Statistiques par jeu (Backlog) ------------------------------------------
// gameId est un UUID généré par creerJeu(), donc unique dans toute l'app —
// pas besoin de filtrer par platformId en plus.

/** Somme des objectifs de session (minutes) cumulés pour CE jeu précis à
 * travers tous ses tirages passés — même limite qu'aux Stats globales
 * (approximatif, suppose chaque session menée à terme). */
export function tempsCumuleJeu(historique: Historique, gameId: string): number {
  return historique.entrees.filter((e) => e.gameId === gameId).reduce((somme, e) => somme + (e.goalMinutes ?? 0), 0);
}

/** Date ISO du tirage le plus récent pour ce jeu, ou null s'il n'a jamais
 * été tiré. */
export function dernierTirageJeu(historique: Historique, gameId: string): string | null {
  const entrees = historique.entrees.filter((e) => e.gameId === gameId);
  if (entrees.length === 0) return null;
  return entrees.reduce((plusRecent, e) => (e.drawnAt > plusRecent ? e.drawnAt : plusRecent), entrees[0].drawnAt);
}

// --- Heatmap des tirages (v26) ----------------------------------------------

export interface JourHeatmap {
  /** Date au format YYYY-MM-DD (clé stable, indépendante du fuseau d'affichage). */
  date: string;
  /** Nombre de tirages ce jour-là. */
  compte: number;
  /** Intensité 0-4 pour le rendu (0 = aucun tirage). */
  niveau: number;
}

/** Clé jour locale (pas UTC) : un tirage à 23h doit compter pour le jour où
 * l'utilisateur l'a réellement fait, pas pour le lendemain. */
function cleJour(d: Date): string {
  const mois = String(d.getMonth() + 1).padStart(2, "0");
  const jour = String(d.getDate()).padStart(2, "0");
  return `${d.getFullYear()}-${mois}-${jour}`;
}

/**
 * Construit une grille façon "contributions GitHub" : un point par jour sur
 * les `jours` derniers jours (aujourd'hui inclus), même les jours sans
 * tirage — la régularité se lit justement dans les trous.
 *
 * Les niveaux sont relatifs au maximum de la période plutôt qu'à des seuils
 * fixes : quelqu'un qui tire 2 fois par jour et quelqu'un qui tire 20 fois
 * doivent tous deux voir un dégradé lisible.
 */
export function construireHeatmap(historique: Historique, jours = 182): JourHeatmap[] {
  const comptes = new Map<string, number>();
  for (const e of historique.entrees) {
    const k = cleJour(new Date(e.drawnAt));
    comptes.set(k, (comptes.get(k) ?? 0) + 1);
  }

  const resultat: JourHeatmap[] = [];
  const aujourdhui = new Date();
  aujourdhui.setHours(12, 0, 0, 0); // midi : évite les décalages aux changements d'heure

  for (let i = jours - 1; i >= 0; i--) {
    const d = new Date(aujourdhui);
    d.setDate(d.getDate() - i);
    const date = cleJour(d);
    resultat.push({ date, compte: comptes.get(date) ?? 0, niveau: 0 });
  }

  const max = Math.max(0, ...resultat.map((j) => j.compte));
  if (max > 0) {
    for (const j of resultat) {
      if (j.compte === 0) j.niveau = 0;
      else j.niveau = Math.min(4, Math.ceil((j.compte / max) * 4));
    }
  }
  return resultat;
}

// --- Frise chronologique des tirages (v26) ----------------------------------

export interface EntreeTimeline {
  nom: string;
  /** Date du tirage (ISO). */
  date: string;
  /** Statut ACTUEL du jeu, si retrouvé dans la bibliothèque. */
  statut: string | null;
  note: number;
  coupDeCoeur: boolean;
}

/**
 * Frise des derniers tirages, du plus récent au plus ancien, enrichie du
 * statut actuel de chaque jeu.
 *
 * Note de conception : la frise s'appuie sur les DATES DE TIRAGE, pas sur
 * des dates de terminaison — `Game` ne stocke aucune date de fin (seulement
 * un statut). Plutôt que d'ajouter un champ à persister et de laisser toutes
 * les données existantes sans date, on utilise ce qui est déjà daté de façon
 * fiable : l'historique. Elle raconte donc « ce que j'ai lancé et où ça en
 * est », ce qui est l'info réellement utile ici.
 */
export function construireTimeline(
  historique: Historique,
  library: GameLibrary | null,
  limite = 25
): EntreeTimeline[] {
  const parId = new Map((library?.jeux ?? []).map((j) => [j.id, j]));
  return [...historique.entrees]
    .reverse()
    .slice(0, limite)
    .map((e) => {
      const jeu = parId.get(e.gameId);
      return {
        nom: e.nom,
        date: e.drawnAt,
        statut: jeu?.statut ?? null,
        note: jeu?.note ?? 0,
        coupDeCoeur: jeu?.coupDeCoeur ?? false,
      };
    });
}
