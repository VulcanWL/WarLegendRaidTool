// Re-grades every stored answer with the current (strict) grader and prints the leaderboard of all rounds.
"use strict";
const fs = require("fs");
const path = require("path");
const DIR = __dirname;
const { grade, cases } = require("./loop.js");
const byId = Object.fromEntries(cases.map((c) => [c.id, c]));
const rows = [];
for (const round of fs.readdirSync(path.join(DIR, "results"))) {
    const rd = path.join(DIR, "results", round);
    for (const cell of fs.readdirSync(rd)) {
        const cd = path.join(rd, cell);
        if (!fs.statSync(cd).isDirectory()) continue;
        const rs = fs.readdirSync(cd).filter((f) => f.endsWith(".json")).map((f) => JSON.parse(fs.readFileSync(path.join(cd, f), "utf8")));
        if (rs.length < 18) continue; // unfinished cell
        let train = 0, test = 0, found = 0, fp = 0, fpKnown = true, wh = 0, sec = 0, out = 0;
        for (const r of rs) {
            const c = byId[r.case];
            if (!c || !r.ok) continue;
            const g = grade(c, r.answer);
            if (c.kind === "debug") { if (c.split === "train") train += g.score; else if (c.split === "test") test += g.score; }
            else if (c.split === "test") { found += g.found; if (g.fp === null) fpKnown = false; else fp += g.fp; }
            wh += r.wh || 0; sec += r.wall_s || 0; out += r.out || 0;
        }
        rows.push({ round, cell, train: +(train / 6).toFixed(2), test: +(test / 6).toFixed(2), review: found + "/10",
            fp: fpKnown ? fp : "n/a", wh: +(wh / rs.length).toFixed(3), sec: +(sec / rs.length).toFixed(1), out: Math.round(out / rs.length) });
    }
}
rows.sort((a, b) => b.test - a.test || a.wh - b.wh);
for (const r of rows) console.log(`${(r.round + " " + r.cell).padEnd(26)} train ${r.train}  test ${r.test}  review ${r.review} fp ${r.fp}  ${r.wh} Wh  ${r.sec}s  ${r.out} tok`);
fs.writeFileSync(path.join(DIR, "leaderboard-strict.json"), JSON.stringify(rows, null, 2));
