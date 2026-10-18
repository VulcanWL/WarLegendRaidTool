-- WarLegend RaidTool - Version Check
-- Broadcasts your version to the raid, warns if a newer one exists, lists who runs what.
local W = WLRT
W.AddFR({ ["Version Check"] = "Vérification de version" })
local L = W.L
local VER, VERQ = "WLRT_VER", "WLRT_VERQ"
local known, warned = {}, false
local lastBroadcast, lastRequest = 0, 0
local UI = {}

local function Parse(v)
    local t = {}
    for n in tostring(v):gmatch("%d+") do t[#t + 1] = tonumber(n) end
    return t
end

local function Newer(a, b)
    local pa, pb = Parse(a), Parse(b)
    for i = 1, math.max(#pa, #pb) do
        local x, y = pa[i] or 0, pb[i] or 0
        if x ~= y then return x > y end
    end
    return false
end

local function Broadcast() lastBroadcast = GetTime(); W.Send(VER, W.version) end

local function Request()
    if GetTime() - lastRequest < 15 then return end
    lastRequest = GetTime()
    W.Send(VERQ, "1")
end

local function RefreshList()
    if not UI.list then return end
    -- known versions are keyed by full identity; the group gives the names to show
    local entries = { { name = W.UnitDisplayName("player") or "?", version = W.version, me = true } }
    for _, u in ipairs(W.GroupUnits()) do
        local key = W.UnitKey(u)
        if key and known[key] and not W.UnitIsMe(u) then
            entries[#entries + 1] = { name = W.UnitDisplayName(u) or "?", version = known[key] }
        end
    end
    table.sort(entries, function(a, b) return a.name < b.name end)
    local ok = 0
    for i, e in ipairs(entries) do
        local r = UI.list:Row(i)
        r.name:SetText(e.name .. (e.me and L(" (you)") or ""))
        r.ver:SetText(e.version)
        if Newer(W.version, e.version) then
            r.st:SetText(L("|cffff5555Outdated|r"))
        elseif Newer(e.version, W.version) then
            r.st:SetText(L("|cffffcc33Newer|r")); ok = ok + 1
        else
            r.st:SetText(L("|cff55ff55Up to date|r")); ok = ok + 1
        end
    end
    UI.list:Finish(#entries)
    UI.count:SetText(ok .. "/" .. #entries .. L(" up to date or newer"))
end

W.OnAddon(VER, function(msg, from, _, full)
    local unit = W.UnitByName(full or from)
    if not unit or W.UnitIsMe(unit) or msg == "" or #msg > 20 then return end
    if not msg:match("^[%w%.%-]+$") then return end -- a version number, nothing else
    known[W.UnitKey(unit)] = msg
    if Newer(msg, W.version) and not warned then
        warned = true
        W.Print(L("|cffffcc00New version available: ") .. msg .. L(" (you have ") .. W.version .. ").|r")
    end
    if W.IsShown("VersionCheck") then RefreshList() end
end)
W.OnAddon(VERQ, function(_, from, _, full)
    if GetTime() - lastBroadcast < 10 then return end -- a flood of requests gets one answer
    if not W.IsMe(full or from) then Broadcast() end
end)

-- My version goes out after a login / reload and when I join a group, never in battlegrounds /
-- arenas; the others ask (Refresh) when they need it. Loading screens and roster moves send nothing.
local wasInGroup = false
W.On("PLAYER_ENTERING_WORLD", function(isLogin, isReload)
    wasInGroup = W.InGroup()
    if isLogin or isReload then W.After(5, function() if not W.InPvP() then Broadcast() end end) end
end)
W.OnRoster(function()
    local inGroup = W.InGroup()
    if inGroup and not wasInGroup and not W.InPvP() then Broadcast() end
    wasInGroup = inGroup
end)

W.RegisterModule("VersionCheck", "Version", function(p)
    W.Title(p, L("Version Check"))
    W.Label(p, L("Your version: ") .. W.version, "GameFontHighlightSmall"):SetPoint("TOPLEFT", 16, -40)
    W.Button(p, L("Refresh"), 110, 22, function()
        if not W.InGroup() then W.Print(L("Nothing to broadcast: you are not in a party or raid.")) end
        Broadcast(); Request(); RefreshList()
    end):SetPoint("TOPLEFT", 14, -60)
    UI.count = W.Label(p, "", "GameFontHighlightSmall")
    UI.count:SetPoint("TOPLEFT", 140, -64)
    local hdr = W.Label(p, L("Member                                   Version          Status"), "GameFontNormalSmall")
    hdr:SetPoint("TOPLEFT", 18, -92)
    hdr:SetTextColor(W.R, W.G, W.B)
    local panel = W.Panel(p, 360, 420)
    panel:SetPoint("TOPLEFT", 12, -106)
    UI.list = W.ScrollList(panel, 320, 404, 18, function(content)
        local r = CreateFrame("Frame", nil, content)
        r.name = W.Label(r, "", "GameFontHighlightSmall"); r.name:SetPoint("LEFT", 4, 0)
        r.ver = W.Label(r, "", "GameFontHighlightSmall"); r.ver:SetPoint("LEFT", 170, 0)
        r.st = W.Label(r, "", "GameFontHighlightSmall"); r.st:SetPoint("LEFT", 240, 0)
        return r
    end)
    UI.list.sf:SetPoint("TOPLEFT", 6, -8)
end, function()
    RefreshList(); Broadcast(); Request()
end)
