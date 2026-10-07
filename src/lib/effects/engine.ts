// Moteur de particules générique — chaque effet de révélation n'est qu'une
// "recette" (émission initiale + comportement par frame), pas une
// implémentation séparée à maintenir. Porté depuis la maquette HTML validée.

export interface Particle {
  life: number; // <= 0 signifie mort ; démarrer à une valeur POSITIVE même
  // pour les particules à délai (voir feuxArtifice) — une vie négative au
  // départ empêche la boucle d'appeler update() et bloque la particule
  // pour toujours (bug déjà rencontré et corrigé sur la maquette).
  update(ctx: CanvasRenderingContext2D): void;
}

export interface RunParticlesOptions {
  /** Appelé une fois par frame après la mise à jour de toutes les particules
   * (ex. dessiner une couche persistante comme la neige accumulée). */
  postDraw?: (ctx: CanvasRenderingContext2D, w: number, h: number) => void;
}

/** Joue une recette de particules sur le canvas donné jusqu'à ce que toutes
 * soient mortes. Le canvas est redimensionné à la taille de son parent
 * (ce qui le vide au passage — comportement du DOM, pas un bug).
 *
 * `ralenti` (v22, corrige `revealDurationMs` qui ne pouvait que RACCOURCIR
 * un effet, jamais l'allonger — cf. JOURNAL-DEV.md) : un facteur >= 1 qui
 * étire la durée perçue en sautant des frames de MISE À JOUR (physique +
 * dessin) sans jamais effacer le canvas sur ces frames sautées — le dernier
 * état dessiné reste donc affiché tel quel jusqu'à la prochaine avancée.
 * Sûr par construction : jamais deux dessins de la même particule dans une
 * même frame (contrairement à une tentative précédente d'appeler update()
 * plusieurs fois par frame pour ACCÉLÉRER, abandonnée pour ce risque précis
 * — ce paramètre-ci ne fait que RALENTIR, jamais l'inverse). */
export function runParticles(
  canvas: HTMLCanvasElement,
  spawn: (w: number, h: number) => Particle[],
  opts: RunParticlesOptions = {},
  ralenti = 1
): Promise<void> {
  const parent = canvas.parentElement;
  const rect = parent?.getBoundingClientRect();
  canvas.width = rect?.width ?? canvas.clientWidth;
  canvas.height = rect?.height ?? canvas.clientHeight;
  const ctx = canvas.getContext("2d")!;
  const particles = spawn(canvas.width, canvas.height);
  const facteur = Math.max(1, Math.round(ralenti));
  let compteur = 0;

  return new Promise((resolve) => {
    function tick() {
      compteur++;
      if (compteur % facteur !== 0) {
        // Frame sautée : on ne touche PAS au canvas (ni clear, ni dessin) —
        // le dernier état rendu reste visible tel quel, effet ralenti.
        requestAnimationFrame(tick);
        return;
      }
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      let alive = false;
      for (const p of particles) {
        if (p.life <= 0) continue;
        alive = true;
        p.update(ctx);
      }
      opts.postDraw?.(ctx, canvas.width, canvas.height);
      if (alive) requestAnimationFrame(tick);
      else resolve();
    }
    tick();
  });
}

export function cssVar(name: string): string {
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
}

// Durée "de référence" à laquelle chaque recette a été réglée au jugé
// (valeur par défaut de revealDurationMs) — un ralenti de 1 (comportement
// naturel, inchangé) en dessous ou à cette valeur ; au-dessus, on étire
// proportionnellement. Ne fait QUE ralentir, jamais accélérer (cf. le
// commentaire sur runParticles pour le risque de double-dessin évité).
const DUREE_REFERENCE_MS = 1200;
export function ralentiDepuisDuree(dureeMs?: number): number {
  if (!dureeMs || dureeMs <= DUREE_REFERENCE_MS) return 1;
  return dureeMs / DUREE_REFERENCE_MS;
}
export function accentColor(): string {
  return cssVar("--accent");
}
/** Palette dérivée du thème actif (accent/success/warning/danger) — utilisée
 * par les effets multicolores (confettis, feux d'artifice, encre). */
export function themePalette(): string[] {
  return [cssVar("--accent"), cssVar("--success"), cssVar("--warning"), cssVar("--danger")];
}
