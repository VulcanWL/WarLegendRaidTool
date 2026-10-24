-- WarLegend RaidTool - Loss of control alert (the idea of OmniCC GODMODE's player CC alert)
-- When I am stunned, feared, silenced, rooted, disarmed or incapacitated: a big icon in the middle of the
-- screen with the countdown and the kind of control, colored by kind. My own data (C_LossOfControl), not secret.
-- Cost: nothing until the game says I lost control; a check every 0.2 s only while it lasts.
local W = WLRT
W.AddFR({
    ["Crowd control alert"] = "Alerte de CC",
    ["Show a big icon when I am crowd controlled"] = "Afficher une grosse icône quand je suis sous contrôle",
    ["Roots too"] = "Aussi les immobilisations",
    ["Play a sound"] = "Jouer un son",
    ["Lock the icon"] = "Verrouiller l'icône",
    ["Size:"] = "Taille :",
    ["Test"] = "Test",
    ["Reset position"] = "Réinitialiser la position",
    ["Stunned"] = "Étourdissement",
    ["Feared"] = "Peur",
    ["Silenced"] = "Silence",
    ["Rooted"] = "Immobilisation",
    ["Disarmed"] = "Désarmement",
    ["Incapacitated"] = "Stupéfaction",
})
local L = W.L
local db

W.OnReady(function()
    db = W.DB("ccAlert", { enabled = false, roots = false, sound = true, locked = false, size = 64 })
    if type(db.point) ~= "table" then db.point = { "CENTER", "CENTER", 0, 120 } end
end)

-- kind of control from the loss of control type (as OmniCC GODMODE)
local KINDS = {
    STUN = { "Stunned", 1, 0.2, 0.2 },
    FEAR = { "Feared", 0.7, 0.2, 1 },
    SILENCE = { "Silenced", 0.2, 0.6, 1 },
    ROOT = { "Rooted", 0.3, 0.8, 0.3 },
    DISARM = { "Disarmed", 1, 0.6, 0.2 },
    INCAP = { "Incapacitated", 1, 0.8, 0.2 },
}
local function Kind(locType)
    local t = tostring(locType or ""):upper()
    if t:find("STUN", 1, true) then return "STUN" end
    if t:find("FEAR", 1, true) or t:find("HORROR", 1, true) then return "FEAR" end
    if t:find("ROOT", 1, true) then return "ROOT" end
    if t:find("SILENCE", 1, true) or t:find("SCHOOL_INTERRUPT", 1, true) then return "SILENCE" end
    if t:find("DISARM", 1, true) then return "DISARM" end
    if t:find("INCAP", 1, true) or t:find("CONFUSE", 1, true) or t:find("PACIFY", 1, true)
        or t:find("CHARM", 1, true) or t:find("POSSESS", 1, true) then return "INCAP" end
end

local frame
local function Place()
    local p = db.point
    frame:ClearAllPoints()
    frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

local function Create()
    if frame then return end
    frame = CreateFrame("Frame", "WLRTCCAlert", UIParent, W.BT)
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
    frame:SetBackdrop({ edgeFile = W.WHITE, edgeSize = 2 })
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetPoint("TOPLEFT", 2, -2)
    frame.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.cd = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.cd:SetAllPoints(frame.icon)
    frame.cd:SetReverse(true)
    frame.cd:SetDrawEdge(false)
    frame.label = frame:CreateFontString(nil, "OVERLAY")
    W.SetFont(frame.label, W.FONT, 14, "OUTLINE")
    frame.label:SetPoint("TOP", frame, "BOTTOM", 0, -4)
    frame:Hide()
    Place()
end

local shownKind, shownEnds, ticking -- the control drawn now: the same one is not drawn again every 0.2 s
local TICK_LABEL
local function Scan()
    if not db or not db.enabled or not frame then return end
    local best, bestIcon, bestStart, bestDur, bestEnds, bestText -- locals, no table per control found
    local LoC = C_LossOfControl
    if LoC and LoC.GetActiveLossOfControlDataCount and LoC.GetActiveLossOfControlData then
        local ok, count = pcall(LoC.GetActiveLossOfControlDataCount)
        for i = 1, (ok and type(count) == "number") and count or 0 do
            local okData, data = pcall(LoC.GetActiveLossOfControlData, i)
            if okData and type(data) == "table" then
                local kind = Kind(W.Safe(data.locType))
                local start, dur = W.Safe(data.startTime), W.Safe(data.duration)
                if kind and (kind ~= "ROOT" or db.roots) then
                    local ends = (type(start) == "number" and type(dur) == "number") and (start + dur) or 0
                    if not best or ends > bestEnds then
                        best, bestIcon, bestStart, bestDur, bestEnds = kind, W.Safe(data.iconTexture) or W.Safe(data.texture), start, dur, ends
                        bestText = W.Safe(data.displayText)
                    end
                end
            end
        end
    end
    if not best then
        frame:Hide()
        shownKind, shownEnds = nil, nil
        return
    end
    if best ~= shownKind or bestEnds ~= shownEnds then
        shownKind, shownEnds = best, bestEnds
        local k = KINDS[best]
        frame:SetSize(db.size, db.size)
        frame:SetBackdropBorderColor(k[2], k[3], k[4], 1)
        frame.icon:SetTexture(bestIcon or 136116)
        frame.label:SetText(bestText or L(k[1]))
        frame.label:SetTextColor(k[2], k[3], k[4])
        if type(bestStart) == "number" and type(bestDur) == "number" and bestDur > 0 then
            frame.cd:SetCooldown(bestStart, bestDur)
        else
            frame.cd:Clear()
        end
        if db.sound and not frame:IsShown() and SOUNDKIT then PlaySound(SOUNDKIT.RAID_WARNING, "Master") end
    end
    frame:Show()
end

-- one check every 0.2 s while a control lasts (they can end without an event)
local function Tick()
    Scan()
    TICK_LABEL = TICK_LABEL or ("timer " .. W.Where(1))
    if frame and frame:IsShown() then W.After(0.2, Tick, TICK_LABEL) else ticking = false end
end
local function Start()
    if not db or not db.enabled then return end
    Create()
    if not ticking then ticking = true; Tick() end
end

-- these events are not on every client: registered one by one, an unknown one is skipped
local events = CreateFrame("Frame")
for _, e in ipairs({ "LOSS_OF_CONTROL_ADDED", "LOSS_OF_CONTROL_UPDATE", "PLAYER_CONTROL_LOST" }) do
    pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function() if W.Allowed() and not W.IsOff("CCAlert") then Start() end end)

local function Test()
    Create()
    shownKind, shownEnds = nil, nil -- the test draws its own: a real control after it is drawn again
    local k = KINDS.STUN
    frame:SetSize(db.size, db.size)
    frame:SetBackdropBorderColor(k[2], k[3], k[4], 1)
    frame.icon:SetTexture(132298) -- Kidney Shot
    frame.label:SetText(L(k[1]))
    frame.label:SetTextColor(k[2], k[3], k[4])
    frame.cd:SetCooldown(GetTime(), 5)
    frame:Show()
    C_Timer.After(5, function() if frame then frame:Hide() end end)
end
W.RegisterTest("Crowd control alert", function() return db and db.enabled end, Test,
    function() if frame then frame:Hide() end end)

W.RegisterModule("CCAlert", L("Crowd control alert"), function(p)
    W.Title(p, L("Crowd control alert"))
    W.Check(p, L("Show a big icon when I am crowd controlled"), function() return db.enabled end,
        function(v) db.enabled = v; if not v and frame then frame:Hide() end end):SetPoint("TOPLEFT", 12, -40)
    W.Check(p, L("Roots too"), function() return db.roots end, function(v) db.roots = v end):SetPoint("TOPLEFT", 32, -66)
    W.Check(p, L("Play a sound"), function() return db.sound end, function(v) db.sound = v end):SetPoint("TOPLEFT", 32, -90)
    W.Check(p, L("Lock the icon"), function() return db.locked end, function(v) db.locked = v end):SetPoint("TOPLEFT", 32, -114)
    W.Label(p, L("Size:"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 36, -150)
    local sizes = {}
    for _, s in ipairs({ 48, 64, 80, 96, 128 }) do sizes[#sizes + 1] = { s, tostring(s) } end
    W.Cycle(p, 70, sizes, function() return db.size end, function(v) db.size = v; if frame then frame:SetSize(v, v) end end)
        :SetPoint("TOPLEFT", 90, -145)
    W.Button(p, L("Test"), 110, 22, Test):SetPoint("TOPLEFT", 16, -184)
    W.Button(p, L("Reset position"), 160, 22, function()
        db.point = { "CENTER", "CENTER", 0, 120 }
        if frame then Place() end
    end):SetPoint("TOPLEFT", 132, -184)
end)

W.slash.cc = function() W.Toggle("CCAlert") end
