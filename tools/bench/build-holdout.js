// SEALED final test set: bugs seeded in files never used before. Built once, not looked at while tuning.
"use strict";
const fs = require("fs");
const path = require("path");
const REPO = path.resolve(__dirname, "..", "..", "WarLegendRaidTool");
const OUT = path.join(__dirname, "holdout");
fs.mkdirSync(OUT, { recursive: true });
const read = (f) => fs.readFileSync(path.join(REPO, f), "utf8").replace(/\r\n/g, "\n");
function seed(src, pairs) {
    for (const [a, b] of pairs) { if (!src.includes(a)) throw new Error("seed not found: " + a); src = src.replace(a, b); }
    return src;
}
const num = (src) => src.split("\n").map((l, i) => String(i + 1).padStart(4) + ": " + l).join("\n");
const lineOf = (src, re) => { const i = src.split("\n").findIndex((l) => re.test(l)); if (i < 0) throw new Error("line " + re); return i + 1; };
const out = [];

const gy = read("GYTimer.lua");
// H1 (catalogue pattern: secret value)
const h1 = seed(gy, [["local left = W.Safe(GetAreaSpiritHealerTime())\n    if type(left) == \"number\" and left > 0 then", "local left = GetAreaSpiritHealerTime()\n    if left and left > 0 then"]]);
out.push({ id: "H1", kind: "debug", split: "holdout", file: "WarLegendRaidTool/GYTimer.lua", code: num(h1),
    symptom: "En champ de bataille, quand je suis mort : erreur « attempt to perform boolean test on local 'left' (a secret number value) » dans SyncFromSpiritHealer.",
    expect: { lines: [lineOf(h1, /if left and left > 0/), lineOf(h1, /local left = GetAreaSpiritHealerTime/)], kw: "(secr|issecret|W\\.Safe|type\\()", kwFlags: "i" } });
// H2 (not in catalogue: while -> if)
const h2 = seed(gy, [["while nextWave <= now do nextWave = nextWave + WAVE end", "if nextWave <= now then nextWave = nextWave + WAVE end"]]);
out.push({ id: "H2", kind: "debug", split: "holdout", file: "WarLegendRaidTool/GYTimer.lua", code: num(h2),
    symptom: "Chrono cimetière : une fois ressuscité depuis plus d'une minute, la barre affiche des temps négatifs au lieu de continuer à compter les vagues de 30 secondes.",
    expect: { lines: [lineOf(h2, /if nextWave <= now then/)], kw: "(while|boucle|loop|plusieurs vagues|répét)", kwFlags: "i" } });
// H3 (not in catalogue: elseif -> else)
const cd = read("CooldownText.lua");
const h3 = seed(cd, [["    elseif db.previous ~= \"\" then\n", "    else\n"]]);
out.push({ id: "H3", kind: "debug", split: "holdout", file: "WarLegendRaidTool/CooldownText.lua", code: num(h3),
    symptom: "Le module Texte de recharge est désactivé, pourtant l'option du jeu countdownForCooldowns est effacée (remise à vide) à chaque connexion.",
    expect: { lines: [lineOf(h3, /^    else$/), lineOf(h3, /SetCV\(CVAR, db\.previous\)/)], kw: "(previous|vide|\"\"|elseif)", kwFlags: "i" } });
// H4 review (2 bugs: local declared below its use = catalogue; reset moved inside the if = not in catalogue)
const tr = read("TalentReminder.lua");
let h4 = seed(tr, [
    ["local function HideBreak()\n    if breakFrame then breakFrame:SetScript(\"OnUpdate\", nil); breakFrame:Hide() end\nend\n\n", ""],
    ["local function HookBigWigs()", "local function HideBreak()\n    if breakFrame then breakFrame:SetScript(\"OnUpdate\", nil); breakFrame:Hide() end\nend\n\nlocal function HookBigWigs()"],
    ["            ShowReminder()\n        end\n        wasInInstance = inInstance\n", "            ShowReminder()\n            wasInInstance = inInstance\n        end\n"],
]);
out.push({ id: "H4", kind: "review", split: "holdout", file: "WarLegendRaidTool/TalentReminder.lua", code: num(h4),
    expect: [{ lines: [lineOf(h4, /if seconds <= 0 then HideBreak\(\)/)], kw: "(déclar|declar|global|avant|plus bas|portée|nil)", kwFlags: "i" },
        { lines: [lineOf(h4, /^            wasInInstance = inInstance/)], kw: "(wasInInstance|sortie|quitt|false|jamais|réinit)", kwFlags: "i" }] });
// H5 review clean
out.push({ id: "H5", kind: "review", split: "holdout", file: "WarLegendRaidTool/CooldownText.lua", code: num(cd), expect: [] });

for (const c of out) fs.writeFileSync(path.join(OUT, c.id + ".json"), JSON.stringify(c, null, 2));
console.log("sealed:", out.map((c) => c.id).join(" "));
