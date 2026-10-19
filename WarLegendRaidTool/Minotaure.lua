-- WarLegend RaidTool - Minotaure
-- Guild PvP season ranking, from Sashoof's WarLegend v3 addon (same rules): seasons of 28 days (UTC, the first one starts
-- Monday 12 October 2026), 5 points per honorable kill and 30 per battleground win, at most 200 points a day, score =
-- 50 x world / (world + 200) + 50 x BG / (BG + 200) (out of 100: one kind of PvP alone cannot fill it), weekly challenges.
-- Only what this client sees counts: the honorable kill counter (GetPVPSessionStats) and the winner of a battleground I saw
-- running. Guild members' totals come from their addon (GUILD, prefix WLRT_MINO): shown as declared, never checked.
local W = WLRT
W.AddFR({
    ["Minotaure"] = "Minotaure",
    ["Ranking"] = "Classement",
    ["My season"] = "Ma saison",
    ["Challenges"] = "Défis",
    ["Seasons"] = "Saisons",
    ["Season %s - %s, week %d / 4, ends in %d day(s)"] = "Saison du %s au %s, semaine %d / 4, fin dans %d jour(s)",
    ["Player"] = "Joueur",
    ["Score"] = "Score",
    ["World"] = "Monde",
    ["BG"] = "BG",
    ["Wins"] = "Victoires",
    ["Played"] = "Joués",
    ["Source"] = "Source",
    ["me"] = "moi",
    ["declared"] = "déclaré",
    ["Count my PvP for the Minotaure"] = "Compter mon JcJ pour le Minotaure",
    ["Share my totals with the guild"] = "Partager mes totaux avec la guilde",
    ["Messages in the chat (challenges, end of season)"] = "Messages dans le chat (défis, fin de saison)",
    ["Points: %d (world %d, battlegrounds %d), score %.1f / 100"] = "Points : %d (monde %d, champs de bataille %d), score %.1f / 100",
    ["Honorable kills: %d in the world, %d in battlegrounds"] = "Victoires honorables : %d dans le monde, %d en champ de bataille",
    ["Battlegrounds: %d won, %d lost, %d played"] = "Champs de bataille : %d gagnés, %d perdus, %d joués",
    ["Wins by declared role: Tank %d, Heal %d, DPS %d"] = "Victoires par rôle déclaré : Tank %d, Heal %d, DPS %d",
    ["Today: %d / %d points"] = "Aujourd'hui : %d / %d points",
    ["My declared role: %s (Guild > Classes)"] = "Mon rôle déclaré : %s (Guilde > Classes)",
    ["none"] = "aucun",
    ["Honorable kills cannot be read on this client: only the battleground results count."] =
        "Les victoires honorables ne sont pas lisibles sur ce client : seuls les résultats de champ de bataille comptent.",
    ["Rules: 5 points per honorable kill (open world or battleground), 30 per battleground win, nothing for a loss, at most 200 points a day. Score = 50 x world / (world + 200) + 50 x BG / (BG + 200). A battleground counts when you saw it running (not after a reload on the score screen). Seasons of 28 days, the same for everybody (UTC)."] =
        "Règles : 5 points par victoire honorable (monde ou champ de bataille), 30 par victoire en champ de bataille, rien pour une défaite, 200 points par jour au plus. Score = 50 x monde / (monde + 200) + 50 x BG / (BG + 200). Un champ de bataille compte si tu l'as vu en cours (pas après un rechargement sur l'écran des scores). Saisons de 28 jours, les mêmes pour tous (UTC).",
    ["The guild members' figures are sent by their addon: they are shown as declared, nothing can check them."] =
        "Les chiffres des membres de la guilde sont envoyés par leur addon : ils sont affichés comme déclarés, rien ne peut les vérifier.",
    ["Rules and idea: Sashoof's WarLegend v3 addon."] = "Règles et idée : addon WarLegend v3 de Sashoof.",
    ["Week %d"] = "Semaine %d",
    ["Open front"] = "Front ouvert",
    ["%d honorable kills in the open world"] = "%d victoires honorables en monde ouvert",
    ["Team victory"] = "Victoire collective",
    ["%d battleground wins"] = "%d victoires en champ de bataille",
    ["At the front"] = "Présence au front",
    ["%d battlegrounds played to the end"] = "%d champs de bataille joués jusqu'au bout",
    ["Hold the line"] = "Tenir la ligne",
    ["Guardian angel"] = "Ange gardien",
    ["Breakthrough"] = "Percée",
    ["%d battleground wins as %s"] = "%d victoires en champ de bataille en %s",
    ["declare a role in Guild > Classes"] = "déclare un rôle dans Guilde > Classes",
    ["done"] = "fait",
    ["Minotaure: challenge done, %s."] = "Minotaure : défi accompli, %s.",
    ["Minotaure: the season of %s - %s is over, your score: %.1f (%d points)."] =
        "Minotaure : la saison du %s au %s est terminée, ton score : %.1f (%d points).",
    ["Season"] = "Saison",
    ["Points"] = "Points",
    ["Wins / played"] = "Victoires / joués",
    ["Your seasons (this character). The ranking of the guild is kept for the season in progress only."] =
        "Tes saisons (ce personnage). Le classement de la guilde n'est gardé que pour la saison en cours.",
})
local L = W.L
local db

local PREFIX = "WLRT_MINO"
local DAY, WEEK, LENGTH, ANCHOR = 86400, 604800, 2419200, 1791763200 -- Monday 12 October 2026 00:00 UTC
local HONOR, VICTORY, DAILY_CAP = 5, 30, 200
local GOALS = { world = 20, wins = 3, matches = 5, role = 2 }
local MAX_SEASONS = 13 -- one year per character
local ROLE_TITLE = { Tank = "Hold the line", Heal = "Guardian angel", DPS = "Breakthrough" }
local UI = {}

local function Now() return GetServerTime() end
local function MyKey() return W.Key(W.UnitFullName("player")) end

local function SeasonStart(t)
    return ANCHOR + math.floor((t - ANCHOR) / LENGTH) * LENGTH
end

local function NewSeason()
    return { world = 0, bg = 0, hkW = 0, hkB = 0, wins = 0, losses = 0, matches = 0,
        roles = { Tank = 0, Heal = 0, DPS = 0 }, days = {}, weeks = {}, done = {} }
end

local function Score(world, bg)
    return 50 * world / (world + DAILY_CAP) + 50 * bg / (bg + DAILY_CAP)
end

local function Date(t) return date("!%d/%m", t) end

-- this character's data and the season in progress
local function Char()
    local key = MyKey()
    local c = db.chars[key]
    if type(c) ~= "table" then c = { seasons = {} }; db.chars[key] = c end
    if type(c.seasons) ~= "table" then c.seasons = {} end
    return c
end

local function Season()
    local start = SeasonStart(Now())
    local c = Char()
    local s = c.seasons[start]
    if type(s) ~= "table" then
        s = NewSeason()
        c.seasons[start] = s
        local keys = {}
        for k in pairs(c.seasons) do keys[#keys + 1] = k end
        table.sort(keys)
        for i = 1, #keys - MAX_SEASONS do c.seasons[keys[i]] = nil end
    end
    return s, start
end

local function WeekOf(start, t) return math.max(1, math.min(4, math.floor((t - start) / WEEK) + 1)) end

local function Week(s, w)
    local x = s.weeks[w]
    if type(x) ~= "table" then x = { hkW = 0, wins = 0, matches = 0, roles = { Tank = 0, Heal = 0, DPS = 0 } }; s.weeks[w] = x end
    return x
end

-- the challenges of one week: { key, title, text, current, goal }
local function Challenges(s, w)
    local x = s.weeks[w] or { hkW = 0, wins = 0, matches = 0, roles = {} }
    local list = {
        { key = "world", title = L("Open front"), text = string.format(L("%d honorable kills in the open world"), GOALS.world), current = x.hkW, goal = GOALS.world },
        { key = "wins", title = L("Team victory"), text = string.format(L("%d battleground wins"), GOALS.wins), current = x.wins, goal = GOALS.wins },
        { key = "matches", title = L("At the front"), text = string.format(L("%d battlegrounds played to the end"), GOALS.matches), current = x.matches, goal = GOALS.matches },
    }
    local role = W.MyRole and W.MyRole()
    if role then
        list[#list + 1] = { key = "role" .. role, title = L(ROLE_TITLE[role]), text = string.format(L("%d battleground wins as %s"), GOALS.role, role),
            current = (x.roles and x.roles[role]) or 0, goal = GOALS.role }
    else
        list[#list + 1] = { key = "role", title = L("Hold the line") .. " / " .. L("Guardian angel") .. " / " .. L("Breakthrough"),
            text = L("declare a role in Guild > Classes"), current = 0, goal = GOALS.role }
    end
    return list
end

---------------------------------------------------------------------------
-- Sharing (GUILD): "1^season^world^bg^wins^played^role^role wins", "?" asks the others for theirs
---------------------------------------------------------------------------
local lastShare, waiting, lastAsk = -1000, false, -1000
local afterPvP = false -- totals to send once out of the battleground (addon messages can be locked there)
local function Share()
    if not db.on or not db.share or not W.IsInGuild() then return end
    if W.InPvP() then afterPvP = true; return end
    local now = GetTime()
    if now - lastShare < 60 then
        if not waiting then
            waiting = true
            W.After(60 - (now - lastShare) + 0.1, function() waiting = false; Share() end)
        end
        return
    end
    local s, start = Season()
    if s.world + s.bg + s.matches == 0 then return end
    lastShare = now
    local role = W.MyRole and W.MyRole() or ""
    W.Send(PREFIX, W.Pack(1, start, s.world, s.bg, s.wins, s.matches, role, role ~= "" and s.roles[role] or 0), "GUILD")
end

local function Ask()
    if not db.share or not W.IsInGuild() or GetTime() - lastAsk < 60 then return end
    lastAsk = GetTime()
    W.Send(PREFIX, "?", "GUILD")
end

local Refresh
local function Int(v, max)
    v = tonumber(v)
    if not v or v < 0 or v > max or v % 1 ~= 0 then return nil end
    return v
end

W.OnAddon(PREFIX, function(msg, name, channel, full)
    if channel ~= "GUILD" or not db or not db.on or #msg > 200 then return end
    if full == W.UnitFullName("player") then return end
    if msg == "?" then Share(); return end
    local f = W.Unpack(msg)
    if f[1] ~= "1" then return end
    local start = Int(f[2], 4102444800)
    if start ~= SeasonStart(Now()) then return end -- another season (or a wrong clock)
    local world, bg = Int(f[3], DAILY_CAP * 28), Int(f[4], DAILY_CAP * 28)
    local wins, played, roleWins = Int(f[5], 5000), Int(f[6], 5000), Int(f[8], 5000)
    if not world or not bg or not wins or not played or not roleWins or wins > played or world + bg > DAILY_CAP * 28 then return end
    local role = (f[7] == "Tank" or f[7] == "Heal" or f[7] == "DPS") and f[7] or ""
    db.peers[W.Key(full)] = { n = W.Plain(name, 40), f = W.Plain(full, 60), s = start, w = world, b = bg, v = wins, m = played,
        r = role, rw = roleWins, t = Now() }
    if UI.panel and UI.panel:IsShown() then Refresh() end
end)

---------------------------------------------------------------------------
-- Points
---------------------------------------------------------------------------
local function Notify(text)
    if db.notify then W.Print(text) end
end

-- kind: "hk", "win", "loss"; mode: "world", "bg"
local function Award(kind, mode, count, role)
    local s, start = Season()
    local now = Now()
    local day = math.floor(now / DAY)
    local used = s.days[day] or 0
    local rate = (kind == "hk" and HONOR) or (kind == "win" and VICTORY) or 0
    local pts = math.min(rate * count, math.max(0, DAILY_CAP - used))
    s.days[day] = used + pts
    for d in pairs(s.days) do if d < day - 30 then s.days[d] = nil end end
    if mode == "world" then s.world = s.world + pts else s.bg = s.bg + pts end
    local w = WeekOf(start, now)
    local x = Week(s, w)
    if kind == "hk" then
        if mode == "world" then s.hkW = s.hkW + count; x.hkW = x.hkW + count else s.hkB = s.hkB + count end
    else
        s.matches, x.matches = s.matches + 1, x.matches + 1
        if kind == "win" then
            s.wins, x.wins = s.wins + 1, x.wins + 1
            if role and s.roles[role] then
                s.roles[role] = s.roles[role] + 1
                x.roles[role] = (x.roles[role] or 0) + 1
            end
        else
            s.losses = s.losses + 1
        end
    end
    for _, c in ipairs(Challenges(s, w)) do
        local key = w .. ":" .. c.key
        if c.current >= c.goal and c.key ~= "role" and not s.done[key] then
            s.done[key] = now
            Notify(string.format(L("Minotaure: challenge done, %s."), c.title))
        end
    end
    Share()
    if UI.panel and UI.panel:IsShown() then Refresh() end
end

local function Mode()
    local inside, kind = IsInInstance()
    if kind == "pvp" then return "bg" end
    if not inside then return "world" end
    return nil -- arena, dungeon, raid: no points
end

-- honorable kills: the session counter of the client, counted by its increase
local lastHK
local function ReadHK()
    if not GetPVPSessionStats then return nil end
    local hk = W.Safe((GetPVPSessionStats()))
    return type(hk) == "number" and hk or nil
end
local hkEv = W.On("PLAYER_PVP_KILLS_CHANGED", function()
    local hk = ReadHK()
    if not hk then return end
    local prev = lastHK
    lastHK = hk
    if not prev or hk <= prev or hk - prev > 50 then return end -- first reading, new day, or an odd jump
    local mode = Mode()
    if mode then Award("hk", mode, hk - prev) end
end, nil, true)

-- battlegrounds: counted when seen running, then the winner known
local match -- { seen = saw it running, done }
local function Winner()
    if GetBattlefieldWinner then return W.Safe(GetBattlefieldWinner()) end
    local E = Enum and Enum.PvPMatchState
    if C_PvP and C_PvP.GetActiveMatchState and C_PvP.GetActiveMatchWinner and E and E.Complete then
        if W.Safe(C_PvP.GetActiveMatchState()) == E.Complete then return W.Safe(C_PvP.GetActiveMatchWinner()) end
    end
    return nil
end

local function CheckEnd()
    if not match or match.done then return end
    local w = Winner()
    if w == nil then match.seen = true; return end
    match.done = true
    if not match.seen then return end -- over before I saw it (reload on the score screen)
    local faction = UnitFactionGroup and W.Safe((UnitFactionGroup("player")))
    if (faction ~= "Horde" and faction ~= "Alliance") or (w ~= 0 and w ~= 1) then return end
    local won = (w == 0 and faction == "Horde") or (w == 1 and faction == "Alliance")
    Award(won and "win" or "loss", "bg", 1, W.MyRole and W.MyRole())
end
local endEv1 = W.On("UPDATE_BATTLEFIELD_SCORE", CheckEnd, nil, true)
local endEv2 = W.On("UPDATE_BATTLEFIELD_STATUS", CheckEnd, nil, true)
local endEv3 = W.On("PVP_MATCH_COMPLETE", CheckEnd, nil, true)

local function Zone()
    if not db then return end
    local _, kind = IsInInstance()
    local inBG = db.on and kind == "pvp"
    W.Activate(endEv1, inBG)
    W.Activate(endEv2, inBG)
    W.Activate(endEv3, inBG)
    W.Activate(hkEv, db.on)
    lastHK = ReadHK()
    if not inBG then
        match = nil
        if afterPvP and not W.InPvP() then afterPvP = false; W.After(5, Share) end
        return
    end
    if not match then
        match = {}
        CheckEnd()
    end
end
W.On("PLAYER_ENTERING_WORLD", Zone)
W.On("ZONE_CHANGED_NEW_AREA", Zone)

-- once per login: the end of the last season, and my totals for the guild
W.On("PLAYER_LOGIN", function()
    if not db or not db.on then return end
    local c, start = Char(), SeasonStart(Now())
    local last
    for k, s in pairs(c.seasons) do
        if k < start and type(s) == "table" and (s.world + s.bg) > 0 and (not last or k > last) then last = k end
    end
    if last and (c.told or 0) < last then
        c.told = last
        local s = c.seasons[last]
        Notify(string.format(L("Minotaure: the season of %s - %s is over, your score: %.1f (%d points)."),
            Date(last), Date(last + LENGTH - DAY), Score(s.world, s.bg), s.world + s.bg))
    end
    W.After(40 + math.random() * 30, Share)
end)

W.OnReady(function()
    db = W.DB("minotaure", { on = true, share = true, notify = true })
    if type(db.chars) ~= "table" then db.chars = {} end
    if type(db.peers) ~= "table" then db.peers = {} end
    local start = SeasonStart(Now())
    for k, p in pairs(db.peers) do
        if type(p) ~= "table" or p.s ~= start then db.peers[k] = nil end
    end
end)

---------------------------------------------------------------------------
-- Window tab
---------------------------------------------------------------------------
local function Grey(s) return "|cff888888" .. s .. "|r" end

function Refresh()
    if not UI.panel then return end
    local s, start = Season()
    local now = Now()
    local week = WeekOf(start, now)
    UI.season:SetText(string.format(L("Season %s - %s, week %d / 4, ends in %d day(s)"), Date(start), Date(start + LENGTH - DAY),
        week, math.max(0, math.ceil((start + LENGTH - now) / DAY))))
    local tab = UI.tabs.current or 1
    if tab == 1 then
        local list = {}
        if s.world + s.bg + s.matches > 0 then
            list[#list + 1] = { name = UnitName("player"), class = select(2, UnitClass("player")), w = s.world, b = s.bg, v = s.wins, m = s.matches, me = true }
        end
        for _, p in pairs(db.peers) do
            if p.s == start then
                local g = W.GuildMember(p.f)
                list[#list + 1] = { name = p.n, full = p.f, class = g and g.class, w = p.w, b = p.b, v = p.v, m = p.m }
            end
        end
        for _, e in ipairs(list) do e.score = Score(e.w, e.b) end
        table.sort(list, function(a, b)
            if a.score ~= b.score then return a.score > b.score end
            return a.name < b.name
        end)
        local rows = {}
        for i, e in ipairs(list) do
            local name = W.ColorName(e.name, e.class)
            if e.me then name = "|cffffd100>|r " .. name end
            rows[i] = { cells = { tostring(i), name, string.format("%.1f", e.score), tostring(e.w), tostring(e.b), tostring(e.v), tostring(e.m),
                e.me and L("me") or Grey(L("declared")) } }
        end
        UI.ranking:SetData(rows)
    elseif tab == 2 then
        local day = math.floor(now / DAY)
        local role = W.MyRole and W.MyRole()
        UI.mine:SetText(table.concat({
            string.format(L("Points: %d (world %d, battlegrounds %d), score %.1f / 100"), s.world + s.bg, s.world, s.bg, Score(s.world, s.bg)),
            string.format(L("Today: %d / %d points"), s.days[day] or 0, DAILY_CAP),
            string.format(L("Honorable kills: %d in the world, %d in battlegrounds"), s.hkW, s.hkB),
            string.format(L("Battlegrounds: %d won, %d lost, %d played"), s.wins, s.losses, s.matches),
            string.format(L("Wins by declared role: Tank %d, Heal %d, DPS %d"), s.roles.Tank, s.roles.Heal, s.roles.DPS),
            string.format(L("My declared role: %s (Guild > Classes)"), role or L("none")),
            ReadHK() == nil and ("|cffff8800" .. L("Honorable kills cannot be read on this client: only the battleground results count.") .. "|r") or "",
        }, "\n"))
    elseif tab == 3 then
        local lines = {}
        for w = week, 1, -1 do
            lines[#lines + 1] = "|cffffd100" .. string.format(L("Week %d"), w) .. "|r"
            for _, c in ipairs(Challenges(s, w)) do
                local ok = c.current >= c.goal and c.key ~= "role"
                local mark = ok and ("|cff55ff55" .. L("done") .. "|r") or (math.min(c.current, c.goal) .. " / " .. c.goal)
                lines[#lines + 1] = "   " .. (ok and "|cff55ff55" or "|cffffffff") .. c.title .. "|r  " .. Grey(c.text) .. "   " .. mark
            end
            lines[#lines + 1] = " "
        end
        UI.challenges:SetText(table.concat(lines, "\n"))
    else
        local keys = {}
        for k in pairs(Char().seasons) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return a > b end)
        local rows = {}
        for _, k in ipairs(keys) do
            local x = Char().seasons[k]
            rows[#rows + 1] = { cells = { Date(k) .. " - " .. Date(k + LENGTH - DAY), string.format("%.1f", Score(x.world, x.bg)),
                tostring(x.world + x.bg), tostring(x.world), tostring(x.bg), x.wins .. " / " .. x.matches } }
        end
        UI.seasons:SetData(rows)
    end
end

W.RegisterModule("Minotaure", L("Minotaure"), function(p)
    UI.panel = p
    W.Title(p, L("Minotaure"))
    UI.season = W.Label(p, "", "GameFontHighlightSmall")
    UI.season:SetPoint("TOPRIGHT", -16, -14)
    UI.tabs = W.SubTabs(p, { L("Ranking"), L("My season"), L("Challenges"), L("Seasons") }, function() Refresh() end)
    local f1, f2, f3, f4 = UI.tabs.frames[1], UI.tabs.frames[2], UI.tabs.frames[3], UI.tabs.frames[4]

    UI.ranking = W.Table(f1, { { "#", 30, "CENTER" }, { L("Player"), 210 }, { L("Score"), 70, "CENTER" }, { L("World"), 70, "CENTER" },
        { L("BG"), 70, "CENTER" }, { L("Wins"), 75, "CENTER" }, { L("Played"), 70, "CENTER" }, { L("Source"), 110, "CENTER" } }, 380)
    UI.ranking:SetPoint("TOPLEFT", 10, -6)
    local n1 = W.Label(f1, L("The guild members' figures are sent by their addon: they are shown as declared, nothing can check them."), "GameFontDisableSmall")
    n1:SetPoint("TOPLEFT", 16, -396)
    n1:SetWidth(780)
    n1:SetJustifyH("LEFT")

    W.Check(f2, L("Count my PvP for the Minotaure"), function() return db.on end, function(v) db.on = v; Zone() end):SetPoint("TOPLEFT", 12, -4)
    W.Check(f2, L("Share my totals with the guild"), function() return db.share end, function(v) db.share = v; if v then Share() end end)
        :SetPoint("TOPLEFT", 12, -28)
    W.Check(f2, L("Messages in the chat (challenges, end of season)"), function() return db.notify end, function(v) db.notify = v end)
        :SetPoint("TOPLEFT", 12, -52)
    UI.mine = W.Label(f2, "", "GameFontHighlight")
    UI.mine:SetPoint("TOPLEFT", 16, -90)
    UI.mine:SetWidth(780)
    UI.mine:SetJustifyH("LEFT")
    UI.mine:SetSpacing(6)
    local rules = W.Label(f2, L("Rules: 5 points per honorable kill (open world or battleground), 30 per battleground win, nothing for a loss, at most 200 points a day. Score = 50 x world / (world + 200) + 50 x BG / (BG + 200). A battleground counts when you saw it running (not after a reload on the score screen). Seasons of 28 days, the same for everybody (UTC)."),
        "GameFontDisableSmall")
    rules:SetPoint("TOPLEFT", 16, -300)
    rules:SetWidth(780)
    rules:SetJustifyH("LEFT")
    W.Label(f2, L("Rules and idea: Sashoof's WarLegend v3 addon."), "GameFontDisableSmall"):SetPoint("TOPLEFT", rules, "BOTTOMLEFT", 0, -8)

    UI.challenges = W.Label(f3, "", "GameFontHighlightSmall")
    UI.challenges:SetPoint("TOPLEFT", 16, -6)
    UI.challenges:SetWidth(780)
    UI.challenges:SetJustifyH("LEFT")
    UI.challenges:SetSpacing(4)

    UI.seasons = W.Table(f4, { { L("Season"), 140 }, { L("Score"), 80, "CENTER" }, { L("Points"), 80, "CENTER" }, { L("World"), 80, "CENTER" },
        { L("BG"), 80, "CENTER" }, { L("Wins / played"), 120, "CENTER" } }, 360)
    UI.seasons:SetPoint("TOPLEFT", 10, -6)
    W.Label(f4, L("Your seasons (this character). The ranking of the guild is kept for the season in progress only."), "GameFontDisableSmall")
        :SetPoint("TOPLEFT", 16, -376)

    p:SetScript("OnShow", function() Ask(); Refresh() end)
    UI.tabs:Select(1)
end, function()
    if UI.tabs then UI.tabs:Select(UI.tabs.current or 1) end
end)

W.slash.mino = function() W.Toggle("Minotaure") end
