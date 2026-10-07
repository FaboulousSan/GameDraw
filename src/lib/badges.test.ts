import { describe, it, expect } from "vitest";
import { calculerStatsPourBadges, badgesDebloquables, nouveauxBadges, BADGE_DEFINITIONS } from "./badges";
import type { GameLibrary, Historique } from "./types";
import { creerJeu } from "./library";

function lib(platformId: string, jeux: GameLibrary["jeux"]): GameLibrary {
  return { schemaVersion: 21, platformId, jeux };
}
function hist(entrees: Historique["entrees"]): Historique {
  return { schemaVersion: 21, entrees };
}

describe("BADGE_DEFINITIONS", () => {
  it("n'a pas d'id en double", () => {
    const ids = BADGE_DEFINITIONS.map((b) => b.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  it("n'a pas de libellé en double", () => {
    const labels = BADGE_DEFINITIONS.map((b) => b.label);
    expect(new Set(labels).size).toBe(labels.length);
  });

  it("compte largement plus de 80 succès (expansion massive)", () => {
    expect(BADGE_DEFINITIONS.length).toBeGreaterThanOrEqual(80);
  });
});

describe("calculerStatsPourBadges", () => {
  it("agrège correctement à travers plusieurs bibliothèques", () => {
    const a = { ...creerJeu("A"), statut: "Termine", complete100: true, note: 5, heuresJouees: 12 };
    const b = { ...creerJeu("B"), coupDeCoeur: true, envieDeFaire: true };
    const c = { ...creerJeu("C") };
    c.defis = [
      { id: "1", texte: "d1", complete: true },
      { id: "2", texte: "d2", complete: false },
    ];
    const historique = hist([
      { platformId: "pc", gameId: a.id, nom: "A", drawnAt: "2026-01-01T10:00:00", goalMinutes: 30 },
      { platformId: "switch", gameId: b.id, nom: "B", drawnAt: "2026-01-02T10:00:00", goalMinutes: 30 },
    ]);
    const stats = calculerStatsPourBadges(historique, [lib("pc", [a, c]), lib("switch", [b])]);
    expect(stats.nombreTirages).toBe(2);
    expect(stats.jeuxTermines).toBe(1);
    expect(stats.jeux100).toBe(1);
    expect(stats.defisComplets).toBe(1);
    expect(stats.jeuxCoupDeCoeur).toBe(1);
    expect(stats.jeuxEnvieDeFaire).toBe(1);
    expect(stats.jeuxNotes).toBe(1);
    expect(stats.totalJeux).toBe(3);
    expect(stats.plateformesAvecJeux).toBe(2);
    expect(stats.heuresJoueesTotal).toBe(12);
  });

  it("gère une absence totale de données sans planter", () => {
    const stats = calculerStatsPourBadges(hist([]), []);
    expect(stats.totalJeux).toBe(0);
    expect(stats.jeuxCoupDeCoeur).toBe(0);
    expect(badgesDebloquables(stats)).toEqual([]);
  });
});

describe("badgesDebloquables — paliers cumulatifs", () => {
  it("débloque les paliers de tirage jusqu'au seuil atteint, pas au-delà", () => {
    const historique = hist(
      Array.from({ length: 30 }, (_, i) => ({
        platformId: "pc",
        gameId: String(i),
        nom: "X",
        drawnAt: "2026-01-01T10:00:00",
        goalMinutes: 30,
      }))
    );
    const ids = badgesDebloquables(calculerStatsPourBadges(historique, []));
    expect(ids).toContain("tirages_bronze");
    expect(ids).toContain("tirages_argent");
    expect(ids).not.toContain("tirages_or");
  });

  it("débloque les paliers de plateformes au bon seuil (2 à 6)", () => {
    const jeu = creerJeu("A");
    const deuxPlateformes = calculerStatsPourBadges(hist([]), [lib("pc", [jeu]), lib("switch", [creerJeu("B")])]);
    const ids = badgesDebloquables(deuxPlateformes);
    expect(ids).toContain("plateformes_bronze");
    expect(ids).not.toContain("plateformes_argent");
  });

  it("débloque les paliers de collection au bon seuil", () => {
    const jeux = Array.from({ length: 10 }, (_, i) => creerJeu(`Jeu ${i}`));
    const ids = badgesDebloquables(calculerStatsPourBadges(hist([]), [lib("pc", jeux)]));
    expect(ids).toContain("collection_bronze");
    expect(ids).not.toContain("collection_argent");
  });

  it("débloque les paliers d'heures jouées cumulées", () => {
    const jeux = [{ ...creerJeu("A"), heuresJouees: 60 }];
    const ids = badgesDebloquables(calculerStatsPourBadges(hist([]), [lib("pc", jeux)]));
    expect(ids).toContain("heures_bronze");
    expect(ids).toContain("heures_argent");
    expect(ids).not.toContain("heures_or");
  });
});

describe("badgesDebloquables — succès simples", () => {
  it("détecte un jeu tiré la nuit (0h-5h) et pas les autres horaires", () => {
    const stats = calculerStatsPourBadges(hist([{ platformId: "pc", gameId: "1", nom: "X", drawnAt: "2026-01-01T02:30:00", goalMinutes: 30 }]), []);
    expect(stats.aTireDeNuit).toBe(true);
    expect(stats.aTirePauseDejeuner).toBe(false);
    const ids = badgesDebloquables(stats);
    expect(ids).toContain("oiseau_de_nuit");
    expect(ids).not.toContain("pause_dejeuner");
  });

  it("détecte le jour de la semaine du tirage", () => {
    // 2026-01-01 est un jeudi
    const stats = calculerStatsPourBadges(hist([{ platformId: "pc", gameId: "1", nom: "X", drawnAt: "2026-01-01T10:00:00", goalMinutes: 30 }]), []);
    expect(badgesDebloquables(stats)).toContain("jour_jeudi");
  });

  it("détecte deux puis trois tirages consécutifs du même jeu", () => {
    const deux = calculerStatsPourBadges(
      hist([
        { platformId: "pc", gameId: "1", nom: "X", drawnAt: "2026-01-01T10:00:00", goalMinutes: 30 },
        { platformId: "pc", gameId: "1", nom: "X", drawnAt: "2026-01-02T10:00:00", goalMinutes: 30 },
      ]),
      []
    );
    expect(badgesDebloquables(deux)).toContain("deja_vu");
    expect(badgesDebloquables(deux)).not.toContain("triple_deja_vu");

    const trois = calculerStatsPourBadges(
      hist([
        { platformId: "pc", gameId: "1", nom: "X", drawnAt: "2026-01-01T10:00:00", goalMinutes: 30 },
        { platformId: "pc", gameId: "1", nom: "X", drawnAt: "2026-01-02T10:00:00", goalMinutes: 30 },
        { platformId: "pc", gameId: "1", nom: "X", drawnAt: "2026-01-03T10:00:00", goalMinutes: 30 },
      ]),
      []
    );
    expect(badgesDebloquables(trois)).toContain("triple_deja_vu");
  });

  it("prend en compte le nombre de statuts personnalisés (paliers)", () => {
    const avecUn = calculerStatsPourBadges(hist([]), [], 1);
    expect(badgesDebloquables(avecUn)).toContain("statuts_bronze");
    expect(badgesDebloquables(avecUn)).not.toContain("statuts_argent");
    const avecTrois = calculerStatsPourBadges(hist([]), [], 3);
    expect(badgesDebloquables(avecTrois)).toContain("statuts_argent");
    const sansAucun = calculerStatsPourBadges(hist([]), [], 0);
    expect(badgesDebloquables(sansAucun)).not.toContain("statuts_bronze");
  });

  it("prend en compte le flag anti-répétition désactivé", () => {
    const avecChaos = calculerStatsPourBadges(hist([]), [], 0, true);
    expect(badgesDebloquables(avecChaos)).toContain("chaos_assume");
    const sansChaos = calculerStatsPourBadges(hist([]), [], 0, false);
    expect(badgesDebloquables(sansChaos)).not.toContain("chaos_assume");
  });

  it("compte les jeux avec description/commentaire/tag", () => {
    const jeux = Array.from({ length: 5 }, (_, i) => ({ ...creerJeu(`J${i}`), description: "une description" }));
    const stats = calculerStatsPourBadges(hist([]), [lib("pc", jeux)]);
    expect(stats.jeuxAvecDescription).toBe(5);
    expect(badgesDebloquables(stats)).toContain("descriptions_argent");
  });

  it("détecte une bibliothèque parfaite (5+ jeux, tous Terminé)", () => {
    const jeux = Array.from({ length: 5 }, (_, i) => ({ ...creerJeu(`J${i}`), statut: "Termine" }));
    const stats = calculerStatsPourBadges(hist([]), [lib("pc", jeux)]);
    expect(badgesDebloquables(stats)).toContain("bibliotheque_parfaite");
  });

  it("zero_abandon exige au moins 10 terminés et aucun abandonné", () => {
    const jeuxOk = Array.from({ length: 10 }, (_, i) => ({ ...creerJeu(`J${i}`), statut: "Termine" }));
    const statsOk = calculerStatsPourBadges(hist([]), [lib("pc", jeuxOk)]);
    expect(badgesDebloquables(statsOk)).toContain("zero_abandon");

    const jeuxAvecAbandon = [...jeuxOk.slice(0, 9), { ...creerJeu("Abandon"), statut: "Abandonne" }];
    const statsAvecAbandon = calculerStatsPourBadges(hist([]), [lib("pc", jeuxAvecAbandon)]);
    expect(badgesDebloquables(statsAvecAbandon)).not.toContain("zero_abandon");
  });
});

describe("nouveauxBadges", () => {
  it("ne retourne que les ids pas encore débloqués", () => {
    const r = nouveauxBadges(["tirages_bronze", "tirages_argent", "collection_bronze"], ["tirages_bronze"]);
    expect(r).toEqual(["tirages_argent", "collection_bronze"]);
  });

  it("retourne vide si tout est déjà débloqué", () => {
    expect(nouveauxBadges(["tirages_bronze"], ["tirages_bronze", "tirages_argent"])).toEqual([]);
  });
});

describe("succès v22 (notes, régularité, complétion)", () => {
  it("détecte une note parfaite et une note minimale", () => {
    const jeux = [{ ...creerJeu("A"), note: 5 }, { ...creerJeu("B"), note: 1 }];
    const ids = badgesDebloquables(calculerStatsPourBadges(hist([]), [lib("pc", jeux)]));
    expect(ids).toContain("note_parfaite");
    expect(ids).toContain("note_minimale");
  });

  it("calcule la moyenne des notes en ignorant les jeux non notés", () => {
    const jeux = [
      ...Array.from({ length: 10 }, (_, i) => ({ ...creerJeu(`J${i}`), note: 5 })),
      { ...creerJeu("NonNote"), note: 0 },
    ];
    const stats = calculerStatsPourBadges(hist([]), [lib("pc", jeux)]);
    expect(stats.moyenneNotes).toBe(5);
    expect(badgesDebloquables(stats)).toContain("moyenne_elevee");
  });

  it("compte les jours calendaires distincts, pas les tirages", () => {
    const entrees = [
      { platformId: "pc", gameId: "1", nom: "X", drawnAt: "2026-01-01T10:00:00", goalMinutes: 30 },
      { platformId: "pc", gameId: "2", nom: "Y", drawnAt: "2026-01-01T20:00:00", goalMinutes: 30 },
    ];
    const stats = calculerStatsPourBadges(hist(entrees), []);
    expect(stats.joursDistinctsTires).toBe(1);
    expect(stats.maxTiragesUnJour).toBe(2);
  });

  it("débloque le grand soir à partir de 5 tirages le même jour", () => {
    const entrees = Array.from({ length: 5 }, (_, i) => ({
      platformId: "pc", gameId: String(i), nom: "X", drawnAt: "2026-01-01T10:00:00", goalMinutes: 30,
    }));
    expect(badgesDebloquables(calculerStatsPourBadges(hist(entrees), []))).toContain("grand_soir");
  });

  it("calcule le pourcentage de bibliothèque terminée", () => {
    const jeux = [
      ...Array.from({ length: 5 }, (_, i) => ({ ...creerJeu(`T${i}`), statut: "Termine" })),
      ...Array.from({ length: 5 }, (_, i) => creerJeu(`N${i}`)),
    ];
    const stats = calculerStatsPourBadges(hist([]), [lib("pc", jeux)]);
    expect(stats.pctTermine).toBe(50);
    const ids = badgesDebloquables(stats);
    expect(ids).toContain("progression_bronze");
    expect(ids).toContain("progression_argent");
    expect(ids).not.toContain("progression_or");
  });

  it("détecte un jeu avec 5+ défis tous complétés", () => {
    const jeu = creerJeu("A");
    jeu.defis = Array.from({ length: 5 }, (_, i) => ({ id: String(i), texte: `d${i}`, complete: true }));
    expect(badgesDebloquables(calculerStatsPourBadges(hist([]), [lib("pc", [jeu])]))).toContain("tout_defis");
  });

  it("exige que TOUS les jeux aient une jaquette (10 minimum)", () => {
    const avecTout = Array.from({ length: 10 }, (_, i) => ({ ...creerJeu(`J${i}`), cover: "/chemin.png" }));
    expect(badgesDebloquables(calculerStatsPourBadges(hist([]), [lib("pc", avecTout)]))).toContain("collection_bien_rangee");
    const avecUnSans = [...avecTout.slice(0, 9), creerJeu("SansCover")];
    expect(badgesDebloquables(calculerStatsPourBadges(hist([]), [lib("pc", avecUnSans)]))).not.toContain("collection_bien_rangee");
  });
});


describe("succès v26 (contenu riche, usage de l'app)", () => {
  it("détecte une description longue et beaucoup de tags", () => {
    const jeux = [
      { ...creerJeu("A"), description: "x".repeat(250) },
      { ...creerJeu("B"), tags: "a, b, c, d, e" },
    ];
    const ids = badgesDebloquables(calculerStatsPourBadges(hist([]), [lib("pc", jeux)]));
    expect(ids).toContain("bibliophile");
    expect(ids).toContain("tag_maniaque");
  });

  it("exige que TOUS les jeux soient notés, minimum 20", () => {
    const tousNotes = Array.from({ length: 20 }, (_, i) => ({ ...creerJeu(`J${i}`), note: 3 }));
    expect(badgesDebloquables(calculerStatsPourBadges(hist([]), [lib("pc", tousNotes)]))).toContain("collection_notee");
    const avecUnNonNote = [...tousNotes.slice(0, 19), creerJeu("SansNote")];
    expect(badgesDebloquables(calculerStatsPourBadges(hist([]), [lib("pc", avecUnNonNote)]))).not.toContain("collection_notee");
  });

  it("distingue gros morceau et petit plaisir", () => {
    const jeux = [
      { ...creerJeu("Long"), heuresJouees: 120 },
      { ...creerJeu("Court"), statut: "Termine", heuresJouees: 3 },
    ];
    const ids = badgesDebloquables(calculerStatsPourBadges(hist([]), [lib("pc", jeux)]));
    expect(ids).toContain("gros_morceau");
    expect(ids).toContain("petit_plaisir");
  });

  it("ne compte pas un petit plaisir si le jeu n'est pas terminé", () => {
    const jeux = [{ ...creerJeu("Court"), statut: "EnCours", heuresJouees: 2 }];
    expect(badgesDebloquables(calculerStatsPourBadges(hist([]), [lib("pc", jeux)]))).not.toContain("petit_plaisir");
  });

  it("prend en compte le journal d'usage", () => {
    const stats = calculerStatsPourBadges(hist([]), [], 0, false, {
      nbBadgesDebloques: 55,
      nbThemesEssayes: 6,
      aUtiliseTirageMultiple: true,
      aUtiliseRouletteRusse: true,
      aUtiliseFiltres: true,
    });
    const ids = badgesDebloquables(stats);
    expect(ids).toContain("cote_a_cote");
    expect(ids).toContain("engage");
    expect(ids).toContain("selectif");
    expect(ids).toContain("esthete");
    expect(ids).toContain("veteran_app");
    expect(ids).not.toContain("presque_tout");
  });

  it("sans usage fourni, aucun succès d'usage ne se débloque", () => {
    const ids = badgesDebloquables(calculerStatsPourBadges(hist([]), []));
    expect(ids).not.toContain("cote_a_cote");
    expect(ids).not.toContain("esthete");
  });
});

describe("succès v27 (séries, contrastes, jalons)", () => {
  function jourISO(decalage: number, heure = 12): string {
    const d = new Date();
    d.setHours(heure, 0, 0, 0);
    d.setDate(d.getDate() - decalage);
    return d.toISOString();
  }

  it("détecte une série de 3 jours consécutifs", () => {
    const h = hist([2, 1, 0].map((n, i) => ({
      platformId: "pc", gameId: String(i), nom: "X", drawnAt: jourISO(n), goalMinutes: 30,
    })));
    const stats = calculerStatsPourBadges(h, []);
    expect(stats.serieJoursMax).toBe(3);
    expect(badgesDebloquables(stats)).toContain("serie_3");
    expect(badgesDebloquables(stats)).not.toContain("serie_7");
  });

  it("casse la série s'il manque un jour", () => {
    const h = hist([5, 4, 2, 1].map((n, i) => ({
      platformId: "pc", gameId: String(i), nom: "X", drawnAt: jourISO(n), goalMinutes: 30,
    })));
    expect(calculerStatsPourBadges(h, []).serieJoursMax).toBe(2);
  });

  it("détecte des notes extrêmes opposées", () => {
    const jeux = [{ ...creerJeu("A"), note: 5 }, { ...creerJeu("B"), note: 1 }];
    expect(badgesDebloquables(calculerStatsPourBadges(hist([]), [lib("pc", jeux)]))).toContain("grand_ecart");
    const jeuxProches = [{ ...creerJeu("A"), note: 4 }, { ...creerJeu("B"), note: 2 }];
    expect(badgesDebloquables(calculerStatsPourBadges(hist([]), [lib("pc", jeuxProches)]))).not.toContain("grand_ecart");
  });

  it("compte les tags DISTINCTS, insensible à la casse", () => {
    const jeux = [{ ...creerJeu("A"), tags: "RPG, Long" }, { ...creerJeu("B"), tags: "rpg, court" }];
    expect(calculerStatsPourBadges(hist([]), [lib("pc", jeux)]).tagsDistincts).toBe(3);
  });

  it("détecte une reprise après plus de 30 jours", () => {
    const h = hist([
      { platformId: "pc", gameId: "1", nom: "X", drawnAt: jourISO(60), goalMinutes: 30 },
      { platformId: "pc", gameId: "2", nom: "Y", drawnAt: jourISO(0), goalMinutes: 30 },
    ]);
    expect(badgesDebloquables(calculerStatsPourBadges(h, []))).toContain("retour_gagnant");
  });

  it("compte les tirages d'une même nuit (avant 5h)", () => {
    const h = hist([1, 2, 3].map((i) => ({
      platformId: "pc", gameId: String(i), nom: "X", drawnAt: jourISO(0, 2), goalMinutes: 30,
    })));
    const stats = calculerStatsPourBadges(h, []);
    expect(stats.maxTiragesUneNuit).toBe(3);
    expect(badgesDebloquables(stats)).toContain("nuit_blanche");
  });

  it("exige note ET commentaire pour bibliotheque_annotee", () => {
    const avecDeux = Array.from({ length: 10 }, (_, i) => ({ ...creerJeu(`J${i}`), note: 4, commentaire: "bien" }));
    expect(badgesDebloquables(calculerStatsPourBadges(hist([]), [lib("pc", avecDeux)]))).toContain("bibliotheque_annotee");
    const noteSeule = Array.from({ length: 10 }, (_, i) => ({ ...creerJeu(`J${i}`), note: 4 }));
    expect(badgesDebloquables(calculerStatsPourBadges(hist([]), [lib("pc", noteSeule)]))).not.toContain("bibliotheque_annotee");
  });
});
