-- WarLegend RaidTool - Danger alert (the idea of HighLevelAlert)
-- In the open world, a warning at the top of the screen and a sound when a nameplate shows an enemy player
-- flagged for PvP, a "skull" mob (10+ levels above me) or a red elite (3+ levels). Counts what is near.
-- Cost: one look per nameplate that appears / goes away, nothing in instances, battlegrounds and on a taxi.
-- Option: a list of the enemy players seen (the Radar of Sashoof's WarLegend v3 addon), from nameplates, target and
-- mouseover in the open world, kept on this computer (200 at most).
local W = WLRT
W.AddFR({
    ["Danger alert"] = "Alerte danger",
    ["Warn me when danger is near (open world)"] = "Me prévenir quand un danger approche (monde ouvert)",
    ["Enemy players flagged for PvP"] = "Joueurs ennemis en mode JcJ",
    ["Skull and red elite mobs"] = "Monstres « tête de mort » et élites rouges",
    ["Play a sound"] = "Jouer un son",
    ["Lock the warning"] = "Verrouiller l'alerte",
    ["Test"] = "Test",
    ["Reset position"] = "Réinitialiser la position",
    ["WARNING"] = "ALERTE",
    ["CAUTION"] = "ATTENTION",
    ["%d enemy player(s) nearby"] = "%d joueur(s) ennemi(s) à proximité",
    ["%d skull elite(s) nearby"] = "%d élite(s) tête de mort à proximité",
    ["%d skull mob(s) nearby"] = "%d monstre(s) tête de mort à proximité",
    ["%d red elite(s) nearby"] = "%d élite(s) rouge(s) à proximité",
    ["Uses the nameplates: enemy nameplates must be shown (V key) to see what is around."] =
        "Utilise les barres de nom : celles des ennemis doivent être affichées (touche V) pour voir ce qui approche.",
    ["Keep a list of the enemy players seen (open world)"] = "Garder la liste des joueurs ennemis vus (monde ouvert)",
    ["Nameplates, target and mouseover; kept on this computer, 200 players at most. Idea: the Radar of Sashoof's WarLegend v3 addon."] =
        "Barres de nom, cible et survol ; gardée sur cet ordinateur, 200 joueurs au plus. Idée : le Radar de l'addon WarLegend v3 de Sashoof.",
    ["All classes"] = "Toutes les classes",
    ["Clear the list"] = "Vider la liste",
    ["Clear the list of the enemy players seen?"] = "Vider la liste des joueurs ennemis vus ?",
    ["Enemy player"] = "Joueur ennemi",
    ["Level"] = "Niveau",
    ["Guild"] = "Guilde",
    ["Zone"] = "Zone",
    ["Seen"] = "Vu",
    ["Times"] = "Fois",
    ["%d s"] = "%d s",
    ["%d min"] = "%d min",
    ["%d h"] = "%d h",
    ["%d d"] = "%d j",
})
local L = W.L
local db

W.OnReady(function()
    db = W.DB("dangerAlert", { enabled = false, players = true, mobs = true, sound = true, locked = false, log = false, logClass = "" })
    if type(db.point) ~= "table" then db.point = { "TOP", "TOP", 0, -90 } end
    if type(db.seen) ~= "table" then db.seen = {} end
end)

-- what each nameplate unit is: "pvp", "skullElite", "skull", "redElite"
local seen = {}
local ORDER = { "pvp", "skullElite", "skull", "redElite" }
local TEXT = {
    pvp = { "%d enemy player(s) nearby", true },
    skullElite = { "%d skull elite(s) nearby", true },
    skull = { "%d skull mob(s) nearby", true },
    redElite = { "%d red elite(s) nearby", false },
}
local SOUNDS = {
    pvp = SOUNDKIT and (SOUNDKIT.PVP_THROUGH_QUEUE or SOUNDKIT.RAID_WARNING),
    skullElite = SOUNDKIT and SOUNDKIT.RAID_WARNING,
    skull = SOUNDKIT and (SOUNDKIT.READY_CHECK or SOUNDKIT.RAID_WARNING),
    redElite = SOUNDKIT and (SOUNDKIT.ALARM_CLOCK_WARNING_2 or SOUNDKIT.RAID_WARNING),
}

local frame
local function Place()
    local p = db.point
    frame:ClearAllPoints()
    frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

local function Create()
    if frame then return end
    frame = CreateFrame("Frame", "WLRTDangerAlert", UIParent)
    frame:SetSize(420, 30)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) if not db.locked then self:StartMoving() end end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, rel, x, y = self:GetPoint()
        db.point = { point, rel, x, y }
    end)
    frame.text = frame:CreateFontString(nil, "OVERLAY")
    W.SetFont(frame.text, W.FONT, 18, "OUTLINE")
    frame.text:SetPoint("CENTER")
    frame:Hide()
    Place()
end

local function OpenWorld()
    local inInstance = IsInInstance()
    return not inInstance and not (UnitOnTaxi and UnitOnTaxi("player"))
end

local counts = {} -- reused: Refresh runs for every dangerous nameplate that comes or goes
local function Refresh()
    if not frame then return end
    wipe(counts)
    for _, kind in pairs(seen) do counts[kind] = (counts[kind] or 0) + 1 end
    for _, kind in ipairs(ORDER) do
        local n = counts[kind]
        if n and n > 0 then
            local t = TEXT[kind]
            local tag = t[2] and ("|cffff3333" .. L("WARNING") .. "|r") or ("|cffffcc00" .. L("CAUTION") .. "|r")
            frame.text:SetText("[" .. tag .. "] " .. string.format(L(t[1]), n))
            frame:Show()
            return
        end
    end
    frame.text:SetText("")
    frame:Hide()
end

local function Classify(unit)
    local isEnemy = W.Safe(UnitIsEnemy("player", unit))
    if not isEnemy then return nil end
    if W.Safe(UnitIsPlayer(unit)) then
        return db.players and W.Safe(UnitIsPVP(unit)) and "pvp" or nil
    end
    if not db.mobs then return nil end
    local level, me = W.Safe(UnitLevel(unit)), W.Safe(UnitLevel("player"))
    if not level or not me then return nil end
    local class = W.Safe(UnitClassification(unit))
    local elite = class == "worldboss" or class == "rareelite" or class == "elite"
    local skull = level == -1 or level >= me + 10
    if skull then return elite and "skullElite" or "skull" end
    if level >= me + 3 and elite then return "redElite" end
end

-- Enemy players seen: db.seen[key] = { n = name, c = class, l = level, g = guild, z = zone, t = last seen, k = times }
local MAX_SEEN, AGAIN = 200, 300 -- seen again after 5 min: one more time
local RECENT = 10 -- a player written less than 10 s ago (same GUID) is not read again: nameplate, target, mouseover
local recent, recentCount = {}, 0
local LogChanged
local function Record(unit)
    if not W.Safe(UnitIsPlayer(unit)) or not W.Safe(UnitIsEnemy("player", unit)) then return end
    local guid, t = W.Safe(UnitGUID(unit)), GetTime()
    if guid then
        local last = recent[guid]
        if last and t - last < RECENT then return end
        if not last then
            recentCount = recentCount + 1
            if recentCount > 300 then wipe(recent); recentCount = 1 end -- a busy evening: start over, stays small
        end
        recent[guid] = t
    end
    local name = W.UnitDisplayName(unit)
    if not name then return end
    local key = name:lower()
    local now = time()
    local e = db.seen[key]
    if not e then
        -- full: the one seen longest ago goes first
        local count, oldest = 0, nil
        for k, v in pairs(db.seen) do
            count = count + 1
            if not oldest or (v.t or 0) < (db.seen[oldest].t or 0) then oldest = k end
        end
        if count >= MAX_SEEN and oldest then db.seen[oldest] = nil end
        e = { k = 0, t = 0 }
        db.seen[key] = e
    end
    if now - e.t >= AGAIN then e.k = e.k + 1 end
    e.n, e.t = name, now
    e.c = W.UnitClassToken(unit) or e.c
    local level = W.Safe(UnitLevel(unit))
    if type(level) == "number" then e.l = level end
    local guild = GetGuildInfo and W.Safe((GetGuildInfo(unit)))
    if guild then e.g = guild end
    e.z = W.Safe(GetRealZoneText()) or e.z
    if LogChanged then LogChanged() end
end

-- one sound per kind every 10 s: a camp of elites shows ten nameplates at once
local SOUND_GAP = 10
local soundAt = {}
local addEv = W.On("NAME_PLATE_UNIT_ADDED", function(unit)
    if not OpenWorld() then return end
    if db.log then Record(unit) end
    if not db.enabled then return end
    local kind = Classify(unit)
    if not kind then return end
    seen[unit] = kind
    Create()
    local now = GetTime()
    if db.sound and SOUNDS[kind] and now - (soundAt[kind] or 0) >= SOUND_GAP then
        soundAt[kind] = now
        PlaySound(SOUNDS[kind], "Ambience")
    end
    Refresh()
end, nil, true)
local removeEv = W.On("NAME_PLATE_UNIT_REMOVED", function(unit)
    if seen[unit] then seen[unit] = nil; Refresh() end
end, nil, true)

local targetEv = W.On("PLAYER_TARGET_CHANGED", function() if OpenWorld() then Record("target") end end, nil, true)
local mouseEv = W.On("UPDATE_MOUSEOVER_UNIT", function() if OpenWorld() then Record("mouseover") end end, nil, true)

-- the events only in the open world: in an instance the handlers did nothing (an instance always comes with a
-- loading screen, so PLAYER_ENTERING_WORLD switches them back); the taxi stays a test in the handlers
local function Apply()
    local world = not IsInInstance()
    local on = db and db.enabled and world and true or false
    local log = db and db.log and world and true or false
    W.Activate(addEv, on or log)
    W.Activate(removeEv, on)
    W.Activate(targetEv, log)
    W.Activate(mouseEv, log)
    wipe(seen)
    Refresh()
end
W.On("PLAYER_ENTERING_WORLD", Apply)

local function Test()
    Create()
    seen.test = "pvp"
    Refresh()
    if db.sound and SOUNDS.pvp then PlaySound(SOUNDS.pvp, "Ambience") end
    C_Timer.After(5, function() seen.test = nil; Refresh() end)
end
W.RegisterTest("Danger alert", function() return db and db.enabled end, Test,
    function() if seen.test then seen.test = nil; Refresh() end end)

W.RegisterModule("DangerAlert", L("Danger alert"), function(p)
    W.Title(p, L("Danger alert"))
    W.Check(p, L("Warn me when danger is near (open world)"), function() return db.enabled end,
        function(v) db.enabled = v; Apply() end):SetPoint("TOPLEFT", 12, -40)
    W.Check(p, L("Enemy players flagged for PvP"), function() return db.players end, function(v) db.players = v end)
        :SetPoint("TOPLEFT", 32, -66)
    W.Check(p, L("Skull and red elite mobs"), function() return db.mobs end, function(v) db.mobs = v end)
        :SetPoint("TOPLEFT", 32, -90)
    W.Check(p, L("Play a sound"), function() return db.sound end, function(v) db.sound = v end):SetPoint("TOPLEFT", 32, -114)
    W.Check(p, L("Lock the warning"), function() return db.locked end, function(v) db.locked = v end):SetPoint("TOPLEFT", 32, -138)
    W.Button(p, L("Test"), 110, 22, Test):SetPoint("TOPLEFT", 16, -172)
    W.Button(p, L("Reset position"), 160, 22, function()
        db.point = { "TOP", "TOP", 0, -90 }
        if frame then Place() end
    end):SetPoint("TOPLEFT", 132, -172)
    local info = W.Label(p, L("Uses the nameplates: enemy nameplates must be shown (V key) to see what is around."), "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, -210)
    info:SetTextColor(0.7, 0.7, 0.7)

    -- enemy players seen
    local list
    local function Age(t)
        local s = math.max(0, time() - (t or 0))
        if s < 60 then return string.format(L("%d s"), s) end
        if s < 3600 then return string.format(L("%d min"), math.floor(s / 60)) end
        if s < 86400 then return string.format(L("%d h"), math.floor(s / 3600)) end
        return string.format(L("%d d"), math.floor(s / 86400))
    end
    local function Fill()
        if not list or not p:IsShown() then return end
        local entries = {}
        for _, e in pairs(db.seen) do
            if db.logClass == "" or e.c == db.logClass then entries[#entries + 1] = e end
        end
        table.sort(entries, function(a, b) return (a.t or 0) > (b.t or 0) end)
        local rows = {}
        for i, e in ipairs(entries) do
            rows[i] = { cells = { W.ColorName(W.Plain(e.n, 60), e.c), e.l and (e.l < 0 and "??" or tostring(e.l)) or "",
                W.Plain(e.g or "", 40), W.Plain(e.z or "", 40), Age(e.t), tostring(e.k or 1) } }
        end
        list:SetData(rows)
    end
    local pending = false
    LogChanged = function()
        if pending or not p:IsShown() then return end
        pending = true
        W.After(0.5, function() pending = false; Fill() end)
    end
    W.Check(p, L("Keep a list of the enemy players seen (open world)"), function() return db.log end,
        function(v) db.log = v; Apply() end, { L("Nameplates, target and mouseover; kept on this computer, 200 players at most. Idea: the Radar of Sashoof's WarLegend v3 addon.") })
        :SetPoint("TOPLEFT", 12, -240)
    local classes = { { "", L("All classes") } }
    for _, c in ipairs({ "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }) do
        classes[#classes + 1] = { c, W.ColorName((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c]) or c, c) }
    end
    W.Cycle(p, 150, classes, function() return db.logClass end, function(v) db.logClass = v; Fill() end)
        :SetPoint("TOPLEFT", 400, -240)
    W.Button(p, L("Clear the list"), 130, 22, function()
        W.Confirm(L("Clear the list of the enemy players seen?"), function() wipe(db.seen); Fill() end)
    end):SetPoint("TOPLEFT", 560, -240)
    list = W.Table(p, { { L("Enemy player"), 200 }, { L("Level"), 50, "CENTER" }, { L("Guild"), 160 }, { L("Zone"), 160 },
        { L("Seen"), 70, "CENTER" }, { L("Times"), 50, "CENTER" } }, 270)
    list:SetPoint("TOPLEFT", 10, -272)
    p:SetScript("OnShow", Fill)
end)

W.slash.danger = function() W.Toggle("DangerAlert") end
