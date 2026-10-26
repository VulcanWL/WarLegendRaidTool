-- WarLegend RaidTool - Guild trials
-- Members at the trial rank: since when (first time this computer saw them at that rank), how many raids
-- in your attendance since then, reminder once a day when a trial is over. Nothing is sent to anyone.
local W = WLRT
W.AddFR({
    ["Trials"] = "Recrues",
    ["Trial rank:"] = "Rang d'essai :",
    ["Trial length:"] = "Durée de l'essai :",
    ["None"] = "Aucun",
    ["%d days"] = "%d jours",
    ["Name"] = "Nom",
    ["Level"] = "Niveau",
    ["Trial since"] = "En essai depuis",
    ["Days"] = "Jours",
    ["Raids"] = "Raids",
    ["Status"] = "État",
    ["To review"] = "À évaluer",
    ["%d day(s) left"] = "%d jour(s) restant(s)",
    ["Choose the trial rank. The date is the first time you saw the member at that rank. Raids = raid nights in your attendance since then."] =
        "Choisis le rang d'essai. La date est la première fois que tu as vu le membre à ce rang. Raids = soirées de raid dans tes présences depuis.",
    ["Trials to review: %s"] = "Recrues à évaluer : %s",
})
local L = W.L

local db

W.OnReady(function()
    db = W.DB("roster", { trialRank = "", trialDays = 21, remindDay = "" })
    if type(db.trials) ~= "table" then db.trials = {} end -- [key] = first time seen at the trial rank
    db.players = nil -- mains / alts of an earlier test version
end)

---------------------------------------------------------------------------
-- First time each member is seen at the trial rank
---------------------------------------------------------------------------
local lastScan = 0
local function ScanTrials()
    if not db or db.trialRank == "" or not W.IsInGuild() or GetTime() - lastScan < 30 then return end
    lastScan = GetTime()
    local members = W.GuildMembers()
    if #members == 0 then return end
    local now, rankOf = time(), {}
    for _, m in ipairs(members) do
        local k = m.full:lower()
        rankOf[k] = m.rank
        if m.rank == db.trialRank and not db.trials[k] then db.trials[k] = now end
    end
    -- promoted: forgotten. Not in the roster: kept (the roster can list online members only on Classic),
    -- forgotten after 6 months
    for k, since in pairs(db.trials) do
        if (rankOf[k] and rankOf[k] ~= db.trialRank) or now - since > 180 * 86400 then db.trials[k] = nil end
    end
end

local UI = {}
local RefreshTrials

W.On("GUILD_ROSTER_UPDATE", function() ScanTrials(); if W.IsShown("Roster") then RefreshTrials() end end)

local function Overdue()
    local out, limit = {}, (db.trialDays or 21) * 86400
    for _, m in ipairs(W.GuildMembers()) do
        local since = m.rank == db.trialRank and db.trials[m.full:lower()]
        if since and time() - since >= limit then out[#out + 1] = W.FOREVER and m.full or m.name end
    end
    return out
end

local function CanManage()
    if C_GuildInfo and C_GuildInfo.CanEditOfficerNote then return C_GuildInfo.CanEditOfficerNote() end
    return CanEditOfficerNote and CanEditOfficerNote() or false
end

-- officers get a reminder once a day when a trial is over
W.On("PLAYER_ENTERING_WORLD", function(isLogin)
    if not isLogin then return end
    W.After(60, function()
        if not db or db.trialRank == "" or db.remindDay == date("%Y-%m-%d") or not CanManage() then return end
        W.RequestGuildRoster()
        W.After(5, function()
            ScanTrials()
            local list = Overdue()
            if #list > 0 then
                db.remindDay = date("%Y-%m-%d")
                W.Print(string.format(L("Trials to review: %s"), table.concat(list, ", ")))
            end
        end)
    end)
end)

-- raid nights of the attendance where this player was there (not benched) since a date
local function RaidsSince(key, since)
    local a = W.db and W.db.attendance
    local count = 0
    for _, night in ipairs(type(a) == "table" and type(a.nights) == "table" and a.nights or {}) do
        if (night.t or 0) >= since then
            local p = night.players and night.players[key]
            if p and not p.bench then count = count + 1 end
        end
    end
    return count
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
function RefreshTrials()
    if not UI.trials or not UI.trials:IsVisible() then return end
    local rows, limit = {}, (db.trialDays or 21) * 86400
    for _, m in ipairs(W.GuildMembers()) do
        local k = m.full:lower()
        local since = db.trialRank ~= "" and m.rank == db.trialRank and db.trials[k]
        if since then
            local age = time() - since
            local status = age >= limit and ("|cffff5555" .. L("To review") .. "|r")
                or string.format(L("%d day(s) left"), math.ceil((limit - age) / 86400))
            rows[#rows + 1] = { since = since, cells = { W.ColorName(W.FOREVER and m.full or m.name, m.class), m.level or "",
                date("%d/%m/%Y", since), math.floor(age / 86400), RaidsSince(k, since), status } }
        end
    end
    table.sort(rows, function(a, b) return a.since < b.since end)
    UI.trials:SetData(rows)
end

W.RegisterModule("Roster", "Trials", function(p)
    W.Title(p, L("Trials"))
    local lbl = W.Label(p, L("Trial rank:"), "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT", 14, -44)
    local rankValues = {}
    local rankCycle = W.Cycle(p, 160, rankValues, function() return db.trialRank end,
        function(v) db.trialRank = v; lastScan = 0; ScanTrials(); RefreshTrials() end)
    rankCycle:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
    local lbl2 = W.Label(p, L("Trial length:"), "GameFontHighlightSmall")
    lbl2:SetPoint("LEFT", rankCycle, "RIGHT", 20, 0)
    local lengths = {}
    for _, d in ipairs({ 7, 14, 21, 28, 30, 45 }) do lengths[#lengths + 1] = { d, string.format(L("%d days"), d) } end
    W.Cycle(p, 100, lengths, function() return db.trialDays end, function(v) db.trialDays = v; RefreshTrials() end)
        :SetPoint("LEFT", lbl2, "RIGHT", 8, 0)
    UI.trials = W.Table(p, { { L("Name"), 200 }, { L("Level"), 60, "CENTER" }, { L("Trial since"), 110, "CENTER" },
        { L("Days"), 60, "CENTER" }, { L("Raids"), 60, "CENTER" }, { L("Status"), 180 } }, 440)
    UI.trials:SetPoint("TOPLEFT", 10, -74)
    local hint = W.Label(p, L("Choose the trial rank. The date is the first time you saw the member at that rank. Raids = raid nights in your attendance since then."),
        "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", 14, 8)
    hint:SetWidth(800)
    hint:SetJustifyH("LEFT")
    p:SetScript("OnShow", function()
        wipe(rankValues)
        rankValues[1] = { "", L("None") }
        local seen, ranks = {}, {}
        for _, m in ipairs(W.GuildMembers()) do
            if m.rank and not seen[m.rank] then seen[m.rank] = true; ranks[#ranks + 1] = m end
        end
        table.sort(ranks, function(a, b) return (a.rankIndex or 0) < (b.rankIndex or 0) end)
        for _, m in ipairs(ranks) do rankValues[#rankValues + 1] = { m.rank, m.rank } end
        rankCycle.Sync()
        W.RequestGuildRoster()
        ScanTrials()
        RefreshTrials()
    end)
end, function() RefreshTrials() end)

W.slash.trials = function() W.Toggle("Roster") end
