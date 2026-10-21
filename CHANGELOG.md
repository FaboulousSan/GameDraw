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
