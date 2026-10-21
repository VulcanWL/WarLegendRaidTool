# WarLegend RaidTool (repo root)

Open sessions here. The project rules and the current state are loaded from these files (not shipped: the release
zip holds only the three addon folders):

@WarLegendRaidTool/AGENTS.md
@WarLegendRaidTool/STATUS.md

Tools: `node tools/check.js` (checks, also the cross-file ones: W fields, `/wl` vs HELP / README, CATEGORIES,
addon prefixes / lodPrefix, missing French; `npm install --prefix tools` once if `tools/node_modules` is missing),
`bash tools/sync.sh` (copy to the game folder), module detail in `docs/modules.md`.
Also: `node tools/smoke.js` (the addons run in a simulated client: Lua errors, protected actions in combat, messages
sent by tests or caused by hostile addon messages, cost; `--open-world`: raid of 40 / guild of 120; `--bg`: Alterac
40 vs 40, cost of each frame), `node tools/wow-api.js check` (API used vs Blizzard's
documentation of the Forever build), `node tools/deps-watch.js` (upstream libraries / ported addons / Blizzard policy);
the CI and the watches of `.github/workflows` run them (see "Checks and watch" in `docs/modules.md`).
