---@class Data
---@class WarLegendPvP

---@type string
local AddonName = ...
---@class Data
local Data = select(2, ...)
local issecret = issecretvalue or function() return false end -- WoW Forever secret values

---@class WarLegendPvP
local WarLegendPvP = WarLegendPvP
local L = Data.L

--WoW API
local pairs = pairs
local type = type

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local UnitGUID = UnitGUID
local UnitRace = UnitRace

--lua
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_random = math.random
local table_insert = table.insert
local table_remove = table.remove





local IsClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
local IsTBCC = WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
local IsWrath = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC


--[[  from wowpedia
1	IconSmall RaidStar.png 		Yellow 4-point Star
2	IconSmall RaidCircle.png 	Orange Circle
3	IconSmall RaidDiamond.png 	Purple Diamond
4	IconSmall RaidTriangle.png 	Green Triangle
5	IconSmall RaidMoon.png 		White Crescent Moon
6	IconSmall RaidSquare.png 	Blue Square
7	IconSmall RaidCross.png 	Red "X" Cross
8	IconSmall RaidSkull.png 	White Skull
 ]]


local testEvents = {
	---@param mainFrame MainFrame
	function(mainFrame, playerButton)
		if playerButton.isDead then return end

		-- hide old flag carrier
		local oldFlagholder = mainFrame.Testmode.holdsFlag
		if oldFlagholder then
			oldFlagholder:SetFlagCarrier(false)
		end

		playerButton:SetFlagCarrier(true)

		mainFrame.Testmode.holdsFlag = playerButton
		mainFrame.Testmode.hasFlag = true
	end,
	---@param mainFrame MainFrame
	function (mainFrame, playerButton)
		playerButton:UNIT_POWER_FREQUENT()
		if playerButton.isDead then return end
	end,
	---@param mainFrame MainFrame
	function (mainFrame, playerButton)
		playerButton:UNIT_HEALTH()
	end,
	---@param mainFrame MainFrame
	function(mainFrame, playerButton)
		if playerButton.Target then
			playerButton:IsNoLongerTarging(playerButton.Target)
		end

		local oppositeMainFrame = playerButton:GetOppositeMainFrame()
		if oppositeMainFrame then --this really should never be nil
			local randomPlayer = oppositeMainFrame:GetRandomPlayer()

			if randomPlayer then
				playerButton:IsNowTargeting(randomPlayer)
			end
		end
	end,
	---@param mainFrame MainFrame
	function(mainFrame, playerButton)
		playerButton:UpdateRaidTargetIcon(math_random(1, 8))
	end,
	function (mainFrame, playerButton)
		playerButton:UpdateRange(not playerButton.wasInRange)
	end
}

-- WarLegend: the player details that say who the player is (CreateOrUpdatePlayerDetails)
local IDENTITY_DETAILS = { "PlayerName", "PlayerClass", "PlayerClassColor", "PlayerSpecName", "PlayerRole", "PlayerLevel", "isFakePlayer" }

---@class MainFrame : Button
---@field Players table<string, PlayerButton>
---@field CurrentPlayerOrder table<number, PlayerButton>
---@field InactivePlayerButtons table<number, PlayerButton>
---@field NewPlayersDetails table<number, table>
---@field PlayerType string
---@field PlayerSources table<string, table>
---@field NumPlayers number
---@field Counter table<string, number>
---@field PlayerCount MyFontString
---@field ActiveProfile MyFontString
---@return MainFrame
local function CreateMainFrame(playerType)

    --binding voodoo
    -- how it works:
    -- SecureHandlerEnterLeaveTemplate is necessary to add the secure onenter and onleave event handlers
    -- the handler then sets the wheeldown and wheelup binding to execute a button click using the global button names
    -- when mouswheel is scrolled up or down it triggers a button click and runs the onclick kook from SecureHandlerWrapScript gets execute, which then sets the macrotext

    ---@class MainFrame
	local mainframe = CreateFrame("Button", "WLPvP"..playerType, UIParent, "SecureActionButtonTemplate, SecureHandlerEnterLeaveTemplate")
	-- WarLegend: raised at each settings change (SortPlayers(true)); a button carries the one it was set up for
	mainframe.settingsGeneration = 1

	mainframe:SetAttribute("type4", "macro")
	mainframe:SetAttribute("type5", "macro")
	mainframe:RegisterForClicks(GetCVarBool("ActionButtonUseKeyDown") and "AnyDown" or "AnyUp")

	SecureHandlerWrapScript(mainframe,"OnClick",mainframe,[[

		local maxUnits = self:GetAttribute("maxUnits")
		local playerIndex = self:GetAttribute("playerIndex")
		local nextPlayerIndex
		-- WarLegend: before the first scoreboard there is no list yet (the arithmetic below raised an error)
		if not maxUnits or maxUnits < 1 or not playerIndex then return end

		if button == "Button4" then
			nextPlayerIndex = playerIndex -1
			if nextPlayerIndex <1 then
				nextPlayerIndex = maxUnits
			end
		else
			nextPlayerIndex = playerIndex + 1
			if nextPlayerIndex >maxUnits then
				nextPlayerIndex = 1
			end	
		end

		self:SetAttribute("macrotext", self:GetAttribute("playerMacro"..nextPlayerIndex))
		self:SetAttribute("playerIndex", nextPlayerIndex)
	]])

	mainframe.Players = {}            --index = name, value = button(table), contains enemyButtons
	mainframe.CurrentPlayerOrder = {} --index = number, value = playerButton(table)
	mainframe.InactivePlayerButtons = {} --index = number, value = button(table)
	mainframe.NewPlayersDetails = {}  -- index = numeric, value = playerdetails, used for creation of new buttons, use (temporary) table to not create an unnecessary new button if another player left
	mainframe.PlayerType = playerType
	mainframe.PlayerSources = {}
	mainframe.NumPlayers = 0
    mainframe.Counter = {}
	mainframe.Testmode = {
		holdsFlag = false,
		hasFlag = false
	}

	
    mainframe:SetScript("OnEvent", function(self, event, ...)
		if self.db and self.db.profile and self.db.profile.DebugBlizzEvents then
			self:Debug("OnEvent", event, ...)
		end
        self[event](self, ...)
    end)

	-- WarLegend: each shown button every 0.2 s in combat (BattleGroundEnemies used 0.1: half the work with 40 players,
	-- still smooth), 0.4 s out of combat: enemies UpdateAll (range, target, health of a unit without events), allies
	-- their range. One OnUpdate for the side spreads the buttons over the frames (WarLegendPvP.Spread). Fake players
	-- (test mode) have none; nothing while I am dead.
	local function UpdateButtonsInTurn(playerButton)
		if not WarLegendPvP.states.userIsAlive or not playerButton:IsVisible() then return end
		local details = playerButton.PlayerDetails
		if not details or details.isFakePlayer then return end
		if playerButton.PlayerIsEnemy then
			playerButton:UpdateAll()
		elseif playerButton ~= WarLegendPvP.UserButton then
			playerButton:UpdateRangeViaLibRangeCheck(playerButton.unitID)
		else
			playerButton:UpdateRange(true)
		end
	end
	WarLegendPvP.Spread(mainframe, function() return InCombatLockdown() and 0.2 or 0.4 end,
		function() return mainframe.CurrentPlayerOrder end, UpdateButtonsInTurn)


	function mainframe:InitializeAllPlayerSources()
		for sourceName in pairs(WarLegendPvP.consts.PlayerSources) do
			mainframe.PlayerSources[sourceName] = {}
		end
	end

	mainframe:InitializeAllPlayerSources()

	function mainframe:RemoveAllPlayersFromAllSources()
		self:InitializeAllPlayerSources()
		self:AfterPlayerSourceUpdate()
	end

	function mainframe:Debug(...)
		WarLegendPvP:Debug(self.PlayerType, ...)
	end

	function mainframe:RemoveAllPlayersFromSource(source)
		self:BeforePlayerSourceUpdate(source)
		self:AfterPlayerSourceUpdate()
	end

	function mainframe:BeforePlayerSourceUpdate(source)
		self.PlayerSources[source] = {}
	end

	function mainframe:AddPlayerToSource(source, playerT)
		self:Debug("AddPlayerToSource", source, playerT)
		if not playerT.name or issecret(playerT.name) or playerT.name == "" then return end
		if not playerT.classToken or issecret(playerT.classToken) or playerT.classToken == "" then return end

		table_insert(self.PlayerSources[source], playerT)
	end

	-- WarLegend: the entries of a source by their name with spaces ("First-Surname" and "First Surname" are the same
	-- player), made once per source update instead of a scan of the source (a gsub per entry) for each player looked for
	local sourceIndex = setmetatable({}, { __mode = "k" })

	function mainframe:FindPlayerInSource(source, playerT)
		local playerSource = self.PlayerSources[source]
		local wanted = playerT.name and playerT.name:gsub("%-", " ")
		if not wanted then return end
		local index = sourceIndex[playerSource]
		if not index or index.n ~= #playerSource then
			index = { n = #playerSource, byName = {} }
			for i = #playerSource, 1, -1 do -- backwards: the first entry with a name wins, as in the scan
				local name = playerSource[i].name
				if type(name) == "string" then index.byName[(name:gsub("%-", " "))] = playerSource[i] end
			end
			sourceIndex[playerSource] = index
		end
		return index.byName[wanted]
	end

	function mainframe:AfterPlayerSourceUpdate()
		self:Debug("AfterPlayerSourceUpdate")
		local newPlayers = {} --contains combined data from PlayerSources
		if self.PlayerType == WarLegendPvP.consts.PlayerTypes.Enemies then
			if WarLegendPvP:IsTestmodeOrEditmodeActive() then
				newPlayers = self.PlayerSources[WarLegendPvP.consts.PlayerSources.FakePlayers]
			else
				local scoreboardEnemies = self.PlayerSources[WarLegendPvP.consts.PlayerSources.Scoreboard]
				for i = 1, #scoreboardEnemies do
					local scoreboardEnemy = scoreboardEnemies[i]
					table.insert(newPlayers, {
						name = scoreboardEnemy.name,
						raceName = scoreboardEnemy.raceName,
						classToken = scoreboardEnemy.classToken,
						specName = scoreboardEnemy.talentSpec
					})
				end
			end
		else --"Allies"
			local groupMembers = self.PlayerSources[WarLegendPvP.consts.PlayerSources.GroupMembers]
			local numGroupMembers = #groupMembers
			local addWholeGroup = false
			if WarLegendPvP:IsTestmodeOrEditmodeActive() then
				if WarLegendPvP.db.profile.Testmode_UseTeammates then
					addWholeGroup = true
				else
					--just addMyself and fill up the rest with fakeplayers
					-- (UserButton is false until the player's own button exists: then only the fake allies)
					if WarLegendPvP.UserButton and WarLegendPvP.UserButton.PlayerDetails and groupMembers[numGroupMembers] then
						table.insert(newPlayers, groupMembers[numGroupMembers]) --i am always last in here
					end
					local fakeAllies = self.PlayerSources[WarLegendPvP.consts.PlayerSources.FakePlayers]
					for i = 1, #fakeAllies do
						table.insert(newPlayers, fakeAllies[i])
					end
				end
			else
				addWholeGroup = true
			end
			if addWholeGroup then
				for i = 1, numGroupMembers do
					local groupMember = groupMembers[i]
					local specName = groupMember.specName
					if issecret(specName) then specName = nil end
					if not specName or specName == "" then
						local name = groupMember.name
						--self:Debug("player", name, "doesnt have a spec from group member")
						local match = self:FindPlayerInSource(WarLegendPvP.consts.PlayerSources.Scoreboard, groupMember)
						if match then
							--self:Debug("player", name, "we found a spec from the scoreboard")
							groupMember.specName = match.talentSpec
						end
					end
					table.insert(newPlayers, groupMember)
				end
			end
		end
		self:BeforePlayerUpdate()
		for i = 1, #newPlayers do
			local newPlayer = newPlayers[i]
			local name = newPlayer.name
			local raceName = newPlayer.raceName
			local classToken = newPlayer.classToken
			local specName = newPlayer.specName
			local additionalData = newPlayer.additionalData
			self:Debug("AfterPlayer", name, raceName, classToken, specName, additionalData)
			self:CreateOrUpdatePlayerDetails(name, raceName, classToken, specName, additionalData)
		end
		self:SetPlayerCount(#newPlayers)
		self:CreateOrRemovePlayerButtons()
	end

	function mainframe:OnTestOrEditmodeEnabled()
		self.ActiveProfile:Show()
	end

	function mainframe:OnTestOrEditmodeDisabled()
		self:RemoveAllPlayersFromSource(WarLegendPvP.consts.PlayerSources.FakePlayers)
		self.ActiveProfile:Hide()
	end

	function mainframe:OnTestmodeTick()
		for name, playerButton in pairs(self.Players) do
			if playerButton.PlayerDetails.isFakePlayer then
				local numEvents = #testEvents
				local randomEvent = testEvents[math_random(1, numEvents)]
				randomEvent(self, playerButton)
				playerButton:UNIT_HEALTH()

				playerButton:DispatchEvent("OnTestmodeTick")
			end
		end
	end

	function mainframe:OnTestmodeEnabled()
		for playerName, playerButton in pairs(self.Players) do
			playerButton:DispatchEvent("OnTestmodeEnabled")
		end
		self.ActiveProfile:Show()

		if self.CurrentPlayerOrder[1] then
			WarLegendPvP:HandleTargetChanged(self.CurrentPlayerOrder[1])
		end
		if self.CurrentPlayerOrder[2] then
			WarLegendPvP:HandleFocusChanged(self.CurrentPlayerOrder[2])
		end
		self:OnTestOrEditmodeEnabled()
	end

	function mainframe:OnTestmodeDisabled()
		for playerName, playerButton in pairs(self.Players) do
			playerButton:DispatchEvent("OnTestmodeDisabled")
		end
		self:OnTestOrEditmodeDisabled()
	end

	function mainframe:Enable()
		self:Debug("Enable called")
		if InCombatLockdown() then return WarLegendPvP:QueueForUpdateAfterCombat(mainframe, "CheckEnableState") end

		if WarLegendPvP:IsTestmodeOrEditmodeActive() then
		else
			if self.PlayerType == WarLegendPvP.consts.PlayerTypes.Enemies then
				self:Debug("Registered enemy events")
				self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
				self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
			end
		end
		self.enabled = true
		self:Show()
	end

	function mainframe:Disable()
		self:Debug("Disable called")

		if InCombatLockdown() then return WarLegendPvP:QueueForUpdateAfterCombat(mainframe, "CheckEnableState") end
		self:UnregisterAllEvents()

		self.enabled = false
		self:Hide()
	end

	function mainframe:NoActivePlayercountProfile()
		self.playerCountConfig = false
		self:Disable()
	end

	function mainframe:ApplyPlayerCountProfileSettings()
		if InCombatLockdown() then
			return WarLegendPvP:QueueForUpdateAfterCombat(self, "ApplyPlayerCountProfileSettings")
		end

		local conf = self.playerCountConfig
		if not conf then return end



		self:SetPlayerCountJustifyV(conf.BarVerticalGrowdirection)

		self.ActiveProfile:ApplyFontStringSettings(WarLegendPvP.db.profile.PlayerCount.Text)

		self.ActiveProfile:SetText(L[self.PlayerType]..": ".. WarLegendPvP:GetPlayerCountConfigNameLocalized(self.playerCountConfig))


		self:SortPlayers(true) --force repositioning

		self:UpdatePlayerCountText()
		self:CheckEnableState()
	end

	function mainframe:SelectPlayerCountProfile(forceUpdate)
		self.playerTypeConfig = WarLegendPvP.db.profile[self.PlayerType]
		local maxNumPlayers = math_max(self.NumPlayers or 0)
		self:Debug("SelectPlayerCountProfile", maxNumPlayers)
		if not maxNumPlayers then return end
		if maxNumPlayers == 0 then return self:NoActivePlayercountProfile() end

		if maxNumPlayers > 40 then return self:NoActivePlayercountProfile() end

		local playerCountConfigs = self.playerTypeConfig.playerCountConfigs

		local foundProfilesForPlayerCount = {}
		for i = 1, #playerCountConfigs do
			local playerCountProfile = playerCountConfigs[i]
			local minPlayerCount = playerCountProfile.minPlayerCount
			local maxPlayerCount = playerCountProfile.maxPlayerCount

			if maxNumPlayers <= maxPlayerCount and maxNumPlayers >= minPlayerCount then
				table.insert(foundProfilesForPlayerCount, playerCountProfile)
			end
		end

		if #foundProfilesForPlayerCount == 0 then
			self:NoActivePlayercountProfile()
			return
			--return WarLegendPvP:Information("Can't find a profile for the current player count of " .. self.NumPlayers .." players for "..self.PlayerType.." please check the settings")
		end

		if #foundProfilesForPlayerCount > 1 then
			local overlappingProfilesString = ""
			for i = 1, #foundProfilesForPlayerCount do
				local overlappingIndexShownName = WarLegendPvP:GetPlayerCountConfigNameLocalized(foundProfilesForPlayerCount[i])
				overlappingProfilesString = overlappingProfilesString .. "and " .. overlappingIndexShownName
			end
			self:NoActivePlayercountProfile()
			WarLegendPvP:Information("Found multiple player count profiles fitting the current player count for "..self.PlayerType.." please check your settings and make sure they don't overlap")
			WarLegendPvP:Information("The following profiles are overlapping: "..overlappingProfilesString)

			return
		end



		if forceUpdate or foundProfilesForPlayerCount[1] ~= self.playerCountConfig then
			self.playerCountConfig = foundProfilesForPlayerCount[1]
			self:ApplyPlayerCountProfileSettings()
		end
	end

	function mainframe:CheckEnableState()
		self:Debug("CheckEnableState")
		if not WarLegendPvP.enabled then return self:Disable() end
		if self.playerTypeConfig.Enabled and self.playerCountConfig and self.playerCountConfig.Enabled then
			self:Enable()
		else
			self:Disable()
		end
	end

	function mainframe:SetRealPlayerCount(realCount)
		self:Debug("SetRealPlayerCount", realCount)
		self.RealPlayerCount = realCount
		self:UpdatePlayerCountText()
	end

	function mainframe:SetPlayerCount(count)
		local oldCount = self.NumPlayers
		self.NumPlayers = count
		if not oldCount or oldCount ~= count then
			self:SelectPlayerCountProfile()
		end
		self:UpdatePlayerCountText()
	end

	function mainframe:UpdatePlayerCountText()
		self.PlayerCount:ApplyFontStringSettings(WarLegendPvP.db.profile.PlayerCount.Text)
		local maxNumPlayers = math_max(self.RealPlayerCount or 0, self.NumPlayers or 0)


		local isEnemy = self.PlayerType == WarLegendPvP.consts.PlayerTypes.Enemies
		self:Debug("UpdatePlayerCountText", maxNumPlayers, isEnemy)


		-- WarLegend: 0 is the Horde, 1 the Alliance (GetBattlefieldArenaFaction): the fallback had them the other way round
		WarLegendPvP:SetAllyFaction(WarLegendPvP.AllyFaction or (WarLegendPvP.UserFaction == "Horde" and 0 or 1))

		if self.playerCountConfig and self.playerCountConfig.PlayerCount.Enabled then
			self.PlayerCount:Show()
			self.PlayerCount:SetText(format(isEnemy == (WarLegendPvP.EnemyFaction == 0) and PLAYER_COUNT_HORDE or PLAYER_COUNT_ALLIANCE, maxNumPlayers))
		else
			self.PlayerCount:Hide()
		end
	end

	-- WoW Forever: the unit name can be secret or come in another form (see FindPlayerInTable in Main.lua)
	function mainframe:GetPlayerbuttonByUnitID(unitID)
		return WarLegendPvP.FindPlayerInTable(self.Players, WarLegendPvP:GetReadableUnitName(unitID))
	end

	function mainframe:GetRandomPlayer()
		local t = {}
		for playerName, playerButton in pairs(self.Players) do
			table.insert(t, playerButton)
		end
		local numPlayers = #t
		if numPlayers > 0 then
			return t[math_random(1, numPlayers)]
		end
	end

	function mainframe:SetPlayerCountJustifyV(direction)
		if direction == "downwards" then
			self.PlayerCount:SetJustifyV("BOTTOM")
		else
			self.PlayerCount:SetJustifyV("TOP")
		end
	end

	function mainframe:SetupButtonForNewPlayer(playerDetails)
		local playerButton = self.InactivePlayerButtons[#self.InactivePlayerButtons]
		if playerButton then --recycle a previous used button
			table_remove(self.InactivePlayerButtons, #self.InactivePlayerButtons)
			--Cleanup previous shown stuff of another player
			playerButton.MyTarget:Hide() --reset possible shown target indicator frame
			playerButton.MyFocus:Hide() --reset possible shown target indicator frame

			for moduleName, moduleFrameOnButton in pairs(WarLegendPvP.ButtonModules) do
				if playerButton[moduleName] and playerButton[moduleName].Reset then
					playerButton[moduleName]:Reset()
				end
			end


			if playerButton.UnitIDs then
				wipe(playerButton.UnitIDs.TargetedByEnemy)
				playerButton:UpdateTargetIndicators()
				playerButton:DeleteActiveUnitID()
			end
			-- WarLegend: the old player's target, level and death state go too (they stayed on the button)
			if playerButton.Target then playerButton:IsNoLongerTarging(playerButton.Target) end
			playerButton.PlayerLevel = nil
			if playerButton.isDead then playerButton:PlayerIsAlive() end
		else --no recycleable buttons remaining => create a new one
			self.buttonCounter = (self.buttonCounter or 0) + 1
			playerButton = WarLegendPvP:CreatePlayerButton(self, self.buttonCounter)
		end

		playerButton.UnitIDs = { TargetedByEnemy = {}, HasAllyUnitID = false}
		playerButton.hasFlag = false
		playerButton.unitID = nil
		playerButton.unit = nil

		playerButton.PlayerDetails = playerDetails
		-- WarLegend: a button not set up for the current settings gets its modules and click bindings from the
		-- ApplyButtonSettings of ButtonPositioning: done once, not twice (40 buttons at the first scoreboard)
		if playerButton.settingsGeneration == self.settingsGeneration then
			playerButton:PlayerDetailsChanged()
		end

		self.Target = nil

		-- WarLegend: the range / UpdateAll of every 0.2 s is done for all the buttons of the side by one OnUpdate
		-- (UpdateButtonsInTurn below), no more one per button
		if playerButton.PlayerIsEnemy then
			playerButton:UpdateRange(false)
		else
			playerButton:UpdateRange(true)
		end


		playerButton:Show()



		self.Players[playerButton.PlayerDetails.PlayerName] = playerButton

		return playerButton
	end

	function mainframe:RemovePlayer(playerButton)
		if playerButton == WarLegendPvP.UserButton then return end -- dont remove the Player itself

		local targetEnemyButton = playerButton.Target
		if targetEnemyButton then -- if that no longer exiting ally targeted something update the button of its target
			playerButton:IsNoLongerTarging(targetEnemyButton)
		end

		playerButton:Hide()

		table_insert(self.InactivePlayerButtons, playerButton)
		self.Players[playerButton.PlayerDetails.PlayerName] = nil
	end

	function mainframe:RemoveAllPlayers()
		for playerName, playerButton in pairs(self.Players) do
			self:RemovePlayer(playerButton)
		end
		self:SortPlayers()
	end

	function mainframe:GetPrevioiusPlayer()
		local currentTarget = WarLegendPvP.currentTarget

		local currentTargetIndex
		for i = 1, #self.CurrentPlayerOrder do
			local player = self.CurrentPlayerOrder[i]
			if player == currentTarget then
				currentTargetIndex = i
				break
			end
		end
		local newTargetIndex = (currentTargetIndex or 0) -1
		if newTargetIndex < 1 then
			newTargetIndex = #self.CurrentPlayerOrder
		end
		return newTargetIndex, self.CurrentPlayerOrder[newTargetIndex]
	end

	function mainframe:GetNextPlayer()
		local currentTarget = WarLegendPvP.currentTarget

		local currentTargetIndex
		for i = 1, #self.CurrentPlayerOrder do
			local player = self.CurrentPlayerOrder[i]
			if player == currentTarget then
				currentTargetIndex = i
				break
			end
		end
		local newTargetIndex = (currentTargetIndex or 0) + 1
		if newTargetIndex >#self.CurrentPlayerOrder then
			newTargetIndex = 0
		end
		return newTargetIndex, self.CurrentPlayerOrder[newTargetIndex]
	end

	function mainframe:SetUpBindings()
		--self:Debug("SetUpBindings", self.PlayerType)
		local maxPlayers = #self.CurrentPlayerOrder
		self:SetAttribute("maxUnits", maxPlayers)
		for j = 1, #self.CurrentPlayerOrder do
			self:SetAttribute("playerMacro"..j, WarLegendPvP.GetTargetMacro(self.CurrentPlayerOrder[j].PlayerDetails.PlayerName))
		end

		self:SetAttribute("playerIndex",1)


		if WarLegendPvP.db.profile.EnableMouseWheelPlayerTargeting then
			--SecureHandlerEnterLeaveTemplate ads _onenter and _onleave functionality
			mainframe:EnableMouseWheel(true)
			mainframe:SetAttribute("_onenter",[[
				self:SetBindingClick(true, "MOUSEWHEELUP",self:GetName(), "Button4")
				self:SetBindingClick(true, "MOUSEWHEELDOWN",self:GetName(), "Button5")
			]])
			-- onleave, clear override binding
			mainframe:SetAttribute("_onleave",[[
				self:ClearBindings()
			]])
		else
			mainframe:EnableMouseWheel(false)
			mainframe:SetAttribute("_onenter",nil)
			-- onleave, clear override binding
			mainframe:SetAttribute("_onleave",nil)
		end




		--button:SetAttribute("type1", "macro")
	end

	function mainframe:ButtonPositioning()
		self:Debug("ButtonPositioning")
		local orderedPlayers = self.CurrentPlayerOrder

		local config = self.playerCountConfig
		if not config then return end
		local columns = config.BarColumns


		local barHeight = config.BarHeight
		local barWidth = config.BarWidth

		local verticalSpacing = config.BarVerticalSpacing
		local horizontalSpacing = config.BarHorizontalSpacing

		local growDownwards = (config.BarVerticalGrowdirection == "downwards")
		local growRightwards = (config.BarHorizontalGrowdirection == "rightwards")

		local playerCount = #orderedPlayers

		local rowsPerColumn = math.ceil(playerCount / columns)

		local offsetX, offsetY

		local point, offsetDirectionX, offsetDirectionY = Data.Helpers.getContainerAnchorPointForConfig(growRightwards, growDownwards)

		self:SetScale(WarLegendPvP.SafeScale(config.Framescale))
		self:ClearAllPoints()

		local scale = self:GetEffectiveScale()

		self:SetPoint(point, UIParent, "BOTTOMLEFT", config.Position_X / scale, config.Position_Y / scale)

		local column = 1
		local row = 1

		for i = 1, playerCount do
			local playerButton = orderedPlayers[i]
			if playerButton then --should never be nil
				playerButton.position = i
				if column > 1 then
					offsetX = (column - 1) * (barWidth + horizontalSpacing) * offsetDirectionX
				else
					offsetX = 0
				end

				if row > 1 then
					offsetY = (row - 1) * (barHeight + verticalSpacing) * offsetDirectionY
				else
					offsetY = 0
				end


				playerButton:ClearAllPoints()
				playerButton:SetPoint(point, self, point, offsetX, offsetY)

				-- WarLegend: the settings only when they changed or the button never had them; a new order (a player
				-- joins or leaves, 40 times while a raid forms) only moves the buttons. Marked once the button has a
				-- place: SetModulePositions waits for one, it is tried again until then
				if playerButton.settingsGeneration ~= self.settingsGeneration then
					playerButton:ApplyButtonSettings()
					if playerButton:GetRect() then playerButton.settingsGeneration = self.settingsGeneration end
				end

				if row < rowsPerColumn then
					row = row + 1
				else
					column = column + 1
					row = 1
				end
			end
		end
		if playerCount > 0 then
			local lastButton = orderedPlayers[playerCount]
			local firstButton = orderedPlayers[1]

			local topButton
			local bottomButton

			if growDownwards then
				topButton = firstButton
				bottomButton = lastButton
			else
				topButton = lastButton
				bottomButton = firstButton
			end
			self:SetSize(barWidth, topButton:GetTop() - bottomButton:GetBottom())
		end
	end

	function mainframe:BeforePlayerUpdate()
		wipe(self.NewPlayersDetails)
	end

	function mainframe:CreateOrUpdatePlayerDetails(name, race, classToken, specName, additionalData)
		if issecret(name) or issecret(classToken) then return end
		if issecret(specName) then specName = nil end
		if issecret(race) then race = nil end
		local spec = false
		if specName and specName ~= "" then
			spec = specName
		end
		local specData
		if classToken and spec then
			local t = Data.Classes[classToken]
			if t then
				specData = t[spec]
			end
		end

		local playerDetails = {
			PlayerName = name,
			PlayerClass = string.upper(classToken),                  --apparently it can happen that we get a lowercase "druid" from GetBattlefieldScore() in TBCC, IsTBCC
			PlayerClassColor = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[classToken],
			PlayerSpecName = spec,                                 --set to false since we use Mixin() and Mixin doesnt mixin nil values and therefore we dont overwrite values with nil
			PlayerRole = specData and specData.roleID,
			PlayerLevel = false,
			isFakePlayer = false --to set a base value, might be overwritten by mixin
		}
		if additionalData then
			Mixin(playerDetails, additionalData)
		end

		-- self:Debug("CreateOrUpdatePlayerDetails", name, race, classToken, specName, additionalData)
		local playerButton = self.Players[name]
		if playerButton then --already existing
			local currentDetails = playerButton.PlayerDetails
			local detailsChanged = false

			-- WarLegend: only who the player is counts; the unit, GUID and leader / assistant of a raid member move at
			-- every roster change and are just kept (a change re-applies the modules and click bindings of the button)
			for i = 1, #IDENTITY_DETAILS do
				local k = IDENTITY_DETAILS[i]
				if playerDetails[k] ~= currentDetails[k] then
					detailsChanged = true
					break
				end
			end
			playerButton.PlayerDetails = playerDetails

			if detailsChanged then
				playerButton:PlayerDetailsChanged()
			end

			playerButton.status = 1 --1 means found, already existing
			playerDetails = playerButton.PlayerDetails
		else
			table.insert(self.NewPlayersDetails, playerDetails)
		end
	end

	function mainframe:CreateOrRemovePlayerButtons()
		local inCombat = InCombatLockdown()
		local existingPlayersCount = 0
		for playerName, playerButton in pairs(self.Players) do
			if playerButton.status == 2 then --no longer existing
				if inCombat then
					return WarLegendPvP:QueueForUpdateAfterCombat(self, "AfterPlayerSourceUpdate")
				else
					self:RemovePlayer(playerButton)
				end
			else -- == 1 -- set to 2 for the next comparison
				playerButton.status = 2
				existingPlayersCount = existingPlayersCount + 1
			end
		end

		for i = 1, #self.NewPlayersDetails do
			local playerDetails = self.NewPlayersDetails[i]
			if inCombat then
				return WarLegendPvP:QueueForUpdateAfterCombat(self, "AfterPlayerSourceUpdate")
			else
				local playerButton = self:SetupButtonForNewPlayer(playerDetails)
				playerButton.status = 2
			end
		end
		self:SortPlayers(false)
	end

	do
		local BlizzardsSortOrder = {}
		for i = 1, #CLASS_SORT_ORDER do        -- Constants.lua
			BlizzardsSortOrder[CLASS_SORT_ORDER[i]] = i --key = ENGLISH CLASS NAME, value = number
		end

		-- WarLegend: the role order is read once per setting (it was split into two new tables at each comparison:
		-- about 300 per sort of 40 players, at each scoreboard update and roster event)
		local roleOrderKey, roleOrder
		local function RoleOrder()
			--WarLegendPvP.db.profile.RoleSortingOrder is somethng like "HEALER_TANK_DAMAGER"
			local key = WarLegendPvP.db.profile.RoleSortingOrder
			if key ~= roleOrderKey or not roleOrder then
				roleOrder = {}
				for k, v in pairs({strsplit("_", key)}) do
					roleOrder[v] = k
				end
				roleOrderKey = key
			end
			return roleOrder
		end

		local function PlayerSortingByRoleClassName(playerA, playerB) -- a and b are playerButtons
			local detailsPlayerA = playerA.PlayerDetails
			local detailsPlayerB = playerB.PlayerDetails

			local reverseRoleT = RoleOrder()

			local roleSortingNumerPlayerA = reverseRoleT[detailsPlayerA.PlayerRole]
			local roleSortingNumerPlayerB = reverseRoleT[detailsPlayerB.PlayerRole]

			if roleSortingNumerPlayerA and roleSortingNumerPlayerB then
				if roleSortingNumerPlayerA == roleSortingNumerPlayerB then
					if BlizzardsSortOrder[detailsPlayerA.PlayerClass] == BlizzardsSortOrder[detailsPlayerB.PlayerClass] then
						if detailsPlayerA.PlayerName < detailsPlayerB.PlayerName then return true end
					elseif BlizzardsSortOrder[detailsPlayerA.PlayerClass] < BlizzardsSortOrder[detailsPlayerB.PlayerClass] then
						return true
					end
				elseif roleSortingNumerPlayerA < roleSortingNumerPlayerB then
					return true
				end
			else
				if BlizzardsSortOrder[detailsPlayerA.PlayerClass] == BlizzardsSortOrder[detailsPlayerB.PlayerClass] then
					if detailsPlayerA.PlayerName < detailsPlayerB.PlayerName then return true end
				elseif BlizzardsSortOrder[detailsPlayerA.PlayerClass] < BlizzardsSortOrder[detailsPlayerB.PlayerClass] then
					return true
				end
			end
		end

		function mainframe:SortPlayers(forceRepositioning)
			--self:Debug("SortPlayers", self.PlayerType)
			local newPlayerOrder = {}
			for playerName, playerButton in pairs(self.Players) do
				-- self:Debug(playerName)
				table.insert(newPlayerOrder, playerButton)
			end
			--[[
			self:Debug("before sorting")
			for i = 1, #newPlayerOrder do
				self:Debug(i, newPlayerOrder[i].PlayerDetails.PlayerName)
			end

 ]]

			table.sort(newPlayerOrder, PlayerSortingByRoleClassName)

			local orderChanged = false
			for i = 1, math_max(#newPlayerOrder, #self.CurrentPlayerOrder) do --players can leave or join so #self.CurrentPlayerOrder can be unequal to #newPlayerOrder
				if newPlayerOrder[i] ~= self.CurrentPlayerOrder[i] then
					orderChanged = true
					break
				end
			end

			-- WarLegend: new settings for every button; and a button without the current ones (new, or kept aside while
			-- they changed) is set up by ButtonPositioning even when the order did not change
			if forceRepositioning then self.settingsGeneration = self.settingsGeneration + 1 end
			if not orderChanged then
				for i = 1, #newPlayerOrder do
					if newPlayerOrder[i].settingsGeneration ~= self.settingsGeneration then
						orderChanged = true
						break
					end
				end
			end

			--[[ 			self:Debug("after sorting")
			for i = 1, #newPlayerOrder do
				self:Debug(i, newPlayerOrder[i].PlayerDetails.PlayerName)
			end ]]


			if orderChanged or forceRepositioning then
				local inCombat = InCombatLockdown()
				if inCombat then
					return WarLegendPvP:QueueForUpdateAfterCombat(self, "AfterPlayerSourceUpdate")
				end
				self.CurrentPlayerOrder = newPlayerOrder
				self:ButtonPositioning()
				self:SetUpBindings()
			end
		end
	end


	mainframe:SetClampedToScreen(true)
	mainframe:SetMovable(true)
	mainframe:SetUserPlaced(true)
	mainframe:SetResizable(true)
	mainframe:SetToplevel(true)

	mainframe.PlayerCount = WarLegendPvP.MyCreateFontString(mainframe)
	mainframe.PlayerCount:SetPoint("BOTTOMLEFT", mainframe, "TOPLEFT")
	mainframe.PlayerCount:SetPoint("BOTTOMRIGHT", mainframe, "TOPRIGHT")
	mainframe.PlayerCount:SetHeight(30)
	mainframe.PlayerCount:SetJustifyH("LEFT")
	mainframe.PlayerCount:SetJustifyV("MIDDLE")

	mainframe.ActiveProfile = WarLegendPvP.MyCreateFontString(mainframe)
	mainframe.ActiveProfile:SetPoint("BOTTOMLEFT", mainframe.PlayerCount, "TOPLEFT")
	mainframe.ActiveProfile:SetPoint("BOTTOMRIGHT", mainframe.PlayerCount, "TOPRIGHT")
	mainframe.ActiveProfile:SetHeight(30)
	mainframe.ActiveProfile:SetJustifyH("LEFT")
	mainframe.ActiveProfile:SetJustifyV("MIDDLE")
	mainframe.ActiveProfile:Hide()

    return mainframe
end

---@class WarLegendPvP.Allies: MainFrame
WarLegendPvP.Allies = CreateMainFrame(WarLegendPvP.consts.PlayerTypes.Allies)
WarLegendPvP.Allies.GUIDToAllyname = {}


---@class WarLegendPvP.Enemies: MainFrame
WarLegendPvP.Enemies = CreateMainFrame(WarLegendPvP.consts.PlayerTypes.Enemies)
WarLegendPvP.Enemies.Counter = {}

-- WarLegend: the buttons are made a few per frame out of combat as soon as this addon is loaded (the queue pops),
-- hidden in InactivePlayerButtons, so the first scoreboard of the battleground does not create 80 of them at once
do
	local PRECREATE_MAX, PER_FRAME = 40, 2
	local precreate = CreateFrame("Frame")
	precreate:SetScript("OnUpdate", function(self)
		if InCombatLockdown() or not WarLegendPvP.db then return end
		local done = true
		for _, mainframe in ipairs({ WarLegendPvP.Allies, WarLegendPvP.Enemies }) do
			for _ = 1, PER_FRAME do
				if (mainframe.buttonCounter or 0) >= PRECREATE_MAX then break end
				done = false
				mainframe.buttonCounter = (mainframe.buttonCounter or 0) + 1
				table_insert(mainframe.InactivePlayerButtons, 1, WarLegendPvP:CreatePlayerButton(mainframe, mainframe.buttonCounter))
			end
		end
		if done then self:SetScript("OnUpdate", nil); self:Hide() end
	end)
end


function WarLegendPvP.Allies:AddGroupMember(name, isLeader, isAssistant, classToken, unitID)
	local raceName, raceFile, raceID = UnitRace(unitID)
	local GUID = UnitGUID(unitID)

	if not GUID or issecret(GUID) then return end

	if name and raceName and classToken then
		local specName = WarLegendPvP.specCache[GUID]

		self:AddPlayerToSource(WarLegendPvP.consts.PlayerSources.GroupMembers, {
			name = name,
			raceName = raceName,
			classToken = classToken,
			specName = specName,
			additionalData = {
				isGroupLeader = isLeader,
				isGroupAssistant = isAssistant,
				GUID = GUID,
				unitID = unitID
			}
		})
	end

	self.GUIDToAllyname[GUID] = name

	if isLeader then
		self.groupLeader = name
	end
	if isAssistant then
		table_insert(self.assistants, name)
	end
end

function WarLegendPvP.Allies:UpdateAllUnitIDs()
	--it happens that numGroupMembers is higher than the value of the maximal players for that battleground, for example 15 in a 10 man bg, thats why we wipe AllyUnitIDToAllyDetails
	local sortNeeded = false -- WarLegend: one sort after the loop, not one per ally whose unit changed
	for allyName, allyButton in pairs(self.Players) do
		local unitID
		local targetUnitID
		if allyButton then
			if allyButton.PlayerDetails.unitID ~= "player" then
				-- WarLegend: an ally without a unit yet is skipped, the loop goes on (it returned: the others kept
				-- their old unit)
				unitID = allyButton.PlayerDetails.unitID
				targetUnitID = unitID and unitID .. "target"
			else
				unitID = "player"
				targetUnitID = "target"
				WarLegendPvP.UserButton = allyButton
			end
		end
		if unitID and targetUnitID then
			--self.unitID already gets assigned for allies before, info from GROUP_ROSTER_UPDATE

			local changed = allyButton.unit ~= unitID
			if changed then
				--ally has a new unitID now
				-- WarLegend: in combat only the secure part waits (unit attribute, order); the loop goes on, so every
				-- ally's range, power, auras and target follow its new unit now, not after the fight
				if InCombatLockdown() then --GROUP_ROSTER_UPDATE also has a combat check and will get called after combat
					WarLegendPvP:QueueForUpdateAfterCombat(WarLegendPvP[allyButton.PlayerType], "UpdateAllUnitIDs")
				else
					allyButton.unit = unitID
					allyButton:SetAttribute('unit', unitID)
					sortNeeded = true
				end
			end

			allyButton:UpdateUnitID(unitID, targetUnitID)

			-- WarLegend: reset the TargetedByEnemy once the ally's target unit is the new one, so the enemy it targets
			-- reads that unit (was targetButton:IsNoLongerTarging(targetButton): the enemy button targeted itself)
			local targetButton = changed and allyButton.Target
			if targetButton then
				allyButton:IsNoLongerTarging(targetButton)
				allyButton:IsNowTargeting(targetButton)
			end
		end
	end
	if sortNeeded then self:SortPlayers() end
end

-- key = nameplate unitID, value = playerButton; the name of a removed nameplate may no longer be readable
WarLegendPvP.Enemies.NameplateButtons = {}

function WarLegendPvP.Enemies:NAME_PLATE_UNIT_ADDED(unitID)
	local enemyButton = self:GetPlayerbuttonByUnitID(unitID)
	if enemyButton then
		self.NameplateButtons[unitID] = enemyButton
		enemyButton:UpdateEnemyUnitID("Nameplate", unitID)
	end
end

function WarLegendPvP.Enemies:NAME_PLATE_UNIT_REMOVED(unitID)
	local enemyButton = self.NameplateButtons[unitID] or self:GetPlayerbuttonByUnitID(unitID)
	self.NameplateButtons[unitID] = nil
	if enemyButton and enemyButton.UnitIDs and enemyButton.UnitIDs.Nameplate == unitID then
		enemyButton:UpdateEnemyUnitID("Nameplate", false)
	end
end

