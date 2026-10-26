-- WarLegend RaidTool - LootTriage
-- Bags full: marks in the loot window which loot is worth the room, and numbers the bag items to throw away
-- (cheapest first). Value: TSM or Auctionator when installed, else the vendor price. Personal: sends nothing.
local W = WLRT
local L = W.L
local db

W.AddFR({
    ["Loot triage"] = "Tri du butin",
    ["Bags full: shows which loot is worth the room and which bag items to throw away for it, the cheapest first."] =
        "Sacs pleins : montre quel butin vaut la place et quels objets des sacs jeter pour la faire, le moins cher d'abord.",
    ["Enable loot triage"] = "Activer le tri du butin",
    ["Mark the loot window (green + = worth the room, red - = cheaper than my cheapest item)"] =
        "Marquer la fenêtre de butin (+ vert = vaut la place, - rouge = moins cher que mon objet le moins cher)",
    ["Number the bag items to throw away (1 = cheapest), only when the bags are full"] =
        "Numéroter les objets des sacs à jeter (1 = le moins cher), seulement sacs pleins",
    ["Value and rank in the item tooltips"] = "Valeur et rang dans les infobulles",
    ["Price: automatic (TSM, then Auctionator, then vendor)"] = "Prix : automatique (TSM, puis Auctionator, puis marchand)",
    ["Price: TSM"] = "Prix : TSM",
    ["Price: Auctionator"] = "Prix : Auctionator",
    ["Price: vendor"] = "Prix : marchand",
    ["Never counted: quest items, items without any price (hearthstone...), epic and better."] =
        "Jamais comptés : objets de quête, objets sans aucun prix (pierre de foyer...), épiques et mieux.",
    ["Loot triage: %s (%s)"] = "Tri du butin : %s (%s)",
    ["Loot triage: throw away n°%d"] = "Tri du butin : à jeter n°%d",
    ["Price sources found: %s"] = "Sources de prix trouvées : %s",
    ["none (vendor price only)"] = "aucune (prix marchand seulement)",
    ["vendor"] = "marchand",
})

W.OnReady(function()
    db = W.DB("lootTriage", { enabled = false, loot = true, bags = true, tooltip = true, source = "auto" })
end)

local C = C_Container or {}
local NumSlots = C.GetContainerNumSlots or _G.GetContainerNumSlots
local FreeSlots = C.GetContainerNumFreeSlots or _G.GetContainerNumFreeSlots
local ItemLink = C.GetContainerItemLink or _G.GetContainerItemLink
local CLASS_QUEST = (Enum and Enum.ItemClass and Enum.ItemClass.Questitem) or 12
local NUM_BAGS = NUM_BAG_SLOTS or 4

-- the hooks stay installed: they do nothing once the module is switched off (Settings > Modules) or out of the guild
local function On(what) return db and db.enabled and db[what] and W.Allowed() and not W.IsOff("LootTriage") end

---------------------------------------------------------------------------
-- Prices (per unit, in copper)
---------------------------------------------------------------------------
local function TSMPrice(link)
    local api = _G.TSM_API
    if not (api and api.ToItemString and api.GetCustomPriceValue) then return nil end
    local ok, itemString = pcall(api.ToItemString, link)
    if not ok or not itemString then return nil end
    local ok2, v = pcall(api.GetCustomPriceValue, "dbmarket", itemString)
    return ok2 and type(v) == "number" and v > 0 and v or nil
end

local function AuctionatorPrice(link)
    local api = _G.Auctionator and Auctionator.API and Auctionator.API.v1
    if not (api and api.GetAuctionPriceByItemLink) then return nil end
    local ok, v = pcall(api.GetAuctionPriceByItemLink, "WarLegendRaidTool", link)
    return ok and type(v) == "number" and v > 0 and v or nil
end

local function VendorPrice(link)
    local v = select(11, W.GetItemInfo(link))
    return type(v) == "number" and v > 0 and v or nil
end

-- price of one unit and where it comes from (nil: no price known)
local function UnitPrice(link)
    local src = db and db.source or "auto"
    local v
    if src == "auto" or src == "tsm" then v = TSMPrice(link); if v then return v, "TSM" end end
    if src == "auto" or src == "auctionator" then v = AuctionatorPrice(link); if v then return v, "Auctionator" end end
    v = VendorPrice(link)
    if v then return v, L("vendor") end
end

local function Money(c)
    if GetCoinTextureString then return GetCoinTextureString(c) end
    return string.format("%.2fg", c / 10000)
end

-- an item that is never offered to the bin
local function Protected(link)
    local _, _, quality = W.GetItemInfo(link)
    local _, _, _, _, _, classID = W.GetItemInfoInstant(link)
    return quality == nil or classID == CLASS_QUEST or quality >= 4 -- quality not read yet: never offered
end

---------------------------------------------------------------------------
-- Bag ranking (rebuilt after the bags change, only while the option is on)
---------------------------------------------------------------------------
local rank = {}      -- "bag:slot" -> 1 = cheapest
local cheapest       -- value of the cheapest stack in the bags
local bagsFull = false

local function Count(bag, slot)
    if C.GetContainerItemInfo then
        local info = C.GetContainerItemInfo(bag, slot)
        return info and info.stackCount or 1
    end
    local _, n = _G.GetContainerItemInfo(bag, slot)
    return n or 1
end

local function Rebuild()
    wipe(rank); cheapest = nil; bagsFull = false
    if not (db and db.enabled and NumSlots and ItemLink) then return end
    local free, list = 0, {}
    for bag = 0, NUM_BAGS do
        if FreeSlots then
            local n, bagType = FreeSlots(bag)
            if (bagType or 0) == 0 then free = free + (n or 0) end
        end
        for slot = 1, NumSlots(bag) or 0 do
            local link = ItemLink(bag, slot)
            if link and not Protected(link) then
                local price = UnitPrice(link)
                if price then list[#list + 1] = { key = bag .. ":" .. slot, value = price * Count(bag, slot) } end
            end
        end
    end
    table.sort(list, function(a, b) return a.value < b.value end)
    for i, e in ipairs(list) do rank[e.key] = i end
    cheapest = list[1] and list[1].value
    bagsFull = FreeSlots ~= nil and free == 0
end

---------------------------------------------------------------------------
-- Marks on the buttons
---------------------------------------------------------------------------
local marks = {}
local function Mark(button, text, r, g, b)
    local fs = marks[button]
    if not text then if fs then fs:Hide() end; return end
    if not fs then
        fs = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        fs:SetPoint("TOPLEFT", 2, -2)
        marks[button] = fs
    end
    fs:SetText(text); fs:SetTextColor(r, g, b); fs:Show()
end

local function MarkBag(button, bag, slot)
    local n = On("bags") and bagsFull and bag and slot and rank[bag .. ":" .. slot]
    if n and n <= 9 then Mark(button, n, 1, 0.3, 0.3) else Mark(button, nil) end
end

local function MarkLoot(button, lootSlot)
    if not (On("loot") and bagsFull and cheapest and lootSlot and GetLootSlotLink) then Mark(button, nil); return end
    local link = GetLootSlotLink(lootSlot)
    if not link then Mark(button, nil); return end -- money
    local price = UnitPrice(link)
    local count = GetLootSlotInfo and select(3, GetLootSlotInfo(lootSlot))
    local value = price and price * (count or 1)
    if Protected(link) or (value and value > cheapest) then Mark(button, "+", 0.2, 1, 0.2)
    else Mark(button, "-", 1, 0.2, 0.2) end
end

if hooksecurefunc then
    if type(ContainerFrame_Update) == "function" then
        hooksecurefunc("ContainerFrame_Update", W.Timed("hook loot triage bags", function(container)
            local bag, name = container:GetID(), container:GetName()
            for i = 1, container.size or 0 do
                local button = _G[name .. "Item" .. i]
                if button then MarkBag(button, bag, button:GetID()) end
            end
        end))
    else
        local update = W.Timed("hook loot triage bags", function(frame)
            if not frame.EnumerateValidItems then return end
            for _, button in frame:EnumerateValidItems() do
                MarkBag(button, button.GetBagID and button:GetBagID(), button:GetID())
            end
        end)
        if ContainerFrameCombinedBags and ContainerFrameCombinedBags.UpdateItems then hooksecurefunc(ContainerFrameCombinedBags, "UpdateItems", update) end
        for _, frame in ipairs((ContainerFrameContainer or UIParent).ContainerFrames or {}) do
            if frame.UpdateItems then hooksecurefunc(frame, "UpdateItems", update) end
        end
    end
    if type(LootFrame_UpdateButton) == "function" then
        hooksecurefunc("LootFrame_UpdateButton", W.Timed("hook loot triage loot", function(index)
            local button = _G["LootButton" .. index]
            if button then MarkLoot(button, button:IsEnabled() and button.slot) end
        end))
    elseif LootFrame and LootFrame.ScrollBox and LootFrame.ScrollBox.RegisterCallback then
        LootFrame.ScrollBox:RegisterCallback("OnUpdate", W.Timed("hook loot triage loot", function()
            LootFrame.ScrollBox:ForEachFrame(function(frame)
                local data = frame.GetElementData and frame:GetElementData()
                if frame.Item then MarkLoot(frame.Item, data and data.slotIndex) end
            end)
        end))
    end
end

---------------------------------------------------------------------------
-- Events (only while the option is on)
---------------------------------------------------------------------------
local evBags = W.On("BAG_UPDATE_DELAYED", Rebuild, nil, true)
local evLoot = W.On("LOOT_OPENED", Rebuild, nil, true)
local function Apply()
    local on = db and db.enabled and not W.IsOff("LootTriage") and true or false
    W.Activate(evBags, on); W.Activate(evLoot, on)
    if on then Rebuild() else wipe(rank); cheapest = nil; bagsFull = false end -- switched off: no bag scan
    if not (on and On("bags")) then for _, fs in pairs(marks) do fs:Hide() end end -- numbers already on the bags
end
W.OnReady(function() W.After(1, Apply) end)

---------------------------------------------------------------------------
-- Tooltip: value and rank
---------------------------------------------------------------------------
local OnTooltipItem = W.Timed("hook loot triage tooltip", function(tooltip)
    if not On("tooltip") or not tooltip.GetItem then return end
    local _, link = tooltip:GetItem()
    link = W.Safe(link)
    if type(link) ~= "string" or Protected(link) then return end
    local price, src = UnitPrice(link)
    if price then tooltip:AddLine(string.format(L("Loot triage: %s (%s)"), Money(price), src), 0.8, 0.8, 0.8) end
    local owner = tooltip.GetOwner and tooltip:GetOwner()
    if bagsFull and owner and owner.GetID and owner.GetParent then
        local bag = owner.GetBagID and owner:GetBagID() or (owner:GetParent() and owner:GetParent():GetID())
        local n = bag and rank[bag .. ":" .. owner:GetID()]
        if n then tooltip:AddLine(string.format(L("Loot triage: throw away n°%d"), n), 1, 0.4, 0.4) end
    end
end)
if C_TooltipInfo and TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltipItem)
else
    GameTooltip:HookScript("OnTooltipSetItem", OnTooltipItem)
end

---------------------------------------------------------------------------
-- Tab
---------------------------------------------------------------------------
W.RegisterModule("LootTriage", "Loot triage", function(p)
    W.Title(p, L("Loot triage"))
    local intro = W.Label(p, L("Bags full: shows which loot is worth the room and which bag items to throw away for it, the cheapest first."), "GameFontHighlight")
    intro:SetPoint("TOPLEFT", 16, -40); intro:SetWidth(560); intro:SetJustifyH("LEFT")
    local y = 70
    local checks = {
        { "enabled", "Enable loot triage" },
        { "loot", "Mark the loot window (green + = worth the room, red - = cheaper than my cheapest item)" },
        { "bags", "Number the bag items to throw away (1 = cheapest), only when the bags are full" },
        { "tooltip", "Value and rank in the item tooltips" },
    }
    for _, c in ipairs(checks) do
        W.Check(p, L(c[2]), function() return db[c[1]] end, function(v) db[c[1]] = v; Apply() end):SetPoint("TOPLEFT", 16, -y)
        y = y + 26
    end
    W.Cycle(p, 360, { { "auto", L("Price: automatic (TSM, then Auctionator, then vendor)") }, { "tsm", L("Price: TSM") },
        { "auctionator", L("Price: Auctionator") }, { "vendor", L("Price: vendor") } },
        function() return db.source end, function(v) db.source = v; Apply() end):SetPoint("TOPLEFT", 20, -(y + 6))
    y = y + 40
    local found = {}
    if _G.TSM_API then found[#found + 1] = "TSM" end
    if _G.Auctionator and Auctionator.API then found[#found + 1] = "Auctionator" end
    W.Label(p, string.format(L("Price sources found: %s"), #found > 0 and table.concat(found, ", ") or L("none (vendor price only)")), "GameFontHighlightSmall")
        :SetPoint("TOPLEFT", 16, -y)
    W.Label(p, L("Never counted: quest items, items without any price (hearthstone...), epic and better."), "GameFontHighlightSmall")
        :SetPoint("TOPLEFT", 16, -(y + 20))
end)
