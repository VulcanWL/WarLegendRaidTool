-- WarLegend RaidTool - Myslot: reading the action bars, macros and key bindings, and putting them back
-- Based on Myslot 6.2.1 by Boshi Lian (Apache-2.0, see LICENSE), made into a module of WarLegend RaidTool on 29/10/2026:
-- same reading and restoring of the bars, macros, key bindings, pet bar and click bindings (and so the same exports,
-- Codec.lua); its retail parts left out (talent loadouts, Cooldown Manager, the pre-11.0 spellbook), the import made
-- in one go inside the confirmation's click (no timer: AGENTS.md rule 7), every macro and key binding that does more than
-- target or cast listed before it (W.MACRO_CMDS).
local W = WLRT
local L = W.L
local ns = W.Space("Myslot")

W.AddFR({
    ["Myslot: slot %d holds a \"%s\", which Myslot does not save: left out."] =
        "Myslot : l'emplacement %d contient un « %s », que Myslot ne sauvegarde pas : laissé de côté.",
    ["Myslot: key binding with the modifier \"%s\" left out (unknown to Myslot)."] =
        "Myslot : raccourci avec le modificateur « %s » laissé de côté (inconnu de Myslot).",
    ["Myslot: macro \"%s\" not created: no free macro slot."] = "Myslot : macro « %s » pas créée : plus de place pour une macro.",
    ["Myslot: unknown macro (id %s) left out."] = "Myslot : macro inconnue (id %s) laissée de côté.",
    ["Myslot: spell %s not known by this character, left out."] = "Myslot : sort %s inconnu de ce personnage, laissé de côté.",
    ["Myslot: item %s not found, left out."] = "Myslot : objet %s introuvable, laissé de côté.",
    ["Myslot: slot %d left as it was (error: %s)."] = "Myslot : emplacement %d laissé tel quel (erreur : %s).",
    ["Myslot: profile imported."] = "Myslot : profil importé.",
    ["This text is not a Myslot profile."] = "Ce texte n'est pas un profil Myslot.",
    ["This Myslot profile is damaged (wrong checksum): copy it again."] =
        "Ce profil Myslot est abîmé (somme de contrôle fausse) : copie-le à nouveau.",
    ["This Myslot profile holds nothing to import."] = "Ce profil Myslot ne contient rien à importer.",
    ["The text is too long to be a Myslot profile (500 KB at most)."] = "Le texte est trop long pour un profil Myslot (500 Ko au plus).",
    ["Macros in this profile: %d."] = "Macros dans ce profil : %d.",
    ["Macros with a command that is not targeting or casting (code, guild, chat...) (%d):"] =
        "Macros avec une commande qui ne cible ni ne lance de sort (code, guilde, chat...) (%d) :",
    ["Key bindings that click a button or run a macro (%d):"] = "Raccourcis qui cliquent un bouton ou lancent une macro (%d) :",
    ["Import only a profile you trust."] = "N'importe qu'un profil de confiance.",
    ["Time"] = "Heure",
})

local MAX_TEXT = 500000 -- a pasted text past it is no profile (it is decoded whole)
ns.MAX_TEXT = MAX_TEXT
local MAX_SLOT = 180     -- 15 pages of 12 action slots
local CUSTOM_BIND = 0xFFFF
local SLOT = ns.SLOT
local SLOT_TYPE = {
    spell = SLOT.SPELL, companion = SLOT.COMPANION, macro = SLOT.MACRO, item = SLOT.ITEM, flyout = SLOT.FLYOUT,
    petaction = SLOT.EMPTY, futurespell = SLOT.EMPTY, equipmentset = SLOT.EQUIPMENTSET, summonpet = SLOT.SUMMONPET,
    summonmount = SLOT.SUMMONMOUNT, outfit = SLOT.OUTFIT,
}
local MacroConsts = Constants and Constants.MacroConsts
local MAX_ACCOUNT = tonumber(_G.MAX_ACCOUNT_MACROS) or (MacroConsts and MacroConsts.MAX_ACCOUNT_MACROS) or 120
local MAX_CHARACTER = tonumber(_G.MAX_CHARACTER_MACROS) or (MacroConsts and MacroConsts.MAX_CHARACTER_MACROS) or 30
ns.MAX_ACCOUNT, ns.MAX_CHARACTER = MAX_ACCOUNT, MAX_CHARACTER

function ns.Print(msg) W.Print(msg) end

local function Page(slot) return math.ceil(slot / 12) end

-- skip = what Export / Import leave alone: { bars = { [page] = true }, account = , character = , bindings = , pet = ,
-- clicks = } (nothing skipped by default)

-- Click bindings (C_ClickBindings, in Forever's documentation) and a pet bar (a class that can have a pet)
function ns.HasClickBindings()
    return C_ClickBindings and C_ClickBindings.GetProfileInfo and C_ClickBindings.SetProfileByInfo and true or false
end
local PET_CLASSES = { HUNTER = true, WARLOCK = true, DEATHKNIGHT = true }
function ns.HasPetBar()
    local _, class = UnitClass("player")
    return PET_CLASSES[class] or (class == "MAGE" and (select(4, GetBuildInfo()) or 0) >= 30000) or false
end

---------------------------------------------------------------------------
-- Reading (the bars as a message of MySlot.proto, Codec.lua)
---------------------------------------------------------------------------
-- spells whose action slot shows another spell (an override): the base spell is saved
local function SpellOverrides()
    local map = {}
    local book = C_SpellBook
    if not (book and book.GetNumSpellBookSkillLines and book.GetSpellBookSkillLineInfo and book.GetSpellBookItemType
        and C_Spell and C_Spell.GetOverrideSpell and Enum.SpellBookSpellBank) then
        return map
    end
    for line = 1, book.GetNumSpellBookSkillLines() or 0 do
        local info = book.GetSpellBookSkillLineInfo(line)
        for i = 1, info and info.numSpellBookItems or 0 do
            local kind, id, spellId = book.GetSpellBookItemType(info.itemIndexOffset + i, Enum.SpellBookSpellBank.Player)
            if spellId then
                local new = C_Spell.GetOverrideSpell(spellId)
                if new ~= spellId then map[new] = spellId end
            elseif Enum.SpellBookItemType and kind == Enum.SpellBookItemType.Flyout and GetFlyoutInfo then
                local _, _, numSlots, known = GetFlyoutInfo(id)
                if known and numSlots > 0 then
                    for k = 1, numSlots do
                        local spellID, overrideID = GetFlyoutSlotInfo(id, k)
                        map[overrideID] = spellID
                    end
                end
            end
        end
    end
    return map
end

local function ReadMacro(id)
    local name, icon, body = GetMacroInfo(id)
    if not name then return nil end
    icon = gsub(strupper(icon or "INV_Misc_QuestionMark"), "INTERFACE\\ICONS\\", "")
    return { id = id, icon = icon, name = name, body = body }
end

local function ReadSlot(slot)
    local kind, index, subType = GetActionInfo(slot)
    local t = SLOT_TYPE[kind]
    local name
    if t == SLOT.EQUIPMENTSET then
        -- the set's number, from 0 (https://github.com/tg123/myslot/issues/10)
        if C_EquipmentSet and C_EquipmentSet.GetNumEquipmentSets then
            for i = 0, C_EquipmentSet.GetNumEquipmentSets() do
                if C_EquipmentSet.GetEquipmentSetInfo(i) == index then index = i; break end
            end
        end
    elseif t == SLOT.OUTFIT then
        -- the outfit's name too, found by name on another account
        local info = C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetOutfitInfo and C_TransmogOutfitInfo.GetOutfitInfo(index)
        if info then name = info.name end
    elseif not t then
        if kind then ns.Print(L("Myslot: slot %d holds a \"%s\", which Myslot does not save: left out."):format(slot, tostring(kind))) end
        return nil
    elseif kind == "macro" and subType then
        -- a macro showing a spell or an item gives that one: the macro's number is read from the cursor
        PickupAction(slot)
        local _
        _, index = GetCursorInfo()
        PlaceAction(slot)
    elseif kind == "spell" and subType == "assistedcombat" then
        index = C_AssistedCombat and C_AssistedCombat.GetActionSpell and C_AssistedCombat.GetActionSpell()
    elseif not index then
        return nil
    end
    local msg = { id = slot, type = t }
    if type(index) == "string" then msg.strindex, msg.index = index, 0 else msg.index = index end
    if name then msg.strindex = name end
    return msg
end

local function ReadPetSlot(slot)
    local name, _, isToken, _, _, _, spellID = GetPetActionInfo(slot)
    local msg = { id = slot, type = SLOT.SPELL }
    if isToken then msg.strindex, msg.index = name, 0
    elseif spellID then msg.index = spellID
    elseif not name then msg.index, msg.type = 0, SLOT.EMPTY
    else return nil end
    return msg
end

-- "CTRL-SHIFT-F" -> { key, mod } of Myslot's lists (keys.lua); a key outside the list is kept by its name
local function ReadKey(key)
    if not key then return nil end
    local mod
    local _, _, m, k = string.find(key, "(.+)-(.+)")
    if m and k then mod, key = m, k end
    mod = mod or "NONE"
    if not ns.MOD_KEYS[mod] then
        ns.Print(L("Myslot: key binding with the modifier \"%s\" left out (unknown to Myslot)."):format(mod))
        return nil
    end
    local msg = { mod = ns.MOD_KEYS[mod] }
    if ns.KEYS[key] then msg.key = ns.KEYS[key] else msg.key, msg.keycode = ns.KEYS.KEYCODE, key end
    return msg
end

local function ReadBinding(i)
    local command, _, key1, key2 = GetBinding(i)
    if not command then return nil end
    local msg = { id = ns.BINDS[command] }
    if not msg.id then msg.id, msg.command = CUSTOM_BIND, command end
    msg.key1, msg.key2 = ReadKey(key1), ReadKey(key2)
    if msg.key1 or msg.key2 then return msg end
end

-- the game state as a message (what Myslot 6.2.1's MySlot:Export serialized). Picks up and puts back a macro slot that
-- shows a spell: called from a click, out of combat
function ns.Read(skip)
    skip = skip or {}
    local bars = skip.bars or {}
    local msg = { ver = 42, name = UnitName("player"), macro = {}, slot = {}, bind = {}, petslot = {}, clickBinding = {} }
    if not skip.account then
        for i = 1, MAX_ACCOUNT do msg.macro[#msg.macro + 1] = ReadMacro(i) end
    end
    if not skip.character then
        for i = MAX_ACCOUNT + 1, MAX_ACCOUNT + MAX_CHARACTER do msg.macro[#msg.macro + 1] = ReadMacro(i) end
    end
    local overrides = SpellOverrides()
    for i = 1, MAX_SLOT do
        if not bars[Page(i)] then
            local m = ReadSlot(i)
            if m then
                if m.type == SLOT.SPELL and overrides[m.index] then m.index = overrides[m.index] end
                msg.slot[#msg.slot + 1] = m
            end
        end
    end
    if not skip.bindings then
        for i = 1, GetNumBindings() do msg.bind[#msg.bind + 1] = ReadBinding(i) end
    end
    if not skip.pet and IsPetActive() then
        for i = 1, tonumber(_G.NUM_PET_ACTION_SLOTS) or 10 do msg.petslot[#msg.petslot + 1] = ReadPetSlot(i) end
    end
    if not skip.clicks and ns.HasClickBindings() then
        for _, info in ipairs(C_ClickBindings.GetProfileInfo() or {}) do
            msg.clickBinding[#msg.clickBinding + 1] = { type = info.type, actionID = info.actionID or 0, button = info.button,
                modifiers = info.modifiers or 0 }
        end
    end
    return msg
end

-- the export text (the header: comments, read by nobody; then the data, Codec.lua) and the message it holds
function ns.Export(skip)
    local header = { "Myslot", "Wow Version: " .. (GetBuildInfo()),
        "Addon Version: " .. (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("WarLegendRaidTool", "Version") or "?"),
        L("Time") .. ": " .. date(), PLAYER .. ": " .. (UnitName("player") or "?"), CLASS .. ": " .. (UnitClass("player") or "?") }
    local talents = W.OwnTalents and W.TalentText and W.TalentText(W.OwnTalents())
    if talents then header[#header + 1] = TALENTS .. ": " .. talents end
    header[#header + 1] = LEVEL .. ": " .. (UnitLevel("player") or "?")
    local sep = IsWindowsClient and IsWindowsClient() and "\r\n" or "\n"
    local msg = ns.Read(skip)
    return ns.Armor(ns.Encode(msg), header, sep), msg
end

---------------------------------------------------------------------------
-- Reading a pasted text
---------------------------------------------------------------------------
local function Empty(t) return t == nil or next(t) == nil end

-- the message of a text, or nil and why (a sentence for the player)
function ns.Parse(text)
    if type(text) ~= "string" then return nil, L("This text is not a Myslot profile.") end
    if #text > MAX_TEXT then return nil, L("The text is too long to be a Myslot profile (500 KB at most).") end
    local payload, crcOk = ns.Unarmor(text)
    if not payload then return nil, L("This text is not a Myslot profile.") end
    if not crcOk then return nil, L("This Myslot profile is damaged (wrong checksum): copy it again.") end
    local ok, msg = pcall(ns.Decode, payload)
    if not ok or type(msg) ~= "table" then return nil, L("This text is not a Myslot profile.") end
    if Empty(msg.slot) and Empty(msg.bind) and Empty(msg.macro) and Empty(msg.clickBinding)
        and (msg.cooldownManager == nil or msg.cooldownManager == "") then
        return nil, L("This Myslot profile holds nothing to import.")
    end
    return msg
end

-- What the profile would do besides targeting and casting, said before every import. A profile pasted by someone else
-- can put on a bar or a key a macro that runs Lua code (/run), hands the guild over (/gleader) or leaves it (/gquit): an
-- allow list, not a block list (W.MACRO_CMDS, Settings.lua). Every command of a macro that is not on it, and every line
-- without "/" (the game says it in the chat), is listed with the macro's name; also the key bindings that click a button
-- or run a macro. max = lines shown per list. Returns the text and whether something was listed.
function ns.Risky(msg, max)
    local allowed = W.MACRO_CMDS or {}
    local macros, binds, count = {}, {}, 0
    for _, m in ipairs(msg.macro or {}) do
        count = count + 1
        local flagged, seen = {}, {}
        for line in (type(m.body) == "string" and m.body or ""):gmatch("[^\n]+") do
            local cmd = line:match("^%s*/([%a_]+)") -- "/cast[@mouseover] X" is "cast"
            local other
            if cmd then other = not allowed[cmd:lower()]
            else other = not (line:match("^%s*$") or line:match("^%s*#")) end
            if other then
                local what = cmd and ("/" .. cmd:lower()) or W.Plain(line, 40)
                if not seen[what] then seen[what] = true; flagged[#flagged + 1] = what end
            end
        end
        if #flagged > 0 then
            macros[#macros + 1] = W.Plain(tostring(m.name or "?"), 20) .. ": "
                .. table.concat(flagged, ", ", 1, math.min(#flagged, 8)) .. (#flagged > 8 and ", ..." or "")
        end
    end
    for _, b in ipairs(msg.bind or {}) do
        local cmd = b.id == CUSTOM_BIND and type(b.command) == "string" and b.command or ""
        if cmd:match("^CLICK ") or cmd:match("^MACRO ") then binds[#binds + 1] = W.Plain(cmd, 60) end
    end
    local function Shown(list)
        local shown = {}
        for i = 1, math.min(max, #list) do shown[i] = list[i] end
        return table.concat(shown, "\n") .. (#list > max and "\n..." or "")
    end
    local out = { L("Macros in this profile: %d."):format(count) }
    if #macros > 0 then
        out[#out + 1] = L("Macros with a command that is not targeting or casting (code, guild, chat...) (%d):"):format(#macros)
        out[#out + 1] = Shown(macros)
    end
    if #binds > 0 then
        out[#out + 1] = L("Key bindings that click a button or run a macro (%d):"):format(#binds)
        out[#out + 1] = Shown(binds)
    end
    out[#out + 1] = L("Import only a profile you trust.")
    return table.concat(out, "\n"), #macros + #binds > 0
end

---------------------------------------------------------------------------
-- Restoring (in the click of the import's confirmation, out of combat: bars, macros and bindings are protected in combat)
---------------------------------------------------------------------------
local function Unify(body) return strtrim((gsub(body or "", "\r", ""))) end

-- the character's macros by "name_body" and by body, read once per import
local function MacroIndex()
    local index = {}
    for i = 1, MAX_ACCOUNT + MAX_CHARACTER do
        local name, _, body = GetMacroInfo(i)
        if name then
            body = Unify(body)
            index[name .. "_" .. body] = i
            index[body] = i
        end
    end
    return index
end

local function FindMacro(m, index)
    local body = Unify(m.body)
    return index[(m.name or "") .. "_" .. body] or index[body]
end

-- an existing macro with that name and text, else a new one of its kind (general or character), else of the other
local function FindOrCreateMacro(m, index)
    local found = FindMacro(m, index)
    if found then return found end
    local body = Unify(m.body)
    local general, character = GetNumMacros()
    local generalFree, characterFree = general < MAX_ACCOUNT, character < MAX_CHARACTER
    local perChar
    if m.id > MAX_ACCOUNT then
        if characterFree then perChar = true elseif generalFree then perChar = false end
    else
        if generalFree then perChar = false elseif characterFree then perChar = true end
    end
    if perChar ~= nil then
        local icon = m.icon
        if strsub(body, 0, 12) == "#showtooltip" then icon = "INV_Misc_QuestionMark" end
        local id = CreateMacro(m.name, icon, body, perChar)
        if id then
            index[m.name .. "_" .. body], index[body] = id, id
            return id
        end
    end
    ns.Print(L("Myslot: macro \"%s\" not created: no free macro slot."):format(W.Plain(tostring(m.name), 30)))
end

local function Mounts()
    local mounts = {}
    local journal = C_MountJournal
    if not (journal and journal.GetDisplayedMountInfo) then return mounts end
    local n = journal.GetNumDisplayedMounts and journal.GetNumDisplayedMounts() or journal.GetNumMounts and journal.GetNumMounts() or 0
    for i = 1, n do
        local _, _, _, _, _, _, _, _, _, _, collected, mountID = journal.GetDisplayedMountInfo(i)
        if collected and mountID then mounts[mountID] = i end
    end
    return mounts
end

-- picks up what a slot of the profile holds (the cursor holds it after, or nothing)
local function PickUp(s, overrides, flyouts, mounts)
    local PickupSpell = C_Spell and C_Spell.PickupSpell or _G.PickupSpell
    local PickupItem = C_Item and C_Item.PickupItem or _G.PickupItem
    local t, index, name = s.type, s.index, s.strindex
    if t == SLOT.SPELL or t == SLOT.COMPANION then
        PickupSpell(index)
        if t == SLOT.SPELL then
            if not GetCursorInfo() and overrides[index] then PickupSpell(overrides[index]) end
            local GetSpellName = C_Spell and C_Spell.GetSpellName or _G.GetSpellInfo
            local spellName = not GetCursorInfo() and GetSpellName and GetSpellName(index)
            if spellName and spellName ~= "" then PickupSpell(spellName) end
            local FindBase = C_SpellBook and C_SpellBook.FindBaseSpellByID
            local base = not GetCursorInfo() and FindBase and FindBase(index)
            if base then PickupSpell(base) end
        end
        if not GetCursorInfo() then ns.Print(L("Myslot: spell %s not known by this character, left out."):format(tostring(index))) end
    elseif t == SLOT.FLYOUT then
        local flyout = flyouts[index]
        if flyout and C_SpellBook and C_SpellBook.PickupSpellBookItem then C_SpellBook.PickupSpellBookItem(flyout, Enum.SpellBookSpellBank.Player) end
        if not GetCursorInfo() then ns.Print(L("Myslot: spell %s not known by this character, left out."):format(tostring(index))) end
    elseif t == SLOT.ITEM then
        PickupItem(index)
        if not GetCursorInfo() then ns.Print(L("Myslot: item %s not found, left out."):format(tostring(index))) end
    elseif t == SLOT.SUMMONPET then
        if name and C_PetJournal and C_PetJournal.PickupPet then
            C_PetJournal.PickupPet(name, false)
            if not GetCursorInfo() then C_PetJournal.PickupPet(name, true) end
        end
    elseif t == SLOT.SUMMONMOUNT then
        if C_MountJournal and C_MountJournal.Pickup then
            if index == 0x0FFFFFFF then
                C_MountJournal.Pickup(0)
            else
                if mounts[index] then C_MountJournal.Pickup(mounts[index]) end
                local _, mountSpell
                if not GetCursorInfo() and C_MountJournal.GetMountInfoByID then _, mountSpell = C_MountJournal.GetMountInfoByID(index) end
                if mountSpell then PickupSpell(mountSpell) end
                if not GetCursorInfo() then C_MountJournal.Pickup(0) end -- a random mount instead
            end
        end
    elseif t == SLOT.EQUIPMENTSET then
        if C_EquipmentSet and C_EquipmentSet.PickupEquipmentSet then C_EquipmentSet.PickupEquipmentSet(index) end
    elseif t == SLOT.OUTFIT then
        local outfits = C_TransmogOutfitInfo
        if outfits and outfits.PickupOutfit then
            outfits.PickupOutfit(index)
            if not GetCursorInfo() and name and name ~= "" and outfits.GetOutfitInfoByName then
                local info = outfits.GetOutfitInfoByName(name)
                if info then outfits.PickupOutfit(info.outfitID) end
            end
        end
    end
end

local function Flyouts()
    local flyouts = {}
    local book = C_SpellBook
    if not (book and book.GetNumSpellBookSkillLines and book.GetSpellBookSkillLineInfo and book.GetSpellBookItemType
        and Enum.SpellBookSpellBank and Enum.SpellBookItemType) then
        return flyouts
    end
    for line = 1, book.GetNumSpellBookSkillLines() or 0 do
        local info = book.GetSpellBookSkillLineInfo(line)
        for i = 1, info and info.numSpellBookItems or 0 do
            local index = info.itemIndexOffset + i
            local kind, id = book.GetSpellBookItemType(index, Enum.SpellBookSpellBank.Player)
            if id and kind == Enum.SpellBookItemType.Flyout then flyouts[id] = index end
        end
    end
    return flyouts
end

local function SetKey(k, command)
    local mod, key = ns.R_MOD_KEYS[k.mod], ns.R_KEYS[k.key]
    if key == "KEYCODE" then key = k.keycode end
    -- a key or a command this client does not know (another game version, a made-up profile) is skipped
    if type(command) ~= "string" or type(mod) ~= "string" or type(key) ~= "string" then return end
    key = (mod ~= "NONE" and (mod .. "-") or "") .. key
    local context = 1
    if C_KeyBindings and C_KeyBindings.GetBindingContextForAction then context = C_KeyBindings.GetBindingContextForAction(command) end
    SetBinding(key, command, context)
end

-- puts the profile on the bars, macros, key bindings, pet bar and click bindings not skipped. In one go: called from
-- the click of the confirmation (never from a timer), out of combat
function ns.Restore(msg, skip)
    skip = skip or {}
    local bars = skip.bars or {}
    local overrides, flyouts, mounts = SpellOverrides(), Flyouts(), Mounts()

    -- macros, then the slots that show them
    local macroSlots, macroIds = {}, {}
    for _, s in ipairs(msg.slot or {}) do
        if s.type == SLOT.MACRO then
            macroSlots[s.index] = macroSlots[s.index] or {}
            table.insert(macroSlots[s.index], s.id)
        end
    end
    local index = MacroIndex()
    for _, m in ipairs(msg.macro or {}) do
        local newId
        if (not skip.account and m.id <= MAX_ACCOUNT) or (not skip.character and m.id > MAX_ACCOUNT) then
            newId = FindOrCreateMacro(m, index)
        end
        newId = newId or FindMacro(m, index)
        if newId then
            macroIds[m.id] = newId
            for _, slot in ipairs(macroSlots[m.id] or {}) do
                if not bars[Page(slot)] then
                    PickupMacro(newId)
                    PlaceAction(slot)
                    ClearCursor() -- what the slot held before (the game swaps it onto the cursor)
                end
            end
        else
            ns.Print(L("Myslot: unknown macro (id %s) left out."):format(tostring(m.id)))
        end
    end

    -- the other slots (a macro is in place already; an EMPTY one, a pet action or a future spell, is left as it is, as
    -- Myslot did); a slot of the chosen bars that the profile does not list is emptied
    local inProfile = {}
    for _, s in ipairs(msg.slot or {}) do
        local slot = s.id
        inProfile[slot] = true
        if not bars[Page(slot)] and s.type ~= SLOT.MACRO and s.type ~= SLOT.EMPTY then
            local kind, current = GetActionInfo(slot)
            local ok, err = pcall(function()
                if current ~= s.index or SLOT_TYPE[kind or ""] ~= s.type then
                    PickUp(s, overrides, flyouts, mounts)
                    if GetCursorInfo() then PlaceAction(slot) end
                    ClearCursor()
                end
            end)
            if not ok then
                ClearCursor()
                ns.Print(L("Myslot: slot %d left as it was (error: %s)."):format(slot, tostring(err)))
            end
        end
    end
    for slot = 1, MAX_SLOT do
        if not bars[Page(slot)] and not inProfile[slot] and GetActionInfo(slot) then
            PickupAction(slot)
            ClearCursor()
        end
    end

    if not skip.bindings then
        for _, b in ipairs(msg.bind or {}) do
            local command = b.id == CUSTOM_BIND and b.command or ns.R_BINDS[b.id]
            if b.key1 then pcall(SetKey, b.key1, command) end
            if b.key2 then pcall(SetKey, b.key2, command) end
        end
        SaveBindings(GetCurrentBindingSet())
    end

    if not skip.pet and IsPetActive() then
        local tokens = {}
        for i = 1, tonumber(_G.NUM_PET_ACTION_SLOTS) or 10 do
            local name, _, isToken = GetPetActionInfo(i)
            if isToken then tokens[name] = i end
        end
        for _, p in ipairs(msg.petslot or {}) do
            if p.strindex then
                if tokens[p.strindex] then
                    PickupPetAction(tokens[p.strindex])
                    PickupPetAction(p.id)
                end
            elseif p.index then
                PickupPetSpell(p.index)
                PickupPetAction(p.id)
            end
            ClearCursor()
        end
    end

    -- click bindings of a macro point at its number, which may have changed above
    if not skip.clicks and not Empty(msg.clickBinding) and ns.HasClickBindings() then
        local MACRO_TYPE = Enum.ClickBindingType and Enum.ClickBindingType.Macro or 2
        local profile = {}
        for _, c in ipairs(msg.clickBinding) do
            local action = c.actionID
            if c.type == MACRO_TYPE then action = macroIds[c.actionID] end
            if action then
                profile[#profile + 1] = { type = c.type, actionID = action, button = c.button, modifiers = c.modifiers or 0 }
            end
        end
        C_ClickBindings.SetProfileByInfo(profile)
    end
    ns.Print(L("Myslot: profile imported."))
end

-- "ACTION" (the pages of bars true in pages), "MACRO" (general and / or character macros), "BINDING" (every key
-- binding). From a click, out of combat
function ns.Clear(what, pages, general, character)
    if what == "ACTION" then
        for slot = 1, MAX_SLOT do
            if pages[Page(slot)] then
                PickupAction(slot)
                ClearCursor()
            end
        end
    elseif what == "MACRO" then
        if general then for i = MAX_ACCOUNT, 1, -1 do DeleteMacro(i) end end
        if character then for i = MAX_ACCOUNT + MAX_CHARACTER, MAX_ACCOUNT + 1, -1 do DeleteMacro(i) end end
    elseif what == "BINDING" then
        for i = 1, GetNumBindings() do
            local command, _, key1, key2 = GetBinding(i)
            for _, key in ipairs({ key1 or false, key2 or false }) do
                if key then
                    local context = 1
                    if C_KeyBindings and C_KeyBindings.GetBindingContextForAction then context = C_KeyBindings.GetBindingContextForAction(command) end
                    SetBinding(key, nil, context)
                end
            end
        end
        SaveBindings(GetCurrentBindingSet())
    end
end
