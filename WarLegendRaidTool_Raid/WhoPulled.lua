-- WarLegend RaidTool - Who pulled?
-- Finds who started the fight: first hit between a group member and an enemy just before combat
-- (combat log when the client gives it), else the boss's first target when the encounter starts.
local W = WLRT
W.AddFR({
    ["Who Pulled"] = "Qui a pull",
    ["Pulled by %s"] = "Pull par %s",
    ["Announce the puller in raid chat"] = "Annoncer le puller dans le canal raid",
    ["Bosses only"] = "Boss uniquement",
    ["Print in my chat"] = "Afficher dans mon chat",
    ["Time"] = "Heure",
    ["Puller"] = "Puller",
    ["Target"] = "Cible",
    ["How"] = "Comment",
    ["(pet)"] = "(familier)",
    ["boss target"] = "cible du boss",
    ["body pull"] = "body pull",
    ["Last pulls"] = "Derniers pulls",
    ["First target of %s: %s"] = "Première cible de %s : %s",
})
local L = W.L

local WP = {}
W.WhoPulled = WP
local db
W.OnReady(function()
    db = W.DB("whoPulled", { announce = false, bossOnly = true, print = true })
    if type(db.log) ~= "table" then db.log = {} end
end)

local band = bit and bit.band or function(a, b)
    local r, v = 0, 1
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then r = r + v end
        a, b, v = math.floor(a / 2), math.floor(b / 2), v * 2
    end
    return r
end
local GROUP = 0x00000007     -- mine / party / raid
local HOSTILE = 0x00000040
local PLAYER_OR_PET = 0x00000400 + 0x00001000 + 0x00002000

local first          -- first pull candidate since we were last out of combat
local STALE = 10     -- a candidate older than this is never reported

-- PvE only. The combat log fires thousands of times per second in a raid: we only listen while
-- it is useful (no candidate yet, in a dungeon / raid, or a raid group facing a world boss) and
-- unregister as soon as the first hit is found. Never in battlegrounds, arenas or world PvP.
-- WoW: Forever (Midnight addon rules) refuses the combat log to addons: registering it is a
-- forbidden action. There the module only reports the boss's first target, and says so.
local CLEU_OK = not W.FOREVER and CombatLogGetCurrentEventInfo ~= nil
local cleu = CreateFrame("Frame")
local listening = false
local worldBoss = false -- open world: a world boss has been targeted in this zone
local function UsefulHere()
    local _, kind = IsInInstance()
    if kind == "party" or kind == "raid" then return W.InGroup() end
    return kind == "none" and worldBoss and W.InRaid()
end
local targetEv -- world boss detection: target changes, only for a raid group in the open world
local function Listen()
    local _, kind = IsInInstance()
    W.Activate(targetEv, db ~= nil and not worldBoss and W.Allowed() and kind == "none" and W.InRaid())
    local want = db ~= nil and not first and W.Allowed() and CLEU_OK and UsefulHere()
    if want == listening then return end
    listening = want
    if want then cleu:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED") else cleu:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED") end
end

local function Reset() first = nil; Listen() end

local function InGroupFlags(f) return f and band(f, GROUP) > 0 end
local function Hostile(f) return f and band(f, HOSTILE) > 0 and band(f, 0x00000400) == 0 end

local HIT = { SWING_DAMAGE = 1, RANGE_DAMAGE = 1, SPELL_DAMAGE = 1, SPELL_MISSED = 1, SWING_MISSED = 1, RANGE_MISSED = 1,
    SPELL_AURA_APPLIED = 1, SPELL_CAST_SUCCESS = 1, SPELL_PERIODIC_DAMAGE = 1 }

local function Found(candidate)
    first = candidate
    Listen()
    -- hit out of combat that never turned into a fight (tagged trash...): look again later
    W.After(STALE, function()
        if first == candidate and not (UnitAffectingCombat and UnitAffectingCombat("player")) then Reset() end
    end)
end

cleu:SetScript("OnEvent", function()
    if W.IsOff("WhoPulled") then return end -- switched off in Settings > Modules
    if first or not W.Allowed() then Listen(); return end -- access lost: stop listening
    local _, sub, _, _, srcName, srcFlags, _, _, dstName, dstFlags, _, _, spellName = CombatLogGetCurrentEventInfo()
    -- WoW: Forever can hide combat log values (secret): never index or compute with them
    sub = W.Safe(sub)
    if not sub or not HIT[sub] then return end
    srcName, dstName, srcFlags, dstFlags = W.Safe(srcName), W.Safe(dstName), W.Safe(srcFlags), W.Safe(dstFlags)
    if not srcName or not dstName or not srcFlags or not dstFlags then return end
    if InGroupFlags(srcFlags) and Hostile(dstFlags) then
        local pet = band(srcFlags, 0x00001000 + 0x00002000) > 0
        Found({ who = W.BaseName(srcName) .. (pet and (" " .. L("(pet)")) or ""), target = dstName,
            how = sub:match("^SWING") and "melee" or (W.Safe(spellName) or sub), at = GetTime() })
    elseif Hostile(srcFlags) and InGroupFlags(dstFlags) and band(dstFlags, PLAYER_OR_PET) > 0 then
        Found({ who = W.BaseName(dstName), target = srcName, how = L("body pull"), at = GetTime() })
    end
end)
-- new zone: forget the world boss and any candidate from the previous zone (not during a fight)
local function NewZone()
    worldBoss = false
    if not (UnitAffectingCombat and UnitAffectingCombat("player")) then first = nil end
    Listen()
end
W.On("PLAYER_ENTERING_WORLD", NewZone)
W.On("ZONE_CHANGED_NEW_AREA", NewZone)
W.OnRoster(Listen)
targetEv = W.On("PLAYER_TARGET_CHANGED", function()
    if worldBoss or not W.InRaid() then return end
    local _, kind = IsInInstance()
    if kind == "none" and UnitExists("target") and UnitClassification("target") == "worldboss" then
        worldBoss = true
        Listen()
    end
end, nil, true) -- off until Listen turns it on (raid group in the open world)

local function Report(p, boss)
    -- without a real first hit (no combat log), the boss's first target is shown as what it is
    local text = p.how == L("boss target")
        and string.format(L("First target of %s: %s"), boss or "?", p.who)
        or (string.format(L("Pulled by %s"), p.who) .. " -> " .. (boss or p.target or "?") .. "  (" .. (p.how or "?") .. ")")
    table.insert(db.log, 1, { t = time(), who = p.who, target = boss or p.target, how = p.how })
    while #db.log > 50 do table.remove(db.log) end
    if db.print then W.Print(text) end
    if db.announce and W.Channel() then
        -- already printed above: send quietly; otherwise show it here if the chat is locked
        if db.print then W.SendChat("[WaR LegenD] " .. text, W.Channel()) else W.Announce("[WaR LegenD] " .. text, W.Channel()) end
    end
    WP.Refresh()
end

local reported
W.On("ENCOUNTER_START", function(_, name)
    if not db or not UsefulHere() then return end
    reported = true
    local boss = W.Safe(name)
    W.After(0.5, function()
        if first and GetTime() - first.at < STALE then Report(first, boss); return end
        local who = W.Safe(UnitName("boss1target"))
        if who then Report({ who = who, how = L("boss target") }, boss) end
    end)
end)

W.On("PLAYER_REGEN_DISABLED", function()
    reported = false
    if not db or db.bossOnly or not UsefulHere() then return end
    W.After(1, function()
        if reported or not first or GetTime() - first.at > 5 then return end
        if not (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) then Report(first) end
        reported = true
    end)
end)
W.On("PLAYER_REGEN_ENABLED", function()
    -- world boss fight over: nothing listened in the open world any more (world PvP after a boss...)
    if worldBoss then worldBoss = false; Listen() end
    if first then W.After(2, Reset) end -- no timer at all when there is nothing to reset (PvP)
end)

local UI = {}
function WP.Refresh()
    if not UI.list or not UI.list:IsVisible() then return end
    local rows = {}
    for _, e in ipairs(db.log) do
        rows[#rows + 1] = { cells = { date("%d/%m %H:%M", e.t), e.who or "?", e.target or "?", e.how or "" } }
    end
    UI.list:SetData(rows)
end

W.RegisterModule("WhoPulled", L("Who Pulled"), function(p)
    W.Title(p, L("Who Pulled"))
    W.Check(p, L("Print in my chat"), function() return db.print end, function(v) db.print = v end):SetPoint("TOPLEFT", 12, -34)
    W.Check(p, L("Announce the puller in raid chat"), function() return db.announce end, function(v) db.announce = v end)
        :SetPoint("TOPLEFT", 12, -58)
    W.Check(p, L("Bosses only"), function() return db.bossOnly end, function(v) db.bossOnly = v end):SetPoint("TOPLEFT", 12, -82)
    local t = W.Label(p, L("Last pulls"), "GameFontNormal")
    t:SetPoint("TOPLEFT", 14, -116)
    UI.list = W.Table(p, { { L("Time"), 90 }, { L("Puller"), 150 }, { L("Target"), 220 }, { L("How"), 200 } }, 360)
    UI.list:SetPoint("TOPLEFT", 10, -136)
    p:SetScript("OnShow", WP.Refresh)
end, function() WP.Refresh() end)
