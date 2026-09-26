## Working in this repo

- **For the project's domain vocabulary, read `CONTEXT.md` (repo root) first, once the project has
  one** — the pinned glossary (term → what-it-IS + `_Avoid_` synonyms); use these exact terms for
  naming stability. The `godot-architecture-review` skill produces and maintains it, so a project
  that has not run that skill yet has no glossary to read. `docs/agents/domain.md` is the short
  pointer to it and to `docs/adr/`.
- **For any work involving the Godot MCP tools, read `docs/godot-mcp-guide.md` first.** Division of
  labour: **godot-ai = primary WRITER** where the project vendors it (§ godot-ai addon) —
  scene/node/script/property creation, `project_run`, `editor_screenshot`, `logs_read`;
  **godot-mcp = READ/TEST complement** (`godot_input`, `godot_runtime_state`, `godot_docs`,
  `godot_editor get_log_messages` — **no `source` arg, it is a phantom and silently stripped**;
  editor-only filtering is godot-ai `logs_read source="editor"`); **minimal-godot = local
  diagnostics** (`get_diagnostics`). godot-mcp silently no-ops `Rect2`: with godot-ai vendored, never
  write through godot-mcp; without it, godot-mcp is the writer and that no-op is a known gap — a
  `Rect2` is hand-edited in the `.tscn`/`.tres` and re-verified, and the guide's godot-ai-as-writer
  matrix does not describe this project. **One writer per editor instance**. **Project pins:**
  *<Fill at init: the godot-mcp version pinned in `tools/mcp/package.json` — addon and server are
  bumped together — and, where the project vendors godot-ai, its version, which is the tag vendored
  below. A project that skips godot-ai names godot-mcp alone here.>*
- **MCP servers connect at session start.** After any MCP config change, start a new session — your
  host adapter says which files hold that config and how a new session is started. The tool-name
  prefix a host shows you is a host detail; the roles above are not.
- **Four Godot skills, read when you touch the work they cover** — `godot-gdscript-patterns`
  (GDScript), `godot-animation-tree-mastery` (AnimationTree), `godot-gotchas` (engine/editor quirks —
  the single source for *universal* ones; `docs/godot-gotchas.md` holds only *project-local* ones),
  `godot-personal-preferences` (workflow rules — read at session start). Read each **where it is
  installed** — its directory exists under `~/.claude/skills` (Claude Code) or `~/.agents/skills`
  (Codex); the two hosts resolve skills through different roots, so a check against one root skips
  the read for everyone on the other. Where one is absent, skip that read and fall back to
  `docs/godot-gotchas.md` and this contract — never fail on it. Read them when touching `.gd` /
  `.tscn` / AnimationTree work whether or not your host fires them from context on its own; your
  adapter says which of the two it is here.
- **Invoke by name, always explicitly:** `godot-architecture-review` for architecture/refactor work
  (leaves `CONTEXT.md`, `docs/adr/`, `docs/architecture/system-map.md`); `audit-godot-parity` for
  periodic project↔skill parity audits.
- Hand-edit atomic scene (`.tscn`) / resource (`.tres`) changes with a read-back; use the editor for
  structural changes and `Transform3D` bases, per `godot-personal-preferences`. Typed arrays
  serialize as `Array[X]([...])`.
- `.godot/` is the editor's generated cache and is gitignored — never edit it directly; regenerate by
  opening the project in the editor.

## Blender pipeline

*<Fill at init: with a Blender source, the reading rule — before any Blender MCP work read
`docs/blender-mcp-guide.md` (schema inconsistencies such as `name` vs `object_name` and a
basename-only `output_path`, the data-API-over-`bpy.ops` rule, depsgraph staleness on derived
reads, edit-mode bmesh discipline, the `glTF Material Output` node group for AO, Blender 5.x API
drift), and for the pipeline's shape `docs/asset-pipeline.md` (the directory layout, the naming
discipline that leaks from Blender into Godot, what crosses the boundary). With none, one line
saying the project has no Blender source, so neither doc is stamped or looked for.>*

## godot-ai addon

**Vendored tag:** *<Fill at init: the `hi-godot/godot-ai` tag checked out before vendoring — or,
where the project does not vendor godot-ai, `none`, and the rest of this section does not apply.>*

Where vendored, `addons/godot_ai` is a copy of upstream `hi-godot/godot-ai` at that tag, **committed
to git** — that tag pins both the addon and the Python MCP server the dock fetches from PyPI.

**The dock registers each MCP client itself, at USER scope**, writing a generated `godot-ai attach`
stdio entry into that host's own config — **your adapter names yours** — and deleting any
project-scope `godot-ai` entry. **Ports are RESOLVED, not fixed:** the plugin walks them on
collision, so one walk strands every host at once. **Apply a port fix to every host's user-scope
config**, by re-running the dock's client setup where it can write that file and by hand where it
cannot. Never hardcode `8000`/`9500` in a probe or a kill recipe — a stale port can mislead a check
into killing an unrelated process. Telemetry is ON by default: set `GODOT_AI_DISABLE_TELEMETRY=true`
before first launch.

**The addon updates itself in-editor** — one button in the dock rewrites the whole tree, and it
rewrites `project.godot` and `.mcp.json` on its own schedule (gotcha #116). That is why it is
tracked, not ignored: the update lands as a diff you accept deliberately
(`chore(mcp): vendor godot-ai X.Y.Z`), bumping the version above in the same commit, and
**no project gate reads `addons/`** — the gotcha scan and `secret_scan` both exclude it — so
`git status` is the only thing that announces it. **Do not hand-verify the release**: the addon
authenticates the signed manifest, the archive inventory and a post-restart tree hash against the
key in the *running* plugin (`utils/release_verifier.gd`). The one path that skips all of it is
overlaying a source checkout on the tree, so never do that.

## Running

Open the project in the Godot editor and press F5. From the CLI, `godot --path .` runs the main scene
defined in `project.godot` (`tests/run_tests.sh` finds the binary on its own via the `GODOT` env var
→ macOS app path → PATH).

**Run the headless test suite with `tests/run_tests.sh`** (subset by pattern:
`tests/run_tests.sh <pattern>`; `--selftest` verifies the runner's own verdicts against
`tests/fixtures/` — must end `selftest: 8/8 verdicts correct`). It needs no sandbox bypass on either
host: its captures go under `$TMPDIR`, not `/tmp`. Never trust `$?` from a raw `godot --script` test
run — exit codes lie on parse failure and mid-run abort; the runner + the shared base
`tests/scene_tree_test.gd` (required `EXPECTED_CHECKS` pin) exist to make verdicts truthful.

**Gotcha pre-commit scan:** `tools/agent/godot-gotchas-scan.sh`, the host-neutral entry point — give
it a scope (`--all`, or the scan's own diff arguments for a change), and read its `VERDICT:` line,
never `$?`. With no scope on a clean tree it prints `VERDICT: VACUOUS`, which is not a pass.

**Fresh-clone rehydrate:** `npm ci --prefix tools/mcp`, then import once
(`godot --headless --path . --import` or open the editor) so the global class cache exists —
otherwise `tests/run_tests.sh` false-FAILs `fixture_pass.gd`. A vendored `addons/godot_ai` is
tracked, so there is no re-vendor step. Your host's project-scope MCP config may be a gitignored
file you have to re-create as well; your host adapter names it, and the session-start rule above
then applies.
