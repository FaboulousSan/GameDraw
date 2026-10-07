<script lang="ts">
  import { scale } from "svelte/transition";
  import { Plus, Search, LibraryBig, Gamepad2, Upload, Download, SquareCheck, Square, Trash2, X, Heart, Award, Star, Trophy, RotateCcw } from "@lucide/svelte";
  import { ICONE_NOTATION_COMPOSANTS } from "./icones-notation";
  import { convertFileSrc } from "@tauri-apps/api/core";
  import { save, open } from "@tauri-apps/plugin-dialog";
  import type { AppConfig, Game, GameLibrary, Platform, StatutJeu } from "./types";
  import {
    ajouterJeu,
    modifierJeu,
    supprimerJeu,
    ajouterPlusieursJeux,
    supprimerPlusieursJeux,
    filtrerJeux,
    importerLignes,
    fusionnerJeux,
    type LigneImport,
  } from "./library";
  import { trouverStatut } from "./statuts";
  import { CATALOGUES, CATALOGUE_LABELS, type CatalogueName } from "./catalogues";
  import { api } from "./api";
  import SteamImportDialog from "./SteamImportDialog.svelte";
  import ImportListeDialog from "./ImportListeDialog.svelte";
  import AjouterDepuisRawgDialog from "./AjouterDepuisRawgDialog.svelte";
  import AjouterDepuisSteamDialog from "./AjouterDepuisSteamDialog.svelte";
  import MenuContextuel from "./MenuContextuel.svelte";
  import type { ActionMenu } from "./menu-contextuel";
  import Toast from "./Toast.svelte";
  import { tr, labelStatut } from "./i18n";

  let {
    platformId,
    platforms,
    library,
    config,
    confirmer,
    onLibraryChange,
    onConfigChange,
    onPlatformChange,
    onOuvrirJeu,
  }: {
    platformId: string | null;
    platforms: Platform[];
    library: GameLibrary | null;
    config: AppConfig;
    confirmer: (message: string) => Promise<boolean>;
    onLibraryChange: (lib: GameLibrary) => void;
    onConfigChange: (cfg: AppConfig) => void;
    onPlatformChange: (id: string) => void;
    onOuvrirJeu: (gameId: string) => void;
  } = $props();

  let recherche = $state("");
  let nouveauNom = $state("");
  let catalogueOuvert = $state(false);
  let filtreStatut = $state<StatutJeu | "Tous">("Tous");
  let steamOuvert = $state(false);
  let rawgAjoutOuvert = $state(false);
  let steamAjoutOuvert = $state(false);
  let importListeOuvert = $state(false);
  let importerOuvert = $state(false);
  let messageImport = $state<string | null>(null);
  let messageImportTimeout: ReturnType<typeof setTimeout> | null = null;
  let modeSelection = $state(false);
  let jeuxSelectionnes = $state<Set<string>>(new Set());

  const IconeNote = $derived(ICONE_NOTATION_COMPOSANTS[config.iconeNotation]);

  const jeuxFiltres = $derived(
    library
      ? filtrerJeux(library.jeux, recherche).filter((j) => filtreStatut === "Tous" || j.statut === filtreStatut)
      : []
  );

  function afficherMessageImport(message: string) {
    messageImport = message;
    if (messageImportTimeout) clearTimeout(messageImportTimeout);
    messageImportTimeout = setTimeout(() => (messageImport = null), 5000);
  }

  function ajouter() {
    if (!library || !nouveauNom.trim()) return;
    onLibraryChange(ajouterJeu(library, nouveauNom));
    nouveauNom = "";
  }

  async function ajouterJeuAvecJaquette(nom: string, coverUrl: string | null) {
    if (!library || !platformId) return;
    const bibliothequeAvecJeu = ajouterJeu(library, nom);
    onLibraryChange(bibliothequeAvecJeu);
    if (!coverUrl) return;
    // Le nouveau jeu est toujours en dernière position (ajouterJeu() l'ajoute
    // à la fin) — pas besoin d'une fonction dédiée qui retourne son id.
    const nouveauJeu = bibliothequeAvecJeu.jeux[bibliothequeAvecJeu.jeux.length - 1];
    try {
      const chemin = await api.downloadCover(platformId, nouveauJeu.id, coverUrl);
      onLibraryChange({
        ...bibliothequeAvecJeu,
        jeux: bibliothequeAvecJeu.jeux.map((j) => (j.id === nouveauJeu.id ? { ...j, cover: chemin } : j)),
      });
    } catch {
      // La jaquette est un bonus — le jeu est déjà ajouté, une erreur de
      // téléchargement ne doit pas empêcher le reste de continuer.
    }
  }

  function basculerModeSelection() {
    modeSelection = !modeSelection;
    jeuxSelectionnes = new Set();
  }

  // --- Menu contextuel (clic droit sur une carte de jeu) -------------------
  let menuJeu = $state<{ x: number; y: number; actions: ActionMenu[] } | null>(null);

  function ouvrirMenuJeu(e: MouseEvent, jeu: Game) {
    e.preventDefault();
    e.stopPropagation();
    if (!library) return;
    const lib = library;

    const actions: ActionMenu[] = [
      { label: tr(config.langue, "Ouvrir la fiche", "Open details"), icone: Award, action: () => onOuvrirJeu(jeu.id) },
      {
        label: jeu.coupDeCoeur ? tr(config.langue, "Retirer le coup de cœur", "Remove favorite") : tr(config.langue, "Marquer coup de cœur", "Mark as favorite"),
        icone: Heart,
        action: () => onLibraryChange(modifierJeu(lib, jeu.id, { coupDeCoeur: !jeu.coupDeCoeur })),
      },
      {
        label: jeu.envieDeFaire ? tr(config.langue, "Retirer « envie de faire »", "Remove want to play") : tr(config.langue, "Marquer « envie de faire »", "Mark as want to play"),
        icone: Star,
        action: () => onLibraryChange(modifierJeu(lib, jeu.id, { envieDeFaire: !jeu.envieDeFaire })),
      },
      {
        label: jeu.complete100 ? tr(config.langue, "Retirer le 100%", "Remove 100%") : tr(config.langue, "Marquer à 100%", "Mark as 100%"),
        icone: Trophy,
        action: () => onLibraryChange(modifierJeu(lib, jeu.id, { complete100: !jeu.complete100 })),
      },
      {
        label: jeu.dejaFait ? tr(config.langue, "Remettre dans le pool", "Put back in draw pool") : tr(config.langue, "Retirer du pool de tirage", "Remove from draw pool"),
        icone: RotateCcw,
        separateurAvant: true,
        action: () => onLibraryChange(modifierJeu(lib, jeu.id, { dejaFait: !jeu.dejaFait })),
      },
      {
        label: modeSelection ? tr(config.langue, "Sélectionner / désélectionner", "Select / deselect") : tr(config.langue, "Sélectionner ce jeu", "Select this game"),
        icone: SquareCheck,
        action: () => {
          if (!modeSelection) modeSelection = true;
          basculerSelection(jeu.id);
        },
      },
      {
        label: tr(config.langue, "Supprimer ce jeu", "Delete this game"),
        icone: Trash2,
        danger: true,
        separateurAvant: true,
        action: async () => {
          const ok = await confirmer(config.langue === "en" ? `Delete “${jeu.nom}” from the library?` : `Supprimer « ${jeu.nom} » de la bibliothèque ?`);
          if (ok) onLibraryChange(supprimerJeu(lib, jeu.id));
        },
      },
    ];
    menuJeu = { x: e.clientX, y: e.clientY, actions };
  }

  function basculerSelection(gameId: string) {
    const s = new Set(jeuxSelectionnes);
    if (s.has(gameId)) s.delete(gameId);
    else s.add(gameId);
    jeuxSelectionnes = s;
  }

  function toutSelectionner() {
    jeuxSelectionnes = new Set(jeuxFiltres.map((j) => j.id));
  }

  function toutDeselectionner() {
    jeuxSelectionnes = new Set();
  }

  async function supprimerSelection() {
    if (!library || jeuxSelectionnes.size === 0) return;
    const n = jeuxSelectionnes.size;
    const confirme = await confirmer(config.langue === "en" ? `Delete ${n} selected game${n > 1 ? "s" : ""} from the library?` : `Supprimer ${n} jeu${n > 1 ? "x" : ""} sélectionné${n > 1 ? "s" : ""} de la bibliothèque ?`);
    if (!confirme) return;
    onLibraryChange(supprimerPlusieursJeux(library, [...jeuxSelectionnes]));
    jeuxSelectionnes = new Set();
    modeSelection = false;
    afficherMessageImport(config.langue === "en" ? `${n} game${n > 1 ? "s" : ""} deleted.` : `${n} jeu${n > 1 ? "x" : ""} supprimé${n > 1 ? "s" : ""}.`);
  }

  function importerCatalogue(nom: CatalogueName) {
    if (!library) return;
    onLibraryChange(ajouterPlusieursJeux(library, CATALOGUES[nom]).library);
    catalogueOuvert = false;
  }

  function importerDepuisSteam(noms: string[]) {
    if (!library) return;
    const { library: nouvelle, ignores } = ajouterPlusieursJeux(library, noms);
    onLibraryChange(nouvelle);
    afficherMessageImport(config.langue === "en" ? `Steam: ${noms.length - ignores} game(s) imported${ignores > 0 ? `, ${ignores} duplicate(s) ignored` : ""}.` : `Steam : ${noms.length - ignores} jeu(x) importé(s)${ignores > 0 ? `, ${ignores} déjà présent(s) ignoré(s)` : ""}.`);
  }

  function importerLignesListe(lignes: LigneImport[]) {
    if (!library) return;
    const { library: nouvelle, ignores } = importerLignes(library, lignes);
    onLibraryChange(nouvelle);
    afficherMessageImport(config.langue === "en" ? `${lignes.length - ignores} game(s) imported${ignores > 0 ? `, ${ignores} ignored (duplicate or empty)` : ""}.` : `${lignes.length - ignores} jeu(x) importé(s)${ignores > 0 ? `, ${ignores} ignoré(s) (doublon ou vide)` : ""}.`);
  }

  async function exporterBibliotheque() {
    if (!platformId) return;
    try {
      const nomPlateforme = platforms.find((p) => p.id === platformId)?.nom ?? platformId;
      const dest = await save({
        defaultPath: `GameDraw-${nomPlateforme}.zip`,
        filters: [{ name: "Archive GameDraw", extensions: ["zip"] }],
      });
      if (!dest) return;
      await api.exportLibraryZip(platformId, dest);
      afficherMessageImport(tr(config.langue, "Bibliothèque exportée.", "Library exported."));
    } catch (e) {
      afficherMessageImport(`${tr(config.langue, "Erreur d’export", "Export error")} : ${String(e)}`);
    }
  }

  async function importerZip() {
    if (!platformId || !library) return;
    try {
      const source = await open({ multiple: false, filters: [{ name: "Archive GameDraw", extensions: ["zip"] }] });
      if (!source || Array.isArray(source)) return;
      const importee = await api.importLibraryZip(platformId, source);
      const { library: nouvelle, ignores } = fusionnerJeux(library, importee.jeux);
      onLibraryChange(nouvelle);
      afficherMessageImport(
        config.langue === "en" ? `Archive imported: ${importee.jeux.length - ignores} game(s)${ignores > 0 ? `, ${ignores} duplicate(s) ignored` : ""}.` : `Archive importée : ${importee.jeux.length - ignores} jeu(x)${ignores > 0 ? `, ${ignores} déjà présent(s) ignoré(s)` : ""}.`
      );
    } catch (e) {
      afficherMessageImport(`${tr(config.langue, "Erreur d’import", "Import error")} : ${String(e)}`);
    }
  }
</script>

<section class="bibliotheque">
  <div class="chips-plateforme">
    {#each platforms as p}
      <button class="chip-plateforme" class:active={p.id === platformId} onclick={() => onPlatformChange(p.id)}>
        {p.nom}
      </button>
    {/each}
  </div>

  <div class="barre glass">
    <div class="recherche">
      <Search size={16} strokeWidth={2.2} color="var(--muted)" />
      <input type="text" placeholder={tr(config.langue, "Rechercher un jeu…", "Search for a game…")} bind:value={recherche} />
    </div>
    <div class="ajout">
      <input type="text" placeholder={tr(config.langue, "Nom du jeu", "Game name")} bind:value={nouveauNom} onkeydown={(e) => e.key === "Enter" && ajouter()} />
      <button class="btn-ajout" onclick={ajouter} disabled={!nouveauNom.trim()}>
        <Plus size={16} strokeWidth={2.2} />
        {tr(config.langue, "Ajouter", "Add")}
      </button>
      <button class="btn-catalogue" onclick={() => (rawgAjoutOuvert = true)}>
        <Search size={16} strokeWidth={2.2} />
        {tr(config.langue, "Depuis RAWG", "From RAWG")}
      </button>
      <button class="btn-catalogue" onclick={() => (steamAjoutOuvert = true)}>
        <Search size={16} strokeWidth={2.2} />
        {tr(config.langue, "Depuis Steam", "From Steam")}
      </button>
    </div>
    <div class="catalogue-wrap catalogue-wrap--catalogue">
      <button class="btn-catalogue" onclick={() => { importerOuvert = false; catalogueOuvert = !catalogueOuvert; }}>
        <LibraryBig size={16} strokeWidth={2.2} />
        {tr(config.langue, "Catalogue", "Catalog")}
      </button>
      {#if catalogueOuvert}
        <div class="menu-catalogue">
          {#each Object.keys(CATALOGUES) as nom}
            <button onclick={() => importerCatalogue(nom as CatalogueName)}>
              {CATALOGUE_LABELS[nom as CatalogueName]}
            </button>
          {/each}
        </div>
      {/if}
    </div>
    <div class="catalogue-wrap catalogue-wrap--import">
      <button class="btn-catalogue" onclick={() => { catalogueOuvert = false; importerOuvert = !importerOuvert; }}>
        <Upload size={16} strokeWidth={2.2} />
        {tr(config.langue, "Importer", "Import")}
      </button>
      {#if importerOuvert}
        <div class="menu-catalogue">
          <button onclick={() => { steamOuvert = true; importerOuvert = false; }}>{tr(config.langue, "Depuis Steam", "From Steam")}</button>
          <button onclick={() => { importListeOuvert = true; importerOuvert = false; }}>Liste / CSV</button>
          <button onclick={() => { importerZip(); importerOuvert = false; }}>Archive .zip</button>
        </div>
      {/if}
    </div>
    <button class="btn-catalogue" onclick={exporterBibliotheque}>
      <Download size={16} strokeWidth={2.2} />
      {tr(config.langue, "Exporter", "Export")}
    </button>
    <button class="btn-catalogue" class:active={modeSelection} onclick={basculerModeSelection}>
      <SquareCheck size={16} strokeWidth={2.2} />
      {tr(config.langue, "Sélectionner", "Select")}
    </button>
  </div>

  {#if messageImport}
    <Toast message={messageImport} onClose={() => (messageImport = null)} />
  {/if}

  {#if modeSelection}
    <div class="barre-selection glass">
      <span class="compte-selection">{config.langue === "en" ? `${jeuxSelectionnes.size} / ${jeuxFiltres.length} selected` : `${jeuxSelectionnes.size} / ${jeuxFiltres.length} sélectionné(s)`}</span>
      <div class="actions-selection">
        <button class="btn-selection" onclick={toutSelectionner}>
          <SquareCheck size={14} strokeWidth={2.2} />
          {tr(config.langue, "Tout cocher", "Select all")}
        </button>
        <button class="btn-selection" onclick={toutDeselectionner}>
          <Square size={14} strokeWidth={2.2} />
          {tr(config.langue, "Tout décocher", "Deselect all")}
        </button>
        <button class="btn-selection danger" onclick={supprimerSelection} disabled={jeuxSelectionnes.size === 0}>
          <Trash2 size={14} strokeWidth={2.2} />
          {tr(config.langue, "Supprimer", "Delete")} ({jeuxSelectionnes.size})
        </button>
        <button class="btn-selection" onclick={basculerModeSelection}>
          <X size={14} strokeWidth={2.2} />
          {tr(config.langue, "Annuler", "Cancel")}
        </button>
      </div>
    </div>
  {/if}

  {#if library && library.jeux.length > 0}
    <div class="onglets-statut">
      <button class="onglet-statut" class:active={filtreStatut === "Tous"} onclick={() => (filtreStatut = "Tous")}>
        {tr(config.langue, "Tous", "All")}
      </button>
      {#each config.statuts.filter((s) => s.visible) as s}
        <button class="onglet-statut" class:active={filtreStatut === s.id} onclick={() => (filtreStatut = s.id)}>
          <span class="point-statut" style="background: {s.couleur}"></span>
          {labelStatut(config.langue, s.id, s.label, s.integre)}
        </button>
      {/each}
    </div>
  {/if}

  {#if !library || library.jeux.length === 0}
    <div class="accueil-vide glass">
      <Gamepad2 size={32} strokeWidth={1.8} color="var(--muted)" />
      <p class="titre-vide">{tr(config.langue, "Bibliothèque vide", "Empty library")}</p>
      <p class="sous-titre-vide">
        {tr(config.langue, "Ajoute un jeu manuellement ci-dessus, ou importe un catalogue prédéfini pour démarrer rapidement.", "Add a game manually above, or import a predefined catalog to get started quickly.")}
      </p>
    </div>
  {:else if jeuxFiltres.length === 0}
    <p class="aucun-resultat">
      {#if recherche.trim()}
        {config.langue === "en" ? `No game matches “${recherche}”.` : `Aucun jeu ne correspond à « ${recherche} ».`}
      {:else}
        {tr(config.langue, "Aucun jeu avec ce statut pour l’instant.", "No game with this status yet.")}
      {/if}
    </p>
  {:else}
    <div class="grille">
      {#each jeuxFiltres as jeu (jeu.id)}
        {@const statutJeu = trouverStatut(config.statuts, jeu.statut)}
        <button
          class="carte-jeu"
          class:selectionnee={jeuxSelectionnes.has(jeu.id)}
          onclick={() => (modeSelection ? basculerSelection(jeu.id) : onOuvrirJeu(jeu.id))}
          oncontextmenu={(e) => ouvrirMenuJeu(e, jeu)}
          in:scale={{ duration: 200, start: 0.9 }}
        >
          {#if modeSelection}
            <span class="case-selection" class:cochee={jeuxSelectionnes.has(jeu.id)}>
              {#if jeuxSelectionnes.has(jeu.id)}<SquareCheck size={16} strokeWidth={2.2} color="var(--accent)" />{:else}<Square size={16} strokeWidth={2} color="var(--muted)" />{/if}
            </span>
          {/if}
          <div class="cover-mini">
            {#if jeu.cover}
              <img src={convertFileSrc(jeu.cover)} alt={jeu.nom} />
            {:else}
              <span class="cover-mini-placeholder">{jeu.nom.slice(0, 1).toUpperCase()}</span>
            {/if}
            {#if jeu.envieDeFaire || jeu.coupDeCoeur || jeu.complete100}
              <div class="badges-coeur">
                {#if jeu.coupDeCoeur}<Heart size={13} strokeWidth={2} fill="var(--danger)" color="var(--danger)" />{/if}
                {#if jeu.envieDeFaire}<Heart size={13} strokeWidth={2} fill="var(--accent)" color="var(--accent)" />{/if}
                {#if jeu.complete100}<Award size={13} strokeWidth={2} fill="#EAB308" color="#EAB308" />{/if}
              </div>
            {/if}
          </div>
          <div class="infos-mini">
            <p class="nom-mini">{jeu.nom}</p>
            <p class="statut-mini">
              <span class="point-statut" style="background: {statutJeu.couleur}"></span>
              {labelStatut(config.langue, statutJeu.id, statutJeu.label, statutJeu.integre)}
            </p>
            {#if jeu.note > 0}
              <p class="note-mini">
                <IconeNote size={11} strokeWidth={2} fill="var(--accent)" color="var(--accent)" />
                {jeu.note}
              </p>
            {/if}
          </div>
        </button>
      {/each}
    </div>
  {/if}
</section>

{#if steamOuvert}
  <SteamImportDialog
    steamApiKey={config.steamApiKey}
    steamId64={config.steamId64}
    onImport={importerDepuisSteam}
    onClose={() => (steamOuvert = false)}
  />
{/if}

{#if importListeOuvert}
  <ImportListeDialog statutsConnus={config.statuts} onImport={importerLignesListe} onClose={() => (importListeOuvert = false)} />
{/if}

{#if rawgAjoutOuvert}
  <AjouterDepuisRawgDialog rawgApiKey={config.rawgApiKey} onAjouter={ajouterJeuAvecJaquette} onClose={() => (rawgAjoutOuvert = false)} />
{/if}
{#if menuJeu}
  <MenuContextuel x={menuJeu.x} y={menuJeu.y} actions={menuJeu.actions} onClose={() => (menuJeu = null)} />
{/if}

{#if steamAjoutOuvert}
  <AjouterDepuisSteamDialog onAjouter={ajouterJeuAvecJaquette} onClose={() => (steamAjoutOuvert = false)} />
{/if}

<style>
  .bibliotheque {
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

  .onglets-statut {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }
  .onglet-statut {
    display: flex;
    align-items: center;
    gap: 5px;
    background: transparent;
    color: var(--muted);
    border: 1px solid var(--border);
    font-family: var(--font-body);
    font-size: 0.78rem;
    padding: 4px 10px;
    border-radius: 999px;
    cursor: pointer;
    transition: background-color 0.15s ease, color 0.15s ease, border-color 0.15s ease;
  }
  .onglet-statut:hover {
    border-color: color-mix(in srgb, var(--accent) 50%, var(--border));
  }
  .onglet-statut.active {
    background: color-mix(in srgb, var(--accent) 18%, transparent);
    color: var(--text);
    border-color: var(--accent);
  }

  .barre {
    padding: var(--space-3);
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-2);
    align-items: center;
    /* backdrop-filter sur .glass crée un stacking context. Sans z-index sur
       la barre elle-même, les cartes .glass rendues après peuvent recouvrir
       les menus déroulants enfants, même si .menu-catalogue a un gros
       z-index. On élève donc la barre entière au-dessus du contenu. */
    position: relative;
    z-index: 40;
    overflow: visible;
  }

  .recherche {
    display: flex;
    align-items: center;
    gap: 6px;
    background: color-mix(in srgb, var(--input) 85%, transparent);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 6px 10px;
    flex: 2 1 160px;
    transition: border-color 0.15s ease, box-shadow 0.15s ease;
  }
  .recherche:focus-within {
    border-color: var(--accent);
    box-shadow: 0 0 0 3px color-mix(in srgb, var(--accent) 20%, transparent);
  }
  .recherche input {
    background: transparent;
    border: none;
    color: var(--text);
    font-family: var(--font-body);
    font-size: 0.85rem;
    width: 100%;
  }

  .ajout {
    display: flex;
    gap: 6px;
    flex: 3 1 220px;
  }
  .ajout input {
    background: color-mix(in srgb, var(--input) 85%, transparent);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 6px 10px;
    color: var(--text);
    font-family: var(--font-body);
    font-size: 0.85rem;
    flex: 1;
    min-width: 90px;
    transition: border-color 0.15s ease, box-shadow 0.15s ease;
  }
  .ajout input:focus {
    outline: none;
    border-color: var(--accent);
    box-shadow: 0 0 0 3px color-mix(in srgb, var(--accent) 20%, transparent);
  }

  .btn-ajout,
  .btn-catalogue {
    display: flex;
    align-items: center;
    gap: 6px;
    background: var(--accent);
    color: var(--darkbg);
    border: none;
    border-radius: var(--radius-sm);
    padding: 6px 12px;
    font-family: var(--font-display);
    font-weight: 600;
    font-size: 0.85rem;
    cursor: pointer;
    white-space: nowrap;
  }
  .btn-ajout:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
  .btn-catalogue {
    background: color-mix(in srgb, var(--input) 85%, transparent);
    color: var(--text);
    border: 1px solid var(--border);
  }
  .btn-catalogue.active {
    background: var(--accent);
    color: var(--darkbg);
    border-color: var(--accent);
  }

  .catalogue-wrap {
    position: relative;
  }
  /* Les deux menus n'ont pas le même contexte horizontal :
     - Catalogue est proche du bord droit, on l'aligne donc sur la droite ;
     - Importer est sur la ligne suivante et son menu est plus large que le
       bouton. L'aligner sur la droite faisait partir le menu vers x=0. */
  .catalogue-wrap--catalogue .menu-catalogue {
    right: 0;
    left: auto;
  }
  .catalogue-wrap--import .menu-catalogue {
    left: 0;
    right: auto;
  }
  .menu-catalogue {
    position: absolute;
    top: calc(100% + 6px);
    display: flex;
    flex-direction: column;
    gap: 2px;
    padding: 6px;
    min-width: 160px;
    max-width: min(260px, calc(100vw - 24px));
    z-index: 80;
    /* Fond opaque plutôt que la classe .glass ici : ce petit menu flotte
       déjà au-dessus d'une barre d'outils elle-même en verre — empiler un
       deuxième flou dessus a déjà causé un artefact de rendu par le passé
       (voir le bug du gel de fenêtre). Un fond simple évite le risque. */
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    box-shadow: 0 8px 30px rgba(0, 0, 0, 0.35);
  }
  .menu-catalogue button {
    background: transparent;
    border: none;
    color: var(--text);
    text-align: left;
    padding: 6px 8px;
    border-radius: 6px;
    font-family: var(--font-body);
    font-size: 0.85rem;
    cursor: pointer;
  }
  .menu-catalogue button:hover {
    background: color-mix(in srgb, var(--accent) 18%, transparent);
  }

  .accueil-vide {
    padding: var(--space-5);
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
    gap: 6px;
  }
  .titre-vide {
    font-family: var(--font-display);
    font-weight: 700;
    font-size: 1.1rem;
    color: var(--text);
    margin: var(--space-2) 0 0;
  }
  .sous-titre-vide {
    color: var(--muted);
    font-size: 0.85rem;
    margin: 0;
    max-width: 36ch;
  }

  .aucun-resultat {
    color: var(--muted);
    text-align: center;
    font-size: 0.9rem;
  }


  .grille {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
    gap: var(--space-2);
  }

  .carte-jeu {
    display: flex;
    flex-direction: column;
    padding: 8px;
    text-align: left;
    cursor: pointer;
    border-radius: var(--radius-sm);
    border: 1px solid color-mix(in srgb, var(--border) 70%, transparent);
    background: linear-gradient(160deg, color-mix(in srgb, var(--card) 85%, transparent), color-mix(in srgb, var(--card) 55%, transparent));
    box-shadow: 0 6px 18px rgba(0, 0, 0, 0.22);
    transition: transform 0.2s var(--spring), box-shadow 0.2s ease, border-color 0.2s ease;
  }
  .carte-jeu:hover {
    transform: translateY(-4px);
    border-color: color-mix(in srgb, var(--accent) 55%, var(--border));
    box-shadow: 0 12px 26px rgba(0, 0, 0, 0.3), 0 0 0 1px color-mix(in srgb, var(--accent) 25%, transparent);
  }

  .cover-mini {
    position: relative;
    width: 100%;
    aspect-ratio: 3 / 4;
    border-radius: 8px;
    overflow: hidden;
    background: var(--input);
    margin-bottom: 6px;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .cover-mini img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    object-position: top center;
    transition: transform 0.35s ease;
  }
  .carte-jeu:hover .cover-mini img {
    transform: scale(1.06);
  }
  .cover-mini-placeholder {
    font-family: var(--font-display);
    font-size: 1.6rem;
    font-weight: 700;
    color: var(--muted);
  }

  .badges-coeur {
    position: absolute;
    top: 6px;
    right: 6px;
    display: flex;
    gap: 3px;
  }

  .nom-mini {
    font-family: var(--font-display);
    font-weight: 600;
    font-size: 0.85rem;
    color: var(--text);
    margin: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .statut-mini {
    display: flex;
    align-items: center;
    gap: 4px;
    color: var(--muted);
    font-size: 0.72rem;
    margin: 2px 0 0;
  }
  .point-statut {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    border: 1px solid color-mix(in srgb, var(--border) 60%, transparent);
    flex-shrink: 0;
  }
  .note-mini {
    display: flex;
    align-items: center;
    gap: 3px;
    color: var(--accent);
    font-size: 0.72rem;
    margin: 2px 0 0;
  }

  .barre-selection {
    padding: var(--space-2) var(--space-3);
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-2);
  }
  .compte-selection {
    color: var(--muted);
    font-size: 0.85rem;
  }
  .actions-selection {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }
  .btn-selection {
    display: flex;
    align-items: center;
    gap: 5px;
    background: color-mix(in srgb, var(--input) 85%, transparent);
    color: var(--text);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 5px 10px;
    font-family: var(--font-body);
    font-size: 0.8rem;
    cursor: pointer;
  }
  .btn-selection:hover:not(:disabled) {
    border-color: color-mix(in srgb, var(--accent) 50%, var(--border));
  }
  .btn-selection.danger {
    color: var(--danger);
    border-color: color-mix(in srgb, var(--danger) 50%, var(--border));
  }
  .btn-selection.danger:hover:not(:disabled) {
    background: color-mix(in srgb, var(--danger) 12%, transparent);
  }
  .btn-selection:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .carte-jeu {
    position: relative;
  }
  .carte-jeu.selectionnee {
    border-color: var(--accent);
    box-shadow: 0 0 0 2px color-mix(in srgb, var(--accent) 35%, transparent);
  }
  .case-selection {
    position: absolute;
    top: 6px;
    left: 6px;
    z-index: 2;
    background: var(--darkbg);
    border-radius: 4px;
    padding: 2px;
    display: flex;
  }
</style>
