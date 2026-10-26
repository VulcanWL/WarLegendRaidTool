-- WarLegend RaidTool - AutoLog
-- Starts /combatlog automatically in raids and/or dungeons, and stops it when leaving
-- (only if the addon started it).
local W = WLRT
local L = W.L
local db
local debugMode = false
local worldBoss = false

W.OnReady(function()
    db = W.DB("autoLog", { raids = false, dungeons = false, owned = false })
end)

local function IsLogging()
    if C_ChatInfo and C_ChatInfo.IsLoggingCombat then return C_ChatInfo.IsLoggingCombat() and true or false end
    return LoggingCombat() and true or false
end

local function Debug(fmt, ...)
    if debugMode then W.Print("|cff999999debug|r " .. string.format(fmt, ...)) end
end

local function ShouldLog()
    local _, instanceType, difficultyID = GetInstanceInfo()
    Debug("instanceType=%s difficultyID=%s raids=%s dungeons=%s worldboss=%s",
        tostring(instanceType), tostring(difficultyID), tostring(db.raids), tostring(db.dungeons), tostring(worldBoss))
    if instanceType == "raid" then return db.raids end
    if instanceType == "party" then return db.dungeons end
    return worldBoss and db.raids -- open world boss
end

-- target changes are only watched where a world boss can show up: open world, raids option on
local targetEv
local function WatchTargets()
    local _, kind = IsInInstance()
    W.Activate(targetEv, db and db.raids and kind == "none" and not worldBoss)
end

local function CheckAutoLog()
    if not db then return end
    if W.Overlap("autoLog") then return end -- EllesmereUI already logs for you
    WatchTargets()
    if db.owned and not IsLogging() then db.owned = false end -- stopped manually
    if ShouldLog() then
        if not IsLogging() then
            -- nil = rate limited (5 calls per 10 s shared by every addon): nothing changed, try again
            if LoggingCombat(true) == nil then W.After(3, CheckAutoLog); return end
            if IsLogging() then db.owned = true; W.Print(L("Combat logging started.")) end
        end
    elseif db.owned then
        if LoggingCombat(false) == nil then W.After(3, CheckAutoLog); return end
        -- only says "stopped" when the game confirms it
        if not IsLogging() then
            db.owned = false
            W.Print(L("Combat logging stopped."))
        end
    end
end

local function Later() W.After(2, CheckAutoLog) end
W.On("PLAYER_ENTERING_WORLD", Later)
W.On("ZONE_CHANGED_NEW_AREA", function() worldBoss = false; Later() end)
W.On("PLAYER_DIFFICULTY_CHANGED", Later)
W.On("UPDATE_INSTANCE_INFO", Later)
-- World boss logging ends with the fight (30 s out of combat, a death or a short break does
-- not count), or after 5 minutes if the fight never started.
local wbAt, fought = 0, false
local function WorldBossOver()
    if worldBoss and not (UnitAffectingCombat and UnitAffectingCombat("player")) then
        worldBoss, fought = false, false
        CheckAutoLog()
    end
end
targetEv = W.On("PLAYER_TARGET_CHANGED", function()
    if UnitExists("target") and UnitClassification("target") == "worldboss" and not worldBoss then
        worldBoss, fought = true, false
        wbAt = GetTime()
        Later()
        local mark = wbAt
        W.After(300, function() if wbAt == mark and not fought then WorldBossOver() end end)
    end
end, nil, true) -- off until WatchTargets turns it on
W.On("PLAYER_REGEN_DISABLED", function() if worldBoss then fought = true end end)
-- only the check of the latest end of combat counts (an older one could fire during a later short break)
local overRun = 0
W.On("PLAYER_REGEN_ENABLED", function()
    if not worldBoss then return end
    overRun = overRun + 1
    local run = overRun
    W.After(30, function() if run == overRun then WorldBossOver() end end)
end)

W.slash.logdebug = function()
    debugMode = not debugMode
    W.Print(L("AutoLog debug: ") .. (debugMode and "ON" or "OFF"))
    if debugMode then CheckAutoLog() end
end

W.RegisterModule("AutoLog", "AutoLog", function(p)
    W.Title(p, "AutoLog")
    W.Check(p, L("Raids (and world bosses)"), function() return db.raids end,
        function(v) db.raids = v; CheckAutoLog() end):SetPoint("TOPLEFT", 12, -40)
    W.Check(p, L("Dungeons"), function() return db.dungeons end,
        function(v) db.dungeons = v; CheckAutoLog() end):SetPoint("TOPLEFT", 12, -66)
    local info = W.Label(p, L("The log is written to Logs\\WoWCombatLog.txt (for Warcraft Logs).\n")
        .. L("The addon only stops logs it started itself. /wl logdebug to troubleshoot."), "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, -100)
    info:SetTextColor(0.7, 0.7, 0.7)
    W.OverlapNote(p, "autoLog", "TOPLEFT", 16, -150)
    W.Check(p, L("Use it anyway"), W.OverlapForced, W.SetOverlapForce):SetPoint("TOPLEFT", 12, -172)
end)
