-- WarLegend RaidTool - Layers
-- Which layer (copy of the open world) I am on, and the layers of the guild members. Idea and method from Sashoof's
-- WarLegend v3 addon: the zone part of a creature GUID ("Creature-0-server-instance-zoneUID-npc-spawn") is the same for
-- every creature of one layer. Two different creatures that agree within 30 s confirm it (target, mouseover, nameplates).
-- Shared with the guild (GUILD, prefix WLRT_LAYER). Layer numbers are this computer's aliases per zone (1, 2, 3... in the
-- order they were met), never the server's numbers. Nothing runs in instances, battlegrounds and on a taxi.
local W = WLRT
W.AddFR({
    ["Layers"] = "Layers",
    ["Detect my layer (open world)"] = "Détecter mon layer (monde ouvert)",
    ["Share my layer with the guild"] = "Partager mon layer avec la guilde",
    ["My layer: %s"] = "Mon layer : %s",
    ["Layer %d"] = "Layer %d",
    ["unknown: target or look at two creatures of the zone (nameplates help)"] =
        "inconnu : cible ou survole deux créatures de la zone (les barres de nom aident)",
    ["off in instances, battlegrounds and on a taxi"] = "désactivé en instance, en champ de bataille et en taxi",
    ["Player"] = "Joueur",
    ["Zone"] = "Zone",
    ["Layer"] = "Layer",
    ["Seen"] = "Vu",
    ["Same as me"] = "Comme moi",
    ["%d s"] = "%d s",
    ["%d min"] = "%d min",
    ["%d h"] = "%d h",
    ["(me)"] = "(moi)",
    ["Invite to my layer"] = "Inviter sur mon layer",
    ["Selected: %s"] = "Sélectionné : %s",
    ["Click a player on another layer of my zone, then Invite."] = "Clique un joueur sur un autre layer de ma zone, puis Inviter.",
    ["Invite: not in combat or in an instance."] = "Invitation impossible en combat ou en instance.",
    ["Invite: my layer is unknown."] = "Invitation impossible : mon layer est inconnu.",
    ["Invite: %s is already in my group."] = "Invitation impossible : %s est déjà dans mon groupe.",
    ["Invite: only the leader or an assistant can invite."] = "Invitation impossible : seul le chef ou un assistant peut inviter.",
    ["Invite: %s is not on another layer of my zone."] = "Invitation impossible : %s n'est pas sur un autre layer de ma zone.",
    ["Invite: the reading of %s is older than 5 minutes."] = "Invitation impossible : la lecture de %s date de plus de 5 minutes.",
    ["[WaR LegenD] We are on different layers: I am inviting you to my group, accept to join my layer."] =
        "[WaR LegenD] Nous sommes sur des layers différents : je t'invite dans mon groupe, accepte pour rejoindre mon layer.",
    ["Invitation sent to %s."] = "Invitation envoyée à %s.",
    ["Click: select. Right click: whisper. Layer numbers are given by this computer, zone by zone, in the order the layers were met: they can differ from another player's numbers. A reading older than 5 minutes is grey, gone after one hour."] =
        "Clic : sélectionner. Clic droit : chuchoter. Les numéros de layer sont donnés par cet ordinateur, zone par zone, dans l'ordre où les layers ont été rencontrés : ils peuvent différer de ceux d'un autre joueur. Une lecture de plus de 5 minutes est grise, effacée après une heure.",
    ["Method from Sashoof's WarLegend v3 addon."] = "Méthode reprise de l'addon WarLegend v3 de Sashoof.",
})
local L = W.L
local db

local PREFIX = "WLRT_LAYER"
local CONFIRM_GAP = 30 -- two creatures of the same layer seen within 30 s confirm it
local FRESH = 300      -- older than 5 min: shown in grey
local KEEP = 3600      -- a guild member's reading is forgotten after 1 h
local SHARE_GAP = 120  -- the same layer is sent again at most every 2 min
local MIN_GAP = 10     -- and never two messages within 10 s (zone borders)
local MAX_PER_ZONE = 20
local LOOK_GAP = 2     -- once the layer is known: one creature looked at every 2 s at most (nameplates come in bursts)

local current -- { id = "server-zoneUID", map = mapID, zone = name, at = server time }
-- votes of this zone (wiped on a zone change): creature GUID -> GetTime(), creature GUID -> layer id. Two plain
-- tables instead of one table per creature: nothing is allocated per nameplate.
local voteAt, voteId, voteMap = {}, {}, nil
local lastLook = -1000
local guild = {} -- W.Key(full name) -> { name, full, id, map, zone, at }
local UI = {}
local selected -- full name of the selected row
local WHISPER_GAP = 60 -- one invitation whisper per player per minute
local lastWhisper = {}

W.OnReady(function()
    db = W.DB("layers", { on = true, share = true })
    if type(db.registry) ~= "table" then db.registry = {} end
end)

-- Alias of a layer in a zone: 1, 2, 3... in the order this computer met them
local function Number(map, id)
    local key = tostring(map)
    local zone = db.registry[key]
    if type(zone) ~= "table" then zone = { next = 0, ids = {} }; db.registry[key] = zone end
    local e = zone.ids[id]
    if not e then
        local count, oldest = 0, nil
        for k, v in pairs(zone.ids) do
            count = count + 1
            if not oldest or v.seen < zone.ids[oldest].seen then oldest = k end
        end
        if count >= MAX_PER_ZONE and oldest then zone.ids[oldest] = nil end -- old server restarts
        zone.next = zone.next + 1
        e = { n = zone.next, seen = 0 }
        zone.ids[id] = e
    end
    e.seen = GetServerTime()
    return e.n
end

local function OpenWorld()
    if IsInInstance() then return false end
    return not (UnitOnTaxi and UnitOnTaxi("player"))
end

local function Age(at)
    local s = math.max(0, GetServerTime() - (at or 0))
    if s < 60 then return string.format(L("%d s"), s) end
    if s < 3600 then return string.format(L("%d min"), math.floor(s / 60)) end
    return string.format(L("%d h"), math.floor(s / 3600))
end

local Refresh

---------------------------------------------------------------------------
-- Sharing (GUILD): "1^id^map^time^zone", "?" asks the others to send theirs
---------------------------------------------------------------------------
local lastShare, waiting = -1000, false
local function Share(force)
    if not db.share or not current or not W.IsInGuild() or W.InPvP() then return end
    local now = GetTime()
    if not force and now - lastShare < SHARE_GAP then return end
    if now - lastShare < MIN_GAP then
        if not waiting then
            waiting = true
            W.After(MIN_GAP - (now - lastShare) + 0.1, function() waiting = false; Share(true) end)
        end
        return
    end
    lastShare = now
    W.Send(PREFIX, W.Pack(1, current.id, current.map, current.at, W.Plain(current.zone, 60)), "GUILD")
end

local lastAsk, lastAnswer = -1000, -1000
local function Ask()
    if not db.share or not W.IsInGuild() or GetTime() - lastAsk < 60 then return end
    lastAsk = GetTime()
    W.Send(PREFIX, "?", "GUILD")
end

W.OnAddon(PREFIX, function(msg, name, channel, full)
    if channel ~= "GUILD" or not db or not db.on or #msg > 200 then return end
    if full == W.UnitFullName("player") then return end
    if msg == "?" then
        -- one answer a minute whoever asks: a flood of "?" must not make the whole guild send
        if current and GetServerTime() - current.at < FRESH and GetTime() - lastAnswer >= 60 then
            lastAnswer = GetTime()
            Share(true)
        end
        return
    end
    local f = W.Unpack(msg)
    if f[1] ~= "1" then return end
    local id, map, at = f[2], tonumber(f[3]), W.Finite(f[4])
    if not id or #id > 24 or not id:match("^%d+%-%d+$") or not map or map < 1 or map > 100000 or map % 1 ~= 0 or not at then return end
    local now = GetServerTime()
    if at > now + 60 or now - at > KEEP then return end
    local key = W.Key(full)
    local e = guild[key] -- the same table each time a member sends: no allocation per message
    if not e then e = {}; guild[key] = e end
    e.name, e.full, e.id, e.map, e.at, e.zone = name, full, id, map, math.min(at, now), W.Plain(f[5], 60)
    Number(map, id)
    if UI.panel and UI.panel:IsShown() then Refresh() end
end)

---------------------------------------------------------------------------
-- Detection
---------------------------------------------------------------------------
-- Cost: the events are off in instances and battlegrounds (Apply); in the open world, once the layer is known, one
-- creature every LOOK_GAP seconds, and a creature of the known layer only refreshes its time (no allocation).
local function Observe(unit)
    local now = GetTime()
    if current and now - lastLook < LOOK_GAP then return end
    if UnitOnTaxi and UnitOnTaxi("player") then return end
    local guid = W.Safe(UnitGUID(unit))
    if type(guid) ~= "string" then return end
    local kind, server, zoneUID = guid:match("^(%a+)%-0%-(%d+)%-%d+%-(%d+)%-")
    if kind ~= "Creature" and kind ~= "Vehicle" then return end
    lastLook = now
    local map = C_Map and C_Map.GetBestMapForUnit and W.Safe(C_Map.GetBestMapForUnit("player"))
    if type(map) ~= "number" then return end
    local id = server .. "-" .. zoneUID
    -- the known layer seen again: only its time (and maybe the periodic share)
    if current and current.id == id and current.map == map then
        current.at = GetServerTime()
        Share(false)
        return
    end
    if map ~= voteMap then wipe(voteAt); wipe(voteId); voteMap = map end
    voteAt[guid], voteId[guid] = now, id
    local count = 0
    for g, at in pairs(voteAt) do
        if now - at > CONFIRM_GAP then voteAt[g], voteId[g] = nil, nil
        elseif voteId[g] == id then count = count + 1 end
    end
    if count < 2 then return end
    current = current or {}
    current.id, current.map, current.zone, current.at = id, map, W.Safe(GetRealZoneText()) or "?", GetServerTime()
    Number(map, id)
    Share(true)
    if UI.panel and UI.panel:IsShown() then Refresh() end
end

local evTarget = W.On("PLAYER_TARGET_CHANGED", function() Observe("target") end, nil, true)
local evMouse = W.On("UPDATE_MOUSEOVER_UNIT", function() Observe("mouseover") end, nil, true)
local evPlate = W.On("NAME_PLATE_UNIT_ADDED", function(unit) Observe(unit) end, nil, true)

-- the three events only in the open world (an instance always comes with a loading screen: PLAYER_ENTERING_WORLD)
local function Apply()
    local on = db and db.on and not IsInInstance() and true or false
    W.Activate(evTarget, on)
    W.Activate(evMouse, on)
    W.Activate(evPlate, on)
end

-- a new zone (or a loading screen: maybe another layer) starts over
local function Reset()
    current = nil
    wipe(voteAt); wipe(voteId); voteMap = nil
    lastLook = -1000
    Apply()
    if UI.panel and UI.panel:IsShown() then Refresh() end
end
W.On("PLAYER_ENTERING_WORLD", Reset)
W.On("ZONE_CHANGED_NEW_AREA", Reset)

---------------------------------------------------------------------------
-- Invite a guild member who is on another layer of my zone (the group puts him on my layer)
---------------------------------------------------------------------------
local function Invite(full)
    if C_PartyInfo and C_PartyInfo.InviteUnit then C_PartyInfo.InviteUnit(full)
    elseif InviteUnit then InviteUnit(full) end
end

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
    local e = guild[key]
    local name = e and e.name or selected
    if InCombatLockdown() or IsInInstance() then W.Print(L("Invite: not in combat or in an instance.")); return end
    if not current then W.Print(L("Invite: my layer is unknown.")); return end
    if not e or e.map ~= current.map or e.id == current.id then
        W.Print(string.format(L("Invite: %s is not on another layer of my zone."), name)); return
    end
    if GetServerTime() - e.at > FRESH then
        W.Print(string.format(L("Invite: the reading of %s is older than 5 minutes."), name)); return
    end
    if InGroupWith(key) then W.Print(string.format(L("Invite: %s is already in my group."), name)); return end
    if W.InGroup() and not W.CanLead() then W.Print(L("Invite: only the leader or an assistant can invite.")); return end
    local now = GetTime()
    if now - (lastWhisper[key] or -1000) >= WHISPER_GAP then
        lastWhisper[key] = now
        -- W.SendChat: C_ChatInfo first (the global SendChatMessage is only one of Blizzard's deprecation shims here)
        W.SendChat(L("[WaR LegenD] We are on different layers: I am inviting you to my group, accept to join my layer."), "WHISPER", e.full)
    end
    Invite(e.full)
    W.Print(string.format(L("Invitation sent to %s."), name))
end

---------------------------------------------------------------------------
-- Window tab
---------------------------------------------------------------------------
function Refresh()
    if not UI.panel then return end
    local now = GetServerTime()
    if current then
        UI.mine:SetText(string.format(L("My layer: %s"), string.format(L("Layer %d"), Number(current.map, current.id))
            .. "  |cffaaaaaa" .. W.Plain(current.zone, 60) .. " · " .. Age(current.at) .. "|r"))
    elseif db.on and not OpenWorld() then
        UI.mine:SetText(string.format(L("My layer: %s"), "|cffaaaaaa" .. L("off in instances, battlegrounds and on a taxi") .. "|r"))
    else
        UI.mine:SetText(string.format(L("My layer: %s"), "|cffaaaaaa" .. L("unknown: target or look at two creatures of the zone (nameplates help)") .. "|r"))
    end
    local list = {}
    if current then
        list[#list + 1] = { name = UnitName("player"), full = W.UnitFullName("player"), id = current.id, map = current.map,
            zone = current.zone, at = current.at, me = true }
    end
    for key, e in pairs(guild) do
        if now - e.at > KEEP then guild[key] = nil else list[#list + 1] = e end
    end
    for _, e in ipairs(list) do e.n = Number(e.map, e.id) end -- once per row, not in the sort
    table.sort(list, function(a, b)
        if a.zone ~= b.zone then return a.zone < b.zone end
        if a.n ~= b.n then return a.n < b.n end
        return a.name < b.name
    end)
    local rows = {}
    for _, e in ipairs(list) do
        local m = W.GuildMember(e.full)
        local old = now - e.at > FRESH
        local same = current and not e.me and e.map == current.map and e.id == current.id
        local name = W.ColorName(e.name, m and m.class or (e.me and select(2, UnitClass("player")))) .. (e.me and (" " .. L("(me)")) or "")
        if selected and W.Key(e.full) == W.Key(selected) then name = "|cffffff00> |r" .. name end
        local layer = string.format(L("Layer %d"), e.n)
        rows[#rows + 1] = { full = e.full, me = e.me, cells = {
            name,
            old and ("|cff777777" .. e.zone .. "|r") or e.zone,
            old and ("|cff777777" .. layer .. "|r") or (same and ("|cff55ff55" .. layer .. "|r") or layer),
            same and ("|cff55ff55" .. L("Same as me") .. "|r") or "",
            old and ("|cff777777" .. Age(e.at) .. "|r") or Age(e.at),
        } }
    end
    UI.table:SetData(rows)
    if UI.sel then
        local e = selected and guild[W.Key(selected)]
        UI.sel:SetText(e and string.format(L("Selected: %s"), e.name) or "|cffaaaaaa" .. L("Click a player on another layer of my zone, then Invite.") .. "|r")
        if UI.invite then
            local ok = e and current and e.map == current.map and e.id ~= current.id and GetServerTime() - e.at <= FRESH
            if ok then UI.invite:Enable() else UI.invite:Disable() end
        end
    end
end

W.RegisterModule("Layers", L("Layers"), function(p)
    UI.panel = p
    W.Title(p, L("Layers"))
    W.Check(p, L("Detect my layer (open world)"), function() return db.on end,
        function(v) db.on = v; Reset() end):SetPoint("TOPLEFT", 12, -40)
    W.Check(p, L("Share my layer with the guild"), function() return db.share end,
        function(v) db.share = v; if v then Share(true); Ask() end end):SetPoint("TOPLEFT", 12, -64)
    UI.mine = W.Label(p, "", "GameFontNormal")
    UI.mine:SetPoint("TOPLEFT", 16, -98)
    UI.mine:SetWidth(780)
    UI.mine:SetJustifyH("LEFT")
    UI.table = W.Table(p, { { L("Player"), 220 }, { L("Zone"), 220 }, { L("Layer"), 90, "CENTER" },
        { "", 110, "CENTER" }, { L("Seen"), 80, "CENTER" } }, 360)
    UI.table:SetPoint("TOPLEFT", 10, -124)
    UI.table.onClick = function(d, btn)
        if d.me then return end
        if btn == "RightButton" then
            if ChatFrame_SendTell then ChatFrame_SendTell(d.full) end
        else
            selected = d.full
            Refresh()
        end
    end
    UI.invite = W.Button(p, L("Invite to my layer"), 150, 22, InviteSelected)
    UI.invite:SetPoint("TOPLEFT", 10, -494)
    UI.sel = W.Label(p, "", "GameFontHighlightSmall")
    UI.sel:SetPoint("LEFT", UI.invite, "RIGHT", 10, 0)
    UI.sel:SetWidth(600)
    UI.sel:SetJustifyH("LEFT")
    local hint = W.Label(p, L("Click: select. Right click: whisper. Layer numbers are given by this computer, zone by zone, in the order the layers were met: they can differ from another player's numbers. A reading older than 5 minutes is grey, gone after one hour."),
        "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 16, -522)
    hint:SetWidth(780)
    hint:SetJustifyH("LEFT")
    local credit = W.Label(p, L("Method from Sashoof's WarLegend v3 addon."), "GameFontDisableSmall")
    credit:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -6)
    local acc = 0
    p:SetScript("OnShow", function() acc = 0; Ask(); Refresh() end)
    p:SetScript("OnUpdate", function(_, el)
        acc = acc + el
        if acc >= 5 then acc = 0; Refresh() end
    end)
end, function() Refresh() end)

W.slash.layer = function() W.Toggle("Layers") end
