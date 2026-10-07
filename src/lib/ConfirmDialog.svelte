<script lang="ts">
  import { TriangleAlert } from "@lucide/svelte";
  import { scale, fade } from "svelte/transition";
  import { langueApp, tr } from "./i18n";

  let { message, onConfirm, onCancel }: { message: string; onConfirm: () => void; onCancel: () => void } = $props();

  function onKeydown(e: KeyboardEvent) {
    if (e.key === "Escape") onCancel();
    if (e.key === "Enter") onConfirm();
  }
</script>

<svelte:window onkeydown={onKeydown} />

<!-- svelte-ignore a11y_click_events_have_key_events -- clic-dehors pour
     fermer est un bonus souris ; le clavier est déjà couvert par Échap
     (svelte:window ci-dessus) et par les boutons Annuler/Continuer. -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="backdrop" transition:fade={{ duration: 120 }} onclick={onCancel}>
  <div
    class="dialog glass"
    transition:scale={{ duration: 160, start: 0.94 }}
    onclick={(e) => e.stopPropagation()}
    role="alertdialog"
    aria-modal="true"
    tabindex="-1"
  >
    <TriangleAlert size={22} strokeWidth={2.2} color="var(--warning)" />
    <p class="message">{message}</p>
    <div class="actions">
      <button class="annuler" onclick={onCancel}>{tr($langueApp, "Annuler", "Cancel")}</button>
      <button class="continuer" onclick={onConfirm}>{tr($langueApp, "Continuer", "Continue")}</button>
    </div>
  </div>
</div>

<style>
  .backdrop {
    position: fixed;
    inset: 0;
    z-index: 50;
    background: rgba(0, 0, 0, 0.45);
    backdrop-filter: blur(2px);
    display: flex;
    align-items: center;
    justify-content: center;
    padding: var(--space-4);
  }

  .dialog {
    max-width: 360px;
    padding: var(--space-4);
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--space-3);
    text-align: center;
  }

  .message {
    color: var(--text);
    font-family: var(--font-body);
    font-size: 0.95rem;
    margin: 0;
    line-height: 1.4;
  }

  .actions {
    display: flex;
    gap: var(--space-2);
    width: 100%;
  }

  button {
    flex: 1;
    padding: var(--space-2) var(--space-3);
    border-radius: var(--radius-sm);
    font-family: var(--font-display);
    font-weight: 600;
    font-size: 0.9rem;
    cursor: pointer;
    transition: transform 0.15s var(--spring), filter 0.15s ease;
  }

  button:hover {
    transform: translateY(-1px);
  }

  .annuler {
    background: color-mix(in srgb, var(--input) 85%, transparent);
    color: var(--muted);
    border: 1px solid var(--border);
  }

  .continuer {
    background: linear-gradient(135deg, var(--accent), color-mix(in srgb, var(--accent) 70%, var(--success)));
    color: var(--darkbg);
    border: none;
  }
</style>
