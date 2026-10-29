---@type string
local AddonName = ...
---@class Data
local Data = select(2, ...)
---@class WarLegendPvP
local WarLegendPvP = WarLegendPvP
local L = Data.L
local issecret = issecretvalue or function() return false end

-- WoW Forever: our own cast bar instead of Blizzard's CastingBarFrameTemplate. The enemy cast info is
-- secret in a battleground and Blizzard's template errors on it when it runs from addon frames. Like
-- EllesmereUI's nameplates: the name / icon go straight to the widgets (they accept secrets), the bar
-- runs on the duration objects (UnitCastingDuration + StatusBar:SetTimerDuration), the
-- "not interruptible" overlay uses SetAlphaFromBoolean. Nothing secret is compared.

local styles = {
	Normal = L.NormalCastingBar,
	Small = L.SmallCastingBar
}

local styleSizes = {
	Normal = { width = 195, height = 13 },
	Small = { width = 150, height = 10 },
}

local defaultSettings = {
	Parent = "Button",
	ActivePoints = 1,
	Style = "Small",
	Scale = 1.5
}

local CreateFrame = CreateFrame
local UnitCastingInfo, UnitChannelInfo = UnitCastingInfo, UnitChannelInfo

local CAST_EVENTS = {
	"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
	"UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
	"UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}

local castBar = WarLegendPvP:NewButtonModule({
	moduleName = "CastBar",
	localizedModuleName = SHOW_ENEMY_CAST,
	defaultSettings = defaultSettings,
	flags = {
		Height = "Fixed",
		Width = "Fixed"
	},
	events = {"UnitIdUpdate"},
	enabledInThisExpansion = true
})

local function createBar(container)
	local bar = CreateFrame("StatusBar", nil, container)
	bar:SetAllPoints()
	bar:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
	bar:SetMinMaxValues(0, 1)

	bar.Background = bar:CreateTexture(nil, "BACKGROUND")
	bar.Background:SetAllPoints()
	bar.Background:SetColorTexture(0, 0, 0, 0.6)

	-- grey overlay shown while the cast can't be interrupted (alpha driven by a possibly secret boolean)
	bar.NotInterruptible = bar:CreateTexture(nil, "ARTWORK", nil, 2)
	bar.NotInterruptible:SetAllPoints(bar:GetStatusBarTexture())
	bar.NotInterruptible:SetColorTexture(0.55, 0.55, 0.55, 1)
	bar.NotInterruptible:SetAlpha(0)

	bar.Icon = bar:CreateTexture(nil, "OVERLAY")
	bar.Icon:SetPoint("RIGHT", bar, "LEFT", -2, 0)

	bar.Text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	bar.Text:SetPoint("LEFT", 2, 0)
	bar.Text:SetPoint("RIGHT", -2, 0)
	bar.Text:SetJustifyH("CENTER")
	bar.Text:SetWordWrap(false)
	return bar
end

function castBar:AttachToPlayerButton(playerButton)
	local container = CreateFrame("Frame", nil, playerButton)
	container.Bar = createBar(container)
	container.Bar:Hide()
	container:Hide()

	-- fallback for clients without duration objects: plain numbers only
	local function onUpdateFallback(bar)
		local now = GetTime() * 1000
		if now >= bar.endTime then
			bar:SetScript("OnUpdate", nil)
			bar:Hide()
			return
		end
		local progress = (now - bar.startTime) / (bar.endTime - bar.startTime)
		bar:SetValue(bar.isChannel and (1 - progress) or progress)
	end

	-- WarLegend: a unit token can point to another player by now (nameplates are reused): the cast is only
	-- shown when the unit is this button's player (when its name is readable; unreadable: the mapping is trusted)
	local function isThisPlayer(unit)
		local ok, name = pcall(WarLegendPvP.GetReadableUnitName, WarLegendPvP, unit)
		if not ok or not name then return true end
		local okB, btn = pcall(WarLegendPvP.GetPlayerbuttonByName, WarLegendPvP, name)
		return not okB or btn == nil or btn == playerButton
	end

	function container:Refresh()
		local bar = self.Bar
		bar:SetScript("OnUpdate", nil)
		local unit = self.unit
		if not unit or not UnitExists(unit) or not isThisPlayer(unit) then return bar:Hide() end

		local name, _, texture, startTime, endTime, _, _, notInterruptible = UnitCastingInfo(unit)
		local isChannel = false
		if type(name) == "nil" then
			name, _, texture, startTime, endTime, _, notInterruptible = UnitChannelInfo(unit)
			isChannel = true
		end
		if type(name) == "nil" then return bar:Hide() end

		bar.Icon:SetTexture(texture)
		bar.Text:SetText(name)
		if isChannel then
			bar:SetStatusBarColor(0, 1, 0)
		else
			bar:SetStatusBarColor(1, 0.7, 0)
		end
		if bar.NotInterruptible.SetAlphaFromBoolean and type(notInterruptible) ~= "nil" then
			bar.NotInterruptible:SetAlphaFromBoolean(notInterruptible)
		else
			bar.NotInterruptible:SetAlpha(0)
		end

		local duration
		if bar.SetTimerDuration and UnitCastingDuration then
			if isChannel then
				duration = UnitChannelDuration and UnitChannelDuration(unit)
			else
				duration = UnitCastingDuration(unit)
			end
		end
		if duration then
			local direction = isChannel and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime
			bar:SetTimerDuration(duration, nil, direction)
		elseif startTime and endTime and not issecret(startTime) and not issecret(endTime) and endTime > startTime then
			bar:SetMinMaxValues(0, 1)
			bar.startTime, bar.endTime, bar.isChannel = startTime, endTime, isChannel
			bar:SetScript("OnUpdate", onUpdateFallback)
		else
			return bar:Hide()
		end
		bar:Show()
	end

	container:SetScript("OnEvent", function(self)
		self:Refresh()
	end)

	function container:SetUnit(unitID)
		self:UnregisterAllEvents()
		-- "raid3target"-like tokens get no cast events: their bar would keep an old cast, none is shown
		if type(unitID) == "string" and unitID ~= "target" and unitID:find("target$") then unitID = nil end
		self.unit = unitID
		if unitID then
			for i = 1, #CAST_EVENTS do
				pcall(self.RegisterUnitEvent, self, CAST_EVENTS[i], unitID)
			end
		end
		self:Refresh()
	end

	--when unitID changes
	function container:UnitIdUpdate(unitID)
		self:SetUnit(unitID)
	end

	function container:Reset()
		self:SetUnit(nil)
	end

	function container:Disable()
		self:SetUnit(nil)
	end

	function container:ApplyAllSettings()
		if not self.config then return end
		local size = styleSizes[self.config.Style]
		if not size then -- i.e. the removed "Arena" style of an old profile
			self.config.Style = defaultSettings.Style
			size = styleSizes[defaultSettings.Style]
		end
		self:SetSize(size.width, size.height)
		self.Bar:SetStatusBarTexture(WarLegendPvP:GetBarTexture("cast", playerButton.PlayerType))
		self.Bar.Icon:SetSize(size.height + 4, size.height + 4)
		if self.config.Scale then
			self:SetScale(WarLegendPvP.SafeScale(self.config.Scale))
		end
		self:Show()
		self:SetUnit(playerButton:GetUnitID())
	end

	playerButton.CastBar = container
	return playerButton.CastBar
end
