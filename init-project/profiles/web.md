---
type: web
# Beyond dev-base (which is always imported and recursively pulls the base
# chunks: the three git-* files + verify-gate). A new web project lands on the
# GitHub tracker, so it imports tracker-github. The fork below is imported
# nowhere — it is a Skill the engine names in both adapters.
imports:
  - tracker-github         # the default tracker for a new web project — written only where
                           # engine step 0's tracker rule settles on it.
fork: git-flow-squash      # the default (ADR-0002) and, since ADR-0013, the only variant.
templates: []              # none of web's own. The tracker's two pointer Templates are stamped
                           # by the recipe's § B at engine step 5, by reference to the tracker's
                           # own Profile, so that step 0's tracker rule decides which pair lands.
knobs:
  # tracker-github is an explicit import and verify-gate rides dev-base; parallel-work and
  # implement-run are Skills that no project imports and that read their block by marker
  # (ADR 0014). Every one is value-variant, so the engine still writes a knob
  # block for each — tracker-github's only where engine step 0's tracker rule settles on it —
  # into the project's shared contract (docs/agents/project-workflow.md), never into an adapter,
  # and never into a chunk.
  #
  # A `<…>` value below is shape, not a default: answer it from the project at
  # apply time. It is deliberately NOT the Template `{{NAME}}` token — that one
  # is substituted into COPIED files, and the only ones this Profile copies are the tracker's
  # two pointer Templates, which § B stamps by reference at engine step 5.
  tracker-github:
    # profiles/github.md is canonical for this block's shape: exactly these two keys, in this
    # order, prompts mirrored from there. REPO is derived by that Profile's § A stage 2 (run at
    # engine step 0 by this Profile's § A) and confirmed with the owner before it is written in.
    REPO: "<owner/repo>"
    RESULTS_DIR: "<a path relative to the repository root where a gate:accept ticket's result note goes — or `none` for comments only>"
  verify-gate:
    # Web toolchain gate — exact commands the verify-gate chunk's invariant
    # sequence (typecheck → test → build → smoke → secret-scan) runs. The npm
    # scripts below are the common shape; swap in the project's package manager
    # and script names at apply time.
    dir: "<the directory the gate runs in: repo root for a single-package repo, the app's subdirectory where it is one>"
    typecheck: "npm run typecheck"
    test: "npm run test"
    build: "npm run build"
    build_check: "<the build's own artifact assertion — e.g. that the SSG/prerender step produced the static output. The build must SAY so; exit 0 alone is not the check>"
    # NOT a bare server command: a dev server never exits, and step 7 classifies a gate step that
    # hangs — no exit, banner only — as a STAMP FAILURE, so `smoke: <the dev command>` fails the
    # verify-after-write of every project stamped from this Profile. State the procedure instead.
    smoke: "bring the dev server up in the background (`npm run dev`, or the project's package manager and script name), request the affected route, and read the route's OWN rendered content — the server's ready banner is not the verdict, and a route that 500s or renders an error boundary still prints that banner. Then stop the server and confirm the port is free. PASS = the affected route's expected content observed AND no server process left behind; either half missing is a FAIL"
    secret_scan: "grep -rEn '<secret-leak pattern>' over the working tree from repo root — expect ZERO matches"
    env: "<where the deployed secrets live — an env file on the host, a secrets manager, the platform's own store; never in the repo and never in the client runtime>"
  parallel-work:
    # parallel-work is a Skill, not an import, and still value-variant: it names two knobs the
    # engine writes into <!-- knobs:parallel-work --> in the project's contract.
    worktree_path_prefix: "../<proj>-<n>-<slug>"        # where `git worktree add` puts each tree; the last path
                                                        # segment IS the task-branch name, so the worktree layout
                                                        # and the branch convention stay in step. The tracker's
                                                        # branch form is `<type>/<n>-<slug>` — match the project's
                                                        # own convention here, not this shape.
    install: "<the fresh-worktree install command, e.g. `npm install` in the app directory>"
  implement-run:
    # implement-run is a Skill too, read by marker, and unlike the values above none of these is a
    # `<…>` shape to answer: they are its OWN defaults, which apply wherever the block is absent, so a
    # project stamped before this entry existed runs on exactly them. They become that project's
    # saved pick — the coordinator states them at the start of a run and asks only where a ticket
    # cannot fit them.
    shape: "subagents"
    layout: "parallel-when-disjoint"
    gate_runner: "gate-runner"
    advisor: "advisor"
    light_set:
      - "docs/**"
      - "CONTEXT.md"
      - "README.md"
---
## Bespoke setup

One thing beyond the engine's uniform steps: **the tracker**, in the two sections that close this
recipe — § A at engine step 0, § B at engine step 5 — both by reference to the tracker's own
Profile (`profiles/github.md`, or `profiles/backlog.md` on a backlog pick) and both under step 0's
tracker rule. The engine's apply algorithm (the five emitted files — the contract,
`docs/agents/ADDING.md`, the two adapters and the gate seat — the settings.local.json merge,
verify-after-write, handoff) covers the rest of a web project; there are no installs, no `init`
CLI, no `project.godot`-style edits, no Templates of this Profile's own to stamp, and no host
specifics beyond the generic ones, so this Profile declares no `adapters:` fragments either.

**Three answers the project owes before anything is written**, because nothing here can
guess them and each one is wrong by default: **where the toolchain runs** (repo root or an
app subdirectory — it fills the `verify-gate` and `parallel-work` values),
**where the deployed secrets live** (the `verify-gate` `env` value), and **the task-branch
convention** (the `parallel-work` prefix). A fourth, **the deploy target**, is not a knob at
all — deploy is inline-leaf, so ask for it and hand it to whoever writes the contract's
project sections.

**Web-specific concerns live as INLINE-LEAF, hand-authored in the contract's project
sections (`docs/agents/project-workflow.md`) — not in either adapter, which carry host
mechanics only.** The engine never writes a project section it did not author, and no
manifest knob or shared chunk carries these:

- **Deploy** — the target, the commands that push to it, where the secrets live, the
  client-to-API boundary the frontend is held to, and anything under the deploy directory
  (reverse-proxy config, service units). All human-gated; project-specific. A deploy command
  belongs in this zone even when it is a one-liner: the knob blocks are rewritten on every
  re-run and would lose it.
- **The framework skill list** — which framework or UI skills to invoke proactively and
  their triggers (before touching a component, for reusable component APIs, for route
  animations, and so on). This list is inline-leaf, not a knob, because the set changes
  per project and per framework — no shared Chunk or Skill can carry it.
- **Exact toolchain / version pins** — the framework, router, build tool and language
  versions, several of which a meta-framework typically pins through its own peer deps, plus
  the pin table and the bump policy — in a doc of its own once it outgrows a paragraph.
- **Large files** — files above the repo's size threshold are never committed to git; they
  live in a gitignored assets directory and ship via the deploy asset-sync target.
  Project-specific, never a chunk.

<!-- precondition -->
### A. The GitHub remote check — by reference, at engine step 0

**Skipped whenever engine step 0's tracker rule settled the tracker from the contract** — a held
block of either tracker: nothing here runs, and nothing is offered.

Otherwise run **stage 1** of `profiles/github.md` → `## Bespoke setup` → **§ A** by reference — is
there a GitHub remote at all — and act on its answer here:

- **Stage 1 `yes`** → where `backlog/` already exists, name the board to the owner and ask whether
  to take backlog instead (meaning 1 below) before settling on `tracker-github`. On `tracker-github`,
  run the rest of § A by reference, still here: its **stage 2** (the `owner/repo` the `REPO` knob is
  confirmed from) and stage 2's stop on a failure there, which is not a stage-1 `no` and puts no
  offer.
- **Stage 1 `no`** → put § A's offer to the owner — but this section, not § A, says what the pick
  does: the stamp continues with the pick; it does not stop and re-run under another Profile.

The rest of this Profile still applies, so § A's two alternatives mean, read from a web stamp:

1. **backlog** — `backlog-core` is this stamp's tracker: its import, a
   `<!-- knobs:backlog-core -->` block from `profiles/backlog.md`'s `knobs` answered from the
   project, that Profile's two Templates and its contract fragment, and its board setup where
   `backlog/` is absent — all of it at step 1 and § B, not here.
2. **none** — no tracker wiring at all.

Either way this Profile's own `tracker-github` import and knob block are not written (step 0's
tracker rule). This section carries the `<!-- precondition -->` marker for the reason engine step 0
gives: the engine reads preconditions only off the stamped Profile's own file.

### B. The tracker setup — by reference, at engine step 5

The tracker's import line and knob block are **not** this section's: step 1 wrote them, for the
tracker step 0 settled. This section runs that tracker's setup only where step 0's tracker rule
lets it run — a held `backlog-core`, not this Profile's own tracker, runs nothing here. Profiles do
not compose; reference, don't copy. After (a), ask the owner each `*<Fill at init:` prompt a stamped
Template carries and write the answer in — step 7 fails on any that survive.

- **github** — (a) stamp `profiles/github.md`'s two `templates` entries,
  `profiles/github/templates/issue-tracker.md` and `triage-labels.md`, to `docs/agents/`,
  skip-if-exists as engine step 3 does (`issue-tracker.md` is the canonical tracker pointer for
  skills that look up that path: code-review, triage, to-tickets); (b) append its contract fragment
  (`profiles/github/templates/contract.md`, the `## Issue tracker` section) **as the contract's
  final section** — step 1 consumed the `<!-- profile:contract-sections -->` marker — **only where
  the contract has no `## Issue tracker` section yet**, so a re-run does not duplicate it and the
  two pointers have a reader; (c) run `profiles/github.md` → `## Bespoke setup` → **§ B**, the
  label mint, as written there, then the verify-after-write items its closing paragraph lists.
- **backlog** — the same three, by reference to `profiles/backlog.md`: (a) its two `templates`
  entries from `profiles/backlog/templates/` to `docs/agents/`, skip-if-exists; (b) its contract
  fragment's `## Board` section (`profiles/backlog/templates/contract.md`) **appended as the
  contract's final section**, only where the contract has no `## Board` section yet; (c) where
  `backlog/` is absent, its `## Bespoke setup` steps 1–4 — the install check, the `backlog init`,
  the `definition_of_done` hand-edit with the `DoD` list the knob block step 1 wrote, and the
  seeding pass, which still needs an explicit go-ahead per `backlog-core`; its step 5, the adoption
  commit, is the engine handoff's, not a second commit here.
- **none** — nothing; the project keeps its task-tracking guidance in the contract's project
  sections.
