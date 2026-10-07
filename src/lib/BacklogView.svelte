<script lang="ts">
  import { Heart, ListChecks, Clock, CalendarDays, Eye, EyeOff, Award } from "@lucide/svelte";
  import { convertFileSrc } from "@tauri-apps/api/core";
  import type { AppConfig, Game, GameLibrary, Historique, Platform } from "./types";
  import { tempsCumuleJeu, dernierTirageJeu, formaterMinutes } from "./stats";
  import { trouverStatut } from "./statuts";
  import { ICONE_NOTATION_COMPOSANTS } from "./icones-notation";
  import { tr } from "./i18n";

  let {
    platformId,
    platforms,
    library,
    historique,
    config,
    onPlatformChange,
    onOuvrirJeu,
  }: {
    platformId: string | null;
    platforms: Platform[];
    library: GameLibrary | null;
    historique: Historique;
    config: AppConfig;
    onPlatformChange: (id: string) => void;
    onOuvrirJeu: (gameId: string) => void;
  } = $props();

  const IconeNote = $derived(ICONE_NOTATION_COMPOSANTS[config.iconeNotation]);

  // Un backlog, c'est d'abord "ce qu'il reste à faire" — pas une bibliothèque
  // parallèle. Masqué par défaut : Terminé/Abandonné, avec un bouton pour
  // les faire réapparaître. Plus d'onglets de statut ici (déjà dans la
  // Bibliothèque) : c'est ce qui différencie vraiment les deux vues.
  let voirTout = $state(false);
  let noteMin = $state(0);

  const jeuxFiltres = $derived(
    library
      ? library.jeux.filter(
          (j) => (voirTout || (j.statut !== "Termine" && j.statut !== "Abandonne")) && j.note >= noteMin
        )
      : []
  );

  function tags(jeu: Game): string[] {
    return jeu.tags
      .split(",")
      .map((t) => t.trim())
      .filter((t) => t.length > 0);
  }

  function formaterDate(iso: string): string {
    return new Intl.DateTimeFormat(config.langue === "en" ? "en-US" : "fr-FR", { day: "numeric", month: "short" }).format(new Date(iso));
  }
</script>

<section class="backlog">
  <div class="chips-plateforme">
    {#each platforms as p}
      <button class="chip-plateforme" class:active={p.id === platformId} onclick={() => onPlatformChange(p.id)}>
        {p.nom}
      </button>
    {/each}
  </div>

  <div class="filtres glass">
    <button class="btn-voir-tout" onclick={() => (voirTout = !voirTout)}>
      {#if voirTout}<Eye size={15} strokeWidth={2.2} />{:else}<EyeOff size={15} strokeWidth={2.2} />{/if}
      {voirTout ? tr(config.langue, "Tout affiché", "Showing all") : tr(config.langue, "Terminé/Abandonné masqués", "Completed/Abandoned hidden")}
    </button>
    <div class="filtre-note">
      <span class="eyebrow">{tr(config.langue, "Note min.", "Min. rating")}</span>
      {#each [0, 1, 2, 3, 4, 5] as n}
        <button class="etoile-filtre" onclick={() => (noteMin = n)} aria-label="Note minimale {n}">
          <IconeNote size={15} strokeWidth={2} fill={n <= noteMin && n > 0 ? "var(--accent)" : "none"} color={n === 0 ? "var(--muted)" : "var(--accent)"} />
        </button>
      {/each}
    </div>
  </div>

  {#if jeuxFiltres.length === 0}
    <p class="aucun-resultat">
      {#if !voirTout && library && library.jeux.length > 0}
        {tr(config.langue, "Rien à faire pour l’instant — tout est terminé, abandonné, ou filtré par la note.", "Nothing left for now — everything is completed, abandoned, or filtered by rating.")}
      {:else}
        {tr(config.langue, "Aucun jeu ne correspond à ces filtres.", "No games match these filters.")}
      {/if}
    </p>
  {:else}
    <div class="grille-backlog">
      {#each jeuxFiltres as jeu (jeu.id)}
        {@const tempsCumule = tempsCumuleJeu(historique, jeu.id)}
        {@const dernierTirage = dernierTirageJeu(historique, jeu.id)}
        {@const defisComplets = jeu.defis.filter((d) => d.complete).length}
        {@const statutJeu = trouverStatut(config.statuts, jeu.statut)}
        <button class="carte-backlog" onclick={() => onOuvrirJeu(jeu.id)}>
          <div class="cover-backlog">
            {#if jeu.cover}
              <img src={convertFileSrc(jeu.cover)} alt={jeu.nom} />
            {:else}
              <span class="cover-placeholder">{jeu.nom.slice(0, 1).toUpperCase()}</span>
            {/if}
            <span
              class="badge-statut"
              style="background: {statutJeu.couleur}; --couleur-halo: {statutJeu.couleur};"
              class:pulse={jeu.statut === "EnCours" && config.ledAnimation === "pulse"}
            ></span>
            {#if jeu.envieDeFaire || jeu.coupDeCoeur || jeu.complete100}
              <div class="badges-coeur">
                {#if jeu.coupDeCoeur}<Heart size={14} strokeWidth={2} fill="var(--danger)" color="var(--danger)" />{/if}
                {#if jeu.envieDeFaire}<Heart size={14} strokeWidth={2} fill="var(--accent)" color="var(--accent)" />{/if}
                {#if jeu.complete100}<Award size={14} strokeWidth={2} fill="#EAB308" color="#EAB308" />{/if}
              </div>
            {/if}
          </div>
          <p class="nom-backlog">{jeu.nom}</p>
          {#if jeu.note > 0}
            <p class="note-backlog">
              <IconeNote size={12} strokeWidth={2} fill="var(--accent)" color="var(--accent)" />
              {jeu.note}
            </p>
          {/if}
          {#if tags(jeu).length > 0}
            <div class="puces-tags">
              {#each tags(jeu).slice(0, 3) as tag}
                <span class="puce-tag">{tag}</span>
              {/each}
            </div>
          {/if}
          {#if jeu.defis.length > 0 || dernierTirage || tempsCumule > 0 || jeu.heuresJouees}
            <div class="meta-backlog">
              {#if jeu.defis.length > 0}
                <span class="meta-item" class:complet={defisComplets === jeu.defis.length}>
                  <ListChecks size={11} strokeWidth={2} />
                  {defisComplets}/{jeu.defis.length}
                </span>
              {/if}
              {#if jeu.heuresJouees}
                <span class="meta-item"><Clock size={11} strokeWidth={2} />{jeu.heuresJouees}h</span>
              {:else if tempsCumule > 0}
                <span class="meta-item"><Clock size={11} strokeWidth={2} />{formaterMinutes(tempsCumule)}</span>
              {/if}
              {#if dernierTirage}
                <span class="meta-item"><CalendarDays size={11} strokeWidth={2} />{formaterDate(dernierTirage)}</span>
              {/if}
            </div>
          {/if}
        </button>
      {/each}
    </div>
  {/if}
</section>

<style>
  .backlog {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .chips-plateforme {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-2);
  }
  .chip-plateforme {
    background: color-mix(in srgb, var(--input) 80%, transparent);
    color: var(--muted);
    border: 1px solid var(--border);
    font-family: var(--font-display);
    font-weight: 600;
    font-size: 0.85rem;
    padding: 6px 14px;
    border-radius: var(--radius-sm);
    cursor: pointer;
    transition: transform 0.2s var(--spring), background-color 0.2s ease, color 0.2s ease;
  }
  .chip-plateforme:hover {
    transform: translateY(-2px);
  }
  .chip-plateforme.active {
    background: var(--accent);
    color: var(--darkbg);
    border-color: var(--accent);
    box-shadow: 0 4px 18px color-mix(in srgb, var(--accent) 45%, transparent);
  }

  .filtres {
    padding: var(--space-3);
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-3);
    align-items: center;
    justify-content: space-between;
  }

  .btn-voir-tout {
    display: flex;
    align-items: center;
    gap: 6px;
    background: color-mix(in srgb, var(--input) 80%, transparent);
    color: var(--muted);
    border: 1px solid var(--border);
    font-family: var(--font-body);
    font-size: 0.8rem;
    padding: 6px 12px;
    border-radius: var(--radius-sm);
    cursor: pointer;
    transition: color 0.15s ease, border-color 0.15s ease;
  }
  .btn-voir-tout:hover {
    color: var(--text);
    border-color: color-mix(in srgb, var(--accent) 50%, var(--border));
  }

  .filtre-note {
    display: flex;
    align-items: center;
    gap: 4px;
  }
  .etoile-filtre {
    background: transparent;
    border: none;
    cursor: pointer;
    padding: 2px;
    display: flex;
  }

  .aucun-resultat {
    color: var(--muted);
    text-align: center;
    font-size: 0.9rem;
  }

  .grille-backlog {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
    gap: var(--space-3);
  }

  .carte-backlog {
    display: flex;
    flex-direction: column;
    padding: 0;
    text-align: left;
    cursor: pointer;
    background: transparent;
    border: none;
    transition: transform 0.2s var(--spring);
  }
  .carte-backlog:hover {
    transform: translateY(-4px);
  }

  .cover-backlog {
    position: relative;
    width: 100%;
    aspect-ratio: 3 / 4;
    border-radius: var(--radius-sm);
    overflow: hidden;
    background: var(--input);
    box-shadow: 0 8px 20px rgba(0, 0, 0, 0.3);
    display: flex;
    align-items: center;
    justify-content: center;
    margin-bottom: 6px;
  }
  .cover-backlog img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    object-position: top center;
    transition: transform 0.35s ease;
  }
  .carte-backlog:hover .cover-backlog img {
    transform: scale(1.06);
  }
  .cover-placeholder {
    font-family: var(--font-display);
    font-size: 2rem;
    font-weight: 700;
    color: var(--muted);
  }

  .badge-statut {
    position: absolute;
    top: 8px;
    right: 8px;
    width: 5px;
    height: 5px;
    border-radius: 50%;
    box-shadow: 0 0 0 1px rgba(0, 0, 0, 0.35);
  }

  .badges-coeur {
    position: absolute;
    top: 8px;
    left: 8px;
    display: flex;
    gap: 3px;
  }
  .badge-statut.pulse {
    animation: pulse-statut 1.4s ease-in-out infinite;
  }
  @keyframes pulse-statut {
    0%, 100% { box-shadow: 0 0 0 1px rgba(0, 0, 0, 0.35), 0 0 0 0 color-mix(in srgb, var(--couleur-halo, var(--accent)) 60%, transparent); }
    50% { box-shadow: 0 0 0 1px rgba(0, 0, 0, 0.35), 0 0 0 3px transparent; }
  }

  .nom-backlog {
    font-family: var(--font-display);
    font-weight: 600;
    font-size: 0.88rem;
    color: var(--text);
    margin: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .note-backlog {
    display: flex;
    align-items: center;
    gap: 3px;
    color: var(--accent);
    font-size: 0.75rem;
    margin: 2px 0 0;
  }

  .puces-tags {
    display: flex;
    flex-wrap: wrap;
    gap: 3px;
    margin-top: 4px;
  }
  .puce-tag {
    background: color-mix(in srgb, var(--input) 80%, transparent);
    color: var(--muted);
    font-size: 0.68rem;
    padding: 1px 6px;
    border-radius: 999px;
  }

  .meta-backlog {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
    margin-top: 4px;
  }
  .meta-item {
    display: flex;
    align-items: center;
    gap: 2px;
    color: var(--muted);
    font-size: 0.68rem;
  }
  .meta-item.complet {
    color: var(--success);
  }
</style>
