import { invoke } from "@tauri-apps/api/core";
import type { AppConfig, Badges, DrawSession, GameLibrary, Historique, Platform } from "./types";
import { migrate } from "./migrations";

// Fine couche au-dessus de `invoke` : noms de commandes Rust centralisés,
// signatures typées, et TOUTE lecture disque passe par migrate() pour
// garantir que l'app ne manipule que des données au schéma courant.
//
// Le backend Rust ne fait plus que de l'I/O disque (load/save) — la logique
// de tirage vit côté TS dans draw.ts.

export const api = {
  configExists: () => invoke<boolean>("config_exists"),
  loadConfig: async (): Promise<AppConfig> =>
    migrate<AppConfig>("config", await invoke("load_config")),
  saveConfig: (config: AppConfig) => invoke<void>("save_config", { config }),

  listPlatforms: () => invoke<Platform[]>("list_platforms"),
  savePlatforms: (platforms: Platform[]) => invoke<void>("save_platforms", { platforms }),

  loadGames: async (platformId: string): Promise<GameLibrary> =>
    migrate<GameLibrary>("library", await invoke("load_games", { platformId })),
  saveGames: (library: GameLibrary) => invoke<void>("save_games", { library }),

  loadSession: async (): Promise<DrawSession> =>
    migrate<DrawSession>("session", await invoke("load_session")),
  saveSession: (session: DrawSession) => invoke<void>("save_session", { session }),

  loadHistorique: async (): Promise<Historique> =>
    migrate<Historique>("historique", await invoke("load_historique")),
  saveHistorique: (historique: Historique) => invoke<void>("save_historique", { historique }),

  loadBadges: async (): Promise<Badges> => migrate<Badges>("badges", await invoke("load_badges")),
  saveBadges: (badges: Badges) => invoke<void>("save_badges", { badges }),

  /** Journalise un message dans error.log (même fichier que le backend). */
  logError: (message: string) => invoke<void>("log_error", { message }),

  /** Recherche RAWG — entièrement côté Rust (reqwest), jamais un fetch()
   * frontend, pour ne pas avoir à autoriser api.rawg.io dans la CSP. */
  rawgSearch: (apiKey: string, query: string) => invoke<RawgGame[]>("rawg_search", { apiKey, query }),
  /** Télécharge une jaquette RAWG et la copie dans le dossier de données ;
   * retourne le chemin local (jamais l'URL distante gardée telle quelle). */
  downloadCover: (platformId: string, gameId: string, url: string) =>
    invoke<string>("download_cover", { platformId, gameId, url }),
  /** Copie un fichier local choisi via le sélecteur de fichier dans le
   * dossier de données ; retourne le chemin copié. */
  saveLocalCover: (platformId: string, gameId: string, sourcePath: string) =>
    invoke<string>("save_local_cover", { platformId, gameId, sourcePath }),

  /** Import Steam — entièrement côté Rust, même principe que RAWG. */
  steamOwnedGames: (apiKey: string, steamId: string) =>
    invoke<SteamGame[]>("steam_owned_games", { apiKey, steamId }),

  /** Export d'une bibliothèque (jeux + jaquettes) en .zip portable. */
  exportLibraryZip: (platformId: string, destPath: string) =>
    invoke<void>("export_library_zip", { platformId, destPath }),
  /** Import d'un .zip exporté par GameDraw — retourne les jeux importés
   * (nouveaux identifiants, jaquettes déjà copiées localement), à fusionner
   * dans la bibliothèque cible côté frontend (dédoublonnage par nom). */
  importLibraryZip: (platformId: string, sourcePath: string) =>
    invoke<GameLibrary>("import_library_zip", { platformId, sourcePath }),

  /** Lit un fichier texte choisi par l'utilisateur (import CSV) — en Rust,
   * pas via le plugin fs JS (évite un scope de permission supplémentaire). */
  readTextFile: (path: string) => invoke<string>("read_text_file", { path }),

  /** Sauvegarde COMPLÈTE du dossier de données (config, plateformes, toutes
   * les bibliothèques + jaquettes, historique, session) — contrairement à
   * exportLibraryZip qui ne fait qu'une plateforme. `password` optionnel
   * (chiffrement AES-256 si renseigné). */
  /** IRRÉVERSIBLE — efface toutes les données. Double confirmation exigée
   * côté appelant avant d'appeler ceci. */
  effacerToutesDonnees: () => invoke<void>("effacer_toutes_donnees"),

  exportBackup: (destPath: string, password?: string) => invoke<void>("export_backup", { destPath, password: password || null }),
  /** Restaure une sauvegarde complète — DESTRUCTIF (écrase les fichiers
   * existants). Toujours confirmer avec l'utilisateur avant d'appeler ceci,
   * et prévenir qu'un redémarrage de l'app est nécessaire après. Fournir le
   * même mot de passe que celui utilisé à l'export, si applicable. */
  importBackup: (sourcePath: string, password?: string) => invoke<void>("import_backup", { sourcePath, password: password || null }),

  /** Recherche de jaquette SANS clé API (endpoint public Steam Store,
   * aucune inscription requise) — alternative à rawgSearch pour qui ne
   * veut pas créer de compte. Ne couvre que les jeux présents sur Steam. */
  steamStoreSearch: (query: string) => invoke<RawgGame[]>("steam_store_search", { query }),

  /** Recherche de jaquette via SteamGridDB (clé requise) — en complément du
   * lien "fenêtre intégrée" (sans clé) proposé dans la Fiche du jeu. */
  steamgriddbSearch: (apiKey: string, query: string) => invoke<RawgGame[]>("steamgriddb_search", { apiKey, query }),

  /** Change l'icône de la fenêtre en cours d'exécution (barre des tâches/
   * barre de titre) — PAS l'icône du .exe/raccourci, figée à la compilation. */
  definirIconeFenetre: (variante: string) => invoke<void>("definir_icone_fenetre", { variante }),
};

export interface RawgGame {
  id: number;
  nom: string;
  coverUrl: string | null;
}

export interface SteamGame {
  appid: number;
  nom: string;
}
