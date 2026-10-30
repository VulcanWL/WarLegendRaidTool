-- WarLegend RaidTool - Myslot: the tab
-- Built in the Myslot tab of the window (../Myslot.lua: ns.BuildTab). Sub-tabs: Profile (the text box, Export, Import,
-- save under a name), Saved profiles (named exports and the backups made before each import), Parts (what Export and
-- Import cover, for this session), Delete (the tools that delete without a backup, each asked first). Export, Import and
-- the deletions act in the click of their button or of the confirmation (AGENTS.md rule 7), never in combat.
local W = WLRT
local L = W.L
local ns = W.Space("Myslot")

W.AddFR({
    ["Profile"] = "Profil",
    ["Saved profiles"] = "Profils enregistrés",
    ["Parts"] = "Parties",
    ["Delete"] = "Supprimer",
    ["Export"] = "Exporter",
    ["Writes your action bars, macros and key bindings (the parts ticked in Parts) as a text in the box: copy it with Ctrl+C."] =
        "Écrit tes barres d'action, macros et raccourcis (les parties cochées dans Parties) sous forme de texte dans la case : copie-le avec Ctrl+C.",
    ["Applies the profile pasted in the box to the parts ticked in Parts. It asks first, lists what the macros do, and saves your current setup as a backup (Saved profiles)."] =
        "Applique le profil collé dans la case aux parties cochées dans Parties. Demande d'abord, liste ce que font les macros et garde ta configuration actuelle en sauvegarde (Profils enregistrés).",
    ["Select all"] = "Tout sélectionner",
    ["Empty the box"] = "Vider la case",
    ["Save as profile"] = "Enregistrer comme profil",
    ["Name"] = "Nom",
    ["Load"] = "Charger",
    ["Rename"] = "Renommer",
    ["Class"] = "Classe",
    ["Size"] = "Taille",
    ["Sort"] = "Tri",
    ["Newest first"] = "Plus récents d'abord",
    ["By name"] = "Par nom",
    ["By class"] = "Par classe",
    ["My class only"] = "Ma classe seulement",
    ["No saved profile yet: export, then Save as profile."] = "Aucun profil enregistré : exporte, puis Enregistrer comme profil.",
    ["Backup before import, %s"] = "Sauvegarde avant import, %s",
    ["Export and Import cover the parts ticked here (for this session; everything is ticked after a /reload)."] =
        "Exporter et Importer portent sur les parties cochées ici (pour cette session ; tout est coché après un /reload).",
    ["Action bars"] = "Barres d'action",
    ["Main bar, page 1"] = "Barre principale, page 1",
    ["Main bar, page 2"] = "Barre principale, page 2",
    ["Bottom left bar"] = "Barre en bas à gauche",
    ["Bottom right bar"] = "Barre en bas à droite",
    ["Right bar"] = "Barre de droite",
    ["Right bar 2"] = "Barre de droite 2",
    ["Stance / form bar %d"] = "Barre de posture / forme %d",
    ["Action bar %d"] = "Barre d'action %d",
    ["Macros and keys"] = "Macros et touches",
    ["General macros"] = "Macros générales",
    ["Character macros"] = "Macros du personnage",
    ["Key bindings"] = "Raccourcis clavier",
    ["Pet bar"] = "Barre du familier",
    ["Click bindings"] = "Raccourcis de clic",
    ["These delete without a backup and are refused in combat. Each one asks first."] =
        "Ces outils suppriment sans sauvegarde et sont refusés en combat. Chacun demande d'abord.",
    ["Allow deleting before an import"] = "Autoriser la suppression avant un import",
    ["Shows the choices below: delete your macros or key bindings just before the next import (the profile's own then come alone, with no duplicate)."] =
        "Affiche les choix ci-dessous : supprimer tes macros ou tes raccourcis juste avant le prochain import (ceux du profil arrivent alors seuls, sans doublon).",
    ["Before the next import, delete:"] = "Avant le prochain import, supprimer :",
    ["Unticked again after each import. The chosen action bars need nothing: what the profile does not hold is emptied anyway."] =
        "Décochés à nouveau après chaque import. Rien à faire pour les barres d'action choisies : ce que le profil ne contient pas est vidé de toute façon.",
    ["Empty every action bar"] = "Vider toutes les barres d'action",
    ["Delete every key binding"] = "Supprimer tous les raccourcis",
    ["Delete every macro"] = "Supprimer toutes les macros",
    ["Empty every action bar? There is no backup."] = "Vider toutes les barres d'action ? Il n'y a pas de sauvegarde.",
    ["Delete every key binding? There is no backup."] = "Supprimer tous les raccourcis clavier ? Il n'y a pas de sauvegarde.",
    ["Delete every macro (general and character)? There is no backup."] =
        "Supprimer toutes les macros (générales et du personnage) ? Il n'y a pas de sauvegarde.",
    ["Not in combat: your bars, macros and key bindings cannot change during a fight."] =
        "Pas en combat : tes barres, macros et raccourcis ne peuvent pas changer pendant un combat.",
    ["Import this Myslot profile? It replaces the parts ticked in Parts; your current setup is saved first (Saved profiles)."] =
        "Importer ce profil Myslot ? Il remplace les parties cochées dans Parties ; ta configuration actuelle est d'abord sauvegardée (Profils enregistrés).",
    ["Myslot: the backup failed, nothing imported (%s)."] = "Myslot : la sauvegarde a échoué, rien d'importé (%s).",
    ["Exported: %d action slot(s), %d macro(s), %d key binding(s). Ctrl+C to copy."] =
        "Exporté : %d emplacement(s) d'action, %d macro(s), %d raccourci(s). Ctrl+C pour copier.",
    ["Profile read: %d action slot(s), %d macro(s), %d key binding(s)."] =
        "Profil lu : %d emplacement(s) d'action, %d macro(s), %d raccourci(s).",
    ["Nothing ticked in Parts."] = "Rien n'est coché dans Parties.",
    ["Type a name first."] = "Tape d'abord un nom.",
    ["The box is empty."] = "La case est vide.",
    ["Replace the profile \"%s\" with the text of the box?"] = "Remplacer le profil « %s » par le texte de la case ?",
    ["Profile \"%s\" saved."] = "Profil « %s » enregistré.",
    ["100 profiles at most: delete one first."] = "100 profils au plus : supprimes-en un d'abord.",
    ["4 MB of saved profiles at most: delete one first."] = "4 Mo de profils enregistrés au plus : supprimes-en un d'abord.",
    ["Select a profile in the list first."] = "Choisis d'abord un profil dans la liste.",
    ["Delete the profile \"%s\"?"] = "Supprimer le profil « %s » ?",
    ["Myslot: the profile is in the box of the Myslot tab, click Import to apply it."] =
        "Myslot : le profil est dans la case de l'onglet Myslot, clique sur Importer pour l'appliquer.",
})

local MAX_PROFILES, MAX_BACKUPS = 100, 3
local ui = {}
-- session choices: what Export / Import leave alone (ns.Read / ns.Restore), what the next import deletes first
local skip = { bars = {} }
local clearNext = {}

local function db() return ns.db end

local function Status(text, bad)
    if not ui.status then return end
    ui.status:SetText(text or "")
    if bad then ui.status:SetTextColor(1, 0.4, 0.4) else ui.status:SetTextColor(0.75, 0.75, 0.75) end
end

local function Counts(msg)
    return #(msg.slot or {}), #(msg.macro or {}), #(msg.bind or {})
end

-- a copy of the session's choices, the one an import or a backup works with
local function Skip()
    local s = {}
    for k, v in pairs(skip) do s[k] = v end
    s.bars = {}
    for k, v in pairs(skip.bars) do s.bars[k] = v end
    return s
end

local function NothingTicked()
    for page = 1, 15 do if not skip.bars[page] then return false end end
    return skip.account and skip.character and skip.bindings and (skip.pet or not ns.HasPetBar())
        and (skip.clicks or not ns.HasClickBindings())
end

-- a name the player typed, as saved: no escape code or control character, 60 bytes at most
local function CleanName(s)
    s = strtrim((tostring(s or ""):gsub("[%c|]", " ")))
    return W.CutUTF8(s, 60)
end

---------------------------------------------------------------------------
-- Profile: export, import
---------------------------------------------------------------------------
local function Export()
    if InCombatLockdown() then Status(L("Not in combat: your bars, macros and key bindings cannot change during a fight."), true); return end
    if NothingTicked() then Status(L("Nothing ticked in Parts."), true); return end
    local ok, text, msg = pcall(ns.Export, Skip())
    if not ok then geterrorhandler()(text); return end
    ui.box:SetText(text)
    ui.box:SetFocus()
    ui.box:HighlightText()
    Status(L("Exported: %d action slot(s), %d macro(s), %d key binding(s). Ctrl+C to copy."):format(Counts(msg)))
end

local function RefreshSaved() if ui.refreshSaved then ui.refreshSaved() end end

-- the confirmation's Yes: a backup of what the import replaces, the deletions asked for, then the profile, all in this
-- click
local function Apply(msg)
    if InCombatLockdown() then Status(L("Not in combat: your bars, macros and key bindings cannot change during a fight."), true); return end
    local s = Skip()
    local ok, backup = pcall(ns.Export, s)
    if not ok or type(backup) ~= "string" then
        ns.Print(L("Myslot: the backup failed, nothing imported (%s)."):format(tostring(backup)))
        return
    end
    local backups = db().backups
    backups[#backups + 1] = { value = backup, time = time() }
    while #backups > MAX_BACKUPS do table.remove(backups, 1) end
    if db().allowClear then
        if clearNext.general or clearNext.character then ns.Clear("MACRO", nil, clearNext.general, clearNext.character) end
        if clearNext.bindings then ns.Clear("BINDING") end
    end
    -- for this import only (they stayed ticked, and the next import deleted what nobody chose to)
    clearNext.general, clearNext.character, clearNext.bindings = false, false, false
    for _, c in ipairs(ui.clearChecks or {}) do c:Sync() end
    local done, err = pcall(ns.Restore, msg, s)
    if not done then geterrorhandler()(err) end
    RefreshSaved()
end

local function Import()
    if InCombatLockdown() then Status(L("Not in combat: your bars, macros and key bindings cannot change during a fight."), true); return end
    local text = ui.box:GetText()
    if text == "" then Status(L("The box is empty."), true); return end
    local msg, why = ns.Parse(text)
    if not msg then Status(why, true); return end
    if NothingTicked() then Status(L("Nothing ticked in Parts."), true); return end
    Status(L("Profile read: %d action slot(s), %d macro(s), %d key binding(s)."):format(Counts(msg)))
    -- the whole list in the chat, the first lines in the question
    ns.Print((ns.Risky(msg, 200)))
    local risk, flagged = ns.Risky(msg, 5)
    W.Confirm(L("Import this Myslot profile? It replaces the parts ticked in Parts; your current setup is saved first (Saved profiles).")
        .. "\n\n" .. (flagged and ("|cffff6060" .. risk .. "|r") or risk), function() Apply(msg) end, L("Import"))
end

local function SaveAs()
    local name = CleanName(ui.name:GetText())
    if name == "" then Status(L("Type a name first."), true); return end
    local text = ui.box:GetText()
    if text == "" then Status(L("The box is empty."), true); return end
    if #text > ns.MAX_TEXT then Status(L("The text is too long to be a Myslot profile (500 KB at most)."), true); return end
    local exports = db().exports
    local function Saved()
        Status(L("Profile \"%s\" saved."):format(name))
        RefreshSaved()
    end
    local size, same = #text, nil -- the profiles once this one is saved
    for _, e in ipairs(exports) do
        if e.name == name and not same then same = e else size = size + #e.value end
    end
    if size > ns.MAX_SAVED then Status(L("4 MB of saved profiles at most: delete one first."), true); return end
    if same then
        W.Confirm(L("Replace the profile \"%s\" with the text of the box?"):format(name), function()
            same.value, same.class = text, select(2, UnitClass("player"))
            Saved()
        end, L("Save"))
        return
    end
    if #exports >= MAX_PROFILES then Status(L("100 profiles at most: delete one first."), true); return end
    exports[#exports + 1] = { name = name, value = text, class = select(2, UnitClass("player")) }
    Saved()
end

-- a text into the box, the Profile sub-tab shown (Saved profiles > Load, /wl myslot load)
function ns.ShowText(text)
    if not ui.box then ns.pendingText = text; return end
    ui.sub:Select(1)
    ui.box:SetText(text or "")
    Status("")
end

---------------------------------------------------------------------------
-- Saved profiles
---------------------------------------------------------------------------
local selected -- { kind = "export" | "backup", index = i }

local function ClassText(token)
    if not token then return "" end
    local name = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token] or token
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
    return color and color.colorStr and ("|c" .. color.colorStr .. name .. "|r") or name
end

local function Size(value) return string.format("%.1f KB", #(value or "") / 1024) end

-- the rows: the named exports (sorted, filtered), then the backups (newest first)
local function Rows()
    local exports, backups, rows = db().exports, db().backups, {}
    local _, myClass = UnitClass("player")
    local order = {}
    for i, e in ipairs(exports) do
        if not (db().myClass and e.class and e.class ~= myClass) then order[#order + 1] = i end
    end
    local function ByName(a, b)
        local x, y = (exports[a].name or ""):lower(), (exports[b].name or ""):lower()
        if x == y then return a < b end
        return x < y
    end
    if db().sort == "name" then
        table.sort(order, ByName)
    elseif db().sort == "class" then
        table.sort(order, function(a, b)
            local x, y = exports[a].class, exports[b].class
            if x ~= y then
                if not x then return false end
                if not y then return true end
                return x < y
            end
            return ByName(a, b)
        end)
    else
        for i = 1, math.floor(#order / 2) do order[i], order[#order - i + 1] = order[#order - i + 1], order[i] end
    end
    local function Mark(kind, i, text)
        if selected and selected.kind == kind and selected.index == i then return "|cffffd100" .. text .. "|r" end
        return text
    end
    for _, i in ipairs(order) do
        local e = exports[i]
        rows[#rows + 1] = { kind = "export", index = i, cells = { Mark("export", i, e.name or "?"), ClassText(e.class), Size(e.value) } }
    end
    for i = #backups, 1, -1 do
        local b = backups[i]
        local when = date("%d/%m %H:%M", tonumber(b.time) or 0)
        rows[#rows + 1] = { kind = "backup", index = i, cells = { Mark("backup", i, L("Backup before import, %s"):format(when)), "", Size(b.value) } }
    end
    return rows
end

local function Selected()
    if not selected then return nil end
    local list = selected.kind == "export" and db().exports or db().backups
    return list[selected.index]
end

local function BuildSaved(f)
    local sort = W.Cycle(f, 190, { { "date", L("Newest first") }, { "name", L("By name") }, { "class", L("By class") } },
        function() return db().sort end, function(v) db().sort = v; RefreshSaved() end)
    sort:SetPoint("TOPLEFT", 12, -8)
    local mine = W.Check(f, L("My class only"), function() return db().myClass end, function(v) db().myClass = v; RefreshSaved() end)
    mine:SetPoint("LEFT", sort, "RIGHT", 16, 0)
    local list = W.Table(f, { { L("Name"), 420 }, { L("Class"), 140 }, { L("Size"), 90, "RIGHT" } }, 360)
    list:SetPoint("TOPLEFT", 12, -40)
    list:SetEmptyText(L("No saved profile yet: export, then Save as profile."))
    list.onClick = function(data)
        selected = { kind = data.kind, index = data.index }
        local e = Selected()
        ui.savedName:SetText(data.kind == "export" and e and e.name or "")
        RefreshSaved()
    end
    ui.savedName = W.EditBox(f, 220, 60)
    ui.savedName:SetPoint("TOPLEFT", 18, -412)
    local load = W.Button(f, L("Load"), 100, 22, function()
        local e = Selected()
        if not e then Status(L("Select a profile in the list first."), true); return end
        ns.ShowText(e.value)
    end)
    load:SetPoint("LEFT", ui.savedName, "RIGHT", 12, 0)
    local rename = W.Button(f, L("Rename"), 100, 22, function()
        local e = Selected()
        local name = CleanName(ui.savedName:GetText())
        if not e or selected.kind ~= "export" then return end
        if name == "" then return end
        e.name = name
        RefreshSaved()
    end)
    rename:SetPoint("LEFT", load, "RIGHT", 6, 0)
    local delete = W.Button(f, L("Delete"), 100, 22, function()
        local e = Selected()
        if not e then return end
        local kind, index = selected.kind, selected.index
        local label = kind == "export" and (e.name or "?") or L("Backup before import, %s"):format(date("%d/%m %H:%M", tonumber(e.time) or 0))
        W.Confirm(L("Delete the profile \"%s\"?"):format(label), function()
            local list = kind == "export" and db().exports or db().backups
            if list[index] == e then table.remove(list, index) end -- by the profile, not the place (the list may have moved)
            selected = nil
            ui.savedName:SetText("")
            RefreshSaved()
        end, L("Delete"))
    end)
    delete:SetPoint("LEFT", rename, "RIGHT", 6, 0)
    ui.refreshSaved = function()
        if selected and not Selected() then selected = nil end
        list:SetData(Rows())
        if ui.savedButtons then
            local e = Selected()
            ui.savedButtons.load:SetEnabled(e ~= nil)
            ui.savedButtons.delete:SetEnabled(e ~= nil)
            ui.savedButtons.rename:SetEnabled(e ~= nil and selected.kind == "export")
        end
    end
    ui.savedButtons = { load = load, rename = rename, delete = delete }
end

---------------------------------------------------------------------------
-- Parts, Delete
---------------------------------------------------------------------------
local function Page(name, fallback) return tonumber(_G[name]) or fallback end

local function BuildParts(f)
    local intro = W.Label(f, L("Export and Import cover the parts ticked here (for this session; everything is ticked after a /reload)."), "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", 12, -8)
    intro:SetWidth(780)
    local bars = {
        { 1, L("Main bar, page 1") }, { 2, L("Main bar, page 2") },
        { Page("BOTTOMLEFT_ACTIONBAR_PAGE", 6), L("Bottom left bar") }, { Page("BOTTOMRIGHT_ACTIONBAR_PAGE", 5), L("Bottom right bar") },
        { Page("RIGHT_ACTIONBAR_PAGE", 3), L("Right bar") }, { Page("LEFT_ACTIONBAR_PAGE", 4), L("Right bar 2") },
    }
    for i = 1, 4 do bars[#bars + 1] = { 6 + i, L("Stance / form bar %d"):format(i) } end
    for i, key in ipairs({ "MULTIBAR_5_ACTIONBAR_PAGE", "MULTIBAR_6_ACTIONBAR_PAGE", "MULTIBAR_7_ACTIONBAR_PAGE" }) do
        local page = tonumber(_G[key])
        if page then bars[#bars + 1] = { page, L("Action bar %d"):format(5 + i) } end
    end
    local head = W.Label(f, L("Action bars"), "GameFontNormal")
    head:SetPoint("TOPLEFT", 12, -36)
    for i, b in ipairs(bars) do
        local page = b[1]
        local c = W.Check(f, b[2], function() return not skip.bars[page] end, function(v) skip.bars[page] = not v end)
        c:SetPoint("TOPLEFT", 12 + (i > 7 and 260 or 0), -56 - ((i - 1) % 7) * 26)
    end
    local head2 = W.Label(f, L("Macros and keys"), "GameFontNormal")
    head2:SetPoint("TOPLEFT", 540, -36)
    local others = { { "account", L("General macros") }, { "character", L("Character macros") }, { "bindings", L("Key bindings") } }
    if ns.HasPetBar() then others[#others + 1] = { "pet", L("Pet bar") } end
    if ns.HasClickBindings() then others[#others + 1] = { "clicks", L("Click bindings") } end
    for i, o in ipairs(others) do
        local key = o[1]
        local c = W.Check(f, o[2], function() return not skip[key] end, function(v) skip[key] = not v end)
        c:SetPoint("TOPLEFT", 540, -56 - (i - 1) * 26)
    end
end

local function AskDelete(text, fn)
    W.Confirm(text, function()
        if InCombatLockdown() then ns.Print(L("Not in combat: your bars, macros and key bindings cannot change during a fight.")); return end
        fn()
    end, L("Delete"))
end

-- /wl myslot clear action | macro | binding
function ns.AskClear(what)
    if what == "action" then
        local all = {}
        for page = 1, 15 do all[page] = true end
        AskDelete(L("Empty every action bar? There is no backup."), function() ns.Clear("ACTION", all) end)
    elseif what == "binding" then
        AskDelete(L("Delete every key binding? There is no backup."), function() ns.Clear("BINDING") end)
    elseif what == "macro" then
        AskDelete(L("Delete every macro (general and character)? There is no backup."), function() ns.Clear("MACRO", nil, true, true) end)
    else
        return false
    end
    return true
end

local function BuildDelete(f)
    local warn = W.Label(f, L("These delete without a backup and are refused in combat. Each one asks first."), "GameFontHighlightSmall")
    warn:SetPoint("TOPLEFT", 12, -8)
    warn:SetTextColor(1, 0.5, 0.5)
    ui.clearChecks = {}
    local function Sync() for _, c in ipairs(ui.clearChecks) do c:SetEnabled(db().allowClear and true or false) end end
    local allow = W.Check(f, L("Allow deleting before an import"), function() return db().allowClear end, function(v)
        db().allowClear = v
        if not v then clearNext.general, clearNext.character, clearNext.bindings = false, false, false end
        for _, c in ipairs(ui.clearChecks) do c:Sync() end
        Sync()
    end, { L("Shows the choices below: delete your macros or key bindings just before the next import (the profile's own then come alone, with no duplicate).") })
    allow:SetPoint("TOPLEFT", 12, -32)
    local head = W.Label(f, L("Before the next import, delete:"), "GameFontHighlightSmall")
    head:SetPoint("TOPLEFT", 40, -62)
    for i, o in ipairs({ { "general", L("General macros") }, { "character", L("Character macros") }, { "bindings", L("Key bindings") } }) do
        local key = o[1]
        local c = W.Check(f, o[2], function() return clearNext[key] end, function(v) clearNext[key] = v end)
        c:SetPoint("TOPLEFT", 36, -78 - (i - 1) * 24)
        ui.clearChecks[#ui.clearChecks + 1] = c
    end
    f:HookScript("OnShow", Sync)
    Sync()
    local note = W.Label(f, L("Unticked again after each import. The chosen action bars need nothing: what the profile does not hold is emptied anyway."), "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", 40, -154)
    note:SetWidth(740)
    local y = -190
    for _, b in ipairs({ { L("Empty every action bar"), "action" }, { L("Delete every key binding"), "binding" }, { L("Delete every macro"), "macro" } }) do
        local what = b[2]
        W.Button(f, b[1], 240, 24, function() ns.AskClear(what) end):SetPoint("TOPLEFT", 12, y)
        y = y - 30
    end
end

---------------------------------------------------------------------------
-- The tab
---------------------------------------------------------------------------
function ns.BuildTab(p)
    local sub = W.SubTabs(p, { L("Profile"), L("Saved profiles"), L("Parts"), L("Delete") }, function(i)
        if i == 2 then RefreshSaved() end
    end, -72)
    ui.sub = sub
    local f = sub.frames[1]
    local bg, box = W.MultiEdit(f, 600, 400)
    bg:SetPoint("TOPLEFT", 12, -8)
    ui.box = box
    ui.status = W.Label(f, "", "GameFontHighlightSmall")
    ui.status:SetPoint("TOPLEFT", bg, "BOTTOMLEFT", 2, -8)
    ui.status:SetWidth(600)
    local x = 628
    W.Button(f, L("Export"), 170, 24, Export,
        { L("Writes your action bars, macros and key bindings (the parts ticked in Parts) as a text in the box: copy it with Ctrl+C.") })
        :SetPoint("TOPLEFT", x, -8)
    W.Button(f, L("Import"), 170, 24, Import,
        { L("Applies the profile pasted in the box to the parts ticked in Parts. It asks first, lists what the macros do, and saves your current setup as a backup (Saved profiles).") })
        :SetPoint("TOPLEFT", x, -38)
    W.Button(f, L("Select all"), 170, 22, function() box:SetFocus(); box:HighlightText() end):SetPoint("TOPLEFT", x, -78)
    W.Button(f, L("Empty the box"), 170, 22, function() box:SetText(""); Status("") end):SetPoint("TOPLEFT", x, -104)
    local saveHead = W.Label(f, L("Save as profile"), "GameFontNormal")
    saveHead:SetPoint("TOPLEFT", x, -146)
    ui.name = W.EditBox(f, 164, 60)
    ui.name:SetPoint("TOPLEFT", x + 4, -166)
    ui.name:SetScript("OnEnterPressed", function(self) self:ClearFocus(); SaveAs() end)
    W.Button(f, L("Save"), 170, 22, SaveAs):SetPoint("TOPLEFT", x, -192)
    BuildSaved(sub.frames[2])
    BuildParts(sub.frames[3])
    BuildDelete(sub.frames[4])
    sub:Select(1)
    if ns.pendingText then
        ns.ShowText(ns.pendingText)
        ns.pendingText = nil
    end
end
