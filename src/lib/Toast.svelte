<script lang="ts">
  import { PartyPopper, Trophy, X } from "@lucide/svelte";
  import { fly } from "svelte/transition";

  let {
    message,
    type = "session",
    onClose,
  }: {
    message: string;
    type?: "session" | "succes";
    onClose: () => void;
  } = $props();
</script>

<div class="toast glass" class:succes={type === "succes"} transition:fly={{ y: 24, duration: 220 }} role="status">
  {#if type === "succes"}
    <Trophy size={20} strokeWidth={2.2} color="#FFD54A" />
  {:else}
    <PartyPopper size={20} strokeWidth={2.2} color="var(--accent)" />
  {/if}
  <p class="msg">{message}</p>
  <button class="close" onclick={onClose} aria-label="Fermer">
    <X size={16} strokeWidth={2.2} />
  </button>
</div>

<style>
  .toast {
    position: fixed;
    right: var(--space-4);
    bottom: var(--space-4);
    z-index: 60;
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-3);
    max-width: 320px;
    box-shadow:
      0 0 24px color-mix(in srgb, var(--accent) 30%, transparent),
      0 8px 30px rgba(0, 0, 0, 0.25);
  }
  .toast.succes {
    border-color: color-mix(in srgb, #ffd54a 50%, var(--border));
    box-shadow:
      0 0 24px color-mix(in srgb, #ffd54a 35%, transparent),
      0 8px 30px rgba(0, 0, 0, 0.25);
  }

  .msg {
    margin: 0;
    font-family: var(--font-body);
    font-size: 0.9rem;
    color: var(--text);
    flex: 1;
    line-height: 1.35;
  }

  .close {
    background: transparent;
    border: none;
    color: var(--muted);
    cursor: pointer;
    padding: 3px;
    border-radius: 6px;
    flex-shrink: 0;
  }
  .close:hover {
    background: color-mix(in srgb, var(--input) 80%, transparent);
  }
</style>
