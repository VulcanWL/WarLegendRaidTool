// Builds the benchmark prompts from the repo (read only) into ./cases. Seeded bugs are applied to in-memory copies.
"use strict";
const fs = require("fs");
const path = require("path");
const REPO = path.resolve(__dirname, "..", "..", "WarLegendRaidTool");
const OUT = path.join(__dirname, "cases");
const read = (f) => fs.readFileSync(path.join(REPO, f), "utf8").replace(/\r\n/g, "\n");
const numbered = (src, from = 1) => src.split("\n").map((l, i) => String(i + from).padStart(4) + ": " + l).join("\n");
function seed(src, pairs) {
    for (const [a, b] of pairs) {
        if (!src.includes(a)) throw new Error("seed not found: " + a);
        src = src.replace(a, b);
    }
    return src;
}
const lines = (src, a, b) => src.split("\n").slice(a - 1, b).join("\n");

const RULES = `Contexte : addon World of Warcraft Classic "WarLegendRaidTool" (Lua 5.1 de WoW).
Règles du projet (extrait de AGENTS.md) :
- Lua 5.1 : pas de goto, pas de //, pas d'opérateurs bit à bit, pas de table.unpack (utiliser unpack).
- Ne jamais inventer d'API WoW ; une API incertaine est gardée : if C_X and C_X.Y then ... end.
- Les frames sécurisées / actions protégées ne peuvent pas changer en combat : tester InCombatLockdown() d'abord.
- Chaque fichier : local W = WLRT ; local L = W.L ; local db. Données : W.OnReady(function() db = W.DB("cle", { defauts scalaires }) end).
- Événements : W.On("EVENT", fn, always, inactive) renvoie un handler ; inactive = true le démarre éteint, W.Activate(handler, on) l'allume.
  always = true : s'exécute même si le joueur n'est pas dans la guilde (réservé au cœur de l'addon). Sinon les handlers ne tournent que si W.Allowed().
- Textes visibles : L("English text") est un APPEL de fonction, jamais L["..."]. Le français va dans W.AddFR({...}) du même fichier.
  La langue n'est connue qu'à ADDON_LOADED : appeler L() dans les fonctions de construction / handlers / W.OnReady, pas au chargement du fichier.
- Nouvelle commande /wl : W.slash.nom dans le module, + liste HELP de Core.lua (avec texte français), + tableau "Commandes" de README.md.
- Outils : node tools/check.js (vérifications), bash tools/sync.sh (copie vers le dossier du jeu). Pas de bump de version sans demande.
Réponds en français.`;

const BUGFMT = `Tâche : relis ce fichier et liste les VRAIS bugs (plantage, comportement faux, violation des règles du projet).
Pour chaque bug : numéro de ligne, explication courte, correction proposée (code).
N'invente pas de bug : si le code est correct, réponds "Aucun bug trouvé". Ne liste pas de simples remarques de style.`;

const cases = [];
function add(id, kind, title, prompt, key) { cases.push({ id, kind, title, prompt, key }); }

// ---------- Comprehension ----------
const core = read("Core.lua");
const autolog = read("AutoLog.lua");
add("C1", "comprehension", "Handler inactif de AutoLog (W.On / W.Activate / Sync)",
    `${RULES}\n\nExtrait de Core.lua (lignes 124-185) :\n${numbered(lines(core, 124, 185), 124)}\n\nFichier AutoLog.lua :\n${numbered(autolog)}\n\n` +
    `Question : explique précisément comment le handler PLAYER_TARGET_CHANGED de AutoLog.lua est allumé et éteint, dans quelles conditions, ` +
    `ce que deviennent alors l'enregistrement de l'événement auprès du jeu, et pourquoi ce design.`,
    ["W.On(..., nil, true) : 4e argument inactive=true -> démarre éteint (always=nil)",
     "WatchTargets() appelle W.Activate(targetEv, db.raids and kind=='none' and not worldBoss) depuis CheckAutoLog",
     "Sync(): l'événement n'est enregistré (RegisterEvent) que s'il a au moins un handler actif ; sinon UnregisterEvent",
     "But : événement fréquent (changement de cible) qui ne coûte rien hors monde ouvert / option raids off / world boss déjà détecté"]);

add("C2", "comprehension", "Ajouter une commande /wl (procédure projet)",
    `${RULES}\n\nFichier Focus.lua :\n${numbered(read("Focus.lua"))}\n\n` +
    `Question : je veux une nouvelle commande "/wl focusreset" qui remet les réglages du module Focus par défaut et affiche un message traduit. ` +
    `Liste TOUS les endroits à modifier (fichiers et quoi), donne le code à ajouter dans Focus.lua, et ce qu'il faut lancer / vérifier ensuite.`,
    ["W.slash.focusreset = function(rest) ... end dans Focus.lua",
     "Remise des valeurs (enabled=false, modifier='shift', button='1') puis Apply() ; Apply ne fait rien en combat",
     "Message via W.Print(L(\"...\")) + traduction dans W.AddFR({...}) en haut de Focus.lua",
     "Entrée dans la liste HELP de Core.lua avec texte français",
     "Ligne dans le tableau Commandes de README.md",
     "node tools/check.js puis bash tools/sync.sh ; pas de bump de version ; tester /reload en jeu"]);

const dbPart = lines(core, 505, 579);
add("C3", "comprehension", "W.DB appelé au chargement avec un défaut table",
    `${RULES}\n\nExtrait de Core.lua (lignes 505-579) :\n${numbered(dbPart, 505)}\n\n` +
    `Question : un nouveau module contient, au niveau du fichier (hors fonction) :\n` +
    `    local db = W.DB("loot", { enabled = true, history = {} })\n` +
    `Que se passe-t-il au chargement et ensuite ? Quels problèmes, et comment l'écrire correctement dans ce projet ?`,
    ["Au chargement du fichier W.db est nil (créé à ADDON_LOADED) -> erreur 'attempt to index field db (a nil value)' dans W.DB",
     "Les défauts doivent être scalaires : une table par défaut est partagée par référence / règle du projet",
     "Correct : local db en haut + W.OnReady(function() db = W.DB('loot', {enabled=true}); db.history = db.history or {} end)"]);

const ct = read("CombatTimer.lua");
add("C4", "comprehension", "Tracer CombatTimer (combat -> boss -> mort -> fin)",
    `${RULES}\n\nFichier CombatTimer.lua :\n${numbered(ct)}\n\n` +
    `Question : le module est activé (bossOnly = false). Trace pas à pas l'état (startAt, isEncounter, ticker) pour cette séquence : ` +
    `1) le joueur entre en combat contre un trash, 2) le boss est engagé (ENCOUNTER_START) pendant ce combat, ` +
    `3) le joueur meurt (il sort de combat) pendant que la rencontre continue, 4) la rencontre se termine (ENCOUNTER_END). ` +
    `Le chrono redémarre-t-il, s'arrête-t-il à la mort, quand s'arrête-t-il ?`,
    ["1) PLAYER_REGEN_DISABLED -> Start(false) : startAt=now, isEncounter=false, ticker créé",
     "2) ENCOUNTER_START -> Start(true) : déjà en cours, encounter et pas isEncounter -> startAt remis à now, isEncounter=true (redémarre à 0:00), ticker conservé",
     "3) PLAYER_REGEN_ENABLED -> Stop(false) : isEncounter et IsEncounterInProgress() -> return, le chrono continue",
     "4) ENCOUNTER_END -> Stop(true) : Update, startAt=nil, ticker annulé ; si hideOOC masqué après 5 s"]);

// long context: whole Core.lua
add("R1", "long-context", "Navigation dans Core.lua entier (~104 Ko)",
    `${RULES}\n\nFichier Core.lua complet :\n${numbered(core)}\n\n` +
    `Questions : a) À quelle ligne est définie la liste affichée par "/wl help" et à quelle ligne la fonction qui l'affiche ? ` +
    `b) Dans la fonction Run (événements), à quelle condition exacte un handler s'exécute-t-il, notamment quand le joueur n'est pas (encore) reconnu comme membre de la guilde ? ` +
    `c) Que signifie W.access == nil ? d) Quelles valeurs par défaut sont créées pour W.db.ui à ADDON_LOADED ?`,
    ["a) local HELP = { ligne 2267 ; W.slash.help ligne 2310",
     "b) ligne 178 : h.active et fichier non désactivé, et ((W.access==true et (not gatedOnly or not h.always)) ou (h.always et not gatedOnly))",
     "c) accès pas encore connu (vérification de guilde en attente)",
     "d) lastModule='RaidGroups', style='auto', lang='auto', overlapForce=false, preloadRaid=true (+ off = {})"]);

// ---------- Bug hunting (seeded) ----------
add("B1", "bugs", "CombatTimer : 2 bugs injectés (// Lua 5.3, condition inversée)",
    `${RULES}\n\n${BUGFMT}\n\nFichier CombatTimer.lua :\n${numbered(seed(ct, [
        ['return string.format("%d:%02d", math.floor(secs / 60), secs % 60)', 'return string.format("%d:%02d", secs // 60, secs % 60)'],
        ["if not isEncounter and encounterEnd then return end", "if isEncounter and encounterEnd then return end"],
    ]))}`,
    ["L26 : // n'existe pas en Lua 5.1 -> erreur de syntaxe, fichier non chargé ; math.floor(secs / 60)",
     "L59 : condition inversée : ENCOUNTER_END ne stoppe plus un chrono de boss (et un chrono non-boss est arrêté par ENCOUNTER_END) -> 'if not isEncounter and encounterEnd'"]);

add("B2", "bugs", "AutoLog : 2 bugs injectés (arguments de W.On, test de timer inversé)",
    `${RULES}\n\n${BUGFMT}\n\nFichier AutoLog.lua :\n${numbered(seed(autolog, [
        ["end, nil, true) -- off until WatchTargets turns it on", "end, true) -- off until WatchTargets turns it on"],
        ["if wbAt == mark and not fought then", "if wbAt ~= mark and not fought then"],
    ]))}`,
    ["L82 : W.On(..., true) met always=true au lieu de inactive=true : handler actif dès le départ, même hors guilde, l'événement reste enregistré -> W.On(..., nil, true)",
     "L80 : wbAt ~= mark : le délai de 5 min ne libère jamais le world boss non combattu -> wbAt == mark"]);

const focus = read("Focus.lua");
add("B3", "bugs", "Focus : 2 bugs injectés (InCombatLockdown retiré, L[...])",
    `${RULES}\n\n${BUGFMT}\n\nFichier Focus.lua :\n${numbered(seed(focus, [
        ["if not db or InCombatLockdown() then return end", "if not db then return end"],
        ['W.Label(p, L("Focus is not available on this client."), "GameFontDisable")', 'W.Label(p, L["Focus is not available on this client."], "GameFontDisable")'],
    ]))}`,
    ["L33 : sans InCombatLockdown, SetAttribute sur frames sécurisées / ClearOverrideBindings / SetOverrideBindingClick en combat (PLAYER_ENTERING_WORLD ou clic d'option en combat) -> ADDON_ACTION_BLOCKED",
     "L75 : L est une fonction : L[...] -> erreur 'attempt to index a function value' quand Focus est indisponible -> L(\"...\")",
     "PIÈGE (pas un bug) : mettre bound[f]=nil pendant pairs(bound) est autorisé en Lua"]);

const ap = read("AutoPromote.lua");
add("B4", "bugs", "AutoPromote : 2 bugs injectés (portée de local dans une closure, off-by-one)",
    `${RULES}\n\n${BUGFMT}\n\nFichier AutoPromote.lua :\n${numbered(seed(ap, [
        ["            local box\n            box = W.Check(", "            local box = W.Check("],
        ["for i = #ranks + 1, #UI.rankChecks do UI.rankChecks[i]:Hide() end", "for i = #ranks, #UI.rankChecks do UI.rankChecks[i]:Hide() end"],
    ]))}`,
    ["L80 : 'local box = W.Check(... function() return box.rankName ...)' : dans l'expression, box n'est pas encore la locale -> global box nil -> erreur 'attempt to index global box' à l'affichage / clic -> déclarer local box avant",
     "L91 : for i = #ranks : masque la dernière case de rang valide (et si #ranks==0, UI.rankChecks[0] nil -> erreur) -> #ranks + 1"]);

const lib = read("Lib.lua");
const packPart = lines(lib, 144, 155);
add("B5", "bugs", "W.Pack / W.Unpack : 2 bugs injectés (# avec des nil, + au lieu de *)",
    `${RULES}\n\n${BUGFMT}\nCes deux fonctions sérialisent des champs pour les messages d'addon (W.Unpack(W.Pack(a, b, c)) doit redonner les champs, nil -> "").\n\nExtrait de Lib.lua :\n${numbered(seed(packPart, [
        ['for i = 1, select("#", ...) do', "for i = 1, #t do"],
        ['gmatch("([^%^]*)%^")', 'gmatch("([^%^]+)%^")'],
    ]), 144)}`,
    ["L147 : #t sur une table avec des nil (trous) est indéfini : les champs nil en fin (ou après un trou) sont perdus -> select('#', ...)",
     "L153 : + saute les champs vides : W.Unpack('a^^c') -> {a, c} au lieu de {a, '', c}, décalage des champs -> *"]);

add("B6", "bugs", "Témoin : Overlap.lua original, sans bug injecté",
    `${RULES}\n\n${BUGFMT}\n\nFichier Overlap.lua :\n${numbered(read("Overlap.lua"))}`,
    ["Aucun bug réel : la bonne réponse est 'Aucun bug trouvé' (au plus des remarques mineures clairement présentées comme non bloquantes)"]);

for (const c of cases) fs.writeFileSync(path.join(OUT, c.id + ".txt"), c.prompt);
fs.writeFileSync(path.join(__dirname, "cases.json"), JSON.stringify(cases.map(({ prompt, ...r }) => ({ ...r, chars: prompt.length })), null, 2));
console.log(cases.map((c) => c.id + " " + c.prompt.length).join("\n"));
