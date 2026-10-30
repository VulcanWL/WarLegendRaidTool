-- WarLegend RaidTool - DoesItDie: focus frame
-- The damage marker (and the kill icon, as on nameplates) on the focus frame's health bar,
-- for your DoTs on the focused mob. Based on toughnuts99's patch (issue #12).
--
-- Tracking is per mob already (ns.dotBreakdownForUnit) and UNIT_COMBAT reports hits on the focus, so this is only
-- display: it reuses the nameplate widgets (ns.barMarker) in a look of its own (Focus tab, focus* settings, read
-- through a view that maps the widgets' plate* keys to them), drawn on EllesmereUI's focus frame when it shows
-- one, else Blizzard's. The tab's preview has a mock focus frame drawn the same way with its plain numbers
-- (ns.setFocusPreview). Drawn by the driver of DoesItDie.lua (ns.refreshFocus) while something is tracked.
--
-- The widgets hang off a frame of our own rather than the bar's parent: unit frame addons may put the bar in a
-- clipping frame, which would cut off a kill icon beside the bar. So they're hidden by hand whenever there's no
-- focus, the bar isn't visible or there are no DoTs, and pinned so the nameplate refresh leaves them alone.

local W = WLRT
local L = W.L
local ns = W.Space("DoesItDie")

W.AddFR({
    ["%s focus frame"] = "cadre de focalisation de %s",
    ["Blizzard's focus frame"] = "cadre de focalisation de Blizzard",
    ["no focus frame found"] = "aucun cadre de focalisation trouvé",
    ["Focus display error (logged): %s"] = "Erreur d'affichage de la focalisation (dans le journal) : %s",
})

local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r or false
end

-- Blizzard's focus frame is built from the target frame's template, so its bar sits at the same paths.
local function blizzardFocusBar()
    local ff = FocusFrame
    local content = ff and ff.TargetFrameContent
    local main = content and content.TargetFrameContentMain
    return (main and main.HealthBarsContainer and main.HealthBarsContainer.HealthBar)
        or (main and main.HealthBar)
        or FocusFrameHealthBar
        or (ff and ff.healthbar)
end

-- The bar to draw on and its addon's name: EllesmereUI's focus frame, looked up by name at most once a second (it was
-- looked up 10 times a second; it may be built late), else Blizzard's (no name).
local knownBar, knownOwner, knownAt = nil, nil, -math.huge
local function focusBar()
    local now = GetTime()
    if now - knownAt >= 1 then
        knownAt = now
        knownBar, knownOwner = ns.knownFocusFrame()
    end
    if knownBar then return knownBar, knownOwner end
    return blizzardFocusBar()
end

-- What the focus marker is attached to (the tab).
function ns.focusStatus()
    local bar, owner = focusBar()
    if owner then return L("%s focus frame"):format(owner) end
    if bar then return L("Blizzard's focus frame") end
    return "|cffff6666" .. L("no focus frame found") .. "|r"
end

-- The focus look: the nameplate widgets read plate* (and nameplateMode, nameplateIcon*) settings; this view
-- answers those keys with the focus* ones, and everything else (showMarkers) straight from the settings.
local FOCUS_KEYS = {
    nameplateMode = "focusMode", plateIcon = "focusIcon", nameplateIconSize = "focusIconSize",
    nameplateIconPosition = "focusIconPosition", plateIconOffsetX = "focusIconOffsetX",
    plateIconOffsetY = "focusIconOffsetY", plateDotColors = "focusDotColors", plateFillTexture = "focusFillTexture",
    plateFillColor = "focusFillColor", plateFillOpacity = "focusFillOpacity", plateOutlineStyle = "focusOutlineStyle",
    plateDashLength = "focusDashLength", plateOutlineThickness = "focusOutlineThickness",
    plateOutlineColor = "focusOutlineColor", plateOutlineOpacity = "focusOutlineOpacity",
}
local focusLook = setmetatable({}, { __index = function(_, key) return ns.db[FOCUS_KEYS[key] or key] end })
ns.focusKeys = FOCUS_KEYS -- (the Focus sub-tab's "Copy from the Nameplates tab")

local host = CreateFrame("Frame", nil, UIParent)
host:SetAllPoints(UIParent)
local widgets

local function hide()
    if widgets then ns.barMarker.hide(widgets) end
end

-- The tab's mock focus frame: { frame, healthBar } and the preview state ({ health, dots } in % of max
-- health), or nil.
local previewHost, previewState, previewWidgets

function ns.setFocusPreview(mock, state)
    previewHost, previewState = mock, state
    if not mock and previewWidgets then ns.barMarker.hide(previewWidgets) end
end

local function refreshPreview(db)
    if not previewHost or not previewState then return end
    ns.barMarker.pin(previewHost.frame)
    previewWidgets = ns.barMarker.widgetsFor(previewHost.frame, previewHost.healthBar)
    local entries, total = {}, 0
    for _, dot in ipairs(previewState.dots) do
        if dot.damage > 0 then
            table.insert(entries, dot)
            total = total + dot.damage
        end
    end
    if total <= 0 or db.focusMode == "off" then return ns.barMarker.hide(previewWidgets) end
    ns.barMarker.draw(previewWidgets, entries, total, 100, math.max(previewState.health, 0.01), focusLook)
end

local function shown(bar)
    local ok, visible = pcall(bar.IsVisible, bar)
    return not ok or isSecret(visible) or visible ~= false
end

-- Highest strata/level anywhere in the focus frame: the bar's own level isn't enough, since Blizzard's focus frame
-- (like the target frame, see Display.lua) has art layered far above its health bar, and can re-layer it any time.
local STRATA_RANK = {
    BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8,
}
local LAYER_CHECK_INTERVAL = 1
local layerCheckedAt, topStrata, topLevel, layerBar = -math.huge, nil, nil, nil
local appliedStrata, appliedLevel, appliedBar -- what the widgets were put in last (a new bar re-anchors them)

local function topLayer(root)
    local bestStrata, bestLevel = "BACKGROUND", 0
    local function visit(frame, depth)
        -- Some of Blizzard's frames report a secret strata/level; those are skipped (their children aren't).
        local strata, level = frame:GetFrameStrata(), frame:GetFrameLevel()
        if not isSecret(strata) and not isSecret(level) then
            local rank, bestRank = STRATA_RANK[strata] or 0, STRATA_RANK[bestStrata] or 0
            if rank > bestRank then
                bestStrata, bestLevel = strata, level
            elseif rank == bestRank and level > bestLevel then
                bestLevel = level
            end
        end
        if depth < 6 then
            for _, child in ipairs({ frame:GetChildren() }) do visit(child, depth + 1) end
        end
    end
    visit(root, 0)
    return bestStrata, bestLevel
end

-- Keeps the focus widgets above everything on the frame that holds `bar` (checked at most once a second).
local function updateLayering(bar, now)
    if bar ~= layerBar or now - layerCheckedAt >= LAYER_CHECK_INTERVAL then
        layerCheckedAt, layerBar = now, bar
        local root = ns.frameRoot and ns.frameRoot(bar) or bar
        local ok, strata, level = pcall(topLayer, root)
        if ok and (strata ~= topStrata or level ~= topLevel) then
            topStrata, topLevel = strata, level
            ns.trace(string.format("LAYER focus frame top is %s/%d; focus marker placed above it", strata, level))
        end
    end
    -- only on a change (it was set 10 times a second): a strata set also resets the levels
    if topStrata and (topStrata ~= appliedStrata or topLevel ~= appliedLevel or bar ~= appliedBar) then
        appliedStrata, appliedLevel, appliedBar = topStrata, topLevel, bar
        ns.barMarker.layer(widgets, topStrata, topLevel)
    end
end

local function dead()
    local ok, isDead = pcall(UnitIsDead, "focus")
    return ok and not isSecret(isDead) and isDead
end

local function refresh()
    local db = ns.db
    if not db or not ns.barMarker then return end
    refreshPreview(db)
    if db.focusMode == "off" or not UnitExists("focus") or dead() then return hide() end
    local bar = focusBar()
    if not bar or not shown(bar) then return hide() end
    local entries, total = ns.dotBreakdownForUnit("focus")
    if total <= 0 then return hide() end
    ns.barMarker.pin(host)
    widgets = ns.barMarker.widgetsFor(host, bar, false, true)
    updateLayering(bar, GetTime())
    ns.barMarker.draw(widgets, entries, total, UnitHealthMax("focus"), UnitHealth("focus"), focusLook)
end

-- Called 10 times a second by the driver of DoesItDie.lua while something is tracked. An error is reported once.
local reportedError = false
function ns.refreshFocus()
    local ok, err = pcall(refresh)
    if not ok then
        pcall(hide)
        if not reportedError then
            reportedError = true
            ns.trace("ERROR in focus update: " .. tostring(err))
            ns.print(L("Focus display error (logged): %s"):format(tostring(err)))
        end
    end
end
