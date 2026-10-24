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
  Work per frame (Alterac, 80 buttons): no OnUpdate per button. `WarLegendPvP.Spread(parent, period, getList, fn)` (`Main.lua`)
  runs fn for each item every `period` s from ONE OnUpdate that spreads the items over the frames (round robin): the range /
  `UpdateAll` of each side's buttons (`Mainframe.lua`, 0.2 s in combat, 0.4 s out of combat), the ally power read
  (`Power.lua`, 0.25 s), the dispel type symbols (`NativeAuras.lua`, 0.25 s: the container's frames have no event).
  `GROUP_ROSTER_UPDATE` is not read outside a battleground / the test mode (`PLAYER_ENTERING_WORLD` in a battleground and
  `EnableTestMode` read it with `force`); in a battleground a burst is read at once, then once more 0.2 s later at most.
  `UPDATE_BATTLEFIELD_SCORE` (asked every 2 s) rebuilds nothing when the scoreboard holds the same players (name, side,
  class, race, spec; secret values never compared); `lastScoreboard` is cleared at each loading screen. The player sort
  reads the role order once per setting (`RoleOrder`), `FindPlayerInSource` uses an index per source update.

## Guild-side modules (personal only, no addon messages)
`Guild.lua` (inactive, professions synced, recruitment), `Roster.lua` (trials by rank, `/wl trials`), `GuildBank.lua`
(stock of MY account's characters at the bank rank, read from `Alts.lua`, `/wl bank`), `BGStats.lua` (my guild premades,
players, fastest wins per battleground, `/wl bg`). Roster, GuildBank and BGStats send nothing: the user chose that; do not
add guild sync to them without being asked.

## Modules taken from Sashoof's WarLegend v3 addon (rewritten here, they DO send to the GUILD)
`Layers.lua` (`WLRT_LAYER`: creature GUID zone part, two creatures within 30 s confirm, numbers are local aliases per map), Invite button (whisper once / 60 s + InviteUnit; refused in combat / instance, if grouped, if same layer or zone, reading > 5 min),
`Classes.lua` (`WLRT_PROFILE`: my role / spec / availability; `W.MyRole()`; class leaders in `TABLE_FIELDS`),
`Minotaure.lua` (`WLRT_MINO`: 28-day UTC seasons from 1791763200, fixed rules 5 / 30 / 200 a day, peers shown as declared).
Each answers a `"?"` request, throttled. `DangerAlert.lua` keeps the enemy players seen (`db.seen`, 200 at most, personal).
Its enemy player frames (open world) are light rows of its own, not the PvP addon (never loaded for them): one per GUID,
fed by nameplate / target / focus / mouseover events, no nameplate scan. The click buttons are secure, anchored to the
holder (never to the rows), changed out of combat only; in combat a clickable row stays (grey) until the combat ends.
`Overlap.lua`: `autoInvite` is covered by WarLegend v3 while its `WarLegendDB.config.invite.mode` is not "off".
The "WL v3" styles (`wl3`, `wl3red`, `wl3gold`, `wl3violet`, `wl3mono`) share the `wl3` palette in `Core.lua`.

## Settings.lua
- Settings > General: the options of the addon as a whole (minimap button, preload of the raid modules, countdown voice,
  overlap switch). An option that concerns the whole addon goes there, not in a module's panel.
- Settings > Modules: `W.SetModuleOn(key, on)` / `W.IsOff(key)`. Core skips the `W.On`, `W.OnRoster`, `W.OnAddon` handlers
  and the test of that module's FILE, found with `W.Where`; one module per file. A module with its own event frame
  (not `W.On`) checks `W.IsOff("Key")` in its OnEvent.
- Settings > Profile: export / import of the options as one text. A profile holds the scalars of every `W.db` key plus the
  option tables listed in `TABLE_FIELDS` there (and `point` / `emphPoint`): a new option saved as a table goes in `TABLE_FIELDS`.
  An imported profile is untrusted: finite numbers up to 1e12, strings up to 20 000, 20 000 entries; its macro lines keep
  only the commands of `MACRO_CMDS` (an allow list: never add a guild, logout, chat or script command to it).
- Received data (addon messages, whispers, pasted strings, the Skyborne public channel) is untrusted: numbers through
  `W.Finite` / `W.Int` (a `tonumber("nan")` passes `<` / `>` tests), lists and tables capped, texts through `W.Plain`, names
  that reach a macro without `[ ] ; ,` or control characters, and a "?" / "Q" request answered once a minute at most.
- Names: on Forever the short name (`W.BaseName`) is only the first name, shared by strangers. Anything that grants
  trust (promotion, auto-accept, leader checks) matches the full name (`W.FullName`, `W.GuildMember`), a short name only
  for the one guild member who has it. Prompts from other players show the sender with `W.Sender` (flags "not in guild").

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
  HereBeDragons in `Libs/` (the "-gm" Forever copy from GuildMap, loaded first in the .toc). HereBeDragons-Pins takes a
  new world map pin at each `AddWorldMapIcon*` and frees the old one only when the map refreshes: a moved icon is removed
  first (`RemoveWorldMapIcon`, as `Transports.lua` does), else pins pile up while the map is closed. A line that changes
  neither the place, the class nor the options (`PlaceKey`) places nothing again: each minimap add makes the library
  update every pin.

## Test all and Cost
- **Test all** (`/wl test`, header button): `W.RegisterTest(label, enabledFn, runFn, stopFn)` in the module file. A test must
  end by itself (timer) and `stopFn` must hide it. Never send addon / chat messages from a test.
- **Cost** (`/wl perf`): every `W.On` handler, `W.After` timer, roster and ready function is timed (max of one run, count,
  total). A hook on Blizzard code that can run often (`hooksecurefunc`, `HookScript`, tooltip callbacks) is wrapped with
  `W.Timed("label", fn)` so it shows there too (see `ItemLevels.lua`). Anything that must run every frame (`OnUpdate`) is
  only set while its frame is shown, and throttled (0.1 s or more) when a timer text is enough.

## Skyborne (4th addon, load on demand)
`WarLegendRaidTool/Skyborne.lua` = loader (`W.LoadSkyborne`, on `PLAYER_ENTERING_WORLD` only if `UnitRace` token is "Skyborne", and `/wl sk`).
`WarLegendRaidTool_Skyborne/` = port of "Skyborne Leyline & Convergence Marker" 0.4.1 by tr0tsky (MIT): `Data.lua` (`WLRTSkyData`),
`Main.lua` (map pins, Blizzard settings page, export, `WLRTSkyborne.Command/Start`), `Comm.lua` (hidden channel `SLLCMShare`A/H, prefix `SLLCM`:
kept as the original so its users are heard; on by default; NOT guild messages, so no `lodPrefix`), `Scan.lua` (minimap blips), `Pins.xml`.
Saved in `WarLegendRaidTool_SkyborneDB`. The addon is loaded after login: `ns.Start` / `ns.CommStart` replace ADDON_LOADED / PLAYER_LOGIN.
Removed from the original: About / Discord page, first-run popup, "show on non-Skyborne", dev/test commands, `Watch` hooks.
The folder is in `.gitignore`'s allow list, `tools/sync.sh`, `tools/check.js` and the release workflow.
`Comm.lua` reads nameplates / target / mouseover (the phase) in the open world only: `inInstance`, set by `OnWorld`.

## Checks and watch (tools/, .github/: not shipped)
- `tools/check.js` (offline, the project rules), `tools/.luacheckrc` (Luacheck: unused / lost values, `not x == y`,
  shadowing; the warnings already looked at are listed per file, a new one fails the CI).
- `tools/wow-api.js`: model of the game's API from Blizzard_APIDocumentationGenerated in Gethe/wow-ui-source, branch
  `forever` (cloned into `tools/.cache`, 50 MB). `check` lists the C_ functions / Enum / Constants the addon uses that
  the build does not document, and the old globals called directly (with or without a guard; `deprecated shim` = only
  Blizzard_Deprecated* defines it, gone when the CVar loadDeprecationFallbacks is off). Names already looked at are in
  `tools/api-baseline.txt`; only new ones fail.
- `tools/sync.sh` copies to the `_forever_` client only (the Classic beta is no longer used); `WLRT_GAME=<AddOns folder>` restricts it to one.
- `tools/forever-report.js [--since DATE|all] [--all]` (read-only): what a game session left on disk - installed version vs the repo,
  our Lua errors from !BugGrabber (file:line, count) since the installed files, `auditLog` (refused, peaks, slowest work, CPU), `bgMessages`,
  login errors; exit 1 when one of our addons raised an error or the audit refused a message.
- `tools/smoke.js` + `tools/smoke/wow.lua` (the fake client) + `tools/smoke/scenario.lua`: fengari (Lua 5.3 in JS) runs
  the four addons twice (fresh English install; /reload with the saved data, French, Skyborne character): login, every
  `/wl` command alone and in a raid, every tab, Test all, ready check, pull, combat (protected frames changed in combat
  are listed as the game would block them), hostile addon messages on every prefix, own messages replayed 100 times,
  event floods. Limits: values are never secret, frames draw nothing, the server never answers: it proves the code runs,
  not that a feature works in game. The fake client follows FrameXML where the addon depends on it: pools reuse their
  objects, the world map is a MapCanvas (no map before its first opening, pins from pools), a frame becomes protected when a
  secure frame is its child or is anchored to it.
- `node tools/smoke.js --open-world` (`tools/smoke/openworld.lua`, one English run, about 20 s, also in the CI): a guild of
  120 and a raid of 40 outside instances (`M.SetupWorld`: two continents, a few zones, positions for HereBeDragons).
  [1] enemy player frames of the danger alert (40 at most, clicks right after combat, nothing secure changed in combat),
  frames drawn in a raid; [2] the raid forming, the same events with 10 and 40 players, the PvP addon loaded, the
  addon's own lines sent by 39 raiders / 119 guild mates, OnUpdate at rest, `W.BusiestWork`; [3] 119 members sending
  GuildMap lines built from the addon's own line (map never opened, open on a zone / the continent, closed; I move; edge;
  "gone" line; silence; return): members placed, pins drawn, world map pins left active, frames reused. Fails on a Lua
  error, a blocked action, a chat line or a failed check. fengari ms only compare with each other.
- `node tools/smoke.js --bg` (`tools/smoke/battleground.lua`, one English run with a Skyborne character, about 20 s, also in
  the CI): Alterac Valley 40 vs 40. The fake client models the battleground (`M.instance = "pvp"`, `M.scores` = the
  scoreboard read by `C_PvP.GetScoreInfo`, `M.bgFaction`; `RequestBattlefieldScoreData` answers with
  `UPDATE_BATTLEFIELD_SCORE`). `M.frameStats` gives the cost of each simulated frame (one step of 1/20 s: only the time in
  the addons' code; an event the scenario fires between two steps counts in the next one), reported as average,
  percentiles, worst frame and what it did (`M.costs` on: handlers, OnUpdate, timers by the file:line of their callback).
  Phases: the raid forming (39 joins, 3 roster events each), rest at the start, a fight (20 enemies on nameplates, about 280
  UNIT_HEALTH, 160 UNIT_POWER_FREQUENT, 160 UNIT_AURA a second, targets, mouseover), combat in / out with players coming and
  going, dead at the graveyard, roster / scoreboard floods, back outside (PvP frames hidden, roster cost), the test mode
  before any battleground and after one (my own button shown), the next battleground and a fight in it. Fails on a Lua
  error, a blocked action, a chat line or a failed check. To compare with the code before a change, run the same bench on
  the addons of `HEAD` (`git archive HEAD <the four folders>` into a scratch folder with a copy of `tools/smoke*`, then
  `NODE_PATH=tools/node_modules WLRT_WUS=<the UI source> node tools/smoke.js --bg` there).
- `tools/deps-watch.js` + `tools/watch.json`: upstream version of each embedded library, latest release of the ported
  addons, edits of Blizzard's add-on policy, Luacheck release. `reviewed` = the upstream value already looked at.
- Workflows: `wlrt-ci.yml` (every push / PR: check.js, Luacheck, wow-api check, smoke, open world and battleground smoke), `wlrt-build-watch.yml` (hourly:
  new build or UI source commit = one issue, with the API check and smoke results for a UI commit), `wlrt-deps-watch.yml`
  (Mondays: one issue per new upstream value), `.github/dependabot.yml` (pull requests for the pinned actions and tools).
  Scheduled workflows run from `main` only.
