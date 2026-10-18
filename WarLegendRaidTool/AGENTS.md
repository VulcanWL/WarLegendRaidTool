# WarLegendRaidTool — context for coding agents

World of Warcraft **Classic** addon (client beta, `## Interface: 16001`) for the "War Legend" guild:
raid groups, loot council, buffs, ready check, attendance, who pulled, inspect, aura
tracking, raid cooldowns, alts, guild tools, trials, guild bank characters, battleground frames / graveyard
timer / premade history. Slash command `/wl` (also `/wlrt`, `/warlegend`), `/wl help` lists every command.
Current version is in `WarLegendRaidTool.toc` (`## Version:`).

The user is French: **always answer in French**. Code, comments and English UI strings stay in English.

## Hard rules
- **Lua 5.1** (WoW): no `goto`, no `//`, no bitwise operators, no `table.unpack` (use `unpack`).
- **Never invent WoW API functions.** If you are not sure an API exists on Classic, say so and
  guard it like the existing code does: `if C_ChatInfo and C_ChatInfo.X then ... else OldGlobal(...) end`.
- **Read a file before editing it.** Make the smallest change that works. Never rewrite a whole file,
  never rename existing functions, globals, DB keys or addon-message prefixes.
- Files are **UTF-8 without BOM, LF line endings, 4-space indentation**. Keep it that way
  (French accents in strings must stay valid UTF-8).
- Secure frames / protected actions cannot change in combat: check `InCombatLockdown()` first.
- There are no automated tests. The user tests in game with `/reload`. Say what to test.

## Load order and files
`WarLegendRaidTool.toc` lists the files in load order: `Locale.lua`, `Core.lua`, `Lib.lua`, then one file
per module, `VersionCheck.lua` last. **A new file must be added to the .toc** (before `VersionCheck.lua`)
or WoW will not load it. Other files in the folder (like this one) are ignored by the game.

- `Locale.lua` — `W.L`, `W.AddFR`, `W.SetLanguage`, base French table.
- `Core.lua` — events, saved DB, access check, group/guild helpers, UI widgets, main window, `/wl`.
- `Lib.lua` — addon-message queue, item/name helpers, extra widgets (SubTabs, Table, Confirm...).
- One file per module (`AutoLog.lua`, `Focus.lua`, `CombatTimer.lua` are small, good examples).
- **Two addons**: the raid modules (RaidGroups, LootCouncil, RaidBuffs, ReadyCheck, Checklist, WhoPulled, RaidInspect,
  AuraTracker, RaidCooldowns, Readiness) live in the sibling folder `../WarLegendRaidTool_Raid` (load-on-demand, like BigWigs
  zone modules), listed in ITS `.toc`. `Core.lua` loads it (`W.LoadRaid`) in a group, in a dungeon / raid, with Aura Tracking on,
  when `/wl` opens, or when one of its addon messages arrives (prefixes listed in `lodPrefix`: a new prefix there too).
  In that addon `W.OnReady` runs after the whole file is loaded, `W.On` handlers for login / entering world are replayed once.
- **Third addon**: `../WarLegendRaidTool_PvP` (battleground enemy / ally frames, BattleGroundEnemies cleaned up), loaded on
  demand by `PvP.lua` (`W.LoadPvP`) in a battleground or when its tab opens. `Modules/Dispel.lua` there: ally frames show what
  MY class can dispel and give, `Modules/CrowdControl.lua` the CC on the class icon. Both use `Modules/NativeAuras.lua`:
  Blizzard's `CreateFrame("AuraContainer")` (Forever 12.1 aura system) shows the auras itself, also the secret ones.
  Trinket / DR tracking is NOT possible in battlegrounds (the client hides that data there).
- Guild-side modules of the main addon: `Guild.lua` (inactive, professions synced, recruitment), `Roster.lua` (trials by rank,
  `/wl trials`), `GuildBank.lua` (stock of MY account's characters at the bank rank, read from `Alts.lua`, `/wl bank`),
  `BGStats.lua` (my guild premades, players, fastest wins per battleground, `/wl bg`). These three are **personal only:
  no addon messages** — the user chose that; do not add guild sync to them without being asked.

- `Settings.lua`: Settings > General (the options of the addon as a whole: minimap button, preload of the raid modules,
  countdown voice, overlap switch; an option that concerns the whole addon goes there, not in a module's panel), Settings > Modules (`W.SetModuleOn(key, on)` / `W.IsOff(key)`: Core skips the `W.On`, `W.OnRoster`,
  `W.OnAddon` handlers and the test of that module's FILE, found with `W.Where`; one module per file) and Settings > Profile
  (export / import of the options as one text). A profile holds the scalars of every `W.db` key plus the option tables
  listed in `TABLE_FIELDS` there (and `point` / `emphPoint`): **a new option saved as a table goes in `TABLE_FIELDS`**.
  A module with its own event frame (not `W.On`) checks `W.IsOff("Key")` in its OnEvent.
- `MoveFrames.lua` (`/wl move`): the safe part of MoveAny. It never moves a protected frame (`IsProtected()`), only hooks
  Blizzard's (`HookScript`, `hooksecurefunc`), and works out of combat. Do not add action bars, unit / group frames,
  buffs or the minimap there: EllesmereUI moves them, and moving secure frames is what breaks MoveAny.
- `InterfaceOptions.lua` (`/wl cvar`): hidden game options as CVars (from Advanced Interface Options) and a CVar browser.
  A CVar is set out of combat only, through `pcall`, and only one that exists on the client is shown. The values set
  there are kept in `db.cvars` (put back at login, in the profiles); a change made elsewhere updates them (SetCVar hooks).
- `ItemLevels.lua` (`/wl ilvl`): from SimpleItemLevel. Marks live on a child frame of each Blizzard item button, kept in a
  weak table (nothing written in Blizzard's tables); it does nothing while SimpleItemLevel itself is loaded.
- `GuildPositions.lua` (`/wl map`): guild members on the maps. It **sends addon messages to the GUILD** (the user asked for it),
  with GuildMap's prefix `GuildMapEx1` and fields so both addons see each other: keep that format. Pins through
  HereBeDragons in `Libs/` (the "-gm" Forever copy from GuildMap, loaded first in the .toc).
- **Test all** (`/wl test`, header button): `W.RegisterTest(label, enabledFn, runFn, stopFn)` in the module file. A test
  must end by itself (timer) and `stopFn` must hide it. Never send addon / chat messages from a test.
- **Cost** (`/wl perf`): every `W.On` handler, `W.After` timer, roster and ready function is timed (max of one run,
  count, total). A hook on Blizzard code that can run often (`hooksecurefunc`, `HookScript`, tooltip callbacks) is
  wrapped with `W.Timed("label", fn)` so it shows there too (see `ItemLevels.lua`). Anything that must run every
  frame (`OnUpdate`) is only set while its frame is shown, and throttled (0.1 s or more) when a timer text is enough.

## Commands and docs
- A new `/wl` sub-command goes in `W.slash` **and** in the `HELP` list of `Core.lua` (`/wl help`, with its French text)
  **and** in the "Commandes" table of `README.md`.
- `README.md` is the user-facing doc (French): keep its feature list and command tables in sync with the code.

## Releases
- Releases are made by pushing a tag `v1.x.x` (GitHub workflow builds the zip that WowUp-CF installs). A push to `main`
  without a tag does not update the players. Guild members use WowUp-CF: **batch changes**, do not bump `## Version:`
  or propose a tag after every fix; release only when the user asks.

## Module pattern (copy this)
Every file starts with:
```lua
-- WarLegend RaidTool - ModuleName
-- One or two lines saying what the module does.
local W = WLRT
local L = W.L
local db
```
- **Saved data**: `W.OnReady(function() db = W.DB("moduleKey", { option = false }) end)`.
  Defaults are scalars only. SavedVariables is `WarLegendRaidToolDB` (`W.db`). Changing the format of
  existing saved data needs `W.Migration(version, key, fn)`.
- **Events**: `W.On("EVENT_NAME", fn)` (one shared frame). Returns a handler; pass `inactive = true`
  (4th arg) to start it off and switch with `W.Activate(handler, on)`. Handlers only run once the
  player is confirmed in the War Legend guild (`W.Allowed()`), except core ones with `always = true`.
  Group changes: `W.OnRoster(fn)`. Timers: `W.After(seconds, fn)`.
- **Window tab**: `W.RegisterModule("Key", "Label", function(panel) ... end, refreshFn)`.
  Build the UI with `W.Title(p, text)`, `W.Check(p, text, get, set, tip)`, `W.Button(p, text, w, h, onClick, tip)`,
  `W.Label(p, text, font)`, `W.EditBox(p, w, maxLetters)`, `W.Cycle`, `W.ScrollList`, `W.Table`, `W.SubTabs`,
  then `:SetPoint("TOPLEFT", x, -y)`. To show the module in the menu, add its key to `CATEGORIES`
  in `Core.lua`: three tabs, Raid (the raid night in order: Organisation, Preparation, Combat, Loot, then PvP; collapsible
  sections), Guild (Members, My characters) and Options (Addon, Interface: nothing to do with a raid or the guild). A key
  left out goes to the last section of Options.
- **Slash sub-command**: `W.slash.name = function(rest) ... end` gives `/wl name`.
- **Chat output**: `W.Print(msg)` (local), `W.Announce(text, channel)` / `W.SendChat(...)` (public).
- **Addon messages**: `W.OnAddon(prefix, fn)` to receive, `W.Send(prefix, msg, channel, target)` to send,
  `W.Pack` / `W.Unpack` for fields, `W.SendLong` / `W.OnAddonLong` for long texts.
- **Group / names**: `W.InRaid()`, `W.InGroup()`, `W.IsLeader()`, `W.CanLead()`, `W.GroupUnits()`,
  `W.FullName(name)`, `W.UnitKey(unit)`, `W.ColorName(name, class)`.

## Translations (English source, French on frFR clients)
- Every visible text goes through `L("English text")` — a function call, **not** `L["..."]`.
- The French version goes in the **same module file**, near the top:
  ```lua
  W.AddFR({
      ["Combat logging started."] = "Journal de combat démarré.",
  })
  ```
- The language is only known at `ADDON_LOADED`: call `L()` inside build functions, event handlers or
  `W.OnReady`, not at file load time. Tables of texts built at load time use `W.TranslateField(list, field)`.
- Keep color codes (`|cff......|r`) and `%s` / `%d` identical in the French string.

## How to work here
0. Read `STATUS.md` (next to this file) first: the feature in progress, the decisions already taken, the next step.
1. Say which file(s) you will touch and why, in one or two lines.
2. Read them, then edit with small, targeted changes in the existing style. The source is the git repo
   `C:\Dev\WarLegendRaidTool`; copy every changed file to the same path in the game's AddOns folder too.
3. Finish with: what changed, what to test in game (`/reload`, which `/wl` command or window tab).
4. At the end of the session, update `STATUS.md` (French, short): "Maintenant" (version published / unpushed
   commits, feature in progress, files, decisions, what was verified, next step), move what is done to
   "Historique", keep "Pistes ouvertes" current. It is not shipped (excluded from the release zip).
