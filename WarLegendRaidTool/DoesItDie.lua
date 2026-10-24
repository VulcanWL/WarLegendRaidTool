-- WarLegend RaidTool - DoesItDie
-- Settings tab of DoesItDie (damage your DoTs still have left marked on the target's health bar and on the
-- nameplates, kill icon when they finish the mob; DoesItDie 0.8.3 by Joe Greive, MIT), whose files are in the folder
-- DoesItDie/. Off by default: its code stops at load until switched on (then /reload). Personal tool: it sends
-- nothing. Settings in DoesItDieDB (original name).
local W = WLRT
local L = W.L
local db

W.AddFR({
    ["DoesItDie: marks on your target's health bar the damage your DoTs still have to deal, and shows a kill icon when they will finish it."] =
        "DoesItDie : marque sur la barre de vie de ta cible les dégâts que tes DoT doivent encore faire, et montre une icône de mort quand ils vont l'achever.",
    ["Enable DoesItDie"] = "Activer DoesItDie",
    ["Open the DoesItDie options"] = "Ouvrir les options de DoesItDie",
    ["Nameplates: off"] = "Barres de nom : rien",
    ["Nameplates: marker only"] = "Barres de nom : marque seulement",
    ["Nameplates: marker and kill icon"] = "Barres de nom : marque et icône de mort",
    ["Switching it on or off takes effect after a /reload."] = "L'allumer ou l'éteindre prend effet après un /reload.",
    ["If the original DoesItDie addon is installed, disable it: it uses the same saved file."] =
        "Si l'addon DoesItDie d'origine est installé, désactive-le : il utilise le même fichier de données.",
    ["DoesItDie: marks of the DoTs on the target and the nameplates (off by default)"] =
        "DoesItDie : marques des DoT sur la cible et les barres de nom (éteint par défaut)",
    ["DoesItDie is off: switch it on in Raid > Combat > DoesItDie, then /reload."] =
        "DoesItDie est éteint : allume-le dans Raid > Combat > DoesItDie, puis /reload.",
})

W.OnReady(function()
    db = W.DB("doesItDie", { enabled = false })
end)

-- /wl did [args] : the arguments go to DoesItDie's own /did command (which says how to switch it on when it is off)
W.slash.did = function(rest)
    if SlashCmdList and SlashCmdList.DOESITDIE then SlashCmdList.DOESITDIE(rest or "") end
end

W.RegisterModule("DoesItDie", "DoesItDie", function(p)
    W.Title(p, "DoesItDie")
    local info = W.Label(p, L("DoesItDie: marks on your target's health bar the damage your DoTs still have to deal, and shows a kill icon when they will finish it."), "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, -40)
    info:SetWidth(520)
    info:SetJustifyH("LEFT")
    W.Check(p, L("Enable DoesItDie"), function() return db.enabled end, function(v) db.enabled = v end)
        :SetPoint("TOPLEFT", 16, -76)
    -- the nameplate display, written straight in DoesItDie's own settings (read again on its next update)
    W.Cycle(p, 260, { { "off", L("Nameplates: off") }, { "marker", L("Nameplates: marker only") },
        { "markerIcon", L("Nameplates: marker and kill icon") } },
        function() return _G.DoesItDieDB and DoesItDieDB.nameplateMode or "markerIcon" end,
        function(v) DoesItDieDB = DoesItDieDB or {}; DoesItDieDB.nameplateMode = v end):SetPoint("TOPLEFT", 20, -108)
    W.Button(p, L("Open the DoesItDie options"), 200, 24, function() W.slash.did("") end):SetPoint("TOPLEFT", 16, -144)
    local note = W.Label(p, L("Switching it on or off takes effect after a /reload.") .. "\n"
        .. L("If the original DoesItDie addon is installed, disable it: it uses the same saved file."), "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 16, -180)
    note:SetWidth(520)
    note:SetJustifyH("LEFT")
    note:SetTextColor(0.7, 0.7, 0.7)
end)
