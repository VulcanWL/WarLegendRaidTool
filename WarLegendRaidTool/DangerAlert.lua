-- WarLegend RaidTool - Danger alert (the idea of HighLevelAlert)
-- In the open world, a warning at the top of the screen and a sound when a nameplate shows an enemy player
-- flagged for PvP, a "skull" mob (10+ levels above me) or a red elite (3+ levels). Counts what is near.
-- Cost: one look per nameplate that appears / goes away, nothing in instances, battlegrounds and on a taxi.
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
})
local L = W.L
local db

W.OnReady(function()
    db = W.DB("dangerAlert", { enabled = false, players = true, mobs = true, sound = true, locked = false })
    if type(db.point) ~= "table" then db.point = { "TOP", "TOP", 0, -90 } end
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

local function Refresh()
    if not frame then return end
    local counts = {}
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

-- one sound per kind every 10 s: a camp of elites shows ten nameplates at once
local SOUND_GAP = 10
local soundAt = {}
local addEv = W.On("NAME_PLATE_UNIT_ADDED", function(unit)
    if not db.enabled or not OpenWorld() then return end
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

local function Apply()
    local on = db and db.enabled and true or false
    W.Activate(addEv, on)
    W.Activate(removeEv, on)
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
end)

W.slash.danger = function() W.Toggle("DangerAlert") end
