-- WarLegend RaidTool - Interface options
-- The useful part of Advanced Interface Options: game settings Blizzard took out of its options window
-- (camera distance, spell queue, nameplate distance and stacking, combat text, names...) and a browser
-- of every console variable (CVar). A CVar is only set out of combat, only one that exists on this client
-- is shown, and the values changed here are put back at login (and travel in the profiles).
local W = WLRT
W.AddFR({
    ["Interface options"] = "Options d'interface",
    ["Camera & combat"] = "Caméra & combat",
    ["Nameplates & combat text"] = "Barres d'info & texte de combat",
    ["Names & misc"] = "Noms & divers",
    ["All CVars"] = "Toutes les CVars",
    ["Camera"] = "Caméra",
    ["Nameplates"] = "Barres d'info",
    ["Combat text"] = "Texte de combat",
    ["Names"] = "Noms",
    ["Misc"] = "Divers",
    ["Max camera distance"] = "Distance de caméra maximale",
    ["Camera zoom speed"] = "Vitesse du zoom de la caméra",
    ["Spell queue window (ms)"] = "Fenêtre de file des sorts (ms)",
    ["Stop attacking when changing target"] = "Arrêter d'attaquer en changeant de cible",
    ["Attack when using /assist"] = "Attaquer en faisant /assist",
    ["Cast on key press (not on release)"] = "Lancer à l'appui de la touche (pas au relâchement)",
    ["Do not toggle an ability off by pressing it twice (stealth...)"] = "Ne pas annuler une technique en l'appuyant deux fois (camouflage...)",
    ["Character voice for errors (not enough mana...)"] = "Voix du personnage pour les erreurs (pas assez de mana...)",
    ["Nameplate distance"] = "Distance des barres d'info",
    ["Nameplates:"] = "Barres d'info :",
    ["Overlapping"] = "Superposées",
    ["Stacking"] = "Empilées",
    ["Space between stacked nameplates"] = "Espace entre les barres empilées",
    ["Place of the nameplates"] = "Place des barres d'info",
    ["Above the head"] = "Au-dessus de la tête",
    ["At the feet"] = "Aux pieds",
    ["Size of the target's nameplate"] = "Taille de la barre de la cible",
    ["Class colors on enemy nameplates"] = "Couleurs de classe sur les barres ennemies",
    ["Class colors on friendly nameplates"] = "Couleurs de classe sur les barres alliées",
    ["Combat text about me (damage taken, heals...)"] = "Texte de combat sur moi (dégâts subis, soins...)",
    ["My damage over the target"] = "Mes dégâts au-dessus de la cible",
    ["My heals over the target"] = "Mes soins au-dessus de la cible",
    ["Periodic damage (DoTs)"] = "Dégâts périodiques (DoTs)",
    ["Pet melee damage"] = "Dégâts de mêlée du familier",
    ["Pet spell damage"] = "Dégâts des sorts du familier",
    ["Direction of the combat text"] = "Sens du texte de combat",
    ["Up"] = "Défilement vers le haut",
    ["Down"] = "Défilement vers le bas",
    ["Arc"] = "Arc-en-ciel",
    ["Size of the damage numbers"] = "Taille des chiffres de dégâts",
    ["Guild names of players"] = "Nom de guilde des joueurs",
    ["PvP titles of players"] = "Titres JcJ des joueurs",
    ["Guild ranks of players"] = "Rang de guilde des joueurs",
    ["Class colors in chat names"] = "Couleurs de classe dans les noms du chat",
    ["Every debuff on the target (not only mine)"] = "Tous les affaiblissements sur la cible (pas seulement les miens)",
    ["Fade the world map while moving"] = "Estomper la carte du monde en se déplaçant",
    ["Show Lua errors"] = "Afficher les erreurs Lua",
    ["Full-screen glow"] = "Lueur plein écran",
    ["Grey screen when dead"] = "Écran gris quand on est mort",
    ["Put my values back at each login"] = "Remettre mes valeurs à chaque connexion",
    ["Not in combat: the game refuses this change during a fight."] = "Pas en combat : le jeu refuse ce changement pendant un combat.",
    ["The game refused this value."] = "Le jeu a refusé cette valeur.",
    ["Search a CVar:"] = "Chercher une CVar :",
    ["Value"] = "Valeur",
    ["Set"] = "Appliquer",
    ["Default"] = "Par défaut",
    ["Click a CVar, type its value, then Set. Default gives it back the game's value."] =
        "Clique une CVar, tape sa valeur, puis Appliquer. Par défaut lui rend la valeur du jeu.",
    ["%d CVars (the first %d shown)"] = "%d CVars (les %d premières affichées)",
    ["%d CVars"] = "%d CVars",
    ["Only the options this client knows are shown. Changed here, a value is put back at login and is part of the profiles."] =
        "Seules les options que ce client connaît sont affichées. Changée ici, une valeur est remise à la connexion et fait partie des profils.",
})
local L = W.L
local db

W.OnReady(function()
    db = W.DB("interfaceOptions", { keep = true })
    if type(db.cvars) ~= "table" then db.cvars = {} end -- [cvar] = value set here, as text
end)

local function Off() return not db or W.IsOff("InterfaceOptions") end

---------------------------------------------------------------------------
-- CVar access (C_CVar on recent clients, the old globals otherwise), every call protected
---------------------------------------------------------------------------
local function Exists(cvar)
    if C_CVar and C_CVar.GetCVarInfo then
        local ok, v = pcall(C_CVar.GetCVarInfo, cvar)
        return ok and v ~= nil
    end
    local ok, v = pcall(GetCVar, cvar)
    return ok and v ~= nil
end

local function Get(cvar)
    local ok, v
    if C_CVar and C_CVar.GetCVar then ok, v = pcall(C_CVar.GetCVar, cvar) else ok, v = pcall(GetCVar, cvar) end
    return ok and v or nil
end

local function GetDefault(cvar)
    if C_CVar and C_CVar.GetCVarDefault then
        local ok, v = pcall(C_CVar.GetCVarDefault, cvar)
        if ok then return v end
    end
    return nil
end

local function Text(v)
    if type(v) == "boolean" then return v and "1" or "0" end
    return tostring(v)
end

-- set a CVar; remember = keep it in our list (put back at login, in the profiles)
local function Set(cvar, value, remember)
    if InCombatLockdown() then W.Print(L("Not in combat: the game refuses this change during a fight.")); return false end
    value = Text(value)
    local ok, res
    if C_CVar and C_CVar.SetCVar then ok, res = pcall(C_CVar.SetCVar, cvar, value) else ok, res = pcall(SetCVar, cvar, value) end
    if not ok or res == false then W.Print(L("The game refused this value.")); return false end
    if remember then db.cvars[cvar] = value end
    return true
end

-- a CVar we keep, changed by the game's own options window (or another addon): we keep that new value,
-- so the login never puts an old one back
local function Track(cvar, value)
    if Off() or db.cvars[cvar] == nil or value == nil then return end
    db.cvars[cvar] = Text(value)
end
if hooksecurefunc then
    if type(SetCVar) == "function" then hooksecurefunc("SetCVar", Track) end
    if C_CVar and type(C_CVar.SetCVar) == "function" then hooksecurefunc(C_CVar, "SetCVar", Track) end
end

local applied, pendingApply = false, false
local function ApplyKept()
    if Off() or not db.keep then return end
    if InCombatLockdown() then pendingApply = true; return end
    for cvar, v in pairs(db.cvars) do
        if Exists(cvar) and Get(cvar) ~= v then Set(cvar, v, false) end
    end
end
W.On("PLAYER_ENTERING_WORLD", function()
    if applied then return end
    applied = true
    ApplyKept()
end)
W.On("PLAYER_REGEN_ENABLED", function() if pendingApply then pendingApply = false; ApplyKept() end end)

---------------------------------------------------------------------------
-- The options: { cvar (or a list: the first that exists), label, values = { {value, text} } or nil for on / off,
-- invert = on / off the other way round }. English texts, translated when the tab is built.
---------------------------------------------------------------------------
local PAGES = {
    {
        { header = "Camera" },
        { "cameraDistanceMaxZoomFactor", "Max camera distance", values = { { "1.5", "1.5" }, { "2", "2" }, { "2.6", "2.6" }, { "3", "3" }, { "3.4", "3.4 (max)" } } },
        { "cameraZoomSpeed", "Camera zoom speed", values = { { "10", "10" }, { "20", "20" }, { "35", "35" }, { "50", "50" } } },
        { header = "Combat" },
        { "SpellQueueWindow", "Spell queue window (ms)", values = { { "50", "50" }, { "100", "100" }, { "150", "150" }, { "200", "200" }, { "250", "250" }, { "300", "300" }, { "400", "400" } } },
        { "stopAutoAttackOnTargetChange", "Stop attacking when changing target" },
        { "assistAttack", "Attack when using /assist" },
        { "ActionButtonUseKeyDown", "Cast on key press (not on release)" },
        { "secureAbilityToggle", "Do not toggle an ability off by pressing it twice (stealth...)" },
        { "Sound_EnableErrorSpeech", "Character voice for errors (not enough mana...)" },
    },
    {
        { header = "Nameplates" },
        { "nameplateMaxDistance", "Nameplate distance", values = { { "20", "20" }, { "30", "30" }, { "41", "41" } } },
        { "nameplateMotion", "Nameplates:", values = { { "0", "Overlapping" }, { "1", "Stacking" } } },
        { "nameplateOverlapV", "Space between stacked nameplates", values = { { "0.5", "0.5" }, { "0.8", "0.8" }, { "1.1", "1.1" }, { "1.5", "1.5" } } },
        { "nameplateOtherAtBase", "Place of the nameplates", values = { { "0", "Above the head" }, { "2", "At the feet" } } },
        { "nameplateSelectedScale", "Size of the target's nameplate", values = { { "1", "1" }, { "1.2", "1.2" }, { "1.4", "1.4" } } },
        { "ShowClassColorInNameplate", "Class colors on enemy nameplates" },
        { { "ShowClassColorInFriendlyNameplate", "nameplateShowFriendlyClassColor" }, "Class colors on friendly nameplates" },
        { header = "Combat text" },
        { "enableFloatingCombatText", "Combat text about me (damage taken, heals...)" },
        { "floatingCombatTextCombatDamage", "My damage over the target" },
        { "floatingCombatTextCombatHealing", "My heals over the target" },
        { "floatingCombatTextCombatLogPeriodicSpells", "Periodic damage (DoTs)" },
        { "floatingCombatTextPetMeleeDamage", "Pet melee damage" },
        { "floatingCombatTextPetSpellDamage", "Pet spell damage" },
        { "floatingCombatTextFloatMode", "Direction of the combat text", values = { { "1", "Up" }, { "2", "Down" }, { "3", "Arc" } } },
        { "WorldTextScale", "Size of the damage numbers", values = { { "0.5", "0.5" }, { "0.75", "0.75" }, { "1", "1" }, { "1.5", "1.5" }, { "2", "2" } } },
    },
    {
        { header = "Names" },
        { "UnitNamePlayerGuild", "Guild names of players" },
        { "UnitNamePlayerPVPTitle", "PvP titles of players" },
        { "UnitNameGuildTitle", "Guild ranks of players" },
        { "chatClassColorOverride", "Class colors in chat names", invert = true },
        { header = "Misc" },
        { "noBuffDebuffFilterOnTarget", "Every debuff on the target (not only mine)" },
        { "mapFade", "Fade the world map while moving" },
        { "scriptErrors", "Show Lua errors" },
        { "ffxGlow", "Full-screen glow" },
        { "ffxDeath", "Grey screen when dead" },
    },
}

local function FirstExisting(c)
    if type(c) == "table" then
        for _, x in ipairs(c) do if Exists(x) then return x end end
        return nil
    end
    return Exists(c) and c or nil
end

local function IsOn(v) return v ~= nil and v ~= "0" and v ~= "" and v ~= "false" end

local function BuildPage(p, entries)
    local y = -8
    for _, e in ipairs(entries) do
        if e.header then
            W.Label(p, L(e.header), "GameFontNormal"):SetPoint("TOPLEFT", 14, y - 4)
            y = y - 26
        else
            local cvar = FirstExisting(e[1])
            if cvar then
                if e.values then
                    W.Label(p, L(e[2]), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 18, y - 5)
                    local vals = {}
                    for _, v in ipairs(e.values) do vals[#vals + 1] = { v[1], L(v[2]) } end
                    local nVals, extra = #vals, nil
                    W.Cycle(p, 150, vals, function()
                        local cur = Get(cvar)
                        -- "41.000" and "41" are the same value
                        for _, v in ipairs(vals) do if tonumber(v[1]) and tonumber(cur) == tonumber(v[1]) then return v[1] end end
                        -- a value that is not in the list (set elsewhere): show it as it is, not the first entry
                        if cur and cur ~= "" then
                            if extra then vals[nVals + 1] = nil end
                            vals[nVals + 1] = { cur, cur }
                            extra = true
                        end
                        return cur
                    end, function(v) Set(cvar, v, true) end):SetPoint("TOPLEFT", 330, y)
                else
                    W.Check(p, L(e[2]), function()
                        local on = IsOn(Get(cvar))
                        if e.invert then return not on end
                        return on
                    end, function(v)
                        if e.invert then v = not v end
                        Set(cvar, v, true)
                    end):SetPoint("TOPLEFT", 14, y)
                end
                y = y - 26
            end
        end
    end
end

---------------------------------------------------------------------------
-- Every CVar: search, click, value, Set / Default
---------------------------------------------------------------------------
local MAX_ROWS = 300
local function AllCVars()
    local all = (ConsoleGetAllCommands and ConsoleGetAllCommands()) or (C_Console and C_Console.GetAllCommands and C_Console.GetAllCommands()) or {}
    local CVAR = Enum and Enum.ConsoleCommandType and Enum.ConsoleCommandType.Cvar or 0
    local out = {}
    for _, info in ipairs(all) do
        local name = info and info.command
        if type(name) == "string" and info.commandType == CVAR and info.category ~= 0 and info.category ~= 8
            and not name:lower():find("debug", 1, true) then
            out[#out + 1] = name
        end
    end
    table.sort(out, function(a, b) return a:lower() < b:lower() end)
    return out
end

local function BuildBrowser(p)
    local lbl = W.Label(p, L("Search a CVar:"), "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT", 14, -10)
    local search = W.EditBox(p, 200, 60)
    search:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
    local count = W.Label(p, "", "GameFontDisableSmall")
    count:SetPoint("LEFT", search, "RIGHT", 12, 0)
    local list = W.Table(p, { { "CVar", 300 }, { L("Value"), 160 }, { L("Default"), 160 } }, 300)
    list:SetPoint("TOPLEFT", 10, -40)
    local names
    local selected
    local sel = W.Label(p, "", "GameFontNormal")
    sel:SetPoint("TOPLEFT", 14, -356)
    local value = W.EditBox(p, 200, 200)
    value:SetPoint("TOPLEFT", 14, -376)
    local function Refresh()
        names = names or AllCVars()
        local q = (search:GetText() or ""):lower()
        local rows, found = {}, 0
        for _, name in ipairs(names) do
            if q == "" or name:lower():find(q, 1, true) then
                found = found + 1
                if #rows < MAX_ROWS then
                    local v, d = Get(name) or "", GetDefault(name) or ""
                    local shown = (v ~= d and d ~= "") and ("|cffffd100" .. v .. "|r") or v
                    rows[#rows + 1] = { cvar = name, cells = { name, shown, d } }
                end
            end
        end
        count:SetText(found > MAX_ROWS and string.format(L("%d CVars (the first %d shown)"), found, MAX_ROWS) or string.format(L("%d CVars"), found))
        list:SetData(rows)
    end
    list.onClick = function(d)
        selected = d.cvar
        sel:SetText(d.cvar)
        value:SetText(Get(d.cvar) or "")
    end
    search:SetScript("OnTextChanged", Refresh)
    W.Button(p, L("Set"), 110, 22, function()
        if not selected then return end
        if Set(selected, value:GetText() or "", true) then Refresh() end
    end):SetPoint("LEFT", value, "RIGHT", 10, 0)
    W.Button(p, L("Default"), 110, 22, function()
        if not selected then return end
        local d = GetDefault(selected)
        if d and Set(selected, d, false) then
            db.cvars[selected] = nil -- back to the game's value: no longer one of ours
            value:SetText(d)
            Refresh()
        end
    end):SetPoint("LEFT", value, "RIGHT", 126, 0)
    local help = W.Label(p, L("Click a CVar, type its value, then Set. Default gives it back the game's value."), "GameFontDisableSmall")
    help:SetPoint("TOPLEFT", 14, -404)
    p:SetScript("OnShow", function() names = nil; Refresh() end)
end

W.RegisterModule("InterfaceOptions", "Interface options", function(p)
    W.Title(p, L("Interface options"))
    local tabs = W.SubTabs(p, { L("Camera & combat"), L("Nameplates & combat text"), L("Names & misc"), L("All CVars") })
    for i = 1, 3 do BuildPage(tabs.frames[i], PAGES[i]) end
    BuildBrowser(tabs.frames[4])
    W.Check(p, L("Put my values back at each login"), function() return db.keep end, function(v) db.keep = v end)
        :SetPoint("BOTTOMLEFT", 12, 30)
    local info = W.Label(p, L("Only the options this client knows are shown. Changed here, a value is put back at login and is part of the profiles."),
        "GameFontDisableSmall")
    info:SetPoint("BOTTOMLEFT", 16, 12)
    tabs:Select(1)
end)

W.slash.cvar = function() W.Toggle("InterfaceOptions") end
