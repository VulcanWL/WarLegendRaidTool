# WarLegend RaidTool

Addon WoW **Forever** (interface 16001) de la guilde **War Legend** : groupes de raid, loot council (avec le
nombre de loots reçus), buffs, ready check, checklist, inspection, suivi d'auras, CD de raid, préparation, présences,
rerolls, outils de guilde (inactifs, métiers, recrutement, recrues en essai, stock des persos banque),
export pour simulateurs (SimulationCraft, MythicSim, OXM), cadres PvP (dissipations façon Decursive, CC sur les cadres), alerte danger, alerte de contrôle (CC), texte de recharge, chrono de cimetière (style Capping),
historique et records des premades de BG, liste de summon.
Commande : `/wl` (`/wl help` affiche toutes les commandes ; la case « Rechercher une option... » en haut de la fenêtre trouve un réglage).
La fenêtre a trois onglets : **Raid** (sections Organisation, Préparation, Combat, Butin, JcJ : les outils d'une soirée,
dans l'ordre), **Guilde** (Membres : guilde, recrues, carte ; Mes personnages : rerolls, banque, export sim) et
**Options** (Addon : réglages, version, bugs ; Interface : cadres, options cachées, niveaux d'objet, texte de recharge,
focus, qualité de vie). Options > Réglages : **Général** (bouton de minicarte, préchargement des modules de raid, voix du
décompte, doublons avec d'autres addons), **Modules** (éteindre ceux dont on ne se sert pas), **Profil** (configuration à
copier / coller). Langues : français / anglais (bouton de l'en-tête, comme le style).

> L'addon est réservé aux membres de la guilde **War Legend** (message affiché sinon).
> Droits réservés : utilisation libre, pas de redistribution modifiée sans accord.

## Installation

Il faut **trois dossiers** dans `World of Warcraft\_classic_beta_\Interface\AddOns\` :

```
AddOns\
├── WarLegendRaidTool\        noyau (toujours chargé)
├── WarLegendRaidTool_Raid\   modules de raid (chargés à la demande, comme BigWigs)
└── WarLegendRaidTool_PvP\    cadres ennemis / alliés en champ de bataille (chargés à la demande)
```

Le plus simple : télécharger le zip de la dernière **Release** (les trois dossiers sont à la racine) et le
décompresser dans `AddOns`. Avec **WowUp** : *Obtenir des addons → Installer depuis une URL* → adresse de ce dépôt.

## Premier lancement

1. Vérifier que les trois addons sont cochés dans la liste des addons.
2. `/wl` ouvre la fenêtre. Le chargement des modules de raid se fait tout seul (groupe, donjon, `/wl`),
   celui des cadres PvP en entrant dans un champ de bataille (réglages : `/wl pvp`).
3. Raccourci de rechargement : Échap → Options → Raccourcis → AddOns → WarLegend RaidTool.

## Commandes

`/wl` peut aussi s'écrire `/wlrt` ou `/warlegend`. `[preset]` = nom d'un preset de groupes (sans nom : le preset sélectionné).

**Général**

| Commande | Effet |
|---|---|
| `/wl` | Ouvre / ferme la fenêtre principale. |
| `/wl help` | Affiche toutes les commandes dans le chat. |
| `/wl minimap` | Affiche / cache le bouton de la minicarte (aussi dans Options > Réglages > Général). |
| `/wl bugs` | Ouvre Options > Bugs (erreurs Lua récentes). |
| `/wl preload` | Charger les modules de raid pendant l'écran de chargement (activé par défaut : pas de gel au premier `/wl` ; aussi dans Options > Réglages > Général). |
| `/wl perf` | Mémoire et CPU utilisés par l'addon, puis ses travaux les plus lents (une exécution) et les plus coûteux (total depuis la connexion) : événements, timers, hooks, avec le fichier et la ligne. |
| `/wl move` | Déplacer les cadres (repris de MoveAny, version sûre) : fenêtres Blizzard à la souris hors combat (Ctrl+molette : taille, place retenue en option), éléments d'écran (texte d'erreur, de zone, emotes de boss, souffle, score du BG, barre de capture, durabilité), infobulle au curseur ou à une ancre, FPS / latence. Les barres d'action, cadres d'unité, buffs et minicarte ne sont pas touchés (EllesmereUI). |
| `/wl cvar` | Options d'interface (reprises d'Advanced Interface Options) : distance max de la caméra, fenêtre de file des sorts, distance et empilement des barres de nom, texte de combat, noms et titres, couleurs de classe dans le chat... et un navigateur de toutes les CVars (chercher, modifier, valeur par défaut). Hors combat seulement ; les valeurs changées ici sont remises à la connexion et vont dans les profils. |
| `/wl ilvl` | Niveaux d'objet (repris de SimpleItemLevel) : sur la fiche de personnage, l'inspection, les sacs, la banque et le butin, niveau moyen sous le modèle, ligne dans les infobulles, flèche sur les objets meilleurs que les miens, « E » sur l'équipement sans enchantement. Inactif si l'addon SimpleItemLevel est chargé. |
| `/wl map` | Carte de guilde (reprise de GuildMap) : les membres de la guilde sur la carte du monde et la minicarte, icône de classe, infobulle (niveau, zone), clic : chuchoter, clic droit : inviter. Ma position est partagée hors donjon / raid / BG (désactivable). Compatible avec les membres qui ont l'addon GuildMap. |
| `/wl modules` | Options > Réglages > Modules : décocher un module l'éteint complètement (plus d'événements, de messages ni de CPU). |
| `/wl profile` | Options > Réglages > Profil : exporter tous les réglages (addon et cadres de BG) en un texte à copier, ou en importer un (puis recharger). Les données (historiques, membres, presets) n'y sont jamais. |
| `/wl reset [données]` | Sans nom : liste les données sauvegardées. Avec un nom : remet ce module à zéro (puis recharge). |
| `/wl logdebug` | Active / coupe le débogage du journal de combat automatique. |

**Raid : groupes et marques**

| Commande | Effet |
|---|---|
| `/wl apply [preset]` | Applique le preset : marques + groupes. |
| `/wl marks [preset]` | Pose seulement les marques du preset. |
| `/wl groups [preset]` | Range seulement les groupes du preset. |
| `/wl clear` | Enlève toutes les marques. |
| `/wl list` | Liste les presets enregistrés. |
| `/wl assist [preset]` | Crée ma macro d'assist d'après le preset. |

**Raid : ready check et loot**

| Commande | Effet |
|---|---|
| `/rc` | Lance un vrai ready check (chef / assistant), sinon ouvre la fenêtre de vérification. |
| `/wl rc` | Ouvre la fenêtre de vérification (prêt, durabilité). |
| `/wl loot` | Ouvre le Loot Council. |
| `/wl loot vote` | Ouvre la fenêtre de vote. |
| `/wl loot add [objet]` | Ajoute un objet (lien) à la liste des objets à attribuer. |
| `/wl loot test` | Lance une session de test. |
| `/wl sr` | Ouvre l'onglet des soft-res. |
| `!sr [objet]` *(chuchotement)* | Un joueur réserve un objet en chuchotant le chef de loot (si l'option est cochée). `!sr` seul : voir ses réserves. |

**Outils**

| Commande | Effet |
|---|---|
| `/wl sim` | Export SimulationCraft. `/wl sim oxm` : format OXM, `/wl sim json` : JSON (MythicSim). |
| `/wl summon` | Ouvre la liste de summon. |
| `/wl trials` | Recrues en essai (selon le rang choisi) : depuis quand, nombre de raids, rappel à la fin de l'essai. |
| `/wl bank` | Stock et or de mes persos banque (ceux de mon compte au rang « Banque »), avec recherche. |
| `/wl craft [objet]` | Qui peut fabriquer cet objet dans la guilde (nom ou lien d'objet avec Maj-clic), artisans en ligne en premier. Sans nom : Guilde > Métiers, une ligne par membre et par métier (niveau, nombre de recettes), avec des filtres qui se combinent : nom du joueur, métier, niveau (de - à), recette ou objet. Seuls les membres qui ont l'addon y sont, une fois leurs données reçues (gardées après un redémarrage) ; les recettes d'un métier arrivent quand le membre l'a ouvert une fois. Ctrl-clic : chuchoter l'artisan. |
| `/wl bg` | Historique de mes premades de BG, stats par joueur, records par BG (victoires les plus rapides). |
| `/wl gy` | Active / coupe le test du chrono de cimetière (fausses vagues). |
| `/wl pvp` | Réglages des cadres PvP. |
| `/wl pvpcheck` | Vérifie si les restrictions d'addons sont actives dans ce champ de bataille. |
| `/wl caps` | Chronos de BG au style Capping : capture des bases (Darkspear Island, Arathi 1 min, Alterac 5 min), début de la bataille, file d'attente, réapparition du drapeau. Style BigWigs : la barre passe au centre pour ses 5 dernières secondes, avec un gros décompte 5-4-3-2-1 et la voix. Maj-clic : /dire, Ctrl-clic : canal du BG. |
| `/wl danger` | Alerte danger (monde ouvert) : message + son quand un joueur ennemi JcJ, un monstre « tête de mort » ou un élite rouge approche. |
| `/wl cc` | Grosse icône au centre de l'écran quand vous êtes sous contrôle (étourdi, peur, silence...), avec le temps restant. |
| `/wl duel` | Gros compte à rebours pour les duels façon BigWigs (chiffre animé et voix) : 3, 2, 1, « Combat ! », et les 10 secondes pour revenir quand on sort de la zone de duel. |
| `/wl test` | Teste en même temps tous les modules activés (chronos, duel, cimetière, alertes, cadres de BG, suivi d'auras, ready check en groupe, loot council seul) pour les voir et les déplacer. Aussi le bouton « Tout tester » en haut de la fenêtre. Relancer `/wl test` (ou le bouton, devenu « Arrêter le test ») arrête tout ; aussi `/wl test stop`. |
| `/wl bgmsg` | Derniers messages du champ de bataille, à copier (pour ajouter les textes de drapeau d'un nouveau BG). |

Les erreurs éventuelles s'affichent dans BugSack. Version actuelle : voir `WarLegendRaidTool.toc`.

## Crédits

- Voix du décompte **Amy**, **David**, **Jim** et police **Noto Sans** : reprises de [BigWigs](https://github.com/BigWigsMods/BigWigs)
  (licences CC BY-NC 3.0 / CC0 / SIL OFL, détail dans `Media/Sounds/Countdown/README.txt` et `Media/Fonts/Noto_license.txt`).
- Cadres de champ de bataille : basés sur BattleGroundEnemies (Bullsei).
- Carte de guilde : idée et messages de GuildMap (Portalz, Devetik) ; librairie HereBeDragons (Nevcairiel, BSD), détail dans `Libs/README.txt`.
