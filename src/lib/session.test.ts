import { describe, it, expect } from "vitest";
import { computeRemainingMs, computeEndsAt, countdownPhase, formatDuration } from "./session";

describe("computeRemainingMs", () => {
  it("retourne 0 quand endsAt est null", () => {
    expect(computeRemainingMs(null)).toBe(0);
  });

  it("calcule le temps restant depuis une date de fin future", () => {
    const now = 1_000_000;
    const endsAt = new Date(now + 90_000).toISOString();
    expect(computeRemainingMs(endsAt, now)).toBe(90_000);
  });

  it("ne descend jamais sous 0 pour une date de fin déjà passée", () => {
    const now = 1_000_000;
    const endsAt = new Date(now - 90_000).toISOString();
    expect(computeRemainingMs(endsAt, now)).toBe(0);
  });
});

describe("computeEndsAt", () => {
  it("ajoute le nombre de minutes donné à la date de départ", () => {
    const from = 1_000_000;
    const endsAt = computeEndsAt(30, from);
    expect(new Date(endsAt).getTime()).toBe(from + 30 * 60_000);
  });
});

describe("countdownPhase", () => {
  it("terminé quand il n'y a pas de session (totalMs <= 0)", () => {
    expect(countdownPhase(0, 0)).toBe("termine");
  });

  it("terminé quand le temps restant est à 0", () => {
    expect(countdownPhase(0, 60_000)).toBe("termine");
  });

  it("normal au-dessus de 50% du temps restant", () => {
    expect(countdownPhase(60_000, 100_000)).toBe("normal");
  });

  it("attention entre 10% et 50%", () => {
    expect(countdownPhase(30_000, 100_000)).toBe("attention");
  });

  it("urgent sous 10%", () => {
    expect(countdownPhase(5_000, 100_000)).toBe("urgent");
  });
});

describe("formatDuration", () => {
  it("formate en m:ss sous une heure", () => {
    expect(formatDuration(90_000)).toBe("1:30");
  });

  it("formate en h:mm:ss au-delà d'une heure", () => {
    expect(formatDuration(3_661_000)).toBe("1:01:01");
  });

  it("arrondit au-dessus pour éviter d'afficher 0:00 avant expiration réelle", () => {
    expect(formatDuration(500)).toBe("0:01");
  });
});
