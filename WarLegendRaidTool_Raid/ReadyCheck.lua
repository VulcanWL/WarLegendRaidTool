-- WarLegend RaidTool - Ready Check
-- Ready check window: ready / durability / food / flask / class buffs.
-- Vanilla version: buffs detected by spell NAME (all ranks), no rune or vantus.
local W = WLRT
local L = W.L
local db
local DUR_PREFIX = "WLRT_DUR"
local MAX_ROWS = 40
local ROW_H = 18

local frame, rows = nil, {}
local statuses, responded, durability = {}, {}, {}
local finishAt, duration, closeAt = nil, 30, nil

W.OnReady(function() db = W.DB("readyCheck", { enabled = true }) end)

-- Spells matched by localized name: covers every rank
local BUFFS = {
    food = { 19705 },                                   -- Well Fed
    flask = { 17626, 17627, 17628, 17629, 17624 },      -- Flasks (Titans, Wisdom, Supreme Power, Chromatic, Petrification)
    int = { 1459, 23028 },                              -- Arcane Intellect / Brilliance
    stam = { 1243, 21562 },                             -- Fortitude / Prayer of Fortitude
    motw = { 1126, 21849 },                             -- Mark / Gift of the Wild
}
local buffNames
local function BuffNames()
    if buffNames then return buffNames end
    buffNames = {}
    for key, ids in pairs(BUFFS) do
        local set = {}
        for _, id in ipairs(ids) do
            local name = W.SpellName(id)
            if name then set[name] = true end
        end
        buffNames[key] = set
    end
    return buffNames
end

-- One shared set and no closure per aura: this runs for 40 units twice a second
local function AuraName(a) return a.name end
local buffSet = {}
local function UnitBuffSet(unit)
    wipe(buffSet)
    local set = buffSet
    for i = 1, 40 do
        local name
        if W.HAS_AURA_API then
            local a = W.AuraByIndex(unit, i, "HELPFUL") -- false: secret, refused to addons
            if a == nil then break end
            local ok, n = false, nil
            if a then ok, n = pcall(AuraName, a) end -- auras can be secret in combat
            name = ok and n or false
        elseif UnitBuff then
            name = UnitBuff(unit, i)
            if not name then break end
        else
            break
        end
        name = W.Safe(name)
        if name then set[name] = true end
    end
    return set
end

local function Has(set, key)
    for name in pairs(BuffNames()[key]) do
        if set[name] then return true end
    end
    return false
end

-- Lighter path: ask for the dozen buff names we care about instead of reading every aura
-- (40 players x 40 auras). A hidden (secret) answer still means the buff is there.
local FindByName = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
local function UnitHas(unit, key)
    for name in pairs(BuffNames()[key]) do
        local ok, a = pcall(FindByName, unit, name, "HELPFUL")
        if ok and a ~= nil then return true end
    end
    return false
end

local function Check(unit, key, set)
    if FindByName then return UnitHas(unit, key) end
    return Has(set, key)
end

-- Durability (broadcast to other addon users)
local function DurabilityPercent()
    local cur, max = 0, 0
    for slot = 1, 18 do
        local c, m = GetInventoryItemDurability(slot)
        if c and m and m > 0 then cur, max = cur + c, max + m end
    end
    return max == 0 and 100 or cur / max * 100
end

local function SendDurability()
    local p = DurabilityPercent()
    durability[W.UnitKey("player") or "?"] = p
    W.Send(DUR_PREFIX, string.format("%.0f", p))
end

W.OnAddon(DUR_PREFIX, function(msg, from, _, full)
    local unit = W.UnitByName(full or from)
    if not unit then return end -- group members only
    local p = W.Finite(msg, 0, 100)
    if p then
        durability[W.UnitKey(unit)] = p -- full identity: two players can share a first name
        if frame and frame:IsShown() then W.ReadyCheckRefresh() end
    end
end)

local function OK(v) return v and "|cff33ff66OK|r" or "|cffff4444--|r" end
local function ReadyText(v)
    if v == "ready" then return "|cff33ff66OK|r" end
    if v == "notready" then return L("|cffff4444NO|r") end
    return "|cffff9900...|r"
end
local function DurText(v)
    if not v then return "-" end
    local t = string.format("%d%%", math.floor(v + 0.5))
    if v <= 20 then return "|cffff4444" .. t .. "|r" end
    if v <= 50 then return "|cffffcc33" .. t .. "|r" end
    return "|cff66ff66" .. t .. "|r"
end

local COLS = { { L("Name"), 120, "LEFT" }, { L("Ready"), 44 }, { "Dura.", 48 }, { L("Food"), 46 }, { L("Flask"), 50 },
    { "Int", 38 }, { L("Stam"), 40 }, { L("MotW"), 44 } }
W.TranslateField(COLS, 1)

local function BuildFrame()
    if frame then return end
    frame = W.Window("WLRTReadyCheck", 470, 120, "WaR LegenD - Ready Check")
    frame:SetPoint("CENTER", 320, 0)
    frame:SetFrameStrata("HIGH")
    local x = 14
    for _, c in ipairs(COLS) do
        local h = W.Label(frame, c[1], "GameFontNormalSmall")
        h:SetPoint("TOPLEFT", x, -30)
        h:SetWidth(c[2])
        h:SetJustifyH(c[3] or "CENTER")
        h:SetTextColor(0.85, 0.85, 0.85)
        c.x = x
        x = x + c[2]
    end
    frame.count = W.Label(frame, "", "GameFontNormalSmall")
    frame.count:SetPoint("TOPRIGHT", -34, -12)
    frame.list = CreateFrame("Frame", nil, frame)
    frame.list:SetPoint("TOPLEFT", 0, -46)
    frame.list:SetSize(470, ROW_H)
    frame.bar = W.TimerBar(frame, 14)
    frame.bar:SetPoint("BOTTOMLEFT", 12, 10)
    frame.bar:SetPoint("BOTTOMRIGHT", -12, 10)
    frame:SetScript("OnUpdate", function(self)
        local now = GetTime()
        if closeAt and now >= closeAt then closeAt = nil; self:Hide(); return end
        if finishAt then
            local left = math.max(0, finishAt - now)
            self.bar:SetValue(left)
            -- the text only changes once per second: no new string every frame
            local secs = math.ceil(left)
            if secs ~= self.secs then
                self.secs = secs
                self.bar.text:SetText(string.format(L("Closing in %ds"), secs))
            end
            if left <= 0 then finishAt = nil; closeAt = now + 2; self.bar.text:SetText(L("Ready check finished")) end
        end
        if now >= (self.nextRefresh or 0) then -- once per second whatever the frame rate, keeps buffs current
            self.nextRefresh = now + 1
            W.ReadyCheckRefresh()
        end
    end)
end

local function NewRow(i)
    local r = CreateFrame("Frame", nil, frame.list)
    W.Size(r, 450, ROW_H)
    r:SetPoint("TOPLEFT", 8, -(i - 1) * ROW_H)
    if i % 2 == 0 then -- striped rows
        local z = r:CreateTexture(nil, "BACKGROUND")
        z:SetAllPoints()
        W.SetColor(z, 1, 1, 1, 0.04)
    end
    r.cells = {}
    for k, c in ipairs(COLS) do
        local fs = W.Label(r, "", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", c.x - 8, 0)
        fs:SetWidth(c[2])
        fs:SetJustifyH(c[3] or "CENTER")
        r.cells[k] = fs
    end
    return r
end

function W.ReadyCheckRefresh()
    if not frame or not frame:IsShown() then return end
    local units = W.GroupUnits()
    local count = math.min(#units, MAX_ROWS)
    local ready = 0
    for i = 1, count do
        local unit = units[i]
        local key, name = W.UnitKey(unit) or "?", W.UnitDisplayName(unit) or "?"
        local st = GetReadyCheckStatus and W.Safe(GetReadyCheckStatus(unit))
        if st ~= "ready" and st ~= "notready" then st = statuses[key] end
        if st == "ready" then ready = ready + 1 end
        local set = not FindByName and UnitBuffSet(unit) or nil
        local r = rows[i] or NewRow(i)
        rows[i] = r
        local c = r.cells
        c[1]:SetText(name)
        c[1]:SetTextColor(W.ClassColor(W.UnitClassToken(unit)))
        c[2]:SetText(ReadyText(st))
        c[3]:SetText(DurText(durability[key]))
        c[4]:SetText(OK(Check(unit, "food", set)))
        c[5]:SetText(OK(Check(unit, "flask", set)))
        c[6]:SetText(OK(Check(unit, "int", set)))
        c[7]:SetText(OK(Check(unit, "stam", set)))
        c[8]:SetText(OK(Check(unit, "motw", set)))
        r:Show()
    end
    for i = count + 1, #rows do rows[i]:Hide() end
    frame:SetHeight(46 + math.max(1, count) * ROW_H + 34)
    frame.count:SetText("|cff66ff66" .. ready .. "|r/" .. count)
    if count > 0 and ready >= count and finishAt then
        finishAt = nil
        closeAt = GetTime() + 2
        frame.bar.text:SetText(L("Everyone is ready!"))
    end
end

local function Show(starter, timeLeft, force)
    if not force and (not db.enabled or not W.InGroup()) then return end
    if force and not W.InGroup() then W.Print(L("Ready check requires being in a party or raid.")); return end
    wipe(statuses); wipe(responded)
    -- the starter is ready: its key, found through its unit (the event gives a name)
    local su = starter and W.UnitByName(W.Safe(starter) or "")
    if su then statuses[W.UnitKey(su)] = "ready" end
    duration = (tonumber(timeLeft) and tonumber(timeLeft) > 0) and tonumber(timeLeft) or 30
    BuildFrame()
    finishAt, closeAt = GetTime() + duration, nil
    frame.bar:SetMinMaxValues(0, duration)
    frame.secs, frame.nextRefresh = nil, GetTime() + 0.5
    frame:Show()
    W.ReadyCheckRefresh()
end

W.On("READY_CHECK", function(starter, timeLeft)
    SendDurability() -- always, even if our own window is disabled
    Show(starter, timeLeft)
end)
W.On("READY_CHECK_CONFIRM", function(unit, isReady)
    if not unit then return end
    local key = W.UnitKey(unit)
    if not key then return end
    statuses[key] = isReady and "ready" or "notready"
    W.ReadyCheckRefresh()
end)
W.On("READY_CHECK_FINISHED", function()
    if frame and frame:IsShown() then
        W.ReadyCheckRefresh()
        finishAt = nil
        closeAt = GetTime() + 2
        frame.bar.text:SetText(L("Ready check finished"))
    end
end)

W.slash.rc = function() SendDurability(); Show(nil, 30, true) end
-- "Test all": the window alone (no durability message sent), in a group only (it lists the group)
W.RegisterTest("Ready Check", function() return db and db.enabled and W.InGroup() end,
    function() Show(nil, 30, true) end,
    function() if frame then frame:Hide() end end)

-- /rc: starts a real ready check if you are leader/assist, otherwise opens the check window
SLASH_WLRTREADYCHECK1 = "/rc"
SlashCmdList["WLRTREADYCHECK"] = function()
    if not W.Allowed() then W.Denied(); return end
    -- C_PartyInfo on Forever; the global only exists through Blizzard's deprecation shims
    local doCheck = (C_PartyInfo and C_PartyInfo.DoReadyCheck) or DoReadyCheck
    if W.InGroup() and W.CanLead() and doCheck then
        doCheck()
    else
        W.slash.rc()
    end
end

W.RegisterModule("ReadyCheck", "Ready Check", function(p)
    W.Title(p, L("Ready Check"))
    W.Check(p, L("Show the check window on every ready check (/rc)"), function() return db.enabled end,
        function(v) db.enabled = v; if not v and frame then frame:Hide() end end):SetPoint("TOPLEFT", 12, -40)
    W.Button(p, L("Start (/rc)"), 110, 22, SlashCmdList["WLRTREADYCHECK"]):SetPoint("TOPLEFT", 16, -72)
    W.Button(p, L("Test window"), 130, 22, W.slash.rc):SetPoint("TOPLEFT", 132, -72)
    local info = W.Label(p, L("Columns: ready, durability (sent by players who have the addon), Well Fed, ")
        .. L("flask, Arcane Intellect, Fortitude, Mark of the Wild.\nThe window closes by itself when the ready check ends."),
        "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, -110)
    info:SetWidth(600)
    info:SetTextColor(0.7, 0.7, 0.7)
end)
