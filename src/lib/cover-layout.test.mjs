import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

// Assurance anti-régression : une jaquette ne doit jamais être rognée par un
// changement de CSS local, même si CoverImage utilise déjà object-fit: contain.
const local = (name) => readFileSync(fileURLToPath(new URL(name, import.meta.url)), "utf8");
const vues = [
  "./CoverImage.svelte", "./BibliothequeView.svelte", "./BacklogView.svelte",
  "./FicheJeu.svelte", "./RechercheGlobaleView.svelte",
  "./AjouterDepuisSteamDialog.svelte", "./AjouterDepuisRawgDialog.svelte",
  "../App.svelte",
];

describe("stabilisation V1 — jaquettes intégrales, centrées et non déformées", () => {
  it.each(vues)("interdit le recadrage pour %s", (fichier) => {
    const code = local(fichier);
    if (!fichier.includes("CoverImage.svelte")) expect(code).not.toMatch(/object-fit:\s*cover\b/i);
    expect(code).not.toMatch(/object-position:\s*top\s+center\b/i);
    expect(code).toMatch(/object-fit:\s*contain\b/i);
  });

  it("impose un rendu centré et un remplissage d'ambiance non destructif", () => {
    const component = local("./CoverImage.svelte");
    expect(component).toMatch(/object-position:\s*(?:center\s+center|50%\s+50%)/i);
    expect(component).toMatch(/gamedraw-cover-ambient/);
    expect(component).toMatch(/gamedraw-cover-frame/);
    expect(component).toMatch(/fallback\.source === path/);
    expect(component).toMatch(/requestedPath === path|path === requestedPath/);
    expect(component).toMatch(/gamedraw-cover-image[\s\S]*?object-fit:\s*contain/i);
  });

  it("STAB-C4 : la fiche suit le ratio NATIF, pas un cadre 3:4 fixe", () => {
    const detail = local("./FicheJeu.svelte");
    const image = local("./CoverImage.svelte");
    const frame = detail.match(/\.cover-cadre\s*\{([^}]*)\}/)?.[1] ?? "";
    const imageDetail = image.match(/\.gamedraw-cover-image\.detail\s*\{([^}]*)\}/)?.[1] ?? "";
    const frameDetail = image.match(/\.gamedraw-cover-frame\.detail\s*\{([^}]*)\}/)?.[1] ?? "";
    expect(frame).toMatch(/aspect-ratio:\s*auto\s*;/);
    expect(frame).not.toMatch(/aspect-ratio:\s*3\s*\/\s*4/);
    expect(frameDetail).toMatch(/height:\s*auto\s*;/);
    expect(imageDetail).toMatch(/height:\s*auto\s*;/);
    expect(imageDetail).toMatch(/object-fit:\s*contain\s*;/);
    expect(image).toMatch(/class:detail=\{variant === "detail"\}/);
  });

  it.each([
    ["./BibliothequeView.svelte", ".carte-jeu:hover .cover-mini"],
    ["./BacklogView.svelte", ".carte-backlog:hover .cover-backlog"],
    ["./FicheJeu.svelte", ".cover-cadre:hover"],
  ])("interdit le zoom tronquant au survol dans %s", (fichier, selecteur) => {
    const code = local(fichier);
    const debut = code.indexOf(`${selecteur} :global(.gamedraw-cover-image)`);
    if (debut >= 0) {
      expect(code.slice(debut, code.indexOf("}", debut))).not.toMatch(/transform:\s*scale\(/);
    }
  });
});
