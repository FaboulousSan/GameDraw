<script lang="ts">
  import { Sparkles, Download, ArrowRight, X, GitBranch, ShieldCheck } from "@lucide/svelte";
  import { fly, fade } from "svelte/transition";
  import type { GithubRelease } from "./api";
  import { tr, type LangueApp } from "./i18n";

  let { release, currentVersion, langue, onDetails, onDismiss, preview = false }: {
    release: GithubRelease;
    currentVersion: string;
    langue: LangueApp;
    onDetails: () => void;
    onDismiss: () => void;
    preview?: boolean;
  } = $props();
  const maxPreview = 160;
</script>

<aside class="gd-update-pop" in:fly={{ y: -22, duration: 420 }} out:fade={{ duration: 180 }} aria-labelledby="gd-update-title" role="status">
  <div class="gd-update-glow" aria-hidden="true"></div>
  <div class="gd-update-header">
    <span class="gd-update-emblem" aria-hidden="true"><Sparkles size={21}/></span>
    <span class="gd-update-label">{preview ? tr(langue,"APERÇU DE LA NOTIFICATION","NOTIFICATION PREVIEW") : tr(langue, "MISE À JOUR DISPONIBLE", "UPDATE AVAILABLE")}</span>
    <button class="gd-update-close" type="button" aria-label={tr(langue, "Plus tard", "Later")} onclick={onDismiss}><X size={17}/></button>
  </div>
  <h2 id="gd-update-title">GameDraw <span>v{release.version}</span></h2>
  <div class="gd-update-versions" aria-label={tr(langue,"Versions actuelle et disponible", "Current and available versions")}>
    <span>v{currentVersion}</span><ArrowRight size={17}/><strong>v{release.version}</strong>
    <small><GitBranch size={13}/>{release.tag}</small>
  </div>
  {#if release.notes.trim()}
    <p class="gd-update-notes">{release.notes.trim().slice(0,maxPreview)}{release.notes.trim().length > maxPreview ? "…" : ""}</p>
  {:else}
    <p class="gd-update-notes">{tr(langue,"Une nouvelle version vient d'être publiée sur le GitHub officiel.","A new version has been published on the official GitHub repository.")}</p>
  {/if}
  <div class="gd-update-actions">
    <button type="button" class="gd-update-primary" onclick={preview ? onDismiss : onDetails}><Download size={17}/>{preview ? tr(langue,"Fermer l'aperçu","Close preview") : tr(langue,"Découvrir la mise à jour","View update")}</button>
    <button type="button" class="gd-update-later" onclick={onDismiss}>{tr(langue,"Plus tard","Later")}</button>
  </div>
  <div class="gd-update-safe"><ShieldCheck size={14}/>{preview ? tr(langue,"Démonstration : aucune release réelle","Preview only: no actual release") : tr(langue,"Aucun téléchargement sans ton accord","No download without your permission")}</div>
</aside>

<style>
  .gd-update-pop { position:fixed; z-index:1300; right:19px; top:78px; width:min(390px,calc(100vw - 30px)); box-sizing:border-box; overflow:hidden; padding:19px 19px 15px; border-radius:19px;
    background:linear-gradient(135deg,color-mix(in srgb,var(--accent) 13%,var(--surface)),var(--surface) 66%); color:var(--text);
    border:1px solid color-mix(in srgb,var(--accent) 45%,transparent);
    box-shadow:0 22px 65px rgba(0,0,0,.32),0 0 24px color-mix(in srgb,var(--accent) 15%,transparent);
    backdrop-filter:blur(20px); isolation:isolate; }
  .gd-update-glow { position:absolute; width:160px; height:160px; right:-70px; top:-90px; border-radius:50%; background:var(--accent); filter:blur(55px); opacity:.23; pointer-events:none; animation:gd-pulse 4s ease-in-out infinite alternate; z-index:-1; }
  .gd-update-header { display:flex; gap:10px; align-items:center; }
  .gd-update-emblem { display:grid; place-items:center; color:var(--accent); width:33px; height:33px; border-radius:10px; background:color-mix(in srgb,var(--accent) 15%,transparent); animation:gd-float 3.5s ease-in-out infinite; }
  .gd-update-label { flex:1; font-weight:800; font-size:.73rem; letter-spacing:.10em; color:var(--accent); }
  .gd-update-close { display:grid; place-items:center; border:0; width:28px; height:28px; border-radius:8px; background:transparent; color:var(--muted); cursor:pointer; }
  .gd-update-close:hover { background:color-mix(in srgb,var(--text) 9%,transparent); color:var(--text); }
  h2 { font-family:var(--font-display); font-weight:800; font-size:1.55rem; margin:13px 0 8px; line-height:1.1; }
  h2 span { color:var(--accent); }
  .gd-update-versions { display:flex; flex-wrap:wrap; align-items:center; gap:9px; font-size:.88rem; }
  .gd-update-versions > span { opacity:.62; }
  .gd-update-versions strong { color:var(--accent); font-weight:800; }
  .gd-update-versions small { display:inline-flex; gap:4px; align-items:center; margin-left:auto; opacity:.63; font-size:.72rem; }
  .gd-update-notes { margin:12px 0 15px; color:var(--muted); font-size:.86rem; white-space:pre-line; overflow-wrap:anywhere; max-height:90px; overflow:hidden; }
  .gd-update-actions { display:flex; gap:8px; flex-wrap:wrap; }
  .gd-update-actions button { cursor:pointer; padding:10px 12px; border-radius:10px; font-weight:750; font-size:.82rem; }
  .gd-update-primary { border:1px solid color-mix(in srgb,var(--accent) 70%,transparent); background:var(--accent); color:white; display:inline-flex; align-items:center; gap:8px; }
  .gd-update-primary:hover { filter:brightness(1.12); transform:translateY(-1px); }
  .gd-update-later { border:1px solid color-mix(in srgb,var(--text) 14%,transparent); background:transparent; color:var(--muted); }
  .gd-update-safe { display:flex; gap:5px; align-items:center; opacity:.68; margin-top:12px; font-size:.72rem; }
  @keyframes gd-pulse { from{transform:scale(.78);opacity:.10}to{transform:scale(1.14);opacity:.28} }
  @keyframes gd-float { 0%,100%{transform:translateY(0)}50%{transform:translateY(-3px)} }
  @media (max-width:520px){ .gd-update-pop{right:10px;top:58px;} }
  @media (prefers-reduced-motion:reduce) { .gd-update-glow,.gd-update-emblem {animation:none;} .gd-update-primary:hover{transform:none;} }
</style>
