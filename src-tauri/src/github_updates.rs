//! GameDraw 1.0.5 : GitHub Releases public (sans token ni exécution d'exécutable).
//! La future installation automatique exige les signatures Ed25519 du plugin Tauri.
use serde::{Deserialize, Serialize};
use std::io::Write;
use std::path::PathBuf;
use std::time::Duration;
use tauri::{AppHandle, Emitter, Manager};

const MAX_DOWNLOAD: u64 = 600 * 1024 * 1024;

#[derive(Debug, Deserialize)]
struct ReleaseApi {
    tag_name: String,
    name: Option<String>,
    body: Option<String>,
    html_url: String,
    published_at: Option<String>,
    draft: bool,
    prerelease: bool,
    assets: Vec<AssetApi>,
}
#[derive(Debug, Deserialize)]
struct AssetApi {
    name: String,
    size: u64,
    browser_download_url: String,
}
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct GithubReleaseAsset { name: String, size: u64 }
#[derive(Serialize, Clone)]
struct DownloadProgress { received: u64, total: u64 }
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct GithubRelease {
    version: String,
    tag: String,
    title: String,
    notes: String,
    html_url: String,
    published_at: Option<String>,
    assets: Vec<GithubReleaseAsset>,
}

fn repo_parts(raw: &str) -> Result<(&str, &str), String> {
    let (owner, repo) = raw.trim().split_once('/').ok_or("Indiquer le dépôt comme propriétaire/nom (ex. organisation/gamedraw).")?;
    fn valid(s: &str) -> bool {
        !s.is_empty() && s.len() <= 100 && !s.starts_with('.') && !s.ends_with('.')
            && s.bytes().all(|c| c.is_ascii_alphanumeric() || c == b'-' || c == b'_' || c == b'.')
    }
    if !valid(owner) || !valid(repo) { return Err("Nom de dépôt GitHub incorrect (format propriétaire/nom).".into()); }
    Ok((owner, repo))
}

#[derive(Debug, Clone, Eq, PartialEq)]
struct Version { numbers: [u64; 3], prerelease: Option<Vec<String>> }
fn parse_version(raw: &str) -> Option<Version> {
    let raw = raw.trim().trim_start_matches('v');
    let (main, pre) = raw.split_once('-').map(|(a,b)|(a,Some(b))).unwrap_or((raw,None));
    let nums: Vec<_> = main.split('.').collect();
    if nums.len() != 3 { return None; }
    let numbers = [nums[0].parse().ok()?, nums[1].parse().ok()?, nums[2].parse().ok()?];
    let prerelease = match pre {
        None => None,
        Some(p) if !p.is_empty() && p.split('.').all(|x| !x.is_empty() && x.bytes().all(|c| c.is_ascii_alphanumeric() || c==b'-')) => Some(p.split('.').map(str::to_owned).collect()),
        _ => return None,
    };
    Some(Version { numbers, prerelease })
}
fn cmp_pre(a: &[String], b: &[String]) -> std::cmp::Ordering {
    use std::cmp::Ordering;
    for (x,y) in a.iter().zip(b) {
        let result = match (x.parse::<u64>(),y.parse::<u64>()) {
            (Ok(i),Ok(j))=>i.cmp(&j), (Ok(_),Err(_))=>Ordering::Less,
            (Err(_),Ok(_))=>Ordering::Greater, (Err(_),Err(_))=>x.cmp(y),
        };
        if result != Ordering::Equal {return result;}
    }
    a.len().cmp(&b.len())
}
impl Ord for Version {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        self.numbers.cmp(&other.numbers).then_with(|| match (&self.prerelease,&other.prerelease) {
            (None,None) => std::cmp::Ordering::Equal,
            (None,Some(_)) => std::cmp::Ordering::Greater,
            (Some(_),None) => std::cmp::Ordering::Less,
            (Some(a),Some(b)) => cmp_pre(a,b),
        })
    }
}
impl PartialOrd for Version { fn partial_cmp(&self, other:&Self) -> Option<std::cmp::Ordering> {Some(self.cmp(other))} }

fn acceptable_asset(name: &str) -> bool {
    // Pas de script, ZIP source, .bat, URL externe ni fichier avec chemins.
    let lower=name.to_ascii_lowercase();
    name.len() <= 160 && !name.contains('/') && !name.contains('\\') && !name.contains("..")
        && name.bytes().all(|x| x.is_ascii_alphanumeric() || b"._-()+ ".contains(&x))
        && lower.starts_with("gamedraw") && (lower.ends_with(".exe") || lower.ends_with(".msi"))
}
fn client() -> Result<reqwest::Client, String> {
    reqwest::Client::builder().https_only(true)
        .user_agent("GameDraw/1.0.6 (+GitHub Releases updater)")
        .timeout(Duration::from_secs(90))
        .build().map_err(|e| format!("Client GitHub : {e}"))
}
async fn fetch_releases(repository: &str) -> Result<Vec<ReleaseApi>, String> {
    let (owner, name) = repo_parts(repository)?;
    let url = format!("https://api.github.com/repos/{owner}/{name}/releases?per_page=30");
    let response=client()?.get(&url).send().await.map_err(|e| format!("Connexion GitHub : {e}"))?;
    match response.status().as_u16() {
        404 => return Err("Dépôt introuvable ou privé. Indiquer un dépôt GitHub public.".into()),
        403 | 429 => return Err("GitHub limite les appels. Réessaie plus tard.".into()),
        status if !(200..300).contains(&status) => return Err(format!("GitHub Releases : HTTP {status}")),
        _ => {}
    }
    response.json::<Vec<ReleaseApi>>().await.map_err(|e| format!("Réponse GitHub illisible : {e}"))
}

#[tauri::command]
pub async fn github_release_check(repository: String, channel: String, current_version: String) -> Result<Option<GithubRelease>, String> {
    let current=parse_version(&current_version).ok_or("Version GameDraw locale invalide.")?;
    if channel != "stable" && channel != "beta" { return Err("Canal invalide.".into()); }
    let releases=fetch_releases(&repository).await?;
    let selected=releases.into_iter().filter(|r| !r.draft && (channel == "beta" || !r.prerelease))
        .filter_map(|r| parse_version(&r.tag_name).map(|v|(v,r)))
        .filter(|(v,r)| v > &current && (channel == "beta" || (v.prerelease.is_none() && !r.prerelease)))
        .max_by(|a,b|a.0.cmp(&b.0));
    let result=selected.map(|(_,r)| GithubRelease {
        version: r.tag_name.trim_start_matches('v').to_owned(), tag: r.tag_name.clone(),
        title: r.name.unwrap_or_else(|| r.tag_name.clone()),
        notes: r.body.unwrap_or_default().chars().take(6000).collect(),
        html_url: r.html_url,
        published_at: r.published_at,
        assets: r.assets.into_iter().filter(|a| acceptable_asset(&a.name) && a.size <= MAX_DOWNLOAD)
            .map(|a|GithubReleaseAsset{name:a.name,size:a.size}).collect(),
    });
    Ok(result)
}

#[tauri::command]
pub async fn github_release_download(app: AppHandle, repository: String, tag: String, asset_name: String) -> Result<String, String> {
    let _=repo_parts(&repository)?;
    if parse_version(&tag).is_none() || tag.contains('/') { return Err("Version GitHub incorrecte.".into()); }
    if !acceptable_asset(&asset_name) {return Err("Seuls les installateurs officiels GameDraw .exe/.msi sont téléchargeables.".into());}
    // Revalider le nom + l'URL depuis l'API à chaque téléchargement : le frontend
    // ne fournit jamais une URL arbitraire à reqwest.
    let releases=fetch_releases(&repository).await?;
    let release=releases.into_iter().find(|r| !r.draft && r.tag_name == tag).ok_or("Release GitHub introuvable.")?;
    let asset=release.assets.into_iter().find(|a| a.name==asset_name && a.size>0 && a.size<=MAX_DOWNLOAD)
        .ok_or("Installateur non disponible ou trop volumineux.")?;
    let (owner,repo)=repo_parts(&repository)?;
    let expected_prefix=format!("https://github.com/{owner}/{repo}/releases/download/");
    if !asset.browser_download_url.starts_with(&expected_prefix) {
        return Err("L'URL de téléchargement ne provient pas du dépôt configuré.".into());
    }
    let path=app.path().download_dir().map_err(|e|format!("Dossier Téléchargements : {e}"))?;
    std::fs::create_dir_all(&path).map_err(|e|format!("Accès au dossier Téléchargements : {e}"))?;
    download_to_path(&app,&path,&asset).await
}

async fn download_to_path(app:&AppHandle,directory:&std::path::Path,asset:&AssetApi)->Result<String,String> {
    let client=client()?;
    let mut resp=client.get(&asset.browser_download_url).timeout(Duration::from_secs(300))
        .send().await.map_err(|e|format!("Téléchargement GitHub : {e}"))?;
    if !resp.status().is_success() {return Err(format!("Téléchargement refusé : HTTP {}",resp.status()));}
    if resp.content_length().is_some_and(|size| size>MAX_DOWNLOAD) { return Err("Fichier trop volumineux.".into()); }
    // Chemin nouveau : ne jamais écraser un fichier utilisateur existant.
    let mut destination=None;
    for index in 0..50 {
        let filename=if index==0 {asset.name.clone()} else {
            let dot=asset.name.rfind('.').unwrap_or(asset.name.len());
            format!("{} ({index}){}",&asset.name[..dot], &asset.name[dot..])
        };
        let candidate=directory.join(filename);
        if !candidate.exists() && !PathBuf::from(format!("{}.part", candidate.display())).exists() {destination=Some(candidate);break;}
    }
    let final_path:PathBuf=destination.ok_or("Trop de fichiers du même nom dans Téléchargements.")?;
    let part_path=PathBuf::from(format!("{}.part",final_path.display()));
    let mut file=std::fs::OpenOptions::new().write(true).create_new(true).open(&part_path)
        .map_err(|e|format!("Impossible de préparer le téléchargement : {e}"))?;
    let result:Result<(),String>=async {
        let mut bytes_total=0u64;
        let mut last_reported=0u64;
        let _=app.emit("gamedraw:update-download-progress",DownloadProgress{received:0,total:asset.size});
        while let Some(chunk)=resp.chunk().await.map_err(|e|format!("Lecture réseau interrompue : {e}"))? {
            bytes_total+=chunk.len() as u64;
            if bytes_total>MAX_DOWNLOAD {return Err("Fichier trop volumineux.".into());}
            file.write_all(&chunk).map_err(|e|format!("Écriture disque : {e}"))?;
            if bytes_total.saturating_sub(last_reported)>=512*1024 || bytes_total==asset.size {
                let _=app.emit("gamedraw:update-download-progress",DownloadProgress{received:bytes_total,total:asset.size});
                last_reported=bytes_total;
            }
        }
        file.flush().map_err(|e|format!("Finalisation disque : {e}"))?;
        if bytes_total==0 || bytes_total!=asset.size {
            return Err(format!("Taille inattendue : {bytes_total} octets au lieu de {}.",asset.size));
        }
        Ok(())
    }.await;
    drop(file);
    if let Err(err)=result {let _=std::fs::remove_file(&part_path);return Err(err);}
    let _=app.emit("gamedraw:update-download-progress",DownloadProgress{received:asset.size,total:asset.size});
    std::fs::rename(&part_path,&final_path).map_err(|e|{let _=std::fs::remove_file(&part_path);format!("Finalisation du téléchargement : {e}")})?;
    Ok(final_path.to_string_lossy().into_owned())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn repository_validation(){assert!(repo_parts("owner/Repo").is_ok());for bad in ["","../bad","user/repo/other","user/x%2fmal","ftp://no"]{assert!(repo_parts(bad).is_err());}}
    #[test] fn versions(){assert!(parse_version("v1.0.6").unwrap()>parse_version("1.0.5").unwrap());assert!(parse_version("1.0.5").unwrap()>parse_version("1.0.5-beta.2").unwrap());assert!(parse_version("1.0.5-beta.11").unwrap()>parse_version("1.0.5-beta.2").unwrap());}
    #[test] fn asset_filter(){assert!(acceptable_asset("GameDraw_1.0.6_x64-setup.exe"));assert!(!acceptable_asset("GameDraw.bat"));assert!(!acceptable_asset("../GameDraw.exe"));assert!(!acceptable_asset("other.exe"));}
}
