// Nouveau schéma de données GameDraw (rupture volontaire avec le JSON
// PowerShell — cf. décision prise en début de migration : pas de lecture/
// écriture rétrocompatible, migration one-shot prévue en Phase 8).
//
// Chaque fichier de données porte un champ `schemaVersion` pour permettre
// une migration future sans tout casser si le schéma évolue encore.

import type { AnimationStyleName } from "./animations/animations";
import type { RevealEffectName } from "./effects/effects";

export const SCHEMA_VERSION = 29;

export type ThemeName =
  | "catppuccin"
  | "ocarina"
  | "cyberpunk"
  | "foret"
  | "dracula"
  | "witcher"
  | "pipboy"
  | "mario"
  | "luigi"
  | "dragon"
  | "clair"
  | "sombrePremium"
  | "hiver"
  | "firefox"
  | "majora"
  | "hollowKnight"
  | "sakura"
  | "vaporwave"
  | "sang"
  | "abysse"
  | "emeraude"
  | "monochrome"
  | "cafe"
  | "neon";

export type IconeNotation = "etoile" | "epee" | "coeur" | "trophee" | "diamant" | "crane";

export type Densite = "compact" | "normal" | "confortable" | "spacieux";

// Objectifs de session — v20 : plus seulement des minutes, une unité au
// choix (utile pour un objectif "1 jour" en marathon, ou "2 heures").
// Converti en minutes uniquement au moment de démarrer une session
// (session.json/historique.json restent en minutes, inchangés).
export type UniteDuree = "minutes" | "heures" | "jours";

export interface ObjectifSession {
  valeur: number;
  unite: UniteDuree;
}

export function objectifEnMinutes(o: ObjectifSession): number {
  if (o.unite === "heures") return o.valeur * 60;
  if (o.unite === "jours") return o.valeur * 60 * 24;
  return o.valeur;
}

export function formaterObjectif(o: ObjectifSession): string {
  const unite = o.unite === "minutes" ? "min" : o.unite === "heures" ? "h" : "j";
  return `${o.valeur} ${unite}`;
}

// Animation de la pastille de statut clignotante (Backlog) — "pulse" est le
// comportement d'origine, "fixe" la désactive pour qui la trouve distrayante.
export type AnimationLed = "pulse" | "fixe";

// Style de transition entre les onglets principaux — "glissement" tient
// compte du SENS de navigation (l'onglet arrive du côté d'où on vient),
// "fondu" est un simple crossfade, "aucune" désactive tout.
export type TransitionOnglets = "glissement" | "fondu" | "aucune";

// Seuls ces 4 onglets peuvent être masqués (cf. ongletsMasques) — Tirage et
// Options en sont volontairement exclus, par sécurité d'usage.
// Blocs du récap d'accueil, masquables individuellement (Options > Apparence).
export const BLOCS_RECAP: { id: string; label: string }[] = [
  { id: "poolRestant", label: "Jeux à découvrir" },
  { id: "enCours", label: "Jeux en cours" },
  { id: "termines", label: "Jeux terminés" },
  { id: "tirages", label: "Nombre de tirages" },
  { id: "dernierTirage", label: "Dernier tirage" },
];

// Styles d'affichage du compte à rebours de session (Options > Apparence).
// "barre" est l'affichage d'origine ; les autres changent la mise en scène
// du temps qui passe, pas l'information affichée.
export type StyleChrono = "barre" | "arcEnCiel" | "defilant" | "bombe" | "sablier" | "segments" | "aucun";

export const STYLES_CHRONO: { id: StyleChrono; label: string; description: string }[] = [
  { id: "barre", label: "Barre", description: "Barre de progression classique." },
  { id: "arcEnCiel", label: "Arc-en-ciel", description: "Barre dégradée multicolore." },
  { id: "defilant", label: "Défilant", description: "Barre à rayures animées." },
  { id: "bombe", label: "Bombe 💣", description: "Mèche qui se consume, explose à zéro." },
  { id: "sablier", label: "Sablier", description: "Le sable descend au fil du temps." },
  { id: "segments", label: "Segments", description: "Blocs qui s'éteignent un par un." },
  { id: "aucun", label: "Aucun", description: "Chiffres seuls, sans indicateur visuel." },
];

export type OngletMasquable = "bibliotheque" | "backlog" | "statistiques" | "recherche";

export const ONGLETS_MASQUABLES: { id: OngletMasquable; label: string }[] = [
  { id: "bibliotheque", label: "Bibliothèque" },
  { id: "backlog", label: "Backlog" },
  { id: "statistiques", label: "Stats" },
  { id: "recherche", label: "Recherche" },
];

// Icône de la FENÊTRE (barre des tâches/barre de titre) pendant l'exécution
// — pas l'icône du .exe/raccourci, figée à la compilation et impossible à
// changer sans recompiler. "defaut" = celle du build (icons/icon.ico), les
// autres reprennent les variantes du script PowerShell d'origine.
export type IconeFenetre = "defaut" | "bleu" | "sombre" | "v2";

// Sources de recherche AUTOMATIQUE de jaquette (Fiche du jeu) — chacune
// activable/désactivable indépendamment dans Options > Connexion. SteamGridDB
// propose les DEUX approches : un lien qui ouvre une fenêtre intégrée sur le
// site (aucune clé, comme le script PowerShell d'origine) ET une recherche
// automatisée avec résultats affichés dans l'app (clé requise, comme RAWG).
export interface SourcesCoverActives {
  rawg: boolean;
  steam: boolean;
  steamgriddb: boolean;
}

export const SOURCES_COVER_PAR_DEFAUT: SourcesCoverActives = {
  rawg: true,
  steam: true,
  steamgriddb: true,
};

// --- jeux/<platformId>.json ------------------------------------------------
// Depuis v10 : plus un type figé — `Game.statut` est une simple chaîne qui
// référence l'id d'une StatutDefinition (dans config.statuts). Les 5
// statuts d'origine restent "intégrés" (integre: true, non supprimables),
// mais on peut en ajouter d'autres avec leur propre libellé/couleur, et
// masquer n'importe lequel des sélecteurs sans casser les jeux qui le
// référencent déjà (masquer ≠ supprimer).
export type StatutJeu = string;

export interface StatutDefinition {
  id: string;
  label: string;
  // Couleur hex fixe, universelle — que ce soit un statut intégré ou
  // personnalisé, elle ne change pas avec le thème actif (demande
  // explicite : un statut "En cours" doit rester vert quel que soit le
  // thème choisi).
  couleur: string;
  integre: boolean;
  visible: boolean;
}

export const STATUTS_PAR_DEFAUT: StatutDefinition[] = [
  // Couleurs fixes et universelles (pas var(--accent) etc.) — un vert reste
  // vert quel que soit le thème actif, demande explicite de Sensei plutôt
  // que des couleurs qui suivaient l'accent du thème.
  { id: "NonCommence", label: "Non commencé", couleur: "#F4F4F5", integre: true, visible: true },
  { id: "EnCours", label: "En cours", couleur: "#22C55E", integre: true, visible: true },
  { id: "EnPause", label: "En pause", couleur: "#EAB308", integre: true, visible: true },
  { id: "Termine", label: "Terminé", couleur: "#A855F7", integre: true, visible: true },
  { id: "Abandonne", label: "Abandonné", couleur: "#EF4444", integre: true, visible: true },
];

// --- config.json ---------------------------------------------------------
export interface AppConfig {
  schemaVersion: number;
  // Ajouté en v29 : langue de l'interface, persistée localement.
  langue: "fr" | "en";
  theme: ThemeName;
  // Ajouté en v3 (Phase 4) : champ temporaire en attendant l'écran Options
  // (Phase 7) où la Connexion RAWG/Steam aura sa vraie place.
  rawgApiKey: string;
  // Ajoutés en v4 (Phase 5) : mêmes raisons, pour l'import Steam.
  steamApiKey: string;
  steamId64: string;
  // Ajouté en v8 : style d'icône pour la notation (étoile par défaut,
  // épée/cœur/trophée/diamant/crâne au choix) — reprend l'esprit de
  // l'ancien "styles d'icônes de notation" du script PowerShell.
  iconeNotation: IconeNotation;
  // Ajoutés en v9 (Phase 7 — Options > Tirage) : jusqu'ici en dur dans
  // App.svelte (ANIMATION_STYLE, REVEAL_EFFECT, ANIMATION_DURATION_MS,
  // DEFAULT_SESSION_MINUTES), maintenant réglables.
  animationStyle: AnimationStyleName;
  revealEffect: RevealEffectName;
  animationDurationMs: number; // durée de l'animation de TIRAGE (avant révélation)
  // Ajouté en v20 : durée de l'effet de RÉVÉLATION, séparée de celle du
  // tirage — jusqu'ici seule celle du tirage était réglable.
  revealDurationMs: number;
  eviterRepetitions: boolean; // désactiver = tirage 100% aléatoire, sans pool anti-répétition
  avertirAvantNouveauTirage: boolean; // confirmation si une session chronométrée est active
  notifierFinSession: boolean; // notification Windows + toast à la fin du compte à rebours
  // Ajouté en v19 : même principe pour le déblocage d'un succès — notification
  // Windows + toast dédiés, désactivables indépendamment de notifierFinSession.
  notifierSucces: boolean;
  // v20 : objectifs de session avec unité (minutes/heures/jours), plus
  // seulement des minutes brutes.
  objectifParDefaut: ObjectifSession;
  objectifsDisponibles: ObjectifSession[];
  nombreHistorique: number; // nombre d'entrées conservées dans historique.json
  // Ajoutés en v9 (Phase 7 — Options > Apparence).
  densite: Densite;
  afficherSelecteurTheme: boolean;
  // Ajouté en v20 (Options > Apparence) : anime ou non la pastille de
  // statut clignotante du Backlog.
  ledAnimation: AnimationLed;
  // Ajoutés en v22 : sons de l'app (synthétisés, cf. sons.ts) et style de
  // transition entre les onglets.
  sonsActifs: boolean;
  volumeSons: number; // 0 (muet) à 1
  transitionOnglets: TransitionOnglets;
  // Ajouté en v23 : onglets masqués de la barre de navigation. "tirage" et
  // "options" ne sont JAMAIS masquables — le premier est le cœur de l'app,
  // le second est le seul moyen de revenir en arrière (se masquer Options
  // enfermerait l'utilisateur sans recours).
  ongletsMasques: OngletMasquable[];
  // Ajoutés en v24 (Options > Tirage).
  // nombreTirages : combien de jeux sortir d'un coup (1 = comportement
  // d'origine). rouletteRusse : masque le bouton "Retirer" après un tirage,
  // pour s'engager sur le résultat — un garde-fou volontaire, pas une
  // contrainte technique (rien n'empêche de relancer l'app).
  nombreTirages: number;
  rouletteRusse: boolean;
  // Ajouté en v25 : récap en haut de l'onglet Tirage.
  afficherRecap: boolean;
  // Ajouté en v27 : jaquette du jeu tiré affichée dans la zone de résultat.
  afficherCoverResultat: boolean;
  // Ajouté en v27 : blocs du récap d'accueil masqués individuellement.
  // Liste d'ids (cf. BLOCS_RECAP) plutôt que 5 booléens séparés : ajouter
  // un bloc plus tard ne demandera pas un nouveau champ à migrer.
  blocsRecapMasques: string[];
  // Ajouté en v28 : mise en scène du compte à rebours.
  styleChrono: StyleChrono;
  // Ajoutés en v26 — petit journal d'usage, uniquement pour des succès qui
  // ne seraient pas déductibles autrement (rien de tout ça ne se déduit de
  // la bibliothèque ou de l'historique). Volontairement minimal : des
  // listes d'ids déjà essayés et quelques booléens, pas de télémétrie.
  themesEssayes: string[];
  aUtiliseTirageMultiple: boolean;
  aUtiliseRouletteRusse: boolean;
  aUtiliseFiltres: boolean;
  // Ajouté en v10 (Phase 7 — Options > Jeux & Statuts).
  statuts: StatutDefinition[];
  // Ajouté en v11 (Options > Apparence) : réduit dans la barre système au
  // lieu de quitter au clic sur la croix, avec un menu clic droit sur
  // l'icône (Ouvrir/Quitter). Pris en compte seulement au démarrage
  // (lu directement par Rust) — nécessite un redémarrage pour s'appliquer.
  reduireBarreSysteme: boolean;
  // Ajouté en v16 : clé API SteamGridDB, en complément (pas en remplacement)
  // du lien fenêtre intégrée — les deux approches coexistent, au choix.
  steamgriddbApiKey: string;
  sourcesCoverActives: SourcesCoverActives;
  // Ajouté en v17 (Options > Apparence) : icône de la fenêtre en cours
  // d'exécution (barre des tâches/barre de titre), appliquée au démarrage
  // et à chaque changement — contrairement à l'icône du .exe/raccourci,
  // celle-ci PEUT changer sans recompiler.
  iconeFenetre: IconeFenetre;
  // Ajouté en v21 : succès masqués de la grille (pas supprimés — juste
  // cachés) — décision de conception : la LISTE des succès reste définie
  // par le code, seule leur visibilité est personnalisable.
  badgesDesactives: string[];
}

export const DEFAULT_CONFIG: AppConfig = {
  schemaVersion: SCHEMA_VERSION,
  langue: "fr",
  theme: "catppuccin",
  rawgApiKey: "",
  steamApiKey: "",
  steamId64: "",
  iconeNotation: "etoile",
  animationStyle: "cartes",
  revealEffect: "confettis",
  animationDurationMs: 1800,
  revealDurationMs: 1200,
  eviterRepetitions: true,
  avertirAvantNouveauTirage: true,
  notifierFinSession: true,
  notifierSucces: true,
  objectifParDefaut: { valeur: 30, unite: "minutes" },
  objectifsDisponibles: [
    { valeur: 15, unite: "minutes" },
    { valeur: 30, unite: "minutes" },
    { valeur: 45, unite: "minutes" },
    { valeur: 60, unite: "minutes" },
    { valeur: 90, unite: "minutes" },
  ],
  nombreHistorique: 50,
  densite: "normal",
  afficherSelecteurTheme: true,
  ledAnimation: "pulse",
  sonsActifs: true,
  volumeSons: 0.6,
  transitionOnglets: "glissement",
  ongletsMasques: [],
  nombreTirages: 1,
  rouletteRusse: false,
  afficherRecap: true,
  afficherCoverResultat: true,
  blocsRecapMasques: [],
  styleChrono: "barre",
  themesEssayes: [],
  aUtiliseTirageMultiple: false,
  aUtiliseRouletteRusse: false,
  aUtiliseFiltres: false,
  statuts: STATUTS_PAR_DEFAUT,
  reduireBarreSysteme: false,
  steamgriddbApiKey: "",
  sourcesCoverActives: SOURCES_COVER_PAR_DEFAUT,
  iconeFenetre: "defaut",
  badgesDesactives: [],
};

// --- plateformes.json -----------------------------------------------------
export interface Platform {
  id: string; // slug stable, ex: "switch", "pc" — généré une seule fois à la création
  nom: string;
  actif: boolean;
}

// --- jeux/<platformId>.json ------------------------------------------------

export interface Defi {
  id: string;
  texte: string;
  complete: boolean;
}

export interface Game {
  id: string;
  nom: string;
  dejaFait: boolean; // fait partie du pool anti-répétition du cycle en cours
  // Ajoutés en v3 (Phase 4) :
  statut: StatutJeu;
  note: number; // 0-5
  tags: string; // séparés par virgule
  description: string;
  commentaire: string;
  typeFin: string; // libre, pertinent surtout si statut = Termine/Abandonne
  cover: string | null; // chemin absolu local (copié dans le dossier de données), jamais une URL distante
  // Ajoutés en v6 : deux marqueurs rapides à cœur, distincts des tags libres
  // — "Envie de faire" (pour prioriser le backlog) et "Coup de cœur" (les
  // favoris qu'on veut mettre en avant).
  envieDeFaire: boolean;
  coupDeCoeur: boolean;
  // Ajoutés en v7 : défis personnalisés à cocher (liste libre, vide par
  // défaut — un jeu sans défi n'affiche rien nulle part, pas besoin
  // d'interrupteur pour "désactiver" la fonctionnalité) et temps de jeu
  // manuel (saisi par l'utilisateur, contrairement au temps de chrono qui
  // se déduit de l'historique des tirages).
  defis: Defi[];
  heuresJouees: number | null;
  // Ajouté en v12 : marqueur "100%" distinct du statut — un jeu peut être
  // Terminé sans avoir tout fait (100% des trophées/succès/objets), ou
  // inversement en cours de "post-game" 100% avant d'être marqué Terminé.
  complete100: boolean;
}

export interface GameLibrary {
  schemaVersion: number;
  platformId: string;
  jeux: Game[];
}

// --- session.json (tirage en cours) ---------------------------------------
export interface DrawSession {
  schemaVersion: number;
  platformId: string | null;
  gameId: string | null;
  drawnAt: string | null; // ISO 8601, ancré sur une date absolue (voir doc migration)
  // Ajoutés en v2 (Phase 3) : le compte à rebours se recalcule TOUJOURS à
  // partir de endsAt (date de fin absolue), jamais d'une durée écoulée en
  // mémoire — condition explicite du plan de migration pour survivre à une
  // fermeture complète de l'app.
  goalMinutes: number | null;
  endsAt: string | null;
}

export const EMPTY_SESSION: DrawSession = {
  schemaVersion: SCHEMA_VERSION,
  platformId: null,
  gameId: null,
  drawnAt: null,
  goalMinutes: null,
  endsAt: null,
};

// --- historique.json (journal des tirages) — Phase 6 ------------------------
// Nouveau fichier : une entrée par tirage effectué, utilisée pour les
// Statistiques (nombre de tirages, temps d'objectif cumulé par plateforme).
export interface EntreeHistorique {
  platformId: string;
  gameId: string;
  nom: string; // dénormalisé — évite de recharger la bibliothèque pour afficher les stats
  drawnAt: string; // ISO 8601
  goalMinutes: number | null;
}

export interface Historique {
  schemaVersion: number;
  entrees: EntreeHistorique[];
}

export const EMPTY_HISTORIQUE: Historique = {
  schemaVersion: SCHEMA_VERSION,
  entrees: [],
};

// --- badges.json (succès internes) — nouveau fichier ------------------------
// Une entrée par succès débloqué, avec la date. La LISTE des succès
// possibles (BADGE_DEFINITIONS) est du code, pas des données — seul l'état
// "débloqué ou non + quand" est persisté ici.
export interface BadgeDebloque {
  id: string;
  dateDebloquee: string; // ISO 8601
}

export interface Badges {
  schemaVersion: number;
  debloquees: BadgeDebloque[];
}

export const EMPTY_BADGES: Badges = {
  schemaVersion: SCHEMA_VERSION,
  debloquees: [],
};
