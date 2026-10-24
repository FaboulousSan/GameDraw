import { describe, expect, it } from "vitest";
import { evaluateSteamGridSearch, steamGridWebSearchUrl, hasNextSteamGridPage, isDirectImageUrl } from "./steamgriddb-search";

describe("SteamGridDB HF4 — recherche dans la fiche", () => {
  it("n'ouvre pas de fenêtre pour une recherche autorisée", () => {
    expect(evaluateSteamGridSearch({ enabled: true, apiKey: "  clé  ", query: " Celeste " })).toBe("ready");
  });
  it("signale la clé manquante au lieu d'ouvrir une fenêtre éphémère", () => {
    expect(evaluateSteamGridSearch({ enabled: true, apiKey: " ", query: "Hades" })).toBe("missing-key");
  });
  it("respecte une source désactivée", () => {
    expect(evaluateSteamGridSearch({ enabled: false, apiKey: "key", query: "Hades" })).toBe("disabled");
  });
  it("signale un nom de jeu manquant", () => {
    expect(evaluateSteamGridSearch({ enabled: true, apiKey: "key", query: "   " })).toBe("empty-query");
  });
  it("encode les noms accentués et les caractères spéciaux dans le lien public", () => {
    const url = new URL(steamGridWebSearchUrl("Pokémon & Zelda / HD"));
    expect(url.origin).toBe("https://www.steamgriddb.com");
    expect(url.searchParams.get("term")).toBe("Pokémon & Zelda / HD");
  });
});


describe("SteamGridDB HF5 — galerie et import manuel", () => {
  it("permet la navigation lorsqu'une page pleine n'a pas de total", () => {
    expect(hasNextSteamGridPage({ page: 0, total: 0, images: Array(24) })).toBe(true);
    expect(hasNextSteamGridPage({ page: 1, total: 0, images: Array(5) })).toBe(false);
  });
  it("respecte le total connu et la limite de pages", () => {
    expect(hasNextSteamGridPage({ page: 0, total: 49, images: Array(24) })).toBe(true);
    expect(hasNextSteamGridPage({ page: 2, total: 49, images: Array(1) })).toBe(false);
    expect(hasNextSteamGridPage({ page: 100, total: 5000, images: Array(24) })).toBe(false);
  });
  it("valide les URL HTTPS de manière défensive", () => {
    expect(isDirectImageUrl(" https://cdn.example.org/poster.jpg ")).toBe(true);
    expect(isDirectImageUrl("http://cdn.example.org/poster.jpg")).toBe(false);
    expect(isDirectImageUrl("javascript:alert(1)")).toBe(false);
    expect(isDirectImageUrl("https://user:password@cdn.example.org/a.png")).toBe(false);
    expect(isDirectImageUrl("pas une url")).toBe(false);
  });
  it("ne confond pas vérification HTTPS et validation du contenu image", () => {
    expect(isDirectImageUrl("https://www.steamgriddb.com/search/grids?term=Zelda")).toBe(true);
    // Validation HTTPS syntaxique uniquement : le backend doit encore vérifier le contenu image.
    expect(isDirectImageUrl("ftp://cdn.example.org/a.png")).toBe(false);
    expect(isDirectImageUrl("https://evil.example@cdn.example.org/a.png")).toBe(false);
  });
});
