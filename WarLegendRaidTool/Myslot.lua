-- WarLegend RaidTool - Myslot
-- Tab of Myslot (files in the folder Myslot/: action bars, macros, key bindings and settings saved / restored as
-- text or as named exports, Myslot 6.2.1 by Boshi Lian, Apache-2.0). Open: /wl myslot or the Myslot tab.
-- Personal tool: it sends nothing through WLRT. The exports are in MyslotExports (the original addon's file name).
local W = WLRT
local L = W.L

W.AddFR({
    ["Myslot had an error while loading: see BugSack (/bugsack). If the original Myslot addon is also installed, disable it."] =
        "Myslot a eu une erreur au chargement : voir BugSack (/bugsack). Si l'addon Myslot d'origine est aussi installé, désactive-le.",
    ["Myslot: save and restore your action bars, macros, key bindings and settings as a text to copy or as named exports (also to move them to another character or account)."] =
        "Myslot : sauvegarde et restaure tes barres d'action, macros, raccourcis et réglages sous forme d'un texte à copier ou d'exports nommés (aussi pour les passer à un autre personnage ou compte).",
    ["Open Myslot"] = "Ouvrir Myslot",
    ["Importing replaces your action bars and macros: it is refused in combat. Use the original addon's own confirmation."] =
        "Importer remplace tes barres d'action et tes macros : refusé en combat. La confirmation d'origine de Myslot s'applique.",
    ["If the original Myslot addon is installed, disable it: it uses the same saved file."] =
        "Si l'addon Myslot d'origine est installé, désactive-le : il utilise le même fichier de données.",
    -- said by the import confirmation of Myslot/gui.lua
    ["Macros in this profile: %d."] = "Macros dans ce profil : %d.",
    ["Macros with a command that is not targeting or casting (code, guild, chat...) (%d):"] =
        "Macros avec une commande qui ne cible ni ne lance de sort (code, guilde, chat...) (%d) :",
    ["Key bindings that click a button or run a macro (%d):"] =
        "Raccourcis qui cliquent un bouton ou lancent une macro (%d) :",
    ["Import only a profile you trust."] = "N'importe qu'un profil de confiance.",
    -- said by /myslot load and /myslot clear (Myslot/gui.lua)
    ["Myslot: the profile is in the window, click Import to apply it."] =
        "Myslot : le profil est dans la fenêtre, clique sur Importer pour l'appliquer.",
    ["Myslot: clear all your %s? There is no backup."] = "Myslot : effacer tous tes %s ? Il n'y a pas de sauvegarde.",
    ["Myslot: paused until the end of the fight."] = "Myslot : en pause jusqu'à la fin du combat.",
})

-- /wl myslot [load name | ...] : the arguments go to Myslot's own /myslot command
W.slash.myslot = function(rest)
    if _G.SlashCmdList and _G.SlashCmdList.MYSLOT then _G.SlashCmdList.MYSLOT(rest or "")
    else W.Print(L("Myslot had an error while loading: see BugSack (/bugsack). If the original Myslot addon is also installed, disable it.")) end
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
