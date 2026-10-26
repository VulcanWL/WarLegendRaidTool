#!/usr/bin/env bash
# WarLegend RaidTool - copy the repo's addon folders to the game's AddOns folder(s) (not shipped).
# Usage: bash tools/sync.sh [--force] [--retail]
# Without WLRT_GAME it copies to the _forever_ client (the Classic beta is no longer used); WLRT_GAME (an AddOns
# folder) copies to that one instead. --retail also copies to _retail_: a test copy only (the .toc are Forever's,
# retail loads them with "Load out of date AddOns" ticked); the players never get a retail version.
# A game file is overwritten only when it is missing or is a version git already knows (some past commit or the
# index): a file changed ONLY in the game folder is skipped and listed, so no work is lost (see 1.27.1).
# --force overwrites those too. Nothing is ever deleted in the game folder. Prints only what it did.
# Only files git tracks (committed or "git add"-ed) are copied: untracked files are listed, ignored ones never seen.
# Symbolic links are never followed, in the repo or in the game folder (skipped and listed).
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
GAME="${WLRT_GAME:-}"
FORCE=0; RETAIL=0
for a in "$@"; do
    case "$a" in --force) FORCE=1 ;; --retail) RETAIL=1 ;; esac
done
if [ -z "${WLRT_GAME:-}" ]; then
    WOW="/c/Program Files (x86)/World of Warcraft"
    rc=0; n=0
    # retail reads a .toc listing its own interface numbers: written in the _retail_ copy only, never in the repo
    RETAIL_INTERFACE="16001, 120000, 120001, 120005, 120007, 120100"
    flavors="_forever_"
    [ $RETAIL -eq 1 ] && flavors="_forever_ _retail_"
    for flavor in $flavors; do
        [ -d "$WOW/$flavor/Interface/AddOns" ] || continue
        echo "== $flavor"
        toc=""
        [ "$flavor" = "_retail_" ] && toc="$RETAIL_INTERFACE"
        WLRT_GAME="$WOW/$flavor/Interface/AddOns" WLRT_STATE="wlrt-synced${flavor}" WLRT_TOC_INTERFACE="$toc" bash "$0" "$@" || rc=1
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
TOC_INTERFACE="${WLRT_TOC_INTERFACE:-}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
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
    src="$f"
    if [ -n "$TOC_INTERFACE" ] && [[ "$f" =~ ^[^/]+/[^/]+.toc$ ]]; then # the retail test copy: the addons' interface line
        src="$TMP/$(echo "$f" | tr "/" "_")"
        sed "s/^## Interface:.*/## Interface: $TOC_INTERFACE/" "$f" > "$src"
    fi
    [ -f "$dst" ] && cmp -s "$src" "$dst" && continue
    if [ -f "$dst" ] && [ $FORCE -eq 0 ]; then
        blob="$(git hash-object --path="$f" "$dst")"
        if ! git cat-file -e "$blob" 2>/dev/null && [ "$blob" != "${synced[$f]:-}" ]; then
            echo "SKIP (changed only in the game folder): $f"
            skipped=$((skipped + 1))
            continue
        fi
    fi
    mkdir -p "$(dirname "$dst")"
    if cp "$src" "$dst"; then
        echo "copied: $f"
        copied=$((copied + 1))
        synced["$f"]="$(git hash-object --path="$f" "$dst")"
    fi
done < <(git ls-files -z -s -- "${ADDONS[@]}")

for f in "${!synced[@]}"; do printf '%s	%s
' "${synced[$f]}" "$f"; done > "$STATE"
echo "$copied copied, $skipped skipped, $untracked not tracked."
[ $skipped -eq 0 ]
