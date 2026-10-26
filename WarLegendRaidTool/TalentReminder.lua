-- WarLegend RaidTool - Talent Reminder (vanilla take on CC RaidTools' Spec Reminder)
-- Shows your talent spread when entering a raid / dungeon and on every ready check,
-- + a break window when BigWigs starts a /break.
local W = WLRT
local L = W.L
local db
local reminder, breakFrame
local wasInInstance = false
local DURATION = 15

W.OnReady(function()
    db = W.DB("talentReminder", { enabled = true, onZone = true, onReadyCheck = true, onBreak = true })
end)

-- "Arcane 31 / Fire 0 / Frost 20": modern C_Traits on Forever, old talent API elsewhere
local function TalentSummary()
    local t = W.OwnTalents()
    if not t then return L("unknown") end
    local parts = {}
    for i, name in ipairs(t.names) do parts[i] = name .. " " .. t.spent[i] end
    return table.concat(parts, " / "), t.best
end

local function Countdown(f, seconds, fmt, onDone)
    local endAt = GetTime() + seconds
    local shown -- last second displayed: the text is rebuilt once per second, not every frame
    f.bar:SetMinMaxValues(0, seconds)
    f:SetScript("OnUpdate", function(self)
        local left = endAt - GetTime()
        if left <= 0 then
            self:SetScript("OnUpdate", nil)
            self:Hide()
            if onDone then onDone() end
            return
        end
        self.bar:SetValue(left)
        local secs = math.ceil(left)
        if secs ~= shown then shown = secs; self.bar.text:SetText(fmt(left)) end
    end)
end

local function ShowReminder()
    if not reminder then
        reminder = W.Window("WLRTTalentReminder", 340, 120, L("Check your talents"))
        reminder:SetPoint("CENTER", 0, 120)
        reminder.body = W.Label(reminder, "", "GameFontHighlight")
        reminder.body:SetPoint("TOPLEFT", 16, -36)
        reminder.body:SetWidth(308)
        reminder.bar = W.TimerBar(reminder, 12)
        reminder.bar:SetPoint("BOTTOMLEFT", 14, 10)
        reminder.bar:SetPoint("BOTTOMRIGHT", -14, 10)
    end
    local summary, main = TalentSummary()
    reminder.body:SetText(L("Main tree: |cffffcc00") .. (main or "?") .. "|r\n|cffaaaaaa" .. summary .. "|r")
    reminder:Show()
    Countdown(reminder, DURATION, function(left) return string.format(L("Closing in %d s"), math.ceil(left)) end)
end

local function HideBreak()
    if breakFrame then breakFrame:SetScript("OnUpdate", nil); breakFrame:Hide() end
end

local function ShowBreak(seconds)
    seconds = tonumber(seconds) or 0
    if seconds <= 0 then HideBreak(); return end
    if not breakFrame then
        breakFrame = W.Window("WLRTBreak", 240, 90, L("Break!"))
        breakFrame:SetPoint("CENTER", 0, -120)
        breakFrame.big = W.Label(breakFrame, "", "GameFontNormalHuge")
        breakFrame.big:SetPoint("TOP", 0, -30)
        breakFrame.bar = W.TimerBar(breakFrame, 12)
        breakFrame.bar:SetPoint("BOTTOMLEFT", 14, 10)
        breakFrame.bar:SetPoint("BOTTOMRIGHT", -14, 10)
    end
    breakFrame:Show()
    Countdown(breakFrame, seconds, function(left)
        local s = math.ceil(left)
        local clock = string.format("%d:%02d", math.floor(s / 60), s % 60)
        breakFrame.big:SetText(clock)
        return L("Resuming in ") .. clock
    end)
end

local function HookBigWigs()
    if not BigWigsLoader or not BigWigsLoader.RegisterMessage then return end
    local listener = {}
    BigWigsLoader.RegisterMessage(listener, "BigWigs_StartBreak", function(_, _, seconds)
        -- BigWigs calls us outside our event table: the module switch is checked here
        if db and db.onBreak and W.Allowed() and not W.IsOff("TalentReminder") then ShowBreak(seconds) end
    end)
    BigWigsLoader.RegisterMessage(listener, "BigWigs_StopBreak", HideBreak)
end

W.On("PLAYER_LOGIN", HookBigWigs)
W.On("PLAYER_ENTERING_WORLD", function()
    W.After(0.5, function()
        local inInstance, instanceType = IsInInstance()
        if db.enabled and db.onZone and inInstance and not wasInInstance
            and (instanceType == "raid" or instanceType == "party") then
            ShowReminder()
        end
        wasInInstance = inInstance
    end)
end)
W.On("READY_CHECK", function()
    if db.enabled and db.onReadyCheck then ShowReminder() end
end)

W.RegisterModule("TalentReminder", "Talent Reminder", function(p)
    W.Title(p, L("Talent Reminder"))
    W.Check(p, L("Enable talent reminder"), function() return db.enabled end,
        function(v) db.enabled = v end):SetPoint("TOPLEFT", 12, -40)
    W.Check(p, L("When entering a raid or dungeon"), function() return db.onZone end,
        function(v) db.onZone = v end):SetPoint("TOPLEFT", 32, -66)
    W.Check(p, L("On every ready check"), function() return db.onReadyCheck end,
        function(v) db.onReadyCheck = v end):SetPoint("TOPLEFT", 32, -92)
    W.Check(p, L("Break window during BigWigs /break"), function() return db.onBreak end,
        function(v) db.onBreak = v; if not v then HideBreak() end end):SetPoint("TOPLEFT", 12, -118)
    W.Button(p, L("Test reminder"), 140, 22, ShowReminder):SetPoint("TOPLEFT", 16, -152)
    W.Button(p, L("Test break"), 140, 22, function() ShowBreak(60) end):SetPoint("TOPLEFT", 162, -152)
    local info = W.Label(p, L("Talents cannot be changed in combat: the reminder shows before the pull."),
        "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, -186)
    info:SetTextColor(0.7, 0.7, 0.7)
end)
