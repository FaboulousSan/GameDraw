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

# 🔎 Ajouter des jeux

Selon les fonctions utilisées, GameDraw peut travailler avec :

- ajout manuel ;
- listes / imports ;
- Steam ;
- RAWG ;
- SteamGridDB pour certaines recherches de jaquettes.

Certaines fonctions en ligne peuvent nécessiter une clé API ou un identifiant propre au service concerné.

👉 Guide : [`docs/GameDraw-Cles-API.md`](docs/GameDraw-Cles-API.md)

Le fonctionnement principal de GameDraw reste disponible sans compte GameDraw et sans service cloud obligatoire.

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
