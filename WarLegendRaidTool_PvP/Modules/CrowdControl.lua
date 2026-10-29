
---@class WarLegendPvP
local WarLegendPvP = WarLegendPvP

-- WarLegend: the crowd control a player is under (stun, fear, polymorph, silence...), drawn over the class
-- icon with its countdown, like the "big debuffs" of BetterBlizzFrames / MiniAuras. Shown by the client's
-- aura container (filter "HARMFUL|CROWD_CONTROL"): it works on the auras the game keeps secret. Allies always
-- have a unit; an enemy only while he is a nameplate / target / focus.

local W = WLRT
W.AddFR({
	["Crowd control on the class icon"] = "Contrôle (CC) sur l'icône de classe",
})

local defaultSettings = {
	Enabled = true,
	Parent = "Button",
}

local crowdControl = WarLegendPvP:NewButtonModule({
	moduleName = "CrowdControl",
	localizedModuleName = W.L("Crowd control on the class icon"),
	defaultSettings = defaultSettings,
	events = { "UnitIdUpdate", "PlayerButtonSizeChanged", "UnitDied", "UnitRevived", "OnTestmodeEnabled", "OnTestmodeDisabled", "OnTestmodeTick" },
	enabledInThisExpansion = true,
	attachSettingsToButton = true
})

local TEST_ICON = 136071 -- Polymorph

function crowdControl:AttachToPlayerButton(playerButton)
	local f = CreateFrame("Frame", nil, playerButton)
	f:SetFrameLevel(playerButton:GetFrameLevel() + 20)
	playerButton.CrowdControl = f
	local NA = WarLegendPvP.NativeAuras

	if NA and NA.Available() then
		f.native, f.box = NA.Create(f, {
			{ key = "cc", filter = "HARMFUL|CROWD_CONTROL", max = 1, timer = true },
		})
	end

	-- over the class / spec icon, or the left end of the frame
	local function Place()
		f:ClearAllPoints()
		local icon = playerButton.SpecClassPriorityOne
		local size
		if icon and icon:IsShown() and icon:GetWidth() > 1 then
			f:SetAllPoints(icon)
			size = math.min(icon:GetWidth(), icon:GetHeight())
		else
			local h = playerButton:GetHeight() or 20
			f:SetPoint("LEFT", playerButton, "LEFT")
			f:SetSize(h, h)
			size = h
		end
		-- WarLegend: the client's icon is made once, at one size (NativeAuras.lua): as high as the icon's place now
		if f.box then NA.SetIconSize(f.box, math.max(12, size)) end
	end

	-- test mode: a fake polymorph on some players
	local test = CreateFrame("Frame", nil, f)
	test:SetAllPoints(f)
	test.icon = test:CreateTexture(nil, "ARTWORK")
	test.icon:SetAllPoints(test)
	test.icon:SetTexture(TEST_ICON)
	test.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	test.cd = CreateFrame("Cooldown", nil, test, "CooldownFrameTemplate")
	test.cd:SetAllPoints(test)
	test.cd:SetReverse(true)
	test:Hide()

	function f:Update()
		if not self.Enabled or self.testmode then return end
		Place()
		if self.native then NA.SetUnit(self.native, playerButton:GetUnitID()) end
	end

	function f:UnitIdUpdate() self:Update() end
	function f:PlayerButtonSizeChanged() self:Update() end
	function f:UnitDied() if self.native then NA.SetUnit(self.native, nil) end end
	function f:UnitRevived() self:Update() end -- back alive: the unit is the same, show its CC again

	function f:OnTestmodeEnabled()
		self.testmode = true
		if self.native then NA.SetUnit(self.native, nil) end
	end
	function f:OnTestmodeDisabled()
		self.testmode = false
		test:Hide()
		self:Update()
	end
	function f:OnTestmodeTick()
		self.testmode = true
		Place()
		if math.random(1, 4) == 1 and not test:IsShown() then
			test.cd:SetCooldown(GetTime(), 8)
			test:Show()
			C_Timer.After(8, function() test:Hide() end)
		end
	end

	function f:Disable()
		test:Hide()
		if self.native then NA.SetUnit(self.native, nil) end
	end

	function f:ApplyAllSettings()
		if not self.config then return end
		self:Update()
	end

	return f
end
