# WaR LegenD RaidTool — guide simple

Quatre parties : installer WowUp, installer l'addon, s'en servir, sauvegarder ses données avant une réinstallation ou un wipe du jeu.

---

## 1. Installer WowUp-CF

WowUp-CF met les addons à jour tout seul. Les membres de la guilde l'utilisent pour recevoir les nouvelles versions.

1. Télécharger **WowUp-CF** (le WowUp qui marche avec CurseForge) depuis sa page officielle et lancer l'installeur.
2. Au premier lancement, WowUp cherche le jeu. S'il ne le trouve pas : **Mes addons → Ajouter une installation** (ou le choix du client) et pointer vers le dossier du jeu, par exemple `C:\Program Files (x86)\World of Warcraft`.
3. Choisir le client **WoW Forever** (dossier `_forever_`). C'est ce dossier-là que le jeu lit, pas `_classic_`, `_classic_beta_` ni `_retail_`.
4. Vérifier que WowUp affiche bien ce client en haut de la fenêtre avant d'installer quoi que ce soit.

---

## 2. Installer WaR LegenD RaidTool

### Avec WowUp (recommandé, mises à jour automatiques)

1. Dans WowUp : **Obtenir des addons → Installer depuis une URL**.
2. Coller l'adresse du dépôt : `https://github.com/VulcanWL/WarLegendRaidTool`
3. Valider. WowUp télécharge la dernière version et la range dans `Interface\AddOns`.
4. Lancer le jeu. Dans la liste des addons (écran de choix du personnage), vérifier que ces **quatre** lignes sont cochées :
   - `WarLegendRaidTool` (le noyau)
   - `WarLegendRaidTool_Raid` (modules de raid, chargés quand il faut)
   - `WarLegendRaidTool_PvP` (cadres de champ de bataille, chargés quand il faut)
   - `WarLegendRaidTool_Skyborne` (lignes de force / convergences Skyborne, chargé quand il faut)

### À la main (si WowUp pose problème)

1. Télécharger le zip de la dernière **Release** sur la page GitHub du dépôt.
2. Le décompresser dans `World of Warcraft\_forever_\Interface\AddOns\`.
3. Les dossiers `WarLegendRaidTool`, `WarLegendRaidTool_Raid`, etc. doivent être directement dans `AddOns` (pas dans un sous-dossier en plus).

### Mettre à jour

WowUp le fait : il montre « mise à jour disponible », un clic. Fermer le jeu avant, ou faire `/reload` après.

---

## 3. Utilisation générale

### Ouvrir l'addon

- Taper **`/wl`** dans le chat (aussi `/wlrt` ou `/warlegend`), ou cliquer le bouton de la minicarte.
- **`/wl help`** liste toutes les commandes.
- La case **« Rechercher une option... »** en haut de la fenêtre trouve n'importe quel réglage.

### La fenêtre : quatre onglets

| Onglet | Pour quoi faire |
|---|---|
| **Raid** | La soirée de raid, dans l'ordre : Organisation (groupes), Préparation (buffs, ready check, checklist), Combat (cooldowns, auras, qui a pull), Butin et présences (loot council). |
| **JcJ** | Champs de bataille (cadres alliés / ennemis) et Monde ouvert (alerte danger, duels, layers). |
| **Guilde** | Membres (guilde, classes, recrues, carte) et Mes personnages (rerolls, banque, export pour simulateurs). |
| **Options** | Addon (réglages, version, bugs) et Interface (cadres, texte de recharge, niveaux d'objet...), Petits automatismes. |

Toutes les sections sont visibles, sous leur titre. La fenêtre se redimensionne en tirant le coin en bas à droite.

### Les commandes à connaître

| Commande | Effet |
|---|---|
| `/wl` | Ouvre / ferme la fenêtre. |
| `/wl help` | Toutes les commandes. |
| `/wl minimap` | Affiche / cache le bouton de la minicarte. |
| `/wl move` | Déplacer des fenêtres et éléments d'écran (hors combat). |
| `/wl profile` | Exporter / importer tous les réglages en texte. |
| `/wl bugs` | Voir les erreurs Lua récentes (à envoyer à l'auteur en cas de souci). |
| `/wl perf` | Mémoire et CPU utilisés par l'addon. |

### Premiers réglages conseillés

1. **Options → Réglages → Général** : choisir la langue (français / anglais), le style de la fenêtre, la taille du texte.
2. **Options → Réglages → Modules** : éteindre ce dont on ne se sert pas.
3. Utile en raid : **groupes de raid** (presets), **ready check**, **loot council**, **buffs manquants**, **cooldowns de raid**.
4. Si un autre addon fait la même chose, l'addon propose de ne pas doubler (Réglages → Général).

### Un problème ?

- `/reload` règle beaucoup de choses.
- `/wl bugs` pour voir l'erreur, la copier et l'envoyer à l'auteur.
- Vérifier dans WowUp que l'addon est bien à jour.

---

## 4. Sauvegarder ses données avant une réinstallation ou un wipe

Un wipe peut vider le dossier `WTF` (réglages et données des addons). Il faut donc **copier ses fichiers avant**, et les remettre après.

### Ce qu'il faut sauvegarder

Les données sont dans :

```
World of Warcraft\_forever_\WTF\Account\<NOM DU COMPTE>\SavedVariables\
```

Copier ces fichiers (ceux qui existent) :

| Fichier | Contenu |
|---|---|
| `WarLegendRaidTool.lua` | Tout le noyau : réglages, presets de groupes, historiques, membres, présences, loot, etc. **Le plus important.** |
| `WarLegendRaidTool_PvP.lua` | Réglages des cadres de champ de bataille. |
| `WarLegendRaidTool_Skyborne.lua` | Positions Skyborne (si tu en as un). |
| `WarLegendRaidTool.lua` (dans le dossier du personnage : `WTF\Account\<compte>\<royaume>\<personnage>\SavedVariables\`) | Réglages Myslot propres au personnage (`MyslotSettings`). Les exports Myslot (`MyslotExports`) et les réglages de DoesItDie (`DoesItDieDB`) sont dans le `WarLegendRaidTool.lua` du compte. |

Les fichiers `.lua.bak` à côté sont une copie de secours faite par le jeu : les garder aussi, ça ne coûte rien.

Le plus simple et le plus sûr : **copier tout le dossier `WTF`** dans un endroit à toi (bureau, clé USB, cloud). Ça sauve aussi les réglages du jeu et des autres addons.

### Étapes avant le wipe

1. **Quitter complètement le jeu** (pas juste le personnage) : c'est à ce moment que le jeu écrit ses fichiers.
2. Copier le dossier `WTF` (ou au minimum les 3 fichiers ci-dessus) dans un dossier de sauvegarde, par exemple `Documents\Sauvegarde WoW 2026-10-20\`.
3. Bonus : en jeu avant de quitter, `/wl profile` → **Exporter**, copier le texte et le coller dans un fichier `.txt`. C'est un deuxième filet, mais il ne contient que les **réglages**, pas les historiques ni les presets de groupes. La copie des fichiers reste la vraie sauvegarde.

### Étapes après le wipe

1. Réinstaller le jeu si besoin, puis **réinstaller WowUp et l'addon** (parties 1 et 2).
2. **Lancer le jeu une fois**, se connecter, puis quitter : ça recrée l'arborescence `WTF\Account\<NOM>\SavedVariables\`.
3. **Le jeu fermé**, recopier les fichiers sauvegardés dans ce dossier `SavedVariables` (remplacer ceux qui y sont). Le nom du compte doit être le même ; sinon copier dans le dossier du nouveau nom de compte.
4. Relancer le jeu : l'addon retrouve ses données. En cas de doute, `/wl` et regarder si les presets et réglages sont là.
5. Si seuls les réglages ont été perdus : `/wl profile` → **Importer** → coller le texte exporté → `/reload`.

### Pièges à éviter

- **Ne jamais copier les fichiers pendant que le jeu tourne** : il les réécrit à la sortie et écrase ta restauration.
- Un fichier sauvegardé d'une **version plus ancienne** de l'addon marche : l'addon sait migrer ses données. Mais ne pas remettre un vieux fichier sur une version déjà utilisée sans l'avoir sauvegardé d'abord.
- Garder au moins **deux copies** de la sauvegarde (par exemple PC + clé USB), tant que le wipe n'est pas passé et que tout fonctionne.

---

*Version courte à retenir : WowUp → URL du dépôt → quatre addons cochés → `/wl`. Avant un wipe : jeu fermé, copier `WTF\Account\<compte>\SavedVariables`, remettre après le premier lancement.*
