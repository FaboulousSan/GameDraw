import type { Densite } from "./types";

// Multiplie les jetons d'espacement définis dans app.css (--space-1..5) ET
// la largeur maximale de la zone de contenu (--main-max-width, lue par
// App.svelte) — un seul point d'application (comme applyTheme()) plutôt
// que des conditions de densité éparpillées dans chaque composant.
const ECHELLES: Record<Densite, number> = {
  compact: 0.75,
  normal: 1,
  confortable: 1.25,
  spacieux: 1.5,
};

// Largeur max de <main> par palier — "spacieux" élargit vraiment la zone
// utilisable, pas seulement l'espacement interne entre les éléments.
const LARGEURS_MAX: Record<Densite, number> = {
  compact: 820,
  normal: 900,
  confortable: 980,
  spacieux: 1100,
};

const BASES = { 1: 4, 2: 8, 3: 16, 4: 24, 5: 36 } as const;

export function applyDensite(densite: Densite): void {
  const echelle = ECHELLES[densite] ?? 1;
  const root = document.documentElement.style;
  for (const [n, base] of Object.entries(BASES)) {
    root.setProperty(`--space-${n}`, `${Math.round(base * echelle)}px`);
  }
  root.setProperty("--main-max-width", `${LARGEURS_MAX[densite] ?? 900}px`);
}
