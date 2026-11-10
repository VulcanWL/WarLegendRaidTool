-- WarLegend RaidTool - /wl verify in the simulated client (tools/smoke/scenario.lua, phase "Dev verify"; not shipped). The Dev
-- addon first runs for real on the first night in the game, when a broken probe costs the session: here every probe must
-- run to its end, the session watch must see what the game sends, and nothing may leave for other players.
local M, Check = ...
local W = WLRT

local kept = { bank = rawget(_G, "GetGuildBankMoney"), secrets = rawget(_G, "C_Secrets"), logging = rawget(_G, "LoggingChat"),
    popup = W.TextPopup, events = rawget(_G, "C_EventUtils"), grabber = rawget(_G, "BugGrabber"),
    inviteLine = rawget(_G, "ERR_INVITE_PLAYER_S") }
local eventNames = W.EventNames()
table.sort(eventNames)
local eventError, eventRefused, eventFine = eventNames[1], eventNames[2], eventNames[3]
C_EventUtils = { IsEventValid = function(name)
    if name == eventError then error("refused", 0) end -- a refusal must stay inside the probe
    return name ~= eventRefused
end }
ERR_INVITE_PLAYER_S = "You have invited %s to join your group."
GetGuildBankMoney = function() return 12345 end
LoggingChat = function() return true end
C_Secrets = {
    HasSecretRestrictions = function() return InCombatLockdown() end,
    ShouldAurasBeSecret = function() return InCombatLockdown() end,
    ShouldCooldownsBeSecret = function() return InCombatLockdown() end,
    ShouldUnitStatsBeSecret = function() return false end,
    ShouldUnitIdentityBeSecret = function() error("bad unit", 0) end, -- a refusal must stay inside the probe
}
local shown
W.TextPopup = function(title, text) shown = text end

local path = M.smokeDir .. "/../../WarLegendRaidTool_Dev/Verify.lua"
local chunk, err = load(SMOKE_READ(path), "@WarLegendRaidTool_Dev/Verify.lua")
if not chunk then error(err, 0) end
chunk()
M.Fire("ADDON_LOADED", "WarLegendRaidTool_Dev")
M.Fire("PLAYER_ENTERING_WORLD", true, false)
M.Advance(11) -- the bank's second reading

-- the session: what only the game can show, from other players too
local SENDER = "Zzsender-Surname"
M.Fire("CHAT_MSG_WHISPER", "hello", SENDER, "", "", SENDER, "", 0, 0, "", 0, 1, "Player-1-00000099")
M.Fire("PARTY_INVITE_REQUEST", SENDER, false, false, false, true, false, "Player-1-00000099", false)
M.Fire("CHAT_MSG_ADDON", "WLRT_LC", "x", "RAID", SENDER, "", 0, 0, "", 0)
M.Fire("CHAT_MSG_ADDON", "SLLCM", "x", "CHANNEL", SENDER, "", 0, 0, "", 0)
M.Fire("CHAT_MSG_ADDON", "SLLCM", "x", "GUILD", SENDER, "", 0, 0, "", 0)
M.Fire("CHAT_MSG_ADDON", "OtherAddon", "x", "RAID", SENDER, "", 0, 0, "", 0)
M.Fire("QUEST_DETAIL")
-- our invites as the game answers them: asked from one of our files (the watch leaves out other callers)
local ourInvite = load("C_PartyInfo.InviteUnit(...)", "@WarLegendRaidTool/InviteTool.lua")
local function Invited(name) M.Fire("CHAT_MSG_SYSTEM", ERR_INVITE_PLAYER_S:format(name)) end
ourInvite("Zzanne Good")
Invited("Zzanne Good")
ourInvite("Zzbob Good")
Invited("Zzbob Other") -- the game's bug: another character with that first name
ourInvite("Zzcid Good")
Invited("Zzcid") -- no surname in the game's line
ourInvite("Zzdan Good") -- no line at all
C_PartyInfo.InviteUnit("Zzeve Good") -- not from our code: not counted
Invited("Zzeve Good")
M.Fire("PLAYER_REGEN_DISABLED") -- just before the lockdown, as in the game
M.combat = true
M.Advance(3)
M.combat = false
M.Fire("PLAYER_REGEN_ENABLED")
M.Advance(1)

-- a chat line of ours goes through the watch (taken out of the bench's list: only the watch's reading matters here)
local chat0 = #M.chat
W.SendChat("verify check line", "RAID")
for i = #M.chat, chat0 + 1, -1 do M.chat[i] = nil end
M.Advance(16) -- no echo in the fake client: "never came back"

local function Lines(from)
    local out = {}
    for i = from, #M.prints do
        local line = tostring(M.prints[i]):match("%[WLRT%-VERIFY%] (.*)")
        if line then out[#out + 1] = line end
    end
    return out
end
local function Find(lines, text)
    for _, l in ipairs(lines) do if l:find(text, 1, true) then return l end end
end

local chat1, addon1, errors1 = #M.chat, #M.addon, M.errorSeq or 0
local prints1 = #M.prints
M.Call(W.slash.verify, "quick")
local lines = Lines(prints1 + 1)

local missing = {}
for _, id in ipairs({ "client", "names", "masterloot", "slot18", "range", "itemstats", "coins", "oldglobals", "realm", "encoding",
    "api", "cvar", "raid", "memory", "nameform", "guildname", "chatecho", "restricted", "blocked", "spellrank", "gcd", "pvpscore",
    "guildbank", "lootsource", "combatlog", "channels", "editmode", "pvplayout", "addonmsg", "questgiver", "secrets", "talents",
    "hooks", "strings", "eventnames", "errorcap", "invitename", "watch", "end" }) do
    if not Find(lines, " " .. id .. ": ") then missing[#missing + 1] = id end
end
Check("/wl verify: every probe gives its line", #missing == 0, table.concat(missing, " "))
local broke = Find(lines, "probe error")
Check("/wl verify: no probe stops on an error", not broke, broke or "")
local watchLine = Find(lines, " watch: ")
Check("/wl verify: the session watch had no error", watchLine ~= nil and watchLine:find("0 error", 1, true) ~= nil, tostring(watchLine))
Check("/wl verify: sends nothing, no Lua error", #M.chat == chat1 and #M.addon == addon1 and (M.errorSeq or 0) == errors1,
    (#M.chat - chat1) .. " chat, " .. (#M.addon - addon1) .. " addon, " .. ((M.errorSeq or 0) - errors1) .. " errors: " .. tostring(M.lastError))

-- what the watch saw
Check("/wl verify: whisper and invite: the form, never the name", Find(lines, "nameform: whisper") ~= nil and Find(lines, "nameform: invite") ~= nil
    and not Find(lines, "Zzsender"), tostring(Find(lines, "Zzsender") or Find(lines, " nameform: ")))
local on, off = Find(lines, "skyborne CHANNEL"), Find(lines, "skyborne GUILD")
Check("/wl verify: our addon messages by channel, another addon's left out, a Skyborne one off its channel to look at",
    Find(lines, "wlrt RAID") ~= nil and on ~= nil and on:find("INFO", 1, true) == 1 and off ~= nil and off:find("LOOK", 1, true) == 1
        and not Find(lines, "OtherAddon"), tostring(on) .. " / " .. tostring(off))
local fight = Find(lines, "fight in ")
Check("/wl verify: a fight's secrets read in the fight, a refusal stays inside", fight ~= nil and fight:find("any=true", 1, true) ~= nil
    and fight:find("identity=error", 1, true) ~= nil and Find(lines, "out of combat: any=false") ~= nil, tostring(fight))
local echoLine = Find(lines, "chatecho: last")
Check("/wl verify: our chat line and its missing echo", echoLine ~= nil and echoLine:find("1 never came back", 1, true) ~= nil, tostring(echoLine))
local money = Find(lines, "guildbank: money")
Check("/wl verify: the bank's money at login", money ~= nil and money:find("12345", 1, true) ~= nil, tostring(money))

-- the launch-night probes taken from the scan of 31/10
local eventLine = Find(lines, " eventnames: ")
Check("/wl verify: event names the client refuses are listed, a refusal stays inside", eventLine ~= nil
    and eventLine:find("LOOK", 1, true) == 1 and eventLine:find(eventError, 1, true) ~= nil
    and eventLine:find(eventRefused, 1, true) ~= nil and not eventLine:find(eventFine, 1, true), tostring(eventLine))
local inviteLine = Find(lines, " invitename: ")
Check("/wl verify: our invites against the game's line, counts and forms only", inviteLine ~= nil
    and inviteLine:find("LOOK", 1, true) == 1 and inviteLine:find("4 invite", 1, true) ~= nil
    and inviteLine:find("that character 1", 1, true) ~= nil and inviteLine:find("first name 1", 1, true) ~= nil
    and inviteLine:find("no surname 1", 1, true) ~= nil and inviteLine:find("no line read 1", 1, true) ~= nil
    and not inviteLine:find("Zz", 1, true), tostring(inviteLine))
Check("/wl verify: the invite is not a restricted call", not Find(lines, "restricted: InviteUnit"), tostring(Find(lines, "restricted: InviteUnit") or ""))
local capLine = Find(lines, " errorcap: ")
Check("/wl verify: no BugGrabber, the errors are not counted", capLine ~= nil and capLine:find("SKIP", 1, true) == 1, tostring(capLine))
local function CapRun(counter)
    BugGrabber = { GetSessionId = function() return 7 end, GetDB = function() return {
        { session = 7, counter = counter, message = "x", stack = "" }, { session = 6, counter = 500, message = "x", stack = "" } } end }
    local from = #M.prints
    M.Call(W.slash.verify, "quick")
    BugGrabber = kept.grabber
    return Find(Lines(from + 1), " errorcap: ")
end
local under, over = CapRun(99), CapRun(100)
Check("/wl verify: 100 errors in this session are to look at, 99 or another session's are not", under ~= nil and under:find("OK", 1, true) == 1
    and over ~= nil and over:find("LOOK", 1, true) == 1, tostring(under) .. " / " .. tostring(over))
-- audit 10/11 (M19): an error of ours raised again during the run. BugGrabber keeps one entry per error and counts its
-- repeats: with one per entry nothing moved, and the release gate read "no new Lua error"
do
    local reads = 0
    BugGrabber = { GetSessionId = function() return 7 end, GetDB = function()
        reads = reads + 1 -- the first read is the count before the probes; the error comes back twice after it
        return { { session = 7, counter = reads == 1 and 1 or 3, message = "Interface/AddOns/WarLegendRaidTool/Core.lua:1: again", stack = "" } }
    end }
    local from = #M.prints
    M.Call(W.slash.verify, "quick")
    BugGrabber = kept.grabber
    local line = Find(Lines(from + 1), " errors: ")
    Check("/wl verify: an error of ours raised again during the run counts as new", line ~= nil and line:find("LOOK", 1, true) == 1
        and line:find("2 new", 1, true) ~= nil, tostring(line))
end

-- the report: opens by itself, the same with /wl verify copy, and reads back
local first = shown
Check("/wl verify: the report opens to copy", type(first) == "string" and first:find("WLRTV1:", 1, true) ~= nil, tostring(first):sub(1, 60))
shown = nil
M.Call(W.slash.verify, "copy")
Check("/wl verify copy: the last report again", shown == first, tostring(shown):sub(1, 60))
local packed = type(first) == "string" and first:match("WLRTV1:\n(.*)")
local report = packed and W.Inflate((packed:gsub("\n", "")), 200000)
Check("/wl verify: the compressed report holds the context, the lines and the summary", type(report) == "string"
    and report:find("WLRT ", 1, true) == 1 and report:find("INFO client: ", 1, true) ~= nil and report:find("summary: ", 1, true) ~= nil
    and not report:find("Zzsender", 1, true), tostring(report):sub(1, 80))

-- the full run: the module tests, then the report 70 s later
shown = nil
local prints2, errors2 = #M.prints, M.errorSeq or 0
M.Call(W.slash.verify, "")
local waiting = shown == nil
M.Advance(71)
Check("/wl verify: with the module tests, the report comes when they are over", waiting and type(shown) == "string",
    tostring(waiting) .. " " .. tostring(shown):sub(1, 40))
local testError = Find(Lines(prints2 + 1), "W.TestAll error")
Check("/wl verify: the module tests start", not testError, testError or "")
Check("/wl verify: no Lua error during the module tests", (M.errorSeq or 0) == errors2, tostring(M.lastError))

M.combat = true
local printsC = #M.prints
M.Call(W.slash.verify, "quick")
Check("/wl verify: refused in combat", #Lines(printsC + 1) == 0, tostring(#Lines(printsC + 1)))
M.combat = false

GetGuildBankMoney, C_Secrets, LoggingChat, W.TextPopup = kept.bank, kept.secrets, kept.logging, kept.popup
C_EventUtils, BugGrabber, ERR_INVITE_PLAYER_S = kept.events, kept.grabber, kept.inviteLine
