-- WarLegend RaidTool - Raid Cooldowns
-- Who has battle rez, Soulstone, Innervate, Divine Intervention, tank cooldowns... ready, and for how long not.
-- No combat log: every WarLegend user reports their own casts (UNIT_SPELLCAST_SUCCEEDED, player only)
-- and, when asked, which of these spells they know. Players without the addon show "?" (class only).
-- Cost: one table lookup per spell I cast while in a group; the window redraws once per second only
-- while one of its cooldowns is running. Nothing in battlegrounds / arenas.
local W = WLRT
W.AddFR({
    ["Raid Cooldowns"] = "CD de raid",
    ["Share my cooldowns with the group"] = "Partager mes CD avec le groupe",
    ["Show the cooldown window"] = "Afficher la fenêtre des CD",
    ["Raids only"] = "En raid uniquement",
    ["Lock the window"] = "Verrouiller la fenêtre",
    ["Spells shown:"] = "Sorts affichés :",
    ["Ask the group"] = "Demander au groupe",
    ["Reset position"] = "Réinitialiser la position",
    ["Players without WaR LegenD show \"?\": only their class is known, not their cooldown."] =
        "Les joueurs sans WaR LegenD affichent « ? » : seule leur classe est connue, pas leur CD.",
    ["Cooldowns are read on the caster's client (talents included) and sent to the group."] =
        "Les CD sont lus chez le lanceur (talents compris) et envoyés au groupe.",
})
local L = W.L

-- v2: cooldown ends travel as server time (GetServerTime), so a message held back by a lockdown
-- (boss encounter) is still right when it arrives; identities are full names
local PREFIX = "WLRT_CD2"
-- key, class, base cooldown (s), spell IDs (every rank, lowest first); talent = only shown when reported.
-- IDs, ranks and cooldowns checked on wowhead.com/forever (Oct 2026). The base cooldown is only a
-- fallback: the caster's client sends the real one (talents included).
local SPELLS = {
    { key = "rebirth", class = "DRUID", cd = 1800, ids = { 20484, 20739, 20742, 20747, 20748 } },
    { key = "soulstone", class = "WARLOCK", cd = 1800, ids = { 20707, 20762, 20763, 20764, 20765 },
        items = { 5232, 16892, 16893, 16895, 16896 } },
    { key = "reinc", class = "SHAMAN", cd = 3600, ids = { 20608 }, reagent = 17030 }, -- needs an Ankh
    { key = "di", class = "PALADIN", cd = 3600, ids = { 19752 } },
    { key = "innervate", class = "DRUID", cd = 360, ids = { 29166 } },
    { key = "tranq", class = "DRUID", cd = 300, ids = { 740, 8918, 9862, 9863 } },
    { key = "manatide", class = "SHAMAN", cd = 300, ids = { 16190, 17354, 17359 }, talent = true },
    { key = "pi", class = "PRIEST", cd = 180, ids = { 10060 }, talent = true },
    { key = "shieldwall", class = "WARRIOR", cd = 900, ids = { 871 } },
    { key = "laststand", class = "WARRIOR", cd = 180, ids = { 12975 }, talent = true },
    { key = "cshout", class = "WARRIOR", cd = 600, ids = { 1161 } },
    { key = "croar", class = "DRUID", cd = 600, ids = { 5209 } },
    { key = "loh", class = "PALADIN", cd = 1200, ids = { 633, 2800, 10310 } },
    { key = "bop", class = "PALADIN", cd = 300, ids = { 1022, 5599, 10278 } },
    { key = "tranqshot", class = "HUNTER", cd = 20, ids = { 19801 }, off = true },
}
local byKey, bySpell = {}, {}
for _, e in ipairs(SPELLS) do
    byKey[e.key] = e
    for _, id in ipairs(e.ids) do bySpell[id] = e end
end
local GetTex = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
local GetItemCD = (C_Container and C_Container.GetItemCooldown) or GetItemCooldown
local GetCount = (C_Item and C_Item.GetItemCount) or GetItemCount

local db
local state = {}   -- name -> { addon = true, [key] = end time (0 = ready) }
local members = {} -- { name, class } in roster order
local UI = {}

local function Me() return W.UnitKey("player") or "?" end -- my key (full identity)
-- local end time <-> server time (shared by every client, unlike GetTime)
local function ToServer(localEnd) return math.floor(GetServerTime() + (localEnd - GetTime()) + 0.5) end
-- a received end time is kept within one day of now: nothing absurd reaches the window
local function FromServer(serverEnd)
    local left = (W.Finite(serverEnd) or 0) - GetServerTime()
    return GetTime() + math.max(-86400, math.min(86400, left))
end

---------------------------------------------------------------------------
-- My own spells
---------------------------------------------------------------------------
local function SpellCD(id)
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(id)
        if not info then return 0, 0 end
        return W.Safe(info.startTime) or 0, W.Safe(info.duration) or 0
    end
    if GetSpellCooldown then
        local s, d = GetSpellCooldown(id)
        return W.Safe(s) or 0, W.Safe(d) or 0
    end
    return 0, 0
end

-- Seconds left on a cooldown read from the game (ignores the global cooldown), else nil
local function Left(start, duration)
    if start and duration and start > 0 and duration > 2 then return math.max(0, start + duration - GetTime()) end
end

local function ItemLeft(items)
    if not GetItemCD then return nil end
    local best
    for _, id in ipairs(items) do
        local s, d = GetItemCD(id)
        local left = Left(W.Safe(s), W.Safe(d))
        if left and (not best or left > best) then best = left end
    end
    return best
end

-- true when one of these items is in my bags (nil: the client cannot tell)
local function HasItem(ids)
    if not GetCount then return nil end
    for _, id in ipairs(ids) do
        if (W.Safe(GetCount(id)) or 0) > 0 then return true end
    end
    return false
end

local function KnownRank(e)
    for i = #e.ids, 1, -1 do
        local id = e.ids[i]
        if (IsPlayerSpell and IsPlayerSpell(id)) or (IsSpellKnown and IsSpellKnown(id)) then return id end
    end
end

-- "key:secondsLeft,..." for every tracked spell I know
local function KnownList()
    local _, myClass = UnitClass("player")
    local parts, mine = {}, { addon = true }
    local old, now = state[Me()], GetTime()
    for _, e in ipairs(SPELLS) do
        local left
        if e.items then
            if myClass == e.class then
                left = ItemLeft(e.items)
                if not left then
                    -- ready only with a stone in my bags; a stone used a moment ago keeps its running end
                    if HasItem(e.items) ~= false then left = 0
                    elseif old and old[e.key] and old[e.key] > now then left = old[e.key] - now end
                end
            end
        else
            local id = KnownRank(e)
            if id then left = Left(SpellCD(id)) or 0 end
        end
        -- a spell that needs a reagent (Ankh) is not ready without it
        if left == 0 and e.reagent and HasItem({ e.reagent }) == false then left = nil end
        if left then
            parts[#parts + 1] = e.key .. ":" .. (left > 0 and ToServer(GetTime() + left) or 0)
            mine[e.key] = left > 0 and GetTime() + left or 0
        end
    end
    state[Me()] = mine
    return table.concat(parts, ",")
end

local lastKnown, lastQ = 0, 0
local function SendKnown()
    -- "Share my cooldowns" off: nothing is sent (else the others would see me ready forever)
    if not (db and db.share) or not W.InGroup() or W.InPvP() or GetTime() - lastKnown < 5 then return end
    lastKnown = GetTime()
    W.Queue(PREFIX, W.Pack("K", KnownList())) -- queued: held through a lockdown, sent after
end

local lastAsk = 0
local function Ask(force)
    if not W.InGroup() or W.InPvP() or (not force and GetTime() - lastAsk < 20) then return end
    lastAsk = GetTime()
    W.Queue(PREFIX, "Q")
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local win, ticker
local lines = {}

local function Short(secs)
    secs = math.floor(secs)
    if secs >= 600 then return math.ceil(secs / 60) .. "m" end
    return string.format("%d:%02d", math.floor(secs / 60), secs % 60)
end

local function Line(i)
    local fs = lines[i]
    if not fs then
        fs = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", 4, -18 - (i - 1) * 15)
        fs:SetWidth(292)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        lines[i] = fs
    end
    return fs
end

local Redraw
local function SetTicking(on)
    if on and not ticker and C_Timer and C_Timer.NewTicker then
        ticker = C_Timer.NewTicker(1, function() Redraw() end)
    elseif not on and ticker then
        ticker:Cancel()
        ticker = nil
    end
end

function Redraw()
    if not win or not win:IsShown() then SetTicking(false); return end
    local now, n, running = GetTime(), 0, false
    for _, e in ipairs(SPELLS) do
        if db.spells[e.key] then
            local parts
            for _, m in ipairs(members) do
                if m.class == e.class then
                    local st = state[m.key]
                    local text
                    if st then
                        local v = st[e.key]
                        if v and v > now then
                            running = true
                            text = "|cff777777" .. m.name .. " " .. Short(v - now) .. "|r"
                        elseif v then
                            text = W.ColorName(m.name, m.class)
                        end
                    elseif not e.talent then
                        text = W.ColorName(m.name, m.class) .. "|cff999999?|r"
                    end
                    if text then parts = parts or {}; parts[#parts + 1] = text end
                end
            end
            if parts then
                n = n + 1
                Line(n):SetText("|T" .. (e.icon or 134400) .. ":14|t " .. table.concat(parts, "  "))
                Line(n):Show()
            end
        end
    end
    for i = n + 1, #lines do lines[i]:Hide() end
    win:SetHeight(22 + math.max(n, 1) * 15)
    SetTicking(running)
end

local function RebuildMembers()
    wipe(members)
    local seen = {}
    for _, u in ipairs(W.GroupUnits()) do
        local key, name, class = W.UnitKey(u), W.UnitDisplayName(u), W.UnitClassToken(u)
        if key and name and class then
            members[#members + 1] = { key = key, name = name, class = class }
            seen[key] = true
        end
    end
    for key in pairs(state) do if not seen[key] then state[key] = nil end end
end

local function WindowWanted()
    return db and db.window and W.Allowed() and W.InGroup() and (W.InRaid() or not db.raidOnly) and not W.InPvP()
end

local function UpdateWindow()
    if not win then return end
    local want = WindowWanted()
    win:SetShown(want)
    win:EnableMouse(not db.locked)
    win.bg:SetShown(not db.locked)
    if want then
        RebuildMembers()
        if not state[Me()] then KnownList() end -- my own line without waiting for a message
        Redraw()
    else
        SetTicking(false)
    end
end

local function BuildWindow()
    win = CreateFrame("Frame", "WLRTRaidCooldowns", UIParent)
    win:SetSize(300, 40)
    win:SetPoint(db.point or "LEFT", UIParent, db.relPoint or "LEFT", db.x or 20, db.y or 120)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", function(self) if not db.locked then self:StartMoving() end end)
    win:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint(1)
        db.point, db.relPoint, db.x, db.y = p, rp, x, y
    end)
    win.bg = win:CreateTexture(nil, "BACKGROUND")
    win.bg:SetAllPoints()
    W.SetColor(win.bg, 0, 0, 0, 0.45)
    local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", 4, -3)
    title:SetText(W.Upper(L("Raid Cooldowns")))
    title:SetTextColor(W.R, W.G, W.B)
    win:SetScale(db.scale or 1)
    win:Hide()
end

---------------------------------------------------------------------------
-- Casting and messages
---------------------------------------------------------------------------
local castFrame = CreateFrame("Frame")
local listening = false
local function Listen()
    local want = db and db.share and W.Allowed() and W.InGroup() and not W.InPvP()
    if want == listening then return end
    listening = want
    if want then castFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    else castFrame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED") end
end

-- 40 answers to one question come in a few seconds: the window is drawn again once per 0.2 s at most
local RedrawSoon = W.Coalesce(0.2, function() if win and win:IsShown() then Redraw() end end)

castFrame:SetScript("OnEvent", function(_, _, _, _, spellID)
    if W.IsOff("RaidCooldowns") then return end -- switched off in Settings > Modules
    local id = W.Safe(spellID)
    local e = id and bySpell[id]
    if not e then return end
    -- the cooldown starts right after the cast: read the real one (talents), else the base value
    W.After(0.3, function()
        local left = (e.items and ItemLeft(e.items)) or Left(SpellCD(id)) or e.cd
        local mine = state[Me()] or { addon = true }
        mine[e.key] = GetTime() + left
        state[Me()] = mine
        W.Queue(PREFIX, W.Pack("C", e.key, ToServer(mine[e.key])))
        if win and win:IsShown() then Redraw() end
    end)
end)

W.OnAddon(PREFIX, function(msg, from, _, full)
    if W.InPvP() then return end
    -- the sender's key comes from its unit: the same key as its line in the window
    local unit = W.UnitByName(full or from)
    if not unit or W.UnitIsMe(unit) then return end -- group members only, not me
    local who = W.UnitKey(unit)
    local t = W.Unpack(msg)
    if t[1] == "Q" then
        if GetTime() - lastKnown < 5 or GetTime() - lastQ < 3 then return end -- one timer per burst of questions
        lastQ = GetTime()
        W.After(0.5 + math.random() * 2.5, SendKnown)
        return
    end
    local st = state[who]
    if t[1] == "K" then
        st = { addon = true }
        for key, serverEnd in (t[2] or ""):gmatch("(%w+):(%d+)") do
            if byKey[key] then
                serverEnd = W.Finite(serverEnd, 0) or 0
                st[key] = serverEnd > 0 and FromServer(serverEnd) or 0
            end
        end
        state[who] = st
    elseif t[1] == "C" and byKey[t[2]] then
        st = st or { addon = true }
        local serverEnd = W.Finite(t[3], 0)
        st[t[2]] = serverEnd and FromServer(serverEnd) or (GetTime() + byKey[t[2]].cd)
        state[who] = st
    else
        return
    end
    RedrawSoon()
end)

local wasInGroup = false
W.OnRoster(function()
    local inGroup = W.InGroup()
    if inGroup and not wasInGroup then SendKnown() end -- just joined: tell the others
    if not inGroup then wipe(state) end
    wasInGroup = inGroup
    Listen()
    UpdateWindow()
end)
-- this file is loaded on demand: Core replays its first PLAYER_ENTERING_WORLD with isLogin = false,
-- so the first one seen here counts as the login / reload (the group knows nothing about me yet)
local firstEnter = true
W.On("PLAYER_ENTERING_WORLD", function(isLogin, isReload)
    local fresh = isLogin or isReload or firstEnter
    firstEnter = false
    wasInGroup = W.InGroup()
    Listen()
    UpdateWindow()
    -- a loading screen changes nothing for the others: tell them only after a login / reload
    if fresh and wasInGroup and not W.InPvP() then
        W.After(3, function() SendKnown(); if db.window then Ask() end end)
    end
end)

W.OnReady(function()
    db = W.DB("raidCooldowns", { share = true, window = false, raidOnly = true, locked = false, scale = 1 })
    if type(db.spells) ~= "table" then
        db.spells = {}
        for _, e in ipairs(SPELLS) do db.spells[e.key] = not e.off end
    end
    BuildWindow()
end)

W.On("PLAYER_LOGIN", function()
    for _, e in ipairs(SPELLS) do
        e.name = W.SpellName(e.ids[#e.ids]) or e.key
        e.icon = GetTex and GetTex(e.ids[#e.ids]) or nil
    end
end)

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
W.RegisterModule("RaidCooldowns", L("Raid Cooldowns"), function(p)
    W.Title(p, L("Raid Cooldowns"))
    local function opt(key, text, y)
        W.Check(p, text, function() return db[key] end, function(v)
            db[key] = v
            Listen()
            UpdateWindow()
            if key == "window" and v then Ask(true) end
        end):SetPoint("TOPLEFT", 12, y)
    end
    opt("share", L("Share my cooldowns with the group"), -40)
    opt("window", L("Show the cooldown window"), -64)
    opt("raidOnly", L("Raids only"), -88)
    opt("locked", L("Lock the window"), -112)

    local head = W.Label(p, L("Spells shown:"), "GameFontNormal")
    head:SetPoint("TOPLEFT", 14, -146)
    for i, e in ipairs(SPELLS) do
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        local c = W.Check(p, "", function() return db.spells[e.key] end, function(v) db.spells[e.key] = v; Redraw() end)
        c:SetPoint("TOPLEFT", 12 + col * 230, -164 - row * 24)
        c:HookScript("OnShow", function(self)
            local r, g, b = W.ClassColor(e.class)
            self.label:SetText("|T" .. (e.icon or 134400) .. ":14|t " .. (e.name or e.key))
            self.label:SetTextColor(r, g, b)
        end)
    end

    W.Button(p, L("Ask the group"), 150, 22, function() Ask(true) end):SetPoint("TOPLEFT", 16, -296)
    W.Button(p, L("Size -"), 80, 22, function()
        db.scale = math.max(0.6, (db.scale or 1) - 0.1); win:SetScale(db.scale)
    end):SetPoint("TOPLEFT", 172, -296)
    W.Button(p, L("Size +"), 80, 22, function()
        db.scale = math.min(2, (db.scale or 1) + 0.1); win:SetScale(db.scale)
    end):SetPoint("TOPLEFT", 258, -296)
    W.Button(p, L("Reset position"), 162, 22, function()
        db.point, db.relPoint, db.x, db.y = nil, nil, nil, nil
        win:ClearAllPoints()
        win:SetPoint("LEFT", UIParent, "LEFT", 20, 120)
    end):SetPoint("TOPLEFT", 344, -296)

    local info = W.Label(p, L("Players without WaR LegenD show \"?\": only their class is known, not their cooldown.") .. "\n"
        .. L("Cooldowns are read on the caster's client (talents included) and sent to the group."), "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, -332)
    info:SetWidth(640)
    info:SetTextColor(0.7, 0.7, 0.7)
end, function() UpdateWindow() end)
