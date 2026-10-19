// Real bugs fixed live (git history, read only): the code BEFORE the fix + the symptom as reported in game.
// Writes real/<id>.json { id, split, commit, file, code (numbered), symptom, expect: {lines:[..], kw: regex} }.
"use strict";
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");
const REPO = path.resolve(__dirname, "..", "..");
const OUT = path.join(__dirname, "real");
fs.mkdirSync(OUT, { recursive: true });

const git = (...a) => execFileSync("git", ["-C", REPO, ...a], { encoding: "utf8", maxBuffer: 64 << 20 }).replace(/\r\n/g, "\n");

// start: regex of the first line shown; n: lines shown; expect: regexes of the line(s) at fault (any hit counts)
const CASES = [
    // ---------- train (their fixes feed the bug catalogue) ----------
    { id: "L1", split: "train", commit: "c7b0e59", file: "WarLegendRaidTool/Core.lua", start: /^function W\.Button\(/, n: 64,
      symptom: "Depuis la dernière modification, /wl n'ouvre plus aucune fenêtre. Erreur : « attempt to call global 'Index' (a nil value) » dans W.Button.",
      expect: [/^\s+Index\(text, b\)/, /^local function Index\(/], kw: /(déclar|declar|avant|before|au-dessus|plus haut|portée|scope|upvalue|global)/i },
    { id: "L2", split: "train", commit: "40b70c8", file: "WarLegendRaidTool_PvP/Modules/Power.lua", start: /function playerButton\.Power:UpdateMinMaxValues/, n: 52,
      symptom: "En champ de bataille, la barre de mana des cadres reste figée et ne bouge plus. Aucune erreur affichée (les appels de module passent par un SafeCall qui avale les erreurs). Sur ce client, les API d'unité peuvent renvoyer des « valeurs secrètes ».",
      expect: [/if max and issecret\(max\)/], kw: /(secr)/i },
    { id: "L6", split: "train", commit: "a321309", file: "WarLegendRaidTool_Raid/RaidGroups.lua", start: /^-- The unit's mark/, n: 12,
      symptom: "Erreur en raid : « attempt to compare local 'v' (a secret number value) » quand le module lit les marques de raid.",
      expect: [/if v == nil then/], kw: /(type\(|secr)/i },
    { id: "L8", split: "train", commit: "2cc3405", file: "WarLegendRaidTool/Roster.lua", start: /^local function ScanTrials/, n: 24,
      symptom: "Recrues : la date de début d'essai de certaines recrues repart régulièrement à aujourd'hui, alors qu'elles n'ont pas quitté la guilde.",
      expect: [/if not at\[k\] then db\.trials\[k\] = nil/], kw: /(ligne|connect|online|offline|absent|liste)/i },
    { id: "L10", split: "train", commit: "2cc3405", file: "WarLegendRaidTool/CapTimers.lua", start: /^-- Gates, flag respawn, queue/, n: 30,
      symptom: "Chronos BG : quand je décoche « Captures » (db.enabled), les barres de file d'attente, de portes et de drapeau disparaissent aussi, alors qu'elles ont leurs propres cases (db.queue, db.flag).",
      expect: [/local function Extras\(\)/], kw: /db\.enabled/i },
    { id: "L11", split: "train", commit: "2cc3405", file: "WarLegendRaidTool_PvP/Modules/CrowdControl.lua", start: /^local crowdControl = /, n: 70,
      symptom: "Cadres BG : après la mort puis la résurrection d'un joueur, l'icône de contrôle (CC) ne réapparaît plus jamais sur son cadre.",
      expect: [/events = \{/, /function f:UnitDied\(\)/], kw: /(reviv|ressusc|résurr|resurr)/i },
    // ---------- test (never used to write the catalogue) ----------
    { id: "L3", split: "test", commit: "27759fa", file: "WarLegendRaidTool_PvP/Modules/NativeAuras.lua", start: /^local function LayoutTypeIcons/, n: 40,
      symptom: "Erreur x464 en champ de bataille : « attempt to perform boolean test on local 'visible' (a secret boolean value) » dans LayoutTypeIcons.",
      expect: [/if ok and visible then/], kw: /(issecret|secr)/i },
    { id: "L4", split: "test", commit: "28480d4", file: "WarLegendRaidTool_PvP/Modules/Power.lua", start: /function playerButton\.Power:UpdatePower/, n: 26,
      symptom: "Cadres BG alliés : ma barre de mana affiche parfois la mana d'un autre joueur. Sur ce serveur, plusieurs joueurs peuvent avoir le même prénom ; les événements de puissance sont rattachés aux cadres par le nom du joueur.",
      expect: [/function playerButton\.Power:UpdatePower/, /^\s+if unitID then\s*$/, /UnitPowerMax\(unitID\)/, /UnitPower\(unitID\)/], kw: /(propre unité|sa propre|son unité|own unit|playerButton\.unitID|self\.unitID|unitID du (cadre|bouton))/i },
    { id: "L5", split: "test", commit: "ce8d6b9", file: "WarLegendRaidTool_PvP/Startup.lua", start: /^---@class WarLegendPvP/, n: 12,
      symptom: "L'addon PvP est chargé à la demande (LoadAddOn) bien après la connexion. Ses options cochées (ex. masquer les cadres de raid) reviennent aux valeurs par défaut à chaque chargement.",
      expect: [/WarLegendPvP:PLAYER_LOGIN\(\)/, /if IsLoggedIn\(\) then/], kw: /(ADDON_LOADED|SavedVariables)/i },
    { id: "L7", split: "test", commit: "2cc3405", file: "WarLegendRaidTool/CapTimers.lua", start: /^local function FindScoreWidgets/, n: 30,
      symptom: "Chronos BG : dans un champ de bataille à drapeaux, l'estimation « temps avant la victoire » est absurde ; dans Arathi elle est juste.",
      expect: [/text:match\("%d\+%s\*\/%s\*%d\+"\)/], kw: /(1\/3|x\/3|\/3\b|compteurs? de drapeaux|flag counter|max(imum)? (est |de )?(3|petit)|>= ?100|au moins 100)/i },
    { id: "L9", split: "test", commit: "2cc3405", file: "WarLegendRaidTool_PvP/FlagCarrier.lua", start: /^function WarLegendPvP:MarkRaidFrameFlag/, n: 34,
      symptom: "Quand le nom du porteur de drapeau a une forme inattendue, l'icône de drapeau s'affiche sur beaucoup de cadres de raid à la fois.",
      expect: [/== self:GetPlayerbuttonByName\(name\)/], kw: /(nil\s*==\s*nil|les deux (renvoient|valent|sont|retournent) nil|tous les deux nil|both (return )?nil|deux nil|nil des deux)/i },
    { id: "L12", split: "test", commit: "2cc3405", file: "WarLegendRaidTool/CapTimers.lua", start: /^local function Zone\(\)/, n: 34,
      symptom: "Chronos BG : les barres et l'estimation du temps avant la victoire repartent de zéro quand on change de sous-zone à l'intérieur du même champ de bataille.",
      expect: [/W\.On\("ZONE_CHANGED_NEW_AREA", Zone\)/], kw: /(sous-zone|même|same|instance|InstanceID|ZONE_CHANGED)/i },
];

for (const c of CASES) {
    const src = git("show", c.commit + "^:" + c.file).split("\n");
    let s = src.findIndex((l) => c.start.test(l));
    if (s < 0) throw new Error(c.id + ": start not found");
    // CapTimers Extras/Zone and Core W.Button: show a few lines above for context
    const from = Math.max(0, s - (c.id === "L12" ? 0 : 2));
    const lines = src.slice(from, from + c.n);
    const exp = [];
    lines.forEach((l, i) => { if (c.expect.some((re) => re.test(l))) exp.push(from + i + 1); });
    if (!exp.length) throw new Error(c.id + ": expected line not found in the window");
    const code = lines.map((l, i) => String(from + i + 1).padStart(4) + ": " + l.replace(/\t/g, "    ")).join("\n");
    const rec = { id: c.id, split: c.split, commit: c.commit, file: c.file, symptom: c.symptom, code,
        expect: { lines: exp, kw: c.kw.source, kwFlags: c.kw.flags }, fix: git("show", "--format=", "-U2", c.commit, "--", c.file).slice(0, 4000) };
    fs.writeFileSync(path.join(OUT, c.id + ".json"), JSON.stringify(rec, null, 2));
    console.log(c.id, c.split, c.file, "lines", from + 1, "-", from + lines.length, "expect", exp.join(","));
}
