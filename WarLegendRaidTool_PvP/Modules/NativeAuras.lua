
---@class WarLegendPvP
local WarLegendPvP = WarLegendPvP

-- WarLegend: Blizzard's aura container (CreateFrame("AuraContainer"), WoW Forever / 12.1 aura system, as used by
-- BetterBlizzFrames and MiniAuras for Forever). The client itself finds, filters ("HARMFUL|RAID_PLAYER_DISPELLABLE",
-- "HARMFUL|CROWD_CONTROL"...), sorts and draws the auras, also those it keeps secret from addons: nothing is read
-- here. NA.Available() is false on a client without it, the modules then use their old way.

local NA = {}
WarLegendPvP.NativeAuras = NA

local available
function NA.Available()
	if available ~= nil then return available end
	available = false
	if AuraContainerSortMethod and AuraContainerSortDirection then
		local ok, test = pcall(CreateFrame, "AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
		if ok and test and test.AddAuraGroup and test.SetUnit then
			available = true
			test:Hide()
		end
	end
	return available
end

local function Try(obj, method, ...)
	if obj and obj[method] then return pcall(obj[method], obj, ...) end
end

-- the dispel type textures: our own flat art (white square / lines) that the client only colors with the
-- dispel type (PreserveAsset, as BetterBlizzFrames' pixel borders); the stretched Blizzard border atlas
-- when the client has no PreserveAsset
local WHITE = [[Interface\Buttons\WHITE8X8]]
local function AddDispelTexture(button, texture, asset)
	local styles = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
	if not (styles and button.AddDispelTypeTexture) then return end
	local own = styles.PreserveAsset ~= nil
	if own then texture:SetTexture(asset or WHITE) end
	pcall(button.AddDispelTypeTexture, button, texture, {
		style = own and styles.PreserveAsset or styles.Border,
		showWhenHarmful = true,
		showWhenHelpful = false,
		showWithoutDispelType = false,
	})
end

-- a flat square behind an icon (1 px shows around it)
local function Square(parent, sublevel, r, g, b)
	local t = parent:CreateTexture(nil, "BACKGROUND", nil, sublevel)
	t:SetAllPoints(parent)
	t:SetTexture(WHITE)
	if r then t:SetVertexColor(r, g, b, 1) end
	return t
end

-- the health bar of the unit frame in the dispel color: a texture over the bar's fill (it follows the health,
-- same bar texture), under the health text. Hidden with the aura button.
-- the dispel type symbol of Blizzard's party / raid frames, inside the unit frame's health bar on its right
-- (one per dispellable debuff, the n-th aura button of the group draws the n-th symbol). The client picks
-- the image by the aura's dispel type (CustomAsset + customDispelAssetMap, as BetterBlizzFrames).
local TYPE_ICONS = {
	Magic = { asset = "RaidFrame-Icon-DebuffMagic" },
	Curse = { asset = "RaidFrame-Icon-DebuffCurse" },
	Disease = { asset = "RaidFrame-Icon-DebuffDisease" },
	Poison = { asset = "RaidFrame-Icon-DebuffPoison" },
}
-- Placement of the dispel type symbols of a unit frame (the container's and the fallback ones of Dispel.lua):
-- BEFORE the name when the name is shown (the name is pushed right by the width of the symbols), AFTER it
-- (the name is cut shorter on its right) when the name box is too narrow to stay readable beside them, and at the
-- right edge of the health bar when there is no name. Redone when the name, the frame or a symbol changes.
local TYPE_GAP, NAME_MIN = 1, 45 -- px between symbols; px of name that must stay readable beside them
local function LayoutTypeIcons(pb)
	local list, bar = pb.WLTypeIcons, pb.healthBar
	if not (list and bar) then return end
	-- the symbols live inside the client's aura container: it may refuse some calls on them ("secret aspects"),
	-- so each one goes through pcall and a refusal just leaves that symbol where it is
	local shown, size = {}, 0
	for _, it in ipairs(list) do
		local ok, visible = pcall(it.IsVisible, it)
		if ok and visible then
			shown[#shown + 1] = it
			local okw, w = pcall(it.GetWidth, it)
			if okw and type(w) == "number" and w > 0 then size = w end
		end
	end
	local n = #shown
	local total = n * (size + TYPE_GAP)
	local name = pb.Name
	local cfg = name and name.config
	local hasName = name and name.Enabled ~= false and cfg and cfg.Points and name:IsShown() and true or false
	local old = pb.WLNameShift or { 0, 0 }
	local sl, sr, mode = 0, 0, "bar"
	if hasName and n > 0 then
		local w = name:GetWidth()
		local textW = name:GetStringWidth() or 0
		mode, sl, sr = "before", total, 0
		-- the box width without my own shift; unknown before the first layout: then the symbols stay first
		if w and w > 0 and (w + old[1] + old[2]) - total < math.min(textW, NAME_MIN) then mode, sl, sr = "after", 0, total end
	end
	-- nothing changed since the last pass: nothing to anchor again
	local sig = mode .. ":" .. n .. ":" .. size .. ":" .. sl .. ":" .. sr
	if pb.WLTypeSig == sig then return end
	pb.WLTypeSig = sig
	-- the name box: its left anchor is pushed right, its right anchor left
	if hasName and (old[1] ~= sl or old[2] ~= sr) then
		pb.WLNameShift = { sl, sr }
		local es = name:GetEffectiveScale()
		for j = 1, cfg.ActivePoints do
			local pc = cfg.Points[j]
			local rel = pc and pc.RelativeFrame and pb:GetAnchor(pc.RelativeFrame)
			if rel and pc.Point then
				local dx = pc.Point:find("LEFT") and sl or (pc.Point:find("RIGHT") and -sr or 0)
				name:SetPoint(pc.Point, rel, pc.RelativePoint, ((pc.OffsetX or 0) + dx) / es, (pc.OffsetY or 0) / es)
			end
		end
	end
	for k, it in ipairs(shown) do
		local step = (k - 1) * (size + TYPE_GAP)
		pcall(function()
			it:ClearAllPoints()
			if mode == "before" then it:SetPoint("LEFT", name, "LEFT", -total + step, 0)
			elseif mode == "after" then it:SetPoint("LEFT", name, "RIGHT", TYPE_GAP + step, 0)
			else it:SetPoint("RIGHT", bar, "RIGHT", -26 - step, 0) end -- left of the target counter
		end)
	end
end
NA.LayoutTypeIcons = LayoutTypeIcons

-- item: a frame or texture placed by LayoutTypeIcons. No script is set on it (the container's frames refuse
-- HookScript): a throttled OnUpdate on a frame of mine, running only while the unit frame is shown, looks again.
function NA.RegisterTypeIcon(pb, item)
	pb.WLTypeIcons = pb.WLTypeIcons or {}
	pb.WLTypeIcons[#pb.WLTypeIcons + 1] = item
	if pb.WLTypeHooked then return end
	pb.WLTypeHooked = true
	local function again() pb.WLTypeSig = nil; LayoutTypeIcons(pb) end
	if hooksecurefunc then
		-- SetModulePositions anchors the name again from its settings: my shift is gone, apply it anew
		pcall(hooksecurefunc, pb, "SetModulePositions", function() pb.WLNameShift = nil; again() end)
		if pb.Name and pb.Name.SetName then pcall(hooksecurefunc, pb.Name, "SetName", again) end
	end
	local ticker, acc = CreateFrame("Frame", nil, pb), 0
	ticker:SetScript("OnUpdate", function(_, elapsed)
		acc = acc + elapsed
		if acc < 0.25 then return end
		acc = 0
		LayoutTypeIcons(pb)
	end)
end

local function TypeIcon(button, unitFrame, slot)
	local styles = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
	local bar = unitFrame.healthBar
	if not (styles and styles.CustomAsset and button.AddDispelTypeTexture and bar) then return end
	local size = math.max(12, math.floor((bar:GetHeight() or 20) * 0.85)) -- big enough to be seen at a glance
	local holder = CreateFrame("Frame", nil, button) -- child of the aura button: hidden with it
	holder:SetSize(size, size)
	holder:SetFrameLevel(bar:GetFrameLevel() + 5)
	NA.RegisterTypeIcon(unitFrame, holder) -- its place depends on the name
	local tex = holder:CreateTexture(nil, "OVERLAY")
	tex:SetAllPoints(holder)
	pcall(button.AddDispelTypeTexture, button, tex, {
		style = styles.CustomAsset,
		showWhenHarmful = true,
		showWhenHelpful = false,
		showWithoutDispelType = false,
		customDispelAssetMap = TYPE_ICONS,
	})
end

local function HealthBarColor(button, unitFrame)
	local bar = unitFrame.healthBar
	local fill = bar and bar.GetStatusBarTexture and bar:GetStatusBarTexture()
	if not fill then return end
	local tint = bar:CreateTexture(nil, "ARTWORK", nil, 7)
	tint:SetAllPoints(fill)
	AddDispelTexture(button, tint, fill:GetTexture())
	pcall(button.HookScript, button, "OnHide", function() tint:Hide() end) -- the container may refuse scripts on its frames
end

local function InitButton(button, group, glowParent)
	local size = (group.sizeFn and group.sizeFn()) or group.size or 20
	button:SetSize(size, size)
	-- black square, then the dispel colored square, the icon 1 px inside: a clean 1 px border
	Square(button, -8, 0, 0, 0)
	if group.dispelBorder then AddDispelTexture(button, Square(button, -7)) end
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT", 1, -1)
	icon:SetPoint("BOTTOMRIGHT", -1, 1)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	Try(button, "SetIcon", icon)
	local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	cooldown:SetPoint("TOPLEFT", 1, -1)
	cooldown:SetPoint("BOTTOMRIGHT", -1, 1)
	cooldown:SetReverse(true)
	cooldown:SetDrawEdge(false)
	cooldown:SetDrawBling(false)
	Try(cooldown, "SetSwipeColor", 0, 0, 0, 0.6)
	cooldown:SetHideCountdownNumbers(not group.timer)
	Try(cooldown, "SetMinimumCountdownDuration", 0)
	Try(cooldown, "SetUsingParentLevel", true)
	Try(button, "SetDurationCooldown", cooldown)
	local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, 0)
	Try(button, "SetApplicationCount", count)
	if group.frameGlow and glowParent then
		HealthBarColor(button, glowParent)
		group.made = (group.made or 0) + 1 -- the client makes the buttons of a group in their display order
		TypeIcon(button, glowParent, group.made)
	end
	if Try(button, "SetMouseMotionEnabled", false) == nil then button:EnableMouse(false) end
end

-- groups: { { key, filter, max, size, timer, dispelBorder, frameGlow }, ... } shown left to right
-- (right to left with growLeft, the container then hangs on the right side of parent)
-- glowParent: the frame a "frameGlow" group colors (the unit frame)
function NA.Create(parent, groups, glowParent, growLeft)
	if not NA.Available() then return nil end
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, parent, "CustomAuraContainerTemplate")
	if not ok or not container then return nil end
	container:SetSize(1, 1)
	local side = growLeft and "RIGHT" or "LEFT"
	container:SetPoint(side, parent, side)
	if AnchorUtil and AnchorUtil.FlowLayoutAxis and AnchorUtil.FlowDirection then
		local dir = growLeft and AnchorUtil.FlowDirection.Left or AnchorUtil.FlowDirection.Right
		Try(container, "SetFlowLayoutAxis", AnchorUtil.FlowLayoutAxis.Horizontal)
		Try(container, "SetFlowLayoutAnchorPoint", side)
		Try(container, "SetFlowLayoutGrowthDirection", dir or AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
		Try(container, "SetFlowLayoutPadding", 0, 0, 0, 0)
	end
	for _, g in ipairs(groups) do
		local added = pcall(container.AddAuraGroup, container, g.key, g.filter, {
			maxFrameCount = 0,
			sortMethod = AuraContainerSortMethod.ExpirationOnly,
			sortDirection = AuraContainerSortDirection.Reverse,
			layout = { elementSpacing = 2, lineSpacing = 2 },
			initializeFrame = function(button) InitButton(button, g, glowParent) end,
		})
		if added then Try(container, "SetAuraGroupMaxFrameCount", g.key, g.max or 4) end
	end
	Try(container, "SetEnabled", false)
	container:Hide()
	return container
end

-- unit nil: hidden
function NA.SetUnit(container, unit)
	if not container then return end
	if unit and UnitExists(unit) then
		Try(container, "SetUnit", unit)
		Try(container, "SetEnabled", true)
		container:Show()
		Try(container, "UpdateAllAuras")
	else
		Try(container, "SetEnabled", false)
		container:Hide()
	end
end
