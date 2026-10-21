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
- **Raid addon** `../WarLegendRaidTool_Raid` (raid modules, load-on-demand via `W.LoadRaid`; a new addon-message prefix
  goes in `lodPrefix` too) and **PvP addon** `../WarLegendRaidTool_PvP` (battleground frames, `W.LoadPvP`; trinket / DR
  tracking is NOT possible in battlegrounds). Each lists its files in ITS `.toc`.
- `Roster.lua`, `GuildBank.lua`, `BGStats.lua` are **personal only: no addon messages** (the user's choice).
  `GuildPositions.lua` does send to the GUILD with GuildMap's prefix `GuildMapEx1`: keep that format.
- Options: a whole-addon option goes in Settings > General; **a new option saved as a table goes in `TABLE_FIELDS`**
  (`Settings.lua`); a module with its own event frame checks `W.IsOff("Key")` in its OnEvent.
- `MoveFrames.lua` never moves a protected frame (no action bars, unit / group frames, buffs, minimap). CVars are set out
  of combat through `pcall`. `ItemLevels.lua` writes nothing in Blizzard's tables.
- Tests (`W.RegisterTest`) end by themselves and never send messages. Frequent hooks on Blizzard code are wrapped in
  `W.Timed("label", fn)`; an `OnUpdate` runs only while its frame is shown, throttled.
- **Detail behind these rules**: `C:\Dev\WarLegendRaidTool\docs\modules.md` — read the part about a file only when you
  change that file.

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
  `W.Label(p, text, font)`, `W.EditBox(p, w, maxLetters)`, `W.Cycle` (a drop-down of values), `W.ScrollList`, `W.Table`, `W.SubTabs`,
  then `:SetPoint("TOPLEFT", x, -y)`. To show the module in the menu, add its key to `CATEGORIES`
  in `Core.lua`: three tabs, Raid (the raid night in order: Organisation, Preparation, Combat, Loot, then PvP), Guild (Members, My
  characters) and Options (Addon, Interface: nothing to do with a raid or the guild), all with collapsible sections. A key
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
Sessions are opened in `C:\Dev\WarLegendRaidTool` (its `CLAUDE.md` loads this file and `STATUS.md`).
0. Read `STATUS.md` (next to this file) first, unless it is already loaded: feature in progress, decisions, next step.
1. **Same or new session**: at the start of every user request, say in one line whether it is better done in this
   session or in a new one, to save tokens. New session when the request does not build on this session's work (another
   feature or module), when the current feature is done and verified, or when the session is long (about 100 exchanges,
   or a compaction already happened). Same session for a fix, a follow-up or a test result of the current work. When it
   is "new session", update `STATUS.md` first so the next one starts from it.
   **Vague request** (which module, which behaviour, what "done" looks like is unclear): ask short questions first
   (`AskUserQuestion`, 1 to 4 questions with choices) instead of exploring the code to guess. The user prefers that.
2. Say which file(s) you will touch and why, in one or two lines.
3. Read them, then edit with small, targeted changes in the existing style. The source is the git repo
   `C:\Dev\WarLegendRaidTool`; then run `bash tools/sync.sh`: it copies the changed files to the game's AddOns folder
   and skips (lists) any file changed only there — never overwrite those without asking. **After every change the game
   folder must hold the newest version** (the user plays from it): run it after each edit, read its output (a new file
   must be `git add`-ed to be copied), and say in the report that the game folder is up to date. Before a release:
   `bash tools/sync.sh` must show nothing skipped except `STATUS.md`; never tag with the game folder behind.
4. Before saying the code is verified, and before every push: `node tools/check.js` (syntax Lua 5.1, BOM / CRLF, .toc,
   globals, names used above their `local` declaration; across the three addons: `W.X` never assigned, `/wl` commands
   vs HELP / README, module keys vs `CATEGORIES`, addon prefixes sent vs received vs `lodPrefix`, `L()` without French).
   Read every line it prints. Never filter its output. No need to re-check those by hand. When Lua code changed, also
   `node tools/smoke.js` (simulated client, about 20 s; a new legacy API call may need a line in `tools/smoke/wow.lua`
   once you checked the function exists) and `node tools/wow-api.js check`; `--open-world` / `--bg` too when the change
   touches the open world / battlegrounds (PvP addon, frame cost). The CI runs them all on every push, with Luacheck.
5. Finish with: what changed, what to test in game (`/reload`, which `/wl` command or window tab).
6. At the end of the session, update `STATUS.md` (French, short): "Maintenant" (version published / unpushed
   commits, feature in progress, files, decisions, what was verified, next step), move what is done to
   "Historique" (last three versions only: git tags keep the rest), keep "Pistes ouvertes" current.
   It is not shipped (excluded from the release zip).

## Token economy (the user asked for it; quality first)
- Search before reading: `Grep -n` for the function, then read that range. `Core.lua` (100 KB), `Guild.lua`,
  `RaidGroups.lua`, `LootCouncil.lua`, PvP `Main.lua` are big: never read them whole, never re-read a range you
  already have and did not change. List of Core's API: `grep -n "^function W\." WarLegendRaidTool/Core.lua`.
- Keep command output short: `git diff --stat`, `grep -c`, `| head`, `| tail`. No `cat` of big files or logs.
- Web pages: `get_page_text` / `read_page` or a `zoom` on one region rather than full screenshots.
- Batch independent reads / searches in one call. No sub-agents for code search here: a targeted Grep is cheaper.
- Never trade a needed check for tokens: say the trade-off instead.
- **Local AI** (Ollama on the user's PC, nothing leaves it): `node tools/ask-local.js "instruction" --file path`.
  The script reads the files, so you only read its short answer. Use it when it saves real reading: summary of a long
  log / diff / error dump / big file you would otherwise read, first French draft of many new `L()` strings. Not for
  a few lines (slower than doing it yourself), never for WoW API, code or design decisions; check what it returns.
  While WoW runs it puts on the graphics card only what fits with 4 GB of video memory left free for the game, the
  rest on 3 CPU threads at low priority. An answer takes about 20 s to 1 minute: run long ones in the background.
  `--bug "symptom" --file x.lua` gives a first diagnosis (line + fix; right about one time in two on new bugs, the fix
  itself often wrong: check both), `--each` asks the same question about many files in one call. A bug fixed live that
  it missed: add its lesson to `tools/local-ai-catalogue.md` (one numbered line, no code from the fix).
