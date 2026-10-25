-- WarLegend RaidTool - Focus
-- Modifier + mouse click = /focus on the hovered unit (Blizzard frames, EllesmereUI, nameplates...).
local W = WLRT
local L = W.L
local db
local AVAILABLE = FocusUnit ~= nil
local prevKey
local bound = setmetatable({}, { __mode = "k" })

-- secure button made out of combat (Apply): after a /reload in combat its attributes would be refused
local btn
local function Btn()
    if not btn then
        btn = CreateFrame("Button", "WLRTFocusButton", UIParent, "SecureActionButtonTemplate")
        btn:RegisterForClicks("AnyUp", "AnyDown")
        btn:SetAttribute("type", "macro")
        btn:SetAttribute("macrotext", "/focus mouseover")
    end
    return btn
end

local function KeyName()
    return string.upper(db.modifier) .. "-BUTTON" .. db.button
end

local function KnownFrames()
    local list = { _G.TargetFrame, _G.PlayerFrame, _G.EllesmereUIUnitFrames_Player, _G.EllesmereUIUnitFrames_Target }
    for i = 1, 5 do list[#list + 1] = _G["Boss" .. i .. "TargetFrame"] end
    return list
end

local function Apply()
    if not db or InCombatLockdown() then return end
    -- secure unit frames: "focus" attribute on the chosen combination
    for f, info in pairs(bound) do
        if f:GetAttribute(info.attr) == "focus" then f:SetAttribute(info.attr, info.orig) end
        bound[f] = nil
    end
    ClearOverrideBindings(Btn())
    prevKey = nil
    if not db.enabled or not AVAILABLE then return end
    local attr = string.lower(db.modifier) .. "-type" .. db.button
    for _, f in pairs(KnownFrames()) do
        if f and f.GetAttribute then
            bound[f] = { attr = attr, orig = f:GetAttribute(attr) }
            f:SetAttribute(attr, "focus")
        end
    end
    prevKey = KeyName()
    SetOverrideBindingClick(btn, true, prevKey, "WLRTFocusButton")
end

W.OnReady(function()
    db = W.DB("focus", { enabled = false, modifier = "shift", button = "1" })
end)
W.On("PLAYER_ENTERING_WORLD", Apply)
W.On("PLAYER_REGEN_ENABLED", Apply)

local MODS = { { "Shift", "shift" }, { "Alt", "alt" }, { "Ctrl", "ctrl" } }
local BUTTONS = { { "Left", "1" }, { "Right", "2" }, { "Middle", "3" }, { "Mouse 4", "4" }, { "Mouse 5", "5" } } -- L() in Label

local function Label(list, v)
    for _, e in ipairs(list) do if e[2] == v then return L(e[1]) end end
    return v
end

local function Next(list, v)
    for i, e in ipairs(list) do if e[2] == v then return list[(i % #list) + 1][2] end end
    return list[1][2]
end

W.RegisterModule("Focus", "Focus", function(p)
    W.Title(p, "Focus")
    if not AVAILABLE then
        W.Label(p, L("Focus is not available on this client."), "GameFontDisable"):SetPoint("TOPLEFT", 16, -44)
        return
    end
    W.Check(p, L("Enable click-to-focus"), function() return db.enabled end,
        function(v) db.enabled = v; Apply() end):SetPoint("TOPLEFT", 12, -40)
    W.Label(p, L("Modifier:"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 16, -76)
    local mod = W.Button(p, "", 100, 22)
    mod:SetPoint("TOPLEFT", 90, -72)
    W.Label(p, L("Click:"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 210, -76)
    local mb = W.Button(p, "", 100, 22)
    mb:SetPoint("TOPLEFT", 260, -72)
    local function sync()
        mod:SetText(Label(MODS, db.modifier))
        mb:SetText(Label(BUTTONS, db.button))
    end
    mod:SetScript("OnClick", function() db.modifier = Next(MODS, db.modifier); sync(); Apply() end)
    mb:SetScript("OnClick", function() db.button = Next(BUTTONS, db.button); sync(); Apply() end)
    mod:SetScript("OnShow", sync)
    sync()
    local info = W.Label(p, L("Click the buttons to change them. E.g. Shift + left-click on a mob or a frame = focus.\n")
        .. L("Settings apply out of combat."), "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, -108)
    info:SetTextColor(0.7, 0.7, 0.7)
end)
