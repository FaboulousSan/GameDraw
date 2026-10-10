import { writable } from "svelte/store";

export type LangueApp = "fr" | "en";

/**
 * Langue active de l'interface. La valeur persistante reste dans config.json ;
 * ce store ne sert qu'à la diffuser aux composants sans prop drilling.
 */
export const langueApp = writable<LangueApp>("fr");

/** Transforme une locale système/WebView2 vers une langue réellement prise en charge.
 * Toutes les variantes françaises (fr, fr-FR, fr-CA...) donnent `fr`;
 * toute autre locale tombe sur l'anglais, seule autre langue disponible. */
export function langueDepuisLocale(locale: string | null | undefined): LangueApp {
  return (locale ?? "").trim().toLowerCase().startsWith("fr") ? "fr" : "en";
}

export function tr(langue: LangueApp, francais: string, anglais: string): string {
  return langue === "en" ? anglais : francais;
}

const STATUTS_EN: Record<string, string> = {
  NonCommence: "Not started",
  EnCours: "In progress",
  EnPause: "Paused",
  Termine: "Completed",
  Abandonne: "Abandoned",
};

export function labelStatut(langue: LangueApp, id: string, labelOriginal: string, integre = false): string {
  if (langue === "en" && integre) return STATUTS_EN[id] ?? labelOriginal;
  return labelOriginal;
}
