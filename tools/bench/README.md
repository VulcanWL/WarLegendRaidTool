# Local AI benchmark (not shipped)

Measures how well the local AI (Ollama, `tools/ask-local.js`) finds Lua bugs of this project, against Sonnet on the
same prompts. Only 127.0.0.1 is contacted; nothing in the repo or in Ollama is changed (the prompt goes with each
request). GPU energy is read with nvidia-smi.

## Cases
- `real/` 12 bugs fixed live (code before the fix from git history + the symptom as reported in game). L1, L2, L6, L8,
  L10, L11 are the "train" ones: `tools/local-ai-catalogue.md` was written from them only. L3, L4, L5, L7, L9, L12 test.
- `cases/` B1-B6: bugs seeded in modules for a review without symptom (B6 has none), C1-C4 / R1 comprehension.
- `holdout/` H1-H5: seeded in files never used before. Sealed until the 2026-10-18 final run, so no longer blind:
  for a new honest measure, build a new set the same way (`build-holdout.js` as a model) and look at it only once.
- `sonnet-*/` Sonnet's answers to the same prompts: the reference.

## Run
    node tools/bench/loop.js <round> P2 gptoss-low          debug + review cases, one leaderboard line per cell
    set HOLDOUT=1 first to add the H cases
    node tools/bench/regrade.js                              leaderboard of every round, strict grading
    node tools/bench/static-check.js                         what tools/check.js catches alone (0 Wh)
    node tools/bench/throughput.js                           answers per minute and Wh, 1 / 2 / 4 at a time
    node tools/bench/run-local.js                            the first benchmark (comprehension C1-C4, long file R1)
Prompts: P0 bare, P1 rules + short format, P2 + catalogue (what `ask-local.js --bug` sends), P3 + "traps, not a
checklist"; a V suffix adds a self-check pass (it rejected right answers: not used). The grader wants the line (+-1)
and a keyword of the cause; answers without a "ligne N" format cannot be graded reliably. Check the best cells by hand.

## Results 2026-10-18 (RTX 5070 Ti 16 GB, WoW closed)
| | real bugs, new (6 test + 3 sealed) | review (12 seeded) | false alarms | Wh / answer |
|---|---|---|---|---|
| Sonnet | 9 / 9 | 11 / 12 | 0 | - |
| gpt-oss:20b low + P2 | about 5.5 / 9 | 2 / 12 | 8 | 0.2 - 0.3 |
| qwen3.6 35B no thinking + P2 / P3 | about 4.5 / 9 | 3-4 / 12 | 4 to 85 | 0.16 - 0.3 |
Repeat runs vary: gpt-oss:20b low + P2 at temperature 0.2 (as ask-local.js, the loop's setting since) found 2 of the 6
test bugs twice in a row. Count on about one new bug in two, and run a cell at least twice before comparing.
gpt-oss:20b reads 64k tokens on the card (Core.lua whole, 4/4 questions right); qwen3.6 35B did not fit (CPU spill,
CUDA crashes when switching models, half of a long prompt silently cut). Thinking modes cost 3-15x the energy
without better answers. tools/check.js alone catches 4 of the 25 bugs at no cost. Detail: `leaderboard-strict.json`.
