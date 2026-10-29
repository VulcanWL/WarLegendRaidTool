<div align="center">

<img src=".github/assets/logo.png" width="128" alt="Logo de WaR LegenD RaidTool">

# WaR LegenD RaidTool

**L'addon de la guilde WaR LegenD pour World of Warcraft Forever**

Raid, butin, guilde et champs de bataille dans une seule fenêtre : `/wl`.

[![Version](https://img.shields.io/github/v/release/VulcanWL/WarLegendRaidTool?style=for-the-badge&label=version&labelColor=1a1a1a&color=ce1918)](https://github.com/VulcanWL/WarLegendRaidTool/releases/latest)
[![WoW Forever](https://img.shields.io/badge/WoW-Forever-1f7fe0?style=for-the-badge&labelColor=1a1a1a)](#installation)

[Contenu](#contenu) · [Installation](#installation) · [Commandes](#commandes-principales) · [Nouveautés](CHANGELOG.md) · [Documentation complète](WarLegendRaidTool/README.md)

</div>

---

## Contenu

La fenêtre a quatre onglets, chacun avec toutes ses sections visibles.

| Onglet | Section | Ce qu'on y trouve |
| --- | --- | --- |
| **Raid** | Organisation | Groupes de raid (presets : groupes et marques posés d'un clic), invitations, promotion auto, liste de summon, barre de marques. |
| | Préparation | Ready check et rappel des talents, checklist des consommables, assignation des buffs, préparation des raiders, inspection du raid. |
| | Combat | CD de raid, suivi d'auras, qui a pull, DoesItDie (tes DoT suffiront-ils à achever la cible) et journal de combat automatique. |
| | Butin et présences | Loot Council (vote, soft-res, nombre de loots reçus), présences, tableau de bord de la guilde, recrues en essai. |
| **JcJ** | Champs de bataille | Cadres ennemis et alliés (dissipations, contrôles), minuteurs de capture et de cimetière, historique et records des premades. |
| | Monde ouvert | Alerte danger, compte à rebours des duels, layers de la guilde. |
| **Guilde** | Membres | Métiers, recrutement et inactifs, la guilde par classe, carte de la guilde et transports, classement JcJ Minotaure. |
| | Mes personnages | Rerolls, stock des persos banque, export pour simulateurs (SimulationCraft, MythicSim, OXM). |
| **Options** | Addon | Réglages (modules, profil, taille de la fenêtre), version, erreurs Lua, temps de chargement. |
| | Interface | Déplacer les fenêtres, options cachées du jeu, niveaux d'objet, outils de la carte. |
| | Petits automatismes | Qualité de vie, focus et alerte de contrôle, minuteurs, améliorations dans les sacs, tri du butin, objectif d'or, Myslot. |

> [!TIP]
> Un outil dont tu ne te sers pas s'éteint dans **Options > Réglages > Modules** : éteint, il ne fait plus rien.
> La case « Rechercher une option... » en haut de la fenêtre trouve n'importe quel réglage.

## Installation

1. Télécharge `WarLegendRaidTool-<version>-forever.zip` depuis la dernière
   [Release](https://github.com/VulcanWL/WarLegendRaidTool/releases/latest).
2. Décompresse-le dans `World of Warcraft\_forever_\Interface\AddOns\` : tu dois y trouver quatre dossiers,
   `WarLegendRaidTool`, `WarLegendRaidTool_Raid`, `WarLegendRaidTool_PvP` et `WarLegendRaidTool_Skyborne`.
3. Connecte-toi (ou `/reload` en jeu), puis tape `/wl`.

Avec **WowUp** : *Obtenir des addons → Installer depuis une URL* → `https://github.com/VulcanWL/WarLegendRaidTool`.
WowUp propose ensuite chaque nouvelle version.

## Commandes principales

| Commande | Effet |
| --- | --- |
| `/wl` | Ouvre / ferme la fenêtre (aussi `/wlrt` ou `/warlegend`). |
| `/wl help` | Toutes les commandes dans le chat. |
| `/rc` | Ready check (chef / assistant), sinon la fenêtre de vérification. |
| `/wl apply [preset]` | Pose les marques et range les groupes d'un preset. |
| `/wl loot` | Loot Council. |
| `/wl map` | Carte de la guilde et transports. |
| `/wl pvp` | Réglages des cadres de champ de bataille. |
| `/wl test` | Montre en même temps tous les modules allumés, pour les voir et les placer. |
| `/wl bugs` | Erreurs Lua récentes. |

La liste complète, avec chaque option : [documentation](WarLegendRaidTool/README.md#commandes).

## Sécurité

- Gratuit, code lisible, rien n'est envoyé hors du jeu.
- Messages d'addon échangés avec ton groupe et ta guilde seulement (exception : le canal caché de Skyborne) ; tout ce qui
  arrive des autres joueurs est borné avant d'être lu.
- Un message reçu n'agit pas à ta place : il affiche une information ou une question à valider d'un clic (seule exception, si
  tu l'allumes : l'invitation par mot-clé chuchoté).
- Annonces publiques sur un clic, aucune action protégée en combat.

Détail : [Sécurité](WarLegendRaidTool/README.md#sécurité).

## Nouveautés

Ce qui change à chaque version : [CHANGELOG.md](CHANGELOG.md), aussi dans les notes de chaque
[Release](https://github.com/VulcanWL/WarLegendRaidTool/releases).

## Crédits

Des parties viennent d'autres addons (BattleGroundEnemies, Myslot, DoesItDie, GuildMap, WarLegend v3 de Sashoof...), chacune
avec sa licence : voir [Crédits](WarLegendRaidTool/README.md#crédits).

## Développement

Règles du projet : [`WarLegendRaidTool/AGENTS.md`](WarLegendRaidTool/AGENTS.md) ; détail des modules :
[`docs/modules.md`](docs/modules.md) ; vérifications : `node tools/check.js` et `node tools/smoke.js` (outils dans
[`tools/`](tools)).
