// Les 6 styles d'animation de tirage — manipulation DOM directe dans un
// conteneur fourni par l'appelant (pas des composants Svelte : ce sont des
// séquences impératives courtes, portées telles quelles depuis la maquette
// validée). Chaque fonction résout une fois la durée écoulée.

export type AnimationStyleName =
  | "roue" | "bandeau" | "des" | "chenillard" | "cartes" | "vague"
  | "radar" | "pendule" | "cascade" | "flip" | "rideau"
  | "typewriter" | "domino" | "spirale" | "pulsation" | "faisceau"
  | "ascenseur" | "machine" | "neon" | "coffre";

export const ANIMATION_STYLE_LABELS: Record<AnimationStyleName, string> = {
  roue: "Roue de roulette", bandeau: "Bandeau défilant", des: "Machine à sous",
  chenillard: "Chenillard lumineux", cartes: "Cartes en cascade", vague: "Vague (égaliseur)",
  radar: "Radar", pendule: "Pendule", cascade: "Cascade de tuiles", flip: "Carte qui se retourne",
  rideau: "Rideau de théâtre", typewriter: "Machine à écrire", domino: "Dominos",
  spirale: "Spirale", pulsation: "Pulsation", faisceau: "Faisceau balayant",
  ascenseur: "Ascenseur", machine: "Machine à jetons", neon: "Enseigne néon", coffre: "Coffre au trésor",
};
// Regroupement par FAMILLE visuelle — une liste de 20 vignettes à plat est
// illisible ; groupées, on trouve d'un coup d'œil "le genre" qu'on cherche.
export const ANIMATION_FAMILLES: { titre: string; styles: AnimationStyleName[] }[] = [
  { titre: "🎰 Hasard & casino", styles: ["roue", "des", "cartes", "machine"] },
  { titre: "📜 Défilement", styles: ["bandeau", "ascenseur", "chenillard", "faisceau"] },
  { titre: "🎬 Mise en scène", styles: ["rideau", "coffre", "flip", "typewriter"] },
  { titre: "🌀 Mouvement", styles: ["spirale", "pendule", "vague", "pulsation"] },
  { titre: "🧩 Objets", styles: ["domino", "cascade", "radar", "neon"] },
];

export const ANIMATION_STYLE_ORDER: AnimationStyleName[] = [
  "roue", "bandeau", "des", "chenillard", "cartes", "vague",
  "radar", "pendule", "cascade", "flip", "rideau",
  "typewriter", "domino", "spirale", "pulsation", "faisceau",
  "ascenseur", "machine", "neon", "coffre",
];

function sleep(ms: number) {
  return new Promise<void>((r) => setTimeout(r, ms));
}
function clear(container: HTMLElement) {
  container.querySelectorAll(".anim-node").forEach((n) => n.remove());
}
function mount(container: HTMLElement, el: HTMLElement) {
  el.classList.add("anim-node");
  container.appendChild(el);
  return el;
}

async function roue(container: HTMLElement, duration: number) {
  const wrap = mount(container, document.createElement("div"));
  wrap.className = "wheel-wrap anim-node";
  wrap.innerHTML = `<div class="wheel-pointer"></div><div class="wheel"></div><div class="wheel-hub">🎲</div>`;
  const wheel = wrap.querySelector(".wheel") as HTMLElement;
  const turns = 4 + Math.random() * 3;
  const finalAngle = turns * 360 + Math.random() * 360;
  wheel.style.transition = `transform ${duration}ms cubic-bezier(.12,.71,.24,1)`;
  await sleep(30);
  wheel.style.transform = `rotate(${finalAngle}deg)`;
  await sleep(duration);
}

async function bandeau(container: HTMLElement, duration: number, winner: string, sample: string[]) {
  const viewport = mount(container, document.createElement("div"));
  viewport.className = "bandeau-viewport anim-node";
  const list = document.createElement("div");
  list.className = "bandeau-list";
  const itemH = 46;
  const noms = [...sample, winner];
  noms.forEach((n) => {
    const it = document.createElement("div");
    it.className = "bandeau-item";
    it.textContent = n;
    list.appendChild(it);
  });
  viewport.appendChild(list);
  list.style.transform = "translateY(0)";
  await sleep(30);
  list.style.transition = `transform ${duration}ms cubic-bezier(.1,.85,.25,1)`;
  list.style.transform = `translateY(-${(noms.length - 1) * itemH}px)`;
  await sleep(duration);
}

async function des(container: HTMLElement, duration: number) {
  const row = mount(container, document.createElement("div"));
  row.className = "des-row anim-node";
  const faces = ["⚀", "⚁", "⚂", "⚃", "⚄", "⚅"];
  const dice = [0, 1, 2].map(() => {
    const d = document.createElement("div");
    d.className = "de";
    d.textContent = "⚀";
    row.appendChild(d);
    return d;
  });
  const stopTimes = [duration * 0.5, duration * 0.75, duration];
  const intervals = dice.map((d) => setInterval(() => (d.textContent = faces[Math.floor(Math.random() * 6)]), 80));
  await Promise.all(
    dice.map((d, i) =>
      sleep(stopTimes[i]).then(() => {
        clearInterval(intervals[i]);
        d.textContent = faces[Math.floor(Math.random() * 6)];
      })
    )
  );
}

async function chenillard(container: HTMLElement, duration: number) {
  const row = mount(container, document.createElement("div"));
  row.className = "chenillard-row anim-node";
  const n = 12;
  const dots = Array.from({ length: n }, () => {
    const d = document.createElement("div");
    d.className = "dot";
    row.appendChild(d);
    return d;
  });
  let pos = 0, elapsed = 0, delay = 45;
  const growth = 1.12;
  while (elapsed < duration) {
    dots.forEach((d, i) => d.classList.toggle("on", i === pos));
    await sleep(delay);
    elapsed += delay;
    pos = (pos + 1) % n;
    delay = Math.min(delay * growth, 260);
  }
  dots.forEach((d, i) => d.classList.toggle("on", i === pos));
}

async function cartes(container: HTMLElement, duration: number, winner: string, sample: string[]) {
  const row = mount(container, document.createElement("div"));
  row.className = "cartes-row anim-node";
  const cards = Array.from({ length: 5 }, () => {
    const c = document.createElement("div");
    c.className = "carte";
    c.textContent = "?";
    row.appendChild(c);
    return c;
  });
  const stopTimes = [0.3, 0.5, 0.68, 0.84, 1].map((f) => f * duration);
  const rand = () => sample[Math.floor(Math.random() * sample.length)];
  const intervals = cards.map((c) => setInterval(() => (c.textContent = rand()), 90));
  await Promise.all(
    cards.map((c, i) =>
      sleep(stopTimes[i]).then(() => {
        clearInterval(intervals[i]);
        c.textContent = i === cards.length - 1 ? winner : rand();
        c.classList.add("stopped");
      })
    )
  );
}

async function vague(container: HTMLElement, duration: number) {
  const row = mount(container, document.createElement("div"));
  row.className = "vague-row anim-node";
  const bars = Array.from({ length: 10 }, () => {
    const b = document.createElement("div");
    b.className = "barre-vague";
    b.style.height = "10px";
    row.appendChild(b);
    return b;
  });
  let elapsed = 0;
  const step = 60;
  while (elapsed < duration) {
    bars.forEach((b) => (b.style.height = 8 + Math.random() * 62 + "px"));
    await sleep(step);
    elapsed += step;
  }
  bars.forEach((b) => (b.style.height = 8 + Math.random() * 62 + "px"));
}

async function radar(container: HTMLElement, duration: number, winner: string, sample: string[]) {
  const scene = mount(container, document.createElement("div"));
  scene.className = "radar-scene anim-node";
  scene.innerHTML = `<div class="radar-sweep"></div><div class="radar-nom">?</div>`;
  const sweep = scene.querySelector(".radar-sweep") as HTMLElement;
  const label = scene.querySelector(".radar-nom") as HTMLElement;
  const noms = [...sample, winner];
  let elapsed = 0, delay = 90;
  const growth = 1.14;
  let i = 0;
  while (elapsed < duration) {
    label.textContent = noms[i % noms.length];
    i++;
    sweep.style.transition = `transform ${delay}ms linear`;
    sweep.style.transform = `rotate(${i * 137}deg)`;
    await sleep(delay);
    elapsed += delay;
    delay = Math.min(delay * growth, 420);
  }
  label.textContent = winner;
}

async function pendule(container: HTMLElement, duration: number, winner: string, sample: string[]) {
  const scene = mount(container, document.createElement("div"));
  scene.className = "pendule-scene anim-node";
  scene.innerHTML = `<div class="pendule-tige"></div><div class="pendule-nom">?</div>`;
  const tige = scene.querySelector(".pendule-tige") as HTMLElement;
  const label = scene.querySelector(".pendule-nom") as HTMLElement;
  const noms = [...sample, winner];
  const oscillations = 7;
  for (let i = 0; i < oscillations; i++) {
    const amplitude = 55 * (1 - i / oscillations);
    const angle = i % 2 === 0 ? amplitude : -amplitude;
    const pas = duration / oscillations;
    label.textContent = noms[i % noms.length];
    tige.style.transition = `transform ${pas}ms ease-in-out`;
    tige.style.transform = `rotate(${angle}deg)`;
    await sleep(pas);
  }
  tige.style.transition = "transform 300ms ease-out";
  tige.style.transform = "rotate(0deg)";
  label.textContent = winner;
  await sleep(300);
}

async function cascade(container: HTMLElement, duration: number, winner: string, sample: string[]) {
  const row = mount(container, document.createElement("div"));
  row.className = "cascade-row anim-node";
  const noms = [...sample.slice(0, 3), winner];
  const pas = duration / noms.length;
  for (const nom of noms) {
    const tuile = document.createElement("div");
    tuile.className = "tuile-cascade";
    tuile.textContent = nom;
    row.appendChild(tuile);
    await sleep(20);
    tuile.classList.add("posee");
    await sleep(pas - 20);
  }
  row.querySelectorAll(".tuile-cascade").forEach((t, i, all) => {
    t.classList.toggle("gagnante", i === all.length - 1);
  });
}

async function flip(container: HTMLElement, duration: number, winner: string, sample: string[]) {
  const scene = mount(container, document.createElement("div"));
  scene.className = "flip-scene anim-node";
  scene.innerHTML = `<div class="flip-carte"><span class="flip-texte">?</span></div>`;
  const carte = scene.querySelector(".flip-carte") as HTMLElement;
  const texte = scene.querySelector(".flip-texte") as HTMLElement;
  const noms = [...sample, winner];
  let elapsed = 0, delay = 100;
  const growth = 1.16;
  let i = 0;
  let face = false;
  while (elapsed < duration) {
    face = !face;
    carte.style.transition = `transform ${delay}ms ease-in-out`;
    carte.style.transform = `rotateY(${face ? 180 : 360}deg)`;
    await sleep(delay / 2);
    texte.textContent = noms[i % noms.length];
    i++;
    await sleep(delay / 2);
    elapsed += delay;
    delay = Math.min(delay * growth, 380);
  }
  texte.textContent = winner;
  carte.style.transform = "rotateY(360deg)";
}

async function rideau(container: HTMLElement, duration: number, winner: string) {
  const scene = mount(container, document.createElement("div"));
  scene.className = "rideau-scene anim-node";
  scene.innerHTML = `
    <div class="rideau-nom">${winner}</div>
    <div class="rideau-panneau rideau-gauche"></div>
    <div class="rideau-panneau rideau-droite"></div>
  `;
  const gauche = scene.querySelector(".rideau-gauche") as HTMLElement;
  const droite = scene.querySelector(".rideau-droite") as HTMLElement;
  const suspense = Math.max(duration - 500, 200);
  await sleep(suspense);
  gauche.style.transition = droite.style.transition = "transform 500ms cubic-bezier(.4,0,.2,1)";
  gauche.style.transform = "translateX(-100%)";
  droite.style.transform = "translateX(100%)";
  await sleep(500);
}

async function typewriter(container: HTMLElement, duration: number, winner: string, sample: string[]) {
  const scene = mount(container, document.createElement("div"));
  scene.className = "typewriter-scene anim-node";
  scene.innerHTML = `<span class="typewriter-texte"></span><span class="typewriter-curseur">|</span>`;
  const texte = scene.querySelector(".typewriter-texte") as HTMLElement;
  const noms = [...sample.slice(0, 3), winner];
  const pasParNom = duration / noms.length;
  for (let n = 0; n < noms.length; n++) {
    const nom = noms[n];
    const estGagnant = n === noms.length - 1;
    const tempsFrappe = pasParNom * 0.6;
    const delaiParLettre = tempsFrappe / Math.max(nom.length, 1);
    texte.textContent = "";
    for (const lettre of nom) {
      texte.textContent += lettre;
      await sleep(delaiParLettre);
    }
    if (!estGagnant) {
      await sleep(pasParNom * 0.15);
      const tempsEffacement = pasParNom * 0.25;
      const delaiEffacement = tempsEffacement / Math.max(nom.length, 1);
      while (texte.textContent && texte.textContent.length > 0) {
        texte.textContent = texte.textContent.slice(0, -1);
        await sleep(delaiEffacement);
      }
    }
  }
}

async function domino(container: HTMLElement, duration: number, winner: string, sample: string[]) {
  const row = mount(container, document.createElement("div"));
  row.className = "domino-row anim-node";
  const noms = [...sample.slice(0, 4), winner];
  const tuiles = noms.map((nom, i) => {
    const t = document.createElement("div");
    t.className = "domino-tuile";
    t.textContent = nom;
    if (i === noms.length - 1) t.classList.add("gagnante");
    row.appendChild(t);
    return t;
  });
  const pas = duration / tuiles.length;
  for (const t of tuiles) {
    t.classList.add("tombe");
    await sleep(pas);
  }
}

async function spirale(container: HTMLElement, duration: number, winner: string, sample: string[]) {
  const scene = mount(container, document.createElement("div"));
  scene.className = "spirale-scene anim-node";
  const noms = [...sample.slice(0, 5), winner];
  const items = noms.map((nom, i) => {
    const el = document.createElement("div");
    el.className = "spirale-item";
    el.textContent = nom;
    const angle = (i / noms.length) * Math.PI * 2;
    const rayon = 80;
    el.style.transform = `translate(${Math.cos(angle) * rayon}px, ${Math.sin(angle) * rayon}px) scale(1)`;
    scene.appendChild(el);
    return el;
  });
  await sleep(30);
  const pas = duration / items.length;
  for (let i = 0; i < items.length; i++) {
    items.forEach((el, j) => {
      const estGagnant = j === items.length - 1;
      const converge = i >= j;
      el.style.transition = `transform ${pas}ms ease-in, opacity ${pas}ms ease-in`;
      if (converge && !estGagnant) {
        el.style.opacity = "0";
        el.style.transform += " scale(0.2)";
      } else if (estGagnant && i === items.length - 1) {
        el.style.transform = "translate(0, 0) scale(1.3)";
      }
    });
    await sleep(pas);
  }
}

async function pulsation(container: HTMLElement, duration: number, winner: string, sample: string[]) {
  const scene = mount(container, document.createElement("div"));
  scene.className = "pulsation-scene anim-node";
  scene.innerHTML = `<div class="pulsation-cercle"><span class="pulsation-nom">?</span></div>`;
  const cercle = scene.querySelector(".pulsation-cercle") as HTMLElement;
  const label = scene.querySelector(".pulsation-nom") as HTMLElement;
  const noms = [...sample, winner];
  let elapsed = 0, delay = 140;
  const growth = 1.15;
  let i = 0;
  while (elapsed < duration) {
    label.textContent = noms[i % noms.length];
    i++;
    cercle.style.transition = `transform ${delay * 0.5}ms ease-out`;
    cercle.style.transform = "scale(1.18)";
    await sleep(delay * 0.5);
    cercle.style.transform = "scale(1)";
    await sleep(delay * 0.5);
    elapsed += delay;
    delay = Math.min(delay * growth, 460);
  }
  label.textContent = winner;
  cercle.style.transform = "scale(1.25)";
}

async function faisceau(container: HTMLElement, duration: number, winner: string, sample: string[]) {
  const row = mount(container, document.createElement("div"));
  row.className = "faisceau-row anim-node";
  const noms = [...sample.slice(0, 4), winner];
  const items = noms.map((nom) => {
    const el = document.createElement("div");
    el.className = "faisceau-item";
    el.textContent = nom;
    row.appendChild(el);
    return el;
  });
  let elapsed = 0, delay = 110, pos = 0;
  const growth = 1.16;
  while (elapsed < duration) {
    items.forEach((el, i) => el.classList.toggle("eclaire", i === pos));
    await sleep(delay);
    elapsed += delay;
    pos = (pos + 1) % items.length;
    delay = Math.min(delay * growth, 300);
  }
  items.forEach((el, i) => el.classList.toggle("eclaire", i === items.length - 1));
}


async function ascenseur(container: HTMLElement, duration: number, winner: string, sample: string[]) {
  // Défilement vertical continu qui décélère, façon compteur mécanique.
  const scene = mount(container, document.createElement("div"));
  scene.className = "ascenseur-scene anim-node";
  const piste = document.createElement("div");
  piste.className = "ascenseur-piste";
  scene.appendChild(piste);

  const noms = [...sample, winner];
  // Assez d'éléments pour que le défilement paraisse continu.
  const suite = [...noms, ...noms, ...noms, winner];
  for (const n of suite) {
    const el = document.createElement("div");
    el.className = "ascenseur-item";
    el.textContent = n;
    piste.appendChild(el);
  }

  const hauteurItem = 34;
  const cible = (suite.length - 1) * hauteurItem;
  piste.style.transition = `transform ${duration}ms cubic-bezier(.16,.9,.3,1)`;
  await sleep(20);
  piste.style.transform = `translateY(-${cible}px)`;
  await sleep(duration);
}

async function machine(container: HTMLElement, duration: number, winner: string, sample: string[]) {
  // Jetons qui tombent dans une fente, le dernier est le gagnant.
  const scene = mount(container, document.createElement("div"));
  scene.className = "machine-scene anim-node";
  scene.innerHTML = `<div class="machine-fente"><span class="machine-nom">?</span></div>`;
  const fente = scene.querySelector(".machine-fente") as HTMLElement;
  const label = scene.querySelector(".machine-nom") as HTMLElement;

  const noms = [...sample, winner];
  let elapsed = 0, delay = 95;
  let i = 0;
  while (elapsed < duration) {
    label.textContent = noms[i % noms.length];
    i++;
    fente.style.transition = "none";
    fente.style.transform = "translateY(-16px)";
    await sleep(16);
    fente.style.transition = `transform ${delay * 0.7}ms cubic-bezier(.3,1.5,.5,1)`;
    fente.style.transform = "translateY(0)";
    await sleep(delay);
    elapsed += delay;
    delay = Math.min(delay * 1.15, 400);
  }
  label.textContent = winner;
}

async function neon(container: HTMLElement, duration: number, winner: string) {
  // Lettres qui s'allument une à une, avec grésillement final.
  const scene = mount(container, document.createElement("div"));
  scene.className = "neon-scene anim-node";
  const lettres = [...winner].map((ch) => {
    const el = document.createElement("span");
    el.className = "neon-lettre";
    el.textContent = ch === " " ? "\u00a0" : ch;
    scene.appendChild(el);
    return el;
  });

  // 70% du temps pour allumer, 30% pour le grésillement — sans ça, un nom
  // long allumerait ses lettres trop lentement pour rester lisible.
  const tempsAllumage = duration * 0.7;
  const pas = tempsAllumage / Math.max(lettres.length, 1);
  for (const el of lettres) {
    el.classList.add("allumee");
    await sleep(pas);
  }
  const finGrésillement = Date.now() + duration * 0.3;
  while (Date.now() < finGrésillement) {
    const el = lettres[Math.floor(Math.random() * lettres.length)];
    el.classList.remove("allumee");
    await sleep(45);
    el.classList.add("allumee");
    await sleep(70);
  }
}

async function coffre(container: HTMLElement, duration: number, winner: string) {
  // Coffre qui tremble puis s'ouvre sur le résultat.
  const scene = mount(container, document.createElement("div"));
  scene.className = "coffre-scene anim-node";
  scene.innerHTML = `
    <div class="coffre-couvercle">🎁</div>
    <div class="coffre-nom">${winner}</div>
  `;
  const couvercle = scene.querySelector(".coffre-couvercle") as HTMLElement;
  const nom = scene.querySelector(".coffre-nom") as HTMLElement;

  const suspense = Math.max(duration - 450, 250);
  couvercle.classList.add("tremble");
  await sleep(suspense);
  couvercle.classList.remove("tremble");
  couvercle.classList.add("ouvert");
  nom.classList.add("visible");
  await sleep(450);
}

export interface PlayAnimationArgs {
  container: HTMLElement;
  duration: number;
  winner: string;
  /** Noms au hasard pour habiller bandeau/cartes (déjà fourni par sampleNames()). */
  sample: string[];
}

export const drawAnimations: Record<AnimationStyleName, (args: PlayAnimationArgs) => Promise<void>> = {
  roue: ({ container, duration }) => roue(container, duration),
  bandeau: ({ container, duration, winner, sample }) => bandeau(container, duration, winner, sample),
  des: ({ container, duration }) => des(container, duration),
  chenillard: ({ container, duration }) => chenillard(container, duration),
  cartes: ({ container, duration, winner, sample }) => cartes(container, duration, winner, sample),
  vague: ({ container, duration }) => vague(container, duration),
  radar: ({ container, duration, winner, sample }) => radar(container, duration, winner, sample),
  pendule: ({ container, duration, winner, sample }) => pendule(container, duration, winner, sample),
  cascade: ({ container, duration, winner, sample }) => cascade(container, duration, winner, sample),
  flip: ({ container, duration, winner, sample }) => flip(container, duration, winner, sample),
  rideau: ({ container, duration, winner }) => rideau(container, duration, winner),
  typewriter: ({ container, duration, winner, sample }) => typewriter(container, duration, winner, sample),
  domino: ({ container, duration, winner, sample }) => domino(container, duration, winner, sample),
  spirale: ({ container, duration, winner, sample }) => spirale(container, duration, winner, sample),
  pulsation: ({ container, duration, winner, sample }) => pulsation(container, duration, winner, sample),
  faisceau: ({ container, duration, winner, sample }) => faisceau(container, duration, winner, sample),
  ascenseur: ({ container, duration, winner, sample }) => ascenseur(container, duration, winner, sample),
  machine: ({ container, duration, winner, sample }) => machine(container, duration, winner, sample),
  neon: ({ container, duration, winner }) => neon(container, duration, winner),
  coffre: ({ container, duration, winner }) => coffre(container, duration, winner),
};

/** Retire tous les nœuds DOM injectés par une animation (à appeler avant
 * d'en rejouer une autre, et après la fin de celle en cours). */
export function clearAnimationNodes(container: HTMLElement) {
  clear(container);
}
