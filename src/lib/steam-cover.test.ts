import { describe, it, expect } from "vitest";
import { steamPortraitCandidates } from "./steam-cover";

describe("GameDraw 1.0.7 - images Steam publiques sans cle", () => {
  it("classe la couverture HD avant les miniatures et ne dépend pas de SteamGridDB", () => {
    const urls = steamPortraitCandidates(620);
    expect(urls[0]).toMatch(/620\/library_600x900_2x\.jpg$/);
    expect(urls[1]).toMatch(/620\/library_600x900\.jpg$/);
    expect(urls.at(-1)).toMatch(/620\/header\.jpg$/);
    urls.forEach(u => expect(new URL(u).origin).toBe("https://shared.steamstatic.com"));
  });
  it("refuse les identifiants invalides", () => {
    for (const v of [0,-1,NaN,Infinity,1.5]) expect(steamPortraitCandidates(v)).toEqual([]);
  });
});
