<script lang="ts">
  import { Dices, Link2, Palette, Play, Trash2, Plus, X, Tags, Eye, EyeOff, Database, Download, Upload, Loader2, Info, Languages } from "@lucide/svelte";
  import { save, open } from "@tauri-apps/plugin-dialog";
  import { jouerSon, SON_LABELS, SON_ORDER } from "./sons";
  import { ONGLETS_MASQUABLES, BLOCS_RECAP, STYLES_CHRONO, type OngletMasquable } from "./types";
  import type { AppConfig, Historique, ObjectifSession, UniteDuree } from "./types";
  import { objectifEnMinutes, formaterObjectif } from "./types";
  import { ANIMATION_FAMILLES, ANIMATION_STYLE_LABELS, drawAnimations, clearAnimationNodes } from "./animations/animations";
  import { EFFECT_FAMILLES, REVEAL_EFFECT_LABELS, revealEffects } from "./effects/effects";
  import { ajouterStatut, supprimerStatut, basculerVisibiliteStatut, modifierCouleurStatut } from "./statuts";
  import { api } from "./api";
  import { tr, labelStatut } from "./i18n";
  import { APP_NAME, APP_VERSION, APP_CREATOR, APP_COPYRIGHT, APP_COPYRIGHT_EN } from "./app-meta";

  let {
    config,
    historique,
    confirmer,
    onConfigChange,
    onEffacerHistorique,
  }: {
    config: AppConfig;
    historique: Historique;
    confirmer: (message: string) => Promise<boolean>;
    onConfigChange: (cfg: AppConfig) => void;
    onEffacerHistorique: () => void;
  } = $props();

  type Categorie = "tirage" | "connexion" | "apparence" | "statuts" | "donnees" | "apropos";
  let categorie = $state<Categorie>("tirage");

  let nouveauStatutLabel = $state("");
  let nouveauStatutCouleur = $state("#89B4FA");
  let sauvegardeEnCours = $state(false);
  let restaurationEnCours = $state(false);
  let messageDonnees = $state<string | null>(null);
  // Suppression totale : deux étapes (bouton puis saisie du mot) — une
  // action irréversible ne doit jamais être à un seul clic de distance.
  let confirmationSuppression = $state(false);
  let saisieSuppression = $state("");
  let suppressionEnCours = $state(false);

  function formaterObjectifLangue(o: ObjectifSession): string {
    if (config.langue === "fr") return formaterObjectif(o);
    const unite = o.unite === "minutes" ? (o.valeur === 1 ? "minute" : "minutes")
      : o.unite === "heures" ? (o.valeur === 1 ? "hour" : "hours")
      : (o.valeur === 1 ? "day" : "days");
    return `${o.valeur} ${unite}`;
  }

  async function supprimerToutesDonnees() {
    if (saisieSuppression.trim().toUpperCase() !== "SUPPRIMER") return;
    suppressionEnCours = true;
    messageDonnees = null;
    try {
      await api.effacerToutesDonnees();
      messageDonnees = tr(config.langue, "Toutes les données ont été supprimées. Redémarre GameDraw pour repartir de zéro.", "All data has been deleted. Restart GameDraw to start fresh.");
      confirmationSuppression = false;
      saisieSuppression = "";
    } catch (e) {
      messageDonnees = `${tr(config.langue, "Échec de la suppression", "Deletion failed")} : ${e}`;
    } finally {
      suppressionEnCours = false;
    }
  }
  let motDePasseExport = $state("");
  let motDePasseImport = $state("");

  let nouvelObjectif = $state("");
  let nouvelleUnite = $state<UniteDuree>("minutes");
  let previewEnCours = $state(false);
  let previewContainerEl = $state<HTMLDivElement | null>(null);
  let previewCanvasEl = $state<HTMLCanvasElement | null>(null);

  const NOMS_DEMO = ["Hadès", "Celeste", "Baldur's Gate 3", "Disco Elysium", "Outer Wilds", "Slay the Spire"];

  async function apercuAnimationTirage() {
    if (!previewContainerEl || previewEnCours) return;
    previewEnCours = true;
    clearAnimationNodes(previewContainerEl);
    const gagnant = NOMS_DEMO[Math.floor(Math.random() * NOMS_DEMO.length)];
    const echantillon = NOMS_DEMO.filter((n) => n !== gagnant);
    await drawAnimations[config.animationStyle]({
      container: previewContainerEl,
      duration: config.animationDurationMs,
      winner: gagnant,
      sample: echantillon,
    });
    clearAnimationNodes(previewContainerEl);
    previewEnCours = false;
  }

  /** Sélectionne un style ET le joue tout de suite — un seul geste au lieu
   * de "choisir dans une liste puis cliquer Aperçu". La config est mise à
   * jour d'abord, mais l'aperçu utilise la valeur locale : `config` est une
   * prop, sa mise à jour ne se reflète pas immédiatement dans ce scope. */
  function basculerOnglet(id: OngletMasquable) {
    const masque = config.ongletsMasques.includes(id);
    onConfigChange({
      ...config,
      ongletsMasques: masque ? config.ongletsMasques.filter((x) => x !== id) : [...config.ongletsMasques, id],
    });
  }

  async function choisirEtApercuAnimation(style: AppConfig["animationStyle"]) {
    if (previewEnCours) return;
    onConfigChange({ ...config, animationStyle: style });
    if (!previewContainerEl) return;
    previewEnCours = true;
    clearAnimationNodes(previewContainerEl);
    const gagnant = NOMS_DEMO[Math.floor(Math.random() * NOMS_DEMO.length)];
    await drawAnimations[style]({
      container: previewContainerEl,
      duration: config.animationDurationMs,
      winner: gagnant,
      sample: NOMS_DEMO.filter((n) => n !== gagnant),
    });
    clearAnimationNodes(previewContainerEl);
    previewEnCours = false;
  }

  async function choisirEtApercuEffet(effet: AppConfig["revealEffect"]) {
    if (previewEnCours) return;
    onConfigChange({ ...config, revealEffect: effet });
    if (!previewCanvasEl) return;
    previewEnCours = true;
    await revealEffects[effet](previewCanvasEl, config.revealDurationMs);
    previewCanvasEl.getContext("2d")?.clearRect(0, 0, previewCanvasEl.width, previewCanvasEl.height);
    previewEnCours = false;
  }

  async function apercuEffetRevelation() {
    if (!previewCanvasEl || previewEnCours) return;
    previewEnCours = true;
    // Vraie durée respectée (v22) — le moteur peut désormais réellement
    // ralentir un effet, pas seulement le tronquer (cf. JOURNAL-DEV.md).
    await revealEffects[config.revealEffect](previewCanvasEl, config.revealDurationMs);
    previewCanvasEl.getContext("2d")?.clearRect(0, 0, previewCanvasEl.width, previewCanvasEl.height);
    previewEnCours = false;
  }

  function ajouterObjectif() {
    const n = Number(nouvelObjectif);
    if (!n || n <= 0) return;
    const existeDeja = config.objectifsDisponibles.some((o) => o.valeur === n && o.unite === nouvelleUnite);
    if (existeDeja) return;
    const nouveau: ObjectifSession = { valeur: n, unite: nouvelleUnite };
    onConfigChange({
      ...config,
      objectifsDisponibles: [...config.objectifsDisponibles, nouveau].sort(
        (a, b) => objectifEnMinutes(a) - objectifEnMinutes(b)
      ),
    });
    nouvelObjectif = "";
  }
  function retirerObjectif(o: ObjectifSession) {
    onConfigChange({
      ...config,
      objectifsDisponibles: config.objectifsDisponibles.filter((x) => !(x.valeur === o.valeur && x.unite === o.unite)),
    });
  }

  function ajouterLeStatut() {
    const label = nouveauStatutLabel.trim();
    if (!label) return;
    onConfigChange({ ...config, statuts: ajouterStatut(config.statuts, label, nouveauStatutCouleur) });
    nouveauStatutLabel = "";
  }

  async function exporterSauvegarde() {
    try {
      const dest = await save({
        defaultPath: "GameDraw-sauvegarde.zip",
        filters: [{ name: "Archive GameDraw", extensions: ["zip"] }],
      });
      if (!dest) return;
      sauvegardeEnCours = true;
      await api.exportBackup(dest, motDePasseExport);
      messageDonnees = motDePasseExport.trim()
        ? tr(config.langue, "Sauvegarde chiffrée créée avec succès — garde bien le mot de passe, il ne peut pas être récupéré.", "Encrypted backup created successfully — keep the password safe, it cannot be recovered.")
        : tr(config.langue, "Sauvegarde créée avec succès.", "Backup created successfully.");
    } catch (e) {
      messageDonnees = `${tr(config.langue, "Erreur de sauvegarde", "Backup error")} : ${String(e)}`;
    } finally {
      sauvegardeEnCours = false;
    }
  }

  async function restaurerSauvegarde() {
    const source = await open({ multiple: false, filters: [{ name: "Archive GameDraw", extensions: ["zip"] }] });
    if (!source || Array.isArray(source)) return;
    const confirme = await confirmer(
      tr(config.langue, "Restaurer cette sauvegarde va ÉCRASER toutes les données actuelles (bibliothèques, historique, réglages). Cette action est irréversible. Continuer ?", "Restoring this backup will OVERWRITE all current data (libraries, history, settings). This action cannot be undone. Continue?")
    );
    if (!confirme) return;
    try {
      restaurationEnCours = true;
      await api.importBackup(source, motDePasseImport);
      messageDonnees = tr(config.langue, "Sauvegarde restaurée — ferme et relance GameDraw pour que tout soit pris en compte.", "Backup restored — close and restart GameDraw to apply everything.");
    } catch (e) {
      messageDonnees = `${tr(config.langue, "Erreur de restauration", "Restore error")} : ${String(e)}`;
    } finally {
      restaurationEnCours = false;
    }
  }
</script>

<section class="options">
  <nav class="sidebar">
    <button class="item-sidebar" class:active={categorie === "tirage"} onclick={() => (categorie = "tirage")}>
      <Dices size={16} strokeWidth={2.2} />
      {tr(config.langue, "Tirage", "Draw")}
    </button>
    <button class="item-sidebar" class:active={categorie === "connexion"} onclick={() => (categorie = "connexion")}>
      <Link2 size={16} strokeWidth={2.2} />
      {tr(config.langue, "Connexion", "Connections")}
    </button>
    <button class="item-sidebar" class:active={categorie === "apparence"} onclick={() => (categorie = "apparence")}>
      <Palette size={16} strokeWidth={2.2} />
      {tr(config.langue, "Apparence", "Appearance")}
    </button>
    <button class="item-sidebar" class:active={categorie === "statuts"} onclick={() => (categorie = "statuts")}>
      <Tags size={16} strokeWidth={2.2} />
      {tr(config.langue, "Statuts", "Statuses")}
    </button>
    <button class="item-sidebar" class:active={categorie === "donnees"} onclick={() => (categorie = "donnees")}>
      <Database size={16} strokeWidth={2.2} />
      {tr(config.langue, "Données", "Data")}
    </button>
    <button class="item-sidebar" class:active={categorie === "apropos"} onclick={() => (categorie = "apropos")}>
      <Info size={16} strokeWidth={2.2} />
      {tr(config.langue, "À propos", "About")}
    </button>
  </nav>

  <div class="contenu">
    {#if categorie === "tirage"}
      <div class="carte-reglage">
        <p class="eyebrow">{tr(config.langue, "Raccourcis clavier", "Keyboard shortcuts")}</p>
        <div class="liste-raccourcis">
          <div class="ligne-raccourci"><kbd>{tr(config.langue, "Espace", "Space")}</kbd><span>{tr(config.langue, "Lancer un tirage", "Start a draw")}</span></div>
          <div class="ligne-raccourci"><kbd>1</kbd>–<kbd>6</kbd><span>{tr(config.langue, "Aller à un onglet", "Go to a tab")}</span></div>
          <div class="ligne-raccourci"><kbd>{tr(config.langue, "Échap", "Esc")}</kbd><span>{tr(config.langue, "Fermer une fiche", "Close game details")}</span></div>
          <div class="ligne-raccourci"><kbd>{tr(config.langue, "Clic droit", "Right click")}</kbd><span>{tr(config.langue, "Menu contextuel", "Context menu")}</span></div>
        </div>
        <p class="aide">{tr(config.langue, "Sans effet pendant une saisie de texte.", "Disabled while typing in a text field.")}</p>

        <p class="eyebrow">{tr(config.langue, "Style d’animation", "Draw animation style")} — {ANIMATION_STYLE_LABELS[config.animationStyle]}</p>
        <p class="aide">{tr(config.langue, "Clique pour choisir et prévisualiser aussitôt. Regroupés par famille.", "Click to select and preview immediately. Grouped by family.")}</p>
        {#each ANIMATION_FAMILLES as fam}
          <div class="famille">
            <p class="titre-famille">{fam.titre}</p>
            <div class="galerie">
              {#each fam.styles as s}
                <button
                  class="vignette"
                  class:active={config.animationStyle === s}
                  disabled={previewEnCours}
                  onclick={() => choisirEtApercuAnimation(s)}
                >
                  {ANIMATION_STYLE_LABELS[s]}
                </button>
              {/each}
            </div>
          </div>
        {/each}

        <p class="eyebrow">{tr(config.langue, "Effet de révélation", "Reveal effect")} — {REVEAL_EFFECT_LABELS[config.revealEffect]}</p>
        <p class="aide">{tr(config.langue, "Idem : un clic choisit et lance l’aperçu.", "Same here: one click selects and starts the preview.")}</p>
        {#each EFFECT_FAMILLES as fam}
          <div class="famille">
            <p class="titre-famille">{fam.titre}</p>
            <div class="galerie">
              {#each fam.effets as ef}
                <button
                  class="vignette"
                  class:active={config.revealEffect === ef}
                  disabled={previewEnCours}
                  onclick={() => choisirEtApercuEffet(ef)}
                >
                  {REVEAL_EFFECT_LABELS[ef]}
                </button>
              {/each}
            </div>
          </div>
        {/each}

        <div class="zone-apercu">
          <div class="scene-apercu" bind:this={previewContainerEl}>
            <canvas class="canvas-apercu" bind:this={previewCanvasEl}></canvas>
          </div>
          <div class="boutons-apercu">
            <button class="btn-apercu" onclick={apercuAnimationTirage} disabled={previewEnCours}>
              <Play size={15} strokeWidth={2.2} />
              {previewEnCours ? tr(config.langue, "En cours…", "Previewing…") : tr(config.langue, "Aperçu du tirage", "Draw preview")}
            </button>
            <button class="btn-apercu secondaire" onclick={apercuEffetRevelation} disabled={previewEnCours}>
              <Play size={15} strokeWidth={2.2} />
              {previewEnCours ? tr(config.langue, "En cours…", "Previewing…") : tr(config.langue, "Aperçu de la révélation", "Reveal preview")}
            </button>
          </div>
        </div>
      </div>

      <div class="carte-reglage">
        <label class="ligne-toggle">
          <span>{tr(config.langue, "Éviter les répétitions (pool anti-répétition)", "Avoid repeats (anti-repeat pool)")}</span>
          <button class="toggle" class:actif={config.eviterRepetitions} onclick={() => onConfigChange({ ...config, eviterRepetitions: !config.eviterRepetitions })} aria-label="Éviter les répétitions">
            <span class="pastille"></span>
          </button>
        </label>
        <label class="ligne-toggle">
          <span>{tr(config.langue, "Avertir avant un nouveau tirage si une session est active", "Warn before a new draw while a session is active")}</span>
          <button class="toggle" class:actif={config.avertirAvantNouveauTirage} onclick={() => onConfigChange({ ...config, avertirAvantNouveauTirage: !config.avertirAvantNouveauTirage })} aria-label="Avertir avant un nouveau tirage">
            <span class="pastille"></span>
          </button>
        </label>
        <label class="ligne-toggle">
          <span>{tr(config.langue, "Notifier à la fin d’une session", "Notify when a session ends")}</span>
          <button class="toggle" class:actif={config.notifierFinSession} onclick={() => onConfigChange({ ...config, notifierFinSession: !config.notifierFinSession })} aria-label="Notifier à la fin d'une session">
            <span class="pastille"></span>
          </button>
        </label>
        <label class="ligne-toggle">
          <span>{tr(config.langue, "Notifier au déblocage d’un succès (toast + notification Windows)", "Notify when an achievement is unlocked (toast + Windows notification)")}</span>
          <button class="toggle" class:actif={config.notifierSucces} onclick={() => onConfigChange({ ...config, notifierSucces: !config.notifierSucces })} aria-label="Notifier au déblocage d'un succès">
            <span class="pastille"></span>
          </button>
        </label>
      </div>

      <div class="carte-reglage">
        <p class="eyebrow">{tr(config.langue, "Sons", "Sounds")}</p>
        <p class="aide">
          Sons courts synthétisés par l'app (aucun fichier audio) : tics pendant le tirage,
          révélation du jeu, déblocage d'un succès, fin de session.
        </p>
        <label class="ligne-toggle">
          <span>{tr(config.langue, "Activer les sons", "Enable sounds")}</span>
          <button class="toggle" class:actif={config.sonsActifs} onclick={() => onConfigChange({ ...config, sonsActifs: !config.sonsActifs })} aria-label="Activer les sons">
            <span class="pastille"></span>
          </button>
        </label>
        {#if config.sonsActifs}
          <p class="eyebrow">Volume ({Math.round(config.volumeSons * 100)}%)</p>
          <input
            type="range"
            min="0"
            max="1"
            step="0.05"
            value={config.volumeSons}
            oninput={(e) => onConfigChange({ ...config, volumeSons: Number(e.currentTarget.value) })}
          />
          <div class="boutons-apercu">
            {#each SON_ORDER as s}
              <button class="btn-apercu secondaire" onclick={() => jouerSon(s, config.volumeSons)}>
                <Play size={13} strokeWidth={2.2} />
                {SON_LABELS[s]}
              </button>
            {/each}
          </div>
        {/if}
      </div>

      <div class="carte-reglage">
        <p class="eyebrow">{tr(config.langue, "Objectif de session par défaut", "Default session goal")}</p>
        <div class="ligne-objectif">
          <input
            type="number"
            min="1"
            value={config.objectifParDefaut.valeur}
            onchange={(e) => onConfigChange({ ...config, objectifParDefaut: { ...config.objectifParDefaut, valeur: Number(e.currentTarget.value) || config.objectifParDefaut.valeur } })}
          />
          <select
            value={config.objectifParDefaut.unite}
            onchange={(e) => onConfigChange({ ...config, objectifParDefaut: { ...config.objectifParDefaut, unite: e.currentTarget.value as UniteDuree } })}
          >
            <option value="minutes">{tr(config.langue, "minutes", "minutes")}</option>
            <option value="heures">{tr(config.langue, "heures", "hours")}</option>
            <option value="jours">{tr(config.langue, "jours", "days")}</option>
          </select>
        </div>

        <p class="eyebrow">{tr(config.langue, "Objectifs proposés", "Suggested goals")}</p>
        <div class="puces-objectifs">
          {#each config.objectifsDisponibles as o}
            <span class="puce-objectif">
              {formaterObjectifLangue(o)}
              <button onclick={() => retirerObjectif(o)} aria-label="Retirer {formaterObjectifLangue(o)}"><X size={11} strokeWidth={2.2} /></button>
            </span>
          {/each}
        </div>
        <div class="ajout-objectif">
          <input type="number" min="1" placeholder={tr(config.langue, "Nouvel objectif", "New goal")} bind:value={nouvelObjectif} onkeydown={(e) => e.key === "Enter" && ajouterObjectif()} />
          <select bind:value={nouvelleUnite}>
            <option value="minutes">{tr(config.langue, "minutes", "minutes")}</option>
            <option value="heures">{tr(config.langue, "heures", "hours")}</option>
            <option value="jours">{tr(config.langue, "jours", "days")}</option>
          </select>
          <button class="btn-ajout" onclick={ajouterObjectif} disabled={!nouvelObjectif}><Plus size={15} strokeWidth={2.2} /></button>
        </div>
      </div>

      <div class="carte-reglage">
        <p class="eyebrow">{config.langue === "en" ? `Saved history (${historique.entrees.length} entr${historique.entrees.length === 1 ? "y" : "ies"})` : `Historique conservé (${historique.entrees.length} entrée${historique.entrees.length > 1 ? "s" : ""})`}</p>
        <input
          type="number"
          min="1"
          value={config.nombreHistorique}
          onchange={(e) => onConfigChange({ ...config, nombreHistorique: Number(e.currentTarget.value) || config.nombreHistorique })}
        />
        <button class="btn-effacer" onclick={onEffacerHistorique}>
          <Trash2 size={15} strokeWidth={2.2} />
          {tr(config.langue, "Effacer l’historique", "Clear history")}
        </button>
      </div>
    {:else if categorie === "connexion"}
      <div class="carte-reglage">
        <p class="eyebrow">{tr(config.langue, "Clé API RAWG", "RAWG API key")}</p>
        <input type="text" placeholder="Clé API RAWG" value={config.rawgApiKey} onchange={(e) => onConfigChange({ ...config, rawgApiKey: e.currentTarget.value })} />
        <p class="aide">{tr(config.langue, "Utilisée dans la Fiche du jeu pour la recherche automatique de jaquette.", "Used in the game details view for automatic cover searches.")}</p>
      </div>
      <div class="carte-reglage">
        <p class="eyebrow">{tr(config.langue, "Clé API Steam", "Steam API key")}</p>
        <input type="text" placeholder="Clé API Steam" value={config.steamApiKey} onchange={(e) => onConfigChange({ ...config, steamApiKey: e.currentTarget.value })} />
        <p class="eyebrow">SteamID64</p>
        <input type="text" placeholder="SteamID64" value={config.steamId64} onchange={(e) => onConfigChange({ ...config, steamId64: e.currentTarget.value })} />
        <p class="aide">{tr(config.langue, "Utilisées dans Bibliothèque → Importer → Depuis Steam.", "Used in Library → Import → From Steam.")}</p>
      </div>
      <div class="carte-reglage">
        <p class="eyebrow">{tr(config.langue, "Clé API SteamGridDB (optionnelle)", "SteamGridDB API key (optional)")}</p>
        <input type="text" placeholder="Clé API SteamGridDB" value={config.steamgriddbApiKey} onchange={(e) => onConfigChange({ ...config, steamgriddbApiKey: e.currentTarget.value })} />
        <p class="aide">
          En complément (pas en remplacement) du bouton "Chercher sur SteamGridDB" de la Fiche
          du jeu, qui ouvre une fenêtre intégrée sans avoir besoin de clé. Renseigne une clé ici
          pour obtenir en plus une recherche automatisée avec résultats affichés dans l'app.
        </p>
      </div>
      <div class="carte-reglage">
        <p class="eyebrow">{tr(config.langue, "Sources de recherche automatique de jaquette actives", "Enabled automatic cover search sources")}</p>
        <p class="aide">{tr(config.langue, "Désactive une source pour ne plus la voir proposée dans la Fiche du jeu.", "Disable a source to hide it from the game details view.")}</p>
        <label class="ligne-toggle">
          <span>Steam (aucune clé)</span>
          <button class="toggle" class:actif={config.sourcesCoverActives.steam} onclick={() => onConfigChange({ ...config, sourcesCoverActives: { ...config.sourcesCoverActives, steam: !config.sourcesCoverActives.steam } })} aria-label="Activer Steam">
            <span class="pastille"></span>
          </button>
        </label>
        <label class="ligne-toggle">
          <span>RAWG</span>
          <button class="toggle" class:actif={config.sourcesCoverActives.rawg} onclick={() => onConfigChange({ ...config, sourcesCoverActives: { ...config.sourcesCoverActives, rawg: !config.sourcesCoverActives.rawg } })} aria-label="Activer RAWG">
            <span class="pastille"></span>
          </button>
        </label>
        <label class="ligne-toggle">
          <span>SteamGridDB</span>
          <button class="toggle" class:actif={config.sourcesCoverActives.steamgriddb} onclick={() => onConfigChange({ ...config, sourcesCoverActives: { ...config.sourcesCoverActives, steamgriddb: !config.sourcesCoverActives.steamgriddb } })} aria-label="Activer SteamGridDB">
            <span class="pastille"></span>
          </button>
        </label>
      </div>
    {:else if categorie === "apparence"}
      <div class="carte-reglage">
        <p class="eyebrow">{tr(config.langue, "Densité d’affichage", "Display density")}</p>
        <select value={config.densite} onchange={(e) => onConfigChange({ ...config, densite: e.currentTarget.value as AppConfig["densite"] })}>
          <option value="compact">{tr(config.langue, "Compact", "Compact")}</option>
          <option value="normal">{tr(config.langue, "Normal", "Normal")}</option>
          <option value="confortable">{tr(config.langue, "Confortable", "Comfortable")}</option>
          <option value="spacieux">{tr(config.langue, "Spacieux (zone élargie)", "Spacious (wider area)")}</option>
        </select>

        <label class="ligne-toggle">
          <span>{tr(config.langue, "Afficher la jaquette du jeu tiré dans le résultat", "Show the drawn game cover in the result")}</span>
          <button class="toggle" class:actif={config.afficherCoverResultat} onclick={() => onConfigChange({ ...config, afficherCoverResultat: !config.afficherCoverResultat })} aria-label="Afficher la jaquette au résultat">
            <span class="pastille"></span>
          </button>
        </label>
        <label class="ligne-toggle">
          <span>{tr(config.langue, "Afficher le récap en haut de l’onglet Tirage", "Show the summary at the top of the Draw tab")}</span>
          <button class="toggle" class:actif={config.afficherRecap} onclick={() => onConfigChange({ ...config, afficherRecap: !config.afficherRecap })} aria-label="Afficher le récap">
            <span class="pastille"></span>
          </button>
        </label>
        {#if config.afficherRecap}
          <p class="aide">{tr(config.langue, "Blocs affichés dans le récap — décoche ceux qui ne te servent pas.", "Blocks shown in the recap — uncheck the ones you do not need.")}</p>
          <div class="galerie">
            {#each BLOCS_RECAP as b}
              <button
                class="vignette"
                class:active={!config.blocsRecapMasques.includes(b.id)}
                onclick={() => onConfigChange({
                  ...config,
                  blocsRecapMasques: config.blocsRecapMasques.includes(b.id)
                    ? config.blocsRecapMasques.filter((x) => x !== b.id)
                    : [...config.blocsRecapMasques, b.id],
                })}
              >
                {b.label}
              </button>
            {/each}
          </div>
        {/if}

        <p class="eyebrow">{tr(config.langue, "Affichage du compte à rebours", "Countdown display")}</p>
        <p class="aide">{STYLES_CHRONO.find((s) => s.id === config.styleChrono)?.description ?? ""}</p>
        <div class="galerie">
          {#each STYLES_CHRONO as s}
            <button
              class="vignette"
              class:active={config.styleChrono === s.id}
              onclick={() => onConfigChange({ ...config, styleChrono: s.id })}
            >
              {s.label}
            </button>
          {/each}
        </div>

        <p class="eyebrow">{tr(config.langue, "Transition entre les onglets", "Tab transition")}</p>
        <select value={config.transitionOnglets} onchange={(e) => onConfigChange({ ...config, transitionOnglets: e.currentTarget.value as AppConfig["transitionOnglets"] })}>
          <option value="glissement">{tr(config.langue, "Glissement (suit le sens de navigation)", "Slide (follows navigation direction)")}</option>
          <option value="fondu">{tr(config.langue, "Fondu simple", "Simple fade")}</option>
          <option value="aucune">{tr(config.langue, "Aucune (instantané)", "None (instant)")}</option>
        </select>
      </div>

      <div class="carte-reglage">
        <p class="eyebrow">{tr(config.langue, "Onglets affichés", "Visible tabs")}</p>
        <p class="aide">
          Masque les onglets dont tu ne te sers pas pour alléger la barre de navigation. Tirage
          et Options restent toujours visibles (sans Options, impossible de revenir en arrière).
        </p>
        {#each ONGLETS_MASQUABLES as o}
          <label class="ligne-toggle">
            <span>{o.label}</span>
            <button
              class="toggle"
              class:actif={!config.ongletsMasques.includes(o.id)}
              onclick={() => basculerOnglet(o.id)}
              aria-label="Afficher l'onglet {o.label}"
            >
              <span class="pastille"></span>
            </button>
          </label>
        {/each}
      </div>
      <div class="carte-reglage">
        <label class="ligne-toggle">
          <span>{tr(config.langue, "Afficher le sélecteur de thème dans l’en-tête", "Show the theme selector in the header")}</span>
          <button class="toggle" class:actif={config.afficherSelecteurTheme} onclick={() => onConfigChange({ ...config, afficherSelecteurTheme: !config.afficherSelecteurTheme })} aria-label="Afficher le sélecteur de thème">
            <span class="pastille"></span>
          </button>
        </label>
        <label class="ligne-toggle">
          <span>{tr(config.langue, "Animer la pastille « En cours » dans le Backlog (clignotement)", "Animate the In progress indicator in Backlog (pulse)")}</span>
          <button
            class="toggle"
            class:actif={config.ledAnimation === "pulse"}
            onclick={() => onConfigChange({ ...config, ledAnimation: config.ledAnimation === "pulse" ? "fixe" : "pulse" })}
            aria-label="Animer la pastille du Backlog"
          >
            <span class="pastille"></span>
          </button>
        </label>
        <label class="ligne-toggle">
          <span>{tr(config.langue, "Réduire dans la barre système à la fermeture (menu clic droit Ouvrir/Quitter)", "Minimize to system tray on close (right-click Open/Quit menu)")}</span>
          <button
            class="toggle"
            class:actif={config.reduireBarreSysteme}
            onclick={() => onConfigChange({ ...config, reduireBarreSysteme: !config.reduireBarreSysteme })}
            aria-label="Réduire dans la barre système"
          >
            <span class="pastille"></span>
          </button>
        </label>
        <p class="aide">{tr(config.langue, "Nécessite de redémarrer GameDraw pour s’appliquer.", "Requires restarting GameDraw to apply.")}</p>
      </div>
      <div class="carte-reglage">
        <p class="eyebrow">{tr(config.langue, "Identité visuelle Windows", "Windows app icon")}</p>
        <p class="aide">
          {tr(config.langue,
            "Choisis une icône transparente pour la fenêtre, la barre des tâches et la barre système. L'exécutable et les raccourcis installés gardent l'icône claire par défaut.",
            "Choose a transparent icon for the window, taskbar and system tray. The executable and installed shortcuts keep the light icon by default.")}
        </p>
        <div class="choix-icone-fenetre">
          <button
            class="option-icone-fenetre"
            class:active={config.iconeFenetre !== "sombre"}
            aria-pressed={config.iconeFenetre !== "sombre"}
            onclick={() => onConfigChange({ ...config, iconeFenetre: "defaut" })}
          >
            <img src="/icons/gamedraw-light.png" alt="" width="74" height="74" />
            <strong>{tr(config.langue, "Clair / Blanc", "Light / White")}</strong>
            <small>{tr(config.langue, "Par défaut", "Default")}</small>
          </button>
          <button
            class="option-icone-fenetre"
            class:active={config.iconeFenetre === "sombre"}
            aria-pressed={config.iconeFenetre === "sombre"}
            onclick={() => onConfigChange({ ...config, iconeFenetre: "sombre" })}
          >
            <img src="/icons/gamedraw-dark.png" alt="" width="74" height="74" />
            <strong>{tr(config.langue, "Sombre / Noir", "Dark / Black")}</strong>
            <small>{tr(config.langue, "Alternative", "Alternative")}</small>
          </button>
        </div>
        <p class="aide">
          {tr(config.langue,
            "Pour changer un raccourci du Bureau : clic droit → Propriétés → Changer d’icône, puis sélectionne GameDraw-Dark.ico dans le dossier d’installation (ou dans Livrables\Icones-Windows après Release).",
            "For a desktop shortcut: right-click → Properties → Change Icon, then select GameDraw-Dark.ico from the installed resources (or from Livrables\Icones-Windows after Release).")}
        </p>
      </div>
    {:else if categorie === "statuts"}
      <div class="carte-reglage">
        <p class="eyebrow">{tr(config.langue, "Statuts existants", "Existing statuses")}</p>
        <p class="aide">
          Masquer un statut le retire des sélecteurs (Fiche, filtres) sans toucher aux jeux qui
          l'ont déjà — seuls les statuts personnalisés (pas les 5 d'origine) peuvent être supprimés.
        </p>
        <div class="liste-statuts">
          {#each config.statuts as s (s.id)}
            <div class="ligne-statut">
              {#if s.integre}
                <span class="pastille-couleur" style="background: {s.couleur}" title="Suit le thème actif"></span>
              {:else}
                <input
                  type="color"
                  class="pastille-couleur-input"
                  value={s.couleur}
                  onchange={(e) => onConfigChange({ ...config, statuts: modifierCouleurStatut(config.statuts, s.id, e.currentTarget.value) })}
                  aria-label="Couleur de {s.label}"
                />
              {/if}
              <span class="label-statut">{labelStatut(config.langue, s.id, s.label, s.integre)}</span>
              {#if s.integre}<span class="puce-integre">{tr(config.langue, "intégré", "built-in")}</span>{/if}
              <button
                class="btn-icone"
                onclick={() => onConfigChange({ ...config, statuts: basculerVisibiliteStatut(config.statuts, s.id) })}
                aria-label={s.visible ? `Masquer ${s.label}` : `Afficher ${s.label}`}
                title={s.visible ? "Visible" : "Masqué"}
              >
                {#if s.visible}<Eye size={15} strokeWidth={2.2} />{:else}<EyeOff size={15} strokeWidth={2.2} />{/if}
              </button>
              <button
                class="btn-icone danger"
                onclick={() => onConfigChange({ ...config, statuts: supprimerStatut(config.statuts, s.id) })}
                disabled={s.integre}
                aria-label="Supprimer {s.label}"
                title={s.integre ? "Statuts d'origine non supprimables" : "Supprimer"}
              >
                <Trash2 size={14} strokeWidth={2.2} />
              </button>
            </div>
          {/each}
        </div>

        <p class="eyebrow">{tr(config.langue, "Ajouter un statut personnalisé", "Add a custom status")}</p>
        <div class="ajout-statut">
          <input type="color" bind:value={nouveauStatutCouleur} aria-label={tr(config.langue, "Couleur du nouveau statut", "New status color")} />
          <input
            type="text"
            placeholder={tr(config.langue, "Nom du statut (ex. En rejeu)", "Status name (e.g. Replay)")}
            bind:value={nouveauStatutLabel}
            onkeydown={(e) => e.key === "Enter" && ajouterLeStatut()}
          />
          <button class="btn-ajout" onclick={ajouterLeStatut} disabled={!nouveauStatutLabel.trim()}>
            <Plus size={15} strokeWidth={2.2} />
          </button>
        </div>
      </div>
    {:else if categorie === "donnees"}
      <div class="carte-reglage">
        <p class="eyebrow">{tr(config.langue, "Importer des jeux", "Import games")}</p>
        <p class="aide">
          {tr(config.langue,
            "L’import (Steam, liste/CSV, archive .zip d’une bibliothèque exportée) se fait depuis Bibliothèque → Importer : il est propre à chaque plateforme et reste géré là où la plateforme active est déjà sélectionnée.",
            "Importing (Steam, list/CSV, exported library .zip) is done from Library → Import: it is platform-specific and stays where the active platform is already selected."
          )}
        </p>
      </div>

      <div class="carte-reglage">
        <p class="eyebrow">{tr(config.langue, "Sauvegarde complète", "Full backup")}</p>
        <p class="aide">
          {tr(config.langue,
            "Exporte tout le dossier de données (réglages, plateformes, toutes les bibliothèques, jaquettes et historique) en une seule archive. L’export Bibliothèque → Exporter ne couvre qu’une plateforme.",
            "Exports the whole data folder (settings, platforms, all libraries, covers and history) into one archive. Library → Export only covers one platform."
          )}
        </p>
        <p class="eyebrow">{tr(config.langue, "Mot de passe (optionnel)", "Password (optional)")}</p>
        <input type="password" placeholder={tr(config.langue, "Laisser vide pour ne pas chiffrer", "Leave empty for no encryption")} bind:value={motDePasseExport} />
        <p class="aide">
          {#if motDePasseExport.trim()}
            {tr(config.langue, "L’archive sera chiffrée (AES-256) — garde ce mot de passe, il ne peut pas être récupéré s’il est perdu.", "The archive will be encrypted (AES-256) — keep this password safe, it cannot be recovered if lost.")}
          {:else}
            {tr(config.langue, "Aucun mot de passe : l’archive ne sera pas chiffrée.", "No password: the archive will not be encrypted.")}
          {/if}
        </p>
        <button class="btn-sauvegarde" onclick={exporterSauvegarde} disabled={sauvegardeEnCours}>
          {#if sauvegardeEnCours}<Loader2 size={15} strokeWidth={2.2} class="spin" />{:else}<Download size={15} strokeWidth={2.2} />{/if}
          {tr(config.langue, "Créer une sauvegarde", "Create backup")}
        </button>
      </div>

      <div class="carte-reglage">
        <p class="eyebrow">{tr(config.langue, "Restauration", "Restore")}</p>
        <p class="aide aide-danger">
          ⚠️ {tr(config.langue, "Écrase toutes les données actuelles avec le contenu de la sauvegarde choisie — action irréversible. Un redémarrage de l’app est nécessaire après restauration.", "Overwrites all current data with the selected backup — this cannot be undone. Restart the app after restoring.")}
        </p>
        <p class="eyebrow">{tr(config.langue, "Mot de passe (optionnel — seulement si l’archive en avait un)", "Password (optional — only if the archive had one)")}</p>
        <input type="password" placeholder={tr(config.langue, "Laisser vide si l’archive n’est pas chiffrée", "Leave empty if the archive is not encrypted")} bind:value={motDePasseImport} />
        <button class="btn-restaurer" onclick={restaurerSauvegarde} disabled={restaurationEnCours}>
          {#if restaurationEnCours}<Loader2 size={15} strokeWidth={2.2} class="spin" />{:else}<Upload size={15} strokeWidth={2.2} />{/if}
          {tr(config.langue, "Restaurer une sauvegarde", "Restore backup")}
        </button>
        {#if messageDonnees}<p class="message-donnees">{messageDonnees}</p>{/if}
      </div>

      <div class="carte-reglage zone-danger">
        <p class="eyebrow danger">⚠️ {tr(config.langue, "Zone de danger", "Danger zone")}</p>
        <p class="aide">
          {tr(config.langue,
            "Supprime toutes les données de GameDraw : jeux, plateformes, historique, succès, réglages et jaquettes téléchargées. Cette action est irréversible — exporte une sauvegarde avant si nécessaire.",
            "Deletes all GameDraw data: games, platforms, history, achievements, settings and downloaded covers. This cannot be undone — export a backup first if needed."
          )}
        </p>
        {#if !confirmationSuppression}
          <button class="btn-danger" onclick={() => (confirmationSuppression = true)}>
            <Trash2 size={15} strokeWidth={2.2} />
            {tr(config.langue, "Supprimer toutes les données…", "Delete all data…")}
          </button>
        {:else}
          <!-- Seconde étape : il faut TAPER le mot, un simple clic ne suffit
               pas pour une action irréversible. -->
          <p class="aide-danger">
            {tr(config.langue, "Pour confirmer, tape", "To confirm, type")} <code>SUPPRIMER</code> {tr(config.langue, "ci-dessous :", "below:")}
          </p>
          <input type="text" placeholder="SUPPRIMER" bind:value={saisieSuppression} />
          <div class="actions-danger">
            <button
              class="btn-danger"
              disabled={saisieSuppression.trim().toUpperCase() !== "SUPPRIMER" || suppressionEnCours}
              onclick={supprimerToutesDonnees}
            >
              {#if suppressionEnCours}<Loader2 size={15} strokeWidth={2.2} class="spin" />{:else}<Trash2 size={15} strokeWidth={2.2} />{/if}
              {tr(config.langue, "Confirmer la suppression définitive", "Confirm permanent deletion")}
            </button>
            <button class="btn-annuler" onclick={() => { confirmationSuppression = false; saisieSuppression = ""; }}>
              {tr(config.langue, "Annuler", "Cancel")}
            </button>
          </div>
        {/if}
      </div>
    {:else if categorie === "apropos"}
      <div class="carte-reglage carte-apropos">
        <div class="apropos-entete">
          <div class="apropos-logo">🎲</div>
          <div>
            <p class="apropos-nom">{APP_NAME}</p>
            <p class="apropos-version">{tr(config.langue, "Version", "Version")} {APP_VERSION}</p>
          </div>
        </div>
        <p class="aide apropos-description">
          {tr(config.langue, "Application locale de tirage et de gestion de bibliothèque de jeux vidéo, conçue pour Windows.", "Local-first game drawing and video game library management app designed for Windows.")}
        </p>
      </div>

      <div class="carte-reglage">
        <p class="eyebrow"><Languages size={15} strokeWidth={2.2} /> {tr(config.langue, "Langue de l’interface", "Interface language")}</p>
        <div class="choix-langue" role="group" aria-label={tr(config.langue, "Langue de l’interface", "Interface language")}>
          <button class="btn-langue" class:active={config.langue === "fr"} onclick={() => onConfigChange({ ...config, langue: "fr" })}>🇫🇷 Français</button>
          <button class="btn-langue" class:active={config.langue === "en"} onclick={() => onConfigChange({ ...config, langue: "en" })}>🇬🇧 English</button>
        </div>
        <p class="aide">{tr(config.langue, "Le choix est enregistré automatiquement dans la configuration locale.", "Your choice is automatically saved in the local configuration.")}</p>
      </div>

      <div class="carte-reglage">
        <p class="eyebrow">{tr(config.langue, "Créateur", "Creator")}</p>
        <p class="credit-createur">{APP_CREATOR}</p>
        <p class="aide">{config.langue === "en" ? APP_COPYRIGHT_EN : APP_COPYRIGHT}</p>
      </div>

      <div class="carte-reglage">
        <p class="eyebrow">{tr(config.langue, "Technologies", "Technology")}</p>
        <p class="aide">Tauri 2 · Rust · Svelte 5 · TypeScript</p>
        <p class="aide">{tr(config.langue, "Données locales, sans télémétrie intégrée.", "Local data, with no built-in telemetry.")}</p>
      </div>
    {/if}
  </div>
</section>

<style>

  .carte-apropos {
    background: linear-gradient(135deg, color-mix(in srgb, var(--accent) 12%, var(--surface)), var(--surface));
  }
  .apropos-entete { display: flex; align-items: center; gap: var(--space-3); }
  .apropos-logo {
    width: 52px; height: 52px; display: grid; place-items: center;
    border-radius: 16px; font-size: 28px; background: color-mix(in srgb, var(--accent) 16%, transparent);
    border: 1px solid color-mix(in srgb, var(--accent) 35%, transparent);
  }
  .apropos-nom { margin: 0; font-family: var(--font-display); font-weight: 700; font-size: 1.35rem; }
  .apropos-version { margin: 2px 0 0; color: var(--muted); font-family: var(--font-mono); font-size: .8rem; }
  .apropos-description { margin-top: var(--space-3); }
  .choix-langue { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: var(--space-2); }
  .btn-langue {
    padding: 10px 12px; border-radius: 10px; border: 1px solid var(--border);
    background: var(--surface-2); color: var(--text); cursor: pointer; font-weight: 650;
  }
  .btn-langue:hover { border-color: color-mix(in srgb, var(--accent) 55%, var(--border)); }
  .btn-langue.active { border-color: var(--accent); background: color-mix(in srgb, var(--accent) 14%, var(--surface-2)); }
  .credit-createur { margin: 0; font-size: 1.05rem; font-weight: 700; color: var(--accent); }
  .options {
    display: grid;
    grid-template-columns: 160px 1fr;
    gap: var(--space-3);
    align-items: start;
    width: 100%;
  }
  @media (max-width: 520px) {
    .options {
      grid-template-columns: 1fr;
    }
  }

  .sidebar {
    display: flex;
    flex-direction: column;
    gap: 2px;
    padding: 6px;
    border-radius: var(--radius);
    border: 1px solid color-mix(in srgb, var(--border) 70%, transparent);
    background: linear-gradient(160deg, color-mix(in srgb, var(--card) 85%, transparent), color-mix(in srgb, var(--card) 55%, transparent));
    box-shadow: 0 6px 18px rgba(0, 0, 0, 0.22);
  }
  .item-sidebar {
    display: flex;
    align-items: center;
    gap: 8px;
    background: transparent;
    color: var(--muted);
    border: none;
    border-radius: var(--radius-sm);
    padding: 8px 10px;
    font-family: var(--font-display);
    font-weight: 600;
    font-size: 0.9rem;
    cursor: pointer;
    text-align: left;
    transition: background-color 0.15s ease, color 0.15s ease;
  }
  .item-sidebar:hover {
    background: color-mix(in srgb, var(--accent) 12%, transparent);
    color: var(--text);
  }
  .item-sidebar.active {
    background: var(--accent);
    color: var(--darkbg);
    box-shadow: 0 2px 14px color-mix(in srgb, var(--glow) 45%, transparent);
  }

  .contenu {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    min-width: 0;
  }

  .carte-reglage {
    padding: var(--space-3);
    display: flex;
    flex-direction: column;
    gap: 8px;
    width: 100%;
    min-width: 0;
    border-radius: var(--radius);
    border: 1px solid color-mix(in srgb, var(--border) 70%, transparent);
    background: linear-gradient(160deg, color-mix(in srgb, var(--card) 85%, transparent), color-mix(in srgb, var(--card) 55%, transparent));
    box-shadow: 0 6px 18px rgba(0, 0, 0, 0.22);
  }

  select,
  input[type="text"],
  input[type="number"],
  input[type="password"] {
    background: color-mix(in srgb, var(--input) 85%, transparent);
    color: var(--text);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 6px 10px;
    font-family: var(--font-body);
    font-size: 0.85rem;
    width: 100%;
  }
  input[type="range"] {
    width: 100%;
    accent-color: var(--accent);
  }

  .aide {
    color: var(--muted);
    font-size: 0.76rem;
    margin: 0;
  }

  .ligne-toggle {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-3);
    font-size: 0.85rem;
    color: var(--text);
  }
  .toggle {
    width: 38px;
    height: 22px;
    border-radius: 999px;
    background: var(--input);
    border: 1px solid var(--border);
    position: relative;
    cursor: pointer;
    flex-shrink: 0;
    transition: background-color 0.2s ease;
  }
  .toggle:disabled {
    opacity: 0.45;
    cursor: not-allowed;
  }
  .toggle .pastille {
    position: absolute;
    top: 2px;
    left: 2px;
    width: 16px;
    height: 16px;
    border-radius: 50%;
    background: var(--muted);
    transition: transform 0.2s var(--spring), background-color 0.2s ease;
  }
  .toggle.actif {
    background: color-mix(in srgb, var(--accent) 35%, var(--input));
    border-color: var(--accent);
  }
  .toggle.actif .pastille {
    transform: translateX(16px);
    background: var(--accent);
  }

  .zone-apercu {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
    margin-top: 4px;
  }
  .scene-apercu {
    position: relative;
    width: 100%;
    min-height: 140px;
    border-radius: var(--radius-sm);
    background: color-mix(in srgb, var(--darkbg) 60%, transparent);
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
  }
  .canvas-apercu {
    position: absolute;
    inset: 0;
    pointer-events: none;
  }
  /* Galerie de sélection (styles d'animation / effets de révélation) —
     remplace une liste déroulante : tout est visible d'un coup d'œil et un
     seul clic sélectionne ET lance l'aperçu. */
  .famille {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .titre-famille {
    font-size: 0.74rem;
    color: var(--muted);
    margin: 4px 0 0;
    font-weight: 600;
  }

  .galerie {
    display: flex;
    flex-wrap: wrap;
    gap: 5px;
  }
  .vignette {
    background: color-mix(in srgb, var(--input) 80%, transparent);
    color: var(--muted);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 5px 11px;
    font-family: var(--font-body);
    font-size: 0.78rem;
    cursor: pointer;
    transition: color 0.15s ease, border-color 0.15s ease, background-color 0.15s ease, transform 0.15s ease;
  }
  .vignette:hover:not(:disabled) {
    transform: translateY(-1px);
    color: var(--text);
    border-color: color-mix(in srgb, var(--accent) 50%, var(--border));
  }
  .vignette.active {
    background: color-mix(in srgb, var(--accent) 20%, transparent);
    color: var(--text);
    border-color: var(--accent);
    box-shadow: 0 0 10px color-mix(in srgb, var(--accent) 30%, transparent);
  }
  .vignette:disabled {
    opacity: 0.5;
    cursor: default;
  }

  .liste-raccourcis {
    display: flex;
    flex-direction: column;
    gap: 5px;
  }
  .ligne-raccourci {
    display: flex;
    align-items: center;
    gap: 6px;
    color: var(--muted);
    font-size: 0.8rem;
  }
  .ligne-raccourci kbd {
    background: color-mix(in srgb, var(--input) 90%, transparent);
    border: 1px solid var(--border);
    border-bottom-width: 2px;
    border-radius: 4px;
    padding: 1px 7px;
    font-family: var(--font-mono, monospace);
    font-size: 0.74rem;
    color: var(--text);
  }
  .ligne-raccourci span {
    margin-left: 4px;
  }

  .boutons-apercu {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    justify-content: center;
  }
  .btn-apercu {
    display: flex;
    align-items: center;
    gap: 6px;
    background: var(--accent);
    color: var(--darkbg);
    border: none;
    border-radius: var(--radius-sm);
    padding: 8px 16px;
    font-family: var(--font-display);
    font-weight: 700;
    font-size: 0.9rem;
    cursor: pointer;
  }
  .btn-apercu.secondaire {
    background: transparent;
    color: var(--accent);
    border: 1px solid color-mix(in srgb, var(--accent) 50%, transparent);
  }
  .btn-apercu:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .puces-objectifs {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }
  .puce-objectif {
    display: flex;
    align-items: center;
    gap: 4px;
    background: color-mix(in srgb, var(--accent) 15%, transparent);
    color: var(--text);
    border: 1px solid color-mix(in srgb, var(--accent) 40%, var(--border));
    border-radius: 999px;
    padding: 3px 6px 3px 10px;
    font-size: 0.8rem;
  }
  .puce-objectif button {
    background: transparent;
    border: none;
    color: var(--muted);
    cursor: pointer;
    padding: 2px;
    display: flex;
  }
  .puce-objectif button:hover {
    color: var(--danger);
  }

  .ligne-objectif {
    display: flex;
    gap: 6px;
  }
  .ligne-objectif input {
    flex: 1;
  }
  .ligne-objectif select {
    width: auto;
    flex-shrink: 0;
  }

  .ajout-objectif {
    display: flex;
    gap: 6px;
  }
  .ajout-objectif input {
    flex: 1;
  }
  .ajout-objectif select {
    width: auto;
    flex-shrink: 0;
  }
  .btn-ajout {
    background: color-mix(in srgb, var(--accent) 20%, var(--input));
    color: var(--accent);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 0 10px;
    cursor: pointer;
    display: flex;
    align-items: center;
  }
  .btn-ajout:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  /* Zone de danger : visuellement distincte du reste pour qu'on ne clique
     pas dedans par inadvertance en parcourant les options. */
  .zone-danger {
    border-color: color-mix(in srgb, var(--danger) 45%, transparent);
    background: linear-gradient(160deg, color-mix(in srgb, var(--danger) 8%, transparent), transparent);
  }
  .eyebrow.danger {
    color: var(--danger);
  }
  .aide-danger {
    color: var(--danger);
    font-size: 0.82rem;
    margin: 0;
  }
  .aide-danger code {
    background: color-mix(in srgb, var(--danger) 18%, transparent);
    padding: 1px 6px;
    border-radius: 4px;
    font-family: var(--font-mono, monospace);
  }
  .actions-danger {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
  }
  .btn-danger {
    display: flex;
    align-items: center;
    gap: 6px;
    background: var(--danger);
    color: #fff;
    border: none;
    border-radius: var(--radius-sm);
    padding: 8px 14px;
    font-family: var(--font-display);
    font-weight: 700;
    font-size: 0.85rem;
    cursor: pointer;
  }
  .btn-danger:disabled {
    opacity: 0.45;
    cursor: not-allowed;
  }
  .btn-annuler {
    background: transparent;
    color: var(--muted);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 8px 14px;
    font-family: var(--font-body);
    font-size: 0.85rem;
    cursor: pointer;
  }

  .btn-effacer {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    background: transparent;
    border: 1px solid color-mix(in srgb, var(--danger) 50%, var(--border));
    color: var(--danger);
    border-radius: var(--radius-sm);
    padding: 8px 12px;
    font-family: var(--font-body);
    font-size: 0.82rem;
    cursor: pointer;
    align-self: flex-start;
  }
  .btn-effacer:hover {
    background: color-mix(in srgb, var(--danger) 12%, transparent);
  }

  .choix-icone-fenetre {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 10px;
  }
  .option-icone-fenetre {
    min-width: 0;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
    background: color-mix(in srgb, var(--input) 80%, transparent);
    color: var(--text);
    border: 1px solid var(--border);
    font-family: var(--font-body);
    font-size: 0.85rem;
    padding: 12px;
    border-radius: var(--radius-sm);
    cursor: pointer;
    transition: border-color 0.15s ease, background-color 0.15s ease;
  }
  .option-icone-fenetre img {
    display: block;
    max-width: 100%;
    object-fit: contain;
    filter: drop-shadow(0 3px 7px #0004);
  }
  .option-icone-fenetre small { color: var(--muted); }
  .option-icone-fenetre:hover { border-color: var(--accent); }
  .option-icone-fenetre.active {
    background: color-mix(in srgb, var(--accent) 13%, var(--input));
    border-color: var(--accent);
  }
  @media (max-width: 440px) {
    .choix-icone-fenetre { grid-template-columns: 1fr 1fr; }
    .option-icone-fenetre { padding: 7px; }
    .option-icone-fenetre img { width: 56px; height: 56px; }
  }

  .liste-statuts {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .ligne-statut {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 4px 0;
  }
  .pastille-couleur {
    width: 16px;
    height: 16px;
    border-radius: 50%;
    flex-shrink: 0;
  }
  .pastille-couleur-input {
    width: 22px;
    height: 22px;
    padding: 0;
    border: 1px solid var(--border);
    border-radius: 50%;
    background: none;
    cursor: pointer;
    flex-shrink: 0;
  }
  .label-statut {
    flex: 1;
    font-size: 0.85rem;
    color: var(--text);
  }
  .puce-integre {
    background: color-mix(in srgb, var(--input) 90%, transparent);
    color: var(--muted);
    font-size: 0.68rem;
    padding: 2px 7px;
    border-radius: 999px;
  }
  .btn-icone {
    background: transparent;
    border: none;
    color: var(--muted);
    cursor: pointer;
    padding: 4px;
    border-radius: 6px;
    display: flex;
  }
  .btn-icone:hover:not(:disabled) {
    color: var(--text);
    background: color-mix(in srgb, var(--input) 80%, transparent);
  }
  .btn-icone.danger:hover:not(:disabled) {
    color: var(--danger);
  }
  .btn-icone:disabled {
    opacity: 0.3;
    cursor: not-allowed;
  }

  .ajout-statut {
    display: flex;
    gap: 6px;
    align-items: center;
  }
  .ajout-statut input[type="text"] {
    flex: 1;
  }
  .ajout-statut input[type="color"] {
    width: 32px;
    height: 32px;
    padding: 0;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    background: none;
    cursor: pointer;
    flex-shrink: 0;
  }

  .aide-danger {
    color: var(--danger);
  }

  .btn-sauvegarde,
  .btn-restaurer {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    border-radius: var(--radius-sm);
    padding: 8px 14px;
    font-family: var(--font-display);
    font-weight: 600;
    font-size: 0.9rem;
    cursor: pointer;
    align-self: flex-start;
  }
  .btn-sauvegarde {
    background: var(--accent);
    color: var(--darkbg);
    border: none;
  }
  .btn-restaurer {
    background: transparent;
    border: 1px solid color-mix(in srgb, var(--danger) 50%, var(--border));
    color: var(--danger);
  }
  .btn-restaurer:hover:not(:disabled) {
    background: color-mix(in srgb, var(--danger) 12%, transparent);
  }
  .btn-sauvegarde:disabled,
  .btn-restaurer:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .message-donnees {
    color: var(--muted);
    font-size: 0.8rem;
    margin: 0;
  }

  :global(.spin) {
    animation: spin 0.6s linear infinite;
  }
  @keyframes spin {
    to { transform: rotate(360deg); }
  }
</style>
