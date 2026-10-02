#!/bin/bash
# PreToolUse guard for the Bash tool. Runs in every Claude session in this
# repo — interactive, host agent, or container (hooks still fire under
# bypassPermissions). Enforces the agents' never-commit rule and blocks, for
# everyone, the git operations that can erase uncommitted work.
#
# Commits and pushes are an agent's limit, not an interactive session's: the
# user commits through the session they are sitting in. An agent is a session
# launched by agents/agent or agents/host-agent, which set HEART_AGENT=1 — or
# any session inside a container, should one start some other way.
#
# This is a guardrail, not a jail: a sufficiently creative command can evade
# string matching. Real containment is the container + read-only credentials.
set -uo pipefail

input="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$input")"
[[ -z "$cmd" ]] && exit 0

deny() {
  jq -n --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

agent() {
  [[ "${HEART_AGENT:-}" == 1 || -f /.dockerenv ]]
}

if agent && grep -Eq '(^|[|;&(`])\s*git[^|;&]*\b(commit|push)\b' <<<"$cmd"; then
  deny "Commits and pushes are reserved for the user. Leave work in the tree; run 'git add -N .' so new files show in git diff."
fi

if grep -Eq '(^|[|;&(`])\s*git[^|;&]*\b(reset[^|;&]*--hard|clean[^|;&]* -[a-zA-Z]*f| (rebase|merge)(\s|$)|branch[^|;&]* -D|checkout[^|;&]* \.|restore[^|;&]* \.|stash[^|;&]*\b(drop|clear))' <<<"$cmd"; then
  deny "Destructive git operation blocked — it can erase uncommitted work. Explain what you need and let the user run it."
fi

if grep -Eq '(^|[|;&]\s*)rm\s+(-[a-zA-Z]*\s+)*-[a-zA-Z]*r[a-zA-Z]*f' <<<"$cmd" \
   && ! grep -Eq 'rm\s+(-[a-zA-Z]+\s+)+(\./)?(build|\.dart_tool|/tmp|/private/tmp)' <<<"$cmd"; then
  deny "Recursive force-delete outside build/.dart_tool//tmp is blocked for agents."
fi

exit 0
