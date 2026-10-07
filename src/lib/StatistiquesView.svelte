<script lang="ts">
  import { Star, RotateCw, Dices, Clock, Trophy, Lock, LayoutGrid, EyeOff, Eye, X, CalendarDays, Activity, Heart } from "@lucide/svelte";
  import { scale, fade } from "svelte/transition";
  import type { AppConfig, Badges, GameLibrary, Historique, Platform } from "./types";
  import { calculerStats, formaterMinutes, construireHeatmap, construireTimeline } from "./stats";
  import { calculerStatsPourBadges, badgesDebloquables, nouveauxBadges, BADGE_DEFINITIONS, COULEURS_PALIER, LABELS_PALIER, type CategorieBadge, type BadgeDefinition } from "./badges";
  import { api } from "./api";
  import { tr, labelStatut } from "./i18n";

  let {
    platformId,
    platforms,
    library,
    historique,
    badges,
    config,
    onPlatformChange,
    onBadgesChange,
    onConfigChange,
  }: {
    platformId: string | null;
    platforms: Platform[];
    library: GameLibrary | null;
    historique: Historique;
    badges: Badges;
    config: AppConfig;
    onPlatformChange: (id: string) => void;
    onBadgesChange: (b: Badges) => void;
    onConfigChange: (cfg: AppConfig) => void;
  } = $props();

  const stats = $derived(calculerStats(library, historique, platformId ?? ""));
  const nomPlateforme = $derived(platforms.find((p) => p.id === platformId)?.nom ?? "");
  const heatmap = $derived(construireHeatmap(historique, 182));
  const timeline = $derived(construireTimeline(historique, library, 25));

  function formaterDateCourte(iso: string): string {
    return new Intl.DateTimeFormat(config.langue === "en" ? "en-US" : "fr-FR", { day: "numeric", month: "short" }).format(new Date(iso));
  }
  function libelleStatut(id: string): string {
    const statut = config.statuts.find((s) => s.id === id);
    return statut ? labelStatut(config.langue, statut.id, statut.label, statut.integre) : id;
  }

  let sousVue = $state<"stats" | "succes">("stats");
  let chargementSucces = $state(false);
  let afficherMasques = $state(false);
  let badgeAgrandi = $state<BadgeDefinition | null>(null);

  const LABELS_CATEGORIE: Record<CategorieBadge, string> = {
    tirage: "Tirages",
    progression: "Progression",
    collection: "Collection",
    special: "Spécial",
  };

  // Recalculé à chaque ouverture de l'onglet Succès : c'est le seul moment
  // où on charge TOUTES les plateformes (pas seulement celle active) pour
  // que les succès "collection"/"explorateur"/"nomade" soient justes — le
  // reste de l'app n'a jamais besoin de plus d'une bibliothèque en mémoire
  // à la fois.
  async function ouvrirSucces() {
    sousVue = "succes";
    chargementSucces = true;
    try {
      const toutes = await Promise.all(platforms.map((p) => api.loadGames(p.id)));
      const nbStatutsPerso = config.statuts.filter((s) => !s.integre).length;
      const sansAntiRepetition = !config.eviterRepetitions && historique.entrees.length > 0;
      const statsBadges = calculerStatsPourBadges(historique, toutes, nbStatutsPerso, sansAntiRepetition, {
        nbBadgesDebloques: badges.debloquees.length,
        nbThemesEssayes: config.themesEssayes.length,
        aUtiliseTirageMultiple: config.aUtiliseTirageMultiple,
        aUtiliseRouletteRusse: config.aUtiliseRouletteRusse,
        aUtiliseFiltres: config.aUtiliseFiltres,
      });
      const debloquables = badgesDebloquables(statsBadges);
      const nouveaux = nouveauxBadges(debloquables, badges.debloquees.map((b) => b.id));
      if (nouveaux.length > 0) {
        const maintenant = new Date().toISOString();
        onBadgesChange({
          ...badges,
          debloquees: [...badges.debloquees, ...nouveaux.map((id) => ({ id, dateDebloquee: maintenant }))],
        });
      }
    } finally {
      chargementSucces = false;
    }
  }

  function estDebloque(id: string): boolean {
    return badges.debloquees.some((b) => b.id === id);
  }
  function dateDebloque(id: string): string | null {
    return badges.debloquees.find((b) => b.id === id)?.dateDebloquee ?? null;
  }
  function formaterDate(iso: string): string {
    return new Intl.DateTimeFormat(config.langue === "en" ? "en-US" : "fr-FR", { day: "numeric", month: "short", year: "numeric" }).format(new Date(iso));
  }
  function estMasque(id: string): boolean {
    return config.badgesDesactives.includes(id);
  }
  function basculerMasque(id: string, e?: MouseEvent) {
    e?.stopPropagation();
    const masque = estMasque(id);
    onConfigChange({
      ...config,
      badgesDesactives: masque ? config.badgesDesactives.filter((x) => x !== id) : [...config.badgesDesactives, id],
    });
  }
</script>

<section class="statistiques">
  <div class="onglets-sous-vue">
    <button class="sous-onglet" class:active={sousVue === "stats"} onclick={() => (sousVue = "stats")}>
      <LayoutGrid size={15} strokeWidth={2.2} />
      {tr(config.langue, "Statistiques", "Statistics")}
    </button>
    <button class="sous-onglet" class:active={sousVue === "succes"} onclick={ouvrirSucces}>
      <Trophy size={15} strokeWidth={2.2} />
      {tr(config.langue, "Succès", "Achievements")} ({badges.debloquees.length}/{BADGE_DEFINITIONS.length})
    </button>
  </div>

  {#if sousVue === "stats"}
    <div class="chips-plateforme">
      {#each platforms as p}
        <button class="chip-plateforme" class:active={p.id === platformId} onclick={() => onPlatformChange(p.id)}>
          {p.nom}
        </button>
      {/each}
    </div>

    {#if !library || library.jeux.length === 0}
      <div class="vide">
        <p>{config.langue === "en" ? `No games in ${nomPlateforme} yet — statistics will appear once the library has content.` : `Aucun jeu dans ${nomPlateforme} pour l’instant — les statistiques apparaîtront une fois la bibliothèque peuplée.`}</p>
      </div>
    {:else}
      <div class="grille-cartes">
        <div class="carte-stat">
          <div class="carte-entete">
            <Star size={18} strokeWidth={2.2} color="var(--accent)" />
            <p class="carte-titre">{tr(config.langue, "Taux de notation", "Rating coverage")}</p>
          </div>
          <div class="barre-progression">
            <div class="barre-remplie" style="width: {stats.tauxNotationPct}%"></div>
          </div>
          <p class="carte-valeur">{config.langue === "en" ? `${stats.jeuxNotes} / ${stats.totalJeux} games rated (${stats.tauxNotationPct}%)` : `${stats.jeuxNotes} / ${stats.totalJeux} jeux notés (${stats.tauxNotationPct}%)`}</p>
        </div>

        <div class="carte-stat">
          <div class="carte-entete">
            <RotateCw size={18} strokeWidth={2.2} color="var(--success)" />
            <p class="carte-titre">{tr(config.langue, "Cycle en cours", "Current cycle")}</p>
          </div>
          <div class="barre-progression">
            <div class="barre-remplie succes" style="width: {stats.dejaFaitsPct}%"></div>
          </div>
          <p class="carte-valeur">{config.langue === "en" ? `${stats.dejaFaits} / ${stats.totalJeux} games already drawn this cycle (${stats.dejaFaitsPct}%)` : `${stats.dejaFaits} / ${stats.totalJeux} jeux déjà tirés ce cycle (${stats.dejaFaitsPct}%)`}</p>
        </div>

        <div class="carte-stat carte-compacte">
          <div class="carte-entete">
            <Dices size={18} strokeWidth={2.2} color="var(--warning)" />
            <p class="carte-titre">{tr(config.langue, "Tirages", "Draws")}</p>
          </div>
          <p class="grand-nombre">{stats.nombreTirages}</p>
          <p class="carte-sous-titre">{config.langue === "en" ? `${stats.nombreTirages} total draw${stats.nombreTirages > 1 ? "s" : ""} on ${nomPlateforme}` : `${stats.nombreTirages} tirage${stats.nombreTirages > 1 ? "s" : ""} au total sur ${nomPlateforme}`}</p>
        </div>

        <div class="carte-stat carte-compacte">
          <div class="carte-entete">
            <Clock size={18} strokeWidth={2.2} color="var(--danger)" />
            <p class="carte-titre">{tr(config.langue, "Temps d’objectif cumulé", "Cumulative goal time")}</p>
          </div>
          <p class="grand-nombre">{formaterMinutes(stats.minutesCumulees)}</p>
          <p class="carte-sous-titre">{tr(config.langue, "somme des objectifs de session passés (approximatif)", "sum of past session goals (approximate)")}</p>
        </div>
      </div>

      <!-- Heatmap : tous supports confondus (l'historique n'est pas filtré
           par plateforme) — la régularité de tirage est une habitude
           personnelle, pas une donnée par plateforme. -->
      <div class="carte-stat">
        <div class="carte-entete">
          <CalendarDays size={18} strokeWidth={2.2} color="var(--accent)" />
          <p class="carte-titre">{tr(config.langue, "Régularité des tirages (6 derniers mois)", "Draw consistency (last 6 months)")}</p>
        </div>
        <div class="heatmap">
          {#each heatmap as jour (jour.date)}
            <div
              class="case-heatmap"
              data-niveau={jour.niveau}
              title="{jour.date} — {jour.compte} tirage{jour.compte > 1 ? 's' : ''}"
            ></div>
          {/each}
        </div>
        <div class="legende-heatmap">
          <span>{tr(config.langue, "Moins", "Less")}</span>
          {#each [0, 1, 2, 3, 4] as n}
            <div class="case-heatmap" data-niveau={n}></div>
          {/each}
          <span>{tr(config.langue, "Plus", "More")}</span>
        </div>
      </div>

      <!-- Frise des derniers tirages, enrichie du statut actuel. -->
      {#if timeline.length > 0}
        <div class="carte-stat">
          <div class="carte-entete">
            <Activity size={18} strokeWidth={2.2} color="var(--success)" />
            <p class="carte-titre">{tr(config.langue, "Derniers tirages", "Recent draws")}</p>
          </div>
          <div class="timeline">
            {#each timeline as e, i (e.date + i)}
              <div class="ligne-timeline">
                <div class="point-timeline" class:termine={e.statut === "Termine"} class:encours={e.statut === "EnCours"}></div>
                <div class="contenu-timeline">
                  <p class="nom-timeline">
                    {e.nom}
                    {#if e.coupDeCoeur}<Heart size={11} strokeWidth={2.4} color="var(--danger)" />{/if}
                  </p>
                  <p class="meta-timeline">
                    {formaterDateCourte(e.date)}
                    {#if e.statut}· {libelleStatut(e.statut)}{/if}
                    {#if e.note > 0}· {e.note}/5{/if}
                  </p>
                </div>
              </div>
            {/each}
          </div>
        </div>
      {/if}
    {/if}
  {:else}
    <div class="succes-contenu">
      {#if chargementSucces}
        <p class="chargement-succes">{tr(config.langue, "Calcul des succès en cours…", "Calculating achievements…")}</p>
      {/if}
      <label class="ligne-masques">
        <input type="checkbox" bind:checked={afficherMasques} />
        {tr(config.langue, "Afficher les succès masqués", "Show hidden achievements")} ({config.badgesDesactives.length})
      </label>
      {#each ["tirage", "progression", "collection", "special"] as cat}
        {@const defsCategorie = BADGE_DEFINITIONS.filter((b) => b.categorie === cat && (afficherMasques || !estMasque(b.id)))}
        {#if defsCategorie.length > 0}
          <div class="groupe-succes">
            <p class="titre-groupe">{config.langue === "en" ? ({ tirage: "Draws", progression: "Progression", collection: "Collection", special: "Special" } as Record<CategorieBadge, string>)[cat as CategorieBadge] : LABELS_CATEGORIE[cat as CategorieBadge]}</p>
            <div class="grille-badges">
              {#each defsCategorie as def, i}
                {@const debloque = estDebloque(def.id)}
                {@const masque = estMasque(def.id)}
                {@const couleur = def.palier ? COULEURS_PALIER[def.palier] : "var(--accent)"}
                <!-- svelte-ignore a11y_click_events_have_key_events -->
                <div
                  class="carte-badge"
                  class:verrouille={!debloque}
                  class:masque
                  role="button"
                  tabindex="0"
                  onclick={() => (badgeAgrandi = def)}
                  in:scale={{ duration: 220, delay: Math.min(i, 12) * 30, start: 0.85 }}
                >
                  <button class="btn-oeil" onclick={(e) => basculerMasque(def.id, e)} aria-label={masque ? tr(config.langue, "Réafficher", "Show again") : tr(config.langue, "Masquer", "Hide")} title={masque ? tr(config.langue, "Réafficher", "Show again") : tr(config.langue, "Masquer", "Hide")}>
                    {#if masque}<EyeOff size={12} strokeWidth={2.2} />{:else}<Eye size={12} strokeWidth={2.2} />{/if}
                  </button>
                  <div
                    class="icone-badge"
                    class:verrouille={!debloque}
                    style={debloque ? `background: color-mix(in srgb, ${couleur} 22%, transparent); color: ${couleur};` : ""}
                  >
                    {#if debloque}<Trophy size={22} strokeWidth={2} />{:else}<Lock size={18} strokeWidth={2} />{/if}
                  </div>
                  {#if def.palier}
                    <span class="puce-palier" style="background: color-mix(in srgb, {couleur} 25%, transparent); color: {couleur};">
                      {LABELS_PALIER[def.palier]}
                    </span>
                  {/if}
                  <p class="label-badge">{def.label}</p>
                  <p class="description-badge">{def.description}</p>
                  {#if debloque}
                    {@const date = dateDebloque(def.id)}
                    {#if date}<p class="date-badge">{tr(config.langue, "Débloqué le", "Unlocked on")} {formaterDate(date)}</p>{/if}
                  {/if}
                </div>
              {/each}
            </div>
          </div>
        {/if}
      {/each}
    </div>
  {/if}
</section>

{#if badgeAgrandi}
  {@const couleur = badgeAgrandi.palier ? COULEURS_PALIER[badgeAgrandi.palier] : "var(--accent)"}
  {@const debloque = estDebloque(badgeAgrandi.id)}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="fond-agrandi" transition:fade={{ duration: 150 }} onclick={() => (badgeAgrandi = null)}>
    <div class="carte-agrandie" transition:scale={{ duration: 200, start: 0.9 }} onclick={(e) => e.stopPropagation()}>
      <button class="fermer-agrandi" onclick={() => (badgeAgrandi = null)} aria-label={tr(config.langue, "Fermer", "Close")}><X size={18} strokeWidth={2.2} /></button>
      <div
        class="icone-agrandie"
        class:verrouille={!debloque}
        style={debloque ? `background: color-mix(in srgb, ${couleur} 22%, transparent); color: ${couleur};` : ""}
      >
        {#if debloque}<Trophy size={44} strokeWidth={1.8} />{:else}<Lock size={36} strokeWidth={1.8} />{/if}
      </div>
      {#if badgeAgrandi.palier}
        <span class="puce-palier" style="background: color-mix(in srgb, {couleur} 25%, transparent); color: {couleur};">
          {LABELS_PALIER[badgeAgrandi.palier]}
        </span>
      {/if}
      <p class="label-agrandi">{badgeAgrandi.label}</p>
      <p class="description-agrandie">{badgeAgrandi.description}</p>
      {#if debloque}
        {@const date = dateDebloque(badgeAgrandi.id)}
        {#if date}<p class="date-badge">{tr(config.langue, "Débloqué le", "Unlocked on")} {formaterDate(date)}</p>{/if}
      {:else}
        <p class="date-badge">{tr(config.langue, "Pas encore débloqué.", "Not unlocked yet.")}</p>
      {/if}
    </div>
  </div>
{/if}

<style>
  .statistiques {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .onglets-sous-vue {
    display: flex;
    gap: 6px;
  }
  .sous-onglet {
    display: flex;
    align-items: center;
    gap: 6px;
    background: color-mix(in srgb, var(--input) 80%, transparent);
    color: var(--muted);
    border: 1px solid var(--border);
    font-family: var(--font-display);
    font-weight: 600;
    font-size: 0.85rem;
    padding: 6px 14px;
    border-radius: var(--radius-sm);
    cursor: pointer;
    transition: color 0.15s ease, border-color 0.15s ease, background-color 0.15s ease;
  }
  .sous-onglet.active {
    background: color-mix(in srgb, var(--accent) 18%, transparent);
    color: var(--text);
    border-color: var(--accent);
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

  .vide {
    padding: var(--space-4);
    text-align: center;
    color: var(--muted);
    font-size: 0.9rem;
    border-radius: var(--radius);
    border: 1px solid color-mix(in srgb, var(--border) 70%, transparent);
    background: linear-gradient(160deg, color-mix(in srgb, var(--card) 85%, transparent), color-mix(in srgb, var(--card) 55%, transparent));
    box-shadow: 0 6px 18px rgba(0, 0, 0, 0.22);
  }

  .grille-cartes {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(230px, 1fr));
    gap: var(--space-3);
  }

  .carte-stat {
    padding: var(--space-3);
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    border-radius: var(--radius);
    border: 1px solid color-mix(in srgb, var(--border) 70%, transparent);
    background: linear-gradient(160deg, color-mix(in srgb, var(--card) 85%, transparent), color-mix(in srgb, var(--card) 55%, transparent));
    box-shadow: 0 6px 18px rgba(0, 0, 0, 0.22);
  }

  .carte-entete {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .carte-titre {
    font-family: var(--font-display);
    font-weight: 600;
    font-size: 0.9rem;
    color: var(--text);
    margin: 0;
  }

  .barre-progression {
    height: 8px;
    background: var(--input);
    border-radius: 4px;
    overflow: hidden;
  }
  .barre-remplie {
    height: 100%;
    background: linear-gradient(90deg, var(--accent), color-mix(in srgb, var(--accent) 60%, var(--success)));
    transition: width 0.5s var(--spring);
  }
  .barre-remplie.succes {
    background: linear-gradient(90deg, var(--success), color-mix(in srgb, var(--success) 60%, var(--accent)));
  }

  .carte-valeur {
    color: var(--muted);
    font-size: 0.82rem;
    margin: 0;
  }

  .carte-compacte {
    align-items: center;
    text-align: center;
  }
  .grand-nombre {
    font-family: var(--font-display);
    font-weight: 700;
    font-size: 2.2rem;
    color: var(--text);
    margin: 4px 0 0;
    line-height: 1;
  }
  .carte-sous-titre {
    color: var(--muted);
    font-size: 0.78rem;
    margin: 0;
  }

  /* Heatmap façon "contributions" — grille en colonnes de 7 (une semaine
     par colonne), remplie de haut en bas puis de gauche à droite. */
  .heatmap {
    display: grid;
    grid-template-rows: repeat(7, 1fr);
    grid-auto-flow: column;
    grid-auto-columns: 1fr;
    gap: 3px;
    width: 100%;
  }
  .case-heatmap {
    aspect-ratio: 1;
    border-radius: 2px;
    background: color-mix(in srgb, var(--input) 85%, transparent);
    border: 1px solid color-mix(in srgb, var(--border) 40%, transparent);
  }
  .case-heatmap[data-niveau="1"] { background: color-mix(in srgb, var(--accent) 25%, transparent); }
  .case-heatmap[data-niveau="2"] { background: color-mix(in srgb, var(--accent) 45%, transparent); }
  .case-heatmap[data-niveau="3"] { background: color-mix(in srgb, var(--accent) 70%, transparent); }
  .case-heatmap[data-niveau="4"] { background: var(--accent); }

  .legende-heatmap {
    display: flex;
    align-items: center;
    gap: 4px;
    justify-content: flex-end;
    color: var(--muted);
    font-size: 0.68rem;
    margin-top: 6px;
  }
  .legende-heatmap .case-heatmap {
    width: 10px;
    height: 10px;
    aspect-ratio: auto;
  }

  /* Frise des derniers tirages. */
  .timeline {
    display: flex;
    flex-direction: column;
    gap: 0;
    max-height: 320px;
    overflow-y: auto;
  }
  .ligne-timeline {
    display: flex;
    gap: 10px;
    padding: 5px 0;
    position: relative;
  }
  /* Trait vertical reliant les points, sauf après le dernier. */
  .ligne-timeline:not(:last-child)::before {
    content: "";
    position: absolute;
    left: 4px;
    top: 16px;
    bottom: -5px;
    width: 1px;
    background: color-mix(in srgb, var(--border) 60%, transparent);
  }
  .point-timeline {
    width: 9px;
    height: 9px;
    border-radius: 50%;
    background: var(--muted);
    margin-top: 5px;
    flex-shrink: 0;
    z-index: 1;
  }
  .point-timeline.termine { background: var(--success); }
  .point-timeline.encours { background: var(--accent); }
  .contenu-timeline {
    min-width: 0;
  }
  .nom-timeline {
    display: flex;
    align-items: center;
    gap: 5px;
    font-family: var(--font-display);
    font-weight: 600;
    font-size: 0.84rem;
    color: var(--text);
    margin: 0;
  }
  .meta-timeline {
    color: var(--muted);
    font-size: 0.72rem;
    margin: 1px 0 0;
  }

  .succes-contenu {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
  }
  .chargement-succes {
    color: var(--muted);
    font-size: 0.85rem;
    text-align: center;
  }
  .titre-groupe {
    font-family: var(--font-display);
    font-weight: 700;
    font-size: 0.82rem;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--muted);
    margin: 0 0 8px;
  }
  .ligne-masques {
    display: flex;
    align-items: center;
    gap: 6px;
    color: var(--muted);
    font-size: 0.8rem;
    cursor: pointer;
  }
  .grille-badges {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
    gap: var(--space-2);
  }
  .carte-badge {
    position: relative;
    padding: var(--space-2);
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
    gap: 4px;
    transition: opacity 0.2s ease, transform 0.15s ease;
    border-radius: var(--radius);
    border: 1px solid color-mix(in srgb, var(--border) 70%, transparent);
    background: linear-gradient(160deg, color-mix(in srgb, var(--card) 85%, transparent), color-mix(in srgb, var(--card) 55%, transparent));
    box-shadow: 0 6px 18px rgba(0, 0, 0, 0.22);
    font-family: inherit;
    cursor: pointer;
    width: 100%;
  }
  .carte-badge:hover {
    transform: translateY(-2px);
  }
  .carte-badge.verrouille {
    opacity: 0.5;
  }
  .carte-badge.masque {
    opacity: 0.35;
  }
  .btn-oeil {
    position: absolute;
    top: 6px;
    right: 6px;
    background: color-mix(in srgb, var(--darkbg) 60%, transparent);
    border: none;
    border-radius: 50%;
    width: 20px;
    height: 20px;
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--muted);
    cursor: pointer;
    opacity: 0;
    transition: opacity 0.15s ease, color 0.15s ease;
  }
  .carte-badge:hover .btn-oeil {
    opacity: 1;
  }
  .btn-oeil:hover {
    color: var(--text);
  }
  .icone-badge {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    background: color-mix(in srgb, var(--accent) 20%, transparent);
    color: var(--accent);
    margin-bottom: 2px;
  }
  .icone-badge.verrouille {
    background: color-mix(in srgb, var(--muted) 15%, transparent);
    color: var(--muted);
  }
  .puce-palier {
    font-family: var(--font-display);
    font-weight: 700;
    font-size: 0.62rem;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    padding: 2px 8px;
    border-radius: 999px;
  }
  .label-badge {
    font-family: var(--font-display);
    font-weight: 600;
    font-size: 0.82rem;
    color: var(--text);
    margin: 0;
  }
  .description-badge {
    color: var(--muted);
    font-size: 0.72rem;
    margin: 0;
  }
  .date-badge {
    color: var(--accent);
    font-size: 0.68rem;
    margin: 2px 0 0;
  }

  .fond-agrandi {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.6);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 55;
    padding: var(--space-4);
  }
  .carte-agrandie {
    position: relative;
    max-width: 320px;
    width: 100%;
    padding: var(--space-5) var(--space-4);
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
    gap: 8px;
    border-radius: var(--radius);
    border: 1px solid color-mix(in srgb, var(--border) 70%, transparent);
    background: linear-gradient(160deg, color-mix(in srgb, var(--card) 92%, transparent), color-mix(in srgb, var(--card) 65%, transparent));
    box-shadow: 0 20px 50px rgba(0, 0, 0, 0.4);
  }
  .fermer-agrandi {
    position: absolute;
    top: 10px;
    right: 10px;
    background: transparent;
    border: none;
    color: var(--muted);
    cursor: pointer;
    padding: 4px;
  }
  .fermer-agrandi:hover {
    color: var(--text);
  }
  .icone-agrandie {
    width: 84px;
    height: 84px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    background: color-mix(in srgb, var(--accent) 20%, transparent);
    color: var(--accent);
    margin-bottom: 4px;
  }
  .icone-agrandie.verrouille {
    background: color-mix(in srgb, var(--muted) 15%, transparent);
    color: var(--muted);
  }
  .label-agrandi {
    font-family: var(--font-display);
    font-weight: 700;
    font-size: 1.15rem;
    color: var(--text);
    margin: 4px 0 0;
  }
  .description-agrandie {
    color: var(--muted);
    font-size: 0.88rem;
    margin: 0;
    line-height: 1.4;
  }
</style>
