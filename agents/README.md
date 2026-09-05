# Autonomous agents

Two to three Claude Code agents working the backlog in parallel on this
machine: **two containerized** (broad permissions, hard isolation, no
simulator) and **one host-side** (scoped permissions, full iOS toolchain).
Work arrives from GitHub issues or a manual prompt; work leaves as an
**uncommitted diff in a per-agent worktree** — you review and commit, always.

## Quick start

```sh
# once: credentials directory (outside any repo — checkouts get mounted
# into containers wholesale, so secrets can never live in one).
# default.env is shared by all agents; a <name>.env beside it overrides.
mkdir -p ~/.config/heart-agents
cp agents/env.example ~/.config/heart-agents/default.env   # then fill it in
claude setup-token    # → CLAUDE_CODE_OAUTH_TOKEN for the env file

# once: a simulator of the host agent's own, so it never touches yours
xcrun simctl create agent-iphone "iPhone 17"

# then, one terminal tab each:
agents/agent a1 --issue 142                       # containerized, headless
agents/agent a2 --repo ~/mine/heart-api --task "…" --aws
agents/host-agent ui --issue 137                  # host, simulators available
```

No `--task`/`--issue` drops you into an interactive session in the same
isolation (useful for steering); `--shell` gives bash in the container.

## How the pieces fit

**Isolation.** Each agent runs `claude --worktree <name>`, so edits land in
`.claude/worktrees/<name>` and Claude Code itself blocks writes to the main
checkout. Containers add the hard shell: non-root, default-deny egress
firewall (`init-firewall.sh`), resource caps, and only the target repo
mounted. The repo is mounted at its **identical host path** because worktree
metadata records absolute paths.

**Permissions.** Containerized agents run `--permission-mode
bypassPermissions` — sanctioned for exactly this shape: non-root, firewalled,
scoped credentials. The host agent runs `acceptEdits` and leans on the
allowlist in `.claude/settings.local.json`; unlisted commands still prompt.

**Guardrails.** `.claude/settings.json` wires `hooks/guard.sh` as a
PreToolUse hook for every session in this repo — hooks still fire under
bypassPermissions. It denies `git commit`/`push` (never-commit rule),
work-destroying git (`reset --hard`, `clean -f`, `rebase`, `merge`,
`checkout .`, `stash drop`…), and recursive force-deletes outside
`build//.dart_tool//tmp`. It's a guardrail, not a jail — real containment is
the container plus read-only credentials.

**Verification.** CI's whole unit-test/lint matrix is `ubuntu-latest`, so
containers run `make test` and `make lint` natively. What they *can't* do is
the CLAUDE.md screenshot rule — container agents are told to end UI work
with "needs a visual pass," and those tasks belong to the host agent, which
must screenshot-verify on its own `agent-iphone` simulator.

**Review.** Agents finish by writing `HANDOFF.md` at the worktree root
(gitignored) — what changed, verification evidence, the `docs/handoff.md`
checklist with each item done/n-a/flagged, and anything needing a visual
pass — and, for issue-dispatched work, the same summary as an issue comment.
Before writing it they run the `review-handoff` skill on their own
tree and leave `REVIEW.md` beside it. Review with the same skill — "review
the a1 worktree" — which re-runs lint and tests, checks the diff against the
ticket and the repo contract, and rewrites `REVIEW.md` with a verdict and
to-dos; then commit yourself. Picking up a container-produced worktree on the host?
Run `flutter pub get` in it first — its `.dart_tool` points at the
container's SDK.

## Credentials (default.env, shared; per-agent override optional)

| What                      | Scope                                                                                        | Why this scope                                                                                                                                                                                                                                                                      |
|---------------------------|----------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `CLAUDE_CODE_OAUTH_TOKEN` | from `claude setup-token`                                                                    | headless auth in containers                                                                                                                                                                                                                                                         |
| `GH_TOKEN`                | fine-grained PAT: heart + heart-api; Contents **Read**, Issues **Read/write**, Metadata Read | agents read issues and comment; read-only Contents means the token cannot push even if asked to                                                                                                                                                                                     |
| `SENTRY_AUTH_TOKEN`       | project:read, event:read, issue:read                                                         | triage crashes; no mutation                                                                                                                                                                                                                                                         |
| `AGENT_AWS_ROLE_ARN`      | `heart-agent` role, dev account only, `ReadOnlyAccess` to start (heart-api#49)               | no static secret at all — with `--aws` the launcher assumes the role via your `heart-dev` profile and injects session creds that expire on their own (default 4h; agent needs a restart past that); `--aws` also opens the firewall to AWS ranges in ca-central-1; prod stays yours |

The issue text for `--issue` is fetched on the **host** with your own `gh`
auth before the container starts, so agent PATs stay minimal.

## The list of things one forgets

- **Flutter/Dart pin**: the image installs the tag in `.flutter-version`
  (build-arg). After you upgrade to 3.47 / Dart 3.13, rerun with `--build`.
- **Anthropic auth persistence**: each agent's `~/.claude` is a named docker
  volume (`heart-agent-<name>-claude`), so login/session state survives
  `--rm`. Pub cache is a shared volume — first `pub get` is slow, later ones
  aren't.
- **heart-api's database tests**: `make db-up` won't work inside a container
  (no docker-in-docker — deliberately; the docker socket is root on the
  host). Run `make db-up` yourself in heart-api, then launch the agent with
  `--db` so the firewall lets it reach `host.docker.internal:5432`. Otherwise
  agents run `test-dart`/`test-python` and flag db tests for you.
- **No Dart MCP/LSP in containers**: CLAUDE.md's LSP-first navigation doesn't
  apply there; agents fall back to grep. The host agent has the full setup.
- **Firewall staleness**: allowed IPs are resolved at container start; big
  CDNs rotate. If egress starts failing mid-run, restart the container.
- **Following along**: containers stream via `agents/watch <name>`; the
  host agent narrates to its own terminal (same rendering — both go through
  `agents/narrate.jq`), with the raw event stream kept in
  `$TMPDIR/heart-agent-<name>.jsonl` for post-mortems.
- **Simulator ownership**: the host agent uses `agent-iphone` only. Your
  iPad simulator is yours; its prompt says so explicitly.
- **Docker Desktop resources**: 2 agents × (3 CPUs, 8 GB) — check Docker
  Desktop's VM allowance covers that plus headroom.
- **Escape hatch**: `AGENT_SKIP_FIREWALL=1` (env file) disables the egress
  lockdown for debugging. Don't leave it on.

## What stays out of reach, on purpose

Pushing anywhere, committing, prod AWS, TestFlight/App Store (deploys stay
CI-driven), your simulators, other repos (only the target repo is mounted),
and any env file (they live outside the repos and `.claude/settings.json`
denies reading `~/.config/heart-agents/`).
