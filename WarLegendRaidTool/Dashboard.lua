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
local ROWS, ROW_H = 15, 19
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
            for key, p in pairs(night.players) do
                if type(p) == "table" and not p.bench then
                    local c = counts[key]
                    if not c then c = { name = p.n or key, n = 0 }; counts[key] = c end
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
    for key, g in pairs(db.gear) do
        if IsMember(key) then -- the full identity: two members can share a short name
            totals.tracked = totals.tracked + 1
            local days = math.floor((now - (g.t or now)) / 86400)
            local short = W.FOREVER and g.name or W.BaseName(g.name) -- Forever: "First Surname", two "Jean" stay apart
            out.ilvl[#out.ilvl + 1] = { name = short, class = g.class, text = tostring(g.ilvl), sort = g.ilvl,
                tip = { g.name, string.format(L("Item level read %d day(s) ago"), days) } }
            local gems, miss = g.gems or 0, g.miss or 0
            if miss + gems > 0 then
                totals.miss = totals.miss + miss + gems
                out.ench[#out.ench + 1] = { name = short, class = g.class, text = "|cffff5555" .. (miss + gems) .. "|r", sort = miss + gems,
                    tip = { g.name, string.format(L("%d enchant(s) and %d gem(s) missing"), miss, gems) } }
            end
            if (g.set or 0) > 0 then
                out.set[#out.set + 1] = { name = short, class = g.class, text = tostring(g.set), sort = g.set,
                    tip = { g.name, string.format(L("%d piece(s) of the set worn most: %s"), g.set, g.setSlots or "") } }
            end
        end
    end
    local counts, nights = WeeklyRaids(now)
    totals.nights = nights
    for _, c in pairs(counts) do
        if IsMember(c.name) then
            out.week[#out.week + 1] = { name = W.FOREVER and c.name or W.BaseName(c.name), class = c.class, text = tostring(c.n), sort = c.n,
                tip = { c.name, string.format(L("%d raid(s) this week"), c.n) } }
        end
    end
    for _, list in pairs(out) do table.sort(list, ByValueThenName) end
    return out, totals
end

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------
local RANK_COLORS = { { 1, 0.5, 0 }, { 0.64, 0.21, 0.93 }, { 0, 0.44, 0.87 } } -- like the sheet: orange, purple, blue, then green
local function RankColor(i)
    local c = RANK_COLORS[i]
    if c then return c[1], c[2], c[3] end
    if i <= 10 then return 0.12, 0.62, 0.12 end
    return 0.35, 0.35, 0.35
end

local function Tile(p, x, label)
    local f = W.Panel(p, 144, 46)
    f:SetPoint("TOPLEFT", x, -64)
    f.label = W.Label(f, label, "GameFontNormalSmall")
    f.label:SetPoint("TOP", 0, -6)
    f.value = W.Label(f, "-", "GameFontHighlightLarge")
    f.value:SetPoint("BOTTOM", 0, 7)
    return f
end

local function Board(p, x, title, emptyText)
    local f = W.Panel(p, 184, 30 + ROWS * ROW_H + 4)
    f:SetPoint("TOPLEFT", x, -120)
    f.title = W.Label(f, title, "GameFontNormal")
    f.title:SetPoint("TOP", 0, -8)
    f.empty = W.Label(f, emptyText, "GameFontDisableSmall")
    f.empty:SetPoint("TOP", 0, -40)
    f.empty:SetWidth(160)
    f.rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Button", nil, f)
        W.Size(r, 176, ROW_H - 1)
        r:SetPoint("TOPLEFT", 4, -28 - (i - 1) * ROW_H)
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        W.SetColor(hl, 1, 1, 1, 0.08)
        r.bar = r:CreateTexture(nil, "BACKGROUND")
        r.bar:SetPoint("TOPLEFT")
        r.bar:SetPoint("BOTTOMLEFT")
        r.bar:SetWidth(18)
        r.rank = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.rank:SetPoint("CENTER", r.bar, "CENTER")
        r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.name:SetPoint("LEFT", 24, 0)
        r.name:SetWidth(102)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        r.val = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.val:SetPoint("RIGHT", -4, 0)
        r.val:SetWidth(44)
        r.val:SetJustifyH("RIGHT")
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

local function Fill(board, entries)
    board.empty:SetShown(#entries == 0)
    for i = 1, ROWS do
        local r, e = board.rows[i], entries[i]
        if e then
            r.bar:SetColorTexture(RankColor(i))
            r.rank:SetText(i)
            r.name:SetText(W.ColorName(e.name, e.class))
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
    UI.tiles.miss.value:SetText(t.miss > 0 and ("|cffff5555" .. t.miss .. "|r") or "0")
    UI.tiles.members.value:SetText(t.members)
    UI.tiles.nights.value:SetText(t.nights)
    UI.tiles.tracked.value:SetText(t.tracked)
    Fill(UI.ilvl, out.ilvl)
    Fill(UI.set, out.set)
    Fill(UI.ench, out.ench)
    Fill(UI.week, out.week)
end

W.RegisterModule("Dashboard", "Dashboard", function(p)
    W.Title(p, L("Dashboard"))
    W.Button(p, L("Refresh"), 90, 22, function() W.RequestGuildRoster(); Refresh() end):SetPoint("TOPLEFT", 200, -14)
    local note = W.Label(p, L("Raid data is kept for the players you inspected; only guild members are listed."), "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", 14, -42)

    UI.tiles = {
        miss = Tile(p, 14, L("Missing enchants / gems")),
        members = Tile(p, 164, L("Members")),
        nights = Tile(p, 314, L("Raids this week")),
        tracked = Tile(p, 464, L("Players tracked")),
    }
    UI.ilvl = Board(p, 14, L("Average item level"), L("No data yet: open Raid Inspect in a raid."))
    UI.set = Board(p, 204, L("Set pieces worn"), L("No set piece found in the inspected gear."))
    UI.ench = Board(p, 394, L("Missing enchants / gems"), L("Nobody is missing an enchant or a gem."))
    UI.week = Board(p, 584, L("Raids done this week"), L("No raid this week yet (Attendance)."))
    p:SetScript("OnShow", function() W.RequestGuildRoster(); Refresh() end)
end) -- the OnShow above draws the tab at each showing (a refresh function too drew it twice)

W.On("GUILD_ROSTER_UPDATE", function()
    if W.IsShown("Dashboard") then Refresh() end
end)

W.slash.dashboard = function() W.Toggle("Dashboard") end
