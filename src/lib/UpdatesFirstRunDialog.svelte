<script lang="ts">
  import { onMount } from "svelte";
  import { RefreshCw, ShieldCheck, Check, X } from "@lucide/svelte";
  import { tr, type LangueApp } from "./i18n";

  let { langue, onChoose, errorMessage = null } = $props<{
    langue: LangueApp;
    onChoose: (enabled: boolean) => void | Promise<void>;
    errorMessage?: string | null;
  }>();

  let dialogEl: HTMLDialogElement;
  let pending = $state(false);

  onMount(() => {
    if (!dialogEl.open) dialogEl.showModal();
    return () => { if (dialogEl.open) dialogEl.close(); };
  });

  async function choisir(enabled: boolean) {
    if (pending) return;
    pending = true;
    try { await onChoose(enabled); }
    finally { pending = false; }
  }
</script>

<dialog bind:this={dialogEl} class="first-update-dialog" aria-labelledby="first-update-title" aria-describedby="first-update-description" oncancel={(e) => e.preventDefault()}>
  <div class="first-update-icon"><RefreshCw size={27}/></div>
  <p class="first-update-kicker">{tr(langue, "Premier lancement · Mises à jour", "First launch · Updates")}</p>
  <h2 id="first-update-title">{tr(langue, "GameDraw peut surveiller les nouvelles versions", "GameDraw can check for new versions")}</h2>
  <p id="first-update-description" class="first-update-desc">
    {tr(langue,
      "Souhaites-tu que GameDraw vérifie automatiquement les nouvelles versions officielles sur GitHub au lancement ? Tu recevras une notification animée avec le numéro de version et les nouveautés.",
      "Would you like GameDraw to check for official new releases on GitHub at startup? You will see an animated notification with the version number and release notes.")}
  </p>
  <div class="first-update-privacy"><ShieldCheck size={19}/><span>{tr(langue,
    "Aucun téléchargement ni aucune installation sans ton accord. Modifiable à tout moment dans Options → Mises à jour.",
    "No download or installation without your approval. Change this later under Settings → Updates.")}</span></div>
  <div class="first-update-actions">
    <button type="button" class="first-update-yes" disabled={pending} onclick={() => void choisir(true)}><Check size={18}/>{tr(langue,"Oui, vérifier au lancement", "Yes, check on startup")}</button>
    <button type="button" class="first-update-no" disabled={pending} onclick={() => void choisir(false)}><X size={17}/>{tr(langue,"Non, merci", "No, thanks")}</button>
  </div>
  {#if errorMessage}<p class="first-update-error" role="alert">{errorMessage}</p>{/if}
</dialog>

<style>
  .first-update-dialog { width:min(550px,calc(100vw - 24px)); max-width:none; max-height:calc(100dvh - 24px); margin:auto; padding:clamp(18px,4vw,32px); overflow-y:auto; border-radius:20px; border:1px solid color-mix(in srgb,var(--accent) 35%,var(--border)); background:var(--card); color:var(--text); box-shadow:0 30px 95px rgba(0,0,0,.55); }
  .first-update-dialog::backdrop { background:rgba(3,9,22,.85); backdrop-filter:blur(11px); }
  .first-update-icon { width:54px; height:54px; display:grid; place-items:center; border-radius:15px; background:color-mix(in srgb,var(--accent) 17%,var(--input)); color:var(--accent); margin-bottom:13px; }
  .first-update-kicker { color:var(--accent); letter-spacing:.1em; text-transform:uppercase; font-size:.73rem; font-weight:800; margin:0 0 7px; }
  h2 { font-family:var(--font-display); font-size:clamp(1.25rem,3.3vw,1.85rem); line-height:1.18; margin:0; }
  .first-update-desc { color:var(--muted); line-height:1.6; margin:14px 0; }
  .first-update-privacy { display:flex; align-items:start; gap:11px; padding:12px; border:1px solid var(--border); border-radius:11px; background:var(--input); font-size:.84rem; line-height:1.45; }
  .first-update-privacy :global(svg) { flex:none; color:var(--accent); }
  .first-update-actions { margin-top:18px; display:flex; flex-wrap:wrap; gap:10px; }
  .first-update-actions button { display:flex; justify-content:center; align-items:center; gap:8px; padding:11px 15px; border-radius:11px; font:inherit; font-weight:700; cursor:pointer; }
  .first-update-yes { color:var(--darkbg); background:var(--accent); border:1px solid var(--accent); }
  .first-update-no { color:var(--text); background:var(--input); border:1px solid var(--border); }
  button:focus-visible { outline:2px solid var(--accent); outline-offset:3px; }
  button:disabled { opacity:.5; cursor:wait; }
  .first-update-error { color:var(--danger); overflow-wrap:anywhere; font-size:.84rem; }
</style>
