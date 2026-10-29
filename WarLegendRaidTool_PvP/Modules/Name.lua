
---@class WarLegendPvP
local WarLegendPvP = WarLegendPvP
---@type string
local AddonName = ...
---@class Data
local Data = select(2, ...)

local L = Data.L

local generalDefaults = {
	ShowRealmnames = true
}

local defaultSettings = {
	Enabled = true,
	Parent = "healthBar",
	ActivePoints = 2,
	Points = {
		{
			Point = "TOPLEFT",
			RelativeFrame = "Level",
			RelativePoint = "TOPRIGHT",
			OffsetX = 5,
			OffsetY = -2
		},
		-- WarLegend: ends before the flag icon (ObjectiveAndRespawn: as wide as the icon on the flag carrier, nearly
		-- no width otherwise; the target counter is right of it)
		{
			Point = "BOTTOMRIGHT",
			RelativeFrame = "ObjectiveAndRespawn",
			RelativePoint = "BOTTOMLEFT",
			OffsetX = -2,
		}
	},
	Text = {
		FontSize = 13,
		JustifyH = "LEFT",
		JustifyV = "MIDDLE",
		WordWrap = false
	},
}



local name = WarLegendPvP:NewButtonModule({
	moduleName = "Name",
	localizedModuleName = L.Name,
	generalDefaults = generalDefaults,
	defaultSettings = defaultSettings,
	enabledInThisExpansion = true,
	attachSettingsToButton = true
})


function name:AttachToPlayerButton(playerButton)
	playerButton.Name = WarLegendPvP.MyCreateFontString(playerButton)

	function playerButton.Name:SetName()
		if not playerButton.PlayerDetails then return end
		local playerName = playerButton.PlayerDetails.PlayerName
		if not playerName then return end

		local name, realm = strsplit( "-", playerName, 2)

		if WarLegendPvP.db.profile.ConvertCyrillic then
			playerName = ""
			for i = 1, name:utf8len() do
				local c = name:utf8sub(i,i)

				if Data.CyrillicToRomanian[c] then
					playerName = playerName..Data.CyrillicToRomanian[c]
					if i == 1 then
						playerName = playerName:gsub("^.",string.upper) --uppercase the first character
					end
				else
					playerName = playerName..c
				end
			end
			--self.DisplayedName = self.DisplayedName:gsub("-.",string.upper) --uppercase the realm name
			name = playerName
		end

		if realm and self.config.ShowRealmnames then
			name = name.."-"..realm
		end

		self:SetText(name)
		self.DisplayedName = name
	end

	function playerButton.Name:ApplyAllSettings()
		if not self.config then return end
		local config = self.config
		-- name
		self:ApplyFontStringSettings(config.Text)
		-- WarLegend: the name in the class color (option per side)
		local side = WarLegendPvP.db.profile[playerButton.PlayerType]
		local c = playerButton.PlayerDetails and playerButton.PlayerDetails.PlayerClassColor
		if side and side.NameClassColor and c then self:SetTextColor(c.r, c.g, c.b) end
		self:SetName()
	end
	return playerButton.Name
end