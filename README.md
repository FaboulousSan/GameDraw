<div align="center">
  <img src="assets/gamedraw-logo.svg" alt="GameDraw" width="150" />

# 🎲 GameDraw 1.0.6

**Tu as des jeux. Beaucoup de jeux. GameDraw t'aide à choisir lequel lancer.**

*Windows · Français / English · Local-first · sans compte obligatoire*

Créé par **Faboulous San**.

**Langues de la documentation :** 🇫🇷 Français (ce fichier) · 🇬🇧 [English — README.en.md](README.en.md).
</div>

---

> **Le problème :** « Je joue à quoi ce soir ? »  
> **La méthode classique :** regarder sa bibliothèque pendant 40 minutes, puis relancer le même jeu.  
> **La méthode GameDraw :** laisser le hasard faire le sale boulot.


**Version 1.0.6 — [CHANGELOG](CHANGELOG.md) :** menu sur les jaquettes, navigation SteamGridDB, confirmation d’import et paramètres GitHub simplifiés.

## 🔄 Mises à jour GitHub — GameDraw 1.0.6

**Au premier lancement**, juste après le choix de la langue, GameDraw demande : **« Souhaites-tu vérifier automatiquement les mises à jour au démarrage ? »** Tu peux répondre **Oui** ou **Non**, sans télécharger ni installer quoi que ce soit. Avant cette réponse, GameDraw ne vérifie pas GitHub. Le choix est sauvegardé et peut être modifié dans **Options → Mises à jour**. Les utilisateurs ayant déjà une configuration conservent leur choix existant.

Tu peux maintenant rechercher les nouvelles versions **directement dans GameDraw**. Dans **Options → Mises à jour** :

1. Le dépôt **[FaboulousSan/GameDraw](https://github.com/FaboulousSan/GameDraw/)** est déjà configuré. Aucun token n'est requis pour consulter ses releases publiques.
2. Sélectionne **Stable** (releases finales) ou **Bêta** (inclut les préversions).
3. Clique sur **Rechercher une mise à jour** pour consulter la version, les nouveautés et les installateurs Windows publiés.
4. Sélectionne un `.exe`/`.msi` GameDraw et clique sur **Télécharger dans Windows**. Confirme : une **barre de progression réelle** indique le pourcentage et le volume téléchargé ; le fichier arrive dans **Téléchargements** sans écraser un téléchargement existant.
5. Installe-le **manuellement** après contrôle de sa provenance. GameDraw ne lance jamais l'installateur à ta place en 1.0.6.

### Détection automatique désactivable

Sur une **nouvelle installation**, la recherche au démarrage est **activée par défaut**, mais tu peux la désactiver dans Options → Mises à jour. Les préférences enregistrées lors d'une mise à jour de GameDraw sont **préservées** (un ancien réglage « désactivé » reste désactivé). Une seule requête GitHub est effectuée au lancement si l'option est active.

Lorsqu'une version plus récente existe, GameDraw présente une **notification animée** montrant `version actuelle → nouvelle version`, une synthèse des nouveautés, et les choix **« Découvrir la mise à jour » / « Plus tard »**. Les animations respectent le réglage système « Réduire les animations ». Utilise **« Tester la notification animée »** dans Options → Mises à jour pour voir son rendu immédiatement, même si aucune nouvelle version GitHub n'est disponible ; cet aperçu est explicitement marqué comme démonstration. Si les notifications Windows sont déjà autorisées, une notification système peut aussi s'afficher, sans redemander d'autorisation.

La détection **n'entraîne jamais de téléchargement ni d'installation silencieuse**. Désactive-la pour ne plus contacter GitHub au démarrage ; la recherche manuelle demeure disponible. GameDraw ne propose jamais une version antérieure à celle déjà installée.

L'**installation réellement intégrée et signée** demande la configuration des clés de signature officielles Tauri et de la chaîne de publication GitHub. Voir le [guide d'intégration bêta](docs/IMPORT-BETA-UPDATER-1.0.5.md) et la [procédure de mise à jour](docs/MAJ-GITHUB-1.0.5-FR.md).


## 👀 Aperçu

### 📚 Ta bibliothèque

<p align="center">
  <img src="docs/screenshots/gamedraw-bibliotheque.png" alt="GameDraw - Bibliothèque" width="880" />
</p>

GameDraw centralise tes jeux, leurs statuts, tes notes, tes tags, ta progression et quelques autres petites choses qui rendent un backlog beaucoup trop sérieux.

### 🌱 Au tout début

<p align="center">
  <img src="docs/screenshots/gamedraw-bibliotheque-vide.png" alt="GameDraw - Bibliothèque vide" width="760" />
</p>

Bibliothèque vide ? Aucun souci. GameDraw te laisse importer tes jeux ou commencer tranquillement à la main. Il ne juge pas les 287 jeux que tu ajouteras ensuite.

---

# 📥 Importer sa bibliothèque sans y passer la nuit

Tu peux évidemment ajouter les jeux un par un. Tu peux aussi choisir de garder une vie sociale. **Bibliothèque → Importer** propose plusieurs chemins :

<p align="center">
  <img src="docs/screenshots/gamedraw-import-menu.png" alt="GameDraw - menu Importer : Steam, liste TXT/CSV et archive ZIP" width="880" />
</p>

| Méthode | Ce qu'elle fait | Quand l'utiliser |
|---|---|---|
| 🎮 **Depuis Steam** | Récupère la bibliothèque du compte Steam configuré | Tu as déjà une bibliothèque Steam et zéro envie de tout retaper |
| 📝 **Liste / TXT** | Un nom de jeu par ligne | Tu as une liste simple, un vieux fichier texte, ou un bloc-notes héroïque |
| 📊 **CSV** | Importe le nom et, si présents, statut/tags/description/commentaire | Tu veux arriver organisé dès la première minute |
| 📦 **Archive `.zip` GameDraw** | Réimporte une bibliothèque exportée par GameDraw, avec ses jaquettes | Migration, transfert, sauvegarde ou retour triomphal après réinstallation |

> **Les doublons sont ignorés.** GameDraw essaie de gérer ta bibliothèque, pas de créer *Skyrim — Special Special Definitive Re-Re-Edition* en six exemplaires.

## 🎮 Importer depuis Steam

Dans **Bibliothèque → Importer → Depuis Steam**, GameDraw peut récupérer les jeux possédés par le compte configuré dans **Options → Connexion**. Une **clé API Steam** et un **SteamID64** sont nécessaires pour cet import.

<p align="center">
  <img src="docs/screenshots/gamedraw-import-steam.png" alt="GameDraw - aperçu de l'import d'une bibliothèque Steam" width="880" />
</p>

Le principe est simple :

1. configure Steam dans **Options → Connexion** ;
2. clique sur **Récupérer la bibliothèque Steam** ;
3. garde cochés les jeux que tu veux importer ;
4. clique sur **Importer la sélection** ;
5. contemple ton backlog prendre de la masse musculaire.

Si Steam ne retourne aucun jeu, vérifie notamment les informations du compte et la visibilité du profil/bibliothèque.

## 📝 Importer un fichier `.txt` — le tutoriel pas à pas

**Pas besoin d'une clé Steam ni de connaissances techniques.** Tu as simplement besoin d'une liste avec **un nom de jeu par ligne**.

### 1. Prépare ton fichier avec le Bloc-notes

Ouvre **Bloc-notes** sur Windows, puis écris ou colle par exemple :

```text
Hades
Celeste
Baldur's Gate 3
Dave the Diver
Stardew Valley
```

Enregistre-le avec **Fichier → Enregistrer sous** :

- **Nom :** `mes-jeux-pc.txt` (ou `mes-jeux-switch.txt`).
- **Type :** *Tous les fichiers*, si Windows ajoute une extension inattendue.
- **Encodage :** *UTF-8*, pour conserver les accents.
- **Emplacement :** le Bureau ou ton dossier Téléchargements, pour le retrouver facilement.

> Vérifie que le fichier s'appelle bien `mes-jeux-pc.txt`, et non `mes-jeux-pc.txt.txt`. Windows adore parfois rajouter son petit grain de sel.

Tu peux aussi télécharger notre [`exemple-jeux.txt`](docs/examples/exemple-jeux.txt) ou une des [listes Switch/PC déjà préparées](docs/examples/listes-jeux/README.md).

### 2. Ouvre le bon menu dans GameDraw

**Parcours exact :** `Bibliothèque` → sélectionne **PC** ou **Switch** → **Importer** → **Liste / CSV**.

<p align="center">
  <img src="docs/screenshots/gamedraw-import-menu.png" alt="Menu Importer de GameDraw, avec l'entrée Liste / CSV" width="820" />
</p>

Le choix **PC / Switch est important** : le fichier est ajouté à la bibliothèque de la plateforme sélectionnée. Si tu possèdes les deux consoles Nintendo Switch, utilise l'onglet **Switch** et, pour les distinguer, les [listes CSV avec tags Switch 1 / Switch 2](docs/examples/listes-jeux/README.md).

### 3. Sélectionne ton fichier `.txt`

Dans la fenêtre **Importer une liste**, tu as deux possibilités :

1. **Clique sur « Glisse un fichier ici »**, puis sélectionne `mes-jeux-pc.txt` dans l'explorateur Windows ; tu peux aussi **glisser-déposer** le fichier dans cette zone.
2. Ou **colle tes lignes** dans la zone de texte, puis clique sur **Importer le texte collé**. Aucun fichier nécessaire dans ce cas.

<p align="center">
  <img src="docs/screenshots/gamedraw-import-liste-txt-csv.png" alt="Fenêtre d'import GameDraw : zone de texte et sélection de fichier TXT ou CSV" width="820" />
</p>

### 4. Retrouve les jeux dans ta bibliothèque

GameDraw lit le fichier et importe directement les noms, puis affiche une confirmation. **Les jeux déjà présents sous le même nom sont ignorés**, afin d'éviter de collectionner trois fois *Hades* au lieu d'y jouer une fois.

Les jeux importés apparaissent dans la bibliothèque **PC** ou **Switch** choisie. Tu peux ensuite enrichir leurs fiches, ajouter des jaquettes et les inclure dans un tirage.

**Petites réponses aux problèmes fréquents :**

- **Aucun jeu n'apparaît ?** Regarde d'abord si tu es dans la bonne plateforme PC/Switch et vérifie les filtres/recherches actifs.
- **Le fichier est refusé ?** Utilise un vrai `.txt` avec un titre par ligne, sans en-tête CSV, et enregistre-le en UTF-8.
- **Tu as des noms répétés ?** Les doublons exacts (sans tenir compte de la casse) sont ignorés.
- **Tu veux aussi importer des tags et des statuts ?** Passe au format CSV ci-dessous.

> Cinq minutes pour importer un backlog. Quatre ans pour le terminer. Les mathématiques du joueur restent un mystère.

👉 [**Guide détaillé d'import TXT/CSV avec captures**](docs/GUIDE-IMPORT-TXT-CSV.md)

## 📊 Importer un fichier `.csv`

Le CSV suit **le même chemin que le TXT** : `Bibliothèque → PC / Switch → Importer → Liste / CSV`, puis sélection du fichier `.csv`. Il est pratique pour importer plus que le nom du jeu. La colonne **`Nom` est obligatoire** ; les colonnes suivantes sont optionnelles :

- `Statut` ;
- `Tags` ;
- `Description` ;
- `Commentaire`.

Exemple :

```csv
Nom,Statut,Tags,Description,Commentaire
Hadès,Terminé,"roguelike,action","Évasion des Enfers","À refaire en difficulté supérieure"
Celeste,En cours,"plateforme,indé","Ascension du mont Celeste","Chapitre 7 en cours"
Baldur's Gate 3,Non commencé,"RPG,coop","RPG narratif","Un jour. Probablement."
```

👉 Exemple complet : [`docs/examples/exemple-jeux.csv`](docs/examples/exemple-jeux.csv)

Les statuts intégrés reconnus par défaut sont notamment **Non commencé**, **En cours**, **En pause**, **Terminé** et **Abandonné**. Les colonnes absentes ne bloquent pas l'import. **Virgules ou points-virgules acceptés :** GameDraw 1.0.4 reconnaît aussi les CSV exportés par Excel en français (avec éventuel BOM UTF-8).

### ✨ Nouveauté 1.0.4 — les CSV d’Excel en français

Tu as exporté un fichier depuis Excel et toutes tes colonnes sont séparées par des `;` ? Bonne nouvelle : **GameDraw reconnaît maintenant automatiquement `;` ou `,`**. Les guillemets sont pris en charge, même lorsque le nom ou les tags contiennent des séparateurs.

```csv
Nom;Statut;Tags
"Super Mario Odyssey";En cours;"Switch 1, Mario"
"Celeste";Non commencé;"plateforme;indé"
```

Le parcours ne change pas : **Bibliothèque → PC/Switch → Importer → Liste / CSV**.

Les images de jaquettes continuent de se gérer depuis la fiche d'un jeu : **Modifier → Choisir un fichier**, ou via Steam/RAWG/SteamGridDB. En cas d'image introuvable, une vignette de remplacement s'affiche au lieu d'une image cassée.

## 🎁 Packs de jeux prêts à importer

Tu viens d'installer GameDraw et la bibliothèque te regarde comme un frigo vide un dimanche soir ? Le package fournit maintenant des listes prêtes à l'emploi :

| Pack | TXT | CSV avec tag | Jeux |
|---|---|---|---:|
| 🟥 **Nintendo Switch** | [`jeux-switch-1.txt`](docs/examples/listes-jeux/jeux-switch-1.txt) | [`jeux-switch-1.csv`](docs/examples/listes-jeux/jeux-switch-1.csv) | 60 |
| 🟦 **Nintendo Switch 2** | [`jeux-switch-2.txt`](docs/examples/listes-jeux/jeux-switch-2.txt) | [`jeux-switch-2.csv`](docs/examples/listes-jeux/jeux-switch-2.csv) | 40 |
| 🎮 **Switch 1 + 2** | [`jeux-switch-1-et-2.txt`](docs/examples/listes-jeux/jeux-switch-1-et-2.txt) | [`jeux-switch-1-et-2.csv`](docs/examples/listes-jeux/jeux-switch-1-et-2.csv) | 100 |
| 🖥️ **PC** | [`jeux-pc.txt`](docs/examples/listes-jeux/jeux-pc.txt) | [`jeux-pc.csv`](docs/examples/listes-jeux/jeux-pc.csv) | 60 |

Les fichiers **TXT** contiennent simplement un titre par ligne. Les fichiers **CSV** ajoutent en plus un tag `Switch 1`, `Switch 2` ou `PC`. C'est particulièrement utile pour la Switch : GameDraw garde actuellement une bibliothèque Switch commune, donc les tags permettent de distinguer les deux générations sans transformer l'application en musée Nintendo à douze étages.

> Ces listes sont des **sélections de départ non exhaustives**. Supprime ce que tu n'as pas, ajoute ce qui manque, et personne ne viendra vérifier ton backlog avec un clipboard.

👉 Mode d'emploi détaillé : [`docs/examples/listes-jeux/README.md`](docs/examples/listes-jeux/README.md)

## 📦 Réimporter une archive GameDraw

Une bibliothèque exportée depuis GameDraw peut être réimportée avec **Bibliothèque → Importer → Archive `.zip`**. L'archive de bibliothèque contient les jeux de la plateforme exportée et les jaquettes associées.

C'est particulièrement pratique pour :

- transférer une bibliothèque ;
- conserver une copie avant une grosse réorganisation ;
- restaurer une plateforme sans refaire tout le travail ;
- prouver à ton futur toi que oui, tu avais vraiment ajouté autant de jeux.

> Pour une sauvegarde globale de GameDraw — réglages, plateformes, bibliothèques, jaquettes, historique, etc. — utilise plutôt **Options → Données → Sauvegarde**. L'export de Bibliothèque concerne une plateforme, pas toute l'application.

---

# 🚀 Installer ou lancer GameDraw

GameDraw existe sous trois formes.

| Version | Fichier | Idéal pour |
|---|---|---|
| 🧙 **Installateur Windows** | `GameDraw_1.0.6_x64-setup.exe` | Installation classique et simple |
| 🏢 **MSI** | `GameDraw_1.0.4_x64_en-US.msi` | Installation administrée / Windows Installer |
| 🧳 **Portable** | `Portable\GameDraw.exe` | Lancer GameDraw sans installation |

### 🧙 Installateur classique

1. Lance `GameDraw_1.0.6_x64-setup.exe`.
2. Suis l'assistant Windows.
3. Lance **GameDraw**.
4. Essaie de ne pas passer 25 minutes à choisir ton thème avant ton premier tirage.

### 🧳 Mode portable

Aucune installation :

```text
Portable\GameDraw.exe
```

Tu peux conserver ce dossier où tu veux et lancer directement l'application.

> Le mode portable concerne **l'exécutable**. Les données utilisateur restent gérées localement par GameDraw dans le profil Windows afin d'éviter de semer des fichiers de configuration partout comme des miettes de chips.

---

# 🌍 Premier lancement

Lors du premier démarrage, GameDraw détecte la langue du système et te propose :

- 🇫🇷 **Français** ;
- 🇬🇧 **English**.

La langue détectée n'est qu'une suggestion : tu gardes le dernier mot.

Tu pourras la modifier ensuite dans :

```text
Options → À propos
Settings → About
```

---

# 🎯 Ce que GameDraw sait faire

## 🎲 Tirer un jeu

Le cœur de l'application : sélectionner un jeu de ta bibliothèque selon tes critères.

Tu peux notamment profiter de :

- filtres de tirage ;
- tirage simple ou multiple ;
- anti-répétition ;
- roulette russe ;
- **20 animations** de tirage ;
- **42 effets** de révélation ;
- plusieurs styles de chrono pour tes sessions.

Le hasard n'a jamais eu autant de réglages.

## 📚 Gérer ta bibliothèque

Pour chaque jeu, tu peux notamment suivre :

- son statut ;
- ta note ;
- tes tags ;
- ton commentaire personnel ;
- ton temps de jeu ;
- tes défis ;
- ton coup de cœur ;
- ton envie d'y jouer ;
- sa progression et son type de fin ;
- son état **100 %**.

## 🧾 Backlog

GameDraw t'aide aussi à voir les jeux qui attendent encore leur heure de gloire — ou leur suppression discrète de la liste.

## 📊 Statistiques

Retrouve notamment :

- historique des tirages ;
- statistiques par plateforme ;
- progression ;
- heatmap ;
- couverture des notes ;
- régularité de tes tirages.

## 🏆 Succès

GameDraw propose également un système de succès. Parce qu'il était apparemment nécessaire de gamifier le fait de choisir à quel jeu vidéo jouer.

---

# 🔎 Ajouter un jeu autrement

Pas besoin d'importer une armée entière à chaque fois. Pour ajouter quelques titres, GameDraw propose aussi :

- **Ajout manuel** : tu connais le nom, tu le tapes, affaire classée ;
- **Depuis RAWG** : recherche assistée via le service RAWG ;
- **Depuis Steam** : recherche d'un jeu côté Steam ;
- **Catalogues prédéfinis** : pratique pour amorcer rapidement une plateforme.

L’import d’une bibliothèque Steam nécessite une clé API Steam et un SteamID64 ; la recherche de jaquette Steam fonctionne sans clé. RAWG et SteamGridDB nécessitent chacun leur propre clé API pour les recherches intégrées.

👉 Guide : [`docs/GameDraw-Cles-API.md`](docs/GameDraw-Cles-API.md)

Le fonctionnement principal de GameDraw reste disponible **sans compte GameDraw et sans cloud obligatoire**. Internet intervient uniquement lorsque tu demandes une fonction qui en a réellement besoin.

---

# 💾 Où sont mes données ?

GameDraw est conçu en **local-first**.

Les données utilisateur sont stockées localement dans le profil Windows :

```text
%APPDATA%\com.sensei.gamedraw\
```

GameDraw n'exige pas de compte utilisateur pour fonctionner.

Pour sauvegarder ou restaurer tes données, utilise les fonctions prévues dans **Options → Données**.

> Conseil qui semble évident jusqu'au jour où il ne l'est plus : fais une sauvegarde avant une grosse manipulation ou un changement de machine.

---

# ⌨️ Quelques raccourcis

| Touche | Action |
|---|---|
| `Espace` | Lancer un tirage |
| `1` à `6` | Changer de vue |
| `Échap` | Fermer certaines fenêtres/fiches |
| Clic droit | Ouvrir les menus contextuels disponibles |

---

# 🎨 Personnalisation

GameDraw permet de personnaliser notamment :

- thèmes ;
- animations ;
- effets ;
- sons ;
- transitions ;
- densité de l'interface ;
- certains comportements de l'application.

Le meilleur thème reste évidemment celui que tu choisiras après en avoir testé douze.

---

# 🛟 En cas de problème

Quelques réflexes utiles :

1. ferme puis relance GameDraw ;
2. vérifie que tu utilises bien la dernière version fournie ;
3. si une fonction Internet échoue, vérifie ta connexion et les éventuelles clés API ;
4. évite de supprimer manuellement les fichiers de `%APPDATA%\com.sensei.gamedraw\` sans sauvegarde ;
5. garde une copie de tes données avant toute opération importante.

Si GameDraw démarre mais qu'une fonction particulière pose problème, note ce que tu étais en train de faire : les bugs détestent les témoins précis.

---

# 🔐 Vie privée

GameDraw fonctionne principalement avec des données stockées localement.

Les connexions réseau sont utilisées lorsque tu demandes explicitement une fonction nécessitant un service externe, par exemple une recherche de jeu ou de jaquette.

Pas besoin de créer un compte GameDraw pour choisir entre « finir ce RPG de 120 heures » et « relancer Mario cinq minutes ».

---

# 👤 À propos

**GameDraw 1.0.4**  
Créateur : **Faboulous San**  
© 2026 Faboulous San. Tous droits réservés.

---

<div align="center">

### 🎲 Bon jeu !

**GameDraw choisit le jeu. Pour les excuses du genre « finalement je vais juste regarder YouTube », il ne peut encore rien faire.**

</div>

## 🎨 Une icône qui ne se cache plus derrière son fond

GameDraw s'habille désormais d'une **icône blanche transparente** pour l'exécutable, le Bureau, la barre des tâches et les raccourcis Windows. Le bleu néon est là ; la grosse tuile de fond, non. Elle est partie jouer à cache-cache.

Tu préfères le côté obscur de la manette ? Dans **Options → Apparence**, choisis **Sombre / Noir** : l'icône de fenêtre, de barre des tâches et, le cas échéant, de barre système change immédiatement.

Pour un **raccourci du Bureau**, clic droit → **Propriétés → Changer d’icône → Parcourir** et choisis `GameDraw-Dark.ico`. Les deux fichiers `.ico` sont livrés avec les ressources de GameDraw et copiés dans `Livrables/Icones-Windows` après une Release. Pour un raccourci épinglé, retire-le puis épingle-le de nouveau si Windows conserve l’ancienne image en cache.


### 🔍 Pourquoi une icône est-elle parfois différente après mise à jour ?

Windows met les icônes en cache, notamment dans la barre des tâches. Si tu vois encore l'ancienne image après installation d'une nouvelle version, **ferme GameDraw**, retire l'ancien raccourci épinglé si nécessaire et épingle le nouveau. Cela n'affecte ni ta bibliothèque ni tes sauvegardes.

La nouvelle icône GameDraw privilégie **la lisibilité** : dessin plus simple en 16/20/24/32 px pour la barre des tâches, rendu détaillé en 48/64/128/256 px pour les grandes icônes. Une icône 4K miniature n'a pas de super-pouvoirs : chaque pixel doit avoir une utilité.


### 🔍 Atelier SteamGridDB — HF5 (GameDraw 1.0.4)

Le bouton **Atelier SteamGridDB · rechercher des images** est accessible dans **Bibliothèque → ouvrir un jeu → Modifier (crayon)**. Une **vraie boîte de dialogue au premier plan** s'ouvre, à la taille de la fenêtre, avec une croix toujours accessible et la touche **Échap**. Le contenu défile même sur un petit écran ou avec un zoom Windows à 125/150 %.

**Avec une clé API SteamGridDB :**

1. Dans **Options → Connexion**, active SteamGridDB, colle ta **clé API SteamGridDB personnelle** (pas une clé Steam Web API) et clique sur **Tester la connexion SteamGridDB**. La clé se masque par défaut.
2. Ouvre la fiche du jeu, puis **Modifier → Atelier SteamGridDB**.
3. Saisis ou corrige le titre, clique sur **Rechercher** et choisis le bon jeu dans la liste (les titres, éditions et variantes peuvent différer).
4. Explore les illustrations par **Portrait / Paysage / Carré** ; utilise **Suivant** ou **Précédent** pour les autres images.
5. Clique sur **Utiliser** sous l'image souhaitée. La version d'origine est téléchargée et vérifiée, puis copiée dans le stockage local GameDraw. Le changement doit apparaître dans la fiche et dans la bibliothèque, y compris au prochain lancement.

**Sans clé API :** l'atelier reste utilisable. Clique sur **Parcourir SteamGridDB dans GameDraw** : la page publique s'ouvre dans une **fenêtre WebView2 gérée par GameDraw**, sans quitter le logiciel. Cherche ton jeu et repère la jaquette souhaitée sur le site. Sur l'image, utilise **Copier l'adresse de l'image** (puis colle son URL HTTPS directe dans l'atelier et clique sur **Appliquer**) ou **Enregistrer l'image** (puis **Choisir une image locale**). Le bouton **Navigateur externe** reste disponible si le site bloque sa consultation dans WebView2. L'image sélectionnée est enregistrée localement et retrouvée dans ta Bibliothèque après fermeture de l'atelier. Une URL de **page HTML** ne peut pas être importée comme image. La navigation publique est possible sans clé ; **l'accès automatisé aux résultats de l'API SteamGridDB exige une clé**. Il n'y a ni scraping du site ni accès dissimulé à l'API.

**Erreurs expliquées :** `401` = clé manquante/refusée ; `403` = accès interdit ; `429` = limite de requêtes ; timeout = connexion interrompue. Tu peux toujours revenir à l'import manuel. Aucune nouvelle clé ni résultat ne sont écrits dans les journaux ; les clés restent gérées par les paramètres existants.

**Bon à savoir :** une bannière paysage ou un carré peuvent être appliqués à une jaquette, mais le cadrage de la Bibliothèque reste principalement vertical : privilégie les formats Portrait pour un rendu homogène.

### 🖼️ Une jaquette refuse de s'afficher ?

Dans **Bibliothèque → sélectionne le jeu → Modifier (crayon)**, tu peux désormais :

- cliquer sur **Choisir un fichier** pour utiliser une image JPEG, PNG, WEBP ou GIF ;
- chercher une jaquette avec **Steam** (sans clé), **RAWG** ou **SteamGridDB** (clé API requise selon le service) ;
- coller l'adresse directe d'une image puis cliquer sur **Appliquer**.

GameDraw enregistre la jaquette **sur ton PC** : tu n'as pas à retrouver le fichier à chaque lancement.
Si un service renvoie un code 401 ou une page à la place d'une image, l'application l'explique au lieu d'afficher une mystérieuse icône cassée. Et si le fichier local n'existe plus, elle montre une vignette de remplacement.


### Fenêtre GameDraw intégrée (Windows)

Depuis la **1.0.4 (HF1)**, GameDraw utilise un en-tête unifié à la place du bandeau Windows séparé : logo, onglets, thème et contrôles de fenêtre partagent le même style. Tu peux déplacer la fenêtre en attrapant son logo ou la zone libre de l'en-tête. Les boutons **—**, **□** et **×** permettent de réduire, agrandir/restaurer et fermer. Une session chronométrée active conserve sa confirmation avant fermeture.

Les raccourcis Windows (dont `Alt+F4`) restent disponibles. Le comportement du redimensionnement et de l'accrochage aux bords doit être confirmé sur Windows après compilation.


### Dépannage DEV-HUB — Auto-test code 76 (HF2)

Si l'Auto-test s'arrête immédiatement sur un « manifeste invalide », le correctif HF2
rétablit le manifeste Windows et introduit un contrôle explicite, compatible LF/CRLF :

```powershell
node .\tools\devhub-manifest-check.mjs
.\DEV-AUTO.bat --devhub-selftest
```

Les erreurs `[MANIFEST][ERREUR]` indiquent le champ en cause. Les jeux et les
jaquettes existants ne doivent pas être supprimés. Voir `docs/WikiJS/09-Diagnostic-Depannage.md`.


## GameDraw 1.0.5 HF3 — Finitions Windows et bibliothèque

### Icônes Windows haute définition
L’icône blanche reste celle de l’exécutable, de l’installateur et des nouveaux raccourcis. La variante noire est fournie pour un raccourci personnalisé. Chaque ICO intègre **11 rendus PNG transparents**, de 16 à 256 px. Pour les **petites tailles (16/20/24/32 px)**, GameDraw utilise désormais un pictogramme de manette simplifié, plutôt qu’une réduction floue du logo détaillé. Les grandes tailles reprennent l’illustration HD avec ses cartes.

Windows décide de la taille physique des icônes de la barre des tâches : une application ne peut pas forcer une icône plus grande. Pour vérifier la nouvelle icône sur un raccourci déjà épinglé, ferme GameDraw, désépingle-le et épingle le nouvel exécutable. Sur le Bureau, tu peux utiliser **clic droit → Propriétés → Changer d’icône** puis sélectionner `GameDraw-Light.ico` ou `GameDraw-Dark.ico` depuis les livrables.

### Clic droit de la Bibliothèque
Sur une carte de jeu, clic droit : **Ouvrir/Modifier**, **Dupliquer**, **changer le statut**, **favoris**, **envie de faire**, **100 %**, **inclure/exclure du cycle de tirage**, **ajouter des tags** et **supprimer** après confirmation. Un menu long reste dans l’écran et peut défiler. Les flèches du clavier et Échap fonctionnent également.

Pour plusieurs jeux : clique sur **Sélectionner**, coche les jeux, puis fais clic droit sur **un jeu déjà sélectionné** pour appliquer le statut ou les marqueurs à tous. Le menu ne modifie pas les autres jeux. Les tags sont ajoutés sans effacer les anciens et les doublons sont ignorés. La barre de sélection propose aussi des actions rapides.

### Suppression totale : sécurité et redémarrage
Dans **Options → Données → Supprimer toutes les données**, GameDraw ouvre une vraie confirmation avec un message humoristique. Il faut taper `SUPPRIMER` avant de valider. Après succès, l’application affiche un message de fin et le bouton **Fermer GameDraw maintenant**. **Il faut fermer complètement et rouvrir GameDraw** après cette opération : éviter de modifier la configuration tant que l’ancienne session est ouverte. Une sauvegarde avant suppression reste fortement recommandée.

### Interface améliorée
Les Options et la page Mises à jour ont un style harmonisé : boutons, cases et champs colorés selon le thème GameDraw, espacement et retours visuels cohérents. Les animations sont réduites si Windows demande une réduction des mouvements.


## Listes de jeux embarquées — GameDraw 1.0.6 HF1

L’application Windows embarque directement les listes CSV de découverte du projet, même en version portable, NSIS ou MSI. Dans **Bibliothèque → Importer → Listes fournies (complètes)**, choisis **PC (60)**, **Switch 1 (60)**, **Switch 2 (40)**, **Switch 1+2 (100)** ou **PC + Switch (160)** pour ajouter les deux plateformes en une opération. Tu disposes d’un aperçu et d’une confirmation. Les doublons sont ignorés, les jaquettes et fiches existantes sont préservées et les tags Switch 1/Switch 2 sont conservés. Ces listes sont des sélections de départ, **pas la liste exhaustive de tous les jeux sortis**. Tu peux toujours importer tes propres TXT/CSV.

### Netteté de l’icône de la barre des tâches

GameDraw conserve son ICO RGBA Windows à 11 tailles pour l’EXE et les raccourcis, et applique maintenant une **image de fenêtre 256 px** au démarrage plutôt qu’une image 64 px. Le contenu optique a été recentré/agrandi dans les grandes tailles, tout en conservant les pictogrammes dessinés pour les petites tailles. **Windows contrôle la hauteur et la taille réelle** de la barre des tâches : GameDraw ne modifie pas ses paramètres. Si seule l’icône GameDraw paraît petite après une mise à jour, désépingle l’ancien raccourci puis épingle le nouvel exécutable.



### SteamGridDB public : une jaquette sans clé API (1.0.6 HF3)

Dans la fiche d'un jeu, ouvrez **Atelier SteamGridDB → Parcourir SteamGridDB dans GameDraw**. Dans la fenêtre du site public, trouvez une jaquette, faites **clic droit sur l'image → Copier l'adresse de l'image** (menu natif du navigateur), puis revenez dans l'atelier et cliquez sur **Importer l'image copiée**. Si WebView2 refuse la lecture du presse-papiers, utilisez **Ctrl+V** dans le champ URL puis **Appliquer**, ou enregistrez l'image et choisissez son fichier. La sélection via l'API avec plusieurs vignettes continue de nécessiter une clé API. L'application n'injecte aucune commande privilégiée dans le site public.

**Fenêtre d'édition :** la fiche est désormais un dialogue natif adapté à la fenêtre Windows ; sa barre d'actions et sa croix restent visibles même en cas de défilement ou de DPI 125/150 %. Échap ferme la fiche.

**Mises à jour au lancement :** la question Oui/Non s'affiche après la langue lors d'une première installation. Pour une configuration conservée d'une version antérieure sans réponse enregistrée, elle est posée une seule fois lors du premier lancement de HF3. Votre choix est conservé.
