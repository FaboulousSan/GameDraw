// Toute la logique du compte à rebours est en fonctions PURES ici, testables
// sans Tauri ni horloge réelle (paramètre `now` injectable). L'appelant
// (App.svelte) ne fait que lire session.endsAt et appeler ces fonctions à
// intervalle régulier — jamais de durée écoulée gardée en mémoire, toujours
// recalculée depuis la date de fin absolue stockée sur disque.

export type CountdownPhase = "normal" | "attention" | "urgent" | "termine";

/** Temps restant en ms, jamais négatif. `endsAt` null → 0 (pas de session active). */
export function computeRemainingMs(endsAt: string | null, now: number = Date.now()): number {
  if (!endsAt) return 0;
  return Math.max(0, new Date(endsAt).getTime() - now);
}

/** Date de fin absolue à stocker, calculée une seule fois au moment du tirage. */
export function computeEndsAt(minutes: number, from: number = Date.now()): string {
  return new Date(from + minutes * 60_000).toISOString();
}

/**
 * Phase du compte à rebours selon le pourcentage de temps restant :
 * - > 50% : normal (couleur accent du thème)
 * - 10-50% : attention (orange)
 * - < 10% : urgent (rouge, pulsation) — cf. plan de migration
 * - 0 ou pas de session : terminé
 */
export function countdownPhase(remainingMs: number, totalMs: number): CountdownPhase {
  if (totalMs <= 0 || remainingMs <= 0) return "termine";
  const pct = remainingMs / totalMs;
  if (pct <= 0.1) return "urgent";
  if (pct <= 0.5) return "attention";
  return "normal";
}

/** Formate en m:ss ou h:mm:ss selon la durée. */
export function formatDuration(ms: number): string {
  const totalSeconds = Math.ceil(ms / 1000);
  const h = Math.floor(totalSeconds / 3600);
  const m = Math.floor((totalSeconds % 3600) / 60);
  const s = totalSeconds % 60;
  const pad = (n: number) => String(n).padStart(2, "0");
  return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${m}:${pad(s)}`;
}
