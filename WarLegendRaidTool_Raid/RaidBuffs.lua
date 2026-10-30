-- WarLegend RaidTool - Raid buff assignments (L3FTools style)
-- Give each mage / priest / druid the groups they buff, each paladin a blessing; send it
-- (raid chat + a popup on the casters' screens) and check who is missing what.
local W = WLRT
W.AddFR({
    ["Raid Buffs"] = "Buffs de raid",
    ["Arcane Intellect"] = "Intelligence des arcanes",
    ["Fortitude"] = "Robustesse",
    ["Divine Spirit"] = "Esprit divin",
    ["Shadow Protection"] = "Protection contre l'ombre",
    ["Mark of the Wild"] = "Marque du fauve",
    ["Paladin blessings"] = "Bénédictions de paladin",
    ["Might"] = "Puissance",
    ["Wisdom"] = "Sagesse",
    ["Kings"] = "Rois",
    ["Salvation"] = "Salut",
    ["Light"] = "Lumière",
    ["Auto assign"] = "Répartition auto",
    ["Send assignments"] = "Envoyer les assignations",
    ["Check missing"] = "Vérifier les manquants",
    ["Report missing to raid"] = "Annoncer les manquants au raid",
    ["Clear"] = "Effacer",
    ["Nobody of this class in the raid."] = "Personne de cette classe dans le raid.",
    ["Your buffs"] = "Tes buffs",
    ["groups"] = "groupes",
    ["everyone"] = "tout le monde",
    ["Everyone has their buffs."] = "Tout le monde a ses buffs.",
    ["Buffs are hidden by the game right now (combat?)."] = "Les buffs sont cachés par le jeu pour le moment (combat ?).",
    ["missing"] = "manquant",
    ["Post the assignments in raid chat too"] = "Poster aussi les assignations dans le canal raid",
    ["Click G1..G8 to give a group to a caster. Paladins: click the blessing to change it."] =
        "Clique G1..G8 pour donner un groupe à un buffer. Paladins : clique la bénédiction pour la changer.",
})
local L = W.L

local RB = {}
W.RaidBuffs = RB
local PREFIX = "WLRT_BUFF"
local db

-- classes a buff is useless on (no mana / no attack power): never counted as missing there
local NO_MANA = { WARRIOR = true, ROGUE = true }
local CASTERS = { MAGE = true, PRIEST = true, WARLOCK = true }
-- talent = only some casters have it (never auto assigned), level = learned at that level,
-- skip = classes that do not need it, noTank = not wanted on tanks (Salvation)
-- WoW: Forever (class deep dives, Sept-Oct 2026): Divine Spirit is baseline for priests at level 30,
-- Blessing of Kings is baseline for paladins (no longer talents)
local BUFFS = {
    { key = "int", class = "MAGE", text = L("Arcane Intellect"), ids = { 1459, 1460, 1461, 10156, 10157, 23028 }, skip = NO_MANA },
    { key = "fort", class = "PRIEST", text = L("Fortitude"), ids = { 1243, 1244, 1245, 2791, 10937, 10938, 21562, 21564 } },
    { key = "spirit", class = "PRIEST", text = L("Divine Spirit"), ids = { 14752, 14818, 14819, 27841, 27681 }, level = 30, skip = NO_MANA },
    { key = "shadow", class = "PRIEST", text = L("Shadow Protection"), ids = { 976, 10957, 10958, 27683 }, level = 30 },
    { key = "motw", class = "DRUID", text = L("Mark of the Wild"), ids = { 1126, 5232, 6756, 5234, 8907, 9884, 9885, 21849, 21850 } },
}
local BLESS = {
    { key = "kings", text = L("Kings"), ids = { 20217, 25898 } },
    { key = "wisdom", text = L("Wisdom"), ids = { 19742, 19850, 19852, 19853, 19854, 25290, 25894, 25918 }, skip = NO_MANA },
    { key = "might", text = L("Might"), ids = { 19740, 19834, 19835, 19836, 19837, 19838, 25291, 25782, 25916 }, skip = CASTERS },
    { key = "salvation", text = L("Salvation"), ids = { 1038, 25895 }, level = 26, noTank = true },
    { key = "light", text = L("Light"), ids = { 19977, 19978, 19979, 25890 }, level = 40 },
}
W.TranslateField(BUFFS, "text")
W.TranslateField(BLESS, "text")
local BUFF_BY, BLESS_BY, SPELL_TO = {}, {}, {}
for _, b in ipairs(BUFFS) do BUFF_BY[b.key] = b; for _, id in ipairs(b.ids) do SPELL_TO[id] = b.key end end
for _, b in ipairs(BLESS) do BLESS_BY[b.key] = b; for _, id in ipairs(b.ids) do SPELL_TO[id] = b.key end end

W.OnReady(function()
    db = W.DB("buffs", { chat = true })
    if type(db.assign) ~= "table" then db.assign = {} end
    if type(db.bless) ~= "table" then db.bless = {} end
end)

-- Raid members: { name, class, group, unit, level, tank } - name is "First Surname" on Forever, so two
-- casters sharing a first name keep their own assignment
local function IsTank(u, rosterRole)
    if W.Safe(rosterRole) == "MAINTANK" then return true end
    return UnitGroupRolesAssigned and W.Safe(UnitGroupRolesAssigned(u)) == "TANK" or false
end

local function Members()
    local list = {}
    if W.InRaid() then
        for i = 1, W.NumRaid() do
            local _, _, group, level, _, class, _, _, _, role = GetRaidRosterInfo(i)
            local u = "raid" .. i
            local name = W.UnitDisplayName(u)
            if name then
                list[#list + 1] = { name = name, class = class, group = group or 1, unit = u, level = W.Safe(level),
                    tank = IsTank(u, role) }
            end
        end
    else
        for _, u in ipairs(W.GroupUnits()) do
            local n = W.UnitDisplayName(u)
            if n then
                list[#list + 1] = { name = n, class = W.UnitClassToken(u), group = 1, unit = u, level = W.Safe(UnitLevel(u)),
                    tank = IsTank(u) }
            end
        end
        if #list == 0 then
            list[1] = { name = W.UnitDisplayName("player") or "?", class = W.UnitClassToken("player"), group = 1, unit = "player",
                level = W.Safe(UnitLevel("player")), tank = IsTank("player") }
        end
    end
    return list
end

-- minLevel: only the casters who can have learned the spell (an unknown level is accepted)
local function Casters(class, members, minLevel)
    local out = {}
    for _, m in ipairs(members) do
        if m.class == class and not (minLevel and m.level and m.level > 0 and m.level < minLevel) then
            out[#out + 1] = m.name
        end
    end
    table.sort(out)
    return out
end

local function UsedGroups(members)
    local g = {}
    for _, m in ipairs(members) do g[m.group] = true end
    local out = {}
    for i = 1, 8 do if g[i] then out[#out + 1] = i end end
    return out
end

local function Assign(key) db.assign[key] = db.assign[key] or {}; return db.assign[key] end

function RB.AutoAssign()
    local members = Members()
    local groups = UsedGroups(members)
    for _, b in ipairs(BUFFS) do
        -- a talent buff stays as the leader set it: we cannot know who has the talent
        if not b.talent then
            local casters = Casters(b.class, members, b.level)
            local a = {}
            if #casters > 0 then
                -- groups split evenly: 1-2 to the first caster, 3-4 to the next...
                for i, g in ipairs(groups) do
                    local c = casters[math.floor((i - 1) * #casters / #groups) + 1]
                    a[c] = a[c] or {}
                    a[c][g] = true
                end
            end
            db.assign[b.key] = a
        end
    end
    -- paladins: the blessings every paladin of that level has
    local levelOf = {}
    for _, m in ipairs(members) do levelOf[m.name] = m.level end
    local auto = {}
    for _, b in ipairs(BLESS) do if not b.talent then auto[#auto + 1] = b end end
    local paladins = Casters("PALADIN", members)
    wipe(db.bless)
    for i, p in ipairs(paladins) do
        local lvl = levelOf[p]
        for k = 0, #auto - 1 do
            local b = auto[((i - 1 + k) % #auto) + 1]
            if not (b.level and lvl and lvl > 0 and lvl < b.level) then db.bless[p] = b.key; break end
        end
    end
    RB.Refresh()
end

local function GroupText(set)
    local t = {}
    for g = 1, 8 do if set[g] then t[#t + 1] = g end end
    if #t == 8 then return L("everyone") end
    return "G" .. table.concat(t, ",")
end

-- Text lines of every assignment, and each caster's own text
function RB.Lines()
    local lines, perCaster = {}, {}
    local members = Members()
    local present = {}
    for _, m in ipairs(members) do present[m.name] = true end
    for _, b in ipairs(BUFFS) do
        local parts = {}
        for caster, set in pairs(Assign(b.key)) do
            if present[caster] and next(set) then
                local gt = GroupText(set)
                parts[#parts + 1] = caster .. " " .. gt
                perCaster[caster] = (perCaster[caster] and (perCaster[caster] .. " | ") or "") .. b.text .. ": " .. gt
            end
        end
        table.sort(parts)
        if #parts > 0 then lines[#lines + 1] = b.text .. ": " .. table.concat(parts, ", ") end
    end
    local bl = {}
    for p, key in pairs(db.bless) do
        if present[p] and BLESS_BY[key] then
            bl[#bl + 1] = p .. " " .. BLESS_BY[key].text
            perCaster[p] = (perCaster[p] and (perCaster[p] .. " | ") or "") .. L("Paladin blessings") .. ": " .. BLESS_BY[key].text
        end
    end
    table.sort(bl)
    if #bl > 0 then lines[#lines + 1] = L("Paladin blessings") .. ": " .. table.concat(bl, ", ") end
    return lines, perCaster
end

function RB.Send()
    local lines, perCaster = RB.Lines()
    if db.chat and W.Channel() then W.AnnounceLines(lines, W.Channel()) end -- one a second, 255 bytes each
    for caster, text in pairs(perCaster) do W.Queue(PREFIX, W.Pack("A", caster, text)) end
end

-- Popup on the caster's screen
local popup, popupId
local function ShowBuffs(shown, mine)
    db.mine = mine
    if not popup then
        popup = W.Window("WLRTBuffPopup", 420, 90, L("Your buffs"))
        popup:SetPoint("TOP", 0, -140)
        popup.text = W.Label(popup, "", "GameFontHighlight")
        popup.text:SetPoint("TOPLEFT", 14, -38)
        popup.text:SetWidth(392)
    end
    popup.text:SetText(shown)
    popup:SetHeight(50 + popup.text:GetHeight())
    popup:Show()
    W.Print(L("Your buffs") .. ": " .. db.mine)
    popupId = (popupId or 0) + 1
    local id = popupId
    W.After(30, function() if popupId == id then popup:Hide() end end)
end

-- one popup per 10 s: a leader or assistant repeating it cannot keep it on my screen and fill my chat. What comes
-- meanwhile waits, the newest only (a corrected list sent right after the first one still arrives).
local POPUP_GAP = 10
local popupAt, popupNext = -POPUP_GAP, nil
W.OnAddon(PREFIX, function(msg, from, channel, full)
    local t = W.Unpack(msg)
    if t[1] ~= "A" or not W.IsGroupLead(full or from, channel) then return end
    if (t[2] or ""):lower() ~= (W.UnitDisplayName("player") or ""):lower() then return end
    -- the lines are separated by " | ": split first, then every line is plain text
    local lines = {}
    for line in ((t[3] or "") .. " | "):gmatch("(.-) | ") do lines[#lines + 1] = W.Plain(line, 120) end
    local shown = string.format(L("From %s"), W.Sender(from, full)) .. "\n" .. table.concat(lines, "\n")
    local mine = table.concat(lines, " | ")
    local wait = popupAt + POPUP_GAP - GetTime()
    if wait <= 0 then
        popupAt = GetTime()
        ShowBuffs(shown, mine)
        return
    end
    if not popupNext then
        W.After(wait, function()
            local n = popupNext
            popupNext, popupAt = nil, GetTime()
            ShowBuffs(n[1], n[2])
        end, "raid buffs popup")
    end
    popupNext = { shown, mine }
end)

-- A player too far (not visible, out of range) gives no aura data: unknown, never reported as missing.
-- Called through pcall: a secret value (in combat) cannot be tested, the player then counts as readable.
local function TooFar(unit)
    if UnitIsVisible and not UnitIsVisible(unit) then return true end
    if UnitInRange and unit ~= "player" then
        local inRange, checked = UnitInRange(unit)
        if checked and not inRange then return true end
    end
    return false
end

local function AuraSpellId(a) return a.spellId end

-- Who misses which buff (spell IDs, every rank)
function RB.Missing()
    if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then return nil end
    local members = Members()
    local miss = {}
    -- saved assignments outlive the raid: a caster who is not here tonight is not expected to buff
    local present = {}
    for _, m in ipairs(members) do present[m.name] = true end
    local activeBless = {}
    for p, key in pairs(db.bless) do if present[p] then activeBless[key] = p end end
    local checked, skipped = 0, 0 -- skipped: a player with an aura the game hides from addons
    for _, m in ipairs(members) do
        local ok, far = pcall(TooFar, m.unit)
        if UnitExists(m.unit) and not (ok and far) and (not UnitIsConnected or UnitIsConnected(m.unit)) and not (UnitIsDeadOrGhost and UnitIsDeadOrGhost(m.unit)) then
            local has, hidden = {}, false
            for i = 1, 40 do
                local a = W.AuraByIndex(m.unit, i, "HELPFUL") -- false: secret, refused to addons
                if a == nil then break end
                local ok, id = false, nil
                if a then ok, id = pcall(AuraSpellId, a) end
                id = ok and W.Safe(id)
                if not id then hidden = true -- an aura we cannot read could be the buff
                elseif SPELL_TO[id] then has[SPELL_TO[id]] = true end
            end
            checked = checked + 1
            if hidden then skipped = skipped + 1 end
            -- a buff the player does not need (Wisdom on a warrior, Might on a mage, Salvation on a tank)
            local function Needs(b) return not (b.skip and b.skip[m.class]) and not (b.noTank and m.tank) end
            for _, b in ipairs(hidden and {} or BUFFS) do
                local caster
                for c, set in pairs(Assign(b.key)) do if set[m.group] and present[c] then caster = c end end
                if caster and not has[b.key] and Needs(b) then
                    miss[#miss + 1] = { buff = b.text, name = m.name, group = m.group, caster = caster }
                end
            end
            for key, p in pairs(hidden and {} or activeBless) do
                if not has[key] and BLESS_BY[key] and Needs(BLESS_BY[key]) then
                    miss[#miss + 1] = { buff = BLESS_BY[key].text, name = m.name, group = m.group, caster = p }
                end
            end
        end
    end
    if checked > 0 and skipped == checked then return nil end -- every aura hidden: "hidden by the game"
    return miss
end

local function MissingLines()
    local miss = RB.Missing()
    if not miss then return nil end
    local by = {}
    local order = {}
    for _, x in ipairs(miss) do
        local k = x.buff .. " (" .. x.caster .. ")"
        if not by[k] then by[k] = {}; order[#order + 1] = k end
        table.insert(by[k], x.name)
    end
    local lines = {}
    for _, k in ipairs(order) do lines[#lines + 1] = k .. " " .. L("missing") .. ": " .. table.concat(by[k], ", ") end
    return lines
end

function RB.Check(toRaid)
    local lines = MissingLines()
    if not lines then W.Print(L("Buffs are hidden by the game right now (combat?).")); return end
    if #lines == 0 then W.Print(L("Everyone has their buffs.")); return end
    if toRaid and W.Channel() then W.AnnounceLines(lines, W.Channel()); return end -- one a second, 255 bytes each
    for _, l in ipairs(lines) do W.Print(l) end
end

-- Panel
local UI = {}
local ROW_H = 24

local function MakeRow(content)
    local r = CreateFrame("Frame", nil, content)
    r.label = W.Label(r, "", "GameFontHighlightSmall")
    r.label:SetPoint("LEFT", 8, 0)
    r.label:SetWidth(160)
    r.groups = {}
    for g = 1, 8 do
        local b = W.Button(r, "G" .. g, 38, 20, function()
            local a = Assign(r.buff)
            a[r.caster] = a[r.caster] or {}
            if a[r.caster][g] then
                a[r.caster][g] = nil
            else
                for _, set in pairs(a) do set[g] = nil end -- one caster per group
                a[r.caster][g] = true
            end
            RB.Refresh()
        end)
        b:SetPoint("LEFT", 170 + (g - 1) * 42, 0)
        r.groups[g] = b
    end
    r.bless = W.Button(r, "", 140, 20, function()
        local cur, idx = db.bless[r.caster], 0
        for i, b in ipairs(BLESS) do if b.key == cur then idx = i end end
        db.bless[r.caster] = BLESS[(idx % #BLESS) + 1].key
        RB.Refresh()
    end)
    r.bless:SetPoint("LEFT", 170, 0)
    return r
end

function RB.Refresh()
    if not UI.list or not UI.list.sf:IsVisible() then return end
    local members = Members()
    local groups = {}
    for _, g in ipairs(UsedGroups(members)) do groups[g] = true end
    local i = 0
    local function row() i = i + 1; local r = UI.list:Row(i); return r end
    local function header(text, class)
        local r = row()
        r.label:SetText(W.ColorName(W.Upper(text), class))
        for g = 1, 8 do r.groups[g]:Hide() end
        r.bless:Hide()
    end
    for _, b in ipairs(BUFFS) do
        header(b.text, b.class)
        local casters = Casters(b.class, members)
        if #casters == 0 then
            local r = row()
            r.label:SetText("|cff777777  " .. L("Nobody of this class in the raid.") .. "|r")
            for g = 1, 8 do r.groups[g]:Hide() end
            r.bless:Hide()
        end
        for _, c in ipairs(casters) do
            local r = row()
            r.buff, r.caster = b.key, c
            r.label:SetText("  " .. W.ColorName(c, b.class))
            r.bless:Hide()
            local set = Assign(b.key)[c] or {}
            for g = 1, 8 do
                local btn = r.groups[g]
                btn:Show()
                btn:SetText(set[g] and ("|cff33ff66G" .. g .. "|r") or (groups[g] and ("G" .. g) or ("|cff555555G" .. g .. "|r")))
            end
        end
    end
    header(L("Paladin blessings"), "PALADIN")
    local pals = Casters("PALADIN", members)
    if #pals == 0 then
        local r = row()
        r.label:SetText("|cff777777  " .. L("Nobody of this class in the raid.") .. "|r")
        for g = 1, 8 do r.groups[g]:Hide() end
        r.bless:Hide()
    end
    for _, p in ipairs(pals) do
        local r = row()
        r.caster = p
        r.label:SetText("  " .. W.ColorName(p, "PALADIN"))
        for g = 1, 8 do r.groups[g]:Hide() end
        local key = db.bless[p]
        r.bless:SetText(key and BLESS_BY[key] and BLESS_BY[key].text or "-")
        r.bless:Show()
    end
    UI.list:Finish(i)
end

W.RegisterModule("RaidBuffs", "Raid Buffs", function(p)
    W.Title(p, L("Raid Buffs"))
    W.Button(p, L("Auto assign"), 120, 22, RB.AutoAssign):SetPoint("TOPLEFT", 12, -34)
    W.Button(p, L("Send assignments"), 150, 22, RB.Send):SetPoint("TOPLEFT", 136, -34)
    W.Button(p, L("Check missing"), 142, 22, function() RB.Check(false) end):SetPoint("TOPLEFT", 290, -34)
    W.Button(p, L("Report missing to raid"), 190, 22, function() RB.Check(true) end):SetPoint("TOPLEFT", 438, -34)
    W.Button(p, L("Clear"), 80, 22, function() wipe(db.assign); wipe(db.bless); RB.Refresh() end):SetPoint("TOPLEFT", 634, -34)
    W.Check(p, L("Post the assignments in raid chat too"), function() return db.chat end, function(v) db.chat = v end)
        :SetPoint("TOPLEFT", 12, -60)
    local help = W.Label(p, L("Click G1..G8 to give a group to a caster. Paladins: click the blessing to change it."), "GameFontDisableSmall")
    help:SetPoint("TOPLEFT", 330, -62)
    help:SetWidth(470)
    help:SetJustifyH("LEFT")
    UI.list = W.ScrollList(p, 800, 470, ROW_H, MakeRow)
    UI.list.sf:SetPoint("TOPLEFT", 6, -90)
end, function() RB.Refresh() end) -- run at each showing of the tab (an OnShow too drew it twice)

W.OnRoster(function() if W.IsShown("RaidBuffs") then RB.Refresh() end end)
