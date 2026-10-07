import { describe, expect, it } from "vitest";
import { langueDepuisLocale } from "./i18n";

describe("langueDepuisLocale", () => {
  it("détecte les locales françaises", () => {
    expect(langueDepuisLocale("fr-FR")).toBe("fr");
    expect(langueDepuisLocale("fr-CA")).toBe("fr");
    expect(langueDepuisLocale("FR_fr")).toBe("fr");
  });

  it("utilise l'anglais pour les autres locales prises en charge par fallback", () => {
    expect(langueDepuisLocale("en-US")).toBe("en");
    expect(langueDepuisLocale("de-DE")).toBe("en");
    expect(langueDepuisLocale(undefined)).toBe("en");
  });
});
