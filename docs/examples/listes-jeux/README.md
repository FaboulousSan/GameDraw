# 🎮 Listes de jeux prêtes à importer

Ces fichiers sont des **listes de départ non exhaustives** fournies avec GameDraw.
Elles servent surtout à tester rapidement l'import ou à amorcer une bibliothèque sans tout saisir à la main.

> Les listes ne prétendent pas être des catalogues officiels complets. Tu peux les modifier, supprimer des lignes ou ajouter tes propres jeux avant import.

## 🪄 Import direct dans l’application finale (1.0.6 HF1)

Les quatre fichiers CSV ci-dessous sont **embarqués dans le frontend compilé**. Même dans le portable, le MSI et l'installateur NSIS, aucun fichier du dossier `docs/` n'est nécessaire pour importer les listes fournies :

1. Ouvre **Bibliothèque → Importer → Listes fournies (complètes)**.
2. Choisis **PC (60)**, **Switch 1 (60)**, **Switch 2 (40)**, **Switch 1+2 (100)** ou **PC + Switch (160)**.
3. Lis l'aperçu, clique sur **Ajouter**, puis vérifie le bilan d'import.

Les jeux PC vont dans la bibliothèque PC, les jeux Switch dans la bibliothèque Switch, avec leurs tags de génération conservés. Les jeux existants et leurs jaquettes ne sont **jamais remplacés**. Relancer le même import ignore les doublons. Les listes sont des sélections de découverte et **ne constituent pas un catalogue complet mondial**.

## 📦 Fichiers fournis

| Plateforme | TXT | CSV | Nombre |
|---|---|---:|---:|
| Nintendo Switch | `jeux-switch-1.txt` | `jeux-switch-1.csv` | 60 |
| Nintendo Switch 2 | `jeux-switch-2.txt` | `jeux-switch-2.csv` | 40 |
| Switch 1 + Switch 2 | `jeux-switch-1-et-2.txt` | `jeux-switch-1-et-2.csv` | 100 |
| PC | `jeux-pc.txt` | `jeux-pc.csv` | 60 |

## 📝 TXT ou CSV ?

- **TXT** : uniquement les noms, un jeu par ligne. C'est le format le plus simple.
- **CSV** : ajoute automatiquement un tag `Switch 1`, `Switch 2` ou `PC`, ce qui est pratique pour filtrer ensuite.

## 🕹️ Important pour Switch 1 / Switch 2

GameDraw possède actuellement une bibliothèque **Switch** commune. Pour conserver la distinction entre les deux générations, préfère les fichiers **CSV** : les jeux Switch 1 reçoivent le tag `Switch 1` et les jeux Switch 2 le tag `Switch 2`.

### Import conseillé

1. ouvre **Bibliothèque** ;
2. sélectionne **Switch** ou **PC** en haut ;
3. clique sur **Importer → Liste / CSV** ;
4. glisse le fichier voulu dans la fenêtre ;
5. laisse GameDraw faire le travail pénible pendant que tu prends tout le mérite.

Les doublons par nom sont ignorés par GameDraw.

## ℹ️ Switch 2

La sélection Switch 2 contient des titres sortis ou annoncés pour Nintendo Switch 2 et des éditions Nintendo Switch 2. Elle est volontairement indicative et pourra évoluer avec le catalogue de la console.
