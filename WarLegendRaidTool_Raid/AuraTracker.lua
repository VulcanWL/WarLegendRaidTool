-- WarLegend RaidTool - Aura Tracking
-- Icons for my debuffs, the co-tanks' debuffs, external buffs (Power Infusion, Blessings...),
-- immunities and custom auras. Built to cost nothing when idle:
--   * UNIT_AURA is registered only for me and up to 2 co-tanks (RegisterUnitEvent), never the whole raid
--   * the game's incremental aura updates are used: only added / removed auras are looked at
--   * timers are drawn by the game's cooldown frames: no OnUpdate, no Lua code per frame
--   * redraws are grouped (one per frame at most) and only happen when a tracked aura changed
--   * off by default, and off in battlegrounds / arenas unless asked
local W = WLRT
W.AddFR({
    ["Aura Tracking"] = "Suivi d'auras",
    ["Enable aura tracking"] = "Activer le suivi d'auras",
    ["My debuffs"] = "Mes debuffs",
    ["Co-tank debuffs"] = "Debuffs des co-tanks",
    ["External buffs (Power Infusion, Blessings, Innervate, Fear Ward)"] = "Buffs externes (Infusion de puissance, Bénédictions, Innervation, Gardien de peur)",
    ["Immunities (Divine Shield, Ice Block, Blessing of Protection...)"] = "Immunités (Bouclier divin, Bloc de glace, Bénédiction de protection...)",
    ["Hide debuffs without a duration"] = "Masquer les debuffs sans durée",
    ["Also in battlegrounds and arenas"] = "Aussi en champs de bataille et arènes",
    ["Co-tanks (empty = automatic from raid roles, max 2):"] = "Co-tanks (vide = automatique selon les rôles du raid, 2 max) :",
    ["Custom auras (spell IDs or names, comma separated):"] = "Auras perso (ID de sort ou noms, séparés par des virgules) :",
    ["Move"] = "Déplacer",
    ["Lock"] = "Verrouiller",
    ["Stop test"] = "Arrêter le test",
    ["Reset positions"] = "Réinitialiser les positions",
    ["Me"] = "Moi",
    ["Co-tank %d"] = "Co-tank %d",
    ["Co-tanks: %s"] = "Co-tanks : %s",
    ["none found"] = "aucun trouvé",
    ["Co-tanks are the raid's main tanks (or the Tank role). Type names to choose them yourself."] =
        "Les co-tanks sont les tanks principaux du raid (ou le rôle Tank). Tape des noms pour les choisir toi-même.",
    ["Border: gold = immunity, green = external, blue = custom, debuff = its dispel type color."] =
        "Bordure : or = immunité, vert = externe, bleu = perso, debuff = couleur de son type de dissipation.",
    ["Timers are drawn by the game itself: no addon code runs every frame."] =
        "Les chronos sont dessinés par le jeu lui-même : aucun code de l'addon ne tourne à chaque image.",
    ["Countdown numbers: Blizzard option \"Show numbers for cooldowns\" (or OmniCC)."] =
        "Chiffres du chrono : option Blizzard « Afficher les chiffres des temps de recharge » (ou OmniCC).",
})
local L = W.L

local MAX_ICONS, GAP, ROWS = 8, 3, 3 -- row 1 = me, rows 2-3 = co-tanks
local CAT_ORDER = { immunity = 1, external = 2, custom = 3, debuff = 4 }
local CAT_COLOR = { immunity = { 1, 0.82, 0 }, external = { 0.2, 0.9, 0.3 }, custom = { 0.3, 0.6, 1 }, debuff = { 0.8, 0, 0 } }
-- dispel type colors (WoW: Forever has no DebuffTypeColor global)
local DISPEL_COLOR = { Magic = { 0.2, 0.6, 1 }, Curse = { 0.6, 0, 1 }, Disease = { 0.6, 0.4, 0 }, Poison = { 0, 0.6, 0 } }

-- Classic spell IDs (every rank). The names are read from the game, so any language matches.
local IMMUNITY_SPELLS = {
    642, 1020,         -- Divine Shield
    498, 5573,         -- Divine Protection
    1022, 5599, 10278, -- Blessing of Protection
    19752,             -- Divine Intervention
    11958,             -- Ice Block
    19263,             -- Deterrence
    3169,              -- Invulnerability (Limited Invulnerability Potion)
    6615,              -- Free Action (potion)
    7744,              -- Will of the Forsaken
    18499,             -- Berserker Rage
    20594,             -- Stoneform
}
local EXTERNAL_SPELLS = {
    10060,             -- Power Infusion
    29166,             -- Innervate
    1044,              -- Blessing of Freedom
    6940, 20729,       -- Blessing of Sacrifice
    6346,              -- Fear Ward
}

local db
local rows = {}
local tanks = {}
local unlocked, testMode = false, false
local immById, immByName, extById, extByName = {}, {}, {}, {}
local cusById, cusByName, cusByLower = {}, {}, {}
local hasCustom, hasTyped = false, false
local GetTex = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture

---------------------------------------------------------------------------
-- What is tracked
---------------------------------------------------------------------------
local function FillSet(ids, byId, byName)
    wipe(byId); wipe(byName)
    for _, id in ipairs(ids) do
        byId[id] = true
        local n = W.SpellName(id)
        if n then byName[n] = true end
    end
end

local function ParseCustom()
    wipe(cusById); wipe(cusByName); wipe(cusByLower)
    hasCustom, hasTyped = false, false
    for tok in (db.custom or ""):gmatch("[^,;\n]+") do
        tok = tok:gsub("^%s+", ""):gsub("%s+$", "")
        local id = tonumber(tok) or tonumber(tok:match("spell:(%d+)")) -- shift-clicked spell links work too
        if id then
            cusById[id] = true
            local n = W.SpellName(id)
            if n then cusByName[n] = true end
            hasCustom = true
        elseif tok ~= "" then
            cusByLower[tok:lower()] = true
            hasCustom, hasTyped = true, true
        end
    end
end

local function Match(byId, byName, id, name)
    return (id and byId[id]) or (name and byName[name]) or false
end

local function Category(id, name, harmful, isMe)
    if not harmful then
        if db.immunities and Match(immById, immByName, id, name) then return "immunity" end
        if db.externals and Match(extById, extByName, id, name) then return "external" end
    end
    if hasCustom and (Match(cusById, cusByName, id, name) or (hasTyped and name and cusByLower[name:lower()])) then
        return "custom"
    end
    if harmful and ((isMe and db.myDebuffs) or (not isMe and db.tankDebuffs)) then return "debuff" end
end

-- One pcall per aura and no closure: the client may hide some values (secret) in combat
local function ReadAura(a)
    return a.auraInstanceID, a.spellId, a.name, a.icon, a.applications, a.duration, a.expirationTime, a.isHarmful, a.dispelName
end

-- Adds the aura to the row if it is tracked. Returns true when the row changed.
-- Second result: true when the aura could not be read (WoW: Forever hides aura data in restricted combat)
local function Track(row, a, harmfulFilter)
    if W.Safe(a) == nil then return false, true end
    local ok, iid, id, name, icon, count, dur, exp, harmful, dispel = pcall(ReadAura, a)
    if not ok then return false, true end
    iid, icon = W.Safe(iid), W.Safe(icon)
    if not iid or not icon then return false, true end
    id, name = W.Safe(id), W.Safe(name)
    if harmfulFilter == nil then harmful = W.Safe(harmful) and true or false else harmful = harmfulFilter end
    local cat = Category(id, name, harmful, row.isMe)
    if not cat then return false end
    dur, exp = W.Safe(dur) or 0, W.Safe(exp) or 0
    if cat == "debuff" and db.hideNoDuration and dur <= 0 then return false end
    local e = row.auras[iid] or {}
    e.cat, e.order, e.icon, e.count = cat, CAT_ORDER[cat], icon, W.Safe(count) or 0
    e.dur, e.exp, e.dispel = dur, exp, W.Safe(dispel)
    e.sortExp = exp > 0 and exp or math.huge
    row.auras[iid] = e
    return true
end

---------------------------------------------------------------------------
-- Reading a unit
---------------------------------------------------------------------------
local scratch = {} -- old clients without C_UnitAuras: UnitAura values packed in one reused table
local function Scan(row)
    wipe(row.auras)
    row.blind = false
    local unit = row.unit
    if not unit or not UnitExists(unit) then return end
    local modern = W.HAS_AURA_API
    local readable, hidden = 0, 0
    for pass = 1, 2 do
        local filter = pass == 1 and "HELPFUL" or "HARMFUL"
        for i = 1, 40 do
            local a
            if modern then
                a = W.AuraByIndex(unit, i, filter) -- false: secret, the client refuses it to addons
                if a == false then hidden = hidden + 1 end
            elseif UnitAura then
                local name, icon, count, dtype, dur, exp, _, _, _, id = UnitAura(unit, i, filter)
                if name then
                    a = scratch
                    a.auraInstanceID, a.spellId, a.name, a.icon, a.applications = filter .. i, id, name, icon, count
                    a.duration, a.expirationTime, a.dispelName = dur, exp, dtype
                end
            end
            if a == nil then break end
            if a then
                local _, secret = Track(row, a, pass == 2)
                if secret then hidden = hidden + 1 else readable = readable + 1 end
            end
        end
    end
    -- nothing readable in combat: stop reading this unit until the fight ends (no wasted work)
    row.blind = hidden > 0 and readable == 0 and InCombatLockdown()
end

---------------------------------------------------------------------------
-- Drawing (grouped: at most once per frame, only rows that changed)
---------------------------------------------------------------------------
local TEST
local function TestEntries()
    if TEST then return TEST end
    local now = GetTime()
    TEST = {
        { cat = "immunity", order = 1, icon = GetTex and GetTex(642) or 134400, count = 0, dur = 12, exp = now + 12 },
        { cat = "external", order = 2, icon = GetTex and GetTex(10060) or 134400, count = 0, dur = 15, exp = now + 15 },
        { cat = "custom", order = 3, icon = GetTex and GetTex(6346) or 134400, count = 0, dur = 0, exp = 0 },
        { cat = "debuff", order = 4, icon = 136118, count = 3, dur = 20, exp = now + 20, dispel = "Magic" },
    }
    for _, e in ipairs(TEST) do e.sortExp = e.exp > 0 and e.exp or math.huge end
    return TEST
end

local function NewIcon(row, i)
    local b = CreateFrame("Frame", nil, row)
    b.border = b:CreateTexture(nil, "BACKGROUND")
    b.border:SetAllPoints()
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetPoint("TOPLEFT", 2, -2)
    b.tex:SetPoint("BOTTOMRIGHT", -2, 2)
    b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cd:SetAllPoints(b.tex)
    b.cd:SetReverse(true)
    if b.cd.SetDrawEdge then b.cd:SetDrawEdge(false) end
    if b.cd.SetHideCountdownNumbers then b.cd:SetHideCountdownNumbers(false) end
    local over = CreateFrame("Frame", nil, b)
    over:SetAllPoints()
    over:SetFrameLevel(b.cd:GetFrameLevel() + 2)
    b.count = over:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", -1, 2)
    row.icons[i] = b
    return b
end

local function PlaceIcons(row)
    local size = db.size or 32
    W.Size(row, MAX_ICONS * (size + GAP) - GAP, size)
    for i, b in ipairs(row.icons) do
        W.Size(b, size, size)
        b:ClearAllPoints()
        b:SetPoint("LEFT", (i - 1) * (size + GAP), 0)
    end
end

local list = {}
local function ByOrder(a, b)
    if a.order ~= b.order then return a.order < b.order end
    return a.sortExp < b.sortExp
end

local function Draw(row)
    wipe(list)
    local src = testMode and TestEntries() or row.auras
    for _, e in pairs(src) do list[#list + 1] = e end
    table.sort(list, ByOrder)
    local n = math.min(#list, MAX_ICONS)
    for i = 1, n do
        local e = list[i]
        local b = row.icons[i]
        if not b then b = NewIcon(row, i); PlaceIcons(row) end
        if b.iconTex ~= e.icon then b.iconTex = e.icon; b.tex:SetTexture(e.icon) end
        local c = (e.cat == "debuff" and e.dispel and DISPEL_COLOR[e.dispel]) or CAT_COLOR[e.cat]
        W.SetColor(b.border, c[1], c[2], c[3], 1)
        b.count:SetText(e.count > 1 and e.count or "")
        if e.dur > 0 and e.exp > 0 then
            -- only restart the swipe when the aura was refreshed
            if b.exp ~= e.exp or b.dur ~= e.dur then
                b.exp, b.dur = e.exp, e.dur
                b.cd:SetCooldown(e.exp - e.dur, e.dur)
            end
            b.cd:Show()
        elseif b.exp then
            b.exp, b.dur = nil, nil
            b.cd:Hide()
        end
        b:Show()
    end
    for i = n + 1, #row.icons do row.icons[i]:Hide() end
    row:SetShown(n > 0 or unlocked)
end

local flushPending = false
local function Flush()
    flushPending = false
    for _, row in ipairs(rows) do
        if row.dirty then row.dirty = false; Draw(row) end
    end
end

local function Dirty(row)
    row.dirty = true
    if not flushPending then flushPending = true; W.After(0, Flush) end
end

---------------------------------------------------------------------------
-- UNIT_AURA: only the added / changed / removed auras are looked at
---------------------------------------------------------------------------
-- Full read of a unit, at most twice a second (bursts of UNIT_AURA give one read)
local function QueueScan(row)
    if row.blind or row.scanPending then return end
    row.scanPending = true
    W.After(0.5, function()
        row.scanPending = false
        if row.unit then Scan(row); Dirty(row) end
    end)
end

-- A value the client hides (secret) must not be tested, compared or used as a key
local function Hidden(v) return v ~= nil and W.Safe(v) == nil end

local SetUnit
local function OnAura(self, _, unit, info)
    local row = self.row
    if unit ~= row.unit then return end
    if W.IsOff("AuraTracker") then SetUnit(row, nil); return end
    if not W.Allowed() then SetUnit(row, nil); return end -- access lost: stop listening
    local byId = C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID
    -- WoW: Forever can hide the whole update (restricted combat): read the unit again instead
    if not info or not byId or Hidden(info) then QueueScan(row); return end
    local full = info.isFullUpdate
    if Hidden(full) or full then QueueScan(row); return end
    local added, updated, removed = info.addedAuras, info.updatedAuraInstanceIDs, info.removedAuraInstanceIDs
    if Hidden(added) or Hidden(updated) or Hidden(removed) then QueueScan(row); return end
    local changed = false
    if added then
        for i = 1, #added do
            local tracked, secret = Track(row, added[i])
            if secret then QueueScan(row); return end
            if tracked then changed = true end
        end
    end
    if updated then
        for i = 1, #updated do
            local iid = W.Safe(updated[i])
            if not iid then QueueScan(row); return end
            if row.auras[iid] then
                row.auras[iid] = nil
                local a = W.AuraByInstance(unit, iid)
                if a == false then QueueScan(row); return end -- secret now: the full read sorts it out
                if a then Track(row, a) end
                changed = true
            end
        end
    end
    if removed then
        for i = 1, #removed do
            local iid = W.Safe(removed[i])
            if not iid then QueueScan(row); return end
            if row.auras[iid] then row.auras[iid] = nil; changed = true end
        end
    end
    if changed then Dirty(row) end
end

-- end of the fight: units that were unreadable are read again
W.On("PLAYER_REGEN_ENABLED", function()
    for _, row in ipairs(rows) do
        if row.blind then row.blind = false; QueueScan(row) end
    end
end)

---------------------------------------------------------------------------
-- Rows (me + co-tanks)
---------------------------------------------------------------------------
local function DefaultPos(index) return "CENTER", "CENTER", -130, -90 - (index - 1) * 50 end

local function Anchor(row)
    local p = db.pos[row.index]
    row:ClearAllPoints()
    if p then
        row:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        local a, b, x, y = DefaultPos(row.index)
        row:SetPoint(a, UIParent, b, x, y)
    end
end

local function NewRow(index)
    local f = CreateFrame("Frame", "WLRTAuraRow" .. index, UIParent)
    f.index, f.isMe = index, index == 1
    f.auras, f.icons = {}, {}
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(false) -- click-through while locked
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint(1)
        db.pos[self.index] = { p, rp, x, y }
    end)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    W.SetColor(f.bg, 0, 0, 0, 0.45)
    f.bg:Hide()
    f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.label:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 2)
    f.ev = CreateFrame("Frame")
    f.ev.row = f
    f.ev:SetScript("OnEvent", OnAura)
    PlaceIcons(f)
    Anchor(f)
    f:Hide()
    rows[index] = f
    return f
end

function SetUnit(row, unit)
    local guid = unit and W.Safe(UnitGUID(unit)) or nil
    if row.unit == unit and row.guid == guid then return end
    row.unit, row.guid = unit, guid
    row.ev:UnregisterEvent("UNIT_AURA")
    if unit then
        if row.ev.RegisterUnitEvent then row.ev:RegisterUnitEvent("UNIT_AURA", unit) else row.ev:RegisterEvent("UNIT_AURA") end
    end
    Scan(row)
    Dirty(row)
end

local function RowLabel(row)
    if row.isMe then return L("Me") end
    local name = row.unit and W.Safe(UnitName(row.unit))
    return name or string.format(L("Co-tank %d"), row.index - 1)
end

local function UpdateLabels()
    for _, row in ipairs(rows) do
        row.label:SetText(RowLabel(row))
        row.label:SetShown(unlocked or (not row.isMe and row.unit ~= nil))
    end
end

-- Co-tanks: names typed in the options, else the raid's main tanks / Tank role (2 at most)
local function ResolveTanks()
    wipe(tanks)
    local function add(u)
        if #tanks < 2 and u and u ~= "player" and UnitExists(u) and not W.UnitIsMe(u) then tanks[#tanks + 1] = u end
    end
    if (db.tankNames or "") ~= "" then
        for _, n in ipairs(W.NameList(db.tankNames)) do add(W.UnitByName(n)) end
    elseif W.InRaid() then
        for i = 1, W.NumRaid() do
            local u = W.RAID_UNITS[i]
            local _, _, _, _, _, _, _, _, _, role, _, combatRole = GetRaidRosterInfo(i)
            local assigned = UnitGroupRolesAssigned and W.Safe(UnitGroupRolesAssigned(u))
            role, combatRole = W.Safe(role), W.Safe(combatRole)
            if role == "MAINTANK" or combatRole == "TANK" or assigned == "TANK" then add(u) end
        end
    elseif W.InGroup() and UnitGroupRolesAssigned then
        for i = 1, 4 do
            local u = W.PARTY_UNITS[i]
            if UnitExists(u) and W.Safe(UnitGroupRolesAssigned(u)) == "TANK" then add(u) end
        end
    end
end

local UI = {}
local function UpdateStatus()
    if not UI.status then return end
    local names = {}
    for _, u in ipairs(tanks) do names[#names + 1] = W.Safe(UnitName(u)) or "?" end
    UI.status:SetText(string.format(L("Co-tanks: %s"), #names > 0 and table.concat(names, ", ") or L("none found")))
end

local function Running()
    return db and db.enabled and not W.IsOff("AuraTracker") and W.Allowed() and (db.pvp or not W.InPvP())
end

-- Registers / unregisters everything from the current options, zone and roster
local function Apply()
    if not db or #rows == 0 then return end
    local run = Running()
    wipe(tanks)
    if run and (db.tankDebuffs or db.externals or db.immunities or hasCustom) then ResolveTanks() end
    local me = run and (db.myDebuffs or db.externals or db.immunities or hasCustom)
    SetUnit(rows[1], me and "player" or nil)
    for k = 1, ROWS - 1 do SetUnit(rows[k + 1], run and tanks[k] or nil) end
    UpdateLabels()
    UpdateStatus()
end

-- Options changed: read every tracked unit again
local function Rescan()
    for _, row in ipairs(rows) do Scan(row); Dirty(row) end
end

local function SetUnlocked(v)
    unlocked = v
    for _, row in ipairs(rows) do
        row:EnableMouse(v)
        row.bg:SetShown(v)
        Dirty(row)
    end
    UpdateLabels()
end

-- test = sample icons on every row, unlocked so they can be placed
local function SetTest(v)
    testMode = v
    TEST = nil
    SetUnlocked(v)
end

-- "Test all": the sample icons for 30 seconds (a newer test keeps its own stop)
local testRun = 0
W.RegisterTest("Aura Tracking", function() return db and db.enabled end,
    function()
        SetTest(true)
        testRun = testRun + 1
        local run = testRun
        W.After(30, function() if run == testRun and testMode then SetTest(false) end end)
    end,
    function() testRun = testRun + 1; if testMode then SetTest(false) end end)

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
W.OnReady(function()
    db = W.DB("auras", { enabled = false, myDebuffs = true, tankDebuffs = true, externals = true, immunities = true,
        hideNoDuration = true, pvp = false, size = 32, custom = "", tankNames = "" })
    if type(db.pos) ~= "table" then db.pos = {} end
    for i = 1, ROWS do NewRow(i) end
end)

W.On("PLAYER_LOGIN", function()
    -- spell names are read once the game data is loaded
    FillSet(IMMUNITY_SPELLS, immById, immByName)
    FillSet(EXTERNAL_SPELLS, extById, extByName)
    ParseCustom()
end)
W.On("PLAYER_ENTERING_WORLD", Apply)

-- the roster changes in bursts: the shared "roster settled" signal runs once after them
local function RosterChanged()
    if db and db.enabled then Apply() end
end
W.OnRoster(RosterChanged)
W.On("PLAYER_ROLES_ASSIGNED", RosterChanged)

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
local function Option(p, key, text, y)
    W.Check(p, text, function() return db[key] end, function(v) db[key] = v; Apply(); Rescan() end):SetPoint("TOPLEFT", 12, y)
end

W.RegisterModule("AuraTracker", L("Aura Tracking"), function(p)
    W.Title(p, L("Aura Tracking"))
    Option(p, "enabled", L("Enable aura tracking"), -40)
    Option(p, "myDebuffs", L("My debuffs"), -70)
    Option(p, "tankDebuffs", L("Co-tank debuffs"), -94)
    Option(p, "externals", L("External buffs (Power Infusion, Blessings, Innervate, Fear Ward)"), -118)
    Option(p, "immunities", L("Immunities (Divine Shield, Ice Block, Blessing of Protection...)"), -142)
    Option(p, "hideNoDuration", L("Hide debuffs without a duration"), -172)
    Option(p, "pvp", L("Also in battlegrounds and arenas"), -196)

    W.Label(p, L("Co-tanks (empty = automatic from raid roles, max 2):"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 16, -232)
    local tankBox = W.EditBox(p, 240, 60)
    tankBox:SetPoint("TOPLEFT", 20, -248)
    local function saveTanks(self)
        db.tankNames = table.concat(W.NameList(self:GetText()), ", ")
        self:SetText(db.tankNames)
        Apply()
    end
    tankBox:SetScript("OnEnterPressed", function(self) saveTanks(self); self:ClearFocus() end)
    tankBox:SetScript("OnEditFocusLost", saveTanks)
    tankBox:SetScript("OnShow", function(self) self:SetText(db.tankNames or "") end)
    UI.status = W.Label(p, "", "GameFontHighlightSmall")
    UI.status:SetPoint("LEFT", tankBox, "RIGHT", 12, 0)

    W.Label(p, L("Custom auras (spell IDs or names, comma separated):"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 16, -282)
    local bg, box = W.MultiEdit(p, 460, 60, 500)
    bg:SetPoint("TOPLEFT", 16, -298)
    box:SetScript("OnShow", function(self) self:SetText(db.custom or "") end)
    box:SetScript("OnEditFocusLost", function(self)
        db.custom = self:GetText()
        ParseCustom()
        Apply()
        Rescan()
    end)

    local move, test
    local function syncButtons()
        move:SetText(unlocked and L("Lock") or L("Move"))
        test:SetText(testMode and L("Stop test") or "Test")
    end
    move = W.Button(p, L("Move"), 110, 22, function()
        if testMode then SetTest(false) else SetUnlocked(not unlocked) end
        syncButtons()
    end)
    move:SetPoint("TOPLEFT", 16, -372)
    test = W.Button(p, "Test", 110, 22, function() SetTest(not testMode); syncButtons() end)
    test:SetPoint("LEFT", move, "RIGHT", 6, 0)
    local smaller = W.Button(p, L("Size -"), 80, 22, function()
        db.size = math.max(20, (db.size or 32) - 2)
        for _, row in ipairs(rows) do PlaceIcons(row) end
    end)
    smaller:SetPoint("LEFT", test, "RIGHT", 6, 0)
    W.Button(p, L("Size +"), 80, 22, function()
        db.size = math.min(56, (db.size or 32) + 2)
        for _, row in ipairs(rows) do PlaceIcons(row) end
    end):SetPoint("LEFT", smaller, "RIGHT", 6, 0)
    W.Button(p, L("Reset positions"), 172, 22, function()
        wipe(db.pos)
        for _, row in ipairs(rows) do Anchor(row) end
    end):SetPoint("TOPLEFT", 16, -400)

    local info = W.Label(p, L("Co-tanks are the raid's main tanks (or the Tank role). Type names to choose them yourself.") .. "\n"
        .. L("Border: gold = immunity, green = external, blue = custom, debuff = its dispel type color.") .. "\n"
        .. L("Timers are drawn by the game itself: no addon code runs every frame.") .. "\n"
        .. L("Countdown numbers: Blizzard option \"Show numbers for cooldowns\" (or OmniCC)."), "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, -434)
    info:SetWidth(620)
    info:SetTextColor(0.7, 0.7, 0.7)
    -- leaving the tab locks the icons again (click-through, no test icons)
    p:HookScript("OnHide", function()
        if testMode or unlocked then SetTest(false) end
        syncButtons()
    end)
    p:HookScript("OnShow", syncButtons)
end, function() UpdateStatus() end)
