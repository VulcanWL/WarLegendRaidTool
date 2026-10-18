-- WarLegend RaidTool - Raid Inspect
-- Modeled on Naowh Forever's Group Inspect: while the tab is open, everyone in the group is
-- inspected one at a time (2 s apart, never in combat, only in range, yielding to your own inspect).
-- Out of range is tried again later, item data that loads late is read again, results go stale
-- after 5 minutes. Players running WarLegend send their own data, so they are not inspected.
local W = WLRT
local L = W.L

local REQ_PREFIX, DATA_PREFIX = "WLRT_INSQ", "WLRT_INSD"
local GAP, WAIT_FOR, RETRY, STALE, SETTLE = 2, 4, 5, 300, 0.3
local INSPECT_DISTANCE = 1
-- Same enchantable slots as Naowh Forever (no head/shoulders/legs: those are not real enchants in vanilla)
local ENCHANT_SLOTS = { 5, 8, 9, 10, 15, 16, 17 }
local ILVL_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
local SLOT_NAMES = { [1] = "Head", [2] = "Neck", [3] = "Shoulders", [5] = "Chest", [6] = "Waist", [7] = "Legs",
    [8] = "Feet", [9] = "Wrists", [10] = "Hands", [15] = "Back", [16] = "Main hand", [17] = "Off hand", [18] = "Ranged" }

local records = {}   -- by GUID
local members = {}   -- ordered list of records in the group
local open = false
local pending, pendingUnit, pendingAt = nil, nil, 0
local lastAsked, lastRequest = 0, 0
local loading = false
local dirty = false -- something changed: the list is redrawn on the next tick
local UI = {}

local function Now() return GetTime() end

local function UserInspecting()
    return InspectFrame and InspectFrame:IsShown()
end

---------------------------------------------------------------------------
-- Reading gear
---------------------------------------------------------------------------
local function EquipLoc(link)
    if not W.GetItemInfoInstant then return nil end
    local _, _, _, loc = W.GetItemInfoInstant(link)
    return loc
end

-- Fills ilvl / enchants from rec.links; returns true while some item data is still loading
local function Evaluate(rec)
    local links = rec.links
    local sum, wait = 0, false
    for _, slot in ipairs(ILVL_SLOTS) do
        local link = links[slot]
        if link then
            local lvl = W.ItemLevel(link)
            if lvl then sum = sum + lvl else wait = true end
        end
    end
    local main = links[16]
    if main and not links[17] and EquipLoc(main) == "INVTYPE_2HWEAPON" then
        sum = sum + (W.ItemLevel(main) or 0) -- 2-hander counts twice, like the game
    end
    if not rec.apiIlvl then rec.ilvl = math.floor(sum / #ILVL_SLOTS + 0.5) end
    rec.missing, rec.enchanted, rec.enchantable = {}, 0, 0
    local nf = _G.NaowhForever
    local naowhEnchants = nf and nf.BiS and nf.BiS.Enchants
    for _, slot in ipairs(ENCHANT_SLOTS) do
        local link = links[slot]
        if link then
            local can, current
            if naowhEnchants and naowhEnchants.Enchantable then
                -- Naowh Forever knows which items can really take an enchant on Forever
                local ok, c, cur = pcall(naowhEnchants.Enchantable, link)
                if ok then can, current = c, cur end
            end
            if can == nil then
                local loc = EquipLoc(link)
                can = not (slot == 17 and (loc == "INVTYPE_HOLDABLE" or loc == nil))
                current = tonumber(link:match("item:%d+:(%d*)") or "") or 0
            end
            if can or (current and current > 0) then
                rec.enchantable = rec.enchantable + 1
                if current and current > 0 then
                    rec.enchanted = rec.enchanted + 1
                else
                    rec.missing[#rec.missing + 1] = slot
                end
            end
        end
    end
    rec.loading = wait
    return wait
end

-- the guild dashboard keeps the last complete reading of each player (Guild > Dashboard)
local SLOT_LETTER = { [1] = "H", [3] = "S", [5] = "C", [6] = "W", [7] = "L", [8] = "F", [9] = "B", [10] = "G" } -- head shoulders chest waist legs feet bracers gloves
local GetStats = (C_Item and C_Item.GetItemStats) or GetItemStats

-- the set worn the most (item set ID = 16th value of GetItemInfo): its piece count and the slots; empty gem sockets
local function Extras(rec)
    local bySet, gems = {}, 0
    for slot, link in pairs(rec.links) do
        local setID = select(16, W.GetItemInfo(link))
        if type(setID) == "number" and setID > 0 then
            bySet[setID] = bySet[setID] or { n = 0, slots = {} }
            bySet[setID].n = bySet[setID].n + 1
            if SLOT_LETTER[slot] then bySet[setID].slots[#bySet[setID].slots + 1] = SLOT_LETTER[slot] end
        end
        if GetStats then
            local ok, stats = pcall(GetStats, link)
            if ok and type(stats) == "table" then
                for k, v in pairs(stats) do
                    if type(k) == "string" and k:find("^EMPTY_SOCKET_") and type(v) == "number" then gems = gems + v end
                end
            end
        end
    end
    local best
    for _, x in pairs(bySet) do if not best or x.n > best.n then best = x end end
    table.sort(best and best.slots or {})
    return { gems = gems, set = best and best.n or 0, setSlots = best and table.concat(best.slots, " ") or "" }
end

local function Keep(rec, unit)
    if not (W.DashboardGear and unit and rec.ilvl and not rec.loading and rec.links) then return end
    if W.Safe(UnitGUID(unit)) ~= rec.guid then return end
    -- a self-report has no item links: the set and gems read at the last inspection stay
    W.DashboardGear(unit, rec.ilvl, #(rec.missing or {}), rec.enchantable, next(rec.links) and Extras(rec) or nil)
end

local function ReadUnit(rec, unit)
    rec.links = {}
    for _, slot in ipairs(ILVL_SLOTS) do
        local ok, link = pcall(GetInventoryItemLink, unit, slot)
        link = ok and W.Safe(link) or nil
        if link then rec.links[slot] = link end
    end
    rec.apiIlvl = nil
    if unit == "player" then
        if GetAverageItemLevel then
            local _, equipped = GetAverageItemLevel()
            equipped = W.Safe(equipped)
            if equipped and equipped > 0 then rec.ilvl, rec.apiIlvl = math.floor(equipped + 0.5), true end
        end
        rec.talents = W.OwnTalents()
    else
        local api = C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel
        local lvl = api and W.Safe(api(unit))
        if lvl and lvl > 0 then rec.ilvl, rec.apiIlvl = math.floor(lvl + 0.5), true end
        rec.talents = W.InspectTalents() or rec.talents
    end
    if Evaluate(rec) then loading = true end
    rec.read, rec.far, rec.state = Now(), false, unit == "player" and "self" or "ready"
    Keep(rec, unit)
    dirty = true
end

---------------------------------------------------------------------------
-- Roster
---------------------------------------------------------------------------
local function AddUnit(unit)
    local guid = W.Safe(UnitGUID(unit))
    if not guid then return end
    local rec = records[guid]
    if not rec then
        rec = { guid = guid, links = {}, missing = {} }
        records[guid] = rec
    end
    rec.unit = unit
    rec.name = W.UnitDisplayName(unit) or "?"
    rec.class = W.UnitClassToken(unit)
    local lvl = W.Safe(UnitLevel(unit))
    rec.level = (lvl and lvl > 0) and lvl or rec.level
    local online = UnitIsConnected(unit)
    rec.online = W.Safe(online) ~= false
    members[#members + 1] = rec
end

local function Fresh(rec, now)
    return rec.read and now - rec.read < STALE
end

local inGroup = {}
local function Rebuild()
    wipe(members)
    AddUnit("player")
    if W.InRaid() then
        for i = 1, W.NumRaid() do
            local u = W.RAID_UNITS[i]
            if UnitExists(u) and not W.UnitIsMe(u) then AddUnit(u) end
        end
    else
        for i = 1, 4 do
            local u = W.PARTY_UNITS[i]
            if UnitExists(u) then AddUnit(u) end
        end
    end
    local me = records[W.Safe(UnitGUID("player")) or ""]
    if me then ReadUnit(me, "player") end
    -- forget players who left the group once their data is stale (no endless growth over pugs / raids)
    wipe(inGroup)
    for _, rec in ipairs(members) do inGroup[rec.guid] = true end
    local now = Now()
    for guid, rec in pairs(records) do
        if not inGroup[guid] and not Fresh(rec, now) then records[guid] = nil end
    end
    dirty = true
end

---------------------------------------------------------------------------
-- Self-reports from other WarLegend users (no inspect needed)
-- guid|ilvl|enchanted|enchantable|missing csv|talents a/b/c|main tree
---------------------------------------------------------------------------
local function SelfReport()
    local me = { guid = W.Safe(UnitGUID("player")), links = {} }
    if not me.guid then return end
    ReadUnit(me, "player")
    local tree = me.talents and me.talents.best or ""
    W.Send(DATA_PREFIX, table.concat({ me.guid, me.ilvl or 0, me.enchanted or 0, me.enchantable or 0,
        table.concat(me.missing or {}, ","), W.TalentText(me.talents) or "", (tree:gsub("|", "")) }, "|"))
end

local function RequestReports()
    if Now() - lastRequest < 10 then return end
    lastRequest = Now()
    W.Send(REQ_PREFIX, "1")
end

local lastReport = -1000
W.OnAddon(REQ_PREFIX, function(_, from, _, full)
    if GetTime() - lastReport < 10 then return end -- a flood of requests gets one report
    if not W.IsMe(full or from) then lastReport = GetTime(); W.After(math.random() * 2, SelfReport) end
end)

W.OnAddon(DATA_PREFIX, function(msg, from, _, full)
    local unit = W.UnitByName(full or from)
    if not unit or W.UnitIsMe(unit) then return end
    local guid, ilvl, ench, total, miss, tal, tree = msg:match("^([^|]+)|(%d+)|(%d+)|(%d+)|([^|]*)|([^|]*)|(.*)$")
    local rec = guid and records[guid]
    -- only trust the player about themselves: the data must be about the sender's own character
    if not rec or W.Safe(UnitGUID(unit)) ~= guid then return end
    rec.ilvl, rec.apiIlvl = tonumber(ilvl), true
    rec.enchanted, rec.enchantable, rec.missing = tonumber(ench), tonumber(total), {}
    for id in miss:gmatch("%d+") do rec.missing[#rec.missing + 1] = tonumber(id) end
    if tal ~= "" then
        local spent = {}
        for n in tal:gmatch("%d+") do spent[#spent + 1] = tonumber(n) end
        rec.talents = { spent = spent, best = tree ~= "" and W.Plain(tree, 40) or nil }
    end
    rec.read, rec.far, rec.state, rec.hasAddon, rec.loading = Now(), false, "ready", true, false
    Keep(rec, unit)
    if pending == guid then pending = nil end
    if UI.Refresh then UI.Refresh() end
end)

---------------------------------------------------------------------------
-- The inspect walk (one request at a time)
---------------------------------------------------------------------------
local function Step()
    local now = Now()
    if pending then
        if now - pendingAt < WAIT_FOR then return end
        local rec = records[pending]
        if rec then rec.state = "timeout"; rec.far = true; rec.farAt = now; dirty = true end
        pending = nil
    end
    if InCombatLockdown() or UserInspecting() or now - lastAsked < GAP then return end
    for _, rec in ipairs(members) do
        if rec.unit ~= "player" and rec.online and not Fresh(rec, now)
            and not (rec.far and now - (rec.farAt or 0) < RETRY) then
            local unit = rec.unit
            if W.Safe(UnitGUID(unit)) ~= rec.guid then return Rebuild() end
            if CanInspect(unit) and CheckInteractDistance(unit, INSPECT_DISTANCE) then
                pending, pendingUnit, pendingAt, lastAsked = rec.guid, unit, now, now
                rec.state = "inspecting"
                dirty = true
                NotifyInspect(unit)
                return
            end
            if rec.state ~= "far" then dirty = true end
            rec.far, rec.farAt, rec.state = true, now, "far"
        end
    end
end

local ticker = CreateFrame("Frame")
ticker:Hide()
local acc, uiAcc, loadAt = 0, 0, nil
ticker:SetScript("OnUpdate", function(_, e)
    acc = acc + e
    if acc < 0.2 then return end
    uiAcc = uiAcc + acc
    acc = 0
    if loadAt and Now() >= loadAt then
        loadAt = nil
        local still = false
        for _, rec in ipairs(members) do
            if rec.loading and rec.links then
                if Evaluate(rec) then still = true else Keep(rec, rec.unit) end
            end
        end
        loading = still
        dirty = true
    end
    Step()
    -- redraw only when something changed (at most 5/s), else once per second for the combat status
    if UI.Refresh and (dirty or uiAcc >= 1) then
        dirty, uiAcc = false, 0
        UI.Refresh()
    end
end)

local events = {} -- only listened while the tab is open
events[#events + 1] = W.On("INSPECT_READY", function(guid)
    if not open or not guid or guid ~= pending then return end
    local rec, unit = records[guid], pendingUnit
    pending = nil
    if rec and unit and W.Safe(UnitGUID(unit)) == guid then ReadUnit(rec, unit) end
    if not UserInspecting() and ClearInspectPlayer then ClearInspectPlayer() end
end, nil, true)

events[#events + 1] = W.On("GET_ITEM_INFO_RECEIVED", function()
    if open and loading then loadAt = Now() + SETTLE end
end, nil, true)

local function OnRoster()
    if not open then return end
    Rebuild()
    RequestReports()
end
W.OnRoster(OnRoster)
events[#events + 1] = W.On("UNIT_CONNECTION", OnRoster, nil, true)
events[#events + 1] = W.On("UNIT_INVENTORY_CHANGED", function(unit)
    if not open or not unit then return end
    local guid = W.Safe(UnitGUID(unit))
    local rec = guid and records[guid]
    if rec and unit ~= "player" and not rec.hasAddon then rec.read = nil end
end, nil, true)

local function Open()
    if open then return end
    open = true
    for _, ev in ipairs(events) do W.Activate(ev, true) end
    Rebuild()
    RequestReports()
    ticker:Show()
end

local function Close()
    open = false
    pending = nil
    ticker:Hide()
    for _, ev in ipairs(events) do W.Activate(ev, false) end
end

local function RefreshAll()
    for _, rec in pairs(records) do
        if not rec.hasAddon then rec.read, rec.far = nil, nil end
    end
    lastRequest = 0
    Rebuild()
    RequestReports()
end

---------------------------------------------------------------------------
-- Interface
---------------------------------------------------------------------------
local STATE_TEXT = {}
W.OnReady(function() -- built once the language is known
    STATE_TEXT.inspecting = "|cffffcc33" .. L("Inspecting...") .. "|r"
    STATE_TEXT.far = "|cffff7744" .. L("Out of range") .. "|r"
    STATE_TEXT.timeout = "|cffff7744" .. L("No reply") .. "|r"
    STATE_TEXT.offline = "|cff777777" .. L("Offline") .. "|r"
    STATE_TEXT.queued = "|cff999999" .. L("Queued") .. "|r"
end)

local COLS = { { "Name", 4, 150, "LEFT" }, { "Lvl", 156, 30 }, { "Ilvl", 188, 40 }, { "Talents", 230, 130, "LEFT" },
    { "Enchants", 362, 70 }, { "State", 434, 90 } }

function UI.Refresh()
    if not UI.list or not UI.root:IsVisible() then return end
    local done, total = 0, 0
    for i, rec in ipairs(members) do
        total = total + 1
        local r = UI.list:Row(i)
        r.rec = rec
        r.name:SetText(rec.name .. (rec.hasAddon and " |cffce1918WL|r" or ""))
        r.name:SetTextColor(W.ClassColor(rec.class))
        r.lvl:SetText(rec.level or "")
        local known = rec.read ~= nil
        if known then done = done + 1 end
        r.ilvl:SetText(known and rec.ilvl and rec.ilvl > 0 and (rec.ilvl .. (rec.loading and "*" or "")) or "-")
        local tal = W.TalentText(rec.talents)
        r.tal:SetText(tal and (tal .. (rec.talents.best and ("  |cff999999" .. rec.talents.best .. "|r") or "")) or "-")
        if known and rec.enchantable and rec.enchantable > 0 then
            local full = rec.enchanted >= rec.enchantable
            r.ench:SetText((full and "|cff33ff66" or "|cffff4444") .. rec.enchanted .. "/" .. rec.enchantable .. "|r")
        else
            r.ench:SetText(known and "|cff33ff66-|r" or "-")
        end
        local st = rec.state
        if not rec.online then st = "offline"
        elseif rec.unit == "player" or (st == "ready") then st = nil
        elseif not known and st ~= "inspecting" and st ~= "far" and st ~= "timeout" then st = "queued" end
        r.state:SetText(st and STATE_TEXT[st] or "")
        r.again:SetShown(rec.unit ~= "player" and not rec.hasAddon)
    end
    UI.list:Finish(#members)
    if total <= 1 and not W.InGroup() then
        UI.status:SetText(L("Raid Inspect requires being in a party or raid."))
    else
        UI.status:SetText(string.format(L("Inspected: %d/%d"), done, total)
            .. (InCombatLockdown() and ("  |cffff7744" .. L("(paused in combat)") .. "|r") or ""))
    end
end

local function Build(p)
    UI.root = p
    W.Title(p, L("Raid Inspect"))
    W.Button(p, L("Refresh all"), 130, 24, RefreshAll,
        { L("Inspects everyone again. The scan runs by itself while this tab is open.") }):SetPoint("TOPLEFT", 14, -40)
    UI.status = W.Label(p, "", "GameFontHighlightSmall")
    UI.status:SetPoint("LEFT", p, "TOPLEFT", 156, -52)
    for _, c in ipairs(COLS) do
        local h = W.Label(p, L(c[1]), "GameFontNormalSmall")
        h:SetPoint("TOPLEFT", 18 + c[2], -76)
        h:SetWidth(c[3])
        h:SetJustifyH(c[4] or "CENTER")
        h:SetTextColor(0.85, 0.85, 0.85)
    end
    local panel = W.Panel(p, 580, 470)
    panel:SetPoint("TOPLEFT", 12, -92)
    UI.list = W.ScrollList(panel, 540, 454, 18, function(content)
        local r = CreateFrame("Frame", nil, content)
        r:EnableMouse(true)
        local function col(k)
            local c = COLS[k]
            local fs = W.Label(r, "", "GameFontHighlightSmall")
            fs:SetPoint("LEFT", c[2], 0)
            fs:SetWidth(c[3])
            fs:SetJustifyH(c[4] or "CENTER")
            fs:SetWordWrap(false)
            return fs
        end
        r.name, r.lvl, r.ilvl, r.tal, r.ench, r.state = col(1), col(2), col(3), col(4), col(5), col(6)
        r.again = W.Button(r, "R", 18, 16, function(self)
            local rec = self:GetParent().rec
            if rec then rec.read, rec.far = nil, nil; dirty = true end
        end, { L("Inspect this player again") })
        r.again:SetPoint("RIGHT", -2, 0)
        r:SetScript("OnEnter", function(self)
            local rec = self.rec
            if not rec then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(rec.name, W.ClassColor(rec.class))
            if rec.hasAddon then GameTooltip:AddLine(L("Data sent by their WarLegend RaidTool"), 0.8, 0.8, 0.8) end
            if rec.missing and #rec.missing > 0 then
                GameTooltip:AddLine(L("Missing enchant on:"), 1, 0.4, 0.4)
                for _, s in ipairs(rec.missing) do GameTooltip:AddLine("- " .. L(SLOT_NAMES[s] or ("#" .. s)), 1, 1, 1) end
            end
            if rec.talents and rec.talents.names then
                for i, n in ipairs(rec.talents.names) do GameTooltip:AddDoubleLine(n, rec.talents.spent[i], 0.8, 0.8, 0.8, 1, 1, 1) end
            end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return r
    end)
    UI.list.sf:SetPoint("TOPLEFT", 6, -8)
    local info = W.Label(p, L("* = items not loaded by the game yet (they are read again automatically).") .. "\n\n"
        .. L("Players must be within inspect range (~10 yd). Out of range players are tried again every few seconds.") .. "\n\n"
        .. L("|cffce1918WL|r = has WarLegend RaidTool: sends its own data, no inspect needed."), "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 604, -96)
    info:SetWidth(200)
    info:SetTextColor(0.7, 0.7, 0.7)
    p:HookScript("OnShow", Open)
    p:HookScript("OnHide", Close)
end

W.RegisterModule("RaidInspect", "Raid Inspect", Build, function() Open(); UI.Refresh() end)
