<script lang="ts">
  import { TriangleAlert } from "@lucide/svelte";
  import { onMount } from "svelte";
  import { langueApp, tr } from "./i18n";

  let { message, onConfirm, onCancel }: { message: string; onConfirm: () => void; onCancel: () => void } = $props();

  let dialogEl: HTMLDialogElement;
  onMount(() => {
    dialogEl.showModal();
    return () => { if (dialogEl?.open) dialogEl.close(); };
  });
</script>

<!-- La confirmation doit elle aussi vivre dans la top-layer, au-dessus de
     la fiche modale native, sans être cachée derrière elle. -->
<dialog bind:this={dialogEl} class="confirmation-dialog glass" aria-label={tr($langueApp, "Confirmation", "Confirmation")}
  oncancel={(event) => { event.preventDefault(); onCancel(); }}>
  <div class="confirmation-content">
    <TriangleAlert size={22} strokeWidth={2.2} color="var(--warning)" />
    <p class="message">{message}</p>
    <div class="actions">
      <button class="annuler" onclick={onCancel}>{tr($langueApp, "Annuler", "Cancel")}</button>
      <button class="continuer" onclick={onConfirm}>{tr($langueApp, "Continuer", "Continue")}</button>
    </div>
  </div>
</dialog>

<style>
  .confirmation-dialog {
    position:fixed; inset:0; margin:auto; width:min(420px, calc(100vw - 24px)); max-width:none;
    max-height:calc(100dvh - 24px); overflow-y:auto; border:1px solid var(--border);
    border-radius:16px; padding:0; background:var(--card); color:var(--text);
    box-shadow:0 28px 100px rgba(0,0,0,.6);
  }
  .confirmation-dialog::backdrop { background:rgba(0,0,0,.7); backdrop-filter:blur(4px); }
  .confirmation-content {
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
