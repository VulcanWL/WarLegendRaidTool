-- WarLegend RaidTool - what tools/smoke.js plays in the simulated client (not shipped, fengari = Lua 5.3).
-- Phases: login, every /wl command, every window tab, "Test all", a raid with a fight, hostile addon messages,
-- event floods (cost), then the caller runs it again after a /reload (saved data kept, French client).
local M, opts = ...
local report = { phases = {}, perf = {}, fuzz = {} }
M.report = report

local function Phase(name) M.phase = name; report.phases[#report.phases + 1] = name end
local function Count(list, phase) local n = 0; for _, e in ipairs(list) do if e.phase == phase then n = n + 1 end end return n end

-- login
Phase("login")
M.version = opts.version
M.player.race = opts.race
M.LoadAddOn("WarLegendRaidTool")
M.loggedIn = true
M.Fire("PLAYER_LOGIN")
M.Fire("PLAYER_ENTERING_WORLD", true, false)
M.Advance(1)
M.Fire("GUILD_ROSTER_UPDATE", false)
M.Fire("PLAYER_GUILD_UPDATE", "player")
M.Advance(35)
local W = WLRT
if not W then return report end
report.access = W.access

-- every /wl command, without argument (as typed alone); again later in a raid
local function Commands(label)
    Phase(label)
    local names = {}
    for name in pairs(W.slash or {}) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        M.phase = label .. " /wl " .. name
        M.Call(W.slash[name], "")
        M.Advance(1)
        if W.StopTests then M.Call(W.StopTests, true) end
    end
    return names
end
report.commands = Commands("commands")
M.phase = "/wl help"
M.Call(SlashCmdList.WARLEGENDRT, "help")
M.Call(SlashCmdList.WARLEGENDRT, "")
M.Advance(1)

-- the window, every tab
local function AllTabs(label)
    Phase(label)
    if not W.IsShown() then M.Call(W.Toggle) end
    M.Advance(0.5)
    local keys = {}
    for _, m in ipairs(W.modules) do keys[#keys + 1] = m.key end
    for _, key in ipairs(keys) do
        M.phase = label .. " " .. key
        M.Call(W.Select, key)
        M.Advance(0.2)
    end
    M.Advance(3) -- the tabs filled slowly (W.IndexTabsSlowly)
    report.tabs = #keys
    M.Call(W.Hide)
end
AllTabs("window")

-- Test all: modules show fake data, end by themselves, never send anything
Phase("test all")
local chat0, addon0 = #M.chat, #M.addon
M.Call(W.TestAll)
M.Advance(70)
report.testChat, report.testAddon = #M.chat - chat0, #M.addon - addon0
M.Call(W.StopTests, true)

-- a raid of 10: the raid addon loads, a ready check, a pull, a fight, the end
Phase("raid")
local CLASSES = { "WARRIOR", "PRIEST", "MAGE", "ROGUE", "DRUID", "HUNTER", "PALADIN", "WARLOCK", "SHAMAN" }
M.group = { M.player }
for i = 2, 10 do M.group[i] = { name = "Raider" .. i, class = CLASSES[(i % #CLASSES) + 1] } end
M.instance = "raid"
M.Fire("GROUP_ROSTER_UPDATE")
M.Fire("PLAYER_ENTERING_WORLD", false, false)
M.Advance(3)
report.raidLoaded = W.raidLoaded
M.Fire("READY_CHECK", "Smoketest", 30)
M.Advance(2)
M.Fire("READY_CHECK_CONFIRM", "raid2", true)
M.Fire("READY_CHECK_FINISHED")
M.Fire("ENCOUNTER_START", 663, "Lucifron", 9, 10)
-- PLAYER_REGEN_DISABLED comes just before the lockdown (secure frames can still change), _ENABLED just after it
M.Fire("PLAYER_REGEN_DISABLED")
M.combat = true
Phase("combat")
for i = 1, 40 do
    M.Fire("UNIT_AURA", "raid" .. ((i % 10) + 1), { isFullUpdate = true })
    M.Fire("UNIT_HEALTH", "raid" .. ((i % 10) + 1))
end
M.Advance(10)
M.Call(W.slash.rc or function() end, "")
M.combat = false
Phase("after combat")
M.Fire("PLAYER_REGEN_ENABLED")
M.Fire("ENCOUNTER_END", 663, "Lucifron", 9, 10, 1)
M.Advance(5)
AllTabs("raid window")
report.raidCommands = Commands("raid commands")

-- trust checks of the security review: a stranger is flagged on prompts, a burst of questions schedules one reply
Phase("trust")
report.checks = {}
local function Check(name, ok, detail) report.checks[#report.checks + 1] = { name = name, ok = ok and true or false, detail = detail } end
Check("guild member not flagged", W.Sender and not W.Sender("Guildie1-Forever"):find("|cff", 1, true))
Check("stranger flagged as not in guild", W.Sender and W.Sender("Stranger-Other"):find("|cff", 1, true) ~= nil)
M.Advance(10)
local timers0 = M.PendingTimers()
for _ = 1, 50 do M.Fire("CHAT_MSG_ADDON", "WLRT_CD2", "Q", "RAID", "Raider2-Forever", "Raider2-Forever", 0, 0, "", 0) end
Check("50 cooldown questions schedule at most 1 reply", M.PendingTimers() - timers0 <= 1, M.PendingTimers() - timers0)
M.Advance(5)

-- every addon in memory (PvP: battleground frames, Skyborne: a Skyborne character), so all their prefixes are listened to
for _, n in ipairs({ "WarLegendRaidTool_PvP", "WarLegendRaidTool_Skyborne" }) do C_AddOns.LoadAddOn(n) end
M.Fire("PLAYER_ENTERING_WORLD", false, false)
M.Advance(3)

-- hostile addon messages on every prefix: from a guild mate (guild, raid), and whispered by a stranger
Phase("fuzz")
local seed = 12345
local function Rand(n) seed = (seed * 1103515245 + 12345) % 2147483648; return (seed % n) + 1 end
local PIECES = { "", "0", "1", "-1", "2147483648", "1e309", "-1e309", "nan", "inf", "0x7fffffff", "1.5", "999999999999",
    "|cffff0000red|r", "|Hitem:19019::::::::60:::::|h[x]|h", "|TInterface\\Icons\\INV_Misc_QuestionMark:4000|t", "||", "|", "~", "~1~2~3",
    "^", "^^^", ";", ",", ":", "[", "]", "/gquit", "/run print(1)", "\n", "\0", "Raider2", "Raider2-Forever", "Smoketest",
    string.rep("A", 255), "é", "\255\254", "raid1", "player", "Q", "?", "R", "S", "A", "D", "1:2:3", "a=b", "{}" }
local function Junk()
    local n = Rand(12) - 1
    local parts = {}
    for i = 1, n do parts[i] = PIECES[Rand(#PIECES)] end
    local s = table.concat(parts, ({ "^", ":", ";", ",", "\t", " ", "|", "~" })[Rand(8)])
    if Rand(4) == 1 then s = PIECES[Rand(#PIECES)] .. s end
    return s:sub(1, 255)
end
local prefixes = {}
for p in pairs(M.prefixes) do prefixes[#prefixes + 1] = p end
table.sort(prefixes)
local SENDERS = { { "Raider2-Forever", "RAID" }, { "Guildie1-Forever", "GUILD" }, { "Raider3-Forever", "WHISPER" }, { "Stranger-Other", "WHISPER" },
    { "Raider4-Forever", "PARTY" }, { "Guildie2-Forever", "OFFICER" }, { "Stranger-Other", "CHANNEL" } }
local perPrefix = opts.fuzz or 300
for _, p in ipairs(prefixes) do
    M.phase = "fuzz " .. p
    local chatBefore, addonBefore, sensBefore = #M.chat, #M.addon, #M.sensitive
    for i = 1, perPrefix do
        local s = SENDERS[Rand(#SENDERS)]
        M.Fire("CHAT_MSG_ADDON", p, Junk(), s[2], s[1], s[1], 0, 0, "", 0)
        if i % 50 == 0 then M.Advance(0.5) end
    end
    M.Advance(2)
    report.fuzz[#report.fuzz + 1] = { prefix = p, sent = perPrefix, replies = #M.addon - addonBefore, chat = #M.chat - chatBefore,
        sensitive = #M.sensitive - sensBefore }
end

-- the addon's own messages (valid requests and answers), replayed 100 times by other players: replies stay bounded
Phase("replay")
local seen, samples = {}, {}
for _, a in ipairs(M.addon) do
    local k = a.prefix .. "\1" .. tostring(a.msg)
    seen[a.prefix] = seen[a.prefix] or 0
    if not seen[k] and seen[a.prefix] < 4 then seen[k] = true; seen[a.prefix] = seen[a.prefix] + 1; samples[#samples + 1] = a end
end
report.replay = {}
for _, a in ipairs(samples) do
    M.phase = "replay " .. a.prefix
    local before, chatBefore, sensBefore = #M.addon, #M.chat, #M.sensitive
    for i = 1, 100 do
        local s = SENDERS[(i % 3) + 1]
        M.Fire("CHAT_MSG_ADDON", a.prefix, a.msg, a.channel == "CHANNEL" and "CHANNEL" or s[2], s[1], s[1], 0, 0, "", 0)
        if i % 10 == 0 then M.Advance(1) end
    end
    M.Advance(5)
    report.replay[#report.replay + 1] = { prefix = a.prefix, msg = tostring(a.msg):sub(1, 40), replies = #M.addon - before,
        chat = #M.chat - chatBefore, sensitive = #M.sensitive - sensBefore }
end

-- cost: event floods in a raid, out of combat, window closed (fengari is slower than the game: compare, do not read as ms in game)
Phase("perf")
M.Call(W.Hide) -- the commands may have left the window open: measured closed
M.costs = {}
local function Flood(label, n, fn)
    local t0 = os.clock()
    for i = 1, n do fn(i) end
    local dt = (os.clock() - t0) * 1000
    report.perf[#report.perf + 1] = { label = label, n = n, ms = dt }
end
Flood("UNIT_AURA x2000", 2000, function(i) M.Fire("UNIT_AURA", "raid" .. ((i % 10) + 1), { isFullUpdate = false }) end)
Flood("UNIT_HEALTH x2000", 2000, function(i) M.Fire("UNIT_HEALTH", "raid" .. ((i % 10) + 1)) end)
Flood("GROUP_ROSTER_UPDATE x200", 200, function() M.Fire("GROUP_ROSTER_UPDATE") end)
Flood("GUILD_ROSTER_UPDATE x200", 200, function() M.Fire("GUILD_ROSTER_UPDATE", false) end)
M.SetGuild(500)
Flood("GUILD_ROSTER_UPDATE x200 (500 members)", 200, function() M.Fire("GUILD_ROSTER_UPDATE", false) end)
M.SetGuild(30)
Flood("COMBAT_LOG x2000", 2000, function() M.Fire("COMBAT_LOG_EVENT_UNFILTERED") end)
Flood("CHAT_MSG_GUILD x500", 500, function(i) M.Fire("CHAT_MSG_GUILD", "hello " .. i, "Guildie1-Forever") end)
Flood("BAG_UPDATE x500", 500, function(i) M.Fire("BAG_UPDATE", i % 5) end)
Flood("UPDATE_MOUSEOVER_UNIT x500", 500, function() M.Fire("UPDATE_MOUSEOVER_UNIT") end)
Flood("NAME_PLATE_UNIT_ADDED x500", 500, function(i) M.Fire("NAME_PLATE_UNIT_ADDED", "nameplate" .. (i % 40 + 1)) end)
-- idle: OnUpdate scripts still running every frame with every window closed, out of combat
M.updates = 0
local idle = {}
for _, f in ipairs(M.frames) do if f.__scripts.OnUpdate and f:IsVisible() then idle[#idle + 1] = (f:GetName() or f.__type) .. " (" .. (f.__where or "?") .. ")" end end
local t0 = os.clock()
M.Advance(10)
report.idle = { frames = idle, updatesPerSecond = M.updates / 10, ms = (os.clock() - t0) * 1000, timers = M.PendingTimers() }
report.busiest = W.BusiestWork and W.BusiestWork(12) or {}
local costs = {}
for k, ms in pairs(M.costs) do costs[#costs + 1] = { k, ms } end
table.sort(costs, function(a, b) return a[2] > b[2] end)
report.frameCosts = { table.unpack(costs, 1, math.min(#costs, 10)) }
M.costs = nil

-- leave: the game writes the saved variables
Phase("logout")
M.group = {}
M.instance = nil
M.Fire("GROUP_ROSTER_UPDATE")
M.Advance(2)
M.Fire("PLAYER_LOGOUT")
return report
