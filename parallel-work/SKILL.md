---
name: parallel-work
description: Shared checkouts, background waves and attended worktrees. Use when a checkout turns out to have a second writer, on an explicit parallel-work signal (2+ tasks at once, a dependency-free fan-out of background subagents), and before any git worktree setup.
---

## Parallel work — shared checkouts, waves & attended worktrees

**Decision rule.** One task → the standing single-task process; with your checkout held by
another session → wait, or on the user's say-so, one attended worktree. You driving 2+ tasks →
attended worktrees (Mode B). Dependency-free fan-out you are not driving → waves (Mode A). A busy
checkout is never itself a signal; a worktree you did not create is someone else's session; a
throwaway tree that only runs a gate (`verify-gate`) needs no signal. *Attended* = a human driving
or watching, whoever writes the diff — not `implement-run`'s `solo`, which turns delegation off.

**Knobs** (`<!-- knobs:parallel-work -->` in the project contract your host adapter names, read
from the file on disk — an injected copy has lost its marker lines; a contract that cannot be read
is a stop that names the path):
`worktree_path_prefix`, a path template whose last segment is the branch name (`<path>` below,
filled in), and `install`, the command that makes a fresh tree buildable. Never bake in a literal.

**One clone per interactive session.** Two sessions on one checkout is the failure both modes
exist to avoid. The tell: `git status` shows changes you did not make, HEAD is on a branch you did
not check out, or `git checkout main` refuses or would carry changes along.

- **A peer's uncommitted work is not yours to move.** On a tree that is not yours, `stash`,
  `reset --hard`, `clean`, `checkout -- <file>`, `restore`, `rebase` and any branch switch each
  remove, overwrite or hide in-flight work, silently — a switch carries dirty changes onto the
  branch you land on and leaves the source branch nothing to merge. Park your work and ask the
  peer to commit.
- **Stage by explicit path, board files included, and re-verify the branch before every commit**
  (`git-commit-format`). **Landed on the integration branch, your commit only?** Fast-forward
  only — `git merge-base --is-ancestor main <sha> && git branch -f main <sha>` — never
  `git checkout main` while another session holds the checkout.

**Git writes in a worktree fail under the sandbox**, subagents' included. Claude Code denies
`.git/worktrees/<name>/`, so `add`, `commit` and `fetch` there fail on `index.lock` or
`FETCH_HEAD` — run them with the sandbox bypassed (`sandbox-and-permissions`). Codex denies all of
`.git/` under `workspace-write` (`codex-sandbox-and-approvals`).

**Mode A — Waves.** For tasks with no shared state and no ordering between them:

- **The coordinator alone** syncs `main` and claims each task, in the tracker chunk's form of claim.
- Per task, from the repo root: `git worktree add <path> -b <branch> main`, then run `install` in
  it. A Claude Code subagent inherits the parent's permission mode and sandbox, so nothing is
  copied; the Agent tool's `isolation: "worktree"` also works but ignores both knobs. Codex role
  files: `codex-sandbox-and-approvals`.
- Spawn one background subagent per task, all in one message. Each prompt, verbatim: stay in your
  worktree; read the task and its design docs first; run the full verify gate (`verify-gate`) and
  paste its output; commit on the branch; end with a review handoff. **Hard limits, in every
  prompt:** no merge, push, Done, deploy, board write or `gh` write. The prompt carries the gates,
  not the host — under Codex `-a on-request` a child runs `git push` or `git stash` unasked
  (`git-confirm-destructive`).
- Steer a drifting subagent by message; a respawn loses its context.
- **The coordinator re-verifies every handoff**: the gate re-runs in that worktree, by the
  coordinator or a gate-runner seat, never by the seat that wrote the diff, and real output is
  diffed against source. A self-reported metric is a claim, not a measurement.

**Mode B — Attended worktrees.** `git worktree add <path> -b <branch> origin/main` — branching off
fresh `origin/main` is the sync, so don't re-pull inside. Which tracker writes the session may make
is the tracker chunk's.

- **A fresh interactive worktree inherits no gitignored host config.** Claude Code:
  `cp .claude/settings.local.json <path>/.claude/` before launch, or the session silently runs
  without the sandbox and auto mode. Codex: supply `.codex/config.toml`, or the session has no
  project MCP servers.

**A worktree isolates files, not tool state.** A tool that scans "the repo", resolves its root once,
or keys on anything but your working directory sees — or writes — a sibling's world; verify what
each keys on.

**Visual or feel acceptance runs attended**, never as a wave: the diff may be delegated, the
acceptance may not.

**A coordinator's unattended slice on a `tracker-github` project is a batch**, which the owner
starts with `/implement-batch` — suggest it where that Skill's directory exists under
`~/.claude/skills` or `~/.agents/skills`, and skip this step otherwise. It is slash-only: the owner
invokes it, never the session.

**Merge and Done: `git-flow-squash`**, however the branch was produced.
