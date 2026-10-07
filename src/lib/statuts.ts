import type { StatutDefinition } from "./types";

// CRUD sur la liste de statuts (config.statuts) — même esprit que
// library.ts : fonctions pures, non-mutantes, testables sans Tauri.
// Global à toute l'app (pas par plateforme) : un statut a du sens partout.

function nouvelId(): string {
  return crypto.randomUUID();
}

/** Ajoute un statut personnalisé (jamais "intégré" — seuls les 5 statuts
 * d'origine le sont, et ils ne peuvent être créés qu'au tout début). */
export function ajouterStatut(statuts: StatutDefinition[], label: string, couleur: string): StatutDefinition[] {
  const propre = label.trim();
  if (!propre) return statuts;
  const nouveau: StatutDefinition = { id: nouvelId(), label: propre, couleur, integre: false, visible: true };
  return [...statuts, nouveau];
}

/** Refuse de supprimer un statut intégré (les 5 d'origine) — retourne la
 * liste inchangée dans ce cas plutôt que de lever une erreur, pour rester
 * simple à utiliser depuis l'UI (bouton déjà désactivé côté affichage). */
export function supprimerStatut(statuts: StatutDefinition[], id: string): StatutDefinition[] {
  const cible = statuts.find((s) => s.id === id);
  if (!cible || cible.integre) return statuts;
  return statuts.filter((s) => s.id !== id);
}

/** Masquer un statut ne le supprime pas : les jeux qui le référencent déjà
 * gardent leur statut intact, seul le sélecteur (Fiche, filtres) ne le
 * propose plus par défaut. */
export function basculerVisibiliteStatut(statuts: StatutDefinition[], id: string): StatutDefinition[] {
  return statuts.map((s) => (s.id === id ? { ...s, visible: !s.visible } : s));
}

export function modifierCouleurStatut(statuts: StatutDefinition[], id: string, couleur: string): StatutDefinition[] {
  return statuts.map((s) => (s.id === id ? { ...s, couleur } : s));
}

/** Trouve la définition d'un statut par id, avec un repli neutre si le
 * statut a été supprimé depuis (jeu orphelin) — n'affiche jamais un
 * libellé/couleur cassé, juste l'id brut en libellé. */
export function trouverStatut(statuts: StatutDefinition[], id: string): StatutDefinition {
  return statuts.find((s) => s.id === id) ?? { id, label: id, couleur: "var(--muted)", integre: false, visible: false };
}
