<script lang="ts">
  import { onMount } from "svelte";
  import { spring } from "svelte/motion";
  import { fade, fly } from "svelte/transition";
  import { jouerSon } from "./lib/sons";
  import { getCurrentWindow } from "@tauri-apps/api/window";
  import { convertFileSrc } from "@tauri-apps/api/core";
  import MenuContextuel from "./lib/MenuContextuel.svelte";
  import type { ActionMenu } from "./lib/menu-contextuel";
  import { isPermissionGranted, requestPermission, sendNotification } from "@tauri-apps/plugin-notification";
  import { Dices, Gamepad2, Timer, SlidersHorizontal, Settings, LayoutGrid } from "@lucide/svelte";
  import { langueApp, tr, labelStatut, langueDepuisLocale, type LangueApp } from "./lib/i18n";
  import { api } from "./lib/api";
  import { applyTheme } from "./lib/themes";
  import ThemePicker from "./lib/ThemePicker.svelte";
  import ConfirmDialog from "./lib/ConfirmDialog.svelte";
  import Toast from "./lib/Toast.svelte";
  import BibliothequeView from "./lib/BibliothequeView.svelte";
  import BacklogView from "./lib/BacklogView.svelte";
  import StatistiquesView from "./lib/StatistiquesView.svelte";
  import RechercheGlobaleView from "./lib/RechercheGlobaleView.svelte";
  import FicheJeu from "./lib/FicheJeu.svelte";
  import OptionsView from "./lib/OptionsView.svelte";
  import LanguageSetupDialog from "./lib/LanguageSetupDialog.svelte";
  import type { AppConfig, Platform, GameLibrary, DrawSession, Historique, Badges, Game, ThemeName, OngletMasquable } from "./lib/types";
  import { BLOCS_RECAP, DEFAULT_CONFIG, EMPTY_SESSION, EMPTY_HISTORIQUE, EMPTY_BADGES, SCHEMA_VERSION, objectifEnMinutes } from "./lib/types";
  import { drawFromLibrary, sampleNames, drawMultiple, appliquerFiltres, FILTRES_VIDES, filtresActifs, type FiltresTirage } from "./lib/draw";
  import { modifierJeu, supprimerJeu } from "./lib/library";
  import { drawAnimations, clearAnimationNodes } from "./lib/animations/animations";
  import { revealEffects } from "./lib/effects/effects";
  import { computeRemainingMs, computeEndsAt, countdownPhase, formatDuration } from "./lib/session";
  import { applyDensite } from "./lib/densite";
  import { calculerStatsPourBadges, badgesDebloquables, nouveauxBadges, BADGE_DEFINITIONS, LABELS_PALIER } from "./lib/badges";

  let config = $state<AppConfig>(DEFAULT_CONFIG);
  let afficherChoixLanguePremierLancement = $state(false);
  let langueSystemeDetectee = $state<LangueApp>("fr");
  let erreurChoixLangue = $state<string | null>(null);

  function detecterLangueSysteme(): LangueApp {
    const locale = typeof navigator !== "undefined"
      ? (navigator.languages?.[0] ?? navigator.language ?? "")
      : "";
    return langueDepuisLocale(locale);
  }

  $effect(() => {
    langueApp.set(config.langue);
    document.documentElement.lang = config.langue;
  });
  let platforms = $state<Platform[]>([]);
  let selectedPlatformId = $state<string | null>(null);
  let library = $state<GameLibrary | null>(null);
  let session = $state<DrawSession>(EMPTY_SESSION);
  let loading = $state(true);
  let erreur = $state<string | null>(null);
  type NomVue = "tirage" | "bibliotheque" | "backlog" | "statistiques" | "recherche" | "options";
  const ORDRE_VUES: NomVue[] = ["tirage", "bibliotheque", "backlog", "statistiques", "recherche", "options"];
  let vue = $state<NomVue>("tirage");
  // Sens de navigation (+1 vers la droite, -1 vers la gauche) — sert à faire
  // arriver la nouvelle vue du bon côté avec la transition "glissement".
  let sensNavigation = $state(1);

  function allerVue(cible: NomVue) {
    if (cible === vue) return;
    sensNavigation = ORDRE_VUES.indexOf(cible) > ORDRE_VUES.indexOf(vue) ? 1 : -1;
    vue = cible;
  }

  /** Un onglet masqué (Options → Apparence) disparaît de la navigation.
   * "tirage" et "options" ne sont jamais masquables — le type
   * OngletMasquable les exclut déjà, ce test est juste la lecture inverse. */
  function estMasque(onglet: string): boolean {
    return config.ongletsMasques.includes(onglet as OngletMasquable);
  }

  // Filet de sécurité : si l'utilisateur masque l'onglet sur lequel il se
  // trouve (possible depuis Options, qui reste toujours accessible), on le
  // ramène sur Tirage plutôt que de le laisser sur une vue devenue
  // inatteignable par la navigation.
  $effect(() => {
    if (estMasque(vue)) allerVue("tirage");
  });
  let justTire = $state(false); // déclenche le halo lumineux du reveal
  let tirageEnCours = $state(false); // pendant l'animation de tirage
  let remainingMs = $state(0); // recalculé chaque seconde depuis session.endsAt (jamais gardé tel quel)
  let notifieFinSession = $state(false); // évite de renotifier en boucle une fois à 0

  let canvasEl = $state<HTMLCanvasElement | null>(null);
  let animContainerEl = $state<HTMLDivElement | null>(null);
  let dialogConfirmation = $state<{ message: string; resolve: (v: boolean) => void } | null>(null);
  let toastMessage = $state<string | null>(null);
  let toastType = $state<"session" | "succes">("session");
  let toastTimeout: ReturnType<typeof setTimeout> | null = null;
  let ticTimeout: ReturnType<typeof setTimeout> | null = null;
  // Filtres de tirage — volontairement NON persistés : ce sont des réglages
  // "de séance" (ce soir je veux un RPG court), pas une préférence durable.
  let filtres = $state<FiltresTirage>({ ...FILTRES_VIDES });
  let panneauFiltresOuvert = $state(false);
  // Jeux tirés en plus du premier, quand nombreTirages > 1.
  let jeuxTiresMultiples = $state<Game[]>([]);

  // Tags réellement présents dans la bibliothèque active — proposer des tags
  // qui n'existent pas donnerait des filtres qui ne matchent jamais.
  const tagsDisponibles = $derived.by(() => {
    if (!library) return [];
    const tous = new Set<string>();
    for (const j of library.jeux) {
      for (const t of j.tags.split(",").map((x) => x.trim()).filter(Boolean)) tous.add(t);
    }
    return [...tous].sort((a, b) => a.localeCompare(b, "fr")).slice(0, 30);
  });

  // Taille du pool après filtres — retour immédiat pendant qu'on ajuste.
  const poolFiltreCount = $derived(library ? appliquerFiltres(library, filtres).jeux.length : 0);

  // Roulette russe : le tirage est verrouillé tant qu'une session chronométrée
  // court encore. Sans chrono actif, rien à verrouiller (sinon on bloquerait
  // l'app pour de bon).
  const verrouRouletteRusse = $derived(config.rouletteRusse && remainingMs > 0);

  // --- Récap d'accueil (v25) ------------------------------------------------
  // --- Menu contextuel de la vue Tirage (clic droit) ------------------------
  let menuAccueil = $state<{ x: number; y: number; actions: ActionMenu[] } | null>(null);

  function ouvrirMenuAccueil(e: MouseEvent) {
    // Ne pas capturer le clic droit sur un champ de saisie : l'utilisateur
    // s'attend au menu natif (copier/coller) à cet endroit précis.
    const cible = e.target as HTMLElement | null;
    if (cible && (cible.tagName === "INPUT" || cible.tagName === "TEXTAREA" || cible.isContentEditable)) return;
    e.preventDefault();
    menuAccueil = {
      x: e.clientX,
      y: e.clientY,
      actions: [
        {
          label: verrouRouletteRusse
            ? tr(config.langue, "Tirage verrouillé (roulette russe)", "Draw locked (Russian roulette)")
            : tr(config.langue, "Lancer un tirage", "Start a draw"),
          icone: Dices,
          action: () => {
            if (!tirageEnCours && !verrouRouletteRusse && selectedPlatformId && poolTotal > 0) void lancerTirage();
          },
        },
        {
          label: panneauFiltresOuvert
            ? tr(config.langue, "Masquer les filtres", "Hide draw filters")
            : tr(config.langue, "Filtres de tirage…", "Draw filters…"),
          icone: SlidersHorizontal,
          action: () => (panneauFiltresOuvert = !panneauFiltresOuvert),
        },
        {
          label: config.afficherRecap
            ? tr(config.langue, "Masquer le récap", "Hide summary")
            : tr(config.langue, "Afficher le récap", "Show summary"),
          icone: LayoutGrid,
          separateurAvant: true,
          action: () => void majConfig({ ...config, afficherRecap: !config.afficherRecap }),
        },
        { label: tr(config.langue, "Ouvrir les options", "Open settings"), icone: Settings, action: () => allerVue("options") },
      ],
    };
  }

  function blocRecapMasque(id: string): boolean {
    return config.blocsRecapMasques.includes(id);
  }
  // Si l'utilisateur masque TOUS les blocs, on n'affiche pas un bandeau vide.
  const recapVisible = $derived(
    config.afficherRecap && config.blocsRecapMasques.length < BLOCS_RECAP.length
  );
  const nbEnCours = $derived(library ? library.jeux.filter((j) => j.statut === "EnCours").length : 0);
  const nbTermines = $derived(library ? library.jeux.filter((j) => j.statut === "Termine").length : 0);
  // Dernier tirage tous supports confondus (l'historique n'est pas filtré par
  // plateforme) — formaté en relatif, plus parlant qu'une date brute.
  const dernierTirageTexte = $derived.by(() => {
    const derniere = historique.entrees.at(-1);
    if (!derniere) return null;
    const ecoule = Date.now() - new Date(derniere.drawnAt).getTime();
    const jours = Math.floor(ecoule / 86_400_000);
    const heures = Math.floor(ecoule / 3_600_000);
    const minutes = Math.floor(ecoule / 60_000);
    let quand: string;
    if (jours >= 2) quand = config.langue === "en" ? `${jours} days ago` : `il y a ${jours} jours`;
    else if (jours === 1) quand = tr(config.langue, "hier", "yesterday");
    else if (heures >= 1) quand = config.langue === "en" ? `${heures}h ago` : `il y a ${heures} h`;
    else if (minutes >= 1) quand = config.langue === "en" ? `${minutes} min ago` : `il y a ${minutes} min`;
    else quand = tr(config.langue, "à l'instant", "just now");
    return `${derniere.nom} — ${quand}`;
  });
  let historique = $state<Historique>(EMPTY_HISTORIQUE);
  let badges = $state<Badges>(EMPTY_BADGES);
  let jeuOuvertId = $state<string | null>(null);

  /** Remplace le dialogue natif du système (fond blanc système, impossible à
   * styler — cf. le même problème déjà rencontré avec le <select> natif) par
   * une confirmation maison qui respecte le thème actif. */
  function confirmer(message: string): Promise<boolean> {
    return new Promise((resolve) => {
      dialogConfirmation = { message, resolve };
    });
  }
  function repondreDialogue(valeur: boolean) {
    dialogConfirmation?.resolve(valeur);
    dialogConfirmation = null;
  }

  // Physique de ressort réelle (pas une transition CSS) : le reveal
  // "rebondit" légèrement au-delà de sa taille finale avant de s'y stabiliser.
  const revealScale = spring(1, { stiffness: 0.25, damping: 0.45 });

  const jeuTire = $derived(
    library && session.gameId ? library.jeux.find((j) => j.id === session.gameId) ?? null : null
  );
  const poolRestant = $derived(library ? library.jeux.filter((j) => !j.dejaFait).length : 0);
  const poolTotal = $derived(library?.jeux.length ?? 0);
  const poolPct = $derived(poolTotal > 0 ? Math.round((poolRestant / poolTotal) * 100) : 0);
  const phase = $derived(countdownPhase(remainingMs, (session.goalMinutes ?? objectifEnMinutes(config.objectifParDefaut)) * 60_000));
  // Part de temps restante (0-100) — alimente la barre de progression du
  // chrono, bornée pour éviter tout débordement visuel si l'horloge dérive.
  const pctTempsRestant = $derived.by(() => {
    const total = (session.goalMinutes ?? objectifEnMinutes(config.objectifParDefaut)) * 60_000;
    if (total <= 0) return 0;
    return Math.min(100, Math.max(0, (remainingMs / total) * 100));
  });
  const jeuOuvert = $derived(library?.jeux.find((j) => j.id === jeuOuvertId) ?? null);

  /** Notification Windows native (via le plugin Tauri) à la fin du compte à
   * rebours, avec le nom du jeu ET la plateforme — demande la permission au
   * premier besoin. Affiche aussi un toast maison (thème respecté) : la
   * notification système est utile app minimisée, le toast prend le relais
   * visuellement quand la fenêtre est au premier plan. */
  async function notifierFinSession(message: string) {
    if (config.sonsActifs) jouerSon("finSession", config.volumeSons);
    // Effet visuel de fin de session — volontairement FIXE (ondeChoc) et
    // distinct de l'effet de révélation configurable : la fin du chrono
    // doit se reconnaître immédiatement sans déclencher deux animations
    // concurrentes sur le même canvas.
    if (canvasEl) void revealEffects.ondeChoc(canvasEl, 1000);
    toastMessage = message;
    toastType = "session";
    if (toastTimeout) clearTimeout(toastTimeout);
    toastTimeout = setTimeout(() => (toastMessage = null), 6000);

    try {
      let accordee = await isPermissionGranted();
      if (!accordee) {
        const reponse = await requestPermission();
        accordee = reponse === "granted";
      }
      if (accordee) {
        sendNotification({ title: "GameDraw", body: message });
      }
    } catch (e) {
      void api.logError(`notifierFinSession: ${String(e)}`);
    }
  }

  // --- Raccourcis clavier (v25) --------------------------------------------
  // Volontairement limités à des touches qui ne servent à rien d'autre ici,
  // et TOUJOURS ignorés quand le focus est dans un champ de saisie : sinon
  // taper "3" dans un nom de jeu changerait d'onglet.
  function estDansUnChamp(cible: EventTarget | null): boolean {
    const el = cible as HTMLElement | null;
    if (!el) return false;
    const tag = el.tagName;
    return tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT" || el.isContentEditable;
  }

  function gererRaccourci(e: KeyboardEvent) {
    // Le choix de langue du premier lancement est modal : aucun raccourci de
    // l'application ne doit agir derrière la fenêtre.
    if (afficherChoixLanguePremierLancement) return;

    // Échap ferme la fiche ouverte — utile même depuis un champ, c'est le
    // seul cas où on ne filtre pas la saisie.
    if (e.key === "Escape" && jeuOuvertId) {
      jeuOuvertId = null;
      return;
    }
    if (estDansUnChamp(e.target) || e.ctrlKey || e.altKey || e.metaKey) return;

    // Espace = lancer un tirage (le geste principal de l'app).
    if (e.code === "Space" && vue === "tirage") {
      e.preventDefault(); // sinon la page défile
      if (!tirageEnCours && !verrouRouletteRusse && selectedPlatformId && poolTotal > 0) {
        void lancerTirage();
      }
      return;
    }

    // 1-6 = navigation directe, en sautant les onglets masqués pour que la
    // numérotation corresponde à ce qui est RÉELLEMENT affiché.
    const n = Number(e.key);
    if (Number.isInteger(n) && n >= 1 && n <= 9) {
      const visibles = ORDRE_VUES.filter((v) => v === "tirage" || v === "options" || !estMasque(v));
      const cible = visibles[n - 1];
      if (cible) allerVue(cible);
    }
  }

  onMount(async () => {
    try {
      // Ne pas déduire le premier lancement du contenu de config.json : une
      // ancienne installation possède déjà une langue migrée en v29. On teste
      // donc l'existence réelle du fichier AVANT loadConfig().
      let configExistait = true;
      try {
        configExistait = await api.configExists();
      } catch (e) {
        // Une impossibilité de sonder le fichier ne doit pas bloquer l'app :
        // on considère prudemment qu'il existe et on journalise seulement.
        void api.logError(`config_exists: ${String(e)}`);
      }

      config = await api.loadConfig();
      if (!configExistait) {
        langueSystemeDetectee = detecterLangueSysteme();
        config = { ...config, langue: langueSystemeDetectee };
        afficherChoixLanguePremierLancement = true;
      }
      applyTheme(config.theme);
      applyDensite(config.densite);
      await api.definirIconeFenetre(config.iconeFenetre);

      platforms = await api.listPlatforms();
      if (platforms.length === 0) {
        platforms = [
          { id: "pc", nom: "PC", actif: true },
          { id: "switch", nom: "Switch", actif: true },
        ];
        await api.savePlatforms(platforms);
      }
      selectedPlatformId = platforms.find((p) => p.actif)?.id ?? platforms[0]?.id ?? null;

      session = await api.loadSession();
      if (selectedPlatformId) {
        library = await api.loadGames(selectedPlatformId);
      }
      historique = await api.loadHistorique();
      badges = await api.loadBadges();

      // Recalcule immédiatement (pas d'attente d'1s) depuis la date de fin
      // absolue rechargée du disque — c'est ce qui permet au compte à
      // rebours de "reprendre" correctement après une fermeture complète.
      remainingMs = computeRemainingMs(session.endsAt);
      setInterval(() => {
        remainingMs = computeRemainingMs(session.endsAt);
        if (session.endsAt && remainingMs <= 0 && !notifieFinSession) {
          notifieFinSession = true;
          if (config.notifierFinSession) {
            const nomPlateforme = platforms.find((p) => p.id === session.platformId)?.nom;
            const message = `${tr(config.langue, "Session terminée", "Session finished")} : ${jeuTire?.nom ?? ""}${nomPlateforme ? ` (${nomPlateforme})` : ""}`;
            void notifierFinSession(message);
          }
        }
      }, 1000);
    } catch (e) {
      erreur = String(e);
      void api.logError(`onMount: ${erreur}`);
    } finally {
      loading = false;
      // Confirmer le PREMIER affichage réel, pas seulement la réussite de la compilation Rust.
      // requestAnimationFrame attend que Svelte ait affiché la vue ou le message d'erreur.
      requestAnimationFrame(() => {
        if (document.querySelector("#app main")) {
          window.dispatchEvent(new Event("gamedraw:ready"));
        } else {
          window.dispatchEvent(new CustomEvent("gamedraw:fatal", {
            detail: "Le chargement a terminé, mais aucune vue Svelte n'est visible."
          }));
        }
      });
    }

    // Confirmation avant de quitter complètement l'app si une session
    // chronométrée est active (pas de confirmation pour un changement de
    // thème ou autre action anodine).
    const fenetre = getCurrentWindow();
    await fenetre.onCloseRequested(async (event) => {
      if (remainingMs > 0) {
        event.preventDefault();
        const confirme = await confirmer(tr(config.langue, "Une session chronométrée est encore active. Fermer quand même l'application ?", "A timed session is still active. Close the application anyway?"));
        if (confirme) await fenetre.destroy();
      }
    });
  });

  async function changerPlateforme(id: string) {
    selectedPlatformId = id;
    justTire = false;
    library = await api.loadGames(id);
  }

  async function changerTheme(theme: ThemeName) {
    config = { ...config, theme };
    applyTheme(theme);
    await api.saveConfig(config);
  }

  /** Callback partagé avec BibliothequeView : la bibliothèque doit rester en
   * phase avec la vue Tirage (pool restant, etc.), donc l'état vit ici et
   * pas dans le composant enfant. */
  async function majBibliotheque(lib: GameLibrary) {
    library = lib;
    await api.saveGames(lib);
    void verifierNouveauxBadges();
  }

  async function majConfig(cfg: AppConfig) {
    // Journal d'usage (v26) : mémorise les thèmes essayés pour le succès
    // "Esthète". Fait ici plutôt que dans le sélecteur de thème, pour
    // couvrir tous les chemins de changement (Options, en-tête, import...).
    if (cfg.theme && !cfg.themesEssayes.includes(cfg.theme)) {
      cfg = { ...cfg, themesEssayes: [...cfg.themesEssayes, cfg.theme] };
    }
    config = cfg;
    applyTheme(cfg.theme);
    applyDensite(cfg.densite);
    await api.definirIconeFenetre(cfg.iconeFenetre);
    await api.saveConfig(cfg);
  }

  async function choisirLanguePremierLancement(langue: LangueApp) {
    erreurChoixLangue = null;
    try {
      await majConfig({ ...config, langue });
      afficherChoixLanguePremierLancement = false;
    } catch (e) {
      erreurChoixLangue = langue === "en"
        ? `Unable to save the language choice: ${String(e)}`
        : `Impossible d’enregistrer le choix de langue : ${String(e)}`;
      void api.logError(`premier_lancement_langue: ${String(e)}`);
    }
  }

  /** Fiche du jeu — partagée entre Bibliothèque, Backlog et Recherche
   * globale (une seule instance rendue au niveau racine, pas une par vue). */
  function sauvegarderPatchFiche(gameId: string, patch: Partial<GameLibrary["jeux"][number]>) {
    if (!library) return;
    void majBibliotheque(modifierJeu(library, gameId, patch));
  }

  function supprimerJeuFiche(gameId: string) {
    if (!library) return;
    void majBibliotheque(supprimerJeu(library, gameId));
    jeuOuvertId = null;
  }

  /** Ouvre la fiche d'un jeu — si le résultat vient d'une autre plateforme
   * que celle actuellement active (Recherche globale), on bascule dessus
   * d'abord : un seul jeu de données chargé à la fois, cohérent avec le
   * reste de l'architecture (pas de bibliothèques multiples en mémoire). */
  async function ouvrirJeuFiche(platformId: string, gameId: string) {
    if (platformId !== selectedPlatformId) {
      await changerPlateforme(platformId);
    }
    jeuOuvertId = gameId;
  }

  async function effacerHistorique() {
    const confirme = await confirmer(tr(config.langue, "Effacer tout l'historique des tirages ? Cette action est irréversible.", "Delete the entire draw history? This action cannot be undone."));
    if (!confirme) return;
    historique = { ...EMPTY_HISTORIQUE, schemaVersion: historique.schemaVersion };
    await api.saveHistorique(historique);
  }

  async function majBadges(b: Badges) {
    badges = b;
    await api.saveBadges(b);
  }

  /** Vérification légère (bibliothèque de la plateforme active + historique
   * déjà en mémoire, pas de rechargement des autres plateformes) après un
   * tirage — le seul moment où un nouveau succès mérite une petite fête
   * immédiate. Les succès "collection"/"explorateur" qui ont besoin de
   * TOUTES les plateformes se rattrapent à l'ouverture de l'onglet Succès. */
  async function verifierNouveauxBadges() {
    if (!library) return;
    const nbStatutsPerso = config.statuts.filter((s) => !s.integre).length;
    const sansAntiRepetition = !config.eviterRepetitions && historique.entrees.length > 0;
    const stats = calculerStatsPourBadges(historique, [library], nbStatutsPerso, sansAntiRepetition, {
      nbBadgesDebloques: badges.debloquees.length,
      nbThemesEssayes: config.themesEssayes.length,
      aUtiliseTirageMultiple: config.aUtiliseTirageMultiple,
      aUtiliseRouletteRusse: config.aUtiliseRouletteRusse,
      aUtiliseFiltres: config.aUtiliseFiltres,
    });
    const nouveaux = nouveauxBadges(badgesDebloquables(stats), badges.debloquees.map((b) => b.id));
    if (nouveaux.length === 0) return;
    const maintenant = new Date().toISOString();
    await majBadges({
      ...badges,
      debloquees: [...badges.debloquees, ...nouveaux.map((id) => ({ id, dateDebloquee: maintenant }))],
    });
    const premier = BADGE_DEFINITIONS.find((d) => d.id === nouveaux[0]);
    if (premier && config.notifierSucces) {
      const palierTxt = premier.palier ? ` (${LABELS_PALIER[premier.palier]})` : "";
      const message = `🏆 ${tr(config.langue, "Succès débloqué", "Achievement unlocked")} : ${premier.label}${palierTxt}`;
      toastMessage = message;
      toastType = "succes";
      if (toastTimeout) clearTimeout(toastTimeout);
      toastTimeout = setTimeout(() => (toastMessage = null), 6000);

      try {
        let accordee = await isPermissionGranted();
        if (!accordee) {
          const reponse = await requestPermission();
          accordee = reponse === "granted";
        }
        if (accordee) sendNotification({ title: "GameDraw", body: message });
      } catch {
        // Notification système best-effort, jamais bloquant.
      }

      // Feu d'artifice fixe (pas l'effet de révélation configuré par
      // l'utilisateur) — décalé pour ne jamais se superposer à celui du
      // tirage lui-même, qui vient de jouer juste avant.
      if (canvasEl) {
        setTimeout(() => {
          if (canvasEl) void revealEffects.feuxArtifice(canvasEl, 1400);
          if (config.sonsActifs) jouerSon("succes", config.volumeSons);
        }, 900);
      }
    }
  }

  async function lancerTirage() {
    if (!selectedPlatformId || !library || tirageEnCours || !animContainerEl) return;
    erreur = null;
    try {
      // Avertissement si une session chronométrée est encore active — le
      // tirage lui-même reste réel et déterminé juste après, seule la
      // confirmation est demandée en amont.
      if (remainingMs > 0 && config.avertirAvantNouveauTirage) {
        const confirme = await confirmer("Une session est encore en cours. Lancer un nouveau tirage quand même ?");
        if (!confirme) return;
      }

      // Filtres appliqués AVANT le tirage (v24) : le pool est restreint, le
      // tirage reste un vrai hasard sur ce sous-ensemble.
      const poolFiltre = appliquerFiltres(library, filtres);
      if (poolFiltre.jeux.length === 0) {
        erreur = "Aucun jeu ne correspond aux filtres de tirage — assouplis-les dans le panneau Filtres.";
        return;
      }

      // Résultat déjà déterminé AVANT toute animation (le tirage est réel,
      // pas mis en scène après coup) — seul l'affichage est différé.
      const nb = Math.max(1, config.nombreTirages);
      const multi = drawMultiple(poolFiltre, nb, config.eviterRepetitions);
      if (!multi) return;

      // drawMultiple travaille sur le pool FILTRÉ : il faut reporter les
      // dejaFait sur la bibliothèque complète, sinon les jeux exclus par les
      // filtres perdraient leur état.
      const majParId = new Map(multi.library.jeux.map((j) => [j.id, j]));
      const libraryComplete: GameLibrary = {
        ...library,
        jeux: library.jeux.map((j) => majParId.get(j.id) ?? (multi.cycleReset ? { ...j, dejaFait: false } : j)),
      };
      const result = { game: multi.games[0], library: libraryComplete, cycleReset: multi.cycleReset };
      jeuxTiresMultiples = multi.games.length > 1 ? multi.games : [];

      // Journal d'usage (v26) — écrit une seule fois par fonctionnalité, et
      // seulement si la valeur change réellement (évite une écriture disque
      // à chaque tirage).
      const usageMaj: Partial<AppConfig> = {};
      if (multi.games.length > 1 && !config.aUtiliseTirageMultiple) usageMaj.aUtiliseTirageMultiple = true;
      if (config.rouletteRusse && !config.aUtiliseRouletteRusse) usageMaj.aUtiliseRouletteRusse = true;
      if (filtresActifs(filtres) && !config.aUtiliseFiltres) usageMaj.aUtiliseFiltres = true;
      if (Object.keys(usageMaj).length > 0) void majConfig({ ...config, ...usageMaj });

      tirageEnCours = true;
      justTire = false;
      clearAnimationNodes(animContainerEl);

      const sample = sampleNames(result.library, 8, result.game.id);
      // Tics rythmés pendant l'animation — cadence qui ralentit
      // progressivement, comme une roue qui s'arrête. Nettoyé dans tous les
      // cas via le finally plus bas.
      if (config.sonsActifs) {
        let delaiTic = 90;
        const tic = () => {
          jouerSon("tic", config.volumeSons * 0.5);
          delaiTic = Math.min(delaiTic * 1.13, 380);
          ticTimeout = setTimeout(tic, delaiTic);
        };
        ticTimeout = setTimeout(tic, delaiTic);
      }
      await drawAnimations[config.animationStyle]({
        container: animContainerEl,
        duration: config.animationDurationMs,
        winner: result.game.nom,
        sample,
      });
      clearAnimationNodes(animContainerEl);

      library = result.library;
      const objectifMinutes = objectifEnMinutes(config.objectifParDefaut);
      session = {
        schemaVersion: SCHEMA_VERSION,
        platformId: selectedPlatformId,
        gameId: result.game.id,
        drawnAt: new Date().toISOString(),
        goalMinutes: objectifMinutes,
        endsAt: computeEndsAt(objectifMinutes),
      };
      notifieFinSession = false;
      remainingMs = computeRemainingMs(session.endsAt);

      await api.saveGames(library);
      await api.saveSession(session);

      historique = {
        ...historique,
        entrees: [
          ...historique.entrees,
          {
            platformId: selectedPlatformId,
            gameId: result.game.id,
            nom: result.game.nom,
            drawnAt: session.drawnAt!,
            goalMinutes: objectifMinutes,
          },
        ].slice(-config.nombreHistorique),
      };
      await api.saveHistorique(historique);
      void verifierNouveauxBadges();

      requestAnimationFrame(() => (justTire = true));

      // Le "punch" : on force une valeur hors cible, le spring rebondit
      // naturellement en revenant vers 1 (physique, pas un keyframe figé).
      revealScale.set(0.94, { hard: true });
      requestAnimationFrame(() => revealScale.set(1));
      if (canvasEl) void revealEffects[config.revealEffect](canvasEl, config.revealDurationMs);
      if (config.sonsActifs) jouerSon("revelation", config.volumeSons);
    } catch (e) {
      erreur = String(e);
      void api.logError(`lancerTirage: ${erreur}`);
    } finally {
      // Arrêt des tics dans TOUS les cas (succès, erreur, pool vide) —
      // sinon ils continueraient indéfiniment après le tirage.
      if (ticTimeout) {
        clearTimeout(ticTimeout);
        ticTimeout = null;
      }
      tirageEnCours = false;
    }
  }
</script>

<svelte:window onkeydown={gererRaccourci} />

<main>
  {#if loading}
    <p class="etat">{tr(config.langue, "Chargement…", "Loading…")}</p>
  {:else}
    <header>
      <div class="brand">
        <Gamepad2 size={22} strokeWidth={2.2} color="var(--accent)" />
        <h1>GameDraw</h1>
      </div>
      <div class="header-droite">
        <nav class="onglets">
          <button class="onglet" class:active={vue === "tirage"} onclick={() => allerVue("tirage")}>{tr(config.langue, "Tirage", "Draw")}</button>
          {#if !estMasque("bibliotheque")}
            <button class="onglet" class:active={vue === "bibliotheque"} onclick={() => allerVue("bibliotheque")}>
              {tr(config.langue, "Bibliothèque", "Library")}
            </button>
          {/if}
          {#if !estMasque("backlog")}
            <button class="onglet" class:active={vue === "backlog"} onclick={() => allerVue("backlog")}>Backlog</button>
          {/if}
          {#if !estMasque("statistiques")}
            <button class="onglet" class:active={vue === "statistiques"} onclick={() => allerVue("statistiques")}>
              {tr(config.langue, "Stats", "Stats")}
            </button>
          {/if}
          {#if !estMasque("recherche")}
            <button class="onglet" class:active={vue === "recherche"} onclick={() => allerVue("recherche")}>
              {tr(config.langue, "Recherche", "Search")}
            </button>
          {/if}
          <button class="onglet" class:active={vue === "options"} onclick={() => allerVue("options")}>
            {tr(config.langue, "Options", "Settings")}
          </button>
        </nav>
        {#if config.afficherSelecteurTheme}
          <ThemePicker value={config.theme} onChange={changerTheme} />
        {/if}
      </div>
    </header>

    <div class="rule"></div>

    <!-- La transition doit envelopper le {#key}, PAS l'inverse : une
         transition Svelte ne se joue que si l'élément est créé/détruit. Avec
         le {#if} sur le style à l'extérieur, le <div> restait le même d'un
         onglet à l'autre (le style ne change pas pendant la navigation) et
         aucune transition ne se déclenchait — bug signalé par Sensei.
         Ici, {#key vue} recrée le <div> à CHAQUE changement de vue, donc la
         transition in: se rejoue à chaque fois. -->
    {#if config.transitionOnglets === "aucune"}
      <div class="vue-fondu">
        {@render contenuVue()}
      </div>
    {:else if config.transitionOnglets === "fondu"}
      {#key vue}
        <div class="vue-fondu" in:fade={{ duration: 170 }}>
          {@render contenuVue()}
        </div>
      {/key}
    {:else}
      {#key vue}
        <div class="vue-fondu" in:fly={{ x: sensNavigation * 34, duration: 240, opacity: 0 }}>
          {@render contenuVue()}
        </div>
      {/key}
    {/if}
  {/if}
</main>

{#if afficherChoixLanguePremierLancement && !loading}
  <LanguageSetupDialog
    detectedLang={langueSystemeDetectee}
    currentLang={config.langue}
    errorMessage={erreurChoixLangue}
    onChoose={choisirLanguePremierLancement}
  />
{/if}

{#snippet contenuVue()}
    {#if vue === "tirage"}
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div class="zone-accueil" oncontextmenu={ouvrirMenuAccueil}>
    <!-- Récap d'accueil (v25) : l'état du backlog en un coup d'oeil, en haut
         de l'onglet d'arrivée plutôt qu'en 7e onglet — l'info doit venir à
         l'utilisateur, pas l'inverse. Masqué pendant un tirage pour ne pas
         voler la vedette à l'animation. -->
    {#if !tirageEnCours && recapVisible}
      <section class="recap" transition:fade={{ duration: 180 }}>
        {#if !blocRecapMasque("poolRestant")}
          <div class="bloc-recap">
            <p class="valeur-recap">{poolRestant}</p>
            <p class="label-recap">{tr(config.langue, "à découvrir", "to discover")}</p>
          </div>
        {/if}
        {#if !blocRecapMasque("enCours")}
          <div class="bloc-recap">
            <p class="valeur-recap">{nbEnCours}</p>
            <p class="label-recap">{tr(config.langue, "en cours", "in progress")}</p>
          </div>
        {/if}
        {#if !blocRecapMasque("termines")}
          <div class="bloc-recap">
            <p class="valeur-recap">{nbTermines}</p>
            <p class="label-recap">{tr(config.langue, "terminés", "completed")}</p>
          </div>
        {/if}
        {#if !blocRecapMasque("tirages")}
          <div class="bloc-recap">
            <p class="valeur-recap">{historique.entrees.length}</p>
            <p class="label-recap">{tr(config.langue, "tirages", "draws")}</p>
          </div>
        {/if}
        {#if dernierTirageTexte && !blocRecapMasque("dernierTirage")}
          <p class="dernier-tirage">{tr(config.langue, "Dernier tirage", "Last draw")} : {dernierTirageTexte}</p>
        {/if}
      </section>
    {/if}

    <div class="stage">
      <section class="rail glass">
        <p class="eyebrow">{tr(config.langue, "Plateforme", "Platform")}</p>
        <div class="chips">
          {#each platforms as p}
            <button
              class="chip"
              class:active={p.id === selectedPlatformId}
              onclick={() => changerPlateforme(p.id)}
            >
              {p.nom}
            </button>
          {/each}
        </div>

        {#if library}
          <p class="eyebrow pool-label">{tr(config.langue, "Pool restant", "Remaining pool")}</p>
          <div class="pool-bar">
            <div class="pool-fill" style="width: {poolPct}%"></div>
          </div>
          <p class="pool-count mono">{poolRestant} / {poolTotal}</p>
        {/if}
      </section>

      <section
        class="reveal glass"
        class:flash={justTire}
        style="transform: scale({$revealScale})"
      >
        <canvas class="burst" bind:this={canvasEl}></canvas>
        <div class="anim-container" class:hidden={!tirageEnCours} bind:this={animContainerEl}></div>
        {#if tirageEnCours}
          <p class="eyebrow">{tr(config.langue, "Tirage en cours…", "Drawing…")}</p>
        {:else if jeuTire}
          <p class="eyebrow">{tr(config.langue, "Résultat du tirage", "Draw result")}</p>
          {#if config.afficherCoverResultat && jeuTire.cover}
            <!-- Jaquette du jeu tiré (v27) — cliquable pour ouvrir la fiche,
                 puisque c'est le geste naturel qu'on tente en la voyant. -->
            <button class="cover-resultat" onclick={() => (jeuOuvertId = jeuTire.id)} title={tr(config.langue, "Ouvrir la fiche", "Open game details")}>
              <img src={convertFileSrc(jeuTire.cover)} alt={jeuTire.nom} />
            </button>
          {/if}
          <p class="nom-jeu">{jeuTire.nom}</p>
          {#if jeuxTiresMultiples.length > 1}
            <!-- Tirage multiple : les autres jeux sortis dans le même lot.
                 Le premier reste LE résultat (celui qui pilote la session) —
                 les autres sont des alternatives proposées. -->
            <div class="autres-tires">
              <p class="eyebrow">{tr(config.langue, "Aussi tirés", "Also drawn")}</p>
              <div class="liste-autres">
                {#each jeuxTiresMultiples.slice(1) as g (g.id)}
                  <button class="autre-tire" onclick={() => (jeuOuvertId = g.id)}>{g.nom}</button>
                {/each}
              </div>
            </div>
          {/if}
          {#if session.endsAt}
            <p class="countdown mono" class:attention={phase === "attention"} class:urgent={phase === "urgent"} class:termine={phase === "termine"}>
              <Timer size={14} strokeWidth={2.2} />
              {phase === "termine" ? tr(config.langue, "Session terminée", "Session finished") : formatDuration(remainingMs)}
            </p>
            <!-- Mise en scène du temps qui passe (v28) : plusieurs styles au
                 choix, tous alimentés par le même pctTempsRestant. -->
            {#if config.styleChrono === "bombe"}
              <div class="chrono-bombe" class:urgent={phase === "urgent"} class:termine={phase === "termine"}>
                <div class="meche-piste">
                  <div class="meche-restante" style="width: {pctTempsRestant}%"></div>
                  {#if phase !== "termine"}
                    <span class="etincelle-meche" style="left: {pctTempsRestant}%">✨</span>
                  {/if}
                </div>
                <span class="icone-bombe">{phase === "termine" ? "💥" : "💣"}</span>
              </div>
            {:else if config.styleChrono === "sablier"}
              <div class="chrono-sablier" class:urgent={phase === "urgent"}>
                <div class="verre-sablier">
                  <div class="sable" style="height: {pctTempsRestant}%"></div>
                </div>
                <span class="icone-sablier">{phase === "termine" ? "⌛" : "⏳"}</span>
              </div>
            {:else if config.styleChrono === "segments"}
              <div class="chrono-segments" class:urgent={phase === "urgent"}>
                {#each Array(20) as _, i}
                  <!-- Segments allumés proportionnellement au temps restant :
                       le dernier s'éteint pile à zéro. -->
                  <div class="segment" class:eteint={(i + 1) / 20 * 100 > pctTempsRestant}></div>
                {/each}
              </div>
            {:else if config.styleChrono !== "aucun"}
              <div
                class="barre-chrono"
                class:attention={phase === "attention"}
                class:urgent={phase === "urgent"}
                class:termine={phase === "termine"}
                class:arc-en-ciel={config.styleChrono === "arcEnCiel"}
                class:defilant={config.styleChrono === "defilant"}
              >
                <div class="remplissage-chrono" style="width: {pctTempsRestant}%"></div>
              </div>
            {/if}
          {/if}

        {:else if poolTotal === 0}
          <p class="eyebrow">{tr(config.langue, "Pool vide", "Empty pool")}</p>
          <p class="placeholder">
            {tr(config.langue, "Aucun jeu dans cette plateforme.", "No games on this platform.")}<br />{tr(config.langue, "Ajoute-en depuis l'onglet", "Add some from the")}
            <button class="lien-biblio" onclick={() => allerVue("bibliotheque")}>{tr(config.langue, "Bibliothèque", "Library")}</button>.
          </p>
        {:else}
          <p class="eyebrow">{tr(config.langue, "En attente", "Waiting")}</p>
          <p class="placeholder">{tr(config.langue, "Lance un tirage pour révéler un jeu.", "Start a draw to reveal a game.")}</p>
        {/if}
      </section>
    </div>

    <div class="zone-filtres">
      <button class="btn-filtres" class:actif={filtresActifs(filtres)} onclick={() => (panneauFiltresOuvert = !panneauFiltresOuvert)}>
        <SlidersHorizontal size={15} strokeWidth={2.2} />
        {tr(config.langue, "Filtres de tirage", "Draw filters")}{filtresActifs(filtres) ? tr(config.langue, " (actifs)", " (active)") : ""}
      </button>
      {#if panneauFiltresOuvert}
        <div class="panneau-filtres" transition:fly={{ y: -8, duration: 160 }}>
          <p class="aide-filtres">
            {tr(config.langue, "Restreint le pool avant le tirage. Non conservé au redémarrage — c'est un réglage de séance, pas une préférence.", "Restricts the pool before drawing. It is not kept after restart — this is a session setting, not a preference.")}
          </p>
          <label class="ligne-filtre">
            <input type="checkbox" checked={filtres.exclureTermines} onchange={(e) => (filtres = { ...filtres, exclureTermines: e.currentTarget.checked })} />
            {tr(config.langue, "Exclure les jeux terminés et abandonnés", "Exclude completed and abandoned games")}
          </label>
          <label class="ligne-filtre">
            <input type="checkbox" checked={filtres.seulementEnvie} onchange={(e) => (filtres = { ...filtres, seulementEnvie: e.currentTarget.checked })} />
            {tr(config.langue, "Seulement les jeux « envie de faire »", "Only games marked as want to play")}
          </label>

          <p class="eyebrow">{tr(config.langue, "Statuts", "Statuses")}</p>
          <div class="chips-filtre">
            {#each config.statuts.filter((s) => s.visible) as s}
              <button
                class="chip-filtre"
                class:active={filtres.statuts.includes(s.id)}
                onclick={() => (filtres = { ...filtres, statuts: filtres.statuts.includes(s.id) ? filtres.statuts.filter((x) => x !== s.id) : [...filtres.statuts, s.id] })}
              >
                {labelStatut(config.langue, s.id, s.label, s.integre)}
              </button>
            {/each}
          </div>

          {#if tagsDisponibles.length > 0}
            <p class="eyebrow">Tags</p>
            <div class="chips-filtre">
              {#each tagsDisponibles as t}
                <button
                  class="chip-filtre"
                  class:active={filtres.tags.includes(t)}
                  onclick={() => (filtres = { ...filtres, tags: filtres.tags.includes(t) ? filtres.tags.filter((x) => x !== t) : [...filtres.tags, t] })}
                >
                  {t}
                </button>
              {/each}
            </div>
          {/if}

          <div class="pied-filtres">
            <span class="compte-filtre">{config.langue === "en" ? `${poolFiltreCount} game${poolFiltreCount > 1 ? "s" : ""} in pool` : `${poolFiltreCount} jeu${poolFiltreCount > 1 ? "x" : ""} dans le pool`}</span>
            {#if filtresActifs(filtres)}
              <button class="btn-reset-filtres" onclick={() => (filtres = { ...FILTRES_VIDES })}>{tr(config.langue, "Tout effacer", "Clear all")}</button>
            {/if}
          </div>
        </div>
      {/if}
    </div>

    <button
      class="tirer"
      onclick={lancerTirage}
      disabled={!selectedPlatformId || poolTotal === 0 || tirageEnCours || verrouRouletteRusse}
      title={verrouRouletteRusse ? tr(config.langue, "Mode roulette russe : termine la session en cours avant de retirer", "Russian roulette mode: finish the current session before drawing again") : ""}
    >
      <Dices size={20} strokeWidth={2.2} class={tirageEnCours ? "spin" : ""} />
      {#if tirageEnCours}
        {tr(config.langue, "Tirage…", "Drawing…")}
      {:else if verrouRouletteRusse}
        {tr(config.langue, "Session en cours (roulette russe)", "Session in progress (Russian roulette)")}
      {:else if config.nombreTirages > 1}
        {config.langue === "en" ? `Draw ${config.nombreTirages} games` : `Tirer ${config.nombreTirages} jeux`}
      {:else}
        {tr(config.langue, "Lancer le tirage", "Start draw")}
      {/if}
    </button>

    {#if erreur}
      <p class="erreur">{erreur}</p>
    {/if}
    </div>
    {:else if vue === "bibliotheque"}
      <BibliothequeView
        platformId={selectedPlatformId}
        platforms={platforms}
        library={library}
        config={config}
        {confirmer}
        onLibraryChange={majBibliotheque}
        onConfigChange={majConfig}
        onPlatformChange={changerPlateforme}
        onOuvrirJeu={(gameId) => (jeuOuvertId = gameId)}
      />
    {:else if vue === "backlog"}
      <BacklogView
        platformId={selectedPlatformId}
        platforms={platforms}
        library={library}
        historique={historique}
        config={config}
        onPlatformChange={changerPlateforme}
        onOuvrirJeu={(gameId) => (jeuOuvertId = gameId)}
      />
    {:else if vue === "statistiques"}
      <StatistiquesView
        platformId={selectedPlatformId}
        platforms={platforms}
        library={library}
        historique={historique}
        badges={badges}
        config={config}
        onPlatformChange={changerPlateforme}
        onBadgesChange={majBadges}
        onConfigChange={majConfig}
      />
    {:else if vue === "recherche"}
      <RechercheGlobaleView platforms={platforms} onOuvrirJeu={ouvrirJeuFiche} />
    {:else if vue === "options"}
      <OptionsView config={config} historique={historique} {confirmer} onConfigChange={majConfig} onEffacerHistorique={effacerHistorique} />
    {/if}
{/snippet}

{#if menuAccueil}
  <MenuContextuel x={menuAccueil.x} y={menuAccueil.y} actions={menuAccueil.actions} onClose={() => (menuAccueil = null)} />
{/if}

{#if jeuOuvert && selectedPlatformId}
  <FicheJeu
    game={jeuOuvert}
    platformId={selectedPlatformId}
    config={config}
    {confirmer}
    onSave={(patch) => sauvegarderPatchFiche(jeuOuvert.id, patch)}
    onDelete={() => supprimerJeuFiche(jeuOuvert.id)}
    onClose={() => (jeuOuvertId = null)}
    onConfigChange={majConfig}
  />
{/if}

{#if dialogConfirmation}
  <ConfirmDialog
    message={dialogConfirmation.message}
    onConfirm={() => repondreDialogue(true)}
    onCancel={() => repondreDialogue(false)}
  />
{/if}

{#if toastMessage}
  <Toast message={toastMessage} type={toastType} onClose={() => (toastMessage = null)} />
{/if}

<style>
  main {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    /* Fluide, pas un plafond fixe : suit réellement l'agrandissement/
       rétrécissement de la fenêtre (94vw), avec un plafond de confort de
       lecture sur les très grands écrans (900px), au lieu d'un 560px qui
       laissait un vide énorme en grande fenêtre et forçait un empilement
       prématuré près de la largeur minimale (380px). */
    max-width: min(var(--main-max-width, 900px), 94vw);
    margin: 0 auto;
    padding: var(--space-5) var(--space-4);
    position: relative;
    z-index: 1;
  }

  /* Enveloppe du fondu entre onglets — reprend le layout flex de <main>
     pour que l'espacement des vues reste identique malgré ce niveau en
     plus. Nom vérifié unique dans tout le projet avant usage (cf. le bug
     de collision .carte, JOURNAL-DEV.md). */
  /* Conteneur de la vue Tirage — sert de cible au clic droit et reprend le
     layout flex pour ne pas casser l'espacement existant. */
  .zone-accueil {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
  }

  .vue-fondu {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
  }

  header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .brand {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  h1 {
    font-size: 1.5rem;
    font-weight: 700;
    letter-spacing: 0.02em;
    margin: 0;
    color: var(--text);
  }

  .rule {
    height: 2px;
    background: linear-gradient(90deg, var(--accent), transparent 70%);
    margin-top: calc(var(--space-4) * -1 + var(--space-2));
  }

  .header-droite {
    display: flex;
    align-items: center;
    gap: var(--space-3);
  }

  .onglets {
    display: flex;
    gap: 4px;
    background: color-mix(in srgb, var(--input) 70%, transparent);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 3px;
  }
  .onglet {
    background: transparent;
    border: none;
    color: var(--muted);
    font-family: var(--font-display);
    font-weight: 600;
    font-size: 0.85rem;
    padding: 5px 12px;
    border-radius: 7px;
    cursor: pointer;
    transition: background-color 0.15s ease, color 0.15s ease, box-shadow 0.15s ease;
  }
  .onglet.active {
    background: var(--accent);
    color: var(--darkbg);
    box-shadow: 0 2px 14px color-mix(in srgb, var(--glow) 45%, transparent);
  }

  .lien-biblio {
    background: transparent;
    border: none;
    color: var(--accent);
    font-family: inherit;
    font-size: inherit;
    text-decoration: underline;
    cursor: pointer;
    padding: 0;
  }

  .stage {
    display: grid;
    grid-template-columns: 1fr;
    gap: var(--space-3);
  }

  .rail {
    padding: var(--space-3);
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .chips {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-2);
  }

  .chip {
    background: color-mix(in srgb, var(--input) 80%, transparent);
    color: var(--muted);
    border: 1px solid var(--border);
    font-family: var(--font-display);
    font-weight: 600;
    font-size: 0.95rem;
    letter-spacing: 0.02em;
    padding: var(--space-2) var(--space-3);
    border-radius: var(--radius-sm);
    transition: transform 0.25s var(--spring), background-color 0.2s ease, color 0.2s ease, box-shadow 0.2s ease;
  }

  .chip:hover {
    transform: translateY(-2px);
  }

  .chip.active {
    background: var(--accent);
    color: var(--darkbg);
    border-color: var(--accent);
    box-shadow: 0 4px 18px color-mix(in srgb, var(--accent) 45%, transparent);
  }

  .pool-label {
    margin-top: var(--space-2);
  }

  .pool-bar {
    height: 6px;
    background: var(--input);
    border-radius: 3px;
    overflow: hidden;
  }

  .pool-fill {
    height: 100%;
    background: linear-gradient(90deg, var(--accent), var(--success));
    transition: width 0.5s var(--spring);
  }

  .pool-count {
    color: var(--muted);
    font-size: 0.85rem;
    margin: 0;
  }

  .reveal {
    padding: var(--space-4);
    min-height: 170px;
    /* Halo radial discret derrière le résultat : donne de la profondeur
       sans masquer le canvas d'effets qui se superpose. */
    background-image: radial-gradient(
      ellipse at 50% 40%,
      color-mix(in srgb, var(--accent) 9%, transparent),
      transparent 65%
    );
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    text-align: center;
    gap: var(--space-2);
    position: relative;
    overflow: hidden;
  }

  .reveal.flash {
    box-shadow: 0 0 50px 6px color-mix(in srgb, var(--glow) 55%, transparent);
  }

  .burst {
    position: absolute;
    inset: 0;
    pointer-events: none;
  }

  .anim-container {
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 90px;
  }
  .anim-container.hidden {
    display: none;
  }

  /* Jaquette du jeu tiré — taille contenue pour ne pas repousser le nom et
     le chrono hors de la zone visible sur une petite fenêtre. */
  .cover-resultat {
    background: none;
    border: none;
    padding: 0;
    cursor: pointer;
    line-height: 0;
    margin-bottom: 10px;
    border-radius: var(--radius-sm);
    transition: transform 0.2s var(--spring);
  }
  .cover-resultat:hover {
    transform: scale(1.04);
  }
  .cover-resultat img {
    max-height: 150px;
    max-width: 110px;
    object-fit: cover;
    border-radius: var(--radius-sm);
    border: 1px solid color-mix(in srgb, var(--accent) 45%, transparent);
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.35), 0 0 18px color-mix(in srgb, var(--accent) 25%, transparent);
  }

  .nom-jeu {
    font-family: var(--font-display);
    /* Taille fluide : un titre court reste imposant, un titre à rallonge
       (« The Legend of Zelda: Tears of the Kingdom ») ne déborde plus. */
    font-size: clamp(1.35rem, 5vw, 2.1rem);
    font-weight: 700;
    margin: 0;
    line-height: 1.15;
    max-width: 100%;
    overflow-wrap: break-word;
    /* Dégradé plus large que le texte + animation lente : la couleur
       "coule" doucement à travers le titre au lieu d'être figée. */
    background: linear-gradient(115deg, var(--text) 10%, var(--accent) 45%, var(--text) 85%);
    background-size: 220% auto;
    -webkit-background-clip: text;
    background-clip: text;
    color: transparent;
    animation: flux-titre 6s ease-in-out infinite;
  }
  @keyframes flux-titre {
    0%, 100% { background-position: 0% center; }
    50% { background-position: 100% center; }
  }
  /* Respecte le réglage système « animations réduites » — un dégradé qui
     bouge en permanence peut gêner (vestibulaire, TDAH, migraines). */
  @media (prefers-reduced-motion: reduce) {
    .nom-jeu { animation: none; }
  }

  .countdown {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 0.95rem;
    color: var(--accent);
    margin: 4px 0 0;
  }
  .countdown.attention {
    color: var(--warning);
  }
  .countdown.urgent {
    color: var(--danger);
    animation: pulse-countdown 0.9s ease-in-out infinite;
  }
  .countdown.termine {
    color: var(--muted);
  }
  @keyframes pulse-countdown {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.45; }
  }

  /* Barre de progression du chrono — le temps restant devient lisible d'un
     coup d'oeil. Change de couleur avec la phase, comme le texte. */
  /* Tirage multiple — les jeux sortis en plus du résultat principal. */
  .autres-tires {
    margin-top: 8px;
  }
  .liste-autres {
    display: flex;
    flex-wrap: wrap;
    gap: 5px;
    justify-content: center;
  }
  .autre-tire {
    background: color-mix(in srgb, var(--input) 80%, transparent);
    color: var(--muted);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 4px 10px;
    font-family: var(--font-body);
    font-size: 0.78rem;
    cursor: pointer;
    transition: color 0.15s ease, border-color 0.15s ease;
  }
  .autre-tire:hover {
    color: var(--text);
    border-color: var(--accent);
  }

  /* Panneau de filtres de tirage. */
  /* Récap d'accueil — bandeau compact, volontairement discret : il informe
     sans concurrencer visuellement la zone de tirage juste en dessous. */
  .recap {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: center;
    gap: var(--space-4);
    padding: var(--space-3);
    border-radius: var(--radius);
    border: 1px solid color-mix(in srgb, var(--border) 60%, transparent);
    background: color-mix(in srgb, var(--card) 45%, transparent);
  }
  .bloc-recap {
    text-align: center;
    min-width: 62px;
  }
  .valeur-recap {
    font-family: var(--font-display);
    font-weight: 700;
    font-size: 1.5rem;
    color: var(--accent);
    margin: 0;
    line-height: 1;
  }
  .label-recap {
    color: var(--muted);
    font-size: 0.72rem;
    margin: 3px 0 0;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }
  .dernier-tirage {
    width: 100%;
    text-align: center;
    color: var(--muted);
    font-size: 0.76rem;
    margin: 0;
    padding-top: 6px;
    border-top: 1px solid color-mix(in srgb, var(--border) 40%, transparent);
  }

  .zone-filtres {
    display: flex;
    flex-direction: column;
    gap: 8px;
    align-items: center;
  }
  .btn-filtres {
    display: flex;
    align-items: center;
    gap: 6px;
    background: transparent;
    color: var(--muted);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 5px 12px;
    font-family: var(--font-body);
    font-size: 0.8rem;
    cursor: pointer;
    transition: color 0.15s ease, border-color 0.15s ease;
  }
  .btn-filtres:hover {
    color: var(--text);
  }
  .btn-filtres.actif {
    color: var(--accent);
    border-color: var(--accent);
  }
  .panneau-filtres {
    width: 100%;
    max-width: 480px;
    display: flex;
    flex-direction: column;
    gap: 8px;
    padding: var(--space-3);
    border-radius: var(--radius);
    border: 1px solid color-mix(in srgb, var(--border) 70%, transparent);
    background: linear-gradient(160deg, color-mix(in srgb, var(--card) 85%, transparent), color-mix(in srgb, var(--card) 55%, transparent));
  }
  .aide-filtres {
    color: var(--muted);
    font-size: 0.75rem;
    margin: 0;
  }
  .ligne-filtre {
    display: flex;
    align-items: center;
    gap: 7px;
    color: var(--text);
    font-size: 0.82rem;
    cursor: pointer;
  }
  .chips-filtre {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
  }
  .chip-filtre {
    background: color-mix(in srgb, var(--input) 80%, transparent);
    color: var(--muted);
    border: 1px solid var(--border);
    border-radius: 999px;
    padding: 3px 10px;
    font-family: var(--font-body);
    font-size: 0.75rem;
    cursor: pointer;
    transition: color 0.15s ease, border-color 0.15s ease, background-color 0.15s ease;
  }
  .chip-filtre.active {
    background: color-mix(in srgb, var(--accent) 20%, transparent);
    color: var(--text);
    border-color: var(--accent);
  }
  .pied-filtres {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 10px;
    margin-top: 2px;
  }
  .compte-filtre {
    color: var(--muted);
    font-size: 0.75rem;
  }
  .btn-reset-filtres {
    background: transparent;
    border: none;
    color: var(--danger);
    font-family: var(--font-body);
    font-size: 0.75rem;
    cursor: pointer;
    padding: 2px 4px;
  }

  /* --- Styles de chrono (v28) --------------------------------------------
     Tous partagent la même largeur que la barre d'origine pour que changer
     de style ne déplace pas le reste de la mise en page. */

  /* Arc-en-ciel : dégradé fixe, l'identité du style est justement de ne pas
     suivre les couleurs de phase. */
  .barre-chrono.arc-en-ciel .remplissage-chrono,
  .barre-chrono.arc-en-ciel.attention .remplissage-chrono,
  .barre-chrono.arc-en-ciel.urgent .remplissage-chrono {
    background: linear-gradient(90deg, #FF3B5C, #FF9F1C, #FFE066, #4ECDC4, #4D96FF, #9B5DE5);
  }

  /* Défilant : rayures animées — le mouvement traduit "ça tourne encore". */
  .barre-chrono.defilant .remplissage-chrono {
    background-image: repeating-linear-gradient(
      -45deg,
      color-mix(in srgb, var(--accent) 100%, transparent) 0 8px,
      color-mix(in srgb, var(--accent) 55%, transparent) 8px 16px
    );
    background-size: 22px 100%;
    animation: defilement-chrono 0.7s linear infinite;
  }
  @keyframes defilement-chrono {
    to { background-position: 22px 0; }
  }

  /* Bombe : mèche qui se consume de droite à gauche. */
  .chrono-bombe {
    display: flex;
    align-items: center;
    gap: 7px;
    width: min(220px, 70%);
    margin: 8px auto 0;
  }
  .meche-piste {
    position: relative;
    flex: 1;
    height: 4px;
    border-radius: 999px;
    background: color-mix(in srgb, var(--input) 90%, transparent);
  }
  .meche-restante {
    height: 100%;
    border-radius: 999px;
    background: linear-gradient(90deg, #8a5a2b, #d89a4a);
    transition: width 1s linear;
  }
  /* Mèche incandescente quand ça devient urgent — le danger se lit sur la
     mèche elle-même, pas seulement sur l'icône. */
  .chrono-bombe.urgent .meche-restante {
    background: linear-gradient(90deg, #8a5a2b, #ff9a3c, #ff4d2d);
    box-shadow: 0 0 10px rgba(255, 120, 40, 0.75);
  }
  .chrono-bombe.urgent .etincelle-meche {
    animation: etincelle-vive 0.3s ease-in-out infinite;
  }
  @keyframes etincelle-vive {
    0%, 100% { transform: translate(-50%, -50%) scale(1); }
    50% { transform: translate(-50%, -50%) scale(1.45); }
  }
  .etincelle-meche {
    position: absolute;
    top: 50%;
    transform: translate(-50%, -50%);
    font-size: 0.7rem;
    transition: left 1s linear;
    pointer-events: none;
  }
  .icone-bombe {
    font-size: 1.1rem;
    line-height: 1;
    flex-shrink: 0;
  }
  .chrono-bombe.urgent .icone-bombe {
    animation: tremble-bombe 0.25s ease-in-out infinite;
  }
  .chrono-bombe.termine .icone-bombe {
    animation: explosion-bombe 0.6s ease-out;
    font-size: 1.5rem;
  }
  @keyframes tremble-bombe {
    0%, 100% { transform: translate(0, 0) rotate(0deg); }
    25% { transform: translate(-1px, 1px) rotate(-6deg); }
    75% { transform: translate(1px, -1px) rotate(6deg); }
  }
  @keyframes explosion-bombe {
    0% { transform: scale(0.6); }
    45% { transform: scale(1.5); }
    100% { transform: scale(1); }
  }

  /* Sablier : le sable descend dans le verre. */
  .chrono-sablier {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    margin: 8px auto 0;
  }
  .verre-sablier {
    position: relative;
    width: 22px;
    height: 46px;
    border: 1px solid color-mix(in srgb, var(--border) 90%, transparent);
    border-radius: 4px;
    background: color-mix(in srgb, var(--input) 70%, transparent);
    display: flex;
    align-items: flex-end;
    overflow: hidden;
  }
  .sable {
    width: 100%;
    background: linear-gradient(180deg, var(--warning), color-mix(in srgb, var(--warning) 60%, var(--danger)));
    transition: height 1s linear;
  }
  .icone-sablier {
    font-size: 1.1rem;
  }
  /* Filet de sable au centre du verre : sans lui, le sablier a l'air figé
     entre deux mises à jour de hauteur (une par seconde). */
  .verre-sablier::after {
    content: "";
    position: absolute;
    left: 50%;
    top: 30%;
    width: 2px;
    height: 40%;
    transform: translateX(-50%);
    background: linear-gradient(180deg, transparent, var(--warning), transparent);
    opacity: 0.7;
    animation: filet-sable 0.8s linear infinite;
  }
  @keyframes filet-sable {
    0% { opacity: 0.15; }
    50% { opacity: 0.8; }
    100% { opacity: 0.15; }
  }
  .chrono-sablier.urgent .icone-sablier {
    animation: pulse-countdown 0.9s ease-in-out infinite;
  }

  /* Segments : blocs qui s'éteignent un par un, façon jauge d'énergie. */
  .chrono-segments {
    display: flex;
    gap: 2px;
    width: min(220px, 70%);
    margin: 8px auto 0;
  }
  .segment {
    flex: 1;
    height: 8px;
    border-radius: 2px;
    background: var(--accent);
    box-shadow: 0 0 6px color-mix(in srgb, var(--accent) 45%, transparent);
    /* Décalage de transition : les segments s'éteignent avec un léger retard
       les uns sur les autres, ce qui se lit comme une vague. */
    transition: background-color 0.45s ease, opacity 0.45s ease, box-shadow 0.45s ease;
  }
  .segment.eteint {
    background: color-mix(in srgb, var(--input) 90%, transparent);
    opacity: 0.5;
  }
  .chrono-segments.urgent .segment:not(.eteint) {
    background: var(--danger);
    animation: pulse-countdown 0.9s ease-in-out infinite;
  }

  .barre-chrono {
    width: min(220px, 70%);
    height: 4px;
    border-radius: 999px;
    background: color-mix(in srgb, var(--input) 90%, transparent);
    overflow: hidden;
    margin: 6px auto 0;
  }
  .remplissage-chrono {
    height: 100%;
    background: var(--accent);
    border-radius: 999px;
    /* Lueur discrète : donne du relief sans distraire pendant une session. */
    box-shadow: 0 0 8px color-mix(in srgb, var(--accent) 55%, transparent);
    /* linear, pas d'easing : le temps s'écoule à vitesse constante, une
       accélération/décélération donnerait une fausse impression. */
    transition: width 1s linear, background-color 0.4s ease;
  }
  .barre-chrono.attention .remplissage-chrono {
    background: var(--warning);
  }
  .barre-chrono.urgent .remplissage-chrono {
    background: var(--danger);
    box-shadow: 0 0 12px color-mix(in srgb, var(--danger) 70%, transparent);
    animation: pulse-countdown 0.9s ease-in-out infinite;
  }
  /* La piste elle-même respire en phase urgente : le mouvement attire l'oeil
     même en vision périphérique, quand on est concentré sur le jeu. */
  .barre-chrono.urgent {
    animation: respire-piste 0.9s ease-in-out infinite;
  }
  @keyframes respire-piste {
    0%, 100% { box-shadow: 0 0 0 0 color-mix(in srgb, var(--danger) 40%, transparent); }
    50% { box-shadow: 0 0 0 3px transparent; }
  }
  .barre-chrono.termine .remplissage-chrono {
    background: var(--muted);
  }

  /* Barre de progression du chrono — même code couleur que le texte, pour
     que l'urgence se lise d'un coup d'œil sans déchiffrer les chiffres. */
  .barre-chrono {
    width: 100%;
    max-width: 240px;
    height: 4px;
    border-radius: 2px;
    background: color-mix(in srgb, var(--muted) 25%, transparent);
    overflow: hidden;
    margin: 6px auto 0;
  }
  .remplissage-chrono {
    height: 100%;
    background: var(--accent);
    border-radius: 2px;
    transition: width 1s linear, background-color 0.4s ease;
  }
  .barre-chrono.attention .remplissage-chrono {
    background: var(--warning);
  }
  .barre-chrono.urgent .remplissage-chrono {
    background: var(--danger);
    box-shadow: 0 0 12px color-mix(in srgb, var(--danger) 70%, transparent);
    animation: pulse-countdown 0.9s ease-in-out infinite;
  }
  /* La piste elle-même respire en phase urgente : le mouvement attire l'oeil
     même en vision périphérique, quand on est concentré sur le jeu. */
  .barre-chrono.urgent {
    animation: respire-piste 0.9s ease-in-out infinite;
  }
  @keyframes respire-piste {
    0%, 100% { box-shadow: 0 0 0 0 color-mix(in srgb, var(--danger) 40%, transparent); }
    50% { box-shadow: 0 0 0 3px transparent; }
  }
  .barre-chrono.termine {
    opacity: 0.4;
  }

  :global(.spin) {
    animation: spin 0.6s linear infinite;
  }
  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  .placeholder {
    color: var(--muted);
    font-size: 0.9rem;
    margin: 0;
    max-width: 32ch;
  }

  .tirer {
    background: linear-gradient(135deg, var(--accent), color-mix(in srgb, var(--accent) 70%, var(--success)));
    color: var(--darkbg);
    font-family: var(--font-display);
    font-weight: 700;
    font-size: 1.15rem;
    letter-spacing: 0.02em;
    padding: var(--space-3);
    border-radius: var(--radius-sm);
    display: flex;
    align-items: center;
    justify-content: center;
    gap: var(--space-2);
    box-shadow: 0 10px 30px color-mix(in srgb, var(--accent) 35%, transparent);
    transition: transform 0.2s var(--spring), box-shadow 0.2s ease, filter 0.15s ease;
    /* Reflet qui balaie le bouton au survol — contenu dans les limites du
       bouton, sans déborder sur le reste de la page. */
    position: relative;
    overflow: hidden;
  }
  .tirer::after {
    content: "";
    position: absolute;
    top: 0;
    bottom: 0;
    left: -60%;
    width: 45%;
    background: linear-gradient(100deg, transparent, rgba(255, 255, 255, 0.32), transparent);
    transform: skewX(-18deg);
    transition: left 0.55s ease;
    pointer-events: none;
  }
  .tirer:hover:not(:disabled)::after {
    left: 115%;
  }
  .tirer:hover:not(:disabled) {
    box-shadow:
      0 12px 34px color-mix(in srgb, var(--accent) 40%, transparent),
      0 0 26px color-mix(in srgb, var(--glow) 30%, transparent);
    transform: translateY(-1px);
  }

  .tirer:not(:disabled):hover {
    transform: translateY(-2px);
    box-shadow: 0 14px 36px color-mix(in srgb, var(--accent) 50%, transparent);
  }

  .tirer:not(:disabled):active {
    transform: translateY(0) scale(0.98);
  }

  .etat {
    color: var(--muted);
    text-align: center;
    font-family: var(--font-body);
  }

  .erreur {
    color: var(--danger);
    text-align: center;
  }

  @media (min-width: 480px) {
    .stage {
      grid-template-columns: 1fr 1.4fr;
      align-items: stretch;
    }
  }
</style>
