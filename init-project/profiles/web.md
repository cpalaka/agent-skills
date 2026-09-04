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
knobs:
  # backlog-core is an explicit import; verify-gate + dev-practice ride
  # dev-base. All three are value-variant, so the engine still writes a knob
  # block for each, into the project's shared contract (docs/agents/project-workflow.md) —
  # never into an adapter, and never into a chunk.
  #
  # A `<…>` value below is shape, not a default: answer it from the project at
  # apply time. It is deliberately NOT the Template `{{NAME}}` token — that one
  # is substituted into COPIED files by step 3, and this Profile stamps none.
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
    dir: "<the directory the gate runs in: repo root for a single-package repo, the app's subdirectory where it is one>"
    typecheck: "npm run typecheck"
    test: "npm run test"
    build: "npm run build"
    build_check: "<the build's own artifact assertion — e.g. that the SSG/prerender step produced the static output. The build must SAY so; exit 0 alone is not the check>"
    smoke: "npm run dev"                      # bring up, confirm the affected route renders, bring down
    secret_scan: "grep -rEn '<secret-leak pattern>' over the working tree from repo root — expect ZERO matches"
    env: "<where the deployed secrets live — an env file on the host, a secrets manager, the platform's own store; never in the repo and never in the client runtime>"
  dev-practice:
    test_roster: "<pointer to the authoritative required-coverage list, e.g. a PRD section>"
    spec_verify_src: "<source tree dir that spec [reuse] claims are grepped against, e.g. the app dir's src/>"
  parallel-work:
    # parallel-work rides dev-base and is value-variant: it names two knobs the
    # engine writes into <!-- knobs:parallel-work --> in the project's contract.
    worktree_path_prefix: "../<proj>-task-NNN-<slug>"   # where `git worktree add` puts each tree; the last path
                                                        # segment IS the task-branch name, so the worktree layout
                                                        # and the branch convention stay in step. Match the
                                                        # project's own convention here, not this shape.
    install: "<the fresh-worktree install command, e.g. `npm install` in the app directory>"
---
## Bespoke setup

None beyond the engine's uniform steps. The engine's apply algorithm
(the contract and the two adapters, the settings.local.json merge, verify-after-write,
handoff) fully covers a web project; there are no installs, no `init` CLI, no
`project.godot`-style edits, no Templates to stamp, and no host specifics beyond the
generic ones, so this Profile declares no `adapters:` fragments either.

**Three answers the project owes before anything is written**, because nothing here can
guess them and each one is wrong by default: **where the toolchain runs** (repo root or an
app subdirectory — it fills the `verify-gate`, `dev-practice` and `parallel-work` values),
**where the deployed secrets live** (the `verify-gate` `env` value), and **the task-branch
convention** (the `parallel-work` prefix). A fourth, **the deploy target**, is not a knob at
all — deploy is inline-leaf, so ask for it and hand it to whoever writes the contract's
project sections.

**If this project needs a board** and `backlog/` is absent, run the board
setup from **`profiles/backlog.md`'s `## Bespoke setup`** (the `backlog init`
+ `config.yml` DoD seeding recipe) — do **not** duplicate those steps here.
Profiles do not compose; reference, don't copy. (The board CONVENTIONS still
arrive via the `backlog-core` @import regardless; only the one-time CLI
`init` is bespoke, and it lives in the backlog profile.)

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
  animations, and so on). The `dev-practice` chunk explicitly leaves this list as
  inline-leaf, not a knob, because the set changes per project and per framework.
- **Exact toolchain / version pins** — the framework, router, build tool and language
  versions, several of which a meta-framework typically pins through its own peer deps, plus
  the pin table and the bump policy — in a doc of its own once it outgrows a paragraph.
- **Large files** — files above the repo's size threshold are never committed to git; they
  live in a gitignored assets directory and ship via the deploy asset-sync target.
  Project-specific, never a chunk.
