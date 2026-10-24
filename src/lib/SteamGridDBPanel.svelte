<script lang="ts">
  import CoverImage from "./CoverImage.svelte";
  import { onMount } from "svelte";
  import { api, type SteamGridGame, type SteamGridArtworkPage, type SteamGridFormat, type RawgGame } from "./api";
  import { steamPortraitCandidates } from "./steam-cover";
  import { evaluateSteamGridSearch, hasNextSteamGridPage, steamGridWebSearchUrl, isDirectImageUrl } from "./steamgriddb-search";
  import { open } from "@tauri-apps/plugin-dialog";
  import { openUrl } from "@tauri-apps/plugin-opener";
  import { WebviewWindow } from "@tauri-apps/api/webviewWindow";
  import { Search, Loader2, X, ArrowLeft, ChevronLeft, ChevronRight, ExternalLink, FolderOpen, Download, KeyRound, Images, Check } from "@lucide/svelte";
  import { tr } from "./i18n";
  import type { AppConfig } from "./types";

  let { initialQuery, config, platformId, gameId, onClose, onApplied } : {
    initialQuery: string;
    config: AppConfig;
    platformId: string;
    gameId: string;
    onClose: () => void;
    onApplied: (path: string) => void;
  } = $props();

  let query = $state(initialQuery);
  let searchInput: HTMLInputElement;
  let dialogEl: HTMLDialogElement;
  onMount(() => {
    // La top-layer native <dialog> échappe aux ancêtres transformés/scrollables
    // (dont la fiche animée) : la croix reste atteignable en 125/150 % DPI.
    if (!dialogEl.open) dialogEl.showModal();
    requestAnimationFrame(() => searchInput?.focus());
    return () => { if (dialogEl.open) dialogEl.close(); };
  });
  let games = $state<SteamGridGame[] | null>(null);
  let publicGames = $state<RawgGame[] | null>(null);
  let selected = $state<SteamGridGame | null>(null);
  let gallery = $state<SteamGridArtworkPage | null>(null);
  let format = $state<SteamGridFormat>("portrait");
  let busy = $state(false);
  let savingId = $state<number | null>(null);
  let failure = $state<string | null>(null);
  let success = $state<string | null>(null);
  let applied = $state(false);
  let webStatus = $state<string | null>(null);
  let pasted = $state("");
  let previewUrl = $state<string | null>(null);
  let previewFailed = $state(false);
  let requestSerial = 0;
  const configured = $derived(evaluateSteamGridSearch({ enabled: config.sourcesCoverActives.steamgriddb, apiKey: config.steamgriddbApiKey, query }));
  const lang = $derived(config.langue);

  async function search() {
    if (busy || savingId !== null) return;
    const state = evaluateSteamGridSearch({ enabled: config.sourcesCoverActives.steamgriddb, apiKey: config.steamgriddbApiKey, query });
    if (state === "empty-query" || !query.trim()) return;
    // Sans clé API SteamGridDB, on fournit une recherche directe de jaquettes
    // officielles Steam, tout en gardant l'import manuel SteamGridDB accessible.
    const publicMode = state === "missing-key" || state === "disabled";
    const serial = ++requestSerial;
    busy = true;
    failure = null;
    success = null;
    games = null;
    publicGames = null;
    selected = null;
    gallery = null;
    try {
      if (publicMode) {
        const response = await api.steamStoreSearch(query.trim());
        if (serial === requestSerial) publicGames = response;
      } else {
        const response = await api.steamgriddbGames(config.steamgriddbApiKey.trim(), query.trim());
        if (serial === requestSerial) games = response;
      }
    } catch (e) {
      if (serial === requestSerial) failure = String(e);
    } finally {
      if (serial === requestSerial) busy = false;
    }
  }

  async function openGame(game: SteamGridGame, nextFormat: SteamGridFormat = "portrait", page = 0) {
    if (busy || savingId !== null) return;
    const serial = ++requestSerial;
    selected = game;
    format = nextFormat;
    gallery = null;
    busy = true;
    failure = null;
    success = null;
    try {
      const response = await api.steamgriddbArtworks(config.steamgriddbApiKey.trim(), game.id, nextFormat, page);
      if (serial === requestSerial) gallery = response;
    } catch (e) {
      if (serial === requestSerial) failure = String(e);
    } finally {
      if (serial === requestSerial) busy = false;
    }
  }

  async function goToPage(page: number) {
    if (selected && page >= 0 && !busy) await openGame(selected, format, page);
  }

  async function applyImage(url: string, identifier: number) {
    if (savingId !== null || busy) return;
    savingId = identifier;
    failure = null;
    success = null;
    try {
      const path = await api.downloadCover(platformId, gameId, url);
      onApplied(path);
      applied = true;
      success = tr(lang, "Jaquette enregistrée ! Ferme l’atelier pour revenir à la fiche et retrouver l’image dans ta bibliothèque.", "Cover saved! Close the studio to return to your game and see the image in your library.");
    } catch (e) {
      failure = `${tr(lang, "Impossible d'appliquer la jaquette", "Could not apply cover")}: ${String(e)}`;
    } finally {
      savingId = null;
    }
  }

  async function applySteamPublic(game: RawgGame) {
    if (savingId !== null || busy) return;
    savingId = game.id;
    failure = null;
    success = null;
    try {
      const path = await api.downloadSteamCover(platformId, gameId, game.id);
      onApplied(path);
      applied = true;
      success = tr(lang,
        "Jaquette officielle Steam enregistrée sans clé API. Elle est conservée localement en qualité native.",
        "Official Steam artwork saved without an API key, at its native quality.");
    } catch (e) {
      failure = `${tr(lang, "Jaquette Steam indisponible", "Steam artwork unavailable")}: ${String(e)}`;
    } finally { savingId = null; }
  }

  async function pickFile() {
    if (savingId !== null || busy) return;
    failure = null;
    success = null;
    try {
      const selectedFile = await open({ multiple: false, filters: [{ name: "Images", extensions: ["jpg", "jpeg", "png", "webp", "gif"] }] });
      if (typeof selectedFile !== "string") return;
      savingId = -1;
      const path = await api.saveLocalCover(platformId, gameId, selectedFile);
      onApplied(path);
      applied = true;
      success = tr(lang, "Image locale importée avec succès. La jaquette est enregistrée : ferme l’atelier pour la retrouver dans ta fiche et ta bibliothèque.", "Local image saved successfully. Close this studio to see the cover in the game details and library.");
    } catch (e) {
      failure = `${tr(lang, "Import impossible", "Import failed")}: ${String(e)}`;
    } finally {
      savingId = null;
    }
  }

  function preparePreview(url: string) {
    const trimmed = url.trim();
    previewFailed = false;
    previewUrl = isDirectImageUrl(trimmed) ? trimmed : null;
    if (!previewUrl) failure = tr(lang,
      "Utilisez le lien direct de l’image HTTPS (pas l’adresse de la page SteamGridDB).",
      "Use the direct HTTPS image URL, not the SteamGridDB page URL.");
    else failure = null;
  }

  async function applyPastedUrl() {
    if (!isDirectImageUrl(pasted)) {
      failure = tr(lang, "Colle une adresse HTTPS directe vers une image, pas une page web.", "Paste a direct HTTPS image address, not a webpage.");
      return;
    }
    await applyImage(pasted.trim(), -2);
  }

  /** Pont explicitement déclenché par l'utilisateur : d'abord une image binaire
   * copiée, puis à défaut un lien HTTPS direct. Aucune lecture automatique d'un
   * site tiers et aucune exposition des commandes Tauri dans la WebView distante. */
  async function importerImageCopiee() {
    failure = null;
    if (savingId !== null || busy) return;
    // Certaines WebView2 savent lire l'image binaire copiée (« Copier l'image »).
    // Les permissions de presse-papiers peuvent l'empêcher : repli sur l'URL.
    if (navigator.clipboard?.read) {
      try {
        const items = await navigator.clipboard.read();
        for (const item of items) {
          const imageType = item.types.find(type => /^(image\/(png|jpeg|webp|gif))$/i.test(type));
          if (!imageType) continue;
          const blob = await item.getType(imageType);
          if (blob.size > 15 * 1024 * 1024) {
            failure = tr(lang, "Image copiée trop volumineuse (maximum 15 Mio).", "Copied image exceeds the 15 MiB limit.");
            return;
          }
          const bytes = new Uint8Array(await blob.arrayBuffer());
          // Découpage pour ne pas saturer la pile JS avec un spread géant.
          let binary = "";
          for (let index = 0; index < bytes.length; index += 8192) {
            binary += String.fromCharCode(...bytes.subarray(index, index + 8192));
          }
          savingId = -3;
          try {
            const path = await api.saveClipboardCover(platformId, gameId, btoa(binary));
            onApplied(path);
            applied = true;
            success = tr(lang, "Image copiée enregistrée sans compression supplémentaire par GameDraw, sans clé API.", "Copied image saved without additional compression by GameDraw, no API key.");
          } catch (error) {
            failure = `${tr(lang, "Import du presse-papiers refusé", "Clipboard import rejected")}: ${String(error)}`;
          } finally { savingId = null; }
          return;
        }
      } catch {
        // Une lecture binaire refusée par WebView2 n'empêche pas les autres méthodes.
      }
    }
    try {
      if (!navigator.clipboard?.readText) throw new Error("clipboard API unavailable");
      const copied = (await navigator.clipboard.readText()).trim();
      if (!isDirectImageUrl(copied)) {
        pasted = copied;
        previewUrl = null;
        failure = tr(lang, "Le presse-papiers ne contient pas d'adresse HTTPS d'image. Sur SteamGridDB, clic droit sur l'image → Copier l'adresse de l'image, puis réessaie.", "The clipboard does not contain a valid HTTPS image URL. On SteamGridDB, right-click the image → Copy image address, then try again.");
        return;
      }
      pasted = copied;
      preparePreview(copied);
      webStatus = tr(lang, "Adresse récupérée. Vérifiez l’aperçu puis cliquez sur « Utiliser cette jaquette ».", "Address captured. Check the preview, then click ‘Use this cover’.");
    } catch {
      failure = tr(lang,
        "Windows refuse la lecture du presse-papiers. Clique dans le champ ci-dessous, fais Ctrl+V, puis Appliquer.",
        "Clipboard access is blocked. Click the field below, press Ctrl+V, then Apply.");
    }
  }

  async function openWebsite() {
    failure = null;
    try { await openUrl(steamGridWebSearchUrl(query.trim() || initialQuery)); }
    catch (e) { failure = `${tr(lang, "Impossible d'ouvrir le navigateur", "Cannot open browser")}: ${String(e)}`; }
  }

  /** Le site public est rendu dans une WebView2 dédiée à GameDraw.
   * Les commandes Tauri restent autorisées sur « main » uniquement.
   * Sans API, l'utilisateur choisit manuellement une image du site puis
   * copie son URL HTTPS directe ou enregistre son fichier. */
  async function openInsideApp() {
    if (savingId !== null) return;
    failure = null;
    webStatus = null;
    const label = "steamgriddb-public";
    try {
      const existing = await WebviewWindow.getByLabel(label);
      if (existing) {
        await existing.show();
        await existing.setFocus();
        webStatus = tr(lang, "La fenêtre du site public est ouverte. Lancez la recherche sur le site si nécessaire.", "The public website window is open. Search on the website if needed.");
        return;
      }
      const window = new WebviewWindow(label, {
        url: steamGridWebSearchUrl(query.trim() || initialQuery),
        title: "SteamGridDB · GameDraw — site public",
        width: 1040,
        height: 720,
        minWidth: 450,
        minHeight: 360,
        center: true,
        decorations: true,
        resizable: true,
      });
      window.once("tauri://created", () => {
        webStatus = tr(lang, "Site ouvert. Copiez l'adresse d'une image ou enregistrez son fichier, puis revenez à l'atelier GameDraw.", "Site opened. Copy an image address or save its file, then return to GameDraw studio.");
      });
      window.once("tauri://error", (e) => {
        failure = `${tr(lang, "Fenêtre SteamGridDB impossible à ouvrir", "Could not open SteamGridDB window")}: ${String(e.payload)}`;
      });
    } catch (e) {
      failure = `${tr(lang, "Fenêtre SteamGridDB impossible à ouvrir", "Could not open SteamGridDB window")}: ${String(e)}`;
    }
  }

  function close() {
    requestSerial += 1;
    if (dialogEl?.open) dialogEl.close();
    onClose();
  }
</script>

<!-- showModal place ce dialogue dans la top-layer du navigateur : aucun
     conteneur de fiche transformé ne peut le rogner ni masquer son bouton X. -->
<dialog bind:this={dialogEl} class="sgdb-dialog" aria-label={tr(lang, "Atelier de jaquettes SteamGridDB", "SteamGridDB artwork studio")}
  onclick={(event) => event.stopPropagation()}
  oncancel={(event) => { event.preventDefault(); close(); }}>
  <section class="sgdb-panel glass">
    <header class="sgdb-head">
      <div>
        <span class="sgdb-eyebrow">STEAMGRIDDB · GAMEDRAW</span>
        <h2><Images size={22} strokeWidth={2} /> {tr(lang, "Atelier de jaquettes", "Cover artwork studio")}</h2>
        <p>{tr(lang, "Trouvez le bon jeu, choisissez une image et appliquez-la directement.", "Find the right game, choose an image and apply it directly.")}</p>
      </div>
      <button class="sgdb-close" onclick={close} title={tr(lang, "Fermer", "Close")} aria-label={tr(lang, "Fermer", "Close")}><X size={20}/></button>
    </header>

    <div class="sgdb-controls">
      <label for="sgdb-title">{tr(lang, "Rechercher un jeu", "Search for a game")}</label>
      <div class="sgdb-search">
        <input id="sgdb-title" type="search" bind:this={searchInput} bind:value={query} placeholder={tr(lang, "Nom du jeu, édition, plateforme…", "Game title, edition, platform…")} onkeydown={(event) => { if (event.key === "Enter") { event.stopPropagation(); void search(); } }} />
        {#if configured === "missing-key" || configured === "disabled"}
          <button class="sgdb-primary" onclick={search} disabled={busy || savingId !== null || !query.trim()}>
            {#if busy}<Loader2 size={17} class="sgdb-spin" />{:else}<Search size={17} />{/if}
            {tr(lang, "Chercher Steam · sans clé", "Search Steam · no key")}
          </button>
        {:else}
          <button class="sgdb-primary" onclick={search} disabled={configured !== "ready" || busy || savingId !== null}>
            {#if busy}<Loader2 size={17} class="sgdb-spin" />{:else}<Search size={17} />{/if}
            {tr(lang, "Rechercher", "Search")}
          </button>
        {/if}
      </div>
      {#if !config.sourcesCoverActives.steamgriddb}
        <p class="sgdb-notice">{tr(lang, "SteamGridDB désactivé : recherche de jaquettes Steam sans clé disponible. Import manuel toujours possible.", "SteamGridDB disabled: no-key Steam artwork search is available. Manual import remains possible.")}</p>
      {:else if !config.steamgriddbApiKey.trim()}
        <p class="sgdb-notice"><KeyRound size={16} /> {tr(lang, "Sans clé : recherchez et installez directement une jaquette officielle Steam. Pour une création communautaire SteamGridDB, ouvrez son site public puis importez le lien direct ou le fichier. La galerie automatique SteamGridDB exige sa clé API.", "No key: search and install official Steam artwork directly. For community SteamGridDB art, browse its public site and import the direct image link or file. Automatic SteamGridDB gallery requires its API key.")}</p>
      {:else if configured === "empty-query"}
        <p class="sgdb-notice">{tr(lang, "Saisissez un titre pour lancer la recherche.", "Enter a title to start searching.")}</p>
      {/if}
    </div>

    {#if failure}<p class="sgdb-error" role="alert">{failure}</p>{/if}
    {#if success}
      <div class="sgdb-done" role="status">
        <div class="sgdb-done-message"><Check size={19}/><span>{success}</span></div>
        {#if applied}
          <button type="button" class="sgdb-done-close" onclick={close}>
            <Check size={16}/>{tr(lang, "Terminer et fermer l’atelier", "Done — close artwork studio")}
          </button>
        {/if}
      </div>
    {/if}

    <div class="sgdb-results">
      {#if selected}
        <div class="sgdb-section-title">
          <button class="sgdb-back" onclick={() => { selected = null; gallery = null; failure = null; }} disabled={busy}><ArrowLeft size={15} /> {tr(lang, "Jeux", "Games")}</button>
          <strong>{selected.name}</strong>
        </div>
        <div class="sgdb-formats" role="group" aria-label={tr(lang, "Format des images", "Image format")}>
          {#each [{id:"portrait",label:tr(lang,"Portrait · jaquettes", "Portrait · covers")},{id:"landscape",label:tr(lang,"Paysage · bannières", "Landscape · banners")},{id:"square",label:tr(lang,"Carré", "Square")}] as item}
            <button class:active={format === item.id} disabled={busy} onclick={() => selected && openGame(selected, item.id as SteamGridFormat, 0)}>{item.label}</button>
          {/each}
        </div>
        {#if busy}<p class="sgdb-empty"><Loader2 size={18} class="sgdb-spin" /> {tr(lang, "Chargement des illustrations…", "Loading artwork…")}</p>
        {:else if gallery}
          {#if gallery.images.length === 0}<p class="sgdb-empty">{tr(lang, "Aucune image dans ce format. Essayez un autre format ou un autre jeu.", "No artwork in this format. Try another format or game.")}</p>{/if}
          <div class="sgdb-artworks">
            {#each gallery.images as art (art.id)}
              <div class="sgdb-artwork">
                <div class="sgdb-preview" class:landscape={format === "landscape"} class:square={format === "square"}>
                  <CoverImage path={art.thumb} alt={selected.name} variant="card" />
                </div>
                <span class="sgdb-author">{art.authorName || art.style || "SteamGridDB"}</span>
                <button onclick={() => applyImage(art.url, art.id)} disabled={savingId !== null}>
                  {#if savingId === art.id}<Loader2 size={14} class="sgdb-spin" />{:else}<Download size={14} />{/if}
                  {tr(lang, "Utiliser", "Use")}
                </button>
              </div>
            {/each}
          </div>
          <div class="sgdb-pagination">
            <button onclick={() => goToPage(gallery ? gallery.page - 1 : 0)} disabled={busy || gallery.page === 0}><ChevronLeft size={15} /> {tr(lang,"Précédent","Previous")}</button>
            <span>{tr(lang,"Page","Page")} {gallery.page + 1}{gallery.total > 0 ? ` · ${gallery.total} ${tr(lang,"images","images")}` : ""}</span>
            <button onclick={() => goToPage(gallery ? gallery.page + 1 : 0)} disabled={busy || !hasNextSteamGridPage(gallery)}>{tr(lang,"Suivant","Next")} <ChevronRight size={15}/></button>
          </div>
        {/if}
      {:else if busy}
        <p class="sgdb-empty"><Loader2 size={19} class="sgdb-spin" /> {tr(lang, "Recherche de jeux…", "Searching games…")}</p>
      {:else if games}
        {#if games.length === 0}<p class="sgdb-empty">{tr(lang,"Aucun jeu trouvé. Essayez un titre plus court.","No games found. Try a shorter title.")}</p>{/if}
        <div class="sgdb-games">
          {#each games as candidate (candidate.id)}
            <button onclick={() => openGame(candidate)}><span>{candidate.name}</span><ChevronRight size={16}/></button>
          {/each}
        </div>
      {:else if publicGames}
        <div class="sgdb-section-title"><strong>{tr(lang, "Jaquettes officielles Steam · sans clé", "Official Steam artwork · no key")}</strong></div>
        <p class="sgdb-source-explain">{tr(lang, "Résultats Steam Store (pas SteamGridDB). L'import teste les affiches HD puis les autres formats publics disponibles. Sans résultat, utilise le site SteamGridDB ci-dessous.", "Steam Store results (not SteamGridDB). Import tries HD posters then other public formats. Use the SteamGridDB website below if none is available.")}</p>
        <div class="sgdb-public-results">
          {#each publicGames as candidate (candidate.id)}
            <div class="sgdb-public-game">
              <div class="sgdb-public-image"><CoverImage path={candidate.coverUrl || steamPortraitCandidates(candidate.id)[1] || null} alt={candidate.nom} variant="card" /></div>
              <strong>{candidate.nom}</strong>
              <button onclick={() => applySteamPublic(candidate)} disabled={savingId !== null || busy}>
                {#if savingId === candidate.id}<Loader2 size={15} class="sgdb-spin" />{:else}<Download size={15}/>{/if}
                {tr(lang, "Utiliser", "Use")}
              </button>
            </div>
          {/each}
        </div>
        {#if publicGames.length === 0}<p class="sgdb-empty">{tr(lang, "Aucun jeu correspondant sur Steam. Ouvre SteamGridDB ci-dessous pour choisir une image manuellement.", "No matching Steam game. Browse SteamGridDB below to choose an image manually.")}</p>{/if}
      {:else if configured === "missing-key" || configured === "disabled"}
        <p class="sgdb-empty">{tr(lang,"Cherche un titre pour retrouver une jaquette Steam sans clé, ou ouvre SteamGridDB ci-dessous pour un choix manuel.","Search a title for a Steam cover without a key, or open SteamGridDB below for manual selection.")}</p>
      {:else}
        <p class="sgdb-empty">{tr(lang,"La recherche est prête. Choisissez un jeu puis une jaquette, ou utilisez une image manuelle ci-dessous.","Ready to search. Choose a game and then artwork, or use a manual image below.")}</p>
      {/if}
    </div>

    <footer class="sgdb-manual" class:sgdb-manual-focused={configured !== "ready"}>
      <h3>{tr(lang, "Choisir une jaquette · sans clé ou depuis un fichier", "Choose artwork · no API key or local file")}</h3>
      <div class="sgdb-actions">
        <button class="sgdb-primary" onclick={openInsideApp}><Images size={16}/>{tr(lang,"Parcourir SteamGridDB dans GameDraw", "Browse SteamGridDB in GameDraw")}</button>
        <button onclick={importerImageCopiee} disabled={savingId !== null || busy} title={tr(lang,"Sur SteamGridDB : copier l’image ou son adresse HTTPS, puis cliquer ici", "On SteamGridDB: copy the image or its HTTPS address, then click here")}><Download size={16}/>{tr(lang,"Importer depuis le presse-papiers", "Import from clipboard")}</button>
        <button onclick={openWebsite}><ExternalLink size={16}/>{tr(lang,"Navigateur externe", "External browser")}</button>
        <button onclick={pickFile} disabled={savingId !== null || busy}><FolderOpen size={16}/>{tr(lang,"Choisir une image locale","Choose local image")}</button>
      </div>
      {#if webStatus}<p class="sgdb-webstatus" role="status">{webStatus}</p>{/if}
      <div class="sgdb-paste">
        <input type="url" bind:value={pasted} oninput={() => { previewUrl = null; previewFailed = false; }} placeholder={tr(lang,"Coller une URL directe d’image HTTPS…","Paste a direct HTTPS image URL…")} onkeydown={(event) => { if (event.key === "Enter") preparePreview(pasted); }}/>
        <button onclick={() => preparePreview(pasted)} disabled={!pasted.trim() || savingId !== null || busy}><Search size={15}/>{tr(lang,"Aperçu", "Preview")}</button>
      </div>
      {#if previewUrl}
        <div class="sgdb-manual-preview">
          <div class="sgdb-manual-preview-picture"><img src={previewUrl} alt={tr(lang, "Aperçu de la jaquette", "Artwork preview")} onerror={() => (previewFailed = true)} onload={() => (previewFailed = false)}/></div>
          <div class="sgdb-manual-preview-details">
            <strong>{tr(lang, "Votre jaquette sélectionnée", "Your selected cover")}</strong>
            <small>{tr(lang, "GameDraw vérifiera le fichier avant de l’enregistrer localement.", "GameDraw validates the image before saving it locally.")}</small>
            {#if previewFailed}<small class="sgdb-preview-warning">{tr(lang, "Aperçu indisponible ; l’import peut fonctionner si le serveur autorise le téléchargement.", "Preview unavailable; import may still work if the server allows downloading.")}</small>{/if}
            <button class="sgdb-primary" onclick={applyPastedUrl} disabled={savingId !== null || busy}><Check size={16}/>{tr(lang,"Utiliser cette jaquette", "Use this cover")}</button>
          </div>
        </div>
      {/if}
      <small>{tr(lang,"Le site public est consultable sans clé, mais la sélection automatique depuis sa page n'est pas disponible sans API. Clic droit sur une image → « Copier l’image » ou « Copier l’adresse de l’image », puis « Importer depuis le presse-papiers » ici. Sinon Ctrl+V ou choisir un fichier. L'atelier reste ouvert jusqu'à votre décision.","The public site can be browsed without a key, but automatic selection from its webpage requires API access. Right-click artwork → ‘Copy image’ or ‘Copy image address’, then ‘Import from clipboard’ here. You can also use Ctrl+V or select a file. The studio stays open until you close it.")}</small>
    </footer>
  </section>
</dialog>

<style>
  .sgdb-dialog { position: fixed; inset:0; width:min(1040px, calc(100vw - 20px)); max-width:none; height:min(810px, calc(100dvh - 18px)); max-height:none; margin:auto; padding:0; border:0; border-radius:20px; background:transparent; color:var(--text); overflow:hidden; box-shadow:0 32px 100px rgba(0,0,0,.6); }
  .sgdb-dialog::backdrop { background:rgba(3,9,22,.85); backdrop-filter:blur(10px); }
  .sgdb-panel { width:100%; height:100%; min-width:0; min-height:0; overflow:hidden; display:flex; flex-direction:column; border:1px solid color-mix(in srgb, var(--accent) 42%, var(--border)); border-radius:20px; background:var(--card); color:var(--text); }
  .sgdb-head { flex:none; display:flex; gap:20px; justify-content:space-between; padding: 14px 20px 10px; background: linear-gradient(110deg, color-mix(in srgb, var(--accent) 16%, transparent), transparent 75%); }
  .sgdb-head h2 { font-family:var(--font-display); font-size:1.4rem; display:flex; align-items:center; gap:10px; margin:4px 0; }
  .sgdb-head p { color:var(--muted); margin:0; font-size:.84rem; }
  .sgdb-eyebrow { font-size:.65rem; letter-spacing:.16em; color:var(--accent); font-weight:800; }
  .sgdb-close { flex:none; position:sticky; top:0; align-self:start; border-radius:11px; border:1px solid var(--border); background:var(--input); color:var(--text); padding:8px; cursor:pointer; }
  .sgdb-controls { flex:none; padding: 9px 20px; display:grid; gap:7px; }
  .sgdb-controls label { font-size:.77rem; font-weight:700; color:var(--muted); }
  .sgdb-search, .sgdb-paste { display:flex; gap:9px; }
  .sgdb-search input, .sgdb-paste input { min-width:0; flex:1; background:var(--input); color:var(--text); border:1px solid var(--border); border-radius:10px; padding:11px 13px; font:inherit; }
  button { font:inherit; }
  button:disabled { opacity:.45; cursor:not-allowed; }
  .sgdb-primary, .sgdb-actions button, .sgdb-paste button { display:flex; align-items:center; gap:7px; padding:9px 14px; border-radius:10px; cursor:pointer; color:var(--text); background:color-mix(in srgb,var(--accent) 19%,var(--input)); border:1px solid color-mix(in srgb,var(--accent) 44%,var(--border)); }
  .sgdb-primary { background:var(--accent); color:var(--bg); font-weight:800; }
  .sgdb-notice, .sgdb-error, .sgdb-success { font-size:.8rem; line-height:1.5; display:flex; align-items:flex-start; gap:8px; padding:10px 13px; margin:0 24px 10px; border-radius:10px; }
  .sgdb-notice { background:color-mix(in srgb, var(--accent) 12%,transparent); color:var(--text); }
  .sgdb-error { background:rgba(220,66,82,.13); border:1px solid rgba(220,66,82,.35); color:var(--danger); }
  .sgdb-success { background:rgba(40,180,125,.13); color:var(--success); }
  .sgdb-done { display:flex; flex-wrap:wrap; align-items:center; justify-content:space-between; gap:10px; margin:0 24px 10px; padding:12px 14px; background:color-mix(in srgb,var(--success) 15%,var(--card)); border:1px solid color-mix(in srgb,var(--success) 40%,var(--border)); border-radius:12px; }
  .sgdb-done-message { display:flex; align-items:flex-start; gap:10px; color:var(--success); font-size:.82rem; line-height:1.45; flex:1; min-width:210px; }
  .sgdb-done-close { display:inline-flex; align-items:center; gap:7px; min-height:36px; padding:8px 12px; border:1px solid var(--accent); border-radius:9px; background:var(--accent); color:var(--darkbg); font-weight:800; cursor:pointer; }
  .sgdb-results { flex:1 1 auto; min-height:40px; overflow-y:auto; overscroll-behavior:contain; padding: 8px 24px 16px; }
  .sgdb-section-title { display:flex; align-items:center; gap:14px; padding:4px 0 12px; }
  .sgdb-back { border:1px solid var(--border); border-radius:9px; color:var(--text); background:var(--input); padding:7px 10px; display:flex; gap:5px; align-items:center; cursor:pointer; }
  .sgdb-section-title strong { font-family:var(--font-display); font-size:1.08rem; }
  .sgdb-source-explain { color:var(--muted);font-size:.78rem;line-height:1.5;margin:0 0 12px; }
  .sgdb-public-results { display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:12px; }
  .sgdb-public-game {display:flex;flex-direction:column;min-width:0;gap:8px;padding:10px;border:1px solid var(--border);border-radius:12px;background:var(--input);}
  .sgdb-public-game strong {font-size:.79rem;line-height:1.4;min-height:2.8em;overflow-wrap:anywhere;}
  .sgdb-public-image {height:160px;width:100%;border-radius:8px;overflow:hidden;}
  .sgdb-public-game button {display:flex;align-items:center;justify-content:center;gap:7px;padding:8px;background:color-mix(in srgb,var(--accent) 20%,var(--input));color:var(--text);border:1px solid var(--accent);border-radius:8px;cursor:pointer;}
  .sgdb-games { display:grid; grid-template-columns:repeat(auto-fit,minmax(min(100%,280px),1fr)); gap:9px; }
  .sgdb-games button { border:1px solid var(--border); border-radius:11px; background:color-mix(in srgb,var(--input) 87%,transparent); color:var(--text); padding:15px; display:flex; justify-content:space-between; gap:10px; align-items:center; cursor:pointer; text-align:left; }
  .sgdb-games button:hover,.sgdb-artwork:hover { border-color:var(--accent); }
  .sgdb-formats { display:flex; flex-wrap:wrap; gap:7px; margin-bottom:12px; }
  .sgdb-formats button { border:1px solid var(--border); border-radius:999px; background:var(--input); color:var(--muted); padding:8px 12px; cursor:pointer; }
  .sgdb-formats button.active { background:color-mix(in srgb, var(--accent) 19%,var(--input)); color:var(--text); border-color:var(--accent); }
  .sgdb-artworks { display:grid; grid-template-columns: repeat(auto-fill,minmax(130px,1fr)); gap:14px; }
  .sgdb-artwork { border:1px solid var(--border); border-radius:13px; padding:9px; display:flex; flex-direction:column; gap:8px; background:color-mix(in srgb,var(--input) 80%,transparent); min-width:0; }
  .sgdb-preview { aspect-ratio:2/3; background:var(--input); border-radius:8px; overflow:hidden; }
  .sgdb-preview.landscape { aspect-ratio: 2.1; } .sgdb-preview.square { aspect-ratio:1; }
  .sgdb-preview :global(img) { width:100%; height:100%; object-fit:contain; }
  .sgdb-author { font-size:.69rem; color:var(--muted); overflow:hidden; white-space:nowrap; text-overflow:ellipsis; }
  .sgdb-artwork button { display:flex; align-items:center; justify-content:center; gap:5px; border:1px solid color-mix(in srgb,var(--accent) 45%,var(--border)); color:var(--text); background:color-mix(in srgb,var(--accent) 18%,var(--input)); padding:7px; border-radius:8px; cursor:pointer; }
  .sgdb-pagination { display:flex; justify-content:center; align-items:center; gap:15px; margin:15px 0 0; font-size:.8rem; }
  .sgdb-pagination button { display:flex; align-items:center; gap:4px; background:var(--input); color:var(--text); border:1px solid var(--border); border-radius:8px; padding:7px; cursor:pointer; }
  .sgdb-empty { display:flex; justify-content:center; align-items:center; gap:8px; padding:20px; margin:0; text-align:center; font-size:.84rem; color:var(--muted); }
  .sgdb-manual { flex:none; max-height:37%; overflow-y:auto; overscroll-behavior:contain; border-top:1px solid var(--border); background:color-mix(in srgb,var(--input) 48%,transparent); padding:14px 24px 17px; display:grid; gap:9px; }
  .sgdb-manual-focused { max-height:min(54%,460px); }
  .sgdb-manual-preview { display:grid; grid-template-columns:minmax(85px,125px) 1fr; gap:14px; padding:12px; background:color-mix(in srgb,var(--accent) 9%,var(--card)); border:1px solid color-mix(in srgb,var(--accent) 32%,var(--border)); border-radius:12px; }
  .sgdb-manual-preview-picture { aspect-ratio:2/3; min-width:0; border-radius:8px; background:var(--input); overflow:hidden; }
  .sgdb-manual-preview-picture img { width:100%; height:100%; object-fit:contain; }
  .sgdb-manual-preview-details { display:flex; flex-direction:column; align-items:start; justify-content:center; gap:8px; min-width:0; }
  .sgdb-manual-preview-details strong { font-size:.88rem; }
  .sgdb-manual-preview-details .sgdb-preview-warning { color:var(--danger); }
  .sgdb-manual h3 { margin:0; font-size:.86rem; font-family:var(--font-display); }
  .sgdb-manual small { font-size:.7rem; line-height:1.45; color:var(--muted); }
  .sgdb-actions { display:flex; flex-wrap:wrap; gap:9px; }
  .sgdb-webstatus { margin:0; font-size:.77rem; line-height:1.45; color:var(--success); overflow-wrap:anywhere; }
  .sgdb-paste button { white-space:nowrap; }
  @keyframes sgdb-spin {to { transform:rotate(360deg);}} .sgdb-spin {animation:sgdb-spin 1s linear infinite;}
  @media (max-width:400px) { .sgdb-manual-preview { grid-template-columns:78px 1fr; gap:8px; padding:8px; } .sgdb-manual-preview .sgdb-primary { font-size:.73rem; } }
  @media (max-width:620px) { .sgdb-dialog { width:calc(100vw - 12px); height:calc(100dvh - 12px); border-radius:12px; } .sgdb-panel { border-radius:12px; } .sgdb-head h2 { font-size:1.13rem; } .sgdb-head p { font-size:.74rem; } .sgdb-manual { max-height:45%; } .sgdb-head,.sgdb-controls,.sgdb-results,.sgdb-manual { padding-left:13px; padding-right:13px; } .sgdb-search,.sgdb-paste { flex-wrap:wrap; } .sgdb-search input,.sgdb-paste input { flex-basis:100%; } .sgdb-notice,.sgdb-error,.sgdb-success { margin-left:13px; margin-right:13px; } }
</style>

