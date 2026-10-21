<script lang="ts">
  import CoverImage from "./CoverImage.svelte";
  import MenuContextuel from "./MenuContextuel.svelte";
  import type { ActionMenu } from "./menu-contextuel";
  import { Trash2, X, FolderOpen, Search, Loader2, Heart, Plus, ListChecks, SquareCheck, Square, Award, ExternalLink, Pencil, Check, Download } from "@lucide/svelte";
  import { fly } from "svelte/transition";
  import { onMount } from "svelte";
  import { open } from "@tauri-apps/plugin-dialog";
  import SteamGridDBPanel from "./SteamGridDBPanel.svelte";
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
  let ficheDialog: HTMLDialogElement;
  onMount(() => {
    // L'API top-layer échappe à la barre intégrée et au scroll de la fiche.
    ficheDialog.showModal();
    return () => { if (ficheDialog?.open) ficheDialog.close(); };
  });

  // svelte-ignore state_referenced_locally -- intentionnel : valeur de
  // départ pratique (nom du jeu), l'utilisateur doit ensuite pouvoir taper
  // sa propre recherche sans qu'elle soit réécrasée si `game` se met à jour.
  let rechercheRawg = $state(game.nom);
  type SourceCover = "rawg" | "steam";

  const SOURCES_INFO: Record<SourceCover, { label: string; aideFr: string; aideEn: string; needsKey: boolean }> = {
    steam: { label: "Steam", aideFr: "Jeux Steam/PC uniquement, aucune clé requise.", aideEn: "Steam/PC games only, no API key required.", needsKey: false },
    rawg: { label: "RAWG", aideFr: "Toutes plateformes, clé API requise.", aideEn: "All platforms, API key required.", needsKey: true },
  };

  // Seules les sources activées dans Options > Connexion sont proposées ici.
  const sourcesDisponibles = $derived(
    (Object.keys(SOURCES_INFO) as SourceCover[]).filter((s) => config.sourcesCoverActives[s])
  );

  function aUneCle(s: SourceCover): boolean {
    if (s === "rawg") return !!config.rawgApiKey.trim();
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
  let messageCover = $state<string | null>(null);
  let sgdbPanelOpen = $state(false);
  let coverMenu = $state<{ x: number; y: number; actions: ActionMenu[] } | null>(null);
  let pulseNote = $state(false);
  let pulseTimeout: ReturnType<typeof setTimeout> | null = null;
  let nouveauDefi = $state("");
  let urlCollee = $state("");


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
    if (telechargementEnCours) return;
    erreurRawg = null;
    messageCover = null;
    try {
      const selection = await open({
        multiple: false,
        filters: [{ name: "Images", extensions: ["jpg", "jpeg", "png", "webp", "gif"] }],
      });
      if (!selection || Array.isArray(selection)) return;
      telechargementEnCours = true;
      const chemin = await api.saveLocalCover(platformId, game.id, selection);
      onSave({ cover: chemin });
      messageCover = tr(config.langue, "Image enregistrée ! Tu peux maintenant fermer la fiche : elle sera aussi visible dans la Bibliothèque.", "Image saved! You can now close this game detail; it is also available in the library.");
    } catch (e) {
      erreurRawg = `${tr(config.langue, "Impossible d'importer cette image", "Cannot import this image")} : ${String(e)}`;
    } finally {
      telechargementEnCours = false;
    }
  }

  // HF5 : recherche SteamGridDB dans un vrai atelier interne qui reste ouvert
  // même sans clé API. Aucune nouvelle WebView ni fermeture automatique.
  function chercherSteamGridDB() {
    sgdbPanelOpen = true;
    erreurRawg = null;
    messageCover = null;
  }

  function imageSteamGridDBAppliquee(path: string) {
    onSave({ cover: path });
    messageCover = tr(config.langue, "Jaquette SteamGridDB enregistrée.", "SteamGridDB cover saved.");
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
      messageCover = tr(config.langue, "Jaquette téléchargée et enregistrée.", "Cover downloaded and saved.");
      urlCollee = "";
    } catch (e) {
      erreurRawg = `${tr(config.langue, "Téléchargement impossible", "Download failed")} : ${e}`;
    } finally {
      telechargementEnCours = false;
    }
  }

  async function rechercherCouverture(sourceForcee?: SourceCover) {
    if (rawgEnCours) return;
    const source = sourceForcee ?? sourceCover;
    const query = rechercheRawg.trim();
    if (!query || (SOURCES_INFO[source].needsKey && !aUneCle(source))) {
      erreurRawg = !query
        ? tr(config.langue, "Indique le nom d’un jeu à rechercher.", "Enter a game name to search.")
        : tr(config.langue, "Clé API manquante : vérifie Options → Connexion.", "Missing API key: check Settings → Connections.");
      return;
    }
    sourceCover = source;
    rawgEnCours = true;
    erreurRawg = null;
    resultatsRawg = null;
    try {
      if (source === "rawg") {
        resultatsRawg = await api.rawgSearch(config.rawgApiKey.trim(), query);
      } else {
        resultatsRawg = await api.steamStoreSearch(query);
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
      messageCover = tr(config.langue, "Jaquette téléchargée et enregistrée.", "Cover downloaded and saved.");
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

  function ouvrirMenuJaquette(event: MouseEvent) {
    event.preventDefault();
    event.stopPropagation();
    const actions: ActionMenu[] = [
      { label: tr(config.langue, "Modifier la fiche", "Edit game details"), icone: Pencil,
        action: () => { mode = "edition"; } },
      { label: tr(config.langue, "Choisir une image locale…", "Choose a local image…"), icone: FolderOpen,
        groupe: tr(config.langue, "Jaquette", "Cover"), action: () => { mode = "edition"; void choisirFichierLocal(); } },
      { label: tr(config.langue, "Rechercher sur SteamGridDB…", "Search SteamGridDB…"), icone: Search,
        action: () => { mode = "edition"; chercherSteamGridDB(); } },
    ];
    if (game.cover) actions.push({
      label: tr(config.langue, "Retirer la jaquette de cette fiche…", "Remove this game's cover…"),
      icone: Trash2, danger: true, separateurAvant: true, action: async () => {
        const ok = await confirmer(tr(config.langue,
          `Retirer la jaquette de « ${game.nom} » ? Le jeu sera conservé.`,
          `Remove the cover from “${game.nom}”? The game will be kept.`));
        if (ok) onSave({ cover: null });
      },
    });
    coverMenu = { x: event.clientX, y: event.clientY, actions };
  }

  function onKeydown(e: KeyboardEvent) {
    if (e.key === "Escape" && !sgdbPanelOpen) onClose();
  }
</script>

<svelte:window onkeydown={onKeydown} />

<!-- Dialogue natif dans la top-layer, pas un div fixe dépendant d'un conteneur défilant. -->
<dialog bind:this={ficheDialog} class="fiche-dialog" aria-label={game.nom}
  oncancel={(e) => { e.preventDefault(); if (!sgdbPanelOpen) onClose(); }}>
  <div class="fiche glass">
    <div class="fiche-toolbar">
      <span class="fiche-toolbar-label">{tr(config.langue, "Fiche du jeu", "Game details")} · {game.nom}</span>
      <div class="fiche-toolbar-buttons">
    <button
      class="crayon"
      onclick={() => (mode = mode === "consultation" ? "edition" : "consultation")}
      aria-label={mode === "consultation" ? tr(config.langue, "Modifier", "Edit") : tr(config.langue, "Terminer la modification", "Finish editing")}
      title={mode === "consultation" ? tr(config.langue, "Modifier", "Edit") : tr(config.langue, "Terminer la modification", "Finish editing")}
    >
      {#if mode === "consultation"}<Pencil size={16} strokeWidth={2.2} />{:else}<Check size={16} strokeWidth={2.2} />{/if}
    </button>
    <button class="fermer" type="button" onclick={onClose} aria-label={tr(config.langue, "Fermer la fiche", "Close game details")} title={tr(config.langue, "Fermer (Échap)", "Close (Escape)")}><X size={20} strokeWidth={2.2} /></button>
      </div>
    </div>
    <div class="fiche-scroll">
    <div class="colonnes">
      <div class="colonne-cover" in:fly={{ x: -16, duration: 240, delay: 40 }}>
        <!-- Intercepter le clic droit : le menu WebView2 « Inspecter » n’a pas sa place sur une jaquette. -->
        <!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
        <div class="cover-cadre" oncontextmenu={ouvrirMenuJaquette} role="group" aria-label={tr(config.langue, "Jaquette : clic droit pour les actions", "Cover: right-click for actions")}>
          <CoverImage path={game.cover} alt={game.nom} variant="detail" />
        </div>
        {#if mode === "edition"}
        <button class="action-cover" onclick={choisirFichierLocal} disabled={telechargementEnCours}>
          <FolderOpen size={15} strokeWidth={2.2} />
          {tr(config.langue, "Choisir un fichier", "Choose a file")}
        </button>
        <button class="action-cover secondaire" onclick={chercherSteamGridDB} disabled={telechargementEnCours}>
          <Search size={15} strokeWidth={2.2} />
          {tr(config.langue, "Atelier SteamGridDB · rechercher des images", "SteamGridDB studio · find artwork")}
        </button>
        <p class="aide-source">
          {tr(config.langue,
            "Avec clé : choisissez un jeu puis une jaquette parmi plusieurs images. Sans clé : navigateur, fichier local ou URL directe, dans le même atelier.",
            "With a key: select a game then pick from multiple images. Without a key: browser, local file or direct URL in the same studio.")}
        </p>
        {#if erreurRawg}<p class="erreur-rawg" role="alert">{erreurRawg}</p>{/if}
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
              <button class="action-cover" onclick={() => rechercherCouverture()} disabled={rawgEnCours}>
                {#if rawgEnCours}<Loader2 size={15} strokeWidth={2.2} class="spin" />{:else}<Search size={15} strokeWidth={2.2} />{/if}
                {tr(config.langue, "Rechercher", "Search")}
              </button>
            {#if resultatsRawg}
              <div class="resultats-rawg">
                {#each resultatsRawg as r (r.id)}
                  <button class="resultat" onclick={() => utiliserResultat(r)} disabled={!r.coverUrl || telechargementEnCours}>
                    {#if r.coverUrl}<CoverImage path={r.coverUrl} alt={r.nom} variant="preview" />{/if}
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
        {#if messageCover}
          <div class="cover-import-confirmation" role="status">
            <p class="message-cover">{messageCover}</p>
            <button type="button" class="action-cover" onclick={onClose}><Check size={15}/>{tr(config.langue, "Terminer et fermer la fiche", "Done — close game details")}</button>
          </div>
        {/if}

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
  {#if coverMenu && !sgdbPanelOpen}
    <MenuContextuel x={coverMenu.x} y={coverMenu.y} actions={coverMenu.actions}
      titre={tr(config.langue, "Actions sur la jaquette", "Cover actions")}
      onClose={() => (coverMenu = null)} />
  {/if}
</dialog>
  {#if sgdbPanelOpen}
    <SteamGridDBPanel
      initialQuery={rechercheRawg.trim() || game.nom}
      {config}
      {platformId}
      gameId={game.id}
      onClose={() => (sgdbPanelOpen = false)}
      onApplied={imageSteamGridDBAppliquee}
    />
  {/if}
<style>
  .fiche-dialog {
    position: fixed; inset: 0; margin: auto; padding: 0; border: 0;
    width: min(960px, calc(100vw - 18px)); max-width: none;
    height: min(760px, calc(100dvh - 18px)); max-height: none;
    background: transparent; color: var(--text); overflow: hidden;
    border-radius: 18px; box-shadow: 0 25px 95px rgba(0,0,0,.55);
  }
  .fiche-dialog::backdrop { background:rgba(0,0,0,.67); backdrop-filter:blur(5px); }
  .fiche { display:flex; flex-direction:column; height:100%; width:100%; max-width:none;
    max-height:none; overflow:hidden; padding:0; animation:fiche-glow .6s ease-out; }
  .fiche-toolbar { flex:none; position:relative; z-index:3; display:flex; align-items:center;
    justify-content:space-between; gap:10px; padding:10px 14px;
    background:color-mix(in srgb,var(--input) 78%,var(--card));
    border-bottom:1px solid var(--border); min-height:51px; }
  .fiche-toolbar-label { min-width:0; overflow:hidden; text-overflow:ellipsis; white-space:nowrap;
    color:var(--text); font-size:.85rem; font-weight:750; }
  .fiche-toolbar-buttons { display:flex; flex:none; gap:8px; align-items:center; }
  .fiche-scroll { flex:1; min-height:0; overflow-y:auto; overscroll-behavior:contain;
    padding:var(--space-4); scrollbar-gutter:stable; }
  @keyframes fiche-glow {
    0% { box-shadow: 0 0 0 0 color-mix(in srgb, var(--glow) 60%, transparent); }
    40% { box-shadow: 0 0 40px 6px color-mix(in srgb, var(--glow) 45%, transparent); }
    100% { box-shadow: 0 8px 30px rgba(0, 0, 0, 0.22); }
  }

  .fermer {
    position: relative;
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
    position: relative;
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
  .cover-cadre :global(.gamedraw-cover-image) {
    width: 100%;
    height: 100%;
    object-fit: cover;
    object-position: top center;
    transition: transform 0.35s ease;
  }
  .cover-cadre:hover :global(.gamedraw-cover-image) {
    transform: scale(1.07);
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
  .resultat :global(.gamedraw-cover-image) {
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

  .message-cover { color: var(--success); font-size: 0.78rem; margin: 0; }
  .cover-import-confirmation { display:grid; gap:8px; padding:10px; border:1px solid color-mix(in srgb,var(--success) 35%,var(--border)); background:color-mix(in srgb,var(--success) 9%,var(--card)); border-radius:11px; }
  .cover-import-confirmation .action-cover { color:var(--text); }
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
  @media (max-width: 620px) {
    .fiche-dialog { width:calc(100vw - 10px); height:calc(100dvh - 10px); border-radius:12px; }
    .fiche-scroll { padding:12px; scrollbar-gutter:auto; }
    .fiche-toolbar { padding:8px 12px; }
  }
</style>
