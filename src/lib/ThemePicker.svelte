<script lang="ts">
  import { Palette, ChevronDown, Check } from "@lucide/svelte";
  import { scale } from "svelte/transition";
  import { THEME_ORDER, THEME_LABELS } from "./themes";
  import type { ThemeName } from "./types";

  let { value, onChange }: { value: ThemeName; onChange: (t: ThemeName) => void } = $props();

  let open = $state(false);
  let rootEl = $state<HTMLDivElement | null>(null);

  function toggle() {
    open = !open;
  }
  function choose(t: ThemeName) {
    onChange(t);
    open = false;
  }
  function onWindowClick(e: MouseEvent) {
    if (open && rootEl && !rootEl.contains(e.target as Node)) open = false;
  }
  function onKeydown(e: KeyboardEvent) {
    if (e.key === "Escape") open = false;
  }
</script>

<svelte:window onclick={onWindowClick} onkeydown={onKeydown} />

<div class="picker" bind:this={rootEl}>
  <button class="trigger glass" onclick={toggle} aria-expanded={open} aria-haspopup="listbox">
    <Palette size={16} strokeWidth={2} color="var(--muted)" />
    <span>{THEME_LABELS[value]}</span>
    <span class="chevron" class:open>
      <ChevronDown size={14} strokeWidth={2} color="var(--muted)" />
    </span>
  </button>

  {#if open}
    <div class="menu" role="listbox" transition:scale={{ duration: 140, start: 0.95 }}>
      {#each THEME_ORDER as t}
        <button class="item" class:active={t === value} onclick={() => choose(t)} role="option" aria-selected={t === value}>
          <span>{THEME_LABELS[t]}</span>
          {#if t === value}<Check size={14} strokeWidth={2.5} />{/if}
        </button>
      {/each}
    </div>
  {/if}
</div>

<style>
  .picker {
    position: relative;
  }

  .trigger {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-1) var(--space-2);
    border-radius: var(--radius-sm);
    color: var(--text);
    font-family: var(--font-body);
    font-size: 0.85rem;
  }

  .chevron {
    display: inline-flex;
    transition: transform 0.2s var(--spring);
  }
  .chevron.open {
    transform: rotate(180deg);
  }

  .menu {
    position: absolute;
    top: calc(100% + 8px);
    right: 0;
    min-width: 190px;
    max-height: 320px;
    overflow-y: auto;
    padding: 6px;
    display: flex;
    flex-direction: column;
    gap: 2px;
    z-index: 30;
    /* Fond opaque plutôt que .glass : ce menu flotte au-dessus du header,
       cohérence avec le correctif appliqué au menu Importer de la
       Bibliothèque (éviter d'empiler des flous, risque déjà rencontré). */
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    box-shadow: 0 8px 30px rgba(0, 0, 0, 0.35);
  }

  .item {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-2);
    border-radius: 8px;
    background: transparent;
    color: var(--text);
    font-family: var(--font-body);
    font-size: 0.88rem;
    text-align: left;
    transition: background-color 0.15s ease;
  }

  .item:hover {
    background: color-mix(in srgb, var(--accent) 18%, transparent);
  }

  .item.active {
    color: var(--accent);
    font-weight: 600;
  }
</style>
