#!/usr/bin/env bash
# WarLegend RaidTool - copy the repo's three addon folders to the game's AddOns folder (not shipped).
# Usage: bash tools/sync.sh [--force]
# A game file is overwritten only when it is missing or is a version git already knows (some past commit or the
# index): a file changed ONLY in the game folder is skipped and listed, so no work is lost (see 1.27.1).
# --force overwrites those too. Nothing is ever deleted in the game folder. Prints only what it did.
# Only files git tracks (committed or "git add"-ed) are copied: untracked files are listed, ignored ones never seen.
# Symbolic links are never followed, in the repo or in the game folder (skipped and listed).
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
GAME="${WLRT_GAME:-/c/Program Files (x86)/World of Warcraft/_classic_beta_/Interface/AddOns}"
FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1
cd "$REPO" || exit 1
[ -d "$GAME" ] || { echo "Game AddOns folder not found: $GAME"; exit 1; }

ADDONS=(WarLegendRaidTool WarLegendRaidTool_Raid WarLegendRaidTool_PvP WarLegendRaidTool_Skyborne)
copied=0; skipped=0; untracked=0
# What this script last copied (path -> blob): a game file still equal to it is OUR previous copy (an edit not committed
# yet), so it is safe to replace; only a game file that is neither in git nor our last copy is someone's own change.
STATE="$(git rev-parse --git-dir)/wlrt-synced"
declare -A synced
if [ -f "$STATE" ]; then
    while IFS=$'	' read -r blob path; do [ -n "$path" ] && synced["$path"]="$blob"; done < "$STATE"
fi
while IFS= read -r -d '' f; do
    echo "NOT TRACKED (git add it to sync): $f"
    untracked=$((untracked + 1))
done < <(git ls-files -z -o --exclude-standard -- "${ADDONS[@]}")

# -s gives "mode blob stage<TAB>path": mode 120000 is a symbolic link, even where git checked it out as a plain file
while IFS= read -r -d '' entry; do
    mode="${entry%% *}"
    f="${entry#*$'\t'}"
    dst="$GAME/$f"
    if [ "$mode" = "120000" ] || [ -L "$f" ] || [ -L "$dst" ]; then
        echo "SKIP (symbolic link): $f"
        skipped=$((skipped + 1))
        continue
    fi
    [ -f "$f" ] || continue # in the index but deleted on disk
    [ -f "$dst" ] && cmp -s "$f" "$dst" && continue
    if [ -f "$dst" ] && [ $FORCE -eq 0 ]; then
        blob="$(git hash-object --path="$f" "$dst")"
        if ! git cat-file -e "$blob" 2>/dev/null && [ "$blob" != "${synced[$f]:-}" ]; then
            echo "SKIP (changed only in the game folder): $f"
            skipped=$((skipped + 1))
            continue
        fi
    fi
    mkdir -p "$(dirname "$dst")"
    if cp "$f" "$dst"; then
        echo "copied: $f"
        copied=$((copied + 1))
        synced["$f"]="$(git hash-object --path="$f" "$dst")"
    fi
done < <(git ls-files -z -s -- "${ADDONS[@]}")

for f in "${!synced[@]}"; do printf '%s	%s
' "${synced[$f]}" "$f"; done > "$STATE"
echo "$copied copied, $skipped skipped, $untracked not tracked."
[ $skipped -eq 0 ]
