-- WarLegend RaidTool - Verify (dev addon: internal testing only, never in the release zip, see AGENTS.md)
-- /wl verify: checks in the real client what the code alone cannot prove (API present, formats returned by the game),
-- then runs the test of every module switched on and counts the Lua errors. Reads only: never sends a message.
-- Each line goes to the chat with the tag [WLRT-VERIFY] and the chat log is switched on (Logs\WoWChatLog.txt), so the
-- lines can be read from outside the game while it runs (node tools/verify-live.js); the last 5 runs are also saved
-- in WarLegendRaidTool_DevDB (its own file, written at /reload or logout).
-- From login it also watches the session (audit of 29/10, probes for 5/11): name forms the game gives, our chat lines and
-- whether the server echoes them, our restricted calls and whether they worked, blocked actions. Still sends nothing:
-- play the session (raid, loot, battleground), then /wl verify quick reports what was seen. Also: the channel and sender
-- form of our addon messages, and what the game really hides in a fight (C_Secrets).
-- One command: /wl verify runs everything, then opens the whole report (context, every line, modules tested, our Lua
-- errors with their stack) already selected: Ctrl+C, paste it to Claude. /wl verify copy opens the last report again.
local W = WLRT
local L = W.L
local db

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
    if name ~= "WarLegendRaidTool_Dev" then return end
    self:UnregisterEvent("ADDON_LOADED")
    if type(WarLegendRaidTool_DevDB) ~= "table" then WarLegendRaidTool_DevDB = {} end
    db = WarLegendRaidTool_DevDB
end)

W.AddFR({
    ["Verify: not in combat."] = "Vérification : pas en combat.",
    ["Verify: done, %d OK, %d to look at, %d skipped. /reload to save the run."] =
        "Vérification : finie, %d OK, %d à regarder, %d sautés. /reload pour enregistrer.",
    ["Verify: module tests running (about 70 s), then the report opens to copy."] =
        "Vérification : tests des modules en cours (environ 70 s), puis le rapport s'ouvre pour le copier.",
    ["Verify: chat log switched off."] = "Vérification : journal du chat éteint.",
    ["WLRT verify report"] = "Rapport de vérification WLRT",
    ["All selected: Ctrl+C, then paste it to Claude."] = "Tout est sélectionné : Ctrl+C, puis colle-le à Claude.",
    ["Verify: no report yet. Type /wl verify."] = "Vérification : pas encore de rapport. Tape /wl verify.",
})

local TAG = "[WLRT-VERIFY] "
local MAX_LINES, MAX_LEN, MAX_RUNS = 150, 300, 5
local MAX_ERRORS, STACK_LINES, MAX_ADDONS = 10, 8, 60
local run, counts

local function Str(v)
    v = W.Safe(v)
    if v == nil then return "nil" end
    return tostring(v)
end

-- status: OK (as expected), LOOK (to read: a format or value the code depends on), SKIP (could not run here), INFO
local function Out(status, id, text)
    local line = W.CutUTF8(status .. " " .. id .. ": " .. tostring(text), MAX_LEN)
    W.Print(TAG .. line)
    if run then
        if #run.lines < MAX_LINES then run.lines[#run.lines + 1] = line else run.dropped = (run.dropped or 0) + 1 end
    end
    if counts and counts[status] then counts[status] = counts[status] + 1 end
end

local function Kind(v) return v == nil and "missing" or type(v) end

local probes = {}
local function Probe(id, fn) probes[#probes + 1] = { id = id, fn = fn } end

Probe("client", function()
    local version, build, date, toc = GetBuildInfo()
    local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    Out("INFO", "client", string.format("%s build %s (%s) toc %s, addon %s, forever %s", Str(version), Str(build),
        Str(date), Str(toc), Str(meta and meta("WarLegendRaidTool", "Version")), Str(W.FOREVER)))
end)

Probe("names", function()
    local n, r = UnitFullName("player")
    local bytes = { string.byte(W.NAME_SEP or "", 1, -1) }
    Out("INFO", "names", string.format("UnitFullName=%s|%s UnitName=%s W.UnitFullName=%s sep bytes=%s",
        Str(n), Str(r), Str(UnitName("player")), Str(W.UnitFullName("player")), table.concat(bytes, ",")))
end)

-- audit M1: the master loot candidate names must carry the surname, or LootCouncil's first-name match is used
Probe("masterloot", function()
    local method = (C_PartyInfo and C_PartyInfo.GetLootMethod and C_PartyInfo.GetLootMethod())
        or (GetLootMethod and GetLootMethod())
    local items = GetNumLootItems and GetNumLootItems() or 0
    if not GetMasterLootCandidate or items == 0 then
        Out("SKIP", "masterloot", "method " .. Str(method) .. ": open a loot window as master looter, then /wl verify")
        return
    end
    local names, short = {}, 0
    for i = 1, 40 do
        local name = W.Safe(GetMasterLootCandidate(1, i))
        if name then
            names[#names + 1] = name
            if not W.HasFullPart(name) then short = short + 1 end
        end
    end
    if #names == 0 then Out("SKIP", "masterloot", "no candidate for slot 1 (method " .. Str(method) .. ")"); return end
    local sample = table.concat(names, ", ", 1, math.min(5, #names))
    if short == 0 then
        Out("OK", "masterloot", #names .. " candidates, all full names: " .. sample)
    else
        Out("LOOK", "masterloot", short .. " / " .. #names .. " candidates without surname (audit M1): " .. sample)
    end
end)

Probe("slot18", function()
    local ok, id = pcall(GetInventorySlotInfo, "RangedSlot")
    Out("INFO", "slot18", string.format("RangedSlot=%s link18=%s", ok and Str(id) or "error",
        Str(GetInventoryItemLink("player", 18))))
end)

Probe("range", function()
    Out("INFO", "range", string.format("IsItemInRange %s, C_Item.IsItemInRange %s", Kind(IsItemInRange),
        Kind(C_Item and C_Item.IsItemInRange)))
end)

-- Upgrades (stat weights) reads an item's hit / crit as ratings, 10 / 8 / 14 per 1 %; Forever's tooltips write them as
-- percents (TOOLTIP_ITEM_STAT_HIT_PERCENT): values of 1 to 5 here are percents, then the weights are 10 to 14 times too weak
Probe("itemstats", function()
    local GetStats = (C_Item and C_Item.GetItemStats) or _G.GetItemStats
    if not GetStats then Out("LOOK", "itemstats", "no GetItemStats"); return end
    local seen, biggest, first = {}, 0, nil
    for slot = 1, 19 do
        local link = GetInventoryItemLink("player", slot)
        local ok, stats = false, nil
        if link then ok, stats = pcall(GetStats, link) end
        if ok and type(stats) == "table" then
            for k, v in pairs(stats) do
                v = W.Safe(v)
                if type(k) == "string" and type(v) == "number" and (k:find("HIT", 1, true) or k:find("CRIT", 1, true)) then
                    local name = k:gsub("^ITEM_MOD_", ""):gsub("_SHORT$", "")
                    seen[#seen + 1] = slot .. " " .. name .. "=" .. v
                    if v > biggest then biggest = v end
                    first = first or slot
                end
            end
        end
    end
    if #seen == 0 then Out("SKIP", "itemstats", "nothing with hit / crit worn: put one on, then /wl verify quick"); return end
    Out(biggest <= 5 and "LOOK" or "OK", "itemstats", (biggest <= 5 and "percents? " or "ratings: ") .. table.concat(seen, ", "))
    -- that item's tooltip line with a "%" (a percent stat reads "... by 1%.")
    local tip = C_TooltipInfo and C_TooltipInfo.GetInventoryItem and select(2, pcall(C_TooltipInfo.GetInventoryItem, "player", first))
    if type(tip) == "table" and type(tip.lines) == "table" then
        for _, line in ipairs(tip.lines) do
            local text = W.Safe(line.leftText)
            if type(text) == "string" and text:find("%", 1, true) then Out("INFO", "itemstats", "tooltip: " .. text); break end
        end
    end
end)

-- money text: Forever has only C_CurrencyInfo's (no global; LootTriage, MoneyGoal, QualityOfLife use it first)
Probe("coins", function()
    local fn = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString
    Out(fn and "OK" or "LOOK", "coins", string.format("C_CurrencyInfo.GetCoinTextureString %s, global %s", Kind(fn),
        Kind(_G.GetCoinTextureString)))
end)

-- old globals that only Blizzard's deprecation addons define on this client (EllesmereUI: Forever loads none of them)
Probe("oldglobals", function()
    local missing, present = {}, {}
    for _, name in ipairs({ "GetItemInfo", "GetItemInfoInstant", "GetItemCount", "GetItemIcon", "GetItemQualityColor",
        "GetDetailedItemLevelInfo", "GetItemCooldown", "GetCoinTextureString", "GetTalentInfo", "GetSpecialization",
        "GetSpecializationInfo", "GetSpecializationInfoByID", "IsItemInRange", "GetProfessions", "GetSkillLineInfo",
        "GetMasterLootCandidate", "GiveMasterLoot", "PickupContainerItem", "SendChatMessage" }) do
        local list = _G[name] == nil and missing or present
        list[#list + 1] = name
    end
    Out("INFO", "oldglobals", "missing: " .. table.concat(missing, " "))
    Out("INFO", "oldglobals", "present: " .. table.concat(present, " "))
end)

-- EllesmereUI calls Forever "realmless" (its per-character keys use the ruleset); ours use the realm name
Probe("realm", function()
    Out("INFO", "realm", "GetRealmName=" .. Str(GetRealmName and GetRealmName()))
end)

-- the size read in the deflate codes before inflating (W.InflatedSize) must work on the client's own deflate
Probe("encoding", function()
    local EU = C_EncodingUtil
    if not (EU and EU.CompressString and EU.EncodeBase64) then Out("LOOK", "encoding", "C_EncodingUtil missing"); return end
    local plain = string.rep("WLRT verify ", 60)
    local ok, packed = pcall(function() return EU.EncodeBase64(EU.CompressString(plain)) end)
    if not ok then Out("LOOK", "encoding", "compress error " .. Str(packed)); return end
    if W.Inflate(packed, 4096) == plain then Out("OK", "encoding", "round trip " .. #plain .. " -> " .. #packed)
    else Out("LOOK", "encoding", "W.Inflate refused the client's own deflate") end
end)

Probe("api", function()
    Out("INFO", "api", string.format("GetTradePlayerItemLink %s, C_Traits %s, C_ChatInfo.SendAddonMessage %s",
        Kind(GetTradePlayerItemLink), Kind(C_Traits), Kind(C_ChatInfo and C_ChatInfo.SendAddonMessage)))
end)

Probe("cvar", function()
    local get = (C_CVar and C_CVar.GetCVar) or GetCVar
    Out("INFO", "cvar", "nameplateMaxDistance=" .. Str(get and get("nameplateMaxDistance")))
end)

Probe("raid", function()
    if not W.raidLoaded then W.LoadRaid() end
    Out(W.raidLoaded and "OK" or "LOOK", "raid", "raid modules loaded: " .. Str(W.raidLoaded))
end)

Probe("memory", function()
    if not (UpdateAddOnMemoryUsage and GetAddOnMemoryUsage) then Out("SKIP", "memory", "no memory API"); return end
    UpdateAddOnMemoryUsage()
    local parts = {}
    for _, a in ipairs({ "WarLegendRaidTool", "WarLegendRaidTool_Raid", "WarLegendRaidTool_PvP", "WarLegendRaidTool_Skyborne" }) do
        parts[#parts + 1] = string.format("%s %.0f KB", a, GetAddOnMemoryUsage(a) or 0)
    end
    Out("INFO", "memory", table.concat(parts, ", "))
end)

---------------------------------------------------------------------------
-- Session watch (audit of 29/10): only the session itself can show these. Reads only.
---------------------------------------------------------------------------
local SEP = W.NAME_SEP or " "
local SEP_PAT = (SEP:gsub("%W", "%%%0"))
local HELPERS = { ["Core.lua"] = true, ["Lib.lua"] = true, ["Audit.lua"] = true }
local watchErrors = 0

-- the module that asked: first file:line of our shipped addons in the stack, outside the shared helpers; ours = such a
-- frame is in the stack (Blizzard's raid window calls SetRaidSubgroup too). A tail call ("return W.SendChat(...)")
-- leaves no frame: the line shown is then its caller's.
local function Caller()
    local first, best, ours
    for level = 2, 14 do
        local s = debugstack and debugstack(level, 1, 0) or ""
        if s == "" then break end
        local mine = s:find("WarLegendRaidTool", 1, true) and not s:find("WarLegendRaidTool_Dev", 1, true)
        local file, line = s:match("([%w_]+%.lua)%D+(%d+)")
        if file and file ~= "Verify.lua" then
            first = first or (file .. ":" .. line)
            if mine then
                ours = true
                if not best and not HELPERS[file] then best = file .. ":" .. line end
            end
        end
    end
    return best or first or "?", ours
end

-- a name's form without the name: letters -> "a", the surname separator -> "_" ("a-a", "a_a", "a")
local function Shape(name)
    if type(name) ~= "string" then return Str(name) end
    name = W.CutUTF8(name, 60):gsub(SEP_PAT, "_")
    return (name:gsub("[%a\128-\255]+", "a"))
end

-- the full name the game gives for a GUID ("First Surname": the surname comes in the realm slot)
local function GuidFull(guid)
    if not (guid and GetPlayerInfoByGUID) then return nil end
    local ok, _, _, _, _, _, name, realm = pcall(GetPlayerInfoByGUID, guid)
    name, realm = W.Safe(name), W.Safe(realm)
    if not ok or type(name) ~= "string" or name == "" then return nil end
    if type(realm) == "string" and realm ~= "" and not name:find(SEP .. realm, 1, true) then return name .. SEP .. realm end
    return name
end

-- HIGH 2: the raw name of a whisper / invite / invite confirmation, and what W.FullName makes of it vs the GUID's name
local nameSeen = { whisper = {}, invite = {}, confirm = {} }
local function NoteName(kind, raw, guid)
    local seen = nameSeen[kind]
    raw, guid = W.Safe(raw), W.Safe(guid)
    if seen.n == 5 or type(raw) ~= "string" then return end
    raw = W.CutUTF8(raw, 60)
    local want, got = GuidFull(guid), W.FullName(raw)
    local entry = Shape(raw) .. ">" .. Shape(got) .. (want == nil and " (no GUID name)"
        or want == got and " same as GUID" or (" GUID gives " .. Shape(want) .. " DIFFERS"))
    if not seen[entry] then
        seen[entry] = true
        seen.n = (seen.n or 0) + 1
        seen[seen.n] = entry
    end
end

-- HIGH 6: our chat lines (the ones our modules send) and whether the server echoes them back
local sent, settling, listening = {}, false, false
local echo = CreateFrame("Frame")
local ECHO = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_CHANNEL" }
local function Listen(on)
    if on == listening then return end
    listening = on
    for _, e in ipairs(ECHO) do
        if on then pcall(echo.RegisterEvent, echo, e) else echo:UnregisterEvent(e) end
    end
end
local function Settle()
    local now, waiting = GetTime(), false
    for _, s in ipairs(sent) do
        if s.ok and s.echo == nil then
            if now - s.t > 10 then s.echo = false else waiting = true end
        end
    end
    if waiting then W.After(5, Settle, "verify echo") else settling = false; Listen(false) end
end
-- the chat events only listened to while a line of ours waits for its echo (10 s at most)
echo:SetScript("OnEvent", function(_, event, text, _, _, _, _, _, _, _, _, _, _, guid)
    text = W.Safe(text)
    if type(text) ~= "string" then return end
    if event ~= "CHAT_MSG_WHISPER_INFORM" then
        guid = W.Safe(guid)
        if guid and guid ~= UnitGUID("player") then return end
    end
    local key = text:sub(1, 40)
    for _, s in ipairs(sent) do
        if s.ok and s.echo == nil and s.key == key then s.echo = true; return end
    end
end)
local rawSendChat = W.SendChat
function W.SendChat(text, channel, target)
    local ok = rawSendChat(text, channel, target)
    if type(text) == "string" then
        if #sent >= 30 then table.remove(sent, 1) end
        sent[#sent + 1] = { t = GetTime(), ch = tostring(channel), key = text:sub(1, 40), ok = ok, at = (Caller()) }
        if ok then
            Listen(true)
            if not settling then settling = true; W.After(5, Settle, "verify echo") end
        end
    end
    return ok
end

-- HIGH 6: our restricted calls, and 2 s later whether the group shows them done (nil = cannot tell)
local calls = {}
local function NoteCall(label, at, check)
    local c = calls[label]
    if not c then c = { n = 0, combat = 0, yes = 0, no = 0, from = {}, places = 0 }; calls[label] = c end
    c.n = c.n + 1
    if InCombatLockdown() then c.combat = c.combat + 1 end
    if c.from[at] then c.from[at] = c.from[at] + 1
    elseif c.places < 4 then c.from[at] = 1; c.places = c.places + 1 end
    if not check then return end
    W.After(2, function()
        local ok, done = pcall(check)
        if ok and done == true then c.yes = c.yes + 1 elseif ok and done == false then c.no = c.no + 1 end
    end, "verify check")
end
local function Subgroup(index)
    local _, _, g = GetRaidRosterInfo(index)
    return W.Safe(g)
end
-- our code calls the C_PartyInfo form when it exists, else the old global: hook that one only (no double count)
local function Hook(key, label, makeCheck)
    local tbl = (C_PartyInfo and type(C_PartyInfo[key]) == "function") and C_PartyInfo or _G
    if type(tbl[key]) ~= "function" then return end
    local function After(...)
        local at, ours = Caller()
        if not ours then return end
        local ok, check = pcall(makeCheck, ...)
        NoteCall(label, at, ok and check or nil)
    end
    if tbl == _G then hooksecurefunc(key, After) else hooksecurefunc(tbl, key, After) end
end
Hook("ConvertToRaid", "ConvertToRaid", function() return function() return IsInRaid() and true or false end end)
Hook("PromoteToAssistant", "PromoteToAssistant", function(name)
    return function()
        local unit = W.UnitByName(name)
        if not (unit and UnitIsGroupAssistant) then return nil end
        return UnitIsGroupAssistant(unit) and true or false
    end
end)
if GetRaidRosterInfo then
    Hook("SetRaidSubgroup", "SetRaidSubgroup", function(index, group)
        return function() return Subgroup(index) == group end
    end)
    -- a post-hook: the roster still shows the groups from before the swap
    Hook("SwapRaidSubgroup", "SwapRaidSubgroup", function(i1, i2)
        local a, b = Subgroup(i1), Subgroup(i2)
        if not a or not b or a == b then return nil end
        return function() return Subgroup(i1) == b and Subgroup(i2) == a end
    end)
end

local blocked, blockedKeys, blockedOther = {}, 0, 0
local gcd = { out = {}, combat = {} }
local castID, castAt
local bank = {}
local function BankMoney() return W.Safe(GetGuildBankMoney and GetGuildBankMoney()) end

local ON = {}
local function Blocked(kind, addon, fn)
    addon, fn = W.Safe(addon), W.Safe(fn)
    if type(addon) ~= "string" or addon:find("WarLegendRaidTool", 1, true) ~= 1 then
        blockedOther = blockedOther + 1
        return
    end
    local key = kind .. " " .. W.CutUTF8(tostring(fn), 60)
    local b = blocked[key]
    if not b then
        if blockedKeys >= 20 then return end
        blockedKeys = blockedKeys + 1
        b = { n = 0, combat = 0 }
        blocked[key] = b
    end
    b.n = b.n + 1
    if InCombatLockdown() then b.combat = b.combat + 1 end
end
ON.ADDON_ACTION_BLOCKED = function(addon, fn) Blocked("blocked", addon, fn) end
ON.ADDON_ACTION_FORBIDDEN = function(addon, fn) Blocked("forbidden", addon, fn) end
ON.CHAT_MSG_WHISPER = function(_, sender, _, _, _, _, _, _, _, _, _, guid) NoteName("whisper", sender, guid) end
ON.PARTY_INVITE_REQUEST = function(name, _, _, _, _, _, guid) NoteName("invite", name, guid) end
ON.GROUP_INVITE_CONFIRMATION = function()
    local id = W.Safe(GetNextPendingInviteConfirmation and GetNextPendingInviteConfirmation())
    if not (id and GetInviteConfirmationInfo) then return end
    local _, name, guid = GetInviteConfirmationInfo(id)
    NoteName("confirm", name, guid)
end
-- audit 21: guild bank money right after login, 10 s later, and whether the bank was opened since
ON.PLAYER_ENTERING_WORLD = function(isLogin, isReload)
    if bank.how then return end
    bank.how = isLogin and "login" or isReload and "reload" or "zone"
    bank.login = BankMoney()
    W.After(10, function() bank.later = BankMoney() end, "verify bank")
end
ON.GUILDBANKFRAME_OPENED = function() bank.opened = true end
-- audit 15: a spell's cooldown fields just after I cast it (under the GCD), read on SPELL_UPDATE_COOLDOWN as the docs say
ON.UNIT_SPELLCAST_SUCCEEDED = function(unit, _, spellID)
    unit = W.Safe(unit) -- the payload can be secret (SecretWhenUnitSpellCastRestricted): never compared then
    if unit ~= nil and unit ~= "player" then return end
    if #gcd[InCombatLockdown() and "combat" or "out"] >= 3 then return end
    castID, castAt = W.Safe(spellID), GetTime()
end
ON.SPELL_UPDATE_COOLDOWN = function()
    if not castID then return end
    local id = castID
    castID = nil
    local get = C_Spell and C_Spell.GetSpellCooldown
    if GetTime() - castAt > 0.5 or not get then return end
    local info = get(id)
    if type(info) ~= "table" then return end
    local d = info.duration
    local dur = (issecretvalue and issecretvalue(d)) and "secret" or (type(d) == "number" and string.format("%.2f", d)) or Str(d)
    local list = gcd[InCombatLockdown() and "combat" or "out"]
    list[#list + 1] = string.format("%s isActive=%s isOnGCD=%s isEnabled=%s duration=%s", Str(W.SpellName(id) or id),
        Str(info.isActive), Str(info.isOnGCD), Str(info.isEnabled), dur)
end

-- audit 12 and the TRUST table: channel and sender's form of our addon messages (Skyborne reads only "CHANNEL")
local addonSeen, addonLines = {}, {}
ON.CHAT_MSG_ADDON = function(prefix, _, channel, sender)
    prefix = W.Safe(prefix)
    if type(prefix) ~= "string" or #addonLines >= 12 then return end
    local mine = prefix == "SLLCM" and "skyborne" or prefix:sub(1, 5) == "WLRT_" and "wlrt" or nil
    if not mine then return end
    channel = Str(channel)
    local key = mine .. " " .. channel .. " " .. Shape(W.Safe(sender))
    if not addonSeen[key] then
        addonSeen[key] = true
        addonLines[#addonLines + 1] = { mine, channel, key }
    end
end

-- QualityOfLife takes a quest from an NPC only: what the game says of the giver, for an NPC and for a player sharing one
local questSeen, questLines = {}, {}
ON.QUEST_DETAIL = function()
    if #questLines >= 4 then return end
    local line = string.format("questnpc is a player %s, npc is a player %s", Str(UnitIsPlayer("questnpc")), Str(UnitIsPlayer("npc")))
    if not questSeen[line] then
        questSeen[line] = true
        questLines[#questLines + 1] = line
    end
end

-- HIGH 7: what the game really hides (the bench models only part of it): C_Secrets' answers and the reads that come back
-- secret, at each run and 2 s into the first fight of each kind of place
local function SecretLine()
    local S, out = C_Secrets, {}
    if not S then return "C_Secrets missing" end
    local function Ask(label, name, ...)
        local fn, ok, v = S[name], false, nil
        if fn then ok, v = pcall(fn, ...) end
        out[#out + 1] = label .. "=" .. (fn and (ok and Str(v) or "error") or "missing")
    end
    Ask("any", "HasSecretRestrictions")
    Ask("auras", "ShouldAurasBeSecret")
    Ask("cooldowns", "ShouldCooldownsBeSecret")
    Ask("stats", "ShouldUnitStatsBeSecret")
    local unit = UnitExists("target") and "target" or "player"
    Ask("identity", "ShouldUnitIdentityBeSecret", unit)
    Ask("healthmax", "ShouldUnitHealthMaxBeSecret", unit)
    Ask("casting", "ShouldUnitSpellCastingBeSecret", unit)
    if not issecretvalue then return table.concat(out, " ") .. ", no issecretvalue" end
    local hidden = {}
    local function Read(label, v) if issecretvalue(v) then hidden[#hidden + 1] = label end end
    Read("name", (UnitName(unit)))
    Read("guid", (UnitGUID(unit)))
    Read("health", (UnitHealth(unit)))
    Read("healthmax", (UnitHealthMax(unit)))
    local aura = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex and C_UnitAuras.GetAuraDataByIndex("player", 1)
    Read("aura", aura)
    aura = W.Safe(aura)
    if type(aura) == "table" then Read("aura spell", aura.spellId); Read("aura name", aura.name) end
    return table.concat(out, " ") .. "; " .. unit .. " reads secret: " .. (#hidden > 0 and table.concat(hidden, " ") or "none")
end
local secretKinds, secretLines = {}, {}
local function SampleFight(kind)
    if secretKinds[kind] or #secretLines >= 6 then return end
    secretKinds[kind] = true
    W.After(2, function()
        if not InCombatLockdown() then secretKinds[kind] = nil; return end -- over too soon: the next fight
        local ok, line = pcall(SecretLine)
        secretLines[#secretLines + 1] = "fight in " .. kind .. ": " .. (ok and line or ("error " .. Str(line)))
    end, "verify secrets")
end
ON.PLAYER_REGEN_DISABLED = function()
    local _, kind = IsInInstance()
    SampleFight(Str(kind))
end
ON.ENCOUNTER_START = function() SampleFight("encounter") end

local watch = CreateFrame("Frame")
for e in pairs(ON) do
    if e ~= "UNIT_SPELLCAST_SUCCEEDED" then pcall(watch.RegisterEvent, watch, e) end
end
if watch.RegisterUnitEvent then pcall(watch.RegisterUnitEvent, watch, "UNIT_SPELLCAST_SUCCEEDED", "player")
else pcall(watch.RegisterEvent, watch, "UNIT_SPELLCAST_SUCCEEDED") end
-- an error here would land in BugGrabber among ours: counted and shown by the "watch" probe instead
watch:SetScript("OnEvent", function(_, event, ...)
    if not pcall(ON[event], ...) then watchErrors = watchErrors + 1 end
end)

---------------------------------------------------------------------------
-- Probes of the 29/10 audit (docs/audit-2026-10-29.md, "In-game probes for 5/11")
---------------------------------------------------------------------------
Probe("nameform", function()
    local any = false
    for _, kind in ipairs({ "whisper", "invite", "confirm" }) do
        local seen = nameSeen[kind]
        if (seen.n or 0) > 0 then
            any = true
            local list = {}
            for i = 1, seen.n do list[i] = seen[i] end
            local line = table.concat(list, "; ")
            Out(line:find("DIFFERS", 1, true) and "LOOK" or "OK", "nameform", kind .. ": " .. line)
        end
    end
    if not any then Out("SKIP", "nameform", "no whisper / invite seen since /reload: get one of each, then /wl verify quick") end
end)

-- HIGH 2 (fixed 29/10): "First-Zzz" / "First Zzz" must not match the guild's only "First"
Probe("guildname", function()
    local list = W.GuildMembers()
    if #list == 0 then Out("SKIP", "guildname", "guild roster not read yet: open the guild window, then /wl verify quick"); return end
    local count = {}
    for _, m in ipairs(list) do count[m.name:lower()] = (count[m.name:lower()] or 0) + 1 end
    for _, m in ipairs(list) do
        if count[m.name:lower()] == 1 and W.HasFullPart(m.full) then
            local hyphen, spaced = W.GuildMember(m.name .. "-Zzz"), W.GuildMember(m.name .. SEP .. "Zzz")
            local found = W.GuildMember(m.full) ~= nil
            Out((not hyphen and not spaced and found) and "OK" or "LOOK", "guildname", string.format(
                "%d members; a unique first name with a fake surname: hyphen %s, space %s; its full name %s", #list,
                hyphen and "MATCHED" or "refused", spaced and "MATCHED" or "refused", found and "found" or "NOT FOUND"))
            return
        end
    end
    Out("SKIP", "guildname", "no member whose first name nobody else has")
end)

Probe("chatecho", function()
    if #sent == 0 then
        Out("SKIP", "chatecho",
            "no chat line of ours since /reload: Raid Buffs report, a Loot Council award, Summon, !sr, then /wl verify quick")
        return
    end
    local back, lost, refused, waiting, lostAt, backAt = 0, 0, 0, 0, {}, {}
    for _, s in ipairs(sent) do
        local at = s.ch .. " " .. s.at
        if not s.ok then refused = refused + 1
        elseif s.echo then back = back + 1; if #backAt < 4 and not backAt[at] then backAt[at] = true; backAt[#backAt + 1] = at end
        elseif s.echo == false then lost = lost + 1; if #lostAt < 4 then lostAt[#lostAt + 1] = at end
        else waiting = waiting + 1 end
    end
    Out(lost > 0 and "LOOK" or "OK", "chatecho", string.format(
        "last %d line(s): %d came back, %d never came back, %d refused at send (chat locked / send error), %d waiting",
        #sent, back, lost, refused, waiting))
    if #backAt > 0 then Out("INFO", "chatecho", "came back: " .. table.concat(backAt, ", ")) end
    if #lostAt > 0 then Out("LOOK", "chatecho", "never came back: " .. table.concat(lostAt, ", ")) end
end)

Probe("restricted", function()
    if not next(calls) then
        Out("SKIP", "restricted",
            "no restricted call of ours since /reload: APPLY ALL, mass invites, AutoPromote, then /wl verify quick")
        return
    end
    for label, c in pairs(calls) do
        local from = {}
        for at, n in pairs(c.from) do from[#from + 1] = at .. " x" .. n end
        Out(c.no > 0 and "LOOK" or "OK", "restricted", string.format("%s: %d call(s), %d in combat, worked %d, no effect %d, from %s",
            label, c.n, c.combat, c.yes, c.no, table.concat(from, ", ")))
    end
end)

Probe("blocked", function()
    if not next(blocked) then
        Out("OK", "blocked", "no action of ours blocked or forbidden since /reload (" .. blockedOther .. " for other addons)")
        return
    end
    for key, b in pairs(blocked) do Out("LOOK", "blocked", string.format("%s x%d (%d in combat)", key, b.n, b.combat)) end
end)

-- audit 17: Dispel and the buff families check rank-1 IDs; is a rank 1 still "known" once rank 2 is learned?
local RANKS = {
    PRIEST = { { 1243, 1244 }, { 527, 988 } }, MAGE = { { 1459, 1460 } }, DRUID = { { 1126, 5232 } },
    PALADIN = { { 19740, 19834 } }, WARRIOR = { { 6673, 5242 } }, ROGUE = { { 1752, 1757 } },
    HUNTER = { { 13165, 14318 } }, WARLOCK = { { 687, 696 } }, SHAMAN = { { 403, 529 } },
}
Probe("spellrank", function()
    local known = C_SpellBook and C_SpellBook.IsSpellKnown
    if not known then Out("LOOK", "spellrank", "no C_SpellBook.IsSpellKnown"); return end
    local list = RANKS[W.UnitClassToken("player")]
    if not list then Out("SKIP", "spellrank", "no spell listed for this class"); return end
    for _, p in ipairs(list) do
        local k1, k2 = known(p[1]), known(p[2])
        local what = string.format("%s %d=%s, rank 2 %d=%s", Str(W.SpellName(p[1])), p[1], Str(k1), p[2], Str(k2))
        if not k2 then Out("SKIP", "spellrank", what .. ": rank 2 not learned yet")
        elseif k1 then Out("OK", "spellrank", what .. ": rank 1 still known")
        else Out("LOOK", "spellrank", what .. ": rank 1 NOT known once rank 2 is learned (audit 17: Dispel)") end
    end
end)

-- audit 15: is isActive true under the GCD alone? (RaidCooldowns read "hidden" for a ready spell mid-GCD)
Probe("gcd", function()
    for slot, label in pairs({ out = "out of combat", combat = "in combat" }) do
        if #gcd[slot] == 0 then Out("SKIP", "gcd", label .. ": cast any spell, then /wl verify quick") end
        for _, s in ipairs(gcd[slot]) do Out("INFO", "gcd", label .. ": " .. s) end
    end
end)

-- audit 18: PvP compares the scoreboard's faction (GetScoreInfo is SecretInActivePvPMatch; faction / name NeverSecret)
Probe("pvpscore", function()
    if not W.InPvP() then Out("SKIP", "pvpscore", "run it in a battleground (Alterac) once the scoreboard is filled"); return end
    if not (C_PvP and C_PvP.GetScoreInfo and issecretvalue) then
        Out("LOOK", "pvpscore",
            "C_PvP.GetScoreInfo " .. Kind(C_PvP and C_PvP.GetScoreInfo) .. ", issecretvalue " .. Kind(issecretvalue))
        return
    end
    local info = C_PvP.GetScoreInfo(1)
    if type(info) ~= "table" then Out("SKIP", "pvpscore", "no score line 1 yet"); return end
    local secret, plain = {}, {}
    for k, v in pairs(info) do
        if type(k) == "string" then
            local list = issecretvalue(v) and secret or plain
            list[#list + 1] = k
        end
    end
    table.sort(secret)
    table.sort(plain)
    local bad = issecretvalue(info.faction) or issecretvalue(info.name)
    Out(bad and "LOOK" or "OK", "pvpscore",
        (bad and "faction / name SECRET (audit 18), " or "") .. "secret: " .. table.concat(secret, " "))
    Out("INFO", "pvpscore", "plain: " .. table.concat(plain, " "))
end)

-- audit 21: QualityOfLife's guild repair reads GetGuildBankMoney(): 0 until the bank is opened = the player pays
Probe("guildbank", function()
    if not GetGuildBankMoney then Out("LOOK", "guildbank", "GetGuildBankMoney missing"); return end
    if not (IsInGuild and IsInGuild()) then Out("SKIP", "guildbank", "not in a guild"); return end
    local now = BankMoney()
    Out("INFO", "guildbank", string.format(
        "money after %s %s, 10 s later %s, now %s; bank opened since: %s; withdraw %s, can repair %s",
        Str(bank.how), Str(bank.login), Str(bank.later), Str(now), bank.opened and "yes" or "no",
        Str(GetGuildBankWithdrawMoney and GetGuildBankWithdrawMoney()), Str(CanGuildBankRepair and CanGuildBankRepair())))
    if (bank.login or 0) > 0 or (bank.later or 0) > 0 then Out("OK", "guildbank", "money read without opening the bank")
    elseif (now or 0) > 0 then
        Out(bank.opened and "LOOK" or "OK", "guildbank",
            bank.opened and "0 until the bank was opened (audit 21)" or "money came without opening the bank")
    else Out("SKIP", "guildbank", "0 so far: /reload, wait 10 s, open the guild bank, then /wl verify quick") end
end)

-- audit 28: LootCouncil's corpse key uses GetLootSourceInfo (in neither the docs nor Blizzard's Forever code)
Probe("lootsource", function()
    if not GetLootSourceInfo then
        Out("LOOK", "lootsource", "GetLootSourceInfo missing: LootCouncil's corpse key falls back")
        return
    end
    if (GetNumLootItems and GetNumLootItems() or 0) == 0 then
        Out("SKIP", "lootsource", "open a loot window, then /wl verify quick")
        return
    end
    local guid, qty = GetLootSourceInfo(1)
    guid = W.Safe(guid)
    Out(type(guid) == "string" and "OK" or "LOOK", "lootsource", "slot 1 source " ..
        (type(guid) == "string" and (guid:match("^[^%-]+") or "?") or Str(guid)) .. ", quantity " .. Str(qty))
end)

-- audit 28: AutoLog reads LoggingCombat(true)'s return (nil = rate limited, 5 calls per 10 s): 4 calls at most here
Probe("combatlog", function()
    if not LoggingCombat then Out("LOOK", "combatlog", "LoggingCombat missing"); return end
    local was = LoggingCombat()
    if was == nil then Out("LOOK", "combatlog", "LoggingCombat() returned nil (rate limited?): /wl verify quick in 10 s"); return end
    if was then Out("INFO", "combatlog", "already logging: LoggingCombat(true) returned " .. Str(LoggingCombat(true))); return end
    local on = LoggingCombat(true)
    local state = LoggingCombat()
    local off = LoggingCombat(false)
    Out((on ~= nil and state) and "OK" or "LOOK", "combatlog", string.format(
        "LoggingCombat(true) returned %s, then logging %s; LoggingCombat(false) returned %s", Str(on), Str(state), Str(off)))
end)

-- audit 28: Skyborne's share channel
Probe("channels", function()
    Out(JoinTemporaryChannel and "OK" or "LOOK", "channels", string.format(
        "JoinTemporaryChannel %s, JoinChannelByName %s, JoinPermanentChannel %s",
        Kind(JoinTemporaryChannel), Kind(JoinChannelByName), Kind(JoinPermanentChannel)))
end)

-- audit 22: MoveFrames moves these; an Edit Mode system's SetPoint writes Edit Mode state (taint)
Probe("editmode", function()
    for _, name in ipairs({ "DurabilityFrame", "MirrorTimerContainer", "RaidWarningFrame", "TalkingHeadFrame" }) do
        local f = _G[name]
        Out("INFO", "editmode", type(f) == "table"
            and string.format("%s system=%s managed=%s", name, Str(f.system), Str(f.isManagedFrame)) or (name .. " missing"))
    end
    local get = (C_CVar and C_CVar.GetCVar) or GetCVar
    local log = get and get("taintLog")
    if log == nil or log == "0" then
        Out("SKIP", "editmode", "taintLog " .. Str(log)
            .. ": /console taintLog 1, move the durability figure, open Edit Mode, fight, /wl verify quick")
    else
        Out("INFO", "editmode", "taintLog " .. Str(log) .. ": see the blocked line above, details in Logs\\taint.log")
    end
end)

-- audit 43: the PvP 16-40 layout (1 column of 23 px from y = 600): rows below the screen?
Probe("pvplayout", function()
    local P = WarLegendPvP
    if not (P and P.Allies and P.Enemies) then
        Out("SKIP", "pvplayout", "PvP addon not loaded: in a battleground, or /wl pvp test mode")
        return
    end
    local top = UIParent:GetTop() * UIParent:GetEffectiveScale()
    for _, side in ipairs({ "Allies", "Enemies" }) do
        local shown, off = 0, 0
        for _, b in pairs(P[side].Players or {}) do
            if type(b) == "table" and b.IsVisible and b:IsVisible() then
                shown = shown + 1
                local lo, hi, s = b:GetBottom(), b:GetTop(), b:GetEffectiveScale()
                if lo and hi and (lo * s < -1 or hi * s > top + 1) then off = off + 1 end
            end
        end
        if shown == 0 then Out("SKIP", "pvplayout", side .. ": no button shown")
        else Out(off == 0 and "OK" or "LOOK", "pvplayout", string.format("%s: %d shown, %d off screen", side, shown, off)) end
    end
end)

Probe("addonmsg", function()
    if #addonLines == 0 then
        Out("SKIP", "addonmsg", "no message of ours seen since /reload: a group or guild member with the addon, /wl sk share, then /wl verify quick")
        return
    end
    for _, a in ipairs(addonLines) do
        Out((a[1] == "skyborne" and a[2] ~= "CHANNEL") and "LOOK" or "INFO", "addonmsg", a[3]
            .. ((a[1] == "skyborne" and a[2] ~= "CHANNEL") and " (Skyborne reads only CHANNEL: audit 12)" or ""))
    end
end)

Probe("questgiver", function()
    if #questLines == 0 then
        Out("SKIP", "questgiver", "no quest window since /reload: an NPC's, and one shared by a player, then /wl verify quick")
        return
    end
    for _, line in ipairs(questLines) do Out("INFO", "questgiver", line) end
end)

Probe("secrets", function()
    local ok, line = pcall(SecretLine)
    Out("INFO", "secrets", "out of combat: " .. (ok and line or ("error " .. Str(line))))
    if #secretLines == 0 then Out("SKIP", "secrets", "no fight seen since /reload: fight for 2 s, then /wl verify quick") end
    for _, l in ipairs(secretLines) do Out("INFO", "secrets", l) end
end)

-- the talent reading (groups, else columns of nodes): TalentReminder and Upgrades' automatic tree depend on it
Probe("talents", function()
    local t = W.OwnTalents and W.OwnTalents()
    if type(t) ~= "table" then
        Out((UnitLevel("player") or 0) < 10 and "SKIP" or "LOOK", "talents", "W.OwnTalents gave nothing at level " .. Str(UnitLevel("player")))
        return
    end
    local parts = {}
    for i, n in ipairs(t.spent or {}) do parts[i] = Str(t.names and t.names[i]) .. " " .. Str(n) end
    Out((t.total or 0) > 0 and "OK" or "SKIP", "talents", string.format("%s points: %s; best %s", Str(t.total), table.concat(parts, ", "), Str(t.best)))
end)

-- the Blizzard functions our hooks need: a missing one = that feature silently stays off (item levels, +/- on the loot window...).
-- The inspect ones come with the inspect window: open it once before reading them.
Probe("hooks", function()
    local missing, present = {}, {}
    for _, name in ipairs({ "BankFrameItemButton_Update", "ChatEdit_InsertLink", "ContainerFrame_Update", "GameTooltip_SetDefaultAnchor",
        "InspectPaperDollFrame_UpdateButtons", "InspectPaperDollItemSlotButton_Update", "LootFrame_UpdateButton",
        "PaperDollItemSlotButton_Update", "UpdateUIPanelPositions" }) do
        local list = type(_G[name]) == "function" and present or missing
        list[#list + 1] = name
    end
    if #missing > 0 then Out("INFO", "hooks", "missing: " .. table.concat(missing, " ")) end
    if #present > 0 then Out("INFO", "hooks", "present: " .. table.concat(present, " ")) end
end)

-- Myslot's export header (a global missing: it says "Player" on a French client)
Probe("strings", function()
    local parts = {}
    for _, name in ipairs({ "PLAYER", "CLASS", "TALENTS", "LEVEL" }) do
        local v = rawget(_G, name)
        parts[#parts + 1] = name .. "=" .. (type(v) == "string" and W.CutUTF8(v, 20) or Kind(v))
    end
    Out("INFO", "strings", table.concat(parts, " "))
end)

Probe("watch", function()
    Out(watchErrors == 0 and "OK" or "LOOK", "watch", watchErrors .. " error(s) in the session watch")
end)

-- our errors of this session in BugGrabber (same test as Bugs.lua: the message or the stack names one of our addon folders)
local function Errors()
    if not (BugGrabber and BugGrabber.GetDB and BugGrabber.GetSessionId) then return nil end
    local session, n = BugGrabber:GetSessionId(), 0
    for _, err in ipairs(BugGrabber:GetDB() or {}) do
        local text = tostring(err.message or "") .. tostring(err.stack or "")
        if err.session == session and text:find("WarLegendRaidTool", 1, true) then n = n + 1 end
    end
    return n
end

---------------------------------------------------------------------------
-- The report to paste to Claude: context, every line, the module tests, our errors in full, the busiest work
---------------------------------------------------------------------------
local function Context(out)
    local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local version, build = GetBuildInfo()
    local _, class = UnitClass("player")
    local _, race = UnitRace("player")
    local _, kind = IsInInstance()
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    local group = W.InRaid() and ("raid of " .. n) or W.InGroup() and ("party of " .. n) or "solo"
    local role = W.IsLeader() and "leader" or (UnitIsGroupAssistant and UnitIsGroupAssistant("player")) and "assistant" or "member"
    out[#out + 1] = string.format("WLRT %s, client %s build %s, locale %s, %s", Str(meta and meta("WarLegendRaidTool", "Version")),
        Str(version), Str(build), Str(GetLocale()), date("%Y-%m-%d %H:%M"))
    out[#out + 1] = string.format("%s %s level %s, guild %s, %s%s, zone %s (%s), combat %s", Str(race), Str(class),
        Str(UnitLevel("player")), W.IsInGuild() and "yes" or "no", group, W.InGroup() and (" (" .. role .. ")") or "",
        Str(GetRealZoneText and GetRealZoneText()), Str(kind), InCombatLockdown() and "yes" or "no")
    local off = {}
    local ui = W.db and W.db.ui
    for key, v in pairs(ui and type(ui.off) == "table" and ui.off or {}) do
        if v then off[#off + 1] = tostring(key) end
    end
    table.sort(off)
    out[#out + 1] = "modules switched off: " .. (#off > 0 and table.concat(off, " ") or "none")
    -- the other addons loaded: overlaps and conflicts (EllesmereUI, BugGrabber...)
    local list = {}
    local num = C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns() or 0
    for i = 1, num do
        local name = C_AddOns.GetAddOnInfo(i)
        if type(name) == "string" and C_AddOns.IsAddOnLoaded(i) and name:find("WarLegendRaidTool", 1, true) ~= 1
            and #list < MAX_ADDONS then
            list[#list + 1] = name .. " " .. Str(meta and meta(name, "Version"))
        end
    end
    out[#out + 1] = "other addons loaded: " .. (#list > 0 and table.concat(list, ", ") or "none")
end

-- our errors of this session, message and stack (BugGrabber's list is oldest first)
local function ErrorLines(out)
    if not (BugGrabber and BugGrabber.GetDB and BugGrabber.GetSessionId) then
        out[#out + 1] = "errors: BugGrabber not installed, none listed (install BugGrabber to get them here)"
        return
    end
    local session, n = BugGrabber:GetSessionId(), 0
    for _, err in ipairs(BugGrabber:GetDB() or {}) do
        local message, stack = tostring(err.message or ""), tostring(err.stack or "")
        if err.session == session and (message .. stack):find("WarLegendRaidTool", 1, true) then
            n = n + 1
            if n <= MAX_ERRORS then
                out[#out + 1] = string.format("error %d (x%s): %s", n, Str(err.counter), W.CutUTF8(message, 500))
                local k = 0
                for line in stack:gmatch("[^\n]+") do
                    k = k + 1
                    if k > STACK_LINES then break end
                    out[#out + 1] = "    " .. W.CutUTF8(line, 200)
                end
            end
        end
    end
    out[#out + 1] = string.format("errors of ours this session: %d%s", n, n > MAX_ERRORS and (", the first " .. MAX_ERRORS .. " above") or "")
end

local function Report(r)
    local out = {}
    Context(out)
    for _, l in ipairs(r.lines) do out[#out + 1] = l end
    if r.dropped then out[#out + 1] = r.dropped .. " line(s) over the limit, not kept" end
    if r.tested then out[#out + 1] = "module tests: " .. r.tested end
    ErrorLines(out)
    for _, b in ipairs(W.BusiestWork and W.BusiestWork(8) or {}) do
        out[#out + 1] = string.format("perf: %s %.1f ms in %d call(s), max %.1f ms", Str(b[1]), tonumber(b[4]) or 0,
            tonumber(b[3]) or 0, tonumber(b[2]) or 0)
    end
    out[#out + 1] = string.format("summary: %d OK, %d LOOK, %d SKIP", r.counts.OK, r.counts.LOOK, r.counts.SKIP)
    return table.concat(out, "\n")
end

-- what gets copied: one line anyone can read, then the report deflated + base64 in lines of 76 (node
-- tools/verify-live.js --decode reads it back); the plain report when the client cannot compress
local function Pack(r, text)
    local head = string.format("WLRT verify %s: %d OK, %d LOOK, %d SKIP", date("%Y-%m-%d %H:%M", r.t),
        r.counts.OK, r.counts.LOOK, r.counts.SKIP)
    local EU = C_EncodingUtil
    if EU and EU.CompressString and EU.EncodeBase64 then
        local ok, packed = pcall(function() return EU.EncodeBase64(EU.CompressString(text)) end)
        if ok and type(packed) == "string" and packed ~= "" then
            local parts = { head, "WLRTV1:" }
            for i = 1, #packed, 76 do parts[#parts + 1] = packed:sub(i, i + 75) end
            return table.concat(parts, "\n")
        end
    end
    return head .. "\n" .. text
end

-- the copy box: everything already selected ("|" doubled: an edit box reads it as the start of an escape code)
local function ShowReport(text)
    W.TextPopup(L("WLRT verify report"), (text:gsub("|", "||")), { hint = L("All selected: Ctrl+C, then paste it to Claude.") })
end

local function Finish(before)
    local after = Errors()
    if after == nil then Out("SKIP", "errors", "BugGrabber not installed")
    elseif after > (before or 0) then Out("LOOK", "errors", (after - (before or 0)) .. " new Lua error(s): /wl bugs")
    else Out("OK", "errors", "no new Lua error (" .. after .. " this session)") end
    Out("INFO", "end", "run finished")
    W.Print(string.format(L("Verify: done, %d OK, %d to look at, %d skipped. /reload to save the run."),
        counts.OK, counts.LOOK, counts.SKIP))
    local r = run
    run = nil
    local ok, text = pcall(Report, r)
    if not ok then text = "report error: " .. tostring(text) .. "\n" .. table.concat(r.lines, "\n") end
    r.report = Pack(r, text)
    ShowReport(r.report)
end

local function Start(tests)
    if InCombatLockdown() then W.Print(L("Verify: not in combat.")); return end
    if LoggingChat and not LoggingChat() then
        LoggingChat(true)
        db.chatLogByUs = true
    end
    counts = { OK = 0, LOOK = 0, SKIP = 0, INFO = 0 }
    run = { t = time(), lines = {}, counts = counts }
    db.runs = type(db.runs) == "table" and db.runs or {}
    table.insert(db.runs, 1, run)
    while #db.runs > MAX_RUNS do table.remove(db.runs) end
    for i = 2, #db.runs do db.runs[i].report = nil end -- one report kept: the newest
    Out("INFO", "begin", date("%Y-%m-%d %H:%M:%S") .. ", chat log " .. Str(LoggingChat and LoggingChat()))
    local before = Errors()
    for _, p in ipairs(probes) do
        local ok, err = pcall(p.fn)
        if not ok then Out("LOOK", p.id, "probe error " .. Str(err)) end
    end
    if not tests then return Finish(before) end
    W.Print(L("Verify: module tests running (about 70 s), then the report opens to copy."))
    -- what W.TestAll prints (the modules shown, or none switched on) goes in the report too
    local printed, rawPrint = {}, W.Print
    W.Print = function(msg)
        if #printed < 3 then printed[#printed + 1] = tostring(msg) end
        return rawPrint(msg)
    end
    local ok, err = pcall(W.TestAll)
    W.Print = rawPrint
    if not ok then Out("LOOK", "tests", "W.TestAll error " .. Str(err)) end
    run.tested = table.concat(printed, " / ")
    local mine = run
    W.After(70, function() if run == mine then Finish(before) end end)
end

-- /wl verify (probes + module tests), /wl verify quick (probes only), /wl verify copy (the last report again),
-- /wl verify stop (chat log back off)
W.slash.verify = function(rest)
    rest = (rest or ""):lower()
    if rest:match("^%s*copy") then
        local last = type(db.runs) == "table" and db.runs[1]
        if last and last.report then ShowReport(last.report) else W.Print(L("Verify: no report yet. Type /wl verify.")) end
        return
    end
    if rest:match("^%s*stop") then
        if db.chatLogByUs and LoggingChat then LoggingChat(false) end
        db.chatLogByUs = false
        W.Print(L("Verify: chat log switched off."))
        return
    end
    Start(not rest:match("^%s*quick"))
end
