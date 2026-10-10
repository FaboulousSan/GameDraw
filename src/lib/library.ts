import type { Defi, Game, GameLibrary, StatutDefinition, StatutJeu } from "./types";
import { STATUTS_PAR_DEFAUT } from "./types";

// CRUD de bibliothèque en fonctions PURES (non-mutantes), même esprit que
// draw.ts — testable sans Tauri, l'appelant persiste via api.saveGames().

function nouvelId(): string {
  return crypto.randomUUID();
}

export function creerJeu(nom: string): Game {
  return {
    id: nouvelId(),
    nom: nom.trim(),
    dejaFait: false,
    statut: "NonCommence",
    note: 0,
    tags: "",
    description: "",
    commentaire: "",
    typeFin: "",
    cover: null,
    envieDeFaire: false,
    coupDeCoeur: false,
    defis: [],
    heuresJouees: null,
    complete100: false,
  };
}

export function ajouterJeu(library: GameLibrary, nom: string): GameLibrary {
  return { ...library, jeux: [...library.jeux, creerJeu(nom)] };
}

/** Ajoute plusieurs jeux d'un coup (import de catalogue), en ignorant les
 * doublons par nom (insensible à la casse) déjà présents dans la bibliothèque. */
export function ajouterPlusieursJeux(library: GameLibrary, noms: string[]): { library: GameLibrary; ignores: number } {
  const existants = new Set(library.jeux.map((j) => j.nom.trim().toLowerCase()));
  let ignores = 0;
  const nouveaux: Game[] = [];
  for (const nom of noms) {
    const cle = nom.trim().toLowerCase();
    if (!cle || existants.has(cle)) {
      ignores++;
      continue;
    }
    existants.add(cle);
    nouveaux.push(creerJeu(nom));
  }
  return { library: { ...library, jeux: [...library.jeux, ...nouveaux] }, ignores };
}

export function supprimerJeu(library: GameLibrary, gameId: string): GameLibrary {
  return { ...library, jeux: library.jeux.filter((j) => j.id !== gameId) };
}

/** Supprime plusieurs jeux d'un coup (mode sélection groupée) — pratique
 * pour nettoyer après des tests d'import répétés. */
export function supprimerPlusieursJeux(library: GameLibrary, gameIds: string[]): GameLibrary {
  const aSupprimer = new Set(gameIds);
  return { ...library, jeux: library.jeux.filter((j) => !aSupprimer.has(j.id)) };
}

export function modifierJeu(library: GameLibrary, gameId: string, patch: Partial<Game>): GameLibrary {
  return { ...library, jeux: library.jeux.map((j) => (j.id === gameId ? { ...j, ...patch } : j)) };
}

/** Filtre les jeux par texte de recherche (nom, insensible à la casse). */
export function filtrerJeux(jeux: Game[], recherche: string): Game[] {
  const q = recherche.trim().toLowerCase();
  if (!q) return jeux;
  return jeux.filter((j) => j.nom.toLowerCase().includes(q));
}

// --- Import de liste texte / CSV — Phase 5 ----------------------------------

export interface LigneImport {
  nom: string;
  statut?: StatutJeu;
  tags?: string;
  description?: string;
  commentaire?: string;
}

/** Colle une liste de noms (un par ligne) → une ligne d'import par nom non-vide. */
export function parseListeTexte(texte: string): LigneImport[] {
  return texte
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l.length > 0)
    .map((nom) => ({ nom }));
}

/** Parseur CSV minimal (pas de dépendance ajoutée pour un format aussi
 * simple) : virgule comme séparateur, champs entre guillemets doubles
 * supportés (avec `""` pour un guillemet littéral à l'intérieur). Colonne
 * "Nom" obligatoire (insensible à la casse) ; "Statut"/"Tags"/"Description"/
 * "Commentaire" optionnelles. Un "Statut" qui ne correspond à aucun statut
 * connu (par id OU par libellé, ex. "Terminé" ou "Termine") est ignoré (le
 * jeu reste "NonCommence" par défaut), plutôt que de faire échouer tout
 * l'import pour une seule ligne mal formée. `statutsConnus` par défaut aux
 * 5 statuts d'origine ; passer `config.statuts` pour reconnaître aussi les
 * statuts personnalisés déjà créés. */
export function parseCsv(texte: string, statutsConnus: StatutDefinition[] = STATUTS_PAR_DEFAUT): LigneImport[] {
  const lignes = diviserLignesCsv(texte);
  if (lignes.length === 0) return [];

  const entete = lignes[0].map((c) => c.trim().toLowerCase());
  const idxNom = entete.indexOf("nom");
  if (idxNom === -1) return [];
  const idxStatut = entete.indexOf("statut");
  const idxTags = entete.indexOf("tags");
  const idxDescription = entete.indexOf("description");
  const idxCommentaire = entete.indexOf("commentaire");

  const resultat: LigneImport[] = [];
  for (const champs of lignes.slice(1)) {
    const nom = (champs[idxNom] ?? "").trim();
    if (!nom) continue;
    const statutBrut = idxStatut >= 0 ? (champs[idxStatut] ?? "").trim().toLowerCase() : "";
    const statutTrouve = statutsConnus.find((s) => s.id.toLowerCase() === statutBrut || s.label.toLowerCase() === statutBrut);
    resultat.push({
      nom,
      statut: statutTrouve?.id,
      tags: idxTags >= 0 ? champs[idxTags]?.trim() : undefined,
      description: idxDescription >= 0 ? champs[idxDescription]?.trim() : undefined,
      commentaire: idxCommentaire >= 0 ? champs[idxCommentaire]?.trim() : undefined,
    });
  }
  return resultat;
}

function diviserLignesCsv(texte: string): string[][] {
  const lignes: string[][] = [];
  let ligne: string[] = [];
  let champ = "";
  let dansGuillemets = false;

  for (let i = 0; i < texte.length; i++) {
    const c = texte[i];
    if (dansGuillemets) {
      if (c === '"') {
        if (texte[i + 1] === '"') {
          champ += '"';
          i++;
        } else {
          dansGuillemets = false;
        }
      } else {
        champ += c;
      }
    } else if (c === '"') {
      dansGuillemets = true;
    } else if (c === ",") {
      ligne.push(champ);
      champ = "";
    } else if (c === "\n" || c === "\r") {
      if (c === "\r" && texte[i + 1] === "\n") i++;
      ligne.push(champ);
      champ = "";
      if (ligne.some((c) => c.trim() !== "")) lignes.push(ligne);
      ligne = [];
    } else {
      champ += c;
    }
  }
  if (champ !== "" || ligne.length > 0) {
    ligne.push(champ);
    if (ligne.some((c) => c.trim() !== "")) lignes.push(ligne);
  }
  return lignes;
}

/** Import de liste/CSV : comme ajouterPlusieursJeux, mais chaque ligne peut
 * porter statut/tags/description/commentaire en plus du nom. */
export function importerLignes(library: GameLibrary, lignes: LigneImport[]): { library: GameLibrary; ignores: number } {
  const existants = new Set(library.jeux.map((j) => j.nom.trim().toLowerCase()));
  let ignores = 0;
  const nouveaux: Game[] = [];
  for (const ligne of lignes) {
    const cle = ligne.nom.trim().toLowerCase();
    if (!cle || existants.has(cle)) {
      ignores++;
      continue;
    }
    existants.add(cle);
    const jeu = creerJeu(ligne.nom);
    if (ligne.statut) jeu.statut = ligne.statut;
    if (ligne.tags) jeu.tags = ligne.tags;
    if (ligne.description) jeu.description = ligne.description;
    if (ligne.commentaire) jeu.commentaire = ligne.commentaire;
    nouveaux.push(jeu);
  }
  return { library: { ...library, jeux: [...library.jeux, ...nouveaux] }, ignores };
}

// --- Fusion de jeux déjà construits (Steam, import .zip) — Phase 5 ----------

/** Fusionne des Game déjà complets (import Steam converti en Game, ou jeux
 * lus d'un .zip GameDraw) dans la bibliothèque cible — même dédoublonnage
 * par nom que les autres imports, mais on garde l'objet Game tel quel
 * (jaquette, statut, etc. déjà présents) plutôt que de le reconstruire. */
export function fusionnerJeux(library: GameLibrary, jeuxImportes: Game[]): { library: GameLibrary; ignores: number } {
  const existants = new Set(library.jeux.map((j) => j.nom.trim().toLowerCase()));
  let ignores = 0;
  const nouveaux: Game[] = [];
  for (const jeu of jeuxImportes) {
    const cle = jeu.nom.trim().toLowerCase();
    if (!cle || existants.has(cle)) {
      ignores++;
      continue;
    }
    existants.add(cle);
    nouveaux.push(jeu);
  }
  return { library: { ...library, jeux: [...library.jeux, ...nouveaux] }, ignores };
}

// --- Défis personnalisés — liste libre à cocher par jeu ---------------------
// Vide par défaut : un jeu sans défi n'affiche rien nulle part (Backlog),
// pas besoin d'un interrupteur pour "désactiver" la fonctionnalité.

export function ajouterDefi(library: GameLibrary, gameId: string, texte: string): GameLibrary {
  const propre = texte.trim();
  if (!propre) return library;
  const defi: Defi = { id: nouvelId(), texte: propre, complete: false };
  return modifierJeu(library, gameId, {
    defis: [...(library.jeux.find((j) => j.id === gameId)?.defis ?? []), defi],
  });
}

export function basculerDefi(library: GameLibrary, gameId: string, defiId: string): GameLibrary {
  const jeu = library.jeux.find((j) => j.id === gameId);
  if (!jeu) return library;
  return modifierJeu(library, gameId, {
    defis: jeu.defis.map((d) => (d.id === defiId ? { ...d, complete: !d.complete } : d)),
  });
}

export function supprimerDefi(library: GameLibrary, gameId: string, defiId: string): GameLibrary {
  const jeu = library.jeux.find((j) => j.id === gameId);
  if (!jeu) return library;
  return modifierJeu(library, gameId, { defis: jeu.defis.filter((d) => d.id !== defiId) });
}
