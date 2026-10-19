-- WarLegend RaidTool - PvP
-- Battleground enemy / ally frames: the addon WarLegendRaidTool_PvP (BattleGroundEnemies cleaned up for
-- Forever), loaded on demand when entering a battleground or when this tab is opened. All its settings
-- are here (no separate options window).
local W = WLRT
local L = W.L
local db

local PVP_ADDON = "WarLegendRaidTool_PvP"
local loaded, loadFailed, waitCombat = false, false, false

W.AddFR({
    ["Battleground frames"] = "Cadres de CdB",
    ["Sync"] = "Synchro",
    ["Sync mode: a setting changed in Enemies or Allies applies to both sides."] =
        "Mode synchro : un réglage changé dans Ennemis ou Alliés s'applique aux deux côtés.",
    ["Settings already different stay as they are."] = "Les réglages déjà différents restent tels quels.",
    ["The PvP module is missing or disabled: install the folder WarLegendRaidTool_PvP next to WarLegendRaidTool."] =
        "Le module PvP est absent ou désactivé : installe le dossier WarLegendRaidTool_PvP à côté de WarLegendRaidTool.",
    ["Not in combat: the frames are loaded after the fight."] = "Pas en combat : les cadres seront chargés après le combat.",
    ["Show the enemy and ally frames in battlegrounds"] = "Afficher les cadres des ennemis et des alliés en champ de bataille",
    ["Style:"] = "Style :",
    ["Style: in the Enemies / Allies tabs below."] = "Style : dans les onglets Ennemis / Alliés ci-dessous.",
    ["Flat"] = "Plat",
    ["Text:"] = "Texte :",
    ["Bar color:"] = "Couleur des barres :",
    ["Class"] = "Classe",
    ["One color"] = "Couleur unique",
    ["Click: choose the color of every bar of this side (\"One color\")."] =
        "Clic : choisir la couleur de toutes les barres de ce côté (« Couleur unique »).",
    ["Name in the class color"] = "Nom en couleur de classe",
    ["Border"] = "Bordure",
    ["Shadow"] = "Ombre",
    ["Outline"] = "Contour",
    ["Thick outline"] = "Contour épais",
    ["Smooth"] = "Lisse",
    ["Classic"] = "Classique",
    ["Auto"] = "Auto",
    ["Blizzard"] = "Blizzard",
    ["EllesmereUI is not installed: Blizzard style."] = "EllesmereUI n'est pas installé : style Blizzard.",
    ["Lock the frames (unlocked: drag them to move)"] = "Verrouiller les cadres (déverrouillés : les glisser pour les déplacer)",
    ["Mouse wheel over the frames: previous / next target"] = "Molette sur les cadres : cible précédente / suivante",
    ["Hide the raid frames in battlegrounds"] = "Masquer les cadres de raid en champ de bataille",
    ["Tooltips"] = "Infobulles",
    ["Test mode"] = "Mode test",
    ["Test players:"] = "Joueurs en test :",
    ["Reset"] = "Réinitialiser",
    ["Reset all the battleground frame settings?"] = "Réinitialiser tous les réglages des cadres de champ de bataille ?",
    ["Enemies"] = "Ennemis",
    ["Allies"] = "Alliés",
    ["Show these frames"] = "Afficher ces cadres",
    ["Width:"] = "Largeur :",
    ["Height:"] = "Hauteur :",
    ["Scale:"] = "Échelle :",
    ["Power bar:"] = "Barre d'énergie :",
    ["Height of the power bar (energy, mana, rage) under the health bar. Only on the frames that show it."] =
        "Hauteur de la barre d'énergie (énergie, mana, rage) sous la barre de vie. Seulement sur les cadres qui l'affichent.",
    ["Health in %"] = "Vie en %",
    ["Shown on each player:"] = "Affiché sur chaque joueur :",
    ["The PvP module had an error while loading: see BugSack (/bugsack)."] =
        "Le module PvP a eu une erreur au chargement : voir BugSack (/bugsack).",
    ["PvP check:"] = "Vérif PvP :",
    ["in a battleground"] = "en champ de bataille",
    ["restriction"] = "restriction",
    ["chat lockdown"] = "verrouillage du chat",
    ["last battleground message"] = "dernier message du champ de bataille",
    ["secret"] = "secret",
    ["YES"] = "OUI",
    ["no"] = "non",
    ["not available on this client"] = "pas disponible sur ce client",
    ["no battleground message received since the last /reload"] = "aucun message de champ de bataille reçu depuis le dernier /reload",
    ["Battleground messages"] = "Messages du champ de bataille",
    ["No battleground message recorded yet: play a battleground, then type /wl bgmsg again."] =
        "Aucun message de champ de bataille enregistré : joue un champ de bataille, puis retape /wl bgmsg.",
    ["Out of range: grey"] = "Hors de portée : griser",
    ["Class icon"] = "Icône de classe",
    ["My spells"] = "Mes sorts",
    ["My spells: the range of my main spell, as the action buttons."] =
        "Mes sorts : la portée de mon sort principal, comme les boutons d'action.",
    ["Blizzard: the check of Blizzard's raid frames (allies; my spells for the enemies)."] =
        "Blizzard : la vérification des cadres de raid de Blizzard (alliés ; mes sorts pour les ennemis).",
    ["Range:"] = "Portée :",
    ["Right-click: dispel, middle-click: 2nd dispel (my class)"] = "Clic droit : dissiper, clic milieu : 2e dissipation (ma classe)",
    ["ally auras: %d readable, %d secret"] = "auras des alliés : %d lisibles, %d secrètes",
    ["Not available on WoW Forever: auras, diminishing returns, trinket and racial (enemy data kept secret in battlegrounds)."] =
        "Pas disponible sur WoW Forever : auras, rendements décroissants, bijou et raciaux (infos ennemies secrètes en champ de bataille).",
})

-- Loads the PvP addon now (never in combat: it creates secure frames)
function W.LoadPvP()
    if loaded then return true end
    if loadFailed or not (C_AddOns and C_AddOns.LoadAddOn) then return false end
    if InCombatLockdown() then
        waitCombat = true
        W.Print(L("Not in combat: the frames are loaded after the fight."))
        return false
    end
    local called, ok = W.Measure("load the battleground frames", C_AddOns.LoadAddOn, PVP_ADDON)
    if not called then ok = false end
    if not ok then
        loadFailed = true
        W.Print(L("The PvP module is missing or disabled: install the folder WarLegendRaidTool_PvP next to WarLegendRaidTool."))
        return false
    end
    loaded = true
    return true
end

local function InBattleground()
    local inInstance, kind = IsInInstance()
    return inInstance and kind == "pvp"
end

local function MaybeLoad()
    if not db or not db.enabled or W.access ~= true or loaded then return end
    if not InBattleground() then return end
    if InCombatLockdown() then waitCombat = true; return end
    W.LoadPvP()
end

W.OnReady(function()
    db = W.DB("pvp", { enabled = true, syncSides = false })
    if type(db.bgMessages) ~= "table" then db.bgMessages = {} end
end)
W.On("PLAYER_ENTERING_WORLD", MaybeLoad)
W.On("PLAYER_REGEN_ENABLED", function()
    if waitCombat then waitCombat = false; MaybeLoad() end
end)

-- The queue pops (status "confirm": the "Enter battle" window): the frames are loaded right then, outside, so their
-- first load (about 150 ms, /wl perf) is not paid at the end of the loading screen in the battleground. In combat it
-- waits: entering the battleground still loads them (MaybeLoad above). Off once loaded.
local queueEv
local function QueuePopped(queueId)
    if not GetBattlefieldStatus then return false end
    if queueId then return W.Safe(GetBattlefieldStatus(queueId)) == "confirm" end
    for i = 1, (GetMaxBattlefieldID and W.Safe(GetMaxBattlefieldID())) or 3 do
        if W.Safe(GetBattlefieldStatus(i)) == "confirm" then return true end
    end
    return false
end
queueEv = W.On("UPDATE_BATTLEFIELD_STATUS", function(queueId)
    if loaded or loadFailed then W.Activate(queueEv, false); return end
    if not db or not db.enabled or W.access ~= true or InCombatLockdown() then return end
    if not QueuePopped(W.Safe(queueId)) then return end
    if W.LoadPvP() then W.Activate(queueEv, false) end
end)

W.slash.pvp = function() W.Toggle("PvPFrames") end

-- /wl pvpcheck: are the 12.x addon restrictions active in this battleground? (runs only when typed)
-- C_RestrictedActions.IsAddOnRestrictionActive, C_ChatInfo.InChatMessagingLockdown (warcraft.wiki.gg).
-- The last battleground system message is only noted (secret or not, never read), for the flag carrier.
local lastBGMessage
-- the last readable ones, kept in the saved file (they survive a /reload), for /wl bgmsg
local function BGMessages() return db and db.bgMessages or {} end
local function NoteBGMessage(event)
    return function(text)
        local secret = (issecretvalue and issecretvalue(text)) or (canaccessvalue and not canaccessvalue(text)) or false
        lastBGMessage = { event = event, secret = secret, at = time() }
        if not secret and type(text) == "string" then
            table.insert(BGMessages(), 1, date("%d/%m %H:%M:%S") .. "  " .. event:gsub("CHAT_MSG_BG_SYSTEM_", "") .. "  " .. text)
            while #BGMessages() > 40 do table.remove(BGMessages()) end
        end
    end
end
W.On("CHAT_MSG_BG_SYSTEM_HORDE", NoteBGMessage("CHAT_MSG_BG_SYSTEM_HORDE"))
W.On("CHAT_MSG_BG_SYSTEM_ALLIANCE", NoteBGMessage("CHAT_MSG_BG_SYSTEM_ALLIANCE"))
W.On("CHAT_MSG_BG_SYSTEM_NEUTRAL", NoteBGMessage("CHAT_MSG_BG_SYSTEM_NEUTRAL"))

-- /wl bgmsg: the last battleground messages, to copy (to add the flag texts of a new battleground)
W.slash.bgmsg = function()
    local list = BGMessages()
    W.TextPopup(L("Battleground messages"), #list > 0 and table.concat(list, "\n")
        or L("No battleground message recorded yet: play a battleground, then type /wl bgmsg again."), { hint = "Ctrl+C" })
end

local function Answer(value)
    if value == nil then return L("not available on this client") end
    if issecretvalue and issecretvalue(value) then return L("secret") end
    return value and L("YES") or L("no")
end

W.slash.pvpcheck = function()
    local inInstance, kind = IsInInstance()
    W.Print(L("PvP check:") .. " " .. L("in a battleground") .. " = " .. Answer(inInstance and kind == "pvp"))
    local types = Enum and Enum.AddOnRestrictionType
    local isActive = C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive
    if types and isActive then
        for _, name in ipairs({ "PvPMatch", "Combat", "Map", "Chat" }) do
            if types[name] then
                W.Print("  " .. L("restriction") .. " " .. name .. " = " .. Answer(isActive(types[name])))
            end
        end
    else
        W.Print("  C_RestrictedActions: " .. L("not available on this client"))
    end
    local lockdown
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then lockdown = C_ChatInfo.InChatMessagingLockdown() end
    W.Print("  " .. L("chat lockdown") .. " = " .. Answer(lockdown))
    -- auras of my team (the ally frames show them only when readable)
    local readable, secret = 0, 0
    local units = W.InRaid() and { "raid1", "raid2", "raid3", "raid4", "raid5" } or { "player" }
    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
                for i = 1, 40 do
                    local a = W.AuraByIndex(unit, i, filter)
                    if a == nil then break end
                    if a then readable = readable + 1 else secret = secret + 1 end
                    if secret >= 40 then break end
                end
            end
        end
    end
    W.Print("  " .. string.format(L("ally auras: %d readable, %d secret"), readable, secret))
    if lastBGMessage then
        W.Print("  " .. L("last battleground message") .. " (" .. date("%H:%M:%S", lastBGMessage.at) .. ") " ..
            L("secret") .. " = " .. Answer(lastBGMessage.secret))
    else
        W.Print("  " .. L("no battleground message received since the last /reload"))
    end
end

-- value lists of the cycle buttons
local STYLES = { { "auto", "Auto" }, { "eui", "EllesmereUI" }, { "blizzard", "Blizzard" }, { "flat", "Flat" },
    { "smooth", "Smooth" }, { "classic", "Classic" } }
local WIDTHS, HEIGHTS, SCALES, POWER_HEIGHTS = {}, {}, {}, {}
for _, v in ipairs({ 3, 5, 8, 10, 12, 14 }) do POWER_HEIGHTS[#POWER_HEIGHTS + 1] = { v, tostring(v) } end
for _, v in ipairs({ 140, 160, 180, 200, 220, 240, 260 }) do WIDTHS[#WIDTHS + 1] = { v, tostring(v) } end
for _, v in ipairs({ 18, 22, 26, 28, 32, 38, 47 }) do HEIGHTS[#HEIGHTS + 1] = { v, tostring(v) } end
for _, v in ipairs({ 0.8, 0.9, 1, 1.1, 1.2, 1.3 }) do SCALES[#SCALES + 1] = { v, tostring(v) } end
local RANGES = {}
for _, v in ipairs({ 10, 20, 30, 40 }) do RANGES[#RANGES + 1] = { v, v .. " m" } end
-- the game's own checks (WarLegendRaidTool_PvP GameRangeCheck); labels translated when the tab is built
RANGES[#RANGES + 1] = { "spell", "My spells" }
RANGES[#RANGES + 1] = { "blizzard", "Blizzard" }

-- The game's color picker. Blizzard's new way (SetupColorPickerAndShow) when the client has it, else the
-- old fields of ColorPickerFrame. onChange(r, g, b) on every change, and with the old color on cancel.
local function PickColor(r, g, b, onChange)
    local CPF = ColorPickerFrame
    if not CPF then return end
    local function current()
        local ok, nr, ng, nb = pcall(CPF.GetColorRGB, CPF)
        if ok and nr then onChange(nr, ng, nb) end
    end
    if CPF.SetupColorPickerAndShow then
        CPF:SetupColorPickerAndShow({ r = r, g = g, b = b, hasOpacity = false,
            swatchFunc = current, cancelFunc = function() onChange(r, g, b) end })
    else
        CPF.hasOpacity = false
        CPF.previousValues = { r, g, b }
        CPF.func = current
        CPF.cancelFunc = function() onChange(r, g, b) end
        CPF:SetColorRGB(r, g, b)
        CPF:Hide()
        CPF:Show()
    end
end

-- the frames of one side (Enemies / Allies)
local function BuildSide(f, pvp, side)
    -- sync mode: a change goes to both sides (the other tab rereads its values on show); the dispel click
    -- exists only for the allies
    local other = side == "Enemies" and "Allies" or "Enemies"
    local function Set(key, v, moduleName)
        pvp:SetSideSetting(side, key, v, moduleName)
        if db.syncSides and key ~= "ClickDispel" then
            if type(v) == "table" then v = { v[1], v[2], v[3] } end -- the bar color: one table per side
            pvp:SetSideSetting(other, key, v, moduleName)
        end
    end
    W.Check(f, L("Show these frames"), function() return pvp:GetSideSetting(side, "Enabled") end,
        function(v) Set("Enabled", v) end):SetPoint("TOPLEFT", 12, -4)
    -- style of this side
    W.Label(f, L("Style:"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 236, -9)
    local styles = {}
    for _, s in ipairs(STYLES) do styles[#styles + 1] = { s[1], L(s[2]) } end
    W.Cycle(f, 120, styles, function() return pvp:GetSideSetting(side, "Style") end,
        function(v) Set("Style", v) end):SetPoint("TOPLEFT", 290, -4)
    -- edge of the texts: shadow (smooth) or the game's outline (sharper, a bit pixelated)
    W.Label(f, L("Text:"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 424, -9)
    W.Cycle(f, 120, { { "shadow", L("Shadow") }, { "outline", L("Outline") }, { "thick", L("Thick outline") } },
        function() return pvp:GetSideSetting(side, "TextOutline") end,
        function(v) Set("TextOutline", v) end):SetPoint("TOPLEFT", 464, -4)

    local rows = { { L("Width:"), "Width", WIDTHS }, { L("Height:"), "Height", HEIGHTS }, { L("Scale:"), "Scale", SCALES },
        { L("Power bar:"), "PowerHeight", POWER_HEIGHTS,
            L("Height of the power bar (energy, mana, rage) under the health bar. Only on the frames that show it.") } }
    for i, row in ipairs(rows) do
        local x = 16 + (i - 1) * 140
        W.Label(f, row[1], "GameFontHighlightSmall"):SetPoint("TOPLEFT", x, -38)
        W.Cycle(f, 64, row[3], function() return pvp:GetSideSetting(side, row[2]) end,
            function(v) Set(row[2], v) end, row[4] and { row[4] } or nil):SetPoint("TOPLEFT", x + 58, -33)
    end

    W.Check(f, L("Health in %"), function() return pvp:GetSideSetting(side, "HealthText") end,
        function(v) Set("HealthText", v) end):SetPoint("TOPLEFT", 12, -62)
    if side == "Allies" and pvp.GetDispelSpell then
        W.Check(f, L("Right-click: dispel, middle-click: 2nd dispel (my class)"),
            function() return pvp:GetSideSetting(side, "ClickDispel") end,
            function(v) Set("ClickDispel", v) end):SetPoint("TOPLEFT", 220, -62)
    end

    -- out of range: grey, and the distance it is checked at
    W.Check(f, L("Out of range: grey"), function() return pvp:GetSideSetting(side, "RangeDesat") end,
        function(v) Set("RangeDesat", v) end):SetPoint("TOPLEFT", 12, -86)
    W.Label(f, L("Range:"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 236, -92)
    local ranges = {}
    for _, r in ipairs(RANGES) do ranges[#ranges + 1] = { r[1], type(r[1]) == "string" and L(r[2]) or r[2] } end
    W.Cycle(f, 84, ranges, function() return pvp:GetSideSetting(side, "Range") end,
        function(v) Set("Range", v) end, { L("My spells: the range of my main spell, as the action buttons."),
            L("Blizzard: the check of Blizzard's raid frames (allies; my spells for the enemies).") }):SetPoint("TOPLEFT", 290, -87)
    -- the class / spec icon (on the right of the ally frames: the debuffs then stick to the bar)
    W.Check(f, L("Class icon"), function() return pvp:GetSideSetting(side, "Modules", "SpecClassPriorityOne") end,
        function(v) Set("Modules", v, "SpecClassPriorityOne") end):SetPoint("TOPLEFT", 392, -86)

    -- health bar color: class color, or one color for every player of this side (color picker), and the name
    -- in the class color
    W.Label(f, L("Bar color:"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 16, -116)
    W.Cycle(f, 90, { { "class", L("Class") }, { "custom", L("One color") } },
        function() return pvp:GetSideSetting(side, "BarColorMode") end,
        function(v) Set("BarColorMode", v) end):SetPoint("TOPLEFT", 134, -111)
    local swatch = CreateFrame("Button", nil, f, W.BT)
    W.Size(swatch, 22, 18)
    swatch:SetPoint("TOPLEFT", 230, -113)
    W.Backdrop(swatch, 1, true)
    swatch.color = swatch:CreateTexture(nil, "ARTWORK")
    swatch.color:SetPoint("TOPLEFT", 2, -2)
    swatch.color:SetPoint("BOTTOMRIGHT", -2, 2)
    swatch.color:SetTexture(W.WHITE)
    local function ShowSwatch()
        local c = pvp:GetSideSetting(side, "BarColor")
        swatch.color:SetVertexColor(c[1], c[2], c[3], 1)
    end
    swatch:SetScript("OnShow", ShowSwatch)
    swatch:SetScript("OnClick", function()
        local c = pvp:GetSideSetting(side, "BarColor")
        PickColor(c[1], c[2], c[3], function(r, g, b)
            Set("BarColor", { r, g, b })
            ShowSwatch()
        end)
    end)
    W.Tooltip(swatch, L("Bar color:"), { L("Click: choose the color of every bar of this side (\"One color\").") })
    W.Check(f, L("Name in the class color"), function() return pvp:GetSideSetting(side, "NameClassColor") end,
        function(v) Set("NameClassColor", v) end):SetPoint("TOPLEFT", 270, -110)
    -- the 1 px black frame around each player (by default: as the style)
    W.Check(f, L("Border"), function() return pvp:GetSideSetting(side, "Border") end,
        function(v) Set("Border", v) end):SetPoint("TOPLEFT", 460, -110)

    W.Label(f, L("Shown on each player:"), "GameFontNormalSmall"):SetPoint("TOPLEFT", 16, -142)
    for i, moduleName in ipairs(pvp.ToggleableModules) do
        local module = pvp.ButtonModules[moduleName]
        if module then
            local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
            W.Check(f, module.localizedModuleName or moduleName,
                function() return pvp:GetSideSetting(side, "Modules", moduleName) end,
                function(v) Set("Modules", v, moduleName) end
            ):SetPoint("TOPLEFT", 12 + col * 220, -158 - row * 24)
        end
    end
end

-- test mode of the frames: on / off, and off by itself after 30 seconds (a newer test keeps its own stop)
local testRun = 0
local function ToggleTest(onlyStart)
    local pvp = WarLegendPvP
    if not (pvp and pvp.ToggleTestmode and pvp.states) then return end
    if pvp.states.testmodeActive then
        if not onlyStart then pvp.ToggleTestmode() end
        return
    end
    pvp.ToggleTestmode()
    testRun = testRun + 1
    local run = testRun
    W.After(30, function()
        if run == testRun and pvp.states.testmodeActive and not InCombatLockdown() then pvp.ToggleTestmode() end
    end)
end
W.RegisterTest("Battleground frames", function() return db and db.enabled and not InCombatLockdown() end,
    function() if W.LoadPvP() then ToggleTest(true) end end,
    function()
        local pvp = WarLegendPvP
        testRun = testRun + 1
        if pvp and pvp.states and pvp.states.testmodeActive and not InCombatLockdown() then pvp.ToggleTestmode() end
    end)

W.RegisterModule("PvPFrames", "Battleground frames", function(p)
    W.Title(p, L("Battleground frames"))
    if not W.LoadPvP() or not WarLegendPvP or not WarLegendPvP.db then
        local why
        if loadFailed then
            why = L("The PvP module is missing or disabled: install the folder WarLegendRaidTool_PvP next to WarLegendRaidTool.")
        elseif InCombatLockdown() then
            why = L("Not in combat: the frames are loaded after the fight.") .. " (/reload)"
        else
            why = L("The PvP module had an error while loading: see BugSack (/bugsack).")
        end
        local label = W.Label(p, why, "GameFontDisable")
        label:SetPoint("TOPLEFT", 16, -44)
        label:SetWidth(440)
        return
    end
    local pvp = WarLegendPvP

    W.Check(p, L("Show the enemy and ally frames in battlegrounds"), function() return db.enabled end,
        function(v)
            db.enabled = v
            pvp:SetSetting("ShowBGEInBattleground", v)
            MaybeLoad()
        end):SetPoint("TOPLEFT", 12, -40)

    -- the style is chosen per side, in the Enemies / Allies tabs below
    W.Label(p, L("Style: in the Enemies / Allies tabs below."), "GameFontDisableSmall"):SetPoint("TOPLEFT", 16, -72)
    if not pvp:HasEllesmereUI() then
        W.Label(p, L("EllesmereUI is not installed: Blizzard style."), "GameFontDisableSmall"):SetPoint("TOPLEFT", 340, -72)
    end

    local checks = {
        { L("Lock the frames (unlocked: drag them to move)"), "Locked" },
        { L("Mouse wheel over the frames: previous / next target"), "EnableMouseWheelPlayerTargeting" },
        { L("Hide the raid frames in battlegrounds"), "DisableRaidFramesInBattleground" },
        { L("Tooltips"), "ShowTooltips" },
    }
    for i, c in ipairs(checks) do
        W.Check(p, c[1], function() return pvp:GetSetting(c[2]) end,
            function(v) pvp:SetSetting(c[2], v) end):SetPoint("TOPLEFT", 12, -92 - (i - 1) * 24)
    end

    W.Button(p, L("Test mode"), 110, 22, function() ToggleTest() end):SetPoint("TOPLEFT", 16, -192)
    W.Button(p, L("Reset"), 110, 22, function()
        W.Confirm(L("Reset all the battleground frame settings?"), function()
            pvp:ResetSettings()
            if p:IsShown() then p:Hide(); p:Show() end -- the checkboxes sync on show
        end)
    end):SetPoint("TOPLEFT", 132, -192)

    -- test mode player count (1 to 40, the BattleGroundEnemies slider): - / + and quick sizes
    W.Label(p, L("Test players:"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 262, -197)
    local count = W.Label(p, "", "GameFontHighlight")
    count:SetPoint("TOPLEFT", 386, -196)
    count:SetWidth(30)
    count:SetJustifyH("CENTER")
    local function ShowCount() count:SetText(pvp:GetTestPlayerCount()) end
    local function Change(value)
        pvp:SetTestPlayerCount(value)
        ShowCount()
    end
    W.Button(p, "-", 26, 22, function() Change(pvp:GetTestPlayerCount() - 1) end):SetPoint("TOPLEFT", 358, -192)
    W.Button(p, "+", 26, 22, function() Change(pvp:GetTestPlayerCount() + 1) end):SetPoint("TOPLEFT", 418, -192)
    for i, size in ipairs({ 10, 15, 20, 40 }) do
        W.Button(p, tostring(size), 34, 22, function() Change(size) end):SetPoint("TOPLEFT", 452 + (i - 1) * 38, -192)
    end
    ShowCount()
    p:HookScript("OnShow", ShowCount) -- after a reset, or a change made elsewhere

    local tabs = W.SubTabs(p, { L("Enemies"), L("Allies") }, nil, -224)
    -- sync mode, on the left of the sub-tabs: they move right to make room
    W.Check(p, L("Sync"), function() return db.syncSides end, function(v) db.syncSides = v end,
        { L("Sync mode: a setting changed in Enemies or Allies applies to both sides."),
            L("Settings already different stay as they are.") }):SetPoint("TOPLEFT", 8, -223)
    local x = 104
    for _, b in ipairs(tabs.buttons) do
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", x, -224)
        x = x + b:GetWidth() + 4
    end
    BuildSide(tabs.frames[1], pvp, "Enemies")
    BuildSide(tabs.frames[2], pvp, "Allies")
    tabs:Select(1)

    local note = W.Label(p, L("Not available on WoW Forever: auras, diminishing returns, trinket and racial (enemy data kept secret in battlegrounds)."), "GameFontDisableSmall")
    note:SetPoint("BOTTOMLEFT", 16, 10)
    note:SetWidth(440)
end)
