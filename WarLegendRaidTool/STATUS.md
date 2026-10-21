# STATUS — WarLegend RaidTool

État du travail, mis à jour à la fin de chaque session (voir `AGENTS.md`). Le plus récent en haut.
Pas dans le zip des releases.

## Maintenant (21/10/2026)

- **Audit complet (21/10)**, branche `claude/audit-warlegend-raid-tool-176431` (worktree), **rien de commité ni poussé**, dossier du jeu à jour.
  Corrigé, **rien testé en jeu** : `CapTimers.lua` (prévision de fin de BG jamais calculée avec les compteurs « texte » :
  `a and s:match()` ne garde qu'une capture), `Layers.lua` (« Inviter sur mon layer » appelait `SendChatMessage`, qui n'existe ici que
  par un shim Blizzard_Deprecated → `W.SendChat`), PvP `Main.lua` (`not type(x) == "table"` toujours faux), PvP `Locales.lua` (plus de
  lien vers le site de traduction de BattleGroundEnemies). Outils ajoutés (non livrés) : `tools/smoke.js` + `tools/smoke/` (banc fengari),
  `tools/wow-api.js` + `api-baseline.txt` (API vs documentation Blizzard de Forever), `tools/deps-watch.js` + `watch.json`,
  `tools/.luacheckrc`, fengari dans `tools/package.json` ; workflows `wlrt-ci.yml`, `wlrt-deps-watch.yml`, `dependabot.yml`,
  `wlrt-build-watch.yml` étendu (résultats API + banc dans l'issue d'un commit UI, checkout épinglé, curl sans arrêt) ; doc `docs/modules.md`
  « Checks and watch ». Vérifié hors jeu : check.js 0, Luacheck 0, wow-api 0 nouveau (147 noms vus), banc 0 erreur sur 2 passes (mutation
  détectée), répétitions à blanc des deux veilles avec un faux `gh`. Les workflows planifiés ne tournent que depuis `main` : à pousser.
- **Veille locale** (note d'une autre session retrouvée dans le dossier du jeu) : tâche planifiée « Veille news WoW Forever » (toutes les 6 h,
  app ouverte requise ; builds `wow_classic_beta` / `wowf`, branche `forever` de Gethe/wow-ui-source, news ; branche `veille/<build>` + `.toc`
  + rapport, sans push). `wlrt-build-watch.yml` a tourné une fois à la main (21/10 08:41) : issues n° 1-3 (builds 70450 / 70245, UI 172a387e) ;
  aucune exécution planifiée vue. Tests gardés pour plus tard : annonces en emote hors instance (clic requis), MoveFrames (`GetFrameStrata`
  secret), Raid Buffs / DangerAlert (valeurs secrètes).
- **Version publiée (21/10)** : 1.35.1-beta (tag `v1.35.1-beta`) = `MoveFrames.lua` +10 fenêtres (menu Échap, ready check, sacs, options, journal de quêtes flottant, config du chat...), Ctrl + clic droit = remise à zéro, mémoire « jamais / jusqu au /reload / toujours » (`winMemory`, repli sur `savePos`) ; idées de BlizzMove. `MapTools` : infobulles corrigées (tableau de lignes, pas une phrase). Testé en jeu par l utilisateur : OK. Un plantage client (BREAKPOINT, sans addon en cause) a eu lieu à 19:51, non reproduit.
- **Avant (21/10)** : 1.35.0-beta (tag `v1.35.0-beta`) = `MapTools.lua` (coordonnées sous la carte du monde, Ctrl + clic = repère,
  rouvrir la carte sur ma zone ; idées d'OpenMap, MIT ; `/wl maptools` ; testé en jeu : coordonnées et Ctrl + clic OK, points de guilde /
  Overlord / Skyborne OK) + journal d'audit (ci-dessous), **éteint par défaut pour les joueurs** (`/wl audit on` ; allumé chez l'auteur).
  Pas encore vu : pic CPU de 85 ms au lancement du jeu (cause inconnue, accroches de MapTools mesurées par `W.Timed`).
- **Dans 1.35.0-beta** : `Audit.lua` (nouveau, dans le .toc avant `VersionCheck.lua`) + crochet dans `Dispatch` de `Core.lua` : journal
  automatique du trafic (reçus / refusés avec la raison / envoyés par préfixe, lignes publiques, pic par minute, travaux les plus
  lents, mémoire, CPU), métadonnées seulement, dans `WarLegendRaidToolDB.auditLog.cur` (`.prev` = session d'avant), écrit par le jeu
  au `/reload` ou à la sortie. `/wl audit` (résumé), `/wl audit off`. `check.js` 0 problème, jeu à jour, **rien testé en jeu**.
  Audit du 21/10 (sans raid) : banc fengari hors dépôt (API WoW simulée, 18 préfixes × 400 messages hostiles + 6 sondes de flood) :
  0 erreur Lua, chuchotements d'inconnus refusés, amplification bornée (au pire 30 réponses / 300 requêtes, ≈ 1 / 10 s, sur
  `WLRT_INSQ` et `WLRT_VERQ`). Relus : récepteur Skyborne, import de profil (macros en liste blanche, aucun texte de `main`
  vers le chat), conditions de Blizzard (aucune pub / don, annonces éteintes par défaut). Perf mesurée en jeu : rien d'anormal
  (le minuteur `Core.lua:2087` = remplissage des onglets, voulu). **Pas encore vu : du trafic réel d'autres joueurs** (le journal
  ne l'a vu que lui-même) ; le banc est dans le scratchpad, à copier dans `tools/` si on le garde.
- **Version publiée (20/10)** : 1.34.1-beta (tag `v1.34.1-beta`) = correctifs de sécurité « confiance zéro » (puce suivante), sur 1.34.0-beta (Skyborne, audit externe n°2, textes « WaR LegenD »). **Rien testé en jeu.**
- **Inclus dans 1.34.1-beta (audit sécurité « confiance zéro »)** : failles présentes dans 1.34.0, corrigées ici. Import de
  profil : macros des clics PvP filtrées par **liste blanche** `MACRO_CMDS` (ciblage / sorts ; avant, /gquit, /gdisband, /gleader,
  /gremove, /logout passaient) et lignes sans « / » retirées des clics (dites en /say) (`Settings.lua`) ; noms des macros d'assist sans
  `[ ] ; ,` + groupe `nan` refusé (`RaidGroups.lua`) ; Layers répond à « ? » 1 fois / min (amplification) ; Readiness : 1 réponse / 5 s
  (or lu par dichotomie) et ids bornés ; Loot Council : nombre d'objets entier, CSV soft-res sans `nan` (erreur Lua), noms ≤ 40 ;
  Guild : niveaux de métier bornés ; **Skyborne** (canal public) : nombres finis, 200 signalements / carte, 100 épingles apprises /
  carte (avant : sans limite, gardées pour toujours), file d'envoi 60, réponse à « Q » 1 fois / min / phase. Vérifié sain : répartiteur
  des messages (groupe / guilde seulement), Loot Council, !sr, presets reçus, métiers, Summon, invitations, annonces (toujours sur
  clic ou confirmation). Règles dans `docs/modules.md`. `check.js` 0 problème, jeu à jour, **rien testé en jeu**.

- **Inclus dans 1.34.0-beta (Skyborne)** : 4e addon à la demande `WarLegendRaidTool_Skyborne` (port de Skyborne Leyline & Convergence
  Marker 0.4.1, tr0tsky, MIT) : épingles lignes de force / convergences sur la carte, détection minicarte, partage par le canal caché
  d'origine (`SLLCM`, allumé par défaut), `/wl sk` ; chargeur `Skyborne.lua`. Ajouté à `.gitignore`, `sync.sh`, `check.js`, workflow.
  `check.js` 0 problème ; **rien testé en jeu**. À tester : perso Skyborne, `/reload`, carte du monde, `/wl sk`, `/wl sk share`.
- **Inclus dans 1.34.0-beta (audit externe n°2)** : corrigé : import de profil (nombres finis et ≤ 1e12 car les dates valent ~1,8e9, chaînes ≤ 20 000, 20 000 entrées
  au plus, noms de champs ≤ 40, réglages PvP fusionnés clé par clé au lieu de remplacer le fichier, `Settings.lua`) ; `W.Finite` / `W.Int`
  (`Lib.lua`) appliqués à ReadyCheck, GuildPositions, RaidCooldowns, RaidInspect, Checklist (100 objets au plus) ; fragments de preset
  renvoyés si throttle / chat verrouillé (le verrouillage d'un boss ne compte pas), file vidée + message si échec (`RaidGroups.lua`) ; repli talents d'inspection (`Core.lua`) ;
  Raid Buffs ignore les joueurs non visibles / hors portée, sous `pcall` (valeurs secrètes), (`RaidBuffs.lua`) ; repli talents gardé seulement s'il trouve des points. Limite connue : un preset partagé juste avant un pull peut arriver incomplet (le receveur jette un transfert après 60 s). Relecture complète du diff faite le 20/10. Déjà fait : zip sans AGENTS / STATUS / tests LibStub
  (workflow). `CanLead()` gardé tel quel (choix de l'utilisateur). Pas touché : partages par défaut, GPL du module PvP (BattleGroundEnemies
  est en GPLv3 : à décider, licence ou accord écrit de l'auteur), découpage des gros fichiers, tickers PvP, chargement à la demande.
  À confirmer en jeu : en-tête des raccourcis PvP (`header="WarLegendPvP"` sans global), emplacement 18. `check.js` 0 problème, jeu à jour, **rien testé en jeu**.
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

- **Audit du 21/10, à décider** : (1) PvP : `WarLegendPvP:GROUP_ROSTER_UPDATE` recalcule tous les alliés à chaque événement, même hors BG
  une fois l'addon PvP chargé (le plus coûteux du banc) → ignorer hors BG ; (2) LibRangeCheck-3.0 : MINOR 28, amont 38 ; HereBeDragons
  « -gm » 33, amont 35 ; (3) métiers lus en 3 copies (Alts, Guild, SimExport) : seule Guild a le repli Classic `GetSkillLineInfo` →
  une fonction partagée ; (4) en jeu : `/run print(GetBattlefieldTeamInfo, GetGuildRosterInfo, IsItemInRange)` (fonctions non
  documentées) ; (5) release : faire dépendre le zip de check.js + Luacheck ; (6) Skyborne : hébergement amont inconnu (veille manuelle).

- **À faire plus tard (demande du 20/10)** : intégrer des images dans l'addon. Rien n'est fait. À préciser dans une nouvelle
  session : quelles images (logo, fond de fenêtre, icônes, bouton minicarte), où sont les fichiers (dossier, format, taille),
  remplacer l'existant (`Media/Logo*.tga`, `WLLogo*.tga`, `W.LOGO_TEX` dans `Core.lua`) ou s'ajouter. Contraintes : `.tga` / `.blp`,
  dimensions en puissance de 2, `git add` du fichier pour `sync.sh`, relance complète du jeu pour voir un nouveau fichier.
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

- **1.35.1-beta** (21/10) : MoveFrames (+10 fenêtres, Ctrl + clic droit, mémoire en 3 modes), MapTools (infobulles).
- **1.35.0-beta** (21/10) : MapTools (outils de carte), journal d'audit `/wl audit`, audit sans raid (banc fengari, 0 erreur).
- **1.34.1-beta** (20/10) : correctifs de sécurité (macros d'import en liste blanche, canal Skyborne plafonné, Readiness, Layers, Loot Council).
- **1.34.0-beta** (20/10) : addon Skyborne, audit externe n°2, textes « WaR LegenD ».
- Versions plus anciennes : `git tag`, `git log`.
