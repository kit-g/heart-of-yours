#!/bin/bash
# Regression matrix for guard.sh. Run: agents/hooks/guard_test.sh
# Each case: expected decision, a tab, the command as the Bash tool would see it.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
fail=0
while IFS=$'\t' read -r want cmd; do
  [[ -z "$want" || "$want" == \#* ]] && continue
  out="$(jq -n --arg c "$cmd" '{tool_input:{command:$c}}' | "$HERE/guard.sh")"
  got=allow; [[ -n "$out" ]] && got=deny
  mark=ok; [[ "$got" != "$want" ]] && { mark=FAIL; fail=1; }
  printf '%-4s %-5s %s\n' "$mark" "$got" "$cmd"
done <<'EOF'
# never-commit rule
deny	git commit -m x
deny	git push origin main
deny	git -C /Users/kitg/apps/heart push origin main
deny	cd x && git commit -m y
deny	echo hi; git push
deny	out=$(git merge main)
# work-destroying git
deny	git merge main
deny	git merge
deny	git -C /x merge --no-ff feature
deny	git rebase main
deny	git rebase -i HEAD~3
deny	git reset --hard HEAD
deny	git checkout .
deny	git restore .
deny	git stash drop
deny	git branch -D feature
deny	git clean -fd
# read-only git that used to trip the subcommand match
allow	git log --oneline -15 --merges
allow	git log --no-merges main..HEAD
allow	git merge-base main HEAD
allow	git -C .claude/worktrees/ui log --oneline main..HEAD
allow	git status --short
allow	git worktree list
allow	git add -N .
# git mentioned in prose, not in command position
allow	echo git subcommand merge text in a script
allow	cat file.md | grep 'git commit'
allow	grep -n 'git push' agents/README.md
# rm
deny	rm -rf lib
allow	rm -rf build/agent-screens
allow	rm -rf .dart_tool
EOF
[[ $fail -eq 0 ]] && echo "all cases pass"
exit $fail
