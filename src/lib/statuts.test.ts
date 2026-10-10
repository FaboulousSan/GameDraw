import { describe, it, expect } from "vitest";
import { ajouterStatut, supprimerStatut, basculerVisibiliteStatut, modifierCouleurStatut, trouverStatut } from "./statuts";
import { STATUTS_PAR_DEFAUT } from "./types";

describe("ajouterStatut", () => {
  it("ajoute un statut personnalisé non-intégré et visible par défaut", () => {
    const r = ajouterStatut(STATUTS_PAR_DEFAUT, "Speedrun", "#ff0000");
    expect(r).toHaveLength(6);
    const nouveau = r[5];
    expect(nouveau.label).toBe("Speedrun");
    expect(nouveau.couleur).toBe("#ff0000");
    expect(nouveau.integre).toBe(false);
    expect(nouveau.visible).toBe(true);
  });

  it("ignore un label vide", () => {
    expect(ajouterStatut(STATUTS_PAR_DEFAUT, "   ", "#fff")).toEqual(STATUTS_PAR_DEFAUT);
  });

  it("ne mute pas la liste d'origine", () => {
    const original = [...STATUTS_PAR_DEFAUT];
    ajouterStatut(STATUTS_PAR_DEFAUT, "Speedrun", "#fff");
    expect(STATUTS_PAR_DEFAUT).toEqual(original);
  });
});

describe("supprimerStatut", () => {
  it("refuse de supprimer un statut intégré", () => {
    const r = supprimerStatut(STATUTS_PAR_DEFAUT, "Termine");
    expect(r).toHaveLength(5);
    expect(r.find((s) => s.id === "Termine")).toBeDefined();
  });

  it("supprime un statut personnalisé", () => {
    const avecPerso = ajouterStatut(STATUTS_PAR_DEFAUT, "Speedrun", "#fff");
    const id = avecPerso[5].id;
    const r = supprimerStatut(avecPerso, id);
    expect(r).toHaveLength(5);
    expect(r.find((s) => s.id === id)).toBeUndefined();
  });

  it("ne fait rien si l'id est inconnu", () => {
    expect(supprimerStatut(STATUTS_PAR_DEFAUT, "id-inexistant")).toEqual(STATUTS_PAR_DEFAUT);
  });
});

describe("basculerVisibiliteStatut", () => {
  it("inverse la visibilité du bon statut seulement", () => {
    const r = basculerVisibiliteStatut(STATUTS_PAR_DEFAUT, "Abandonne");
    expect(r.find((s) => s.id === "Abandonne")!.visible).toBe(false);
    expect(r.find((s) => s.id === "Termine")!.visible).toBe(true);
  });

  it("ne supprime jamais un statut masqué (juste visible: false)", () => {
    const r = basculerVisibiliteStatut(STATUTS_PAR_DEFAUT, "Abandonne");
    expect(r).toHaveLength(5);
  });
});

describe("modifierCouleurStatut", () => {
  it("change la couleur du bon statut seulement", () => {
    const r = modifierCouleurStatut(STATUTS_PAR_DEFAUT, "EnCours", "#123456");
    expect(r.find((s) => s.id === "EnCours")!.couleur).toBe("#123456");
    expect(r.find((s) => s.id === "EnPause")!.couleur).toBe("#EAB308");
  });
});

describe("trouverStatut", () => {
  it("retourne la définition existante", () => {
    expect(trouverStatut(STATUTS_PAR_DEFAUT, "EnCours").label).toBe("En cours");
  });

  it("retourne un repli neutre pour un id orphelin (statut supprimé depuis)", () => {
    const r = trouverStatut(STATUTS_PAR_DEFAUT, "id-supprime");
    expect(r.label).toBe("id-supprime");
    expect(r.couleur).toBe("var(--muted)");
  });
});
