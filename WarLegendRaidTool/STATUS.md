# STATUS — WarLegend RaidTool

État du travail, mis à jour à la fin de chaque session (voir `AGENTS.md`). Le plus récent en haut.
Pas dans le zip des releases.

## Maintenant (17/10/2026)

- **Version publiée** : 1.27.4 (tag `v1.27.4`). `main` a des commits de plus, **non poussés, non publiés**
  (Guilde > Métiers ci-dessous, et ce STATUS.md) : `git log v1.27.4..main`. Ils partiront avec la prochaine
  release, quand l'utilisateur la demandera.
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

## Pistes ouvertes (audit du 17/10, non corrigées)

- Emplacement 18 (à distance) : `SimExport.lua` dit qu'il n'existe pas sur Forever, `RaidInspect.lua`,
  `ItemLevels.lua` et `LootCouncil.lua` l'utilisent. À vérifier en jeu.
- `W.InspectTalents` (Core) : pas de repli sur l'ancienne API quand `C_Traits` ne rend rien.
- Raid Buffs : buffs signalés manquants sur des joueurs trop loin (le jeu ne les donne pas).
- Readiness : « free » (instances verrouillées) et « item » (banque) peut-être faux chez celui qui répond.
- Focus vs Clique (Maj + clic gauche) ; Raid Inspect vs les autres addons d'inspection.
- Salut deviendra « Salut collectif » sur Forever (note du paladin, pas encore en jeu) : nouvel ID à prendre.

## Historique

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
- **1.27.1 / 1.27.2** (17/10) : l'installation de la 1.27.1 a écrasé une journée de travail faite seulement
  dans le dossier du jeu, restaurée depuis la conversation. Depuis : **on travaille dans le dépôt `C:\Dev`
  et on copie chaque changement dans le dossier AddOns**.
- Versions plus anciennes (1.22.1 à 1.27.0) : `git tag`, `git log`.
