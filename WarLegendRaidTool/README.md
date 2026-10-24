# WaR LegenD RaidTool

Addon WoW **Forever** (interface 16001) de la guilde **WaR LegenD** : groupes de raid, loot council (avec le
nombre de loots reçus), buffs, ready check, checklist, inspection, suivi d'auras, CD de raid, préparation, présences,
rerolls, outils de guilde (inactifs, métiers, recrutement, recrues en essai, stock des persos banque),
export pour simulateurs (SimulationCraft, MythicSim, OXM), cadres PvP (dissipations façon Decursive, CC sur les cadres), alerte danger, alerte de contrôle (CC), texte de recharge, chrono de cimetière (style Capping),
historique et records des premades de BG, liste de summon, layers de la guilde, classement JcJ de saison (Minotaure) et
guilde par classe (responsables, rôles déclarés), repris de l'addon WarLegend v3 de Sashoof.
Commande : `/wl` (`/wl help` affiche toutes les commandes ; la case « Rechercher une option... » en haut de la fenêtre trouve un réglage).
La fenêtre a quatre onglets : **Raid** (Organisation, Préparation, Combat, Butin et présences : les outils d'une soirée,
dans l'ordre), **JcJ** (Champs de bataille ; Monde ouvert : alerte danger, duels, layers), **Guilde** (Membres : guilde, classes,
carte, Minotaure ; Mes personnages : rerolls, banque, export sim) et **Options** (Addon : réglages, version, bugs ; Interface :
cadres, options cachées, niveaux d'objet, carte ; Petits automatismes : qualité de vie, focus, texte de recharge, journal,
alerte de contrôle, minuteur de combat, tri du butin), chacun avec toutes ses sections visibles sous de simples légendes ; les choix
de valeurs s'ouvrent en menu déroulant. Options > Réglages : **Général** (bouton de minicarte, préchargement des modules de raid, taille de la fenêtre et du texte (aussi : coin en bas à droite de la fenêtre à glisser), voix du
décompte, doublons avec d'autres addons), **Modules** (éteindre ceux dont on ne se sert pas), **Profil** (configuration à
copier / coller). Langues : français / anglais (bouton de l'en-tête, comme le style). Styles : Auto, EllesmereUI, Blizzard,
WaR LegenD, SashoofUI et les cinq styles **WL v3** de l'addon de Sashoof (panneaux ardoise, accent Cyan, Rouge, Or, Violet ou
Monochrome, logo de la même couleur).

> L'addon est ouvert à tous les joueurs (le réglage `W.GUILD_RESTRICTED` de `Core.lua` permet de le réserver à la guilde **War Legend**).
> Droits réservés : utilisation libre, pas de redistribution modifiée sans accord.

## Installation

Il faut **quatre dossiers** dans `World of Warcraft\_forever_\Interface\AddOns\` :

```
AddOns\
├── WarLegendRaidTool\        noyau (toujours chargé)
├── WarLegendRaidTool_Raid\   modules de raid (chargés à la demande, comme BigWigs)
├── WarLegendRaidTool_PvP\    cadres ennemis / alliés en champ de bataille (chargés à la demande)
└── WarLegendRaidTool_Skyborne\  épingles lignes de force / convergences sur la carte (à la demande)
```

Le plus simple : télécharger le zip de la dernière **Release** (les quatre dossiers sont à la racine) et le
décompresser dans `AddOns`. Avec **WowUp** : *Obtenir des addons → Installer depuis une URL* → adresse de ce dépôt.

## Premier lancement

1. Vérifier que les quatre addons sont cochés dans la liste des addons.
2. `/wl` ouvre la fenêtre. Le chargement des modules de raid se fait tout seul (groupe, donjon, `/wl`),
   celui des cadres PvP en entrant dans un champ de bataille (réglages : `/wl pvp`).
3. Raccourci de rechargement : Échap → Options → Raccourcis → AddOns → WaR LegenD RaidTool.

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
| `/wl maptools` | Outils de la carte du monde (Options > Interface) : coordonnées sous la carte (moi et le curseur), Ctrl + clic pour poser le repère de carte du jeu, rouvrir la carte sur ma zone. Idées d'OpenMap (licence MIT). Rien ne touche aux points des autres addons. |
| `/wl audit` | Journal du trafic de l'addon (messages reçus / refusés / envoyés par préfixe, lignes publiques, pics par minute, travaux les plus lents), enregistré tout seul dans `WTF\Account\...\SavedVariables\WarLegendRaidTool.lua` au `/reload` ou à la sortie (`auditLog.cur`, la session d'avant dans `.prev`). Jamais le texte des messages. Éteint par défaut : `/wl audit on` l'allume, `/wl audit off` l'éteint. |
| `/wl perf` | Mémoire et CPU utilisés par l'addon (et le CPU des modules Raid, PvP et Skyborne quand ils sont chargés), puis ses travaux les plus lents (une exécution) et les plus coûteux (total depuis la connexion) : événements, timers, hooks, avec le fichier et la ligne. |
| `/wl move` | Déplacer les cadres (repris de MoveAny, version sûre) : fenêtres Blizzard à la souris hors combat (Ctrl+molette : taille, place retenue en option), éléments d'écran (texte d'erreur, de zone, emotes de boss, souffle, score du BG, barre de capture, durabilité), infobulle au curseur ou à une ancre, FPS / latence. Les barres d'action, cadres d'unité, buffs et minicarte ne sont pas touchés (EllesmereUI). |
| `/wl cvar` | Options d'interface (reprises d'Advanced Interface Options) : distance max de la caméra, fenêtre de file des sorts, distance et empilement des barres de nom, texte de combat, noms et titres, couleurs de classe dans le chat... et un navigateur de toutes les CVars (chercher, modifier, valeur par défaut). Hors combat seulement ; les valeurs changées ici sont remises à la connexion et vont dans les profils. |
| `/wl ilvl` | Niveaux d'objet (repris de SimpleItemLevel) : sur la fiche de personnage, l'inspection, les sacs, la banque et le butin, niveau moyen sous le modèle, ligne dans les infobulles, flèche sur les objets meilleurs que les miens, « E » sur l'équipement sans enchantement. Inactif si l'addon SimpleItemLevel est chargé. |
| `/wl map` | Carte de guilde (reprise de GuildMap) : les membres de la guilde sur la carte du monde et la minicarte, icône de classe, infobulle (niveau, zone), clic : chuchoter, clic droit : inviter. Ma position est partagée hors donjon / raid / BG (désactivable). Compatible avec les membres qui ont l'addon GuildMap. Onglet **Transports** : bateaux, zeppelins et tramways (icônes sur la carte du monde et la minicarte, horaires d'arrivée et de départ). L'horaire s'apprend en prenant le transport une fois, ou se reçoit de la guilde ; tout s'arrête en champ de bataille, arène et donjon. |
| `/wl layer` | Layers : mon layer (copie du monde ouvert) et celui des membres de la guilde, par zone. Détecté avec les créatures ciblées, survolées ou dont la barre de nom s'affiche (deux créatures doivent être d'accord), partagé avec la guilde (désactivable). Les numéros (Layer 1, 2...) sont donnés par ton ordinateur, zone par zone : ils peuvent différer de ceux d'un autre joueur. Rien en instance, en BG ni en taxi. Clic : sélectionner ; bouton **Inviter sur mon layer** (chuchotement + invitation, seulement vers un membre d'un autre layer de ta zone, lecture de moins de 5 min, pas en combat ni en instance, pas déjà dans ton groupe) ; clic droit : chuchoter. Méthode reprise de WarLegend v3 (Sashoof). |
| `/wl classes` | Classes : la guilde par classe (neuf cartes : membres, en ligne, rôles déclarés, liste au survol), responsable de chaque classe (gardé sur cet ordinateur et dans les profils exportés), **mon profil** (rôle Tank / Heal / DPS, spé, disponibilités) envoyé à la guilde (désactivable). Idée de WarLegend v3 (Sashoof). |
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
| `/wl dashboard` | Tableau de bord de la guilde : tuiles (membres, en ligne, enchants manquants, soirées de raid, loots) et quatre classements : niveau d'objets moyen, enchants manquants, présences, loots reçus. Données déjà présentes sur ton PC (liste de guilde, inspection de raid, présences, Loot Council) ; période réglable pour les loots ; rien n'est envoyé. Les joueurs apparaissent dans les classements d'objets une fois inspectés en raid. |
| `/wl bank` | Stock et or de mes persos banque (ceux de mon compte au rang « Banque »), avec recherche. |
| `/wl craft [objet]` | Qui peut fabriquer cet objet dans la guilde (nom ou lien d'objet avec Maj-clic), artisans en ligne en premier. Sans nom : Guilde > Métiers (premier onglet, puis Recrutement et Inactifs), une ligne par membre et par métier avec son relevé le plus récent (niveau, nombre de recettes), avec des filtres qui se combinent : nom du joueur, menu déroulant (Recette ou objet, Tous les métiers, puis chaque métier), niveau (de - à), recette ou objet. Trois sources, indiquées dans la colonne Source : la liste de guilde du serveur (comme l'onglet Guilde de Retail : 2 métiers principaux, niveau sans maximum, quand le serveur les donne), le WaR LegenD RaidTool du membre (tous ses métiers, niveau/max, recettes une fois le métier ouvert, fenêtre Blizzard ou Naowh ; messages d'addon invisibles, désactivables, jamais de chat) et les liens de métier (Maj-clic sur un lien pendant que l'onglet est ouvert : le métier seulement, un lien ne contient pas le niveau). Données gardées après un redémarrage. Ctrl-clic : chuchoter l'artisan. Tri par clic sur les en-têtes **Nom**, **Métier** ou **Niveau** (encore un clic : dans l'autre sens ; flèche sur la colonne triée, choix retenu ; un niveau inconnu « ? » reste en fin de liste) ; case **Membres en ligne seulement**. Les grandes listes restent fluides : seules les lignes visibles sont dessinées. |
| `/wl bg` | Historique de mes premades de BG, stats par joueur, records par BG (victoires les plus rapides). |
| `/wl mino` | Minotaure (règles de WarLegend v3, Sashoof) : classement JcJ de la guilde par saisons de 28 jours (UTC, à partir du lundi 12 octobre 2026). 5 points par victoire honorable (monde ou BG), 30 par victoire en BG, 200 points par jour au plus ; score sur 100 = 50 × monde / (monde + 200) + 50 × BG / (BG + 200). Défis de la semaine (victoires honorables, victoires et BG joués, victoires selon le rôle déclaré dans Classes), historique de mes saisons. Les totaux des autres membres viennent de leur addon (affichés « déclaré »). |
| `/wl sk` | Skyborne (personnages de race Skyborne seulement) : épingles des lignes de force (Alliance) ou convergences élémentaires (Horde) sur la carte du monde, positions connues + celles que tu trouves (sort racial ou détection sur la minicarte). Réglages dans les options de l'interface du jeu (`/wl sk`) ; `/wl sk export` copie tes positions ; `/wl sk share` état du partage ; partage des repérages (phase, position, heure) avec les autres joueurs de l'addon par un canal caché, **activé par défaut sur les Skyborne** (désactivable dans les réglages). Addon à la demande `WarLegendRaidTool_Skyborne`, basé sur *Skyborne Leyline & Convergence Marker* de tr0tsky (licence MIT). |
| `/wl myslot` | Myslot : sauvegarde et restaure tes barres d'action, macros, raccourcis clavier et réglages, en texte à copier ou en exports nommés (passage d'un personnage ou d'un compte à l'autre). Aussi dans Options > Petits automatismes > Myslot. L'import remplace tes barres : refusé en combat, confirmation de Myslot. Intégré à l'addon (dossier `Myslot`, *Myslot* de Boshi Lian, licence Apache 2.0, données dans `MyslotExports` : désactive l'addon Myslot d'origine s'il est installé). |
| `/wl did` | DoesItDie : marque sur la barre de vie de ta cible (et sur les barres de nom) les dégâts que tes DoT doivent encore faire, icône de mort quand ils vont l'achever. **Éteint par défaut** : Raid > Combat > DoesItDie (case à cocher, affichage sur les barres de nom : rien / marque / marque et icône). `/wl did` ouvre ses options (`/did` aussi). Intégré à l'addon (dossier `DoesItDie`, rien ne tourne tant qu'il est éteint ; l'allumer ou l'éteindre demande un `/reload` ; *DoesItDie* 0.8.3 de Joe Greive, licence MIT, données dans `DoesItDieDB` : désactive l'addon d'origine s'il est installé). |
| `/wl gy` | Active / coupe le test du chrono de cimetière (fausses vagues). |
| `/wl pvp` | Réglages des cadres PvP, par côté (sous-onglets Ennemis / Alliés). Case « Synchro » à leur gauche : un réglage changé s'applique aux deux côtés (les réglages déjà différents restent tels quels). Largeur, hauteur, échelle et hauteur de la barre d'énergie (sous la barre de vie) sont réglables. |
| `/wl pvpcheck` | Vérifie si les restrictions d'addons sont actives dans ce champ de bataille. |
| `/wl caps` | Chronos de BG au style Capping : capture des bases (Darkspear Island, Arathi 1 min, Alterac 5 min), début de la bataille, file d'attente, réapparition du drapeau. Style BigWigs : la barre passe au centre pour ses 5 dernières secondes, avec un gros décompte 5-4-3-2-1 et la voix. Maj-clic : /dire, Ctrl-clic : canal du BG. |
| `/wl danger` | Alerte danger (monde ouvert) : message + son quand un joueur ennemi JcJ, un monstre « tête de mort » ou un élite rouge approche. Option : liste des joueurs ennemis vus (barres de nom, cible, survol ; classe, niveau, guilde, zone, quand ; filtre par classe), gardée sur cet ordinateur (idée : Radar de WarLegend v3, Sashoof). Option : cadres des joueurs ennemis sur le côté de l'écran, comme en BG (nom, couleur de classe, points de vie ; grisés quand ils ne sont plus vus, retirés après 15 s ; 40 au plus ; clic pour cibler, à couper si besoin). |
| `/wl cc` | Grosse icône au centre de l'écran quand vous êtes sous contrôle (étourdi, peur, silence...), avec le temps restant. |
| `/wl duel` | Gros compte à rebours pour les duels façon BigWigs (chiffre animé et voix) : 3, 2, 1, « Combat ! », et les 10 secondes pour revenir quand on sort de la zone de duel. |
| `/wl test` | Teste en même temps tous les modules activés (chronos, duel, cimetière, alertes, cadres de BG, suivi d'auras, ready check en groupe, loot council seul) pour les voir et les déplacer. Aussi le bouton « Tout tester » en haut de la fenêtre. Relancer `/wl test` (ou le bouton, devenu « Arrêter le test ») arrête tout ; aussi `/wl test stop`. |
| `/wl bgmsg` | Derniers messages du champ de bataille, à copier (pour ajouter les textes de drapeau d'un nouveau BG). |

Les erreurs éventuelles s'affichent dans BugSack. Version actuelle : voir `WarLegendRaidTool.toc`.

## Sécurité

- Messages entre addons acceptés seulement du groupe ou de la guilde ; les chuchotements d'inconnus sont refusés, et chaque valeur reçue est bornée (nombres finis, longueurs, nombre d'entrées).
- Import de profil : confirmation qui liste tout ce qui sera changé ; les macros des clics PvP sont filtrées par liste blanche (ciblage et sorts seulement : jamais `/gquit`, `/logout`, `/run`...). Les macros que tu écris toi-même dans les réglages ne sont pas filtrées : tu en es responsable.
- Actions automatiques (invitations, promotions) éteintes par défaut, promotions hors combat seulement ; les annonces publiques partent sur un clic ou une confirmation ; aucun code reçu n'est exécuté.
- Exception : Skyborne partage ses épingles sur le canal caché d'origine (`SLLCM`, ouvert à tous) ; ce qui y arrive est borné (nombres finis, 200 signalements et 100 épingles par carte) et le partage se coupe dans les réglages de Skyborne (`/wl sk`).
- Valeurs « secrètes » du jeu (vie, GUID, cible en combat...) : jamais comparées ni envoyées ; une valeur illisible est traitée comme absente.
- Aucune action protégée en combat : les marques, le placement des groupes, le `/reload` et le ciblage PvP passent par des boutons sécurisés préparés hors combat.
- Essais de guilde, banque de guilde, statistiques de BG, tri du butin, Myslot et DoesItDie n'envoient rien.

## Crédits

- Voix du décompte **Amy**, **David**, **Jim** et police **Noto Sans** : reprises de [BigWigs](https://github.com/BigWigsMods/BigWigs)
  (licences CC BY-NC 3.0 / CC0 / SIL OFL, détail dans `Media/Sounds/Countdown/README.txt` et `Media/Fonts/Noto_license.txt`).
- Scintillements du butin (Options > Interface) : idée de ForeverLootSparkles (Ashtar Senior, GPL-3.0) ; seules les variables de console sont reprises, aucun code.
- Cadres de champ de bataille : basés sur BattleGroundEnemies (Bullsei).
- Carte de guilde : idée et messages de GuildMap (Portalz, Devetik) ; librairie HereBeDragons (Nevcairiel, BSD), détail dans `Libs/README.txt`. Transports : idée et données de routes de NauticusClassicResurrected (psynct, licence MIT).
- **Layers**, **Minotaure**, **Classes**, l'historique d'ennemis de l'alerte danger et les styles **WL v3** (palette, accents, logos
  `Media/WLLogo*.tga`) : repris de l'addon **WarLegend v3** de **Sashoof** (réécrits dans l'architecture de cet addon).
