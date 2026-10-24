-- WarLegend RaidTool - shared helpers for the bigger modules
-- Throttled addon messages (long texts split in chunks), sub-tabs, multiline box,
-- confirm popup, cycle button, item helpers, shift-click links into our edit boxes.
local W = WLRT
local L = W.L

W.AddFR({
    ["Yes"] = "Oui",
    ["No"] = "Non",
    ["Cancel"] = "Annuler",
    ["%dd"] = "%dj",
    ["%dh"] = "%dh",
    ["now"] = "maintenant",
})

---------------------------------------------------------------------------
-- Send queue: one addon message every 0.25 s, retried when the client throttles
---------------------------------------------------------------------------
local queue, pumping = {}, false
-- a message the client keeps refusing (throttle, lockdown during a long boss fight) is given up after this
local MAX_WAIT, MAX_QUEUE = 300, 150
W.AddFR({
    ["Voice: auto"] = "Voix : auto",
    ["Beep"] = "Bip",
    ["not in guild"] = "hors guilde",
    ["From %s"] = "De %s",
    ["Some messages could not be sent to the group (chat locked or throttled for too long)."] =
        "Des messages n'ont pas pu être envoyés au groupe (chat verrouillé ou bridé trop longtemps).",
})

-- Delivers a message to ourselves when we are alone (tests / solo), like the game does in a group
local function Loopback(prefix, msg)
    local fn = W.AddonHandler(prefix)
    if fn then W.After(0, function() fn(msg, UnitName("player"), "LOCAL") end) end
end

local warnedAt = 0
local function Pump()
    local item = queue[1]
    if not item then pumping = false; return end
    local res
    if item.channel == "LOCAL" then
        Loopback(item.prefix, item.msg)
        res = "sent"
    else
        res = W.SendRaw(item.prefix, item.msg, item.channel, item.target)
    end
    -- Forever locks addon chat for a whole boss encounter (can last more than MAX_WAIT): that time
    -- does not count, only a throttle that never ends does
    if res == "locked" then item.at = GetTime() end
    if (res == "throttle" or res == "locked") and GetTime() - item.at < MAX_WAIT then
        -- kept in the queue: throttle passes in a moment, a lockdown at the end of the encounter
        W.After(res == "locked" and 3 or 1, Pump)
        return
    end
    table.remove(queue, 1)
    if res ~= "sent" and res ~= "failed" and GetTime() - warnedAt > 60 then
        warnedAt = GetTime()
        W.Print(L("Some messages could not be sent to the group (chat locked or throttled for too long)."))
    end
    W.After(0.25, Pump)
end

-- channel nil = raid/party; "LOCAL" when alone. Messages leave one every 0.25 s, in order.
function W.Queue(prefix, msg, channel, target)
    channel = channel or W.Channel() or "LOCAL"
    if #queue >= MAX_QUEUE then -- long lockdown: the oldest goes, memory stays small, said once a minute
        table.remove(queue, 1)
        if GetTime() - warnedAt > 60 then
            warnedAt = GetTime()
            W.Print(L("Some messages could not be sent to the group (chat locked or throttled for too long)."))
        end
    end
    queue[#queue + 1] = { prefix = prefix, msg = msg, channel = channel, target = target, at = GetTime() }
    if not pumping then pumping = true; Pump() end
    return true
end

-- Numbers read from a received message: nil when not a finite number, else clamped to min..max.
-- W.Int also drops the decimals. Every addon-message handler runs its numbers through these.
function W.Finite(v, min, max)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    if min and n < min then n = min end
    if max and n > max then n = max end
    return n
end
function W.Int(v, min, max)
    local n = W.Finite(v, min, max)
    return n and math.floor(n) or nil
end

-- Search boxes: fn runs once typing pauses for delay seconds, not on every key (big tables rebuilt once)
function W.Debounce(delay, fn)
    local gen = 0
    return function()
        gen = gen + 1
        local mine = gen
        W.After(delay, function() if mine == gen then fn() end end)
    end
end

-- Long text: split into chunks "id:i:n:chunk", rebuilt by W.OnAddonLong
local CHUNK = 220
local longId = 0
function W.SendLong(prefix, text, channel, target)
    longId = (longId + 1) % 1000
    text = text:gsub("~", "~1"):gsub("\n", "~2"):gsub("|", "~3") -- no raw newlines / pipes in addon messages
    local n = math.max(1, math.ceil(#text / CHUNK))
    local id = tostring(math.random(100, 999)) .. longId
    for i = 1, n do
        W.Queue(prefix, id .. ":" .. i .. ":" .. n .. ":" .. text:sub((i - 1) * CHUNK + 1, i * CHUNK), channel, target)
    end
end

local PARTS_TTL = 60 -- an incomplete message (lost chunk, sender left) is dropped after this
local MAX_CHUNKS = 64 -- 14 KB: far above a raid note or a profession list, refuses absurd senders
function W.OnAddonLong(prefix, fn)
    local parts = {}
    W.OnAddon(prefix, function(msg, from, channel, full)
        local id, i, n, chunk = msg:match("^(%d+):(%d+):(%d+):(.*)$")
        if not id then return end
        i, n = tonumber(i), tonumber(n)
        if not i or not n or n < 1 or n > MAX_CHUNKS or i < 1 or i > n then return end
        local key = (full or from) .. id
        if parts[key] and parts[key].n ~= n then return end -- chunks of one message all say the same count
        local p = parts[key]
        if not p then
            local now = GetTime()
            for k, old in pairs(parts) do
                if now - old.at > PARTS_TTL then parts[k] = nil end
            end
            p = { n = n, got = 0, at = now }
            parts[key] = p
        end
        if not p[i] then p[i] = chunk; p.got = p.got + 1 end
        if p.got >= p.n then
            parts[key] = nil
            local text = table.concat(p, "", 1, p.n):gsub("~3", "|"):gsub("~2", "\n"):gsub("~1", "~")
            fn(text, from, channel, full)
        end
    end, 3) -- the module that called W.OnAddonLong owns the prefix (Settings > Modules)
end

-- Names typed by the player: comma / semicolon / line separated. On WoW: Forever a name holds a
-- space ("First Surname"), so spaces only separate names on the other clients.
function W.NameList(text)
    local out = {}
    for token in (text or ""):gmatch(W.FOREVER and "[^,;\n]+" or "[^,;%s]+") do
        token = W.SanitizeName(token)
        if token ~= "" then out[#out + 1] = token end
    end
    return out
end

-- One CSV line: a field with a comma, a quote or a line break is quoted (inner quotes doubled)
function W.CSV(...)
    local out = {}
    for i = 1, select("#", ...) do
        local v = tostring((select(i, ...)) or "")
        if v:find('[,"\n]') then v = '"' .. v:gsub('"', '""') .. '"' end
        out[i] = v
    end
    return table.concat(out, ",")
end

-- Free text from another player, shown as plain text: "|" is doubled (no color, texture or link escape
-- works), control characters go, length is cut. Use it on every received string that is displayed or saved.
function W.Plain(s, max)
    if type(s) ~= "string" then return "" end
    if max and #s > max then s = s:sub(1, max) end -- cut first: a cut after doubling could leave one "|"
    s = s:gsub("[%z\1-\31]", " "):gsub("|", "||")
    return s
end

-- The sender of a received prompt, as shown to me: plain name, flagged when not in my guild
function W.Sender(from, full)
    local name = W.Plain(from, 40)
    if W.GuildMember(full or from) then return name end
    return name .. " |cffff8040(" .. L("not in guild") .. ")|r"
end

-- Fields separated by "^" (never used in names, links are sent as item strings)
function W.Pack(...)
    local t = { ... }
    for i = 1, select("#", ...) do t[i] = tostring(t[i] == nil and "" or t[i]):gsub("%^", "") end
    return table.concat(t, "^")
end

function W.Unpack(msg)
    local t = {}
    for v in (msg .. "^"):gmatch("([^%^]*)%^") do t[#t + 1] = v end
    return t
end

---------------------------------------------------------------------------
-- Items
---------------------------------------------------------------------------
function W.ItemString(link)
    if type(link) ~= "string" then return nil end
    return link:match("item:[%-%d:]+")
end

function W.ItemID(link)
    if type(link) == "number" then return link end
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("item:(%d+)") or link:match("^(%d+)$"))
end

-- Full link (or a readable placeholder while the item is not cached)
function W.ItemLink(str)
    if not str then return "?" end
    local _, link = W.GetItemInfo(str)
    if link then return link end
    local id = W.ItemID(str)
    if id and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    return "[item:" .. tostring(id) .. "]"
end

function W.ItemIcon(str)
    if not str then return 134400 end
    local _, _, _, _, icon = W.GetItemInfoInstant(str)
    return icon or 134400
end

function W.ItemQuality(str)
    local _, _, q = W.GetItemInfo(str)
    if q then return q end
    if C_Item and C_Item.GetItemQualityByID then return C_Item.GetItemQualityByID(str) end
end

function W.ItemCount(id)
    if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(id, false, false, true) or 0 end
    return GetItemCount and GetItemCount(id) or 0
end

-- Item from an ID, a link or a name (bags / cache)
function W.ParseItem(text)
    text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return nil end
    local id = W.ItemID(text)
    if id then return id end
    local _, link = W.GetItemInfo(text)
    return link and W.ItemID(link)
end

---------------------------------------------------------------------------
-- Misc
---------------------------------------------------------------------------
function W.Ago(t)
    if not t then return "-" end
    local s = time() - t
    if s < 3600 then return L("now") end
    if s < 86400 then return string.format(L("%dh"), math.floor(s / 3600)) end
    return string.format(L("%dd"), math.floor(s / 86400))
end

function W.ColorName(name, class)
    local r, g, b = W.ClassColor(class)
    return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, name or "?")
end

-- Group member by name -> unit, class
-- A full name ("Name-Realm", Forever "First Surname") matches that exact character. A short name
-- (display input), or a full name whose other side has no surname / realm (client formats differ),
-- matches on the short name, and only if nobody else in the group has it.
function W.UnitByName(name)
    if not name then return nil end
    local wantFull = W.HasFullPart(name) and W.FullName(name):lower()
    local low = W.BaseName(name):lower()
    local loose, looseCount = nil, 0
    local function check(u)
        if wantFull then
            local f = W.UnitFullName(u)
            if f and f:lower() == wantFull then return true end
            if f and W.HasFullPart(f) then return false end -- both sides complete and different
        end
        local n = W.Safe(UnitName(u))
        if n and n:lower() == low then loose, looseCount = u, looseCount + 1 end
        return false
    end
    local raid = W.InRaid()
    local units = raid and W.RAID_UNITS or W.PARTY_UNITS
    for i = 1, raid and W.NumRaid() or 4 do
        local u = units[i]
        if UnitExists(u) and check(u) then return u, W.UnitClassToken(u) end
    end
    if not raid and check("player") then return "player", W.UnitClassToken("player") end
    if looseCount == 1 then return loose, W.UnitClassToken(loose) end
end

-- true when a sender is me. Pass the full sender name when there is one: a bare first name
-- cannot tell me from another "Arthur" (it then only matches my own first name).
function W.IsMe(name)
    if not name or name == "" then return false end
    local f = W.FullName(name) -- "First-Surname" and "First Surname" alike
    if W.HasFullPart(f) then return f:lower() == W.UnitKey("player") end
    return name == W.Safe(UnitName("player"))
end

-- UnitIsUnit can answer a hidden (secret) boolean in restricted instances: never test it as is
function W.SameUnit(a, b)
    return a ~= nil and b ~= nil and W.Safe(UnitIsUnit(a, b)) == true
end
function W.UnitIsMe(unit) return unit == "player" or W.SameUnit(unit, "player") end

-- Forever keeps these in C_PartyInfo; the old globals only exist through Blizzard's deprecation shims
function W.Uninvite(name)
    if C_PartyInfo and C_PartyInfo.UninviteUnit then C_PartyInfo.UninviteUnit(name)
    elseif UninviteUnit then UninviteUnit(name) end
end

function W.GuildInfo(name) return W.GuildMember(name) end

-- Leader / assistant check for messages that change shared things
-- channel: where the message came from. Alone, only my own local test messages ("LOCAL") count as a
-- leader: a guild member's GUILD / WHISPER message must not pass as one.
function W.IsGroupLead(name, channel)
    if not W.InGroup() then return channel == "LOCAL" end
    local unit = W.UnitByName(name)
    if not unit then return false end
    if UnitIsGroupLeader and UnitIsGroupLeader(unit) then return true end
    return UnitIsGroupAssistant and UnitIsGroupAssistant(unit) and true or false
end

---------------------------------------------------------------------------
-- Aura reads. WoW: Forever raises an ERROR (not a hidden value) when an addon reads a secret aura:
-- combat / boss / PvP restrictions, or a spell flagged always secret. The client is asked first
-- (C_Secrets), and a pcall catches what it did not announce.
---------------------------------------------------------------------------
local AuraAt = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
local AuraOf = C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID
local IndexSecret = C_Secrets and C_Secrets.ShouldUnitAuraIndexBeSecret
local InstanceSecret = C_Secrets and C_Secrets.ShouldUnitAuraInstanceBeSecret

-- anything but a plain false (true, or a hidden answer) counts as secret
local function ReadAt(unit, i, filter)
    if IndexSecret and IndexSecret(unit, i, filter) ~= false then return false end
    return AuraAt(unit, i, filter)
end
local function ReadOf(unit, iid)
    if InstanceSecret and InstanceSecret(unit, iid) ~= false then return false end
    return AuraOf(unit, iid)
end

W.HAS_AURA_API = AuraAt ~= nil

-- The aura, false when it cannot be read (more may follow: keep looking), nil after the last one
function W.AuraByIndex(unit, i, filter)
    if not AuraAt then return nil end
    local ok, a = pcall(ReadAt, unit, i, filter)
    if not ok then return false end
    return a
end

-- The aura, false when it cannot be read, nil when it is gone
function W.AuraByInstance(unit, iid)
    if not AuraOf then return nil end
    local ok, a = pcall(ReadOf, unit, iid)
    if not ok then return false end
    return a
end

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------
-- Tabs inside a module panel. Returns { frames = {...}, Select(i) }
function W.SubTabs(parent, labels, onSelect, top)
    top = top or -34
    local tabs = { frames = {}, buttons = {} }
    local x = 12
    for i, text in ipairs(labels) do
        local w = math.max(80, #text * 7 + 20)
        local b = W.Button(parent, text, w, 22, function() tabs:Select(i) end)
        b:SetPoint("TOPLEFT", x, top)
        x = x + w + 4
        tabs.buttons[i] = b
        local f = CreateFrame("Frame", nil, parent)
        f:SetPoint("TOPLEFT", 0, top - 28)
        f:SetPoint("BOTTOMRIGHT", 0, 0)
        f:Hide()
        f.subTabs, f.subTabIndex = tabs, i -- the search box opens the sub-tab holding an option
        tabs.frames[i] = f
    end
    function tabs:Select(i)
        self.current = i
        for k, f in ipairs(self.frames) do
            f:SetShown(k == i)
            W.SetSelected(self.buttons[k], k == i)
        end
        if onSelect then onSelect(i, self.frames[i]) end
    end
    return tabs
end

-- Multiline edit box in a scroll frame
function W.MultiEdit(parent, w, h, maxLetters)
    local bg = CreateFrame("Frame", nil, parent, W.BT)
    W.Size(bg, w, h)
    W.Backdrop(bg, 0.9)
    local sf = CreateFrame("ScrollFrame", W.N("MEdit"), bg, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 6, -6)
    sf:SetPoint("BOTTOMRIGHT", -26, 6)
    W.SkinScroll(sf)
    local box = CreateFrame("EditBox", nil, sf)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject("ChatFontNormal")
    box:SetWidth(w - 36)
    box:SetHeight(h - 12)
    box:SetMaxLetters(maxLetters or 0)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    sf:SetScrollChild(box)
    bg:EnableMouse(true)
    bg:SetScript("OnMouseDown", function() box:SetFocus() end)
    bg.box = box
    W.LinkTarget(box)
    return bg, box
end

-- Shift-click an item while one of our boxes has the focus: the link goes in the box
local linkTargets = {}
function W.LinkTarget(box) linkTargets[#linkTargets + 1] = box end
if hooksecurefunc then
    local function Insert(link)
        for _, box in ipairs(linkTargets) do
            if box:HasFocus() then box:Insert(link); return true end
        end
    end
    if ChatEdit_InsertLink then hooksecurefunc("ChatEdit_InsertLink", Insert) end
end

-- Drop-down menu of values: values = { {value, text}, ... }. The game's MenuUtil, like the Guild >
-- Professions filter; on a client without it, a click goes to the next value.
function W.Cycle(parent, w, values, get, set, tip)
    local b
    -- the saved value, or the first one when it is not in the list (it is the one shown)
    local function Current()
        local cur = get()
        for _, v in ipairs(values) do if v[1] == cur then return cur end end
        return values[1] and values[1][1]
    end
    local function Text()
        local cur = Current()
        for _, v in ipairs(values) do if v[1] == cur then return v[2] end end
        return "?"
    end
    local function Choose(value)
        set(value)
        b:SetText(Text())
    end
    b = W.Button(parent, "", w, 22, function(self)
        if #values == 0 then return end -- a list filled later (wowaudit encounters) may still be empty
        if MenuUtil and MenuUtil.CreateContextMenu then
            MenuUtil.CreateContextMenu(self, function(_, root)
                for _, v in ipairs(values) do
                    root:CreateRadio(v[2], function() return Current() == v[1] end, function() Choose(v[1]) end)
                end
            end)
            return
        end
        local cur, idx = Current(), 0
        for i, v in ipairs(values) do if v[1] == cur then idx = i end end
        Choose(values[(idx % #values) + 1][1])
    end, tip)
    local arrow = b:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    W.Size(arrow, 12, 12)
    arrow:SetPoint("RIGHT", -6, -3)
    b:SetText(Text())
    b:HookScript("OnShow", function() b:SetText(Text()) end)
    b.Sync = function() b:SetText(Text()) end
    return b
end

-- Yes / No popup
local confirm
function W.Confirm(text, onYes, yesText)
    if not confirm then
        confirm = W.Window("WLRTConfirm", 360, 130, "WaR LegenD")
        confirm:SetFrameStrata("FULLSCREEN_DIALOG")
        confirm.text = W.Label(confirm, "", "GameFontHighlight")
        confirm.text:SetPoint("TOP", 0, -40)
        confirm.text:SetWidth(320)
        confirm.text:SetJustifyH("CENTER")
        confirm.yes = W.Button(confirm, L("Yes"), 110, 22)
        confirm.yes:SetPoint("BOTTOMRIGHT", confirm, "BOTTOM", -6, 14)
        confirm.no = W.Button(confirm, L("No"), 110, 22, function() confirm:Hide() end)
        confirm.no:SetPoint("BOTTOMLEFT", confirm, "BOTTOM", 6, 14)
        tinsert(UISpecialFrames, "WLRTConfirm")
    end
    confirm.text:SetText(text)
    confirm:SetHeight(math.max(130, (confirm.text:GetStringHeight() or 0) + 96)) -- a long text (profile import) stays inside
    confirm.yes:SetText(yesText or L("Yes"))
    confirm.yes:SetScript("OnClick", function() confirm:Hide(); onYes() end)
    confirm:Show()
    return confirm
end

-- Reload confirmation. The WoW: Forever client blocks ReloadUI() from addon code, even on a click,
-- so "Reload" is a secure button running the /reload macro on the player's own click (as EllesmereUI
-- does). Secure buttons cannot be created or shown in combat: there we ask for a /reload later.
W.AddFR({
    ["Later"] = "Plus tard",
    ["Type /reload after combat to apply the change."] = "Tape /reload après le combat pour appliquer le changement.",
})
local reloadWin
function W.ConfirmReload(text)
    if InCombatLockdown() then W.Print(L("Type /reload after combat to apply the change.")); return end
    if not reloadWin then
        local f = W.Window("WLRTReload", 380, 130, "WaR LegenD")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f.text = W.Label(f, "", "GameFontHighlight")
        f.text:SetPoint("TOP", 0, -40)
        f.text:SetWidth(340)
        f.text:SetJustifyH("CENTER")
        local yes = W.Button(f, L("Reload"), 110, 22)
        yes:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 14)
        local secure = CreateFrame("Button", "WLRTReloadButton", yes, "SecureActionButtonTemplate")
        secure:SetAllPoints(yes)
        secure:SetFrameLevel(yes:GetFrameLevel() + 5)
        secure:RegisterForClicks("AnyUp")
        secure:SetAttribute("useOnKeyDown", false)
        secure:SetAttribute("type", "macro")
        secure:SetAttribute("macrotext", "/reload")
        -- hover look stays on the visible button underneath
        secure:SetScript("OnEnter", function() local fn = yes:GetScript("OnEnter"); if fn then fn(yes) end; yes:LockHighlight() end)
        secure:SetScript("OnLeave", function() local fn = yes:GetScript("OnLeave"); if fn then fn(yes) end; yes:UnlockHighlight() end)
        W.Button(f, L("Later"), 110, 22, function() f:Hide() end):SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 14)
        reloadWin = f
    end
    reloadWin.text:SetText(text)
    reloadWin:Show()
end
-- the window holds a secure button: close it before combat locks it
W.On("PLAYER_REGEN_DISABLED", function() if reloadWin and reloadWin:IsShown() then reloadWin:Hide() end end)

-- Reload key (Key Bindings > AddOns, see Bindings.xml): the bound key clicks this secure /reload
-- button, a one-step reload with no question. A typed /rl cannot do that on Forever: ReloadUI() is
-- refused to addon code, and chat text an addon rewrites ("/rl" -> "/reload") is refused too.
-- No texture and no mouse: invisible, only the key reaches it. Made at load, or after the fight
-- when the interface was reloaded in combat (its attributes would be refused then).
local function MakeReloadKey()
    if _G.WLRTReloadKey or InCombatLockdown() then return end
    local key = CreateFrame("Button", "WLRTReloadKey", UIParent, "SecureActionButtonTemplate")
    key:SetSize(1, 1)
    key:SetPoint("TOPLEFT")
    key:EnableMouse(false)
    key:RegisterForClicks("AnyUp")
    key:SetAttribute("useOnKeyDown", false)
    key:SetAttribute("type", "macro")
    key:SetAttribute("macrotext", "/reload")
end
MakeReloadKey()
W.On("PLAYER_REGEN_ENABLED", MakeReloadKey, true)
BINDING_HEADER_WARLEGENDRAIDTOOL = "WaR LegenD RaidTool"
W.AddFR({ ["Reload the interface"] = "Recharger l'interface" })
W.OnReady(function()
    _G["BINDING_NAME_CLICK WLRTReloadKey:LeftButton"] = L("Reload the interface")
    W.DB("ui").rlAlias = nil -- the old "/rl" alias of /reload (removed: it rewrote another addon's slash command)
end)

-- BigWigs-like countdown: a spoken number (Media/Sounds/Countdown/<fr|en>/<1-5>.mp3, Windows voices) and the
-- "pop" of a big number (it starts large, settles, then fades). W.Pulse scales the frame it is given: give it an
-- inner frame anchored at the CENTER of its holder with no offset, so it grows in place.
local VOICE_PATH = "Interface\\AddOns\\WarLegendRaidTool\\Media\\Sounds\\Countdown\\"
-- BigWigs' countdown font (Noto Sans Regular, SIL Open Font License, Media/Fonts/Noto_license.txt)
W.COUNTDOWN_FONT = "Interface\\AddOns\\WarLegendRaidTool\\Media\\Fonts\\NotoSans-Regular.otf"

-- Voices (W.DB("ui").countdownVoice): Amy / David / Jim come from BigWigs (CC BY-NC 3.0 / CC0, see
-- Media/Sounds/Countdown/README.txt), Hortense / Zira were made with the Windows voices. "bigwigs": BigWigs'
-- own French voice (Heroes announcer, (C) Blizzard, not copied here), played from BigWigs' folder when it is
-- installed. "beep": the game's battleground countdown tick (file 567474, as BigWigs' "simple").
local function BigWigsInstalled()
    if C_AddOns and C_AddOns.DoesAddOnExist then return C_AddOns.DoesAddOnExist("BigWigs") end
    return GetAddOnInfo and GetAddOnInfo("BigWigs") ~= nil
end
W.COUNTDOWN_VOICES = { "auto", "Amy", "David", "Jim", "Hortense", "Zira", "bigwigs", "beep" }
function W.CountdownVoice(n)
    if type(n) ~= "number" or n < 1 or n > 10 or not PlaySoundFile then return end
    local voice = W.db and W.db.ui and W.db.ui.countdownVoice or "auto"
    if voice == "auto" then
        if BigWigsInstalled() then voice = "bigwigs" -- the BigWigs voice by default, in French and in English
        else voice = W.LANG == "fr" and "Hortense" or "Amy" end
    end
    if voice == "bigwigs" and not BigWigsInstalled() then voice = W.LANG == "fr" and "Hortense" or "Amy" end
    local file
    if voice == "beep" then
        file = 567474
    elseif voice == "bigwigs" then
        if n > 5 then return end
        file = "Interface\\AddOns\\BigWigs\\Media\\Sounds\\Heroes\\" .. (W.LANG == "fr" and "frFR" or "enUS") .. "\\female\\" .. n .. ".ogg"
    elseif voice == "Hortense" or voice == "Zira" then
        if n > 5 then return end
        file = VOICE_PATH .. (voice == "Hortense" and "fr" or "en") .. "\\" .. n .. ".mp3"
    else
        file = VOICE_PATH .. voice .. "\\" .. n .. ".ogg"
    end
    pcall(PlaySoundFile, file, "Master")
end

-- the voice cycle values for a panel ({ value, label })
function W.CountdownVoiceValues()
    local L = W.L
    return { { "auto", L("Voice: auto") }, { "Amy", "Amy (EN)" }, { "David", "David (EN)" }, { "Jim", "Jim (EN)" },
        { "Hortense", "Hortense (FR)" }, { "Zira", "Zira (EN)" }, { "bigwigs", "BigWigs" }, { "beep", L("Beep") } }
end

function W.Pulse(frame, duration)
    duration = duration or 0.95
    local t = 0
    frame:SetAlpha(1)
    frame:SetScale(1.8)
    frame:Show()
    frame:SetScript("OnUpdate", function(self, e)
        t = t + e
        self:SetScale(t < 0.15 and (1.8 - 0.8 * t / 0.15) or 1)
        if t > duration * 0.6 then self:SetAlpha(math.max(0, 1 - (t - duration * 0.6) / (duration * 0.4))) end
        if t >= duration then
            self:SetScript("OnUpdate", nil)
            self:Hide()
            self:SetAlpha(1)
            self:SetScale(1)
        end
    end)
end

W.AddFR({
    ["Click: sort by this column (again: the other way)."] = "Clic : trier par cette colonne (encore : dans l'autre sens).",
})

-- Simple column table built on W.ScrollList: cols = { {title, width, justify, sort = key} }
-- A column with "sort" has a clickable header: holder.onSort(key) is called, holder:SetSortMark(key, desc) shows the
-- arrow. Only the rows on screen exist: a list of thousands of lines keeps a few dozen frames (WoW never frees a
-- frame), moved and filled again when the list scrolls.
local SORT_UP = " |TInterface\\Buttons\\Arrow-Up-Up:10:10:0:-2|t"
local SORT_DOWN = " |TInterface\\Buttons\\Arrow-Down-Up:10:10:0:2|t"
function W.Table(parent, cols, h, rowH)
    rowH = rowH or 18
    local width = 0
    for _, c in ipairs(cols) do width = width + c[2] end
    local holder = CreateFrame("Frame", nil, parent)
    W.Size(holder, width + 24, h)
    holder.heads = {}
    local x = 4
    for _, c in ipairs(cols) do
        local fs = W.Label(holder, c[1], "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", x, 0)
        fs:SetWidth(c[2])
        fs:SetJustifyH(c[3] or "LEFT")
        fs:SetTextColor(0.85, 0.85, 0.85)
        holder.heads[#holder.heads + 1] = fs
        if c.sort then
            local b = CreateFrame("Button", nil, holder)
            b:SetPoint("TOPLEFT", x - 2, 2)
            W.Size(b, c[2], 16)
            local hl = b:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            W.SetColor(hl, 1, 1, 1, 0.08)
            b:SetScript("OnClick", function() if holder.onSort then holder.onSort(c.sort) end end)
            W.Tooltip(b, c[1], { L("Click: sort by this column (again: the other way).") })
        end
        c.x = x
        x = x + c[2]
    end
    function holder:SetSortMark(key, desc)
        for i, c in ipairs(cols) do
            if c.sort then self.heads[i]:SetText(c[1] .. (c.sort == key and (desc and SORT_DOWN or SORT_UP) or "")) end
        end
    end
    local listH = h - 18
    local list = W.ScrollList(holder, width, listH, rowH, function(content)
        local r = CreateFrame("Button", nil, content)
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        W.SetColor(hl, 1, 1, 1, 0.06)
        r.cells = {}
        for k, c in ipairs(cols) do
            local fs = W.Label(r, "", "GameFontHighlightSmall")
            fs:SetPoint("LEFT", c.x - 4, 0)
            fs:SetWidth(c[2] - 2)
            fs:SetJustifyH(c[3] or "LEFT")
            fs:SetWordWrap(false)
            r.cells[k] = fs
        end
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetScript("OnClick", function(self, btn) if holder.onClick and self.data then holder.onClick(self.data, btn, self) end end)
        r:SetScript("OnEnter", function(self) if holder.onEnter and self.data then holder.onEnter(self.data, self) end end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return r
    end)
    list.sf:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -16)
    local data = {}
    local visible = math.ceil(listH / rowH) + 1
    -- the rows on screen: row j shows line first + j, at that line's place in the full-height content
    local function Render()
        local n = #data
        local first = math.floor((list.sf:GetVerticalScroll() or 0) / rowH)
        local shown = 0
        for j = 1, visible do
            local idx = first + j
            local d = data[idx]
            if not d then break end
            local r = list:Row(j)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", list.content, "TOPLEFT", 0, -(idx - 1) * rowH)
            if not r.stripe then
                r.stripe = r:CreateTexture(nil, "BACKGROUND")
                r.stripe:SetAllPoints()
                W.SetColor(r.stripe, 1, 1, 1, 0.035)
            end
            r.stripe:SetShown(idx % 2 == 0) -- the stripes follow the lines, not the recycled rows
            r.data = d
            for k = 1, #cols do r.cells[k]:SetText(d.cells[k] or "") end
            shown = j
        end
        for j = shown + 1, #list.rows do list.rows[j]:Hide() end
    end
    list.sf:HookScript("OnVerticalScroll", Render)
    -- data = { {cells = {...}, ...}, ... }
    function holder:SetData(d)
        data = d or {}
        list.content:SetHeight(math.max(#data * rowH, 1))
        -- a shorter list (a filter): never left scrolled below its end
        local maxScroll = math.max(0, #data * rowH - listH)
        if (list.sf:GetVerticalScroll() or 0) > maxScroll then list.sf:SetVerticalScroll(maxScroll) end
        Render()
    end
    function holder:ScrollToTop() list.sf:SetVerticalScroll(0) end
    holder.list = list
    return holder
end

-- Private table of an addon ported inside this folder (DoesItDie, Myslot): it stands in for the "..." table the
-- game gives each addon, which here would be shared by every file of WarLegendRaidTool.
local spaces = {}
function W.Space(name)
    spaces[name] = spaces[name] or {}
    return spaces[name]
end
