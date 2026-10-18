# STATUS — WarLegend RaidTool

État du travail, mis à jour à la fin de chaque session (voir `AGENTS.md`). Le plus récent en haut.
Pas dans le zip des releases.

## Maintenant (17/10/2026)

- **Version publiée** : 1.27.5 (tag `v1.27.5`, 17/10) : Guilde > Métiers, harmonisation des menus, mode synchro
  des Champs de bataille, outillage (`tools/`). Rien de non poussé sur `main`. **Rien de tout ça n'est encore testé en jeu.**
- **Fonctionnalité en cours** : Guilde > Métiers, façon onglet Guilde de Retail.
- **Fichiers** : `Guild.lua` (tout le module), `Settings.lua` (`profMin` / `profMax` hors des profils),
  `README.md` (ligne `/wl craft`).
- **Décisions prises** :
  - Trois sources réelles, rien n'est simulé :
    1. liste de guilde du serveur via `C_Club.GetMemberInfo` (`profession1/2ID`, `Rank`, `Name` : documenté
       dans la branche `forever` de Gethe/wow-ui-source) : 2 métiers principaux, sans maximum ;
    2. le WarLegend RaidTool du membre (messages d'addon `WLRT_PROF` vers GUILD, invisibles, désactivables
       par l'option `profShare`, jamais de chat) : tous les métiers, niveau/max, recettes ;
    3. liens de métier (Maj-clic) : `|Htrade:GUID:sort:skillLine|h` ne contient **pas** de niveau, donc métier seul.
  - Métiers identifiés par leur skill line ID (171 Alchimie...), jamais par le nom affiché : FR et EN
    fonctionnent pareil. « Premiers soins » (nom du lien FR) = Secourisme.
  - Membres identifiés par leur nom complet en minuscules (`W.Key`). Les anciennes entrées du même joueur
    (prénom seul, ancienne clé) sont fusionnées dès que la liste de guilde est connue (`G.Consolidate`) :
    par métier, le relevé le plus récent gagne. Un prénom ambigu n'est ni fusionné ni affiché.
  - Lecture de mes métiers : un délai de 30 s **par métier** et l'événement `TRADE_SKILL_DATA_SOURCE_CHANGED`.
    La fenêtre de Naowh (comme celle de Blizzard) change de métier sans se fermer : c'était le bug.
  - Onglets : Métiers, Recrutement, Inactifs. Filtre de métier en menu déroulant (`MenuUtil`, comme Naowh) :
    « Recette ou objet », « Tous les métiers », puis les 12 métiers.
- **Vérifié** : syntaxe des 68 fichiers (luaparse 5.1), traductions de `Guild.lua` (77 textes), 3 tests
  simulés avec fengari (79 vérifications, scripts fengari dans un scratchpad, pas dans le dépôt).
- **Outillage (17/10, non commité)** : `tools/check.js` (toutes les vérifications, 0 problème sur 68 fichiers),
  `tools/sync.sh` (copie vers le jeu, saute un fichier modifié seulement là-bas), `CLAUDE.md` racine (charge
  AGENTS.md + STATUS.md), `docs/modules.md` (détail sorti d'AGENTS.md), règle « même session ou nouvelle ».
  Ouvrir désormais les sessions dans `C:\Dev\WarLegendRaidTool`.
- **Prochaine étape** : test en jeu par l'utilisateur (`/reload`, puis Guilde > Métiers) :
  - le serveur Forever remplit-il vraiment `profession1ID` / `Rank` (lignes « Liste ») ?
  - en passant d'un métier à l'autre dans la fenêtre Naowh, une ligne « Métiers : ... enregistré » s'affiche-t-elle ?
  - une seule ligne par métier pour Vulcan Wl, et le menu déroulant s'ouvre-t-il ?
  - le Ctrl-clic chuchote-t-il un « Prénom Nom » ?
  Puis, si l'utilisateur le demande : version 1.27.5 + tag.

## Harmonisation des menus (17/10, 1.27.5)

- **Fichiers** : `Lib.lua` (`W.Cycle`), `Core.lua` (`CATEGORIES`, `OpenKey`, en-tête), `Settings.lua` (`SKIP_FIELDS.ui`),
  `AGENTS.md`.
- **Fait** :
  - Guilde et Options ont les sections repliables « + / - » de Raid (`accordion = true`, une ouverte à la fois).
    Chaque onglet garde sa section ouverte : `ui.openSection` (Raid, clé inchangée), `ui.openSection_me`,
    `ui.openSection_options` (hors des profils).
  - `W.Cycle` = menu déroulant `MenuUtil` (boutons radio, flèche comme le filtre Guilde > Métiers) ; sans `MenuUtil`,
    un clic passe à la valeur suivante comme avant. Tous les choix à clic de l'addon (29 appels : Guilde, Options,
    Raid, JcJ) en profitent, dont le style de la fenêtre et le style des cadres JcJ.
  - En-tête : la langue FR/EN est aussi un menu déroulant ; style / langue : pas de popup de rechargement si on
    choisit la valeur actuelle.
  - Style : appliqué à `ADDON_LOADED` (`W.ResolveTheme`), lu par chaque widget à sa construction, aucun module ne le
    met en cache au chargement : après `/reload`, il vaut partout (y compris addons _Raid / _PvP). Les cadres JcJ ont
    leur propre style, par côté (choix existant, gardé).
- **Vérifié** : `node tools/check.js` 0 problème, `bash tools/sync.sh` fait. **Pas testé en jeu.**
- **À tester** : `/reload`, `/wl` : sections Guilde / Options repliables, un menu déroulant (ex. Guilde > Recrutement
  intervalle, Options > Niveaux d'objet), style et langue de l'en-tête, puis un changement de style vérifié dans
  plusieurs fenêtres.

## Champs de bataille : mode synchro (17/10, 1.27.5)

- **Fichier** : `PvP.lua` seulement (`BuildSide` : fonction locale `Set`, case à gauche des sous-onglets).
- **Fait** : case « Synchro » à gauche d'Ennemis / Alliés (les deux boutons décalés à x = 104). Active : chaque
  réglage par côté est aussi écrit sur l'autre côté (couleur de barre copiée, une table par côté), sauf le clic de
  dissipation (alliés seulement). À l'activation rien n'est copié (choix de l'utilisateur). Option scalaire
  `pvp.syncSides` (défaut `false`), donc pas de `TABLE_FIELDS`.
- **Vérifié** : `node tools/check.js` 0 problème, `bash tools/sync.sh` fait. **Pas testé en jeu.**
- **À tester** : `/reload`, `/wl` > Champs de bataille : cocher Synchro, changer un réglage dans Ennemis, ouvrir
  Alliés (même valeur) ; décocher, vérifier qu'un changement ne touche plus qu'un côté ; mode test pour voir les cadres.

## Pistes ouvertes (audit du 17/10, non corrigées)

- Emplacement 18 (à distance) : `SimExport.lua` dit qu'il n'existe pas sur Forever, `RaidInspect.lua`,
  `ItemLevels.lua` et `LootCouncil.lua` l'utilisent. À vérifier en jeu.
- `W.InspectTalents` (Core) : pas de repli sur l'ancienne API quand `C_Traits` ne rend rien.
- Raid Buffs : buffs signalés manquants sur des joueurs trop loin (le jeu ne les donne pas).
- Readiness : « free » (instances verrouillées) et « item » (banque) peut-être faux chez celui qui répond.
- Focus vs Clique (Maj + clic gauche) ; Raid Inspect vs les autres addons d'inspection.
- Salut deviendra « Salut collectif » sur Forever (note du paladin, pas encore en jeu) : nouvel ID à prendre.

## Historique

- **1.27.5** (17/10) : Guilde > Métiers (liste de guilde, messages d'addon, liens de métier), sections repliables
  et menus déroulants dans les trois onglets, case « Synchro » Ennemis / Alliés dans Champs de bataille.
- **1.27.4** (17/10) : corrections de l'audit de compatibilité :
  - Readiness : réponses en chuchotement ;
  - CD de raid : annonce après un /reload, option de partage respectée, pierre d'âme / Ankh ;
  - Raid Buffs : niveaux, et buffs inutiles selon la classe ;
  - tri auto avec les main tanks ;
  - PvP Dispel : suit les sorts appris ;
  - Danger alert : un son par type toutes les 10 s.
  Plus les notes de classes Forever : Rois et Esprit divin deviennent des sorts de base, Sanctuaire est retiré.
- **1.27.3** (17/10) : niveaux d'objet de l'inspection qui fermaient l'infobulle ; la valeur de CVar suit
  les changements faits ailleurs.
- Versions plus anciennes (1.22.1 à 1.27.2) : `git tag`, `git log`.
