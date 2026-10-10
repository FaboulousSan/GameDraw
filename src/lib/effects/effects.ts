import { runParticles, accentColor, themePalette, cssVar, ralentiDepuisDuree, type Particle } from "./engine";

export type RevealEffectName =
  | "confettis" | "feuxArtifice" | "etincelles" | "eclairOrage" | "sakura"
  | "ondeChoc" | "etoilesFilantes" | "bulles" | "encreDispersee" | "neige"
  | "automne" | "printemps" | "vent" | "pluie"
  | "arcEnCiel" | "laser" | "pixelExplosion" | "vagueOnde" | "spirale"
  | "coeurs" | "fumee" | "eclatsDeVerre"
  | "supernova" | "matrice" | "bulleSavon" | "poussiereEtoiles"
  | "feuilleMorte" | "aurore" | "kaleidoscope" | "impulsion"
  | "trouNoir" | "eclatPrisme" | "nueeInsectes" | "vortexEncre" | "grelons" | "braises"
  | "feuArtificeMulti" | "ondeGravite" | "confettisCanon" | "meteores" | "bullesIrisees" | "eclairsChaine";

export const REVEAL_EFFECT_LABELS: Record<RevealEffectName, string> = {
  confettis: "Confettis", feuxArtifice: "Feux d'artifice", etincelles: "Étincelles",
  eclairOrage: "Éclair-orage", sakura: "Pétales de sakura", ondeChoc: "Onde de choc",
  etoilesFilantes: "Étoiles filantes", bulles: "Bulles", encreDispersee: "Encre dispersée",
  neige: "Neige", automne: "Automne", printemps: "Printemps", vent: "Vent", pluie: "Pluie",
  arcEnCiel: "Arc-en-ciel", laser: "Lasers", pixelExplosion: "Explosion pixel",
  vagueOnde: "Vagues concentriques", spirale: "Spirale", coeurs: "Cœurs",
  fumee: "Fumée", eclatsDeVerre: "Éclats de verre",
  supernova: "Supernova", matrice: "Pluie de code", bulleSavon: "Bulles de savon",
  poussiereEtoiles: "Poussière d'étoiles", feuilleMorte: "Feuilles mortes",
  aurore: "Aurore boréale", kaleidoscope: "Kaléidoscope", impulsion: "Impulsion",
  trouNoir: "Trou noir", eclatPrisme: "Éclat prismatique", nueeInsectes: "Nuée",
  vortexEncre: "Vortex d'encre", grelons: "Grêlons", braises: "Braises",
  feuArtificeMulti: "Bouquet final", ondeGravite: "Onde gravitationnelle",
  confettisCanon: "Canons à confettis", meteores: "Pluie de météores",
  bullesIrisees: "Bulles irisées", eclairsChaine: "Éclairs en chaîne",
};

// Même logique que les animations : 42 effets à plat sont impossibles à
// parcourir, groupés par ambiance ils deviennent choisissables.
export const EFFECT_FAMILLES: { titre: string; effets: RevealEffectName[] }[] = [
  { titre: "🎉 Fête", effets: ["confettis", "confettisCanon", "feuxArtifice", "feuArtificeMulti", "etincelles", "coeurs"] },
  { titre: "⚡ Énergie", effets: ["eclairOrage", "eclairsChaine", "laser", "impulsion", "ondeChoc", "ondeGravite"] },
  { titre: "🌌 Cosmos", effets: ["supernova", "trouNoir", "etoilesFilantes", "meteores", "poussiereEtoiles", "aurore"] },
  { titre: "🍃 Nature", effets: ["sakura", "neige", "grelons", "automne", "printemps", "vent", "pluie", "feuilleMorte"] },
  { titre: "💧 Fluides", effets: ["bulles", "bullesIrisees", "bulleSavon", "encreDispersee", "vortexEncre", "fumee", "braises"] },
  { titre: "🎨 Abstrait", effets: ["arcEnCiel", "eclatPrisme", "kaleidoscope", "spirale", "vagueOnde", "pixelExplosion", "matrice", "eclatsDeVerre", "nueeInsectes"] },
];

export const REVEAL_EFFECT_ORDER: RevealEffectName[] = [
  "confettis", "feuxArtifice", "etincelles", "eclairOrage", "sakura", "ondeChoc",
  "etoilesFilantes", "bulles", "encreDispersee", "neige", "automne", "printemps", "vent", "pluie",
  "arcEnCiel", "laser", "pixelExplosion", "vagueOnde", "spirale", "coeurs", "fumee", "eclatsDeVerre",
  "supernova", "matrice", "bulleSavon", "poussiereEtoiles", "feuilleMorte", "aurore", "kaleidoscope", "impulsion",
  "trouNoir", "eclatPrisme", "nueeInsectes", "vortexEncre", "grelons", "braises",
  "feuArtificeMulti", "ondeGravite", "confettisCanon", "meteores", "bullesIrisees", "eclairsChaine",
];

function confettis(canvas: HTMLCanvasElement, dureeMs?: number) {
  const cols = themePalette();
  return runParticles(canvas, (w, h) =>
    Array.from({ length: 130 }, () => {
      const p: any = {
        x: w / 2, y: h * 0.35, vx: (Math.random() - 0.5) * 8.5, vy: -Math.random() * 7 - 2.5, life: 1,
        rot: Math.random() * Math.PI * 2, vr: (Math.random() - 0.5) * 0.35,
        color: cols[Math.floor(Math.random() * cols.length)], w: 6 + Math.random() * 5, h: 3 + Math.random() * 4,
      };
      p.update = (ctx: CanvasRenderingContext2D) => {
        p.x += p.vx; p.y += p.vy; p.vy += 0.16; p.rot += p.vr; p.life -= 0.011;
        ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.rot); ctx.globalAlpha = Math.max(p.life, 0);
        ctx.shadowColor = p.color; ctx.shadowBlur = 5;
        ctx.fillStyle = p.color; ctx.fillRect(-p.w / 2, -p.h / 2, p.w, p.h); ctx.restore();
      };
      return p as Particle;
    })
  , {}, ralentiDepuisDuree(dureeMs));
}

function feuxArtifice(canvas: HTMLCanvasElement, dureeMs?: number) {
  const cols = themePalette();
  const bursts = Array.from({ length: 4 }, (_, b) => ({
    delay: b * 220, x: 0.2 + Math.random() * 0.6, y: 0.2 + Math.random() * 0.35,
  }));
  return runParticles(canvas, (w, h) => {
    const all: Particle[] = [];
    bursts.forEach((b) => {
      const cx = w * b.x, cy = h * b.y;
      const color = cols[Math.floor(Math.random() * cols.length)];
      for (let i = 0; i < 42; i++) {
        const angle = (i / 42) * Math.PI * 2;
        const speed = 3 + Math.random() * 3.5;
        // life reste positif dès le départ : le délai ne fait que retarder
        // la mise à jour — une vie négative bloquait la particule pour
        // toujours (bug identifié et corrigé sur la maquette).
        const p: any = { x: cx, y: cy, vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed, life: 1, delay: b.delay, color };
        p.update = (ctx: CanvasRenderingContext2D) => {
          if (p.delay > 0) { p.delay -= 16; return; }
          p.x += p.vx; p.y += p.vy; p.vy += 0.045; p.vx *= 0.985; p.vy *= 0.985; p.life -= 0.014;
          ctx.save(); ctx.globalAlpha = Math.max(p.life, 0);
          ctx.shadowColor = p.color; ctx.shadowBlur = 12;
          ctx.strokeStyle = p.color; ctx.lineWidth = 2.4; ctx.lineCap = "round";
          ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(p.x - p.vx * 1.8, p.y - p.vy * 1.8); ctx.stroke();
          ctx.restore();
        };
        all.push(p);
      }
    });
    return all;
  }, {}, ralentiDepuisDuree(dureeMs));
}

function etincelles(canvas: HTMLCanvasElement, dureeMs?: number) {
  return runParticles(canvas, (w, h) =>
    Array.from({ length: 38 }, () => {
      const angle = Math.random() * Math.PI * 2, speed = 5 + Math.random() * 5.5;
      const p: any = { x: w / 2, y: h / 2, vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed, life: 1 };
      p.update = (ctx: CanvasRenderingContext2D) => {
        p.x += p.vx; p.y += p.vy; p.vx *= 0.92; p.vy *= 0.92; p.life -= 0.045;
        ctx.save(); ctx.globalAlpha = Math.max(p.life, 0);
        ctx.shadowColor = accentColor(); ctx.shadowBlur = 8;
        ctx.strokeStyle = accentColor(); ctx.lineWidth = 2.2; ctx.lineCap = "round";
        ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(p.x - p.vx * 1.8, p.y - p.vy * 1.8); ctx.stroke();
        ctx.restore();
      };
      return p as Particle;
    })
  , {}, ralentiDepuisDuree(dureeMs));
}

function eclairOrage(canvas: HTMLCanvasElement, dureeMs?: number) {
  return runParticles(canvas, (w, h) => {
    const flash: Particle = {
      life: 1,
      update(ctx) {
        ctx.fillStyle = "#fff"; ctx.globalAlpha = Math.max(this.life, 0) * 0.75; ctx.fillRect(0, 0, w, h);
        this.life -= 0.1;
      },
    };
    const bolts: Particle[] = Array.from({ length: 3 }, () => {
      const startX = w * (0.2 + Math.random() * 0.6);
      const pts: [number, number][] = [[startX, 0]];
      let x = startX;
      for (let y = 0; y < h; y += h / 6) { x += (Math.random() - 0.5) * 44; pts.push([x, y + h / 6]); }
      return {
        life: 1,
        update(ctx) {
          ctx.save(); ctx.globalAlpha = Math.max(this.life, 0);
          ctx.shadowColor = accentColor(); ctx.shadowBlur = 14;
          ctx.strokeStyle = accentColor(); ctx.lineWidth = 3;
          ctx.beginPath(); pts.forEach(([x, y], i) => (i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y))); ctx.stroke();
          ctx.restore();
          this.life -= 0.045;
        },
      };
    });
    return [flash, ...bolts];
  }, {}, ralentiDepuisDuree(dureeMs));
}

function sakura(canvas: HTMLCanvasElement, dureeMs?: number) {
  return runParticles(canvas, (w, h) =>
    Array.from({ length: 40 }, () => {
      const p: any = {
        x: Math.random() * w, y: -20 - Math.random() * h * 0.5, vy: 0.6 + Math.random() * 0.8,
        sway: Math.random() * Math.PI * 2, swaySpeed: 0.02 + Math.random() * 0.02, life: 1, rot: Math.random() * Math.PI * 2,
      };
      p.update = (ctx: CanvasRenderingContext2D) => {
        p.sway += p.swaySpeed; p.x += Math.sin(p.sway) * 1.2; p.y += p.vy; p.rot += Math.sin(p.sway) * 0.05;
        if (p.y > h + 20) p.life = 0;
        ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.rot); ctx.fillStyle = "#f9a8d4"; ctx.globalAlpha = 0.85;
        ctx.beginPath(); ctx.moveTo(0, -5); ctx.quadraticCurveTo(5, 0, 0, 6); ctx.quadraticCurveTo(-5, 0, 0, -5); ctx.fill();
        ctx.restore();
      };
      return p as Particle;
    })
  , {}, ralentiDepuisDuree(dureeMs));
}

function ondeChoc(canvas: HTMLCanvasElement, dureeMs?: number) {
  return runParticles(canvas, (w, h) =>
    Array.from({ length: 4 }, (_, i) => {
      const p: any = { r: 0, delay: i * 140, life: 1 };
      p.update = (ctx: CanvasRenderingContext2D) => {
        if (p.delay > 0) { p.delay -= 16; return; }
        p.r += 5.5; p.life -= 0.018;
        ctx.save(); ctx.globalAlpha = Math.max(p.life, 0);
        ctx.shadowColor = accentColor(); ctx.shadowBlur = 16;
        ctx.strokeStyle = accentColor(); ctx.lineWidth = 3.5;
        ctx.beginPath(); ctx.arc(w / 2, h / 2, p.r, 0, Math.PI * 2); ctx.stroke();
        ctx.restore();
      };
      return p as Particle;
    })
  , {}, ralentiDepuisDuree(dureeMs));
}

function etoilesFilantes(canvas: HTMLCanvasElement, dureeMs?: number) {
  return runParticles(canvas, (w, h) =>
    Array.from({ length: 14 }, () => {
      const p: any = {
        x: Math.random() * w, y: Math.random() * h * 0.5, vx: -7 - Math.random() * 5, vy: 3.5 + Math.random() * 2.5,
        life: 1, delay: Math.random() * 350,
      };
      p.update = (ctx: CanvasRenderingContext2D) => {
        if (p.delay > 0) { p.delay -= 16; return; }
        p.x += p.vx; p.y += p.vy; p.life -= 0.018;
        const grad = ctx.createLinearGradient(p.x, p.y, p.x - p.vx * 5, p.y - p.vy * 5);
        grad.addColorStop(0, accentColor()); grad.addColorStop(1, "transparent");
        ctx.save(); ctx.globalAlpha = Math.max(p.life, 0);
        ctx.shadowColor = accentColor(); ctx.shadowBlur = 10;
        ctx.strokeStyle = grad; ctx.lineWidth = 2.4; ctx.lineCap = "round";
        ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(p.x - p.vx * 5, p.y - p.vy * 5); ctx.stroke();
        ctx.restore();
      };
      return p as Particle;
    })
  , {}, ralentiDepuisDuree(dureeMs));
}

function bulles(canvas: HTMLCanvasElement, dureeMs?: number) {
  return runParticles(canvas, (w, h) =>
    Array.from({ length: 26 }, () => {
      const p: any = {
        x: w / 2 + (Math.random() - 0.5) * 60, y: h * 0.7, r: 3 + Math.random() * 5,
        vy: -(1 + Math.random() * 1.5), wob: Math.random() * Math.PI * 2, life: 1,
      };
      p.update = (ctx: CanvasRenderingContext2D) => {
        p.wob += 0.05; p.x += Math.sin(p.wob) * 0.6; p.y += p.vy; p.life -= 0.012;
        ctx.globalAlpha = Math.max(p.life, 0) * 0.7; ctx.strokeStyle = accentColor(); ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2); ctx.stroke();
      };
      return p as Particle;
    })
  , {}, ralentiDepuisDuree(dureeMs));
}

function encreDispersee(canvas: HTMLCanvasElement, dureeMs?: number) {
  const cols = themePalette();
  return runParticles(canvas, (w, h) =>
    Array.from({ length: 24 }, () => {
      const angle = Math.random() * Math.PI * 2;
      const p: any = {
        x: w / 2, y: h / 2, vx: Math.cos(angle) * (2.5 + Math.random() * 3.5), vy: Math.sin(angle) * (2.5 + Math.random() * 3.5),
        r: 4 + Math.random() * 12, life: 1, color: cols[Math.floor(Math.random() * cols.length)],
      };
      p.update = (ctx: CanvasRenderingContext2D) => {
        p.x += p.vx; p.y += p.vy; p.vx *= 0.94; p.vy *= 0.94; p.r += 0.35; p.life -= 0.013;
        ctx.save(); ctx.globalAlpha = Math.max(p.life, 0) * 0.6;
        ctx.shadowColor = p.color; ctx.shadowBlur = 6; ctx.fillStyle = p.color;
        ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2); ctx.fill(); ctx.restore();
      };
      return p as Particle;
    })
  , {}, ralentiDepuisDuree(dureeMs));
}

function neige(canvas: HTMLCanvasElement, dureeMs?: number) {
  // Les flocons qui touchent le bas restent affichés (tas qui s'épaissit)
  // au lieu de disparaître hors-canvas.
  const settled: { x: number; y: number; r: number }[] = [];
  return runParticles(
    canvas,
    (w, h) =>
      Array.from({ length: 55 }, () => {
        const p: any = {
          x: Math.random() * w, y: -10 - Math.random() * h, vy: 0.4 + Math.random() * 0.6,
          sway: Math.random() * Math.PI * 2, r: 1.6 + Math.random() * 1.4, life: 1,
        };
        p.update = (ctx: CanvasRenderingContext2D) => {
          p.sway += 0.02; p.x += Math.sin(p.sway) * 0.5; p.y += p.vy;
          const landY = h - 4 - Math.random() * 10;
          if (p.y >= landY) {
            const tas = settled.filter((s) => Math.abs(s.x - p.x) < 14).length;
            settled.push({ x: p.x, y: h - Math.min(tas * 2.2, 22) - Math.random() * 3, r: p.r });
            p.life = 0;
            return;
          }
          ctx.globalAlpha = 0.85; ctx.fillStyle = "#fff";
          ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2); ctx.fill();
        };
        return p as Particle;
      }),
    {
      postDraw: (ctx) => {
        if (!settled.length) return;
        ctx.save(); ctx.fillStyle = "#fff"; ctx.globalAlpha = 0.9;
        settled.forEach((s) => { ctx.beginPath(); ctx.arc(s.x, s.y, s.r, 0, Math.PI * 2); ctx.fill(); });
        ctx.restore();
      },
    }
  , ralentiDepuisDuree(dureeMs));
}

function automne(canvas: HTMLCanvasElement, dureeMs?: number) {
  const cols = ["#D2691E", "#B22222", "#DAA520", "#8B4513", "#CD853F"];
  return runParticles(canvas, (w, h) =>
    Array.from({ length: 34 }, () => {
      const p: any = {
        x: Math.random() * w, y: -20 - Math.random() * h * 0.6, vy: 0.7 + Math.random() * 0.9,
        sway: Math.random() * Math.PI * 2, swaySpeed: 0.03 + Math.random() * 0.035, life: 1,
        rot: Math.random() * Math.PI * 2, vr: (Math.random() - 0.5) * 0.06, color: cols[Math.floor(Math.random() * cols.length)],
      };
      p.update = (ctx: CanvasRenderingContext2D) => {
        p.sway += p.swaySpeed; p.x += Math.sin(p.sway) * 1.8; p.y += p.vy; p.rot += p.vr;
        if (p.y > h + 20) p.life = 0;
        ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.rot); ctx.fillStyle = p.color; ctx.globalAlpha = 0.85;
        ctx.beginPath(); ctx.moveTo(0, -6); ctx.quadraticCurveTo(6, -2, 0, 7); ctx.quadraticCurveTo(-6, -2, 0, -6); ctx.fill();
        ctx.strokeStyle = "rgba(0,0,0,0.2)"; ctx.lineWidth = 0.6;
        ctx.beginPath(); ctx.moveTo(0, -5); ctx.lineTo(0, 6); ctx.stroke();
        ctx.restore();
      };
      return p as Particle;
    })
  , {}, ralentiDepuisDuree(dureeMs));
}

function printemps(canvas: HTMLCanvasElement, dureeMs?: number) {
  // Éclosion radiale (flash + pétales giclant du centre + pollen scintillant)
  // — refonte suite au retour "pas assez wow" de la première version flottante.
  const cols = ["#FBCFE8", "#FDE68A", "#BBF7D0", "#C7D2FE", "#FECACA", "#FFFFFF"];
  return runParticles(canvas, (w, h) => {
    const cx = w / 2, cy = h / 2;
    const flash: Particle = {
      life: 1,
      update(ctx) {
        ctx.save(); ctx.globalAlpha = Math.max(this.life, 0) * 0.35;
        const grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, Math.max(w, h) * 0.42);
        grad.addColorStop(0, "#fff"); grad.addColorStop(1, "transparent");
        ctx.fillStyle = grad; ctx.fillRect(0, 0, w, h); ctx.restore();
        this.life -= 0.06;
      },
    };
    const petales: Particle[] = Array.from({ length: 70 }, () => {
      const angle = Math.random() * Math.PI * 2, speed = 1.5 + Math.random() * 4.5;
      const p: any = {
        x: cx, y: cy, vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed - 1, life: 1,
        rot: Math.random() * Math.PI * 2, vr: (Math.random() - 0.5) * 0.12, sway: Math.random() * Math.PI * 2,
        r: 3 + Math.random() * 4, color: cols[Math.floor(Math.random() * cols.length)],
      };
      p.update = (ctx: CanvasRenderingContext2D) => {
        p.sway += 0.05; p.x += p.vx * 0.09 + Math.sin(p.sway) * 0.3; p.y += p.vy * 0.09; p.vy += 0.012; p.vx *= 0.985;
        p.rot += p.vr; p.life -= 0.008;
        ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.rot);
        ctx.globalAlpha = Math.max(p.life, 0) * 0.9; ctx.shadowColor = p.color; ctx.shadowBlur = 7;
        ctx.fillStyle = p.color;
        ctx.beginPath(); ctx.ellipse(0, 0, p.r, p.r * 0.6, 0, 0, Math.PI * 2); ctx.fill();
        ctx.restore();
      };
      return p as Particle;
    });
    const pollen: Particle[] = Array.from({ length: 26 }, () => {
      const angle = Math.random() * Math.PI * 2, speed = 0.5 + Math.random() * 1.6;
      const p: any = { x: cx, y: cy, vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed, life: 1, tw: Math.random() * Math.PI * 2 };
      p.update = (ctx: CanvasRenderingContext2D) => {
        p.x += p.vx * 0.5; p.y += p.vy * 0.5; p.tw += 0.22; p.life -= 0.011;
        ctx.save(); ctx.globalAlpha = Math.max(p.life, 0) * (0.4 + 0.6 * Math.max(Math.sin(p.tw), 0));
        ctx.fillStyle = "#FDE68A"; ctx.shadowColor = "#FDE68A"; ctx.shadowBlur = 9;
        ctx.beginPath(); ctx.arc(p.x, p.y, 1.7, 0, Math.PI * 2); ctx.fill(); ctx.restore();
      };
      return p as Particle;
    });
    return [flash, ...petales, ...pollen];
  }, {}, ralentiDepuisDuree(dureeMs));
}

function vent(canvas: HTMLCanvasElement, dureeMs?: number) {
  return runParticles(canvas, (w, h) => {
    const rafales: Particle[] = Array.from({ length: 16 }, () => {
      const y0 = Math.random() * h;
      const p: any = {
        x: -80 - Math.random() * 220, y: y0, vx: 10 + Math.random() * 8, amp: 6 + Math.random() * 12,
        phase: Math.random() * Math.PI * 2, life: 1, delay: Math.random() * 450,
      };
      p.update = (ctx: CanvasRenderingContext2D) => {
        if (p.delay > 0) { p.delay -= 16; return; }
        p.x += p.vx; p.phase += 0.16;
        if (p.x > w + 80) { p.life = 0; return; }
        const yy = p.y + Math.sin(p.phase) * p.amp * 0.35;
        const grad = ctx.createLinearGradient(p.x - 75, yy, p.x, yy);
        grad.addColorStop(0, "rgba(255,255,255,0)"); grad.addColorStop(1, "rgba(255,255,255,0.7)");
        ctx.save(); ctx.strokeStyle = grad; ctx.lineWidth = 2.2; ctx.shadowColor = "#fff"; ctx.shadowBlur = 4;
        ctx.beginPath(); ctx.moveTo(p.x - 75, yy + 7); ctx.quadraticCurveTo(p.x - 35, yy - p.amp * 0.5, p.x, yy); ctx.stroke();
        ctx.restore();
      };
      return p as Particle;
    });
    const debris: Particle[] = Array.from({ length: 12 }, () => {
      const p: any = {
        x: -20 - Math.random() * 200, y: Math.random() * h, vx: 6 + Math.random() * 5, vy: (Math.random() - 0.5) * 1.5,
        rot: Math.random() * Math.PI * 2, vr: (Math.random() - 0.5) * 0.4, life: 1, delay: Math.random() * 600, color: accentColor(),
      };
      p.update = (ctx: CanvasRenderingContext2D) => {
        if (p.delay > 0) { p.delay -= 16; return; }
        p.x += p.vx; p.y += p.vy; p.rot += p.vr;
        if (p.x > w + 20) { p.life = 0; return; }
        ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.rot); ctx.globalAlpha = 0.75;
        ctx.fillStyle = p.color; ctx.fillRect(-3, -1.5, 6, 3); ctx.restore();
      };
      return p as Particle;
    });
    return [...rafales, ...debris];
  }, {}, ralentiDepuisDuree(dureeMs));
}

function pluie(canvas: HTMLCanvasElement, dureeMs?: number) {
  // Boucle sur elle-même (les gouttes qui touchent le bas repartent du haut)
  // pendant une durée totale fixe, avec éclaboussures au sol qui s'estompent.
  const splashes: { x: number; y: number; life: number; r: number }[] = [];
  let elapsed = 0;
  let done = false;
  return runParticles(
    canvas,
    (w, h) =>
      Array.from({ length: 65 }, () => {
        const p: any = { x: Math.random() * w, y: -Math.random() * h, vy: 9 + Math.random() * 5, len: 14 + Math.random() * 10, life: 1 };
        p.update = (ctx: CanvasRenderingContext2D) => {
          if (done) { p.life = 0; return; }
          p.y += p.vy; p.x += 1.3;
          if (p.y > h) {
            splashes.push({ x: p.x, y: h - 2, life: 1, r: 0 });
            p.y = -20 - Math.random() * 60; p.x = Math.random() * w;
          }
          const grad = ctx.createLinearGradient(p.x, p.y, p.x - 3.9, p.y - p.len);
          grad.addColorStop(0, "rgba(190,215,255,0.95)"); grad.addColorStop(1, "rgba(190,215,255,0)");
          ctx.save(); ctx.strokeStyle = grad; ctx.lineWidth = 1.6; ctx.shadowColor = "#bcd8ff"; ctx.shadowBlur = 3;
          ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(p.x - 3.9, p.y - p.len); ctx.stroke();
          ctx.restore();
        };
        return p as Particle;
      }),
    {
      postDraw: (ctx) => {
        elapsed += 16;
        if (elapsed > 2200) done = true;
        for (let i = splashes.length - 1; i >= 0; i--) {
          const s = splashes[i];
          s.life -= 0.09; s.r += 1.5;
          if (s.life <= 0) { splashes.splice(i, 1); continue; }
          ctx.save(); ctx.globalAlpha = Math.max(s.life, 0) * 0.55; ctx.strokeStyle = "#cfe3ff"; ctx.lineWidth = 1;
          ctx.beginPath(); ctx.ellipse(s.x, s.y, s.r * 1.5, s.r * 0.5, 0, 0, Math.PI * 2); ctx.stroke();
          ctx.restore();
        }
      },
    }
  , ralentiDepuisDuree(dureeMs));
}

// --- Nouveaux effets (v21) --------------------------------------------------

function arcEnCiel(canvas: HTMLCanvasElement, dureeMs?: number) {
  // Palette arc-en-ciel fixe (pas themePalette()) — l'identité de cet
  // effet, c'est justement de ne PAS suivre le thème.
  const cols = ["#FF3B30", "#FF9500", "#FFD500", "#34C759", "#0A84FF", "#5E5CE6", "#BF5AF2"];
  return runParticles(canvas, (w, h) =>
    Array.from({ length: 90 }, (_, i) => {
      const p: any = {
        x: w / 2, y: h * 0.35, vx: (Math.random() - 0.5) * 7, vy: -Math.random() * 6 - 2, life: 1,
        rot: Math.random() * Math.PI * 2, vr: (Math.random() - 0.5) * 0.3,
        color: cols[i % cols.length], w: 4, h: 14 + Math.random() * 8,
      };
      p.update = (ctx: CanvasRenderingContext2D) => {
        p.x += p.vx; p.y += p.vy; p.vy += 0.15; p.rot += p.vr; p.life -= 0.01;
        ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.rot); ctx.globalAlpha = Math.max(p.life, 0);
        ctx.fillStyle = p.color; ctx.fillRect(-p.w / 2, -p.h / 2, p.w, p.h); ctx.restore();
      };
      return p as Particle;
    })
  , {}, ralentiDepuisDuree(dureeMs));
}

function laser(canvas: HTMLCanvasElement, dureeMs?: number) {
  const accent = accentColor();
  return runParticles(canvas, (w, h) => {
    const cx = w / 2, cy = h * 0.45;
    return Array.from({ length: 24 }, (_, i) => {
      const angle = (i / 24) * Math.PI * 2;
      const p: any = { x: cx, y: cy, angle, longueur: 0, life: 1 };
      p.update = (ctx: CanvasRenderingContext2D) => {
        p.longueur += 22; p.life -= 0.03;
        const x2 = cx + Math.cos(p.angle) * p.longueur;
        const y2 = cy + Math.sin(p.angle) * p.longueur;
        ctx.save(); ctx.globalAlpha = Math.max(p.life, 0);
        ctx.strokeStyle = accent; ctx.lineWidth = 2.5; ctx.shadowColor = accent; ctx.shadowBlur = 8;
        ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(x2, y2); ctx.stroke(); ctx.restore();
      };
      return p as Particle;
    });
  }, {}, ralentiDepuisDuree(dureeMs));
}

function pixelExplosion(canvas: HTMLCanvasElement, dureeMs?: number) {
  const cols = themePalette();
  return runParticles(canvas, (w, h) =>
    Array.from({ length: 70 }, () => {
      const taille = 6 + Math.floor(Math.random() * 3) * 4; // 6, 10 ou 14 — look "gros pixel"
      const p: any = {
        x: w / 2, y: h * 0.4, vx: (Math.random() - 0.5) * 9, vy: (Math.random() - 0.5) * 9 - 2, life: 1,
        color: cols[Math.floor(Math.random() * cols.length)], taille,
      };
      p.update = (ctx: CanvasRenderingContext2D) => {
        p.x += p.vx; p.y += p.vy; p.vy += 0.12; p.life -= 0.015;
        ctx.save(); ctx.globalAlpha = Math.max(p.life, 0); ctx.fillStyle = p.color;
        ctx.fillRect(Math.round(p.x / p.taille) * p.taille, Math.round(p.y / p.taille) * p.taille, p.taille - 1, p.taille - 1);
        ctx.restore();
      };
      return p as Particle;
    })
  , {}, ralentiDepuisDuree(dureeMs));
}

function vagueOnde(canvas: HTMLCanvasElement, dureeMs?: number) {
  const accent = accentColor();
  return runParticles(canvas, (w, h) =>
    Array.from({ length: 4 }, (_, i) => {
      const p: any = { x: w / 2, y: h * 0.45, r: 0, life: 1, delai: i * 220 };
      p.update = (ctx: CanvasRenderingContext2D) => {
        if (p.delai > 0) { p.delai -= 16; return; }
        p.r += 5.5; p.life -= 0.014;
        ctx.save(); ctx.globalAlpha = Math.max(p.life, 0) * 0.7;
        ctx.strokeStyle = accent; ctx.lineWidth = 3;
        ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2); ctx.stroke(); ctx.restore();
      };
      return p as Particle;
    })
  , {}, ralentiDepuisDuree(dureeMs));
}

function spirale(canvas: HTMLCanvasElement, dureeMs?: number) {
  const cols = themePalette();
  return runParticles(canvas, (w, h) =>
    Array.from({ length: 100 }, (_, i) => {
      const p: any = {
        x: w / 2, y: h * 0.4, angle: (i / 100) * Math.PI * 10, rayon: 0,
        color: cols[i % cols.length], life: 1,
      };
      p.update = (ctx: CanvasRenderingContext2D) => {
        p.angle += 0.13; p.rayon += 2.1; p.life -= 0.012;
        const x = w / 2 + Math.cos(p.angle) * p.rayon;
        const y = h * 0.4 + Math.sin(p.angle) * p.rayon * 0.7;
        ctx.save(); ctx.globalAlpha = Math.max(p.life, 0); ctx.fillStyle = p.color;
        ctx.beginPath(); ctx.arc(x, y, 3.5, 0, Math.PI * 2); ctx.fill(); ctx.restore();
      };
      return p as Particle;
    })
  , {}, ralentiDepuisDuree(dureeMs));
}

function coeurs(canvas: HTMLCanvasElement, dureeMs?: number) {
  // Glyphe "♥" via fillText plutôt qu'un chemin bézier fait main — plus
  // simple et fiable, rendu correct sur toutes les polices système.
  const rouge = cssVar("--danger") || "#e05a7a";
  const accent = accentColor();
  return runParticles(canvas, (w, h) =>
    Array.from({ length: 26 }, () => {
      const p: any = {
        x: w * (0.15 + Math.random() * 0.7), y: h * (0.75 + Math.random() * 0.2),
        vx: (Math.random() - 0.5) * 1.2, vy: -1.2 - Math.random() * 1.4, life: 1,
        taille: 16 + Math.random() * 18, couleur: Math.random() > 0.5 ? rouge : accent,
      };
      p.update = (ctx: CanvasRenderingContext2D) => {
        p.x += p.vx; p.y += p.vy; p.life -= 0.009;
        ctx.save(); ctx.globalAlpha = Math.max(p.life, 0); ctx.font = `${p.taille}px sans-serif`;
        ctx.fillStyle = p.couleur; ctx.textAlign = "center"; ctx.fillText("♥", p.x, p.y); ctx.restore();
      };
      return p as Particle;
    })
  , {}, ralentiDepuisDuree(dureeMs));
}

function fumee(canvas: HTMLCanvasElement, dureeMs?: number) {
  return runParticles(canvas, (w, h) =>
    Array.from({ length: 20 }, () => {
      const p: any = {
        x: w * (0.3 + Math.random() * 0.4), y: h * 0.75,
        vx: (Math.random() - 0.5) * 0.7, vy: -0.5 - Math.random() * 0.7, life: 1,
        r: 14 + Math.random() * 10,
      };
      p.update = (ctx: CanvasRenderingContext2D) => {
        p.x += p.vx; p.y += p.vy; p.r += 0.35; p.life -= 0.007;
        ctx.save(); ctx.globalAlpha = Math.max(p.life, 0) * 0.28;
        ctx.fillStyle = "#c8ccd4"; ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2); ctx.fill(); ctx.restore();
      };
      return p as Particle;
    })
  , {}, ralentiDepuisDuree(dureeMs));
}

function eclatsDeVerre(canvas: HTMLCanvasElement, dureeMs?: number) {
  // Palette froide fixe (pas themePalette()) — évoque le verre/glace quel
  // que soit le thème actif, comme arcEnCiel pour l'arc-en-ciel.
  const cols = ["#EAF6FF", "#BFE3FF", "#8FD0FF", "#5FB8F0"];
  return runParticles(canvas, (w, h) =>
    Array.from({ length: 60 }, () => {
      const p: any = {
        x: w / 2, y: h * 0.4, vx: (Math.random() - 0.5) * 10, vy: (Math.random() - 0.5) * 8 - 1, life: 1,
        rot: Math.random() * Math.PI * 2, vr: (Math.random() - 0.5) * 0.5,
        color: cols[Math.floor(Math.random() * cols.length)], taille: 5 + Math.random() * 7,
      };
      p.update = (ctx: CanvasRenderingContext2D) => {
        p.x += p.vx; p.y += p.vy; p.vy += 0.2; p.rot += p.vr; p.life -= 0.016;
        ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.rot); ctx.globalAlpha = Math.max(p.life, 0);
        ctx.fillStyle = p.color; ctx.beginPath();
        ctx.moveTo(0, -p.taille); ctx.lineTo(p.taille * 0.7, p.taille * 0.6); ctx.lineTo(-p.taille * 0.7, p.taille * 0.6);
        ctx.closePath(); ctx.fill(); ctx.restore();
      };
      return p as Particle;
    })
  , {}, ralentiDepuisDuree(dureeMs));
}


// --- Nouveaux effets (v26) --------------------------------------------------

function supernova(canvas: HTMLCanvasElement, dureeMs?: number) {
  const accent = accentColor();
  const cols = themePalette();
  return runParticles(canvas, (w, h) => {
    const cx = w / 2, cy = h * 0.42;
    const parts: Particle[] = [];
    // Onde de choc centrale + éclats projetés : deux "couches" qui donnent
    // l'impression d'une explosion en profondeur plutôt qu'à plat.
    const onde: any = { x: cx, y: cy, r: 0, life: 1 };
    onde.update = (ctx: CanvasRenderingContext2D) => {
      onde.r += 7; onde.life -= 0.022;
      ctx.save(); ctx.globalAlpha = Math.max(onde.life, 0) * 0.8;
      ctx.strokeStyle = accent; ctx.lineWidth = 4; ctx.shadowColor = accent; ctx.shadowBlur = 14;
      ctx.beginPath(); ctx.arc(cx, cy, onde.r, 0, Math.PI * 2); ctx.stroke(); ctx.restore();
    };
    parts.push(onde as Particle);
    for (let i = 0; i < 80; i++) {
      const angle = Math.random() * Math.PI * 2;
      const vitesse = 2 + Math.random() * 9;
      const p: any = {
        x: cx, y: cy, vx: Math.cos(angle) * vitesse, vy: Math.sin(angle) * vitesse,
        life: 1, color: cols[Math.floor(Math.random() * cols.length)], r: 1.5 + Math.random() * 2.5,
      };
      p.update = (ctx: CanvasRenderingContext2D) => {
        p.x += p.vx; p.y += p.vy; p.vx *= 0.97; p.vy *= 0.97; p.life -= 0.014;
        ctx.save(); ctx.globalAlpha = Math.max(p.life, 0); ctx.fillStyle = p.color;
        ctx.shadowColor = p.color; ctx.shadowBlur = 6;
        ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2); ctx.fill(); ctx.restore();
      };
      parts.push(p as Particle);
    }
    return parts;
  }, {}, ralentiDepuisDuree(dureeMs));
}

function matrice(canvas: HTMLCanvasElement, dureeMs?: number) {
  const vert = "#3BE87A";
  const GLYPHES = "01ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄ";
  return runParticles(canvas, (w, h) => {
    const colonnes = Math.floor(w / 14);
    return Array.from({ length: colonnes }, (_, i) => {
      const p: any = {
        x: i * 14 + 7, y: Math.random() * -h, vitesse: 4 + Math.random() * 7,
        life: 1, longueur: 5 + Math.floor(Math.random() * 8),
      };
      p.update = (ctx: CanvasRenderingContext2D) => {
        p.y += p.vitesse; p.life -= 0.008;
        ctx.save(); ctx.font = "12px monospace"; ctx.textAlign = "center";
        for (let k = 0; k < p.longueur; k++) {
          const yk = p.y - k * 13;
          if (yk < 0 || yk > h) continue;
          // Tête plus claire, traîne dégradée — le rendu "pluie de code".
          ctx.globalAlpha = Math.max(p.life, 0) * (k === 0 ? 1 : Math.max(0, 1 - k / p.longueur) * 0.7);
          ctx.fillStyle = k === 0 ? "#CFFFE0" : vert;
          ctx.fillText(GLYPHES[Math.floor(Math.random() * GLYPHES.length)], p.x, yk);
        }
        ctx.restore();
      };
      return p as Particle;
    });
  }, {}, ralentiDepuisDuree(dureeMs));
}

function bulleSavon(canvas: HTMLCanvasElement, dureeMs?: number) {
  return runParticles(canvas, (w, h) =>
    Array.from({ length: 26 }, () => {
      const p: any = {
        x: w * (0.1 + Math.random() * 0.8), y: h + 20,
        vx: (Math.random() - 0.5) * 0.8, vy: -0.9 - Math.random() * 1.6,
        life: 1, r: 8 + Math.random() * 20, phase: Math.random() * Math.PI * 2,
      };
      p.update = (ctx: CanvasRenderingContext2D) => {
        p.phase += 0.05;
        p.x += p.vx + Math.sin(p.phase) * 0.6; p.y += p.vy; p.life -= 0.008;
        const a = Math.max(p.life, 0);
        ctx.save(); ctx.globalAlpha = a * 0.55;
        // Dégradé irisé : bord coloré, centre transparent — l'aspect savon.
        const g = ctx.createRadialGradient(p.x, p.y, p.r * 0.2, p.x, p.y, p.r);
        g.addColorStop(0, "rgba(255,255,255,0.05)");
        g.addColorStop(0.75, "rgba(160,220,255,0.25)");
        g.addColorStop(1, "rgba(255,190,240,0.55)");
        ctx.fillStyle = g;
        ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2); ctx.fill();
        ctx.globalAlpha = a * 0.7; ctx.fillStyle = "rgba(255,255,255,0.8)";
        ctx.beginPath(); ctx.arc(p.x - p.r * 0.3, p.y - p.r * 0.35, p.r * 0.13, 0, Math.PI * 2); ctx.fill();
        ctx.restore();
      };
      return p as Particle;
    }), {}, ralentiDepuisDuree(dureeMs)
  );
}

function poussiereEtoiles(canvas: HTMLCanvasElement, dureeMs?: number) {
  const cols = themePalette();
  return runParticles(canvas, (w, h) =>
    Array.from({ length: 110 }, () => {
      const p: any = {
        x: w / 2 + (Math.random() - 0.5) * 60, y: h * 0.4 + (Math.random() - 0.5) * 60,
        vx: (Math.random() - 0.5) * 3.4, vy: (Math.random() - 0.5) * 3.4 - 0.5,
        life: 1, color: cols[Math.floor(Math.random() * cols.length)],
        r: 0.8 + Math.random() * 1.8, scint: Math.random() * Math.PI * 2,
      };
      p.update = (ctx: CanvasRenderingContext2D) => {
        p.x += p.vx; p.y += p.vy; p.vy += 0.015; p.life -= 0.007; p.scint += 0.3;
        // Scintillement : l'opacité oscille, chaque particule à son rythme.
        const a = Math.max(p.life, 0) * (0.55 + Math.sin(p.scint) * 0.45);
        ctx.save(); ctx.globalAlpha = a; ctx.fillStyle = p.color;
        ctx.shadowColor = p.color; ctx.shadowBlur = 8;
        ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2); ctx.fill(); ctx.restore();
      };
      return p as Particle;
    }), {}, ralentiDepuisDuree(dureeMs)
  );
}

function feuilleMorte(canvas: HTMLCanvasElement, dureeMs?: number) {
  const cols = ["#C1440E", "#D97706", "#B45309", "#92400E", "#E8A33D"];
  return runParticles(canvas, (w, h) =>
    Array.from({ length: 34 }, () => {
      const p: any = {
        x: Math.random() * w, y: -20 - Math.random() * h * 0.5,
        vy: 0.9 + Math.random() * 1.5, life: 1, phase: Math.random() * Math.PI * 2,
        amplitude: 15 + Math.random() * 30, rot: Math.random() * Math.PI,
        vr: (Math.random() - 0.5) * 0.12, taille: 5 + Math.random() * 6,
        color: cols[Math.floor(Math.random() * cols.length)], baseX: 0,
      };
      p.baseX = p.x;
      p.update = (ctx: CanvasRenderingContext2D) => {
        p.phase += 0.035; p.y += p.vy; p.rot += p.vr; p.life -= 0.0055;
        // Balancement latéral : la feuille tombe en zigzag, pas en ligne droite.
        p.x = p.baseX + Math.sin(p.phase) * p.amplitude;
        ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.rot);
        ctx.globalAlpha = Math.max(p.life, 0); ctx.fillStyle = p.color;
        ctx.beginPath(); ctx.ellipse(0, 0, p.taille, p.taille * 0.55, 0, 0, Math.PI * 2); ctx.fill();
        ctx.restore();
      };
      return p as Particle;
    }), {}, ralentiDepuisDuree(dureeMs)
  );
}

function aurore(canvas: HTMLCanvasElement, dureeMs?: number) {
  return runParticles(canvas, (w, h) =>
    Array.from({ length: 5 }, (_, i) => {
      const p: any = {
        life: 1, phase: i * 1.2, offset: i * (h * 0.07), amplitude: 18 + i * 6,
        color: i % 2 === 0 ? "rgba(80,255,180," : "rgba(150,120,255,",
      };
      p.update = (ctx: CanvasRenderingContext2D) => {
        p.phase += 0.03; p.life -= 0.006;
        const a = Math.max(p.life, 0) * 0.4;
        ctx.save();
        // Voile ondulant dessiné en bandes verticales dégradées.
        for (let x = 0; x <= w; x += 6) {
          const y = h * 0.3 + p.offset + Math.sin(x * 0.012 + p.phase) * p.amplitude;
          const g = ctx.createLinearGradient(0, y - 40, 0, y + 40);
          g.addColorStop(0, p.color + "0)");
          g.addColorStop(0.5, p.color + a + ")");
          g.addColorStop(1, p.color + "0)");
          ctx.fillStyle = g;
          ctx.fillRect(x, y - 40, 7, 80);
        }
        ctx.restore();
      };
      return p as Particle;
    }), {}, ralentiDepuisDuree(dureeMs)
  );
}

function kaleidoscope(canvas: HTMLCanvasElement, dureeMs?: number) {
  const cols = themePalette();
  return runParticles(canvas, (w, h) =>
    Array.from({ length: 40 }, (_, i) => {
      const p: any = {
        angle: (i / 40) * Math.PI * 2, rayon: 5, life: 1,
        vitesseAngle: 0.04 + Math.random() * 0.03, vitesseRayon: 1.4 + Math.random() * 1.6,
        color: cols[i % cols.length], taille: 3 + Math.random() * 4,
      };
      p.update = (ctx: CanvasRenderingContext2D) => {
        p.angle += p.vitesseAngle; p.rayon += p.vitesseRayon; p.life -= 0.011;
        const cx = w / 2, cy = h * 0.42;
        ctx.save(); ctx.globalAlpha = Math.max(p.life, 0); ctx.fillStyle = p.color;
        // 6 symétries : c'est ce qui donne le rendu kaléidoscope.
        for (let s = 0; s < 6; s++) {
          const a = p.angle + (s / 6) * Math.PI * 2;
          ctx.beginPath();
          ctx.arc(cx + Math.cos(a) * p.rayon, cy + Math.sin(a) * p.rayon, p.taille, 0, Math.PI * 2);
          ctx.fill();
        }
        ctx.restore();
      };
      return p as Particle;
    }), {}, ralentiDepuisDuree(dureeMs)
  );
}

function impulsion(canvas: HTMLCanvasElement, dureeMs?: number) {
  const accent = accentColor();
  return runParticles(canvas, (w, h) =>
    Array.from({ length: 6 }, (_, i) => {
      const p: any = { r: 0, life: 1, delai: i * 130, epaisseur: 5 - i * 0.6 };
      p.update = (ctx: CanvasRenderingContext2D) => {
        if (p.delai > 0) { p.delai -= 16; return; }
        p.r += 6.5; p.life -= 0.016;
        const a = Math.max(p.life, 0);
        ctx.save(); ctx.globalAlpha = a * 0.75;
        ctx.strokeStyle = accent; ctx.lineWidth = Math.max(p.epaisseur, 1);
        ctx.shadowColor = accent; ctx.shadowBlur = 12;
        // Anneau + halo intérieur : plus "énergie" qu'une simple onde.
        ctx.beginPath(); ctx.arc(w / 2, h * 0.42, p.r, 0, Math.PI * 2); ctx.stroke();
        ctx.globalAlpha = a * 0.15;
        ctx.beginPath(); ctx.arc(w / 2, h * 0.42, p.r * 0.75, 0, Math.PI * 2); ctx.stroke();
        ctx.restore();
      };
      return p as Particle;
    }), {}, ralentiDepuisDuree(dureeMs)
  );
}


// --- Nouveaux effets (v27) ---------------------------------------------------

function trouNoir(canvas: HTMLCanvasElement, dureeMs?: number) {
  // Inverse des autres effets : les particules CONVERGENT vers le centre en
  // accélérant, au lieu d'exploser vers l'extérieur.
  const cols = themePalette();
  return runParticles(canvas, (w, h) =>
    Array.from({ length: 90 }, () => {
      const angle = Math.random() * Math.PI * 2;
      const rayon = 90 + Math.random() * 130;
      const p: any = {
        cx: w / 2, cy: h * 0.42, angle, rayon, life: 1,
        vitesseAngle: 0.04 + Math.random() * 0.05,
        color: cols[Math.floor(Math.random() * cols.length)],
        taille: 1.5 + Math.random() * 2.5,
      };
      p.update = (ctx: CanvasRenderingContext2D) => {
        // Aspiration : plus on est proche, plus ça va vite (comme une vraie
        // spirale d'accrétion).
        p.rayon -= 1.4 + (140 - Math.min(p.rayon, 140)) * 0.035;
        p.angle += p.vitesseAngle;
        p.life -= 0.008;
        if (p.rayon <= 2) p.life = 0;
        const x = p.cx + Math.cos(p.angle) * p.rayon;
        const y = p.cy + Math.sin(p.angle) * p.rayon * 0.75;
        ctx.save(); ctx.globalAlpha = Math.max(p.life, 0);
        ctx.fillStyle = p.color;
        ctx.beginPath(); ctx.arc(x, y, p.taille, 0, Math.PI * 2); ctx.fill(); ctx.restore();
      };
      return p as Particle;
    })
  , {}, ralentiDepuisDuree(dureeMs));
}

function eclatPrisme(canvas: HTMLCanvasElement, dureeMs?: number) {
  // Faisceaux triangulaires colorés, façon réfraction — palette fixe, c'est
  // l'identité de l'effet (comme arcEnCiel).
  const cols = ["#FF3B5C", "#FF9F1C", "#FFE066", "#4ECDC4", "#4D96FF", "#9B5DE5"];
  return runParticles(canvas, (w, h) =>
    Array.from({ length: 18 }, (_, i) => {
      const p: any = {
        cx: w / 2, cy: h * 0.42, angle: (i / 18) * Math.PI * 2,
        longueur: 0, largeur: 0.06 + Math.random() * 0.06, life: 1,
        color: cols[i % cols.length],
      };
      p.update = (ctx: CanvasRenderingContext2D) => {
        p.longueur += 16; p.life -= 0.022;
        ctx.save(); ctx.globalAlpha = Math.max(p.life, 0) * 0.75;
        ctx.fillStyle = p.color;
        ctx.beginPath();
        ctx.moveTo(p.cx, p.cy);
        ctx.lineTo(p.cx + Math.cos(p.angle - p.largeur) * p.longueur, p.cy + Math.sin(p.angle - p.largeur) * p.longueur);
        ctx.lineTo(p.cx + Math.cos(p.angle + p.largeur) * p.longueur, p.cy + Math.sin(p.angle + p.largeur) * p.longueur);
        ctx.closePath(); ctx.fill(); ctx.restore();
      };
      return p as Particle;
    })
  , {}, ralentiDepuisDuree(dureeMs));
}

function nueeInsectes(canvas: HTMLCanvasElement, dureeMs?: number) {
  // Mouvement erratique (bruit pseudo-aléatoire par particule) plutôt qu'une
  // trajectoire balistique — donne un côté "essaim vivant".
  const accent = accentColor();
  return runParticles(canvas, (w, h) =>
    Array.from({ length: 55 }, () => {
      const p: any = {
        x: w / 2 + (Math.random() - 0.5) * 60, y: h * 0.42 + (Math.random() - 0.5) * 60,
        vx: (Math.random() - 0.5) * 3, vy: (Math.random() - 0.5) * 3,
        phase: Math.random() * Math.PI * 2, life: 1, taille: 1.5 + Math.random() * 1.5,
      };
      p.update = (ctx: CanvasRenderingContext2D) => {
        p.phase += 0.3;
        p.vx += Math.cos(p.phase) * 0.5;
        p.vy += Math.sin(p.phase * 1.3) * 0.5;
        // Frottement : sans ça, les impulsions s'accumulent et tout part au loin.
        p.vx *= 0.92; p.vy *= 0.92;
        p.x += p.vx; p.y += p.vy;
        p.life -= 0.009;
        ctx.save(); ctx.globalAlpha = Math.max(p.life, 0);
        ctx.fillStyle = accent;
        ctx.beginPath(); ctx.arc(p.x, p.y, p.taille, 0, Math.PI * 2); ctx.fill(); ctx.restore();
      };
      return p as Particle;
    })
  , {}, ralentiDepuisDuree(dureeMs));
}

function vortexEncre(canvas: HTMLCanvasElement, dureeMs?: number) {
  // Taches qui s'étalent en tournant, comme de l'encre dans l'eau.
  const cols = themePalette();
  return runParticles(canvas, (w, h) =>
    Array.from({ length: 26 }, (_, i) => {
      const p: any = {
        cx: w / 2, cy: h * 0.42, angle: (i / 26) * Math.PI * 2 + Math.random() * 0.4,
        rayon: 10 + Math.random() * 30, r: 6 + Math.random() * 10, life: 1,
        color: cols[Math.floor(Math.random() * cols.length)],
      };
      p.update = (ctx: CanvasRenderingContext2D) => {
        p.angle += 0.045; p.rayon += 1.6; p.r += 0.5; p.life -= 0.011;
        const x = p.cx + Math.cos(p.angle) * p.rayon;
        const y = p.cy + Math.sin(p.angle) * p.rayon * 0.7;
        ctx.save(); ctx.globalAlpha = Math.max(p.life, 0) * 0.4;
        ctx.fillStyle = p.color;
        ctx.beginPath(); ctx.arc(x, y, p.r, 0, Math.PI * 2); ctx.fill(); ctx.restore();
      };
      return p as Particle;
    })
  , {}, ralentiDepuisDuree(dureeMs));
}

function grelons(canvas: HTMLCanvasElement, dureeMs?: number) {
  // Chute rapide + rebond au sol : contraste avec la neige, qui flotte.
  return runParticles(canvas, (w, h) =>
    Array.from({ length: 48 }, () => {
      const p: any = {
        x: Math.random() * w, y: -10 - Math.random() * 60,
        vy: 5 + Math.random() * 4, vx: (Math.random() - 0.5) * 1.2,
        life: 1, taille: 2 + Math.random() * 2.5, rebonds: 0,
      };
      p.update = (ctx: CanvasRenderingContext2D) => {
        p.x += p.vx; p.y += p.vy; p.vy += 0.35;
        const sol = h * 0.86;
        if (p.y >= sol && p.rebonds < 2) {
          p.y = sol; p.vy = -p.vy * 0.42; p.rebonds++;
          p.vx *= 0.7;
        }
        p.life -= p.rebonds >= 2 ? 0.05 : 0.008;
        ctx.save(); ctx.globalAlpha = Math.max(p.life, 0) * 0.9;
        ctx.fillStyle = "#DCEBFF";
        ctx.beginPath(); ctx.arc(p.x, p.y, p.taille, 0, Math.PI * 2); ctx.fill(); ctx.restore();
      };
      return p as Particle;
    })
  , {}, ralentiDepuisDuree(dureeMs));
}

function braises(canvas: HTMLCanvasElement, dureeMs?: number) {
  // Montée depuis le bas avec scintillement — inverse de la pluie/neige.
  return runParticles(canvas, (w, h) =>
    Array.from({ length: 44 }, () => {
      const p: any = {
        x: w * (0.2 + Math.random() * 0.6), y: h * 0.9 + Math.random() * 20,
        vx: (Math.random() - 0.5) * 0.8, vy: -1 - Math.random() * 1.8,
        life: 1, taille: 1.2 + Math.random() * 2, scintille: Math.random() * Math.PI * 2,
      };
      p.update = (ctx: CanvasRenderingContext2D) => {
        p.scintille += 0.35;
        p.x += p.vx + Math.sin(p.scintille) * 0.4;
        p.y += p.vy;
        p.vy *= 0.995;
        p.life -= 0.0085;
        // Du jaune vif vers le rouge sombre en refroidissant.
        const chaleur = Math.max(p.life, 0);
        const r = 255;
        const g = Math.round(80 + chaleur * 150);
        const b = Math.round(20 + chaleur * 40);
        ctx.save();
        ctx.globalAlpha = chaleur * (0.65 + Math.sin(p.scintille) * 0.35);
        ctx.fillStyle = `rgb(${r},${g},${b})`;
        ctx.beginPath(); ctx.arc(p.x, p.y, p.taille, 0, Math.PI * 2); ctx.fill();
        ctx.restore();
      };
      return p as Particle;
    })
  , {}, ralentiDepuisDuree(dureeMs));
}


// --- Effets v28 ---------------------------------------------------------------

function feuArtificeMulti(canvas: HTMLCanvasElement, dureeMs?: number) {
  // Plusieurs explosions décalées dans le temps ET l'espace, contrairement
  // à feuxArtifice qui part d'un seul point.
  const cols = themePalette();
  return runParticles(canvas, (w, h) => {
    const foyers = [
      { x: w * 0.28, y: h * 0.32, delai: 0 },
      { x: w * 0.72, y: h * 0.28, delai: 14 },
      { x: w * 0.5, y: h * 0.52, delai: 28 },
      { x: w * 0.18, y: h * 0.55, delai: 42 },
      { x: w * 0.82, y: h * 0.58, delai: 56 },
    ];
    return foyers.flatMap((f) =>
      Array.from({ length: 34 }, () => {
        const a = Math.random() * Math.PI * 2;
        const v = 1.6 + Math.random() * 3.4;
        const p: any = {
          x: f.x, y: f.y, vx: Math.cos(a) * v, vy: Math.sin(a) * v,
          life: 1, delai: f.delai,
          color: cols[Math.floor(Math.random() * cols.length)], taille: 1.6 + Math.random() * 1.6,
        };
        p.update = (ctx: CanvasRenderingContext2D) => {
          if (p.delai > 0) { p.delai--; return; }
          p.x += p.vx; p.y += p.vy; p.vy += 0.075;
          p.vx *= 0.985; p.vy *= 0.985;
          p.life -= 0.014;
          ctx.save(); ctx.globalAlpha = Math.max(p.life, 0);
          ctx.fillStyle = p.color; ctx.shadowColor = p.color; ctx.shadowBlur = 6;
          ctx.beginPath(); ctx.arc(p.x, p.y, p.taille, 0, Math.PI * 2); ctx.fill(); ctx.restore();
        };
        return p as Particle;
      })
    );
  }, {}, ralentiDepuisDuree(dureeMs));
}

function ondeGravite(canvas: HTMLCanvasElement, dureeMs?: number) {
  // Grille de points déformée par une onde qui se propage — l'espace-temps
  // qui ondule, plutôt que des particules libres.
  const accent = accentColor();
  return runParticles(canvas, (w, h) => {
    const pas = 26;
    const points: Particle[] = [];
    for (let gx = pas / 2; gx < w; gx += pas) {
      for (let gy = pas / 2; gy < h; gy += pas) {
        const dist = Math.hypot(gx - w / 2, gy - h * 0.45);
        const p: any = { bx: gx, by: gy, dist, t: 0, life: 1 };
        p.update = (ctx: CanvasRenderingContext2D) => {
          p.t += 0.09; p.life -= 0.009;
          // Décalage radial : chaque point s'écarte quand l'onde le traverse.
          const front = p.t * 42;
          const delta = Math.exp(-Math.abs(p.dist - front) / 34) * 11;
          const ang = Math.atan2(p.by - h * 0.45, p.bx - w / 2);
          const x = p.bx + Math.cos(ang) * delta;
          const y = p.by + Math.sin(ang) * delta;
          ctx.save();
          ctx.globalAlpha = Math.max(p.life, 0) * (0.25 + Math.min(delta / 11, 1) * 0.75);
          ctx.fillStyle = accent;
          ctx.beginPath(); ctx.arc(x, y, 1.7, 0, Math.PI * 2); ctx.fill(); ctx.restore();
        };
        points.push(p as Particle);
      }
    }
    return points;
  }, {}, ralentiDepuisDuree(dureeMs));
}

function confettisCanon(canvas: HTMLCanvasElement, dureeMs?: number) {
  // Deux jets latéraux en diagonale, comme des canons de scène — l'inverse
  // d'une explosion centrale.
  const cols = themePalette();
  return runParticles(canvas, (w, h) =>
    [0, 1].flatMap((cote) =>
      Array.from({ length: 55 }, () => {
        const gauche = cote === 0;
        const p: any = {
          x: gauche ? -10 : w + 10, y: h * 0.75,
          vx: (gauche ? 1 : -1) * (5 + Math.random() * 4),
          vy: -(5 + Math.random() * 4),
          rot: Math.random() * Math.PI, vr: (Math.random() - 0.5) * 0.4, life: 1,
          color: cols[Math.floor(Math.random() * cols.length)],
          lg: 5 + Math.random() * 5, ht: 3 + Math.random() * 3,
        };
        p.update = (ctx: CanvasRenderingContext2D) => {
          p.x += p.vx; p.y += p.vy; p.vy += 0.16; p.vx *= 0.99; p.rot += p.vr; p.life -= 0.0095;
          ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.rot);
          ctx.globalAlpha = Math.max(p.life, 0); ctx.fillStyle = p.color;
          ctx.fillRect(-p.lg / 2, -p.ht / 2, p.lg, p.ht); ctx.restore();
        };
        return p as Particle;
      })
    )
  , {}, ralentiDepuisDuree(dureeMs));
}

function meteores(canvas: HTMLCanvasElement, dureeMs?: number) {
  // Traînées obliques avec queue — plus long et plus rapide que les étoiles
  // filantes existantes, et toujours dans le même sens (pluie dirigée).
  const accent = accentColor();
  return runParticles(canvas, (w, h) =>
    Array.from({ length: 22 }, () => {
      const p: any = {
        x: Math.random() * w * 1.3 - w * 0.15, y: -20 - Math.random() * 120,
        v: 9 + Math.random() * 7, life: 1, longueur: 30 + Math.random() * 45,
        epaisseur: 1 + Math.random() * 1.8,
      };
      p.update = (ctx: CanvasRenderingContext2D) => {
        // Angle constant (-30°) : une pluie de météores vient d'une direction.
        p.x -= p.v * 0.5; p.y += p.v; p.life -= 0.011;
        const qx = p.x + p.longueur * 0.5;
        const qy = p.y - p.longueur;
        const grad = ctx.createLinearGradient(p.x, p.y, qx, qy);
        grad.addColorStop(0, accent);
        grad.addColorStop(1, "transparent");
        ctx.save(); ctx.globalAlpha = Math.max(p.life, 0);
        ctx.strokeStyle = grad; ctx.lineWidth = p.epaisseur; ctx.lineCap = "round";
        ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(qx, qy); ctx.stroke(); ctx.restore();
      };
      return p as Particle;
    })
  , {}, ralentiDepuisDuree(dureeMs));
}

function bullesIrisees(canvas: HTMLCanvasElement, dureeMs?: number) {
  // Bulles avec reflet et contour irisé — plus riche visuellement que les
  // bulles simples existantes.
  return runParticles(canvas, (w, h) =>
    Array.from({ length: 30 }, () => {
      const p: any = {
        x: w * (0.1 + Math.random() * 0.8), y: h + 20 + Math.random() * 60,
        vy: -(0.9 + Math.random() * 1.5), vx: (Math.random() - 0.5) * 0.7,
        r: 7 + Math.random() * 16, life: 1, phase: Math.random() * Math.PI * 2,
        teinte: Math.random() * 360,
      };
      p.update = (ctx: CanvasRenderingContext2D) => {
        p.phase += 0.05;
        p.x += p.vx + Math.sin(p.phase) * 0.5;
        p.y += p.vy;
        p.life -= 0.007;
        p.teinte = (p.teinte + 1.5) % 360;
        const a = Math.max(p.life, 0);
        ctx.save();
        ctx.globalAlpha = a * 0.55;
        ctx.strokeStyle = `hsl(${p.teinte}, 85%, 70%)`;
        ctx.lineWidth = 1.6;
        ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2); ctx.stroke();
        // Reflet : petit arc clair en haut à gauche, ce qui fait "bulle".
        ctx.globalAlpha = a * 0.75;
        ctx.strokeStyle = "rgba(255,255,255,0.9)";
        ctx.lineWidth = 1.2;
        ctx.beginPath(); ctx.arc(p.x - p.r * 0.3, p.y - p.r * 0.3, p.r * 0.32, Math.PI * 0.9, Math.PI * 1.7); ctx.stroke();
        ctx.restore();
      };
      return p as Particle;
    })
  , {}, ralentiDepuisDuree(dureeMs));
}

function eclairsChaine(canvas: HTMLCanvasElement, dureeMs?: number) {
  // Arcs électriques reliant des noeuds successifs — segments brisés
  // recalculés à chaque frame pour le grésillement.
  const accent = accentColor();
  return runParticles(canvas, (w, h) =>
    Array.from({ length: 7 }, (_, i) => {
      const p: any = {
        x1: w * (0.12 + Math.random() * 0.2), y1: h * (0.2 + Math.random() * 0.6),
        x2: w * (0.68 + Math.random() * 0.2), y2: h * (0.2 + Math.random() * 0.6),
        life: 1, delai: i * 5,
      };
      p.update = (ctx: CanvasRenderingContext2D) => {
        if (p.delai > 0) { p.delai--; return; }
        p.life -= 0.035;
        const segments = 9;
        ctx.save();
        ctx.globalAlpha = Math.max(p.life, 0);
        ctx.strokeStyle = accent;
        ctx.lineWidth = 1.8;
        ctx.shadowColor = accent;
        ctx.shadowBlur = 10;
        ctx.beginPath();
        ctx.moveTo(p.x1, p.y1);
        for (let s = 1; s < segments; s++) {
          const t = s / segments;
          const x = p.x1 + (p.x2 - p.x1) * t + (Math.random() - 0.5) * 22;
          const y = p.y1 + (p.y2 - p.y1) * t + (Math.random() - 0.5) * 22;
          ctx.lineTo(x, y);
        }
        ctx.lineTo(p.x2, p.y2);
        ctx.stroke();
        ctx.restore();
      };
      return p as Particle;
    })
  , {}, ralentiDepuisDuree(dureeMs));
}

export const revealEffects: Record<RevealEffectName, (canvas: HTMLCanvasElement, dureeMs?: number) => Promise<void>> = {
  confettis, feuxArtifice, etincelles, eclairOrage, sakura, ondeChoc,
  etoilesFilantes, bulles, encreDispersee, neige, automne, printemps, vent, pluie,
  arcEnCiel, laser, pixelExplosion, vagueOnde, spirale, coeurs, fumee, eclatsDeVerre,
  supernova, matrice, bulleSavon, poussiereEtoiles, feuilleMorte, aurore, kaleidoscope, impulsion,
  trouNoir, eclatPrisme, nueeInsectes, vortexEncre, grelons, braises,
  feuArtificeMulti, ondeGravite, confettisCanon, meteores, bullesIrisees, eclairsChaine,
};
