use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};

pub const SCHEMA_VERSION: u32 = 1;

// --- Modèles (miroir de src/lib/types.ts) ----------------------------------

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct AppConfig {
    #[serde(rename = "schemaVersion")]
    pub schema_version: u32,
    // v29 : langue d'interface. Rust la transporte et la préserve ;
    // les traductions restent côté frontend.
    #[serde(default = "defaut_langue")]
    pub langue: String,
    pub theme: String,
    #[serde(rename = "rawgApiKey", default)]
    pub rawg_api_key: String,
    // Champs ajoutés en v4 (Phase 5) côté TS mais oubliés ici côté Rust —
    // silencieusement perdus à chaque save_config puisque serde ignore les
    // champs JSON inconnus par défaut. Corrigé en même temps que v8.
    #[serde(rename = "steamApiKey", default)]
    pub steam_api_key: String,
    #[serde(rename = "steamId64", default)]
    pub steam_id_64: String,
    #[serde(rename = "iconeNotation", default = "defaut_icone_notation")]
    pub icone_notation: String,
    // Ajoutés en v9 (Phase 7 — Options > Tirage/Apparence).
    #[serde(rename = "animationStyle", default = "defaut_animation_style")]
    pub animation_style: String,
    #[serde(rename = "revealEffect", default = "defaut_reveal_effect")]
    pub reveal_effect: String,
    #[serde(rename = "animationDurationMs", default = "defaut_animation_duration_ms")]
    pub animation_duration_ms: u32,
    // Ajouté en v20 : durée de l'effet de RÉVÉLATION, séparée de celle du
    // tirage (animation_duration_ms, qui ne couvrait que le tirage lui-même).
    #[serde(rename = "revealDurationMs", default = "defaut_reveal_duration_ms")]
    pub reveal_duration_ms: u32,
    #[serde(rename = "eviterRepetitions", default = "defaut_true")]
    pub eviter_repetitions: bool,
    #[serde(rename = "avertirAvantNouveauTirage", default = "defaut_true")]
    pub avertir_avant_nouveau_tirage: bool,
    #[serde(rename = "notifierFinSession", default = "defaut_true")]
    pub notifier_fin_session: bool,
    // Ajouté en v19 : notification/toast dédiés au déblocage de succès.
    #[serde(rename = "notifierSucces", default = "defaut_true")]
    pub notifier_succes: bool,
    // v20 : objectifs de session avec unité (minutes/heures/jours), plus
    // seulement des minutes brutes.
    #[serde(rename = "objectifParDefaut", default = "defaut_objectif_par_defaut")]
    pub objectif_par_defaut: ObjectifSession,
    #[serde(rename = "objectifsDisponibles", default = "defaut_objectifs_disponibles")]
    pub objectifs_disponibles: Vec<ObjectifSession>,
    #[serde(rename = "nombreHistorique", default = "defaut_nombre_historique")]
    pub nombre_historique: u32,
    #[serde(default = "defaut_densite")]
    pub densite: String,
    #[serde(rename = "afficherSelecteurTheme", default = "defaut_true")]
    pub afficher_selecteur_theme: bool,
    // Ajouté en v20 (Options > Apparence) : anime ou non la pastille de
    // statut clignotante du Backlog.
    #[serde(rename = "ledAnimation", default = "defaut_led_animation")]
    pub led_animation: String,
    // Ajoutés en v22 : sons de l'app (synthétisés côté frontend) et style
    // de transition entre onglets — Rust ne fait que les transporter.
    #[serde(rename = "sonsActifs", default = "defaut_true")]
    pub sons_actifs: bool,
    #[serde(rename = "volumeSons", default = "defaut_volume_sons")]
    pub volume_sons: f64,
    #[serde(rename = "transitionOnglets", default = "defaut_transition_onglets")]
    pub transition_onglets: String,
    // Ajouté en v23 : onglets masqués de la navigation (jamais "tirage" ni
    // "options" — garde-fou côté frontend).
    #[serde(rename = "ongletsMasques", default)]
    pub onglets_masques: Vec<String>,
    // Ajoutés en v24 : tirage multiple + mode roulette russe.
    #[serde(rename = "nombreTirages", default = "defaut_nombre_tirages")]
    pub nombre_tirages: u32,
    #[serde(rename = "rouletteRusse", default)]
    pub roulette_russe: bool,
    // Ajouté en v25 : récap en haut de l'onglet Tirage.
    #[serde(rename = "afficherRecap", default = "defaut_true")]
    pub afficher_recap: bool,
    // Ajouté en v27 : jaquette du jeu tiré dans la zone de résultat.
    #[serde(rename = "afficherCoverResultat", default = "defaut_true")]
    pub afficher_cover_resultat: bool,
    // Ajouté en v27 : blocs du récap d'accueil masqués individuellement.
    #[serde(rename = "blocsRecapMasques", default)]
    pub blocs_recap_masques: Vec<String>,
    // Ajouté en v28 : mise en scène du compte à rebours.
    #[serde(rename = "styleChrono", default = "defaut_style_chrono")]
    pub style_chrono: String,
    // Ajoutés en v26 : journal d'usage minimal (succès non déductibles de la
    // bibliothèque ou de l'historique — thèmes essayés, fonctionnalités
    // utilisées au moins une fois).
    #[serde(rename = "themesEssayes", default)]
    pub themes_essayes: Vec<String>,
    #[serde(rename = "aUtiliseTirageMultiple", default)]
    pub a_utilise_tirage_multiple: bool,
    #[serde(rename = "aUtiliseRouletteRusse", default)]
    pub a_utilise_roulette_russe: bool,
    #[serde(rename = "aUtiliseFiltres", default)]
    pub a_utilise_filtres: bool,
    // Ajouté en v10 (Phase 7 — Options > Jeux & Statuts).
    #[serde(default = "defaut_statuts")]
    pub statuts: Vec<StatutDefinition>,
    // Ajouté en v11 — lu directement par Rust au démarrage (setup()) pour
    // décider de construire ou non l'icône barre système, cf. run().
    #[serde(rename = "reduireBarreSysteme", default)]
    pub reduire_barre_systeme: bool,
    // Ajouté en v13 (Options > Connexion), activation/désactivation
    // indépendante de chaque source de recherche AUTOMATIQUE de jaquette.
    #[serde(rename = "sourcesCoverActives", default = "defaut_sources_cover")]
    pub sources_cover_actives: SourcesCoverActives,
    // Ajouté en v16 : clé API SteamGridDB, en complément (pas en
    // remplacement) du lien fenêtre intégrée — les deux coexistent.
    #[serde(rename = "steamgriddbApiKey", default)]
    pub steamgriddb_api_key: String,
    // Ajouté en v17 : icône de la fenêtre en cours d'exécution (pas celle
    // du .exe/raccourci, figée à la compilation) — voir definir_icone_fenetre.
    #[serde(rename = "iconeFenetre", default = "defaut_icone_fenetre")]
    pub icone_fenetre: String,
    // Ajouté en v21 : succès masqués de la grille (pas supprimés, juste
    // cachés) — liste d'ids, vide par défaut (tous visibles).
    #[serde(rename = "badgesDesactives", default)]
    pub badges_desactives: Vec<String>,
}

fn defaut_langue() -> String {
    "fr".into()
}

fn defaut_icone_fenetre() -> String {
    "defaut".into()
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct SourcesCoverActives {
    // default individuel sur chaque champ, pas juste sur le struct entier :
    // "steamgriddb" en particulier a été ajouté, retiré (Wikipédia l'a
    // remplacé un temps), puis rajouté au fil des phases — un config.json
    // d'une version intermédiaire peut donc ne PAS avoir cette clé du tout,
    // ce qui ferait échouer le parsing de tout AppConfig sans ce default
    // (même bug que ObjectifSession, cf. commentaire plus haut).
    #[serde(default = "defaut_true")]
    pub rawg: bool,
    #[serde(default = "defaut_true")]
    pub steam: bool,
    #[serde(default = "defaut_true")]
    pub steamgriddb: bool,
}

fn defaut_sources_cover() -> SourcesCoverActives {
    SourcesCoverActives { rawg: true, steam: true, steamgriddb: true }
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct StatutDefinition {
    pub id: String,
    pub label: String,
    pub couleur: String,
    pub integre: bool,
    pub visible: bool,
}

fn defaut_statuts() -> Vec<StatutDefinition> {
    vec![
        StatutDefinition { id: "NonCommence".into(), label: "Non commencé".into(), couleur: "#F4F4F5".into(), integre: true, visible: true },
        StatutDefinition { id: "EnCours".into(), label: "En cours".into(), couleur: "#22C55E".into(), integre: true, visible: true },
        StatutDefinition { id: "EnPause".into(), label: "En pause".into(), couleur: "#EAB308".into(), integre: true, visible: true },
        StatutDefinition { id: "Termine".into(), label: "Terminé".into(), couleur: "#A855F7".into(), integre: true, visible: true },
        StatutDefinition { id: "Abandonne".into(), label: "Abandonné".into(), couleur: "#EF4444".into(), integre: true, visible: true },
    ]
}

fn defaut_icone_notation() -> String {
    "etoile".into()
}
fn defaut_true() -> bool {
    true
}
fn defaut_animation_style() -> String {
    "cartes".into()
}
fn defaut_reveal_effect() -> String {
    "confettis".into()
}
fn defaut_animation_duration_ms() -> u32 {
    1800
}
fn defaut_reveal_duration_ms() -> u32 {
    1200
}

#[derive(Debug, Serialize, Clone)]
pub struct ObjectifSession {
    pub valeur: f64,
    pub unite: String,
}

// Deserialize manuel (pas #[derive]) : accepte AUSSI l'ancien format
// pré-v20 (un simple nombre en minutes, ex. `"objectifParDefaut": 30.0`)
// en plus du nouveau `{ valeur, unite }`. Sans ça, un config.json créé
// avant ce changement de forme fait planter le parsing Rust au démarrage
// — la migration TS ne peut jamais s'exécuter puisque Rust échoue avant
// même de renvoyer les données au frontend (elle n'a aucune notion de
// "migration", juste un type Rust figé). Bug réel rencontré par Sensei.
impl<'de> serde::Deserialize<'de> for ObjectifSession {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        #[derive(Deserialize)]
        #[serde(untagged)]
        enum ObjectifSessionBrut {
            AncienNombre(f64),
            NouvelObjet { valeur: f64, unite: String },
        }
        Ok(match ObjectifSessionBrut::deserialize(deserializer)? {
            ObjectifSessionBrut::AncienNombre(n) => ObjectifSession { valeur: n, unite: "minutes".into() },
            ObjectifSessionBrut::NouvelObjet { valeur, unite } => ObjectifSession { valeur, unite },
        })
    }
}

fn defaut_objectif_par_defaut() -> ObjectifSession {
    ObjectifSession { valeur: 30.0, unite: "minutes".into() }
}
fn defaut_objectifs_disponibles() -> Vec<ObjectifSession> {
    vec![15.0, 30.0, 45.0, 60.0, 90.0]
        .into_iter()
        .map(|v| ObjectifSession { valeur: v, unite: "minutes".into() })
        .collect()
}
fn defaut_led_animation() -> String {
    "pulse".into()
}
fn defaut_volume_sons() -> f64 {
    0.6
}
fn defaut_nombre_tirages() -> u32 {
    1
}
fn defaut_style_chrono() -> String {
    "barre".into()
}
fn defaut_transition_onglets() -> String {
    "glissement".into()
}
fn defaut_nombre_historique() -> u32 {
    50
}
fn defaut_densite() -> String {
    "normal".into()
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            schema_version: SCHEMA_VERSION,
            langue: defaut_langue(),
            theme: "catppuccin".into(),
            rawg_api_key: String::new(),
            steam_api_key: String::new(),
            steam_id_64: String::new(),
            icone_notation: defaut_icone_notation(),
            animation_style: defaut_animation_style(),
            reveal_effect: defaut_reveal_effect(),
            animation_duration_ms: defaut_animation_duration_ms(),
            reveal_duration_ms: defaut_reveal_duration_ms(),
            eviter_repetitions: true,
            avertir_avant_nouveau_tirage: true,
            notifier_fin_session: true,
            notifier_succes: true,
            objectif_par_defaut: defaut_objectif_par_defaut(),
            objectifs_disponibles: defaut_objectifs_disponibles(),
            nombre_historique: defaut_nombre_historique(),
            densite: defaut_densite(),
            afficher_selecteur_theme: true,
            led_animation: defaut_led_animation(),
            sons_actifs: true,
            volume_sons: defaut_volume_sons(),
            transition_onglets: defaut_transition_onglets(),
            onglets_masques: Vec::new(),
            nombre_tirages: 1,
            roulette_russe: false,
            afficher_recap: true,
            afficher_cover_resultat: true,
            blocs_recap_masques: Vec::new(),
            style_chrono: defaut_style_chrono(),
            themes_essayes: Vec::new(),
            a_utilise_tirage_multiple: false,
            a_utilise_roulette_russe: false,
            a_utilise_filtres: false,
            statuts: defaut_statuts(),
            reduire_barre_systeme: false,
            sources_cover_actives: defaut_sources_cover(),
            steamgriddb_api_key: String::new(),
            icone_fenetre: defaut_icone_fenetre(),
            badges_desactives: Vec::new(),
        }
    }
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Platform {
    pub id: String,
    pub nom: String,
    pub actif: bool,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Game {
    pub id: String,
    pub nom: String,
    #[serde(rename = "dejaFait")]
    pub deja_fait: bool,
    // Champs ajoutés en v3 (Phase 4). #[serde(default)] est essentiel ici :
    // sans ça, Rust échouerait à lire un ancien jeux/<plateforme>.json (v1/v2,
    // ex. le fichier de test créé à la main en Phase 1) puisque ces champs y
    // sont absents. Rust ne fait que transmettre — c'est migrate() côté TS
    // qui donne leur vraie valeur par défaut sémantique (ex. "NonCommence").
    #[serde(default)]
    pub statut: String,
    #[serde(default)]
    pub note: f64,
    #[serde(default)]
    pub tags: String,
    #[serde(default)]
    pub description: String,
    #[serde(default)]
    pub commentaire: String,
    #[serde(rename = "typeFin", default)]
    pub type_fin: String,
    #[serde(default)]
    pub cover: Option<String>,
    // Ajoutés en v6 : marqueurs cœur.
    #[serde(rename = "envieDeFaire", default)]
    pub envie_de_faire: bool,
    #[serde(rename = "coupDeCoeur", default)]
    pub coup_de_coeur: bool,
    // Ajoutés en v7 : défis personnalisés + temps de jeu manuel.
    #[serde(default)]
    pub defis: Vec<Defi>,
    #[serde(rename = "heuresJouees", default)]
    pub heures_jouees: Option<f64>,
    // Ajouté en v12 : marqueur "100%" distinct du statut.
    #[serde(rename = "complete100", default)]
    pub complete_100: bool,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Defi {
    pub id: String,
    pub texte: String,
    pub complete: bool,
}

#[derive(Debug, Serialize, Deserialize, Clone, Default)]
pub struct GameLibrary {
    #[serde(rename = "schemaVersion")]
    pub schema_version: u32,
    #[serde(rename = "platformId")]
    pub platform_id: String,
    pub jeux: Vec<Game>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct DrawSession {
    #[serde(rename = "schemaVersion")]
    pub schema_version: u32,
    #[serde(rename = "platformId")]
    pub platform_id: Option<String>,
    #[serde(rename = "gameId")]
    pub game_id: Option<String>,
    #[serde(rename = "drawnAt")]
    pub drawn_at: Option<String>,
    // Champs ajoutés en v2 (Phase 3) côté TS mais oubliés ici côté Rust —
    // même bug que steamApiKey/steamId64 (Phase 5) : silencieusement perdus
    // à chaque save_session, ce qui cassait justement l'exigence de la
    // Phase 3 que le compte à rebours survive à une fermeture complète de
    // l'app (il ne pouvait pas se relire correctement au redémarrage).
    #[serde(rename = "goalMinutes", default)]
    pub goal_minutes: Option<f64>,
    #[serde(rename = "endsAt", default)]
    pub ends_at: Option<String>,
}

impl Default for DrawSession {
    fn default() -> Self {
        Self {
            schema_version: SCHEMA_VERSION,
            platform_id: None,
            game_id: None,
            drawn_at: None,
            goal_minutes: None,
            ends_at: None,
        }
    }
}

/// Une entrée par tirage effectué — Phase 6, sert aux Statistiques.
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct EntreeHistorique {
    #[serde(rename = "platformId")]
    pub platform_id: String,
    #[serde(rename = "gameId")]
    pub game_id: String,
    pub nom: String,
    #[serde(rename = "drawnAt")]
    pub drawn_at: String,
    #[serde(rename = "goalMinutes")]
    pub goal_minutes: Option<f64>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Historique {
    #[serde(rename = "schemaVersion", default)]
    pub schema_version: u32,
    #[serde(default)]
    pub entrees: Vec<EntreeHistorique>,
}

impl Default for Historique {
    fn default() -> Self {
        Self { schema_version: SCHEMA_VERSION, entrees: Vec::new() }
    }
}

/// Succès internes (gamification) — la LISTE des succès possibles est du
/// code côté TS (BADGE_DEFINITIONS), pas des données ; ce fichier ne garde
/// que l'état "débloqué ou non + quand".
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct BadgeDebloque {
    pub id: String,
    #[serde(rename = "dateDebloquee")]
    pub date_debloquee: String,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Badges {
    #[serde(rename = "schemaVersion", default)]
    pub schema_version: u32,
    #[serde(default)]
    pub debloquees: Vec<BadgeDebloque>,
}

impl Default for Badges {
    fn default() -> Self {
        Self { schema_version: SCHEMA_VERSION, debloquees: Vec::new() }
    }
}

// --- Lecture / écriture JSON générique --------------------------------------

/// Lit un fichier JSON, ou retourne la valeur par défaut si le fichier
/// n'existe pas encore (première utilisation / dossier de données neuf).
pub fn read_json_or_default<T>(path: &Path) -> Result<T, String>
where
    T: for<'de> Deserialize<'de> + Default,
{
    if !path.exists() {
        return Ok(T::default());
    }
    let raw = fs::read_to_string(path).map_err(|e| format!("lecture {:?}: {e}", path))?;
    serde_json::from_str(&raw).map_err(|e| format!("parsing {:?}: {e}", path))
}

pub fn write_json<T: Serialize>(path: &Path, value: &T) -> Result<(), String> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|e| format!("mkdir {:?}: {e}", parent))?;
    }
    let raw = serde_json::to_string_pretty(value).map_err(|e| e.to_string())?;
    // Écriture atomique : fichier temporaire puis rename, pour ne jamais
    // laisser un JSON tronqué en cas de crash pendant l'écriture.
    let tmp = path.with_extension("tmp");
    fs::write(&tmp, raw).map_err(|e| format!("ecriture {:?}: {e}", tmp))?;
    fs::rename(&tmp, path).map_err(|e| format!("rename vers {:?}: {e}", path))?;
    Ok(())
}

// --- Chemins -----------------------------------------------------------------

pub fn config_path(data_dir: &Path) -> PathBuf {
    data_dir.join("config.json")
}
pub fn platforms_path(data_dir: &Path) -> PathBuf {
    data_dir.join("plateformes.json")
}
pub fn games_path(data_dir: &Path, platform_id: &str) -> PathBuf {
    data_dir.join("jeux").join(format!("{platform_id}.json"))
}
pub fn session_path(data_dir: &Path) -> PathBuf {
    data_dir.join("session.json")
}
pub fn historique_path(data_dir: &Path) -> PathBuf {
    data_dir.join("historique.json")
}
pub fn badges_path(data_dir: &Path) -> PathBuf {
    data_dir.join("badges.json")
}
pub fn error_log_path(data_dir: &Path) -> PathBuf {
    data_dir.join("error.log")
}
/// Dossier des jaquettes locales pour une plateforme donnée — les jaquettes
/// choisies localement ou téléchargées depuis RAWG sont TOUJOURS copiées ici
/// (jamais juste référencées par leur chemin d'origine, qui pourrait
/// disparaître) : `images/<plateforme>/<idJeu>.<ext>`.
pub fn images_dir(data_dir: &Path, platform_id: &str) -> PathBuf {
    data_dir.join("images").join(platform_id)
}

/// Encodage percent minimal, suffisant pour une requête de recherche RAWG
/// (évite une dépendance supplémentaire pour un seul usage simple).
pub fn url_encode(s: &str) -> String {
    let mut out = String::new();
    for byte in s.as_bytes() {
        match byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => out.push(*byte as char),
            _ => out.push_str(&format!("%{:02X}", byte)),
        }
    }
    out
}

/// Ajoute une ligne horodatée à error.log (créé au premier appel). Best-effort
/// : une erreur d'écriture du journal lui-même ne doit jamais faire planter
/// l'appelant, donc les erreurs de log_error sont avalées par ses appelants
/// via `let _ =`.
pub fn append_error_log(data_dir: &Path, message: &str) -> Result<(), String> {
    use std::io::Write;
    let path = error_log_path(data_dir);
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|e| format!("mkdir {:?}: {e}", parent))?;
    }
    let mut file = fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(&path)
        .map_err(|e| format!("ouverture {:?}: {e}", path))?;
    let ts = chrono::Local::now().format("%Y-%m-%d %H:%M:%S");
    writeln!(file, "[{ts}] {message}").map_err(|e| format!("ecriture {:?}: {e}", path))?;
    Ok(())
}
