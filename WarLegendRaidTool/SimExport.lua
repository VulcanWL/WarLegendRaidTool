-- WarLegend RaidTool - Sim export
-- My character for the simulators that know WoW: Forever (written here, no code taken from other addons):
--   * a SimulationCraft profile in the layout of the official SimC addon's Forever export: header
--     comments, spec=unknown + role, talents from the Forever spec group (primary / secondary as
--     comments), one "# Item Name (ilvl)" comment per item, item lines with enchant / gems / bonus /
--     drop level / crafted stats, "### Gear from Bags", skills and buffs, adler32 checksum
--   * JSON in the layout of the wowsims exporters (MythicSim's Forever sim runs on wowsims)
-- Cost: nothing at all until a button is clicked or /wl sim is typed.
local W = WLRT
W.AddFR({
    ["Sim export"] = "Export sim",
    ["Export my character for a simulator (gear, enchants, gems, talents, professions)."] =
        "Exporte mon personnage pour un simulateur (équipement, enchants, gemmes, talents, métiers).",
    ["SimulationCraft (text)"] = "SimulationCraft (texte)",
    ["MythicSim (JSON)"] = "MythicSim (JSON)",
    ["OXM (WSE JSON)"] = "OXM (JSON WSE)",
    ["Include the gear in my bags (for Top Gear)"] = "Inclure l'équipement des sacs (pour Top Gear)",
    ["Ctrl+C to copy, then paste it in the simulator."] = "Ctrl+C pour copier, puis colle-le dans le simulateur.",
    ["Not available in combat."] = "Indisponible en combat.",
    ["Sites for WoW: Forever:\n- SimulationCraft (Forever version of the SimC addon / sim)\n- mythicsim.com/wow-forever/sim : Import > Addon Import (JSON)\n- simsforever.com\nNo raidbots / wowsims.com sim for Forever yet."] =
        "Sites pour WoW: Forever :\n- SimulationCraft (version Forever de l'addon / du sim SimC)\n- mythicsim.com/wow-forever/sim : Import > Addon Import (JSON)\n- simsforever.com\nPas encore de sim Forever sur raidbots / wowsims.com.",
})
local L = W.L
local db

W.OnReady(function()
    db = W.DB("simExport", { bags = true })
end)

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
-- SimC tokens: lower case, spaces to "_", only a-z 0-9 _
local function Tokenize(s)
    s = (s or ""):lower():gsub(" ", "_"):gsub("[^a-z0-9_]", "")
    return s
end

local function Race()
    local _, file = UnitRace("player")
    file = W.Safe(file) or ""
    if file == "Scourge" then return "undead" end
    return Tokenize((file:gsub("(%l)(%u)", "%1 %2"))) -- "NightElf" -> "night_elf"
end

local PROF_EN = { [164] = "blacksmithing", [165] = "leatherworking", [171] = "alchemy", [182] = "herbalism",
    [186] = "mining", [197] = "tailoring", [202] = "engineering", [333] = "enchanting", [393] = "skinning",
    [755] = "jewelcrafting", [773] = "inscription" }
-- the two main professions only (GetProfessions also gives cooking, fishing...)
local function Professions()
    local out = {}
    if not (GetProfessions and GetProfessionInfo) then return out end
    local p1, p2 = GetProfessions()
    for _, idx in ipairs({ p1, p2 }) do
        local name, _, rank, _, _, _, skillLine = GetProfessionInfo(idx)
        if name and PROF_EN[skillLine] then out[#out + 1] = { name = PROF_EN[skillLine], rank = rank or 0 } end
    end
    return out
end

local function SpecInfo()
    local getSpec = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
    local getInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
    if not (getSpec and getInfo) then return "", nil end
    local idx = getSpec()
    if not idx then return "", nil end
    local _, name, _, _, role = getInfo(idx)
    return W.Safe(name) or "", W.Safe(role)
end

-- Forever keeps talents by spec group (primary / secondary): group -> trait config -> loadout string
local function LoadoutOfGroup(group)
    local configOf = C_SpecializationInfo and C_SpecializationInfo.GetCombatConfigIDForSpecGroup
    local id = configOf and configOf(group)
    if not id and group == 1 and C_ClassTalents and C_ClassTalents.GetActiveConfigID then id = C_ClassTalents.GetActiveConfigID() end
    if not id or not (C_Traits and C_Traits.GenerateImportString) then return nil end
    local ok, s = pcall(C_Traits.GenerateImportString, id)
    s = ok and W.Safe(s)
    return (s and s ~= "") and s or nil
end

local function ActiveGroup()
    local f = C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup
    return (f and f()) or 1
end

local function Adler32(s)
    local a, b = 1, 0
    for i = 1, #s do
        a = (a + s:byte(i)) % 65521
        b = (b + a) % 65521
    end
    return b * 65536 + a
end

---------------------------------------------------------------------------
-- Items
---------------------------------------------------------------------------
-- SimC slot names, in SimC's order (Forever has no ranged slot)
local SLOTS = {
    { 1, "head" }, { 2, "neck" }, { 3, "shoulder" }, { 15, "back" }, { 5, "chest" }, { 4, "shirt" },
    { 19, "tabard" }, { 9, "wrist" }, { 10, "hands" }, { 6, "waist" }, { 7, "legs" }, { 8, "feet" },
    { 11, "finger1" }, { 12, "finger2" }, { 13, "trinket1" }, { 14, "trinket2" }, { 16, "main_hand" },
    { 17, "off_hand" },
}
local EQUIP_SLOT = {
    INVTYPE_HEAD = "head", INVTYPE_NECK = "neck", INVTYPE_SHOULDER = "shoulder", INVTYPE_CLOAK = "back",
    INVTYPE_CHEST = "chest", INVTYPE_ROBE = "chest", INVTYPE_WRIST = "wrist", INVTYPE_HAND = "hands",
    INVTYPE_WAIST = "waist", INVTYPE_LEGS = "legs", INVTYPE_FEET = "feet", INVTYPE_FINGER = "finger1",
    INVTYPE_TRINKET = "trinket1", INVTYPE_WEAPON = "main_hand", INVTYPE_WEAPONMAINHAND = "main_hand",
    INVTYPE_2HWEAPON = "main_hand", INVTYPE_RANGED = "main_hand", INVTYPE_RANGEDRIGHT = "main_hand",
    INVTYPE_WEAPONOFFHAND = "off_hand", INVTYPE_SHIELD = "off_hand", INVTYPE_HOLDABLE = "off_hand",
}
-- item link modifier types kept by SimC
local MOD_DROP_LEVEL, MOD_CONTENT_TUNING, MOD_CRAFT_1, MOD_CRAFT_2, MOD_REDIRECTED = 9, 28, 29, 30, 64

-- "item:id:enchant:gem1:gem2:gem3:gem4:suffix:unique:level:spec:mods:context:numBonus:bonus...:numMods:type:value..."
local function Split(link)
    local body = link and link:match("item:([%-%d:]+)")
    if not body then return nil end
    local f = {}
    for v in (body .. ":"):gmatch("([^:]*):") do f[#f + 1] = tonumber(v) or 0 end
    return f
end

local function ItemLine(slot, link)
    local f = Split(link)
    if not f or f[1] == 0 then return nil end
    local opts = { slot .. "=", "id=" .. f[1] }
    if f[2] > 0 then opts[#opts + 1] = "enchant_id=" .. f[2] end
    local gems = { f[3] or 0, f[4] or 0, f[5] or 0, f[6] or 0 }
    while #gems > 0 and gems[#gems] == 0 do table.remove(gems) end
    if #gems > 0 then opts[#opts + 1] = "gem_id=" .. table.concat(gems, "/") end
    local nBonus = f[13] or 0
    local bonus = {}
    for i = 1, nBonus do bonus[i] = f[13 + i] or 0 end
    if #bonus > 0 then opts[#opts + 1] = "bonus_id=" .. table.concat(bonus, "/") end
    local pos = 13 + nBonus + 1
    local crafted = {}
    for i = 1, f[pos] or 0 do
        local t, v = f[pos + 2 * i - 1], f[pos + 2 * i]
        if t == MOD_DROP_LEVEL then opts[#opts + 1] = "drop_level=" .. v
        elseif t == MOD_CONTENT_TUNING then opts[#opts + 1] = "content_tuning=" .. v
        elseif t == MOD_CRAFT_1 or t == MOD_CRAFT_2 then crafted[#crafted + 1] = v
        elseif t == MOD_REDIRECTED then opts[#opts + 1] = "redirected_base_stats=" .. v end
    end
    if #crafted > 0 then opts[#opts + 1] = "crafted_stats=" .. table.concat(crafted, "/") end
    return table.concat(opts, ",")
end

-- "Name (ilvl)" for the comment above the item line
local function ItemComment(link)
    local name = link:match("|h%[(.-)%]|h")
    if not name or name:match("^%s*$") then return nil end
    name = name:gsub("|%a.-|%a", "")
    local ilvl = W.GetDetailedItemLevelInfo and W.GetDetailedItemLevelInfo(link)
    return ilvl and (name .. " (" .. ilvl .. ")") or name
end

local function BagLinks()
    local out = {}
    local numSlots = C_Container and C_Container.GetContainerNumSlots
    local linkOf = C_Container and C_Container.GetContainerItemLink
    if not (numSlots and linkOf and W.GetItemInfoInstant) then return out end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, numSlots(bag) or 0 do
            local link = linkOf(bag, slot)
            if link then
                local _, _, _, loc = W.GetItemInfoInstant(link)
                local quality = select(3, W.GetItemInfo(link))
                if EQUIP_SLOT[loc] and (quality or 0) >= 2 then out[#out + 1] = { EQUIP_SLOT[loc], link } end
            end
        end
    end
    return out
end

local function Skills()
    if not (C_SkillInfo and C_SkillInfo.GetNumSkillLines and C_SkillInfo.GetSkillLineInfo) then return nil end
    local list = {}
    for i = 1, C_SkillInfo.GetNumSkillLines() do
        local s = C_SkillInfo.GetSkillLineInfo(i)
        if s and not s.isHeader and s.skillID then list[#list + 1] = s end
    end
    table.sort(list, function(a, b) return a.skillID < b.skillID end)
    local out = {}
    for _, s in ipairs(list) do out[#out + 1] = s.skillID .. ":" .. (s.rank or 0) .. ":" .. (s.modifier or 0) .. ":" .. (s.maxRank or 0) end
    return table.concat(out, "/")
end

local function Buffs()
    if not W.AuraByIndex then return nil end
    local list = {}
    for i = 1, 40 do
        local a = W.AuraByIndex("player", i, "HELPFUL") -- false: hidden, skipped
        if a == nil then break end
        local id = a and W.Safe(a.spellId)
        if id then list[#list + 1] = { id, W.Safe(a.applications) or 0 } end
    end
    table.sort(list, function(x, y) return x[1] < y[1] end)
    local out = {}
    for _, b in ipairs(list) do out[#out + 1] = b[1] .. ":" .. b[2] end
    return table.concat(out, "/")
end

---------------------------------------------------------------------------
-- SimulationCraft profile
---------------------------------------------------------------------------
function W.SimcProfile()
    local name = W.Safe(UnitName("player")) or "?"
    local _, class = UnitClass("player")
    local region = (GetCurrentRegionName and GetCurrentRegionName()) or "eu"
    local realm = (GetRealmName and GetRealmName()) or ""
    local version, build, _, toc = GetBuildInfo()
    local _, role = SpecInfo()
    local out = {}
    local function add(s) out[#out + 1] = s end

    add("# " .. name .. " - " .. date("%Y-%m-%d %H:%M") .. " - " .. region .. "/" .. realm)
    add("# WaR LegenD RaidTool " .. (W.version or "") .. " (SimC addon layout)")
    add("# WoW " .. tostring(version) .. "." .. tostring(build) .. ", TOC " .. tostring(toc))
    add("# Requires SimulationCraft 1000-01 or newer")
    add("")
    add(Tokenize(class) .. "=\"" .. name .. "\"")
    add("level=" .. (UnitLevel("player") or 60))
    add("race=" .. Race())
    add("region=" .. Tokenize(region))
    add("server=" .. Tokenize(realm))
    add("role=" .. (role == "TANK" and "tank" or (role and "attack" or "")))
    local profs = {}
    for _, p in ipairs(Professions()) do profs[#profs + 1] = p.name .. "=" .. p.rank end
    add(#profs > 0 and ("professions=" .. table.concat(profs, "/")) or "")
    add("spec=unknown") -- as the SimC addon on Forever: the spec comes from the talent string
    add("")
    local active = LoadoutOfGroup(ActiveGroup())
    add(active and ("talents=" .. active) or "# Unable to export talents - no talent data from the client yet, try again")
    add("")
    local labels = { "Primary", "Secondary" }
    for g = 1, (GetNumSpecGroups and GetNumSpecGroups()) or 1 do
        local s = LoadoutOfGroup(g)
        if s then add("# " .. (labels[g] or ("Group " .. g)) .. " Talents"); add("# talents=" .. s) end
    end
    add("")

    for _, s in ipairs(SLOTS) do
        local link = W.Safe(GetInventoryItemLink("player", s[1]))
        local line = link and ItemLine(s[2], link)
        if line then
            local c = ItemComment(link)
            if c then add("# " .. c) end
            add(line)
        end
    end

    if db and db.bags then
        local bags = BagLinks()
        if #bags > 0 then
            add("")
            add("### Gear from Bags")
            for _, b in ipairs(bags) do
                local line = ItemLine(b[1], b[2])
                if line then
                    add("#")
                    local c = ItemComment(b[2])
                    if c then add("# " .. c) end
                    add("# " .. line)
                end
            end
        end
    end

    add("")
    add("### Additional Character Info")
    local ok, skills = pcall(Skills)
    if ok and skills then add("#"); add("# skills=" .. skills) end
    local okB, buffs = pcall(Buffs)
    if okB and buffs then add("#"); add("# buffs=" .. buffs) end
    add("")
    local text = table.concat(out, "\n") .. "\n"
    return text .. "# Checksum: " .. string.format("%x", Adler32((text:gsub("||", "|"))))
end

---------------------------------------------------------------------------
-- JSON (wowsims exporter layout)
---------------------------------------------------------------------------
local NULL = {} -- an empty slot in a positional list
local function Encode(v)
    local t = type(v)
    if v == NULL then return "null" end
    if t == "number" or t == "boolean" then return tostring(v) end
    if t == "string" then
        return '"' .. v:gsub('[%c"\\]', function(c)
            if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" elseif c == "\n" then return "\\n" end
            return string.format("\\u%04x", c:byte())
        end) .. '"'
    end
    if t ~= "table" then return "null" end
    if #v > 0 or next(v) == nil then
        local out = {}
        for i = 1, #v do out[i] = Encode(v[i]) end
        return "[" .. table.concat(out, ",") .. "]"
    end
    local keys, out = {}, {}
    for k in pairs(v) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    for _, k in ipairs(keys) do out[#out + 1] = Encode(k) .. ":" .. Encode(v[k]) end
    return "{" .. table.concat(out, ",") .. "}"
end

-- MythicSim's "Addon Import" (the wowsims exporter JSON) reads: class ("mage"), race (its English
-- name, spaces ignored: "Night Elf", "Undead", "Skyborne (High Order)"), professions (its 9 names
-- only, an unknown one fails the import), talents ("ranks of tree 1-tree 2-tree 3") and gear.items
-- with only id / enchant / random_suffix (its parser refuses any other field).
local MYTHIC_PROFS = { alchemy = "Alchemy", blacksmithing = "Blacksmithing", enchanting = "Enchanting",
    engineering = "Engineering", herbalism = "Herbalism", leatherworking = "Leatherworking", mining = "Mining",
    skinning = "Skinning", tailoring = "Tailoring" }
-- ItemSlot order of the sim (rings and trinkets go to the first free slot, in this order)
local MYTHIC_SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }

local function MythicRace()
    local _, file = UnitRace("player")
    file = W.Safe(file) or ""
    if file == "Scourge" then return "Undead" end
    if file:find("Skyborne") then
        return file:find("Wind") and "Skyborne (Windshaper)" or "Skyborne (High Order)"
    end
    return (file:gsub("(%l)(%u)", "%1 %2")) -- "NightElf" -> "Night Elf"
end

-- Forever: one trait tree per class split in 3 groups (the 3 talent trees, left to right as the
-- talent frame shows them). Each tree: the ranks of its talents row by row, left to right.
local function MythicTalents()
    local group = ActiveGroup()
    local configOf = C_SpecializationInfo and C_SpecializationInfo.GetCombatConfigIDForSpecGroup
    local configID = configOf and configOf(group)
    if not (configID and C_Traits and C_Traits.GetConfigInfo and C_Traits.GetTreeNodes
        and C_Traits.GetNodeInfo and C_Traits.GetGroupDisplayInfoByTreeID) then return "" end
    local info = C_Traits.GetConfigInfo(configID)
    local treeID = info and info.treeIDs and info.treeIDs[1]
    if not treeID then return "" end
    local order, trees = {}, {}
    for i, d in ipairs(C_Traits.GetGroupDisplayInfoByTreeID(treeID) or {}) do
        order[d.groupID] = i
        trees[i] = {}
    end
    if #trees == 0 then return "" end
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
        local n = C_Traits.GetNodeInfo(configID, nodeID)
        if n and n.isVisible and (n.maxRanks or 0) > 0 then
            for _, g in ipairs(n.groupIDs or {}) do
                local t = order[g]
                if t then
                    local list = trees[t]
                    list[#list + 1] = { y = n.posY or 0, x = n.posX or 0, r = n.ranksPurchased or 0 }
                    break
                end
            end
        end
    end
    local parts = {}
    for i, list in ipairs(trees) do
        table.sort(list, function(a, b) if a.y ~= b.y then return a.y < b.y end return a.x < b.x end)
        local digits = {}
        for k, t in ipairs(list) do digits[k] = tostring(math.min(9, t.r)) end
        parts[i] = (table.concat(digits):gsub("0+$", ""))
    end
    return table.concat(parts, "-")
end

function W.SimJSON()
    local _, class = UnitClass("player")
    local items = {}
    for _, slotID in ipairs(MYTHIC_SLOTS) do
        local f = Split(W.Safe(GetInventoryItemLink("player", slotID)))
        if f and f[1] > 0 then
            local e = { id = f[1] }
            if f[2] > 0 then e.enchant = f[2] end
            if f[7] ~= 0 then e.random_suffix = f[7] end
            items[#items + 1] = e
        end
    end
    local profs = {}
    for _, p in ipairs(Professions()) do
        if MYTHIC_PROFS[p.name] then profs[#profs + 1] = { name = MYTHIC_PROFS[p.name], level = p.rank } end
    end
    return Encode({
        version = "WarLegendRaidTool " .. (W.version or ""),
        unit = "player",
        name = W.Safe(UnitName("player")) or "?",
        realm = GetRealmName and GetRealmName() or "",
        race = MythicRace(),
        class = Tokenize(class),
        level = UnitLevel("player") or 60,
        talents = MythicTalents(),
        professions = profs,
        gear = { items = items },
    })
end

-- OXM (forever.oxm.gg) "WSE Import" reads the WowSimsExporter JSON: gear.items is POSITIONAL (head, neck,
-- shoulder, back, chest, wrist, hands, waist, legs, feet, ring 1, ring 2, trinket 1, trinket 2, main hand,
-- off hand, ranged), an empty slot is null; gems and enchant are kept; name is the first name only.
local OXM_SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }

function W.SimOXM()
    local _, class = UnitClass("player")
    local _, raceFile = UnitRace("player")
    raceFile = W.Safe(raceFile) or ""
    if raceFile == "Scourge" then raceFile = "Undead" end
    local items = {}
    for i, slotID in ipairs(OXM_SLOTS) do
        local f = Split(W.Safe(GetInventoryItemLink("player", slotID)))
        if f and f[1] > 0 then
            local e = { id = f[1] }
            if f[2] > 0 then e.enchant = f[2] end
            local gems = {}
            for g = 3, 6 do if f[g] > 0 then gems[#gems + 1] = f[g] end end
            if #gems > 0 then e.gems = gems end
            items[i] = e
        else
            items[i] = NULL
        end
    end
    local profs = {}
    for _, p in ipairs(Professions()) do
        profs[#profs + 1] = { name = p.name:sub(1, 1):upper() .. p.name:sub(2), level = p.rank }
    end
    return Encode({
        version = "WarLegendRaidTool " .. (W.version or ""),
        unit = "player",
        name = W.Safe(UnitName("player")) or "?",
        realm = GetRealmName and GetRealmName() or "",
        race = raceFile,
        class = Tokenize(class),
        level = UnitLevel("player") or 60,
        talents = MythicTalents(),
        professions = profs,
        gear = { items = items },
    })
end

---------------------------------------------------------------------------
-- Panel and /wl sim
---------------------------------------------------------------------------
local function Show(kind)
    if InCombatLockdown() then W.Print(L("Not available in combat.")); return end
    local text = kind == "oxm" and W.SimOXM() or kind == "json" and W.SimJSON() or W.SimcProfile()
    W.TextPopup(kind == "oxm" and L("OXM (WSE JSON)") or kind == "json" and L("MythicSim (JSON)") or L("SimulationCraft (text)"), text,
        { hint = L("Ctrl+C to copy, then paste it in the simulator.") })
end

W.slash.sim = function(rest)
    rest = (rest or ""):lower()
    Show(rest:find("oxm") and "oxm" or rest:find("json") and "json" or "simc")
end

W.RegisterModule("SimExport", "Sim export", function(p)
    W.Title(p, L("Sim export"))
    W.Label(p, L("Export my character for a simulator (gear, enchants, gems, talents, professions)."), "GameFontHighlightSmall")
        :SetPoint("TOPLEFT", 16, -40)
    W.Button(p, L("SimulationCraft (text)"), 220, 26, function() Show("simc") end, { "/wl sim" }):SetPoint("TOPLEFT", 16, -66)
    W.Button(p, L("MythicSim (JSON)"), 220, 26, function() Show("json") end, { "/wl sim json" }):SetPoint("TOPLEFT", 246, -66)
    W.Button(p, L("OXM (WSE JSON)"), 220, 26, function() Show("oxm") end, { "/wl sim oxm" }):SetPoint("TOPLEFT", 476, -66)
    W.Check(p, L("Include the gear in my bags (for Top Gear)"), function() return db.bags end, function(v) db.bags = v end)
        :SetPoint("TOPLEFT", 12, -102)
    local info = W.Label(p, L("Sites for WoW: Forever:\n- SimulationCraft (Forever version of the SimC addon / sim)\n- mythicsim.com/wow-forever/sim : Import > Addon Import (JSON)\n- simsforever.com\nNo raidbots / wowsims.com sim for Forever yet."),
        "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, -136)
    info:SetWidth(700)
    info:SetJustifyH("LEFT")
    info:SetTextColor(0.7, 0.7, 0.7)
end)
