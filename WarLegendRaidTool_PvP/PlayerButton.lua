---@type string
local AddonName = ...
---@class Data
local Data = select(2, ...)
local issecret = issecretvalue or function() return false end -- WoW Forever secret values

---@class WarLegendPvP
local WarLegendPvP = WarLegendPvP
local L = Data.L

---@class PlayerDetails: table
---@field PlayerName string
---@field PlayerClass string
---@field PlayerSpecName string
---@field PlayerSpecID number
---@field PlayerRole string
---@field PlayerRoleID number
---@field isFakePlayer boolean
---@field unitID UnitToken?


--WoW API
local C_PvP = C_PvP
local CreateFrame = CreateFrame
local GetTime = GetTime
local InCombatLockdown = InCombatLockdown
local IsItemInRange = IsItemInRange
local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost

--lua
local _G = _G
local math_floor = math.floor
local math_random = math.random
local math_min = math.min
local pairs = pairs
local print = print
local table_insert = table.insert
local table_remove = table.remove
local time = time
local type = type
local unpack = unpack

--Libs
local LRC = LibStub("LibRangeCheck-3.0")



---@class UnitIds
---@field Nameplate UnitToken?
---@field Target UnitToken?
---@field Focus UnitToken?
---@field Ally UnitToken?
---@field HasAllyUnitID boolean
---@field TargetedByEnemy table<PlayerButton, boolean>

function WarLegendPvP:CreatePlayerButton(mainframe, num)
	--local playerButton = CreateFrame('Button', "WarLegendPvP" .. mainframe.PlayerType .. "frame" ..num, mainframe)


	---@class PlayerButton: Button
	---@field PlayerType string
	---@field PlayerIsEnemy boolean
	---@field MainFrame MainFrame
	---@field ButtonEvents table<string, table>
	---@field PlayerDetails PlayerDetails
	---@field unitID UnitToken?
	---@field TargetUnitID UnitToken?
	---@field UnitIDs UnitIds
	---@field unit UnitToken?
	---@field status number
	---@field position number?
	---@field Name MyFontString
	---@field Role Role
	---@field MyTarget BackdropTemplate
	---@field MyFocus BackdropTemplate
	---@field healthBar StatusBar
	---@field Power StatusBar
	local playerButton = CreateFrame('Button', "WarLegendPvP" .. mainframe.PlayerType .. "frame" ..num, mainframe, 'SecureUnitButtonTemplate')
	playerButton:RegisterForClicks('AnyUp')
	playerButton:SetPropagateMouseMotion(true) --to send the mouse wheel event to the other frame behind it (the mainframe)
	playerButton:Hide()
	-- setmetatable(playerButton, self)
	-- self.__index = self


	playerButton.ButtonEvents = playerButton.ButtonEvents or {}

	playerButton.PlayerType = mainframe.PlayerType
	playerButton.PlayerIsEnemy = playerButton.PlayerType == WarLegendPvP.consts.PlayerTypes.Enemies
	playerButton.MainFrame = mainframe

	playerButton:SetScript("OnSizeChanged", function(self, width, height)
		self:DispatchEvent("PlayerButtonSizeChanged", width, height)
	end)


	function playerButton:GetOppositeMainFrame()
		if self.PlayerType == WarLegendPvP.consts.PlayerTypes.Enemies then
			return WarLegendPvP.Allies
		else
			return WarLegendPvP.Enemies
		end
	end

	function playerButton:Debug(...)
		return WarLegendPvP:Debug(self.PlayerDetails and self.PlayerDetails.PlayerName, ...)
	end

	function playerButton:OnDragStart()
		if InCombatLockdown() then
			return WarLegendPvP:Debug("OnDragStart called in combat, ignoring")
		end
		return WarLegendPvP.db.profile.Locked or self:GetParent():StartMoving()
	end

	function playerButton:OnDragStop()
		local parent = self:GetParent()
		if not parent then return end
		if InCombatLockdown() then
			return WarLegendPvP:Debug("OnDragStop called in combat, ignoring")
		end
		parent:StopMovingOrSizing()

		local scale = self:GetEffectiveScale()

		local growDownwards = (self.playerCountConfig.BarVerticalGrowdirection == "downwards")
		local growRightwards = (self.playerCountConfig.BarHorizontalGrowdirection == "rightwards")

		if growDownwards then
			self.playerCountConfig.Position_Y = parent:GetTop() * scale
		else
			self.playerCountConfig.Position_Y = parent:GetBottom() * scale
		end

		if growRightwards then
			self.playerCountConfig.Position_X = parent:GetLeft() * scale
		else
			self.playerCountConfig.Position_X = parent:GetRight() * scale
		end
		-- kept in WarLegendRaidTool_PvPDB, the same place for every player count
		WarLegendPvP:SavePosition(self.PlayerType, self.playerCountConfig.Position_X, self.playerCountConfig.Position_Y)
	end

	function playerButton:UpdateAll(temporaryUnitID)
		local updateStuffWithEvents = false --only update health, power, etc for players that dont get events for that or that dont have a unitID assigned
		local unitID
		if temporaryUnitID then
			updateStuffWithEvents = true
			unitID = temporaryUnitID
		else
			if self.unitID then
				unitID = self.unitID
				if self.UnitIDs.HasAllyUnitID then
					updateStuffWithEvents = true
				end
			end
		end
		--WarLegendPvP:Debug("UpdateAll", unitID, updateStuffWithEvents)
		if not unitID then return end
		--WarLegendPvP:Debug("UpdateAll", 1)

		if not UnitExists(unitID) then return end

		--this further checks dont seem necessary since they dont seem to rule out any other unitiDs (all unit ids that exist also are a button and are also this frame)


		--[[ WarLegendPvP:Debug("UpdateAll", 2)

		local playerButton = WarLegendPvP:GetPlayerbuttonByUnitID(unitID)

		if not playerButton then return end
		WarLegendPvP:Debug("UpdateAll", 3)
		if playerButton ~= self then return	end
		WarLegendPvP:Debug("UpdateAll", 4) ]]


		if updateStuffWithEvents then
			self:UNIT_POWER_FREQUENT(unitID)
			self:UNIT_HEALTH(unitID)
		end

		self:UpdateRangeViaLibRangeCheck(unitID)
		self:UpdateTarget()
	end

	function playerButton:GetSpecData()
		if not self.PlayerDetails then return end
		if self.PlayerDetails.PlayerClass and self.PlayerDetails.PlayerSpecName then
			local t = Data.Classes[self.PlayerDetails.PlayerClass]
			if t then
				t = t[self.PlayerDetails.PlayerSpecName]
				return t
			end
		end
	end

	-- WarLegend: the modules' settings put a full health bar and no mark: the unit's values are read again (the
	-- next unit update used to do it; since it stops early for an unchanged unit, a dead ally showed a full bar)
	function playerButton:RefreshAfterSettings()
		if not self.unitID then return end -- test mode players keep their made-up values and marks
		self:UpdateAll(self.unitID)
		self:UpdateRaidTargetIcon()
	end

	function playerButton:PlayerDetailsChanged()
		self:SetBindings()
		self:ApplyModuleSettings()
		self:RefreshAfterSettings()
	end

	function playerButton:UpdateRaidTargetIcon(forceIndex)
		local unit = self:GetUnitID()
		local newIndex = forceIndex --used for testmode, otherwise it will just be nil and overwritten when one actually exists
		if unit then
			newIndex = GetRaidTargetIndex(unit)
			-- SecretReturns (warcraft.wiki.gg): SetRaidTargetIconTexture does arithmetic on it, so no icon when secret
			if issecret(newIndex) then newIndex = nil end
		end
		self.RaidTargetIconIndex = newIndex
		self:DispatchEvent("UpdateRaidTargetIcon", self.RaidTargetIconIndex)
	end

	function playerButton:UpdateUnitID(unitID, targetUnitID)
		if not UnitExists(unitID) then return end
		-- WarLegend: the same unit and target unit again (each roster read for every ally, twice per target switch of
		-- an ally for the enemy): no full update and no UnitIdUpdate for the modules (the cast bar registers its events
		-- again, the aura containers are rebuilt); the periodic UpdateAll keeps the values fresh
		local same = unitID == self.unitID and targetUnitID == self.TargetUnitID
		self.unitID = unitID
		self.TargetUnitID = targetUnitID
		if self.PlayerIsEnemy then
			if same then return end
		elseif self:GetAttribute("unit") ~= unitID and self.config then
			self:SetBindings() -- an ally's unit changed (raid roster): the unit attribute follows (after combat if needed)
		end
		if same then return end
		self:UpdateRaidTargetIcon() -- allies too: a mark placed before the frames existed showed only at the next change
		self:UpdateAll(unitID)
		self:DispatchEvent("UnitIdUpdate", unitID)
	end

	function playerButton:SetModuleConfig(moduleName)
		local moduleFrameOnButton = self[moduleName]
		local moduleConfigOnButton = {}

		if not self.playerCountConfig then return end

		local playerSizeModuleConfig = self.playerCountConfig.ButtonModules[moduleName]

		local globalModuleConfig = WarLegendPvP.db.profile.ButtonModules[moduleName] or {}

		Mixin(moduleConfigOnButton, globalModuleConfig, playerSizeModuleConfig)


		if moduleConfigOnButton.Enabled and WarLegendPvP:IsModuleEnabledOnThisExpansion(moduleName) then
			moduleFrameOnButton.Enabled = true
		else
			moduleFrameOnButton.Enabled = false
		end
		moduleFrameOnButton.config = moduleConfigOnButton
	end

	function playerButton:SetAllModuleConfigs()
		for moduleName, moduleFrame in pairs(WarLegendPvP.ButtonModules) do
			self:SetModuleConfig(moduleName)
		end
	end

	function playerButton:CallExistingFuncOnAllButtonModuleFrames(funcName, ...)
		for moduleName, moduleFrame in pairs(WarLegendPvP.ButtonModules) do
			local moduleFrameOnButton = self[moduleName]
			if moduleFrameOnButton then
				if moduleFrameOnButton and type(moduleFrameOnButton[funcName]) == "function" then
					moduleFrameOnButton[funcName](moduleFrameOnButton, ...)
				end
				end
		end
	end

	function playerButton:CallExistingFuncOnAllEnabledButtonModuleFrames(funcName, ...)
		for moduleName, moduleFrame in pairs(WarLegendPvP.ButtonModules) do
			local moduleFrameOnButton = self[moduleName]
			if moduleFrameOnButton then
				if moduleFrameOnButton.Enabled then
					if type(moduleFrameOnButton[funcName]) == "function" then
						moduleFrameOnButton[funcName](moduleFrameOnButton, ...)
					end
				end
			end
		end
	end

	function playerButton:CallFuncOnAllButtonModuleFrames(func)
		for moduleName, moduleFrame in pairs(WarLegendPvP.ButtonModules) do
			local moduleFrameOnButton = self[moduleName]
			if moduleFrameOnButton then
				func(self, moduleFrameOnButton)
 			end
		end
	end

	function playerButton:CallFuncOnAllEnabledButtonModuleFrames(func)
		for moduleName, moduleFrame in pairs(WarLegendPvP.ButtonModules) do
			local moduleFrameOnButton = self[moduleName]
			if moduleFrameOnButton then
				if moduleFrameOnButton.Enabled then
					func(self, moduleFrameOnButton)
				end
 			end
		end
	end

	function playerButton:DeleteActiveUnitID() --Delete from OnUpdate
		if not self.PlayerIsEnemy then return end
		self:Debug("DeleteActiveUnitID")
		self.unitID = nil
		self.TargetUnitID = nil
		self:UpdateRange(false)

		if self.Target then
			self:IsNoLongerTarging(self.Target)
		end

		self.UnitIDs.HasAllyUnitID = false
		self:DispatchEvent("UnitIdUpdate")
	end

	function playerButton:UpdateEnemyUnitID(key, value)
		if not self.PlayerIsEnemy then return end
		if self.PlayerDetails.isFakePlayer then return end
		local unitIDs = self.UnitIDs
		if key then
			unitIDs[key] = value
		end

		local unitID = unitIDs.Nameplate or unitIDs.Target or unitIDs.Focus
		if unitID then
			unitIDs.HasAllyUnitID = false
			self:UpdateUnitID(unitID, unitID .. "target")
		elseif unitIDs.Ally then
			unitIDs.HasAllyUnitID = true
			local playerButton = WarLegendPvP:GetPlayerbuttonByUnitID(unitIDs.Ally)
			if playerButton and playerButton == self then
				self:UpdateUnitID(unitIDs.Ally, unitIDs.Ally .. "target")
				unitIDs.HasAllyUnitID = true
			end
		else
			self:DeleteActiveUnitID()
		end
	end

	function playerButton:SetModulePositions()
		if not self:GetRect() then return end --the position of the button is not set yet
		local i = 1
		repeat                          -- we basically run this roop to get out of the anchring hell (making sure all the frames that a module is depending on is set)
			local allModulesSet = true
			for moduleName, moduleFrame in pairs(WarLegendPvP.ButtonModules) do
				local moduleFrameOnButton = self[moduleName]

				local config = moduleFrameOnButton.config
				if not config then return end


				if config.Points then
					if i == 1 then moduleFrameOnButton:ClearAllPoints() end

					for j = 1, config.ActivePoints do
						local pointConfig = config.Points[j]
						if pointConfig then
							if pointConfig.RelativeFrame then
								local relativeFrame = self:GetAnchor(pointConfig.RelativeFrame)


								if relativeFrame then
									local scale = WarLegendPvP.SafeScale(moduleFrameOnButton.config.Scale)
									moduleFrameOnButton:SetScale(scale)
									if relativeFrame:GetNumPoints() > 0 then
										local effectiveScale = moduleFrameOnButton:GetEffectiveScale()
										moduleFrameOnButton:SetPoint(pointConfig.Point, relativeFrame,
											pointConfig.RelativePoint, (pointConfig.OffsetX or 0) / effectiveScale, (pointConfig.OffsetY or 0) / effectiveScale)
									else
										-- the module we are depending on hasn't been set yet
										allModulesSet = false
										--WarLegendPvP:Debug("moduleName", moduleName, "isnt set yet")
									end
								else
									return print("error", relativeFrame, "for module", moduleName, "doesnt exist")
								end
							else
								--do nothing, the point was probably deleted
							end
						end
					end
				end
				if config.Parent then
					moduleFrameOnButton:SetParent(self:GetAnchor(config.Parent))
				end

				if not moduleFrameOnButton.Enabled and moduleFrame.flags.SetZeroWidthWhenDisabled then
					moduleFrameOnButton:SetWidth(0.01)
				else
					if config.UseButtonHeightAsWidth then
						moduleFrameOnButton:SetWidth(self:GetHeight())
					else
						if config.Width and WarLegendPvP:ModuleFrameNeedsWidth(moduleFrame, config) then
							moduleFrameOnButton:SetWidth(config.Width)
						end
					end
				end


				if not moduleFrameOnButton.Enabled and moduleFrame.flags.SetZeroHeightWhenDisabled then
					moduleFrameOnButton:SetHeight(0.001)
				else
					if config.UseButtonHeightAsHeight then
						moduleFrameOnButton:SetHeight(self:GetHeight())
					else
						if config.Height and WarLegendPvP:ModuleFrameNeedsHeight(moduleFrame, config) then
							moduleFrameOnButton:SetHeight(config.Height)
						end
					end
				end
			end
			i = i + 1

			if i > 10 then
				self:Debug("something went wrong in ApplyModuleSettings")
			end
		until allModulesSet or i > 10 --maxium of 10 tries
		self.MyTarget:SetParent(self.healthBar)
		self.MyTarget:SetPoint("TOPLEFT", self.healthBar, "TOPLEFT")
		self.MyTarget:SetPoint("BOTTOMRIGHT", self.Power, "BOTTOMRIGHT")
		self.MyFocus:SetParent(self.healthBar)
		self.MyFocus:SetPoint("TOPLEFT", self.healthBar, "TOPLEFT")
		self.MyFocus:SetPoint("BOTTOMRIGHT", self.Power, "BOTTOMRIGHT")
	end

	function playerButton:ApplyModuleSettings()
		wipe(self.ButtonEvents)
		for moduleName, moduleFrame in pairs(WarLegendPvP.ButtonModules) do
			local moduleFrameOnButton = self[moduleName]

			if moduleFrameOnButton.Enabled then
				if moduleFrame.events then
					for i = 1, #moduleFrame.events do
						local event = moduleFrame.events[i]
						self.ButtonEvents[event] = self.ButtonEvents[event] or {}

						table_insert(self.ButtonEvents[event], moduleFrameOnButton)
					end
				end
				moduleFrameOnButton.Enabled = true
				moduleFrameOnButton:Show()
				if moduleFrameOnButton.Enable then moduleFrameOnButton:Enable() end
				if moduleFrameOnButton.ApplyAllSettings then moduleFrameOnButton:ApplyAllSettings() end
			else
				moduleFrameOnButton.Enabled = false
				moduleFrameOnButton:Hide()
				if moduleFrameOnButton.Disable then moduleFrameOnButton:Disable() end
				if moduleFrameOnButton.Reset then moduleFrameOnButton:Reset() end
			end
		end
	end

	function playerButton:SetConfigShortCuts()
		self.config = WarLegendPvP.db.profile[self.PlayerType]
		self.playerCountConfig = WarLegendPvP[self.PlayerType].playerCountConfig
		self:SetAllModuleConfigs()
	end



	function playerButton:ApplyButtonSettings()
		self:SetConfigShortCuts()
		local conf = self.playerCountConfig
		if not conf then return end

		self:SetWidth(conf.BarWidth)
		self:SetHeight(conf.BarHeight)

		self:ApplyRangeIndicatorSettings()

		-- style (per side): 1px black frame for the styles that have one, EllesmereUI's accent color for the target border
		local isEUI = WarLegendPvP:GetStyle(self.PlayerType) == "eui"
		self.StyleBorder:SetShown(WarLegendPvP:StyleHasBorder(self.PlayerType))
		local tr, tg, tb, ta = unpack(WarLegendPvP.db.profile.MyTarget_Color)
		if isEUI then
			tr, tg, tb = WarLegendPvP:GetAccentColor()
		end

		--MyTarget, indicating the current target of the player
		self.MyTarget:SetBackdrop({
			bgFile = "Interface/Buttons/WHITE8X8", --drawlayer "BACKGROUND"
			edgeFile = 'Interface/Buttons/WHITE8X8', --drawlayer "BORDER"
			edgeSize = WarLegendPvP.db.profile.MyTarget_BorderSize
		})
		self.MyTarget:SetBackdropColor(0, 0, 0, 0)
		self.MyTarget:SetBackdropBorderColor(tr, tg, tb, ta)

		--MyFocus, indicating the current focus of the player
		self.MyFocus:SetBackdrop({
			bgFile = "Interface/Buttons/WHITE8X8", --drawlayer "BACKGROUND"
			edgeFile = 'Interface/Buttons/WHITE8X8', --drawlayer "BORDER"
			edgeSize = WarLegendPvP.db.profile.MyFocus_BorderSize
		})
		self.MyFocus:SetBackdropColor(0, 0, 0, 0)
		self.MyFocus:SetBackdropBorderColor(unpack(WarLegendPvP.db.profile.MyFocus_Color))

		self:SetModulePositions()
		self:ApplyModuleSettings()
		self:SetBindings()
		self:RefreshAfterSettings()
	end

	do
		local mouseButtons = {
			[1] = "LeftButton",
			[2] = "RightButton",
			[3] = "MiddleButton"
		}

		function playerButton:SetBindings()
			self:Debug("SetBindings")
			if not self.config then return end
			local setupUsualAttributes = true
			--use a table to track changes and compare them to GetAttribute
			--set baseline



			local newAttributes = {
				-- WarLegend: the ally's unit (self.unitID): the frame then is a unit frame for the game, [@mouseover]
				-- macros and the click spells (dispel) work on it. Was self.unit, a field nothing set.
				unit = not self.PlayerIsEnemy and self.unitID or false,
				type1 = false,
				type2 = false,
				type3 = false,
				macrotext1 = false,
				macrotext2 = false,
				macrotext3 = false,
				spell1 = false,
				spell2 = false,
				spell3 = false
			}

			if ClickCastFrames[self] then
				ClickCastFrames[self] = nil
			end

			if not self.PlayerIsEnemy then
				if WarLegendPvP.db.profile[self.PlayerType].UseClique then
					WarLegendPvP:Debug("Clique used")
					ClickCastFrames[self] = true
					setupUsualAttributes = false
				end
			end





			if setupUsualAttributes then
				newAttributes.type1 = "macro" -- type1 = LEFT-Click
				newAttributes.type2 = "macro" -- type2 = Right-Click
				newAttributes.type3 = "macro" -- type3 = Middle-Click

				for i = 1, 3 do
					local bindingType = self.config[mouseButtons[i] .. "Type"]
					-- WoW Forever: "/targetexact First-Surname" finds nobody, use the name forms the client accepts
					local playerName = self.PlayerDetails.PlayerName

					-- WarLegend: "Dispel" casts a dispel spell of my class on this ally (Modules/Dispel.lua),
					-- a plain secure spell attribute on the button's unit, like Decursive's clicks
					local dispelSpell = bindingType == "Dispel" and not self.PlayerIsEnemy
						and WarLegendPvP.GetDispelSpell and WarLegendPvP.GetDispelSpell(i)
					if dispelSpell then
						newAttributes['type' .. i] = "spell"
						newAttributes['spell' .. i] = dispelSpell
					elseif bindingType == "Dispel" then
						newAttributes['macrotext' .. i] = ""
					elseif bindingType == "Target" then
						newAttributes['macrotext' .. i] = WarLegendPvP.GetTargetMacro(playerName)
					elseif bindingType == "Focus" then
						newAttributes['macrotext' .. i] = '/targetexact ' .. WarLegendPvP.GetTargetableName(playerName) .. '\n' ..
							'/focus\n' ..
							'/targetlasttarget'
					else -- Custom
						local macrotext = (WarLegendPvP.db.profile[self.PlayerType][mouseButtons[i] .. "Value"])
							:gsub("%%n", WarLegendPvP.GetTargetableName(playerName))
						newAttributes['macrotext' .. i] = macrotext
					end
				end
			end

			--check what have actually changed
			local updateNeeded = false
			for attribute, value in pairs(newAttributes) do
				local currentValue = self:GetAttribute(attribute)
				if currentValue ~= value then
					updateNeeded = true
					break
				end
			end
			local newRegisterForClicksValue = WarLegendPvP.db.profile[self.PlayerType].ActionButtonUseKeyDown and "AnyDown" or "AnyUp"
			if self.registerForClicksValue == nil or self.registerForClicksValue ~= newRegisterForClicksValue then
				updateNeeded = true
			end
			if updateNeeded then
				if InCombatLockdown() then
					return WarLegendPvP:QueueForUpdateAfterCombat(self, "SetBindings")
				end
				self:RegisterForClicks(newRegisterForClicksValue)
				self.registerForClicksValue = newRegisterForClicksValue
				for attribute, value in pairs(newAttributes) do
					self:SetAttribute(attribute, value)
				end
			end
		end
	end

	function playerButton:PlayerIsDead()
		if not self.isDead then
			self:DispatchEvent("UnitDied")
			self.isDead = true
		end
	end

	function playerButton:PlayerIsAlive()
		if self.isDead then
			self:DispatchEvent("UnitRevived")
			self.isDead = false
		end
	end

	local maxHealths = {} --key = playerbutton, value = {}
	local deadPlayers = {}

	function playerButton:FakeUnitHealth()
		local now = GetTime()
		if deadPlayers[self] then
			--this player is dead, check if we can revive him
			if deadPlayers[self] + 26 < now then -- he died more than 26 seconds ago
				deadPlayers[self] = nil
			else
				return 0 -- let the player be dead
			end
		end
		local maxHealth = self:FakeUnitHealthMax()

		local health = math_random(0, 100)
		if health == 0 then
			deadPlayers[self] = now
			return 0
		else
			return math_floor((health / 100) * maxHealth)
		end
	end

	function playerButton:FakeUnitHealthMax()
		if not maxHealths[self] then
			local myMaxHealth = UnitHealthMax("player")
			local playerMaxHealthDifference = math_random(-15, 15) -- the player has the same health as me +/- 15%
			local playerMaxHealth = math.ceil(myMaxHealth * (1 + (playerMaxHealthDifference / 100)))
			maxHealths[self] = playerMaxHealth
		end
		return maxHealths[self]
	end

	function playerButton:UpdateHealth(unitID, health, maxHealth)
		self:DispatchEvent("UpdateHealth", unitID, health, maxHealth)
		if unitID and UnitIsDeadOrGhost(unitID) or (not issecret(health) and health == 0) then
			self:PlayerIsDead()
		else
			self:PlayerIsAlive()
		end
	end

	function playerButton:UNIT_HEALTH(unitID) --gets health of nameplates, player, target, focus, raid1 to raid40, partymember
		if not self.isShown then return end
		local health
		local maxHealth
		if self.PlayerDetails.isFakePlayer then
			health = self:FakeUnitHealth()
			maxHealth = self:FakeUnitHealthMax()
		else
			health = UnitHealth(unitID)
			maxHealth = UnitHealthMax(unitID)
		end

		self:UpdateHealth(unitID, health, maxHealth)
	end

	function playerButton:ApplyRangeIndicatorSettings()
		--set everything to default
		for frameName, enableRange in pairs(self.config.RangeIndicator_Frames) do
			if self[frameName] then
				self[frameName]:SetAlpha(1)
			else
				--probably old saved variables version
				self.config.RangeIndicator_Frames[frameName] = nil
			end
		end
		self:SetAlpha(1)
		self:UpdateRange(self.wasInRange, true)
	end

	-- WoW Forever: the flag carriers come from the battleground messages (FlagCarrier.lua)
	function playerButton:SetFlagCarrier(hasFlag)
		hasFlag = hasFlag and true or false
		if self.hasFlag == hasFlag then return end
		self.hasFlag = hasFlag
		self:DispatchEvent(hasFlag and "FlagPickedUp" or "FlagDropped")
		-- WarLegend: the flag also on the carrier's raid frame (FlagCarrier.lua)
		if not self.PlayerIsEnemy and WarLegendPvP.MarkRaidFrameFlag then
			WarLegendPvP:MarkRaidFrameFlag(self.PlayerDetails and self.PlayerDetails.PlayerName, hasFlag)
		end
	end

	-- Shows/Hides targeting indicators for a button (the rated battleground sound alerts are gone: no rated BG on Forever)
	function playerButton:UpdateTargetIndicators()
		self:DispatchEvent("UpdateTargetIndicators")
	end

	function playerButton:UpdateRange(inRange, forceUpdate)
		if not self.config then return end
		--WarLegendPvP:Information("UpdateRange", inRange, self.PlayerName, self.config.RangeIndicator_Enabled, self.config.RangeIndicator_Alpha)

		if not self.config.RangeIndicator_Enabled then return end

		if forceUpdate or inRange ~= self.wasInRange then
			local alpha = inRange and 1 or self.config.RangeIndicator_Alpha
			if self.config.RangeIndicator_Everything then
				self:SetAlpha(alpha)
			else
				for frameName, enableRange in pairs(self.config.RangeIndicator_Frames) do
					if enableRange then
						self[frameName]:SetAlpha(alpha)
					end
				end
			end
			self.wasInRange = inRange
			self:ApplyRangeDesaturation()
		end
	end

	-- WarLegend: out of range = grey health bar and class icon (option per side, RangeIndicator_Desaturate)
	function playerButton:ApplyRangeDesaturation()
		local grey = self.config and self.config.RangeIndicator_Enabled and self.config.RangeIndicator_Desaturate
			and self.wasInRange == false
		local bar = self.healthBar
		if bar and self.PlayerDetails then
			local r, g, b = WarLegendPvP:GetBarColor(self) -- class color or the side's single color
			if grey then
				local l = (0.3 * r + 0.59 * g + 0.11 * b) * 0.6
				bar:SetStatusBarColor(l, l, l)
			else
				bar:SetStatusBarColor(r, g, b)
			end
		end
		local spec = self.SpecClassPriorityOne
		if spec and spec.SpecClassIcon and spec.SpecClassIcon.SetDesaturated then
			spec.SpecClassIcon:SetDesaturated(grey and true or false)
		end
	end

	function playerButton:UpdateRangeViaItem(unitID)
		--WarLegendPvP:Information("UpdateRange", inRange, self.PlayerName, self.config.RangeIndicator_Enabled, self.config.RangeIndicator_Alpha)

		if not self.config.RangeIndicator_Enabled then return end
		self:UpdateRange(IsItemInRange(self.config.RangeIndicator_Range, unitID))
	end

	function playerButton:UpdateRangeViaLibRangeCheck(unitID)
		if not unitID then return end
		if not self.config then return end
		if not self.config.RangeIndicator_Enabled then return end
		-- WarLegend: the game's own range checks when chosen ("spell": the range of my main spell, as the action
		-- buttons; "blizzard": UnitInRange, as Blizzard's raid frames); LibRangeCheck when they give no answer
		local mode = self.config.RangeIndicator_Mode
		if mode and WarLegendPvP.GameRangeCheck then
			local inRange = WarLegendPvP.GameRangeCheck(mode, unitID, self.PlayerIsEnemy)
			if inRange ~= nil then return self:UpdateRange(inRange) end
		end
		local inCombatLockdown = InCombatLockdown()
		local checker, range = LRC[self.PlayerIsEnemy and "GetHarmMaxChecker"  or "GetFriendMaxChecker"](LRC, inCombatLockdown and self.config.RangeIndicator_Range_InCombat or self.config.RangeIndicator_Range_OutOfCombat, inCombatLockdown)
		if not checker then return self:UpdateRange(true) end
		self:UpdateRange(checker(unitID))
	end



	function playerButton:GetUnitID()
		return self.unitID
	end

	playerButton.UNIT_HEALTH_FREQUENT = playerButton.UNIT_HEALTH --TBC compability, IsTBCC
	playerButton.UNIT_MAXHEALTH = playerButton.UNIT_HEALTH


	function playerButton:UNIT_POWER_FREQUENT(unitID, powerToken) --gets power of nameplates, player, target, focus, raid1 to raid40, partymember
		if not self.isShown then return end
		self:DispatchEvent("UpdatePower", unitID, powerToken)
	end

	-- returns true if the other button is a enemy from the point of view of the button. True if button is ally and other button is enemy, and vice versa
	function playerButton:IsEnemyToMe(playerButton)
		return self.PlayerIsEnemy ~= playerButton.PlayerIsEnemy
	end

	function playerButton:UpdateTargetedByEnemy(playerButton, targeted)
		local unitIDs = self.UnitIDs
		unitIDs.TargetedByEnemy[playerButton] = targeted
		self:UpdateTargetIndicators()

		if self.PlayerIsEnemy then
			local allyUnitID

			for allyBtn in pairs(unitIDs.TargetedByEnemy) do
				if allyBtn ~= WarLegendPvP.UserButton then
					allyUnitID = allyBtn.TargetUnitID
					break
				end
			end
			self:UpdateEnemyUnitID("Ally", allyUnitID)
		end
	end

	function playerButton:IsNowTargeting(playerButton)
		--WarLegendPvP:Debug("IsNowTargeting", self.PlayerName, self.unitID, playerButton.PlayerName)
		self.Target = playerButton

		if not self:IsEnemyToMe(playerButton) then return end --we only care of the other player is of opposite faction

		playerButton:UpdateTargetedByEnemy(self, true)
	end

	function playerButton:IsNoLongerTarging(playerButton)
		--WarLegendPvP:Debug("IsNoLongerTarging", self.PlayerName, self.unitID, playerButton.PlayerName)
		self.Target = nil

		if not self:IsEnemyToMe(playerButton) then return end --we only care of the other player is of opposite faction

		playerButton:UpdateTargetedByEnemy(self, nil)
	end

	function playerButton:UpdateTarget()
		--WarLegendPvP:Debug("UpdateTarget", self.PlayerName, self.unitID)

		local oldTargetPlayerButton = self.Target
		local newTargetPlayerButton

		if self.TargetUnitID then
			newTargetPlayerButton = WarLegendPvP:GetPlayerbuttonByUnitID(self.TargetUnitID)
		end


		if oldTargetPlayerButton then
			--WarLegendPvP:Debug("UpdateTarget", "oldTargetPlayerButton", self.PlayerName, self.unitID, oldTargetPlayerButton.PlayerName, oldTargetPlayerButton.unitID)

			if newTargetPlayerButton and oldTargetPlayerButton == newTargetPlayerButton then return end
			self:IsNoLongerTarging(oldTargetPlayerButton)
		end

		--player didnt have a target before or the player targets a new player

		if newTargetPlayerButton then --player targets an existing player and not for example a pet or a NPC
			--WarLegendPvP:Debug("UpdateTarget", "newTargetPlayerButton", self.PlayerName, self.unitID, newTargetPlayerButton.PlayerName, newTargetPlayerButton.unitID)
			self:IsNowTargeting(newTargetPlayerButton)
		end
	end

	function playerButton:DispatchEvent(event, ...)
		if not self.ButtonEvents then return end

		local moduleFrames = self.ButtonEvents[event]

		if not moduleFrames then return end
		for i = 1, #moduleFrames do
			local moduleFrameOnButton = moduleFrames[i]
			if moduleFrameOnButton[event] then
				Data.SafeCall(moduleFrameOnButton[event], moduleFrameOnButton, ...)
			else
				WarLegendPvP:OnetimeInformation("Event:", event,
					"There is no key with the event name for this module", moduleFrameOnButton.moduleName)
			end
		end
	end

	-- WoW Forever: modules removed from this version, saved profiles may still anchor to them
	local removedModuleAnchors = {
		Covenant = "Role", Cooldowns = "Button", Trinket = "Button", Racial = "Button", DRTracking = "Button",
		PriorityBuffs = "Button", PriorityDebuffs = "Button", NonPriorityBuffs = "Button", NonPriorityDebuffs = "Button"
	}

	function playerButton:GetAnchor(relativeFrame)
		relativeFrame = removedModuleAnchors[relativeFrame] or relativeFrame
		return relativeFrame == "Button" and self or self[relativeFrame]
	end


	playerButton.Counter = {}
	playerButton:SetScript("OnEvent", function(self, event, ...)
		--self.Counter[event] = (self.Counter[event] or 0) + 1
		if self.db and self.db.profile and self.db.profile.DebugBlizzEvents then
			self:Debug("OnEvent", event, ...)
		end
		self[event](self, ...)
	end)
	playerButton:SetScript("OnShow", function()
		playerButton.isShown = true
	end)
	playerButton:SetScript("OnHide", function()
		playerButton.isShown = false
	end)

	-- events/scripts
	playerButton:RegisterForDrag('LeftButton')
	playerButton:SetClampedToScreen(true)

	playerButton:SetScript('OnDragStart', playerButton.OnDragStart)
	playerButton:SetScript('OnDragStop', playerButton.OnDragStop)


	--MyTarget, indicating the current target of the player
	playerButton.MyTarget = CreateFrame('Frame', nil, playerButton.healthBar,
		BackdropTemplateMixin and "BackdropTemplate")

	playerButton.MyTarget:Hide()

	-- 1px black frame of the EllesmereUI style (hidden in the Blizzard style)
	playerButton.StyleBorder = CreateFrame('Frame', nil, playerButton, BackdropTemplateMixin and "BackdropTemplate")
	playerButton.StyleBorder:SetPoint("TOPLEFT", -1, 1)
	playerButton.StyleBorder:SetPoint("BOTTOMRIGHT", 1, -1)
	playerButton.StyleBorder:SetFrameLevel(playerButton:GetFrameLevel() + 20)
	playerButton.StyleBorder:SetBackdrop({ edgeFile = "Interface/Buttons/WHITE8X8", edgeSize = 1 })
	playerButton.StyleBorder:SetBackdropBorderColor(0, 0, 0, 1)
	playerButton.StyleBorder:Hide()

	--MyFocus, indicating the current focus of the player
	playerButton.MyFocus = CreateFrame('Frame', nil, playerButton.healthBar,
		BackdropTemplateMixin and "BackdropTemplate")
	playerButton.MyFocus:SetBackdrop({
		bgFile = "Interface/Buttons/WHITE8X8", --drawlayer "BACKGROUND"
		edgeFile = 'Interface/Buttons/WHITE8X8', --drawlayer "BORDER"
		edgeSize = 1
	})
	playerButton.MyFocus:SetBackdropColor(0, 0, 0, 0)
	playerButton.MyFocus:Hide()

	playerButton.ButtonModules = {}
	for moduleName, moduleFrame in pairs(WarLegendPvP.ButtonModules) do
		if moduleFrame.AttachToPlayerButton then
			moduleFrame:AttachToPlayerButton(playerButton)

			if not playerButton[moduleName] then
				print("something went wrong here after AttachToPlayerButton",
					moduleName)
			end

			playerButton[moduleName].GetConfig = function(self)
				self.config = playerButton.playerCountConfig.ButtonModules[moduleName]
				return self.config
			end

			playerButton[moduleName].Debug = function(self, ...)
				WarLegendPvP:Debug(moduleName, playerButton.PlayerDetails and playerButton.PlayerDetails.PlayerName, ...)
			end

			playerButton[moduleName].moduleName = moduleName
		end
	end
	return playerButton
end