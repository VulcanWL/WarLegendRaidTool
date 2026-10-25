// WarLegend RaidTool - read the results of /wl verify (not shipped, read-only).
// Usage: node tools/verify-live.js [--follow] [--saved] [--all] [--game <folder>]
// Reads the [WLRT-VERIFY] lines of the client's chat log (<game>\Logs\WoWChatLog.txt, written while the game runs once
// /wl verify switched it on): the last run only, --all for every run of the file, --follow keeps printing new lines.
// --saved reads the runs kept in WarLegendRaidTool_DevDB instead (SavedVariables, written at /reload or logout).
// Only the tagged lines are printed: the rest of the chat log is never shown.
// Exit code 1 when the last run printed a LOOK line.
const fs = require("fs");
const path = require("path");

const argv = process.argv.slice(2);
const opt = (name) => { const i = argv.indexOf(name); return i >= 0 ? argv[i + 1] : null; };
const GAME = opt("--game") || "C:\\Program Files (x86)\\World of Warcraft\\_forever_";
const TAG = "[WLRT-VERIFY] ";
const read = (f) => { try { return fs.readFileSync(f, "utf8").split("\r").join(""); } catch (e) { return null; } };

function tagged(text) {
    const out = [];
    for (const line of text.split("\n")) {
        const i = line.indexOf(TAG);
        if (i >= 0) out.push(line.slice(0, 18).trim() + "  " + line.slice(i + TAG.length));
    }
    return out;
}

function lastRun(lines) {
    if (argv.includes("--all")) return lines;
    let start = 0;
    lines.forEach((l, i) => { if (/\bINFO begin:/.test(l)) start = i; });
    return lines.slice(start);
}

if (argv.includes("--saved")) {
    const root = path.join(GAME, "WTF", "Account");
    let found = false;
    for (const acc of fs.existsSync(root) ? fs.readdirSync(root) : []) {
        const text = read(path.join(root, acc, "SavedVariables", "WarLegendRaidTool_Dev.lua"));
        if (!text) continue;
        const lines = [...text.matchAll(/"((?:OK|LOOK|SKIP|INFO) [a-z0-9]+: (?:[^"\\]|\\.)*)"/g)].map((m) => m[1]);
        if (!lines.length) continue;
        found = true;
        console.log(`== ${acc} (newest run first)`);
        lines.forEach((l) => console.log(/^INFO begin:/.test(l) ? "\n" + l : l));
    }
    if (!found) console.log("No saved run: /wl verify in game, then /reload.");
    process.exit(0);
}

const LOG = path.join(GAME, "Logs", "WoWChatLog.txt");
const text = read(LOG);
if (text === null && !argv.includes("--follow")) {
    console.log(`No chat log at ${LOG}: run /wl verify in game first.`);
    process.exit(0);
}
const run = lastRun(tagged(text || ""));
run.forEach((l) => console.log(l));
if (!argv.includes("--follow")) {
    if (!run.length) console.log("No [WLRT-VERIFY] line yet (the client writes the chat log with some delay).");
    process.exit(run.some((l) => /\s\sLOOK /.test(l)) ? 1 : 0);
}

// --follow: print the new tagged lines as the client appends them
let size = text === null ? 0 : fs.statSync(LOG).size;
console.log(`(following ${LOG}, Ctrl+C to stop)`);
setInterval(() => {
    let st;
    try { st = fs.statSync(LOG); } catch (e) { return; }
    if (st.size < size) size = 0; // file recreated
    if (st.size === size) return;
    const fd = fs.openSync(LOG, "r");
    const buf = Buffer.alloc(st.size - size);
    fs.readSync(fd, buf, 0, buf.length, size);
    fs.closeSync(fd);
    size = st.size;
    tagged(buf.toString("utf8").split("\r").join("")).forEach((l) => console.log(l));
}, 1000);
