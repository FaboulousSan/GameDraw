import { Star, Sword, Heart, Trophy, Gem, Skull } from "@lucide/svelte";
import type { IconeNotation } from "./types";
import type { Component } from "svelte";

export const ICONE_NOTATION_LABELS: Record<IconeNotation, string> = {
  etoile: "Étoile",
  epee: "Épée",
  coeur: "Cœur",
  trophee: "Trophée",
  diamant: "Diamant",
  crane: "Crâne",
};

export const ICONE_NOTATION_ORDER: IconeNotation[] = ["etoile", "epee", "coeur", "trophee", "diamant", "crane"];

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const ICONE_NOTATION_COMPOSANTS: Record<IconeNotation, Component<any>> = {
  etoile: Star,
  epee: Sword,
  coeur: Heart,
  trophee: Trophy,
  diamant: Gem,
  crane: Skull,
};
