//! Recherche publique d'assets de bibliothèque Steam (sans clé SteamGridDB).
//! Les URL finales sont toujours construites sur le CDN officiel Steam, et les
//! chemins renvoyés par un service distant subissent un contrôle strict.
use serde_json::Value;

/// Résout au plus deux jaquettes portrait natives, de la meilleure à la normale.
/// Ne jamais substituer `header` (paysage) lorsque `library_capsule` existe.
pub fn portrait_urls(app_id: i64, payload: &Value) -> Vec<String> {
    if app_id <= 0 { return Vec::new(); }
    let Some(items) = payload.get("response")
        .and_then(|v| v.get("store_items")).and_then(Value::as_array) else { return Vec::new() };
    let Some(assets) = items.iter()
        .find(|item| item.get("appid").and_then(Value::as_i64) == Some(app_id))
        .and_then(|item| item.get("assets")) else { return Vec::new() };
    let Some(format) = assets.get("asset_url_format").and_then(Value::as_str) else { return Vec::new() };
    let prefix = format!("steam/apps/{app_id}/");
    if !format.starts_with(&prefix) || format.matches("${FILENAME}").count() != 1 { return Vec::new(); }
    // Steam peut ajouter ?t= suivi d'un horodatage au format d'URL.
    let (template, suffix) = match format.split_once('?') {
        Some((f, q)) if q.starts_with("t=") && q[2..].len() <= 20
            && !q[2..].is_empty() && q[2..].bytes().all(|b| b.is_ascii_digit()) => (f, format!("?{q}")),
        Some(_) => return Vec::new(),
        None => (format, String::new()),
    };
    // Le modèle doit remplacer le suffixe exact, sans préfixes hostiles.
    if template != format!("{prefix}${{FILENAME}}") { return Vec::new(); }
    ["library_capsule_2x", "library_capsule"].iter().filter_map(|key| {
        let filename = assets.get(*key)?.as_str()?;
        if filename.is_empty() || filename.len() > 256 || filename.starts_with('/') { return None; }
        let valid = filename.split('/').all(|seg| !seg.is_empty() && seg != "." && seg != ".."
            && seg.bytes().all(|b| b.is_ascii_alphanumeric() || matches!(b, b'_' | b'-' | b'.')));
        if !valid { return None; }
        Some(format!("https://shared.steamstatic.com/store_item_assets/{prefix}{filename}{suffix}"))
    }).collect()
}

pub fn legacy_portrait_urls(app_id: i64) -> Vec<String> {
    if app_id <= 0 { return Vec::new(); }
    let base = format!("https://shared.steamstatic.com/store_item_assets/steam/apps/{app_id}");
    ["library_600x900_2x.jpg", "library_600x900.jpg", "library_600x900.png"]
        .iter().map(|name| format!("{base}/{name}")).collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    #[test]
    fn preference_portrait_hd_avec_chemin_hache() {
        let response = json!({"response": {"store_items":[{"appid":620,"assets":{
            "asset_url_format":"steam/apps/620/${FILENAME}?t=12345",
            "header":"hash/header.jpg",
            "library_capsule":"hash/library_600x900.jpg",
            "library_capsule_2x":"hash/library_600x900_2x.jpg"}}]}});
        let urls = portrait_urls(620, &response);
        assert_eq!(urls.len(), 2);
        assert_eq!(urls[0], "https://shared.steamstatic.com/store_item_assets/steam/apps/620/hash/library_600x900_2x.jpg?t=12345");
        assert!(!urls.iter().any(|s| s.contains("header.jpg")));
    }
    #[test]
    fn url_hostile_interdite_et_erreur_non_fatale() {
        let payload = json!({"response":{"store_items":[{"appid":123,"assets":{
            "asset_url_format":"steam/apps/123/${FILENAME}",
            "library_capsule_2x":"../../secret", "library_capsule":"https://evil.test/image.jpg"
        }}]}});
        assert!(portrait_urls(123, &payload).is_empty());
        assert!(portrait_urls(-1, &payload).is_empty());
        assert_eq!(legacy_portrait_urls(123).len(), 3);
    }
    #[test]
    fn refuse_mauvais_app_id_et_doubles_placeholders() {
        let payload = json!({"response":{"store_items":[{"appid":12,"assets":{
            "asset_url_format":"steam/apps/12/${FILENAME}/${FILENAME}",
            "library_capsule":"art.jpg"
        }}]}});
        assert!(portrait_urls(13, &payload).is_empty());
        assert!(portrait_urls(12, &payload).is_empty());
    }
}
