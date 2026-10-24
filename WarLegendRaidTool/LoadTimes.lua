-- WarLegend RaidTool - LoadTimes
-- How long each addon loading after WLRT takes at login (gap between two ADDON_LOADED), up to the end of the loading
-- screen. The last 5 logins are kept. Idea of OloLaunch (Olo, MIT). Personal: sends nothing.
local W = WLRT
local L = W.L
local db

W.AddFR({
    ["Load times"] = "Temps de chargement",
    ["How long each addon takes to load at login, measured from WLRT's own loading (addons loaded before it are not seen) to the end of the loading screen."] =
        "Le temps de chargement de chaque addon à la connexion, mesuré depuis le chargement de WLRT (les addons chargés avant lui ne sont pas vus) jusqu'à la fin de l'écran de chargement.",
    ["Measure load times at login"] = "Mesurer les temps de chargement à la connexion",
    ["Last login (%s): %.2f s, slowest steps:"] = "Dernière connexion (%s) : %.2f s, étapes les plus lentes :",
    ["Nothing measured yet: switch it on, then /reload."] = "Rien de mesuré : l'activer, puis /reload.",
})

local now = debugprofilestop
local start, last = now(), now()
local marks = {} -- { name, ms since the previous mark }

local f = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "LOADING_SCREEN_DISABLED" }) do
    f:RegisterEvent(e)
end
f:SetScript("OnEvent", function(self, event, arg1)
    local t = now()
    marks[#marks + 1] = { event == "ADDON_LOADED" and tostring(arg1) or event, t - last }
    last = t
    if event ~= "LOADING_SCREEN_DISABLED" then return end
    self:UnregisterAllEvents() -- later on-demand loads are not login cost
    local list = marks
    marks = nil -- nothing kept in memory when switched off
    if not (db and db.enabled) then return end
    db.history = type(db.history) == "table" and db.history or {}
    table.insert(db.history, 1, { at = date("%Y-%m-%d %H:%M"), total = t - start, marks = list })
    while #db.history > 5 do table.remove(db.history) end
end)

W.OnReady(function()
    db = W.DB("loadTimes", { enabled = false })
end)

W.RegisterModule("LoadTimes", "Load times", function(p)
    W.Title(p, L("Load times"))
    local intro = W.Label(p, L("How long each addon takes to load at login, measured from WLRT's own loading (addons loaded before it are not seen) to the end of the loading screen."), "GameFontHighlight")
    intro:SetPoint("TOPLEFT", 16, -40); intro:SetWidth(560); intro:SetJustifyH("LEFT")
    W.Check(p, L("Measure load times at login"), function() return db.enabled end, function(v) db.enabled = v end)
        :SetPoint("TOPLEFT", 16, -86)
    p.report = W.Label(p, "", "GameFontHighlightSmall")
    p.report:SetPoint("TOPLEFT", 20, -120); p.report:SetWidth(560); p.report:SetJustifyH("LEFT")
end, function(p)
    local rec = type(db.history) == "table" and db.history[1]
    if type(rec) ~= "table" or type(rec.marks) ~= "table" then p.report:SetText(L("Nothing measured yet: switch it on, then /reload.")); return end
    local sorted = {}
    for _, m in ipairs(rec.marks) do if type(m) == "table" then sorted[#sorted + 1] = m end end -- damaged file
    table.sort(sorted, function(a, b) return (a[2] or 0) > (b[2] or 0) end)
    local lines = { string.format(L("Last login (%s): %.2f s, slowest steps:"), tostring(rec.at), (tonumber(rec.total) or 0) / 1000) }
    for i = 1, math.min(15, #sorted) do
        lines[#lines + 1] = string.format("%6.0f ms  %s", tonumber(sorted[i][2]) or 0, tostring(sorted[i][1]))
    end
    p.report:SetText(table.concat(lines, "\n"))
end)
