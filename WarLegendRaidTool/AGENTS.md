# WarLegendRaidTool — context for coding agents

World of Warcraft **Classic** addon (WoW Forever client, `_forever_` folder, `## Interface: 16001`) for the "War Legend" guild:
raid groups, loot council, buffs, ready check, attendance, who pulled, inspect, aura
tracking, raid cooldowns, alts, guild tools, trials, guild bank characters, battleground frames / graveyard
timer / premade history. Slash command `/wl` (also `/wlrt`, `/warlegend`), `/wl help` lists every command.
Current version is in `WarLegendRaidTool.toc` (`## Version:`).

The user is French but asked (23/10) for **answers in English** (fewer tokens). Code, comments and English UI strings stay in English; French only in `W.AddFR`, README and STATUS.md.

## Hard rules
- **Lua 5.1** (WoW): no `goto`, no `//`, no bitwise operators, no `table.unpack` (use `unpack`).
- **Never invent WoW API functions.** If you are not sure an API exists on Classic, say so and
  guard it like the existing code does: `if C_ChatInfo and C_ChatInfo.X then ... else OldGlobal(...) end`.
- **Read a file before editing it.** Make the smallest change that works. Never rewrite a whole file,
  never rename existing functions, globals, DB keys or addon-message prefixes.
- Files are **UTF-8 without BOM, LF line endings, 4-space indentation**. Keep it that way
  (French accents in strings must stay valid UTF-8).
- Secure frames / protected actions cannot change in combat: check `InCombatLockdown()` first.
- **Text from other players** (addon message, whisper, chat line, pasted profile) is bounded before any pattern runs on
  it: a size cap per prefix (`W.OnAddonLong(prefix, fn, max)`, `#field` / `#line` checks), a split with a single class
  (`gmatch("[^;]+")`) or plain `find(sep, 1, true)`, then anchored patterns on short pieces. Never a pattern with a
  repeated class before a literal (`(.-)%s*=`, `([^=;]+)=`, `(%d+):(%d+)`) unanchored on a received field: quadratic or
  cubic, one message froze every client (audit 28/10). `tools/smoke/scenario.lua` "long texts" checks the long prefixes,
  "chat lines" the chat parsers, "paste" the importers, and every text shown is checked for escape codes of other players.
- There are no automated tests. The user tests in game with `/reload`. Say what to test.

## Blizzard ToS check (every change, every changed line)
Sources, read in full on 27/10/2026: **Policy** = UI Add-On Development Policy (8 clauses,
us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534, also in `tools/watch.json`); **EULA** = Blizzard End
User License Agreement, revised 21/03/2024, section "License Limitations" (Policy 7 sends add-ons to it);
**client** = enforced by the game (protected functions), not written in either text. Walk each changed line through
this list; a line that fails it is a blocker, whatever the user asked (explain instead of coding it).
1. **Free** (Policy 1). No paid or "premium" version, no feature behind payment, no charge for a service tied to the
   addon.
2. **Code visible** (Policy 2). No hidden, obfuscated or minified code; ported libraries keep their readable source
   and licence.
3. **No harm to realms or other players** (Policy 3). Its examples: excessive use of the chat system, unnecessary
   loading from the hard disk, slow frame rates. So: public announces off by default or sent on click, automatic
   whispers / replies opt-in, rate-limited and listed in the "Accepted exceptions" below (rule 7), nothing posted in
   public channels at login; addon messages through `W.Send`
   (queue, throttle), bounded per sender, replies spread; `RequestRaidInfo`, inspect, guild-roster requests throttled;
   no heavy `OnUpdate` / scans (`smoke.js` cost, `W.Timed`); SavedVariables kept bounded.
4. **No advertising** (Policy 4; EULA "Prohibited Commercial Uses" iv: no commercial advertisement, solicitation or
   offer through the game, also in chat lines the addon sends). Guild recruitment text is not commercial: fine.
5. **No donation request in the game** (Policy 5). Credits and links to a donation page only on the download site,
   never in the UI, chat or tooltips.
6. **Nothing offensive** (Policy 6: rated "T"). Applies to texts, presets, default messages, images.
7. **No automation, no bot** (EULA "Cheating": bots = code "that allows the automated control of a Game"; client:
   protected actions need a hardware event). A protected action and a chat line on SAY / YELL / a channel outside an
   instance run only in the call chain of a click or key press: `OnClick`, a secure button, a `W.Confirm` button. Never
   from `OnUpdate`, `W.After`, a ticker, an event handler or an addon-message handler. One click = one action the
   player chose (a secure macro run by that same click is fine); nothing goes on acting after it. Protected =
   secure-only (cast / use, target, focus: secure buttons and macros) or `HasRestrictions` in Blizzard's Forever API
   docs (build 1.60.1.70532, `tools/.cache/wow-ui-source`): `C_PartyInfo` ConvertToRaid / ConvertToParty /
   UninviteUnit / PromoteToAssistant / PromoteToLeader / DemoteAssistant / SetEveryoneIsAssistant / SetLootMethod /
   DoReadyCheck / DoCountdown; raid marks (SetRaidTarget, PlaceRaidMarker, ClearRaidMarker, RemoveRaidTargets);
   `C_ChatInfo.SendChatMessage` (the client asks a click for SAY / YELL / CHANNEL outside an instance; group, raid and
   whisper lines it lets through, but ours too go out only on a click, a list one confirmation click per 3 lines
   (`W.AnnounceLines`); the automatic ones are rule 3 replies in the exceptions below) / `PerformEmote`;
   `C_GuildInfo` RemoveFromGuild / SetNote / SetMOTD / SetInfoText /
   SetGuildRankOrder; `C_TradeInfo` money; `C_Macro.RunMacroText`; `C_ClickBindings`; `C_SettingsUtil.OpenSettingsPanel`;
   `C_Item.DeleteItem`. **Not restricted**: `InviteUnit` (invites queued after one click are standard) and addon
   messages. Old globals missing from the docs (`SetRaidSubgroup`, `SwapRaidSubgroup`, `GiveMasterLoot`, guild rank
   changes, AH, equip, macro / binding changes): treated as restricted until a test in game says otherwise.
8. **Remote input acts on nothing** (follows from 7 and EULA "Disruption / Harassment"). A received addon message,
   whisper or chat line never casts, invites, marks, gives loot or sends a public line by itself: it shows
   information, or a question the local player must click (`W.ConfirmRemote`). A hostile sender must not be able to
   make us spam or grief others.
9. **No cheat, no exploit, no hack** (EULA "Cheating": cheats = unauthorised methods incl. "exploits of any in-game
   bugs" giving an advantage; hacks = modifying the game software; client: secret values, taint). No reading secret
   values around `issecretvalue`, no taint tricks to reach a protected function (insecure call into Blizzard secure
   code, overwriting Blizzard functions: use `hooksecurefunc`), no moving protected frames (`MoveFrames.lua` rule), no
   use of a known game bug for an advantage, no file outside the AddOns folder touched.
10. **No data leaving the game** (EULA "Data Mining": add-ons are allowed only as Blizzard-permitted user interfaces).
    Nothing collected beyond what the game shows; addon messages only to GROUP / RAID / GUILD / a whisper target
    (Skyborne's documented public channel is the one exception); no player data in links or strings meant for
    outside sites.
11. **No commercial use of the game** (EULA "Prohibited Commercial Uses" ii, iii, v). No tool for gold / item selling
    outside the game, paid boosts or wagering (no betting on rolls, duels or boss kills).
12. **Blizzard may switch anything off** (Policy 8). An API that Blizzard removes or protects is not a bug to work
    around: guard it and degrade (`if X then ... end`), never try to get the old behaviour back by another path.
If a rule cannot be checked from the code alone (API behaviour on Forever), write `UNVERIFIED ToS: <what>` in the report.

**Accepted exceptions** (audit 28/10; opt-in, off by default unless said, the player switched them on: not to flag
again, but a new one needs the user's yes): rules 7 / 8: InviteTool keyword and Battle.net whisper invites
(`InviteUnit`, not restricted; once per 30 s per sender, auto-convert for guild members only) and accepting invites
suggested by the group; AutoPromote on roster events (`PromoteToAssistant` is `HasRestrictions`: UNVERIFIED ToS, may be
refused outside a click, 5/11); Focus putting back the
key binding the player chose, out of combat; QualityOfLife junk selling and quests at the vendor / NPC the player
opened; Loot Council putting owed items in the trade window on `TRADE_SHOW` (the master looter still clicks Accept);
Summon's group line (one line, 3 s after the first request). Added 29/10 (user's yes, audit of 29/10 HIGH 6): the
Loot Council `!sr` whisper reply (off by default, to the asker only, 3 per 10 s); QualityOfLife accepting group invites
from friends / guild members (by GUID) and resurrections out of combat (both off by default, Shift skips). Rule 10:
SimExport and the Attendance / loot CSV are the player's own data, copied by hand from a text box, never sent anywhere.
**Moved into the click** (29/10, not exceptions): the Raid Groups mover (one move per click, then a "Next move"
confirmation), the mass-invite conversion to raid (a confirmation when the first player joins), the Loot Council award
line (said by the award click), announce lists (3 lines per click), the Myslot import (bars, macros, key bindings in
the confirmation's Yes, in one go, no timer; recoded 29/10); WhoPulled never announces on Forever; shared quests
are not auto-accepted.

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
- Options:
  - a whole-addon option goes in Settings > General;
  - **a new option saved as a table goes in `TABLE_FIELDS`** (`Settings.lua`, `{ dbKey = { field = true } }`): it lists
    which table fields are options, so profiles export / import them (any other table is treated as data and skipped);
  - a module with its own event frame checks `W.IsOff("Key")` in its OnEvent.
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
- The repo root `README.md` is the GitHub landing page (French, short: logo `.github/assets/logo.png`, a table of the tabs
  and sections, install, main commands; not in the zip). Update it when a tab / section of `CATEGORIES` or one of the
  commands it lists changes.
- The repo root `CHANGELOG.md` is for the players (French, not in the zip): each change a player notices adds one short
  line under `## Prochaine version` (`### Ajouté` / `### Modifié` / `### Corrigé`). Its sections become the release notes.

## Releases
- Releases are made by pushing a tag `v1.x.x` (GitHub workflow builds the zip that WowUp-CF installs). A push to `main`
  without a tag does not update the players. Guild members use WowUp-CF: **batch changes**, do not bump `## Version:`
  or propose a tag after every fix; release only when the user asks.
- Release commit: with the `## Version:` bump, rename `## Prochaine version` of `CHANGELOG.md` to `## X.Y.Z (dd/mm/yyyy)`
  and put a new empty `## Prochaine version` above it. `check.js` refuses a `## Version:` without notes in its section;
  the release workflow copies that section into the GitHub release notes (above the compare link).
- **Release gate (since 24/10)**: no tag before the first in-game session on Forever (planned 5 November) has run
  `/wl verify` and its results were read (`node tools/verify-live.js`, `--follow` while the game runs, `--saved` after a
  `/reload`) and every `LOOK` line was fixed or accepted by the user. Gated items: audit M1 (master loot candidates
  without surname, `LootCouncil.lua` `IsCandidate`), slot 18, compression on the client's own deflate, and the module
  tests with 0 new Lua error. Until then, a release request: say this gate is open and ask before tagging.
- **`WarLegendRaidTool_Dev`** (`/wl verify`, `Verify.lua`, saved in `WarLegendRaidTool_DevDB`) is for **internal testing
  only**: `sync.sh` copies it to the developer's game, the release zip never holds it (the workflow refuses a zip that
  does), its `/wl` commands are not in HELP / README and the shipped addons never depend on it. Never add it to the zip,
  never move its code into the shipped addons.

## Module pattern (copy this)
Every file starts with:
```lua
-- WarLegend RaidTool - ModuleName
-- One or two lines saying what the module does.
local W = WLRT
local L = W.L
local db

W.AddFR({
    ["English text"] = "Texte français",
})
```
- **Saved data**: `W.OnReady(function() db = W.DB("moduleKey", { option = false }) end)`.
  Defaults are scalars only. SavedVariables is `WarLegendRaidToolDB` (`W.db`). Changing the format of
  existing saved data needs `W.Migration(version, key, fn)`.
- **Events**: `W.On("EVENT_NAME", fn)` (one shared frame). Returns a handler; pass `inactive = true`
  (4th arg) to start it off and switch with `W.Activate(handler, on)`. Handlers only run once the
  player is confirmed in the War Legend guild (`W.Allowed()`), except core ones with `always = true`.
  Group changes: `W.OnRoster(fn)`. Timers: `W.After(seconds, fn)`.
- **Window tab**: `W.RegisterModule("Key", "Label", function(p) ... end, refresh)`: the build
  function runs once, the first time the tab opens; `refresh(p)` (optional) runs each time the tab is shown, to update
  the widgets. Build the UI with `W.Title(p, text)`, `W.Check(p, text, get, set, tip)`, `W.Button(p, text, w, h, onClick, tip)`,
  `W.Label(p, text, font)`, `W.EditBox(p, w, maxLetters)`, `W.Cycle` (a drop-down of values), `W.ScrollList`, `W.Table`, `W.SubTabs`,
  then `:SetPoint("TOPLEFT", x, -y)`. To show the module in the menu, add its key to `CATEGORIES`
  in `Core.lua`: four tabs, Raid (the raid night in order: Organisation, Preparation, Combat, Loot and attendance), PvP (Battlegrounds,
  Open world), Guild (Members, My characters) and Options (Addon, Interface, Small automations: nothing to do with a raid or the
  guild), all with every section visible under plain captions (no accordion). A key left out goes to the last section of Options.
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
  `W.OnReady`, not at file load time (wrong: `local TITLE = L("Raid")` at the top of a file; right: `L("Raid")` in the
  build function). Tables of texts built at load time use `W.TranslateField(list, field)`.
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
   `C:\Dev\WarLegendRaidTool` (never edit the game folder: it is a copy); then run `bash tools/sync.sh`: it copies the changed files to the game's AddOns folder
   and skips (lists) any file changed only there — never overwrite those without asking. **After every change the game
   folder must hold the newest version** (the user plays from it): run it after each edit, read its output (a new file
   must be `git add`-ed to be copied), and say in the report that the game folder is up to date. Before a release:
   `bash tools/sync.sh` must show nothing skipped except `STATUS.md`; never tag with the game folder behind.
4. Before saying the code is verified, and before every push: `node tools/check.js` (syntax Lua 5.1, BOM / CRLF, .toc,
   globals, names used above their `local` declaration; across the three addons: `W.X` never assigned, `/wl` commands
   vs HELP / README, module keys vs `CATEGORIES`, addon prefixes sent vs received vs `lodPrefix`, `L()` without French,
   upvalues per function: WoW refuses a whole file with a function past 60, fengari / the smoke test does not; the CI
   also compiles every loaded file with Lua 5.1's `luac5.1`, the PC has none).
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
- Smoke bench: `node tools/smoke.js --quiet` first (also with `--open-world` / `--bg`): only what fails, under one line
  per pass, same verdict and exit code (2 or 3 lines instead of about 110 when all passes). `--verbose` only on a failure, with
  `--quiet` kept to see just the failures in full (every FAIL line, the stack of each Lua error).
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
