// Petits catalogues de démonstration pour peupler rapidement une bibliothèque.
// Les listes complètes incluses dans le projet sont disponibles séparément via
// Importer > Listes fournies (complètes) : src/lib/catalogues-complets.ts.
// Tous ces jeux sont indicatifs ; pas de catalogue mondial exhaustif.

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
