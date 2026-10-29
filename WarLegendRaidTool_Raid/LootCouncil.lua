-- WarLegend RaidTool - Loot Council (RCLootCouncil style, master loot)
-- The master looter starts a session with the boss items; every raider with the addon answers
-- (Need / Upgrade / Minor / Offspec / Greed / Pass + note, with their equipped items);
-- the council votes; the master looter awards (GiveMasterLoot) and everything goes in the loot log.
-- Also: loot log of every item looted in raid, soft-res (softres.it import + "!sr" whispers).
local W = WLRT
W.AddFR({
    ["click"] = "clic",
    ["Loot Council"] = "Loot Council",
    ["Need (BiS)"] = "Besoin (BiS)",
    ["Upgrade"] = "Amélioration",
    ["Minor upgrade"] = "Petite amélio.",
    ["Offspec"] = "Spé secondaire",
    ["Greed"] = "Cupidité",
    ["Pass"] = "Passer",
    ["Waiting..."] = "En attente...",
    ["Timeout"] = "Temps écoulé",
    ["Autopass"] = "Passe auto",
    ["No addon"] = "Pas d'addon",
    ["Session"] = "Session",
    ["History"] = "Historique",
    ["Soft-res"] = "Soft-res",
    ["Settings"] = "Réglages",
    ["Loot - choose"] = "Loot - choisis",
    ["Council voting"] = "Vote du conseil",
    ["Note"] = "Note",
    ["Name"] = "Nom",
    ["Rank"] = "Rang",
    ["Response"] = "Réponse",
    ["Gear"] = "Équipé",
    ["Diff"] = "Diff",
    ["Votes"] = "Votes",
    ["Vote"] = "Voter",
    ["Unvote"] = "Retirer",
    ["Award %s to %s?"] = "Donner %s à %s ?",
    ["This item is already awarded."] = "Cet objet est déjà attribué.",
    ["Loot session closed: the master looter left the group."] = "Session de loot fermée : le maître du butin a quitté le groupe.",
    ["Loot session restored after the reload."] = "Session de loot restaurée après le rechargement.",
    ["Award"] = "Donner",
    ["Awarded to "] = "Donné à ",
    ["End session"] = "Fin de session",
    ["Open voting window"] = "Ouvrir la fenêtre de vote",
    ["Test session (your gear)"] = "Session test (ton équipement)",
    ["Add item"] = "Ajouter l'objet",
    ["Start session"] = "Lancer la session",
    ["Clear list"] = "Vider la liste",
    ["Items for the next session (shift-click an item in the box):"] = "Objets de la prochaine session (shift-clic un objet dans la case) :",
    ["No session running."] = "Aucune session en cours.",
    ["Session by %s: %d item(s)."] = "Session de %s : %d objet(s).",
    ["You must be master looter or raid leader/assist."] = "Il faut être responsable du butin ou chef ou assistant du raid.",
    ["Loot session started (%d items)."] = "Session de loot lancée (%d objets).",
    ["Loot session ended."] = "Session de loot terminée.",
    ["%d item(s) won by %s added to the trade."] = "%d objet(s) gagné(s) par %s ajouté(s) à l'échange.",
    ["Trade %s to %s (item not in the loot window)."] = "Échange %s à %s (objet absent de la fenêtre de loot).",
    ["Could not give %s to %s (out of range or not eligible?)."] = "Impossible de donner %s à %s (hors de portée ou pas éligible ?).",
    ["Autopassed %s (cannot use)."] = "Passé auto %s (inutilisable).",
    ["Loot: %s -> %s (%s)"] = "Loot : %s -> %s (%s)",
    ["Boss loot"] = "Loot du boss",
    ["Start a loot session with these items?"] = "Lancer une session de loot avec ces objets ?",
    ["Enable the loot council"] = "Activer le loot council",
    ["Ask to start a session when I open a boss as master looter"] = "Proposer une session quand j'ouvre un boss en responsable du butin",
    ["Announce awards in raid chat"] = "Annoncer les attributions dans le canal raid",
    ["Autopass items my class cannot use"] = "Passer auto les objets inutilisables par ma classe",
    ["Minimum quality:"] = "Qualité minimum :",
    ["Answer time:"] = "Temps de réponse :",
    ["Council: guild ranks up to"] = "Conseil : rangs de guilde jusqu'à",
    ["Extra council members (names, comma):"] = "Membres du conseil en plus (noms, virgules) :",
    ["Loot log: record every item looted in raid"] = "Loot log : enregistrer chaque objet looté en raid",
    ["Filter:"] = "Filtre :",
    ["Date"] = "Date",
    ["Item"] = "Objet",
    ["Winner"] = "Gagnant",
    ["Zone"] = "Zone",
    ["Source"] = "Source",
    ["Export CSV"] = "Exporter CSV",
    ["Clear history?"] = "Effacer l'historique ?",
    ["Clear"] = "Effacer",
    ["Delete this entry?"] = "Supprimer cette ligne ?",
    ["Players"] = "Joueurs",
    ["Import (softres.it CSV)"] = "Importer (CSV softres.it)",
    ["Paste the softres.it CSV export (or lines \"Name,ItemID\")."] = "Colle l'export CSV de softres.it (ou des lignes \"Nom,IDobjet\").",
    ["%d soft-res imported."] = "%d soft-res importés.",
    ["Nothing found to import."] = "Rien à importer.",
    ["Accept \"!sr [item]\" whispers"] = "Accepter les chuchotements \"!sr [objet]\"",
    ["Max soft-res per player:"] = "Soft-res max par joueur :",
    ["Clear all soft-res?"] = "Effacer tous les soft-res ?",
    ["Announce"] = "Annoncer",
    ["Soft-res saved: %s (%d/%d)."] = "Soft-res enregistré : %s (%d/%d).",
    ["You already have %d soft-res: %s"] = "Tu as déjà %d soft-res : %s",
    ["Your soft-res: %s"] = "Tes soft-res : %s",
    ["No soft-res. Whisper \"!sr [item link]\"."] = "Aucun soft-res. Chuchote \"!sr [lien de l'objet]\".",
    ["Unknown item. Whisper \"!sr\" + the item link or ID."] = "Objet inconnu. Chuchote \"!sr\" + le lien ou l'ID de l'objet.",
    ["%s soft-reserved %s."] = "%s a soft-res %s.",
    ["Council"] = "Conseil",
    ["Looted"] = "Looté",
    ["Close"] = "Fermer",
    ["Soft-res: "] = "Soft-res : ",
    ["Council members: "] = "Membres du conseil : ",
    ["Awards"] = "Attributions",
    ["Loots"] = "Loots",
    ["Loots: items received in guild raids, last 30 days."] = "Loots : objets reçus en raid guilde, 30 derniers jours.",
    ["No loot given yet."] = "Aucun objet attribué pour l'instant.",
})
local L = W.L

local LC = {}
W.LootCouncil = LC
local PREFIX = "WLRT_LC"
local db
local hist -- loot history, newest first

local RESP = {
    { key = "need", text = L("Need (BiS)"), color = "33ff66" },
    { key = "up", text = L("Upgrade"), color = "ff9933" },
    { key = "minor", text = L("Minor upgrade"), color = "ffff55" },
    { key = "os", text = L("Offspec"), color = "bb77ff" },
    { key = "greed", text = L("Greed"), color = "9999ff" },
    { key = "pass", text = L("Pass"), color = "888888" },
}
local SPECIAL = {
    wait = { text = L("Waiting..."), color = "777777", order = 20 },
    timeout = { text = L("Timeout"), color = "aa5555", order = 30 },
    autopass = { text = L("Autopass"), color = "666666", order = 40 },
    noaddon = { text = L("No addon"), color = "555555", order = 50 },
}
W.TranslateField(RESP, "text")
W.TranslateField(SPECIAL, "text")
local RESP_BY = {}
for i, r in ipairs(RESP) do r.order = i; RESP_BY[r.key] = r end
for k, r in pairs(SPECIAL) do r.key = k; RESP_BY[k] = r end

local function RespText(key)
    local r = RESP_BY[key] or SPECIAL.wait
    return "|cff" .. r.color .. r.text .. "|r"
end

W.OnReady(function()
    db = W.DB("loot", {
        enabled = true, autoStart = true, announce = true, autopass = true, minQuality = 4,
        timeout = 60, councilRank = 1, councilExtra = "", logLoot = true,
        srWhisper = false, srMax = 1,
    })
    -- the loot history has its own key (WarLegendRaidToolDB.lootHistory), apart from the module options
    if type(W.db.lootHistory) ~= "table" then
        W.db.lootHistory = type(db.history) == "table" and db.history or {} -- moved once from loot.history
    end
    db.history = nil
    hist = W.db.lootHistory
    if type(db.sr) ~= "table" then db.sr = {} end
    -- "!sr" whispers are for whoever collects the soft-res: off by default now (every raider answered them and kept a
    -- list); switched off once here, unless this player already holds a list
    if not db.srChecked then
        db.srChecked = true
        if next(db.sr) == nil then db.srWhisper = false end
    end
    if type(db.pending) ~= "table" then db.pending = {} end
end)

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function Me() return W.Safe(UnitName("player")) or "?" end

function LC.IsML()
    local method, partyIdx, raidIdx
    if C_PartyInfo and C_PartyInfo.GetLootMethod then
        method, partyIdx, raidIdx = C_PartyInfo.GetLootMethod()
    elseif GetLootMethod then
        method, partyIdx, raidIdx = GetLootMethod()
    end
    local ML = Enum and Enum.LootMethod and (Enum.LootMethod.Masterlooter or Enum.LootMethod.MasterLooter) or 2
    if method ~= "master" and method ~= ML then return false end
    if raidIdx and raidIdx > 0 then return W.UnitIsMe("raid" .. raidIdx) end
    return partyIdx == 0
end

function LC.CanRun()
    return LC.IsML() or not W.InGroup() or W.IsLeader() or (W.InRaid() and W.CanLead())
end

-- Equipment slots for an equip location
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 },
    INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 },
    INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 }, INVTYPE_TABARD = { 19 },
}

local function EquipLoc(str)
    if not str or type(str) ~= "string" then return nil end
    local _, _, _, loc = W.GetItemInfoInstant(str)
    return loc
end

local function MyGear(str)
    local loc = EquipLoc(str)
    if not loc then return nil, nil end
    local slots = SLOTS[loc] or nil
    local g = {}
    if slots then
        for i, s in ipairs(slots) do g[i] = W.ItemString(GetInventoryItemLink("player", s)) end
    end
    return g[1], g[2]
end

-- What a class can equip (vanilla rules). classID 4 = armor, 2 = weapon.
local ALL = { WARRIOR = 1, PALADIN = 1, HUNTER = 1, ROGUE = 1, PRIEST = 1, SHAMAN = 1, MAGE = 1, WARLOCK = 1, DRUID = 1 }
local function Set(s) local t = {}; for c in s:gmatch("%u+") do t[c] = true end; return t end
local ARMOR = {
    [1] = ALL, [2] = Set("WARRIOR PALADIN HUNTER ROGUE SHAMAN DRUID"), [3] = Set("WARRIOR PALADIN HUNTER SHAMAN"),
    [4] = Set("WARRIOR PALADIN"), [6] = Set("WARRIOR PALADIN SHAMAN"), [7] = Set("PALADIN"), [8] = Set("DRUID"), [9] = Set("SHAMAN"),
}
local WEAPON = {
    [0] = Set("WARRIOR PALADIN HUNTER ROGUE SHAMAN"), [1] = Set("WARRIOR PALADIN HUNTER SHAMAN"),
    [2] = Set("WARRIOR HUNTER ROGUE"), [3] = Set("WARRIOR HUNTER ROGUE"),
    [4] = Set("WARRIOR PALADIN ROGUE PRIEST SHAMAN DRUID"), [5] = Set("WARRIOR PALADIN SHAMAN DRUID"),
    [6] = Set("WARRIOR PALADIN HUNTER"), [7] = Set("WARRIOR PALADIN HUNTER ROGUE MAGE WARLOCK"),
    [8] = Set("WARRIOR PALADIN HUNTER"), [10] = Set("WARRIOR HUNTER PRIEST SHAMAN MAGE WARLOCK DRUID"),
    [13] = Set("WARRIOR HUNTER ROGUE SHAMAN DRUID"), [15] = Set("WARRIOR HUNTER ROGUE PRIEST SHAMAN MAGE WARLOCK DRUID"),
    [16] = Set("WARRIOR HUNTER ROGUE"), [18] = Set("WARRIOR HUNTER ROGUE"), [19] = Set("PRIEST MAGE WARLOCK"),
}

-- "Classes: Rogue, Mage" line of the tooltip (tier tokens, class sets...): set of class tokens, nil if none or not loaded.
-- Read once per item id and kept (a tooltip is only parsed when the item has none yet).
local classNameToken, scanTip
local classLine = {} -- item id -> false (no class line) or set
local function ClassLine(str)
    local id = W.ItemID(str)
    if not id then return nil end
    local known = classLine[id]
    if known ~= nil then return known or nil end
    if not ITEM_CLASSES_ALLOWED then return nil end
    if not classNameToken then
        classNameToken = {}
        for _, names in ipairs({ LOCALIZED_CLASS_NAMES_MALE or {}, LOCALIZED_CLASS_NAMES_FEMALE or {} }) do
            for token, name in pairs(names) do classNameToken[name] = token end
        end
    end
    if not scanTip then scanTip = CreateFrame("GameTooltip", "WLRTLCScanTip", nil, "GameTooltipTemplate") end
    scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    local ok = pcall(scanTip.SetHyperlink, scanTip, "item:" .. id)
    local lines = ok and scanTip:NumLines() or 0
    if lines == 0 then scanTip:Hide(); return nil end -- item not loaded yet: not kept, asked again next time
    local pattern = "^" .. ITEM_CLASSES_ALLOWED:gsub("%%s", "(.+)") .. "$"
    local set
    for i = 1, lines do
        local fs = _G["WLRTLCScanTipTextLeft" .. i]
        local text = fs and W.Safe(fs:GetText())
        local list = type(text) == "string" and text:match(pattern)
        if list then
            set = {}
            for name in (list .. ", "):gmatch("(.-), ") do
                local token = classNameToken[name]
                if token then set[token] = true end
            end
            if not next(set) then set = nil end -- class names not understood: no restriction
            break
        end
    end
    scanTip:Hide()
    classLine[id] = set or false
    return set
end

function LC.CanUse(str, class)
    local restricted = ClassLine(str)
    if restricted and class and not restricted[class] then return false end
    local _, _, _, loc, _, classID, subID = W.GetItemInfoInstant(str)
    if not classID then return true end
    if loc == "INVTYPE_CLOAK" then return true end
    local t = (classID == 4 and ARMOR[subID]) or (classID == 2 and WEAPON[subID])
    if not t then return true end
    return t[class] and true or false
end

local function Ilvl(str) return str and W.ItemLevel(str) end

local function AvgIlvl()
    if not GetAverageItemLevel then return 0 end
    local _, equipped = GetAverageItemLevel()
    return math.floor((W.Safe(equipped) or 0) + 0.5)
end

local function ZoneName()
    local name = GetInstanceInfo and GetInstanceInfo()
    return name or (GetRealZoneText and GetRealZoneText()) or ""
end

-- Soft-res
function LC.SRFor(str)
    local id = W.ItemID(str)
    return id and db.sr[id] or nil
end

-- a soft-res name and a player: the same full name, or the same first name when one side has no surname /
-- realm (a softres.it import), so two raiders sharing a first name keep their own whispered soft-res
local function SRMatch(a, b)
    if not a or not b then return false end
    if a:lower() == b:lower() then return true end
    if W.HasFullPart(a) and W.HasFullPart(b) then return false end
    return W.BaseName(a):lower() == W.BaseName(b):lower()
end

-- a council / voter key (lowercase full name) as the group shows it, or the key itself
local function KeyName(key)
    for _, u in ipairs(W.GroupUnits()) do
        if W.UnitKey(u) == key then return W.UnitDisplayName(u) or key end
    end
    return W.Plain(key, 60) -- a name from the starter's message: never its colour / line codes
end

local function HasSR(str, name)
    local list = LC.SRFor(str)
    if not list then return false end
    for _, n in ipairs(list) do if SRMatch(n, name) then return true end end
    return false
end

---------------------------------------------------------------------------
-- Session state (same on every client)
---------------------------------------------------------------------------
local S -- { sid, ml, n, timeout, started, items = {}, council = {}, acks = {}, roster = {} }
local ended = {} -- [sid] = true: sessions closed here, never opened again by an old "S"
local CloseSession
local UI = {}

-- Identities: every candidate, council member and voter is keyed by its full identity
-- (W.UnitKey: "first surname" on Forever, "name-realm" elsewhere); c.name is only for display.
local function MyKey() return W.UnitKey("player") or "?" end

-- key of a message sender, taken from its unit so it matches the candidate lists
local function SenderKey(from, full)
    local u = W.UnitByName(full or from)
    return u and W.UnitKey(u), u
end

local function NewCandidates()
    local list = {}
    local units = W.GroupUnits()
    if #units == 0 then units = { "player" } end
    for _, u in ipairs(units) do
        local key, name = W.UnitKey(u), W.UnitDisplayName(u)
        if key and name then
            local g = W.GuildMember(W.UnitFullName(u))
            list[key] = { key = key, name = name, class = W.UnitClassToken(u), rank = g and g.rank or "",
                rankIndex = g and g.rankIndex or 99, resp = "wait", votes = {} }
        end
    end
    return list
end

-- a council name as the voters' key (W.UnitKey of the group unit): a name typed without the surname or
-- with another separator ("First-Surname", "first surname") still finds its player. Out of the group: W.Key.
local function CouncilKey(n)
    local u = W.UnitByName(n)
    return (u and W.UnitKey(u)) or W.Key(n)
end

local function IsCouncil(key)
    return S and S.council[key or MyKey()] or false
end

function LC.Session() return S end

-- a guild raid: at least half of the group is in the guild
local function GuildRaid()
    local n, g = 0, 0
    for _, u in ipairs(W.GroupUnits()) do
        n = n + 1
        local name = W.UnitFullName(u)
        if name and W.GuildMember(name) then g = g + 1 end
    end
    return n > 0 and g * 2 >= n
end

local function Record(entry)
    if entry.g == nil then entry.g = GuildRaid() end
    table.insert(hist, 1, entry)
    while #hist > 1000 do table.remove(hist) end
    if UI.history and UI.history:IsVisible() then LC.RefreshHistory() end
end

---------------------------------------------------------------------------
-- Messages
---------------------------------------------------------------------------
local function Send(...) W.Queue(PREFIX, W.Pack(...)) end
-- an award goes before the waiting messages: behind a resync whispered to 3 players it waited 16 s or more, and the
-- "Award" button came back meanwhile (a second click gave or owed the item twice)
local function SendFirst(...) W.Queue(PREFIX, W.Pack(...), nil, nil, true) end

-- council members as full identities (two players can share a first name)
local function CouncilList()
    local set, list = {}, {}
    local function add(n)
        n = W.FullName(W.SanitizeName(n or ""))
        if n and n ~= "" and not set[n:lower()] then set[n:lower()] = true; list[#list + 1] = n end
    end
    add(W.UnitFullName("player"))
    for _, u in ipairs(W.GroupUnits()) do
        local n = W.UnitFullName(u)
        local g = n and W.GuildMember(n)
        if g and g.rankIndex and g.rankIndex <= (db.councilRank or 1) then add(n) end
    end
    for _, n in ipairs(W.NameList(db.councilExtra)) do add(n) end
    return list
end

local SESSION_MAX = 30 -- the receivers refuse more (MAX_ITEMS): never announce a session they drop
W.AddFR({
    ["Only the first %d items are put in the session."] = "Seuls les %d premiers objets sont mis dans la session.",
    ["A loot session is still open: the new one replaces it for everyone (answers not given yet are lost)."] =
        "Une session de butin est encore ouverte : la nouvelle la remplace pour tout le monde (les réponses pas encore données sont perdues).",
    ["Start a test session?"] = "Lancer une session de test ?",
})

-- said in the question before a new session: one still open is replaced for everyone
local function OpenWarning()
    if not S then return "" end
    return "\n\n|cffff5555" .. L("A loot session is still open: the new one replaces it for everyone (answers not given yet are lost).") .. "|r"
end

function LC.StartSession(items, test)
    if not LC.CanRun() then W.Print(L("You must be master looter or raid leader/assist.")); return end
    if #items == 0 then return end
    if #items > SESSION_MAX then
        local kept = {}
        for i = 1, SESSION_MAX do kept[i] = items[i] end
        items = kept
        W.Print(string.format(L("Only the first %d items are put in the session."), SESSION_MAX))
    end
    local sid = tostring(time() % 100000) .. math.random(10, 99)
    Send("S", sid, #items, db.timeout, test and "t" or "")
    for i, str in ipairs(items) do Send("I", sid, i, str) end
    -- the council in several "C" messages: 15 "First Surname" names already pass the 255 bytes of one
    -- message (refused by the client, then nobody could vote); each one adds to the list
    local part = {}
    for _, n in ipairs(CouncilList()) do
        if #part > 0 and #table.concat(part, ",") + #n > 180 then Send("C", sid, table.concat(part, ",")); part = {} end
        part[#part + 1] = n
    end
    if #part > 0 then Send("C", sid, table.concat(part, ",")) end
    W.Print(string.format(L("Loot session started (%d items)."), #items))
    return true
end

function LC.EndSession()
    if S then Send("E", S.sid) end
end

local Receive = {}

-- Protocol safety: only the master looter or the group leader / an assistant may start a session,
-- then only that player (full "Name-Realm" name) drives it. Every value is bounded.
local MAX_ITEMS, MAX_COUNCIL, MAX_NOTE = 30, 40, 100

-- 40 answers (and as many notes, votes) arrive in a few seconds: the voting window is rebuilt once per 0.2 s
local RefreshVoteSoon = W.Coalesce(0.2, function() LC.RefreshVote() end)

local function MasterLooterUnit()
    local method, partyIdx, raidIdx
    if C_PartyInfo and C_PartyInfo.GetLootMethod then
        method, partyIdx, raidIdx = C_PartyInfo.GetLootMethod()
    elseif GetLootMethod then
        method, partyIdx, raidIdx = GetLootMethod()
    end
    local ML = Enum and Enum.LootMethod and (Enum.LootMethod.Masterlooter or Enum.LootMethod.MasterLooter) or 2
    if method ~= "master" and method ~= ML then return nil end
    if raidIdx and raidIdx > 0 then return W.RAID_UNITS[raidIdx] end
    if partyIdx == 0 then return "player" end
    return partyIdx and W.PARTY_UNITS[partyIdx]
end

local function SameName(a, b) return a and b and a:lower() == b:lower() end

-- the loot authority of the group: the master looter under master loot, else the group leader
local function LootAuthority(full)
    local u = full and W.UnitByName(full)
    if not u then return false end
    local ml = MasterLooterUnit()
    if ml then return W.SameUnit(u, ml) end
    return W.Safe(UnitIsGroupLeader(u)) == true
end

local function MayStart(full, channel)
    if not W.InGroup() then return channel == "LOCAL" end -- alone: our own test session, never a whisper
    if W.IsGroupLead(full) then return true end
    local u = MasterLooterUnit()
    return u and SameName(W.UnitFullName(u), full) or false
end

local function FromML(full)
    if not S or not full then return false end
    if SameName(S.mlFull, full) then return true end
    -- the two forms can differ (surname / realm in the name or not): compare the group units
    local a, b = W.UnitByName(S.mlFull), W.UnitByName(full)
    return W.SameUnit(a, b)
end

Receive.S = function(t, from, full, channel)
    if not db.enabled or not MayStart(full, channel) then return end
    -- a session driven by someone else is not reset by another leader (10 min: one whose end never came)
    if S and not SameName(S.mlFull, full) and GetTime() - S.started < 600 then return end
    -- the session I already have (a resync answer for someone else, a repeat): kept as it is
    if S and S.sid == t[2] then return end
    if t[2] and ended[t[2]] then return end -- a session that ended does not open again (old message)
    local n = W.Int(t[3]) or 0
    if n < 1 or n > MAX_ITEMS or not t[2] or #t[2] > 12 then return end
    local timeout = W.Finite(t[4], 10, 300) or 60
    -- the rows of the session it replaces must not stay clickable: the window opens again once the new items are here
    if S and UI.loot then UI.loot:Hide() end
    S = { sid = t[2], ml = from, mlFull = full, n = n, timeout = timeout, started = GetTime(),
        items = {}, council = {}, acks = {}, answered = {} }
    -- a test (Test button, or a session alone): its awards are shown but never saved in the loot log
    S.test = t[5] == "t" or not W.InGroup()
    S.cands = NewCandidates()
    if UI.vote then UI.vote.sel = 1 end -- the tab chosen in the last session may not exist in this one
    Send("K", S.sid)
    -- safety net: if the item list never completes, still mark the silent players after 30 s
    local sid = S.sid
    W.After(30, function() if S and S.sid == sid then LC.MarkNoAddon(sid) end end)
end

-- Players who never answered the "K" do not have the addon. Counted from the moment the item list
-- is complete (a long list, slowed by the send queue, must not mark everyone "no addon").
function LC.MarkNoAddon(sid)
    if not S or S.sid ~= sid or S.marked then return end
    S.marked = true
    for _, item in pairs(S.items) do
        for key, c in pairs(item.cands) do
            if c.resp == "wait" and not S.acks[key] then c.resp = "noaddon" end
        end
    end
    RefreshVoteSoon()
end

Receive.K = function(t, from, full)
    if not S or S.sid ~= t[2] then return end
    local key = SenderKey(from, full)
    if key then S.acks[key] = true end
end

local function NewItem(str)
    local item = { str = str, cands = {} }
    for key, c in pairs(S.cands) do
        item.cands[key] = { key = key, name = c.name, class = c.class, rank = c.rank, rankIndex = c.rankIndex, resp = "wait", votes = {} }
    end
    return item
end

Receive.I = function(t, from, full)
    if not S or S.sid ~= t[2] or not FromML(full) then return end
    local idx = tonumber(t[3])
    if not idx or idx < 1 or idx > S.n or idx ~= math.floor(idx) then return end
    if not t[4] or #t[4] > 120 or not t[4]:match("^item:[%-%d:]+$") then return end
    if S.items[idx] then return end -- sent once: a repeat must not wipe the answers, votes and winner
    S.items[idx] = NewItem(t[4])
    W.ItemLink(t[4]) -- asks the client to cache it
    local count = 0
    for _ in pairs(S.items) do count = count + 1 end
    if count >= S.n and not S.complete then
        S.complete = true
        LC.ShowLootFrame()
        local sid = S.sid
        W.After(8, function() LC.MarkNoAddon(sid) end)
    end
end

Receive.C = function(t, from, full)
    if not S or S.sid ~= t[2] or not FromML(full) then return end
    -- the list comes in several messages: the cap counts them all
    S.ncouncil = S.ncouncil or 0
    for n in (t[3] or ""):gmatch("[^,]+") do
        if S.ncouncil >= MAX_COUNCIL then break end
        local key = #n <= 60 and CouncilKey(n)
        if key and not S.council[key] then S.council[key] = true; S.ncouncil = S.ncouncil + 1 end
    end
    S.council[CouncilKey(S.mlFull)] = true
    if IsCouncil() then LC.ShowVote() end
end

local function Cand(t, from, full)
    if not S or S.sid ~= t[2] then return end
    local item = S.items[tonumber(t[3]) or 0]
    if not item then return end
    local key, u = SenderKey(from, full)
    if not key then return end -- only members of the group take part
    local c = item.cands[key]
    if not c then
        local g = W.GuildMember(W.UnitFullName(u))
        c = { key = key, name = W.UnitDisplayName(u) or from, class = W.UnitClassToken(u), rank = g and g.rank or "",
            rankIndex = g and g.rankIndex or 99, resp = "wait", votes = {} }
        item.cands[key] = c
    end
    return c, item
end

local function Gear(s) return (s and s ~= "" and #s <= 120 and s:match("^item:[%-%d:]+$")) and s or nil end

-- what a candidate may answer: the buttons, or the automatic timeout / autopass (never "wait" / "noaddon")
local ANSWERABLE = { timeout = true, autopass = true }
for _, r in ipairs(RESP) do ANSWERABLE[r.key] = true end
-- an answer is final: once given (or once the item is awarded) a later one is ignored. "noaddon" can
-- still be replaced: a slow answer from a player marked too early
local function Open(c, item) return not item.winner and (c.resp == "wait" or c.resp == "noaddon") end

Receive.R = function(t, from, full)
    local c, item = Cand(t, from, full)
    if not c or not Open(c, item) then return end
    c.resp = ANSWERABLE[t[4]] and t[4] or "pass"
    c.g1, c.g2 = Gear(t[5]), Gear(t[6])
    local ilvl = tonumber(t[7])
    c.ilvl = (ilvl and ilvl >= 0 and ilvl < 1000) and ilvl or nil
    S.acks[c.key] = true
    RefreshVoteSoon()
end

Receive.N = function(t, from, full)
    local c, item = Cand(t, from, full)
    -- one note, sent right after the answer, before the award
    if c and not item.winner and not c.note then c.note = W.Plain(t[4], MAX_NOTE); RefreshVoteSoon() end
end

-- votes: voter and candidate are full identities (t[4] = the candidate's key)
Receive.V = function(t, from, full)
    if not S or S.sid ~= t[2] then return end
    local voter = SenderKey(from, full)
    if not voter or not IsCouncil(voter) then return end
    local item = S.items[tonumber(t[3]) or 0]
    if not item or item.winner then return end -- votes close with the award (the count is saved in the history)
    local target = item.cands[t[4]]
    if not target then return end
    if t[5] == "1" then
        for _, c in pairs(item.cands) do c.votes[voter] = nil end -- one vote per council member and item
        target.votes[voter] = true
    else
        target.votes[voter] = nil
    end
    RefreshVoteSoon()
end

Receive.A = function(t, from, full, channel)
    if not S or S.sid ~= t[2] or not FromML(full) then return end
    local item = S.items[tonumber(t[3]) or 0]
    if not item or item.winner then return end -- awarded once: a repeat would give a second history line
    local c = item.cands[t[4]]
    local winner = c and c.name or W.Plain(W.BaseName(t[4] or "?"), 40)
    local resp = (t[5] == "" or RESP_BY[t[5]]) and t[5] or "pass" -- a known answer only (it is saved in the history)
    t[5] = resp
    item.winner, item.winnerName, item.winResp = t[4], winner, resp
    local votes = 0
    if c then for _ in pairs(c.votes) do votes = votes + 1 end end
    -- a resync after my /reload sends the awards again: one already in my history is not saved twice
    local seen = false
    for i = 1, channel == "WHISPER" and math.min(40, #hist) or 0 do
        local h = hist[i]
        if h.src == "council" and h.item == item.str and h.winner == winner and time() - (h.t or 0) < 900 then seen = true; break end
    end
    -- saved only from the loot authority of the group, or my own session: an assistant who starts sessions cannot
    -- write made-up awards into every raider's history (30 a session, pushing the real ones out of the 1,000 lines)
    if not seen and (W.IsMe(full) or LootAuthority(full)) then
        Record({ t = time(), item = item.str, winner = winner, class = c and c.class, resp = t[5], zone = ZoneName(), src = "council", votes = votes, test = S.test or nil })
    end
    -- a test session (even in a raid) is never announced
    if not S.test and FromML(W.UnitFullName("player")) and db.announce and W.Channel() then
        W.Announce(string.format(L("Loot: %s -> %s (%s)"), W.ItemLink(item.str), winner,
            (RESP_BY[t[5]] and RESP_BY[t[5]].text) or t[5]), W.Channel())
    end
    RefreshVoteSoon()
end

Receive.E = function(t, from, full)
    if not S or S.sid ~= t[2] or not FromML(full) then return end
    CloseSession()
    W.Print(L("Loot session ended."))
end

-- my session ends here (an "E", the master looter gone): an old message of it cannot open it again
CloseSession = function()
    if not S then return end
    ended[S.sid] = true
    S = nil
    if db then db.session = nil end
    if UI.loot then UI.loot:Hide() end
    if UI.vote then UI.vote:Hide() end
    LC.RefreshSession()
end

---------------------------------------------------------------------------
-- Resync: a player who reloads or joins during a session asks ("Q"); the master looter whispers him the
-- session, its items, its council and the winners so far (not the others' answers and votes).
---------------------------------------------------------------------------
local askedAt, answeredTo = 0, {}
-- tries: asked again 35 s later while no session came (the master looter answers 3 players per 30 s)
local function AskSession(tries)
    if S or not db or not db.enabled or not W.InGroup() or W.InPvP() then return end
    if GetTime() - askedAt < 30 then return end
    askedAt = GetTime()
    Send("Q")
    tries = tonumber(tries) or 1
    if tries < 4 then W.After(35, function() AskSession(tries + 1) end) end
end

local function Whisper(to, ...) W.Queue(PREFIX, W.Pack(...), "WHISPER", to) end
Receive.Q = function(t, from, full)
    if not S or not FromML(W.UnitFullName("player")) or W.IsMe(full or from) then return end
    local u = W.UnitByName(full or from)
    if not u then return end -- group members only
    local key = W.UnitKey(u)
    if GetTime() - (answeredTo[key] or -1000) < 30 then return end -- one resync per player every 30 s
    -- and 3 players per 30 s in all: a whole raid reloading must not fill my send queue for minutes
    -- (my own awards wait behind it); the others ask again 35 s later (AskSession tries)
    local now, recent = GetTime(), 0
    for _, at in pairs(answeredTo) do if now - at < 30 then recent = recent + 1 end end
    if recent >= 3 then return end
    answeredTo[key] = now
    local to = W.UnitFullName(u)
    Whisper(to, "S", S.sid, S.n, S.timeout, S.test and "t" or "")
    for i = 1, S.n do
        local item = S.items[i]
        if item then Whisper(to, "I", S.sid, i, item.str) end
    end
    local part = {}
    for key2 in pairs(S.council) do
        if #part > 0 and #table.concat(part, ",") + #key2 > 180 then Whisper(to, "C", S.sid, table.concat(part, ",")); part = {} end
        part[#part + 1] = key2
    end
    if #part > 0 then Whisper(to, "C", S.sid, table.concat(part, ",")) end
    for i = 1, S.n do
        local item = S.items[i]
        if item and item.winner then Whisper(to, "A", S.sid, i, item.winner, item.winResp or "") end
    end
end

-- Master looter gone (left the group): the session is closed here, no one could award or end it
local function CheckMaster()
    if not S or not W.InGroup() then
        if S and not FromML(W.UnitFullName("player")) then CloseSession(); W.Print(L("Loot session ended.")) end
        return
    end
    if not W.UnitByName(S.mlFull) then
        CloseSession()
        W.Print(L("Loot session closed: the master looter left the group."))
    end
end
local wasInGroup = false
W.OnRoster(function()
    CheckMaster()
    local inGroup = W.InGroup()
    if inGroup and not wasInGroup then W.After(3, AskSession) end -- just joined: a session may be running
    wasInGroup = inGroup
end)

-- The master looter's own session survives a /reload (10 min): saved at logout, back at the next login
local RESTORE_SECONDS = 600
W.On("PLAYER_LOGOUT", function()
    if not db then return end
    for i = #hist, 1, -1 do if hist[i].test then table.remove(hist, i) end end -- tests are gone after a reload
    if S and not S.test and FromML(W.UnitFullName("player")) then
        S.savedAt, S.age = time(), GetTime() - S.started
        db.session = S
    else
        db.session = nil
    end
end)
-- this file loads on demand: the first PLAYER_ENTERING_WORLD seen here is the login / reload
local firstEnter = true
W.On("PLAYER_ENTERING_WORLD", function(isLogin, isReload)
    local fresh = isLogin or isReload or firstEnter
    firstEnter = false
    wasInGroup = W.InGroup()
    if not fresh or not db then return end
    local saved = db.session
    db.session = nil
    if not S and type(saved) == "table" and type(saved.items) == "table" and time() - (saved.savedAt or 0) <= RESTORE_SECONDS
            and W.InGroup() and SameName(saved.mlFull, W.UnitFullName("player")) then
        saved.started = GetTime() - (tonumber(saved.age) or 0)
        saved.savedAt, saved.age = nil, nil
        S = saved
        -- the "no addon" marking was a timer: lost with the reload if it had not run yet
        if not saved.marked then W.After(8, function() LC.MarkNoAddon(saved.sid) end) end
        W.Print(L("Loot session restored after the reload."))
        LC.RefreshSession()
    elseif not S then
        W.After(5, AskSession)
    end
end)

-- loot messages travel in the group (or come back to me when I am alone); a resync comes whispered
local LOOT_CHANNELS = { RAID = true, PARTY = true, INSTANCE_CHAT = true, LOCAL = true }
local WHISPERED = { S = true, I = true, C = true, A = true }
W.OnAddon(PREFIX, function(msg, from, channel, full)
    if #msg > 255 then return end
    local t = W.Unpack(msg)
    if not LOOT_CHANNELS[channel] and not (channel == "WHISPER" and WHISPERED[t[1]]) then return end
    local fn = Receive[t[1]]
    if fn then fn(t, from, full or W.FullName(from), channel) end
end)

---------------------------------------------------------------------------
-- Answering (loot frame)
---------------------------------------------------------------------------
local function Answer(idx, key, note)
    if not S or S.answered[idx] then return end
    local item = S.items[idx]
    if not item then return end -- a row of the session before (a new one started, its items not all here yet)
    S.answered[idx] = true
    local g1, g2 = MyGear(item.str)
    Send("R", S.sid, idx, key, g1 or "", g2 or "", AvgIlvl())
    if note and note ~= "" then Send("N", S.sid, idx, note) end
end

local ROW_H = 58
local function LootRow(i)
    local f = UI.loot
    local r = f.rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, f)
    W.Size(r, 560, ROW_H)
    r.icon = CreateFrame("Button", nil, r)
    W.Size(r.icon, 36, 36)
    r.icon:SetPoint("TOPLEFT", 16, -4)
    r.tex = r.icon:CreateTexture(nil, "ARTWORK")
    r.tex:SetAllPoints()
    r.icon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(r.str); GameTooltip:Show()
    end)
    r.icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r.name = W.Label(r, "", "GameFontNormal")
    r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, 0)
    r.name:SetWidth(300)
    r.info = W.Label(r, "", "GameFontHighlightSmall")
    r.info:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
    r.info:SetTextColor(0.7, 0.7, 0.7)
    r.note = W.EditBox(r, 150, 60)
    r.note:SetPoint("TOPRIGHT", -18, -4)
    r.noteLbl = W.Label(r, L("Note"), "GameFontDisableSmall")
    r.noteLbl:SetPoint("RIGHT", r.note, "LEFT", -6, 0)
    r.btns = {}
    for k, resp in ipairs(RESP) do
        local b = W.Button(r, "|cff" .. resp.color .. resp.text .. "|r", 86, 20, function()
            Answer(r.idx, resp.key, r.note:GetText())
            LC.ShowLootFrame()
        end)
        b:SetPoint("BOTTOMLEFT", 60 + (k - 1) * 84, 2)
        W.Size(b, 82, 20)
        r.btns[k] = b
    end
    f.rows[i] = r
    return r
end

-- an item not in the cache yet has no name, icon or class line (autopass): the frames are drawn again a bit later
local lootRetries = 0
local function RetryLoot()
    if lootRetries >= 10 then return end
    lootRetries = lootRetries + 1
    W.After(1, function()
        if S and UI.loot and UI.loot:IsShown() then LC.ShowLootFrame() end
        RefreshVoteSoon()
    end)
end

local timedSid -- the session whose timeout timer is set
function LC.ShowLootFrame()
    if not S then return end
    if not UI.loot then
        local f = W.Window("WLRTLootFrame", 580, 120, L("Loot - choose"))
        f:SetPoint("CENTER", 0, 120)
        f.rows = {}
        f.bar = W.TimerBar(f, 12)
        f.bar:SetPoint("BOTTOMLEFT", 14, 12)
        f.bar:SetPoint("BOTTOMRIGHT", -14, 12)
        f:SetScript("OnUpdate", function(self)
            if not S then self:Hide(); return end
            local left = S.started + S.timeout - GetTime()
            if self.max ~= S.timeout then self.max = S.timeout; self.bar:SetMinMaxValues(0, S.timeout) end
            self.bar:SetValue(math.max(0, left))
            -- the text only changes once per second: no new string every frame
            local secs = math.max(0, math.ceil(left))
            if secs ~= self.secs then self.secs = secs; self.bar.text:SetText(secs .. " s") end
            if left <= 0 then
                for idx in pairs(S.items) do if not S.answered[idx] then Answer(idx, "timeout") end end
                self:Hide()
            end
        end)
        UI.loot = f
    end
    -- the timeout also runs with the window closed (its OnUpdate stops then): unanswered items still go out
    if timedSid ~= S.sid then
        timedSid = S.sid
        local sid = S.sid
        W.After(math.max(0, S.started + S.timeout - GetTime()) + 0.5, function()
            if not S or S.sid ~= sid then return end
            for idx in pairs(S.items) do if not S.answered[idx] then Answer(idx, "timeout") end end
        end)
    end
    local f = UI.loot
    local myClass = W.UnitClassToken("player")
    local n, missing = 0, false
    for idx = 1, S.n do
        local item = S.items[idx]
        if item and not S.answered[idx] and not W.GetItemInfo(item.str) then
            missing = true -- not judged yet: no autopass on an item whose class line is unknown
            n = n + 1
            local r = LootRow(n)
            r.idx, r.str = idx, item.str
            r.tex:SetTexture(W.ItemIcon(item.str))
            r.name:SetText(W.ItemLink(item.str))
            r.info:SetText("")
            r.note:SetText("")
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -32 - (n - 1) * ROW_H)
            r:Show()
        elseif item and not S.answered[idx] then
            if db.autopass and not LC.CanUse(item.str, myClass) then
                Answer(idx, "autopass")
                W.Print(string.format(L("Autopassed %s (cannot use)."), W.ItemLink(item.str)))
            else
                n = n + 1
                local r = LootRow(n)
                r.idx, r.str = idx, item.str
                r.tex:SetTexture(W.ItemIcon(item.str))
                r.name:SetText(W.ItemLink(item.str))
                local lvl = Ilvl(item.str)
                local sr = HasSR(item.str, W.UnitDisplayName("player") or Me()) and "  |cff00ccffSR|r" or ""
                r.info:SetText((lvl and ("ilvl " .. lvl .. "  ") or "") .. (_G[EquipLoc(item.str) or ""] or "") .. sr)
                r.note:SetText("")
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 0, -32 - (n - 1) * ROW_H)
                r:Show()
            end
        end
    end
    for i = n + 1, #f.rows do f.rows[i]:Hide() end
    if missing then RetryLoot() else lootRetries = 0 end
    if n == 0 then f:Hide(); return end
    f:SetHeight(36 + n * ROW_H + 34)
    f:Show()
end

---------------------------------------------------------------------------
-- Council voting window
---------------------------------------------------------------------------
local VCOLS = { { L("Name"), 110 }, { L("Rank"), 80 }, { L("Response"), 110 }, { "ilvl", 40, "CENTER" },
    { L("Gear"), 60 }, { L("Diff"), 40, "CENTER" }, { L("Votes"), 44, "CENTER" }, { L("Note"), 110 }, { L("Loots"), 40, "CENTER" } }
W.TranslateField(VCOLS, 1)
local VROW = 22

-- Items each player received in guild raids over the last 30 days (loot log of this computer)
local LOOT_DAYS = 30
local function CountKey(name)
    if not name then return nil end
    local g = W.GuildMember(name)
    return g and g.full:lower() or W.BaseName(name):lower()
end

-- read again only when the history changed (newest line, size) or the hour turned: not on every redraw
local countsCache, countsNewest, countsSize, countsHour
local function LootCounts()
    local hour = math.floor(time() / 3600)
    if countsCache and countsNewest == hist[1] and countsSize == #hist and countsHour == hour then return countsCache end
    countsNewest, countsSize, countsHour = hist[1], #hist, hour
    local counts, since = {}, time() - LOOT_DAYS * 86400
    countsCache = counts
    for _, h in ipairs(hist) do
        if (h.t or 0) < since then break end -- newest first
        if h.g ~= false and h.winner and not h.test then
            local k = CountKey(h.winner)
            if k then counts[k] = (counts[k] or 0) + 1 end
        end
    end
    return counts
end

local function SortedCands(item)
    local list = {}
    for _, c in pairs(item.cands) do list[#list + 1] = c end
    -- votes counted once per candidate, not on every comparison of the sort
    for _, c in ipairs(list) do
        local n = 0
        for _ in pairs(c.votes) do n = n + 1 end
        c.nv = n
    end
    local function votes(c) return c.nv or 0 end
    table.sort(list, function(a, b)
        local oa, ob = (RESP_BY[a.resp] or SPECIAL.wait).order, (RESP_BY[b.resp] or SPECIAL.wait).order
        if oa ~= ob then return oa < ob end
        local va, vb = votes(a), votes(b)
        if va ~= vb then return va > vb end
        return a.name < b.name
    end)
    return list, votes
end

local function GearIcon(parent)
    local b = CreateFrame("Button", nil, parent)
    W.Size(b, 18, 18)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints()
    b:SetScript("OnEnter", function(self)
        if self.str then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(self.str); GameTooltip:Show() end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

-- after a vote, show the next item (after this one, then from the start) that has no winner and none of my votes
local function NextToVote(from)
    local me = MyKey()
    for k = 1, S.n - 1 do
        local i = (from - 1 + k) % S.n + 1
        local item = S.items[i]
        if item and not item.winner then
            local voted = false
            for _, c in pairs(item.cands) do if c.votes[me] then voted = true; break end end
            if not voted then UI.vote.sel = i; return end
        end
    end
end

local function VoteRow(content)
    local r = CreateFrame("Button", nil, content)
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    W.SetColor(hl, 1, 1, 1, 0.07)
    r.cells = {}
    local x = 4
    for k, c in ipairs(VCOLS) do
        if k ~= 5 then
            local fs = W.Label(r, "", "GameFontHighlightSmall")
            fs:SetPoint("LEFT", x, 0)
            fs:SetWidth(c[2] - 2)
            fs:SetJustifyH(c[3] or "LEFT")
            fs:SetWordWrap(false)
            r.cells[k] = fs
        else
            r.g1 = GearIcon(r); r.g1:SetPoint("LEFT", x, 0)
            r.g2 = GearIcon(r); r.g2:SetPoint("LEFT", x + 22, 0)
        end
        x = x + c[2]
    end
    r.vote = W.Button(r, L("Vote"), 60, 18, function()
        if not S or not r.cand then return end
        local mine = r.cand.votes[MyKey()]
        Send("V", S.sid, UI.vote.sel, r.cand.key, mine and "0" or "1")
        if not mine then NextToVote(UI.vote.sel) end -- like RCLootCouncil: on to the next item; the item tabs go back
    end)
    r.vote:SetPoint("LEFT", x + 4, 0)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnClick", function(self) if self.cand then LC.AskAward(UI.vote.sel, self.cand.key) end end)
    r:SetScript("OnEnter", function(self)
        local c = self.cand
        if not c then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(c.name, W.ClassColor(c.class))
        if c.note then GameTooltip:AddLine(c.note, 1, 1, 1, true) end
        GameTooltip:AddLine(L("Loots: items received in guild raids, last 30 days."), 0.7, 0.7, 0.7, true)
        local voters = {}
        for v in pairs(c.votes) do voters[#voters + 1] = KeyName(v) end
        if #voters > 0 then GameTooltip:AddLine(L("Votes") .. ": " .. table.concat(voters, ", "), 0.7, 0.7, 0.7, true) end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
end

local function BuildVote()
    local f = W.Window("WLRTVoteFrame", 760, 470, L("Council voting"))
    f:SetPoint("CENTER", 0, 40)
    tinsert(UISpecialFrames, "WLRTVoteFrame")
    f.sel = 1
    f.tabs = {}
    f.icon = f:CreateTexture(nil, "ARTWORK")
    W.Size(f.icon, 40, 40)
    f.icon:SetPoint("TOPLEFT", 14, -78)
    f.name = W.Label(f, "", "GameFontNormalLarge")
    f.name:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 10, -2)
    f.info = W.Label(f, "", "GameFontHighlightSmall")
    f.info:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -4)
    f.info:SetTextColor(0.75, 0.75, 0.75)
    local x = 14
    for _, c in ipairs(VCOLS) do
        local h = W.Label(f, c[1], "GameFontNormalSmall")
        h:SetPoint("TOPLEFT", x, -128)
        h:SetTextColor(0.85, 0.85, 0.85)
        x = x + c[2]
    end
    f.list = W.ScrollList(f, 720, 280, VROW, VoteRow)
    f.list.sf:SetPoint("TOPLEFT", 10, -144)
    f.status = W.Label(f, "", "GameFontHighlightSmall")
    f.status:SetPoint("BOTTOMLEFT", 14, 16)
    f.endBtn = W.Button(f, L("End session"), 120, 22, function() LC.EndSession() end)
    f.endBtn:SetPoint("BOTTOMRIGHT", -14, 10)
    UI.vote = f
end

local function ItemTab(i)
    local f = UI.vote
    local b = f.tabs[i]
    if b then return b end
    b = CreateFrame("Button", nil, f, W.BT)
    W.Size(b, 36, 36)
    W.Backdrop(b, 1, true)
    b:SetPoint("TOPLEFT", 14 + (i - 1) * 40, -34)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetPoint("TOPLEFT", 2, -2)
    b.tex:SetPoint("BOTTOMRIGHT", -2, 2)
    b.done = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.done:SetPoint("BOTTOMRIGHT", -1, 1)
    b:SetScript("OnClick", function() f.sel = i; LC.RefreshVote() end)
    b:SetScript("OnEnter", function(self)
        if self.str then GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:SetHyperlink(self.str); GameTooltip:Show() end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.tabs[i] = b
    return b
end

function LC.ShowVote()
    if not S then W.Print(L("No session running.")); return end
    if not UI.vote then BuildVote() end
    UI.vote:Show()
    LC.RefreshVote()
end

function LC.RefreshVote()
    LC.RefreshSession()
    local f = UI.vote
    if not f or not f:IsShown() then return end
    if not S then f:Hide(); return end
    for i = 1, S.n do
        local item = S.items[i]
        local b = ItemTab(i)
        b.str = item and item.str
        b.tex:SetTexture(item and W.ItemIcon(item.str) or 134400)
        b.done:SetText(item and item.winner and "|cff33ff66v|r" or "")
        W.SetSelected(b, i == f.sel)
        b:Show()
    end
    for i = S.n + 1, #f.tabs do f.tabs[i]:Hide() end
    local item = S.items[f.sel]
    if not item then f.list:Finish(0); return end
    f.icon:SetTexture(W.ItemIcon(item.str))
    f.name:SetText(W.ItemLink(item.str))
    local lvl = Ilvl(item.str)
    local sr = LC.SRFor(item.str)
    f.info:SetText((lvl and ("ilvl " .. lvl .. "   ") or "") .. (_G[EquipLoc(item.str) or ""] or "")
        .. (item.winner and ("   |cff33ff66" .. L("Awarded to ") .. (item.winnerName or item.winner) .. "|r") or "")
        .. (sr and ("   |cff00ccff" .. L("Soft-res: ") .. table.concat(sr, ", ") .. "|r") or ""))
    local list, votes = SortedCands(item)
    local council = IsCouncil()
    local counts = LootCounts()
    for i, c in ipairs(list) do
        local r = f.list:Row(i)
        r.cand = c
        local tag = HasSR(item.str, c.name) and " |cff00ccffSR|r" or ""
        r.cells[1]:SetText(W.ColorName(c.name, c.class) .. tag)
        r.cells[2]:SetText(c.rank or "")
        r.cells[3]:SetText(RespText(c.resp))
        r.cells[4]:SetText(c.ilvl and c.ilvl > 0 and c.ilvl or "")
        local diff
        local e1, e2 = Ilvl(c.g1), Ilvl(c.g2)
        local cur = (e1 and e2) and math.min(e1, e2) or e1 or e2
        if lvl and cur then diff = lvl - cur end
        r.cells[6]:SetText(diff and ((diff > 0 and "|cff33ff66+" or (diff < 0 and "|cffff5555" or "|cffaaaaaa")) .. diff .. "|r") or "")
        local nv = votes(c)
        r.cells[7]:SetText(nv > 0 and ("|cffffcc33" .. nv .. "|r") or "0")
        r.cells[8]:SetText(c.note or "")
        local got = counts[CountKey(c.name) or ""] or 0
        r.cells[9]:SetText(got > 0 and got or "|cff7777770|r")
        r.g1.str, r.g2.str = c.g1, c.g2
        r.g1.tex:SetTexture(c.g1 and W.ItemIcon(c.g1) or nil); r.g1:SetShown(c.g1 ~= nil)
        r.g2.tex:SetTexture(c.g2 and W.ItemIcon(c.g2) or nil); r.g2:SetShown(c.g2 ~= nil)
        r.vote:SetShown(council)
        r.vote:SetText(c.votes[MyKey()] and L("Unvote") or L("Vote"))
    end
    f.list:Finish(#list)
    local isML = FromML(W.UnitFullName("player"))
    f.endBtn:SetShown(isML)
    local answered, total = 0, 0
    for _, c in pairs(item.cands) do
        total = total + 1
        if c.resp ~= "wait" then answered = answered + 1 end
    end
    f.status:SetText(string.format(L("Session by %s: %d item(s)."), S.ml, S.n) .. "   " .. answered .. "/" .. total
        .. (isML and ("   |cff888888" .. L("Award") .. ": " .. L("click") .. "|r") or ""))
end

---------------------------------------------------------------------------
-- Award (master looter)
---------------------------------------------------------------------------
-- a master loot candidate ("Name", "Name-Realm" or Forever "First Surname") is this character?
local function IsCandidate(cand, key, display)
    cand = W.Safe(cand)
    if not cand then return false end
    if W.Key(cand) == key then return true end
    -- one side without its surname / realm: the short names must match
    return (not W.HasFullPart(cand) or not W.HasFullPart(key))
        and W.BaseName(cand):lower() == W.BaseName(display or key):lower()
end

local function GiveLoot(str, key, display)
    if not (GetNumLootItems and GiveMasterLoot and GetMasterLootCandidate) then return false, false end
    for slot = 1, GetNumLootItems() do
        if W.ItemString(GetLootSlotLink(slot)) == str then
            for i = 1, 40 do
                if IsCandidate(GetMasterLootCandidate(slot, i), key, display) then
                    GiveMasterLoot(slot, i)
                    return true, true
                end
            end
            return false, true -- in the window but this player cannot receive it
        end
    end
    return false, false
end

-- Items a winner must get by trade (not in the loot window): when that player opens a trade with me, they are
-- put in the trade window (RCLootCouncil does the same). Nothing is given before both of us accept.
local owed, OWED_MAX = {}, 40 -- { id, key, name }
local tradePlaced -- the owed entries put in the trade window now open (.done: the game said "Trade complete.")
local tradeGiven, tradeBefore -- [item id] = copies in my side of the trade when I accepted / in my bags at TRADE_SHOW
local NumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
local LinkOf = (C_Container and C_Container.GetContainerItemLink) or GetContainerItemLink
local PickupItem = (C_Container and C_Container.PickupContainerItem) or PickupContainerItem

local function Owe(str, key, name)
    local id = W.ItemID(str)
    if not id then return end
    if #owed >= OWED_MAX then table.remove(owed, 1) end
    owed[#owed + 1] = { id = id, key = key, name = name }
end

-- first bag slot holding item id that is not in `used`
local function FindInBags(id, used)
    if not (NumSlots and LinkOf) then return nil end
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, NumSlots(bag) or 0 do
            local at = bag .. ":" .. slot
            if not used[at] and W.ItemID(W.Safe(LinkOf(bag, slot))) == id then return bag, slot, at end
        end
    end
end

local function CountInBags(id)
    local n, used = 0, {}
    local _, _, at = FindInBags(id, used)
    while at do
        used[at] = true
        n = n + 1
        _, _, at = FindInBags(id, used)
    end
    return n
end

W.On("TRADE_SHOW", function()
    if #owed == 0 or not db or not db.enabled or not (ClickTradeButton and PickupItem and CursorHasItem) then return end
    -- the partner ("NPC") found in the group by unit, never by name: on Forever UnitName is the first name only,
    -- a "Jean Martin" outside the raid must not be handed what "Jean Dupont" won
    local unit
    for _, u in ipairs(W.GroupUnits()) do
        if W.SameUnit("NPC", u) then unit = u; break end
    end
    local key = unit and W.UnitKey(unit)
    if not key or CursorHasItem() then return end
    local used, placed, shown = {}, {}, 0
    for _, o in ipairs(owed) do
        if o.key == key and shown < 6 then -- the trade window holds 6 items
            local bag, slot, at = FindInBags(o.id, used)
            if bag then
                PickupItem(bag, slot)
                if CursorHasItem() then
                    ClickTradeButton(shown + 1)
                    if CursorHasItem() then ClearCursor() else
                        used[at] = true
                        shown = shown + 1
                        placed[#placed + 1] = o
                    end
                end
            end
        end
    end
    if shown == 0 then return end
    W.Print(string.format(L("%d item(s) won by %s added to the trade."), shown, W.Plain(placed[1].name, 40)))
    tradePlaced = placed
    tradeGiven = nil
    tradeBefore = {}
    for _, o in ipairs(placed) do tradeBefore[o.id] = CountInBags(o.id) end
end)

-- I accepted: what is in my trade slots now is what leaves if the trade goes through (I may have changed the
-- slots by hand; any change clears both accepts, so the last snapshot is the one the trade was made with). Not
-- cleared when the accept drops: the game may send that as the trade ends, "Trade complete." decides.
W.On("TRADE_ACCEPT_UPDATE", function(mine)
    if not tradePlaced or not GetTradePlayerItemLink or mine ~= 1 then return end
    tradeGiven = {}
    for i = 1, 6 do
        local id = W.ItemID(W.Safe(GetTradePlayerItemLink(i)))
        if id then tradeGiven[id] = (tradeGiven[id] or 0) + 1 end
    end
end)

W.On("UI_INFO_MESSAGE", function(_, msg)
    if tradePlaced and ERR_TRADE_COMPLETE and W.Safe(msg) == ERR_TRADE_COMPLETE then tradePlaced.done = true end
end)

-- once the trade is over, an owed item is paid only if the game said "Trade complete.", the item was in my side
-- of the trade when I accepted and one copy left my bags (not one sold or moved, nor another copy). The message
-- may come just after TRADE_CLOSED: read 1 s later. Without the game string, the bags alone decide.
W.On("TRADE_CLOSED", function()
    local placed, given, before = tradePlaced, tradeGiven, tradeBefore
    if not placed then return end
    W.After(1, function()
        if tradePlaced == placed then tradePlaced, tradeGiven, tradeBefore = nil, nil, nil end
        if not given or (ERR_TRADE_COMPLETE and not placed.done) then return end
        local gone = {}
        for id, n in pairs(before) do gone[id] = math.min(given[id] or 0, n - CountInBags(id)) end
        for _, o in ipairs(placed) do
            if (gone[o.id] or 0) > 0 then
                gone[o.id] = gone[o.id] - 1
                for i = #owed, 1, -1 do if owed[i] == o then table.remove(owed, i) end end
            end
        end
    end)
end)

-- key = the candidate's full identity (W.UnitKey)
function LC.AskAward(idx, key)
    if not S or not FromML(W.UnitFullName("player")) then return end
    local item = S.items[idx]
    if not item then return end
    if item.winner or item.awarding then W.Print(L("This item is already awarded.")); return end
    local c = item.cands[key]
    local name = c and c.name or W.BaseName(key)
    W.Confirm(string.format(L("Award %s to %s?"), W.ItemLink(item.str), name), function()
        if not S or S.items[idx] ~= item then return end -- the session ended while the window was open
        -- two confirm windows (double click): the second one does nothing
        if item.winner or item.awarding then W.Print(L("This item is already awarded.")); return end
        item.awarding = true
        W.After(10, function() item.awarding = nil end) -- the "A" never came back (send refused): award again possible
        if item.givenTo then
            -- given (or owed) by an earlier click whose "A" never came back: only the "A" goes again, to that player
            key = item.givenTo
            c = item.cands[key]
        else
            local given, found = GiveLoot(item.str, key, name)
            if not given then
                if found then
                    -- still on the corpse: not awarded, it can be given again (in range) or to someone else
                    W.Print(string.format(L("Could not give %s to %s (out of range or not eligible?)."), W.ItemLink(item.str), name))
                    item.awarding = nil
                    return
                elseif key ~= MyKey() and not S.test then -- a test item (my own gear) is never owed
                    W.Print(string.format(L("Trade %s to %s (item not in the loot window)."), W.ItemLink(item.str), name))
                    Owe(item.str, key, name) -- put in the trade window when that player opens a trade with me
                end
            end
            item.givenTo = key
        end
        SendFirst("A", S.sid, idx, key, c and c.resp or "")
        -- next item without a winner
        for i = 1, S.n do
            if S.items[i] and not S.items[i].winner and i ~= idx then UI.vote.sel = i; break end
        end
    end, L("Award"))
end

---------------------------------------------------------------------------
-- Master looter: items of the opened corpse
---------------------------------------------------------------------------
local seenLoot, seenCount = {}, 0
local SEEN_MAX = 500 -- a night of raiding is far below this; the table never grows without limit
local function CorpseItems()
    local items = {}
    if not GetNumLootItems then return items end
    if seenCount > SEEN_MAX then wipe(seenLoot); seenCount = 0 end
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink(slot)
        local str = W.ItemString(link)
        if str then
            local q = W.ItemQuality(link) or 0
            local guid = GetLootSourceInfo and GetLootSourceInfo(slot) or ""
            local key = tostring(W.Safe(guid) or "") .. str .. slot
            if q >= (db.minQuality or 4) and not seenLoot[key] then
                seenLoot[key] = true
                seenCount = seenCount + 1
                items[#items + 1] = str
            end
        end
    end
    return items
end

W.On("LOOT_OPENED", function()
    if not db or not db.enabled or not db.autoStart or not W.InRaid() or not LC.IsML() then return end
    local items = CorpseItems()
    if #items == 0 then return end
    local lines = {}
    for _, str in ipairs(items) do
        local sr = LC.SRFor(str)
        lines[#lines + 1] = W.ItemLink(str) .. (sr and ("  |cff00ccffSR: " .. table.concat(sr, ", ") .. "|r") or "")
        if sr then W.Print(L("Soft-res: ") .. W.ItemLink(str) .. " -> " .. table.concat(sr, ", ")) end
    end
    W.Confirm(L("Start a loot session with these items?") .. "\n\n" .. table.concat(lines, "\n") .. OpenWarning(), function()
        LC.StartSession(items)
    end, L("Start session"))
end)

---------------------------------------------------------------------------
-- Loot log: every item looted in raid (CHAT_MSG_LOOT)
---------------------------------------------------------------------------
local function Pattern(fmt)
    if not fmt then return nil end
    local p = fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    p = p:gsub("%%%%s", "(.+)"):gsub("%%%%d", "(%%d+)")
    return "^" .. p
end
local PAT_OTHER = { Pattern(LOOT_ITEM_MULTIPLE), Pattern(LOOT_ITEM) }
local PAT_SELF = { Pattern(LOOT_ITEM_SELF_MULTIPLE), Pattern(LOOT_ITEM_SELF) }

local lootEv = W.On("CHAT_MSG_LOOT", function(msg)
    if not db or not db.logLoot or not W.InRaid() or not msg then return end
    msg = W.Safe(msg)
    if not msg then return end
    local who, link
    for _, p in ipairs(PAT_OTHER) do
        local a, b = msg:match(p)
        if a and b then who, link = a, b; break end
    end
    if not who then
        for _, p in ipairs(PAT_SELF) do
            local a = msg:match(p)
            if a then who, link = W.UnitDisplayName("player") or Me(), a; break end
        end
    end
    local str = W.ItemString(link)
    if not who or not str then return end
    if (W.ItemQuality(link) or 0) < (db.minQuality or 4) then return end
    -- saved under the full name when the group tells who it is (two raiders with that first name: it can't)
    local unit, class = W.UnitByName(who)
    local winner = unit and W.UnitDisplayName(unit) or W.BaseName(who)
    who = W.BaseName(who)
    -- already recorded by a council award?
    for i = 1, math.min(10, #hist) do
        local h = hist[i]
        -- the award keeps the surname ("First Surname" on Forever), the loot line only the first name
        if h.item == str and W.BaseName(h.winner) == who and time() - h.t < 300 then return end
    end
    Record({ t = time(), item = str, winner = winner, class = class, resp = "", zone = ZoneName(), src = "loot" })
end, nil, true) -- on in a raid with the loot log enabled (LC.Watch)

---------------------------------------------------------------------------
-- Soft-res: "!sr [item]" whispers + softres.it import
---------------------------------------------------------------------------
local function PlayerSR(name)
    local out = {}
    for id, list in pairs(db.sr) do
        for _, n in ipairs(list) do if SRMatch(n, name) then out[#out + 1] = id; break end end
    end
    return out
end

local function ItemText(id) return W.ItemLink("item:" .. id) end

-- caps: the saved soft-res list cannot grow without limit (whispers, imports)
local SR_MAX_ITEMS, SR_MAX_NAMES = 300, 40
function LC.AddSR(name, id)
    if not db.sr[id] then
        local count = 0
        for _ in pairs(db.sr) do count = count + 1 end
        if count >= SR_MAX_ITEMS then return false end
        db.sr[id] = {}
    end
    if #db.sr[id] >= SR_MAX_NAMES then return false end
    for _, n in ipairs(db.sr[id]) do if SRMatch(n, name) then return false end end
    table.insert(db.sr[id], name)
    return true
end

-- at most 3 answers per player in 10 s: a flood of "!sr" whispers must not make me whisper back in a loop
-- (the game's anti-spam would mute me)
local REPLY_WINDOW, REPLY_MAX = 10, 3
local replies, repliesCount = {}, 0 -- [sender] = { start, count }
local function Reply(to, text)
    local now, r = GetTime(), replies[to]
    if not r or now - r[1] > REPLY_WINDOW then
        if not r then
            repliesCount = repliesCount + 1
            if repliesCount > 200 then wipe(replies); repliesCount = 1 end -- stays small over an evening
        end
        r = { now, 0 }
        replies[to] = r
    end
    if r[2] >= REPLY_MAX then return end
    r[2] = r[2] + 1
    W.SendChat(W.TAG:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") .. text, "WHISPER", to)
end
-- that player had his 3 answers of the last 10 s: his whisper is not even read (the soft-res list is not scanned)
local function Limited(to)
    local r = replies[to]
    return r ~= nil and GetTime() - r[1] <= REPLY_WINDOW and r[2] >= REPLY_MAX
end

local srEv = W.On("CHAT_MSG_WHISPER", function(text, sender)
    if not db or not db.srWhisper then return end
    text, sender = W.Safe(text), W.Safe(sender)
    if not text or not sender or not text:lower():match("^!sr") then return end
    -- only my group and my guild can soft-reserve; answers go to the full "Name-Realm"
    if not (W.UnitByName(W.FullName(sender)) or W.GuildMember(sender)) then return end
    if Limited(sender) then return end
    local name = W.Plain(W.FOREVER and W.FullName(sender) or W.BaseName(sender), 40) -- with the surname on Forever
    local rest = text:gsub("^!%a+%s*", "")
    local mine = PlayerSR(name)
    local function list()
        local t = {}
        for _, id in ipairs(mine) do t[#t + 1] = ItemText(id) end
        return table.concat(t, ", ")
    end
    if rest == "" then
        Reply(sender, #mine > 0 and string.format(L("Your soft-res: %s"), list()) or L("No soft-res. Whisper \"!sr [item link]\"."))
        return
    end
    local id = W.ParseItem(rest)
    if id and (id < 1 or id > 9999999) then id = nil end -- a made-up number is not saved as an item
    if not id then Reply(sender, L("Unknown item. Whisper \"!sr\" + the item link or ID.")); return end
    if #mine >= (db.srMax or 1) then
        Reply(sender, string.format(L("You already have %d soft-res: %s"), #mine, list()))
        return
    end
    if not LC.AddSR(name, id) then -- already reserved by this player, or the list is full: say what is saved
        Reply(sender, #mine > 0 and string.format(L("Your soft-res: %s"), list()) or L("No soft-res. Whisper \"!sr [item link]\"."))
        return
    end
    Reply(sender, string.format(L("Soft-res saved: %s (%d/%d)."), ItemText(id), #mine + 1, db.srMax or 1))
    W.Print(string.format(L("%s soft-reserved %s."), name, ItemText(id)))
    LC.RefreshSR()
end, nil, true) -- on when "!sr" whispers are accepted (LC.Watch)

-- loot messages and "!sr" whispers are only listened to when they are used
function LC.Watch()
    W.Activate(lootEv, db and db.logLoot and W.InRaid())
    W.Activate(srEv, db and db.srWhisper)
end
W.OnRoster(LC.Watch)
W.OnReady(LC.Watch)

local function CSVSplit(line)
    local out, field, inq = {}, "", false
    for ch in line:gmatch(".") do
        if ch == '"' then inq = not inq
        elseif ch == "," and not inq then out[#out + 1] = field; field = ""
        else field = field .. ch end
    end
    out[#out + 1] = field
    for i, v in ipairs(out) do out[i] = v:gsub("^%s+", ""):gsub("%s+$", "") end
    return out
end

function LC.ImportSR(text)
    local count, idCol, nameCol = 0, nil, nil
    for line in (text or ""):gmatch("[^\r\n]+") do
        local f = CSVSplit(line)
        if not idCol then
            for i, v in ipairs(f) do
                local low = v:lower()
                if low == "itemid" then idCol = i elseif low == "name" then nameCol = i end
            end
            if idCol and nameCol then f = nil end -- header line
        end
        if f then
            local id, name
            -- a pasted text: an item id is a whole number (a "nan" would break the table), a name at most 40 letters
            if idCol and nameCol then
                id, name = W.Int(f[idCol], 1, 9999999), f[nameCol]
            else
                for _, v in ipairs(f) do
                    if tonumber(v) then id = id or W.Int(v, 1, 9999999) elseif v ~= "" then name = name or v end
                end
            end
            -- the surname kept on Forever (two raiders can share a first name), the realm dropped elsewhere
            name = name and W.SanitizeName(name)
            name = name and W.CutUTF8(W.FOREVER and W.FullName(name) or W.BaseName(name), 40)
            if id and name and name ~= "" and LC.AddSR(name, id) then count = count + 1 end
        end
    end
    return count
end

---------------------------------------------------------------------------
-- Module panel: Session / History / Soft-res / Settings
---------------------------------------------------------------------------
local function QualityName(q)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    local name = _G["ITEM_QUALITY" .. q .. "_DESC"] or tostring(q)
    return c and (c.hex or "|cffffffff") .. name .. "|r" or name
end

function LC.RefreshSession()
    local p = UI.session
    if not p or not p:IsVisible() then return end
    local lines = {}
    if S then
        lines[1] = "|cffffffff" .. string.format(L("Session by %s: %d item(s)."), S.ml, S.n) .. "|r"
        for i = 1, S.n do
            local item = S.items[i]
            if item then
                lines[#lines + 1] = "  " .. W.ItemLink(item.str) .. (item.winner and ("  |cff33ff66-> " .. (item.winnerName or item.winner) .. "|r") or "")
            end
        end
        local council = {}
        for n in pairs(S.council) do council[#council + 1] = KeyName(n) end
        table.sort(council)
        lines[#lines + 1] = "|cff888888" .. L("Council members: ") .. table.concat(council, ", ") .. "|r"
    else
        lines[1] = "|cff999999" .. L("No session running.") .. "|r"
    end
    p.status:SetText(table.concat(lines, "\n"))
    local pend = {}
    for _, str in ipairs(db.pending) do pend[#pend + 1] = "  " .. W.ItemLink(str) end
    p.pending:SetText(table.concat(pend, "\n"))
end

local function BuildSession(p)
    UI.session = p
    p.status = W.Label(p, "", "GameFontHighlightSmall")
    p.status:SetPoint("TOPLEFT", 14, -6)
    p.status:SetWidth(520)
    p.status:SetJustifyV("TOP")
    W.Button(p, L("Open voting window"), 170, 22, LC.ShowVote):SetPoint("TOPRIGHT", -16, -4)
    W.Button(p, L("End session"), 170, 22, LC.EndSession):SetPoint("TOPRIGHT", -16, -30)
    W.Button(p, L("Test session (your gear)"), 170, 22, function()
        if S then W.Confirm(L("Start a test session?") .. OpenWarning(), LC.Test, L("Start session")) else LC.Test() end
    end):SetPoint("TOPRIGHT", -16, -56)
    local lbl = W.Label(p, L("Items for the next session (shift-click an item in the box):"), "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", 14, -250)
    local box = W.EditBox(p, 260, 255)
    box:SetPoint("TOPLEFT", 18, -270)
    W.LinkTarget(box)
    local function add()
        local id = W.ParseItem(box:GetText())
        local str = W.ItemString(box:GetText()) or (id and ("item:" .. id))
        if str then table.insert(db.pending, str); box:SetText(""); LC.RefreshSession() end
    end
    box:SetScript("OnEnterPressed", add)
    W.Button(p, L("Add item"), 110, 22, add):SetPoint("LEFT", box, "RIGHT", 8, 0)
    W.Button(p, L("Start session"), 120, 22, function()
        if #db.pending == 0 then return end
        local function start()
            if not LC.StartSession(db.pending) then return end -- refused: the list is kept
            db.pending = {}
            LC.RefreshSession()
        end
        if S then W.Confirm(L("Start a loot session with these items?") .. OpenWarning(), start, L("Start session")) else start() end
    end):SetPoint("LEFT", box, "RIGHT", 124, 0)
    W.Button(p, L("Clear list"), 100, 22, function() db.pending = {}; LC.RefreshSession() end)
        :SetPoint("LEFT", box, "RIGHT", 250, 0)
    p.pending = W.Label(p, "", "GameFontHighlightSmall")
    p.pending:SetPoint("TOPLEFT", 14, -298)
    p.pending:SetWidth(600)
    p:SetScript("OnShow", LC.RefreshSession)
end

-- History / loot log
local function HistoryRows()
    local filter = UI.filter and UI.filter:GetText():lower() or ""
    local rows = {}
    for i, h in ipairs(hist) do
        local link = W.ItemLink(h.item)
        local text = (h.winner .. " " .. link .. " " .. (h.zone or "")):lower()
        if filter == "" or text:find(filter, 1, true) then
            rows[#rows + 1] = { index = i, cells = {
                date("%d/%m %H:%M", h.t), link, W.ColorName(h.winner, h.class),
                h.resp ~= "" and RespText(h.resp) or "-", h.zone or "", h.test and L("Test") or h.src == "council" and L("Council") or L("Looted") } }
        end
    end
    return rows
end

function LC.RefreshHistory()
    if UI.history then UI.history:SetData(HistoryRows()) end
end

local function BuildHistory(p)
    local lbl = W.Label(p, L("Filter:"), "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", 14, -8)
    UI.filter = W.EditBox(p, 180, 40)
    UI.filter:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
    UI.filter:SetScript("OnTextChanged", LC.RefreshHistory)
    W.Button(p, L("Export CSV"), 110, 22, function()
        local out = { "date,item,itemID,winner,response,zone,source" }
        for _, h in ipairs(hist) do if not h.test then
            local name = W.GetItemInfo(h.item) or ""
            out[#out + 1] = W.CSV(date("%Y-%m-%d %H:%M", h.t), name, W.ItemID(h.item) or "",
                h.winner, h.resp or "", h.zone or "", h.src or "")
        end end -- test lines are not exported
        W.TextPopup(L("History"), table.concat(out, "\n"), { hint = "Ctrl+C" })
    end):SetPoint("TOPRIGHT", -130, -6)
    W.Button(p, L("Clear"), 100, 22, function()
        W.Confirm(L("Clear history?"), function() wipe(hist); LC.RefreshHistory() end)
    end):SetPoint("TOPRIGHT", -16, -6)
    UI.history = W.Table(p, { { L("Date"), 80 }, { L("Item"), 230 }, { L("Winner"), 110 }, { L("Response"), 110 },
        { L("Zone"), 130 }, { L("Source"), 70 } }, 470)
    UI.history:SetPoint("TOPLEFT", 10, -38)
    UI.history:SetEmptyText(L("No loot given yet."))
    UI.history.onEnter = function(d, row)
        local h = hist[d.index]
        if h then GameTooltip:SetOwner(row, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(h.item); GameTooltip:Show() end
    end
    UI.history.onClick = function(d, btn)
        if btn == "RightButton" then
            -- the line itself, not its index: a loot recorded while the question is open shifts the indexes
            local entry = hist[d.index]
            W.Confirm(L("Delete this entry?"), function()
                for i = 1, #hist do if hist[i] == entry then table.remove(hist, i); break end end
                LC.RefreshHistory()
            end)
        end
    end
    p:SetScript("OnShow", LC.RefreshHistory)
end

-- Soft-res tab
function LC.RefreshSR()
    if not UI.sr or not UI.sr:IsVisible() then return end
    local rows = {}
    for id, list in pairs(db.sr) do
        if #list > 0 then rows[#rows + 1] = { id = id, cells = { ItemText(id), table.concat(list, ", ") } } end
    end
    table.sort(rows, function(a, b) return a.id < b.id end)
    UI.sr:SetData(rows)
end

local function BuildSR(p)
    W.Button(p, L("Import (softres.it CSV)"), 170, 22, function()
        W.TextPopup(L("Soft-res"), "", {
            hint = L("Paste the softres.it CSV export (or lines \"Name,ItemID\")."),
            confirmText = L("Import"),
            onConfirm = function(text)
                local n = LC.ImportSR(text)
                if n == 0 then return L("Nothing found to import.") end
                W.Print(string.format(L("%d soft-res imported."), n))
                LC.RefreshSR()
            end,
        })
    end):SetPoint("TOPLEFT", 14, -6)
    W.Button(p, L("Announce"), 100, 22, function()
        local ch = W.Channel()
        if not ch then W.Print(L("You are not in a group.")); return end
        local lines = {}
        for id, list in pairs(db.sr) do
            if #list > 0 then lines[#lines + 1] = "SR " .. ItemText(id) .. ": " .. table.concat(list, ", ") end
        end
        W.AnnounceLines(lines, ch) -- one line a second, 20 at most (a few nights of soft-res made 300 lines at once)
    end):SetPoint("TOPLEFT", 190, -6)
    W.Button(p, L("Clear"), 90, 22, function()
        W.Confirm(L("Clear all soft-res?"), function() wipe(db.sr); LC.RefreshSR() end)
    end):SetPoint("TOPLEFT", 296, -6)
    W.Check(p, L("Accept \"!sr [item]\" whispers"), function() return db.srWhisper end, function(v) db.srWhisper = v; LC.Watch() end)
        :SetPoint("TOPLEFT", 400, -5)
    local lbl = W.Label(p, L("Max soft-res per player:"), "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT", 16, -40)
    W.Cycle(p, 40, { { 1, "1" }, { 2, "2" }, { 3, "3" } }, function() return db.srMax end, function(v) db.srMax = v end)
        :SetPoint("LEFT", lbl, "RIGHT", 8, 0)
    UI.sr = W.Table(p, { { L("Item"), 280 }, { L("Players"), 380 } }, 430)
    UI.sr:SetPoint("TOPLEFT", 10, -66)
    UI.sr.onEnter = function(d, row)
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink("item:" .. d.id); GameTooltip:Show()
    end
    UI.sr.onClick = function(d, btn)
        if btn == "RightButton" then
            W.Confirm(L("Delete this entry?"), function() db.sr[d.id] = nil; LC.RefreshSR() end)
        end
    end
    p:SetScript("OnShow", LC.RefreshSR)
end

local function RankValues()
    local vals = {}
    local n = GuildControlGetNumRanks and GuildControlGetNumRanks() or 0
    for i = 1, n do vals[#vals + 1] = { i - 1, (GuildControlGetRankName(i) or ("#" .. i)) } end
    if #vals == 0 then for i = 0, 9 do vals[#vals + 1] = { i, "#" .. i } end end
    return vals
end

local function BuildSettings(p)
    local y = -6
    local function check(text, key)
        W.Check(p, text, function() return db[key] end, function(v) db[key] = v; LC.Watch() end):SetPoint("TOPLEFT", 12, y)
        y = y - 26
    end
    check(L("Enable the loot council"), "enabled")
    check(L("Ask to start a session when I open a boss as master looter"), "autoStart")
    check(L("Announce awards in raid chat"), "announce")
    check(L("Autopass items my class cannot use"), "autopass")
    check(L("Loot log: record every item looted in raid"), "logLoot")
    y = y - 8
    local function row(text)
        local lbl = W.Label(p, text, "GameFontHighlightSmall")
        lbl:SetPoint("TOPLEFT", 16, y - 4)
        y = y - 30
        return lbl
    end
    local q = row(L("Minimum quality:"))
    W.Cycle(p, 120, { { 2, QualityName(2) }, { 3, QualityName(3) }, { 4, QualityName(4) }, { 5, QualityName(5) } },
        function() return db.minQuality end, function(v) db.minQuality = v end):SetPoint("LEFT", q, "RIGHT", 10, 0)
    local t = row(L("Answer time:"))
    W.Cycle(p, 80, { { 30, "30 s" }, { 60, "60 s" }, { 90, "90 s" }, { 120, "120 s" }, { 180, "180 s" } },
        function() return db.timeout end, function(v) db.timeout = v end):SetPoint("LEFT", t, "RIGHT", 10, 0)
    local c = row(L("Council: guild ranks up to"))
    local rankBtn = W.Cycle(p, 150, RankValues(), function() return db.councilRank end, function(v) db.councilRank = v end)
    rankBtn:SetPoint("LEFT", c, "RIGHT", 10, 0)
    local e = row(L("Extra council members (names, comma):"))
    local box = W.EditBox(p, 300, 200)
    box:SetPoint("LEFT", e, "RIGHT", 10, 0)
    box:SetScript("OnShow", function(self) self:SetText(db.councilExtra or "") end)
    box:SetScript("OnTextChanged", function(self) db.councilExtra = self:GetText() end)
end

local function Build(p)
    W.Title(p, L("Loot Council"))
    UI.tabs = W.SubTabs(p, { L("Session"), L("History"), L("Soft-res"), L("Settings") })
    BuildSession(UI.tabs.frames[1])
    BuildHistory(UI.tabs.frames[2])
    BuildSR(UI.tabs.frames[3])
    BuildSettings(UI.tabs.frames[4])
    UI.tabs:Select(1)
end

-- Test: a session with 3 of your own equipped items
function LC.Test()
    local items = {}
    for _, slot in ipairs({ 1, 5, 16, 7, 3 }) do
        local str = W.ItemString(GetInventoryItemLink("player", slot))
        if str and #items < 3 then items[#items + 1] = str end
    end
    if #items == 0 then items = { "item:19019" } end
    LC.StartSession(items, true)
end
-- "Test all": alone only (in a group the test session would go to the whole raid)
W.RegisterTest("Loot Council", function() return db and db.enabled and not W.InGroup() end,
    function() LC.Test() end,
    function() if not W.InGroup() then LC.EndSession() end end)

W.slash.loot = function(rest)
    rest = rest or ""
    if rest == "test" then LC.Test()
    elseif rest:match("^add") then
        local str = W.ItemString(rest)
        if str then table.insert(db.pending, str); W.Print(W.ItemLink(str)) end
    elseif rest == "vote" then LC.ShowVote()
    else W.Toggle("LootCouncil") end
end
W.slash.sr = function() W.Toggle("LootCouncil"); if UI.tabs then UI.tabs:Select(3) end end

W.RegisterModule("LootCouncil", "Loot Council", Build, function() LC.RefreshSession() end)
