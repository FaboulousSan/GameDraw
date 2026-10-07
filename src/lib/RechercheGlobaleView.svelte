<script lang="ts">
  import { Search, Loader2 } from "@lucide/svelte";
  import { convertFileSrc } from "@tauri-apps/api/core";
  import type { Platform } from "./types";
  import { api } from "./api";
  import { filtrerJeux } from "./library";
  import { langueApp, tr } from "./i18n";

  let {
    platforms,
    onOuvrirJeu,
  }: {
    platforms: Platform[];
    onOuvrirJeu: (platformId: string, gameId: string) => void;
  } = $props();

  interface Resultat {
    platformId: string;
    platformNom: string;
    gameId: string;
    nom: string;
    cover: string | null;
  }

  let recherche = $state("");
  let enCours = $state(false);
  let resultats = $state<Resultat[] | null>(null);
  let erreur = $state<string | null>(null);
  let requeteEnAttente: ReturnType<typeof setTimeout> | null = null;

  function surSaisie() {
    if (requeteEnAttente) clearTimeout(requeteEnAttente);
    if (!recherche.trim()) {
      resultats = null;
      return;
    }
    requeteEnAttente = setTimeout(lancerRecherche, 250); // léger anti-rebond
  }

  async function lancerRecherche() {
    const q = recherche.trim();
    if (!q) {
      resultats = null;
      return;
    }
    enCours = true;
    erreur = null;
    try {
      const tout: Resultat[] = [];
      for (const p of platforms.filter((p) => p.actif)) {
        const lib = await api.loadGames(p.id);
        for (const jeu of filtrerJeux(lib.jeux, q)) {
          tout.push({ platformId: p.id, platformNom: p.nom, gameId: jeu.id, nom: jeu.nom, cover: jeu.cover });
        }
      }
      resultats = tout;
    } catch (e) {
      erreur = String(e);
    } finally {
      enCours = false;
    }
  }
</script>

<section class="recherche-globale">
  <div class="barre-recherche glass">
    <Search size={18} strokeWidth={2.2} color="var(--muted)" />
    <input
      type="text"
      placeholder={tr($langueApp, "Chercher un jeu dans toutes les plateformes actives…", "Search for a game across all active platforms…")}
      bind:value={recherche}
      oninput={surSaisie}
    />
    {#if enCours}<Loader2 size={16} strokeWidth={2.2} class="spin" color="var(--muted)" />{/if}
  </div>

  {#if erreur}
    <p class="erreur">{erreur}</p>
  {:else if resultats === null}
    <p class="placeholder-txt">{tr($langueApp, "Tape au moins un caractère pour chercher dans toutes les plateformes actives.", "Type at least one character to search across all active platforms.")}</p>
  {:else if resultats.length === 0}
    <p class="placeholder-txt">{$langueApp === "en" ? `No game matches “${recherche}”.` : `Aucun jeu ne correspond à « ${recherche} ».`}</p>
  {:else}
    <div class="liste-resultats">
      {#each resultats as r (r.platformId + r.gameId)}
        <button class="ligne-resultat glass" onclick={() => onOuvrirJeu(r.platformId, r.gameId)}>
          <div class="cover-mini">
            {#if r.cover}
              <img src={convertFileSrc(r.cover)} alt={r.nom} />
            {:else}
              <span class="cover-placeholder">{r.nom.slice(0, 1).toUpperCase()}</span>
            {/if}
          </div>
          <span class="nom-resultat">{r.nom}</span>
          <span class="etiquette-plateforme">{r.platformNom}</span>
        </button>
      {/each}
    </div>
  {/if}
</section>

<style>
  .recherche-globale {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .barre-recherche {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: var(--space-2) var(--space-3);
  }
  .barre-recherche input {
    flex: 1;
    background: transparent;
    border: none;
    color: var(--text);
    font-family: var(--font-body);
    font-size: 0.95rem;
  }
  .barre-recherche input:focus {
    outline: none;
  }

  .placeholder-txt,
  .erreur {
    text-align: center;
    font-size: 0.9rem;
    color: var(--muted);
  }
  .erreur {
    color: var(--danger);
  }

  .liste-resultats {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .ligne-resultat {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: 8px var(--space-2);
    cursor: pointer;
    text-align: left;
    transition: transform 0.15s var(--spring);
  }
  .ligne-resultat:hover {
    transform: translateY(-2px);
  }

  .cover-mini {
    width: 36px;
    height: 48px;
    border-radius: 6px;
    overflow: hidden;
    background: var(--input);
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .cover-mini img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    object-position: top center;
  }
  .cover-placeholder {
    font-family: var(--font-display);
    font-weight: 700;
    font-size: 0.9rem;
    color: var(--muted);
  }

  .nom-resultat {
    flex: 1;
    font-family: var(--font-body);
    font-size: 0.9rem;
    color: var(--text);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .etiquette-plateforme {
    background: color-mix(in srgb, var(--accent) 18%, transparent);
    color: var(--accent);
    font-family: var(--font-display);
    font-weight: 600;
    font-size: 0.72rem;
    padding: 3px 9px;
    border-radius: 999px;
    flex-shrink: 0;
  }

  :global(.spin) {
    animation: spin 0.6s linear infinite;
  }
  @keyframes spin {
    to { transform: rotate(360deg); }
  }
</style>
