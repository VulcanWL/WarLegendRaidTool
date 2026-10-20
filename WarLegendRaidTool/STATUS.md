# STATUS — WarLegend RaidTool

État du travail, mis à jour à la fin de chaque session (voir `AGENTS.md`). Le plus récent en haut.
Pas dans le zip des releases.

## Maintenant (19/10/2026)

- **Version publiée** : 1.33.0-beta (tag `v1.33.0-beta`) : fenêtre redimensionnable (coin en bas à droite, échelle 0,8 à 1,6,
  `ui.scale`, `W.SetWindowScale` dans `Core.lua`) + option « taille de la fenêtre et du texte » (Réglages > Général, 90 à 150 %) ;
  plafond de 200 fragments sur la file de partage des presets (`RaidGroups.lua`) ; Loot Council : `LC.CanUse` lit la ligne
  « Classes : … » de l'infobulle (jetons de tier). Le zoom agrandit toute la fenêtre d'un bloc (les modules ont des positions fixes,
  la police seule n'est pas changée). **Rien testé en jeu.** Audit externe (ZIP) analysé : rien d'autre à corriger.
- 1.32.0-beta : Layers, bouton « Inviter sur mon layer » (clic gauche = sélection, clic droit = chuchoter), **rien testé en jeu**.
  Radar / distance des barres de nom : inchangé (plafond du jeu 41 ; test `/run SetCVar("nameplateMaxDistance",60)` à faire).
- Avant : 1.31.0-beta (tag `v1.31.0-beta`, depuis `main`, publiée pour que la guilde teste) : cadres des
  joueurs ennemis en monde ouvert dans l'Alerte danger (`DangerAlert.lua`, option `frames` éteinte par défaut, `framesClick` allumée, `framesPoint` dans
  `TABLE_FIELDS` de `Settings.lua`, README, `docs/modules.md`). Cadres légers à nous, PAS l'addon PvP (jamais chargé
  pour ça). Choix de l'utilisateur : 40 au plus (2 colonnes de 20), nom + couleur de classe + PV seulement, grisé puis
  retiré après 15 s, clic pour cibler (`/targetexact`, boutons sécurisés ancrés au conteneur, changés hors combat
  seulement ; en combat une ligne cliquable reste grise jusqu'à la fin du combat, un nouvel ennemi devient cliquable
  après). Événements actifs seulement option allumée et hors instance ; `UNIT_HEALTH` seulement s'il y a des lignes ;
  vie dessinée 5 fois / s au plus ; une vérification / s des lignes affichées. Valeurs secrètes jamais comparées.
  Vérifié hors jeu : `check.js` 0 problème ; banc fengari (scratchpad, non gardé) : aucune action protégée en combat,
  plafond 40 (84 cadres créés en tout), mort / instance vident tout, aucun gestionnaire actif en instance.
  **Rien testé en jeu.** Ensuite : retours de la guilde (Test, clic en / hors combat, `/wl perf`, vie = nombre ou %).
- **1.30.0-beta** = la fusion avec l'addon WarLegend v3 de Sashoof (son accord est obtenu), faite d'abord dans le projet
  séparé `C:\Dev\WarLegendRaidTool Merge`, puis rapatriée ici ; le numéro continue de monter pour WowUp-CF.
- **Ménage** : branche `tools/local-ai-bug-mode` supprimée (contenu sur `main`), dossier Merge supprimé (bêtas et
  sauvegarde `backup\` de l'addon 1.29.1 et des SavedVariables, à la demande de l'utilisateur). Anciennes Releases et tags
  GitHub gardés. L'addon WarLegend v3 de Sashoof est à retirer du jeu par l'utilisateur.
- **Vérifié hors jeu** (sessions Merge du 19/10) : `check.js` 0 problème (75 fichiers) ; démarrage réel sous fengari
  (9 styles + WarLegend v3), tests de sécurité 17 / 17, file BG 11 / 11, modules 44 / 44, tri des métiers 21 / 21.
  Bancs fengari non conservés. **Rien n'est testé dans le vrai client.**
- **À tester en jeu** : `/reload` puis `/wl bugs` (aucune erreur) ; `/wl perf` (une capitale, avec / sans Layers ; en
  raid aucune ligne Layers / DangerAlert ; pic des cadres de BG au moment où la file s'ouvre) ; Guilde > Métiers (tri
  Nom / Métier / Niveau, « Membres en ligne seulement », défilement des autres tableaux) ; style « WL v3 Or » ;
  `/wl layer` (GUID de créature lisibles sur Forever ?), `/wl classes`, `/wl mino` ; liste d'ennemis de l'alerte
  danger ; import de profil (macros `/run` retirées, confirmation complète) ; « !sr » limité à 3 réponses / 10 s.
- **Décision en attente** : partages activés par défaut (position, layer, Minotaure, métiers).
- **Règle** : après chaque changement, `bash tools/sync.sh` puis confirmer que le dossier du jeu est à jour ; jamais de tag
  avec le jeu en retard. Erreurs Lua : `/wl bugs` ou `!BugGrabber.lua` dans les SavedVariables.

## Pistes ouvertes (audit du 17/10, non corrigées)

- Emplacement 18 (à distance) : `SimExport.lua` dit qu'il n'existe pas sur Forever, `RaidInspect.lua`,
  `ItemLevels.lua` et `LootCouncil.lua` l'utilisent. À vérifier en jeu.
- `W.InspectTalents` (Core) : pas de repli sur l'ancienne API quand `C_Traits` ne rend rien.
- Raid Buffs : buffs signalés manquants sur des joueurs trop loin (le jeu ne les donne pas).
- Readiness : « free » (instances verrouillées) et « item » (banque) peut-être faux chez celui qui répond.
- Focus vs Clique (Maj + clic gauche) ; Raid Inspect vs les autres addons d'inspection.
- Salut deviendra « Salut collectif » sur Forever (note du paladin, pas encore en jeu) : nouvel ID à prendre.
- 1.28.0 jamais testé en jeu : tableau de bord (pièces de set, gemmes), échange du Loot Council, `/wl` avec WoWHead Looter.
- Transports (1.28.3) : icône, `UnitOnTaxi`, `GetServerTime`, déclencheurs à vérifier en jeu.

## Historique

- **1.33.0-beta** (19/10) : fenêtre redimensionnable + taille, plafond de la file des presets, Loot Council (Classes).
- **1.32.0-beta** (19/10) : Layers, bouton « Inviter sur mon layer » (voir Maintenant).
- **1.31.0-beta** (19/10) : cadres des joueurs ennemis en monde ouvert (Alerte danger, 40 au plus, clic pour cibler).
- **1.30.0-beta** (19/10) : fusion WarLegend v3 (styles WL v3 + logos `Media/WLLogo*.tga`, `Layers.lua`,
  `Classes.lua`, `Minotaure.lua`, liste des ennemis vus de l'alerte danger, invitation sur mot-clé coupée si WarLegend v3
  invite déjà) ; performances (Layers et alerte danger coupés en instance, Layers allégé, cadres de BG chargés quand la
  file s'ouvre) ; audit de sécurité (import de profil sans macros exécutables, noms de presets nettoyés, fenêtres de la
  carte de guilde recyclées, « !sr » limité) ; Guilde > Métiers triable + filtre en ligne ; `W.Table` ne crée que les
  lignes visibles.
- Versions plus anciennes : `git tag`, `git log`.
