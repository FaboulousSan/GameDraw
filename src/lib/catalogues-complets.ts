/** Listes de découverte EMBARQUÉES dans le build Vite (y compris .exe/MSI/NSIS).
 * Même contenu que docs/examples/listes-jeux, sans accès au disque de sources.
 * Il ne s'agit PAS du catalogue mondial exhaustif des jeux vidéo.
 */
import pcCsv from "../../docs/examples/listes-jeux/jeux-pc.csv?raw";
import switch1Csv from "../../docs/examples/listes-jeux/jeux-switch-1.csv?raw";
import switch2Csv from "../../docs/examples/listes-jeux/jeux-switch-2.csv?raw";
import switchTousCsv from "../../docs/examples/listes-jeux/jeux-switch-1-et-2.csv?raw";
import { parseCsv, type LigneImport } from "./library";

export type PackInclusId = "pc" | "switch1" | "switch2" | "switchTous" | "tous";
export type PackPlateforme = "pc" | "switch";
export interface PackInclus {
  id: Exclude<PackInclusId, "tous">;
  titre: string;
  plateforme: PackPlateforme;
  lignes: LigneImport[];
}

export const PACKS_INCLUS: readonly PackInclus[] = [
  { id: "pc", titre: "PC", plateforme: "pc", lignes: parseCsv(pcCsv) },
  { id: "switch1", titre: "Nintendo Switch 1", plateforme: "switch", lignes: parseCsv(switch1Csv) },
  { id: "switch2", titre: "Nintendo Switch 2", plateforme: "switch", lignes: parseCsv(switch2Csv) },
  { id: "switchTous", titre: "Nintendo Switch 1 + 2", plateforme: "switch", lignes: parseCsv(switchTousCsv) },
];

/** Ne jamais importer les 3 variantes Switch ensemble : le pack combiné est
 * déjà l'union Switch 1+2. Ne jamais ajouter dans la mauvaise plateforme. */
export function packsAImporter(id: PackInclusId): readonly PackInclus[] {
  if (id === "tous") return [PACKS_INCLUS[0], PACKS_INCLUS[3]];
  return PACKS_INCLUS.filter((pack) => pack.id === id);
}

export function nombreDansPack(id: PackInclusId): number {
  return packsAImporter(id).reduce((total, pack) => total + pack.lignes.length, 0);
}
