import { describe, it, expect } from "vitest";
import { drawFromLibrary, sampleNames, appliquerFiltres, drawMultiple, FILTRES_VIDES } from "./draw";
import { migrate } from "./migrations";
import { SCHEMA_VERSION, type Game, type GameLibrary } from "./types";
import { creerJeu } from "./library";

function lib(jeux: Array<{ id: string; nom: string; dejaFait: boolean }>): GameLibrary {
  const complets: Game[] = jeux.map((j) => ({
    ...j,
    statut: "NonCommence",
    note: 0,
    tags: "",
    description: "",
    commentaire: "",
    typeFin: "",
    cover: null,
    envieDeFaire: false,
    coupDeCoeur: false,
    defis: [],
    heuresJouees: null,
    complete100: false,
  }));
  return { schemaVersion: SCHEMA_VERSION, platformId: "pc", jeux: complets };
}

describe("drawFromLibrary", () => {
  it("retourne null sur bibliothèque vide", () => {
    expect(drawFromLibrary(lib([]))).toBeNull();
  });

  it("tire uniquement dans le pool non-fait", () => {
    const l = lib([
      { id: "1", nom: "A", dejaFait: true },
      { id: "2", nom: "B", dejaFait: false },
    ]);
    const r = drawFromLibrary(l)!;
    expect(r.game.id).toBe("2");
    expect(r.cycleReset).toBe(false);
  });

  it("marque le jeu tiré comme fait sans muter l'original", () => {
    const l = lib([{ id: "1", nom: "A", dejaFait: false }]);
    const r = drawFromLibrary(l)!;
    expect(r.library.jeux[0].dejaFait).toBe(true);
    expect(l.jeux[0].dejaFait).toBe(false); // pas de mutation
  });

  it("réinitialise le cycle quand tout le pool est épuisé", () => {
    const l = lib([
      { id: "1", nom: "A", dejaFait: true },
      { id: "2", nom: "B", dejaFait: true },
    ]);
    const r = drawFromLibrary(l)!;
    expect(r.cycleReset).toBe(true);
    // exactement un jeu refait après le reset : celui qui vient d'être tiré
    expect(r.library.jeux.filter((j) => j.dejaFait)).toHaveLength(1);
    expect(r.library.jeux.find((j) => j.dejaFait)!.id).toBe(r.game.id);
  });

  it("avec eviterRepetitions=false, tire dans toute la bibliothèque sans toucher dejaFait", () => {
    const l = lib([
      { id: "1", nom: "A", dejaFait: true },
      { id: "2", nom: "B", dejaFait: true },
    ]);
    const r = drawFromLibrary(l, false)!;
    expect(["A", "B"]).toContain(r.game.nom);
    expect(r.cycleReset).toBe(false);
    // dejaFait inchangé (toujours true pour les deux, comme avant le tirage)
    expect(r.library.jeux.every((j) => j.dejaFait)).toBe(true);
  });
});

describe("sampleNames", () => {
  it("exclut l'id demandé", () => {
    const l = lib([
      { id: "1", nom: "A", dejaFait: false },
      { id: "2", nom: "B", dejaFait: false },
    ]);
    const s = sampleNames(l, 5, "1");
    expect(s).not.toContain("A");
    expect(s.length).toBeGreaterThan(0);
  });

  it("remplit en répétant si la bibliothèque est plus petite que count", () => {
    const l = lib([{ id: "1", nom: "A", dejaFait: false }]);
    expect(sampleNames(l, 4)).toHaveLength(4);
  });
});

describe("migrate", () => {
  it("laisse passer les données au schéma courant", () => {
    const d = { schemaVersion: SCHEMA_VERSION, theme: "catppuccin" };
    expect(migrate("config", d)).toEqual(d);
  });

  it("considère v1 une donnée sans schemaVersion", () => {
    const r = migrate<{ schemaVersion: number }>("config", { theme: "dracula" });
    expect(r.schemaVersion).toBe(SCHEMA_VERSION);
  });

  it("migre une config v28 vers v29 avec le français par défaut", () => {
    const r = migrate<{ schemaVersion: number; langue: string }>("config", { schemaVersion: 28 });
    expect(r.schemaVersion).toBe(SCHEMA_VERSION);
    expect(r.langue).toBe("fr");
  });

  it("préserve l’anglais pendant la migration v28 vers v29", () => {
    const r = migrate<{ schemaVersion: number; langue: string }>("config", { schemaVersion: 28, langue: "en" });
    expect(r.schemaVersion).toBe(SCHEMA_VERSION);
    expect(r.langue).toBe("en");
  });

  it("auto-répare un historique créé à tort avec schemaVersion 0", () => {
    const r = migrate<{ schemaVersion: number; entrees: unknown[] }>("historique", {
      schemaVersion: 0,
      entrees: [],
    });
    expect(r.schemaVersion).toBe(SCHEMA_VERSION);
    expect(r.entrees).toEqual([]);
  });

  it("refuse une version future explicitement", () => {
    expect(() => migrate("session", { schemaVersion: SCHEMA_VERSION + 1 })).toThrow(
      /version plus récente/
    );
  });
});

describe("appliquerFiltres", () => {
  function libAvec(jeux: Partial<Game>[]): GameLibrary {
    return {
      schemaVersion: 23,
      platformId: "pc",
      jeux: jeux.map((j, i) => ({ ...creerJeu(`Jeu ${i}`), ...j })) as Game[],
    };
  }

  it("retourne la bibliothèque telle quelle si aucun filtre actif", () => {
    const l = libAvec([{}, {}]);
    expect(appliquerFiltres(l, FILTRES_VIDES)).toBe(l);
  });

  it("exclut les jeux terminés et abandonnés", () => {
    const l = libAvec([{ statut: "Termine" }, { statut: "Abandonne" }, { statut: "AFaire" }]);
    const r = appliquerFiltres(l, { ...FILTRES_VIDES, exclureTermines: true });
    expect(r.jeux).toHaveLength(1);
    expect(r.jeux[0].statut).toBe("AFaire");
  });

  it("ne garde que les jeux avec envie de faire", () => {
    const l = libAvec([{ envieDeFaire: true }, { envieDeFaire: false }]);
    expect(appliquerFiltres(l, { ...FILTRES_VIDES, seulementEnvie: true }).jeux).toHaveLength(1);
  });

  it("filtre par statut", () => {
    const l = libAvec([{ statut: "EnCours" }, { statut: "AFaire" }, { statut: "EnCours" }]);
    expect(appliquerFiltres(l, { ...FILTRES_VIDES, statuts: ["EnCours"] }).jeux).toHaveLength(2);
  });

  it("filtre par tag, insensible à la casse et aux espaces", () => {
    const l = libAvec([{ tags: "RPG, Long" }, { tags: "action" }, { tags: "  rpg  " }]);
    expect(appliquerFiltres(l, { ...FILTRES_VIDES, tags: ["rpg"] }).jeux).toHaveLength(2);
  });

  it("combine plusieurs filtres (ET logique)", () => {
    const l = libAvec([
      { statut: "AFaire", tags: "rpg" },
      { statut: "AFaire", tags: "action" },
      { statut: "Termine", tags: "rpg" },
    ]);
    const r = appliquerFiltres(l, { ...FILTRES_VIDES, tags: ["rpg"], exclureTermines: true });
    expect(r.jeux).toHaveLength(1);
  });

  it("peut retourner un pool vide sans planter", () => {
    const l = libAvec([{ statut: "Termine" }]);
    expect(appliquerFiltres(l, { ...FILTRES_VIDES, exclureTermines: true }).jeux).toHaveLength(0);
  });
});

describe("drawMultiple", () => {
  function libDe(n: number): GameLibrary {
    return {
      schemaVersion: 23,
      platformId: "pc",
      jeux: Array.from({ length: n }, (_, i) => creerJeu(`Jeu ${i}`)),
    };
  }

  it("retourne null sur une bibliothèque vide", () => {
    expect(drawMultiple({ schemaVersion: 23, platformId: "pc", jeux: [] }, 3)).toBeNull();
  });

  it("tire le nombre demandé de jeux DISTINCTS", () => {
    const r = drawMultiple(libDe(10), 3)!;
    expect(r.games).toHaveLength(3);
    expect(new Set(r.games.map((g) => g.id)).size).toBe(3);
  });

  it("ne peut pas sortir plus de jeux qu'il n'en existe", () => {
    const r = drawMultiple(libDe(2), 5)!;
    expect(r.games).toHaveLength(2);
    expect(new Set(r.games.map((g) => g.id)).size).toBe(2);
  });

  it("marque tous les jeux tirés comme dejaFait dans la bibliothèque retournée", () => {
    const r = drawMultiple(libDe(6), 3)!;
    const faits = r.library.jeux.filter((j) => j.dejaFait);
    expect(faits).toHaveLength(3);
  });

  it("reste sans doublon même sans anti-répétition", () => {
    const r = drawMultiple(libDe(8), 4, false)!;
    expect(new Set(r.games.map((g) => g.id)).size).toBe(r.games.length);
  });
});
