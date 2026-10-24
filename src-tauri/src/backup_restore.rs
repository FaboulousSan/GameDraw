//! Restauration de sauvegardes GameDraw : extraction preflight et bascule de dossier.
//! C5 / v1.0.7 : aucune écriture dans les données actives avant la validation complète.
//! Le ZIP est une sauvegarde complète du dossier app_data_dir, pas un ZIP de bibliothèque.
use std::collections::{HashMap, HashSet};
use std::fs::{self, File, OpenOptions};
use std::io::{self, Read, Write};
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

const MAX_ENTRIES: usize = 20_000;
const MAX_FILE_BYTES: u64 = 512 * 1024 * 1024;
const MAX_TOTAL_BYTES: u64 = 4 * 1024 * 1024 * 1024;
const MAX_REL_PATH_BYTES: usize = 768;
const MAX_DEPTH: usize = 32;

#[derive(Clone)]
struct EntryPlan { index: usize, rel: PathBuf, is_dir: bool, size: u64 }

/// Nettoie un chemin d'archive portable y compris sur Windows. Rejette aussi
/// les collisions de casse et chemins qui deviennent des noms spéciaux Win32.
fn valid_rel(name: &str) -> Result<(PathBuf, String), String> {
    if name.is_empty() || name.len() > MAX_REL_PATH_BYTES || name.starts_with('/') ||
        name.contains('\\') || name.contains('\0') { return Err(format!("Chemin ZIP dangereux ou trop long : {name:?}")); }
    let mut rel = PathBuf::new();
    let mut normalized = Vec::new();
    for part in name.trim_end_matches('/').split('/') {
        if part.is_empty() || part == "." || part == ".." || part.len() > 240 ||
            part.ends_with('.') || part.ends_with(' ') ||
            part.chars().any(|c| c.is_control() || "<>:\"|?*".contains(c)) {
            return Err(format!("Chemin ZIP non portable : {name:?}"));
        }
        let device = part.split('.').next().unwrap_or("").to_ascii_uppercase();
        if matches!(device.as_str(), "CON" | "PRN" | "AUX" | "NUL" |
            "COM1" | "COM2" | "COM3" | "COM4" | "COM5" | "COM6" | "COM7" | "COM8" | "COM9" |
            "LPT1" | "LPT2" | "LPT3" | "LPT4" | "LPT5" | "LPT6" | "LPT7" | "LPT8" | "LPT9") {
            return Err(format!("Nom réservé Windows dans le ZIP : {name:?}"));
        }
        rel.push(part);
        normalized.push(part.to_lowercase());
        if normalized.len() > MAX_DEPTH { return Err("Archive ZIP : dossiers imbriqués trop profondément".into()); }
    }
    if normalized.is_empty() { return Err("Chemin ZIP vide".into()); }
    Ok((rel, normalized.join("/")))
}

fn inspect_zip<R: Read + io::Seek>(archive: &mut zip::ZipArchive<R>) -> Result<Vec<EntryPlan>, String> {
    if archive.len() == 0 || archive.len() > MAX_ENTRIES { return Err("Archive ZIP vide ou trop de fichiers".into()); }
    let mut entries = Vec::with_capacity(archive.len());
    let mut total: u64 = 0;
    // true = dossier (explicite/implicite), false = fichier
    let mut seen: HashMap<String, bool> = HashMap::new();
    let mut explicit = HashSet::new();
    let mut recognized = false;
    for i in 0..archive.len() {
        // by_index_raw lit seulement les métadonnées : compatible avec entrées AES.
        let entry = archive.by_index_raw(i).map_err(|e| format!("Entrée ZIP #{i} illisible : {e}"))?;
        if entry.unix_mode().is_some_and(|m| {
            let kind = m & 0o170000;
            kind != 0 && kind != 0o040000 && kind != 0o100000
        }) { return Err(format!("Liens et fichiers spéciaux interdits : {}", entry.name())); }
        let is_dir = entry.is_dir();
        let (rel, key) = valid_rel(entry.name())?;
        if entry.enclosed_name().is_none() { return Err(format!("Chemin hors dossier : {}", entry.name())); }
        if !explicit.insert(key.clone()) { return Err(format!("Nom dupliqué dans le ZIP : {}", entry.name())); }
        let parts: Vec<&str> = key.split('/').collect();
        for depth in 1..parts.len() {
            let parent = parts[..depth].join("/");
            if matches!(seen.get(&parent), Some(false)) {
                return Err(format!("Conflit fichier/dossier ZIP : {}", entry.name()));
            }
            seen.insert(parent, true);
        }
        if seen.contains_key(&key) && !is_dir { return Err(format!("Conflit dossier/fichier ZIP : {}", entry.name())); }
        if seen.insert(key.clone(), is_dir).is_some_and(|prev| !prev) {
            return Err(format!("Conflit ZIP : {}", entry.name()));
        }
        if !is_dir {
            if entry.size() > MAX_FILE_BYTES { return Err(format!("Fichier ZIP trop gros : {}", entry.name())); }
            total = total.checked_add(entry.size()).ok_or("Taille ZIP trop importante")?;
            if total > MAX_TOTAL_BYTES { return Err("Archive décompressée trop volumineuse (4 Gio max)".into()); }
            if parts.len() == 1 && ["config.json", "plateformes.json", "session.json", "historique.json", "badges.json"].contains(&key.as_str()) {
                recognized = true;
            }
            if key.starts_with("jeux/") && key.ends_with(".json") { recognized = true; }
        }
        entries.push(EntryPlan { index: i, rel, is_dir, size: entry.size() });
    }
    if !recognized { return Err("Cette archive ne ressemble pas à une sauvegarde complète GameDraw (fichiers attendus absents).".into()); }
    Ok(entries)
}

fn new_sibling(root: &Path, label: &str, create: bool) -> Result<PathBuf, String> {
    let parent = root.parent().ok_or("Dossier de données sans parent")?;
    let basename = root.file_name().and_then(|s| s.to_str()).ok_or("Dossier de données invalide")?;
    let nanos = SystemTime::now().duration_since(UNIX_EPOCH).map_err(|e| e.to_string())?.as_nanos();
    for index in 0..100 {
        let path = parent.join(format!(".{basename}-{label}-{}-{nanos}-{index}", std::process::id()));
        if create {
            match fs::create_dir(&path) {
                Ok(()) => return Ok(path),
                Err(e) if e.kind() == io::ErrorKind::AlreadyExists => continue,
                Err(e) => return Err(format!("Création dossier de préparation : {e}")),
            }
        } else if !path.exists() { return Ok(path); }
    }
    Err("Impossible de réserver un dossier de restauration unique".into())
}

fn validate_json(stage: &Path) -> Result<(), String> {
    for name in ["config.json", "plateformes.json", "session.json", "historique.json", "badges.json"] {
        let path = stage.join(name);
        if path.exists() {
            let f = File::open(&path).map_err(|e| e.to_string())?;
            let value: serde_json::Value = serde_json::from_reader(io::BufReader::new(f))
                .map_err(|e| format!("{name} invalide : {e}"))?;
            let correct = if name == "plateformes.json" { value.is_array() } else { value.is_object() };
            if !correct { return Err(format!("{name} : structure JSON inattendue")); }
        }
    }
    let games = stage.join("jeux");
    if games.exists() {
        for item in fs::read_dir(&games).map_err(|e| e.to_string())? {
            let item = item.map_err(|e| e.to_string())?;
            if item.path().extension().is_some_and(|ext| ext == "json") {
                let value: serde_json::Value = serde_json::from_reader(io::BufReader::new(File::open(item.path()).map_err(|e| e.to_string())?))
                    .map_err(|e| format!("Bibliothèque {:?} invalide : {e}", item.file_name()))?;
                if !value.get("jeux").is_some_and(|v| v.is_array()) {
                    return Err(format!("Bibliothèque {:?} : champ jeux manquant", item.file_name()));
                }
            }
        }
    }
    Ok(())
}

fn pending_marker(root: &Path) -> Result<PathBuf, String> {
    let parent = root.parent().ok_or("Dossier de données sans parent")?;
    let basename = root.file_name().and_then(|s| s.to_str()).ok_or("Nom de données invalide")?;
    Ok(parent.join(format!(".{basename}-restore-pending")))
}

/// Écrit et synchronise le marqueur avec un descripteur OUVERT EN ÉCRITURE.
/// Sur Windows, FlushFileBuffers (sync_all) appelé sur File::open (lecture seule)
/// peut renvoyer ERROR_ACCESS_DENIED (os error 5).
/// create_new interdit de remplacer un marqueur de récupération existant.
fn write_pending_marker(marker: &Path, previous: &Path) -> Result<(), String> {
    let name = previous.file_name().ok_or("Nom de récupération invalide")?;
    let mut file = OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(marker)
        .map_err(|e| format!("Création du marqueur de récupération : {e}"))?;
    let result = file.write_all(name.to_string_lossy().as_bytes())
        .and_then(|_| file.sync_all());
    // Libérer le handle avant toute suppression ou bascule de dossiers Windows.
    drop(file);
    if let Err(e) = result {
        let _ = fs::remove_file(marker);
        return Err(format!("Synchronisation du marqueur de récupération : {e}"));
    }
    Ok(())
}

/// Réserve une copie de repli du dossier actif. La copie n'est pas supprimée
/// après succès et reste réutilisable manuellement. Bascule par renames sur le
/// même volume ; si Windows bloque la bascule, les données actives sont intactes.
pub fn import_backup(root: &Path, source: &Path, password: Option<&str>) -> Result<Option<PathBuf>, String> {
    let parent = root.parent().ok_or("Dossier GameDraw invalide")?;
    fs::create_dir_all(parent).map_err(|e| format!("Accès au dossier de données : {e}"))?;
    let file = File::open(source).map_err(|e| format!("Ouverture du ZIP : {e}"))?;
    let mut archive = zip::ZipArchive::new(file).map_err(|e| format!("Lecture ZIP : {e}"))?;
    let plan = inspect_zip(&mut archive)?;
    let stage = new_sibling(root, "restore-stage", true)?;
    // La fermeture du stage est best-effort si la validation ou la décompression échoue.
    let stage_result: Result<(), String> = (|| {
        let mut written = 0u64;
        for entry_plan in &plan {
            let dest = stage.join(&entry_plan.rel);
            if entry_plan.is_dir {
                fs::create_dir_all(&dest).map_err(|e| format!("Dossier ZIP : {e}"))?;
                continue;
            }
            let mut entry = match password.filter(|p| !p.trim().is_empty()) {
                Some(pw) => archive.by_index_decrypt(entry_plan.index, pw.as_bytes())
                    .map_err(|e| format!("Déchiffrement ZIP impossible (mot de passe ?) : {e}"))?,
                None => archive.by_index(entry_plan.index)
                    .map_err(|e| format!("Lecture ZIP impossible (archive chiffrée sans mot de passe ?) : {e}"))?,
            };
            if let Some(parent) = dest.parent() { fs::create_dir_all(parent).map_err(|e| e.to_string())?; }
            let mut out = File::create(&dest).map_err(|e| format!("Écriture préparation : {e}"))?;
            // Ne jamais accepter plus d'octets que le maximum déclaré ; lecture en flux.
            let allowed = entry_plan.size.min(MAX_FILE_BYTES);
            let count = io::copy(&mut entry.by_ref().take(allowed + 1), &mut out)
                .map_err(|e| format!("ZIP corrompu ou mauvais mot de passe ({:?}) : {e}", entry_plan.rel))?;
            if count != entry_plan.size { return Err(format!("Taille ZIP incohérente : {:?}", entry_plan.rel)); }
            written = written.checked_add(count).ok_or("Données ZIP trop volumineuses")?;
            if written > MAX_TOTAL_BYTES { return Err("Limite ZIP décompressée atteinte".into()); }
            out.sync_all().map_err(|e| format!("Synchronisation fichier extrait : {e}"))?;
        }
        validate_json(&stage)?;
        Ok(())
    })();
    if let Err(e) = stage_result {
        let _ = fs::remove_dir_all(&stage);
        return Err(format!("Restauration annulée avant modification des données : {e}"));
    }

    let rollback = if root.exists() {
        match new_sibling(root, "pre-restore", false) {
            Ok(previous) => Some(previous),
            Err(e) => { let _ = fs::remove_dir_all(&stage); return Err(e); }
        }
    } else { None };
    let marker = match pending_marker(root) {
        Ok(marker) => marker,
        Err(e) => { let _ = fs::remove_dir_all(&stage); return Err(e); }
    };
    if let Some(previous) = &rollback {
        // Marqueur de transaction durable : ne jamais écraser un marqueur existant.
        // Utiliser le MÊME handle inscriptible pour écrire et sync_all (Windows).
        if let Err(e) = write_pending_marker(&marker, previous) {
            let _ = fs::remove_dir_all(&stage);
            return Err(format!("Données actuelles non modifiées : {e}"));
        }
        if let Err(e) = fs::rename(root, previous) {
            let _ = fs::remove_file(&marker);
            let _ = fs::remove_dir_all(&stage);
            return Err(format!("Données actuelles non modifiées : déplacement de protection impossible : {e}"));
        }
    }
    if let Err(e) = fs::rename(&stage, root) {
        let _ = fs::remove_dir_all(&stage);
        if let Some(previous) = &rollback {
            if let Err(recovery_error) = fs::rename(previous, root) {
                return Err(format!("ÉCHEC CRITIQUE : activation impossible ({e}). Données précédentes conservées dans {previous:?}, récupération automatique impossible ({recovery_error}). Ne pas relancer l'application avant récupération manuelle."));
            }
        }
        let _ = fs::remove_file(&marker);
        return Err(format!("Restauration annulée, anciennes données conservées : {e}"));
    }
    if rollback.is_some() { let _ = fs::remove_file(&marker); }

    Ok(rollback)
}

/// Après une interruption entre le déplacement du dossier et la bascule,
/// restaure le dossier conservé si le répertoire de données est manquant.
/// Ne touche JAMAIS à un répertoire GameDraw existant.
pub fn recover_if_interrupted(root: &Path) -> Result<(), String> {
    let marker = pending_marker(root)?;
    if !marker.exists() { return Ok(()); }
    if root.exists() {
        // Si la nouvelle version est déjà en place, le commit a réussi.
        let _ = fs::remove_file(&marker);
        return Ok(());
    }
    let parent = root.parent().ok_or("Dossier de données invalide")?;
    let basename = root.file_name().and_then(|s| s.to_str()).ok_or("Nom du dossier de données invalide")?;
    let name = fs::read_to_string(&marker).map_err(|e| format!("Lecture marqueur : {e}"))?;
    if !name.starts_with(&format!(".{basename}-pre-restore-")) ||
        name.contains('/') || name.contains('\\') || name.contains("..") {
        return Err("Marqueur de récupération illisible ou dangereux".into());
    }
    let previous = parent.join(name);
    if !previous.is_dir() { return Err(format!("Copie de récupération manquante : {previous:?}")); }
    fs::rename(&previous, root).map_err(|e| format!("Récupération interrompue : {e} ; données conservées dans {previous:?}"))?;
    let _ = fs::remove_file(&marker);
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn unsafe_zip_paths() {
        for bad in ["../x", "a/../x", "/absolute", "C:/data", "a\\b", "CON.txt", "x/NUL", "a//b", "a/./b", "a/", "a/b "] {
            if bad == "a/" { assert!(valid_rel(bad).is_ok()); } else { assert!(valid_rel(bad).is_err(), "{bad}"); }
        }
        assert!(valid_rel("jeux/steam.json").is_ok());
    }
    #[test] fn accepts_standard_paths() {
        assert!(valid_rel("images/steam/abc.jpg").is_ok());
        assert!(valid_rel("plateformes.json").is_ok());
    }
}

#[cfg(test)]
mod integration_tests {
    use super::*;
    use std::io::Write;

    struct Fixture { base: PathBuf }
    impl Fixture {
        fn new() -> Self {
            let nonce = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_nanos();
            let base = std::env::temp_dir().join(format!("gamedraw-c5-{}-{nonce}", std::process::id()));
            fs::create_dir(&base).unwrap();
            Self { base }
        }
        fn root(&self) -> PathBuf { self.base.join("GameDrawData") }
        fn zip(&self, files: &[(&str, &str)]) -> PathBuf {
            let zip_path = self.base.join("backup.zip");
            let mut writer = zip::ZipWriter::new(File::create(&zip_path).unwrap());
            let options: zip::write::FileOptions<()> = zip::write::FileOptions::default();
            for (name, content) in files {
                writer.start_file(*name, options.clone()).unwrap();
                writer.write_all(content.as_bytes()).unwrap();
            }
            writer.finish().unwrap();
            zip_path
        }
    }
    impl Drop for Fixture { fn drop(&mut self) { let _ = fs::remove_dir_all(&self.base); } }

    #[test]
    fn old_data_preserved_after_success() {
        let fixture = Fixture::new();
        let root = fixture.root();
        fs::create_dir(&root).unwrap();
        fs::write(root.join("config.json"), r#"{"langue":"fr"}"#).unwrap();
        fs::write(root.join("old-secret.txt"), "OLD").unwrap();
        let zip = fixture.zip(&[("config.json", r#"{"langue":"en"}"#),
            ("jeux/steam.json", r#"{"jeux":[]}"#)]);
        let backup = import_backup(&root, &zip, None).unwrap().unwrap();
        assert!(root.join("jeux/steam.json").exists());
        assert!(!root.join("old-secret.txt").exists());
        assert_eq!(fs::read_to_string(backup.join("old-secret.txt")).unwrap(), "OLD");
    }

    #[test]
    fn writable_marker_is_synced_and_existing_marker_is_not_overwritten() {
        let fixture = Fixture::new();
        let root = fixture.root();
        let marker = pending_marker(&root).unwrap();
        let previous = new_sibling(&root, "pre-restore", false).unwrap();
        write_pending_marker(&marker, &previous).unwrap();
        let expected = previous.file_name().unwrap().to_string_lossy().to_string();
        assert_eq!(fs::read_to_string(&marker).unwrap(), expected);
        assert!(write_pending_marker(&marker, &previous).is_err());
        assert_eq!(fs::read_to_string(&marker).unwrap(), expected);
    }

    #[test]
    fn existing_marker_refuses_restore_without_leaking_a_stage() {
        let fixture = Fixture::new();
        let root = fixture.root();
        fs::create_dir(&root).unwrap();
        fs::write(root.join("config.json"), r#"{"langue":"fr"}"#).unwrap();
        let marker = pending_marker(&root).unwrap();
        fs::write(&marker, "MARQUEUR_EXISTANT").unwrap();
        let zip = fixture.zip(&[("config.json", r#"{"langue":"en"}"#)]);
        assert!(import_backup(&root, &zip, None).is_err());
        assert_eq!(fs::read_to_string(root.join("config.json")).unwrap(), r#"{"langue":"fr"}"#);
        assert_eq!(fs::read_to_string(&marker).unwrap(), "MARQUEUR_EXISTANT");
        assert!(!fs::read_dir(&fixture.base).unwrap().any(|entry| {
            entry.unwrap().file_name().to_string_lossy().contains("restore-stage")
        }));
    }

    #[test]
    fn bad_json_cannot_replace_old_data() {
        let fixture = Fixture::new();
        let root = fixture.root();
        fs::create_dir(&root).unwrap();
        fs::write(root.join("unchanged.txt"), "SAFE").unwrap();
        let zip = fixture.zip(&[("config.json", "garbage")]);
        assert!(import_backup(&root, &zip, None).is_err());
        assert_eq!(fs::read_to_string(root.join("unchanged.txt")).unwrap(), "SAFE");
    }

    #[test]
    fn rejects_traversal_and_duplicates_without_touching_data() {
        let fixture = Fixture::new();
        let root = fixture.root();
        fs::create_dir(&root).unwrap();
        fs::write(root.join("safe.txt"), "SAFE").unwrap();
        let zip = fixture.zip(&[("config.json", "{}"), ("../evil", "oops")]);
        assert!(import_backup(&root, &zip, None).is_err());
        assert_eq!(fs::read_to_string(root.join("safe.txt")).unwrap(), "SAFE");
        let zip2 = fixture.zip(&[("config.json", "{}"), ("CONFIG.JSON", "{}")]);
        assert!(import_backup(&root, &zip2, None).is_err());
        assert_eq!(fs::read_to_string(root.join("safe.txt")).unwrap(), "SAFE");
    }

    #[test]
    fn wrong_password_never_replaces_current_data() {
        let fixture = Fixture::new();
        let root = fixture.root();
        fs::create_dir(&root).unwrap();
        fs::write(root.join("unchanged.txt"), "SAFE").unwrap();
        let zip_path = fixture.base.join("backup.zip");
        let mut writer = zip::ZipWriter::new(File::create(&zip_path).unwrap());
        let options: zip::write::FileOptions<()> = zip::write::FileOptions::default()
            .compression_method(zip::CompressionMethod::Deflated)
            .with_aes_encryption(zip::AesMode::Aes256, "correct");
        writer.start_file("config.json", options).unwrap();
        writer.write_all(br#"{"langue":"fr"}"#).unwrap();
        writer.finish().unwrap();
        assert!(import_backup(&root, &zip_path, Some("incorrect")).is_err());
        assert_eq!(fs::read_to_string(root.join("unchanged.txt")).unwrap(), "SAFE");
        // Une archive chiffrée sans mot de passe ne doit rien modifier non plus.
        assert!(import_backup(&root, &zip_path, None).is_err());
        assert_eq!(fs::read_to_string(root.join("unchanged.txt")).unwrap(), "SAFE");
    }

    #[test]
    fn recovers_interrupted_directory_swap() {
        let fixture = Fixture::new();
        let root = fixture.root();
        fs::create_dir(&root).unwrap();
        fs::write(root.join("config.json"), "{}").unwrap();
        let backup = new_sibling(&root, "pre-restore", false).unwrap();
        fs::write(pending_marker(&root).unwrap(), backup.file_name().unwrap().to_string_lossy().as_bytes()).unwrap();
        fs::rename(&root, &backup).unwrap();
        recover_if_interrupted(&root).unwrap();
        assert!(root.join("config.json").exists());
        assert!(!backup.exists());
    }
}
