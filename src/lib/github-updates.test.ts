import { describe, it, expect } from "vitest";
import { depotGitHubValide, doitVerifierAuDemarrage } from "./github-updates";
import { DEFAULT_CONFIG } from "./types";
import type { AppConfig } from "./types";
import { migrate } from "./migrations";

describe("GameDraw 1.0.6 HF3 — consentement aux mises à jour", () => {
  it("ne contacte PAS GitHub avant la réponse du premier lancement", () => {
    expect(DEFAULT_CONFIG.updatesGithubRepo).toBe("FaboulousSan/GameDraw");
    expect(DEFAULT_CONFIG.updatesConsentAnswered).toBe(false);
    expect(doitVerifierAuDemarrage(DEFAULT_CONFIG)).toBe(false);
  });
  it("permet Oui / Non, uniquement après une réponse enregistrée", () => {
    expect(doitVerifierAuDemarrage({updatesConsentAnswered:true,updatesAutoCheck:true,updatesGithubRepo:"FaboulousSan/GameDraw"})).toBe(true);
    expect(doitVerifierAuDemarrage({updatesConsentAnswered:true,updatesAutoCheck:false,updatesGithubRepo:"FaboulousSan/GameDraw"})).toBe(false);
    expect(doitVerifierAuDemarrage({updatesConsentAnswered:false,updatesAutoCheck:true,updatesGithubRepo:"FaboulousSan/GameDraw"})).toBe(false);
  });
  it("les configurations conservées lors d'une réinstallation reçoivent la question une seule fois", () => {
    const old = migrate<AppConfig>("config", {schemaVersion: DEFAULT_CONFIG.schemaVersion, updatesAutoCheck: false, updatesGithubRepo: ""});
    expect(old.updatesAutoCheck).toBe(false);
    expect(old.updatesConsentAnswered).toBe(false);
    expect(old.updatesGithubRepo).toBe("FaboulousSan/GameDraw");
    const answered = migrate<AppConfig>("config", { ...old, updatesConsentAnswered:true, updatesAutoCheck:true });
    expect(answered.updatesConsentAnswered).toBe(true);
    expect(answered.updatesAutoCheck).toBe(true);
  });
  it("refuse les dépôts mal formés et tokens malgré un accord", () => {
    for (const bad of ["https://github.com/o/r", "../r", "o/../r", "o/r?token=x", "o/r/other"])
      expect(depotGitHubValide(bad)).toBe(false);
  });
});
