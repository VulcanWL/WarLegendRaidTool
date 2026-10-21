// WarLegend RaidTool - smoke test in a simulated client (not shipped).
// Usage: node tools/smoke.js [--fuzz N] [--verbose]     (once: npm install --prefix tools)
// Runs the four addons in fengari (a Lua VM in JavaScript) on top of tools/smoke/wow.lua, a small fake client whose
// API answers come from Blizzard's own API documentation of the current build (tools/wow-api.js, cached UI source).
// Plays tools/smoke/scenario.lua twice: a fresh install (English client), then a /reload with the saved data (French).
// Reports: Lua errors, protected actions in combat, messages sent by "Test all" or caused by hostile addon messages,
// the cost of event floods. It is NOT the game: it shows that the code runs with plausible answers, not that a feature
// does what it should in game (the user still tests with /reload). Exit code 1 when something is wrong.
const fs = require("fs");
const path = require("path");
const { lua, lauxlib, lualib, to_luastring } = require("fengari");
const api = require("./wow-api");

const TOOLS = __dirname;
const REPO = path.join(TOOLS, "..");
const ADDONS = ["WarLegendRaidTool", "WarLegendRaidTool_Raid", "WarLegendRaidTool_PvP", "WarLegendRaidTool_Skyborne"];
const args = process.argv.slice(2);
const opt = (name, def) => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : def; };
const verbose = args.includes("--verbose");

// the API model as Lua, rebuilt when the UI source changed
function apiModel() {
    const wus = api.source(false);
    const out = path.join(TOOLS, ".cache", "wow-api.lua");
    let head = "";
    try { head = require("child_process").execFileSync("git", ["rev-parse", "HEAD"], { cwd: wus }).toString().trim(); } catch (e) { /* no git */ }
    const stamp = out + ".stamp";
    if (!fs.existsSync(out) || !fs.existsSync(stamp) || fs.readFileSync(stamp, "utf8") !== head) {
        fs.mkdirSync(path.dirname(out), { recursive: true });
        fs.writeFileSync(out, api.luaModel(api.model(wus)));
        fs.writeFileSync(stamp, head);
    }
    return out;
}

// a .toc's files in load order (XML files: their <Script file> and <Include file>, recursively)
function tocFiles(addon) {
    const dir = path.join(REPO, addon);
    const toc = fs.readFileSync(path.join(dir, addon + ".toc"), "utf8");
    const saved = [];
    const out = [];
    const xml = (rel) => {
        const src = fs.readFileSync(path.join(dir, rel), "utf8").replace(/<!--[\s\S]*?-->/g, "");
        for (const m of src.matchAll(/<(Script|Include)\s+file="([^"]+)"/g)) {
            const f = path.posix.join(path.posix.dirname(rel.replace(/\\/g, "/")), m[2].replace(/\\/g, "/"));
            if (m[1] === "Include" || f.endsWith(".xml")) xml(f); else out.push(addon + "/" + f);
        }
    };
    for (let line of toc.split(/\r?\n/)) {
        line = line.trim();
        const sv = line.match(/^## SavedVariables(PerCharacter)?:\s*(.+)$/);
        if (sv) saved.push(...sv[2].split(",").map((s) => s.trim()).filter(Boolean));
        if (!line || line.startsWith("#")) continue;
        line = line.replace(/\\/g, "/").replace(/\s*\[.*\]\s*$/, "");
        if (line.endsWith(".xml")) xml(line); else if (line.endsWith(".lua")) out.push(addon + "/" + line);
    }
    return { files: out, saved };
}

const luaStr = (s) => '"' + String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n") + '"';

// the glue: file reading from JS, LoadAddOn, saved variables, JSON out
const GLUE = `
local modelPath, wowPath, scenarioPath, root, TOCS, SAVED, OPTS = ...
local API = load(SMOKE_READ(modelPath), "@wow-api.lua")()
local M = load(SMOKE_READ(wowPath), "@tools/smoke/wow.lua")(API)
M.locale = OPTS.locale
function M.LoadAddOn(name)
    local toc = TOCS[name]
    if not toc then return false end
    if M.loaded[name] then return true end
    M.loaded[name] = true
    local ns = {}
    for _, f in ipairs(toc.files) do
        local src = SMOKE_READ(root .. "/" .. f)
        if not src then M.Error("file listed in the .toc not found: " .. f)
        else
            local chunk, err = load(src, "@Interface/AddOns/" .. f)
            if not chunk then M.Error(err) else M.Call(chunk, name, ns) end
        end
    end
    for _, sv in ipairs(toc.saved) do
        if SAVED[sv] then
            local fn = load("return " .. SAVED[sv])
            _G[sv] = fn and fn() or nil
        end
    end
    M.Fire("ADDON_LOADED", name)
    return true
end
local report = load(SMOKE_READ(scenarioPath), "@tools/smoke/scenario.lua")(M, OPTS)

local function Ser(v, seen, depth)
    local t = type(v)
    if t == "string" then return string.format("%q", v) end
    if t == "number" then
        if v ~= v then return "0/0" elseif v == math.huge then return "math.huge" elseif v == -math.huge then return "-math.huge" end
        return string.format("%.17g", v)
    end
    if t == "boolean" then return tostring(v) end
    if t ~= "table" or seen[v] or depth > 40 then return "nil" end
    seen[v] = true
    local parts = {}
    for k, x in pairs(v) do
        if type(k) == "string" or type(k) == "number" then
            local kk = type(k) == "string" and string.format("[%q]", k) or ("[" .. Ser(k, seen, depth + 1) .. "]")
            local vv = Ser(x, seen, depth + 1)
            if vv ~= "nil" then parts[#parts + 1] = kk .. "=" .. vv end
        end
    end
    seen[v] = nil
    return "{" .. table.concat(parts, ",") .. "}"
end
local saved = {}
for _, toc in pairs(TOCS) do for _, sv in ipairs(toc.saved) do if rawget(_G, sv) ~= nil then saved[sv] = Ser(rawget(_G, sv), {}, 0) end end end

local function J(v, depth)
    depth = depth or 0
    local t = type(v)
    if t == "string" then
        return '"' .. v:gsub('[%c"\\\\\\128-\\255]', function(c) return string.format("\\\\u%04x", c:byte()) end) .. '"'
    elseif t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return "null" end
        return string.format("%.6g", v)
    elseif t == "boolean" then return tostring(v)
    elseif t == "table" and depth < 8 then
        local n = #v
        local parts = {}
        if n > 0 then
            for i = 1, n do parts[i] = J(v[i], depth + 1) end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        for k, x in pairs(v) do if type(k) == "string" then parts[#parts + 1] = J(k) .. ":" .. J(x, depth + 1) end end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "null"
end
local unknown = {}
for k, n in pairs(M.unknownReads) do unknown[#unknown + 1] = { k, n } end
table.sort(unknown, function(a, b) return a[2] > b[2] end)
local chatByPhase = {}
for _, c in ipairs(M.chat) do chatByPhase[#chatByPhase + 1] = { c.phase or "?", c.channel or "?", c.msg or "" } end
local addonByPrefix = {}
for _, a in ipairs(M.addon) do local k = (a.prefix or "?") .. " " .. (a.channel or "?"); addonByPrefix[k] = (addonByPrefix[k] or 0) + 1 end
return J({ report = report, errors = M.errors, blocked = M.blocked, sensitive = M.sensitive, chat = chatByPhase,
    addon = addonByPrefix, popups = M.popups or 0, unknown = unknown }), J(saved)
`;

function run(options, savedIn) {
    const L = lauxlib.luaL_newstate();
    lualib.luaL_openlibs(L);
    lua.lua_pushcfunction(L, (Ls) => {
        const p = lua.lua_tojsstring(Ls, 1);
        try { lua.lua_pushstring(Ls, new Uint8Array(fs.readFileSync(p))); return 1; } catch (e) { return 0; }
    });
    lua.lua_setglobal(L, to_luastring("SMOKE_READ"));
    if (lauxlib.luaL_loadbuffer(L, to_luastring(GLUE), null, to_luastring("@smoke-glue")) !== lua.LUA_OK) throw new Error(lua.lua_tojsstring(L, -1));
    const tocs = ADDONS.map((a) => {
        const t = tocFiles(a);
        return "[" + luaStr(a) + "]={files={" + t.files.map(luaStr).join(",") + "},saved={" + t.saved.map(luaStr).join(",") + "}}";
    });
    const savedLua = "{" + Object.entries(savedIn || {}).map(([k, v]) => "[" + luaStr(k) + "]=" + luaStr(v)).join(",") + "}";
    const version = (fs.readFileSync(path.join(REPO, ADDONS[0], ADDONS[0] + ".toc"), "utf8").match(/^## Version:\s*(\S+)/m) || [])[1] || "?";
    const optsLua = "{locale=" + luaStr(options.locale) + ",race=" + luaStr(options.race || "Human") + ",fuzz=" + Number(options.fuzz) + ",version=" + luaStr(version) + "}";
    for (const s of [apiModel(), path.join(TOOLS, "smoke", "wow.lua"), path.join(TOOLS, "smoke", "scenario.lua"), REPO]) lua.lua_pushstring(L, to_luastring(s));
    for (const s of ["{" + tocs.join(",") + "}", savedLua, optsLua]) {
        if (lauxlib.luaL_dostring(L, to_luastring("return " + s)) !== lua.LUA_OK) throw new Error(lua.lua_tojsstring(L, -1));
    }
    if (lua.lua_pcall(L, 7, 2, 0) !== lua.LUA_OK) throw new Error("smoke glue: " + lua.lua_tojsstring(L, -1));
    const out = JSON.parse(lua.lua_tojsstring(L, -2));
    const saved = JSON.parse(lua.lua_tojsstring(L, -1));
    return { out, saved };
}

// only our files in a stack trace
const ourTrace = (t) => (t || "").split("\n").filter((l) => /Interface\/AddOns\/WarLegend/.test(l)).slice(0, 4).map((l) => "      " + l.trim()).join("\n");

// an empty Lua table comes back as {}: a list is wanted
const list = (x) => (Array.isArray(x) ? x : []);
let bad = 0;
function show(title, { out }) {
    const r = out.report || {};
    console.log("== " + title);
    console.log("  access " + r.access + ", " + list(r.commands).length + " /wl commands (" + list(r.raidCommands).length + " in a raid), " + (r.tabs || 0) + " tabs, raid addon loaded: " + r.raidLoaded);
    const errors = list(out.errors);
    console.log("  Lua errors: " + errors.length);
    for (const e of errors) { console.log("    [" + e.phase + "] x" + e.count + " " + e.msg); if (verbose) console.log(ourTrace(e.trace)); }
    const blocked = list(out.blocked);
    console.log("  protected actions in combat (the game blocks them): " + blocked.length);
    for (const b of blocked.slice(0, 10)) console.log("    " + b);
    console.log("  'Test all' sent: " + (r.testChat || 0) + " chat line(s), " + (r.testAddon || 0) + " addon message(s)");
    const fuzz = list(r.fuzz);
    const fuzzChat = fuzz.reduce((a, f) => a + f.chat, 0), fuzzSens = fuzz.reduce((a, f) => a + f.sensitive, 0);
    console.log("  hostile addon messages: " + fuzz.length + " prefixes, " + fuzz.reduce((a, f) => a + f.sent, 0) + " messages -> " +
        fuzz.reduce((a, f) => a + f.replies, 0) + " addon replies, " + fuzzChat + " chat line(s), " + fuzzSens + " action(s) for the player");
    for (const f of fuzz) if (f.replies > f.sent / 10 || f.chat || f.sensitive || verbose) console.log("    " + f.prefix + ": " + f.replies + " replies, " + f.chat + " chat, " + f.sensitive + " actions");
    const replay = list(r.replay);
    const worst = replay.reduce((a, x) => (x.replies > a.replies ? x : a), { replies: 0 });
    const replayBad = replay.reduce((a, x) => a + x.chat + x.sensitive, 0);
    console.log("  own messages replayed by others: " + replay.length + " kinds x 100 -> at most " + worst.replies + " replies" +
        (worst.prefix ? " (" + worst.prefix + ")" : "") + ", " + replayBad + " chat line(s) / action(s)");
    for (const x of replay) if (x.chat || x.sensitive || x.replies > 20 || verbose) console.log("    " + x.prefix + " \"" + x.msg + "\": " + x.replies + " replies, " + x.chat + " chat, " + x.sensitive + " actions");
    bad += replayBad;
    const chat = list(out.chat);
    console.log("  chat lines sent (all phases): " + chat.length);
    for (const c of chat.slice(0, verbose ? 50 : 8)) console.log("    [" + c[0] + "] " + c[1] + ": " + String(c[2]).slice(0, 90));
    if (verbose) { console.log("  actions for the player: " + list(out.sensitive).join("; ")); console.log("  addon messages: " + JSON.stringify(out.addon)); }
    console.log("  cost of event floods (fengari ms, compare only):");
    for (const p of list(r.perf)) console.log("    " + p.label.padEnd(40) + p.ms.toFixed(0).padStart(7) + " ms");
    const idle = r.idle || {};
    console.log("  idle (windows closed): " + list(idle.frames).length + " OnUpdate script(s) running: " + list(idle.frames).join(", ") + "; " + idle.timers + " timer(s) pending");
    if (list(r.frameCosts).length) {
        console.log("  costliest event handlers during the floods (any frame, fengari ms total):");
        for (const c of list(r.frameCosts).slice(0, 6)) console.log("    " + String(c[0]).padEnd(60) + Number(c[1]).toFixed(1).padStart(8));
    }
    if (list(r.busiest).length) {
        console.log("  busiest work by the addon's own /wl perf (fengari ms total / count):");
        for (const b of r.busiest.slice(0, 8)) console.log("    " + String(b[0]).padEnd(50) + Number(b[3]).toFixed(1).padStart(8) + " / " + b[2]);
    }
    if (verbose && list(out.unknown).length) console.log("  globals read but nil here: " + out.unknown.slice(0, 40).map((u) => u[0]).join(" "));
    bad += errors.length + blocked.length + (r.testChat || 0) + (r.testAddon || 0) + fuzzChat + fuzzSens + (r.access === true ? 0 : 1);
}

const fuzz = Number(opt("--fuzz", 300));
const first = run({ locale: "enUS", fuzz });
show("fresh install, English client", first);
const second = run({ locale: "frFR", race: "Skyborne", fuzz: Math.max(1, Math.floor(fuzz / 3)) }, first.saved);
show("after /reload (saved data kept), French client, Skyborne character", second);
console.log(bad ? "Smoke test: " + bad + " problem(s)." : "Smoke test: no problem found (simulated client: still test in game).");
process.exit(bad ? 1 : 0);
