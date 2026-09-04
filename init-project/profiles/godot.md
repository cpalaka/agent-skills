---
type: godot
imports: []                 # No UNCONDITIONAL imports beyond dev-base + the fork.
                            # backlog-core is CONDITIONAL (like blender-mcp-guide): the recipe's
                            # "Board (conditional)" step decides it at apply time and wires it
                            # (import line + knob block + init) — never the default knob pass.
fork: git-flow-squash       # The default (ADR-0002). git-flow-noff is the opt-in alternative.
                            # MIGRATION: pick the fork from the repo's REAL git history, not this
                            # default. Pre-chunk Godot bootstrapping prescribed NO git-flow
                            # model at all, so a pre-chunk Godot repo has whatever its history shows:
                            # linear / squash-merged history → git-flow-squash; genuine `--no-ff`
                            # merge commits → git-flow-noff. Never flip a project's integration model
                            # as a scaffolding side effect. (The `--no-ff` default was the old BACKLOG
                            # init template's model, NOT the godot one — ADR-0002.)

# Template assets under profiles/godot/templates/ are already copied in; this manifest enumerates
# the ones to STAMP, with DEST (engine step 3: copy src→dest, skip-if-exists unless refresh:true).
# The godot settings.local.json delta is NOT a template — it is the `settings:` field below,
# merged into .claude/settings.local.json by the engine (step 4). blender-mcp-guide.md is stamped
# CONDITIONALLY (only for Blender-pipeline projects) — see the recipe, not this list.
# The three contract/adapter fragments are NOT stamped from here either: they are the `adapters:`
# field below, inserted into the engine's own Templates at their markers (engine step 1).
# Three stamps have a recipe ORDERING dependency: mcp.json, codex/config.toml and mcp/package.json
# all point into tools/mcp/, so the recipe's lockfile-freeze runs before any of those trees is used.
templates:
  # root
  - { src: mcp.json,              dest: .mcp.json }                    # stamped; launches the two npm servers from the frozen tools/mcp tree (freeze runs first — see Bespoke). No godot-ai entry: see step 4.4
  - { src: codex/config.toml,     dest: .codex/config.toml }           # the Codex counterpart of .mcp.json; {{PROJECT_ROOT}} is DERIVED from pwd at the repo root, never asked. Same freeze ordering; gitignored machine-wide, see step 8
  # per-project reference docs (docs/) — always copy, skip-if-exists unless refresh
  - { src: godot-mcp-guide.md,    dest: docs/godot-mcp-guide.md }
  - { src: domain.md,             dest: docs/agents/domain.md }        # host-neutral pointer to CONTEXT.md + docs/adr/; both adapters reach it through the contract
  - { src: asset-pipeline.md,     dest: docs/asset-pipeline.md }       # carries a {{WORKSPACE_ROOT}} token — engine step 3 asks for it
  - { src: godot-gotchas.md,      dest: docs/godot-gotchas.md }
  # headless test harness (tests/)
  - { src: tests/run_tests.sh,                          dest: tests/run_tests.sh }    # chmod +x in recipe
  - { src: tests/scene_tree_test.gd,                    dest: tests/scene_tree_test.gd }
  - { src: tests/fixtures/fixture_pass.gd,              dest: tests/fixtures/fixture_pass.gd }
  - { src: tests/fixtures/fixture_assert_fail.gd,       dest: tests/fixtures/fixture_assert_fail.gd }
  - { src: tests/fixtures/fixture_missing_pin.gd,       dest: tests/fixtures/fixture_missing_pin.gd }
  - { src: tests/fixtures/fixture_no_base.gd,           dest: tests/fixtures/fixture_no_base.gd }
  - { src: tests/fixtures/fixture_runtime_abort.gd,     dest: tests/fixtures/fixture_runtime_abort.gd }
  - { src: tests/fixtures/fixture_hang.gd,              dest: tests/fixtures/fixture_hang.gd }
  - { src: tests/fixtures/fixture_truncated_clean.gd,   dest: tests/fixtures/fixture_truncated_clean.gd }
  - { src: tests/fixtures/fixture_parse_error.gd.txt,   dest: tests/fixtures/fixture_parse_error.gd.txt }  # inert .gd.txt — never a live .gd
  # project-local subagents (.claude/agents/)
  - { src: agents/godot-export-verifier.md,  dest: .claude/agents/godot-export-verifier.md }
  # host-neutral tool entry points (tools/agent/) — named by the knob strings below, so they must
  # resolve on either host; chmod +x in recipe
  - { src: agents/godot-gotchas-scan.sh,     dest: tools/agent/godot-gotchas-scan.sh }
  # user-level helper (NOT in-repo; chmod +x in recipe)
  - { src: godot-mcp-clean,       dest: ~/.local/bin/godot-mcp-clean }   # user-level, once per machine; recipe chmod +x
  # lockfile-freeze seed (engine step 6 mechanic, payload below)
  - { src: mcp/package.json,      dest: tools/mcp/package.json }   # pins both servers exactly; recipe runs the freeze

# The three fragments the engine inserts into ITS Templates (engine step 1). The Godot project
# rules are contract content — host-neutral, "your host adapter says how" — and each adapter
# fragment carries only what is true of that host alone.
adapters:
  contract: contract.md          # → <!-- profile:contract-sections --> in docs/agents/project-workflow.md
  claude:   adapter-claude.md    # → <!-- profile:claude-mechanics --> in CLAUDE.md
  codex:    adapter-codex.md     # → <!-- profile:codex-mechanics --> in AGENTS.md

settings:                 # merged into .claude/settings.local.json by the engine (step 4)
  allow:
    - "Bash(pgrep -fl:*)"
    - "Bash(lsof -nP -iTCP:6550*)"
    - "Bash(lsof -nP -iTCP:8000*)"
    - "Bash(lsof -nP -iTCP:9500*)"
    - "Bash(mkdir -p:*)"
    - "Bash(chmod +x:*)"
    - "Bash(godot-mcp-clean)"
    - "mcp__godot__get_diagnostics"
    - "mcp__godot__clear_console_output"
    - "mcp__godot__get_console_output"
    - "mcp__godot__scan_workspace_diagnostics"
    - "mcp__godot-mcp__godot_scene"
    - "mcp__godot-mcp__godot_node"
    - "mcp__godot-mcp__godot_scene3d"
    - "mcp__godot-mcp__godot_editor"
    - "mcp__godot-mcp__godot_project"
    - "mcp__godot-mcp__godot_resource"
    - "mcp__godot-mcp__godot_docs"
    - "mcp__godot-mcp__godot_input"
    - "mcp__godot-mcp__godot_runtime_state"
    - "mcp__godot-ai__*"
  enabled_mcp_servers: [ godot-mcp, godot ]   # godot-ai is NOT an .mcp.json server since 3.2.x — its dock registers
                                            # a user-scope stdio entry in ~/.claude.json itself (recipe step 4.4)

# These knob strings are stamped into a project's docs/agents/project-workflow.md and
# backlog/config.yml and are read there, detached from this file — and they are read on BOTH
# hosts. So none of them names a per-host skill root: the gotcha scan is invoked through
# `tools/agent/godot-gotchas-scan.sh`, the stamped wrapper that resolves the skill under either
# root and hands off (the rationale for testing both roots is stated once, under "Companion
# Skills are gated" in the recipe below). Read the wrapper's VERDICT line, never `$?`; give it a
# scope (`--all`, or the scan's own diff arguments), because VACUOUS is not a pass.
knobs:
  backlog-core:             # CONDITIONAL — written ONLY when backlog-core is imported (board-driven
                            # project); skipped entirely for a board-less prototype.
    VERSION: "<pin the installed backlog CLI version>"
    PLANS_DIR: "docs/plans/"
    VERIFY_EXAMPLES: "tests/run_tests.sh green via the headless runner; an in-editor F5 / interactive verification of the affected surface; a Gotcha pre-commit scan — `tools/agent/godot-gotchas-scan.sh --all`, or the scan's diff arguments for the change (read the VERDICT line, not `$?`; with no scope on a clean tree it prints `VERDICT: VACUOUS`, which is NOT a pass), then a hand-scan of the diff's Detect-proactively patterns"
    # Godot-flavored DoD — standing gates for every task, ending in the user-sign-off gate
    # (backlog-core requires the list end in sign-off). Stamped into backlog/config.yml at
    # task-create time; config changes don't back-propagate.
    DoD:
      - "Headless test suite green via tests/run_tests.sh (verdict from output, not $?)"
      - "Gotcha pre-commit scan — tools/agent/godot-gotchas-scan.sh (read the VERDICT line, not $?), then a hand-scan of the diff — clean, or each finding addressed"
      - "New gotchas filed: project-local -> docs/godot-gotchas.md; universal -> the `godot-gotchas` skill where it is installed — its directory exists under `~/.claude/skills` (Claude Code) or `~/.agents/skills` (Codex) — otherwise docs/godot-gotchas.md as well. Load-bearing decisions recorded as docs/adr/ entries"
      - "Any debug/diagnostic scaffolding (autoload prints, temp scenes, profiler hooks) reverted"
      - "User sign-off received"
  verify-gate:
    # The godot verify gate, one key per step of the chunk's invariant sequence
    # (typecheck → test → build → smoke → secret-scan), plus dir and env. For a Godot project
    # the test step is the headless runner, the "build" is a headless export, and the "smoke" is
    # opening the project / F5 the affected scene.
    dir: "the repo root (the runner cd's into tests/ itself)"
    # NOT `--check-only --quit`: measured 2026-09-03 on Godot 4.7.2.stable, that prints the banner
    # and never exits, because --check-only modifies --script and with no script the run never
    # reaches --quit. A gate step that hangs reads as a pass to anyone watching for a failure.
    typecheck: "godot --headless --path . --import --quit, output grepped for `SCRIPT ERROR` / `Parse Error` — expect zero. **Not an exhaustive parse**; treat it as a smoke check, not project-wide parse coverage. Same editor-lifecycle pass the init recipe's Edit C runs; it returned in under 40 s on Godot 4.7.2.stable (measured 2026-09-03)"
    test: "tests/run_tests.sh — the headless runner; see **## Running** for its verdict-from-output / --selftest / never-trust-`$?` discipline"
    build: "headless export via the project's export smoke-tester (`godot-export-verifier`; your host adapter says how to dispatch it) — pre-push / at milestone close, not per-merge"
    build_check: "the smoke-tester's own PASS/FAIL line per platform preset, read from its output — an export that exits 0 having written nothing still reports FAIL there"
    smoke: "open the project / F5 the affected scene (a green test run is not a played scene)"
    secret_scan: "git grep -nE '(api[_-]?key|secret|password|token)\\s*=' -- ':!docs' ':!*.md' ':!addons'  # vendored addons/ excluded; expect ZERO — investigate any match"
    env: "$GODOT → the editor binary (macOS app path → `godot` on PATH); run from the repo root. The runner writes its capture files under $TMPDIR, so it needs no sandbox bypass on either host (measured 2026-09-03)"
  dev-practice:
    # test-roster: where the authoritative list of required-coverage modules lives.
    test_roster: "the project board (backlog) if present, else the design docs under docs/; new gameplay systems with verifiable runtime behaviour get a tests/test_<topic>.gd before implementation"
    # spec-verify: the source surface a spec's [reuse] claims are checked against.
    spec_verify_src: "the project's GDScript/scene tree (res://) + addons/"
  parallel-work:
    # parallel-work rides dev-base (value-variant): the engine writes these into the project's
    # <!-- knobs:parallel-work --> block. Solo prototypes rarely fan out, but the chunk is always
    # imported via dev-base, so it needs values, not an empty block.
    worktree_path_prefix: "../<proj>-task-NNN-<slug>"   # where `git worktree add` puts each tree
    install: "npm ci --prefix tools/mcp (rehydrate the frozen MCP launcher tree), then import once (open the editor or `godot --headless --path . --import`) so the global class cache exists — else tests/run_tests.sh false-FAILs fixture_pass.gd"
---

## Bespoke setup

The heavy Godot recipe. The engine already owns the uniform steps — the contract and the two
adapters (the @imports, the tagged knob blocks above, and the three `adapters:` fragments), the
`.claude/settings.local.json` merge (the godot allow-delta, union by exact-string dedup), plain
Template stamping, the lockfile-freeze MECHANIC, verify-after-write including the byte gate, and the
handoff. Do **not** re-run those here.
This recipe supplies only what the manifest can't express: the MCP install, the `project.godot`
edits, the freeze PAYLOAD, and the load-bearing WHYs. Run the numbered steps in order.

**Companion Skills are gated.** Nothing this Profile stamps hard-requires a companion Skill.
Where a step is better with one, it tests for that Skill's directory under **both**
`~/.claude/skills` and `~/.agents/skills` — Claude Code and Codex resolve Skills through
different roots, so a gate that checks one skips the step for every consumer on the other host.
An absent companion always means skip that step and take the stated fallback, never fail. In a
script the test is:

```
[ -d "$HOME/.claude/skills/godot-gotchas" ] || [ -d "$HOME/.agents/skills/godot-gotchas" ]
```

That test is why `tools/agent/godot-gotchas-scan.sh` is stamped: a knob string lands in the
project's contract and in `backlog/config.yml`, where both hosts read it, so it names the wrapper
and the wrapper does the resolving. Its own exit 2 (neither root holds a runnable scanner) is a
broken install to fix, never a clean verdict.

**Board (conditional):** backlog-core is NOT imported unconditionally — it actively instructs
board ops ("session start: check the board"), so it is not safe-when-unused. Decide at apply
time whether this project is board-driven: if `backlog/` already exists,
or the user wants a board (default **yes** for a real game project, **no** for a
prototype/sketch), then (a) add `@~/.claude/chunks/backlog-core.md` to the `CLAUDE.md` import
block, (b) write the `<!-- knobs:backlog-core -->` block from the manifest knobs **into
`docs/agents/project-workflow.md`**, at the position this manifest's `knobs` order gives it,
(c) run **steps 1–4 of `profiles/backlog.md` → `## Bespoke setup`** — the install check, the
`backlog init`, the `definition_of_done` hand-edit, and the seeding pass (which still needs an
explicit go-ahead per `backlog-core`); its step 5, the adoption commit, is the engine handoff's job,
not a second commit here — (d) stamp that Profile's `issue-tracker.md` and `triage-labels.md`
Templates to `docs/agents/` (`issue-tracker.md` is the canonical tracker pointer
for skills that look up that path: code-review, triage, to-tickets), and (e) insert that Profile's
contract fragment `## Board` section into `docs/agents/project-workflow.md`, so the two pointers
have a reader. If board-less, skip all five —
the project keeps its task-tracking guidance in the contract's project sections instead. Re-running
init-project later with the board enabled adds exactly this wiring (the engine is idempotent:
import-line dedup + knob insert).

**Reference docs:** the engine always stamps `docs/godot-mcp-guide.md`, `docs/asset-pipeline.md`,
`docs/godot-gotchas.md` and `docs/agents/domain.md`. **Blender is opt-in** — only if the project
uses a Blender→Godot pipeline, also stamp `templates/blender-mcp-guide.md` →
`docs/blender-mcp-guide.md`; otherwise drop the contract fragment's one Blender-MCP bullet. The
asset-pipeline bullet stays either way — that doc is stamped unconditionally. Both MCP
guides are carried forward as-is and are **due a content-staleness audit at step 6** (they track
live MCP tool reality / Blender API drift).

**Stamp order, and the two files that must wait for the freeze.** `.mcp.json` and
`.codex/config.toml` both launch the two npm servers out of `tools/mcp/node_modules/`, so both are
written **after** step 5's lockfile-freeze — otherwise they point at a tree that does not exist yet.
`.codex/config.toml` needs absolute paths (Codex resolves a relative MCP `cwd` against the launch
directory, not the repo), so its `{{PROJECT_ROOT}}` is filled from `pwd` at the repo root, derived,
never asked. `chmod +x tools/agent/godot-gotchas-scan.sh` after stamping it; a present-but-non-
executable copy takes the wrapper's exit-2 path.

### 1. User-level helpers (once per machine, idempotent — independent of this project)

- **`godot-mcp-clean`** — the manifest stamps it to `~/.local/bin/godot-mcp-clean`; here
  `chmod +x ~/.local/bin/godot-mcp-clean`, then confirm `~/.local/bin` is on PATH
  (`echo $PATH | tr ':' '\n' | grep -q '\.local/bin'`; if not, tell the user to add
  `export PATH="$HOME/.local/bin:$PATH"` to their shell rc). It encapsulates the single
  legitimate `kill` use case (orphan node MCP servers hogging the editor's single-client
  bridge slot) — which is **why `Bash(kill:*)` stays OFF the allowlist**. **Scope:** it reaps
  ONLY orphaned `node …godot-mcp` servers (not godot-ai's uv server, not minimal-godot), so it
  is a break-glass helper, low-frequency by design. If a project ever drops godot-mcp entirely
  (godot-ai-only), drop `godot-mcp-clean` AND its `Bash(godot-mcp-clean)` allowlist line together.
- **`godot-gdscript-patterns` skill** (global, idempotent):
  `test -d ~/.agents/skills/godot-gdscript-patterns && echo installed || npx -y skills add wshobson/agents@godot-gdscript-patterns -g -y`
- **`godot-animation-tree-mastery` skill** (global, idempotent — narrower, AnimationTree-only;
  pre-installing is cheap):
  `test -d ~/.agents/skills/godot-animation-tree-mastery && echo installed || npx -y skills add thedivergentai/gd-agentic-skills@godot-animation-tree-mastery -g -y`

### 2. Verify target is a Godot project

`test -f project.godot` — if absent, STOP and ask the user; do not create a Godot project
from scratch (ask them to run Godot first). If the directory is not yet a git repository and the
user wants one, `git init -b main` — a bare `git init` yields `master` on this machine, and every
sibling Godot repo is on `main`.

### 3. Install the in-engine addon (version-pinned to the server)

```
npx -y @satelliteoflove/godot-mcp@4.1.0 --install-addon .
```

Copies `addons/godot_mcp/` (the WebSocket bridge the servers connect to). **WHY @4.1.0:**
the addon version must match the server pin in `tools/mcp/package.json` — an addon ↔
server major-version split risks a bridge-protocol mismatch (connection fails / tools misbehave
after `/mcp`). Bump one → bump both (the `--install-addon` flag verified present on 4.1.0's CLI). Then **verify both paths step 6 depends on** exist, or the
autoload registration silently references a missing file:

```
test -f addons/godot_mcp/plugin.cfg && \
  test -f addons/godot_mcp/game_bridge/mcp_game_bridge.gd && echo OK || echo "addon incomplete"
```

If either is missing, STOP and surface the error (version mismatch, no `node` on PATH, or the
upstream package restructured the addon layout) — do not proceed to step 6.

### 4. OPTIONAL — godot-ai writer plugin (skippable)

`godot-ai` (`hi-godot/godot-ai`, MIT) is the **primary writer** in the recommended setup
(scene/node/script/property creation, `input_map_manage`, `script_patch`, `project_run`,
`editor_screenshot`, `logs_read`). It writes most struct types correctly (why it is the writer)
but is **not** universal: it omits `uid=` on first save (still live on godot-ai 3.1.3; not
re-probed on 3.2.4), and it
has no Skeleton3D-bone and no AnimationTree authoring verbs (both re-probed, measured
2026-08-08). Three once-live bridge quirks are fixed upstream — `Vector2i` (2.8.0+), the
`input_map` list, and typed `Array[T]` — as is the `@tool` create gate, whose error names its own
fix. If the `godot-gotchas` skill is installed (its directory exists under `~/.claude/skills` or
`~/.agents/skills`), its catalog is the current quirk set and its retired list says which quirks
no longer apply; otherwise skip that lookup and treat the notes here as the record. godot-mcp
stays as the read/test complement. Skip this step only if the project writes through godot-mcp
(not recommended — godot-mcp silently no-ops `Rect2`).

1. **Vendor the addon (pinned + TRACKED).** From a clone of `hi-godot/godot-ai`,
   `git checkout v3.2.4` (the current baseline — check `git ls-remote --tags` for newer; the
   pin here is re-read against the fleet at each `audit-godot-parity` run) **before copying**,
   then copy the install-ready `addons/godot_ai/` (at `plugin/addons/godot_ai/`, not the repo
   root; a `src/godot_ai` copy is NOT the one to vendor) into the project's `addons/`.
   **WHY the tag is the pin:** the vendored `plugin.cfg` version drives which Python MCP
   server the dock fetches from PyPI via `uvx` (`uv` must be on PATH) — so the checked-out
   tag pins BOTH addon and server, stopping cross-project drift. **Commit the vendored copy;
   do NOT gitignore it.** The addon self-updates in-editor and rewrites `project.godot` and
   `.mcp.json` on its own schedule (gotcha #116): an ignored copy drifts with no git trace
   and the recorded version rots silently (measured on one project: a silent
   2.8.4 → 3.1.3 bump left 23 of 47 recorded godot-ai claims stale). Tracked, the drift
   shows in `git status` and can be pinned by a test that asserts `plugin.cfg` equals the
   version the contract records. Record the vendored tag in the contract's godot-ai section
   (`docs/agents/project-workflow.md`), which is where both hosts read it.
2. **Disable telemetry** (ON by default): set `GODOT_AI_DISABLE_TELEMETRY=true` before first
   launching the editor; the setting persists once written.
3. **Enable the plugin** at Project → Project Settings → Plugins after opening the editor.
4. **The MCP client entry is written by the dock, at USER scope — not by this recipe.**
   Since godot-ai 3.2.x the dock configures the client itself: on first enable it writes a
   stdio entry into `~/.claude.json` (`uvx --from godot-ai==<plugin.cfg version> godot-ai
   attach --port 8000 --ws-port 9500 --disable-telemetry`) and deletes any project-scope
   `godot-ai` block from `.mcp.json` — which is why the stamped `mcp.json` carries none and
   the `settings` delta lists only the two npm servers in `enabled_mcp_servers` (the
   `mcp__godot-ai__*` allow stays; user-scope servers are not gated by
   `enabledMcpjsonServers`). Verify after the first editor launch:
   `python3 -c 'import json;print(json.load(open("$HOME/.claude.json"))["mcpServers"]["godot-ai"])'`.
   Two consequences: (a) the pin now lives in that user-scope entry — bumping the vendored
   tag without re-running the dock's client setup leaves the client on the old server;
   (b) the entry **hardcodes 8000/9500** while the plugin itself walks ports on collision —
   if the dock moves, re-run its client setup rather than hand-editing `~/.claude.json`.
   The entry is INERT until the plugin is enabled AND the editor is running — a fresh session
   shows godot-ai disconnected in `/mcp`; expected, not a bug. The dock writes the equivalent
   user-scope entry for each host it configures, hardcoding the same ports in each, so a port
   walk strands every host at once — the contract's godot-ai section carries that rule, and
   `.codex/config.toml` lists the two npm servers only, exactly as `.mcp.json` does.

**If NOT using godot-ai:** drop the `mcp__godot-ai__*` allow from `settings.local.json` and
remove the user-scope `godot-ai` entry from `~/.claude.json` if a previous project's dock
wrote one (it is machine-wide, so it will otherwise show as a failed server in every
project). (`uv` on PATH is a prerequisite when used — the dock auto-starts a uv-managed
Python server on `:8000` + `:9500`.) **Then fix the contract, or it documents a server the project
does not have:** delete the fragment's whole `## godot-ai addon (vendored, TRACKED)` section and the
godot-ai half of the Project-pins sentence in the MCP bullet, and name godot-mcp as the writer in
that bullet's division of labour. `.mcp.json` and `.codex/config.toml` are unaffected — neither ever
listed godot-ai.

### 5. Lockfile-freeze PAYLOAD (the engine mechanic, godot's package set)

The engine's step-6 mechanic (install once → commit the lock, not the modules → gitignore the
tree → record the rehydrate command) runs against THIS payload:

1. `tools/mcp/package.json` is already stamped (pins `@satelliteoflove/godot-mcp@4.1.0` and
   `@ryanmazzolini/minimal-godot-mcp@0.1.6` exactly — no `^`/`~`).
2. `npm install --prefix tools/mcp --no-audit --no-fund` → writes `tools/mcp/package-lock.json`
   (lockfileVersion 3, sha512 per package) and materializes `tools/mcp/node_modules/`.
   **Commit the lockfile + package.json, NOT `node_modules/`.**
3. Stop Godot import-scanning the tree: create an **empty** `tools/.gdignore`
   (**NOT** `.godotignore` — the wrong name silently does nothing).
4. Append `tools/mcp/node_modules/` **and `.godot/`** to `.gitignore` (create if absent;
   exact-string dedup). `.godot/` is the editor's generated cache: the contract and the handoff both
   state it is gitignored, and this is the only step that makes that true.

**WHY freeze:** `.mcp.json` and `.codex/config.toml` launch the two npm servers on *every* session
on their host.
`npx -y <pkg>@<ver>` re-resolves the **unpinned transitive tree** from the registry on each
cold start and runs install lifecycle scripts — a recurring arbitrary-code-execution surface
on the dev machine and on every clone that approves the MCP prompt. Pinning the top-level
version does NOT freeze the transitive tree; launching from a committed lock does. (Distinct
from step 3's `--install-addon`: that is a one-time pinned fetch whose committed result
isn't a recurring runtime exposure.)

### 6. Write both MCP adapters from the frozen tree, then edit `project.godot`

`.mcp.json` (the stamped `mcp.json`) launches the two servers via `node tools/mcp/node_modules/…`
(NOT `npx -y`) — **which is why the freeze (step 5) must run first**: otherwise it points at a
`node_modules/` that doesn't exist yet. `.codex/config.toml` (the stamped `codex/config.toml`) is
the same two servers for the other host, with `{{PROJECT_ROOT}}` filled from `pwd` at the repo root
and `required = false`, so a wrong or unreplaced path fails silently rather than blocking a session.

Then check the ignore: `git check-ignore -q .codex/config.toml`. It should already be covered
machine-wide by `**/.codex/config.toml` in `~/.config/git/ignore`; if it is not, tell the user to
add that line there, and do **not** add it to the project's `.gitignore` — the file is per-clone and
machine-local, and one line in the machine-wide ignore covers every project.

Then read `project.godot` and make three edits (sections are top-level INI-style; Godot
reorders cleanly on next save):

- **Edit A — `[editor_plugins]`.** Add `"res://addons/godot_mcp/plugin.cfg"` to
  `enabled=PackedStringArray(...)`. If the section/key is absent, create it; **always use the
  `PackedStringArray("...")` wrapper even for a single path** (a bare `enabled=res://...` is
  invalid). If the array exists, parse the quoted paths between the parens and add the entry
  only if not already present (exact-string match); preserve existing paths.
- **Edit B — `[autoload]`.** Add `MCPGameBridge="res://addons/godot_mcp/game_bridge/mcp_game_bridge.gd"`
  if not already present; don't disturb other autoloads.
- **Do NOT hand-write a `[godot_mcp]` section** — Godot auto-writes its default settings
  (`bind_mode`, `port_override`, …) on the first import/editor-open (Edit C below). Your
  hand-edits happen before that; leave that section to be auto-created.
- **Edit C — import to populate the class cache, then re-verify the harness:**
  ```
  godot --headless --path . --import        # editor-build-only flag; writes .godot/global_script_class_cache.cfg, then quits
  grep -c MCPFrameProfiler .godot/global_script_class_cache.cfg   # must be > 0
  tests/run_tests.sh --selftest             # must end with: selftest: 8/8 verdicts correct
  ```
  **WHY:** the `MCPGameBridge` autoload references the addon's `class_name` types
  (`MCPFrameProfiler`, `MCPRuntimeStateSampler`, `MCPLog`, …), which resolve only from
  `.godot/global_script_class_cache.cfg`. A never-opened project hasn't written it, so the
  autoload fails to parse during project init. Because `tests/run_tests.sh` runs
  `godot --headless --path .` (instantiating autoloads every test), those parse errors get
  prepended to every test's output and trip the runner's `SCRIPT ERROR` / `Failed to load
  script` greps — a **false FAIL** on the green `fixture_pass.gd`. A plain `--script` run never
  builds the cache, so the harness can't self-heal; only an editor-lifecycle pass (`--import`
  or opening the editor) writes it. **This post-import 8/8 — not any earlier selftest — is the
  authoritative harness verification.** If only an export-template/headless-server Godot is
  reachable (no `--import`), defer Edit C to the handoff (opening the editor has the same
  effect). The import also auto-writes the `[godot_mcp]` settings section — expected; leave it.

  **WHY the runner verdicts from output, not `$?`:** headless `--script` exit codes lie — a
  parse failure and a mid-run runtime abort both exit 0, so a bare `godot --script` run can
  look green having run nothing. The runner greps the captured output (summary-line +
  `SCRIPT ERROR` / `Failed to load script` + a perl-alarm timeout) and each test pins
  `const EXPECTED_CHECKS := <N>` so silent truncation becomes a counted failure.

### 7. Handoff additions (beyond the engine's standard handoff)

Tell the user, in addition to the engine's external-includes-approval note:

1. Open (or restart) the Godot 4.x editor to pick up the new addon + autoload.
2. Confirm the `godot_mcp` plugin (and `godot_ai`, if installed) is enabled at
   Project → Project Settings → Plugins.
3. In Claude Code, `/mcp` to (re)connect the servers to the now-running bridge; verify with
   `mcp__godot-mcp__godot_project addon_status` → `connected: true`. In Codex, `codex mcp list`
   from the repo root must show both npm servers enabled beside the user-scope godot-ai.
   **Single-client bridge:** the godot-mcp bridge accepts ONE client, on either host — if they hit
   "Another MCP server connected and replaced this one", or a Codex read reports the bridge already
   held, run `godot-mcp-clean` and reconnect from the one session that should hold it.
4. **Fresh-clone rehydrate** (the lockfile-freeze clone gap): `node_modules/` and `.godot/`
   are both gitignored, so a clone must (a) `npm ci --prefix tools/mcp` once
   (integrity-verified against the committed lock) before the godot-mcp/minimal tools load,
   (b) import once — open the editor or `godot --headless --path . --import` — or
   `tests/run_tests.sh` false-FAILs `fixture_pass.gd` with `SCRIPT ERROR` (class cache empty),
   (`addons/godot_ai/` is tracked — step 4.1 — so no re-vendor step; but the godot-ai MCP
   client entry is user-scope, so a clone on a NEW machine gets it only after the dock's first
   enable — step 4.4). `.codex/config.toml` is gitignored too, so a clone re-creates it from the
   block in `docs/godot-mcp-guide.md` § Host adapters with its own absolute root. Neither host
   picks up an MCP change without a new session.
5. If the user-level Claude Code settings don't already allow the godot-mcp tools, the
   user may get permission prompts — user-level perms are out of scope here (this profile sets
   project-level perms only). Codex has no such allowlist; its sandbox and approval policy are
   the equivalent, and `AGENTS.md` states the profile this repo expects.

## Migrating a pre-contract Godot project

Run the engine's `## Migrate mode` first; it moves the prose. Two things are godot-specific:

- **The knob value migrate flags is this Profile's `tools/agent/godot-gotchas-scan.sh`.** A
  pre-contract project's `VERIFY_EXAMPLES` and DoD item 2 name
  `~/.claude/skills/godot-gotchas/scripts/precommit-scan.sh` — a path that resolves on one host and
  silently misses on the other. Migrate reports it; the replacement is the stamped wrapper, with the
  read-the-VERDICT-line and give-it-a-scope wording the knobs above carry.
- **Then run init once.** Migrate emits no Templates, so the wrapper itself, `.codex/config.toml`,
  `docs/agents/domain.md` and (with a board) `docs/agents/triage-labels.md` are still absent after
  it. Init is idempotent and skip-if-exists, so a second run over a migrated project stamps exactly
  the missing files and touches nothing migrate wrote.
