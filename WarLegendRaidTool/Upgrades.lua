-- WarLegend RaidTool - Upgrades
-- A button when an item in the bags has a higher item level than what I wear in that slot (same armor type, usable
-- by me). Click = equip, right-click = ignore it. Never equips by itself. Idea of OloLaunch (Olo, MIT). Personal.
local W = WLRT
local L = W.L
local db

W.AddFR({
    ["Bag upgrades"] = "Améliorations dans les sacs",
    ["A button shows the best item of the bags with a higher item level than the one worn in its slot (same armor type, usable by me). Click to equip it, right-click to ignore it. Nothing is equipped by itself."] =
        "Un bouton montre le meilleur objet des sacs d'un niveau d'objet plus haut que celui porté à sa place (même type d'armure, utilisable par moi). Clic pour l'équiper, clic droit pour l'ignorer. Rien n'est équipé tout seul.",
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
    db = W.DB("upgrades", { enabled = true, minGain = 3, locked = true })
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

-- the best upgrade in the bags: { link, bag, slot, gain, slotId, empty }
local function Best()
    if not (NumSlots and ItemLink and GetInventoryItemLink) then return nil end
    -- what I wear, read once per scan (not once per bag item)
    local wornLinks, wornLevels = {}, {}
    for s = 1, 18 do
        local l = GetInventoryItemLink("player", s)
        wornLinks[s], wornLevels[s] = l, l and W.ItemLevel(l) or 0
    end
    local top
    for bag = 0, NUM_BAGS do
        for slot = 1, NumSlots(bag) or 0 do
            local link = ItemLink(bag, slot)
            if link and not ignored[link] then
                local _, _, _, equipLoc, _, classID, subID = W.GetItemInfoInstant(link)
                local slots = equipLoc and SLOTS[equipLoc]
                local lvl = slots and W.ItemLevel(link)
                if lvl then
                    -- the weakest of the slots it fits (two rings, two trinkets)
                    local slotId, worn, wornLink
                    for _, s in ipairs(slots) do
                        if not slotId or wornLevels[s] < worn then slotId, worn, wornLink = s, wornLevels[s], wornLinks[s] end
                    end
                    local sameType = true
                    if wornLink and BODY[slotId] and classID == CLASS_ARMOR then
                        local _, _, _, _, _, wornClass, wornSub = W.GetItemInfoInstant(wornLink)
                        sameType = wornClass ~= CLASS_ARMOR or wornSub == subID
                    end
                    local gain = wornLink and (lvl - worn) or math.huge
                    if sameType and gain >= (db.minGain or 3) and (not top or gain > top.gain) and Usable(bag, slot, link) then
                        top = { link = link, bag = bag, slot = slot, gain = gain, slotId = slotId, empty = not wornLink }
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
    btn.text:SetText(current.empty and string.format(L("New: %s"), name)
        or string.format(L("Upgrade: %s  |cff33ff99+%d ilvl|r"), name, current.gain))
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
    local intro = W.Label(p, L("A button shows the best item of the bags with a higher item level than the one worn in its slot (same armor type, usable by me). Click to equip it, right-click to ignore it. Nothing is equipped by itself."), "GameFontHighlight")
    intro:SetPoint("TOPLEFT", 16, -40); intro:SetWidth(560); intro:SetJustifyH("LEFT")
    W.Check(p, L("Show bag upgrades"), function() return db.enabled end, function(v) db.enabled = v; Apply() end)
        :SetPoint("TOPLEFT", 16, -90)
    W.Check(p, L("Lock the button (else Shift + drag moves it)"), function() return db.locked end, function(v) db.locked = v end)
        :SetPoint("TOPLEFT", 16, -116)
    local gains = {}
    for _, n in ipairs({ 1, 3, 5, 10 }) do gains[#gains + 1] = { n, string.format(L("Minimum gain: %d item levels"), n) } end
    W.Cycle(p, 260, gains, function() return db.minGain end, function(v) db.minGain = v; Refresh() end)
        :SetPoint("TOPLEFT", 20, -148)
    W.Button(p, L("Forget ignored items"), 180, 22, function()
        wipe(ignored); Refresh(); W.Print(L("Ignored items forgotten."))
    end):SetPoint("TOPLEFT", 20, -184)
end)
