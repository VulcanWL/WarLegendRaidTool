// WarLegend RaidTool - the game's API, read from Blizzard's UI source (not shipped).
// Usage: node tools/wow-api.js check [--update]   API names the addon uses that this game build does not document
//        node tools/wow-api.js update            fetch the newest UI source
// The UI source is the community mirror of the game's own interface files, Gethe/wow-ui-source, branch "forever"
// (cloned once into tools/.cache/wow-ui-source, about 50 MB; WLRT_WUS=<folder> uses another checkout).
// Its Blizzard_APIDocumentationGenerated folder is Blizzard's own description of every C_ function, Enum and
// constant of the build. tools/smoke.js uses the same model to answer the addon's API calls with the right types, and
// to give secret values where the documentation says so.
// "check" prints only what is new compared to tools/api-baseline.txt (names already looked at), exit code 1 if any.
// It also lists "C_ form not tried first": a global Blizzard's own code no longer calls, whose replacement C_X.Name is
// documented (Forever loads none of the deprecation fallbacks: likely nil there), called without trying the C_ form first.
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

// The UI source holds the files of every client of the family (Vanilla, Wrath, Mainline...); the .toc files say which
// ones a client loads. Forever is the game type "camelot", part of "mainline" (Blizzard's .toc lines exclude camelot from
// mainline ones): [Game] = Camelot\, [Family] = Mainline\. "standard" (the main game mode of mainline) is kept too.
const GAME_TYPES = new Set(["camelot", "mainline", "standard"]);
function typesOk(text) {
    const list = (re) => { const m = text.match(re); return m ? m[1].split(/[\s,]+/).filter(Boolean).map((s) => s.toLowerCase()) : null; };
    const allow = list(/AllowLoadGameType:?\s*([^\]\r\n]*)/i), deny = list(/ExcludeLoadGameType:?\s*([^\]\r\n]*)/i);
    if (allow && !allow.some((t) => GAME_TYPES.has(t))) return false;
    return !(deny && deny.some((t) => GAME_TYPES.has(t)));
}
// The .lua / .xml files Forever loads in game (glue-screen addons and lines left out), XML includes followed
function loadedFiles(wus) {
    const out = new Set();
    const add = (p) => {
        if (out.has(p) || !fs.existsSync(p)) return;
        out.add(p);
        if (!p.endsWith(".xml")) return;
        const src = fs.readFileSync(p, "latin1").replace(/<!--[\s\S]*?-->/g, "");
        for (const x of src.matchAll(/<(?:Script|Include)\s+file="([^"]+)"/gi)) add(path.join(path.dirname(p), x[1].replace(/\\/g, "/")));
    };
    const root = path.join(wus, "Interface", "AddOns");
    for (const d of fs.readdirSync(root, { withFileTypes: true })) {
        if (!d.isDirectory()) continue;
        for (const t of fs.readdirSync(path.join(root, d.name)).filter((n) => n.endsWith(".toc"))) {
            const lines = fs.readFileSync(path.join(root, d.name, t), "latin1").split(/\r?\n/);
            const head = lines.filter((l) => l.startsWith("##")).join("\n");
            if (!typesOk(head) || /^##\s*AllowLoad:\s*glue\b/im.test(head)) continue;
            for (const l of lines) {
                const s = l.trim();
                if (!s || s.startsWith("#") || !typesOk(s) || /\[AllowLoad\s+glue\]/i.test(s)) continue;
                const rel = s.replace(/\s*\[[^\]]*\]/g, (m, i) => (i === 0 ? m : "")).trim()
                    .replace(/^\[Game\]/i, "Camelot").replace(/^\[Family\]/i, "Mainline").replace(/\\/g, "/");
                if (/\.(lua|xml)$/i.test(rel)) add(path.join(root, d.name, rel));
            }
        }
    }
    return out;
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
    const enums = {}, structs = new Set(), fieldsOf = {}, secretKinds = new Set();
    const raw = systems.map((t) => value(t));
    for (const s of raw) {
        for (const t of (s && s.Tables) || []) {
            if (t.Type === "Enumeration") { enums[t.Name] = {}; for (const fl of t.Fields || []) enums[t.Name][fl.Name] = fl.EnumValue; }
            else if (t.Type === "Structure") structs.add(t.Name);
        }
        // SecretPredicatesDocumentation.lua: the predicates of type "Secret" (SecretWhenCooldownsRestricted...)
        for (const p of (s && s.Predicates) || []) if (p.Type === "Secret") secretKinds.add(p.Name);
    }
    // a return / payload / structure field for the secret values of the smoke test: its type as a spec character, the
    // structure it is (or holds in a list), Nilable, NeverSecret, a unit token
    const char = (t) => spec([{ Type: t }], enums, structs)[0];
    const field = (r) => ({ name: r.Name, c: char(r.Type), struct: structs.has(r.Type) ? r.Type : undefined,
        inner: r.InnerType ? (structs.has(r.InnerType) ? r.InnerType : char(r.InnerType)) : undefined, nilable: !!r.Nilable, never: !!r.NeverSecret,
        unit: /^(UnitToken\w*|uiUnit)$/.test(r.Type) });
    const flags = (o) => Object.keys(o).filter((k) => secretKinds.has(k) && o[k] === true);
    const consts = {}, fn = {}, widget = {}, events = {}, secret = {}, secretEvents = {};
    systems.forEach((tbl, i) => {
        const s = value(tbl, enums);
        if (!s) return;
        for (const t of s.Tables || []) if (t.Type === "Constants") { consts[t.Name] = {}; for (const v of t.Values || []) consts[t.Name][v.Name] = v.Value; }
        for (const t of s.Tables || []) if (t.Type === "Structure") fieldsOf[t.Name] = (t.Fields || []).map(field);
        for (const e of s.Events || []) if (e.LiteralName) {
            events[e.LiteralName] = (e.Payload || []).map((p) => p.Name);
            if (flags(e).length) secretEvents[e.LiteralName] = { flags: flags(e), values: (e.Payload || []).map(field) };
        }
        for (const f of s.Functions || []) {
            const sp = spec(f.Returns, enums, structs);
            if (s.Type === "ScriptObject") { if (!(f.Name in widget)) widget[f.Name] = sp; continue; }
            const name = (s.Namespace ? s.Namespace + "." : "") + f.Name;
            fn[name] = sp;
            if (flags(f).length && !f.ReturnsNeverSecret) secret[name] = { flags: flags(f), values: (f.Returns || []).map(field) };
        }
        void i;
    });
    // names the game's own Lua / XML defines (FrameXML): functions, tables, named frames, mixins; only the files
    // Forever loads (loadedFiles). Blizzard_Deprecated* apart: those shims load only while the CVar
    // loadDeprecationFallbacks is on.
    // A shim's body names Blizzard's replacement (IsPlayerSpell calls C_SpellBook.IsSpellKnown): kept in replacement.
    // blizzCalls: global functions the rest of that code calls (the game has them, documented or not)
    const frameXML = new Set(), deprecated = new Set(), replacement = {}, blizzCalls = new Set();
    for (const f of loadedFiles(wus)) {
        if (f.includes("Blizzard_APIDocumentation")) continue;
        const src = fs.readFileSync(f, "latin1");
        if (f.endsWith(".lua")) {
            const shim = /[\\/]Blizzard_Deprecated[^\\/]*[\\/]/.test(f);
            const into = shim ? deprecated : frameXML;
            for (const x of src.matchAll(/^\s*function\s+([A-Za-z_]\w*)\s*\(/gm)) into.add(x[1]);
            for (const x of src.matchAll(/^\s*([A-Za-z_]\w*)\s*=[^=]/gm)) into.add(x[1]);
            if (shim) shimReplacements(src, replacement);
            else {
                const code = src.replace(/--\[(=*)\[[\s\S]*?\]\1\]/g, "").replace(/--[^\n]*/g, "");
                for (const x of code.matchAll(/(?:^|[^.:\w])([A-Z]\w*)\s*\(/gm)) blizzCalls.add(x[1]);
            }
        } else {
            for (const x of src.matchAll(/\bname="([A-Za-z_]\w*)"/g)) frameXML.add(x[1]);
        }
    }
    let build = "?";
    try { build = git(["log", "-1", "--format=%s (%h, %cs)"], wus); } catch (e) { /* not a git checkout */ }
    // only the structures the secret functions / events hold (the smoke test fills them)
    const used = {};
    const reach = (vals) => { for (const v of vals) for (const s of [v.struct, v.inner]) if (s && fieldsOf[s] && !used[s]) { used[s] = fieldsOf[s]; reach(fieldsOf[s]); } };
    for (const x of [...Object.values(secret), ...Object.values(secretEvents)]) reach(x.values);
    return { fn, widget, enums, consts, structs, events, frameXML, deprecated, replacement, blizzCalls, secret, secretEvents, secretStructs: used, build };
}

// Global functions of a Blizzard_Deprecated* file and the C_X.Y functions each one calls or is set to
function shimReplacements(src, out) {
    let ast;
    try { ast = luaparse.parse(src, { luaVersion: "5.1", encodingMode: "pseudo-latin1" }); } catch (e) { return; }
    const cCalls = (n, into) => {
        if (!n || typeof n !== "object") return;
        if (Array.isArray(n)) { n.forEach((c) => cCalls(c, into)); return; }
        if (n.type === "MemberExpression" && n.base.type === "Identifier" && /^C_/.test(n.base.name)) into.add(n.base.name + "." + n.identifier.name);
        for (const k in n) if (k !== "loc" && k !== "range") cCalls(n[k], into);
    };
    const add = (name, node) => { const s = out[name] || new Set(); cCalls(node, s); if (s.size) out[name] = s; };
    (function v(n) {
        if (!n || typeof n !== "object") return;
        if (Array.isArray(n)) { n.forEach(v); return; }
        if (n.type === "FunctionDeclaration" && !n.isLocal && n.identifier && n.identifier.type === "Identifier") add(n.identifier.name, n.body);
        if (n.type === "AssignmentStatement") n.variables.forEach((t, i) => { if (t.type === "Identifier") add(t.name, n.init[i]); });
        for (const k in n) if (k !== "loc" && k !== "range") v(n[k]);
    })(ast);
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
    // secret values: the functions / events flagged with a Secret predicate, their returns / payload, the structures
    // these hold ({ name, c = spec character, struct, inner, nilable, never = NeverSecret, unit = a unit token })
    const fld = (v) => "{" + ["name=" + q(v.name), "c=" + q(v.c), v.struct && "struct=" + q(v.struct), v.inner && "inner=" + q(v.inner),
        v.nilable && "nilable=true", v.never && "never=true", v.unit && "unit=true"].filter(Boolean).join(",") + "}";
    const entry = (x) => "{flags={" + x.flags.map(q).join(",") + "},values={" + x.values.map(fld).join(",") + "}}";
    out.push("}, secret = {");
    for (const k of Object.keys(m.secret).sort()) out.push("[" + q(k) + "]=" + entry(m.secret[k]) + ",");
    out.push("}, secretEvents = {");
    for (const k of Object.keys(m.secretEvents).sort()) out.push("[" + q(k) + "]=" + entry(m.secretEvents[k]) + ",");
    out.push("}, secretStructs = {");
    for (const k of Object.keys(m.secretStructs).sort()) out.push("[" + q(k) + "]={" + m.secretStructs[k].map(fld).join(",") + "},");
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

// Is the C_ form (forms: "C_X.Name") tried before node? Yes when the function around it (or the file) names C_X.Name
// above it (anywhere: for a local alias, used below; a C_X.NameByID counts for Name), or when node is the fallback of
// an "if" that tests a function of the same C_X: in a later branch of it, or below it in the same block.
function triedFirst(forms, node, parents, anywhere) {
    const scope = [...parents].reverse().find((p) => p.type === "FunctionDeclaration" || p.type === "Chunk");
    if (!scope) return false;
    const at = node.loc.start;
    const wanted = forms.map((f) => f.split("."));
    let hit = false;
    (function v(n) {
        if (hit || !n || typeof n !== "object") return;
        if (Array.isArray(n)) { n.forEach(v); return; }
        if (n.type === "MemberExpression" && n.base.type === "Identifier" && wanted.some(([ns, y]) => n.base.name === ns && n.identifier.name.startsWith(y))) {
            const l = n.loc.start;
            if (anywhere || l.line < at.line || (l.line === at.line && l.column < at.column)) { hit = true; return; }
        }
        for (const k in n) if (k !== "loc" && k !== "range") v(n[k]);
    })(scope);
    if (hit || anywhere) return hit;
    const spaces = new Set(wanted.map(([ns]) => ns));
    const tests = (cond) => { let t = false; (function v(n) {
        if (t || !n || typeof n !== "object") return;
        if (Array.isArray(n)) { n.forEach(v); return; }
        if (n.type === "Identifier" && spaces.has(n.name)) { t = true; return; }
        for (const k in n) if (k !== "loc" && k !== "range") v(n[k]);
    })(cond); return t; };
    for (let i = parents.length - 1; i >= 0; i--) {
        const p = parents[i], child = parents[i + 1];
        if (p.type === "IfStatement") {
            const k = p.clauses.indexOf(child);
            for (let j = 0; j < k; j++) if (tests(p.clauses[j].condition)) return true;
        }
        if (Array.isArray(p.body)) for (const s of p.body) {
            if (s === child || s.loc.start.line >= at.line) break;
            if (s.type === "IfStatement" && tests(s.clauses[0].condition)) return true;
        }
        if (p === scope) break;
    }
    return false;
}

// What the addon uses that the build does not document: C_X.Y, Enum.X, Constants.X, and direct calls of
// globals that neither the documentation nor the game's Lua define (old C functions: they may exist, unverified)
function check(m) {
    const found = new Map(); // "kind name" -> [where]
    const add = (k, where) => { if (!found.has(k)) found.set(k, []); found.get(k).push(where); };
    // Forever loads none of Blizzard's deprecation fallbacks: an undocumented global that Blizzard's own code no longer
    // calls and whose replacement is documented (C_X.Name, or the C_ function its Blizzard_Deprecated shim calls) is
    // likely nil there. The code must try the C_ form first, above it in the same function ("C_X and C_X.Name(...) or
    // Name(...)"; for a local alias anywhere in its scope), else it is listed
    const cForms = {};
    for (const k of Object.keys(m.fn)) {
        const d = k.indexOf(".");
        if (d > 0 && /^C_/.test(k)) (cForms[k.slice(d + 1)] = cForms[k.slice(d + 1)] || []).push(k);
    }
    const noFallback = (name, node, parents, where, alias) => {
        if (m.blizzCalls.has(name)) return;
        const forms = [...new Set([...(cForms[name] || []), ...[...(m.replacement[name] || [])].filter((k) => k in m.fn)])].sort();
        if (forms.length && !triedFirst(forms, node, parents, alias)) add("C_ form not tried first " + name + " (" + forms.join(", ") + ")", where);
    };
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
            // hooksecurefunc("Name", fn): the game raises an error when Name is not a function, a guarded hook on a
            // missing one never runs (the feature it feeds is dead on Forever)
            if (n.type === "CallExpression" && n.base.type === "Identifier" && n.base.name === "hooksecurefunc" &&
                    n.arguments[0] && n.arguments[0].type === "StringLiteral") {
                const name = n.arguments[0].raw.slice(1, -1);
                if (!(name in m.fn) && !m.frameXML.has(name) && !own.has(name)) {
                    const kind = m.deprecated.has(name) ? "hook on a deprecated shim" : "hook on a missing function";
                    add(kind + (guarded(name, parents, n.loc.start.line) ? " (guarded) " : " (no guard) ") + name, where);
                }
            }
            if (n.type === "CallExpression" && n.base.type === "Identifier" && n.base.isLocal === false) {
                const name = n.base.name;
                if (/^[A-Z]/.test(name) && !(name in m.fn) && !m.frameXML.has(name) && !own.has(name)) {
                    const kind = m.deprecated.has(name) ? "deprecated shim" : "legacy";
                    add(kind + (guarded(name, parents, n.loc.start.line) ? " (guarded) " : " (no guard) ") + name, where);
                    noFallback(name, n, parents, where);
                }
            }
            // local X = X: the calls go through the local, the global is read once here
            if (n.type === "LocalStatement") n.init.forEach((init) => {
                const name = init && init.type === "Identifier" && init.isLocal === false && init.name;
                if (name && /^[A-Z][a-z]/.test(name) && !(name in m.fn) && !m.frameXML.has(name) && !own.has(name)) {
                    add((m.deprecated.has(name) ? "deprecated shim" : "legacy") + " (local alias) " + name, where);
                    noFallback(name, init, parents.concat([n]), where, true);
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
