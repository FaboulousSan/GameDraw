<script lang="ts">
  import { Trash2, X, FolderOpen, Search, Loader2, Heart, Plus, ListChecks, SquareCheck, Square, Award, ExternalLink, Pencil, Check, Download } from "@lucide/svelte";
  import { scale, fade, fly } from "svelte/transition";
  import { open } from "@tauri-apps/plugin-dialog";
  import { WebviewWindow } from "@tauri-apps/api/webviewWindow";
  import { convertFileSrc } from "@tauri-apps/api/core";
  import { api, type RawgGame } from "./api";
  import type { AppConfig, Game, StatutJeu } from "./types";
  import { ICONE_NOTATION_COMPOSANTS, ICONE_NOTATION_LABELS, ICONE_NOTATION_ORDER } from "./icones-notation";
  import { tr, labelStatut } from "./i18n";

  let {
    game,
    platformId,
    config,
    confirmer,
    onSave,
    onDelete,
    onClose,
    onConfigChange,
  }: {
    game: Game;
    platformId: string;
    config: AppConfig;
    confirmer: (message: string) => Promise<boolean>;
    onSave: (patch: Partial<Game>) => void;
    onDelete: () => void;
    onClose: () => void;
    onConfigChange: (cfg: AppConfig) => void;
  } = $props();

  const IconeNote = $derived(ICONE_NOTATION_COMPOSANTS[config.iconeNotation]);

  // Fiche "statique" par défaut (consultation) — les outils de recherche de
  // jaquette (RAWG/Steam/SteamGridDB, choisir un fichier) et les champs
  // texte libres ne s'affichent qu'en mode édition, pour une vue plus
  // légère au quotidien. Statut/note/marqueurs/défis restent interactifs
  // dans les deux modes : ce sont des bascules rapides, pas de l'édition.
  let mode = $state<"consultation" | "edition">("consultation");

  // svelte-ignore state_referenced_locally -- intentionnel : valeur de
  // départ pratique (nom du jeu), l'utilisateur doit ensuite pouvoir taper
  // sa propre recherche sans qu'elle soit réécrasée si `game` se met à jour.
  let rechercheRawg = $state(game.nom);
  type SourceCover = "rawg" | "steam" | "steamgriddb";

  const SOURCES_INFO: Record<SourceCover, { label: string; aideFr: string; aideEn: string; needsKey: boolean }> = {
    steam: { label: "Steam", aideFr: "Jeux Steam/PC uniquement, aucune clé requise.", aideEn: "Steam/PC games only, no API key required.", needsKey: false },
    rawg: { label: "RAWG", aideFr: "Toutes plateformes, clé API requise.", aideEn: "All platforms, API key required.", needsKey: true },
    steamgriddb: { label: "SteamGridDB", aideFr: "Toutes plateformes, clé API requise.", aideEn: "All platforms, API key required.", needsKey: true },
  };

  // Seules les sources activées dans Options > Connexion sont proposées ici.
  const sourcesDisponibles = $derived(
    (Object.keys(SOURCES_INFO) as SourceCover[]).filter((s) => config.sourcesCoverActives[s])
  );

  function aUneCle(s: SourceCover): boolean {
    if (s === "rawg") return !!config.rawgApiKey.trim();
    if (s === "steamgriddb") return !!config.steamgriddbApiKey.trim();
    return true;
  }

  // Steam (sans clé) toujours disponible ; RAWG/SteamGridDB seulement si une
  // clé est renseignée — sert de défaut le plus utile selon ce qui est déjà
  // prêt et activé.
  // svelte-ignore state_referenced_locally -- valeur de départ pratique,
  // l'utilisateur peut ensuite changer de source manuellement sans qu'elle
  // soit réécrasée.
  let sourceCover = $state<SourceCover>(
    sourcesDisponibles.find((s) => aUneCle(s)) ?? sourcesDisponibles[0] ?? "steam"
  );
  let resultatsRawg = $state<RawgGame[] | null>(null);
  let rawgEnCours = $state(false);
  let telechargementEnCours = $state(false);
  let erreurRawg = $state<string | null>(null);
  let pulseNote = $state(false);
  let pulseTimeout: ReturnType<typeof setTimeout> | null = null;
  let nouveauDefi = $state("");
  let urlCollee = $state("");

  const coverSrc = $derived(game.cover ? convertFileSrc(game.cover) : null);

  function majStatut(statut: StatutJeu) {
    onSave({ statut });
  }
  function majNote(note: number) {
    onSave({ note: note === game.note ? 0 : note }); // re-cliquer sur la même étoile efface la note
    pulseNote = false;
    if (pulseTimeout) clearTimeout(pulseTimeout);
    requestAnimationFrame(() => (pulseNote = true));
    pulseTimeout = setTimeout(() => (pulseNote = false), 300);
  }

  function ajouterDefiLocal() {
    const texte = nouveauDefi.trim();
    if (!texte) return;
    onSave({ defis: [...game.defis, { id: crypto.randomUUID(), texte, complete: false }] });
    nouveauDefi = "";
  }
  function basculerDefiLocal(defiId: string) {
    onSave({ defis: game.defis.map((d) => (d.id === defiId ? { ...d, complete: !d.complete } : d)) });
  }
  function supprimerDefiLocal(defiId: string) {
    onSave({ defis: game.defis.filter((d) => d.id !== defiId) });
  }

  async function choisirFichierLocal() {
    const selection = await open({
      multiple: false,
      filters: [{ name: "Images", extensions: ["jpg", "jpeg", "png", "webp"] }],
    });
    if (!selection || Array.isArray(selection)) return;
    try {
      const chemin = await api.saveLocalCover(platformId, game.id, selection);
      onSave({ cover: chemin });
    } catch (e) {
      erreurRawg = String(e);
    }
  }

  // Fenêtre Tauri intégrée (pas le navigateur externe) sur la recherche
  // SteamGridDB — reste "dans" l'app visuellement. Pas d'intégration
  // automatique du clic sur une image (nécessiterait d'injecter du script
  // dans une page tierce : fragile, casse à la moindre mise à jour de leur
  // site) — après téléchargement, l'image se sélectionne via "Choisir un
  // fichier" juste à côté, comme le script PowerShell d'origine.
  async function ouvrirFenetreSteamGridDB() {
    const requete = encodeURIComponent(game.nom);
    new WebviewWindow(`sgdb-${game.id}`, {
      url: `https://www.steamgriddb.com/search/grids?term=${requete}`,
      title: `SteamGridDB — ${game.nom}`,
      width: 1000,
      height: 720,
    });
  }

  // Coller directement l'URL d'une image trouvée sur le web (clic droit sur
  // l'image → « Copier l'adresse de l'image »). Évite l'aller-retour
  // télécharger-puis-resélectionner, qui était le vrai point de friction de
  // la recherche via fenêtre intégrée.
  async function utiliserUrlCollee() {
    const url = urlCollee.trim();
    if (!url) return;
    if (!/^https?:\/\//i.test(url)) {
      erreurRawg = tr(config.langue, "L’adresse doit commencer par http:// ou https://", "The address must start with http:// or https://");
      return;
    }
    telechargementEnCours = true;
    erreurRawg = null;
    try {
      const chemin = await api.downloadCover(platformId, game.id, url);
      onSave({ cover: chemin });
      urlCollee = "";
    } catch (e) {
      erreurRawg = `${tr(config.langue, "Téléchargement impossible", "Download failed")} : ${e}`;
    } finally {
      telechargementEnCours = false;
    }
  }

  async function rechercherCouverture() {
    if (!rechercheRawg.trim()) return;
    if (SOURCES_INFO[sourceCover].needsKey && !aUneCle(sourceCover)) return;
    rawgEnCours = true;
    erreurRawg = null;
    resultatsRawg = null;
    try {
      if (sourceCover === "rawg") {
        resultatsRawg = await api.rawgSearch(config.rawgApiKey, rechercheRawg);
      } else if (sourceCover === "steamgriddb") {
        resultatsRawg = await api.steamgriddbSearch(config.steamgriddbApiKey, rechercheRawg);
      } else {
        resultatsRawg = await api.steamStoreSearch(rechercheRawg);
      }
    } catch (e) {
      erreurRawg = String(e);
    } finally {
      rawgEnCours = false;
    }
  }

  async function utiliserResultat(resultat: RawgGame) {
    if (!resultat.coverUrl) return;
    telechargementEnCours = true;
    erreurRawg = null;
    try {
      const chemin = await api.downloadCover(platformId, game.id, resultat.coverUrl);
      onSave({ cover: chemin });
      resultatsRawg = null;
    } catch (e) {
      erreurRawg = String(e);
    } finally {
      telechargementEnCours = false;
    }
  }

  async function supprimer() {
    const confirme = await confirmer(config.langue === "en" ? `Delete “${game.nom}” from the library?` : `Supprimer « ${game.nom} » de la bibliothèque ?`);
    if (confirme) onDelete();
  }

  function onKeydown(e: KeyboardEvent) {
    if (e.key === "Escape") onClose();
  }
</script>

<svelte:window onkeydown={onKeydown} />

<!-- svelte-ignore a11y_click_events_have_key_events -- clic-dehors pour
     fermer est un bonus souris ; le clavier est déjà couvert par Échap et
     par le bouton de fermeture explicite. -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="backdrop" transition:fade={{ duration: 120 }} onclick={onClose}>
  <div class="fiche glass" transition:scale={{ duration: 160, start: 0.96 }} onclick={(e) => e.stopPropagation()} role="dialog" aria-modal="true" tabindex="-1">
    <button class="fermer" onclick={onClose} aria-label={tr(config.langue, "Fermer", "Close")}><X size={18} strokeWidth={2.2} /></button>
    <button
      class="crayon"
      onclick={() => (mode = mode === "consultation" ? "edition" : "consultation")}
      aria-label={mode === "consultation" ? tr(config.langue, "Modifier", "Edit") : tr(config.langue, "Terminer la modification", "Finish editing")}
      title={mode === "consultation" ? tr(config.langue, "Modifier", "Edit") : tr(config.langue, "Terminer la modification", "Finish editing")}
    >
      {#if mode === "consultation"}<Pencil size={16} strokeWidth={2.2} />{:else}<Check size={16} strokeWidth={2.2} />{/if}
    </button>

    <div class="colonnes">
      <div class="colonne-cover" in:fly={{ x: -16, duration: 240, delay: 40 }}>
        <div class="cover-cadre">
          {#if coverSrc}
            <img src={coverSrc} alt={game.nom} />
          {:else}
            <div class="cover-placeholder">{game.nom.slice(0, 1).toUpperCase()}</div>
          {/if}
        </div>
        {#if mode === "edition"}
        <button class="action-cover" onclick={choisirFichierLocal}>
          <FolderOpen size={15} strokeWidth={2.2} />
          {tr(config.langue, "Choisir un fichier", "Choose a file")}
        </button>
        <button class="action-cover secondaire" onclick={ouvrirFenetreSteamGridDB}>
          <ExternalLink size={15} strokeWidth={2.2} />
          {tr(config.langue, "Chercher sur SteamGridDB", "Search on SteamGridDB")}
        </button>
        <p class="aide-source">
          {tr(config.langue, "Ouvre une fenêtre dans l’app. Trouve une image, copie l’adresse de l’image avec le clic droit, puis colle-la ci-dessous : elle sera téléchargée et appliquée directement.", "Opens a window in the app. Find an image, right-click to copy its image address, then paste it below: it will be downloaded and applied directly.")}
        </p>
        <div class="coller-url">
          <input
            type="text"
            placeholder={tr(config.langue, "Coller l’adresse d’une image…", "Paste an image address…")}
            bind:value={urlCollee}
            onkeydown={(e) => e.key === "Enter" && utiliserUrlCollee()}
          />
          <button class="action-cover" onclick={utiliserUrlCollee} disabled={!urlCollee.trim() || telechargementEnCours}>
            {#if telechargementEnCours}<Loader2 size={15} strokeWidth={2.2} class="spin" />{:else}<Download size={15} strokeWidth={2.2} />{/if}
            {tr(config.langue, "Appliquer", "Apply")}
          </button>
        </div>

        {#if sourcesDisponibles.length === 0}
          <p class="renvoi-options">
            {tr(config.langue, "Toutes les sources de jaquette sont désactivées — réactive-en au moins une dans Options → Connexion.", "All cover sources are disabled — enable at least one in Options → Connections.")}
          </p>
        {:else}
          <div class="choix-source">
            {#each sourcesDisponibles as s}
              <button class="source-btn" class:active={sourceCover === s} onclick={() => { sourceCover = s; resultatsRawg = null; }}>
                {SOURCES_INFO[s].label}
              </button>
            {/each}
          </div>
          <p class="aide-source">{config.langue === "en" ? SOURCES_INFO[sourceCover].aideEn : SOURCES_INFO[sourceCover].aideFr}</p>

          {#if SOURCES_INFO[sourceCover].needsKey && !aUneCle(sourceCover)}
            <p class="renvoi-options">
              {tr(config.langue, `Renseigne la clé API ${SOURCES_INFO[sourceCover].label} dans Options → Connexion, ou choisis une autre source ci-dessus (aucune clé requise pour Steam).`, `Enter the ${SOURCES_INFO[sourceCover].label} API key in Options → Connections, or choose another source above (Steam requires no key).`)}
            </p>
          {:else}
            <div class="recherche-rawg">
              <input type="text" placeholder={tr(config.langue, "Nom à rechercher", "Name to search")} bind:value={rechercheRawg} onkeydown={(e) => e.key === "Enter" && rechercherCouverture()} />
              <button class="action-cover" onclick={rechercherCouverture} disabled={rawgEnCours}>
                {#if rawgEnCours}<Loader2 size={15} strokeWidth={2.2} class="spin" />{:else}<Search size={15} strokeWidth={2.2} />{/if}
                {tr(config.langue, "Rechercher", "Search")}
              </button>
            {#if resultatsRawg}
              <div class="resultats-rawg">
                {#each resultatsRawg as r (r.id)}
                  <button class="resultat" onclick={() => utiliserResultat(r)} disabled={!r.coverUrl || telechargementEnCours}>
                    {#if r.coverUrl}<img src={r.coverUrl} alt={r.nom} />{/if}
                    <span>{r.nom}</span>
                  </button>
                {/each}
                {#if resultatsRawg.length === 0}
                  <p class="placeholder-txt">{tr(config.langue, "Aucun résultat.", "No results.")}</p>
                {/if}
              </div>
            {/if}
          </div>
        {/if}
        {/if}
        {#if erreurRawg}<p class="erreur-rawg">{erreurRawg}</p>{/if}
        {/if}
      </div>

      <div class="colonne-info" in:fly={{ x: 16, duration: 240, delay: 80 }}>
        <h2>{game.nom}</h2>

        <p class="eyebrow">{tr(config.langue, "Statut", "Status")}</p>
        <div class="badges">
          {#each config.statuts.filter((s) => s.visible || s.id === game.statut) as s}
            <button
              class="badge"
              class:active={game.statut === s.id}
              style={game.statut === s.id ? `background: ${s.couleur}; border-color: ${s.couleur};` : ""}
              onclick={() => majStatut(s.id)}
            >
              {labelStatut(config.langue, s.id, s.label, s.integre)}
            </button>
          {/each}
        </div>

        <div class="ligne-note-eyebrow">
          <p class="eyebrow">{tr(config.langue, "Note", "Rating")}</p>
          <div class="choix-icone">
            {#each ICONE_NOTATION_ORDER as ic}
              {@const Comp = ICONE_NOTATION_COMPOSANTS[ic]}
              <button
                class="swatch-icone"
                class:actif={config.iconeNotation === ic}
                onclick={() => onConfigChange({ ...config, iconeNotation: ic })}
                title={ICONE_NOTATION_LABELS[ic]}
                aria-label="Icône {ICONE_NOTATION_LABELS[ic]}"
              >
                <Comp size={13} strokeWidth={2.2} />
              </button>
            {/each}
          </div>
        </div>
        <div class="etoiles" class:pulse={pulseNote}>
          {#each [1, 2, 3, 4, 5] as n}
            <button class="etoile" onclick={() => majNote(n)} aria-label="{n} {ICONE_NOTATION_LABELS[config.iconeNotation]}">
              <IconeNote size={20} strokeWidth={2} fill={n <= game.note ? "var(--accent)" : "none"} color="var(--accent)" />
            </button>
          {/each}
        </div>

        <div class="marqueurs-coeur">
          <button
            class="marqueur-coeur"
            class:actif={game.envieDeFaire}
            onclick={() => onSave({ envieDeFaire: !game.envieDeFaire })}
          >
            <Heart size={16} strokeWidth={2.2} fill={game.envieDeFaire ? "var(--accent)" : "none"} color="var(--accent)" />
            {tr(config.langue, "Envie de faire", "Want to play")}
          </button>
          <button
            class="marqueur-coeur coup-de-coeur"
            class:actif={game.coupDeCoeur}
            onclick={() => onSave({ coupDeCoeur: !game.coupDeCoeur })}
          >
            <Heart size={16} strokeWidth={2.2} fill={game.coupDeCoeur ? "var(--danger)" : "none"} color="var(--danger)" />
            {tr(config.langue, "Coup de cœur", "Favorite")}
          </button>
          <button
            class="marqueur-coeur complete-100"
            class:actif={game.complete100}
            onclick={() => onSave({ complete100: !game.complete100 })}
          >
            <Award size={16} strokeWidth={2.2} fill={game.complete100 ? "#EAB308" : "none"} color="#EAB308" />
            100%
          </button>
        </div>

        <p class="eyebrow eyebrow-icone">
          <ListChecks size={13} strokeWidth={2.2} />
          {tr(config.langue, "Défis", "Challenges")} {#if game.defis.length > 0}({game.defis.filter((d) => d.complete).length}/{game.defis.length}){/if}
        </p>
        {#if game.defis.length > 0}
          <div class="liste-defis">
            {#each game.defis as defi (defi.id)}
              <div class="ligne-defi">
                <button class="case-defi" onclick={() => basculerDefiLocal(defi.id)} aria-label="Basculer le défi">
                  {#if defi.complete}<SquareCheck size={16} strokeWidth={2.2} color="var(--success)" />{:else}<Square size={16} strokeWidth={2} color="var(--muted)" />{/if}
                </button>
                <span class="texte-defi" class:fait={defi.complete}>{defi.texte}</span>
                <button class="retirer-defi" onclick={() => supprimerDefiLocal(defi.id)} aria-label="Supprimer le défi">
                  <X size={13} strokeWidth={2.2} />
                </button>
              </div>
            {/each}
          </div>
        {/if}
        <div class="ajout-defi">
          <input
            type="text"
            placeholder={tr(config.langue, "Nouveau défi (ex. Terminer en difficile)", "New challenge (e.g. Finish on hard)")}
            bind:value={nouveauDefi}
            onkeydown={(e) => e.key === "Enter" && ajouterDefiLocal()}
          />
          <button class="btn-ajout-defi" onclick={ajouterDefiLocal} disabled={!nouveauDefi.trim()} aria-label="Ajouter le défi">
            <Plus size={16} strokeWidth={2.2} />
          </button>
        </div>

        {#if mode === "edition"}
          <label class="champ">
            <span class="eyebrow">{tr(config.langue, "Temps de jeu (heures, saisi manuellement)", "Play time (hours, entered manually)")}</span>
            <input
              type="number"
              min="0"
              step="0.5"
              value={game.heuresJouees ?? ""}
              onchange={(e) => onSave({ heuresJouees: e.currentTarget.value ? Number(e.currentTarget.value) : null })}
            />
          </label>

          <label class="champ">
            <span class="eyebrow">{tr(config.langue, "Tags (séparés par virgule)", "Tags (comma-separated)")}</span>
            <input type="text" value={game.tags} onchange={(e) => onSave({ tags: e.currentTarget.value })} />
          </label>

          <label class="champ">
            <span class="eyebrow">{tr(config.langue, "Description", "Description")}</span>
            <textarea rows="2" value={game.description} onchange={(e) => onSave({ description: e.currentTarget.value })}></textarea>
          </label>

          <label class="champ">
            <span class="eyebrow">{tr(config.langue, "Commentaire personnel", "Personal comment")}</span>
            <textarea rows="2" value={game.commentaire} onchange={(e) => onSave({ commentaire: e.currentTarget.value })}></textarea>
          </label>

          {#if game.statut === "Termine" || game.statut === "Abandonne"}
            <label class="champ">
              <span class="eyebrow">{tr(config.langue, "Type de fin", "Completion type")}</span>
              <select value={game.typeFin} onchange={(e) => onSave({ typeFin: e.currentTarget.value })}>
                <option value="">—</option>
                <option value="100%">100%</option>
                <option value="Histoire principale">{tr(config.langue, "Histoire principale", "Main story")}</option>
                <option value="Abandonné en cours">{tr(config.langue, "Abandonné en cours", "Abandoned")}</option>
                <option value="Autre">{tr(config.langue, "Autre", "Other")}</option>
              </select>
            </label>
          {/if}

          <button class="supprimer" onclick={supprimer}>
            <Trash2 size={15} strokeWidth={2.2} />
            {tr(config.langue, "Supprimer le jeu", "Delete game")}
          </button>
        {:else}
          {#if game.heuresJouees}
            <div class="champ">
              <span class="eyebrow">{tr(config.langue, "Temps de jeu", "Play time")}</span>
              <p class="valeur-lecture">{game.heuresJouees} h</p>
            </div>
          {/if}
          {#if game.tags.trim()}
            <div class="champ">
              <span class="eyebrow">Tags</span>
              <p class="valeur-lecture">{game.tags}</p>
            </div>
          {/if}
          {#if game.description.trim()}
            <div class="champ">
              <span class="eyebrow">{tr(config.langue, "Description", "Description")}</span>
              <p class="valeur-lecture">{game.description}</p>
            </div>
          {/if}
          {#if game.commentaire.trim()}
            <div class="champ">
              <span class="eyebrow">{tr(config.langue, "Commentaire personnel", "Personal comment")}</span>
              <p class="valeur-lecture">{game.commentaire}</p>
            </div>
          {/if}
          {#if game.typeFin.trim()}
            <div class="champ">
              <span class="eyebrow">{tr(config.langue, "Type de fin", "Completion type")}</span>
              <p class="valeur-lecture">{game.typeFin}</p>
            </div>
          {/if}
        {/if}
      </div>
    </div>
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
    border: none;
    width: 100%;
    cursor: default;
  }

  .fiche {
    position: relative;
    max-width: 920px;
    width: 100%;
    max-height: 92vh;
    overflow-y: auto;
    padding: var(--space-4);
    animation: fiche-glow 0.6s ease-out;
  }
  @keyframes fiche-glow {
    0% { box-shadow: 0 0 0 0 color-mix(in srgb, var(--glow) 60%, transparent); }
    40% { box-shadow: 0 0 40px 6px color-mix(in srgb, var(--glow) 45%, transparent); }
    100% { box-shadow: 0 8px 30px rgba(0, 0, 0, 0.22); }
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
    z-index: 2;
  }
  .fermer:hover {
    background: color-mix(in srgb, var(--input) 80%, transparent);
  }
  .crayon {
    position: absolute;
    top: var(--space-2);
    right: calc(var(--space-2) + 30px);
    background: color-mix(in srgb, var(--accent) 15%, transparent);
    border: 1px solid color-mix(in srgb, var(--accent) 40%, transparent);
    color: var(--accent);
    cursor: pointer;
    padding: 4px;
    border-radius: 6px;
    z-index: 2;
    display: flex;
    transition: background-color 0.15s ease;
  }
  .crayon:hover {
    background: color-mix(in srgb, var(--accent) 25%, transparent);
  }
  .valeur-lecture {
    color: var(--text);
    font-size: 0.85rem;
    margin: 0;
    line-height: 1.4;
    white-space: pre-wrap;
  }

  .colonnes {
    display: grid;
    grid-template-columns: 1fr;
    gap: var(--space-4);
  }
  @media (min-width: 520px) {
    .colonnes {
      grid-template-columns: 180px 1fr;
    }
  }

  .colonne-cover {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .cover-cadre {
    width: 100%;
    aspect-ratio: 3 / 4;
    border-radius: var(--radius-sm);
    overflow: hidden;
    background: var(--input);
    box-shadow: 0 8px 20px rgba(0, 0, 0, 0.35);
  }
  .cover-cadre img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    object-position: top center;
    transition: transform 0.35s ease;
  }
  .cover-cadre:hover img {
    transform: scale(1.07);
  }
  .cover-placeholder {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-family: var(--font-display);
    font-size: 2.5rem;
    font-weight: 700;
    color: var(--muted);
  }

  .coller-url {
    display: flex;
    gap: 5px;
    margin-top: 6px;
  }
  .coller-url input {
    flex: 1;
    min-width: 0;
  }

  .choix-source {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
    margin-top: 6px;
  }
  .aide-source {
    color: var(--muted);
    font-size: 0.72rem;
    margin: 2px 0 0;
  }
  .source-btn {
    flex: 1;
    background: color-mix(in srgb, var(--input) 85%, transparent);
    color: var(--muted);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 5px 8px;
    font-family: var(--font-body);
    font-size: 0.76rem;
    cursor: pointer;
    transition: color 0.15s ease, border-color 0.15s ease, background-color 0.15s ease;
  }
  .source-btn.active {
    background: color-mix(in srgb, var(--accent) 18%, transparent);
    color: var(--text);
    border-color: var(--accent);
  }

  .action-cover {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    background: color-mix(in srgb, var(--input) 85%, transparent);
    color: var(--text);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: var(--space-1) var(--space-2);
    font-family: var(--font-body);
    font-size: 0.8rem;
    cursor: pointer;
    width: 100%;
  }
  .action-cover.secondaire {
    background: transparent;
    color: var(--muted);
  }
  .action-cover:hover {
    background: color-mix(in srgb, var(--accent) 20%, var(--input));
  }
  .action-cover:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .renvoi-options {
    color: var(--muted);
    font-size: 0.78rem;
    margin: 4px 0 0;
  }
  .recherche-rawg {
    display: flex;
    flex-direction: column;
    gap: 6px;
    margin-top: 4px;
  }

  input[type="text"],
  input[type="number"],
  textarea,
  select {
    background: color-mix(in srgb, var(--input) 90%, transparent);
    color: var(--text);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 6px 8px;
    font-family: var(--font-body);
    font-size: 0.85rem;
    width: 100%;
    resize: vertical;
  }

  .resultats-rawg {
    display: flex;
    flex-direction: column;
    gap: 4px;
    max-height: 180px;
    overflow-y: auto;
  }
  .resultat {
    display: flex;
    align-items: center;
    gap: 8px;
    background: transparent;
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 4px;
    cursor: pointer;
    text-align: left;
    color: var(--text);
    font-size: 0.78rem;
  }
  .resultat:hover:not(:disabled) {
    background: color-mix(in srgb, var(--accent) 15%, transparent);
  }
  .resultat img {
    width: 32px;
    height: 32px;
    object-fit: cover;
    border-radius: 4px;
    flex-shrink: 0;
  }
  .placeholder-txt {
    color: var(--muted);
    font-size: 0.8rem;
    margin: 0;
  }

  .erreur-rawg {
    color: var(--danger);
    font-size: 0.78rem;
    margin: 0;
  }

  .colonne-info {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  h2 {
    font-family: var(--font-display);
    font-size: 1.4rem;
    font-weight: 700;
    margin: 0 var(--space-4) 0 0;
    color: var(--text);
  }

  .badges {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }
  .badge {
    background: color-mix(in srgb, var(--input) 85%, transparent);
    color: var(--muted);
    border: 1px solid var(--border);
    border-radius: 999px;
    padding: 4px 10px;
    font-size: 0.78rem;
    font-family: var(--font-display);
    font-weight: 600;
    cursor: pointer;
    transition: transform 0.15s var(--spring), background-color 0.2s ease, box-shadow 0.2s ease;
  }
  .badge:hover {
    transform: translateY(-1px);
  }
  .badge.active {
    background: var(--accent);
    color: var(--darkbg);
    border-color: var(--accent);
    box-shadow: 0 3px 12px color-mix(in srgb, var(--accent) 45%, transparent);
    animation: badge-pop 0.3s var(--spring);
  }
  @keyframes badge-pop {
    0% { transform: scale(0.85); }
    60% { transform: scale(1.08); }
    100% { transform: scale(1); }
  }

  .marqueurs-coeur {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
  }
  .marqueur-coeur {
    display: flex;
    align-items: center;
    gap: 5px;
    background: color-mix(in srgb, var(--input) 85%, transparent);
    color: var(--muted);
    border: 1px solid var(--border);
    border-radius: 999px;
    padding: 5px 12px;
    font-family: var(--font-body);
    font-size: 0.8rem;
    cursor: pointer;
    transition: transform 0.15s var(--spring), border-color 0.2s ease, color 0.2s ease;
  }
  .marqueur-coeur:hover {
    transform: translateY(-1px);
  }
  .marqueur-coeur.actif {
    color: var(--text);
    border-color: var(--accent);
  }
  .marqueur-coeur.coup-de-coeur.actif {
    border-color: var(--danger);
    animation: coeur-pop 0.3s var(--spring);
  }
  .marqueur-coeur.complete-100.actif {
    border-color: #EAB308;
    animation: coeur-pop 0.3s var(--spring);
  }
  @keyframes coeur-pop {
    0% { transform: scale(0.85); }
    60% { transform: scale(1.12); }
    100% { transform: scale(1); }
  }

  .ligne-note-eyebrow {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .choix-icone {
    display: flex;
    gap: 2px;
  }
  .swatch-icone {
    background: transparent;
    border: 1px solid transparent;
    border-radius: 6px;
    color: var(--muted);
    cursor: pointer;
    padding: 3px;
    display: flex;
    transition: color 0.15s ease, border-color 0.15s ease;
  }
  .swatch-icone:hover {
    color: var(--text);
  }
  .swatch-icone.actif {
    color: var(--accent);
    border-color: var(--accent);
  }

  .etoiles {
    display: flex;
    gap: 2px;
  }
  .etoiles.pulse .etoile :global(svg) {
    animation: etoile-pop 0.3s var(--spring);
  }
  @keyframes etoile-pop {
    0% { transform: scale(0.7) rotate(-8deg); }
    60% { transform: scale(1.25) rotate(4deg); }
    100% { transform: scale(1) rotate(0); }
  }
  .etoile {
    background: transparent;
    border: none;
    cursor: pointer;
    padding: 2px;
    display: flex;
    transition: transform 0.15s var(--spring);
  }
  .etoile:hover {
    transform: translateY(-2px);
  }

  .champ {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .eyebrow-icone {
    display: flex;
    align-items: center;
    gap: 4px;
  }

  .liste-defis {
    display: flex;
    flex-direction: column;
    gap: 3px;
  }
  .ligne-defi {
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .case-defi {
    background: transparent;
    border: none;
    cursor: pointer;
    padding: 2px;
    display: flex;
    flex-shrink: 0;
  }
  .texte-defi {
    flex: 1;
    font-size: 0.85rem;
    color: var(--text);
  }
  .texte-defi.fait {
    color: var(--muted);
    text-decoration: line-through;
  }
  .retirer-defi {
    background: transparent;
    border: none;
    color: var(--muted);
    cursor: pointer;
    padding: 2px;
    border-radius: 4px;
    flex-shrink: 0;
    opacity: 0.6;
  }
  .retirer-defi:hover {
    opacity: 1;
    color: var(--danger);
  }

  .ajout-defi {
    display: flex;
    gap: 6px;
  }
  .ajout-defi input {
    flex: 1;
  }
  .btn-ajout-defi {
    background: color-mix(in srgb, var(--accent) 20%, var(--input));
    color: var(--accent);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 0 10px;
    cursor: pointer;
    display: flex;
    align-items: center;
  }
  .btn-ajout-defi:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .supprimer {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    background: transparent;
    border: 1px solid color-mix(in srgb, var(--danger) 50%, var(--border));
    color: var(--danger);
    border-radius: var(--radius-sm);
    padding: var(--space-1) var(--space-2);
    font-family: var(--font-body);
    font-size: 0.82rem;
    cursor: pointer;
    margin-top: var(--space-2);
    align-self: flex-start;
  }
  .supprimer:hover {
    background: color-mix(in srgb, var(--danger) 12%, transparent);
  }

  :global(.spin) {
    animation: spin 0.6s linear infinite;
  }
  @keyframes spin {
    to { transform: rotate(360deg); }
  }
</style>
