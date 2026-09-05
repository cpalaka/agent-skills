---
type: backlog
# dev-base is always imported by the engine; it already pulls verify-gate +
# dev-practice. Add only the explicit, un-bundleable imports here.
imports:
  - backlog-core
fork: git-flow-squash       # ADR-0002 default. Opt-in alternative is git-flow-noff
                            # (plain task-NNN branch + SHA-in-notes) — swap the fork
                            # line to migrate; never import both.
templates:                  # board conventions arrive via the backlog-core @import (the old
                            # claude-section.md Template was promoted INTO that chunk). Two stamped
                            # assets, both host-neutral and both reached through the contract:
                            # the canonical tracker pointer for skills that look up
                            # docs/agents/issue-tracker.md (code-review, triage, to-tickets), and
                            # the board's label vocabulary.
  - { src: issue-tracker.md, dest: docs/agents/issue-tracker.md }
  - { src: triage-labels.md, dest: docs/agents/triage-labels.md }

adapters:                   # the contract's Board section is what gives the two pointers above a
                            # reader; without it they are stamped and never named. No host-mechanics
                            # fragments — driving the CLI is the same on both hosts.
  contract: contract.md     # → <!-- profile:contract-sections --> in docs/agents/project-workflow.md
knobs:
  # Per-project values written into <!-- knobs:backlog-core --> in the project's shared contract,
  # docs/agents/project-workflow.md — never into an adapter, and never into the chunk.
  backlog-core:
    VERSION: "1.45.2"                       # THE canonical pin — any other Profile that mirrors it bumps with it; npm i -g backlog.md@<pin>
    PLANS_DIR: "docs/plans/"                # where multi-task plan docs linked via --doc live
    VERIFY_EXAMPLES: "typecheck/test/build green · dev smoke · screenshot"  # illustrate AC shape
    DoD:                                    # standing gates, stamped at task-creation time;
      - "<project test gate — e.g. lint+typecheck+tests green>"   # MUST always end in sign-off.
      - "<project review gate — e.g. PR/diff reviewed ready>"
      - "<filing gate — new gotchas/ADRs filed (or N/A)>"
      - "Debug/scaffolding instrumentation reverted"
      - "User sign-off received"
  # verify-gate + dev-practice are imported via dev-base; we only supply their knob values.
  verify-gate:              # one key per step of the chunk's invariant sequence, same eight keys
                            # in every Profile — vary the commands, never the key set.
    dir: "<the directory the gate runs in>"
    typecheck: "<the type/compile step>"
    test: "<the test suite>"
    build: "<a real production build>"
    build_check: "<the build's own artifact assertion — exit 0 alone is not the check>"
    smoke: "<bring it up, confirm the affected surface, bring it down>"
    secret_scan: "<grep pattern; expect zero matches>"
    env: "<any required env>"
  dev-practice:
    test_roster: "<pointer to the authoritative required-coverage list, e.g. a PRD section>"
    spec_verify_src: "<source tree dir that spec [reuse] claims are grepped against>"
  parallel-work:
    # parallel-work rides dev-base and is value-variant: it names two knobs the
    # engine writes into <!-- knobs:parallel-work --> in the project's contract.
    worktree_path_prefix: "../<proj>-task-NNN-<slug>"   # where `git worktree add` puts each tree; the last path
                                                        # segment IS the task-branch name, so the worktree layout
                                                        # and the branch convention stay in step. Match the
                                                        # project's own convention here, not this shape.
    install: "<the fresh-worktree install command — or `none` where the project needs no install step>"
---

## Bespoke setup

Board-driven project: install + initialize Backlog.md and seed the board. (The board
*conventions* — CLI-only/no-MCP, AC-vs-DoD, sign-off gate, drafts/labels/milestones —
already arrive via the `backlog-core` @import; this recipe only does the parts the
manifest can't express: the CLI `init`, the one hand-edit, and the seeding pass. Run from
the repo root.)

1. **Install check + pinned install.** `backlog --version`. If missing or mismatched,
   `npm i -g backlog.md@<VERSION>` (the `backlog-core` VERSION knob; 1.45.2 default). A
   hand-invoked CLI, not an unattended server, so a global pin — not a per-repo freeze —
   avoids resolve-latest-at-launch exposure. No lockfile-freeze step here.

2. **Init (flags beat the wizard).**
   ```
   backlog init <project-name> --agent-instructions none --integration-mode cli \
     --install-claude-agent false --zero-padded-ids 3 --defaults
   ```
   `--agent-instructions none` is load-bearing: a plain `backlog init` injects a
   ~742-line / ~7.7k-token block into CLAUDE.md (upstream #459) — a permanent per-turn
   context tax; the board conventions already live in the `backlog-core` chunk.
   Then verify `backlog/config.yml`: `auto_commit: false`,
   `statuses: [To Do, In Progress, Done]` (keep defaults — the four gates are DoD items,
   not columns), `zero_padded_ids: 3`.

3. **DoD defaults — hand-edit `backlog/config.yml`.** The key is `definition_of_done`,
   snake_case in the file, and `backlog config set` does NOT expose it — so hand-edit the yaml
   (config is fine to hand-edit; task files are NOT — the CLI owns IDs/naming/frontmatter). Write
   the `DoD` knob list — **the calling Profile's, where another Profile is running these steps**
   (the godot Profile's board step brings its own, Godot-flavoured list); this Profile's own entries
   are placeholder shapes and are the list only when backlog is the project type. Adapt items 1–N to
   the project's standing gates and **always end with the explicit user sign-off** item (the
   human-in-the-loop Done-gate; also surfaced per-task by `backlog-core`). Read it back with
   `backlog config get definitionOfDone` — the CLI takes the camelCase spelling for the same key
   (verified 2026-09-03 on 1.45.2).

4. **Seed the board** — MAIN session only, sequential. `task create`'s ID generation is a
   max+1 scan, so concurrent creation from subagents/workflow agents collides (upstream
   #632). Per `backlog-core`, populating the board needs an explicit go-ahead in chat
   first — propose the list (titles + one-liners), wait for a yes.
   - Everything that predates backlog → label **`pre-backlog`**.
   - Every item Claude creates → label **`claude-generated`**, set in `-l` at create time
     (provenance = creation *mechanism*, not idea origin; the user's web-UI items stay
     unlabeled).
   - Sources: existing roadmap/TODO docs, doc-ledger task lists, agent-memory forward
     queues — **verify each item against git first** (docs and memory go stale; the queued
     work may already be done).
   - **Tasks** = concrete identified work — `-d` description with context + file/doc
     pointers, a task-specific `--ac` per check (the Done-gate). **Drafts** = ungrilled
     phase-heads via `backlog draft create` (no CLI edit verb — set labels at `-l` time).
   - **Milestones** = phases (`-m <phase>`, auto-created on first use); **labels** are
     free-form (`-l a,b`) and emerge organically. After seeding, retire the old queue
     homes (point roadmap docs/memories at the board; never maintain two queues).

5. **Adoption commit.** Commit the `backlog/` files by explicit path + the three emitted files
   (`CLAUDE.md`, `AGENTS.md` and `docs/agents/project-workflow.md`) plus the two stamped
   `docs/agents/` pointers as one adoption commit. `auto_commit: false` means task-file changes
   always ride along with code commits thereafter (one task-file change per code commit).

**Then resume the engine's verify-after-write + handoff** (the imports resolve, the knob
blocks are populated in the contract, the board exists) — including the byte gate over the
auto-loaded Codex pair, the first-launch external-includes approval (which is also what makes
headless runs expand the imports), and the Codex directory-trust prompt.
