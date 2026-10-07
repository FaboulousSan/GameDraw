<script lang="ts">
  import { X, Loader2, Download, Check } from "@lucide/svelte";
  import { fade, scale, fly } from "svelte/transition";
  import { api, type SteamGame } from "./api";
  import { langueApp, tr } from "./i18n";

  let {
    steamApiKey,
    steamId64,
    onImport,
    onClose,
  }: {
    steamApiKey: string;
    steamId64: string;
    onImport: (noms: string[]) => void;
    onClose: () => void;
  } = $props();

  let enCours = $state(false);
  let erreur = $state<string | null>(null);
  let jeux = $state<SteamGame[] | null>(null);
  let selection = $state<Set<number>>(new Set());
  let succes = $state(false);

  async function recuperer() {
    if (!steamApiKey.trim() || !steamId64.trim()) {
      erreur = "Renseigne ta clé API Steam et ton SteamID64 dans Options → Connexion.";
      return;
    }
    enCours = true;
    erreur = null;
    try {
      jeux = await api.steamOwnedGames(steamApiKey, steamId64);
      selection = new Set(jeux.map((j) => j.appid));
    } catch (e) {
      erreur = String(e);
    } finally {
      enCours = false;
    }
  }

  function basculer(appid: number) {
    const s = new Set(selection);
    if (s.has(appid)) s.delete(appid);
    else s.add(appid);
    selection = s;
  }

  function importer() {
    if (!jeux) return;
    const noms = jeux.filter((j) => selection.has(j.appid)).map((j) => j.nom);
    onImport(noms);
    succes = true;
    setTimeout(onClose, 700);
  }
</script>

<!-- svelte-ignore a11y_click_events_have_key_events -- clic-dehors pour
     fermer est un bonus souris ; le clavier est déjà couvert par Échap et
     le bouton de fermeture explicite. -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="backdrop" transition:fade={{ duration: 120 }} onclick={onClose}>
  <div class="dialog glass" transition:scale={{ duration: 160, start: 0.96 }} onclick={(e) => e.stopPropagation()} role="dialog" aria-modal="true" tabindex="-1">
    <button class="fermer" onclick={onClose} aria-label="Fermer"><X size={18} strokeWidth={2.2} /></button>

    {#if succes}
      <div class="succes" transition:scale={{ duration: 260, start: 0.7 }}>
        <Check size={40} strokeWidth={2.5} color="var(--success)" />
        <p>{tr($langueApp, "Import réussi", "Import successful")}</p>
      </div>
    {:else}
      <h2>{tr($langueApp, "Import Steam", "Steam import")}</h2>

      {#if !steamApiKey.trim() || !steamId64.trim()}
        <p class="renvoi-options">{tr($langueApp, "Renseigne ta clé API Steam et ton SteamID64 dans", "Enter your Steam API key and SteamID64 in")} <strong>{tr($langueApp, "Options → Connexion", "Settings → Connections")}</strong>.</p>
      {/if}

      <button class="btn-recuperer" onclick={recuperer} disabled={enCours}>
        {#if enCours}<Loader2 size={16} strokeWidth={2.2} class="spin" />{:else}<Download size={16} strokeWidth={2.2} />{/if}
        Récupérer la bibliothèque Steam
      </button>

      {#if erreur}<p class="erreur">{erreur}</p>{/if}

      {#if jeux}
        <p class="compte">{selection.size} / {jeux.length} sélectionnés</p>
        <div class="liste-jeux">
          {#each jeux as j, i (j.appid)}
            <label class="ligne-jeu" in:fly={{ y: 6, duration: 180, delay: Math.min(i, 20) * 12 }}>
              <input type="checkbox" checked={selection.has(j.appid)} onchange={() => basculer(j.appid)} />
              {j.nom}
            </label>
          {/each}
          {#if jeux.length === 0}
            <p class="placeholder-txt">{tr($langueApp, "Aucun jeu trouvé (profil privé ?).", "No games found (private profile?)")}</p>
          {/if}
        </div>
        <button class="btn-importer" onclick={importer} disabled={selection.size === 0}>
          Importer la sélection ({selection.size})
        </button>
      {/if}
    {/if}
  </div>
</div>

<style>
  .backdrop {
    position: fixed;
    inset: 0;
    z-index: 50;
    background: rgba(0, 0, 0, 0.5);
    backdrop-filter: blur(3px);
    display: flex;
    align-items: center;
    justify-content: center;
    padding: var(--space-4);
  }

  .dialog {
    position: relative;
    max-width: 420px;
    width: 100%;
    max-height: 80vh;
    overflow-y: auto;
    padding: var(--space-4);
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .fermer {
    position: absolute;
    top: var(--space-2);
    right: var(--space-2);
    background: transparent;
    border: none;
    color: var(--muted);
    cursor: pointer;
    padding: 4px;
    border-radius: 6px;
  }
  .fermer:hover {
    background: color-mix(in srgb, var(--input) 80%, transparent);
  }

  h2 {
    font-family: var(--font-display);
    font-size: 1.2rem;
    font-weight: 700;
    margin: 0 var(--space-4) var(--space-2) 0;
    color: var(--text);
  }

  .renvoi-options {
    color: var(--muted);
    font-size: 0.78rem;
    margin: 0;
  }
  .renvoi-options strong {
    color: var(--text);
  }

  .btn-recuperer,
  .btn-importer {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    background: var(--accent);
    color: var(--darkbg);
    border: none;
    border-radius: var(--radius-sm);
    padding: 8px 14px;
    font-family: var(--font-display);
    font-weight: 600;
    font-size: 0.9rem;
    cursor: pointer;
    margin-top: 4px;
  }
  .btn-recuperer:disabled,
  .btn-importer:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .erreur {
    color: var(--danger);
    font-size: 0.82rem;
    margin: 0;
  }

  .compte {
    color: var(--muted);
    font-size: 0.82rem;
    margin: 4px 0 0;
  }

  .liste-jeux {
    display: flex;
    flex-direction: column;
    gap: 2px;
    max-height: 260px;
    overflow-y: auto;
    background: color-mix(in srgb, var(--input) 60%, transparent);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 6px;
  }
  .ligne-jeu {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 4px 6px;
    border-radius: 6px;
    font-size: 0.85rem;
    color: var(--text);
    cursor: pointer;
  }
  .ligne-jeu:hover {
    background: color-mix(in srgb, var(--accent) 12%, transparent);
  }
  .placeholder-txt {
    color: var(--muted);
    font-size: 0.82rem;
    margin: 4px;
  }

  :global(.spin) {
    animation: spin 0.6s linear infinite;
  }
  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  .succes {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
    padding: var(--space-5) var(--space-3);
  }
  .succes p {
    font-family: var(--font-display);
    font-weight: 600;
    color: var(--text);
    margin: 0;
  }
</style>
