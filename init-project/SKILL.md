---
name: init-project
description: Scaffold (or migrate) a dev project onto the Chunk library, driven by a declarative project-type Profile. Use when setting up a new dev project, adopting the chunk library in an existing one, or adding a new project type.
---

# init-project — the Chunk-library scaffolding engine

ONE engine, many **Profiles**. The engine is a uniform apply-algorithm; a Profile
(`profiles/<type>.md`) is the *data* for one project type. Adding a project type = adding
a Profile. The engine and `dev-base` bundle are stable; only Profiles grow. (ADR-0003.)

Every Profile emits the same three agent-facing files: one shared **contract** and two thin **host
adapters** over it (ADR-0009). Knob blocks live in the contract, host mechanics live in the
adapters, and neither adapter carries a project rule.

## What a Profile is (the manifest contract)

A Profile is `profiles/<type>.md`: a YAML frontmatter **manifest** + an optional
`## Bespoke setup` recipe. The manifest fields the engine reads:

```yaml
---
type: <name>
imports:            # chunk ids to @import BEYOND dev-base (dev-base is always imported)
  - backlog-core    # e.g.
fork: git-flow-squash      # exactly one git-flow variant. squash is the DEFAULT (ADR-0002);
                           # git-flow-noff is the opt-in. The fork is imported explicitly,
                           # never via dev-base (@import cannot be undone).
templates: []              # parity-tracked Template assets to stamp: [{src, dest, refresh?}]
adapters:                  # optional: this type's fragments for the three engine Templates.
  claude: adapter-claude.md   #   inserted at <!-- profile:claude-mechanics --> in CLAUDE.md
  codex:  adapter-codex.md    #   inserted at <!-- profile:codex-mechanics --> in AGENTS.md
  contract: contract.md       #   inserted at <!-- profile:contract-sections --> in the contract
settings:                  # optional: this type's settings.local.json delta, merged in step 4
  allow: []                #   extra permissions.allow globs (unioned by exact-string dedup)
  enabled_mcp_servers: []  #   added to enabledMcpjsonServers
knobs:                     # per value-variant chunk → the values to write into its knob block
  backlog-core:
    VERSION: "..."
    PLANS_DIR: "..."
    VERIFY_EXAMPLES: "..."
    DoD: ["...", "User sign-off received"]
  verify-gate: { commands: "...", paths: "...", secret_scan: "...", env: "..." }
  dev-practice: { test_roster: "...", spec_verify_src: "..." }
---
## Bespoke setup
<imperative steps the manifest can't express, or "None.">
```

Knob *values* that are project-specific are filled at apply time (prompt the user or derive
from the repo); the manifest carries defaults/shape. Pure-invariant chunks (git-*, codegraph,
code-hygiene, sandbox-auto) have no knob block.

`adapters:` names three files under the Profile's own `templates/`. An absent field, or an absent
key inside it, inserts nothing — the engine deletes that marker line and moves on.

**A fragment is a section, not loose bullets.** It carries its own `##` headings, because it lands
at one marker near the end of the file and loose bullets would read as part of whichever section
happens to sit above the marker. Two placements:

- A heading the engine Template already stubs (`## Working in this repo`, `## Running`)
  **replaces** that stub, in place. That is how a Profile fills a section the engine can only stub.
- Any other heading is **appended** at the marker, as its own section.

Either way a fragment *adds*: it sharpens the engine's generic bullets with this project type's
specifics rather than restating them.

## The engine-owned Templates

`templates/` beside this file holds the three Templates every Profile emits. They are engine-owned:
a Profile customises them through `adapters:` fragments and knob values, never by shipping its own
copy.

| Template | Stamped to | Tokens |
|---|---|---|
| `templates/project-workflow.md` | `docs/agents/project-workflow.md` | `{{PROJECT_NAME}}`, `{{KNOB_BLOCKS}}` |
| `templates/CLAUDE.md` | `CLAUDE.md` | `{{PROJECT_NAME}}`, `{{IMPORT_LINES}}` |
| `templates/AGENTS.md` | `AGENTS.md` | `{{PROJECT_NAME}}`, `{{CHUNK_READ_LIST}}` |

- **`{{PROJECT_NAME}}`** — the project's own name. Asked **once**, reused in all three.
- **`{{KNOB_BLOCKS}}`** — the tagged knob blocks, in `knobs` order (step 1).
- **`{{IMPORT_LINES}}`** — the `@` import block, in the order step 1 fixes.
- **`{{CHUNK_READ_LIST}}`** — the sentence naming the chunk files Codex must read, derived in step 1.
- **`<!-- profile:claude-mechanics -->`, `<!-- profile:codex-mechanics -->`,
  `<!-- profile:contract-sections -->`** — insertion markers for the `adapters:` fragments. Every
  marker is consumed: it is replaced by its fragment, or deleted.

The three Templates also carry `*<Fill at init: …>*` prompts where a value cannot be derived (the
Project blurb, the project's own rules, how to run it). Ask for those and write the answers in;
step 7 fails on any that survive.

## The apply algorithm (uniform — this is `init-scaffold-core`)

Idempotent and re-runnable: every step inventories first and **merges or skips**, never
blind-overwrites. Re-running with an updated Profile updates only what changed.

**0. Preconditions + inventory.** Confirm the chunks symlink exists
(`readlink ~/.claude/chunks` → the skills repo's `chunks/`; if missing, run `bootstrap.sh` /
`bootstrap.ps1`). Inventory the target: `ls CLAUDE.md AGENTS.md docs/agents/project-workflow.md
.claude/settings.local.json` + any paths the Profile's `templates`/recipe touch. For each thing that
exists, plan to merge/skip — not overwrite. **A `CLAUDE.md` that carries knob blocks or project
sections is a pre-contract project: stop and run `## Migrate mode` instead of this algorithm.**

**1. Write the contract and the two adapters.**

- **`docs/agents/project-workflow.md` — the shared project contract.** In this order: the engine's
  header (it states that this is the one contract both adapters read and that host mechanics live in
  the adapters); the **knob blocks**; then the project sections — Project, Working in this repo,
  Running, plus whatever the Profile's contract fragment adds. **For each chunk in `knobs` that is
  actually imported** (it rides dev-base, it's the chosen `fork`, or it's in `imports`), write a
  tagged block `<!-- knobs:<id> -->` … `<!-- /knobs:<id> -->` carrying that chunk's values. On
  re-run, replace *only* the content between the tags (idempotent); insert the block if absent.
  Never write knob values into a chunk file — they live here, and the chunks read them out of this
  file by marker. **A chunk listed in `knobs` but NOT imported** — a CONDITIONAL import, e.g. the
  godot profile's `backlog-core` (imported only for board-driven projects) — gets its knob block
  written by the Profile's conditional recipe step at the moment it adds the import, never by this
  default pass; a board-less project must not be left with a dangling `<!-- knobs:backlog-core -->`
  block. **The engine owns the header and the knob blocks and nothing else here:** it never edits a
  project section it did not write.
- **`CLAUDE.md` — the thin Claude Code adapter.** The import block, in order:
  `@~/.claude/chunks/dev-base.md`, then the `fork` (`@~/.claude/chunks/<fork>.md`), then each
  `imports` entry, then **`@docs/agents/project-workflow.md`** — an `@` import, not a prose pointer,
  so the project rules stay always-loaded. If `CLAUDE.md` exists, merge into the existing import
  block with **exact-line dedup**; never duplicate or reorder hand-placed imports. Below it, one
  section — `## Claude Code mechanics (this host only)` — carrying host mechanics only: the
  `.claude/settings.local.json` baseline pointer, `.mcp.json` as the project-scope MCP file,
  `.claude/agents/` for project-local subagents **where the Profile stamps any** (drop that bullet
  where it stamps none), that skills fire from context on this host, and the `/name` spelling. **No
  knob block and no project rule may remain in this file.**
- **`AGENTS.md` — the Codex adapter.** Derive `{{CHUNK_READ_LIST}}` first: dev-base's seven bundled
  chunks (`git-sync-branch-start`, `git-commit-format`, `git-confirm-destructive`, `sandbox-auto`,
  `parallel-work`, `verify-gate`, `dev-practice`) + the `fork` + each `imports` entry — named as
  files under `~/.codex/chunks/`, counted in the sentence that introduces them. The Template carries
  the rest: the read-these-completely list, the "do not read `dev-base.md` instead" warning and the
  `~/.claude/chunks` → `~/.codex/chunks` resolution rule (ADR-0005), the Skills / MCP / sandbox /
  child-agent sections, and the canary as its last line. **Keep it under 8 KiB before Profile
  fragments**, and see the byte gate in step 7 for the pair that is actually capped.

**2. Enable external @imports (load-bearing — see ADR-0001), and trust the repo on Codex.**
External `@~/.claude/chunks/…` imports require a **one-time, per-project interactive approval**
("trust external includes"). It is granted at first launch (you are present at init), persists
for that project, and is what **headless** runs (`claude -p`, cron) key off too: with the
approval recorded, headless expands the imports; without it, headless leaves the `@…` lines as
raw text and the chunks never load (measured 2026-09-01, both flag values, with and without
`--add-dir ~/.claude/chunks` — `--add-dir` changes nothing either way). The Codex counterpart is the
**directory-trust prompt** on first launch in the project; the user answers it, and the engine never
writes `~/.codex/config.toml`. Both go in the handoff (step 8); the engine does **not** auto-edit
`~/.claude.json` unless the user explicitly opts in.

**3. Stamp Templates.** For each `templates` entry, copy `src` → `dest`, **skip if the dest
exists** unless `refresh: true`. After copying, replace every `{{NAME}}` token with the value
the user supplies for NAME; ask once per distinct token. Two tokens are **derived, never asked**:
`{{PROJECT_ROOT}}` is `pwd` at the repo root at stamp time, and `{{PROJECT_NAME}}` is the answer
step 1 already has. Templates are *copied + parity-tracked* (unlike chunks); their source of truth
is the Profile asset, kept aligned by a parity check, never hand-merged.

**4. Merge `.claude/settings.local.json` (the merge contract from `sandbox-auto`).** Apply the
Profile's `settings` delta (if any): union its `allow` globs into `permissions.allow`, and add
its `enabled_mcp_servers` to `enabledMcpjsonServers`. If the target file is absent, create it
from the sandbox-auto baseline
(`{"permissions":{"defaultMode":"auto"},"sandbox":{"enabled":true}}`) plus that delta. If present: **union `permissions.allow` by strict exact-string
dedup** (do not semantically merge overlapping `Bash(...)` patterns — keep both); set
`enabledMcpjsonServers` as the Profile requires; **preserve every other top-level key**; write
back. Never clobber. Keep destructive/`gh`-write globs OFF the allowlist (`sandbox-auto` hygiene).

**5. Run the Profile's `## Bespoke setup` recipe.** The escape hatch for what a manifest can't
express (a CLI `init`, editing `project.godot`, a pinned tool install). Empty for simple types.

**6. Lockfile-freeze (when the recipe declares pinned installs).** The mechanic lives here; the
*payload* (which packages, which versions) is Profile-leaf. Install once into a local tree,
**commit the lockfile, not the modules**, gitignore the module tree (append with exact-string
dedup), and record the fresh-clone rehydrate command in the handoff. (Currently only the godot
Profile needs this; promote nothing until a second type does.)

**7. Verify-after-write.** Re-inventory the expected outputs; confirm the three emitted files exist;
confirm each `@import` path resolves through the symlink; confirm no stamped file still carries a
`{{` token, an unconsumed `<!-- profile:… -->` marker, or a surviving `*<Fill at init:` prompt; if
the Profile sets a `verify-gate`, run it. Then two measurements:

- **The byte gate (it FAILS the stamp).** `wc -c AGENTS.md ~/.codex/AGENTS.md`; the two figures
  summed must be **≤ 32,768**. Over that, report both figures and **stop** — do not trim silently, and
  do not report the stamp as done. Codex's `project_doc_max_bytes` cap governs exactly this
  auto-loaded pair, and a chain over it is truncated with no error.
- **The chunk total (recorded, never gated).** `wc -c` over the chunk files `AGENTS.md` names, summed.
  Those are tool-read on demand, outside the cap; the figure belongs in the handoff so a later reader
  knows what the adapter costs when it is followed.

Surface any gap; do not report success without the inventory passing (the `verify-gate` discipline).

**8. Handoff.** Tell the user: (a) on first launch in Claude Code, **approve the external-includes
prompt once**, then restart so the imports load; (b) that same approval is what makes headless runs
expand the imports; (c) on first launch in Codex, **answer the directory-trust prompt** — the Codex
counterpart of that approval; (d) `.codex/config.toml` is ignored machine-wide by
`**/.codex/config.toml` in `~/.config/git/ignore`. Check it with
`git check-ignore -q .codex/config.toml`; if it is **not** ignored, tell the user to add that line
there. The engine does not touch the project's `.gitignore` for it — the file is per-clone and
machine-local, and one line in the machine-wide ignore covers every project; (e) **both hosts need a
new session after an MCP or settings change** — nothing re-reads either mid-session; (f) any
fresh-clone rehydrate command from step 6; (g) step 7's figures — the two halves of the auto-loaded
pair and the chunk total; (h) anything the Profile recipe defers to an interactive editor step.

## Migrate mode

For a project already on the Chunk library whose `CLAUDE.md` was written by the previous engine —
Zone 1 imports, knob blocks inline, project sections below them. It moves what belongs in the
contract into the contract and leaves an adapter behind. It **moves prose; it never authors any**.

**1. Refuse what this is not for.** If `CLAUDE.md` carries no `@~/.claude/chunks/dev-base.md` line,
this is not a chunk-library project: say so and stop — the right tool is init, not migrate.

**2. Require every knob block that should exist.** For each value-variant chunk the file imports —
`verify-gate`, `dev-practice` and `parallel-work` (they ride dev-base), plus `backlog-core` where it
is imported — its `<!-- knobs:<id> -->` block must be present. If one is missing, **refuse and name
it**. Never synthesise a knob value: the values are measured facts about that project, and a guessed
gate command is worse than no migration.

**3. Move the knob blocks verbatim** into the new `docs/agents/project-workflow.md`, under the
engine's header, in the order they appeared.

**4. Move every project section verbatim** into the contract, after the knob blocks — same order,
demoting nothing and rewriting nothing, with exactly two exceptions:

- **Claude-only host mechanics move to the adapter instead**: the `.claude/settings.local.json`
  baseline, `.mcp.json`, `.claude/agents/`, the `/name` spelling, and any "skills auto-load here"
  claim. They belong in `## Claude Code mechanics (this host only)`, not in a shared contract.
- **A `~/.claude/skills/<skill>/scripts/…` path inside a knob value is host-specific** — it resolves
  on one host and silently misses on the other. Do not rewrite it: **report it** as a value the user
  must replace with a host-neutral entry point. (The godot Profile's replacement is
  `tools/agent/godot-gotchas-scan.sh`.)

**5. Rewrite `CLAUDE.md` as the thin adapter** — the same import lines it already had, plus
`@docs/agents/project-workflow.md`, then the mechanics section holding what step 4 moved into it.

**6. Emit `AGENTS.md`** exactly as init step 1 does, from the imports the file already carries.

**7. Run verify-after-write** (step 7 above), byte gate included.

**8. Hand off with the ledger:** every line moved and where it went, and every line flagged for the
user to replace. A reader who disagrees with a move needs to see it, not diff for it.

**Migrate is idempotent.** A second run finds `docs/agents/project-workflow.md` already there and a
`CLAUDE.md` with no knob blocks left to move, and changes nothing.

## Profiles

- `profiles/backlog.md` — a board-driven dev project (dev-base + git-flow fork + backlog-core).
- `profiles/web.md` — a web project; carries the npm-shaped toolchain gate and leaves the
  app directory, the secrets location and the task-branch convention as values to answer.
- `profiles/godot.md` — a Godot project; carries the heavy bespoke recipe (MCP install,
  `project.godot` edits, lockfile-freeze) and owns its Template assets.

## Extensibility

New project type → add `profiles/<type>.md` (+ its `adapters:` fragments where the type has host
specifics). New cross-cutting rule → add `chunks/<name>.md` (+ `dev-base.md` if universal).
