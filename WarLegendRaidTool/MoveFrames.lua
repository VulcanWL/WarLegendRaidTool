-- WarLegend RaidTool - Move frames
-- The safe part of MoveAny: drag Blizzard's windows (out of combat, never a protected one), move a few
-- screen elements EllesmereUI does not handle, place the tooltip, a small FPS / latency display.
-- Action bars, unit / group frames, buffs and the minimap are left alone: they are secure frames,
-- EllesmereUI moves them already, and moving them from an addon is what gives MoveAny its
-- "action blocked" errors. Everything here is off until ticked, and the module can be switched off.
local W = WLRT
W.AddFR({
    ["Move frames"] = "Déplacer les cadres",
    ["Move Blizzard windows with the mouse (out of combat)"] = "Déplacer les fenêtres Blizzard à la souris (hors combat)",
    ["Remember their place and size:"] = "Retenir leur place et leur taille :",
    ["Never"] = "Jamais",
    ["Until /reload"] = "Jusqu'au /reload",
    ["Always"] = "Toujours",
    ["Window reset: close and open it again to put it back in its place."] =
        "Fenêtre remise à zéro : ferme-la et rouvre-la pour la remettre à sa place.",
    ["Drag a window by an empty spot (edge, title). Ctrl + mouse wheel on it: its size. Ctrl + right-click: reset it. Protected windows are never touched."] =
        "Fais glisser une fenêtre par un endroit vide (bord, titre). Ctrl + molette dessus : sa taille. Ctrl + clic droit : la remettre à zéro. Les fenêtres protégées ne sont jamais touchées.",
    ["Reset the windows"] = "Réinitialiser les fenêtres",
    ["Move screen elements (error text, zone text, battleground score...)"] = "Déplacer des éléments d'écran (texte d'erreur, texte de zone, score du BG...)",
    ["Tooltip:"] = "Infobulle :",
    ["Default"] = "Par défaut",
    ["At the cursor"] = "Au curseur",
    ["At its anchor"] = "À son ancre",
    ["Also in combat"] = "Aussi en combat",
    ["FPS and latency"] = "FPS et latence",
    ["Unlock (show the movers)"] = "Déverrouiller (montrer les cadres)",
    ["Lock"] = "Verrouiller",
    ["Reset the elements"] = "Réinitialiser les éléments",
    ["The elements go back to Blizzard's place after a reload."] = "Les éléments reprennent la place de Blizzard après un rechargement.",
    ["Not moved here: action bars, unit and group frames, buffs, minimap. EllesmereUI does it, and moving them from an addon gives the \"action blocked\" errors."] =
        "Pas déplacés ici : barres d'action, cadres d'unité et de groupe, buffs, minicarte. EllesmereUI s'en charge, et les déplacer depuis un addon donne les erreurs « action bloquée ».",
    ["Unticked, an element keeps its place until the next /reload."] = "Décoché, un élément garde sa place jusqu'au prochain /reload.",
    ["Error text (red)"] = "Texte d'erreur (rouge)",
    ["Zone text"] = "Texte de zone",
    ["Sub-zone text"] = "Texte de sous-zone",
    ["Raid warnings"] = "Avertissements de raid",
    ["Boss emotes"] = "Emotes de boss",
    ["Breath / fatigue bars"] = "Barres de souffle / fatigue",
    ["Battleground score (top)"] = "Score du BG (en haut)",
    ["Capture bar (below the minimap)"] = "Barre de capture (sous la minicarte)",
    ["Durability figure"] = "Bonhomme de durabilité",
    ["Tooltip"] = "Infobulle",
    ["Drag the boxes, then Lock."] = "Fais glisser les cadres, puis Verrouiller.",
})
local L = W.L
local db

W.OnReady(function()
    db = W.DB("moveFrames", { windows = false, winMemory = "never", elements = false, tooltip = "default", tooltipCombat = false, fps = false })
    if type(db.winPos) ~= "table" then db.winPos = {} end
    if type(db.winScale) ~= "table" then db.winScale = {} end
    if type(db.elemPos) ~= "table" then db.elemPos = {} end
    if type(db.point) ~= "table" then db.point = { "TOPLEFT", "TOPLEFT", 10, -10 } end
    if type(db.tipPoint) ~= "table" then db.tipPoint = { "BOTTOMRIGHT", "BOTTOMRIGHT", -80, 160 } end
end)

-- an option is used only while the module is on (Settings > Modules) and the player allowed; the windows also only
-- while no other addon moves them (EllesmereUI's window mover, see Overlap.lua)
local function Use(opt)
    return db and db[opt] and W.Allowed() and not W.IsOff("MoveFrames") and not (opt == "windows" and W.Overlap("moveFrames"))
end

---------------------------------------------------------------------------
-- Blizzard windows. Hooks only (HookScript, never SetScript over Blizzard's), out of combat, and a
-- window the game marks protected is skipped. Without "remember", the game puts it back at its next opening.
---------------------------------------------------------------------------
local WINDOWS = { "CharacterFrame", "SpellBookFrame", "PlayerTalentFrame", "QuestLogFrame", "FriendsFrame", "MerchantFrame",
    "GossipFrame", "QuestFrame", "TradeSkillFrame", "CraftFrame", "ProfessionsFrame", "ClassTrainerFrame", "BankFrame",
    "MailFrame", "OpenMailFrame", "AuctionFrame", "AuctionHouseFrame", "TaxiFrame", "DressUpFrame", "TradeFrame", "InspectFrame",
    "MacroFrame", "KeyBindingFrame", "PVPFrame", "PVPParentFrame", "BattlefieldFrame", "WorldStateScoreFrame", "LFGParentFrame",
    "PVEFrame", "TimeManagerFrame", "AddonList", "ItemTextFrame", "PetStableFrame", "TabardFrame", "HelpFrame", "GuildBankFrame",
    "ItemSocketingFrame", "CalendarFrame", "ChannelFrame", "CommunitiesFrame", "CollectionsJournal", "EncounterJournal",
    "AchievementFrame", "GuildControlUI", "GuildRegistrarFrame", "PetitionFrame",
    -- seen in BlizzMove's list for this kind of client; a frame this client does not have, or a protected one, is skipped.
    -- Not here: the loot windows, the game puts them back at the cursor / in a stack each time.
    "GameMenuFrame", "ReadyCheckFrame", "ContainerFrame1", "ContainerFrameCombinedBags", "SettingsPanel",
    "QuestLogPopupDetailFrame", "ChatConfigFrame", "TalkingHeadFrame", "QuickKeybindFrame", "GuildInviteFrame",
    -- WoW Forever's own windows (its UI source): talents and spellbook, stable, Legacy, social window
    "PlayerSpellsFrame", "StableFrame", "LegacySystemFrame", "SocialUIFrame" }

local hooked, moving, panelHook = {}, nil, false

-- Where a window's place and size are kept: "never", "session" (until the next /reload) or "always" (saved)
local sessPos, sessScale = {}, {}
local function Memory()
    local m = db and db.winMemory
    if m == "session" or m == "always" then return m end
    return "never"
end
local function PosOf(name)
    local m = Memory()
    if m == "always" then return db.winPos[name], db.winScale[name] end
    if m == "session" then return sessPos[name], sessScale[name] end
end

local function Restore(f, name)
    if not Use("windows") or Memory() == "never" or InCombatLockdown() then return end
    local p, s = PosOf(name)
    if s then f:SetScale(s) end
    if p then
        f:ClearAllPoints()
        f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    end
end

local wheeled = {} -- [name] = window whose wheel script is ours
local function HookWindow(name)
    local f = _G[name]
    if hooked[name] or type(f) ~= "table" or type(f.StartMoving) ~= "function" or type(f.HookScript) ~= "function" then return end
    if f:IsProtected() then return end -- secure, or holds secure buttons: moved by an addon it breaks in combat
    hooked[name] = true
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:HookScript("OnMouseDown", function(self, button)
        if not Use("windows") or InCombatLockdown() then return end
        if button == "RightButton" then
            -- Ctrl + right-click: size back to 1 and the kept place forgotten (the game puts it back when it opens again)
            if IsControlKeyDown() then
                self:SetScale(1)
                db.winScale[name], db.winPos[name], sessScale[name], sessPos[name] = nil, nil, nil, nil
                W.Print(L("Window reset: close and open it again to put it back in its place."))
            end
            return
        end
        if button ~= "LeftButton" then return end
        moving = self
        self:StartMoving()
    end)
    f:HookScript("OnMouseUp", function(self)
        if moving ~= self then return end
        moving = nil
        self:StopMovingOrSizing()
        if self.SetUserPlaced then self:SetUserPlaced(false) end -- not kept by the game itself (layout-local.txt)
        local point, _, rel, x, y = self:GetPoint()
        local mode = Memory()
        if point and mode == "always" then db.winPos[name] = { point, rel, x, y }
        elseif point and mode == "session" then sessPos[name] = { point, rel, x, y } end
    end)
    f:HookScript("OnHide", function(self)
        if moving == self then moving = nil; self:StopMovingOrSizing() end
    end)
    -- the game places a window when it opens: ours goes after it
    f:HookScript("OnShow", function(self) W.After(0, function() Restore(self, name) end) end)
    -- Ctrl + mouse wheel: its size (only on a window that has no wheel script of its own)
    -- the wheel is caught (no camera zoom over the window) only while the option is on, see SetWheels
    if not f:GetScript("OnMouseWheel") then
        wheeled[name] = f
        f:EnableMouseWheel(true)
        f:SetScript("OnMouseWheel", function(self, delta)
            if not IsControlKeyDown() or not Use("windows") or InCombatLockdown() then return end
            local s = math.max(0.5, math.min(1.5, (self:GetScale() or 1) + delta * 0.05))
            s = math.floor(s * 100 + 0.5) / 100
            self:SetScale(s)
            local mode = Memory()
            if mode == "always" then db.winScale[name] = (s ~= 1) and s or nil
            elseif mode == "session" then sessScale[name] = (s ~= 1) and s or nil end
        end)
    end
end

local function SetWheels(on)
    for _, f in pairs(wheeled) do f:EnableMouseWheel(on) end
end

local pendingHook = false
local function HookAll()
    if not Use("windows") then return end
    if InCombatLockdown() then pendingHook = true; return end
    for _, name in ipairs(WINDOWS) do HookWindow(name) end
    -- opening another window moves the open ones: the remembered places are put back after
    if not panelHook and hooksecurefunc and type(UpdateUIPanelPositions) == "function" then
        panelHook = true
        hooksecurefunc("UpdateUIPanelPositions", function()
            if not Use("windows") or Memory() == "never" or InCombatLockdown() then return end
            for name in pairs(hooked) do
                local f = _G[name]
                if f and f:IsShown() and PosOf(name) then Restore(f, name) end
            end
        end)
    end
end

---------------------------------------------------------------------------
-- Screen elements: each one moved follows a box (its mover). Blizzard keeps placing them: a hook on
-- their SetPoint puts them back on the box. Only an element the player moved is touched.
---------------------------------------------------------------------------
local ELEMENTS = {
    { "UIErrorsFrame", "Error text (red)" },
    { "ZoneTextFrame", "Zone text" },
    { "SubZoneTextFrame", "Sub-zone text" },
    { "RaidWarningFrame", "Raid warnings" },
    { "RaidBossEmoteFrame", "Boss emotes" },
    { "MirrorTimerContainer", "Breath / fatigue bars" }, -- newer clients
    { "MirrorTimer1", "Breath / fatigue bars" },         -- older ones (skipped when the container exists)
    { "UIWidgetTopCenterContainerFrame", "Battleground score (top)" },
    { "UIWidgetBelowMinimapContainerFrame", "Capture bar (below the minimap)" },
    { "DurabilityFrame", "Durability figure" },
}

local movers, anchoring, hookedEl = {}, {}, {}
local unlocked = false

local function Usable(name)
    local f = _G[name]
    if type(f) ~= "table" or type(f.SetPoint) ~= "function" or f:IsProtected() then return nil end
    if name == "MirrorTimer1" and _G.MirrorTimerContainer then return nil end
    return f
end

local function Anchor(name)
    local f, m = Usable(name), movers[name]
    if not f or not m or not db.elemPos[name] or not Use("elements") then return end
    anchoring[name] = true
    f:ClearAllPoints()
    f:SetPoint("CENTER", m, "CENTER", 0, 0)
    anchoring[name] = nil
end

local function PlaceMover(name)
    local m, p = movers[name], db.elemPos[name]
    m:ClearAllPoints()
    if p then m:SetPoint("CENTER", UIParent, "BOTTOMLEFT", p[1], p[2])
    else m:SetPoint("CENTER", _G[name], "CENTER", 0, 0) end
end

local function Mover(name, label)
    if movers[name] then return movers[name] end
    local f = _G[name]
    local m = CreateFrame("Frame", nil, UIParent, W.BT)
    local w, h = f:GetWidth() or 0, f:GetHeight() or 0
    W.Size(m, math.max(140, math.min(w > 1 and w or 220, 520)), math.max(24, math.min(h > 1 and h or 32, 160)))
    W.Backdrop(m, 0.55)
    m:SetFrameStrata("DIALOG")
    m:SetClampedToScreen(true)
    m:SetMovable(true)
    m:EnableMouse(true)
    m:RegisterForDrag("LeftButton")
    m.text = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    m.text:SetPoint("CENTER")
    m.text:SetText(L(label))
    m:SetScript("OnDragStart", function(self) self:StartMoving() end)
    m:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        if not x then return end
        db.elemPos[name] = { math.floor(x + 0.5), math.floor(y + 0.5) }
        PlaceMover(name) -- on UIParent before the element is put on it (no loop of anchors)
        Anchor(name)
    end)
    m:Hide()
    movers[name] = m
    PlaceMover(name)
    return m
end

local function SetupElements()
    if not Use("elements") then return end
    for _, e in ipairs(ELEMENTS) do
        local name = e[1]
        local f = Usable(name)
        if f then
            Mover(name, e[2])
            if not hookedEl[name] and hooksecurefunc then
                hookedEl[name] = true
                hooksecurefunc(f, "SetPoint", function()
                    if anchoring[name] or not db.elemPos[name] then return end
                    Anchor(name)
                end)
            end
            Anchor(name)
        end
    end
end

---------------------------------------------------------------------------
-- Tooltip: at the cursor, or at an anchor box. Out of combat only unless asked: the game's own unit
-- frames show it in combat and the less we touch it there, the better.
---------------------------------------------------------------------------
local tipAnchor, tipHook = nil, false

local function TipAnchor()
    if tipAnchor then return tipAnchor end
    tipAnchor = CreateFrame("Frame", "WLRTTooltipAnchor", UIParent, W.BT)
    W.Size(tipAnchor, 180, 70)
    tipAnchor:SetClampedToScreen(true)
    tipAnchor:SetMovable(true)
    tipAnchor:RegisterForDrag("LeftButton")
    W.Backdrop(tipAnchor, 0.55)
    tipAnchor.text = tipAnchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tipAnchor.text:SetPoint("CENTER")
    tipAnchor.text:SetText(L("Tooltip"))
    tipAnchor:Hide()
    tipAnchor:SetScript("OnDragStart", function(self) self:StartMoving() end)
    tipAnchor:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, rel, x, y = self:GetPoint()
        if point then db.tipPoint = { point, rel, x, y } end
    end)
    local p = db.tipPoint
    tipAnchor:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    return tipAnchor
end

local function HookTooltip()
    if tipHook or not hooksecurefunc or type(GameTooltip_SetDefaultAnchor) ~= "function" then return end
    tipHook = true
    hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
        if tooltip ~= GameTooltip or not db or db.tooltip == "default" or W.IsOff("MoveFrames") or not W.Allowed() then return end
        if InCombatLockdown() and not db.tooltipCombat then return end
        if db.tooltip == "cursor" then
            tooltip:SetOwner(parent or UIParent, "ANCHOR_CURSOR")
        elseif db.tooltip == "anchor" then
            tooltip:ClearAllPoints()
            tooltip:SetPoint("BOTTOMRIGHT", TipAnchor(), "BOTTOMRIGHT", 0, 0)
        end
    end)
end

---------------------------------------------------------------------------
-- FPS and latency (one update a second, only while shown)
---------------------------------------------------------------------------
local fpsFrame, fpsTicker

local function FpsUpdate()
    local _, _, home, world = GetNetStats()
    local ms = math.max(tonumber(home) or 0, tonumber(world) or 0)
    fpsFrame.text:SetText(string.format("|cff3fc7ebFPS|r %d   |cff3fc7ebms|r %d", math.floor((GetFramerate() or 0) + 0.5), ms))
end

local function SetupFps()
    local want = Use("fps") and true or false
    if want and not fpsFrame then
        fpsFrame = CreateFrame("Frame", "WLRTFps", UIParent)
        W.Size(fpsFrame, 130, 20)
        fpsFrame:SetFrameStrata("MEDIUM")
        fpsFrame:SetClampedToScreen(true)
        fpsFrame:SetMovable(true)
        fpsFrame:RegisterForDrag("LeftButton")
        -- the box shown while unlocked (a backdrop of its own: the skins cannot take one away)
        fpsFrame.box = CreateFrame("Frame", nil, fpsFrame, W.BT)
        fpsFrame.box:SetAllPoints()
        fpsFrame.box:SetFrameLevel(fpsFrame:GetFrameLevel())
        W.Backdrop(fpsFrame.box, 0.55)
        fpsFrame.box:Hide()
        fpsFrame.text = fpsFrame:CreateFontString(nil, "OVERLAY")
        W.SetFont(fpsFrame.text, W.FONT, 12, "OUTLINE")
        fpsFrame.text:SetPoint("CENTER")
        fpsFrame:SetScript("OnDragStart", function(self) if unlocked then self:StartMoving() end end)
        fpsFrame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local point, _, rel, x, y = self:GetPoint()
            if point then db.point = { point, rel, x, y } end
        end)
        local p = db.point
        fpsFrame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    end
    if not fpsFrame then return end
    fpsFrame:SetShown(want)
    if want and not fpsTicker and C_Timer and C_Timer.NewTicker then
        FpsUpdate()
        fpsTicker = C_Timer.NewTicker(1, FpsUpdate)
    elseif not want and fpsTicker then
        fpsTicker:Cancel()
        fpsTicker = nil
    end
end

---------------------------------------------------------------------------
-- Unlock: the boxes of the elements, the tooltip anchor and the FPS frame can be dragged
---------------------------------------------------------------------------
local unlockButton
local function SetUnlocked(on)
    unlocked = on and true or false
    if unlocked then SetupElements() end
    for name, m in pairs(movers) do m:SetShown(unlocked and Use("elements") and Usable(name) ~= nil) end
    if db and db.tooltip == "anchor" or tipAnchor then
        local a = TipAnchor()
        a:EnableMouse(unlocked)
        a:SetShown(unlocked and db.tooltip == "anchor")
    end
    if fpsFrame then
        fpsFrame:EnableMouse(unlocked)
        fpsFrame.box:SetShown(unlocked)
    end
    if unlockButton then unlockButton:SetText(unlocked and L("Lock") or L("Unlock (show the movers)")) end
end

local function Setup()
    HookAll()
    SetupElements()
    if db and db.tooltip ~= "default" then HookTooltip() end
    SetupFps()
end

W.On("PLAYER_ENTERING_WORLD", Setup)
W.On("ADDON_LOADED", function() if Use("windows") then HookAll() end end) -- Blizzard's windows loaded on demand
W.On("PLAYER_REGEN_ENABLED", function() if pendingHook then pendingHook = false; HookAll() end end)
W.On("PLAYER_REGEN_DISABLED", function() if unlocked then SetUnlocked(false) end end)

-- "Test all": the boxes for 30 seconds (a newer test keeps its own stop)
local testRun = 0
W.RegisterTest("Move frames", function() return Use("elements") or Use("fps") or (db and db.tooltip == "anchor") end,
    function()
        if InCombatLockdown() then return end
        SetUnlocked(true)
        testRun = testRun + 1
        local run = testRun
        W.After(30, function() if run == testRun and unlocked then SetUnlocked(false) end end)
    end,
    function() testRun = testRun + 1; if unlocked then SetUnlocked(false) end end)

W.RegisterModule("MoveFrames", "Move frames", function(p)
    W.Title(p, L("Move frames"))
    W.Check(p, L("Move Blizzard windows with the mouse (out of combat)"), function() return db.windows end,
        function(v) db.windows = v; SetWheels(v and true or false); if v then HookAll() end end):SetPoint("TOPLEFT", 12, -40)
    W.OverlapNote(p, "moveFrames", "TOPLEFT", 400, -46)
    W.Label(p, L("Remember their place and size:"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 36, -68)
    W.Cycle(p, 150, { { "never", L("Never") }, { "session", L("Until /reload") }, { "always", L("Always") } },
        function() return Memory() end,
        function(v) db.winMemory = v end):SetPoint("TOPLEFT", 250, -63)
    local hint = W.Label(p, L("Drag a window by an empty spot (edge, title). Ctrl + mouse wheel on it: its size. Ctrl + right-click: reset it. Protected windows are never touched."),
        "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 36, -90)
    hint:SetWidth(640)
    hint:SetJustifyH("LEFT")
    W.Button(p, L("Reset the windows"), 170, 22, function()
        wipe(db.winPos)
        wipe(db.winScale)
        wipe(sessPos)
        wipe(sessScale)
        if not InCombatLockdown() then
            for name in pairs(hooked) do local f = _G[name]; if f then f:SetScale(1) end end
        end
    end):SetPoint("TOPLEFT", 36, -120)

    W.Check(p, L("Move screen elements (error text, zone text, battleground score...)"), function() return db.elements end,
        function(v) db.elements = v; if v then SetupElements() elseif unlocked then SetUnlocked(true) end end):SetPoint("TOPLEFT", 12, -146)
    local elHint = W.Label(p, L("Unticked, an element keeps its place until the next /reload."), "GameFontDisableSmall")
    elHint:SetPoint("TOPLEFT", 36, -172)

    W.Label(p, L("Tooltip:"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 16, -204)
    W.Cycle(p, 140, { { "default", L("Default") }, { "cursor", L("At the cursor") }, { "anchor", L("At its anchor") } },
        function() return db.tooltip end,
        function(v) db.tooltip = v; if v ~= "default" then HookTooltip() end; if unlocked then SetUnlocked(true) end end)
        :SetPoint("TOPLEFT", 90, -199)
    W.Check(p, L("Also in combat"), function() return db.tooltipCombat end, function(v) db.tooltipCombat = v end)
        :SetPoint("TOPLEFT", 244, -200)

    W.Check(p, L("FPS and latency"), function() return db.fps end, function(v) db.fps = v; SetupFps() end):SetPoint("TOPLEFT", 12, -232)

    unlockButton = W.Button(p, L("Unlock (show the movers)"), 220, 22, function()
        if InCombatLockdown() then return end
        SetUnlocked(not unlocked)
        if unlocked then W.Print(L("Drag the boxes, then Lock.")) end
    end)
    unlockButton:SetPoint("TOPLEFT", 16, -270)
    W.Button(p, L("Reset the elements"), 170, 22, function()
        wipe(db.elemPos)
        db.tipPoint = { "BOTTOMRIGHT", "BOTTOMRIGHT", -80, 160 }
        db.point = { "TOPLEFT", "TOPLEFT", 10, -10 }
        W.ConfirmReload(L("The elements go back to Blizzard's place after a reload."))
    end):SetPoint("TOPLEFT", 244, -270)

    local info = W.Label(p, L("Not moved here: action bars, unit and group frames, buffs, minimap. EllesmereUI does it, and moving them from an addon gives the \"action blocked\" errors."),
        "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, -310)
    info:SetWidth(680)
    info:SetJustifyH("LEFT")
    info:SetTextColor(0.7, 0.7, 0.7)
end)

W.slash.move = function() W.Toggle("MoveFrames") end
