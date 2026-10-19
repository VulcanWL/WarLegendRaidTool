-- WarLegend RaidTool - Guild map
-- Guild members on the world map and the minimap (the idea of GuildMap): each member sends its position to the
-- guild every few seconds while it moves, out of instances. Same addon messages as the GuildMap addon (prefix,
-- fields): its users and ours see each other. Pins: HereBeDragons (Libs/, BSD). Off while GuildMap is loaded.
local W = WLRT
W.AddFR({
    ["Guild map"] = "Carte de guilde",
    ["Members"] = "Membres",
    ["Share my position with the guild"] = "Partager ma position avec la guilde",
    ["Show the guild on the world map"] = "Afficher la guilde sur la carte du monde",
    ["Show the guild on the minimap"] = "Afficher la guilde sur la minicarte",
    ["Keep the far ones on the edge of the minimap"] = "Garder les lointains au bord de la minicarte",
    ["Size of the icons:"] = "Taille des icônes :",
    ["%d guild members on the map"] = "%d membres de la guilde sur la carte",
    ["Level %d"] = "Niveau %d",
    ["%d s ago"] = "il y a %d s",
    ["Click: whisper. Right-click: invite."] = "Clic : chuchoter. Clic droit : inviter.",
    ["The GuildMap addon is loaded: disable it, this module replaces it (members with GuildMap are still seen)."] =
        "L'addon GuildMap est chargé : désactive-le, ce module le remplace (les membres qui ont GuildMap sont toujours vus).",
    ["Not shared in dungeons, raids and battlegrounds. The players of your group are not shown (the game shows them). Members who use the GuildMap addon are seen too, and see you."] =
        "Pas partagée en donjon, raid et champ de bataille. Les joueurs de ton groupe ne sont pas affichés (le jeu les montre). Les membres qui utilisent l'addon GuildMap sont vus aussi, et te voient.",
    ["The map library is missing: reinstall the addon."] = "La librairie de carte manque : réinstalle l'addon.",
})
local L = W.L
local db

local PREFIX = "GuildMapEx1" -- the GuildMap addon's prefix and fields
local GM_VERSION = "1.5.1"   -- told to GuildMap users (it reads some fields only from 1.3.2)
local REF = "WLRTGuildMap"
local SEND_MOVING, SEND_IDLE, FORGET = 5, 20, 60
local MAX_PINS = 300

W.OnReady(function()
    db = W.DB("guildPositions", { share = true, world = true, minimap = true, edge = false, size = 16 })
end)

local HBD, Pins
local standalone = false
local function On(opt) return db and db[opt] and HBD and Pins and not standalone and W.Allowed() and not W.IsOff("GuildPositions") end

---------------------------------------------------------------------------
-- Pins (one world and one minimap frame per member, reused)
---------------------------------------------------------------------------
local members = {} -- [full name] = { name, level, class, mapID, x, y, t, world = frame, mini = frame }
local count = 0

local function Invite(name)
    if C_PartyInfo and C_PartyInfo.InviteUnit then C_PartyInfo.InviteUnit(name) elseif InviteUnit then InviteUnit(name) end
end

local function OnEnter(self)
    local m = self.member
    if not m then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(m.name, W.ClassColor(m.class))
    GameTooltip:AddLine(string.format(L("Level %d"), m.level or 0), 1, 1, 1)
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(m.mapID)
    if info and info.name then GameTooltip:AddLine(info.name, 0.8, 0.8, 0.8) end
    GameTooltip:AddLine(string.format(L("%d s ago"), math.floor(GetTime() - m.t)), 0.6, 0.6, 0.6)
    GameTooltip:AddLine(L("Click: whisper. Right-click: invite."), 0.5, 0.8, 1)
    GameTooltip:Show()
end

-- WoW never frees a frame: the pins of a member who is forgotten (60 s silent, in an instance, in my group) go back
-- here and are reused, else every evening would add new frames
local spare = {}
local function NewPin()
    local f = table.remove(spare)
    if f then return f end
    f = CreateFrame("Button", nil, UIParent)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f:SetScript("OnEnter", OnEnter)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:SetScript("OnClick", function(self, button)
        local m = self.member
        if not m then return end
        if button == "RightButton" then Invite(m.full) elseif ChatFrame_SendTell then ChatFrame_SendTell(m.full) end
    end)
    return f
end

local function Paint(f, m)
    f.member = m
    local size = db.size or 16
    f:SetSize(size, size)
    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[m.class]
    if coords then
        f.icon:SetTexture("Interface\\WorldStateFrame\\Icons-Classes")
        f.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
        f.icon:SetTexture("Interface\\Minimap\\PartyRaidBlips")
        f.icon:SetTexCoord(0, 1, 0, 1)
    end
end

local function Unpin(m)
    if m.world then Pins:RemoveWorldMapIcon(REF, m.world) end
    if m.mini then Pins:RemoveMinimapIcon(REF, m.mini) end
end

local function Place(m)
    if not (HBD and Pins) then return end
    if On("world") then
        m.world = m.world or NewPin()
        Paint(m.world, m)
        Pins:AddWorldMapIconMap(REF, m.world, m.mapID, m.x, m.y, HBD_PINS_WORLDMAP_SHOW_CONTINENT or 2)
    elseif m.world then
        Pins:RemoveWorldMapIcon(REF, m.world)
    end
    if On("minimap") then
        m.mini = m.mini or NewPin()
        Paint(m.mini, m)
        Pins:AddMinimapIconMap(REF, m.mini, m.mapID, m.x, m.y, true, db.edge and true or false)
    elseif m.mini then
        Pins:RemoveMinimapIcon(REF, m.mini)
    end
end

local function Release(f)
    if not f then return end
    f.member = nil
    f:Hide()
    spare[#spare + 1] = f
end

local function Forget(full)
    local m = members[full]
    if not m then return end
    Unpin(m)
    Release(m.world)
    Release(m.mini)
    m.world, m.mini = nil, nil
    m.gone = true
    count = count - 1
    members[full] = nil
end

local function PlaceAll()
    for _, m in pairs(members) do Place(m) end
end

local function ForgetAll()
    for full in pairs(members) do Forget(full) end
end

---------------------------------------------------------------------------
-- Receive: "name,rank,level,class,race,x,y,mapID,health,layer,version,dueling" (class STEALTH: gone)
---------------------------------------------------------------------------
local myName
W.OnAddon(PREFIX, function(msg, _, channel, full)
    if channel ~= "GUILD" or #msg > 300 or not (HBD and Pins) or standalone or W.IsOff("GuildPositions") then return end
    -- in a dungeon, raid or battleground the pins cannot show (the map library hides them there): the
    -- messages of the whole guild are dropped unread, the members are forgotten by Tick and come back
    -- with their next message once outside
    if IsInInstance() then return end
    myName = myName or W.UnitFullName("player")
    if not full or full == myName then return end
    local name, _, level, class, _, x, y, mapID = strsplit(",", msg)
    if class == "STEALTH" then Forget(full); return end
    x, y, mapID, level = tonumber(x), tonumber(y), tonumber(mapID), tonumber(level)
    if not (x and y and mapID) or x <= 0 or x > 1 or y <= 0 or y > 1 or mapID <= 0 then Forget(full); return end
    -- the game shows the players of my group itself
    if W.UnitByName and W.UnitByName(full) then Forget(full); return end
    local m = members[full]
    if not m then
        if count >= MAX_PINS then return end
        m = { full = full }
        members[full] = m
        count = count + 1
    end
    m.name = (type(name) == "string" and name ~= "" and #name <= 60) and W.Plain(name, 60) or full
    m.level = level or 0
    m.class = type(class) == "string" and class:upper() or "WARRIOR"
    m.mapID, m.x, m.y, m.t = mapID, x, y, GetTime()
    Place(m)
end)

---------------------------------------------------------------------------
-- Send: when I moved (every 5 s) or every 20 s anyway, never in an instance; "gone" once when it stops
---------------------------------------------------------------------------
local lastX, lastY, lastMap, lastSent, sharing = nil, nil, nil, 0, false

local function Line(x, y, mapID, gone)
    local me = W.UnitFullName("player") or "?"
    -- my rank straight from GetGuildInfo: W.GuildMember would rebuild the whole guild list (every member)
    -- each time the roster changed, every 5 s while moving in a big guild
    local rankIndex = GetGuildInfo and W.Safe(select(3, GetGuildInfo("player")))
    local race = W.Safe(UnitRace("player")) or ""
    local class = gone and "STEALTH" or (W.UnitClassToken("player") or "WARRIOR")
    return string.format("%s,%s,%d,%s,%s,%.3f,%.3f,%d,%d,%d,%s,%d", me, tostring(type(rankIndex) == "number" and rankIndex or 5),
        UnitLevel("player") or 1, class, (race:gsub(",", "")), x, y, mapID, 100, 0, GM_VERSION, 0)
end

local function StopSharing()
    if not sharing then return end
    sharing = false
    lastMap = nil
    if IsInGuild() then W.Send(PREFIX, Line(0, 0, 0, true), "GUILD") end
end

local function Tick()
    local now = GetTime()
    -- the members not heard for a while are taken off the map
    for full, m in pairs(members) do
        if now - m.t > FORGET then Forget(full) end
    end
    if not On("share") or not IsInGuild() or IsInInstance() then StopSharing(); return end
    local mapID = C_Map and C_Map.GetBestMapForUnit and W.Safe(C_Map.GetBestMapForUnit("player"))
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    local x, y
    if pos and pos.GetXY then x, y = pos:GetXY() end
    x, y = W.Safe(x), W.Safe(y)
    if type(x) ~= "number" or type(y) ~= "number" or (x == 0 and y == 0) then StopSharing(); return end
    local moved = mapID ~= lastMap or not lastX or math.abs(x - lastX) + math.abs(y - lastY) > 0.002
    if not moved and now - lastSent < SEND_IDLE then return end
    if W.Send(PREFIX, Line(x, y, mapID, false), "GUILD") then
        sharing, lastX, lastY, lastMap, lastSent = true, x, y, mapID, now
    end
end

local ticker
local function Start()
    local want = db and not standalone and HBD and Pins and W.Allowed() and not W.IsOff("GuildPositions")
    if want and not ticker and C_Timer and C_Timer.NewTicker then
        ticker = C_Timer.NewTicker(SEND_MOVING, function()
            local ok, err = W.Measure("guild map", Tick)
            if not ok then geterrorhandler()(err) end
        end)
    elseif not want and ticker then
        ticker:Cancel()
        ticker = nil
        StopSharing()
        ForgetAll()
    end
end

W.On("PLAYER_LOGIN", function()
    standalone = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("GuildMap") and true or false
    if LibStub then
        HBD = LibStub("HereBeDragons-2.0-gm", true)
        Pins = LibStub("HereBeDragons-Pins-2.0-gm", true)
    end
end)
W.On("PLAYER_ENTERING_WORLD", function() Start(); W.After(2, Tick) end)
W.On("PLAYER_LOGOUT", StopSharing)

W.RegisterModule("GuildPositions", "Guild map", function(p)
    W.Title(p, L("Guild map"))
    local tabs = W.SubTabs(p, { L("Members"), L("Transports") })
    if W.TransportsPanel then W.TransportsPanel(tabs.frames[2]) end
    p = tabs.frames[1]
    local y = -8
    if standalone then
        local warn = W.Label(p, L("The GuildMap addon is loaded: disable it, this module replaces it (members with GuildMap are still seen)."), "GameFontHighlight")
        warn:SetPoint("TOPLEFT", 16, y)
        warn:SetWidth(680)
        warn:SetJustifyH("LEFT")
        y = y - 34
    elseif not (HBD and Pins) then
        W.Label(p, L("The map library is missing: reinstall the addon."), "GameFontHighlight"):SetPoint("TOPLEFT", 16, y)
        y = y - 30
    end
    W.Check(p, L("Share my position with the guild"), function() return db.share end, function(v)
        db.share = v
        if v then Tick() else StopSharing() end
    end):SetPoint("TOPLEFT", 12, y)
    W.Check(p, L("Show the guild on the world map"), function() return db.world end, function(v) db.world = v; PlaceAll() end)
        :SetPoint("TOPLEFT", 12, y - 24)
    W.Check(p, L("Show the guild on the minimap"), function() return db.minimap end, function(v) db.minimap = v; PlaceAll() end)
        :SetPoint("TOPLEFT", 12, y - 48)
    W.Check(p, L("Keep the far ones on the edge of the minimap"), function() return db.edge end, function(v) db.edge = v; PlaceAll() end)
        :SetPoint("TOPLEFT", 32, y - 72)
    W.Label(p, L("Size of the icons:"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 16, y - 107)
    W.Cycle(p, 70, { { 12, "12" }, { 16, "16" }, { 20, "20" }, { 24, "24" } }, function() return db.size end,
        function(v) db.size = v; PlaceAll() end):SetPoint("TOPLEFT", 160, y - 102)
    local shown = W.Label(p, "", "GameFontNormal")
    shown:SetPoint("TOPLEFT", 16, y - 140)
    p:HookScript("OnShow", function() shown:SetText(string.format(L("%d guild members on the map"), count)) end)
    local info = W.Label(p, L("Not shared in dungeons, raids and battlegrounds. The players of your group are not shown (the game shows them). Members who use the GuildMap addon are seen too, and see you."),
        "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, y - 170)
    info:SetWidth(680)
    info:SetJustifyH("LEFT")
    info:SetTextColor(0.7, 0.7, 0.7)
    tabs:Select(1)
end)

W.slash.map = function() W.Toggle("GuildPositions") end
