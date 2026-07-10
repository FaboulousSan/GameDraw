<p align="center">
  <img src="assets/gamedraw-cover.svg" alt="GameDraw" width="800">
</p>

<p align="center">
  <img alt="version" src="https://img.shields.io/badge/version-Beta%200.35-blue">
  <img alt="license" src="https://img.shields.io/badge/licence-MIT-green">
  <img alt="platform" src="https://img.shields.io/badge/plateforme-Windows%2011-informational">
  <img alt="stack" src="https://img.shields.io/badge/stack-PowerShell%20%2B%20WPF-5391FE">
</p>

---

## En bref

**Le syndrome du "j'ai 200 jeux et je relance Minecraft pour la 47e fois" a enfin un remede.**

GameDraw resout la paralysie du choix face a une ludotheque trop fournie : un clic, une roue qui
tourne, un jeu tire au sort dans ta bibliotheque (Switch, PC, ou toute autre plateforme que tu
ajoutes), avec un roulement equitable (chaque jeu passe une fois avant qu'un autre repasse - meme
lui, oui, meme celui que tu as achete en solde et jamais lance), une duree de session optionnelle
pour eviter le "encore une partie" qui dure 4h, et un historique complet pour prouver a qui de
droit que tu joues vraiment a autre chose que Mario Kart.

## Sommaire

- [Fonctionnalites](#fonctionnalites)
- [Installation](#installation)
- [Configurer la recherche automatique (RAWG)](#configurer-la-recherche-automatique-rawg)
- [Importer sa bibliotheque Steam](#importer-sa-bibliotheque-steam)
- [Themes](#themes)
- [Mettre a jour](#mettre-a-jour)
- [Ou vivent tes donnees](#ou-vivent-tes-donnees)
- [Licence](#licence)

## Fonctionnalites

- **Tirage equitable** avec pool anti-repetition et reset automatique, vraie roue de roulette
  animee (tranches colorees, pointeur, deceleration naturelle) au moment du tirage
- **Compte a rebours design** pendant une session chronometree, avec notification Windows native
  (toast) a l'expiration - le nom du jeu tire y figure. Le tirage en cours et le temps restant
  survivent a un changement de theme comme a une fermeture complete de l'application.
- **Bibliotheques multi-plateformes** illimitees (Switch, PC, ou autre), avec recherche/filtre
- **Backlog** : vue en grille avec pochettes centrees, badges de statut (5 par defaut ou
  personnalises avec couleur au choix) et tags libres par jeu
- **Fiche de jeu** en disposition 2 colonnes (jaquette a gauche, infos a droite, façon page
  Steam/GOG) : description, commentaire personnel, tags, notation et statut modifiables
  directement
- **Recherche en ligne (RAWG)** : cherche un jeu par son nom et recupere sa jaquette
  automatiquement, comme sur Steam ou OBS - [voir plus bas](#configurer-la-recherche-automatique-rawg)
- **Import Steam** : recupere automatiquement les jeux d'une bibliotheque Steam (nom, temps de
  jeu, jaquette) - [voir plus bas](#importer-sa-bibliotheque-steam)
- **Export/import de bibliotheque** entre plateformes ou vers un autre PC (.zip portable)
- **Raccourcis clavier** : Espace pour lancer un tirage, Echap pour fermer une fenetre
- **Notation en un clic** directement sur les icones affichees (etoile, coeur, pouce, trophee ou
  diamant au choix, avec possibilite de choisir quels styles proposer), couleur personnalisable
  pour la note maximale
- **Catalogues de jeux predefinis et editables** (Switch 1, Switch 2, PC) pour peupler une
  bibliotheque en un clic
- **Objectifs et statuts personnalisables** (listes modifiables dans Options, statuts avec
  couleur au choix, possibilite de choisir lesquels afficher)
- **11 themes visuels** : Catppuccin, Ocarina of Time, Cyberpunk, Foret, Dracula, The Witcher,
  Pip-Boy, Super Mario, Dragon, Blanc Premium, Sombre Premium
- **Statistiques** par plateforme (taux de notation avec barre de progression visuelle, temps de
  session cumule, nombre de tirages)
- **Sauvegarde / restauration** en un clic (.zip contenant toutes les donnees, y compris les
  images), avec des dialogues entierement themes (pas de boites Windows grises)
- **Emplacement des donnees configurable** (Options), migre automatiquement au premier lancement
- **Interface adaptive** : fenetre redimensionnable, bascule automatique en disposition verticale
  sous ~850px de large, barre de titre personnalisee aux couleurs du theme actif
- **Fenetre Options par categories** (barre laterale a la Windows 11) : Tirage, Jeux & Statuts,
  Apparence, Connexion, Donnees - densite d'affichage, animation, icone de l'application,
  boutons de l'en-tete a masquer, avertissements, tout centralise et organise
- Journalisation des erreurs pour un diagnostic rapide (chemin visible depuis Options)

Documentation technique complete (architecture, schemas JSON, diagrammes) :
[`docs/GameDraw-Documentation.md`](docs/GameDraw-Documentation.md) - compatible import direct
dans WikiJS.
Historique condense (l'essentiel, par theme) : [`CHANGELOG-RESUME.md`](CHANGELOG-RESUME.md).
Historique detaille de chaque version : [`CHANGELOG.md`](CHANGELOG.md).

## Installation

1. Extraire ce dossier dans un emplacement **stable et definitif** (ex : `C:\GameDraw`) - a eviter :
   `Downloads` ou tout dossier qui contient un numero de version dans son nom, pour que les futures
   mises a jour et le raccourci Bureau restent valides sans y retoucher.
2. Lancer `Launcher.bat` une premiere fois (demande d'elevation UAC, c'est normal).
3. Dans l'application : **Options -> Creer un raccourci sur le Bureau** (ou executer
   `scripts\Creer-Raccourci.ps1`). Ce raccourci cible PowerShell directement, sans fenetre
   intermediaire, et demande l'elevation automatiquement au double-clic.

Aucune installation de PowerShell/WPF requise : natifs sous Windows 11.

> Si l'execution de scripts est bloquee par la politique locale : `Set-ExecutionPolicy -Scope
> CurrentUser RemoteSigned` dans une invite PowerShell administrateur.

## Configurer la recherche automatique (RAWG)

Le bouton **"En ligne"** (dans *Gerer les jeux*, a cote du champ d'ajout) cherche un jeu par son
nom sur RAWG.io et telecharge sa jaquette automatiquement en un clic - comparable a la
reconnaissance de bibliotheque de Steam. Ca demande une cle API **gratuite**. Voici la procedure
complete, de A a Z :

1. Va sur **[rawg.io/apidocs](https://rawg.io/apidocs)**.
2. Cree un compte gratuit (email + mot de passe, ou connexion via Google/autre - aucune carte
   bancaire n'est demandee).
3. Une fois connecte, ta cle API s'affiche directement sur cette page (une chaine du type
   `a1b2c3d4e5f6...`). Copie-la.
4. Dans GameDraw : **Options -> Recherche en ligne (RAWG)** -> colle la cle dans le champ ->
   **Enregistrer**.
5. Retourne dans **Gerer les jeux**, tape un nom de jeu dans le champ d'ajout, clique
   **"En ligne"** : une liste de resultats avec pochettes s'affiche. Clique sur le bon jeu, il est
   ajoute a la bibliotheque avec sa jaquette deja en place.

C'est tout. La cle est stockee localement dans ta config GameDraw, jamais partagee ailleurs.
RAWG propose aussi une [documentation d'API complete](https://api.rawg.io/docs/) si tu veux
explorer au-dela de ce que GameDraw utilise.

## Importer sa bibliotheque Steam

Le bouton **"Steam"** (dans *Gerer les jeux*, a cote de "En ligne") ouvre une fenetre listant
tous les jeux de ta bibliotheque Steam, avec des cases a cocher pour choisir precisement
lesquels importer (nom, temps de jeu et jaquette officielle recuperes automatiquement).

1. Recupere une cle API gratuite sur **[steamcommunity.com/dev/apikey](https://steamcommunity.com/dev/apikey)**
   (necessite un compte Steam, aucune carte bancaire).
2. Trouve ton **SteamID64** : va sur ton profil Steam, copie l'URL, et colle-la sur
   **[steamid.io](https://steamid.io)** - il affichera ton SteamID64 (un nombre a 17 chiffres).
3. Dans GameDraw : **Options -> Connexion** -> colle la cle API et le SteamID64 dans leurs
   champs respectifs -> **Enregistrer** pour chacun.
4. Ton **profil Steam doit etre public** (Steam -> Modifier le profil -> Confidentialite ->
   "Details du jeu" sur Public) - sinon l'API ne retourne aucun jeu, meme avec une cle valide.
5. Retourne dans **Gerer les jeux**, selectionne la plateforme de destination, clique
   **"Steam"** : coche les jeux a importer (ou "Tout selectionner"), puis
   **"Importer la selection"**.

## Themes

| Theme | Inspiration |
|---|---|
| Catppuccin | Palette pastel tres appreciee des devs, theme par defaut |
| Ocarina of Time | Bois/cuir du menu, or de la Triforce et des rubis, vert Kokiri |
| Cyberpunk | Jaune/noir/gris signature de Cyberpunk 2077 |
| Foret | Vert nature, atmosphere boisee |
| Dracula | Palette officielle Dracula |
| The Witcher | Acier/argent du medaillon du Loup, rouge sang, cuir sombre |
| Pip-Boy | Terminal phosphore vert monochrome (Fallout) |
| Super Mario | Bleu salopette + rouge iconiques, vert Luigi, or des pieces |
| Dragon | Antre obscur, ecailles, feu et tresor |
| Blanc Premium | Theme clair, fond blanc, accents indigo/vert/orange pastel |
| Sombre Premium | Meme identite que Blanc Premium (indigo/vert/orange), sur fond sombre |

Changer de theme : bouton palette dans l'en-tete de la fenetre principale.

## Mettre a jour

Les donnees (bibliotheques, historique, config) vivent dans le dossier configure dans **Options
-> Emplacement des donnees** (par defaut `%LOCALAPPDATA%\GameDraw`), **jamais** dans le dossier
d'installation. Une mise a jour ne touche donc jamais tes donnees.

```powershell
.\scripts\Update-GameDraw.ps1 -Source "C:\Users\toi\Downloads\GameDraw_Package_Beta0.XX.zip"
```

Ce script sauvegarde l'installation actuelle avant d'ecraser le code (`scripts\`, `assets\`,
`docs\`, `Launcher.bat`) avec la nouvelle version. Voir la doc complete pour le detail.

## Ou vivent tes donnees

| Fichier | Contenu |
|---|---|
| `config.json` | Theme, icone de notation, densite, cle RAWG, preferences |
| `platforms.json` | Liste des plateformes |
| `<plateforme>_games.json` | Bibliotheque de jeux par plateforme (statut, tags, notes, jaquettes...) |
| `historique.json` | Historique des tirages |
| `catalogues.json` | Catalogues de jeux predefinis (editables) |
| `session.json` | Tirage et compte a rebours en cours (survit a une fermeture de l'app) |
| `images\` | Jaquettes, logos, captures et icones par jeu |
| `error.log` | Journal d'erreurs |

L'emplacement exact est visible et modifiable depuis **Options -> Emplacement des donnees**.


## Licence

[MIT](LICENSE) - fais-en ce que tu veux, sans garantie. C'est le choix le plus simple et le plus
permissif pour un projet perso ; change pour une autre licence (GPL si tu veux forcer le partage
des modifications, Unlicense pour du domaine public pur) si tes besoins evoluent.
