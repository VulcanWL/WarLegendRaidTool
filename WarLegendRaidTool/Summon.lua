-- WarLegend RaidTool - Summon list (warlock portal / summon)
-- A raid member types the keyword (123) in the raid or party chat: they are added to a small list of the
-- players to summon, unless they are already in the raid's zone (their raid frame says where they are),
-- in which case nothing is added. Players who arrive leave the list by themselves. Display only: it
-- never casts, targets or clicks anything. Cost: the chat events are listened to only while the
-- option is on and you are in a group; the list window exists only once someone asked for a summon.
local W = WLRT
W.AddFR({
    ["Summon list"] = "Liste de summon",
    ["Summon list (type 123 in the raid chat)"] = "Liste de summon (taper 123 dans le chat raid)",
    ["Keyword:"] = "Mot-clé :",
    ["Show the list window by itself when someone asks"] = "Afficher la fenêtre tout seul quand quelqu'un demande",
    ["Say in the raid chat who is added"] = "Écrire dans le chat raid qui est ajouté",
    ["Show the list"] = "Afficher la liste",
    ["Clear the list"] = "Vider la liste",
    ["Summon: %s"] = "Summon : %s",
    ["Nobody to summon"] = "Personne à summon",
    ["Left-click: remove (done) - Right-click: remove"] = "Clic : retirer (fait) - Clic droit : retirer",
    ["%s to summon (not in the zone yet)"] = "%s à summon (pas encore dans la zone)",
    ["%s is already in the zone."] = "%s est déjà dans la zone.",
    ["%s arrived."] = "%s est arrivé.",
    ["Whoever types the keyword in the raid or party chat is added to the list, unless they are already in your zone. Players leave the list when they arrive, or by a click."] =
        "Celui qui écrit le mot-clé dans le chat raid ou groupe est ajouté à la liste, sauf s'il est déjà dans ta zone. Les joueurs quittent la liste à leur arrivée, ou d'un clic.",
    ["Offline"] = "Hors ligne",
    ["Assign 2 clickers"] = "Assigner 2 clickeurs",
    ["Please click the summoning portal!"] = "Clique sur le portail d'invocation s'il te plaît !",
    ["Whisper sent to the clickers:"] = "Chuchotement envoyé aux clickeurs :",
    ["Clickers: %s"] = "Clickeurs : %s",
    ["Not enough players in the zone to click (2 needed)."] = "Pas assez de joueurs dans la zone pour cliquer (2 nécessaires).",
    ["Whisper to the clickers:"] = "Chuchotement aux clickeurs :",
    ["Picks two players who are already in the zone (the ones who clicked the least so far) and whispers them to click the portal."] =
        "Choisit deux joueurs déjà dans la zone (ceux qui ont le moins cliqué jusqu'ici) et leur chuchote de cliquer sur le portail.",
})
local L = W.L
local db
local queue = {}      -- { key, name, class }, in the order they asked
local win, rows = nil, {}
local chatEvs = {}
local MAX_ROWS = 10
local clicks = {} -- key -> how many times this player was asked to click (they take turns)
local AssignClickers -- defined below the list code

W.OnReady(function()
    db = W.DB("summon", { enabled = false, keyword = "123", autoShow = true, say = false, whisper = "" })
    if db.keyword == "" then db.keyword = "123" end
end)

---------------------------------------------------------------------------
-- Where is this player?
---------------------------------------------------------------------------
-- Raid: the zone of the raid frame (GetRaidRosterInfo). Party: nobody gives the zone, so a player the
-- client can see (loaded next to me) counts as here.
local function IsHere(unit)
    if W.UnitIsMe(unit) then return true end
    local mine = W.Safe(GetRealZoneText and GetRealZoneText())
    local idx = tonumber(unit:match("^raid(%d+)$"))
    if idx then
        local zone = W.Safe(select(7, GetRaidRosterInfo(idx)))
        if type(zone) == "string" and type(mine) == "string" and zone ~= "" then
            return zone:lower() == mine:lower()
        end
    end
    return W.Safe(UnitIsVisible(unit)) == true
end

---------------------------------------------------------------------------
-- The list
---------------------------------------------------------------------------
local function Find(key)
    for i, e in ipairs(queue) do if e.key == key then return i end end
end

local function Refresh()
    if not win then return end
    for i = 1, MAX_ROWS do
        local r, e = rows[i], queue[i]
        if e then
            r.data = e
            r.text:SetText(W.ColorName(e.name, e.class))
            r:Show()
        else
            r.data = nil
            r:Hide()
        end
    end
    local n = #queue
    win.more:SetText(n > MAX_ROWS and ("+" .. (n - MAX_ROWS)) or "")
    win.empty:SetShown(n == 0)
    win:SetHeight(86 + math.max(1, math.min(n, MAX_ROWS)) * 18 + (n > MAX_ROWS and 14 or 0))
end

local function BuildWindow()
    if win then return end
    win = W.Window("WLRTSummonList", 220, 100, L("Summon list"))
    win:ClearAllPoints()
    win:SetPoint("RIGHT", UIParent, "RIGHT", -60, 60)
    win:SetFrameStrata("MEDIUM")
    for i = 1, MAX_ROWS do
        local r = CreateFrame("Button", nil, win)
        r:SetSize(196, 18)
        r:SetPoint("TOPLEFT", 12, -34 - (i - 1) * 18)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        W.SetColor(hl, 1, 1, 1, 0.08)
        r.text = W.Label(r, "", "GameFontHighlightSmall")
        r.text:SetPoint("LEFT", 2, 0)
        r:SetScript("OnClick", function(self)
            local e = self.data
            local i2 = e and Find(e.key)
            if i2 then table.remove(queue, i2); Refresh() end
        end)
        r:Hide()
        rows[i] = r
    end
    win.empty = W.Label(win, L("Nobody to summon"), "GameFontDisableSmall")
    win.empty:SetPoint("TOPLEFT", 14, -36)
    win.more = W.Label(win, "", "GameFontNormalSmall")
    win.more:SetPoint("BOTTOMLEFT", 14, 56)
    local tip = W.Label(win, L("Left-click: remove (done) - Right-click: remove"), "GameFontDisableSmall")
    tip:SetPoint("BOTTOMLEFT", 12, 10)
    tip:SetWidth(196)
    local assign = W.Button(win, L("Assign 2 clickers"), 196, 22, function() AssignClickers() end)
    assign:SetPoint("BOTTOMLEFT", 12, 30)
    win:Hide()
end

local function Show()
    BuildWindow()
    Refresh()
    win:Show()
end

-- Players who are in the zone now leave the list
local function Prune()
    local changed = false
    for i = #queue, 1, -1 do
        local unit = W.UnitByName(queue[i].name)
        if not unit then
            table.remove(queue, i); changed = true -- left the group
        elseif IsHere(unit) then
            W.Print(string.format(L("%s arrived."), W.ColorName(queue[i].name, queue[i].class)))
            table.remove(queue, i); changed = true
        end
    end
    if changed then Refresh() end
    return changed
end

-- while the list is not empty: a look every 3 seconds (players arriving), nothing otherwise
local watching = false
local function Watch()
    if watching or #queue == 0 then return end
    watching = true
    local function step()
        if #queue == 0 or not db.enabled or not W.InGroup() or W.IsOff("Summon") then
            watching = false
            if W.IsOff("Summon") and win then win:Hide() end
            return
        end
        Prune()
        W.After(3, step)
    end
    W.After(3, step)
end

---------------------------------------------------------------------------
-- Two players click the portal: picked among those already in the zone, whispered
---------------------------------------------------------------------------
local function WhisperText()
    return (db.whisper and db.whisper ~= "") and db.whisper or L("Please click the summoning portal!")
end

function AssignClickers()
    local list = {}
    for _, u in ipairs(W.GroupUnits()) do
        if not W.UnitIsMe(u) and UnitExists(u) and W.Safe(UnitIsConnected(u)) == true
            and W.Safe(UnitIsDeadOrGhost(u)) ~= true then
            local key = W.UnitKey(u)
            if key and not Find(key) and IsHere(u) then
                list[#list + 1] = { unit = u, key = key, name = W.UnitDisplayName(u) or "?", class = W.UnitClassToken(u) }
            end
        end
    end
    if #list < 2 then W.Print(L("Not enough players in the zone to click (2 needed).")); return end
    -- the two who were asked the least take it, then alphabetical: they take turns
    table.sort(list, function(a, b)
        local ca, cb = clicks[a.key] or 0, clicks[b.key] or 0
        if ca ~= cb then return ca < cb end
        return a.name < b.name
    end)
    local names = {}
    for i = 1, 2 do
        local c = list[i]
        clicks[c.key] = (clicks[c.key] or 0) + 1
        names[i] = c.name
        local target = W.UnitFullName(c.unit) -- "First Surname" on Forever: never another player with that first name
        if target then W.SendChat(WhisperText(), "WHISPER", target) end
        W.Print(L("Whisper sent to the clickers:") .. " " .. W.ColorName(c.name, c.class))
    end
    if db.say and W.Channel() then W.Announce(string.format(L("Clickers: %s"), table.concat(names, ", ")), W.Channel()) end
end

---------------------------------------------------------------------------
-- Chat
---------------------------------------------------------------------------
local function Normalize(s) return ((s or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()) end

-- the names asking for a summon, said in one group line 3 s after the first (40 raiders typing the keyword made 40
-- lines at once)
local sayNames, saying = {}, false
local function SayLater(name)
    sayNames[#sayNames + 1] = name
    if saying then return end
    saying = true
    W.After(3, function()
        saying = false
        local channel = W.Channel()
        if channel and #sayNames > 0 then
            W.Announce(W.CutUTF8(string.format(L("Summon: %s"), table.concat(sayNames, ", ")), 255), channel)
        end
        wipe(sayNames)
    end)
end

local function OnChat(text, sender)
    text, sender = W.Safe(text), W.Safe(sender)
    if type(text) ~= "string" or type(sender) ~= "string" or sender == "" then return end
    if Normalize(text) ~= Normalize(db.keyword) then return end
    local unit = W.UnitByName(sender)
    if not unit or W.UnitIsMe(unit) then return end
    local key = W.UnitKey(unit)
    if not key or Find(key) then return end
    local name = W.UnitDisplayName(unit) or sender
    local class = W.UnitClassToken(unit)
    if IsHere(unit) then
        W.Print(string.format(L("%s is already in the zone."), W.ColorName(name, class)))
        return
    end
    if #queue >= 40 then return end
    queue[#queue + 1] = { key = key, name = name, class = class }
    W.Print(string.format(L("%s to summon (not in the zone yet)"), W.ColorName(name, class)))
    if db.say and W.Channel() then SayLater(name) end
    if db.autoShow then Show() else Refresh() end
    Watch()
end

local function SyncEvents()
    local on = db and db.enabled and W.InGroup()
    for _, h in ipairs(chatEvs) do W.Activate(h, on and true or false) end
    if not on then wipe(queue); Refresh() end
end

for _, ev in ipairs({ "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER" }) do
    chatEvs[#chatEvs + 1] = W.On(ev, OnChat, nil, true)
end
W.OnRoster(SyncEvents)
W.On("PLAYER_ENTERING_WORLD", function() SyncEvents(); Prune() end)

W.slash.summon = function() Show() end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
W.RegisterModule("Summon", "Summon list", function(p)
    W.Title(p, L("Summon list"))
    W.Check(p, L("Summon list (type 123 in the raid chat)"), function() return db.enabled end,
        function(v) db.enabled = v; SyncEvents() end):SetPoint("TOPLEFT", 12, -40)
    W.Label(p, L("Keyword:"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 16, -78)
    local box = W.EditBox(p, 120, 20)
    box:SetPoint("TOPLEFT", 80, -74)
    local function save(self)
        local v = Normalize(self:GetText())
        if v == "" then v = "123" end
        db.keyword = v
        self:SetText(v)
        self:ClearFocus()
    end
    box:SetScript("OnEnterPressed", save)
    box:SetScript("OnEditFocusLost", save)
    box:SetScript("OnShow", function(self) self:SetText(db.keyword or "123") end)
    W.Check(p, L("Show the list window by itself when someone asks"), function() return db.autoShow end,
        function(v) db.autoShow = v end):SetPoint("TOPLEFT", 12, -104)
    W.Check(p, L("Say in the raid chat who is added"), function() return db.say end,
        function(v) db.say = v end):SetPoint("TOPLEFT", 12, -130)
    W.Button(p, L("Show the list"), 150, 22, Show):SetPoint("TOPLEFT", 16, -166)
    W.Button(p, L("Clear the list"), 150, 22, function() wipe(queue); Refresh() end):SetPoint("TOPLEFT", 176, -166)
    W.Label(p, L("Whisper to the clickers:"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 16, -204)
    local wbox = W.EditBox(p, 420, 120)
    wbox:SetPoint("TOPLEFT", 190, -200)
    local function saveWhisper(self)
        local t = self:GetText()
        db.whisper = (t == L("Please click the summoning portal!")) and "" or t -- the default follows the language
    end
    wbox:SetScript("OnEnterPressed", function(self) saveWhisper(self); self:ClearFocus() end)
    wbox:SetScript("OnEditFocusLost", saveWhisper)
    wbox:SetScript("OnShow", function(self) self:SetText(WhisperText()) end)
    W.Button(p, L("Assign 2 clickers"), 180, 22, function() AssignClickers() end, { L("Picks two players who are already in the zone (the ones who clicked the least so far) and whispers them to click the portal.") }):SetPoint("TOPLEFT", 16, -236)
    local info = W.Label(p, L("Whoever types the keyword in the raid or party chat is added to the list, unless they are already in your zone. Players leave the list when they arrive, or by a click."),
        "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, -276)
    info:SetWidth(700)
    info:SetJustifyH("LEFT")
    info:SetTextColor(0.7, 0.7, 0.7)
end)
