-- WarLegend RaidTool - Bugs
-- The Lua errors of the WarLegend addons (WarLegendRaidTool, _Raid, _PvP) caught by BugGrabber, formatted with
-- the versions and the zone, ready to copy for the guild's bug channel. /wl bugs
-- Nothing runs until BugGrabber reports an error ("BugGrabber.BugGrabbed", the signal BugSack uses).
local W = WLRT
local L = W.L

local MAX_ERRORS = 30
local STACK_LINES = 8
local errors = {} -- this session: { key = message, text = formatted report, counter = n }
local notified = false
local refresh -- set when the tab is built

W.AddFR({
    ["Bugs"] = "Bugs",
    ["Errors of the WaR LegenD addons this session. Select all, copy (Ctrl+C) and paste in the guild's bug channel."] =
        "Erreurs des addons WaR LegenD de cette session. Tout sélectionner, copier (Ctrl+C) et coller dans le salon bugs de la guilde.",
    ["BugGrabber is not installed: install BugGrabber and BugSack to record the errors."] =
        "BugGrabber n'est pas installé : installe BugGrabber et BugSack pour enregistrer les erreurs.",
    ["No error of the WaR LegenD addons this session."] = "Aucune erreur des addons WaR LegenD dans cette session.",
    ["Select all"] = "Tout sélectionner",
    ["Refresh"] = "Actualiser",
    ["Clear"] = "Effacer",
    ["A WaR LegenD error was recorded: /wl bugs to copy it."] = "Une erreur WaR LegenD a été enregistrée : /wl bugs pour la copier.",
})

local function IsOurs(err)
    local text = (err.message or "") .. (err.stack or "")
    return text:find("WarLegendRaidTool", 1, true) ~= nil
end

local function AddonVersion(name)
    local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return (meta and meta(name, "Version")) or "-"
end

-- text shown in an EditBox: "|" starts escape codes there, "||" shows it
local function Plain(s)
    return (tostring(s or ""):gsub("|", "||"))
end

local function Format(err)
    local gameVersion, build = GetBuildInfo()
    local zone = W.Safe(GetRealZoneText and GetRealZoneText()) or "?"
    -- BugGrabber stores the time as text ("2026/11/05 20:31:12"): date() would raise on it
    local when = type(err.time) == "number" and date("%Y-%m-%d %H:%M", err.time) or tostring(err.time or date("%Y-%m-%d %H:%M"))
    local lines = {
        ("[WaR LegenD %s | Raid %s | PvP %s | WoW %s (%s) | %s | %s] x%d"):format(W.version,
            AddonVersion("WarLegendRaidTool_Raid"), AddonVersion("WarLegendRaidTool_PvP"), tostring(gameVersion),
            tostring(build), zone, when, tonumber(err.counter) or 1),
        Plain(err.message),
    }
    local n = 0
    for line in tostring(err.stack or ""):gmatch("[^\n]+") do
        n = n + 1
        if n > STACK_LINES then break end
        lines[#lines + 1] = "  " .. Plain(line)
    end
    return table.concat(lines, "\n")
end

local function Remember(err)
    if not err or not IsOurs(err) then return end
    for _, e in ipairs(errors) do
        if e.key == err.message then -- the same error again: keep the latest count
            e.counter, e.text = err.counter, Format(err)
            return
        end
    end
    if #errors >= MAX_ERRORS then table.remove(errors, 1) end
    errors[#errors + 1] = { key = err.message, counter = err.counter, text = Format(err) }
    if not notified then
        notified = true
        W.Print(L("A WaR LegenD error was recorded: /wl bugs to copy it."))
    end
end

-- errors of this session already in BugGrabber (caught before this file was loaded, or before the tab opened)
local function Collect()
    if not (BugGrabber and BugGrabber.GetDB and BugGrabber.GetSessionId) then return end
    local session = BugGrabber:GetSessionId()
    for _, err in ipairs(BugGrabber:GetDB() or {}) do
        if err.session == session then pcall(Remember, err) end -- one odd entry must not leave the box empty
    end
end

if EventRegistry and EventRegistry.RegisterCallback then
    -- pcall: an error raised here would be caught by BugGrabber, reported here again, and loop
    EventRegistry:RegisterCallback("BugGrabber.BugGrabbed", function(_, errorID)
        if not (BugGrabber and BugGrabber.GetErrorByID) then return end
        pcall(function() Remember(BugGrabber:GetErrorByID(errorID)) end)
        if refresh then pcall(refresh) end
    end, {})
end

W.slash.bugs = function() W.Toggle("Bugs") end

W.RegisterModule("Bugs", "Bugs", function(p)
    W.Title(p, L("Bugs"))
    if not BugGrabber then
        local label = W.Label(p, L("BugGrabber is not installed: install BugGrabber and BugSack to record the errors."), "GameFontDisable")
        label:SetPoint("TOPLEFT", 16, -44)
        label:SetWidth(600)
        return
    end
    local help = W.Label(p, L("Errors of the WaR LegenD addons this session. Select all, copy (Ctrl+C) and paste in the guild's bug channel."), "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", 16, -40)
    help:SetWidth(640)

    local frame, box = W.MultiEdit(p, 640, 420)
    frame:SetPoint("TOPLEFT", 16, -64)

    refresh = function()
        if #errors == 0 then
            box:SetText(L("No error of the WaR LegenD addons this session."))
            return
        end
        local parts = {}
        for i = #errors, 1, -1 do parts[#parts + 1] = errors[i].text end -- newest first
        box:SetText(table.concat(parts, "\n\n"))
    end

    W.Button(p, L("Select all"), 130, 22, function()
        box:SetFocus()
        box:HighlightText()
    end):SetPoint("TOPLEFT", 16, -492)
    W.Button(p, L("Refresh"), 110, 22, function() Collect(); refresh() end):SetPoint("TOPLEFT", 152, -492)
    W.Button(p, L("Clear"), 110, 22, function() wipe(errors); refresh() end):SetPoint("TOPLEFT", 268, -492)

    Collect()
    refresh()
    p:HookScript("OnShow", function() Collect(); refresh() end)
end)
