-- WarLegend RaidTool - Skyborne
-- Loader of the addon WarLegendRaidTool_Skyborne (leylines / elemental convergences on the world map, based on
-- "Skyborne Leyline & Convergence Marker" by tr0tsky, MIT). It is loaded on demand, only for Skyborne characters.
-- Its settings are in the game's addon settings (/wl sk). Personal tool: it sends nothing through WLRT; the sharing
-- (on by default, switch off in the settings) uses the original addon's hidden channel, so the original addon's users are heard too.
local W = WLRT
local L = W.L

local SKY_ADDON = "WarLegendRaidTool_Skyborne"
local loaded, loadFailed = false, false

W.AddFR({
    ["The Skyborne module is missing or disabled: install the folder WarLegendRaidTool_Skyborne next to WarLegendRaidTool."] =
        "Le module Skyborne est absent ou désactivé : installe le dossier WarLegendRaidTool_Skyborne à côté de WarLegendRaidTool.",
    ["The Skyborne module had an error while loading: see BugSack (/bugsack)."] =
        "Le module Skyborne a eu une erreur au chargement : voir BugSack (/bugsack).",
    ["/wl sk is for Skyborne characters only."] = "/wl sk est réservé aux personnages Skyborne.",
})

local function IsSkyborne()
    return select(2, UnitRace("player")) == "Skyborne"
end

-- Loads the Skyborne addon now (true when it is in memory and started)
function W.LoadSkyborne()
    if loaded then return true end
    if loadFailed or not (C_AddOns and C_AddOns.LoadAddOn) then return false end
    local called, ok = W.Measure("load the Skyborne module", C_AddOns.LoadAddOn, SKY_ADDON)
    if not called or not ok then
        loadFailed = true
        W.Print(L("The Skyborne module is missing or disabled: install the folder WarLegendRaidTool_Skyborne next to WarLegendRaidTool."))
        return false
    end
    if not (_G.WLRTSkyborne and _G.WLRTSkyborne.Start and _G.WLRTSkyborne.Command) then
        loadFailed = true -- the next /wl sk must not call a missing function
        W.Print(L("The Skyborne module had an error while loading: see BugSack (/bugsack)."))
        return false
    end
    loaded = true
    return true
end

local function MaybeLoad()
    if loaded or loadFailed or W.access ~= true or not IsSkyborne() then return end
    if W.LoadSkyborne() then _G.WLRTSkyborne.Start() end
end
W.On("PLAYER_ENTERING_WORLD", MaybeLoad)

W.slash.sk = function(rest)
    if not IsSkyborne() then
        W.Print(L("/wl sk is for Skyborne characters only."))
        return
    end
    if W.LoadSkyborne() and _G.WLRTSkyborne then
        _G.WLRTSkyborne.Start()
        _G.WLRTSkyborne.Command(rest)
    end
end
