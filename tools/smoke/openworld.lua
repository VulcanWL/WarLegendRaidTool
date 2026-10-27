-- WarLegend RaidTool - the open world in the simulated client: node tools/smoke.js --open-world (not shipped, fengari = Lua 5.3).
-- A guild of 120 and a raid of 40 outside instances, on three axes:
-- [1 frames] the enemy player frames of the danger alert (40 at most, secure buttons changed out of combat only, combat
--   in and out while enemies come and go), the other frames shown in a raid in the open world;
-- [2 cost] the raid forming, unit events of 10 vs 40 players, the PvP addon once loaded, addon messages from 39 raiders
--   and 119 guild mates, the OnUpdate scripts at rest, the addon's own /wl perf (W.BusiestWork);
-- [3 map] the guild members on the world map and the minimap (GuildPositions, GuildMap's messages made from the addon's
--   own line), map closed / open, pins, the minimap library at work, stale positions.
-- fengari ms only compare with each other here: they are not ms in game.
local M, opts = ...
local report = { sections = {}, checks = {} }
M.report = report
local section
local function Phase(name) M.phase = name end
local function Section(title) section = { title = title, lines = {} }; report.sections[#report.sections + 1] = section; Phase(title) end
local function Line(fmt, ...) section.lines[#section.lines + 1] = string.format(fmt, ...) end
local function Check(name, ok, detail) report.checks[#report.checks + 1] = { name = name, ok = ok and true or false, detail = detail ~= nil and tostring(detail) or nil } end
local function Clock(fn) local t0 = os.clock(); fn(); return (os.clock() - t0) * 1000 end
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local seed = 4242
local function Rand() seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 end

-- the world before the addons load (HereBeDragons reads the maps at load), a guild of 120 all online
M.version = opts.version
M.player.race = opts.race
M.SetupWorld()
M.SetGuild(119)
for _, g in ipairs(M.guild) do g.online = true end
table.insert(M.guild, 1, { name = M.player.name .. "-" .. M.player.realm, class = M.player.class, online = true, rank = 1, level = 60 })

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
local function LineWork(before, n, filter)
    local list = {}
    for _, b in ipairs(W.BusiestWork(1000)) do
        local o = before[b[1]] or { 0, 0 }
        if b[3] > o[1] and (not filter or b[1]:find(filter)) then list[#list + 1] = { b[1], b[3] - o[1], b[4] - o[2] } end
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
local function Blocked() return #M.blocked end
-- the key M.costs gives a frame's handler / OnUpdate ("EVENT File.lua:line" of its CreateFrame): found from the frame, so
-- it follows the code when lines move
local function CostKey(what, f) return f and (what .. " " .. tostring(f.__where or f:GetName() or "?")) or what .. " ?" end
local function FrameOf(file, event)
    for _, f in ipairs(M.frames) do
        if f.__events and f.__events[event] and tostring(f.__where):match("^([^:]+)") == file then return f end
    end
end

-- the options of the open world on (the danger alert and its frames are off by default), applied at a loading screen
local da = W.db.dangerAlert
da.enabled, da.frames, da.framesClick, da.log = true, true, true, true
local gp = W.db.guildPositions
M.Fire("PLAYER_ENTERING_WORLD", false, false)
M.Advance(6)

---------------------------------------------------------------------------
-- [3 map] guild members on the maps, solo
---------------------------------------------------------------------------
-- the addon's own lines (its send code), then the same fields for the others
local own, gone
for _, a in ipairs(M.addon) do
    if a.prefix == "GuildMapEx1" and a.channel == "GUILD" and not tostring(a.msg):find(",STEALTH,", 1, true) then own = a.msg end
end
gp.share = false
M.Advance(6)
for _, a in ipairs(M.addon) do
    if a.prefix == "GuildMapEx1" and tostring(a.msg):find(",STEALTH,", 1, true) then gone = a.msg end
end
gp.share = true
M.Advance(6)
local fields = own and { strsplit(",", own) } or {}
Check("the addon sends its own position (GuildMapEx1 on GUILD)", own ~= nil, own)
Check("its line has GuildMap's 12 fields", #fields == 12, own)
Check("it sends a 'gone' line (class STEALTH) when sharing stops", gone ~= nil, gone)

local Pins = LibStub and LibStub("HereBeDragons-Pins-2.0-gm", true)
local REF, TEMPLATE = "WLRTGuildMap", "HereBeDragonsPinsTemplate"
-- drawn: shown with an anchor (a frame with no point is not drawn)
local function Drawn(f) return f:IsVisible() and #f.__points > 0 end
local function MapState()
    local s = { world = 0, worldShown = 0, mini = 0, miniShown = 0, mapPins = 0, made = 0 }
    if not Pins then return s end
    for icon in pairs(Pins.worldmapPinRegistry[REF] or {}) do s.world = s.world + 1; if Drawn(icon) and WorldMapFrame:IsVisible() and icon.__parent and rawget(icon.__parent, "pinTemplate") then s.worldShown = s.worldShown + 1 end end
    for icon in pairs(Pins.minimapPinRegistry[REF] or {}) do s.mini = s.mini + 1; if Drawn(icon) and icon.__parent == Minimap then s.miniShown = s.miniShown + 1 end end
    s.mapPins = WorldMapFrame:GetNumActivePinsByTemplate(TEMPLATE)
    for _, f in ipairs(M.frames) do if tostring(f.__where):find("^GuildPositions%.lua") then s.made = s.made + 1 end end
    return s
end
local function LineMap(label, s)
    Line("%s: %d members placed (world map %d, %d shown; minimap %d, %d shown), %d world map pins active, %d pin frames made",
        label, s.world, s.world, s.worldShown, s.mini, s.miniShown, s.mapPins, s.made)
end

-- 119 senders: 40 % in Durotar (10 of them near me, in the minimap's range), the rest on Kalimdor and in Elwynn;
-- half move (a line every 5 s), half stand (every 20 s), as GuildPositions sends
local ZONES = { { 1411, 40 }, { 1454, 20 }, { 1413, 20 }, { 1440, 10 }, { 1429, 10 } }
local senders, near = {}, 0
for i = 2, #M.guild do
    local g = M.guild[i]
    local r, map = Rand() * 100, 1411
    for _, z in ipairs(ZONES) do
        if r < z[2] then map = z[1]; break end
        r = r - z[2]
    end
    local s = { full = g.name, class = g.class, level = g.level, map = map, x = 0.1 + Rand() * 0.8, y = 0.1 + Rand() * 0.8,
        moving = i % 2 == 0, next = M.now + Rand() * 5 }
    if map == 1411 and near < 10 then near = near + 1; s.x, s.y = 0.52 + (Rand() - 0.5) * 0.06, 0.44 + (Rand() - 0.5) * 0.06 end
    senders[#senders + 1] = s
end
local function PosLine(s, template)
    local f = { strsplit(",", template) }
    f[1], f[3], f[4] = s.full, tostring(s.level), template == gone and "STEALTH" or s.class
    if template ~= gone then f[6], f[7], f[8] = string.format("%.3f", s.x), string.format("%.3f", s.y), tostring(s.map) end
    return table.concat(f, ",")
end
local function Send(s, template)
    M.Fire("CHAT_MSG_ADDON", "GuildMapEx1", PosLine(s, template or own), "GUILD", s.full, s.full, 0, 0, "", 0)
end
local sending, playerMoving, received = false, false, 0
M.onStep = function(now)
    if playerMoving then M.world.player.x = M.world.player.x + 0.0002 end
    if not (sending and own) then return end
    for _, s in ipairs(senders) do
        if now >= s.next then
            if s.moving then
                s.x = math.min(0.98, math.max(0.02, s.x + (Rand() - 0.5) * 0.01))
                s.y = math.min(0.98, math.max(0.02, s.y + (Rand() - 0.5) * 0.01))
            end
            Send(s)
            received = received + 1
            s.next = now + (s.moving and 5 or 20)
        end
    end
end
-- one phase of the map: seconds of traffic, the receive cost per message and what the map holds after
local function MapRun(label, seconds)
    local r0, b0 = received, Work()
    CostsStart()
    local ms = Clock(function() M.Advance(seconds) end)
    local costs = CostsLines(0)
    local n = received - r0
    local recv = costs[CostKey("CHAT_MSG_ADDON", FrameOf("Core.lua", "CHAT_MSG_ADDON"))] or 0
    local s = MapState()
    LineMap(label, s)
    Line("  %d s: %d lines received, %.1f ms in all (%.3f ms per line received), map library OnUpdate %.1f ms, guild map ticker %.1f ms",
        seconds, n, ms, n > 0 and recv / n or 0, costs[CostKey("OnUpdate", Pins and Pins.updateFrame)] or 0, (function()
            local t = 0
            for _, w in ipairs(W.BusiestWork(1000)) do if w[1] == "guild map" then t = w[4] - ((b0["guild map"] or { 0, 0 })[2]) end end
            return t
        end)())
    return s, n
end

Section("[3 map] guild of 120 (119 others send their position), solo in Durotar, open world")
sending = true
local s1 = MapRun("map never opened, 60 s", 60)
Check("members placed: the 119 senders", s1.world == 119 and s1.mini == 119, s1.world .. " / " .. s1.mini)
Check("no world map pin before the map is opened (the map has no map yet)", s1.mapPins == 0, s1.mapPins)
Check("the minimap shows the members in its range (10 near me)", s1.miniShown >= 5 and s1.miniShown <= 20, s1.miniShown)
local reopen = Clock(function() WorldMapFrame:Show() end)
local s2 = MapState()
LineMap(string.format("world map opened on Durotar (%.1f ms)", reopen), s2)
local durotar = 0
for _, s in ipairs(senders) do if s.map == 1411 then durotar = durotar + 1 end end
Check("the open zone map shows its members (Durotar)", s2.worldShown == durotar, s2.worldShown .. " / " .. durotar)
local s3 = MapRun("map open on Durotar, 30 s", 30)
Check("map open: one world map pin per member shown, none left over", s3.mapPins == s3.worldShown, s3.mapPins .. " pins / " .. s3.worldShown .. " shown")
local change = Clock(function() WorldMapFrame:SetMapID(1414) end)
local s4 = MapState()
LineMap(string.format("map switched to Kalimdor (%.1f ms)", change), s4)
local kalimdor = 0
for _, s in ipairs(senders) do if s.map ~= 1429 then kalimdor = kalimdor + 1 end end
Check("the continent map shows its members (Kalimdor)", s4.worldShown == kalimdor, s4.worldShown .. " / " .. kalimdor)
local s5 = MapRun("map open on Kalimdor, 30 s", 30)
Check("continent open: one world map pin per member shown, none left over", s5.mapPins == s5.worldShown, s5.mapPins .. " pins / " .. s5.worldShown .. " shown")
WorldMapFrame:Hide()
local s6, n6 = MapRun("map closed (it stays on Kalimdor), 60 s", 60)
Check("map closed: no world map pin left over (one per member at most)", s6.mapPins <= s6.world, s6.mapPins .. " pins / " .. s6.world .. " members")
if s6.mapPins > s6.world then
    Line("  -> %d pins left active for %d members: about %d more per hour with the map closed", s6.mapPins, s6.world, math.floor((s6.mapPins - s5.mapPins) * 60))
end
reopen = Clock(function() WorldMapFrame:Show() end)
local s7 = MapState()
LineMap(string.format("map opened again, on Durotar (%.1f ms)", reopen), s7)
Check("opening the map again: pins of the open map only", s7.mapPins == s7.worldShown, s7.mapPins .. " / " .. s7.worldShown)
WorldMapFrame:Hide()
-- the minimap library redraws every pin in range each frame while I move
playerMoving = true
local s8 = MapRun("I move (minimap pins redrawn each frame), 20 s", 20)
gp.edge = true
for _, s in ipairs(senders) do s.next = math.min(s.next, M.now + 0.1) end
M.Advance(0.2)
local s9 = MapRun("I move, far members kept on the minimap's edge, 20 s", 20)
Check("edge option: the members of my zone all on the minimap", s9.miniShown >= durotar - 2, s9.miniShown .. " / " .. durotar)
gp.edge = false
playerMoving = false
local _ = s8
-- gone line (sharing stopped): forgotten at once; then everyone stops: forgotten after 60 s, frames kept for reuse
if gone then
    local before = MapState().world
    Send(senders[1], gone)
    Check("a 'gone' line takes the member off at once", MapState().world == before - 1, before .. " -> " .. MapState().world)
end
sending = false
M.Advance(70)
local s10 = MapState()
LineMap("everyone silent for 70 s", s10)
Check("stale positions removed after 60 s (world, minimap)", s10.world == 0 and s10.mini == 0 and s10.miniShown == 0, s10.world .. " / " .. s10.mini)
Check("no world map pin left after they are gone", s10.mapPins == 0, s10.mapPins)
sending = true
for _, s in ipairs(senders) do s.next = M.now + Rand() * 5 end
local s11 = MapRun("they come back, 25 s", 25)
Check("pin frames reused when members come back", s11.made == s10.made, s10.made .. " -> " .. s11.made)
sending = false

---------------------------------------------------------------------------
-- [2 cost] a raid of 40 forms in the open world, unit events with 10 and 40 players
---------------------------------------------------------------------------
Section("[2 cost] a raid of 40 forms in the open world (guild mates, 3 GROUP_ROSTER_UPDATE per join)")
local b0 = Work()
CostsStart()
local ms = Clock(function()
    M.group = { M.player }
    for i = 2, 40 do
        local g = M.guild[i]
        M.group[i] = { name = g.name, class = g.class, map = 1411, x = 0.52 + (Rand() - 0.5) * 0.02, y = 0.44 + (Rand() - 0.5) * 0.02 }
        for _ = 1, 3 do M.Fire("GROUP_ROSTER_UPDATE") end
        M.Advance(0.2)
    end
    M.Advance(3)
end)
Line("39 joins in 8 s: %.0f ms in all (raid modules loaded on the way: %s)", ms, tostring(W.raidLoaded))
CostsLines(4)
LineWork(b0, 6)
report.raidLoaded = W.raidLoaded

local function Sized(size, fn)
    local keep = M.group
    M.group = { table.unpack(keep, 1, size) }
    M.Fire("GROUP_ROSTER_UPDATE")
    M.Advance(1)
    local r = table.pack(fn())
    M.group = keep
    M.Fire("GROUP_ROSTER_UPDATE")
    M.Advance(1)
    return table.unpack(r, 1, r.n)
end
local function Flood(n, fn)
    CostsStart()
    local t = Clock(function() for i = 1, n do fn(i) end end)
    return t, CostsLines(0)
end
local function Compare(label, n, fn, key)
    local t10, c10 = Sized(10, function() return Flood(n, function(i) fn(i, 10) end) end)
    local t40, c40 = Sized(40, function() return Flood(n, function(i) fn(i, 40) end) end)
    Line("%-34s 10 players %7.0f ms, 40 players %7.0f ms (x%.1f)", label, t10, t40, t10 > 0 and t40 / t10 or 0)
    if key then Line("  of which %-40s %7.0f ms -> %7.0f ms", key, c10[key] or 0, c40[key] or 0) end
    return t10, t40
end
Section("[2 cost] the same events with 10 and 40 players (window closed, out of combat)")
Compare("GROUP_ROSTER_UPDATE x200", 200, function() M.Fire("GROUP_ROSTER_UPDATE") end)
Compare("UNIT_AURA x2000 (raid1..N)", 2000, function(i, n) M.Fire("UNIT_AURA", "raid" .. ((i % n) + 1), { isFullUpdate = false }) end)
Compare("UNIT_HEALTH x2000 (raid1..N)", 2000, function(i, n) M.Fire("UNIT_HEALTH", "raid" .. ((i % n) + 1)) end)
local g30 = Flood(200, function() M.Fire("GUILD_ROSTER_UPDATE", false) end)
Line("%-34s %7.0f ms (guild of 120)", "GUILD_ROSTER_UPDATE x200", g30)
-- the PvP addon stays in memory after a battleground (or once its tab was opened)
if W.LoadPvP then W.LoadPvP() end
M.Fire("PLAYER_ENTERING_WORLD", false, false)
M.Advance(3)
report.pvpLoaded = C_AddOns.IsAddOnLoaded("WarLegendRaidTool_PvP")
Line("PvP addon loaded (as after a battleground), back in the open world:")
local p10, p40 = Compare("GROUP_ROSTER_UPDATE x200", 200, function() M.Fire("GROUP_ROSTER_UPDATE") end, CostKey("GROUP_ROSTER_UPDATE", rawget(_G, "WarLegendPvP")))
Line("  -> the PvP addon recomputes every ally on each roster event outside battlegrounds: %.1f ms per event with 40 (fengari)", p40 / 200)
local _ = p10

---------------------------------------------------------------------------
-- [1 frames] the danger alert's enemy player frames, raid of 40 formed
---------------------------------------------------------------------------
Section("[1 frames] enemy player frames (danger alert, option on), open world, raid of 40")
local enemies = {}
local function Enemy(k)
    local e = enemies[k]
    if not e then
        e = { name = "Enemy" .. k .. "-Forever", class = CLASSES[(k % #CLASSES) + 1], guid = string.format("Player-2-%08X", k),
            enemy = true, pvp = true, hp = 3000 + k, hpMax = 4000, level = 60 }
        enemies[k] = e
    end
    return e
end
local function Plate(i, k) M.units["nameplate" .. i] = Enemy(k); M.Fire("NAME_PLATE_UNIT_ADDED", "nameplate" .. i) end
local function Unplate(i)
    if not M.units["nameplate" .. i] then return end
    M.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate" .. i)
    M.units["nameplate" .. i] = nil
end
local function EnterCombat() M.Fire("PLAYER_REGEN_DISABLED"); M.combat = true end
local function LeaveCombat() M.combat = false; M.Fire("PLAYER_REGEN_ENABLED") end
-- what the frames show, read from the frames themselves
local function Frames()
    local holder = rawget(_G, "WLRTDangerFrames")
    local s = { rows = 0, grey = 0, clicks = 0, made = 0, clicksMade = 0, header = "", bad = 0 }
    if not holder then return s end
    local rows, clicks = {}, {}
    for _, c in ipairs(holder.__children) do
        if c.__type == "StatusBar" then
            s.made = s.made + 1
            if c:IsShown() then
                s.rows = s.rows + 1
                if c:GetAlpha() < 1 then s.grey = s.grey + 1 end
                local p = c.__points[1]
                rows[p[4] .. ":" .. p[5]] = c
            end
        elseif rawget(c, "__protected") then
            s.clicksMade = s.clicksMade + 1
            if c:IsShown() then s.clicks = s.clicks + 1; clicks[#clicks + 1] = c end
        elseif rawget(c, "text") then
            s.header = c:IsShown() and (c.text:GetText() or "") or "(hidden)"
        end
    end
    -- each click shown targets the player its row shows
    for _, c in ipairs(clicks) do
        local p = c.__points[1]
        local row = rows[p[4] .. ":" .. p[5]]
        local name = row and row.name:GetText()
        local macro = c:GetAttribute("macrotext1") or ""
        if not (name and macro:find(W.BaseName(name), 1, true)) then s.bad = s.bad + 1 end
    end
    return s
end
local function LineFrames(label, s)
    Line("%s: %d rows shown (%d grey), %d clickable, header \"%s\"; %d rows / %d buttons made%s", label, s.rows, s.grey, s.clicks, s.header,
        s.made, s.clicksMade, s.bad > 0 and (", " .. s.bad .. " click(s) on the wrong row") or "")
end
local blocked0 = Blocked()
Phase("[1 frames] out of combat")
for i = 1, 25 do Plate(i, i) end
M.units.target = Enemy(25)
M.Fire("PLAYER_TARGET_CHANGED")
M.units.mouseover = Enemy(56)
M.Fire("UPDATE_MOUSEOVER_UNIT")
M.Advance(1)
local f1 = Frames()
LineFrames("25 nameplates + target + mouseover (out of combat)", f1)
Check("frames: one row per enemy player (25 plates, target = one of them, mouseover = a 26th)", f1.rows == 26 and f1.grey == 0, f1.rows)
Check("frames: every row clickable out of combat, each on its own player", f1.clicks == f1.rows and f1.bad == 0, f1.clicks .. " / bad " .. f1.bad)
M.units.mouseover = nil
Phase("[1 frames] combat starts, 30 more come, 15 leave and 15 new ones come")
EnterCombat()
for i = 26, 40 do Plate(i, i) end
local f2 = Frames()
LineFrames("in combat, 40 plates", f2)
Check("frames: 40 rows at most", f2.rows <= 40, f2.rows)
for i = 1, 15 do Unplate(i); Plate(i, 40 + i) end
local fh = Flood(4000, function(i) M.Fire("UNIT_HEALTH", i % 2 == 0 and ("nameplate" .. (i % 40 + 1)) or ("raid" .. (i % 40 + 1))) end)
Line("UNIT_HEALTH x4000 in combat (40 enemy plates + raid1..40): %.0f ms", fh)
M.Advance(20)
local f3 = Frames()
LineFrames("in combat 20 s later (15 left, 15 new)", f3)
Check("frames: still 40 rows at most in combat", f3.rows <= 40, f3.rows)
Check("frames: no secure button changed in combat", Blocked() == blocked0, Blocked() - blocked0)
LeaveCombat()
M.Advance(1.5)
local f4 = Frames()
LineFrames("combat over (1.5 s)", f4)
Check("frames: after the combat, the clicks follow the rows again", f4.clicks == f4.rows and f4.bad == 0, f4.clicks .. " / " .. f4.rows .. ", bad " .. f4.bad)
local plated = 0
for i = 1, 40 do if M.units["nameplate" .. i] then plated = plated + 1 end end
Line("  enemies on a nameplate now: %d; rows: %d", plated, f4.rows)
Check("frames: after the combat, the players refused while the 40 rows were full get a row", f4.rows == math.min(plated, 40), f4.rows .. " / " .. plated)
for i = 1, 40 do Unplate(i) end
M.units.target = nil
M.Fire("PLAYER_TARGET_CHANGED")
M.Advance(17)
local f5 = Frames()
LineFrames("all plates gone, 17 s later", f5)
Check("frames: every row gone 15 s after its player", f5.rows == 0 and f5.clicks == 0, f5.rows .. " / " .. f5.clicks)
Check("frames: never more than 40 rows / buttons made", f5.made <= 40 and f5.clicksMade <= 40, f5.made .. " / " .. f5.clicksMade)
Phase("[1 frames] combat in and out while enemies come")
local k = 100
for r = 1, 12 do
    for _ = 1, 4 do
        k = k + 1
        local p = ((k - 101) % 40) + 1
        Unplate(p)
        Plate(p, k)
    end
    if r % 2 == 1 then EnterCombat() else LeaveCombat() end
    M.Advance(1.3)
    for j = 1, 2 do Unplate(((k - 101 - j) % 40) + 1) end
    M.Advance(0.7)
end
M.Advance(1)
local f6 = Frames()
LineFrames("12 combat changes, 48 enemies, then out of combat", f6)
Check("frames: in / out of combat, no secure button changed in combat", Blocked() == blocked0, Blocked() - blocked0)
Check("frames: in / out of combat, clicks right after", f6.clicks == f6.rows and f6.bad == 0, f6.clicks .. " / " .. f6.rows .. ", bad " .. f6.bad)
-- churn of 40 plates (a battle in the open world): the cost
local fc = Flood(2000, function(i)
    local p = (i % 40) + 1
    Unplate(p)
    Plate(p, 200 + (i % 120))
end)
Line("NAME_PLATE_UNIT_REMOVED + _ADDED x2000 (40 plates, 120 enemies): %.0f ms", fc)
for i = 1, 40 do Unplate(i) end
M.Advance(17)
local f7 = Frames()
Check("frames: all gone at the end", f7.rows == 0, f7.rows)

-- every other frame of ours shown outside instances in a raid
Section("[1 frames] other frames of the addons shown in a raid of 40, open world")
-- what is drawn: a shown frame with an anchor and a text, a texture or a backdrop shown; listed by the top frame
-- (child of UIParent) that holds it, with the number of such frames
local function Root(f)
    while f.__parent and f.__parent ~= UIParent and f.__parent ~= Minimap and f.__parent.__parent do f = f.__parent end
    return f
end
local function Draws(f)
    if not f:IsVisible() or #f.__points == 0 then return false end
    if f.__backdrop or f.__type == "StatusBar" then return true end
    for _, r in ipairs(f.__regions) do
        if r.__shown and ((r.__type == "FontString" and (r.__text or "") ~= "") or (r.__type == "Texture" and (r.__texture or r.__atlas))) then return true end
    end
    return false
end
local function Shown()
    local byRoot, mini = {}, {}
    for _, f in ipairs(M.frames) do
        if f.__where and Draws(f) then
            local root = Root(f)
            if root.__parent == Minimap then mini[#mini + 1] = tostring(root.__where)
            else
                local key = (root:GetName() or root.__type) .. " (" .. tostring(root.__where) .. ")"
                byRoot[key] = (byRoot[key] or 0) + 1
            end
        end
    end
    local list = {}
    for w, n in pairs(byRoot) do list[#list + 1] = w .. ": " .. n end
    table.sort(list)
    return list, mini
end
local shown, mini = Shown()
Line("out of combat: %s", #shown > 0 and table.concat(shown, ", ") or "none")
EnterCombat()
M.Advance(2)
local shownC = Shown()
Line("in combat: %s", #shownC > 0 and table.concat(shownC, ", ") or "none")
LeaveCombat()
M.Advance(2)
Line("on the minimap: %d frame(s) drawn%s", #mini, #mini > 0 and (" (" .. table.concat(mini, ", ") .. ")") or "")

---------------------------------------------------------------------------
-- [2 cost] addon messages from 39 raiders and 119 guild mates
---------------------------------------------------------------------------
Section("[2 cost] addon messages: each of the addon's own lines sent by the 39 raiders (RAID) or the 119 guild mates (GUILD)")
-- a ready check in the open world (a raid forming before it zones): its messages are part of what the raid sends
M.Fire("READY_CHECK", M.player.name, 30)
M.Advance(1)
M.Fire("READY_CHECK_FINISHED")
M.Advance(2)
local kinds, seen = {}, {}
for _, a in ipairs(M.addon) do
    if a.prefix ~= "GuildMapEx1" and (a.channel == "RAID" or a.channel == "PARTY" or a.channel == "GUILD") then
        local key, per = a.prefix .. "\1" .. a.channel .. "\1" .. tostring(a.msg), a.prefix .. "\1" .. a.channel
        if not seen[key] and (seen[per] or 0) < 3 then seen[key] = true; seen[per] = (seen[per] or 0) + 1; kinds[#kinds + 1] = a end
    end
end
local totalMsgs, totalMs, worst = 0, 0, { replies = 0 }
local b1 = Work()
CostsStart()
for _, a in ipairs(kinds) do
    Phase("[2 cost] replay " .. a.prefix)
    local addon0, chat0 = #M.addon, #M.chat
    local n = 0
    local t = Clock(function()
        if a.channel ~= "GUILD" then -- a line sent to the party while the raid formed: the raiders send it to the raid
            for i = 2, 40 do M.Fire("CHAT_MSG_ADDON", a.prefix, a.msg, "RAID", M.group[i].name, M.group[i].name, 0, 0, "", 0); n = n + 1 end
        else
            for i = 2, #M.guild do M.Fire("CHAT_MSG_ADDON", a.prefix, a.msg, "GUILD", M.guild[i].name, M.guild[i].name, 0, 0, "", 0); n = n + 1 end
        end
        M.Advance(2)
    end)
    local replies = #M.addon - addon0
    totalMsgs, totalMs = totalMsgs + n, totalMs + t
    Line("%-12s %-5s x%3d \"%s\": %.0f ms, %d addon replies, %d chat lines", a.prefix, a.channel == "GUILD" and "GUILD" or "RAID", n, tostring(a.msg):sub(1, 24), t, replies, #M.chat - chat0)
    if replies > worst.replies then worst = { replies = replies, prefix = a.prefix } end
    Check("replies stay bounded: " .. a.prefix .. " " .. (a.channel == "GUILD" and "GUILD" or "RAID"), replies <= 10, replies)
end
Line("%d kinds, %d messages, %.0f ms (with 2 s of clock after each kind)", #kinds, totalMsgs, totalMs)
CostsLines(3)
LineWork(b1, 5)
Check("some of the addon's own messages were replayed", #kinds > 0, #kinds)

---------------------------------------------------------------------------
-- [3 map] guild members on the maps while in the raid
---------------------------------------------------------------------------
Section("[3 map] guild members on the maps, in the raid of 40 (39 of them in my raid: the game shows those)")
sending = true
for _, s in ipairs(senders) do s.next = M.now + Rand() * 5 end
local s12 = MapRun("in the raid, 30 s", 30)
Check("raid members not placed (119 - 39 = 80 members)", s12.world == 80 and s12.mini == 80, s12.world .. " / " .. s12.mini)
-- 5 leave the raid: on the map again with their next line; they come back: off the map again
local left = {}
for _ = 1, 5 do left[#left + 1] = table.remove(M.group) end
M.Fire("GROUP_ROSTER_UPDATE")
local s13 = MapRun("5 left the raid, 25 s", 25)
Check("members who left my raid are placed again", s13.world == 85, s13.world)
for i = #left, 1, -1 do M.group[#M.group + 1] = left[i] end
M.Fire("GROUP_ROSTER_UPDATE")
local s14 = MapRun("they joined again, 25 s", 25)
Check("members who joined my raid are taken off again", s14.world == 80, s14.world)
-- each phase above starts right after a roster change (every sender asked once): the same raid a minute later
MapRun("in the raid, 60 s more, no roster change", 60)

---------------------------------------------------------------------------
-- [2 cost] at rest: raid of 40, guild on the maps (still sending), window and map closed, out of combat
---------------------------------------------------------------------------
Section("[2 cost] at rest 10 s: raid of 40 formed, guild members on the maps, every window closed, out of combat")
W.Hide()
local idle = {}
for _, f in ipairs(M.frames) do
    if f.__scripts.OnUpdate and f:IsVisible() then idle[#idle + 1] = (f:GetName() or f.__type) .. " (" .. (f.__where or "?") .. ")" end
end
M.updates = 0
local b2 = Work()
CostsStart()
local rest = Clock(function() M.Advance(10) end)
Line("%d OnUpdate script(s) running: %s; %.1f calls per frame; %d timer(s) pending; %.0f ms for 10 s (traffic included)", #idle, table.concat(idle, ", "),
    M.updates / 200, M.PendingTimers(), rest)
CostsLines(4)
LineWork(b2, 4)
sending = false
Section("[2 cost] /wl perf over the whole run (W.BusiestWork, total ms / count)")
for _, b in ipairs(W.BusiestWork(10)) do Line("%-52s %8.1f ms / %d (max %.1f ms)", b[1], b[4], b[3], b[2]) end

Phase("logout")
M.onStep = nil
M.group = {}
M.Fire("GROUP_ROSTER_UPDATE")
M.Advance(2)
M.Fire("PLAYER_LOGOUT")
return report
