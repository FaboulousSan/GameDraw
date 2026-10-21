// Type partagé du menu contextuel — dans un module .ts séparé plutôt que
// dans le composant : un `export interface` déclaré dans un <script> Svelte
// n'est pas importable depuis un autre fichier.
export interface ActionMenu {
  label: string;
  /** Nom de section quand un groupe de commandes débute. */
  groupe?: string;
  /** Vérifié dans le menu (ex. statut actif). */
  actif?: boolean;
  /** Composant d'icône Lucide, optionnel. */
  icone?: any;
  action: () => void;
  /** Style d'alerte (rouge) pour les actions destructrices. */
  danger?: boolean;
  /** Affiche un séparateur AVANT cette entrée. */
  separateurAvant?: boolean;
}
