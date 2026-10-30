-- WarLegend RaidTool - DoesItDie: the tab
-- Built in the DoesItDie tab of the window (../DoesItDie.lua: ns.BuildTab). Left: the settings in sub-tabs, written
-- straight to ns.db; a row greys out when a setting above makes it unused. Right: a live preview: the real marker and
-- kill icon are attached to a mock target frame, nameplate and focus frame (ns.setDisplayHost, ns.setPlatePreview,
-- ns.setFocusPreview) and fed plain numbers, so it runs the same drawing code as combat; out of combat only, while
-- the tab is shown. The rows are plain widgets (CheckButton, Slider, a list button with color swatches): the window
-- has no slider or color list of its own.
local W = WLRT
local L = W.L
local ns = W.Space("DoesItDie")

W.AddFR({
    -- sub-tabs, presets, buttons
    ["Kill icon"] = "Icône de mort",
    ["Marker"] = "Marque",
    ["Effects"] = "Effets",
    ["Text"] = "Texte",
    ["Nameplates"] = "Barres de nom",
    ["Focus"] = "Focalisation",
    ["Accuracy"] = "Précision",
    ["Learned ticks"] = "Ticks appris",
    ["Presets"] = "Préréglages",
    ["Minimal"] = "Minimal",
    ["Classic"] = "Classique",
    ["Juicy"] = "Éclatant",
    ["Debug"] = "Débogage",
    ["%s preset applied."] = "Préréglage %s appliqué.",
    ["Reset this tab"] = "Réinitialiser cet onglet",
    ["Copy from the Marker tab"] = "Copier depuis l'onglet Marque",
    ["Copy from the Nameplates tab"] = "Copier depuis l'onglet Barres de nom",
    -- lists (ns.lists)
    ["Purple"] = "Violet", ["Gold"] = "Or", ["White"] = "Blanc", ["Red"] = "Rouge", ["Orange"] = "Orange",
    ["Green"] = "Vert", ["Cyan"] = "Cyan", ["Pink"] = "Rose", ["Black"] = "Noir",
    ["Raid skull"] = "Crâne de raid", ["Red X"] = "X rouge", ["Green checkmark"] = "Coche verte",
    ["Boss skull"] = "Crâne de boss", ["Sunglasses"] = "Lunettes de soleil",
    ["None"] = "Aucun", ["Flat"] = "Uni", ["Health bar texture"] = "Texture de barre de vie",
    ["Raid bar texture"] = "Texture de barre de raid", ["Diagonal stripes"] = "Rayures diagonales",
    ["Fade in from left"] = "Fondu depuis la gauche",
    ["Dashed"] = "Tirets", ["Solid"] = "Plein",
    ["Fine dots (1px)"] = "Points fins (1 px)", ["Dots (2px)"] = "Points (2 px)",
    ["Short dashes (4px)"] = "Tirets courts (4 px)", ["Dashes (8px)"] = "Tirets (8 px)",
    ["Long dashes (16px)"] = "Tirets longs (16 px)",
    ["Left of the bar"] = "À gauche de la barre", ["Centered on the bar"] = "Au centre de la barre",
    ["Inside the bar, right end"] = "Dans la barre, à droite",
    ["One color (fill color)"] = "Une couleur (celle du remplissage)", ["By spell school"] = "Par école de magie",
    ["Different color per DoT"] = "Une couleur par DoT",
    ["Never (estimate straight away)"] = "Jamais (estimation tout de suite)", ["When unsure"] = "En cas de doute",
    ["Always (real ticks only)"] = "Toujours (vrais ticks seulement)",
    ["Off"] = "Rien", ["Marker only"] = "Marque seulement", ["Marker and kill icon"] = "Marque et icône de mort",
    ["Right of the health bar"] = "À droite de la barre de vie", ["Left of the health bar"] = "À gauche de la barre de vie",
    ["Above the health bar"] = "Au-dessus de la barre de vie",
    -- Kill icon
    ["Show icon on portrait"] = "Icône sur le portrait",
    ["Shows an icon over the target's portrait when your DoTs on it will kill it."] =
        "Montre une icône sur le portrait de la cible quand tes DoT vont la tuer.",
    ["Icon"] = "Icône",
    ["Size"] = "Taille",
    ["Pulse"] = "Pulsation",
    ["Gently pulses the icon while it's showing."] = "L'icône pulse doucement tant qu'elle est affichée.",
    ["Horizontal offset"] = "Décalage horizontal",
    ["Pixels right (+) or left (-) of the portrait's center."] =
        "Pixels à droite (+) ou à gauche (-) du centre du portrait.",
    ["Vertical offset"] = "Décalage vertical",
    ["Pixels up (+) or down (-) from the portrait's center."] =
        "Pixels vers le haut (+) ou le bas (-) depuis le centre du portrait.",
    -- Marker
    ["Show damage marker"] = "Marque des dégâts",
    ["Marks the damage your DoTs still have to deal on the target's health bar. If the health ends inside it, the target dies."] =
        "Marque sur la barre de vie de la cible les dégâts que tes DoT doivent encore faire. Si la vie finit dedans, la cible meurt.",
    ["DoT colors"] = "Couleurs des DoT",
    ["One color, or one segment per DoT colored by spell school or with a different color each."] =
        "Une couleur, ou un segment par DoT coloré par école de magie ou d'une couleur différente chacun.",
    ["Fill style"] = "Remplissage",
    ["Fill color"] = "Couleur du remplissage",
    ["Used when DoT colors is set to one color."] = "Utilisée quand les couleurs des DoT sont sur une couleur.",
    ["Fill opacity"] = "Opacité du remplissage",
    ["Dividers between DoTs"] = "Séparations entre les DoT",
    ["Outline"] = "Contour",
    ["Dash length"] = "Longueur des tirets",
    ["Outline thickness"] = "Épaisseur du contour",
    ["Outline color"] = "Couleur du contour",
    ["Outline opacity"] = "Opacité du contour",
    -- Effects
    ["Smooth motion"] = "Mouvement fluide",
    ["The marker grows in when it appears and glides to new values instead of jumping."] =
        "La marque grandit en apparaissant et glisse vers ses nouvelles valeurs au lieu de sauter.",
    ["Flash on new DoT"] = "Flash à chaque nouveau DoT",
    ["Spark"] = "Étincelle",
    ["A bright flare on the marker's edge when a DoT lands."] = "Un éclat lumineux au bord de la marque quand un DoT arrive.",
    ["Pulse outline"] = "Contour qui pulse",
    ["Glow"] = "Halo",
    ["Soft halo in the outline color."] = "Halo doux de la couleur du contour.",
    ["Glow size"] = "Taille du halo",
    ["Shine sweep"] = "Reflet qui passe",
    ["Shine every"] = "Reflet toutes les",
    ["Scroll stripes"] = "Rayures qui défilent",
    ["Animates the diagonal stripes fill."] = "Anime le remplissage en rayures diagonales.",
    -- Text
    ["Show damage text"] = "Texte des dégâts",
    ["Remaining DoT damage next to the health bar (a per-DoT breakdown with DoT colors)."] =
        "Dégâts restants des DoT à côté de la barre de vie (détail par DoT avec les couleurs des DoT).",
    ["Position"] = "Position",
    ["Color"] = "Couleur",
    -- Nameplates, Focus
    ["Show on nameplates"] = "Sur les barres de nom",
    ["Draws a marker (and optionally the kill icon) on every enemy nameplate with your DoTs on it, in its own look below."] =
        "Dessine une marque (et si voulu l'icône de mort) sur chaque barre de nom ennemie qui porte tes DoT, avec son propre style ci-dessous.",
    ["Kill icon size"] = "Taille de l'icône de mort",
    ["Kill icon position"] = "Place de l'icône de mort",
    ["Icon horizontal offset"] = "Décalage horizontal de l'icône",
    ["Pixels right (+) or left (-) of the chosen position."] = "Pixels à droite (+) ou à gauche (-) de la place choisie.",
    ["Icon vertical offset"] = "Décalage vertical de l'icône",
    ["Pixels up (+) or down (-) from the chosen position."] = "Pixels vers le haut (+) ou le bas (-) depuis la place choisie.",
    ["Show on focus frame"] = "Sur le cadre de focalisation",
    ["Draws the marker (and optionally the kill icon) on your focus's health bar, for your DoTs on it, in its own look below. /cast [@focus] macros put the DoT on your focus."] =
        "Dessine la marque (et si voulu l'icône de mort) sur la barre de vie de ta focalisation, pour tes DoT sur elle, avec son propre style ci-dessous. Les macros /cast [@focus] mettent le DoT sur ta focalisation.",
    ["Nameplate bar in use"] = "Dernière barre de nom utilisée",
    ["Focus bar in use"] = "Barre de focalisation utilisée",
    -- Accuracy
    ["Wait for first tick"] = "Attendre le 1er tick",
    ["Whether a new DoT counts before its first tick lands. \"When unsure\" waits for finishers with unknown combo points and spells the addon hasn't seen tick yet."] =
        "Si un nouveau DoT compte avant son premier tick. « En cas de doute » attend pour les coups de grâce aux points de combo inconnus et les sorts que l'addon n'a pas encore vus faire un tick.",
    ["Estimate during casting"] = "Estimation pendant l'incantation",
    ["Shows a DoT with a cast time while you're still casting it. Once the cast lands the normal estimate takes over; an interrupted or failed cast removes it."] =
        "Montre un DoT à temps d'incantation pendant que tu l'incantes encore. Une fois le sort lancé, l'estimation normale prend le relais ; une incantation interrompue ou ratée le retire.",
    ["Echo trace log to chat"] = "Journal de suivi dans le chat",
    ["Prints each DoT cast, matched tick and estimate to chat."] =
        "Écrit chaque DoT lancé, tick reconnu et estimation dans le chat.",
    ["Health bar in use"] = "Barre de vie utilisée",
    ["Kill icon in use"] = "Place de l'icône de mort",
    ["Commands: /wl did skull, plates, exec [percent], debug, reset (/wl did help explains them)."] =
        "Commandes : /wl did skull, plates, exec [pourcentage], debug, reset (/wl did help les explique).",
    -- Learned ticks
    ["What each DoT really ticks for, learned from your casts and used instead of its tooltip. Tooltips leave out spell power and attack power: Bonus is how much more yours do. Shift-click: link the spell. Right-click: forget the size."] =
        "Ce que chaque DoT fait vraiment par tick, appris de tes sorts et utilisé à la place de son infobulle. Les infobulles oublient la puissance des sorts et d'attaque : Bonus dit combien les tiens font de plus. Maj + clic : lien du sort. Clic droit : oublier la taille.",
    ["Spell"] = "Sort",
    ["Combo"] = "Combo",
    ["Per tick"] = "Par tick",
    ["Tooltip"] = "Infobulle",
    ["Bonus"] = "Bonus",
    ["Total"] = "Total",
    ["Nothing learned yet. Tick sizes are learned as your DoTs tick on your targets."] =
        "Rien d'appris pour l'instant. Les tailles de tick s'apprennent quand tes DoT font des ticks sur tes cibles.",
    ["Forget all"] = "Tout oublier",
    ["1 learned tick size"] = "1 taille de tick apprise",
    ["%d learned tick sizes"] = "%d tailles de tick apprises",
    ["Spell %d"] = "Sort %d",
    ["Combo points"] = "Points de combo",
    ["Learned per tick"] = "Appris par tick",
    ["Tooltip per tick"] = "Infobulle par tick",
    ["Ticks"] = "Ticks",
    ["%d, every %gs (%gs)"] = "%d, toutes les %g s (%g s)",
    ["Full duration"] = "Durée complète",
    ["Learned from this spell's ticks on your targets; used instead of the tooltip's number, which leaves out spell power and attack power."] =
        "Appris des ticks de ce sort sur tes cibles ; utilisé à la place du nombre de l'infobulle, qui oublie la puissance des sorts et d'attaque.",
    ["Shift-click: link it in chat. Right-click: forget it."] = "Maj + clic : lien dans le chat. Clic droit : l'oublier.",
    -- preview
    ["Live preview"] = "Aperçu en direct",
    ["Mottled Boar"] = "Sanglier tacheté",
    ["In combat: the marker and kill icon are showing on your target. The preview resumes after combat."] =
        "En combat : la marque et l'icône de mort s'affichent sur ta cible. L'aperçu reprend après le combat.",
    ["Target health"] = "Vie de la cible",
    ["DoT damage"] = "Dégâts des DoT",
    ["Remaining damage of two sample DoTs, as a percentage of the target's max health."] =
        "Dégâts restants de deux DoT d'exemple, en pourcentage de la vie max de la cible.",
    ["Simulate fight"] = "Simuler un combat",
    ["Stop"] = "Arrêter",
    ["Flash"] = "Flash",
    ["No DoTs on the target"] = "Aucun DoT sur la cible",
    ["DoTs finish it: the kill icon shows"] = "Les DoT l'achèvent : l'icône de mort s'affiche",
    ["Survives by %d%% of its health"] = "Survit avec %d %% de sa vie",
    ["Nameplate"] = "Barre de nom",
    ["While this tab is open, the marker and kill icon are drawn here instead of on your target."] =
        "Tant que cet onglet est ouvert, la marque et l'icône de mort sont dessinées ici au lieu de sur ta cible.",
})

local WHITE = "Interface\\Buttons\\WHITE8X8"
local ROW_HEIGHT = 24
local SETTINGS_LAYOUT = { label = 170, control = 200 }
local PREVIEW_LAYOUT = { label = 92, control = 140 }
local PREVIEW_WIDTH = 330
local DISABLED_ALPHA = 0.35
local SIMULATION_STEP = 0.5 -- seconds
local SUBTABS_TOP = -94      -- the sub-tab buttons; their pages start 28 px lower
local PANE_LEFT = 446        -- where the preview starts (the settings rows are 420 px wide)

-- The number settings (sliders): min, max, step. Also what an imported profile may set
-- (ns.Sanitize).
local RANGES = {
    skullSize = { 20, 128, 2 }, skullOffsetX = { -150, 150, 1 }, skullOffsetY = { -150, 150, 1 },
    fillOpacity = { 0, 100, 5 }, outlineThickness = { 1, 8, 1 }, outlineOpacity = { 10, 100, 5 },
    glowSize = { 2, 16, 1 }, shineInterval = { 2, 10, 1 }, labelSize = { 8, 20, 1 },
    nameplateIconSize = { 12, 128, 1 }, plateIconOffsetX = { -40, 40, 1 }, plateIconOffsetY = { -40, 40, 1 },
    plateFillOpacity = { 0, 100, 5 }, plateOutlineThickness = { 1, 3, 1 }, plateOutlineOpacity = { 10, 100, 5 },
    focusIconSize = { 12, 128, 1 }, focusIconOffsetX = { -40, 40, 1 }, focusIconOffsetY = { -40, 40, 1 },
    focusFillOpacity = { 0, 100, 5 }, focusOutlineThickness = { 1, 3, 1 }, focusOutlineOpacity = { 10, 100, 5 },
}
-- The choice settings and the list each picks from (ns.lists, filled by DoesItDie.lua, Display.lua, Nameplates.lua).
local CHOICES = {
    skullIcon = "icons", dotColors = "dotColors", fillTexture = "fills", fillColor = "colors",
    outlineStyle = "outlines", dashLength = "dashLengths", outlineColor = "colors",
    labelPosition = "labelPositions", labelColor = "colors", waitFirstTick = "waitModes",
    nameplateMode = "nameplateModes", plateIcon = "icons", nameplateIconPosition = "nameplateIconPositions",
    plateDotColors = "dotColors", plateFillTexture = "fills", plateFillColor = "colors",
    plateOutlineStyle = "outlines", plateDashLength = "dashLengths", plateOutlineColor = "colors",
    focusMode = "nameplateModes", focusIcon = "icons", focusIconPosition = "nameplateIconPositions",
    focusDotColors = "dotColors", focusFillTexture = "fills", focusFillColor = "colors",
    focusOutlineStyle = "outlines", focusDashLength = "dashLengths", focusOutlineColor = "colors",
}

-- Presets only set the look; accuracy settings are left alone.
local PRESETS = {
    { label = "Minimal", values = {
        showSkull = true, skullIcon = "cross", skullSize = 40, skullPulse = false,
        showMarkers = true, fillTexture = "flat", fillColor = "purple", fillOpacity = 35, dotColors = "single",
        outlineStyle = "solid", outlineThickness = 1, outlineColor = "purple", outlineOpacity = 100,
        smoothMotion = true, flashOnApply = false, pulseOutline = false,
        showSpark = false, showGlow = false, showShine = false, scrollStripes = false, showLabel = false,
    } },
    { label = "Classic", values = {
        showSkull = true, skullIcon = "skull", skullSize = 48, skullPulse = true,
        showMarkers = true, fillTexture = "smooth", fillColor = "red", fillOpacity = 60, dotColors = "single",
        outlineStyle = "dashed", dashLength = 4, outlineThickness = 2, outlineColor = "gold", outlineOpacity = 100,
        smoothMotion = true, flashOnApply = true, pulseOutline = false,
        showSpark = true, showGlow = false, showShine = false, scrollStripes = false, showLabel = false,
    } },
    { label = "Juicy", values = {
        showSkull = true, skullIcon = "shades", skullSize = 64, skullPulse = true,
        showMarkers = true, fillTexture = "stripes", fillColor = "red", fillOpacity = 100, dotColors = "each",
        segmentDividers = true, outlineStyle = "dashed", dashLength = 4, outlineThickness = 1, outlineColor = "red",
        outlineOpacity = 85, smoothMotion = true, flashOnApply = true, pulseOutline = true,
        showSpark = true, showGlow = true, glowSize = 7, showShine = true, shineInterval = 3, scrollStripes = true,
        showLabel = false,
    } },
    { label = "Debug", values = {
        showSkull = true, skullIcon = "cross", skullPulse = false,
        showMarkers = true, fillTexture = "flat", fillOpacity = 60, dotColors = "school", segmentDividers = true,
        outlineStyle = "solid", outlineThickness = 1, outlineColor = "white", outlineOpacity = 100,
        smoothMotion = false, flashOnApply = true, pulseOutline = false,
        showSpark = false, showGlow = false, showShine = false, scrollStripes = false,
        showLabel = true, labelPosition = "left", labelSize = 10, labelColor = "white",
    } },
}

local function findEntry(list, id)
    for _, entry in ipairs(list or {}) do
        if entry.id == id then return entry end
    end
end

-- A number out of its slider's range, or an id not in its list (an imported profile, an edited file), goes back to
-- the default: a made-up size or texture drew huge frames or nothing at all.
function ns.Sanitize(db)
    for key, range in pairs(RANGES) do
        local v = db[key]
        if type(v) ~= "number" or v ~= v or v < range[1] or v > range[2] then db[key] = ns.DEFAULTS[key] end
    end
    for key, listName in pairs(CHOICES) do
        if not findEntry(ns.lists[listName], db[key]) then db[key] = ns.DEFAULTS[key] end
    end
end

local page        -- the tab (p of W.RegisterModule)
local ui = {}     -- the preview's widgets and the sub-tabs
local controls = {} -- every settings / preview row, refreshed after each change
local menu        -- shared list of choices
local simulation

-- Preview numbers, in % of the mock target's max health.
local preview = {
    health = 60,
    dots = {
        { name = "Corruption", school = 32, damage = 27, tick = 4 },
        { name = "Immolate", school = 4, damage = 18, tick = 5 },
    },
}

local function db() return ns.db end

local function setBackdrop(frame, shade, alpha)
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    frame:SetBackdropColor(shade, shade, shade, alpha or 1)
    frame:SetBackdropBorderColor(0.28, 0.28, 0.3, 1)
end

local function refreshControls()
    for _, control in ipairs(controls) do control:Refresh() end
end

local function changed()
    ns.reattach() -- the look is applied again, then the display redrawn
    refreshControls()
end
-- a slider's drag sends 20 to 60 steps a second: the whole pass above runs 10 times a second at most
local changedSoon = W.Coalesce(0.1, changed)

---------------------------------------------------------------------------
-- Preview
---------------------------------------------------------------------------

local function previewTotal()
    local total = 0
    for _, dot in ipairs(preview.dots) do total = total + dot.damage end
    return total
end

-- Splits a total over the two sample DoTs (60/40).
local function setPreviewDamage(total)
    preview.dots[1].damage = total * 0.6
    preview.dots[2].damage = total * 0.4
end

local function inCombat()
    return (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player"))
end

local function stopSimulation()
    if simulation then
        simulation:Cancel()
        simulation = nil
    end
    if ui.simulateButton then ui.simulateButton:SetText(L("Simulate fight")) end
end

-- The preview only takes over the display out of combat: in combat the real target comes first, even with the tab
-- open (settings changes still apply to it live).
local function syncDisplayHost()
    if not ui.mock or not page:IsVisible() then return end
    local paused = inCombat() and true or false
    ui.combatNote:SetShown(paused)
    ui.mock:SetAlpha(paused and 0.3 or 1)
    ui.mockPlate:SetAlpha(paused and 0.3 or 1)
    ui.mockFocus:SetAlpha(paused and 0.3 or 1)
    ui.simulateButton:SetEnabled(not paused)
    ui.flashButton:SetEnabled(not paused)
    if paused ~= ui.previewPaused then
        ui.previewPaused = paused
        if paused then stopSimulation() end
        ns.setDisplayHost((not paused) and ui.host or nil)
        ns.setPlatePreview((not paused) and ui.plateHost or nil, preview)
        ns.setFocusPreview((not paused) and ui.focusHost or nil, preview)
    end
end

local function updatePreview()
    if not ui.mock then return end
    ui.healthBar:SetValue(preview.health)
    ui.plateHealthBar:SetValue(preview.health)
    ui.focusHealthBar:SetValue(preview.health)
    local total = previewTotal()
    if total <= 0 then
        ui.status:SetText(L("No DoTs on the target"))
    elseif total >= preview.health then
        ui.status:SetText("|cff66ff66" .. L("DoTs finish it: the kill icon shows") .. "|r")
    else
        ui.status:SetText(L("Survives by %d%% of its health"):format(math.floor(preview.health - total + 0.5)))
    end
    ns.refresh()
end

-- A scripted fight: a DoT lands, ticks, a second DoT lands and makes it lethal, ticks until the target dies.
local function startSimulation()
    stopSimulation()
    if not (C_Timer and C_Timer.NewTicker) then return end
    preview.health = 80
    setPreviewDamage(0)
    local step = 0
    simulation = C_Timer.NewTicker(SIMULATION_STEP, function()
        step = step + 1
        if step == 1 then
            preview.dots[1].damage = 32
            ns.playFlash()
        elseif step == 5 then
            preview.dots[2].damage = 50
            ns.playFlash()
        else
            local dealt = 0
            for _, dot in ipairs(preview.dots) do
                local tick = math.min(dot.damage, dot.tick)
                dot.damage = dot.damage - tick
                dealt = dealt + tick
            end
            preview.health = math.max(0, preview.health - dealt)
        end
        updatePreview()
        refreshControls()
        if preview.health <= 0 or (step > 5 and previewTotal() <= 0) then stopSimulation() end
    end)
    ui.simulateButton:SetText(L("Stop"))
    updatePreview()
    refreshControls()
end

---------------------------------------------------------------------------
-- Rows: a label (W.Label, so the window's search finds the option) and a control
---------------------------------------------------------------------------

local function makeRow(parent, labelText, opts)
    local layout = opts.layout or SETTINGS_LAYOUT
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(layout.label + layout.control + 50, ROW_HEIGHT)
    row.layout = layout
    row.label = W.Label(row, labelText, "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", 6, 0)
    row.label:SetWidth(layout.label - 8)
    row.enabledIf = opts.enabledIf
    if opts.tooltip then
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(labelText, 1, 1, 1)
            GameTooltip:AddLine(opts.tooltip, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    function row:ApplyEnabled(widget)
        local enabled = not self.enabledIf or self.enabledIf(db())
        self:SetAlpha(enabled and 1 or DISABLED_ALPHA)
        widget:EnableMouse(enabled)
        if widget.EnableMouseWheel then widget:EnableMouseWheel(enabled) end
    end
    controls[#controls + 1] = row
    return row
end

local function checkbox(parent, key, labelText, opts)
    opts = opts or {}
    local row = makeRow(parent, labelText, opts)
    local box = CreateFrame("CheckButton", nil, row)
    box:SetSize(24, 24)
    box:SetPoint("LEFT", row, "LEFT", row.layout.label, 0)
    box:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    box:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    box:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    box:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    box:SetScript("OnClick", function(self)
        db()[key] = self:GetChecked() and true or false
        changed()
    end)
    function row:Refresh()
        box:SetChecked(db()[key] and true or false)
        self:ApplyEnabled(box)
    end
    return row
end

-- get / set work on any value (a setting or a preview number).
local function sliderRow(parent, labelText, min, max, step, get, set, opts)
    opts = opts or {}
    local row = makeRow(parent, labelText, opts)
    local slider = CreateFrame("Slider", nil, row)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(row.layout.control - 44, 18)
    slider:SetPoint("LEFT", row, "LEFT", row.layout.label + 2, 0)
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(0.3, 0.3, 0.32, 1)
    track:SetHeight(4)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider:GetThumbTexture():SetSize(18, 24)
    local valueText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueText:SetPoint("LEFT", slider, "RIGHT", 8, 0)
    local suffix = opts.suffix or ""
    local updating = false
    slider:SetScript("OnValueChanged", function(_, value)
        if updating then return end
        value = math.floor(value / step + 0.5) * step
        valueText:SetText(value .. suffix)
        set(value)
    end)
    slider:SetScript("OnMouseWheel", function(self, delta) self:SetValue(self:GetValue() + delta * step) end)
    function row:Refresh()
        updating = true
        local value = get()
        slider:SetValue(value)
        valueText:SetText(math.floor(value / step + 0.5) * step .. suffix)
        updating = false
        self:ApplyEnabled(slider)
    end
    return row
end

local function slider(parent, key, labelText, opts)
    local range = RANGES[key]
    return sliderRow(parent, labelText, range[1], range[2], range[3],
        function() return db()[key] end,
        function(value)
            db()[key] = value
            changedSoon()
        end, opts)
end

local function closeMenu()
    if menu then menu:Hide() end
end

-- Shared list of choices under `owner`; entries may carry an rgb swatch. On the tab (not UIParent): it follows the
-- window's scale.
local function openMenu(owner, list, current, pick)
    if not menu then
        menu = CreateFrame("Frame", nil, page, "BackdropTemplate")
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:EnableMouse(true)
        setBackdrop(menu, 0.08, 0.98)
        menu.buttons = {}
        menu:Hide()
        -- closed by a click anywhere else, only while it is open (the event may not exist on every client)
        menu:SetScript("OnShow", function(self) pcall(self.RegisterEvent, self, "GLOBAL_MOUSE_DOWN") end)
        menu:SetScript("OnHide", function(self) self:UnregisterAllEvents() end)
        menu:SetScript("OnEvent", function(self)
            if not self:IsMouseOver() and not (self.owner and self.owner:IsMouseOver()) then self:Hide() end
        end)
    end
    if menu:IsShown() and menu.owner == owner then return menu:Hide() end
    menu.owner = owner
    for i, entry in ipairs(list) do
        local button = menu.buttons[i]
        if not button then
            button = CreateFrame("Button", nil, menu)
            button:SetHeight(20)
            local highlight = button:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints()
            highlight:SetColorTexture(1, 1, 1, 0.1)
            button.swatch = button:CreateTexture(nil, "ARTWORK")
            button.swatch:SetSize(12, 12)
            button.swatch:SetPoint("LEFT", 8, 0)
            button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            button.text:SetJustifyH("LEFT")
            menu.buttons[i] = button
        end
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, -4 - (i - 1) * 20)
        button:SetPoint("RIGHT", menu, "RIGHT", -1, 0)
        button.swatch:SetShown(entry.rgb ~= nil)
        if entry.rgb then button.swatch:SetColorTexture(entry.rgb[1], entry.rgb[2], entry.rgb[3], 1) end
        button.text:ClearAllPoints()
        button.text:SetPoint("LEFT", entry.rgb and 26 or 8, 0)
        button.text:SetText(entry.id == current and ("|cffffd100" .. L(entry.label) .. "|r") or L(entry.label))
        button:SetScript("OnClick", function()
            menu:Hide()
            pick(entry.id)
        end)
        button:Show()
    end
    for i = #list + 1, #menu.buttons do menu.buttons[i]:Hide() end
    menu:SetSize(owner:GetWidth(), #list * 20 + 8)
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    menu:Show()
end

local function choice(parent, key, labelText, opts)
    opts = opts or {}
    local list = ns.lists[CHOICES[key]]
    local row = makeRow(parent, labelText, opts)
    local button = CreateFrame("Button", nil, row, "BackdropTemplate")
    button:SetSize(row.layout.control, 22)
    button:SetPoint("LEFT", row, "LEFT", row.layout.label, 0)
    setBackdrop(button, 0.13)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.06)
    local swatch = button:CreateTexture(nil, "ARTWORK")
    swatch:SetSize(12, 12)
    swatch:SetPoint("LEFT", 8, 0)
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetJustifyH("LEFT")
    local arrow = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    arrow:SetPoint("RIGHT", -8, 0)
    arrow:SetText("v")
    button:SetScript("OnClick", function(self)
        openMenu(self, list, db()[key], function(id)
            db()[key] = id
            changed()
        end)
    end)
    function row:Refresh()
        local entry = findEntry(list, db()[key])
        text:SetText(entry and L(entry.label) or tostring(db()[key]))
        swatch:SetShown(entry ~= nil and entry.rgb ~= nil)
        if entry and entry.rgb then swatch:SetColorTexture(entry.rgb[1], entry.rgb[2], entry.rgb[3], 1) end
        text:ClearAllPoints()
        text:SetPoint("LEFT", (entry and entry.rgb) and 26 or 8, 0)
        text:SetPoint("RIGHT", -20, 0)
        self:ApplyEnabled(button)
    end
    return row
end

-- A line of text in the settings column, from getText().
local function infoRow(parent, labelText, getText, opts)
    opts = opts or {}
    local row = makeRow(parent, labelText, opts)
    local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", row, "LEFT", row.layout.label, 0)
    text:SetWidth(row.layout.control + 40)
    text:SetJustifyH("LEFT")
    function row:Refresh() text:SetText(getText()) end
    return row
end

---------------------------------------------------------------------------
-- Learned tick sizes (sub-tab): what each DoT really ticks for, next to its tooltip
---------------------------------------------------------------------------

local function formatTick(value)
    if not value then return "-" end
    if value == math.floor(value) then return string.format("%d", value) end
    return string.format("%.1f", value)
end

local function spellLink(spellID)
    local fn = C_Spell and C_Spell.GetSpellLink or GetSpellLink
    if not fn then return nil end
    local ok, link = pcall(fn, spellID)
    if ok and type(link) == "string" then return link end
end

local function showTickTooltip(owner, entry)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local shown = GameTooltip.SetSpellByID and pcall(GameTooltip.SetSpellByID, GameTooltip, entry.spellID)
    if not shown then GameTooltip:SetText(entry.name or L("Spell %d"):format(entry.spellID), 1, 1, 1) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("DoesItDie", 1, 0.82, 0)
    if entry.comboPoints then
        GameTooltip:AddDoubleLine(L("Combo points"), entry.comboPoints, 0.8, 0.8, 0.8, 1, 1, 1)
    end
    GameTooltip:AddDoubleLine(L("Learned per tick"), formatTick(entry.perTick), 0.8, 0.8, 0.8, 1, 1, 1)
    if entry.tooltipPerTick then
        GameTooltip:AddDoubleLine(L("Tooltip per tick"), formatTick(entry.tooltipPerTick), 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddDoubleLine(L("Ticks"), L("%d, every %gs (%gs)"):format(entry.ticks, entry.interval,
            entry.duration), 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddDoubleLine(L("Full duration"), formatTick(entry.perTick * entry.ticks), 0.8, 0.8, 0.8, 1, 1, 1)
    end
    GameTooltip:AddLine(L("Learned from this spell's ticks on your targets; used instead of the tooltip's number, which leaves out spell power and attack power."), 0.6, 0.6, 0.6, true)
    GameTooltip:AddLine(L("Shift-click: link it in chat. Right-click: forget it."), 0.5, 0.8, 1)
    GameTooltip:Show()
end

local function colorCode(rgb)
    local function byte(v) return math.floor(v * 255 + 0.5) end
    return string.format("|cff%02x%02x%02x", byte(rgb[1]), byte(rgb[2]), byte(rgb[3]))
end

local function refreshTicks()
    if not ui.ticks or not db() then return end
    local rows = {}
    for _, entry in ipairs(ns.learnedTickList()) do
        local bonus = entry.tooltipPerTick and entry.tooltipPerTick > 0
            and math.floor((entry.perTick / entry.tooltipPerTick - 1) * 100 + 0.5)
        local bonusText = "-"
        if bonus then
            bonusText = string.format("%+d%%", bonus)
            if bonus > 0 then bonusText = "|cff66ff66" .. bonusText .. "|r"
            elseif bonus < 0 then bonusText = "|cffff7373" .. bonusText .. "|r" end
        end
        local name = entry.name or L("Spell %d"):format(entry.spellID)
        rows[#rows + 1] = { entry = entry, cells = {
            entry.color and (colorCode(entry.color) .. name .. "|r") or name,
            entry.comboPoints and tostring(entry.comboPoints) or "",
            formatTick(entry.perTick),
            entry.tooltipPerTick and formatTick(entry.tooltipPerTick) or "-",
            bonusText,
            entry.ticks and formatTick(entry.perTick * entry.ticks) or "-",
        } }
    end
    ui.ticks:SetData(rows)
    ui.ticksCount:SetText(#rows == 1 and L("1 learned tick size") or L("%d learned tick sizes"):format(#rows))
    ui.forgetAll:SetEnabled(#rows > 0)
end

local function buildTicks(frame)
    local intro = W.Label(frame, L("What each DoT really ticks for, learned from your casts and used instead of its tooltip. Tooltips leave out spell power and attack power: Bonus is how much more yours do. Shift-click: link the spell. Right-click: forget the size."), "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", 8, -8)
    intro:SetWidth(PANE_LEFT - 20)
    ui.ticks = W.Table(frame, {
        { L("Spell"), 150 }, { L("Combo"), 46, "CENTER" }, { L("Per tick"), 56, "RIGHT" },
        { L("Tooltip"), 56, "RIGHT" }, { L("Bonus"), 50, "RIGHT" }, { L("Total"), 56, "RIGHT" },
    }, 330, 18)
    ui.ticks:SetPoint("TOPLEFT", 4, -70)
    ui.ticks:SetEmptyText(L("Nothing learned yet. Tick sizes are learned as your DoTs tick on your targets."))
    ui.ticks.onEnter = function(data, row) showTickTooltip(row, data.entry) end
    ui.ticks.onClick = function(data, button)
        if button == "RightButton" then
            ns.forgetLearnedTick(data.entry.key)
            GameTooltip:Hide()
            refreshTicks()
        elseif IsShiftKeyDown and IsShiftKeyDown() then
            local link = spellLink(data.entry.spellID)
            if link and not (ChatEdit_InsertLink and ChatEdit_InsertLink(link)) and ChatFrame_OpenChat then
                ChatFrame_OpenChat(link)
            end
        end
    end
    ui.ticksCount = W.Label(frame, "", "GameFontDisableSmall")
    ui.ticksCount:SetPoint("BOTTOMLEFT", 10, 16)
    ui.forgetAll = W.Button(frame, L("Forget all"), 110, 22, function()
        ns.resetLearnedTicks()
        refreshTicks()
    end)
    ui.forgetAll:SetPoint("BOTTOMLEFT", 300, 10)
end

---------------------------------------------------------------------------
-- Sub-tabs of settings
---------------------------------------------------------------------------

-- A sub-tab whose methods add rows top to bottom and remember the setting keys, for "Reset this tab".
local function newTab(frame)
    local tab = { frame = frame, keys = {}, y = 8 }
    local function place(row, key)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -tab.y)
        tab.y = tab.y + ROW_HEIGHT
        if key then tab.keys[#tab.keys + 1] = key end
        return row
    end
    function tab:checkbox(key, ...) return place(checkbox(frame, key, ...), key) end
    function tab:slider(key, ...) return place(slider(frame, key, ...), key) end
    function tab:choice(key, ...) return place(choice(frame, key, ...), key) end
    function tab:info(...) return place(infoRow(frame, ...)) end
    function tab:gap() self.y = self.y + 6 end
    return tab
end

local function isDashed(s) return s.outlineStyle == "dashed" end
local function hasOutline(s) return s.outlineStyle ~= "none" end
local function singleColor(s) return s.dotColors == "single" end
local function perDot(s) return s.dotColors ~= "single" end
local function showsLabel(s) return s.showLabel end

local function buildSettings(frames)
    local tabs = {}

    local icon = newTab(frames[1])
    icon:checkbox("showSkull", L("Show icon on portrait"),
        { tooltip = L("Shows an icon over the target's portrait when your DoTs on it will kill it.") })
    icon:choice("skullIcon", L("Icon"))
    icon:slider("skullSize", L("Size"))
    icon:checkbox("skullPulse", L("Pulse"), { tooltip = L("Gently pulses the icon while it's showing.") })
    icon:slider("skullOffsetX", L("Horizontal offset"),
        { tooltip = L("Pixels right (+) or left (-) of the portrait's center.") })
    icon:slider("skullOffsetY", L("Vertical offset"),
        { tooltip = L("Pixels up (+) or down (-) from the portrait's center.") })
    tabs[1] = icon

    local marker = newTab(frames[2])
    marker:checkbox("showMarkers", L("Show damage marker"), { tooltip = L("Marks the damage your DoTs still have to deal on the target's health bar. If the health ends inside it, the target dies.") })
    marker:choice("dotColors", L("DoT colors"), { tooltip = L("One color, or one segment per DoT colored by spell school or with a different color each.") })
    marker:choice("fillTexture", L("Fill style"))
    marker:choice("fillColor", L("Fill color"), { enabledIf = singleColor,
        tooltip = L("Used when DoT colors is set to one color.") })
    marker:slider("fillOpacity", L("Fill opacity"), { suffix = "%" })
    marker:checkbox("segmentDividers", L("Dividers between DoTs"), { enabledIf = perDot })
    marker:gap()
    marker:choice("outlineStyle", L("Outline"))
    marker:choice("dashLength", L("Dash length"), { enabledIf = isDashed })
    marker:slider("outlineThickness", L("Outline thickness"), { enabledIf = hasOutline })
    marker:choice("outlineColor", L("Outline color"), { enabledIf = hasOutline })
    marker:slider("outlineOpacity", L("Outline opacity"), { suffix = "%", enabledIf = hasOutline })
    tabs[2] = marker

    local effects = newTab(frames[3])
    effects:checkbox("smoothMotion", L("Smooth motion"),
        { tooltip = L("The marker grows in when it appears and glides to new values instead of jumping.") })
    effects:checkbox("flashOnApply", L("Flash on new DoT"))
    effects:checkbox("showSpark", L("Spark"), { tooltip = L("A bright flare on the marker's edge when a DoT lands.") })
    effects:checkbox("pulseOutline", L("Pulse outline"), { enabledIf = hasOutline })
    effects:gap()
    effects:checkbox("showGlow", L("Glow"), { enabledIf = hasOutline, tooltip = L("Soft halo in the outline color.") })
    effects:slider("glowSize", L("Glow size"), { enabledIf = function(s) return hasOutline(s) and s.showGlow end })
    effects:checkbox("showShine", L("Shine sweep"))
    effects:slider("shineInterval", L("Shine every"), { suffix = "s", enabledIf = function(s) return s.showShine end })
    effects:checkbox("scrollStripes", L("Scroll stripes"), { tooltip = L("Animates the diagonal stripes fill."),
        enabledIf = function(s) return s.fillTexture == "stripes" and singleColor(s) end })
    tabs[3] = effects

    local text = newTab(frames[4])
    text:checkbox("showLabel", L("Show damage text"),
        { tooltip = L("Remaining DoT damage next to the health bar (a per-DoT breakdown with DoT colors).") })
    text:choice("labelPosition", L("Position"), { enabledIf = showsLabel })
    text:slider("labelSize", L("Size"), { enabledIf = showsLabel })
    text:choice("labelColor", L("Color"), { enabledIf = showsLabel })
    tabs[4] = text

    -- Nameplates have their own look: enemy plates are red, so the target marker's colors may not show on them.
    local platesOn = function(s) return s.nameplateMode ~= "off" end
    local plateIcon = function(s) return s.nameplateMode == "markerIcon" end
    local plateSingle = function(s) return platesOn(s) and s.plateDotColors == "single" end
    local plateOutline = function(s) return platesOn(s) and s.plateOutlineStyle ~= "none" end
    local plates = newTab(frames[5])
    plates:choice("nameplateMode", L("Show on nameplates"), { tooltip = L("Draws a marker (and optionally the kill icon) on every enemy nameplate with your DoTs on it, in its own look below.") })
    plates:choice("plateIcon", L("Kill icon"), { enabledIf = plateIcon })
    plates:slider("nameplateIconSize", L("Kill icon size"), { enabledIf = plateIcon })
    plates:choice("nameplateIconPosition", L("Kill icon position"), { enabledIf = plateIcon })
    plates:slider("plateIconOffsetX", L("Icon horizontal offset"),
        { enabledIf = plateIcon, tooltip = L("Pixels right (+) or left (-) of the chosen position.") })
    plates:slider("plateIconOffsetY", L("Icon vertical offset"),
        { enabledIf = plateIcon, tooltip = L("Pixels up (+) or down (-) from the chosen position.") })
    plates:gap()
    plates:choice("plateDotColors", L("DoT colors"), { enabledIf = platesOn })
    plates:choice("plateFillTexture", L("Fill style"), { enabledIf = platesOn })
    plates:choice("plateFillColor", L("Fill color"), { enabledIf = plateSingle })
    plates:slider("plateFillOpacity", L("Fill opacity"), { suffix = "%", enabledIf = platesOn })
    plates:choice("plateOutlineStyle", L("Outline"), { enabledIf = platesOn })
    plates:choice("plateDashLength", L("Dash length"),
        { enabledIf = function(s) return platesOn(s) and s.plateOutlineStyle == "dashed" end })
    plates:slider("plateOutlineThickness", L("Outline thickness"), { enabledIf = plateOutline })
    plates:choice("plateOutlineColor", L("Outline color"), { enabledIf = plateOutline })
    plates:slider("plateOutlineOpacity", L("Outline opacity"), { suffix = "%", enabledIf = plateOutline })
    plates:info(L("Nameplate bar in use"), function() return ns.plateBarStatus() end)
    plates.footer = W.Button(frames[5], L("Copy from the Marker tab"), 200, 22, function()
        local s = db()
        s.plateFillTexture, s.plateFillColor, s.plateFillOpacity = s.fillTexture, s.fillColor, s.fillOpacity
        s.plateDotColors, s.plateIcon = s.dotColors, s.skullIcon
        s.plateOutlineStyle, s.plateDashLength = s.outlineStyle, s.dashLength
        s.plateOutlineThickness = math.min(s.outlineThickness, 3)
        s.plateOutlineColor, s.plateOutlineOpacity = s.outlineColor, s.outlineOpacity
        changed()
    end)
    tabs[5] = plates

    -- The focus frame (Focus.lua): its own look, like the nameplates'.
    local focusOn = function(s) return s.focusMode ~= "off" end
    local focusIcon = function(s) return s.focusMode == "markerIcon" end
    local focusSingle = function(s) return focusOn(s) and s.focusDotColors == "single" end
    local focusOutline = function(s) return focusOn(s) and s.focusOutlineStyle ~= "none" end
    local focus = newTab(frames[6])
    focus:choice("focusMode", L("Show on focus frame"), { tooltip = L("Draws the marker (and optionally the kill icon) on your focus's health bar, for your DoTs on it, in its own look below. /cast [@focus] macros put the DoT on your focus.") })
    focus:choice("focusIcon", L("Kill icon"), { enabledIf = focusIcon })
    focus:slider("focusIconSize", L("Kill icon size"), { enabledIf = focusIcon })
    focus:choice("focusIconPosition", L("Kill icon position"), { enabledIf = focusIcon })
    focus:slider("focusIconOffsetX", L("Icon horizontal offset"),
        { enabledIf = focusIcon, tooltip = L("Pixels right (+) or left (-) of the chosen position.") })
    focus:slider("focusIconOffsetY", L("Icon vertical offset"),
        { enabledIf = focusIcon, tooltip = L("Pixels up (+) or down (-) from the chosen position.") })
    focus:gap()
    focus:choice("focusDotColors", L("DoT colors"), { enabledIf = focusOn })
    focus:choice("focusFillTexture", L("Fill style"), { enabledIf = focusOn })
    focus:choice("focusFillColor", L("Fill color"), { enabledIf = focusSingle })
    focus:slider("focusFillOpacity", L("Fill opacity"), { suffix = "%", enabledIf = focusOn })
    focus:choice("focusOutlineStyle", L("Outline"), { enabledIf = focusOn })
    focus:choice("focusDashLength", L("Dash length"),
        { enabledIf = function(s) return focusOn(s) and s.focusOutlineStyle == "dashed" end })
    focus:slider("focusOutlineThickness", L("Outline thickness"), { enabledIf = focusOutline })
    focus:choice("focusOutlineColor", L("Outline color"), { enabledIf = focusOutline })
    focus:slider("focusOutlineOpacity", L("Outline opacity"), { suffix = "%", enabledIf = focusOutline })
    focus:info(L("Focus bar in use"), function() return ns.focusStatus() end)
    focus.footer = W.Button(frames[6], L("Copy from the Nameplates tab"), 200, 22, function()
        local s = db()
        for plateKey, focusKey in pairs(ns.focusKeys) do
            if plateKey ~= "nameplateMode" then s[focusKey] = s[plateKey] end
        end
        changed()
    end)
    tabs[6] = focus

    local accuracy = newTab(frames[7])
    accuracy:choice("waitFirstTick", L("Wait for first tick"), { tooltip = L("Whether a new DoT counts before its first tick lands. \"When unsure\" waits for finishers with unknown combo points and spells the addon hasn't seen tick yet.") })
    accuracy:checkbox("estimateDuringCast", L("Estimate during casting"), { tooltip = L("Shows a DoT with a cast time while you're still casting it. Once the cast lands the normal estimate takes over; an interrupted or failed cast removes it.") })
    accuracy:checkbox("debug", L("Echo trace log to chat"),
        { tooltip = L("Prints each DoT cast, matched tick and estimate to chat.") })
    accuracy:gap()
    accuracy:info(L("Health bar in use"), function() return (ns.attachStatus()) end)
    accuracy:info(L("Kill icon in use"), function() return select(2, ns.attachStatus()) end)
    local commands = W.Label(frames[7], L("Commands: /wl did skull, plates, exec [percent], debug, reset (/wl did help explains them)."), "GameFontDisableSmall")
    commands:SetPoint("TOPLEFT", 10, -(accuracy.y + 10))
    commands:SetWidth(PANE_LEFT - 20)
    tabs[7] = accuracy

    for _, tab in ipairs(tabs) do
        if tab.footer then tab.footer:SetPoint("BOTTOMLEFT", 10, 10) end
    end
    return tabs
end

---------------------------------------------------------------------------
-- Preview pane
---------------------------------------------------------------------------

local function mockBar(parent, width, height, r, g, b, backR, backG, backB)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(width, height)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(r, g, b)
    bar:SetMinMaxValues(0, 100)
    local back = bar:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(backR, backG, backB, 1)
    return bar
end

local function roundPortrait(parent, size)
    local portrait = parent:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(size, size)
    portrait:SetTexture("Interface\\Icons\\Ability_Hunter_Pet_Boar")
    local mask = parent:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(portrait)
    portrait:AddMaskTexture(mask)
    return portrait
end

local function buildPreview(pane)
    local title = W.Label(pane, L("Live preview"), "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10)

    -- Mock target frame: name, health bar, round portrait.
    local mock = CreateFrame("Frame", nil, pane, "BackdropTemplate")
    mock:SetSize(PREVIEW_WIDTH - 24, 78)
    mock:SetPoint("TOPLEFT", pane, "TOPLEFT", 12, -32)
    setBackdrop(mock, 0.03)
    local portrait = roundPortrait(mock, 56)
    portrait:SetPoint("RIGHT", mock, "RIGHT", -12, 0)
    local healthBar = mockBar(mock, PREVIEW_WIDTH - 110, 18, 0.1, 0.8, 0.1, 0.25, 0.08, 0.08)
    healthBar:SetPoint("RIGHT", portrait, "LEFT", -10, -6)
    local name = mock:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name:SetPoint("BOTTOMLEFT", healthBar, "TOPLEFT", 0, 4)
    name:SetText(L("Mottled Boar"))
    ui.mock, ui.healthBar = mock, healthBar
    ui.host = { healthBar = healthBar, portrait = portrait, layerFrame = page }

    -- Over the mock frame while combat has the display back on the real target.
    ui.combatNote = pane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ui.combatNote:SetPoint("CENTER", mock, "CENTER")
    ui.combatNote:SetWidth(PREVIEW_WIDTH - 40)
    ui.combatNote:SetText(L("In combat: the marker and kill icon are showing on your target. The preview resumes after combat."))
    ui.combatNote:Hide()

    -- Preview controls (plain numbers, not settings).
    local health = sliderRow(pane, L("Target health"), 0, 100, 1,
        function() return preview.health end,
        function(value)
            stopSimulation()
            preview.health = value
            updatePreview()
        end, { layout = PREVIEW_LAYOUT, suffix = "%" })
    health:SetPoint("TOPLEFT", mock, "BOTTOMLEFT", -4, -10)
    local damage = sliderRow(pane, L("DoT damage"), 0, 100, 1,
        function() return math.floor(previewTotal() + 0.5) end,
        function(value)
            stopSimulation()
            setPreviewDamage(value)
            updatePreview()
        end, { layout = PREVIEW_LAYOUT, suffix = "%",
            tooltip = L("Remaining damage of two sample DoTs, as a percentage of the target's max health.") })
    damage:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, 0)

    ui.simulateButton = W.Button(pane, L("Simulate fight"), 130, 22, function()
        if simulation then stopSimulation() else startSimulation() end
    end)
    ui.simulateButton:SetPoint("TOPLEFT", damage, "BOTTOMLEFT", 6, -8)
    ui.flashButton = W.Button(pane, L("Flash"), 80, 22, function() ns.playFlash() end)
    ui.flashButton:SetPoint("LEFT", ui.simulateButton, "RIGHT", 8, 0)

    ui.status = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ui.status:SetPoint("TOPLEFT", ui.simulateButton, "BOTTOMLEFT", 0, -10)
    ui.status:SetWidth(PREVIEW_WIDTH - 30)
    ui.status:SetJustifyH("LEFT")

    -- Mock enemy nameplate (red, like the real ones), drawn by the real nameplate code (Nameplates.lua).
    local plateLabel = pane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    plateLabel:SetPoint("TOPLEFT", ui.status, "BOTTOMLEFT", 0, -16)
    plateLabel:SetText(L("Nameplate"))
    local mockPlate = CreateFrame("Frame", nil, pane)
    mockPlate:SetSize(140, 26)
    mockPlate:SetPoint("TOPLEFT", plateLabel, "BOTTOMLEFT", 40, -6)
    local plateName = mockPlate:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    plateName:SetPoint("TOP", mockPlate, "TOP")
    plateName:SetText(L("Mottled Boar"))
    local plateBar = mockBar(mockPlate, 140, 10, 0.85, 0.1, 0.1, 0.1, 0.02, 0.02)
    plateBar:SetPoint("BOTTOM", mockPlate, "BOTTOM")
    ui.mockPlate, ui.plateHealthBar = mockPlate, plateBar
    ui.plateHost = { plate = mockPlate, healthBar = plateBar }

    -- A small focus frame (Focus.lua draws on it), shaped like Blizzard's: bar on the left, portrait on the right.
    local focusLabel = pane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    focusLabel:SetPoint("TOPLEFT", plateLabel, "BOTTOMLEFT", 0, -44)
    focusLabel:SetText(L("Focus"))
    local mockFocus = CreateFrame("Frame", nil, pane)
    mockFocus:SetSize(170, 36)
    mockFocus:SetPoint("TOPLEFT", focusLabel, "BOTTOMLEFT", 50, -4)
    local focusPortrait = roundPortrait(mockFocus, 32)
    focusPortrait:SetPoint("RIGHT", mockFocus, "RIGHT", 0, 0)
    local focusBar = mockBar(mockFocus, 130, 12, 0.1, 0.8, 0.1, 0.25, 0.08, 0.08)
    focusBar:SetPoint("RIGHT", focusPortrait, "LEFT", -6, -5)
    local focusName = mockFocus:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    focusName:SetPoint("BOTTOMLEFT", focusBar, "TOPLEFT", 0, 3)
    focusName:SetText(L("Mottled Boar"))
    ui.mockFocus, ui.focusHealthBar = mockFocus, focusBar
    ui.focusHost = { frame = mockFocus, healthBar = focusBar }

    local hint = pane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", 12, 10)
    hint:SetWidth(PREVIEW_WIDTH - 24)
    hint:SetJustifyH("LEFT")
    hint:SetText(L("While this tab is open, the marker and kill icon are drawn here instead of on your target."))
end

---------------------------------------------------------------------------
-- The tab
---------------------------------------------------------------------------

local LEARNED_TAB = 8

-- y: below the header of ../DoesItDie.lua (title, description, switch, presets).
function ns.BuildTab(p)
    page = p
    -- Presets, right-aligned on the switch's line.
    local previous
    for i = #PRESETS, 1, -1 do
        local preset = PRESETS[i]
        local button = W.Button(p, L(preset.label), 80, 22, function()
            for key, value in pairs(preset.values) do db()[key] = value end
            changed()
            ns.print(L("%s preset applied."):format(L(preset.label)))
        end)
        if previous then
            button:SetPoint("RIGHT", previous, "LEFT", -4, 0)
        else
            button:SetPoint("TOPRIGHT", p, "TOPRIGHT", -8, -62)
        end
        previous = button
    end
    local presetLabel = W.Label(p, L("Presets"), "GameFontDisableSmall")
    presetLabel:SetPoint("RIGHT", previous, "LEFT", -8, 0)

    local tabs
    local sub = W.SubTabs(p, { L("Kill icon"), L("Marker"), L("Effects"), L("Text"), L("Nameplates"), L("Focus"),
        L("Accuracy"), L("Learned ticks") }, function(i)
        closeMenu()
        if ui.reset then ui.reset:SetShown(i ~= LEARNED_TAB) end
        if i == LEARNED_TAB then refreshTicks() end
        ui.current = tabs and tabs[i]
    end, SUBTABS_TOP)
    tabs = buildSettings(sub.frames)
    buildTicks(sub.frames[LEARNED_TAB])
    ui.reset = W.Button(p, L("Reset this tab"), 150, 22, function()
        if not ui.current then return end
        for _, key in ipairs(ui.current.keys) do db()[key] = ns.DEFAULTS[key] end
        changed()
    end)
    ui.reset:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 230, 10)

    local pane = CreateFrame("Frame", nil, p, "BackdropTemplate")
    pane:SetPoint("TOPLEFT", p, "TOPLEFT", PANE_LEFT, SUBTABS_TOP - 28)
    pane:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -4, 4)
    setBackdrop(pane, 0.09, 0.6)
    buildPreview(pane)

    -- Combat hands the display back to the real target, and after combat back to the preview.
    ui.events = CreateFrame("Frame")
    ui.events:SetScript("OnEvent", syncDisplayHost)
    p:HookScript("OnShow", function()
        ui.events:RegisterEvent("PLAYER_REGEN_DISABLED")
        ui.events:RegisterEvent("PLAYER_REGEN_ENABLED")
        ns.setPreviewState(preview)
        ui.previewPaused = nil
        syncDisplayHost()
        refreshControls()
        updatePreview()
        if sub.current == LEARNED_TAB then refreshTicks() end
    end)
    p:HookScript("OnHide", ns.EndPreview)
    sub:Select(1)
    ui.sub = sub
end

-- The tab hidden (or, from Display.lua, its mock frame no longer visible): the display goes back to the real target.
function ns.EndPreview()
    if ui.events then ui.events:UnregisterAllEvents() end
    stopSimulation()
    closeMenu()
    ui.previewPaused = nil
    ns.setPreviewState(nil)
    ns.setDisplayHost(nil)
    ns.setPlatePreview(nil)
    ns.setFocusPreview(nil)
end

-- /wl did ticks: the Learned ticks sub-tab (the tab is opened by ../DoesItDie.lua).
function ns.ShowLearnedTicks()
    if ui.sub then ui.sub:Select(LEARNED_TAB) end
end
