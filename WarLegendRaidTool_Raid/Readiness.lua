-- WarLegend RaidTool - Raider Readiness
-- Officers write the requirements (one per line), "Check the raid" sends them to the group: every
-- WarLegend client checks its own character and answers the requester, who gets a table of who is
-- not ready and why. Raiders also see their own status, and get a chat line listing what they miss.
-- Nothing runs between checks.
--
-- Requirement lines:   type  values  [= label]
--   level 60                     character level
--   quest 7848                   quest done (attunement); several IDs = any of them: quest 9121/9122/9123
--   item 16309 1                 at least N of an item (bags + bank)
--   rep 749 5                    reputation at least: 4 neutral, 5 friendly, 6 honored, 7 revered, 8 exalted
--   resist fire 150              total resistance: fire, nature, frost, shadow, arcane
--   enchants                     every enchantable slot enchanted
--   gold 50                      at least N gold
--   free 249                     not saved to this instance (map ID: 8th value of /dump GetInstanceInfo() inside it)
-- WoW: Forever raids at launch (Dec 9th 2026, wowhead.com/forever): Hyjal Summit (20), Barrow Deeps (10),
-- Onyxia's Lair (40). Their attunements are not announced yet: the presets only hold what is known.
local W = WLRT
W.AddFR({
    ["Raider Readiness"] = "Préparation",
    ["Requirements (one per line):"] = "Prérequis (un par ligne) :",
    ["My status"] = "Mon statut",
    ["Check the raid"] = "Vérifier le raid",
    ["Asked %d player(s), answers arrive in a few seconds."] = "Demandé à %d joueur(s), les réponses arrivent en quelques secondes.",
    ["%d/%d ready, %d without the addon"] = "%d/%d prêts, %d sans l'addon",
    ["You must be in a group."] = "Tu dois être en groupe.",
    ["You must be leader or assistant."] = "Tu dois être chef ou assistant.",
    ["Wait a few seconds before checking again."] = "Attends quelques secondes avant de vérifier à nouveau.",
    ["Readiness check from %s: you are missing %s"] = "Vérification de %s : il te manque %s",
    ["Readiness check from %s: you are ready."] = "Vérification de %s : tu es prêt.",
    ["Level %d"] = "Niveau %d",
    ["Quest %s"] = "Quête %s",
    ["Enchants"] = "Enchantements",
    ["%d gold"] = "%d po",
    ["Not saved: %s"] = "Pas verrouillé : %s",
    ["%s resistance %d"] = "Résistance %s %d",
    ["%d missing"] = "%d manquant(s)",
    ["saved"] = "verrouillé",
    ["Unknown line"] = "Ligne inconnue",
    ["Presets (examples, edit them):"] = "Modèles (exemples, à adapter) :",
    ["level 60 | quest ID (or ID/ID) | item ID count | rep factionID 4-8 | resist fire|nature|frost|shadow|arcane N | enchants | gold N | free instanceID   (= label at the end of a line)"] =
        "level 60 | quest ID (ou ID/ID) | item ID nombre | rep factionID 4-8 | resist fire|nature|frost|shadow|arcane N | enchants | gold N | free instanceID   (= libellé en fin de ligne)",
    ["Player"] = "Joueur",
    ["Answer checks from: guild leaders"] = "Répondre aux vérifs : chefs de ma guilde",
    ["Answer checks from: any group leader"] = "Répondre aux vérifs : tout chef de groupe",
    ["Answer checks from: nobody"] = "Répondre aux vérifs : personne",
    ["Gold and item counts are never sent: only OK or missing."] =
        "L'or et le nombre d'objets ne sont jamais envoyés : seulement OK ou manquant.",
})
local L = W.L

local PREFIX_ASK, PREFIX_ANS = "WLRT_RDYQ", "WLRT_RDYA"
local MAX_REQ = 8
local SCHOOLS = { fire = 2, nature = 3, frost = 4, shadow = 5, arcane = 6 }
local ENCHANT_SLOTS = { 5, 8, 9, 10, 15, 16, 17 } -- same as Raid Inspect (no head / shoulders / legs)

local db
local UI = {}
local results, asked, askedAt = {}, {}, 0 -- name -> { {ok, value}, ... } for the last check I started
local askId -- id of my last check: answers must carry it


---------------------------------------------------------------------------
-- Requirements
---------------------------------------------------------------------------
local function ParseLine(line)
    -- the list can come from another player: a long line is skipped and "=" found as plain text, no pattern
    -- with a repeated class before a literal (a line of spaces made it cubic: one ask froze the raid)
    if #line > 200 then return nil end
    local body, label = line, nil
    local eq = line:find("=", 1, true)
    if eq then body, label = line:sub(1, eq - 1), line:sub(eq + 1):match("^%s*(.-)%s*$") end
    body = body:match("^%s*(.-)%s*$")
    if body == "" or body:sub(1, 2) == "--" then return nil end
    local words = {}
    for w in body:gmatch("%S+") do words[#words + 1] = w:lower() end
    local r = { kind = words[1], label = (label and label ~= "") and label or nil }
    -- the list can come from another player: ids and amounts are finite and bounded before any game call
    local ID, N = 9999999, 99999999
    if r.kind == "level" or r.kind == "gold" then
        r.n = W.Finite(words[2], 0, N) or 0
    elseif r.kind == "quest" then
        r.ids = {}
        for id in (words[2] or ""):gmatch("%d+") do
            if #r.ids < 10 then r.ids[#r.ids + 1] = W.Int(id, 1, ID) end
        end
    elseif r.kind == "item" then
        r.id, r.n = W.Int(words[2], 1, ID), W.Int(words[3], 0, N) or 1
    elseif r.kind == "rep" then
        r.id, r.n = W.Int(words[2], 1, ID), W.Int(words[3], 0, 8) or 5
    elseif r.kind == "resist" then
        r.school, r.n = SCHOOLS[words[2] or ""], W.Finite(words[3], 0, N) or 0
    elseif r.kind == "free" then
        r.id = W.Int(words[2], 1, ID)
    elseif r.kind ~= "enchants" then
        r.kind = "unknown"
    end
    return r
end

local function Parse(text)
    local list = {}
    for line in ((text or "") .. "\n"):gmatch("(.-)\n") do
        local r = ParseLine(line)
        if r and #list < MAX_REQ then list[#list + 1] = r end
        if #list >= MAX_REQ then break end
    end
    return list
end

local function QuestDone(id)
    local f = (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) or IsQuestFlaggedCompleted
    return f and f(id) and true or false
end

local function Standing(id)
    if C_Reputation and C_Reputation.GetFactionDataByID then
        local d = C_Reputation.GetFactionDataByID(id)
        if d then return W.Safe(d.reaction), W.Safe(d.name) end
    end
    if GetFactionInfoByID then
        local name, _, standing = GetFactionInfoByID(id)
        return W.Safe(standing), W.Safe(name)
    end
end

local function StandingName(n) return _G["FACTION_STANDING_LABEL" .. tostring(n)] or tostring(n) end
local function SchoolName(i) return _G["SPELL_SCHOOL" .. i .. "_CAP"] or tostring(i) end
local function ZoneName(id)
    local z = GetRealZoneText and W.Safe(GetRealZoneText(id))
    return (z and z ~= "") and z or ("#" .. tostring(id))
end

local function SavedTo(instanceID)
    if not (GetNumSavedInstances and GetSavedInstanceInfo) then return nil end
    local zone = ZoneName(instanceID)
    for i = 1, GetNumSavedInstances() do
        local name, _, reset, _, locked, _, _, _, _, _, _, _, _, id = GetSavedInstanceInfo(i)
        name, reset, locked, id = W.Safe(name), W.Safe(reset), W.Safe(locked), W.Safe(id)
        if locked and reset and reset > 0 and (id == instanceID or name == zone) then return true end
    end
    return false
end

local function MissingEnchants()
    local missing = 0
    local nf = _G.NaowhForever
    local naowhEnchants = nf and nf.BiS and nf.BiS.Enchants
    for _, slot in ipairs(ENCHANT_SLOTS) do
        local link = W.Safe(GetInventoryItemLink("player", slot))
        if link then
            local can, current
            if naowhEnchants and naowhEnchants.Enchantable then -- same rule as Raid Inspect
                local ok, c, cur = pcall(naowhEnchants.Enchantable, link)
                if ok then can, current = c, cur end
            end
            if can == nil then
                local loc = W.GetItemInfoInstant and select(4, W.GetItemInfoInstant(link))
                can = not (slot == 17 and (loc == "INVTYPE_HOLDABLE" or loc == nil))
                current = tonumber(link:match("item:%d+:(%d*)") or "") or 0
            end
            if can and not (current and current > 0) then missing = missing + 1 end
        end
    end
    return missing
end

-- Readable name of a requirement
local function Label(r)
    if r.label then return r.label end
    if r.kind == "level" then return string.format(L("Level %d"), r.n) end
    if r.kind == "gold" then return string.format(L("%d gold"), r.n) end
    if r.kind == "enchants" then return L("Enchants") end
    if r.kind == "quest" then
        local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and r.ids[1] and C_QuestLog.GetTitleForQuestID(r.ids[1])
        return title or string.format(L("Quest %s"), table.concat(r.ids, "/"))
    end
    if r.kind == "item" then
        local name = r.id and W.GetItemInfo(r.id)
        return (name or ("item:" .. tostring(r.id))) .. (r.n > 1 and (" x" .. r.n) or "")
    end
    if r.kind == "rep" then
        local _, name = Standing(r.id or 0)
        return (name or ("#" .. tostring(r.id))) .. " " .. StandingName(r.n)
    end
    if r.kind == "resist" then return string.format(L("%s resistance %d"), SchoolName(r.school or 0), r.n) end
    if r.kind == "free" then return string.format(L("Not saved: %s"), ZoneName(r.id)) end
    return L("Unknown line")
end

-- ok = true / false / nil (cannot tell), value = short text
local function Evaluate(r)
    if r.kind == "level" then
        local lvl = W.Safe(UnitLevel("player")) or 0
        return lvl >= r.n, tostring(lvl)
    elseif r.kind == "gold" then
        local g = math.floor((W.Safe(GetMoney()) or 0) / 10000)
        return g >= r.n, g .. "g"
    elseif r.kind == "quest" then
        for _, id in ipairs(r.ids) do if QuestDone(id) then return true, "" end end
        return false, ""
    elseif r.kind == "item" then
        if not r.id then return nil, "" end
        local n = W.Safe((C_Item and C_Item.GetItemCount and C_Item.GetItemCount(r.id, true)) or (GetItemCount and GetItemCount(r.id, true))) or 0
        return n >= r.n, tostring(n)
    elseif r.kind == "rep" then
        local standing = r.id and Standing(r.id)
        if not standing then return false, "-" end
        return standing >= r.n, StandingName(standing)
    elseif r.kind == "resist" then
        if not r.school then return nil, "" end
        local _, total = UnitResistance("player", r.school)
        total = W.Safe(total) or 0
        return total >= r.n, tostring(total)
    elseif r.kind == "enchants" then
        local m = MissingEnchants()
        return m == 0, m > 0 and string.format(L("%d missing"), m) or ""
    elseif r.kind == "free" then
        local saved = r.id and SavedTo(r.id)
        if saved == nil then return nil, "" end
        return not saved, saved and L("saved") or ""
    end
    return nil, ""
end

local function Clean(s) return (tostring(s or ""):gsub("[;,%^|]", "")) end

---------------------------------------------------------------------------
-- Checking the raid
---------------------------------------------------------------------------
local function GroupNames()
    local out = {}
    for _, u in ipairs(W.GroupUnits()) do
        local key, n = W.UnitKey(u), W.UnitDisplayName(u)
        if key and n then out[#out + 1] = { key = key, name = n, class = W.UnitClassToken(u) } end
    end
    return out
end

local function RefreshTable()
    if not UI.table or not UI.table:IsVisible() then return end
    local reqs = Parse(db.text)
    for i = 1, MAX_REQ do
        local h = UI.table.heads[i + 1]
        if h then h:SetText(reqs[i] and Label(reqs[i]) or "") end
    end
    local rows, ready, noAddon, total = {}, 0, 0, 0
    for _, m in ipairs(GroupNames()) do
        total = total + 1
        local res = results[m.key]
        local cells = { W.ColorName(m.name, m.class) }
        local allOk = res ~= nil
        for i = 1, #reqs do
            local r = res and res[i]
            if not res then
                cells[i + 1] = "|cff999999?|r"
            elseif r and r[1] == "1" then
                cells[i + 1] = "|cffbbbbbbOK|r" .. (r[2] ~= "" and (" |cff999999" .. r[2] .. "|r") or "")
            elseif r and r[1] == "0" then
                allOk = false
                cells[i + 1] = "|cffff4444X|r" .. (r[2] ~= "" and (" " .. r[2]) or "")
            else
                cells[i + 1] = "|cff999999-|r"
            end
        end
        if not res then noAddon = noAddon + 1 elseif allOk then ready = ready + 1 end
        rows[#rows + 1] = { cells = cells }
    end
    UI.table:SetData(rows)
    if askedAt > 0 then UI.status:SetText(string.format(L("%d/%d ready, %d without the addon"), ready, total, noAddon)) end
end

-- private = answering someone else: gold and item counts are sent as OK / missing only
local PRIVATE = { gold = true, item = true }
local function MyResults(reqs, private)
    local out = {}
    for i, r in ipairs(reqs) do
        local ok, value = Evaluate(r)
        if private and PRIVATE[r.kind] then value = "" end
        out[i] = { ok == true and "1" or (ok == false and "0" or "?"), Clean(value) }
    end
    return out
end

local function RefreshMine()
    if not UI.mine then return end
    local reqs = Parse(db.text)
    for i = 1, MAX_REQ do
        local fs = UI.mine[i]
        local r = reqs[i]
        if r then
            local ok, value = Evaluate(r)
            local mark = ok == true and "|cffbbbbbbOK|r" or (ok == false and "|cffff4444X|r" or "|cff999999?|r")
            fs:SetText(mark .. "  " .. Label(r) .. (value ~= "" and ("  |cff999999(" .. value .. ")|r") or ""))
        else
            fs:SetText("")
        end
    end
end

local lastCheck = 0
local function CheckRaid()
    if not W.InGroup() then W.Print(L("You must be in a group.")); return end
    if not W.CanLead() then W.Print(L("You must be leader or assistant.")); return end
    if GetTime() - lastCheck < 5 then W.Print(L("Wait a few seconds before checking again.")); return end
    lastCheck = GetTime()
    if RequestRaidInfo then RequestRaidInfo() end
    wipe(results)
    askedAt = GetTime()
    askId = tostring(math.random(100000, 999999))
    results[W.UnitKey("player") or "?"] = MyResults(Parse(db.text))
    W.SendLong(PREFIX_ASK, askId .. "\n" .. (db.text or ""))
    UI.status:SetText(string.format(L("Asked %d player(s), answers arrive in a few seconds."), math.max(0, #GroupNames() - 1))) -- not me
    RefreshTable()
end

-- Who may check me: "guild" = a leader / assistant of my group who is in my guild (default),
-- "group" = any leader / assistant of my group, "off" = nobody
local function MayAsk(from, full, channel)
    local who = db.answerFrom
    if who == "off" or not W.IsGroupLead(full or from, channel) then return false end
    return who == "group" or W.GuildMember(full or from) ~= nil
end

-- A leader asks: check my character against their list, answer them, tell me what I miss.
-- One answer every 5 s at most: a flood of checks ("gold 100", "gold 200"...) must not read my gold step by step.
local lastAnswered = -1000
W.OnAddonLong(PREFIX_ASK, function(text, from, channel, full)
    if W.IsMe(full or from) or not MayAsk(from, full, channel) then return end
    if GetTime() - lastAnswered < 5 then return end
    lastAnswered = GetTime()
    local id, list = text:match("^(%d+)\n(.*)$")
    if not id or #list > 2000 then return end -- the asker's box holds 2000 letters
    -- "free": my saved instances are asked for first, the answer is read once they had time to arrive
    if RequestRaidInfo then RequestRaidInfo() end
    W.After(1 + math.random() * 2, function()
        local reqs = Parse(list)
        local res = MyResults(reqs, true)
        local parts, missing = {}, {}
        for i, r in ipairs(res) do
            parts[i] = r[1] .. "," .. r[2]
            if r[1] == "0" then missing[#missing + 1] = W.Plain(Label(reqs[i]), 60) end -- the label comes from the asker
        end
        W.Queue(PREFIX_ANS, id .. "#" .. table.concat(parts, ";"), "WHISPER", full or from)
        if #missing > 0 then
            W.Print(string.format(L("Readiness check from %s: you are missing %s"), W.Sender(from, full), table.concat(missing, ", ")))
        else
            W.Print(string.format(L("Readiness check from %s: you are ready."), W.Sender(from, full)))
        end
    end)
end, 2100) -- id + the 2000-letter box

W.OnAddon(PREFIX_ANS, function(msg, from, _, full)
    if askedAt == 0 or GetTime() - askedAt > 120 then return end -- only answers to my own recent check
    local id, body = msg:match("^(%d+)#(.*)$")
    if id ~= askId or not W.UnitByName(full or from) then return end -- answers to this very check, from my group
    local res = {}
    for s, v in (body .. ";"):gmatch("([01%?]),([^;]*);") do
        if #res >= MAX_REQ then break end
        res[#res + 1] = { s, W.Plain(v, 20) }
    end
    results[W.UnitKey(W.UnitByName(full or from))] = res -- the answering unit's full identity
    RefreshTable()
end)

---------------------------------------------------------------------------
-- Presets: the WoW: Forever raids. Onyxia keeps the Classic attunement (quest 6502 / 6602 and the
-- Drakefire Amulet 16309 still exist on wowhead.com/forever) until Blizzard says otherwise.
---------------------------------------------------------------------------
local function Presets()
    local horde = UnitFactionGroup and UnitFactionGroup("player") == "Horde"
    return {
        { "Onyxia", "level 60\nquest " .. (horde and "6602" or "6502") .. " = Onyxia attunement\nitem 16309 1 = Drakefire Amulet\nenchants\ngold 50" },
        { "Hyjal", "level 60\nenchants\ngold 50" },
        { "Barrow Deeps", "level 60\nenchants\ngold 50" },
    }
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
W.OnReady(function()
    db = W.DB("readiness", { text = "level 60\nenchants\ngold 50", answerFrom = "guild" })
end)

W.RegisterModule("Readiness", "Raider Readiness", function(p)
    W.Title(p, L("Raider Readiness"))
    W.Label(p, L("Requirements (one per line):"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 16, -40)
    local bg, box = W.MultiEdit(p, 380, 150, 2000)
    bg:SetPoint("TOPLEFT", 16, -56)
    box:SetScript("OnShow", function(self) self:SetText(db.text or "") end)
    box:SetScript("OnEditFocusLost", function(self) db.text = self:GetText(); RefreshMine(); RefreshTable() end)

    W.Label(p, L("Presets (examples, edit them):"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 16, -214)
    local x = 16
    for _, preset in ipairs(Presets()) do
        local name = preset[1]
        W.Button(p, name, 104, 20, function()
            for _, pr in ipairs(Presets()) do
                if pr[1] == name then db.text = pr[2] end
            end
            box:SetText(db.text)
            RefreshMine()
            RefreshTable()
        end):SetPoint("TOPLEFT", x, -230)
        x = x + 108
    end
    local help = W.Label(p, L("level 60 | quest ID (or ID/ID) | item ID count | rep factionID 4-8 | resist fire|nature|frost|shadow|arcane N | enchants | gold N | free instanceID   (= label at the end of a line)"),
        "GameFontDisableSmall")
    help:SetPoint("TOPLEFT", 16, -256)
    help:SetWidth(380)

    local mineHead = W.Label(p, L("My status"), "GameFontNormal")
    mineHead:SetPoint("TOPLEFT", 420, -40)
    UI.mine = {}
    for i = 1, MAX_REQ do
        local fs = W.Label(p, "", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", 420, -60 - (i - 1) * 18)
        fs:SetWidth(380)
        fs:SetWordWrap(false)
        UI.mine[i] = fs
    end

    W.Button(p, L("Check the raid"), 160, 24, CheckRaid):SetPoint("TOPLEFT", 16, -300)
    W.Cycle(p, 300, {
        { "guild", L("Answer checks from: guild leaders") },
        { "group", L("Answer checks from: any group leader") },
        { "off", L("Answer checks from: nobody") },
    }, function() return db.answerFrom end, function(v) db.answerFrom = v end,
        { L("Gold and item counts are never sent: only OK or missing.") }):SetPoint("TOPLEFT", 420, -214)
    UI.status = W.Label(p, "", "GameFontHighlightSmall")
    UI.status:SetPoint("TOPLEFT", 186, -306)
    local cols = { { L("Player"), 110 } }
    for i = 1, MAX_REQ do cols[#cols + 1] = { "", 76, "CENTER" } end
    UI.table = W.Table(p, cols, 250)
    UI.table:SetPoint("TOPLEFT", 10, -332)
    p:SetScript("OnShow", function() if RequestRaidInfo then RequestRaidInfo() end; RefreshMine(); RefreshTable() end)
end, function() RefreshMine(); RefreshTable() end)

W.On("UPDATE_INSTANCE_INFO", function() if W.IsShown("Readiness") then RefreshMine() end end)
