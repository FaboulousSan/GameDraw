<script lang="ts">
  import { fade } from "svelte/transition";
  import { onMount } from "svelte";
  import { Check } from "@lucide/svelte";
  import type { ActionMenu } from "./menu-contextuel";

  let {
    x,
    y,
    actions,
    titre = "",
    onClose,
  }: {
    x: number;
    y: number;
    actions: ActionMenu[];
    titre?: string;
    onClose: () => void;
  } = $props();

  let menuEl = $state<HTMLElement | null>(null);

  // Repositionnement si le menu déborde de la fenêtre : un menu ouvert près
  // du bord droit ou bas serait sinon partiellement inaccessible.
  const position = $derived.by(() => {
    const largeur = 256;
    const marge = 10;
    const hauteur = Math.min(window.innerHeight - marge * 2, actions.length * 38 + 72);
    return {
      x: Math.max(marge, Math.min(x, window.innerWidth - largeur - marge)),
      y: Math.max(marge, Math.min(y, window.innerHeight - hauteur - marge)),
    };
  });

  onMount(() => { menuEl?.querySelector<HTMLButtonElement>("button:not(:disabled)")?.focus(); });

  function naviguerClavier(e: KeyboardEvent) {
    if (e.key === "Escape") { e.preventDefault(); onClose(); return; }
    if (!["ArrowDown", "ArrowUp", "Home", "End"].includes(e.key)) return;
    const boutons = [...(menuEl?.querySelectorAll<HTMLButtonElement>("button:not(:disabled)") ?? [])];
    if (!boutons.length) return;
    e.preventDefault();
    const index = boutons.indexOf(document.activeElement as HTMLButtonElement);
    const prochain = e.key === "Home" ? 0 : e.key === "End" ? boutons.length - 1
      : (index + (e.key === "ArrowDown" ? 1 : -1) + boutons.length) % boutons.length;
    boutons[prochain].focus();
  }

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
  onkeydown={naviguerClavier}
  oncontextmenu={(e) => e.preventDefault()}
>
  {#if titre}<div class="titre-menu">{titre}</div>{/if}
  {#each actions as a}
    {#if a.groupe}<div class="groupe-menu">{a.groupe}</div>{/if}
    {#if a.separateurAvant}
      <div class="separateur-menu"></div>
    {/if}
    <button class="item-menu" class:danger={a.danger} role="menuitem" onclick={() => lancer(a)}>
      {#if a.icone}
        {@const Icone = a.icone}
        <Icone size={14} strokeWidth={2.2} />
      {/if}
      <span class="libelle-menu">{a.label}</span>
      {#if a.actif}<Check size={13} aria-hidden="true" color="var(--accent)" />{/if}
    </button>
  {/each}
</div>

<style>
  .menu-contextuel {
    position: fixed;
    z-index: 200;
    width: min(256px, calc(100vw - 20px));
    max-height: calc(100vh - 20px);
    overflow-y: auto;
    overscroll-behavior: contain;
    padding: 5px;
    border-radius: 13px;
    border: 1px solid color-mix(in srgb, var(--border) 85%, transparent);
    background: color-mix(in srgb, var(--card) 97%, var(--darkbg));
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
    min-height: 33px;
    cursor: pointer;
    transition: background-color 0.12s ease;
  }
  .item-menu:focus-visible { outline: 2px solid var(--accent); outline-offset: -2px; }
  .libelle-menu { flex: 1; }
  .titre-menu { font-family: var(--font-display); font-weight: 700; padding: 9px 10px; font-size: 0.95rem; color: var(--text); border-bottom: 1px solid var(--border); overflow-wrap: anywhere; }
  .groupe-menu { color: var(--muted); font-size: 0.67rem; letter-spacing: 0.1em; text-transform: uppercase; font-weight: 800; padding: 8px 9px 4px; }
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
