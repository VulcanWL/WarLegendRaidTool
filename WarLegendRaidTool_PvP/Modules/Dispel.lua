
---@class WarLegendPvP
local WarLegendPvP = WarLegendPvP
---@type string
local AddonName = ...
---@class Data
local Data = select(2, ...)

-- WarLegend: on the ally frames, what I can do for each player with my class.
--  * a debuff I can dispel: the frame border takes the dispel type color, and the debuff icon is shown
--    (filter "HARMFUL|RAID" = debuffs the player can remove; checked again with my class when readable)
--  * the buffs of my class (Fortitude, Mark of the Wild, Arcane Intellect, Blessings...): the icon is shown
--    when the player has it, greyed when it is missing (only for the long buffs, and Intellect / Spirit
--    only on mana users)
-- WoW Forever can keep auras secret in a battleground: an aura the client refuses is never read nor shown,
-- and a missing buff is only shown when every buff of the player was readable.

local W = WLRT
W.AddFR({
	["Dispels and my buffs (allies)"] = "Dissipations et mes buffs (alliés)",
})

local CreateFrame = CreateFrame
local GetTime = GetTime

local defaultSettings = {
	Enabled = true,
	Parent = "Button",
	UseButtonHeightAsHeight = true,
	Width = 1,
	ActivePoints = 1,
	Points = {
		{
			Point = "LEFT",
			RelativeFrame = "Button",
			RelativePoint = "RIGHT",
			OffsetX = 2
		}
	}
}

local dispel = WarLegendPvP:NewButtonModule({
	moduleName = "Dispel",
	localizedModuleName = W.L("Dispels and my buffs (allies)"),
	defaultSettings = defaultSettings,
	events = { "UnitIdUpdate", "PlayerButtonSizeChanged", "OnTestmodeEnabled", "OnTestmodeDisabled", "OnTestmodeTick" },
	enabledInThisExpansion = true,
	attachSettingsToButton = true
})

---------------------------------------------------------------------------
-- My class
---------------------------------------------------------------------------
-- dispel types each class removes (Classic spells; a warlock needs his Felhunter, the filter knows it)
local CLASS_DISPELS = {
	PRIEST = { Magic = true, Disease = true },
	PALADIN = { Magic = true, Poison = true, Disease = true },
	DRUID = { Curse = true, Poison = true },
	MAGE = { Curse = true },
	SHAMAN = { Poison = true, Disease = true },
	WARLOCK = { Magic = true },
}

-- buffs each class gives: spell IDs of one buff family (single and group versions), missing = show it greyed
-- when the player does not have it, mana = only on mana users
local CLASS_BUFFS = {
	PRIEST = {
		{ ids = { 1243, 21562 }, missing = true },               -- Power Word / Prayer of Fortitude
		{ ids = { 14752, 27681 }, missing = true, mana = true }, -- Divine Spirit / Prayer of Spirit
		{ ids = { 976, 27683 } },                                -- Shadow Protection / Prayer of Shadow Protection
		{ ids = { 6346 } },                                      -- Fear Ward
	},
	MAGE = {
		{ ids = { 1459, 23028 }, missing = true, mana = true },  -- Arcane Intellect / Arcane Brilliance
	},
	DRUID = {
		{ ids = { 1126, 21849 }, missing = true },               -- Mark / Gift of the Wild
		{ ids = { 467 } },                                       -- Thorns
	},
	PALADIN = {
		{ ids = { 19740, 25782 } }, -- Blessing of Might / Greater
		{ ids = { 19742, 25894 } }, -- Wisdom
		{ ids = { 20217, 25898 } }, -- Kings
		{ ids = { 1038, 25895 } },  -- Salvation
		{ ids = { 19977, 25890 } }, -- Light
		-- no Sanctuary: the talent is removed in WoW: Forever (Paladin class deep dive, Oct 2026)
	},
}

-- click to dispel (like Decursive): mouse button 2 (right) = first list, 3 (middle) = second list; the first
-- spell I know of each list (highest version first)
local CLASS_DISPEL_SPELLS = {
	PRIEST = { [2] = { 527 }, [3] = { 552, 528 } },          -- Dispel Magic / Abolish, Cure Disease
	PALADIN = { [2] = { 4987, 1152 }, [3] = { 1152 } },      -- Cleanse (or Purify) / Purify
	DRUID = { [2] = { 2782 }, [3] = { 2893, 8946 } },        -- Remove Curse / Abolish, Cure Poison
	MAGE = { [2] = { 475 } },                                -- Remove Lesser Curse
	SHAMAN = { [2] = { 526 }, [3] = { 2870 } },              -- Cure Poison / Cure Disease
}

local DISPEL_COLOR = {
	Magic = { 0.2, 0.6, 1 },
	Curse = { 0.6, 0, 1 },
	Disease = { 0.6, 0.4, 0 },
	Poison = { 0, 0.6, 0 },
	Unknown = { 1, 0.5, 0 }, -- dispellable, but its type is kept secret
}

local function SpellIcon(id)
	if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
	return GetSpellTexture and GetSpellTexture(id)
end

local function Knows(id)
	if IsPlayerSpell then return IsPlayerSpell(id) end
	if IsSpellKnown then return IsSpellKnown(id) end
	return true
end

-- my buff families, built once: { names = { [name] = true }, icon, missing, mana }
local myBuffs, myDispels
local function MyClass()
	if myBuffs then return myBuffs, myDispels end
	local class = W.UnitClassToken("player")
	myDispels = CLASS_DISPELS[class] or {}
	myBuffs = {}
	for _, fam in ipairs(CLASS_BUFFS[class] or {}) do
		local names, known = {}, false
		for _, id in ipairs(fam.ids) do
			local n = W.SpellName(id)
			if n then names[n] = true end
			if Knows(id) then known = true end
		end
		local icon = SpellIcon(fam.ids[1])
		if known and icon and next(names) then
			myBuffs[#myBuffs + 1] = { names = names, icon = icon, missing = fam.missing, mana = fam.mana }
		end
	end
	return myBuffs, myDispels
end

-- name of the dispel spell for a mouse button (2 right, 3 middle), nil when I have none
function WarLegendPvP.GetDispelSpell(mouseButton)
	local list = (CLASS_DISPEL_SPELLS[W.UnitClassToken("player")] or {})[mouseButton]
	for _, id in ipairs(list or {}) do
		if Knows(id) then
			local name = W.SpellName(id)
			if name then return name end
		end
	end
end

-- a spell learned (low level battleground brackets) or a respec: my buffs / dispels are read again, and the
-- dispel clicks of the ally buttons follow (SetBindings waits for the end of a fight by itself)
local spellsChanged, rebindPending = CreateFrame("Frame"), false
spellsChanged:RegisterEvent("SPELLS_CHANGED")
spellsChanged:SetScript("OnEvent", function()
	myBuffs, myDispels = nil, nil
	if rebindPending or not (C_Timer and C_Timer.After) then return end
	rebindPending = true
	C_Timer.After(1, function() -- SPELLS_CHANGED comes in bursts: once is enough
		rebindPending = false
		local allies = WarLegendPvP.Allies and WarLegendPvP.Allies.Players
		for _, playerButton in pairs(allies or {}) do
			if playerButton.SetBindings then playerButton:SetBindings() end
		end
	end)
end)

---------------------------------------------------------------------------
-- Reading one unit (secret-safe: W.AuraByIndex gives false for an aura the client refuses)
---------------------------------------------------------------------------
local MAX_DEBUFFS = 4

-- missingOnly: the client's aura container already shows the debuffs and my buffs, only the missing ones
local function ReadUnit(unit, missingOnly)
	local buffs, dispels = MyClass()
	-- an aura the client keeps secret is skipped (never shown as "?"); a run of secret ones stops the scan
	local debuffs, border, secretRun = {}, nil, 0
	for i = 1, missingOnly and 0 or 40 do
		local a = W.AuraByIndex(unit, i, "HARMFUL|RAID")
		if a == nil then break end
		if a == false then
			secretRun = secretRun + 1
			if secretRun >= 8 then break end
		else
			secretRun = 0
			local icon, dtype = W.Safe(a.icon), W.Safe(a.dispelName)
			if icon and (not dtype or dispels[dtype]) then -- type unreadable: the filter said I can remove it
				local color = DISPEL_COLOR[dtype or "Unknown"] or DISPEL_COLOR.Unknown
				border = border or color
				if #debuffs < MAX_DEBUFFS then debuffs[#debuffs + 1] = { icon = icon, color = color, dtype = dtype } end
			end
		end
	end
	local have, allReadable = {}, true
	if #buffs > 0 then
		secretRun = 0
		for i = 1, 40 do
			local a = W.AuraByIndex(unit, i, "HELPFUL")
			if a == nil then break end
			local name = a and W.Safe(a.name)
			if not name then
				allReadable = false
				secretRun = secretRun + 1
				if secretRun >= 8 then break end
			else
				secretRun = 0
				for f, fam in ipairs(buffs) do
					if fam.names[name] then have[f] = true end
				end
			end
		end
	end
	local power = W.Safe(UnitPowerType(unit))
	local shown = {}
	for f, fam in ipairs(buffs) do
		if have[f] then
			if not missingOnly then shown[#shown + 1] = { icon = fam.icon } end
		elseif fam.missing and allReadable and not (fam.mana and power ~= 0) then
			shown[#shown + 1] = { icon = fam.icon, grey = true }
		end
	end
	return debuffs, shown, border
end

---------------------------------------------------------------------------
-- Frames on each ally button
---------------------------------------------------------------------------
function dispel:AttachToPlayerButton(playerButton)
	local f = CreateFrame("Frame", nil, playerButton)
	f.icons = {}
	playerButton.Dispel = f

	-- the health bar in the dispel color (when the client's aura container is missing, and in test mode):
	-- a texture over the bar's fill, made when first needed (the health bar module may come after this one)
	local tint
	local function Tint()
		if tint then return tint end
		local bar = playerButton.healthBar
		local fill = bar and bar.GetStatusBarTexture and bar:GetStatusBarTexture()
		if not fill then return nil end
		tint = bar:CreateTexture(nil, "ARTWORK", nil, 7)
		tint:SetAllPoints(fill)
		tint:SetTexture(fill:GetTexture())
		tint:Hide()
		return tint
	end

	-- the client's aura containers (secret-safe):
	--  right of the frame: the debuffs I can dispel (icon border + frame border in the dispel type color),
	--  then the other debuffs
	--  left of the frame: the missing buffs of my class (greyed, read by us), then my buffs on the player
	local NA = WarLegendPvP.NativeAuras
	-- icons as high as the bar (a bit less), read when the client makes each icon
	local function IconSize() return math.max(14, math.floor((playerButton:GetHeight() or 22) - 4)) end
	if not playerButton.PlayerIsEnemy and NA and NA.Available() then
		f.native = NA.Create(f, {
			{ key = "dispel", filter = "HARMFUL|RAID_PLAYER_DISPELLABLE", max = MAX_DEBUFFS, sizeFn = IconSize, dispelBorder = true, frameGlow = true },
			{ key = "other", filter = "HARMFUL|!RAID_PLAYER_DISPELLABLE", max = 4, sizeFn = IconSize, dispelBorder = true },
		}, playerButton)
		if f.native then
			f.left = CreateFrame("Frame", nil, playerButton)
			f.left:SetPoint("RIGHT", playerButton, "LEFT", -2, 0)
			f.left:SetSize(1, 18)
			f.leftNative = NA.Create(f.left, {
				{ key = "mine", filter = "HELPFUL|PLAYER", max = 4, sizeFn = IconSize },
			}, nil, true)
			if f.leftNative then
				-- hangs left of the greyed icons (f.left grows with them)
				f.leftNative:ClearAllPoints()
				f.leftNative:SetPoint("RIGHT", f.left, "LEFT", -2, 0)
			end
		end
	end

	local function Icon(i)
		local b = f.icons[i]
		if b then return b end
		b = CreateFrame("Frame", nil, f.left or f, BackdropTemplateMixin and "BackdropTemplate")
		b:SetBackdrop({ edgeFile = "Interface/Buttons/WHITE8X8", edgeSize = 1 })
		b.tex = b:CreateTexture(nil, "ARTWORK")
		b.tex:SetPoint("TOPLEFT", 1, -1)
		b.tex:SetPoint("BOTTOMRIGHT", -1, 1)
		b.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		f.icons[i] = b
		return b
	end

	-- the dispel type symbols inside the health bar, as Blizzard's party frames (when the client's aura
	-- container is missing, and in test mode; the container draws its own, NativeAuras.lua)
	local typeIcons = {}
	local function TypeIcons(debuffs)
		local bar = playerButton.healthBar
		if not bar then return end
		local size = math.max(12, math.floor((bar:GetHeight() or 20) * 0.85)) -- big enough to be seen at a glance
		local n = 0
		for _, d in ipairs(debuffs) do
			if d.dtype and n < MAX_DEBUFFS then
				n = n + 1
				local t = typeIcons[n]
				if not t then
					t = bar:CreateTexture(nil, "OVERLAY", nil, 7)
					typeIcons[n] = t
					NA.RegisterTypeIcon(playerButton, t) -- placed before / after the name (NativeAuras.lua)
				end
				t:SetSize(size, size)
				t:SetAtlas("RaidFrame-Icon-Debuff" .. d.dtype)
				t:Show()
			end
		end
		for i = n + 1, #typeIcons do typeIcons[i]:Hide() end
		NA.LayoutTypeIcons(playerButton)
	end

	-- debuffs on the right of the frame; buffs on the left when f.left exists (aura containers), else after the debuffs
	function f:Show_(debuffs, buffs, border)
		local size = math.max(10, (playerButton:GetHeight() or 20) - 4)
		local n, nl, nr = 0, 0, 0
		local function put(e, r, g, b, grey, left)
			n = n + 1
			local ic = Icon(n)
			local s = grey and math.floor(size * 0.75) or size -- missing buffs: smaller
			ic:SetSize(s, s)
			ic:ClearAllPoints()
			if left then -- grows to the left of the frame
				ic:SetParent(f.left)
				ic:SetPoint("RIGHT", f.left, "RIGHT", -nl * (size + 2), 0)
				nl = nl + 1
			else
				ic:SetParent(f)
				ic:SetPoint("LEFT", f, "LEFT", nr * (size + 2), 0)
				nr = nr + 1
			end
			ic.tex:SetTexture(e.icon)
			ic.tex:SetDesaturated(grey and true or false)
			ic:SetAlpha(grey and 0.4 or 1)
			ic:SetBackdropBorderColor(r, g, b, 1)
			ic:Show()
		end
		for _, d in ipairs(debuffs) do put(d, d.color[1], d.color[2], d.color[3]) end
		for _, b in ipairs(buffs) do put(b, 0, 0, 0, b.grey, f.left ~= nil) end
		for i = n + 1, #f.icons do f.icons[i]:Hide() end
		self:SetWidth(f.native and 8 * 20 or math.max(1, nr * (size + 2)))
		if f.left then f.left:SetWidth(math.max(1, nl * (size + 2))) end
		TypeIcons(debuffs)
		local t = border and Tint() or tint
		if t then
			if border then
				t:SetVertexColor(border[1], border[2], border[3], 1)
				t:Show()
			else
				t:Hide()
			end
		end
	end

	function f:Clear()
		f.lastSig = nil
		for i = 1, #f.icons do f.icons[i]:Hide() end
		if tint then tint:Hide() end
		for i = 1, #typeIcons do typeIcons[i]:Hide() end
		if f.native then NA.SetUnit(f.native, nil) end
		if f.leftNative then NA.SetUnit(f.leftNative, nil) end
	end

	-- right of the class icon when it sits on the right of the frame (ally default), else against the bar
	function f:Anchor()
		local icon = playerButton.SpecClassPriorityOne
		local target, x = playerButton, 2
		if icon and icon.Enabled ~= false and icon:IsShown() and (icon:GetWidth() or 0) > 1 then
			local iconLeft, barRight = icon:GetLeft(), playerButton:GetRight()
			if iconLeft and barRight and iconLeft >= barRight - 2 then target = icon end
		end
		if self.anchorTarget == target then return end -- WarLegend: re-anchor only when it changes
		self.anchorTarget = target
		self:ClearAllPoints()
		self:SetPoint("LEFT", target, "RIGHT", x, 0)
	end

	-- WarLegend: what Show_ would draw; Update redraws only when it changes (it runs every 0.2 s per ally in combat)
	local function Signature(debuffs, buffs, border)
		local parts = { playerButton:GetHeight() or 0, border and border[1] or "-" }
		for _, d in ipairs(debuffs) do parts[#parts + 1] = tostring(d.icon) .. (d.dtype or "") end
		parts[#parts + 1] = "|"
		for _, b in ipairs(buffs) do parts[#parts + 1] = tostring(b.icon) .. (b.grey and "g" or "") end
		return table.concat(parts, ",")
	end
	function f:Draw(debuffs, buffs, border)
		local sig = Signature(debuffs, buffs, border)
		if sig == self.lastSig then return end
		self.lastSig = sig
		self:Show_(debuffs, buffs, border)
	end

	function f:Update()
		self.pending = false
		if not self.Enabled or playerButton.PlayerIsEnemy then return end
		self:Anchor()
		if self.testmode then return end
		local unit = playerButton:GetUnitID()
		if not unit or not UnitExists(unit) then return self:Clear() end
		if f.native then
			if f.nativeUnit ~= unit or not f.native:IsShown() then
				f.nativeUnit = unit
				NA.SetUnit(f.native, unit)
				if f.leftNative then NA.SetUnit(f.leftNative, unit) end
			end
			local ok, _, missing = pcall(ReadUnit, unit, true)
			self:Draw({}, ok and missing or {}, nil)
			return
		end
		local ok, debuffs, buffs, border = pcall(ReadUnit, unit)
		if not ok then return self:Clear() end
		self:Draw(debuffs, buffs, border)
	end

	-- UNIT_AURA can fire many times in a row: one read per button every 0.2 s at most
	function f:Schedule()
		if self.pending then return end
		self.pending = true
		C_Timer.After(0.2, self.runUpdate)
	end
	f.runUpdate = function() f:Update() end -- made once per button, not on every schedule

	function f:UnitIdUpdate() self:Schedule() end
	function f:PlayerButtonSizeChanged() self.anchorTarget = nil; self:Schedule() end

	function f:OnTestmodeEnabled()
		self.testmode = true
		if f.native then NA.SetUnit(f.native, nil); f.nativeUnit = nil end
		if f.leftNative then NA.SetUnit(f.leftNative, nil) end
	end
	function f:OnTestmodeDisabled() self.testmode = false; self:Clear(); f.nativeUnit = nil end
	function f:OnTestmodeTick()
		self.testmode = true
		self.lastSig = nil
		if playerButton.PlayerIsEnemy then return end
		self:Anchor()
		local buffs = MyClass()
		local shown = {}
		for _, fam in ipairs(buffs) do shown[#shown + 1] = { icon = fam.icon, grey = math.random(1, 2) == 1 } end
		if math.random(1, 3) == 1 then
			local types = { "Magic", "Curse", "Disease", "Poison" }
			local dtype = types[math.random(1, 4)]
			local c = DISPEL_COLOR[dtype]
			self:Show_({ { icon = 136118, color = c, dtype = dtype } }, shown, c)
		else
			self:Show_({}, shown, nil)
		end
	end

	function f:Disable() self:Clear() end

	function f:ApplyAllSettings()
		if not self.config then return end
		if playerButton.PlayerIsEnemy then self:Clear(); return end
		self.lastSig, self.anchorTarget = nil, nil
		self:Schedule()
	end

	return f
end

-- one listener for every ally button, registered only while the frames are enabled (in a battleground):
-- UNIT_AURA fires for every unit, hundreds of times a second in a raid, and once this addon has been loaded
-- (a battleground, the PvP tab, a profile export) it stays in memory for the rest of the session
local GROUP_UNITS = { player = true } -- the units the patterns matched, as one table lookup
for i = 1, 40 do GROUP_UNITS["raid" .. i] = true end
for i = 1, 4 do GROUP_UNITS["party" .. i] = true end
local auraFrame = CreateFrame("Frame")
auraFrame:SetScript("OnEvent", function(_, _, unit)
	-- cheapest test first: outside a battleground nothing else runs
	if not WarLegendPvP.states or not WarLegendPvP.states.real or not WarLegendPvP.states.real.isInBattleground then return end
	if not GROUP_UNITS[unit] then return end
	local ok, btn = pcall(WarLegendPvP.GetPlayerbuttonByUnitID, WarLegendPvP, unit)
	if ok and btn and not btn.PlayerIsEnemy and btn.Dispel and btn.Dispel.Enabled then btn.Dispel:Schedule() end
end)
if hooksecurefunc and WarLegendPvP.Enable and WarLegendPvP.Disable then
	hooksecurefunc(WarLegendPvP, "Enable", function() auraFrame:RegisterEvent("UNIT_AURA") end)
	hooksecurefunc(WarLegendPvP, "Disable", function() auraFrame:UnregisterEvent("UNIT_AURA") end)
else
	auraFrame:RegisterEvent("UNIT_AURA")
end
