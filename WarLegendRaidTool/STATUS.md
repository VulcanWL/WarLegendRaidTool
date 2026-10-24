# STATUS — WarLegend RaidTool

État du travail, mis à jour à la fin de chaque session (voir `AGENTS.md`). Le plus récent en haut.
Pas dans le zip des releases.

## Maintenant (23/10/2026)

- **Brief de recodage d une IA externe (23/10, branche `claude/wlrt-audit-refactor-453435`, non poussée)** : relu contre le code ; découpage de `Core.lua`, `Locale/`, caches de regex / préfixes refusés (faux ou risqués). Fait : Loot Council, une dette d échange n est effacée que si le jeu dit « Échange terminé » (`UI_INFO_MESSAGE` = `ERR_TRADE_COMPLETE`, comme RCLootCouncil), que l objet était dans MON côté quand j ai accepté (`TRADE_ACCEPT_UPDATE` + `GetTradePlayerItemLink`) et qu une copie a quitté les sacs ; 6 scénarios rejoués sous fengari (banc jetable) : OK (avant : effacée si l objet n était plus dans les sacs, même vendu / déplacé, ou gardée si j en avais une 2e copie) ; README « Sécurité » : Skyborne (canal public), valeurs secrètes, boutons sécurisés. Vérifié : check 0, smoke 0, wow-api 0 nouveau (`GetTradePlayerItemLink` ajouté à la baseline), jeu à jour. **Rien testé en jeu.** Reste possible : `W.Where` dans `W.After` (mesurer avec `--bg` avant), `W.After` annulable (si un module en a besoin).

- **Version publiée (23/10)** : 1.37.0 (tag `v1.37.0`) = DoesItDie et Myslot intégrés au noyau, zip à 4 dossiers.
- **Plus de Classic bêta (23/10, demande de l utilisateur)** : seul `_forever_` est utilisé ; tâche planifiée locale « Veille news WoW Forever » 2 fois par jour, après les resets EU (06:30) et US (17:30), `wowf` seul ; `sync.sh`, `forever-report.js`, veille des builds (`wowf` seul), README, guide joueur, CLAUDE.md, `docs/modules.md` mis à jour ; tickets de veille bêta / anciens builds fermés (restent n° 6 et 8). Ménage des worktrees / branches déjà fusionnés : refusé par le contrôle automatique, à faire par l utilisateur.
- **DoesItDie et Myslot intégrés au noyau (23/10, dans 1.37.0)** : demande de l utilisateur (pas d addons externes). Fichiers d origine dans `WarLegendRaidTool/DoesItDie/` et `WarLegendRaidTool/Myslot/`, listés dans le .toc du noyau ; `W.Space(name)` (`Lib.lua`) remplace la table `...` de l addon (sinon partagée par tous les fichiers du noyau) ; textures DoesItDie via `DoesItDie\Textures` ; SavedVariables `MyslotExports`, `DoesItDieDB` (+ `MyslotSettings` par personnage) dans le .toc du noyau (les anciens fichiers `WarLegendRaidTool_Myslot.lua` / `_DoesItDie.lua` du WTF ne sont plus lus). DoesItDie éteint par défaut : à `ADDON_LOADED`, option éteinte = événements retirés, ses 3 OnUpdate arrêtés (`ns.offFrames`), `/did` dit comment l allumer ; allumer / éteindre = `/reload`. Myslot toujours chargé (LibStub / CallbackHandler du noyau). Zip = 4 dossiers ; anciens dossiers `_Myslot` / `_DoesItDie` supprimés de `_forever_` et `_classic_beta_` (les joueurs WowUp devront peut-être les supprimer). Vérifié : check 0, smoke / open world / BG 0 erreur, éteint = aucun OnUpdate DoesItDie, allumé (forcé le temps d un banc) = 0 erreur, wow-api 0 nouveau. **Rien testé en jeu.**
- **Version publiée (23/10)** : 1.36.1 (tag `v1.36.1`) = perf PvP (boutons précréés, Dispel par signature), release liée aux checks, doc 6 addons, actions/checkout v7 (PR Dependabot n° 5). **Bêta désinstallée par l utilisateur (on attend la sortie du jeu)** : `sync.sh` n a plus de dossier de jeu, rien testé en jeu.
- **Avant (23/10)** : 1.36.0 (tag `v1.36.0`, `main` en avance rapide depuis `claude/loot-triage-4ae37f`) = tri du butin, DoesItDie, Myslot (zip corrigé), recherches avec anti-rebond (branche fps-debounce incluse). Tous les nouveaux modules éteints par défaut. **Rien testé en jeu.**

- **Branche `claude/sweet-mclaren-32208b` (23/10, fusionnée dans `main`, pas de tag)** : PvP, deux coûts du banc `--bg`. `Mainframe.lua` : les 80 boutons sont précréés 2 par image et par côté hors combat dès le chargement (file d attente), cachés dans `InactivePlayerButtons`. `Modules/Dispel.lua` : signature des auras (hauteur, bordure, icônes) ; `Update` ne redessine que si elle change, ré-ancrage seulement si la cible change. Mesuré (ms fengari, avant → après) : pire image à l entrée 175 → 115 (le reste = tri / réglages des 40 boutons au premier tableau des scores) ; minuteur Dispel combat 30 s 343 → 209, churn 238 → 154, mort 114 → 67 ; moyenne combat 2,25 → 2,08. Vérifié : check.js 0, smoke 0, `--bg` 15 / 15, `--open-world` 38 / 38, wow-api 0 nouveau, jeu à jour. **Rien testé en jeu.** À tester : entrée en BG (`/wl perf`), icônes de dissipation alliées qui changent bien, mode test `/wl pvp`.
- **Branche `claude/fps-debounce-gc-optimization-68ba73` (23/10, non poussée, non fusionnée)** : `W.Debounce` (`Lib.lua`) sur les recherches Guilde > Métiers et Banque de guilde (0,25 s) ; plafond d itérations sur le message de métiers reçu (`Guild.lua`) ; avertissement quand la file d envoi pleine jette un message ; README = 5 dossiers. Audits externes du 23/10 relus : `DangerAlert` taint = faux constat (barres et boutons sécurisés frères), `pendingMsgs` repasse par `Dispatch` (sain). Vérifié : check.js 0, smoke 0, wow-api 0 nouveau. **Rien testé en jeu.**
- **Tri du butin (23/10, branche `claude/loot-triage-4ae37f`, non poussée)** : `LootTriage.lua` (nouveau, .toc avant `VersionCheck.lua`, Options > Petits automatismes, clé `lootTriage`, **éteint par défaut**). Sacs pleins : + vert / - rouge sur la fenêtre de butin (vaut plus que mon objet le moins cher), numéros 1-9 sur les objets à jeter, valeur + rang dans l infobulle. Prix : TSM (`dbmarket`), puis Auctionator, puis marchand (choix dans l onglet). Jamais comptés : quête, sans prix, épique+. Code à nous (aucune ligne de LootTriage / cmangos). Limites : un butin qui s empile sur une pile existante est quand même jugé ; poches spéciales ignorées. Vérifié : check.js 0, smoke 0, wow-api 0 nouveau (`GetLootSlotInfo` ajouté à la baseline). **Rien testé en jeu.**
- **DoesItDie intégré (23/10, même branche)** : 6e addon à la demande `WarLegendRaidTool_DoesItDie` (DoesItDie 0.8.3 de Joe Greive, MIT, repris tel quel : LF, sans BOM, textures via le nom d addon) + chargeur `WarLegendRaidTool/DoesItDie.lua` (Raid > Combat, clé `doesItDie`, **éteint par défaut**, chargé à la connexion seulement une fois allumé ; `/wl did` = `/did`). Barres de nom : choix rien / marque / marque + icône dans notre onglet (écrit dans `DoesItDieDB.nameplateMode`, défaut d origine marque + icône). Outils : listes des addons (check, smoke, wow-api, sync, CI, luacheck, release), baseline API (3 noms). **Corrigé au passage** : le zip de release n incluait pas `WarLegendRaidTool_Myslot`. Vérifié : check 0, smoke + open world 38/38 + BG 15/15 0 erreur, wow-api 0 nouveau. **Rien testé en jeu.** À tester : allumer, `/reload`, DoT sur une cible (marque sur la barre de vie, icône de mort), barres de nom avec nos réglages / Platynator / EllesmereUI, `/wl did`.
- (fait ci-dessus) **module « tri du butin » recodé par nous** (idée de LootTriage 1.1.1 de Krelock : sacs pleins, quel butin vaut la place, quoi jeter, le moins cher d abord). LootTriage n a **aucune licence** : ne rien copier de son code ; sa liste d objets de quête vient de cmangos (GPL-3.0) : ne pas la reprendre non plus. Zip d origine : `C:\Users\vulca\Downloads\LootTriage-1.1.1.zip` (pour l idée seulement).

## Avant (22/10/2026)

- **Myslot intégré (22/10, non publié)** : 5e addon à la demande `WarLegendRaidTool_Myslot` (Myslot 6.2.1 de Boshi Lian, Apache-2.0, repris tel quel : libs en `Libs`, LF, seulement `GetAddOnMetadata` du nom d addon et bouton minicarte masqué par défaut) + chargeur `WarLegendRaidTool/Myslot.lua` (`/wl myslot`, onglet Options > Petits automatismes). Données `MyslotExports` / `MyslotSettings` (noms d origine : désactiver l addon Myslot d origine). Choix de l utilisateur : barres + macros, raccourcis, options, exports gardés ; confirmation d origine, refus en combat. Outils : listes des addons (check, smoke, wow-api, sync, CI, release), baseline API (32 noms Myslot), faux `RED_FONT_COLOR`. Vérifié : check.js 0, smoke 0 erreur, wow-api 0 nouveau. **Rien testé en jeu.** À tester : `/reload`, `/wl myslot` (fenêtre), exporter puis réimporter ses barres, macros, raccourcis ; import refusé en combat.
- **Version publiée (22/10)** : 1.35.7 (tag `v1.35.7`) = `VersionCheck.lua` envoie aussi la version à la GUILDE à la connexion (un joueur hors groupe est prévenu d une mise à jour) ; `docs/guide-joueur.md` (guide joueur, 4 addons / 4 onglets). Vérifié : check.js 0, wow-api 0 nouveau, smoke + open world 0 erreur. **Rien testé en jeu.** Aussi : `CapTimers.lua` replace les barres une seule fois quand plusieurs finissent ensemble. Worktrees fusionnés supprimés.

- **Version publiée (22/10)** : 1.35.6 (tag `v1.35.6`) = Loot Council : après un vote on passe à l objet suivant à voter (onglets pour revenir) ; historique dans sa propre clé `lootHistory` (migré depuis `loot.history`). **Rien testé en jeu.**

- **Version publiée (22/10)** : 1.35.5-beta (tag `v1.35.5-beta`, depuis `main`, avance rapide de la branche ci-dessous) = le menu réorganisé. **Rien testé en jeu.**
- **Menu réorganisé (22/10 ; accordéon retiré : toutes les sections visibles sous des légendes, entrées moins indentées ; menu 160 px, lignes 24 px, fenêtre 1000 px)**, branche `claude/unused-tools-inventory-6afaec` : 4 onglets (Raid, JcJ, Guilde, Options) au
  lieu de 3, seulement `CATEGORIES` dans `Core.lua` (clés des modules inchangées) + `openSection_pvp` dans la liste blanche du profil
  (`Settings.lua`) ; README et AGENTS à jour. Raid : Organisation, Préparation, Combat, Butin et présences (+ Dashboard, Essais) ;
  JcJ : Champs de bataille, Monde ouvert (alerte danger, duels, layers) ; Guilde : Minotaure ici ; Options : section « Petits
  automatismes ». Aussi : CI avec bancs open world / BG en jobs parallèles. Vérifié : check.js 0, smoke 0 erreur. **Rien testé en jeu.**
  À tester : `/reload`, les 4 onglets, `/wl pvp` (ouvre l'onglet JcJ), `/wl map`, recherche d'une option, section ouverte retenue.

## Avant (21/10/2026)

- **Version publiée (21/10)** : 1.35.4-beta (tag `v1.35.4-beta`, depuis `main`, avance rapide de la branche ci-dessous) = la fluidité
  en champ de bataille. **Rien testé en jeu.**
- **Fluidité en champ de bataille (21/10)**, branche `claude/nostalgic-jang-b845ed` (worktree), fusionnée dans `main`, dossier du jeu à jour. Banc `node tools/smoke.js --bg` (`tools/smoke/battleground.lua`, ~20 s, ajouté au CI) : Alterac 40
  contre 40, coût de chaque image (moyenne, centiles, pire image et son contenu). Faux client : tableau des scores (`M.scores`,
  `C_PvP.GetScoreInfo`), minuteurs attribués par fichier:ligne, un événement tiré entre deux images compte dans la suivante.
  **Changé** (aucun rafraîchissement en combat ralenti) : PvP `Main.lua` `WarLegendPvP.Spread` = un seul OnUpdate par côté qui
  répartit les boutons sur les images (portée / `UpdateAll` 0,2 s en combat, 0,4 s hors combat ; `Power.lua` 0,25 s ; `NativeAuras.lua`
  0,25 s) au lieu d'un par bouton ; `GROUP_ROSTER_UPDATE` ignoré hors BG / mode test (relu à l'entrée en BG et au mode test), rafales
  regroupées en BG ; `UPDATE_BATTLEFIELD_SCORE` ne reconstruit rien si le tableau n'a pas changé ; tri des joueurs sans `strsplit` à
  chaque comparaison ; `FindPlayerInSource` indexé. Skyborne `Comm.lua` : plaques / cible / survol ignorés en instance.
  `GuildPositions.lua` : une ligne sans changement (place, classe, options) ne replace rien. `/wl perf` montre aussi le CPU des modules
  Raid / PvP / Skyborne chargés (`Core.lua`, README). Mesuré (ms fengari, `HEAD` vs après, même banc) : repos moyenne 0,69 → 0,24,
  pire 14,6 → 2,6 ; combat 30 s moyenne 2,30 → 1,91, pire 16,6 → 5,1 ; mort pire 15,7 → 4,5 ; raid qui change pire 486 → 77 ;
  score 13,0 → 2,2 ms ; `GROUP_ROSTER_UPDATE` hors BG 10,3 → 0,01 ms. Vérifié hors jeu : check.js 0, wow-api 0 nouveau, smoke 2 passes
  0 erreur, open world 37 / 37, BG 15 / 15 (mode test avant / après un BG : mon bouton affiché). Luacheck non lancé ici (CI).
  **Rien testé en jeu.** À tester : Alterac, `/wl perf` (ligne « PvP ») ; cadres alliés / ennemis : portée qui grise, PV, cible, en
  et hors combat ; un joueur qui rejoint / quitte le raid ; `/wl pvp` mode test hors BG (mon bouton présent) ; carte de guilde.
- **Avant (21/10)** : 1.35.3-beta (tag `v1.35.3-beta`, depuis `main`, avance rapide de la branche ci-dessous) = le banc
  open world et ses 3 correctifs (carte de guilde, alerte danger).
- **Banc « open world » (21/10)**, branche `claude/openworld-bench-77ee57` (worktree), fusionnée dans `main`, dossier du jeu à jour.
  `node tools/smoke.js --open-world` (`tools/smoke/openworld.lua`, ~20 s, ajouté au CI) : guilde de 120, raid de 40 hors instance.
  Faux client plus fidèle (`tools/smoke/wow.lua`) : réserves de cadres réutilisées, carte du monde = MapCanvas, protection implicite
  (parent / ancre d'un cadre sécurisé), unités ennemies (`M.units`), monde `M.SetupWorld` (C_Map, UnitPosition, minicarte).
  **Corrigé** : `GuildPositions.lua` laissait un repère de carte actif à chaque position reçue (HereBeDragons ne libère l'ancien qu'au
  rafraîchissement de la carte) : 1 326 repères pour 119 membres après 60 s carte fermée (~50 000 / h), maintenant 1 par membre
  (retrait avant ajout, comme `Transports.lua`). Ensuite (demande de l'utilisateur) : `GuildPositions` garde par expéditeur
  « dans mon groupe ? » (vidé à `GROUP_ROSTER_UPDATE`, redemandé après 2 min) : ligne en raid 0,92 → 0,17 ms fengari en régime établi ;
  `DangerAlert` reprend les barres de nom refusées quand les 40 lignes étaient pleines dès qu'une ligne se libère (`waiting`, `Refill`
  après `Tick` / fin de combat) : 40 lignes pour 40 ennemis après le combat (24 avant). Vérifié hors jeu : check.js 0, wow-api 0
  nouveau, banc 0 erreur (2 passes + open world 37 / 37), mutation détectée (garde de combat retirée → 1 345 actions bloquées).
  **Rien testé en jeu.** Reste sans correctif : PvP chargé = 14 ms fengari par `GROUP_ROSTER_UPDATE` à 40 (x5 vs 10).
  **À tester en jeu** : `/wl perf` en raid de 40 hors instance ; carte du monde ouverte / fermée avec la guilde (`/wl map`, les
  repères suivent les membres, plus de traces à l'ancienne place ; un joueur qui quitte le raid réapparaît sur la carte) ; alerte
  danger, cadres allumés, plus de 40 ennemis puis fin de combat (les refusés arrivent), `/wl test`.
- **Avant (21/10)** : 1.35.2-beta (tag `v1.35.2-beta`, depuis `main` après la fusion de la PR n° 4) = l'audit ci-dessous.
- **Audit complet (21/10)**, branche `claude/audit-warlegend-raid-tool-176431` (worktree), fusionnée dans `main` (PR n° 4), dossier du jeu à jour.
  Corrigé : `CapTimers.lua` (prévision de fin de BG jamais calculée avec les compteurs « texte » :
  `a and s:match()` ne garde qu'une capture), `Layers.lua` (« Inviter sur mon layer » appelait `SendChatMessage`, qui n'existe ici que
  par un shim Blizzard_Deprecated → `W.SendChat`), PvP `Main.lua` (`not type(x) == "table"` toujours faux), PvP `Locales.lua` (plus de
  lien vers le site de traduction de BattleGroundEnemies). Outils ajoutés (non livrés) : `tools/smoke.js` + `tools/smoke/` (banc fengari),
  `tools/wow-api.js` + `api-baseline.txt` (API vs documentation Blizzard de Forever), `tools/deps-watch.js` + `watch.json`,
  `tools/.luacheckrc`, fengari dans `tools/package.json` ; workflows `wlrt-ci.yml`, `wlrt-deps-watch.yml`, `dependabot.yml`,
  `wlrt-build-watch.yml` étendu (résultats API + banc dans l'issue d'un commit UI, checkout épinglé, curl sans arrêt) ; doc `docs/modules.md`
  « Checks and watch ». Vérifié hors jeu : check.js 0, Luacheck 0, wow-api 0 nouveau (147 noms vus), banc 0 erreur sur 2 passes (mutation
  détectée), répétitions à blanc des deux veilles avec un faux `gh`. Les workflows planifiés ne tournent que depuis `main` : à pousser.
  PR n° 4 vers `main` (Auto-fix activé). **Testé en jeu (21/10)** : `/wl bugs` sans erreur ; `/wl perf` sain (3,4 Mo, 0,005 ms par image,
  pic 58 ms au chargement ; en tête : remplissage des onglets `Core.lua:2087` 4,7 ms au plus, voulu) ; `GetBattlefieldTeamInfo` et
  `GetGuildRosterInfo` existent, `IsItemInRange` = nil (seulement dans `UpdateRangeViaItem` du PvP, jamais appelée : sans effet).
  **Reste à tester en jeu** : « Inviter sur mon layer », prévision de fin de BG (`CapTimers`), message PvP sans lien en client français.
- **Veille locale** (note d'une autre session retrouvée dans le dossier du jeu) : tâche planifiée « Veille news WoW Forever » (toutes les 6 h,
  app ouverte requise ; builds `wow_classic_beta` / `wowf`, branche `forever` de Gethe/wow-ui-source, news ; branche `veille/<build>` + `.toc`
  + rapport, sans push). `wlrt-build-watch.yml` a tourné une fois à la main (21/10 08:41) : issues n° 1-3 (builds 70450 / 70245, UI 172a387e) ;
  aucune exécution planifiée vue. Tests gardés pour plus tard : annonces en emote hors instance (clic requis), MoveFrames (`GetFrameStrata`
  secret), Raid Buffs / DangerAlert (valeurs secrètes).
- **Avant (21/10)** : 1.35.1-beta (tag `v1.35.1-beta`) = `MoveFrames.lua` +10 fenêtres (menu Échap, ready check, sacs, options, journal de quêtes flottant, config du chat...), Ctrl + clic droit = remise à zéro, mémoire « jamais / jusqu au /reload / toujours » (`winMemory`, repli sur `savePos`) ; idées de BlizzMove. `MapTools` : infobulles corrigées (tableau de lignes, pas une phrase). Testé en jeu par l utilisateur : OK. Un plantage client (BREAKPOINT, sans addon en cause) a eu lieu à 19:51, non reproduit.
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

- **Audit externe du 23/10 (sur 1.36.0)** : fait (poussé sur `main`, pas de tag) : README arbre à 6 dossiers, guide joueur (6 addons, fichiers Myslot / DoesItDie à sauvegarder), **release liée aux checks** (`wlrt-release.yml` appelle `wlrt-ci.yml` en `workflow_call`, `needs: checks` ; la CI ne tourne plus seule sur les tags). Restent : campagne de tests en jeu (fiche par testeur) ; pic d entrée en BG (création des 80 boutons, `Mainframe.lua`) ; `Dispel.lua` redessin seulement si les auras changent ; DoesItDie : 3 OnUpdate au repos (code d origine) ; recherche du menu qui construit tous les panneaux (`Core.lua` ~2078) ; licence GPL du module PvP ; dette (métiers en 3 copies, découpage, libs à jour).

- **Banc BG du 21/10, pistes** : `Dispel.lua` (alliés) = maintenant le premier coût en combat (~la moitié de l'image moyenne) :
  `UNIT_AURA` → bouton par le nom, puis `f:Update` toutes les 0,2 s par allié qui ré-ancre le cadre et toutes les icônes même sans
  changement (le faux client ne rend aucune aura : coût réel sans doute plus haut) ; création des 40 boutons ennemis d'un coup au
  premier tableau des scores (~150 ms fengari, hors combat, début de BG). Banc open world : (a) (b) (c) (d) faits le 21/10.

- **Audit du 21/10, à décider** : (1) fait le 21/10 (banc BG) ; (2) LibRangeCheck-3.0 : MINOR 28, amont 38 ; HereBeDragons
  « -gm » 33, amont 35 ; (3) métiers lus en 3 copies (Alts, Guild, SimExport) : seule Guild a le repli Classic `GetSkillLineInfo` →
  une fonction partagée ; (4) PvP : `UpdateRangeViaItem` (code mort, `IsItemInRange` absent de Forever) peut être retirée ; (5) release : faire dépendre le zip de check.js + Luacheck ; (6) Skyborne : hébergement amont inconnu (veille manuelle).

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

- **1.35.6** (22/10) : Loot Council, après un vote on passe à l objet suivant ; historique du butin dans `lootHistory`.
- **1.35.5-beta** (22/10) : menu en 4 onglets (Raid, JcJ, Guilde, Options) sans accordéon, menu 160 px ; CI avec bancs en parallèle.
- **1.35.4-beta** (21/10) : banc champ de bataille (`--bg`, coût par image) ; cadres PvP plus fluides (un OnUpdate par côté, groupe
  non lu hors BG, tableau des scores inchangé = rien reconstruit) ; Skyborne muet en instance ; carte de guilde ; `/wl perf` + modules.
- Versions plus anciennes : `git tag`, `git log`.
