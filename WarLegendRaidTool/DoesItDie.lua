-- WarLegend RaidTool - DoesItDie
-- Marks on the target's health bar (and on the nameplates and the focus frame) the damage your DoTs still have to
-- deal, and shows a kill icon when they will finish the mob. Based on DoesItDie 0.8.3 by Joe Greive (MIT), made into
-- this module: its files are in the folder DoesItDie/ (tracking, display, nameplates, focus, execute probe, the tab).
-- Off by default; switched on or off at once from its tab, no /reload. Personal tool: it sends nothing.
local W = WLRT
local L = W.L
local ns = W.Space("DoesItDie")
local db

W.AddFR({
    ["DoesItDie: marks on your target's health bar the damage your DoTs still have to deal, and shows a kill icon when they will finish it."] =
        "DoesItDie : marque sur la barre de vie de ta cible les dégâts que tes DoT doivent encore faire, et montre une icône de mort quand ils vont l'achever.",
    ["Enable DoesItDie"] = "Activer DoesItDie",
    ["Tracks your DoTs (casts and ticks seen by the game) on the target, the focus and the nameplates. Off: nothing is registered and nothing runs."] =
        "Suit tes DoT (sorts lancés et ticks vus par le jeu) sur la cible, la focalisation et les barres de nom. Éteint : rien n'est enregistré et rien ne tourne.",
    ["The original DoesItDie addon is enabled: the one of WaR LegenD stays off (disable one of them)."] =
        "L'addon DoesItDie d'origine est activé : celui de WaR LegenD reste éteint (désactive l'un des deux).",
    ["DoesItDie: marks of the DoTs on the target and the nameplates (on demand, off by default)"] =
        "DoesItDie : marques des DoT sur la cible et les barres de nom (à la demande, éteint par défaut)",
    ["DoesItDie is switched off in Settings > Modules."] = "DoesItDie est désactivé dans Réglages > Modules.",
})

-- The original addon, when enabled, loads before us (alphabetical order): it keeps its /did and its saved table,
-- and ours stays off (both would mark every nameplate).
local originalLoaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("DoesItDie") or false
-- Its live saved table, read before our saved variables replace the global DoesItDieDB (both save it at logout).
local originalDB = originalLoaded and type(DoesItDieDB) == "table" and DoesItDieDB or nil

-- 1.37.0 to 1.41.54 kept the settings and learned tick sizes in DoesItDieDB, the original addon's own name (still
-- listed in the .toc for this move): copied once into W.db.doesItDie, then no longer saved.
W.Migration(3, "doesItDie", function(saved)
    local old = DoesItDieDB
    if type(old) ~= "table" then return end
    local t = type(saved.doesItDie) == "table" and saved.doesItDie or {}
    saved.doesItDie = t
    for key, value in pairs(ns.DEFAULTS) do
        if key ~= "enabled" and type(old[key]) == type(value) then t[key] = old[key] end
    end
    if old.version == ns.TICKS_VERSION and type(old.ticks) == "table" then
        t.ticks, t.ticksVersion = old.ticks, ns.TICKS_VERSION -- checked by ns.SetDB
    end
end)

-- Whether the tracking may run: the module's switch, Settings > Modules, the guild check, no original addon.
function ns.Allowed()
    return db ~= nil and db.enabled and W.Allowed() and not W.IsOff("DoesItDie") and not originalLoaded
end

function ns.Apply() ns.SetActive(ns.Allowed()) end

W.OnReady(function()
    db = W.DB("doesItDie", ns.DEFAULTS)
    ns.Sanitize(db)
    ns.SetDB(db)
    if originalLoaded then
        if originalDB then DoesItDieDB = originalDB end -- given back: the original addon saves it
        if db.enabled then W.Print(L("The original DoesItDie addon is enabled: the one of WaR LegenD stays off (disable one of them).")) end
    else
        DoesItDieDB = nil -- moved into W.db.doesItDie (migration 3)
    end
end)

-- Switched on once the guild check passed (W.On only runs then), and again after Settings > Modules turned it back on.
W.On("PLAYER_ENTERING_WORLD", function() ns.Apply() end)
W.On("PLAYER_TARGET_CHANGED", function() if not ns.IsActive() then ns.Apply() end end)
W.On("PLAYER_REGEN_DISABLED", function() if not ns.IsActive() then ns.Apply() end end)

-- /wl did [command]: no command opens the tab, "ticks" its Learned ticks sub-tab, the rest goes to ns.Command
-- (DoesItDie/DoesItDie.lua: line, skull, plates, exec, debug, reset, help).
W.slash.did = function(rest)
    if originalLoaded then
        W.Print(L("The original DoesItDie addon is enabled: the one of WaR LegenD stays off (disable one of them)."))
        return
    end
    if W.IsOff("DoesItDie") then W.Print(L("DoesItDie is switched off in Settings > Modules.")); return end
    local cmd = strlower(strtrim(rest or ""))
    if cmd == "" or cmd == "options" or cmd == "config" or cmd == "ticks" then
        W.Toggle("DoesItDie")
        if cmd == "ticks" then ns.ShowLearnedTicks() end
        return
    end
    ns.Command(cmd)
end

-- /did and /doesitdie, the original addon's commands, unless that addon has them.
if not originalLoaded then
    SLASH_DOESITDIE1, SLASH_DOESITDIE2 = "/did", "/doesitdie"
    SlashCmdList.DOESITDIE = function(msg)
        if not W.Allowed() then W.Denied(); return end
        W.slash.did(msg)
    end
end

W.RegisterModule("DoesItDie", "DoesItDie", function(p)
    W.Title(p, "DoesItDie")
    local info = W.Label(p, L("DoesItDie: marks on your target's health bar the damage your DoTs still have to deal, and shows a kill icon when they will finish it."), "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, -38)
    info:SetWidth(790)
    W.Check(p, L("Enable DoesItDie"), function() return db.enabled end, function(v)
        db.enabled = v
        ns.Apply()
        if v and originalLoaded then
            W.Print(L("The original DoesItDie addon is enabled: the one of WaR LegenD stays off (disable one of them)."))
        end
    end, { L("Tracks your DoTs (casts and ticks seen by the game) on the target, the focus and the nameplates. Off: nothing is registered and nothing runs.") })
        :SetPoint("TOPLEFT", 12, -60)
    ns.BuildTab(p)
end)
