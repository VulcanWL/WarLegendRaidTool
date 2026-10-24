-- WarLegend RaidTool - Raid Groups
-- Mark + group presets (MRT style), pre-placement from the guild,
-- auto sort by role (CC RaidTools), sharing, text export/import, announce.
local W = WLRT
local L = W.L
local RG = {}
W.RaidGroups = RG

RG.LIVE = "Current raid"
local SHARE_PREFIX = "WLRT_RG"
local EXPORT_TAG = "WLRT1:"
local db -- W.db.raidGroups

---------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------
local function InitDB()
    db = W.DB("raidGroups", { clearOthers = true, syncOnApply = false, acceptShared = true,
        poolSource = "guild", showOffline = true, sortParts = 2, sortRule = "consecutive" })
    db.presets = db.presets or {}
    db.sortGroups = db.sortGroups or { true, true, true, true, true, true, true, true }
    if db.poolSource ~= "raid" and db.poolSource ~= "guild" then db.poolSource = "guild" end
    -- old French name of the live preset
    if db.presets["Raid actuel"] then db.presets["Raid actuel"] = nil end
    if db.selected == "Raid actuel" then db.selected = nil end
    -- Import presets from the old RaidPresets addon (if still enabled)
    if not db.migrated and type(RaidPresetsDB) == "table" and type(RaidPresetsDB.presets) == "table" then
        local n = 0
        for name, p in pairs(RaidPresetsDB.presets) do
            if not db.presets[name] and type(p) == "table" and type(p.players) == "table" and not p.live then
                local copy = { players = {} }
                for _, pl in ipairs(p.players) do
                    copy.players[#copy.players + 1] = { name = pl.name, class = pl.class, group = pl.group or 1, icon = pl.icon or 0 }
                end
                db.presets[name] = copy
                n = n + 1
            end
        end
        db.migrated = true
        if n > 0 then W.Print(n .. L(" preset(s) imported from RaidPresets. You can disable RaidPresets.")) end
    end
    -- presets saved before marks were unique: the first player keeps a doubled mark
    for _, p in pairs(db.presets) do
        if type(p) == "table" and type(p.players) == "table" then RG.UniqueIcons(p) end
    end
end
W.OnReady(InitDB)

-- Names in presets: "First Surname" on WoW: Forever (many players share a first name), the name
-- without realm elsewhere (as before). Maps also answer to a first name nobody else has, so the
-- presets saved with first names keep working.
local function PName(name)
    if not name then return nil end
    return W.FOREVER and W.FullName(name) or W.BaseName(name)
end
RG.PName = PName

local function UnitPName(unit, fallback)
    if W.FOREVER then return W.UnitFullName(unit) or fallback end
    return W.BaseName(fallback or W.Safe(UnitName(unit)))
end

-- adds the "first name" aliases that point to a single entry
local function WithAliases(map)
    local short = {}
    for key, m in pairs(map) do
        local s = W.BaseName(key)
        if s ~= key then short[s] = (short[s] == nil) and m or false end
    end
    for s, m in pairs(short) do
        if m and map[s] == nil then map[s] = m end
    end
    return map
end

-- Group members: { unit, name, class, group, index }
function RG.GetMembers()
    local list = {}
    if W.InRaid() then
        for i = 1, W.NumRaid() do
            local name, _, subgroup, _, _, class = GetRaidRosterInfo(i)
            name, subgroup, class = W.Safe(name), W.Safe(subgroup), W.Safe(class)
            if name and subgroup then
                local u = W.RAID_UNITS[i]
                list[#list + 1] = { unit = u, name = UnitPName(u, name), class = class, group = subgroup, index = i }
            end
        end
    elseif W.InGroup() then
        for _, u in ipairs(W.GroupUnits()) do
            local name = W.Safe(UnitName(u))
            if name and name ~= UNKNOWNOBJECT then
                list[#list + 1] = { unit = u, name = UnitPName(u, name), class = W.UnitClassToken(u), group = 1 }
            end
        end
    end
    return list
end

function RG.MemberMap()
    local map = {}
    for _, m in ipairs(RG.GetMembers()) do map[m.name:lower()] = m end
    return WithAliases(map)
end

function RG.GuildMap()
    local map = {}
    for _, m in ipairs(W.GuildMembers()) do map[(PName(m.full or m.name) or m.name):lower()] = m end
    return WithAliases(map)
end

function RG.FindPlayer(preset, name)
    local key = name:lower()
    for i, p in ipairs(preset.players) do
        if p.name:lower() == key then return p, i end
    end
end

function RG.AddPlayer(preset, name, class, group, icon)
    name = W.SanitizeName(PName(name) or "")
    if name == "" then return nil end
    local existing = RG.FindPlayer(preset, name)
    if existing then return existing end
    local p = { name = name, class = class, group = group or 1, icon = icon or 0 }
    preset.players[#preset.players + 1] = p
    return p
end

-- "Current raid": live preset filled from the roster (like MRT)
function RG.RefreshLive(force)
    if not W.InGroup() then return false end
    local old = db.presets[RG.LIVE]
    if old and old.dirty and not force then return false end
    local preset = { players = {}, live = true }
    local members = RG.GetMembers()
    table.sort(members, function(a, b)
        if a.group ~= b.group then return a.group < b.group end
        return (a.index or 0) < (b.index or 0)
    end)
    for _, m in ipairs(members) do RG.AddPlayer(preset, m.name, m.class, m.group, W.GetMarker(m.unit)) end
    db.presets[RG.LIVE] = preset
    return true
end

function RG.SortedNames()
    local names = {}
    for name in pairs(db.presets) do
        if name ~= RG.LIVE then names[#names + 1] = name end
    end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    if db.presets[RG.LIVE] then table.insert(names, 1, RG.LIVE) end
    return names
end

function RG.UniqueName(base)
    base = W.SanitizeName(base)
    if base == "" then base = "Preset" end
    local name, n = base, 2
    while db.presets[name] do name = base .. " (" .. n .. ")"; n = n + 1 end
    return name
end

-- Saves a preset built by another module (wowaudit import) under a free name; returns that name
function RG.SavePreset(base, preset)
    local name = RG.UniqueName(base)
    db.presets[name] = preset
    if RG.Refresh then RG.Refresh() end
    return name
end

local function CopyPreset(p)
    local c = { players = {} }
    for _, pl in ipairs(p.players) do
        c.players[#c.players + 1] = { name = pl.name, class = pl.class, group = pl.group, icon = pl.icon, ma = pl.ma }
    end
    return c
end

-- A mark is on one player only (as in game): the first player holding it keeps it, the others lose it.
-- Returns how many duplicates were removed.
function RG.UniqueIcons(preset)
    local seen, fixed = {}, 0
    for _, p in ipairs(preset.players) do
        local ic = tonumber(p.icon) or 0
        if ic < 0 or ic > 8 then ic = 0 end
        if ic > 0 and seen[ic] then ic = 0; fixed = fixed + 1 end
        if ic > 0 then seen[ic] = true end
        p.icon = ic
    end
    return fixed
end

-- Gives the mark to this player and takes it from whoever had it in the preset
function RG.GiveIcon(preset, player, icon)
    if icon > 0 then
        for _, p in ipairs(preset.players) do
            if p ~= player and p.icon == icon then p.icon = 0 end
        end
    end
    player.icon = icon
end

function RG.Capture(preset)
    local members = RG.GetMembers()
    local added = 0
    for _, m in ipairs(members) do
        local p = RG.FindPlayer(preset, m.name)
        if not p then
            p = RG.AddPlayer(preset, m.name, m.class, m.group, 0)
            added = added + 1
        end
        p.class = m.class or p.class
        p.group = m.group or p.group
        local icon = W.GetMarker(m.unit)
        if icon > 0 then RG.GiveIcon(preset, p, icon) end
    end
    return #members, added
end

function RG.RemoveAbsent(preset)
    local map = RG.MemberMap()
    local kept, removed = {}, 0
    for _, p in ipairs(preset.players) do
        if map[p.name:lower()] then kept[#kept + 1] = p else removed = removed + 1 end
    end
    preset.players = kept
    return removed
end

---------------------------------------------------------------------------
-- Auto sort by role (ported from CC RaidTools)
---------------------------------------------------------------------------
local function Partition(groups, parts, rule)
    local result = {}
    for p = 1, parts do result[p] = {} end
    if rule == "alternating" then
        for i, g in ipairs(groups) do table.insert(result[((i - 1) % parts) + 1], g) end
    else
        local base, rem, idx = math.floor(#groups / parts), #groups % parts, 1
        for p = 1, parts do
            for _ = 1, base + (p <= rem and 1 or 0) do
                if groups[idx] then table.insert(result[p], groups[idx]); idx = idx + 1 end
            end
        end
    end
    return result
end

function RG.AutoSort(preset)
    local concerned = {}
    for g = 1, 8 do if db.sortGroups[g] then concerned[#concerned + 1] = g end end
    if #concerned == 0 then W.Print(L("No group checked in the sort options.")); return end

    local counts = { 0, 0, 0, 0, 0, 0, 0, 0 }
    local buckets = { TANK = {}, HEALER = {}, DAMAGER = {} }
    local map = RG.MemberMap()
    local noRole = 0
    for _, p in ipairs(preset.players) do
        if db.sortGroups[p.group or 1] then
            local m = map[p.name:lower()]
            local role = m and UnitGroupRolesAssigned and W.Safe(UnitGroupRolesAssigned(m.unit))
            -- Classic raids rarely set roles: the raid's main tanks (and the combat role) count too
            if role ~= "TANK" and role ~= "HEALER" and m and m.index then
                local _, _, _, _, _, _, _, _, _, rosterRole, _, combatRole = GetRaidRosterInfo(m.index)
                rosterRole, combatRole = W.Safe(rosterRole), W.Safe(combatRole)
                if rosterRole == "MAINTANK" or combatRole == "TANK" then role = "TANK"
                elseif combatRole == "HEALER" then role = "HEALER" end
            end
            if role ~= "TANK" and role ~= "HEALER" then
                if role ~= "DAMAGER" then noRole = noRole + 1 end
                role = "DAMAGER"
            end
            table.insert(buckets[role], p)
            p.group = nil
        else
            counts[p.group] = counts[p.group] + 1
        end
    end
    for _, list in pairs(buckets) do table.sort(list, function(a, b) return a.name < b.name end) end

    local parts = math.min(db.sortParts or 1, #concerned)
    local partList = Partition(concerned, parts, db.sortRule)
    local function Try(g, p)
        if counts[g] < 5 then p.group = g; counts[g] = counts[g] + 1; return true end
    end
    local function Overflow(p)
        for _, g in ipairs(concerned) do if Try(g, p) then return end end
        for g = 1, 8 do if Try(g, p) then return end end
        p.group = 8 -- raid full: left in G8 (flagged by the warning)
    end
    local nextPart = 1
    local function PlaceAlt(p)
        local done = false
        for i = 0, parts - 1 do
            local list = partList[((nextPart - 1 + i) % parts) + 1]
            for _, g in ipairs(list) do if Try(g, p) then done = true; break end end
            if done then break end
        end
        if not done then Overflow(p) end
        nextPart = (nextPart % parts) + 1
    end
    for _, p in ipairs(buckets.TANK) do PlaceAlt(p) end
    for _, p in ipairs(buckets.HEALER) do PlaceAlt(p) end
    for _, p in ipairs(buckets.DAMAGER) do Overflow(p) end

    W.Print(string.format(L("Auto sort: %d tank(s), %d healer(s), %d dps."), #buckets.TANK, #buckets.HEALER, #buckets.DAMAGER))
    if noRole > 0 then
        W.Print(string.format(L("%d player(s) without a role (not in the raid, or no role set): sorted as dps."), noRole))
    end
end

---------------------------------------------------------------------------
-- Applying marks
-- WoW: Forever refuses SetRaidTarget to addon code (ADDON_ACTION_FORBIDDEN, as EllesmereUI found).
-- There the marks are placed by Blizzard's /tm command, in a macro run by a secure button on the
-- player's own click (APPLY ALL, see SecureApply). The macro is written when the mouse comes over
-- the button, out of combat, never during the click itself.
---------------------------------------------------------------------------
W.AddFR({
    ["Presets"] = "Presets",
    ["Main assist "] = "Assist principal ",
    ["INV ALL"] = "INV TLM",
    ["INV ALL is reserved for the two highest guild ranks."] = "INV TLM est réservé aux deux premiers rangs de la guilde.",
    ["Invites every player of the preset who is not in the group yet."] =
        "Invite tous les joueurs du preset qui ne sont pas encore dans le groupe.",
})

W.AddFR({
    ["|cffffaa00Marks: click APPLY ALL in the Raid Groups tab (/wl). WoW: Forever only lets a click on a button place marks.|r"] =
        "|cffffaa00Marques : clique sur TOUT APPLIQUER dans l'onglet Groupes de raid (/wl). WoW: Forever ne laisse poser les marques que par un clic sur un bouton.|r",
    ["|cffffaa00Marks cannot be placed in combat: click again after the fight.|r"] =
        "|cffffaa00Impossible de poser les marques en combat : reclique après le combat.|r",
    ["|cffffaa00WoW: Forever only lets a click on a button remove marks: use the target menu (Raid Target Icon).|r"] =
        "|cffffaa00WoW: Forever ne laisse retirer les marques que par un clic sur un bouton : utilise le menu de la cible (Icône de cible).|r",
})

-- The unit's mark: 0 none, nil when the client hides it (the macro then sets / clears it anyway)
local function MarkOf(unit)
    local v = GetRaidTargetIndex(unit)
    -- GetRaidTargetIndex has SecretReturns (warcraft.wiki.gg): type() is the nil test that works on a secret
    if type(v) == "nil" then return 0 end
    return W.Safe(v)
end

-- /tm lines putting the preset's marks on the group. Clears first (a mark set elsewhere moves),
-- "!" so a mark already in place is not toggled off. One mark per player, one player per mark.
-- Returns the lines, the number of marks, the missing players.
function RG.MarkPlan(preset)
    local map = RG.MemberMap()
    local wanted, order, missing, usedIcon = {}, {}, {}, {}
    for _, p in ipairs(preset.players) do
        local ic = p.icon or 0
        if ic > 0 and not usedIcon[ic] then
            local m = map[p.name:lower()]
            if not m then
                missing[#missing + 1] = p.name
            elseif not wanted[m.unit] then
                usedIcon[ic] = true
                wanted[m.unit] = ic
                order[#order + 1] = m.unit
            end
        end
    end
    local lines = {}
    if db.clearOthers then
        for _, m in ipairs(RG.GetMembers()) do
            if not wanted[m.unit] and MarkOf(m.unit) ~= 0 then lines[#lines + 1] = "/tm [@" .. m.unit .. "] 0" end
        end
    end
    for _, unit in ipairs(order) do
        if MarkOf(unit) ~= wanted[unit] then lines[#lines + 1] = "/tm [@" .. unit .. "] !" .. wanted[unit] end
    end
    return lines, #order, missing
end

-- Direct marking (slash commands, minimap): refused on Forever, which only allows the button
function RG.ApplyMarkers(preset)
    if W.FOREVER then
        if InCombatLockdown() then
            W.Print(L("|cffffaa00Marks cannot be placed in combat: click again after the fight.|r"))
        else
            W.Print(L("|cffffaa00Marks: click APPLY ALL in the Raid Groups tab (/wl). WoW: Forever only lets a click on a button place marks.|r"))
        end
        return
    end
    if not W.InGroup() then W.Print(L("You are not in a group.")); return end
    if not W.CanLead() then W.Print(L("|cffff5555You must be leader or assistant to set marks.|r")); return end
    local map = RG.MemberMap()
    local wanted, missing, count = {}, {}, 0
    for _, p in ipairs(preset.players) do
        if p.icon and p.icon > 0 then
            local m = map[p.name:lower()]
            if m then wanted[m.unit] = p.icon else missing[#missing + 1] = p.name end
        end
    end
    if db.clearOthers then
        for _, m in pairs(map) do
            if W.GetMarker(m.unit) > 0 and not wanted[m.unit] then SetRaidTarget(m.unit, 0) end
        end
    end
    for unit, icon in pairs(wanted) do
        if W.GetMarker(unit) ~= icon then SetRaidTarget(unit, icon) end
        count = count + 1
    end
    W.Print(count .. L(" mark(s) applied."))
    if #missing > 0 then W.Print(L("|cffffaa00Missing:|r ") .. table.concat(missing, ", ")) end
end

function RG.ClearMarkers()
    if W.FOREVER then
        W.Print(L("|cffffaa00WoW: Forever only lets a click on a button remove marks: use the target menu (Raid Target Icon).|r"))
        return
    end
    if not W.InGroup() then SetRaidTarget("player", 0); return end
    for _, m in ipairs(RG.GetMembers()) do
        if W.GetMarker(m.unit) > 0 then SetRaidTarget(m.unit, 0) end
    end
    W.Print(L("Marks cleared."))
end

---------------------------------------------------------------------------
-- Applying groups (one move at a time, like CC RaidTools)
---------------------------------------------------------------------------
local mover = CreateFrame("Frame")
mover:Hide()
local state = { steps = 0, timer = 0, moved = 0 }

local function GroupStep(preset)
    local desired = {}
    for _, p in ipairs(preset.players) do
        if p.group then desired[p.name:lower()] = p.group end
    end
    local roster, counts = {}, { 0, 0, 0, 0, 0, 0, 0, 0 }
    for i = 1, W.NumRaid() do
        local name, _, sub = GetRaidRosterInfo(i)
        name, sub = W.Safe(name), W.Safe(sub)
        if name and sub then
            -- exact preset name first, then the first name (presets saved with first names)
            local key = UnitPName(W.RAID_UNITS[i], name):lower()
            roster[#roster + 1] = { index = i, group = sub, want = desired[key] or desired[W.BaseName(key)] }
            counts[sub] = counts[sub] + 1
        end
    end
    local blocked = false
    for _, r in ipairs(roster) do
        if r.want and r.want ~= r.group then
            local t = r.want
            if counts[t] < 5 then
                SetRaidSubgroup(r.index, t)
                return "moved"
            end
            local best
            for _, o in ipairs(roster) do
                if o.group == t and o.want ~= t then
                    if o.want == r.group then best = o; break end
                    best = best or o
                end
            end
            if best then
                SwapRaidSubgroup(r.index, best.index)
                return "moved"
            end
            blocked = true
        end
    end
    return blocked and "blocked" or "done"
end

local function FinishGroups(msg)
    mover:Hide()
    state.preset = nil
    W.Print(msg)
end

mover:SetScript("OnUpdate", function(_, elapsed)
    state.timer = state.timer - elapsed
    if state.timer > 0 then return end
    if not W.InRaid() then FinishGroups(L("No longer in a raid, stopped.")); return end
    if InCombatLockdown() then FinishGroups(L("|cffff5555Cannot move players in combat.|r")); return end
    if state.steps >= 120 then FinishGroups(L("|cffff5555Stopped: too many steps.|r")); return end
    state.steps = state.steps + 1
    local res = GroupStep(state.preset)
    if res == "moved" then
        state.moved = state.moved + 1
        state.timer = 1.5 -- max delay if the roster update never arrives
    elseif res == "done" then
        FinishGroups(state.moved .. L(" move(s), groups applied."))
    else
        FinishGroups(L("|cffffaa00Some players could not be placed (more than 5 in a group?).|r"))
    end
end)

function RG.ApplyGroups(preset)
    if not W.InRaid() then W.Print(L("Groups can only be applied in a raid.")); return end
    if not W.CanLead() then W.Print(L("|cffff5555You must be leader or assistant to move players.|r")); return end
    if InCombatLockdown() then W.Print(L("|cffff5555Not possible in combat.|r")); return end
    state.preset, state.steps, state.timer, state.moved = preset, 0, 0, 0
    mover:Show()
end

local function OnRoster()
    -- roster update arrived: continue sooner (without spamming the server)
    if mover:IsShown() and state.timer > 0.4 then state.timer = 0.4 end
end

---------------------------------------------------------------------------
-- Main assists + assist macros
-- /assist [@MA1,nodead][@MA2,nodead] : takes MA1's target, falls back to MA2 if MA1 is dead
---------------------------------------------------------------------------
function RG.AssistList(preset)
    local list = {}
    for _, p in ipairs(preset.players) do
        if p.ma then list[#list + 1] = p end
    end
    table.sort(list, function(a, b) return a.ma < b.ma end)
    return list
end

function RG.ToggleAssist(preset, player)
    if player.ma then
        local old = player.ma
        player.ma = nil
        for _, p in ipairs(preset.players) do
            if p.ma and p.ma > old then p.ma = p.ma - 1 end
        end
    else
        local n = #RG.AssistList(preset)
        if n >= 8 then W.Print(L("Maximum 8 main assists.")); return end
        player.ma = n + 1
    end
end

-- a name inside a macro condition: no bracket, separator or control character (presets come from shared strings)
local function MacroName(name) return (tostring(name or ""):gsub("[%c%[%];,]", "")) end

-- Macro body for a group: that group's own main assist first, then the others in order
function RG.AssistMacro(preset, group)
    local list = RG.AssistList(preset)
    if #list == 0 then return nil end
    local ordered = {}
    if group then
        for _, p in ipairs(list) do if p.group == group then ordered[#ordered + 1] = p end end
    end
    for _, p in ipairs(list) do
        if not (group and p.group == group) then ordered[#ordered + 1] = p end
    end
    local conds = {}
    for _, p in ipairs(ordered) do conds[#conds + 1] = "[@" .. MacroName(p.name) .. ",nodead]" end
    return "#showtooltip\n/assist " .. table.concat(conds)
end

function RG.AssistExportText(preset, name)
    local list = RG.AssistList(preset)
    local maNames = {}
    for _, p in ipairs(list) do maNames[#maNames + 1] = "MA" .. p.ma .. " = " .. p.name end
    local out = { "-- WaR LegenD assist macros : " .. name, "-- " .. table.concat(maNames, "  |  "), "" }
    out[#out + 1] = "== " .. L("Raid leader") .. " =="
    for _, p in ipairs(list) do out[#out + 1] = "/ma " .. p.name end
    out[#out + 1] = ""
    out[#out + 1] = "== " .. L("Everyone") .. " =="
    out[#out + 1] = RG.AssistMacro(preset)
    local used = {}
    for _, p in ipairs(preset.players) do used[p.group or 1] = true end
    for g = 1, 8 do
        if used[g] then
            out[#out + 1] = ""
            out[#out + 1] = "== " .. L("Group ") .. g .. " =="
            out[#out + 1] = RG.AssistMacro(preset, g)
        end
    end
    return table.concat(out, "\n")
end

-- Single assist macro on MA1, named "MA"
local MACRO_NAME, MACRO_ICON = "MA", 134400 -- 134400 = question mark (same as Naowh)
local macrosLoaded = false -- macros are not loaded before the first PLAYER_ENTERING_WORLD
W.On("PLAYER_ENTERING_WORLD", function() macrosLoaded = true end)

function RG.MAPlayer(preset)
    for _, p in ipairs(preset.players) do if p.ma == 1 then return p end end
    return RG.AssistList(preset)[1]
end

function RG.MAMacroBody(preset)
    local p = RG.MAPlayer(preset)
    if not p then return nil end
    return "#showtooltip\n/assist [@" .. MacroName(p.name) .. ",nodead]"
end

local function MacroRange()
    local mc = Constants and Constants.MacroConsts
    local maxAccount = (mc and mc.MAX_ACCOUNT_MACROS) or MAX_ACCOUNT_MACROS or 120
    local maxCharacter = (mc and mc.MAX_CHARACTER_MACROS) or MAX_CHARACTER_MACROS or 18
    return maxAccount, maxCharacter
end

-- Same flow as NaowhForever_Macros (Library.Add): combat check, already have, name taken, room, CreateMacro(..., true)
function RG.CreateMyAssistMacro(preset)
    if InCombatLockdown() then W.Print(L("|cffff5555Not possible in combat.|r")); return end
    if not macrosLoaded then W.Print(L("Macros are not loaded yet, try again in a moment.")); return end
    local body = RG.MAMacroBody(preset)
    if not body then W.Print(L("No main assist in this preset (Alt-click a player).")); return end
    local maxAccount, maxCharacter = MacroRange()
    -- already have it? (character macros only)
    for i = maxAccount + 1, maxAccount + maxCharacter do
        local n, _, b = GetMacroInfo(i)
        if n == MACRO_NAME and b and b:gsub("%s+$", "") == body then
            W.Print(string.format(L("You already have the macro \"%s\"."), MACRO_NAME)); return
        end
    end
    local idx = GetMacroIndexByName(MACRO_NAME) or 0
    if idx > maxAccount then -- our character macro with an old target: update it
        EditMacro(idx, MACRO_NAME, nil, body)
        W.Print(string.format(L("Macro \"%s\" updated (/macro)."), MACRO_NAME)); return
    elseif idx > 0 then
        W.Print(string.format(L("|cffff5555An account macro is already named \"%s\".|r"), MACRO_NAME)); return
    end
    local _, characterCount = GetNumMacros()
    if characterCount >= maxCharacter then W.Print(L("|cffff5555Your character macros are full.|r")); return end
    CreateMacro(MACRO_NAME, MACRO_ICON, body, true)
    W.Print(string.format(L("Macro \"%s\" added to your character macros (/macro)."), MACRO_NAME))
end

function RG.ExportAssist(preset, name)
    local body = RG.MAMacroBody(preset)
    if not body then W.Print(L("No main assist in this preset (Alt-click a player).")); return end
    W.TextPopup("MA", body, {
        hint = L("Assist on the main assist. Ctrl+C to copy."),
        extraText = L("Create macro"),
        onExtra = function() RG.CreateMyAssistMacro(preset) end,
    })
end

-- Forever: SetPartyAssignment is refused to addon code too, Blizzard's secure /mainassist command
-- does it from the APPLY ALL macro. Adds those lines (raid only) to `lines`.
function RG.AssistLines(preset, lines)
    if not W.InRaid() then return lines end
    local cmd = SLASH_MAINASSISTON1 or "/mainassist"
    local map = RG.MemberMap()
    for _, p in ipairs(RG.AssistList(preset)) do
        local m = map[p.name:lower()]
        if m then lines[#lines + 1] = cmd .. " " .. m.unit end
    end
    return lines
end

-- Raid leader: gives the main assist role in the raid (/ma) to the preset's MAs
function RG.ApplyAssists(preset)
    if W.FOREVER then return end -- done by the APPLY ALL macro (RG.AssistLines)
    if not W.InRaid() or not W.CanLead() or not SetPartyAssignment then return end
    local map = RG.MemberMap()
    for _, p in ipairs(RG.AssistList(preset)) do
        local m = map[p.name:lower()]
        if m then pcall(SetPartyAssignment, "MAINASSIST", m.unit) end
    end
end

-- marksDone: the APPLY ALL secure button already placed the marks on this click
function RG.ApplyAll(preset, name, marksDone)
    if not marksDone then RG.ApplyMarkers(preset) end
    RG.ApplyAssists(preset)
    if W.InRaid() then RG.ApplyGroups(preset) end
    if db.syncOnApply then RG.Share(name) end
end

function W.ApplySelectedPreset()
    local name = db and db.selected
    local preset = name and db.presets[name]
    if preset then RG.ApplyAll(preset, name) else W.Print(L("No preset selected.")) end
end

---------------------------------------------------------------------------
-- Announce, share, export / import
---------------------------------------------------------------------------
function RG.Announce(preset, name)
    local channel = W.Channel()
    if not channel then W.Print(L("You are not in a group.")); return end
    W.Announce("[WaR LegenD] " .. (preset.live and L(name) or name), channel)
    -- main assists first: "Assist: MA1 Thrall > MA2 Jaina"
    local mas = RG.AssistList(preset)
    if #mas > 0 then
        local parts = {}
        for _, p in ipairs(mas) do
            parts[#parts + 1] = "MA" .. p.ma .. " " .. p.name .. ((p.icon and p.icon > 0) and (" {rt" .. p.icon .. "}") or "")
        end
        W.Announce("Assist: " .. table.concat(parts, " > "), channel)
    end
    local line = ""
    for icon = 1, 8 do
        for _, p in ipairs(preset.players) do
            if p.icon == icon then
                local seg = "{rt" .. icon .. "} " .. p.name .. "  "
                if #line + #seg > 240 then W.Announce(line, channel); line = "" end
                line = line .. seg
            end
        end
    end
    if line ~= "" then W.Announce(line, channel) end
end

function RG.Serialize(name, preset)
    local parts = { name }
    for _, p in ipairs(preset.players) do
        parts[#parts + 1] = string.format("%s,%s,%d,%d,%d", p.name, p.class or "", p.group or 1, p.icon or 0, p.ma or 0)
    end
    return table.concat(parts, ";")
end

-- A shared or pasted string comes from someone else: the preset name is shown in the confirmation and the lists,
-- so no escape sequence ("|" textures, colors, links) and no control character; the class is a class token only;
-- a raid holds 40 players.
function RG.Deserialize(str)
    local name, preset = nil, { players = {} }
    for chunk in string.gmatch(str or "", "[^;]+") do
        if not name then
            name = chunk:gsub("[%c|]", ""):sub(1, 40)
            if name:match("^%s*$") then name = "Preset" end
        elseif #preset.players < 40 then
            local n, c, g, i, ma = strsplit(",", chunk)
            n = n and W.SanitizeName(n)
            if n and n ~= "" and n ~= "#boss" then
                g = tonumber(g) or 1
                if g ~= g or g < 1 or g > 8 or g % 1 ~= 0 then g = 1 end -- g ~= g: NaN
                i = tonumber(i) or 0
                if i < 0 or i > 8 or i % 1 ~= 0 then i = 0 end
                c = (c and #c <= 12 and c:match("^%u+$")) and c or nil
                preset.players[#preset.players + 1] = {
                    name = n, class = c, group = g, icon = i,
                    -- 5th field = main assist number (old RaidPresets strings had x,y floats here)
                    ma = (ma and ma:match("^[1-8]$")) and tonumber(ma) or nil }
            end
        end
    end
    if not name then return nil end
    RG.UniqueIcons(preset) -- shared / pasted strings may give a mark twice
    return name, preset
end

local sendQueue = {}
local MAX_SEND_QUEUE = 200 -- fragments waiting to be sent (a preset is at most 50)
W.AddFR({
    ["Preset sharing is still in progress: wait a few seconds."] = "Le partage des presets est encore en cours : attends quelques secondes.",
    ["The preset could not be sent to the group."] = "Le preset n'a pas pu être envoyé au groupe.",
})
local sender = CreateFrame("Frame")
sender:Hide()
local sendTimer = 0
sender:SetScript("OnUpdate", function(self, elapsed)
    sendTimer = sendTimer - elapsed
    if sendTimer > 0 then return end
    local item = sendQueue[1]
    if not item then self:Hide(); return end
    -- the fragment leaves the queue only once the client took it: a throttle or a chat lockdown retries it later
    local res = W.SendRaw(SHARE_PREFIX, item.msg, item.channel)
    -- a lockdown lasts the whole boss encounter: it does not count, only a throttle that never ends does
    if res == "locked" then sendTimer = 3; return end
    if res == "throttle" then
        item.tries = (item.tries or 0) + 1
        if item.tries < 60 then sendTimer = 1; return end
        res = "gave up"
    end
    if res == "sent" then
        table.remove(sendQueue, 1)
        sendTimer = 0.15
    else
        -- the rest of this preset is useless without that fragment (left the group...): drop the queue and say so
        wipe(sendQueue)
        W.Print(L("The preset could not be sent to the group."))
        self:Hide()
    end
end)

function RG.Share(name)
    local preset = db.presets[name]
    if not preset then return end
    local channel = W.Channel()
    if not channel then W.Print(L("You are not in a group.")); return end
    -- compressed then Base64 (safe on the addon channel): about 6 times fewer fragments
    local EU = C_EncodingUtil
    local ok, data = pcall(function() return EU.EncodeBase64(EU.CompressString(RG.Serialize(name, preset))) end)
    if not ok or type(data) ~= "string" or data == "" then W.Print(L("Compression is not available: the preset was not sent.")); return end
    local size = 200
    local total = math.ceil(#data / size)
    if #sendQueue + total > MAX_SEND_QUEUE then W.Print(L("Preset sharing is still in progress: wait a few seconds.")); return end
    local id = tostring(math.random(10000, 99999))
    for i = 1, total do
        sendQueue[#sendQueue + 1] = { msg = "Z:" .. id .. ":" .. i .. ":" .. total .. ":" .. data:sub((i - 1) * size + 1, i * size), channel = channel }
    end
    sender:Show()
    W.Print("Preset \"" .. name .. L("\" shared with the group."))
end

local incoming = {}
-- Shared presets: only from the group leader / an assistant, and saved after I say yes.
-- Unfinished transfers are dropped after a minute; the number of saved presets is capped.
local MAX_PRESETS, TRANSFER_TTL = 100, 60
local MAX_PLAIN = 20000 -- decompressed size refused above this (a real preset is far smaller)
W.AddFR({
    ["Compression is not available: the preset was not sent."] = "Compression indisponible : le preset n'a pas été envoyé.",
    ["%s shares the preset \"%s\". Save it?"] = "%s partage le preset « %s ». L'enregistrer ?",
    ["Too many presets saved: delete some to receive new ones."] = "Trop de presets enregistrés : supprime-en pour en recevoir de nouveaux.",
})

W.OnAddon(SHARE_PREFIX, function(msg, from, channel, full)
    if not db or W.IsMe(full or from) or not db.acceptShared then return end
    if not W.IsGroupLead(full or from, channel) then return end
    local id, i, total, payload = msg:match("^Z:(%d+):(%d+):(%d+):(.*)$")
    if not id then return end
    i, total = tonumber(i), tonumber(total)
    if not i or not total or i < 1 or i > total or total > 50 then return end
    local now = GetTime()
    for k, old in pairs(incoming) do
        if now - (old.at or now) > TRANSFER_TTL then incoming[k] = nil end
    end
    local key = (full or from) .. id
    local buf = incoming[key]
    if not buf then buf = { n = 0, parts = {}, total = total, at = now }; incoming[key] = buf end
    if buf.total ~= total then return end
    if not buf.parts[i] then buf.parts[i] = payload; buf.n = buf.n + 1 end
    if buf.n < total then return end
    incoming[key] = nil
    local EU = C_EncodingUtil
    if not EU then return end
    local ok, plain = pcall(function() return EU.DecompressString(EU.DecodeBase64(table.concat(buf.parts, "", 1, total))) end)
    if not ok or type(plain) ~= "string" or #plain > MAX_PLAIN then return end
    local name, preset = RG.Deserialize(plain)
    if not name then return end
    local count = 0
    for _ in pairs(db.presets) do count = count + 1 end
    if count >= MAX_PRESETS then W.Print(L("Too many presets saved: delete some to receive new ones.")); return end
    W.Confirm(string.format(L("%s shares the preset \"%s\". Save it?"), from, name), function()
        local newName = RG.UniqueName(name .. " (" .. from .. ")")
        preset.received = from
        db.presets[newName] = preset
        W.Print(L("Preset received from |cffffff00") .. from .. "|r: \"" .. newName .. L("\" (/wl to view it)"))
        if RG.Refresh then RG.Refresh() end
    end)
end)

function RG.Export(name)
    local preset = db.presets[name]
    if not preset or #preset.players == 0 then W.Print(L("Preset is empty, nothing to export.")); return end
    W.TextPopup(L("Export \"") .. name .. "\"", EXPORT_TAG .. RG.Serialize(name, preset),
        { hint = L("Ctrl+C to copy, then paste it wherever you want.") })
end

function RG.Import()
    W.TextPopup(L("Import a preset"), "", {
        showName = true, hint = L("Paste a WaR LegenD (or RaidPresets) string."),
        onConfirm = function(text, wanted)
            text = (text or ""):gsub("%s+", "")
            if text:sub(1, #EXPORT_TAG) == EXPORT_TAG then text = text:sub(#EXPORT_TAG + 1) end
            local name, preset = RG.Deserialize(text)
            if not name or #preset.players == 0 then return L("Invalid or unreadable string.") end
            local final = RG.UniqueName((wanted and W.SanitizeName(wanted) ~= "") and wanted or name)
            db.presets[final] = preset
            db.selected = final
            W.Print("Preset \"" .. final .. L("\" imported."))
            if RG.Refresh then RG.Refresh() end
        end,
    })
end

---------------------------------------------------------------------------
-- Interface
---------------------------------------------------------------------------
local UI = {}

local function Current()
    local name = db and db.selected
    return name and db.presets[name], name
end

local function NeedPreset()
    local preset, name = Current()
    if not preset then W.Print(L("Select or create a preset first.")) end
    return preset, name
end

local function Changed()
    local preset = Current()
    if preset then preset.dirty = true end
    RG.Refresh()
end

-- Next / previous mark, skipping the marks other players of the preset already have
local function CycleIcon(p, dir)
    local preset = Current()
    local used = {}
    if preset then
        for _, o in ipairs(preset.players) do
            if o ~= p and o.icon and o.icon > 0 then used[o.icon] = true end
        end
    end
    local ic = p.icon or 0
    for _ = 1, 9 do
        ic = (ic + dir) % 9
        if ic == 0 or not used[ic] then break end
    end
    p.icon = ic
end

-- Drag and drop
local function StartDrag(info, name, class)
    UI.dragInfo = info
    UI.drag.text:SetText(name)
    UI.drag.text:SetTextColor(W.ClassColor(class))
    UI.drag:Show()
end

local function DropOnSlot(info, slot)
    local preset = Current()
    if not preset then return end
    local players, target = preset.players, slot.data
    if info.player then
        local a = info.player
        if a == target then return end
        local _, ia = RG.FindPlayer(preset, a.name)
        if target then
            local _, ib = RG.FindPlayer(preset, target.name)
            a.group, target.group = target.group, a.group
            players[ia], players[ib] = players[ib], players[ia]
        else
            table.remove(players, ia)
            a.group = slot.group
            players[#players + 1] = a
        end
    elseif info.member then
        local m = info.member
        if RG.FindPlayer(preset, m.name) then return end
        local p = RG.AddPlayer(preset, m.full or m.name, m.class, slot.group, m.unit and W.GetMarker(m.unit) or 0)
        if p and target then
            local _, ib = RG.FindPlayer(preset, target.name)
            table.remove(players, #players)
            players[ib] = p -- the replaced player goes back to "not in preset"
        end
    end
end

local function StopDrag()
    local info = UI.dragInfo
    UI.dragInfo = nil
    UI.drag:Hide()
    if not info then return end
    for _, slot in ipairs(UI.slots) do
        if slot:IsMouseOver() then DropOnSlot(info, slot); Changed(); return end
    end
    if info.player and UI.freePanel:IsMouseOver() then
        local preset = Current()
        local _, idx = RG.FindPlayer(preset, info.player.name)
        if idx then table.remove(preset.players, idx) end
        Changed()
    end
end

StaticPopupDialogs["WLRT_DELETE_PRESET"] = {
    text = L("Delete preset \"%s\"?"),
    button1 = YES or L("Yes"), button2 = NO or L("No"),
    OnAccept = function()
        if UI.pendingDelete then
            db.presets[UI.pendingDelete] = nil
            if db.selected == UI.pendingDelete then db.selected = nil end
            UI.pendingDelete = nil
            RG.Refresh()
        end
    end,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
}
W.TranslateField({ StaticPopupDialogs["WLRT_DELETE_PRESET"] }, "text")

-- Presets panel
local function BuildPresetPanel(parent)
    local p = W.Panel(parent, 190, 540)
    p:SetPoint("TOPLEFT", 0, 0)
    W.Label(p, L("Presets")):SetPoint("TOPLEFT", 10, -8)

    UI.presetList = W.ScrollList(p, 150, 300, 20, function(content)
        local r = CreateFrame("Button", nil, content)
        r.sel = r:CreateTexture(nil, "BACKGROUND")
        r.sel:SetAllPoints()
        W.SetColor(r.sel, W.R, W.G, W.B, 0.35)
        r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        r.text = W.Label(r, "", "GameFontHighlight")
        r.text:SetPoint("LEFT", 4, 0)
        r.text:SetPoint("RIGHT", -2, 0)
        r:SetScript("OnClick", function(self) db.selected = self.presetName; RG.Refresh() end)
        return r
    end)
    UI.presetList.sf:SetPoint("TOPLEFT", 8, -26)

    local box = W.EditBox(p, 160)
    box:SetPoint("TOPLEFT", 16, -336)
    UI.nameBox = box
    local function boxText() return W.SanitizeName(box:GetText()) end

    W.Button(p, L("New"), 85, 22, function()
        local name = RG.UniqueName(boxText() ~= "" and boxText() or "Preset")
        db.presets[name] = { players = {} }
        db.selected = name
        RG.Refresh()
    end, { L("Creates an empty preset (name taken from the field).") }):SetPoint("TOPLEFT", 8, -360)

    W.Button(p, L("Rename"), 85, 22, function()
        local preset, cur = NeedPreset()
        if not preset then return end
        local new = boxText()
        if new == "" or new == cur then return end
        if db.presets[new] then W.Print(L("A preset with this name already exists.")); return end
        db.presets[new], db.presets[cur] = preset, nil
        preset.live, preset.dirty = nil, nil
        db.selected = new
        RG.Refresh()
    end, { L("Renames the selected preset using the field text.") }):SetPoint("TOPLEFT", 97, -360)

    W.Button(p, L("Save"), 85, 22, function()
        local preset, cur = NeedPreset()
        if not preset then return end
        local name = RG.UniqueName(boxText() ~= "" and boxText() or (cur .. L(" copy")))
        db.presets[name] = CopyPreset(preset)
        db.selected = name
        W.Print("Preset \"" .. name .. L("\" saved."))
        RG.Refresh()
    end, { L("Saves a copy of the displayed preset under the field name."),
        L("E.g. arrange \"Current raid\", type a name, then Save.") }):SetPoint("TOPLEFT", 8, -386)

    W.Button(p, L("Delete"), 85, 22, function()
        local _, cur = NeedPreset()
        if not cur then return end
        UI.pendingDelete = cur
        StaticPopup_Show("WLRT_DELETE_PRESET", cur)
    end):SetPoint("TOPLEFT", 97, -386)

    W.Button(p, L("Export"), 85, 22, function()
        local _, cur = NeedPreset()
        if cur then RG.Export(cur) end
    end, { L("Text to copy/paste (Discord, another player...).") }):SetPoint("TOPLEFT", 8, -412)

    W.Button(p, L("Import"), 85, 22, RG.Import, { L("Paste an exported string to create a preset.") })
        :SetPoint("TOPLEFT", 97, -412)

    W.Button(p, L("Reload current raid"), 174, 22, function()
        if not W.InGroup() then W.Print(L("You are not in a group.")); return end
        RG.RefreshLive(true)
        db.selected = RG.LIVE
        RG.Refresh()
    end, { L("Refills \"Current raid\" with the raid's groups and marks (discards unsaved changes).") })
        :SetPoint("TOPLEFT", 8, -442)

    UI.presetInfo = W.Label(p, "", "GameFontHighlightSmall")
    UI.presetInfo:SetPoint("TOPLEFT", 10, -474)
    UI.presetInfo:SetWidth(170)
end

local function RefreshPresets()
    local names = RG.SortedNames()
    for i, name in ipairs(names) do
        local r = UI.presetList:Row(i)
        r.presetName = name
        local preset = db.presets[name]
        if preset.live then
            r.text:SetText("|cff55ff55>|r " .. L(RG.LIVE) .. (preset.dirty and " |cffffaa00*|r" or ""))
            r.text:SetTextColor(0.6, 1, 0.6)
        else
            r.text:SetText(name)
            if preset.received then r.text:SetTextColor(0.6, 0.9, 1) else r.text:SetTextColor(1, 1, 1) end
        end
        if name == db.selected then r.sel:Show() else r.sel:Hide() end
    end
    UI.presetList:Finish(#names)

    local preset, name = Current()
    if preset then
        if not UI.nameBox:HasFocus() then UI.nameBox:SetText(preset.live and "" or name) end
        local txt = #preset.players .. L(" player(s)")
        if preset.live then txt = txt .. L("\n|cff55ff55Live roster|r") .. (preset.dirty and L(" |cffffaa00(modified)|r") or "") end
        if preset.received then txt = txt .. L("\n|cff99ddffReceived from ") .. preset.received .. "|r" end
        UI.presetInfo:SetText(txt)
    else
        UI.presetInfo:SetText(L("|cff999999No preset selected.|r"))
    end
end

-- 8 groups x 5 slots panel
local SLOT_W, SLOT_H = 158, 19

local function MakeSlot(parent, g)
    local s = CreateFrame("Button", nil, parent)
    W.Size(s, SLOT_W, SLOT_H)
    s.group = g
    s.bg = s:CreateTexture(nil, "BACKGROUND")
    s.bg:SetAllPoints()
    W.SetColor(s.bg, 1, 1, 1, 0.05)
    s:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    s.icon = CreateFrame("Button", nil, s)
    W.Size(s.icon, 16, 16)
    s.icon:SetPoint("LEFT", 2, 0)
    s.icon:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    s.icon.tex = s.icon:CreateTexture(nil, "ARTWORK")
    s.icon.tex:SetAllPoints()
    s.icon.empty = s.icon:CreateTexture(nil, "BACKGROUND")
    s.icon.empty:SetAllPoints()
    W.SetColor(s.icon.empty, 1, 1, 1, 0.1)
    s.icon:SetScript("OnClick", function(self, btn)
        local d = self:GetParent().data
        if not d then return end
        CycleIcon(d, btn == "RightButton" and -1 or 1)
        Changed()
    end)
    W.Tooltip(s.icon, function(self)
        local d = self:GetParent().data
        local ic = d and d.icon or 0
        return ic > 0 and W.ICON_NAMES[ic] or L("No mark")
    end, { L("Left-click: next mark"), L("Right-click: previous mark") })

    s.text = W.Label(s, "", "GameFontHighlightSmall")
    s.text:SetPoint("LEFT", 21, 0)
    s.text:SetPoint("RIGHT", -2, 0)

    s:RegisterForDrag("LeftButton")
    s:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    s:SetScript("OnDragStart", function(self)
        if self.data then StartDrag({ player = self.data }, self.data.name, self.data.class) end
    end)
    s:SetScript("OnDragStop", StopDrag)
    s:SetScript("OnClick", function(self, btn)
        if btn == "LeftButton" and IsAltKeyDown() and self.data then
            RG.ToggleAssist(Current(), self.data)
            Changed()
        elseif btn == "RightButton" and self.data then
            local preset = Current()
            local _, idx = RG.FindPlayer(preset, self.data.name)
            if idx then table.remove(preset.players, idx) end
            Changed()
        end
    end)
    s:SetScript("OnEnter", function(self)
        if not self.data then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.data.name, W.ClassColor(self.data.class))
        GameTooltip:AddLine(L("Drag: move / swap"), 0.8, 0.8, 0.8)
        if self.data.ma then GameTooltip:AddLine(L("Main assist ") .. self.data.ma, W.R, W.G + 0.3, W.B + 0.3) end
        GameTooltip:AddLine(L("Alt-click: set / remove main assist"), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L("Right-click: remove from preset"), 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    s:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return s
end

-- Auto sort options (popup)
local sortFrame
local function OpenSortOptions()
    if not sortFrame then
        local f = W.Window("WLRTSortOptions", 300, 210, L("Auto sort options"))
        W.Label(f, L("Groups to sort:"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 14, -36)
        f.checks = {}
        for g = 1, 8 do
            local c = W.Check(f, tostring(g), function() return db.sortGroups[g] end,
                function(v) db.sortGroups[g] = v end)
            c:SetPoint("TOPLEFT", 10 + ((g - 1) % 4) * 68, -54 - math.floor((g - 1) / 4) * 26)
            f.checks[g] = c
        end
        W.Label(f, L("Number of splits:"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 14, -118)
        f.parts = W.Button(f, "", 60, 20, function(self)
            db.sortParts = (db.sortParts % 4) + 1
            self:SetText(db.sortParts)
        end, { L("Number of sides to spread tanks and healers across (click to change).") })
        f.parts:SetPoint("TOPLEFT", 140, -114)
        W.Label(f, L("Split rule:"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 14, -146)
        f.rule = W.Button(f, "", 140, 20, function(self)
            db.sortRule = db.sortRule == "alternating" and "consecutive" or "alternating"
            self:SetText(db.sortRule == "alternating" and L("Alternating (1,3,5)") or L("Consecutive (1,2,3)"))
        end)
        f.rule:SetPoint("TOPLEFT", 140, -142)
        W.Label(f, L("|cff999999Tanks/healers spread across splits, dps fill G1 then G2...|r"), "GameFontHighlightSmall")
            :SetPoint("BOTTOMLEFT", 14, 14)
        sortFrame = f
    end
    for g = 1, 8 do sortFrame.checks[g]:Sync() end
    sortFrame.parts:SetText(db.sortParts)
    sortFrame.rule:SetText(db.sortRule == "alternating" and L("Alternating (1,3,5)") or L("Consecutive (1,2,3)"))
    sortFrame:Show()
end

local function BuildGroupPanel(parent)
    local p = W.Panel(parent, 340, 540)
    p:SetPoint("TOPLEFT", 198, 0)
    UI.slots, UI.groupHeaders = {}, {}
    for g = 1, 8 do
        local x = 8 + ((g - 1) % 2) * 165
        local y = -8 - math.floor((g - 1) / 2) * 116
        local h = W.Label(p, L("Group ") .. g, "GameFontNormalSmall")
        h:SetPoint("TOPLEFT", x + 2, y)
        UI.groupHeaders[g] = h
        for i = 1, 5 do
            local s = MakeSlot(p, g)
            s:SetPoint("TOPLEFT", x, y - 14 - (i - 1) * SLOT_H)
            UI.slots[#UI.slots + 1] = s
        end
    end
    UI.emptyHint = W.Label(p, "", "GameFontDisable")
    UI.emptyHint:SetPoint("CENTER", 0, 20)
    UI.emptyHint:SetWidth(300)
    UI.emptyHint:SetJustifyH("CENTER")

    UI.warnText = W.Label(p, "", "GameFontHighlightSmall")
    UI.warnText:SetPoint("TOPLEFT", 10, -470)
    UI.warnText:SetWidth(320)
    UI.warnText:SetWordWrap(false)

    W.Button(p, L("Capture group"), 160, 22, function()
        local preset = NeedPreset()
        if not preset then return end
        if not W.InGroup() then W.Print(L("You are not in a group.")); return end
        local total, added = RG.Capture(preset)
        W.Print(total .. L(" player(s) captured (") .. added .. L(" new)."))
        Changed()
    end, { L("Updates the preset with the raid's current players, groups and marks.") })
        :SetPoint("TOPLEFT", 8, -488)
    W.Button(p, L("Remove missing"), 160, 22, function()
        local preset = NeedPreset()
        if not preset then return end
        if not W.InGroup() then W.Print(L("You are not in a group.")); return end
        W.Print(RG.RemoveAbsent(preset) .. L(" player(s) removed."))
        Changed()
    end, { L("Removes players who are not in the raid from the preset.") }):SetPoint("TOPLEFT", 172, -488)
    W.Button(p, L("Auto sort"), 105, 22, function()
        local preset = NeedPreset()
        if not preset then return end
        RG.AutoSort(preset)
        Changed()
    end, { L("Spreads the preset's players by role (tanks, healers, dps) across the checked groups."),
        L("Outside a raid, everyone counts as dps.") }):SetPoint("TOPLEFT", 8, -512)
    W.Button(p, L("Sort options"), 105, 22, OpenSortOptions):SetPoint("TOPLEFT", 117, -512)
    W.Button(p, L("Clear"), 105, 22, function()
        local preset = NeedPreset()
        if not preset then return end
        wipe(preset.players)
        Changed()
    end, { L("Removes everyone from the preset.") }):SetPoint("TOPLEFT", 226, -512)
end

local function RefreshGroups()
    local preset = Current()
    local players = preset and preset.players or {}
    local map = W.InGroup() and RG.MemberMap() or nil
    local byGroup, iconUse, warns = {}, {}, {}
    for g = 1, 8 do byGroup[g] = {} end
    for _, pl in ipairs(players) do
        local g = pl.group or 1
        if g < 1 or g > 8 then g = 1; pl.group = 1 end
        byGroup[g][#byGroup[g] + 1] = pl
        if pl.icon and pl.icon > 0 then iconUse[pl.icon] = (iconUse[pl.icon] or 0) + 1 end
    end
    for g = 1, 8 do
        local n = #byGroup[g]
        UI.groupHeaders[g]:SetText(L("Group ") .. g .. (n > 0 and (" |cffaaaaaa(" .. n .. ")|r") or ""))
        if n > 5 then
            local extra = {}
            for k = 6, n do extra[#extra + 1] = byGroup[g][k].name end
            warns[#warns + 1] = "G" .. g .. " > 5: " .. table.concat(extra, ", ")
        end
    end
    for ic = 1, 8 do
        if (iconUse[ic] or 0) > 1 then warns[#warns + 1] = W.ICON_NAMES[ic] .. " x" .. iconUse[ic] end
    end
    local idx = {}
    for _, s in ipairs(UI.slots) do
        idx[s.group] = (idx[s.group] or 0) + 1
        local pl = byGroup[s.group][idx[s.group]]
        s.data = pl
        if pl then
            local r, g, b = W.ClassColor(pl.class)
            local tag = pl.ma and ("|cffce1918[MA" .. pl.ma .. "]|r ") or ""
            if map and not map[pl.name:lower()] then
                s.text:SetText(tag .. pl.name .. " |cff777777(absent)|r")
                s.text:SetTextColor(r * 0.5, g * 0.5, b * 0.5)
            else
                s.text:SetText(tag .. pl.name)
                s.text:SetTextColor(r, g, b)
            end
            if pl.icon and pl.icon > 0 then
                s.icon.tex:SetTexture(W.ICON .. pl.icon)
                s.icon.tex:Show()
            else
                s.icon.tex:Hide()
            end
            s.icon:Show()
        else
            s.text:SetText("")
            s.icon:Hide()
        end
    end
    if not preset then
        UI.emptyHint:SetText(L("Create or select a preset on the left."))
    elseif #players == 0 then
        UI.emptyHint:SetText(L("Empty preset: drag players from\nthe right column (Raid or Guild)\nor use \"Capture group\"."))
    else
        UI.emptyHint:SetText("")
    end
    UI.warnText:SetText(#warns > 0 and ("|cffff6666" .. table.concat(warns, "  -  ") .. "|r") or "")
end

-- Members column: Raid or Guild source
local function SourceChip(parent, text, w)
    local b = CreateFrame("Button", nil, parent, W.BT)
    W.Size(b, w, 18)
    if b.SetBackdrop then
        b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        b:SetBackdropBorderColor(0, 0, 0, 1)
    end
    b.text = W.Label(b, text, "GameFontHighlightSmall")
    b.text:SetPoint("CENTER")
    return b
end

local function StyleChip(b, active)
    if not b.SetBackdropColor then return end
    if active then
        b:SetBackdropColor(W.R * 0.6, W.G * 0.6, W.B * 0.6, 0.95)
        b.text:SetTextColor(1, 1, 1)
    else
        b:SetBackdropColor(0.05, 0.05, 0.06, 0.9)
        b.text:SetTextColor(0.6, 0.6, 0.6)
    end
end

local FREE_W = 250
local function BuildFreePanel(parent)
    local p = W.Panel(parent, FREE_W, 540)
    p:SetPoint("TOPLEFT", 546, 0)
    UI.freePanel = p
    UI.freeTitle = W.Label(p, L("Members"), "GameFontNormalSmall")
    UI.freeTitle:SetPoint("TOPLEFT", 10, -10)
    W.Tooltip(p, L("Members not in preset"), { L("Raid: members of your current group."),
        L("Guild: every guild member, to pre-place before inviting."),
        L("Drag them into a group slot."), L("Drag a player here to remove them from the preset.") })

    UI.srcGuild = SourceChip(p, L("Guild"), 56)
    UI.srcGuild:SetPoint("TOPRIGHT", -10, -8)
    UI.srcRaid = SourceChip(p, "Raid", 48)
    UI.srcRaid:SetPoint("RIGHT", UI.srcGuild, "LEFT", -4, 0)
    UI.srcRaid:SetScript("OnClick", function() db.poolSource = "raid"; UI.RefreshFree() end)
    UI.srcGuild:SetScript("OnClick", function()
        if not W.IsInGuild() then W.Print(L("You are not in a guild.")); return end
        db.poolSource = "guild"
        W.RequestGuildRoster()
        UI.RefreshFree()
    end)

    local filter = W.EditBox(p, 120)
    filter:SetPoint("TOPLEFT", 16, -32)
    filter:SetScript("OnTextChanged", function() UI.RefreshFree() end)
    UI.filterBox = filter
    W.Label(p, L("Filter"), "GameFontDisableSmall"):SetPoint("BOTTOMLEFT", filter, "TOPLEFT", -4, 0)

    UI.offlineCheck = W.Check(p, L("Offline"), function() return db.showOffline end,
        function(v) db.showOffline = v; UI.RefreshFree() end,
        { L("Guild: also show offline members.") })
    UI.offlineCheck:SetPoint("LEFT", filter, "RIGHT", 6, 0)

    UI.freeList = W.ScrollList(p, FREE_W - 36, 290, 16, function(content)
        local r = CreateFrame("Button", nil, content)
        r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        r.text = W.Label(r, "", "GameFontHighlightSmall")
        r.text:SetPoint("LEFT", 2, 0)
        r.text:SetPoint("RIGHT", -2, 0)
        r:RegisterForDrag("LeftButton")
        r:SetScript("OnDragStart", function(self)
            if self.member then StartDrag({ member = self.member }, self.member.name, self.member.class) end
        end)
        r:SetScript("OnDragStop", StopDrag)
        r:SetScript("OnEnter", function(self)
            local m = self.member
            if not m then return end
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine(m.name, W.ClassColor(m.class))
            if m.rank then GameTooltip:AddLine(m.rank .. (m.level and (L("  -  lvl ") .. m.level) or ""), 0.8, 0.8, 0.8) end
            if m.group then GameTooltip:AddLine(L("Group ") .. m.group, 0.8, 0.8, 0.8) end
            if m.online == false then GameTooltip:AddLine(L("Offline"), 0.5, 0.5, 0.5) end
            GameTooltip:AddLine(L("Drag into a group slot"), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return r
    end)
    UI.freeList.sf:SetPoint("TOPLEFT", 6, -56)

    local add = W.EditBox(p, 130)
    add:SetPoint("TOPLEFT", 16, -356)
    local function doAdd()
        local preset = NeedPreset()
        if not preset then return end
        local name = W.SanitizeName(add:GetText())
        local class
        if name == "" and UnitExists("target") and UnitIsPlayer("target") then
            name = W.Safe(UnitName("target")) or ""
            class = W.UnitClassToken("target")
        end
        if name == "" then W.Print(L("Type a name or target a player.")); return end
        local m = RG.MemberMap()[name:lower()] or RG.GuildMap()[name:lower()]
        if m then class, name = m.class, m.name end
        local counts = { 0, 0, 0, 0, 0, 0, 0, 0 }
        for _, pl in ipairs(preset.players) do counts[pl.group or 1] = counts[pl.group or 1] + 1 end
        local g = 1
        while g < 8 and counts[g] >= 5 do g = g + 1 end
        RG.AddPlayer(preset, name, class, g, 0)
        add:SetText("")
        Changed()
    end
    add:SetScript("OnEnterPressed", function(self) doAdd(); self:ClearFocus() end)
    W.Button(p, L("Add"), 80, 22, doAdd, { L("Adds the typed name, or your target if the field is empty.") })
        :SetPoint("LEFT", add, "RIGHT", 6, 0)

    UI.freeHint = W.Label(p, "", "GameFontDisableSmall")
    UI.freeHint:SetPoint("TOPLEFT", 10, -382)
    UI.freeHint:SetWidth(FREE_W - 20)

    W.Check(p, L("Clear other marks"), function() return db.clearOthers end,
        function(v) db.clearOthers = v end,
        { L("When applying, removes marks from players who have none in the preset.") })
        :SetPoint("TOPLEFT", 10, -440)
    W.Check(p, L("Share with group when applying"), function() return db.syncOnApply end,
        function(v) db.syncOnApply = v end,
        { L("\"Apply all\" also sends the preset to players who have the addon.") })
        :SetPoint("TOPLEFT", 10, -464)
    W.Check(p, L("Accept shared presets"), function() return db.acceptShared end,
        function(v) db.acceptShared = v end)
        :SetPoint("TOPLEFT", 10, -488)
end

function UI.RefreshFree()
    if not UI.freeList then return end
    local preset = Current()
    local source = db.poolSource
    StyleChip(UI.srcRaid, source == "raid")
    StyleChip(UI.srcGuild, source == "guild")
    if source == "guild" then UI.offlineCheck:Show() else UI.offlineCheck:Hide() end

    local query = W.SanitizeName(UI.filterBox:GetText()):lower()
    local function keep(m)
        if preset and RG.FindPlayer(preset, m.name) then return false end
        if query ~= "" and not m.name:lower():find(query, 1, true) then return false end
        return true
    end

    local list, total, hint = {}, 0, ""
    if source == "guild" then
        if not W.IsInGuild() then
            hint = L("No guild.")
        else
            local inRaid = W.InGroup() and RG.MemberMap() or {}
            for _, m in ipairs(W.GuildMembers()) do
                if m.online or db.showOffline then
                    total = total + 1
                    -- the guild list is shared and cached: always overwrite (nil when not in the raid)
                    local rm = inRaid[(PName(m.full or m.name) or m.name):lower()]
                    m.unit, m.group = rm and rm.unit, rm and rm.group
                    if keep(m) then list[#list + 1] = m end
                end
            end
            table.sort(list, function(a, b)
                if a.online ~= b.online then return a.online end
                return a.name < b.name
            end)
            if total == 0 then hint = L("Loading guild roster...")
            elseif #list == 0 then hint = L("Everyone is already in the preset.") end
        end
    elseif W.InGroup() then
        for _, m in ipairs(RG.GetMembers()) do
            total = total + 1
            if keep(m) then list[#list + 1] = m end
        end
        table.sort(list, function(a, b) return a.name < b.name end)
        if #list == 0 then hint = L("The whole raid is in the preset.") end
    else
        hint = L("Not in a group. Switch to \"Guild\" to pre-place.")
    end
    UI.freeHint:SetText(hint)
    UI.freeTitle:SetText(L("Members |cffaaaaaa(") .. #list .. ")|r")

    for i, m in ipairs(list) do
        local r = UI.freeList:Row(i)
        r.member = m
        local r1, g1, b1 = W.ClassColor(m.class)
        if m.online == false then
            r.text:SetText(m.name .. L(" |cff666666offline|r"))
            r.text:SetTextColor(r1 * 0.55, g1 * 0.55, b1 * 0.55)
        else
            r.text:SetText(m.name .. (m.group and (" |cff888888G" .. m.group .. "|r") or ""))
            r.text:SetTextColor(r1, g1, b1)
        end
    end
    UI.freeList:Finish(#list)
end

-- APPLY ALL on Forever: a secure button laid over the visible one runs the /tm marks macro on the
-- click, then the rest (assists, groups, share) runs as plain addon code right after it. It lives on
-- UIParent and only shows while the mouse is on the button (as NaowhForever does): a secure child
-- would stop the /wl window from opening or closing in combat.
local function PrepareMarks(self)
    if InCombatLockdown() then return end
    local preset = Current()
    local text, plan = "", nil
    if preset and W.InGroup() and W.CanLead() then
        local lines, count, missing = RG.MarkPlan(preset)
        text = table.concat(RG.AssistLines(preset, lines), "\n")
        plan = { count = count, missing = missing }
    end
    self.plan = plan
    self:SetAttribute("macrotext", text)
end

-- lays the secure button over the visible one (out of combat only)
local function Cover(visible)
    local b = UI.applySecure
    if not b or b:IsShown() or InCombatLockdown() or not visible:GetLeft() then return end
    local scale = visible:GetEffectiveScale() / UIParent:GetEffectiveScale()
    b:ClearAllPoints()
    b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", visible:GetLeft() * scale, visible:GetBottom() * scale)
    b:SetSize(visible:GetWidth() * scale, visible:GetHeight() * scale)
    PrepareMarks(b)
    b:Show()
end

local function SecureApply(visible)
    UI.applyVisible = visible
    if UI.applySecure or not W.FOREVER or InCombatLockdown() then return end -- in combat: made after it
    local b = CreateFrame("Button", "WLRTApplyAllButton", UIParent, "SecureActionButtonTemplate")
    b:SetFrameStrata("TOOLTIP")
    b:RegisterForClicks("AnyUp")
    b:SetAttribute("useOnKeyDown", false)
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", "")
    b:Hide()
    UI.applySecure = b
    visible:HookScript("OnEnter", Cover)
    visible:HookScript("OnHide", function() if not InCombatLockdown() then b:Hide() end end)
    -- hover look and tooltip stay on the visible button underneath
    b:SetScript("OnEnter", function()
        local fn = visible:GetScript("OnEnter"); if fn then fn(visible) end
        visible:LockHighlight()
    end)
    b:SetScript("OnLeave", function(self)
        local fn = visible:GetScript("OnLeave"); if fn then fn(visible) end
        visible:UnlockHighlight()
        if not InCombatLockdown() then self:Hide() end
    end)
    -- runs after the secure macro of the same click
    b:HookScript("OnClick", function(self)
        local preset, name = NeedPreset()
        if not preset then return end
        if not W.InGroup() then
            W.Print(L("You are not in a group."))
        elseif InCombatLockdown() then
            W.Print(L("|cffffaa00Marks cannot be placed in combat: click again after the fight.|r"))
        elseif not W.CanLead() then
            W.Print(L("|cffff5555You must be leader or assistant to set marks.|r"))
        elseif self.plan then
            W.Print(self.plan.count .. L(" mark(s) applied."))
            if #self.plan.missing > 0 then W.Print(L("|cffffaa00Missing:|r ") .. table.concat(self.plan.missing, ", ")) end
        end
        RG.ApplyAll(preset, name, true)
    end)
end

-- Entering combat (last moment secure frames can change): macro emptied and button hidden, the
-- visible button then answers alone. A button not made yet (window built in combat) is made after.
W.On("PLAYER_REGEN_DISABLED", function()
    local b = UI.applySecure
    if b then b.plan = nil; b:SetAttribute("macrotext", ""); b:Hide() end
end)
W.On("PLAYER_REGEN_ENABLED", function()
    if UI.applyVisible and not UI.applySecure then SecureApply(UI.applyVisible) end
end)
-- the roster moved while the mouse waits on the button: rewrite the macro
W.OnRoster(function()
    local b = UI.applySecure
    if b and b:IsShown() and not InCombatLockdown() then PrepareMarks(b) end
end)

local function BuildBottomBar(parent)
    local x = 0
    local function add(text, w, fn, tip)
        local b = W.Button(parent, text, w, 24, fn, tip)
        b:SetPoint("BOTTOMLEFT", x, 4)
        x = x + w + 6
        return b
    end
    -- Apply marks / Apply groups / Clear marks / Announce: hidden for now (functions kept: /wl apply, RG.Announce...)
    local applyAll = add(L("|cff55ff55APPLY ALL|r"), 135, function()
        local preset, name = NeedPreset()
        if preset then RG.ApplyAll(preset, name) end
    end, { L("Marks + groups (+ share if checked)."), L("Macro: /wl apply PresetName") })
    SecureApply(applyAll)
    add(L("Share"), 90, function()
        local _, name = NeedPreset()
        if name then RG.Share(name) end
    end, { L("Sends the preset to group members who have the addon.") })
    add(L("INV ALL"), 80, function()
        -- reserved for guild rank 0 (guild master) and 1
        local me = W.GuildMember(W.UnitFullName("player"))
        if not (me and me.rankIndex and me.rankIndex <= 1) then
            W.Print(L("INV ALL is reserved for the two highest guild ranks."))
            return
        end
        local preset = NeedPreset()
        if not preset then return end
        local names = {}
        for _, p in ipairs(preset.players) do names[#names + 1] = p.name end
        if W.InviteMany then W.InviteMany(names) end
    end, { L("Invites every player of the preset who is not in the group yet.") })
    add(L("Assist macro"), 95, function()
        local preset, name = NeedPreset()
        if preset then RG.ExportAssist(preset, name) end
    end, { L("Shows the /assist macro on the main assist (MA1) and creates it."),
        L("Alt-click a player in a group to make them main assist (MA1, MA2...).") })
end

function RG.RefreshPlayers()
    if not UI.slots then return end
    RefreshGroups()
    UI.RefreshFree()
end

function RG.Refresh()
    if not UI.slots or not UI.root:IsVisible() then return end
    if db.selected and not db.presets[db.selected] then db.selected = nil end
    RefreshPresets()
    RG.RefreshPlayers()
end

local function Build(panel)
    UI.root = panel
    local d = CreateFrame("Frame", nil, UIParent)
    W.Size(d, 140, 18)
    d:SetFrameStrata("TOOLTIP")
    d.bg = d:CreateTexture(nil, "BACKGROUND")
    d.bg:SetAllPoints()
    W.SetColor(d.bg, 0, 0, 0, 0.75)
    d.text = W.Label(d, "", "GameFontHighlight")
    d.text:SetPoint("LEFT", 4, 0)
    d:Hide()
    d:SetScript("OnUpdate", function(self)
        local x, y = GetCursorPosition()
        local s = UIParent:GetEffectiveScale()
        self:ClearAllPoints()
        self:SetPoint("LEFT", UIParent, "BOTTOMLEFT", x / s + 8, y / s)
    end)
    UI.drag = d
    BuildPresetPanel(panel)
    BuildGroupPanel(panel)
    BuildFreePanel(panel)
    BuildBottomBar(panel)
end

local function OnShowModule()
    if db.poolSource == "guild" then W.RequestGuildRoster() end
    if W.InGroup() then
        RG.RefreshLive()
        if not db.selected then db.selected = RG.LIVE end
    end
    RG.Refresh()
end

W.RegisterModule("RaidGroups", "Raid Groups", Build, OnShowModule)

---------------------------------------------------------------------------
-- Events and commands
---------------------------------------------------------------------------
local function RosterChanged()
    OnRoster()
    if UI.slots and UI.root:IsVisible() then
        if RG.RefreshLive() then RG.Refresh() else RG.RefreshPlayers() end
    end
end
W.On("GROUP_ROSTER_UPDATE", RosterChanged)
W.On("RAID_ROSTER_UPDATE", RosterChanged)
W.On("PARTY_MEMBERS_CHANGED", RosterChanged)
W.On("GUILD_ROSTER_UPDATE", function()
    if UI.slots and UI.root:IsVisible() and db.poolSource == "guild" then UI.RefreshFree() end
end)

local function PresetArg(rest)
    local name = (rest and rest ~= "") and rest or db.selected
    local preset = name and db.presets[name]
    if not preset then W.Print(L("Preset not found: ") .. tostring(name)) end
    return preset, name
end
W.slash.apply = function(rest) local p, n = PresetArg(rest); if p then RG.ApplyAll(p, n) end end
W.slash.marks = function(rest) local p = PresetArg(rest); if p then RG.ApplyMarkers(p) end end
W.slash.groups = function(rest) local p = PresetArg(rest); if p then RG.ApplyGroups(p) end end
W.slash.clear = function() RG.ClearMarkers() end
W.slash.assist = function(rest)
    local p = PresetArg(rest)
    if p then RG.CreateMyAssistMacro(p) end
end
W.slash.list = function() for _, n in ipairs(RG.SortedNames()) do W.Print(" - " .. (n == RG.LIVE and L(n) or n)) end end
