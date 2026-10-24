-- WarLegend RaidTool - Item levels
-- The useful part of SimpleItemLevel (Kemayo): the item level on the character sheet, the inspect window,
-- the bags, the bank and the loot window, the average under the model, a line in the item tooltips, an arrow
-- on the items better than what I wear, and "E" on the gear missing an enchant (character / inspect).
-- Hooks only (hooksecurefunc / HookScript), our marks on a child frame of each button. Does nothing while
-- the SimpleItemLevel addon itself is loaded (the two would write over each other).
local W = WLRT
W.AddFR({
    ["Item levels"] = "Niveaux d'objet",
    ["On the character sheet"] = "Sur la fiche de personnage",
    ["In the inspect window"] = "Dans la fenêtre d'inspection",
    ["In the bags and the bank"] = "Dans les sacs et la banque",
    ["In the loot window"] = "Dans la fenêtre de butin",
    ["In the item tooltips"] = "Dans les infobulles des objets",
    ["Average item level under the model"] = "Niveau d'objet moyen sous le modèle",
    ["Arrow on the items better than mine"] = "Flèche sur les objets meilleurs que les miens",
    ["\"E\" on the gear missing an enchant (character / inspect)"] = "« E » sur l'équipement sans enchantement (fiche / inspection)",
    ["Color of the item quality"] = "Couleur de la qualité de l'objet",
    ["From quality:"] = "À partir de la qualité :",
    ["Place on the icon:"] = "Place sur l'icône :",
    ["Top right"] = "En haut à droite",
    ["Top left"] = "En haut à gauche",
    ["Bottom right"] = "En bas à droite",
    ["Bottom left"] = "En bas à gauche",
    ["Center"] = "Au centre",
    ["Poor"] = "Mauvais",
    ["Common"] = "Commun",
    ["Uncommon"] = "Inhabituel",
    ["Rare"] = "Rare",
    ["Epic"] = "Épique",
    ["The SimpleItemLevel addon is loaded: disable it, this module replaces it."] =
        "L'addon SimpleItemLevel est chargé : désactive-le, ce module le remplace.",
    ["Weapons and armor only. The arrow compares with what you wear (armor type of your class, not the weapons). A change shows the next time a window opens."] =
        "Armes et armures seulement. La flèche compare avec ce que tu portes (type d'armure de ta classe, pas les armes). Un changement se voit à la prochaine ouverture d'une fenêtre.",
})
local L = W.L
local db

W.OnReady(function()
    db = W.DB("itemLevels", { character = true, inspect = true, bags = true, loot = true, tooltip = true, average = true,
        upgrades = true, enchants = true, color = true, quality = 1, position = "TOPRIGHT" })
end)

-- SimpleItemLevel itself: known once every addon at login is loaded
local standalone = false
W.On("PLAYER_LOGIN", function()
    standalone = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("SimpleItemLevel") and true or false
end)

local function On(opt) return db and db[opt] and not standalone and W.Allowed() and not W.IsOff("ItemLevels") end

local GetInfoInstant = W.GetItemInfoInstant
local QualityColor = (C_Item and C_Item.GetItemQualityColor) or GetItemQualityColor
local CLASS_WEAPON = Enum and Enum.ItemClass and Enum.ItemClass.Weapon or 2
local CLASS_ARMOR = Enum and Enum.ItemClass and Enum.ItemClass.Armor or 4

---------------------------------------------------------------------------
-- Which items: weapons and armor. Upgrades: the armor type my class wears (as LibAppropriateItems
-- with the vanilla rule: plate / mail from level 40), jewelry, cloaks, trinkets; the weapons are left out.
---------------------------------------------------------------------------
local ARMOR = { CLOTH = 1, LEATHER = 2, MAIL = 3, PLATE = 4, SHIELD = 6 }
local BEST = { WARRIOR = { 4, 3 }, PALADIN = { 4, 3 }, HUNTER = { 3, 2 }, SHAMAN = { 3, 2 }, ROGUE = { 2, 2 }, DRUID = { 2, 2 },
    PRIEST = { 1, 1 }, MAGE = { 1, 1 }, WARLOCK = { 1, 1 } }
local SHIELD_CLASSES = { WARRIOR = true, PALADIN = true, SHAMAN = true }
local SLOTS1 = { INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CHEST = 5, INVTYPE_ROBE = 5, INVTYPE_WAIST = 6,
    INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10, INVTYPE_FINGER = 11, INVTYPE_TRINKET = 13,
    INVTYPE_CLOAK = 15, INVTYPE_SHIELD = 17, INVTYPE_HOLDABLE = 17 }
local SLOTS2 = { INVTYPE_FINGER = 12, INVTYPE_TRINKET = 14 }

local function Appropriate(subclass, equipLoc)
    if equipLoc == "INVTYPE_CLOAK" or equipLoc == "INVTYPE_HOLDABLE" or subclass == 0 then return true end -- cloak, off-hand, jewelry
    local class = W.UnitClassToken("player")
    if subclass == ARMOR.SHIELD then return SHIELD_CLASSES[class] or false end
    local best = BEST[class]
    if not best then return false end
    return subclass == ((UnitLevel("player") or 1) >= 40 and best[1] or best[2])
end

local function IsUpgrade(link, level)
    local _, _, _, equipLoc, _, classID, subclass = GetInfoInstant(link)
    if classID ~= CLASS_ARMOR or not SLOTS1[equipLoc] or not Appropriate(subclass, equipLoc) then return false end
    for _, slot in ipairs({ SLOTS1[equipLoc], SLOTS2[equipLoc] }) do
        local worn = GetInventoryItemLink("player", slot)
        if not worn then return true end
        local wornLevel = W.ItemLevel(worn)
        if wornLevel and wornLevel < level then return true end
    end
    return false
end

-- enchantable in vanilla (the wands and the off-hand frills cannot take one)
local ENCHANTABLE = { INVTYPE_HEAD = true, INVTYPE_SHOULDER = true, INVTYPE_CHEST = true, INVTYPE_ROBE = true, INVTYPE_LEGS = true,
    INVTYPE_FEET = true, INVTYPE_WRIST = true, INVTYPE_HAND = true, INVTYPE_CLOAK = true, INVTYPE_SHIELD = true,
    INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true,
    INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true }
local WAND = Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Wand or 19
local function MissingEnchant(link)
    local _, _, _, equipLoc, _, classID, subclass = GetInfoInstant(link)
    if not ENCHANTABLE[equipLoc] or (classID == CLASS_WEAPON and subclass == WAND) then return false end
    local enchant = link:match("item:%-?%d+:(%-?%d*)")
    return enchant == nil or enchant == "" or enchant == "0"
end

---------------------------------------------------------------------------
-- Our marks on a button (a child frame, nothing written in Blizzard's tables)
---------------------------------------------------------------------------
local OFFSETS = { TOPRIGHT = { -2, -2 }, TOPLEFT = { 2, -2 }, BOTTOMRIGHT = { -2, 2 }, BOTTOMLEFT = { 2, 2 }, CENTER = { 0, 0 } }
local overlays = setmetatable({}, { __mode = "k" })
local wanted = setmetatable({}, { __mode = "k" }) -- the link a button waits for (the data loads later)

local function Clean(button)
    local o = overlays[button]
    if o then o.level:Hide(); o.up:Hide(); o.miss:Hide() end
    wanted[button] = nil
end

local function Overlay(button)
    local o = overlays[button]
    if not o then
        o = CreateFrame("Frame", nil, button)
        o:SetAllPoints()
        o.level = o:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        o.up = o:CreateTexture(nil, "OVERLAY")
        o.up:SetSize(10, 10)
        if o.up.SetAtlas then o.up:SetAtlas("poi-door-arrow-up") end
        o.miss = o:CreateFontString(nil, "OVERLAY")
        o.miss:SetFont("Fonts\\ARIALN.TTF", 11, "OUTLINE")
        o.miss:SetTextColor(1, 0.2, 0.2)
        o.miss:SetText("E")
        overlays[button] = o
    end
    o:SetFrameLevel(button:GetFrameLevel() + 2)
    local pos = OFFSETS[db.position] and db.position or "TOPRIGHT"
    o.level:ClearAllPoints()
    o.level:SetPoint(pos, OFFSETS[pos][1], OFFSETS[pos][2])
    o.up:ClearAllPoints()
    o.up:SetPoint(pos == "TOPLEFT" and "TOPRIGHT" or "TOPLEFT", pos == "TOPLEFT" and -2 or 2, -2)
    o.miss:ClearAllPoints()
    o.miss:SetPoint("BOTTOMLEFT", 2, 2)
    return o
end

-- kind: "character" / "inspect" (enchant marks, no upgrade arrow) or "bags" / "loot"
-- File level, not one new function per slot and per bag update; level / quality given when already known
local function Paint(button, link, kind, level, quality)
    if wanted[button] ~= link then return end -- the button shows another item now
    if not level then
        local _
        _, _, quality = W.GetItemInfo(link)
        level = W.ItemLevel(link)
    end
    local _, _, _, _, _, classID = GetInfoInstant(link)
    if not level or (classID ~= CLASS_WEAPON and classID ~= CLASS_ARMOR) or (quality or -1) < db.quality then return end
    local o = Overlay(button)
    local r, g, b = 1, 1, 1
    if db.color and quality and QualityColor then r, g, b = QualityColor(quality) end
    o.level:SetText(level)
    o.level:SetTextColor(r or 1, g or 1, b or 1)
    o.level:Show()
    if db.upgrades and (kind == "bags" or kind == "loot") and IsUpgrade(link, level) then o.up:Show() end
    if db.enchants and (kind == "character" or kind == "inspect") and MissingEnchant(link) then o.miss:Show() end
end

local function Mark(button, link, kind)
    Clean(button)
    if not link then return end
    wanted[button] = link
    local level = W.ItemLevel(link)
    local name, _, quality = W.GetItemInfo(link)
    if level and name then
        Paint(button, link, kind, level, quality)
    elseif Item and Item.CreateFromItemLink then
        -- not loaded yet: a small wrapper only here, level and quality read again once loaded
        local item = Item:CreateFromItemLink(link)
        if item and not item:IsItemEmpty() then item:ContinueOnItemLoad(function() Paint(button, link, kind) end) end
    end
end

---------------------------------------------------------------------------
-- Character sheet and inspect window, with the average item level
---------------------------------------------------------------------------
local function AverageText(fs, value)
    if not fs then return end
    if value and value > 0 then
        fs:SetText(string.format(ITEM_LEVEL or "Item Level %d", math.floor(value + 0.5)))
        fs:Show()
    else
        fs:Hide()
    end
end

local charAvg, charPending
local function CharacterAverage()
    charPending = false
    if not charAvg then
        local parent = _G.CharacterModelScene or _G.CharacterModelFrame
        if not parent then return end
        charAvg = parent:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        charAvg:SetPoint("BOTTOM", 0, 8)
    end
    if not On("average") then charAvg:Hide(); return end
    local equipped = GetAverageItemLevel and select(2, GetAverageItemLevel())
    AverageText(charAvg, W.Safe(equipped))
end

if hooksecurefunc and type(PaperDollItemSlotButton_Update) == "function" then
    hooksecurefunc("PaperDollItemSlotButton_Update", W.Timed("hook character sheet", function(button)
        if not On("character") then Clean(button); return end
        local slot = button:GetID()
        if slot and slot >= 1 and slot <= 19 and slot ~= 4 and slot ~= 19 then -- not the shirt and the tabard
            Mark(button, GetInventoryItemLink("player", slot), "character")
        else
            Clean(button)
        end
        if not charPending then charPending = true; W.After(0.1, CharacterAverage) end
    end))
end

local inspectAvg, inspectRetry
local function InspectAverage(unit)
    if not inspectAvg then
        local parent = _G.InspectModelFrame or _G.InspectModelScene
        if not parent then return end
        inspectAvg = parent:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        inspectAvg:SetPoint("BOTTOM", 0, 24)
    end
    if not On("average") then inspectAvg:Hide(); return end
    local api = C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel
    local value = api and W.Safe(api(unit))
    if not value or value <= 0 then
        -- by hand: the 2-hander counts twice, as the game does
        local sum, missing = 0, false
        for slot = 1, 18 do
            if slot ~= 4 then
                local link = GetInventoryItemLink(unit, slot)
                local lvl = link and W.ItemLevel(link)
                if link and not lvl then missing = true end
                sum = sum + (lvl or 0)
            end
        end
        local main = GetInventoryItemLink(unit, 16)
        if main and not GetInventoryItemLink(unit, 17) and select(4, GetInfoInstant(main)) == "INVTYPE_2HWEAPON" then
            sum = sum + (W.ItemLevel(main) or 0)
        end
        value = not missing and sum / 17 or nil
    end
    AverageText(inspectAvg, value)
end

-- Repaint OUR marks only. Calling Blizzard's UpdateButtons here re-runs InspectPaperDollItemSlotButton_Update
-- on every slot, which closes the item tooltip the cursor is on.
local INSPECT_SLOTS = { "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands", "Waist", "Legs", "Feet",
    "Finger0", "Finger1", "Trinket0", "Trinket1", "MainHand", "SecondaryHand", "Ranged" }
local function RepaintInspect(unit)
    for _, name in ipairs(INSPECT_SLOTS) do
        local button = _G["Inspect" .. name .. "Slot"]
        if button and button.GetID then Mark(button, GetInventoryItemLink(unit, button:GetID()), "inspect") end
    end
end

local function HookInspect()
    if type(InspectPaperDollItemSlotButton_Update) ~= "function" then return end
    hooksecurefunc("InspectPaperDollItemSlotButton_Update", W.Timed("hook inspect window", function(button)
        if not On("inspect") then Clean(button); return end
        local unit = (InspectFrame and InspectFrame.unit) or "target"
        local link = GetInventoryItemLink(unit, button:GetID())
        Mark(button, link, "inspect")
        -- the inspect data comes in bits: one more pass a moment later
        if not inspectRetry then
            inspectRetry = true
            W.After(1.5, function()
                inspectRetry = false
                if InspectFrame and InspectFrame:IsShown() and InspectFrame.unit then
                    if On("inspect") then RepaintInspect(InspectFrame.unit) end
                    InspectAverage(InspectFrame.unit)
                end
            end)
        end
    end))
    if InspectPaperDollFrame and InspectPaperDollFrame.UpdateButtons then
        hooksecurefunc(InspectPaperDollFrame, "UpdateButtons", function() InspectAverage((InspectFrame and InspectFrame.unit) or "target") end)
    elseif type(InspectPaperDollFrame_UpdateButtons) == "function" then
        hooksecurefunc("InspectPaperDollFrame_UpdateButtons", function() InspectAverage((InspectFrame and InspectFrame.unit) or "target") end)
    end
end

local inspectHooked = false
W.On("ADDON_LOADED", function(name)
    if name == "Blizzard_InspectUI" and not inspectHooked then inspectHooked = true; HookInspect() end
end)
W.On("PLAYER_LOGIN", function()
    if not inspectHooked and C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_InspectUI") then
        inspectHooked = true
        HookInspect()
    end
end)

---------------------------------------------------------------------------
-- Bags and bank (old ContainerFrame_Update, or the newer frames with UpdateItems)
---------------------------------------------------------------------------
local GetContainerItemLink = (C_Container and C_Container.GetContainerItemLink) or _G.GetContainerItemLink

local function MarkBagButton(button, bag, slot)
    if not On("bags") or not bag or not slot then Clean(button); return end
    Mark(button, GetContainerItemLink(bag, slot), "bags")
end

-- the hooks run on every bag update while the bags are open (looting...): timed, so /wl perf shows their cost
if hooksecurefunc then
    if type(ContainerFrame_Update) == "function" then
        hooksecurefunc("ContainerFrame_Update", W.Timed("hook bags", function(container)
            local bag, name = container:GetID(), container:GetName()
            for i = 1, container.size or 0 do
                local button = _G[name .. "Item" .. i]
                if button then MarkBagButton(button, bag, button:GetID()) end
            end
        end))
    else
        local update = W.Timed("hook bags", function(frame)
            if not frame.EnumerateValidItems then return end
            for _, button in frame:EnumerateValidItems() do
                MarkBagButton(button, button.GetBagID and button:GetBagID(), button:GetID())
            end
        end)
        if ContainerFrameCombinedBags and ContainerFrameCombinedBags.UpdateItems then hooksecurefunc(ContainerFrameCombinedBags, "UpdateItems", update) end
        for _, frame in ipairs((ContainerFrameContainer or UIParent).ContainerFrames or {}) do
            if frame.UpdateItems then hooksecurefunc(frame, "UpdateItems", update) end
        end
    end
    if type(BankFrameItemButton_Update) == "function" then
        hooksecurefunc("BankFrameItemButton_Update", W.Timed("hook bank", function(button)
            if button.isBag then return end
            MarkBagButton(button, button:GetParent():GetID(), button:GetID())
        end))
    end
end

---------------------------------------------------------------------------
-- Loot window
---------------------------------------------------------------------------
if hooksecurefunc and type(LootFrame_UpdateButton) == "function" then
    hooksecurefunc("LootFrame_UpdateButton", W.Timed("hook loot window", function(index)
        local button = _G["LootButton" .. index]
        if not button then return end
        if not On("loot") or not button:IsEnabled() or not button.slot then Clean(button); return end
        Mark(button, GetLootSlotLink(button.slot), "loot")
    end))
elseif LootFrame and LootFrame.ScrollBox and LootFrame.ScrollBox.RegisterCallback then
    LootFrame.ScrollBox:RegisterCallback("OnUpdate", W.Timed("hook loot window", function()
        LootFrame.ScrollBox:ForEachFrame(function(frame)
            if not frame.Item then return end
            local data = frame.GetElementData and frame:GetElementData()
            if not On("loot") or not (data and data.slotIndex) then Clean(frame.Item); return end
            Mark(frame.Item, GetLootSlotLink(data.slotIndex), "loot")
        end)
    end))
end

---------------------------------------------------------------------------
-- Tooltips: one "Item Level" line (only when the data is there: never added late on another tooltip)
---------------------------------------------------------------------------
local LEVEL_PATTERN = "^" .. (ITEM_LEVEL or "Item Level %d"):gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%d", "%%d+")
-- the game already shows it (some clients do): no second line
local function HasLevelLine(tooltip)
    local name = tooltip.GetName and tooltip:GetName()
    if not name or not tooltip.NumLines then return false end
    for i = 2, math.min(tooltip:NumLines() or 0, 8) do
        local fs = _G[name .. "TextLeft" .. i]
        local text = fs and W.Safe(fs:GetText())
        if type(text) == "string" and text:find(LEVEL_PATTERN) then return true end
    end
    return false
end

local OnTooltipItem = W.Timed("hook item tooltip", function(tooltip)
    if not On("tooltip") or not tooltip.GetItem then return end
    local _, link = tooltip:GetItem()
    link = W.Safe(link)
    if type(link) ~= "string" then return end
    local _, _, _, _, _, classID = GetInfoInstant(link)
    if classID ~= CLASS_WEAPON and classID ~= CLASS_ARMOR then return end
    local level = W.ItemLevel(link)
    if level and not HasLevelLine(tooltip) then tooltip:AddLine(string.format(ITEM_LEVEL or "Item Level %d", level), 1, 0.82, 0) end
end)
if C_TooltipInfo and TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltipItem)
else
    GameTooltip:HookScript("OnTooltipSetItem", OnTooltipItem)
    if ItemRefTooltip then ItemRefTooltip:HookScript("OnTooltipSetItem", OnTooltipItem) end
end

---------------------------------------------------------------------------
-- Tab
---------------------------------------------------------------------------
W.RegisterModule("ItemLevels", "Item levels", function(p)
    W.Title(p, L("Item levels"))
    if standalone then
        W.Label(p, L("The SimpleItemLevel addon is loaded: disable it, this module replaces it."), "GameFontHighlight")
            :SetPoint("TOPLEFT", 16, -40)
    end
    local checks = {
        { "character", "On the character sheet" }, { "inspect", "In the inspect window" }, { "bags", "In the bags and the bank" },
        { "loot", "In the loot window" }, { "tooltip", "In the item tooltips" }, { "average", "Average item level under the model" },
        { "upgrades", "Arrow on the items better than mine" }, { "enchants", "\"E\" on the gear missing an enchant (character / inspect)" },
        { "color", "Color of the item quality" },
    }
    for i, c in ipairs(checks) do
        W.Check(p, L(c[2]), function() return db[c[1]] end, function(v) db[c[1]] = v end)
            :SetPoint("TOPLEFT", 12, -60 - (i - 1) * 24)
    end
    local y = -60 - #checks * 24 - 10
    W.Label(p, L("From quality:"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 16, y - 5)
    W.Cycle(p, 130, { { 0, L("Poor") }, { 1, L("Common") }, { 2, L("Uncommon") }, { 3, L("Rare") }, { 4, L("Epic") } },
        function() return db.quality end, function(v) db.quality = v end):SetPoint("TOPLEFT", 170, y)
    y = y - 30
    W.Label(p, L("Place on the icon:"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 16, y - 5)
    W.Cycle(p, 130, { { "TOPRIGHT", L("Top right") }, { "TOPLEFT", L("Top left") }, { "BOTTOMRIGHT", L("Bottom right") },
        { "BOTTOMLEFT", L("Bottom left") }, { "CENTER", L("Center") } },
        function() return db.position end, function(v) db.position = v end):SetPoint("TOPLEFT", 170, y)
    local info = W.Label(p, L("Weapons and armor only. The arrow compares with what you wear (armor type of your class, not the weapons). A change shows the next time a window opens."),
        "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, y - 40)
    info:SetWidth(680)
    info:SetJustifyH("LEFT")
    info:SetTextColor(0.7, 0.7, 0.7)
end)

W.slash.ilvl = function() W.Toggle("ItemLevels") end
