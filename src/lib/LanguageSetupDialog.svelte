<script lang="ts">
  import { Languages, Monitor, Check } from "@lucide/svelte";
  import { onMount } from "svelte";
  import type { LangueApp } from "./i18n";

  let {
    detectedLang,
    currentLang,
    errorMessage = null,
    onChoose,
  } = $props<{
    detectedLang: LangueApp;
    currentLang: LangueApp;
    errorMessage?: string | null;
    onChoose: (langue: LangueApp) => void | Promise<void>;
  }>();

  const detectionLabel = $derived(
    detectedLang === "fr" ? "Français / French" : "English / Anglais"
  );

  let dialogEl: HTMLDialogElement;

  onMount(() => {
    if (!dialogEl.open) dialogEl.showModal();
    requestAnimationFrame(() => {
      dialogEl.querySelector<HTMLButtonElement>(".language-choice.active")?.focus();
    });
    return () => {
      if (dialogEl.open) dialogEl.close();
    };
  });
</script>

<dialog bind:this={dialogEl} class="language-dialog" aria-labelledby="language-title" aria-describedby="language-description" oncancel={(event) => event.preventDefault()}>
    <div class="language-icon" aria-hidden="true"><Languages size={28} strokeWidth={2.1} /></div>
    <p class="language-kicker">Premier lancement · First launch</p>
    <h2 id="language-title">Choisissez votre langue <span>/ Choose your language</span></h2>
    <p id="language-description" class="language-description">
      GameDraw utilise la langue de votre système comme suggestion. Vous pourrez modifier ce choix à tout moment dans
      <strong>Options → À propos</strong>.
      <span>GameDraw uses your system language as the suggested choice. You can change it later in <strong>Settings → About</strong>.</span>
    </p>

    <div class="language-detected">
      <Monitor size={16} strokeWidth={2} />
      <span>Langue système détectée / Detected system language:</span>
      <strong>{detectionLabel}</strong>
    </div>

    <div class="language-choices" role="group" aria-label="Choix de la langue / Language selection">
      <button
        type="button"
        class="language-choice"
        class:active={currentLang === "fr"}
        onclick={() => void onChoose("fr")}
      >
        <span class="flag" aria-hidden="true">🇫🇷</span>
        <span class="choice-text"><strong>Français</strong><small>Interface en français</small></span>
        {#if currentLang === "fr"}<span class="choice-check" aria-hidden="true"><Check size={18} strokeWidth={2.4} /></span>{/if}
      </button>
      <button
        type="button"
        class="language-choice"
        class:active={currentLang === "en"}
        onclick={() => void onChoose("en")}
      >
        <span class="flag" aria-hidden="true">🇬🇧</span>
        <span class="choice-text"><strong>English</strong><small>English interface</small></span>
        {#if currentLang === "en"}<span class="choice-check" aria-hidden="true"><Check size={18} strokeWidth={2.4} /></span>{/if}
      </button>
    </div>

    {#if errorMessage}
      <p class="language-error" role="alert">{errorMessage}</p>
    {/if}

    <p class="language-note">Le choix est enregistré localement · Your choice is stored locally</p>
  </dialog>

<style>
  .language-dialog {
    position: relative;
    width: min(620px, calc(100vw - 28px));
    max-width: none;
    max-height: calc(100vh - 28px);
    margin: auto;
    padding: clamp(24px, 5vw, 38px);
    border: 1px solid color-mix(in srgb, var(--accent) 38%, var(--border));
    border-radius: calc(var(--radius) + 6px);
    background: linear-gradient(145deg, color-mix(in srgb, var(--card) 95%, var(--accent) 5%), var(--card));
    color: var(--text);
    box-shadow: 0 28px 80px rgba(0, 0, 0, 0.48), 0 0 50px color-mix(in srgb, var(--accent) 13%, transparent);
  }

  .language-dialog::backdrop {
    background: color-mix(in srgb, var(--darkbg) 82%, transparent);
    backdrop-filter: blur(14px);
    -webkit-backdrop-filter: blur(14px);
  }

  .language-icon {
    width: 56px;
    height: 56px;
    display: grid;
    place-items: center;
    border-radius: 16px;
    color: var(--accent);
    background: color-mix(in srgb, var(--accent) 14%, var(--input));
    border: 1px solid color-mix(in srgb, var(--accent) 32%, var(--border));
    margin-bottom: 18px;
  }

  .language-kicker {
    margin: 0 0 6px;
    font-family: var(--font-display);
    font-weight: 700;
    letter-spacing: .13em;
    text-transform: uppercase;
    font-size: .72rem;
    color: var(--accent);
  }

  h2 {
    margin: 0;
    font-family: var(--font-display);
    font-size: clamp(1.65rem, 4vw, 2.25rem);
    line-height: 1.05;
    color: var(--text);
  }

  h2 span {
    color: var(--muted);
    font-weight: 500;
  }

  .language-description {
    margin: 16px 0 18px;
    line-height: 1.6;
    color: var(--muted);
  }

  .language-description > span {
    display: block;
    margin-top: 5px;
  }

  .language-detected {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 7px;
    padding: 10px 12px;
    margin-bottom: 18px;
    border-radius: var(--radius-sm);
    background: color-mix(in srgb, var(--input) 75%, transparent);
    border: 1px solid var(--border);
    color: var(--muted);
    font-size: .83rem;
  }

  .language-detected strong { color: var(--text); }

  .language-choices {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 12px;
  }

  .language-choice {
    position: relative;
    min-height: 92px;
    display: flex;
    align-items: center;
    gap: 12px;
    text-align: left;
    padding: 16px;
    color: var(--text);
    background: color-mix(in srgb, var(--input) 82%, transparent);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    transition: transform .18s var(--spring), border-color .18s ease, background-color .18s ease, box-shadow .18s ease;
  }

  .language-choice:hover {
    transform: translateY(-2px);
    border-color: color-mix(in srgb, var(--accent) 70%, var(--border));
  }

  .language-choice.active {
    border-color: var(--accent);
    background: color-mix(in srgb, var(--accent) 14%, var(--input));
    box-shadow: 0 8px 26px color-mix(in srgb, var(--accent) 14%, transparent);
  }

  .flag { font-size: 1.8rem; line-height: 1; }
  .choice-text { display: flex; flex-direction: column; gap: 3px; }
  .choice-text strong { font-family: var(--font-display); font-size: 1.05rem; }
  .choice-text small { color: var(--muted); font-size: .75rem; }
  .choice-check { position: absolute; top: 12px; right: 12px; color: var(--accent); }

  .language-error {
    margin: 14px 0 0;
    padding: 10px 12px;
    border-radius: var(--radius-sm);
    color: var(--danger);
    background: color-mix(in srgb, var(--danger) 10%, transparent);
    border: 1px solid color-mix(in srgb, var(--danger) 35%, transparent);
    font-size: .82rem;
  }

  .language-note {
    margin: 16px 0 0;
    text-align: center;
    color: var(--muted);
    font-size: .74rem;
  }

  @media (max-width: 560px) {
    .language-choices { grid-template-columns: 1fr; }
  }
</style>
