---
# Beyond dev-base (which is always imported and recursively pulls the base chunks: the three git-*
# files + verify-gate), web imports nothing of its own. The tracker, the fork and every knob key not
# listed below are the engine's (init-project/defaults.md).
imports: []
templates: []              # none of web's own. The tracker's two pointer Templates are the engine's,
                           # stamped by `stamp` when the tracker outcome is github.
knobs:
  verify-gate:
    # Web's commands for the verify-gate keys (defaults.md glosses the key set).
    dir: "<the directory the gate runs in: repo root for a single-package repo, the app's subdirectory where it is one>"
    typecheck: "npm run typecheck"
    test: "npm run test"
    build: "npm run build"
    build_check: "<the build's own artifact assertion — e.g. that the SSG/prerender step produced the static output. The build must SAY so; exit 0 alone is not the check>"
    # NOT a bare server command: a dev server never exits, and engine step 5 classifies a gate step
    # that hangs — no exit, banner only — as a STAMP FAILURE, so `smoke: <the dev command>` fails the
    # gate run of every project stamped from this Profile. State the procedure instead.
    smoke: "bring the dev server up in the background (`npm run dev`, or the project's package manager and script name), request the affected route, and read the route's OWN rendered content — the server's ready banner is not the verdict, and a route that 500s or renders an error boundary still prints that banner. Then stop the server and confirm the port is free. PASS = the affected route's expected content observed AND no server process left behind; either half missing is a FAIL"
    secret_scan: "grep -rEn --exclude-dir=.git --exclude-dir=node_modules '<secret-leak pattern>' . from repo root — every file in the working tree, untracked and ignored ones included, except git's store and the installed modules; expect ZERO matches"
    env: "<where the deployed secrets live — an env file on the host, a secrets manager, the platform's own store; never in the repo and never in the client runtime>"
  parallel-work:
    install: "<the fresh-worktree install command: the lockfile install, e.g. `npm ci --prefix <app>` or `cd <app> && npm ci`>"
---
## Bespoke setup

None: the engine's steps cover a web project — no installs, no `init` CLI, no Templates or
`adapters:` fragments of this Profile's own. What only web knows is what the owner answers at
engine step 1, and the inline-leaf list below.

**Answered at the interview (engine step 1)**, because nothing here can guess them and each is wrong
by default:

- **Where the toolchain runs** — repo root or an app subdirectory: `verify-gate.dir`, and
  `parallel-work.install` written for that directory (`npm ci --prefix <app>` or
  `cd <app> && npm ci`), since `parallel-work` has no directory key.
- **Where the deployed secrets live**: `verify-gate.env`.
- **Where task worktrees go**: `parallel-work.worktree_path_prefix` (the branch form is the tracker
  Chunk's).
- **The secret-leak pattern**: `verify-gate.secret_scan`. The manifest's value is a literal carrying
  a `<secret-leak pattern>` shape the script passes through unanswered, so give the whole key.
- **The deploy target** — not a knob: deploy is inline-leaf, so it is part of the
  `fill:docs/agents/project-workflow.md#Working in this repo` answer, with the rest of the list
  below.

The `verify-gate` literals assume npm script names; where the project's package manager or scripts
differ, the answers file gives those keys too, read off `package.json` and confirmed.

**Web-specific concerns live as INLINE-LEAF, in the contract's project sections
(`docs/agents/project-workflow.md`) — not in either adapter, which carry host mechanics only.** They
reach the contract as fills of the engine's `## Working in this repo` and `## Running` prompts; no
manifest knob or shared Chunk carries them. Each is asked at the interview with the
`#Working in this repo` fill, and an item with nothing to say for this project is left out:

- **Deploy** — the target, the commands that push to it, where the secrets live, the
  client-to-API boundary the frontend is held to, and anything under the deploy directory
  (reverse-proxy config, service units). All human-gated; project-specific. A deploy command
  belongs here even when it is a one-liner: no knob key holds it, and an answers-file key the
  Profile does not list is a stop.
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
