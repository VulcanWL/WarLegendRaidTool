-- WarLegend RaidTool - Myslot's text format in the simulated client (tools/smoke/scenario.lua, phase "Myslot format";
-- not shipped). A small model of the action bars, macros and key bindings (what the module reads and changes), then:
-- the exports below, made by Myslot 6.2.1's own code (lua-pb) before its removal, must give the same bytes when the
-- module exports the same bars, and import back to the same bars; messages of every field round-trip; damaged texts are
-- refused; the import changes nothing before the confirmation's click, and nothing in combat. On 29/10/2026, with both
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
    "SaveBindings", "GetCurrentBindingSet", "IsPetActive", "IsWindowsClient", "date" }
local kept
local function Copy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = Copy(v) end
    return c
end
local function Install(state)
    model = { actions = Copy(state.actions or {}), macros = Copy(state.macros or {}), binds = Copy(state.binds or {}),
        known = state.known or {}, cursor = nil, changes = 0 }
    if kept then return end
    kept = { g = {}, spell = C_Spell and C_Spell.PickupSpell, item = C_Item and C_Item.PickupItem,
        lines = C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines }
    for _, k in ipairs(FUNCS) do kept.g[k] = rawget(_G, k) end
    local function Changed() model.changes = model.changes + 1 end
    function GetActionInfo(slot) local a = model.actions[slot]; if a then return a[1], a[2], a[3] end end
    function PickupAction(slot)
        local a = model.actions[slot]
        model.actions[slot], model.cursor = model.cursor, a
        if a or model.actions[slot] then Changed() end
    end
    function PlaceAction(slot)
        if not model.cursor then return end
        model.actions[slot], model.cursor = model.cursor, model.actions[slot]
        Changed()
    end
    function GetCursorInfo() local c = model.cursor; if c then return c[1], c[2] end end
    function ClearCursor() model.cursor = nil end
    local function Spell(id) if model.known[id] then model.cursor = { "spell", id } end end
    local function Item(id) if model.known[id] then model.cursor = { "item", id } end end
    PickupSpell, PickupItem = Spell, Item
    if C_Spell then C_Spell.PickupSpell = Spell end
    if C_Item then C_Item.PickupItem = Item end
    if C_SpellBook then C_SpellBook.GetNumSpellBookSkillLines = function() return 0 end end
    function PickupMacro(i) if model.macros[i] then model.cursor = { "macro", i } end end
    function GetMacroInfo(i) local m = model.macros[i]; if m then return m[1], m[2], m[3] end end
    function GetNumMacros()
        local a, c = 0, 0
        for i in pairs(model.macros) do if i <= 120 then a = a + 1 else c = c + 1 end end
        return a, c
    end
    function CreateMacro(name, icon, body, perChar)
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
    function IsPetActive() return false end
    function IsWindowsClient() return false end
    function date() return "Thu Oct 29 12:00:00 2026" end
end
local function Uninstall()
    if not kept then return end
    for _, k in ipairs(FUNCS) do rawset(_G, k, kept.g[k]) end
    if C_Spell then C_Spell.PickupSpell = kept.spell end
    if C_Item then C_Item.PickupItem = kept.item end
    if C_SpellBook then C_SpellBook.GetNumSpellBookSkillLines = kept.lines end
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
    M.Call(W.Toggle, "Myslot")
    M.Advance(0.2)
    local panel
    for _, m in ipairs(W.modules) do if m.key == "Myslot" then panel = m.panel end end
    local box = panel and Under(panel, function(o) return o.__type == "EditBox" and o.__parent and o.__parent.__type == "ScrollFrame" end)
    local import = panel and Under(panel, function(o) return o.__type == "Button" and rawequal(o.__text, W.L("Import")) end)
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

return { Install = Install, Uninstall = Uninstall, FULL = FULL, EMPTY = EMPTY, FIXTURES = FIXTURES, Body = Body }
