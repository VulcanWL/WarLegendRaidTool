-- WarLegend RaidTool - Cooldown text (the idea of OmniCC)
-- The time left written on the spell buttons and icons. Not an engine of our own: the client's own countdown
-- numbers (CVar countdownForCooldowns), drawn by the game, so they also work on the cooldowns it keeps secret
-- in PvP. The value the player had is put back when the option is switched off.
local W = WLRT
W.AddFR({
    ["Cooldown text"] = "Texte de recharge",
    ["Show the time left on spell buttons and icons"] = "Afficher le temps restant sur les boutons de sorts et les icônes",
    ["Uses the game's own countdown numbers (option \"countdownForCooldowns\"). If your action bar addon already writes them, leave this off."] =
        "Utilise les chiffres de recharge du jeu (option « countdownForCooldowns »). Si ton addon de barres d'action les affiche déjà, laisse ceci désactivé.",
    ["This client has no countdown option."] = "Ce client n'a pas l'option de compte à rebours.",
})
local L = W.L
local db
local CVAR = "countdownForCooldowns"

local function GetCV(name)
    if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(name) end
    return GetCVar and GetCVar(name)
end
local function SetCV(name, value)
    if C_CVar and C_CVar.SetCVar then return pcall(C_CVar.SetCVar, name, value) end
    if SetCVar then return pcall(SetCVar, name, value) end
end

W.OnReady(function()
    db = W.DB("cooldownText", { enabled = false, previous = "" })
end)

local function Apply()
    if not db then return end
    local cur = GetCV(CVAR)
    if cur == nil then return end
    if db.enabled then
        if cur ~= "1" then
            if db.previous == "" then db.previous = cur end
            SetCV(CVAR, "1")
        end
    elseif db.previous ~= "" then
        SetCV(CVAR, db.previous)
        db.previous = ""
    end
end
W.On("PLAYER_ENTERING_WORLD", function(isLogin, isReload) if isLogin or isReload then Apply() end end)

W.RegisterModule("CooldownText", "Cooldown text", function(p)
    W.Title(p, L("Cooldown text"))
    if GetCV(CVAR) == nil then
        W.Label(p, L("This client has no countdown option."), "GameFontDisable"):SetPoint("TOPLEFT", 16, -44)
        return
    end
    W.Check(p, L("Show the time left on spell buttons and icons"), function() return db.enabled end,
        function(v) db.enabled = v; Apply() end):SetPoint("TOPLEFT", 12, -40)
    local info = W.Label(p, L("Uses the game's own countdown numbers (option \"countdownForCooldowns\"). If your action bar addon already writes them, leave this off."),
        "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, -76)
    info:SetWidth(700)
    info:SetJustifyH("LEFT")
    info:SetTextColor(0.7, 0.7, 0.7)
end)
