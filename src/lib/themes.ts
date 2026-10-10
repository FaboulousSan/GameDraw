import type { ThemeName } from "./types";

// Jetons de couleur repris tel quels du script PowerShell ($themes, lignes
// ~667-746 de Tirage-Jeux.ps1) pour garantir une parité visuelle exacte.
export interface ThemeTokens {
  accent: string;
  success: string;
  bg: string;
  card: string;
  input: string;
  border: string;
  darkbg: string;
  muted: string;
  danger: string;
  warning: string;
  text: string;
  glow: string;
}

export const THEME_LABELS: Record<ThemeName, string> = {
  catppuccin: "Catppuccin",
  ocarina: "Ocarina of Time",
  cyberpunk: "Cyberpunk",
  foret: "Forêt",
  dracula: "Dracula",
  witcher: "The Witcher",
  pipboy: "Pip-Boy",
  mario: "Super Mario",
  luigi: "Luigi",
  dragon: "Dragon",
  clair: "Blanc Premium",
  sombrePremium: "Sombre Premium",
  hiver: "Hiver",
  firefox: "Firefox",
  majora: "Majora",
  hollowKnight: "Hollow Knight",
  sakura: "Sakura",
  vaporwave: "Vaporwave",
  sang: "Sang & Or",
  abysse: "Abysse",
  emeraude: "Émeraude",
  monochrome: "Monochrome",
  cafe: "Café",
  neon: "Néon",
};

// Ordre d'affichage dans le sélecteur de thème (identique à $script:themeOrder)
export const THEME_ORDER: ThemeName[] = [
  "catppuccin",
  "ocarina",
  "cyberpunk",
  "foret",
  "dracula",
  "witcher",
  "pipboy",
  "mario",
  "luigi",
  "dragon",
  "clair",
  "sombrePremium",
  "hiver",
  "firefox",
  "majora",
  "hollowKnight",
  "sakura",
  "vaporwave",
  "sang",
  "abysse",
  "emeraude",
  "monochrome",
  "cafe",
  "neon",
];

export const THEMES: Record<ThemeName, ThemeTokens> = {
  catppuccin: {
    accent: "#89B4FA", success: "#A6E3A1", bg: "#181825", card: "#3E3E4B",
    input: "#313244", border: "#5F6171", darkbg: "#11111B", muted: "#BAC2DE",
    danger: "#F38BA8", warning: "#F9E2AF", text: "#FFFFFF", glow: "#89B4FA",
  },
  ocarina: {
    accent: "#D4AF37", success: "#4C8C4A", bg: "#1B1710", card: "#443E34",
    input: "#3A2F1D", border: "#706044", darkbg: "#100D08", muted: "#C9B896",
    danger: "#D15151", warning: "#5FA8D3", text: "#FFFFFF", glow: "#D4AF37",
  },
  cyberpunk: {
    accent: "#FCEE0A", success: "#00E5A0", bg: "#0D0D0D", card: "#383838",
    input: "#262626", border: "#5B5B5B", darkbg: "#000000", muted: "#9E9E9E",
    danger: "#FF003C", warning: "#FCEE0A", text: "#FFFFFF", glow: "#FCEE0A",
  },
  // Vert mousse/olive (pas le vert franc de Luigi) — sous-bois, feuilles
  // mortes, lumière tamisée. Fond très saturé en vert profond pour bien
  // se distinguer du bleu nuit de Luigi.
  foret: {
    accent: "#8FA84A", success: "#B8C97A", bg: "#0F1F14", card: "#2A3B28",
    input: "#1C2B1A", border: "#41573A", darkbg: "#0A150E", muted: "#B8C9A8",
    danger: "#C1583D", warning: "#D9A544", text: "#FFFFFF", glow: "#8FA84A",
  },
  dracula: {
    accent: "#BD93F9", success: "#50FA7B", bg: "#282A36", card: "#4A4D5A",
    input: "#3B3F51", border: "#6F7180", darkbg: "#191A21", muted: "#F8F8F2",
    danger: "#FF5555", warning: "#F1FA8C", text: "#FFFFFF", glow: "#BD93F9",
  },
  witcher: {
    accent: "#A9B4BC", success: "#5A8448", bg: "#15120F", card: "#3E3A37",
    input: "#2C2520", border: "#655D56", darkbg: "#0C0A08", muted: "#A79C8C",
    danger: "#DF3939", warning: "#B08D57", text: "#FFFFFF", glow: "#A9B4BC",
  },
  pipboy: {
    accent: "#41FF00", success: "#7CFF3D", bg: "#0A0F0A", card: "#323C32",
    input: "#16260F", border: "#4B633E", darkbg: "#050805", muted: "#8FCB6B",
    danger: "#FF3B30", warning: "#FFD500", text: "#FFFFFF", glow: "#41FF00",
  },
  mario: {
    accent: "#F13A37", success: "#43B047", bg: "#0F2A66", card: "#304D90",
    input: "#25499C", border: "#4C71C5", darkbg: "#081736", muted: "#CFE0FF",
    danger: "#F26522", warning: "#FBD000", text: "#FFFFFF", glow: "#F13A37",
  },
  // Le duo naturel de Mario : vert au premier plan (casquette/salopette
  // inversée), bleu nuit en fond (ses salopettes) — même famille que Mario
  // mais rôles de couleurs inversés pour bien les distinguer au survol du
  // sélecteur de thème.
  luigi: {
    accent: "#3DA35D", success: "#7CC576", bg: "#0A1F30", card: "#163350",
    input: "#102943", border: "#2C5578", darkbg: "#071420", muted: "#C9E4D3",
    danger: "#E5484D", warning: "#F4C430", text: "#FFFFFF", glow: "#3DA35D",
  },
  // Braise/cendre — rouge de feu profond (pas l'orange franc de Firefox),
  // fond noir légèrement roussi, teintes de cendre plutôt que de flamme vive.
  dragon: {
    accent: "#E8452A", success: "#8A6D5A", bg: "#1C0F0C", card: "#4A3530",
    input: "#382320", border: "#7D5A4D", darkbg: "#100807", muted: "#C9A088",
    danger: "#C4331F", warning: "#E8901F", text: "#FFFFFF", glow: "#E8452A",
  },
  // DARKBG sert ici de couleur de texte SUR fond ACCENT (indigo assez
  // saturé pour justifier du blanc), pas de fond sombre — cf. commentaire
  // original du script pour ce thème clair.
  clair: {
    accent: "#6366F1", success: "#22C55E", bg: "#FFFFFF", card: "#F8FAFC",
    input: "#F1F5F9", border: "#E5E7EB", darkbg: "#FFFFFF", muted: "#64748B",
    danger: "#B91365", warning: "#F59E0B", text: "#0F172A", glow: "#6366F1",
  },
  sombrePremium: {
    accent: "#818CF8", success: "#4ADE80", bg: "#09090B", card: "#18181B",
    input: "#101012", border: "#27272A", darkbg: "#0A0A0F", muted: "#A1A1AA",
    danger: "#F472B6", warning: "#FBBF24", text: "#F4F4F5", glow: "#818CF8",
  },
  // Palette glacée — nuit d'hiver enneigée, bleu givré au premier plan,
  // touches d'or chaud (guirlandes lumineuses) pour le warning.
  hiver: {
    accent: "#8ECFEB", success: "#6EE7B7", bg: "#0B1622", card: "#1B2A38",
    input: "#14212C", border: "#2C4356", darkbg: "#060D14", muted: "#9FB8C9",
    danger: "#E1544C", warning: "#F5C451", text: "#FFFFFF", glow: "#8ECFEB",
  },
  // Orange ardent du renard/logo, sur un thème sombre dans l'esprit du
  // mode nuit du navigateur.
  firefox: {
    accent: "#FF7139", success: "#6BC46D", bg: "#1A1A1F", card: "#2B2A33",
    input: "#23222B", border: "#52525E", darkbg: "#0C0C0F", muted: "#B0AFB7",
    danger: "#FF4F5E", warning: "#FFBD4F", text: "#FFFFFF", glow: "#FF7139",
  },
  // Majora's Mask — lune qui tombe, ambiance inquiétante : violet
  // spectral au premier plan, nuit profonde en fond, rouge sang de lune.
  majora: {
    accent: "#8B5FBF", success: "#4FBF8B", bg: "#150E1F", card: "#2B1F3D",
    input: "#1F1530", border: "#4A3560", darkbg: "#0A0714", muted: "#B6A3D1",
    danger: "#D1425A", warning: "#E8B04F", text: "#FFFFFF", glow: "#8B5FBF",
  },
  // Hollow Knight — le vide (Void) en fond, cyan pâle spectral (essence
  // d'âme) au premier plan, touche d'ambre pour le warning (fanal/lanterne).
  // Hollow Knight — carapace blanc-os pâle et désaturée (pas le cyan vif
  // d'Hiver), fond "Vide" sarcelle-noir (verdâtre, pas bleu pur) pour bien
  // se distinguer. Ambre pour le warning (fanal/lumafly).
  hollowKnight: {
    accent: "#D8D3C4", success: "#5FA88C", bg: "#0A1210", card: "#1C2622",
    input: "#111A17", border: "#324841", darkbg: "#050908", muted: "#8FA39D",
    danger: "#C1443A", warning: "#D4A24A", text: "#FFFFFF", glow: "#D8D3C4",
  },
  // --- Nouveaux thèmes : créneaux de teinte volontairement laissés libres
  // par les 16 précédents (rose/magenta 300-350°, turquoise 165-185°,
  // gris neutre pur, brun chaud) — vérifié par analyse HSL avant écriture.
  sakura: {
    accent: "#F2A0C0", success: "#8FCFA8", bg: "#1A1016", card: "#2E1F28",
    input: "#241620", border: "#4A3340", darkbg: "#120A0F", muted: "#C9A8B8",
    danger: "#E8607F", warning: "#EFC06A", text: "#FFFFFF", glow: "#F2A0C0",
  },
  vaporwave: {
    accent: "#FF6EC7", success: "#6EE7E7", bg: "#160D2E", card: "#2A1C4A",
    input: "#1E1338", border: "#4A3578", darkbg: "#0D0720", muted: "#B9A0E0",
    danger: "#FF4D6D", warning: "#FFD166", text: "#FFFFFF", glow: "#FF6EC7",
  },
  sang: {
    accent: "#8B1A3D", success: "#D4AF37", bg: "#12060B", card: "#2B1420",
    input: "#1C0A12", border: "#4A1E33", darkbg: "#080304", muted: "#C9A0AE",
    danger: "#E03E5C", warning: "#D4AF37", text: "#FFFFFF", glow: "#8B1A3D",
  },
  abysse: {
    accent: "#2DD4BF", success: "#4ADE80", bg: "#04121A", card: "#0F2730",
    input: "#081C25", border: "#1C4049", darkbg: "#020B10", muted: "#7FA8B0",
    danger: "#E85D75", warning: "#E8B04F", text: "#FFFFFF", glow: "#2DD4BF",
  },
  emeraude: {
    accent: "#10B981", success: "#6EE7B7", bg: "#07160F", card: "#122E20",
    input: "#0C2117", border: "#1F4A34", darkbg: "#030D08", muted: "#8FBCA5",
    danger: "#DC5C4F", warning: "#DFAE52", text: "#FFFFFF", glow: "#10B981",
  },
  monochrome: {
    accent: "#E4E4E7", success: "#A1A1AA", bg: "#0A0A0B", card: "#1F1F23",
    input: "#161618", border: "#3A3A40", darkbg: "#050506", muted: "#8A8A93",
    danger: "#D4D4D8", warning: "#B4B4BB", text: "#FFFFFF", glow: "#E4E4E7",
  },
  cafe: {
    accent: "#C89F73", success: "#94B58A", bg: "#171008", card: "#2E2418",
    input: "#211910", border: "#4A3B28", darkbg: "#0D0904", muted: "#BFA98E",
    danger: "#C4614A", warning: "#D9A441", text: "#FFFFFF", glow: "#C89F73",
  },
  neon: {
    accent: "#B026FF", success: "#39FF14", bg: "#0A0014", card: "#1E0A2E",
    input: "#150520", border: "#3D1660", darkbg: "#05000A", muted: "#A87FC4",
    danger: "#FF2D95", warning: "#FFE03D", text: "#FFFFFF", glow: "#B026FF",
  },
};

/** Applique un thème comme custom properties CSS sur :root. */
export function applyTheme(name: ThemeName): void {
  const t = THEMES[name] ?? THEMES.catppuccin;
  const root = document.documentElement.style;
  root.setProperty("--accent", t.accent);
  root.setProperty("--success", t.success);
  root.setProperty("--bg", t.bg);
  root.setProperty("--card", t.card);
  root.setProperty("--input", t.input);
  root.setProperty("--border", t.border);
  root.setProperty("--darkbg", t.darkbg);
  root.setProperty("--muted", t.muted);
  root.setProperty("--danger", t.danger);
  root.setProperty("--warning", t.warning);
  root.setProperty("--text", t.text);
  root.setProperty("--glow", t.glow);
}

/**
 * Contraste automatique texte clair/sombre selon la luminance relative
 * d'une couleur de fond — reprend le seuil ~0.55 utilisé côté PowerShell
 * pour les badges de statut à couleur libre.
 */
export function contrastText(hexBg: string): "#000000" | "#FFFFFF" {
  const hex = hexBg.replace("#", "");
  const r = parseInt(hex.substring(0, 2), 16) / 255;
  const g = parseInt(hex.substring(2, 4), 16) / 255;
  const b = parseInt(hex.substring(4, 6), 16) / 255;
  const lin = (c: number) => (c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4));
  const luminance = 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);
  return luminance > 0.55 ? "#000000" : "#FFFFFF";
}
