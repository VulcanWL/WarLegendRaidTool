// WarLegend RaidTool - offline checks (not shipped: only the three addon folders go in the release zip).
// Usage: node tools/check.js [root]   (once: npm install --prefix tools)
//          (root = the folder holding the three addon folders, default: the repo)
// Prints only the problems, then one summary line. Exit code 1 when something is wrong.
// Checks: UTF-8 BOM / CRLF, Lua 5.1 syntax, .toc entries <-> files, global writes, unknown lowercase
// global reads, and names used above the line where the same file declares them local (nil in game).
"use strict";
const fs = require("fs");
const path = require("path");
const luaparse = require("luaparse");

const root = path.resolve(process.argv[2] || path.join(__dirname, ".."));
const ADDONS = ["WarLegendRaidTool", "WarLegendRaidTool_Raid", "WarLegendRaidTool_PvP"];

// Globals the addon may create (anything else written at global scope is an accident).
// ClickCastFrames: Clique's shared table (PvP frames register there).
const OK_WRITE = /^([A-Z0-9_]+|WLRT\w*|WarLegend\w*|ClickCastFrames)$/;
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
        return;
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

let count = 0;
for (const addon of ADDONS) {
    const dir = path.join(root, addon);
    if (!fs.existsSync(dir)) { problems.push(addon + ": folder not found under " + root); continue; }
    const toc = path.join(dir, addon + ".toc");
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
    fs.readFileSync(toc, "utf8").split("\n").forEach((l, i) => {
        const s = l.trim();
        if (s && !s.startsWith("#")) addEntry(dir, s, toc, i + 1);
    });
    for (const f of luaFiles(dir)) {
        count++;
        if (!listed.has(path.normalize(f).toLowerCase())) report(f, 1, "not listed in " + addon + ".toc (WoW will not load it)");
        checkLua(f);
    }
}

for (const p of problems) console.log(p);
console.log(count + " Lua files checked, " + problems.length + " problem(s).");
process.exit(problems.length ? 1 : 0);
