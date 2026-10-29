-- WarLegend RaidTool - Verify (dev addon: internal testing only, never in the release zip, see AGENTS.md)
-- /wl verify: checks in the real client what the code alone cannot prove (API present, formats returned by the game),
-- then runs the test of every module switched on and counts the Lua errors. Reads only: never sends a message.
-- Each line goes to the chat with the tag [WLRT-VERIFY] and the chat log is switched on (Logs\WoWChatLog.txt), so the
-- lines can be read from outside the game while it runs (node tools/verify-live.js); the last 5 runs are also saved
-- in WarLegendRaidTool_DevDB (its own file, written at /reload or logout).
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
    ["Verify: module tests running (about 70 s)..."] = "Vérification : tests des modules en cours (environ 70 s)...",
    ["Verify: chat log switched off."] = "Vérification : journal du chat éteint.",
})

local TAG = "[WLRT-VERIFY] "
local MAX_LINES, MAX_LEN, MAX_RUNS = 120, 200, 5
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
    if run and #run.lines < MAX_LINES then run.lines[#run.lines + 1] = line end
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

local function Finish(before)
    local after = Errors()
    if after == nil then Out("SKIP", "errors", "BugGrabber not installed")
    elseif after > (before or 0) then Out("LOOK", "errors", (after - (before or 0)) .. " new Lua error(s): /wl bugs")
    else Out("OK", "errors", "no new Lua error (" .. after .. " this session)") end
    Out("INFO", "end", "run finished")
    W.Print(string.format(L("Verify: done, %d OK, %d to look at, %d skipped. /reload to save the run."),
        counts.OK, counts.LOOK, counts.SKIP))
    run = nil
end

local function Start(tests)
    if InCombatLockdown() then W.Print(L("Verify: not in combat.")); return end
    if LoggingChat and not LoggingChat() then
        LoggingChat(true)
        db.chatLogByUs = true
    end
    run = { t = time(), lines = {} }
    counts = { OK = 0, LOOK = 0, SKIP = 0, INFO = 0 }
    db.runs = type(db.runs) == "table" and db.runs or {}
    table.insert(db.runs, 1, run)
    while #db.runs > MAX_RUNS do table.remove(db.runs) end
    Out("INFO", "begin", date("%Y-%m-%d %H:%M:%S") .. ", chat log " .. Str(LoggingChat and LoggingChat()))
    local before = Errors()
    for _, p in ipairs(probes) do
        local ok, err = pcall(p.fn)
        if not ok then Out("LOOK", p.id, "probe error " .. Str(err)) end
    end
    if not tests then return Finish(before) end
    W.Print(L("Verify: module tests running (about 70 s)..."))
    W.TestAll()
    local mine = run
    W.After(70, function() if run == mine then Finish(before) end end)
end

-- /wl verify (probes + module tests), /wl verify quick (probes only), /wl verify stop (chat log back off)
W.slash.verify = function(rest)
    rest = (rest or ""):lower()
    if rest:match("^%s*stop") then
        if db.chatLogByUs and LoggingChat then LoggingChat(false) end
        db.chatLogByUs = false
        W.Print(L("Verify: chat log switched off."))
        return
    end
    Start(not rest:match("^%s*quick"))
end
