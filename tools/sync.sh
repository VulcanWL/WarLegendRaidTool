#!/usr/bin/env bash
# WarLegend RaidTool - copy the repo's three addon folders to the game's AddOns folder (not shipped).
# Usage: bash tools/sync.sh [--force]
# A game file is overwritten only when it is missing or is a version git already knows (some past commit or the
# index): a file changed ONLY in the game folder is skipped and listed, so no work is lost (see 1.27.1).
# --force overwrites those too. Nothing is ever deleted in the game folder. Prints only what it did.
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
GAME="${WLRT_GAME:-/c/Program Files (x86)/World of Warcraft/_classic_beta_/Interface/AddOns}"
FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1
cd "$REPO" || exit 1
[ -d "$GAME" ] || { echo "Game AddOns folder not found: $GAME"; exit 1; }

copied=0; skipped=0
while IFS= read -r f; do
    dst="$GAME/$f"
    [ -f "$dst" ] && cmp -s "$f" "$dst" && continue
    if [ -f "$dst" ] && [ $FORCE -eq 0 ]; then
        blob="$(git hash-object --path="$f" "$dst")"
        if ! git cat-file -e "$blob" 2>/dev/null; then
            echo "SKIP (changed only in the game folder): $f"
            skipped=$((skipped + 1))
            continue
        fi
    fi
    mkdir -p "$(dirname "$dst")"
    cp "$f" "$dst" && echo "copied: $f" && copied=$((copied + 1))
done < <(git ls-files -co --exclude-standard -- WarLegendRaidTool WarLegendRaidTool_Raid WarLegendRaidTool_PvP)

echo "$copied copied, $skipped skipped."
[ $skipped -eq 0 ]
