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
  verify-gate:             # one key per step of the chunk's invariant sequence, in this order
    dir: "..."             #   the directory the gate runs in
    typecheck: "..."
    test: "..."
    build: "..."
    build_check: "..."     #   the build's own artifact assertion — exit 0 alone is not the check
    smoke: "..."
    secret_scan: "..."
    env: "..."
  dev-practice: { test_roster: "...", spec_verify_src: "..." }
---
## Bespoke setup
<imperative steps the manifest can't express, or "None.">
```

Knob *values* that are project-specific are filled at apply time (prompt the user or derive
from the repo); the manifest carries defaults/shape. Pure-invariant chunks (git-*, codegraph,
code-hygiene, sandbox-auto) have no knob block. The `verify-gate` keys are the same eight in every
Profile — the chunk's sequence is invariant, so a Profile varies the commands, never the key set;
a step a project genuinely has no command for says so in its value rather than going missing.

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
  default pass, and at the position the Profile's `knobs` order gives it; a board-less project must
  not be left with a dangling `<!-- knobs:backlog-core -->` block. **The engine owns the header and
  the knob blocks and nothing else here:** it never edits a project section it did not write.

  **The inner shape of a knob block is fixed**, because a chunk reads it by marker out of a file it
  never sees whole: **one bullet per key, `- <key>: <value>`, keys in the Profile's order, no
  heading and no nesting between the markers.** A multi-item value (a DoD list) is a numbered list
  indented under its bullet. So:

  ```
  <!-- knobs:dev-practice -->
  - test-roster: the project board, falling back to the design docs under `docs/`.
  - spec-verify src: the project's own source tree.
  <!-- /knobs:dev-practice -->
  ```
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
  `parallel-work`, `verify-gate`, `dev-practice`) + the `fork` + each `imports` entry. It expands
  into **item 3 of the read list**, not a free-standing sentence, and it carries the count so a
  reader can tell a short read from a complete one:
  `These nine files under ~/.codex/chunks/ (the dev-process rules, shared with the other host):`
  then the file names with their `.md` suffixes. The Template carries
  the rest: the read-these-completely list, the "do not read `dev-base.md` instead" warning and the
  `~/.claude/chunks` → `~/.codex/chunks` resolution rule (ADR-0005), the Skills / MCP / sandbox /
  child-agent sections, and the canary as its last line. **Keep it under 8 KiB before Profile
  fragments**, and see the byte gate in step 7 for the pair that is actually capped.

  **The canary is the truncation signal.** A fresh Codex session that cannot quote the last line did
  not receive the whole file — the auto-loaded pair is over the cap, or the file never loaded at all
  — so it is the one check that distinguishes "read and ignored" from "never arrived". The `v1` in
  it names the adapter Template's *shape*; bump it only when that shape changes, never per project.

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
is the Profile asset, kept aligned by a parity check, never hand-merged. **Leave behind any
`templates` entry whose comment says it waits for the lockfile-freeze** — the recipe stamps those
itself, after the freeze, because they point into a tree that does not exist yet at this step.

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
Profile needs this; promote nothing until a second type does.) **This is a mechanic, not a position
in the sequence:** it runs where the recipe puts it — the godot recipe calls it at its own step 5,
before the two MCP adapter files that launch out of the frozen tree — so read the recipe for the
order and this step for what the freeze does.

**7. Verify-after-write.** Re-inventory the expected outputs; confirm the three emitted files exist;
confirm each `@import` path resolves through the symlink; confirm no stamped file still carries a
`{{` token, an unconsumed `<!-- profile:… -->` marker, or a surviving `*<Fill at init:` prompt; if
the Profile sets a `verify-gate`, run it.

**Two verdicts a scaffold produces that are neither pass nor fail**, and both have been read as a
pass: a **gate step that hangs** — no exit, banner only — is a **stamp failure**; kill it, report
the command and that it did not return, and fix the knob rather than recording the step as green.
And on day zero a project has no tests, so the test step prints `no tests match` or its equivalent:
that is an empty run, not a green one. The scaffold's real test verdict is the harness's own
self-check (for the godot Profile, `tests/run_tests.sh --selftest` ending
`selftest: 8/8 verdicts correct`) — quote that, and say the suite was empty.

Then two measurements:

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
counterpart of that approval; (d) **the two per-clone host config files are ignored machine-wide,
and the engine writes neither ignore.** Check both —
`git check-ignore -q .codex/config.toml` and `git check-ignore -q .claude/settings.local.json` — and
for each that comes back unignored, tell the user the line to add to `~/.config/git/ignore`:
`**/.codex/config.toml` and `**/.claude/settings.local.json`. Not the project's `.gitignore`: both
files are per-clone and machine-local, and one line each in the machine-wide ignore covers every
project; (e) **both hosts need a
new session after an MCP or settings change** — nothing re-reads either mid-session; (f) any
fresh-clone rehydrate command from step 6; (g) step 7's figures — the two halves of the auto-loaded
pair and the chunk total; (h) anything the Profile recipe defers to an interactive editor step.

## Migrate mode

For a project already on the Chunk library whose `CLAUDE.md` was written by the previous engine: the
chunk imports, the knob blocks inline below them, and the project's own rules below those. It moves
what belongs in the contract into the contract and leaves an adapter behind. It **moves prose; it
never authors any**, and it **never rewrites a line to fix it** — a line that needs fixing is
flagged for the user.

**0. Stop if it is already migrated.** If `docs/agents/project-workflow.md` exists *and* `CLAUDE.md`
carries no `<!-- knobs:` marker, report "already migrated, nothing to move" and stop. Only past this
check does step 2's refusal mean anything: a migrated project has no knob blocks in `CLAUDE.md` by
design, and refusing it for that would make migrate fail on its own output.

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
same prose.

- **The unit of movement is a whole bullet or a whole paragraph**, never a sentence cut out of one.
  A paragraph that mixes host mechanics with a project rule is not split: it **stays in the
  contract** and is flagged for the user to split by hand.
- **The only structural change is promotion.** A wrapper heading (`## Project-specific
  (inline-leaf)` and the like) disappears and its children rise one level to `##`, because they are
  now top-level sections of a file of their own. Nothing is demoted and nothing is reworded.
- **A moved section replaces an engine stub when its heading begins with the stub's text.** So
  `## Working in this repo — Godot domain & MCP workflow` replaces the `## Working in this repo`
  stub, keeping the project's fuller heading; likewise `## Running`.
- **Whole bullets that are only host mechanics move to the adapter instead**: the
  `.claude/settings.local.json` baseline, `.mcp.json`, `.claude/agents/`, the `/name` spelling, and
  any "skills auto-load here" claim. They belong in `## Claude Code mechanics (this host only)`, not
  in a shared contract.

**Flag, never rewrite.** Three classes, each reported in step 8's ledger with its file and its
line, and left exactly as it was:

- Any line still in the contract that names a host or a host path — `Claude Code`, `.claude/`,
  `~/.claude`, `.mcp.json`, `~/.claude.json`, or the Codex equivalents (`Codex`, `.codex/`,
  `~/.codex`). Whether it is host mechanics or a project rule that happens to mention one is a
  judgement the user makes.
- Any `~/.claude/skills/<skill>/scripts/…` path inside a knob value: it resolves on one host and
  silently misses on the other, so the user replaces it with a host-neutral entry point in the repo.
- Any cross-reference to a heading whose level the promotion changed (`see **### Running**` when
  `Running` is now `##`).

**5. Rewrite `CLAUDE.md` as the thin adapter** — the header and mechanics section from
`templates/CLAUDE.md`, the import-block comment and import lines the file already had (the comment
is the project's own record of why each import is there: keep it) plus
`@docs/agents/project-workflow.md`, and, folded into that mechanics section, whatever step 4 moved
out of the contract. Where a moved line and a Template bullet cover the same ground, **keep the
project's wording and append whatever fact the Template bullet carries that the project's line
lacks** — the project line is the more specific, but dropping the Template's is how the migration
loses content nobody notices missing.

**6. Emit `AGENTS.md`** as init step 1 does, from the imports the file already carries — including
the Profile's **`codex` adapter fragment**, which is host mechanics this project has never had and
cannot have written down. Same for the `claude` fragment in step 5. **Do not insert the `contract`
fragment**: the project already has its own prose for those sections, and this mode moves prose
rather than replacing it. Instead, for each contract-fragment section whose heading matches one the
migration moved, list it in the ledger as "the Profile's current wording for this section; adopt by
hand if you want it". A migrated project whose Profile has a `codex` fragment must not come out with
an `AGENTS.md` that says nothing about that project type.

**7. Run verify-after-write** (step 7 above), byte gate included.

**8. Hand off with the ledger and the init handoff.** The ledger: every line moved and where it went,
every line flagged and why, and every contract-fragment section offered for hand-adoption. A reader
who disagrees with a move needs to see it, not diff for it. Then init step 8's items (a), (b), (c)
and (e) — the external-includes approval, what it does for headless runs, the Codex directory-trust
prompt, and the new-session rule — plus the byte figures from step 7. A migrated project is a first
launch on the second host, so none of those has been answered yet.

## Profiles

- `profiles/backlog.md` — a board-driven dev project (dev-base + git-flow fork + backlog-core).
- `profiles/web.md` — a web project; carries the npm-shaped toolchain gate and leaves the
  app directory, the secrets location and the task-branch convention as values to answer.
- `profiles/godot.md` — a Godot project; carries the heavy bespoke recipe (MCP install,
  `project.godot` edits, lockfile-freeze) and owns its Template assets.

## Extensibility

New project type → add `profiles/<type>.md` (+ its `adapters:` fragments where the type has host
specifics). New cross-cutting rule → add `chunks/<name>.md` (+ `dev-base.md` if universal).
