-- WarLegend RaidTool - Graveyard timer
-- Battleground spirit healer wave timer (display only): the game gives the time left before the next
-- 30 second resurrection wave while you are dead; the bar keeps counting the waves after you are back.
-- It never releases, accepts or clicks anything for you. Cost: nothing outside a battleground (the bar
-- is created when you first enter one, its one-tenth-of-a-second update runs only while it is shown).
local W = WLRT
W.AddFR({
    ["Graveyard timer"] = "Chrono cimetière",
    ["Show the graveyard timer in battlegrounds"] = "Afficher le chrono de cimetière en champ de bataille",
    ["Lock the bar"] = "Verrouiller la barre",
    ["Unlocked: drag the bar to move it."] = "Déverrouillée : fais glisser la barre pour la déplacer.",
    ["Test (fake waves)"] = "Test (fausses vagues)",
    ["Reset position"] = "Réinitialiser la position",
    ["Die once to sync"] = "Meurs une fois pour synchro",
    ["GY rez"] = "Rez cimetière",
    ["Spirit healer waves come every 30 seconds. Die once in the battleground to synchronise the bar with the game, it then keeps counting."] =
        "Les vagues du guérisseur d'âmes arrivent toutes les 30 secondes. Meurs une fois dans le champ de bataille pour synchroniser la barre avec le jeu, elle continue ensuite de compter.",
    ["The separate GYTimer addon is loaded: disable it, this module replaces it."] =
        "L'addon GYTimer séparé est chargé : désactive-le, ce module le remplace.",
})
local L = W.L
local db
local WAVE, SOON, STEP = 30, 5, 0.2 -- 5 redraws a second (10 the whole battleground before)
local frame, bar, text, timeText
-- Same look as the Capping bars (LibCandyBar with Capping's defaults)
local CAP_TEXTURE = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill"
local CAP_ICON = "Interface\\Icons\\Spell_Holy_Resurrection"
local CAP_W, CAP_H, CAP_FONT_SIZE = 200, 20, 10
local nextWave -- GetTime() of the next wave, nil until synced with the spirit healer
local testMode, acc = false, 0
local testRun = 0
local healerEv
local standalone = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("GYTimer")

W.OnReady(function()
    db = W.DB("gyTimer", { enabled = true, locked = false })
    if type(db.point) ~= "table" then db.point = { "TOP", "TOP", 0, -120 } end
end)

local function InBattleground()
    local _, kind = IsInInstance()
    return kind == "pvp"
end

local function SyncFromSpiritHealer()
    if not UnitIsDeadOrGhost("player") or not GetAreaSpiritHealerTime then return end
    local left = W.Safe(GetAreaSpiritHealerTime())
    if type(left) == "number" and left > 0 then nextWave = GetTime() + left end
end

local function Update()
    if not testMode then SyncFromSpiritHealer() end
    if not nextWave then
        bar:SetValue(0)
        text:SetText(L("Die once to sync"))
        timeText:SetText("")
        return
    end
    local now = GetTime()
    while nextWave <= now do nextWave = nextWave + WAVE end -- the waves go on after you are back alive
    local left = nextWave - now
    bar:SetValue(left)
    if left <= SOON then bar:SetStatusBarColor(1, 0, 0) else bar:SetStatusBarColor(1, 1, 0) end
    text:SetText(L("GY rez"))
    if left < 10 then timeText:SetFormattedText("%.1f", left) else timeText:SetFormattedText("%d", left) end
end

local function Place()
    local p = db.point
    frame:ClearAllPoints()
    frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

local function Create()
    if frame then return end
    frame = CreateFrame("Frame", "WLRTGYTimerFrame", UIParent)
    frame:SetSize(CAP_W, CAP_H)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:Hide()
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(CAP_H, CAP_H)
    icon:SetPoint("LEFT")
    icon:SetTexture(CAP_ICON)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    bar = CreateFrame("StatusBar", nil, frame)
    bar:SetPoint("TOPLEFT", icon, "TOPRIGHT")
    bar:SetPoint("BOTTOMRIGHT")
    bar:SetStatusBarTexture(CAP_TEXTURE)
    bar:SetMinMaxValues(0, WAVE)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(CAP_TEXTURE)
    bg:SetVertexColor(0, 0, 0, 0.75)
    timeText = bar:CreateFontString(nil, "OVERLAY")
    timeText:SetFont(W.FONT, CAP_FONT_SIZE, "")
    timeText:SetShadowOffset(1, -1)
    timeText:SetTextColor(1, 1, 1)
    timeText:SetPoint("RIGHT", -2, 0)
    timeText:SetJustifyH("RIGHT")
    text = bar:CreateFontString(nil, "OVERLAY")
    text:SetFont(W.FONT, CAP_FONT_SIZE, "")
    text:SetShadowOffset(1, -1)
    text:SetTextColor(1, 1, 1)
    text:SetPoint("LEFT", 2, 0)
    text:SetPoint("RIGHT", timeText, "LEFT", -2, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    frame:SetScript("OnDragStart", function(self) if not db.locked then self:StartMoving() end end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, rel, x, y = self:GetPoint()
        db.point = { point, rel, x, y }
    end)
    frame:SetScript("OnUpdate", function(_, e)
        acc = acc + e
        if acc < STEP then return end
        acc = 0
        Update()
    end)
    Place()
end

local function Refresh()
    if standalone or not db then return end
    local show = db.enabled and (testMode or InBattleground())
    W.Activate(healerEv, show and true or false)
    if show then
        Create()
        frame:Show()
        Update()
    elseif frame then
        frame:Hide()
    end
end

healerEv = W.On("AREA_SPIRIT_HEALER_IN_RANGE", SyncFromSpiritHealer, nil, true)
W.On("PLAYER_ENTERING_WORLD", function() nextWave = nil; Refresh() end)
W.On("ZONE_CHANGED_NEW_AREA", Refresh)

W.slash.gy = function()
    if standalone then W.Print(L("The separate GYTimer addon is loaded: disable it, this module replaces it.")); return end
    testMode = not testMode
    nextWave = testMode and (GetTime() + WAVE) or nil
    Refresh()
    -- the test stops by itself after two fake waves (a newer test keeps its own stop)
    testRun = testRun + 1
    local run = testRun
    if testMode then
        W.After(2 * WAVE + 1, function()
            if testMode and run == testRun then testMode = false; nextWave = nil; Refresh() end
        end)
    end
end
W.RegisterTest("Graveyard timer", function() return db and db.enabled and not standalone end,
    function() if not testMode then W.slash.gy() end end,
    function()
        if not testMode then return end
        testMode, nextWave, testRun = false, nil, testRun + 1
        Refresh()
    end)

W.RegisterModule("GYTimer", "Graveyard timer", function(p)
    W.Title(p, L("Graveyard timer"))
    if standalone then
        W.Label(p, L("The separate GYTimer addon is loaded: disable it, this module replaces it."), "GameFontHighlight")
            :SetPoint("TOPLEFT", 16, -44)
    end
    W.Check(p, L("Show the graveyard timer in battlegrounds"), function() return db.enabled end,
        function(v) db.enabled = v; Refresh() end):SetPoint("TOPLEFT", 12, -70)
    W.Check(p, L("Lock the bar"), function() return db.locked end, function(v) db.locked = v end,
        { L("Unlocked: drag the bar to move it.") })
        :SetPoint("TOPLEFT", 12, -96)
    W.Button(p, L("Test (fake waves)"), 170, 22, function() W.slash.gy() end):SetPoint("TOPLEFT", 16, -130)
    W.Button(p, L("Reset position"), 162, 22, function()
        db.point = { "TOP", "TOP", 0, -120 }
        if frame then Place() end
    end):SetPoint("TOPLEFT", 196, -130)
    local info = W.Label(p, L("Spirit healer waves come every 30 seconds. Die once in the battleground to synchronise the bar with the game, it then keeps counting."),
        "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, -170)
    info:SetWidth(700)
    info:SetJustifyH("LEFT")
    info:SetTextColor(0.7, 0.7, 0.7)
end)
