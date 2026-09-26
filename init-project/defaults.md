---
fork: git-flow-squash       # the ADR-0002 default and, since ADR-0013, the only variant. Exactly one,
                            # and it is imported nowhere; where each adapter names it: SKILL.md step 1.
knobs:
  # Per-project values written into the tagged blocks in the project's shared contract,
  # docs/agents/project-workflow.md — never into an adapter, and never into a Chunk.
  # A `<…>` value below is a shape, not a default: the project answers it in the answers file,
  # and until it does `stamp` stops naming <id>.<key>. A quoted literal is written as is unless
  # the answers file gives the key. This file is the one home of each key's gloss.
  tracker-github:
    # Written only where the tracker outcome is github, and first. Exactly these two keys, in this
    # order: the Chunk's § Knobs fixes both the names and that there are two of them. PROJECT,
    # COLUMNS, AGENT_LABEL and RECORDS_DIR are retired — a contract still carrying one is on the old
    # five-knob shape, and the Chunk says where those four go instead (the project's own policy
    # file, never back into the Chunk).
    REPO: "<owner/repo>"    # derived, never asked blind: SKILL.md step 0, stage 2, then confirmed
                            # with the owner.
    RESULTS_DIR: "<a path relative to the repository root where a gate:accept ticket's result note goes — or `none` for comments only>"
  verify-gate:
    # One key per step of the Chunk's invariant sequence (typecheck → test → build → smoke →
    # secret-scan), plus dir, build_check and env read beside them — the same eight keys in every
    # project: vary the commands, never the key set. Where a key has no value to give (a step with
    # no command, `env` with none required), the answer is `none — <why>`, which the gate-runner
    # reads as declared absent.
    dir: "<the directory the gate runs in>"
    typecheck: "<the type/compile step>"
    test: "<the test suite>"
    build: "<a real production build>"
    build_check: "<the build's own artifact assertion — exit 0 alone is not the check>"
    smoke: "<bring it up, confirm the affected surface, bring it down>"
    secret_scan: "<grep pattern; expect zero matches>"
    env: "<any required env>"
  parallel-work:
    # parallel-work is a Skill, not an import, and still value-variant: it reads these two knobs by
    # marker out of <!-- knobs:parallel-work --> in the project's contract (ADR 0014).
    worktree_path_prefix: "<the whole path template `git worktree add` puts each tree at, not a bare prefix, with <n> and <slug> left as placeholders, e.g. ../<proj>-<n>-<slug> — the directory's last segment carries the task's <n>-<slug>, not the branch name <type>/<n>-<slug>>"
    install: "<the fresh-worktree install command — or `none` where the project needs no install step>"
  implement-run:
    # implement-run is a Skill too, read by marker, and none of these is a shape: they are its OWN
    # defaults, which apply wherever the block is absent, so a project stamped before this block
    # existed runs on exactly them. Written out because they are then the project's saved pick: the
    # coordinator states them at the start of a run and asks only where a ticket cannot fit them.
    shape: "subagents"
    layout: "parallel-when-disjoint"
    gate_runner: "gate-runner"
    advisor: "advisor"      # the advisor seat is a user-scope definition (~/.claude/agents/advisor.md),
                            # never stamped into the project; on a machine without it, answer `none`.
    light_set:
      - "docs/**"
      - "CONTEXT.md"
      - "README.md"
---

# The engine's defaults

The knob blocks and the fork every stamp starts from, read by `scripts/engine.sh` in the Profile
frontmatter syntax. A Profile overrides by key: its value replaces the default's, a key or block
only it names is appended after the defaults', and a key it does not name keeps the value here.
The `tracker-github` block is written only when the tracker outcome is `github`.
