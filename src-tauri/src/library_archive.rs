//! STAB-C6 : import des bibliothèques ZIP par plateforme, distinct des backups C5.
//! Inspection complète et décompression bornée avant de toucher aux jaquettes actives.
use crate::cover_utils;
use crate::data::{self, GameLibrary};
use std::collections::{HashMap, HashSet};
use std::fs::{self, File};
use std::io::{Read, Seek};
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

const MAX_ZIP_BYTES: u64 = 640 * 1024 * 1024;
const MAX_ENTRIES: usize = 20_002;
const MAX_GAMES: usize = 20_000;
const MAX_JSON_BYTES: u64 = 16 * 1024 * 1024;
const MAX_TOTAL_BYTES: u64 = 512 * 1024 * 1024;

fn cover_key(value: &str) -> Result<String, String> {
    // Les exports GameDraw utilisent exclusivement covers/<identifiant>.<extension>.
    // Ne jamais interpréter un chemin contenu dans games.json comme un chemin disque.
    if value.is_empty() || value.len() > 220 || value.contains('\\') || value.contains('\0') {
        return Err("Chemin de jaquette ZIP invalide".into());
    }
    let Some(file) = value.strip_prefix("covers/") else {
        return Err("Une jaquette du ZIP doit se trouver dans covers/".into());
    };
    let Some((stem, ext)) = file.rsplit_once('.') else {
        return Err("Nom de jaquette ZIP sans extension".into());
    };
    cover_utils::safe_id(stem)?;
    if !["jpg", "jpeg", "png", "webp", "gif"].contains(&ext.to_ascii_lowercase().as_str()) {
        return Err("Extension de jaquette ZIP non prise en charge".into());
    }
    Ok(value.to_ascii_lowercase())
}

/// Retourne l'index de l'unique games.json et les index des couvertures validées.
/// Aucun nom externe n'est joint à un chemin du système de fichiers.
fn inspect_zip<R: Read + Seek>(archive: &mut zip::ZipArchive<R>) -> Result<(usize, HashMap<String, usize>), String> {
    if archive.len() == 0 || archive.len() > MAX_ENTRIES {
        return Err("ZIP bibliothèque vide ou trop de fichiers".into());
    }
    let mut games_idx = None;
    let mut covers = HashMap::new();
    let mut seen = HashSet::new();
    let mut total = 0u64;
    for idx in 0..archive.len() {
        let entry = archive.by_index_raw(idx).map_err(|e| format!("Entrée ZIP #{idx} illisible : {e}"))?;
        if entry.enclosed_name().is_none() || entry.name().starts_with('/') || entry.name().contains('\\') {
            return Err(format!("Chemin ZIP dangereux : {}", entry.name()));
        }
        if entry.unix_mode().is_some_and(|mode| {
            let kind = mode & 0o170000;
            kind != 0 && kind != 0o040000 && kind != 0o100000
        }) {
            return Err(format!("Lien ou fichier spécial interdit : {}", entry.name()));
        }
        // Ancien format exporté : dossier covers/ explicite facultatif.
        if entry.is_dir() && entry.name() == "covers/" { continue; }
        if entry.is_dir() { return Err(format!("Dossier ZIP inattendu : {}", entry.name())); }
        let name = entry.name();
        let key = if name == "games.json" {
            "games.json".to_string()
        } else {
            cover_key(name)?
        };
        if !seen.insert(key.clone()) { return Err(format!("Doublon ou collision de casse dans le ZIP : {name}")); }
        let limit = if key == "games.json" { MAX_JSON_BYTES } else { cover_utils::MAX_COVER_BYTES as u64 };
        if entry.size() > limit { return Err(format!("Fichier ZIP trop volumineux : {name}")); }
        total = total.checked_add(entry.size()).ok_or("Tailles ZIP incohérentes")?;
        if total > MAX_TOTAL_BYTES { return Err("ZIP décompressé trop volumineux (512 Mio max)".into()); }
        if key == "games.json" { games_idx = Some(idx); }
        else { covers.insert(key, idx); }
    }
    let idx = games_idx.ok_or("games.json absent du ZIP GameDraw")?;
    Ok((idx, covers))
}

fn read_bounded<R: Read>(reader: &mut R, expected: u64, max: u64, label: &str) -> Result<Vec<u8>, String> {
    if expected > max { return Err(format!("{label} dépasse la limite autorisée")); }
    let mut output = Vec::with_capacity(expected.min(1024 * 1024) as usize);
    let count = reader.take(expected + 1).read_to_end(&mut output)
        .map_err(|e| format!("Lecture ZIP défectueuse ({label}) : {e}"))? as u64;
    if count != expected { return Err(format!("Taille réelle incohérente pour {label}")); }
    Ok(output)
}

fn create_stage(images: &Path) -> Result<PathBuf, String> {
    fs::create_dir_all(images).map_err(|e| format!("Dossier images inaccessible : {e}"))?;
    let time = SystemTime::now().duration_since(UNIX_EPOCH).map_err(|e| e.to_string())?.as_nanos();
    for i in 0..100 {
        let candidate = images.join(format!(".import-stage-{}-{time}-{i}", std::process::id()));
        match fs::create_dir(&candidate) {
            Ok(()) => return Ok(candidate),
            Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => continue,
            Err(e) => return Err(format!("Préparation de l'import ZIP : {e}")),
        }
    }
    Err("Impossible de créer un dossier d'import unique".into())
}

pub fn import_library(root: &Path, platform_id: &str, source: &Path) -> Result<GameLibrary, String> {
    cover_utils::safe_id(platform_id)?;
    let size = fs::metadata(source).map_err(|e| format!("Archive inaccessible : {e}"))?.len();
    if size > MAX_ZIP_BYTES { return Err("Archive ZIP trop volumineuse (640 Mio max)".into()); }
    let mut archive = zip::ZipArchive::new(File::open(source).map_err(|e| format!("Ouverture ZIP : {e}"))?)
        .map_err(|e| format!("Archive ZIP illisible : {e}"))?;
    let (games_idx, covers) = inspect_zip(&mut archive)?;
    let mut entry = archive.by_index(games_idx).map_err(|e| format!("games.json inaccessible : {e}"))?;
    let expected_json_size = entry.size();
    let json = read_bounded(&mut entry, expected_json_size, MAX_JSON_BYTES, "games.json")?;
    drop(entry);
    let mut imported: GameLibrary = serde_json::from_slice(&json)
        .map_err(|e| format!("games.json invalide : {e}"))?;
    if imported.jeux.len() > MAX_GAMES { return Err("Trop de jeux à importer (20 000 max)".into()); }

    // Préflight des références avant toute création de fichier.
    let mut refs = Vec::with_capacity(imported.jeux.len());
    for game in &imported.jeux {
        let reference = match game.cover.as_deref() {
            Some(path) => {
                let key = cover_key(path)?;
                let index = covers.get(&key).ok_or_else(|| format!("Jaquette manquante dans le ZIP : {key}"))?;
                Some(*index)
            }
            None => None,
        };
        refs.push(reference);
    }
    // Les doublons existants ou internes n'ont pas besoin de jaquettes écrites
    // sur disque (même règle de dédoublonnage par nom que fusionnerJeux côté JS).
    let existing: GameLibrary = data::read_json_or_default(&data::games_path(root, platform_id))?;
    let mut names: HashSet<String> = existing.jeux.into_iter().map(|j| j.nom.trim().to_lowercase()).collect();
    let mut needed = Vec::new();
    for (i, game) in imported.jeux.iter().enumerate() {
        let key = game.nom.trim().to_lowercase();
        if !key.is_empty() && names.insert(key) && refs[i].is_some() { needed.push(i); }
    }
    let images = data::images_dir(root, platform_id);
    let stage = create_stage(&images)?;
    let stamp = SystemTime::now().duration_since(UNIX_EPOCH).map_err(|e| e.to_string())?.as_nanos();
    let prefix = format!("{stamp:x}-{}", std::process::id());
    let mut transfers: Vec<(PathBuf, PathBuf, usize)> = Vec::new();
    let prepared: Result<(), String> = (|| {
        for i in needed {
            let idx = refs[i].ok_or("Référence interne absente")?;
            let mut image = archive.by_index(idx).map_err(|e| format!("Jaquette ZIP corrompue : {e}"))?;
            let expected_image_size = image.size();
            let bytes = read_bounded(&mut image, expected_image_size, cover_utils::MAX_COVER_BYTES as u64, "jaquette")?;
            let (extension, _) = cover_utils::format_image(&bytes)?;
            let file = format!("{prefix}-{i}.{extension}");
            let staged = stage.join(&file);
            let target = images.join(&file);
            fs::write(&staged, &bytes).map_err(|e| format!("Préparation jaquette : {e}"))?;
            imported.jeux[i].cover = Some(target.to_string_lossy().into_owned());
            transfers.push((staged, target, i));
        }
        Ok(())
    })();
    if let Err(err) = prepared {
        let _ = fs::remove_dir_all(&stage);
        return Err(format!("Import annulé avant toute modification des jaquettes : {err}"));
    }
    let mut moved = Vec::new();
    for (staged, target, _) in &transfers {
        if target.exists() {
            for path in moved { let _ = fs::remove_file(path); }
            let _ = fs::remove_dir_all(&stage);
            return Err("Conflit de nom pour une jaquette, import annulé".into());
        }
        if let Err(e) = fs::rename(staged, target) {
            for path in moved { let _ = fs::remove_file(path); }
            let _ = fs::remove_dir_all(&stage);
            return Err(format!("Import annulé, jaquettes restaurées : {e}"));
        }
        moved.push(target.clone());
    }
    let _ = fs::remove_dir_all(&stage);
    // Les jeux en doublon ont leurs couvertures ignorées afin de ne pas pointer
    // sur des chemins d'archives inexistants en cas de fusion.
    let copied: HashSet<usize> = transfers.iter().map(|(_, _, i)| *i).collect();
    for (i, game) in imported.jeux.iter_mut().enumerate() {
        if refs[i].is_some() && !copied.contains(&i) { game.cover = None; }
        game.id = format!("{prefix}-{i}");
    }
    imported.platform_id = platform_id.to_owned();
    Ok(imported)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    struct Fixture { root: PathBuf }
    impl Fixture {
        fn new() -> Self {
            let id = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_nanos();
            let root = std::env::temp_dir().join(format!("gamedraw-c6-{}-{id}", std::process::id()));
            fs::create_dir_all(&root).unwrap();
            Self { root }
        }
        fn zip(&self, items: &[(&str, &[u8])]) -> PathBuf {
            let path = self.root.join("sample.zip");
            let mut out = zip::ZipWriter::new(File::create(&path).unwrap());
            let options: zip::write::FileOptions<()> = zip::write::FileOptions::default();
            for (name, contents) in items { out.start_file(*name, options.clone()).unwrap(); out.write_all(contents).unwrap(); }
            out.finish().unwrap(); path
        }
    }
    impl Drop for Fixture { fn drop(&mut self) { let _ = fs::remove_dir_all(&self.root); } }
    fn json(cover: &str) -> Vec<u8> {
        format!(r#"{{"schemaVersion":1,"platformId":"pc","jeux":[{{"id":"abc","nom":"Jeu test","dejaFait":false,"cover":{cover}}}]}}"#).into_bytes()
    }
    fn fake_png() -> Vec<u8> { let mut b=b"\x89PNG\r\n\x1a\n".to_vec(); b.extend_from_slice(&[1;40]); b }
    #[test] fn rejects_traversal_before_writing_cover() {
        let f=Fixture::new(); let body=json(r#""../outside.png""#); let zip=f.zip(&[("games.json", &body)]);
        assert!(import_library(&f.root, "pc", &zip).is_err());
        assert!(!data::images_dir(&f.root, "pc").exists());
    }
    #[test] fn rejects_truncated_or_invalid_image_without_partial_import() {
        let f=Fixture::new(); let body=json(r#""covers/abc.jpg""#); let html=b"<html>bad</html>";
        let zip=f.zip(&[("games.json", &body), ("covers/abc.jpg", html)]);
        assert!(import_library(&f.root, "pc", &zip).is_err());
        let dir=data::images_dir(&f.root, "pc");
        assert_eq!(fs::read_dir(dir).unwrap().count(),0);
    }
    #[test] fn rejects_case_collisions_and_unknown_files() {
        let f=Fixture::new(); let body=json("null");
        let image=fake_png();
        let zip=f.zip(&[("games.json", &body), ("covers/ABC.PNG", &image), ("covers/abc.png", &image)]);
        assert!(import_library(&f.root, "pc", &zip).is_err());
        let zip=f.zip(&[("games.json", &body), ("../outside.txt", b"oops")]);
        assert!(import_library(&f.root, "pc", &zip).is_err());
    }
    #[test] fn imports_safe_image_using_signature_not_untrusted_extension() {
        let f=Fixture::new(); let body=json(r#""covers/abc.jpg""#); let image=fake_png();
        let zip=f.zip(&[("games.json", &body), ("covers/abc.jpg", &image)]);
        let lib=import_library(&f.root,"pc",&zip).unwrap();
        assert_eq!(lib.jeux.len(),1);
        let path=PathBuf::from(lib.jeux[0].cover.as_ref().unwrap());
        assert_eq!(path.extension().unwrap(), "png");
        assert_eq!(fs::read(&path).unwrap(), image);
    }
    #[test] fn second_bad_cover_cannot_leave_a_first_cover_behind() {
        let f=Fixture::new();
        let body = br#"{"schemaVersion":1,"platformId":"pc","jeux":[{"id":"a","nom":"A","dejaFait":false,"cover":"covers/a.png"},{"id":"b","nom":"B","dejaFait":false,"cover":"covers/b.png"}]}"#;
        let good=fake_png(); let bad=b"<html>error 404</html>";
        let zip=f.zip(&[("games.json", body), ("covers/a.png", &good), ("covers/b.png",bad)]);
        assert!(import_library(&f.root,"pc",&zip).is_err());
        let images=data::images_dir(&f.root,"pc");
        assert_eq!(fs::read_dir(images).unwrap().count(),0, "aucune jaquette orpheline");
    }
    #[test] fn duplicate_existing_name_does_not_write_a_cover() {
        let f=Fixture::new();
        let original: GameLibrary=serde_json::from_slice(&json("null")).unwrap();
        data::write_json(&data::games_path(&f.root,"pc"),&original).unwrap();
        let archive_json=json(r#""covers/abc.png""#);
        let image=fake_png();
        let zip=f.zip(&[("games.json", &archive_json), ("covers/abc.png", &image)]);
        let incoming=import_library(&f.root,"pc",&zip).unwrap();
        assert!(incoming.jeux[0].cover.is_none());
        assert_eq!(fs::read_dir(data::images_dir(&f.root,"pc")).unwrap().count(),0);
    }
    #[test] fn rejects_oversized_declared_games_json() {
        let f=Fixture::new(); let long=vec![b'x'; MAX_JSON_BYTES as usize+1];
        let zip=f.zip(&[("games.json", &long)]);
        assert!(import_library(&f.root, "pc", &zip).is_err());
    }
}
