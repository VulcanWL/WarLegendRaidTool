// What tools/check.js (the project's own static checks) catches by itself, at zero GPU energy, on every benchmark bug.
// For each case: a copy of the three addons (from HEAD) with only the tested file replaced, check.js run on that copy.
"use strict";
const fs = require("fs");
const path = require("path");
const { execFileSync, spawnSync } = require("child_process");
const REPO = path.resolve(__dirname, "..", "..");
const DIR = __dirname;
const WORK = path.join(DIR, "static");
const ADDONS = ["WarLegendRaidTool", "WarLegendRaidTool_Raid", "WarLegendRaidTool_PvP"];
const git = (...a) => execFileSync("git", ["-C", REPO, ...a], { encoding: "utf8", maxBuffer: 64 << 20 });

// HEAD tree once (git archive -> files), so nothing in the repo is touched
const base = path.join(WORK, "_base");
if (!fs.existsSync(base)) {
    fs.mkdirSync(base, { recursive: true });
    for (const f of git("ls-files", ...ADDONS).split("\n").filter(Boolean)) {
        const dst = path.join(base, f);
        fs.mkdirSync(path.dirname(dst), { recursive: true });
        fs.writeFileSync(dst, execFileSync("git", ["-C", REPO, "show", "HEAD:" + f], { maxBuffer: 64 << 20 }));
    }
}
const unnumber = (code) => code.split("\n").map((l) => l.replace(/^\s*\d+: ?/, "")).join("\n");

function runCase(id, file, content, expect) {
    const root = path.join(WORK, id);
    fs.rmSync(root, { recursive: true, force: true });
    fs.cpSync(base, root, { recursive: true });
    fs.writeFileSync(path.join(root, file), content);
    const r = spawnSync(process.execPath, [path.join(REPO, "tools", "check.js"), root], { encoding: "utf8" });
    const lines = (r.stdout || "").split("\n").filter((l) => l.startsWith(file.replace(/\\/g, "/") + ":"));
    const caught = expect.map((e) => lines.some((l) => { const n = parseInt(l.split(":")[1], 10); return e.some((x) => Math.abs(x - n) <= 1); }));
    return { id, file, caught, findings: lines };
}

const results = [];
// synthetic B cases (full seeded files rebuilt the same way as build-cases.js)
const SEEDS = {
    B1: ["WarLegendRaidTool/CombatTimer.lua", [[26], [59]]],
    B2: ["WarLegendRaidTool/AutoLog.lua", [[82], [80]]],
    B3: ["WarLegendRaidTool/Focus.lua", [[33], [75]]],
    B4: ["WarLegendRaidTool/AutoPromote.lua", [[80], [91]]],
};
for (const [id, [file, expect]] of Object.entries(SEEDS)) {
    const txt = fs.readFileSync(path.join(DIR, "cases", id + ".txt"), "utf8");
    const code = txt.slice(txt.search(/\n(Fichier|Extrait) [^\n]*:\n/) + 1).replace(/^[^\n]*\n/, "");
    results.push(runCase(id, file, unnumber(code), expect));
}
// real bugs: the whole file as it was before the fix
for (const f of fs.readdirSync(path.join(DIR, "real")).sort()) {
    const r = JSON.parse(fs.readFileSync(path.join(DIR, "real", f), "utf8"));
    results.push(runCase(r.id, r.file, git("show", r.commit + "^:" + r.file), [r.expect.lines]));
}
// sealed set: full seeded files
for (const f of fs.readdirSync(path.join(DIR, "holdout")).sort()) {
    const h = JSON.parse(fs.readFileSync(path.join(DIR, "holdout", f), "utf8"));
    const exp = Array.isArray(h.expect) ? h.expect.map((e) => e.lines) : [h.expect.lines];
    if (!exp.length) continue;
    results.push(runCase(h.id, h.file, unnumber(h.code), exp));
}
let tot = 0, got = 0;
for (const r of results) {
    tot += r.caught.length; got += r.caught.filter(Boolean).length;
    console.log(r.id.padEnd(4), r.caught.map((c) => (c ? "CAUGHT" : "-")).join(" "), r.findings.slice(0, 3).join(" | "));
}
console.log(`check.js alone: ${got}/${tot} bugs`);
fs.writeFileSync(path.join(DIR, "static-results.json"), JSON.stringify(results, null, 2));
