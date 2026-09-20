---
type: github
# dev-base is always imported by the engine; it already pulls the three git-* chunks and
# verify-gate. parallel-work and implement-run are Skills, imported by nothing, that read their
# knob block by marker out of the contract (ADR 0014). Add only the explicit, un-bundleable
# imports here.
imports:
  - tracker-github          # UNCONDITIONAL — this is the tracker-typed Profile, so there is nothing
                            # to decide at apply time. A project imports this OR backlog-core,
                            # never both; the chunk's own header states that fork.
fork: git-flow-squash       # the ADR-0002 default and, since ADR-0013, the only variant.
                            # Exactly one, and it is imported nowhere: the engine names it as a
                            # Skill in both adapters (`/git-flow-squash`, `$git-flow-squash`).
templates:                  # the tracker CONVENTIONS arrive via the tracker-github @import. These
                            # two stamped assets are host-neutral pointers, both reached through
                            # the contract: the canonical tracker pointer for skills that look up
                            # docs/agents/issue-tracker.md (code-review's Spec axis reads it by
                            # that path; triage, to-tickets and wayfinder expect it by
                            # description), and the map from the upstream triage roles onto this
                            # tracker's labels.
  - { src: issue-tracker.md, dest: docs/agents/issue-tracker.md }
  - { src: triage-labels.md, dest: docs/agents/triage-labels.md }

adapters:                   # the contract's Issue tracker section is what gives the two pointers
                            # above a reader; without it they are stamped and named by nothing.
                            # No host-mechanics fragments — driving `gh` is the same on both hosts.
                            # No `codex` fragment in particular: the engine derives the Codex read
                            # list from `imports` ({{CHUNK_READ_LIST}}, step 1), so a fragment
                            # naming this chunk would be a second copy of that list, drifting from
                            # it silently. No `gate_runner` fragment either — the tracker names no
                            # project gate.
  contract: contract.md     # → <!-- profile:contract-sections --> in docs/agents/project-workflow.md
knobs:
  # Per-project values written into the tagged blocks in the project's shared contract,
  # docs/agents/project-workflow.md — never into an adapter, and never into a chunk.
  # A `<…>` value below is shape, not a default: answer it from the project at apply time.
  tracker-github:
    # Exactly these two keys, in this order: the chunk's § Knobs fixes both the names and that
    # there are two of them. PROJECT, COLUMNS, AGENT_LABEL and RECORDS_DIR are retired — a
    # contract still carrying one is on the old five-knob shape, and the chunk says where those
    # four go instead (the project's own policy file, never back into the chunk).
    REPO: "<owner/repo>"    # DERIVE it, do not ask blind:
                            #   gh repo view --json nameWithOwner -q .nameWithOwner
                            # from the repo root. That resolves both the SSH and the HTTPS remote
                            # forms, which hand-parsing `git remote -v` does not. Confirm the
                            # derived value with the owner before writing it in.
    RESULTS_DIR: "<a path relative to the repository root where a gate:accept ticket's result note goes — or `none` for comments only>"
  verify-gate:              # one key per step of the chunk's invariant sequence, same eight keys
                            # in every Profile — vary the commands, never the key set. A
                            # GitHub-tracked project implies no toolchain, so every value here is
                            # a shape the project answers at apply time.
    dir: "<the directory the gate runs in>"
    typecheck: "<the type/compile step>"
    test: "<the test suite>"
    build: "<a real production build>"
    build_check: "<the build's own artifact assertion — exit 0 alone is not the check>"
    smoke: "<bring it up, confirm the affected surface, bring it down>"
    secret_scan: "<grep pattern; expect zero matches>"
    env: "<any required env>"
  parallel-work:
    # parallel-work is a Skill, not an import, and still value-variant: it names two knobs the
    # engine writes into <!-- knobs:parallel-work --> in the project's contract.
    worktree_path_prefix: "../<proj>-<n>-<slug>"        # where `git worktree add` puts each tree; the last path
                                                        # segment IS the task-branch name, so the worktree layout
                                                        # and the branch convention stay in step. The tracker's
                                                        # branch form is `<type>/<n>-<slug>` — match the project's
                                                        # own convention here, not this shape.
    install: "<the fresh-worktree install command — or `none` where the project needs no install step>"
  implement-run:
    # implement-run is a Skill too, read by marker. These four are its OWN defaults — the values that
    # apply wherever the block is absent, so a project stamped before this entry existed runs on
    # exactly them. Written out here because they are then the project's saved pick: the
    # coordinator states them at the start of a run and asks only where a ticket cannot fit them.
    shape: "subagents"
    layout: "parallel-when-disjoint"
    gate_runner: "gate-runner"
    advisor: "advisor"
---

## Bespoke setup

Two parts, and **they do not run at the same point in the engine's algorithm.** Part A carries the
engine's `<!-- precondition -->` marker, so **it runs at step 0, before step 1 writes anything**;
Part B has no marker, so it is an ordinary recipe step and runs where step 5 calls this section. The
marker is what decides that, not either heading's wording — so read A's position off the marker, not
off its being first in this file.

<!-- precondition -->
### A. The GitHub remote check — runs at engine step 0, BEFORE step 1

**Why here and not at step 5.** By the time step 5 calls this recipe, step 1 has already written
`CLAUDE.md` with the `@~/.claude/chunks/tracker-github.md` import line, the contract's
`## Issue tracker` section and its `<!-- knobs:tracker-github -->` block, and step 3 has stamped
`docs/agents/triage-labels.md` — all of which name `gate:*` labels. **The engine has no undo
path:** its import merge is exact-line dedup and removes none, and no step deletes a stamped file.
Run this check at step 5 and a project with no GitHub remote is left naming labels it cannot hold,
recoverable only by hand.

The check is **two stages, and they answer different questions.** Do not collapse them: the first
needs no network and no credentials, and only the first can decide this Profile's fit.

**Stage 1 — is there a GitHub remote at all?** From the repo root:

```sh
git remote -v | grep -q 'github\.com' && echo yes || echo no
```

This is the question the Profile turns on, and `git` answers it offline from the repository's own
config. `no` — including a repository with no remotes at all — is the failure this step exists to
catch; take the offer below.

**Stage 2 — what is its `owner/repo`?** Only once stage 1 said `yes`:

```sh
gh repo view --json nameWithOwner -q .nameWithOwner
```

It resolves both the SSH and the HTTPS remote forms, which hand-parsing stage 1's output does not.
Keep the value: it is the answer to the `REPO` knob step 1 is about to ask for, to be confirmed with
the owner rather than written in silently.

**A stage-2 failure is not a stage-1 failure, and it does not take the offer below.** `gh` exits
non-zero when it is unauthenticated, offline or rate-limited — `HTTP 401: Bad credentials`,
exit 1, on a clone whose remote is perfectly good (measured on gh 2.101.0). Reading that as "no
GitHub remote" would move a project off this Profile over an expired token. If stage 1 said `yes`
and stage 2 fails, **stop and report what `gh` printed**: the remedy is `gh auth login` or a
network, after which init re-runs from the top at no cost. The tracker choice is not in question.

**On a stage-1 `no`, stop before anything is written** and put two named alternatives to the owner
(this is the only path that reaches the offer — a stage-2 failure does not):

1. **Run `profiles/backlog.md` instead** — the board-driven Profile. It tracks work in files under
   `backlog/` and needs no remote of any kind.
2. **Stamp no tracker at all** — run neither tracker Profile. The project gets the contract, the
   two adapters and the gate seat with no tracker import, no tracker knob block and no pointer
   files, and adopts one later.

Then stop and let the owner pick; do not choose for them and do not proceed with this Profile.
**A re-run costs nothing, because nothing was written** — once the remote exists, run init again
from the top and there is no half-stamped state to clean up first.

### B. Mint the thirteen labels — an ordinary recipe step at engine step 5

All thirteen must exist before the first ticket is filed or the first map charted, because a
missing label lists as zero issues at exit 0. Mint them **list-first, then create only what is
missing** — never create-and-ignore-the-error.

1. **List what the repository already has.**

   ```sh
   gh label list -L 200 --json name,description
   ```

   `-L 200` is load-bearing: the default is 30, so on a repository with more labels than that an
   existing label reads as missing and its create then fails.

2. **Compute the missing subset** of the thirteen in the table below, by name.

3. **Present the whole batch as one approval** — the names you would create, each with its colour
   and description, and, listed beside them, the names you are **skipping because they already
   exist**. One approval covers the batch; do not ask per label.

4. **On a yes, create only the missing ones.**

   ```sh
   gh label create <name> -c <color> -d "<description>"
   ```

**Never `--force` / `-f`.** That flag updates an existing label's colour and description, so it
would silently rewrite a description the project had customised, and it would make "the second run
errors on nothing" true by overwriting rather than by skipping. **Skipping is the mechanism**; `-f`
is not a shortcut to it.

**Which gate the one approval is.** It is **init's own interaction gate** over a batch of writes to
the owner's repository. It is **not** `git-confirm-destructive`'s: the tracker chunk's § Commit
forms, and clauses deferred here puts minting a label among the writes that need no approval under
*that* gate, and both statements are true because they are about different gates. Named here so a
reader holding both does not report a contradiction.

**Re-run behaviour.** The second run's list step finds all thirteen present, the missing subset is
empty, no `gh label create` runs, and the step errors on nothing.

**Verify after the mint, not by its exit code.** Run `gh label list -L 200 --json name,description`
again and confirm all thirteen names are present with the descriptions below — a loop whose one
failing create is not checked still exits green.

| Label | Colour | Description |
|---|---|---|
| `gate:agent` | `0E8A16` | A session starts and closes it alone |
| `gate:accept` | `1D76DB` | A session works it; the owner accepts before it closes |
| `gate:decide` | `B60205` | A decision or grill first; no session starts the work |
| `origin:spec` | `5319E7` | Child of a Spec: parent |
| `origin:found` | `D93F0B` | A defect met while doing other work |
| `origin:review` | `8A63D2` | Out of a code review |
| `origin:spec-review` | `A371F7` | Out of a spec review, off-chain |
| `origin:chore` | `C2E0C6` | Maintenance and housekeeping |
| `wayfinder:map` | `0052CC` | The map parent of a wayfinder chain |
| `wayfinder:grilling` | `6F42C1` | A wayfinder ticket resolved by grilling the owner |
| `wayfinder:prototype` | `0E7490` | A wayfinder ticket answering a question by building |
| `wayfinder:research` | `0366D6` | A wayfinder ticket answering a question from sources |
| `wayfinder:task` | `0969DA` | A wayfinder ticket that is ordinary work |

Three gate, five origin, five wayfinder.

**The Description column is the `-d` string the mint passes, not a definition.** `gh label create`
needs one, so these thirteen one-liners necessarily echo the chunk's § Two label axes — that is a
second copy, and it is the one duplication this Profile cannot design away. **The chunk is
authoritative**; a description here that has drifted from it is this table's bug, never the chunk's.
The coupling is checkable and worth checking when either side changes. **Run it from the skill's own
directory** (`init-project/`), not from the repository root as the rest of this recipe assumes —
from anywhere else both greps read missing files and `diff` prints nothing, which looks exactly like
agreement:

```sh
diff <(grep -oE '^\| `(gate|origin|wayfinder):[a-z-]+`' profiles/github.md | tr -d '|` ' | sort -u) \
     <(grep -oE '(gate|origin|wayfinder):[a-z-]+' ../chunks/tracker-github.md | sort -u)
```

Expect no output, and expect **13** lines on each side — a zero on either side means the extraction
broke, not that the sets agree. Read the counts before you believe the silence. Beyond the names, do not restate what a label *means* here, in a
stamped file, or in the approval you present.

**Then resume the engine's verify-after-write + handoff** — the imports resolve, the contract
carries the `<!-- knobs:tracker-github -->` block with `REPO` and `RESULTS_DIR` answered, both
pointer files are stamped, and the thirteen labels exist — including the byte gate over the
auto-loaded Codex pair, the first-launch external-includes approval (which is also what makes
headless runs expand the imports), and the Codex directory-trust prompt.
