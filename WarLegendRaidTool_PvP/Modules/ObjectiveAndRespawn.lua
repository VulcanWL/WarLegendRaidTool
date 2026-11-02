---@class WarLegendPvP
local WarLegendPvP = WarLegendPvP

---@type string
local AddonName = ...
---@class Data
local Data = select(2, ...)
local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture or GetSpellTexture

local L = Data.L

-- WoW Forever: flag icon on the flag carrier (carriers from the battleground messages, FlagCarrier.lua).
-- Removed: the objective debuff stacks (enemy auras are secret in battlegrounds, and vanilla has no
-- Focused / Brutal Assault) and the respawn timer (rated battlegrounds only, Forever has none).
-- The module name stays "ObjectiveAndRespawn" for the saved profiles.

local defaultSettings = {
	Enabled = true,
	Parent = "Button",
	Width = 36,
	ActivePoints = 2,
	Points = {
		{
			Point = "TOPRIGHT",
			RelativeFrame = "TargetIndicatorNumeric",
			RelativePoint = "TOPLEFT",
			OffsetX = -2
		},
		{
			Point = "BOTTOMRIGHT",
			RelativeFrame = "TargetIndicatorNumeric",
			RelativePoint = "BOTTOMLEFT",
			OffsetX = -2
		}
	}
}

local objectiveAndRespawn = WarLegendPvP:NewButtonModule({
	moduleName = "ObjectiveAndRespawn",
	localizedModuleName = L.ObjectiveAndRespawnTimer,
	defaultSettings = defaultSettings,
	events = {"FlagPickedUp", "FlagDropped"},
	enabledInThisExpansion = true,
	attachSettingsToButton = true
})

function objectiveAndRespawn:AttachToPlayerButton(playerButton)
	local frame = CreateFrame("frame", nil, playerButton)
	frame:SetFrameLevel(playerButton:GetFrameLevel() + 5)

	frame.Icon = frame:CreateTexture(nil, "BORDER")
	frame.Icon:SetAllPoints()

	frame:SetScript("OnSizeChanged", function(self, width, height)
		WarLegendPvP.CropImage(self.Icon, width, height)
	end)
	frame:Hide()

	-- WarLegend: the name ends at this frame's left (Name.lua): nearly no width while there is no flag
	function frame:Reset()
		self:Hide()
		self.Icon:SetTexture()
		self:SetWidth(0.01)
	end

	function frame:ApplyAllSettings()
		if not self.config then return end
		if playerButton.hasFlag then
			self:FlagPickedUp()
		else
			self:Reset()
		end
	end

	function frame:FlagPickedUp()
		local carrierFaction = playerButton.PlayerIsEnemy and WarLegendPvP.EnemyFaction or WarLegendPvP.AllyFaction
		local texture
		-- the map's flag auras, or the Classic Warsong Gulch ones (Data.BattlegroundspezificBuffs[1460],
		-- from BattleGroundEnemies) when the Forever map ID is not in that table
		local battlegroundBuffs = WarLegendPvP:GetBattlegroundAuras() or Data.BattlegroundspezificBuffs[1460]
		local spellId = battlegroundBuffs and battlegroundBuffs[carrierFaction]
		if spellId then
			texture = GetSpellTexture(spellId)
		end
		if not texture then return end
		self:SetWidth(self.config and self.config.Width or 36)
		self.Icon:SetTexture(texture)
		self:Show()
	end

	function frame:FlagDropped()
		self:Reset()
	end

	playerButton.ObjectiveAndRespawn = frame
	return playerButton.ObjectiveAndRespawn
end
