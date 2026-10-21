import { describe, expect, it } from "vitest";
import { nombreDansPack, packsAImporter, PACKS_INCLUS } from "./catalogues-complets";
import { importerLignes, creerJeu } from "./library";
import type { GameLibrary } from "./types";

describe("listes GameDraw embarquées dans la release", () => {
  it("embarque les fichiers complets fournis avec le projet", () => {
    expect(PACKS_INCLUS.map((p) => p.lignes.length)).toEqual([60, 60, 40, 100]);
    expect(nombreDansPack("tous")).toBe(160);
  });
  it("importe Switch 1 + Switch 2 sans double import", () => {
    expect(packsAImporter("tous").map((p) => p.id)).toEqual(["pc", "switchTous"]);
    expect(packsAImporter("switch2")[0].plateforme).toBe("switch");
  });
  it("conserve les tags des générations Switch", () => {
    const pack = packsAImporter("switchTous")[0];
    expect(pack.lignes.some((l) => l.tags === "Switch 1")).toBe(true);
    expect(pack.lignes.some((l) => l.tags === "Switch 2")).toBe(true);
  });
  it("ajoute sans écraser et ignore les doublons à la réimportation", () => {
    const initiale: GameLibrary = { schemaVersion: 27, platformId: "pc", jeux: [creerJeu("Baldur's Gate 3")] };
    const pack = packsAImporter("pc")[0];
    const premiere = importerLignes(initiale, pack.lignes);
    const seconde = importerLignes(premiere.library, pack.lignes);
    expect(premiere.library.jeux.length).toBe(60);
    expect(seconde.library.jeux.length).toBe(60);
    expect(seconde.ignores).toBe(60);
    expect(initiale.jeux).toHaveLength(1);
  });
});
