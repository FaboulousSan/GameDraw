//! Validation légère des jaquettes. Aucune réponse HTML/API n'est enregistrée comme image.
use std::path::Path;
pub const MAX_COVER_BYTES: usize = 15 * 1024 * 1024;

pub fn format_image(bytes: &[u8]) -> Result<(&'static str, &'static str), String> {
    if bytes.len() > MAX_COVER_BYTES { return Err("Image trop volumineuse (limite 15 Mio).".into()); }
    if bytes.len() < 16 { return Err("Image vide, tronquée ou illisible.".into()); }
    if bytes.starts_with(&[0x89, b'P', b'N', b'G', 13, 10, 26, 10]) {
        return Ok(("png", "image/png"));
    }
    if bytes.starts_with(&[0xFF, 0xD8, 0xFF]) { return Ok(("jpg", "image/jpeg")); }
    if bytes.starts_with(b"RIFF") && bytes.get(8..12) == Some(&b"WEBP"[..]) {
        return Ok(("webp", "image/webp"));
    }
    if bytes.starts_with(b"GIF87a") || bytes.starts_with(b"GIF89a") {
        return Ok(("gif", "image/gif"));
    }
    Err("Le fichier reçu n'est pas une image JPEG, PNG, WEBP ou GIF valide (page HTML/API refusée).".into())
}

pub fn safe_id(id: &str) -> Result<&str, String> {
    if id.is_empty() || id.len() > 128 || !id.bytes().all(|c| c.is_ascii_alphanumeric() || c == b'-' || c == b'_') {
        return Err("Identifiant de jeu/plateforme invalide.".into());
    }
    Ok(id)
}

pub fn store_image(images: &Path, game_id: &str, bytes: &[u8]) -> Result<String, String> {
    let (ext, _) = format_image(bytes)?;
    safe_id(game_id)?;
    std::fs::create_dir_all(images).map_err(|e| format!("Dossier images inaccessible: {e}"))?;
    // Nouveau nom à chaque sélection : l'URL change et invalide le cache WebView2.
    let stamp = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH)
        .map_err(|e| e.to_string())?.as_nanos();
    let target = images.join(format!("{game_id}-{stamp}.{ext}"));
    std::fs::write(&target, bytes).map_err(|e| format!("Impossible d'enregistrer la jaquette: {e}"))?;
    Ok(target.to_string_lossy().into_owned())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn refuse_html_et_donnees_vides() {
        assert!(format_image(b"<html>Unauthorized 401</html>").is_err());
        assert!(format_image(&[]).is_err());
    }
    #[test] fn reconnait_formats_par_signature_sans_se_fier_url() {
        let mut png=b"\x89PNG\r\n\x1a\n".to_vec(); png.extend_from_slice(&[0;32]);
        assert_eq!(format_image(&png).unwrap().0,"png");
        let mut webp=b"RIFF0000WEBP".to_vec(); webp.extend_from_slice(&[0;20]);
        assert_eq!(format_image(&webp).unwrap().0,"webp");
    }
    #[test] fn refuse_traversee_chemin() { assert!(safe_id("../private").is_err()); }
}
