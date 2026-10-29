// WarLegend RaidTool - smoke test in a simulated client (not shipped).
// Usage: node tools/smoke.js [--fuzz N] [--seed S] [--verbose] [--quiet] [--open-world] [--bg]    (once: cd tools && npm install)
// Runs the four addons in fengari (a Lua VM in JavaScript) on top of tools/smoke/wow.lua, a small fake client whose
// API answers come from Blizzard's own API documentation of the current build (tools/wow-api.js, cached UI source).
// Plays tools/smoke/scenario.lua twice: a fresh install (English client), then a /reload with the saved data (French).
// Reports: Lua errors, protected actions in combat, messages sent by "Test all" or caused by hostile addon messages or
// chat lines, escape codes of other players shown live, pasted texts (profile, Myslot, preset, soft-res), the cost of
// event floods. The hostile messages come from --seed (default 12345): the same seed and --fuzz send the same ones, and
// the message behind the first Lua error of each prefix / event is printed. It is NOT the game: it shows that the code
// runs with plausible answers, not that a feature does what it should in game (the user still tests with /reload).
// --quiet prints only what fails, under one line per pass (counts, seconds): same problems counted, same exit code
// (agents run it first, then --verbose on a failure). Exit code 1 when something is wrong.
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
const quiet = args.includes("--quiet");

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
-- --quiet: what the addons print (a chat line in the game) is not written out; wow.lua still reads it
if OPTS.quiet then print = function() end end
local API = load(SMOKE_READ(modelPath), "@wow-api.lua")()
local M = load(SMOKE_READ(wowPath), "@tools/smoke/wow.lua")(API)
M.locale = OPTS.locale
-- fengari's integers have 32 bits: a hex literal past them wraps (0x100000000 is 0 there, "n % 0" an error), the game
-- (Lua 5.1, only doubles) reads the number: written as that number (Myslot's protobuf library)
local function Wide(h)
    local v = 0.0
    for d in h:gmatch(".") do v = v * 16 + tonumber(d, 16) end
    return string.format("%.1f", v)
end
function M.LoadAddOn(name)
    local toc = TOCS[name]
    if not toc then return false end
    if M.loaded[name] then return true end
    M.loaded[name] = true
    local ns = {}
    for _, f in ipairs(toc.files) do
        local src = SMOKE_READ(root .. "/" .. f)
        if src then src = src:gsub("0[xX](%x%x%x%x%x%x%x%x%x+)", Wide) end
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
    const t0 = Date.now();
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
    const optsLua = "{locale=" + luaStr(options.locale) + ",race=" + luaStr(options.race || "Human") + ",fuzz=" + Number(options.fuzz) +
        ",seed=" + Number(options.seed || 12345) + ",version=" + luaStr(version) + ",quiet=" + quiet + "}";
    for (const s of [apiModel(), path.join(TOOLS, "smoke", "wow.lua"), path.join(TOOLS, "smoke", options.scenario || "scenario.lua"), REPO]) lua.lua_pushstring(L, to_luastring(s));
    // the saved data came back from the first run as one character per byte (J in the glue): pushed back byte for byte
    // (latin1), not re-encoded as UTF-8 (to_luastring), so "é" stays the two bytes the addon saved
    for (const [s, bytes] of [["{" + tocs.join(",") + "}", to_luastring], [savedLua, (x) => new Uint8Array(Buffer.from(x, "latin1"))], [optsLua, to_luastring]]) {
        if (lauxlib.luaL_loadbuffer(L, bytes("return " + s), null, to_luastring("=smoke-args")) !== lua.LUA_OK ||
            lua.lua_pcall(L, 0, 1, 0) !== lua.LUA_OK) throw new Error(lua.lua_tojsstring(L, -1));
    }
    if (lua.lua_pcall(L, 7, 2, 0) !== lua.LUA_OK) throw new Error("smoke glue: " + lua.lua_tojsstring(L, -1));
    const out = JSON.parse(lua.lua_tojsstring(L, -2));
    const saved = JSON.parse(lua.lua_tojsstring(L, -1));
    return { out, saved, sec: (Date.now() - t0) / 1000 };
}

// only our files in a stack trace
const ourTrace = (t) => (t || "").split("\n").filter((l) => /Interface\/AddOns\/WarLegend/.test(l)).slice(0, 4).map((l) => "      " + l.trim()).join("\n");

// an empty Lua table comes back as {}: a list is wanted
const list = (x) => (Array.isArray(x) ? x : []);
let bad = 0;
// a pass's lines, each marked when it shows a problem counted in bad (or the section of one): all of them by default,
// only those under one line of counts and seconds with --quiet
function Printer() {
    const lines = [];
    const say = (text, fails) => { lines.push([text, !!fails]); };
    say.flush = (title, summary) => {
        console.log("== " + title + (quiet ? ": " + summary : ""));
        for (const [text, fails] of lines) if (fails || !quiet) console.log(text);
    };
    return say;
}
function show(title, { out, sec }) {
    const r = out.report || {};
    const say = Printer();
    const before = bad;
    say("  access " + r.access + ", " + list(r.commands).length + " /wl commands (" + list(r.raidCommands).length + " in a raid), " + (r.tabs || 0) + " tabs, raid addon loaded: " + r.raidLoaded, r.access !== true);
    const errors = list(out.errors);
    say("  Lua errors: " + errors.length, errors.length);
    for (const e of errors) { say("    [" + e.phase + "] x" + e.count + " " + e.msg, true); if (verbose) say(ourTrace(e.trace), true); }
    const blocked = list(out.blocked);
    say("  protected actions in combat (the game blocks them): " + blocked.length, blocked.length);
    for (const b of blocked.slice(0, 10)) say("    " + b, true);
    say("  'Test all' sent: " + (r.testChat || 0) + " chat line(s), " + (r.testAddon || 0) + " addon message(s)", r.testChat || r.testAddon);
    const fuzz = list(r.fuzz);
    const fuzzChat = fuzz.reduce((a, f) => a + f.chat, 0), fuzzSens = fuzz.reduce((a, f) => a + f.sensitive, 0);
    const fuzzSent = fuzz.reduce((a, f) => a + f.sent, 0);
    say("  hostile addon messages (seed " + r.seed + "): " + fuzz.length + " prefixes, " + fuzzSent + " messages -> " +
        fuzz.reduce((a, f) => a + f.replies, 0) + " addon replies, " + fuzzChat + " chat line(s), " + fuzzSens + " action(s) for the player", fuzzChat + fuzzSens);
    for (const f of fuzz) if (f.replies > f.sent / 10 || f.chat || f.sensitive || verbose) say("    " + f.prefix + ": " + f.replies + " replies, " + f.chat + " chat, " + f.sensitive + " actions", f.chat || f.sensitive);
    // the input behind the first Lua error (counted with the errors above): node tools/smoke.js --seed S --fuzz N sends it again
    const blame = (what, f, channel) => say("    first Lua error on " + what + ": " + (f.later ? "in a timer after " : "") + "message " + f.n +
        " from " + f.from + (channel ? " (" + channel + ")" : "") + ": " + f.msg + "\n      -> " + f.err, true);
    for (const f of fuzz) if (f.first) blame(f.prefix, f.first, f.first.channel);
    const replay = list(r.replay);
    const worst = replay.reduce((a, x) => (x.replies > a.replies ? x : a), { replies: 0 });
    const replayBad = replay.reduce((a, x) => a + x.chat + x.sensitive, 0);
    say("  own messages replayed by others: " + replay.length + " kinds x 100 -> at most " + worst.replies + " replies" +
        (worst.prefix ? " (" + worst.prefix + ")" : "") + ", " + replayBad + " chat line(s) / action(s)", replayBad);
    for (const x of replay) if (x.chat || x.sensitive || x.replies > 20 || verbose) say("    " + x.prefix + " \"" + x.msg + "\": " + x.replies + " replies, " + x.chat + " chat, " + x.sensitive + " actions", x.chat || x.sensitive);
    bad += replayBad;
    const sh = r.shaped || {};
    say("  shaped hostile messages (own messages with a marked field, fields shown by Classes / Layers / Raid Buffs): " + (sh.sent || 0) +
        " -> " + (sh.replies || 0) + " addon replies, " + (sh.chat || 0) + " chat line(s), " + (sh.sensitive || 0) + " action(s) for the player", (sh.chat || 0) + (sh.sensitive || 0));
    if (sh.first) blame("a shaped message (" + sh.first.channel + ")", sh.first);
    bad += (sh.chat || 0) + (sh.sensitive || 0);
    // chat lines of other players: < 1 s each, no chat line, no action, but AGENTS.md's accepted exceptions
    const cl = r.chatLines || {};
    const clKinds = [list(cl.bad), list(cl.badActions), list(cl.badChat)];
    const clBad = clKinds.reduce((a, k) => a + k.length, 0);
    say("  chat lines from other players: " + (cl.sent || 0) + " lines on " + (cl.events || 0) + " events (as installed, then InviteTool / !sr / Summon on) -> worst " +
        Number(cl.worst || 0).toFixed(0) + " ms" + (cl.worstEvent ? " (" + cl.worstEvent + ")" : "") + "; accepted: " + (cl.actionsOk || 0) +
        " keyword invite(s), " + (cl.chatOk || 0) + " !sr answer(s); not allowed: " + list(cl.badActions).length + " action(s), " +
        list(cl.badChat).length + " chat line(s), " + list(cl.bad).length + " other", clBad);
    for (const k of clKinds) {
        for (const b of k.slice(0, verbose ? 200 : 5)) say("    FAIL " + b, true);
        if (k.length > 5 && !verbose) say("    ... " + (k.length - 5) + " more of this kind (--verbose)", true);
    }
    for (const [ev, f] of Object.entries(cl.first || {})) blame(ev, f);
    bad += clBad;
    // pasted texts: < 1 s, refused or in the confirmation with the saved data untouched, or saved in a checked form
    const paste = list(r.paste);
    const pasteBad = paste.filter((p) => p.fail);
    const slow = paste.reduce((a, p) => ((p.ms || 0) > a.ms ? p : a), { ms: 0 });
    say("  pasted text: " + paste.length + " cases (profile, Myslot, Raid Groups preset, soft-res CSV) -> slowest " + slow.ms.toFixed(0) + " ms" +
        (slow.case ? " (" + slow.importer + ", " + slow.case + ", " + slow.size + " bytes)" : "") + "; problems: " + pasteBad.length, pasteBad.length);
    for (const p of paste) {
        if (p.fail || verbose) say("    " + (p.fail ? "FAIL " : "ok   ") + p.importer + ", " + p.case + ": " +
            (p.fail || (p.size + " bytes, " + (p.ms || 0).toFixed(0) + " ms, " + p.outcome)), p.fail);
    }
    bad += pasteBad.length;
    // escape codes from the hostile pieces shown live (tools/smoke/wow.lua M.Shown), with the line that showed them
    const esc = list(r.escapes);
    const reached = list(r.reached);
    say("  escape codes of other players shown live (|T |A |K, |H not an item, line breaks): " + esc.length + " (their text reached the screen at " +
        reached.length + " place(s)" + (verbose ? ": " + reached.map((x) => x[0] + " x" + x[1]).join(", ") : ", --verbose lists them") + ")", esc.length);
    for (const e of esc) say("    FAIL " + e.code + " shown by " + e.at + " (" + e.kind + ", " + e.phase + ", x" + e.count + "): " + JSON.stringify(e.sample), true);
    bad += esc.length;
    // what was sent: shown with --quiet too when a chat line or an action above is counted
    const sentChat = (r.testChat || 0) + fuzzChat + replay.reduce((a, x) => a + x.chat, 0) + (sh.chat || 0);
    const sentActions = fuzzSens + replay.reduce((a, x) => a + x.sensitive, 0) + (sh.sensitive || 0);
    const chat = list(out.chat);
    say("  chat lines sent (all phases): " + chat.length, sentChat);
    for (const c of chat.slice(0, verbose ? 50 : 8)) say("    [" + c[0] + "] " + c[1] + ": " + String(c[2]).slice(0, 90), sentChat);
    if (verbose) { say("  actions for the player: " + list(out.sensitive).join("; "), sentActions); say("  addon messages: " + JSON.stringify(out.addon), r.testAddon); }
    say("  cost of event floods (fengari ms, compare only):");
    for (const p of list(r.perf)) say("    " + p.label.padEnd(40) + p.ms.toFixed(0).padStart(7) + " ms");
    const idle = r.idle || {};
    say("  idle (windows closed): " + list(idle.frames).length + " OnUpdate script(s) running: " + list(idle.frames).join(", ") + "; " + idle.timers + " timer(s) pending");
    if (list(r.frameCosts).length) {
        say("  costliest event handlers / OnUpdate scripts during the floods and the idle time (any frame, fengari ms total):");
        for (const c of list(r.frameCosts).slice(0, 6)) say("    " + String(c[0]).padEnd(60) + Number(c[1]).toFixed(1).padStart(8));
    }
    if (list(r.busiest).length) {
        say("  busiest work by the addon's own /wl perf (fengari ms total / count):");
        for (const b of r.busiest.slice(0, 8)) say("    " + String(b[0]).padEnd(50) + Number(b[3]).toFixed(1).padStart(8) + " / " + b[2]);
    }
    if (verbose && list(out.unknown).length) say("  globals read but nil here: " + out.unknown.slice(0, 40).map((u) => u[0]).join(" "));
    const failedChecks = list(r.checks).filter((c) => !c.ok);
    say("  trust checks: " + (list(r.checks).length - failedChecks.length) + " / " + list(r.checks).length + " passed", failedChecks.length);
    for (const c of failedChecks) say("    FAIL " + c.name + (c.detail !== undefined ? " (" + c.detail + ")" : ""), true);
    bad += failedChecks.length;
    bad += errors.length + blocked.length + (r.testChat || 0) + (r.testAddon || 0) + fuzzChat + fuzzSens + (r.access === true ? 0 : 1);
    const problems = bad - before;
    say.flush(title, (problems ? problems + " problem(s)" : "no problem") + " in " + sec.toFixed(0) + " s (" + errors.length + " Lua error(s), " +
        blocked.length + " blocked, " + (fuzzSent + (sh.sent || 0)) + " hostile messages, " + (cl.sent || 0) + " chat lines, " + paste.length + " pastes, " +
        esc.length + " escape codes, " + (list(r.checks).length - failedChecks.length) + " / " + list(r.checks).length + " trust checks)");
}

// --open-world: tools/smoke/openworld.lua instead (one pass, English client): a raid of 40 and a guild of 120 in the
// open world: enemy player frames of the danger alert, cost of the raid / guild traffic, guild members on the maps
// --bg: tools/smoke/battleground.lua (one pass, English client, Skyborne character): Alterac Valley 40 vs 40, the cost
// of each frame (worst, average) at rest, in a fight, dead, while the raid changes; the frames of the PvP addon
function showOpenWorld({ out, sec }) {
    const r = out.report || {};
    const say = Printer();
    const before = bad;
    say("  access " + r.access + ", guild " + r.guild + " members, raid addon loaded: " + r.raidLoaded + ", PvP addon loaded: " + r.pvpLoaded +
        (r.skyLoaded !== undefined ? ", Skyborne addon loaded: " + r.skyLoaded : ""), r.access !== true);
    const errors = list(out.errors);
    say("  Lua errors: " + errors.length, errors.length);
    for (const e of errors) { say("    [" + e.phase + "] x" + e.count + " " + e.msg, true); if (verbose) say(ourTrace(e.trace), true); }
    const blocked = list(out.blocked);
    say("  protected actions in combat (the game blocks them): " + blocked.length, blocked.length);
    for (const b of blocked.slice(0, 10)) say("    " + b, true);
    for (const s of list(r.sections)) {
        say("  " + s.title);
        for (const l of list(s.lines)) say("    " + l);
    }
    const checks = list(r.checks);
    const failed = checks.filter((c) => !c.ok).length;
    say("  checks:", failed);
    for (const c of checks) if (!c.ok || verbose) say("    " + (c.ok ? "ok   " : "FAIL ") + c.name + (c.detail ? " (" + c.detail + ")" : ""), !c.ok);
    say("    " + (checks.length - failed) + " / " + checks.length + " passed", failed);
    const chat = list(out.chat);
    say("  chat lines sent: " + chat.length, chat.length);
    for (const c of chat.slice(0, 8)) say("    [" + c[0] + "] " + c[1] + ": " + String(c[2]).slice(0, 90), true);
    if (verbose) say("  addon messages sent: " + JSON.stringify(out.addon));
    bad += errors.length + blocked.length + failed + chat.length + (r.access === true ? 0 : 1);
    const problems = bad - before;
    say.flush(r.title || "open world: raid of 40, guild of 120", (problems ? problems + " problem(s)" : "no problem") + " in " + sec.toFixed(0) + " s (" +
        errors.length + " Lua error(s), " + blocked.length + " blocked, " + (checks.length - failed) + " / " + checks.length + " checks, " + chat.length + " chat lines)");
}
if (args.includes("--bg")) {
    showOpenWorld(run({ locale: "enUS", race: "Skyborne", fuzz: 0, scenario: "battleground.lua" }));
    console.log(bad ? "Battleground smoke test: " + bad + " problem(s)." : "Battleground smoke test: no problem found (simulated client: still test in game).");
    process.exit(bad ? 1 : 0);
}
if (args.includes("--open-world")) {
    showOpenWorld(run({ locale: "enUS", fuzz: 0, scenario: "openworld.lua" }));
    console.log(bad ? "Open world smoke test: " + bad + " problem(s)." : "Open world smoke test: no problem found (simulated client: still test in game).");
    process.exit(bad ? 1 : 0);
}

const fuzz = Number(opt("--fuzz", 300));
const seedArg = Number(opt("--seed", 12345));
const seed = Number.isFinite(seedArg) ? Math.floor(Math.abs(seedArg)) % 2147483648 : 12345;
const first = run({ locale: "enUS", fuzz, seed });
show("fresh install, English client", first);
const second = run({ locale: "frFR", race: "Skyborne", fuzz: Math.max(1, Math.floor(fuzz / 3)), seed }, first.saved);
show("after /reload (saved data kept), French client, Skyborne character", second);
console.log(bad ? "Smoke test: " + bad + " problem(s)." : "Smoke test: no problem found (simulated client: still test in game).");
process.exit(bad ? 1 : 0);
