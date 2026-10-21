<script lang="ts">
  import { convertFileSrc } from "@tauri-apps/api/core";
  import { api } from "./api";
  import { classifyCoverSource } from "./cover-source";

  let { path, alt, variant = "card" }: {
    path: string | null;
    alt: string;
    variant?: "card" | "detail" | "result" | "preview";
  } = $props();
  let failed = $state(false);
  let fallbackUrl = $state<string | null>(null);
  let fallbackTried = $state(false);
  const cover = $derived(classifyCoverSource(path));
  const src = $derived.by(() => {
    if (fallbackUrl) return fallbackUrl;
    // GAMEDRAW-104-HF2-COVER-GUARD : les valeurs null couvrent les sources empty/invalid.
    // Eviter la comparaison `kind === invalid` apres avoir teste la valeur : TS2367.
    if (!cover.value) return null;
    if (cover.kind === "local") {
      try {
        return convertFileSrc(cover.value);
      } catch {
        // En cas d'URL Windows invalide, conserver un rendu sûr.
        return null;
      }
    }
    return cover.value;
  });

  // Important : si l'image change, l'ancien état d'échec ne doit pas persister.
  $effect(() => {
    void path;
    failed = false;
    fallbackUrl = null;
    fallbackTried = false;
  });

  async function handleError() {
    if (!path) return;
    if (cover.kind === "local" && !fallbackTried) {
      const requestedPath = cover.value;
      fallbackTried = true;
      try {
        // Secours natif : fichier GameDraw uniquement, jamais un chemin arbitraire.
        const url = await api.readCoverDataUrl(requestedPath);
        if (path?.trim() === requestedPath) fallbackUrl = url;
        return;
      } catch {
        // Anciennes jaquettes manquantes/corrompues : afficher un remplacement.
      }
    }
    failed = true;
  }
</script>

{#if src && !failed}
  <img class="gamedraw-cover-image" class:result={variant === "result"} class:preview={variant === "preview"} src={src} alt={alt} loading={variant === "detail" || variant === "preview" ? "eager" : "lazy"} decoding="async" referrerpolicy="no-referrer" onerror={handleError} />
{:else}
  <span class="gamedraw-cover-placeholder" class:detail={variant === "detail"} class:preview={variant === "preview"} title={path ? "Jaquette indisponible — sélectionne une autre image" : alt}>
    {alt.trim().slice(0, 1).toUpperCase() || "🎮"}
  </span>
{/if}

<style>
  .gamedraw-cover-image {
    display: block;
    width: 100%;
    height: 100%;
    object-fit: cover;
    object-position: top center;
    transition: transform 0.35s ease;
  }
  .gamedraw-cover-image.result {
    max-height: 150px;
    max-width: 110px;
    width: auto;
    height: auto;
    border-radius: var(--radius-sm);
    border: 1px solid color-mix(in srgb, var(--accent) 45%, transparent);
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.35);
  }
  .gamedraw-cover-image.preview { width: 32px; height: 32px; border-radius: 4px; flex-shrink: 0; }
  .gamedraw-cover-placeholder {
    display: flex;
    justify-content: center;
    align-items: center;
    width: 100%;
    height: 100%;
    min-height: 1em;
    font-family: var(--font-display);
    font-size: 1.5rem;
    font-weight: 700;
    color: var(--muted);
  }
  .gamedraw-cover-placeholder.detail { font-size: 2.5rem; }
  .gamedraw-cover-placeholder.preview { flex: 0 0 32px; width: 32px; height: 32px; font-size: 1rem; }
</style>
