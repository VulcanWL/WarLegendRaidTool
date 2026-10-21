-- WarLegend RaidTool - Danger alert (the idea of HighLevelAlert)
-- In the open world, a warning at the top of the screen and a sound when a nameplate shows an enemy player
-- flagged for PvP, a "skull" mob (10+ levels above me) or a red elite (3+ levels). Counts what is near.
-- Cost: one look per nameplate that appears / goes away, nothing in instances, battlegrounds and on a taxi.
-- Option: a list of the enemy players seen (the Radar of Sashoof's WarLegend v3 addon), from nameplates, target and
-- mouseover in the open world, kept on this computer (200 at most).
-- Option: enemy player frames on the side of the screen (open world, 40 at most, click to target), see below.
local W = WLRT
W.AddFR({
    ["Danger alert"] = "Alerte danger",
    ["Warn me when danger is near (open world)"] = "Me prévenir quand un danger approche (monde ouvert)",
    ["Enemy players flagged for PvP"] = "Joueurs ennemis en mode JcJ",
    ["Skull and red elite mobs"] = "Monstres « tête de mort » et élites rouges",
    ["Play a sound"] = "Jouer un son",
    ["Lock the warning and the frames"] = "Verrouiller l'alerte et les cadres",
    ["Test"] = "Test",
    ["Reset position"] = "Réinitialiser la position",
    ["WARNING"] = "ALERTE",
    ["CAUTION"] = "ATTENTION",
    ["%d enemy player(s) nearby"] = "%d joueur(s) ennemi(s) à proximité",
    ["%d skull elite(s) nearby"] = "%d élite(s) tête de mort à proximité",
    ["%d skull mob(s) nearby"] = "%d monstre(s) tête de mort à proximité",
    ["%d red elite(s) nearby"] = "%d élite(s) rouge(s) à proximité",
    ["Uses the nameplates: enemy nameplates must be shown (V key) to see what is around."] =
        "Utilise les barres de nom : celles des ennemis doivent être affichées (touche V) pour voir ce qui approche.",
    ["Keep a list of the enemy players seen (open world)"] = "Garder la liste des joueurs ennemis vus (monde ouvert)",
    ["Nameplates, target and mouseover; kept on this computer, 200 players at most. Idea: the Radar of Sashoof's WarLegend v3 addon."] =
        "Barres de nom, cible et survol ; gardée sur cet ordinateur, 200 joueurs au plus. Idée : le Radar de l'addon WarLegend v3 de Sashoof.",
    ["All classes"] = "Toutes les classes",
    ["Clear the list"] = "Vider la liste",
    ["Clear the list of the enemy players seen?"] = "Vider la liste des joueurs ennemis vus ?",
    ["Enemy player"] = "Joueur ennemi",
    ["Level"] = "Niveau",
    ["Guild"] = "Guilde",
    ["Zone"] = "Zone",
    ["Seen"] = "Vu",
    ["Times"] = "Fois",
    ["%d s"] = "%d s",
    ["%d min"] = "%d min",
    ["%d h"] = "%d h",
    ["%d d"] = "%d j",
    ["Enemy player frames"] = "Cadres des joueurs ennemis",
    ["Enemy players: %d"] = "Joueurs ennemis : %d",
    ["Enemy player frames on the side of the screen (open world)"] =
        "Cadres des joueurs ennemis sur le côté de l'écran (monde ouvert)",
    ["One row per enemy player shown by a nameplate, the target, the focus or the mouseover: name, class color, health. Grey once no longer seen, gone after 15 s; 40 at most. Drag the title to move them (Test shows them)."] =
        "Une ligne par joueur ennemi montré par une barre de nom, la cible, la focalisation ou le survol : nom, couleur de classe, points de vie. Grisée quand il n'est plus vu, retirée après 15 s ; 40 au plus. Faire glisser le titre pour les déplacer (Test les affiche).",
    ["Click a frame to target the player"] = "Cliquer sur un cadre pour cibler le joueur",
    ["Secure buttons, changed out of combat only: in combat a new player can be clicked once the combat is over. Switch it off if it costs too much."] =
        "Boutons sécurisés, modifiés hors combat seulement : en combat, un nouveau joueur devient cliquable à la fin du combat. À couper si cela coûte trop.",
})
local L = W.L
local db

W.OnReady(function()
    db = W.DB("dangerAlert", { enabled = false, players = true, mobs = true, sound = true, locked = false, log = false, logClass = "",
        frames = false, framesClick = true })
    if type(db.point) ~= "table" then db.point = { "TOP", "TOP", 0, -90 } end
    if type(db.framesPoint) ~= "table" then db.framesPoint = { "TOPRIGHT", "TOPRIGHT", -30, -200 } end
    if type(db.seen) ~= "table" then db.seen = {} end
end)

-- what each nameplate unit is: "pvp", "skullElite", "skull", "redElite"
local seen = {}
local ORDER = { "pvp", "skullElite", "skull", "redElite" }
local TEXT = {
    pvp = { "%d enemy player(s) nearby", true },
    skullElite = { "%d skull elite(s) nearby", true },
    skull = { "%d skull mob(s) nearby", true },
    redElite = { "%d red elite(s) nearby", false },
}
local SOUNDS = {
    pvp = SOUNDKIT and (SOUNDKIT.PVP_THROUGH_QUEUE or SOUNDKIT.RAID_WARNING),
    skullElite = SOUNDKIT and SOUNDKIT.RAID_WARNING,
    skull = SOUNDKIT and (SOUNDKIT.READY_CHECK or SOUNDKIT.RAID_WARNING),
    redElite = SOUNDKIT and (SOUNDKIT.ALARM_CLOCK_WARNING_2 or SOUNDKIT.RAID_WARNING),
}

local frame
local function Place()
    local p = db.point
    frame:ClearAllPoints()
    frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

local function Create()
    if frame then return end
    frame = CreateFrame("Frame", "WLRTDangerAlert", UIParent)
    frame:SetSize(420, 30)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) if not db.locked then self:StartMoving() end end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, rel, x, y = self:GetPoint()
        db.point = { point, rel, x, y }
    end)
    frame.text = frame:CreateFontString(nil, "OVERLAY")
    W.SetFont(frame.text, W.FONT, 18, "OUTLINE")
    frame.text:SetPoint("CENTER")
    frame:Hide()
    Place()
end

local function OpenWorld()
    local inInstance = IsInInstance()
    return not inInstance and not (UnitOnTaxi and UnitOnTaxi("player"))
end

local counts = {} -- reused: Refresh runs for every dangerous nameplate that comes or goes
local function Refresh()
    if not frame then return end
    wipe(counts)
    for _, kind in pairs(seen) do counts[kind] = (counts[kind] or 0) + 1 end
    for _, kind in ipairs(ORDER) do
        local n = counts[kind]
        if n and n > 0 then
            local t = TEXT[kind]
            local tag = t[2] and ("|cffff3333" .. L("WARNING") .. "|r") or ("|cffffcc00" .. L("CAUTION") .. "|r")
            frame.text:SetText("[" .. tag .. "] " .. string.format(L(t[1]), n))
            frame:Show()
            return
        end
    end
    frame.text:SetText("")
    frame:Hide()
end

local function Classify(unit)
    local isEnemy = W.Safe(UnitIsEnemy("player", unit))
    if not isEnemy then return nil end
    if W.Safe(UnitIsPlayer(unit)) then
        return db.players and W.Safe(UnitIsPVP(unit)) and "pvp" or nil
    end
    if not db.mobs then return nil end
    local level, me = W.Safe(UnitLevel(unit)), W.Safe(UnitLevel("player"))
    if not level or not me then return nil end
    local class = W.Safe(UnitClassification(unit))
    local elite = class == "worldboss" or class == "rareelite" or class == "elite"
    local skull = level == -1 or level >= me + 10
    if skull then return elite and "skullElite" or "skull" end
    if level >= me + 3 and elite then return "redElite" end
end

-- Enemy players seen: db.seen[key] = { n = name, c = class, l = level, g = guild, z = zone, t = last seen, k = times }
local MAX_SEEN, AGAIN = 200, 300 -- seen again after 5 min: one more time
local RECENT = 10 -- a player written less than 10 s ago (same GUID) is not read again: nameplate, target, mouseover
local recent, recentCount = {}, 0
local LogChanged
local function Record(unit)
    if not W.Safe(UnitIsPlayer(unit)) or not W.Safe(UnitIsEnemy("player", unit)) then return end
    local guid, t = W.Safe(UnitGUID(unit)), GetTime()
    if guid then
        local last = recent[guid]
        if last and t - last < RECENT then return end
        if not last then
            recentCount = recentCount + 1
            if recentCount > 300 then wipe(recent); recentCount = 1 end -- a busy evening: start over, stays small
        end
        recent[guid] = t
    end
    local name = W.UnitDisplayName(unit)
    if not name then return end
    local key = name:lower()
    local now = time()
    local e = db.seen[key]
    if not e then
        -- full: the one seen longest ago goes first
        local count, oldest = 0, nil
        for k, v in pairs(db.seen) do
            count = count + 1
            if not oldest or (v.t or 0) < (db.seen[oldest].t or 0) then oldest = k end
        end
        if count >= MAX_SEEN and oldest then db.seen[oldest] = nil end
        e = { k = 0, t = 0 }
        db.seen[key] = e
    end
    if now - e.t >= AGAIN then e.k = e.k + 1 end
    e.n, e.t = name, now
    e.c = W.UnitClassToken(unit) or e.c
    local level = W.Safe(UnitLevel(unit))
    if type(level) == "number" then e.l = level end
    local guild = GetGuildInfo and W.Safe((GetGuildInfo(unit)))
    if guild then e.g = guild end
    e.z = W.Safe(GetRealZoneText()) or e.z
    if LogChanged then LogChanged() end
end

-- one sound per kind every 10 s: a camp of elites shows ten nameplates at once
local SOUND_GAP = 10
local soundAt = {}
local addEv = W.On("NAME_PLATE_UNIT_ADDED", function(unit)
    if not OpenWorld() then return end
    if db.log then Record(unit) end
    if not db.enabled then return end
    local kind = Classify(unit)
    if not kind then return end
    seen[unit] = kind
    Create()
    local now = GetTime()
    if db.sound and SOUNDS[kind] and now - (soundAt[kind] or 0) >= SOUND_GAP then
        soundAt[kind] = now
        PlaySound(SOUNDS[kind], "Ambience")
    end
    Refresh()
end, nil, true)
local removeEv = W.On("NAME_PLATE_UNIT_REMOVED", function(unit)
    if seen[unit] then seen[unit] = nil; Refresh() end
end, nil, true)

local targetEv = W.On("PLAYER_TARGET_CHANGED", function() if OpenWorld() then Record("target") end end, nil, true)
local mouseEv = W.On("UPDATE_MOUSEOVER_UNIT", function() if OpenWorld() then Record("mouseover") end end, nil, true)

-- Enemy player frames (open world, the idea of the battleground frames): one row per enemy player (GUID) that a
-- nameplate, the target, the focus or the mouseover shows: name, class color, health. A row no unit shows any more goes
-- grey (its last health stays on the bar) and leaves after 15 s. Rows are slots made once and reused, 40 at most.
-- Click to target: secure buttons anchored to the holder (not to the rows, which stay free in combat), changed out of
-- combat only. In combat a clickable row stays where it is (grey if the player left) until the combat ends; a new
-- player gets a free row that becomes clickable after the combat.
-- Cost: nothing while the option is off, in an instance or on a taxi; one look per nameplate / target / focus /
-- mouseover change; health events only while a row is shown, drawn 5 times a second at most; one check a second
-- of the rows shown (units gone, 15 s out).
local MAX_ROWS, PER_COLUMN, ROW_W, ROW_H, LOST = 40, 20, 150, 14, 15
local holder, header, made = nil, nil, 0
local rows, clicks = {}, {}
local slots, byGuid, byUnit, pool = {}, {}, {}, {} -- slots[i] = entry shown on row i; byUnit[unit token] = entry
local waiting, refill = {}, {} -- waiting[nameplate token] = refused while the 40 rows were full, still shown
local count, framesOn, clickPending, testing, ticking, dirty = 0, false, false, false, false, false
local fHealthEv, fMaxEv, fRegenEv, Tick

local function SlotXY(i)
    local col, r = math.floor((i - 1) / PER_COLUMN), (i - 1) % PER_COLUMN
    return -col * (ROW_W + 4), -16 - r * (ROW_H + 1)
end

local function PlaceHolder()
    local p = db.framesPoint
    holder:ClearAllPoints()
    holder:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

-- the holder shows nothing itself; the secure buttons make it protected: never moved in combat
local function Holder()
    if holder then return holder end
    holder = CreateFrame("Frame", "WLRTDangerFrames", UIParent)
    holder:SetSize(ROW_W, 16 + PER_COLUMN * (ROW_H + 1))
    holder:SetFrameStrata("MEDIUM")
    holder:SetClampedToScreen(true)
    holder:SetMovable(true)
    header = CreateFrame("Frame", nil, holder)
    header:SetPoint("TOPRIGHT")
    header:SetSize(ROW_W, 14)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        if not db.locked and not InCombatLockdown() then holder:StartMoving() end
    end)
    header:SetScript("OnDragStop", function()
        if InCombatLockdown() then return end
        holder:StopMovingOrSizing()
        local point, _, rel, x, y = holder:GetPoint()
        db.framesPoint = { point, rel, x, y }
    end)
    header.text = header:CreateFontString(nil, "OVERLAY")
    W.SetFont(header.text, W.FONT, 11, "OUTLINE")
    header.text:SetPoint("RIGHT")
    header:Hide()
    PlaceHolder()
    return holder
end

local function Row(i)
    if rows[i] then return rows[i] end
    local row = CreateFrame("StatusBar", nil, Holder())
    row:SetSize(ROW_W, ROW_H)
    row:SetPoint("TOPRIGHT", holder, "TOPRIGHT", SlotXY(i))
    row:SetStatusBarTexture(W.BAR_TEXTURE)
    row:SetMinMaxValues(0, 1)
    row:SetValue(1)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    W.SetColor(row.bg, 0.05, 0.05, 0.05, 0.7)
    row.name = row:CreateFontString(nil, "OVERLAY")
    W.SetFont(row.name, W.FONT, 10, "OUTLINE")
    row.name:SetPoint("LEFT", 3, 0)
    row.name:SetPoint("RIGHT", -40, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.hp = row:CreateFontString(nil, "OVERLAY")
    W.SetFont(row.hp, W.FONT, 10, "OUTLINE")
    row.hp:SetPoint("RIGHT", -3, 0)
    row:Hide()
    rows[i] = row
    if i > made then made = i end
    return row
end

-- out of combat only (SyncClicks)
local function Click(i)
    if clicks[i] then return clicks[i] end
    local c = CreateFrame("Button", nil, Holder(), "SecureActionButtonTemplate")
    c:SetSize(ROW_W, ROW_H)
    c:SetPoint("TOPRIGHT", holder, "TOPRIGHT", SlotXY(i))
    c:SetFrameLevel(holder:GetFrameLevel() + 5) -- above the rows: its highlight shows
    c:RegisterForClicks("AnyUp", "AnyDown")
    c:SetAttribute("type1", "macro")
    c:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    clicks[i] = c
    return c
end

-- as the battleground frames (WarLegendRaidTool_PvP Main.lua GetTargetMacro): "First Surname" or "Name-Realm"
local function TargetMacro(name)
    local first, rest = name:match("^([^%s%-]+)[%s%-](.+)$")
    if not first then return "/cleartarget\n/targetexact " .. name end
    return "/cleartarget\n/targetexact " .. first .. " " .. rest ..
        "\n/targetexact [noexists] " .. first .. "-" .. rest ..
        "\n/targetexact [noexists] " .. first
end

-- health can be a secret value: only handed to the bar and the font string (as HealthBar.lua of the PvP addon)
local function HealthText(v)
    if AbbreviateNumbers then return AbbreviateNumbers(v) end
    if issecretvalue and issecretvalue(v) then return v end
    return AbbreviateLargeNumbers and AbbreviateLargeNumbers(v) or v
end

local function Health(e)
    local row, u = rows[e.slot], e.unit
    if not row or not u then return end
    local hp, max = UnitHealth(u), UnitHealthMax(u)
    row:SetMinMaxValues(0, max)
    row:SetValue(hp)
    row.hp:SetFormattedText("%s", HealthText(hp))
    e.hp, e.max = W.Safe(hp), W.Safe(max) -- for a grey row moved to another slot
end

local function Paint(i)
    local e, row = slots[i], rows[i]
    if not e then
        if row and not testing then row:Hide() end
        return
    end
    row = row or Row(i)
    row.name:SetText(e.name)
    if e.unit then
        row:SetStatusBarColor(W.ClassColor(e.class))
        row:SetAlpha(1)
        Health(e)
    else
        row:SetStatusBarColor(0.4, 0.4, 0.4)
        row:SetAlpha(0.6)
        if e.moved then
            if e.hp and e.max then
                row:SetMinMaxValues(0, e.max)
                row:SetValue(e.hp)
                row.hp:SetFormattedText("%s", HealthText(e.hp))
            else
                row:SetMinMaxValues(0, 1)
                row:SetValue(1)
                row.hp:SetText("")
            end
        end
    end
    e.moved = nil
    row:Show()
end

local function SyncClicks()
    if InCombatLockdown() then
        clickPending = true
        W.Activate(fRegenEv, true)
        return
    end
    clickPending = false
    local want = framesOn and db.framesClick
    for i = 1, MAX_ROWS do
        local e, c = want and slots[i], clicks[i]
        if e then
            c = c or Click(i)
            if c.macro ~= e.macro then c:SetAttribute("macrotext1", e.macro); c.macro = e.macro end
            c.entry = e
            c:Show()
        elseif c then
            c.entry = nil
            c:Hide()
        end
    end
end

-- rows packed from the top, except in combat while a click can target them
local function Layout()
    if not (db.framesClick and InCombatLockdown()) then
        local n = 0
        for i = 1, MAX_ROWS do
            local e = slots[i]
            if e then
                n = n + 1
                if i ~= n then slots[i], slots[n], e.slot, e.moved = nil, e, n, true end
            end
        end
    end
    for i = 1, made do Paint(i) end
    SyncClicks()
end

local function Clickable(e)
    local c = clicks[e.slot]
    return c and c.entry == e and c.macro == e.macro and c:IsShown()
end

local function Changed()
    if header then
        header.text:SetFormattedText(L("Enemy players: %d"), testing and 5 or count)
        header:SetShown(count > 0 or testing)
    end
    W.Activate(fHealthEv, framesOn and count > 0)
    W.Activate(fMaxEv, framesOn and count > 0)
    if count > 0 and not ticking then ticking = true; W.After(1, Tick) end
end

local function Remove(e)
    for u, x in pairs(byUnit) do if x == e then byUnit[u] = nil end end
    slots[e.slot], byGuid[e.guid] = nil, nil
    count = count - 1
    pool[#pool + 1] = e
end

-- the unit that showed this player does not any more: another one that still does, or grey
local function Rebind(e)
    e.unit = nil
    for u, x in pairs(byUnit) do
        if x == e then
            if W.Safe(UnitGUID(u)) == e.guid then e.unit = u; break end
            byUnit[u] = nil
        end
    end
    if e.unit then e.lost = nil elseif not e.lost then e.lost = GetTime() end
end

local function NewEntry(unit, guid)
    if count >= MAX_ROWS then return nil end
    local name = W.UnitDisplayName(unit)
    if not name then return nil end
    local i = 1
    while slots[i] do i = i + 1 end
    local e = table.remove(pool) or {}
    e.guid, e.name, e.class, e.slot, e.macro = guid, name, W.UnitClassToken(unit), i, TargetMacro(name)
    e.unit, e.lost, e.hp, e.max, e.moved, e.dirty = nil, nil, nil, nil, nil, nil
    slots[i], byGuid[guid] = e, e
    count = count + 1
    return e
end

local function Bind(unit)
    local e, new
    if W.Safe(UnitIsPlayer(unit)) and W.Safe(UnitIsEnemy("player", unit)) then
        local guid = W.Safe(UnitGUID(unit))
        if guid then
            e = byGuid[guid]
            if not e then
                e = NewEntry(unit, guid)
                new = e ~= nil
                if not e and count >= MAX_ROWS and unit:find("^nameplate") then waiting[unit] = true end
            end
        end
    end
    local old = byUnit[unit]
    if not e and not old then return end
    byUnit[unit] = e
    if old and old ~= e and old.unit == unit then Rebind(old); Paint(old.slot) end
    if e then
        -- the mouseover gets no health events: keep the unit it already had
        if not e.unit or unit ~= "mouseover" then e.unit, e.lost = unit, nil end
        Paint(e.slot)
    end
    Changed()
    if new and db.framesClick then SyncClicks() end -- in combat: after the combat
end

local function Unbind(unit)
    local e = byUnit[unit]
    if not e then return end
    byUnit[unit] = nil
    if e.unit == unit then Rebind(e); Paint(e.slot) end
end

-- rows came free (players gone, end of combat): the nameplates refused while the rows were full get one now
local function Refill()
    if count >= MAX_ROWS or not next(waiting) then return end
    wipe(refill)
    for unit in pairs(waiting) do refill[#refill + 1] = unit end
    wipe(waiting)
    for _, unit in ipairs(refill) do
        if W.Safe(UnitExists(unit)) then Bind(unit) end -- full again: Bind puts it back in waiting
    end
end

Tick = function()
    ticking = false
    if not framesOn then return end
    local now, lockdown, gone = GetTime(), InCombatLockdown(), false
    for i = 1, MAX_ROWS do
        local e = slots[i]
        if e then
            if e.unit and W.Safe(UnitGUID(e.unit)) ~= e.guid then
                Rebind(e)
                Paint(i)
            elseif e.unit == "mouseover" then
                Health(e)
            end
            if e.lost and now - e.lost >= LOST and not (lockdown and Clickable(e)) then Remove(e); gone = true end
        end
    end
    if gone then Layout(); Refill() end
    Changed()
end

local function ClearFrames()
    for i = 1, MAX_ROWS do
        local e = slots[i]
        if e then Remove(e) end
    end
    wipe(byUnit)
    wipe(waiting)
    for i = 1, made do Paint(i) end
    Changed()
    SyncClicks()
end

local function Flush()
    dirty = false
    for i = 1, MAX_ROWS do
        local e = slots[i]
        if e and e.dirty then
            e.dirty = nil
            Health(e)
        end
    end
end

local function OnHealth(unit)
    local e = byUnit[unit]
    if not e or e.unit ~= unit then return end
    e.dirty = true
    if not dirty then dirty = true; W.After(0.2, Flush) end
end

local fAddEv = W.On("NAME_PLATE_UNIT_ADDED", function(unit) if OpenWorld() then Bind(unit) end end, nil, true)
local fRemoveEv = W.On("NAME_PLATE_UNIT_REMOVED", function(unit)
    waiting[unit] = nil
    if byUnit[unit] then Unbind(unit); Changed() end
end, nil, true)
local fTargetEv = W.On("PLAYER_TARGET_CHANGED", function() if OpenWorld() then Bind("target") end end, nil, true)
local fFocusEv = W.On("PLAYER_FOCUS_CHANGED", function() if OpenWorld() then Bind("focus") end end, nil, true)
local fMouseEv = W.On("UPDATE_MOUSEOVER_UNIT", function() if OpenWorld() then Bind("mouseover") end end, nil, true)
fHealthEv = W.On("UNIT_HEALTH", OnHealth, nil, true)
fMaxEv = W.On("UNIT_MAXHEALTH", OnHealth, nil, true)
local fDeadEv = W.On("PLAYER_DEAD", ClearFrames, nil, true)
-- end of combat: the players gone during the combat leave, the clicks follow the rows again
fRegenEv = W.On("PLAYER_REGEN_ENABLED", function()
    if framesOn then
        local now = GetTime()
        for i = 1, MAX_ROWS do
            local e = slots[i]
            if e and e.lost and now - e.lost >= LOST then Remove(e) end
        end
        Layout()
        Refill()
        Changed()
    elseif clickPending then
        SyncClicks()
    end
    W.Activate(fRegenEv, db.frames and true or false)
end, nil, true)

local TEST_CLASSES = { "WARRIOR", "MAGE", "PRIEST", "ROGUE", "HUNTER" }
local function StopFramesTest()
    if not testing then return end
    testing = false
    for i = 1, made do Paint(i) end
    Changed()
end
local function TestFrames()
    if count > 0 then return end
    testing = true
    for i = 1, 5 do
        local row, hp = Row(i), 4000 - i * 600
        row.name:SetText(L("Enemy player") .. " " .. i)
        if i == 5 then row:SetStatusBarColor(0.4, 0.4, 0.4) else row:SetStatusBarColor(W.ClassColor(TEST_CLASSES[i])) end
        row:SetAlpha(i == 5 and 0.6 or 1)
        row:SetMinMaxValues(0, 4000)
        row:SetValue(hp)
        row.hp:SetText(tostring(hp))
        row:Show()
    end
    Changed()
    W.After(5, StopFramesTest)
end

-- the events only in the open world: in an instance the handlers did nothing (an instance always comes with a
-- loading screen, so PLAYER_ENTERING_WORLD switches them back); the taxi stays a test in the handlers
local function Apply()
    local world = not IsInInstance()
    local on = db and db.enabled and world and true or false
    local log = db and db.log and world and true or false
    W.Activate(addEv, on or log)
    W.Activate(removeEv, on)
    W.Activate(targetEv, log)
    W.Activate(mouseEv, log)
    wipe(seen)
    Refresh()
    framesOn = db and db.frames and world and true or false
    W.Activate(fAddEv, framesOn)
    W.Activate(fRemoveEv, framesOn)
    W.Activate(fTargetEv, framesOn)
    W.Activate(fFocusEv, framesOn)
    W.Activate(fMouseEv, framesOn)
    W.Activate(fDeadEv, framesOn)
    W.Activate(fRegenEv, (db and db.frames) or clickPending)
    ClearFrames()
end
W.On("PLAYER_ENTERING_WORLD", Apply)

local function Test()
    Create()
    seen.test = "pvp"
    Refresh()
    if db.sound and SOUNDS.pvp then PlaySound(SOUNDS.pvp, "Ambience") end
    C_Timer.After(5, function() seen.test = nil; Refresh() end)
    if db.frames then TestFrames() end
end
W.RegisterTest("Danger alert", function() return db and db.enabled end, Test,
    function() if seen.test then seen.test = nil; Refresh() end end)
W.RegisterTest("Enemy player frames", function() return db and db.frames end, TestFrames, StopFramesTest)

W.RegisterModule("DangerAlert", L("Danger alert"), function(p)
    W.Title(p, L("Danger alert"))
    W.Check(p, L("Warn me when danger is near (open world)"), function() return db.enabled end,
        function(v) db.enabled = v; Apply() end):SetPoint("TOPLEFT", 12, -40)
    W.Check(p, L("Enemy players flagged for PvP"), function() return db.players end, function(v) db.players = v end)
        :SetPoint("TOPLEFT", 32, -66)
    W.Check(p, L("Skull and red elite mobs"), function() return db.mobs end, function(v) db.mobs = v end)
        :SetPoint("TOPLEFT", 32, -90)
    W.Check(p, L("Play a sound"), function() return db.sound end, function(v) db.sound = v end):SetPoint("TOPLEFT", 32, -114)
    W.Check(p, L("Lock the warning and the frames"), function() return db.locked end, function(v) db.locked = v end):SetPoint("TOPLEFT", 32, -138)
    W.Button(p, L("Test"), 110, 22, Test):SetPoint("TOPLEFT", 16, -172)
    W.Button(p, L("Reset position"), 160, 22, function()
        db.point = { "TOP", "TOP", 0, -90 }
        if frame then Place() end
        if InCombatLockdown() then return end -- the frames' holder is protected (secure buttons)
        db.framesPoint = { "TOPRIGHT", "TOPRIGHT", -30, -200 }
        if holder then PlaceHolder() end
    end):SetPoint("TOPLEFT", 132, -172)
    local info = W.Label(p, L("Uses the nameplates: enemy nameplates must be shown (V key) to see what is around."), "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, -204)
    info:SetTextColor(0.7, 0.7, 0.7)
    W.Check(p, L("Enemy player frames on the side of the screen (open world)"), function() return db.frames end,
        function(v) db.frames = v; Apply() end,
        { L("One row per enemy player shown by a nameplate, the target, the focus or the mouseover: name, class color, health. Grey once no longer seen, gone after 15 s; 40 at most. Drag the title to move them (Test shows them).") })
        :SetPoint("TOPLEFT", 12, -222)
    W.Check(p, L("Click a frame to target the player"), function() return db.framesClick end,
        function(v) db.framesClick = v; SyncClicks() end,
        { L("Secure buttons, changed out of combat only: in combat a new player can be clicked once the combat is over. Switch it off if it costs too much.") })
        :SetPoint("TOPLEFT", 32, -246)

    -- enemy players seen
    local list
    local function Age(t)
        local s = math.max(0, time() - (t or 0))
        if s < 60 then return string.format(L("%d s"), s) end
        if s < 3600 then return string.format(L("%d min"), math.floor(s / 60)) end
        if s < 86400 then return string.format(L("%d h"), math.floor(s / 3600)) end
        return string.format(L("%d d"), math.floor(s / 86400))
    end
    local function Fill()
        if not list or not p:IsShown() then return end
        local entries = {}
        for _, e in pairs(db.seen) do
            if db.logClass == "" or e.c == db.logClass then entries[#entries + 1] = e end
        end
        table.sort(entries, function(a, b) return (a.t or 0) > (b.t or 0) end)
        local rows = {}
        for i, e in ipairs(entries) do
            rows[i] = { cells = { W.ColorName(W.Plain(e.n, 60), e.c), e.l and (e.l < 0 and "??" or tostring(e.l)) or "",
                W.Plain(e.g or "", 40), W.Plain(e.z or "", 40), Age(e.t), tostring(e.k or 1) } }
        end
        list:SetData(rows)
    end
    local pending = false
    LogChanged = function()
        if pending or not p:IsShown() then return end
        pending = true
        W.After(0.5, function() pending = false; Fill() end)
    end
    W.Check(p, L("Keep a list of the enemy players seen (open world)"), function() return db.log end,
        function(v) db.log = v; Apply() end, { L("Nameplates, target and mouseover; kept on this computer, 200 players at most. Idea: the Radar of Sashoof's WarLegend v3 addon.") })
        :SetPoint("TOPLEFT", 12, -280)
    local classes = { { "", L("All classes") } }
    for _, c in ipairs({ "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }) do
        classes[#classes + 1] = { c, W.ColorName((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c]) or c, c) }
    end
    W.Cycle(p, 150, classes, function() return db.logClass end, function(v) db.logClass = v; Fill() end)
        :SetPoint("TOPLEFT", 400, -280)
    W.Button(p, L("Clear the list"), 130, 22, function()
        W.Confirm(L("Clear the list of the enemy players seen?"), function() wipe(db.seen); Fill() end)
    end):SetPoint("TOPLEFT", 560, -280)
    list = W.Table(p, { { L("Enemy player"), 200 }, { L("Level"), 50, "CENTER" }, { L("Guild"), 160 }, { L("Zone"), 160 },
        { L("Seen"), 70, "CENTER" }, { L("Times"), 50, "CENTER" } }, 230)
    list:SetPoint("TOPLEFT", 10, -312)
    p:SetScript("OnShow", Fill)
end)

W.slash.danger = function() W.Toggle("DangerAlert") end
