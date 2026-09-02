---
type: web
# Beyond dev-base (which is always imported and recursively pulls the base
# chunks incl. verify-gate + dev-practice). A web project is board-driven
# here, so it imports backlog-core; the fork below is imported explicitly too
# (a fork can never ride dev-base — @import cannot be undone).
imports:
  - backlog-core
fork: git-flow-squash      # the default (ADR-0002); git-flow-noff is the opt-in alternative.
templates: []              # none — backlog's claude-section.md is promoted into the
                           # backlog-core chunk, so no profile stamps it; web carries no Template assets.
#
# Two placeholder styles below, and they mean different things:
#   {{TOKEN}}  a value to ask the user for once and substitute before writing.
#   <shape>    illustrative prose the Profile author replaces by hand.
# The tokens this Profile uses are listed under "## Placeholders" after the manifest.
knobs:
  # backlog-core is an explicit import; verify-gate + dev-practice ride
  # dev-base. All three are value-variant, so the engine still writes a knob
  # block for each (knob values live in the project CLAUDE.md, never in a chunk).
  backlog-core:
    VERSION: "1.45.2"                         # mirrors profiles/backlog.md, which carries THE canonical
                                              # pin — bump both together; confirm at apply time
    PLANS_DIR: "docs/plans/"                  # specs in docs/specs/; plans/ created lazily
    VERIFY_EXAMPLES: "typecheck/test/build green, dev smoke of the affected route, screenshot where visual"
    DoD:                                      # EXAMPLES ONLY — at apply time, mirror the project's ACTUAL
                                              # backlog/config.yml definition_of_done verbatim (a live board
                                              # usually has more items). The list ALWAYS ends in a user sign-off item.
      - "Verify gate clean (typecheck/test/build/smoke + secret-scan)"
      - "Docs synced (PRD.md / CONTEXT.md / docs/adr/ for new language or decisions)"
      - "User sign-off received"
  verify-gate:
    # Web toolchain gate — exact commands the verify-gate chunk's invariant
    # sequence (typecheck → test → build → smoke → secret-scan) runs. The npm
    # scripts below are the common shape; swap in the project's package manager
    # and script names at apply time.
    dir: "{{APP_DIR}}"                        # the directory the gate runs in: the repo root for a
                                              # single-package repo, a subdirectory where the app is one
    typecheck: "npm run typecheck"
    test: "npm run test"
    build: "npm run build"
    build_check: "<the build's own artifact assertion — e.g. that the SSG/prerender step produced the static output. The build must SAY so; exit 0 alone is not the check>"
    smoke: "npm run dev"                      # bring up, confirm the affected route renders, bring down
    secret_scan: "grep -rEn '<secret-leak pattern>' over the working tree from repo root — expect ZERO matches"
    env: "{{SECRETS_LOCATION}}"               # where the deployed secrets live; never in the repo and never
                                              # in the client runtime
  dev-practice:
    test_roster: "<pointer to the authoritative required-coverage list, e.g. a PRD section>"
    spec_verify_src: "{{APP_DIR}}/src"        # the source tree specs' [reuse] claims are grep-verified against
  parallel-work:
    # parallel-work rides dev-base and is value-variant: it names two knobs the
    # engine writes into <!-- knobs:parallel-work --> in the project CLAUDE.md.
    worktree_path_prefix: "../{{TASK_BRANCH_CONVENTION}}"   # where `git worktree add` puts each tree; the last
                                                            # path segment is the task-branch name, so the
                                                            # worktree layout and the branch convention stay in step
    install: "the fresh-worktree install command — e.g. `npm install` in {{APP_DIR}}"
---
## Placeholders

Four tokens, each asked once and answered before anything is written:

| token | what it is | where it lands |
| --- | --- | --- |
| `{{APP_DIR}}` | the directory the toolchain runs in — repo root, or the subdirectory holding the app | `verify-gate`, `dev-practice`, `parallel-work` knob blocks |
| `{{SECRETS_LOCATION}}` | where the deployed secrets actually live (an env file on the host, a secrets manager, the platform's own store) | the `verify-gate` knob block |
| `{{TASK_BRANCH_CONVENTION}}` | the project's task-branch name shape, e.g. `<proj>-task-NNN-<slug>` | the `parallel-work` knob block |
| `{{DEPLOY_TARGET}}` | what the project deploys to — a host, a platform, a container registry | the project's Zone 3 inline-leaf, hand-authored (see below) |

The first three are knob values: the engine substitutes them as it writes Zone 2. `{{DEPLOY_TARGET}}`
is different — deploy is inline-leaf, so the token marks a value to *ask for and hand to the
author*, not one the engine writes anywhere.

## Bespoke setup

None beyond the engine's uniform steps. The engine's apply algorithm
(@imports + knob blocks, settings.local.json merge, verify-after-write, handoff)
fully covers a web project; there are no installs, no `init` CLI, no
`project.godot`-style edits, and no Templates to stamp.

**If this project needs a board** and `backlog/` is absent, run the board
setup from **`profiles/backlog.md`'s `## Bespoke setup`** (the `backlog init`
+ `config.yml` DoD seeding recipe) — do **not** duplicate those steps here.
Profiles do not compose; reference, don't copy. (The board CONVENTIONS still
arrive via the `backlog-core` @import regardless; only the one-time CLI
`init` is bespoke, and it lives in the backlog profile.)

**Web-specific concerns live as INLINE-LEAF (Zone 3), hand-authored in the
project's own `CLAUDE.md`.** The engine never writes Zone 3, and no manifest
knob or shared chunk carries them:

- **Deploy** — the target (`{{DEPLOY_TARGET}}`), the commands that push to it, where the
  secrets live (`{{SECRETS_LOCATION}}`), the client-to-API boundary the frontend is held to,
  and anything under the deploy directory (reverse-proxy config, service units). All
  human-gated; project-specific. A deploy command belongs in this zone even when it is a
  one-liner: the knob blocks are regenerated on every re-run and would lose it.
- **The framework skill list** — which framework or UI skills to invoke proactively and
  their triggers (before touching a component, for reusable component APIs, for route
  animations, and so on). The `dev-practice` chunk explicitly leaves this list as
  inline-leaf, not a knob, because the set changes per project and per framework.
- **Exact toolchain / version pins** — the framework, router, build tool and language
  versions, several of which a meta-framework typically pins through its own peer deps, plus
  the pin table and the bump policy — in a doc of its own once it outgrows a paragraph.
- **Large files** — files above the repo's size threshold are never committed to git; they
  live in a gitignored assets directory and ship via the deploy asset-sync target.
  Project-specific, never a chunk.
