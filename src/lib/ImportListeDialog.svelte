<script lang="ts">
  import { onMount, onDestroy } from "svelte";
  import { X, FileUp, ClipboardList, Check } from "@lucide/svelte";
  import { fade, scale } from "svelte/transition";
  import { open } from "@tauri-apps/plugin-dialog";
  import { getCurrentWebview } from "@tauri-apps/api/webview";
  import { api } from "./api";
  import { parseListeTexte, parseCsv, type LigneImport } from "./library";
  import type { StatutDefinition } from "./types";
  import { langueApp, tr } from "./i18n";

  let {
    statutsConnus,
    onImport,
    onClose,
  }: {
    statutsConnus: StatutDefinition[];
    onImport: (lignes: LigneImport[]) => void;
    onClose: () => void;
  } = $props();

  let texte = $state("");
  let erreur = $state<string | null>(null);
  let dragOver = $state(false);
  let succes = $state(false);
  let unlisten: (() => void) | null = null;
  let dernierTraitement = 0;

  // Vrai glisser-déposer natif (chemins de fichiers réels, pas juste l'API
  // HTML5 qui ne donne pas le chemin dans un webview). Un bug connu de
  // Tauri déclenche parfois l'événement "drop" deux fois pour un seul
  // dépôt — le garde-fou de 500ms ci-dessous l'empêche de traiter deux fois.
  onMount(async () => {
    unlisten = await getCurrentWebview().onDragDropEvent((event) => {
      if (event.payload.type === "over") {
        dragOver = true;
      } else if (event.payload.type === "drop") {
        dragOver = false;
        const maintenant = Date.now();
        if (maintenant - dernierTraitement < 500) return;
        dernierTraitement = maintenant;
        const chemin = event.payload.paths?.[0];
        if (chemin) void traiterFichier(chemin);
      } else {
        dragOver = false;
      }
    });
  });
  onDestroy(() => unlisten?.());

  function lignesDepuisFichier(chemin: string, contenu: string): LigneImport[] | null {
    const ext = chemin.split(".").pop()?.toLowerCase();
    if (ext === "csv") {
      const lignes = parseCsv(contenu, statutsConnus);
      return lignes.length > 0 ? lignes : null;
    }
    if (ext === "txt") {
      const lignes = parseListeTexte(contenu);
      return lignes.length > 0 ? lignes : null;
    }
    return null;
  }

  async function traiterFichier(chemin: string) {
    erreur = null;
    try {
      const contenu = await api.readTextFile(chemin);
      const lignes = lignesDepuisFichier(chemin, contenu);
      if (!lignes) {
        const bas = chemin.toLowerCase();
        erreur = bas.endsWith(".csv")
          ? "Aucune colonne « Nom » trouvée dans ce CSV."
          : bas.endsWith(".txt")
            ? "Fichier texte vide."
            : "Formats acceptés : .csv ou .txt.";
        return;
      }
      confirmerImport(lignes);
    } catch (e) {
      erreur = String(e);
    }
  }

  async function choisirFichier() {
    const selection = await open({ multiple: false, filters: [{ name: "Liste de jeux", extensions: ["csv", "txt"] }] });
    if (!selection || Array.isArray(selection)) return;
    await traiterFichier(selection);
  }

  function importerTexteColle() {
    const lignes = parseListeTexte(texte);
    if (lignes.length === 0) {
      erreur = "Colle au moins un nom de jeu, un par ligne.";
      return;
    }
    confirmerImport(lignes);
  }

  function confirmerImport(lignes: LigneImport[]) {
    erreur = null;
    succes = true;
    onImport(lignes);
    setTimeout(onClose, 700); // laisse le temps de voir la coche de succès
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
      <h2>{tr($langueApp, "Importer une liste", "Import a list")}</h2>

      <p class="eyebrow">{tr($langueApp, "Coller une liste (un nom par ligne)", "Paste a list (one name per line)")}</p>
      <textarea rows="5" placeholder={"Hadès\nCeleste\nBaldur's Gate 3"} bind:value={texte}></textarea>
      <button class="btn-action" onclick={importerTexteColle} disabled={!texte.trim()}>
        <ClipboardList size={16} strokeWidth={2.2} />
        Importer le texte collé
      </button>

      <div class="separateur"><span>{tr($langueApp, "ou", "or")}</span></div>

      <button class="zone-depot" class:dragover={dragOver} onclick={choisirFichier}>
        <FileUp size={28} strokeWidth={1.8} />
        <p class="zone-titre">{tr($langueApp, "Glisse un fichier ici", "Drop a file here")}</p>
        <p class="zone-sous-titre">{tr($langueApp, ".csv ou .txt — ou clique pour choisir", ".csv or .txt — or click to choose")}</p>
      </button>
      <p class="aide">
        CSV : colonne <code>Nom</code> obligatoire ; <code>Statut</code>, <code>Tags</code>,
        <code>Description</code>, <code>Commentaire</code> optionnelles. TXT : un nom par ligne.
      </p>

      {#if erreur}<p class="erreur">{erreur}</p>{/if}
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
    z-index: 2;
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

  textarea {
    background: color-mix(in srgb, var(--input) 85%, transparent);
    color: var(--text);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 8px 10px;
    font-family: var(--font-mono);
    font-size: 0.82rem;
    width: 100%;
    resize: vertical;
    transition: border-color 0.15s ease, box-shadow 0.15s ease;
  }
  textarea:focus {
    outline: none;
    border-color: var(--accent);
    box-shadow: 0 0 0 3px color-mix(in srgb, var(--accent) 20%, transparent);
  }

  .btn-action {
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
    transition: transform 0.15s var(--spring), filter 0.15s ease;
  }
  .btn-action:hover:not(:disabled) {
    transform: translateY(-1px);
  }
  .btn-action:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .separateur {
    display: flex;
    align-items: center;
    gap: 8px;
    color: var(--muted);
    font-size: 0.78rem;
    margin: 4px 0;
  }
  .separateur::before,
  .separateur::after {
    content: "";
    flex: 1;
    height: 1px;
    background: var(--border);
  }

  /* Zone de dépôt — le cœur du côté "moderne" demandé : bordure en
     pointillés qui réagit au survol ET au vrai glisser-déposer natif. */
  .zone-depot {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
    padding: var(--space-4) var(--space-3);
    border: 2px dashed var(--border);
    border-radius: var(--radius-sm);
    background: color-mix(in srgb, var(--input) 40%, transparent);
    color: var(--muted);
    cursor: pointer;
    transition: border-color 0.2s ease, background-color 0.2s ease, transform 0.2s var(--spring);
  }
  .zone-depot:hover {
    border-color: color-mix(in srgb, var(--accent) 60%, var(--border));
    color: var(--text);
  }
  .zone-depot.dragover {
    border-color: var(--accent);
    background: color-mix(in srgb, var(--accent) 14%, transparent);
    color: var(--text);
    transform: scale(1.02);
    box-shadow: 0 0 0 4px color-mix(in srgb, var(--accent) 18%, transparent);
  }
  .zone-titre {
    font-family: var(--font-display);
    font-weight: 600;
    font-size: 0.9rem;
    margin: 4px 0 0;
    color: inherit;
  }
  .zone-sous-titre {
    font-size: 0.76rem;
    margin: 0;
    color: var(--muted);
  }

  .aide {
    color: var(--muted);
    font-size: 0.76rem;
    margin: 0;
  }
  .aide code {
    font-family: var(--font-mono);
    background: color-mix(in srgb, var(--input) 80%, transparent);
    padding: 0 4px;
    border-radius: 3px;
  }

  .erreur {
    color: var(--danger);
    font-size: 0.82rem;
    margin: 0;
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
