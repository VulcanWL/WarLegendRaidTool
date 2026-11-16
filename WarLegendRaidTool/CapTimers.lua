-- WarLegend RaidTool - Battleground timers (the good ideas of Capping, Capping look)
--  * base captures: the map points of interest change icon when a base is assaulted ("contested" icons),
--    a bar counts down the capture in the color of the team taking it (Darkspear Island, Arathi, Alterac...)
--  * battle begins (gates), queue (estimated wait, then time left to enter), flag respawn after a capture
--  * Shift-click a bar: /say, Ctrl-click: battleground chat
-- When Capping itself is loaded it keeps what it does (queue, gates, flag, Arathi / Alterac captures):
-- only the captures of the other battlegrounds are left here, no bar twice.
-- Cost: nothing outside battlegrounds and queues; in one, the map is read when the game says it changed.
local W = WLRT
W.AddFR({
    ["Battleground timers"] = "Chronos de CdB",
    ["Base capture timers"] = "Chronos de capture des bases",
    ["Battle start and queue bars"] = "Barres de début de bataille et de file d'attente",
    ["Flag respawn after a capture"] = "Réapparition du drapeau après une capture",
    ["Lock the bars"] = "Verrouiller les barres",
    ["Capture time (other battlegrounds):"] = "Temps de capture (autres champs de bataille) :",
    ["%d s"] = "%d s",
    ["Test"] = "Test",
    ["Reset position"] = "Réinitialiser la position",
    ["Map points now"] = "Points de la carte maintenant",
    ["Battle begins"] = "Début de la bataille",
    ["Flag respawns"] = "Réapparition du drapeau",
    ["Capping is loaded: it keeps its queue, gates, flag and Arathi / Alterac bars, these are only for the other battlegrounds."] =
        "Capping est chargé : il garde ses barres de file, de portes, de drapeau et d'Arathi / Alterac, celles-ci ne servent qu'aux autres champs de bataille.",
    ["A base assaulted (map icon contested) gets a bar until it is taken: Alterac 5 min, Arathi 1 min, other battlegrounds the time chosen here. Shift-click a bar: /say, Ctrl-click: battleground chat. If a battleground shows no bar, open \"Map points now\" during an assault and send the text."] =
        "Une base attaquée (icône contestée sur la carte) a une barre jusqu'à sa prise : Alterac 5 min, Arathi 1 min, les autres champs de bataille le temps choisi ici. Maj-clic sur une barre : /dire, Ctrl-clic : canal du champ de bataille. Si un champ de bataille n'affiche rien, ouvre « Points de la carte maintenant » pendant une attaque et envoie le texte.",
    ["Not in a battleground."] = "Pas en champ de bataille.",
    ["BigWigs style: the bar moves to the middle for its last 5 seconds"] =
        "Style BigWigs : la barre passe au centre pour ses 5 dernières secondes",
    ["Big 5-4-3-2-1 countdown"] = "Gros décompte 5-4-3-2-1",
    ["Middle bar (drag me)"] = "Barre du centre (déplace-moi)",
    ["Voice countdown"] = "Décompte vocal",
    ["Time to win (final score estimate)"] = "Temps avant la victoire (score final estimé)",
    ["Final: %d - %d"] = "Final : %d - %d",
    ["Queue pop sound with sound effects off"] = "Son du pop de la file, effets sonores coupés",
    -- appearance
    ["Timers"] = "Chronos",
    ["Appearance"] = "Apparence",
    ["Texture:"] = "Texture :",
    ["Font:"] = "Police :",
    ["Size:"] = "Taille :",
    ["Outline:"] = "Contour :",
    ["Width:"] = "Largeur :",
    ["Height:"] = "Hauteur :",
    ["Spacing:"] = "Espacement :",
    ["Text:"] = "Texte :",
    ["Time:"] = "Temps :",
    ["Default"] = "Par défaut",
    ["Noto Sans"] = "Noto Sans",
    ["Arial Narrow"] = "Arial Narrow",
    ["Morpheus"] = "Morpheus",
    ["Skurri"] = "Skurri",
    ["Capping"] = "Capping",
    ["Blizzard"] = "Blizzard",
    ["Flat"] = "Uni",
    ["Skills bar"] = "Barre de compétence",
    ["Target frame"] = "Cadre de cible",
    ["None"] = "Aucun",
    ["Outline"] = "Contour",
    ["Thick outline"] = "Contour épais",
    ["Center"] = "Centre",
    ["Show the icon"] = "Afficher l'icône",
    ["Icon on the right"] = "Icône à droite",
    ["Show the time"] = "Afficher le temps",
    ["Bars fill up"] = "Les barres se remplissent",
    ["Grow upwards"] = "Empiler vers le haut",
    ["Monochrome font"] = "Police sans lissage",
    ["Colors:"] = "Couleurs :",
    ["Text"] = "Texte",
    ["Background"] = "Fond",
    ["Queue"] = "File d'attente",
    ["Other"] = "Autre",
    ["Default appearance"] = "Apparence par défaut",
    ["Click a square to change its color. Test shows bars while you adjust."] =
        "Clique sur un carré pour changer sa couleur. Test affiche des barres pendant les réglages.",
})
local L = W.L
local db

-- contested icons (POI texture index) -> team taking the base; from Capping (iconDataConflict)
local CONTESTED = {
    [3] = "Alliance", [13] = "Horde",   -- graveyard
    [8] = "Alliance", [11] = "Horde",   -- tower
    [17] = "Alliance", [19] = "Horde",  -- mine / stone
    [22] = "Alliance", [24] = "Horde",  -- lumber / wood
    [27] = "Alliance", [29] = "Horde",  -- blacksmith / anvil
    [32] = "Alliance", [34] = "Horde",  -- farm / house
    [37] = "Alliance", [39] = "Horde",  -- stables / horse
}
-- capture time per battleground instance (Capping's modules); others: db.capTime
local ZONE_CAPTIME = { [30] = 300, [2197] = 241, [529] = 60, [2107] = 60 }
local CAPPING_ZONES = { [30] = true, [2197] = true, [529] = true, [2107] = true } -- Alterac, Arathi
local POI_ICONS = 136441 -- Interface/Minimap/POIIcons
local FLAG_RESPAWN = 12

-- "X captured the flag" in each language (BattlegroundTargets / Capping triggers). French: "a pris le drapeau de
-- la Horde" is the capture, "a pris le drapeau !" alone the pickup (the shorter trigger fired on every pickup)
local CAPTURED = ({
    deDE = "errungen!", esES = "capturado la bandera", esMX = "capturado la bandera", frFR = "a pris le drapeau de",
    itIT = "conquistato la bandiera", koKR = "깃발 쟁탈에 성공했습니다!", ptBR = "capturou a Bandeira", ruRU = "захватил", -- ru: "захватывает флаг" is the pickup
    zhCN = "夺取", zhTW = "佔據了",
})[GetLocale()] or "captured the"

-- Appearance (Capping's options): fixed lists of the fonts and bar textures every client ships (all used by
-- Forever's own interface), the labels translated when the tab is built. A setting is read through Look(): a value
-- outside its list (a profile from another version) gives the default, never a nil size or an unknown file.
local FONTS = {
    { "default", "Default" }, -- W.FONT, read when used (a skin's font is only known at ADDON_LOADED)
    { "noto", "Noto Sans", W.COUNTDOWN_FONT },
    { "arialn", "Arial Narrow", "Fonts\\ARIALN.TTF" },
    { "morpheus", "Morpheus", "Fonts\\MORPHEUS.TTF" },
    { "skurri", "Skurri", "Fonts\\SKURRI.TTF" },
}
local TEXTURES = {
    { "capping", "Capping", "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
    { "blizzard", "Blizzard", W.BAR_TEXTURE },
    { "flat", "Flat", W.WHITE },
    { "skills", "Skills bar", "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" },
    { "target", "Target frame", "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill" },
}
local OUTLINES = { { "", "None" }, { "OUTLINE", "Outline" }, { "THICKOUTLINE", "Thick outline" } }
local ALIGNS = { { "LEFT", "Left" }, { "CENTER", "Center" }, { "RIGHT", "Right" } }
local SIDES = { { "LEFT", "Left" }, { "RIGHT", "Right" } }
local WIDTHS = { 150, 175, 200, 225, 250, 300, 350, 400 }
local HEIGHTS = { 12, 14, 16, 18, 20, 22, 24, 28, 32 }
local SPACINGS = { 0, 1, 2, 4, 6, 8, 10 }
local FONT_SIZES = { 8, 9, 10, 11, 12, 13, 14, 16, 18 }
local LOOK_LISTS = { width = WIDTHS, height = HEIGHTS, spacing = SPACINGS, fontSize = FONT_SIZES, font = FONTS,
    outline = OUTLINES, texture = TEXTURES, alignText = ALIGNS, alignTime = SIDES }
-- colors as "rrggbb" (scalars: in the profiles without a table field); Capping's defaults
local LOOK_DEFAULTS = { width = 200, height = 20, spacing = 0, fontSize = 10, font = "default", outline = "", mono = false,
    texture = "capping", icon = true, iconRight = false, timeText = true, fill = false, growUp = false,
    alignText = "LEFT", alignTime = "RIGHT", cText = "ffffff", cBg = "000000", cAlliance = "0000ff", cHorde = "ff0000",
    cQueue = "999999", cOther = "ffff00" }

W.OnReady(function()
    local defaults = { enabled = true, locked = false, capTime = 60, queue = true, flag = true, win = true,
        emphasize = true, bigCount = true, voice = true, popSound = true }
    for k, v in pairs(LOOK_DEFAULTS) do defaults[k] = v end
    db = W.DB("capTimers", defaults)
    if type(db.point) ~= "table" then db.point = { "TOP", "TOP", 0, -150 } end
end)

local function InList(list, v)
    for _, e in ipairs(list) do if (type(e) == "table" and e[1] or e) == v then return true end end
    return false
end

-- an appearance setting, or its default when the saved one is not one of the choices
local function Look(key)
    local d = LOOK_DEFAULTS[key]
    local v = db and db[key]
    if v == nil then return d end
    local list = LOOK_LISTS[key]
    if list then return InList(list, v) and v or d end
    if type(d) == "boolean" then return v == true end
    if type(v) == "string" and v:match("^%x%x%x%x%x%x$") then return v end -- a color
    return d
end

local function RGB(key)
    local hex = Look(key)
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

local function Hex(r, g, b)
    return string.format("%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function ListPath(list, key)
    for _, e in ipairs(list) do if e[1] == key then return e[3] end end
end

local BAR_COLOR = { Alliance = "cAlliance", Horde = "cHorde", queue = "cQueue" }
local function BarColor(color) return RGB(BAR_COLOR[color] or "cOther") end

local function CappingLoaded()
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Capping") or false
end

---------------------------------------------------------------------------
-- Bars
---------------------------------------------------------------------------
local anchor
local pool, active = {}, {} -- active: [key] = { bar, ends, total, label, team }

local function Place()
    local p = db.point
    anchor:ClearAllPoints()
    anchor:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

local function TimeText(left)
    if left < 10 then return string.format("%.1f", left) end
    if left >= 60 then return string.format("%d:%02d", math.floor(left / 60), math.floor(left % 60)) end
    return string.format("%d", left)
end

-- Shift-click: /say, Ctrl-click: battleground chat (raid outside one), like Capping
local function Report(a)
    local channel = IsShiftKeyDown() and "SAY" or (IsControlKeyDown() and "INSTANCE_CHAT") or nil
    if not channel or a.paused then return end -- a waiting bar has no time to tell
    if channel == "INSTANCE_CHAT" and not (IsInGroup and IsInGroup(2)) then channel = "RAID" end
    local left = math.max(0, a.ends - GetTime())
    local t = TimeText(left)
    if not t:find("[:%.]") then t = "0:" .. t end
    local team = a.team == "Horde" and FACTION_HORDE or (a.team == "Alliance" and FACTION_ALLIANCE) or nil
    W.SendChat(a.label .. " - " .. t .. (team and (" (" .. team .. ")") or ""), channel)
end

-- the look of one bar from the settings: size, icon side, texture, fonts, colors, what is shown. Run on every bar
-- (active and pooled) by Restyle(), and on a pooled bar made before the last change (lookGen) when it starts
local lookGen = 0
local function Style(f)
    local w, h, icon, right = Look("width"), Look("height"), Look("icon"), Look("iconRight")
    f.look = lookGen
    f:SetSize(w, h)
    f.icon:SetSize(h, h)
    f.icon:ClearAllPoints()
    f.icon:SetPoint(right and "RIGHT" or "LEFT")
    f.icon:SetShown(icon)
    f.bar:ClearAllPoints()
    if not icon then
        f.bar:SetAllPoints()
    elseif right then
        f.bar:SetPoint("TOPLEFT")
        f.bar:SetPoint("BOTTOMRIGHT", f.icon, "BOTTOMLEFT")
    else
        f.bar:SetPoint("TOPLEFT", f.icon, "TOPRIGHT")
        f.bar:SetPoint("BOTTOMRIGHT")
    end
    local tex = ListPath(TEXTURES, Look("texture")) or TEXTURES[1][3]
    f.bar:SetStatusBarTexture(tex)
    f.bg:SetTexture(tex)
    local r, g, b = RGB("cBg")
    f.bg:SetVertexColor(r, g, b, 0.75)
    if f.data then f.bar:SetStatusBarColor(BarColor(f.data.color)) end
    local flags = Look("outline")
    if Look("mono") then flags = flags == "" and "MONOCHROME" or (flags .. ", MONOCHROME") end
    local font, size = ListPath(FONTS, Look("font")) or W.FONT, Look("fontSize")
    W.SetFont(f.text, font, size, flags)
    W.SetFont(f.time, font, size, flags)
    r, g, b = RGB("cText")
    f.text:SetTextColor(r, g, b)
    f.time:SetTextColor(r, g, b)
    -- the time at its side, the text on the rest of the bar (all of it without a time)
    local timeOn, timeLeft = Look("timeText"), Look("alignTime") == "LEFT"
    f.time:SetShown(timeOn)
    f.time:ClearAllPoints()
    f.time:SetPoint(timeLeft and "LEFT" or "RIGHT", timeLeft and 2 or -2, 0)
    f.text:ClearAllPoints()
    if timeOn and timeLeft then
        f.text:SetPoint("LEFT", f.time, "RIGHT", 2, 0)
        f.text:SetPoint("RIGHT", -2, 0)
    else
        f.text:SetPoint("LEFT", 2, 0)
        if timeOn then f.text:SetPoint("RIGHT", f.time, "LEFT", -2, 0) else f.text:SetPoint("RIGHT", -2, 0) end
    end
    f.text:SetJustifyH(Look("alignText"))
end

local function NewBar()
    local f = CreateFrame("Frame", nil, anchor)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    -- dragging a bar moves its pile: the normal one, or the middle one (emphasized bars)
    f:SetScript("OnDragStart", function(self)
        if db.locked then return end
        self.mover = self:GetParent()
        self.mover:StartMoving()
    end)
    f:SetScript("OnDragStop", function(self)
        local m = self.mover
        self.mover = nil
        if m then m:GetScript("OnDragStop")(m) end
    end)
    f:SetScript("OnMouseUp", function(self) if self.data then Report(self.data) end end)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.bar = CreateFrame("StatusBar", nil, f)
    f.bg = f.bar:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.time = f.bar:CreateFontString(nil, "OVERLAY")
    f.time:SetShadowOffset(1, -1)
    f.text = f.bar:CreateFontString(nil, "OVERLAY")
    f.text:SetShadowOffset(1, -1)
    f.text:SetWordWrap(false)
    Style(f)
    return f
end

-- BigWigs' "emphasize": in its last seconds a bar moves to the middle of the screen, larger, and a big
-- 5-4-3-2-1 (with the voice) counts the one that ends first
local EMPH_AT, EMPH_SCALE = 5, 1.5
local emphAnchor, bigCount
local function EmphAnchor()
    if emphAnchor then return emphAnchor end
    emphAnchor = CreateFrame("Frame", "WLRTCapTimersEmphasize", UIParent)
    emphAnchor:SetSize(Look("width"), Look("height"))
    local p = db.emphPoint or { "CENTER", "CENTER", 0, 120 }
    emphAnchor:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    emphAnchor:SetFrameStrata("HIGH")
    emphAnchor:SetClampedToScreen(true)
    emphAnchor:SetMovable(true) -- dragged through its bars (not locked); the big number moves with it
    emphAnchor:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, rel, x, y = self:GetPoint()
        db.emphPoint = { point, rel, x, y }
    end)
    -- the big number above the emphasized bars (an inner frame for W.Pulse, it grows in place)
    bigCount = CreateFrame("Frame", nil, emphAnchor)
    bigCount:SetSize(1, 1)
    bigCount:SetPoint("BOTTOM", emphAnchor, "TOP", 0, 40)
    bigCount.text = bigCount:CreateFontString(nil, "OVERLAY")
    W.SetFont(bigCount.text, W.COUNTDOWN_FONT, 56, "THICKOUTLINE") -- as BigWigs: Noto Sans, thick outline
    bigCount.text:SetPoint("CENTER")
    bigCount:Hide()
    return emphAnchor
end

local function Layout()
    local normal, emph = {}, {}
    for _, a in pairs(active) do
        if a.emph then emph[#emph + 1] = a else normal[#normal + 1] = a end
    end
    -- the queue bars stay on top of the pile (as Capping pins them), the others by the time left
    local function byEnd(x, y)
        if x.pinned ~= y.pinned then return x.pinned end
        return x.ends < y.ends
    end
    table.sort(normal, byEnd)
    table.sort(emph, byEnd)
    -- the pile hangs from its anchor (one bar high, so the base never moves with the count), down or up
    local step, up = Look("height") + Look("spacing"), Look("growUp")
    local function Stack(bars, holder, scale)
        for i, a in ipairs(bars) do
            a.bar:SetParent(holder)
            a.bar:SetScale(scale)
            a.bar:ClearAllPoints()
            if up then
                a.bar:SetPoint("BOTTOM", holder, "BOTTOM", 0, (i - 1) * step)
            else
                a.bar:SetPoint("TOP", holder, "TOP", 0, -(i - 1) * step)
            end
        end
    end
    Stack(normal, anchor, 1)
    if #emph > 0 then Stack(emph, EmphAnchor(), EMPH_SCALE) end
    -- shown while any bar runs, the emphasized ones too: its OnUpdate is the only timer of every bar, and a
    -- hidden frame gets no OnUpdate (a bar alone in the middle used to freeze at its last 5 seconds)
    anchor:SetShown(next(active) ~= nil)
end

-- a setting changed: every bar, active or pooled, takes the new look, the piles are rebuilt
local function Restyle()
    lookGen = lookGen + 1
    if anchor then anchor:SetSize(Look("width"), Look("height")) end
    if emphAnchor then emphAnchor:SetSize(Look("width"), Look("height")) end
    for _, a in pairs(active) do Style(a.bar) end
    for _, f in ipairs(pool) do Style(f) end
    if anchor then Layout() end
end

-- the bar drains by default; "fill" (Capping's option) makes it fill up as the time passes
local function BarValue(a, left)
    return Look("fill") and (a.total - left) or left
end

local function StopBar(key, noLayout)
    local a = active[key]
    if not a then return end
    a.bar:Hide()
    a.bar.data, a.bar.lastStep = nil, nil
    a.bar:SetParent(anchor)
    a.bar:SetScale(1)
    pool[#pool + 1] = a.bar
    active[key] = nil
    if not noLayout then Layout() end
end

-- every 0.1 s: bars entering their last seconds move to the middle; the soonest one is counted aloud
local function Emphasize(now)
    if not db.emphasize then return end
    local moved, first = false, nil
    for _, a in pairs(active) do
        local left = a.ends - now
        if not a.emph and left <= EMPH_AT and a.total > EMPH_AT + 1 and a.color ~= "queue" then
            a.emph, moved = true, true
        end
        if a.emph and (not first or a.ends < first.ends) then first = a end
    end
    if moved then Layout() end
    if not first or not db.bigCount then return end
    local n = math.ceil(first.ends - now)
    if n >= 1 and n <= EMPH_AT and n ~= first.lastN then
        first.lastN = n
        EmphAnchor()
        local c = { 1, 0, 0 } -- BigWigs' countdown red
        bigCount.text:SetText(n)
        bigCount.text:SetTextColor(c[1], c[2], c[3])
        W.Pulse(bigCount, 0.95)
        if db.voice then W.CountdownVoice(n) end
    end
end

local function StopMatching(prefix)
    local stopped = false
    for key in pairs(active) do
        if key:sub(1, #prefix) == prefix then StopBar(key, true); stopped = true end
    end
    if stopped then Layout() end
end

local acc = 0
local function OnUpdate(_, e)
    acc = acc + e
    if acc < 0.1 then return end
    acc = 0
    local now = GetTime()
    local stopped = false -- bars ending in the same tick: one Layout after the loop
    for key, a in pairs(active) do
        local left = a.ends - now
        if a.paused then
            a.ends = now + a.total -- a bar that waits (queue past its estimate): full, no time, never ends by itself
            a.bar.bar:SetValue(a.total)
        elseif left <= 0 then
            StopBar(key, true)
            stopped = true
        else
            a.bar.bar:SetValue(BarValue(a, left))
            -- the text changes every 0.1 s under 10 s, every second above: no new string in between
            local step = left < 10 and math.floor(left * 10) or -math.floor(left)
            if a.bar.lastStep ~= step then a.bar.lastStep = step; a.bar.time:SetText(TimeText(left)) end
        end
    end
    if stopped then Layout() end
    Emphasize(now)
end

local function CreateAnchor()
    if anchor then return end
    anchor = CreateFrame("Frame", "WLRTCapTimersAnchor", UIParent)
    anchor:SetSize(Look("width"), Look("height"))
    anchor:SetFrameStrata("MEDIUM")
    anchor:SetClampedToScreen(true)
    anchor:SetMovable(true)
    anchor:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, rel, x, y = self:GetPoint()
        db.point = { point, rel, x, y }
    end)
    anchor:SetScript("OnUpdate", OnUpdate)
    anchor:Hide()
    Place()
end

-- icon: a file ID, or { poi = texture index } for a map point icon
local function StartBar(key, label, secs, color, icon, team)
    if not secs or secs <= 0 then return end
    CreateAnchor()
    StopBar(key)
    local bar = table.remove(pool) or NewBar()
    if bar.look ~= lookGen then Style(bar) end
    bar.bar:SetStatusBarColor(BarColor(color))
    bar.bar:SetMinMaxValues(0, secs)
    bar.bar:SetValue(Look("fill") and 0 or secs)
    bar.text:SetText(label)
    bar.time:SetText("") -- a recycled bar keeps no old time (the first OnUpdate writes it, a paused bar never does)
    local poiCoords = (C_Minimap and C_Minimap.GetPOITextureCoords) or GetPOITextureCoords -- WoW Forever: C_Minimap only
    if type(icon) == "table" and icon.poi and poiCoords then
        bar.icon:SetTexture(POI_ICONS)
        local l, r, t, b = poiCoords(icon.poi)
        if l then bar.icon:SetTexCoord(l, r, t, b) end
    else
        bar.icon:SetTexture(icon or 134400)
        bar.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
    local a = { bar = bar, ends = GetTime() + secs, total = secs, label = label, team = team, color = color,
        pinned = key:sub(1, 6) == "queue:" }
    bar.data = a
    bar:Show()
    active[key] = a
    Layout()
    return a
end

---------------------------------------------------------------------------
-- Base captures (map points of interest)
---------------------------------------------------------------------------
local mapID, capTime, lastIcon = nil, 60, {}

local function POIs()
    local out = {}
    if not (mapID and C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap and C_AreaPoiInfo.GetAreaPOIInfo) then return out end
    for _, id in ipairs(C_AreaPoiInfo.GetAreaPOIForMap(mapID) or {}) do
        local info = C_AreaPoiInfo.GetAreaPOIInfo(mapID, id)
        if info then
            out[#out + 1] = { name = W.Safe(info.name), icon = W.Safe(info.textureIndex), atlas = W.Safe(info.atlasName), id = id }
        end
    end
    return out
end

-- first look: remember the icons without starting bars (an assault already running is not timed)
local function Snapshot()
    wipe(lastIcon)
    for _, p in ipairs(POIs()) do
        if p.name then lastIcon[p.name] = p.icon or p.atlas end
    end
end

local function POIsUpdated()
    -- the map was not known yet at the loading screen: read now, the icons seen first are only remembered
    if not mapID then
        mapID = C_Map and C_Map.GetBestMapForUnit and W.Safe(C_Map.GetBestMapForUnit("player"))
        if mapID then Snapshot() end
        return
    end
    for _, p in ipairs(POIs()) do
        local key = p.icon or p.atlas
        if p.name and key and lastIcon[p.name] ~= key then
            lastIcon[p.name] = key
            local team = p.icon and CONTESTED[p.icon]
            if team then
                StartBar("cap:" .. p.name, p.name, capTime, team, { poi = p.icon }, team)
            else
                StopBar("cap:" .. p.name) -- taken, or defended
            end
        end
    end
end

local poiEv = W.On("AREA_POIS_UPDATED", POIsUpdated, nil, true)

-- The battleground messages as a second source (a battleground whose map icons are not the known ones):
-- "X has assaulted the Farm!" starts the bar of that base in the color of the team the message comes from,
-- "taken" / "defended" stops it. The base is a map point name found in the message, else the words after
-- "assaulted the" / "attaqué". No second bar when the map already started it.
local ASSAULT = { "assault", "attaqu", "angegriffen", "asalt", "attacc", "атак" }
local STOP = { "taken", "claims", "pris", "prise", "eingenommen", "tomado", "conquist", "захват",
    "defend", "défend", "verteidigt", "difes", "защищ" }
local capOn = false

local function HasAny(text, words)
    for _, w in ipairs(words) do if text:find(w, 1, true) then return true end end
    return false
end

local function BaseFromMessage(text)
    for _, p in ipairs(POIs()) do
        if p.name and p.name ~= "" and text:find(p.name, 1, true) then return p.name, p.icon end
    end
    local base = text:match("assaulted the (.-)!") or text:match("attaqué[e]? ?l?a? ?l?e? ?(.-)%s*!")
    if base and base ~= "" and #base <= 40 then return base end
end

local function BaseMessage(text, team)
    text = W.Safe(text)
    if not capOn or type(text) ~= "string" then return end
    local lower = text:lower()
    local assault, stop = HasAny(lower, ASSAULT), HasAny(lower, STOP)
    if not assault and not stop then return end
    local base, icon = BaseFromMessage(text)
    if not base then return end
    local key = "cap:" .. base
    if stop then StopBar(key); return end
    local a = active[key]
    if a and GetTime() - (a.ends - a.total) < 5 then return end -- just started by the map
    StartBar(key, base, capTime, team, icon and { poi = icon } or 134420, team)
end
W.On("CHAT_MSG_BG_SYSTEM_HORDE", function(text) BaseMessage(text, "Horde") end)
W.On("CHAT_MSG_BG_SYSTEM_ALLIANCE", function(text) BaseMessage(text, "Alliance") end)

local function InstanceID()
    local _, kind, _, _, _, _, _, id = GetInstanceInfo()
    if kind ~= "pvp" then return nil end
    return W.Safe(id)
end

---------------------------------------------------------------------------
-- Gates, flag respawn, queue (left to Capping when it is loaded)
---------------------------------------------------------------------------
-- each of these bars has its own checkbox (db.queue, db.flag), the capture box does not switch them off
local function Extras() return db and not CappingLoaded() end

-- Enum.StartTimerType.PvPBeginTimer = 0
W.On("START_TIMER", function(timerType, timeSeconds)
    if not Extras() or not db.queue or W.Safe(timerType) ~= 0 then return end
    timeSeconds = W.Safe(timeSeconds)
    if type(timeSeconds) ~= "number" then return end
    -- Blizzard's own start timer bar would show the same countdown twice: hidden, as Capping does
    -- (once now, once right after in case Blizzard's handler runs after ours)
    local function HideBlizzardTimer()
        if TimerTracker and type(TimerTracker.timerList) == "table" then
            for _, timer in ipairs(TimerTracker.timerList) do
                if timer.bar then timer.bar:Hide() end
            end
        end
    end
    HideBlizzardTimer()
    W.After(0, HideBlizzardTimer)
    local a = active.gates
    local left = a and (a.ends - GetTime())
    if not a or timeSeconds >= 45 or math.abs(timeSeconds - left) > 1 then -- not restarted for a 1 s drift
        StartBar("gates", L("Battle begins"), timeSeconds, "other", 136106) -- Spell_Nature_TimeStop
    end
end)

local function FlagMessage(text)
    text = W.Safe(text)
    if not Extras() or not db.flag or type(text) ~= "string" or not InstanceID() then return end
    if text:find(CAPTURED, 1, true) then
        StartBar("flag", L("Flag respawns"), FLAG_RESPAWN, "other", 134420) -- INV_Misc_Rune_07
    end
end
W.On("CHAT_MSG_BG_SYSTEM_HORDE", FlagMessage)
W.On("CHAT_MSG_BG_SYSTEM_ALLIANCE", FlagMessage)
W.On("CHAT_MSG_BG_SYSTEM_NEUTRAL", FlagMessage)

-- the icon of a battleground's Mark of Honor, found by its name (English or French), for the queue bars
local QUEUE_MARKS = {
    { { "warsong", "chanteguerre" }, 20558 },
    { { "arathi" }, 20559 },
    { { "alterac" }, 20560 },
    { { "darkspear", "sombrelance" }, 274895, "Interface\\Icons\\INV_Misc_Rune_14" }, -- wowhead.com/forever
}
local function QueueIcon(mapName, default)
    local name = (mapName or ""):lower()
    for _, m in ipairs(QUEUE_MARKS) do
        for _, word in ipairs(m[1]) do
            if name:find(word, 1, true) then
                local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(m[2])
                if not icon and GetItemIcon then icon = GetItemIcon(m[2]) end
                return icon or m[3] or default
            end
        end
    end
    return default
end

W.On("UPDATE_BATTLEFIELD_STATUS", function(queueId)
    queueId = W.Safe(queueId)
    if not Extras() or not db.queue or not queueId or not GetBattlefieldStatus then return end
    local status, mapName = GetBattlefieldStatus(queueId)
    status, mapName = W.Safe(status), W.Safe(mapName) or "?"
    local key = "queue:" .. queueId
    if status == "confirm" then -- the battleground popped: time left to enter
        local a = active[key]
        local popped = a and a.color == "other" -- this pop already has its bar: a later status event, not a new pop
        local secs = GetBattlefieldPortExpiration and W.Safe(GetBattlefieldPortExpiration(queueId))
        if type(secs) == "number" and secs > 0 then
            StartBar(key, mapName, secs, "other", QueueIcon(mapName, 132327)) -- its mark, else Ability_TownWatch
            -- the pop heard with the sound effects off (Capping's "loud queue"): the game's own sound plays on the
            -- SFX channel only, ours on the Master channel, once per pop, and only when the game's would be silent
            if db.popSound and not popped and SOUNDKIT and SOUNDKIT.PVP_THROUGH_QUEUE
                and C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("Sound_EnableSFX") == "0" then
                pcall(PlaySound, SOUNDKIT.PVP_THROUGH_QUEUE, "Master")
            end
        end
    elseif status == "queued" and GetBattlefieldEstimatedWaitTime and GetBattlefieldTimeWaited then
        local est = (W.Safe(GetBattlefieldEstimatedWaitTime(queueId)) or 0) / 1000
        local waited = (W.Safe(GetBattlefieldTimeWaited(queueId)) or 0) / 1000
        local remain = est - waited
        local a = active[key]
        if remain > 1 and (not a or a.paused or math.abs(remain - (a.ends - GetTime())) > 10) then -- not restarted for a 10 s drift
            StartBar(key, mapName, remain, "queue", QueueIcon(mapName, 134400))
        elseif remain <= 1 and not (a and a.paused) then
            -- past the estimate, or a paused queue (estimate 0): a full grey bar without a time stays, as Capping
            -- shows it, instead of no bar at all
            local w = StartBar(key, mapName, 3600, "queue", QueueIcon(mapName, 134400))
            if w then w.paused = true end
        end
    elseif status == "none" or status == "active" then
        StopBar(key)
        if status == "active" then StopMatching("queue:") end
    end
end)

---------------------------------------------------------------------------
-- Time to win (Capping's Arathi score estimator, for any battleground with two "score/max" counters at the
-- top of the screen: Darkspear Island, Arathi...). The widget IDs and point rates of a battleground are not
-- needed: the two counters are found in the top widgets (Alliance first), and each team's rate is measured
-- between its score steps of the last 45 seconds. The bar: "Final: Alliance - Horde", until the winner reaches the max score.
---------------------------------------------------------------------------
local WIN_WINDOW = 45
local scoreWidgets, samples, winText = nil, { {}, {} }, nil
local scoreSearchAt = 0

-- the two score counters: { kind = "text" | "double", ids }
local function FindScoreWidgets()
    local UI = C_UIWidgetManager
    if not (UI and UI.GetTopCenterWidgetSetID and UI.GetAllWidgetsBySetID) then return nil end
    local setID = UI.GetTopCenterWidgetSetID()
    local ok, widgets = pcall(UI.GetAllWidgetsBySetID, setID)
    if not ok or type(widgets) ~= "table" then return nil end
    table.sort(widgets, function(a, b) return (a.orderIndex or 0) < (b.orderIndex or 0) end)
    local texts = {}
    for _, w in ipairs(widgets) do
        local id = w.widgetID
        if UI.GetDoubleStatusBarWidgetVisualizationInfo then
            local okD, d = pcall(UI.GetDoubleStatusBarWidgetVisualizationInfo, id)
            if okD and d and W.Safe(d.leftBarMax) and W.Safe(d.rightBarMax) then return { kind = "double", id = id } end
        end
        if UI.GetIconAndTextWidgetVisualizationInfo then
            local okT, t = pcall(UI.GetIconAndTextWidgetVisualizationInfo, id)
            local text = okT and t and W.Safe(t.text)
            -- a score counter ("1200/2000"), not a flag counter ("1/3"): the max is at least 100
            local max = type(text) == "string" and tonumber(text:match("%d+%s*/%s*(%d+)"))
            if max and max >= 100 then texts[#texts + 1] = id end
        end
        if #texts == 2 then return { kind = "text", ids = texts } end
    end
end

-- Alliance score, Horde score, max score
local function ReadScores()
    local UI = C_UIWidgetManager
    if not scoreWidgets and GetTime() >= scoreSearchAt then -- a map without them (Alterac): looked for every 5 s only
        scoreSearchAt = GetTime() + 5
        scoreWidgets = FindScoreWidgets()
    end
    local w = scoreWidgets
    if not w then return end
    if w.kind == "double" then
        local ok, d = pcall(UI.GetDoubleStatusBarWidgetVisualizationInfo, w.id)
        if not ok or not d then return end
        local a, h, max = W.Safe(d.leftBarValue), W.Safe(d.rightBarValue), W.Safe(d.leftBarMax)
        if type(a) == "number" and type(h) == "number" and type(max) == "number" and max > 0 then return a, h, max end
        return
    end
    local scores, max = {}, nil
    for i, id in ipairs(w.ids) do
        local ok, t = pcall(UI.GetIconAndTextWidgetVisualizationInfo, id)
        local text = ok and t and W.Safe(t.text)
        local s, m -- not "type(text) == 'string' and text:match()": "and" keeps only the first capture
        if type(text) == "string" then s, m = text:match("(%d+)%s*/%s*(%d+)") end
        scores[i], max = tonumber(s), tonumber(m) or max
    end
    if scores[1] and scores[2] and max and max > 0 then return scores[1], scores[2], max end
end

-- A team's score as ticks: only the moments the score changed are kept (scores go up by steps, a sample
-- between two steps would make the rate swing). Rate = points between the first and the last tick of the
-- last WIN_WINDOW seconds / the time between them. A team with no tick for that long scores nothing.
local function AddTick(list, score, now)
    local last = list[#list]
    if last and score == last.s then return end
    if last and score < last.s then wipe(list) end -- a new game, a reset
    list[#list + 1] = { t = now, s = score }
    while #list > 2 and now - list[1].t > WIN_WINDOW do table.remove(list, 1) end
end

-- rate (points / s) and the score projected to now; nil while not enough is known
local function TeamRate(list, now)
    local first, last = list[1], list[#list]
    if not last then return nil end
    if now - last.t > WIN_WINDOW then return 0, last.s end -- no base: no points
    if first == last or last.t - first.t < 5 then return nil end
    local rate = (last.s - first.s) / (last.t - first.t)
    return rate, last.s + rate * (now - last.t)
end

-- the win bar changes its text and end in place (no new bar on every tick)
local function SetWinBar(text, left, winner)
    local a = active.win
    if a and a.team == winner then
        a.label = text
        a.bar.text:SetText(text)
        a.ends = GetTime() + left
        if left > a.total then a.total = left; a.bar.bar:SetMinMaxValues(0, left) end
        return
    end
    StartBar("win", text, left, winner, winner == "Horde" and 132485 or 132486, winner) -- INV_BannerPVP_01 / _02
end

local lastWinRead = 0
local function UpdateWin()
    if not db or not db.win then return end
    local now = GetTime()
    if now - lastWinRead < 1 then return end
    lastWinRead = now
    local a, h, max = ReadScores()
    if not a then return end
    AddTick(samples[1], a, now)
    AddTick(samples[2], h, now)
    local ra, pa = TeamRate(samples[1], now)
    local rh, ph = TeamRate(samples[2], now)
    if not ra or not rh or (ra <= 0 and rh <= 0) then return end
    local ta = ra > 0 and math.max(0, (max - pa) / ra) or math.huge
    local th = rh > 0 and math.max(0, (max - ph) / rh) or math.huge
    local winner, left, fa, fh
    if ta <= th then
        winner, left = "Alliance", ta
        fa, fh = max, math.min(max - 10, 10 * math.floor((ph + rh * ta) / 10))
    else
        winner, left = "Horde", th
        fa, fh = math.min(max - 10, 10 * math.floor((pa + ra * th) / 10)), max
    end
    if left <= 1 or left > 3600 then return end
    local text = string.format(L("Final: %d - %d"), fa, fh)
    winText = text
    SetWinBar(text, left, winner)
end

local winEv = W.On("UPDATE_UI_WIDGET", UpdateWin, nil, true)

---------------------------------------------------------------------------
-- Zone
---------------------------------------------------------------------------
local ESTIMATOR_ZONES = { [529] = true, [2107] = true } -- Arathi: Capping has its own estimator
local function Zone()
    local inBG = db and InstanceID()
    local winOn = inBG and db.win and not (ESTIMATOR_ZONES[inBG] and CappingLoaded()) and true or false
    W.Activate(winEv, winOn)
    scoreWidgets, samples, winText = nil, { {}, {} }, nil
    scoreSearchAt = 0
    StopMatching("win")
    local id = db and db.enabled and InstanceID()
    local on = id and not (CAPPING_ZONES[id] and CappingLoaded())
    W.Activate(poiEv, on and true or false)
    capOn = on and true or false
    StopMatching("cap:")
    StopMatching("flag")
    if not InstanceID() then StopMatching("gates") end
    if not on then mapID = nil; return end
    capTime = ZONE_CAPTIME[id] or db.capTime or 60
    mapID = C_Map and C_Map.GetBestMapForUnit and W.Safe(C_Map.GetBestMapForUnit("player"))
    Snapshot()
end
W.On("PLAYER_ENTERING_WORLD", function() if anchor then StopMatching("cap:") end; Zone() end)
-- a new area inside the same battleground keeps the bars and the score samples
local lastZoneInstance
W.On("ZONE_CHANGED_NEW_AREA", function()
    local id = InstanceID()
    if id and id == lastZoneInstance then return end
    lastZoneInstance = id
    Zone()
end)
W.On("PLAYER_ENTERING_WORLD", function() lastZoneInstance = InstanceID() end)

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
local function MapDump()
    if not InstanceID() then W.Print(L("Not in a battleground.")); return end
    if not mapID then mapID = C_Map and C_Map.GetBestMapForUnit and W.Safe(C_Map.GetBestMapForUnit("player")) end
    local name, _, _, _, _, _, _, id = GetInstanceInfo()
    local lines = { "instance " .. tostring(W.Safe(id)) .. " " .. tostring(W.Safe(name)) .. ", uiMap " .. tostring(mapID) }
    for _, p in ipairs(POIs()) do
        lines[#lines + 1] = tostring(p.name) .. "  icon=" .. tostring(p.icon) .. "  atlas=" .. tostring(p.atlas) .. "  poi=" .. tostring(p.id)
    end
    -- the score counters the time to win reads
    local a, h, max = ReadScores()
    lines[#lines + 1] = "score: " .. tostring(a) .. " - " .. tostring(h) .. " / " .. tostring(max)
        .. (scoreWidgets and ("  (" .. scoreWidgets.kind .. " " .. tostring(scoreWidgets.id or table.concat(scoreWidgets.ids, ",")) .. ")") or "  (no counter found)")
    W.TextPopup(L("Map points now"), table.concat(lines, "\n"), { hint = "Ctrl+C" })
end

-- test bars: the pile, plus one bar kept in the middle for 20 s so the middle can be dragged, and one short bar
-- for the big countdown
function W.CapTimersTest()
    StartBar("test:a", "Test Alliance", 60, "Alliance", { poi = 3 }, "Alliance")
    StartBar("test:h", "Test Horde", 30, "Horde", { poi = 13 }, "Horde")
    StartBar("test:g", L("Battle begins"), 45, "other", 136106)
    StartBar("test:f", L("Flag respawns"), FLAG_RESPAWN, "other", 134420)
    local mid = StartBar("test:c", L("Middle bar (drag me)"), 20, "Alliance", { poi = 3 }, "Alliance")
    if mid then mid.emph = true; Layout() end
    StartBar("test:e", "Test", 8, "Horde", { poi = 13 }, "Horde")
end
W.RegisterTest("Battleground timers", function() return db and (db.enabled or db.queue or db.flag) end, W.CapTimersTest,
    function() StopMatching("test:"); if bigCount then bigCount:Hide() end end)

-- The game's color picker (as PvP.lua's, local here: that file is edited in another session). onChange(r, g, b) on
-- every change, and with the old color on cancel.
local function PickColor(r, g, b, onChange)
    local CPF = ColorPickerFrame
    if not CPF then return end
    local function current()
        local ok, nr, ng, nb = pcall(CPF.GetColorRGB, CPF)
        if ok and nr then onChange(nr, ng, nb) end
    end
    if CPF.SetupColorPickerAndShow then
        CPF:SetupColorPickerAndShow({ r = r, g = g, b = b, hasOpacity = false,
            swatchFunc = current, cancelFunc = function() onChange(r, g, b) end })
    else
        CPF.hasOpacity = false
        CPF.previousValues = { r, g, b }
        CPF.func = current
        CPF.cancelFunc = function() onChange(r, g, b) end
        CPF:SetColorRGB(r, g, b)
        CPF:Hide()
        CPF:Show()
    end
end

local function BuildTimers(t)
    W.Check(t, L("Base capture timers"), function() return db.enabled end,
        function(v) db.enabled = v; Zone() end):SetPoint("TOPLEFT", 12, -4)
    W.Check(t, L("Battle start and queue bars"), function() return db.queue end, function(v)
        db.queue = v
        if not v then StopMatching("queue:"); StopMatching("gates") end -- a waiting bar never ends by itself
    end):SetPoint("TOPLEFT", 12, -28)
    W.Check(t, L("Flag respawn after a capture"), function() return db.flag end, function(v) db.flag = v end):SetPoint("TOPLEFT", 12, -52)
    W.Check(t, L("BigWigs style: the bar moves to the middle for its last 5 seconds"), function() return db.emphasize end,
        function(v) db.emphasize = v end):SetPoint("TOPLEFT", 330, -28)
    W.Check(t, L("Big 5-4-3-2-1 countdown"), function() return db.bigCount end, function(v) db.bigCount = v end)
        :SetPoint("TOPLEFT", 350, -52)
    W.Check(t, L("Voice countdown"), function() return db.voice end, function(v) db.voice = v end):SetPoint("TOPLEFT", 350, -76)
    -- right of the capture-time drop-down (280 to 360 at -107)
    W.Check(t, L("Queue pop sound with sound effects off"), function() return db.popSound end,
        function(v) db.popSound = v end):SetPoint("TOPLEFT", 380, -104)
    W.Cycle(t, 130, W.CountdownVoiceValues(), function() return W.DB("ui").countdownVoice or "auto" end,
        function(v) W.DB("ui").countdownVoice = v; W.CountdownVoice(3) end):SetPoint("TOPLEFT", 520, -76)
    W.Check(t, L("Time to win (final score estimate)"), function() return db.win end, function(v) db.win = v; Zone() end)
        :SetPoint("TOPLEFT", 330, -4)
    W.Check(t, L("Lock the bars"), function() return db.locked end, function(v) db.locked = v end):SetPoint("TOPLEFT", 12, -76)
    W.Label(t, L("Capture time (other battlegrounds):"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 16, -112)
    local times = {}
    for _, s in ipairs({ 30, 45, 60, 64, 90, 120, 240, 300 }) do times[#times + 1] = { s, string.format(L("%d s"), s) } end
    W.Cycle(t, 80, times, function() return db.capTime end, function(v) db.capTime = v end):SetPoint("TOPLEFT", 280, -107)
    W.Button(t, L("Test"), 110, 22, function() W.CapTimersTest() end):SetPoint("TOPLEFT", 16, -142)
    W.Button(t, L("Reset position"), 160, 22, function()
        db.point, db.emphPoint = { "TOP", "TOP", 0, -150 }, nil
        if anchor then Place() end
        if emphAnchor then
            emphAnchor:ClearAllPoints()
            emphAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
        end
    end):SetPoint("TOPLEFT", 132, -142)
    W.Button(t, L("Map points now"), 200, 22, MapDump):SetPoint("TOPLEFT", 298, -142)
    local info = W.Label(t, L("A base assaulted (map icon contested) gets a bar until it is taken: Alterac 5 min, Arathi 1 min, other battlegrounds the time chosen here. Shift-click a bar: /say, Ctrl-click: battleground chat. If a battleground shows no bar, open \"Map points now\" during an assault and send the text."),
        "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, -180)
    info:SetWidth(700)
    info:SetJustifyH("LEFT")
    info:SetTextColor(0.7, 0.7, 0.7)
    local capping = W.Label(t, L("Capping is loaded: it keeps its queue, gates, flag and Arathi / Alterac bars, these are only for the other battlegrounds."),
        "GameFontNormalSmall")
    capping:SetPoint("TOPLEFT", 16, -234)
    capping:SetWidth(700)
    capping:SetJustifyH("LEFT")
    t:HookScript("OnShow", function() capping:SetShown(CappingLoaded()) end)
end

-- Capping's appearance options: lists (W.Cycle), check boxes, one color square per color, a reset
local function BuildAppearance(t)
    local widgets = {} -- re-read after "Default appearance"
    local function Add(w) widgets[#widgets + 1] = w; return w end
    local function Set(key) return function(v) db[key] = v; Restyle() end end
    local function Get(key) return function() return Look(key) end end
    local function Choices(list)
        local out = {}
        for _, e in ipairs(list) do
            if type(e) == "table" then out[#out + 1] = { e[1], L(e[2]) } else out[#out + 1] = { e, tostring(e) } end
        end
        return out
    end
    local function Cycle(label, key, list, x, y, w)
        W.Label(t, L(label), "GameFontHighlightSmall"):SetPoint("TOPLEFT", x, y - 5)
        Add(W.Cycle(t, w, Choices(list), Get(key), Set(key))):SetPoint("TOPLEFT", x + 60, y)
    end
    Cycle("Texture:", "texture", TEXTURES, 16, -4, 120)
    Cycle("Font:", "font", FONTS, 210, -4, 120)
    Cycle("Size:", "fontSize", FONT_SIZES, 404, -4, 60)
    Cycle("Outline:", "outline", OUTLINES, 538, -4, 120)
    Cycle("Width:", "width", WIDTHS, 16, -34, 70)
    Cycle("Height:", "height", HEIGHTS, 210, -34, 60)
    Cycle("Spacing:", "spacing", SPACINGS, 404, -34, 60)
    Cycle("Text:", "alignText", ALIGNS, 16, -64, 90)
    Cycle("Time:", "alignTime", SIDES, 210, -64, 90)
    local function Check(label, key, x, y)
        Add(W.Check(t, L(label), Get(key), Set(key))):SetPoint("TOPLEFT", x, y)
    end
    Check("Show the icon", "icon", 12, -96)
    Check("Icon on the right", "iconRight", 160, -96)
    Check("Show the time", "timeText", 330, -96)
    Check("Bars fill up", "fill", 480, -96)
    Check("Grow upwards", "growUp", 12, -120)
    Check("Monochrome font", "mono", 160, -120)
    W.Label(t, L("Colors:"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 16, -156)
    local function Swatch(key, label, x)
        local b
        local function Paint() b.color:SetVertexColor(RGB(key)) end
        b = W.Button(t, "", 22, 22, function()
            local r, g, bl = RGB(key)
            PickColor(r, g, bl, function(nr, ng, nb) db[key] = Hex(nr, ng, nb); Paint(); Restyle() end)
        end)
        b:SetPoint("TOPLEFT", x, -150)
        b.color = b:CreateTexture(nil, "OVERLAY")
        b.color:SetTexture(W.WHITE)
        b.color:SetPoint("TOPLEFT", 4, -4)
        b.color:SetPoint("BOTTOMRIGHT", -4, 4)
        b.Sync = Paint
        Paint()
        b:HookScript("OnShow", Paint)
        W.Label(t, label, "GameFontHighlightSmall"):SetPoint("LEFT", b, "RIGHT", 4, 0)
        return Add(b)
    end
    Swatch("cText", L("Text"), 80)
    Swatch("cBg", L("Background"), 180)
    Swatch("cAlliance", FACTION_ALLIANCE or "Alliance", 300)
    Swatch("cHorde", FACTION_HORDE or "Horde", 400)
    Swatch("cQueue", L("Queue"), 500)
    Swatch("cOther", L("Other"), 620)
    W.Button(t, L("Default appearance"), 160, 22, function()
        for k, v in pairs(LOOK_DEFAULTS) do db[k] = v end
        Restyle()
        for _, w in ipairs(widgets) do w:Sync() end
    end):SetPoint("TOPLEFT", 16, -186)
    W.Button(t, L("Test"), 110, 22, function() W.CapTimersTest() end):SetPoint("TOPLEFT", 182, -186)
    local info = W.Label(t, L("Click a square to change its color. Test shows bars while you adjust."), "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, -220)
    info:SetWidth(700)
    info:SetJustifyH("LEFT")
    info:SetTextColor(0.7, 0.7, 0.7)
end

local tabs
W.RegisterModule("CapTimers", L("Battleground timers"), function(p)
    W.Title(p, L("Battleground timers"))
    tabs = W.SubTabs(p, { L("Timers"), L("Appearance") })
    BuildTimers(tabs.frames[1])
    BuildAppearance(tabs.frames[2])
    tabs:Select(1)
end, function()
    if tabs then tabs:Select(tabs.current or 1) end
end)

-- the bench (tools/smoke/battleground.lua) changes the look and checks the bars
W.CapTimersRestyle = Restyle

W.slash.caps = function() W.Toggle("CapTimers") end
