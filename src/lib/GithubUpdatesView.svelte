<script lang="ts">
  import { Download, RefreshCw, ExternalLink, CheckCircle2, AlertTriangle, GitBranch, ShieldCheck, FolderOpen } from "@lucide/svelte";
  import { openUrl } from "@tauri-apps/plugin-opener";
  import { listen } from "@tauri-apps/api/event";
  import { api, type GithubRelease } from "./api";
  import { APP_VERSION } from "./app-meta";
  import { tr } from "./i18n";
  import type { AppConfig } from "./types";
  import UpdateNotification from "./UpdateNotification.svelte";

  let { config, onConfigChange, confirmer, discoveredUpdate = null }: {
    config: AppConfig;
    onConfigChange: (value: AppConfig) => void;
    confirmer: (question: string) => Promise<boolean>;
    discoveredUpdate?: GithubRelease | null;
  } = $props();

  // Réglage éditeur : dépôt officiel caché à l’utilisateur final.
  const OFFICIAL_REPO = "FaboulousSan/GameDraw";
  let previewNotification = $state(false);
  const demoRelease: GithubRelease = {
    version: "1.0.7-demo", tag: "v1.0.7-demo", title: "GameDraw 1.0.7 (démo)",
    notes: "Animation, nouveautés, version actuelle et version disponible — aperçu uniquement, aucune release téléchargée.",
    htmlUrl: "https://github.com/FaboulousSan/GameDraw/releases", publishedAt: null, assets: []
  };
  let loading = $state(false);
  let downloading = $state(false);
  let status = $state("");
  // Reprendre la mise à jour détectée au démarrage, sans une deuxième requête GitHub.
  // svelte-ignore state_referenced_locally
  let release = $state<GithubRelease | null>(discoveredUpdate);
  let receivedBytes = $state(0);
  let totalBytes = $state(0);
  let progress = $derived(totalBytes > 0 ? Math.min(100, Math.round(receivedBytes / totalBytes * 100)) : 0);
  let downloaded = $state("");
  // svelte-ignore state_referenced_locally
  let selectedAsset = $state(discoveredUpdate?.assets.find((a) => a.name.toLowerCase().endsWith(".exe"))?.name ?? discoveredUpdate?.assets[0]?.name ?? "");
  // Une nouvelle notification peut arriver pendant que les Options sont déjà ouvertes.
  // Ne PAS réinjecter une ancienne release quand l'utilisateur change de canal.
  let lastImportedTag = discoveredUpdate?.tag ?? "";
  $effect(() => {
    const incoming = discoveredUpdate;
    if (incoming && incoming.tag !== lastImportedTag) {
      lastImportedTag = incoming.tag;
      release = incoming;
      selectedAsset = incoming.assets.find((a) => a.name.toLowerCase().endsWith(".exe"))?.name
        ?? incoming.assets[0]?.name ?? "";
    }
  });

  async function verifier() {
    if (loading || downloading) return;
    const repo = OFFICIAL_REPO;
    if (!repo) { status = tr(config.langue, "Renseigne d'abord le dépôt GitHub officiel.", "Enter the official GitHub repository first."); return; }
    loading = true;
    status = "";
    release = null;
    downloaded = "";
    selectedAsset = "";
    try {
      const found = await api.githubReleaseCheck(repo, config.updatesChannel, APP_VERSION);
      if (found) {
        release = found;
        selectedAsset = found.assets.find((a) => a.name.toLowerCase().endsWith(".exe"))?.name ?? found.assets[0]?.name ?? "";
        status = tr(config.langue, `Nouvelle version ${found.version} détectée.`, `New version ${found.version} available.`);
      } else {
        status = tr(config.langue, "Aucune version plus récente pour ce canal.", "No newer version on this channel.");
      }
    } catch (e) {
      status = `${tr(config.langue, "Vérification impossible", "Could not check for updates")} : ${String(e)}`;
    } finally { loading = false; }
  }
  async function telecharger() {
    if (!release || !selectedAsset || downloading || loading) return;
    const oui = await confirmer(tr(config.langue,
      `Télécharger ${selectedAsset} depuis ${OFFICIAL_REPO} vers le dossier Téléchargements ? GameDraw ne lancera PAS cet installateur automatiquement.`,
      `Download ${selectedAsset} from ${OFFICIAL_REPO} to your Downloads folder? GameDraw will NOT run this installer automatically.`));
    if (!oui) return;
    downloading = true;
    receivedBytes = 0;
    totalBytes = release.assets.find((a) => a.name === selectedAsset)?.size ?? 0;
    status = tr(config.langue, "Téléchargement en cours…", "Downloading…");
    let stopListening: (() => void) | null = null;
    try {
      stopListening = await listen<{ received: number; total: number }>("gamedraw:update-download-progress", (event) => {
        receivedBytes = event.payload.received;
        totalBytes = event.payload.total;
      });
      downloaded = await api.githubReleaseDownload(OFFICIAL_REPO, release.tag, selectedAsset);
      receivedBytes = totalBytes;
      status = tr(config.langue,
        "Téléchargement terminé. Installateur dans Téléchargements ; lancement manuel jusqu'à l'activation de l'updater signé.",
        "Download complete. Installer in Downloads; manual launch until signed updates are enabled.");
    } catch (e) {
      status = `${tr(config.langue, "Échec du téléchargement", "Download failed")} : ${String(e)}`;
    } finally {
      stopListening?.();
      downloading = false;
    }
  }
</script>

<div class="gd-updater">
  <div class="carte-reglage updater-hero">
    <div class="updater-heading"><RefreshCw size={20}/><div>
      <strong>{tr(config.langue, "Mises à jour GameDraw", "GameDraw updates")}</strong>
      <p class="aide">{tr(config.langue, `Version installée : ${APP_VERSION}`, `Installed version: ${APP_VERSION}`)}</p>
    </div></div>
    <p class="aide">{tr(config.langue,
      "Recherche les versions du dépôt officiel FaboulousSan/GameDraw. Détection désactivable : jamais de téléchargement sans accord.",
      "Checks the official FaboulousSan/GameDraw releases. Disable checks any time; downloads require your approval.")}</p>

  </div>

  <div class="carte-reglage">
    <label class="ligne-toggle">
      <span>{tr(config.langue, "Vérifier automatiquement au démarrage", "Automatically check on startup")}</span>
      <button class="toggle" class:actif={config.updatesAutoCheck} aria-label={tr(config.langue, "Vérification automatique", "Automatic checking")} onclick={() => onConfigChange({ ...config, updatesAutoCheck: !config.updatesAutoCheck, updatesConsentAnswered: true })}>
        <span class="pastille"></span>
      </button>
    </label>
    <p class="eyebrow">{tr(config.langue, "Canal de diffusion", "Release channel")}</p>
    <div class="updater-inline">
      <button class="btn-sgdb-action" class:updater-active={config.updatesChannel === "stable"} onclick={() => { release = null; onConfigChange({ ...config, updatesChannel: "stable" }); }}>Stable</button>
      <button class="btn-sgdb-action" class:updater-active={config.updatesChannel === "beta"} onclick={() => { release = null; onConfigChange({ ...config, updatesChannel: "beta" }); }}><GitBranch size={14}/> Bêta</button>
    </div>
    <p class="aide">{tr(config.langue, "Stable exclut les préversions ; Bêta inclut les préversions GitHub. Le téléchargement exige ton accord.", "Stable excludes prereleases; Beta also includes GitHub prereleases. Downloads require your approval.")}</p>
    <button type="button" class="btn-sgdb-action updater-check" onclick={verifier} disabled={loading || downloading}>
      <RefreshCw size={16} class={loading ? "updater-spin" : ""}/>{loading ? tr(config.langue, "Recherche…", "Checking…") : tr(config.langue, "Rechercher une mise à jour", "Check for updates")}
    </button>
    <button type="button" class="btn-sgdb-action updater-preview" onclick={() => (previewNotification = true)}>
      <CheckCircle2 size={16}/>{tr(config.langue, "Tester la notification animée", "Preview animated update notification")}
    </button>
    <p class="aide">{tr(config.langue,"Aperçu local, sans requête GitHub ni installation.","Local preview; no GitHub request or installation.")}</p>
    {#if status}<p class="updater-status" role="status">{status}</p>{/if}
  </div>

  {#if release}
    <div class="carte-reglage updater-release">
      <div class="updater-heading"><CheckCircle2 size={20}/><div><strong>{release.title}</strong><p class="aide">{release.tag}{release.publishedAt ? ` · ${release.publishedAt.slice(0,10)}` : ""}</p></div></div>
      <div class="updater-version-compare" role="group" aria-label={tr(config.langue, "Comparaison des versions", "Version comparison")}>
        <span>v{APP_VERSION}</span><span aria-hidden="true">→</span><strong>v{release.version}</strong>
        <span class="updater-channel">{config.updatesChannel === "beta" ? "Bêta" : "Stable"}</span>
      </div>
      {#if release.notes}<div class="updater-notes">{release.notes}</div>{/if}
      <button type="button" class="btn-sgdb-action" onclick={() => { void openUrl(release!.htmlUrl); }}><ExternalLink size={15}/>{tr(config.langue, "Voir sur GitHub", "View on GitHub")}</button>
      {#if release.assets.length}
        <p class="eyebrow">{tr(config.langue, "Installateur Windows", "Windows installer")}</p>
        <select aria-label={tr(config.langue, "Choix installateur", "Choose installer")} bind:value={selectedAsset}>
          {#each release.assets as asset}<option value={asset.name}>{asset.name} ({Math.round(asset.size/1024/1024)} Mo)</option>{/each}
        </select>
        <button class="btn-sgdb-action updater-check" type="button" onclick={telecharger} disabled={downloading || !selectedAsset}>
          <Download size={16}/>{downloading ? tr(config.langue, "Téléchargement…", "Downloading…") : tr(config.langue, "Télécharger dans Windows", "Download to Windows")}
        </button>
        {#if downloading}
          <div class="updater-progress" role="progressbar" aria-label={tr(config.langue, "Téléchargement", "Download")} aria-valuemin="0" aria-valuemax="100" aria-valuenow={progress}>
            <span style={`width:${progress}%`}></span>
          </div>
          <p class="aide">{progress}% · {(receivedBytes / 1024 / 1024).toFixed(1)} / {(totalBytes / 1024 / 1024).toFixed(1)} Mo</p>
        {/if}
        {#if downloaded}<p class="aide"><FolderOpen size={14}/> {downloaded}</p>{/if}
      {:else}
        <p class="aide"><AlertTriangle size={15}/>{tr(config.langue, "Cette release ne contient aucun installateur GameDraw EXE/MSI téléchargeable.", "This release has no downloadable GameDraw EXE/MSI installer.")}</p>
      {/if}
    </div>
  {/if}
  <div class="carte-reglage updater-security">
    <p class="eyebrow"><ShieldCheck size={16}/> {tr(config.langue,"Sécurité de l'installation", "Installation security")}</p>
    <p class="aide">{tr(config.langue,
      "En 1.0.6, GameDraw peut détecter et télécharger un installateur officiel, mais ne l'exécute jamais. L'installation intégrée nécessite la configuration des signatures Tauri par l'éditeur ; voir le guide bêta.",
      "In 1.0.6 GameDraw can discover and download an official installer, but never runs it. In-app installation requires publisher-provisioned Tauri signatures; see the beta integration guide.")}</p>
  </div>
</div>

{#if previewNotification}
  <UpdateNotification
    release={demoRelease}
    currentVersion={APP_VERSION}
    langue={config.langue}
    preview={true}
    onDetails={() => (previewNotification = false)}
    onDismiss={() => (previewNotification = false)}
  />
{/if}

<style>
  .gd-updater { display: grid; gap: 16px; min-width: 0; }
  .carte-reglage { display:flex; flex-direction:column; gap:12px; padding:clamp(16px,2vw,22px); min-width:0; border-radius:16px; border:1px solid color-mix(in srgb,var(--border) 80%,transparent); background:linear-gradient(145deg, color-mix(in srgb,var(--card) 88%,var(--darkbg)), color-mix(in srgb,var(--card) 65%,var(--darkbg))); box-shadow:0 10px 34px rgba(0,0,0,.17); }
  .carte-reglage:hover { border-color:color-mix(in srgb,var(--accent) 25%,var(--border)); }
  .carte-reglage .aide { color:var(--muted); line-height:1.6; font-size:.8rem; margin:0; }
  .carte-reglage .eyebrow { color:var(--muted); font-weight:800; letter-spacing:.11em; text-transform:uppercase; font-size:.68rem; margin:0; }
  .gd-updater select { min-height:38px; border:1px solid var(--border); background:var(--input); color:var(--text); border-radius:10px; padding:9px 12px; font:inherit; }
  .gd-updater button:focus-visible { outline:2px solid var(--accent); outline-offset:2px; }
  .btn-sgdb-action { display:inline-flex; align-items:center; justify-content:center; gap:8px; width:max-content; max-width:100%; min-height:36px; padding:9px 13px; border-radius:10px; border:1px solid var(--border); color:var(--text); background:color-mix(in srgb,var(--input) 86%,transparent); font:600 .84rem var(--font-display); cursor:pointer; transition:transform .18s ease,border-color .18s ease,background-color .18s ease,box-shadow .18s ease; }
  .btn-sgdb-action:hover:not(:disabled) { transform:translateY(-1px); border-color:var(--accent); background:color-mix(in srgb,var(--accent) 16%,var(--input)); box-shadow:0 5px 20px color-mix(in srgb,var(--accent) 12%,transparent); }
  .btn-sgdb-action:disabled { opacity:.5; cursor:not-allowed; }
  .updater-check { color:var(--darkbg); background:var(--accent); border-color:var(--accent); font-weight:800; }
  .updater-check:hover:not(:disabled) { background:var(--accent); filter:brightness(1.07); }
  .ligne-toggle { display:flex; gap:15px; justify-content:space-between; align-items:center; flex-wrap:wrap; font-size:.87rem; font-weight:600; }
  .toggle { width:43px; height:24px; flex-shrink:0; position:relative; border-radius:50px; background:var(--input); border:1px solid var(--border); cursor:pointer; transition:background .2s ease; }
  .toggle .pastille { position:absolute; width:17px; height:17px; border-radius:100%; left:3px; top:2px; background:var(--muted); transition:transform .2s ease; }
  .toggle.actif { border-color:var(--accent); background:color-mix(in srgb,var(--accent) 38%,var(--input)); }
  .toggle.actif .pastille { background:var(--accent); transform:translateX(18px); }
  .updater-security { border-color:color-mix(in srgb,var(--warning) 40%,var(--border)); }
  @media(max-width:540px){ .updater-inline { align-items:stretch; } .btn-sgdb-action { width:auto; } }
  .updater-hero { background: linear-gradient(135deg, color-mix(in srgb, var(--accent) 12%, transparent), transparent 75%); }
  .updater-heading { display:flex; gap:12px; align-items:center; }
  .updater-heading strong { font-family: var(--font-display); font-size:1.15rem; }
  .updater-heading p { margin:4px 0 0; }
  .updater-inline { display:flex; flex-wrap:wrap; gap:10px; align-items:center; }
  .updater-active { border-color:var(--accent) !important; color:var(--accent) !important; }
  .updater-check { margin-top:12px; }
  .updater-preview { margin-top:9px; }
  .updater-notes { white-space:pre-wrap; max-height:210px; overflow-y:auto; font-size:.84rem; color:var(--muted); margin:10px 0; overflow-wrap:anywhere; }
  .updater-status { margin:10px 0 0; padding:10px; border-radius:8px; color:var(--text); background:color-mix(in srgb,var(--accent) 10%, transparent); font-size:.85rem; overflow-wrap:anywhere; }
  .updater-security .eyebrow { display:flex; align-items:center; gap:8px; }
  .updater-version-compare { display:flex; flex-wrap:wrap; align-items:center; gap:9px; margin:12px 0; }
  .updater-version-compare span:first-child { padding:5px 10px; border-radius:8px; background:var(--surface); color:var(--muted); }
  .updater-version-compare strong { padding:5px 10px; border-radius:8px; background:color-mix(in srgb, var(--accent) 18%, transparent); color:var(--accent); }
  .updater-channel { margin-left:auto; font-size:.75rem; color:var(--muted); }
  .updater-progress { width:100%; height:9px; overflow:hidden; border-radius:999px; background:color-mix(in srgb,var(--accent) 13%,var(--surface)); margin:10px 0 5px; }
  .updater-progress > span { display:block; height:100%; background:var(--accent); border-radius:999px; transition:width 160ms ease; }
  .updater-spin { animation: spin-up 1.5s linear infinite; }
  @keyframes spin-up {to{transform:rotate(360deg)}}
</style>
