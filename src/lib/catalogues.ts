// Catalogues prédéfinis pour peupler rapidement une bibliothèque. Listes de
// départ volontairement courtes et non exhaustives — l'édition de ces
// catalogues (ajout/suppression par l'utilisateur) reste Phase 7, comme le
// reste des réglages avancés.

export type CatalogueName = "switch1" | "switch2" | "pc";

export const CATALOGUE_LABELS: Record<CatalogueName, string> = {
  switch1: "Switch 1",
  switch2: "Switch 2",
  pc: "PC",
};

export const CATALOGUES: Record<CatalogueName, string[]> = {
  switch1: [
    "The Legend of Zelda: Breath of the Wild",
    "Super Mario Odyssey",
    "Animal Crossing: New Horizons",
    "Metroid Dread",
    "Fire Emblem: Three Houses",
    "Splatoon 2",
  ],
  switch2: [
    "The Legend of Zelda: Tears of the Kingdom",
    "Mario Kart 8 Deluxe",
    "Super Smash Bros. Ultimate",
    "Pikmin 4",
    "Xenoblade Chronicles 3",
    "Splatoon 3",
  ],
  pc: [
    "Hades",
    "Baldur's Gate 3",
    "Celeste",
    "Disco Elysium",
    "Outer Wilds",
    "Slay the Spire",
    "Hollow Knight",
  ],
};
