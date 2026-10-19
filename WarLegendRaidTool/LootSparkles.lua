-- WarLegend RaidTool - Loot sparkles
-- Keeps the loot sparkle on quest items (the game only shows it while the outline mode is off, and graphics presets
-- switch the outline back on) and shows the game's own icon above the nodes you can gather (soft targeting).
-- Only console variables are set, out of combat, through pcall; the original values are saved and put back.
-- Idea: ForeverLootSparkles (GPL-3.0). Nothing is copied from it: the list of console variables is its documented behaviour.
local W = WLRT
W.AddFR({
    ["Loot sparkles"] = "Scintillements du butin",
    ["Sparkle on quest items (always)"] = "Scintillement sur les objets de quête (toujours)",
    ["Icon above the nodes you can gather (ore, herbs...)"] = "Icône au-dessus des ressources à récolter (minerai, herbes...)",
    ["The game shows the sparkle on quest items only while the outline mode is off: graphics presets turn it back on, so it is set again at login and after a graphics change. Switching it off takes effect after restarting the game (/reload is not enough)."] =
        "Le jeu n'affiche le scintillement des objets de quête que si le mode contour est désactivé : les préréglages graphiques le réactivent, il est donc remis à la connexion et après un changement graphique. Le désactiver ne prend effet qu'après un redémarrage du jeu (/reload ne suffit pas).",
    ["Uses the game's soft targeting: the icon shows for everything you can interact with, up to about 15 yards. Not changed during combat."] =
        "Utilise le ciblage souple du jeu : l'icône s'affiche pour tout ce avec quoi tu peux interagir, jusqu'à environ 15 mètres. Rien n'est changé en combat.",
})
local L = W.L
local db

local QUEST = {
    { "outlineModeShowLootEffectWhenDisabled", "1" },
    { "graphicsOutlineMode", "0" },
    { "OutlineEngineMode", "0" },
    { "raidGraphicsOutlineMode", "0" },
    { "RAIDOutlineEngineMode", "0" },
}
local QUEST_OFF = { outlineModeShowLootEffectWhenDisabled = "0", graphicsOutlineMode = "2" }
local SOFT = {
    { "SoftTargetInteract", "3" },
    { "SoftTargetInteractRange", "60" },
    { "SoftTargetInteractArc", "2" },
    { "SoftTargetInteractOnlyInRange", "0" },
    { "SoftTargetIconInteract", "1" },
    { "SoftTargetIconGameObject", "1" },
    { "SoftTargetLowPriorityIcons", "1" },
}

W.OnReady(function()
    db = W.DB("lootSparkles", { quest = false, nodes = false })
end)

local function Get(name)
    if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(name) end
    return GetCVar and GetCVar(name)
end

local function Set(name, value)
    if C_CVar and C_CVar.SetCVar then return pcall(C_CVar.SetCVar, name, value) end
    if SetCVar then return pcall(SetCVar, name, value) end
end

-- sets a list of variables, remembering each original value once (db["o_" .. name])
local function Apply(list)
    for _, v in ipairs(list) do
        local name, value = v[1], v[2]
        if db["o_" .. name] == nil then
            local cur = Get(name)
            if type(cur) == "string" then db["o_" .. name] = cur end
        end
        if Get(name) ~= value then Set(name, value) end
    end
end

local function Restore(list, fallback)
    for _, v in ipairs(list) do
        local name = v[1]
        local old = db["o_" .. name]
        if old == nil and fallback then old = fallback[name] end
        if type(old) == "string" and Get(name) ~= old then Set(name, old) end
        db["o_" .. name] = nil
    end
end

local pending = false
local function Refresh()
    if not db then return end
    if InCombatLockdown() then pending = true; return end
    pending = false
    if db.quest then Apply(QUEST) end
    if db.nodes then Apply(SOFT) end
end

local function Quest(on)
    db.quest = on
    if on then Refresh() elseif not InCombatLockdown() then Restore(QUEST, QUEST_OFF) end
end

local function Nodes(on)
    db.nodes = on
    if on then Refresh() elseif not InCombatLockdown() then Restore(SOFT) end
end

W.On("PLAYER_ENTERING_WORLD", function() W.After(1, Refresh) end)
W.On("GX_RESTARTED", function() W.After(1, Refresh) end)
W.On("PLAYER_REGEN_ENABLED", function() if pending then Refresh() end end)

W.RegisterModule("LootSparkles", "Loot sparkles", function(p)
    W.Title(p, L("Loot sparkles"))
    W.Check(p, L("Sparkle on quest items (always)"), function() return db.quest end, Quest):SetPoint("TOPLEFT", 12, -40)
    local a = W.Label(p, L("The game shows the sparkle on quest items only while the outline mode is off: graphics presets turn it back on, so it is set again at login and after a graphics change. Switching it off takes effect after restarting the game (/reload is not enough)."),
        "GameFontHighlightSmall")
    a:SetPoint("TOPLEFT", 36, -66)
    a:SetWidth(660)
    a:SetJustifyH("LEFT")
    a:SetTextColor(0.7, 0.7, 0.7)
    W.Check(p, L("Icon above the nodes you can gather (ore, herbs...)"), function() return db.nodes end, Nodes):SetPoint("TOPLEFT", 12, -120)
    local b = W.Label(p, L("Uses the game's soft targeting: the icon shows for everything you can interact with, up to about 15 yards. Not changed during combat."),
        "GameFontHighlightSmall")
    b:SetPoint("TOPLEFT", 36, -146)
    b:SetWidth(660)
    b:SetJustifyH("LEFT")
    b:SetTextColor(0.7, 0.7, 0.7)
end)
