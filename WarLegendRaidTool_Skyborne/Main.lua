-- WarLegend RaidTool - Skyborne
-- Pins the leylines (Alliance) or elemental convergences (Horde) listed in Data.lua on the world
-- map, and keeps a personal list of the ones you find yourself.
-- Based on "Skyborne Leyline & Convergence Marker" by tr0tsky (MIT license), adapted for WarLegend RaidTool:
-- loaded on demand for Skyborne characters only (see Skyborne.lua in WarLegendRaidTool).

local ADDON, ns = ...
local W = WLRT
local L = W.L

W.AddFR({
    ["Leyline"] = "Ligne de force",
    ["Elemental Convergence"] = "Convergence élémentaire",
    ["Skyborne"] = "Skyborne",
    ["%d min ago"] = "il y a %d min",
    ["%d h ago"] = "il y a %d h",
    ["Seen in your phase %s"] = "Vu dans ta phase %s",
    ["Not there in your phase %s"] = "Absent dans ta phase %s",
    ["Not seen in over %d mins"] = "Pas vu depuis plus de %d min",
    ["NEW"] = "NOUVEAU",
    ["map %d"] = "carte %d",
    ["How sharing works"] = "Comment fonctionne le partage",
    ["When one of your Skyborne characters finds an Elemental Convergence or Leyline (racial or minimap), its location (and phase) is sent to other users of the addon. This marks the icon on their map as green if they are in that phase, fading to red over time. You will get updates from other players as well."] =
        "Quand un de tes personnages Skyborne trouve une convergence élémentaire ou une ligne de force (sort racial ou minicarte), sa position (et sa phase) est envoyée aux autres utilisateurs de l'addon. L'icône devient verte sur leur carte s'ils sont dans cette phase, puis rougit avec le temps. Tu reçois aussi les repérages des autres joueurs.",
    ["Sharing uses WoW's built-in addon messages on a hidden chat channel for your faction. Everything goes through Blizzard's own servers: no outside server, no web traffic.\n\nA sighting sends only the phase number, map, position and time seen, for example:\nR:1:H:42752:1413:5496:3462:1791831931\n\nNothing about your character, gear or account is sent. Sightings expire after 90 minutes; new node locations learned from others are kept.\n\nTurning sharing off leaves the channel, so nothing is sent or received."] =
        "Le partage utilise les messages d'addon du jeu sur un canal de discussion caché de ta faction. Tout passe par les serveurs de Blizzard : aucun serveur extérieur, aucun trafic web.\n\nUn repérage envoie seulement le numéro de phase, la carte, la position et l'heure, par exemple :\nR:1:H:42752:1413:5496:3462:1791831931\n\nRien sur ton personnage, ton équipement ou ton compte n'est envoyé. Les repérages expirent après 90 minutes ; les nouvelles positions apprises des autres sont gardées.\n\nCouper le partage quitte le canal : rien n'est envoyé ni reçu.",
    ["Leyline & Convergence Marker"] = "Marqueur de lignes de force et convergences",
    ["Show only self-found locations"] = "Afficher seulement les positions trouvées par moi",
    ["When checked, the map shows only the locations you have found yourself. When unchecked, it shows every known location."] =
        "Coché, la carte n'affiche que les positions que tu as trouvées toi-même. Décoché, elle affiche toutes les positions connues.",
    ["Share sightings with other users"] = "Partager les repérages avec les autres utilisateurs",
    ["Detect nodes on the minimap"] = "Détecter les points sur la minicarte",
    ["Reads leylines and convergences off your minimap as you travel, no mouseover needed, and records them as self-found. With a controller, they're picked up when your cursor passes over them instead."] =
        "Lit les lignes de force et convergences sur ta minicarte en voyageant, sans survol, et les note comme trouvées par toi. Avec une manette, elles sont notées quand ton curseur passe dessus.",
    ["Show only nodes seen in your phase"] = "Afficher seulement les points vus dans ta phase",
    ["Hides every location without a recent sighting in your phase, so the map shows only nodes that are up right now. With sharing off, only the ones you have seen yourself count."] =
        "Masque toute position sans repérage récent dans ta phase : la carte n'affiche que les points actifs. Partage coupé, seuls ceux que tu as vus toi-même comptent.",
    ["Hide pins while buff has more than"] = "Masquer les épingles tant que le buff dépasse",
    ["Always show"] = "Toujours afficher",
    ["%d min"] = "%d min",
    ["Hides the pins while your leyline or convergence buff has more than this many minutes left, so you only see them when you need to find one. Set to 15 to always show them."] =
        "Masque les épingles tant que ton buff de ligne de force ou de convergence a plus de minutes que cela, pour ne les voir que quand tu en cherches une. 15 = toujours afficher.",
    ["Skyborne Marker - Export"] = "Marqueur Skyborne - Export",
    ["Nothing found yet."] = "Rien trouvé pour l'instant.",
    ["/wl sk - open the settings; /wl sk export - copy your found and shared locations; /wl sk share - sharing status"] =
        "/wl sk - ouvre les réglages ; /wl sk export - copie tes positions trouvées et partagées ; /wl sk share - état du partage",
    ["sharing %s, channel %s, phase %s%s, %d sighting(s) held, %d in this phase, %d queued"] =
        "partage %s, canal %s, phase %s%s, %d repérage(s) gardé(s), %d dans cette phase, %d en attente",
    ["on"] = "activé",
    ["off"] = "désactivé",
    ["not joined"] = "non rejoint",
    ["unknown"] = "inconnue",
    [" (tentative)"] = " (provisoire)",
    ["/wl sk share debug - print the messages sent and received"] =
        "/wl sk share debug - affiche les messages envoyés et reçus",
    ["share debug %s"] = "debug du partage %s",
})

local PIN = "WLRTSkyPinTemplate"
local MIN_DURATION = 60
local MAX_MINUTES = 15          -- slider maximum: the buff never has more than this left, so nothing hides
local SAME_YARDS = 60           -- closer than this counts as the same location
local RED_ALPHA = 0.6           -- pin opacity as a sighting is about to expire
local UNSEEN_ALPHA = 0.4        -- pin opacity with sharing on and no recent sighting
local GONE_ALPHA = 0.3          -- pin opacity when the newest report in your phase says it isn't there
local RACIAL_IDS = { [1259705] = true, [1259686] = true } -- Read Leyline (Alliance), Skysight (Horde)
local BUFF_IDS = { [1259691] = true, [1270893] = true } -- Energized (Alliance), Elemental Blessing (Horde)

local FACTIONS = {
    Alliance = { key = "LeyLines", name = "Leyline", atlas = "MagePortalAlliance" },
    Horde = { key = "ElementalConvergences", name = "Elemental Convergence", atlas = "MagePortalAlliance" },
}

local db, Provider, hidden, UpdateBuffHide

local function Print(msg, ...)
    W.Print(format(msg, ...))
end

local function Faction()
    return FACTIONS[UnitFactionGroup("player")] or FACTIONS.Alliance
end

local function MapName(mapID)
    local info = C_Map.GetMapInfo(mapID)
    return info and info.name or format(L("map %d"), mapID)
end

---------------------------------------------------------------------------
-- Geometry
---------------------------------------------------------------------------

-- a zone's size never changes: work it out once per session
local zoneSizes = {}
local function ZoneSizeYards(mapID)
    local size = zoneSizes[mapID]
    if size then return size[1], size[2] end
    local _, a = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0, 0))
    local _, b = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(1, 1))
    if not a or not b then return end
    -- world axes are swapped relative to map axes
    size = { math.abs(b.y - a.y), math.abs(b.x - a.x) }
    zoneSizes[mapID] = size
    return size[1], size[2]
end

local function Near(mapID, x1, y1, x2, y2)
    local w, h = ZoneSizeYards(mapID)
    return w and math.sqrt(((x1 - x2) * w) ^ 2 + ((y1 - y2) * h) ^ 2) < SAME_YARDS
end

local function FindNear(list, mapID, x, y)
    for _, p in ipairs(list or {}) do
        if Near(mapID, p[1], p[2], x, y) then return p end
    end
end

---------------------------------------------------------------------------
-- Self-found locations: db.found[dataKey][mapID] = { {x, y}, ... }
---------------------------------------------------------------------------

-- quiet: no message for a node Data.lua already has (minimap scans pass by lots of those)
local function Record(mapID, x, y, quiet)
    local key = Faction().key
    local found = db.found[key]
    found[mapID] = found[mapID] or {}
    local where = format("%s %.1f, %.1f", MapName(mapID), x * 100, y * 100)

    if FindNear(found[mapID], mapID, x, y) then return end
    table.insert(found[mapID], { x, y })

    if not (quiet and FindNear(WLRTSkyData[key][mapID], mapID, x, y)) then Print("|cffffff00%s|r %s", L("NEW"), where) end
    if Provider then Provider:RefreshAllData() end
end

local function HasNodeBuff(since)
    for id in pairs(BUFF_IDS) do
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
        if aura and aura.duration >= MIN_DURATION and aura.expirationTime - aura.duration >= since then
            return true
        end
    end
end

local pending

local function OnRacialCast()
    local mapID = C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return end
    local x, y, castTime, tries = pos.x, pos.y, GetTime() - 1, 0
    local serverTime = GetServerTime()
    local function Check()
        tries = tries + 1
        local ok, found = pcall(HasNodeBuff, castTime)
        if ok and found then
            Record(mapID, x, y)
            ns.OnConfirmed(mapID, x, y, serverTime)
        elseif ok and tries < 4 then
            C_Timer.After(0.5, Check)
        elseif not ok or InCombatLockdown() then
            -- auras unreadable or not reported in combat: look again when it ends
            pending = { mapID = mapID, x = x, y = y, castTime = castTime, serverTime = serverTime }
        end
    end
    C_Timer.After(0.2, Check)
end

local function CheckPending()
    local p = pending
    pending = nil
    if not p then return end
    local ok, found = pcall(HasNodeBuff, p.castTime)
    if ok and found then
        Record(p.mapID, p.x, p.y)
        ns.OnConfirmed(p.mapID, p.x, p.y, p.serverTime)
    elseif not ok then
        pending = p
    end
end

---------------------------------------------------------------------------
-- Map pins
---------------------------------------------------------------------------

WLRTSkyPinMixin = CreateFromMixins(MapCanvasPinMixin)

function WLRTSkyPinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    self:SetScalingLimits(1, 1.0, 1.2)
    self.Icon:SetAtlas(Faction().atlas)
end

-- report: a current-phase crowd sighting near this pin, if any; gone: else a current-phase "not there"
function WLRTSkyPinMixin:OnAcquired(x, y, report, gone)
    self.x, self.y, self.report, self.gone = x, y, report, gone
    self:SetPosition(x, y)
    if gone then
        self.Icon:SetDesaturated(true)
        self.Icon:SetVertexColor(0.6, 0.6, 0.6)
        self.Icon:SetAlpha(GONE_ALPHA)
    elseif report then
        -- green and solid when fresh, through yellow, to red and faded as it ages out
        local age = ns.CrowdAge(report)
        self.Icon:SetDesaturated(true)
        self.Icon:SetVertexColor(math.min(1, age * 2), math.min(1, (1 - age) * 2), 0)
        self.Icon:SetAlpha(1 - age * (1 - RED_ALPHA))
    else
        -- with sharing on, nodes nobody has seen lately sit back, fainter than an expiring sighting
        self.Icon:SetDesaturated(false)
        self.Icon:SetVertexColor(1, 1, 1)
        self.Icon:SetAlpha(db and db.crowd and UNSEEN_ALPHA or 1)
    end
end

function WLRTSkyPinMixin:CheckMouseButtonPassthrough(...)
    if not InCombatLockdown() then
        MapCanvasPinMixin.CheckMouseButtonPassthrough(self, ...)
    end
end

function WLRTSkyPinMixin:OnMouseEnter()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L(Faction().name))
    GameTooltip:AddLine(format("%.1f, %.1f", self.x * 100, self.y * 100), 1, 1, 1)
    if self.report or self.gone then
        local minutes = math.floor((GetServerTime() - (self.report or self.gone).t) / 60)
        local ago = minutes < 60 and format(L("%d min ago"), minutes) or format(L("%d h ago"), math.floor(minutes / 60))
        if self.report then
            GameTooltip:AddLine(format(L("Seen in your phase %s"), ago), 0.4, 1, 0.4)
        else
            GameTooltip:AddLine(format(L("Not there in your phase %s"), ago), 1, 0.5, 0.25)
        end
    elseif db and db.crowd then
        GameTooltip:AddLine(format(L("Not seen in over %d mins"), ns.CrowdMinutes()), 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

function WLRTSkyPinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

Provider = CreateFromMixins(MapCanvasDataProviderMixin)

function Provider:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate(PIN)
end

function Provider:RefreshAllData()
    self:RemoveAllData()
    if hidden then return end
    local key = Faction().key
    local mapID = self:GetMap():GetMapID()
    local mine = db and db.found[key][mapID]
    local crowd, gone, used = ns.CrowdReports(mapID), ns.CrowdGone(mapID), {}

    local function Pin(x, y)
        local report, notThere
        for i, r in ipairs(crowd) do
            if Near(mapID, r.x, r.y, x, y) then
                used[i], report = true, r
                break
            end
        end
        -- only nodes with a current sighting in your phase, when asked (with sharing off, your own sightings)
        if not report and db and db.hideUnseen then return end
        if not report then
            for _, g in ipairs(gone) do
                if Near(mapID, g.x, g.y, x, y) then notThere = g break end
            end
        end
        self:GetMap():AcquirePin(PIN, x, y, report, notThere)
    end

    if not (db and db.selfOnly) then
        for _, p in ipairs(WLRTSkyData[key][mapID] or {}) do
            Pin(p[1], p[2])
        end
        -- self-found points not already in the list
        for _, p in ipairs(mine or {}) do
            if not FindNear(WLRTSkyData[key][mapID], mapID, p[1], p[2]) then
                Pin(p[1], p[2])
            end
        end
        -- points learned from other players' sightings, not in either
        for _, p in ipairs(db and db.shared[key][mapID] or {}) do
            if not FindNear(WLRTSkyData[key][mapID], mapID, p[1], p[2]) and not FindNear(mine, mapID, p[1], p[2]) then
                Pin(p[1], p[2])
            end
        end
    else
        for _, p in ipairs(mine or {}) do
            Pin(p[1], p[2])
        end
    end
    -- sightings that match nothing we know: new locations, so not when showing self-found only
    if not (db and db.selfOnly) then
        for i, r in ipairs(crowd) do
            if not used[i] then self:GetMap():AcquirePin(PIN, r.x, r.y, r) end
        end
    end
end

ns.Print = Print

ns.Provider, ns.Faction, ns.Near = Provider, Faction, Near
ns.ZoneSizeYards = ZoneSizeYards
ns.GetDB = function() return db end

-- Scan.lua: minimap scanning runs while the setting is on (this addon only loads for Skyborne characters)
function ns.ScanEnabled()
    return db and db.minimapScan
end

-- A blip found by Scan.lua: the node is up in our phase right now
local SCAN_REPORT_GAP = 10 * 60
function ns.OnMinimapNode(mapID, x, y)
    Record(mapID, x, y, true)
    ns.ReportSighting(mapID, x, y, SCAN_REPORT_GAP)
end

-- Drop shared locations that an update has since added to Data.lua
local function PruneShared()
    for key, maps in pairs(db.shared) do
        for mapID, list in pairs(maps) do
            for i = #list, 1, -1 do
                if FindNear(WLRTSkyData[key] and WLRTSkyData[key][mapID], mapID, list[i][1], list[i][2]) then
                    table.remove(list, i)
                end
            end
            if #list == 0 then maps[mapID] = nil end
        end
    end
end

-- Locations learned from other players' sightings: db.shared[dataKey][mapID] = { {x, y}, ... }.
-- Kept apart from db.found so "self-found only" stays self-found; not learned at all while it's on.
function ns.LearnShared(mapID, x, y)
    if not db or db.selfOnly then return end
    local key = Faction().key
    local shared = db.shared[key]
    if FindNear(WLRTSkyData[key][mapID], mapID, x, y) or FindNear(db.found[key][mapID], mapID, x, y)
        or FindNear(shared[mapID], mapID, x, y) then return end
    shared[mapID] = shared[mapID] or {}
    -- heard on a public channel and saved for good: capped, a stranger cannot fill the map (or the saved file)
    if #shared[mapID] >= 100 then return end
    local total = 0 -- and in all: the number of maps is capped by nothing else
    for _, list in pairs(shared) do total = total + #list end
    if total >= 2000 then return end
    table.insert(shared[mapID], { x, y })
end

---------------------------------------------------------------------------
-- Hide pins while the node buff has more than db.hideMinutes left
---------------------------------------------------------------------------

local function BuffRemaining()
    for id in pairs(BUFF_IDS) do
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
        if aura and aura.duration >= MIN_DURATION then return aura.expirationTime - GetTime() end
    end
end

local timerToken, scheduledFor = 0, nil

function UpdateBuffHide()
    if not db then return end
    local ok, remaining = pcall(BuffRemaining)
    if not ok then return end -- auras unreadable (combat): keep the current state

    local limit = db.hideMinutes * 60
    local nowHidden = db.hideMinutes < MAX_MINUTES and remaining ~= nil and remaining > limit

    -- one timer, to re-check when the buff drops to the limit
    if nowHidden then
        local target = GetTime() + remaining - limit + 0.5
        if not scheduledFor or math.abs(target - scheduledFor) > 1 then
            timerToken, scheduledFor = timerToken + 1, target
            local token = timerToken
            C_Timer.After(target - GetTime(), function()
                if token == timerToken then UpdateBuffHide() end
            end)
        end
    else
        timerToken, scheduledFor = timerToken + 1, nil
    end

    if nowHidden ~= hidden then
        hidden = nowHidden
        Provider:RefreshAllData()
    end
end

---------------------------------------------------------------------------
-- Settings page (Blizzard's addon settings)
---------------------------------------------------------------------------

local category

-- the checkbox's tooltip: what is shared, then how
local function ShareTip()
    return L("When one of your Skyborne characters finds an Elemental Convergence or Leyline (racial or minimap), its location (and phase) is sent to other users of the addon. This marks the icon on their map as green if they are in that phase, fading to red over time. You will get updates from other players as well.")
        .. "\n\n" .. L("How sharing works") .. "\n"
        .. L("Sharing uses WoW's built-in addon messages on a hidden chat channel for your faction. Everything goes through Blizzard's own servers: no outside server, no web traffic.\n\nA sighting sends only the phase number, map, position and time seen, for example:\nR:1:H:42752:1413:5496:3462:1791831931\n\nNothing about your character, gear or account is sent. Sightings expire after 90 minutes; new node locations learned from others are kept.\n\nTurning sharing off leaves the channel, so nothing is sent or received.")
end

local function InitSettings()
    category = Settings.RegisterVerticalLayoutCategory("WarLegend - " .. L("Leyline & Convergence Marker"))
    local setting = Settings.RegisterAddOnSetting(category, "WLRT_SKY_SELF_ONLY", "selfOnly", db,
        Settings.VarType.Boolean, L("Show only self-found locations"), false)
    setting:SetValueChangedCallback(function() Provider:RefreshAllData() end)
    Settings.CreateCheckbox(category, setting,
        L("When checked, the map shows only the locations you have found yourself. When unchecked, it shows every known location."))

    local crowdSetting = Settings.RegisterAddOnSetting(category, "WLRT_SKY_CROWD", "crowd", db,
        Settings.VarType.Boolean, L("Share sightings with other users"), false)
    crowdSetting:SetValueChangedCallback(function(_, value)
        ns.SetCrowdEnabled(value)
    end)
    Settings.CreateCheckbox(category, crowdSetting, ShareTip())

    local scanSetting = Settings.RegisterAddOnSetting(category, "WLRT_SKY_MINIMAP_SCAN", "minimapScan", db,
        Settings.VarType.Boolean, L("Detect nodes on the minimap"), true)
    Settings.CreateCheckbox(category, scanSetting,
        L("Reads leylines and convergences off your minimap as you travel, no mouseover needed, and records them as self-found. With a controller, they're picked up when your cursor passes over them instead."))

    local unseen = Settings.RegisterAddOnSetting(category, "WLRT_SKY_HIDE_UNSEEN", "hideUnseen", db,
        Settings.VarType.Boolean, L("Show only nodes seen in your phase"), false)
    unseen:SetValueChangedCallback(function() Provider:RefreshAllData() end)
    Settings.CreateCheckbox(category, unseen,
        L("Hides every location without a recent sighting in your phase, so the map shows only nodes that are up right now. With sharing off, only the ones you have seen yourself count."))

    local hide = Settings.RegisterAddOnSetting(category, "WLRT_SKY_HIDE_MINUTES", "hideMinutes", db,
        Settings.VarType.Number, L("Hide pins while buff has more than"), MAX_MINUTES)
    hide:SetValueChangedCallback(function() UpdateBuffHide() end)
    local options = Settings.CreateSliderOptions(0, MAX_MINUTES, 1)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v)
        return v >= MAX_MINUTES and L("Always show") or format(L("%d min"), v)
    end)
    Settings.CreateSlider(category, hide, options,
        L("Hides the pins while your leyline or convergence buff has more than this many minutes left, so you only see them when you need to find one. Set to 15 to always show them."))
    Settings.RegisterAddOnCategory(category)
end

---------------------------------------------------------------------------
-- Export window
---------------------------------------------------------------------------

local exportFrame

-- Self-found, then learned from other players (skipping any that are in Data.lua or self-found by now)
local function BuildExport()
    local key = Faction().key
    local lines, count = {}, 0

    local function Section(title, source, skip)
        local ids = {}
        for mapID in pairs(source) do ids[#ids + 1] = mapID end
        table.sort(ids)
        local header = false
        for _, mapID in ipairs(ids) do
            local points = {}
            for _, p in ipairs(source[mapID]) do
                if not (skip and skip(mapID, p)) then points[#points + 1] = p end
            end
            if #points > 0 then
                if not header then
                    lines[#lines + 1] = "-- " .. key .. ", " .. title
                    header = true
                end
                lines[#lines + 1] = format("[%d] = { -- %s", mapID, MapName(mapID))
                for _, p in ipairs(points) do
                    lines[#lines + 1] = format("    { %.4f, %.4f },", p[1], p[2])
                    count = count + 1
                end
                lines[#lines + 1] = "},"
            end
        end
    end

    Section("self-found", db.found[key])
    Section("from other players", db.shared[key], function(mapID, p)
        return FindNear(WLRTSkyData[key][mapID], mapID, p[1], p[2]) or FindNear(db.found[key][mapID], mapID, p[1], p[2])
    end)
    return table.concat(lines, "\n"), count
end

local function ShowExport()
    if not exportFrame then
        local f = CreateFrame("Frame", "WLRTSkyExport", UIParent, "BasicFrameTemplateWithInset")
        f:SetSize(420, 360)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f.TitleText:SetText(L("Skyborne Marker - Export"))
        tinsert(UISpecialFrames, f:GetName())

        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -32)
        scroll:SetPoint("BOTTOMRIGHT", -32, 12)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(370)
        edit:SetScript("OnEscapePressed", function() f:Hide() end)
        edit:SetScript("OnKeyDown", function(_, key)
            if key == "C" and IsControlKeyDown() then C_Timer.After(0, function() f:Hide() end) end
        end)
        scroll:SetScrollChild(edit)
        f.edit = edit
        exportFrame = f
    end
    local text, count = BuildExport()
    if count == 0 then
        Print(L("Nothing found yet."))
        return
    end
    exportFrame.edit:SetText(text)
    exportFrame:Show()
    exportFrame.edit:SetFocus()
    exportFrame.edit:HighlightText()
end

---------------------------------------------------------------------------
-- /wl sk (the main addon forwards the text after "sk")
---------------------------------------------------------------------------

WLRTSkyborne = {}
function WLRTSkyborne.Command(msg)
    local cmd, rest = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if cmd == "export" then
        ShowExport()
    elseif cmd == "share" then
        ns.ShareCommand(rest)
    elseif cmd == "scan" and ns.ScanCommand then
        ns.ScanCommand()
    else
        if Settings and Settings.OpenToCategory and category then Settings.OpenToCategory(category:GetID()) end
        Print(L("/wl sk - open the settings; /wl sk export - copy your found and shared locations; /wl sk share - sharing status"))
    end
end

---------------------------------------------------------------------------
-- Start (the addon is loaded on demand, long after login: nothing waits for ADDON_LOADED / PLAYER_LOGIN)
---------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterUnitEvent("UNIT_AURA", "player") -- used only as a trigger; the payload is secret
events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
events:SetScript("OnEvent", function(_, event, arg1, arg2, spellID)
    if not db then return end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if RACIAL_IDS[spellID] then OnRacialCast() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        CheckPending()
        UpdateBuffHide()
    elseif event == "PLAYER_ENTERING_WORLD" then
        UpdateBuffHide()
    elseif event == "UNIT_AURA" and (hidden or db.hideMinutes < MAX_MINUTES) then
        UpdateBuffHide()
    end
end)

function ns.Start()
    if db then return end
    if not WorldMapFrame and C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_WorldMap") end
    if not WorldMapFrame then return end
    WarLegendRaidTool_SkyborneDB = type(WarLegendRaidTool_SkyborneDB) == "table" and WarLegendRaidTool_SkyborneDB or {}
    db = WarLegendRaidTool_SkyborneDB
    db.found = type(db.found) == "table" and db.found or {}
    db.shared = type(db.shared) == "table" and db.shared or {}
    for _, f in pairs(FACTIONS) do
        db.found[f.key] = db.found[f.key] or {}
        db.shared[f.key] = db.shared[f.key] or {}
    end
    if db.selfOnly == nil then db.selfOnly = false end
    if db.hideMinutes == nil then db.hideMinutes = MAX_MINUTES end
    if db.crowd == nil then db.crowd = true end -- WarLegend choice: sharing on by default (Skyborne characters only)
    if db.minimapScan == nil then db.minimapScan = true end
    if db.hideUnseen == nil then db.hideUnseen = false end
    WorldMapFrame:AddDataProvider(Provider)
    -- zone sizes (for distances) aren't always ready this early
    C_Timer.After(5, PruneShared)
    InitSettings()
    ns.CommStart()
    UpdateBuffHide()
end

WLRTSkyborne.Start = ns.Start
