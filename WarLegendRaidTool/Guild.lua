-- WarLegend RaidTool - Guild tools
-- Inactive members, guild professions (synced between members who have the addon:
-- who can craft what), recruitment messages.
local W = WLRT
W.AddFR({
    ["Guild"] = "Guilde",
    ["Inactive"] = "Inactifs",
    ["Professions"] = "Métiers",
    ["Recruitment"] = "Recrutement",
    ["Offline for at least (days):"] = "Hors ligne depuis au moins (jours) :",
    ["Hide officers"] = "Cacher les officiers",
    ["Level"] = "Niveau",
    ["Rank"] = "Rang", -- also in LootCouncil.lua, but that file is in the raid addon (not always loaded)
    ["Offline since"] = "Absent depuis",
    ["Public note"] = "Note publique",
    ["%d members"] = "%d membres",
    ["Export list"] = "Exporter la liste",
    ["Search a recipe or item:"] = "Chercher une recette ou un objet :",
    ["Recipe"] = "Recette",
    ["Crafters"] = "Artisans",
    ["Updated"] = "Mis à jour",
    ["All"] = "Tous",
    ["Ask the guild"] = "Demander à la guilde",
    ["Open each of your professions once so the addon can read your recipes."] =
        "Ouvre chacun de tes métiers une fois pour que l'addon lise tes recettes.",
    ["Data comes from guild members who have the addon."] = "Les données viennent des membres de la guilde qui ont l'addon.",
    ["Message %d"] = "Message %d",
    ["Channel (name or number):"] = "Canal (nom ou numéro) :",
    ["Post now"] = "Poster maintenant",
    ["Remind me every"] = "Me rappeler toutes les",
    ["min"] = "min",
    ["Time to post your recruitment message."] = "C'est l'heure de poster ton message de recrutement.",
    ["Post"] = "Poster",
    ["Channel not found: "] = "Canal introuvable : ",
    ["{guild} = guild name, {me} = your name. 255 characters max."] = "{guild} = nom de la guilde, {me} = ton nom. 255 caractères max.",
    ["<{guild}> is recruiting for its raids! All classes welcome, friendly and motivated. Whisper {me} for info."] =
        "<{guild}> recrute pour ses raids ! Toutes classes bienvenues, ambiance sympa et motivée. /w {me} pour infos.",
    ["Not in a guild."] = "Pas dans une guilde.",
    ["No profession link from %s yet: he must open his profession once with the addon."] =
        "Pas encore de lien de métier de %s : il doit ouvrir son métier une fois avec l'addon.",
    ["Click: open his profession. Shift-click: link it in the chat."] =
        "Clic : ouvrir son métier. Maj-clic : le lier dans le chat.",
    ["Ctrl-click: whisper him."] = "Ctrl-clic : le chuchoter.",
    ["Online members only"] = "Membres en ligne seulement",
    ["Shows only the members online now (the list and the crafters of a recipe)."] =
        "N'affiche que les membres en ligne maintenant (la liste et les artisans d'une recette).",
    ["Nobody has a recipe named \"%s\" (only members who have the addon and opened their professions)."] =
        "Personne n'a de recette « %s » (seulement les membres qui ont l'addon et ont ouvert leurs métiers).",
    ["Who can craft \"%s\":"] = "Qui peut fabriquer « %s » :",
    ["... and %d more: see Guild > Professions."] = "... et %d de plus : voir Guilde > Métiers.",
    ["Player:"] = "Joueur :",
    ["Profession:"] = "Métier :",
    ["Skill:"] = "Niveau :",
    ["Recipe or item:"] = "Recette ou objet :",
    ["Recipe or item"] = "Recette ou objet",
    ["All professions"] = "Tous les métiers",
    ["Profession"] = "Métier",
    ["Skill"] = "Niveau",
    ["Recipes"] = "Recettes",
    ["%d result(s), data from %d member(s)"] = "%d résultat(s), données de %d membre(s)",
    ["No member matches these filters."] = "Aucun membre ne correspond à ces filtres.",
    ["No profession data yet."] = "Aucune donnée de métier pour l'instant.",
    ["Ask the guild members to open each of their professions once, with WaR LegenD RaidTool installed (open yours too)."] =
        "Demande aux membres de la guilde d'ouvrir chacun de leurs métiers une fois, avec WaR LegenD RaidTool installé (ouvre aussi les tiens).",
    ["WoW only lets an addon read a player's professions from that player's own game, and the recipe list only while the profession window is open. Their addon then sends them to the guild."] =
        "WoW ne laisse un addon lire les métiers d'un joueur que depuis le jeu de ce joueur, et la liste des recettes seulement quand la fenêtre du métier est ouverte. Son addon les envoie ensuite à la guilde.",
    ["What is received is saved: it stays after closing this window or restarting the game."] =
        "Ce qui est reçu est enregistré : ça reste après avoir fermé cette fenêtre ou relancé le jeu.",
    ["Recipes not received yet: this member must open this profession once."] =
        "Recettes pas encore reçues : ce membre doit ouvrir ce métier une fois.",
    ["Only members who have the addon appear here, once their data has been received."] =
        "Seuls les membres qui ont l'addon apparaissent ici, une fois leurs données reçues.",
    ["Alchemy"] = "Alchimie",
    ["Blacksmithing"] = "Forge",
    ["Enchanting"] = "Enchantement",
    ["Engineering"] = "Ingénierie",
    ["Herbalism"] = "Herboristerie",
    ["Leatherworking"] = "Travail du cuir",
    ["Mining"] = "Minage",
    ["Skinning"] = "Dépeçage",
    ["Tailoring"] = "Couture",
    ["Cooking"] = "Cuisine",
    ["First Aid"] = "Secourisme",
    ["Fishing"] = "Pêche",
    ["Source"] = "Source",
    ["Roster"] = "Liste",
    ["Link"] = "Lien",
    ["Shared by their WaR LegenD RaidTool (read on their own game)."] =
        "Partagé par son WaR LegenD RaidTool (lu sur son propre jeu).",
    ["From the guild roster (game server): main professions only, no maximum skill."] =
        "Depuis la liste de guilde (serveur du jeu) : métiers principaux seulement, sans niveau maximum.",
    ["From a profession link: it names the profession, not the skill level."] =
        "Depuis un lien de métier : il donne le métier, pas le niveau.",
    ["Skill unknown"] = "Niveau inconnu",
    ["Professions: %s %s saved (%d recipes)."] = "Métiers : %s %s enregistré (%d recettes).",
    ["Profession link saved: %s - %s (a link gives no skill level)."] =
        "Lien de métier enregistré : %s - %s (un lien ne donne pas le niveau).",
    ["This profession link belongs to nobody in the guild."] = "Ce lien de métier n'appartient à personne de la guilde.",
    ["Share my professions with the guild's WaR LegenD RaidTool users (hidden addon messages, no chat)"] =
        "Partager mes métiers avec les utilisateurs WaR LegenD RaidTool de la guilde (messages d'addon invisibles, pas de chat)",
    ["Sources: guild roster (server), the member's WaR LegenD RaidTool, profession links (Shift-click one while this tab is open)."] =
        "Sources : liste de guilde (serveur), WaR LegenD RaidTool du membre, liens de métier (Maj-clic sur un lien pendant que cet onglet est ouvert).",
    ["The game server gives no profession in the guild roster yet, and no member has shared theirs."] =
        "Le serveur du jeu ne donne encore aucun métier dans la liste de guilde, et aucun membre n'a partagé les siens.",
})
local L = W.L

local G = {}
W.Guild = G
local PREFIX = "WLRT_PROF"
local db
local UI = {}

W.OnReady(function()
    db = W.DB("guild", { inactiveDays = 14, hideOfficers = true, channel = "LookingForGroup", interval = 15, remind = false,
        last = 0, sel = 1, profFilter = "", profMin = 0, profMax = 0, profShare = true, profSort = "", profSortDesc = false,
        profOnline = false })
    if type(db.msgs) ~= "table" then db.msgs = { L("<{guild}> is recruiting for its raids! All classes welcome, friendly and motivated. Whisper {me} for info."), "", "" } end
    if type(db.data) ~= "table" then db.data = {} end
    -- members who have not synced for 90 days (left the guild...) are forgotten: the saved file stays small
    local cutoff, me, myKey = time() - 90 * 86400, W.Safe(UnitName("player")), W.UnitKey("player")
    for _, members in pairs(db.data) do
        for name, e in pairs(members) do
            local seen = type(e) == "table" and math.max(e.t or 0, e.srvT or 0, e.lkT or 0) or 0
            if name ~= me and name ~= myKey and seen < cutoff then members[name] = nil end
        end
    end
end)

-- Recipe lists were tables of numbers: now compact "id,id,..." text (about 3x less memory)
W.Migration(2, "guild", function(all)
    local g = all.guild
    if type(g) ~= "table" or type(g.data) ~= "table" then return end
    for _, members in pairs(g.data) do
        for _, e in pairs(type(members) == "table" and members or {}) do
            if type(e) == "table" and type(e.rec) == "table" then
                for prof, ids in pairs(e.rec) do
                    if type(ids) == "table" then e.rec[prof] = table.concat(ids, ",") end
                end
            end
        end
    end
end)

local function GuildName()
    return (GetGuildInfo and GetGuildInfo("player")) or nil
end

local function Data()
    local g = GuildName() or "?"
    db.data[g] = db.data[g] or {}
    return db.data[g]
end

local function Me() return W.Safe(UnitName("player")) or "?" end

-- Members are keyed by their full identity, lowercased (W.Key: "first surname" on Forever, where many share a
-- first name). Entries saved by older versions are keyed by the bare first name and have no .name field:
-- they are still shown, and dropped once the same player sends data under the full key.
local function EntryName(key, e) return (e and e.name) or key end
local function Store(key, name, e)
    local d = Data()
    e.name = name
    d[key] = e
    local short = W.BaseName(name)
    local old = short and d[short]
    if short ~= key and old and not old.name then d[short] = nil end
end

---------------------------------------------------------------------------
-- Inactive members
---------------------------------------------------------------------------
function G.Inactive()
    local out = {}
    if not W.IsInGuild() then return out end
    for i = 1, (GetNumGuildMembers() or 0) do
        local name, rank, rankIndex, level, _, _, note, _, online, _, class = GetGuildRosterInfo(i)
        name = W.Safe(name)
        if name and not online then
            local y, m, d, h = 0, 0, 0, 0
            if GetGuildRosterLastOnline then y, m, d, h = GetGuildRosterLastOnline(i) end
            local days = (y or 0) * 365 + (m or 0) * 30 + (d or 0) + (h or 0) / 24
            if days >= (db.inactiveDays or 14) and not (db.hideOfficers and (rankIndex or 9) <= 1) then
                out[#out + 1] = { name = W.BaseName(name), rank = rank, level = level, class = class, days = days, note = note or "" }
            end
        end
    end
    table.sort(out, function(a, b) return a.days > b.days end)
    return out
end

---------------------------------------------------------------------------
-- Professions: mine, read from the game
---------------------------------------------------------------------------
-- the 12 professions of WoW: Forever (checked on wowhead.com/forever and Naowh Forever's recipe data), by skill
-- line ID: the same on every client language, so "Alchemy" (English client) and "Alchimie" (French) are one
-- profession in the list and its filter. spell = the profession spell (its name in this client's language).
local PROFS = {
    { id = 171, en = "Alchemy", fr = "Alchimie", spell = 2259 },
    { id = 164, en = "Blacksmithing", fr = "Forge", spell = 2018 },
    { id = 333, en = "Enchanting", fr = "Enchantement", spell = 7411 },
    { id = 202, en = "Engineering", fr = "Ingénierie", spell = 4036 },
    { id = 182, en = "Herbalism", fr = "Herboristerie", spell = 2366 },
    { id = 165, en = "Leatherworking", fr = "Travail du cuir", spell = 2108 },
    { id = 186, en = "Mining", fr = "Minage", spell = 2575 },
    { id = 393, en = "Skinning", fr = "Dépeçage", spell = 8613 },
    { id = 197, en = "Tailoring", fr = "Couture", spell = 3908 },
    { id = 185, en = "Cooking", fr = "Cuisine", spell = 2550 },
    { id = 129, en = "First Aid", fr = "Secourisme", spell = 3273, alt = { "Premiers soins" } }, -- the French link says "Premiers soins"
    { id = 356, en = "Fishing", fr = "Pêche", spell = 7620 },
}
local profById = {}
for _, p in ipairs(PROFS) do profById[p.id] = p end
local profByName
local function ProfByName()
    if profByName then return profByName end
    profByName = {}
    for _, p in ipairs(PROFS) do
        profByName[p.en:lower()], profByName[p.fr:lower()] = p.id, p.id
        for _, a in ipairs(p.alt or {}) do profByName[a:lower()] = p.id end
        local n = W.SpellName(p.spell)
        if n then profByName[n:lower()] = p.id end
    end
    return profByName
end

-- Key of a profession: its skill line ID as text, else (a profession we do not know) its name
local function ProfKey(name, id)
    id = tonumber(id)
    if id and profById[id] then return tostring(id) end
    local found = name and ProfByName()[name:lower()]
    return found and tostring(found) or (name or "?")
end

local function ProfLabel(key)
    local p = profById[tonumber(key) or 0]
    return p and L(p.en) or key
end

local function OwnProfessions()
    local out = {}
    if GetProfessions and GetProfessionInfo then
        local idx = { GetProfessions() }
        for i = 1, 6 do
            if idx[i] then
                local name, _, rank, max, _, _, skillLine = GetProfessionInfo(idx[i])
                name = W.Safe(name)
                if name then
                    out[#out + 1] = { n = name, r = W.Safe(rank) or 0, m = W.Safe(max) or 0, id = tonumber(ProfKey(name, W.Safe(skillLine))) }
                end
            end
        end
    end
    if #out == 0 and GetNumSkillLines and GetSkillLineInfo then
        local names = ProfByName()
        for i = 1, GetNumSkillLines() do
            local name, header, _, rank, _, _, max = GetSkillLineInfo(i)
            name = W.Safe(name)
            if name and not header and names[name:lower()] then
                out[#out + 1] = { n = name, r = W.Safe(rank) or 0, m = W.Safe(max) or 0, id = names[name:lower()] }
            end
        end
    end
    return out
end

local function MyEntry()
    local key = W.UnitKey("player") or Me():lower()
    local d = Data()
    local me = d[key]
    if not me then
        me = { rec = {} }
        Store(key, W.UnitDisplayName("player") or Me(), me)
    end
    me.name = me.name or W.UnitDisplayName("player") or Me()
    me.rec = me.rec or {}
    return me
end

-- "id:skill:max;..." of a profession list: tells whether something changed
local function SkillText(list)
    local t = {}
    for _, x in ipairs(list or {}) do t[#t + 1] = (x.id or x.n) .. ":" .. (x.r or 0) .. ":" .. (x.m or 0) end
    return table.concat(t, ";")
end

-- GetProfessions() read again, plus a profession only the profession window gave before (kept)
local function MergeSkills(profs, old)
    local have = {}
    for _, x in ipairs(profs) do have[ProfKey(x.n, x.id)] = true end
    for _, x in ipairs(old or {}) do
        if not have[ProfKey(x.n, x.id)] then profs[#profs + 1] = x end
    end
    return profs
end

-- Full identity and data key of a guild member, from any name form the game gives
local function MemberKey(name)
    if not name or name == "" then return nil end
    local full
    if W.HasFullPart(name) then
        full = W.FullName(name)
    else
        local m = W.GuildMember(name) -- a bare first name: only when one member has it
        full = m and m.full or name
    end
    return full:lower(), full
end

-- A profession seen through a link (or someone's list opened from a link): the profession only, never a
-- skill level, which a link does not hold. Only for guild members; my own data comes from my game.
local function RecordLinkedProfession(name, profKey, link)
    local key, full = MemberKey(name)
    if not key or not W.GuildMember(full) then return false end
    if key == W.UnitKey("player") then return true end
    local e = Data()[key]
    if not e then
        e = {}
        Store(key, full, e)
    end
    e.lk = e.lk or {}
    e.lk[profKey] = time()
    e.lkT = time()
    if link then
        e.links = e.links or {}
        e.links[ProfLabel(profKey)] = link
    end
    return true
end

-- The profession of the open window, as Naowh Forever reads it: the child profession when it has a skill,
-- else the base one. Returns its key, name, skill and maximum (nil when the window gives none).
local function OpenProfession()
    local T = C_TradeSkillUI
    local child = T.GetChildProfessionInfo and T.GetChildProfessionInfo()
    local base = T.GetBaseProfessionInfo and T.GetBaseProfessionInfo()
    local src = (child and (W.Safe(child.maxSkillLevel) or 0) > 0) and child or base
    if not src then return nil end
    local name = W.Safe(base and base.professionName) or W.Safe(src.professionName)
    if name == "" then name = nil end
    local id = W.Safe(base and base.professionID) or W.Safe(src.professionID)
    if not name and not id then return nil end
    return ProfKey(name, id), name, W.Safe(src.skillLevel), W.Safe(src.maxSkillLevel)
end

-- Reads the open profession window: my skill and learned recipes in my own window, the profession alone
-- in someone else's (opened from their link).
-- WoW: Forever uses the modern profession API (C_TradeSkillUI, ProfessionsFrame), like Naowh Forever:
-- recipe IDs are spell IDs (Forever's new recipes have 7-digit ones, e.g. 1259342 Simple Poultice).
-- The window can switch to another profession without closing (its profession tabs, Naowh's window):
-- each profession has its own 30 s gap between two reads, not one gap for all.
local SCAN_GAP, SKILL_SEND_GAP = 30, 600
local lastScanOf, announced = {}, {}
local lastSkillSend = -SKILL_SEND_GAP
local function ScanRecipes(force)
    local T = C_TradeSkillUI
    if not T or not T.GetAllRecipeIDs then return end
    if (T.IsTradeSkillGuild and T.IsTradeSkillGuild()) or (T.IsNPCCrafting and T.IsNPCCrafting()) then return end
    local key, prof, skill, max = OpenProfession()
    if not key then return end
    if not force and lastScanOf[key] and GetTime() - lastScanOf[key] < SCAN_GAP then return end
    lastScanOf[key] = GetTime()
    if T.IsTradeSkillLinked then
        local linked, who = T.IsTradeSkillLinked()
        if linked then
            if RecordLinkedProfession(W.Safe(who), key) and G.RefreshProfs then G.RefreshProfs() end
            return true
        end
    end
    local ids = {}
    for _, id in ipairs(T.GetAllRecipeIDs() or {}) do
        local info = T.GetRecipeInfo(id)
        if info and info.learned then ids[#ids + 1] = id end
    end
    table.sort(ids)
    local me = MyEntry()
    prof = prof or ProfLabel(key)
    local recipesChanged = false
    if #ids > 0 then
        local list = table.concat(ids, ",")
        -- one list per profession, whatever the language it was saved in (compact text: a few KB per member)
        for p in pairs(me.rec) do if p ~= prof and ProfKey(p) == key then me.rec[p] = nil end end
        if me.rec[prof] ~= list then me.rec[prof] = list; recipesChanged = true end
    end
    -- the profession link (as a shift-click on the profession): the others open my recipe list with it
    if T.GetTradeSkillListLink then
        local ok, link = pcall(T.GetTradeSkillListLink)
        link = ok and W.Safe(link)
        if type(link) == "string" and link:find("|Htrade:", 1, true) then
            me.links = me.links or {}
            for p in pairs(me.links) do if p ~= prof and ProfKey(p) == key then me.links[p] = nil end end
            if me.links[prof] ~= link then me.links[prof] = link; recipesChanged = true end
        end
    end
    -- the skill as the window shows it, also for a profession GetProfessions() did not give
    local before = SkillText(me.profs)
    local profs = OwnProfessions()
    if #profs == 0 then profs = me.profs or {} end
    if skill and skill > 0 then
        local found
        for _, x in ipairs(profs) do if ProfKey(x.n, x.id) == key then found = x end end
        if not found then
            found = { n = prof, id = tonumber(key), m = 0 }
            profs[#profs + 1] = found
        end
        found.r = skill
        if max and max > 0 then found.m = max end
    end
    me.profs = profs
    me.t = time()
    local skillChanged = SkillText(profs) ~= before
    if recipesChanged or not announced[key] then
        announced[key] = #ids
        local s = skill and ((max and max > 0) and (skill .. "/" .. max) or tostring(skill)) or ""
        W.Print(string.format(L("Professions: %s %s saved (%d recipes)."), ProfLabel(key), s, #ids))
    end
    if recipesChanged or (skillChanged and GetTime() - lastSkillSend >= SKILL_SEND_GAP) then
        lastSkillSend = GetTime()
        G.Broadcast()
    end
    if G.RefreshProfs then G.RefreshProfs() end
    return true
end

local function Scan(force)
    local ok, err = pcall(ScanRecipes, force)
    if not ok then geterrorhandler()(err) end -- shown by BugSack: a silent failure is what hid this before
end
local scanPending = false
W.On("TRADE_SKILL_LIST_UPDATE", function()
    if scanPending then return end
    scanPending = true
    W.After(1, function() scanPending = false; Scan(false) end)
end)
W.On("TRADE_SKILL_SHOW", function() W.After(1.5, function() Scan(true) end) end)
W.On("TRADE_SKILL_DATA_SOURCE_CHANGED", function() W.After(1, function() Scan(true) end) end) -- another profession
W.On("NEW_RECIPE_LEARNED", function() W.After(1, function() Scan(true) end) end)

-- My skill levels can be read at any time (no window needed): kept up to date in my entry. A skill-up is
-- sent to the guild at most once every 10 minutes (it also leaves with the next recipe scan or answer).
-- A profession only the window gave (not in GetProfessions) is kept.
local skillPending = false
W.On("SKILL_LINES_CHANGED", function()
    if skillPending or not W.IsInGuild() then return end
    skillPending = true
    W.After(2, function() -- the event comes in bursts (weapon skills too): one read
        skillPending = false
        local profs = OwnProfessions()
        if #profs == 0 then return end
        local me = MyEntry()
        MergeSkills(profs, me.profs)
        if SkillText(profs) == SkillText(me.profs) then return end
        me.profs, me.t = profs, time()
        if G.RefreshProfs then G.RefreshProfs() end
        if GetTime() - lastSkillSend >= SKILL_SEND_GAP then
            lastSkillSend = GetTime()
            G.Broadcast()
        end
    end)
end)

---------------------------------------------------------------------------
-- Sync with the guild
---------------------------------------------------------------------------
local function Encode(e)
    local p = {}
    -- "name:skill:max:skillLineID" (older versions read the first three fields and skip the fourth)
    for _, x in ipairs(e.profs or {}) do p[#p + 1] = x.n .. ":" .. x.r .. ":" .. x.m .. ":" .. (x.id or 0) end
    local r = {}
    for prof, ids in pairs(e.rec or {}) do r[#r + 1] = prof .. "=" .. (type(ids) == "table" and table.concat(ids, ",") or ids) end
    -- profession links: "prof \31 link" separated by \30 (a link holds ":" ";" and "=")
    local l = {}
    for prof, link in pairs(e.links or {}) do l[#l + 1] = prof .. "\31" .. link end
    return W.Pack("D", table.concat(p, ";"), table.concat(r, ";"), table.concat(l, "\30"))
end

-- Hidden addon messages to the guild's WarLegend RaidTool users (never a chat line). Only my own data
-- (read on my game): what the roster or a link told me about others stays on my side.
function G.Broadcast()
    if not W.IsInGuild() or not (db and db.profShare) then return end
    local me = MyEntry()
    local profs = OwnProfessions()
    if #profs > 0 then me.profs = MergeSkills(profs, me.profs) end -- the client gave nothing (not ready yet): the last read stays
    me.t = me.t or time()
    W.SendLong(PREFIX, Encode(me), "GUILD")
end

local lastAsk = 0
function G.Ask()
    if not W.IsInGuild() or GetTime() - lastAsk < 60 then return end
    lastAsk = GetTime()
    W.SendLong(PREFIX, "Q", "GUILD")
end

-- The "trade:..." reference of a real profession link ("|cff......|Htrade:GUID:ids|h[name]|h|r"), nil for
-- anything else: a forged link must not reach SetItemRef with another link type.
local function TradeRef(link)
    if type(link) ~= "string" then return nil end
    return link:match("^|c%x%x%x%x%x%x%x%x|H(trade:[%w:%-]+)|h%[[^%]|]*%]|h|r$")
        or link:match("^|H(trade:[%w:%-]+)|h%[[^%]|]*%]|h$")
end

local answering, lastAnswer = false, -1000
W.OnAddonLong(PREFIX, function(msg, from, _, full)
    local who = full or from
    if W.IsMe(who) or not W.GuildMember(who) then return end -- guild members only
    local t = W.Unpack(msg)
    if t[1] == "Q" then
        -- one answer per 2 minutes at most, whoever asks: a flood of "Q" must not make the whole guild send
        if answering or GetTime() - lastAnswer < 120 then return end
        answering = true
        lastAnswer = GetTime()
        W.After(2 + math.random() * 10, function() answering = false; G.Broadcast() end)
    elseif t[1] == "D" then
        local e = { t = time(), profs = {}, rec = {}, links = {} }
        for item in (t[2] or ""):gmatch("[^;]+") do
            local n, r, m, id = item:match("^([^:]+):(%d+):(%d+):?(%d*)$")
            if n and #n <= 40 and #e.profs < 20 then
                n = W.Plain(n, 40)
                e.profs[#e.profs + 1] = { n = n, r = tonumber(r), m = tonumber(m), id = tonumber(ProfKey(n, tonumber(id))) }
            end
        end
        for prof, list in (t[3] or ""):gmatch("([^=;]+)=([%d,]+)") do
            if #prof <= 40 and #list <= 20000 then e.rec[prof] = list end -- kept as compact text
        end
        for prof, link in (t[4] or ""):gmatch("([^\30\31]+)\31([^\30]+)") do
            if #prof <= 40 and #link <= 4000 and TradeRef(link) then e.links[prof] = link end
        end
        local key, name = W.Key(who), W.FullName(who)
        -- nothing readable sent (their client gave no skill yet): what we already have from them stays
        local old = Data()[key]
        if #e.profs == 0 and old and old.profs and #old.profs > 0 then e.profs = old.profs end
        -- what the guild roster (server) and their links told me is mine, not in their message: kept
        if old then e.srv, e.srvT, e.lk, e.lkT = old.srv, old.srvT, old.lk, old.lkT end
        Store(key, name, e)
        G.RefreshProfs()
    end
end)

W.On("PLAYER_ENTERING_WORLD", function(isLogin)
    if isLogin then W.After(40, function() if W.IsInGuild() then G.Broadcast() end end) end
end)

---------------------------------------------------------------------------
-- The guild roster of the game server, as Retail's guild list reads it: C_Club member info has
-- profession1ID / profession1Rank / profession1Name and the same for profession2 (ClubDocumentation of the
-- Forever client). Main professions only, no maximum skill, and the server may leave them empty: only what
-- it really gives is saved (.srv of the member).
---------------------------------------------------------------------------
local guidNames = {} -- GUID -> full name, from the roster: tells whose a profession link is
local focusedClub

local function GuildClub()
    if not (C_Club and C_Club.GetGuildClubId and C_Club.GetClubMembers and C_Club.GetMemberInfo) then return nil end
    local ok, id = pcall(C_Club.GetGuildClubId)
    return ok and W.Safe(id) or nil
end

-- Reads every member's professions from the roster; returns how many members had one (nil: not ready yet)
function G.ReadRoster()
    local clubId = GuildClub()
    if not clubId then return nil end
    if C_Club.AreMembersReady then
        local ok, ready = pcall(C_Club.AreMembersReady, clubId)
        if not (ok and W.Safe(ready)) then
            -- as the guild window does: ask the server for the members, CLUB_MEMBERS_UPDATED follows
            if C_Club.FocusMembers and focusedClub ~= clubId and pcall(C_Club.FocusMembers, clubId) then focusedClub = clubId end
            return nil
        end
    end
    local ok, ids = pcall(C_Club.GetClubMembers, clubId)
    ids = ok and W.Safe(ids)
    if type(ids) ~= "table" then return nil end -- kept secret (chat lockdown): read again later
    local d, now, count = Data(), time(), 0
    for _, memberId in ipairs(ids) do
        local okInfo, info = pcall(C_Club.GetMemberInfo, clubId, memberId)
        if okInfo and type(info) == "table" and not W.Safe(info.isSelf) then
            local key, full = MemberKey(W.Safe(info.name))
            local guid = W.Safe(info.guid)
            if key and guid then guidNames[guid] = full end
            local list = {}
            for slot = 1, 2 do
                local id = W.Safe(info["profession" .. slot .. "ID"])
                local rank = W.Safe(info["profession" .. slot .. "Rank"])
                local pname = W.Safe(info["profession" .. slot .. "Name"])
                if type(id) == "number" and id > 0 then
                    local pk = ProfKey(pname, id)
                    list[#list + 1] = { id = tonumber(pk) or id, n = pname or ProfLabel(pk), r = (type(rank) == "number" and rank > 0) and rank or nil }
                end
            end
            local e = key and d[key]
            if key and #list > 0 then
                if not e then
                    e = {}
                    Store(key, full, e)
                end
                e.srv, e.srvT = list, now
                count = count + 1
            elseif e and e.srv then
                e.srv = nil -- the server no longer lists a profession for this member
            end
        end
    end
    return count
end

local function UnfocusRoster()
    if focusedClub and C_Club.UnfocusMembers and not (CommunitiesFrame and CommunitiesFrame:IsShown()) then
        pcall(C_Club.UnfocusMembers, focusedClub)
    end
    focusedClub = nil
end

-- the roster changes in bursts (a guild of hundreds): read once, a moment after, and only while the tab is open
local rosterPending = false
local function RosterChanged()
    if rosterPending or not (UI.profsTab and UI.profsTab:IsVisible()) then return end
    rosterPending = true
    W.After(2, function()
        rosterPending = false
        if G.ReadRoster() then G.RefreshProfs() end
    end)
end
local clubEvents = {
    W.On("CLUB_MEMBERS_UPDATED", RosterChanged, nil, true),
    W.On("CLUB_MEMBER_UPDATED", RosterChanged, nil, true),
}
local function ListenRoster(on)
    for _, h in ipairs(clubEvents) do W.Activate(h, on) end
    if not on then UnfocusRoster() end
end

---------------------------------------------------------------------------
-- Profession links: |Htrade:<owner GUID>:<profession spell>:<skill line>|h[Name]|h on Forever (as saved by the
-- game's own GetTradeSkillListLink). It names the owner and the profession: no skill level, none is guessed.
-- Shift-click one (own spellbook, chat...) while the Professions tab is open: it is saved for that member.
---------------------------------------------------------------------------
local function LinkOwner(guid)
    if guid == W.Safe(UnitGUID("player")) then return W.UnitDisplayName("player") end
    if guidNames[guid] then return guidNames[guid] end
    if GetPlayerInfoByGUID then
        local ok, _, _, _, _, _, name = pcall(GetPlayerInfoByGUID, guid)
        name = ok and W.Safe(name)
        if name and name ~= "" then return name end
    end
end

function G.ImportLink(link)
    if type(link) ~= "string" then return false end
    local guid, line = link:match("|Htrade:([^:|]+):%d+:(%d+)")
    if not guid then return false end
    local profKey = ProfKey(nil, tonumber(line))
    local owner = LinkOwner(guid)
    local _, full = MemberKey(owner)
    if not full or not W.GuildMember(full) then
        W.Print(L("This profession link belongs to nobody in the guild."))
        return false
    end
    RecordLinkedProfession(full, profKey, link)
    W.Print(string.format(L("Profession link saved: %s - %s (a link gives no skill level)."), full, ProfLabel(profKey)))
    G.RefreshProfs()
    return true
end

if hooksecurefunc and ChatEdit_InsertLink then
    hooksecurefunc("ChatEdit_InsertLink", W.Timed("hook profession link", function(link)
        if not W.Allowed() or W.IsOff("Guild") then return end
        if UI.profsTab and UI.profsTab:IsVisible() and type(link) == "string" and link:find("|Htrade:", 1, true) then
            G.ImportLink(link)
            -- the recipe box may have the focus and take the link too: a profession is not a recipe to search
            W.After(0, function()
                if UI.search and (UI.search:GetText() or ""):find("|Htrade:", 1, true) then UI.search:SetText("") end
            end)
        end
    end))
end

---------------------------------------------------------------------------
-- Recruitment
---------------------------------------------------------------------------
local function Fill(msg)
    return ((msg or ""):gsub("{guild}", GuildName() or ""):gsub("{me}", Me()))
end

function G.Post()
    local msg = Fill(db.msgs[db.sel] or "")
    if msg == "" then return end
    local chan = db.channel or ""
    local id = tonumber(chan) or (GetChannelName and GetChannelName(chan))
    if not id or id == 0 then W.Print(L("Channel not found: ") .. chan); return end
    if not W.SendChat(msg:sub(1, 255), "CHANNEL", id) then
        W.Print(L("Channel not found: ") .. chan)
        return
    end
    db.last = time()
end

-- the reminder timer only runs while the reminder is on
local ticking = false
local function Tick()
    if not db or not db.remind or not W.IsInGuild() then ticking = false; return end
    W.After(30, Tick)
    if time() - (db.last or 0) >= (db.interval or 15) * 60 and not (InCombatLockdown and InCombatLockdown()) then
        db.last = time() -- one reminder per interval, even if ignored
        W.Confirm(L("Time to post your recruitment message.") .. "\n\n|cffaaaaaa" .. Fill(db.msgs[db.sel]) .. "|r", G.Post, L("Post"))
    end
end
local function StartTick()
    if ticking or not db or not db.remind then return end
    ticking = true
    W.After(30, Tick)
end
W.On("PLAYER_LOGIN", function() W.After(30, StartTick) end)

---------------------------------------------------------------------------
-- Panel (UI is declared at the top: the roster and link code above use it)
---------------------------------------------------------------------------

function G.RefreshInactive()
    if not UI.inactive or not UI.inactive:IsVisible() then return end
    local rows = {}
    for _, m in ipairs(G.Inactive()) do
        rows[#rows + 1] = { cells = { W.ColorName(m.name, m.class), m.rank or "", m.level or "", string.format(L("%dd"), math.floor(m.days)), m.note } }
    end
    UI.inactive:SetData(rows)
    UI.count:SetText(string.format(L("%d members"), #rows))
end

local function BuildInactive(p)
    local lbl = W.Label(p, L("Offline for at least (days):"), "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT", 14, -10)
    local box = W.EditBox(p, 40, 4)
    box:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
    box:SetNumeric(true)
    box:SetScript("OnShow", function(self) self:SetText(tostring(db.inactiveDays)) end)
    box:SetScript("OnTextChanged", function(self) db.inactiveDays = tonumber(self:GetText()) or 0; G.RefreshInactive() end)
    W.Check(p, L("Hide officers"), function() return db.hideOfficers end, function(v) db.hideOfficers = v; G.RefreshInactive() end)
        :SetPoint("LEFT", box, "RIGHT", 16, 0)
    UI.count = W.Label(p, "", "GameFontNormalSmall")
    UI.count:SetPoint("TOPLEFT", 480, -10)
    W.Button(p, L("Export list"), 110, 22, function()
        local t = {}
        for _, m in ipairs(G.Inactive()) do t[#t + 1] = W.CSV(m.name, m.rank or "", math.floor(m.days)) end
        W.TextPopup(L("Inactive"), table.concat(t, "\n"), { hint = "Ctrl+C" })
    end):SetPoint("TOPRIGHT", -16, -6)
    UI.inactive = W.Table(p, { { L("Name"), 130 }, { L("Rank"), 110 }, { L("Level"), 50, "CENTER" }, { L("Offline since"), 90, "CENTER" },
        { L("Public note"), 260 } }, 460)
    UI.inactive:SetPoint("TOPLEFT", 10, -40)
    p:SetScript("OnShow", function() W.RequestGuildRoster(); G.RefreshInactive() end)
end

local recipeNames, recipeLower = {}, {}
local function RecipeName(id)
    local n = recipeNames[id]
    if not n then n = W.SpellName(id); recipeNames[id] = n end
    return n or ("#" .. id)
end

-- lowercase name, cached: the search runs on every key press over every member's recipes
local function RecipeLower(id)
    local n = recipeLower[id]
    if not n then
        n = RecipeName(id):lower()
        if recipeNames[id] then recipeLower[id] = n end -- not cached while the name is unknown
    end
    return n
end

local function Online(name)
    local g = W.GuildInfo(name)
    return g and g.online
end

-- "Who can craft X?": the recipes whose name holds the text (an item link counts as its name), each with
-- its crafters, online ones first.
local function SearchText(text)
    text = text or ""
    return (text:match("%[(.-)%]") or text):match("^%s*(.-)%s*$"):lower()
end

-- The filters of the Professions tab, all applied together:
-- prof = a profession key ("" = all), min / max = skill range (0 = no limit), name = part of a member's name
-- The first choice of the profession menu: the recipe / item view (every profession), not a profession
local RECIPE_VIEW = "*recipe"

local function Filters()
    local choice = db.profFilter or ""
    return { prof = choice == RECIPE_VIEW and "" or choice, recipeView = choice == RECIPE_VIEW,
        min = tonumber(db.profMin) or 0, max = tonumber(db.profMax) or 0,
        name = UI.nameSearch and SearchText(UI.nameSearch:GetText()) or "", online = db.profOnline and true or false }
end

---------------------------------------------------------------------------
-- One player, one entry: older versions saved the same player under other keys (the bare first name
-- "Vulcan", an old capitalized "Vulcan Wl"), so old readings showed next to new ones. Once the guild roster
-- tells who is who, they are merged under the current key, each profession keeping its most recent
-- reading, and the old keys are removed from the saved data (they do not come back after a restart).
---------------------------------------------------------------------------
local function MergeEntries(list)
    table.sort(list, function(a, b) return (a.e.t or 0) < (b.e.t or 0) end) -- oldest first: newer ones override
    local m = { profs = {}, rec = {}, links = {} }
    local skills = {} -- profession key -> { x, time }
    for _, it in ipairs(list) do
        local e = it.e
        for _, x in ipairs(e.profs or {}) do
            local pk, t = ProfKey(x.n, x.id), x.t or e.t or 0
            if not skills[pk] or t >= skills[pk].t then
                skills[pk] = { x = { n = x.n, id = x.id, r = x.r, m = x.m, t = t }, t = t }
            end
        end
        for _, field in ipairs({ "rec", "links" }) do
            for prof, v in pairs(e[field] or {}) do
                local pk = ProfKey(prof)
                for old in pairs(m[field]) do if ProfKey(old) == pk then m[field][old] = nil end end
                m[field][prof] = v
            end
        end
        if e.t and e.t > (m.t or 0) then m.t = e.t end
        if e.srv and (e.srvT or 0) >= (m.srvT or 0) then m.srv, m.srvT = e.srv, e.srvT end
        for pk, t in pairs(e.lk or {}) do
            m.lk = m.lk or {}
            if t > (m.lk[pk] or 0) then m.lk[pk] = t end
        end
        if e.lkT and e.lkT > (m.lkT or 0) then m.lkT = e.lkT end
        m.name = e.name or m.name
    end
    for _, s in pairs(skills) do m.profs[#m.profs + 1] = s.x end
    table.sort(m.profs, function(a, b) return ProfLabel(ProfKey(a.n, a.id)) < ProfLabel(ProfKey(b.n, b.id)) end)
    return m
end

function G.Consolidate()
    if not W.IsInGuild() or #W.GuildMembers() == 0 then return 0 end -- who is who needs the roster
    local d = Data()
    local groups = {}
    for key, e in pairs(d) do
        if type(e) == "table" then
            local k, full = MemberKey(EntryName(key, e))
            if k then
                groups[k] = groups[k] or { full = full, list = {} }
                table.insert(groups[k].list, { key = key, e = e })
            end
        end
    end
    local merged = 0
    for k, g in pairs(groups) do
        -- a lone first name nobody or several members have: who it is is unknown, it stays as it is
        local unknown = #g.list == 1 and not W.HasFullPart(g.full)
        if not unknown and (#g.list > 1 or g.list[1].key ~= k) then
            local m = MergeEntries(g.list)
            for _, it in ipairs(g.list) do d[it.key] = nil end
            if W.HasFullPart(g.full) then m.name = g.full end
            d[k] = m
            merged = merged + #g.list - 1
        end
    end
    return merged
end

-- Everything known about a member's professions, one entry per profession: for the skill, the most recent
-- reading wins. "wl" = shared by their WarLegend RaidTool (skill and maximum read on their game), "roster" =
-- the guild roster of the server (skill, no maximum). "link" = a profession link: the profession only, used
-- when no skill reading exists (a link is no reading of the skill).
local function Known(e)
    local best = {}
    for _, x in ipairs(e.profs or {}) do
        local pk, t = ProfKey(x.n, x.id), x.t or e.t or 0
        if not best[pk] or t > best[pk].t then best[pk] = { key = pk, r = x.r, m = x.m, src = "wl", t = t } end
    end
    for _, x in ipairs(e.srv or {}) do
        local pk, t = ProfKey(x.n, x.id), e.srvT or 0
        -- a newer roster reading replaces an older one, but an unknown rank never hides a known skill
        if not best[pk] or (x.r and t > best[pk].t) then best[pk] = { key = pk, r = x.r, src = "roster", t = t } end
    end
    for pk, t in pairs(e.lk or {}) do
        if not best[pk] then best[pk] = { key = pk, src = "link", t = t } end
    end
    local out = {}
    for _, x in pairs(best) do out[#out + 1] = x end
    return out
end

-- The member's skill in one profession, or nil
local function SkillOf(e, key)
    for _, x in ipairs(Known(e)) do
        if x.key == key then return x end
    end
end

-- an unknown skill (link) never passes a skill filter: it is not guessed
local function PassSkill(x, f)
    if f.min > 0 and not (x and x.r and x.r >= f.min) then return false end
    if f.max > 0 and not (x and x.r and x.r <= f.max) then return false end
    return true
end

local function PassName(name, f)
    return f.name == "" or name:lower():find(f.name, 1, true) ~= nil
end

-- Members who left the guild are hidden once the roster is known (their data ages out after 90 days)
local function InGuild(name, rosterKnown)
    return not rosterKnown or W.GuildMember(name) ~= nil
end

-- Number of recipes received for one profession, nil when that window was never opened by the member
local function RecipeCount(e, key)
    for prof, list in pairs(e.rec or {}) do
        if ProfKey(prof) == key then
            if type(list) == "table" then return #list end
            local _, commas = list:gsub(",", "")
            return list ~= "" and commas + 1 or 0
        end
    end
end

-- f: Filters() (optional: the chat command passes none). Result: { id, prof = key, names = {display}, keys = {data key} }
function G.FindCrafters(search, filter, f)
    f = f or { prof = filter or "", min = 0, max = 0, name = "" }
    if filter and filter ~= "" then f.prof = filter end
    local d = Data()
    local by = {}
    for key, e in pairs(d) do
        local name = EntryName(key, e)
        if PassName(name, f) and (not f.online or Online(name)) then
            for prof, list in pairs(e.rec or {}) do
                local pk = ProfKey(prof)
                if (f.prof == "" or pk == f.prof) and PassSkill(SkillOf(e, pk), f) then
                    if type(list) == "table" then list = table.concat(list, ",") end
                    for id in list:gmatch("%d+") do
                        id = tonumber(id)
                        if RecipeLower(id):find(search, 1, true) then
                            by[id] = by[id] or { prof = pk, list = {} }
                            table.insert(by[id].list, { key = key, name = name })
                        end
                    end
                end
            end
        end
    end
    local found = {}
    for id, r in pairs(by) do
        table.sort(r.list, function(a, b)
            local oa, ob = Online(a.name) and 1 or 0, Online(b.name) and 1 or 0
            if oa ~= ob then return oa > ob end
            return a.name < b.name
        end)
        local names, keys = {}, {}
        for i, c in ipairs(r.list) do names[i], keys[i] = c.name, c.key end
        found[#found + 1] = { id = id, prof = r.prof, names = names, keys = keys }
    end
    table.sort(found, function(a, b) return RecipeName(a.id) < RecipeName(b.id) end)
    return found
end

local function CrafterNames(names)
    local out = {}
    for _, n in ipairs(names) do out[#out + 1] = Online(n) and ("|cff33ff66" .. n .. "|r") or ("|cff999999" .. n .. "|r") end
    return table.concat(out, ", ")
end

-- "150/300" (green at the maximum of the current rank), "150" from the roster, "?" from a link
local function SkillCell(x)
    if not x.r then return "|cff777777?|r" end
    local r, m = x.r, x.m or 0
    local text = m > 0 and (r .. "/" .. m) or tostring(r)
    return (m > 0 and r >= m) and ("|cff33ff66" .. text .. "|r") or text
end

local SOURCE_TEXT = { wl = "|cffce1918WL|r", roster = "Roster", link = "Link" }
local function SourceCell(src)
    if src == "wl" then return SOURCE_TEXT.wl end
    return "|cffaaaaaa" .. L(SOURCE_TEXT[src] or src) .. "|r"
end

-- One row per member and profession, only from the data really received
local function MemberRows(f)
    local rows, members = {}, 0
    local rosterKnown = #W.GuildMembers() > 0
    for key, e in pairs(Data()) do
        local known = Known(e)
        local name = EntryName(key, e)
        if #known > 0 and InGuild(name, rosterKnown) then
            members = members + 1
            local g = W.GuildInfo(name)
            local online = g and g.online
            if PassName(name, f) and (not f.online or online) then
                for _, x in ipairs(known) do
                    if (f.prof == "" or x.key == f.prof) and PassSkill(x, f) then
                        local count = RecipeCount(e, x.key)
                        rows[#rows + 1] = { member = key, name = name, prof = x.key, skill = x.r or -1, max = x.m or 0, src = x.src,
                            noRecipes = count == nil, label = ProfLabel(x.key), sortName = name:lower(), online = online,
                            cells = { (online and "|cff33ff66*|r " or "  ") .. W.ColorName(name, g and g.class), ProfLabel(x.key),
                                SkillCell(x), count and tostring(count) or "|cff777777-|r", SourceCell(x.src), W.Ago(x.t) } }
                    end
                end
            end
        end
    end
    local by, desc = G.ProfSort(f)
    table.sort(rows, function(a, b) return G.ProfLess(a, b, by, desc) end)
    return rows, members
end

-- Sort of the list: the column header clicked (Name, Profession, Skill; again: the other way), saved in db.profSort.
-- Never chosen: as before, the best first for one profession, else by name. It sorts on what the cells show: the
-- name without the online mark, the profession's label in this language, the skill (then the maximum); an unknown
-- skill ("?") stays last both ways. The ties end on the name, the profession, then the data key: the same list always
-- comes in the same order (table.sort is not stable).
local SORT_KEYS = { name = true, prof = true, skill = true }
function G.ProfSort(f)
    if SORT_KEYS[db.profSort] then return db.profSort, db.profSortDesc and true or false end
    if f and f.prof ~= "" then return "skill", true end
    return "name", false
end

function G.ProfLess(a, b, by, desc)
    if by == "skill" then
        local ua, ub = a.skill < 0, b.skill < 0
        if ua ~= ub then return ub end
        if a.skill ~= b.skill then if desc then return a.skill > b.skill end return a.skill < b.skill end
        if a.max ~= b.max then if desc then return a.max > b.max end return a.max < b.max end
    elseif by == "prof" then
        if a.label ~= b.label then if desc then return a.label > b.label end return a.label < b.label end
        if a.skill ~= b.skill then return a.skill > b.skill end -- one profession: the best first, "?" last
    end
    if a.sortName ~= b.sortName then
        if by == "name" and desc then return a.sortName > b.sortName end
        return a.sortName < b.sortName
    end
    if a.label ~= b.label then return a.label < b.label end
    return a.member < b.member
end

function G.RefreshProfs()
    if not UI.profs or not UI.profsTab:IsVisible() then return end
    local f = Filters()
    local search = SearchText(UI.search:GetText())
    local rows, members = MemberRows(f)
    local recipeMode = search ~= "" or f.recipeView
    if recipeMode then
        rows = {}
        for _, r in ipairs(G.FindCrafters(search, nil, f)) do
            -- a click opens this profession of the first crafter (online ones first)
            rows[#rows + 1] = { member = r.keys[1], name = r.names[1], prof = r.prof, recipe = true,
                cells = { RecipeName(r.id), ProfLabel(r.prof), CrafterNames(r.names) } }
            if #rows >= 300 then break end
        end
        UI.recipes:SetData(rows)
    else
        UI.profs:SetSortMark(G.ProfSort(f))
        UI.profs:SetData(rows)
    end
    UI.profs:SetShown(not recipeMode)
    UI.recipes:SetShown(recipeMode)
    if not W.IsInGuild() then
        UI.empty:SetText(L("Not in a guild."))
    elseif members == 0 then
        -- nothing received yet: what to do, and why WoW needs it
        UI.empty:SetText("|cffffcc00" .. L("No profession data yet.") .. "|r\n\n"
            .. L("The game server gives no profession in the guild roster yet, and no member has shared theirs.") .. "\n\n"
            .. L("Ask the guild members to open each of their professions once, with WaR LegenD RaidTool installed (open yours too).") .. "\n\n"
            .. L("WoW only lets an addon read a player's professions from that player's own game, and the recipe list only while the profession window is open. Their addon then sends them to the guild.") .. "\n\n"
            .. L("What is received is saved: it stays after closing this window or restarting the game."))
    elseif #rows == 0 then
        UI.empty:SetText(L("No member matches these filters."))
    else
        UI.empty:SetText("")
    end
    UI.empty:SetShown(UI.empty:GetText() ~= "")
    UI.status:SetText(string.format(L("%d result(s), data from %d member(s)"), #rows, members))
end

-- "All", then the professions present in the data (and the one chosen, even when nobody has it any more)
-- The profession menu: "Recipe or item" (the recipe view), "All professions", then the 12 professions of
-- Forever by their skill line ID (names in the addon's language) and any other one found in the data
local function ProfFilterValues()
    local seen, vals = {}, {}
    local function add(key)
        if key ~= "" and key ~= RECIPE_VIEW and not seen[key] then seen[key] = true; vals[#vals + 1] = { key, ProfLabel(key) } end
    end
    for _, p in ipairs(PROFS) do add(tostring(p.id)) end
    for _, e in pairs(Data()) do
        for _, x in ipairs(Known(e)) do add(x.key) end
    end
    add(db.profFilter or "")
    table.sort(vals, function(a, b) return a[2] < b[2] end)
    table.insert(vals, 1, { "", L("All professions") })
    table.insert(vals, 1, { RECIPE_VIEW, L("Recipe or item") })
    return vals
end

local function FilterLabel(key)
    if key == RECIPE_VIEW then return L("Recipe or item") end
    if (key or "") == "" then return L("All professions") end
    return ProfLabel(key)
end

---------------------------------------------------------------------------
-- A member's profession, as a shift-click on a profession link in the chat: click = open it (the game's
-- profession window shows his recipes), shift-click = put the link in the chat box.
---------------------------------------------------------------------------
local function OpenProfessionLink(link)
    if not TradeRef(link) then return end
    if IsShiftKeyDown() and ChatEdit_InsertLink then
        ChatEdit_InsertLink(link)
        return
    end
    local ref = TradeRef(link)
    if ref and SetItemRef then pcall(SetItemRef, ref, link, "LeftButton") end
end

local linkMenu
-- member = data key, onlyProf = a profession key (links are saved under the sender's profession name)
local function MemberLinks(member, onlyProf)
    local e = member and Data()[member]
    local list = {}
    for prof, link in pairs(e and e.links or {}) do
        local key = ProfKey(prof)
        if not onlyProf or key == onlyProf then list[#list + 1] = { ProfLabel(key), link } end
    end
    table.sort(list, function(a, b) return a[1] < b[1] end)
    return list
end

local function ShowMemberLinks(member, onlyProf)
    local list = MemberLinks(member, onlyProf)
    if #list == 0 then
        local name = member and EntryName(member, Data()[member]) or "?"
        W.Print(string.format(L("No profession link from %s yet: he must open his profession once with the addon."), name))
        return
    end
    if #list == 1 then OpenProfessionLink(list[1][2]); return end
    -- several professions: a small menu at the cursor
    if not linkMenu then
        linkMenu = CreateFrame("Frame", "WLRTProfessionLinkMenu", UIParent, W.BT)
        linkMenu:SetFrameStrata("DIALOG")
        W.Backdrop(linkMenu, 0.97)
        linkMenu.buttons = {}
        tinsert(UISpecialFrames, "WLRTProfessionLinkMenu")
    end
    for i, entry in ipairs(list) do
        local b = linkMenu.buttons[i]
        if not b then
            b = W.Button(linkMenu, "", 170, 20)
            b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 22)
            linkMenu.buttons[i] = b
        end
        b:SetText(entry[1])
        b:SetScript("OnClick", function() linkMenu:Hide(); OpenProfessionLink(entry[2]) end)
        b:Show()
    end
    for i = #list + 1, #linkMenu.buttons do linkMenu.buttons[i]:Hide() end
    W.Size(linkMenu, 182, 12 + #list * 22)
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    linkMenu:ClearAllPoints()
    linkMenu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s, y / s)
    linkMenu:Show()
    W.After(8, function() if linkMenu then linkMenu:Hide() end end)
end

local function BuildProfs(p)
    UI.profsTab = p
    -- a filter saved by an older version holds the profession's name: now its key (same in every language)
    if (db.profFilter or "") ~= "" then db.profFilter = ProfKey(db.profFilter) end

    -- line 1: player name, profession, skill range (all applied together)
    local nameLbl = W.Label(p, L("Player:"), "GameFontHighlightSmall")
    nameLbl:SetPoint("TOPLEFT", 14, -10)
    UI.nameSearch = W.EditBox(p, 130, 40)
    UI.nameSearch:SetPoint("LEFT", nameLbl, "RIGHT", 8, 0)
    UI.nameSearch:SetScript("OnTextChanged", G.RefreshProfs)
    local profLbl = W.Label(p, L("Profession:"), "GameFontHighlightSmall")
    profLbl:SetPoint("LEFT", UI.nameSearch, "RIGHT", 16, 0)
    -- a drop-down menu (the game's MenuUtil, as Naowh Forever uses it); on a client without it, a click
    -- goes to the next choice
    local filterBtn
    local function Choose(key)
        db.profFilter = key
        filterBtn:SetText(FilterLabel(key))
        G.RefreshProfs()
    end
    filterBtn = W.Button(p, "", 150, 22, function(self)
        local vals = ProfFilterValues()
        if MenuUtil and MenuUtil.CreateContextMenu then
            MenuUtil.CreateContextMenu(self, function(_, root)
                for i, v in ipairs(vals) do
                    root:CreateRadio(v[2], function() return (db.profFilter or "") == v[1] end, function() Choose(v[1]) end)
                    if i == 2 and root.CreateDivider then root:CreateDivider() end
                end
            end)
            return
        end
        local idx = 1
        for i, v in ipairs(vals) do if v[1] == db.profFilter then idx = i end end
        Choose(vals[(idx % #vals) + 1][1])
    end)
    filterBtn:SetPoint("LEFT", profLbl, "RIGHT", 8, 0)
    filterBtn:SetText(FilterLabel(db.profFilter))
    local arrow = filterBtn:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    W.Size(arrow, 12, 12)
    arrow:SetPoint("RIGHT", -6, -3)
    local skillLbl = W.Label(p, L("Skill:"), "GameFontHighlightSmall")
    skillLbl:SetPoint("LEFT", filterBtn, "RIGHT", 16, 0)
    local function SkillBox(field, anchor)
        local box = W.EditBox(p, 36, 3)
        box:SetNumeric(true)
        box:SetPoint("LEFT", anchor, "RIGHT", 8, 0)
        box:SetScript("OnShow", function(self) self:SetText((db[field] or 0) > 0 and tostring(db[field]) or "") end)
        box:SetScript("OnTextChanged", function(self) db[field] = tonumber(self:GetText()) or 0; G.RefreshProfs() end)
        return box
    end
    local minBox = SkillBox("profMin", skillLbl)
    local dash = W.Label(p, "-", "GameFontHighlightSmall")
    dash:SetPoint("LEFT", minBox, "RIGHT", 6, 0)
    SkillBox("profMax", dash)
    W.Button(p, L("Ask the guild"), 130, 22, function() G.Ask(); G.Broadcast() end):SetPoint("TOPRIGHT", -16, -6)

    -- line 2: recipe search (the list then shows the recipes and who can craft them)
    local lbl = W.Label(p, L("Recipe or item:"), "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT", 14, -38)
    UI.search = W.EditBox(p, 220, 60)
    UI.search:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
    UI.search:SetScript("OnTextChanged", G.RefreshProfs)
    W.LinkTarget(UI.search) -- shift-click an item while typing: its name is searched
    local onlineCheck = W.Check(p, L("Online members only"), function() return db.profOnline end,
        function(v) db.profOnline = v; UI.profs:ScrollToTop(); G.RefreshProfs() end,
        { L("Shows only the members online now (the list and the crafters of a recipe).") })
    onlineCheck:SetPoint("LEFT", UI.search, "RIGHT", 12, 0)
    UI.status = W.Label(p, "", "GameFontNormalSmall")
    UI.status:SetPoint("LEFT", onlineCheck.label, "RIGHT", 16, 0)

    local function OnClick(d)
        if not d.member then return end
        if IsControlKeyDown() and ChatFrame_SendTell then ChatFrame_SendTell(d.name or d.member); return end
        ShowMemberLinks(d.member, d.prof)
    end
    local function OnEnter(d, row)
        if not d.member then return end
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:AddLine(d.name or d.member, 1, 1, 1)
        if d.src == "wl" then
            GameTooltip:AddLine(L("Shared by their WaR LegenD RaidTool (read on their own game)."), 0.8, 0.8, 0.8, true)
        elseif d.src == "roster" then
            GameTooltip:AddLine(L("From the guild roster (game server): main professions only, no maximum skill."), 0.8, 0.8, 0.8, true)
        elseif d.src == "link" then
            GameTooltip:AddLine(L("From a profession link: it names the profession, not the skill level."), 0.8, 0.8, 0.8, true)
        end
        if d.src and d.skill and d.skill < 0 then GameTooltip:AddLine(L("Skill unknown"), 1, 0.5, 0.3) end
        if d.noRecipes then GameTooltip:AddLine(L("Recipes not received yet: this member must open this profession once."), 1, 0.82, 0, true) end
        GameTooltip:AddLine(L("Click: open his profession. Shift-click: link it in the chat."), 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(L("Ctrl-click: whisper him."), 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end
    -- one row per member and profession; the recipe search has its own columns
    UI.profs = W.Table(p, { { L("Name"), 210, sort = "name" }, { L("Profession"), 140, sort = "prof" },
        { L("Skill"), 80, "CENTER", sort = "skill" }, { L("Recipes"), 70, "CENTER" }, { L("Source"), 70, "CENTER" },
        { L("Updated"), 70, "CENTER" } }, 370)
    UI.profs:SetPoint("TOPLEFT", 10, -64)
    UI.profs.onClick, UI.profs.onEnter = OnClick, OnEnter
    -- a header clicked: sort by it; the same one again: the other way (a skill starts with the best)
    UI.profs.onSort = function(key)
        local by, desc = G.ProfSort(Filters())
        if key == by then
            db.profSort, db.profSortDesc = key, not desc
        else
            db.profSort, db.profSortDesc = key, key == "skill"
        end
        UI.profs:ScrollToTop()
        G.RefreshProfs()
    end
    UI.recipes = W.Table(p, { { L("Recipe"), 230 }, { L("Profession"), 140 }, { L("Crafters"), 380 } }, 370)
    UI.recipes:SetPoint("TOPLEFT", 10, -64)
    UI.recipes.onClick, UI.recipes.onEnter = OnClick, OnEnter
    UI.recipes:Hide()
    -- no data / no match: what to do, over the empty list
    UI.empty = W.Label(p, "", "GameFontHighlight")
    UI.empty:SetPoint("TOP", p, "TOP", 0, -130)
    UI.empty:SetWidth(560)
    UI.empty:SetJustifyH("CENTER")
    UI.empty:Hide()

    W.Check(p, L("Share my professions with the guild's WaR LegenD RaidTool users (hidden addon messages, no chat)"),
        function() return db.profShare end, function(v) db.profShare = v end):SetPoint("BOTTOMLEFT", 10, 36)
    local h1 = W.Label(p, L("Sources: guild roster (server), the member's WaR LegenD RaidTool, profession links (Shift-click one while this tab is open)."), "GameFontDisableSmall")
    h1:SetPoint("BOTTOMLEFT", 14, 22)
    local h2 = W.Label(p, L("Open each of your professions once so the addon can read your recipes."), "GameFontDisableSmall")
    h2:SetPoint("BOTTOMLEFT", 14, 6)
    p:SetScript("OnShow", function()
        -- my own skills are readable without any window: my line is there from the first opening
        local mine = W.IsInGuild() and OwnProfessions() or {}
        if #mine > 0 then
            local me = MyEntry()
            MergeSkills(mine, me.profs)
            if SkillText(mine) ~= SkillText(me.profs) then me.profs, me.t = mine, me.t or time() end
        end
        -- the server's roster (as Retail's guild list), listened to only while this tab is open
        ListenRoster(true)
        G.ReadRoster()
        G.Consolidate() -- one entry per player (old keys merged), before anything is shown
        W.RequestGuildRoster(); G.Ask(); G.RefreshProfs()
    end)
    p:HookScript("OnHide", function() ListenRoster(false) end)
end

local function BuildRecruit(p)
    local box
    local tabs = {}
    local function sync()
        box:SetText(db.msgs[db.sel] or "")
        for i, b in ipairs(tabs) do
            W.SetSelected(b, i == db.sel)
        end
    end
    for i = 1, 3 do
        tabs[i] = W.Button(p, string.format(L("Message %d"), i), 100, 22, function() db.sel = i; sync() end)
        tabs[i]:SetPoint("TOPLEFT", 14 + (i - 1) * 104, -6)
    end
    local bg
    bg, box = W.MultiEdit(p, 640, 120, 255)
    bg:SetPoint("TOPLEFT", 14, -34)
    local count = W.Label(p, "", "GameFontDisableSmall")
    count:SetPoint("TOPRIGHT", bg, "BOTTOMRIGHT", 0, -4)
    box:SetScript("OnTextChanged", function(self)
        db.msgs[db.sel] = self:GetText()
        count:SetText(#Fill(self:GetText()) .. "/255")
    end)
    local help = W.Label(p, L("{guild} = guild name, {me} = your name. 255 characters max."), "GameFontDisableSmall")
    help:SetPoint("TOPLEFT", bg, "BOTTOMLEFT", 0, -4)
    local cl = W.Label(p, L("Channel (name or number):"), "GameFontHighlightSmall")
    cl:SetPoint("TOPLEFT", 16, -186)
    local chan = W.EditBox(p, 160, 40)
    chan:SetPoint("LEFT", cl, "RIGHT", 8, 0)
    chan:SetScript("OnShow", function(self) self:SetText(db.channel or "") end)
    chan:SetScript("OnTextChanged", function(self) db.channel = self:GetText() end)
    W.Button(p, L("Post now"), 130, 22, G.Post):SetPoint("LEFT", chan, "RIGHT", 12, 0)
    W.Check(p, L("Remind me every"), function() return db.remind end, function(v) db.remind = v; StartTick() end):SetPoint("TOPLEFT", 12, -216)
    W.Cycle(p, 80, { { 10, "10 " .. L("min") }, { 15, "15 " .. L("min") }, { 20, "20 " .. L("min") }, { 30, "30 " .. L("min") }, { 60, "60 " .. L("min") } },
        function() return db.interval end, function(v) db.interval = v end):SetPoint("TOPLEFT", 172, -216)
    p:SetScript("OnShow", sync)
end

W.RegisterModule("Guild", L("Guild"), function(p)
    W.Title(p, L("Guild"))
    -- the professions first (what the tab is opened for), the officer tools at the end
    UI.tabs = W.SubTabs(p, { L("Professions"), L("Recruitment"), L("Inactive") })
    BuildProfs(UI.tabs.frames[1])
    BuildRecruit(UI.tabs.frames[2])
    BuildInactive(UI.tabs.frames[3])
    UI.tabs:Select(1)
end, function()
    if UI.tabs then UI.tabs:Select(UI.tabs.current or 1) end
end)

-- the first roster of the session also merges old duplicate entries, tab open or not (the saved data stays clean)
local consolidated = false
W.On("GUILD_ROSTER_UPDATE", function()
    if not consolidated and db and #W.GuildMembers() > 0 then consolidated = true; G.Consolidate() end
    if W.IsShown("Guild") then G.RefreshInactive(); G.RefreshProfs() end
end)

-- /wl craft <name or item link>: who can craft it, in the chat; alone: the Professions tab
W.slash.craft = function(rest)
    local search = SearchText(rest)
    if search == "" or not db then
        if not W.IsShown("Guild") then W.Toggle("Guild") end
        if UI.tabs then UI.tabs:Select(1) end -- Professions is the first tab
        return
    end
    local found = G.FindCrafters(search, "")
    local shown = (rest or ""):match("%[(.-)%]") or (rest or ""):match("^%s*(.-)%s*$")
    if #found == 0 then W.Print(string.format(L("Nobody has a recipe named \"%s\" (only members who have the addon and opened their professions)."), shown)); return end
    W.Print(string.format(L("Who can craft \"%s\":"), shown))
    for i, r in ipairs(found) do
        if i > 8 then W.Print(string.format(L("... and %d more: see Guild > Professions."), #found - 8)); break end
        W.Print("  " .. RecipeName(r.id) .. " (" .. ProfLabel(r.prof) .. "): " .. CrafterNames(r.names))
    end
end
