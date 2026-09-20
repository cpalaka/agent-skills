---
name: parallel-work
description: Waves and attended worktrees — the two modes of doing more than one task at once, and the decision rule that picks between them. Use on an explicit parallel-work signal — a request to run 2+ tasks concurrently, a dependency-free fan-out of background subagents, any git worktree setup — and when a checkout turns out to have a second writer.
---

## Parallel work — waves & attended worktrees

Two modes of doing more than one task at once, both taken only on an explicit parallel-work
signal — a busy checkout is not one. Pick by the decision rule: **one task → the standing
single-task process; you driving 2+ tasks hands-on → attended worktrees; dependency-free fan-out
you are NOT hand-driving → background waves.** *Attended* here means a human is driving or
watching the session; it says nothing about who writes the diff. `implement-run`'s `solo` toggle
is a different word for a different thing — it turns delegation off — and the two were measured
colliding 2026-09-14.

**Knobs** (`<!-- knobs:parallel-work -->` in the project contract file named by your host adapter): the **worktree
path prefix** (where `git worktree add` puts each tree) and the **install command** (what
to run in a fresh worktree to make it buildable). This Skill names them; it never bakes a
literal path or command.

**One clone per interactive session.** Two sessions on one checkout is not a mode; it is the
failure both modes below exist to avoid. The tell: `git status` shows changes to files you did
not touch, HEAD is on a branch you did not check out this session, or `git checkout main` either
refuses or would carry the changes along (`git-sync-branch-start`). When you see it:

- **A peer's uncommitted work is not yours to move.** On a tree that is not yours, `git stash`,
  `reset --hard`, `clean`, `checkout -- <file>`, `restore`, `rebase` and switching branches
  (`checkout <branch>`, which carries or blocks on their changes) each remove, overwrite or hide
  in-flight work, with no output. Park what you were about to do and ask the peer to commit. Your
  own worktree or clone is the way forward only on an explicit parallel-work signal (next
  bullet); with no signal, wait.
- **Uncommitted, non-conflicting changes follow a branch switch.** They do not stay behind: a
  `checkout` on a dirty tree silently carries that work — yours or the peer's — onto the branch
  you land on, `main` most often. The damage compounds from there. The source branch is left with
  *no* commit to merge, a squash-merge of it is a no-op, and a later push can publish a different,
  already-committed change in place of the one you meant. That is why clearing your own leftovers
  before a switch (`git-sync-branch-start`) is a rule and not tidiness, and why a switch belongs
  in the list of operations above.
- **Stage by explicit path, and re-verify the branch immediately before every commit** —
  `git-commit-format` owns both rules. **Landed on the integration branch, your commit only?**
  Fast-forward only — `git merge-base --is-ancestor main <sha> && git branch -f main <sha>` —
  never `git checkout main` while another session holds the checkout.
- **Worktrees only on an explicit parallel-work signal.** Mode A or B is chosen, never assumed
  because a checkout is busy; a worktree you did not create is someone else's session, not a
  spare. A throwaway clone or worktree that only runs a gate (`verify-gate`) is not parallel
  work and needs no signal.
- **Board with two writers:** where the tracker keeps rows in the tree, each session
  commits only the task-file edits it made — its own row and any dependent rows it
  pinned — by explicit path. Whether it keeps rows at all is the tracker chunk's
  (`backlog-core` or `tracker-github`).

**Mode A — Waves (dependency-free fan-out via background subagents).** For multiple tasks
with no shared state and no ordering between them:

- **The coordinator alone** syncs `main` and claims each task before fanning out, in whatever
  form of claim the tracker chunk (`backlog-core` or `tracker-github`) sets.
- Per task, from the repo root, create the worktree under the **worktree path prefix** knob
  (`git worktree add <prefix>-<slug> -b <branch> main`) and run the **install command** in
  it. No settings copy needed here: a subagent **inherits the parent session's permission
  mode and sandbox** (the baseline's shape and recovery: the `sandbox-and-permissions` Skill).
- **Host differences.** The inheritance above is Claude Code's. On **Codex**, native subagents
  inherit the parent's sandbox, MCP servers and skills unless the role TOML overrides them:
  `mcp_servers = {}` parses but inherits every server; disabling one needs its full transport
  (`command`/`args` or `url`) plus `enabled = false`; every scalar key must precede the first
  `[mcp_servers.*]` table, or it is parsed into that table and the role is dropped. Roles load
  at session start only — restart the parent after editing one.
- Spawn one background subagent per task, all in a **single message** so they run
  concurrently. Each subagent's prompt must, verbatim: confine it to its own worktree; have
  it read the task and the relevant design docs first; run the full project verify gate (see
  `verify-gate`) and paste the output into its report; commit on the branch; end with a
  review handoff. **Hard limits, in every prompt:** no merge, no push, no marking Done, no
  deploys, no board writes, no `gh` writes. Restate them verbatim rather than trusting the
  host: under Codex `-a on-request` a child executes `git push` or `git stash` without asking,
  so the prompt, not the approval policy, carries the gates (`git-confirm-destructive`).
- Steer a drifting subagent with a message rather than respawning it (a respawn loses its
  context).
- **The coordinator owns re-verification of every handoff.** The verify gate is re-run in that
  worktree before anything is relayed to the user — by the coordinator itself or by a
  gate-runner seat, never by the seat that wrote the diff. Writer/subagent agents
  systematically **over-report their own output**: treat any self-reported metric ("26%
  smaller", "tests pass") as a claim, not a measurement, and diff the real output against
  source yourself.

**Mode B — Attended worktrees (you hands-on, 2+ tasks concurrently).** On a board-driven
project each interactive worktree session **writes board fields for the task it owns** — so
per-session status edits are fine; only `task create` stays main-repo-only (the max+1 ID scan
collides under concurrency, see `backlog-core`). Which tracker writes such a session may make
at all is the tracker chunk's (`backlog-core` or `tracker-github`).

- Set up with `git worktree add <prefix>-<slug> -b <branch> origin/main`. Branching off
  fresh `origin/main` already satisfies the standing sync-`main`-first step, so don't re-run
  the checkout-and-pull inside the worktree.
- **Footgun — a fresh interactive worktree does NOT inherit sandbox+auto, or any other
  gitignored host config.** Unlike a subagent (Mode A, which inherits the parent), it starts
  without the parent's defaults, because the files carrying them are gitignored and do not
  travel with the new worktree. Host differences:
  - **Claude Code:** `.claude/settings.local.json`. **Copy it into the worktree's `.claude/`
    first** (`cp .claude/settings.local.json <prefix>-<slug>/.claude/`) or the session silently
    runs without the defaults (its shape: the `sandbox-and-permissions` Skill).
  - **Codex:** `.codex/config.toml`, so the session has no project MCP servers until you supply
    that file in the worktree before launch.

**Filesystem isolation is NOT tool-state isolation.** A worktree separates *files*, not state a
tool resolves across git refs or outside the tree: a CLI that scans "the repo", resolves a root
once at startup, or keys on something other than your working directory will see — or write — a
sibling's world from inside your isolated checkout. Ask what each tool in it actually keys on and
verify; `backlog`'s max+1 ID scan (see `backlog-core`) is one instance of a general class.

**Visual / feel-AC work runs attended, never as a background wave.** Acceptance criteria that are
visual or "feels right" (screenshots, motion, layout judgment) need a human watching mid-flight.
The diff may still be delegated; what must stay in the attended session is the acceptance.

**Authoring a ticket for hands-off execution is a different job from running one** — converting
its gates rather than skipping them, and batching what a machine cannot self-certify into one
deliberately human ticket. That procedure is `multi-agent-policy`'s `GRANTS.md`, where that skill
is installed (its directory exists under `~/.claude/skills` or `~/.agents/skills`) — read it
before granting a coordinator an unattended slice; where it is not, skip that read.

**Delegate the merge and Done step to `git-flow-squash` — never inline it here.** Merge style,
branch naming and the notes-SHA policy are that Skill's, however the branch was produced.
