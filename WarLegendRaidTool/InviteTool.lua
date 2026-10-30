-- WarLegend RaidTool - Invite Tool
-- A player whispers you a keyword (e.g. "inv", also "inv please" or from Battle.net): they get invited.
-- If you are not leader, the game forwards an invite suggestion to the leader.
-- Mass invites (online guild ranks, a list of names) go through a paced queue: 4 invites while
-- in a party, convert to raid as soon as someone joins, then the rest. Disband the raid in one click.
local W = WLRT
local L = W.L
local db
local DEFAULT = "+1, inv, 123"

W.AddFR({
    ["Invite Tool is now off by default (anyone whispering a keyword got invited). /wl to turn it back on."] =
        "L'Invite Tool est maintenant désactivé par défaut (n'importe qui chuchotant un mot-clé était invité). /wl pour le réactiver.",
    ["Also Battle.net whispers"] = "Aussi les chuchotements Battle.net",
    ["Accept invites suggested by my group (guild members and friends)"] =
        "Accepter les invitations suggérées par mon groupe (membres de guilde et amis)",
    ["The keyword can start a sentence: \"inv please\" works."] = "Le mot-clé peut commencer une phrase : « inv stp » marche.",
    ["Mass invites"] = "Invitations en masse",
    ["Online guild members of these ranks:"] = "Membres de guilde en ligne de ces rangs :",
    ["Invite these ranks"] = "Inviter ces rangs",
    ["Names to invite (comma, space or one per line):"] = "Noms à inviter (virgule, espace ou un par ligne) :",
    ["Names to invite (comma or one per line):"] = "Noms à inviter (virgule ou un par ligne) :",
    ["Invite the list"] = "Inviter la liste",
    ["Disband the raid"] = "Dissoudre le raid",
    ["Disband (keep guild)"] = "Dissoudre (garder la guilde)",
    ["Remove every member from the group?"] = "Retirer tous les membres du groupe ?",
    ["Remove every member who is not in the guild?"] = "Retirer tous les membres hors guilde ?",
    ["You must be the group leader."] = "Tu dois être chef du groupe.",
    ["You must be leader or assistant."] = "Tu dois être chef ou assistant.",
    ["Nobody to invite."] = "Personne à inviter.",
    ["Inviting %d player(s)..."] = "Invitation de %d joueur(s)...",
    ["All invites sent."] = "Toutes les invitations sont envoyées.",
    ["Waiting for a first player to join to convert to raid..."] = "En attente d'un premier joueur pour passer en raid...",
    ["Invites stopped: nobody joined the party."] = "Invitations arrêtées : personne n'a rejoint le groupe.",
    ["A first player joined: convert the party to a raid and invite the %d other(s)?"] =
        "Un premier joueur a rejoint : passer le groupe en raid et inviter les %d autre(s) ?",
    ["Convert to raid"] = "Passer en raid",
    ["Invites stopped: the party could not be converted to a raid. Convert it, then invite again."] =
        "Invitations arrêtées : le groupe n'a pas pu passer en raid. Passe-le en raid, puis invite à nouveau.",
    ["Invites stopped: you are no longer leader or assistant."] = "Invitations arrêtées : tu n'es plus chef ni assistant.",
    ["Suggested invite accepted: %s"] = "Invitation suggérée acceptée : %s",
    ["No guild, or ranks still loading..."] = "Pas de guilde, ou rangs en chargement...",
})

W.OnReady(function()
    db = W.DB("inviteTool", { enabled = false, keyword = DEFAULT, autoRaid = true, guildOnly = false, bnet = true,
        acceptSuggested = false, list = "" })
    if type(db.ranks) ~= "table" then db.ranks = {} end -- rankIndex (0 = guild master) -> true
    -- 1.7.1: was on by default, so the saved "true" is usually not a choice: turn it off once
    if not db.offByDefault then
        db.offByDefault = true
        if db.enabled then
            db.enabled = false
            W.Print(L("Invite Tool is now off by default (anyone whispering a keyword got invited). /wl to turn it back on."))
        end
    end
end)

local function Normalize(s)
    return (s or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
end

-- "inv", "inv please", "inv!" match "inv"; "invite" does not
local function IsKeyword(msg)
    msg = Normalize(msg)
    if msg == "" then return false end
    for kw in (db.keyword or DEFAULT):gmatch("[^,;]+") do
        kw = Normalize(kw)
        if kw ~= "" and msg:sub(1, #kw) == kw then
            local after = msg:sub(#kw + 1, #kw + 1)
            if after == "" or not after:match("[%w\128-\255]") then return true end
        end
    end
    return false
end

local function Invite(name)
    if C_PartyInfo and C_PartyInfo.InviteUnit then
        C_PartyInfo.InviteUnit(name)
    elseif InviteUnit then
        InviteUnit(name)
    end
end

local function ConvertToRaidNow()
    if C_PartyInfo and C_PartyInfo.ConvertToRaid then C_PartyInfo.ConvertToRaid() elseif ConvertToRaid then ConvertToRaid() end
end

local keywordAt, keywordN = {}, 0 -- W.Key(name) -> GetTime() of the last keyword invite; entries
local function InviteFromKeyword(name)
    if db.guildOnly and not W.GuildMember(name) then return end
    -- only when I may invite (alone, leader or assistant), once per 30 s per sender: a stranger whispering the keyword
    -- in a loop must not make us send "suggest invite" popups to our leader
    if W.InGroup() and not W.CanLead() then return end
    local key, now = W.Key(name) or name, GetTime()
    if now - (keywordAt[key] or -1000) < 30 then return end
    if not keywordAt[key] then
        -- many senders: only the ones past their 30 s are forgotten (forgetting them all let 201 senders reset every limit);
        -- 200 senders in 30 s: no invite for a newcomer
        if keywordN >= 200 then
            keywordN = 0
            for k, at in pairs(keywordAt) do
                if now - at >= 30 then keywordAt[k] = nil else keywordN = keywordN + 1 end
            end
            if keywordN >= 200 then return end
        end
        keywordN = keywordN + 1
    end
    keywordAt[key] = now
    -- party full: convert to raid automatically if we are leader, for a guild member only
    if db.autoRaid and not W.InRaid() and W.NumParty() >= 4 and W.IsLeader() and W.GuildMember(name) then ConvertToRaidNow() end
    Invite(name)
end

local whisperEv = W.On("CHAT_MSG_WHISPER", function(msg, sender)
    if not db or not db.enabled or W.Overlap("autoInvite") then return end -- WarLegend v3 already invites
    msg, sender = W.Safe(msg), W.Safe(sender)
    if not sender or sender == "" or not IsKeyword(msg) then return end
    InviteFromKeyword(sender)
end, nil, true)

-- Battle.net whisper: invite the character the friend is playing (same game version only)
local bnEv = W.On("CHAT_MSG_BN_WHISPER", function(...)
    if not db or not db.enabled or not db.bnet then return end
    local msg, bnID = W.Safe((...)), W.Safe((select(13, ...)))
    if not msg or not bnID or not IsKeyword(msg) then return end
    local acc = C_BattleNet and C_BattleNet.GetAccountInfoByID and C_BattleNet.GetAccountInfoByID(bnID)
    local game = acc and acc.gameAccountInfo
    if not game then return end
    local online, name, project, realmName = W.Safe(game.isOnline), W.Safe(game.characterName), W.Safe(game.wowProjectID), W.Safe(game.realmName)
    if not online or not name or name == "" then return end
    if project and WOW_PROJECT_ID and project ~= WOW_PROJECT_ID then return end
    local realm = realmName and realmName:gsub("%s", "") or ""
    local myRealm = (GetRealmName and GetRealmName() or ""):gsub("%s", "")
    if realm ~= "" and realm ~= myRealm then name = name .. "-" .. realm end
    InviteFromKeyword(name)
end, nil, true)

-- A group member suggests someone (or someone asks to join): accept guild members and friends
local confirmEv = W.On("GROUP_INVITE_CONFIRMATION", function()
    if not db or not db.acceptSuggested or not W.IsLeader() then return end
    if not (GetNextPendingInviteConfirmation and GetInviteConfirmationInfo and RespondToInviteConfirmation) then return end
    local id = GetNextPendingInviteConfirmation()
    if not id then return end
    local _, name, guid = GetInviteConfirmationInfo(id)
    name, guid = W.Safe(name), W.Safe(guid)
    -- the GUID decides when the game gives one (a name alone can be a stranger's sharing a guild member's first name)
    local guild
    if guid and IsGuildMember then guild = IsGuildMember(guid) else guild = name and W.GuildMember(name) ~= nil end
    local friend = guid and C_FriendList and C_FriendList.IsFriend and C_FriendList.IsFriend(guid)
    if not (guild or friend) then return end
    RespondToInviteConfirmation(id, true)
    if StaticPopup_Hide then StaticPopup_Hide("GROUP_INVITE_CONFIRMATION", id) end
    W.Print(string.format(L("Suggested invite accepted: %s"), name or "?"))
end, nil, true)

-- whispers and invite confirmations are only listened to when their option is on
local function Watch()
    W.Activate(whisperEv, db and db.enabled)
    W.Activate(bnEv, db and db.enabled and db.bnet)
    W.Activate(confirmEv, db and db.acceptSuggested)
end
W.OnReady(Watch)

---------------------------------------------------------------------------
-- Mass invites: a paced queue
---------------------------------------------------------------------------
local queue = {}
local sentInParty, pumpPending, waitStarted, convertTries, askedConvert = 0, false, 0, 0, false
local WAIT_MAX = 60 -- nobody accepted within this: stop

local Pump
local function Schedule(delay)
    if pumpPending then return end
    pumpPending = true
    W.After(delay, Pump)
end

function Pump()
    pumpPending = false
    if #queue == 0 then return end
    if W.InGroup() and not W.CanLead() then
        wipe(queue)
        W.Print(L("Invites stopped: you are no longer leader or assistant."))
        return
    end
    if W.InRaid() then
        Invite(table.remove(queue, 1))
        if #queue > 0 then Schedule(0.3) else W.Print(L("All invites sent.")) end
        return
    end
    -- party or alone: the party holds 5, so 4 invites, then convert once someone has joined
    if W.NumParty() > 0 and W.IsLeader() then
        -- the conversion is a restricted call (Forever docs, AGENTS.md rule 7): it runs in the player's click on this
        -- question, never from the invite timer (it was retried every second, blocked, forever); the invites go on
        -- once the party is a raid, and stop after 30 s without one
        if not askedConvert then
            askedConvert = true
            W.Confirm(string.format(L("A first player joined: convert the party to a raid and invite the %d other(s)?"), #queue),
                ConvertToRaidNow, L("Convert to raid"))
        end
        convertTries = convertTries + 1
        if convertTries > 30 then
            wipe(queue)
            W.Print(L("Invites stopped: the party could not be converted to a raid. Convert it, then invite again."))
            return
        end
        Schedule(1)
        return
    end
    while sentInParty < 4 and #queue > 0 do
        Invite(table.remove(queue, 1))
        sentInParty = sentInParty + 1
    end
    if #queue == 0 then W.Print(L("All invites sent.")); return end
    if waitStarted == 0 then
        waitStarted = GetTime()
        W.Print(L("Waiting for a first player to join to convert to raid..."))
    elseif GetTime() - waitStarted > WAIT_MAX then
        wipe(queue)
        W.Print(L("Invites stopped: nobody joined the party."))
        return
    end
    Schedule(5) -- safety net; GROUP_ROSTER_UPDATE usually comes first
end

W.OnRoster(function() if #queue > 0 then Schedule(0) end end)

local function InviteMany(names)
    if W.InGroup() and not W.CanLead() then W.Print(L("You must be leader or assistant.")); return end
    wipe(queue)
    local seen, me = {}, (W.UnitFullName("player") or ""):lower()
    local room = 39 - (W.InRaid() and W.NumRaid() - 1 or W.NumParty())
    for _, n in ipairs(names) do
        local key = W.FullName(n):lower() -- full identity: two players can share a first name
        if key ~= me and not seen[key] and not W.UnitByName(n) and #queue < room then
            seen[key] = true
            queue[#queue + 1] = n
        end
    end
    if #queue == 0 then W.Print(L("Nobody to invite.")); return end
    sentInParty, waitStarted, convertTries, askedConvert = 0, 0, 0, false
    W.Print(string.format(L("Inviting %d player(s)..."), #queue))
    Schedule(0)
end
W.InviteMany = InviteMany -- used by the wowaudit import

local function InviteRanks()
    local names = {}
    for _, m in ipairs(W.GuildMembers()) do
        if m.online and m.rankIndex and db.ranks[m.rankIndex] then names[#names + 1] = m.full or m.name end
    end
    InviteMany(names)
end

local function InviteList()
    local names = {}
    for _, n in ipairs(W.NameList(db.list)) do
        n = W.SanitizeName(n)
        if n ~= "" then names[#names + 1] = n end
    end
    InviteMany(names)
end

local function Disband(keepGuild)
    if not W.IsLeader() then W.Print(L("You must be the group leader.")); return end
    W.Confirm(keepGuild and L("Remove every member who is not in the guild?") or L("Remove every member from the group?"), function()
        for _, u in ipairs(W.GroupUnits()) do
            if not W.UnitIsMe(u) then
                -- full name ("First Surname" on Forever): a first name two guild members share is no guild member
                local name = W.UnitFullName(u)
                if name and not (keepGuild and W.GuildMember(name)) then W.Uninvite(name, true) end
            end
        end
    end)
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
local MAX_RANKS = 10

local syncRanks -- the rank boxes of the tab, filled again when the roster arrives
W.RegisterModule("InviteTool", "Invite Tool", function(p)
    W.Title(p, L("Invite Tool"))
    W.Check(p, L("Invite on keyword whisper"), function() return db.enabled end,
        function(v) db.enabled = v; Watch() end):SetPoint("TOPLEFT", 12, -40)
    W.OverlapNote(p, "autoInvite", "TOPLEFT", 300, -46)
    W.Label(p, L("Keywords (comma separated):"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 16, -74)
    local box = W.EditBox(p, 220, 80)
    box:SetPoint("TOPLEFT", 240, -70)
    local function save(self)
        local v = Normalize(self:GetText())
        if v == "" then v = DEFAULT end
        db.keyword = v
        self:SetText(v)
        self:ClearFocus()
    end
    box:SetScript("OnEnterPressed", save)
    box:SetScript("OnEditFocusLost", save)
    box:SetScript("OnShow", function(self) self:SetText(db.keyword or DEFAULT) end)
    local hint = W.Label(p, L("The keyword can start a sentence: \"inv please\" works."), "GameFontHighlightSmall")
    hint:SetPoint("LEFT", box, "RIGHT", 12, 0)
    hint:SetTextColor(0.7, 0.7, 0.7)
    W.Check(p, L("Also Battle.net whispers"), function() return db.bnet end,
        function(v) db.bnet = v; Watch() end):SetPoint("TOPLEFT", 12, -96)
    W.Check(p, L("Convert to raid automatically when the party is full"), function() return db.autoRaid end,
        function(v) db.autoRaid = v end):SetPoint("TOPLEFT", 12, -120)
    W.Check(p, L("Guild members only"), function() return db.guildOnly end,
        function(v) db.guildOnly = v end):SetPoint("TOPLEFT", 12, -144)
    W.Check(p, L("Accept invites suggested by my group (guild members and friends)"), function() return db.acceptSuggested end,
        function(v) db.acceptSuggested = v; Watch() end):SetPoint("TOPLEFT", 12, -174)

    -- Mass invites
    local head = W.Label(p, L("Mass invites"), "GameFontNormal")
    head:SetPoint("TOPLEFT", 14, -212)
    head:SetTextColor(W.R, W.G, W.B)
    W.Label(p, L("Online guild members of these ranks:"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 16, -232)
    local rankChecks = {}
    for i = 1, MAX_RANKS do
        local idx = i - 1 -- roster rank index (0 = guild master)
        local c = W.Check(p, "", function() return db.ranks[idx] end, function(v) db.ranks[idx] = v or nil end)
        c:SetPoint("TOPLEFT", i <= 5 and 12 or 190, -248 - ((i - 1) % 5) * 22)
        rankChecks[i] = c
    end
    local noGuild = W.Label(p, L("No guild, or ranks still loading..."), "GameFontDisableSmall")
    noGuild:SetPoint("TOPLEFT", 16, -252)
    syncRanks = function()
        local n = (W.IsInGuild() and GuildControlGetNumRanks and GuildControlGetNumRanks()) or 0
        for i, c in ipairs(rankChecks) do
            local name = i <= n and GuildControlGetRankName(i)
            c.label:SetText(name or "")
            c:SetShown(name ~= nil and name ~= false and name ~= "")
        end
        noGuild:SetShown(n == 0)
    end
    W.Button(p, L("Invite these ranks"), 170, 22, InviteRanks):SetPoint("TOPLEFT", 400, -250)

    -- Forever: a full name holds a space, so a space separates nothing there (W.NameList)
    W.Label(p, W.FOREVER and L("Names to invite (comma or one per line):") or L("Names to invite (comma, space or one per line):"),
        "GameFontHighlightSmall"):SetPoint("TOPLEFT", 16, -366)
    local listBg, listBox = W.MultiEdit(p, 370, 70, 2000)
    listBg:SetPoint("TOPLEFT", 16, -382)
    listBox:SetScript("OnShow", function(self) self:SetText(db.list or "") end)
    listBox:SetScript("OnTextChanged", function(self) db.list = self:GetText() end)
    W.Button(p, L("Invite the list"), 170, 22, InviteList):SetPoint("TOPLEFT", 400, -382)

    W.Button(p, L("Disband the raid"), 170, 22, function() Disband(false) end):SetPoint("TOPLEFT", 16, -470)
    W.Button(p, L("Disband (keep guild)"), 190, 22, function() Disband(true) end):SetPoint("TOPLEFT", 192, -470)

    p:HookScript("OnShow", function() W.RequestGuildRoster(); syncRanks() end)
    syncRanks()
end)

-- opened while the ranks were still loading: they show once the roster arrives
W.On("GUILD_ROSTER_UPDATE", W.Coalesce(1, function()
    if syncRanks and W.IsShown("InviteTool") then syncRanks() end
end))
