// Sons de l'application — synthétisés à la volée via la Web Audio API
// plutôt que des fichiers audio embarqués : aucun asset à charger, aucune
// licence à gérer, et le rendu reste identique sur toutes les machines.
//
// Tous les sons sont volontairement courts et discrets (< 600ms) : ils
// ponctuent une action, ils ne doivent jamais devenir fatigants sur une
// session de plusieurs tirages.

export type SonName = "tic" | "revelation" | "succes" | "finSession";

export const SON_LABELS: Record<SonName, string> = {
  tic: "Tic de tirage",
  revelation: "Révélation",
  succes: "Succès débloqué",
  finSession: "Fin de session",
};

// Un seul AudioContext réutilisé — en créer un par son épuiserait le quota
// du navigateur (limite basse, et ils ne se libèrent pas immédiatement).
let ctx: AudioContext | null = null;
function contexte(): AudioContext | null {
  try {
    if (!ctx) ctx = new AudioContext();
    // Les navigateurs suspendent l'AudioContext tant qu'aucune interaction
    // utilisateur n'a eu lieu — le relancer est sans effet s'il tourne déjà.
    if (ctx.state === "suspended") void ctx.resume();
    return ctx;
  } catch {
    return null; // Audio indisponible : on ne casse jamais le reste de l'app.
  }
}

interface NoteOptions {
  frequence: number;
  duree: number; // secondes
  debut?: number; // décalage en secondes depuis maintenant
  volume?: number;
  type?: OscillatorType;
  /** Glissando : fréquence finale atteinte à la fin de la note. */
  frequenceFin?: number;
}

function jouerNote(c: AudioContext, volumeGlobal: number, o: NoteOptions) {
  const osc = c.createOscillator();
  const gain = c.createGain();
  const t0 = c.currentTime + (o.debut ?? 0);
  const vol = (o.volume ?? 1) * volumeGlobal;

  osc.type = o.type ?? "sine";
  osc.frequency.setValueAtTime(o.frequence, t0);
  if (o.frequenceFin) osc.frequency.exponentialRampToValueAtTime(o.frequenceFin, t0 + o.duree);

  // Enveloppe attaque/extinction : sans elle, couper net un oscillateur
  // produit un "clic" audible désagréable.
  gain.gain.setValueAtTime(0, t0);
  gain.gain.linearRampToValueAtTime(vol, t0 + 0.012);
  gain.gain.exponentialRampToValueAtTime(0.0001, t0 + o.duree);

  osc.connect(gain);
  gain.connect(c.destination);
  osc.start(t0);
  osc.stop(t0 + o.duree + 0.02);
}

const RECETTES: Record<SonName, (c: AudioContext, v: number) => void> = {
  // Clic sec et bref, joué à répétition pendant l'animation de tirage.
  tic: (c, v) => jouerNote(c, v, { frequence: 880, duree: 0.05, volume: 0.18, type: "square" }),

  // Accord ascendant court — le "ta-da" du jeu révélé.
  revelation: (c, v) => {
    jouerNote(c, v, { frequence: 523.25, duree: 0.18, volume: 0.3, type: "triangle" });
    jouerNote(c, v, { frequence: 659.25, duree: 0.18, volume: 0.3, debut: 0.09, type: "triangle" });
    jouerNote(c, v, { frequence: 783.99, duree: 0.32, volume: 0.34, debut: 0.18, type: "triangle" });
  },

  // Arpège plus large et plus brillant que la révélation, pour bien les
  // distinguer à l'oreille quand les deux s'enchaînent après un tirage.
  succes: (c, v) => {
    jouerNote(c, v, { frequence: 659.25, duree: 0.14, volume: 0.26, type: "sine" });
    jouerNote(c, v, { frequence: 830.61, duree: 0.14, volume: 0.26, debut: 0.08, type: "sine" });
    jouerNote(c, v, { frequence: 987.77, duree: 0.14, volume: 0.26, debut: 0.16, type: "sine" });
    jouerNote(c, v, { frequence: 1318.51, duree: 0.42, volume: 0.3, debut: 0.24, type: "sine" });
  },

  // Deux notes descendantes, plus posées : la session est finie, pas une fête.
  finSession: (c, v) => {
    jouerNote(c, v, { frequence: 587.33, duree: 0.22, volume: 0.28, type: "triangle" });
    jouerNote(c, v, { frequence: 392, duree: 0.45, volume: 0.28, debut: 0.2, type: "triangle" });
  },
};

/** Joue un son. `volume` va de 0 (muet) à 1. Ne lève jamais : si l'audio
 * est indisponible, l'appel est simplement ignoré. */
export function jouerSon(nom: SonName, volume = 0.6): void {
  if (volume <= 0) return;
  const c = contexte();
  if (!c) return;
  try {
    RECETTES[nom]?.(c, Math.min(Math.max(volume, 0), 1));
  } catch {
    // Audio best-effort — jamais bloquant pour le reste de l'app.
  }
}

/** Ordre d'affichage dans Options (boutons d'aperçu). */
export const SON_ORDER: SonName[] = ["tic", "revelation", "succes", "finSession"];
