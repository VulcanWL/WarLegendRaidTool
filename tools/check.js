// WarLegend RaidTool - offline checks (not shipped: only the three addon folders go in the release zip).
// Usage: node tools/check.js [root]   (once: cd tools && npm install)
//          (root = the folder holding the three addon folders, default: the repo)
// Prints only the problems, then one summary line. Exit code 1 when something is wrong.
// Checks: UTF-8 BOM / CRLF, Lua 5.1 syntax, .toc entries <-> files, global writes, unknown lowercase
// global reads, and names used above the line where the same file declares them local (nil in game).
// Cross-file (three addons): W.X used but never assigned; W.slash.x <-> HELP (Core.lua) <-> README "Commandes";
// W.RegisterModule keys <-> CATEGORIES; prefixes sent <-> received, raid addon prefixes <-> lodPrefix; L("...") without W.AddFR.
// CHANGELOG.md (repo root): notes under "## <the .toc ## Version>" (the release workflow makes the release notes from them).
"use strict";
const fs = require("fs");
const path = require("path");
const luaparse = require("luaparse");

const root = path.resolve(process.argv[2] || path.join(__dirname, ".."));
const ADDONS = ["WarLegendRaidTool", "WarLegendRaidTool_Raid", "WarLegendRaidTool_PvP", "WarLegendRaidTool_Skyborne", "WarLegendRaidTool_Dev"];
const DEV = "WarLegendRaidTool_Dev"; // internal testing addon, never in the release zip: no ## Version, its /wl commands not in HELP / README

// Globals the addon may create (anything else written at global scope is an accident).
// ClickCastFrames: Clique's shared table (PvP frames register there).
const OK_WRITE = /^([A-Z0-9_]+|WLRT\w*|WarLegend\w*|ClickCastFrames|Myslot[A-Za-z]*|DoesItDieDB)$/;
// Lowercase globals that exist in the WoW Lua environment.
const OK_READ = new Set((
    "_G assert collectgarbage error getmetatable setmetatable ipairs pairs next pcall xpcall print rawequal rawget " +
    "rawset select tonumber tostring type unpack loadstring getfenv setfenv newproxy gcinfo string table math " +
    "coroutine bit debugstack debugprofilestop debugprofilestart geterrorhandler seterrorhandler securecall " +
    "securecallfunction secureexecuterange issecure issecurevariable issecretvalue issecrettable canaccessvalue " +
    "canaccesstable hooksecurefunc forceinsecure scrub tostringall strsplit strsplittable strjoin strconcat strtrim " +
    "strlen strlenutf8 strsub strfind strmatch strupper strlower strrep strrev strbyte strchar strcmputf8i gsub " +
    "gmatch format tinsert tremove tContains tAppendAll tInvert tFilter tUnorderedRemove wipe sort foreach foreachi getn " +
    "floor ceil abs min max mod fmod sqrt exp log log10 frexp ldexp sin cos tan asin acos atan atan2 deg rad random " +
    "fastrandom date time difftime"
).split(" "));

const problems = [];
const seen = new Set();
const report = (file, line, msg) => {
    const s = path.relative(root, file).replace(/\\/g, "/") + ":" + line + "  " + msg;
    if (!seen.has(s)) { seen.add(s); problems.push(s); }
};

// Visits every node except field names (a.name, a:name(), { name = ... }), which are not variables.
function walk(node, fn) {
    if (!node || typeof node !== "object") return;
    if (Array.isArray(node)) { for (const n of node) walk(n, fn); return; }
    if (node.type) fn(node);
    for (const k in node) {
        if (k === "loc" || k === "range") continue;
        if (k === "identifier" && node.type === "MemberExpression") continue;
        if (k === "key" && node.type === "TableKeyString") continue;
        if (node[k] && typeof node[k] === "object") walk(node[k], fn);
    }
}

function checkLua(file) {
    const raw = fs.readFileSync(file);
    if (raw[0] === 0xef && raw[1] === 0xbb && raw[2] === 0xbf) report(file, 1, "UTF-8 BOM");
    const src = raw.toString("utf8");
    if (src.includes("\r\n")) report(file, 1, "CRLF line endings");
    let ast;
    try {
        ast = luaparse.parse(src.replace(/^﻿/, ""), { luaVersion: "5.1", scope: true, locations: true });
    } catch (e) {
        report(file, e.line || 0, "syntax: " + e.message);
        return null;
    }
    // Locals declared directly in the chunk (file scope), with the line of their declaration.
    const fileLocals = new Map();
    for (const st of ast.body) {
        if (st.type === "LocalStatement") {
            for (const v of st.variables) if (!fileLocals.has(v.name)) fileLocals.set(v.name, v.loc.start.line);
        } else if (st.type === "FunctionDeclaration" && st.isLocal && st.identifier) {
            if (!fileLocals.has(st.identifier.name)) fileLocals.set(st.identifier.name, st.identifier.loc.start.line);
        }
    }
    const written = new Set();
    walk(ast, (n) => {
        if (n.type === "AssignmentStatement") {
            for (const t of n.variables) if (t.type === "Identifier" && !t.isLocal) written.add(t);
        } else if (n.type === "FunctionDeclaration" && !n.isLocal && n.identifier && n.identifier.type === "Identifier") {
            written.add(n.identifier);
        }
    });
    walk(ast, (n) => {
        if (n.type !== "Identifier" || n.isLocal) return;
        const line = n.loc.start.line;
        const declared = fileLocals.get(n.name);
        if (declared && declared > line) {
            report(file, line, "'" + n.name + "' used above its 'local' declaration (line " + declared + "): global nil here");
        } else if (written.has(n)) {
            if (!OK_WRITE.test(n.name)) report(file, line, "global write '" + n.name + "' (missing 'local'?)");
        } else if (/^[a-z]/.test(n.name) && !OK_READ.has(n.name)) {
            report(file, line, "unknown lowercase global '" + n.name + "'");
        }
    });
    return ast;
}

function luaFiles(dir) {
    const out = [];
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
        const p = path.join(dir, e.name);
        if (e.isDirectory()) { if (e.name !== "Libs") out.push(...luaFiles(p)); }
        else if (e.name.endsWith(".lua")) out.push(p);
    }
    return out;
}

// Value of a Lua string literal node (luaparse leaves .value null), else undefined.
function luaStr(n) {
    if (!n || n.type !== "StringLiteral") return undefined;
    const raw = n.raw;
    const long = raw.match(/^\[(=*)\[\n?([\s\S]*)\]\1\]$/);
    if (long) return long[2];
    const ESC = { n: "\n", t: "\t", r: "\r", a: "\x07", b: "\b", f: "\f", v: "\v", "\n": "\n" };
    return raw.slice(1, -1).replace(/\\(\d{1,3}|[\s\S])/g, (_, c) =>
        /^\d/.test(c) ? String.fromCharCode(+c) : (ESC[c] !== undefined ? ESC[c] : c));
}

// W.X (or WLRT.X): the field name X, else null.
const W_BASES = new Set(["W", "WLRT"]);
function wField(n) {
    return n && n.type === "MemberExpression" && n.base.type === "Identifier" && W_BASES.has(n.base.name)
        ? n.identifier.name : null;
}

// Name of the function called: "W.Send", "L", ... (null for anything more complex).
function callee(n) {
    if (n.type !== "CallExpression" && n.type !== "StringCallExpression" && n.type !== "TableCallExpression") return null;
    const b = n.base;
    if (b.type === "Identifier") return b.name;
    const f = wField(b);
    return f ? "W." + f : null;
}
const callArgs = (n) => n.arguments || (n.argument ? [n.argument] : []);

// Checks across files and addons: W fields, /wl commands, module keys, addon-message prefixes, French texts.
function crossChecks() {
    const at = (file, n) => [file, n.loc.start.line];
    const core = parsed.find((p) => p.addon === ADDONS[0] && path.basename(p.file) === "Core.lua");
    const assigned = new Set(), used = []; // W fields
    const slash = new Map(), modules = new Map(), sends = new Map(), recvs = new Map(), texts = [], fr = new Map(); // English text -> { value, file, line }
    const SEND = new Set(["W.Send", "W.SendLong", "W.SendRaw", "W.Queue"]), RECV = new Set(["W.OnAddon", "W.OnAddonLong"]);
    const addKeys = (tbl, file) => {
        if (tbl && tbl.type === "TableConstructorExpression") for (const f of tbl.fields) {
            const k = f.type === "TableKey" ? luaStr(f.key) : undefined;
            if (k !== undefined) fr.set(k, { value: luaStr(f.value), file, line: f.loc.start.line });
        }
    };
    for (const { file, addon, ast } of parsed) {
        // local NAME = "string" constants of the file (addon-message prefixes are kept that way)
        const consts = new Map();
        const targets = new Set();
        walk(ast, (n) => {
            if (n.type === "LocalStatement") {
                n.variables.forEach((v, i) => {
                    const s = luaStr(n.init[i]);
                    if (s !== undefined) consts.set(v.name, s);
                    if (v.name === "FR") addKeys(n.init[i], file); // Locale.lua's base French table
                });
            } else if (n.type === "AssignmentStatement") {
                for (const t of n.variables) targets.add(t);
            } else if (n.type === "FunctionDeclaration" && n.identifier) {
                targets.add(n.identifier);
            }
        });
        const prefixOf = (arg) => {
            const s = luaStr(arg);
            if (s !== undefined) return s;
            return arg && arg.type === "Identifier" && consts.has(arg.name) ? consts.get(arg.name) : undefined;
        };
        walk(ast, (n) => {
            const f = wField(n);
            if (f) { if (targets.has(n)) assigned.add(f); else used.push([f, file, n]); }
            if (addon !== DEV && n.type === "MemberExpression" && targets.has(n) && wField(n.base) === "slash") slash.set(n.identifier.name, at(file, n));
            if (addon !== DEV && n.type === "IndexExpression" && targets.has(n) && wField(n.base) === "slash" && luaStr(n.index) !== undefined) {
                slash.set(luaStr(n.index), at(file, n));
            }
            const c = callee(n);
            if (!c) return;
            const a = callArgs(n);
            if (c === "W.AddFR") addKeys(a[0], file);
            else if (c === "L" || c === "W.L") { const s = luaStr(a[0]); if (s !== undefined) texts.push([s, file, n]); }
            else if (c === "W.RegisterModule") { const s = luaStr(a[0]); if (s !== undefined) modules.set(s, at(file, n)); }
            else if (SEND.has(c) || RECV.has(c)) {
                const p = prefixOf(a[0]);
                if (p === undefined) return; // a variable (the queue, the long-message layer): not a module's prefix
                const m = SEND.has(c) ? sends : recvs;
                if (!m.has(p)) m.set(p, { where: at(file, n), addon });
            }
        });
    }

    // 1. W.X read or called but never assigned in any of the three addons
    for (const [f, file, n] of used) if (!assigned.has(f)) report(file, n.loc.start.line, "W." + f + " is never assigned (typo or removed function?)");

    if (!core) { problems.push("Core.lua not found: /wl, CATEGORIES and lodPrefix checks skipped"); }
    else {
        // Core.lua tables: HELP (first string of each entry), CATEGORIES (every items list), lodPrefix (strings of its loop)
        const help = new Map(), cats = new Map(), lod = new Map(), direct = new Map();
        walk(core.ast, (n) => {
            if (n.type === "LocalStatement" && n.variables[0].name === "HELP") {
                for (const e of n.init[0].fields) {
                    const s = luaStr(e.value.fields && e.value.fields[0] && e.value.fields[0].value);
                    const m = s && s.match(/^\/wl\s+(\S+)/);
                    if (m) help.set(m[1], e.loc.start.line);
                }
            } else if (n.type === "LocalStatement" && n.variables[0].name === "CATEGORIES") {
                walk(n.init[0], (k) => {
                    if (k.type === "TableKeyString" && k.key.name === "items") for (const i of k.value.fields) {
                        // a merged entry: { "A", "B", label = ..., split = ... } lists its modules as plain values
                        const keys = i.value.type === "TableConstructorExpression"
                            ? i.value.fields.filter((x) => x.type === "TableValue").map((x) => x.value) : [i.value];
                        for (const v of keys) cats.set(luaStr(v), v.loc.start.line);
                    }
                });
            } else if (n.type === "ForGenericStatement" && n.body.some((st) => st.type === "AssignmentStatement" &&
                    st.variables[0].type === "IndexExpression" && st.variables[0].base.name === "lodPrefix")) {
                walk(n.iterators, (k) => { const s = luaStr(k); if (s !== undefined) lod.set(s, k.loc.start.line); });
            } else if (n.type === "BinaryExpression" && n.operator === "==" && n.left.type === "Identifier" && n.left.name === "cmd") {
                const s = luaStr(n.right); // commands handled directly in Slash (/wl minimap)
                if (s) direct.set(s, n.loc.start.line);
            }
        });
        // README.md "Commandes" section: first word after /wl in the first cell of each row
        const readme = path.join(root, ADDONS[0], "README.md");
        const doc = new Map();
        if (fs.existsSync(readme)) {
            let inCmds = false;
            fs.readFileSync(readme, "utf8").split("\n").forEach((l, i) => {
                if (/^## /.test(l)) inCmds = /^## Commandes/.test(l);
                const m = inCmds && l.match(/^\|\s*`\/wl\s+([^\s`]+)/);
                if (m) doc.set(m[1], i + 1);
            });
        } else problems.push(path.relative(root, readme) + ": not found");
        const coreFile = core.file;
        // 2. /wl sub-commands <-> HELP <-> README
        const cmds = new Set([...slash.keys(), ...direct.keys()]);
        for (const c of cmds) {
            const w = slash.get(c) || [coreFile, direct.get(c)];
            if (!help.has(c)) report(w[0], w[1], "/wl " + c + " missing from HELP (Core.lua)");
            if (!doc.has(c)) report(w[0], w[1], "/wl " + c + " missing from README.md Commandes");
        }
        for (const [c, line] of help) if (!cmds.has(c)) report(coreFile, line, "HELP lists /wl " + c + " but no W.slash." + c);
        for (const [c, line] of doc) if (!cmds.has(c)) report(readme, line, "README lists /wl " + c + " but no W.slash." + c);
        // 3. module keys <-> CATEGORIES
        for (const [k, w] of modules) if (!cats.has(k)) report(w[0], w[1], "module '" + k + "' missing from CATEGORIES (Core.lua)");
        for (const [k, line] of cats) if (!modules.has(k)) report(coreFile, line, "CATEGORIES lists '" + k + "' but no W.RegisterModule(\"" + k + "\")");
        // 4b. prefixes received by the raid addon must wake it up (lodPrefix), and only those
        for (const [p, r] of recvs) if (r.addon === ADDONS[1] && !lod.has(p)) report(r.where[0], r.where[1], "prefix " + p + " received by the raid addon but missing from lodPrefix (Core.lua)");
        for (const [p, line] of lod) if (!recvs.has(p) || recvs.get(p).addon !== ADDONS[1]) report(coreFile, line, "lodPrefix lists " + p + " but the raid addon does not receive it");
    }
    // 4. prefixes sent but never received, and the reverse
    for (const [p, s] of sends) if (!recvs.has(p)) report(s.where[0], s.where[1], "prefix " + p + " is sent but never received (W.OnAddon / W.OnAddonLong)");
    for (const [p, r] of recvs) if (!sends.has(p)) report(r.where[0], r.where[1], "prefix " + p + " is received but never sent (W.Send / W.SendLong / W.Queue)");
    // 5. L("text") without a French text (W.AddFR, Locale.lua's FR)
    for (const [s, file, n] of texts) if (!fr.has(s)) report(file, n.loc.start.line, "no French text for L(" + JSON.stringify(s) + ")");
    // 6. the French text keeps the English one's %s / %d (same order: string.format is positional) and color codes
    const specs = (t) => (t.replace(/%%/g, "").match(/%[-+ #0]*\d*(?:\.\d+)?[sdifgx]/g) || []).join(" ");
    const colors = (t) => (t.match(/\|c[0-9a-fA-F]{8}/g) || []).length + "/" + (t.match(/\|r/g) || []).length;
    for (const [en, e] of fr) {
        if (typeof e.value !== "string") continue;
        if (specs(en) !== specs(e.value)) report(e.file, e.line, "French text changes the format codes of " + JSON.stringify(en) + " (" + specs(en) + " vs " + specs(e.value) + ")");
        else if (colors(en) !== colors(e.value)) report(e.file, e.line, "French text changes the color codes (|c / |r) of " + JSON.stringify(en));
    }
}

let count = 0;
const versions = new Set();
const parsed = []; // { file, addon, ast } of every file that parsed, for the cross-file checks
for (const addon of ADDONS) {
    const dir = path.join(root, addon);
    if (!fs.existsSync(dir)) { problems.push(addon + ": folder not found under " + root); continue; }
    const toc = path.join(dir, addon + ".toc");
    if (addon !== DEV) try { // the three .toc files carry the same ## Version (the release workflow refuses the tag otherwise)
        const v = (fs.readFileSync(toc, "utf8").match(/^## Version:\s*(\S+)/m) || [])[1];
        if (!v) problems.push(path.relative(root, toc) + ": no ## Version line");
        else if (versions.size && !versions.has(v)) problems.push(path.relative(root, toc) + ": ## Version " + v + " differs from " + [...versions][0]);
        versions.add(v);
    } catch (e) { /* a missing .toc is reported below */ }
    const listed = new Set();
    // Files reached through the .toc, directly or through an .xml it lists (<Script file=> / <Include file=>).
    const addEntry = (base, rel, from, line) => {
        const p = path.normalize(path.join(base, rel.replace(/\\/g, "/")));
        if (!fs.existsSync(p)) { report(from, line, "listed file not found: " + rel); return; }
        listed.add(p.toLowerCase());
        if (p.endsWith(".xml")) {
            fs.readFileSync(p, "utf8").split("\n").forEach((l, i) => {
                const m = l.match(/<(?:Script|Include)\s+file="([^"]+)"/i);
                if (m) addEntry(path.dirname(p), m[1], p, i + 1);
            });
        }
    };
    if (!fs.existsSync(toc)) problems.push(path.relative(root, toc) + ": not found (WoW will not load " + addon + ")");
    else fs.readFileSync(toc, "utf8").split("\n").forEach((l, i) => {
        const s = l.trim();
        if (s && !s.startsWith("#")) addEntry(dir, s, toc, i + 1);
    });
    for (const f of luaFiles(dir)) {
        count++;
        if (!listed.has(path.normalize(f).toLowerCase())) report(f, 1, "not listed in " + addon + ".toc (WoW will not load it)");
        const ast = checkLua(f);
        if (ast) parsed.push({ file: f, addon, ast });
    }
}
if (parsed.length) crossChecks();

// The release notes are the lines of CHANGELOG.md under "## <version>" up to the next "## " (as the release workflow
// reads them): the version of the .toc files needs at least one "- " line there, or the tag would make a release
// without notes (or none at all). Another root (argv[2]) without the file is not checked.
const changelog = path.join(root, "CHANGELOG.md");
const tocVersion = [...versions][0];
if (!fs.existsSync(changelog)) {
    if (!process.argv[2]) problems.push("CHANGELOG.md: not found (the release notes come from it)");
} else if (tocVersion) {
    let inSection = false, notes = 0;
    for (const l of fs.readFileSync(changelog, "utf8").split(/\r?\n/)) {
        if (l.startsWith("## ")) {
            if (inSection) break;
            inSection = l.split(/\s+/)[1] === tocVersion;
        } else if (inSection && l.startsWith("- ")) notes++;
    }
    if (!notes) problems.push("CHANGELOG.md: no notes under \"## " + tocVersion + "\", the ## Version of the .toc files (rename \"## Prochaine version\" at a release)");
}

for (const p of problems) console.log(p);
console.log(count + " Lua files checked, " + problems.length + " problem(s).");
process.exit(problems.length ? 1 : 0);
