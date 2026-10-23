-- WarLegend RaidTool - Myslot
-- Loader of the addon WarLegendRaidTool_Myslot (action bars, macros, key bindings and settings saved / restored as
-- text or as named exports, Myslot 6.2.1 by Boshi Lian, Apache-2.0). Loaded on demand: /wl myslot or the Myslot tab.
-- Personal tool: it sends nothing through WLRT. The exports are in MyslotExports (the original addon's file name).
local W = WLRT
local L = W.L

local MY_ADDON = "WarLegendRaidTool_Myslot"
local loadFailed = false

W.AddFR({
    ["The Myslot module is missing or disabled: install the folder WarLegendRaidTool_Myslot next to WarLegendRaidTool."] =
        "Le module Myslot est absent ou désactivé : installe le dossier WarLegendRaidTool_Myslot à côté de WarLegendRaidTool.",
    ["The Myslot module had an error while loading: see BugSack (/bugsack). If the original Myslot addon is also installed, disable it."] =
        "Le module Myslot a eu une erreur au chargement : voir BugSack (/bugsack). Si l'addon Myslot d'origine est aussi installé, désactive-le.",
    ["Myslot: save and restore your action bars, macros, key bindings and settings as a text to copy or as named exports (also to move them to another character or account)."] =
        "Myslot : sauvegarde et restaure tes barres d'action, macros, raccourcis et réglages sous forme d'un texte à copier ou d'exports nommés (aussi pour les passer à un autre personnage ou compte).",
    ["Open Myslot"] = "Ouvrir Myslot",
    ["Importing replaces your action bars and macros: it is refused in combat. Use the original addon's own confirmation."] =
        "Importer remplace tes barres d'action et tes macros : refusé en combat. La confirmation d'origine de Myslot s'applique.",
    ["If the original Myslot addon is installed, disable it: it uses the same saved file."] =
        "Si l'addon Myslot d'origine est installé, désactive-le : il utilise le même fichier de données.",
})

-- Loads the Myslot addon now (true when it is in memory)
function W.LoadMyslot()
    if _G.SlashCmdList and _G.SlashCmdList.MYSLOT then return true end
    if loadFailed or not (C_AddOns and C_AddOns.LoadAddOn) then return false end
    local called, ok = W.Measure("load the Myslot module", C_AddOns.LoadAddOn, MY_ADDON)
    if not called or not ok then
        loadFailed = true
        W.Print(L("The Myslot module is missing or disabled: install the folder WarLegendRaidTool_Myslot next to WarLegendRaidTool."))
        return false
    end
    if not (_G.SlashCmdList and _G.SlashCmdList.MYSLOT) then
        loadFailed = true
        W.Print(L("The Myslot module had an error while loading: see BugSack (/bugsack). If the original Myslot addon is also installed, disable it."))
        return false
    end
    return true
end

-- /wl myslot [load name | ...] : the arguments go to Myslot's own /myslot command
W.slash.myslot = function(rest)
    if W.LoadMyslot() then _G.SlashCmdList.MYSLOT(rest or "") end
end

W.RegisterModule("Myslot", "Myslot", function(p)
    W.Title(p, "Myslot")
    local info = W.Label(p, L("Myslot: save and restore your action bars, macros, key bindings and settings as a text to copy or as named exports (also to move them to another character or account)."), "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, -40)
    info:SetWidth(520)
    info:SetJustifyH("LEFT")
    W.Button(p, L("Open Myslot"), 140, 24, function() W.slash.myslot("") end):SetPoint("TOPLEFT", 16, -92)
    local note = W.Label(p, L("Importing replaces your action bars and macros: it is refused in combat. Use the original addon's own confirmation.")
        .. "\n" .. L("If the original Myslot addon is installed, disable it: it uses the same saved file."), "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 16, -130)
    note:SetWidth(520)
    note:SetJustifyH("LEFT")
    note:SetTextColor(0.7, 0.7, 0.7)
end)
