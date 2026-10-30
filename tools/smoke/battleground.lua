-- WarLegend RaidTool - a battleground in the simulated client: node tools/smoke.js --bg (not shipped, fengari = Lua 5.3).
-- Alterac Valley, 40 against 40: a raid of 40 allies (the guild's and others), 40 enemies on the scoreboard and on
-- nameplates, the PvP addon loaded (its frames for both sides), a Skyborne character (its addon loaded too).
-- What it measures: the cost of each simulated frame (worst, average, percentiles: a frame of the game is one step
-- of 1/20 s here), at rest at the start, in a 40 vs 40 fight, dead, while the raid changes; which handler / OnUpdate
-- costs the most, the addon's own /wl perf (W.BusiestWork). It also checks the frames (one button per player, the
-- range and health refreshed in combat) and that nothing secure is changed in combat.
-- fengari ms only compare with each other here: they are not ms in game.
local M, opts = ...
local report = { sections = {}, checks = {}, title = "battleground: Alterac Valley, 40 against 40" }
M.report = report
local section
local function Phase(name) M.phase = name end
local function Section(title) section = { title = title, lines = {} }; report.sections[#report.sections + 1] = section; Phase(title) end
local function Line(fmt, ...) section.lines[#section.lines + 1] = string.format(fmt, ...) end
local function Check(name, ok, detail) report.checks[#report.checks + 1] = { name = name, ok = ok and true or false, detail = detail ~= nil and tostring(detail) or nil } end
local function Clock(fn) local t0 = os.clock(); fn(); return (os.clock() - t0) * 1000 end
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local seed = 7331
local function Rand() seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 end
local function Pick(n) return math.floor(Rand() * n) + 1 end

M.version = opts.version
M.player.race = opts.race
M.SetGuild(60)

Phase("login")
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
report.guild = #M.guild

-- /wl perf between two moments: the work done in between, busiest first
local function Work() local t = {}; for _, b in ipairs(W.BusiestWork(1000)) do t[b[1]] = { b[3], b[4] } end return t end
local function LineWork(before, n)
    local list = {}
    for _, b in ipairs(W.BusiestWork(1000)) do
        local o = before[b[1]] or { 0, 0 }
        if b[3] > o[1] then list[#list + 1] = { b[1], b[3] - o[1], b[4] - o[2] } end
    end
    table.sort(list, function(a, b) return a[3] > b[3] end)
    for i = 1, math.min(#list, n or 5) do Line("  /wl perf: %-48s %8.1f ms / %d", list[i][1], list[i][3], list[i][2]) end
    return list
end
-- every handler / OnUpdate of any frame (the libraries' too) between CostsStart and CostsLines
local function CostsStart() M.costs = {} end
local function CostsLines(n)
    local list = {}
    for k, ms in pairs(M.costs or {}) do list[#list + 1] = { k, ms } end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    for i = 1, math.min(#list, n or 4) do Line("  handler:  %-48s %8.1f ms", list[i][1], list[i][2]) end
    M.costs = nil
    local byKey = {}
    for _, c in ipairs(list) do byKey[c[1]] = c[2] end
    return byKey
end
-- the cost of each frame between FramesStart and FramesLine: average, percentiles, worst, and the spikes (frames that
-- cost at least 3 times the median: work done by many frames / buttons in the same frame)
local function FramesStart() M.frameStats = { list = {} } end
local function FramesLine(label)
    local fs = M.frameStats
    M.frameStats = nil
    local l, total = {}, 0
    for i, ms in ipairs(fs.list) do l[i] = ms; total = total + ms end
    table.sort(l)
    local n = #l
    local function P(p) return n > 0 and l[math.max(1, math.ceil(n * p))] or 0 end
    local med, spikes = P(0.5), 0
    for _, ms in ipairs(l) do if ms >= 3 * med and ms > 0.05 then spikes = spikes + 1 end end
    local s = { n = n, avg = n > 0 and total / n or 0, med = med, p95 = P(0.95), p99 = P(0.99), max = fs.max or 0, spikes = spikes }
    Line("%s: %d frames, average %.3f ms, median %.3f, 95th %.3f, 99th %.3f, worst %.3f ms; %d spike(s) (>= 3x median)",
        label, n, s.avg, s.med, s.p95, s.p99, s.max, spikes)
    if fs.maxWhat then Line("  worst frame: %s", fs.maxWhat) end
    report.frames = report.frames or {}
    report.frames[#report.frames + 1] = { label = label, avg = s.avg, p99 = s.p99, max = s.max, spikes = spikes }
    return s
end
local function Blocked() return #M.blocked end
-- the key M.costs gives a frame's handler / OnUpdate ("EVENT File.lua:line" of its CreateFrame): found from the frame, so
-- it follows the code when lines move
local function CostKey(what, f) return f and (what .. " " .. tostring(f.__where or f:GetName() or "?")) or what .. " ?" end

---------------------------------------------------------------------------
-- the battleground: 40 allies (39 + me), 40 enemies, scoreboard
---------------------------------------------------------------------------
M.bgFaction = 1 -- Alliance (the player is Human)
local allies, enemies = { M.player }, {}
for i = 2, 40 do
    local g = M.guild[i]
    -- half of the raid from the guild (its names), half from other guilds
    allies[i] = { name = i <= 20 and g.name or ("Ally" .. i .. "-Forever"), class = CLASSES[(i % #CLASSES) + 1], hp = 4000, hpMax = 4000 }
end
for k = 1, 40 do
    enemies[k] = { name = "Enemy" .. k .. "-Forever", class = CLASSES[(k % #CLASSES) + 1], guid = string.format("Player-2-%08X", k),
        enemy = true, pvp = true, hp = 4000, hpMax = 4000, level = 60 }
end
local function Score(p, faction)
    return { name = p.name, faction = faction, classToken = p.class,
        className = p.class:sub(1, 1) .. p.class:sub(2):lower(), raceName = faction == 1 and "Human" or "Orc",
        guid = p.guid or "", killingBlows = 0, honorableKills = 0, deaths = 0, honorGained = 0, damageDone = 0, healingDone = 0,
        rating = 0, ratingChange = 0, prematchMMR = 0, mmrChange = 0, postmatchMMR = 0, talentSpec = "", honorLevel = 0,
        roleAssigned = 0, gender = 2, stats = {} }
end
local function BuildScores()
    M.scores = {}
    for i = 1, #M.group do M.scores[#M.scores + 1] = Score(M.group[i], 1) end
    for _, e in ipairs(enemies) do M.scores[#M.scores + 1] = Score(e, 0) end
end

local PvP
local function Buttons(side)
    local s = { total = 0, shown = 0, grey = 0 }
    local t = PvP and PvP[side]
    if not t then return s end
    for _, b in pairs(t.Players or {}) do
        s.total = s.total + 1
        if b:IsVisible() then s.shown = s.shown + 1 end
        if b:GetAlpha() < 1 then s.grey = s.grey + 1 end
    end
    return s
end
-- the test mode outside a battleground: my own button among the fake allies (it comes from the roster, which the PvP
-- addon does not read outside battlegrounds)
local function TestMode(when)
    if not (PvP and PvP.EnableTestMode) then return end
    PvP:EnableTestMode()
    M.Advance(1)
    local aTest = Buttons("Allies")
    local mine = PvP.UserButton and PvP.UserButton:IsVisible() and PvP.UserButton.PlayerDetails and PvP.UserButton.PlayerDetails.PlayerName
    Line("test mode %s: allies %d shown, my own button: %s", when, aTest.shown, tostring(mine))
    Check("test mode " .. when .. ": my own button is shown", mine == M.player.name, tostring(mine))
    PvP:DisableTestMode()
    M.Advance(1)
    Check("test mode " .. when .. ", off again: the frames are hidden", Buttons("Allies").shown == 0 and Buttons("Enemies").shown == 0, Buttons("Allies").shown)
end

-- the auras of the fight as a mage's frames read them (readable, the worst case: the game can keep them secret in a
-- battleground): 12 buffs and 2 curses on each ally, Arcane Intellect at the 5th place on every other one
C_Spell.GetSpellName = function(id) return "Spell " .. id end
C_Spell.GetSpellTexture = function(id) return 100000 + id end
M.auras = { helpful = 12, harmful = 2, buffAt = 5, buffName = "Spell 1459" }

-- the PvP addon is loaded when the queue pops (outside, out of combat), then the loading screen
Section("[1 enter] the queue pops, Alterac Valley: the raid of 40 forms in the battleground")
local b0 = Work()
local tLoad = Clock(function() if W.LoadPvP then W.LoadPvP() end end)
report.pvpLoaded = C_AddOns.IsAddOnLoaded("WarLegendRaidTool_PvP")
report.skyLoaded = C_AddOns.IsAddOnLoaded("WarLegendRaidTool_Skyborne")
Line("PvP addon loaded in %.0f ms (Skyborne addon loaded: %s)", tLoad, tostring(report.skyLoaded))
PvP = rawget(_G, "WarLegendPvP")
TestMode("before any battleground, solo")
M.instance, M.instanceName, M.instanceID, M.bgStart = "pvp", "Alterac Valley", 30, M.now
M.group = { M.player }
BuildScores()
M.Fire("PLAYER_ENTERING_WORLD", false, false)
M.Fire("ZONE_CHANGED_NEW_AREA")
M.Advance(1)
-- the others come in over 8 s, three roster events each (as the game sends them)
CostsStart()
FramesStart()
local tJoin = Clock(function()
    for i = 2, 40 do
        M.group[i] = allies[i]
        BuildScores()
        for _ = 1, 3 do M.Fire("GROUP_ROSTER_UPDATE") end
        M.Advance(0.2)
    end
    M.Advance(6)
end)
local fJoin = FramesLine("39 joins in 8 s, then 6 s")
Line("  %.0f ms in all", tJoin)
local cJoin = CostsLines(5)
LineWork(b0, 5)
report.raidLoaded = W.raidLoaded

local a1, e1 = Buttons("Allies"), Buttons("Enemies")
Line("PvP frames: allies %d buttons (%d shown), enemies %d buttons (%d shown)", a1.total, a1.shown, e1.total, e1.shown)
Check("PvP addon loaded and on in the battleground", PvP and PvP.enabled, PvP and tostring(PvP.enabled))
Check("one ally button per raid member (40)", a1.total == 40 and a1.shown == 40, a1.total .. " / " .. a1.shown)
Check("one enemy button per enemy on the scoreboard (40)", e1.total == 40 and e1.shown == 40, e1.total .. " / " .. e1.shown)
local _ = fJoin, cJoin

---------------------------------------------------------------------------
-- the world of the fight: nameplates, targets, health / power / auras changing, the frames reading them
---------------------------------------------------------------------------
local plates, fighting, dead = {}, false, false
local rate = { health = 0, power = 0, aura = 0 }
local function Plate(i, k) plates[i] = k; M.units["nameplate" .. i] = enemies[k]; M.Fire("NAME_PLATE_UNIT_ADDED", "nameplate" .. i) end
local function Unplate(i)
    if not plates[i] then return end
    M.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate" .. i)
    M.units["nameplate" .. i] = nil
    plates[i] = nil
end
local step = 0
-- per frame of 1/20 s in a 40 vs 40 fight: about 280 UNIT_HEALTH, 160 UNIT_POWER_FREQUENT, 160 UNIT_AURA a second (raid and
-- nameplates), 20 UNIT_TARGET, 5 nameplates coming / going, a mouseover twice and a target change every 2 s
M.onStep = function()
    if not fighting then return end
    step = step + 1
    local n = #M.group
    for _ = 1, 8 do
        local i = Pick(n)
        local p = M.group[i]
        p.hp = math.max(1, math.min(p.hpMax or 4000, (p.hp or 4000) + math.floor((Rand() - 0.6) * 600)))
        M.Fire("UNIT_HEALTH", i == 1 and "player" or ("raid" .. i))
        M.Fire("UNIT_POWER_FREQUENT", "raid" .. Pick(n), "MANA")
        M.Fire("UNIT_AURA", "raid" .. Pick(n), { isFullUpdate = false })
    end
    rate.health, rate.power, rate.aura = rate.health + 8, rate.power + 8, rate.aura + 8
    for _ = 1, 6 do
        local i = Pick(20)
        local k = plates[i]
        if k then
            local e = enemies[k]
            e.hp = math.max(1, math.min(e.hpMax, e.hp + math.floor((Rand() - 0.6) * 600)))
            M.Fire("UNIT_HEALTH", "nameplate" .. i)
            rate.health = rate.health + 1
        end
    end
    M.Fire("UNIT_AURA", "nameplate" .. Pick(20), { isFullUpdate = false })
    -- an ally changes target
    local who = Pick(n)
    if who > 1 then
        M.units["raid" .. who .. "target"] = enemies[Pick(40)]
        M.Fire("UNIT_TARGET", "raid" .. who)
    end
    if step % 4 == 0 then
        local i = Pick(20)
        Unplate(i)
        Plate(i, Pick(40))
    end
    if step % 10 == 0 then M.units.mouseover = enemies[Pick(40)]; M.Fire("UPDATE_MOUSEOVER_UNIT") end
    if step % 40 == 0 then M.units.target = enemies[Pick(40)]; M.Fire("PLAYER_TARGET_CHANGED") end
end
local function EnterCombat() M.Fire("PLAYER_REGEN_DISABLED"); M.combat = true end
local function LeaveCombat() M.combat = false; M.Fire("PLAYER_REGEN_ENABLED") end

-- one measured phase: frames, handlers, /wl perf
local function Run(label, seconds, nHandlers)
    local w0 = Work()
    CostsStart()
    FramesStart()
    M.Advance(seconds)
    local s = FramesLine(label)
    local c = CostsLines(nHandlers or 6)
    LineWork(w0, 4)
    return s, c
end

---------------------------------------------------------------------------
-- [2] at rest: the start of the battleground (in the cave, gates closed), out of combat
---------------------------------------------------------------------------
Section("[2 rest] start of the battleground, out of combat, nobody on a nameplate (20 s)")
local idle = {}
for _, f in ipairs(M.frames) do
    if f.__scripts.OnUpdate and f:IsVisible() then
        local k = tostring(f.__where or f:GetName() or f.__type)
        idle[k] = (idle[k] or 0) + 1
    end
end
local idleList = {}
for k, n in pairs(idle) do idleList[#idleList + 1] = k .. (n > 1 and (" x" .. n) or "") end
table.sort(idleList)
Line("OnUpdate scripts running: %d kinds: %s", #idleList, table.concat(idleList, ", "))
local sRest = Run("out of combat, 20 s", 20)
report.rest = sRest

---------------------------------------------------------------------------
-- [3] a 40 vs 40 fight
---------------------------------------------------------------------------
Section("[3 fight] 40 vs 40 in combat: 20 enemies on nameplates, health / power / auras / targets changing (30 s)")
local blocked0 = Blocked()
for i = 1, 20 do Plate(i, i) end
M.units.target = enemies[1]
M.Fire("PLAYER_TARGET_CHANGED")
EnterCombat()
fighting = true
rate = { health = 0, power = 0, aura = 0 }
local wf = Work()
local sFight, cFight = Run("in combat, 30 s", 30, 8)
Line("  events: %d UNIT_HEALTH, %d UNIT_POWER_FREQUENT, %d UNIT_AURA in 30 s", rate.health, rate.power, rate.aura)
report.fight = sFight
local _ = wf, cFight
-- the frames still follow the fight: an enemy out of range gets grey, health shown on the button
local inRangeBefore = Buttons("Enemies").grey
Check("in combat: no secure frame changed", Blocked() == blocked0, Blocked() - blocked0)

---------------------------------------------------------------------------
-- [4] combat in and out, players coming and going on the scoreboard and in the raid
---------------------------------------------------------------------------
Section("[4 churn] combat in and out every 2 s, 5 allies leave and 5 others come, 5 enemies replaced (20 s)")
local w4 = Work()
CostsStart()
FramesStart()
for r = 1, 10 do
    if r % 2 == 1 then LeaveCombat() else EnterCombat() end
    if r == 3 then -- 5 allies leave (each one: 2 roster events)
        for _ = 1, 5 do table.remove(M.group); BuildScores(); M.Fire("GROUP_ROSTER_UPDATE"); M.Fire("GROUP_ROSTER_UPDATE") end
    elseif r == 5 then -- 5 others come
        for j = 1, 5 do
            M.group[#M.group + 1] = { name = "Late" .. j .. "-Forever", class = CLASSES[j], hp = 4000, hpMax = 4000 }
            BuildScores()
            for _ = 1, 3 do M.Fire("GROUP_ROSTER_UPDATE") end
        end
    elseif r == 7 then -- 5 enemies leave, 5 come
        for j = 1, 5 do enemies[j] = { name = "Fresh" .. j .. "-Forever", class = CLASSES[j], guid = string.format("Player-3-%08X", j),
            enemy = true, pvp = true, hp = 4000, hpMax = 4000, level = 60 } end
        BuildScores()
    end
    M.Advance(2)
end
LeaveCombat()
fighting = false
M.Advance(1.5)
FramesLine("combat in / out, raid and scoreboard changing, 20 s")
CostsLines(6)
LineWork(w4, 4)
local a4, e4 = Buttons("Allies"), Buttons("Enemies")
Line("PvP frames after: allies %d buttons (%d shown), enemies %d (%d shown)", a4.total, a4.shown, e4.total, e4.shown)
Check("in / out of combat: no secure frame changed in combat", Blocked() == blocked0, Blocked() - blocked0)
Check("after the churn: one ally button per raid member (40)", a4.shown == #M.group, a4.shown .. " / " .. #M.group)
Check("after the churn: one enemy button per enemy (40)", e4.shown == 40, e4.shown)
local _ = inRangeBefore

---------------------------------------------------------------------------
-- [5] dead, at the graveyard (the raid fights on)
---------------------------------------------------------------------------
Section("[5 dead] dead at the graveyard 10 s while the raid fights on")
EnterCombat()
fighting = true
M.Fire("PLAYER_DEAD")
Run("dead, the others in combat, 10 s", 10, 4)
M.Fire("PLAYER_ALIVE")
M.Fire("PLAYER_UNGHOST")
fighting = false
LeaveCombat()
M.Advance(2)

---------------------------------------------------------------------------
-- [6] the raid's roster events in the battleground: their cost
---------------------------------------------------------------------------
Section("[6 roster] roster events in the battleground, raid of 40 (window closed, out of combat)")
local function Flood(n, fn)
    CostsStart()
    local t = Clock(function() for i = 1, n do fn(i) end end)
    return t, CostsLines(0)
end
local tRoster, cRoster = Flood(200, function(i) M.Fire("GROUP_ROSTER_UPDATE"); if i % 3 == 0 then M.Advance(0.05) end end)
M.Advance(1)
Line("GROUP_ROSTER_UPDATE x200 (bursts of 3 a frame): %.0f ms, of which the PvP addon %.0f ms", tRoster, cRoster[CostKey("GROUP_ROSTER_UPDATE", PvP)] or 0)
local tScore = Flood(50, function() M.Fire("UPDATE_BATTLEFIELD_SCORE") end)
Line("UPDATE_BATTLEFIELD_SCORE x50 (80 on the scoreboard): %.0f ms (%.2f ms each)", tScore, tScore / 50)
local tHealth = Flood(2000, function(i) M.Fire("UNIT_HEALTH", "raid" .. ((i % 40) + 1)) end)
Line("UNIT_HEALTH x2000 (raid1..40): %.0f ms", tHealth)

-- what the frames' shortcuts must not change (audit of 29/10): a reason each, so a shortcut that goes wrong is seen here
local notSet = 0
for _, side in ipairs({ "Allies", "Enemies" }) do
    for _, b in pairs(PvP[side].Players) do
        if b.settingsGeneration ~= PvP[side].settingsGeneration then notSet = notSet + 1 end
    end
end
Check("every button has its settings (set up 4 a frame at the first scoreboard)", notSet == 0, notSet)

-- buttons the client has not placed yet: each one tried once, the others still get theirs, and the rounds end
local tried, kept = 0, {}
for _, b in pairs(PvP.Enemies.Players) do
    local apply = b.ApplyButtonSettings
    kept[b] = apply
    b.ApplyButtonSettings = function(...) tried = tried + 1; return apply(...) end
    b.GetRect = function() return nil end
end
PvP.Enemies:SortPlayers(true)
M.Advance(1)
local triedOnce = tried
M.Advance(1)
Check("buttons without a place yet: each one tried once, then it stops", triedOnce == 40 and tried == 40, triedOnce .. " then " .. tried)
for b, apply in pairs(kept) do b.ApplyButtonSettings, b.GetRect = apply, nil end
PvP.Enemies:SortPlayers(true)
M.Advance(1)
notSet = 0
for _, b in pairs(PvP.Enemies.Players) do
    if b.settingsGeneration ~= PvP.Enemies.settingsGeneration then notSet = notSet + 1 end
end
Check("placed again: every button has its settings", notSet == 0, notSet)

local rebuilt, afterRoster = 0, PvP.Allies.AfterPlayerSourceUpdate
PvP.Allies.AfterPlayerSourceUpdate = function(...) rebuilt = rebuilt + 1; return afterRoster(...) end
M.Advance(1)
rebuilt = 0
M.Fire("GROUP_ROSTER_UPDATE")
M.Advance(1)
Check("the same raid again: the roster read rebuilds nothing", rebuilt == 0, rebuilt)

local boards, seenBoard = 0, PvP.UPDATE_BATTLEFIELD_SCORE
PvP.UPDATE_BATTLEFIELD_SCORE = function(...) boards = boards + 1; return seenBoard(...) end
M.Advance(12) -- 3 unchanged boards
boards = 0
M.Advance(24)
Check("the same scoreboard: asked for every 6 s", boards >= 2 and boards <= 5, boards)

local boardsKept = M.scores
M.scores = {} -- no answer yet: the board is asked for every 2 s
M.Advance(12)
boards = 0
M.Advance(10)
Check("an empty scoreboard: still asked for every 2 s", boards >= 4, boards)
M.scores = boardsKept
M.Advance(3)

rebuilt = 0
local gone = table.remove(M.group)
BuildScores()
M.Fire("GROUP_ROSTER_UPDATE")
M.Advance(1)
Check("a raid member leaves: the side is rebuilt", rebuilt >= 1, rebuilt)
boards = 0
M.Advance(6)
Check("a raid member leaves: the scoreboard is asked for every 2 s again", boards >= 2, boards)
M.group[#M.group + 1] = gone
BuildScores()
M.Fire("GROUP_ROSTER_UPDATE")
M.Advance(1)
PvP.Allies.AfterPlayerSourceUpdate, PvP.UPDATE_BATTLEFIELD_SCORE = afterRoster, seenBoard
Check("the raid member is back: one button per member", Buttons("Allies").shown == #M.group, Buttons("Allies").shown)

local nameReads, readName = 0, PvP.GetReadableUnitName
PvP.GetReadableUnitName = function(...) nameReads = nameReads + 1; return readName(...) end
M.units.nameplate21 = { name = "Guard-Forever", class = "WARRIOR", npc = true, enemy = true, hp = 100, hpMax = 100, level = 60 }
M.Fire("NAME_PLATE_UNIT_ADDED", "nameplate21")
M.Fire("UNIT_HEALTH", "nameplate21")
M.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate21")
M.units.nameplate21 = nil
PvP.GetReadableUnitName = readName
Check("an NPC on a plate: its name is not read, no button", nameReads == 0 and PvP.Enemies.NameplateButtons.nameplate21 == nil, nameReads)

-- a read fills one list for all the buttons: each button keeps its own copy of what it shows
local greyOn, plainOn, shared, listsSeen, even = 0, 0, false, {}, nil
for _, b in pairs(PvP.Allies.Players) do
    local kept = b.Dispel and b.Dispel.lastBuffs
    if kept and kept[1] then
        if kept[1].grey then greyOn = greyOn + 1 else plainOn = plainOn + 1 end
        if listsSeen[kept] then shared = true end
        listsSeen[kept] = true
    end
    if b.unitID == "raid6" then even = b end
end
Check("Dispel: my buff shown on some allies and missing on others, each with its own list", greyOn > 0 and plainOn > 0 and not shared,
    greyOn .. " missing, " .. plainOn .. " there, shared: " .. tostring(shared))
M.auraReads = 0
if even then even.Dispel:Update() end
Check("Dispel: the scan of the buffs stops at my buff (2 curses + the end of them, then 5 buffs)", M.auraReads == 8, M.auraReads)

-- W.UnitByName keeps what it found until the raid changes: a kept unit that changed hands is never returned
local kept3 = W.UnitFullName("raid3")
Check("W.UnitByName finds a raid member", W.UnitByName(kept3) == "raid3", W.UnitByName(kept3))
M.group[3], M.group[4] = M.group[4], M.group[3] -- 2 members swap places: the event is not here yet
Check("W.UnitByName: a kept unit that changed hands, before the event", W.UnitByName(kept3) == "raid4", W.UnitByName(kept3))
M.Fire("GROUP_ROSTER_UPDATE")
Check("W.UnitByName: after the event", W.UnitByName(kept3) == "raid4", W.UnitByName(kept3))
M.group[3], M.group[4] = M.group[4], M.group[3]
M.Fire("GROUP_ROSTER_UPDATE")
Check("W.UnitByName: a name not in the raid is no member", W.UnitByName("Nobody Here") == nil, W.UnitByName("Nobody Here"))
M.Advance(1)

---------------------------------------------------------------------------
-- [7] back in the open world, the raid of 40 still together, the PvP addon in memory
---------------------------------------------------------------------------
Section("[7 after] back in the open world, raid of 40, the PvP addon still loaded")
for i = 1, 20 do Unplate(i) end
M.units.target, M.units.mouseover = nil, nil
M.instance, M.instanceName, M.instanceID, M.scores = nil, nil, nil, nil
M.Fire("PLAYER_ENTERING_WORLD", false, false)
M.Fire("ZONE_CHANGED_NEW_AREA")
M.Advance(3)
local aOut = Buttons("Allies")
Line("PvP frames shown: allies %d", aOut.shown)
Check("PvP frames hidden outside the battleground", aOut.shown == 0, aOut.shown)
local tOut, cOut = Flood(200, function() M.Fire("GROUP_ROSTER_UPDATE") end)
Line("GROUP_ROSTER_UPDATE x200: %.0f ms, of which the PvP addon %.0f ms (%.2f ms per event)", tOut, cOut[CostKey("GROUP_ROSTER_UPDATE", PvP)] or 0,
    (cOut[CostKey("GROUP_ROSTER_UPDATE", PvP)] or 0) / 200)
report.rosterOut = (cOut[CostKey("GROUP_ROSTER_UPDATE", PvP)] or 0) / 200
TestMode("after a battleground, raid of 40")
-- the next battleground: entering it shows the raid again (the PvP addon scans the roster at the loading screen)
M.instance, M.instanceName, M.instanceID, M.bgStart = "pvp", "Alterac Valley", 30, M.now
BuildScores()
M.Fire("PLAYER_ENTERING_WORLD", false, false)
M.Advance(7)
local aBack, eBack = Buttons("Allies"), Buttons("Enemies")
Line("next battleground: allies %d shown, enemies %d shown", aBack.shown, eBack.shown)
Check("next battleground: the raid is shown again (no roster event needed)", aBack.shown == #M.group, aBack.shown .. " / " .. #M.group)
Check("next battleground: the enemies are shown again", eBack.shown == 40, eBack.shown)
-- here every button of both sides was made at the same moment (the loading screen): the worst case for work done
-- every 0.2 s per button
Section("[7b next] a fight in the next battleground, the raid formed before it (every button made at the same moment), 15 s")
for i = 1, 20 do Plate(i, i) end
EnterCombat()
fighting = true
local sNext = Run("in combat, 15 s", 15, 6)
report.fightNext = sNext
fighting = false
LeaveCombat()
for i = 1, 20 do Unplate(i) end
M.Advance(2)
Check("fight in the next battleground: no secure frame changed in combat", Blocked() == blocked0, Blocked() - blocked0)

Section("[8] /wl perf over the whole run (W.BusiestWork, total ms / count)")
for _, b in ipairs(W.BusiestWork(10)) do Line("%-52s %8.1f ms / %d (max %.1f ms)", b[1], b[4], b[3], b[2]) end

Phase("logout")
M.onStep = nil
M.instance, M.scores = nil, nil
M.group = {}
M.Fire("GROUP_ROSTER_UPDATE")
M.Advance(2)
M.Fire("PLAYER_LOGOUT")
return report
