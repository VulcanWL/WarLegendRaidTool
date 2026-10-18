-- WarLegend RaidTool - Guild dashboard
-- One screen for the officers, laid out like a WoWAudit summary sheet: a title bar, a row of tiles with the totals and
-- four ranked lists: average item level, set pieces worn, missing enchants / gems, raids done this week.
-- Personal only: nothing is sent. Sources, all already on this computer: the guild roster, what Raid Inspect last
-- read of each player (kept here, W.DashboardGear) and the Attendance records.
local W = WLRT
W.AddFR({
    ["Dashboard"] = "Tableau de bord",
    ["Members"] = "Membres",
    ["Name"] = "Nom",
    ["Refresh"] = "Actualiser",
    ["Missing enchants / gems"] = "Enchants / gemmes manquants",
    ["Raids this week"] = "Raids cette semaine",
    ["Players tracked"] = "Joueurs suivis",
    ["Raid view"] = "Vue des raids",
    ["This week"] = "Cette semaine",
    ["Average item level"] = "Niveau d'objets moyen",
    ["Set pieces worn"] = "Pièces de set portées",
    ["Raids done this week"] = "Raids faits cette semaine",
    ["Guild summary of %s"] = "Synthèse de la guilde %s",
    ["Refreshed:"] = "Actualisé :",
    ["Pieces"] = "Pièces",
    ["Missing"] = "Manque",
    ["Raids"] = "Raids",
    ["No data yet: open Raid Inspect in a raid."] = "Pas encore de données : ouvre l'inspection en raid.",
    ["Nobody is missing an enchant or a gem."] = "Personne ne manque d'enchant ni de gemme.",
    ["No raid this week yet (Attendance)."] = "Aucun raid cette semaine (Présences).",
    ["No set piece found in the inspected gear."] = "Aucune pièce de set dans l'équipement inspecté.",
    ["Item level read %d day(s) ago"] = "Niveau d'objets lu il y a %d jour(s)",
    ["%d enchant(s) and %d gem(s) missing"] = "%d enchant(s) et %d gemme(s) manquant(s)",
    ["%d piece(s) of the set worn most: %s"] = "%d pièce(s) du set le plus porté : %s",
    ["%d raid(s) this week"] = "%d raid(s) cette semaine",
    ["Raid data is kept for the players you inspected; only guild members are listed."] =
        "Les données de raid sont gardées pour les joueurs inspectés ; seuls les membres de la guilde sont listés.",
})
local L = W.L

local db
local UI = {}
local ROWS, ROW_H = 20, 17
local GEAR_MAX, GEAR_KEEP = 600, 60 * 86400 -- players kept / seconds a reading is kept
local WEEK = 7 * 86400

W.OnReady(function()
    db = W.DB("dashboard", {})
    if type(db.gear) ~= "table" then db.gear = {} end -- key -> { name, class, ilvl, miss, slots, gems, set, setSlots, t }: data, not an option
    local now = time()
    for k, g in pairs(db.gear) do
        if type(g) ~= "table" or now - (tonumber(g.t) or 0) > GEAR_KEEP then db.gear[k] = nil end
    end
end)

-- Called by Raid Inspect when it has a complete reading of a player in the group (unit = "raid3", "player"...).
-- extra = { gems = empty sockets, set = pieces of the most worn set, setSlots = "HSC..." }
function W.DashboardGear(unit, ilvl, missing, slots, extra)
    if not db or type(ilvl) ~= "number" or ilvl <= 0 then return end
    local key, name = W.UnitKey(unit), W.UnitDisplayName(unit)
    if not key or not name then return end
    local g = db.gear[key]
    if not g then
        local n = 0
        for _ in pairs(db.gear) do n = n + 1 end
        if n >= GEAR_MAX then -- the oldest reading goes
            local oldest, at
            for k, x in pairs(db.gear) do if not at or (x.t or 0) < at then oldest, at = k, x.t or 0 end end
            if oldest then db.gear[oldest] = nil end
        end
        g = {}
        db.gear[key] = g
    end
    g.name, g.class = name, W.UnitClassToken(unit)
    g.ilvl, g.miss, g.slots, g.t = ilvl, tonumber(missing) or 0, tonumber(slots) or 0, time()
    if type(extra) == "table" then
        g.gems, g.set, g.setSlots = tonumber(extra.gems) or 0, tonumber(extra.set) or 0, type(extra.setSlots) == "string" and extra.setSlots or ""
    else
        g.gems, g.set, g.setSlots = g.gems or 0, g.set or 0, g.setSlots or "" -- no item links this time: what the last inspection found stays
    end
end

---------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------
local function IsMember(name)
    return not W.IsInGuild() or W.GuildMember(name) ~= nil
end

local function ByValueThenName(a, b)
    if a.sort ~= b.sort then return a.sort > b.sort end
    return a.name < b.name
end

-- Raids attended in the last 7 days, per player, from the Attendance records (a bench seat does not count)
local function WeeklyRaids(now)
    local at = type(W.db.attendance) == "table" and W.db.attendance.nights
    local counts, nights = {}, 0
    if type(at) ~= "table" then return counts, nights end
    for _, night in ipairs(at) do
        if type(night) == "table" and (tonumber(night.t) or 0) >= now - WEEK and type(night.players) == "table" then
            nights = nights + 1
            for rawKey, p in pairs(night.players) do
                if type(p) == "table" and not p.bench then
                    local key, shown = rawKey, p.n
                    if not W.HasFullPart(rawKey) then -- an old record keyed by a first name: joined only when it is unique in the guild
                        local m = W.GuildMember(rawKey)
                        if m and m.full then key, shown = m.full:lower(), shown or m.full end
                    end
                    local c = counts[key]
                    if not c then c = { name = shown or rawKey, n = 0 }; counts[key] = c end
                    c.n = c.n + 1
                    c.class = p.c or c.class
                end
            end
        end
    end
    return counts, nights
end

-- entries: { name (short), text (value shown), sort, tip = { lines } }
local function Collect()
    local out = { ilvl = {}, set = {}, ench = {}, week = {} }
    local totals = { members = 0, miss = 0, nights = 0, tracked = 0 }
    totals.members = #W.GuildMembers()
    local now = time()
    for _, g in pairs(db.gear) do
        if IsMember(g.name) then
            totals.tracked = totals.tracked + 1
            local days = math.floor((now - (g.t or now)) / 86400)
            local short = W.BaseName(g.name)
            out.ilvl[#out.ilvl + 1] = { name = short, text = tostring(g.ilvl), sort = g.ilvl,
                tip = { g.name, string.format(L("Item level read %d day(s) ago"), days) } }
            local gems, miss = g.gems or 0, g.miss or 0
            if miss + gems > 0 then
                totals.miss = totals.miss + miss + gems
                out.ench[#out.ench + 1] = { name = short, text = "|cffcc0000" .. (miss + gems) .. "|r", sort = miss + gems,
                    tip = { g.name, string.format(L("%d enchant(s) and %d gem(s) missing"), miss, gems) } }
            end
            if (g.set or 0) > 0 then
                out.set[#out.set + 1] = { name = short, text = tostring(g.set), sort = g.set,
                    tip = { g.name, string.format(L("%d piece(s) of the set worn most: %s"), g.set, g.setSlots or "") } }
            end
        end
    end
    local counts, nights = WeeklyRaids(now)
    totals.nights = nights
    for _, c in pairs(counts) do
        if IsMember(c.name) then
            out.week[#out.week + 1] = { name = W.BaseName(c.name), text = tostring(c.n), sort = c.n,
                tip = { c.name, string.format(L("%d raid(s) this week"), c.n) } }
        end
    end
    for _, list in pairs(out) do table.sort(list, ByValueThenName) end
    return out, totals
end

---------------------------------------------------------------------------
-- Widgets: the look of the audit summary sheet (dark title bars, light lists, colored rank cells)
---------------------------------------------------------------------------
local DARK, LIGHT = { 0.25, 0.25, 0.25 }, { 0.95, 0.95, 0.95 }
-- rank cells: 1 orange, 2-5 purple, 6-10 blue, 11-20 green (like the sheet)
local function RankColor(i)
    if i == 1 then return 1, 0.6, 0.1 end
    if i <= 5 then return 0.62, 0.36, 0.85 end
    if i <= 10 then return 0.2, 0.5, 0.85 end
    return 0.2, 0.85, 0.2
end

local function Paint(tex, c) W.SetColor(tex, c[1], c[2], c[3], 1) end

-- a dark bar with a white label
local function Bar(parent, w, h, text, font)
    local f = CreateFrame("Frame", nil, parent)
    W.Size(f, w, h)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    Paint(f.bg, DARK)
    f.text = f:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    f.text:SetPoint("CENTER")
    f.text:SetTextColor(1, 1, 1)
    f.text:SetText(text or "")
    return f
end

-- label bar over a value cell (red when it asks for attention, light gray otherwise, pale yellow for the setting)
local function Tile(p, x, w, label)
    local f = CreateFrame("Frame", nil, p)
    W.Size(f, w, 40)
    f:SetPoint("TOPLEFT", x, -46)
    f.head = Bar(f, w, 18, label)
    f.head:SetPoint("TOP")
    f.cell = CreateFrame("Frame", nil, f)
    W.Size(f.cell, w, 22)
    f.cell:SetPoint("TOP", f.head, "BOTTOM")
    f.cell.bg = f.cell:CreateTexture(nil, "BACKGROUND")
    f.cell.bg:SetAllPoints()
    Paint(f.cell.bg, LIGHT)
    f.value = f.cell:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.value:SetPoint("CENTER")
    f.value:SetTextColor(0, 0, 0)
    return f
end

local function SetTile(t, text, color)
    t.value:SetText(text)
    Paint(t.cell.bg, color or LIGHT)
end

local function Board(p, x, w, title, valueHead, emptyText)
    local f = CreateFrame("Frame", nil, p)
    W.Size(f, w, 22 + 18 + ROWS * ROW_H)
    f:SetPoint("TOPLEFT", x, -94)
    f.body = f:CreateTexture(nil, "BACKGROUND")
    f.body:SetAllPoints()
    Paint(f.body, LIGHT)
    f.head = Bar(f, w, 22, title, "GameFontNormal")
    f.head:SetPoint("TOP")
    local function Sub(text, point, x2, width, just)
        local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint(point, x2, -26)
        fs:SetWidth(width)
        fs:SetJustifyH(just)
        fs:SetTextColor(0.1, 0.1, 0.1)
        fs:SetText(text)
    end
    Sub("#", "TOPLEFT", 0, 20, "CENTER")
    Sub(L("Name"), "TOPLEFT", 26, 90, "LEFT")
    Sub(valueHead, "TOPRIGHT", -4, 50, "RIGHT")
    f.empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.empty:SetPoint("TOP", 0, -60)
    f.empty:SetWidth(w - 24)
    f.empty:SetText(emptyText)
    f.rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Button", nil, f)
        W.Size(r, w, ROW_H - 1)
        r:SetPoint("TOPLEFT", 0, -42 - (i - 1) * ROW_H)
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        W.SetColor(hl, 0, 0, 0, 0.08)
        r.cell = r:CreateTexture(nil, "BACKGROUND")
        r.cell:SetPoint("TOPLEFT")
        r.cell:SetPoint("BOTTOMLEFT")
        r.cell:SetWidth(20)
        r.rank = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.rank:SetPoint("CENTER", r.cell, "CENTER")
        r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.name:SetPoint("LEFT", 26, 0)
        r.name:SetWidth(96)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        r.name:SetTextColor(0, 0, 0)
        r.val = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        r.val:SetPoint("RIGHT", -4, 0)
        r.val:SetWidth(44)
        r.val:SetJustifyH("RIGHT")
        r.val:SetTextColor(0, 0, 0)
        r:SetScript("OnEnter", function(self)
            if not self.tip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            for k, line in ipairs(self.tip) do GameTooltip:AddLine(line, 1, 1, 1, k > 1) end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r:Hide()
        f.rows[i] = r
    end
    return f
end

local function FillBoard(board, entries)
    board.empty:SetShown(#entries == 0)
    for i = 1, ROWS do
        local r, e = board.rows[i], entries[i]
        if e then
            W.SetColor(r.cell, RankColor(i))
            r.rank:SetText(i)
            r.name:SetText(e.name)
            r.val:SetText(e.text)
            r.tip = e.tip
            r:Show()
        else
            r.tip = nil
            r:Hide()
        end
    end
end

local function Refresh()
    if not db or not UI.tiles then return end
    local out, t = Collect()
    SetTile(UI.tiles.miss, t.miss, t.miss > 0 and { 0.9, 0.42, 0.42 } or nil)
    SetTile(UI.tiles.members, t.members)
    SetTile(UI.tiles.nights, t.nights)
    SetTile(UI.tiles.tracked, t.tracked)
    SetTile(UI.tiles.view, L("This week"), { 1, 0.95, 0.8 })
    FillBoard(UI.ilvl, out.ilvl)
    FillBoard(UI.set, out.set)
    FillBoard(UI.ench, out.ench)
    FillBoard(UI.week, out.week)
    local guild = GetGuildInfo and W.Safe((GetGuildInfo("player"))) or nil
    local realm = W.Safe(GetRealmName and GetRealmName() or "")
    UI.title.text:SetText(string.format(L("Guild summary of %s"),
        (guild or "?") .. ((realm and realm ~= "") and (" (" .. realm .. ")") or "")))
    UI.stamp:SetText(L("Refreshed:") .. "\n" .. date("%d/%m %H:%M"))
end

W.RegisterModule("Dashboard", L("Dashboard"), function(p)
    local width, gap = 768, 8
    UI.title = Bar(p, width, 30, "", "GameFontHighlightLarge")
    UI.title:SetPoint("TOPLEFT", 12, -8)
    UI.stamp = UI.title:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    UI.stamp:SetPoint("LEFT", 8, 0)
    UI.stamp:SetJustifyH("LEFT")
    local refresh = W.Button(p, L("Refresh"), 80, 20, function() W.RequestGuildRoster(); Refresh() end)
    refresh:SetPoint("RIGHT", UI.title, "RIGHT", -6, 0)
    refresh:SetFrameLevel(UI.title:GetFrameLevel() + 2)

    local tw = math.floor((width - 4 * gap) / 5)
    UI.tiles = {}
    for i, def in ipairs({ { "miss", L("Missing enchants / gems") }, { "members", L("Members") }, { "nights", L("Raids this week") },
        { "tracked", L("Players tracked") }, { "view", L("Raid view") } }) do
        UI.tiles[def[1]] = Tile(p, 12 + (i - 1) * (tw + gap), tw, def[2])
    end

    local bw = math.floor((width - 3 * gap) / 4)
    UI.ilvl = Board(p, 12, bw, L("Average item level"), "iLvL", L("No data yet: open Raid Inspect in a raid."))
    UI.set = Board(p, 12 + (bw + gap), bw, L("Set pieces worn"), L("Pieces"), L("No set piece found in the inspected gear."))
    UI.ench = Board(p, 12 + 2 * (bw + gap), bw, L("Missing enchants / gems"), L("Missing"), L("Nobody is missing an enchant or a gem."))
    UI.week = Board(p, 12 + 3 * (bw + gap), bw, L("Raids done this week"), L("Raids"), L("No raid this week yet (Attendance)."))
    local note = W.Label(p, L("Raid data is kept for the players you inspected; only guild members are listed."), "GameFontDisableSmall")
    note:SetPoint("BOTTOMLEFT", 14, 6)
    p:SetScript("OnShow", function() W.RequestGuildRoster(); Refresh() end)
end, function() Refresh() end)

W.On("GUILD_ROSTER_UPDATE", function()
    if W.IsShown("Dashboard") then Refresh() end
end)

W.slash.dashboard = function() W.Toggle("Dashboard") end
