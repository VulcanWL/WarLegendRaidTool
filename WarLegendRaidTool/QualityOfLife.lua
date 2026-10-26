-- WarLegend RaidTool - Quality of Life
-- Small automations, each with its own toggle. Holding Shift leaves it to the player.
-- We click Blizzard's popup buttons (no direct API call) so their own handlers run normally.
local W = WLRT
local L = W.L
local db
local inCombat = false

W.AddFR({
    ["Not enough money to repair your gear."] = "Pas assez d'argent pour réparer ton équipement.",
})

W.OnReady(function()
    db = W.DB("qol", { acceptInvites = false, acceptResurrect = false, fastLoot = false, sellJunk = false,
        autoRepair = false, repairGuild = false, questAccept = false, questTurnIn = false,
        declineDuels = false, skipCinematics = false, deleteConfirm = false })
end)

local function Shift() return IsShiftKeyDown() end

local function PopupButton(dialog, index)
    return dialog["button" .. index] or _G[(dialog:GetName() or "") .. "Button" .. index]
end

local function ClickPopup(which, index)
    local dialog = StaticPopup_FindVisible and StaticPopup_FindVisible(which)
    if not dialog then return false end
    local b = PopupButton(dialog, index)
    if not b or not b:IsEnabled() then return false end
    b:Click()
    return true
end

local function IsFriend(name)
    if not name then return false end
    local short = W.BaseName(name)
    -- full names compared: on Forever the short name is only the first name, shared by strangers
    local key = W.FullName(name):lower()
    local function same(n) return type(n) == "string" and n ~= "" and W.FullName(n):lower() == key end
    if C_FriendList and C_FriendList.GetFriendInfo then
        local info = C_FriendList.GetFriendInfo(name) or C_FriendList.GetFriendInfo(short)
        if info and same(info.name) then return true end
    end
    if BNGetNumFriends and C_BattleNet and C_BattleNet.GetFriendAccountInfo then
        for i = 1, (BNGetNumFriends() or 0) do
            local acc = C_BattleNet.GetFriendAccountInfo(i)
            local game = acc and acc.gameAccountInfo
            if game and same(game.characterName) then return true end
        end
    end
    return false
end

local function IsGuildMate(name)
    return W.GuildMember(name) ~= nil
end

-- Invites from friends / guild
W.On("PARTY_INVITE_REQUEST", function(name)
    name = W.Safe(name)
    if not db.acceptInvites or Shift() or W.InGroup() or not name then return end
    if not (IsFriend(name) or IsGuildMate(name)) then return end
    W.After(0, function()
        if ClickPopup("PARTY_INVITE", 1) then W.Print(L("Invite from ") .. name .. L(" auto-accepted.")) end
    end)
end)

-- Out-of-combat rez (the fight counts as live if we were in combat or the caster is)
local function TryRez(caster, tries)
    if not db.acceptResurrect or Shift() or inCombat then return end
    if caster and UnitExists(caster) and UnitAffectingCombat(caster) then return end
    for _, which in ipairs({ "RESURRECT", "RESURRECT_NO_SICKNESS", "RESURRECT_NO_TIMER" }) do
        if StaticPopup_FindVisible and StaticPopup_FindVisible(which) then
            if not ClickPopup(which, 1) and tries > 0 then W.After(1, function() TryRez(caster, tries - 1) end) end
            return
        end
    end
end
W.On("RESURRECT_REQUEST", function(caster) W.After(0, function() TryRez(W.Safe(caster), 10) end) end)
W.On("PLAYER_REGEN_DISABLED", function() inCombat = true end)
W.On("PLAYER_REGEN_ENABLED", function() inCombat = false end)

-- Instant loot (only when auto loot applies, never while fishing)
local lastLoot = 0
local function FastLoot()
    if not W.FeatureOn(db, "fastLoot") or GetTime() - lastLoot < 0.3 then return end
    lastLoot = GetTime()
    if IsFishingLoot and IsFishingLoot() then return end
    local auto = (C_CVar and C_CVar.GetCVarBool or GetCVarBool)("autoLootDefault")
    if auto == IsModifiedClick("AUTOLOOTTOGGLE") then return end
    for i = GetNumLootItems(), 1, -1 do LootSlot(i) end
end
W.On("LOOT_READY", FastLoot)
W.On("LOOT_OPENED", FastLoot)

-- Vendor: junk + repair
local function Money(c) return GetCoinTextureString and GetCoinTextureString(c) or tostring(c) end
-- what the guild lets me take for a repair, read like the game's merchant frame: my withdraw limit (-1 = guild
-- master, no limit), never more than the bank holds. Too little: my own money pays (the game would refuse).
local function GuildCanRepair(cost)
    if not (CanGuildBankRepair and CanGuildBankRepair()) then return false end
    if not (GetGuildBankWithdrawMoney and GetGuildBankMoney) then return true end -- unknown: the game decides
    local limit, bank = W.Safe(GetGuildBankWithdrawMoney()), W.Safe(GetGuildBankMoney())
    if type(limit) ~= "number" or type(bank) ~= "number" then return true end
    local amount = limit == -1 and bank or math.min(limit, bank)
    return amount >= cost
end
W.On("MERCHANT_SHOW", function()
    if Shift() then return end
    if W.FeatureOn(db, "sellJunk") then
        local numSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
        local use = (C_Container and C_Container.UseContainerItem) or UseContainerItem
        local count = 0
        for bag = 0, (numSlots and use) and 4 or -1 do
            for slot = 1, (numSlots(bag) or 0) do
                local quality, noValue, link
                if C_Container and C_Container.GetContainerItemInfo then
                    local info = C_Container.GetContainerItemInfo(bag, slot)
                    if info then quality, noValue, link = info.quality, info.hasNoValue, info.hyperlink end
                else
                    local _, _, _, q, _, _, l, _, nv = GetContainerItemInfo(bag, slot)
                    quality, noValue, link = q, nv, l
                end
                if link and quality == 0 and not noValue then use(bag, slot); count = count + 1 end
            end
        end
        if count > 0 then W.Print(count .. L(" junk item(s) sold.")) end
    end
    if W.FeatureOn(db, "autoRepair") and CanMerchantRepair() then
        local cost, can = GetRepairAllCost()
        if not can or not cost or cost == 0 then return end
        if db.repairGuild and GuildCanRepair(cost) then
            RepairAllItems(true)
            W.Print(L("Gear repaired for ") .. Money(cost) .. L(" (guild bank)."))
        elseif (GetMoney() or 0) >= cost then
            RepairAllItems()
            W.Print(L("Gear repaired for ") .. Money(cost) .. ".")
        else
            W.Print(L("Not enough money to repair your gear."))
        end
    end
end)

-- Quests: turn in then accept (no reward choice, no grey quests)
W.On("GOSSIP_SHOW", function()
    if Shift() or not C_GossipInfo then return end
    if W.FeatureOn(db, "questTurnIn") and C_GossipInfo.GetActiveQuests then
        for _, q in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
            if q.isComplete and q.questID then C_GossipInfo.SelectActiveQuest(q.questID); return end
        end
    end
    if W.FeatureOn(db, "questAccept") and C_GossipInfo.GetAvailableQuests then
        for _, q in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
            if q.questID and not q.isTrivial then C_GossipInfo.SelectAvailableQuest(q.questID); return end
        end
    end
end)
W.On("QUEST_GREETING", function()
    if Shift() then return end
    if W.FeatureOn(db, "questTurnIn") then
        for i = 1, GetNumActiveQuests() do
            local _, done = GetActiveTitle(i)
            if done then SelectActiveQuest(i); return end
        end
    end
    if W.FeatureOn(db, "questAccept") then
        for i = 1, GetNumAvailableQuests() do
            local trivial = GetAvailableQuestInfo and GetAvailableQuestInfo(i)
            if not trivial then SelectAvailableQuest(i); return end
        end
    end
end)
W.On("QUEST_DETAIL", function()
    if not W.FeatureOn(db, "questAccept") or Shift() then return end
    if QuestGetAutoAccept and QuestGetAutoAccept() and AcknowledgeAutoAcceptQuest then
        AcknowledgeAutoAcceptQuest()
    else
        AcceptQuest()
    end
end)
W.On("QUEST_PROGRESS", function()
    if W.FeatureOn(db, "questTurnIn") and not Shift() and IsQuestCompletable() then CompleteQuest() end
end)
W.On("QUEST_COMPLETE", function()
    if not W.FeatureOn(db, "questTurnIn") or Shift() then return end
    local choices = GetNumQuestChoices()
    if choices > 1 then return end
    GetQuestReward(choices)
end)

-- Duels (except friends)
W.On("DUEL_REQUESTED", function(challenger)
    challenger = W.Safe(challenger)
    if not db.declineDuels or Shift() or not challenger or IsFriend(challenger) then return end
    W.After(0, function()
        if ClickPopup("DUEL_REQUESTED", 2) then W.Print(L("Duel from ") .. challenger .. L(" declined.")) end
    end)
end)

-- Cinematics
W.On("CINEMATIC_START", function(canCancel)
    if W.FeatureOn(db, "skipCinematics") and not Shift() and canCancel ~= false then StopCinematic() end
end)
W.On("PLAY_MOVIE", function()
    if not W.FeatureOn(db, "skipCinematics") or Shift() then return end
    W.After(0, function()
        if MovieFrame and MovieFrame:IsShown() then
            if MovieFrame.FinishMovie then MovieFrame:FinishMovie() elseif GameMovieFinished then GameMovieFinished() end
        end
    end)
end)

-- Delete: pre-fills the confirmation word (the player still clicks "Yes")
W.On("DELETE_ITEM_CONFIRM", function()
    if not W.FeatureOn(db, "deleteConfirm") or not DELETE_ITEM_CONFIRM_STRING then return end
    W.After(0, function()
        for i = 1, (STATICPOPUP_NUMDIALOGS or 4) do
            local d = _G["StaticPopup" .. i]
            if d and d:IsShown() and (d.which == "DELETE_GOOD_ITEM" or d.which == "DELETE_GOOD_QUEST_ITEM") then
                local box = d.editBox or _G[d:GetName() .. "EditBox"]
                if box then box:SetText(DELETE_ITEM_CONFIRM_STRING) end
            end
        end
    end)
end)

local SECTIONS = {
    { L("Group"), { { "acceptInvites", L("Accept invites from friends and guild") },
        { "acceptResurrect", L("Accept resurrections out of combat") } } },
    { L("Loot and vendors"), { { "fastLoot", L("Instant loot (with auto loot)") },
        { "sellJunk", L("Sell junk at vendors") },
        { "autoRepair", L("Repair gear at vendors") },
        { "repairGuild", L("  Use guild bank funds when possible") } } },
    { L("Quests"), { { "questAccept", L("Accept quests") },
        { "questTurnIn", L("Turn in completed quests (unless a reward choice)") } } },
    { L("Misc"), { { "declineDuels", L("Decline duels (except friends)") },
        { "skipCinematics", L("Skip cinematics") },
        { "deleteConfirm", L("Pre-fill the word to delete an item") } } },
}

W.RegisterModule("QualityOfLife", L("Quality of Life"), function(p)
    W.Title(p, L("Quality of Life"))
    local y = -38
    for _, section in ipairs(SECTIONS) do
        local h = W.Label(p, L(section[1]), "GameFontNormalSmall")
        h:SetPoint("TOPLEFT", 14, y)
        h:SetTextColor(0.85, 0.75, 0.45)
        y = y - 16
        for _, t in ipairs(section[2]) do
            local key = t[1]
            W.Check(p, L(t[2]), function() return db[key] end, function(v) db[key] = v end):SetPoint("TOPLEFT", 12, y)
            W.OverlapNote(p, key, "TOPLEFT", 340, y - 6)
            y = y - 24
        end
        y = y - 6
    end
    local info = W.Label(p, L("Hold Shift when a popup appears (or when talking to an NPC) to handle it yourself."),
        "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, y - 4)
    info:SetTextColor(0.7, 0.7, 0.7)
    W.Check(p, L("Use it anyway"), W.OverlapForced, W.SetOverlapForce):SetPoint("TOPLEFT", 12, y - 34)
end)
