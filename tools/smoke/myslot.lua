-- WarLegend RaidTool - Myslot's text format in the simulated client (tools/smoke/scenario.lua, phase "Myslot format";
-- not shipped). A small model of the action bars, macros and key bindings (what the module reads and changes), then:
-- the exports below, made by Myslot 6.2.1's own code (lua-pb) before its removal, must give the same bytes when the
-- module exports the same bars, and import back to the same bars; messages of every field round-trip; damaged texts are
-- refused; the import changes nothing before the confirmation's click, and nothing in combat; a made-up profile cannot
-- stop it half-way nor print a line per entry; the saved profiles stay under their budget. On 29/10/2026, with both
-- codes loaded, 300 random messages gave the same bytes as lua-pb and read back the same both ways, cut payloads were
-- refused alike, and Myslot 6.2.1 imported the new code's exports (that check left with the old code).
local M, Check = ...
local W = WLRT
local MS = W.Space("Myslot")

---------------------------------------------------------------------------
-- The model: actions[slot] = { type, id, subType }, macros[index] = { name, icon, body }, binds = { {command, key1, key2} }
---------------------------------------------------------------------------
local model
local FUNCS = { "GetActionInfo", "PickupAction", "PlaceAction", "GetCursorInfo", "ClearCursor", "PickupSpell", "PickupItem",
    "PickupMacro", "GetMacroInfo", "GetNumMacros", "CreateMacro", "DeleteMacro", "GetNumBindings", "GetBinding", "SetBinding",
    "SaveBindings", "GetCurrentBindingSet", "IsPetActive", "IsWindowsClient", "date", "GetPetActionInfo", "PickupPetAction", "PickupPetSpell" }
local kept
local function Copy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = Copy(v) end
    return c
end
local function Install(state)
    model = { actions = Copy(state.actions or {}), macros = Copy(state.macros or {}), binds = Copy(state.binds or {}),
        known = state.known or {}, pet = state.pet or false, petBar = {}, cursor = nil, changes = 0 }
    if kept then return end
    kept = { g = {}, spell = C_Spell and C_Spell.PickupSpell, item = C_Item and C_Item.PickupItem,
        lines = C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines, clicks = C_ClickBindings and C_ClickBindings.SetProfileByInfo }
    for _, k in ipairs(FUNCS) do kept.g[k] = rawget(_G, k) end
    local function Changed() model.changes = model.changes + 1 end
    function GetActionInfo(slot) local a = model.actions[slot]; if a then return a[1], a[2], a[3] end end
    function PickupAction(slot)
        local a = model.actions[slot]
        model.actions[slot], model.cursor = model.cursor, a
        if a or model.actions[slot] then Changed() end
    end
    function PlaceAction(slot)
        if slot < 1 or slot > 180 then error("Usage: PlaceAction(slot)", 0) end -- the game may do this for a slot that does not exist
        if not model.cursor then return end
        model.actions[slot], model.cursor = model.cursor, model.actions[slot]
        Changed()
    end
    function GetCursorInfo() local c = model.cursor; if c then return c[1], c[2] end end
    function ClearCursor() model.cursor = nil end
    local function Spell(id)
        if id == 666 then error("bad spell", 0) end -- a number the game refuses with an error
        if model.known[id] then model.cursor = { "spell", id } end
    end
    local function Item(id) if model.known[id] then model.cursor = { "item", id } end end
    PickupSpell, PickupItem = Spell, Item
    if C_Spell then C_Spell.PickupSpell = Spell end
    if C_Item then C_Item.PickupItem = Item end
    if C_SpellBook then C_SpellBook.GetNumSpellBookSkillLines = function() return 0 end end
    if C_ClickBindings then
        C_ClickBindings.SetProfileByInfo = function(profile)
            model.clicks = profile
            error("bad click", 0) -- a made-up profile the game refuses
        end
    end
    function GetPetActionInfo() end
    function PickupPetSpell(id)
        if id == 666 then error("bad spell", 0) end
        model.cursor = { "petspell", id }
    end
    function PickupPetAction(slot)
        if model.cursor then model.petBar[slot], model.cursor = model.cursor[2], nil end
    end
    function PickupMacro(i) if model.macros[i] then model.cursor = { "macro", i } end end
    function GetMacroInfo(i) local m = model.macros[i]; if m then return m[1], m[2], m[3] end end
    function GetNumMacros()
        local a, c = 0, 0
        for i in pairs(model.macros) do if i <= 120 then a = a + 1 else c = c + 1 end end
        return a, c
    end
    function CreateMacro(name, icon, body, perChar)
        -- the game may refuse a name or a text with an error ("Refused": one it refuses for a reason of its own)
        if strlenutf8(name) > 16 or strlenutf8(body or "") > 255 or name == "Refused" then error("Usage: CreateMacro(...)", 0) end
        local first, last = 1, 120
        if perChar then first, last = 121, 150 end
        for i = first, last do
            if not model.macros[i] then model.macros[i] = { name, icon, body }; Changed(); return i end
        end
    end
    function DeleteMacro(i)
        local last = i <= 120 and 120 or 150
        if not model.macros[i] then return end
        for k = i, last - 1 do model.macros[k] = model.macros[k + 1] end
        model.macros[last] = nil
        Changed()
    end
    function GetNumBindings() return #model.binds end
    function GetBinding(i) local b = model.binds[i]; if b then return b[1], "", b[2], b[3] end end
    function SetBinding(key, command)
        for _, b in ipairs(model.binds) do
            if b[3] == key then b[3] = nil end
            if b[2] == key then b[2], b[3] = b[3], nil end
        end
        if command then
            local found
            for _, b in ipairs(model.binds) do if b[1] == command then found = b end end
            if not found then found = { command }; model.binds[#model.binds + 1] = found end
            if not found[2] then found[2] = key else found[3] = key end
        end
        Changed()
        return true
    end
    function SaveBindings() end
    function GetCurrentBindingSet() return 1 end
    function IsPetActive() return model.pet end
    function IsWindowsClient() return false end
    function date() return "Thu Oct 29 12:00:00 2026" end
end
local function Uninstall()
    if not kept then return end
    for _, k in ipairs(FUNCS) do rawset(_G, k, kept.g[k]) end
    if C_Spell then C_Spell.PickupSpell = kept.spell end
    if C_Item then C_Item.PickupItem = kept.item end
    if C_SpellBook then C_SpellBook.GetNumSpellBookSkillLines = kept.lines end
    if C_ClickBindings then C_ClickBindings.SetProfileByInfo = kept.clicks end
    kept, model = nil, nil
end

-- the bars of a character: spells and items on several bars (pages 1, 2, 6, 7 and 13), general and character macros
-- (a texture number as icon, an accent), key bindings with modifiers, a key outside Myslot's list (kept by its name),
-- a free command (a button click)
local FULL = {
    known = { [133] = true, [116] = true, [2136] = true, [1459] = true, [12051] = true, [10] = true, [6948] = true, [5512] = true },
    actions = { [1] = { "spell", 133 }, [2] = { "spell", 116 }, [3] = { "item", 6948 }, [4] = { "macro", 1 }, [5] = { "macro", 121 },
        [13] = { "spell", 2136 }, [25] = { "item", 5512 }, [72] = { "spell", 1459 }, [73] = { "spell", 12051 }, [120] = { "macro", 2 },
        [145] = { "spell", 10 } },
    macros = { [1] = { "Pull", "INV_Misc_QuestionMark", "/cast Fireball\n/stopattack" },
        [2] = { "Été", "Spell_Fire_FlameBolt", "#showtooltip\n/cast [@mouseover,harm][] Fireball" },
        [121] = { "Moi", 134400, "/use 6948" } },
    binds = { { "MOVEFORWARD", "W", "UP" }, { "JUMP", "SPACE" }, { "ACTIONBUTTON1", "1", "SHIFT-1" },
        { "TOGGLEAUTORUN", "NUMLOCK" }, { "TARGETNEARESTENEMY", "TAB", "CTRL-ALT-SHIFT-T" }, { "CLICK MyButton:LeftButton", "ALT-F" },
        { "ACTIONBUTTON2", "\195\150" } },
}
local EMPTY = { known = FULL.known }

-- made by Myslot 6.2.1's code (MySlot:Export, lua-pb, its base64 and CRC32) from FULL and EMPTY above, on 29/10/2026
local FIXTURES = {
    full = [[# Myslot
# Wow Version: 1.60.1
# Addon Version: 1.41.54
# Time: Thu Oct 29 12:00:00 2026
# PLAYER: Smoketest
# CLASS: Mage
# SPECIALIZATION: NONE_CAPS
# LEVEL: 60
#
# --------------------
KlYEFluhnuIKBwgBEAEYhQEKBggCEAEYdAoHCAMQAhikNgoGCAQQAxgBCgYI
BRADGHkKBwgNEAEY2BAKBwgZEAIYiCsKBwhIEAEYswsKBwhJEAEYk14KBgh4
EAMYAgoHCJEBEAEYChIOCAISBAhXEAAaBAhwEAASCAgIEgQIfRAAEg4IGhIE
CDgQABoECDgQARIICAsSBAhnEAASDghUEgQIchAAGgQIVBBwEiUI//8DEgQI
RhADehlDTElDSyBNeUJ1dHRvbjpMZWZ0QnV0dG9uEgwIGxIICAAQAHoCw5Ya
OwoEUHVsbBIaL2Nhc3QgRmlyZWJhbGwKL3N0b3BhdHRhY2sYASIVSU5WX01J
U0NfUVVFU1RJT05NQVJLGlAKBcOJdMOpEi8jc2hvd3Rvb2x0aXAKL2Nhc3Qg
W0Btb3VzZW92ZXIsaGFybV1bXSBGaXJlYmFsbBgCIhRTUEVMTF9GSVJFX0ZM
QU1FQk9MVBoaCgNNb2kSCS91c2UgNjk0OBh5IgYxMzQ0MDBwKnoJU21va2V0
ZXN0
# --------------------
# END OF MYSLOT]],
    empty = [[# Myslot
# Wow Version: 1.60.1
# Addon Version: 1.41.54
# Time: Thu Oct 29 12:00:00 2026
# PLAYER: Smoketest
# CLASS: Mage
# SPECIALIZATION: NONE_CAPS
# LEVEL: 60
#
# --------------------
KlYEFpAvrwBwKnoJU21va2V0ZXN0
# --------------------
# END OF MYSLOT]],
}

---------------------------------------------------------------------------
-- Messages: random ones of every field, compared field by field
---------------------------------------------------------------------------
local FIELDS = {
    Charactor = { { "slot", "Slot", true }, { "bind", "Bind", true }, { "macro", "Macro", true }, { "petslot", "Slot", true },
        { "cooldownManager", "string" }, { "clickBinding", "ClickBinding", true }, { "ver", "n" }, { "name", "string" } },
    Slot = { { "id", "n" }, { "type", "enum" }, { "index", "n" }, { "strindex", "string" } },
    Macro = { { "name", "string" }, { "body", "string" }, { "id", "n" }, { "icon", "string" } },
    Bind = { { "id", "n" }, { "key1", "Key" }, { "key2", "Key" }, { "command", "string" } },
    Key = { { "key", "n" }, { "mod", "n" }, { "keycode", "string" } },
    ClickBinding = { { "type", "n" }, { "actionID", "n" }, { "button", "string" }, { "modifiers", "n" } },
}
local REQUIRED = { Slot = { id = true, type = true, index = true }, Macro = { name = true, body = true, id = true, icon = true },
    Bind = { id = true }, Key = { key = true, mod = true }, ClickBinding = { type = true, actionID = true } }
local function Same(kind, a, b, path)
    for _, f in ipairs(FIELDS[kind]) do
        local x, y, p = a[f[1]], b[f[1]], path .. "." .. f[1]
        if f[3] then
            x, y = x or {}, y or {}
            if #x ~= #y then return false, p .. " count " .. #x .. " ~= " .. #y end
            for i = 1, #x do
                local ok, why = Same(f[2], x[i], y[i], p .. "[" .. i .. "]")
                if not ok then return false, why end
            end
        elseif FIELDS[f[2]] then
            if (x == nil) ~= (y == nil) then return false, p .. " present on one side" end
            if x then
                local ok, why = Same(f[2], x, y, p)
                if not ok then return false, why end
            end
        elseif x ~= y then
            return false, p .. " " .. tostring(x) .. " ~= " .. tostring(y)
        end
    end
    return true
end

local seed = 20261029.0
local function Rand(n) seed = (seed * 16807.0) % 2147483647.0; return math.floor(seed / 2147483647.0 * n) + 1 end
local NUMBERS = { 0, 1, 2, 127, 128, 255, 300, 16383, 16384, 65535, 2097151, 2097152, 268435455 }
local BIG = { 268435456, 2147483647, 2147483648, 4294967295 }
local function Num(big)
    if big and Rand(4) == 1 then return BIG[Rand(#BIG)] end
    if Rand(3) == 1 then return Rand(200000) end
    return NUMBERS[Rand(#NUMBERS)]
end
local PIECES = { "", "a", "Fireball", "/cast X\n/run print(1)", "\195\169t\195\169", "|cffff0000r|r", "\0\1\2",
    string.rep("x", 127), string.rep("y", 128), string.rep("z", 300) }
local function Str() return PIECES[Rand(#PIECES)] end
local function Make(kind, big, depth)
    local m = {}
    for _, f in ipairs(FIELDS[kind]) do
        local name, t = f[1], f[2]
        if f[3] then
            local n = Rand(4) - 1
            if n > 0 then
                m[name] = {}
                for i = 1, n do m[name][i] = Make(t, big, depth + 1) end
            end
        elseif REQUIRED[kind] and REQUIRED[kind][name] or Rand(3) > 1 then
            if t == "n" then m[name] = Num(big)
            elseif t == "enum" then m[name] = Rand(10)
            elseif t == "string" then m[name] = Str()
            else m[name] = Make(t, big, depth + 1) end
        end
    end
    return m
end


local function Body(text) -- the base64 lines of an export
    local out = {}
    for line in text:gmatch("[^\r\n]+") do if not line:find("^[#@]") then out[#out + 1] = line end end
    return table.concat(out, "\n")
end

-- the tab's widgets, found as the bench's paste phase finds them
local function Under(root, test)
    local stack = { root }
    while #stack > 0 do
        local o = table.remove(stack)
        if test(o) then return o end
        for _, c in ipairs(o.__children or {}) do stack[#stack + 1] = c end
    end
end
local function Click(b) M.Script(b, "OnClick", "LeftButton", false) end
local function Confirming() return rawget(_G, "WLRTConfirm") and WLRTConfirm:IsShown() or false end
local function Yes() if Confirming() then Click(WLRTConfirm.yes) end end
local function TabWidgets() -- the tab, shown: its panel, text box and Import button
    M.Call(W.Toggle, "Myslot")
    M.Advance(0.2)
    local panel
    for _, m in ipairs(W.modules) do if m.key == "Myslot" then panel = m.panel end end
    local box = panel and Under(panel, function(o) return o.__type == "EditBox" and o.__parent and o.__parent.__type == "ScrollFrame" end)
    local import = panel and Under(panel, function(o) return o.__type == "Button" and rawequal(o.__text, W.L("Import")) end)
    return panel, box, import
end

---------------------------------------------------------------------------
-- The checks
---------------------------------------------------------------------------
-- 1. the format: random messages written and read back (the same bytes as lua-pb wrote and read: checked against
-- Myslot 6.2.1's code on 29/10/2026, 300 messages, before it was removed)
do
    local bad, n = {}, 0
    for i = 1, 300 do
        local m = Make("Charactor", i > 200, 1) -- past 2^28 too
        local ok, back = pcall(MS.Decode, MS.Encode(m))
        local same, why = ok and Same("Charactor", m, back, "msg")
        if not same then bad[#bad + 1] = "message " .. i .. ": " .. tostring(why or back) end
        n = n + 1
    end
    Check("Myslot format: " .. n .. " messages of every field written and read back", #bad == 0, bad[1] and (#bad .. " problem(s): " .. bad[1]))
end

-- 2. a message with a required field missing: no payload (lua-pb's Serialize gave false), and refused when read
do
    local bytes = MS.Encode({ ver = 42, name = "x", slot = { { id = 1, type = 1 } } })
    local refused = not pcall(MS.Decode, "\10\4\8\1\16\1") -- slot { id = 1, type = SPELL }, no index
    Check("Myslot format: a required field missing is neither written nor read", bytes == "" and refused,
        "payload of " .. #bytes .. " bytes, partial message " .. (refused and "refused" or "read"))
end

-- 3. damaged texts: a payload cut anywhere, a text cut anywhere: refused or read, never a Lua error, under 1 s
do
    local m = Make("Charactor", false, 1)
    m.slot = { { id = 1, type = 1, index = 133 }, { id = 2, type = 3, index = 1, strindex = "x" } }
    local bytes, errs = MS.Encode(m), {}
    for cut = 0, #bytes - 1 do pcall(MS.Decode, bytes:sub(1, cut)) end
    local text = FIXTURES.full
    local t0 = os.clock()
    for cut = 0, #text do
        local ok, err = pcall(MS.Parse, text:sub(1, cut))
        if not ok then errs[#errs + 1] = cut .. ": " .. tostring(err) end
    end
    Check("Myslot format: " .. #bytes .. " cuts of a payload and " .. (#text + 1) .. " of a text refused or read without an error",
        #errs == 0 and os.clock() - t0 < 5, errs[1] or string.format("%.1f s", os.clock() - t0))
end

-- 4. Myslot 6.2.1's exports: read and written back to the same bytes, and the same bars exported to the same bytes
for _, case in ipairs({ { "full", FULL }, { "empty", EMPTY } }) do
    local name, state = case[1], case[2]
    local fixture = FIXTURES[name]
    local payload, crcOk = MS.Unarmor(fixture)
    local ok, msg = pcall(MS.Decode, payload or "")
    Check("Myslot format: the " .. name .. " export of Myslot 6.2.1 read and written back to the same bytes",
        crcOk and ok and MS.Encode(msg) == payload and Body(MS.Armor(payload, { "Myslot" }, "\n")) == Body(fixture),
        not crcOk and "CRC32 refused" or not ok and tostring(msg) or "different bytes")
    Install(state)
    local done, text = pcall(MS.Export, {})
    Uninstall()
    Check("Myslot format: the " .. name .. " bars exported as Myslot 6.2.1 exported them",
        done and Body(text) == Body(fixture), done and "different bytes" or tostring(text))
end

-- 5. the import, through the tab: nothing changes before the confirmation's click, then the bars are those of the
-- profile (exported again: the same bytes); a backup is saved; refused in combat; the delete tools ask first
do
    local _, box, import = TabWidgets()
    if not (box and import and MS.db) then
        Check("Myslot tab: import through the confirmation", false, "no text box / Import button in the tab")
    else
        local backups = MS.db.backups
        local before = {}
        for i, b in ipairs(backups) do before[i] = b end
        -- in combat: refused at the click, no question
        Install(EMPTY)
        box.__text = FIXTURES.full
        M.combat = true
        Click(import)
        local askedInCombat = Confirming()
        if askedInCombat then WLRTConfirm:Hide() end
        M.combat = false
        -- out of combat: the question, nothing changed before its Yes; a fight starting while it is open: refused
        Click(import)
        local asked, untouched = Confirming(), model.changes == 0
        M.combat = true
        Yes()
        M.combat = false
        local inFight = model.changes
        Click(import)
        Yes()
        local _, text = pcall(MS.Export, {})
        -- a macro starting with #showtooltip is made with the question mark icon (the game then shows the spell's)
        local expected = MS.Decode((MS.Unarmor(FIXTURES.full)))
        for _, m in ipairs(expected.macro) do if m.body:sub(1, 12) == "#showtooltip" then m.icon = "INV_MISC_QUESTIONMARK" end end
        Check("Myslot tab: Import asks first and changes nothing before its Yes, nothing in combat",
            asked and untouched and not askedInCombat and inFight == 0,
            not asked and "no confirmation" or askedInCombat and "asked in combat" or inFight > 0 and "changed in combat" or "changed before the Yes")
        Check("Myslot tab: the Yes puts back the profile's bars, macros and key bindings (exported again: the same bytes)",
            MS.Unarmor(text or "") == MS.Encode(expected), "bars not the profile's after the click")
        Check("Myslot tab: a backup of the bars is saved before the import", #backups == math.min(#before + 1, 3), #backups .. " backup(s)")
        -- the delete tools: asked first, done in the Yes
        local macros = 0
        for _ in pairs(model.macros) do macros = macros + 1 end
        M.Call(W.slash.myslot, "clear macro")
        local stillThere = next(model.macros) ~= nil
        Yes()
        Check("Myslot tab: /wl myslot clear macro asks, then deletes the " .. macros .. " macros in the Yes",
            macros > 0 and stillThere and next(model.macros) == nil, "macros left: " .. tostring(next(model.macros)))
        Uninstall()
        for k in pairs(backups) do backups[k] = nil end
        for i, b in ipairs(before) do backups[i] = b end
    end
    M.Call(W.Hide)
end

---------------------------------------------------------------------------
-- What a real export never holds (audit (b) of 29/10, L4 to L7): the game's limits, a text past them, a made-up profile
---------------------------------------------------------------------------
local function Text(msg) return MS.Armor(MS.Encode(msg), { "Myslot" }, "\n") end
local function ASlot(i) return { id = i, type = MS.SLOT.SPELL, index = 133 } end
local function AMacro(i) return { id = i, name = "M" .. i, body = "/cast X", icon = "I" } end
local function Profile(field, list) -- a spell on slot 1, unless the list is the slots
    local msg = { ver = 42, name = "x", slot = { ASlot(1) } }
    msg[field] = list
    return msg
end
local function List(n, make)
    local t = {}
    for i = 1, n do t[i] = make(i) end
    return t
end
local NOT_PROFILE = W.L("This text is not a Myslot profile.")

-- 6. each list at its limit is read whole, one more entry and the text is refused
do
    local bad = {}
    for _, c in ipairs({ { "slot", 180, ASlot }, { "petslot", 10, ASlot }, { "macro", 150, AMacro },
        { "bind", 1000, function(i) return { id = i, key1 = { key = 1, mod = 0 } } end },
        { "clickBinding", 100, function(i) return { type = 1, actionID = i, button = "BUTTON1", modifiers = 0 } end } }) do
        local field, max, make = c[1], c[2], c[3]
        local at, whyAt = MS.Parse(Text(Profile(field, List(max, make))))
        local over, why = MS.Parse(Text(Profile(field, List(max + 1, make))))
        if not at or #at[field] ~= max or at.leftOut ~= 0 then
            bad[#bad + 1] = max .. " " .. field .. " not read whole: " .. (at and (#at[field] .. " kept, left out " .. tostring(at.leftOut)) or tostring(whyAt))
        end
        if over or why ~= NOT_PROFILE then bad[#bad + 1] = (max + 1) .. " " .. field .. " not refused" end
    end
    Check("Myslot limits: 180 slots, 10 pet slots, 150 macros, 1000 bindings, 100 click bindings read whole, one more refused", #bad == 0, bad[1])
    -- the ids: on the edge of the bars, and once each
    local ids = MS.Parse(Text({ ver = 42, name = "x", slot = { ASlot(1), ASlot(180), ASlot(181), ASlot(0), ASlot(1) },
        petslot = { ASlot(1), ASlot(10), ASlot(11), ASlot(0), ASlot(1) } }))
    local s, p = ids and ids.slot or {}, ids and ids.petslot or {}
    Check("Myslot limits: slot ids outside 1-180 (pet slots: 1-10) or seen twice left out",
        #s == 2 and s[1].id == 1 and s[2].id == 180 and #p == 2 and p[1].id == 1 and p[2].id == 10 and ids.leftOut == 6,
        #s .. " slots, " .. #p .. " pet slots kept, left out: " .. tostring(ids and ids.leftOut))
    -- a text of nearly 500 KB, about 40,000 slot entries, refused; about 8 s in fengari (the game's Lua is about 10 times
    -- faster, measured on 28/10): in one pass only
    if M.locale == "enUS" then
        local text = Text(Profile("slot", List(38000, function() return ASlot(1) end)))
        local t0 = os.clock()
        local msg, why = MS.Parse(text)
        local took = os.clock() - t0
        Check(string.format("Myslot limits: a paste of %d KB with 38000 slots refused as no profile", #text / 1000),
            #text > 400000 and #text <= MS.MAX_TEXT and not msg and why == NOT_PROFILE and took < 30, string.format("%s, %.1f s", tostring(why), took))
    end
    -- a real export passes untouched
    local real = MS.Parse(FIXTURES.full)
    Check("Myslot limits: Myslot 6.2.1's export read whole, the same bytes",
        real and real.leftOut == 0 and MS.Encode(real) == MS.Unarmor(FIXTURES.full), real and ("left out: " .. tostring(real.leftOut)) or "refused")
end

-- 7. macros: the game counts letters (an accent takes 2 bytes), no code in a name
do
    local A = "\195\169" -- 2 bytes, 1 letter
    local msg = MS.Parse(Text(Profile("macro", {
        { id = 1, name = A:rep(16), body = A:rep(255), icon = "I" },
        { id = 2, name = A:rep(17), body = "/cast X", icon = "I" },
        { id = 3, name = "M3", body = A:rep(256), icon = "I" },
        { id = 4, name = "M4", body = ("\128"):rep(2000), icon = "I" }, -- bytes that make no letter
        { id = 5, name = "|T134400:0|tX\n", body = "/cast Y", icon = "I" },
    })))
    local kept = msg and msg.macro or {}
    Check("Myslot limits: a macro of 16 + 255 letters with accents kept, 17 or 256 letters or a text without letters left out",
        #kept == 2 and kept[1].id == 1 and msg.leftOut == 3, #kept .. " kept, left out: " .. tostring(msg and msg.leftOut))
    Check("Myslot limits: a |T code in a macro name is cleaned", kept[2] and kept[2].name == "T134400:0tX", tostring(kept[2] and kept[2].name))
end

-- the limit is on the text the game gets: a saved text can end with a line break, and it takes no letter there
do
    local A = "\195\169"
    local msg = MS.Parse(Text(Profile("macro", {
        { id = 1, name = "M1", body = A:rep(255) .. "\n", icon = "I" },
        { id = 2, name = "M2", body = "\r\n" .. ("/cast X\r\n"):rep(28) .. "/use Y\r\n", icon = "I" }, -- 230 letters without the \r
        { id = 3, name = "M3", body = A:rep(256) .. "\n", icon = "I" },
        { id = 4, name = "M4", body = (" "):rep(3000) .. "/cast X", icon = "I" }, -- past the bound that comes before the patterns
    })))
    local kept = msg and msg.macro or {}
    Check("Myslot limits: a line break and \\r take no letter (255 letters kept), 256 letters or a text past the bound left out",
        #kept == 2 and kept[1].id == 1 and kept[2].id == 2 and msg.leftOut == 2, #kept .. " kept, left out: " .. tostring(msg and msg.leftOut))
    local _, box, import = TabWidgets()
    if not (box and import and MS.db) then
        Check("Myslot limits: a macro of 255 letters saved with a line break", false, "no text box / Import button in the tab")
    else
        local backups, before = MS.db.backups, {}
        for i, b in ipairs(backups) do before[i] = b end
        Install({})
        box.__text = Text({ ver = 42, name = "x", slot = { { id = 2, type = MS.SLOT.MACRO, index = 1 } },
            macro = { { id = 1, name = "M1", body = A:rep(255) .. "\n", icon = "I" } } })
        Click(import)
        Yes()
        local a = model.actions[2]
        local made = a and model.macros[a[2]]
        Check("Myslot limits: a macro of 255 letters saved with a line break goes whole on its slot", made and made[3] == A:rep(255),
            made and (#made[3] .. " bytes") or "macro not on its slot")
        Uninstall()
        for k in pairs(backups) do backups[k] = nil end
        for i, b in ipairs(before) do backups[i] = b end
    end
    M.Call(W.Hide)
end

-- 8. through the tab, a made-up profile: slot ids that do not exist (for a macro: its PlaceAction is under no pcall), a
-- macro and values the game refuses with an error, spells and items not known: nothing before the Yes or in combat, no
-- Lua error, the import goes to its end (key bindings, pet bar, click bindings), one line for all
do
    local _, box, import = TabWidgets()
    if not (box and import and MS.db) then
        Check("Myslot limits: a made-up profile through the tab", false, "no text box / Import button in the tab")
    else
        local backups, before = MS.db.backups, {}
        for i, b in ipairs(backups) do before[i] = b end
        Install({ known = { [133] = true, [6948] = true }, pet = true })
        local slots = { ASlot(1), ASlot(500), { id = 1, type = MS.SLOT.ITEM, index = 6948 }, -- 500, slot 1 again
            { id = 2, type = MS.SLOT.MACRO, index = 1 }, { id = 3, type = MS.SLOT.MACRO, index = 5 },
            { id = 501, type = MS.SLOT.MACRO, index = 1 }, { id = 0, type = MS.SLOT.MACRO, index = 1 }, -- 501, 0
            { id = 30, type = MS.SLOT.SPELL, index = 666 } }
        for i = 10, 19 do slots[#slots + 1] = { id = i, type = MS.SLOT.SPELL, index = 90000 + i } end
        for i = 20, 24 do slots[#slots + 1] = { id = i, type = MS.SLOT.ITEM, index = 90000 + i } end
        box.__text = Text({ ver = 42, name = "x", slot = slots, macro = { AMacro(1),
            { id = 5, name = "|T134400:0|tX", body = "/cast Y", icon = "I" },
            { id = 6, name = ("n"):rep(17), body = "/cast Z", icon = "I" }, { id = 7, name = "M7", body = ("b"):rep(256), icon = "I" },
            { id = 8, name = "Refused", body = "/cast W", icon = "I" } },
            bind = { { id = 0xFFFF, command = "JUMP", key1 = { key = MS.KEYS.KEYCODE, mod = MS.MOD_KEYS.NONE, keycode = "F" } } },
            petslot = { { id = 1, type = MS.SLOT.SPELL, index = 777 }, { id = 2, type = MS.SLOT.SPELL, index = 666 },
                { id = 3, type = MS.SLOT.SPELL, index = 778 }, { id = 11, type = MS.SLOT.SPELL, index = 779 } },
            clickBinding = { { type = 1, actionID = 5, button = "BUTTON1", modifiers = 0 } } })
        local e0 = M.errorSeq or 0
        Click(import)
        local asked, untouched = Confirming(), model.changes == 0
        M.combat = true
        Yes()
        M.combat = false
        local inFight = model.changes
        Click(import)
        local prints = #M.prints
        Yes()
        local lines = #M.prints - prints
        local line = M.prints[prints + 2] or ""
        -- invalid: slots 500, 1 again, 501, 0, pet slot 11, 2 macros past the limits; refused: spell 666, pet spell 666, clicks
        local want = W.L("Myslot: left out: %d spell(s) not known, %d item(s) not found, %d macro(s), %d invalid entry(ies)."):format(10, 5, 1, 10)
        local first = W.L("First error: %s"):format("bad spell")
        local bound
        for _, b in ipairs(model.binds) do if b[1] == "JUMP" and b[2] == "F" then bound = true end end
        local a1, a2, a3 = model.actions[1], model.actions[2], model.actions[3]
        Check("Myslot limits: a made-up profile changes nothing before its Yes, nothing in combat", asked and untouched and inFight == 0,
            not asked and "no confirmation" or inFight > 0 and "changed in combat" or "changed before the Yes")
        Check("Myslot limits: slot ids 500, 501 and 0 and what the game refuses left out, no Lua error, the import goes to its end",
            (M.errorSeq or 0) == e0 and bound and a1 and a1[2] == 133 and a2 and model.actions[500] == nil and model.actions[501] == nil
                and model.actions[0] == nil and model.petBar[1] == 777 and model.petBar[3] == 778 and model.clicks ~= nil,
            (M.errorSeq or 0) > e0 and tostring(M.lastError) or not bound and "key binding not set"
                or not (model.petBar[1] and model.petBar[3]) and "pet bar not the profile's" or not model.clicks and "click bindings not reached" or "slots not the profile's")
        Check("Myslot limits: the macro's name on the bars has no code", a3 and model.macros[a3[2]] and model.macros[a3[2]][1] == "T134400:0tX",
            a3 and tostring(model.macros[a3[2]] and model.macros[a3[2]][1]) or "macro not on its slot")
        Check("Myslot limits: one line for all the entries left out, with the first error", lines == 2 and line:find(want, 1, true) ~= nil and line:find(first, 1, true) ~= nil,
            lines .. " line(s), the second: " .. line)
        Uninstall()
        for k in pairs(backups) do backups[k] = nil end
        for i, b in ipairs(before) do backups[i] = b end
    end
    M.Call(W.Hide)
end

-- 9. the 4 global strings of the export's header missing (the bench reads any ALL_CAPS global as its own name: hidden
-- here): Export works, and so the backup of an import
do
    local _, box, import = TabWidgets()
    local meta = getmetatable(_G)
    local index, talentText = meta.__index, W.TalentText
    local HIDDEN = { PLAYER = true, CLASS = true, TALENTS = true, LEVEL = true }
    meta.__index = function(t, k) if not HIDDEN[k] then return index(t, k) end end
    W.TalentText = function() return "31/0/20" end -- the line with TALENTS is written only with talents
    Install(FULL)
    local ok, text = pcall(MS.Export, {})
    Check("Myslot format: an export works with PLAYER, CLASS, TALENTS and LEVEL missing",
        ok and Body(text) == Body(FIXTURES.full) and text:find("# Player: ", 1, true) and text:find("# Class: ", 1, true)
            and text:find("# Talents: 31/0/20", 1, true) and text:find("# Level: ", 1, true), tostring(text):sub(1, 120))
    Uninstall()
    if box and import and MS.db then
        local backups, before = MS.db.backups, {}
        for i, b in ipairs(backups) do before[i] = b end
        Install(EMPTY)
        box.__text = FIXTURES.full
        Click(import)
        Yes()
        local a1 = model.actions[1]
        Check("Myslot format: an import works with those 4 strings missing (its backup is an export)", a1 and a1[2] == 133, "bars not the profile's")
        Uninstall()
        for k in pairs(backups) do backups[k] = nil end
        for i, b in ipairs(before) do backups[i] = b end
    else
        Check("Myslot format: an import works with those 4 strings missing (its backup is an export)", false, "no text box / Import button in the tab")
    end
    meta.__index, W.TalentText = index, talentText
    M.Call(W.Hide)
end

-- 10. the saved profiles, 4 MB in all: Save refuses past it, also a text that replaces a profile; the check at login
do
    local panel, box = TabWidgets()
    local save = panel and Under(panel, function(o) return o.__type == "Button" and rawequal(o.__text, W.L("Save")) end)
    local f = save and save.__parent
    local name = f and Under(f, function(o) return o.__type == "EditBox" and o.__parent == f end)
    if not (box and name and MS.db) then
        Check("Myslot saved: 4 MB of profiles at most", false, "no name box / Save button in the tab")
    else
        local kept = MS.db.exports
        local function Save(who, size)
            name.__text, box.__text = who, ("y"):rep(size)
            Click(save)
        end
        MS.db.exports = { { name = "A", value = ("x"):rep(MS.MAX_SAVED - 1000) } }
        local list = MS.db.exports
        Save("B", 1001)
        local refused = #list == 1
        Save("B", 1000)
        local saved = #list == 2 and #list[2].value == 1000
        Save("B", 1001)
        local replaceRefused = not Confirming() and #list[2].value == 1000
        Save("B", 999)
        Yes()
        local replaced = #list == 2 and #list[2].value == 999
        Check("Myslot saved: Save stops at 4 MB in all, a replaced profile no longer counts", refused and saved and replaceRefused and replaced,
            not refused and "past the budget: saved" or not saved and "up to the budget: not saved" or not replaceRefused and "replacing past the budget: asked" or "replacing within the budget: not done")
        MS.db.exports = kept
        local big, t = ("z"):rep(MS.MAX_TEXT), { exports = {}, backups = {} }
        for i = 1, 100 do t.exports[i] = { name = "P" .. i, value = big } end
        local prints = #M.prints
        MS.Sanitize(t)
        local size = 0
        for _, e in ipairs(t.exports) do size = size + #e.value end
        Check("Myslot saved: the check at login keeps 4 MB of 100 profiles of 500 KB, and says so in one line",
            #t.exports == 8 and size == MS.MAX_SAVED and #M.prints == prints + 1, #t.exports .. " profiles, " .. (#M.prints - prints) .. " line(s)")
    end
    M.Call(W.Hide)
end

return { Install = Install, Uninstall = Uninstall, FULL = FULL, EMPTY = EMPTY, FIXTURES = FIXTURES, Body = Body }
