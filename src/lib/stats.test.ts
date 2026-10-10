import { describe, it, expect } from "vitest";
import { calculerStats, formaterMinutes, tempsCumuleJeu, dernierTirageJeu, construireHeatmap, construireTimeline } from "./stats";
import type { GameLibrary, Historique } from "./types";
import { creerJeu } from "./library";

function lib(jeux: GameLibrary["jeux"] = []): GameLibrary {
  return { schemaVersion: 5, platformId: "pc", jeux };
}

describe("calculerStats", () => {
  it("retourne des stats à zéro sans bibliothèque", () => {
    const stats = calculerStats(null, { schemaVersion: 5, entrees: [] }, "pc");
    expect(stats.totalJeux).toBe(0);
    expect(stats.tauxNotationPct).toBe(0);
    expect(stats.dejaFaitsPct).toBe(0);
  });

  it("calcule le taux de notation et l'avancement du cycle", () => {
    const a = { ...creerJeu("A"), note: 4 };
    const b = { ...creerJeu("B"), note: 0, dejaFait: true };
    const c = { ...creerJeu("C"), note: 5, dejaFait: true };
    const l = lib([a, b, c]);
    const stats = calculerStats(l, { schemaVersion: 5, entrees: [] }, "pc");
    expect(stats.jeuxNotes).toBe(2);
    expect(stats.tauxNotationPct).toBe(67); // 2/3 arrondi
    expect(stats.dejaFaits).toBe(2);
    expect(stats.dejaFaitsPct).toBe(67);
  });

  it("ne compte que les entrées d'historique de la plateforme demandée", () => {
    const historique: Historique = {
      schemaVersion: 5,
      entrees: [
        { platformId: "pc", gameId: "1", nom: "A", drawnAt: "2026-01-01T00:00:00Z", goalMinutes: 30 },
        { platformId: "pc", gameId: "2", nom: "B", drawnAt: "2026-01-02T00:00:00Z", goalMinutes: 45 },
        { platformId: "switch", gameId: "3", nom: "C", drawnAt: "2026-01-03T00:00:00Z", goalMinutes: 60 },
      ],
    };
    const stats = calculerStats(lib([]), historique, "pc");
    expect(stats.nombreTirages).toBe(2);
    expect(stats.minutesCumulees).toBe(75);
  });

  it("traite goalMinutes null comme 0", () => {
    const historique: Historique = {
      schemaVersion: 5,
      entrees: [{ platformId: "pc", gameId: "1", nom: "A", drawnAt: "2026-01-01T00:00:00Z", goalMinutes: null }],
    };
    const stats = calculerStats(lib([]), historique, "pc");
    expect(stats.minutesCumulees).toBe(0);
  });
});

describe("formaterMinutes", () => {
  it("affiche en minutes sous une heure", () => {
    expect(formaterMinutes(45)).toBe("45 min");
  });

  it("affiche en heures rondes", () => {
    expect(formaterMinutes(120)).toBe("2h");
  });

  it("affiche heures et minutes combinées", () => {
    expect(formaterMinutes(90)).toBe("1h30");
  });

  it("affiche 0 min pour une valeur nulle ou négative", () => {
    expect(formaterMinutes(0)).toBe("0 min");
    expect(formaterMinutes(-5)).toBe("0 min");
  });
});

describe("tempsCumuleJeu", () => {
  it("ne cumule que les entrées de ce jeu précis", () => {
    const historique: Historique = {
      schemaVersion: 7,
      entrees: [
        { platformId: "pc", gameId: "jeu-1", nom: "A", drawnAt: "2026-01-01T00:00:00Z", goalMinutes: 30 },
        { platformId: "pc", gameId: "jeu-1", nom: "A", drawnAt: "2026-01-05T00:00:00Z", goalMinutes: 20 },
        { platformId: "pc", gameId: "jeu-2", nom: "B", drawnAt: "2026-01-03T00:00:00Z", goalMinutes: 60 },
      ],
    };
    expect(tempsCumuleJeu(historique, "jeu-1")).toBe(50);
    expect(tempsCumuleJeu(historique, "jeu-inconnu")).toBe(0);
  });
});

describe("dernierTirageJeu", () => {
  it("retourne null si le jeu n'a jamais été tiré", () => {
    expect(dernierTirageJeu({ schemaVersion: 7, entrees: [] }, "jeu-1")).toBeNull();
  });

  it("retourne la date la plus récente parmi les tirages du jeu", () => {
    const historique: Historique = {
      schemaVersion: 7,
      entrees: [
        { platformId: "pc", gameId: "jeu-1", nom: "A", drawnAt: "2026-01-01T00:00:00Z", goalMinutes: 30 },
        { platformId: "pc", gameId: "jeu-1", nom: "A", drawnAt: "2026-01-10T00:00:00Z", goalMinutes: 30 },
        { platformId: "pc", gameId: "jeu-1", nom: "A", drawnAt: "2026-01-05T00:00:00Z", goalMinutes: 30 },
      ],
    };
    expect(dernierTirageJeu(historique, "jeu-1")).toBe("2026-01-10T00:00:00Z");
  });
});


describe("construireHeatmap", () => {
  function histDe(dates: string[]): Historique {
    return {
      schemaVersion: 25,
      entrees: dates.map((d, i) => ({
        platformId: "pc", gameId: String(i), nom: "X", drawnAt: d, goalMinutes: 30,
      })),
    };
  }
  function aujourdhuiISO(decalageJours = 0): string {
    const d = new Date();
    d.setHours(12, 0, 0, 0);
    d.setDate(d.getDate() - decalageJours);
    return d.toISOString();
  }

  it("retourne un point par jour sur la période demandée", () => {
    expect(construireHeatmap(histDe([]), 30)).toHaveLength(30);
  });

  it("met tous les niveaux à 0 sans aucun tirage", () => {
    expect(construireHeatmap(histDe([]), 10).every((j) => j.niveau === 0 && j.compte === 0)).toBe(true);
  });

  it("compte les tirages du jour et leur donne le niveau max", () => {
    const grille = construireHeatmap(histDe([aujourdhuiISO(), aujourdhuiISO()]), 10);
    const dernier = grille[grille.length - 1];
    expect(dernier.compte).toBe(2);
    expect(dernier.niveau).toBe(4);
  });

  it("échelonne les niveaux relativement au maximum de la période", () => {
    const dates = [aujourdhuiISO(), aujourdhuiISO(), aujourdhuiISO(), aujourdhuiISO(), aujourdhuiISO(1)];
    const grille = construireHeatmap(histDe(dates), 10);
    const hier = grille[grille.length - 2];
    const auj = grille[grille.length - 1];
    expect(auj.niveau).toBe(4);
    expect(hier.compte).toBe(1);
    expect(hier.niveau).toBeGreaterThan(0);
    expect(hier.niveau).toBeLessThan(4);
  });

  it("ignore les tirages hors de la fenêtre", () => {
    const grille = construireHeatmap(histDe([aujourdhuiISO(400)]), 30);
    expect(grille.every((j) => j.compte === 0)).toBe(true);
  });
});

describe("construireTimeline", () => {
  it("retourne les tirages du plus récent au plus ancien", () => {
    const h: Historique = {
      schemaVersion: 25,
      entrees: [
        { platformId: "pc", gameId: "1", nom: "Ancien", drawnAt: "2026-01-01T10:00:00", goalMinutes: 30 },
        { platformId: "pc", gameId: "2", nom: "Recent", drawnAt: "2026-06-01T10:00:00", goalMinutes: 30 },
      ],
    };
    const t = construireTimeline(h, null);
    expect(t[0].nom).toBe("Recent");
    expect(t[1].nom).toBe("Ancien");
  });

  it("enrichit avec le statut actuel du jeu quand il existe encore", () => {
    const jeu = { ...creerJeu("A"), statut: "Termine", note: 4, coupDeCoeur: true };
    const lib: GameLibrary = { schemaVersion: 25, platformId: "pc", jeux: [jeu] };
    const h: Historique = {
      schemaVersion: 25,
      entrees: [{ platformId: "pc", gameId: jeu.id, nom: "A", drawnAt: "2026-01-01T10:00:00", goalMinutes: 30 }],
    };
    const t = construireTimeline(h, lib);
    expect(t[0].statut).toBe("Termine");
    expect(t[0].note).toBe(4);
    expect(t[0].coupDeCoeur).toBe(true);
  });

  it("gère un jeu supprimé depuis (statut null, pas de plantage)", () => {
    const h: Historique = {
      schemaVersion: 25,
      entrees: [{ platformId: "pc", gameId: "disparu", nom: "Fantome", drawnAt: "2026-01-01T10:00:00", goalMinutes: 30 }],
    };
    const t = construireTimeline(h, { schemaVersion: 25, platformId: "pc", jeux: [] });
    expect(t[0].statut).toBeNull();
    expect(t[0].nom).toBe("Fantome");
  });

  it("respecte la limite demandée", () => {
    const h: Historique = {
      schemaVersion: 25,
      entrees: Array.from({ length: 50 }, (_, i) => ({
        platformId: "pc", gameId: String(i), nom: `J${i}`, drawnAt: "2026-01-01T10:00:00", goalMinutes: 30,
      })),
    };
    expect(construireTimeline(h, null, 10)).toHaveLength(10);
  });
});
