-- WarLegend RaidTool - Combat Timer
-- Small movable mm:ss timer for the current fight (any combat, or boss fights only).
-- One text update per second while a fight is running, nothing at all otherwise. Never in PvP.
local W = WLRT
W.AddFR({
    ["Combat Timer"] = "Chrono de combat",
    ["Show the combat timer"] = "Afficher le chrono de combat",
    ["Boss fights only"] = "Combats de boss uniquement",
    ["Hide out of combat"] = "Masquer hors combat",
    ["Lock position"] = "Verrouiller la position",
    ["Reset position"] = "Réinitialiser la position",
    ["Starts on entering combat (or on the boss pull) and stops at the end of the fight."] =
        "Démarre à l'entrée en combat (ou au pull du boss) et s'arrête à la fin du combat.",
})
local L = W.L

local db
local frame, ticker
local startAt, isEncounter = nil, false

local function Format(secs)
    secs = math.floor(secs)
    if secs >= 3600 then
        return string.format("%d:%02d:%02d", math.floor(secs / 3600), math.floor(secs / 60) % 60, secs % 60)
    end
    return string.format("%d:%02d", math.floor(secs / 60), secs % 60)
end

local function Update()
    if startAt then frame.text:SetText(Format(GetTime() - startAt)) end
end

local function ApplyVisibility()
    if not frame then return end
    local show = db.enabled and not W.Overlap("combatTimer") and (not db.hideOOC or startAt ~= nil or not db.locked)
    frame:SetShown(show and not W.InPvP())
    frame:EnableMouse(not db.locked)
    frame.bg:SetShown(not db.locked)
end

local function Start(encounter)
    if not db.enabled or W.InPvP() or W.Overlap("combatTimer") then return end
    if db.bossOnly and not encounter then return end
    if startAt then
        -- already timing the fight: a boss pull restarts it as a boss timer
        if encounter and not isEncounter then startAt, isEncounter = GetTime(), true; Update() end
        return
    end
    startAt, isEncounter = GetTime(), encounter
    Update()
    if C_Timer and C_Timer.NewTicker then ticker = C_Timer.NewTicker(1, Update) end
    ApplyVisibility()
end

local function Stop(encounterEnd)
    if not startAt then return end
    -- a boss timer ignores the short out-of-combat moments (death...) while the encounter goes on; WoW Forever has
    -- C_InstanceEncounter only (IsEncounterInProgress is a Blizzard deprecation shim, never loaded there)
    local inProgress = (C_InstanceEncounter and C_InstanceEncounter.IsEncounterInProgress) or IsEncounterInProgress
    if isEncounter and not encounterEnd and inProgress and inProgress() then return end
    if not isEncounter and encounterEnd then return end
    Update()
    startAt = nil
    if ticker then ticker:Cancel(); ticker = nil end
    if db.hideOOC then W.After(5, function() if not startAt then ApplyVisibility() end end) end
end

local function SavePos()
    local p, _, rp, x, y = frame:GetPoint(1)
    db.point, db.relPoint, db.x, db.y = p, rp, x, y
end

local function Build()
    frame = CreateFrame("Frame", "WLRTCombatTimer", UIParent)
    frame:SetSize(90, 28)
    frame:SetPoint(db.point or "TOP", UIParent, db.relPoint or "TOP", db.x or 0, db.y or -120)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) if not db.locked then self:StartMoving() end end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePos() end)
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    W.SetColor(frame.bg, 0, 0, 0, 0.5)
    frame.text = frame:CreateFontString(nil, "OVERLAY")
    frame.text:SetFont(W.FONT, 18, "OUTLINE")
    frame.text:SetPoint("CENTER")
    frame.text:SetText("0:00")
    frame:SetScale(db.scale or 1)
    frame:Hide()
end

W.OnReady(function()
    db = W.DB("combatTimer", { enabled = false, bossOnly = false, hideOOC = false, locked = true, scale = 1 })
    Build()
end)

W.On("PLAYER_ENTERING_WORLD", ApplyVisibility)
W.On("PLAYER_REGEN_DISABLED", function() Start(false) end)
W.On("ENCOUNTER_START", function() Start(true) end)
W.On("PLAYER_REGEN_ENABLED", function() Stop(false) end)
W.On("ENCOUNTER_END", function() Stop(true) end)

W.RegisterModule("CombatTimer", "Combat Timer", function(p)
    W.Title(p, L("Combat Timer"))
    local function opt(key, text, y)
        W.Check(p, text, function() return db[key] end, function(v) db[key] = v; ApplyVisibility() end):SetPoint("TOPLEFT", 12, y)
    end
    opt("enabled", L("Show the combat timer"), -40)
    opt("bossOnly", L("Boss fights only"), -64)
    opt("hideOOC", L("Hide out of combat"), -88)
    opt("locked", L("Lock position"), -112)
    W.Button(p, L("Size -"), 80, 22, function()
        db.scale = math.max(0.6, (db.scale or 1) - 0.1); frame:SetScale(db.scale)
    end):SetPoint("TOPLEFT", 16, -146)
    W.Button(p, L("Size +"), 80, 22, function()
        db.scale = math.min(2.5, (db.scale or 1) + 0.1); frame:SetScale(db.scale)
    end):SetPoint("TOPLEFT", 102, -146)
    W.Button(p, L("Reset position"), 162, 22, function()
        db.point, db.relPoint, db.x, db.y = nil, nil, nil, nil
        frame:ClearAllPoints()
        frame:SetPoint("TOP", UIParent, "TOP", 0, -120)
    end):SetPoint("TOPLEFT", 188, -146)
    local info = W.Label(p, L("Starts on entering combat (or on the boss pull) and stops at the end of the fight."), "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, -182)
    info:SetTextColor(0.7, 0.7, 0.7)
    W.OverlapNote(p, "combatTimer", "TOPLEFT", 16, -210)
    W.Check(p, L("Use it anyway"), W.OverlapForced, W.SetOverlapForce):SetPoint("TOPLEFT", 12, -232)
end)
