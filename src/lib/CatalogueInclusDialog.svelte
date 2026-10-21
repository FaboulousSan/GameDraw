<script lang="ts">
  import { BookOpen, CheckCircle2, Download, X } from "@lucide/svelte";
  import { fade, scale } from "svelte/transition";
  import { PACKS_INCLUS, nombreDansPack, packsAImporter, type PackInclusId } from "./catalogues-complets";
  import { tr } from "./i18n";
  import type { AppConfig } from "./types";

  let { config, onClose, onImport }: {
    config: AppConfig;
    onClose: () => void;
    onImport: (id: PackInclusId) => Promise<{ ajoutes: number; ignores: number }>;
  } = $props();
  let choisi = $state<PackInclusId>("tous");
  let enCours = $state(false);
  let erreur = $state<string | null>(null);
  let bilan = $state<{ ajoutes: number; ignores: number } | null>(null);
  const disponibles = [
    ...PACKS_INCLUS.map((p) => ({ id: p.id as PackInclusId, titre: p.titre, total: p.lignes.length })),
    { id: "tous" as PackInclusId, titre: "PC + Switch 1 et 2", total: nombreDansPack("tous") },
  ];
  const packSelectionne = $derived(packsAImporter(choisi));
  function fermer() { if (!enCours) onClose(); }
  async function importer() {
    if (enCours || bilan) return;
    enCours = true;
    erreur = null;
    try { bilan = await onImport(choisi); }
    catch (e) { erreur = String(e); }
    finally { enCours = false; }
  }
</script>

<svelte:window onkeydown={(e) => { if (e.key === "Escape") fermer(); }} />

<!-- svelte-ignore a11y_no_static_element_interactions -->
<!-- svelte-ignore a11y_click_events_have_key_events -->
<div class="fond-liste" transition:fade={{ duration: 120 }} onclick={fermer}>
  <section class="dialogue-liste glass" role="dialog" aria-modal="true" aria-labelledby="listes-titre" tabindex="-1" transition:scale={{ duration: 160, start: 0.96 }} onclick={(e) => e.stopPropagation()}>
    <button class="fermer-liste" onclick={fermer} disabled={enCours} aria-label={tr(config.langue, "Fermer", "Close")}><X size={18}/></button>
    <header>
      <BookOpen size={24} color="var(--accent)"/>
      <div>
        <h2 id="listes-titre">{tr(config.langue, "Listes de jeux fournies", "Included game lists")}</h2>
        <p>{tr(config.langue, "Importez directement les listes présentes dans le projet, même depuis l'application installée.", "Import bundled game lists directly, even from the installed app.")}</p>
      </div>
    </header>
    {#if bilan}
      <div class="bilan-liste" role="status">
        <CheckCircle2 size={32}/>
        <strong>{tr(config.langue, "Import terminé !", "Import complete!")}</strong>
        <span>{bilan.ajoutes} {tr(config.langue, "jeu(x) ajoutés", "games added")} · {bilan.ignores} {tr(config.langue, "déjà présents/ignorés", "already present/skipped")}</span>
        <small>{tr(config.langue, "Tes jeux existants n'ont pas été modifiés. Les nouveaux jeux sont disponibles dans leurs bibliothèques respectives.", "Your existing games were not modified. New games are in their respective libraries.")}</small>
      </div>
    {:else}
      <div class="choix-liste" role="group" aria-label={tr(config.langue, "Choisir une liste", "Choose a list")}>
        {#each disponibles as pack (pack.id)}
          <button class:actif={choisi === pack.id} aria-pressed={choisi === pack.id} onclick={() => (choisi = pack.id)}>
            <span>{pack.titre}</span><strong>{pack.total} {tr(config.langue, "jeux", "games")}</strong>
          </button>
        {/each}
      </div>
      <p class="details-liste">{tr(config.langue, "Destination", "Destination")} : {packSelectionne.map((p) => p.plateforme === "pc" ? "PC" : "Switch").join(" + ")}. {tr(config.langue, "Les tags Switch 1 / Switch 2 sont conservés.", "Switch 1 / Switch 2 tags are preserved.")}</p>
      <div class="aperçu-liste">
        <small>{tr(config.langue, "Exemples inclus", "Included examples")}</small>
        {#each packSelectionne.flatMap((p) => p.lignes.slice(0, 3)) as ligne}
          <span>• {ligne.nom}</span>
        {/each}
      </div>
      <p class="notice-liste">{tr(config.langue, "Listes de découverte non exhaustives. Pas de téléchargement, pas de remplacement et aucun ajout automatique sans confirmation.", "Non-exhaustive starter lists. No download, no replacement, and nothing is added without confirmation.")}</p>
      {#if erreur}<p class="erreur-liste" role="alert">{erreur}</p>{/if}
    {/if}
    <footer>
      {#if bilan}
        <button class="principal-liste" onclick={fermer}>{tr(config.langue, "Terminer", "Done")}</button>
      {:else}
        <button class="secondaire-liste" onclick={fermer} disabled={enCours}>{tr(config.langue, "Annuler", "Cancel")}</button>
        <button class="principal-liste" onclick={importer} disabled={enCours}><Download size={16}/>{enCours ? tr(config.langue, "Import en cours…", "Importing…") : tr(config.langue, `Ajouter ${nombreDansPack(choisi)} jeux`, `Add ${nombreDansPack(choisi)} games`)}</button>
      {/if}
    </footer>
  </section>
</div>

<style>
  .fond-liste { position:fixed; inset:0; background:rgba(0,0,0,.72); z-index:250; display:grid; place-items:center; padding:18px; backdrop-filter:blur(7px); }
  .dialogue-liste { position:relative; color:var(--text); background:var(--card); border:1px solid var(--border); border-radius:18px; padding:24px; width:min(560px,100%); max-height:min(90vh,760px); overflow-y:auto; box-shadow:0 24px 90px rgba(0,0,0,.45); display:grid; gap:16px; }
  .fermer-liste { position:absolute; top:12px; right:12px; background:transparent; border:0; color:var(--muted); padding:6px; border-radius:8px; cursor:pointer; }
  header { display:flex; gap:12px; padding-right:28px; align-items:flex-start; }
  h2 { margin:0 0 4px; font-family:var(--font-display); font-size:1.35rem; }
  header p { margin:0; color:var(--muted); font-size:.88rem; line-height:1.5; }
  .choix-liste { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:8px; }
  .choix-liste button { padding:12px; border:1px solid var(--border); background:var(--input); color:var(--text); border-radius:12px; display:flex; justify-content:space-between; align-items:center; gap:10px; cursor:pointer; text-align:left; font-family:var(--font-body); }
  .choix-liste button:hover, .choix-liste button.actif { border-color:var(--accent); background:color-mix(in srgb,var(--accent) 12%,var(--card)); }
  .choix-liste button strong { color:var(--accent); white-space:nowrap; font-size:.78rem; }
  .choix-liste button:last-child { grid-column:1/-1; }
  .details-liste,.notice-liste { color:var(--muted); font-size:.83rem; line-height:1.5; margin:0; }
  .aperçu-liste { display:grid; gap:5px; background:color-mix(in srgb,var(--input) 70%,transparent); padding:12px 14px; border-radius:10px; font-size:.86rem; }
  .aperçu-liste small { color:var(--muted); margin-bottom:2px; }
  .erreur-liste { color:var(--danger); margin:0; overflow-wrap:anywhere; }
  footer { display:flex; justify-content:flex-end; gap:10px; flex-wrap:wrap; }
  footer button { border-radius:10px; padding:10px 14px; font-family:var(--font-body); cursor:pointer; font-weight:600; }
  .principal-liste { background:var(--accent); border:1px solid var(--accent); color:var(--darkbg); display:flex; gap:8px; align-items:center; }
  .secondaire-liste { background:var(--input); color:var(--text); border:1px solid var(--border); }
  footer button:disabled { opacity:.5; cursor:wait; }
  .bilan-liste { display:grid; justify-items:center; gap:8px; text-align:center; padding:20px 12px; color:var(--success); }
  .bilan-liste span { color:var(--text); }
  .bilan-liste small { color:var(--muted); line-height:1.4; }
  @media(max-width:540px) { .choix-liste{ grid-template-columns:1fr; } .choix-liste button:last-child{grid-column:auto;} .dialogue-liste{padding:20px 16px;} }
  @media(prefers-reduced-motion:reduce) { * { transition:none !important; } }
</style>
