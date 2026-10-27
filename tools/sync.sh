#!/usr/bin/env bash
# WarLegend RaidTool - copy the repo's addon folders to the game's AddOns folder(s) (not shipped).
# Usage: bash tools/sync.sh [--force]
# Without WLRT_GAME it copies to the _forever_ client (the Classic beta is no longer used); WLRT_GAME (an AddOns
# folder) copies to that one instead.
# A game file is overwritten only when it is missing, is a version of this branch's history (or the index) or is our
# last copy: a file changed ONLY in the game folder, or copied there from another branch / worktree, is skipped and
# listed, so no work is lost and no newer code is replaced by older (see 1.27.1, 26/10).
# --force overwrites those too. Nothing is ever deleted in the game folder. Prints only what it did.
# Only files git tracks (committed or "git add"-ed) are copied: untracked files are listed, ignored ones never seen.
# Symbolic links are never followed, in the repo or in the game folder (skipped and listed).
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
GAME="${WLRT_GAME:-}"
FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1
if [ -z "${WLRT_GAME:-}" ]; then
    WOW="/c/Program Files (x86)/World of Warcraft"
    rc=0; n=0
    for flavor in _forever_; do
        [ -d "$WOW/$flavor/Interface/AddOns" ] || continue
        echo "== $flavor"
        WLRT_GAME="$WOW/$flavor/Interface/AddOns" WLRT_STATE="wlrt-synced${flavor}" bash "$0" "$@" || rc=1
        n=$((n + 1))
    done
    [ $n -gt 0 ] || { echo "No game AddOns folder found under: $WOW"; exit 1; }
    exit $rc
fi
cd "$REPO" || exit 1
[ -d "$GAME" ] || { echo "Game AddOns folder not found: $GAME"; exit 1; }

# WarLegendRaidTool_Dev: internal testing addon (/wl verify), copied to the game but never in the release zip
ADDONS=(WarLegendRaidTool WarLegendRaidTool_Raid WarLegendRaidTool_PvP WarLegendRaidTool_Skyborne WarLegendRaidTool_Dev)
copied=0; skipped=0; untracked=0
# What this script last copied (path -> blob): a game file still equal to it is OUR previous copy (an edit not committed
# yet), so it is safe to replace; only a game file that is neither in git nor our last copy is someone's own change.
STATE="$(git rev-parse --git-dir)/${WLRT_STATE:-wlrt-synced}"
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
        # a version git knows but this branch never had (copied from another branch / worktree, maybe newer): replacing
        # it would put older code in the game (26/10, Core.lua); only one of this branch's history or index is replaced
        if [ "$blob" != "${synced[$f]:-}" ] && [ "$blob" != "$(git rev-parse -q --verify ":$f" 2>/dev/null)" ] &&
            ! git log --format= --raw --no-abbrev HEAD -- "$f" | grep -q -- "$blob"; then
            echo "SKIP (game file is from another branch or worktree, maybe newer; --force to replace): $f"
            skipped=$((skipped + 1))
            continue
        fi
    fi
    mkdir -p "$(dirname "$dst")"
    if cp "$f" "$dst"; then
        echo "copied: $f"
        copied=$((copied + 1))
        synced["$f"]="$(git hash-object --path="$f" "$dst")"
    else
        echo "FAILED to copy: $f"
        skipped=$((skipped + 1))
    fi
done < <(git ls-files -z -s -- "${ADDONS[@]}")

for f in "${!synced[@]}"; do printf '%s	%s
' "${synced[$f]}" "$f"; done > "$STATE"
echo "$copied copied, $skipped skipped, $untracked not tracked."
[ $skipped -eq 0 ]
