<div align="center">
  <img src="assets/gamedraw-logo.svg" alt="GameDraw" width="150" />

# 🎲 GameDraw 1.0.3

**Tu as des jeux. Beaucoup de jeux. GameDraw t'aide à choisir lequel lancer.**

*Windows · Français / English · Local-first · sans compte obligatoire*

Créé par **Faboulous San**.
</div>

---

> **Le problème :** « Je joue à quoi ce soir ? »  
> **La méthode classique :** regarder sa bibliothèque pendant 40 minutes, puis relancer le même jeu.  
> **La méthode GameDraw :** laisser le hasard faire le sale boulot.

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

Les statuts intégrés reconnus par défaut sont notamment **Non commencé**, **En cours**, **En pause**, **Terminé** et **Abandonné**. Les colonnes absentes ne bloquent pas l'import. **Utilise des virgules** comme séparateur CSV : les fichiers séparés par des points-virgules (`;`) ne sont pas pris en charge par le parseur actuel.

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
| 🧙 **Installateur Windows** | `GameDraw_1.0.3_x64-setup.exe` | Installation classique et simple |
| 🏢 **MSI** | `GameDraw_1.0.3_x64_en-US.msi` | Installation administrée / Windows Installer |
| 🧳 **Portable** | `Portable\GameDraw.exe` | Lancer GameDraw sans installation |

### 🧙 Installateur classique

1. Lance `GameDraw_1.0.3_x64-setup.exe`.
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

Steam, RAWG et SteamGridDB peuvent nécessiter une clé API ou un identifiant propre au service concerné.

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

**GameDraw 1.0.3**  
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
