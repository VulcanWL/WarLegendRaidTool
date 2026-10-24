// WarLegend RaidTool - report of what a game session left on disk (not shipped, read-only).
// Usage: node tools/forever-report.js [--flavor forever|beta] [--game <folder>] [--since YYYY-MM-DD|all] [--all]
// Reads <game>\Interface\AddOns (installed version, same files as the repo?), the SavedVariables of every account
// (!BugGrabber: our errors first with file:line and count, WarLegendRaidToolDB: auditLog.cur / .prev, bgMessages) and
// the newest client logs (login errors, Errors folder). Errors older than the installed addon files are left out
// (--since to choose the date, --since all for everything); --all also lists the errors of other addons.
// Exit code 1 when one of our addons raised a Lua error (after --since) or the audit refused a message.
const fs = require("fs");
const path = require("path");

const REPO = path.join(__dirname, "..");
const ADDONS = ["WarLegendRaidTool", "WarLegendRaidTool_Raid", "WarLegendRaidTool_PvP", "WarLegendRaidTool_Skyborne"];
const argv = process.argv.slice(2);
const opt = (name) => { const i = argv.indexOf(name); return i >= 0 ? argv[i + 1] : null; };
const flavor = "_forever_"; // the Classic beta is no longer used
const GAME = opt("--game") || path.join("C:\\Program Files (x86)\\World of Warcraft", flavor);
let since = opt("--since") === "all" ? 0 : opt("--since") ? Date.parse(opt("--since")) / 1000 : null;
const showAll = argv.includes("--all");
let problems = 0;

const fmt = (t) => {
    const d = new Date(t * 1000), p = (n) => String(n).padStart(2, "0");
    return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate()) + " " + p(d.getHours()) + ":" + p(d.getMinutes());
};
const read = (f) => { try { return fs.readFileSync(f, "utf8").split("\r").join(""); } catch (e) { return null; } };
const list = (d) => { try { return fs.readdirSync(d); } catch (e) { return []; } };
const section = (t) => console.log("\n== " + t);

// Minimal reader for the Lua tables the game saves (strings, numbers, booleans, nested tables): "Name = value" pairs.
function parseLua(src) {
    let i = 0;
    const ws = () => { while (i < src.length && /\s/.test(src[i])) i++; };
    function str() {
        const q = src[i++];
        let out = "";
        while (i < src.length && src[i] !== q) {
            if (src[i] === "\\") {
                i++;
                const c = src[i];
                const m = /^\d{1,3}/.exec(src.slice(i, i + 3));
                if (m) { out += String.fromCharCode(+m[0]); i += m[0].length; continue; }
                out += c === "n" ? "\n" : c === "t" ? "\t" : c === "r" ? "\r" : c;
                i++;
            } else out += src[i++];
        }
        i++;
        return out;
    }
    function val() {
        ws();
        const c = src[i];
        if (c === '"' || c === "'") return str();
        if (c === "{") {
            i++;
            const arr = [], obj = {};
            for (;;) {
                ws();
                if (src[i] === "}") { i++; break; }
                if (src[i] === ",") { i++; continue; }
                if (src[i] === "[") {
                    i++;
                    const k = val();
                    ws(); i++; // ]
                    ws(); i++; // =
                    obj[k] = val();
                } else arr.push(val());
            }
            return Object.keys(obj).length ? obj : arr;
        }
        const m = /^(-?[\d.]+(?:e[+-]?\d+)?|true|false|nil)/i.exec(src.slice(i, i + 40));
        if (!m) throw new Error("unexpected '" + src.slice(i, i + 20) + "' at " + i);
        i += m[0].length;
        return m[0] === "true" ? true : m[0] === "false" ? false : m[0] === "nil" ? null : +m[0];
    }
    const out = {};
    for (;;) {
        ws();
        const m = /^[A-Za-z_][A-Za-z0-9_]*/.exec(src.slice(i, i + 80));
        if (!m) break;
        i += m[0].length;
        ws(); i++; // =
        out[m[0]] = val();
    }
    return out;
}

function sameFiles(a, b) {
    const diff = [];
    const walk = (rel) => {
        for (const n of new Set([...list(path.join(a, rel)), ...list(path.join(b, rel))])) {
            const r = path.join(rel, n), pa = path.join(a, r), pb = path.join(b, r);
            if (/^(AGENTS|STATUS)\.md$/.test(n)) continue;
            const sa = fs.existsSync(pa) && fs.statSync(pa), sb = fs.existsSync(pb) && fs.statSync(pb);
            if ((sa && sa.isDirectory()) || (sb && sb.isDirectory())) walk(r);
            else if (!sa || !sb || sa.size !== sb.size || !fs.readFileSync(pa).equals(fs.readFileSync(pb))) diff.push(r);
        }
    };
    walk("");
    return diff;
}

// ---- 1. installed version
section("Installed version (" + GAME + ")");
if (!fs.existsSync(GAME)) { console.log("game folder not found"); process.exit(1); }
const toc = (root, a) => ((read(path.join(root, a, a + ".toc")) || "").match(/^## Version:\s*(.+)$/m) || [])[1] || "missing";
for (const a of ADDONS) {
    const inst = toc(path.join(GAME, "Interface", "AddOns"), a), repo = toc(REPO, a);
    const diff = inst === "missing" ? [] : sameFiles(path.join(REPO, a), path.join(GAME, "Interface", "AddOns", a));
    const state = inst === "missing" ? "NOT INSTALLED" : diff.length ? diff.length + " file(s) differ from the repo (" + diff.slice(0, 3).join(", ") + ")" : "identical to the repo";
    console.log("  " + a.padEnd(28) + inst.padEnd(14) + (inst !== repo ? "repo " + repo + "; " : "") + state);
}

if (since === null) {
    try { since = Math.floor(fs.statSync(path.join(GAME, "Interface", "AddOns", ADDONS[0], ADDONS[0] + ".toc")).mtimeMs / 1000); } catch (e) { since = 0; }
}
console.log("  errors counted since " + (since ? fmt(since) + " (the installed files)" : "the beginning"));

// ---- 2. SavedVariables of every account
const accounts = [];
const wtfAcc = path.join(GAME, "WTF", "Account");
for (const n of list(wtfAcc)) {
    const sv = path.join(wtfAcc, n, "SavedVariables");
    if (fs.existsSync(sv)) accounts.push({ name: n, sv });
}
if (!accounts.length) console.log("\nNo account SavedVariables found under " + wtfAcc);

for (const acc of accounts) {
    const bugFile = path.join(acc.sv, "!BugGrabber.lua"), dbFile = path.join(acc.sv, "WarLegendRaidTool.lua");
    const stamp = (f) => fs.existsSync(f) ? fmt(fs.statSync(f).mtimeMs / 1000) : "absent";
    section("Account " + acc.name + " - Lua errors (!BugGrabber, written " + stamp(bugFile) + ")");
    const bugSrc = read(bugFile);
    if (bugSrc === null) console.log("  no !BugGrabber.lua");
    else {
        let errors = [];
        try { errors = parseLua(bugSrc).BugGrabberDB.errors || []; } catch (e) { console.log("  cannot read: " + e.message); }
        errors = errors.filter((e) => (e.time || 0) >= since);
        const mine = errors.filter((e) => /WarLegend/i.test((e.message || "") + (e.stack || "")));
        const group = (list) => {
            const g = {};
            for (const e of list) {
                const key = String(e.message).split("\n")[0].replace(/\s+/g, " ").slice(0, 170);
                const o = g[key] || (g[key] = { n: 0, last: 0 });
                o.n += e.counter || 1;
                o.last = Math.max(o.last, e.time || 0);
            }
            return Object.entries(g).sort((x, y) => y[1].last - x[1].last);
        };
        console.log("  " + errors.length + " distinct error(s)" + (since ? " since " + fmt(since) : "") + ", " + mine.length + " from our addons");
        for (const [msg, o] of group(mine)) console.log("  ** x" + o.n + "  last " + fmt(o.last) + "  " + msg);
        if (mine.length) problems++;
        const others = errors.filter((e) => !mine.includes(e));
        if (others.length && !showAll) console.log("  (" + others.length + " from other addons, " + others.reduce((s, e) => s + (e.counter || 1), 0) + " occurrences: --all lists them)");
        if (showAll) for (const [msg, o] of group(others)) console.log("     x" + o.n + "  last " + fmt(o.last) + "  " + msg);
    }

    section("Account " + acc.name + " - WarLegendRaidToolDB (written " + stamp(dbFile) + ")");
    const dbSrc = read(dbFile);
    if (dbSrc === null) { console.log("  no WarLegendRaidTool.lua"); continue; }
    let db = null;
    try { db = parseLua(dbSrc).WarLegendRaidToolDB; } catch (e) { console.log("  cannot read: " + e.message); continue; }
    const log = db && db.auditLog;
    if (!log) console.log("  no audit log (off by default for players: /wl audit on)");
    else for (const which of ["prev", "cur"]) {
        const a = log[which];
        if (!a) continue;
        const p = a.perf || {};
        console.log("  " + which + "  " + fmt(a.start) + " -> " + fmt(a.stop) + "  v" + a.version + "  " + (p.group || "?"));
        console.log("       in " + a.inN + ", out " + a.outN + ", refused " + a.refused + ", public lines " + a.chatN +
            "  | memory " + p.memoryKB + " KB, cpu avg " + (p.cpuAvgMs || 0).toFixed(3) + " ms, peak " + (p.cpuPeakMs || 0).toFixed(1) + " ms");
        if (a.refused > 0) problems++;
        const rows = Object.entries(a.counts || {}).map(([k, v]) => [k, v]).filter(([k]) => !/\|(ok|sent)$/.test(k));
        for (const [k, v] of rows) console.log("       NOT ok: " + k + " x" + v.n);
        const peak = Object.entries(a.perMin || {}).sort((x, y) => y[1] - x[1])[0];
        if (peak) console.log("       busiest prefix per minute: " + peak[0] + " " + peak[1]);
        if (p.slowest && p.slowest.length) console.log("       slowest: " + p.slowest.slice(0, 3).map((s) => s.split("|")[0] + " " + s.split("|")[3] + " ms").join("; "));
        if (p.busiest && p.busiest.length) console.log("       busiest: " + p.busiest.slice(0, 3).map((s) => s.split("|")[0] + " " + s.split("|")[2] + " ms/" + s.split("|")[1]).join("; "));
    }
    const bg = db && ((db.pvp && db.pvp.bgMessages) || db.bgMessages);
    console.log("  bgMessages: " + (bg && bg.length ? bg.length + " line(s), newest: " + bg[0] : "none"));
}

// ---- 3. client logs
section("Client logs");
const errDir = path.join(GAME, "Errors");
const errFiles = list(errDir).map((n) => ({ n, t: fs.statSync(path.join(errDir, n)).mtimeMs / 1000 })).sort((x, y) => y.t - x.t);
console.log("  Errors folder: " + (errFiles.length ? errFiles.length + " file(s), newest " + errFiles[0].n + " (" + fmt(errFiles[0].t) + ")" : "none"));
if (errFiles.length && errFiles[0].t >= since) problems++;
const conn = read(path.join(GAME, "Logs", "Connection.log")) || "";
const fatal = conn.split("\n").filter((l) => /Fatal login error|disconnect.*unexpected/i.test(l));
console.log("  login errors (Connection.log): " + (fatal.length ? fatal.length + ", last: " + fatal[fatal.length - 1].slice(0, 150) : "none"));
const client = read(path.join(GAME, "Logs", "Client.log")) || "";
const lines = client.split("\n").filter(Boolean);
console.log("  Client.log: " + (lines.length ? lines[0].trim() + " ... " + lines[lines.length - 1].trim() : "empty"));

console.log("\n" + (problems ? problems + " point(s) to look at (** errors, refused messages, Errors folder)." : "Nothing abnormal found."));
process.exit(problems ? 1 : 0);
