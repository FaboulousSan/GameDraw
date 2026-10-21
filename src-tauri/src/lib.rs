mod data;
mod cover_utils;
mod github_updates;

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

// --- Branding Windows GameDraw 1.0.3 ---------------------------------------
// HF20 : les petites icones sont DESSINEES pour leur taille et non simplement
// reduites depuis l'illustration 1024px. ICO EXE multi-resolutions pour le
// ICO multiresolution pour le Bureau, PNG RGBA 256px pour la fenetre et
// sa barre des taches DPI (evite de remplacer l'icone haute resolution par
// un rendu 64px au lancement), 32px distinct pour la zone de notification.
// La taille physique de la barre des taches reste geree par Windows.
// Toutes les images sont RGBA alpha et embarquees sans fichiers runtime.
const ICONE_CLAIRE_RGBA: &[u8] = include_bytes!("../icons/icon-light-sizes/icon-light-256.png");
const ICONE_SOMBRE_RGBA: &[u8] = include_bytes!("../icons/icon-dark-sizes/icon-dark-256.png");
const ICONE_CLAIRE_TRAY_RGBA: &[u8] = include_bytes!("../icons/icon-light-sizes/icon-light-32.png");
const ICONE_SOMBRE_TRAY_RGBA: &[u8] = include_bytes!("../icons/icon-dark-sizes/icon-dark-32.png");
const ID_TRAY_GAMEDRAW: &str = "gamedraw-main";

fn image_icone_fenetre(variante: &str) -> Result<tauri::image::Image<'static>, String> {
    // Les anciens identifiants "bleu" et "v2" restent compatibles avec
    // config.json sans migration du schema (ils basculent vers la claire).
    let bytes = if variante == "sombre" { ICONE_SOMBRE_RGBA } else { ICONE_CLAIRE_RGBA };
    tauri::image::Image::from_bytes(bytes)
        .map(|image| image.to_owned())
        .map_err(|e| format!("decodage icone RGBA : {e}"))
}

fn image_icone_tray(variante: &str) -> Result<tauri::image::Image<'static>, String> {
    let bytes = if variante == "sombre" { ICONE_SOMBRE_TRAY_RGBA } else { ICONE_CLAIRE_TRAY_RGBA };
    tauri::image::Image::from_bytes(bytes)
        .map(|image| image.to_owned())
        .map_err(|e| format!("decodage icone tray RGBA : {e}"))
}

#[tauri::command]
fn definir_icone_fenetre(window: tauri::WebviewWindow, variante: String) -> Result<(), String> {
    // La fenetre et le bouton dans la barre des taches partagent son icone.
    window
        .set_icon(image_icone_fenetre(&variante)?)
        .map_err(|e| format!("application icone de fenetre : {e}"))?;
    // Si l'utilisateur active la reduction en barre systeme, conserver la
    // meme identite visuelle dans la zone de notification (sans recreer tray).
    if let Some(tray) = window.app_handle().tray_by_id(ID_TRAY_GAMEDRAW) {
        tray.set_icon(Some(image_icone_tray(&variante)?))
            .map_err(|e| format!("application icone de barre systeme : {e}"))?;
    }
    Ok(())
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

// SteamGridDB HF5 : 2 étapes explicites (jeu puis galerie). Aucune WebView
// tierce ni récupération systématique de 5 galeries à chaque saisie.
// L'authentification reste dans Rust ; les clés et corps d'erreur HTTP ne sont
// jamais envoyés aux journaux. Les filtres sont une liste blanche côté backend.
#[derive(serde::Deserialize)]
struct SgdbSearchResponse {
    #[serde(default)]
    data: Vec<SgdbGameRaw>,
}
#[derive(serde::Deserialize, serde::Serialize)]
#[serde(rename_all = "camelCase")]
struct SgdbGameRaw {
    id: i64,
    name: String,
}
#[derive(serde::Deserialize)]
struct SgdbGridsResponse {
    #[serde(default)]
    data: Vec<SgdbGridRaw>,
    #[serde(default)]
    total: u32,
}
#[derive(serde::Deserialize)]
struct SgdbGridRaw {
    id: i64,
    url: Option<String>,
    thumb: Option<String>,
    style: Option<String>,
    author: Option<SgdbAuthorRaw>,
}
#[derive(serde::Deserialize)]
struct SgdbAuthorRaw {
    name: Option<String>,
}
#[derive(serde::Serialize)]
#[serde(rename_all = "camelCase")]
struct SgdbArtwork {
    id: i64,
    url: String,
    thumb: String,
    style: Option<String>,
    author_name: Option<String>,
}
#[derive(serde::Serialize)]
#[serde(rename_all = "camelCase")]
struct SgdbArtworkPage {
    images: Vec<SgdbArtwork>,
    page: u32,
    total: u32,
}

fn steamgriddb_client() -> Result<reqwest::Client, String> {
    reqwest::Client::builder()
        .connect_timeout(std::time::Duration::from_secs(8))
        .timeout(std::time::Duration::from_secs(20))
        .build()
        .map_err(|_| "Impossible de préparer la connexion SteamGridDB.".to_owned())
}

fn steamgriddb_key(key: &str) -> Result<&str, String> {
    let trimmed = key.trim();
    if trimmed.is_empty() {
        return Err("Clé SteamGridDB absente : configure-la dans Options → Connexion.".into());
    }
    if trimmed.len() > 512 || trimmed.chars().any(char::is_whitespace) {
        return Err("Format de clé SteamGridDB incorrect : colle uniquement la clé API, sans 'Bearer' ni espaces.".into());
    }
    Ok(trimmed)
}

async fn steamgriddb_response(resp: reqwest::Response) -> Result<reqwest::Response, String> {
    match resp.status() {
        reqwest::StatusCode::UNAUTHORIZED => Err("SteamGridDB HTTP 401 : clé API refusée. Vérifie la clé SteamGridDB dans Options → Connexion.".into()),
        reqwest::StatusCode::FORBIDDEN => Err("SteamGridDB HTTP 403 : accès refusé pour cette clé API.".into()),
        reqwest::StatusCode::TOO_MANY_REQUESTS => Err("SteamGridDB HTTP 429 : limite de requêtes atteinte. Réessaie plus tard.".into()),
        reqwest::StatusCode::NOT_FOUND => Err("SteamGridDB HTTP 404 : ressource introuvable. Essaie un autre titre ou jeu.".into()),
        status if status.is_server_error() => Err(format!("SteamGridDB HTTP {status} : service indisponible pour le moment.")),
        status if !status.is_success() => Err(format!("SteamGridDB HTTP {status} : recherche impossible.")),
        _ => Ok(resp),
    }
}

#[tauri::command]
async fn steamgriddb_games(app: AppHandle, api_key: String, query: String) -> Result<Vec<SgdbGameRaw>, String> {
    let result: Result<Vec<SgdbGameRaw>, String> = async {
        let key = steamgriddb_key(&api_key)?;
        let term = query.trim();
        if term.is_empty() || term.chars().count() > 120 {
            return Err("Indique un titre de jeu de 1 à 120 caractères.".into());
        }
        let url = format!("https://www.steamgriddb.com/api/v2/search/autocomplete/{}", data::url_encode(term));
        let resp = steamgriddb_client()?.get(url).bearer_auth(key).send().await
            .map_err(|_| "Connexion à SteamGridDB impossible ou délai dépassé (20 s).".to_owned())?;
        // Une recherche sans résultat peut retourner 404 selon le service.
        if resp.status() == reqwest::StatusCode::NOT_FOUND {
            return Ok(vec![]);
        }
        let resp = steamgriddb_response(resp).await?;
        let parsed: SgdbSearchResponse = resp.json().await
            .map_err(|_| "Réponse de recherche SteamGridDB illisible.".to_owned())?;
        Ok(parsed.data.into_iter().take(20).collect())
    }.await;
    logged(&app, "steamgriddb_games", result)
}

#[tauri::command]
async fn steamgriddb_artworks(
    app: AppHandle, api_key: String, game_id: i64, format: String, page: u32,
) -> Result<SgdbArtworkPage, String> {
    let result: Result<SgdbArtworkPage, String> = async {
        let key = steamgriddb_key(&api_key)?;
        if game_id <= 0 { return Err("Identifiant SteamGridDB invalide.".into()); }
        if page > 100 { return Err("Limite de pagination atteinte.".into()); }
        let dimensions = match format.as_str() {
            "portrait" => "600x900,342x482,660x930",
            "landscape" => "460x215,920x430",
            "square" => "512x512,1024x1024",
            _ => return Err("Format de jaquette inconnu.".into()),
        };
        let url = format!("https://www.steamgriddb.com/api/v2/grids/game/{game_id}");
        let page_text = page.to_string();
        let resp = steamgriddb_client()?.get(url)
            .query(&[("dimensions", dimensions), ("types", "static"), ("nsfw", "false"),
                ("humor", "false"), ("epilepsy", "false"), ("limit", "24"), ("page", page_text.as_str())])
            .bearer_auth(key)
            .send().await
            .map_err(|_| "Impossible de charger les jaquettes SteamGridDB (délai 20 s).".to_owned())?;
        let resp = steamgriddb_response(resp).await?;
        let parsed: SgdbGridsResponse = resp.json().await
            .map_err(|_| "Réponse de galerie SteamGridDB illisible.".to_owned())?;
        let images = parsed.data.into_iter().filter_map(|item| {
            // Ne jamais fournir un lien non HTTPS au navigateur ou au téléchargeur.
            let url = item.url?;
            if !url.starts_with("https://") { return None; }
            let thumb = item.thumb.filter(|t| t.starts_with("https://")).unwrap_or_else(|| url.clone());
            Some(SgdbArtwork {
                id: item.id, url, thumb, style: item.style,
                author_name: item.author.and_then(|a| a.name),
            })
        }).collect();
        Ok(SgdbArtworkPage { images, total: parsed.total, page })
    }.await;
    logged(&app, "steamgriddb_artworks", result)
}

// Compatibilité de l'ancienne commande pour les installations HF4 qui
// l'utiliseraient encore : elle n'est plus appelée par la nouvelle interface.
#[tauri::command]
async fn steamgriddb_search(app: AppHandle, api_key: String, query: String) -> Result<Vec<RawgGame>, String> {
    let games = steamgriddb_games(app.clone(), api_key.clone(), query).await?;
    let mut result = Vec::new();
    for game in games.into_iter().take(5) {
        let cover_url = steamgriddb_artworks(app.clone(), api_key.clone(), game.id, "portrait".into(), 0)
            .await.ok().and_then(|r| r.images.into_iter().next()).map(|a| a.url);
        result.push(RawgGame { id: game.id, nom: game.name, cover_url });
    }
    Ok(result)
}

#[cfg(test)]
mod steamgriddb_hf5_tests {
    use super::*;

    #[test]
    fn rejects_missing_or_spaced_keys_without_leaking_them() {
        assert!(steamgriddb_key(" ").is_err());
        assert!(steamgriddb_key("Bearer invalid").is_err());
        assert_eq!(steamgriddb_key("  sgdb-test-key  ").unwrap(), "sgdb-test-key");
    }

    #[test]
    fn parses_game_matches_and_artwork_page_samples() {
        let games: SgdbSearchResponse = serde_json::from_str(
            r#"{"success":true,"data":[{"id":11,"name":"Portal"},{"id":22,"name":"Portal 2"}]}"#
        ).unwrap();
        assert_eq!(games.data.len(), 2);
        let images: SgdbGridsResponse = serde_json::from_str(
            r#"{"total":2,"data":[{"id":123,"url":"https://cdn.example.org/original.png","thumb":"https://cdn.example.org/thumbnail.png","style":"alternate","author":{"name":"Artist"}}]}"#
        ).unwrap();
        assert_eq!(images.total, 2);
        assert_eq!(images.data[0].author.as_ref().unwrap().name.as_deref(), Some("Artist"));
    }
}

/// Télécharge et valide une jaquette. La réponse doit être une vraie image.
/// Les chemins générés changent à chaque mise à jour pour contourner le cache WebView2.
#[tauri::command]
async fn download_cover(app: AppHandle, platform_id: String, game_id: String, url: String) -> Result<String, String> {
    let result: Result<String, String> = async {
        cover_utils::safe_id(&platform_id)?;
        cover_utils::safe_id(&game_id)?;
        let parsed = reqwest::Url::parse(&url).map_err(|e| format!("Adresse de jaquette incorrecte: {e}"))?;
        if !["https", "http"].contains(&parsed.scheme()) {
            return Err("Les jaquettes distantes doivent utiliser HTTP ou HTTPS.".into());
        }
        if parsed.host_str().is_none() || !parsed.username().is_empty() || parsed.password().is_some() {
            return Err("L'adresse de jaquette n'est pas autorisée.".into());
        }
        let client = reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(25))
            .build().map_err(|e| format!("Client HTTP: {e}"))?;
        let resp = client.get(parsed).send().await.map_err(|e| format!("Téléchargement de jaquette impossible: {e}"))?;
        if !resp.status().is_success() {
            return Err(format!("Image non accessible (HTTP {}). Essaie une autre source ou un fichier local.", resp.status()));
        }
        if resp.content_length().is_some_and(|size| size > cover_utils::MAX_COVER_BYTES as u64) {
            return Err("Jaquette trop volumineuse (limite 15 Mio).".into());
        }
        let bytes = resp.bytes().await.map_err(|e| format!("Lecture de l'image: {e}"))?;
        let dir = data_dir(&app)?;
        let images = data::images_dir(&dir, &platform_id);
        cover_utils::store_image(&images, &game_id, &bytes)
    }.await;
    logged(&app, "download_cover", result)
}

/// Import local : même validation de format, mêmes chemins et même politique de cache.
#[tauri::command]
fn save_local_cover(app: AppHandle, platform_id: String, game_id: String, source_path: String) -> Result<String, String> {
    let result: Result<String, String> = (|| {
        cover_utils::safe_id(&platform_id)?;
        cover_utils::safe_id(&game_id)?;
        let source = std::path::Path::new(&source_path);
        let size = std::fs::metadata(source).map_err(|e| format!("Fichier inaccessible: {e}"))?.len();
        if size > cover_utils::MAX_COVER_BYTES as u64 { return Err("Image trop volumineuse (limite 15 Mio).".into()); }
        let bytes = std::fs::read(source).map_err(|e| format!("Lecture de l'image locale: {e}"))?;
        let dir = data_dir(&app)?;
        cover_utils::store_image(&data::images_dir(&dir, &platform_id), &game_id, &bytes)
    })();
    logged(&app, "save_local_cover", result)
}

/// Secours ciblé lorsque l'asset protocol WebView2 n'affiche pas un ancien chemin.
/// N'accepte que des fichiers contenus dans le dossier GameDraw ; aucun chemin arbitraire.
#[tauri::command]
fn read_cover_data_url(app: AppHandle, path: String) -> Result<String, String> {
    use base64::Engine as _;
    let result: Result<String, String> = (|| {
        let dir = std::fs::canonicalize(data_dir(&app)?).map_err(|e| format!("Données GameDraw introuvables: {e}"))?;
        let file = std::fs::canonicalize(&path).map_err(|e| format!("Jaquette introuvable: {e}"))?;
        if !file.starts_with(&dir.join("images")) {
            return Err("Accès refusé : la jaquette doit appartenir à GameDraw.".into());
        }
        if std::fs::metadata(&file).map_err(|e| e.to_string())?.len() > cover_utils::MAX_COVER_BYTES as u64 {
            return Err("Jaquette trop volumineuse.".into());
        }
        let bytes = std::fs::read(&file).map_err(|e| format!("Lecture jaquette: {e}"))?;
        let (_, mime) = cover_utils::format_image(&bytes)?;
        Ok(format!("data:{mime};base64,{}", base64::engine::general_purpose::STANDARD.encode(bytes)))
    })();
    logged(&app, "read_cover_data_url", result)
}

/// Lit un fichier texte choisi par l'utilisateur (import CSV) — en Rust
/// plutôt que via le plugin `fs` JS, pour ne pas avoir à calibrer un scope
/// de permission fs supplémentaire ; cohérent avec save_local_cover qui
/// fait déjà de l'I/O disque brute côté Rust pour un fichier choisi par
/// dialogue natif.
#[tauri::command]
fn read_text_file(app: AppHandle, path: String) -> Result<String, String> {
    const MAX_IMPORT_TEXT_BYTES: u64 = 5 * 1024 * 1024;
    let result = (|| {
        let taille = std::fs::metadata(&path)
            .map_err(|e| format!("Fichier d'import inaccessible : {e}"))?.len();
        if taille > MAX_IMPORT_TEXT_BYTES {
            return Err("Liste TXT/CSV trop volumineuse (maximum 5 Mio).".to_string());
        }
        // Les fichiers Excel/Bloc-notes peuvent contenir un BOM UTF-8.
        let contenu = std::fs::read_to_string(&path)
            .map_err(|e| format!("Lecture TXT/CSV impossible (UTF-8 requis) : {e}"))?;
        Ok(contenu.trim_start_matches('\u{feff}').to_string())
    })();
    logged(&app, "read_text_file", result)
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

            // Icône claire par defaut AVANT toute initialisation frontend.
            // Si la configuration choisit la sombre, elle s'applique aussi
            // immediatement au demarrage, sans flash d'une ancienne icone.
            if let Some(w) = app.get_webview_window("main") {
                if let Err(e) = w.set_icon(image_icone_fenetre(&config.icone_fenetre)?) {
                    let _ = data::append_error_log(&dir, &format!("[setup] icone de fenetre : {e}"));
                }
            }

            if config.reduire_barre_systeme {
                use tauri::{
                    menu::{MenuBuilder, MenuItemBuilder},
                    tray::TrayIconBuilder,
                    WindowEvent,
                };

                // Ne PAS paniquer si l'icône par défaut est indisponible — la
                // barre système est une commodité, pas une fonctionnalité
                // essentielle.
                if let Some(icone) = image_icone_tray(&config.icone_fenetre)
                    .ok()
                    .or_else(|| app.default_window_icon().cloned())
                {
                    let ouvrir = MenuItemBuilder::with_id("ouvrir", "Ouvrir").build(app)?;
                    let quitter = MenuItemBuilder::with_id("quitter", "Quitter").build(app)?;
                    let menu = MenuBuilder::new(app).items(&[&ouvrir, &quitter]).build()?;

                    TrayIconBuilder::with_id(ID_TRAY_GAMEDRAW)
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
            github_updates::github_release_check,
            github_updates::github_release_download,
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
            read_cover_data_url,
            read_text_file,
            steam_owned_games,
            export_library_zip,
            import_library_zip,
            effacer_toutes_donnees,
            export_backup,
            import_backup,
            steam_store_search,
            steamgriddb_search,
            steamgriddb_games,
            steamgriddb_artworks,
        ])
        .run(tauri::generate_context!())
        .expect("erreur au lancement de GameDraw");
}
