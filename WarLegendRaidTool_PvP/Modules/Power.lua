---@type string
local AddonName = ...
---@class Data
local Data = select(2, ...)
local issecret = issecretvalue or function() return false end -- WoW Forever secret values
---@class WarLegendPvP
local WarLegendPvP = WarLegendPvP
local L = Data.L

local PowerBarColor = PowerBarColor --table
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerType = UnitPowerType
local math_random = math.random

local generalDefaults = {
	Background = {0, 0, 0, 0.66},
	OnlyShowForHealers = false
}

local defaultSettings = {
	Enabled = true,
	Parent = "Button",
	Height = 5,
	ActivePoints = 2,
	Points = {
		{
			Point = "BOTTOMLEFT",
			RelativeFrame = "Button",
			RelativePoint = "BOTTOMLEFT",
		},
		{
			Point = "BOTTOMRIGHT",
			RelativeFrame = "Button",
			RelativePoint = "BOTTOMRIGHT",
		}
	}
}



local flags = {
	SetZeroHeightWhenDisabled = true,
	FixedPosition = true
}

-- WarLegend: the ally bars that read their unit 4 times a second (AttachToPlayerButton), one OnUpdate for all of them
local allyBars, allyBarsDriver = {}, nil
local function ReadBar(bar) bar:ReadOwnUnit() end

local power = WarLegendPvP:NewButtonModule({
	moduleName = "Power",
	localizedModuleName = L.PowerBar,
	flags = flags,
	defaultSettings = defaultSettings,
	generalDefaults = generalDefaults,
	events = {"UnitIdUpdate", "UpdatePower"},
	enabledInThisExpansion = true,
	attachSettingsToButton = true
})

function power:AttachToPlayerButton(playerButton)
	playerButton.Power = CreateFrame('StatusBar', nil, playerButton)
	playerButton.Power:SetMinMaxValues(0, 1)
	playerButton.Power.maxValue = 1


	--playerButton.Power.Background = playerButton.Power:CreateTexture(nil, 'BACKGROUND', nil, 2)
	playerButton.Power.Background = playerButton.Power:CreateTexture(nil, 'BACKGROUND', nil, 2)
	playerButton.Power.Background:SetAllPoints()
	playerButton.Power.Background:SetTexture("Interface/Buttons/WHITE8X8")


	function playerButton.Power:UpdateMinMaxValues(max)
		-- a secret value cannot even be tested (if max then ...): ask issecret first
		if issecret(max) then
			self:SetMinMaxValues(0, max)
			self.maxValue = nil
			return
		end
		if max and max ~= self.maxValue then
			self:SetMinMaxValues(0, max)
			self.maxValue = max
		end
	end

	function playerButton.Power:CheckForNewPowerColor(powerToken)
		--self:Debug("CheckForNewPowerColor", powerToken)
		if issecret(powerToken) then return end -- no compare, no table index with a secret

		if self.powerToken ~= powerToken then
			local color = PowerBarColor[powerToken]
			if color then
				self:SetStatusBarColor(color.r, color.g, color.b)
				self.powerToken = powerToken
			end
		end
	end

	function playerButton.Power:UnitIdUpdate(unitID)
		if unitID then
			local powerType, powerToken, altR, altG, altB = UnitPowerType(unitID)

			self:CheckForNewPowerColor(powerToken)
			self:UpdatePower(unitID)
		end
	end


	function playerButton.Power:UpdatePower(unitID)
		--self:Debug("UpdatePower", unitID, powerToken)
		-- the test mode asks every button for a random value (no unit): my own is real, it reads "player"
		if not unitID and WarLegendPvP.UserButton == playerButton
			and not (playerButton.PlayerDetails and playerButton.PlayerDetails.isFakePlayer) then
			unitID = "player"
		end
		-- an ally reads ITS OWN unit, whatever the event says: the event is matched to a button by the player's
		-- name, and several players can share a first name (WoW: Forever), so the unit it names may be another one
		if unitID and not playerButton.PlayerIsEnemy
			and not (playerButton.PlayerDetails and playerButton.PlayerDetails.isFakePlayer) then
			local own = (WarLegendPvP.UserButton == playerButton) and "player" or playerButton.unitID
			if own then unitID = own end
		end
		if unitID then
			-- the maximum can fail (secret value): protected, the bar still gets its value
			pcall(self.UpdateMinMaxValues, self, UnitPowerMax(unitID))
			local value = UnitPower(unitID)
			if issecret(value) or value ~= nil then self:SetValue(value) end
		else
			--for testmode
			self:UpdateMinMaxValues(1)
			self:SetValue(math_random(0, 100)/100)
		end
	end


	-- Allies: the bar also reads its unit 4 times a second, whatever the events do (a hidden bar runs nothing).
	-- My own button reads "player" itself. Fake players (test mode) and enemies keep to the events.
	-- WarLegend: one OnUpdate for all the ally bars, spread over the frames (WarLegendPvP.Spread), not one per bar
	function playerButton.Power:ReadOwnUnit()
		if playerButton.PlayerIsEnemy or not playerButton.isShown or not self:IsVisible() then return end
		local unit = playerButton.unitID
		if WarLegendPvP.UserButton == playerButton then unit = "player" end
		if not unit then return end
		local details = playerButton.PlayerDetails
		if details and details.isFakePlayer then return end
		self:UpdatePower(unit)
	end
	if not playerButton.PlayerIsEnemy then
		allyBars[#allyBars + 1] = playerButton.Power
		if not allyBarsDriver then
			allyBarsDriver = WarLegendPvP.Spread(playerButton:GetParent(), 0.25, function() return allyBars end, ReadBar)
		end
	end

	function playerButton.Power:ApplyAllSettings()
		if not self.config then return end
		-- power
		self:SetHeight(self.config.Height or 0.01)

		self:SetStatusBarTexture(WarLegendPvP:GetBarTexture("power", playerButton.PlayerType))
		self.Background:SetVertexColor(unpack(self.config.Background))
		local playerDetails = playerButton.PlayerDetails
		if not playerDetails then return end
		if not playerDetails.PlayerClass then return end
		if not playerDetails.PlayerRole then return end

		if playerDetails.PlayerRole == "HEALER" or not self.config.OnlyShowForHealers then
			self:SetHeight(self.config.Height or 0.01)
		else
			self:SetHeight(0.01)
		end

		local powerToken

		local t = Data.Classes[playerDetails.PlayerClass]
		if t then
			if playerDetails.PlayerSpecName then
				t = t[playerDetails.PlayerSpecName]
			end
		end
		if t then powerToken = t.Ressource end


		self:CheckForNewPowerColor(powerToken)
	end
	return playerButton.Power
end