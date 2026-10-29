-- WarLegend RaidTool - Myslot: the text format
-- A Myslot export is "#" comment lines, then the base64 of 8 header bytes { 42, 86, 4, 22, CRC32 big endian } and the
-- protobuf message Charactor of MySlot.proto (Myslot by Boshi Lian, Apache-2.0, see LICENSE). Written by hand for its 6
-- messages instead of the general lua-pb library (29/10): the bytes are the ones lua-pb wrote, so an export stays the
-- same for other Myslot users and for the saved exports (tools/smoke/scenario.lua "Myslot format" checks them):
-- fields in tag order, a nil field left out, repeated fields one by one (never packed), a message with a required field
-- missing is not written at all and not read either, an unknown slot type reads as missing.
-- Numbers stay below 2^53 (Lua 5.1 has only doubles): no bit operation outside the CRC.
local ns = WLRT.Space("Myslot")

local byte, char, sub, floor = string.byte, string.char, string.sub, math.floor
local concat = table.concat

-- {tag, name, type, rule}: "repeated" / "required", else optional; type = a message of this table, "string",
-- "uint32" or "enum" (a varint of 1 to 10, Slot.SlotType)
local SCHEMA = {
    Charactor = {
        { 1, "slot", "Slot", "repeated" }, { 2, "bind", "Bind", "repeated" }, { 3, "macro", "Macro", "repeated" },
        { 4, "petslot", "Slot", "repeated" }, { 5, "cooldownManager", "string" },
        { 6, "clickBinding", "ClickBinding", "repeated" }, { 14, "ver", "uint32" }, { 15, "name", "string" },
    },
    Slot = { { 1, "id", "uint32", "required" }, { 2, "type", "enum", "required" }, { 3, "index", "uint32", "required" },
        { 4, "strindex", "string" } },
    Macro = { { 1, "name", "string", "required" }, { 2, "body", "string", "required" }, { 3, "id", "uint32", "required" },
        { 4, "icon", "string", "required" } },
    Bind = { { 1, "id", "uint32", "required" }, { 2, "key1", "Key" }, { 3, "key2", "Key" }, { 15, "command", "string" } },
    Key = { { 1, "key", "uint32", "required" }, { 2, "mod", "uint32", "required" }, { 15, "keycode", "string" } },
    ClickBinding = { { 1, "type", "uint32", "required" }, { 2, "actionID", "uint32", "required" },
        { 3, "button", "string" }, { 4, "modifiers", "uint32" } },
}
-- Slot.SlotType values
ns.SLOT = { SPELL = 1, ITEM = 2, MACRO = 3, FLYOUT = 4, EMPTY = 5, EQUIPMENTSET = 6, SUMMONPET = 7, COMPANION = 8,
    SUMMONMOUNT = 9, OUTFIT = 10 }
local MAX_ENUM = 10
local byTag = {}
for name, fields in pairs(SCHEMA) do
    byTag[name] = {}
    for _, f in ipairs(fields) do byTag[name][f[1]] = f end
end
local function Wire(f) return (f[3] == "uint32" or f[3] == "enum") and 0 or 2 end

---------------------------------------------------------------------------
-- Encoding
---------------------------------------------------------------------------
local TWO32 = 4294967296
-- a uint32 as lua-pb wrote it: past 2^32 the low 32 bits; a negative number as the 64-bit two's complement (10 bytes)
local function Varint(out, n)
    if n ~= n or n == math.huge or n == -math.huge then n = 0 end
    n = floor(n)
    if n >= TWO32 then n = n % TWO32 end
    if n < 0 then
        local h, l = floor(n / TWO32) % TWO32, n % TWO32
        for _ = 1, 4 do out[#out + 1] = char(l % 128 + 128); l = floor(l / 128) end
        out[#out + 1] = char(l % 16 + (h % 8) * 16 + 128)
        n = floor(h / 8)
    end
    while n >= 128 do
        out[#out + 1] = char(n % 128 + 128)
        n = floor(n / 128)
    end
    out[#out + 1] = char(n)
end

local function Bytes(out, s)
    Varint(out, #s)
    out[#out + 1] = s
end

-- the bytes of msg as message `name`, or nil when a required field is missing anywhere (lua-pb's Serialize then gave
-- false: the export held no payload)
local function Encode(name, msg, depth)
    if type(msg) ~= "table" or depth > 4 then return nil end
    local out = {}
    for _, f in ipairs(SCHEMA[name]) do
        local v = msg[f[2]]
        if v == nil or v == false then
            if f[4] == "required" then return nil end
        else
            local tag, kind = f[1] * 8 + Wire(f), f[3]
            local list = f[4] == "repeated" and v or { v }
            if type(list) ~= "table" then return nil end
            for i = 1, #list do
                local item = list[i]
                Varint(out, tag)
                if kind == "uint32" or kind == "enum" then
                    if type(item) ~= "number" then return nil end
                    Varint(out, item)
                elseif kind == "string" then
                    if type(item) ~= "string" then return nil end
                    Bytes(out, item)
                else
                    local inner = Encode(kind, item, depth + 1)
                    if not inner then return nil end
                    Bytes(out, inner)
                end
            end
        end
    end
    return concat(out)
end

-- msg: plain tables shaped like MySlot.proto (Slot.type a number of ns.SLOT). Returns the payload, or "" when a
-- required field is missing (as lua-pb's export did)
function ns.Encode(msg)
    return Encode("Charactor", msg, 1) or ""
end

---------------------------------------------------------------------------
-- Decoding (untrusted text: every read bounded by the message's end, a malformed message raises an error)
---------------------------------------------------------------------------
-- a varint read as lua-pb read it (no wrap to 32 bits); 10 bytes at most
local function ReadVarint(s, pos, last)
    local n, mul = 0, 1
    for _ = 1, 10 do
        if pos > last then error("Myslot: varint cut", 0) end
        local b = byte(s, pos)
        pos = pos + 1
        if b < 128 then return n + b * mul, pos end
        n = n + (b - 128) * mul
        mul = mul * 128.0
    end
    error("Myslot: varint too long", 0)
end

local function Skip(s, pos, last, wire)
    if wire == 0 then
        local _, p = ReadVarint(s, pos, last)
        return p
    elseif wire == 1 then pos = pos + 8
    elseif wire == 5 then pos = pos + 4
    elseif wire == 2 then
        local len
        len, pos = ReadVarint(s, pos, last)
        pos = pos + len
    else
        error("Myslot: wire type " .. wire, 0)
    end
    if pos > last + 1 then error("Myslot: field cut", 0) end
    return pos
end

local function Decode(name, s, pos, last, depth)
    if depth > 4 then error("Myslot: too deep", 0) end
    local msg, tags = {}, byTag[name]
    while pos <= last do
        local key
        key, pos = ReadVarint(s, pos, last)
        local tag, wire = floor(key / 8), key % 8
        local f = tags[tag]
        if not f then
            pos = Skip(s, pos, last, wire)
        else
            if wire ~= Wire(f) then error("Myslot: wire type of " .. f[2], 0) end
            local kind, v = f[3]
            if wire == 0 then
                v, pos = ReadVarint(s, pos, last)
                if kind == "enum" and not (v >= 1 and v <= MAX_ENUM and v % 1 == 0) then v = nil end
            else
                local len
                len, pos = ReadVarint(s, pos, last)
                local stop = pos + len - 1
                if stop > last then error("Myslot: " .. f[2] .. " cut", 0) end
                if kind == "string" then v = sub(s, pos, stop) else v = Decode(kind, s, pos, stop, depth + 1) end
                pos = stop + 1
            end
            if f[4] == "repeated" then
                local list = msg[f[2]] or {}
                msg[f[2]] = list
                list[#list + 1] = v
            else
                msg[f[2]] = v
            end
        end
    end
    -- lua-pb's Parse refused a message with a required field missing (an unknown slot type counts as missing)
    for _, f in ipairs(SCHEMA[name]) do
        if f[4] == "required" and msg[f[2]] == nil then error("Myslot: missing " .. name .. "." .. f[2], 0) end
    end
    return msg
end

-- the Charactor message of a payload; raises an error on a malformed one
function ns.Decode(payload)
    return Decode("Charactor", payload, 1, #payload, 1)
end

---------------------------------------------------------------------------
-- base64 (with "=" padding), CRC32
---------------------------------------------------------------------------
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local ENC, DEC = {}, {}
for i = 1, 64 do
    local c = sub(B64, i, i)
    ENC[i - 1], DEC[byte(c)] = c, i - 1
end

function ns.Base64Encode(s)
    local out, n = {}, #s
    for i = 1, n - 2, 3 do
        local a, b, c = byte(s, i, i + 2)
        local v = a * 65536 + b * 256 + c
        out[#out + 1] = ENC[floor(v / 262144)] .. ENC[floor(v / 4096) % 64] .. ENC[floor(v / 64) % 64] .. ENC[v % 64]
    end
    local rest = n % 3
    if rest == 1 then
        local a = byte(s, n)
        out[#out + 1] = ENC[floor(a / 4)] .. ENC[(a % 4) * 16] .. "=="
    elseif rest == 2 then
        local a, b = byte(s, n - 1, n)
        out[#out + 1] = ENC[floor(a / 4)] .. ENC[(a % 4) * 16 + floor(b / 16)] .. ENC[(b % 16) * 4] .. "="
    end
    return concat(out)
end

-- every character outside the alphabet is skipped ("=" too, anywhere), a last group of 2 or 3 characters gives 1 or 2
-- bytes, as Myslot's decoder did
function ns.Base64Decode(text)
    local s = text:gsub("[^A-Za-z0-9%+/]", "")
    local out, n = {}, #s
    local full = n - n % 4
    for i = 1, full, 4 do
        local a, b, c, d = byte(s, i, i + 3)
        local v = DEC[a] * 262144 + DEC[b] * 4096 + DEC[c] * 64 + DEC[d]
        out[#out + 1] = char(floor(v / 65536), floor(v / 256) % 256, v % 256)
    end
    local rest = n - full
    if rest == 2 then
        local a, b = byte(s, full + 1, full + 2)
        out[#out + 1] = char(floor((DEC[a] * 64 + DEC[b]) / 16))
    elseif rest == 3 then
        local a, b, c = byte(s, full + 1, full + 3)
        local v = DEC[a] * 4096 + DEC[b] * 64 + DEC[c]
        out[#out + 1] = char(floor(v / 1024), floor(v / 4) % 256)
    end
    return concat(out)
end

local crcTable
local function CRC32(s)
    local band, bxor, rshift = bit.band, bit.bxor, bit.rshift
    if not crcTable then
        crcTable = {}
        for i = 0, 255 do
            local c = i
            for _ = 1, 8 do
                if c % 2 == 1 then c = bxor(0xEDB88320, rshift(c, 1)) else c = rshift(c, 1) end
            end
            crcTable[i] = c
        end
    end
    local crc = 0xFFFFFFFF
    for i = 1, #s do
        crc = bxor(rshift(crc, 8), crcTable[band(bxor(crc, byte(s, i)), 0xFF)])
    end
    return bxor(crc, 0xFFFFFFFF) % TWO32
end
ns.CRC32 = CRC32

---------------------------------------------------------------------------
-- The text
---------------------------------------------------------------------------
local VERSION = 42 -- MYSLOT_VER of Myslot 6.2.1
local LINE_LEN = 60

-- the export text of a payload, below the header lines (without "# "), as Myslot wrote it
function ns.Armor(payload, header, sep)
    local data = char(VERSION, 86, 4, 22, 0, 0, 0, 0) .. payload
    local crc = CRC32(data)
    data = char(VERSION, 86, 4, 22, floor(crc / 16777216), floor(crc / 65536) % 256, floor(crc / 256) % 256, crc % 256)
        .. payload
    local out = {}
    for _, line in ipairs(header) do out[#out + 1] = "# " .. line end
    out[#out + 1] = "# "
    out[#out + 1] = "# --------------------"
    local d = ns.Base64Encode(data)
    for i = 1, #d, LINE_LEN do out[#out + 1] = sub(d, i, i + LINE_LEN - 1) end
    out[#out + 1] = "# --------------------"
    out[#out + 1] = "# END OF MYSLOT"
    return concat(out, sep)
end

-- the payload of an export text and whether its CRC32 is right, or nil when it is too short to be one. The comment
-- lines go as Myslot removed them ("@" or "#" to the end of the line, the blank lines after it): linear patterns of one
-- class; the caller caps the text's size.
function ns.Unarmor(text)
    local s = type(text) == "string" and text or ""
    s = s:gsub("(@.[^\n]*\n*)", ""):gsub("(#.[^\n]*\n*)", "")
    local data = ns.Base64Decode(s)
    if #data < 8 then return nil end
    local b5, b6, b7, b8 = byte(data, 5, 8)
    local crc = ((b5 * 256.0 + b6) * 256 + b7) * 256 + b8 -- a float: past 2^31 also in the smoke bench's 32-bit integers
    local zeroed = sub(data, 1, 4) .. "\0\0\0\0" .. sub(data, 9)
    return sub(data, 9), crc == CRC32(zeroed)
end
