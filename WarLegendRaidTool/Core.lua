-- WarLegend RaidTool - Core
-- Shared base: events, database, group/guild helpers,
-- UI widgets (no custom images) and the tabbed main window.
local ADDON = ...
WLRT = WLRT or {}
local W = WLRT
local L = W.L

local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
W.ADDON = ADDON
W.version = (meta and meta(ADDON, "Version")) or "?"
W.R, W.G, W.B = 0.808, 0.098, 0.094 -- warlegend.net red (#CE1918)
W.TAG = "|cffce1918[WaR LegenD]|r " -- text only: also used in whispers, which cannot carry textures
-- War Legend skull logo (Media/Logo.tga 256 px, Media/Logo64.tga for small icons)
W.LOGO_TEX = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Logo"
W.LOGO_SMALL = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Logo64"
W.WHITE = "Interface\\Buttons\\WHITE8X8"
W.LOGO = "|cffffffffWaR|r |cffce1918LegenD|r"
W.FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
W.ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"
W.ICON_NAMES = { L("Star"), L("Circle"), L("Diamond"), "Triangle", L("Moon"), L("Square"), L("Cross"), L("Skull") }
W.BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"

-- A font string given a font file with SetFont shows squares for letters that file lacks (Cyrillic names
-- on a French client...). Blizzard's own fonts are font families: one file per alphabet. W.SetFont makes
-- the same (CreateFontFamily, one per file / size / flags) with Blizzard's Cyrillic, Korean and Chinese
-- files as the other members; plain SetFont when the client has no CreateFontFamily.
local FONT_ALPHABETS = {
    { "russian", "Fonts\\FRIZQT___CYR.TTF" },
    { "korean", "Fonts\\2002.TTF" },
    { "simplifiedchinese", "Fonts\\ARKai_T.ttf" },
    { "traditionalchinese", "Fonts\\blei00d.TTF" },
}
local fontFamilies, fontFamilyCount = {}, 0
function W.SetFont(fs, path, size, flags)
    flags = flags or ""
    if CreateFontFamily then
        local key = path .. "|" .. size .. "|" .. flags
        local family = fontFamilies[key]
        if family == nil then
            fontFamilyCount = fontFamilyCount + 1
            local members = { { alphabet = "roman", file = path, height = size, flags = flags } }
            for _, a in ipairs(FONT_ALPHABETS) do
                members[#members + 1] = { alphabet = a[1], file = a[2], height = size, flags = flags }
            end
            local ok, f = pcall(CreateFontFamily, "WLRTFontFamily" .. fontFamilyCount, members)
            family = ok and f or false
            fontFamilies[key] = family
        end
        if family then
            fs:SetFontObject(family)
            return
        end
    end
    fs:SetFont(path, size, flags)
end

function W.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|T" .. W.LOGO_SMALL .. ":14:14|t " .. W.TAG .. tostring(msg))
end

---------------------------------------------------------------------------
-- Cost of our own work (/wl perf): every event handler, timer, roster and ready function is timed
-- (debugprofilestop, microseconds) and the slowest are listed with the file and line that made them.
---------------------------------------------------------------------------
local clock = debugprofilestop
local costs = {} -- [label] = { max, count, total }
function W.Where(level)
    local s = debugstack and debugstack((level or 2) + 1, 1, 0) or ""
    local file, line = s:match("([%w_]+%.lua)%D+(%d+)")
    return file and (file .. ":" .. line) or "?"
end

function W.Measure(label, fn, ...)
    if not clock then return pcall(fn, ...) end
    local t0 = clock()
    local ok, err = pcall(fn, ...)
    local dt = clock() - t0
    local c = costs[label]
    if not c then c = { max = 0, count = 0, total = 0 }; costs[label] = c end
    c.count, c.total = c.count + 1, c.total + dt
    if dt > c.max then c.max = dt end
    return ok, err
end

-- the n slowest (one run), { label, max ms, count, total ms }
function W.SlowestWork(n)
    local list = {}
    for label, c in pairs(costs) do list[#list + 1] = { label, c.max, c.count, c.total } end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    while #list > (n or 5) do table.remove(list) end
    return list
end

-- the n busiest (most time in all since the login), same entries: what costs frames, even in small runs
function W.BusiestWork(n)
    local list = {}
    for label, c in pairs(costs) do list[#list + 1] = { label, c.max, c.count, c.total } end
    table.sort(list, function(a, b) return a[4] > b[4] end)
    while #list > (n or 5) do table.remove(list) end
    return list
end

-- A function wrapped for /wl perf: hooks on Blizzard code (hooksecurefunc, HookScript, tooltip callbacks)
-- and other scripts that can run often are timed like the event handlers. Return values are dropped
-- (the game ignores a hook's anyway); an error goes to the error handler, as for an event.
function W.Timed(label, fn)
    label = label .. " " .. W.Where(2)
    return function(...)
        local ok, err = W.Measure(label, fn, ...)
        if not ok then geterrorhandler()(err) end
    end
end

function W.After(delay, fn)
    if not (C_Timer and C_Timer.After) then return end
    local where = W.Where(2)
    C_Timer.After(delay, function()
        local ok, err = W.Measure("timer " .. where, fn)
        if not ok then geterrorhandler()(err) end
    end)
end

---------------------------------------------------------------------------
-- Events (a single frame for the whole addon)
---------------------------------------------------------------------------
local evFrame = CreateFrame("Frame")
local handlers, registered = {}, {}
-- while the raid addon loads: what its files register, to replay the login / roster events they missed
local late

-- Modules switched off (W.db.ui.off[key], Settings > Modules): the handlers, roster functions, addon
-- messages and tests of their file are skipped, and an event only they want is unregistered.
local offFiles = {}
local function FileOf(where) return where and where:match("^([%w_]+%.lua)") end

-- An event is registered only while at least one of its handlers is active: a frequent event
-- (target change, item info, loot...) costs nothing while no option or window needs it.
local function Sync(event)
    local want = false
    for _, h in ipairs(handlers[event]) do
        if h.active and not offFiles[h.file] then want = true; break end
    end
    if want == (registered[event] or false) then return end
    registered[event] = want
    if want then
        pcall(evFrame.RegisterEvent, evFrame, event) -- some events do not exist on every client
    else
        evFrame:UnregisterEvent(event)
    end
end

-- always = true: runs even when the player is not allowed to use the addon (core only).
-- inactive = true: starts switched off (W.Activate turns it on). Returns the handler.
function W.On(event, fn, always, inactive)
    handlers[event] = handlers[event] or {}
    local where = W.Where(2)
    local h = { fn = fn, always = always, active = not inactive, event = event, label = event .. " " .. where, file = FileOf(where) }
    local list = handlers[event]
    list[#list + 1] = h
    if late then late.handlers[#late.handlers + 1] = h end
    Sync(event)
    return h
end

function W.Activate(h, on)
    on = on and true or false
    if not h or h.active == on then return end
    h.active = on
    Sync(h.event)
end

local function Run(event, gatedOnly, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        local h = list[i]
        if h.active and not offFiles[h.file] and ((W.access == true and (not gatedOnly or not h.always)) or (h.always and not gatedOnly)) then
            local ok, err = W.Measure(h.label, h.fn, ...)
            if not ok then geterrorhandler()(err) end
        end
    end
end

local function SyncAll()
    for event in pairs(handlers) do Sync(event) end
end

-- One "roster settled" signal shared by the modules: a raid forming fires dozens of
-- GROUP_ROSTER_UPDATE in a row, the modules run once, half a second after the first one.
local rosterFns, rosterLabels, rosterFiles, rosterPending = {}, {}, {}, false
function W.OnRoster(fn)
    rosterFns[#rosterFns + 1] = fn
    local where = W.Where(2)
    rosterLabels[fn] = "roster " .. where
    rosterFiles[fn] = FileOf(where)
    if late then late.roster[#late.roster + 1] = fn end
end

local function RosterSettled()
    rosterPending = false
    if W.access ~= true then return end
    for _, fn in ipairs(rosterFns) do
        if not offFiles[rosterFiles[fn]] then
            local ok, err = W.Measure(rosterLabels[fn] or "roster", fn)
            if not ok then geterrorhandler()(err) end
        end
    end
end

-- Login events seen while the guild is still unknown: replayed once access is granted
local buffered = {}
evFrame:SetScript("OnEvent", function(_, event, ...)
    if W.access == nil and (event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD") then
        buffered[#buffered + 1] = { event, ... }
    end
    Run(event, false, ...)
end)

local function RosterChanged()
    if rosterPending then return end
    rosterPending = true
    W.After(0.5, RosterSettled)
end
W.On("GROUP_ROSTER_UPDATE", RosterChanged)
W.On("RAID_ROSTER_UPDATE", RosterChanged) -- older clients

---------------------------------------------------------------------------
-- Access: the addon only works for members of the War Legend guild
---------------------------------------------------------------------------
W.GUILD_NAME = "War Legend"
-- true: only members of GUILD_NAME can use the addon. Set to false to let everybody use it;
-- nothing else changes.
W.GUILD_RESTRICTED = false
W.access = (not W.GUILD_RESTRICTED) and true or nil -- nil = not known yet, true / false
local function Norm(s) return ((s or ""):lower():gsub("[%s%-_'%.]", "")) end
local accessChecks = 0

function W.Allowed() return W.access == true end

function W.Denied()
    if W.access == nil then
        W.Print(L("Checking your guild..."))
    else
        W.Print(string.format(L("This addon is reserved for members of the %s guild."), W.GUILD_NAME))
    end
end

local function SetAccess(v)
    if W.access == v then return end
    local was = W.access
    W.access = v
    if v then
        -- replay what the modules missed while we were waiting for the guild name
        local list = buffered
        buffered = {}
        -- access refused first, granted later (slow guild data, joined the guild): for the modules it is
        -- their login, so isLogin = true (cooldown text, alts, roster, version broadcast run once)
        if #list == 0 and was == false then list = { { "PLAYER_LOGIN" }, { "PLAYER_ENTERING_WORLD", true, false } } end
        for _, e in ipairs(list) do Run(e[1], true, unpack(e, 2)) end
    else
        buffered = {}
        if W.Hide then W.Hide() end
        W.Denied()
    end
end

function W.CheckAccess()
    if not W.GUILD_RESTRICTED then SetAccess(true); return end
    if not (IsInGuild and IsInGuild()) then
        -- right after login the guild may not be known yet
        if accessChecks < 10 and W.access == nil then return end
        SetAccess(false); return
    end
    local name = GetGuildInfo and GetGuildInfo("player")
    if not name then return end
    SetAccess(Norm(name) == Norm(W.GUILD_NAME))
end

local function Poll()
    accessChecks = accessChecks + 1
    W.CheckAccess()
    if W.access == nil then
        if accessChecks >= 15 then SetAccess(false) else W.After(2, Poll) end
    end
end
W.On("PLAYER_LOGIN", function() W.After(1, Poll) end, true)
W.On("PLAYER_GUILD_UPDATE", function() W.CheckAccess() end, true)
W.On("GUILD_ROSTER_UPDATE", function() W.CheckAccess() end, true)

-- Addon messages: one handler per prefix
local addonHandlers, addonFiles = {}, {}
function W.RegisterPrefix(prefix)
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(prefix)
    elseif RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(prefix)
    end
end

-- level: the stack level of the module that asks (a helper of Lib.lua passes 3)
function W.OnAddon(prefix, fn, level)
    W.RegisterPrefix(prefix)
    addonHandlers[prefix] = fn
    addonFiles[prefix] = FileOf(W.Where(level or 2))
end

function W.AddonHandler(prefix) return addonHandlers[prefix] end

-- Addon messages are taken from my group and my guild only. Anyone on the realm can whisper an
-- addon message (and any addon can reuse our prefixes): a whisper must come from a group or guild
-- member. Handlers get (msg, short name for display / state, channel, full "Name-Realm" name).
-- The full name is the one to trust: two players can share a short name on different realms.
local GROUP_CHANNELS = { RAID = true, PARTY = true, INSTANCE_CHAT = true, GUILD = true, OFFICER = true }

---------------------------------------------------------------------------
-- Load-on-demand raid modules (the way BigWigs loads its zone modules)
-- The raid tools (groups, loot council, buffs, ready check, checklist, inspect, aura tracking, raid
-- cooldowns, readiness, who pulled) live in the addon WarLegendRaidTool_Raid, which the game loads only
-- when it is needed: in a group, in a dungeon / raid, with Aura Tracking switched on, when /wl is
-- opened, or when one of their addon messages arrives. Alone in the open world (or alone in a
-- battleground), none of their code is in memory.
---------------------------------------------------------------------------
local RAID_ADDON = "WarLegendRaidTool_Raid"
local lodPrefix = {}
for _, p in ipairs({ "WLRT_CON", "WLRT_LC", "WLRT_BUFF", "WLRT_CD2", "WLRT_RG", "WLRT_INSQ", "WLRT_INSD",
    "WLRT_RDYQ", "WLRT_RDYA", "WLRT_DUR" }) do
    lodPrefix[p] = true
    W.RegisterPrefix(p) -- the messages must reach us before the module that reads them is loaded
end
W.raidLoaded = false
local pendingMsgs, loadFailed, waitCombat = {}, false, false
local Dispatch

W.AddFR({
    ["The raid modules are missing or disabled: install the folder WarLegendRaidTool_Raid next to WarLegendRaidTool."] =
        "Les modules de raid sont absents ou désactivés : installe le dossier WarLegendRaidTool_Raid à côté de WarLegendRaidTool.",
})

-- Loads the raid addon now. Handlers its files registered after the login / roster events already
-- happened are run once, and the messages that asked for the load are delivered.
function W.LoadRaid()
    if W.raidLoaded then return true end
    if loadFailed or not (C_AddOns and C_AddOns.LoadAddOn) then return false end
    late = { handlers = {}, roster = {}, ready = {} }
    local called, ok = W.Measure("load the raid modules", C_AddOns.LoadAddOn, RAID_ADDON)
    if not called then ok = false end
    local got = late
    late = nil
    if not ok then
        loadFailed = true
        wipe(pendingMsgs)
        W.Print(L("The raid modules are missing or disabled: install the folder WarLegendRaidTool_Raid next to WarLegendRaidTool."))
        return false
    end
    W.raidLoaded = true
    for _, fn in ipairs(got.ready) do
        local good, err = pcall(fn)
        if not good then geterrorhandler()(err) end
    end
    if W.access == true then
        for _, h in ipairs(got.handlers) do
            if h.active and not h.always and not offFiles[h.file] and (h.event == "PLAYER_ENTERING_WORLD" or h.event == "PLAYER_LOGIN") then
                local good, err = pcall(h.fn, false, false)
                if not good then geterrorhandler()(err) end
            end
        end
        for _, fn in ipairs(got.roster) do
            if not offFiles[rosterFiles[fn]] then
                local good, err = pcall(fn)
                if not good then geterrorhandler()(err) end
            end
        end
    end
    local msgs = pendingMsgs
    pendingMsgs = {}
    for _, m in ipairs(msgs) do Dispatch(m[1], m[2], m[3], m[4]) end
    return true
end

-- Should the raid modules be in memory now? (in a group, a dungeon / raid, or with Aura Tracking on)
local function WantRaid()
    if W.access ~= true or W.raidLoaded or loadFailed then return false end
    local auras = W.db and W.db.auras
    if auras and auras.enabled then return true end -- Aura Tracking works everywhere, PvP included
    if W.InGroup() then return true end -- a battleground raid too (Raid Groups, marks)
    -- loaded during the loading screen (PLAYER_ENTERING_WORLD comes before it goes away): no freeze at the
    -- first /wl in the open world, the cost is the memory of the raid modules when playing alone
    if W.db and W.db.ui and W.db.ui.preloadRaid then return true end
    local inInstance, kind = IsInInstance()
    return inInstance and (kind == "party" or kind == "raid" or kind == "scenario") and true or false
end

function W.MaybeLoadRaid()
    if not WantRaid() then return end
    if InCombatLockdown() then waitCombat = true; return end -- frames are made after the fight
    W.LoadRaid()
end
W.On("PLAYER_ENTERING_WORLD", function() W.MaybeLoadRaid() end)
W.On("PLAYER_REGEN_ENABLED", function() if waitCombat then waitCombat = false; W.MaybeLoadRaid() end end)
W.OnRoster(function() W.MaybeLoadRaid() end)

function Dispatch(prefix, msg, channel, sender)
    local fn = addonHandlers[prefix]
    if not fn then
        -- a message for a raid module that is not loaded yet: load it, then deliver the message.
        -- Only from my group / guild (a whisper of a stranger must not load anything), and after the fight.
        if lodPrefix[prefix] and not W.raidLoaded and not loadFailed and W.access == true then
            local who = W.Safe(sender)
            if type(who) ~= "string" or who == "" then return end
            if not GROUP_CHANNELS[channel] then
                if channel ~= "WHISPER" then return end
                local full = W.FullName(who)
                if not (W.UnitByName(full) or W.GuildMember(full)) then return end
            end
            if #pendingMsgs < 50 then pendingMsgs[#pendingMsgs + 1] = { prefix, msg, channel, sender } end
            if InCombatLockdown() then waitCombat = true; return end -- loaded after the fight, messages kept
            W.LoadRaid()
        end
        return
    end
    local audit = W.AuditNote -- Audit.lua: what came in, what was refused and why (metadata only)
    if offFiles[addonFiles[prefix]] then
        if audit then audit("module-off", prefix, channel, nil, 0) end
        return
    end
    msg, sender = W.Safe(msg), W.Safe(sender)
    if not msg or not sender or sender == "" then
        if audit then audit("bad-sender", prefix, channel, nil, 0) end
        return
    end
    local full = W.FullName(sender)
    if not GROUP_CHANNELS[channel] then
        if channel ~= "WHISPER" then
            if audit then audit("bad-channel", prefix, channel, full, #msg) end
            return
        end
        if not (W.UnitByName(full) or W.GuildMember(full)) then
            if audit then audit("stranger", prefix, channel, full, #msg) end
            return
        end
    end
    if not audit then return fn(msg, W.BaseName(sender), channel, full) end
    audit("ok", prefix, channel, full, #msg)
    local t0 = clock and clock()
    fn(msg, W.BaseName(sender), channel, full)
    if t0 then audit("time", prefix, channel, nil, 0, clock() - t0) end
end
W.On("CHAT_MSG_ADDON", function(prefix, msg, channel, sender) Dispatch(prefix, msg, channel, sender) end)

-- Character names. WoW: Forever (interface 1.60+) has no realms: a character is "First Surname"
-- (only the full name is unique, many share a first name) and UnitName returns the surname where
-- retail returns the realm. The full identity is "First Surname" there, "Name-Realm" elsewhere;
-- the short name (display, per-player state) is the first name, like UnitName's first value.
local iface = tonumber((select(4, GetBuildInfo()))) or 0
W.FOREVER = (WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT) or (iface >= 16000 and iface < 20000)
W.NAME_SEP = (Constants and Constants.CharacterNameSeparatorConsts
    and Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR) or " "
if W.NAME_SEP == "" then W.NAME_SEP = " " end
local SEP = W.NAME_SEP
local SEP_CLASS = SEP == " " and "%s" or SEP:gsub("%W", "%%%0")

-- Realm without spaces, as in "Name-Realm"
local myRealm
function W.MyRealm()
    if not myRealm or myRealm == "" then
        myRealm = (GetNormalizedRealmName and GetNormalizedRealmName())
            or ((GetRealmName and GetRealmName() or ""):gsub("%s", ""))
    end
    return myRealm or ""
end

-- Any form of a name -> the full identity ("First Surname" on Forever, "Name-Realm" elsewhere)
function W.FullName(name)
    if not name or name == "" then return name end
    if W.FOREVER then
        if name:find(SEP, 1, true) then return (name:gsub("%-.*$", "")) end -- "First Surname[-Realm]"
        return (name:gsub("%-", SEP, 1))                                    -- "First-Surname" / "First"
    end
    if name:find("-", 1, true) then return name end
    return name .. "-" .. W.MyRealm()
end

function W.UnitFullName(unit)
    local n, second = UnitName(unit)
    n, second = W.Safe(n), W.Safe(second)
    if not n then return nil end
    if W.FOREVER then
        -- some units already carry the surname in the first value
        if second and second ~= "" and not n:find(SEP .. second, 1, true) then return n .. SEP .. second end
        return n
    end
    if not second or second == "" then second = W.MyRealm() end
    return n .. "-" .. second
end

-- Keys for per-player data: the full identity, lowercased. Two players sharing a first name
-- (WoW: Forever) or a name on two realms never share a key.
function W.Key(name)
    local f = W.FullName(name)
    return f and f:lower()
end

function W.UnitKey(unit)
    local f = W.UnitFullName(unit)
    return f and f:lower()
end

-- Name shown in our windows: "First Surname" on Forever (as Blizzard's frames), the name elsewhere
function W.UnitDisplayName(unit)
    if W.FOREVER then return W.UnitFullName(unit) end
    return W.Safe(UnitName(unit))
end

-- true when a full name carries the part that makes it unique (surname / realm)
function W.HasFullPart(name)
    if not name then return false end
    if W.FOREVER then return name:find(SEP, 1, true) ~= nil end
    return name:find("-", 1, true) ~= nil
end

---------------------------------------------------------------------------
-- Database
---------------------------------------------------------------------------
local readyFns = {}
function W.OnReady(fn)
    local where, inner = W.Where(2), fn
    fn = function() -- timed for /wl perf, errors go on to the caller's pcall
        local ok, err = W.Measure("ready " .. where, inner)
        if not ok then error(err, 0) end
    end
    -- a file of the raid addon: its ready functions run once the whole file is loaded, like at login
    if late then late.ready[#late.ready + 1] = fn; return end
    if W.db then fn() else readyFns[#readyFns + 1] = fn end
end

-- DB sub-table with default values (scalars only). A value of the wrong type (damaged file,
-- old format) is put back to its default instead of breaking the module.
function W.DB(key, defaults)
    local t = W.db[key]
    if type(t) ~= "table" then t = {}; W.db[key] = t end
    if defaults then
        for k, v in pairs(defaults) do
            if type(t[k]) ~= type(v) then t[k] = v end
        end
    end
    return t
end

-- Saved data format versions. A module changing its saved format registers a migration
-- (W.Migration(version, fn)); they run once each, in order, before the modules start.
-- A failing migration resets only the data it was working on, never the whole file.
local migrations = {}
function W.Migration(version, key, fn)
    migrations[#migrations + 1] = { v = version, key = key, fn = fn }
end

local function Migrate(db)
    local from = tonumber(db.schema) or 0
    local top = from
    table.sort(migrations, function(a, b) return a.v < b.v end)
    for _, m in ipairs(migrations) do
        if m.v > from then
            local ok, err = pcall(m.fn, db)
            if not ok then
                geterrorhandler()(err)
                if m.key then db[m.key] = nil end -- that module starts clean, the rest is kept
            end
        end
        if m.v > top then top = m.v end
    end
    db.schema = top
end

W.On("ADDON_LOADED", function(name)
    if name ~= ADDON then return end
    if type(WarLegendRaidToolDB) ~= "table" then WarLegendRaidToolDB = {} end
    W.db = WarLegendRaidToolDB
    Migrate(W.db)
    W.DB("ui", { lastModule = "RaidGroups", style = "auto", lang = "auto", overlapForce = false, preloadRaid = true })
    -- the language is known from here: everything built from now on uses it
    W.SetLanguage(W.db.ui.lang)
    W.ICON_NAMES = { L("Star"), L("Circle"), L("Diamond"), "Triangle", L("Moon"), L("Square"), L("Cross"), L("Skull") }
    W.DB("minimap", { angle = 200 })
    if type(W.db.ui.off) ~= "table" then W.db.ui.off = {} end
    for _, m in ipairs(W.modules) do
        if m.file and W.db.ui.off[m.key] and not W.CORE_MODULES[m.key] then offFiles[m.file] = true end
    end
    SyncAll()
    W.ResolveTheme()
    for _, fn in ipairs(readyFns) do
        local ok, err = pcall(fn)
        if not ok then geterrorhandler()(err) end
    end
    readyFns = {}
end, true)

---------------------------------------------------------------------------
-- Player / group / guild helpers (fallbacks for older clients)
---------------------------------------------------------------------------
function W.Safe(v)
    if v ~= nil and ((issecretvalue and issecretvalue(v)) or (canaccessvalue and not canaccessvalue(v))) then
        return nil
    end
    return v
end

-- Short name: without realm (and, on Forever, without surname), as UnitName's first value
function W.BaseName(name)
    if not name then return nil end
    if W.FOREVER then return name:match("^([^%-" .. SEP_CLASS .. "]+)") or name end
    return name:match("^([^%-]+)") or name
end

function W.SanitizeName(s)
    -- no control character (a line break would start a new macro line), no separator of our strings
    s = (s or ""):gsub("[%c;,|:~]", "")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

function W.InRaid()
    if IsInRaid then return IsInRaid() and true or false end
    return (GetNumRaidMembers and GetNumRaidMembers() or 0) > 0
end

function W.NumRaid()
    if not W.InRaid() then return 0 end
    if GetNumGroupMembers then return GetNumGroupMembers() end
    return GetNumRaidMembers()
end

function W.NumParty()
    if GetNumSubgroupMembers then return GetNumSubgroupMembers() end
    if GetNumPartyMembers then return GetNumPartyMembers() end
    return 0
end

function W.InGroup()
    return W.InRaid() or W.NumParty() > 0
end

function W.IsLeader()
    if UnitIsGroupLeader then return UnitIsGroupLeader("player") and true or false end
    return IsRaidLeader and IsRaidLeader() and true or false
end

function W.CanLead()
    if not W.InRaid() then return true end
    if W.IsLeader() then return true end
    if UnitIsGroupAssistant then return UnitIsGroupAssistant("player") and true or false end
    return IsRaidOfficer and IsRaidOfficer() and true or false
end

-- Unit tokens built once (no string concatenation in loops)
W.RAID_UNITS, W.PARTY_UNITS = {}, {}
for i = 1, 40 do W.RAID_UNITS[i] = "raid" .. i end
for i = 1, 4 do W.PARTY_UNITS[i] = "party" .. i end

function W.GroupUnits()
    local units = {}
    if W.InRaid() then
        for i = 1, W.NumRaid() do units[#units + 1] = W.RAID_UNITS[i] end
    elseif W.InGroup() then
        units[1] = "player"
        for i = 1, 4 do
            if UnitExists(W.PARTY_UNITS[i]) then units[#units + 1] = W.PARTY_UNITS[i] end
        end
    end
    return units
end

function W.Channel()
    if W.InRaid() then return "RAID" end
    if W.InGroup() then return "PARTY" end
end

-- Chat messages. WoW: Forever has a "chat messaging lockdown" (boss encounter, challenge mode,
-- PvP match) where addon messages in chat are refused (ADDON_ACTION_BLOCKED): check it first.
W.AddFR({
    ["Group chat is locked during boss fights: message shown only to you."] =
        "Le chat de groupe est verrouillé pendant les combats de boss : message affiché pour toi seulement.",
})

function W.ChatLocked()
    local f = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
    if not f then return false end
    local locked = f()
    if locked ~= nil and W.Safe(locked) == nil then return true end -- hidden answer: treat as locked
    return locked and true or false
end

-- Sends one line; false when it could not be sent (locked, empty, refused)
function W.SendChat(text, channel, target)
    if type(text) ~= "string" or text == "" or not channel or W.ChatLocked() then return false end
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if not send then return false end
    local ok, res = pcall(send, text, channel, nil, target)
    if not ok then return false end
    local success = Enum and Enum.SendChatMessageResult and Enum.SendChatMessageResult.Success
    if type(res) == "number" and success and res ~= success then return false end
    return true
end

-- Announces in group chat, or shows the line to me alone when the chat is locked
local lockNoticeAt = 0
function W.Announce(text, channel)
    if W.SendChat(text, channel) then return true end
    if GetTime() - lockNoticeAt > 10 then
        lockNoticeAt = GetTime()
        W.Print(L("Group chat is locked during boss fights: message shown only to you."))
    end
    W.Print(text)
    return false
end

-- Battleground / arena: the raid tools have nothing to do there
function W.InPvP()
    local _, kind = IsInInstance()
    return kind == "pvp" or kind == "arena"
end

-- Addon message transport. The modern API returns a result code where only Success (0) means the
-- message was accepted. Returns "sent", "throttle" (client limit: retry in a moment), "locked"
-- (AddOnMessageLockdown, e.g. during an encounter: retry after it) or "failed" (not in a group,
-- offline target...: will never succeed).
local AR = Enum and Enum.SendAddonMessageResult or {}
local AR_OK = AR.Success or 0
local AR_THROTTLE = { [AR.AddonMessageThrottle or 3] = true, [AR.ChannelThrottle or 8] = true }
local AR_LOCKED = AR.AddOnMessageLockdown or 11

function W.SendRaw(prefix, msg, channel, target)
    if not channel then return "failed" end
    -- WHISPER: an answer to one player (Readiness), only with a target
    if channel == "WHISPER" then
        if not target or target == "" then return "failed" end
    elseif channel ~= "RAID" and channel ~= "PARTY" and channel ~= "GUILD" and channel ~= "INSTANCE_CHAT" then
        return "failed"
    end
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        local ok, r = pcall(C_ChatInfo.SendAddonMessage, prefix, msg, channel, target)
        if not ok then return "failed" end
        if r == nil or r == true or r == AR_OK then return "sent" end
        if r == AR_LOCKED then return "locked" end
        if AR_THROTTLE[r] then return "throttle" end
        return "failed"
    elseif SendAddonMessage then
        SendAddonMessage(prefix, msg, channel, target)
        return "sent"
    end
    return "failed"
end

-- One immediate message; true only when the client accepted it
function W.Send(prefix, msg, channel, target)
    channel = channel or W.Channel()
    if not channel then return false end
    return W.SendRaw(prefix, msg, channel, target) == "sent"
end

function W.GetMarker(unit)
    return W.Safe(GetRaidTargetIndex(unit)) or 0
end

function W.IsInGuild()
    return IsInGuild and IsInGuild() and true or false
end

-- Requests a fresh roster (Blizzard throttles to once / 10 s); GUILD_ROSTER_UPDATE follows.
function W.RequestGuildRoster()
    if not W.IsInGuild() then return end
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

-- Every guild member: { name, class, rank, rankIndex, level, online }
-- Built once per GUILD_ROSTER_UPDATE (and only when someone asks): the list is shared, do not modify it.
-- Each entry: name = short name (display), full = full identity (invites, checks).
local guildList, guildByFull, guildByShort, guildDirty = {}, {}, {}, true
local function GuildDirty() guildDirty = true end
W.On("GUILD_ROSTER_UPDATE", GuildDirty, true)
W.On("PLAYER_GUILD_UPDATE", GuildDirty, true)

function W.GuildMembers()
    if not W.IsInGuild() then return {} end
    if not guildDirty then return guildList end
    guildDirty = false
    local list, byFull, byShort = {}, {}, {}
    for i = 1, (GetNumGuildMembers() or 0) do
        local name, rankName, rankIndex, level, _, _, _, _, online, _, class = GetGuildRosterInfo(i)
        name = W.Safe(name)
        if name then
            local full = W.FullName(name)
            local key = full:lower()
            if not byFull[key] then
                local m = {
                    name = W.BaseName(name), full = full, class = W.Safe(class), rank = rankName, rankIndex = rankIndex,
                    level = level, online = online and true or false,
                }
                byFull[key] = m
                list[#list + 1] = m
                -- a short name points to its member only while nobody else has it
                local s = m.name:lower()
                if byShort[s] == nil then byShort[s] = m else byShort[s] = false end
            end
        end
    end
    -- new tables: a list a caller is still looping over stays valid
    guildList, guildByFull, guildByShort = list, byFull, byShort
    return list
end

-- Guild member by full name, or by a short name nobody else in the guild has; else nil
function W.GuildMember(name)
    if not name or not W.IsInGuild() then return nil end
    W.GuildMembers()
    local m = guildByFull[W.FullName(name):lower()]
    if m then return m end
    if W.HasFullPart(name) then
        -- a full name that does not match: only accept it when the other side has no full part
        local s = guildByShort[W.BaseName(name):lower()]
        return (s and not W.HasFullPart(s.full)) and s or nil
    end
    return guildByShort[W.BaseName(name):lower()] or nil
end

---------------------------------------------------------------------------
-- Modern / vanilla API wrappers (WoW Forever runs on a modern client)
---------------------------------------------------------------------------
W.GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
W.GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
W.GetDetailedItemLevelInfo = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo

function W.SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(id)
        return info and info.name
    end
    return GetSpellInfo and (GetSpellInfo(id))
end

-- Item level of an item link (nil while the item data is not loaded yet)
function W.ItemLevel(link)
    if not link then return nil end
    local lvl = W.GetDetailedItemLevelInfo and W.GetDetailedItemLevelInfo(link)
    if not lvl and W.GetItemInfo then lvl = select(4, W.GetItemInfo(link)) end
    lvl = W.Safe(lvl)
    return (lvl and lvl > 0) and lvl or nil
end

-- Talents: Forever stores the 3 vanilla trees as trait groups (C_Traits), like Naowh Forever reads them.
-- Returns { spent = {21, 9, 0}, names = {...}, total, best } or nil
function W.ReadTalentConfig(configID)
    if not (configID and C_Traits and C_Traits.GetConfigInfo and C_Traits.GetGroupDisplayInfoByTreeID) then return nil end
    local config = C_Traits.GetConfigInfo(configID)
    local treeID = config and config.treeIDs and config.treeIDs[1]
    if not treeID then return nil end
    local groups = C_Traits.GetGroupDisplayInfoByTreeID(treeID)
    if not groups or #groups == 0 then return nil end
    local ids = {}
    for i, g in ipairs(groups) do ids[i] = g.groupID end
    local infos = (C_Traits.GetGroupCurrencyInfo and C_Traits.GetGroupCurrencyInfo(configID, ids)) or {}
    local t = { spent = {}, names = {}, total = 0 }
    local most = 0 -- no point spent (talents reset): no main tree
    for i, g in ipairs(groups) do
        local spent = 0
        for _, info in ipairs(infos) do
            local cur = info.traitNodeGroupID == g.groupID and info.currencyInfos and info.currencyInfos[1]
            if cur then spent = W.Safe(cur.spent) or 0 end
        end
        t.spent[i], t.names[i] = spent, g.displayName or ("#" .. i)
        t.total = t.total + spent
        if spent > most then t.best, most = t.names[i], spent end
    end
    return t
end

-- Old vanilla talent API (other clients)
function W.ClassicTalents(inspect)
    if not (GetNumTalentTabs and GetTalentInfo and GetTalentTabInfo and GetNumTalents) then return nil end
    local tabs = GetNumTalentTabs(inspect)
    if not tabs or tabs == 0 then return nil end
    local t = { spent = {}, names = {}, total = 0 }
    local most = 0 -- no point spent (talents reset): no main tree
    for tab = 1, tabs do
        local a, b = GetTalentTabInfo(tab, inspect)
        local name = type(a) == "string" and a or (type(b) == "string" and b) or ("#" .. tab)
        local pts = 0
        for i = 1, (GetNumTalents(tab, inspect) or 0) do
            local _, _, _, _, rank = GetTalentInfo(tab, i, inspect)
            pts = pts + (tonumber(rank) or 0)
        end
        t.spent[tab], t.names[tab] = pts, name
        t.total = t.total + pts
        if pts > most then t.best, most = name, pts end
    end
    return t
end

function W.OwnTalents()
    local id = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    return W.ReadTalentConfig(id) or W.ClassicTalents(false)
end

-- Talents of the unit being inspected (after INSPECT_READY)
function W.InspectTalents()
    if C_Traits and C_Traits.HasValidInspectData then
        if not C_Traits.HasValidInspectData() then return nil end
        local consts = Constants and Constants.TraitConsts
        local t = W.ReadTalentConfig(consts and consts.INSPECT_TRAIT_CONFIG_ID)
        if t then return t end
        -- valid inspect data but no usable trait config (transient, empty groups): the old reading is the
        -- fallback, kept only when it found points (all zeros would hide "unknown")
        t = W.ClassicTalents(true)
        return t and t.total > 0 and t or nil
    end
    return W.ClassicTalents(true)
end

function W.TalentText(t)
    if not t or not t.spent or #t.spent == 0 then return nil end
    local parts = {}
    for i, v in ipairs(t.spent) do parts[i] = tostring(v) end
    return table.concat(parts, "/")
end

function W.ClassColor(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 0.75, 0.75, 0.75
end

function W.UnitClassToken(unit)
    local _, class = UnitClass(unit)
    return W.Safe(class)
end

---------------------------------------------------------------------------
-- Widgets (Blizzard templates only, no custom textures)
---------------------------------------------------------------------------
W.BT = BackdropTemplateMixin and "BackdropTemplate" or nil
local nameCounter = 0
function W.N(prefix)
    nameCounter = nameCounter + 1
    return "WLRT" .. prefix .. nameCounter
end

function W.Size(f, w, h) f:SetWidth(w); f:SetHeight(h) end

function W.SetColor(tex, r, g, b, a)
    if tex.SetColorTexture then tex:SetColorTexture(r, g, b, a or 1) else tex:SetTexture(r, g, b, a or 1) end
end

---------------------------------------------------------------------------
-- Themes: follows the player's UI
--   "eui"      EllesmereUI installed -> its skinning API (its colors, font, accent, borders)
--   "blizzard" default WoW Forever UI -> Blizzard dialog frames, red buttons, gold text
--   "flat"     WarLegend flat black/red (warlegend.net)
--   "sashoof"  SashoofUI look: dark navy panels, cyan accent (the "War Legend Classic Forever" UI)
--   "wl3..."   the look of Sashoof's WarLegend v3 addon: slate panels, one of its five accents
--              (wl3 cyan, wl3red, wl3gold, wl3violet, wl3mono) and the logo of that color
-- "auto" (default) picks eui when available, else blizzard. Changing it needs a /reload.
---------------------------------------------------------------------------
local skin
W.style = "blizzard"

local BRAND = { 0.808, 0.098, 0.094 } -- WaR LegenD red #CE1918
-- colors of the flat themes (panel, light panel, border, button hover, header gradient, menu column)
local PALETTES = {
    flat = { panel = { 0.031, 0.031, 0.031 }, light = { 0.075, 0.075, 0.075 }, border = { 0.17, 0.17, 0.17 },
        hover = { 0.16, 0.05, 0.05 }, headTop = { 0.02, 0.02, 0.02 }, headBottom = { 0.09, 0.03, 0.03 }, side = { 0.05, 0.05, 0.05 } },
    sashoof = { panel = { 0.043, 0.078, 0.106 }, light = { 0.075, 0.125, 0.165 }, border = { 0.11, 0.2, 0.26 },
        hover = { 0.05, 0.17, 0.23 }, headTop = { 0.03, 0.07, 0.1 }, headBottom = { 0.05, 0.12, 0.16 }, side = { 0.027, 0.055, 0.075 } },
    wl3 = { panel = { 0.035, 0.043, 0.055 }, light = { 0.095, 0.11, 0.13 }, border = { 0.19, 0.23, 0.27 },
        hover = { 0.13, 0.155, 0.18 }, headTop = { 0.035, 0.043, 0.055 }, headBottom = { 0.065, 0.078, 0.095 }, side = { 0.065, 0.078, 0.095 } },
}
-- WarLegend v3 styles: accent color and logo (Media\WLLogo*.tga, from Sashoof's addon)
local WL3 = {
    wl3 = { 0.64, 0.76, 0.77, "WLLogoBlue" }, wl3red = { 0.80, 0.27, 0.20, "WLLogoRed" },
    wl3gold = { 0.91, 0.70, 0.36, "WLLogoGold" }, wl3violet = { 0.66, 0.45, 0.92, "WLLogoViolet" },
    wl3mono = { 0.78, 0.81, 0.84, "WLLogoWhite" },
}
local PAL = PALETTES.flat
function W.IsFlat() return W.style == "flat" or W.style == "sashoof" or WL3[W.style] ~= nil end
function W.ResolveTheme()
    local pref = (W.db and W.db.ui and W.db.ui.style) or "auto"
    if pref == "auto" then pref = skin and "eui" or "blizzard" end
    if pref == "eui" and not skin then pref = "blizzard" end
    W.style = pref
    PAL = PALETTES[WL3[pref] and "wl3" or pref] or PALETTES.flat
    if WL3[pref] then
        local a = WL3[pref]
        W.R, W.G, W.B = a[1], a[2], a[3]
        W.LOGO_TEX = "Interface\\AddOns\\" .. ADDON .. "\\Media\\" .. a[4]
        W.LOGO = string.format("|cffffffffWaR|r |cff%02x%02x%02xLegenD|r",
            math.floor(a[1] * 255 + 0.5), math.floor(a[2] * 255 + 0.5), math.floor(a[3] * 255 + 0.5))
    elseif pref == "eui" then
        local r, g, b = skin.GetAccentColor()
        W.R, W.G, W.B = r or BRAND[1], g or BRAND[2], b or BRAND[3]
        local font = skin.GetFont and skin.GetFont()
        W.FONT = font or W.FONT
    elseif pref == "blizzard" then
        W.R, W.G, W.B = 1, 0.82, 0 -- Blizzard gold
    elseif pref == "sashoof" then
        W.R, W.G, W.B = 0, 0.78, 1 -- SashoofUI cyan
    else
        W.R, W.G, W.B = BRAND[1], BRAND[2], BRAND[3]
    end
end
function W.Skin() return W.style == "eui" and skin or nil end

if EllesmereUI and EllesmereUI.RegisterSkin then
    EllesmereUI.RegisterSkin("WarLegendRaidTool", function(S)
        skin = S
        W.ResolveTheme()
        if S.OnLooksChanged then S.OnLooksChanged(function() W.ResolveTheme() end) end
    end)
end

function W.IsBlizzard() return W.style == "blizzard" end

local BLIZZ_DIALOG = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 },
}
local BLIZZ_PANEL = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

-- Panel / sub-frame background in the current theme
function W.Backdrop(f, alpha, light)
    local S = W.Skin()
    if S then S.Panel(f, { inset = not light }); return end
    if not f.SetBackdrop then return end
    if W.IsBlizzard() then
        f:SetBackdrop(BLIZZ_PANEL)
        f:SetBackdropColor(0.06, 0.06, 0.06, alpha or 0.9)
        f:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)
        return
    end
    f:SetBackdrop({ bgFile = W.WHITE, edgeFile = W.WHITE, edgeSize = 1 })
    if light then
        f:SetBackdropColor(PAL.light[1], PAL.light[2], PAL.light[3], alpha or 0.95)
    else
        f:SetBackdropColor(PAL.panel[1], PAL.panel[2], PAL.panel[3], alpha or 0.97)
    end
    f:SetBackdropBorderColor(PAL.border[1], PAL.border[2], PAL.border[3], 1)
end

-- Window frame (main window and popups)
function W.Shell(f, alpha)
    local S = W.Skin()
    if S then S.Shell(f); return end
    if not f.SetBackdrop then return end
    if W.IsBlizzard() then
        f:SetBackdrop(BLIZZ_DIALOG)
        f:SetBackdropColor(1, 1, 1, alpha or 1)
        return
    end
    W.Backdrop(f, alpha or 0.97)
end

-- Thin accent line
function W.Accent(f, point, h)
    local t = f:CreateTexture(nil, "ARTWORK")
    W.SetColor(t, W.R, W.G, W.B, 1)
    t:SetHeight(h or 2)
    local inset = W.IsBlizzard() and 5 or 1
    t:SetPoint(point or "TOPLEFT", inset, point == "BOTTOMLEFT" and inset or -inset)
    t:SetPoint(point == "BOTTOMLEFT" and "BOTTOMRIGHT" or "TOPRIGHT", -inset, point == "BOTTOMLEFT" and inset or -inset)
    return t
end

function W.Tooltip(frame, title, lines)
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(type(title) == "function" and title(self) or title, 1, 1, 1)
        if lines then
            for _, l in ipairs(lines) do GameTooltip:AddLine(l, 0.8, 0.8, 0.8, true) end
        end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Selected state for buttons used as tabs: accent bar under the button (every theme)
function W.SetSelected(b, selected)
    if not b.selBar then
        b.selBar = b:CreateTexture(nil, "OVERLAY")
        b.selBar:SetHeight(2)
        b.selBar:SetPoint("BOTTOMLEFT", 3, W.IsBlizzard() and 3 or 1)
        b.selBar:SetPoint("BOTTOMRIGHT", -3, W.IsBlizzard() and 3 or 1)
    end
    W.SetColor(b.selBar, W.R, W.G, W.B, 1)
    b.selBar:SetShown(selected and true or false)
    b.selected = selected
    if not W.Skin() and not W.IsBlizzard() and b.SetBackdropBorderColor then
        if selected then b:SetBackdropBorderColor(W.R, W.G, W.B, 1) else b:SetBackdropBorderColor(PAL.border[1], PAL.border[2], PAL.border[3], 1) end
    end
end

-- Search index (/wl search box): the texts of the widgets a module panel is made of, while it is built.
-- Above every widget function: they all call it (a local must be declared before the code using it).
local indexOff = false
local function Index(text, widget)
    local m = W.building
    if not m or indexOff or type(text) ~= "string" or text == "" then return end
    m.index = m.index or {}
    m.index[#m.index + 1] = { text = text, widget = widget }
end

function W.Button(parent, text, w, h, onClick, tip)
    local b
    local S = W.Skin()
    if W.IsBlizzard() then
        b = CreateFrame("Button", W.N("Btn"), parent, "UIPanelButtonTemplate")
        W.Size(b, w, h or 22)
        b:SetText(text)
        local fs = b.GetFontString and b:GetFontString()
        if fs and fs.SetFontObject then fs:SetFontObject("GameFontNormalSmall") end
    else
        b = CreateFrame("Button", W.N("Btn"), parent, W.BT)
        W.Size(b, w, h or 22)
        local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("CENTER", 0, 0)
        b:SetFontString(fs)
        b:SetNormalFontObject("GameFontHighlightSmall")
        b:SetDisabledFontObject("GameFontDisableSmall")
        if S then
            S.Button(b)
            if S.StateButtonLabel then S.StateButtonLabel(b) end
            if S.Font then S.Font(fs) end
        else
            W.Backdrop(b, 1, true)
            b:HookScript("OnEnter", function(self)
                if self:IsEnabled() then self:SetBackdropBorderColor(W.R, W.G, W.B, 1); self:SetBackdropColor(PAL.hover[1], PAL.hover[2], PAL.hover[3], 1) end
            end)
            b:HookScript("OnLeave", function(self)
                if self.selected then self:SetBackdropBorderColor(W.R, W.G, W.B, 1) else self:SetBackdropBorderColor(PAL.border[1], PAL.border[2], PAL.border[3], 1) end
                self:SetBackdropColor(PAL.light[1], PAL.light[2], PAL.light[3], 1)
            end)
        end
        b:SetScript("OnMouseDown", function(self) if self:IsEnabled() then fs:SetPoint("CENTER", 1, -1) end end)
        b:SetScript("OnMouseUp", function() fs:SetPoint("CENTER", 0, 0) end)
        b:SetText(text)
    end
    if onClick then b:SetScript("OnClick", onClick) end
    if tip then W.Tooltip(b, text, tip) end
    Index(text, b)
    return b
end

function W.Label(parent, text, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    Index(text, fs)
    fs:SetText(text or "")
    fs:SetJustifyH("LEFT")
    local S = W.Skin()
    if S and S.Font then S.Font(fs) end
    return fs
end

-- Module title: UPPERCASE + accent bar underneath
function W.Title(parent, text)
    local fs = W.Label(parent, W.Upper(text), "GameFontNormalLarge")
    fs:SetFont(W.FONT, 15, W.IsBlizzard() and "" or "OUTLINE")
    fs:SetPoint("TOPLEFT", 12, -8)
    if W.IsBlizzard() then fs:SetTextColor(1, 0.82, 0) else fs:SetTextColor(1, 1, 1) end
    local bar = parent:CreateTexture(nil, "ARTWORK")
    W.SetColor(bar, W.R, W.G, W.B, 1)
    W.Size(bar, 40, 2)
    bar:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -4)
    -- faint line across the rest of the panel
    local line = parent:CreateTexture(nil, "ARTWORK")
    W.SetColor(line, 1, 1, 1, 0.06)
    line:SetHeight(1)
    line:SetPoint("LEFT", bar, "RIGHT", 0, 0)
    line:SetPoint("RIGHT", parent, "RIGHT", -12, 0)
    return fs
end

function W.EditBox(parent, w, maxLetters)
    local e = CreateFrame("EditBox", W.N("Edit"), parent, "InputBoxTemplate")
    W.Size(e, w, 20)
    e:SetAutoFocus(false)
    e:SetMaxLetters(maxLetters or 40)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    local S = W.Skin()
    if S then S.EditBox(e) end
    return e
end

-- Checkbox bound to get/set; syncs itself when shown
function W.Check(parent, text, get, set, tip)
    local c = CreateFrame("CheckButton", W.N("Check"), parent, "UICheckButtonTemplate")
    W.Size(c, 24, 24)
    Index(text, c)
    indexOff = true -- its label is the same text
    local fs = W.Label(c, text, "GameFontHighlightSmall")
    indexOff = false
    fs:SetPoint("LEFT", c, "RIGHT", 2, 1)
    c.label = fs
    c:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    c:SetScript("OnShow", function(self) self:SetChecked(get() and true or false) end)
    c.Sync = function(self) self:SetChecked(get() and true or false) end
    if tip then W.Tooltip(c, text, tip) end
    local S = W.Skin()
    if S then S.Checkbox(c) end
    return c
end

function W.Panel(parent, w, h)
    local p = CreateFrame("Frame", nil, parent, W.BT)
    W.Size(p, w, h)
    W.Backdrop(p, 0.95, true)
    if not W.Skin() then W.Accent(p, "TOPLEFT", 2) end
    return p
end

function W.SkinScroll(sf)
    local S = W.Skin()
    local bar = sf.ScrollBar or (sf.GetName and sf:GetName() and _G[sf:GetName() .. "ScrollBar"])
    if S and bar then S.ScrollBar(bar) end
end

-- Scrolling list with recycled rows (striped)
function W.ScrollList(parent, w, h, rowH, makeRow)
    local sf = CreateFrame("ScrollFrame", W.N("Scroll"), parent, "UIPanelScrollFrameTemplate")
    W.Size(sf, w, h)
    W.SkinScroll(sf)
    local content = CreateFrame("Frame", nil, sf)
    W.Size(content, w, h)
    sf:SetScrollChild(content)
    local list = { sf = sf, content = content, rows = {} }
    function list:Row(i)
        local r = self.rows[i]
        if not r then
            r = makeRow(content)
            W.Size(r, w, rowH)
            r:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * rowH)
            if i % 2 == 0 and not r.stripe then
                r.stripe = r:CreateTexture(nil, "BACKGROUND")
                r.stripe:SetAllPoints()
                W.SetColor(r.stripe, 1, 1, 1, 0.035)
            end
            self.rows[i] = r
        end
        r:Show()
        return r
    end
    function list:Finish(n)
        for i = n + 1, #self.rows do self.rows[i]:Hide() end
        content:SetHeight(math.max(n * rowH, 1))
    end
    return list
end

function W.CloseButton(parent, size)
    local close = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
    W.Size(close, size or 28, size or 28)
    local S = W.Skin()
    if S then S.CloseButton(close) end
    return close
end

-- Small movable window (module popups)
function W.Window(name, w, h, title)
    local f = CreateFrame("Frame", name, UIParent, W.BT)
    W.Size(f, w, h)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    W.Shell(f)
    if W.IsFlat() then
        local head = f:CreateTexture(nil, "BACKGROUND", nil, 1)
        W.SetColor(head, 0, 0, 0, 1)
        head:SetPoint("TOPLEFT", 1, -1)
        head:SetPoint("TOPRIGHT", -1, -1)
        head:SetHeight(26)
        local line = f:CreateTexture(nil, "ARTWORK")
        W.SetColor(line, W.R, W.G, W.B, 1)
        line:SetHeight(2)
        line:SetPoint("TOPLEFT", head, "BOTTOMLEFT")
        line:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT")
    end
    f.title = W.Label(f, W.Upper(title or ""), "GameFontNormal")
    f.title:SetPoint("TOP", 0, W.IsBlizzard() and -14 or -8)
    if not W.IsBlizzard() then f.title:SetTextColor(1, 1, 1) end
    local close = W.CloseButton(f)
    close:SetPoint("TOPRIGHT", W.IsBlizzard() and -4 or 2, W.IsBlizzard() and -4 or 2)
    f.close = close
    f:Hide()
    return f
end

-- Timer bar
function W.TimerBar(parent, h)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetHeight(h or 14)
    bar:SetStatusBarTexture(W.BAR_TEXTURE)
    bar:SetStatusBarColor(W.R, W.G, W.B)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    W.SetColor(bar.bg, 0.08, 0.08, 0.10, 0.8)
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetPoint("CENTER")
    local S = W.Skin()
    if S and S.ApplyBarFill then S.ApplyBarFill(bar) end
    return bar
end

-- Multiline text popup (export / import)
local textPopup
function W.TextPopup(title, text, opts)
    opts = opts or {}
    if not textPopup then
        local f = W.Window("WLRTTextPopup", 460, 300, "")
        local nameLbl = W.Label(f, L("Name:"), "GameFontHighlightSmall")
        nameLbl:SetPoint("TOPLEFT", 16, -36)
        f.nameLbl = nameLbl
        f.nameBox = W.EditBox(f, 200)
        f.nameBox:SetPoint("LEFT", nameLbl, "RIGHT", 10, 0)
        local sf = CreateFrame("ScrollFrame", W.N("TextScroll"), f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 16, -64)
        sf:SetPoint("BOTTOMRIGHT", -34, 44)
        W.SkinScroll(sf)
        local boxBg = CreateFrame("Frame", nil, f, W.BT)
        boxBg:SetPoint("TOPLEFT", sf, -6, 6)
        boxBg:SetPoint("BOTTOMRIGHT", sf, 26, -6)
        W.Backdrop(boxBg, 0.6)
        sf:SetFrameLevel((boxBg:GetFrameLevel() or 1) + 2)
        local box = CreateFrame("EditBox", nil, sf)
        box:SetMultiLine(true)
        box:SetAutoFocus(false)
        box:SetFontObject("ChatFontNormal")
        box:SetWidth(400)
        box:SetHeight(180)
        box:SetMaxLetters(0)
        box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        sf:SetScrollChild(box)
        sf:EnableMouse(true)
        sf:SetScript("OnMouseDown", function() box:SetFocus() end)
        f.box = box
        f.status = W.Label(f, "", "GameFontHighlightSmall")
        f.status:SetPoint("BOTTOMLEFT", 16, 18)
        f.ok = W.Button(f, "OK", 110, 22)
        f.ok:SetPoint("BOTTOMRIGHT", -16, 12)
        f.extra = W.Button(f, "", 150, 22)
        f.extra:SetPoint("RIGHT", f.ok, "LEFT", -8, 0)
        tinsert(UISpecialFrames, "WLRTTextPopup")
        textPopup = f
    end
    local f = textPopup
    f.title:SetText(W.Upper(title))
    f.status:SetText(opts.hint or "")
    f.box:SetText(text or "")
    if opts.showName then
        f.nameLbl:Show(); f.nameBox:Show(); f.nameBox:SetText(opts.name or "")
    else
        f.nameLbl:Hide(); f.nameBox:Hide()
    end
    if opts.onExtra then
        f.extra:SetText(opts.extraText or "")
        f.extra:SetScript("OnClick", function() opts.onExtra(f) end)
        f.extra:Show()
    else
        f.extra:Hide()
    end
    if opts.onConfirm then
        f.ok:SetText(opts.confirmText or L("Import"))
        f.ok:SetScript("OnClick", function()
            local err = opts.onConfirm(f.box:GetText(), f.nameBox:GetText())
            if err then f.status:SetText("|cffff5555" .. err .. "|r") else f:Hide() end
        end)
    else
        f.ok:SetText(L("Close"))
        f.ok:SetScript("OnClick", function() f:Hide() end)
    end
    f:Show()
    f.box:SetFocus()
    if text and text ~= "" then f.box:HighlightText() end
end

---------------------------------------------------------------------------
-- Tabbed main window
---------------------------------------------------------------------------
-- "Test all" (as EllesmereUI's test mode): every module registers how to show itself with fake data; the
-- button in the window header and /wl test run the tests of the modules switched on, all at once, so each
-- thing can be seen and dragged to its place. label: English (translated when printed).
W.tests = {}
-- stop: hides what run showed (called by "Stop test" for every module, switched on or not)
function W.RegisterTest(label, enabled, run, stop)
    W.tests[#W.tests + 1] = { label = label, enabled = enabled, run = run, stop = stop, file = FileOf(W.Where(2)) }
end

W.AddFR({
    ["Test all"] = "Tout tester",
    ["Stop test"] = "Arrêter le test",
    ["Test stopped."] = "Test arrêté.",
    ["Test: %s. Drag them to move them (when not locked)."] =
        "Test : %s. Fais-les glisser pour les déplacer (s'ils ne sont pas verrouillés).",
    ["Test: no module switched on."] = "Test : aucun module activé.",
    ["Shows every module switched on, with fake data, so you can see and move them."] =
        "Affiche tous les modules activés avec de fausses données, pour les voir et les déplacer.",
})
-- the header button reads "Stop test" while a test runs; the longest test ends by itself after about 60 s
local testing, testRun, testButton = false, 0, nil
local function SetTesting(on)
    testing = on
    if testButton then testButton:SetText(on and L("Stop test") or L("Test all")) end
end
function W.StopTests(quiet)
    for _, t in ipairs(W.tests) do
        if t.stop then
            local ok, err = pcall(t.stop)
            if not ok then geterrorhandler()(err) end
        end
    end
    SetTesting(false)
    if not quiet then W.Print(L("Test stopped.")) end
end
function W.ToggleTests()
    if testing then W.StopTests() else W.TestAll() end
end
function W.SetTestButton(b) testButton = b end
function W.TestAll()
    local shown = {}
    if not W.raidLoaded and not InCombatLockdown() then W.LoadRaid() end -- the raid modules have tests too
    for _, t in ipairs(W.tests) do
        local okOn, on = pcall(t.enabled)
        if okOn and on and not offFiles[t.file] then
            local ok, err = pcall(t.run)
            if ok then shown[#shown + 1] = L(t.label) else geterrorhandler()(err) end
        end
    end
    if #shown == 0 then W.Print(L("Test: no module switched on.")); return end
    W.Print(string.format(L("Test: %s. Drag them to move them (when not locked)."), table.concat(shown, ", ")))
    SetTesting(true)
    testRun = testRun + 1
    local run = testRun
    W.After(65, function() if testing and run == testRun then SetTesting(false) end end)
end

W.modules = {}
local byKey = {}
-- never switched off: the tab that switches the others back on, the error list and the version check
W.CORE_MODULES = { Settings = true, Bugs = true, VersionCheck = true }
function W.RegisterModule(key, label, build, refresh)
    local m = { key = key, label = label, build = build, refresh = refresh, file = FileOf(W.Where(2)) }
    W.modules[#W.modules + 1] = m
    byKey[key] = m
    -- a module of the raid addon, loaded later: switched off from the start if it was
    if m.file and W.db and W.db.ui and type(W.db.ui.off) == "table" and W.db.ui.off[key] and not W.CORE_MODULES[key] then
        offFiles[m.file] = true
        SyncAll()
    end
end

function W.IsOff(key)
    local m = byKey[key]
    return m and m.file and offFiles[m.file] and true or false
end

W.AddFR({
    ["This module is switched off: it gets no events and does nothing."] =
        "Ce module est désactivé : il ne reçoit aucun événement et ne fait rien.",
    ["Switch it on"] = "L'activer",
    ["Settings > Modules lists every module."] = "Réglages > Modules liste tous les modules.",
})

-- the page of a switched off module, instead of its options
local function BuildOff(m, p)
    W.Title(p, L(m.label))
    local info = W.Label(p, L("This module is switched off: it gets no events and does nothing."), "GameFontHighlight")
    info:SetPoint("TOPLEFT", 16, -44)
    W.Button(p, L("Switch it on"), 140, 22, function() W.SetModuleOn(m.key, true) end):SetPoint("TOPLEFT", 16, -74)
    local more = W.Label(p, L("Settings > Modules lists every module."), "GameFontDisableSmall")
    more:SetPoint("TOPLEFT", 16, -108)
end

local main, mini
local MENU_W = 140

local function SavePos()
    local p, _, rp, x, y = main:GetPoint(1)
    local ui = W.DB("ui")
    ui.point, ui.relPoint, ui.x, ui.y = p, rp, x, y
end

-- Menu: 3 tabs on top. Raid = the raid night in order (organisation, preparation, combat, loot) plus PvP.
-- Guild = the guild and my characters. Options = the addon itself and the interface tools (nothing to do
-- with a raid or the guild). Every tab has collapsible sections (accordion = true: one open at a time, the
-- "+" / "-" sign on its header), each tab remembers its own. English keys, translated when the window is built.
-- Modules not listed go to the last section of the last tab.
local CATEGORIES = {
    { key = "pve", title = "Raid", accordion = true, sections = {
        { key = "org", title = "Organisation", items = { "RaidGroups", "InviteTool", "AutoPromote", "Summon", "MarksBar" } },
        { key = "prep", title = "Preparation", items = { "ReadyCheck", "Checklist", "RaidBuffs", "Readiness", "RaidInspect", "TalentReminder" } },
        { key = "fight", title = "Combat", items = { "RaidCooldowns", "AuraTracker", "CombatTimer", "WhoPulled", "AutoLog", "CCAlert" } },
        { key = "loot", title = "Loot", items = { "LootCouncil", "Attendance" } },
        { key = "bg", title = "PvP", items = { "PvPFrames", "CapTimers", "GYTimer", "BGStats", "Minotaure", "DuelTimer", "DangerAlert" } },
    } },
    { key = "me", title = "Guild", accordion = true, sections = {
        { key = "members", title = "Members", items = { "Guild", "Dashboard", "Classes", "Roster", "GuildPositions", "Layers" } },
        { key = "chars", title = "My characters", items = { "Alts", "GuildBank", "SimExport" } },
    } },
    { key = "options", title = "Options", accordion = true, sections = {
        { key = "addon", title = "Addon", items = { "Settings", "VersionCheck", "Bugs" } },
        { key = "ui", title = "Interface", items = { "MoveFrames", "InterfaceOptions", "ItemLevels", "CooldownText", "Focus", "QualityOfLife", "LootSparkles" } },
    } },
}

W.AddFR({
    ["Language of the addon: French / English (needs a reload)."] = "Langue de l'addon : français / anglais (demande un rechargement).",
    ["Organisation"] = "Organisation",
    ["Preparation"] = "Préparation",
    ["Combat"] = "Combat",
    ["Loot"] = "Butin",
    ["Raid"] = "Raid",
    ["PvP"] = "JcJ",
    ["Guild"] = "Guilde",
    ["Members"] = "Membres",
    ["My characters"] = "Mes personnages",
    ["Options"] = "Options",
    ["Addon"] = "Addon",
    ["Interface"] = "Interface",
    ["Raid Groups"] = "Groupes de raid",
    ["Invite Tool"] = "Invitations",
    ["Raid Inspect"] = "Inspection",
    ["Auto Promote"] = "Promotion auto",
    ["Marks Bar"] = "Barre de marques",
})

-- saved key of the open section of a tab (Raid keeps the key it always had)
local function OpenKey(catKey)
    return catKey == "pve" and "openSection" or ("openSection_" .. tostring(catKey))
end

local function Contains(list, m)
    for _, x in ipairs(list) do if x == m then return true end end
    return false
end

-- tab (category) and section holding a module: the given ones if they do, else the first
local function Locate(m, catKey, secKey)
    local cats = main and main.categories or {}
    for _, cat in ipairs(cats) do
        if cat.key == catKey then
            for _, sec in ipairs(cat.sections) do
                if sec.key == secKey and Contains(sec.list, m) then return catKey, secKey end
            end
            for _, sec in ipairs(cat.sections) do
                if Contains(sec.list, m) then return catKey, sec.key end
            end
        end
    end
    for _, cat in ipairs(cats) do
        for _, sec in ipairs(cat.sections) do
            if Contains(sec.list, m) then return cat.key, sec.key end
        end
    end
end

-- A module's panel, built once (hidden), its widget texts indexed for the search box
function W.EnsurePanel(m)
    if m.panel then return m.panel end
    m.panel = CreateFrame("Frame", nil, main.content)
    m.panel:SetAllPoints()
    -- built hidden: the Show of W.Select then runs every OnShow (check boxes, edit boxes and lists read
    -- their saved values there). Built while shown, a tab opened its first time after a /reload
    -- with every box unchecked and every text field empty.
    m.panel:Hide()
    W.building = m
    local build = m.build
    if W.IsOff(m.key) then build = function(p) BuildOff(m, p) end end
    local ok, err = W.Measure("build the tab " .. tostring(m.key), build, m.panel)
    W.building = nil
    if not ok then geterrorhandler()(err) end
    return m.panel
end

-- fromSection / fromCategory: where the clicked entry is (keeps it open)
function W.Select(key, fromSection, fromCategory)
    local m = byKey[key] or W.modules[1]
    if not m then return end
    for _, other in ipairs(W.modules) do
        if other.panel then other.panel:Hide() end
        for _, b in ipairs(other.buttons or {}) do b.sel:Hide(); W.MenuTextColor(b, other) end
    end
    W.EnsurePanel(m)
    m.panel:Show()
    for _, b in ipairs(m.buttons or {}) do b.sel:Show(); b.text:SetTextColor(1, 1, 1) end
    local ui = W.DB("ui")
    ui.lastModule = m.key
    -- the menu shows the tab and the section of the selected tool (each tab keeps its open section
    -- for when you come back)
    local cat, sec = Locate(m, fromCategory or ui.category, fromSection or ui[OpenKey(fromCategory or ui.category)])
    if cat then
        ui.category = cat
        for _, c in ipairs(main.categories or {}) do
            if c.key == cat and c.accordion then ui[OpenKey(cat)] = sec end
        end
    end
    if main.LayoutMenu then main.LayoutMenu() end
    if m.refresh then m.refresh(m.panel) end
end

-- a switched off module is grey in the menu
function W.MenuTextColor(b, m)
    if W.IsOff(m.key) then b.text:SetTextColor(0.45, 0.45, 0.45) else b.text:SetTextColor(unpack(main.textColor)) end
end

-- on = false: the module stops getting events, messages and tests (what it already shows stays until /reload)
function W.SetModuleOn(key, on)
    local m = byKey[key]
    if not m or not m.file or W.CORE_MODULES[key] then return end
    W.DB("ui").off[key] = (not on) or nil
    offFiles[m.file] = (not on) or nil
    SyncAll()
    -- the tab is built again: the options when on, the "switched off" page when off
    if m.panel then
        local shown = m.panel:IsShown()
        m.panel:Hide()
        m.panel = nil
        if shown then W.Select(key) end
    end
    for _, b in ipairs(m.buttons or {}) do W.MenuTextColor(b, m) end
end

-- Window size: the whole window is scaled (text, buttons and layouts together), so every module stays
-- readable and nothing overlaps. Saved as ui.scale; the grip at the bottom right and Settings > General set it.
local MIN_SCALE, MAX_SCALE = 0.8, 1.6
function W.SetWindowScale(s, keepCorner)
    if not main then return end
    local ui = W.DB("ui")
    local fit = math.min(MAX_SCALE, (UIParent:GetHeight() - 20) / 640, (UIParent:GetWidth() - 20) / 980)
    s = math.max(MIN_SCALE, math.min(tonumber(s) or 1, fit))
    s = math.floor(s * 100 + 0.5) / 100
    local old = main:GetScale()
    local left, top = main:GetLeft(), main:GetTop()
    main:SetScale(s)
    ui.scale = s ~= 1 and s or nil
    if keepCorner and left and top then -- keep the top left corner where it was
        main:ClearAllPoints()
        main:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * old / s, top * old / s)
        SavePos()
    end
end

function W.WindowScale() return (W.db and W.db.ui and W.db.ui.scale) or 1 end

function W.BuildMain()
    if main then return main end
    local blizz, S = W.IsBlizzard(), W.Skin()
    local IN = blizz and 11 or 1           -- inner edge of the frame border
    main = CreateFrame("Frame", "WarLegendRaidToolFrame", UIParent, W.BT)
    W.Size(main, 980, 640)
    local ui = W.DB("ui")
    if ui.point then
        main:SetPoint(ui.point, UIParent, ui.relPoint or ui.point, ui.x or 0, ui.y or 0)
    else
        main:SetPoint("CENTER")
    end
    main:SetFrameStrata("HIGH")
    main:SetScale(math.max(MIN_SCALE, math.min(ui.scale or 1, MAX_SCALE)))
    main:SetMovable(true)
    main:EnableMouse(true)
    main:SetClampedToScreen(true)
    main:RegisterForDrag("LeftButton")
    main:SetScript("OnDragStart", main.StartMoving)
    main:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePos() end)
    W.Shell(main, 0.97)
    tinsert(UISpecialFrames, "WarLegendRaidToolFrame")
    main.textColor = blizz and { 1, 0.82, 0 } or { 0.72, 0.72, 0.72 }

    -- Header: WAR (white) LEGEND (red) logo, like warlegend.net
    if not S then
        local head = main:CreateTexture(nil, "BACKGROUND", nil, 1)
        W.SetColor(head, 0, 0, 0, blizz and 0.55 or 1)
        head:SetPoint("TOPLEFT", IN, -IN)
        head:SetPoint("TOPRIGHT", -IN, -IN)
        head:SetHeight(34 - IN)
        if head.SetGradient and CreateColor and not blizz then
            head:SetColorTexture(1, 1, 1, 1)
            head:SetGradient("VERTICAL", CreateColor(PAL.headTop[1], PAL.headTop[2], PAL.headTop[3], 1), CreateColor(PAL.headBottom[1], PAL.headBottom[2], PAL.headBottom[3], 1))
        end
    end
    local line = main:CreateTexture(nil, "ARTWORK")
    W.SetColor(line, W.R, W.G, W.B, 1)
    line:SetHeight(2)
    line:SetPoint("TOPLEFT", IN, -34)
    line:SetPoint("TOPRIGHT", -IN, -34)
    -- skull logo, then WAR LEGEND
    local skull = main:CreateTexture(nil, "OVERLAY")
    W.Size(skull, 26, 26)
    skull:SetTexture(W.LOGO_TEX)
    skull:SetPoint("TOPLEFT", 10 + (blizz and 4 or 0), -4 - (blizz and 3 or 0))
    local logo = main:CreateFontString(nil, "OVERLAY")
    logo:SetFont(W.FONT, 20, "OUTLINE")
    logo:SetPoint("LEFT", skull, "RIGHT", 6, 0)
    logo:SetText(W.LOGO)
    local sub = main:CreateFontString(nil, "OVERLAY")
    sub:SetFont(W.FONT, 11, "OUTLINE")
    sub:SetPoint("BOTTOMLEFT", logo, "BOTTOMRIGHT", 8, 2)
    sub:SetText("|cffccccccRAIDTOOL|r  |cff777777v" .. W.version .. "|r")
    local close = W.CloseButton(main, 30)
    close:SetPoint("TOPRIGHT", blizz and -6 or 0, blizz and -6 or 0)
    -- style selector, a drop-down (needs a reload)
    local styles = { { "auto", L("Style: Auto") }, { "eui", "Style: EllesmereUI" }, { "blizzard", "Style: Blizzard" }, { "flat", "Style: WaR LegenD" }, { "sashoof", "Style: SashoofUI" },
        { "wl3", L("Style: WL v3 Cyan") }, { "wl3red", L("Style: WL v3 Red") }, { "wl3gold", L("Style: WL v3 Gold") },
        { "wl3violet", L("Style: WL v3 Violet") }, { "wl3mono", L("Style: WL v3 Monochrome") } }
    local styleBtn = W.Cycle(main, 160, styles, function() return W.DB("ui").style or "auto" end, function(v)
        if v == (W.DB("ui").style or "auto") then return end
        W.DB("ui").style = v
        W.ConfirmReload(L("Reload the interface to apply the new style?"))
    end, { L("Follows your interface: EllesmereUI when installed, else the Blizzard look."),
        L("WL v3: the look of Sashoof's WarLegend v3 addon (slate panels, five accent colors).") })
    styleBtn:SetPoint("TOPRIGHT", close, "TOPLEFT", -6, -4)
    W.Size(styleBtn, 160, 20)
    -- language: FR / EN, a drop-down like the style (needs a reload); shows the language that will be used
    local function NextLang()
        local cur = W.DB("ui").lang
        if cur ~= "fr" and cur ~= "en" then cur = W.LANG end
        return cur
    end
    local langBtn = W.Cycle(main, 52, { { "fr", "FR" }, { "en", "EN" } }, NextLang, function(v)
        if v == NextLang() then return end
        W.DB("ui").lang = v
        W.ConfirmReload(v == "fr" and "Recharger l'interface pour passer l'addon en français ?"
            or "Reload the interface to switch the addon to English?")
    end, { L("Language of the addon: French / English (needs a reload).") })
    W.Size(langBtn, 52, 20)
    langBtn:SetPoint("RIGHT", styleBtn, "LEFT", -6, 0)

    -- search box: a tool or an option (any check box, button or text of the tabs), results under it
    local search = W.EditBox(main, 170, 40)
    search:SetPoint("RIGHT", langBtn, "LEFT", -10, 0)
    -- "Test all": every module switched on shows itself at once (EllesmereUI-like test mode)
    local testBtn = W.Button(main, L("Test all"), 110, 20, function() W.ToggleTests() end,
        { L("Shows every module switched on, with fake data, so you can see and move them.") })
    testBtn:SetPoint("RIGHT", search, "LEFT", -10, 0)
    W.SetTestButton(testBtn)
    if testing then testBtn:SetText(L("Stop test")) end
    local hint = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", 4, 0)
    hint:SetText(L("Search an option..."))
    local results = CreateFrame("Frame", nil, main, W.BT)
    results:SetPoint("TOPRIGHT", search, "BOTTOMRIGHT", 0, -2)
    W.Size(results, 380, 10)
    results:SetFrameStrata("DIALOG")
    W.Backdrop(results, 0.97)
    results:Hide()
    local rows = {}
    local function Row(i)
        if rows[i] then return rows[i] end
        local r = CreateFrame("Button", nil, results)
        W.Size(r, 372, 18)
        r:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 18)
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        W.SetColor(hl, 1, 1, 1, 0.08)
        r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.text:SetPoint("LEFT", 4, 0)
        r.text:SetPoint("RIGHT", -4, 0)
        r.text:SetJustifyH("LEFT")
        r.text:SetWordWrap(false)
        r:SetScript("OnClick", function(self)
            results:Hide()
            search:ClearFocus()
            W.Reveal(self.module, self.widget)
        end)
        rows[i] = r
        return r
    end
    search:SetScript("OnTextChanged", function(self)
        local q = self:GetText() or ""
        hint:SetShown(q == "")
        local found = W.SearchOptions(q, 16)
        if #found == 0 then results:Hide(); return end
        for i, f in ipairs(found) do
            local r = Row(i)
            r.module, r.widget = f.module, f.widget
            r.text:SetText(f.label)
            r:Show()
        end
        for i = #found + 1, #rows do rows[i]:Hide() end
        results:SetHeight(8 + #found * 18)
        results:Show()
    end)
    search:HookScript("OnEscapePressed", function() results:Hide() end)
    main:HookScript("OnHide", function() results:Hide() end)

    -- Menu column
    local side = main:CreateTexture(nil, "BACKGROUND", nil, 1)
    W.SetColor(side, 0, 0, 0, S and 0.25 or (blizz and 0.35 or 1))
    if not S and not blizz then W.SetColor(side, PAL.side[1], PAL.side[2], PAL.side[3], 1) end
    side:SetPoint("TOPLEFT", IN, -36)
    side:SetPoint("BOTTOMLEFT", IN, IN)
    side:SetWidth(MENU_W + 3 - IN)
    local sep = main:CreateTexture(nil, "BORDER")
    W.SetColor(sep, 1, 1, 1, 0.08)
    sep:SetPoint("TOPLEFT", MENU_W + 4, -36)
    sep:SetPoint("BOTTOMLEFT", MENU_W + 4, IN)
    sep:SetWidth(1)
    local foot = main:CreateFontString(nil, "OVERLAY")
    foot:SetFont(W.FONT, 10, "OUTLINE")
    foot:SetPoint("BOTTOMLEFT", 12 + (blizz and 4 or 0), 10 + (blizz and 4 or 0))
    foot:SetText("|cff666666WARLEGEND|r|cff8a1210.NET|r")

    -- tabs -> sections -> modules (a module may be listed twice)
    local cats, placed = {}, {}
    for _, c in ipairs(CATEGORIES) do
        local cat = { key = c.key, title = c.title, short = c.short, pvp = c.pvp, accordion = c.accordion, sections = {} }
        for _, s in ipairs(c.sections) do
            local list = {}
            for _, key in ipairs(s.items) do
                if byKey[key] then list[#list + 1] = byKey[key]; placed[key] = true end
            end
            cat.sections[#cat.sections + 1] = { key = s.key, title = s.title, list = list, buttons = {} }
        end
        cats[#cats + 1] = cat
    end
    local lastCat = cats[#cats]
    for _, m in ipairs(W.modules) do
        if not placed[m.key] then table.insert(lastCat.sections[#lastCat.sections].list, m) end
    end
    main.categories = cats

    local BTN_W = MENU_W - 4 - IN
    local function EntryButton(m, sec, cat)
        local b = CreateFrame("Button", nil, main)
        W.Size(b, BTN_W, 21)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        W.SetColor(hl, 1, 1, 1, 0.07)
        -- active tab: tinted background + accent bar on the left
        b.sel = CreateFrame("Frame", nil, b)
        b.sel:SetAllPoints()
        local selBg = b.sel:CreateTexture(nil, "BACKGROUND")
        selBg:SetAllPoints()
        W.SetColor(selBg, W.R, W.G, W.B, 0.2)
        if selBg.SetGradient and CreateColor then
            selBg:SetColorTexture(1, 1, 1, 1)
            selBg:SetGradient("HORIZONTAL", CreateColor(W.R, W.G, W.B, 0.35), CreateColor(W.R, W.G, W.B, 0))
        end
        local selBar = b.sel:CreateTexture(nil, "ARTWORK")
        W.SetColor(selBar, W.R, W.G, W.B, 1)
        selBar:SetPoint("TOPLEFT"); selBar:SetPoint("BOTTOMLEFT"); selBar:SetWidth(3)
        b.sel:Hide()
        b.text = b:CreateFontString(nil, "OVERLAY")
        b.text:SetFont(W.FONT, 11, "")
        b.text:SetPoint("LEFT", 18, 0) -- indented under its section
        b.text:SetText(W.Upper(L(m.label))) -- labels were registered in English at load
        -- a long label (French, a new module) shrinks to fit, then is cut: it never runs into the content
        local avail, size = BTN_W - 22, 11
        while b.text:GetStringWidth() > avail and size > 8 do
            size = size - 1
            b.text:SetFont(W.FONT, size, "")
        end
        if b.text:GetStringWidth() > avail then b.text:SetWidth(avail); b.text:SetWordWrap(false) end
        W.MenuTextColor(b, m)
        b:SetScript("OnClick", function() W.Select(m.key, sec.key, cat.key) end)
        m.buttons = m.buttons or {}
        m.buttons[#m.buttons + 1] = b
        b:Hide()
        return b
    end

    local LayoutMenu
    -- the tabs on top (Raid / Guild / Options), 2 px apart, each as wide as its label is long: the menu column
    -- is narrow and "OPTIONS" needs more room than "RAID"
    local weights, total = {}, 0
    for i, cat in ipairs(cats) do
        weights[i] = math.max(3, #W.Upper(L(cat.short or cat.title)))
        total = total + weights[i]
    end
    local free = BTN_W - 2 * (#cats - 1)
    local tabW, used = {}, 0
    for i = 1, #cats do
        tabW[i] = math.floor(free * weights[i] / total)
        used = used + tabW[i]
    end
    tabW[#cats] = tabW[#cats] + free - used
    local tx = IN + 3
    for i, cat in ipairs(cats) do
        local t = CreateFrame("Button", nil, main)
        W.Size(t, tabW[i] or 40, 22)
        t:SetPoint("TOPLEFT", tx, -42)
        tx = tx + (tabW[i] or 40) + 2
        local bg = t:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        W.SetColor(bg, 1, 1, 1, 0.05)
        local hl = t:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        W.SetColor(hl, 1, 1, 1, 0.08)
        local r, g, b = W.R, W.G, W.B
        if cat.pvp then r, g, b = 0.35, 0.65, 1 end
        t.on = t:CreateTexture(nil, "BORDER")
        t.on:SetAllPoints()
        W.SetColor(t.on, r, g, b, 0.3)
        t.line = t:CreateTexture(nil, "ARTWORK")
        W.SetColor(t.line, r, g, b, 1)
        t.line:SetPoint("BOTTOMLEFT"); t.line:SetPoint("BOTTOMRIGHT"); t.line:SetHeight(2)
        t.text = t:CreateFontString(nil, "OVERLAY")
        t.text:SetFont(W.FONT, 10, "OUTLINE")
        t.text:SetPoint("CENTER")
        t.text:SetText(W.Upper(L(cat.short or cat.title)))
        if cat.short then W.Tooltip(t, L(cat.title)) end
        t:SetScript("OnClick", function()
            W.DB("ui").category = cat.key
            LayoutMenu()
        end)
        cat.tab = t
    end

    for _, cat in ipairs(cats) do
        for _, sec in ipairs(cat.sections) do
            if #sec.list > 0 and sec.title then
                -- section header: click to open / close (accordion)
                local h = CreateFrame("Button", nil, main)
                W.Size(h, BTN_W, 20)
                local hbg = h:CreateTexture(nil, "BACKGROUND")
                hbg:SetAllPoints()
                W.SetColor(hbg, 1, 1, 1, 0.04)
                local hhl = h:CreateTexture(nil, "HIGHLIGHT")
                hhl:SetAllPoints()
                W.SetColor(hhl, 1, 1, 1, 0.08)
                h.text = h:CreateFontString(nil, "OVERLAY")
                h.text:SetFont(W.FONT, 10, "OUTLINE")
                h.text:SetPoint("LEFT", 8, 0)
                h.text:SetText(W.Upper(L(sec.title)))
                h.text:SetTextColor(W.R, W.G, W.B)
                h.sign = h:CreateTexture(nil, "OVERLAY")
                W.Size(h.sign, 12, 12)
                h.sign:SetPoint("RIGHT", -6, 0)
                -- a short tab shows every section: its headers are plain titles
                if cat.accordion then
                    h:SetScript("OnClick", function()
                        local ui = W.DB("ui")
                        local k = OpenKey(cat.key)
                        ui[k] = ui[k] ~= sec.key and sec.key or nil
                        LayoutMenu()
                    end)
                else
                    h:EnableMouse(false)
                    hhl:Hide()
                    h.sign:Hide()
                end
                sec.header = h
            end
            for _, m in ipairs(sec.list) do sec.buttons[#sec.buttons + 1] = EntryButton(m, sec, cat) end
        end
    end

    -- shows the chosen tab: its section headers and the entries of the open section
    function LayoutMenu()
        local ui = W.DB("ui")
        local current = ui.category or cats[1].key
        local y = -70
        for _, cat in ipairs(cats) do
            local active = cat.key == current
            cat.tab.on:SetShown(active)
            cat.tab.line:SetShown(active)
            cat.tab.text:SetTextColor(active and 1 or 0.7, active and 1 or 0.7, active and 1 or 0.7)
            for _, sec in ipairs(cat.sections) do
                local isOpen = true
                if sec.header then
                    isOpen = (not cat.accordion) or sec.key == ui[OpenKey(cat.key)]
                    sec.header:SetShown(active)
                    if active then
                        sec.header:ClearAllPoints()
                        sec.header:SetPoint("TOPLEFT", IN + 3, y)
                        if cat.accordion then
                            sec.header.sign:SetTexture(isOpen and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
                        end
                        y = y - 22
                    end
                end
                for _, b in ipairs(sec.buttons) do
                    if active and isOpen then
                        b:ClearAllPoints()
                        b:SetPoint("TOPLEFT", IN + 3, y)
                        b:Show()
                        y = y - 22
                    else
                        b:Hide()
                    end
                end
                if active and sec.header then y = y - 4 end
            end
        end
    end
    main.LayoutMenu = LayoutMenu

    main.content = CreateFrame("Frame", nil, main)
    main.content:SetPoint("TOPLEFT", MENU_W + 10, -42)
    main.content:SetPoint("BOTTOMRIGHT", -8 - (blizz and 8 or 0), 8 + (blizz and 6 or 0))

    -- resize grip (bottom right): drag to make the whole window bigger or smaller
    local grip = CreateFrame("Button", nil, main)
    W.Size(grip, 16, 16)
    grip:SetPoint("BOTTOMRIGHT", -3, 3)
    grip:SetFrameLevel(main:GetFrameLevel() + 50)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:RegisterForClicks("LeftButtonUp")
    grip:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or InCombatLockdown() then return end
        self.leftU = (main:GetLeft() or 0) * main:GetScale()
        self:SetScript("OnUpdate", function(g)
            local x = GetCursorPosition() / UIParent:GetEffectiveScale()
            W.SetWindowScale((x - g.leftU) / main:GetWidth(), true) -- width on screen / base width
        end)
    end)
    grip:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
    grip:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
    grip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L("Drag to resize the window"))
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function() GameTooltip:Hide() end)

    main:SetScript("OnShow", function()
        local cur = byKey[W.DB("ui").lastModule]
        W.Select(cur and cur.key or W.modules[1].key)
    end)
    main:Hide()
    return main
end

---------------------------------------------------------------------------
-- Search: tool names, then the texts of every panel (built hidden once, the first time something is
-- searched). Accents and case do not matter. A result opens the tool, its sub-tab, and flashes the option.
---------------------------------------------------------------------------
W.AddFR({
    ["Drag to resize the window"] = "Glisse pour redimensionner la fenêtre",
    ["Search an option..."] = "Rechercher une option...",
})
local ACCENTS = { ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e", ["à"] = "a", ["â"] = "a", ["ä"] = "a",
    ["î"] = "i", ["ï"] = "i", ["ô"] = "o", ["ö"] = "o", ["ù"] = "u", ["û"] = "u", ["ü"] = "u", ["ç"] = "c",
    ["É"] = "e", ["È"] = "e", ["Ê"] = "e", ["À"] = "a", ["Â"] = "a", ["Î"] = "i", ["Ô"] = "o", ["Û"] = "u", ["Ç"] = "c" }
local function Plain(s)
    s = (s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
    return s
end
local function Norm(s)
    s = Plain(s)
    for from, to in pairs(ACCENTS) do s = s:gsub(from, to) end
    return s:lower()
end
local NOT_BUILT = { PvPFrames = true } -- its panel loads the PvP addon: found by its name only
local allIndexed = false

-- The tabs not opened yet are built one at a time in the background (one every 0.1 s, never in combat), so
-- the search box knows their options without one long freeze at the first search.
local slowIndexing = false
function W.IndexTabsSlowly()
    if slowIndexing or allIndexed or not main then return end
    slowIndexing = true
    local i = 0
    local function step()
        if allIndexed then slowIndexing = false; return end
        if InCombatLockdown() then W.After(1, step); return end
        -- not in a battleground: the frames load there already, the tabs are built once outside (a first
        -- search still builds what is missing, see W.SearchOptions)
        local inInstance, kind = IsInInstance()
        if inInstance and kind == "pvp" then W.After(10, step); return end
        i = i + 1
        local m = W.modules[i]
        if not m then allIndexed = true; slowIndexing = false; return end
        if not m.panel and not NOT_BUILT[m.key] then W.EnsurePanel(m) end
        W.After(0.1, step)
    end
    W.After(1, step)
end

function W.SearchOptions(query, max)
    local q = Norm(query):gsub("^%s+", ""):gsub("%s+$", "")
    if #q < 2 or not main then return {} end
    if not allIndexed then
        allIndexed = true
        for _, m in ipairs(W.modules) do
            if not NOT_BUILT[m.key] then W.EnsurePanel(m) end
        end
    end
    local out, seen = {}, {}
    local function add(m, widget, text)
        local key = m.key .. "|" .. text
        if seen[key] or #out >= max then return end
        seen[key] = true
        out[#out + 1] = { module = m, widget = widget,
            label = "|cffffd100" .. L(m.label) .. "|r" .. (widget and ("  |cff777777>|r  " .. text) or "") }
    end
    for _, m in ipairs(W.modules) do -- the tools first
        if Norm(L(m.label)):find(q, 1, true) then add(m, nil, "") end
    end
    for _, m in ipairs(W.modules) do
        for _, e in ipairs(m.index or {}) do
            local text = Plain(e.text)
            if Norm(text):find(q, 1, true) then add(m, e.widget, text) end
        end
    end
    return out
end

function W.Reveal(m, widget)
    W.Select(m.key)
    if not widget then return end
    -- the sub-tab holding it
    local f = widget
    for _ = 1, 10 do
        f = f.GetParent and f:GetParent()
        if not f then break end
        if f.subTabs and f.subTabIndex then f.subTabs:Select(f.subTabIndex); break end
    end
    -- a short flash around it (a check box with its text)
    local glow = main.searchGlow
    if not glow then
        glow = CreateFrame("Frame", nil, main, W.BT)
        glow:SetBackdrop({ edgeFile = W.WHITE, edgeSize = 2 })
        glow:SetFrameStrata("DIALOG")
        main.searchGlow = glow
    end
    glow:ClearAllPoints()
    glow:SetPoint("TOPLEFT", widget, "TOPLEFT", -4, 4)
    glow:SetPoint("BOTTOMRIGHT", widget.label or widget, "BOTTOMRIGHT", 4, -4)
    glow:SetBackdropBorderColor(W.R, W.G, W.B, 1)
    glow:Show()
    W.After(2.5, function() glow:Hide() end)
end

function W.Toggle(key)
    if not W.Allowed() then W.Denied(); return end
    W.LoadRaid() -- the menu is built once, with the raid tools in it
    if not main then
        local ok, err = W.Measure("build the /wl window", W.BuildMain)
        if not ok then geterrorhandler()(err) end
        if not main then return end
    end
    W.IndexTabsSlowly()
    if key then
        W.DB("ui").lastModule = key
        if main:IsShown() then W.Select(key) else main:Show() end
        return
    end
    if main:IsShown() then main:Hide() else main:Show() end
end

function W.Hide()
    if main then main:Hide() end
    if mini then mini:Hide() end
end

function W.IsShown(key)
    return main and main:IsShown() and W.DB("ui").lastModule == key
end

---------------------------------------------------------------------------
-- Minimap button (Blizzard texture)
---------------------------------------------------------------------------
local function MiniPos()
    local a = math.rad(W.DB("minimap").angle or 200)
    local r = (Minimap:GetWidth() / 2) + 8
    mini:ClearAllPoints()
    mini:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

function W.UpdateMinimap()
    if not mini then return end
    if W.DB("minimap").hide then mini:Hide() else MiniPos(); mini:Show() end
end

local function CreateMinimapButton()
    if mini then return end
    mini = CreateFrame("Button", "WarLegendRaidToolMinimap", Minimap)
    W.Size(mini, 31, 31)
    mini:SetFrameStrata("MEDIUM")
    mini:SetFrameLevel(8)
    mini:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    -- War Legend skull on the usual dark round minimap background
    local back = mini:CreateTexture(nil, "BACKGROUND")
    W.Size(back, 20, 20)
    back:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    back:SetPoint("TOPLEFT", 6, -5)
    local icon = mini:CreateTexture(nil, "ARTWORK")
    W.Size(icon, 18, 18)
    icon:SetTexture(W.LOGO_SMALL)
    icon:SetPoint("TOPLEFT", 7, -6)
    local border = mini:CreateTexture(nil, "OVERLAY")
    W.Size(border, 53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")
    mini:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    mini:RegisterForDrag("LeftButton")
    mini:SetScript("OnClick", function(_, btn)
        if btn == "RightButton" then W.LoadRaid() end
        if btn == "RightButton" and W.ApplySelectedPreset then
            W.ApplySelectedPreset()
        else
            W.Toggle()
        end
    end)
    mini:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local sc = Minimap:GetEffectiveScale()
            W.DB("minimap").angle = math.deg(math.atan2(cy / sc - my, cx / sc - mx))
            MiniPos()
        end)
    end)
    mini:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    W.Tooltip(mini, W.LOGO .. " RaidTool", {
        L("Left-click: open"), L("Right-click: apply selected preset"), L("Drag: move") })
    W.UpdateMinimap()
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
W.slash = {}

-- /wl perf: what the addon really costs (memory, and CPU when the client has the addon profiler)
W.AddFR({
    ["Memory: %.0f KB"] = "Mémoire : %.0f Ko",
    ["CPU: %.3f ms per frame (recent), %.3f ms (last boss fight), peak %.2f ms"] =
        "CPU : %.3f ms par image (récent), %.3f ms (dernier boss), pic %.2f ms",
    ["CPU: this client has no addon profiler."] = "CPU : ce client n'a pas de profileur d'addons.",
    ["load the raid modules at the loading screen (fewer freezes) on / off"] =
        "charger les modules de raid pendant l'écran de chargement (moins de gels) oui / non",
    ["Slowest work (one run, ms):"] = "Travaux les plus lents (une exécution, ms) :",
    ["Busiest work (total ms since login):"] = "Travaux les plus coûteux (total en ms depuis la connexion) :",
    ["Raid modules loaded at the loading screen: "] = "Modules de raid chargés à l'écran de chargement : ",
})
-- /wl test: the test of every module switched on, at once (again: stops it); /wl test stop
W.slash.test = function(rest)
    if rest and rest:lower():match("^%s*stop") then W.StopTests() else W.ToggleTests() end
end

W.slash.perf = function()
    if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
        UpdateAddOnMemoryUsage()
        W.Print(string.format(L("Memory: %.0f KB"), GetAddOnMemoryUsage(ADDON) or 0))
    end
    local P, M = C_AddOnProfiler, Enum and Enum.AddOnProfilerMetric
    if P and P.GetAddOnMetric and M then
        local function get(metric) return (metric and P.GetAddOnMetric(ADDON, metric)) or 0 end
        W.Print(string.format(L("CPU: %.3f ms per frame (recent), %.3f ms (last boss fight), peak %.2f ms"),
            get(M.RecentAverageTime), get(M.EncounterAverageTime), get(M.PeakTime)))
    else
        W.Print(L("CPU: this client has no addon profiler."))
    end
    -- our own timing since the login / last reload, with the code that made it: the slowest single runs
    -- (freezes) and the busiest in all (the frequent small ones: hooks, timers), count and total / max
    local slow = W.SlowestWork(5)
    if #slow > 0 then
        W.Print(L("Slowest work (one run, ms):"))
        for _, s in ipairs(slow) do W.Print(string.format("  %.1f  %s  (x%d, total %.0f)", s[2], s[1], s[3], s[4])) end
    end
    local busy = W.BusiestWork(5)
    if #busy > 0 then
        W.Print(L("Busiest work (total ms since login):"))
        for _, s in ipairs(busy) do W.Print(string.format("  %.0f  %s  (x%d, max %.1f)", s[4], s[1], s[3], s[2])) end
    end
    W.Print(L("Raid modules loaded at the loading screen: ") .. (W.DB("ui").preloadRaid and L("YES") or L("no"))
        .. "  |cff999999(/wl preload)|r")
end

-- /wl preload: load the raid modules during the loading screen (no freeze at the first /wl), or on demand
W.slash.preload = function()
    local ui = W.DB("ui")
    ui.preloadRaid = not ui.preloadRaid
    W.Print(L("Raid modules loaded at the loading screen: ") .. (ui.preloadRaid and L("YES") or L("no")))
end

-- /wl reset [data]: puts one module's saved data back to zero (a damaged module), keeps the rest
W.AddFR({
    ["Saved data: %s. |cffffffff/wl reset <name>|r resets one of them."] =
        "Données sauvegardées : %s. |cffffffff/wl reset <nom>|r en remet une à zéro.",
    ["Reset the saved data \"%s\"? The interface reloads after."] =
        "Remettre à zéro les données « %s » ? L'interface se recharge ensuite.",
    ["Data reset. Reload the interface to finish."] = "Données remises à zéro. Recharge l'interface pour terminer.",
})
W.slash.reset = function(rest)
    local key = (rest or ""):match("^(%S+)")
    if not key or type(W.db[key]) ~= "table" then
        local keys = {}
        for k, v in pairs(W.db) do if type(v) == "table" then keys[#keys + 1] = k end end
        table.sort(keys)
        W.Print(string.format(L("Saved data: %s. |cffffffff/wl reset <name>|r resets one of them."), table.concat(keys, ", ")))
        return
    end
    W.Confirm(string.format(L("Reset the saved data \"%s\"? The interface reloads after."), key), function()
        W.db[key] = nil
        W.ConfirmReload(L("Data reset. Reload the interface to finish."))
    end)
end

-- /wl help: every command in the chat (also shown for an unknown command)
W.AddFR({
    ["Commands (|cffffffff/wl|r = |cffffffff/wlrt|r = |cffffffff/warlegend|r, [preset] = selected preset if empty):"] =
        "Commandes (|cffffffff/wl|r = |cffffffff/wlrt|r = |cffffffff/warlegend|r, [preset] = preset sélectionné si vide) :",
    ["open / close the window"] = "ouvrir / fermer la fenêtre",
    ["this list"] = "cette liste",
    ["show / hide the minimap button"] = "afficher / cacher le bouton de la minicarte",
    ["recent Lua errors"] = "erreurs Lua récentes",
    ["memory and CPU used by the addon"] = "mémoire et CPU utilisés par l'addon",
    ["addon traffic log of the session (on / off)"] = "journal du trafic de l'addon pour la session (on / off)",
    ["reset one module's saved data (no name: list them)"] = "remettre à zéro les données d'un module (sans nom : les lister)",
    ["combat log auto-start debug"] = "débogage du journal de combat automatique",
    ["apply the preset: marks + groups"] = "appliquer le preset : marques + groupes",
    ["only the preset's marks"] = "seulement les marques du preset",
    ["only the preset's groups"] = "seulement les groupes du preset",
    ["clear all marks"] = "effacer toutes les marques",
    ["list the presets"] = "lister les presets",
    ["create my assist macro"] = "créer ma macro d'assist",
    ["ready check (leader / assist), else the check window"] = "appel (chef / assistant), sinon la fenêtre de vérification",
    ["check window (ready, durability)"] = "fenêtre de vérification (prêt, durabilité)",
    ["Loot Council (vote | add [item] | test)"] = "Loot Council (vote | add [objet] | test)",
    ["soft-res tab (players whisper \"!sr [item]\")"] = "onglet soft-res (les joueurs chuchotent \"!sr [objet]\")",
    ["simulator export (simc, oxm, json)"] = "export pour simulateur (simc, oxm, json)",
    ["summon list"] = "liste de summon",
    ["graveyard timer test (fake waves)"] = "test du chrono de cimetière (fausses vagues)",
    ["PvP frames settings"] = "réglages des cadres PvP",
    ["are the addon restrictions active in this battleground?"] = "les restrictions d'addons sont-elles actives dans ce champ de bataille ?",
    ["guild trials (by rank)"] = "recrues de la guilde (par rang)",
    ["guild dashboard (item level, enchants, attendance, loots)"] = "tableau de bord de la guilde (niveau d'objets, enchants, présences, loots)",
    ["last battleground messages (to copy)"] = "derniers messages du champ de bataille (à copier)",
    ["warning when an enemy player or a dangerous mob is near"] = "alerte quand un joueur ennemi ou un monstre dangereux approche",
    ["big icon when I am crowd controlled"] = "grosse icône quand je suis sous contrôle (CC)",
    ["big countdown for duels (start, out of the duel area)"] = "gros compte à rebours pour les duels (début, hors de la zone)",
    ["test every module switched on at once (to see and move them)"] = "tester tous les modules activés en même temps (pour les voir et les déplacer)",
    ["stop the test"] = "arrêter le test",
    ["battleground timers: captures, gates, queue, flag (Capping style)"] = "chronos de BG : captures, portes, file, drapeau (style Capping)",
    ["stock of my bank characters"] = "stock de mes persos banque",
    ["who can craft it in the guild (name or item link)"] = "qui peut le fabriquer dans la guilde (nom ou lien d'objet)",
    ["switch modules fully off (Settings > Modules)"] = "éteindre complètement des modules (Réglages > Modules)",
    ["move Blizzard windows, screen elements, tooltip, FPS"] = "déplacer les fenêtres Blizzard, des éléments d'écran, l'infobulle, FPS",
    ["hidden game options (camera, nameplates, combat text) and every CVar"] = "options cachées du jeu (caméra, barres d'info, texte de combat) et toutes les CVars",
    ["item levels on the character sheet, inspect, bags, loot and tooltips"] = "niveaux d'objet sur la fiche, l'inspection, les sacs, le butin et les infobulles",
    ["guild members on the world map and the minimap"] = "les membres de la guilde sur la carte du monde et la minicarte",
    ["export / import all the settings as one text (Settings > Profile)"] = "exporter / importer tous les réglages en un texte (Réglages > Profil)",
    ["my premade history and records"] = "historique et records de mes premades",
    ["my layer and the guild members' layers"] = "mon layer et ceux des membres de la guilde",
    ["the guild by class: class leaders, declared roles, my profile"] = "la guilde par classe : responsables, rôles déclarés, mon profil",
    ["Minotaure: guild PvP season ranking and weekly challenges"] = "Minotaure : classement JcJ de saison de la guilde et défis de la semaine",
    ["Skyborne: leylines / convergences on the map (settings, export, share)"] = "Skyborne : lignes de force / convergences sur la carte (réglages, export, partage)",
})
local HELP = {
    { "/wl", "open / close the window" },
    { "/wl help", "this list" },
    { "/wl minimap", "show / hide the minimap button" },
    { "/wl bugs", "recent Lua errors" },
    { "/wl perf", "memory and CPU used by the addon" },
    { "/wl audit", "addon traffic log of the session (on / off)" },
    { "/wl modules", "switch modules fully off (Settings > Modules)" },
    { "/wl move", "move Blizzard windows, screen elements, tooltip, FPS" },
    { "/wl cvar", "hidden game options (camera, nameplates, combat text) and every CVar" },
    { "/wl ilvl", "item levels on the character sheet, inspect, bags, loot and tooltips" },
    { "/wl map", "guild members on the world map and the minimap" },
    { "/wl layer", "my layer and the guild members' layers" },
    { "/wl classes", "the guild by class: class leaders, declared roles, my profile" },
    { "/wl profile", "export / import all the settings as one text (Settings > Profile)" },
    { "/wl reset [name]", "reset one module's saved data (no name: list them)" },
    { "/wl logdebug", "combat log auto-start debug" },
    { "/wl apply [preset]", "apply the preset: marks + groups" },
    { "/wl marks [preset]", "only the preset's marks" },
    { "/wl groups [preset]", "only the preset's groups" },
    { "/wl clear", "clear all marks" },
    { "/wl list", "list the presets" },
    { "/wl assist [preset]", "create my assist macro" },
    { "/rc", "ready check (leader / assist), else the check window" },
    { "/wl rc", "check window (ready, durability)" },
    { "/wl loot", "Loot Council (vote | add [item] | test)" },
    { "/wl sr", "soft-res tab (players whisper \"!sr [item]\")" },
    { "/wl sim", "simulator export (simc, oxm, json)" },
    { "/wl summon", "summon list" },
    { "/wl trials", "guild trials (by rank)" },
    { "/wl dashboard", "guild dashboard (item level, enchants, attendance, loots)" },
    { "/wl bank", "stock of my bank characters" },
    { "/wl craft [item]", "who can craft it in the guild (name or item link)" },
    { "/wl bg", "my premade history and records" },
    { "/wl mino", "Minotaure: guild PvP season ranking and weekly challenges" },
    { "/wl sk", "Skyborne: leylines / convergences on the map (settings, export, share)" },
    { "/wl gy", "graveyard timer test (fake waves)" },
    { "/wl pvp", "PvP frames settings" },
    { "/wl pvpcheck", "are the addon restrictions active in this battleground?" },
    { "/wl bgmsg", "last battleground messages (to copy)" },
    { "/wl preload", "load the raid modules at the loading screen (fewer freezes) on / off" },
    { "/wl caps", "battleground timers: captures, gates, queue, flag (Capping style)" },
    { "/wl danger", "warning when an enemy player or a dangerous mob is near" },
    { "/wl cc", "big icon when I am crowd controlled" },
    { "/wl duel", "big countdown for duels (start, out of the duel area)" },
    { "/wl test", "test every module switched on at once (to see and move them)" },
    { "/wl test stop", "stop the test" },
}
W.slash.help = function()
    W.Print(L("Commands (|cffffffff/wl|r = |cffffffff/wlrt|r = |cffffffff/warlegend|r, [preset] = selected preset if empty):"))
    for _, h in ipairs(HELP) do W.Print("|cffffff00" .. h[1] .. "|r - " .. L(h[2])) end
end

local function Slash(msg)
    if not W.Allowed() then W.Denied(); return end
    msg = msg or ""
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd ~= "" and cmd ~= "minimap" and not W.slash[cmd] then W.LoadRaid() end -- a raid command
    if cmd == "" then
        W.Toggle()
    elseif cmd == "minimap" then
        local m = W.DB("minimap")
        m.hide = not m.hide
        W.UpdateMinimap()
    elseif W.slash[cmd] then
        W.slash[cmd](rest)
    else
        W.slash.help()
    end
end
SLASH_WARLEGENDRT1 = "/wl"
SLASH_WARLEGENDRT2 = "/wlrt"
SLASH_WARLEGENDRT3 = "/warlegend"
SlashCmdList["WARLEGENDRT"] = Slash

-- Another addon that also answers "/wl" (WoWHead Looter: /wl loc, /wl id, /wl reset): the game gives "/wl" to one
-- of the two handlers, not the one we choose. So once every addon is loaded, both entries of SlashCmdList get the
-- same dispatcher: our commands go to Slash, everything else (and everything, for a player outside the guild) to
-- the other addon's own handler, left untouched. /wl reset <name> is ours only when <name> is one of our saved
-- data keys; a bare /wl reset is the other addon's.
W.AddFR({
    ["/wl is shared with another addon (%s): both keep working, |cffffffff/wlrt|r always opens WaR LegenD."] =
        "/wl est partagé avec un autre addon (%s) : les deux fonctionnent, |cffffffff/wlrt|r ouvre toujours WaR LegenD.",
})
local function ClaimSlash()
    local others = {}
    for key, fn in pairs(SlashCmdList) do
        if key ~= "WARLEGENDRT" and type(fn) == "function" then
            for i = 1, 20 do
                local c = _G["SLASH_" .. key .. i]
                if type(c) ~= "string" then break end
                if c:lower() == "/wl" then others[#others + 1] = key; break end
            end
        end
    end
    if #others == 0 then return end
    table.sort(others)
    local otherName = others[1]
    local other = SlashCmdList[otherName]
    local known, noticed = {}, false
    for _, h in ipairs(HELP) do
        local c = h[1]:match("^/wl%s+(%S+)")
        if c then known[c:lower()] = true end
    end
    local function Dispatcher(msg)
        msg = msg or ""
        local cmd, rest = msg:match("^(%S*)%s*(.-)$")
        cmd = (cmd or ""):lower()
        local mine = cmd == "" or cmd == "minimap" or known[cmd] or W.slash[cmd] or false
        if mine and cmd == "reset" then
            local key = (rest or ""):match("^(%S+)")
            mine = key ~= nil and type(W.db[key]) == "table"
        end
        if not mine or not W.Allowed() then return other(msg) end
        if not noticed then
            noticed = true
            W.Print(string.format(L("/wl is shared with another addon (%s): both keep working, |cffffffff/wlrt|r always opens WaR LegenD."), otherName))
        end
        Slash(msg)
    end
    SlashCmdList["WARLEGENDRT"] = Dispatcher
    for _, key in ipairs(others) do SlashCmdList[key] = Dispatcher end
end
W.On("PLAYER_LOGIN", ClaimSlash, true)

-- /rc exists before the raid addon is loaded; its real handler (ReadyCheck.lua) replaces this one
SLASH_WLRTREADYCHECK1 = "/rc"
local ReadyCheckStub
function ReadyCheckStub()
    if not W.Allowed() then W.Denied(); return end
    W.LoadRaid()
    local real = SlashCmdList["WLRTREADYCHECK"]
    if real and real ~= ReadyCheckStub then real() end
end
SlashCmdList["WLRTREADYCHECK"] = ReadyCheckStub

W.On("PLAYER_LOGIN", function()
    CreateMinimapButton()
    W.Print(W.LOGO .. " RaidTool v" .. W.version .. L(" loaded. |cffffffff/wl|r to open."))
end)
