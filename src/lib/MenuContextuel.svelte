<script lang="ts">
  import { fade } from "svelte/transition";
  import type { ActionMenu } from "./menu-contextuel";

  let {
    x,
    y,
    actions,
    onClose,
  }: {
    x: number;
    y: number;
    actions: ActionMenu[];
    onClose: () => void;
  } = $props();

  let menuEl = $state<HTMLElement | null>(null);

  // Repositionnement si le menu déborde de la fenêtre : un menu ouvert près
  // du bord droit ou bas serait sinon partiellement inaccessible.
  const position = $derived.by(() => {
    const largeur = 190;
    const hauteur = actions.length * 34 + 12;
    const marge = 8;
    const maxX = window.innerWidth - largeur - marge;
    const maxY = window.innerHeight - hauteur - marge;
    return {
      x: Math.max(marge, Math.min(x, maxX)),
      y: Math.max(marge, Math.min(y, maxY)),
    };
  });

  function lancer(a: ActionMenu) {
    onClose();
    a.action();
  }
</script>

<svelte:window
  onclick={onClose}
  oncontextmenu={onClose}
  onkeydown={(e) => e.key === "Escape" && onClose()}
  onresize={onClose}
/>

<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
<div
  class="menu-contextuel"
  bind:this={menuEl}
  style="left: {position.x}px; top: {position.y}px;"
  transition:fade={{ duration: 90 }}
  role="menu"
  tabindex="-1"
  oncontextmenu={(e) => e.preventDefault()}
>
  {#each actions as a}
    {#if a.separateurAvant}
      <div class="separateur-menu"></div>
    {/if}
    <button class="item-menu" class:danger={a.danger} role="menuitem" onclick={() => lancer(a)}>
      {#if a.icone}
        {@const Icone = a.icone}
        <Icone size={14} strokeWidth={2.2} />
      {/if}
      {a.label}
    </button>
  {/each}
</div>

<style>
  .menu-contextuel {
    position: fixed;
    z-index: 200;
    min-width: 180px;
    padding: 5px;
    border-radius: var(--radius-sm);
    border: 1px solid color-mix(in srgb, var(--border) 85%, transparent);
    background: color-mix(in srgb, var(--card) 97%, transparent);
    box-shadow: 0 12px 34px rgba(0, 0, 0, 0.45);
    display: flex;
    flex-direction: column;
    gap: 1px;
  }
  .item-menu {
    display: flex;
    align-items: center;
    gap: 8px;
    width: 100%;
    background: transparent;
    border: none;
    border-radius: 5px;
    padding: 7px 10px;
    text-align: left;
    color: var(--text);
    font-family: var(--font-body);
    font-size: 0.83rem;
    cursor: pointer;
    transition: background-color 0.12s ease;
  }
  .item-menu:hover {
    background: color-mix(in srgb, var(--accent) 18%, transparent);
  }
  .item-menu.danger {
    color: var(--danger);
  }
  .item-menu.danger:hover {
    background: color-mix(in srgb, var(--danger) 15%, transparent);
  }
  .separateur-menu {
    height: 1px;
    margin: 3px 6px;
    background: color-mix(in srgb, var(--border) 70%, transparent);
  }
</style>
