/** HF4 — Précontrôle indépendant du frontend : recherche SteamGridDB. */
export type SteamGridSearchState = "ready" | "disabled" | "missing-key" | "empty-query";

export function evaluateSteamGridSearch({
  enabled, apiKey, query,
}: { enabled: boolean; apiKey: string; query: string }): SteamGridSearchState {
  if (!enabled) return "disabled";
  if (!apiKey.trim()) return "missing-key";
  if (!query.trim()) return "empty-query";
  return "ready";
}

/** Retourne le site public (jamais une URL injectée dans une WebView Tauri). */
export function steamGridWebSearchUrl(query: string): string {
  return `https://www.steamgriddb.com/search/grids?term=${encodeURIComponent(query.trim())}`;
}

/** Navigation API v2, 24 images par page ; total peut être absent. */
export function hasNextSteamGridPage({page, total, images}: {page: number; total: number; images: unknown[]}): boolean {
  if (page >= 100) return false;
  return total > 0 ? (page + 1) * 24 < total : images.length === 24;
}

/** N'autoriser que des URL absolues HTTPS pour l'import manuel web. */
export function isDirectImageUrl(value: string): boolean {
  try {
    const url = new URL(value.trim());
    return url.protocol === "https:" && !!url.hostname && !url.username && !url.password;
  } catch { return false; }
}
