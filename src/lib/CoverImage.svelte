<script lang="ts">
  import { convertFileSrc } from "@tauri-apps/api/core";
  import { api } from "./api";
  import { classifyCoverSource } from "./cover-source";

  let { path, alt, variant = "card" }: {
    path: string | null;
    alt: string;
    variant?: "card" | "detail" | "result" | "preview";
  } = $props();
  // Associer les états au chemin courant : un téléchargement asynchrone d'une
  // ancienne jaquette ne doit jamais remplacer/masquer la suivante.
  let failedSource = $state<string | null>(null);
  let fallback = $state<{ source: string; url: string } | null>(null);
  let fallbackTriedFor = $state<string | null>(null);
  const failed = $derived(Boolean(path && failedSource === path));
  const cover = $derived(classifyCoverSource(path));
  const src = $derived.by(() => {
    if (fallback && fallback.source === path) return fallback.url;
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
    failedSource = null;
    fallback = null;
    fallbackTriedFor = null;
  });

  async function handleError(event: Event) {
    const requestedPath = path;
    const failingUrl = (event.currentTarget as HTMLImageElement | null)?.getAttribute("src");
    // Les événements load/error arrivent parfois après un changement rapide de jeu.
    if (!requestedPath || failingUrl !== src) return;
    const requestedCover = classifyCoverSource(requestedPath);
    if (requestedCover.kind === "local" && fallbackTriedFor !== requestedPath) {
      fallbackTriedFor = requestedPath;
      try {
        // Secours natif : uniquement un fichier GameDraw autorisé côté Rust.
        const url = await api.readCoverDataUrl(requestedCover.value);
        if (path === requestedPath) fallback = { source: requestedPath, url };
        return;
      } catch {
        // Ancien fichier supprimé/invalide : laisser apparaître le placeholder.
      }
    }
    if (path === requestedPath) failedSource = requestedPath;
  }

</script>

{#if src && !failed}
  <span class="gamedraw-cover-frame" class:result={variant === "result"} class:preview={variant === "preview"} class:detail={variant === "detail"}>
    <!-- Remplissage visuel purement décoratif : seule cette copie est floutée/recadrée.
         L'image originale au premier plan reste TOUJOURS intégralement visible. -->
    <img class="gamedraw-cover-ambient" src={src} alt="" aria-hidden="true" decoding="async" loading="lazy" referrerpolicy="no-referrer" />
    <img class="gamedraw-cover-image" class:result={variant === "result"} class:preview={variant === "preview"} class:detail={variant === "detail"} src={src} alt={alt} loading={variant === "detail" || variant === "preview" ? "eager" : "lazy"} decoding="async" referrerpolicy="no-referrer" onerror={handleError} />
  </span>
{:else}
  <span class="gamedraw-cover-placeholder" class:detail={variant === "detail"} class:preview={variant === "preview"} title={path ? "Jaquette indisponible — sélectionne une autre image" : alt}>
    {alt.trim().slice(0, 1).toUpperCase() || "🎮"}
  </span>
{/if}

<style>
  .gamedraw-cover-frame {
    display: block;
    position: relative;
    width: 100%;
    height: 100%;
    min-width: 0;
    min-height: 0;
    flex-shrink: 0;
    overflow: hidden;
    box-sizing: border-box;
    /* Les angles arrondis du conteneur ne doivent pas rogner les coins
       de l'original (y compris quand l'image remplit naturellement le cadre). */
    padding: clamp(2px, 2%, 4px);
    background: var(--input);
    isolation: isolate;
    /* Le conteneur possède ses propres couches ; le zoom externe ne touche pas les pixels. */
    contain: paint;
  }
  /* STAB-C4 : la FICHE doit epouser le ratio du fichier ORIGINAL.
     Une hauteur fixe (ex. cadre 3:4 sur poster 2:3) est la source du
     vide habille/floute, qui pouvait ressembler a un titre tronque.
     La hauteur suit le bitmap, sans crop ni deformations. */
  .gamedraw-cover-frame.detail {
    height: auto;
    aspect-ratio: auto;
  }
  .gamedraw-cover-frame.preview { width: 32px; height: 44px; border-radius: 4px; }
  .gamedraw-cover-frame.result { width: 110px; height: 150px; border-radius: var(--radius-sm); border: 1px solid color-mix(in srgb, var(--accent) 45%, transparent); box-shadow: 0 8px 24px rgba(0,0,0,.35); }
  .gamedraw-cover-ambient {
    position: absolute;
    inset: 0;
    width: 100%;
    height: 100%;
    object-fit: cover; /* Arrière-plan UNIQUEMENT, jamais la vraie jaquette */
    object-position: center;
    filter: blur(13px) brightness(.55) saturate(.75);
    opacity: .75;
    transform: scale(1.15);
    pointer-events: none;
    user-select: none;
  }
  .gamedraw-cover-image {
    position: relative;
    z-index: 1;
    display: block;
    width: 100%;
    height: 100%;
    min-width: 0;
    min-height: 0;
    object-fit: contain;
    object-position: center center;
    /* L'original remplit AU MAXIMUM le cadre : aucun crop, aucune déformation.
       Toute zone résiduelle est habillée par gamedraw-cover-ambient. */
    /* La jaquette ne doit jamais être zoomée ou recadrée au survol. */
    image-rendering: auto;
  }
  .gamedraw-cover-image.detail {
    width: 100%;
    height: auto;
    max-width: 100%;
    max-height: none;
    object-fit: contain;
    transform: none;
  }
  .gamedraw-cover-image.result { max-height: 100%; max-width: 100%; }
  .gamedraw-cover-image.preview { width: 100%; height: 100%; border-radius: 4px; }
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
  .gamedraw-cover-placeholder.detail { font-size: 2.5rem; aspect-ratio: 2 / 3; }
  .gamedraw-cover-placeholder.preview { flex: 0 0 32px; width: 32px; height: 32px; font-size: 1rem; }
</style>
