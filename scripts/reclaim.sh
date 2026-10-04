#!/bin/bash
# Disk reclaim for this machine's mobile dev leftovers. Dry run by default:
# it lists what would go and how big it is. APPLY=1 (or --apply) removes it.
#
#   scripts/reclaim.sh            # or: make reclaim
#   scripts/reclaim.sh --apply    # or: make reclaim APPLY=1
#
# What it touches, all of it rebuildable or finished:
# - worktrees under .claude/worktrees (this repo and heart-api) whose branch
#   is merged, with a clean tree and no lock: an agent's live work is never
#   either of the last two;
# - agent simulators other than the canonical agent-iphone and agent-ipad
#   (agents/host-agent creates those two and nothing else), and duplicates of
#   those names;
# - simulators whose runtime is no longer installed;
# - Xcode DerivedData folders untouched for a week.
#
# It never touches the user's own simulators, iOS runtimes, Android
# emulators, Docker or package caches: each of those is a decision, not a
# leftover.
set -uo pipefail

apply=0
[[ "${1:-}" == "--apply" || "${APPLY:-0}" == 1 ]] && apply=1

HERE="$(cd "$(dirname "$0")/.." && pwd)"
REPOS=("$HERE" "$HOME/mine/heart-api")
CANONICAL_SIMS=(agent-iphone agent-ipad)

say() { printf '%8s  %s\n' "$1" "$2"; }
size() { du -sh "$1" 2>/dev/null | cut -f1; }
act() { if [[ $apply == 1 ]]; then "$@"; fi; }

free_before=$(df -k / | tail -1 | awk '{print $4}')
[[ $apply == 1 ]] && echo "reclaiming" || echo "dry run (APPLY=1 or --apply to remove)"

echo "== merged worktrees"
for repo in "${REPOS[@]}"; do
  [[ -d "$repo/.git" || -f "$repo/.git" ]] || continue
  git -C "$repo" fetch -q origin 2>/dev/null
  git -C "$repo" worktree list --porcelain | awk '
    /^worktree / { wt=$2; br=""; locked=0 }
    /^branch /   { br=$2; sub("refs/heads/", "", br) }
    /^locked/    { locked=1 }
    /^$/         { if (wt ~ /\.claude\/worktrees\//) print wt, br, locked }
    END          { if (wt ~ /\.claude\/worktrees\//) print wt, br, locked }
  ' | sort -u | while read -r wt br locked; do
    [[ "$locked" == 1 ]] && continue
    [[ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]] && continue
    merged=0
    if (cd "$repo" && gh pr list --head "$br" --state merged --json number -q 'length' 2>/dev/null | grep -qv '^0$'); then
      merged=1
    elif git -C "$repo" merge-base --is-ancestor "$br" origin/main 2>/dev/null; then
      merged=1
    fi
    [[ $merged == 1 ]] || continue
    say "$(size "$wt")" "$wt ($br)"
    act git -C "$repo" worktree remove "$wt"
  done
done

echo "== stray agent simulators"
seen=" "
xcrun simctl list devices -j 2>/dev/null | python3 -c '
import json, sys
for runtime, devices in json.load(sys.stdin)["devices"].items():
    for d in devices:
        print(d["udid"], d["name"])
' | while read -r udid name; do
  case "$name" in
    agent-*|agent\ *|heart-*|watch-agent*|qa-agent*) ;;
    *) continue ;;
  esac
  keep=0
  for c in "${CANONICAL_SIMS[@]}"; do
    if [[ "$name" == "$c" && "$seen" != *" $c "* ]]; then keep=1; seen="$seen$c "; fi
  done
  [[ $keep == 1 ]] && continue
  say "$(size "$HOME/Library/Developer/CoreSimulator/Devices/$udid")" "simulator $name ($udid)"
  act xcrun simctl delete "$udid"
done

echo "== simulators without a runtime"
xcrun simctl list devices unavailable 2>/dev/null | grep -E '\(([0-9A-F-]{36})\)' | sed -E 's/^ +/          /'
act xcrun simctl delete unavailable

echo "== DerivedData older than a week"
find "$HOME/Library/Developer/Xcode/DerivedData" -mindepth 1 -maxdepth 1 -type d -mtime +7 2>/dev/null |
  while read -r d; do
    say "$(size "$d")" "$d"
    act rm -rf "$d"
  done

free_after=$(df -k / | tail -1 | awk '{print $4}')
echo "== free: $((free_after / 1048576)) GB$([[ $apply == 1 ]] && echo " (freed $(((free_after - free_before) / 1048576)) GB)")"
