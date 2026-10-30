-- WarLegend RaidTool - what tools/smoke.js plays in the simulated client (not shipped, fengari = Lua 5.3).
-- Phases: login, every /wl command, every window tab, "Test all", a raid with a fight, hostile addon messages,
-- event floods (cost), then the caller runs it again after a /reload (saved data kept, French client).
local M, opts = ...
local report = { phases = {}, perf = {}, fuzz = {} }
M.report = report

local function Phase(name) M.phase = name; report.phases[#report.phases + 1] = name end
local function Count(list, phase) local n = 0; for _, e in ipairs(list) do if e.phase == phase then n = n + 1 end end return n end
-- trust checks (security review, secret values...): name, passed, what was seen
report.checks = {}
local function Check(name, ok, detail) report.checks[#report.checks + 1] = { name = name, ok = ok and true or false, detail = detail } end

-- login
Phase("login")
M.version = opts.version
M.player.race = opts.race
M.LoadAddOn("WarLegendRaidTool")
-- not preloaded at this login: the first check below needs the raid addon out of memory (a message then loads it)
local preload0 = WLRT and WLRT.db and WLRT.db.ui.preloadRaid
if WLRT and WLRT.db then WLRT.db.ui.preloadRaid = false end
M.loggedIn = true
M.Fire("PLAYER_LOGIN")
M.Fire("PLAYER_ENTERING_WORLD", true, false)
M.Advance(1)
M.Fire("GUILD_ROSTER_UPDATE", false)
M.Fire("PLAYER_GUILD_UPDATE", "player")
M.Advance(35)
local W = WLRT
if not W then return report end
report.access = W.access

-- a raid prefix on the guild channel, INSTANCE_CHAT or in a battleground loads nothing (master audit of 29/10, item 8: one
-- message on GUILD loaded the raid addon on the whole guild); on the raid channel it does. The rest of that audit: phase "hardening"
local raidAtLogin = W.raidLoaded
M.Fire("CHAT_MSG_ADDON", "WLRT_INSQ", "1", "GUILD", "Guildie1-Forever", "Guildie1-Forever", 0, 0, "", 0)
local byGuild = W.raidLoaded
M.Fire("CHAT_MSG_ADDON", "WLRT_BUFF", "A^Smoketest^x", "INSTANCE_CHAT", "Raider2-Forever", "Raider2-Forever", 0, 0, "", 0)
local byInstance = W.raidLoaded
M.instance = "pvp"
M.Fire("CHAT_MSG_ADDON", "WLRT_BUFF", "A^Smoketest^x", "RAID", "Raider2-Forever", "Raider2-Forever", 0, 0, "", 0)
local byBattleground = W.raidLoaded
M.instance = nil
M.Fire("CHAT_MSG_ADDON", "WLRT_INSQ", "1", "RAID", "Raider2-Forever", "Raider2-Forever", 0, 0, "", 0)
Check("a raid prefix loads the raid addon from the raid channel, not the guild channel, INSTANCE_CHAT or a battleground",
    not (raidAtLogin or byGuild or byInstance or byBattleground) and W.raidLoaded, string.format("at login %s, by the guild channel %s, by INSTANCE_CHAT %s, in a battleground %s, by the raid channel %s",
    tostring(raidAtLogin), tostring(byGuild), tostring(byInstance), tostring(byBattleground), tostring(W.raidLoaded)))
W.db.ui.preloadRaid = preload0
M.Advance(1)

-- every /wl command, without argument (as typed alone); again later in a raid
local function Commands(label)
    Phase(label)
    local names = {}
    for name in pairs(W.slash or {}) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        M.phase = label .. " /wl " .. name
        M.Call(W.slash[name], "")
        M.Advance(1)
        if W.StopTests then M.Call(W.StopTests, true) end
    end
    return names
end
report.commands = Commands("commands")
M.phase = "/wl help"
M.Call(SlashCmdList.WARLEGENDRT, "help")
M.Call(SlashCmdList.WARLEGENDRT, "")
M.Advance(1)

-- the window, every tab
local function AllTabs(label)
    Phase(label)
    if not W.IsShown() then M.Call(W.Toggle) end
    M.Advance(0.5)
    local keys = {}
    for _, m in ipairs(W.modules) do keys[#keys + 1] = m.key end
    for _, key in ipairs(keys) do
        M.phase = label .. " " .. key
        M.Call(W.Select, key)
        M.Advance(0.2)
    end
    M.Advance(3) -- the tabs filled slowly (W.IndexTabsSlowly)
    report.tabs = #keys
    M.Call(W.Hide)
end
AllTabs("window")

-- Test all: modules show fake data, end by themselves, never send anything
Phase("test all")
local chat0, addon0 = #M.chat, #M.addon
M.Call(W.TestAll)
M.Advance(70)
report.testChat, report.testAddon = #M.chat - chat0, #M.addon - addon0
M.Call(W.StopTests, true)

-- a raid of 10: the raid addon loads, a ready check, a pull, a fight, the end
Phase("raid")
local CLASSES = { "WARRIOR", "PRIEST", "MAGE", "ROGUE", "DRUID", "HUNTER", "PALADIN", "WARLOCK", "SHAMAN" }
M.group = { M.player }
for i = 2, 10 do M.group[i] = { name = "Raider" .. i, class = CLASSES[(i % #CLASSES) + 1] } end
M.instance = "raid"
M.Fire("GROUP_ROSTER_UPDATE")
M.Fire("PLAYER_ENTERING_WORLD", false, false)
M.Advance(3)
report.raidLoaded = W.raidLoaded
M.Fire("READY_CHECK", "Smoketest", 30)
M.Advance(2)
M.Fire("READY_CHECK_CONFIRM", "raid2", true)
M.Fire("READY_CHECK_FINISHED")

-- the secret values of the fake client (tools/smoke/wow.lua) behave as the game's: what fails, by name
local SHIELD_WALL = 871
local function SecretSelfTest(inCombat)
    local info = C_Spell.GetSpellCooldown(SHIELD_WALL)
    local v, bad = info and info.startTime, {}
    local function Want(what, ok) if not ok then bad[#bad + 1] = what end end
    if not inCombat then Want("plain out of combat", v ~= nil and not issecretvalue(v)); return bad end
    Want("issecretvalue", issecretvalue(v) == true)
    Want("type", type(v) == "number")
    Want("W.Safe", W.Safe(v) == nil)
    Want("test for nil", pcall(function() return v ~= nil end))
    for _, t in ipairs({ { "==", function() return v == 0 end }, { "<", function() return v < 1 end }, { "+", function() return v + 1 end },
        { "..", function() return v .. "" end }, { "#", function() return #v end }, { "table key", function() local x = {}; x[v] = 1 end },
        { "index", function() return v.x end }, { "table.concat", function() return table.concat({ v }) end } }) do
        Want(t[1] .. " raises", not pcall(t[2]))
    end
    Want("tostring / string.format / math.floor give secrets", issecretvalue(tostring(v)) and issecretvalue(string.format("%d", v)) and issecretvalue(math.floor(v)))
    return bad
end
-- RaidCooldowns (EllesmereUI review 28/10): Shield Wall cast in combat, then a group mate asks "Q". C_Spell.GetSpellCooldown
-- is secret in combat: the "K" answer must not say the spell is ready ("shieldwall:0"). Asked again after the fight, it
-- must list the spell with its end time, else the bench does not see the spell known and the check proves nothing. The
-- spell functions answer "not known" in this client: Shield Wall is known for this fight only.
local function CooldownAnswers(from) -- what the "K" answers sent since M.addon[from] say about Shield Wall (false: not listed)
    local out = {}
    for i = from + 1, #M.addon do
        local a = M.addon[i]
        if a.prefix == "WLRT_CD2" and tostring(a.msg):sub(1, 2) == "K^" then out[#out + 1] = tostring(a.msg):match("shieldwall:(%d+)") or false end
    end
    return out
end
local function AskCooldowns() M.Fire("CHAT_MSG_ADDON", "WLRT_CD2", "Q", "RAID", "Raider2-Forever", "Raider2-Forever", 0, 0, "", 0) end
local knowsBefore = { IsPlayerSpell = rawget(_G, "IsPlayerSpell"), IsSpellKnown = rawget(_G, "IsSpellKnown"),
    known = C_SpellBook and C_SpellBook.IsSpellKnown, inBook = C_SpellBook and C_SpellBook.IsSpellInSpellBook }
local function Knows(id) return id == SHIELD_WALL end
IsPlayerSpell, IsSpellKnown = Knows, Knows
if C_SpellBook then C_SpellBook.IsSpellKnown, C_SpellBook.IsSpellInSpellBook = Knows, Knows end

M.Fire("ENCOUNTER_START", 663, "Lucifron", 9, 10)
-- PLAYER_REGEN_DISABLED comes just before the lockdown (secure frames can still change), _ENABLED just after it
M.Fire("PLAYER_REGEN_DISABLED")
M.combat = true
Phase("combat")
local selfTest = SecretSelfTest(true)
for i = 1, 40 do
    M.Fire("UNIT_AURA", "raid" .. ((i % 10) + 1), { isFullUpdate = true })
    M.Fire("UNIT_HEALTH", "raid" .. ((i % 10) + 1))
end
-- auras that changed (secret in combat: SecretWhenAurasRestricted)
for i = 1, 10 do
    M.Fire("UNIT_AURA", i == 1 and "player" or "raid" .. i, { isFullUpdate = false, updatedAuraInstanceIDs = { 200 + i }, removedAuraInstanceIDs = { 300 + i },
        addedAuras = { { auraInstanceID = 100 + i, spellId = 774, name = "Rejuvenation", icon = 136081, applications = 0, duration = 12,
            expirationTime = M.now + 12, sourceUnit = "raid2", isHelpful = true, isHarmful = false, dispelName = "Magic" } } })
end
M.spellCooldowns[SHIELD_WALL] = { M.now, 300 }
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-1-1-871-0000000001", SHIELD_WALL)
M.Advance(6) -- the cooldown answers wait 5 s after the last one
local inCombatFrom = #M.addon
AskCooldowns()
M.Advance(4)
local inCombat = CooldownAnswers(inCombatFrom)
M.Call(W.slash.rc or function() end, "")
M.combat = false
Phase("after combat")
M.Fire("PLAYER_REGEN_ENABLED")
M.Fire("ENCOUNTER_END", 663, "Lucifron", 9, 10, 1)
M.Advance(5)
for _, what in ipairs(SecretSelfTest(false)) do selfTest[#selfTest + 1] = what end
Check("secret values of the bench behave as the game's in combat, plain after it", #selfTest == 0, table.concat(selfTest, ", "))
local afterFrom = #M.addon
AskCooldowns()
M.Advance(4)
local after = CooldownAnswers(afterFrom)
local listed = false
for _, v in ipairs(after) do if v and v ~= "0" then listed = true end end
local said = {}
for _, v in ipairs(inCombat) do said[#said + 1] = v and ("shieldwall:" .. v) or "not listed" end
Check("RaidCooldowns: a cooldown hidden in combat (secret) is not answered as ready", listed and not tContains(inCombat, "0"),
    listed and ("in combat: " .. (#said > 0 and table.concat(said, ", ") or "no answer")) or "after the fight: no answer listing shieldwall (the bench did not see it known)")
M.spellCooldowns[SHIELD_WALL] = nil
IsPlayerSpell, IsSpellKnown = knowsBefore.IsPlayerSpell, knowsBefore.IsSpellKnown
if C_SpellBook then C_SpellBook.IsSpellKnown, C_SpellBook.IsSpellInSpellBook = knowsBefore.known, knowsBefore.inBook end
AllTabs("raid window")
report.raidCommands = Commands("raid commands")

-- trust checks of the security review: a stranger is flagged on prompts, a burst of questions schedules one reply
Phase("trust")
Check("guild member not flagged", W.Sender and not W.Sender("Guildie1-Forever"):find("|cff", 1, true))
Check("stranger flagged as not in guild", W.Sender and W.Sender("Stranger-Other"):find("|cff", 1, true) ~= nil)
M.Advance(10)
local timers0 = M.PendingTimers()
for _ = 1, 50 do M.Fire("CHAT_MSG_ADDON", "WLRT_CD2", "Q", "RAID", "Raider2-Forever", "Raider2-Forever", 0, 0, "", 0) end
Check("50 cooldown questions schedule at most 1 reply", M.PendingTimers() - timers0 <= 1, M.PendingTimers() - timers0)
M.Advance(5)

-- every addon in memory (PvP: battleground frames, Skyborne: a Skyborne character), so all their prefixes are listened to
for _, n in ipairs({ "WarLegendRaidTool_PvP", "WarLegendRaidTool_Skyborne" }) do C_AddOns.LoadAddOn(n) end
M.Fire("PLAYER_ENTERING_WORLD", false, false)
M.Advance(3)

-- hostile addon messages on every prefix: from guild mates (guild, officer), raid members (a raid assistant among them),
-- whispered by them and by a stranger. The same --seed and --fuzz give the same messages: the one behind the first Lua
-- error of each prefix is kept to replay it
Phase("fuzz")
local seed = opts.seed or 12345
report.seed = seed
local function Rand(n) seed = (seed * 1103515245 + 12345) % 2147483648; return (seed % n) + 1 end
local function Errs() return M.errorSeq or 0 end
-- a text as a Lua string literal (control characters, quotes, bytes past 127 as \ddd), to paste it back
local function Lit(s) return '"' .. (s:gsub('[%c"\\\128-\255]', function(c) return string.format("\\%03d", c:byte()) end)) .. '"' end
-- text from other players reaching the screen: every escape code of the pieces holds this mark (tools/smoke/wow.lua
-- M.Shown reads each text shown from now until the floods); the item links the addon shows itself have none
local MARK = "zq9"
M.mark, M.MARK = MARK, MARK:upper()
local TEX = "|TInterface\\Icons\\" .. MARK .. ":4000|t"
-- line breaks of the pieces, told apart from the addon's own line between two texts (wow.lua LiveCode)
local BREAK, NBREAK = MARK .. "<\n>" .. MARK, MARK .. "<|n>" .. MARK
local CODES = TEX .. "|A:" .. MARK .. ":64:64|a|H" .. MARK .. ":1|h[" .. MARK .. "]|h|K" .. MARK .. "|k" .. NBREAK
local PIECES = { "", "0", "1", "-1", "2147483648", "1e309", "-1e309", "nan", "inf", "0x7fffffff", "1.5", "999999999999",
    "|cffff0000red|r", "|Hitem:19019::::::::60:::::|h[x]|h", TEX, "|A:" .. MARK .. ":64:64|a", "|H" .. MARK .. ":1|h[x]|h",
    "|Hplayer:" .. MARK .. "|h[" .. MARK .. "]|h", "|K" .. MARK .. "|k", BREAK, NBREAK, "||", "|", "~", "~1~2~3",
    "^", "^^^", ";", ",", ":", "[", "]", "/gquit", "/run print(1)", "\n", "\0", "Raider2", "Raider2-Forever", "Smoketest",
    string.rep("A", 255), "é", "\255\254", "raid1", "player", "Q", "?", "R", "S", "A", "D", "1:2:3", "a=b", "{}" }
local function Junk()
    local n = Rand(12) - 1
    local parts = {}
    for i = 1, n do parts[i] = PIECES[Rand(#PIECES)] end
    local s = table.concat(parts, ({ "^", ":", ";", ",", "\t", " ", "|", "~" })[Rand(8)])
    if Rand(4) == 1 then s = PIECES[Rand(#PIECES)] .. s end
    return s:sub(1, 255)
end
local prefixes = {}
for p in pairs(M.prefixes) do prefixes[#prefixes + 1] = p end
table.sort(prefixes)
-- Raider4 is a raid assistant until the tabs are drawn again below: what only a leader may send reaches its handler
M.group[4].assist = true
M.Fire("GROUP_ROSTER_UPDATE")
M.Advance(1)
local SENDERS = { { "Raider2-Forever", "RAID" }, { "Guildie1-Forever", "GUILD" }, { "Raider3-Forever", "WHISPER" }, { "Stranger-Other", "WHISPER" },
    { "Raider4-Forever", "PARTY" }, { "Guildie2-Forever", "OFFICER" }, { "Stranger-Other", "CHANNEL" }, { "Raider4-Forever", "RAID" } }
local perPrefix = opts.fuzz or 300
for _, p in ipairs(prefixes) do
    M.phase = "fuzz " .. p
    local chatBefore, addonBefore, sensBefore = #M.chat, #M.addon, #M.sensitive
    local first, msg, s
    -- the message behind the first error (later: in a timer after it, it was the last one sent)
    local function Blame(e0, i, later)
        if not first and msg and Errs() > e0 then first = { n = i, msg = Lit(msg), from = s[1], channel = s[2], err = M.lastError, later = later } end
    end
    for i = 1, perPrefix do
        s, msg = SENDERS[Rand(#SENDERS)], Junk()
        local e0 = Errs()
        M.Fire("CHAT_MSG_ADDON", p, msg, s[2], s[1], s[1], 0, 0, "", 0)
        Blame(e0, i)
        if i % 50 == 0 then e0 = Errs(); M.Advance(0.5); Blame(e0, i, true) end
    end
    local e0 = Errs()
    M.Advance(2)
    Blame(e0, perPrefix, true)
    report.fuzz[#report.fuzz + 1] = { prefix = p, sent = perPrefix, replies = #M.addon - addonBefore, chat = #M.chat - chatBefore,
        sensitive = #M.sensitive - sensBefore, first = first }
end

-- the addon's own messages (valid requests and answers), replayed 100 times by other players: replies stay bounded
Phase("replay")
local seen, samples = {}, {}
for _, a in ipairs(M.addon) do
    local k = a.prefix .. "\1" .. tostring(a.msg)
    seen[a.prefix] = seen[a.prefix] or 0
    if not seen[k] and seen[a.prefix] < 4 then seen[k] = true; seen[a.prefix] = seen[a.prefix] + 1; samples[#samples + 1] = a end
end
report.replay = {}
for _, a in ipairs(samples) do
    M.phase = "replay " .. a.prefix
    local before, chatBefore, sensBefore = #M.addon, #M.chat, #M.sensitive
    for i = 1, 100 do
        local s = SENDERS[(i % 3) + 1]
        M.Fire("CHAT_MSG_ADDON", a.prefix, a.msg, a.channel == "CHANNEL" and "CHANNEL" or s[2], s[1], s[1], 0, 0, "", 0)
        if i % 10 == 0 then M.Advance(1) end
    end
    M.Advance(5)
    report.replay[#report.replay + 1] = { prefix = a.prefix, msg = tostring(a.msg):sub(1, 40), replies = #M.addon - before,
        chat = #M.chat - chatBefore, sensitive = #M.sensitive - sensBefore }
end
-- shaped hostile messages (random junk rarely has the shape a handler keeps, so it seldom reaches the screen): the
-- addon's own messages with one field ("^" or "|" separated) replaced by a marked piece, and the fields a handler
-- stores and shows (class spec / availability, layer zone, the buff lines a leader assigns), from a guild mate and
-- from the raid assistant
Phase("shaped")
local MARKED = { TEX, CODES, "|H" .. MARK .. ":1|h[" .. MARK .. "]|h", BREAK, "||T" .. MARK .. ":4000||t" }
local function Variants(msg, out)
    local starts = { 1 }
    for pos in msg:gmatch("()[%^|]") do starts[#starts + 1] = pos + 1 end
    for k = 1, math.min(#starts, 8) do
        local a, b = starts[k], (starts[k + 1] or #msg + 2) - 2
        for _, p in ipairs(MARKED) do out[#out + 1] = msg:sub(1, a - 1) .. p .. msg:sub(b + 1) end
    end
end
local shapedMsgs = {}
for _, a in ipairs(samples) do
    local list = {}
    Variants(tostring(a.msg), list)
    for _, m in ipairs(list) do shapedMsgs[#shapedMsgs + 1] = { a.prefix, m } end
end
for _, p in ipairs(MARKED) do
    shapedMsgs[#shapedMsgs + 1] = { "WLRT_PROFILE", "1^Tank^" .. p .. "^" .. p, "GUILD" }
    shapedMsgs[#shapedMsgs + 1] = { "WLRT_LAYER", string.format("1^5-7^1411^%d^", GetServerTime()) .. p, "GUILD" }
    shapedMsgs[#shapedMsgs + 1] = { "WLRT_BUFF", "A^Smoketest^" .. p .. " | " .. p, "RAID" }
end
local shaped = { sent = #shapedMsgs }
report.shaped = shaped
local addon0, chatS0, sensS0 = #M.addon, #M.chat, #M.sensitive
for i, s in ipairs(shapedMsgs) do
    local channel = s[3] or (i % 2 == 0 and "GUILD" or "RAID")
    -- under the per-sender limit of Dispatch (40 messages in 5 s): guild mates take turns, the assistant 1 every 0.25 s
    local from = channel == "GUILD" and string.format("Guildie%d-Forever", 3 + i % 10) or "Raider4-Forever"
    M.phase = "shaped " .. s[1]
    local e0 = Errs()
    M.Fire("CHAT_MSG_ADDON", s[1], s[2], channel, from, from, 0, 0, "", 0)
    if not shaped.first and Errs() > e0 then shaped.first = { n = i, msg = Lit(s[2]), from = from, channel = s[1] .. " " .. channel, err = M.lastError } end
    M.Advance(0.25, 0.25)
end
M.Advance(5)
shaped.replies, shaped.chat, shaped.sensitive = #M.addon - addon0, #M.chat - chatS0, #M.sensitive - sensS0
-- what the hostile messages left (lists, maps) drawn again: every tab, the world map (pins); M.Shown reads it
AllTabs("window after hostile messages")
M.Call(WorldMapFrame.Show, WorldMapFrame)
M.Advance(1)
M.Call(WorldMapFrame.Hide, WorldMapFrame)
M.group[4].assist = nil
M.Fire("GROUP_ROSTER_UPDATE")
M.Advance(1)

-- pathological long texts (audit 28/10) on the prefixes read by W.OnAddonLong: one character repeated, no separator.
-- A pattern with a repeated class before a literal ("(.-)%s*=", "([^=;]+)=", "(%d+):(%d+)") is quadratic / cubic on
-- it: one message froze every client. Each case, within its prefix's size cap and past it, must stay fast. The sender
-- is a guild mate made group lead, so the texts reach the parsers. The fake compression has no size gain: 64 chunks
-- of 220 (14 KB) is the most the transport carries here (in the game 64 KB of one letter deflates into one chunk).
Phase("long texts")
M.Advance(6) -- Readiness answers one ask per 5 s
local isLead = W.IsGroupLead
W.IsGroupLead = function() return true end
local function SendLongText(prefix, text, sender)
    local esc = text:gsub("~", "~1"):gsub("\n", "~2"):gsub("|", "~3")
    local n = math.max(1, math.ceil(#esc / 220))
    local id = string.format("%d", 100 + Rand(899)) -- Rand gives floats here (fengari): "523.0" is no id
    local function Chunk(i)
        M.Fire("CHAT_MSG_ADDON", prefix, id .. ":" .. i .. ":" .. n .. ":" .. esc:sub((i - 1) * 220 + 1, i * 220), "RAID", sender, sender, 0, 0, "", 0)
    end
    for i = 1, n - 1 do
        Chunk(i)
        if i % 30 == 0 then M.Advance(5.5) end -- the per-sender limit of Dispatch (40 in 5 s; 5 ends a hair short)
    end
    local t0 = os.clock()
    Chunk(n)
    M.Advance(3) -- Readiness reads the list 1-3 s after the ask
    return (os.clock() - t0) * 1000
end
for _, c in ipairs({
    { "WLRT_RDYQ", "123456\n", " ", 2000 }, { "WLRT_RDYQ", "123456\n", " ", 14000 },
    { "WLRT_CON", "L^", "7", 2000 }, { "WLRT_CON", "L^", "7", 14000 }, { "WLRT_CON", "Q^", "7", 2000 },
    { "WLRT_PROF", "D^", "a", 14000 }, { "WLRT_PROF", "D^^", "a", 14000 }, { "WLRT_PROF", "D^^^", "a", 14000 },
}) do
    M.phase = "long " .. c[1]
    local ms = SendLongText(c[1], c[2] .. string.rep(c[3], c[4]), string.format("Guildie%d-Forever", Rand(20) + 1))
    Check(string.format("%s '%s' + %d x '%s' handled in < 1 s", c[1], (c[2]:gsub("\n", "\\n")), c[4], c[3]), ms < 1000,
        string.format("%.0f ms", ms))
end
W.IsGroupLead = isLead
M.Advance(5)

-- chat lines from other players (not addon messages): whispers, Battle.net whispers, group / guild / public chat,
-- system and battleground messages, loot lines, with the game's arguments (ChatInfoDocumentation.lua: text, playerName,
-- languageName, channelName, playerName2, specialFlags, zoneChannelID, channelIndex, channelBaseName, languageID,
-- lineID, guid, bnSenderID...), from guild mates, raid members and strangers; the chat filters run on each line as the
-- chat frame does. As installed (InviteTool, "!sr" and Summon off), then with their checkbox on. A line takes < 1 s,
-- sends no chat line and acts for no one, except what AGENTS.md accepts: InviteTool's invite of the sender of a keyword
-- (Battle.net: the friend's character), once per 30 s per sender, and the "!sr" answers whispered to the sender, 3 per
-- 10 s (rule 3, LootCouncil.lua Reply)
Phase("chat lines")
-- a checkbox of a module's tab, clicked as the player would (its label in the client's language)
local function ClickCheck(label, on)
    local text = W.L(label)
    for _, f in ipairs(M.frames) do
        local l = rawget(f, "label")
        if f.__type == "CheckButton" and type(l) == "table" and rawequal(l.__text, text) then -- rawequal: a text may be secret
            if f:GetChecked() ~= on then f:SetChecked(on); M.Script(f, "OnClick", "LeftButton", true) end
            return true
        end
    end
    return false
end
local SWITCHES = { "Invite on keyword whisper", "Accept \"!sr [item]\" whispers", "Summon list (type 123 in the raid chat)" }
local GUILD = { "Guildie1-Forever", "Guildie2-Forever", "Guildie4-Forever" }
local GROUP = { "Raider2-Forever", "Raider3-Forever", "Raider5-Forever" }
local OTHERS = { "Stranger-Other", "Stranger2-Other" }
local function Mix(...)
    local t = {}
    for _, l in ipairs({ ... }) do for _, n in ipairs(l) do t[#t + 1] = n end end
    return t
end
local ANYONE, MATES = Mix(GUILD, GROUP, OTHERS), Mix(GROUP, OTHERS)
-- event, who sends it (none: the server, "bn": a Battle.net friend)
local CHAT_EVENTS = {
    { "CHAT_MSG_WHISPER", ANYONE }, { "CHAT_MSG_BN_WHISPER", "bn" }, { "CHAT_MSG_RAID", MATES }, { "CHAT_MSG_RAID_LEADER", MATES },
    { "CHAT_MSG_PARTY", MATES }, { "CHAT_MSG_PARTY_LEADER", MATES }, { "CHAT_MSG_INSTANCE_CHAT", MATES },
    { "CHAT_MSG_INSTANCE_CHAT_LEADER", MATES }, { "CHAT_MSG_SAY", ANYONE }, { "CHAT_MSG_YELL", ANYONE }, { "CHAT_MSG_CHANNEL", ANYONE },
    { "CHAT_MSG_GUILD", GUILD }, { "CHAT_MSG_OFFICER", GUILD }, { "CHAT_MSG_SYSTEM" }, { "CHAT_MSG_BG_SYSTEM_HORDE" },
    { "CHAT_MSG_BG_SYSTEM_ALLIANCE" }, { "CHAT_MSG_BG_SYSTEM_NEUTRAL" }, { "CHAT_MSG_LOOT" },
}
local ITEM = "|Hitem:19019::::::::60:::::|h[x]|h"
-- what the parsers look for (keywords, "!sr", duel countdown, base assaulted, flag, loot line, Myslot tag), alone or
-- followed by junk
local KEYWORDS = { "inv", "INV please", "  inv  ", "+1", "123", "!sr", "!SR ", "!sr 19019", "!sr 0", "!sr -5", "!sr 99999999999",
    "!sr nan", "!sr 1e309", "!sr " .. ITEM, "!sr " .. TEX, "Duel starting: 3", "Duel starting: 99", "Duel starting: ",
    "Raider2 has assaulted the Farm!", "The Horde has taken the Stables!", "The flag was captured!", "attaqué la ferme !",
    "Raider2 receives loot: " .. ITEM .. ".", "You receive loot: " .. ITEM .. "x2.", "[Myslot: Raider2 - " .. MARK .. "]" }
local LONG = { "a", " ", "|", "~", "%", "!", "é", "[", "9", ":", "\n" } -- one of them repeated past 255 bytes
local function ChatText()
    local r = Rand(10)
    if r <= 4 then return Junk() end
    local k = KEYWORDS[Rand(#KEYWORDS)]
    if r <= 8 then return Rand(2) == 1 and k or k .. " " .. Junk() end
    return (Rand(3) == 1 and k or "") .. string.rep(LONG[Rand(#LONG)], 300 + Rand(3700))
end
local lineID = 0
local function FireChat(ev, text, from, bn)
    lineID = lineID + 1
    local chan, index, base = "", 0, ""
    if ev == "CHAT_MSG_CHANNEL" then chan, index, base = "1. General - Orgrimmar", 1, "General" end
    local guid = (from ~= "" and not bn) and string.format("Player-1-%08X", 4096 + lineID % 4096) or ""
    M.Fire(ev, text, from, "Common", chan, from, "", 0, index, base, 7, lineID, guid, bn or 0, false, false, false, false)
    M.ChatFilters(ev, text, from, "Common", chan, from, "", 0, index, base, 7, lineID, guid, bn or 0, false, false, false, false)
end
-- a Battle.net friend playing a character of my realm, on my game version
local accountInfo = C_BattleNet and C_BattleNet.GetAccountInfoByID
C_BattleNet = C_BattleNet or {}
C_BattleNet.GetAccountInfoByID = function(id)
    return { gameAccountInfo = { isOnline = true, characterName = string.format("Bnfriend%d", id), wowProjectID = WOW_PROJECT_ID,
        realmName = M.player.realm } }
end
-- bad: what is not allowed, by kind (action, chat line, slow line, missing checkbox)
local chat = { events = #CHAT_EVENTS, sent = 0, worst = 0, chatOk = 0, actionsOk = 0, bad = {}, badChat = {}, badActions = {}, first = {} }
report.chatLines = chat
local cur, acts = {}, {}
local sensitive = M.Sensitive
M.Sensitive = function(what)
    acts[#acts + 1] = { what = what, at = M.now, ev = cur.ev, from = cur.from, char = cur.char, on = cur.on }
    return sensitive(what)
end
local perEvent = math.max(20, math.floor((opts.fuzz or 300) / 3))
local srFrom, chat0 = {}, #M.chat -- the senders of a whispered "!sr" line while it was on
for _, on in ipairs({ false, true }) do
    if on then
        for _, label in ipairs(SWITCHES) do
            if not ClickCheck(label, true) then chat.bad[#chat.bad + 1] = "checkbox not found: " .. label end
        end
        -- one sender in a hurry: 10 "!sr" and 10 keyword whispers, 10 keyword Battle.net whispers in 2 s (at most 3
        -- answers and 1 invite each)
        M.phase = "chat flood (switched on)"
        for k = 1, 10 do
            for _, w in ipairs({ { "CHAT_MSG_WHISPER", k % 2 == 0 and "!sr" or "!sr 19019", GUILD[1] }, { "CHAT_MSG_WHISPER", "inv", GUILD[1] },
                { "CHAT_MSG_BN_WHISPER", "inv", "|Kq1|k", 1 } }) do
                cur.ev, cur.from, cur.on, cur.char = w[1], w[3], true, w[4] and "Bnfriend1" or nil
                if w[2]:find("^!sr") then srFrom[w[3]] = true end
                FireChat(w[1], w[2], w[3], w[4])
                chat.sent = chat.sent + 1
            end
            M.Advance(0.2, 0.2)
        end
    end
    for _, e in ipairs(CHAT_EVENTS) do
        local ev = e[1]
        M.phase = "chat " .. ev .. (on and " (switched on)" or "")
        local text, from, bn
        local function Blame(e0, i, later)
            if not chat.first[ev] and Errs() > e0 then chat.first[ev] = { n = i, msg = Lit(text), from = from, err = M.lastError, later = later } end
        end
        for i = 1, perEvent do
            from, bn = "", nil
            if e[2] == "bn" then bn = Rand(3); from = string.format("|Kq%d|k", bn)
            elseif e[2] then from = e[2][Rand(#e[2])] end
            text = ChatText()
            cur.ev, cur.from, cur.on, cur.char = ev, from, on, bn and string.format("Bnfriend%d", bn) or nil
            if on and ev == "CHAT_MSG_WHISPER" and text:lower():find("^!sr") then srFrom[from] = true end
            local e0 = Errs()
            local t0 = os.clock()
            FireChat(ev, text, from, bn)
            local ms = (os.clock() - t0) * 1000
            if ms > chat.worst then chat.worst, chat.worstEvent = ms, ev end
            if ms >= 1000 then chat.bad[#chat.bad + 1] = string.format("%s: one line took %.0f ms: %s", ev, ms, Lit(text):sub(1, 200)) end
            Blame(e0, i)
            chat.sent = chat.sent + 1
            if i % 10 == 0 then e0 = Errs(); M.Advance(5, 0.5); Blame(e0, i, true) end
        end
        local e0 = Errs()
        M.Advance(5, 0.5)
        Blame(e0, perEvent, true)
    end
end
for _, label in ipairs(SWITCHES) do ClickCheck(label, false) end
cur.ev, cur.from, cur.on, cur.char = "(after the lines)", "?", false, nil
M.Advance(15, 0.5) -- what is still queued
M.Sensitive = sensitive
C_BattleNet.GetAccountInfoByID = accountInfo
-- actions: InviteUnit of the sender of a whisper while InviteTool is on, 30 s apart per sender (ConvertToRaid before it
-- for a guild member)
local inGuild, lastInvite = {}, {}
for _, n in ipairs(GUILD) do inGuild[n] = true end
for _, a in ipairs(acts) do
    local target = a.char or a.from
    local whisper = a.on and (a.ev == "CHAT_MSG_WHISPER" or a.ev == "CHAT_MSG_BN_WHISPER")
    local invite = whisper and a.what == "InviteUnit " .. tostring(target)
    if invite and a.at - (lastInvite[target] or -1e9) >= 29.999 then
        lastInvite[target] = a.at
        chat.actionsOk = chat.actionsOk + 1
    elseif whisper and a.what == "ConvertToRaid" and inGuild[a.from] then
        chat.actionsOk = chat.actionsOk + 1
    else
        chat.badActions[#chat.badActions + 1] = string.format("%s after %s from %s (%s)%s", a.what, tostring(a.ev), tostring(a.from),
            a.on and "switched on" or "as installed", invite and ": less than 30 s after the last one" or "")
    end
end
-- chat lines: "!sr" answers whispered to whoever whispered "!sr", 3 per 10 s as LootCouncil.lua counts them
local window = {}
for i = chat0 + 1, #M.chat do
    local c = M.chat[i]
    local ok = c.channel == "WHISPER" and c.target ~= nil and srFrom[c.target]
    if ok then
        local w = window[c.target]
        if not w or c.at - w[1] > 10 then w = { c.at, 0 }; window[c.target] = w end
        w[2] = w[2] + 1
        ok = w[2] <= 3
    end
    if ok then chat.chatOk = chat.chatOk + 1
    else chat.badChat[#chat.badChat + 1] = string.format("chat line %s%s: %s", tostring(c.channel), c.target and (" to " .. c.target) or "", Lit(tostring(c.msg)):sub(1, 120)) end
end

-- pasted text: a profile (Settings), a Myslot profile, a Raid Groups preset, a softres.it CSV, as someone could hand it
-- over: junk, huge, deeply nested, NaN / inf / 1e309, escape codes in names, separators only, one very long line. Each
-- is pasted in its box and imported by its button: it takes < 1 s and ends refused, or in the confirmation (profile,
-- Myslot: never answered here) with the saved data untouched; a preset or a soft-res list (saved by the click itself)
-- is saved in its checked form only (then removed). A growing case goes 1 KB, 16 KB, 256 KB while the last size took
-- < 40 ms (code quadratic at 256 KB would freeze the bench too). A valid export is also cut at 20 places (a copy that
-- lost its end), and a watchdog stops an import that never ends (Watched).
Phase("paste")
M.Call(W.Hide)
local function Under(root, test)
    local stack = { root }
    while #stack > 0 do
        local o = table.remove(stack)
        if test(o) then return o end
        for _, c in ipairs(o.__children or {}) do stack[#stack + 1] = c end
    end
end
local function Panel(key) for _, m in ipairs(W.modules) do if m.key == key then return m.panel end end end
local function ButtonIn(root, text)
    return root and Under(root, function(o) return o.__type == "Button" and rawequal(o.__text, text) and o.__scripts.OnClick ~= nil end)
end
local function Click(b) M.Script(b, "OnClick", "LeftButton", false) end
-- saved data as text (keys sorted), to see whether a paste changed it
local function Dump(v, out, depth)
    if M.IsSecret(v) then out[#out + 1] = "secret"; return end -- kept in combat by the addon (the glue reports it)
    if type(v) ~= "table" then out[#out + 1] = type(v) .. ":" .. tostring(v); return end
    if depth > 30 then out[#out + 1] = "{deep}"; return end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return type(a) .. tostring(a) < type(b) .. tostring(b) end)
    out[#out + 1] = "{"
    for _, k in ipairs(keys) do
        out[#out + 1] = type(k) .. ":" .. tostring(k) .. "="
        Dump(v[k], out, depth + 1)
        out[#out + 1] = ","
    end
    out[#out + 1] = "}"
end
local function Saved(names)
    local out = {}
    for _, n in ipairs(names) do out[#out + 1] = n .. "="; Dump(rawget(_G, n), out, 0) end
    return table.concat(out)
end
local function Confirming() return rawget(_G, "WLRTConfirm") and WLRTConfirm:IsShown() or false end
-- where each importer's text goes and the button that imports it
local function ProfileBox()
    local import = ButtonIn(Panel("Settings"), W.L("Import"))
    return import and Under(import.__parent, function(o) return o.__type == "EditBox" end), import
end
local MS = W.Space and W.Space("Myslot")
local function MyslotBox()
    local f = Panel("Myslot")
    if not f then return nil end
    return Under(f, function(o) return o.__type == "EditBox" and o.__parent and o.__parent.__type == "ScrollFrame" end), ButtonIn(f, W.L("Import"))
end
local function PopupBox(key, label) -- the text window (W.TextPopup) a button of the module opens
    return function()
        local open = ButtonIn(Panel(key), W.L(label))
        if not open then return nil end
        Click(open)
        local f = rawget(_G, "WLRTTextPopup")
        if not f then return nil end
        f.nameBox.__text = ""
        return f.box, f.ok
    end
end
-- a valid Myslot export (Myslot/Codec.lua) holding macros whose names and lines carry escape codes, /gquit and Lua code
-- (the first name is past the game's 16 letters, the second within them), on action slots, with a key binding that
-- clicks a button
local function MyslotCrafted()
    local msg = { ver = 42, name = "Raider2", slot = { { id = 1, type = MS.SLOT.MACRO, index = 1 }, { id = 2, type = MS.SLOT.MACRO, index = 2 } },
        macro = { { id = 1, name = TEX .. MARK .. "|Hplayer:" .. MARK .. "|h[x]|h", icon = "INV_MISC_QUESTIONMARK", body = "/gquit\n/run print(1)\n" .. CODES },
            { id = 2, name = "|T" .. MARK .. ":4|t", icon = "INV_MISC_QUESTIONMARK", body = "/gquit\n/run print(1)\n" .. CODES } },
        bind = { { id = 0xFFFF, command = "CLICK " .. CODES .. ":LeftButton", key1 = { key = 1, mod = 0 } } } }
    return MS.Armor(MS.Encode(msg), { "Myslot" }, "\n")
end
-- valid exports, cut at 20 places below (a copy that lost its end): the addon's own profile export, a preset as
-- RaidGroups writes it, a softres.it CSV (quoted fields, a comma in a note)
local function ProfileExport()
    local export = ButtonIn(Panel("Settings"), W.L("Export"))
    local box = ProfileBox()
    if not (export and box) then error("no Export button / text box", 0) end
    box.__text = ""
    local e0 = Errs()
    Click(export)
    if Errs() > e0 then error("Export raised " .. tostring(M.lastError), 0) end
    return box.__text
end
local function PresetExport()
    local players = {}
    for i = 2, 10 do players[#players + 1] = { name = "Raider" .. i, class = CLASSES[(i % #CLASSES) + 1], group = 1 + i % 2, icon = i % 9, ma = i == 2 and 1 or 0 } end
    players[#players + 1] = { name = "Jean Dupont", class = "PRIEST", group = 2, icon = 0, ma = 0 } -- a Forever name: first name and surname
    return "WLRT1:" .. W.RaidGroups.Serialize("Raid night", { players = players })
end
local function SoftResExport()
    return "Item,ItemId,From,Name,Class,Spec,Note,Plus,Date\n" ..
        '"Band of Accuria",17063,Ragnaros,Raider2,Mage,Arcane,,0,"2026-10-28 20:01:02"\n' ..
        '"Onslaught Girdle",19137,Ragnaros,Raider3,Warrior,Fury,"bis, please",1,"2026-10-28 20:02:10"\n' ..
        '"Choker of the Fire Lord",18814,Ragnaros,Raider5,Mage,Fire,,0,"2026-10-28 20:03:44"\n' ..
        '"Cloak of the Shrouded Mists",17102,Ragnaros,Jean Dupont,Priest,Holy,"",0,"2026-10-28 20:04:51"\n' ..
        '"Perdition\'s Blade",18816,Ragnaros,Raider6,Rogue,Combat,,2,"2026-10-28 20:05:30"\n'
end
-- a parser that stops advancing (an endless loop) fails its case instead of hanging the run: past WATCH_LIMIT Lua
-- instructions (some seconds here: a paste takes < 1 s), each count hook raises an error at the line it stopped (code
-- inside a C function, a slow pattern, is not counted: the 1 s limit sees it)
local WATCH_EVERY, WATCH_LIMIT = 10000, 3e8
local function Watched(fn, ...)
    local steps, done = 0, false
    debug.sethook(function()
        if done then return end
        steps = steps + WATCH_EVERY
        if steps > WATCH_LIMIT then error(string.format("watchdog: %d Lua instructions without returning", steps), 2) end
    end, "", WATCH_EVERY)
    fn(...)
    done = true
    debug.sethook()
    return steps > WATCH_LIMIT
end
-- a preset / soft-res name as saved: no escape code, control character or separator of our strings, short
local function BadName(n) return type(n) ~= "string" or n == "" or #n > 60 or n:find("[%c|;,:~]") ~= nil end
local function Whole(v, a, b) return type(v) == "number" and v % 1 == 0 and v >= a and v <= b end
local presetsBefore, selected
local function PresetsBefore()
    presetsBefore, selected = {}, W.db.raidGroups.selected
    for k in pairs(W.db.raidGroups.presets) do presetsBefore[k] = true end
end
local function PresetsAfter() -- what the import saved, checked, then removed
    local bad, db = {}, W.db.raidGroups
    for name, p in pairs(db.presets) do
        if not presetsBefore[name] then
            if type(name) ~= "string" or #name > 60 or name:find("[%c|]") then bad[#bad + 1] = "preset name " .. Lit(tostring(name)):sub(1, 60) end
            local players = type(p) == "table" and type(p.players) == "table" and p.players or {}
            if #players > 40 then bad[#bad + 1] = #players .. " players" end
            for _, x in ipairs(players) do
                if BadName(x.name) then bad[#bad + 1] = "player " .. Lit(tostring(x.name)):sub(1, 60) end
                if not Whole(x.group, 1, 8) then bad[#bad + 1] = "group " .. tostring(x.group) end
                if not Whole(x.icon, 0, 8) then bad[#bad + 1] = "mark " .. tostring(x.icon) end
                if x.class ~= nil and not tostring(x.class):find("^%u+$") then bad[#bad + 1] = "class " .. Lit(tostring(x.class)) end
            end
            db.presets[name] = nil
        end
    end
    db.selected = selected
    return bad
end
local srBefore
local function SoftResBefore()
    srBefore = {}
    for id, list in pairs(W.db.loot.sr) do
        local copy = {}
        for i, n in ipairs(list) do copy[i] = n end
        srBefore[id] = copy
    end
end
local function SoftResAfter() -- what the import saved, checked, then the list put back (the same table: the module keeps it)
    local bad, sr = {}, W.db.loot.sr
    for id, list in pairs(sr) do
        if not srBefore[id] and not Whole(id, 1, 9999999) then bad[#bad + 1] = "item id " .. tostring(id) end
        for _, n in ipairs(type(list) == "table" and list or {}) do
            if BadName(n) then bad[#bad + 1] = "name " .. Lit(tostring(n)):sub(1, 60) end
        end
    end
    for k in pairs(sr) do sr[k] = nil end
    for k, v in pairs(srBefore) do sr[k] = v end
    return bad
end
local HEADER = "WLRT1:"
local IMPORTERS = {
    { "profile", ProfileBox, saved = { "WarLegendRaidToolDB", "WarLegendRaidTool_PvPDB" }, cases = {
        { "junk", function(n) return HEADER .. string.rep("x", n) end, grow = true },
        { "huge", function(n) return HEADER .. "{smain~{sui~{" .. string.rep("sK~T", math.floor(n / 4)) .. "}}}" end, grow = true },
        { "past the size limit", function() return HEADER .. string.rep("{", 450000) end },
        { "deep nesting", function(n) return HEADER .. string.rep("{smain~", math.floor(n / 7)) end, grow = true },
        { "NaN / inf / 1e309", function() return HEADER .. "{smain~{sui~{sa~n1e309~sb~nnan~sc~ninf~sd~n-1e309~}}}" end },
        { "big numbers", function() return HEADER .. "{smain~{sui~{sscale~n0x7fffffff~sx~n1e12~sy~n-0~}spvp~{}}}" end },
        { "escape codes in names", function()
            return HEADER .. "{smain~{sinviteTool~{skeyword~s" .. CODES .. "~}s" .. CODES .. "~{s" .. CODES .. "~T}sinterfaceOptions~{scvars~{s"
                .. CODES .. "~s1~}}}spvp~{sLeftButtonValue~s/gquit^n" .. CODES .. "^n/cast X~}}"
        end },
        { "separators only", function(n) return HEADER .. string.rep("~^{}", math.floor(n / 4)) end, grow = true },
        { "one very long line", function(n) return HEADER .. "{smain~{sinviteTool~{skeyword~s" .. string.rep("a", n) .. "~}}}" end, grow = true },
        { "blanks", function(n) return HEADER .. "{smain~{sinviteTool~{skeyword~sa" .. string.rep(" ", n) .. "b~}}}" .. string.rep(" ", n) end, grow = true },
        { "valid export cut", ProfileExport, cuts = true },
    } },
    { "Myslot", MyslotBox, saved = { "WarLegendRaidToolDB" }, cases = {
        { "valid export cut", MyslotCrafted, cuts = true },
        { "junk", function(n) return string.rep("A", n) end, grow = true },
        { "past the size limit", function() return string.rep("A", 600000) end },
        { "NaN / inf / 1e309", function() return "nan inf 1e309 -1e309 0x7fffffff" end },
        { "escape codes in names", MyslotCrafted },
        { "separators only", function(n) return string.rep("@\n#\n", math.floor(n / 4)) end, grow = true },
        { "one very long line", function(n) return "# Myslot\n" .. string.rep("=", n) end, grow = true },
    } },
    { "Raid Groups preset", PopupBox("RaidGroups", "Import"), before = PresetsBefore, after = PresetsAfter, cases = {
        { "junk", function(n) return string.rep("x", n) end, grow = true },
        { "huge", function(n) return "P;" .. string.rep("Raider2,MAGE,1,0,0;", math.floor(n / 19)) end, grow = true },
        { "NaN / inf / 1e309", function() return "P;Raider2,MAGE,nan,nan,nan;Raider3,MAGE,inf,-inf,1e309;Raider4,MAGE,1e309,0x10,-0;Raider5,mage,-1,9,99" end },
        { "escape codes in names", function() return CODES .. ";" .. CODES .. ",MAGE,1,0,0;" .. BREAK .. ",PRIEST,2,1,1" end },
        { "separators only", function(n) return string.rep(";,", math.floor(n / 2)) end, grow = true },
        { "commas in one player", function(n) return "P;" .. string.rep(",", n) end, grow = true },
        { "one very long line", function(n) return "P;a" .. string.rep("b", n) .. ",MAGE,1,0,0" end, grow = true },
        { "blanks", function(n) return "P;a" .. string.rep(" ", n) .. "b,MAGE,1,0,0" end, grow = true },
        { "valid export cut", PresetExport, cuts = true },
    } },
    { "soft-res CSV", PopupBox("LootCouncil", "Import (softres.it CSV)"), before = SoftResBefore, after = SoftResAfter, cases = {
        { "junk", function(n) return string.rep("x", n) end, grow = true },
        { "huge", function(n) return "Name,ItemID\n" .. string.rep("Raider2,19019\n", math.floor(n / 14)) end, grow = true },
        { "NaN / inf / 1e309", function() return "Name,ItemID\nRaider2,nan\nRaider3,inf\nRaider4,1e309\nRaider5,-1\nRaider6,0x10\nRaider7,1.5\nRaider8,99999999999" end },
        { "escape codes in names", function() return "Name,ItemID\n" .. CODES .. ",19019\n" .. NBREAK .. ",19020" end },
        { "separators only", function(n) return string.rep(",", n) end, grow = true },
        { "quotes", function(n) return '"' .. string.rep('""', math.floor(n / 2)) .. '",19019' end, grow = true },
        { "one very long line", function(n) return "Name,ItemID\n" .. string.rep("a", n) .. ",19019" end, grow = true },
        { "blanks", function(n) return "Name,ItemID\na" .. string.rep(" ", n) .. "b,19019" end, grow = true },
        { "valid export cut", SoftResExport, cuts = true },
    } },
}
report.paste = {}
local SIZES = { 1024, 16384, 262144 }
-- a cut case: the export cut at 20 places, then whole (it must not be refused, else the cuts prove nothing)
local function Cuts(case)
    local ok, whole = pcall(case[2])
    if not ok or type(whole) ~= "string" or #whole < 21 then return nil, "valid export not built: " .. tostring(whole) end
    local texts = {}
    for i = 1, 20 do texts[i] = whole:sub(1, math.floor(#whole * i / 21)) end
    texts[21] = whole
    return texts
end
for _, imp in ipairs(IMPORTERS) do
    for _, case in ipairs(imp.cases) do
        local r = { importer = imp[1], case = case[1], size = 0, ms = 0 }
        report.paste[#report.paste + 1] = r
        local fails = {}
        local inputs, err = SIZES, nil
        M.phase = "paste " .. imp[1] .. ": " .. case[1]
        if case.cuts then inputs, err = Cuts(case) elseif not case.grow then inputs = { 0 } end
        if not inputs then r.fail, inputs = err, {} end
        for _, n in ipairs(inputs) do
            local ok, text = true, n
            if not case.cuts then ok, text = pcall(case[2], n) end
            if not ok or type(text) ~= "string" then r.fail = "case not built: " .. tostring(text); break end
            if Confirming() then WLRTConfirm:Hide() end
            local box, button = imp[2]()
            if not (box and button) then r.fail = "text box or import button not found"; break end
            local saved = imp.saved and Saved(imp.saved)
            if imp.before then imp.before() end
            local popups, sens, chats, e0 = M.popups or 0, #M.sensitive, #M.chat, Errs()
            box.__text = text -- pasted by the player: not a text the addon shows
            M.phase = "paste " .. imp[1] .. ": " .. case[1]
            local t0 = os.clock()
            local stuck = Watched(Click, button)
            local ms = (os.clock() - t0) * 1000
            r.size, r.ms = #text, ms
            local popup = rawget(_G, "WLRTTextPopup") -- left open with the reason when a preset / list is refused
            r.outcome = (Confirming() or (M.popups or 0) > popups) and "confirmation"
                or (imp.after and not (popup and popup:IsShown()) and "imported") or "refused"
            local why = {}
            if stuck then why[#why + 1] = "stopped by the watchdog (the import did not end)" end
            if Errs() > e0 then why[#why + 1] = "Lua error " .. tostring(M.lastError) end
            if ms >= 1000 then why[#why + 1] = string.format("%.0f ms", ms) end
            if #M.sensitive > sens then why[#why + 1] = "acted: " .. M.sensitive[#M.sensitive] end
            if #M.chat > chats then why[#why + 1] = "chat line sent" end
            if saved and Saved(imp.saved) ~= saved then why[#why + 1] = "saved data changed without an answer" end
            if imp.after then for _, b in ipairs(imp.after()) do why[#why + 1] = "saved " .. b end end
            if #why > 0 then fails[#fails + 1] = string.format("%d bytes: %s", #text, table.concat(why, "; ")) end
            if case.grow and ms > 40 then break end -- the next size could take minutes when this code grows faster than the text
        end
        if case.cuts and #inputs > 0 and r.outcome == "refused" then fails[#fails + 1] = "the whole export was refused: its cuts prove nothing" end
        if #fails > 0 and not r.fail then r.fail = table.concat(fails, " | ") end
    end
end
if Confirming() then WLRTConfirm:Hide() end
if rawget(_G, "WLRTTextPopup") then WLRTTextPopup:Hide() end
M.Advance(2)

-- security hardening (master audit of 29/10, P2: items 8 to 13); each check was seen failing with its fix removed. The
-- raid of 10, Raider4 its assistant (out of my guild first). What the phases before left is cleared first.
Phase("hardening")
M.group[4].assist = true
M.Fire("GROUP_ROSTER_UPDATE")
M.Advance(11)
local ASSIST, MATE, GUILDIE = "Raider4-Forever", "Raider3-Forever", "Guildie1-Forever"
local EU = C_EncodingUtil
local function Addon(prefix, msg, channel, from) M.Fire("CHAT_MSG_ADDON", prefix, msg, channel, from, from, 0, 0, "", 0) end
local function SentSince(from, prefix) -- what the addon sent on a prefix since M.addon[from]
    local out = {}
    for i = from + 1, #M.addon do if M.addon[i].prefix == prefix then out[#out + 1] = M.addon[i] end end
    return out
end
local function Printed(fn) -- what W.Print says while fn runs
    local lines, print0 = {}, W.Print
    W.Print = function(s, ...) lines[#lines + 1] = tostring(s); return print0(s, ...) end
    fn()
    W.Print = print0
    return lines
end
local function PromptText() return Confirming() and WLRTConfirm.text.__text or "" end
local function ClosePrompt() if Confirming() then WLRTConfirm:Hide() end M.Advance(1) end
ClosePrompt()

-- 8: who each prefix is taken from, as Dispatch decides it (what it tells the audit log: "ok" = the handler runs)
do
    local on, note, said = W.AuditOn, W.AuditNote, nil
    W.AuditOn = function() return true end
    W.AuditNote = function(kind) if kind ~= "time" then said = kind end end
    local function Says(prefix, channel, from) said = nil; Addon(prefix, "x", channel, from); return said end
    local KINDS = { WLRT_PROFILE = "guildchan", WLRT_LAYER = "guildchan", WLRT_MINO = "guildchan", WLRT_TRANSP = "guildchan",
        GuildMapEx1 = "guildchan", WLRT_PROF = "guild", WLRT_VERQ = "group", WLRT_INSQ = "group", WLRT_INSD = "group", WLRT_DUR = "group",
        WLRT_CD2 = "group", WLRT_RDYA = "group", WLRT_LC = "raid", WLRT_CON = "raid", WLRT_BUFF = "raid", WLRT_RG = "raid", WLRT_RDYQ = "raid" }
    local function All(v) return { guildchan = v, guild = v, group = v, raid = v } end
    local CASES = {
        { "GUILD", GUILDIE, { guildchan = "ok", guild = "ok", group = "untrusted", raid = "untrusted" } },
        { "OFFICER", GUILDIE, { guildchan = "ok", guild = "ok", group = "untrusted", raid = "untrusted" } },
        { "WHISPER", GUILDIE, { guildchan = "untrusted", guild = "ok", group = "untrusted", raid = "untrusted" } }, -- out of my group
        { "RAID", MATE, { guildchan = "untrusted", guild = "untrusted", group = "ok", raid = "ok" } }, -- out of my guild
        { "PARTY", MATE, { guildchan = "untrusted", guild = "untrusted", group = "ok", raid = "ok" } },
        { "WHISPER", MATE, { guildchan = "untrusted", guild = "untrusted", group = "ok", raid = "ok" } },
        { "INSTANCE_CHAT", MATE, All("bad-channel") },
        { "WHISPER", "Stranger-Other", All("stranger") },
    }
    local wrong = {}
    local function Want(prefix, channel, from, want)
        local got = Says(prefix, channel, from)
        if got ~= want then wrong[#wrong + 1] = string.format("%s on %s from %s: %s, not %s", prefix, channel, from, tostring(got), want) end
    end
    for prefix, kind in pairs(KINDS) do
        for _, c in ipairs(CASES) do Want(prefix, c[1], c[2], c[3][kind]) end
        M.Advance(1, 0.25) -- under the per-sender limit of Dispatch
    end
    Want("WLRT_VER", "GUILD", GUILDIE, "ok")
    Want("WLRT_VER", "RAID", MATE, "ok")
    -- in a battleground: the raid tools take nothing, what the group answers still passes
    local inst = M.instance
    M.instance = "pvp"
    for prefix, kind in pairs(KINDS) do
        if kind == "raid" then Want(prefix, "RAID", MATE, "untrusted") elseif kind == "group" then Want(prefix, "RAID", MATE, "ok") end
    end
    M.instance = inst
    W.AuditOn, W.AuditNote = on, note
    M.Advance(2)
    Check("who each addon prefix is taken from (TRUST of Core.lua)", #wrong == 0, #wrong .. " wrong: " .. table.concat(wrong, ", ", 1, math.min(#wrong, 6)))
end

-- 8: a raid prefix on the guild channel makes nobody answer in their group, on the raid channel it does
M.Advance(11) -- RaidInspect answers once per 10 s
local sent0 = #M.addon
Addon("WLRT_INSQ", "1", "GUILD", GUILDIE)
M.Advance(3)
local onGuild = #SentSince(sent0, "WLRT_INSD")
M.Advance(11)
sent0 = #M.addon
Addon("WLRT_INSQ", "1", "RAID", MATE)
M.Advance(3)
local onRaid = #SentSince(sent0, "WLRT_INSD")
Check("a raid inspect request on the guild channel gets no report, on the raid channel it does", onGuild == 0 and onRaid == 1,
    string.format("guild channel: %d, raid channel: %d", onGuild, onRaid))

-- 8: a long text from outside my guild on a guild prefix is not kept nor opened (it was, before Guild.lua dropped it)
do
    local inflate0, opened = W.Inflate, 0
    W.Inflate = function(...) opened = opened + 1; return inflate0(...) end
    local text = EU.EncodeBase64(EU.CompressString("D^^^"))
    Addon("WLRT_PROF", "z777:1:1:" .. text, "RAID", MATE)
    local byMate = opened
    Addon("WLRT_PROF", "z778:1:1:" .. text, "GUILD", GUILDIE)
    W.Inflate = inflate0
    Check("a long text on a guild prefix from outside the guild is not opened", byMate == 0 and opened == 1,
        string.format("from outside the guild: %d, from a guild mate: %d", byMate, opened - byMate))
end

-- 8: Raid Buffs: one popup per 10 s, the newest one waiting; nothing from INSTANCE_CHAT
do
    local function Shown() local p = rawget(_G, "WLRTBuffPopup"); return p and p.text.__text or "" end
    local function Buffs(text, channel) Addon("WLRT_BUFF", "A^Smoketest^" .. text, channel or "RAID", ASSIST) end
    M.Advance(11)
    local onInstance, first, during, after
    local lines = Printed(function()
        Buffs("hard one", "INSTANCE_CHAT")
        onInstance = Shown()
        Buffs("hard two")
        first = Shown()
        for i = 3, 7 do M.Advance(0.2); Buffs("hard " .. i) end
        during = Shown()
        M.Advance(10)
        after = Shown()
    end)
    local printed = 0
    for _, l in ipairs(lines) do if l:find("hard", 1, true) then printed = printed + 1 end end
    Check("Raid Buffs: one popup per 10 s, the newest after them, none from INSTANCE_CHAT", not onInstance:find("hard one", 1, true) and
        first:find("hard two", 1, true) ~= nil and during:find("hard two", 1, true) ~= nil and after:find("hard 7", 1, true) ~= nil and printed == 2,
        string.format("%d line(s) printed, shown at the end: %q", printed, after))
end

-- 8: both prompts from a lead name the sender in full and flag one out of my guild
do
    local tag = W.L("not in guild")
    Addon("WLRT_CON", "101:1:1:L^13444:5", "RAID", ASSIST)
    local list = PromptText()
    ClosePrompt()
    local preset = EU.EncodeBase64(EU.CompressString(W.RaidGroups.Serialize("Shared", { players = { { name = "Raider5", class = "MAGE", group = 1, icon = 0, ma = 0 } } })))
    Addon("WLRT_RG", "Z:12345:1:1:" .. preset, "RAID", ASSIST)
    local shared = PromptText()
    ClosePrompt()
    local function Names(text) return text:find("Raider4 Forever", 1, true) ~= nil and text:find(tag, 1, true) ~= nil end
    Check("a shared consumables list names its sender in full, flagged out of the guild", Names(list), list)
    Check("a shared preset names its sender in full, flagged out of the guild", Names(shared), shared)
end

-- 9: a stream of many empty deflate blocks is refused when read, before DecompressString; real ones have a few blocks
do
    local function Dynamic(n) -- n - 1 empty dynamic blocks (only the end-of-block symbol has a code), then a last empty one
        local bits = {}
        local function Put(v, count) for _ = 1, count do bits[#bits + 1] = v % 2; v = math.floor(v / 2) end end
        local LENGTH = { [18] = 1, [0] = 2, [1] = 2 } -- code lengths of the code lengths: "0", "10", "11"
        for _ = 1, n - 1 do
            Put(0, 1); Put(2, 2) -- not the last, dynamic
            Put(0, 5); Put(0, 5); Put(14, 4) -- 257 + 1 codes, 18 code lengths
            for _, s in ipairs({ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1 }) do Put(LENGTH[s] or 0, 3) end
            Put(0, 1); Put(127, 7) -- 138 zeros
            Put(0, 1); Put(107, 7) -- 118 zeros
            Put(1, 1); Put(1, 1) -- end of block: length 1
            Put(1, 1); Put(0, 1) -- no distance code: length 0
            Put(0, 1) -- the block's end of block
        end
        Put(1, 1); Put(1, 2); Put(0, 7) -- last, fixed codes, end of block
        local out = {}
        for i = 1, #bits, 8 do
            local b = 0
            for j = 7, 0, -1 do b = b * 2 + (bits[i + j] or 0) end
            out[#out + 1] = string.char(math.floor(b))
        end
        return table.concat(out)
    end
    local function Stored(n, size) -- n stored blocks of size bytes, what a real encoder writes for data it cannot shrink
        local out = {}
        for i = 1, n do
            out[i] = string.char(i == n and 1 or 0, size % 256, math.floor(size / 256), (65535 - size) % 256, math.floor((65535 - size) / 256)) .. string.rep("a", size)
        end
        return table.concat(out)
    end
    local atCap, past = W.InflatedSize(Dynamic(32), 65536), W.InflatedSize(Dynamic(33), 65536)
    local storedAtCap, storedPast = W.InflatedSize(Stored(32, 100), 65536), W.InflatedSize(Stored(33, 100), 65536)
    Check("deflate: 32 blocks are read, 33 are refused (dynamic and stored)", atCap == 0 and past == nil and storedAtCap == 3200 and storedPast == nil,
        string.format("dynamic %s / %s, stored %s / %s", tostring(atCap), tostring(past), tostring(storedAtCap), tostring(storedPast)))
    local forged = EU.EncodeBase64(Dynamic(700))
    local decompress0, opened = EU.DecompressString, 0
    EU.DecompressString = function(...) opened = opened + 1; return decompress0(...) end
    local n = math.ceil(#forged / 220)
    M.Advance(6)
    for i = 1, n do
        Addon("WLRT_PROF", string.format("z779:%d:%d:%s", i, n, forged:sub((i - 1) * 220 + 1, i * 220)), "GUILD", GUILDIE)
        if i % 30 == 0 then M.Advance(5.5, 0.5) end -- the per-sender limit of Dispatch
    end
    EU.DecompressString = decompress0
    Check("deflate: a forged guild message of 700 empty blocks is never opened", n <= 64 and opened == 0, string.format("%d chunks, opened %d time(s)", n, opened))
end

-- 10, 12: Skyborne (its characters only): strangers' text in debug mode, the shared channel only, 2,000 entries in all
if opts.race == "Skyborne" then
    local sky = rawget(_G, "WarLegendRaidTool_SkyborneDB")
    if not (sky and sky.crowdReports and sky.crowdReports.A) then
        Check("Skyborne started on a Skyborne character", false, "no saved reports: its checks did not run")
    else
        local mapKeys, mapSaved = { "GetMapInfo", "GetWorldPosFromMapPos", "GetBestMapForUnit" }, {}
        for _, k in ipairs(mapKeys) do mapSaved[k] = rawget(C_Map, k) end
        C_Map.GetMapInfo = function(id) return { mapID = id, mapType = Enum.UIMapType.Zone } end
        C_Map.GetWorldPosFromMapPos = function(_, pos) return 0, CreateVector2D(pos.x * 2000, pos.y * 2000) end
        C_Map.GetBestMapForUnit = function() return 1411 end
        local inst = M.instance
        M.instance = nil
        M.Fire("PLAYER_ENTERING_WORLD", false, false)
        M.Advance(1)
        local function Sky(text, channel, from) M.Fire("CHAT_MSG_ADDON", "SLLCM", text, channel or "CHANNEL", from, from, 0, 0, "", 0) end
        local function Count(all) local n = 0; for _, list in pairs(all) do n = n + #list end return n end
        local reports, gone = sky.crowdReports.A, sky.crowdGone.A
        local function Sighting(phase, map, kind) return string.format("%s:1:A:%d:%d:5000:5000:%d", kind or "R", phase, map, GetServerTime()) end
        for k in pairs(reports) do reports[k] = nil end
        for k in pairs(gone) do gone[k] = nil end
        -- 10: debug mode (its setting is saved): the text of a stranger reaches the chat with its escape codes dead
        M.Call(W.slash.sk, "share debug")
        local lines = Printed(function()
            Sky("R:1:A:77:" .. CODES, "CHANNEL", "Skyd-Forever")
            Sky("R:1:A:77:x", "WHISPER", "Skyd-Forever")
        end)
        M.Call(W.slash.sk, "share debug")
        local reached, live, refused = 0, 0, 0
        for _, l in ipairs(lines) do
            if l:find(MARK, 1, true) then reached = reached + 1 end
            if M.LiveCode(l, true) then live = live + 1 end
            if l:find("not on the channel: WHISPER", 1, true) then refused = refused + 1 end
        end
        Check("Skyborne debug mode shows a stranger's text with its escape codes dead, and says what came off the channel",
            reached >= 1 and live == 0 and refused == 1, string.format("%d line(s) with the text, %d with a live code, %d about the whisper", reached, live, refused))
        -- 12: heard on the shared channel only
        local wrongChannel = 0
        for _, c in ipairs({ "WHISPER", "GUILD", "OFFICER", "RAID", "PARTY", "INSTANCE_CHAT" }) do
            Sky(Sighting(100, 5000), c, "Skyc-Forever")
            wrongChannel = wrongChannel + Count(reports)
        end
        Sky(Sighting(100, 5000), "CHANNEL", "Skyc-Forever")
        Check("Skyborne takes a sighting on its channel only", wrongChannel == 0 and Count(reports) == 1,
            string.format("%d kept on other channels, %d on the channel", wrongChannel, Count(reports)))
        for k in pairs(reports) do reports[k] = nil end
        -- 12: 12 maps x 200 made-up phases, from 120 senders (20 messages in 10 s each): 2,000 kept in all
        local sent = 0
        for m = 1, 12 do
            for i = 1, 200 do
                Sky(Sighting(1000000 + m * 1000 + i, 5000 + m), "CHANNEL", string.format("Sky%d-Forever", math.floor(sent / 20)))
                sent = sent + 1
            end
        end
        local kept = Count(reports)
        for i = 1, 5 do Sky(Sighting(1000000 + i, 5001, "XM"), "CHANNEL", "Skyg-Forever") end
        local goneKept = Count(gone)
        -- what is in the zone and phase I am in still gets in, another phase there does not (two kinds of NPC: a new phase)
        M.units.nameplate1, M.units.nameplate2 = { guid = "Creature-0-1-1-7777-1234-1" }, { guid = "Creature-0-1-1-7777-1235-1" }
        M.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
        M.Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
        M.units.nameplate1, M.units.nameplate2 = nil, nil
        Sky(Sighting(7777, 1411), "CHANNEL", "Skym-Forever")
        Sky(Sighting(8888, 1411), "CHANNEL", "Skym-Forever")
        Sky(string.format("XM:1:A:7777:1411:1000:1000:%d", GetServerTime()), "CHANNEL", "Skym-Forever")
        Sky(string.format("XM:1:A:8888:1411:1000:1000:%d", GetServerTime()), "CHANNEL", "Skym-Forever")
        local here, goneHere = reports[1411] or {}, gone[1411] or {}
        Check("Skyborne keeps 2,000 entries in all, those of my zone and phase past it", kept == 2000 and goneKept == 0 and #here == 1 and here[1].phase == "7777"
            and #goneHere == 1 and goneHere[1].phase == "7777",
            string.format("%d sightings kept of %d, %d \"not there\", in my zone %d and %d", kept, sent, goneKept, #here, #goneHere))
        -- at the cap what has expired goes first (a map nobody reports on any more), then a new entry gets in (on a map
        -- with room: the 2,000 filled the first ten maps)
        for _, e in ipairs(reports[5001] or {}) do e.t = e.t - 6000 end
        M.Advance(61, 1)
        Sky(Sighting(9999, 5011), "CHANNEL", "Skym-Forever")
        local pruned, newest = #(reports[5001] or {}), false
        for _, e in ipairs(reports[5011] or {}) do if e.phase == "9999" then newest = true end end
        for k in pairs(reports) do reports[k] = nil end
        for k in pairs(gone) do gone[k] = nil end
        Check("Skyborne at its cap drops what has expired first", pruned == 0 and newest, string.format("%d expired left on the map, new entry kept: %s", pruned, tostring(newest)))
        M.Call(W.slash.sk, "share forget")
        for _, k in ipairs(mapKeys) do C_Map[k] = mapSaved[k] end
        M.instance = inst
        M.Fire("PLAYER_ENTERING_WORLD", false, false)
        M.Advance(1)
    end
end

-- 11: Checklist: a raid check is answered to a lead of my guild only, whispered to them, up to 100 of an item
do
    M.Advance(11)
    local itemCount0 = W.ItemCount
    W.ItemCount = function() return 250 end
    local before = #M.addon
    Addon("WLRT_CON", "102:1:1:Q^13444:5,13446:500", "RAID", ASSIST)
    M.Advance(3)
    local outOfGuild = #SentSince(before, "WLRT_CON")
    M.guild[#M.guild + 1] = { name = ASSIST, class = "ROGUE", online = true, rank = 1, level = 60 }
    M.Fire("GUILD_ROSTER_UPDATE", false)
    before = #M.addon
    Addon("WLRT_CON", "103:1:1:Q^13444:5,13446:500", "RAID", ASSIST)
    M.Advance(3)
    local sent = SentSince(before, "WLRT_CON")
    local a = sent[1] or {}
    Check("Checklist answers a lead of my guild only, whispered, up to 100 of an item", outOfGuild == 0 and #sent == 1 and a.channel == "WHISPER" and a.target == "Raider4 Forever"
        and tostring(a.msg):find("A^13444:5,13446:100", 1, true) ~= nil,
        string.format("out of the guild: %d answer(s); in it: %d, %s to %s: %s", outOfGuild, #sent, tostring(a.channel), tostring(a.target), tostring(a.msg)))
    -- my own check: my answer comes back to me directly, nothing whispered; a raider's whispered answer is read
    local cl = W.db.checklist
    local items0 = cl.items
    cl.items = { { 13444, 5 } }
    M.Advance(11)
    before = #M.addon
    Click(ButtonIn(Panel("Checklist"), W.L("Raid check")))
    M.Advance(1)
    local asked = SentSince(before, "WLRT_CON")[1]
    before = #M.addon
    if asked then Addon("WLRT_CON", asked.msg, "RAID", "Smoketest-Forever") end
    M.Advance(3)
    local out = SentSince(before, "WLRT_CON")
    local mine = cl.raid[W.UnitKey("player")]
    Addon("WLRT_CON", "104:1:1:A^13444:3", "WHISPER", MATE)
    local mate = cl.raid[W.UnitKey(W.UnitByName(MATE))]
    Check("Checklist: my own check reads my answer without a whisper, and a raider's whispered one", asked ~= nil and #out == 0
        and mine ~= nil and mine.counts[13444] == 5 and mate ~= nil and mate.counts[13444] == 3,
        string.format("asked: %s, sent after it: %d, my row: %s, the raider's: %s", tostring(asked ~= nil), #out, tostring(mine ~= nil), tostring(mate ~= nil)))
    cl.items = items0
    wipe(cl.raid)
    W.ItemCount = itemCount0
end

-- 11: Readiness: one line answered per item per check (eight thresholds told how many I carry), as for gold
do
    M.Advance(6)
    local before = #M.addon
    Addon("WLRT_RDYQ", "105:1:1:654321~2item 13444 1~2item 13444 2~2item 13444 3~2item 13446 1~2gold 1~2gold 2", "RAID", ASSIST)
    M.Advance(4)
    local a = SentSince(before, "WLRT_RDYA")[1] or {}
    local shape = {}
    for s in (tostring(a.msg):match("^654321#(.*)$") or ""):gmatch("([01%?]),") do shape[#shape + 1] = s == "?" and "?" or "x" end
    shape = table.concat(shape)
    Check("Readiness answers one line per item and gold per check", shape == "x??xx?", shape .. " (" .. tostring(a.channel) .. ")")
end

-- 11: Loot Council: the vote window is for the council and the master looter; 8: no loot message from INSTANCE_CHAT
do
    local LC = W.LootCouncil
    local left = LC.Session()
    if left then left.test, left.started = true, -1e9 end -- what the hostile messages left open can be replaced
    local function VoteShown() local f = rawget(_G, "WLRTVoteFrame"); return f ~= nil and f:IsShown() end
    if VoteShown() then WLRTVoteFrame:Hide() end
    local function Loot(...) Addon("WLRT_LC", W.Pack(...), "RAID", ASSIST) end
    local ITEM_STR = "item:19019::::::::60:::::"
    -- behind Dispatch, which refuses that channel already
    M.Call(W.AddonHandler("WLRT_LC"), W.Pack("S", "77770", 1, 60, ""), "Raider4", "INSTANCE_CHAT", "Raider4 Forever")
    local s = LC.Session()
    Check("Loot Council takes no session from INSTANCE_CHAT", not (s and s.sid == "77770"))
    Loot("S", "77771", 1, 60, "")
    Loot("I", "77771", 1, ITEM_STR)
    Loot("C", "77771", ASSIST)
    M.Advance(1)
    local opened = VoteShown()
    local said = Printed(function() M.Call(W.slash.loot, "vote") end)
    local refused = not VoteShown() and tContains(said, W.L("The voting window is for the loot council."))
    -- the game's master looter (an assistant started this session): the window opens without being in the council
    local lootMethod0 = rawget(C_PartyInfo, "GetLootMethod")
    C_PartyInfo.GetLootMethod = function() return "master", 0, 1 end -- raid1: me
    M.Call(W.slash.loot, "vote")
    local asML = VoteShown()
    if VoteShown() then WLRTVoteFrame:Hide() end
    C_PartyInfo.GetLootMethod = lootMethod0
    Loot("C", "77771", "Smoketest-Forever")
    M.Advance(1)
    local asCouncil = VoteShown()
    Check("the vote window opens for the council and the master looter only", not opened and refused and asML and asCouncil,
        string.format("out of the council: opened %s, refused %s; as master looter: %s; in the council: %s", tostring(opened), tostring(refused), tostring(asML), tostring(asCouncil)))
    -- a new session whose council I am not in closes it
    Loot("S", "77772", 1, 60, "")
    Loot("I", "77772", 1, ITEM_STR)
    Loot("C", "77772", ASSIST)
    Addon("WLRT_LC", W.Pack("R", "77772", 1, "pass", "", "", 100), "RAID", MATE)
    M.Advance(1)
    Check("the vote window closes in a session whose council I am not in", not VoteShown())
    Loot("E", "77772")
    M.Advance(1)
end

-- 12: the limits per sender forget only what is over: 201 senders in a row must not reset them
do
    local function Invites(name, from)
        local n = 0
        for i = from + 1, #M.sensitive do if M.sensitive[i]:find("InviteUnit " .. name, 1, true) then n = n + 1 end end
        return n
    end
    M.Advance(31, 1)
    ClickCheck("Invite on keyword whisper", true)
    local before = #M.sensitive
    FireChat("CHAT_MSG_WHISPER", "inv", "Caller0-Other")
    for i = 1, 205 do FireChat("CHAT_MSG_WHISPER", "inv", "Caller" .. i .. "-Other") end
    FireChat("CHAT_MSG_WHISPER", "inv", "Caller0-Other")
    local again, all = Invites("Caller0-Other", before), Invites("Caller", before)
    M.Advance(31, 1)
    FireChat("CHAT_MSG_WHISPER", "inv", "Caller0-Other")
    FireChat("CHAT_MSG_WHISPER", "inv", "Caller999-Other")
    local later, newcomer = Invites("Caller0-Other", before), Invites("Caller999-Other", before)
    ClickCheck("Invite on keyword whisper", false)
    Check("InviteTool: 201 senders do not reset the 30 s per sender, 200 at most, the ones past it are forgotten", again == 1 and all == 200 and later == 2 and newcomer == 1,
        string.format("invited %d time(s) within 30 s, %d senders in all, %d after them, newcomer %d", again, all, later, newcomer))

    local function Answers(name, from)
        local n = 0
        for i = from + 1, #M.chat do if M.chat[i].target == name then n = n + 1 end end
        return n
    end
    local srLabel = "Accept \"!sr [item]\" whispers"
    M.SetGuild(500)
    M.Fire("GUILD_ROSTER_UPDATE", false)
    M.Advance(11, 1)
    ClickCheck(srLabel, true)
    local chat0 = #M.chat
    for _ = 1, 4 do FireChat("CHAT_MSG_WHISPER", "!sr", GUILDIE) end
    for i = 2, 206 do FireChat("CHAT_MSG_WHISPER", "!sr", "Guildie" .. i .. "-Forever") end
    FireChat("CHAT_MSG_WHISPER", "!sr", GUILDIE)
    local stays, lines = Answers(GUILDIE, chat0), #M.chat - chat0
    M.Advance(11, 1)
    FireChat("CHAT_MSG_WHISPER", "!sr", GUILDIE)
    local afterWindow = Answers(GUILDIE, chat0)
    ClickCheck(srLabel, false)
    M.SetGuild(30)
    M.Fire("GUILD_ROSTER_UPDATE", false)
    -- 3 to the first sender, 1 to each of the 199 others the 200 windows hold
    Check("!sr: 201 senders do not reset the 3 answers per 10 s, 200 windows at most, a window that ended does", stays == 3 and lines == 202 and afterWindow == 4,
        string.format("%d answer(s) within 10 s, %d lines in all, %d after them", stays, lines, afterWindow))
end

-- 13: the Yes of a prompt from another player answers 0.5 s after it shows: the second click of a double click on my own
-- Yes, or a click when one comes up with nothing open, accepts nothing unread; my own questions answer at once
do
    M.Advance(2)
    local theirs, mine = 0, 0
    W.Confirm("my own question", function() end)
    W.ConfirmRemote("a shared list", function() theirs = theirs + 1 end)
    local held = PromptText() == "my own question"
    Click(WLRTConfirm.yes)
    M.Advance(0.1)
    local shown = PromptText() == "a shared list"
    Click(WLRTConfirm.yes) -- the double click's second one
    local byDouble, stayed = theirs, Confirming()
    M.Advance(0.6)
    Click(WLRTConfirm.yes)
    local byHand = theirs
    M.Advance(1)
    W.ConfirmRemote("another list", function() theirs = theirs + 1 end)
    Click(WLRTConfirm.yes)
    local byChance = theirs - byHand
    WLRTConfirm:Hide()
    W.Confirm("my next question", function() mine = mine + 1 end) -- right after it: the wait is not carried over
    Click(WLRTConfirm.yes)
    ClosePrompt()
    Check("the Yes of a prompt from another player answers after 0.5 s, mine at once", held and shown and stayed and byDouble == 0 and byHand == 1 and byChance == 0 and mine == 1,
        string.format("kept waiting: %s, shown: %s; by a double click: %d, left open: %s; by hand: %d; by a click as it came: %d; mine: %d",
        tostring(held), tostring(shown), byDouble, tostring(stayed), byHand, byChance, mine))
end
M.group[4].assist = nil
M.Fire("GROUP_ROSTER_UPDATE")
M.Advance(1)

-- what reached the screen from the hostile pieces (tools/smoke/wow.lua M.Shown): the check ends before the floods
M.mark = nil
report.escapes = M.escapes
report.reached = {}
for at, n in pairs(M.reached) do report.reached[#report.reached + 1] = { at, n } end
table.sort(report.reached, function(a, b) return a[1] < b[1] end)

-- Myslot's text format (tools/smoke/myslot.lua): the same bytes as Myslot 6.2.1's exports, the import in the click only
Phase("Myslot format")
do
    local chunk, err = load(SMOKE_READ(M.smokeDir .. "/myslot.lua"), "@tools/smoke/myslot.lua")
    local ok
    if chunk then ok, err = pcall(chunk, M, Check) end
    if not ok then M.Error(err) end
end

-- cost: event floods in a raid, out of combat, window closed (fengari is slower than the game: compare, do not read as ms in game)
Phase("perf")
M.Call(W.Hide) -- the commands may have left the window open: measured closed
M.costs = {}
local function Flood(label, n, fn)
    local t0 = os.clock()
    for i = 1, n do fn(i) end
    local dt = (os.clock() - t0) * 1000
    report.perf[#report.perf + 1] = { label = label, n = n, ms = dt }
end
Flood("UNIT_AURA x2000", 2000, function(i) M.Fire("UNIT_AURA", "raid" .. ((i % 10) + 1), { isFullUpdate = false }) end)
Flood("UNIT_HEALTH x2000", 2000, function(i) M.Fire("UNIT_HEALTH", "raid" .. ((i % 10) + 1)) end)
Flood("GROUP_ROSTER_UPDATE x200", 200, function() M.Fire("GROUP_ROSTER_UPDATE") end)
Flood("GUILD_ROSTER_UPDATE x200", 200, function() M.Fire("GUILD_ROSTER_UPDATE", false) end)
M.SetGuild(500)
Flood("GUILD_ROSTER_UPDATE x200 (500 members)", 200, function() M.Fire("GUILD_ROSTER_UPDATE", false) end)
M.SetGuild(30)
Flood("COMBAT_LOG x2000", 2000, function() M.Fire("COMBAT_LOG_EVENT_UNFILTERED") end)
Flood("CHAT_MSG_GUILD x500", 500, function(i) M.Fire("CHAT_MSG_GUILD", "hello " .. i, "Guildie1-Forever") end)
Flood("BAG_UPDATE x500", 500, function(i) M.Fire("BAG_UPDATE", i % 5) end)
Flood("UPDATE_MOUSEOVER_UNIT x500", 500, function() M.Fire("UPDATE_MOUSEOVER_UNIT") end)
Flood("NAME_PLATE_UNIT_ADDED x500", 500, function(i) M.Fire("NAME_PLATE_UNIT_ADDED", "nameplate" .. (i % 40 + 1)) end)
-- idle: OnUpdate scripts still running every frame with every window closed, out of combat
M.updates = 0
local idle = {}
for _, f in ipairs(M.frames) do if f.__scripts.OnUpdate and f:IsVisible() then idle[#idle + 1] = (f:GetName() or f.__type) .. " (" .. (f.__where or "?") .. ")" end end
local t0 = os.clock()
M.Advance(10)
report.idle = { frames = idle, updatesPerSecond = M.updates / 10, ms = (os.clock() - t0) * 1000, timers = M.PendingTimers() }
report.busiest = W.BusiestWork and W.BusiestWork(12) or {}
local costs = {}
for k, ms in pairs(M.costs) do costs[#costs + 1] = { k, ms } end
table.sort(costs, function(a, b) return a[2] > b[2] end)
report.frameCosts = { table.unpack(costs, 1, math.min(#costs, 10)) }
M.costs = nil

-- /wl verify, the Dev addon (tools/smoke/verify.lua). Last: its session watch stays on once loaded
Phase("Dev verify")
do
    local chunk, err = load(SMOKE_READ(M.smokeDir .. "/verify.lua"), "@tools/smoke/verify.lua")
    local ok
    if chunk then ok, err = pcall(chunk, M, Check) end
    if not ok then M.Error(err) end
end

-- leave: the game writes the saved variables
Phase("logout")
M.group = {}
M.instance = nil
M.Fire("GROUP_ROSTER_UPDATE")
M.Advance(2)
M.Fire("PLAYER_LOGOUT")
return report
