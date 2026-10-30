-- WarLegend RaidTool - Myslot
-- Saves and restores the action bars, macros and key bindings as a text (to copy to another character or account) or as
-- named profiles. Based on Myslot 6.2.1 by Boshi Lian (Apache-2.0), made into this module on 29/10: its files are in the
-- folder Myslot/ (Codec.lua the text format, the same as Myslot's; keys.lua its key and binding lists; Myslot.lua
-- reading and restoring; Tab.lua the tab). Personal tool: it sends nothing, a profile comes in only by a paste.
local W = WLRT
local L = W.L
local ns = W.Space("Myslot")
local db

W.AddFR({
    ["Myslot: save and restore your action bars, macros and key bindings as a text, to copy to another character or account, or as named profiles. A profile pasted in the box is applied only by Import and its confirmation."] =
        "Myslot : sauvegarde et restaure tes barres d'action, macros et raccourcis sous forme de texte, à copier vers un autre personnage ou compte, ou en profils nommés. Un profil collé dans la case n'est appliqué que par Importer et sa confirmation.",
    ["Myslot is switched off in Settings > Modules."] = "Myslot est désactivé dans Réglages > Modules.",
    ["Myslot: no profile named \"%s\" (Saved profiles)."] = "Myslot : aucun profil nommé « %s » (Profils enregistrés).",
    ["Myslot: /wl myslot [load name | clear action | clear macro | clear binding]"] =
        "Myslot : /wl myslot [load nom | clear action | clear macro | clear binding]",
    ["Myslot: %d saved profile(s) removed: 100 profiles and 4 MB at most, all together."] =
        "Myslot : %d profil(s) enregistré(s) retiré(s) : 100 profils et 4 Mo au plus, en tout.",
})

-- The original addon, when enabled, loads before us (alphabetical order): it keeps its /myslot.
local originalLoaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Myslot") or false
-- saved data checked once at login (a damaged file): strings only, names without escape codes, the sizes
-- bounded (the Tab's Save stops at the same limits)
local function Sanitize(t)
    local exports, backups, size, dropped = {}, {}, 0, 0
    for _, e in ipairs(type(t.exports) == "table" and t.exports or {}) do
        if type(e) == "table" and type(e.value) == "string" and #e.value <= ns.MAX_TEXT then
            if #exports < 100 and size + #e.value <= ns.MAX_SAVED then
                size = size + #e.value
                local name = W.CutUTF8(strtrim((tostring(e.name or "?"):gsub("[%c|]", " "))), 60)
                exports[#exports + 1] = { name = name ~= "" and name or "?", value = e.value, class = type(e.class) == "string" and e.class:match("^%u+$") or nil }
            else
                dropped = dropped + 1
            end
        end
    end
    if dropped > 0 then W.Print(L("Myslot: %d saved profile(s) removed: 100 profiles and 4 MB at most, all together."):format(dropped)) end
    for _, b in ipairs(type(t.backups) == "table" and t.backups or {}) do
        if type(b) == "table" and type(b.value) == "string" and #b.value <= ns.MAX_TEXT then
            backups[#backups + 1] = { value = b.value, time = tonumber(b.time) or 0 }
        end
    end
    while #backups > 3 do table.remove(backups, 1) end
    t.exports, t.backups = exports, backups
end
ns.Sanitize = Sanitize

W.OnReady(function()
    db = W.DB("myslot", { allowClear = false, sort = "date", myClass = false })
    Sanitize(db)
    ns.db = db
end)

-- /wl myslot: the tab; load <name>: that saved profile in the box (Import applies it, after its confirmation);
-- clear action | macro | binding: asks, then deletes
W.slash.myslot = function(rest)
    if W.IsOff("Myslot") then W.Print(L("Myslot is switched off in Settings > Modules.")); return end
    local cmd, arg = strtrim(rest or ""):match("^(%S*)%s*(.-)$")
    cmd = strlower(cmd or "")
    if not db then return end
    if cmd == "load" then
        for _, e in ipairs(db.exports) do
            if e.name == arg then
                W.Toggle("Myslot")
                ns.ShowText(e.value)
                W.Print(L("Myslot: the profile is in the box of the Myslot tab, click Import to apply it."))
                return
            end
        end
        W.Print(L("Myslot: no profile named \"%s\" (Saved profiles)."):format(W.Plain(arg, 60)))
    elseif cmd == "clear" then
        if not ns.AskClear(strlower(arg or "")) then W.Print(L("Myslot: /wl myslot [load name | clear action | clear macro | clear binding]")) end
    else
        W.Toggle("Myslot")
    end
end

-- /myslot, the original addon's command, unless that addon has it
if not originalLoaded then
    SLASH_MYSLOT1 = "/myslot"
    SlashCmdList.MYSLOT = function(msg)
        if not W.Allowed() then W.Denied(); return end
        W.slash.myslot(msg)
    end
end

W.RegisterModule("Myslot", "Myslot", function(p)
    W.Title(p, "Myslot")
    local info = W.Label(p, L("Myslot: save and restore your action bars, macros and key bindings as a text, to copy to another character or account, or as named profiles. A profile pasted in the box is applied only by Import and its confirmation."), "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, -36)
    info:SetWidth(790)
    ns.BuildTab(p)
end)
