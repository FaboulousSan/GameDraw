mod data;

use data::{AppConfig, Badges, DrawSession, GameLibrary, Historique, Platform};
use std::path::PathBuf;
use tauri::{AppHandle, Manager};

fn data_dir(app: &AppHandle) -> Result<PathBuf, String> {
    app.path().app_data_dir().map_err(|e| e.to_string())
}

/// Journalise le résultat d'une commande dans error.log s'il s'agit d'une
/// erreur, puis le laisse passer tel quel vers l'appelant. Best-effort :
/// si le journal lui-même échoue à s'écrire, on ne fait pas planter la
/// commande d'origine pour autant.
fn logged<T>(app: &AppHandle, label: &str, result: Result<T, String>) -> Result<T, String> {
    if let Err(ref e) = result {
        if let Ok(dir) = data_dir(app) {
            let _ = data::append_error_log(&dir, &format!("[{label}] {e}"));
        }
    }
    result
}

#[tauri::command]
fn config_exists(app: AppHandle) -> Result<bool, String> {
    let dir = data_dir(&app)?;
    Ok(data::config_path(&dir).exists())
}

#[tauri::command]
fn load_config(app: AppHandle) -> Result<AppConfig, String> {
    let dir = data_dir(&app)?;
    logged(&app, "load_config", data::read_json_or_default(&data::config_path(&dir)))
}

#[tauri::command]
fn save_config(app: AppHandle, config: AppConfig) -> Result<(), String> {
    let dir = data_dir(&app)?;
    logged(&app, "save_config", data::write_json(&data::config_path(&dir), &config))
}

#[tauri::command]
fn list_platforms(app: AppHandle) -> Result<Vec<Platform>, String> {
    let dir = data_dir(&app)?;
    logged(&app, "list_platforms", data::read_json_or_default(&data::platforms_path(&dir)))
}

#[tauri::command]
fn save_platforms(app: AppHandle, platforms: Vec<Platform>) -> Result<(), String> {
    let dir = data_dir(&app)?;
    logged(&app, "save_platforms", data::write_json(&data::platforms_path(&dir), &platforms))
}

#[tauri::command]
fn load_games(app: AppHandle, platform_id: String) -> Result<GameLibrary, String> {
    let dir = data_dir(&app)?;
    let path = data::games_path(&dir, &platform_id);
    if !path.exists() {
        return Ok(GameLibrary {
            schema_version: data::SCHEMA_VERSION,
            platform_id,
            jeux: vec![],
        });
    }
    logged(&app, "load_games", data::read_json_or_default(&path))
}

#[tauri::command]
fn save_games(app: AppHandle, library: GameLibrary) -> Result<(), String> {
    let dir = data_dir(&app)?;
    let path = data::games_path(&dir, &library.platform_id);
    logged(&app, "save_games", data::write_json(&path, &library))
}

#[tauri::command]
fn load_session(app: AppHandle) -> Result<DrawSession, String> {
    let dir = data_dir(&app)?;
    logged(&app, "load_session", data::read_json_or_default(&data::session_path(&dir)))
}

#[tauri::command]
fn save_session(app: AppHandle, session: DrawSession) -> Result<(), String> {
    let dir = data_dir(&app)?;
    logged(&app, "save_session", data::write_json(&data::session_path(&dir), &session))
}

#[tauri::command]
fn load_historique(app: AppHandle) -> Result<Historique, String> {
    let dir = data_dir(&app)?;
    logged(&app, "load_historique", data::read_json_or_default(&data::historique_path(&dir)))
}

#[tauri::command]
fn save_historique(app: AppHandle, historique: Historique) -> Result<(), String> {
    let dir = data_dir(&app)?;
    logged(&app, "save_historique", data::write_json(&data::historique_path(&dir), &historique))
}

#[tauri::command]
fn load_badges(app: AppHandle) -> Result<Badges, String> {
    let dir = data_dir(&app)?;
    logged(&app, "load_badges", data::read_json_or_default(&data::badges_path(&dir)))
}

#[tauri::command]
fn save_badges(app: AppHandle, badges: Badges) -> Result<(), String> {
    let dir = data_dir(&app)?;
    logged(&app, "save_badges", data::write_json(&data::badges_path(&dir), &badges))
}

/// Permet au frontend de journaliser ses propres erreurs (catch JS, erreurs
/// non interceptées) dans le même error.log que le backend, avec un préfixe
/// distinct pour les repérer à la lecture.
#[tauri::command]
fn log_error(app: AppHandle, message: String) -> Result<(), String> {
    let dir = data_dir(&app)?;
    data::append_error_log(&dir, &format!("[frontend] {message}"))
}

// --- Icône de fenêtre (Options > Apparence) ---------------------------------
// L'icône du .exe/raccourci reste figée à la compilation (impossible à
// changer depuis l'app sans recompiler) — ceci ne change QUE l'icône de la
// fenêtre/barre des tâches pendant l'exécution. Icônes embarquées dans le
// binaire via include_bytes! (pas de résolution de chemin de ressource au
// runtime à gérer, plus simple et plus robuste).
const ICONE_FENETRE_DEFAUT: &[u8] = include_bytes!("../icons/icon.ico");
const ICONE_FENETRE_BLEU: &[u8] = include_bytes!("../icons/fenetres/bleu.ico");
const ICONE_FENETRE_SOMBRE: &[u8] = include_bytes!("../icons/fenetres/sombre.ico");
const ICONE_FENETRE_V2: &[u8] = include_bytes!("../icons/fenetres/v2.ico");

#[tauri::command]
fn definir_icone_fenetre(window: tauri::WebviewWindow, variante: String) -> Result<(), String> {
    let bytes: &[u8] = match variante.as_str() {
        "bleu" => ICONE_FENETRE_BLEU,
        "sombre" => ICONE_FENETRE_SOMBRE,
        "v2" => ICONE_FENETRE_V2,
        _ => ICONE_FENETRE_DEFAUT,
    };
    let image = tauri::image::Image::from_bytes(bytes).map_err(|e| format!("décodage icône : {e}"))?;
    window.set_icon(image).map_err(|e| format!("application icône : {e}"))
}

// --- RAWG (recherche de jaquette en ligne) — Phase 4 ------------------------
//
// Tout se fait côté Rust (reqwest), jamais via fetch() du frontend : ça évite
// d'avoir à autoriser api.rawg.io dans la CSP, et garde le webview aussi
// restreint que possible (principe déjà suivi pour le reste de l'app).

#[derive(serde::Deserialize)]
struct RawgSearchResponse {
    results: Vec<RawgGameRaw>,
}

#[derive(serde::Deserialize)]
struct RawgGameRaw {
    id: i64,
    name: String,
    background_image: Option<String>,
}

#[derive(serde::Serialize, Clone)]
pub struct RawgGame {
    pub id: i64,
    pub nom: String,
    #[serde(rename = "coverUrl")]
    pub cover_url: Option<String>,
}

#[tauri::command]
async fn rawg_search(app: AppHandle, api_key: String, query: String) -> Result<Vec<RawgGame>, String> {
    if api_key.trim().is_empty() {
        return Err("Clé API RAWG manquante.".into());
    }
    let url = format!(
        "https://api.rawg.io/api/games?key={}&search={}&page_size=8",
        data::url_encode(&api_key),
        data::url_encode(&query)
    );
    let result: Result<Vec<RawgGame>, String> = async {
        let resp = reqwest::get(&url).await.map_err(|e| format!("requête RAWG : {e}"))?;
        if !resp.status().is_success() {
            return Err(format!("RAWG a répondu {}", resp.status()));
        }
        let data: RawgSearchResponse = resp.json().await.map_err(|e| format!("réponse RAWG : {e}"))?;
        Ok(data
            .results
            .into_iter()
            .map(|g| RawgGame { id: g.id, nom: g.name, cover_url: g.background_image })
            .collect())
    }
    .await;
    logged(&app, "rawg_search", result)
}

// --- Recherche de jaquette sans clé API — endpoint public Steam -------------
// store.steampowered.com/api/storesearch n'exige aucune clé/inscription
// (utilisé par de nombreux outils tiers), contrairement à RAWG. Réutilise le
// type RawgGame comme forme de résultat commune (id/nom/coverUrl) plutôt que
// de dupliquer un type quasi identique côté TS.
// ⚠️ Endpoint non officiel/non documenté par Valve — sa forme de réponse
// exacte n'a pas pu être vérifiée avec certitude absolue (pas d'accès à un
// exemple de réponse réelle ici) ; à tester en conditions réelles.
#[derive(serde::Deserialize)]
struct SteamStoreSearchResponse {
    #[serde(default)]
    items: Vec<SteamStoreItemRaw>,
}
#[derive(serde::Deserialize)]
struct SteamStoreItemRaw {
    id: i64,
    name: String,
    tiny_image: Option<String>,
}

#[tauri::command]
async fn steam_store_search(app: AppHandle, query: String) -> Result<Vec<RawgGame>, String> {
    let url = format!(
        "https://store.steampowered.com/api/storesearch/?term={}&l=french&cc=FR",
        data::url_encode(&query)
    );
    let result: Result<Vec<RawgGame>, String> = async {
        let resp = reqwest::get(&url).await.map_err(|e| format!("requête Steam : {e}"))?;
        if !resp.status().is_success() {
            return Err(format!("Steam a répondu {}", resp.status()));
        }
        let data: SteamStoreSearchResponse = resp.json().await.map_err(|e| format!("réponse Steam : {e}"))?;
        Ok(data
            .items
            .into_iter()
            .map(|it| RawgGame { id: it.id, nom: it.name, cover_url: it.tiny_image })
            .collect())
    }
    .await;
    logged(&app, "steam_store_search", result)
}

// --- Recherche de jaquette — SteamGridDB (clé requise, en complément du -----
// lien "fenêtre intégrée" côté frontend, pas en remplacement) --------------
// Contrairement à RAWG (une seule requête), SteamGridDB sépare recherche de
// jeu et récupération des images ("grids") : deux requêtes par résultat.
// Limité aux 5 premiers résultats de recherche pour ne pas multiplier les
// appels réseau à l'excès sur une simple recherche de jaquette.
#[derive(serde::Deserialize)]
struct SgdbSearchResponse {
    #[serde(default)]
    data: Vec<SgdbGameRaw>,
}
#[derive(serde::Deserialize)]
struct SgdbGameRaw {
    id: i64,
    name: String,
}
#[derive(serde::Deserialize)]
struct SgdbGridsResponse {
    #[serde(default)]
    data: Vec<SgdbGridRaw>,
}
#[derive(serde::Deserialize)]
struct SgdbGridRaw {
    url: Option<String>,
    thumb: Option<String>,
}

#[tauri::command]
async fn steamgriddb_search(app: AppHandle, api_key: String, query: String) -> Result<Vec<RawgGame>, String> {
    if api_key.trim().is_empty() {
        return Err("Clé API SteamGridDB manquante.".into());
    }
    let result: Result<Vec<RawgGame>, String> = async {
        let client = reqwest::Client::new();
        let search_url = format!(
            "https://www.steamgriddb.com/api/v2/search/autocomplete/{}",
            data::url_encode(&query)
        );
        let resp = client
            .get(&search_url)
            .bearer_auth(&api_key)
            .send()
            .await
            .map_err(|e| format!("requête SteamGridDB : {e}"))?;
        if !resp.status().is_success() {
            return Err(format!("SteamGridDB a répondu {} (vérifie la clé API)", resp.status()));
        }
        let search_data: SgdbSearchResponse = resp.json().await.map_err(|e| format!("réponse SteamGridDB : {e}"))?;

        let mut jeux = Vec::new();
        for jeu in search_data.data.into_iter().take(5) {
            let grids_url = format!("https://www.steamgriddb.com/api/v2/grids/game/{}", jeu.id);
            let cover_url = match client.get(&grids_url).bearer_auth(&api_key).send().await {
                Ok(r) if r.status().is_success() => r
                    .json::<SgdbGridsResponse>()
                    .await
                    .ok()
                    .and_then(|g| g.data.into_iter().next())
                    .and_then(|g| g.thumb.or(g.url)),
                _ => None,
            };
            jeux.push(RawgGame { id: jeu.id, nom: jeu.name, cover_url });
        }
        Ok(jeux)
    }
    .await;
    logged(&app, "steamgriddb_search", result)
}

/// Télécharge une jaquette RAWG et la copie dans le dossier de données —
/// jamais juste l'URL distante gardée telle quelle (qui peut disparaître).
#[tauri::command]
async fn download_cover(app: AppHandle, platform_id: String, game_id: String, url: String) -> Result<String, String> {
    let result: Result<String, String> = async {
        let resp = reqwest::get(&url).await.map_err(|e| format!("téléchargement jaquette : {e}"))?;
        if !resp.status().is_success() {
            return Err(format!("téléchargement a échoué ({})", resp.status()));
        }
        let bytes = resp.bytes().await.map_err(|e| e.to_string())?;
        let ext = url.rsplit('.').next().filter(|e| e.len() <= 4).unwrap_or("jpg");
        let dir = data_dir(&app)?;
        let images = data::images_dir(&dir, &platform_id);
        std::fs::create_dir_all(&images).map_err(|e| format!("mkdir {:?}: {e}", images))?;
        let path = images.join(format!("{game_id}.{ext}"));
        std::fs::write(&path, &bytes).map_err(|e| format!("écriture {:?}: {e}", path))?;
        Ok(path.to_string_lossy().to_string())
    }
    .await;
    logged(&app, "download_cover", result)
}

/// Copie un fichier local choisi par l'utilisateur (sélecteur de fichier)
/// dans le dossier de données — même logique que download_cover, mais depuis
/// disque plutôt que depuis le réseau.
#[tauri::command]
fn save_local_cover(app: AppHandle, platform_id: String, game_id: String, source_path: String) -> Result<String, String> {
    let result: Result<String, String> = (|| {
        let source = std::path::Path::new(&source_path);
        let ext = source.extension().and_then(|e| e.to_str()).unwrap_or("jpg");
        let dir = data_dir(&app)?;
        let images = data::images_dir(&dir, &platform_id);
        std::fs::create_dir_all(&images).map_err(|e| format!("mkdir {:?}: {e}", images))?;
        let dest = images.join(format!("{game_id}.{ext}"));
        std::fs::copy(source, &dest).map_err(|e| format!("copie {:?} -> {:?}: {e}", source, dest))?;
        Ok(dest.to_string_lossy().to_string())
    })();
    logged(&app, "save_local_cover", result)
}

/// Lit un fichier texte choisi par l'utilisateur (import CSV) — en Rust
/// plutôt que via le plugin `fs` JS, pour ne pas avoir à calibrer un scope
/// de permission fs supplémentaire ; cohérent avec save_local_cover qui
/// fait déjà de l'I/O disque brute côté Rust pour un fichier choisi par
/// dialogue natif.
#[tauri::command]
fn read_text_file(app: AppHandle, path: String) -> Result<String, String> {
    logged(&app, "read_text_file", std::fs::read_to_string(&path).map_err(|e| format!("lecture {path}: {e}")))
}

// --- Steam (import de bibliothèque) — Phase 5 -------------------------------
// Même principe que RAWG : tout côté Rust, jamais de fetch() frontend.

#[derive(serde::Deserialize)]
struct SteamOwnedGamesResponse {
    response: SteamResponseInner,
}
#[derive(serde::Deserialize, Default)]
struct SteamResponseInner {
    games: Option<Vec<SteamGameRaw>>,
}
#[derive(serde::Deserialize)]
struct SteamGameRaw {
    appid: i64,
    name: String,
}

#[derive(serde::Serialize, Clone)]
pub struct SteamGame {
    pub appid: i64,
    pub nom: String,
}

#[tauri::command]
async fn steam_owned_games(app: AppHandle, api_key: String, steam_id: String) -> Result<Vec<SteamGame>, String> {
    if api_key.trim().is_empty() || steam_id.trim().is_empty() {
        return Err("Clé API Steam ou SteamID64 manquant.".into());
    }
    let url = format!(
        "https://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/?key={}&steamid={}&format=json&include_appinfo=true",
        data::url_encode(&api_key),
        data::url_encode(&steam_id)
    );
    let result: Result<Vec<SteamGame>, String> = async {
        let resp = reqwest::get(&url).await.map_err(|e| format!("requête Steam : {e}"))?;
        if !resp.status().is_success() {
            return Err(format!(
                "Steam a répondu {} (vérifie la clé API et que le profil Steam est public)",
                resp.status()
            ));
        }
        let data: SteamOwnedGamesResponse = resp.json().await.map_err(|e| format!("réponse Steam : {e}"))?;
        Ok(data
            .response
            .games
            .unwrap_or_default()
            .into_iter()
            .map(|g| SteamGame { appid: g.appid, nom: g.name })
            .collect())
    }
    .await;
    logged(&app, "steam_owned_games", result)
}

// --- Export / import de bibliothèque en .zip — Phase 5 ----------------------

/// Exporte les jeux d'une plateforme + leurs jaquettes en une archive .zip
/// portable : `games.json` (chemins de jaquette rendus RELATIFS à l'archive,
/// jamais des chemins absolus qui n'auraient aucun sens sur un autre PC) +
/// `covers/<id>.<ext>` pour chaque jaquette référencée.
#[tauri::command]
fn export_library_zip(app: AppHandle, platform_id: String, dest_path: String) -> Result<(), String> {
    let result: Result<(), String> = (|| {
        use std::io::Write;
        let dir = data_dir(&app)?;
        let library: GameLibrary = data::read_json_or_default(&data::games_path(&dir, &platform_id))?;

        let file = std::fs::File::create(&dest_path).map_err(|e| format!("création {dest_path}: {e}"))?;
        let mut zip = zip::ZipWriter::new(file);
        let options: zip::write::FileOptions<()> =
            zip::write::FileOptions::default().compression_method(zip::CompressionMethod::Deflated);

        let mut export_jeux = library.jeux.clone();
        for jeu in export_jeux.iter_mut() {
            if let Some(cover_path) = &jeu.cover {
                let src = std::path::Path::new(cover_path);
                if src.exists() {
                    let ext = src.extension().and_then(|e| e.to_str()).unwrap_or("jpg");
                    let rel = format!("covers/{}.{}", jeu.id, ext);
                    let bytes = std::fs::read(src).map_err(|e| format!("lecture jaquette {src:?}: {e}"))?;
                    zip.start_file(&rel, options.clone()).map_err(|e| e.to_string())?;
                    zip.write_all(&bytes).map_err(|e| e.to_string())?;
                    jeu.cover = Some(rel);
                } else {
                    jeu.cover = None;
                }
            }
        }

        let export_library = GameLibrary { schema_version: library.schema_version, platform_id, jeux: export_jeux };
        let json = serde_json::to_string_pretty(&export_library).map_err(|e| e.to_string())?;
        zip.start_file("games.json", options.clone()).map_err(|e| e.to_string())?;
        zip.write_all(json.as_bytes()).map_err(|e| e.to_string())?;
        zip.finish().map_err(|e| e.to_string())?;
        Ok(())
    })();
    logged(&app, "export_library_zip", result)
}

/// Importe une archive .zip exportée par GameDraw dans la plateforme cible.
/// Génère de NOUVEAUX identifiants pour chaque jeu importé (jamais de
/// collision possible avec la bibliothèque cible) et copie les jaquettes de
/// l'archive vers le dossier de données sous ces nouveaux identifiants.
/// Retourne les jeux importés — c'est le frontend qui les fusionne avec la
/// bibliothèque cible (dédoublonnage par nom déjà en place, cf. library.ts).
#[tauri::command]
fn import_library_zip(app: AppHandle, platform_id: String, source_path: String) -> Result<GameLibrary, String> {
    let result: Result<GameLibrary, String> = (|| {
        use std::io::Read;
        let dir = data_dir(&app)?;
        let file = std::fs::File::open(&source_path).map_err(|e| format!("ouverture {source_path}: {e}"))?;
        let mut archive = zip::ZipArchive::new(file).map_err(|e| format!("lecture de l'archive : {e}"))?;

        let mut games_json = String::new();
        {
            let mut entry = archive
                .by_name("games.json")
                .map_err(|_| "games.json introuvable dans l'archive (pas une export GameDraw ?)".to_string())?;
            entry.read_to_string(&mut games_json).map_err(|e| e.to_string())?;
        }
        let mut imported: GameLibrary =
            serde_json::from_str(&games_json).map_err(|e| format!("games.json invalide : {e}"))?;

        let images_dir = data::images_dir(&dir, &platform_id);
        std::fs::create_dir_all(&images_dir).map_err(|e| format!("mkdir {images_dir:?}: {e}"))?;

        let base_id = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_nanos();

        for (i, jeu) in imported.jeux.iter_mut().enumerate() {
            let nouvel_id = format!("{base_id:x}-{i}");
            if let Some(cover_rel) = jeu.cover.clone() {
                if let Ok(mut entry) = archive.by_name(&cover_rel) {
                    let ext = std::path::Path::new(&cover_rel).extension().and_then(|e| e.to_str()).unwrap_or("jpg");
                    let dest = images_dir.join(format!("{nouvel_id}.{ext}"));
                    let mut bytes = Vec::new();
                    entry.read_to_end(&mut bytes).map_err(|e| e.to_string())?;
                    std::fs::write(&dest, &bytes).map_err(|e| e.to_string())?;
                    jeu.cover = Some(dest.to_string_lossy().to_string());
                } else {
                    jeu.cover = None;
                }
            }
            jeu.id = nouvel_id;
        }
        imported.platform_id = platform_id;
        Ok(imported)
    })();
    logged(&app, "import_library_zip", result)
}

// --- Sauvegarde / restauration complète (Options > Données) — suite Phase 7 -

/// Sauvegarde TOUT le dossier de données (config, plateformes, toutes les
/// bibliothèques + jaquettes, historique, session) en une seule archive
/// .zip — contrairement à export_library_zip qui ne fait qu'une plateforme.
/// Chemins relatifs préservés tels quels (pas de remise en forme "portable"
/// comme pour l'export par plateforme) : cette sauvegarde est prévue pour
/// revenir sur GameDraw, pas pour être mélangée à une autre bibliothèque.
///
/// Efface TOUTES les données de l'application (config, plateformes,
/// bibliothèques, session, historique, succès, jaquettes téléchargées).
/// IRRÉVERSIBLE — la double confirmation est gérée côté frontend.
///
/// Supprime le contenu du dossier de données plutôt que le dossier lui-même :
/// Tauri l'a déjà résolu au démarrage, le supprimer laisserait un chemin
/// invalide en mémoire pour le reste de la session.
#[tauri::command]
fn effacer_toutes_donnees(app: AppHandle) -> Result<(), String> {
    let dir = data_dir(&app)?;
    let result: Result<(), String> = (|| {
        let entries = std::fs::read_dir(&dir).map_err(|e| format!("lecture du dossier : {e}"))?;
        for entry in entries {
            let entry = entry.map_err(|e| format!("entrée illisible : {e}"))?;
            let chemin = entry.path();
            // Le journal d'erreurs est conservé : c'est justement ce qui
            // permet de diagnostiquer un souci survenu pendant l'effacement.
            if chemin.file_name().and_then(|n| n.to_str()) == Some("error.log") {
                continue;
            }
            if chemin.is_dir() {
                std::fs::remove_dir_all(&chemin).map_err(|e| format!("suppression dossier : {e}"))?;
            } else {
                std::fs::remove_file(&chemin).map_err(|e| format!("suppression fichier : {e}"))?;
            }
        }
        Ok(())
    })();
    logged(&app, "effacer_toutes_donnees", result)
}

/// `password` optionnel : si renseigné, chaque fichier est chiffré en
/// AES-256 (crate feature `aes-crypto`). ⚠️ API vérifiée contre la doc
/// officielle du crate `zip`, mais pas contre notre version exacte figée
/// (impossible de compiler ici) — à confirmer en ouvrant l'archive
/// exportée avec un outil zip normal et en vérifiant qu'il demande bien le
/// mot de passe avant de s'y fier pour des données sensibles.
#[tauri::command]
fn export_backup(app: AppHandle, dest_path: String, password: Option<String>) -> Result<(), String> {
    let result: Result<(), String> = (|| {
        use std::io::Write;
        let dir = data_dir(&app)?;
        std::fs::create_dir_all(&dir).map_err(|e| format!("mkdir {dir:?}: {e}"))?;

        let file = std::fs::File::create(&dest_path).map_err(|e| format!("création {dest_path}: {e}"))?;
        let mut zip = zip::ZipWriter::new(file);
        let base_options: zip::write::FileOptions<()> =
            zip::write::FileOptions::default().compression_method(zip::CompressionMethod::Deflated);
        let mot_de_passe = password.filter(|p| !p.trim().is_empty());

        for entry in walkdir::WalkDir::new(&dir).into_iter().filter_map(|e| e.ok()) {
            let path = entry.path();
            let rel = path.strip_prefix(&dir).map_err(|e| e.to_string())?;
            if rel.as_os_str().is_empty() {
                continue; // la racine elle-même, rien à ajouter
            }
            // Le format zip attend des séparateurs '/' même sur Windows.
            let rel_str = rel.to_string_lossy().replace('\\', "/");
            if path.is_dir() {
                zip.add_directory(format!("{rel_str}/"), base_options.clone()).map_err(|e| e.to_string())?;
            } else {
                let options = match &mot_de_passe {
                    Some(pw) => base_options.clone().with_aes_encryption(zip::AesMode::Aes256, pw),
                    None => base_options.clone(),
                };
                zip.start_file(&rel_str, options).map_err(|e| e.to_string())?;
                let bytes = std::fs::read(path).map_err(|e| format!("lecture {path:?}: {e}"))?;
                zip.write_all(&bytes).map_err(|e| e.to_string())?;
            }
        }
        zip.finish().map_err(|e| e.to_string())?;
        Ok(())
    })();
    logged(&app, "export_backup", result)
}

/// Restaure une sauvegarde complète : écrase les fichiers existants du
/// dossier de données avec le contenu de l'archive. Destructif — c'est au
/// frontend de confirmer avec l'utilisateur avant d'appeler cette commande
/// (même dialogue maison que le reste de l'app). Un redémarrage de l'app
/// est nécessaire après restauration pour que tout l'état en mémoire
/// (config, bibliothèque active, session, historique) reflète les
/// fichiers restaurés.
///
/// `password` : à fournir si (et seulement si) l'archive a été exportée
/// avec un mot de passe. ⚠️ Si l'archive est chiffrée mais qu'aucun mot de
/// passe n'est fourni ici, les fichiers seront écrits sous leur forme
/// chiffrée brute (corrompus) plutôt que de lever une erreur claire — la
/// détection fiable de ce cas précis n'a pas pu être vérifiée sans pouvoir
/// compiler. Recommandation à Sensei : toujours fournir le mot de passe
/// utilisé à l'export, et vérifier après restauration que l'app se relance
/// normalement (sinon, refaire la restauration avec le bon mot de passe).
#[tauri::command]
fn import_backup(app: AppHandle, source_path: String, password: Option<String>) -> Result<(), String> {
    let result: Result<(), String> = (|| {
        use std::io::Read;
        let dir = data_dir(&app)?;
        std::fs::create_dir_all(&dir).map_err(|e| format!("mkdir {dir:?}: {e}"))?;

        let file = std::fs::File::open(&source_path).map_err(|e| format!("ouverture {source_path}: {e}"))?;
        let mut archive = zip::ZipArchive::new(file).map_err(|e| format!("lecture de l'archive : {e}"))?;
        let mot_de_passe = password.filter(|p| !p.trim().is_empty());

        for i in 0..archive.len() {
            // Vérifie d'abord (sans déchiffrer) si c'est un dossier — un
            // dossier n'est jamais chiffré à l'export, inutile et risqué
            // d'appeler by_index_decrypt dessus.
            let est_un_dossier = archive.by_index(i).map_err(|e| e.to_string())?.is_dir();

            if est_un_dossier {
                let entry = archive.by_index(i).map_err(|e| e.to_string())?;
                let Some(rel) = entry.enclosed_name() else { continue };
                std::fs::create_dir_all(dir.join(rel)).map_err(|e| e.to_string())?;
                continue;
            }

            let mut entry = match &mot_de_passe {
                // by_index_decrypt() retourne un seul niveau de Result dans
                // cette version du crate zip (pas Result<Result<...>>
                // comme supposé initialement sans pouvoir compiler pour
                // vérifier) — une erreur ici couvre aussi bien un mauvais
                // mot de passe qu'un problème de lecture.
                Some(pw) => archive
                    .by_index_decrypt(i, pw.as_bytes())
                    .map_err(|e| format!("Mot de passe incorrect ou archive invalide : {e}"))?,
                None => archive.by_index(i).map_err(|e| e.to_string())?,
            };
            // enclosed_name() refuse les chemins qui tenteraient de sortir du
            // dossier cible (protection "zip slip") — jamais de confiance
            // aveugle dans les chemins fournis par une archive externe.
            let Some(rel) = entry.enclosed_name() else { continue };
            let outpath = dir.join(rel);
            if let Some(parent) = outpath.parent() {
                std::fs::create_dir_all(parent).map_err(|e| format!("mkdir {parent:?}: {e}"))?;
            }
            let mut bytes = Vec::new();
            entry.read_to_end(&mut bytes).map_err(|e| e.to_string())?;
            std::fs::write(&outpath, &bytes).map_err(|e| format!("écriture {outpath:?}: {e}"))?;
        }
        Ok(())
    })();
    logged(&app, "import_backup", result)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_opener::init())
        .setup(|app| {
            // Hook de panic Rust : capture les panics natives (pas seulement
            // les erreurs métier retournées en Result) dans error.log, avec
            // le chemin du dossier de données figé une fois au démarrage.
            if let Ok(dir) = app.handle().path().app_data_dir() {
                std::panic::set_hook(Box::new(move |info| {
                    let _ = data::append_error_log(&dir, &format!("[panic] {info}"));
                }));
            }

            // Barre système (Options > Apparence) — RÉACTIVÉE en v23.
            //
            // La vraie cause du plantage au démarrage (exit 101, aucun message)
            // n'était PAS cette fonctionnalité : c'était la ligne
            // read_json_or_default() ci-dessous qui échouait à parser un
            // config.json à l'ancien format (objectifParDefaut: 30.0, un
            // nombre brut au lieu de { valeur, unite }). Une erreur retournée
            // depuis setup() fait paniquer Tauri sans message exploitable.
            // Retirer tray-icon avait supprimé cette lecture par effet de
            // bord, d'où le faux diagnostic. Le Deserialize tolérant sur
            // ObjectifSession (v22) corrige la vraie cause.
            //
            // Sécurité en plus : la lecture de config ne peut PLUS faire
            // échouer setup(). En cas d'erreur, on journalise et on continue
            // avec les valeurs par défaut — une config illisible ne doit
            // jamais empêcher l'app de démarrer.
            let dir = data_dir(app.handle())?;
            let config: AppConfig = match data::read_json_or_default(&data::config_path(&dir)) {
                Ok(c) => c,
                Err(e) => {
                    let _ = data::append_error_log(
                        &dir,
                        &format!("[setup] config illisible ({e}) — démarrage avec les valeurs par défaut"),
                    );
                    AppConfig::default()
                }
            };

            if config.reduire_barre_systeme {
                use tauri::{
                    menu::{MenuBuilder, MenuItemBuilder},
                    tray::TrayIconBuilder,
                    WindowEvent,
                };

                // Ne PAS paniquer si l'icône par défaut est indisponible — la
                // barre système est une commodité, pas une fonctionnalité
                // essentielle.
                if let Some(icone) = app.default_window_icon().cloned() {
                    let ouvrir = MenuItemBuilder::with_id("ouvrir", "Ouvrir").build(app)?;
                    let quitter = MenuItemBuilder::with_id("quitter", "Quitter").build(app)?;
                    let menu = MenuBuilder::new(app).items(&[&ouvrir, &quitter]).build()?;

                    TrayIconBuilder::new()
                        .icon(icone)
                        .menu(&menu)
                        .tooltip("GameDraw")
                        .on_menu_event(|app, event| match event.id().as_ref() {
                            "ouvrir" => {
                                if let Some(w) = app.get_webview_window("main") {
                                    let _ = w.show();
                                    let _ = w.set_focus();
                                }
                            }
                            "quitter" => app.exit(0),
                            _ => {}
                        })
                        .on_tray_icon_event(|tray, event| {
                            if let tauri::tray::TrayIconEvent::Click {
                                button: tauri::tray::MouseButton::Left,
                                button_state: tauri::tray::MouseButtonState::Up,
                                ..
                            } = event
                            {
                                let app = tray.app_handle();
                                if let Some(w) = app.get_webview_window("main") {
                                    let _ = w.show();
                                    let _ = w.set_focus();
                                }
                            }
                        })
                        .build(app)?;

                    // La croix réduit dans la barre système au lieu de quitter.
                    if let Some(w) = app.get_webview_window("main") {
                        w.on_window_event(move |event| {
                            if let WindowEvent::CloseRequested { api, .. } = event {
                                api.prevent_close();
                            }
                        });
                    }
                } else {
                    let _ = data::append_error_log(
                        &dir,
                        "[setup] icône par défaut introuvable — barre système désactivée pour cette session",
                    );
                }
            }

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            config_exists,
            load_config,
            save_config,
            list_platforms,
            save_platforms,
            load_games,
            save_games,
            load_session,
            save_session,
            load_historique,
            save_historique,
            load_badges,
            save_badges,
            log_error,
            definir_icone_fenetre,
            rawg_search,
            download_cover,
            save_local_cover,
            read_text_file,
            steam_owned_games,
            export_library_zip,
            import_library_zip,
            effacer_toutes_donnees,
            export_backup,
            import_backup,
            steam_store_search,
            steamgriddb_search,
        ])
        .run(tauri::generate_context!())
        .expect("erreur au lancement de GameDraw");
}
