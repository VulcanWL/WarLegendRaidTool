-- WarLegend RaidTool - Transports
-- Boats, zeppelins and trams on the world map and the minimap, with their schedules (the idea and the route data of
-- NauticusClassicResurrected, MIT, psynct). There is no API for the schedules: the cycle of a transport is learned when I
-- ride it (trigger points along the route) or received from guild members (GUILD, prefix WLRT_TRANSP). Everything stops
-- in battlegrounds / arenas / dungeons and when the option is off: the driver frame is hidden, so nothing runs.
local W = WLRT
W.AddFR({
    ["Transports"] = "Transports",
    ["Boats, zeppelins and trams"] = "Bateaux, zeppelins et tramways",
    ["Show the transports (map icons and schedules)"] = "Afficher les transports (icônes et horaires)",
    ["Transports on the world map"] = "Transports sur la carte du monde",
    ["Transports on the minimap"] = "Transports sur la minicarte",
    ["Only my faction and the neutral ones"] = "Seulement ma faction et les neutres",
    ["Share the schedules with the guild"] = "Partager les horaires avec la guilde",
    ["Forget the schedules"] = "Oublier les horaires",
    ["Forget every learned schedule?"] = "Oublier tous les horaires appris ?",
    ["Transport"] = "Transport",
    ["Status"] = "État",
    ["unknown: ride it once"] = "inconnu : prends-le une fois",
    ["docked at %s, leaves in %s"] = "à quai à %s, part dans %s",
    ["next: %s in %s"] = "prochain : %s dans %s",
    ["Leaves %s in %s"] = "Part de %s dans %s",
    ["Learned by me"] = "Appris par moi",
    ["Received from the guild"] = "Reçu de la guilde",
    ["Off in battlegrounds, arenas and dungeons. A schedule is learned by riding the transport once, or received from guild members who did. The icons show the transports of the zone you are in on the minimap, and every known one on the world map."] =
        "Désactivé en champ de bataille, en arène et en donjon. Un horaire s'apprend en prenant le transport une fois, ou se reçoit des membres de la guilde qui l'ont fait. La minicarte montre les transports de la zone où tu es, la carte du monde tous ceux qui sont connus.",
    ["Route data and idea: NauticusClassicResurrected (MIT license, psynct)."] =
        "Données de routes et idée : NauticusClassicResurrected (licence MIT, psynct).",
})
local L = W.L
local db

local PREFIX = "WLRT_TRANSP"
local REF = "WLRTTransports"
local TRIGGER_TICK, DRAW_TICK = 0.8, 0.25
local MOVING, FAST, COOLDOWN = 6.16, 17.0, 30 -- yards per trigger tick, as Nauticus
local MAX_AGE = 90 * 86400
-- the Azeroth map fractions of the routes are stored against the Classic rectangles of the two continents
local RECT = {
    [0] = { 44688.53, 29795.11, 32601.04, 9894.93 }, -- Eastern Kingdoms
    [1] = { 44878.66, 29916.10, 8723.96, 14824.53 }, -- Kalimdor
}

local HBD, Pins

---------------------------------------------------------------------------
-- Clock: the server time (shared by every player) with the precision of GetTime
---------------------------------------------------------------------------
local base = 0
local function Now()
    if base == 0 then base = GetServerTime() - GetTime() end
    return base + GetTime()
end

local cal = CreateFrame("Frame")
cal:Hide()
cal:SetScript("OnUpdate", function(self)
    local s = GetServerTime()
    if self.last and s ~= self.last then
        base = s - GetTime() -- the second just changed: exact to one frame
        self:Hide()
    else
        self.last = self.last or s
    end
end)

---------------------------------------------------------------------------
-- Routes (decoded when first needed)
---------------------------------------------------------------------------
local routes = {}
local zoneMap

local function Route(id)
    local r = routes[id]
    if r then return r end
    local d = W.TransportData and W.TransportData[id]
    if not d then return nil end
    r = { d = d, x = {}, y = {}, t = {}, plat = {}, trig = {}, zone = {}, jump = {}, raw = {} }
    local n = 0
    for item in string.gmatch(d.pts, "[^;]+") do
        n = n + 1
        local coords, flags = strsplit("|", item)
        local x, y, t = strsplit(",", coords)
        r.x[n], r.y[n], r.t[n] = tonumber(x), tonumber(y), tonumber(t)
        if flags then
            for letter, num in string.gmatch(flags, "(%a)(%d*)") do
                if letter == "p" then r.plat[tonumber(num)] = n
                elseif letter == "t" then r.trig[#r.trig + 1] = n
                elseif letter == "z" then r.zone[n] = true
                elseif letter == "j" then r.jump[n] = true
                elseif letter == "r" then r.raw[n] = true end
            end
        end
    end
    r.n = n
    r.t[0] = 0
    r.t[n] = d.rtt
    r.idx = 1
    routes[id] = r
    return r
end

local function ZoneTransports(mapID)
    if not zoneMap then
        zoneMap = {}
        for id, d in pairs(W.TransportData or {}) do
            for _, z in ipairs(d.zones) do
                zoneMap[z] = zoneMap[z] or {}
                zoneMap[z][id] = true
            end
        end
    end
    return zoneMap[mapID]
end

-- world coordinates of point i of a route, seen from the continent `inst`
local function PointWorld(id, i, inst)
    local r = Route(id)
    local d = r.d
    if r.raw[i] then
        if inst == d.raw then return r.x[i], r.y[i] end
        return nil
    elseif d.coords < 0 then
        local rc = RECT[inst]
        if not rc then return nil end
        return rc[3] - rc[1] * r.x[i], rc[4] - rc[2] * r.y[i]
    end
    if inst == d.coords then return r.x[i], r.y[i] end
    return nil
end

-- cycle position (seconds) -> index of the next point, x, y of the transport
local function Where(id, c)
    local r = Route(id)
    local t = r.t
    local i = r.idx
    if i > r.n or (i > 1 and t[i - 1] > c) then i = 1 end
    while i < r.n and t[i] <= c do i = i + 1 end
    r.idx = i
    if i == 1 then return i, r.x[1], r.y[1] end
    local f = (c - t[i - 1]) / (t[i] - t[i - 1])
    return i, r.x[i - 1] + (r.x[i] - r.x[i - 1]) * f, r.y[i - 1] + (r.y[i] - r.y[i - 1]) * f
end

---------------------------------------------------------------------------
-- Known cycles: db["c<id>"] = start of a cycle (server time), db["a<id>"] = when it was observed, db["o<id>"] = 1 when mine
---------------------------------------------------------------------------
local function Known(id) return db and type(db["c" .. id]) == "number" and db["c" .. id] or nil end

local function CycleOf(id)
    local t0 = Known(id)
    if not t0 then return nil end
    local rtt = Route(id).d.rtt
    local c = (Now() - t0) % rtt
    return c, rtt
end

local lastShare = 0
local function Share(own)
    if not db or not db.share or not IsInGuild() or W.InPvP() then return end
    local parts = {}
    for id in pairs(W.TransportData or {}) do
        local t0, a = Known(id), db["a" .. id]
        if t0 and type(a) == "number" and (not own or db["o" .. id] == 1) then
            parts[#parts + 1] = string.format("%d=%.2f@%d", id, t0, a)
        end
    end
    if #parts > 0 and GetTime() - lastShare > 5 then
        lastShare = GetTime()
        W.Send(PREFIX, table.concat(parts, ";"), "GUILD")
    end
end

local function SetCycle(id, t0, observed, mine)
    local rtt = Route(id).d.rtt
    local now = Now()
    t0 = t0 + math.floor((now - t0) / rtt) * rtt -- the most recent start: small numbers, same phase
    db["c" .. id], db["a" .. id], db["o" .. id] = t0, observed, mine and 1 or 0
    if mine then Share(true) end
end

W.OnAddon(PREFIX, function(msg, _, channel, full)
    if channel ~= "GUILD" or type(msg) ~= "string" or #msg > 400 or not db or not db.share or not db.on then return end
    if W.IsOff("GuildPositions") or W.InPvP() then return end
    if full and full == W.UnitFullName("player") then return end
    local now = Now()
    for item in string.gmatch(msg, "[^;]+") do
        local id, t0, a = string.match(item, "^(%d+)=([%d%.]+)@(%d+)$")
        id, t0, a = tonumber(id), tonumber(t0), tonumber(a)
        if id and t0 and a and W.TransportData[id] and a <= now + 60 and a > now - MAX_AGE and t0 > 1.5e9 and t0 < now + 60 then
            local mine = db["a" .. id]
            if not (type(mine) == "number" and mine >= a) then SetCycle(id, t0, a, false) end
        end
    end
end)

---------------------------------------------------------------------------
-- Learning: standing on a transport, crossing a trigger point of its route gives the cycle
---------------------------------------------------------------------------
local function CurrentMap()
    local id = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if id == 1414 or id == 1415 then return nil end
    if not id or id == 0 then id = select(8, GetInstanceInfo()) end
    return id
end

local function SameSign(a, b) return (a >= 0) == (b >= 0) end

local ox, oy, lastTrig
local function Learn(dt)
    local zt = ZoneTransports(CurrentMap())
    if not zt then ox, oy = nil, nil; return end
    local x, y, inst = HBD:GetPlayerWorldPosition()
    if not (x and y) then ox, oy = nil, nil; return end
    local px, py = ox, oy
    ox, oy = x, y
    if not px then return end
    local dx, dy = x - px, y - py
    local dist = math.sqrt(dx * dx + dy * dy) * TRIGGER_TICK / dt -- per standard tick
    if dist <= MOVING or (lastTrig and GetTime() - lastTrig < COOLDOWN) then return end
    if IsSwimming() or UnitOnTaxi("player") then return end
    for id in pairs(zt) do
        local r = Route(id)
        for _, i in ipairs(r.trig) do
            if i >= 2 then
                local tx, ty = PointWorld(id, i, inst)
                local qx, qy = PointWorld(id, i - 1, inst)
                if tx and qx then
                    local ex, ey = x - tx, y - ty
                    if math.sqrt(ex * ex + ey * ey) < 20 and (not r.d.dirx or SameSign(dx, tx - qx)) then
                        if dist > FAST then
                            local dpl = math.sqrt((x - qx) ^ 2 + (y - qy) ^ 2)
                            local seg = math.sqrt((tx - qx) ^ 2 + (ty - qy) ^ 2)
                            if seg > 0 then
                                local step = r.t[i] - r.t[i - 1]
                                local sum = r.t[i] - step + step * (dpl / seg)
                                local now = Now()
                                SetCycle(id, now - sum, now, true)
                                lastTrig = GetTime()
                            end
                        end
                        return
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Pins
---------------------------------------------------------------------------
local TEXTURE = "Interface\\Minimap\\Tracking\\FlightMaster"
local COLORS = { Horde = { 1, 0.45, 0.4 }, Alliance = { 0.5, 0.7, 1 }, Neutral = { 1, 0.9, 0.45 } }
local pinsOf = {} -- [id] = { world = frame, mini = frame }

local function Plain(s)
    if W.LANG ~= "fr" then return s end
    return (string.gsub(s, "[^,<>]+", function(piece)
        local key = strtrim(piece)
        local fr = W.TransportNamesFR and W.TransportNamesFR[key]
        if not fr then return piece end
        fr = string.gsub(fr, " %(.-%)$", "")
        return (string.gsub(piece, "%S.*%S", fr, 1))
    end))
end

local function Mm(sec)
    sec = math.max(0, math.floor(sec + 0.5))
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

-- "docked at X, leaves in 0:35" / "next: X in 2:10", and the list of platforms
local function Status(id)
    local c = CycleOf(id)
    local r = Route(id)
    if not c then return nil end
    local d = r.d
    local best, bestIn, dockedAt, leaves
    local lines = {}
    for k, name in ipairs(d.plats) do
        local i = r.plat[k]
        if i then
            local arrive, depart = r.t[i - 1], r.t[i]
            local place = Plain((string.match(name, "^([^,]+)") or name))
            if c >= arrive and c < depart then
                dockedAt, leaves = place, depart - c
                lines[#lines + 1] = string.format(L("Leaves %s in %s"), place, Mm(depart - c))
            else
                local wait = (arrive - c) % d.rtt
                lines[#lines + 1] = string.format(L("next: %s in %s"), place, Mm(wait))
                if not bestIn or wait < bestIn then best, bestIn = place, wait end
            end
        end
    end
    if dockedAt then return string.format(L("docked at %s, leaves in %s"), dockedAt, Mm(leaves)), lines end
    if best then return string.format(L("next: %s in %s"), best, Mm(bestIn)), lines end
    return nil
end

local function OnEnter(self)
    local id = self.id
    local d = W.TransportData[id]
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(Plain(d.vessel), unpack(COLORS[d.faction] or COLORS.Neutral))
    GameTooltip:AddLine(Plain(d.name), 1, 1, 1)
    local _, lines = Status(id)
    if lines then
        for _, line in ipairs(lines) do GameTooltip:AddLine(line, 0.8, 0.8, 0.8) end
    end
    GameTooltip:Show()
end

local function NewPin(id)
    local f = CreateFrame("Frame", nil, UIParent)
    f.id = id
    f:EnableMouse(true)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    f.icon:SetTexture(TEXTURE)
    local col = COLORS[W.TransportData[id].faction] or COLORS.Neutral
    f.icon:SetVertexColor(col[1], col[2], col[3])
    f:SetScript("OnEnter", OnEnter)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:SetSize(db.size or 18, db.size or 18)
    return f
end

local function Clear(id)
    local p = pinsOf[id]
    if not p then return end
    if p.world and p.world.at then Pins:RemoveWorldMapIcon(REF, p.world); p.world.at = nil; p.world:Hide() end
    if p.mini and p.mini.at then Pins:RemoveMinimapIcon(REF, p.mini); p.mini.at = nil; p.mini:Hide() end
end

local function ClearAll()
    if not Pins then return end
    for id in pairs(pinsOf) do Clear(id) end
end

local function Put(id, kind, inst, x, y)
    local p = pinsOf[id]
    if not p then p = {}; pinsOf[id] = p end
    local f = p[kind]
    if not f then f = NewPin(id); p[kind] = f end
    if f.inst == inst and f.px == x and f.py == y and f.at then return end
    f.inst, f.px, f.py = inst, x, y
    if kind == "world" then
        if f.at then Pins:RemoveWorldMapIcon(REF, f) end
        Pins:AddWorldMapIconWorld(REF, f, inst, x, y, HBD_PINS_WORLDMAP_SHOW_CONTINENT or 2)
    else
        Pins:AddMinimapIconWorld(REF, f, inst, x, y, true)
    end
    f.at = true
    f:Show()
end

local function Draw()
    local worldShown = db.world and WorldMapFrame and WorldMapFrame:IsShown()
    local zt = db.minimap and ZoneTransports(CurrentMap())
    if not worldShown and not zt then ClearAll(); return end
    local faction = UnitFactionGroup("player")
    local _, _, pinst
    if zt then _, _, pinst = HBD:GetPlayerWorldPosition() end
    for id, d in pairs(W.TransportData) do
        local c = CycleOf(id)
        if c and (not db.faction or d.faction == faction or d.faction == "Neutral") then
            local i, x, y = Where(id, c)
            local r = Route(id)
            local winst, wx, wy
            if r.jump[i] then
                Clear(id)
            else
                if r.raw[i] then
                    winst, wx, wy = d.raw, x, y
                elseif d.coords < 0 then
                    winst = x < 0.5 and 1 or 0
                    local rc = RECT[winst]
                    wx, wy = rc[3] - rc[1] * x, rc[4] - rc[2] * y
                else
                    winst, wx, wy = d.coords, x, y
                end
                if worldShown and winst ~= d.coords then
                    Put(id, "world", winst, wx, wy)
                elseif pinsOf[id] and pinsOf[id].world and pinsOf[id].world.at then
                    Pins:RemoveWorldMapIcon(REF, pinsOf[id].world)
                    pinsOf[id].world.at = nil
                    pinsOf[id].world:Hide()
                end
                if zt and zt[id] and winst == pinst then
                    Put(id, "mini", winst, wx, wy)
                elseif pinsOf[id] and pinsOf[id].mini and pinsOf[id].mini.at then
                    Pins:RemoveMinimapIcon(REF, pinsOf[id].mini)
                    pinsOf[id].mini.at = nil
                    pinsOf[id].mini:Hide()
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Driver: one hidden frame, shown only when the module has work to do (never in PvP, arenas and dungeons)
---------------------------------------------------------------------------
local driver = CreateFrame("Frame")
driver:Hide()
local accL, accD = 0, 0
driver:SetScript("OnUpdate", function(_, el)
    accL, accD = accL + el, accD + el
    if accD >= DRAW_TICK then
        accD = 0
        local ok, err = W.Measure("transports draw", Draw)
        if not ok then geterrorhandler()(err) end
    end
    if accL >= TRIGGER_TICK then
        local dt = accL
        accL = 0
        local ok, err = W.Measure("transports learn", Learn, dt)
        if not ok then geterrorhandler()(err) end
    end
end)

local function Refresh()
    local _, kind = IsInInstance()
    local want = db and db.on and HBD and Pins and W.Allowed() and not W.IsOff("GuildPositions")
        and not W.InPvP() and kind ~= "party" and kind ~= "raid"
    if want then
        if not driver:IsShown() then
            ox, oy = nil, nil
            accL, accD = 0, 0
            driver:Show()
        end
    elseif driver:IsShown() or next(pinsOf) then
        driver:Hide()
        ClearAll()
    end
end

W.OnReady(function()
    db = W.DB("transports", { on = true, world = true, minimap = true, faction = true, share = true, size = 18 })
end)

W.On("PLAYER_LOGIN", function()
    if LibStub then
        HBD = LibStub("HereBeDragons-2.0-gm", true)
        Pins = LibStub("HereBeDragons-Pins-2.0-gm", true)
    end
    base = GetServerTime() - GetTime()
    cal:Show()
end)
W.On("PLAYER_ENTERING_WORLD", function()
    Refresh()
    if not W.transportsShared then
        W.transportsShared = true
        W.After(20 + math.random() * 20, function() Share(false) end)
    end
end)
W.On("ZONE_CHANGED_NEW_AREA", Refresh)

---------------------------------------------------------------------------
-- Options and schedules (a tab of the Guild map page)
---------------------------------------------------------------------------
function W.TransportsPanel(f)
    W.Label(f, L("Boats, zeppelins and trams"), "GameFontNormalLarge"):SetPoint("TOPLEFT", 16, -8)
    W.Check(f, L("Show the transports (map icons and schedules)"), function() return db.on end,
        function(v) db.on = v; Refresh() end):SetPoint("TOPLEFT", 12, -34)
    W.Check(f, L("Transports on the world map"), function() return db.world end,
        function(v) db.world = v; ClearAll() end):SetPoint("TOPLEFT", 32, -58)
    W.Check(f, L("Transports on the minimap"), function() return db.minimap end,
        function(v) db.minimap = v; ClearAll() end):SetPoint("TOPLEFT", 32, -82)
    W.Check(f, L("Only my faction and the neutral ones"), function() return db.faction end,
        function(v) db.faction = v; ClearAll() end):SetPoint("TOPLEFT", 32, -106)
    W.Check(f, L("Share the schedules with the guild"), function() return db.share end,
        function(v) db.share = v; if v then Share(false) end end):SetPoint("TOPLEFT", 32, -130)
    W.Button(f, L("Forget the schedules"), 150, 22, function()
        W.Confirm(L("Forget every learned schedule?"), function()
            for id in pairs(W.TransportData) do db["c" .. id], db["a" .. id], db["o" .. id] = nil, nil, nil end
            ClearAll()
        end)
    end):SetPoint("TOPLEFT", 400, -34)

    local rows = {}
    local ids = {}
    for id in pairs(W.TransportData) do ids[#ids + 1] = id end
    table.sort(ids)
    for k, id in ipairs(ids) do
        local d = W.TransportData[id]
        local name = W.Label(f, "", "GameFontHighlightSmall")
        name:SetPoint("TOPLEFT", 16, -162 - (k - 1) * 17)
        name:SetWidth(330)
        name:SetJustifyH("LEFT")
        local st = W.Label(f, "", "GameFontHighlightSmall")
        st:SetPoint("TOPLEFT", 360, -162 - (k - 1) * 17)
        st:SetWidth(340)
        st:SetJustifyH("LEFT")
        rows[k] = { id = id, name = name, st = st, d = d }
    end
    local info = W.Label(f, L("Off in battlegrounds, arenas and dungeons. A schedule is learned by riding the transport once, or received from guild members who did. The icons show the transports of the zone you are in on the minimap, and every known one on the world map."),
        "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, -170 - #ids * 17)
    info:SetWidth(680)
    info:SetJustifyH("LEFT")
    info:SetTextColor(0.7, 0.7, 0.7)
    local credit = W.Label(f, L("Route data and idea: NauticusClassicResurrected (MIT license, psynct)."), "GameFontHighlightSmall")
    credit:SetPoint("TOPLEFT", 16, -214 - #ids * 17)
    credit:SetTextColor(0.5, 0.5, 0.5)

    local acc = 0.5
    local function Update()
        for _, row in ipairs(rows) do
            local col = COLORS[row.d.faction] or COLORS.Neutral
            row.name:SetText(string.format("|cff%02x%02x%02x%s|r  %s", col[1] * 255, col[2] * 255, col[3] * 255,
                Plain(row.d.vessel), Plain(row.d.name)))
            local text = Status(row.id)
            if text then
                row.st:SetText(text)
                row.st:SetTextColor(0.5, 1, 0.5)
            else
                row.st:SetText(L("unknown: ride it once"))
                row.st:SetTextColor(0.55, 0.55, 0.55)
            end
        end
    end
    f:SetScript("OnShow", function() acc = 0.5; Update() end)
    f:SetScript("OnUpdate", function(_, el)
        acc = acc + el
        if acc >= 1 then acc = 0; Update() end
    end)
end
