-- WarLegend RaidTool - Luacheck settings (not shipped).
-- luacheck --config tools/.luacheckrc WarLegendRaidTool WarLegendRaidTool_Raid WarLegendRaidTool_PvP WarLegendRaidTool_Skyborne
-- Run by the CI workflow (.github/workflows/wlrt-ci.yml). It finds what tools/check.js does not look for:
-- unused variables and values, a value that never reaches its variable ("a and f()" keeps one value), "not x == y",
-- shadowed locals, empty branches, unreachable code.
std = "lua51"
max_line_length = false
exclude_files = { "**/Libs/**" }
ignore = {
    "113", -- reading an undefined global: the WoW API, checked against Blizzard's documentation by tools/wow-api.js
    "212", -- unused argument (handlers get self, event, ...)
    "213", -- unused loop variable
    "421", "431", "432", -- a local shadowing another one (local ui = W.DB("ui") in a function, self in nested methods)
    "61.", -- whitespace
}
-- the globals the addon creates or changes (anything else written is an accident)
globals = {
    "WLRT", "WarLegendRaidToolDB", "WarLegendRaidTool_PvPDB", "WarLegendRaidTool_SkyborneDB",
    "WarLegendPvP", "ClickCastFrames", "WLRTSkyData", "WLRTSkyPinMixin", "WLRTSkyborne", "MyslotExports", "MyslotSettings", "DoesItDieDB",
    "SlashCmdList", "StaticPopupDialogs", "BINDING_HEADER_WARLEGENDRAIDTOOL",
    "SLASH_WARLEGENDRT1", "SLASH_WARLEGENDRT2", "SLASH_WARLEGENDRT3", "SLASH_WARLEGENDRTDIRECT1", "SLASH_WARLEGENDRTDIRECT2",
    "SLASH_WLRTREADYCHECK1", "SLASH_DOESITDIE1", "SLASH_DOESITDIE2",
}
-- the battleground frames are BattleGroundEnemies (Bullsei) cleaned up: its unused locals and empty branches are
-- kept as upstream so a later update stays easy to compare
files["WarLegendRaidTool_PvP"] = { ignore = { "211", "311", "411", "421", "431", "542", "621" } }
-- looked at in the audit of 21/10/2026, harmless (dead values or the "local ADDON, ns = ..." header): a NEW warning fails
files["WarLegendRaidTool/CapTimers.lua"] = { ignore = { "231/winText" } }
files["WarLegendRaidTool/Core.lua"] = { ignore = { "411/Norm" } } -- the second Norm is the options search one
files["WarLegendRaidTool/Lib.lua"] = { ignore = { "211/n" } }
files["WarLegendRaidTool/Transports.lua"] = { ignore = { "211/_" } }
files["WarLegendRaidTool_Raid/RaidBuffs.lua"] = { ignore = { "241/BUFF_BY" } }
files["WarLegendRaidTool_Raid/RaidCooldowns.lua"] = { ignore = { "211/UI" } }
files["WarLegendRaidTool_Raid/Readiness.lua"] = { ignore = { "211/asked" } }
files["WarLegendRaidTool_Skyborne"] = { ignore = { "211/ADDON", "211/W", "311/saved" } }
files["WarLegendRaidTool/Myslot"] = { ignore = { "1", "2", "3", "4", "5", "6" } } -- Myslot (Boshi Lian) as upstream: only syntax errors are looked at
