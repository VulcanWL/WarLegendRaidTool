-- WarLegend RaidTool - MoneyGoal
-- "Will I have the money?": a small card with my gold (+ grey junk to sell) against a goal I set (mount, training...).
-- Idea of OloLaunch (Olo, MIT). Personal: sends nothing.
local W = WLRT
local L = W.L
local db

W.AddFR({
    ["Money goal"] = "Objectif d'or",
    ["A small card shows my gold (and the grey junk I can sell) against a goal: mount, training, enchant..."] =
        "Une petite carte montre mon or (et la camelote grise à vendre) face à un objectif : monture, entraînement, enchantement...",
    ["Show the money goal"] = "Montrer l'objectif d'or",
    ["Count the grey junk of the bags (vendor price)"] = "Compter la camelote grise des sacs (prix marchand)",
    ["Lock the card (else Shift + drag moves it)"] = "Verrouiller la carte (sinon Maj + glisser la déplace)",
    ["Goal (gold):"] = "Objectif (or) :",
    ["Name:"] = "Nom :",
    ["Goal"] = "Objectif",
    ["ready"] = "prêt",
    ["%s short"] = "il manque %s",
    ["Coins"] = "Pièces",
    ["Grey junk"] = "Camelote grise",
})

W.OnReady(function()
    db = W.DB("moneyGoal", { enabled = false, goal = 0, label = "", junk = true, locked = true })
end)

local C = C_Container or {}
local NumSlots = C.GetContainerNumSlots or _G.GetContainerNumSlots
local SlotInfo = C.GetContainerItemInfo
local NUM_BAGS = NUM_BAG_SLOTS or 4

local CoinText = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString) or GetCoinTextureString -- no global on Forever
local function Coins(c)
    c = math.max(0, math.floor(c + 0.5))
    if CoinText then return CoinText(c) end
    return string.format("%.2fg", c / 10000)
end

local function JunkValue()
    if not (db.junk and NumSlots and SlotInfo) then return 0 end
    local total = 0
    for bag = 0, NUM_BAGS do
        for slot = 1, NumSlots(bag) or 0 do
            local info = SlotInfo(bag, slot)
            if info and info.quality == 0 and not info.hasNoValue then
                local price = select(11, W.GetItemInfo(info.itemID))
                total = total + (tonumber(price) or 0) * (info.stackCount or 1)
            end
        end
    end
    return total
end

---------------------------------------------------------------------------
-- The card
---------------------------------------------------------------------------
local card, money, junk
-- on: the option, the access and Settings > Modules (the first refresh comes from a timer, not an event)
local function Active() return db.enabled and W.Allowed() and not W.IsOff("MoneyGoal") end

local junkStale = false
local function Refresh()
    if not card then return end
    local need = (tonumber(db.goal) or 0) * 10000
    if not Active() or need <= 0 then card:Hide(); return end
    money = GetMoney() or 0
    if junk and InCombatLockdown() then -- the bags are read after the fight
        junkStale = true
    else
        junk, junkStale = JunkValue(), false
    end
    local have = money + junk
    card.title:SetText(db.label ~= "" and db.label or L("Goal"))
    card.bar:SetValue(math.min(1, have / need))
    card.bar.text:SetText(Coins(have) .. "  /  " .. Coins(need))
    if have >= need then
        card.status:SetText(L("ready")); card.status:SetTextColor(0.35, 0.85, 0.4); card.bar:SetStatusBarColor(0.35, 0.85, 0.4)
    else
        card.status:SetText(string.format(L("%s short"), Coins(need - have)))
        card.status:SetTextColor(1, 0.75, 0.2); card.bar:SetStatusBarColor(1, 0.75, 0.2)
    end
    card:Show()
end

local function Build()
    card = CreateFrame("Frame", "WLRTMoneyGoal", UIParent)
    card:SetSize(230, 40)
    card:SetPoint(db.point or "BOTTOM", UIParent, db.relPoint or "BOTTOM", db.x or 0, db.y or 230)
    card:SetFrameStrata("LOW")
    card:SetMovable(true)
    card:SetClampedToScreen(true)
    card:EnableMouse(true)
    card:RegisterForDrag("LeftButton")
    card.bg = card:CreateTexture(nil, "BACKGROUND")
    card.bg:SetAllPoints()
    W.SetColor(card.bg, 0, 0, 0, 0.6)
    card.title = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.title:SetPoint("TOPLEFT", 6, -5)
    card.status = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.status:SetPoint("TOPRIGHT", -6, -5)
    card.bar = CreateFrame("StatusBar", nil, card)
    card.bar:SetPoint("BOTTOMLEFT", 6, 5)
    card.bar:SetPoint("BOTTOMRIGHT", -6, 5)
    card.bar:SetHeight(14)
    card.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    card.bar:SetMinMaxValues(0, 1)
    card.bar.text = card.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.bar.text:SetPoint("CENTER")
    card:SetScript("OnDragStart", function(self) if not db.locked and IsShiftKeyDown() then self:StartMoving() end end)
    card:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint(1)
        db.point, db.relPoint, db.x, db.y = p, rp, x, y
    end)
    card:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddDoubleLine(L("Coins"), Coins(money or 0), 0.8, 0.8, 0.8, 1, 1, 1)
        if db.junk then GameTooltip:AddDoubleLine(L("Grey junk"), Coins(junk or 0), 0.8, 0.8, 0.8, 1, 1, 1) end
        GameTooltip:Show()
    end)
    card:SetScript("OnLeave", function() GameTooltip:Hide() end)
    card:Hide()
end

local queued = false
local function Queue()
    if queued then return end
    queued = true
    W.After(0.5, function() queued = false; Refresh() end, "money goal")
end
local evMoney = W.On("PLAYER_MONEY", Queue, nil, true)
local evBags = W.On("BAG_UPDATE_DELAYED", Queue, nil, true)
local evRegen = W.On("PLAYER_REGEN_ENABLED", function() if junkStale then Queue() end end, nil, true)

local function Apply()
    local on = Active() and true or false
    W.Activate(evMoney, on); W.Activate(evBags, on); W.Activate(evRegen, on)
    Refresh()
end
W.OnReady(function()
    Build()
    W.After(3, Apply)
end)

---------------------------------------------------------------------------
-- Tab
---------------------------------------------------------------------------
W.RegisterModule("MoneyGoal", "Money goal", function(p)
    W.Title(p, L("Money goal"))
    local intro = W.Label(p, L("A small card shows my gold (and the grey junk I can sell) against a goal: mount, training, enchant..."), "GameFontHighlight")
    intro:SetPoint("TOPLEFT", 16, -40); intro:SetWidth(560); intro:SetJustifyH("LEFT")
    W.Check(p, L("Show the money goal"), function() return db.enabled end, function(v) db.enabled = v; Apply() end)
        :SetPoint("TOPLEFT", 16, -70)
    W.Check(p, L("Count the grey junk of the bags (vendor price)"), function() return db.junk end, function(v) db.junk = v; Refresh() end)
        :SetPoint("TOPLEFT", 16, -96)
    W.Check(p, L("Lock the card (else Shift + drag moves it)"), function() return db.locked end, function(v) db.locked = v end)
        :SetPoint("TOPLEFT", 16, -122)
    W.Label(p, L("Goal (gold):")):SetPoint("TOPLEFT", 20, -160)
    local goal = W.EditBox(p, 80, 7)
    goal:SetPoint("TOPLEFT", 130, -155)
    goal:SetNumeric(true)
    goal:SetText(tostring(db.goal or 0))
    goal:SetScript("OnTextChanged", function(self) db.goal = tonumber(self:GetText()) or 0; Refresh() end)
    W.Label(p, L("Name:")):SetPoint("TOPLEFT", 20, -190)
    local label = W.EditBox(p, 200, 40)
    label:SetPoint("TOPLEFT", 130, -185)
    label:SetText(db.label or "")
    label:SetScript("OnTextChanged", function(self) db.label = self:GetText() or ""; Refresh() end)
end)
