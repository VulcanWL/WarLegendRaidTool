-- WarLegend RaidTool - Settings
-- General: the options of the addon as a whole (minimap button, preload, countdown voice, overlap), which
-- otherwise only had a /wl command. Modules: switch any module fully off (no events, no addon messages, no
-- test). Profile: every setting as one line of text to copy (export) and paste on another character or for
-- another player (import).
local W = WLRT
W.AddFR({
    ["General"] = "Général",
    ["Options of the addon as a whole. The style and the language are the two buttons in the header of this window."] =
        "Options de l'addon dans son ensemble. Le style et la langue sont les deux boutons de l'en-tête de cette fenêtre.",
    ["Minimap button"] = "Bouton de la minicarte",
    ["Load the raid modules at the loading screen (no freeze at the first /wl, a little more memory when alone)"] =
        "Charger les modules de raid pendant l'écran de chargement (pas de gel au premier /wl, un peu plus de mémoire en solo)",
    ["Use our features even when another addon already provides them (Naowh Forever, EllesmereUI)"] =
        "Utiliser nos fonctions même quand un autre addon les fournit déjà (Naowh Forever, EllesmereUI)",
    ["Window and text size (also: drag the corner at the bottom right of the window):"] =
        "Taille de la fenêtre et du texte (aussi : glisse le coin en bas à droite de la fenêtre) :",
    ["Normal"] = "Normal",
    ["Countdown voice (battleground timers, duels):"] = "Voix du décompte (chronos de BG, duels) :",
    ["Settings"] = "Réglages",
    ["Modules"] = "Modules",
    ["Profile"] = "Profil",
    ["Untick a module to switch it fully off: it no longer gets events or messages and costs no CPU. What it already shows goes away at the next /reload."] =
        "Décoche un module pour l'éteindre complètement : il ne reçoit plus d'événements ni de messages et ne coûte plus de CPU. Ce qu'il affiche déjà disparaît au prochain /reload.",
    ["Reload"] = "Recharger",
    ["Reload to clear what the switched off modules still show."] = "Recharger pour effacer ce que les modules éteints affichent encore.",
    ["Export"] = "Exporter",
    ["Import"] = "Importer",
    ["Export: every setting of the addon (and of the battleground frames) in the box below. Copy it with Ctrl+C and share it (Discord...). Import: paste a profile in the box (Ctrl+V), then Import. Data (history, members, presets, characters) is never in a profile."] =
        "Exporter : tous les réglages de l'addon (et des cadres de BG) dans la case ci-dessous. Copie-les avec Ctrl+C et partage-les (Discord...). Importer : colle un profil dans la case (Ctrl+V), puis Importer. Les données (historiques, membres, presets, personnages) ne sont jamais dans un profil.",
    ["Profile ready: Ctrl+C to copy it (%d characters)."] = "Profil prêt : Ctrl+C pour le copier (%d caractères).",
    ["This is not a WaR LegenD RaidTool profile."] = "Ce n'est pas un profil WaR LegenD RaidTool.",
    ["The profile text is damaged: copy it again, all of it."] = "Le texte du profil est abîmé : copie-le à nouveau, en entier.",
    ["Replace your settings with this profile?"] = "Remplacer tes réglages par ce profil ?",
    ["Profile imported: reload to apply it."] = "Profil importé : recharge pour l'appliquer.",
    ["Not in combat."] = "Pas en combat.",
    ["This profile also:"] = "Ce profil, en plus :",
    ["%d macro line(s) that run code (/run, /script...) removed"] = "%d ligne(s) de macro qui exécutent du code (/run, /script...) retirée(s)",
    ["invites whoever whispers the keyword"] = "invite quiconque chuchote le mot-clé",
    ["accepts the invites suggested by the group"] = "accepte les invitations suggérées par le groupe",
    ["accepts group invites from friends and guild"] = "accepte les invitations de groupe des amis et de la guilde",
    ["repairs with the guild bank money"] = "répare avec l'argent de la banque de guilde",
    ["sells grey items at vendors"] = "vend les objets gris chez les marchands",
    ["answers the readiness checks of any group leader"] = "répond aux vérifications de n'importe quel chef de groupe",
    ["shares your position with the guild"] = "partage ta position avec la guilde",
    ["sets %d game option(s) at every login: %s"] = "règle %d option(s) du jeu à chaque connexion : %s",
    ["promotes to assistant: %d name(s) or rank(s)"] = "promeut assistant : %d nom(s) ou rang(s)",
})
local L = W.L

---------------------------------------------------------------------------
-- Text format: T / F, n<number>~, s<text>~, {key value key value ...}. ^ ~ | and line breaks are
-- escaped: the text is one line, safe in an edit box and in a chat or Discord message.
---------------------------------------------------------------------------
local HEADER = "WLRT1:"
local ESC = { ["^"] = "^^", ["~"] = "^t", ["|"] = "^p", ["\n"] = "^n" }
local UNESC = { ["^"] = "^", t = "~", p = "|", n = "\n" }
local SCALAR = { boolean = true, number = true, string = true }

local function Write(v, out)
    local t = type(v)
    if t == "boolean" then
        out[#out + 1] = v and "T" or "F"
    elseif t == "number" then
        out[#out + 1] = "n" .. tostring(v) .. "~"
    elseif t == "string" then
        out[#out + 1] = "s" .. (v:gsub("[%^~|\n]", ESC)) .. "~"
    elseif t == "table" then
        out[#out + 1] = "{"
        for k, x in pairs(v) do
            local kt = type(k)
            if (kt == "string" or kt == "number") and (SCALAR[type(x)] or type(x) == "table") then
                Write(k, out)
                Write(x, out)
            end
        end
        out[#out + 1] = "}"
    end
end

-- limits of a profile: a text from outside never builds an unbounded table or a number the interface cannot take
-- (saved dates are about 1.8e9: the number limit stays far above them, a long name list stays under the string one)
local MAX_ENTRIES, MAX_STRING, MAX_NUMBER = 20000, 20000, 1e12
local entries = 0

local function Read(s, i, depth)
    entries = entries + 1
    if entries > MAX_ENTRIES then error("size") end
    local c = s:sub(i, i)
    if c == "T" then return true, i + 1 end
    if c == "F" then return false, i + 1 end
    if c == "n" or c == "s" then
        local j = s:find("~", i + 1, true)
        if not j then error("cut") end
        local raw = s:sub(i + 1, j - 1)
        if c == "n" then
            local n = tonumber(raw)
            if not n or n ~= n or n > MAX_NUMBER or n < -MAX_NUMBER then error("number") end
            return n, j + 1
        end
        if #raw > MAX_STRING then error("string") end
        return (raw:gsub("%^(.)", UNESC)), j + 1
    end
    if c == "{" then
        if depth > 8 then error("depth") end
        local t = {}
        i = i + 1
        while s:sub(i, i) ~= "}" do
            if i > #s then error("cut") end
            local k, v
            k, i = Read(s, i, depth + 1)
            if type(k) ~= "string" and type(k) ~= "number" then error("key") end
            v, i = Read(s, i, depth + 1)
            t[k] = v
        end
        return t, i + 1
    end
    error("bad")
end

---------------------------------------------------------------------------
-- What a profile holds: the scalar values of every module (its options), plus the tables that are
-- options too (positions, rank and module choices...). Everything else is data and never leaves.
---------------------------------------------------------------------------
local SKIP = { schema = true, minimap = true }
-- saved scalars that are state, not options (this window's place, the language of this client...)
local SKIP_FIELDS = {
    ui = { lastModule = true, category = true, openSection = true, openSection_me = true, openSection_options = true, point = true, relPoint = true, x = true, y = true, lang = true },
    guild = { last = true, sel = true, profFilter = true, profMin = true, profMax = true, profSort = true, profSortDesc = true, profOnline = true },
    cooldownText = { previous = true },
    roster = { remindDay = true },
    bgStats = { recordMap = true },
    inviteTool = { offByDefault = true },
    raidGroups = { migrated = true, selected = true },
    dangerAlert = { logClass = true },
}
-- tables that are options: "point" / "emphPoint" in any module (a frame position), and these.
-- A new option saved as a table goes here, or it is not in the profiles.
local TABLE_FIELDS = {
    ui = { off = true },
    autoPromote = { names = true, ranks = true },
    inviteTool = { ranks = true },
    guild = { msgs = true },
    auras = { pos = true },
    raidGroups = { sortGroups = true },
    raidCooldowns = { spells = true },
    checklist = { items = true },
    moveFrames = { winPos = true, winScale = true, elemPos = true, tipPoint = true },
    interfaceOptions = { cvars = true },
    classes = { leaders = true },
    dangerAlert = { framesPoint = true },
}
local function IsTableOption(key, field)
    return field == "point" or field == "emphPoint" or (TABLE_FIELDS[key] and TABLE_FIELDS[key][field]) or false
end

local function Copy(v, depth)
    if type(v) ~= "table" then return SCALAR[type(v)] and v or nil end
    if depth > 6 then return nil end
    local out = {}
    for k, x in pairs(v) do
        if type(k) == "string" or type(k) == "number" then out[k] = Copy(x, depth + 1) end
    end
    return out
end

local function Collect()
    local main = {}
    for key, t in pairs(W.db) do
        if type(key) == "string" and type(t) == "table" and not SKIP[key] then
            local skip, out, any = SKIP_FIELDS[key] or {}, {}, false
            for f, v in pairs(t) do
                if type(f) == "string" and not skip[f] then
                    if SCALAR[type(v)] then
                        out[f], any = v, true
                    elseif type(v) == "table" and IsTableOption(key, f) then
                        out[f], any = Copy(v, 1), true
                    end
                end
            end
            if any then main[key] = out end
        end
    end
    local data = { main = main }
    -- the battleground frames keep their own saved file, read once their addon is loaded
    if type(WarLegendRaidTool_PvPDB) == "table" then data.pvp = Copy(WarLegendRaidTool_PvPDB, 1) end
    return data
end

local function Export()
    if W.LoadPvP and not InCombatLockdown() then W.LoadPvP() end
    local out = {}
    Write(Collect(), out)
    return HEADER .. table.concat(out)
end

local function Parse(text)
    -- no line break in a profile: the ones a chat or Discord adds when copying are dropped, the ends trimmed
    text = ((text or ""):gsub("[\r\n]", "")):match("^%s*(.-)%s*$")
    if text:sub(1, #HEADER) ~= HEADER then return nil, L("This is not a WaR LegenD RaidTool profile.") end
    if #text > 300000 then return nil, L("The profile text is damaged: copy it again, all of it.") end
    entries = 0
    local ok, data, last = pcall(Read, text, #HEADER + 1, 0)
    if not ok or type(data) ~= "table" or type(data.main) ~= "table" or last ~= #text + 1 then
        return nil, L("The profile text is damaged: copy it again, all of it.")
    end
    return data
end

-- the values are written in place: a module keeps its table, a value of another type than ours is ignored
local function Apply(data)
    for key, fields in pairs(data.main) do
        if type(key) == "string" and #key <= 40 and type(fields) == "table" and not SKIP[key] then
            local dest = W.db[key]
            if type(dest) ~= "table" then dest = {}; W.db[key] = dest end
            local skip = SKIP_FIELDS[key] or {}
            for f, v in pairs(fields) do
                if type(f) == "string" and #f <= 40 and not skip[f] then
                    if type(v) == "table" then
                        if IsTableOption(key, f) then dest[f] = v end
                    elseif dest[f] == nil or type(dest[f]) == type(v) then
                        dest[f] = v
                    end
                end
            end
        end
    end
    if type(data.pvp) == "table" and W.LoadPvP and W.LoadPvP() and type(WarLegendRaidTool_PvPDB) == "table" then
        -- merged key by key (a key of another type than ours is ignored), the saved file is never replaced whole
        local dest = WarLegendRaidTool_PvPDB
        for k, v in pairs(data.pvp) do
            if (type(k) == "string" or type(k) == "number") and (dest[k] == nil or type(dest[k]) == type(v)) then dest[k] = v end
        end
    end
end

-- Before an import: a shared profile must not act behind the player's back. The macro lines that run code
-- (/run, /script, /dump, /console, /click) are removed from it (the "Custom" clicks of the battleground frames run
-- their text as a macro), and the confirmation lists the game options (CVars) and the automatic actions it turns on.
local RUN_CMDS = { run = true, script = true, dump = true, console = true, click = true }
local function StripMacros(t, depth)
    if depth > 8 then return 0 end
    local removed = 0
    for k, v in pairs(t) do
        if type(v) == "string" and v:find("/", 1, true) then
            local kept, cut = {}, 0
            for line in (v .. "\n"):gmatch("(.-)\n") do
                local cmd = line:match("^%s*/(%S+)")
                if cmd and RUN_CMDS[cmd:lower()] then cut = cut + 1 else kept[#kept + 1] = line end
            end
            if cut > 0 then t[k] = table.concat(kept, "\n"); removed = removed + cut end
        elseif type(v) == "table" then
            removed = removed + StripMacros(v, depth + 1)
        end
    end
    return removed
end

-- { module key, field, value that acts on its own, what it does }
local RISKY = {
    { "inviteTool", "enabled", true, "invites whoever whispers the keyword" },
    { "inviteTool", "acceptSuggested", true, "accepts the invites suggested by the group" },
    { "qol", "acceptInvites", true, "accepts group invites from friends and guild" },
    { "qol", "repairGuild", true, "repairs with the guild bank money" },
    { "qol", "sellJunk", true, "sells grey items at vendors" },
    { "readiness", "answerFrom", "group", "answers the readiness checks of any group leader" },
    { "guildPositions", "share", true, "shares your position with the guild" },
}

local function Review(data)
    local lines = {}
    if type(data.pvp) == "table" then
        local cut = StripMacros(data.pvp, 1)
        if cut > 0 then lines[#lines + 1] = string.format(L("%d macro line(s) that run code (/run, /script...) removed"), cut) end
    end
    local main = data.main
    for _, r in ipairs(RISKY) do
        local t, cur = main[r[1]], W.db[r[1]]
        if type(t) == "table" and t[r[2]] == r[3] and not (type(cur) == "table" and cur[r[2]] == r[3]) then
            lines[#lines + 1] = L(r[4])
        end
    end
    local io = main.interfaceOptions
    if type(io) == "table" and type(io.cvars) == "table" then
        local mine = type(W.db.interfaceOptions) == "table" and type(W.db.interfaceOptions.cvars) == "table" and W.db.interfaceOptions.cvars or {}
        local names = {}
        for cvar, v in pairs(io.cvars) do
            if type(cvar) == "string" and mine[cvar] ~= v then names[#names + 1] = W.Plain(cvar, 40) end
        end
        table.sort(names)
        if #names > 0 then
            local shown = {}
            for i = 1, math.min(6, #names) do shown[i] = names[i] end
            lines[#lines + 1] = string.format(L("sets %d game option(s) at every login: %s"), #names,
                table.concat(shown, ", ") .. (#names > 6 and ", ..." or ""))
        end
    end
    local ap = main.autoPromote
    if type(ap) == "table" then
        local n = 0
        for _, list in ipairs({ ap.names, ap.ranks }) do
            if type(list) == "table" then for _ in pairs(list) do n = n + 1 end end
        end
        if n > 0 then lines[#lines + 1] = string.format(L("promotes to assistant: %d name(s) or rank(s)"), n) end
    end
    if #lines == 0 then return "" end
    return "\n\n|cffff9900" .. L("This profile also:") .. "|r\n- " .. table.concat(lines, "\n- ")
end

---------------------------------------------------------------------------
-- Tab
---------------------------------------------------------------------------
local UI = {}

local function BuildModules(p)
    local info = W.Label(p, L("Untick a module to switch it fully off: it no longer gets events or messages and costs no CPU. What it already shows goes away at the next /reload."),
        "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 14, -6)
    info:SetWidth(700)
    info:SetJustifyH("LEFT")
    local checks = {}
    -- the raid modules register when their addon loads: the list is completed on every show
    local function Fill()
        local list = {}
        for _, m in ipairs(W.modules) do
            if m.file and not W.CORE_MODULES[m.key] then list[#list + 1] = m end
        end
        table.sort(list, function(a, b) return L(a.label) < L(b.label) end)
        for i, m in ipairs(list) do
            local c = checks[m.key]
            if not c then
                local key = m.key
                c = W.Check(p, L(m.label), function() return not W.IsOff(key) end, function(v) W.SetModuleOn(key, v) end)
                checks[key] = c
            end
            local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", 12 + col * 240, -40 - row * 24)
            c:SetChecked(not W.IsOff(m.key))
        end
    end
    p:SetScript("OnShow", Fill)
    W.Button(p, L("Reload"), 120, 22, function() W.ConfirmReload(L("Reload to clear what the switched off modules still show.")) end)
        :SetPoint("BOTTOMLEFT", 14, 10)
end

local function BuildProfile(p)
    local info = W.Label(p, L("Export: every setting of the addon (and of the battleground frames) in the box below. Copy it with Ctrl+C and share it (Discord...). Import: paste a profile in the box (Ctrl+V), then Import. Data (history, members, presets, characters) is never in a profile."),
        "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 14, -6)
    info:SetWidth(700)
    info:SetJustifyH("LEFT")
    local bg, box = W.MultiEdit(p, 700, 300, 0)
    bg:SetPoint("TOPLEFT", 14, -80)
    UI.box = box
    W.Button(p, L("Export"), 120, 22, function()
        local text = Export()
        box:SetText(text)
        box:SetFocus()
        box:HighlightText()
        W.Print(string.format(L("Profile ready: Ctrl+C to copy it (%d characters)."), #text))
    end):SetPoint("TOPLEFT", 14, -50)
    W.Button(p, L("Import"), 120, 22, function()
        if InCombatLockdown() then W.Print(L("Not in combat.")); return end
        local data, err = Parse(box:GetText())
        if not data then W.Print(err); return end
        W.Confirm(L("Replace your settings with this profile?") .. Review(data), function()
            Apply(data)
            W.ConfirmReload(L("Profile imported: reload to apply it."))
        end)
    end):SetPoint("TOPLEFT", 140, -50)
end

-- the options of the addon as a whole (the same values as /wl minimap, /wl preload, the voice cycles of the
-- timers and the "Use it anyway" of the overlap notes: one place to find them)
local function BuildGeneral(p)
    local info = W.Label(p, L("Options of the addon as a whole. The style and the language are the two buttons in the header of this window."),
        "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 14, -6)
    info:SetWidth(700)
    info:SetJustifyH("LEFT")
    W.Check(p, L("Minimap button"), function() return not W.DB("minimap").hide end,
        function(v) W.DB("minimap").hide = not v; W.UpdateMinimap() end):SetPoint("TOPLEFT", 12, -36)
    W.Check(p, L("Load the raid modules at the loading screen (no freeze at the first /wl, a little more memory when alone)"),
        function() return W.DB("ui").preloadRaid end, function(v) W.DB("ui").preloadRaid = v end):SetPoint("TOPLEFT", 12, -60)
    W.Check(p, L("Use our features even when another addon already provides them (Naowh Forever, EllesmereUI)"),
        W.OverlapForced, W.SetOverlapForce):SetPoint("TOPLEFT", 12, -84)
    W.Label(p, L("Window and text size (also: drag the corner at the bottom right of the window):"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 16, -158)
    local sizes = { { 0.9, "90 %" }, { 1, "100 % (" .. L("Normal") .. ")" }, { 1.1, "110 %" }, { 1.2, "120 %" }, { 1.35, "135 %" }, { 1.5, "150 %" } }
    W.Cycle(p, 130, sizes, function()
        local cur, best = W.WindowScale(), 1 -- the nearest preset (the corner gives any value)
        for _, v in ipairs(sizes) do if math.abs(v[1] - cur) < math.abs(best - cur) then best = v[1] end end
        return best
    end, function(v) W.SetWindowScale(v, true) end):SetPoint("TOPLEFT", 560, -153)
    W.Label(p, L("Countdown voice (battleground timers, duels):"), "GameFontHighlightSmall"):SetPoint("TOPLEFT", 16, -122)
    W.Cycle(p, 130, W.CountdownVoiceValues(), function() return W.DB("ui").countdownVoice or "auto" end,
        function(v) W.DB("ui").countdownVoice = v; W.CountdownVoice(3) end):SetPoint("TOPLEFT", 330, -117)
end

W.RegisterModule("Settings", "Settings", function(p)
    W.Title(p, L("Settings"))
    UI.tabs = W.SubTabs(p, { L("General"), L("Modules"), L("Profile") })
    BuildGeneral(UI.tabs.frames[1])
    BuildModules(UI.tabs.frames[2])
    BuildProfile(UI.tabs.frames[3])
    UI.tabs:Select(1)
end)

local function Open(tab)
    if not W.IsShown("Settings") then W.Toggle("Settings") end
    if UI.tabs then UI.tabs:Select(tab) end
end
W.slash.modules = function() Open(2) end
W.slash.profile = function() Open(3) end
