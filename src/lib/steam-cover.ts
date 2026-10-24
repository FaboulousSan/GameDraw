/** Jaquettes officielles publiques de Steam : aucune clé SteamGridDB ni scraping. */
export function steamPortraitCandidates(appId: number): string[] {
  if (!Number.isSafeInteger(appId) || appId <= 0) return [];
  const base = `https://shared.steamstatic.com/store_item_assets/steam/apps/${appId}`;
  return [`${base}/library_600x900_2x.jpg`, `${base}/library_600x900.jpg`, `${base}/library_600x900.png`, `${base}/header.jpg`];
}
