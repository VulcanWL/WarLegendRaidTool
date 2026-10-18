# WarLegend RaidTool (repo root)

Open sessions here. The project rules and the current state are loaded from these files (not shipped: the release
zip holds only the three addon folders):

@WarLegendRaidTool/AGENTS.md
@WarLegendRaidTool/STATUS.md

Tools: `node tools/check.js` (checks, also the cross-file ones: W fields, `/wl` vs HELP / README, CATEGORIES,
addon prefixes / lodPrefix, missing French; `npm install --prefix tools` once if `tools/node_modules` is missing),
`bash tools/sync.sh` (copy to the game folder), module detail in `docs/modules.md`.
