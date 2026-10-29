-- WarLegend RaidTool - Raid attendance
-- One record per raid night (same instance, less than 4 hours between two sightings): who came, at what
-- time they arrived and left, at which boss pulls they were there, which bosses died, who was benched.
-- Stats over the last N nights: % of nights, % of pulls, late arrivals, early departures, bench.
-- Cost: roster changes are read once they settle (raid instances only) plus one look every 5 minutes.
local W = WLRT
W.AddFR({
    ["Attendance"] = "Présences",
    ["Snapshot now"] = "Relevé maintenant",
    ["Record on every boss pull"] = "Relever à chaque pull de boss",
    ["Record on every ready check"] = "Relever à chaque appel",
    ["Guild members only"] = "Membres de la guilde uniquement",
    ["Last %d raids"] = "%d derniers raids",
    ["All raids"] = "Tous les raids",
    ["Raids"] = "Raids",
    ["Last seen"] = "Vu le",
    ["Players"] = "Joueurs",
    ["Bosses"] = "Boss",
    ["Attendance recorded: %d players (%s)."] = "Présences relevées : %d joueurs (%s).",
    ["Delete this raid?"] = "Supprimer ce raid ?",
    ["You are not in a raid."] = "Tu n'es pas en raid.",
    ["Nights"] = "Soirées",
    ["Pulls"] = "Pulls",
    ["Late"] = "Retards",
    ["Left early"] = "Partis tôt",
    ["Bench"] = "Banc",
    ["Kills"] = "Kills",
    ["Bench (names, tonight):"] = "Banc (noms, ce soir) :",
    ["Add to bench"] = "Ajouter au banc",
    ["%d player(s) added to the bench."] = "%d joueur(s) ajouté(s) au banc.",
    ["No raid night yet: be in a raid instance."] = "Pas encore de soirée de raid : sois dans une instance de raid.",
    ["Left-click a night for details, right-click to delete it."] = "Clic gauche sur une soirée pour le détail, clic droit pour la supprimer.",
    ["Late = arrived more than 15 min after the start; Left = gone more than 15 min before the end."] =
        "Retard = arrivé plus de 15 min après le début ; Parti tôt = parti plus de 15 min avant la fin.",
    ["kill"] = "kill",
    ["wipe"] = "wipe",
    ["%d present"] = "%d présents",
    ["absent: %s"] = "absents : %s",
    ["Arrived %s, left %s"] = "Arrivé %s, parti %s",
    ["benched"] = "sur le banc",
    ["No raid night recorded yet."] = "Aucune soirée de raid enregistrée pour l'instant.",
})
local L = W.L

local AT = {}
W.Attendance = AT
local db

local NIGHT_GAP = 4 * 3600   -- a new night starts after 4 hours without seeing the raid
local LATE = 15 * 60         -- late / left early threshold
local MAX_NIGHTS, MAX_PULLS = 150, 100

-- Old format (one entry per day: players + bosses, no times) -> nights. Old nights have no
-- per-pull data: they count for "% of nights" but not for "% of pulls".
W.Migration(1, "attendance", function(all)
    local a = all.attendance
    if type(a) ~= "table" or type(a.raids) ~= "table" or a.nights then return end
    local nights = {}
    for _, r in ipairs(a.raids) do
        if type(r) == "table" and type(r.players) == "table" then
            local t = tonumber(r.t) or 0
            local n = { day = r.day, zone = r.zone, t = t, e = t, players = {}, pulls = {} }
            for name, class in pairs(r.players) do
                n.players[name] = { c = type(class) == "string" and class or nil, f = t, l = t, s = "" }
            end
            for boss, killed in pairs(type(r.bosses) == "table" and r.bosses or {}) do
                n.pulls[#n.pulls + 1] = { b = boss, t = t, k = killed and true or false, old = true }
            end
            nights[#nights + 1] = n
        end
    end
    a.nights, a.raids = nights, nil
end)

W.OnReady(function()
    db = W.DB("attendance", { onBoss = true, onReadyCheck = true, guildOnly = true, range = 10 })
    if type(db.nights) ~= "table" then db.nights = {} end
end)

local function InRaidInstance()
    local _, kind = IsInInstance()
    return kind == "raid" and W.InRaid()
end

local function ZoneName()
    local name = GetInstanceInfo and GetInstanceInfo()
    return W.Safe(name) or "?"
end

-- Tonight's record for this instance (a new one after a 4 hour gap)
local function Night(create)
    local zone, now = ZoneName(), time()
    local n = db.nights[1]
    if n and n.zone == zone and now - (n.e or n.t) < NIGHT_GAP then return n end
    if not create then return nil end
    n = { day = date("%Y-%m-%d"), zone = zone, t = now, e = now, players = {}, pulls = {} }
    table.insert(db.nights, 1, n)
    while #db.nights > MAX_NIGHTS do table.remove(db.nights) end
    return n
end

-- Everyone connected in the raid right now: name -> class
-- Players are keyed by full identity (W.UnitKey): two raiders sharing a first name stay apart.
-- p.n keeps the name to show. Old records (keyed by first name) are matched in AT.Stats.
local present, presentNames = {}, {}
local function Present()
    wipe(present); wipe(presentNames)
    for _, u in ipairs(W.GroupUnits()) do
        local key = W.UnitKey(u)
        if key and (not UnitIsConnected or W.Safe(UnitIsConnected(u)) ~= false) then
            present[key] = W.UnitClassToken(u) or true
            presentNames[key] = W.UnitDisplayName(u)
        end
    end
    return present
end

-- Updates arrival / last seen times; pull = true adds a boss pull to everyone's presence string
local function Record(boss)
    local n = Night(true)
    local now = time()
    n.e = now
    local here = Present()
    for key, class in pairs(here) do
        local p = n.players[key]
        if not p then
            p = { c = type(class) == "string" and class or nil, f = now, l = now, s = "", n = presentNames[key] }
            n.players[key] = p
        end
        p.l = now
        if p.bench then p.bench = nil end -- benched then came in: present
    end
    if boss and #n.pulls < MAX_PULLS then
        n.pulls[#n.pulls + 1] = { b = boss, t = now, k = false }
        local count = #n.pulls
        for name, p in pairs(n.players) do
            p.s = (p.s or ""):sub(1, count - 1)
            p.s = p.s .. string.rep("0", count - 1 - #p.s) .. (here[name] and "1" or "0")
        end
    end
    return n
end

function AT.Snapshot(quiet)
    if not W.InRaid() then if not quiet then W.Print(L("You are not in a raid.")) end; return end
    local n = Record()
    if not quiet then
        local count = 0
        for _ in pairs(present) do count = count + 1 end
        W.Print(string.format(L("Attendance recorded: %d players (%s)."), count, n.zone))
    end
    AT.Refresh()
end

---------------------------------------------------------------------------
-- Events (raid instances only)
---------------------------------------------------------------------------
local function RaidBoss()
    local _, kind = IsInInstance()
    return W.InRaid() and kind ~= "party" and kind ~= "pvp" and kind ~= "arena"
end
W.On("ENCOUNTER_START", function(_, name)
    if db and db.onBoss and RaidBoss() then Record(W.Safe(name) or "?"); AT.Refresh() end
end)
W.On("ENCOUNTER_END", function(_, name, _, _, success)
    if not db or not RaidBoss() or W.Safe(success) ~= 1 then return end
    local n = Night(false)
    name = W.Safe(name) or "?"
    if not n then return end
    for i = #n.pulls, 1, -1 do
        if n.pulls[i].b == name then n.pulls[i].k = true; break end
    end
    AT.Refresh()
end)
W.On("READY_CHECK", function()
    if db and db.onReadyCheck and InRaidInstance() then AT.Snapshot(true) end
end)

W.OnRoster(function()
    if db and InRaidInstance() then Record() end
end)

-- last seen times stay current while in a raid instance (departures are then visible)
local ticking = false
local function Tick()
    if not InRaidInstance() then ticking = false; return end
    Record()
    W.After(300, Tick)
end
W.On("PLAYER_ENTERING_WORLD", function()
    if db and not ticking and InRaidInstance() then ticking = true; W.After(5, Tick) end
end)

---------------------------------------------------------------------------
-- Stats over the last N nights
---------------------------------------------------------------------------
local function Ones(s) local _, c = (s or ""):gsub("1", ""); return c end

function AT.Stats()
    local n = db.range == 0 and #db.nights or math.min(db.range, #db.nights)
    local stats, totalPulls = {}, 0
    for i = 1, n do
        local night = db.nights[i]
        local pulls = 0
        for _, p in ipairs(night.pulls) do if not p.old then pulls = pulls + 1 end end
        totalPulls = totalPulls + pulls
        local nightEnd = night.e or night.t
        for rawKey, p in pairs(night.players) do
            -- old records are keyed by a first name: joined to the guild member who has it only when
            -- that first name is unique in the guild, otherwise kept apart (never merged blindly)
            local key, shown = rawKey, p.n
            if not W.HasFullPart(rawKey) then
                local m = W.GuildMember(rawKey)
                if m and m.full then key, shown = m.full:lower(), shown or (W.FOREVER and m.full or m.name) end
            end
            local s = stats[key]
            if not s then s = { key = key, name = shown or rawKey, nights = 0, bench = 0, pulls = 0, late = 0, left = 0 }; stats[key] = s end
            if p.n then s.name = p.n end
            if p.c then s.class = p.c end
            if p.bench then
                s.bench = s.bench + 1
            else
                s.nights = s.nights + 1
                s.pulls = s.pulls + Ones(p.s)
                if (p.f or night.t) - night.t > LATE then s.late = s.late + 1 end
                if nightEnd - (p.l or nightEnd) > LATE then s.left = s.left + 1 end
            end
            if not s.last or night.t > s.last then s.last = night.t end
        end
    end
    local list = {}
    for _, s in pairs(stats) do
        if not db.guildOnly or W.GuildMember(s.key) or not W.IsInGuild() then list[#list + 1] = s end
    end
    table.sort(list, function(a, b)
        if a.nights + a.bench ~= b.nights + b.bench then return a.nights + a.bench > b.nights + b.bench end
        return a.name < b.name
    end)
    return list, n, totalPulls
end

local UI = {}
local function Pct(a, b) return b > 0 and math.floor(a / b * 100 + 0.5) or 0 end
local function Colored(pct)
    return (pct >= 90 and "|cff33ff66" or (pct >= 70 and "|cffffcc33" or "|cffff5555")) .. pct .. "%|r"
end

function AT.Refresh()
    if not UI.players or not UI.players:IsVisible() then return end
    local list, n, totalPulls = AT.Stats()
    local rows = {}
    for _, s in ipairs(list) do
        rows[#rows + 1] = { cells = {
            W.ColorName(s.name, s.class),
            (s.nights + s.bench) .. "/" .. n,
            Colored(Pct(s.nights + s.bench, n)),
            totalPulls > 0 and Colored(Pct(s.pulls, totalPulls)) or "-",
            s.late > 0 and s.late or "",
            s.left > 0 and s.left or "",
            s.bench > 0 and s.bench or "",
            date("%d/%m", s.last) } }
    end
    UI.players:SetData(rows)
    local nights = {}
    for i, night in ipairs(db.nights) do
        local np, nk = 0, 0
        for _, p in pairs(night.players) do if not p.bench then np = np + 1 end end
        for _, p in ipairs(night.pulls) do if p.k then nk = nk + 1 end end
        nights[#nights + 1] = { index = i, cells = { night.day, night.zone, np, nk .. "/" .. #night.pulls } }
    end
    UI.raids:SetData(nights)
end

-- one night in detail: each pull with who was missing, each player's times
local function Detail(night)
    local out = { night.day .. "  " .. night.zone .. "  " .. date("%H:%M", night.t) .. " - " .. date("%H:%M", night.e or night.t), "" }
    local names = {}
    for key in pairs(night.players) do names[#names + 1] = key end
    local function shown(key) return night.players[key].n or key end
    table.sort(names, function(a, b) return shown(a) < shown(b) end)
    for i, pull in ipairs(night.pulls) do
        local missing, count = {}, 0
        for _, name in ipairs(names) do
            local p = night.players[name]
            if not p.bench then
                if (p.s or ""):sub(i, i) == "1" then count = count + 1 elseif not pull.old then missing[#missing + 1] = shown(name) end
            end
        end
        out[#out + 1] = date("%H:%M", pull.t) .. "  " .. pull.b .. "  (" .. (pull.k and L("kill") or L("wipe")) .. ")"
            .. (pull.old and "" or ("  " .. string.format(L("%d present"), count)
            .. (#missing > 0 and ("  " .. string.format(L("absent: %s"), table.concat(missing, ", "))) or "")))
    end
    out[#out + 1] = ""
    for _, name in ipairs(names) do
        local p = night.players[name]
        out[#out + 1] = shown(name) .. "  " .. (p.bench and L("benched")
            or string.format(L("Arrived %s, left %s"), date("%H:%M", p.f or night.t), date("%H:%M", p.l or night.t)))
    end
    W.TextPopup(L("Attendance"), table.concat(out, "\n"), { hint = "Ctrl+C" })
end

local function Export()
    local list, n, totalPulls = AT.Stats()
    local out = { W.CSV("name", "nights", "total", "percent_nights", "percent_pulls", "late", "left_early", "bench") }
    for _, s in ipairs(list) do
        out[#out + 1] = W.CSV(s.name, s.nights + s.bench, n, Pct(s.nights + s.bench, n), Pct(s.pulls, totalPulls), s.late, s.left, s.bench)
    end
    W.TextPopup(L("Attendance"), table.concat(out, "\n"), { hint = "Ctrl+C" })
end

local function AddBench(text)
    local n = Night(false)
    if not n then W.Print(L("No raid night yet: be in a raid instance.")); return end
    local count = 0
    for _, name in ipairs(W.NameList(text)) do
        -- a guild member is found by full name or a unique first name: benched under their full identity
        local g = W.GuildMember(name)
        local key = g and g.full and g.full:lower() or W.Key(name)
        if key and key ~= "" and not n.players[key] then
            local shown = g and (W.FOREVER and g.full or g.name) or name
            n.players[key] = { c = g and g.class or nil, f = n.t, l = n.t, s = "", bench = true, n = shown }
            count = count + 1
        end
    end
    W.Print(string.format(L("%d player(s) added to the bench."), count))
    AT.Refresh()
end

W.RegisterModule("Attendance", "Attendance", function(p)
    W.Title(p, L("Attendance"))
    W.Button(p, L("Snapshot now"), 130, 22, function() AT.Snapshot() end):SetPoint("TOPLEFT", 12, -34)
    W.Cycle(p, 120, { { 5, string.format(L("Last %d raids"), 5) }, { 10, string.format(L("Last %d raids"), 10) },
        { 20, string.format(L("Last %d raids"), 20) }, { 0, L("All raids") } },
        function() return db.range end, function(v) db.range = v; AT.Refresh() end):SetPoint("TOPLEFT", 148, -34)
    W.Button(p, L("Export CSV"), 110, 22, Export):SetPoint("TOPLEFT", 274, -34)
    W.Check(p, L("Record on every boss pull"), function() return db.onBoss end, function(v) db.onBoss = v end)
        :SetPoint("TOPLEFT", 400, -30)
    W.Check(p, L("Record on every ready check"), function() return db.onReadyCheck end, function(v) db.onReadyCheck = v end)
        :SetPoint("TOPLEFT", 600, -30)
    W.Check(p, L("Guild members only"), function() return db.guildOnly end, function(v) db.guildOnly = v; AT.Refresh() end)
        :SetPoint("TOPLEFT", 12, -60)
    W.Label(p, L("Bench (names, tonight):"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 228, -66)
    local bench = W.EditBox(p, 200, 200)
    bench:SetPoint("TOPLEFT", 360, -62)
    W.Button(p, L("Add to bench"), 120, 22, function() AddBench(bench:GetText()); bench:SetText("") end)
        :SetPoint("LEFT", bench, "RIGHT", 8, 0)
    UI.players = W.Table(p, { { L("Name"), 110 }, { L("Nights"), 50, "RIGHT" }, { "%", 42, "RIGHT" }, { L("Pulls"), 42, "RIGHT" },
        { L("Late"), 46, "RIGHT" }, { L("Left early"), 62, "RIGHT" }, { L("Bench"), 40, "RIGHT" }, { L("Last seen"), 46, "CENTER" } }, 440)
    UI.players:SetPoint("TOPLEFT", 10, -96)
    UI.raids = W.Table(p, { { L("Date"), 72 }, { L("Zone"), 110 }, { L("Players"), 46, "RIGHT" }, { L("Kills"), 46, "RIGHT" } }, 440)
    UI.raids:SetPoint("TOPLEFT", 470, -96)
    UI.raids:SetEmptyText(L("No raid night recorded yet."))
    UI.raids.onClick = function(d, btn)
        if btn == "RightButton" then
            -- the night itself, not its place: a new night can be added at the top while the question is open
            local night = db.nights[d.index]
            W.Confirm(L("Delete this raid?"), function()
                for i, n in ipairs(db.nights) do
                    if n == night then table.remove(db.nights, i); break end
                end
                AT.Refresh()
            end)
        else
            local night = db.nights[d.index]
            if night then Detail(night) end
        end
    end
    local hint = W.Label(p, L("Left-click a night for details, right-click to delete it.") .. "\n"
        .. L("Late = arrived more than 15 min after the start; Left = gone more than 15 min before the end."), "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", 14, 4)
end, function() AT.Refresh() end) -- run at each showing of the tab (an OnShow too drew it twice)
