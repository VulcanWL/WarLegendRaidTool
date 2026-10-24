-- WarLegend RaidTool - Auto Promote
-- Promotes listed players and/or checked guild ranks to assistant (when you are raid leader).
local W = WLRT
local L = W.L
local db
local rankByName, ranks = {}, {}
local ranksDirty = true -- rebuilt on demand, not on every GUILD_ROSTER_UPDATE
local promotedAt = {}   -- name -> time: GROUP_ and RAID_ROSTER_UPDATE both fire, ask the server once
local UI = {}

W.OnReady(function()
    db = W.DB("autoPromote")
    db.names = db.names or {}
    db.ranks = db.ranks or {} -- keyed by rank name
end)

local function RefreshRanks()
    if not ranksDirty then return end
    ranksDirty = false
    wipe(rankByName); wipe(ranks)
    local seen = {}
    for _, m in ipairs(W.GuildMembers()) do
        if m.rank then
            -- a duplicate name (same name, other realm) is ambiguous: no rank-based promotion
            rankByName[m.name] = (rankByName[m.name] == nil) and m.rank or false
            if not seen[m.rank] then
                seen[m.rank] = true
                ranks[#ranks + 1] = { name = m.rank, index = m.rankIndex or 99 }
            end
        end
    end
    table.sort(ranks, function(a, b) return a.index < b.index end)
end

local function ShouldPromote(name)
    local full = W.FullName(name)
    if W.HasFullPart(full) and (db.names[name] or db.names[full]) then return true end
    -- a short name of the list or a rank: only the guild member with that name, never a stranger with the same
    -- first name (Forever), and not when two guild members share it
    local m = W.GuildMember(name)
    local short = W.BaseName(name)
    if not m or rankByName[short] == false then return false end
    if db.names[short] then return true end
    return m.rank and db.ranks[m.rank] or false
end

local function Promote(name)
    if C_PartyInfo and C_PartyInfo.PromoteToAssistant then
        C_PartyInfo.PromoteToAssistant(name)
    elseif PromoteToAssistant then
        PromoteToAssistant(name)
    end
end

local function Check()
    if not db or not W.InRaid() or not W.IsLeader() or InCombatLockdown() then return end
    RefreshRanks()
    local now = GetTime()
    for i = 1, W.NumRaid() do
        local name, rank = GetRaidRosterInfo(i)
        name, rank = W.Safe(name), W.Safe(rank)
        if name and rank == 0 and now - (promotedAt[name] or 0) > 5 and ShouldPromote(name) then
            promotedAt[name] = now
            Promote(name)
            W.Print(name .. L(" promoted to assistant."))
        end
    end
end

local function RefreshUI()
    if not UI.names then return end
    local sorted = {}
    for n in pairs(db.names) do sorted[#sorted + 1] = n end
    table.sort(sorted)
    for i, n in ipairs(sorted) do
        local r = UI.names:Row(i)
        r.name = n
        r.text:SetText(n)
    end
    UI.names:Finish(#sorted)

    for i, info in ipairs(ranks) do
        local c = UI.rankChecks[i]
        if not c then
            local box
            box = W.Check(UI.rankPanel, "", function() return box.rankName and db.ranks[box.rankName] end,
                function(v) if box.rankName then db.ranks[box.rankName] = v; Check() end end)
            box:SetPoint("TOPLEFT", 0, -(i - 1) * 24)
            UI.rankChecks[i] = box
            c = box
        end
        c.rankName = info.name
        c.label:SetText(info.name)
        c:Show()
        c:Sync()
    end
    for i = #ranks + 1, #UI.rankChecks do UI.rankChecks[i]:Hide() end
    UI.noGuild:SetShown(#ranks == 0)
end

local function Build(p)
    W.Title(p, L("Auto Promote"))
    W.Label(p, L("Add players (separated by comma or space):"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 16, -40)
    local box = W.EditBox(p, 260, 400)
    box:SetPoint("TOPLEFT", 20, -58)
    local function add()
        for _, n in ipairs(W.NameList(box:GetText())) do
            n = W.SanitizeName(n)
            if n ~= "" then db.names[n] = true end
        end
        box:SetText("")
        RefreshUI()
        Check()
    end
    box:SetScript("OnEnterPressed", function(self) add(); self:ClearFocus() end)
    W.Button(p, L("Add"), 80, 22, add):SetPoint("LEFT", box, "RIGHT", 8, 0)

    W.Label(p, L("Auto-promoted players:"), "GameFontNormalSmall"):SetPoint("TOPLEFT", 16, -90)
    local panel = W.Panel(p, 280, 300)
    panel:SetPoint("TOPLEFT", 14, -106)
    UI.names = W.ScrollList(panel, 240, 284, 20, function(content)
        local r = CreateFrame("Frame", nil, content)
        r.text = W.Label(r, "", "GameFontHighlightSmall")
        r.text:SetPoint("LEFT", 4, 0)
        local x = W.Button(r, "x", 22, 18, function(self) db.names[self:GetParent().name] = nil; RefreshUI() end)
        x:SetPoint("RIGHT", -2, 0)
        return r
    end)
    UI.names.sf:SetPoint("TOPLEFT", 6, -8)

    W.Label(p, L("Guild ranks to promote:"), "GameFontNormalSmall"):SetPoint("TOPLEFT", 320, -90)
    UI.rankPanel = CreateFrame("Frame", nil, p)
    UI.rankPanel:SetPoint("TOPLEFT", 320, -108)
    W.Size(UI.rankPanel, 260, 300)
    UI.rankChecks = {}
    UI.noGuild = W.Label(p, L("No guild, or ranks still loading..."), "GameFontDisableSmall")
    UI.noGuild:SetPoint("TOPLEFT", 324, -112)

    local info = W.Label(p, L("Works when you are raid leader, out of combat."), "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, -420)
    info:SetTextColor(0.7, 0.7, 0.7)
end

W.RegisterModule("AutoPromote", "Auto Promote", Build, function()
    W.RequestGuildRoster()
    RefreshRanks()
    RefreshUI()
end)

W.On("GUILD_ROSTER_UPDATE", function()
    ranksDirty = true
    if W.IsShown("AutoPromote") then RefreshRanks(); RefreshUI() end
end)
W.OnRoster(function() if not W.InRaid() then wipe(promotedAt) end; Check() end)
W.On("PLAYER_REGEN_ENABLED", Check)
-- the guild ranks only matter to a raid leader: no server request on every loading screen
W.On("PLAYER_ENTERING_WORLD", function() if W.InRaid() and W.IsLeader() then W.RequestGuildRoster() end end)
