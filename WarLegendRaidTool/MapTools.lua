-- WarLegend RaidTool - MapTools
-- Small helpers on Blizzard's world map, ideas taken from OpenMap (MIT, (c) 2026 OpenMap contributors,
-- curseforge.com/wow/addons/openmap): coordinates under the map, Ctrl+click for a map pin, the map
-- reopening on my zone. Our own frame and two hooks; nothing runs while the map is closed. The pins of
-- the other addons (guild positions, Overlord, Skyborne...) are not touched.
local W = WLRT

W.AddFR({
    ["Map tools"] = "Outils de carte",
    ["Coordinates under the map (me and the cursor)"] = "Coordonnées sous la carte (moi et le curseur)",
    ["Ctrl + click on the map drops a map pin"] = "Ctrl + clic sur la carte pose un repère",
    ["Reopen the map on my zone"] = "Rouvrir la carte sur ma zone",
    ["Shows your position and the one under the mouse at the foot of the world map."] =
        "Affiche ta position et celle sous la souris en bas de la carte du monde.",
    ["Sets the game's map pin (and its arrow) where you click, if the game has not done it already."] =
        "Pose le repère de carte du jeu (et sa flèche) là où tu cliques, si le jeu ne l'a pas déjà fait.",
    ["Opens the map on the zone you are in, unless you had gone to another map on purpose."] =
        "Ouvre la carte sur ta zone, sauf si tu étais allé sur une autre carte exprès.",
    ["Ideas from OpenMap (MIT). If another map addon shows coordinates, turn that option off here."] =
        "Idées d'OpenMap (MIT). Si un autre addon de carte affiche déjà les coordonnées, éteins cette option.",
    ["Map pins are not available on this client: that option does nothing here."] =
        "Les repères de carte n'existent pas sur ce client : cette option ne fait rien ici.",
    ["Me"] = "Moi",
    ["Cursor"] = "Curseur",
})
local L = W.L

local db
local bar, hooked
local lastClosedMap
local meText, cursorText = "Me", "Cursor"

local function Valid(x, y)
    return type(x) == "number" and type(y) == "number" and x >= 0 and x <= 1 and y >= 0 and y <= 1
end

local function Fmt(x, y)
    if not Valid(x, y) then return "--" end
    return string.format("%.1f, %.1f", x * 100, y * 100)
end

-- my position on a map: pcall and W.Safe, the game hides it (secret values) in some places
local function PlayerXY(mapID)
    if type(mapID) ~= "number" or not (C_Map and C_Map.GetPlayerMapPosition) then return end
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if not ok or type(pos) ~= "table" or not pos.GetXY then return end
    local ok2, x, y = pcall(pos.GetXY, pos)
    if not ok2 then return end
    return W.Safe(x), W.Safe(y)
end

local function CursorXY()
    local sc = WorldMapFrame and WorldMapFrame.ScrollContainer
    if not (sc and sc.GetNormalizedCursorPosition and sc:IsMouseOver()) then return end
    local x, y = sc:GetNormalizedCursorPosition()
    return W.Safe(x), W.Safe(y)
end

local since = 0
local function OnUpdate(self, dt)
    since = since + dt
    if since < 0.1 then return end
    since = 0
    local px, py = PlayerXY(WorldMapFrame.GetMapID and WorldMapFrame:GetMapID())
    self.me:SetText(meText .. "  " .. Fmt(px, py))
    local cx, cy = CursorXY()
    self.cursor:SetText(Valid(cx, cy) and (cursorText .. "  " .. Fmt(cx, cy)) or "")
end

local function BuildBar()
    if bar then return end
    bar = CreateFrame("Frame", nil, WorldMapFrame)
    bar:SetSize(420, 22)
    bar:SetPoint("BOTTOM", WorldMapFrame.ScrollContainer or WorldMapFrame, "BOTTOM", 0, 8)
    bar:SetFrameLevel(math.min((WorldMapFrame:GetFrameLevel() or 0) + 9000, 9900)) -- above the map pins
    bar.me = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bar.me:SetFont(W.FONT, 16, "OUTLINE")
    bar.me:SetPoint("RIGHT", bar, "CENTER", -10, 0)
    bar.me:SetTextColor(1, 0.82, 0)
    bar.cursor = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bar.cursor:SetFont(W.FONT, 16, "OUTLINE")
    bar.cursor:SetPoint("LEFT", bar, "CENTER", 10, 0)
    bar:SetScript("OnUpdate", OnUpdate) -- runs only while the map (its parent) is shown
end

-- the game's map pin, if this client has it
local function CanPin()
    return C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates and true or false
end

local function DropPin(mapID, x, y)
    if not CanPin() or type(mapID) ~= "number" or not Valid(x, y) then return end
    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(mapID) then return end
    -- the game may have set it on this same click already: not twice
    if C_Map.HasUserWaypoint and C_Map.HasUserWaypoint() and C_Map.GetUserWaypoint then
        local p = C_Map.GetUserWaypoint()
        local pos = p and p.position
        if p and p.uiMapID == mapID and pos and math.abs(pos.x - x) < 0.003 and math.abs(pos.y - y) < 0.003 then return end
    end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
end

local function HookMap()
    if hooked then return end
    hooked = true
    local sc = WorldMapFrame.ScrollContainer
    if sc and sc.HookScript and sc.GetNormalizedCursorPosition then
        sc:HookScript("OnMouseUp", W.Timed("map tools click", function(self, button)
            if not (db.waypoint and button == "LeftButton" and IsControlKeyDown()) then return end
            local x, y = self:GetNormalizedCursorPosition()
            local id = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
            -- after the game's own handling of the click
            W.After(0, function() DropPin(id, W.Safe(x), W.Safe(y)) end)
        end))
    end
    WorldMapFrame:HookScript("OnHide", W.Timed("map tools hide", function()
        lastClosedMap = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
    end))
    WorldMapFrame:HookScript("OnShow", W.Timed("map tools show", function()
        if not db.reopen or not WorldMapFrame.GetMapID then return end
        local shown = WorldMapFrame:GetMapID()
        W.After(0, function()
            if not WorldMapFrame:IsShown() or InCombatLockdown() then return end
            -- someone chose another map (a click, a quest, a link): left alone
            if WorldMapFrame:GetMapID() ~= shown or shown ~= lastClosedMap then return end
            local mine = C_Map and C_Map.GetBestMapForUnit and W.Safe(C_Map.GetBestMapForUnit("player"))
            if type(mine) == "number" and mine ~= shown and WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(mine) end
        end)
    end))
end

local function Apply()
    if not db then return end
    if not (WorldMapFrame and WorldMapFrame.ScrollContainer) then return end
    meText, cursorText = L("Me"), L("Cursor")
    BuildBar()
    bar:SetShown(db.coords)
    HookMap()
end

W.OnReady(function()
    db = W.DB("mapTools", { coords = true, waypoint = false, reopen = false })
end)
W.On("PLAYER_ENTERING_WORLD", Apply)

W.slash.maptools = function() W.Toggle("MapTools") end

W.RegisterModule("MapTools", "Map tools", function(p)
    W.Title(p, L("Map tools"))
    W.Check(p, L("Coordinates under the map (me and the cursor)"), function() return db.coords end,
        function(v) db.coords = v; Apply() end,
        L("Shows your position and the one under the mouse at the foot of the world map.")):SetPoint("TOPLEFT", 12, -40)
    W.Check(p, L("Ctrl + click on the map drops a map pin"), function() return db.waypoint end,
        function(v) db.waypoint = v; Apply() end,
        L("Sets the game's map pin (and its arrow) where you click, if the game has not done it already.")):SetPoint("TOPLEFT", 12, -66)
    W.Check(p, L("Reopen the map on my zone"), function() return db.reopen end,
        function(v) db.reopen = v; Apply() end,
        L("Opens the map on the zone you are in, unless you had gone to another map on purpose.")):SetPoint("TOPLEFT", 12, -92)
    local info = W.Label(p, L("Ideas from OpenMap (MIT). If another map addon shows coordinates, turn that option off here."),
        "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, -126)
    info:SetTextColor(0.7, 0.7, 0.7)
    if not CanPin() then
        local warn = W.Label(p, L("Map pins are not available on this client: that option does nothing here."), "GameFontDisable")
        warn:SetPoint("TOPLEFT", 16, -150)
    end
end)
