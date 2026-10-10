import { SCHEMA_VERSION, STATUTS_PAR_DEFAUT, SOURCES_COVER_PAR_DEFAUT } from "./types";

// Point central de migration de schéma. Toute donnée lue du disque passe
// ici AVANT d'être utilisée par l'app. Quand le schéma évolue (il évoluera
// entre les phases), on ajoute une étape dans la chaîne de migration du
// type concerné — jamais de "if version" éparpillés dans les composants.

type Migration = (data: any) => any;

// Chaînes de migration par type de fichier : la clé N contient la fonction
// qui fait passer les données de la version N à la version N+1.
//
// Important : SCHEMA_VERSION est GLOBAL (partagé par tous les types de
// fichier). Bumper la version pour UN type (ex. session en v2 pour le
// compte à rebours) oblige donc les autres types à avoir eux aussi une
// étape v1→v2, même si leur forme n'a pas changé — d'où les migrations
// "identité" ci-dessous pour config/library.
const MIGRATIONS: Record<string, Record<number, Migration>> = {
  config: {
    1: (d) => d, // v2 : schéma config inchangé, seule la version globale a bougé
    2: (d) => ({ ...d, rawgApiKey: d.rawgApiKey ?? "" }), // v3 (Phase 4)
    3: (d) => ({ ...d, steamApiKey: d.steamApiKey ?? "", steamId64: d.steamId64 ?? "" }), // v4 (Phase 5)
    4: (d) => d, // v5 : schéma config inchangé
    5: (d) => d, // v6 : schéma config inchangé
    6: (d) => d, // v7 : schéma config inchangé
    7: (d) => ({ ...d, iconeNotation: d.iconeNotation ?? "etoile" }), // v8
    // v9 (Phase 7) : réglages Tirage/Apparence, jusqu'ici en dur dans App.svelte.
    8: (d) => ({
      ...d,
      animationStyle: d.animationStyle ?? "cartes",
      revealEffect: d.revealEffect ?? "confettis",
      animationDurationMs: d.animationDurationMs ?? 1800,
      eviterRepetitions: d.eviterRepetitions ?? true,
      avertirAvantNouveauTirage: d.avertirAvantNouveauTirage ?? true,
      notifierFinSession: d.notifierFinSession ?? true,
      objectifParDefaut: d.objectifParDefaut ?? 30,
      objectifsDisponibles: d.objectifsDisponibles ?? [15, 30, 45, 60, 90],
      nombreHistorique: d.nombreHistorique ?? 50,
      densite: d.densite ?? "normal",
      afficherSelecteurTheme: d.afficherSelecteurTheme ?? true,
    }),
    // v10 (Phase 7 — Options > Jeux & Statuts) : les statuts deviennent
    // extensibles (StatutDefinition) au lieu d'un type figé.
    9: (d) => ({ ...d, statuts: d.statuts ?? STATUTS_PAR_DEFAUT }),
    // v11 : réduction dans la barre système (Options > Apparence).
    10: (d) => ({ ...d, reduireBarreSysteme: d.reduireBarreSysteme ?? false }),
    // v12 : couleurs de statut fixes/universelles au lieu de var(--accent)
    // etc. — resynchronise les statuts INTÉGRÉS (jamais personnalisables
    // par couleur de toute façon) sur les nouvelles couleurs par défaut ;
    // les statuts personnalisés gardent leur couleur choisie, inchangée.
    11: (d) => ({
      ...d,
      statuts: (d.statuts ?? STATUTS_PAR_DEFAUT).map((s: any) => {
        if (!s.integre) return s;
        const defaut = STATUTS_PAR_DEFAUT.find((sd) => sd.id === s.id);
        return defaut ? { ...s, couleur: defaut.couleur } : s;
      }),
    }),
    // v13 : SteamGridDB (clé) + activation/désactivation par source de jaquette.
    12: (d) => ({
      ...d,
      steamgriddbApiKey: d.steamgriddbApiKey ?? "",
      sourcesCoverActives: d.sourcesCoverActives ?? SOURCES_COVER_PAR_DEFAUT,
    }),
    // v14 : Wikipédia retirée comme source de jaquette — nettoie la clé si
    // elle traîne encore dans une config existante.
    13: (d) => {
      if (d.sourcesCoverActives && "wikipedia" in d.sourcesCoverActives) {
        const { wikipedia, ...reste } = d.sourcesCoverActives;
        return { ...d, sourcesCoverActives: reste };
      }
      return d;
    },
    // v15 : SteamGridDB n'est plus une intégration API à clé — comme dans le
    // script PowerShell d'origine, c'est un simple lien qui ouvre le
    // navigateur (aucune clé, aucune requête faite par l'app). Nettoie la
    // clé et le flag d'activation si présents dans une config existante.
    14: (d) => {
      let cfg = d;
      if ("steamgriddbApiKey" in cfg) {
        const { steamgriddbApiKey, ...reste } = cfg;
        cfg = reste;
      }
      if (cfg.sourcesCoverActives && "steamgriddb" in cfg.sourcesCoverActives) {
        const { steamgriddb, ...resteSources } = cfg.sourcesCoverActives;
        cfg = { ...cfg, sourcesCoverActives: resteSources };
      }
      return cfg;
    },
    // v16 : SteamGridDB redevient une option — les deux approches
    // coexistent désormais (fenêtre intégrée sans clé, recherche API avec
    // clé), au choix de Sensei plutôt que l'une remplaçant l'autre.
    15: (d) => ({
      ...d,
      steamgriddbApiKey: d.steamgriddbApiKey ?? "",
      sourcesCoverActives: { ...d.sourcesCoverActives, steamgriddb: d.sourcesCoverActives?.steamgriddb ?? true },
    }),
    // v17 : icône de fenêtre personnalisable (Options > Apparence).
    16: (d) => ({ ...d, iconeFenetre: d.iconeFenetre ?? "defaut" }),
    17: (d) => d, // v18 : schéma config inchangé (badges est un fichier séparé)
    // v19 : notification/toast dédiés au déblocage de succès.
    18: (d) => ({ ...d, notifierSucces: d.notifierSucces ?? true }),
    // v20 : durée de révélation séparée, objectifs de session avec unité
    // (minutes/heures/jours — anciennement toujours en minutes brutes),
    // animation de LED désactivable.
    19: (d) => {
      const versObjectif = (v: any) => (typeof v === "number" ? { valeur: v, unite: "minutes" } : v);
      return {
        ...d,
        revealDurationMs: d.revealDurationMs ?? 1200,
        objectifParDefaut: versObjectif(d.objectifParDefaut ?? 30),
        objectifsDisponibles: (d.objectifsDisponibles ?? [15, 30, 45, 60, 90]).map(versObjectif),
        ledAnimation: d.ledAnimation ?? "pulse",
      };
    },
    // v21 : succès masqués de la grille (liste d'ids, décochés = tous visibles).
    20: (d) => ({ ...d, badgesDesactives: d.badgesDesactives ?? [] }),
    // v22 : sons de l'app + style de transition entre onglets.
    21: (d) => ({
      ...d,
      sonsActifs: d.sonsActifs ?? true,
      volumeSons: d.volumeSons ?? 0.6,
      transitionOnglets: d.transitionOnglets ?? "glissement",
    }),
    // v23 : onglets masquables.
    22: (d) => ({ ...d, ongletsMasques: d.ongletsMasques ?? [] }),
    // v24 : tirage multiple + mode roulette russe.
    23: (d) => ({ ...d, nombreTirages: d.nombreTirages ?? 1, rouletteRusse: d.rouletteRusse ?? false }),
    // v25 : récap d'accueil.
    24: (d) => ({ ...d, afficherRecap: d.afficherRecap ?? true }),
    // v26 : journal d'usage minimal pour les nouveaux succès.
    25: (d) => ({
      ...d,
      themesEssayes: d.themesEssayes ?? (d.theme ? [d.theme] : []),
      aUtiliseTirageMultiple: d.aUtiliseTirageMultiple ?? false,
      aUtiliseRouletteRusse: d.aUtiliseRouletteRusse ?? false,
      aUtiliseFiltres: d.aUtiliseFiltres ?? false,
    }),
    // v27 : jaquette au résultat + blocs du récap masquables.
    26: (d) => ({
      ...d,
      afficherCoverResultat: d.afficherCoverResultat ?? true,
      blocsRecapMasques: d.blocsRecapMasques ?? [],
    }),
    // v28 : style d'affichage du chrono.
    27: (d) => ({ ...d, styleChrono: d.styleChrono ?? "barre" }),
    // v29 : langue de l'interface (français par défaut pour les installations existantes).
    28: (d) => ({ ...d, langue: d.langue === "en" ? "en" : "fr" }),
  },
  platforms: {},
  library: {
    1: (d) => d, // v2 : schéma bibliothèque inchangé
    // v3 (Phase 4) : chaque jeu gagne statut/note/tags/description/
    // commentaire/typeFin/cover — valeurs par défaut neutres pour les jeux
    // déjà existants.
    2: (d) => ({
      ...d,
      jeux: (d.jeux ?? []).map((j: any) => ({
        ...j,
        statut: j.statut ?? "NonCommence",
        note: j.note ?? 0,
        tags: j.tags ?? "",
        description: j.description ?? "",
        commentaire: j.commentaire ?? "",
        typeFin: j.typeFin ?? "",
        cover: j.cover ?? null,
      })),
    }),
    3: (d) => d, // v4 : schéma bibliothèque inchangé
    4: (d) => d, // v5 : schéma bibliothèque inchangé
    // v6 : deux marqueurs cœur ("Envie de faire", "Coup de cœur").
    5: (d) => ({
      ...d,
      jeux: (d.jeux ?? []).map((j: any) => ({
        ...j,
        envieDeFaire: j.envieDeFaire ?? false,
        coupDeCoeur: j.coupDeCoeur ?? false,
      })),
    }),
    // v7 : défis personnalisés + temps de jeu manuel.
    6: (d) => ({
      ...d,
      jeux: (d.jeux ?? []).map((j: any) => ({
        ...j,
        defis: j.defis ?? [],
        heuresJouees: j.heuresJouees ?? null,
      })),
    }),
    7: (d) => d, // v8 : schéma bibliothèque inchangé
    8: (d) => d, // v9 : schéma bibliothèque inchangé
    9: (d) => d, // v10 : Game.statut passe en simple string, aucune donnée à changer
    10: (d) => d, // v11 : schéma bibliothèque inchangé
    // v12 : marqueur "100%" distinct du statut.
    11: (d) => ({
      ...d,
      jeux: (d.jeux ?? []).map((j: any) => ({ ...j, complete100: j.complete100 ?? false })),
    }),
    12: (d) => d, // v13 : schéma bibliothèque inchangé
    13: (d) => d, // v14 : schéma bibliothèque inchangé
    14: (d) => d, // v15 : schéma bibliothèque inchangé
    15: (d) => d, // v16 : schéma bibliothèque inchangé
    16: (d) => d, // v17 : schéma bibliothèque inchangé
    17: (d) => d, // v18 : schéma bibliothèque inchangé
    18: (d) => d, // v19 : schéma bibliothèque inchangé
    19: (d) => d, // v20 : schéma bibliothèque inchangé
    20: (d) => d, // v21 : schéma bibliothèque inchangé
    21: (d) => d, // v22 : schéma bibliothèque inchangé
    22: (d) => d, // v23 : schéma bibliothèque inchangé
    23: (d) => d, // v24 : schéma bibliothèque inchangé
    24: (d) => d, // v25 : schéma bibliothèque inchangé
    25: (d) => d, // v26 : schéma bibliothèque inchangé
    26: (d) => d, // v27 : schéma bibliothèque inchangé
    27: (d) => d, // v28 : schéma bibliothèque inchangé
    28: (d) => d, // v29 : schéma bibliothèque inchangé
  },
  session: {
    // v2 (Phase 3) : ajout du compte à rebours (goalMinutes, endsAt).
    1: (d) => ({ ...d, goalMinutes: d.goalMinutes ?? null, endsAt: d.endsAt ?? null }),
    2: (d) => d, // v3 : schéma session inchangé
    3: (d) => d, // v4 : schéma session inchangé
    4: (d) => d, // v5 : schéma session inchangé
    5: (d) => d, // v6 : schéma session inchangé
    6: (d) => d, // v7 : schéma session inchangé
    7: (d) => d, // v8 : schéma session inchangé
    8: (d) => d, // v9 : schéma session inchangé
    9: (d) => d, // v10 : schéma session inchangé
    10: (d) => d, // v11 : schéma session inchangé
    11: (d) => d, // v12 : schéma session inchangé
    12: (d) => d, // v13 : schéma session inchangé
    13: (d) => d, // v14 : schéma session inchangé
    14: (d) => d, // v15 : schéma session inchangé
    15: (d) => d, // v16 : schéma session inchangé
    16: (d) => d, // v17 : schéma session inchangé
    17: (d) => d, // v18 : schéma session inchangé
    18: (d) => d, // v19 : schéma session inchangé
    19: (d) => d, // v20 : schéma session inchangé
    20: (d) => d, // v21 : schéma session inchangé
    21: (d) => d, // v22 : schéma session inchangé
    22: (d) => d, // v23 : schéma session inchangé
    23: (d) => d, // v24 : schéma session inchangé
    24: (d) => d, // v25 : schéma session inchangé
    25: (d) => d, // v26 : schéma session inchangé
    26: (d) => d, // v27 : schéma session inchangé
    27: (d) => d, // v28 : schéma session inchangé
    28: (d) => d, // v29 : schéma session inchangé
  },
  // Nouveau fichier en Phase 6 — pas de forme antérieure à faire évoluer,
  // mais migrate() démarre quand même à v1 pour toute donnée sans
  // schemaVersion (cf. sa logique), d'où ces étapes identité 1→4.
  historique: {
    1: (d) => d,
    2: (d) => d,
    3: (d) => d,
    4: (d) => ({ ...d, entrees: d.entrees ?? [] }),
    5: (d) => d, // v6 : schéma historique inchangé
    6: (d) => d, // v7 : schéma historique inchangé
    7: (d) => d, // v8 : schéma historique inchangé
    8: (d) => d, // v9 : schéma historique inchangé
    9: (d) => d, // v10 : schéma historique inchangé
    10: (d) => d, // v11 : schéma historique inchangé
    11: (d) => d, // v12 : schéma historique inchangé
    12: (d) => d, // v13 : schéma historique inchangé
    13: (d) => d, // v14 : schéma historique inchangé
    14: (d) => d, // v15 : schéma historique inchangé
    15: (d) => d, // v16 : schéma historique inchangé
    16: (d) => d, // v17 : schéma historique inchangé
    17: (d) => d, // v18 : schéma historique inchangé
    18: (d) => d, // v19 : schéma historique inchangé
    19: (d) => d, // v20 : schéma historique inchangé
    20: (d) => d, // v21 : schéma historique inchangé
    21: (d) => d, // v22 : schéma historique inchangé
    22: (d) => d, // v23 : schéma historique inchangé
    23: (d) => d, // v24 : schéma historique inchangé
    24: (d) => d, // v25 : schéma historique inchangé
    25: (d) => d, // v26 : schéma historique inchangé
    26: (d) => d, // v27 : schéma historique inchangé
    27: (d) => d, // v28 : schéma historique inchangé
    28: (d) => d, // v29 : schéma historique inchangé
  },
  // Nouveau fichier — succès internes (gamification). Pas de forme
  // antérieure à faire évoluer, migrate() démarre quand même à v1 pour
  // toute donnée sans schemaVersion, d'où les étapes identité 1→17.
  badges: {
    1: (d) => d, 2: (d) => d, 3: (d) => d, 4: (d) => d, 5: (d) => d,
    6: (d) => d, 7: (d) => d, 8: (d) => d, 9: (d) => d, 10: (d) => d,
    11: (d) => d, 12: (d) => d, 13: (d) => d, 14: (d) => d, 15: (d) => d,
    16: (d) => d, 17: (d) => ({ ...d, debloquees: d.debloquees ?? [] }),
    18: (d) => d, // v19 : schéma badges inchangé
    19: (d) => d, // v20 : schéma badges inchangé
    20: (d) => d, // v21 : schéma badges inchangé
    21: (d) => d, // v22 : schéma badges inchangé
    22: (d) => d, // v23 : schéma badges inchangé
    23: (d) => d, // v24 : schéma badges inchangé
    24: (d) => d, // v25 : schéma badges inchangé
    25: (d) => d, // v26 : schéma badges inchangé
    26: (d) => d, // v27 : schéma badges inchangé
    27: (d) => d, // v28 : schéma badges inchangé
    28: (d) => d, // v29 : schéma badges inchangé
  },
};

/**
 * Vérifie la version de schéma d'une donnée lue du disque et applique les
 * migrations nécessaires pour l'amener à SCHEMA_VERSION.
 *
 * - Donnée sans champ schemaVersion : considérée v1 (fichiers écrits par les
 *   premières builds de la Phase 1).
 * - Version FUTURE (donnée écrite par une version plus récente de l'app) :
 *   on lève une erreur explicite plutôt que de corrompre silencieusement.
 */
export function migrate<T>(kind: keyof typeof MIGRATIONS, data: unknown): T {
  let d: any = data;
  let version: number = typeof d?.schemaVersion === "number" ? d.schemaVersion : 1;

  // Certaines builds Rust ont créé historique.json/badges.json avec
  // schemaVersion: 0 via #[derive(Default)] sur un u32. Ces données ont en
  // réalité la forme de base v1 : on les rattache donc explicitement à v1
  // afin que les migrations normales puissent s'appliquer et auto-réparer
  // le fichier au prochain enregistrement.
  if (version === 0) version = 1;

  if (version > SCHEMA_VERSION) {
    throw new Error(
      `Fichier "${kind}" écrit par une version plus récente de GameDraw ` +
        `(schéma v${version} > v${SCHEMA_VERSION}). Mets à jour l'application.`
    );
  }

  const chain = MIGRATIONS[kind];
  while (version < SCHEMA_VERSION) {
    const step = chain[version];
    if (!step) {
      throw new Error(`Migration manquante pour "${kind}" v${version} → v${version + 1}`);
    }
    d = step(d);
    version++;
  }

  d.schemaVersion = SCHEMA_VERSION;
  return d as T;
}
