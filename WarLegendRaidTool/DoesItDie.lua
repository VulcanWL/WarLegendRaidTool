-- WarLegend RaidTool - DoesItDie
-- Loader of the addon WarLegendRaidTool_DoesItDie (damage your DoTs still have left marked on the target's health bar
-- and on the nameplates, kill icon when they finish the mob; DoesItDie 0.8.3 by Joe Greive, MIT). Off by default:
-- loaded at login only once switched on. Personal tool: it sends nothing. Settings in DoesItDieDB (original name).
local W = WLRT
local L = W.L
local db

local DID_ADDON = "WarLegendRaidTool_DoesItDie"
local loadFailed = false

W.AddFR({
    ["The DoesItDie module is missing or disabled: install the folder WarLegendRaidTool_DoesItDie next to WarLegendRaidTool."] =
        "Le module DoesItDie est absent ou désactivé : installe le dossier WarLegendRaidTool_DoesItDie à côté de WarLegendRaidTool.",
    ["The DoesItDie module had an error while loading: see BugSack (/bugsack). If the original DoesItDie addon is also installed, disable it."] =
        "Le module DoesItDie a eu une erreur au chargement : voir BugSack (/bugsack). Si l'addon DoesItDie d'origine est aussi installé, désactive-le.",
    ["DoesItDie: marks on your target's health bar the damage your DoTs still have to deal, and shows a kill icon when they will finish it."] =
        "DoesItDie : marque sur la barre de vie de ta cible les dégâts que tes DoT doivent encore faire, et montre une icône de mort quand ils vont l'achever.",
    ["Enable DoesItDie (loaded at login)"] = "Activer DoesItDie (chargé à la connexion)",
    ["Open the DoesItDie options"] = "Ouvrir les options de DoesItDie",
    ["Nameplates: off"] = "Barres de nom : rien",
    ["Nameplates: marker only"] = "Barres de nom : marque seulement",
    ["Nameplates: marker and kill icon"] = "Barres de nom : marque et icône de mort",
    ["Switching it off takes effect after a /reload."] = "L'éteindre prend effet après un /reload.",
    ["If the original DoesItDie addon is installed, disable it: it uses the same saved file."] =
        "Si l'addon DoesItDie d'origine est installé, désactive-le : il utilise le même fichier de données.",
    ["DoesItDie: marks of the DoTs on the target and the nameplates (on demand, off by default)"] =
        "DoesItDie : marques des DoT sur la cible et les barres de nom (à la demande, éteint par défaut)",
})

-- Loads the DoesItDie addon now (true when it is in memory)
function W.LoadDoesItDie()
    if _G.SlashCmdList and _G.SlashCmdList.DOESITDIE then return true end
    if loadFailed or not (C_AddOns and C_AddOns.LoadAddOn) then return false end
    local called, ok = W.Measure("load the DoesItDie module", C_AddOns.LoadAddOn, DID_ADDON)
    if not called or not ok then
        loadFailed = true
        W.Print(L("The DoesItDie module is missing or disabled: install the folder WarLegendRaidTool_DoesItDie next to WarLegendRaidTool."))
        return false
    end
    if not (_G.SlashCmdList and _G.SlashCmdList.DOESITDIE) then
        loadFailed = true
        W.Print(L("The DoesItDie module had an error while loading: see BugSack (/bugsack). If the original DoesItDie addon is also installed, disable it."))
        return false
    end
    return true
end

W.OnReady(function()
    db = W.DB("doesItDie", { enabled = false })
    if db.enabled then W.LoadDoesItDie() end
end)

-- /wl did [args] : the arguments go to DoesItDie's own /did command (loads it, even when switched off)
W.slash.did = function(rest)
    if W.LoadDoesItDie() then _G.SlashCmdList.DOESITDIE(rest or "") end
end

W.RegisterModule("DoesItDie", "DoesItDie", function(p)
    W.Title(p, "DoesItDie")
    local info = W.Label(p, L("DoesItDie: marks on your target's health bar the damage your DoTs still have to deal, and shows a kill icon when they will finish it."), "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, -40)
    info:SetWidth(520)
    info:SetJustifyH("LEFT")
    W.Check(p, L("Enable DoesItDie (loaded at login)"), function() return db.enabled end, function(v)
        db.enabled = v
        if v then W.LoadDoesItDie() end
    end):SetPoint("TOPLEFT", 16, -76)
    -- the nameplate display, written straight in DoesItDie's own settings (read again on its next update)
    W.Cycle(p, 260, { { "off", L("Nameplates: off") }, { "marker", L("Nameplates: marker only") },
        { "markerIcon", L("Nameplates: marker and kill icon") } },
        function() return _G.DoesItDieDB and DoesItDieDB.nameplateMode or "markerIcon" end,
        function(v) if W.LoadDoesItDie() and _G.DoesItDieDB then DoesItDieDB.nameplateMode = v end end):SetPoint("TOPLEFT", 20, -108)
    W.Button(p, L("Open the DoesItDie options"), 200, 24, function() W.slash.did("") end):SetPoint("TOPLEFT", 16, -144)
    local note = W.Label(p, L("Switching it off takes effect after a /reload.") .. "\n"
        .. L("If the original DoesItDie addon is installed, disable it: it uses the same saved file."), "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 16, -180)
    note:SetWidth(520)
    note:SetJustifyH("LEFT")
    note:SetTextColor(0.7, 0.7, 0.7)
end)
