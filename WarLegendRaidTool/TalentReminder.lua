-- WarLegend RaidTool - Talent Reminder (vanilla take on CC RaidTools' Spec Reminder)
-- Shows your talent spread when entering a raid / dungeon and on every ready check,
-- + a break window when BigWigs starts a /break.
local W = WLRT
local L = W.L
local db
local reminder, breakFrame
local wasInInstance = false
local DURATION = 15

W.AddFR({
    ["Rank %d / %d"] = "Rang %d / %d",
})

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

-- Talent grid, laid out like the game's talent frame: the 3 trees side by side, each node at its C_Traits position
local ICON, STEP, PAD, MAX_W = 28, 38, 12, 900 -- icon size, space of one grid step, tree margin, widest window

local function TalentButton(parent)
    local b = CreateFrame("Frame", nil, parent)
    b:SetSize(ICON, ICON)
    b.edge = b:CreateTexture(nil, "BACKGROUND")
    b.edge:SetPoint("TOPLEFT", -2, 2)
    b.edge:SetPoint("BOTTOMRIGHT", 2, -2)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.rank = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    b.rank:SetPoint("BOTTOMRIGHT", 4, -4)
    b:EnableMouse(true)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.spellID and GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(self.spellID) end
        GameTooltip:AddLine(string.format(L("Rank %d / %d"), self.r, self.m), 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

-- Smallest step between two node positions (the grid step), Blizzard's 600 if there is none
local function GridStep(grid)
    local step
    for _, t in ipairs(grid.trees) do
        for _, a in ipairs(t.nodes) do
            for _, b in ipairs(t.nodes) do
                local dx, dy = math.abs(a.x - b.x), math.abs(a.y - b.y)
                if dx > 0 and (not step or dx < step) then step = dx end
                if dy > 0 and (not step or dy < step) then step = dy end
            end
        end
    end
    return step or 600
end

local function DrawGrid(f, grid)
    f.trees = f.trees or {}
    local scale = STEP / GridStep(grid)
    local minY, maxY, widest = math.huge, -math.huge, 0
    for _, t in ipairs(grid.trees) do
        t.minX, t.maxX = math.huge, -math.huge
        for _, n in ipairs(t.nodes) do
            t.minX, t.maxX = math.min(t.minX, n.x), math.max(t.maxX, n.x)
            minY, maxY = math.min(minY, n.y), math.max(maxY, n.y)
        end
        if #t.nodes > 0 then widest = math.max(widest, t.maxX - t.minX) end
    end
    if minY > maxY then return nil end
    local count = #grid.trees
    -- too wide for the screen: smaller steps (the icons stay readable)
    local treeW = widest * scale + ICON + 2 * PAD
    if count * treeW + 24 > MAX_W then
        scale = scale * (MAX_W - 24 - count * (ICON + 2 * PAD)) / (count * widest * scale)
        treeW = widest * scale + ICON + 2 * PAD
    end
    local gridH = (maxY - minY) * scale + ICON
    for i, t in ipairs(grid.trees) do
        local p = f.trees[i]
        if not p then
            p = CreateFrame("Frame", nil, f)
            p.bg = p:CreateTexture(nil, "BACKGROUND")
            p.bg:SetAllPoints()
            W.SetColor(p.bg, 0, 0, 0, 0.35)
            p.head = W.Label(p, "", "GameFontNormal")
            p.head:SetPoint("TOP", 0, -6)
            p.buttons, p.lines = {}, {}
            f.trees[i] = p
        end
        p:SetSize(treeW, gridH + 2 * PAD + 22)
        p:SetPoint("TOPLEFT", 12 + (i - 1) * (treeW + 4), -64)
        p.head:SetText(t.name .. "  |cffffffff" .. t.spent .. "|r")
        local byID = {}
        for k, n in ipairs(t.nodes) do
            local b = p.buttons[k] or TalentButton(p)
            p.buttons[k] = b
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", PAD + (n.x - t.minX) * scale, -(PAD + 22 + (n.y - minY) * scale))
            b.icon:SetTexture(n.icon or 134400)
            b.icon:SetDesaturated(n.rank == 0 and not n.available)
            b.icon:SetAlpha((n.rank > 0 or n.available) and 1 or 0.5)
            if n.max > 0 and n.rank >= n.max then W.SetColor(b.edge, 1, 0.82, 0, 1)
            elseif n.rank > 0 or n.available then W.SetColor(b.edge, 0.25, 0.85, 0.25, 1)
            else W.SetColor(b.edge, 0.3, 0.3, 0.3, 1) end
            b.rank:SetText(n.rank .. "/" .. n.max)
            b.rank:SetTextColor(n.rank > 0 and 0.25 or 0.8, n.rank > 0 and 1 or 0.8, n.rank > 0 and 0.25 or 0.8)
            b.spellID, b.r, b.m = n.spellID, n.rank, n.max
            b:Show()
            byID[n.id] = b
        end
        for k = #t.nodes + 1, #p.buttons do p.buttons[k]:Hide() end
        -- prerequisite lines (behind the icons: the buttons are child frames)
        local used = 0
        if p.CreateLine then
            for _, n in ipairs(t.nodes) do
                for _, target in ipairs(n.edges) do
                    local to = byID[target]
                    if to then
                        used = used + 1
                        local ln = p.lines[used]
                        if not ln then
                            ln = p:CreateLine(nil, "BORDER")
                            ln:SetThickness(2)
                            p.lines[used] = ln
                        end
                        ln:SetStartPoint("CENTER", byID[n.id])
                        ln:SetEndPoint("CENTER", to)
                        if to.r > 0 then W.SetColor(ln, 1, 0.82, 0, 0.9) else W.SetColor(ln, 0.5, 0.5, 0.5, 0.7) end
                        ln:Show()
                    end
                end
            end
        end
        for k = used + 1, #p.lines do p.lines[k]:Hide() end
        p:Show()
    end
    for i = count + 1, #f.trees do f.trees[i]:Hide() end
    return 24 + count * treeW + (count - 1) * 4, 64 + gridH + 2 * PAD + 22 + 34
end

local function ShowReminder()
    if not reminder then
        reminder = W.Window("WLRTTalentReminder", 340, 120, L("Check your talents"))
        reminder:SetPoint("CENTER", 0, 120)
        reminder.body = W.Label(reminder, "", "GameFontHighlight")
        reminder.body:SetPoint("TOPLEFT", 16, -36)
        reminder.body:SetPoint("RIGHT", -16, 0)
        reminder.bar = W.TimerBar(reminder, 12)
        reminder.bar:SetPoint("BOTTOMLEFT", 14, 10)
        reminder.bar:SetPoint("BOTTOMRIGHT", -14, 10)
    end
    local summary, main = TalentSummary()
    local grid = W.TalentGrid()
    local w, h
    if grid then w, h = DrawGrid(reminder, grid) end
    if w then
        -- the grid shows the points per tree: one line is enough
        reminder.body:SetText(L("Main tree: |cffffcc00") .. (grid.best or main or "?") .. "|r")
        W.Size(reminder, math.max(340, w), h)
    else
        if reminder.trees then for _, p in ipairs(reminder.trees) do p:Hide() end end
        reminder.body:SetText(L("Main tree: |cffffcc00") .. (main or "?") .. "|r\n|cffaaaaaa" .. summary .. "|r")
        W.Size(reminder, 340, 120)
    end
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
