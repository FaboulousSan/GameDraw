import { describe, it, expect } from "vitest";
import {
  ajouterJeu,
  ajouterPlusieursJeux,
  supprimerJeu,
  supprimerPlusieursJeux,
  modifierJeu,
  modifierPlusieursJeux,
  dupliquerJeu,
  ajouterTagsPlusieursJeux,
  filtrerJeux,
  creerJeu,
  parseListeTexte,
  parseCsv,
  importerLignes,
  fusionnerJeux,
  ajouterDefi,
  basculerDefi,
  supprimerDefi,
} from "./library";
import type { GameLibrary } from "./types";

function lib(jeux: GameLibrary["jeux"] = []): GameLibrary {
  return { schemaVersion: 3, platformId: "pc", jeux };
}

describe("creerJeu", () => {
  it("crée un jeu avec des valeurs par défaut neutres", () => {
    const j = creerJeu("Hadès");
    expect(j.nom).toBe("Hadès");
    expect(j.dejaFait).toBe(false);
    expect(j.statut).toBe("NonCommence");
    expect(j.note).toBe(0);
    expect(j.cover).toBeNull();
  });

  it("retire les espaces superflus du nom", () => {
    expect(creerJeu("  Celeste  ").nom).toBe("Celeste");
  });
});

describe("ajouterJeu", () => {
  it("ajoute sans muter la bibliothèque d'origine", () => {
    const l = lib();
    const r = ajouterJeu(l, "Hadès");
    expect(r.jeux).toHaveLength(1);
    expect(l.jeux).toHaveLength(0);
  });
});

describe("ajouterPlusieursJeux", () => {
  it("ignore les doublons insensibles à la casse", () => {
    const l = lib([creerJeu("Hadès")]);
    const { library, ignores } = ajouterPlusieursJeux(l, ["hadès", "Celeste", "  "]);
    expect(library.jeux.map((j) => j.nom)).toEqual(["Hadès", "Celeste"]);
    expect(ignores).toBe(2); // "hadès" (doublon) + la chaîne vide
  });
});

describe("supprimerJeu", () => {
  it("retire uniquement le jeu ciblé", () => {
    const a = creerJeu("A");
    const b = creerJeu("B");
    const l = lib([a, b]);
    const r = supprimerJeu(l, a.id);
    expect(r.jeux.map((j) => j.nom)).toEqual(["B"]);
  });
});

describe("supprimerPlusieursJeux", () => {
  it("retire tous les jeux sélectionnés sans muter l'original", () => {
    const a = creerJeu("A");
    const b = creerJeu("B");
    const c = creerJeu("C");
    const l = lib([a, b, c]);
    const r = supprimerPlusieursJeux(l, [a.id, c.id]);
    expect(r.jeux.map((j) => j.nom)).toEqual(["B"]);
    expect(l.jeux).toHaveLength(3);
  });

  it("ignore les identifiants inconnus sans erreur", () => {
    const a = creerJeu("A");
    const l = lib([a]);
    const r = supprimerPlusieursJeux(l, ["id-inexistant"]);
    expect(r.jeux).toHaveLength(1);
  });
});

describe("modifierJeu", () => {
  it("applique un patch partiel sans toucher aux autres champs", () => {
    const a = creerJeu("A");
    const l = lib([a]);
    const r = modifierJeu(l, a.id, { note: 4, statut: "Termine" });
    expect(r.jeux[0].note).toBe(4);
    expect(r.jeux[0].statut).toBe("Termine");
    expect(r.jeux[0].nom).toBe("A");
  });
});

describe("filtrerJeux", () => {
  it("filtre insensible à la casse sur le nom", () => {
    const jeux = [creerJeu("Hadès"), creerJeu("Celeste")];
    expect(filtrerJeux(jeux, "had").map((j) => j.nom)).toEqual(["Hadès"]);
  });

  it("retourne tout si la recherche est vide", () => {
    const jeux = [creerJeu("Hadès"), creerJeu("Celeste")];
    expect(filtrerJeux(jeux, "  ")).toHaveLength(2);
  });
});

describe("parseListeTexte", () => {
  it("découpe une ligne par nom, ignore les lignes vides", () => {
    const lignes = parseListeTexte("Hadès\n\nCeleste\r\nBaldur's Gate 3\n  \n");
    expect(lignes.map((l) => l.nom)).toEqual(["Hadès", "Celeste", "Baldur's Gate 3"]);
  });
});

describe("parseCsv", () => {
  it("lit les colonnes optionnelles quand présentes", () => {
    const csv = 'Nom,Statut,Tags\nHadès,Termine,"roguelike, action"\nCeleste,EnCours,plateforme';
    const lignes = parseCsv(csv);
    expect(lignes).toEqual([
      { nom: "Hadès", statut: "Termine", tags: "roguelike, action", description: undefined, commentaire: undefined },
      { nom: "Celeste", statut: "EnCours", tags: "plateforme", description: undefined, commentaire: undefined },
    ]);
  });

  it("retourne vide si aucune colonne Nom", () => {
    expect(parseCsv("Titre,Note\nHadès,5")).toEqual([]);
  });

  it("ignore un statut inconnu plutôt que de faire échouer la ligne", () => {
    const lignes = parseCsv("Nom,Statut\nHadès,PasUnStatut");
    expect(lignes[0].nom).toBe("Hadès");
    expect(lignes[0].statut).toBeUndefined();
  });
});

describe("importerLignes", () => {
  it("applique statut/tags quand fournis, ignore les doublons", () => {
    const l: GameLibrary = { schemaVersion: 4, platformId: "pc", jeux: [creerJeu("Hadès")] };
    const { library, ignores } = importerLignes(l, [
      { nom: "hadès" }, // doublon
      { nom: "Celeste", statut: "Termine", tags: "plateforme" },
    ]);
    expect(ignores).toBe(1);
    expect(library.jeux).toHaveLength(2);
    const celeste = library.jeux.find((j) => j.nom === "Celeste")!;
    expect(celeste.statut).toBe("Termine");
    expect(celeste.tags).toBe("plateforme");
  });
});

describe("fusionnerJeux", () => {
  it("fusionne des Game déjà complets en ignorant les doublons par nom", () => {
    const l: GameLibrary = { schemaVersion: 4, platformId: "pc", jeux: [creerJeu("Hadès")] };
    const importe = creerJeu("Celeste");
    const doublon = creerJeu("Hadès");
    const { library, ignores } = fusionnerJeux(l, [importe, doublon]);
    expect(ignores).toBe(1);
    expect(library.jeux.map((j) => j.nom)).toEqual(["Hadès", "Celeste"]);
  });
});

describe("défis personnalisés", () => {
  it("ajouterDefi ajoute un défi non vide sans muter l'original", () => {
    const a = creerJeu("A");
    const l = lib([a]);
    const r = ajouterDefi(l, a.id, "Terminer en difficile");
    expect(r.jeux[0].defis).toHaveLength(1);
    expect(r.jeux[0].defis[0].texte).toBe("Terminer en difficile");
    expect(r.jeux[0].defis[0].complete).toBe(false);
    expect(l.jeux[0].defis).toHaveLength(0);
  });

  it("ajouterDefi ignore un texte vide", () => {
    const a = creerJeu("A");
    const l = lib([a]);
    const r = ajouterDefi(l, a.id, "   ");
    expect(r.jeux[0].defis).toHaveLength(0);
  });

  it("basculerDefi inverse l'état complete du bon défi seulement", () => {
    let a = creerJeu("A");
    let l = lib([a]);
    l = ajouterDefi(l, a.id, "Défi 1");
    l = ajouterDefi(l, a.id, "Défi 2");
    const defiId = l.jeux[0].defis[0].id;
    const r = basculerDefi(l, a.id, defiId);
    expect(r.jeux[0].defis[0].complete).toBe(true);
    expect(r.jeux[0].defis[1].complete).toBe(false);
  });

  it("supprimerDefi retire uniquement le défi ciblé", () => {
    let a = creerJeu("A");
    let l = lib([a]);
    l = ajouterDefi(l, a.id, "Défi 1");
    l = ajouterDefi(l, a.id, "Défi 2");
    const defiId = l.jeux[0].defis[0].id;
    const r = supprimerDefi(l, a.id, defiId);
    expect(r.jeux[0].defis).toHaveLength(1);
    expect(r.jeux[0].defis[0].texte).toBe("Défi 2");
  });
});


describe("import CSV 1.0.4 — Excel français", () => {
  it("reconnaît le BOM UTF-8 et le point-virgule", () => {
    const jeux = parseCsv('\uFEFFNom;Statut;Tags\r\n"Super Mario Odyssey";En cours;"Switch 1, Mario"\r\n');
    expect(jeux).toHaveLength(1);
    expect(jeux[0].nom).toBe("Super Mario Odyssey");
    expect(jeux[0].tags).toBe("Switch 1, Mario");
  });
  it("conserve les champs entre guillemets avec séparateur intégré", () => {
    const jeux = parseCsv('Nom;Description\n"Celeste";"Plateforme; difficulté progressive"');
    expect(jeux).toHaveLength(1);
    expect(jeux[0].description).toBe("Plateforme; difficulté progressive");
  });
  it("préserve le CSV à virgules classique", () => {
    const jeux = parseCsv('Nom,Tags\n"Hades","roguelike,action"');
    expect(jeux[0].tags).toBe("roguelike,action");
  });
});


describe("GameDraw HF3 — menu contextuel et opérations groupées", () => {
  it("change le statut uniquement des jeux sélectionnés sans modifier le modèle d'origine", () => {
    const a = creerJeu("A"), b = creerJeu("B"), c = creerJeu("C");
    const original = lib([a, b, c]);
    const modifie = modifierPlusieursJeux(original, [a.id, c.id, "inconnu"], { statut: "Termine" });
    expect(modifie.jeux.map((j) => j.statut)).toEqual(["Termine", "NonCommence", "Termine"]);
    expect(original.jeux[0].statut).toBe("NonCommence");
  });
  it("empêche le remplacement d'identifiants ou de noms via une action groupée", () => {
    const a = creerJeu("A");
    const r = modifierPlusieursJeux(lib([a]), [a.id], { id: "volé", nom: "Z", envieDeFaire: true });
    expect(r.jeux[0].id).toBe(a.id);
    expect(r.jeux[0].nom).toBe("A");
    expect(r.jeux[0].envieDeFaire).toBe(true);
  });
  it("ajoute des tags sans dupliquer ni effacer les tags existants", () => {
    const a = { ...creerJeu("A"), tags: "rpg, Coop" };
    const b = creerJeu("B");
    const r = ajouterTagsPlusieursJeux(lib([a,b]), [a.id], "Coop, indé, INdÉ");
    expect(r.jeux[0].tags).toBe("rpg, Coop, indé");
    expect(r.jeux[1].tags).toBe("");
  });
  it("duplique avec un nouvel ID et des défis indépendants", () => {
    const a = { ...creerJeu("A"), defis: [{ id: "d1", texte: "Boss", complete: false }] };
    const r = dupliquerJeu(lib([a]), a.id);
    expect(r.jeux).toHaveLength(2);
    expect(r.jeux[1].nom).toBe("A (copie)");
    expect(r.jeux[1].id).not.toBe(a.id);
    expect(r.jeux[1].defis).not.toBe(a.defis);
  });
});
