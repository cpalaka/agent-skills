---
imports: []                 # No imports beyond dev-base. The tracker, the fork and every knob key
                            # not listed below are the engine's (init-project/defaults.md).

# Template assets under profiles/godot/templates/; this manifest enumerates the ones to STAMP, with
# DEST (written by `stamp`, engine step 2; a dest already in the target is not overwritten).
# The godot settings.local.json delta is NOT a template — it is the `settings:` field below,
# merged into .claude/settings.local.json by `stamp`. blender-mcp-guide.md and
# asset-pipeline.md carry `opt_in: blender`, taken only for a Blender-pipeline project (see the
# recipe); what `stamp` does with it is `--help`'s, under `stamp`.
# The four `adapters:` fragments are NOT stamped from here either: they are the `adapters:`
# field below, inserted into the engine's own Templates at their markers by `stamp`.
# Three stamps point into tools/mcp/. package.json is the freeze's input, so it is stamped before
# it; the two that launch from the frozen tree carry after_freeze: true, so `stamp` skips them and
# `stamp --after-freeze` (engine step 3, after the recipe's step 5 freeze) writes them.
templates:
  # root
  - { src: mcp.json,              dest: .mcp.json, after_freeze: true }                    # launches the godot-mcp server from the frozen tools/mcp tree. No godot-ai entry: see recipe step 4.4
  - { src: codex/config.toml,     dest: .codex/config.toml, after_freeze: true }           # the Codex counterpart of .mcp.json; {{PROJECT_ROOT}} is DERIVED from pwd at the repo root, never asked. Gitignored machine-wide by `host-setup` (engine step 8)
  # per-project reference docs (docs/) — one already in the target is kept; the Blender pair only
  # where opt_in blender is taken
  - { src: godot-mcp-guide.md,    dest: docs/godot-mcp-guide.md }
  - { src: blender-mcp-guide.md,  dest: docs/blender-mcp-guide.md, opt_in: blender }
  - { src: asset-pipeline.md,     dest: docs/asset-pipeline.md, opt_in: blender }    # carries {{WORKSPACE_ROOT}}, given in the answers file's tokens block
  - { src: domain.md,             dest: docs/agents/domain.md }        # host-neutral pointer to CONTEXT.md + docs/adr/; both adapters reach it through the contract
  - { src: godot-gotchas.md,      dest: docs/godot-gotchas.md }
  # headless test harness (tests/)
  - { src: tests/run_tests.sh,                          dest: tests/run_tests.sh }
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
  # host-neutral tool entry points (tools/agent/) — named by the contract fragment's gotcha-scan
  # rule (contract.md), which both hosts read, so they must resolve on either host
  - { src: agents/godot-gotchas-scan.sh,     dest: tools/agent/godot-gotchas-scan.sh }
  # user-level helper (NOT in-repo): written by `host-setup`, engine step 8
  - { src: godot-mcp-clean,       dest: ~/.local/bin/godot-mcp-clean }   # user-level, once per machine
  # lockfile-freeze seed (the engine's freeze mechanic, engine step 3; payload in recipe step 5)
  - { src: mcp/package.json,      dest: tools/mcp/package.json }   # pins the server exactly; recipe runs the freeze

# The four fragments `stamp` inserts into the engine's Templates. The Godot project
# rules are contract content — host-neutral, "your host adapter says how" — and each adapter
# fragment carries only what is true of that host alone.
adapters:
  contract: contract.md          # → <!-- profile:contract-sections --> in docs/agents/project-workflow.md
  claude:   adapter-claude.md    # → <!-- profile:claude-mechanics --> in CLAUDE.md
  codex:    adapter-codex.md     # → <!-- profile:codex-mechanics --> in AGENTS.md
  gate_runner: adapter-gate-runner.md   # → <!-- profile:gate-runner-mechanics --> in .claude/agents/gate-runner.md

settings:                 # merged into .claude/settings.local.json by `stamp`
  allow:
    - "Bash(pgrep -fl:*)"
    - "Bash(lsof -nP -iTCP:6550*)"
    - "Bash(mkdir -p:*)"
    - "Bash(chmod +x:*)"
    - "Bash(godot-mcp-clean)"
    - "mcp__godot-mcp__godot_scene"
    - "mcp__godot-mcp__godot_node_read"
    - "mcp__godot-mcp__godot_node_edit"
    - "mcp__godot-mcp__godot_scene3d"
    - "mcp__godot-mcp__godot_editor_read"
    - "mcp__godot-mcp__godot_editor_edit"
    - "mcp__godot-mcp__godot_project"
    - "mcp__godot-mcp__godot_resource"
    - "mcp__godot-mcp__godot_docs"
    - "mcp__godot-mcp__godot_input"
    - "mcp__godot-mcp__godot_runtime_state"
    - "mcp__godot-ai__*"
  enabled_mcp_servers: [ godot-mcp ]          # godot-ai is NOT an .mcp.json server since 3.2.x — its dock registers
                                            # a user-scope stdio entry in ~/.claude.json itself (recipe step 4.4)

# These knob strings are stamped into a project's docs/agents/project-workflow.md and are read
# there, detached from this file — and they are read on BOTH hosts. So none of them names a per-host
# skill root. None names the gotcha scan either: the contract fragment's gotcha-scan rule
# (contract.md) reaches it through `tools/agent/godot-gotchas-scan.sh`, the stamped wrapper that
# resolves the skill under either root and hands off.
knobs:
  verify-gate:
    # Godot's commands for the verify-gate keys (defaults.md glosses the key set). For a Godot
    # project the test step is the headless runner, the "build" is a headless export, and the
    # "smoke" is a headless run of one scene, output grepped, then F5 the affected scene by hand.
    dir: "the repo root (the runner cd's into tests/ itself)"
    # NOT `--check-only --quit`: measured 2026-09-03 on Godot 4.7.2.stable, that prints the banner
    # and never exits, because --check-only modifies --script and with no script the run never
    # reaches --quit. A gate step that hangs reads as a pass to anyone watching for a failure.
    typecheck: "the `env` knob's resolve line `&&` \"$GODOT\" --headless --path . --import --quit, output grepped for `SCRIPT ERROR` / `Parse Error` / `Error importing` — expect zero (a failed asset import prints `ERROR: Error importing` and matches neither of the first two; this step then runs unsandboxed, see env) — **and for the `Godot Engine v` banner line — expect one: no banner means Godot never ran, a FAIL however the error grep reads** (measured 2026-09-28: a bare `godot` on a host with only the app bundle exits 127 and its error grep reads zero). **Not an exhaustive parse**; treat it as a smoke check, not project-wide parse coverage. The init recipe's Edit C runs the same `--import` pass without `--quit`, which `--import` does not need — it exits on its own (measured 2026-09-28, Godot 4.7.2.stable) — so the flag is a guard, not a different check; it returned in under 40 s on Godot 4.7.2.stable (measured 2026-09-03)"
    test: "tests/run_tests.sh — the headless runner; see **## Running** for its verdict-from-output / --selftest / never-trust-`$?` discipline"
    build: "headless export via the project's export smoke-tester (`godot-export-verifier`; your host adapter says how to dispatch it) — not due unless the owner asks for the export: on any other close a coordinator leaves build out of the gate tier"
    build_check: "the smoke-tester's own PASS/FAIL line per platform preset, read from its output — an export that exits 0 having written nothing still reports FAIL there"
    smoke: "pick the scene: the one the dispatch prompt names as the affected scene (the coordinator names it), else the main scene (`run/main_scene` in project.godot). Where the prompt names none and project.godot has no `run/main_scene` (a day-zero tree), run nothing and report NOT RUN — no scene yet: with no main scene the headless run prints `Can't run project: no main scene defined` and never returns. Otherwise the `env` knob's resolve line `&&` \"$GODOT\" --headless --path . --quit-after 120 [SCENE], SCENE being the named scene's path, the argument only for a named scene — the main scene runs with none, since `run/main_scene` may be a `uid://` value — output grepped for `SCRIPT ERROR` / `Parse Error` / `Failed to load` / `Failed loading` — expect zero, never $? (a script parse error and a missing scene path both exit 0; with a scene, or with no argument and a `uid://` main scene, it returned in about 1 s, and with no main scene it was killed at 60 s still running; measured 2026-09-26 on Godot 4.7.2.stable) — and for the `Godot Engine v` banner line — expect one: no banner means Godot never ran, a FAIL however the error grep reads. Then F5 the scene the headless run used (the named scene, else the main scene) — a person's step (a headless run is not a played scene); on the NOT RUN branch no F5 step is owed, since there is no scene to play"
    secret_scan: "git grep --untracked -niE -e '(api[_-]?key|secret|password|token)[[:space:]]*=([^=]|$)' --and --not -e 'do-not-print' -- ':!docs' ':!*.md' ':!addons'  # vendored addons/ excluded; expect ZERO — investigate any match. `--untracked` reads files not yet tracked too (ignored ones stay skipped), so the day-zero scan before the adoption commit reads the tree rather than nearly nothing. [[:space:]], not \\s (git grep -E on macOS matches \\s only as a literal, measured 2026-09-04); =([^=]|$) skips == comparisons while still catching an assignment whose value sits on the next line; -i catches API_KEY = …; 'do-not-print' is the reserved sentinel a fixture needing a secret-shaped literal must use, and nothing else in the tree may contain it. Re-calibrate against known-bad plus the benign shapes whenever this line changes (measured 2026-09-13: 4 benign matches before, 0 after)"
    env: "resolve the binary first, in the shell that runs any Godot step: `GODOT=\"${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}\"; [ -x \"$GODOT\" ] || GODOT=\"$(command -v godot)\"; [ -n \"$GODOT\" ] && [ -x \"$GODOT\" ] || { echo \"FATAL: godot binary not found — set GODOT\" >&2; false; }` — the chain tests/run_tests.sh uses (`$GODOT` → the macOS app path → `godot` on PATH); every Godot command runs `&&`-chained after it, never `;`-joined, so a FATAL fails the step, never passes it, and every knob here spells the binary `\"$GODOT\"`. Run from the repo root. The runner writes its capture files under $TMPDIR, so the runner as scaffolded needs no sandbox bypass (measured 2026-09-03) — but that holds only while it greps `^SCRIPT ERROR` alone and the tree has no `.blend`. Sandboxed, Godot is denied `user://logs` and the CA store and prints `ERROR:` for each (godot-gotchas #88), and a `.blend` import crashes at GPU detection (#47). So the typecheck step above, and any runner tightened to grep `^ERROR:`, run with the sandbox off"
  parallel-work:
    install: "npm ci --prefix tools/mcp (rehydrate the frozen MCP launcher tree), then import once (open the editor, or run the `env` knob's resolve line `&&` `\"$GODOT\" --headless --path . --import`) so the global class cache exists — else tests/run_tests.sh false-FAILs fixture_pass.gd"
---

## Bespoke setup

The heavy Godot recipe runs inside the engine's own steps (`SKILL.md` § The run): its step 2 is
a precondition, which engine step 0 runs before anything is written; the rest run at engine step
3, in order. The engine
already owns the uniform work — the contract, the two adapters and the gate seat (the @imports, the
tagged knob blocks above, and the four `adapters:` fragments), the `.claude/settings.local.json`
merge, Template stamping, the lockfile-freeze MECHANIC, `verify` with its byte gates, and the
handoff. Do **not** re-run those here. This recipe supplies only what the manifest can't express:
the MCP install, the `project.godot` edits, the freeze PAYLOAD, the answers to its contract
fragment's fill prompts, and the load-bearing WHYs.

**Companion Skills are gated.** Nothing this Profile stamps hard-requires a companion Skill.
Where a step is better with one, it tests for that Skill's directory under **both**
`~/.claude/skills` and `~/.agents/skills` — Claude Code and Codex resolve Skills through
different roots, so a gate that checks one skips the step for every consumer on the other host.
An absent companion always means skip that step and take the stated fallback, never fail. In a
script the test is:

```
[ -d "$HOME/.claude/skills/godot-gotchas" ] || [ -d "$HOME/.agents/skills/godot-gotchas" ]
```

That test is why `tools/agent/godot-gotchas-scan.sh` is stamped: the contract fragment's gotcha-scan
rule, which both hosts read, names the wrapper, and the wrapper does the resolving. Its own exit 2
(neither root holds a runnable scanner) is a broken install to fix, never a clean verdict.

**The Godot binary.** Every recipe step that runs Godot first runs the `env` knob's resolve line
(the frontmatter above) in the same shell, with the Godot command `&&`-chained to it, never
`;`-joined, and spells the binary `"$GODOT"`; a FATAL there is a stop, never read past — a bare
`godot` exits 127 on a host with only the app bundle, and a grep over that output reads a vacuous
zero.

**The contract fragment's three fill prompts are answered, never edited around.** The fragment sits
in an engine zone, so the recipe changes no text inside it: what varies per project is a prompt,
answered through the answers file, which a re-run keeps. Ask the owner
`fill:docs/agents/project-workflow.md#Blender pipeline` (below; its answer also decides
`opt_in: blender`) at the interview (engine step 1). `#Working in this repo` (the project pins) and
`#godot-ai addon` (the vendored tag, or `none`) are decided by step 4, whose no-godot-ai branch
changes both, so ask them at engine step 5's fill loop.

**Reference docs:** the manifest always stamps `docs/godot-mcp-guide.md`, `docs/godot-gotchas.md` and
`docs/agents/domain.md`. **The Blender pair is opt-in, and the two travel together** —
`docs/blender-mcp-guide.md` and `docs/asset-pipeline.md` both carry `opt_in: blender`. They document
the same pipeline and the pipeline doc points at the MCP guide, so one without the other is a
dangling reference, and the workspace-root question is meaningless with no Blender source. The
owner takes `blender` only for a Blender→Godot pipeline; then the interview (engine step 1) writes
`- opt_in: blender` into the answers file's meta block and `WORKSPACE_ROOT` (the directory holding
both trees) into its tokens block. What `stamp` does with an untaken or taken opt-in is `--help`'s,
under `stamp`. Answer the fragment's `## Blender pipeline` prompt with the branch the project is on.

**A leftover from an earlier run is reported, never deleted.** A project stamped before the pair
went conditional can hold `docs/asset-pipeline.md` with no Blender source: the engine does not
remove a project file, so name it in the run report as a leftover for the owner to delete, answer
the Blender prompt with the no-source branch, and leave the MCP guide's pointer to it conditional as
it is written. The same holds for a server this Profile has since dropped: a re-run leaves it in an
already-stamped project — no Profile Template already in the target is refreshed from its Template
(each reads `SKIPPED`, the two `after_freeze` ones on the `--after-freeze` pass — a fill-answered
prompt's span is its only write) and the settings merge only adds — while the adapter and contract
zones refresh, so the project's files disagree. Diff every Profile Template the target holds
against its render, and the `settings:` delta against the target and name the surplus in the run
report as a leftover for the owner to remove, the owner re-freezing the lock (recipe step 5) after
any `tools/mcp/package.json` edit.

Both MCP guides are carried forward as-is and are **due a content-staleness audit** (they
track live MCP tool reality / Blender API drift).

**The two files that wait for the freeze.** `.mcp.json` (the stamped `mcp.json`) launches the
godot-mcp server via `node tools/mcp/node_modules/…` (NOT `npx -y`), and `.codex/config.toml` (the
stamped `codex/config.toml`) is the same server for the other host — so both carry
`after_freeze: true`: the plain stamp skips them, and engine step 3's `stamp --after-freeze`, after
this recipe, writes them once step 5's freeze has built the tree they point into.
`.codex/config.toml` needs absolute paths (Codex resolves a relative MCP `cwd` against the launch
directory, not the repo), so its `{{PROJECT_ROOT}}` is derived from `pwd` at the repo root, never
asked, and its entries are `required = false`, so a wrong or unreplaced path fails silently rather
than blocking a session. It is per-clone and machine-local: `host-setup` (engine step 8) keeps it
out of git machine-wide, never the project's `.gitignore`.

### 1. User-level helpers (once per machine, idempotent — independent of this project)

- **`godot-mcp-clean`** — the manifest stamps it to `~/.local/bin/godot-mcp-clean` through
  `host-setup` (engine step 8), which makes it executable; confirm `~/.local/bin` is on PATH
  (`echo $PATH | tr ':' '\n' | grep -q '\.local/bin'`; if not, tell the owner to add
  `export PATH="$HOME/.local/bin:$PATH"` to their shell rc). It encapsulates the single
  legitimate `kill` use case (orphan node MCP servers hogging the editor's single-client
  bridge slot) — which is **why `Bash(kill:*)` stays OFF the allowlist**. **Scope:** it reaps
  ONLY orphaned `node …godot-mcp` servers (not godot-ai's uv server), so it
  is a break-glass helper, low-frequency by design. If a project ever drops godot-mcp entirely
  (godot-ai-only), drop `godot-mcp-clean` AND its `Bash(godot-mcp-clean)` allowlist line together.
- **`godot-gdscript-patterns` skill** (global, idempotent):
  `{ test -d ~/.claude/skills/godot-gdscript-patterns || test -d ~/.agents/skills/godot-gdscript-patterns; } && echo installed || npx -y skills add wshobson/agents@godot-gdscript-patterns -g -y`
  — the `npx` runs as `SKILL.md` § The run, *Under a sandbox*, says.

<!-- precondition -->
### 2. Verify target is a Godot project

`test -f project.godot` — if absent, STOP and ask the owner; the STOP lands with nothing written,
since engine step 0 runs this step before the first write. Do not create a Godot project from
scratch (ask them to run Godot first).

### 3. Install the in-engine addon (version-pinned to the server)

**Skip an addon already at the pin.** From the target root:

```
grep -qx 'version="4.1.0"' addons/godot_mcp/plugin.cfg 2>/dev/null && echo "present at pin" || echo install
```

`present at pin` skips the install, and the run report says so; `install` runs it:

```
npx -y @satelliteoflove/godot-mcp@4.1.0 --install-addon .
```

It runs as `SKILL.md` § The run, *Under a sandbox*, says; a refused install is the stop in that
paragraph's refusal bullet, and the owner's command is the install line above, prefixed `!`.
It copies `addons/godot_mcp/` (the WebSocket bridge the servers connect to). **WHY @4.1.0:**
the addon version must match the server pin in `tools/mcp/package.json` — an addon ↔
server major-version split risks a bridge-protocol mismatch (connection fails / tools misbehave
after `/mcp`). The pin lives in three places — the install line, the skip test and
`profiles/godot/templates/mcp/package.json` (the server pin): bump one → bump all three (the
`--install-addon` flag verified present on 4.1.0's CLI). Then, on either branch — a `plugin.cfg`
at the pin says nothing about `game_bridge/` — **verify both paths step 6 depends on** exist, or
the autoload registration silently references a missing file:

```
test -f addons/godot_mcp/plugin.cfg && \
  test -f addons/godot_mcp/game_bridge/mcp_game_bridge.gd && echo OK || echo "addon incomplete"
```

If either is missing, STOP and surface the error (version mismatch, no `node` on PATH, or the
upstream package restructured the addon layout). The stop halts the recipe — steps 4–6 wait — and
the run resumes at this check once the owner has fixed it.

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
(not recommended — godot-mcp silently no-ops `Rect2`). **Whether to vendor is the owner's.** On a
fresh run the owner is asked here, before 4.1 (recommended: yes), and the answer becomes the
contract's `#godot-ai addon` fill (a tag, or `none`) at engine step 5, which a re-run keeps. On a
re-run nothing is asked: `addons/godot_ai/` present means vendored (skip 4.1, as written there);
absent with the kept fill `none` means the owner declined, so skip 4.1–4.4 (the no-godot-ai branch
below holds); absent with a tag kept means the vendored tree was removed — report it to the owner,
never re-vendor on your own.

1. **Vendor the addon (pinned + TRACKED) — only where `addons/godot_ai/` is absent.** Where
   it is present — an earlier vendoring, by this recipe or by hand — skip 4.1 whatever version it
   holds, and the run report says "present at <plugin.cfg version>": re-copying would overlay a
   source checkout on the tree, which the contract's godot-ai section forbids, and a version bump
   is the owner's separate act, re-read at `audit-godot-parity`. **One tag per machine (the fleet
   pin):** the dock owns one user-scope entry per host (4.4) that every project on the machine
   shares, so read the pin by running 4.4's check now — nothing is vendored yet, so it prints
   `plugin.cfg: none` and exits 1, and the entry versions it prints are the pin. From a clone of
   `hi-godot/godot-ai`, `git checkout v<that>` **before copying**; where both hosts print `none`,
   take the baseline `v3.2.4`; where the two hosts print different versions, stop and tell the
   owner — the fleet is already split. A newer upstream tag
   (`git ls-remote --tags https://github.com/hi-godot/godot-ai`) is a run-report line for the
   owner, never a reason to vendor it here. The clone and the `ls-remote` run as `SKILL.md`
   § The run, *Under a sandbox*, says. Then copy the install-ready `addons/godot_ai/` (at
   `plugin/addons/godot_ai/`, not the repo root; a `src/godot_ai` copy is NOT the one to vendor)
   into the project's `addons/`.
   **WHY the tag is the pin:** the vendored `plugin.cfg` version drives which Python MCP
   server the dock fetches from PyPI via `uvx` (`uv` must be on PATH) — so the checked-out
   tag pins BOTH addon and server, stopping cross-project drift. **Commit the vendored copy;
   do NOT gitignore it.** The addon self-updates in-editor and rewrites `project.godot` and
   `.mcp.json` on its own schedule (gotcha #116): an ignored copy drifts with no git trace
   and the recorded version rots silently (measured on one project: a silent
   2.8.4 → 3.1.3 bump left 23 of 47 recorded godot-ai claims stale). Tracked, the drift
   shows in `git status` and can be pinned by a test that asserts `plugin.cfg` equals the
   version the contract records. The vendored tag is the answer to the contract's
   `#godot-ai addon` fill, where both hosts read it.
2. **Disable telemetry** (ON by default). `GODOT_AI_DISABLE_TELEMETRY` is read at each editor
   launch and persists nowhere: only a truthy value force-disables, and only for an editor started
   from a shell exporting it. The lasting opt-out is the dock's telemetry toggle, the
   EditorSetting `godot_ai/telemetry_enabled`, kept per machine; once it is off, the dock
   re-renders its user-scope entry (4.4) with `--disable-telemetry`. A headless `--import` in this
   recipe neither counts nor needs it: `godot_ai` is not in `[editor_plugins]` until the owner
   enables it at 4.3, so it never loads before then (godot-ai v3.2.4 `telemetry.gd`, header lines
   11–19). Turning the toggle off is an owner-only handoff item (§ 7, item 3).
3. **Enable the plugin** at Project → Project Settings → Plugins after opening the editor — an
   owner-only handoff item (engine step 9).
4. **The MCP client entry is written by the dock, at USER scope — not by this recipe.**
   Since godot-ai 3.2.x the dock configures the client itself: on first enable it writes a
   stdio entry into `~/.claude.json` (`uvx --from godot-ai==<plugin.cfg version> godot-ai
   attach --port 8000 --ws-port 9500`, plus `--disable-telemetry` once the dock's telemetry
   toggle is off — 4.2) and deletes any project-scope
   `godot-ai` block from `.mcp.json` — which is why the stamped `mcp.json` carries none and
   the `settings` delta lists only godot-mcp in `enabled_mcp_servers` (the
   `mcp__godot-ai__*` allow stays; user-scope servers are not gated by
   `enabledMcpjsonServers`). Verify after the first editor launch **and on every re-run** (it is
   a read) — and once at 4.1, before anything is vendored, to read the pin:

   ```
   python3 -c 'import json,os,re,sys;r=lambda p:open(os.path.expanduser(p),encoding="utf-8").read() if os.path.exists(os.path.expanduser(p)) else "";c=" ".join((json.loads(r("~/.claude.json") or "{}").get("mcpServers",{}).get("godot-ai") or {}).get("args",[]));s=re.search(r"(?ms)^\[mcp_servers\.\"?godot-ai\"?\]$(.*?)(?=^\[|\Z)",r("~/.codex/config.toml"));v={h:(re.search(r"godot-ai==([^\s\",]+)",t) or [0,"none"])[1] for h,t in (("claude",c),("codex",s.group(1) if s else ""))};p=(re.search(r"(?m)^version=\"([^\"]+)\"",r("addons/godot_ai/plugin.cfg")) or [0,"none"])[1];print("claude:",v["claude"],"| codex:",v["codex"],"| plugin.cfg:",p);f={x for x in v.values() if x!="none"};sys.exit(0 if f=={p}!={"none"} else 1)'
   ```

   It reads each host's user-scope `godot-ai` entry — Claude Code's `~/.claude.json`, Codex's
   `~/.codex/config.toml`; a missing file reads `none` — and `plugin.cfg`, and exits 0 only when
   every present entry names the `plugin.cfg` version. It exits 1 on a mismatch; on two hosts
   disagreeing (the fleet is already split — the owner's to resolve); on no entry on either host;
   and on no `plugin.cfg`. On a mismatch, this project's vendored tag is not the machine's fleet
   pin: tell the owner, whose remedy is re-running the dock's client setup from the project at the
   tag they choose as the pin — never a hand-edit of either host's config. That remedy applies only
   when `plugin.cfg` and at least one host print a version: an entry reading `none` before the
   owner's first enable (4.3, owner-only) is the handoff item, not a defect — re-run the check after
   the first enable. `plugin.cfg: none` with the kept `#godot-ai addon` fill `none` is the
   no-godot-ai branch, where this check does not run; with a tag kept, the vendored tree is gone —
   report it to the owner as the step 4 intro says, never re-vendor.
   Two consequences: (a) the pin now lives in that user-scope entry — bumping the vendored
   tag without re-running the dock's client setup leaves the client on the old server;
   (b) the entry **hardcodes 8000/9500** while the plugin itself walks ports on collision —
   if the dock moves, re-run its client setup rather than hand-editing `~/.claude.json`.
   The entry is INERT until the plugin is enabled AND the editor is running — a fresh session
   shows godot-ai disconnected in `/mcp`; expected, not a bug. The dock writes the equivalent
   user-scope entry for each host it configures, hardcoding the same ports in each, so a port
   walk strands every host at once — the contract's godot-ai section carries that rule, and
   `.codex/config.toml` lists godot-mcp only, exactly as `.mcp.json` does.

**If NOT using godot-ai**, two things, and skipping either leaves the project documenting or
permitting a server it does not run. (`uv` on PATH is a prerequisite when used — the dock
auto-starts a uv-managed Python server on `:8000` + `:9500`.)

1. **Permissions — in the project's `.claude/settings.local.json`**, the file `stamp` has already
   merged; the `settings` delta in this manifest stays as it is, or every future project loses these
   too. Move the one godot-ai entry, `mcp__godot-ai__*`, from `permissions.allow` to
   `permissions.deny` — deny, not a bare removal, because every re-run's merge adds back a Profile
   entry that deny does not hold. Leave the user-scope `godot-ai` entries alone — each host's
   (Claude Code `~/.claude.json`, Codex `~/.codex/config.toml`) is machine-wide, shared by every
   project on the machine that vendors godot-ai at the fleet pin. The run report names each host's
   entry wherever one exists; removing them from both hosts' configs is the owner's decision, and
   only where no other project on the machine vendors godot-ai.
2. **The contract's fills** take their no-godot-ai branch: `#godot-ai addon` is `none`, and the
   project pins name godot-mcp alone. The fragments' fixed text already reads true without godot-ai
   (godot-mcp as the writer, its `Rect2` hole stated as a hole); **leave the guide's own
   writer/reader matrix alone** — it is a carried-forward reference about the tool stack, not a
   claim about this project.

`.mcp.json` and `.codex/config.toml` are unaffected — neither ever listed godot-ai.

### 5. Lockfile-freeze PAYLOAD (the engine mechanic, godot's package set)

The engine's freeze mechanic (install once → commit the lock, not the modules → gitignore the
tree → the rehydrate command to the run report) runs against THIS payload:

1. `tools/mcp/package.json` is already stamped (pins `@satelliteoflove/godot-mcp@4.1.0`
   exactly — no `^`/`~`).
2. `npm install --prefix tools/mcp --no-audit --no-fund` → writes `tools/mcp/package-lock.json`
   (lockfileVersion 3, sha512 per package) and materializes `tools/mcp/node_modules/`; it runs as
   `SKILL.md` § The run, *Under a sandbox*, says. **Commit the lockfile + package.json, NOT
   `node_modules/`.**
3. Stop Godot import-scanning the tree: create an **empty** `tools/.gdignore`
   (**NOT** `.godotignore` — the wrong name silently does nothing).
4. Ignore `tools/mcp/node_modules/` **and `.godot/`**, each line added only where absent:

   ```sh
   for l in 'tools/mcp/node_modules/' '.godot/'; do
     grep -qxF "$l" .gitignore 2>/dev/null || printf '%s\n' "$l" >> .gitignore
   done
   ```

   `.godot/` is the editor's generated cache: the contract states it is gitignored, and this is the
   only step that makes that true.

**WHY freeze:** `.mcp.json` and `.codex/config.toml` launch the godot-mcp server on *every* session
on their host.
`npx -y <pkg>@<ver>` re-resolves the **unpinned transitive tree** from the registry on each
cold start and runs install lifecycle scripts — a recurring arbitrary-code-execution surface
on the dev machine and on every clone that approves the MCP prompt. Pinning the top-level
version does NOT freeze the transitive tree; launching from a committed lock does. (Distinct
from step 3's `--install-addon`: that is a one-time pinned fetch whose committed result
isn't a recurring runtime exposure.)

### 6. Edit `project.godot`

Read `project.godot` and make three edits (sections are top-level INI-style; Godot
reorders cleanly on next save):

- **Edit A — `[editor_plugins]`.** Add `"res://addons/godot_mcp/plugin.cfg"` to
  `enabled=PackedStringArray(...)`. If the section/key is absent, create it; **always use the
  `PackedStringArray("...")` wrapper even for a single path** (a bare `enabled=res://...` is
  invalid). If the array exists, parse the quoted paths between the parens and add the entry
  only if not already present (exact-string match); preserve existing paths.
- **Edit B — `[autoload]`.** Add `MCPGameBridge="res://addons/godot_mcp/game_bridge/mcp_game_bridge.gd"`
  if not already present; don't disturb other autoloads. No `*` prefix, on purpose: it is the
  value the addon's own `plugin.gd` writes (`_ensure_game_bridge_autoload`, godot-mcp 4.1.0),
  which sets the key only when absent, so the bridge is an autoload with no global singleton name
  and the plugin leaves the line alone.
- **Do NOT hand-write a `[godot_mcp]` section** — Godot auto-writes its default settings
  (`bind_mode`, `port_override`, …) on the first import/editor-open (Edit C below). Your
  hand-edits happen before that; leave that section to be auto-created.
- **Edit C — import to populate the class cache, then re-verify the harness.** Run the `env`
  knob's resolve line with the import `&&`-chained to it:
  ```
  : "${GODOT:?run the env knob resolve line first}" && "$GODOT" --headless --path . --import  # editor-build-only flag; writes .godot/global_script_class_cache.cfg, then quits
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
  authoritative harness verification**, and the harness self-check engine step 5 quotes for this
  Profile. If only an export-template/headless-server Godot is reachable (no `--import`), Edit C
  becomes an owner-only handoff item (opening the editor has the same effect). The import also
  auto-writes the `[godot_mcp]` settings section — expected; leave it.

  **WHY the runner verdicts from output, not `$?`:** headless `--script` exit codes lie — a
  parse failure and a mid-run runtime abort both exit 0, so a bare `godot --script` run can
  look green having run nothing. The runner greps the captured output (summary-line +
  `SCRIPT ERROR` / `Failed to load script` + a perl-alarm timeout) and each test pins
  `const EXPECTED_CHECKS := <N>` so silent truncation becomes a counted failure.

### 7. What this Profile adds to the handoff and the run report

**Owner-only handoff items** (engine step 9 (d)):

1. Open (or restart) the Godot 4.x editor to pick up the new addon + autoload, and confirm the
   `godot_mcp` plugin (and `godot_ai`, if vendored — step 4.3) is enabled at
   Project → Project Settings → Plugins.
2. In Claude Code, `/mcp` to (re)connect the servers to the now-running bridge; verify with
   `mcp__godot-mcp__godot_project addon_status` → `connected: true`. In Codex, `codex mcp list`
   from the repo root must show godot-mcp enabled beside the user-scope godot-ai.
   **Single-client bridge:** the godot-mcp bridge accepts ONE client, on either host — if they hit
   "Another MCP server connected and replaced this one", or a Codex read reports the bridge already
   held, run `godot-mcp-clean` and reconnect from the one session that should hold it.
3. Where godot-ai is vendored, turn off telemetry with the dock's telemetry toggle (the lasting
   opt-out, step 4.2), then re-run the step 4.4 check, which must still exit 0 — the dock re-renders
   its entries on the toggle; the check reads versions, not the telemetry flag, so the toggle's own
   state is read in the dock.

**The adoption commit** (engine step 7) — files the recipe created, each staged by its own path:

- the vendored `addons/godot_mcp/` (step 3) and `addons/godot_ai/` (4.1), each by its directory
  path, which takes exactly the vendored copy — the godot-ai tree ships its own `.uid` files
  upstream;
- the `.uid` sidecars Godot writes beside the stamped `tests/` scripts during Edit C's import,
  staged beside their scripts, since Godot 4.4+ expects each `.uid` committed with its script
  (measured 2026-09-28 on Godot 4.7.2.stable: a headless `--import` wrote `tests/a.gd.uid` and
  `addons/x/b.gd.uid` beside their scripts). A `.uid` beside a file the recipe did not create is
  the owner's.

**Run-report items:**

1. **Fresh-clone rehydrate** (the lockfile-freeze clone gap): `node_modules/` and `.godot/`
   are both gitignored, so a clone must (a) `npm ci --prefix tools/mcp` once
   (integrity-verified against the committed lock) before the godot-mcp tools load,
   (b) import once — open the editor, or `"$GODOT" --headless --path . --import` `&&`-chained
   after the `env` knob's resolve line — or
   `tests/run_tests.sh` false-FAILs `fixture_pass.gd` with `SCRIPT ERROR` (class cache empty).
   A vendored `addons/godot_ai/` is tracked — step 4.1 — so no re-vendor step; but the godot-ai
   MCP client entry is user-scope, so a clone on a NEW machine gets it only after the dock's first
   enable — step 4.4. `.codex/config.toml` is never committed either — the machine-wide git
   excludes that engine step 8 (`host-setup`) writes cover it — so a clone re-creates it from the
   Profile Template (`init-project/profiles/godot/templates/codex/config.toml`, wherever the skill
   is installed), or from the block in `docs/godot-mcp-guide.md` § Host adapters where this
   project's guide carries it, with its own absolute root.
2. If the user-level Claude Code settings don't already allow the godot-mcp tools, the owner may
   get permission prompts — user-level perms are out of scope here (this Profile sets
   project-level perms only). Codex has no such allowlist; its sandbox and approval policy are
   the equivalent, and `AGENTS.md` states the profile this repo expects.
