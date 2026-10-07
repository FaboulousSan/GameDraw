<script lang="ts">
  import { X, Search, Loader2 } from "@lucide/svelte";
  import { api, type RawgGame } from "./api";
  import { langueApp, tr } from "./i18n";

  let {
    rawgApiKey,
    onAjouter,
    onClose,
  }: {
    rawgApiKey: string;
    onAjouter: (nom: string, coverUrl: string | null) => void;
    onClose: () => void;
  } = $props();

  let recherche = $state("");
  let resultats = $state<RawgGame[] | null>(null);
  let enCours = $state(false);
  let erreur = $state<string | null>(null);

  async function rechercher() {
    if (!recherche.trim() || !rawgApiKey.trim()) return;
    enCours = true;
    erreur = null;
    resultats = null;
    try {
      resultats = await api.rawgSearch(rawgApiKey, recherche);
    } catch (e) {
      erreur = String(e);
    } finally {
      enCours = false;
    }
  }

  function choisir(r: RawgGame) {
    onAjouter(r.nom, r.coverUrl);
    onClose();
  }
</script>

<!-- svelte-ignore a11y_click_events_have_key_events -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="backdrop" onclick={onClose}>
  <div class="dialogue glass" onclick={(e) => e.stopPropagation()} role="dialog" aria-modal="true" tabindex="-1">
    <div class="entete">
      <p class="titre">{tr($langueApp, "Ajouter un jeu depuis RAWG", "Add a game from RAWG")}</p>
      <button class="fermer" onclick={onClose} aria-label="Fermer"><X size={18} strokeWidth={2.2} /></button>
    </div>

    {#if !rawgApiKey.trim()}
      <p class="aide">
        Renseigne ta clé API RAWG dans <strong>Options → Connexion</strong> pour activer cette
        recherche.
      </p>
    {:else}
      <p class="aide">
        Cherche un jeu sur RAWG (toutes plateformes) — le sélectionner l'ajoute directement à la
        bibliothèque active, avec sa jaquette déjà téléchargée.
      </p>
      <div class="recherche">
        <input
          type="text"
          placeholder="Nom du jeu à chercher…"
          bind:value={recherche}
          onkeydown={(e) => e.key === "Enter" && rechercher()}
        />
        <button class="btn-chercher" onclick={rechercher} disabled={enCours || !recherche.trim()}>
          {#if enCours}<Loader2 size={15} strokeWidth={2.2} class="spin" />{:else}<Search size={15} strokeWidth={2.2} />{/if}
        </button>
      </div>

      {#if erreur}<p class="erreur">{erreur}</p>{/if}

      {#if resultats}
        <div class="resultats">
          {#each resultats as r (r.id)}
            <button class="resultat" onclick={() => choisir(r)}>
              {#if r.coverUrl}<img src={r.coverUrl} alt={r.nom} />{:else}<span class="pas-de-jaquette">?</span>{/if}
              <span>{r.nom}</span>
            </button>
          {/each}
          {#if resultats.length === 0}
            <p class="aide">{tr($langueApp, "Aucun résultat.", "No results.")}</p>
          {/if}
        </div>
      {/if}
    {/if}
  </div>
</div>

<style>
  .backdrop {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.55);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 50;
    padding: var(--space-4);
  }
  .dialogue {
    width: 100%;
    max-width: 460px;
    max-height: 80vh;
    overflow-y: auto;
    padding: var(--space-4);
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }
  .entete {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .titre {
    font-family: var(--font-display);
    font-weight: 700;
    font-size: 1rem;
    color: var(--text);
    margin: 0;
  }
  .fermer {
    background: transparent;
    border: none;
    color: var(--muted);
    cursor: pointer;
    padding: 4px;
  }
  .aide {
    color: var(--muted);
    font-size: 0.82rem;
    margin: 0;
  }
  .aide strong {
    color: var(--text);
  }
  .recherche {
    display: flex;
    gap: 6px;
  }
  .recherche input {
    flex: 1;
    background: color-mix(in srgb, var(--input) 85%, transparent);
    color: var(--text);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 7px 10px;
    font-family: var(--font-body);
    font-size: 0.85rem;
  }
  .btn-chercher {
    background: var(--accent);
    color: var(--darkbg);
    border: none;
    border-radius: var(--radius-sm);
    padding: 0 12px;
    cursor: pointer;
    display: flex;
    align-items: center;
  }
  .btn-chercher:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
  .erreur {
    color: var(--danger);
    font-size: 0.8rem;
    margin: 0;
  }
  .resultats {
    display: flex;
    flex-direction: column;
    gap: 4px;
    max-height: 320px;
    overflow-y: auto;
  }
  .resultat {
    display: flex;
    align-items: center;
    gap: 10px;
    background: color-mix(in srgb, var(--input) 70%, transparent);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 6px 10px;
    cursor: pointer;
    text-align: left;
    color: var(--text);
    font-family: var(--font-body);
    font-size: 0.85rem;
    transition: border-color 0.15s ease, background-color 0.15s ease;
  }
  .resultat:hover {
    border-color: var(--accent);
    background: color-mix(in srgb, var(--accent) 12%, transparent);
  }
  .resultat img {
    width: 32px;
    height: 44px;
    object-fit: cover;
    border-radius: 4px;
    flex-shrink: 0;
  }
  .pas-de-jaquette {
    width: 32px;
    height: 44px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--input);
    border-radius: 4px;
    color: var(--muted);
    flex-shrink: 0;
  }

  :global(.spin) {
    animation: spin 0.6s linear infinite;
  }
  @keyframes spin {
    to { transform: rotate(360deg); }
  }
</style>
