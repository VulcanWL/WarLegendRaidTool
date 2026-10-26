-- WarLegend RaidTool - Marks Bar
-- Movable bar: 8 raid marks on the target (+ world markers if the client supports them).
local W = WLRT
local L = W.L
local db
local bar, raidButtons, worldButtons = nil, {}, {}
local layoutPending = false
-- /wm order requested by the guild (same as CC RaidTools)
local WORLD_MARK = { [1] = 5, [2] = 6, [3] = 3, [4] = 2, [5] = 7, [6] = 1, [7] = 4, [8] = 8 }
local HAS_WORLD = PlaceRaidMarker ~= nil

local function SavePos()
    local p, _, rp, x, y = bar:GetPoint(1)
    db.point, db.relPoint, db.x, db.y = p, rp, x, y
end

local function IconButton(size, secure)
    local b = CreateFrame("Button", nil, bar, secure and "SecureActionButtonTemplate" or nil)
    W.Size(b, size, size)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    W.SetColor(b.bg, 0.02, 0.02, 0.03, 0.85)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 3, -3)
    b.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    return b
end

local function Layout()
    if not bar then return end
    if InCombatLockdown() then layoutPending = true; return end
    layoutPending = false
    local horiz = db.orientation ~= "VERTICAL"
    local gap, rs, ws = 2, 28, 22
    local rowW = 8 * rs + 7 * gap
    local wOff = (rowW - (8 * ws + 7 * gap)) / 2
    local rows = HAS_WORLD and 2 or 1
    if horiz then W.Size(bar, rowW, rs + (rows - 1) * (ws + gap)) else W.Size(bar, rs + (rows - 1) * (ws + gap), rowW) end
    for i, b in ipairs(raidButtons) do
        b:ClearAllPoints()
        local o = (i - 1) * (rs + gap)
        if horiz then b:SetPoint("TOPLEFT", o, 0) else b:SetPoint("TOPLEFT", 0, -o) end
    end
    for i, b in ipairs(worldButtons) do
        b:ClearAllPoints()
        local o = wOff + (i - 1) * (ws + gap)
        if horiz then b:SetPoint("TOPLEFT", o, -(rs + gap)) else b:SetPoint("TOPLEFT", rs + gap, -o) end
    end
    bar:SetScale(db.scale or 1)
end

-- Mouseover fade: polled 20 times/s, and only installed when the option is on
local elapsedSum = 0
local function MouseoverFade(self, e)
    elapsedSum = elapsedSum + e
    if elapsedSum < 0.05 then return end
    elapsedSum = 0
    local want = self:IsMouseOver() and 1 or 0
    if self:GetAlpha() ~= want then self:SetAlpha(want) end
end

local function ApplyDisplay()
    if not bar or InCombatLockdown() then return end
    if db.enabled then bar:Show() else bar:Hide() end
    bar:SetScript("OnUpdate", db.mouseover and MouseoverFade or nil)
    bar:SetAlpha((db.mouseover and not bar:IsMouseOver()) and 0 or 1)
end

local function CreateBar()
    if bar then return end
    bar = CreateFrame("Frame", "WarLegendMarksBar", UIParent)
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function(self) if not db.locked and not InCombatLockdown() then self:StartMoving() end end)
    bar:SetScript("OnDragStop", function(self) if not InCombatLockdown() then self:StopMovingOrSizing(); SavePos() end end)
    bar:SetPoint(db.point or "CENTER", UIParent, db.relPoint or "CENTER", db.x or 0, db.y or -180)
    for i = 1, 8 do
        -- secure "raidtarget" action on the target: WoW: Forever refuses SetRaidTarget to addon code
        local b = IconButton(28, true)
        b.icon:SetTexture(W.ICON .. i)
        b:RegisterForClicks("AnyUp", "AnyDown")
        b:SetAttribute("type1", "raidtarget"); b:SetAttribute("marker1", i); b:SetAttribute("action1", "set")
        b:SetAttribute("type2", "raidtarget"); b:SetAttribute("marker2", i); b:SetAttribute("action2", "clear")
        b:RegisterForDrag("LeftButton")
        b:SetScript("OnDragStart", function() if not db.locked and not InCombatLockdown() then bar:StartMoving() end end)
        b:SetScript("OnDragStop", function() if not InCombatLockdown() then bar:StopMovingOrSizing(); SavePos() end end)
        W.Tooltip(b, L("Raid mark: ") .. W.ICON_NAMES[i], { L("Left-click: set on target"), L("Right-click: remove") })
        raidButtons[i] = b
    end
    if HAS_WORLD then
        for i = 1, 8 do
            local b = IconButton(22, true)
            b.icon:SetTexture(W.ICON .. i)
            b.icon:SetVertexColor(1, 0.85, 0.35, 0.85)
            b:RegisterForClicks("AnyUp", "AnyDown")
            b:SetAttribute("type1", "worldmarker"); b:SetAttribute("marker1", WORLD_MARK[i]); b:SetAttribute("action1", "set")
            b:SetAttribute("type2", "worldmarker"); b:SetAttribute("marker2", WORLD_MARK[i]); b:SetAttribute("action2", "clear")
            W.Tooltip(b, L("World marker ") .. WORLD_MARK[i], { L("Left-click: place"), L("Right-click: remove") })
            worldButtons[i] = b
        end
    end
    Layout()
    ApplyDisplay()
end

-- switched on in Settings > Modules after the login: the bar is made when its tab needs it
local function EnsureBar()
    if not bar and db and not InCombatLockdown() and not W.IsOff("MarksBar") then CreateBar() end
    return bar
end

W.OnReady(function()
    db = W.DB("marksBar", { enabled = false, locked = false, mouseover = false, orientation = "HORIZONTAL", scale = 1 })
    -- secure buttons: a /reload in combat makes it after; switched off in the module list: not made at all
    if not InCombatLockdown() and not W.IsOff("MarksBar") then CreateBar() end
end)

W.On("PLAYER_REGEN_ENABLED", function()
    if not bar and db and not W.IsOff("MarksBar") then CreateBar() end
    if layoutPending then Layout() end
    ApplyDisplay()
end)

W.RegisterModule("MarksBar", "Marks Bar", function(p)
    W.Title(p, L("Marks Bar"))
    W.Check(p, L("Show the bar"), function() return db.enabled end,
        function(v) db.enabled = v; EnsureBar(); ApplyDisplay() end):SetPoint("TOPLEFT", 12, -40)
    W.Check(p, L("Lock position"), function() return db.locked end,
        function(v) db.locked = v end):SetPoint("TOPLEFT", 12, -66)
    W.Check(p, L("Only visible on mouseover"), function() return db.mouseover end,
        function(v) db.mouseover = v; EnsureBar(); ApplyDisplay() end):SetPoint("TOPLEFT", 12, -92)
    W.Button(p, L("Horizontal"), 100, 22, function() db.orientation = "HORIZONTAL"; Layout() end):SetPoint("TOPLEFT", 16, -126)
    W.Button(p, L("Vertical"), 100, 22, function() db.orientation = "VERTICAL"; Layout() end):SetPoint("TOPLEFT", 122, -126)
    W.Button(p, L("Size -"), 80, 22, function() db.scale = math.max(0.6, (db.scale or 1) - 0.1); Layout() end):SetPoint("TOPLEFT", 16, -154)
    W.Button(p, L("Size +"), 80, 22, function() db.scale = math.min(2, (db.scale or 1) + 0.1); Layout() end):SetPoint("TOPLEFT", 102, -154)
    W.Button(p, L("Recenter the bar"), 150, 22, function()
        if InCombatLockdown() or not EnsureBar() then return end
        db.point, db.relPoint, db.x, db.y = "CENTER", "CENTER", 0, -180
        bar:ClearAllPoints()
        bar:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
    end):SetPoint("TOPLEFT", 16, -182)
    local info = W.Label(p, L("Row 1: raid marks on your target (right-click to remove).\n")
        .. (HAS_WORLD and L("Row 2: world markers.") or L("World markers: not supported by this client."))
        .. L("\nDrag the bar to move it (if unlocked)."), "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, -216)
    info:SetTextColor(0.7, 0.7, 0.7)
end)
