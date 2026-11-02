-- WarLegend RaidTool - Leveling
-- Guild members leveling near my level and zone, and who is looking for a group: Invite and Whisper on a click.
-- The data is the guild roster (level, zone) plus one small GUILD message (WLRT_LVL: looking / grouped / level /
-- zone), sent when my state changes, at most once a minute. Nothing leaves the guild, no automatic whisper.
-- Idea from GroupGains (Cohort Gaming, no licence: nothing was taken from it).
local W = WLRT
local L = W.L
local db

W.AddFR({
    ["Leveling"] = "Leveling",
    ["Leveling companions"] = "Compagnons de leveling",
    ["I am looking for a leveling group (shown to the guild)"] = "Je cherche un groupe de leveling (visible par la guilde)",
    ["Guild members with the addon see you first in this list, and those near your level get one line in their chat."] =
        "Les membres de la guilde qui ont l'addon te voient en tête de cette liste, et ceux proches de ton niveau ont une ligne dans leur chat.",
    ["Share my level, zone and status with the guild"] = "Partager mon niveau, ma zone et mon statut avec la guilde",
    ["Say in my chat when a guild member near my level is looking for a group"] =
        "Dire dans mon chat quand un membre de la guilde proche de mon niveau cherche un groupe",
    ["Levels around mine:"] = "Niveaux autour du mien :",
    ["Any level"] = "Tous les niveaux",
    ["My zone only"] = "Ma zone seulement",
    ["Me: level %d, %s"] = "Moi : niveau %d, %s",
    ["Player"] = "Joueur",
    ["Level"] = "Niveau",
    ["Zone"] = "Zone",
    ["Layer"] = "Layer",
    ["Status"] = "Statut",
    ["Seen"] = "Vu",
    ["Layer %d"] = "Layer %d",
    ["Looking for a group"] = "Cherche un groupe",
    ["In a group"] = "En groupe",
    ["Same zone"] = "Même zone",
    ["No guild member online near my level. Widen the levels, or wait for the roster."] =
        "Aucun membre de la guilde en ligne proche de mon niveau. Élargis les niveaux, ou attends la liste de guilde.",
    ["Click: select. Right click: whisper."] = "Clic : sélectionner. Clic droit : chuchoter.",
    ["Invite"] = "Inviter",
    ["Whisper"] = "Chuchoter",
    ["Selected: %s"] = "Sélectionné : %s",
    ["Click a player, then Invite or Whisper."] = "Clique un joueur, puis Inviter ou Chuchoter.",
    ["Invite: not in combat."] = "Invitation impossible en combat.",
    ["Invite: %s is already in my group."] = "Invitation impossible : %s est déjà dans mon groupe.",
    ["Invite: only the leader or an assistant can invite."] = "Invitation impossible : seul le chef ou un assistant peut inviter.",
    ["Invitation sent to %s."] = "Invitation envoyée à %s.",
    ["%s (level %d, %s) is looking for a leveling group. /wl lvl"] = "%s (niveau %d, %s) cherche un groupe de leveling. /wl lvl",
    ["The list comes from the guild roster (level, zone of each member online). A member with the addon also says whether he is looking for a group or already grouped, at most once a minute, to the guild only. Whisper opens the chat box: nothing is sent by itself."] =
        "La liste vient de la liste de guilde (niveau et zone de chaque membre en ligne). Un membre qui a l'addon dit aussi s'il cherche un groupe ou s'il est déjà groupé, au plus une fois par minute, à la guilde seulement. Chuchoter ouvre la zone de saisie du chat : rien ne part tout seul.",
    ["Idea from GroupGains (Cohort Gaming)."] = "Idée reprise de GroupGains (Cohort Gaming).",
    ["%d s"] = "%d s",
    ["%d min"] = "%d min",
    ["%d h"] = "%d h",
})

local PREFIX = "WLRT_LVL"
local SHARE_GAP = 60    -- my state goes out at most once a minute (a change inside the minute waits for its end)
local HEARTBEAT = 300   -- while I am looking: sent again every 5 min (the others forget a message after KEEP)
local KEEP = 900        -- a member's message is forgotten after 15 min (the roster still lists him)
local MAX_ENTRIES = 500 -- messages kept (a guild has 120 members: a buggy client must not grow this)
local NOTICE_GAP = 1800 -- "X is looking for a group" said once per member per 30 min
local MAX_NOTICED = 500

local guild = {}   -- W.Key(full name) -> { key, name, full, looking, grouped, level, zone, at }
local entries = 0
local noticed, noticedN = {}, 0 -- key -> GetTime() of the last chat line about him
local UI = {}
local selected      -- full name of the selected row
local Refresh

W.OnReady(function()
    db = W.DB("leveling", { share = true, looking = false, range = 5, sameZone = false, notify = true })
end)

local function MyZone() return W.Safe(GetRealZoneText()) or "" end
local function MyLevel() return W.Int(W.Safe(UnitLevel("player")), 1, 100) or 1 end

local function InRange(level)
    local r = db and db.range or 5
    return r == 0 or math.abs(level - MyLevel()) <= r
end

local function Age(at)
    local s = math.max(0, GetServerTime() - (at or 0))
    if s < 60 then return string.format(L("%d s"), s) end
    if s < 3600 then return string.format(L("%d min"), math.floor(s / 60)) end
    return string.format(L("%d h"), math.floor(s / 3600))
end

---------------------------------------------------------------------------
-- Sharing (GUILD): "1^looking^grouped^level^zone"; "?" asks the others to send theirs
---------------------------------------------------------------------------
local lastShare, waiting = -1000, false
local lastGrouped, lastZone
local function Share(force)
    if not db or not db.share or not W.IsInGuild() or W.IsOff("Leveling") then return end
    local now = GetTime()
    if now - lastShare < SHARE_GAP then
        -- a change inside the minute: one message at the end of it, with the state of that moment
        if force and not waiting then
            waiting = true
            W.After(SHARE_GAP - (now - lastShare) + 0.1, function() waiting = false; Share(true) end, "Leveling share")
        end
        return
    end
    lastShare = now
    lastGrouped, lastZone = W.InGroup(), MyZone()
    W.Send(PREFIX, W.Pack(1, db.looking and 1 or 0, lastGrouped and 1 or 0, MyLevel(), W.Plain(lastZone, 60)), "GUILD")
end

local beating = false
local function Heartbeat()
    if not db or not db.looking then beating = false; return end
    Share(false)
    W.After(HEARTBEAT, Heartbeat, "Leveling heartbeat")
end
local function StartHeartbeat()
    if beating then return end
    beating = true
    W.After(HEARTBEAT, Heartbeat, "Leveling heartbeat")
end
W.OnReady(function() if db.looking then StartHeartbeat() end end)

local lastAsk, lastAnswer = -1000, -1000
local function Ask()
    if not db.share or not W.IsInGuild() or GetTime() - lastAsk < 60 then return end
    lastAsk = GetTime()
    W.Send(PREFIX, "?", "GUILD")
end

-- my state changed (group joined or left, zone, level): tell the guild, once a minute at most
local function Changed()
    if not db or not db.share then return end
    local grouped, zone = W.InGroup(), MyZone()
    if grouped ~= lastGrouped or (db.looking and zone ~= lastZone) then Share(true) end
end
W.OnRoster(Changed)
W.On("ZONE_CHANGED_NEW_AREA", Changed)
W.On("PLAYER_LEVEL_UP", function() if db and db.looking then Share(true) end end)
W.On("GUILD_ROSTER_UPDATE", function() UI.dirty = true end)

local function Notice(e)
    if not db.notify or not e.looking or e.grouped or IsInInstance() then return end
    local now = GetTime()
    if now - (noticed[e.key] or -1000) < NOTICE_GAP or not InRange(e.level) then return end
    if not noticed[e.key] then
        if noticedN >= MAX_NOTICED then wipe(noticed); noticedN = 0 end
        noticedN = noticedN + 1
    end
    noticed[e.key] = now
    local m = W.GuildMember(e.full)
    W.Print(string.format(L("%s (level %d, %s) is looking for a leveling group. /wl lvl"),
        W.ColorName((W.FOREVER and e.full) or e.name, m and m.class), e.level, e.zone))
end

W.OnAddon(PREFIX, function(msg, name, channel, full)
    if channel ~= "GUILD" or not db or #msg > 100 then return end
    if full == W.UnitFullName("player") then return end
    if msg == "?" then
        -- one answer a minute whoever asks: a flood of "?" must not make the whole guild send
        if GetTime() - lastAnswer >= 60 then
            lastAnswer = GetTime()
            W.After(1 + math.random() * 8, function() Share(true) end, "Leveling answer") -- the whole guild hears "?": answers spread out
        end
        return
    end
    local f = W.Unpack(msg)
    if f[1] ~= "1" or (f[2] ~= "0" and f[2] ~= "1") or (f[3] ~= "0" and f[3] ~= "1") then return end
    if not f[4] or not f[4]:match("^%d%d?%d?$") then return end
    local level = tonumber(f[4])
    if level < 1 or level > 100 then return end
    local key = W.Key(full)
    local e = guild[key] -- the same table each time a member sends: no allocation per message
    if not e then
        if entries >= MAX_ENTRIES then return end
        e = { key = key }
        guild[key] = e
        entries = entries + 1
    end
    e.name, e.full, e.looking, e.grouped, e.level, e.zone, e.at = name, full, f[2] == "1", f[3] == "1", level, W.Plain(f[5] or "", 60), GetServerTime()
    Notice(e)
    UI.dirty = true
end)

---------------------------------------------------------------------------
-- Invite / whisper the selected member (both on a click)
---------------------------------------------------------------------------
local function InGroupWith(key)
    for _, u in ipairs(W.GroupUnits()) do
        local f = W.UnitFullName(u)
        if f and W.Key(f) == key then return true end
    end
    return false
end

local function InviteSelected()
    if not selected then return end
    local key = W.Key(selected)
    local name = (W.FOREVER and selected) or W.BaseName(selected)
    if InCombatLockdown() then W.Print(L("Invite: not in combat.")); return end
    if InGroupWith(key) then W.Print(string.format(L("Invite: %s is already in my group."), name)); return end
    if W.InGroup() and not W.CanLead() then W.Print(L("Invite: only the leader or an assistant can invite.")); return end
    if C_PartyInfo and C_PartyInfo.InviteUnit then C_PartyInfo.InviteUnit(selected)
    elseif InviteUnit then InviteUnit(selected) end
    W.Print(string.format(L("Invitation sent to %s."), name))
end

-- opens the chat box on "/w Name": the player types the message, nothing is sent by the addon
local function WhisperSelected()
    if selected and ChatFrame_SendTell then ChatFrame_SendTell(selected) end
end

---------------------------------------------------------------------------
-- Window tab
---------------------------------------------------------------------------
local function StatusCell(e)
    if e.looking and not e.grouped then return "|cff55ff55" .. L("Looking for a group") .. "|r" end
    if e.grouped then return "|cff777777" .. L("In a group") .. "|r" end
    return ""
end

local function LayerCell(e)
    if not W.GuildLayer then return "" end
    local n, same = W.GuildLayer(e.full)
    if not n then return "" end
    local text = string.format(L("Layer %d"), n)
    return same and ("|cff55ff55" .. text .. "|r") or ("|cff777777" .. text .. "|r")
end

function Refresh()
    if not UI.panel then return end
    UI.dirty = nil
    local now = GetServerTime()
    local myZone, myLevel = MyZone(), MyLevel()
    local myKey = W.Key(W.UnitFullName("player") or "")
    UI.mine:SetText(string.format(L("Me: level %d, %s"), myLevel, myZone))
    for key, e in pairs(guild) do
        if now - e.at > KEEP then guild[key] = nil; entries = entries - 1 end
    end
    local list = {}
    for _, m in ipairs(W.GuildMembers()) do
        local key = W.Key(m.full)
        if m.online and key ~= myKey then
            local e = guild[key]
            local level = e and e.level or m.level
            local zone = (e and e.zone ~= "" and e.zone) or m.zone or ""
            if type(level) == "number" and InRange(level) and (not db.sameZone or zone == myZone) then
                list[#list + 1] = { key = key, full = m.full, name = m.name, class = m.class, level = level, zone = zone,
                    looking = e and e.looking and not e.grouped, grouped = e and e.grouped, at = e and e.at,
                    same = zone == myZone, dist = math.abs(level - myLevel) }
            end
        end
    end
    table.sort(list, function(a, b)
        if (a.looking or false) ~= (b.looking or false) then return a.looking and true or false end
        if a.same ~= b.same then return a.same end
        if a.dist ~= b.dist then return a.dist < b.dist end
        return a.name < b.name
    end)
    local rows = {}
    for _, e in ipairs(list) do
        local name = W.ColorName((W.FOREVER and e.full) or e.name, e.class)
        if selected and e.key == W.Key(selected) then name = "|cffffff00> |r" .. name end
        rows[#rows + 1] = { full = e.full, cells = {
            name,
            tostring(e.level),
            e.same and ("|cff55ff55" .. e.zone .. "|r") or e.zone,
            LayerCell(e),
            StatusCell(e),
            e.at and Age(e.at) or "",
        } }
    end
    UI.table:SetData(rows)
    local e = selected and W.GuildMember(selected)
    UI.sel:SetText(e and string.format(L("Selected: %s"), (W.FOREVER and e.full) or e.name)
        or "|cffaaaaaa" .. L("Click a player, then Invite or Whisper.") .. "|r")
    if e then UI.invite:Enable(); UI.whisper:Enable() else UI.invite:Disable(); UI.whisper:Disable() end
end

W.RegisterModule("Leveling", "Leveling", function(p)
    UI.panel = p
    W.Title(p, L("Leveling companions"))
    W.Check(p, L("I am looking for a leveling group (shown to the guild)"), function() return db.looking end,
        function(v) db.looking = v; if v then StartHeartbeat() end; Share(true); Refresh() end,
        { L("Guild members with the addon see you first in this list, and those near your level get one line in their chat.") }):SetPoint("TOPLEFT", 12, -40)
    W.Check(p, L("Share my level, zone and status with the guild"), function() return db.share end,
        function(v) db.share = v; if v then Share(true); Ask() end end):SetPoint("TOPLEFT", 12, -64)
    W.Check(p, L("Say in my chat when a guild member near my level is looking for a group"), function() return db.notify end,
        function(v) db.notify = v end):SetPoint("TOPLEFT", 12, -88)
    local lbl = W.Label(p, L("Levels around mine:"), "GameFontNormal")
    lbl:SetPoint("TOPLEFT", 16, -120)
    UI.range = W.Cycle(p, 130, { { 3, "±3" }, { 5, "±5" }, { 10, "±10" }, { 0, L("Any level") } },
        function() return db.range end, function(v) db.range = v; Refresh() end)
    UI.range:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
    W.Check(p, L("My zone only"), function() return db.sameZone end,
        function(v) db.sameZone = v; Refresh() end):SetPoint("LEFT", UI.range, "RIGHT", 16, 0)
    UI.mine = W.Label(p, "", "GameFontNormal")
    UI.mine:SetPoint("TOPLEFT", 16, -148)
    UI.mine:SetWidth(780)
    UI.mine:SetJustifyH("LEFT")
    UI.table = W.Table(p, { { L("Player"), 200 }, { L("Level"), 50, "CENTER" }, { L("Zone"), 190 }, { L("Layer"), 80, "CENTER" },
        { L("Status"), 150 }, { L("Seen"), 70, "CENTER" } }, 310)
    UI.table:SetPoint("TOPLEFT", 10, -170)
    UI.table:SetEmptyText(L("No guild member online near my level. Widen the levels, or wait for the roster."))
    UI.table.onEnter = function(_, row)
        GameTooltip:SetOwner(row, "ANCHOR_CURSOR")
        GameTooltip:AddLine(L("Click: select. Right click: whisper."), 1, 1, 1)
        GameTooltip:Show()
    end
    UI.table.onClick = function(d, btn)
        if btn == "RightButton" then
            if ChatFrame_SendTell then ChatFrame_SendTell(d.full) end
        else
            selected = d.full
            Refresh()
        end
    end
    UI.invite = W.Button(p, L("Invite"), 110, 22, InviteSelected)
    UI.invite:SetPoint("TOPLEFT", 10, -488)
    UI.whisper = W.Button(p, L("Whisper"), 110, 22, WhisperSelected)
    UI.whisper:SetPoint("LEFT", UI.invite, "RIGHT", 6, 0)
    UI.sel = W.Label(p, "", "GameFontHighlightSmall")
    UI.sel:SetPoint("LEFT", UI.whisper, "RIGHT", 10, 0)
    UI.sel:SetWidth(500)
    UI.sel:SetJustifyH("LEFT")
    local hint = W.Label(p, L("The list comes from the guild roster (level, zone of each member online). A member with the addon also says whether he is looking for a group or already grouped, at most once a minute, to the guild only. Whisper opens the chat box: nothing is sent by itself."),
        "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 16, -516)
    hint:SetWidth(780)
    hint:SetJustifyH("LEFT")
    local credit = W.Label(p, L("Idea from GroupGains (Cohort Gaming)."), "GameFontDisableSmall")
    credit:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -6)
    local acc = 0
    p:SetScript("OnShow", function() acc = 0; W.RequestGuildRoster(); Ask(); Refresh() end)
    p:SetScript("OnUpdate", function(_, el)
        acc = acc + el
        if acc >= 5 or (UI.dirty and acc >= 1) then acc = 0; Refresh() end
    end)
end, function() Refresh() end)

W.slash.lvl = function() W.Toggle("Leveling") end
