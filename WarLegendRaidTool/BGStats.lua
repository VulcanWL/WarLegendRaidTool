-- WarLegend RaidTool - Battleground history (guild premades) and records
-- A battleground where at least N guild members play in my team is a premade: at the end its result,
-- duration and the guild members present are kept (my games only, nothing is sent).
-- Records: fastest wins per battleground.
-- Cost: nothing outside battlegrounds; in one, a check per second during the preparation phase only.
local W = WLRT
W.AddFR({
    ["BG history"] = "Historique BG",
    ["Games"] = "Parties",
    ["Players"] = "Joueurs",
    ["Records"] = "Records",
    ["Date"] = "Date",
    ["Battleground"] = "Champ de bataille",
    ["Result"] = "Résultat",
    ["Duration"] = "Durée",
    ["Guild"] = "Guilde",
    ["Victory"] = "Victoire",
    ["Defeat"] = "Défaite",
    ["Name"] = "Nom",
    ["Wins"] = "Victoires",
    ["Last"] = "Dernière",
    ["Win time"] = "Temps",
    ["Premade = at least"] = "Premade = au moins",
    ["%d guild members"] = "%d membres de la guilde",
    ["Last %d days"] = "%d derniers jours",
    ["All time"] = "Depuis toujours",
    ["No record yet for this battleground."] = "Pas encore de record pour ce champ de bataille.",
    ["Your guild premades. Left-click a game for the players, right-click to delete it."] =
        "Tes premades de guilde. Clic gauche sur une partie pour les joueurs, clic droit pour la supprimer.",
    ["Your fastest premade wins. The time starts when the gates open."] =
        "Tes victoires en premade les plus rapides. Le temps part de l'ouverture des portes.",
    ["Delete this game?"] = "Supprimer cette partie ?",
    ["Premade recorded: %s, %s (%s)."] = "Premade enregistré : %s, %s (%s).",
    ["No battleground recorded yet."] = "Aucun champ de bataille enregistré pour l'instant.",
})
local L = W.L

local BG = {}
W.BGStats = BG
local db
local MAX_GAMES = 500
local PREP = 120 -- preparation phase (gates closed) when it could not be seen

W.OnReady(function()
    db = W.DB("bgStats", { minGuild = 5, range = 30, recordMap = 0 })
    if type(db.games) ~= "table" then db.games = {} end -- newest first: { m = mapID, n = name, e = end, d = secs, w = 1/0, f = faction, p = "A;B;..." }
    if type(db.names) ~= "table" then db.names = {} end -- [mapID] = name in my language
end)

local function InBattleground()
    local _, kind = IsInInstance()
    return kind == "pvp"
end

local function Clock(secs)
    secs = math.floor(secs or 0)
    if secs <= 0 then return "-" end
    return string.format("%d:%02d", math.floor(secs / 60), secs % 60)
end

---------------------------------------------------------------------------
-- Storing
---------------------------------------------------------------------------
local function SplitNames(p)
    local out = {}
    for n in (p or ""):gmatch("[^;]+") do out[#out + 1] = n end
    return out
end

local function Store(g)
    table.insert(db.games, 1, g)
    while #db.games > MAX_GAMES do table.remove(db.games) end
    return g
end

---------------------------------------------------------------------------
-- The game being played
---------------------------------------------------------------------------
local cur -- { m, n, startT, prepSeen, players = { [key] = name }, done }

local function PrepAura()
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local ok, a = pcall(C_UnitAuras.GetPlayerAuraBySpellID, 44521) -- Preparation (gates closed)
        if ok then return a ~= nil and a ~= false end
    end
    return nil -- unknown on this client
end

local function SeeGuild()
    if not cur then return end
    local count = 0
    for _, u in ipairs(W.GroupUnits()) do
        local name = W.UnitFullName(u)
        local g = name and W.GuildMember(name)
        if g then cur.players[g.full:lower()] = g.full end
    end
    for _ in pairs(cur.players) do count = count + 1 end
    return count
end

-- once a second while the gates are closed: the time starts when the preparation aura goes away
local function WatchPrep()
    if not cur or cur.startT or not InBattleground() then return end
    local prep = PrepAura()
    if prep then
        cur.prepSeen = true
        W.After(1, WatchPrep)
    elseif prep == false and cur.prepSeen then
        cur.startT = time()
    end
end

local function Finish(winner)
    if not cur or cur.done then return end
    cur.done = true
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    local won = (winner == 0 and faction == "Horde") or (winner == 1 and faction == "Alliance")
    local now, dur = time(), 0
    if cur.startT then
        dur = now - cur.startT
    elseif GetBattlefieldInstanceRunTime then
        local ms = W.Safe(GetBattlefieldInstanceRunTime())
        if type(ms) == "number" and ms > 0 then dur = math.max(0, math.floor(ms / 1000) - PREP) end
    end
    local count = SeeGuild() or 0
    if count < (db.minGuild or 5) then return end
    local names = {}
    for _, n in pairs(cur.players) do names[#names + 1] = n end
    table.sort(names)
    local g = Store({ m = cur.m, n = cur.n, e = now, d = dur, w = won and 1 or 0, f = faction, p = table.concat(names, ";") })
    W.Print(string.format(L("Premade recorded: %s, %s (%s)."), g.n or "?", won and L("Victory") or L("Defeat"), Clock(g.d)))
    BG.Refresh()
end

local endEv1, endEv2, rosterOn
local function CheckEnd()
    if not cur or cur.done or not GetBattlefieldWinner then return end
    local w = W.Safe(GetBattlefieldWinner())
    if w ~= nil then Finish(w) end
end
endEv1 = W.On("UPDATE_BATTLEFIELD_SCORE", CheckEnd, nil, true)
endEv2 = W.On("UPDATE_BATTLEFIELD_STATUS", CheckEnd, nil, true)
W.OnRoster(function() if rosterOn and cur and not cur.done then SeeGuild() end end)

local function Zone()
    local inBG = db and InBattleground()
    W.Activate(endEv1, inBG and true or false)
    W.Activate(endEv2, inBG and true or false)
    rosterOn = inBG
    if not inBG then cur = nil; return end
    local name, _, _, _, _, _, _, id = GetInstanceInfo()
    id, name = W.Safe(id), W.Safe(name)
    if not id then return end
    if cur and cur.m == id then return end -- same game (zone change inside it)
    if name then db.names[id] = name end
    cur = { m = id, n = name, players = {} }
    SeeGuild()
    WatchPrep()
end
W.On("PLAYER_ENTERING_WORLD", Zone)
W.On("ZONE_CHANGED_NEW_AREA", Zone)

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
local UI = {}

local function MapName(g) return db.names[g.m] or (g.n ~= "" and g.n) or ("#" .. tostring(g.m)) end

-- the battleground's Mark of Honor icon (item icon read from the client, else the file)
local MARK_ITEM = { [489] = 20558, [2106] = 20558, [529] = 20559, [2107] = 20559, [30] = 20560 } -- Warsong, Arathi, Alterac
local DARKSPEAR_MARK, DARKSPEAR_ICON = 274895, "Interface\\Icons\\INV_Misc_Rune_14" -- Darkspear Islands Mark of Honor (wowhead.com/forever)
local function MapIcon(g)
    local item = MARK_ITEM[g.m]
    if not item then
        local name = (MapName(g) or ""):lower()
        if name:find("darkspear", 1, true) or name:find("sombrelance", 1, true) then item = DARKSPEAR_MARK end
    end
    if not item then return nil end
    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(item)
    if not icon and GetItemIcon then icon = GetItemIcon(item) end
    return icon or (item == DARKSPEAR_MARK and DARKSPEAR_ICON) or nil
end

-- "|Ticon|t Name" for the tables
local function MapLabel(g)
    local icon = MapIcon(g)
    return (icon and ("|T" .. icon .. ":16:16:0:0:64:64:5:59:5:59|t ") or "") .. MapName(g)
end

local function InRange(g)
    return (db.range or 0) == 0 or (g.e or 0) >= time() - db.range * 86400
end

local function ColorFull(name)
    local gm = W.GuildMember(name)
    return W.ColorName(name, gm and gm.class)
end

local function ResultText(g)
    return g.w == 1 and ("|cff33ff66" .. L("Victory") .. "|r") or ("|cffff5555" .. L("Defeat") .. "|r")
end

local function RefreshGames()
    if not UI.games or not UI.games:IsVisible() then return end
    local rows = {}
    for i, g in ipairs(db.games) do
        if InRange(g) then
            rows[#rows + 1] = { index = i, cells = { date("%d/%m %H:%M", g.e or 0), MapLabel(g), ResultText(g), Clock(g.d), #SplitNames(g.p) } }
        end
    end
    UI.games:SetData(rows)
end

local function RefreshPlayers()
    if not UI.players or not UI.players:IsVisible() then return end
    local stats = {}
    for _, g in ipairs(db.games) do
        if InRange(g) then
            local counted = {}
            for _, n in ipairs(SplitNames(g.p)) do
                local key, shown = W.Key(n), n
                if not counted[key] then
                    counted[key] = true
                    local s = stats[key]
                    if not s then s = { name = shown, games = 0, wins = 0, last = 0 }; stats[key] = s end
                    s.games = s.games + 1
                    if g.w == 1 then s.wins = s.wins + 1 end
                    if (g.e or 0) > s.last then s.last = g.e end
                end
            end
        end
    end
    local list = {}
    for _, s in pairs(stats) do list[#list + 1] = s end
    table.sort(list, function(a, b)
        if a.games ~= b.games then return a.games > b.games end
        return a.name < b.name
    end)
    local rows = {}
    for _, s in ipairs(list) do
        local pct = math.floor(s.wins / s.games * 100 + 0.5)
        rows[#rows + 1] = { cells = { ColorFull(s.name), s.games, s.wins,
            (pct >= 60 and "|cff33ff66" or (pct >= 40 and "|cffffcc33" or "|cffff5555")) .. pct .. "%|r", date("%d/%m", s.last) } }
    end
    UI.players:SetData(rows)
end

local mapValues = {}
local function RefreshRecords()
    if not UI.records or not UI.records:IsVisible() then return end
    local list = {}
    for _, g in ipairs(db.games) do
        if g.m == db.recordMap and g.w == 1 and (g.d or 0) > 0 then list[#list + 1] = g end
    end
    table.sort(list, function(a, b) return a.d < b.d end)
    local rows = {}
    for i = 1, math.min(10, #list) do
        local g = list[i]
        local names = {}
        for _, n in ipairs(SplitNames(g.p)) do names[#names + 1] = ColorFull(n) end
        rows[#rows + 1] = { cells = { i == 1 and "|cffffd100#1|r" or ("#" .. i), Clock(g.d), date("%d/%m/%Y", g.e or 0), table.concat(names, ", ") } }
    end
    UI.records:SetData(rows)
    UI.noRecord:SetShown(#rows == 0)
end

function BG.Refresh()
    if not W.IsShown("BGStats") then return end
    RefreshGames()
    RefreshPlayers()
    RefreshRecords()
end

local function RangeCycle(p)
    return W.Cycle(p, 130, { { 7, string.format(L("Last %d days"), 7) }, { 30, string.format(L("Last %d days"), 30) },
        { 90, string.format(L("Last %d days"), 90) }, { 0, L("All time") } },
        function() return db.range end, function(v) db.range = v; BG.Refresh() end)
end

local function BuildGames(p)
    RangeCycle(p):SetPoint("TOPLEFT", 12, -6)
    local lbl = W.Label(p, L("Premade = at least"), "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT", 160, -12)
    local mins = {}
    for _, n in ipairs({ 3, 5, 8, 10 }) do mins[#mins + 1] = { n, string.format(L("%d guild members"), n) } end
    W.Cycle(p, 170, mins, function() return db.minGuild end, function(v) db.minGuild = v end):SetPoint("LEFT", lbl, "RIGHT", 8, 0)
    UI.games = W.Table(p, { { L("Date"), 110 }, { L("Battleground"), 220 }, { L("Result"), 110, "CENTER" },
        { L("Duration"), 90, "CENTER" }, { L("Guild"), 70, "CENTER" } }, 420)
    UI.games:SetPoint("TOPLEFT", 10, -40)
    UI.games:SetEmptyText(L("No battleground recorded yet."))
    UI.games.onClick = function(d, btn)
        local g = db.games[d.index]
        if not g then return end
        if btn == "RightButton" then
            -- by the game, not its index: a game stored while the question is open moves the list
            W.Confirm(L("Delete this game?"), function()
                for i, x in ipairs(db.games) do
                    if x == g then table.remove(db.games, i); break end
                end
                BG.Refresh()
            end)
        else
            W.TextPopup(MapName(g), date("%d/%m/%Y %H:%M", g.e or 0) .. "  " .. ResultText(g) .. "  " .. Clock(g.d) .. "\n\n"
                .. table.concat(SplitNames(g.p), "\n"), { hint = "Ctrl+C" })
        end
    end
    local hint = W.Label(p, L("Your guild premades. Left-click a game for the players, right-click to delete it."),
        "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", 14, 8)
    p:SetScript("OnShow", RefreshGames)
end

local function BuildPlayers(p)
    RangeCycle(p):SetPoint("TOPLEFT", 12, -6)
    UI.players = W.Table(p, { { L("Name"), 220 }, { L("Games"), 80, "CENTER" }, { L("Wins"), 80, "CENTER" },
        { "%", 60, "CENTER" }, { L("Last"), 80, "CENTER" } }, 420)
    UI.players:SetPoint("TOPLEFT", 10, -40)
    p:SetScript("OnShow", RefreshPlayers)
end

local function BuildRecords(p)
    local cycle = W.Cycle(p, 220, mapValues, function() return db.recordMap end, function(v) db.recordMap = v; RefreshRecords() end)
    cycle:SetPoint("TOPLEFT", 12, -6)
    UI.records = W.Table(p, { { "", 40, "CENTER" }, { L("Win time"), 80, "CENTER" }, { L("Date"), 100, "CENTER" }, { L("Players"), 580 } }, 300)
    UI.records:SetPoint("TOPLEFT", 10, -40)
    UI.noRecord = W.Label(p, L("No record yet for this battleground."), "GameFontDisable")
    UI.noRecord:SetPoint("TOPLEFT", 16, -70)
    local hint = W.Label(p, L("Your fastest premade wins. The time starts when the gates open."), "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", 14, 8)
    p:SetScript("OnShow", function()
        wipe(mapValues)
        local seen = {}
        for _, g in ipairs(db.games) do
            if not seen[g.m] then seen[g.m] = true; mapValues[#mapValues + 1] = { g.m, MapLabel(g) } end
        end
        table.sort(mapValues, function(a, b) return (db.names[a[1]] or a[2]) < (db.names[b[1]] or b[2]) end)
        if not seen[db.recordMap] and mapValues[1] then db.recordMap = mapValues[1][1] end
        cycle.Sync()
        RefreshRecords()
    end)
end

W.RegisterModule("BGStats", L("BG history"), function(p)
    W.Title(p, L("BG history"))
    UI.tabs = W.SubTabs(p, { L("Games"), L("Players"), L("Records") })
    BuildGames(UI.tabs.frames[1])
    BuildPlayers(UI.tabs.frames[2])
    BuildRecords(UI.tabs.frames[3])
    UI.tabs:Select(1)
end, function()
    if UI.tabs then UI.tabs:Select(UI.tabs.current or 1) end
end)

W.slash.bg = function() W.Toggle("BGStats") end
