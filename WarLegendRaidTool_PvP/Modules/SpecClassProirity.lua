---@type string
local AddonName = ...
---@class Data
local Data = select(2, ...)
---@class WarLegendPvP
local WarLegendPvP = WarLegendPvP
local L = Data.L
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local GetClassAtlas = GetClassAtlas

-- WoW Forever: spec / class icon only. The highest priority aura and the interrupt shown over it
-- are gone: enemy auras are secret in battlegrounds and the combat log (interrupts) is closed.
-- The module names stay "SpecClassPriorityOne/Two": the saved profiles and other modules anchor to them.

local generalDefaults = {
	showSpecIfExists = true
}

local defaultSettings = {
	Enabled = true,
	Parent = "Button",
	Width = 36,
	ActivePoints = 1,
	Points = {
		{
			Point = "TOPRIGHT",
			RelativeFrame = "Button",
			RelativePoint = "TOPLEFT",
		}
	},
	UseButtonHeightAsHeight = true,
}

local SpecClassPriorityOne = WarLegendPvP:NewButtonModule({
	moduleName = "SpecClassPriorityOne",
	localizedModuleName = L.SpecClassPriorityOne,
	defaultSettings = defaultSettings,
	generalDefaults = generalDefaults,
	events = {},
	enabledInThisExpansion = true
})

local SpecClassPriorityTwo = WarLegendPvP:NewButtonModule({
	moduleName = "SpecClassPriorityTwo",
	localizedModuleName = L.SpecClassPriorityTwo,
	defaultSettings = Mixin(CopyTable(defaultSettings), {
		Enabled = false,
		Points = {
			{
				Point = "TOPRIGHT",
				RelativeFrame = "Button",
				RelativePoint = "BOTTOMLEFT",
			}
		}
	}),
	generalDefaults = generalDefaults,
	events = {},
	enabledInThisExpansion = true
})

local function getLocalizedClass(classToken)
	for i = 1, GetNumClasses() do
		local className, classFile = GetClassInfo(i)
		if classFile and classFile == classToken then
			return className
		end
	end
end

local function attachToPlayerButton(playerButton)
	local frame = CreateFrame("frame", nil, playerButton)
	frame.Background = frame:CreateTexture(nil, 'BACKGROUND')
	frame.Background:SetAllPoints()
	frame.Background:SetColorTexture(0, 0, 0, 0.8)
	frame.ShowsSpec = false
	frame.SpecClassIcon = frame:CreateTexture(nil, 'BORDER', nil, 2)
	frame.SpecClassIcon:SetAllPoints()

	-- WarLegend: the icon frame takes no mouse (the clicks must reach the secure button under it), so its OnEnter never
	-- ran and the "Tooltips" option did nothing: the hover is read on the button, the tooltip anchored at the icon
	playerButton:HookScript("OnLeave", function()
		if GameTooltip:IsOwned(frame) then
			GameTooltip:Hide()
		end
	end)

	playerButton:HookScript("OnEnter", function()
		if not frame:IsShown() then return end
		WarLegendPvP:ShowTooltip(frame, function()
			local playerDetails = playerButton.PlayerDetails
			if not playerDetails or not playerDetails.PlayerClass then return end
			local localizedClass = getLocalizedClass(playerDetails.PlayerClass)
			if not localizedClass then return end
			if playerDetails.PlayerSpecName then
				GameTooltip:SetText(localizedClass .. " " .. playerDetails.PlayerSpecName)
			else
				GameTooltip:SetText(localizedClass)
			end
		end)
	end)

	frame:SetScript("OnSizeChanged", function(self)
		self:CropImage()
	end)

	frame:Hide()

	function frame:CropImage()
		local width = self:GetWidth()
		local height = self:GetHeight()
		if self.ShowsSpec and width and height and width > 0 and height > 0 then
			WarLegendPvP.CropImage(self.SpecClassIcon, width, height)
		end
	end

	function frame:ApplyAllSettings()
		if not self.config then return end
		self:Show()
		local playerDetails = playerButton.PlayerDetails
		if not playerDetails then return end
		self.ShowsSpec = false

		local specData = playerButton:GetSpecData()
		if specData and self.config.showSpecIfExists then
			self.SpecClassIcon:SetTexture(specData.specIcon)
			self.SpecClassIcon:SetTexCoord(0, 1, 0, 1)
			self.ShowsSpec = true
		else
			local classIconAtlas = GetClassAtlas and GetClassAtlas(playerDetails.PlayerClass)
			if classIconAtlas then
				self.SpecClassIcon:SetAtlas(classIconAtlas)
			else
				local coords = CLASS_ICON_TCOORDS[playerDetails.PlayerClass]
				if playerDetails.PlayerClass and coords then
					self.SpecClassIcon:SetTexture([[Interface\TargetingFrame\UI-Classes-Circles]])
					self.SpecClassIcon:SetTexCoord(unpack(coords))
				else
					self.SpecClassIcon:SetTexture(nil)
				end
			end
		end
		self:CropImage()
	end
	return frame
end

function SpecClassPriorityOne:AttachToPlayerButton(playerButton)
	playerButton.SpecClassPriorityOne = attachToPlayerButton(playerButton)
	return playerButton.SpecClassPriorityOne
end

function SpecClassPriorityTwo:AttachToPlayerButton(playerButton)
	playerButton.SpecClassPriorityTwo = attachToPlayerButton(playerButton)
	return playerButton.SpecClassPriorityTwo
end
