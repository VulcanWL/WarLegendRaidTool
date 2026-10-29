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

## DoesItDie (a module made from a ported addon)
`DoesItDie.lua` = the module (key `doesItDie`, Raid > Combat, `/wl did` and `/did`); `DoesItDie/` = DoesItDie 0.8.3 by Joe
Greive (MIT, `LICENSE` kept) made into the module on 29/10: `DoesItDie.lua` (DoT tracking, its events, the driver,
`ns.Command`), `Display.lua` (target marker and kill icon), `Nameplates.lua`, `Focus.lua`, `Execute.lua` (`/wl did exec`
probe), `Frames.lua` (EllesmereUI's target / focus frames, found by name), `Options.lua` (the tab: sub-tabs and live
preview), `Locale.lua` + `Locale_frFR.lua` (spell texts read in English and French only). Shared through `W.Space("DoesItDie")`.
- **Off by default, switched at once**: `ns.Allowed()` = the module's switch, Settings > Modules, the guild check, no
  original DoesItDie addon loaded. `ns.SetActive` registers / unregisters the events (a frame of its own: the spell cast
  events for the player only, `UNIT_COMBAT` for every unit, too frequent for `W.On`) and forgets every DoT. `W.On` of the
  module file (target change, entering world, combat) switch it back on after Settings > Modules.
- **One driver**: the target marker, the nameplates and the focus are drawn 10 times a second by one `OnUpdate`, shown only
  while a DoT is tracked, a cast estimate runs, the tab's preview is on or the kill icon test runs (`ns.Wake`; it hides
  itself after the pass that hides everything). At rest, switched on: 0 ms. The look is applied again only when a setting
  changes (`ns.lookGeneration`, bumped by `ns.reattach`).
- **Secret values**: target health, mob GUIDs (instances) can be secret: health only ever goes into StatusBar min / max (the
  widget compares), GUIDs fall back to the nameplate token. Never `COMBAT_LOG_EVENT_UNFILTERED` (Forever forbids it).
- **Saved**: options = scalars of `W.db.doesItDie` (profiles); `ticks` (learned tick sizes) and `log` (300 trace lines) are
  data. `ns.Sanitize` puts back a number out of its slider's range or an id out of its list (imported profile).
  1.37.0-1.41.54 saved in `DoesItDieDB` (the original's name): migration 3 copies it, then it is set to nil; it stays in the
  .toc for that move (drop it from `## SavedVariables` a version later). With the original addon loaded, its table is
  given back and ours stays off.
- Removed from the original: its own window and Blizzard settings page, the custom frame paths and the pick mode, the
  other 5 languages, the window language.

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
  shadowing; the warnings already looked at are listed per file, a new one fails the CI). `check.js` also counts the
  upvalues of each function as Lua 5.1 does (the locals of enclosing functions it uses, those its inner functions use
  too): an error above 60 (WoW refuses the whole file; fengari takes 255, the smoke test never sees it), a warning above
  50 (`Libs` not counted). With Lua 5.1's own compiler (`luac5.1` on PATH or `LUAC=<path>`; the CI installs Ubuntu's
  `lua5.1`, the PC has none), `check.js` also compiles every file the .toc files load, `Libs` included (136 today), as
  WoW loads it (`luac5.1 -p`, a BOM dropped): every limit of 5.1, not only the upvalues. Missing in the CI (`CI` set) =
  a problem; a luac of another Lua is refused.
- `tools/wow-api.js`: model of the game's API from Blizzard_APIDocumentationGenerated in Gethe/wow-ui-source, branch
  `forever` (cloned into `tools/.cache`, 50 MB). `check` lists the C_ functions / Enum / Constants the addon uses that
  the build does not document, and the old globals called directly (with or without a guard; `deprecated shim` = only
  Blizzard_Deprecated* defines it, gone when the CVar loadDeprecationFallbacks is off). `C_ form not tried first X (C_Y.X)`:
  a global Blizzard's own loaded code no longer calls, with a documented replacement (`C_Y.X`, or the C_ function its
  shim calls: `IsPlayerSpell` -> `C_SpellBook.IsSpellKnown`), called without trying the C_ form first (above it in the
  same function, or as the fallback of an `if` testing `C_Y`): Forever loads no deprecation fallback, so likely nil there.
  Names already looked at are in `tools/api-baseline.txt`; only new ones fail.
- `tools/sync.sh` copies to the `_forever_` client only (the Classic beta is no longer used); `WLRT_GAME=<AddOns folder>` restricts it to one.
- `tools/forever-report.js [--since DATE|all] [--all]` (read-only): what a game session left on disk - installed version vs the repo,
  our Lua errors from !BugGrabber (file:line, count) since the installed files, `auditLog` (refused, peaks, slowest work, CPU), `bgMessages`,
  login errors; exit 1 when one of our addons raised an error or the audit refused a message.
- `tools/smoke.js` + `tools/smoke/wow.lua` (the fake client) + `tools/smoke/scenario.lua`: fengari (Lua 5.3 in JS) runs
  the four addons twice (fresh English install; /reload with the saved data, French, Skyborne character): login, every
  `/wl` command alone and in a raid, every tab, Test all, ready check, pull, combat (protected frames changed in combat
  are listed as the game would block them), hostile addon messages on every prefix (from guild mates, strangers and a raid
  assistant; `--seed S`, default 12345: the same seed and `--fuzz N` send the same messages, the one behind the first Lua
  error of each prefix / event is printed as a Lua string), own messages replayed 100 times, shaped hostile messages (own
  messages with one field replaced, the fields Classes / Layers / Raid Buffs keep and show), every tab drawn again, chat
  lines of other players (whispers, Battle.net, group / guild / public chat, system, battleground, loot; junk and lines
  past 255 bytes; InviteTool, `!sr` and Summon off then on; the chat filters run on each line), pasted texts (profile,
  Myslot, Raid Groups preset, soft-res CSV: junk, huge, nested, NaN / inf, escape codes, separators, one long line, 1 / 16 /
  256 KB, a valid export cut at 20 places), long texts, event floods. Verdicts: a chat line < 1 s, no chat line and no
  action but AGENTS.md's accepted exceptions (keyword invite 1 per 30 s per sender, `!sr` answers 3 per 10 s); a paste
  < 1 s, refused or in the confirmation with the saved data untouched (a preset / soft-res list: saved in a checked
  form), stopped by a watchdog past 3e8 Lua instructions (`debug.sethook`: an endless loop fails its case instead of
  hanging the run; the whole export must not be refused); no escape code of another player shown live: the hostile
  pieces carry a mark inside their codes and `M.Shown` (`wow.lua`) reads every text shown (widget text, chat line,
  tooltip line, popup, print) for a live `|T`, `|A`, `|K`, `|H` other than an item link or a line break of the pieces,
  with the line that showed it. Secret values (`wow.lua`, end): in combat or an encounter, the functions / events the
  Forever docs flag `SecretWhenCooldownsRestricted`, `SecretWhenAurasRestricted` or `SecretWhenInCombat`
  (`tools/wow-api.js` puts their returns / payload and structures in the model) give secrets (not `NeverSecret` fields,
  booleans, unit tokens): `issecretvalue` true, `type` the value's type, `W.Safe` nil, `tostring` / `tonumber` /
  `string.format` / string and math functions give secrets (wrapped in JS: `SMOKE_WRAP`), comparing (`==` too),
  arithmetic, concatenation (`table.concat` too), `#`, indexing or a table key raise a Lua error at the addon's line
  (`smoke.js` adds `==` and table keys to fengari: one line compiled into its `lvm.js`, `ltable.luaH_get` wrapped), so
  does a secret given to `SendAddonMessage` / `SendChatMessage` (the docs: NotAllowed / AllowedWhenUntainted, the addon
  is tainted); a secret written in the saved variables is a problem; a self-test checks it all each run.
  `M.spellCooldowns[id] = { start, duration }` models `C_Spell.GetSpellCooldown` (RaidCooldowns check: a cooldown cast
  in combat is not answered ready); `C_SpellBook.IsSpellKnown` / `IsSpellInSpellBook`: the player knows the spells
  asked about, but those of `M.unknownSpells`. Limits: frames draw nothing, the server never answers, spells the game flags never
  secret are secret here: it proves the code runs, not that a feature works in game. The fake client follows FrameXML
  where the addon depends on it: pools reuse their objects, the world map is a MapCanvas (no map before its first opening,
  pins from pools), a frame becomes protected when a secure frame is its child or is anchored to it. It follows Lua 5.1 /
  WoW where fengari differs: `unpack` / `strsplit` give 8000 results at most, `bit` returns unsigned 32-bit numbers, a hex
  literal past 32 bits is read as its number (fengari's integers have 32 bits); not modelled: `pairs` walks a table
  constructor's array backwards in fengari (only the crafted Myslot export gets the game's order).
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
- `--quiet` (any of the three modes): only what fails (each Lua error and the message behind the first one, blocked
  actions, the FAIL lines of every verdict, failed checks, the chat lines / actions sent when one is counted), under one
  line per pass: problems, seconds, counts (`== fresh install, English client: no problem in 50 s (0 Lua error(s), ...)`);
  what the addons print is not written out. Same problems counted, same exit code; without it the output is the full one
  (the CI and the user read it). When all passes: 2 or 3 lines / 200-450 bytes instead of about 110 lines / 8-10 KB per
  mode. Agents run it first; on a failure, `--quiet --verbose` (every FAIL line, the stack of each Lua error) or
  `--verbose` alone (everything).
- `tools/deps-watch.js` + `tools/watch.json`: upstream version of each embedded library, latest release of the ported
  addons, edits of Blizzard's add-on policy, Luacheck release. `reviewed` = the upstream value already looked at.
- Workflows: `wlrt-ci.yml` (every push / PR: check.js with Lua 5.1's compiler, Luacheck, wow-api check, smoke, open world and battleground smoke), `wlrt-build-watch.yml` (hourly:
  new build or UI source commit = one issue, with the API check and smoke results for a UI commit), `wlrt-deps-watch.yml`
  (Mondays: one issue per new upstream value), `.github/dependabot.yml` (pull requests for the pinned actions and tools).
  Scheduled workflows run from `main` only.
