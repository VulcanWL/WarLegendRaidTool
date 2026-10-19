-- WarLegend RaidTool - Overlap
-- Finds the features another addon you run already does (Naowh Forever, EllesmereUI) so WarLegend does
-- not do them twice: a feature of ours that another ENABLED addon provides stays off, and its panel says
-- which addon covers it. A switch ("Use it anyway") keeps ours on. Nothing here runs by
-- itself: W.Overlap(feature) is asked when a feature is about to act (combat start, vendor window...).
-- The Graveyard timer is never switched off (no other addon of yours has it).
local W = WLRT
W.AddFR({
    ["Covered by %s: off here (no duplicate)."] = "Déjà fourni par %s : désactivé ici (pas de doublon).",
    ["Use it anyway"] = "L'utiliser quand même",
})
local L = W.L

-- Naowh Forever: its QoL module keeps one settings object (ns.QoLSettings.Get(key)); "enabled" is its master switch
local function Naowh(key)
    return function()
        local ns = _G.NaowhForever
        local S = ns and ns.QoLSettings
        if not (S and S.Get) then return false end
        local ok, on = pcall(function() return S.Get("enabled") and S.Get(key) end)
        return ok and on == true
    end
end

-- EllesmereUI: plain keys of its saved table (a missing key means "on" for sell junk / repair)
local function EUI(test)
    return function()
        local db = _G.EllesmereUIDB
        if type(db) ~= "table" then return false end
        local ok, on = pcall(test, db)
        return ok and on == true
    end
end

-- WarLegend v3 (Sashoof): its saved table, only there while that addon is enabled. Its "Groups" module invites on a
-- keyword whisper unless invite.mode is "off" (its auto promotion never acts: no overlap there).
local function WL3Invite()
    local d = _G.WarLegendDB
    local c = type(d) == "table" and d.config
    if type(c) ~= "table" or type(c.invite) ~= "table" then return false end
    if type(c.modules) == "table" and c.modules.Groups == false then return false end
    return c.invite.mode ~= nil and c.invite.mode ~= "off"
end

-- WarLegend feature -> { addon name, test }, first match wins
local PROVIDERS = {
    combatTimer = { { "Naowh Forever", Naowh("combatTimer") } },
    fastLoot = { { "Naowh Forever", Naowh("fastLoot") } },
    sellJunk = { { "Naowh Forever", Naowh("sellJunk") },
        { "EllesmereUI", EUI(function(d) return d.autoSellJunk ~= false end) } },
    autoRepair = { { "Naowh Forever", Naowh("autoRepair") },
        { "EllesmereUI", EUI(function(d) return d.autoRepair ~= false end) } },
    skipCinematics = { { "Naowh Forever", Naowh("skipCinematics") },
        { "EllesmereUI", EUI(function(d) return d.skipCinematics == true end) } },
    questAccept = { { "Naowh Forever", Naowh("questAccept") } },
    questTurnIn = { { "Naowh Forever", Naowh("questTurnIn") } },
    deleteConfirm = { { "Naowh Forever", Naowh("deleteConfirm") } },
    autoLog = { { "EllesmereUI", EUI(function(d) return type(d.autoLogging) == "table" and d.autoLogging.enabled == true end) } },
    autoInvite = { { "WarLegend v3", function() local ok, on = pcall(WL3Invite); return ok and on == true end } },
}

-- one switch for every feature (Overlap panel notes): "use ours anyway"
local function Forced()
    local ui = W.db and W.db.ui
    return ui and ui.overlapForce == true
end

-- Name of the other addon that already does this feature, or nil (forced, none, or not enabled there)
function W.Overlap(feature)
    local list = PROVIDERS[feature]
    if not list or Forced() then return nil end
    for _, p in ipairs(list) do
        if p[2]() then return p[1] end
    end
end

-- true when WarLegend's own option is on and nothing else covers it
function W.FeatureOn(db, key, feature)
    return db and db[key] and not W.Overlap(feature or key)
end

-- Small note under / next to an option in a panel: which addon covers it, and a switch to force ours
function W.OverlapNote(parent, feature, point, x, y)
    local fs = W.Label(parent, "", "GameFontDisableSmall")
    fs:SetPoint(point or "TOPLEFT", x or 0, y or 0)
    fs:SetTextColor(1, 0.6, 0.2)
    local function refresh()
        local name = W.Overlap(feature)
        if name then fs:SetText(string.format(L("Covered by %s: off here (no duplicate)."), name)) else fs:SetText("") end
    end
    parent:HookScript("OnShow", refresh)
    refresh()
    return fs, refresh
end

function W.OverlapForced() return Forced() and true or false end
function W.SetOverlapForce(on)
    W.DB("ui").overlapForce = on and true or false
end
