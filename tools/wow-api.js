// WarLegend RaidTool - the game's API, read from Blizzard's UI source (not shipped).
// Usage: node tools/wow-api.js check [--update]   API names the addon uses that this game build does not document
//        node tools/wow-api.js update            fetch the newest UI source
// The UI source is the community mirror of the game's own interface files, Gethe/wow-ui-source, branch "forever"
// (cloned once into tools/.cache/wow-ui-source, about 50 MB; WLRT_WUS=<folder> uses another checkout).
// Its Blizzard_APIDocumentationGenerated folder is Blizzard's own description of every C_ function, Enum and
// constant of the build. tools/smoke.js uses the same model to answer the addon's API calls with the right types.
// "check" prints only what is new compared to tools/api-baseline.txt (names already looked at), exit code 1 if any.
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");
const luaparse = require("luaparse");

const TOOLS = __dirname;
const REPO = path.join(TOOLS, "..");
const CACHE = path.join(TOOLS, ".cache");
const ADDONS = ["WarLegendRaidTool", "WarLegendRaidTool_Raid", "WarLegendRaidTool_PvP", "WarLegendRaidTool_Skyborne", "WarLegendRaidTool_Dev"];
const WUS_URL = "https://github.com/Gethe/wow-ui-source.git";
const WUS_BRANCH = process.env.WLRT_WUS_BRANCH || "forever";

function git(args, cwd) { return execFileSync("git", args, { cwd, stdio: ["ignore", "pipe", "pipe"] }).toString().trim(); }

// Path of the UI source checkout, cloned or updated when asked
function source(update) {
    if (process.env.WLRT_WUS) return path.resolve(process.env.WLRT_WUS);
    const dir = path.join(CACHE, "wow-ui-source");
    if (!fs.existsSync(path.join(dir, ".git"))) {
        fs.mkdirSync(CACHE, { recursive: true });
        console.error("Cloning " + WUS_URL + " (" + WUS_BRANCH + ") into tools/.cache ...");
        git(["-c", "core.longpaths=true", "clone", "--quiet", "--depth", "1", "--branch", WUS_BRANCH, "--single-branch", WUS_URL, dir]);
    } else if (update) {
        git(["fetch", "--quiet", "--depth", "1", "origin", WUS_BRANCH], dir);
        git(["reset", "--quiet", "--hard", "FETCH_HEAD"], dir);
    }
    return dir;
}

function files(dir, out, test) {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
        if (e.name === ".git" || e.name === "node_modules") continue;
        const p = path.join(dir, e.name);
        if (e.isDirectory()) files(p, out, test); else if (test(p)) out.push(p);
    }
    return out;
}

// Plain value of a Lua literal / table constructor of the documentation files (no code is run)
function value(n, enums) {
    if (!n) return undefined;
    switch (n.type) {
        case "StringLiteral": return n.value;
        case "NumericLiteral": return n.value;
        case "BooleanLiteral": return n.value;
        case "NilLiteral": return null;
        case "UnaryExpression": return n.operator === "-" ? -value(n.argument, enums) : undefined;
        case "MemberExpression": { // Enum.X.Y inside a constant
            const parts = [];
            for (let m = n; m; m = m.base) {
                if (m.type === "MemberExpression") parts.unshift(m.identifier.name);
                else if (m.type === "Identifier") { parts.unshift(m.name); break; } else return undefined;
            }
            if (parts[0] === "Enum" && enums && enums[parts[1]]) return enums[parts[1]][parts[2]];
            return undefined;
        }
        case "TableConstructorExpression": {
            const keyed = n.fields.some((f) => f.type === "TableKeyString");
            const out = keyed ? {} : [];
            for (const f of n.fields) {
                if (f.type === "TableKeyString") out[f.key.name] = value(f.value, enums);
                else if (f.type === "TableValue") (Array.isArray(out) ? out : (out.__list = out.__list || [])).push(value(f.value, enums));
            }
            return out;
        }
    }
    return undefined;
}

const STRINGISH = new Set(["string", "cstring", "WOWGUID", "textureAtlas", "textureKit", "uiUnit", "UnitToken", "UnitTokenVariant",
    "UnitTokenType", "kstringClubMessage", "kstringLfgListApplicant", "kstringLfgListChat", "kstringLfgListSearch", "ClubId", "ClubStreamId",
    "ClubInvitationId", "FileAsset", "mouseButton", "SingleColorValue"]);
const NUMBERISH = new Set(["number", "luaIndex", "fileID", "time_t", "BigUInteger", "BigInteger", "size", "uiMapID", "UiMapPoint_number",
    "SpellIdentifier", "FragmentID", "BagIndex", "WeeklyRewardItemDBID", "ModelSceneID", "ModelAsset", "AnimationDataEnum", "CalendarEventID",
    "RecruitAcceptanceID", "ProfessionID", "InventorySlots", "luaFunction_number", "ColorChannelNumber", "normalizedValue", "DurationSeconds"]);

// One character per return value: b = false, n = 0, s = "", t = {} (structure / table), x = unknown (nil);
// a "?" after it: Nilable, the stub returns nil there (the game often does).
function spec(returns, enums, structs) {
    if (!Array.isArray(returns)) return "";
    return returns.map((r) => {
        if (!r) return "x";
        const t = r.Type;
        let c = "x";
        if (t === "bool") c = "b";
        else if (STRINGISH.has(t)) c = "s";
        else if (NUMBERISH.has(t) || (enums && enums[t])) c = "n";
        else if (t === "table" || (structs && structs.has(t))) c = "t";
        return c + (r.Nilable ? "?" : "");
    }).join("");
}

// The model: fn["C_X.Y" or "Global"] = return spec, widget[method] = spec, enums, consts, frameXML global names
function model(wus) {
    const doc = path.join(wus, "Interface", "AddOns", "Blizzard_APIDocumentationGenerated");
    const systems = [];
    for (const f of files(doc, [], (p) => p.endsWith(".lua"))) {
        let ast;
        try { ast = luaparse.parse(fs.readFileSync(f, "latin1"), { luaVersion: "5.1", encodingMode: "pseudo-latin1" }); } catch (e) { continue; }
        for (const st of ast.body) {
            if (st.type === "LocalStatement" && st.init[0] && st.init[0].type === "TableConstructorExpression") systems.push(st.init[0]);
        }
    }
    // enums first: constants may use them
    const enums = {}, structs = new Set();
    const raw = systems.map((t) => value(t));
    for (const s of raw) for (const t of (s && s.Tables) || []) {
        if (t.Type === "Enumeration") { enums[t.Name] = {}; for (const fl of t.Fields || []) enums[t.Name][fl.Name] = fl.EnumValue; }
        else if (t.Type === "Structure") structs.add(t.Name);
    }
    const consts = {}, fn = {}, widget = {}, events = {};
    systems.forEach((tbl, i) => {
        const s = value(tbl, enums);
        if (!s) return;
        for (const t of s.Tables || []) if (t.Type === "Constants") { consts[t.Name] = {}; for (const v of t.Values || []) consts[t.Name][v.Name] = v.Value; }
        for (const e of s.Events || []) if (e.LiteralName) events[e.LiteralName] = (e.Payload || []).map((p) => p.Name);
        for (const f of s.Functions || []) {
            const sp = spec(f.Returns, enums, structs);
            if (s.Type === "ScriptObject") { if (!(f.Name in widget)) widget[f.Name] = sp; }
            else fn[(s.Namespace ? s.Namespace + "." : "") + f.Name] = sp;
        }
        void i;
    });
    // names the game's own Lua / XML defines (FrameXML): functions, tables, named frames, mixins.
    // Blizzard_Deprecated* apart: those shims load only while the CVar loadDeprecationFallbacks is on.
    const frameXML = new Set(), deprecated = new Set();
    for (const f of files(path.join(wus, "Interface"), [], (p) => /\.(lua|xml)$/.test(p) && !p.includes("Blizzard_APIDocumentation"))) {
        const src = fs.readFileSync(f, "latin1");
        if (f.endsWith(".lua")) {
            const into = /[\\/]Blizzard_Deprecated[^\\/]*[\\/]/.test(f) ? deprecated : frameXML;
            for (const x of src.matchAll(/^\s*function\s+([A-Za-z_]\w*)\s*\(/gm)) into.add(x[1]);
            for (const x of src.matchAll(/^\s*([A-Za-z_]\w*)\s*=[^=]/gm)) into.add(x[1]);
        } else {
            for (const x of src.matchAll(/\bname="([A-Za-z_]\w*)"/g)) frameXML.add(x[1]);
        }
    }
    let build = "?";
    try { build = git(["log", "-1", "--format=%s (%h, %cs)"], wus); } catch (e) { /* not a git checkout */ }
    return { fn, widget, enums, consts, structs, events, frameXML, deprecated, build };
}

// The model as a Lua file for the smoke test (tools/.cache/wow-api.lua)
function luaModel(m) {
    const q = (s) => JSON.stringify(String(s));
    const lit = (v) => (typeof v === "number" ? (Number.isFinite(v) ? String(v) : "0") : typeof v === "boolean" ? String(v) : typeof v === "string" ? q(v) : "nil");
    const out = ["-- generated by tools/wow-api.js from " + m.build.replace(/\n/g, " "), "return {", "fn = {"];
    for (const k of Object.keys(m.fn).sort()) out.push("[" + q(k) + "]=" + q(m.fn[k]) + ",");
    out.push("}, widget = {");
    for (const k of Object.keys(m.widget).sort()) out.push("[" + q(k) + "]=" + q(m.widget[k]) + ",");
    out.push("}, enums = {");
    for (const k of Object.keys(m.enums).sort()) out.push("[" + q(k) + "]={" + Object.entries(m.enums[k]).map(([a, b]) => "[" + q(a) + "]=" + lit(b)).join(",") + "},");
    out.push("}, consts = {");
    for (const k of Object.keys(m.consts).sort()) out.push("[" + q(k) + "]={" + Object.entries(m.consts[k]).map(([a, b]) => "[" + q(a) + "]=" + lit(b)).join(",") + "},");
    out.push("}, build = " + q(m.build) + " }");
    return out.join("\n") + "\n";
}

function luaFiles(dir, out) {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
        const p = path.join(dir, e.name);
        if (e.isDirectory()) { if (e.name !== "Libs") luaFiles(p, out); } else if (e.name.endsWith(".lua")) out.push(p);
    }
    return out;
}

// Does any ancestor test this name (if NAME / NAME and / or NAME / pcall(...)) or an earlier "if" of the block?
function mentions(node, name) {
    let hit = false;
    (function v(n) {
        if (hit || !n || typeof n !== "object") return;
        if (Array.isArray(n)) { n.forEach(v); return; }
        if (n.type === "Identifier" && n.name === name) { hit = true; return; }
        for (const k in n) if (k !== "loc" && k !== "range") v(n[k]);
    })(node);
    return hit;
}
function guarded(name, parents, line) {
    for (let i = parents.length - 1; i >= 0; i--) {
        const p = parents[i];
        if (p.type === "LogicalExpression" && mentions(p.left, name)) return true;
        if ((p.type === "IfClause" || p.type === "ElseifClause" || p.type === "WhileStatement") && mentions(p.condition, name)) return true;
        if (p.type === "ElseClause") return true; // the "if" before it tested something: legacy branch
        if (p.type === "CallExpression" && p.base.type === "Identifier" && p.base.name === "pcall") return true;
        if (Array.isArray(p.body)) for (const s of p.body) {
            if (s.loc.start.line >= line) break;
            if (s.type === "IfStatement" && mentions(s.clauses[0].condition, name)) return true;
        }
    }
    return false;
}

// What the addon uses that the build does not document: C_X.Y, Enum.X, Constants.X, and direct calls of
// globals that neither the documentation nor the game's Lua define (old C functions: they may exist, unverified)
function check(m) {
    const found = new Map(); // "kind name" -> [where]
    const add = (k, where) => { if (!found.has(k)) found.set(k, []); found.get(k).push(where); };
    const own = new Set(); // names the addon itself assigns at global scope
    const asts = [];
    for (const a of ADDONS) for (const f of luaFiles(path.join(REPO, a), [])) {
        const ast = luaparse.parse(fs.readFileSync(f, "utf8"), { luaVersion: "5.1", locations: true, scope: true });
        asts.push([path.relative(REPO, f).replace(/\\/g, "/"), ast]);
        (function v(n) {
            if (!n || typeof n !== "object") return;
            if (Array.isArray(n)) { n.forEach(v); return; }
            if (n.type === "AssignmentStatement") for (const t of n.variables) if (t.type === "Identifier" && t.isLocal === false) own.add(t.name);
            if (n.type === "FunctionDeclaration" && n.identifier && n.identifier.type === "Identifier" && !n.isLocal) own.add(n.identifier.name);
            for (const k in n) if (k !== "loc" && k !== "range") v(n[k]);
        })(ast);
    }
    for (const [rel, ast] of asts) {
        (function visit(n, parents) {
            if (!n || typeof n !== "object") return;
            if (Array.isArray(n)) { n.forEach((c) => visit(c, parents)); return; }
            const where = n.loc ? rel + ":" + n.loc.start.line : rel;
            if (n.type === "MemberExpression" && n.base.type === "Identifier" && n.base.isLocal === false) {
                const b = n.base.name, id = n.identifier.name;
                if (/^C_/.test(b) && !(b + "." + id in m.fn) && !m.frameXML.has(b)) add("undocumented " + b + "." + id, where);
                if (b === "Enum" && !(id in m.enums)) add("undocumented Enum." + id, where);
                if (b === "Constants" && !(id in m.consts)) add("undocumented Constants." + id, where);
            }
            if (n.type === "CallExpression" && n.base.type === "Identifier" && n.base.isLocal === false) {
                const name = n.base.name;
                if (/^[A-Z]/.test(name) && !(name in m.fn) && !m.frameXML.has(name) && !own.has(name)) {
                    const kind = m.deprecated.has(name) ? "deprecated shim" : "legacy";
                    add(kind + (guarded(name, parents, n.loc.start.line) ? " (guarded) " : " (no guard) ") + name, where);
                }
            }
            // local X = X: the calls go through the local, the global is read once here
            if (n.type === "LocalStatement") n.init.forEach((init) => {
                const name = init && init.type === "Identifier" && init.isLocal === false && init.name;
                if (name && /^[A-Z][a-z]/.test(name) && !(name in m.fn) && !m.frameXML.has(name) && !own.has(name)) {
                    add((m.deprecated.has(name) ? "deprecated shim" : "legacy") + " (local alias) " + name, where);
                }
            });
            const next = parents.concat([n]);
            for (const k in n) if (k !== "loc" && k !== "range") visit(n[k], next);
        })(ast, []);
    }
    return found;
}

module.exports = { source, model, luaModel };

if (require.main === module) {
    const cmd = process.argv[2] || "check";
    const update = cmd === "update" || process.argv.includes("--update");
    const wus = source(update);
    const m = model(wus);
    console.log("UI source: " + m.build + " - " + Object.keys(m.fn).length + " functions, " + Object.keys(m.enums).length + " enums");
    if (cmd === "update") process.exit(0);
    const baseFile = path.join(TOOLS, "api-baseline.txt");
    const base = new Set(fs.existsSync(baseFile) ? fs.readFileSync(baseFile, "utf8").split(/\r?\n/).map((s) => s.trim()).filter((s) => s && !s.startsWith("#")) : []);
    const found = check(m);
    let fresh = 0;
    for (const [k, where] of [...found].sort()) {
        if (base.has(k)) continue;
        fresh++;
        console.log(k + "  " + where.slice(0, 3).join(", ") + (where.length > 3 ? " +" + (where.length - 3) : ""));
    }
    for (const k of base) if (!found.has(k)) console.log("(baseline entry no longer found, can be removed: " + k + ")");
    console.log(found.size + " name(s) not documented, " + fresh + " new (not in tools/api-baseline.txt).");
    process.exit(fresh ? 1 : 0);
}
