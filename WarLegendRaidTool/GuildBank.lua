-- WarLegend RaidTool - Guild bank characters (mine)
-- The characters of my account at the guild's bank rank: their gold and what they hold (bags, bank,
-- mailbox), with a search. The data comes from the alts module (read on each character); nothing is sent.
local W = WLRT
W.AddFR({
    ["Alts is switched off: the bags and money shown are not updated."] = "Alts est désactivé : les sacs et l'or affichés ne sont plus mis à jour.",
    ["Guild bank"] = "Banque de guilde",
    ["Search an item:"] = "Chercher un objet :",
    ["Bank rank:"] = "Rang banque :",
    ["Auto (bank / banque)"] = "Auto (bank / banque)",
    ["Item"] = "Objet",
    ["Bank character"] = "Perso banque",
    ["Bags"] = "Sacs",
    ["Bank"] = "Banque",
    ["Mail"] = "Courrier",
    ["Total"] = "Total",
    ["Seen"] = "Vu",
    ["No bank character on this account: log in once on your bank characters (they must be at the bank rank)."] =
        "Aucun perso banque sur ce compte : connecte-toi une fois sur tes persos banque (ils doivent être au rang banque).",
    ["Bank characters: %s"] = "Persos banque : %s",
    ["Bags are read at login, the bank and the mailbox when you open them on each bank character."] =
        "Les sacs sont lus à la connexion, la banque et le courrier quand tu les ouvres sur chaque perso banque.",
})
local L = W.L

local db

W.OnReady(function()
    db = W.DB("guildBank", { bankRank = "" })
    db.stock, db.requests = nil, nil -- synced data of an earlier test version
end)

local function IsBankRank(rank)
    if not rank then return false end
    if db.bankRank ~= "" then return rank == db.bankRank end
    local r = rank:lower()
    return r:find("bank", 1, true) ~= nil or r:find("banque", 1, true) ~= nil
end

-- my characters in this guild whose guild rank is the bank rank
local function BankChars()
    local out, guild = {}, GetGuildInfo and GetGuildInfo("player")
    if not guild or not W.AccountChars then return out end
    for _, c in pairs(W.AccountChars()) do
        local g = c.guild == guild and c.full and W.GuildMember(c.full)
        if g and IsBankRank(g.rank) then out[#out + 1] = c end
    end
    table.sort(out, function(a, b) return a.full < b.full end)
    return out
end

local function Gold(copper)
    return math.floor((copper or 0) / 10000) .. "|cffffd700g|r"
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
local UI = {}

local function Refresh()
    if not UI.stock or not UI.stock:IsVisible() then return end
    local search = (UI.search:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local wantId = W.ItemID(search)
    local query = search ~= "" and not wantId and search:lower() or nil
    local rows, banks = {}, {}
    for _, c in ipairs(BankChars()) do
        banks[#banks + 1] = W.ColorName(c.full, c.class) .. " (" .. Gold(c.money) .. ")"
        local ids = {}
        for _, where in ipairs({ "bags", "bank", "mail" }) do
            for id in pairs(type(c[where]) == "table" and c[where] or {}) do ids[id] = true end
        end
        for id in pairs(ids) do
            local name = W.GetItemInfo(id)
            if (wantId and id == wantId) or (query and name and name:lower():find(query, 1, true)) or (not wantId and not query) then
                local b, k, m = (c.bags or {})[id] or 0, (c.bank or {})[id] or 0, (c.mail or {})[id] or 0
                rows[#rows + 1] = { id = id, sortName = name or "~", who = c.full, cells = { W.ItemLink("item:" .. id),
                    W.ColorName(c.full, c.class), b > 0 and b or "", k > 0 and k or "", m > 0 and m or "", b + k + m, W.Ago(c.seen) } }
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.sortName ~= b.sortName then return a.sortName < b.sortName end
        return a.who < b.who
    end)
    while #rows > 500 do table.remove(rows) end
    UI.stock:SetData(rows)
    local text = #banks > 0 and string.format(L("Bank characters: %s"), table.concat(banks, ", "))
        or L("No bank character on this account: log in once on your bank characters (they must be at the bank rank).")
    UI.banks:SetText(text .. (W.IsOff("Alts") and ("   |cffffcc33" .. L("Alts is switched off: the bags and money shown are not updated.") .. "|r") or ""))
end

-- item names arrive from the server a moment after they are asked: one refresh once they settle
local itemPending = false
W.On("GET_ITEM_INFO_RECEIVED", function(_, success)
    if success == false or itemPending or not W.IsShown("GuildBank") then return end
    itemPending = true
    W.After(0.5, function() itemPending = false; Refresh() end)
end)

W.RegisterModule("GuildBank", "Guild bank", function(p)
    W.Title(p, L("Guild bank"))
    local lbl = W.Label(p, L("Search an item:"), "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT", 14, -44)
    UI.search = W.EditBox(p, 220, 200)
    UI.search:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
    UI.search:SetScript("OnTextChanged", W.Debounce(0.25, function() Refresh() end))
    W.LinkTarget(UI.search)
    local rl = W.Label(p, L("Bank rank:"), "GameFontHighlightSmall")
    rl:SetPoint("LEFT", UI.search, "RIGHT", 16, 0)
    local rankValues = {}
    local rankCycle = W.Cycle(p, 170, rankValues, function() return db.bankRank end, function(v) db.bankRank = v; Refresh() end)
    rankCycle:SetPoint("LEFT", rl, "RIGHT", 8, 0)
    UI.banks = W.Label(p, "", "GameFontHighlightSmall")
    UI.banks:SetPoint("TOPLEFT", 14, -70)
    UI.banks:SetWidth(800)
    UI.banks:SetJustifyH("LEFT")
    UI.banks:SetWordWrap(false)
    UI.stock = W.Table(p, { { L("Item"), 280 }, { L("Bank character"), 200 }, { L("Bags"), 60, "CENTER" }, { L("Bank"), 60, "CENTER" },
        { L("Mail"), 60, "CENTER" }, { L("Total"), 60, "CENTER" }, { L("Seen"), 50, "CENTER" } }, 420)
    UI.stock:SetPoint("TOPLEFT", 10, -90)
    UI.stock.onEnter = function(d, row)
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. d.id)
        GameTooltip:Show()
    end
    local hint = W.Label(p, L("Bags are read at login, the bank and the mailbox when you open them on each bank character."), "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", 14, 8)
    UI.syncRanks = function()
        wipe(rankValues)
        rankValues[1] = { "", L("Auto (bank / banque)") }
        local seen, ranks = {}, {}
        for _, m in ipairs(W.GuildMembers()) do
            if m.rank and not seen[m.rank] then seen[m.rank] = true; ranks[#ranks + 1] = m end
        end
        table.sort(ranks, function(a, b) return (a.rankIndex or 0) < (b.rankIndex or 0) end)
        for _, m in ipairs(ranks) do rankValues[#rankValues + 1] = { m.rank, m.rank } end
        rankCycle.Sync()
        Refresh()
    end
    p:SetScript("OnShow", function() W.RequestGuildRoster(); UI.syncRanks() end)
end)

-- opened before the roster was known: the ranks and bank characters come with it
W.On("GUILD_ROSTER_UPDATE", W.Coalesce(1, function()
    if UI.syncRanks and W.IsShown("GuildBank") then UI.syncRanks() end
end))

W.slash.bank = function() W.Toggle("GuildBank") end
