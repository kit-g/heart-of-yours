# Sourced by agents/agent and agents/host-agent: puts an agent's worktree on a
# chosen base branch before Claude Code is handed the name.
#
# `claude --worktree <name>` reuses .claude/worktrees/<name> when it exists and
# otherwise branches from whatever the checkout happens to have out — a review
# branch as often as main. Making the worktree here makes the base a deliberate
# choice: main by default, or another agent's branch to stack on (GitHub's
# stacked pull requests; `--base worktree-a2` puts #92's work on top of #91's).
# The branch remembers its base for gh, so a later `gh pr create` from it
# targets the parent without being told.
#
# Usage: ensure_worktree <repo> <name> <base> <base_was_given:0|1>
# Sets WORKTREE_BASE to the base actually in effect.
ensure_worktree() {
  local repo="$1" name="$2" base="$3" given="$4"
  local wt="$repo/.claude/worktrees/$name" branch="worktree-$name"

  if [[ -z "$base" ]]; then
    base="$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
    base="${base:-main}"
  fi

  if [[ -d "$wt" ]]; then
    local current
    current="$(git -C "$wt" branch --show-current)"
    WORKTREE_BASE="$(git -C "$repo" config "branch.$current.gh-merge-base" || echo "$base")"
    if [[ "$given" == 1 && "$WORKTREE_BASE" != "$base" ]]; then
      echo "worktree $name exists on '$current' (base $WORKTREE_BASE); --base $base ignored — remove the worktree to rebase it" >&2
    fi
    return
  fi

  git -C "$repo" rev-parse --verify --quiet "$base^{commit}" >/dev/null \
    || { echo "--base '$base' is not a branch or commit in $repo" >&2; exit 1; }
  mkdir -p "$repo/.claude/worktrees"
  git -C "$repo" worktree add -q "$wt" -b "$branch" "$base"
  git -C "$repo" config "branch.$branch.gh-merge-base" "$base"
  WORKTREE_BASE="$base"
  echo "worktree $name: branch $branch on $base" >&2
}
