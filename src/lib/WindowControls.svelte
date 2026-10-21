<script lang="ts">
  import { onMount } from "svelte";
  import { getCurrentWindow } from "@tauri-apps/api/window";
  import { Minus, Square, Copy, X } from "@lucide/svelte";

  // La fenêtre appartient à Tauri ; les boutons déclenchent les mêmes actions
  // natives que la barre de titre Windows. Ne jamais utiliser destroy() ici :
  // close() préserve la confirmation d'une session chronométrée dans App.svelte.
  const currentWindow = getCurrentWindow();
  let maximized = $state(false);

  onMount(() => {
    let mounted = true;
    let unlisten: (() => void) | undefined;
    async function refresh() {
      try {
        const value = await currentWindow.isMaximized();
        if (mounted) maximized = value;
      } catch (error) {
        console.warn("GameDraw : état de la fenêtre indisponible", error);
      }
    }
    void refresh();
    void currentWindow.onResized(() => void refresh()).then((stop) => {
      if (mounted) unlisten = stop;
      else stop();
    }).catch((error) => console.warn("GameDraw : suivi redimensionnement indisponible", error));
    return () => {
      mounted = false;
      unlisten?.();
    };
  });

  async function act(action: "minimize" | "maximize" | "close") {
    try {
      if (action === "minimize") await currentWindow.minimize();
      else if (action === "maximize") {
        await currentWindow.toggleMaximize();
        maximized = await currentWindow.isMaximized();
      } else await currentWindow.close();
    } catch (error) {
      console.error(`GameDraw : action fenêtre ${action} impossible`, error);
    }
  }
</script>

<div class="window-controls" role="group" aria-label="Contrôles de la fenêtre">
  <button type="button" class="window-control" title="Réduire" aria-label="Réduire la fenêtre" onclick={() => void act("minimize")}>
    <Minus size={16} strokeWidth={1.9} />
  </button>
  <button type="button" class="window-control" title={maximized ? "Restaurer" : "Agrandir"} aria-label={maximized ? "Restaurer la fenêtre" : "Agrandir la fenêtre"} onclick={() => void act("maximize")}>
    {#if maximized}<Copy size={14} strokeWidth={1.8} />{:else}<Square size={13} strokeWidth={1.8} />{/if}
  </button>
  <button type="button" class="window-control close" title="Fermer" aria-label="Fermer GameDraw" onclick={() => void act("close")}>
    <X size={18} strokeWidth={1.8} />
  </button>
</div>

<style>
  .window-controls {
    display: flex;
    flex: 0 0 auto;
    align-items: stretch;
    align-self: stretch;
    height: 48px;
    margin-right: -10px;
  }
  .window-control {
    display: grid;
    place-items: center;
    width: 43px;
    height: 100%;
    border: 0;
    border-radius: 0;
    background: transparent;
    color: var(--text);
    opacity: 0.78;
    transition: opacity 120ms ease, background-color 120ms ease;
    cursor: default;
  }
  .window-control:hover {
    background: color-mix(in srgb, var(--accent) 18%, transparent);
    opacity: 1;
  }
  .window-control.close:hover {
    background: #d83048;
    color: #fff;
    opacity: 1;
  }
  .window-control:focus-visible {
    outline: 2px solid var(--accent);
    outline-offset: -3px;
  }
  @media (max-width: 450px) {
    .window-control { width: 39px; }
  }
</style>
