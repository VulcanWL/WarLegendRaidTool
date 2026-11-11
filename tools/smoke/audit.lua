-- WarLegend RaidTool - the MED findings of the audit of 10/11/2026 in the simulated client (tools/smoke/scenario.lua, phase
-- "audit 10/11"; not shipped). One check per fix the bench can see, each seen failing with its fix taken out; the export / import one passes both
-- ways: it keeps the import checks of M4 / M5 from being too strict.
-- Not seen from here: M6 (the bank's item levels: BankPanel is Blizzard's frame), M13 (the dispel tint: the client's own
-- aura buttons), the order of the secret-value test in W.Safe / M11 (the bench lets a secret be compared with nil).
local M, Check, H = ...
local W = WLRT
local EU = C_EncodingUtil

local function Size(t) local n = 0; for _ in pairs(t or {}) do n = n + 1 end return n end
-- a value as text, keys sorted: to compare what an import left
local function Ser(v, depth)
    if type(v) ~= "table" then return type(v) .. ":" .. tostring(v) end
    if (depth or 0) > 8 then return "{deep}" end
    local keys, out = {}, {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return type(a) .. tostring(a) < type(b) .. tostring(b) end)
    for _, k in ipairs(keys) do out[#out + 1] = type(k) .. ":" .. tostring(k) .. "=" .. Ser(v[k], (depth or 0) + 1) end
    return "{" .. table.concat(out, ",") .. "}"
end

---------------------------------------------------------------------------
-- M2: a link shift-clicked by the game's own code (ChatFrameUtil.InsertLink) goes in the box of ours that has the focus
---------------------------------------------------------------------------
do
    local _, box = W.MultiEdit(UIParent, 100, 40, 0)
    local got
    box.HasFocus = function() return true end
    box.Insert = function(_, link) got = link end
    local link = "|cffffffff|Hitem:2589::::::::60:::::|h[Linen Cloth]|h|r"
    if ChatFrameUtil and ChatFrameUtil.InsertLink then ChatFrameUtil.InsertLink(link) end
    box.HasFocus = function() return false end -- for good: the box stays in the list of link targets
    Check("a link the game inserts (ChatFrameUtil.InsertLink) goes in our box that has the focus", got == link, tostring(got))
end

---------------------------------------------------------------------------
-- M3: messages queued behind a lockdown longer than MAX_WAIT (300 s) still leave after it, through a throttle
---------------------------------------------------------------------------
do
    M.Advance(3) -- the queue empties first
    local send0, sent, tried = C_ChatInfo.SendAddonMessage, 0, {}
    local unlock = M.now + 305
    C_ChatInfo.SendAddonMessage = function(prefix, msg, ...)
        if prefix ~= "WLRT_AUDIT" then return send0(prefix, msg, ...) end
        if M.now < unlock then return 11 end -- AddOnMessageLockdown: a boss encounter
        if not tried[msg] then tried[msg] = true; return 3 end -- AddonMessageThrottle, once per message
        sent = sent + 1
        return 0
    end
    for i = 1, 3 do W.Queue("WLRT_AUDIT", "chunk " .. i, "RAID") end
    M.Advance(320, 1) -- in steps of 1 s: each step of the clock walks every frame ever made
    C_ChatInfo.SendAddonMessage = send0
    Check("messages queued behind a long lockdown leave after it (3 chunks, 305 s locked, then one throttle each)", sent == 3, sent .. " / 3 sent")
end

---------------------------------------------------------------------------
-- M4, M5: a profile's option tables and texts are checked before they are kept
---------------------------------------------------------------------------
do
    local FIELDS = { { "checklist", "items" }, { "autoPromote", "names" }, { "autoPromote", "ranks" }, { "inviteTool", "ranks" },
        { "raidGroups", "sortGroups" }, { "raidCooldowns", "spells" }, { "ui", "off" }, { "moneyGoal", "label" },
        { "summon", "whisper" }, { "inviteTool", "list" }, { "readiness", "text" } }
    local kept, missing = {}, {}
    for i, f in ipairs(FIELDS) do
        if type(W.db[f[1]]) ~= "table" then missing[#missing + 1] = f[1] else kept[i] = W.db[f[1]][f[2]] end
    end
    local function Import(text)
        if H.Confirming() then WLRTConfirm:Hide() end
        local box, button = H.ProfileBox()
        if not (box and button) then return "no profile box" end
        box.__text = text
        H.Click(button)
        if not H.Confirming() then return "refused before the confirmation" end
        H.Click(WLRTConfirm.yes)
        M.Advance(0.5)
        local reload = rawget(_G, "WLRTReload")
        if reload then reload:Hide() end
    end
    local function State() local out = {}; for i, f in ipairs(FIELDS) do out[i] = Ser((W.db[f[1]] or {})[f[2]]) end return out end
    local function Restore() for i, f in ipairs(FIELDS) do if W.db[f[1]] then W.db[f[1]][f[2]] = kept[i] end end end

    -- made-up tables and texts: none must be kept
    local before = State()
    local hostile = "WLRT1:{smain~{"
        .. "schecklist~{sitems~{n1~{n1~n13444~}}}"                       -- { { 13444 } }: no quantity
        .. "sautoPromote~{snames~{sBob~{}}sranks~{n5~sx~}}"              -- a table, a text as flags
        .. "sinviteTool~{sranks~{n99~Tsx~T}}"                            -- a rank past 9, a text key
        .. "sraidGroups~{ssortGroups~{n1~syes~n9~T}}"
        .. "sraidCooldowns~{sspells~{sshieldwall~{}}}"
        .. "sui~{soff~{sGuild~sno~}}"
        .. "smoneyGoal~{slabel~s^pTInterface\\Icons\\x:64^pt~}"          -- an escape code
        .. "ssummon~{swhisper~s" .. string.rep("a", 5000) .. "~}"        -- past its box
        .. "szzAuditJunk~{sa~n1~}"                                       -- a key no module saves under
        .. "}}"
    local err = Import(hostile)
    local after, changed = State(), {}
    for i, f in ipairs(FIELDS) do if after[i] ~= before[i] then changed[#changed + 1] = f[1] .. "." .. f[2] end end
    if W.db.zzAuditJunk ~= nil then changed[#changed + 1] = "zzAuditJunk created"; W.db.zzAuditJunk = nil end
    Restore()
    Check("a profile's made-up lists, flags and texts are not kept (consumables, ranks, names, switches, label, unknown key)",
        not err and #missing == 0 and #changed == 0, err or (#missing > 0 and ("no saved table: " .. table.concat(missing, " ")))
        or ("kept: " .. table.concat(changed, ", ")))

    -- and the real ones come back: what an export wrote is taken again by an import (the checks are not too strict)
    local long = string.rep("Jean Dupont, Éloïse Müller, ", 60) -- 1,800 bytes: the invite list takes 2,000 letters
    local set = { { { 13444, 5 }, { 13446, 3 } }, { ["Jean Dupont"] = true }, { Rank1 = true }, { [0] = true, [3] = true },
        { true, true, true, true, true, true, true, true }, { shieldwall = true }, nil, "Mount || epic", "On my way", long,
        "level 60\nenchants\n" .. string.rep("gold 50\n", 100) }
    for i, f in ipairs(FIELDS) do if set[i] ~= nil and W.db[f[1]] then W.db[f[1]][f[2]] = set[i] end end
    local want = State()
    local ok, text = pcall(H.ProfileExport)
    local blank = { {}, {}, {}, {}, {}, {}, nil, "", "", "", "" }
    for i, f in ipairs(FIELDS) do if blank[i] ~= nil and W.db[f[1]] then W.db[f[1]][f[2]] = blank[i] end end
    if ok then err = Import(text) else err = "export failed: " .. tostring(text) end
    local back, lost = State(), {}
    for i, f in ipairs(FIELDS) do if set[i] ~= nil and back[i] ~= want[i] then lost[#lost + 1] = f[1] .. "." .. f[2] end end
    Restore()
    Check("an exported profile's own lists, flags and long texts come back through an import", not err and #lost == 0,
        err or ("not taken back: " .. table.concat(lost, ", ")))
    if H.Confirming() then WLRTConfirm:Hide() end
end

---------------------------------------------------------------------------
-- M15: a vote moves the vote window to the next item, and the rows shown are that item's candidates at once
---------------------------------------------------------------------------
do
    local LC = W.LootCouncil
    local left = LC.Session()
    if left then left.test, left.started = true, -1e9 end -- what an earlier phase left open can be replaced
    local function Loot(from, ...) H.Addon("WLRT_LC", W.Pack(...), "RAID", from) end
    local SID = "77781"
    local assist0 = M.group[4].assist -- Raider4 starts the session: an assistant, as in the phase "hardening"
    M.group[4].assist = true
    M.Fire("GROUP_ROSTER_UPDATE")
    M.Advance(11, 1)
    Loot(H.ASSIST, "S", SID, 2, 60, "")
    Loot(H.ASSIST, "I", SID, 1, "item:19019::::::::60:::::")
    Loot(H.ASSIST, "I", SID, 2, "item:17182::::::::60:::::")
    Loot(H.ASSIST, "C", SID, "Smoketest-Forever")
    Loot(H.MATE, "R", SID, 1, "need", "", "", 100)   -- item 1: one candidate
    Loot(H.ASSIST, "R", SID, 2, "need", "", "", 100) -- item 2: another one
    M.Advance(1)
    local f = rawget(_G, "WLRTVoteFrame")
    if not (f and f:IsShown()) then M.Call(W.slash.loot, "vote"); f = rawget(_G, "WLRTVoteFrame") end
    local s = LC.Session()
    local row = f and f:IsShown() and f.list and f.list:Row(1)
    local detail = "the vote window did not open on a session of 2 items: the check saw nothing"
    local ok = false
    if s and s.sid == SID and row and row.cand and row.vote then
        f.sel = 1
        LC.RefreshVote()
        local first = row.cand
        H.Click(row.vote)
        local shown, ofItem = row.cand, false
        for _, c in pairs(s.items[f.sel] and s.items[f.sel].cands or {}) do if c == shown then ofItem = true end end
        ok = f.sel == 2 and ofItem
        detail = string.format("item shown after the vote: %s; its row shows %s, a candidate of that item: %s", tostring(f.sel),
            tostring(shown and shown.name), tostring(ofItem)) .. (shown == first and " (still the row of the item voted on)" or "")
    end
    Check("Loot Council: after a vote the rows are those of the next item at once (a second click voted unseen)", ok, detail)
    if f and f:IsShown() then f:Hide() end
    Loot(H.ASSIST, "E", SID)
    M.Advance(1)
    M.group[4].assist = assist0
    M.Fire("GROUP_ROSTER_UPDATE")
    M.Advance(1)
end

---------------------------------------------------------------------------
-- M17: joining a group with the cooldown window on asks the others for their cooldowns (it only told mine)
---------------------------------------------------------------------------
do
    local cd = W.db.raidCooldowns
    local asked, detail = 0, "no raidCooldowns options: the check saw nothing"
    if cd then
        local window0, group0 = cd.window, M.group
        cd.window = true
        M.Advance(21, 1) -- one question per 20 s
        M.group = { M.player }
        M.Fire("GROUP_ROSTER_UPDATE")
        M.Advance(2)
        local from = #M.addon
        M.group = group0
        M.Fire("GROUP_ROSTER_UPDATE")
        M.Advance(6)
        for i = from + 1, #M.addon do
            local a = M.addon[i]
            if a.prefix == "WLRT_CD2" and a.msg == "Q" then asked = asked + 1 end
        end
        detail = asked .. " question(s) sent in the 6 s after joining"
        cd.window = window0
        M.Fire("GROUP_ROSTER_UPDATE")
        M.Advance(1)
    end
    Check("RaidCooldowns: joining a group with the window on asks the group once", asked == 1, detail)
end

---------------------------------------------------------------------------
-- M18: the player's own inspect, asked and not answered yet (InspectFrame.unit set, window still hidden), is left alone
---------------------------------------------------------------------------
do
    local kept = { CanInspect, CheckInteractDistance, NotifyInspect, rawget(_G, "InspectFrame") }
    local notified = 0
    CanInspect = function() return true end
    CheckInteractDistance = function() return true end
    NotifyInspect = function() notified = notified + 1 end
    -- our own inspects go one at a time, each waiting 4 s for its answer (none comes here). The player asks one right
    -- after one of ours left: the next of ours, due about 4 s later, must wait while the player's is in flight
    M.Call(W.Toggle, "RaidInspect")
    local waited = 0
    while notified == 0 and waited < 20 do M.Advance(0.25, 0.25); waited = waited + 0.25 end
    local first = notified
    InspectFrame = { IsShown = function() return false end, unit = "target" }
    M.Advance(7.5, 0.25)
    local during = notified - first
    InspectFrame.unit = nil
    M.Advance(8, 0.25)
    local after = notified - first - during
    M.Call(W.Hide)
    CanInspect, CheckInteractDistance, NotifyInspect, InspectFrame = kept[1], kept[2], kept[3], kept[4]
    Check("Raid Inspect: no inspect of ours while the player's own is asked and not answered yet", first > 0 and during == 0 and after > 0,
        string.format("ours before: %d; in the 7.5 s the player's own was in flight: %d; in the 8 s after: %d%s", first, during, after,
            (first == 0 or after == 0) and " (nobody to inspect: the check saw nothing)" or ""))
end

---------------------------------------------------------------------------
-- M20: a recipe id past the game's range, sent by a guild member, is not asked to the client
---------------------------------------------------------------------------
do
    local name0, asked, most = C_Spell.GetSpellName, 0, 0
    local text = EU.EncodeBase64(EU.CompressString("D^Alchemy:300:300^Alchemy=2259,99999999999999999999,123456789012^^"))
    H.Addon("WLRT_PROF", "z781:1:1:" .. text, "GUILD", "Guildie2-Forever")
    M.Advance(1)
    C_Spell.GetSpellName = function(id)
        asked = asked + 1
        if type(id) == "number" and id > most then most = id end
        return name0(id)
    end
    H.Printed(function() M.Call(W.slash.craft, "spell") end)
    C_Spell.GetSpellName = name0
    Check("Guild professions: a received recipe id past 9 digits is not asked to the client", asked > 0 and most <= 999999999,
        asked == 0 and "no recipe name asked: the list was not kept, the check saw nothing" or string.format("%d names asked, largest id %.0f", asked, most))
end

---------------------------------------------------------------------------
-- M21: another trial rank picked, then the first one again: the dates of the trials are the same
---------------------------------------------------------------------------
do
    local r = W.db.roster
    local n1, same, total = 0, 0, 0
    if r then
        local kept = { r.trialRank, r.trials, r.trialsOf, r.trialsRank }
        local function Scan(rank)
            r.trialRank = rank
            M.Advance(31, 1) -- one scan per 30 s
            M.Fire("GUILD_ROSTER_UPDATE", false)
            M.Advance(1)
        end
        r.trialRank, r.trials, r.trialsOf, r.trialsRank = "", {}, nil, nil
        Scan("Rank1")
        local old = time() - 10 * 86400
        for k in pairs(r.trials) do r.trials[k] = old; n1 = n1 + 1 end
        Scan("Rank2") -- the mis-click
        Scan("Rank1")
        for _, since in pairs(r.trials) do
            total = total + 1
            if since == old then same = same + 1 end
        end
        r.trialRank, r.trials, r.trialsOf, r.trialsRank = kept[1], kept[2], kept[3], kept[4]
    end
    Check("Trials: another rank picked then the first again, every trial keeps its date", n1 > 0 and total == n1 and same == n1,
        string.format("%d trials at the rank, %d after the two changes, %d with their date", n1, total, same))
end

---------------------------------------------------------------------------
-- M26: the DoesItDie tab built again (module off then on): its drop-downs open their list on the new page
---------------------------------------------------------------------------
do
    local function Page() return H.Panel("DoesItDie") end
    local function DropDown(page)
        return page and H.Under(page, function(o)
            if o.__type ~= "Button" or not o.__scripts.OnClick then return false end
            for _, c in ipairs(o.__regions or {}) do if c.__type == "FontString" and rawequal(c.__text, "v") then return true end end
            return false
        end)
    end
    local function List(page) return page and H.Under(page, function(o) return rawget(o, "buttons") ~= nil and rawget(o, "owner") ~= nil end) end
    local function Opens()
        local page = Page()
        local b = DropDown(page)
        if not b then return nil end
        H.Click(b)
        local list = List(page)
        local open = list ~= nil and list:IsVisible()
        if open then H.Click(b) end -- the same click closes it
        return open
    end
    M.Call(W.Toggle, "DoesItDie")
    M.Advance(0.5)
    local page1, first = Page(), Opens()
    M.Call(W.SetModuleOn, "DoesItDie", false)
    M.Advance(0.5)
    M.Call(W.SetModuleOn, "DoesItDie", true)
    M.Advance(0.5)
    local page2, again = Page(), Opens()
    M.Call(W.Hide)
    Check("DoesItDie: its tab built again (switched off then on), the drop-downs still open their list", first == true and again == true and page2 ~= page1,
        string.format("opened on the first page: %s; page built again: %s; opened on it: %s", tostring(first), tostring(page2 ~= page1), tostring(again)))
end

---------------------------------------------------------------------------
-- Build 70888: the inviter's GUID of PARTY_INVITE_REQUEST is read by its form (8th argument now, 7th before)
---------------------------------------------------------------------------
do
    local G = "Player-5827-0A1B2C3D"
    local new = W.InviteGUID(false, false, false, true, true, true, G, false)
    local old = W.InviteGUID(false, false, false, true, false, G, false)
    local none = W.InviteGUID(false, false, false, true, true, true, nil, false)
    local notOne = W.InviteGUID("Player-Forever", "Creature-0-1-1-4242-1234-1", "Player-1-zz", true)
    local hidden = W.InviteGUID(false, M.Secret(G), false)
    Check("the inviter's GUID of an invite is found at its new place (build 70888) and at the old one, nothing else taken for it",
        new == G and old == G and none == nil and notOne == nil and hidden == nil,
        string.format("new format: %s, old: %s, none given: %s, a name / a creature: %s, secret: %s", tostring(new), tostring(old),
            tostring(none), tostring(notOne), tostring(hidden)))

    -- and the handlers give it to the game as it is: "accept invites from friends / guild" asks the friend list and
    -- the guild about the GUID. Read at its old place, the 7th argument (allowMultipleRoles, true here) went to them
    local qol, group0 = W.db.qol, M.group
    local kept = { rawget(_G, "C_FriendList"), rawget(_G, "IsGuildMember"), qol and qol.acceptInvites }
    local asked = {}
    C_FriendList = { IsFriend = function(v) asked[#asked + 1] = v; return false end }
    IsGuildMember = function(v) asked[#asked + 1] = v; return false end
    if qol then qol.acceptInvites = true end
    M.group = { M.player }
    M.Fire("GROUP_ROSTER_UPDATE")
    M.Advance(1)
    M.Fire("PARTY_INVITE_REQUEST", "Zzstranger Nobody", false, false, false, true, false, true, G, false)
    M.Advance(0.5)
    C_FriendList, IsGuildMember = kept[1], kept[2]
    if qol then qol.acceptInvites = kept[3] end
    M.group = group0
    M.Fire("GROUP_ROSTER_UPDATE")
    M.Advance(1)
    local wrong = {}
    for _, v in ipairs(asked) do if v ~= G then wrong[#wrong + 1] = type(v) .. " " .. tostring(v) end end
    Check("an invite of build 70888: the friend list and the guild are asked about the inviter's GUID, nothing else",
        #asked > 0 and #wrong == 0, #asked == 0 and "nothing asked: the check saw nothing" or (#asked .. " asked, not the GUID: "
            .. (#wrong > 0 and table.concat(wrong, ", ") or "none")))
end
