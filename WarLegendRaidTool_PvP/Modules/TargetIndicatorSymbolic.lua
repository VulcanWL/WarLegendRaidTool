---@type string
local AddonName = ...
---@class Data
local Data = select(2, ...)
---@class WarLegendPvP
local WarLegendPvP = WarLegendPvP
local L = Data.L

local CreateFrame = CreateFrame

local defaultSettings = {
	Enabled = true,
	Parent = "healthBar",
	IconWidth = 8,
	IconHeight = 10,
	IconSpacing = 10,
	ActivePoints = 2,
	Points = {
		{
			Point = "TOPLEFT",
			RelativeFrame = "healthBar",
			RelativePoint = "TOPLEFT",
			OffsetX = 0
		},
		{
			Point = "BOTTOMRIGHT",
			RelativeFrame = "healthBar",
			RelativePoint = "BOTTOMRIGHT",
			OffsetX = 0
		}
	},

}

local symbolicTargetIndicator = WarLegendPvP:NewButtonModule({
	moduleName = "TargetIndicatorSymbolic",
	localizedModuleName = L.TargetIndicatorSymbolic,
	defaultSettings = defaultSettings,
	events = {"UpdateTargetIndicators"},
	enabledInThisExpansion = true,
	attachSettingsToButton = true
})

function symbolicTargetIndicator:AttachToPlayerButton(playerButton)
	playerButton.TargetIndicatorSymbolic = CreateFrame("frame", nil, playerButton)
	playerButton.TargetIndicatorSymbolic.Symbols = {}


	playerButton.TargetIndicatorSymbolic.SetSizeAndPosition = function(self, index)
		local config = self.config
		local symbol = self.Symbols[index]
		if not symbol then return end
		if not (config.IconWidth and config.IconHeight) then return end
		symbol:SetSize(config.IconWidth, config.IconHeight)
		symbol:SetPoint("TOP",floor(index/2)*(index%2==0 and -config.IconSpacing or config.IconSpacing), 0) --1: 0, 0 2: -10, 0 3: 10, 0 4: -20, 0 > i = even > left, uneven > right
	end

	function playerButton.TargetIndicatorSymbolic:UpdateTargetIndicators()
		local i = 1
		for enemyButton in pairs(playerButton.UnitIDs.TargetedByEnemy) do
			local indicator = self.Symbols[i]
			if not indicator then
				indicator = CreateFrame("frame", nil, playerButton.TargetIndicatorSymbolic, BackdropTemplateMixin and "BackdropTemplate")
				indicator:SetBackdrop({
					bgFile = "Interface/Buttons/WHITE8X8", --drawlayer "BACKGROUND"
					edgeFile = 'Interface/Buttons/WHITE8X8', --drawlayer "BORDER"
					edgeSize = 1
				})
				indicator:SetBackdropBorderColor(0,0,0,1)
				self.Symbols[i] = indicator

				self:SetSizeAndPosition(i)
			end
			local classColor = enemyButton.PlayerDetails and enemyButton.PlayerDetails.PlayerClassColor
			if classColor then
				indicator:SetBackdropColor(classColor.r,classColor.g,classColor.b)
			else
				indicator:SetBackdropColor(0.5, 0.5, 0.5) -- unknown class token: grey, no error
			end
			indicator:Show()

			i = i + 1
		end

		while self.Symbols[i] do --hide no longer used ones
			self.Symbols[i]:Hide()
			i = i + 1
		end
	end



	playerButton.TargetIndicatorSymbolic.ApplyAllSettings = function(self)
		if not self.config then return end
		for i = 1, #self.Symbols do
			self:SetSizeAndPosition(i)
		end
	end
	return playerButton.TargetIndicatorSymbolic
end