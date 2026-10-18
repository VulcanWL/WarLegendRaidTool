# WarLegendRaidTool — module details (for coding agents)

Read only the part about the file you are changing. The rules that always apply stay in
`WarLegendRaidTool/AGENTS.md`; this file holds the detail behind them. Not shipped (outside the three addon folders).

## The two load-on-demand addons
- **Raid addon** `WarLegendRaidTool_Raid` (RaidGroups, LootCouncil, RaidBuffs, ReadyCheck, Checklist, WhoPulled, RaidInspect,
  AuraTracker, RaidCooldowns, Readiness), like BigWigs zone modules, listed in ITS `.toc`. `Core.lua` loads it (`W.LoadRaid`)
  in a group, in a dungeon / raid, with Aura Tracking on, when `/wl` opens, or when one of its addon messages arrives
  (prefixes listed in `lodPrefix`: a new prefix goes there too). In that addon `W.OnReady` runs after the whole file is
  loaded, `W.On` handlers for login / entering world are replayed once.
- **PvP addon** `WarLegendRaidTool_PvP` (battleground enemy / ally frames, BattleGroundEnemies cleaned up), loaded on demand
  by `PvP.lua` (`W.LoadPvP`) in a battleground or when its tab opens. `Modules/Dispel.lua`: ally frames show what MY class
  can dispel and give; `Modules/CrowdControl.lua`: the CC on the class icon. Both use `Modules/NativeAuras.lua`: Blizzard's
  `CreateFrame("AuraContainer")` (Forever 12.1 aura system) shows the auras itself, also the secret ones.
  Trinket / DR tracking is NOT possible in battlegrounds (the client hides that data there).

## Guild-side modules (personal only, no addon messages)
`Guild.lua` (inactive, professions synced, recruitment), `Roster.lua` (trials by rank, `/wl trials`), `GuildBank.lua`
(stock of MY account's characters at the bank rank, read from `Alts.lua`, `/wl bank`), `BGStats.lua` (my guild premades,
players, fastest wins per battleground, `/wl bg`). Roster, GuildBank and BGStats send nothing: the user chose that; do not
add guild sync to them without being asked.

## Settings.lua
- Settings > General: the options of the addon as a whole (minimap button, preload of the raid modules, countdown voice,
  overlap switch). An option that concerns the whole addon goes there, not in a module's panel.
- Settings > Modules: `W.SetModuleOn(key, on)` / `W.IsOff(key)`. Core skips the `W.On`, `W.OnRoster`, `W.OnAddon` handlers
  and the test of that module's FILE, found with `W.Where`; one module per file. A module with its own event frame
  (not `W.On`) checks `W.IsOff("Key")` in its OnEvent.
- Settings > Profile: export / import of the options as one text. A profile holds the scalars of every `W.db` key plus the
  option tables listed in `TABLE_FIELDS` there (and `point` / `emphPoint`): a new option saved as a table goes in `TABLE_FIELDS`.

## Interface modules
- `MoveFrames.lua` (`/wl move`): the safe part of MoveAny. It never moves a protected frame (`IsProtected()`), only hooks
  Blizzard's (`HookScript`, `hooksecurefunc`), and works out of combat. No action bars, unit / group frames, buffs or the
  minimap there: EllesmereUI moves them, and moving secure frames is what breaks MoveAny.
- `InterfaceOptions.lua` (`/wl cvar`): hidden game options as CVars (from Advanced Interface Options) and a CVar browser.
  A CVar is set out of combat only, through `pcall`, and only one that exists on the client is shown. The values set there
  are kept in `db.cvars` (put back at login, in the profiles); a change made elsewhere updates them (SetCVar hooks).
- `ItemLevels.lua` (`/wl ilvl`): from SimpleItemLevel. Marks live on a child frame of each Blizzard item button, kept in a
  weak table (nothing written in Blizzard's tables); it does nothing while SimpleItemLevel itself is loaded.
- `GuildPositions.lua` (`/wl map`): guild members on the maps. It sends addon messages to the GUILD (the user asked for it),
  with GuildMap's prefix `GuildMapEx1` and fields so both addons see each other: keep that format. Pins through
  HereBeDragons in `Libs/` (the "-gm" Forever copy from GuildMap, loaded first in the .toc).

## Test all and Cost
- **Test all** (`/wl test`, header button): `W.RegisterTest(label, enabledFn, runFn, stopFn)` in the module file. A test must
  end by itself (timer) and `stopFn` must hide it. Never send addon / chat messages from a test.
- **Cost** (`/wl perf`): every `W.On` handler, `W.After` timer, roster and ready function is timed (max of one run, count,
  total). A hook on Blizzard code that can run often (`hooksecurefunc`, `HookScript`, tooltip callbacks) is wrapped with
  `W.Timed("label", fn)` so it shows there too (see `ItemLevels.lua`). Anything that must run every frame (`OnUpdate`) is
  only set while its frame is shown, and throttled (0.1 s or more) when a timer text is enough.
