import type { GameLibrary, Historique } from "./types";

export type CategorieBadge = "tirage" | "progression" | "collection" | "special";
export type Palier = "bronze" | "argent" | "or" | "platine" | "diamant" | "legende";

export const COULEURS_PALIER: Record<Palier, string> = {
  bronze: "#CD7F32",
  argent: "#A8A8B4",
  or: "#FFD54A",
  platine: "#7DE0E0",
  diamant: "#8FD0FF",
  legende: "#C98CFF",
};

export const LABELS_PALIER: Record<Palier, string> = {
  bronze: "Bronze",
  argent: "Argent",
  or: "Or",
  platine: "Platine",
  diamant: "Diamant",
  legende: "Légende",
};

export interface BadgeDefinition {
  id: string;
  label: string;
  description: string;
  categorie: CategorieBadge;
  // Absent = succès simple (pas de progression par palier).
  palier?: Palier;
}

// La LISTE des succès possibles est du code (pas des données), et c'est un
// choix de conception assumé : les succès ne sont PAS personnalisables par
// l'utilisateur — seul l'état "débloqué ou non + quand" est persisté dans
// badges.json (et la liste des DÉSACTIVÉS dans config.json, cf. types.ts).
// Paliers façon trophées (bronze → légende) pour les succès à progression ;
// les autres restent simples (débloqué une fois).
export const BADGE_DEFINITIONS: BadgeDefinition[] = [
  // --- Tirages (6 paliers) ----------------------------------------------
  { id: "tirages_bronze", label: "Tireur occasionnel", description: "10 tirages au total.", categorie: "tirage", palier: "bronze" },
  { id: "tirages_argent", label: "Tireur régulier", description: "25 tirages au total.", categorie: "tirage", palier: "argent" },
  { id: "tirages_or", label: "Tireur assidu", description: "50 tirages au total.", categorie: "tirage", palier: "or" },
  { id: "tirages_platine", label: "Tireur invétéré", description: "100 tirages au total.", categorie: "tirage", palier: "platine" },
  { id: "tirages_diamant", label: "Machine à tirages", description: "250 tirages au total. Le hasard te connaît par ton prénom.", categorie: "tirage", palier: "diamant" },
  { id: "tirages_legende", label: "Le Destin lui-même", description: "500 tirages au total. Tu ne tires plus les jeux, tu les convoques.", categorie: "tirage", palier: "legende" },

  // --- Jeux terminés (6 paliers) ------------------------------------------
  { id: "termines_bronze", label: "Premier terminé", description: "1 jeu marqué Terminé.", categorie: "progression", palier: "bronze" },
  { id: "termines_argent", label: "Sur sa lancée", description: "3 jeux marqués Terminé.", categorie: "progression", palier: "argent" },
  { id: "termines_or", label: "Finisseur", description: "5 jeux marqués Terminé.", categorie: "progression", palier: "or" },
  { id: "termines_platine", label: "Grand finisseur", description: "10 jeux marqués Terminé.", categorie: "progression", palier: "platine" },
  { id: "termines_diamant", label: "Complétionniste", description: "20 jeux marqués Terminé.", categorie: "progression", palier: "diamant" },
  { id: "termines_legende", label: "La Légende Vivante", description: "35 jeux marqués Terminé. Ta pile de honte a une pile de honte.", categorie: "progression", palier: "legende" },

  // --- Collection, toutes plateformes confondues (6 paliers) --------------
  { id: "collection_bronze", label: "Petite bibliothèque", description: "10 jeux, toutes plateformes.", categorie: "collection", palier: "bronze" },
  { id: "collection_argent", label: "Bibliothèque naissante", description: "25 jeux, toutes plateformes.", categorie: "collection", palier: "argent" },
  { id: "collection_or", label: "Belle collection", description: "50 jeux, toutes plateformes.", categorie: "collection", palier: "or" },
  { id: "collection_platine", label: "Grande collection", description: "100 jeux, toutes plateformes.", categorie: "collection", palier: "platine" },
  { id: "collection_diamant", label: "Bibliothèque monumentale", description: "200 jeux, toutes plateformes.", categorie: "collection", palier: "diamant" },
  { id: "collection_legende", label: "La Collection Ultime", description: "350 jeux, toutes plateformes. Tu n'as plus le temps de les finir, seulement de les compter.", categorie: "collection", palier: "legende" },

  // --- Défis personnalisés relevés (5 paliers) -----------------------------
  { id: "defis_bronze", label: "Premier défi", description: "1 défi personnalisé relevé.", categorie: "progression", palier: "bronze" },
  { id: "defis_argent", label: "Bonne dynamique", description: "3 défis relevés.", categorie: "progression", palier: "argent" },
  { id: "defis_or", label: "Habitué des défis", description: "5 défis relevés.", categorie: "progression", palier: "or" },
  { id: "defis_platine", label: "Chasseur de défis", description: "10 défis relevés.", categorie: "progression", palier: "platine" },
  { id: "defis_diamant", label: "Le Maître des défis", description: "20 défis relevés. Rien ne t'échappe.", categorie: "progression", palier: "diamant" },

  // --- Jeux notés (5 paliers) ----------------------------------------------
  { id: "notes_bronze", label: "Premier avis", description: "1 jeu noté.", categorie: "progression", palier: "bronze" },
  { id: "notes_argent", label: "Amateur éclairé", description: "5 jeux notés.", categorie: "progression", palier: "argent" },
  { id: "notes_or", label: "Critique amateur", description: "10 jeux notés.", categorie: "progression", palier: "or" },
  { id: "notes_platine", label: "Critique confirmé", description: "25 jeux notés.", categorie: "progression", palier: "platine" },
  { id: "notes_diamant", label: "Le Metacritic Humain", description: "50 jeux notés. Metacritic t'appelle en pleine nuit.", categorie: "progression", palier: "diamant" },

  // --- Jeux abandonnés (4 paliers) — assumé, pas honteux ------------------
  { id: "abandonnes_bronze", label: "Girouette", description: "As abandonné un premier jeu. Pas grave, il y en a d'autres.", categorie: "progression", palier: "bronze" },
  { id: "abandonnes_argent", label: "Papillon", description: "3 jeux abandonnés. Tu butines, tu ne t'attaches pas.", categorie: "progression", palier: "argent" },
  { id: "abandonnes_or", label: "Cœur volage", description: "5 jeux abandonnés. Ton cœur a de la place pour beaucoup de monde.", categorie: "progression", palier: "or" },
  { id: "abandonnes_platine", label: "L'Increvable Abandonneur", description: "10 jeux abandonnés. Persévérer, très peu pour toi.", categorie: "progression", palier: "platine" },

  // --- Descriptions écrites (4 paliers) -----------------------------------
  { id: "descriptions_bronze", label: "Premier mot", description: "As écrit une description sur 1 jeu.", categorie: "progression", palier: "bronze" },
  { id: "descriptions_argent", label: "Petit rédacteur", description: "As écrit une description sur 5 jeux.", categorie: "progression", palier: "argent" },
  { id: "descriptions_or", label: "Archiviste", description: "As écrit une description sur 10 jeux.", categorie: "progression", palier: "or" },
  { id: "descriptions_platine", label: "L'Encyclopédiste", description: "As écrit une description sur 20 jeux.", categorie: "progression", palier: "platine" },

  // --- Commentaires écrits (4 paliers) -------------------------------------
  { id: "commentaires_bronze", label: "Premier avis perso", description: "As écrit un commentaire sur 1 jeu.", categorie: "progression", palier: "bronze" },
  { id: "commentaires_argent", label: "Chroniqueur", description: "As écrit un commentaire sur 5 jeux.", categorie: "progression", palier: "argent" },
  { id: "commentaires_or", label: "Grand Chroniqueur", description: "As écrit un commentaire sur 10 jeux.", categorie: "progression", palier: "or" },
  { id: "commentaires_platine", label: "Le Bloggeur Compulsif", description: "As écrit un commentaire sur 20 jeux.", categorie: "progression", palier: "platine" },

  // --- Tags utilisés (4 paliers) -------------------------------------------
  { id: "tags_bronze", label: "Premier tag", description: "As tagué 1 jeu.", categorie: "progression", palier: "bronze" },
  { id: "tags_argent", label: "Étiqueteur", description: "As tagué 10 jeux.", categorie: "progression", palier: "argent" },
  { id: "tags_or", label: "Étiqueteur compulsif", description: "As tagué 25 jeux. Tout doit être classé, rangé, nommé.", categorie: "progression", palier: "or" },
  { id: "tags_platine", label: "L'Archiviste Absolu", description: "As tagué 50 jeux.", categorie: "progression", palier: "platine" },

  // --- Jeux "Envie de faire" (4 paliers) ------------------------------------
  { id: "envie_bronze", label: "Une envie", description: "1 jeu marqué Envie de faire.", categorie: "progression", palier: "bronze" },
  { id: "envie_argent", label: "Liste qui pousse", description: "5 jeux marqués Envie de faire.", categorie: "progression", palier: "argent" },
  { id: "envie_or", label: "Wishlist active", description: "10 jeux marqués Envie de faire.", categorie: "progression", palier: "or" },
  { id: "envie_platine", label: "La Pile Interminable", description: "20 jeux marqués Envie de faire.", categorie: "progression", palier: "platine" },

  // --- Jeux "Coup de cœur" (4 paliers) --------------------------------------
  { id: "coupdecoeur_bronze", label: "Coup de cœur", description: "1 jeu marqué Coup de cœur.", categorie: "special", palier: "bronze" },
  { id: "coupdecoeur_argent", label: "Petit romantique", description: "3 jeux marqués Coup de cœur.", categorie: "special", palier: "argent" },
  { id: "coupdecoeur_or", label: "Grand sentimental", description: "5 jeux marqués Coup de cœur.", categorie: "special", palier: "or" },
  { id: "coupdecoeur_platine", label: "Le Cœur qui Déborde", description: "10 jeux marqués Coup de cœur. Tout te touche.", categorie: "special", palier: "platine" },

  // --- Jeux à 100% (4 paliers) -----------------------------------------------
  { id: "cent_bronze", label: "Perfectionniste", description: "1 jeu marqué à 100%.", categorie: "special", palier: "bronze" },
  { id: "cent_argent", label: "Perfectionniste confirmé", description: "3 jeux marqués à 100%.", categorie: "special", palier: "argent" },
  { id: "cent_or", label: "Machine à 100%", description: "5 jeux marqués à 100%.", categorie: "special", palier: "or" },
  { id: "cent_platine", label: "Platine à Volonté", description: "10 jeux marqués à 100%.", categorie: "special", palier: "platine" },

  // --- Plateformes actives (5 paliers) ---------------------------------------
  { id: "plateformes_bronze", label: "Explorateur", description: "Jeux sur 2 plateformes différentes.", categorie: "collection", palier: "bronze" },
  { id: "plateformes_argent", label: "Nomade numérique", description: "Jeux sur 3 plateformes différentes.", categorie: "collection", palier: "argent" },
  { id: "plateformes_or", label: "Multi-plateforme", description: "Jeux sur 4 plateformes différentes.", categorie: "collection", palier: "or" },
  { id: "plateformes_platine", label: "Collectionneur de consoles", description: "Jeux sur 5 plateformes différentes.", categorie: "collection", palier: "platine" },
  { id: "plateformes_diamant", label: "Le Musée Vivant", description: "Jeux sur 6 plateformes différentes ou plus.", categorie: "collection", palier: "diamant" },

  // --- Heures jouées cumulées, saisies manuellement (5 paliers) --------------
  { id: "heures_bronze", label: "Premières heures", description: "10 heures de jeu cumulées (saisies manuellement).", categorie: "progression", palier: "bronze" },
  { id: "heures_argent", label: "Joueur régulier", description: "50 heures de jeu cumulées.", categorie: "progression", palier: "argent" },
  { id: "heures_or", label: "Joueur assidu", description: "100 heures de jeu cumulées.", categorie: "progression", palier: "or" },
  { id: "heures_platine", label: "Vétéran", description: "250 heures de jeu cumulées.", categorie: "progression", palier: "platine" },
  { id: "heures_diamant", label: "La Vie Dédiée au Jeu", description: "500 heures de jeu cumulées.", categorie: "progression", palier: "diamant" },

  // --- Statuts personnalisés créés (3 paliers) --------------------------------
  { id: "statuts_bronze", label: "Décorateur d'intérieur", description: "As créé un statut personnalisé. Ta bibliothèque, tes règles.", categorie: "special", palier: "bronze" },
  { id: "statuts_argent", label: "Architecte d'intérieur", description: "As créé 3 statuts personnalisés.", categorie: "special", palier: "argent" },
  { id: "statuts_or", label: "Designer en Chef", description: "As créé 5 statuts personnalisés.", categorie: "special", palier: "or" },

  // --- Jours de la semaine (7 succès simples) ---------------------------------
  { id: "jour_dimanche", label: "Tirage du dimanche", description: "Lancer un tirage un dimanche.", categorie: "special" },
  { id: "jour_lundi", label: "Tirage du lundi", description: "Lancer un tirage un lundi. Courage.", categorie: "special" },
  { id: "jour_mardi", label: "Tirage du mardi", description: "Lancer un tirage un mardi.", categorie: "special" },
  { id: "jour_mercredi", label: "Tirage du mercredi", description: "Lancer un tirage un mercredi.", categorie: "special" },
  { id: "jour_jeudi", label: "Tirage du jeudi", description: "Lancer un tirage un jeudi.", categorie: "special" },
  { id: "jour_vendredi", label: "Tirage du vendredi", description: "Lancer un tirage un vendredi. Le week-end approche.", categorie: "special" },
  { id: "jour_samedi", label: "Tirage du samedi", description: "Lancer un tirage un samedi.", categorie: "special" },

  // --- Horaires (5 succès simples) ---------------------------------------------
  { id: "oiseau_de_nuit", label: "Oiseau de nuit", description: "Lancer un tirage entre minuit et 5h du matin.", categorie: "special" },
  { id: "leve_tot", label: "Lève-tôt", description: "Lancer un tirage avant 8h du matin. Respect.", categorie: "special" },
  { id: "pause_dejeuner", label: "Pause déjeuner", description: "Lancer un tirage entre midi et 14h.", categorie: "special" },
  { id: "apero", label: "L'heure de l'apéro", description: "Lancer un tirage entre 18h et 20h.", categorie: "special" },
  { id: "prime_time", label: "Prime time", description: "Lancer un tirage entre 20h et 23h.", categorie: "special" },

  // --- Divers (succès simples) --------------------------------------------------
  { id: "deja_vu", label: "Déjà-vu", description: "Le même jeu tiré deux fois d'affilée. Le destin insiste.", categorie: "special" },
  { id: "triple_deja_vu", label: "Le Destin Insiste Vraiment", description: "Le même jeu tiré trois fois d'affilée.", categorie: "special" },
  { id: "marathonien", label: "Marathonien", description: "Lancer une session de 4 heures ou plus. Prévois de l'eau.", categorie: "special" },
  { id: "eclair", label: "Session éclair", description: "Lancer une session de 10 minutes ou moins. Rapide et efficace.", categorie: "special" },
  { id: "chaos_assume", label: "Chaos assumé", description: "Lancer un tirage avec le pool anti-répétition désactivé.", categorie: "special" },
  { id: "bibliotheque_parfaite", label: "Bibliothèque Parfaite", description: "Tous tes jeux (au moins 5) sont marqués Terminé sur une plateforme.", categorie: "special" },
  { id: "zero_abandon", label: "Zéro Abandon", description: "10 jeux terminés ou plus, et aucun abandonné.", categorie: "special" },

  // --- Notes extrêmes et goûts (succès simples) ---------------------------
  { id: "note_parfaite", label: "Chef-d'œuvre", description: "Mettre la note maximale à un jeu.", categorie: "special" },
  { id: "note_minimale", label: "Sans pitié", description: "Mettre la note minimale à un jeu. Ça arrive.", categorie: "special" },
  { id: "cinq_notes_max", label: "Bon public", description: "5 jeux notés au maximum. Tu aimes vraiment tout.", categorie: "special" },
  { id: "moyenne_elevee", label: "Optimiste", description: "Moyenne de tes notes supérieure à 4 (au moins 10 jeux notés).", categorie: "special" },
  { id: "moyenne_basse", label: "Difficile à satisfaire", description: "Moyenne de tes notes inférieure à 2,5 (au moins 10 jeux notés).", categorie: "special" },

  // --- Semaine complète (succès simple, dépend des 7 jours) ---------------
  { id: "semaine_complete", label: "La Semaine Parfaite", description: "Avoir lancé un tirage chaque jour de la semaine (les 7).", categorie: "tirage" },

  // --- Régularité / fidélité (paliers) -------------------------------------
  { id: "fidele_bronze", label: "Habitué", description: "Tirages répartis sur 7 jours différents.", categorie: "tirage", palier: "bronze" },
  { id: "fidele_argent", label: "Fidèle", description: "Tirages répartis sur 30 jours différents.", categorie: "tirage", palier: "argent" },
  { id: "fidele_or", label: "Increvable", description: "Tirages répartis sur 100 jours différents.", categorie: "tirage", palier: "or" },

  // --- Complétion de la bibliothèque (paliers) ------------------------------
  { id: "progression_bronze", label: "Ça avance", description: "25% de ta bibliothèque terminée (au moins 8 jeux).", categorie: "progression", palier: "bronze" },
  { id: "progression_argent", label: "À mi-chemin", description: "50% de ta bibliothèque terminée (au moins 8 jeux).", categorie: "progression", palier: "argent" },
  { id: "progression_or", label: "Presque au bout", description: "75% de ta bibliothèque terminée (au moins 8 jeux).", categorie: "progression", palier: "or" },

  // --- Divers ---------------------------------------------------------------
  { id: "jamais_deux_fois", label: "Jamais deux fois", description: "20 tirages, tous des jeux différents.", categorie: "tirage" },
  { id: "collection_bien_rangee", label: "Collection bien rangée", description: "Tous tes jeux (au moins 10) ont une jaquette.", categorie: "collection" },
  { id: "grand_soir", label: "Le Grand Soir", description: "5 tirages ou plus dans la même journée.", categorie: "tirage" },
  { id: "tout_defis", label: "Rien laissé au hasard", description: "Un jeu avec au moins 5 défis, tous complétés.", categorie: "progression" },

  // --- Vague v27 : rythme, contrastes, jalons ---------------------------------
  { id: "serie_3", label: "Sur une lancée", description: "Tirer au moins 1 jeu par jour, 3 jours d'affilée.", categorie: "tirage" },
  { id: "serie_7", label: "Semaine sans faute", description: "Tirer au moins 1 jeu par jour, 7 jours d'affilée.", categorie: "tirage" },
  { id: "grand_ecart", label: "Le grand écart", description: "Avoir un jeu noté 5 et un jeu noté 1 dans la même bibliothèque.", categorie: "special" },
  { id: "bibliotheque_annotee", label: "Bibliothèque annotée", description: "10 jeux ayant à la fois une note ET un commentaire.", categorie: "progression" },
  { id: "polyglotte", label: "Polyglotte", description: "Au moins 10 tags différents utilisés dans la bibliothèque.", categorie: "collection" },
  { id: "grande_illustration", label: "Galerie complète", description: "25 jeux avec une jaquette.", categorie: "collection" },
  { id: "retour_gagnant", label: "Retour gagnant", description: "Relancer un tirage après plus de 30 jours sans en faire.", categorie: "tirage" },
  { id: "nuit_blanche", label: "Nuit blanche", description: "3 tirages ou plus entre minuit et 5h la même nuit.", categorie: "special" },

  // --- Vague v30 : jalons, patience, curiosité --------------------------------
  { id: "premier_pas", label: "Premier pas", description: "Ajouter ton tout premier jeu. Ça commence ici.", categorie: "collection" },
  { id: "sans_filet", label: "Sans filet", description: "Lancer un tirage sur une bibliothèque de 3 jeux ou moins.", categorie: "tirage" },
  { id: "abondance", label: "Trop de choix", description: "Lancer un tirage avec 100 jeux ou plus dans le pool.", categorie: "tirage" },
  { id: "cycle_complet", label: "Tour complet", description: "Vider entièrement le pool anti-répétition d'une plateforme.", categorie: "tirage" },
  { id: "week_end", label: "Guerrier du week-end", description: "Tirer un samedi ET un dimanche.", categorie: "tirage" },
  { id: "matinal_nocturne", label: "Cycle inversé", description: "Avoir tiré avant 8h et après minuit. Ton sommeil te déteste.", categorie: "special" },
  { id: "note_moyenne", label: "Juste milieu", description: "10 jeux notés exactement 3. La tiédeur assumée.", categorie: "progression" },
  { id: "un_seul_amour", label: "Monogame", description: "20 tirages, dont la moitié sur le même jeu.", categorie: "special" },

  // --- Vague v1.0-b : diversité, extrêmes, habitudes -------------------------
  { id: "eclectique", label: "Éclectique", description: "Des jeux dans 4 statuts différents en même temps.", categorie: "collection" },
  { id: "moitie_notee", label: "Bon élève", description: "Au moins 50% de la bibliothèque notée (min. 20 jeux).", categorie: "progression" },
  { id: "marathon_defis", label: "Bourreau de travail", description: "30 défis relevés au total.", categorie: "progression" },
  { id: "jamais_sans_tag", label: "Maniaque du rangement", description: "Au moins 80% des jeux ont un tag (min. 20 jeux).", categorie: "collection" },
  { id: "double_cent", label: "Deux fois parfait", description: "2 jeux à 100% le même jour.", categorie: "special" },
  { id: "reveil_brutal", label: "Réveil brutal", description: "Un tirage entre 5h et 6h du matin.", categorie: "special" },
  { id: "seance_longue", label: "Séance longue", description: "10 tirages ou plus dans la même journée.", categorie: "tirage" },
  { id: "fidele_plateforme", label: "Loyauté", description: "30 tirages ou plus sur une seule et même plateforme.", categorie: "tirage" },
  { id: "tout_essaye", label: "Tout essayé", description: "Avoir joué au moins un jeu de chaque statut intégré.", categorie: "progression" },
  { id: "bibliotheque_zen", label: "Bibliothèque zen", description: "Aucun jeu « en cours » alors que 10+ sont terminés.", categorie: "progression" },


  // --- Ajouts v26 : tous dérivés de données déjà présentes ------------------
  { id: "bibliophile", label: "Bibliophile", description: "Un jeu avec une description de plus de 200 caractères.", categorie: "progression" },
  { id: "tag_maniaque", label: "Tag-maniaque", description: "Un jeu avec au moins 5 tags différents.", categorie: "progression" },
  { id: "defis_ambitieux", label: "Ambitieux", description: "Un jeu avec au moins 10 défis (complétés ou non).", categorie: "progression" },
  { id: "collection_notee", label: "Tout est jugé", description: "Au moins 20 jeux, tous notés.", categorie: "collection" },
  { id: "gros_morceau", label: "Gros morceau", description: "Un jeu avec 100 heures de jeu ou plus.", categorie: "progression" },
  { id: "petit_plaisir", label: "Petit plaisir", description: "Un jeu terminé en moins de 5 heures.", categorie: "progression" },
  { id: "polyvalent", label: "Polyvalent", description: "Au moins un jeu dans chacun des 5 statuts d'origine.", categorie: "collection" },
  { id: "cote_a_cote", label: "Le Duel", description: "Utiliser le tirage multiple (2 jeux ou plus d'un coup).", categorie: "tirage" },
  { id: "engage", label: "Engagé", description: "Lancer un tirage en mode roulette russe.", categorie: "tirage" },
  { id: "selectif", label: "Sélectif", description: "Lancer un tirage avec des filtres actifs.", categorie: "tirage" },
  { id: "esthete", label: "Esthète", description: "Avoir essayé au moins 5 thèmes différents.", categorie: "special" },
  { id: "veteran_app", label: "Collectionneur de trophées", description: "Avoir débloqué 50 succès.", categorie: "special" },
  { id: "presque_tout", label: "Presque tout", description: "Avoir débloqué 90 succès.", categorie: "special" },
];

export interface StatsPourBadges {
  nombreTirages: number;
  jeuxTermines: number;
  jeux100: number;
  jeuxAbandonnes: number;
  defisComplets: number;
  jeuxCoupDeCoeur: number;
  jeuxEnvieDeFaire: number;
  jeuxNotes: number;
  totalJeux: number;
  plateformesAvecJeux: number;
  jeuxAvecDescription: number;
  jeuxAvecCommentaire: number;
  jeuxAvecTag: number;
  nombreStatutsPersonnalises: number;
  heuresJoueesTotal: number;
  joursDeSemaineTires: Set<number>; // 0=dimanche ... 6=samedi (Date.getDay())
  aTireDeNuit: boolean; // entre minuit et 5h
  aTireTresTot: boolean; // entre 5h et 8h
  aTirePauseDejeuner: boolean; // entre 12h et 14h
  aTireApero: boolean; // entre 18h et 20h
  aTirePrimeTime: boolean; // entre 20h et 23h
  aMemeJeuConsecutif: boolean; // les 2 dernières entrées de l'historique sont le même jeu
  aTripleMemeJeuConsecutif: boolean; // les 3 dernières entrées sont le même jeu
  aObjectifMarathon: boolean; // objectif de session >= 240 min utilisé au moins une fois
  aObjectifEclair: boolean; // objectif de session <= 10 min utilisé au moins une fois
  aTireSansAntiRepetition: boolean; // au moins un tirage avec eviterRepetitions désactivé
  aBibliothequeParfaite: boolean; // au moins une plateforme avec 5+ jeux tous Terminé
  // Ajoutés en v22 — tous dérivés de données déjà présentes, aucun nouveau
  // champ à persister.
  noteMax: number; // note la plus haute attribuée (0 si aucune)
  noteMin: number; // note la plus basse attribuée parmi les jeux notés (0 si aucun)
  jeuxNoteMax: number; // nombre de jeux à la note maximale (5)
  moyenneNotes: number; // moyenne des notes des jeux notés (0 si aucun)
  joursDistinctsTires: number; // nombre de dates calendaires distinctes avec au moins un tirage
  pctTermine: number; // part de la bibliothèque marquée Terminé (0-100)
  tousJeuxDifferents: boolean; // 20+ tirages, tous sur des jeux distincts
  tousAvecJaquette: boolean; // 10+ jeux, tous avec une cover
  maxTiragesUnJour: number; // plus grand nombre de tirages sur une même journée
  aJeuTousDefisComplets: boolean; // un jeu avec 5+ défis, tous cochés
  // Ajoutés en v26.
  aLongueDescription: boolean; // un jeu avec 200+ caractères de description
  aBeaucoupDeTags: boolean; // un jeu avec 5+ tags
  aBeaucoupDeDefis: boolean; // un jeu avec 10+ défis
  tousNotes: boolean; // 20+ jeux, tous notés
  aGrosMorceau: boolean; // un jeu à 100h+
  aPetitPlaisir: boolean; // un jeu terminé en moins de 5h
  statutsCouverts: number; // nombre de statuts distincts présents dans la bibliothèque
  nbBadgesDebloques: number; // fourni par l'appelant (badges.json)
  aUtiliseTirageMultiple: boolean;
  aUtiliseRouletteRusse: boolean;
  aUtiliseFiltres: boolean;
  nbThemesEssayes: number;
  // v27
  serieJoursMax: number; // plus longue série de jours consécutifs avec tirage
  aNotesExtremes: boolean; // au moins un 5 ET un 1
  jeuxNotesEtCommentes: number;
  tagsDistincts: number;
  jeuxAvecJaquette: number;
  aRepriseApresPause: boolean; // un tirage après 30+ jours d'inactivité
  maxTiragesUneNuit: number; // tirages entre 0h et 5h sur une même nuit
  // v30
  poolAuTirage: number; // taille du pool lors du dernier tirage
  aVidePool: boolean; // au moins une plateforme entièrement tirée
  aTireSamedi: boolean;
  aTireDimanche: boolean;
  jeuxNotesTrois: number;
  partMaxUnSeulJeu: number; // part (0-1) du jeu le plus tiré dans l'historique
  // v1.0-b
  statutsDistincts: number; // nombre de statuts différents présents
  partNotee: number; // part (0-1) de la bibliothèque notée
  partTaguee: number; // part (0-1) de la bibliothèque avec au moins un tag
  maxCentUnJour: number; // jeux passés à 100% le même jour — approximé, cf. calcul
  aTireAubeStricte: boolean; // entre 5h et 6h
  maxTiragesUnePlateforme: number;
  jeuxEnCours: number;
}

/** Agrège les données nécessaires à l'évaluation des succès. `bibliotheques`
 * doit couvrir TOUTES les plateformes (pas seulement celle active) pour que
 * les succès "collection"/"plateformes" soient justes.
 * `nombreStatutsPersonnalises` : `config.statuts.filter(s => !s.integre).length`.
 * `aTireSansAntiRepetition` : à combiner côté appelant avec
 * `!config.eviterRepetitions` au moment du tirage (pas déductible de
 * l'historique seul, qui ne garde pas ce réglage). */
/** `usage` : données non déductibles de la bibliothèque/l'historique
 * (thèmes essayés, fonctionnalités utilisées) — voir AppConfig v26. */
export interface UsageAppli {
  nbBadgesDebloques?: number;
  nbThemesEssayes?: number;
  aUtiliseTirageMultiple?: boolean;
  aUtiliseRouletteRusse?: boolean;
  aUtiliseFiltres?: boolean;
}

export function calculerStatsPourBadges(
  historique: Historique,
  bibliotheques: GameLibrary[],
  nombreStatutsPersonnalises = 0,
  aTireSansAntiRepetition = false,
  usage: UsageAppli = {}
): StatsPourBadges {
  const tousLesJeux = bibliotheques.flatMap((b) => b.jeux);
  const heures = historique.entrees.map((e) => new Date(e.drawnAt).getHours());
  const jours = new Set(historique.entrees.map((e) => new Date(e.drawnAt).getDay()));
  const deuxDernieres = historique.entrees.slice(-2);
  const troisDernieres = historique.entrees.slice(-3);
  const notes = tousLesJeux.filter((j) => j.note > 0).map((j) => j.note);
  // Date calendaire locale (pas l'ISO complet) — deux tirages le même jour
  // à des heures différentes comptent pour une seule journée.
  const datesCalendaires = historique.entrees.map((e) => new Date(e.drawnAt).toDateString());
  const datesDistinctes = new Set(datesCalendaires);
  const tagsUniques = new Set<string>();
  for (const j of tousLesJeux) {
    for (const t of j.tags.split(",").map((x) => x.trim().toLowerCase()).filter(Boolean)) tagsUniques.add(t);
  }

  const tiragesParJour: Record<string, number> = {};
  for (const d of datesCalendaires) tiragesParJour[d] = (tiragesParJour[d] ?? 0) + 1;

  // Série de jours consécutifs avec au moins un tirage, et plus grand écart
  // entre deux tirages (pour "Retour gagnant"). Les deux se calculent sur la
  // même liste de jours triée — autant la parcourir une seule fois.
  const joursTries = [...datesDistinctes].map((d) => new Date(d).getTime()).sort((a, b) => a - b);
  let serieMax = joursTries.length > 0 ? 1 : 0;
  let serieCourante = joursTries.length > 0 ? 1 : 0;
  let ecartMaxJours = 0;
  const UN_JOUR = 86_400_000;
  for (let i = 1; i < joursTries.length; i++) {
    const ecart = Math.round((joursTries[i] - joursTries[i - 1]) / UN_JOUR);
    if (ecart > ecartMaxJours) ecartMaxJours = ecart;
    if (ecart === 1) {
      serieCourante++;
      if (serieCourante > serieMax) serieMax = serieCourante;
    } else {
      serieCourante = 1;
    }
  }

  // Tirages nocturnes (0h-5h) regroupés par nuit.
  const parNuit: Record<string, number> = {};
  for (const e of historique.entrees) {
    const d = new Date(e.drawnAt);
    if (d.getHours() < 5) {
      const k = d.toDateString();
      parNuit[k] = (parNuit[k] ?? 0) + 1;
    }
  }
  const maxNuit = Math.max(0, ...Object.values(parNuit));

  return {
    nombreTirages: historique.entrees.length,
    jeuxTermines: tousLesJeux.filter((j) => j.statut === "Termine").length,
    jeux100: tousLesJeux.filter((j) => j.complete100).length,
    jeuxAbandonnes: tousLesJeux.filter((j) => j.statut === "Abandonne").length,
    defisComplets: tousLesJeux.reduce((somme, j) => somme + j.defis.filter((d) => d.complete).length, 0),
    jeuxCoupDeCoeur: tousLesJeux.filter((j) => j.coupDeCoeur).length,
    jeuxEnvieDeFaire: tousLesJeux.filter((j) => j.envieDeFaire).length,
    jeuxNotes: tousLesJeux.filter((j) => j.note > 0).length,
    totalJeux: tousLesJeux.length,
    plateformesAvecJeux: bibliotheques.filter((b) => b.jeux.length > 0).length,
    jeuxAvecDescription: tousLesJeux.filter((j) => j.description.trim().length > 0).length,
    jeuxAvecCommentaire: tousLesJeux.filter((j) => j.commentaire.trim().length > 0).length,
    jeuxAvecTag: tousLesJeux.filter((j) => j.tags.trim().length > 0).length,
    nombreStatutsPersonnalises,
    heuresJoueesTotal: tousLesJeux.reduce((somme, j) => somme + (j.heuresJouees ?? 0), 0),
    joursDeSemaineTires: jours,
    aTireDeNuit: heures.some((h) => h >= 0 && h < 5),
    aTireTresTot: heures.some((h) => h >= 5 && h < 8),
    aTirePauseDejeuner: heures.some((h) => h >= 12 && h < 14),
    aTireApero: heures.some((h) => h >= 18 && h < 20),
    aTirePrimeTime: heures.some((h) => h >= 20 && h < 23),
    aMemeJeuConsecutif: deuxDernieres.length === 2 && deuxDernieres[0].gameId === deuxDernieres[1].gameId,
    aTripleMemeJeuConsecutif:
      troisDernieres.length === 3 && troisDernieres[0].gameId === troisDernieres[1].gameId && troisDernieres[1].gameId === troisDernieres[2].gameId,
    aObjectifMarathon: historique.entrees.some((e) => (e.goalMinutes ?? 0) >= 240),
    aObjectifEclair: historique.entrees.some((e) => e.goalMinutes !== null && e.goalMinutes <= 10),
    aTireSansAntiRepetition,
    aBibliothequeParfaite: bibliotheques.some((b) => b.jeux.length >= 5 && b.jeux.every((j) => j.statut === "Termine")),
    noteMax: notes.length > 0 ? Math.max(...notes) : 0,
    noteMin: notes.length > 0 ? Math.min(...notes) : 0,
    jeuxNoteMax: notes.filter((n) => n >= 5).length,
    moyenneNotes: notes.length > 0 ? notes.reduce((a, b) => a + b, 0) / notes.length : 0,
    joursDistinctsTires: datesDistinctes.size,
    pctTermine: tousLesJeux.length > 0 ? (tousLesJeux.filter((j) => j.statut === "Termine").length / tousLesJeux.length) * 100 : 0,
    tousJeuxDifferents:
      historique.entrees.length >= 20 && new Set(historique.entrees.map((e) => e.gameId)).size === historique.entrees.length,
    tousAvecJaquette: tousLesJeux.length >= 10 && tousLesJeux.every((j) => !!j.cover),
    maxTiragesUnJour: Math.max(0, ...Object.values(tiragesParJour)),
    aJeuTousDefisComplets: tousLesJeux.some((j) => j.defis.length >= 5 && j.defis.every((d) => d.complete)),
    aLongueDescription: tousLesJeux.some((j) => j.description.trim().length >= 200),
    aBeaucoupDeTags: tousLesJeux.some((j) => j.tags.split(",").map((t) => t.trim()).filter(Boolean).length >= 5),
    aBeaucoupDeDefis: tousLesJeux.some((j) => j.defis.length >= 10),
    tousNotes: tousLesJeux.length >= 20 && tousLesJeux.every((j) => j.note > 0),
    aGrosMorceau: tousLesJeux.some((j) => (j.heuresJouees ?? 0) >= 100),
    aPetitPlaisir: tousLesJeux.some((j) => j.statut === "Termine" && j.heuresJouees !== null && j.heuresJouees > 0 && j.heuresJouees < 5),
    statutsCouverts: new Set(tousLesJeux.map((j) => j.statut)).size,
    nbBadgesDebloques: usage.nbBadgesDebloques ?? 0,
    aUtiliseTirageMultiple: usage.aUtiliseTirageMultiple ?? false,
    aUtiliseRouletteRusse: usage.aUtiliseRouletteRusse ?? false,
    aUtiliseFiltres: usage.aUtiliseFiltres ?? false,
    nbThemesEssayes: usage.nbThemesEssayes ?? 0,
    serieJoursMax: serieMax,
    aNotesExtremes: notes.includes(5) && notes.includes(1),
    jeuxNotesEtCommentes: tousLesJeux.filter((j) => j.note > 0 && j.commentaire.trim().length > 0).length,
    tagsDistincts: tagsUniques.size,
    jeuxAvecJaquette: tousLesJeux.filter((j) => !!j.cover).length,
    aRepriseApresPause: ecartMaxJours >= 30,
    maxTiragesUneNuit: maxNuit,
    poolAuTirage: tousLesJeux.length,
    aVidePool: bibliotheques.some((b) => b.jeux.length > 0 && b.jeux.every((j) => j.dejaFait)),
    aTireSamedi: jours.has(6),
    aTireDimanche: jours.has(0),
    jeuxNotesTrois: tousLesJeux.filter((j) => j.note === 3).length,
    statutsDistincts: new Set(tousLesJeux.map((j) => j.statut)).size,
    partNotee: tousLesJeux.length > 0 ? tousLesJeux.filter((j) => j.note > 0).length / tousLesJeux.length : 0,
    partTaguee: tousLesJeux.length > 0 ? tousLesJeux.filter((j) => j.tags.trim().length > 0).length / tousLesJeux.length : 0,
    // Approximation assumée : l'app ne date pas le passage à 100%, on ne peut
    // donc pas savoir si deux jeux l'ont été le MÊME jour. On se rabat sur
    // "au moins 2 jeux à 100%", ce qui reste un jalon honnête.
    maxCentUnJour: tousLesJeux.filter((j) => j.complete100).length,
    aTireAubeStricte: heures.some((h) => h >= 5 && h < 6),
    maxTiragesUnePlateforme: (() => {
      const parPlateforme: Record<string, number> = {};
      for (const e of historique.entrees) parPlateforme[e.platformId] = (parPlateforme[e.platformId] ?? 0) + 1;
      return Object.keys(parPlateforme).length > 0 ? Math.max(...Object.values(parPlateforme)) : 0;
    })(),
    jeuxEnCours: tousLesJeux.filter((j) => j.statut === "EnCours").length,
    partMaxUnSeulJeu: (() => {
      if (historique.entrees.length === 0) return 0;
      const parJeu: Record<string, number> = {};
      for (const e of historique.entrees) parJeu[e.gameId] = (parJeu[e.gameId] ?? 0) + 1;
      return Math.max(...Object.values(parJeu)) / historique.entrees.length;
    })(),
  };
}

/** Ids des succès que ces stats suffisent à débloquer (indépendamment de ce
 * qui est déjà enregistré comme débloqué — cf. nouveauxBadges). */
export function badgesDebloquables(stats: StatsPourBadges): string[] {
  const ids: string[] = [];

  if (stats.nombreTirages >= 10) ids.push("tirages_bronze");
  if (stats.nombreTirages >= 25) ids.push("tirages_argent");
  if (stats.nombreTirages >= 50) ids.push("tirages_or");
  if (stats.nombreTirages >= 100) ids.push("tirages_platine");
  if (stats.nombreTirages >= 250) ids.push("tirages_diamant");
  if (stats.nombreTirages >= 500) ids.push("tirages_legende");

  if (stats.jeuxTermines >= 1) ids.push("termines_bronze");
  if (stats.jeuxTermines >= 3) ids.push("termines_argent");
  if (stats.jeuxTermines >= 5) ids.push("termines_or");
  if (stats.jeuxTermines >= 10) ids.push("termines_platine");
  if (stats.jeuxTermines >= 20) ids.push("termines_diamant");
  if (stats.jeuxTermines >= 35) ids.push("termines_legende");

  if (stats.totalJeux >= 10) ids.push("collection_bronze");
  if (stats.totalJeux >= 25) ids.push("collection_argent");
  if (stats.totalJeux >= 50) ids.push("collection_or");
  if (stats.totalJeux >= 100) ids.push("collection_platine");
  if (stats.totalJeux >= 200) ids.push("collection_diamant");
  if (stats.totalJeux >= 350) ids.push("collection_legende");

  if (stats.defisComplets >= 1) ids.push("defis_bronze");
  if (stats.defisComplets >= 3) ids.push("defis_argent");
  if (stats.defisComplets >= 5) ids.push("defis_or");
  if (stats.defisComplets >= 10) ids.push("defis_platine");
  if (stats.defisComplets >= 20) ids.push("defis_diamant");

  if (stats.jeuxNotes >= 1) ids.push("notes_bronze");
  if (stats.jeuxNotes >= 5) ids.push("notes_argent");
  if (stats.jeuxNotes >= 10) ids.push("notes_or");
  if (stats.jeuxNotes >= 25) ids.push("notes_platine");
  if (stats.jeuxNotes >= 50) ids.push("notes_diamant");

  if (stats.jeuxAbandonnes >= 1) ids.push("abandonnes_bronze");
  if (stats.jeuxAbandonnes >= 3) ids.push("abandonnes_argent");
  if (stats.jeuxAbandonnes >= 5) ids.push("abandonnes_or");
  if (stats.jeuxAbandonnes >= 10) ids.push("abandonnes_platine");

  if (stats.jeuxAvecDescription >= 1) ids.push("descriptions_bronze");
  if (stats.jeuxAvecDescription >= 5) ids.push("descriptions_argent");
  if (stats.jeuxAvecDescription >= 10) ids.push("descriptions_or");
  if (stats.jeuxAvecDescription >= 20) ids.push("descriptions_platine");

  if (stats.jeuxAvecCommentaire >= 1) ids.push("commentaires_bronze");
  if (stats.jeuxAvecCommentaire >= 5) ids.push("commentaires_argent");
  if (stats.jeuxAvecCommentaire >= 10) ids.push("commentaires_or");
  if (stats.jeuxAvecCommentaire >= 20) ids.push("commentaires_platine");

  if (stats.jeuxAvecTag >= 1) ids.push("tags_bronze");
  if (stats.jeuxAvecTag >= 10) ids.push("tags_argent");
  if (stats.jeuxAvecTag >= 25) ids.push("tags_or");
  if (stats.jeuxAvecTag >= 50) ids.push("tags_platine");

  if (stats.jeuxEnvieDeFaire >= 1) ids.push("envie_bronze");
  if (stats.jeuxEnvieDeFaire >= 5) ids.push("envie_argent");
  if (stats.jeuxEnvieDeFaire >= 10) ids.push("envie_or");
  if (stats.jeuxEnvieDeFaire >= 20) ids.push("envie_platine");

  if (stats.jeuxCoupDeCoeur >= 1) ids.push("coupdecoeur_bronze");
  if (stats.jeuxCoupDeCoeur >= 3) ids.push("coupdecoeur_argent");
  if (stats.jeuxCoupDeCoeur >= 5) ids.push("coupdecoeur_or");
  if (stats.jeuxCoupDeCoeur >= 10) ids.push("coupdecoeur_platine");

  if (stats.jeux100 >= 1) ids.push("cent_bronze");
  if (stats.jeux100 >= 3) ids.push("cent_argent");
  if (stats.jeux100 >= 5) ids.push("cent_or");
  if (stats.jeux100 >= 10) ids.push("cent_platine");

  if (stats.plateformesAvecJeux >= 2) ids.push("plateformes_bronze");
  if (stats.plateformesAvecJeux >= 3) ids.push("plateformes_argent");
  if (stats.plateformesAvecJeux >= 4) ids.push("plateformes_or");
  if (stats.plateformesAvecJeux >= 5) ids.push("plateformes_platine");
  if (stats.plateformesAvecJeux >= 6) ids.push("plateformes_diamant");

  if (stats.heuresJoueesTotal >= 10) ids.push("heures_bronze");
  if (stats.heuresJoueesTotal >= 50) ids.push("heures_argent");
  if (stats.heuresJoueesTotal >= 100) ids.push("heures_or");
  if (stats.heuresJoueesTotal >= 250) ids.push("heures_platine");
  if (stats.heuresJoueesTotal >= 500) ids.push("heures_diamant");

  if (stats.nombreStatutsPersonnalises >= 1) ids.push("statuts_bronze");
  if (stats.nombreStatutsPersonnalises >= 3) ids.push("statuts_argent");
  if (stats.nombreStatutsPersonnalises >= 5) ids.push("statuts_or");

  const NOMS_JOURS = ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"];
  for (const j of stats.joursDeSemaineTires) ids.push(`jour_${NOMS_JOURS[j]}`);

  if (stats.aTireDeNuit) ids.push("oiseau_de_nuit");
  if (stats.aTireTresTot) ids.push("leve_tot");
  if (stats.aTirePauseDejeuner) ids.push("pause_dejeuner");
  if (stats.aTireApero) ids.push("apero");
  if (stats.aTirePrimeTime) ids.push("prime_time");
  if (stats.aMemeJeuConsecutif) ids.push("deja_vu");
  if (stats.aTripleMemeJeuConsecutif) ids.push("triple_deja_vu");
  if (stats.aObjectifMarathon) ids.push("marathonien");
  if (stats.aObjectifEclair) ids.push("eclair");
  if (stats.aTireSansAntiRepetition) ids.push("chaos_assume");
  if (stats.aBibliothequeParfaite) ids.push("bibliotheque_parfaite");
  if (stats.jeuxTermines >= 10 && stats.jeuxAbandonnes === 0) ids.push("zero_abandon");

  if (stats.noteMax >= 5) ids.push("note_parfaite");
  if (stats.noteMin > 0 && stats.noteMin <= 1) ids.push("note_minimale");
  if (stats.jeuxNoteMax >= 5) ids.push("cinq_notes_max");
  if (stats.jeuxNotes >= 10 && stats.moyenneNotes > 4) ids.push("moyenne_elevee");
  if (stats.jeuxNotes >= 10 && stats.moyenneNotes < 2.5) ids.push("moyenne_basse");

  if (stats.joursDeSemaineTires.size >= 7) ids.push("semaine_complete");
  if (stats.joursDistinctsTires >= 7) ids.push("fidele_bronze");
  if (stats.joursDistinctsTires >= 30) ids.push("fidele_argent");
  if (stats.joursDistinctsTires >= 100) ids.push("fidele_or");

  if (stats.totalJeux >= 8 && stats.pctTermine >= 25) ids.push("progression_bronze");
  if (stats.totalJeux >= 8 && stats.pctTermine >= 50) ids.push("progression_argent");
  if (stats.totalJeux >= 8 && stats.pctTermine >= 75) ids.push("progression_or");

  if (stats.tousJeuxDifferents) ids.push("jamais_deux_fois");
  if (stats.tousAvecJaquette) ids.push("collection_bien_rangee");
  if (stats.maxTiragesUnJour >= 5) ids.push("grand_soir");
  if (stats.aJeuTousDefisComplets) ids.push("tout_defis");
  if (stats.aLongueDescription) ids.push("bibliophile");
  if (stats.aBeaucoupDeTags) ids.push("tag_maniaque");
  if (stats.aBeaucoupDeDefis) ids.push("defis_ambitieux");
  if (stats.tousNotes) ids.push("collection_notee");
  if (stats.aGrosMorceau) ids.push("gros_morceau");
  if (stats.aPetitPlaisir) ids.push("petit_plaisir");
  if (stats.statutsCouverts >= 5) ids.push("polyvalent");
  if (stats.aUtiliseTirageMultiple) ids.push("cote_a_cote");
  if (stats.aUtiliseRouletteRusse) ids.push("engage");
  if (stats.aUtiliseFiltres) ids.push("selectif");
  if (stats.nbThemesEssayes >= 5) ids.push("esthete");
  if (stats.nbBadgesDebloques >= 50) ids.push("veteran_app");
  if (stats.nbBadgesDebloques >= 90) ids.push("presque_tout");

  if (stats.serieJoursMax >= 3) ids.push("serie_3");
  if (stats.serieJoursMax >= 7) ids.push("serie_7");
  if (stats.aNotesExtremes) ids.push("grand_ecart");
  if (stats.jeuxNotesEtCommentes >= 10) ids.push("bibliotheque_annotee");
  if (stats.tagsDistincts >= 10) ids.push("polyglotte");
  if (stats.jeuxAvecJaquette >= 25) ids.push("grande_illustration");
  if (stats.aRepriseApresPause) ids.push("retour_gagnant");
  if (stats.maxTiragesUneNuit >= 3) ids.push("nuit_blanche");

  if (stats.totalJeux >= 1) ids.push("premier_pas");
  if (stats.nombreTirages >= 1 && stats.poolAuTirage > 0 && stats.poolAuTirage <= 3) ids.push("sans_filet");
  if (stats.poolAuTirage >= 100 && stats.nombreTirages >= 1) ids.push("abondance");
  if (stats.aVidePool) ids.push("cycle_complet");
  if (stats.aTireSamedi && stats.aTireDimanche) ids.push("week_end");
  if (stats.aTireTresTot && stats.aTireDeNuit) ids.push("matinal_nocturne");
  if (stats.jeuxNotesTrois >= 10) ids.push("note_moyenne");
  if (stats.nombreTirages >= 20 && stats.partMaxUnSeulJeu >= 0.5) ids.push("un_seul_amour");

  if (stats.statutsDistincts >= 4) ids.push("eclectique");
  if (stats.totalJeux >= 20 && stats.partNotee >= 0.5) ids.push("moitie_notee");
  if (stats.defisComplets >= 30) ids.push("marathon_defis");
  if (stats.totalJeux >= 20 && stats.partTaguee >= 0.8) ids.push("jamais_sans_tag");
  if (stats.maxCentUnJour >= 2) ids.push("double_cent");
  if (stats.aTireAubeStricte) ids.push("reveil_brutal");
  if (stats.maxTiragesUnJour >= 10) ids.push("seance_longue");
  if (stats.maxTiragesUnePlateforme >= 30) ids.push("fidele_plateforme");
  if (stats.statutsDistincts >= 5) ids.push("tout_essaye");
  if (stats.jeuxEnCours === 0 && stats.jeuxTermines >= 10) ids.push("bibliotheque_zen");

  return ids;
}

/** Parmi les succès débloquables, lesquels ne sont PAS encore dans la liste
 * déjà enregistrée — utile pour savoir lesquels célébrer/persister sans
 * re-déclencher une notification pour un succès déjà débloqué depuis
 * longtemps. */
export function nouveauxBadges(debloquables: string[], dejaDebloquees: string[]): string[] {
  return debloquables.filter((id) => !dejaDebloquees.includes(id));
}
