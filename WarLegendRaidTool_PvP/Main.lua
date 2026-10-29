---@type string
local AddonName = ...
---@class Data
local Data = select(2, ...)
local issecret = issecretvalue or function() return false end -- WoW Forever secret values
local L = Data.L

--upvalues
local _G = _G
local math_random = math.random
local math_min = math.min
local pairs = pairs
local print = print
local table_insert = table.insert
local table_remove = table.remove
local time = time
local type = type
local unpack = unpack

local C_PvP = C_PvP
local CreateFrame = CreateFrame
local CTimerNewTicker = C_Timer.NewTicker
local GetBattlefieldArenaFaction = GetBattlefieldArenaFaction
local GetBattlefieldScore = GetBattlefieldScore
local GetBattlefieldTeamInfo = GetBattlefieldTeamInfo
local GetBestMapForUnit = C_Map.GetBestMapForUnit
local GetNumBattlefieldScores = GetNumBattlefieldScores
local GetNumGroupMembers = GetNumGroupMembers
local GetRaidRosterInfo = GetRaidRosterInfo
local GetTime = GetTime
local GetUnitName = GetUnitName
local InCombatLockdown = InCombatLockdown
local IsInInstance = IsInInstance
local IsInRaid = IsInRaid
local RequestBattlefieldScoreData = RequestBattlefieldScoreData
local SetBattlefieldScoreFaction = SetBattlefieldScoreFaction
local UnitExists = UnitExists
local UnitFactionGroup = UnitFactionGroup
local UnitGUID = UnitGUID
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsGhost = UnitIsGhost
local UnitName = UnitName
local UnitRace = UnitRace
local UnitRealmRelationship = UnitRealmRelationship

local IsClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
local IsTBCC = WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
local IsWrath = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC

local HasSpeccs = not not GetSpecialization  -- Mists of Pandaria

local MaxLevel = GetMaxPlayerLevel()

-- binding definitions
--BINDING_HEADER_BATTLEGROUNDENEMIES = "WarLegendPvP"
_G["BINDING_NAME_CLICK WLPvPAllies:Button4"] = L.TargetPreviousAlly
_G["BINDING_NAME_CLICK WLPvPAllies:Button5"] = L.TargetNextAlly
_G["BINDING_NAME_CLICK WLPvPEnemies:Button4"] = L.TargetPreviousEnemy
_G["BINDING_NAME_CLICK WLPvPEnemies:Button5"] = L.TargetNextEnemy


if not GetUnitName then
	GetUnitName = function(unit, showServerName)
		local name, server = UnitName(unit);

		if (server and server ~= "") then
			if (showServerName) then
				return name .. "-" .. server;
			else
				local relationship = UnitRealmRelationship(unit);
				if (relationship == LE_REALM_RELATION_VIRTUAL) then
					return name;
				else
					return name .. FOREIGN_SERVER_LABEL;
				end
			end
		else
			return name;
		end
	end
end


---@class WarLegendPvP: frame
WarLegendPvP = CreateFrame("Frame", "WarLegendPvP", UIParent)
WarLegendPvP.Counter = {}

--todo: add castbars and combat indicator to testmode
--move unitID update for allies

-- for Clique Support
ClickCastFrames = ClickCastFrames or {}


--[[
Ally frames use Scoreboard, FakePlayers, GroupMembers,
Enemy frames use Scoreboard, FakePlayers
(WoW Forever: no arena, and the combat log is closed to addons)
]]

WarLegendPvP.consts = {}
WarLegendPvP.consts.PlayerSources = {
	Scoreboard = "Scoreboard",
	GroupMembers = "GroupMembers",
	FakePlayers = "FakePlayers"
}
WarLegendPvP.consts.PlayerTypes = {
	Allies = "Allies",
	Enemies = "Enemies"
}

local previousCvarRaidOptionIsShown

--variables used in multiple functions, if a variable is only used by one function its declared above that function
WarLegendPvP.currentTarget = false
WarLegendPvP.currentFocus = false

WarLegendPvP.Testmode = {
	PlayerCountTestmode = 5,
}

WarLegendPvP.ButtonModules = {}   --contains moduleFrames, key is the module name
WarLegendPvP.UserFaction = UnitFactionGroup("player")
WarLegendPvP.UserButton = false   --the button of the Player himself
WarLegendPvP.specCache = {} -- key = GUID, value = specName (localized)


---@class bgeState
---@field WOW_PROJECT_ID number
---@field isInBattleground boolean
---@field currentMapId number|boolean
---@field isRatedBG boolean
---@field isSoloRBG boolean

WarLegendPvP.states = {
	testmodeActive = false,
	userIsAlive = not UnitIsDeadOrGhost("player"),
	---@type bgeState
	real = {
		WOW_PROJECT_ID = WOW_PROJECT_ID,
		isInBattleground = false,
		currentMapId = false,
		isRatedBG = false,
		isSoloRBG = false,
	},
	---@type bgeState
	test = {
		WOW_PROJECT_ID = WOW_PROJECT_ID,
		isInBattleground = false,
		currentMapId = false,
		isRatedBG = false,
		isSoloRBG = false,
	}
}

---@return bgeState
function WarLegendPvP:GetActiveStates()
	if self:IsTestmodeOrEditmodeActive() then
		return self.states.test
	else
		return self.states.real
	end
end

function WarLegendPvP:GetBattlegroundAuras()
	local states = self:GetActiveStates()
	if not states then return end
	return Data.BattlegroundspezificBuffs[states.currentMapId], Data.BattlegroundspezificDebuffs[states.currentMapId]
end






function WarLegendPvP:IsTestmodeOrEditmodeActive()
	return self.states.testmodeActive
end



function WarLegendPvP:GetPlayerCountsFromConfig(playerCountConfig)
	if type(playerCountConfig) ~= "table" then
		error("playerCountConfig must be a table")
	end
	local minPlayers = playerCountConfig.minPlayerCount
	local maxPlayers = playerCountConfig.maxPlayerCount
	return minPlayers, maxPlayers
end

function WarLegendPvP:GetPlayerCountConfigNameLocalized(playerCountConfig, isCustom)
	local minPlayers, maxPlayers = self:GetPlayerCountsFromConfig(playerCountConfig)
	return (isCustom and "*" or "") .. minPlayers.."–"..maxPlayers.. " ".. L.players
end

--WarLegendPvP.EnemyFaction
--WarLegendPvP.AllyFaction

--each module can heave one of the different types
--dynamicContainer == the container is only as big as the children its made of, the container sets only 1 point
--buttonHeightLengthVariable = a attachment that has the height of the button and a variable width (the module will set the width itself). when unused sets to 0.01 width
--buttonHeightSquare = a attachment that has the height of the button and the same width, when unused sets to 0.01 width
--HeightAndWidthVariable


function WarLegendPvP:IsModuleEnabledOnThisExpansion(moduleName)
	local moduleFrame = self.ButtonModules[moduleName]
	if moduleFrame then
		return moduleFrame.enabledInThisExpansion
	end
	return false
end

local function copySettingsWithoutOverwrite(src, dest)
	if not src or type(src) ~= "table" then return end
	if type(dest) ~= "table" then dest = {} end

	for k, v in pairs(src) do
		if type(v) == "table" then
			dest[k] = copySettingsWithoutOverwrite(v, dest[k])
		elseif type(v) ~= type(dest[k]) then -- only overwrite if the type in dest is different
			dest[k] = v
		end
	end

	return dest
end

local function copyModuleDefaultsIntoDefaults(location, moduleName, moduleDefaults)
	location.ButtonModules = location.ButtonModules or {}
	location.ButtonModules[moduleName] = location.ButtonModules[moduleName] or {}
	copySettingsWithoutOverwrite(moduleDefaults, location.ButtonModules[moduleName])
end

function WarLegendPvP:NewButtonModule(moduleSetupTable)
	if type(moduleSetupTable) ~= "table" then return error("Tried to register a Module but the parameter wasn't a table") end
	if not moduleSetupTable.moduleName then return error("NewButtonModule error: No moduleName specified") end
	local moduleName = moduleSetupTable.moduleName
	if not moduleSetupTable.localizedModuleName then
		return error("NewButtonModule error for module: " ..
			moduleName .. " No localizedModuleName specified")
	end
	if moduleSetupTable.enabledInThisExpansion == nil then
		return error("NewButtonModule error for module: " ..
			moduleName .. " enabledInThisExpansion is nil")
	end


	if self.ButtonModules[moduleName] then return error("module " .. moduleName .. " is already registered") end
	local moduleFrame = CreateFrame("Frame", nil, UIParent)

	moduleSetupTable.flags = moduleSetupTable.flags or {}
	Mixin(moduleFrame, moduleSetupTable)


	for k in pairs(self.consts.PlayerTypes) do
		for j = 1, #Data.defaultSettings.profile[k].playerCountConfigs do
			local playerCountConfig = Data.defaultSettings.profile[k].playerCountConfigs[j]
			copyModuleDefaultsIntoDefaults(playerCountConfig, moduleName, moduleSetupTable.defaultSettings)
		end

	end

	if moduleSetupTable.generalDefaults then
		copyModuleDefaultsIntoDefaults(Data.defaultSettings.profile, moduleName, moduleSetupTable.generalDefaults)
	end

	self.ButtonModules[moduleName] = moduleFrame
	return moduleFrame
end

---------------------------------------------------------------------------
-- Settings (WarLegend RaidTool: no AceDB, no options window)
-- WarLegendRaidTool_PvPDB keeps only what the player changed in the /wl tab; the profile the engine
-- reads (WarLegendPvP.db.profile) is rebuilt from Data.defaultSettings + those values.
-- Per side (Enemies / Allies) values apply to every player count config (10, 15, 40 players).
---------------------------------------------------------------------------
local GENERAL_KEYS = { "Style", "Locked", "EnableMouseWheelPlayerTargeting", "ShowBGEInBattleground",
	"DisableRaidFramesInBattleground", "ShowTooltips" }

-- modules the /wl tab can switch on / off (name, health bar and spec / class icon always shown)
WarLegendPvP.ToggleableModules = { "Level", "Power", "CastBar", "Role", "RaidTargetIcon", "TargetIndicatorNumeric",
	"TargetIndicatorSymbolic", "CombatIndicator", "ObjectiveAndRespawn", "Dispel", "CrowdControl" }

local function savedSide(side)
	local saved = WarLegendRaidTool_PvPDB
	saved[side] = type(saved[side]) == "table" and saved[side] or {}
	return saved[side]
end

function WarLegendPvP:BuildProfile()
	local saved = WarLegendRaidTool_PvPDB
	local profile = CopyTable(Data.defaultSettings.profile)
	profile.Style = "auto"
	for _, key in ipairs(GENERAL_KEYS) do
		if saved[key] ~= nil then profile[key] = saved[key] end
	end
	for side in pairs(self.consts.PlayerTypes) do
		local s = savedSide(side)
		local sideConfig = profile[side]
		if s.Enabled ~= nil then sideConfig.Enabled = s.Enabled end
		if type(s.Style) == "string" then sideConfig.Style = s.Style end
		if type(s.TextOutline) == "string" then sideConfig.TextOutline = s.TextOutline end
		-- WarLegend: health bar color (class / one color for all) and name in the class color (GetBarColor)
		sideConfig.BarColorMode = s.BarColorMode == "custom" and "custom" or "class"
		sideConfig.BarColor = type(s.BarColor) == "table" and s.BarColor or nil
		sideConfig.NameClassColor = s.NameClassColor and true or false
		-- the 1 px frame: nil = as the style has it, true / false = always / never
		if type(s.Border) == "boolean" then sideConfig.Border = s.Border else sideConfig.Border = nil end
		-- WarLegend: out of range distance and grey (PlayerButton.lua ApplyRangeDesaturation)
		if type(s.Range) == "number" then
			sideConfig.RangeIndicator_Range_InCombat = s.Range
			sideConfig.RangeIndicator_Range_OutOfCombat = s.Range
		end
		sideConfig.RangeIndicator_Mode = type(s.Range) == "string" and s.Range or nil
		sideConfig.RangeIndicator_Desaturate = s.RangeDesat and true or false
		-- WarLegend: right / middle click on an ally casts my dispel spells (Modules/Dispel.lua)
		if side == "Allies" and s.ClickDispel then
			sideConfig.RightButtonType = "Dispel"
			sideConfig.MiddleButtonType = "Dispel"
		end
		for _, cfg in ipairs(sideConfig.playerCountConfigs) do
			if s.Scale then cfg.Framescale = s.Scale end
			if s.Width then cfg.BarWidth = s.Width end
			if s.Height then cfg.BarHeight = s.Height end
			-- WarLegend: height of the power bar (energy / mana / rage) under the health bar, Modules/Power.lua
			if s.PowerHeight and cfg.ButtonModules.Power then cfg.ButtonModules.Power.Height = s.PowerHeight end
			if s.X and s.Y then cfg.Position_X, cfg.Position_Y = s.X, s.Y end
			if s.HealthText ~= nil and cfg.ButtonModules.healthBar then
				cfg.ButtonModules.healthBar.HealthTextEnabled = s.HealthText
				cfg.ButtonModules.healthBar.HealthTextType = "perc"
			end
			if type(s.Modules) == "table" then
				for moduleName, enabled in pairs(s.Modules) do
					if cfg.ButtonModules[moduleName] then cfg.ButtonModules[moduleName].Enabled = enabled end
				end
			end
		end
	end
	return profile
end

function WarLegendPvP:LoadSettings()
	-- the BattleGroundEnemies / AceDB format of an older version is not read, start clean
	if type(WarLegendRaidTool_PvPDB) ~= "table" or WarLegendRaidTool_PvPDB.profileKeys then
		WarLegendRaidTool_PvPDB = {}
	end
	self.db = { profile = self:BuildProfile() }
	if type(WarLegendRaidTool_PvPDB.TestPlayerCount) == "number" then
		self.Testmode.PlayerCountTestmode = WarLegendRaidTool_PvPDB.TestPlayerCount
	end
end

-- general value (Style, Locked...), saved value or default
function WarLegendPvP:GetSetting(key)
	return self.db.profile[key]
end

function WarLegendPvP:SetSetting(key, value)
	WarLegendRaidTool_PvPDB[key] = value
	self.db.profile = self:BuildProfile()
	self:ApplyAllSettingsDebounce()
end

-- per side value: the saved one, or the default of the 15 players config (the usual battleground size)
function WarLegendPvP:GetSideSetting(side, key, moduleName)
	local s = savedSide(side)
	local cfg = self.db.profile[side].playerCountConfigs[2]
	if key == "Modules" then
		if s.Modules and s.Modules[moduleName] ~= nil then return s.Modules[moduleName] end
		return cfg.ButtonModules[moduleName] and cfg.ButtonModules[moduleName].Enabled
	elseif key == "Enabled" then
		return self.db.profile[side].Enabled
	elseif key == "Scale" then
		return s.Scale or cfg.Framescale
	elseif key == "Width" then
		return s.Width or cfg.BarWidth
	elseif key == "PowerHeight" then
		return s.PowerHeight or (cfg.ButtonModules.Power and cfg.ButtonModules.Power.Height) or 5
	elseif key == "Height" then
		return s.Height or cfg.BarHeight
	elseif key == "HealthText" then
		return cfg.ButtonModules.healthBar and cfg.ButtonModules.healthBar.HealthTextEnabled
	elseif key == "ClickDispel" then
		return s.ClickDispel and true or false
	elseif key == "Style" then
		return s.Style or self.db.profile.Style or "auto"
	elseif key == "TextOutline" then
		return s.TextOutline or "shadow"
	elseif key == "BarColorMode" then
		return s.BarColorMode == "custom" and "custom" or "class"
	elseif key == "BarColor" then
		return type(s.BarColor) == "table" and s.BarColor or { 0.25, 0.25, 0.25 }
	elseif key == "NameClassColor" then
		return s.NameClassColor and true or false
	elseif key == "Border" then
		if type(s.Border) == "boolean" then return s.Border end
		return self:StyleHasBorder(side)
	elseif key == "RangeDesat" then
		return s.RangeDesat and true or false
	elseif key == "Range" then
		return s.Range or self.db.profile[side].RangeIndicator_Range_InCombat
	end
end

function WarLegendPvP:SetSideSetting(side, key, value, moduleName)
	local s = savedSide(side)
	if key == "Modules" then
		s.Modules = s.Modules or {}
		s.Modules[moduleName] = value
	else
		s[key] = value
	end
	self.db.profile = self:BuildProfile()
	self:ApplyAllSettingsDebounce()
end

-- called when an unlocked frame was dragged: the same place for every player count
function WarLegendPvP:SavePosition(side, x, y)
	local s = savedSide(side)
	s.X, s.Y = x, y
	for _, cfg in ipairs(self.db.profile[side].playerCountConfigs) do
		cfg.Position_X, cfg.Position_Y = x, y
	end
end

function WarLegendPvP:ResetSettings()
	WarLegendRaidTool_PvPDB = {}
	self.Testmode.PlayerCountTestmode = 5
	self.db.profile = self:BuildProfile()
	self:ApplyAllSettingsDebounce()
end

-- test mode player count, 1 to 40 like the BattleGroundEnemies slider, kept between sessions
local testCountTimer
function WarLegendPvP:GetTestPlayerCount()
	return self.Testmode.PlayerCountTestmode
end

function WarLegendPvP:SetTestPlayerCount(value)
	value = math.max(1, math.min(40, math.floor(value)))
	self.Testmode.PlayerCountTestmode = value
	WarLegendRaidTool_PvPDB.TestPlayerCount = value
	if testCountTimer then testCountTimer:Cancel() end -- several clicks in a row: rebuild the fake players once
	testCountTimer = C_Timer.NewTimer(0.2, function()
		testCountTimer = nil
		if WarLegendPvP:IsTestmodeOrEditmodeActive() then
			WarLegendPvP:CreateFakePlayers()
		end
	end)
end

local applyTimer
function WarLegendPvP:ApplyAllSettingsDebounce()
	if applyTimer then applyTimer:Cancel() end -- sliders fire many times, apply once they settle
	applyTimer = C_Timer.NewTimer(0.2, function()
		applyTimer = nil
		WarLegendPvP:ApplyAllSettings()
	end)
end

---------------------------------------------------------------------------
-- Style: "eui" (EllesmereUI look, needs EllesmereUI) or "blizzard" (native look); "auto" = EllesmereUI
-- when it is installed
---------------------------------------------------------------------------
local euiSkin
local BLIZZARD_HEALTH_BAR = [[Interface\RaidFrame\Raid-Bar-Hp-Fill]]
local BLIZZARD_BAR = [[Interface\TargetingFrame\UI-StatusBar]]
local FLAT_BAR = [[Interface\Buttons\WHITE8X8]]

if EllesmereUI and EllesmereUI.RegisterSkin then
	EllesmereUI.RegisterSkin("WarLegendRaidTool_PvP", function(S)
		euiSkin = S
		if S.OnLooksChanged then
			S.OnLooksChanged(function()
				if WarLegendPvP.db then WarLegendPvP:ApplyAllSettingsDebounce() end
			end)
		end
		if WarLegendPvP.db then WarLegendPvP:ApplyAllSettingsDebounce() end
	end)
end

function WarLegendPvP:HasEllesmereUI()
	return euiSkin ~= nil
end

-- WarLegend: the game's own range checks (PlayerButton:UpdateRangeViaLibRangeCheck). nil = no answer (spell not
-- known, value kept secret, unit not in my group...), LibRangeCheck is then used.
-- My main spell per class: a helpful one for the allies, a harmful one for the enemies (first one I know).
local RANGE_SPELLS = {
	help = {
		PRIEST = { 2050, 2061 }, PALADIN = { 635, 19750 }, DRUID = { 5185, 774 }, SHAMAN = { 331, 8004 },
		MAGE = { 1459 }, WARLOCK = { 5697 },
	},
	harm = {
		PRIEST = { 585, 589 }, PALADIN = { 20271, 879 }, DRUID = { 5176, 8921 }, SHAMAN = { 403, 8042 },
		MAGE = { 133, 116 }, WARLOCK = { 686, 172 }, HUNTER = { 75, 1978 }, ROGUE = { 1752, 2764 },
		WARRIOR = { 78, 100 },
	},
}
local rangeSpellCache = {}
local function rangeSpell(harm)
	local key = harm and "harm" or "help"
	if rangeSpellCache[key] ~= nil then return rangeSpellCache[key] or nil end
	local _, class = UnitClass("player")
	rangeSpellCache[key] = false
	for _, id in ipairs(RANGE_SPELLS[key][class] or {}) do
		local known = (IsPlayerSpell and IsPlayerSpell(id)) or (IsSpellKnown and IsSpellKnown(id))
		if known then rangeSpellCache[key] = id; break end
	end
	return rangeSpellCache[key] or nil
end
-- spells learned while playing: looked for again
local rangeSpellReset = CreateFrame("Frame")
rangeSpellReset:RegisterEvent("SPELLS_CHANGED")
rangeSpellReset:SetScript("OnEvent", function() wipe(rangeSpellCache) end)

local function readable(v)
	if v == nil or issecret(v) then return nil end
	return v
end

function WarLegendPvP.GameRangeCheck(mode, unit, isEnemy)
	if mode == "blizzard" and not isEnemy and UnitInRange then
		local ok, inRange, checked = pcall(UnitInRange, unit)
		inRange, checked = readable(inRange), readable(checked)
		if ok and checked and inRange ~= nil then return inRange and true or false end
		return nil
	end
	if mode == "spell" or mode == "blizzard" then
		local id = rangeSpell(isEnemy)
		if not id then return nil end
		local ok, r
		if C_Spell and C_Spell.IsSpellInRange then
			ok, r = pcall(C_Spell.IsSpellInRange, id, unit)
		elseif IsSpellInRange and GetSpellInfo then
			ok, r = pcall(IsSpellInRange, GetSpellInfo(id), unit)
		end
		if not ok then return nil end
		r = readable(r)
		if type(r) == "number" then return r == 1 end -- old API: 1 in range, 0 out, nil no check
		if type(r) == "boolean" then return r end
	end
	return nil
end

-- WarLegend: fn(item) every `period` seconds (a number or a function giving it) for each item of getList() (an array),
-- by ONE OnUpdate on a frame child of parent (it runs while parent is shown) that spreads the items over the frames
-- (round robin). One throttled OnUpdate per button, all started together (the scoreboard makes the 40 buttons of a side
-- at once), did the work of every button in the same frame: a spike every 0.2 s.
function WarLegendPvP.Spread(parent, period, getList, fn)
	local driver = CreateFrame("Frame", nil, parent)
	local budget, index = 0, 1
	driver:SetScript("OnUpdate", function(_, elapsed)
		local list = getList()
		local n = #list
		if n == 0 then budget = 0; return end
		local p = type(period) == "function" and period() or period
		budget = math_min(budget + n * elapsed / p, n) -- a long frame (loading screen) does one round, not more
		while budget >= 1 do
			budget = budget - 1
			if index > n then index = 1 end
			local item = list[index]
			index = index + 1
			if item then fn(item) end
		end
	end)
	return driver
end

-- WarLegend: one style per side (Allies / Enemies), the general one when a side has none. Textures of the game
-- only: blizzard (raid health bar + status bar), flat (plain), smooth (raid bar everywhere), classic (skill bar)
local SKILL_BAR = [[Interface\PaperDollInfoFrame\UI-Character-Skills-Bar]]
local STYLES = {
	blizzard = { health = BLIZZARD_HEALTH_BAR, bar = BLIZZARD_BAR },
	eui = { health = FLAT_BAR, bar = FLAT_BAR, border = true },
	flat = { health = FLAT_BAR, bar = FLAT_BAR, border = true, outline = "OUTLINE" },
	smooth = { health = BLIZZARD_HEALTH_BAR, bar = BLIZZARD_HEALTH_BAR, border = true },
	classic = { health = SKILL_BAR, bar = SKILL_BAR, border = true },
}

-- the side (Allies / Enemies) a frame belongs to: its player button or main frame carries PlayerType
local function sideOf(frame)
	for _ = 1, 10 do
		if not frame then return nil end
		if frame.PlayerType then return frame.PlayerType end
		frame = frame.GetParent and frame:GetParent()
	end
end
WarLegendPvP.SideOf = sideOf

function WarLegendPvP:GetStyle(side)
	local p = self.db and self.db.profile
	local style = p and ((side and p[side] and p[side].Style) or p.Style) or "auto"
	if style == "auto" then style = euiSkin and "eui" or "blizzard" end
	if style == "eui" and not euiSkin then style = "blizzard" end
	if not STYLES[style] then style = "blizzard" end
	return style
end

-- WarLegend: the health bar color of a player button: the side's single color, or the class color
function WarLegendPvP:GetBarColor(playerButton)
	local cfg = self.db and self.db.profile[playerButton.PlayerType]
	if cfg and cfg.BarColorMode == "custom" and type(cfg.BarColor) == "table" then
		return cfg.BarColor[1] or 0.25, cfg.BarColor[2] or 0.25, cfg.BarColor[3] or 0.25
	end
	local c = playerButton.PlayerDetails and playerButton.PlayerDetails.PlayerClassColor
	if c then return c.r, c.g, c.b end
	return 0.5, 0.5, 0.5
end

function WarLegendPvP:StyleHasBorder(side)
	local p = self.db and self.db.profile
	if side and p and p[side] and type(p[side].Border) == "boolean" then return p[side].Border end -- the side's choice
	return STYLES[self:GetStyle(side)].border and true or false
end

-- kind: "health", "power" or "cast"
function WarLegendPvP:GetBarTexture(kind, side)
	local s = STYLES[self:GetStyle(side)]
	return kind == "health" and s.health or s.bar
end

-- font path, outline flag, shadow
function WarLegendPvP:GetFont(side)
	local style = self:GetStyle(side)
	if style == "eui" and euiSkin.GetFont then
		local path, outline = euiSkin.GetFont()
		if path then return path, outline or "", false end
	end
	local outline = STYLES[style].outline
	return STANDARD_TEXT_FONT or [[Fonts\FRIZQT__.TTF]], outline or "", not outline
end

function WarLegendPvP:GetAccentColor()
	if euiSkin and euiSkin.GetAccentColor then
		local r, g, b = euiSkin.GetAccentColor()
		if r then return r, g, b end
	end
	return 1, 1, 1
end

-- Module sizing helpers, from BattleGroundEnemies Options.lua (kept as they were: the module layout uses them)
local function isInSameHorizontal(Point1, Point2)
    local p1 = (Point1.Point:match("(TOP)")) or (Point1.Point:match("(BOTTOM)")) or false
    local p2 = (Point2.Point:match("(TOP)")) or (Point2.Point:match("(BOTTOM)")) or false
    if p1=="TOP" and p2=="TOP" then
        return true
    elseif not (p1=="TOP" or p2=="TOP" or p1=="BOTTOM" or p2=="BOTTOM") then
        return true
    elseif p1=="BOTTOM" and p2=="BOTTOM" then
        return true
    end
end

---comment
---@param Point1 any
---@param Point2 any
---@return boolean
local function isInSameVertical(Point1, Point2)
    local p1 = (Point1.Point:match("(LEFT)")) or (Point1.Point:match("(RIGHT)")) or false
    local p2 = (Point2.Point:match("(LEFT)")) or (Point2.Point:match("(RIGHT)")) or false
    if p1=="LEFT" and p2=="LEFT" then
        return true
    elseif not (p1=="LEFT" or p2=="LEFT" or p1=="RIGHT" or p2=="RIGHT") then
        return true
    elseif p1=="RIGHT" and p2=="RIGHT" then
        return true
    end
	return false
end

function WarLegendPvP:GetActivePoints(config)
	if not config.Points then return end
	local activePoints = {}
	for i = 1, config.ActivePoints do
		activePoints[i] = config.Points[i]
	end
	return activePoints
end

function WarLegendPvP:FrameNeedsHeight(Point1, Point2)
	if not Point1 and not Point2 then return end
	if Point1 and not Point2 then return true end
	return isInSameHorizontal(Point1, Point2)
end

function WarLegendPvP:ModuleFrameNeedsHeight(moduleFrame, config)
	local flags = moduleFrame.flags

	if flags.HasDynamicSize then return false end

	local heightFlag = flags.Width

	if heightFlag == "Fixed" then return end

	local activePoints = self:GetActivePoints(config)
	if not activePoints then return end
	return WarLegendPvP:FrameNeedsWidth(activePoints[1], activePoints[2])
end


function WarLegendPvP:FrameNeedsWidth(Point1, Point2)
	if not Point1 and not Point2 then return end
	if Point1 and not Point2 then return true end
	return isInSameVertical(Point1, Point2)
end

function WarLegendPvP:ModuleFrameNeedsWidth(moduleFrame, config)
	local flags = moduleFrame.flags

	if flags.HasDynamicSize then return false end

	local widthFlag = flags.Width

	if widthFlag == "Fixed" then return end

	local activePoints = self:GetActivePoints(config)
	if not activePoints then return end
	return WarLegendPvP:FrameNeedsWidth(activePoints[1], activePoints[2])
end

local sentDebugMessages = {}
function WarLegendPvP:OnetimeDebug(...)
	local message = table.concat({ ... }, ", ")
	if sentDebugMessages[message] then return end
	sentDebugMessages[message] = true
	self:Debug(...)
end

WarLegendPvP:SetScript("OnEvent", function(self, event, ...)
	--self.Counter[event] = (self.Counter[event] or 0) + 1
	if self.db and self.db.profile and self.db.profile.DebugBlizzEvents then
		self:Debug("WarLegendPvP OnEvent", event, ...)
	end
	Data.SafeCall(self[event], self, ...)
end)

function WarLegendPvP:ShowTooltip(owner, func)
	if self.db.profile.ShowTooltips then
		GameTooltip:SetOwner(owner, "ANCHOR_RIGHT", 0, 0)
		func()
		GameTooltip:Show()
	end
end

function WarLegendPvP:GetColoredName(playerButton)
	if not playerButton.PlayerDetails then return end
	local name = playerButton.PlayerDetails.PlayerName
	local tbl = playerButton.PlayerDetails.PlayerClassColor
	return ("|cFF%02x%02x%02x%s|r"):format(tbl.r * 255, tbl.g * 255, tbl.b * 255, name)
end

---@type FunctionContainer
WarLegendPvP.FakePlayersUpdateTicker = nil

local function stopFakePlayersTicker()
	if WarLegendPvP.FakePlayersUpdateTicker then
		WarLegendPvP.FakePlayersUpdateTicker:Cancel()
		WarLegendPvP.FakePlayersUpdateTicker = nil
	end
end

local function createFakePlayersTicker(seconds, callback)
	local ticker = CTimerNewTicker(seconds, callback)
	stopFakePlayersTicker()
	WarLegendPvP.FakePlayersUpdateTicker = ticker
	return ticker
end



-- WoW Forever: no fake auras / DRs in the test mode, the aura modules are gone (enemy auras are secret in battlegrounds)
function WarLegendPvP:SetupTestmode()
	local mapIDs = {}
	for mapID in pairs(Data.BattlegroundspezificBuffs) do
		table.insert(mapIDs, mapID)
	end
	WarLegendPvP.states.test.currentMapId = mapIDs[math_random(1, #mapIDs)]
	WarLegendPvP.states.test.isInBattleground = true
	WarLegendPvP.states.test.isRatedBG = false

	self:CreateFakePlayers()
	self:CheckEnableState()
end

do
	local counter

	function WarLegendPvP:FillFakePlayerData(amount, mainFrame, role)
		for i = 1, amount do
			local name, classToken, specName

			if HasSpeccs and #Data.RolesToSpec[role] > 0 then
				local randomSpec
				randomSpec = Data.RolesToSpec[role][math_random(1, #Data.RolesToSpec[role])]
				classToken = randomSpec.classToken
				specName = randomSpec.specName
			else
				classToken = Data.ClassList[math_random(1, #Data.ClassList)]
			end
			local nameprefix = mainFrame.PlayerType == self.consts.PlayerTypes.Enemies and "Enemy" or "Ally"
			name = L[nameprefix] .. counter .. "-Realm" .. counter

			mainFrame:AddPlayerToSource(self.consts.PlayerSources.FakePlayers, {
				name = name,
				raceName = nil,
				classToken = classToken,
				specName = specName,
				additionalData = {
					isFakePlayer = true,
					PlayerLevel = i == 1 and MaxLevel or math_random(MaxLevel - 10, MaxLevel - 1)
				}
			})
			counter = counter + 1
		end
	end

	function WarLegendPvP:CreateFakePlayers()
		local count = self.Testmode.PlayerCountTestmode or 5

		for number, mainFrame in pairs({ self.Allies, self.Enemies }) do
			local remaining = count
			if mainFrame == self.Allies then
				remaining = remaining - 1
			end
			mainFrame:BeforePlayerSourceUpdate(self.consts.PlayerSources.FakePlayers)

			local healerAmount = math_random(2, 3)
			healerAmount = math_min(healerAmount, remaining)
			remaining = remaining - healerAmount
			local tankAmount = math_random(1)
			tankAmount = math_min(tankAmount, remaining)
			remaining = remaining - tankAmount
			local damagerAmount = remaining

			counter = 1
			WarLegendPvP:FillFakePlayerData(healerAmount, mainFrame, "HEALER")
			WarLegendPvP:FillFakePlayerData(tankAmount, mainFrame, "TANK")
			WarLegendPvP:FillFakePlayerData(damagerAmount, mainFrame, "DAMAGER")

			mainFrame:AfterPlayerSourceUpdate()
		end
	end
end

local function fakePlayersTestmodeTicker()
	for number, mainFrame in pairs({ WarLegendPvP.Allies, WarLegendPvP.Enemies }) do
		mainFrame:OnTestmodeTick()
	end
end

local function setupFakePlayersTestmodeTicker()
	createFakePlayersTicker(1, fakePlayersTestmodeTicker)
end

function WarLegendPvP.ToggleTestmodeOnUpdate()
	local enabled = not WarLegendPvP.FakePlayersUpdateTicker
	if enabled then
		setupFakePlayersTestmodeTicker()
		WarLegendPvP:Information(L.FakeEventsEnabled)
	else
		stopFakePlayersTicker()
		WarLegendPvP:Information(L.FakeEventsDisabled)
	end
end

function WarLegendPvP:EnableTestMode()
	if InCombatLockdown() then
		return WarLegendPvP:Information(L.ErrorTestmodeInCombat)
	end
	self:GROUP_ROSTER_UPDATE(true) -- not read outside a battleground: my own button comes from it, as before the test mode
	self.states.testmodeActive = true
	self:SetupTestmode()

	self.Allies:OnTestmodeEnabled()
	self.Enemies:OnTestmodeEnabled()
	self:Information(L.TestmodeEnabled)
end

function WarLegendPvP:DisableTestMode()
	self.states.testmodeActive = false
	self:Information(L.TestmodeDisabled)
	self.Allies:OnTestmodeDisabled()
	self.Enemies:OnTestmodeDisabled()
	self:CheckEnableState()
end

function WarLegendPvP.ToggleTestmode()
	if WarLegendPvP.states.testmodeActive then
		WarLegendPvP:DisableTestMode()
	else
		WarLegendPvP:EnableTestMode()
	end
end

-- name kept from BattleGroundEnemies (there was an edit mode too, replaced by dragging the unlocked frames)
function WarLegendPvP:DisableTestOrEditmode()
	if self.states.testmodeActive then
		return self:DisableTestMode()
	end
end


local RequestFrame = CreateFrame("Frame", nil, WarLegendPvP)
RequestFrame:Hide()
do
	local TimeSinceLastOnUpdate = 0
	local UpdatePeroid = 2                   --update every second
	local function RequestTicker(self, elapsed) --OnUpdate runs if the frame RequestFrame is shown
		TimeSinceLastOnUpdate = TimeSinceLastOnUpdate + elapsed
		if TimeSinceLastOnUpdate > UpdatePeroid then
			RequestBattlefieldScoreData()
			TimeSinceLastOnUpdate = 0
		end
	end
	RequestFrame:SetScript("OnUpdate", RequestTicker)
end

WarLegendPvP:RegisterEvent("PLAYER_LOGIN") --Fired on reload UI and on initial loading screen

-- WoW Forever: COMBAT_LOG_EVENT_UNFILTERED is protected (ADDON_ACTION_FORBIDDEN) and has no payload,
-- the flag carriers come from the battleground messages. Enemy auras and spell IDs are secret in
-- battlegrounds, so nothing here reads them (no aura, DR, trinket or racial tracking)
WarLegendPvP.GeneralEvents = {
	"UPDATE_MOUSEOVER_UNIT",
	"PLAYER_TARGET_CHANGED",
	"PLAYER_FOCUS_CHANGED",
	"RAID_TARGET_UPDATE",
	"UNIT_TARGET",
	"UNIT_HEALTH",
	"UNIT_MAXHEALTH",
	"UNIT_POWER_FREQUENT",
	"UNIT_POWER_UPDATE", -- the same bar, for a client without the FREQUENT event or with a slower one
	"UNIT_MAXPOWER",
	"UNIT_DISPLAYPOWER",
	"CHAT_MSG_BG_SYSTEM_HORDE",
	"CHAT_MSG_BG_SYSTEM_ALLIANCE",
	"CHAT_MSG_BG_SYSTEM_NEUTRAL",
	"PLAYER_REGEN_ENABLED",
	"PLAYER_REGEN_DISABLED"
}

function WarLegendPvP:RegisterEvents()
	local events = self.GeneralEvents
	for i = 1, #events do
		local event = events[i]
		if not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid(event) then
			pcall(self.RegisterEvent, self, event)
		end
	end
end

function WarLegendPvP:UnregisterEvents()
	local allEvents = self.GeneralEvents
	for i = 1, #allEvents do
		if self:IsEventRegistered(allEvents[i]) then
			self:UnregisterEvent(allEvents[i])
		end
	end
end

-- if lets say raid1 leaves all remaining players get shifted up, so raid2 is the new raid1, raid 3 gets raid2 etc.



local function EnableShadowColor(fontString, enableShadow, shadowColor)
	if shadowColor then fontString:SetShadowColor(unpack(shadowColor)) end
	if enableShadow then
		fontString:SetShadowOffset(1, -1)
	else
		fontString:SetShadowOffset(0, 0)
	end
end

function WarLegendPvP.CropImage(texture, width, height, hasTexcoords)
	local left, right, top, bottom = 0.075, 0.925, 0.075, 0.925
	local ratio = height / width
	if ratio > 1 then --crop the sides
		ratio = 1 / ratio
		texture:SetTexCoord((left) + ((1 - ratio) / 2), right - ((1 - ratio) / 2), top, bottom)
	elseif ratio == 1 then
		texture:SetTexCoord(left, right, top, bottom)
	else
		-- crop the height
		texture:SetTexCoord(left, right, top + ((1 - ratio) / 2), bottom - ((1 - ratio) / 2))
	end
end

local function ApplyFontStringSettings(fs, settings, isCooldown)
	local globals = Mixin({}, WarLegendPvP.db.profile.Text)
	if isCooldown then
		globals = Mixin({}, globals, WarLegendPvP.db.profile.Cooldown)
	end

	local configTable = Mixin({}, globals, settings)

	-- font, outline and shadow follow the style (EllesmereUI font or Blizzard's), the sizes stay per module
	local side = sideOf(fs:GetParent())
	local fontPath, styleOutline, styleShadow = WarLegendPvP:GetFont(side)
	local outline = configTable.FontOutline
	if outline == nil or outline == "" then outline = styleOutline end
	-- WarLegend: text edge per side (TextOutline): "shadow" (default, a full black drop shadow: smooth, readable
	-- on the white priest bar), "outline" / "thick" (the game's outline, sharper but pixelated at small sizes)
	local p = WarLegendPvP.db.profile
	local mode = (side and p[side] and p[side].TextOutline) or "shadow"
	if mode == "outline" then
		outline = "OUTLINE"
	elseif mode == "thick" then
		outline = "THICKOUTLINE"
	else
		styleShadow = true
	end
	-- through WarLegend's font family: Cyrillic / Asian names keep their letters (no squares)
	if WLRT and WLRT.SetFont then
		WLRT.SetFont(fs, fontPath, configTable.FontSize, outline)
	else
		fs:SetFont(fontPath, configTable.FontSize, outline)
	end
	configTable.EnableShadow = configTable.EnableShadow or styleShadow


	--idk why, but without this the SetJustifyH and SetJustifyV dont seem to work sometimes even tho GetJustifyH returns the new, correct value
	fs:GetRect()
	fs:GetStringHeight()
	fs:GetStringWidth()

	if configTable.JustifyH then
		fs:SetJustifyH(configTable.JustifyH)
	end

	if configTable.JustifyV then
		fs:SetJustifyV(configTable.JustifyV)
	end

	if configTable.WordWrap ~= nil then
		fs:SetWordWrap(configTable.WordWrap)
	end

	if configTable.FontColor then
		fs:SetTextColor(unpack(configTable.FontColor))
	end

	fs:EnableShadowColor(configTable.EnableShadow, configTable.ShadowColor)
end

local function ApplyCooldownSettings(self, config, cdReverse, swipeColor)
	local configTable = Mixin({}, WarLegendPvP.db.profile.Cooldown, config)
	self:SetReverse(cdReverse)
	self:SetDrawSwipe(configTable.DrawSwipe)
	self:SetDrawEdge(configTable.DrawSwipe)
	if swipeColor then self:SetSwipeColor(unpack(swipeColor)) end
	self:SetHideCountdownNumbers(not configTable.ShowNumber)
	if self.Text then
		self.Text:ApplyFontStringSettings(config, true)
	end
end


---comment
---@param parent Frame
function WarLegendPvP.MyCreateFontString(parent)
	---@class MyFontString: fontstring
	---@field DisplayedName string
	local fontString = parent:CreateFontString(nil, "OVERLAY")
	fontString.ApplyFontStringSettings = ApplyFontStringSettings
	fontString.EnableShadowColor = EnableShadowColor
	fontString:SetDrawLayer('OVERLAY', 2)
	return fontString
end

---comment
---@param frame cooldown
---@return fontstring?
function WarLegendPvP.GrabFontString(frame)
	for _, region in pairs { frame:GetRegions() } do
		if region:GetObjectType() == "FontString" then
			return region
		end
	end
end

function WarLegendPvP.AttachCooldownSettings(cooldown)
	cooldown.ApplyCooldownSettings = ApplyCooldownSettings
	-- Find fontstring of the cooldown
	local fontstring = WarLegendPvP.GrabFontString(cooldown)
	if fontstring then
		---@class MyFontString
		cooldown.Text = fontstring
		cooldown.Text.ApplyFontStringSettings = ApplyFontStringSettings
		cooldown.Text.EnableShadowColor = EnableShadowColor
	end
end

function WarLegendPvP.MyCreateCooldown(parent)
	local cooldown = CreateFrame("Cooldown", nil, parent)
	cooldown:SetAllPoints()
	cooldown:SetSwipeTexture('Interface/Buttons/WHITE8X8')

	WarLegendPvP.AttachCooldownSettings(cooldown)

	return cooldown
end

function WarLegendPvP:Disable()
	self:Debug("WarLegendPvP disabled")
	self.enabled = false
	self:UnregisterEvents()
	RequestFrame:Hide()
	stopFakePlayersTicker()
	self.Allies:Disable()
	self.Enemies:Disable()
end

function WarLegendPvP:Enable()
	self:Debug("WarLegendPvP enabled")
	self.enabled = true

	self:RegisterEvents()
	if WarLegendPvP:IsTestmodeOrEditmodeActive() then
		setupFakePlayersTestmodeTicker()
		RequestFrame:Hide()
	else
		RequestFrame:Show()
		stopFakePlayersTicker()
	end
	self.Allies:CheckEnableState()
	self.Enemies:CheckEnableState()
end

function WarLegendPvP:CheckEnableState()
	self:Debug("CheckEnableState")
	local states = WarLegendPvP:GetActiveStates()
	if states.isInBattleground and WarLegendPvP.db.profile.ShowBGEInBattleground then
		return self:Enable()
	end
	self:Disable()
end


do
	local function PVPMatchScoreboard_OnHide()
		if PVPMatchScoreboard.selectedTab ~= 1 then
			-- user was looking at another tab than all players
			SetBattlefieldScoreFaction() -- request a UPDATE_BATTLEFIELD_SCORE
		end
	end




	--Triggered immediately before PLAYER_ENTERING_WORLD on login and UI Reload, but NOT when entering/leaving instances.
	function WarLegendPvP:PLAYER_LOGIN()
		self.UserDetails = {
			-- full name ("First Surname" on Forever), as the other allies are keyed (GetReadableUnitName)
			PlayerName = self:GetReadableUnitName("player") or UnitName("player"),
			FirstName = UnitName("player"),
			PlayerClass = select(2, UnitClass("player")),
			isGroupLeader = UnitIsGroupLeader("player"),
			isGroupAssistant = UnitIsGroupAssistant("player"),
			unit = "player",
			GUID = UnitGUID("player")
		}

		self:LoadSettings()

		WarLegendPvP:ApplyAllSettings()

		self:RegisterEvent("GROUP_ROSTER_UPDATE") --Fired whenever a group or raid is formed or disbanded, players are leaving or joining the group or raid.
		self:RegisterEvent("PLAYER_ENTERING_WORLD") -- fired on reload UI and on every loading screen (for switching zones, intances etc)
		self:RegisterEvent("PARTY_LEADER_CHANGED") --Fired when the player's leadership changed.
		self:RegisterEvent("PLAYER_ALIVE") --Fired when the player releases from death to a graveyard; or accepts a resurrect before releasing their spirit. Does not fire when the player is alive after being a ghost. PLAYER_UNGHOST is triggered in that case.
		self:RegisterEvent("PLAYER_UNGHOST") --Fired when the player is alive after being a ghost.
		self:RegisterEvent("PLAYER_DEAD") --Fired when the player has died.
		self:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")



		if PVPMatchScoreboard then -- for TBCC, IsTBCC
			PVPMatchScoreboard:HookScript("OnHide", PVPMatchScoreboard_OnHide)
		end

		--DBObjectLib:ResetProfile(noChildren, noCallbacks)


		self:GROUP_ROSTER_UPDATE() --Scan again, the user could have reloaded the UI so GROUP_ROSTER_UPDATE didnt fire

		self:UnregisterEvent("PLAYER_LOGIN")
	end
end

--Notes about UnitIDs
--priority of unitIDs:
--1. nameplates, detected by UNIT_HEALTH, NAME_PLATE_UNIT_ADDED, NAME_PLATE_UNIT_REMOVED
--2. player's target
--3. player's focus
--4. ally targets, UNIT_TARGET fires if the target changes, we need to check for UnitExists() since there is a small time frame after an ally lost that enemy where UnitExists returns false for that unitID



function WarLegendPvP:ApplyAllSettings()
	WarLegendPvP:CheckEnableState()
	WarLegendPvP.Allies:SelectPlayerCountProfile(true)
	WarLegendPvP.Enemies:SelectPlayerCountProfile(true)
	WarLegendPvP:ToggleRaidFrames()
end

function WarLegendPvP:Debug(...)
	if not (self.db and self.db.profile and self.db.profile.Debug) then return end
	print("|cff0099ffWaR LegenD PvP debug:|r", ...)
end

local sentMessages = {}
function WarLegendPvP:OnetimeInformation(...)
	local message = table.concat({ ... }, ", ")
	if sentMessages[message] then return end
	print("|cff0099ffWaR LegenD PvP:|r", message)
	sentMessages[message] = true
end

function WarLegendPvP:Information(...)
	print("|cff0099ffWaR LegenD PvP:|r", ...)
end



-- WoW Forever: names are "First Surname". Depending on the API the same player comes as "First Surname",
-- "First-Surname" (the surname where other clients had the realm) or "First" alone, so a lookup by name
-- tries those forms. A first name alone (allowFirstName, used for the battleground messages) only matches
-- when one shown player has it.
local function findPlayerInTable(players, name, allowFirstName)
	if type(name) ~= "string" or issecret(name) or name == "" then return end
	local playerButton = players[name]
	if playerButton then return playerButton end

	local first, rest = name:match("^([^%s%-]+)[%s%-](.+)$")
	if first then
		return players[first .. " " .. rest] or players[first .. "-" .. rest]
	end

	if not allowFirstName then return end

	-- only a first name: unique match on the first part of the shown names
	local found
	for playerName, button in pairs(players) do
		local playerFirst = playerName:match("^([^%s%-]+)")
		if playerFirst == name then
			if found then return end -- two players with that first name, don't guess
			found = button
		end
	end
	return found
end
WarLegendPvP.FindPlayerInTable = findPlayerInTable

-- "Name" or "Name-Realm" of a player GUID, nil when the client keeps it secret
local function nameFromGUID(GUID)
	if type(GUID) ~= "string" or issecret(GUID) or not GUID:find("^Player%-") then return end
	local ok, _, _, _, _, _, name, realm = pcall(GetPlayerInfoByGUID, GUID)
	if not ok or issecret(name) or issecret(realm) or type(name) ~= "string" or name == "" then return end
	if type(realm) == "string" and realm ~= "" then
		name = name .. "-" .. realm
	end
	return name
end

-- readable name of a unit, nil when it is secret
function WarLegendPvP:GetReadableUnitName(unitID)
	local uName = GetUnitName(unitID, true)
	if uName and not issecret(uName) then return uName end
	local guid = UnitGUID(unitID)
	if guid and not issecret(guid) then
		return nameFromGUID(guid)
	end
end

-- "First Surname", "First-Surname" and "First" are the same player for the name compares
local function normalizeName(name)
	if type(name) ~= "string" or issecret(name) then return end
	return (name:gsub("%-", " "))
end

function WarLegendPvP:IsUserName(name)
	local normalized = normalizeName(name)
	if not normalized then return false end
	if normalized == normalizeName(self.UserDetails.PlayerName) or normalized == normalizeName(self.UserDetails.FirstName) then return true end
	local fullName = self:GetReadableUnitName("player")
	return fullName and normalized == normalizeName(fullName) or false
end

-- WarLegend: my names as normalizeName gives them, for many compares in a row (IsUserName on each of the 40
-- enemies of the scoreboard made 4 gsub and an API call each)
function WarLegendPvP:UserNameSet()
	local set = {}
	local function add(n)
		local k = normalizeName(n)
		if k then set[k] = true end
	end
	add(self.UserDetails.PlayerName)
	add(self.UserDetails.FirstName)
	add(self:GetReadableUnitName("player"))
	return set
end

-- target macro lines for a player name, the forms the client may use for a Forever name
function WarLegendPvP.GetTargetMacro(name)
	local first, rest = name:match("^([^%s%-]+)[%s%-](.+)$")
	if not first then
		return "/cleartarget\n/targetexact " .. name
	end
	return "/cleartarget\n/targetexact " .. first .. " " .. rest ..
		"\n/targetexact [noexists] " .. first .. "-" .. rest ..
		"\n/targetexact [noexists] " .. first
end

-- the name with a space, how /targetexact finds a Forever player
function WarLegendPvP.GetTargetableName(name)
	local first, rest = name:match("^([^%s%-]+)%-(.+)$")
	if first then return first .. " " .. rest end
	return name
end

-- WarLegend: the button of a group unit (player, partyN, raidN) is kept and checked against the button's own unit
-- (a roster change moves the units): the hundreds of unit events a second each did a name lookup
local GROUP_UNIT = { player = true }
for i = 1, 40 do GROUP_UNIT["raid" .. i] = true end
for i = 1, 4 do GROUP_UNIT["party" .. i] = true end
local groupUnitButtons = {}

function WarLegendPvP:GetPlayerbuttonByUnitID(unitID)
	local group = GROUP_UNIT[unitID]
	if group then
		local button = groupUnitButtons[unitID]
		if button and button.unitID == unitID and button:IsShown() then return button end
	end
	local uName = self:GetReadableUnitName(unitID)
	if not uName then return end
	local button = self:GetPlayerbuttonByName(uName)
	if group then groupUnitButtons[unitID] = button end
	return button
end

function WarLegendPvP:GetPlayerbuttonByName(name)
	return findPlayerInTable(self.Enemies.Players, name) or findPlayerInTable(self.Allies.Players, name)
end

function WarLegendPvP:GetPlayerbuttonByGUID(GUID)
	local name = nameFromGUID(GUID)
	if not name then return end
	return self:GetPlayerbuttonByName(name)
end

function WarLegendPvP:HandleTargetChanged(newTarget)
	self:Debug("playerButton target", GetUnitName("target", true))
	if WarLegendPvP.currentTarget then

		WarLegendPvP.currentTarget:UpdateEnemyUnitID("Target", false)

		if self.UserButton then
			self.UserButton:IsNoLongerTarging(WarLegendPvP.currentTarget)
		end
		WarLegendPvP.currentTarget.MyTarget:Hide()
	end

	if newTarget then --i target an existing player
		if self.UserButton then

			newTarget:UpdateEnemyUnitID("Target", "target")

			self.UserButton:IsNowTargeting(newTarget)
		end
		newTarget.MyTarget:Show()
		WarLegendPvP.currentTarget = newTarget


	else
		WarLegendPvP.currentTarget = false
	end
end

function WarLegendPvP:PLAYER_TARGET_CHANGED()
	self:HandleTargetChanged(self:GetPlayerbuttonByUnitID("target"))
end

function WarLegendPvP:HandleFocusChanged(newFocus)

	--self:Debug("playerButton focus", playerButton, GetUnitName("focus", true))
	if WarLegendPvP.currentFocus then

		WarLegendPvP.currentFocus:UpdateEnemyUnitID("Focus", false)

		WarLegendPvP.currentFocus.MyFocus:Hide()
	end
	if newFocus then

		newFocus:UpdateEnemyUnitID("Focus", "focus")

		newFocus.MyFocus:Show()
		WarLegendPvP.currentFocus = newFocus
	else
		WarLegendPvP.currentFocus = false
	end
end

function WarLegendPvP:PLAYER_FOCUS_CHANGED()
	self:HandleFocusChanged(self:GetPlayerbuttonByUnitID("focus"))
end



function WarLegendPvP:UPDATE_MOUSEOVER_UNIT()
	local enemyButton = self.Enemies:GetPlayerbuttonByUnitID("mouseover")
	if enemyButton then --unit is a shown enemy
		enemyButton:UpdateAll("mouseover")
	end
end


function WarLegendPvP:RAID_TARGET_UPDATE()
	for name, playerButton in pairs(self.Allies.Players) do
		playerButton:UpdateRaidTargetIcon()
	end
	for name, playerButton in pairs(self.Enemies.Players) do
		playerButton:UpdateRaidTargetIcon()
	end
end

function WarLegendPvP:UNIT_HEALTH(unitID) --gets health of nameplates, player, target, focus, raid1 to raid40, partymember
	local playerButton = self:GetPlayerbuttonByUnitID(unitID)
	if playerButton then                         --unit is a shown player
		playerButton:UNIT_HEALTH(unitID)
	end
end

WarLegendPvP.UNIT_HEALTH_FREQUENT = WarLegendPvP
	.UNIT_HEALTH --used to be used only in tbc, now its only used in classic and wrath
WarLegendPvP.UNIT_MAXHEALTH = WarLegendPvP.UNIT_HEALTH


function WarLegendPvP:UNIT_POWER_FREQUENT(unitID, powerToken) --gets power of nameplates, player, target, focus, raid1 to raid40, partymember
	local playerButton = self:GetPlayerbuttonByUnitID(unitID)
	if playerButton then                                             --unit is a shown enemy
		playerButton:UNIT_POWER_FREQUENT(unitID, powerToken)
	end
end

WarLegendPvP.UNIT_POWER_UPDATE = WarLegendPvP.UNIT_POWER_FREQUENT
WarLegendPvP.UNIT_MAXPOWER = WarLegendPvP.UNIT_POWER_FREQUENT

-- the power type changed (a druid shifting form...): the bar color and its maximum, then the value
function WarLegendPvP:UNIT_DISPLAYPOWER(unitID)
	local playerButton = self:GetPlayerbuttonByUnitID(unitID)
	if playerButton then
		if playerButton.Power and playerButton.Power.UnitIdUpdate then playerButton.Power:UnitIdUpdate(unitID) end
		playerButton:UNIT_POWER_FREQUENT(unitID)
	end
end

WarLegendPvP.PendingUpdates = {}
function WarLegendPvP:QueueForUpdateAfterCombat(tbl, funcName)
	--dont add the same function twice
	for i = 1, #WarLegendPvP.PendingUpdates do
		local pendingUpdate = WarLegendPvP.PendingUpdates[i]
		if pendingUpdate.tbl == tbl and pendingUpdate.funcName == funcName then return end
	end

	table.insert(self.PendingUpdates, { tbl = tbl, funcName = funcName })
end

function WarLegendPvP:PLAYER_REGEN_ENABLED()
	--Check if there are any outstanding updates that have been hold back due to being in combat
	for i = 1, #self.PendingUpdates do
		local tbl = self.PendingUpdates[i].tbl
		local funcName = self.PendingUpdates[i].funcName
		tbl[funcName](tbl)
	end
	wipe(self.PendingUpdates)
end

function WarLegendPvP:PLAYER_REGEN_DISABLED()
	self:DisableTestOrEditmode()
end

function WarLegendPvP:PlayerDead()
	self.states.userIsAlive = false
end

function WarLegendPvP:PlayerAlive()
	--recheck the targets of groupmembers
	for allyName, allyButton in pairs(self.Allies.Players) do
		allyButton:UpdateTarget()
	end
	self.states.userIsAlive = true
end

function WarLegendPvP:PLAYER_ALIVE()
	if UnitIsGhost("player") then --Releases his ghost to a graveyard.
		self:PlayerDead()
	else                       --alive (revived while not being a ghost)
		self:PlayerAlive()
	end
end

function WarLegendPvP:PLAYER_DEAD()
	self:PlayerDead()
end

function WarLegendPvP:UNIT_TARGET(unitID)
	local playerButton = self:GetPlayerbuttonByUnitID(unitID)


	if playerButton and playerButton ~= self.UserButton then --we use Player_target_changed for the player
		--self:Debug("UNIT_TARGET", unitID, playerButton.PlayerDetails.PlayerName)
		playerButton:UpdateTarget()
	end
end

local function restoreShowRaidFrameCVar()
	if not previousCvarRaidOptionIsShown then return end --we didn't modify it so no need to restore it
	SetCVar("raidOptionIsShown", previousCvarRaidOptionIsShown)
end

local function disableRaidFrames()
	if previousCvarRaidOptionIsShown == nil then
		previousCvarRaidOptionIsShown =  GetCVar("raidOptionIsShown")
	end
	SetCVar("raidOptionIsShown", "0")
end

-- EllesmereUI's raid / party frames ignore that CVar, and their containers carry secure visibility drivers
-- (they show themselves again every 0.2 s): out of combat they are moved under a parent of ours, hidden in
-- battlegrounds and shown again outside. Container names from EllesmereUIRaidFrames (EUI_RaidFrames_Layout.lua,
-- EUI_RaidFrames_Party.lua).
local raidFrameHider
local function eurContainers()
	local list = {}
	if _G.EllesmereUIRaidFrameContainer then list[#list + 1] = _G.EllesmereUIRaidFrameContainer end
	local party = _G.ERFPartyHeader and _G.ERFPartyHeader:GetParent()
	if party and party ~= UIParent then list[#list + 1] = party end
	return list
end

local function setEllesmereRaidFramesHidden(hide)
	if hide then
		if not raidFrameHider then
			raidFrameHider = CreateFrame("Frame", nil, UIParent)
			raidFrameHider:SetAllPoints(UIParent)
		end
		for _, container in ipairs(eurContainers()) do
			if container:GetParent() == UIParent then container:SetParent(raidFrameHider) end
		end
		raidFrameHider:Hide()
	elseif raidFrameHider then
		raidFrameHider:Show()
		for _, container in ipairs(eurContainers()) do
			if container:GetParent() == raidFrameHider then container:SetParent(UIParent) end
		end
	end
end

function WarLegendPvP:ToggleRaidFrames()
	local hide = WarLegendPvP.states.real.isInBattleground and self.db.profile.DisableRaidFramesInBattleground
	if InCombatLockdown() then
		-- moving secure frames is refused in combat: done when it ends
		return self:QueueForUpdateAfterCombat(self, "ToggleRaidFrames")
	end
	setEllesmereRaidFramesHidden(hide and true or false)
	if hide then return disableRaidFrames() end

	restoreShowRaidFrameCVar()
end



WarLegendPvP.PLAYER_UNGHOST = WarLegendPvP.PlayerAlive --player is alive again


function WarLegendPvP:GetBuffsAndDebuffsForMap(mapId)
	if not mapId then return end
	return Data.BattlegroundspezificBuffs[mapId], Data.BattlegroundspezificDebuffs[mapId]
end


function WarLegendPvP:UpdateMapID(retries)
	retries = retries or 0
	--	SetMapToCurrentZone() apparently removed in 8.0
	local mapId = GetBestMapForUnit('player')
	self:Debug("UpdateMapID")

	if mapId and mapId ~= -1 and mapId ~= 0 then -- when this values occur the map ID is not real
		self.states.real.currentMapId = mapId
	else
		self.states.real.currentMapId = false
		if retries > 5 then return end
		C_Timer.After(2, function() --Delay this check, since its happening sometimes that this data is not ready yet
			self:UpdateMapID(retries + 1)
		end)
	end
end

local function parseBattlefieldScore(index)
	WarLegendPvP:Debug("parseBattlefieldScore", index)
	local result
	if C_PvP and C_PvP.GetScoreInfo then
		local scoreInfo = C_PvP.GetScoreInfo(index)

		--[[
		info
			PVPScoreInfo?
			Key	Type	Description
			name	string
			guid	string
			killingBlows	number
			honorableKills	number
			deaths	number
			honorGained	number
			faction	number
			raceName	string
			className	string
			classToken	string
			damageDone	number
			healingDone	number
			rating	number
			ratingChange	number
			prematchMMR	number
			mmrChange	number
			talentSpec	string
			honorLevel	number
			roleAssigned	number
			stats	PVPStatInfo[]


			PVPStatInfo
			Key	Type	Description
			pvpStatID	number
			pvpStatValue	number
			orderIndex	number
			name	string
			tooltip	string
			iconName	string

 		]]
		if not scoreInfo then return end
		if type(scoreInfo) ~= "table" then return end
		result = scoreInfo
	else
		local _, name, faction, race, classToken, specName
		if HasSpeccs then
			WarLegendPvP:Debug("HasSpeccs")
			--name, killingBlows, honorableKills, deaths, honorGained, faction, rank, race, class, classToken, damageDone, healingDone = GetBattlefieldScore(index)
			name, _, _, _, _, faction, race, _, classToken, _, _, _, _, _, _, specName = GetBattlefieldScore(index)
		else
			name, _, _, _, _, faction, _, race, _, classToken = GetBattlefieldScore(index)
		end
		result = {
			name = name,
			faction = faction,
			raceName = race,
			classToken = classToken,
			talentSpec = specName
		}
	end
	return result
end

function WarLegendPvP:SetAllyFaction(allyFaction)
	self:Debug("SetAllyFaction", allyFaction)
	self.EnemyFaction = allyFaction == 0 and 1 or 0
	self.AllyFaction = allyFaction
end



-- a scoreboard value to compare (UPDATE_BATTLEFIELD_SCORE), "?" for a secret one, "" for none
local function plainValue(v)
	if issecret(v) then return "?" end
	if v == nil then return "" end
	return v
end
-- WarLegend: the values of this scoreboard and of the last one, two arrays swapped (no text made every 2 s)
local scoreFields, lastScoreFields = {}, {}

function WarLegendPvP:UPDATE_BATTLEFIELD_SCORE()
	self:Debug("UPDATE_BATTLEFIELD_SCORE")
	-- self:Debug(GetCurrentMapAreaID())
	-- self:Debug("UPDATE_BATTLEFIELD_SCORE")
	-- self:Debug("GetBattlefieldArenaFaction", GetBattlefieldArenaFaction())
	-- self:Debug("C_PvP.IsInBrawl", C_PvP.IsInBrawl())
	-- self:Debug("GetCurrentMapAreaID", GetCurrentMapAreaID())
	-- self:Debug("horde players:", GetBattlefieldTeamInfo(0))
	-- self:Debug("alliance players:", GetBattlefieldTeamInfo(1))

	--self:Debug("IsRatedBG", IsRatedBG)

	self:SetAllyFaction(self.AllyFaction or 0) --set fallback value

	local _, _, _, _, numEnemies = GetBattlefieldTeamInfo(self.EnemyFaction)
	local _, _, _, _, numAllies = GetBattlefieldTeamInfo(self.AllyFaction)

	self:Debug("numEnemies:", numEnemies)
	self:Debug("numAllies:", numAllies)

	if numEnemies then
		self.Enemies:SetRealPlayerCount(numEnemies)
	end

	if numAllies then
		self.Allies:SetRealPlayerCount(numAllies)
	end

	local battlefieldScores = {}
	local numScores = GetNumBattlefieldScores()
	self:Debug("numScores", numScores)
	for i = 1, numScores do
		local score = parseBattlefieldScore(i)
		if score then
			table.insert(battlefieldScores, score)
		end
	end

	self:Debug("battlefieldScores", battlefieldScores)

	--see if our faciton in BG changed
	local myNames -- WarLegend: read once, for the first enemy entry
	for i = 1, #battlefieldScores do
		local score = battlefieldScores[i]
		local name = score.name
		local faction = score.faction

		if faction == self.EnemyFaction then -- the cheap test first (80 entries every 2 s)
			myNames = myNames or self:UserNameSet()
			local normalized = normalizeName(name)
			if normalized and myNames[normalized] then self:SetAllyFaction(self.EnemyFaction) end
		end
	end

	-- WarLegend: the scoreboard is asked for every 2 s; when it holds the same players as the last time (name, side,
	-- class, race, spec) the frames are not built again from it. Compared value by value with the last one (it was a
	-- text of 4 KB made each time); self.lastScoreboard is its count, nil = build again. A secret value is never
	-- compared: "?" in its place.
	local fields, n = scoreFields, 0
	for i = 1, #battlefieldScores do
		local score = battlefieldScores[i]
		fields[n + 1], fields[n + 2], fields[n + 3] = plainValue(score.name), plainValue(score.faction), plainValue(score.classToken)
		fields[n + 4], fields[n + 5] = plainValue(score.raceName), plainValue(score.talentSpec)
		n = n + 5
	end
	n = n + 1
	fields[n] = plainValue(self.EnemyFaction)
	local same = self.lastScoreboard == n
	if same then
		for i = 1, n do
			if fields[i] ~= lastScoreFields[i] then same = false; break end
		end
	end
	if same then return end
	scoreFields, lastScoreFields = lastScoreFields, fields
	self.lastScoreboard = n

	WarLegendPvP.Enemies:BeforePlayerSourceUpdate(self.consts.PlayerSources.Scoreboard)
	WarLegendPvP.Allies:BeforePlayerSourceUpdate(self.consts.PlayerSources.Scoreboard)

	for i = 1, #battlefieldScores do
		local score = battlefieldScores[i]

		local faction = score.faction
		local name = score.name
		local classToken = score.classToken

		local t
		if faction and name and classToken then
			if faction == self.EnemyFaction then
				t = WarLegendPvP.Enemies
			else
				t = WarLegendPvP.Allies
			end
			t:AddPlayerToSource(self.consts.PlayerSources.Scoreboard, score)
		end
	end
	WarLegendPvP.Enemies:AfterPlayerSourceUpdate()
	WarLegendPvP.Allies:AfterPlayerSourceUpdate()
end



local rosterReadAt, rosterAgain = 0, false
-- force: read now (the direct calls of PLAYER_ENTERING_WORLD in a battleground and EnableTestMode; the events have no payload)
function WarLegendPvP:GROUP_ROSTER_UPDATE(force)
	if not force then
		-- WarLegend: outside a battleground and the test mode the frames are hidden: the roster is not read at each
		-- event (about 10 ms each in the bench with a raid of 40, several a second while a raid forms)
		if not (self.states.real.isInBattleground or self.states.testmodeActive) then return end
		-- the events come in bursts (3 or more for a player joining): read at once, then once more 0.2 s later at most
		local now = GetTime()
		if now - rosterReadAt < 0.2 then
			if not rosterAgain then
				rosterAgain = true
				C_Timer.After(0.2 - (now - rosterReadAt), function()
					rosterAgain, rosterReadAt = false, 0
					self:GROUP_ROSTER_UPDATE()
				end)
			end
			return
		end
	end
	rosterReadAt = GetTime()
	self.Allies:BeforePlayerSourceUpdate(self.consts.PlayerSources.GroupMembers)
	self.Allies.groupLeader = nil
	self.Allies.assistants = {}

	--IsInGroup returns true when user is in a Raid and In a 5 man group


	-- GetRaidRosterInfo also works when in a party (not raid) but i am not 100% sure how the party unitID maps to the index in GetRaidRosterInfo()

	local numGroupMembers = GetNumGroupMembers()
	self.Allies:SetRealPlayerCount(numGroupMembers)

	if IsInRaid() then
		for i = 1, numGroupMembers do -- the player itself only shows up here when he is in a raid
			local name, rank, subgroup, level, localizedClass, classToken, zone, online, isDead, role, isML, combatRole =
				GetRaidRosterInfo(i)

			-- WoW Forever: the roster name of the player can differ from UnitName("player"), compare the units
			-- UnitIsUnit can answer a secret boolean or nothing under the identity restriction
			-- (EllesmereUI_Colors.lua), then fall back on the name
			local isMe = UnitIsUnit("raid" .. i, "player")
			if issecret(isMe) or isMe == nil then isMe = self:IsUserName(name) end
			if name and not issecret(name) and not isMe and rank and classToken then
				self.Allies:AddGroupMember(name, rank == 2, rank == 1, classToken, "raid" .. i)
			end
		end
	else
		-- we are in a party, 5 man group
		for i = 1, numGroupMembers do
			local unitID = "party" .. i
			local name = self:GetReadableUnitName(unitID)

			local classToken = select(2, UnitClass(unitID))

			if name and classToken and not issecret(classToken) then
				self.Allies:AddGroupMember(name, UnitIsGroupLeader(unitID), UnitIsGroupAssistant(unitID), classToken,
					unitID)
			end
		end
	end

	self.UserDetails.isGroupLeader = UnitIsGroupLeader("player")
	self.UserDetails.isGroupAssistant = UnitIsGroupAssistant("player")
	self.Allies:AddGroupMember(self.UserDetails.PlayerName, self.UserDetails.isGroupLeader,
		self.UserDetails.isGroupAssistant, self.UserDetails.PlayerClass, "player")
	self.Allies:AfterPlayerSourceUpdate()
	self.Allies:UpdateAllUnitIDs()
end

WarLegendPvP.PARTY_LEADER_CHANGED = WarLegendPvP.GROUP_ROSTER_UPDATE




--Fires when the player logs in, /reloads the UI or zones between map instances. Basically whenever the loading screen appears.
function WarLegendPvP:PLAYER_ENTERING_WORLD()
	self:Debug("PLAYER_ENTERING_WORLD")
	self:DisableTestOrEditmode()


	self.Enemies:RemoveAllPlayersFromAllSources()
	self.Allies:RemoveAllPlayersFromSource(self.consts.PlayerSources.Scoreboard)
	self.lastScoreboard = nil -- the next scoreboard builds the frames again
	local _, zone = IsInInstance()
	self:Debug("zone", zone)
	if zone == "pvp" then
		local faction = GetBattlefieldArenaFaction and GetBattlefieldArenaFaction() -- the player's faction in this battleground, 0 for horde, 1 for alliance
		if faction and not issecret(faction) then
			self:SetAllyFaction(faction)
		else
			self:SetAllyFaction(WarLegendPvP.UserFaction == "Alliance" and 1 or 0) -- corrected later from the scoreboard
		end

		WarLegendPvP.states.real.isInBattleground = true
		self:GROUP_ROSTER_UPDATE(true) -- not read outside a battleground: read it now

		C_Timer.After(5,
			function()        --Delay this check, since its happening sometimes that this data is not ready yet
				local isRated = C_PvP and C_PvP.IsRatedBattleground and C_PvP.IsRatedBattleground()
				local isSoloRBG = C_PvP and C_PvP.IsSoloRBG and C_PvP.IsSoloRBG()
				self.states.real.isRatedBG = not issecret(isRated) and isRated == true
				self.states.real.isSoloRBG = not issecret(isSoloRBG) and isSoloRBG == true

				self:UPDATE_BATTLEFIELD_SCORE() --trigger the function again because since 10.0.0 UPDATE_BATTLEFIELD_SCORE doesnt fire reguralry anymore and RequestBattlefieldScore doesnt trigger the event
			end)
	else
		self.states.real.isInBattleground = false
		self.states.real.isSoloRBG = false
		self.states.real.isRatedBG = false
	end

	self:CheckEnableState()
	self:UpdateMapID()
	self:ToggleRaidFrames()
	self:ResetFlagCarriers()
end
