-- WarLegend RaidTool - Upgrades
-- A button when an item in the bags is better than what I wear in that slot (same armor type, usable by me): higher
-- item level, or (option) higher stat-weight score for my class and talent tree. Click = equip, right-click = ignore
-- it. Never equips by itself. Idea of OloLaunch (Olo, MIT); stat weights from Wowdee (MIT, see below). Personal.
local W = WLRT
local L = W.L
local db

W.AddFR({
    ["Bag upgrades"] = "Améliorations dans les sacs",
    ["A button shows the best item of the bags that beats the one worn in its slot (same armor type, usable by me), by item level or by stat weights. Nothing is equipped by itself."] =
        "Un bouton montre le meilleur objet des sacs qui bat celui porté à sa place (même type d'armure, utilisable par moi), au niveau d'objet ou aux poids de caractéristiques. Rien n'est équipé tout seul.",
    ["Compare: item level"] = "Comparer : niveau d'objet",
    ["Compare: stat weights (class + talent tree)"] = "Comparer : poids des caractéristiques (classe + arbre de talents)",
    ["Minimum gain: %d%% (stat weights)"] = "Gain minimum : %d %% (poids des caractéristiques)",
    ["Weights: main talent tree (auto)"] = "Poids : arbre de talents principal (auto)",
    ["Weights: %s"] = "Poids : %s",
    ["Feral (cat)"] = "Farouche (félin)",
    ["Feral (bear)"] = "Farouche (ours)",
    ["Upgrade: %s  |cff33ff99+%d%%|r"] = "Amélioration : %s  |cff33ff99+%d %%|r",
    ["Upgrade: %s  |cff33ff99higher score|r"] = "Amélioration : %s  |cff33ff99meilleur score|r",
    ["Score %s: %d -> %d"] = "Score %s : %d -> %d",
    ["Stat weights: starting values from Classic theorycraft (Wowdee, MIT). Hit and crit are read as ratings."] =
        "Poids des caractéristiques : valeurs de départ de la théorie Classic (Wowdee, MIT). Toucher et critique sont lus en score.",
    ["Show bag upgrades"] = "Montrer les améliorations des sacs",
    ["Minimum gain: %d item levels"] = "Gain minimum : %d niveaux d'objet",
    ["Lock the button (else Shift + drag moves it)"] = "Verrouiller le bouton (sinon Maj + glisser le déplace)",
    ["Upgrade: %s  |cff33ff99+%d ilvl|r"] = "Amélioration : %s  |cff33ff99+%d niv.|r",
    ["New: %s"] = "Nouveau : %s",
    ["Click to equip, right-click to ignore it"] = "Clic pour équiper, clic droit pour l'ignorer",
    ["Equip it after the combat."] = "Équipe-le après le combat.",
    ["Ignored items forgotten."] = "Objets ignorés oubliés.",
    ["Forget ignored items"] = "Oublier les objets ignorés",
})

W.OnReady(function()
    -- mode: "ilvl" or "score"; spec<CLASS> (a class at a time, the DB is shared by my characters): 0 or none = the
    -- tree with the most points, else its index in WEIGHTS
    db = W.DB("upgrades", { enabled = true, minGain = 3, locked = true, mode = "ilvl", minPct = 3 })
end)

local C = C_Container or {}
local NumSlots = C.GetContainerNumSlots or _G.GetContainerNumSlots
local ItemLink = C.GetContainerItemLink or _G.GetContainerItemLink
local Equip = (C_Item and C_Item.EquipItemByName) or _G.EquipItemByName
local NUM_BAGS = NUM_BAG_SLOTS or 4
local CLASS_ARMOR = (Enum and Enum.ItemClass and Enum.ItemClass.Armor) or 4

-- equip location -> inventory slots it can go in (one-hand weapons: main hand only)
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}
-- body armor: only the armor type I already wear there (no leather for a warrior in plate)
local BODY = { [1] = true, [3] = true, [5] = true, [6] = true, [7] = true, [8] = true, [9] = true, [10] = true }

local ignored = {} -- item link -> true, this session

---------------------------------------------------------------------------
-- Stat weights (mode "score"). Weights, stat names and weapon values adapted from Wowdee 0.35.11
-- (Modules/Upgrades.lua), under the MIT License:
--   Copyright (c) Wowdee
--   Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
--   documentation files (the "Software"), to deal in the Software without restriction, including without limitation
--   the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
--   permit persons to whom the Software is furnished to do so, subject to the following conditions:
--   The above copyright notice and this permission notice shall be included in all copies or substantial portions of
--   the Software.
--   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
--   THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
--   CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
--   IN THE SOFTWARE.
-- Starting values from Classic theorycraft, hit / crit per 1%: Forever lists them as ratings, converted with the
-- level-60 rating costs below.
---------------------------------------------------------------------------
local HIT_PER_PCT, SPELLHIT_PER_PCT, CRIT_PER_PCT = 10, 8, 14

-- item stat keys (GetItemStats) -> short names, several client spellings each
local ALIAS = {
    ITEM_MOD_STRENGTH_SHORT = "STR", ITEM_MOD_AGILITY_SHORT = "AGI", ITEM_MOD_STAMINA_SHORT = "STA",
    ITEM_MOD_INTELLECT_SHORT = "INT", ITEM_MOD_SPIRIT_SHORT = "SPI",
    ITEM_MOD_ATTACK_POWER_SHORT = "AP", ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "RAP",
    ITEM_MOD_HIT_RATING_SHORT = "HIT", ITEM_MOD_HIT_MELEE_RATING_SHORT = "HIT_MELEE",
    ITEM_MOD_HIT_RANGED_RATING_SHORT = "HIT_RANGED", ITEM_MOD_HIT_SPELL_RATING_SHORT = "HIT_SPELL",
    ITEM_MOD_CRIT_RATING_SHORT = "CRIT", ITEM_MOD_CRIT_MELEE_RATING_SHORT = "CRIT_MELEE",
    ITEM_MOD_CRIT_RANGED_RATING_SHORT = "CRIT_RANGED", ITEM_MOD_CRIT_SPELL_RATING_SHORT = "CRIT_SPELL",
    ITEM_MOD_HASTE_RATING_SHORT = "HASTE",
    ITEM_MOD_SPELL_POWER_SHORT = "SP", ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "SPELLDMG",
    ITEM_MOD_SPELL_HEALING_DONE_SHORT = "HEAL",
    ITEM_MOD_MANA_REGENERATION_SHORT = "MP5", ITEM_MOD_POWER_REGEN0_SHORT = "MP5",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "DEF", ITEM_MOD_DODGE_RATING_SHORT = "DODGE",
    ITEM_MOD_PARRY_RATING_SHORT = "PARRY", ITEM_MOD_BLOCK_RATING_SHORT = "BLOCK",
    ITEM_MOD_BLOCK_VALUE_SHORT = "BLOCKVAL",
    RESISTANCE0_NAME = "ARMOR", ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "DPS",
}

-- weight per point (hit / crit: per 1%), ARMOR per armor point, DPS per weapon DPS. The first three trees are in the
-- game's talent order; the druid's two extra ones are only chosen by hand.
local WEIGHTS = {
    WARRIOR = { "Arms", "Fury", "Protection",
        Arms = { STR = 2, AGI = 1.2, AP = 1, CRIT = 20, HIT = 22, STA = 0.3, ARMOR = 0.005, DPS = 7 },
        Fury = { STR = 2, AGI = 1.2, AP = 1, CRIT = 22, HIT = 24, STA = 0.3, ARMOR = 0.005, DPS = 6 },
        Protection = { STA = 1.5, DEF = 1.4, DODGE = 1.2, PARRY = 1.1, BLOCK = 0.8, BLOCKVAL = 0.3, AGI = 0.7, STR = 0.6, HIT = 8, ARMOR = 0.1, DPS = 1 },
    },
    PALADIN = { "Holy", "Protection", "Retribution",
        Holy = { HEAL = 1, SP = 1, INT = 0.6, MP5 = 2, CRIT = 8, SPI = 0.1, STA = 0.1 },
        Protection = { STA = 1.5, DEF = 1.4, SPELLDMG = 0.5, SP = 0.5, BLOCK = 0.9, BLOCKVAL = 0.4, STR = 0.5, AGI = 0.5, ARMOR = 0.1, DPS = 1 },
        Retribution = { STR = 2, AGI = 1, AP = 1, CRIT = 20, HIT = 22, INT = 0.3, SPELLDMG = 0.3, STA = 0.3, ARMOR = 0.005, DPS = 7 },
    },
    HUNTER = { "Beast Mastery", "Marksmanship", "Survival",
        ["Beast Mastery"] = { AGI = 2, RAP = 1, AP = 1, CRIT = 20, HIT = 22, INT = 0.3, STA = 0.3, DPS = 8 },
        Marksmanship = { AGI = 2, RAP = 1, AP = 1, CRIT = 22, HIT = 24, INT = 0.3, STA = 0.3, DPS = 9 },
        Survival = { AGI = 2.3, RAP = 1, AP = 1, CRIT = 22, HIT = 22, INT = 0.3, STA = 0.3, DPS = 8 },
    },
    ROGUE = { "Assassination", "Combat", "Subtlety",
        Assassination = { AGI = 2, STR = 1, AP = 1, CRIT = 22, HIT = 24, STA = 0.3, DPS = 6 },
        Combat = { AGI = 2, STR = 1, AP = 1, CRIT = 20, HIT = 26, STA = 0.3, DPS = 7 },
        Subtlety = { AGI = 2, STR = 1, AP = 1, CRIT = 22, HIT = 22, STA = 0.3, DPS = 6 },
    },
    PRIEST = { "Discipline", "Holy", "Shadow",
        Discipline = { HEAL = 1, SP = 1, INT = 0.6, SPI = 0.4, MP5 = 2, CRIT = 8, STA = 0.1 },
        Holy = { HEAL = 1, SP = 1, SPI = 0.6, INT = 0.5, MP5 = 2, CRIT = 7, STA = 0.1 },
        Shadow = { SPELLDMG = 1, SP = 1, HIT = 12, CRIT = 8, INT = 0.3, SPI = 0.3, STA = 0.2 },
    },
    SHAMAN = { "Elemental", "Enhancement", "Restoration",
        Elemental = { SPELLDMG = 1, SP = 1, CRIT = 10, HIT = 12, INT = 0.4, MP5 = 1.5, STA = 0.2 },
        Enhancement = { STR = 2, AGI = 1.4, AP = 1, CRIT = 20, HIT = 22, INT = 0.2, STA = 0.3, DPS = 7 },
        Restoration = { HEAL = 1, SP = 1, MP5 = 2.5, INT = 0.6, CRIT = 7, STA = 0.1 },
    },
    MAGE = { "Arcane", "Fire", "Frost",
        Arcane = { SPELLDMG = 1, SP = 1, INT = 0.6, HIT = 12, CRIT = 9, SPI = 0.3, STA = 0.2 },
        Fire = { SPELLDMG = 1, SP = 1, CRIT = 11, HIT = 13, INT = 0.4, STA = 0.2 },
        Frost = { SPELLDMG = 1, SP = 1, HIT = 13, CRIT = 8, INT = 0.4, STA = 0.25 },
    },
    WARLOCK = { "Affliction", "Demonology", "Destruction",
        Affliction = { SPELLDMG = 1, SP = 1, HIT = 13, CRIT = 6, STA = 0.4, INT = 0.3, SPI = 0.2 },
        Demonology = { SPELLDMG = 1, SP = 1, HIT = 12, CRIT = 8, STA = 0.5, INT = 0.3 },
        Destruction = { SPELLDMG = 1, SP = 1, CRIT = 10, HIT = 13, STA = 0.3, INT = 0.3 },
    },
    DRUID = { "Balance", "Feral Combat", "Restoration", "Feral Cat", "Feral Bear",
        Balance = { SPELLDMG = 1, SP = 1, CRIT = 9, HIT = 12, INT = 0.5, SPI = 0.3, STA = 0.2 },
        ["Feral Combat"] = { AGI = 1.8, STR = 2, AP = 1, CRIT = 20, HIT = 22, STA = 0.8, ARMOR = 0.05 },
        Restoration = { HEAL = 1, SP = 1, SPI = 0.6, INT = 0.5, MP5 = 2, STA = 0.1 },
        ["Feral Cat"] = { AGI = 2, STR = 2, AP = 1, CRIT = 20, HIT = 22, STA = 0.4, ARMOR = 0.02 },
        ["Feral Bear"] = { AGI = 1.5, STR = 1, AP = 0.5, CRIT = 10, HIT = 12, STA = 2, ARMOR = 0.2, DEF = 1, DODGE = 1.5 },
    },
}

-- weapon DPS by weapon kind (14 AP = 1 DPS on each weapon; dual wield: the off hand hits for half; hunters fight
-- with the ranged weapon; tanks live on stats)
local WPN_MELEE = { TWO = 14, MAIN = 12, OFF = 5, RANGED = 1 }
local WPN_DUAL = { TWO = 14, MAIN = 10, OFF = 6, RANGED = 1 }
local WPN_HUNTER = { TWO = 2, MAIN = 1.5, OFF = 1, RANGED = 14 }
local WPN_TANK = { TWO = 4, MAIN = 5, OFF = 2, RANGED = 0.5 }
local WPN = {
    WARRIOR = { Arms = WPN_MELEE, Fury = WPN_DUAL, Protection = WPN_TANK },
    PALADIN = { Protection = WPN_TANK, Retribution = WPN_MELEE },
    HUNTER = { ["Beast Mastery"] = WPN_HUNTER, Marksmanship = { TWO = 2, MAIN = 1.5, OFF = 1, RANGED = 15 }, Survival = WPN_HUNTER },
    ROGUE = { Assassination = WPN_DUAL, Combat = WPN_DUAL, Subtlety = WPN_DUAL },
    SHAMAN = { Enhancement = WPN_MELEE },
}

-- per 1% -> per rating point (casters: spell hit cost)
for name, class in pairs(WEIGHTS) do
    for _, spec in ipairs(class) do
        local w = class[spec]
        local caster = w.SP and not w.DPS
        if w.HIT then w.HIT = w.HIT / (caster and SPELLHIT_PER_PCT or HIT_PER_PCT) end
        if w.CRIT then w.CRIT = w.CRIT / CRIT_PER_PCT end
        w.WPN = WPN[name] and WPN[name][spec]
        w.family = caster and "SPELL" or (w.RAP and "RANGED") or "MELEE"
    end
end

local GetStats = (C_Item and C_Item.GetItemStats) or _G.GetItemStats

-- the game's talent trees -> their index in WEIGHTS: by name when the client gives the English names (the game
-- may list its trees in another order), else the vanilla order (a translated client, or "#2" talent columns)
local function TreeOrder(def, t)
    local order = {}
    for n = 1, 3 do
        local name = t and t.names and t.names[n]
        for j = 1, 3 do if def[j] == name then order[n] = j end end
    end
    if order[1] and order[2] and order[3] then return order end
    return { 1, 2, 3 }
end

-- my weights: the chosen tree, else the one with the most talent points (the first with none); and its index
local function Weights()
    local _, class = UnitClass("player")
    local def = class and WEIGHTS[class]
    if not def then return nil end
    local i = tonumber(db["spec" .. class]) or 0
    if not def[i] then
        i = 1
        local t, most = W.OwnTalents(), 0
        local order = TreeOrder(def, t)
        for n, pts in ipairs(t and t.spent or {}) do
            local j = order[n]
            if type(pts) == "number" and pts > most and j and def[j] then i, most = j, pts end
        end
    end
    return def[def[i]], i, def
end

-- the tree's name: the game's (translated) for the talent trees, ours for the druid's extra ones
local function TreeName(def, i)
    if i == 4 then return L("Feral (cat)") elseif i == 5 then return L("Feral (bear)") end
    local t = W.OwnTalents()
    local order, name = TreeOrder(def, t), nil
    for n = 1, 3 do if order[n] == i then name = t and t.names and t.names[n] end end
    return (name and not name:find("^#")) and name or def[i] -- "#2": the talent columns, without the game's names
end

-- item stats as short names, nil while the item data is not there (not kept then); a link's stats never change
local statCache, cached = {}, 0
local function Stats(link)
    local s = statCache[link]
    if s then return s end
    if not GetStats then return nil end
    local ok, raw = pcall(GetStats, link)
    raw = ok and W.Safe(raw)
    if type(raw) ~= "table" or not next(raw) then return nil end
    s = {}
    for k, v in pairs(raw) do
        local short = ALIAS[k]
        v = W.Safe(v)
        if short and type(v) == "number" and v == v and v > -math.huge and v < math.huge then
            s[short] = math.max(s[short] or v, v) -- two spellings of one stat count once
        end
    end
    if cached >= 500 then wipe(statCache); cached = 0 end
    statCache[link], cached = s, cached + 1
    return s
end

local KIND = { INVTYPE_2HWEAPON = "TWO", INVTYPE_WEAPONOFFHAND = "OFF", INVTYPE_RANGED = "RANGED",
    INVTYPE_RANGEDRIGHT = "RANGED", INVTYPE_THROWN = "RANGED" }
-- the score of an item in a slot with weights w, nil while its stats are unknown
local function Score(link, w, slot)
    local s = Stats(link)
    if not s then return nil end
    local kind = slot == 18 and "RANGED" or KIND[select(4, W.GetItemInfoInstant(link)) or ""] or (slot == 17 and "OFF" or "MAIN")
    local v = 0
    for k, n in pairs(s) do
        if k == "DPS" and w.WPN then v = v + (w.WPN[kind] or 0) * n
        elseif type(w[k]) == "number" then v = v + w[k] * n end
    end
    -- a typed rating (spell hit...) counts only for my damage type, and only without the generic one
    for _, key in ipairs({ "HIT", "CRIT" }) do
        local typed = s[key .. "_" .. w.family]
        if typed and s[key] == nil then v = v + (w[key] or 0) * typed end
    end
    return v
end

-- the game paints in red what I cannot use (class, level, untrained weapon skill)
local function Red(c) return c and c.r and c.r > 0.9 and c.g < 0.25 and c.b < 0.25 end
local function Usable(bag, slot, link)
    local minLevel = select(5, W.GetItemInfo(link))
    if type(minLevel) == "number" and minLevel > (UnitLevel("player") or 1) then return false end
    if not (C_TooltipInfo and C_TooltipInfo.GetBagItem) then return true end
    local ok, data = pcall(C_TooltipInfo.GetBagItem, bag, slot)
    if not (ok and data and data.lines) then return true end
    for i = 2, #data.lines do
        local l = data.lines[i]
        if (l.leftText and l.leftText ~= "" and Red(l.leftColor)) or (l.rightText and l.rightText ~= "" and Red(l.rightColor)) then
            return false
        end
    end
    return true
end

-- the best upgrade in the bags: { link, bag, slot, gain, slotId, empty, pct, worn, value, tree }
local function Best()
    if not (NumSlots and ItemLink and GetInventoryItemLink) then return nil end
    -- stat weights mode: my weights (nil for a class without any: item level then)
    local w, tree, def
    if db.mode == "score" then w, tree, def = Weights() end
    local treeName = w and TreeName(def, tree)
    -- what I wear, read once per scan (not once per bag item): item level, or score (nil = stats not there yet)
    local wornLinks, wornValues = {}, {}
    for s = 1, 18 do
        local l = GetInventoryItemLink("player", s)
        wornLinks[s] = l
        if w then wornValues[s] = l and Score(l, w, s) or (not l and 0) or nil
        else wornValues[s] = l and W.ItemLevel(l) or (not l and 0) or nil end -- not read yet: slot skipped
    end
    local twoHand = wornLinks[16] and select(4, W.GetItemInfoInstant(wornLinks[16])) == "INVTYPE_2HWEAPON"
    local top
    for bag = 0, NUM_BAGS do
        for slot = 1, NumSlots(bag) or 0 do
            local link = ItemLink(bag, slot)
            if link and not ignored[link] then
                local _, _, _, equipLoc, _, classID, subID = W.GetItemInfoInstant(link)
                local slots = equipLoc and SLOTS[equipLoc]
                local value
                if slots and w then value = Score(link, w, slots[1])
                elseif slots then value = W.ItemLevel(link) end
                if value then
                    -- the weakest of the slots it fits (two rings, two trinkets); a slot whose score is unknown is skipped
                    local slotId, worn, wornLink
                    for _, s in ipairs(slots) do
                        local v = wornValues[s]
                        if w and s == 16 and equipLoc == "INVTYPE_2HWEAPON" and v then
                            v = wornValues[17] and v + wornValues[17] or nil -- a two-hander replaces both hands
                        end
                        if s == 17 and twoHand then v = nil end -- no off hand with a two-hander
                        if v and (not slotId or v < worn) then slotId, worn, wornLink = s, v, wornLinks[s] end
                    end
                    local sameType = slotId and true
                    if wornLink and BODY[slotId] and classID == CLASS_ARMOR then
                        local _, _, _, _, _, wornClass, wornSub = W.GetItemInfoInstant(wornLink)
                        sameType = wornClass ~= CLASS_ARMOR or wornSub == subID
                    end
                    local gain = slotId and (wornLink and (value - worn) or math.huge)
                    local pct, enough
                    if w then
                        pct = gain and (worn > 0 and gain / worn * 100 or math.huge)
                        enough = gain and gain > 0 and pct >= (db.minPct or 3)
                    else
                        enough = gain and gain >= (db.minGain or 3)
                    end
                    if sameType and enough and (not top or gain > top.gain) and Usable(bag, slot, link) then
                        top = { link = link, bag = bag, slot = slot, gain = gain, slotId = slotId, empty = not wornLink,
                            pct = pct, worn = worn, value = value, tree = treeName }
                    end
                end
            end
        end
    end
    return top
end

---------------------------------------------------------------------------
-- The button
---------------------------------------------------------------------------
local btn, current
-- on: the option, the access and Settings > Modules (the first refresh comes from a timer, not an event)
local function Active() return db.enabled and W.Allowed() and not W.IsOff("Upgrades") end

local function Refresh()
    if not btn then return end
    current = Active() and Best() or nil
    if not current then btn:Hide(); return end
    local name = W.GetItemInfo(current.link) or current.link
    btn.icon:SetTexture(select(5, W.GetItemInfoInstant(current.link)))
    local text
    if current.empty then text = string.format(L("New: %s"), name)
    elseif current.pct == math.huge then text = string.format(L("Upgrade: %s  |cff33ff99higher score|r"), name)
    elseif current.pct then text = string.format(L("Upgrade: %s  |cff33ff99+%d%%|r"), name, math.floor(current.pct + 0.5))
    else text = string.format(L("Upgrade: %s  |cff33ff99+%d ilvl|r"), name, current.gain) end
    btn.text:SetText(text)
    btn:SetWidth(52 + btn.text:GetStringWidth())
    btn:Show()
end

local function Build()
    btn = CreateFrame("Button", "WLRTUpgrade", UIParent)
    btn:SetSize(200, 40)
    btn:SetPoint(db.point or "BOTTOM", UIParent, db.relPoint or "BOTTOM", db.x or 0, db.y or 280)
    btn:SetFrameStrata("LOW")
    btn:SetMovable(true)
    btn:SetClampedToScreen(true)
    btn:RegisterForDrag("LeftButton")
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    W.SetColor(btn.bg, 0, 0, 0, 0.6)
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(32, 32)
    btn.icon:SetPoint("LEFT", 4, 0)
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.text:SetPoint("LEFT", btn.icon, "RIGHT", 6, 0)
    btn:SetScript("OnDragStart", function(self) if not db.locked and IsShiftKeyDown() then self:StartMoving() end end)
    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint(1)
        db.point, db.relPoint, db.x, db.y = p, rp, x, y
    end)
    btn:SetScript("OnClick", function(_, button)
        if not current then return end
        if button == "RightButton" then ignored[current.link] = true; Refresh(); return end
        if InCombatLockdown() then W.Print(L("Equip it after the combat.")); return end
        if Equip then pcall(Equip, current.link, current.slotId) end
    end)
    btn:SetScript("OnEnter", function(self)
        if not current then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if GameTooltip.SetBagItem then GameTooltip:SetBagItem(current.bag, current.slot) end
        if current.tree then
            GameTooltip:AddLine(string.format(L("Score %s: %d -> %d"), current.tree, math.floor(current.worn + 0.5),
                math.floor(current.value + 0.5)), 0.2, 1, 0.6)
        end
        GameTooltip:AddLine(L("Click to equip, right-click to ignore it"), 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:Hide()
end

-- bag / gear changes come in bursts: one look per burst, never in combat (tooltip scans)
local queued, waiting = false, false
local function Queue()
    if queued then return end
    queued = true
    W.After(0.5, function()
        queued = false
        if InCombatLockdown() then waiting = true; return end
        Refresh()
    end, "upgrades")
end

local handlers = {}
for _, e in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP" }) do
    handlers[#handlers + 1] = W.On(e, Queue, nil, true)
end
handlers[#handlers + 1] = W.On("PLAYER_REGEN_ENABLED", function()
    if waiting then waiting = false; Queue() end
end, nil, true)

local function Apply()
    for _, h in ipairs(handlers) do W.Activate(h, Active() and true or false) end
    Refresh()
end
W.OnReady(function()
    Build()
    W.After(5, Apply) -- item data of the bags arrives after login
end)

---------------------------------------------------------------------------
-- Tab
---------------------------------------------------------------------------
W.RegisterModule("Upgrades", "Bag upgrades", function(p)
    W.Title(p, L("Bag upgrades"))
    local intro = W.Label(p, L("A button shows the best item of the bags that beats the one worn in its slot (same armor type, usable by me), by item level or by stat weights. Nothing is equipped by itself."), "GameFontHighlight")
    intro:SetPoint("TOPLEFT", 16, -40); intro:SetWidth(560); intro:SetJustifyH("LEFT")
    W.Check(p, L("Show bag upgrades"), function() return db.enabled end, function(v) db.enabled = v; Apply() end)
        :SetPoint("TOPLEFT", 16, -90)
    W.Check(p, L("Lock the button (else Shift + drag moves it)"), function() return db.locked end, function(v) db.locked = v end)
        :SetPoint("TOPLEFT", 16, -116)
    W.Cycle(p, 380, { { "ilvl", L("Compare: item level") }, { "score", L("Compare: stat weights (class + talent tree)") } },
        function() return db.mode end, function(v) db.mode = v; Refresh() end):SetPoint("TOPLEFT", 20, -148)
    local gains = {}
    for _, n in ipairs({ 1, 3, 5, 10 }) do gains[#gains + 1] = { n, string.format(L("Minimum gain: %d item levels"), n) } end
    W.Cycle(p, 380, gains, function() return db.minGain end, function(v) db.minGain = v; Refresh() end)
        :SetPoint("TOPLEFT", 20, -178)
    local pcts = {}
    for _, n in ipairs({ 1, 3, 5, 10 }) do pcts[#pcts + 1] = { n, string.format(L("Minimum gain: %d%% (stat weights)"), n) } end
    W.Cycle(p, 380, pcts, function() return db.minPct end, function(v) db.minPct = v; Refresh() end)
        :SetPoint("TOPLEFT", 20, -208)
    local trees = { { 0, L("Weights: main talent tree (auto)") } }
    local _, class = UnitClass("player")
    local def = class and WEIGHTS[class]
    for i = 1, def and #def or 0 do trees[#trees + 1] = { i, string.format(L("Weights: %s"), TreeName(def, i)) } end
    W.Cycle(p, 380, trees, function() return db["spec" .. (class or "")] or 0 end,
        function(v) db["spec" .. (class or "")] = v; Refresh() end)
        :SetPoint("TOPLEFT", 20, -238)
    W.Button(p, L("Forget ignored items"), 180, 22, function()
        wipe(ignored); Refresh(); W.Print(L("Ignored items forgotten."))
    end):SetPoint("TOPLEFT", 20, -274)
    local note = W.Label(p, L("Stat weights: starting values from Classic theorycraft (Wowdee, MIT). Hit and crit are read as ratings."), "GameFontDisable")
    note:SetPoint("TOPLEFT", 16, -308); note:SetWidth(560); note:SetJustifyH("LEFT")
end)
