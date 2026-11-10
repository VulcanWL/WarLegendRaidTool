-- WarLegend RaidTool - Layers
-- Which layer (copy of the open world) I am on, and the layers of the guild members. Idea and method from Sashoof's
-- WarLegend v3 addon: the zone part of a creature GUID ("Creature-0-server-instance-zoneUID-npc-spawn") is the same for
-- every creature of one layer. Two different creatures that agree within 30 s confirm it (target, mouseover, nameplates).
-- Shared with the guild (GUILD, prefix WLRT_LAYER). The number shown is the zone part itself: the game's own number for
-- that layer, the same on every computer (the raw id Forever Layer Hop and Overlord show too). Forever layers are per
-- zone and come and go with the crowd, so the old aliases "in the order this computer met them" reached "Layer 70" in
-- Durotar within two days. Blizzard's SHARD_TRANSFER events (the "moving you to another layer" toast) restart the
-- detection. Since launch a group does not move anyone at once: joining (or leaving) one starts the game's countdown
-- notice, and the move happens when it ends or when the player presses its Refresh Now (also a button here, on click).
-- Ask LayerSwap hosts (Forever, on click): LayerSwap's request to the players of my zone, see its section below.
-- Nothing runs in instances, battlegrounds and on a taxi.
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
    ["[WaR LegenD] We are on different layers: I am inviting you to my group. Accept, then press Refresh Now on the game's layer notice (or wait for its countdown) to come to my layer."] =
        "[WaR LegenD] Nous sommes sur des layers différents : je t'invite dans mon groupe. Accepte, puis valide l'avis de changement de layer du jeu (ou attends son compte à rebours) pour venir sur mon layer.",
    ["Invitation sent to %s."] = "Invitation envoyée à %s.",
    ["%s must accept, then press Refresh Now on the game's notice (or wait for its countdown, about 5 min)."] =
        "%s doit accepter, puis valider l'avis de changement de layer du jeu (ou attendre son compte à rebours, environ 5 min).",
    ["Change layer now"] = "Changer de layer maintenant",
    ["Same as Refresh Now on the game's notice: moves me now instead of at the end of the countdown. Not in combat."] =
        "Comme le bouton de l'avis du jeu : me change de layer tout de suite au lieu de la fin du compte à rebours. Pas en combat.",
    ["Change layer: not in combat."] = "Changement de layer impossible en combat.",
    ["The game will move me to another layer in %s: press Refresh Now on its notice (or Change layer now in /wl layer) to move at once, out of combat."] =
        "Le jeu va me changer de layer dans %s : valide son avis (ou Changer de layer maintenant dans /wl layer) pour changer tout de suite, hors combat.",
    ["Click: select. Right click: whisper."] = "Clic : sélectionner. Clic droit : chuchoter.",
    ["The layer number is the game's own number for this copy of the zone, read on the creatures around you: the same for every player on that layer. Layers open and close with the crowd, so the numbers change over time. To change layer: a player on the other layer invites you, you accept, then press Refresh Now on the game's notice (or wait for its countdown), out of combat. Stay in the group: leaving it starts a new countdown. A reading older than 5 minutes is grey, gone after one hour."] =
        "Le numéro de layer est celui du jeu pour cette copie de la zone, lu sur les créatures autour de toi : le même pour tous les joueurs de ce layer. Les layers s'ouvrent et se ferment avec l'affluence, donc les numéros changent avec le temps. Pour changer de layer : un joueur de l'autre layer t'invite, tu acceptes, puis tu valides l'avis du jeu (ou tu attends son compte à rebours), hors combat. Reste dans le groupe : le quitter relance un compte à rebours. Une lecture de plus de 5 minutes est grise, effacée après une heure.",
    ["the game moves me to another layer in %s"] = "le jeu me change de layer dans %s",
    ["the game moves me to another layer any moment"] = "le jeu me change de layer d'un instant à l'autre",
    ["Method from Sashoof's WarLegend v3 addon."] = "Méthode reprise de l'addon WarLegend v3 de Sashoof.",
    ["Ask LayerSwap hosts"] = "Demander aux hôtes LayerSwap",
    ["Stop asking"] = "Arrêter la demande",
    ["Asks the players of my zone, out of sight, for an invite from another layer: the request of the LayerSwap addon, which its users with Host on answer with an invite."] =
        "Demande en privé aux joueurs de ma zone une invitation depuis un autre layer : la demande de l'addon LayerSwap, à laquelle ses utilisateurs avec Host activé répondent par une invitation.",
    ["The game's player search (/who) opens with the list of the players asked: 40 at most, 8 at once then one a second, one search every 30 s; in a busy zone each search after the first covers one class. The hosts that answered before are asked first."] =
        "La recherche de joueurs du jeu (/who) s'ouvre avec la liste des joueurs sollicités : 40 au plus, 8 d'un coup puis un par seconde, une recherche toutes les 30 s ; dans une zone peuplée, chaque recherche après la première couvre une classe. Les hôtes qui ont déjà répondu sont sollicités en premier.",
    ["My place on the zone map goes with the ask (LayerSwap's format: a host that skips askers near it reads it). The answers show next to the button: how many LayerSwap users heard me, how many host on another layer."] =
        "Ma position sur la carte de la zone part avec la demande (format de LayerSwap : un hôte qui ignore les demandeurs proches la lit). Les réponses s'affichent à côté du bouton : combien d'utilisateurs de LayerSwap l'ont reçue, combien hébergent sur un autre layer.",
    ["%d heard, %d hosting on another layer"] = "%d l'ont reçue, %d hôtes sur un autre layer",
    ["Ask LayerSwap hosts: nobody of this search's class in my zone, click again for the next class."] =
        "Demande aux hôtes LayerSwap : personne de la classe de cette recherche dans ma zone, clique encore pour la classe suivante.",
    ["No invite after asking %d players: none of them answered with LayerSwap. Try again later (in a busy zone, the next search covers another class)."] =
        "Aucune invitation après %d joueurs sollicités : aucun n'a répondu avec LayerSwap. Réessaie plus tard (dans une zone peuplée, la recherche suivante couvre une autre classe).",
    ["No invite: %d LayerSwap users heard me, none of them hosting on another layer of this zone. Try again later, or in a busier zone."] =
        "Aucune invitation : %d utilisateurs de LayerSwap ont reçu la demande, aucun n'héberge sur un autre layer de cette zone. Réessaie plus tard, ou dans une zone plus peuplée.",
    ["No invite: %d LayerSwap hosts on another layer heard me but none invited (busy, or a full group). Try again in a moment."] =
        "Aucune invitation : %d hôtes LayerSwap d'un autre layer ont reçu la demande sans inviter (occupés ou groupe plein). Réessaie dans un instant.",
    ["%s is a LayerSwap host on my own layer: accepting changes nothing. Decline, then ask again."] =
        "%s est un hôte LayerSwap de mon propre layer : accepter ne change rien. Refuse, puis redemande.",
    ["No layer move announced %d s after joining the group of %s: the host may be on my layer or in another zone. Leave this group in /wl layer, then ask again."] =
        "Aucun changement de layer annoncé %d s après avoir rejoint le groupe de %s : l'hôte est peut-être sur mon layer ou dans une autre zone. Quitte ce groupe dans /wl layer, puis redemande.",
    ["Leave this group"] = "Quitter ce groupe",
    ["No layer move was announced after joining this group from a LayerSwap ask: the host may stand on my layer or in another zone. Leaves the group; then ask again."] =
        "Aucun changement de layer annoncé après avoir rejoint ce groupe depuis une demande LayerSwap : l'hôte est peut-être sur mon layer ou dans une autre zone. Quitte le groupe ; redemande ensuite.",
    ["Then accept the invite, press Refresh Now on the game's notice (or Change layer now) and stay in the group. Out of a group, with my layer known."] =
        "Ensuite, accepte l'invitation, valide l'avis du jeu (ou Changer de layer maintenant) et reste dans le groupe. Hors groupe, avec mon layer connu.",
    ["searching my zone..."] = "recherche dans ma zone...",
    ["%d of %d players asked..."] = "%d joueurs sur %d sollicités...",
    ["%d players asked, waiting for an invite..."] = "%d joueurs sollicités, en attente d'une invitation...",
    ["Ask LayerSwap hosts: stopped."] = "Demande aux hôtes LayerSwap arrêtée.",
    ["Ask LayerSwap hosts: the player search is not available."] =
        "Demande aux hôtes LayerSwap : la recherche de joueurs n'est pas disponible.",
    ["Ask LayerSwap hosts: not in combat, in an instance or on a taxi."] =
        "Demande aux hôtes LayerSwap impossible en combat, en instance ou en taxi.",
    ["Ask LayerSwap hosts: leave your group first (a host cannot invite a player who is in a group)."] =
        "Demande aux hôtes LayerSwap : quitte d'abord ton groupe (un hôte ne peut pas inviter un joueur déjà groupé).",
    ["Ask LayerSwap hosts: my layer is unknown, look at two creatures of the zone first (a host on my own layer must stay out)."] =
        "Demande aux hôtes LayerSwap : mon layer est inconnu, regarde d'abord deux créatures de la zone (un hôte de mon propre layer doit rester à l'écart).",
    ["Ask LayerSwap hosts: one search every 30 s, again in %d s."] =
        "Demande aux hôtes LayerSwap : une recherche toutes les 30 s, encore %d s.",
    ["Ask LayerSwap hosts: my zone is unknown."] = "Demande aux hôtes LayerSwap : ma zone est inconnue.",
    ["Ask LayerSwap hosts: the game refused the player search."] =
        "Demande aux hôtes LayerSwap : le jeu a refusé la recherche de joueurs.",
    ["Ask LayerSwap hosts: the player search got no answer, try again in a moment."] =
        "Demande aux hôtes LayerSwap : la recherche de joueurs n'a pas répondu, réessaie dans un instant.",
    ["Ask LayerSwap hosts: the search found nobody else in my zone."] =
        "Demande aux hôtes LayerSwap : la recherche n'a trouvé personne d'autre dans ma zone.",
    ["Ask LayerSwap hosts: the game refused or held back the addon whispers, try again in a minute."] =
        "Demande aux hôtes LayerSwap : le jeu a refusé ou retenu les messages d'addon, réessaie dans une minute.",
    ["%s invited me: if it is a LayerSwap host, accept, then press Refresh Now on the game's notice (or Change layer now in /wl layer) and stay in the group (leaving it moves me again)."] =
        "%s m'invite : si c'est un hôte LayerSwap, accepte, puis valide l'avis du jeu (ou Changer de layer maintenant dans /wl layer) et reste dans le groupe (le quitter me fait changer de layer à nouveau).",
})
local L = W.L
local db

local PREFIX = "WLRT_LAYER"
local CONFIRM_GAP = 30 -- two creatures of the same layer seen within 30 s confirm it
local FRESH = 300      -- older than 5 min: shown in grey
local KEEP = 3600      -- a guild member's reading is forgotten after 1 h
local SHARE_GAP = 120  -- the same layer is sent again at most every 2 min
local MIN_GAP = 10     -- and never two messages within 10 s (zone borders)
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
local invitedAt = {} -- W.Key(full name) -> GetTime() of my invitation: their new readings go to the log for 15 min
local MAX_LOG = 80

-- What happens around a layer move (my readings, loading screens and zones, group joins / leaves, the game's
-- announcements, my invitations and the invited players' readings) in the saved file (layers.log, the last 80 lines):
-- read after a /reload to see why a group did or did not move someone. Short fields only: ids are digits, names and
-- zones are bounded.
local function Log(msg)
    if not db then return end
    if type(db.log) ~= "table" then db.log = {} end
    local log = db.log
    log[#log + 1] = date("%H:%M:%S") .. " " .. msg
    while #log > MAX_LOG do table.remove(log, 1) end
end
local function Mine() return current and current.id or "?" end

W.OnReady(function()
    db = W.DB("layers", { on = true, share = true })
    db.registry = nil -- the old per-zone aliases (up to 300 zones x 20 layers): no longer used
end)

-- The number shown for a layer id ("server-zoneUID", digits only: checked on receive, matched on the GUID): the zone
-- part, the game's own number for that layer
local function Number(id)
    return tonumber(id:match("%-(%d+)$")) or 0
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
            W.After(1 + math.random() * 8, function() Share(true) end) -- the whole guild hears "?": answers spread out
        end
        return
    end
    local f = W.Unpack(msg)
    if f[1] ~= "1" then return end
    local id, map, at = f[2], tonumber(f[3]), W.Finite(f[4])
    if not id or #id > 24 or not id:match("^%d+%-%d+$") or not map or map < 1 or map > 100000 or map % 1 ~= 0 or not at then return end
    if C_Map and C_Map.GetMapInfo and not C_Map.GetMapInfo(map) then return end -- a map this client does not know
    local now = GetServerTime()
    if at > now + 60 or now - at > KEEP then return end
    local key = W.Key(full)
    local e = guild[key] -- the same table each time a member sends: no allocation per message
    if not e then e = {}; guild[key] = e end
    local was = e.id
    e.name, e.full, e.id, e.map, e.at, e.zone = name, full, id, map, math.min(at, now), W.Plain(f[5], 60)
    if was ~= id and invitedAt[key] and GetTime() - invitedAt[key] < 900 then
        Log("reading " .. W.Plain(name, 40) .. " " .. id .. " map " .. map .. " (mine " .. Mine() .. ")")
    end
    if UI.panel and UI.panel:IsVisible() then Refresh() end
end)

-- For the other modules (Leveling): a guild member's layer number (the game's), and whether it is mine (same zone and
-- layer); nil when unknown or older than 5 minutes.
function W.GuildLayer(full)
    local e = guild[W.Key(full)]
    if not e or GetServerTime() - e.at > FRESH then return nil end
    return Number(e.id), current and e.map == current.map and e.id == current.id or false
end

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
    Log("mine " .. id .. " map " .. map .. " " .. W.Plain(current.zone, 40))
    Share(true)
    if UI.panel and UI.panel:IsVisible() then Refresh() end
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
    if UI.panel and UI.panel:IsVisible() then Refresh() end
end
W.On("PLAYER_ENTERING_WORLD", function() Log("loading screen (was " .. Mine() .. ")"); Reset() end)
W.On("ZONE_CHANGED_NEW_AREA", function() Log("zone " .. W.Plain(W.Safe(GetRealZoneText()) or "?", 40) .. " (was " .. Mine() .. ")"); Reset() end)
local function GroupState()
    if not W.InGroup() then return "solo" end
    return (UnitIsGroupLeader and UnitIsGroupLeader("player")) and "leader" or "member"
end
W.On("GROUP_JOINED", function() Log("group joined, " .. GroupState() .. " (mine " .. Mine() .. ")") end)
W.On("GROUP_LEFT", function() Log("group left (mine " .. Mine() .. ")") end)

-- Blizzard's layer moves (System events of the Forever build, the client's "moving you to another layer" toast):
-- IMMINENT starts the countdown (GetEvictionTimeRemaining, seconds) when I join a group (to the group's layer) or leave
-- one (where the server chooses), CANCELLED stops it, SHARD_TRANSFER is the move itself: my reading is wrong from then
-- on, the detection starts over. One chat line per announcement (a raid's roster changes can announce again).
local moveAt -- GetTime() of the announced move, nil when none
-- how: "announced" (the event) or "already scheduled" (found when the world loads)
local function Announce(left, how)
    left = (type(left) == "number" and left > 0) and left or 0
    local announced = moveAt ~= nil
    moveAt = GetTime() + left
    if not announced then Log(string.format("game: move %s in %d s, %s (mine %s)", how, math.ceil(left), GroupState(), Mine())) end
    if not announced and db and db.on then
        local t = left < 60 and string.format(L("%d s"), math.ceil(left)) or string.format(L("%d min"), math.ceil(left / 60))
        W.Print(string.format(L("The game will move me to another layer in %s: press Refresh Now on its notice (or Change layer now in /wl layer) to move at once, out of combat."), t))
    end
    if UI.panel and UI.panel:IsVisible() then Refresh() end
end
W.On("SHARD_TRANSFER_IMMINENT", function()
    Announce(GetEvictionTimeRemaining and W.Safe(GetEvictionTimeRemaining()), "announced")
end)
-- Build 70840: Blizzard's notice now also shows a move scheduled before the UI loaded (a /reload or a loading screen
-- during the countdown, when IMMINENT came before us); so does the tab
W.On("PLAYER_ENTERING_WORLD", function()
    local left = GetEvictionTimeRemaining and W.Safe(GetEvictionTimeRemaining())
    if not moveAt and type(left) == "number" and left > 0 then Announce(left, "already scheduled") end
end)
W.On("SHARD_TRANSFER_CANCELLED", function()
    Log("game: move cancelled (mine " .. Mine() .. ")")
    moveAt = nil
    if UI.panel and UI.panel:IsVisible() then Refresh() end
end)
W.On("SHARD_TRANSFER", function() Log("game: moved (was " .. Mine() .. ")"); moveAt = nil; Reset() end)

local function MoveText()
    if not moveAt then return "" end
    local left = math.ceil(moveAt - GetTime())
    if left <= 0 then return "  |cffff8800" .. L("the game moves me to another layer any moment") .. "|r" end
    local t = left < 60 and string.format(L("%d s"), left) or string.format(L("%d min"), math.ceil(left / 60))
    return "  |cffff8800" .. string.format(L("the game moves me to another layer in %s"), t) .. "|r"
end

-- The button of the tab: the same call as Refresh Now on Blizzard's notice (GameDialogDefs), only on the player's click
local function CanMoveNow()
    return moveAt ~= nil and C_PlayerInteractionManager and C_PlayerInteractionManager.ShardTransferConfirm and true or false
end
local function MoveNow()
    if not CanMoveNow() then return end
    if InCombatLockdown() or UnitAffectingCombat("player") then W.Print(L("Change layer: not in combat.")); return end
    Log("Change layer now clicked (mine " .. Mine() .. ")")
    C_PlayerInteractionManager.ShardTransferConfirm()
end

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
    local name = e and ((W.FOREVER and e.full) or e.name) or selected
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
        W.SendChat(L("[WaR LegenD] We are on different layers: I am inviting you to my group. Accept, then press Refresh Now on the game's layer notice (or wait for its countdown) to come to my layer."), "WHISPER", e.full)
    end
    Invite(e.full)
    invitedAt[key] = now
    Log("invite " .. W.Plain(name, 40) .. " theirs " .. e.id .. " mine " .. current.id .. ", " .. GroupState())
    W.Print(string.format(L("Invitation sent to %s."), name))
    W.Print(string.format(L("%s must accept, then press Refresh Now on the game's notice (or wait for its countdown, about 5 min)."), name))
end

---------------------------------------------------------------------------
-- Ask LayerSwap hosts (WoW Forever). Players who run the LayerSwap addon (Adam5288, CurseForge) with Host on invite whoever
-- asks them; the live realms refuse an addon's chat lines, so LayerSwap asks by hidden addon whisper: its click asks the
-- game who stands in the zone (/who with the group finder's map filter), then sends each of them its request line. Ours
-- does the same on the player's click: one search (SendWho has restrictions: in the click only), then the line
-- "inv layer <LS zoneMap not myLayer x,y>" (prefix "LayerSwap", the format of LayerSwap 1.14.10; x,y = my place on the zone
-- map in percent, for a host that skips askers near it) to at most 40 players of the zone, through the client's throttle.
-- A host on another layer of that zone invites; one on my layer or in another zone stays out. As LayerSwap does: in a busy
-- zone (the search's 50 names full) each click after one on every class asks one class; the hosts that answered before
-- are asked first. Their answers ("heard", "same") are read while the ask is out, from the players it went to only (Core:
-- TRUST "ask"): counts for the status, the hosts for that list; nothing is sent back. Only the wire format is LayerSwap's,
-- the code is ours. Nothing here invites or accepts: the invite is the game's own window, then Change layer now. LayerSwap
-- leaves a host's group by itself when nothing moved; here a Leave this group button (a click) shows instead, never during
-- the game's countdown (leaving then cancels the move). The search opens the game's who list when the group finder is
-- loaded (LFGWhoListMixin:UpdateWhoList): left as it is, Blizzard's frames are not touched. LayerSwap changes its format
-- often and its page refuses scripts (no deps-watch): STATUS.md says what to read again in each new version.
---------------------------------------------------------------------------
local LS_PREFIX = "LayerSwap"
-- BURST lines at once, then one a second (the client's own budget for an addon message per prefix). GAP between two
-- searches, RETRY after one that found nobody or got no answer, INVITE_WAIT after the last line. JOIN_WAIT: a group
-- joined from an ask and no layer move announced by then: the Leave button. CLASSES: Forever's (LayerSwap's rotation),
-- round 0 = every class; crowded: the last search on every class was full, in the zone crowdedMap. The book of hosts:
-- BOOK_DAYS, BOOK_MAX.
-- invite: { at, name, key, guid } of an invite that came during my ask; joined: the same once I joined that group.
local LS = { MAX = 40, BURST = 8, ROUNDS = 45, WHO_WAIT = 5, INVITE_WAIT = 60, GAP = 30, RETRY = 15, JOIN_WAIT = 15,
    BOOK_DAYS = 7, BOOK_MAX = 150, CLASSES = { 1, 2, 3, 4, 5, 7, 8, 9, 11 }, round = 0, crowded = false, last = -1000 }
-- the ask under way: { state = "search" | "send" | "wait", from (my layer id), zone, zoneName, cls, line, names, asked
-- (key -> true once sent), replies (key -> { host, other, same }), n, sent, failed, rounds }
local ask
local ZONE_TYPE = (Enum and Enum.UIMapType and Enum.UIMapType.Zone) or 3

-- The zone's map, as LayerSwap compares it (a cave or a town map climbs to its zone); the map itself when the climb fails
local function ZoneMap()
    local id = C_Map and C_Map.GetBestMapForUnit and W.Safe(C_Map.GetBestMapForUnit("player"))
    if type(id) ~= "number" or id <= 0 or not C_Map.GetMapInfo then return nil end
    local m = id
    for _ = 1, 6 do
        local info = C_Map.GetMapInfo(m)
        local t = type(info) == "table" and W.Safe(info.mapType)
        if type(t) ~= "number" then break end
        if t == ZONE_TYPE then return m end
        local up = W.Safe(info.parentMapID)
        if t < ZONE_TYPE or type(up) ~= "number" or up <= 0 then break end
        m = up
    end
    return id
end

-- My place on the zone map as LayerSwap writes it ("48.2,42.5", percent, one decimal); nil when the game does not say
local function MapSpot(zone)
    if not (C_Map and C_Map.GetPlayerMapPosition) then return nil end
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, zone, "player")
    pos = ok and W.Safe(pos)
    if type(pos) ~= "table" then return nil end
    local x, y
    if pos.GetXY then x, y = pos:GetXY() else x, y = pos.x, pos.y end
    x, y = W.Safe(x), W.Safe(y)
    if type(x) ~= "number" or type(y) ~= "number" or x < 0 or x > 1 or y < 0 or y > 1 then return nil end
    return string.format("%.1f,%.1f", x * 100, y * 100)
end

-- The who answer goes to the window (not the chat) while ours waits; back to the chat after it unless a who list is open
local function WhoToUi(on)
    if not (C_FriendList and C_FriendList.SetWhoToUi) then return end
    if not on then
        for _, name in ipairs({ "LFGWhoListFrame", "WhoFrame" }) do
            local f = _G[name]
            if type(f) == "table" and f.IsVisible and f:IsVisible() then return end
        end
    end
    pcall(C_FriendList.SetWhoToUi, on)
end

-- The book: hosts that answered my asks (W.Key -> time()), saved as data (not an option), bounded on each write and at login
local function BookAdd(key)
    if type(db.lsHosts) ~= "table" then db.lsHosts = {} end
    local book = db.lsHosts
    if not book[key] then
        local n, oldKey, oldAt = 0, nil, nil
        for k, at in pairs(book) do
            n = n + 1
            if not oldAt or at < oldAt then oldKey, oldAt = k, at end
        end
        if n >= LS.BOOK_MAX and oldKey then book[oldKey] = nil end
    end
    book[key] = time()
end
W.OnReady(function()
    if type(db.lsHosts) ~= "table" then return end
    local cut = time() - LS.BOOK_DAYS * 86400
    for k, at in pairs(db.lsHosts) do
        if type(k) ~= "string" or #k > 60 or type(at) ~= "number" or at < cut then db.lsHosts[k] = nil end
    end
end)

-- The answers: LayerSwap users who heard me, those hosting on another layer of my zone, those hosting on my own layer
local function Counts(p)
    local heard, other, same = 0, 0, 0
    for _, r in pairs(p.replies) do
        heard = heard + 1
        if r.other then other = other + 1 end
        if r.same then same = same + 1 end
    end
    return heard, other, same
end

local evWho
local function EndAsk(why, text)
    if not ask then return end
    local heard, other = Counts(ask)
    Log("LayerSwap ask " .. why .. ", " .. ask.sent .. " sent, " .. heard .. " heard, " .. other .. " hosts elsewhere")
    if ask.state == "search" then WhoToUi(false) end
    ask = nil
    W.Activate(evWho, false)
    if text then W.Print(text) end
    if UI.askBtn then UI.askBtn:SetText(L("Ask LayerSwap hosts")) end
    if UI.panel and UI.panel:IsVisible() then Refresh() end
end

local function AskText()
    if not ask then return "" end
    local t
    if ask.state == "search" then t = L("searching my zone...")
    elseif ask.state == "send" then t = string.format(L("%d of %d players asked..."), ask.sent, #ask.names)
    else t = string.format(L("%d players asked, waiting for an invite..."), ask.sent) end
    local heard, other = Counts(ask)
    if heard > 0 then t = t .. "  " .. string.format(L("%d heard, %d hosting on another layer"), heard, other) end
    return "|cff88ccffLayerSwap|r " .. t
end

-- The ask over without an invite: what the answers say, so nobody waits for nothing
local function NoInvite(p)
    local heard, other = Counts(p)
    if heard == 0 then
        EndAsk("no invite", string.format(L("No invite after asking %d players: none of them answered with LayerSwap. Try again later (in a busy zone, the next search covers another class)."), p.sent))
    elseif other == 0 then
        EndAsk("no invite", string.format(L("No invite: %d LayerSwap users heard me, none of them hosting on another layer of this zone. Try again later, or in a busier zone."), heard))
    else
        EndAsk("no invite", string.format(L("No invite: %d LayerSwap hosts on another layer heard me but none invited (busy, or a full group). Try again in a moment."), other))
    end
end

-- One round a second: BURST lines in the first, one in each after it; a line the client holds back (throttle) waits for
-- the next round. The module switched off, or my layer no longer the one the line leaves: nothing more goes out
local function SendRound(p)
    if ask ~= p or p.state ~= "send" then return end
    if W.IsOff("Layers") or not current or current.id ~= p.from then EndAsk("moved"); return end
    p.rounds = p.rounds + 1
    local n = 0
    while p.n <= #p.names and n < (p.rounds == 1 and LS.BURST or 1) do
        local name = p.names[p.n]
        local res = W.SendRaw(LS_PREFIX, p.line, "WHISPER", name)
        if res == "throttle" then break end
        p.n, n = p.n + 1, n + 1
        if res == "sent" then
            p.sent = p.sent + 1
            p.asked[W.Key(name)] = true
        else
            p.failed = p.failed + 1
        end
    end
    if p.n <= #p.names and p.rounds < LS.ROUNDS then
        W.After(1, function() SendRound(p) end)
    elseif p.sent == 0 then
        EndAsk("refused", L("Ask LayerSwap hosts: the game refused or held back the addon whispers, try again in a minute."))
        return
    else
        p.state = "wait"
        Log("LayerSwap ask: " .. p.sent .. " asked, " .. p.failed .. " refused")
        W.After(LS.INVITE_WAIT, function()
            if ask == p and W.IsOff("Layers") then EndAsk("off")
            elseif ask == p then NoInvite(p) end
        end)
    end
    if UI.panel and UI.panel:IsVisible() then Refresh() end
end

-- The game's answer to our search: the players of my zone (not me), the hosts of the book first, 40 at most, then the
-- rounds
evWho = W.On("WHO_LIST_UPDATE", function()
    local p = ask
    if not p or p.state ~= "search" then return end
    WhoToUi(false)
    local n, total = C_FriendList.GetNumWhoResults()
    n, total = W.Safe(n), W.Safe(total)
    n = type(n) == "number" and n or 0
    if not p.cls then LS.crowded, LS.crowdedMap = type(total) == "number" and total >= 50, p.zone end
    local me = W.UnitKey("player")
    local book = type(db.lsHosts) == "table" and db.lsHosts or {}
    local seen, known, rest = {}, {}, {}
    for i = 1, math.min(n, 50) do
        local info = C_FriendList.GetWhoInfo(i)
        local full = type(info) == "table" and W.Safe(info.fullName)
        local area = type(info) == "table" and W.Safe(info.area)
        if type(full) == "string" and full ~= "" and #full <= 60 and not seen[full] and W.Key(full) ~= me
            and (type(area) ~= "string" or area == p.zoneName) then
            seen[full] = true
            local list = book[W.Key(full)] and known or rest
            list[#list + 1] = full
        end
    end
    for _, list in ipairs({ known, rest }) do
        for _, full in ipairs(list) do
            if #p.names < LS.MAX then p.names[#p.names + 1] = full end
        end
    end
    W.Activate(evWho, false)
    -- the rows against the ones kept: "nobody here" and "the zone filter matches no row" read apart in layers.log
    Log("LayerSwap ask: who " .. n .. " rows, " .. #p.names .. " in my zone, " .. #known .. " known hosts")
    if #p.names == 0 then
        LS.last = GetTime() - LS.GAP + LS.RETRY
        EndAsk("nobody", p.cls and L("Ask LayerSwap hosts: nobody of this search's class in my zone, click again for the next class.")
            or L("Ask LayerSwap hosts: the search found nobody else in my zone."))
        return
    end
    p.state = "send"
    SendRound(p)
end, nil, true)

local function AskHosts()
    if ask then EndAsk("stopped", L("Ask LayerSwap hosts: stopped.")); return end
    if not (C_FriendList and C_FriendList.SendWho and C_FriendList.GetNumWhoResults and C_FriendList.GetWhoInfo) then
        W.Print(L("Ask LayerSwap hosts: the player search is not available.")); return
    end
    if InCombatLockdown() or UnitAffectingCombat("player") or not OpenWorld() then
        W.Print(L("Ask LayerSwap hosts: not in combat, in an instance or on a taxi.")); return
    end
    if W.InGroup() then W.Print(L("Ask LayerSwap hosts: leave your group first (a host cannot invite a player who is in a group).")); return end
    if not current then
        W.Print(L("Ask LayerSwap hosts: my layer is unknown, look at two creatures of the zone first (a host on my own layer must stay out).")); return
    end
    local wait = LS.GAP - (GetTime() - LS.last)
    if wait > 0 then W.Print(string.format(L("Ask LayerSwap hosts: one search every 30 s, again in %d s."), math.ceil(wait))); return end
    local zone, zoneName = ZoneMap(), W.Safe(GetRealZoneText())
    if not zone or type(zoneName) ~= "string" or zoneName == "" then W.Print(L("Ask LayerSwap hosts: my zone is unknown.")); return end
    -- a busy zone: one class a search, after one on every class; a quiet one: every class each time
    if LS.crowded and LS.crowdedMap == zone then LS.round = (LS.round + 1) % (#LS.CLASSES + 1) else LS.round = 0 end
    local cls = LS.CLASSES[LS.round]
    -- in the click: the search is the one restricted call
    local origin = (Enum and Enum.SocialWhoOrigin and Enum.SocialWhoOrigin.Social) or 1
    local text = 'z-"' .. zoneName .. '"'
    WhoToUi(true)
    local ok = pcall(C_FriendList.SendWho, text, origin, { classIDs = cls and { cls } or {}, raceIDs = {}, uiMapIDs = { zone } })
    if not ok then ok = pcall(C_FriendList.SendWho, text, origin) end -- a client without the map filter: the zone by name
    if not ok then WhoToUi(false); W.Print(L("Ask LayerSwap hosts: the game refused the player search.")); return end
    LS.last = GetTime()
    local spot = MapSpot(zone)
    local p = { state = "search", from = current.id, zone = zone, zoneName = zoneName, cls = cls,
        line = "inv layer <LS " .. zone .. " not " .. current.id .. (spot and (" " .. spot) or "") .. ">",
        names = {}, asked = {}, replies = {}, n = 1, sent = 0, failed = 0, rounds = 0 }
    ask = p
    W.Activate(evWho, true)
    Log("LayerSwap ask: search map " .. zone .. " class " .. (cls or "all") .. " (mine " .. current.id .. ")")
    if UI.askBtn then UI.askBtn:SetText(L("Stop asking")) end
    W.After(LS.WHO_WAIT, function()
        if ask == p and p.state == "search" then
            LS.last = GetTime() - LS.GAP + LS.RETRY -- nothing went out: the next search sooner (a late answer is not read: the handler is off)
            EndAsk("no answer", L("Ask LayerSwap hosts: the player search got no answer, try again in a moment."))
        end
    end)
    if UI.panel and UI.panel:IsVisible() then Refresh() end
end

-- The answers of LayerSwap users, whispered back (strangers: Core lets them through only while my ask is out, only from a
-- player it went to, see W.AskGate): "heard <my name>|<their layer>|<their zone map>|<h: hosting, or ->" from each user,
-- "same" from a host on my own layer. Short pieces, anchored patterns; counted, the hosts kept in the book; never answered.
W.AskGate(LS_PREFIX, function(full)
    local p = ask
    return p ~= nil and p.state ~= "search" and p.asked[W.Key(full) or ""] == true
end)
W.OnAddon(LS_PREFIX, function(msg, _, channel, full)
    local p = ask
    if not p or channel ~= "WHISPER" or #msg > 120 then return end
    local key = W.Key(full)
    if not key or not p.asked[key] then return end
    local was = p.replies[key]
    local r = was or {}
    local function Flags() return (r.host and 1 or 0) + (r.other and 2 or 0) + (r.same and 4 or 0) end
    local before = was and Flags() or -1
    if msg == "same" then
        r.same, r.host = true, true
    else
        local f = {}
        for part in msg:gmatch("[^|]+") do
            f[#f + 1] = part
            if #f > 4 then return end
        end
        if #f ~= 4 then return end
        local target = f[1]:match("^heard (.+)$")
        if not target or W.Key(target) ~= W.UnitKey("player") then return end
        local layer, zone, host = f[2], f[3], f[4]
        if not ((layer == "-" or layer:match("^%d+%-%d+$")) and (zone == "-" or zone:match("^%d+$")) and (host == "h" or host == "-")) then
            return
        end
        local here = zone == tostring(p.zone)
        r.host = r.host or host == "h"
        r.other = r.other or (host == "h" and here and layer ~= "-" and layer ~= p.from)
        r.same = r.same or (here and layer == p.from)
    end
    p.replies[key] = r
    -- the same answer again (a sender may repeat it within its flood cap): no book write, no redraw
    if Flags() == before then return end
    if r.host then BookAdd(key) end
    if UI.panel and UI.panel:IsVisible() then Refresh() end
end)

-- An invite (a host's, or anyone's), a group, a new zone or layer: the ask is over, nothing more goes out. An invite from
-- a host that said it stands on my layer is named: accepting it changes nothing.
W.On("PARTY_INVITE_REQUEST", function(name, _, _, _, _, _, guid)
    if not ask then return end
    local raw = W.Safe(name)
    local who = W.Plain(raw or "?", 40)
    local key = type(raw) == "string" and W.Key(raw) or nil
    local r = key and ask.replies[key]
    guid = W.Safe(guid)
    LS.invite = { at = GetTime(), name = who, key = key, guid = type(guid) == "string" and guid or nil }
    if r and r.same then
        EndAsk("invite from a host on my layer", string.format(L("%s is a LayerSwap host on my own layer: accepting changes nothing. Decline, then ask again."), who))
    else
        EndAsk("invite", string.format(L("%s invited me: if it is a LayerSwap host, accept, then press Refresh Now on the game's notice (or Change layer now in /wl layer) and stay in the group (leaving it moves me again)."), who))
    end
end)
local function AskMoved() if ask then EndAsk("moved") end end
W.On("PLAYER_ENTERING_WORLD", AskMoved)
W.On("ZONE_CHANGED_NEW_AREA", AskMoved)
-- moved: the host's layer is mine now, stay in the group (no Leave button)
W.On("SHARD_TRANSFER", function() LS.joined = nil; AskMoved() end)
W.On("GROUP_LEFT", function() LS.joined = nil end)
-- an invite declined, timed out or taken back: the next group is not that one
W.On("PARTY_INVITE_CANCEL", function() LS.invite = nil end)
-- the inviter in my group: by its GUID when the invite gave one, else by name
local function InviterHere(j)
    if j.guid then
        for _, u in ipairs(W.GroupUnits()) do
            if W.Safe(UnitGUID(u)) == j.guid then return true end
        end
        return false
    end
    return j.key ~= nil and InGroupWith(j.key)
end
-- The group of an invite that came during my ask (within 2 min, the inviter in it): no layer move announced JOIN_WAIT s
-- after joining, a line says so and the Leave button shows (the host may stand on my layer or in another zone)
W.On("GROUP_JOINED", function()
    AskMoved()
    local inv = LS.invite
    LS.invite = nil
    if not inv or GetTime() - inv.at > 120 then return end
    local j = { at = GetTime(), name = inv.name, key = inv.key, guid = inv.guid }
    LS.joined = j
    Log("LayerSwap: joined the group of " .. inv.name .. " (mine " .. Mine() .. ")")
    W.After(LS.JOIN_WAIT, function()
        if LS.joined ~= j or moveAt or not W.InGroup() then return end
        if not InviterHere(j) then LS.joined = nil; return end -- another group than the invite's
        Log("LayerSwap: no move announced " .. LS.JOIN_WAIT .. " s after joining (mine " .. Mine() .. ")")
        W.Print(string.format(L("No layer move announced %d s after joining the group of %s: the host may be on my layer or in another zone. Leave this group in /wl layer, then ask again."), LS.JOIN_WAIT, j.name))
        if UI.panel and UI.panel:IsVisible() then Refresh() end
    end)
end)

-- The Leave button: on the player's click, never during the game's countdown (leaving then cancels the move), not as leader
local function CanLeave()
    local j = LS.joined
    return j ~= nil and not moveAt and W.InGroup() and GetTime() - j.at >= LS.JOIN_WAIT
        and not (UnitIsGroupLeader and UnitIsGroupLeader("player")) and C_PartyInfo ~= nil and C_PartyInfo.LeaveParty ~= nil
end
local function LeaveGroup()
    if not CanLeave() then return end
    Log("LayerSwap: Leave this group clicked (mine " .. Mine() .. ")")
    LS.joined = nil
    C_PartyInfo.LeaveParty()
    if UI.panel and UI.panel:IsVisible() then Refresh() end
end

---------------------------------------------------------------------------
-- Window tab
---------------------------------------------------------------------------
function Refresh()
    if not UI.panel then return end
    local now = GetServerTime()
    if current then
        UI.mine:SetText(string.format(L("My layer: %s"), string.format(L("Layer %d"), Number(current.id))
            .. "  |cffaaaaaa" .. W.Plain(current.zone, 60) .. " · " .. Age(current.at) .. "|r") .. MoveText())
    elseif db.on and not OpenWorld() then
        UI.mine:SetText(string.format(L("My layer: %s"), "|cffaaaaaa" .. L("off in instances, battlegrounds and on a taxi") .. "|r"))
    else
        UI.mine:SetText(string.format(L("My layer: %s"), "|cffaaaaaa" .. L("unknown: target or look at two creatures of the zone (nameplates help)") .. "|r"))
    end
    local list = {}
    if current then
        list[#list + 1] = { name = W.UnitDisplayName("player") or "?", full = W.UnitFullName("player"), id = current.id, map = current.map,
            zone = current.zone, at = current.at, me = true }
    end
    for key, e in pairs(guild) do
        if now - e.at > KEEP then guild[key] = nil else list[#list + 1] = e end
    end
    for _, e in ipairs(list) do e.n = Number(e.id) end -- once per row, not in the sort
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
        local name = W.ColorName((W.FOREVER and e.full) or e.name, m and m.class or (e.me and select(2, UnitClass("player")))) .. (e.me and (" " .. L("(me)")) or "")
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
        UI.sel:SetText(e and string.format(L("Selected: %s"), (W.FOREVER and e.full) or e.name) or "|cffaaaaaa" .. L("Click a player on another layer of my zone, then Invite.") .. "|r")
        if UI.invite then
            local ok = e and current and e.map == current.map and e.id ~= current.id and GetServerTime() - e.at <= FRESH
            if ok then UI.invite:Enable() else UI.invite:Disable() end
        end
    end
    if UI.move then UI.move:SetShown(CanMoveNow()) end
    if UI.askText then UI.askText:SetText(AskText()) end
    if UI.leave then UI.leave:SetShown(CanLeave()) end
end

W.RegisterModule("Layers", "Layers", function(p)
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
    UI.move = W.Button(p, L("Change layer now"), 190, 22, MoveNow,
        { L("Same as Refresh Now on the game's notice: moves me now instead of at the end of the countdown. Not in combat.") })
    UI.move:SetPoint("TOPRIGHT", -12, -40)
    UI.move:Hide()
    if W.FOREVER then
        UI.askBtn = W.Button(p, ask and L("Stop asking") or L("Ask LayerSwap hosts"), 190, 22, AskHosts, {
            L("Asks the players of my zone, out of sight, for an invite from another layer: the request of the LayerSwap addon, which its users with Host on answer with an invite."),
            L("The game's player search (/who) opens with the list of the players asked: 40 at most, 8 at once then one a second, one search every 30 s; in a busy zone each search after the first covers one class. The hosts that answered before are asked first."),
            L("My place on the zone map goes with the ask (LayerSwap's format: a host that skips askers near it reads it). The answers show next to the button: how many LayerSwap users heard me, how many host on another layer."),
            L("Then accept the invite, press Refresh Now on the game's notice (or Change layer now) and stay in the group. Out of a group, with my layer known."),
        })
        UI.askBtn:SetPoint("TOPRIGHT", -12, -66)
        UI.askText = W.Label(p, "", "GameFontHighlightSmall")
        UI.askText:SetPoint("RIGHT", UI.askBtn, "LEFT", -8, 0)
        UI.askText:SetWidth(320)
        UI.askText:SetJustifyH("RIGHT")
        -- the same place as Change layer now: one shows during the game's countdown, the other only without one
        UI.leave = W.Button(p, L("Leave this group"), 190, 22, LeaveGroup, {
            L("No layer move was announced after joining this group from a LayerSwap ask: the host may stand on my layer or in another zone. Leaves the group; then ask again."),
        })
        UI.leave:SetPoint("TOPRIGHT", -12, -40)
        UI.leave:Hide()
    end
    UI.table = W.Table(p, { { L("Player"), 220 }, { L("Zone"), 220 }, { L("Layer"), 90, "CENTER" },
        { "", 110, "CENTER" }, { L("Seen"), 80, "CENTER" } }, 330)
    UI.table:SetPoint("TOPLEFT", 10, -124)
    UI.table.onEnter = function(d, row)
        if d.me then return end
        GameTooltip:SetOwner(row, "ANCHOR_CURSOR")
        GameTooltip:AddLine(L("Click: select. Right click: whisper."), 1, 1, 1)
        GameTooltip:Show()
    end
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
    UI.invite:SetPoint("TOPLEFT", 10, -464)
    UI.sel = W.Label(p, "", "GameFontHighlightSmall")
    UI.sel:SetPoint("LEFT", UI.invite, "RIGHT", 10, 0)
    UI.sel:SetWidth(600)
    UI.sel:SetJustifyH("LEFT")
    local hint = W.Label(p, L("The layer number is the game's own number for this copy of the zone, read on the creatures around you: the same for every player on that layer. Layers open and close with the crowd, so the numbers change over time. To change layer: a player on the other layer invites you, you accept, then press Refresh Now on the game's notice (or wait for its countdown), out of combat. Stay in the group: leaving it starts a new countdown. A reading older than 5 minutes is grey, gone after one hour."),
        "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 16, -492)
    hint:SetWidth(780)
    hint:SetJustifyH("LEFT")
    local credit = W.Label(p, L("Method from Sashoof's WarLegend v3 addon."), "GameFontDisableSmall")
    credit:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -6)
    local acc = 0
    p:SetScript("OnShow", function() acc = 0; W.RequestGuildRoster(); Ask(); Refresh() end)
    p:SetScript("OnUpdate", function(_, el)
        acc = acc + el
        if acc >= 5 then acc = 0; Refresh() end
    end)
end, function() Refresh() end)

W.slash.layer = function() W.Toggle("Layers") end
