-- WarLegend RaidTool - Audit
-- Automatic record of the addon traffic (messages received / sent, who was refused and why, public chat
-- lines sent, slowest work) for a review after the session. Metadata only: never the text of a message.
-- Saved with the other data in WarLegendRaidTool.lua (SavedVariables), written by the game at logout or /reload:
--   WarLegendRaidToolDB.auditLog.cur = this session, .prev = the one before. /wl audit shows a summary.
local W = WLRT
local L = W.L
local cfg
local cur

W.AddFR({
    ["Audit log: %s"] = "Journal d'audit : %s",
    ["Audit: nothing recorded yet."] = "Audit : rien d'enregistré pour l'instant.",
    ["Audit (this session, %d min): in %d, refused %d, sent %d, public lines %d"] =
        "Audit (cette session, %d min) : reçus %d, refusés %d, envoyés %d, lignes publiques %d",
    ["Audit: busiest prefix per minute:"] = "Audit : préfixes les plus bavards (par minute) :",
    ["Audit: the file is WarLegendRaidTool.lua in WTF > SavedVariables, written at /reload or logout."] =
        "Audit : le fichier est WarLegendRaidTool.lua dans WTF > SavedVariables, écrit au /reload ou à la sortie.",
})

local MAX_KEYS, MAX_RECENT, MAX_FIELD = 300, 150, 40

local function Clean(v)
    v = W.Safe(v)
    if type(v) ~= "string" then return "?" end
    return v:sub(1, MAX_FIELD)
end

local function NewSession()
    return {
        version = W.version, start = time(),
        counts = {}, nkeys = 0, -- ["dir|prefix|channel|verdict"] = { n, bytes, max ms }
        recent = {}, nrecent = 0, -- refused or oversized lines, ring of MAX_RECENT
        perMin = {}, -- [prefix] = highest count in one minute
        minute = {}, -- [prefix] = { minute number, count }
        inN = 0, refused = 0, outN = 0, chatN = 0,
    }
end

W.OnReady(function()
    cfg = W.DB("auditCfg", { on = true })
    local log = W.DB("auditLog")
    if type(log.cur) == "table" and (log.cur.inN or 0) + (log.cur.outN or 0) + (log.cur.chatN or 0) > 0 then
        log.prev = log.cur -- the session before is kept until the next one replaces it
    end
    cur = NewSession()
    log.cur = cur
end)

local function Record(dir, prefix, channel, verdict, len, ms)
    local key = dir .. "|" .. prefix .. "|" .. channel .. "|" .. verdict
    local c = cur.counts[key]
    if not c then
        if cur.nkeys >= MAX_KEYS then return end
        c = { n = 0, bytes = 0, max = 0 }
        cur.counts[key] = c
        cur.nkeys = cur.nkeys + 1
    end
    c.n = c.n + 1
    c.bytes = c.bytes + (len or 0)
    if ms and ms > c.max then c.max = ms end
    return c
end

local function Remember(dir, prefix, channel, verdict, who, len)
    cur.nrecent = cur.nrecent + 1
    cur.recent[(cur.nrecent - 1) % MAX_RECENT + 1] = string.format("%d|%s|%s|%s|%s|%s|%d",
        time(), dir, prefix, channel, verdict, who or "-", len or 0)
end

-- messages per minute and prefix: an answer loop or a flood shows up as a peak
local function Rate(prefix)
    local m = math.floor(time() / 60)
    local r = cur.minute[prefix]
    if not r or r[1] ~= m then r = { m, 0 }; cur.minute[prefix] = r end
    r[2] = r[2] + 1
    if r[2] > (cur.perMin[prefix] or 0) then cur.perMin[prefix] = r[2] end
end

-- Called by Core.lua (Dispatch). kind: "ok" (handler called), "time" (handler done, ms in len),
-- or a refusal reason ("stranger", "bad-channel", "bad-sender", "module-off", "waiting").
function W.AuditNote(kind, prefix, channel, who, len, ms)
    if not (cfg and cfg.on and cur) then return end
    prefix, channel = Clean(prefix), Clean(channel)
    if kind == "time" then -- the slowest handler run, on the line already counted
        local c = cur.counts["in|" .. prefix .. "|" .. channel .. "|ok"]
        if c and ms and ms > c.max then c.max = ms end
        return
    end
    len = tonumber(len) or 0
    cur.inN = cur.inN + 1
    Rate(prefix)
    local c = Record("in", prefix, channel, kind, len)
    if kind ~= "ok" then
        cur.refused = cur.refused + 1
        Remember("in", prefix, channel, kind, Clean(who), len)
    elseif len > 240 then
        Remember("in", prefix, channel, "long", Clean(who), len)
    end
    return c
end

-- Sent addon messages: the wrapper sees every caller (W.Send, the queue of Lib.lua, preset sharing).
local rawSend = W.SendRaw
function W.SendRaw(prefix, msg, channel, target)
    local res = rawSend(prefix, msg, channel, target)
    if cfg and cfg.on and cur then
        cur.outN = cur.outN + 1
        Record("out", Clean(prefix), Clean(channel), Clean(res), type(msg) == "string" and #msg or 0)
        Rate("out:" .. Clean(prefix))
    end
    return res
end

-- Public lines (say, party, raid, guild...): count and size only, never the text
local rawChat = W.SendChat
function W.SendChat(text, channel, target)
    local ok = rawChat(text, channel, target)
    if cfg and cfg.on and cur then
        cur.chatN = cur.chatN + 1
        Record("chat", "-", Clean(channel), ok and "sent" or "refused", type(text) == "string" and #text or 0)
        Rate("chat")
    end
    return ok
end

-- Cost of our own work and memory, taken when the game closes or reloads (the file is written right after)
local function Snapshot()
    if not (cfg and cfg.on and cur) then return end
    local perf = { busiest = {}, slowest = {} }
    -- "label|runs|total ms|slowest run ms" (debugprofilestop counts in milliseconds)
    for _, s in ipairs(W.BusiestWork(8)) do perf.busiest[#perf.busiest + 1] = string.format("%s|%d|%.1f|%.2f", s[1], s[3], s[4], s[2]) end
    for _, s in ipairs(W.SlowestWork(5)) do perf.slowest[#perf.slowest + 1] = string.format("%s|%d|%.1f|%.2f", s[1], s[3], s[4], s[2]) end
    if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
        UpdateAddOnMemoryUsage()
        perf.memoryKB = math.floor(GetAddOnMemoryUsage(W.ADDON) or 0)
    end
    local P, M = C_AddOnProfiler, Enum and Enum.AddOnProfilerMetric
    if P and P.GetAddOnMetric and M then
        perf.cpuAvgMs = P.GetAddOnMetric(W.ADDON, M.RecentAverageTime) or 0
        perf.cpuPeakMs = P.GetAddOnMetric(W.ADDON, M.PeakTime) or 0
    end
    perf.group = W.InRaid() and "raid" or (W.InGroup() and "group" or "solo")
    cur.perf, cur.stop = perf, time()
end
W.On("PLAYER_LOGOUT", Snapshot, true)

W.slash.audit = function(rest)
    local arg = (rest or ""):lower():match("^%s*(%a*)")
    if arg == "on" or arg == "off" then
        cfg.on = arg == "on"
        W.Print(string.format(L("Audit log: %s"), arg:upper()))
        return
    end
    if not cur or (cur.inN + cur.outN + cur.chatN) == 0 then W.Print(L("Audit: nothing recorded yet.")); return end
    W.Print(string.format(L("Audit (this session, %d min): in %d, refused %d, sent %d, public lines %d"),
        math.floor((time() - cur.start) / 60), cur.inN, cur.refused, cur.outN, cur.chatN))
    local list = {}
    for prefix, n in pairs(cur.perMin) do list[#list + 1] = { prefix, n } end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    if #list > 0 then W.Print(L("Audit: busiest prefix per minute:")) end
    for i = 1, math.min(5, #list) do W.Print(string.format("  %s: %d", list[i][1], list[i][2])) end
    W.Print(L("Audit: the file is WarLegendRaidTool.lua in WTF > SavedVariables, written at /reload or logout."))
end
