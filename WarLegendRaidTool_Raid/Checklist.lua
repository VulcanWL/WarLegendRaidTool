-- WarLegend RaidTool - Consumables checklist (L3FTools style)
-- Your list of consumables with the quantity you want: bags vs target, reminder at every ready check.
-- The raid leader can share a list and ask everyone with the addon how many they have.
local W = WLRT
W.AddFR({
    ["Checklist"] = "Checklist",
    ["Consumables"] = "Consommables",
    ["Item (ID, name or shift-click):"] = "Objet (ID, nom ou shift-clic) :",
    ["Qty:"] = "Qté :",
    ["Add"] = "Ajouter",
    ["Have"] = "En sac",
    ["Want"] = "Voulu",
    ["Load defaults for my class"] = "Charger les défauts de ma classe",
    ["Remind me at every ready check"] = "Me prévenir à chaque appel",
    ["Share my list with the raid"] = "Partager ma liste au raid",
    ["Raid check"] = "Vérif. du raid",
    ["Unknown item."] = "Objet inconnu.",
    ["Missing consumables: "] = "Consommables manquants : ",
    ["All your consumables are there."] = "Tous tes consommables sont là.",
    ["%s shares a consumables list (%d items). Replace your list?"] = "%s partage une liste de consommables (%d objets). Remplacer ta liste ?",
    ["Replace"] = "Remplacer",
    ["List shared."] = "Liste partagée.",
    ["Asking the raid..."] = "Demande au raid...",
    ["Right-click an item to remove it."] = "Clic droit sur un objet pour le retirer.",
    ["My list"] = "Ma liste",
})
local L = W.L

local CL = {}
W.Checklist = CL
local PREFIX = "WLRT_CON"
local lastAnswer = 0
local db

W.OnReady(function()
    db = W.DB("checklist", { remind = true })
    if type(db.items) ~= "table" then db.items = {} end -- { {id, want}, ... }
    if type(db.raid) ~= "table" then db.raid = {} end    -- answers to the raid check
end)

local CASTER = { { 13444, 5 }, { 13446, 5 }, { 13454, 5 }, { 20007, 5 }, { 13457, 3 }, { 5634, 2 } }
local MELEE = { { 13446, 5 }, { 13452, 5 }, { 9206, 5 }, { 12451, 5 }, { 13457, 3 }, { 5634, 2 } }
local HEALER = { { 13444, 8 }, { 13446, 3 }, { 20007, 5 }, { 13511, 1 }, { 13457, 3 }, { 5634, 2 } }
local DEFAULTS = {
    MAGE = CASTER, WARLOCK = CASTER, PRIEST = HEALER, DRUID = HEALER, SHAMAN = HEALER, PALADIN = HEALER,
    WARRIOR = MELEE, ROGUE = MELEE, HUNTER = MELEE,
}

function CL.Missing()
    local out = {}
    for _, e in ipairs(db.items) do
        local have = W.ItemCount(e[1])
        if have < e[2] then out[#out + 1] = { id = e[1], have = have, want = e[2] } end
    end
    return out
end

W.On("READY_CHECK", function()
    if not db or not db.remind or #db.items == 0 then return end
    local miss = CL.Missing()
    if #miss == 0 then return end
    local t = {}
    for _, m in ipairs(miss) do t[#t + 1] = W.ItemLink("item:" .. m.id) .. " " .. m.have .. "/" .. m.want end
    W.Print("|cffffaa00" .. L("Missing consumables: ") .. "|r" .. table.concat(t, ", "))
end)

local function Encode(items)
    local t = {}
    for _, e in ipairs(items) do t[#t + 1] = e[1] .. ":" .. e[2] end
    return table.concat(t, ",")
end
local MAX_ITEMS = 100 -- a shared list: at most this many items, ids and quantities within sane bounds
local function Decode(s)
    local out = {}
    for id, n in (s or ""):gmatch("(%d+):(%d+)") do
        if #out >= MAX_ITEMS then break end
        id, n = W.Int(id, 1, 999999), W.Int(n, 0, 9999)
        if id and n then out[#out + 1] = { id, n } end
    end
    return out
end

-- L = list shared, Q = how many do you have, A = answer
W.OnAddonLong(PREFIX, function(msg, from, channel, full)
    local t = W.Unpack(msg)
    local unit, class = W.UnitByName(full or from)
    local isMe = unit and W.UnitIsMe(unit)
    if t[1] == "L" and not isMe and W.IsGroupLead(full or from, channel) then
        local items = Decode(t[2])
        local who = unit and W.UnitDisplayName(unit) or from
        W.Confirm(string.format(L("%s shares a consumables list (%d items). Replace your list?"), who, #items), function()
            db.items = items
            CL.Refresh()
        end, L("Replace"))
    elseif t[1] == "Q" and W.IsGroupLead(full or from, channel) then
        if GetTime() - lastAnswer < 10 then return end -- one answer per 10 s whoever asks
        lastAnswer = GetTime()
        local items = Decode(t[2])
        local ans = {}
        for _, e in ipairs(items) do ans[#ans + 1] = e[1] .. ":" .. W.ItemCount(e[1]) end
        W.SendLong(PREFIX, W.Pack("A", table.concat(ans, ",")))
    elseif t[1] == "A" and unit then
        -- answers keyed by full identity: two "Arthur" in the raid stay two rows
        local r = { name = W.UnitDisplayName(unit) or from, class = class, counts = {} }
        local nCounts = 0
        for id, n in (t[2] or ""):gmatch("(%d+):(%d+)") do
            id, n = W.Int(id, 1, 999999), W.Int(n, 0, 99999999)
            if id and n and nCounts < MAX_ITEMS then r.counts[id] = n; nCounts = nCounts + 1 end
        end
        db.raid[W.UnitKey(unit) or from] = r
        CL.RefreshRaid()
    end
end)

-- Panel
local UI = {}

function CL.Refresh()
    if not UI.mine or not UI.mine:IsVisible() then return end
    local rows = {}
    for i, e in ipairs(db.items) do
        local have = W.ItemCount(e[1])
        local col = have >= e[2] and "|cff33ff66" or (have > 0 and "|cffffcc33" or "|cffff5555")
        rows[#rows + 1] = { index = i, id = e[1], cells = { W.ItemLink("item:" .. e[1]), col .. have .. "|r", e[2] } }
    end
    UI.mine:SetData(rows)
end

function CL.RefreshRaid()
    if not UI.raid or not UI.raid:IsVisible() then return end
    local rows = {}
    local keys = {}
    for k in pairs(db.raid) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return (db.raid[a].name or a) < (db.raid[b].name or b) end)
    for _, k in ipairs(keys) do
        local r = db.raid[k]
        local n = r.name or k
        local parts, ok = {}, true
        for _, e in ipairs(db.items) do
            local have = r.counts[e[1]] or 0
            if have < e[2] then
                ok = false
                parts[#parts + 1] = "|cffff5555" .. (W.GetItemInfo(e[1]) or ("#" .. e[1])) .. " " .. have .. "/" .. e[2] .. "|r"
            end
        end
        rows[#rows + 1] = { cells = { W.ColorName(n, r.class), ok and "|cff33ff66OK|r" or table.concat(parts, ", ") } }
    end
    UI.raid:SetData(rows)
end

-- bags / item data: only listened while the tab is open
local bagEv = W.On("BAG_UPDATE_DELAYED", function() CL.Refresh() end, nil, true)
local itemEv = W.On("GET_ITEM_INFO_RECEIVED", function() CL.Refresh() end, nil, true)
local function Watch(on) W.Activate(bagEv, on); W.Activate(itemEv, on) end

W.RegisterModule("Checklist", L("Checklist"), function(p)
    W.Title(p, L("Consumables"))
    local lbl = W.Label(p, L("Item (ID, name or shift-click):"), "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT", 14, -40)
    local box = W.EditBox(p, 200, 255)
    box:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
    W.LinkTarget(box)
    local ql = W.Label(p, L("Qty:"), "GameFontHighlightSmall")
    ql:SetPoint("LEFT", box, "RIGHT", 10, 0)
    local qty = W.EditBox(p, 40, 4)
    qty:SetPoint("LEFT", ql, "RIGHT", 6, 0)
    qty:SetNumeric(true)
    qty:SetText("5")
    local function add()
        local id = W.ParseItem(box:GetText())
        if not id then W.Print(L("Unknown item.")); return end
        local n = tonumber(qty:GetText()) or 1
        for _, e in ipairs(db.items) do if e[1] == id then e[2] = n; id = nil; break end end
        if id then table.insert(db.items, { id, n }) end
        box:SetText("")
        CL.Refresh()
    end
    box:SetScript("OnEnterPressed", add)
    W.Button(p, L("Add"), 80, 22, add):SetPoint("LEFT", qty, "RIGHT", 8, 0)
    W.Button(p, L("Load defaults for my class"), 200, 22, function()
        db.items = {}
        for _, e in ipairs(DEFAULTS[W.UnitClassToken("player") or ""] or CASTER) do table.insert(db.items, { e[1], e[2] }) end
        CL.Refresh()
    end):SetPoint("TOPLEFT", 14, -66)
    W.Check(p, L("Remind me at every ready check"), function() return db.remind end, function(v) db.remind = v end)
        :SetPoint("TOPLEFT", 222, -65)
    local t1 = W.Label(p, L("My list"), "GameFontNormal")
    t1:SetPoint("TOPLEFT", 14, -98)
    UI.mine = W.Table(p, { { L("Item"), 230 }, { L("Have"), 50, "CENTER" }, { L("Want"), 50, "CENTER" } }, 380)
    UI.mine:SetPoint("TOPLEFT", 10, -116)
    UI.mine.onEnter = function(d, row) GameTooltip:SetOwner(row, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink("item:" .. d.id); GameTooltip:Show() end
    UI.mine.onClick = function(d, btn) if btn == "RightButton" then table.remove(db.items, d.index); CL.Refresh() end end
    local hint = W.Label(p, L("Right-click an item to remove it."), "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 14, -500)
    local t2 = W.Label(p, L("Raid check"), "GameFontNormal")
    t2:SetPoint("TOPLEFT", 380, -98)
    W.Button(p, L("Share my list with the raid"), 190, 22, function()
        W.SendLong(PREFIX, W.Pack("L", Encode(db.items)))
        W.Print(L("List shared."))
    end):SetPoint("TOPLEFT", 460, -66)
    W.Button(p, L("Raid check"), 130, 22, function()
        wipe(db.raid)
        W.SendLong(PREFIX, W.Pack("Q", Encode(db.items)))
        W.Print(L("Asking the raid..."))
        CL.RefreshRaid()
    end):SetPoint("TOPLEFT", 656, -66)
    UI.raid = W.Table(p, { { L("Name"), 110 }, { L("Missing consumables: "), 320 } }, 380)
    UI.raid:SetPoint("TOPLEFT", 376, -116)
    p:SetScript("OnShow", function() Watch(true); CL.Refresh(); CL.RefreshRaid() end)
    p:SetScript("OnHide", function() Watch(false) end)
end, function() CL.Refresh(); CL.RefreshRaid() end)

