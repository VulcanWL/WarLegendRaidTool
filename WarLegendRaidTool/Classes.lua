-- WarLegend RaidTool - Classes
-- The guild by class, from Sashoof's WarLegend v3 addon: nine cards with the members, how many are online, the class
-- leader (chosen here) and the roles the members declared. My profile (role, specialization, availability) is sent to
-- the guild (GUILD, prefix WLRT_PROFILE) when it changes and when someone opens this tab.
local W = WLRT
W.AddFR({
    ["Classes"] = "Classes",
    ["My profile"] = "Mon profil",
    ["Role:"] = "Rôle :",
    ["Spec:"] = "Spé :",
    ["Availability:"] = "Disponibilités :",
    ["None"] = "Aucun",
    ["From my talents"] = "Depuis mes talents",
    ["Share my profile with the guild"] = "Partager mon profil avec la guilde",
    ["Leader:"] = "Responsable :",
    ["%d members, %d online"] = "%d membres, %d en ligne",
    ["Declared: %s"] = "Déclarés : %s",
    ["nobody"] = "personne",
    ["Leader"] = "Responsable",
    ["e.g. evenings, weekends"] = "ex. soirs, week-ends",
    ["Your role, spec and availability are seen by the guild members who use the addon (press Enter to send). The class leaders are kept on this computer (and in the exported profiles). Hover a card for its members."] =
        "Ton rôle, ta spé et tes disponibilités sont vus par les membres de la guilde qui ont l'addon (Entrée pour envoyer). Les responsables de classe sont gardés sur cet ordinateur (et dans les profils exportés). Survole une carte pour voir ses membres.",
    ["Idea from Sashoof's WarLegend v3 addon."] = "Idée reprise de l'addon WarLegend v3 de Sashoof.",
    ["...and %d more"] = "... et %d de plus",
    ["Online members only: tick \"Show offline members\" in the guild window."] =
        "Membres en ligne seulement : coche « Afficher les membres hors ligne » dans la fenêtre de guilde.",
})
local L = W.L
local db

local PREFIX = "WLRT_PROFILE"
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local ROLES = { Tank = true, Heal = true, DPS = true }
local KEEP = 90 * 86400
local UI = { cards = {} }

local function MyKey() return W.Key(W.UnitFullName("player")) end

W.OnReady(function()
    db = W.DB("classes", { share = true })
    if type(db.leaders) ~= "table" then db.leaders = {} end
    if type(db.mine) ~= "table" then db.mine = {} end   -- my characters' profiles
    if type(db.known) ~= "table" then db.known = {} end -- guild members' profiles
    local now = time()
    for k, p in pairs(db.known) do
        if type(p) ~= "table" or type(p.t) ~= "number" or now - p.t > KEEP then db.known[k] = nil end
    end
end)

local function Mine()
    local key = MyKey()
    local p = db.mine[key]
    if type(p) ~= "table" then p = { r = "", s = "", a = "" }; db.mine[key] = p end
    return p
end

-- my declared role ("Tank", "Heal", "DPS") or nil; used by Minotaure
function W.MyRole()
    if not db then return nil end
    local r = Mine().r
    return ROLES[r] and r or nil
end

---------------------------------------------------------------------------
-- Sharing (GUILD): "1^role^spec^availability", "?" asks the others for theirs
---------------------------------------------------------------------------
local lastSend, lastAsk = -1000, -1000
local function Send(force)
    if not db.share or not W.IsInGuild() then return end
    if not force and GetTime() - lastSend < 30 then return end
    lastSend = GetTime()
    local p = Mine()
    W.Send(PREFIX, W.Pack(1, p.r, W.Plain(p.s, 30), W.Plain(p.a, 60)), "GUILD")
end

local function Ask()
    if not db.share or not W.IsInGuild() or GetTime() - lastAsk < 60 then return end
    lastAsk = GetTime()
    W.Send(PREFIX, "?", "GUILD")
end

local Refresh
local answering = false
W.OnAddon(PREFIX, function(msg, name, channel, full)
    if channel ~= "GUILD" or not db or #msg > 200 then return end
    if full == W.UnitFullName("player") then return end
    if msg == "?" then
        local p = Mine()
        if (p.r ~= "" or p.s ~= "" or p.a ~= "") and not answering then
            answering = true -- the whole guild hears "?": the answers are spread over a few seconds
            W.After(1 + math.random() * 8, function() answering = false; Send(false) end)
        end
        return
    end
    local f = W.Unpack(msg)
    if f[1] ~= "1" then return end
    local role = ROLES[f[2]] and f[2] or ""
    db.known[W.Key(full)] = { n = W.Plain(name, 40), f = W.Plain(full, 60), r = role, s = W.Plain(f[3], 30), a = W.Plain(f[4], 60), t = time() }
    if UI.panel and UI.panel:IsShown() then Refresh() end
end)

W.On("PLAYER_ENTERING_WORLD", function()
    if W.classesShared then return end
    W.classesShared = true
    local p = Mine()
    if p.r ~= "" or p.s ~= "" or p.a ~= "" then W.After(30 + math.random() * 30, function() Send(true) end) end
end)

---------------------------------------------------------------------------
-- Window tab
---------------------------------------------------------------------------
local function ClassName(token)
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]) or token
end

local function Profile(m)
    if m.full and W.Key(m.full) == MyKey() then return Mine() end
    return db.known[W.Key(m.full)]
end

local function ByClass()
    local out = {}
    for _, c in ipairs(CLASSES) do out[c] = {} end
    for _, m in ipairs(W.GuildMembers()) do
        if m.class and out[m.class] then table.insert(out[m.class], m) end
    end
    for _, list in pairs(out) do table.sort(list, function(a, b) return a.name < b.name end) end
    return out
end

local function CardTooltip(card)
    GameTooltip:SetOwner(card, "ANCHOR_RIGHT")
    GameTooltip:AddLine(W.ColorName(ClassName(card.class), card.class))
    local list = card.members or {}
    for i, m in ipairs(list) do
        if i > 30 then
            GameTooltip:AddLine(string.format(L("...and %d more"), #list - 30), 0.6, 0.6, 0.6)
            break
        end
        local p, parts = Profile(m), {}
        if p then
            for _, v in ipairs({ p.r, p.s, p.a }) do
                if v and v ~= "" then parts[#parts + 1] = v end
            end
        end
        local right = table.concat(parts, " · ")
        local leader = db.leaders[card.class] == m.full and (" |cffffd100" .. L("Leader") .. "|r") or ""
        -- "First Surname" on Forever: two members may share a first name
        GameTooltip:AddDoubleLine((W.FOREVER and m.full or m.name) .. " (" .. tostring(m.level or "?") .. ")" .. leader, right,
            m.online and 0.4 or 0.6, m.online and 1 or 0.6, m.online and 0.4 or 0.6, 0.85, 0.85, 0.85)
    end
    GameTooltip:Show()
end

local function MakeCard(p, class, i)
    local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
    local c = W.Panel(p, 262, 112)
    c:SetPoint("TOPLEFT", 12 + col * 270, -128 - row * 120)
    c.class = class
    local icon = c:CreateTexture(nil, "ARTWORK")
    W.Size(icon, 28, 28)
    icon:SetPoint("TOPLEFT", 8, -8)
    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if coords then
        icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
        icon:SetTexCoord(unpack(coords))
    end
    c.title = W.Label(c, W.ColorName(ClassName(class), class), "GameFontNormalLarge")
    c.title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    c.count = W.Label(c, "", "GameFontHighlightSmall")
    c.count:SetPoint("TOPLEFT", 10, -42)
    c.roles = W.Label(c, "", "GameFontHighlightSmall")
    c.roles:SetPoint("TOPLEFT", 10, -58)
    c.roles:SetWidth(244)
    c.roles:SetJustifyH("LEFT")
    local lbl = W.Label(c, L("Leader:"), "GameFontHighlightSmall")
    lbl:SetPoint("BOTTOMLEFT", 10, 12)
    c.values = { { "", L("None") } }
    c.leader = W.Cycle(c, 150, c.values, function() return db.leaders[class] or "" end, function(v)
        db.leaders[class] = v ~= "" and v or nil
    end)
    c.leader:SetPoint("LEFT", lbl, "RIGHT", 6, 0)
    c:EnableMouse(true)
    c:SetScript("OnEnter", CardTooltip)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return c
end

function Refresh()
    if not UI.panel then return end
    local groups = ByClass()
    for _, c in ipairs(UI.cards) do
        local list = groups[c.class]
        c.members = list
        local online, roles = 0, { Tank = 0, Heal = 0, DPS = 0 }
        wipe(c.values)
        c.values[1] = { "", L("None") }
        local leader = db.leaders[c.class]
        local leaderFound = false
        for _, m in ipairs(list) do
            if m.online then online = online + 1 end
            local p = Profile(m)
            if p and ROLES[p.r] then roles[p.r] = roles[p.r] + 1 end
            c.values[#c.values + 1] = { m.full, W.FOREVER and m.full or m.name }
            if m.full == leader then leaderFound = true end
        end
        -- a leader who left the guild stays chosen, shown by name
        if leader and not leaderFound then c.values[#c.values + 1] = { leader, W.FOREVER and leader or W.BaseName(leader) } end
        c.count:SetText(string.format(L("%d members, %d online"), #list, online))
        local parts = {}
        for _, r in ipairs({ "Tank", "Heal", "DPS" }) do
            if roles[r] > 0 then parts[#parts + 1] = r .. " " .. roles[r] end
        end
        c.roles:SetText(string.format(L("Declared: %s"), #parts > 0 and table.concat(parts, " · ") or L("nobody")))
        c.leader.Sync()
    end
    -- the Classic guild list can hold only the members online: the counts would be wrong
    local onlineOnly = GetGuildRosterShowOffline and W.Safe(GetGuildRosterShowOffline()) == false
    UI.offline:SetText(onlineOnly and L("Online members only: tick \"Show offline members\" in the guild window.") or "")
end

W.RegisterModule("Classes", "Classes", function(p)
    UI.panel = p
    W.Title(p, L("Classes"))
    local me = Mine
    local head = W.Label(p, L("My profile"), "GameFontNormal")
    head:SetPoint("TOPLEFT", 16, -42)
    local lr = W.Label(p, L("Role:"), "GameFontHighlightSmall")
    lr:SetPoint("TOPLEFT", 16, -66)
    local roleCycle = W.Cycle(p, 90, { { "", L("None") }, { "Tank", "Tank" }, { "Heal", "Heal" }, { "DPS", "DPS" } },
        function() return me().r end, function(v) me().r = v; Send(true); Refresh() end)
    roleCycle:SetPoint("LEFT", lr, "RIGHT", 6, 0)
    local ls = W.Label(p, L("Spec:"), "GameFontHighlightSmall")
    ls:SetPoint("LEFT", roleCycle, "RIGHT", 16, 0)
    local spec = W.EditBox(p, 120, 30)
    spec:SetPoint("LEFT", ls, "RIGHT", 10, 0)
    local la = W.Label(p, L("Availability:"), "GameFontHighlightSmall")
    la:SetPoint("LEFT", spec, "RIGHT", 16, 0)
    local avail = W.EditBox(p, 200, 60)
    avail:SetPoint("LEFT", la, "RIGHT", 10, 0)
    W.Tooltip(avail, L("Availability:"), { L("e.g. evenings, weekends") })
    local function Save()
        local p2 = me()
        local s = W.CutUTF8((spec:GetText() or ""):gsub("[|%c]", ""), 30)
        local a = W.CutUTF8((avail:GetText() or ""):gsub("[|%c]", ""), 60)
        if s == p2.s and a == p2.a then return end
        p2.s, p2.a = s, a
        Send(true)
    end
    spec:HookScript("OnEnterPressed", Save)
    spec:HookScript("OnEditFocusLost", Save)
    avail:HookScript("OnEnterPressed", Save)
    avail:HookScript("OnEditFocusLost", Save)
    W.Button(p, L("From my talents"), 130, 22, function()
        local t = W.TalentText(W.OwnTalents())
        if t then spec:SetText(t); Save() end
    end):SetPoint("TOPLEFT", 16, -92)
    W.Check(p, L("Share my profile with the guild"), function() return db.share end,
        function(v) db.share = v; if v then Send(true) end end):SetPoint("TOPLEFT", 160, -91)
    UI.offline = W.Label(p, "", "GameFontHighlightSmall")
    UI.offline:SetPoint("TOPRIGHT", -16, -42)
    UI.offline:SetTextColor(1, 0.6, 0.2)
    for i, class in ipairs(CLASSES) do UI.cards[i] = MakeCard(p, class, i) end
    local hint = W.Label(p, L("Your role, spec and availability are seen by the guild members who use the addon (press Enter to send). The class leaders are kept on this computer (and in the exported profiles). Hover a card for its members."),
        "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 16, -494)
    hint:SetWidth(790)
    hint:SetJustifyH("LEFT")
    W.Label(p, L("Idea from Sashoof's WarLegend v3 addon."), "GameFontDisableSmall"):SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -6)
    p:SetScript("OnShow", function()
        spec:SetText(me().s or "")
        avail:SetText(me().a or "")
        W.RequestGuildRoster()
        Ask()
        Refresh()
    end)
end, function() Refresh() end)

W.On("GUILD_ROSTER_UPDATE", function() if UI.panel and UI.panel:IsShown() then Refresh() end end)

W.slash.classes = function() W.Toggle("Classes") end
