## GameDraw 1.0.7 — STAB-C6-HF2 (release / EXE)

- Correction des huit erreurs bloquantes de `npm run check` remontées par DEV-HUB (`CodeRetour=40`) lors de `--devhub-release`.
- Test de jaquettes déplacé vers `cover-layout.test.mjs` : même suite Vitest, hors typage applicatif Svelte, sans nouvelle dépendance npm.
- Types explicites `migrate<AppConfig>` pour les tests de consentement GitHub ; aucun changement de la logique de migration.
- Garde anti-régression du contrôle DEV-HUB et procédure Windows de qualification.
- **V1.0.7 inchangée**, sans fonctionnalité nouvelle ; Dev, covers et correctifs C4/C5/C6/HF1 conservés.
- Résultat Windows réel `--devhub-release` **à revalider** (tests locaux limités à l'audit statique).


## GameDraw 1.0.7 STAB-C6-HF1 (24/10/2026)
- Correction du test Rust `old_data_preserved_after_success` : synchronisation du marqueur de sauvegarde via un descripteur ouvert en écriture, sans `Accès refusé (os error 5)` sous Windows.
- Ne pas écraser un marqueur de récupération existant ; nettoyer le dossier de préparation si l'ouverture du marqueur échoue.
- Deux nouveaux tests de non-régression et contrôles statiques DEV-HUB ; conservation de C4/C5/C6 et du gel fonctionnel 1.0.7.
- **Validation Windows requise** : `--devhub-test`, `--devhub-validate`, `--devhub-build`.

# STAB-C6 — Import ZIP de bibliothèque durci (24/10/2026)

Validation des chemins et volumes, staging des images, nettoyage sur erreur, images des doublons ignorées, traitement hors thread interface ; aucun ajout fonctionnel. Tests Rust inclus non exécutés faute de Cargo. Version 1.0.7 conservée.

## GameDraw 1.0.7 — STAB-C5 (24/10/2026)

- Restauration des sauvegardes ZIP sécurisée : extraction en staging, contrôle des chemins et tailles, copie de récupération de l'ancien dossier, reprise sur interruption.
- Mot de passe erroné ou archive corrompue : les données actives restent intactes avant activation.
- Restauration hors thread UI, confirmation et fermeture complète requise avant reprise d'utilisation.
- Tests unitaires Rust ajoutés ; certification Cargo/Windows restant à réaliser. **Pas de nouvelle fonctionnalité.**

## GameDraw 1.0.7 — stabilisation STAB-C4 (24/10/2026)

- Correction du cadre des jaquettes dans la fiche du jeu : hauteur adaptée au ratio natif, bord supérieur et inférieur toujours visibles ; aucun ajout fonctionnel.
- Garde DEV-HUB et tests visuels Chromium sur cinq ratios, format normal et compact.
- Certification Windows/WebView2/EXE non encore exécutée.


## 1.0.7 — STAB-C3 (correction des jaquettes, sans nouvelle fonctionnalité)
- Visuel : protection des coins, recadrage interdit sur toute la jaquette originale, mise en page sur cinq ratios vérifiée dans Chromium.
- Fiabilité : le fallback local asynchrone ne peut plus masquer une nouvelle jaquette sélectionnée.
- Steam : prise en charge du chemin CDN haché officiel pour les jaquettes verticales natives, HD d'abord, sans clé API.
- Validation : audit statique PASS, tests Svelte/Rust et Windows encore à exécuter.

## Candidat de stabilisation V1 — rendu intégral des jaquettes (23/10/2026)

- Correctif uniquement : jaquettes centrées et entièrement visibles dans les écrans existants, sans effet `cover` ni zoom tronquant.
- Non-régression statique ajoutée à l'audit DEV-HUB et suite Vitest pour les huit vues concernées.
- Audit P0/P1, recette Windows et roadmap recentrée sur la stabilisation. **Aucune fonctionnalité ajoutée ; numéro applicatif conservé en 1.0.7, candidat non certifié Windows.**

## 1.0.7 — Bibliothèque et jaquettes (21/10/2026)

- Fusion « Catalogue » / « Importer » : un accès unique aux listes fournies avec confirmation, sans ajout silencieux.
- SteamGridDB sans clé : aperçu de l’URL directe avant validation et retour explicite sur le téléchargement.
- Interface des menus et de l’atelier adaptée aux fenêtres réduites ; flux existant avec clé préservé.
- Version npm, Rust, Tauri et DEV-HUB alignée en 1.0.7.

## 1.0.6 — HF3 (20/10/2026)
- Correction de la question de mise à jour : variable de langue corrigée et consentement Oui/Non mémorisé indépendamment de `config.json`.
- Fiche d'édition en dialogue natif avec barre d'actions toujours visible et défilement interne.
- SteamGridDB sans API : action « Importer l'image copiée » depuis le menu clic droit natif du navigateur avec fallback Ctrl+V.
- Responsive et documentation FR/EN actualisés, version applicative inchangée.

# CHANGELOG — GameDraw 1.0.6

Date : 18 octobre 2026


## Hotfix 1.0.6 HF2 — Atelier SteamGridDB responsive et consentement mises à jour (19/10/2026)

- L'atelier SteamGridDB utilise maintenant une vraie boîte de dialogue HTML modale au premier plan : fenêtre 100 % utilisable à 125/150 % de mise à l'échelle, croix visible, fermeture Échap, zones défilantes.
- Sans clé API, ouverture du site SteamGridDB dans une fenêtre WebView2 **appartenant à GameDraw**, puis import manuel d'une URL HTTPS directe ou d'une image enregistrée. Le navigateur externe reste disponible.
- Conservation de la galerie automatique **avec clé API uniquement** : pas de scraping ni de contournement de l'authentification SteamGridDB.
- Permissions Tauri ciblées pour remettre au premier plan une fenêtre SteamGridDB existante.
- Premier lancement : consentement explicite pour la recherche de mises à jour **Oui / Non**, présenté après le choix de langue. Préférences des installations existantes conservées.
- README français/anglais et recette Windows actualisés ; aucune migration des jeux enregistrés.

## Hotfix 1.0.6 HF1 — Listes intégrées et icônes Windows
- Import direct depuis l'application installée des listes PC (60), Switch 1 (60), Switch 2 (40) et Switch 1+2 (100).
- Import combiné PC + Switch (160 entrées) vers les bonnes plateformes, avec tags Switch préservés et sans écraser jeux ni jaquettes existants.
- Aperçu, confirmation, suppression des doublons et bilan ; plus besoin de retrouver les CSV dans le dossier source.
- Icône de fenêtre 256 px à l'exécution (au lieu de 64 px), et contenu optique agrandi pour les grandes résolutions ICO tout en conservant les pictogrammes dédiés aux petites tailles.
- Aucun changement des paramètres Windows de la barre des tâches, du schéma des données ou du moteur de tirage.

## Interface, jaquettes et fenêtres
- Ajout du **menu clic droit GameDraw sur la jaquette de la fiche** : éditer, importer une image, SteamGridDB, retirer après confirmation (le jeu est conservé).
- Correctif d'ouverture du site SteamGridDB via le navigateur Windows par défaut : ajout de la permission officielle Tauri `opener:default` pour les URL HTTP(S).
- L'atelier de jaquettes s'affiche hors du conteneur transformé de la fiche, pour éviter les panneaux tronqués.
- Confirmation d'import persistante et bouton **Terminer et fermer l'atelier** après application réussie.

## Mises à jour
- Paramètres GitHub techniques masqués de l'interface. Source officielle fixée sur `FaboulousSan/GameDraw` dans la configuration de publication ; les préférences utilisateur restent disponibles (vérification auto et canal).
- Notifications de mise à jour conservées.
- Pas d'installation silencieuse d'un EXE téléchargé : la mise à jour signée Tauri reste une étape distincte nécessitant la signature de l'éditeur.

## Qualité et documentation
- Version projet, Rust, Svelte, npm, Tauri et DEV-HUB alignée sur 1.0.6.
- Changelog présent dans **Options → À propos**, README français/anglais, Wiki.js.
- Aucun changement de schéma de bibliothèque et aucune suppression de données.

## Validation Windows à réaliser
Auto-test → Sync → Validate → Test → Dev → Build → Release. Vérifier SteamGridDB sans clé/avec clé, menu contextuel, import local et fermeture du studio, fenêtre non coupée, versions, MSI/NSIS/portable.


### Correctif de stabilisation V1.0.7 — jaquettes intégrales et sources sans clé
- Jaquettes entières et centrées dans un cadre visuellement rempli (habillage flouté indépendant, original non recadré).
- Parcours sans clé : recherche d'affiches officielles Steam en qualité native + import volontaire d'images du site public SteamGridDB via presse-papiers/URL/fichier.
- SteamGridDB API continue à nécessiter une clé ; aucune extraction automatisée non autorisée.
- Limitation des téléchargements distants pendant le transfert ; tests statiques renforcés.
- Numéro applicatif conservé : **1.0.7** ; compilation Windows à vérifier.
