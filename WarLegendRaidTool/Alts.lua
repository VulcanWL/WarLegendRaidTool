-- WarLegend RaidTool - My characters (alts)
-- Every character of the account in one place, like Altoholic / OneWoW AltTracker: gold (total, today's
-- change, gold in the mailbox), level, item level, rested XP, zone, professions, raid lockouts, played time,
-- and where an item is (bags, bank, mailbox) across all characters.
-- Cost: nothing in combat. Data is read at login and logout, when your money changes, and while the bank
-- or the mailbox is open. Characters are recorded even outside the guild (alts are often guildless);
-- the window itself stays reserved to guild members like the rest of the addon.
local W = WLRT
W.AddFR({
    ["My characters"] = "Mes personnages",
    ["Overview"] = "Vue d'ensemble",
    ["Items"] = "Objets",
    ["Lockouts"] = "Verrouillages",
    ["Character"] = "Personnage",
    ["Lvl"] = "Niv",
    ["Ilvl"] = "Ilvl",
    ["Gold"] = "Or",
    ["Today"] = "Aujourd'hui",
    ["Rested"] = "Repos",
    ["Zone"] = "Zone",
    ["Professions"] = "Métiers",
    ["Seen"] = "Vu",
    ["Total: %s (%s today), %d character(s)"] = "Total : %s (%s aujourd'hui), %d personnage(s)",
    ["This realm only"] = "Ce royaume uniquement",
    ["Sort: gold"] = "Tri : or",
    ["Sort: level"] = "Tri : niveau",
    ["Sort: name"] = "Tri : nom",
    ["Sort: last seen"] = "Tri : vu le",
    ["Update played time"] = "Mettre à jour le temps de jeu",
    ["Forget %s?"] = "Oublier %s ?",
    ["Right-click a character to forget it. Log in once on each character so it appears here."] =
        "Clic droit sur un personnage pour l'oublier. Connecte-toi une fois sur chaque personnage pour qu'il apparaisse ici.",
    ["Item (name, ID or shift-click):"] = "Objet (nom, ID ou shift-clic) :",
    ["Item"] = "Objet",
    ["Bags"] = "Sacs",
    ["Bank"] = "Banque",
    ["Mail"] = "Courrier",
    ["Total"] = "Total",
    ["The bank and the mailbox are read when you open them on each character."] =
        "La banque et le courrier sont lus quand tu les ouvres sur chaque personnage.",
    ["Instance"] = "Instance",
    ["Progress"] = "Progression",
    ["Resets in"] = "Réinitialisation dans",
    ["Played: %s"] = "Temps de jeu : %s",
    ["Gold in the mailbox: %s"] = "Or au courrier : %s",
    ["Guild: %s"] = "Guilde : %s",
    ["Last seen: %s"] = "Vu : %s",
    ["Raid lockouts:"] = "Verrouillages de raid :",
})
local L = W.L

local db
local KEYRING = Enum and Enum.BagIndex and Enum.BagIndex.Keyring
local LAST_BAG = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or NUM_BAG_SLOTS or 4
local BANK_FIRST = Enum and Enum.BagIndex and Enum.BagIndex.CharacterBankTab_1
local BANK_LAST = Enum and Enum.BagIndex and (Enum.BagIndex.CharacterBankTab_9 or Enum.BagIndex.CharacterBankTab_6)
local NumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots

-- "First Surname-Realm" on Forever (two alts may share a first name), "Name-Realm" elsewhere
local function Key()
    return (W.UnitDisplayName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "?")
end

-- data saved before the surname was in the key ("First-Realm"): taken over when it is mine
local function OldKey()
    return (W.Safe(UnitName("player")) or "?") .. "-" .. (GetRealmName and GetRealmName() or "?")
end

local function Char()
    if not db then return {} end -- before ADDON_LOADED: nothing is kept
    local k = Key()
    local c = db.chars[k]
    if not c then
        local old = OldKey()
        local o = old ~= k and db.chars[old]
        if o and (not o.full or o.full == W.UnitFullName("player")) then
            c, db.chars[old] = o, nil
        else
            c = {}
        end
        db.chars[k] = c
    end
    return c
end

local function Today() return date("%Y-%m-%d") end

---------------------------------------------------------------------------
-- Reading the current character
---------------------------------------------------------------------------
local function SetMoney(c)
    c.money = W.Safe(GetMoney()) or c.money or 0
    if c.day ~= Today() then c.day, c.dayStart = Today(), c.money end
end

local function Professions()
    local out = {}
    if GetProfessions and GetProfessionInfo then
        local idx = { GetProfessions() }
        for i = 1, 6 do
            if idx[i] then
                local name, _, rank, max = GetProfessionInfo(idx[i])
                if name then out[#out + 1] = { n = name, r = rank or 0, m = max or 0 } end
            end
        end
    end
    return out
end

local function Snapshot()
    local c = Char()
    c.name = W.UnitDisplayName("player") or "?"
    c.full = W.UnitFullName("player") or c.full -- full identity ("First Surname" on Forever), for the guild bank
    c.realm = GetRealmName and GetRealmName() or "?"
    c.class = W.UnitClassToken("player")
    c.faction = UnitFactionGroup and UnitFactionGroup("player") or nil
    c.level = W.Safe(UnitLevel("player")) or c.level
    c.maxLevel = GetMaxPlayerLevel and GetMaxPlayerLevel() or c.maxLevel
    local xp, max = W.Safe(UnitXP("player")) or 0, W.Safe(UnitXPMax("player")) or 0
    c.xp = max > 0 and xp / max or 0
    c.rested = max > 0 and (W.Safe(GetXPExhaustion and GetXPExhaustion()) or 0) / max or 0
    if GetAverageItemLevel then
        local _, equipped = GetAverageItemLevel()
        equipped = W.Safe(equipped)
        if equipped and equipped > 0 then c.ilvl = math.floor(equipped + 0.5) end
    end
    c.zone = (GetRealZoneText and GetRealZoneText()) or c.zone
    c.guild = GetGuildInfo and GetGuildInfo("player") or nil
    c.profs = Professions()
    SetMoney(c)
    c.seen = time()
end

-- Item counts of a range of containers, added into `into`; item names kept for the search
local function Count(into, first, last)
    if not (db and NumSlots and C_Container and C_Container.GetContainerItemInfo) then return end
    for bag = first, last do
        for slot = 1, (NumSlots(bag) or 0) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = info and W.Safe(info.itemID)
            if id then
                into[id] = (into[id] or 0) + (W.Safe(info.stackCount) or 1)
                if not db.names[id] then db.names[id] = W.GetItemInfo(id) end
            end
        end
    end
end

local function ScanBags()
    local bags = {}
    Count(bags, 0, LAST_BAG)
    if KEYRING then Count(bags, KEYRING, KEYRING) end
    Char().bags = bags
end

local function ScanBank()
    local bank = {}
    if BANK_FIRST and BANK_LAST then
        Count(bank, BANK_FIRST, BANK_LAST)
    elseif BANK_CONTAINER then
        Count(bank, BANK_CONTAINER, BANK_CONTAINER)
        if NUM_BANKBAGSLOTS then Count(bank, (NUM_BAG_SLOTS or 4) + 1, (NUM_BAG_SLOTS or 4) + NUM_BANKBAGSLOTS) end
    end
    Char().bank = bank
end

local function ScanMail()
    if not (db and GetInboxNumItems and GetInboxItem) then return end
    local items, money = {}, 0
    for i = 1, (GetInboxNumItems() or 0) do
        local _, _, _, _, gold, _, _, hasItem = GetInboxHeaderInfo(i)
        money = money + (W.Safe(gold) or 0)
        if hasItem then
            for a = 1, (ATTACHMENTS_MAX_RECEIVE or 16) do
                local name, id, _, count = GetInboxItem(i, a)
                id = W.Safe(id)
                if id then
                    items[id] = (items[id] or 0) + (W.Safe(count) or 1)
                    if not db.names[id] then db.names[id] = W.Safe(name) end
                end
            end
        end
    end
    local c = Char()
    c.mail, c.mailMoney = items, money
end

local function ReadLockouts()
    if not (GetNumSavedInstances and GetSavedInstanceInfo) then return end
    local out = {}
    for i = 1, GetNumSavedInstances() do
        local name, _, reset, _, locked, _, _, _, _, diffName, numBosses, killed = GetSavedInstanceInfo(i)
        name, reset, locked, diffName = W.Safe(name), W.Safe(reset), W.Safe(locked), W.Safe(diffName)
        numBosses, killed = W.Safe(numBosses), W.Safe(killed)
        if name and locked and reset and reset > 0 then
            out[#out + 1] = { n = name, d = diffName, k = killed or 0, b = numBosses or 0, r = time() + reset }
        end
    end
    Char().lockouts = out
end

---------------------------------------------------------------------------
-- Events (recorded on every character, guild or not)
---------------------------------------------------------------------------
local bankOpen, bankPending, mailPending = false, false, false

W.OnReady(function()
    db = W.DB("alts", { realmOnly = false, sort = "gold" })
    if type(db.chars) ~= "table" then db.chars = {} end
    if type(db.names) ~= "table" then db.names = {} end
    -- item names are only kept for items someone still holds: the file never grows without limit
    local count = 0
    for _ in pairs(db.names) do count = count + 1 end
    if count > 5000 then
        local keep = {}
        for _, c in pairs(db.chars) do
            for _, where in ipairs({ "bags", "bank", "mail" }) do
                for id in pairs(type(c[where]) == "table" and c[where] or {}) do keep[id] = db.names[id] end
            end
        end
        db.names = keep
    end
end)

W.On("PLAYER_ENTERING_WORLD", function(isLogin, isReload)
    Snapshot()
    if isLogin or isReload then
        if RequestRaidInfo then RequestRaidInfo() end
        W.After(5, ScanBags)
    end
end, true)
W.On("PLAYER_LOGOUT", function() Snapshot(); ScanBags() end, true)
W.On("PLAYER_MONEY", function() SetMoney(Char()) end, true)
W.On("PLAYER_LEVEL_UP", function(level) Char().level = W.Safe(level) or Char().level end, true)
W.On("UPDATE_INSTANCE_INFO", ReadLockouts, true)
W.On("TIME_PLAYED_MSG", function(total) Char().played = W.Safe(total) end, true)

local bagEv -- bag moves are only read while the bank is open
W.On("BANKFRAME_OPENED", function() bankOpen = true; W.Activate(bagEv, true); W.After(0.5, ScanBank) end, true)
W.On("BANKFRAME_CLOSED", function() bankOpen = false; W.Activate(bagEv, false) end, true)
-- while the bank is open, any move is read again once things settle
bagEv = W.On("BAG_UPDATE_DELAYED", function()
    if not bankOpen or bankPending then return end
    bankPending = true
    W.After(1, function() bankPending = false; if bankOpen then ScanBank(); ScanBags() end end)
end, true, true) -- off until the bank opens
W.On("MAIL_INBOX_UPDATE", function()
    if mailPending then return end
    mailPending = true
    W.After(0.5, function() mailPending = false; ScanMail() end)
end, true)

---------------------------------------------------------------------------
-- Display helpers
---------------------------------------------------------------------------
local function Gold(copper)
    local g = math.floor(math.abs(copper or 0) / 10000)
    return (BreakUpLargeNumbers and BreakUpLargeNumbers(g) or tostring(g)) .. "|cffffd700g|r"
end

local function Change(c)
    local delta = (c.day == Today() and c.dayStart) and (c.money - c.dayStart) or 0
    if delta == 0 then return "|cff777777-|r", 0 end
    return (delta > 0 and "|cff33ff66+" or "|cffff5555-") .. Gold(delta) .. "|r", delta
end

local function Played(secs)
    if not secs then return "?" end
    local d, h = math.floor(secs / 86400), math.floor(secs % 86400 / 3600)
    return d > 0 and string.format("%dd %dh", d, h) or string.format("%dh %dm", h, math.floor(secs % 3600 / 60))
end

local function ResetsIn(t)
    local s = t - time()
    if s >= 86400 then return string.format("%dd %dh", math.floor(s / 86400), math.floor(s % 86400 / 3600)) end
    return string.format("%dh %dm", math.floor(s / 3600), math.floor(s % 3600 / 60))
end

local function CharList()
    local list, realm = {}, GetRealmName and GetRealmName()
    for key, c in pairs(db.chars) do
        if c.name and (not db.realmOnly or c.realm == realm) then
            c.key = key
            list[#list + 1] = c
        end
    end
    local sort = db.sort
    table.sort(list, function(a, b)
        if sort == "level" and (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
        if sort == "seen" and (a.seen or 0) ~= (b.seen or 0) then return (a.seen or 0) > (b.seen or 0) end
        if sort == "gold" and (a.money or 0) ~= (b.money or 0) then return (a.money or 0) > (b.money or 0) end
        return a.name < b.name
    end)
    return list
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
local UI = {}

local function RefreshOverview()
    if not UI.overview or not UI.overview:IsVisible() then return end
    local me, total, today = Key(), 0, 0
    local rows = {}
    for _, c in ipairs(CharList()) do
        local change, delta = Change(c)
        total, today = total + (c.money or 0), today + delta
        local profs = {}
        for _, p in ipairs(c.profs or {}) do profs[#profs + 1] = p.n .. " " .. p.r end
        local lvl = tostring(c.level or "?")
        if c.maxLevel and c.level and c.level < c.maxLevel and c.xp then lvl = lvl .. " |cff999999" .. math.floor(c.xp * 100) .. "%|r" end
        local rested = (c.maxLevel and c.level and c.level >= c.maxLevel) and "-" or (math.floor((c.rested or 0) * 100) .. "%")
        rows[#rows + 1] = { char = c, cells = {
            (c.key == me and "|cff33ff66*|r " or "") .. W.ColorName(c.name, c.class) .. " |cff777777" .. (c.realm or "") .. "|r",
            lvl, c.ilvl and tostring(c.ilvl) or "-", Gold(c.money), change, rested, c.zone or "",
            table.concat(profs, ", "), c.key == me and "|cff33ff66*|r" or W.Ago(c.seen) } }
    end
    UI.overview:SetData(rows)
    UI.summary:SetText(string.format(L("Total: %s (%s today), %d character(s)"), Gold(total),
        (today >= 0 and "+" or "-") .. Gold(today), #rows))
end

local function CharTooltip(c, owner)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(c.name .. " - " .. (c.realm or ""), W.ClassColor(c.class))
    if c.guild then GameTooltip:AddLine(string.format(L("Guild: %s"), c.guild), 0.8, 0.8, 0.8) end
    GameTooltip:AddLine(string.format(L("Played: %s"), Played(c.played)), 0.8, 0.8, 0.8)
    if (c.mailMoney or 0) > 0 then GameTooltip:AddLine(string.format(L("Gold in the mailbox: %s"), Gold(c.mailMoney)), 1, 1, 1) end
    for _, p in ipairs(c.profs or {}) do
        GameTooltip:AddDoubleLine(p.n, p.r .. (p.m > 0 and ("/" .. p.m) or ""), 0.8, 0.8, 0.8, 1, 1, 1)
    end
    local any = false
    for _, lo in ipairs(c.lockouts or {}) do
        if lo.r > time() then
            if not any then GameTooltip:AddLine(L("Raid lockouts:"), 1, 0.82, 0); any = true end
            GameTooltip:AddDoubleLine(lo.n .. (lo.d and (" (" .. lo.d .. ")") or ""), lo.k .. "/" .. lo.b .. "  " .. ResetsIn(lo.r), 1, 1, 1, 0.8, 0.8, 0.8)
        end
    end
    GameTooltip:AddLine(string.format(L("Last seen: %s"), date("%d/%m %H:%M", c.seen or 0)), 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function BuildOverview(p)
    UI.summary = W.Label(p, "", "GameFontNormal")
    UI.summary:SetPoint("TOPLEFT", 14, -10)
    W.Check(p, L("This realm only"), function() return db.realmOnly end, function(v) db.realmOnly = v; RefreshOverview() end)
        :SetPoint("TOPLEFT", 10, -30)
    W.Cycle(p, 140, { { "gold", L("Sort: gold") }, { "level", L("Sort: level") }, { "name", L("Sort: name") }, { "seen", L("Sort: last seen") } },
        function() return db.sort end, function(v) db.sort = v; RefreshOverview() end):SetPoint("TOPLEFT", 220, -30)
    W.Button(p, L("Update played time"), 190, 22, function() if RequestTimePlayed then RequestTimePlayed() end end)
        :SetPoint("TOPLEFT", 370, -30)
    UI.overview = W.Table(p, { { L("Character"), 175 }, { L("Lvl"), 55, "RIGHT" }, { L("Ilvl"), 35, "RIGHT" },
        { L("Gold"), 90, "RIGHT" }, { L("Today"), 80, "RIGHT" }, { L("Rested"), 50, "RIGHT" }, { L("Zone"), 110 },
        { L("Professions"), 120 }, { L("Seen"), 40, "CENTER" } }, 430)
    UI.overview:SetPoint("TOPLEFT", 10, -60)
    UI.overview.onEnter = function(data, row) CharTooltip(data.char, row) end
    UI.overview.onClick = function(data, btn)
        local c = data.char
        if btn ~= "RightButton" or c.key == Key() then return end
        W.Confirm(string.format(L("Forget %s?"), c.name .. "-" .. (c.realm or "")), function()
            db.chars[c.key] = nil
            RefreshOverview()
        end)
    end
    local hint = W.Label(p, L("Right-click a character to forget it. Log in once on each character so it appears here."), "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", 14, 8)
    p:SetScript("OnShow", function() Snapshot(); ScanBags(); RefreshOverview() end)
end

local function RefreshItems()
    if not UI.items or not UI.items:IsVisible() then return end
    local text = (UI.search:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local rows = {}
    if text ~= "" then
        local wantId = W.ItemID(text)
        local query = not wantId and text:lower() or nil
        local found = {}
        for _, c in pairs(db.chars) do
            for _, where in ipairs({ "bags", "bank", "mail" }) do
                for id in pairs(c[where] or {}) do
                    if not found[id] then
                        local name = db.names[id] or W.GetItemInfo(id) -- not in the cache at scan time: asked again
                        if name and not db.names[id] then db.names[id] = W.Safe(name) end
                        if (wantId and id == wantId) or (query and name and name:lower():find(query, 1, true)) then found[id] = true end
                    end
                end
            end
        end
        local ids = {}
        for id in pairs(found) do ids[#ids + 1] = id end
        table.sort(ids, function(a, b) return (db.names[a] or "") < (db.names[b] or "") end)
        for _, id in ipairs(ids) do
            for _, c in ipairs(CharList()) do
                local b, k, m = (c.bags or {})[id] or 0, (c.bank or {})[id] or 0, (c.mail or {})[id] or 0
                if b + k + m > 0 then
                    rows[#rows + 1] = { cells = { W.ItemLink("item:" .. id), W.ColorName(c.name, c.class),
                        b > 0 and b or "", k > 0 and k or "", m > 0 and m or "", b + k + m } }
                end
            end
            if #rows >= 300 then break end
        end
    end
    UI.items:SetData(rows)
end

local function BuildItems(p)
    local lbl = W.Label(p, L("Item (name, ID or shift-click):"), "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT", 14, -12)
    UI.search = W.EditBox(p, 260, 200)
    UI.search:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
    UI.search:SetScript("OnTextChanged", W.Debounce(0.25, function() RefreshItems() end)) -- once typing pauses
    W.LinkTarget(UI.search)
    UI.items = W.Table(p, { { L("Item"), 260 }, { L("Character"), 160 }, { L("Bags"), 70, "RIGHT" }, { L("Bank"), 70, "RIGHT" },
        { L("Mail"), 70, "RIGHT" }, { L("Total"), 70, "RIGHT" } }, 440)
    UI.items:SetPoint("TOPLEFT", 10, -40)
    local hint = W.Label(p, L("The bank and the mailbox are read when you open them on each character."), "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", 14, 8)
    p:SetScript("OnShow", function() ScanBags(); RefreshItems() end)
end

-- item names arrive from the server a moment after they are asked: the search is run again once
W.On("GET_ITEM_INFO_RECEIVED", W.Coalesce(0.5, function() if W.IsShown("Alts") then RefreshItems() end end))

local function RefreshLockouts()
    if not UI.lockouts or not UI.lockouts:IsVisible() then return end
    local rows, now = {}, time()
    for _, c in ipairs(CharList()) do
        for _, lo in ipairs(c.lockouts or {}) do
            if lo.r > now then
                rows[#rows + 1] = { cells = { W.ColorName(c.name, c.class), lo.n .. (lo.d and (" |cff999999" .. lo.d .. "|r") or ""),
                    lo.k .. "/" .. lo.b, ResetsIn(lo.r) } }
            end
        end
    end
    UI.lockouts:SetData(rows)
end

local function BuildLockouts(p)
    UI.lockouts = W.Table(p, { { L("Character"), 180 }, { L("Instance"), 300 }, { L("Progress"), 90, "RIGHT" },
        { L("Resets in"), 140, "CENTER" } }, 480)
    UI.lockouts:SetPoint("TOPLEFT", 10, -10)
    p:SetScript("OnShow", function() if RequestRaidInfo then RequestRaidInfo() end; RefreshLockouts() end)
end

W.On("UPDATE_INSTANCE_INFO", function() if W.IsShown("Alts") then RefreshLockouts() end end)

-- Every character of the account (read by the guild bank module)
function W.AccountChars() return db and db.chars or {} end

W.RegisterModule("Alts", "My characters", function(p)
    W.Title(p, L("My characters"))
    UI.tabs = W.SubTabs(p, { L("Overview"), L("Items"), L("Lockouts") })
    BuildOverview(UI.tabs.frames[1])
    BuildItems(UI.tabs.frames[2])
    BuildLockouts(UI.tabs.frames[3])
    UI.tabs:Select(1)
end, function()
    if UI.tabs then UI.tabs:Select(UI.tabs.current or 1) end
end)
