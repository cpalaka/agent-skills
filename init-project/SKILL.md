---
name: init-project
description: Scaffold (or migrate) a dev project onto the Chunk library, driven by a declarative project-type Profile. Use when setting up a new dev project, adopting the chunk library in an existing one, adding a new project type, or when a workflow skill falls back to writing local ticket files because the project declares no tracker.
---

# init-project — the Chunk-library scaffolding engine

**ONE engine, many Profiles.** The engine is a uniform apply-algorithm; a **Profile**
(`profiles/<type>.md`) is the *data* for one project type. A new project type is a new Profile; a
new cross-cutting rule is a new `chunks/<name>.md` (plus `dev-base.md` where it is universal). The
engine and the `dev-base` bundle are stable; only Profiles grow. (ADR 0003.)

**Every Profile emits the same four agent-facing files:** one shared **contract**, two thin **host
adapters** over it (ADR 0009), and the project's **gate-runner seat** at
`.claude/agents/gate-runner.md`, which re-runs the verify gate for a coordinator that did not write
the diff (ADR 0011). Knob blocks live in the contract, host mechanics live in the adapters, and
neither adapter carries a project rule.

## What a Profile is (the manifest contract)

A Profile is `profiles/<type>.md`: a YAML frontmatter **manifest** + an optional
`## Bespoke setup` recipe. The manifest fields the engine reads:

```yaml
---
type: <name>
imports:            # chunk ids to @import BEYOND dev-base (dev-base is always imported)
  - backlog-core    # e.g.
fork: git-flow-squash      # exactly one git-flow variant, and squash is the only one today
                           # (ADR 0002, ADR 0013). The key names the integration model the project
                           # selects, so a merge-commit variant can still arrive later. It is NOT
                           # imported: the fork is a Skill, emitted into BOTH adapters' skill
                           # lists — `/git-flow-squash` on Claude, `$git-flow-squash` on Codex.
templates: []              # Template assets to stamp: [{src, dest, refresh?}]
adapters:                  # optional: this type's fragments for the four engine Templates.
  claude: adapter-claude.md   #   inserted at <!-- profile:claude-mechanics --> in CLAUDE.md
  codex:  adapter-codex.md    #   inserted at <!-- profile:codex-mechanics --> in AGENTS.md
  contract: contract.md       #   inserted at <!-- profile:contract-sections --> in the contract
  gate_runner: adapter-gate-runner.md   # inserted at <!-- profile:gate-runner-mechanics --> in the gate-runner starter
settings:                  # optional: this type's settings.local.json delta, merged in step 4
  allow: []                #   extra permissions.allow globs
  enabled_mcp_servers: []  #   added to enabledMcpjsonServers
knobs:                     # per value-variant chunk → the values to write into its knob block
  backlog-core:
    VERSION: "..."
    PLANS_DIR: "..."
    VERIFY_EXAMPLES: "..."
    DoD: ["...", "User sign-off received"]
  verify-gate:             # the five steps plus the three read alongside them, in this order
    dir: "..."             #   the directory the gate runs in
    typecheck: "..."
    test: "..."
    build: "..."
    build_check: "..."     #   the build's own artifact assertion — exit 0 alone is not the check
    smoke: "..."
    secret_scan: "..."
    env: "..."
  parallel-work: { worktree_path_prefix: "...", install: "..." }
---
## Bespoke setup
<imperative steps the manifest can't express, or "None.">
```

**The manifest carries shape; the project carries values.** A project-specific knob value is filled
at apply time — prompt the user, or derive it from the repo. Pure-invariant chunks (`git-*`) have
no knob block, and no `fork` declares one today. **The `verify-gate` key set is the same eight in every
Profile** — five for the chunk's invariant sequence, three (`dir`, `build_check`, `env`) for what it
reads alongside them — so a Profile varies the commands, never the keys; a step the project has no
command for says so in its value rather than going missing.

`adapters:` names four files under the Profile's own `templates/`. **Every `<!-- profile:… -->`
marker is consumed** — replaced by its fragment, or deleted where the field or the key is absent.

**A fragment is a section, not loose bullets.** It carries its own `##` headings, because it lands
at one marker near the end of the file, where loose bullets would read as part of whatever section
sits above it. Two placements:

- A heading the engine Template already stubs (`## Working in this repo`, `## Running`)
  **replaces** that stub, in place.
- Any other heading is **appended** at the marker, as its own section.

Either way a fragment *adds* — it sharpens the engine's generic bullets with this type's specifics
rather than restating them.

**The gate-runner starter has no stub heading**, so a `gate_runner` fragment always appends.
`## Project gates` is the project's to fill, never a stub a fragment may replace — and because the
replace rule is a prefix match, a fragment heading that prefix-matches a starter heading swallows
the starter's own section: a Profile bug.

**A bullet may declare what it presupposes.** One HTML comment on the line above it,
`<!-- requires: <target>[; <target>…] -->`, names what must already exist for the bullet to be
true. It may sit above a fragment bullet or an engine Template bullet; the check treats both alike.
Four target families, and no others:

- `<path>` — the file or directory exists. `tests/run_tests.sh`, `.claude/agents`
- `<path> § <Heading text>` — a `##`/`###` heading in that file whose text **begins with** the given
  text. That is **the prefix rule**, and stub replacement uses it too: `§ godot-ai addon` is met by
  `## godot-ai addon (vendored, TRACKED)`. `docs/godot-mcp-guide.md § Host adapters`
- `contract § <Heading text>` / `contract names <a>, <b>, …` / `contract knob <key> names <token>` /
  `contract states: <claim>` — four members: the emitted contract has that heading (same prefix
  rule) / names every one of those **as a skill name** — a doc path that happens to carry the name,
  `docs/godot-gotchas.md`, does not count / the `<key>:` value in one of its knob blocks contains
  that token, where a combined or bolded key line such as `- **typecheck / test / build:**` counts as
  each key it lists / the claim holds of the contract. `contract knob build names godot-export-verifier`
- `<path> states: <claim>` — read the file; the claim holds. For a fact about a file the engine did
  not write, such as a preserved `.mcp.json`. `.mcp.json states: no godot-ai entry`

A `states:` claim is decided by reading the file and asking whether it *behaves* as claimed, never
by string match; a missing file fails the form; a claim may not contain `;`, which separates targets.

**A `## Bespoke setup` section may declare itself a precondition.** One HTML comment on the line
above its heading, `<!-- precondition -->`, moves that section out of step 5 and into **step 0**,
before anything is written. It is the recipe's second marker, unrelated to `<!-- requires: -->`
above, and step 0 states its rule and its grep.

The comment is the Profile's and is never emitted: **every mode strips it on insertion.** A bullet
with no comment presupposes nothing and is always inserted. Init inserts every bullet (step 1); the
check that reads the comments is Migrate mode's **fragment target check** (its step 6).

## The engine-owned Templates

`templates/` beside this file holds the four Templates every Profile emits. They are engine-owned:
a Profile customises them through `adapters:` fragments and knob values, never by shipping its own
copy.

| Template | Stamped to | Tokens |
|---|---|---|
| `templates/project-workflow.md` | `docs/agents/project-workflow.md` | `{{PROJECT_NAME}}`, `{{KNOB_BLOCKS}}` |
| `templates/CLAUDE.md` | `CLAUDE.md` | `{{PROJECT_NAME}}`, `{{IMPORT_LINES}}` |
| `templates/AGENTS.md` | `AGENTS.md` | `{{PROJECT_NAME}}`, `{{CHUNK_READ_LIST}}` |
| `templates/gate-runner.md` | `.claude/agents/gate-runner.md` | `{{PROJECT_NAME}}` |

- **`{{PROJECT_NAME}}`** — the project's own name. Asked **once**, reused in all four.
- **`{{KNOB_BLOCKS}}`**, **`{{IMPORT_LINES}}`**, **`{{CHUNK_READ_LIST}}`** — derived in step 1: the
  tagged knob blocks in `knobs` order, the `@` import block in the order step 1 fixes, and the
  sentence naming the chunk files Codex must read.

The emitted files also carry `*<Fill at init: …>*` prompts where a value cannot be derived (the
Project blurb, the project's own rules, how to run it). Ask for those and write the answers in;
step 7 fails on any that survive.

## The apply algorithm

Idempotent and re-runnable: **every step inventories first and merges or skips, never
blind-overwrites**, so a re-run against an updated Profile touches only what changed.

**0. Preconditions + inventory.** Confirm **both** chunk symlinks — `readlink ~/.claude/chunks` and
`readlink ~/.codex/chunks`, each → the skills repo's `chunks/`; if either is missing, run
`bootstrap.sh` / `bootstrap.ps1`, which creates the pair. **Both, on either host:** a stamp emits
`CLAUDE.md` naming `~/.claude/chunks/…` and `AGENTS.md` naming `~/.codex/chunks/…` whichever host
you are running on, so checking only the one your own host reads leaves the other adapter pointing
at nothing, with no error at stamp time and none at the other host's next launch. Then inventory the
target — `ls CLAUDE.md AGENTS.md docs/agents/project-workflow.md .claude/agents/gate-runner.md
.claude/settings.local.json`, plus any path the Profile's `templates`/recipe touches — and for each
thing that exists, plan to merge or skip. **A `CLAUDE.md` that carries knob blocks or project
sections is a pre-contract project: stop and run `## Migrate mode` instead of this algorithm.**

**A Profile's recipe may declare a precondition step, and it runs here**, before step 1 writes
anything. The engine fixes the position; the recipe says only what the step checks and what happens
when the check fails. **This is the inverse of step 6's freeze**, which runs where the recipe puts
it — a precondition's place is not the recipe's to choose, because **no step in this algorithm
removes a line it wrote**, so a check whose failure should stop the stamp is worth nothing once the
first write has landed.

**A precondition is declared by a marker, never by how its heading is worded.** The line
`<!-- precondition -->` immediately above a `##`/`###` heading in `## Bespoke setup` makes that
section one; a section without the marker is an ordinary recipe step and runs at step 5, however its
heading reads. **Read the set off a command, not off the recipe's intent** — a prose heading that
merely *says* it runs early is the failure this marker exists to prevent, reading as a precondition
to a careful reader and as an ordinary step to a literal one:

```sh
grep -A1 '^<!-- precondition -->$' profiles/<type>.md | grep '^#'
```

**The adjacency is the whole check**, so do not use a bare `grep -c` for the marker: a Profile that
*mentions* the marker in its own prose matches that and is not thereby declaring anything. The
marker is the Profile's and is never emitted.

**1. Write the contract, the two adapters and the gate seat.** Fragments go in whole — init writes
the targets a `<!-- requires: -->` comment names, so the fragment target check does not run here.

- **`docs/agents/project-workflow.md` — the shared project contract.** Order: the engine's header,
  the **knob blocks**, then the project sections. **More than one fragment can write into
  `<!-- profile:contract-sections -->`, so the section order is fixed:** the engine's own stubs
  (Project, Working in this repo, Running — each replaced in place where a fragment supplies it),
  then the type Profile's contract fragment, then any conditional fragment a recipe step inserts
  later, which is why the board's `## Board` section lands last. **A fragment section that is not a
  stub replacement keeps its position in its own fragment's order**: a fragment running Working in
  this repo → godot-ai addon → Running emits the addon section between those two, not after both.

  **Write a tagged block `<!-- knobs:<id> -->` … `<!-- /knobs:<id> -->` for each id in `knobs` that
  is either actually imported** (it rides dev-base, or it is in `imports`) **or read by marker by a
  Skill — today `parallel-work` and `implement-run`, which are Skills no project imports and which
  read their block out of this contract exactly as the Chunks did (ADR 0014 § decision 2).**
  Today's `fork` is neither — `git-flow-squash` declares no knobs — so it gets no block; a later
  one that reads a block by marker qualifies under that second limb like any other Skill, and the
  test decides it, not the key it arrived under.
  On re-run, replace *only* the content between the tags, and insert the block if absent. **Delete,
  tags and all, any `<!-- knobs:<id> -->` block whose id the Profile's `knobs` no longer lists at
  all** — a chunk the library has retired, which a re-run would otherwise preserve forever (ADR 0014
  § decision 3). Absence from `knobs` is the whole test, so this never touches a block the Profile
  still declares, including a conditional one: that one's presence is the recipe step's call, below.
  **The values inside an existing block are this project's own answers, not the manifest's:** a
  re-run keeps them and fills from the manifest only an absent block. What it does change between
  existing tags is the key set — a key the Profile has added or renamed since the last stamp is
  added or renamed in place, its value answered from the project as at apply time. **Never write
  knob values into a chunk file**: they live here, and the chunks and Skills read them out by
  marker. **A chunk listed in `knobs` whose import is CONDITIONAL** — e.g. the godot Profile's
  `backlog-core` — gets its block from the Profile's conditional recipe step at the moment that
  step adds the import, at the position the Profile's `knobs` order gives it, never from this
  default pass; a board-less project must not be left with a dangling
  `<!-- knobs:backlog-core -->` block. **The engine owns the header and the knob blocks and nothing
  else here:** it never edits a project section it did not write.

  **The inner shape of a knob block is fixed**, because a chunk reads it by marker out of a file it
  never sees whole: **one bullet per key, `- <key>: <value>`, the key spelled exactly as the Profile
  names it, keys in the Profile's order, no heading and no nesting between the markers.** A
  multi-item value (a DoD list) is a numbered list indented under its bullet:

  ```
  <!-- knobs:parallel-work -->
  - worktree_path_prefix: `../<proj>-<n>-<slug>`
  - install: `npm ci`
  <!-- /knobs:parallel-work -->
  ```
- **`CLAUDE.md` — the thin Claude Code adapter.** The import block, in order:
  `@~/.claude/chunks/dev-base.md`, then each `imports` entry, then
  **`@docs/agents/project-workflow.md`** — an `@` import, not a prose pointer, so the project rules
  stay always-loaded. **The `fork` is not in the import block at all**: it is a Skill, and the
  engine writes it into the Template's skill-list slot as `/<fork>` — `/git-flow-squash` today.
  If `CLAUDE.md` exists, merge into the existing import
  block with **exact-line dedup**; never duplicate or reorder hand-placed imports. Below it, the
  Template's one section — `## Claude Code mechanics (this host only)` — carrying host mechanics
  only, its `.claude/agents/` bullet unconditional because every Profile stamps the gate seat there.
  **No knob block and no project rule may remain in this file.**
- **`AGENTS.md` — the Codex adapter.** Derive `{{CHUNK_READ_LIST}}` first: the chunks
  `~/.claude/chunks/dev-base.md` bundles — read it for the list — plus each `imports` entry. **The
  `fork` is not on that list**: it is a Skill, written instead into the Template's skill-list slot
  as `$<fork>` — `$git-flow-squash` today. The read list expands into **item 3**, not a free-standing
  sentence, and it carries the count so a reader can tell a short read from a complete one:
  `These <count> files under ~/.codex/chunks/ (the dev-process rules, shared with the other host):`
  then the file names with their `.md` suffixes. `<count>` is the length of the list you just
  derived, spelled as a word. **Keep the file under 8 KiB before Profile fragments**; step 7's byte
  gate caps the pair that is actually loaded.

  **The canary is the truncation signal.** A fresh Codex session that cannot quote the last line did
  not receive the whole file — the auto-loaded pair is over the cap, or the file never loaded at all
  — so it is the one check that distinguishes "read and ignored" from "never arrived". The `v1` in
  it names the adapter Template's *shape*; bump it only when that shape changes, never per project.
- **`.claude/agents/gate-runner.md` — the project's gate seat.** Stamped whole from
  `templates/gate-runner.md`, **skip if it exists**: a project that has customised its starter keeps
  its own. The `gate_runner` fragment replaces the marker; where the Profile declares none, the
  marker is deleted. **What skip-if-exists costs:** a later improvement to the starter never reaches
  an already-stamped project by re-running init — someone carries it across by hand.

**2. Enable external @imports (load-bearing — ADR 0001), and trust the repo on Codex.** External
`@~/.claude/chunks/…` imports require a **one-time, per-project interactive approval** ("trust
external includes"), granted at first launch and persisting for that project. **Headless runs key
off the same approval:** without it, `claude -p` and cron leave the `@…` lines as raw text and the
chunks never load (measured 2026-09-01; `--add-dir ~/.claude/chunks` changes nothing either way).
The Codex counterpart is the **directory-trust prompt** on first launch in the project; the user
answers it, and the engine never writes `~/.codex/config.toml` and does not auto-edit
`~/.claude.json` unless the user explicitly opts in. Both go in the handoff (step 8).

**3. Stamp Templates.** For each `templates` entry, copy `src` → `dest`, **skip if the dest exists**
unless `refresh: true`. Then replace every `{{NAME}}` token with the value the user supplies,
asking once per distinct token. Two are **derived, never asked**: `{{PROJECT_ROOT}}` is `pwd` at the
repo root at stamp time, and `{{PROJECT_NAME}}` is the answer step 1 already has. Templates are
*copied*, not referenced (unlike chunks): their source of truth is the Profile asset, realigned by
a parity check where the Profile has one, never hand-merged. **Leave behind any `templates` entry
whose comment says it waits for the lockfile-freeze** — the recipe stamps those itself, after the
freeze, because they point into a tree that does not exist yet.

**4. Merge `.claude/settings.local.json`.** Apply the Profile's `settings` delta (if any): union its
`allow` globs into `permissions.allow`, and add its `enabled_mcp_servers` to `enabledMcpjsonServers`.
If the target file is absent, create it from the session baseline the Claude adapter Template's
**Session baseline** bullet names — `{"permissions":{"defaultMode":"auto"},"sandbox":{"enabled":true}}`,
whose shape and recovery live in the `sandbox-and-permissions` Skill — plus that delta. If present:
**union `permissions.allow` by strict exact-string dedup** — keep both of two overlapping
`Bash(...)` patterns rather than semantically merging them — set `enabledMcpjsonServers` as the
Profile requires, **preserve every other top-level key**, and write back. Never clobber. Keep
destructive and `gh`-write globs OFF the allowlist (`git-confirm-destructive`). The fuller merge
contract is the **`sandbox-and-permissions`** skill where it is installed (its directory exists
under `~/.claude/skills` or `~/.agents/skills`); where it is not, skip that read.

**5. Run the Profile's `## Bespoke setup` recipe.** The escape hatch for what a manifest can't
express — a CLI `init`, editing `project.godot`, a pinned tool install. Empty for simple types.
**Minus every section the recipe marks `<!-- precondition -->`, which step 0 has already run** —
those are the one part of the section this step does not re-run, and re-running a check whose whole
point was to fire before the first write buys nothing. Everything else in `## Bespoke setup` runs
here, in the order the recipe gives it.

**6. Lockfile-freeze (when the recipe declares pinned installs).** Install once into a local tree,
**commit the lockfile, not the modules**, gitignore the module tree (append with exact-string
dedup), and record the fresh-clone rehydrate command in the handoff. The *payload* — which packages,
which versions — is Profile-leaf; only the godot Profile needs the mechanic today, and nothing is
promoted until a second type does. **This is a mechanic, not a position in the sequence:** it runs
where the recipe puts it, so read the recipe for the order and this step for what the freeze does.

**7. Verify-after-write.** Re-inventory the expected outputs: the four emitted files exist; each
`@import` path resolves through the symlink; no stamped file still carries a `{{` token, an
unconsumed `<!-- profile:… -->` marker, a `<!-- requires:` comment or a surviving `*<Fill at init:`
prompt; no `##` heading in an emitted adapter has nothing under it. If the Profile sets a
`verify-gate`, run it.

**Two verdicts a scaffold produces that are neither pass nor fail**, and both have been read as a
pass. A **gate step that hangs** — no exit, banner only — is a **stamp failure**: kill it, report the
command and that it did not return, and fix the knob rather than recording the step as green. And on
day zero a project has no tests, so the test step prints `no tests match` or its equivalent: that is
an empty run, not a green one. Quote the harness's own self-check as the real test verdict (for the
`godot` Profile, `tests/run_tests.sh --selftest` ending `selftest: 8/8 verdicts correct`), and say
the suite was empty.

Then two measurements:

- **The byte gate (it FAILS the stamp).** `wc -c AGENTS.md ~/.codex/AGENTS.md`; **each** figure must
  be **≤ 32,768**, because the cap is per file, not across the loaded pair (measured 2026-09-04).
  Over the cap, report both figures and **stop**: no silent trim, and not a stamp reported done.
  Codex's `project_doc_max_bytes` governs each auto-loaded file and truncates past it with no error.
- **The chunk total (recorded, never gated).** `wc -c` over the chunk files `AGENTS.md` names,
  summed. Those are tool-read on demand, outside the cap; the figure belongs in the handoff so a
  later reader knows what the adapter costs when it is followed.

Surface every gap, and report the stamp done only once the inventory passes (`verify-gate`).

**8. Handoff.** Tell the user: (a) on first launch in Claude Code, **approve the external-includes
prompt once**, then restart so the imports load; (b) that same approval is what makes headless runs
expand the imports; (c) on first launch in Codex, **answer the directory-trust prompt** — **it is
load-bearing for MCP, not only for config loading.** Answering it writes
`[projects."<absolute path>"] trust_level = "trusted"` into `~/.codex/config.toml`, and until that
entry exists the project's own `.codex/config.toml` does not load at all: `codex mcp list` from the
project root shows only the user-scope servers, with no error (measured 2026-09-03). A
`-c projects."<path>".trust_level="trusted"` override on the command line does **not** substitute
for the file entry; (d) **the two per-clone host config files are ignored machine-wide, and the
engine writes neither ignore.** Run `git check-ignore -q .codex/config.toml` and `git check-ignore
-q .claude/settings.local.json`; for each that comes back unignored, give the user the line for
`~/.config/git/ignore` — `**/.codex/config.toml`, `**/.claude/settings.local.json`. Not the
project's `.gitignore`: both files are per-clone and machine-local, so one line each machine-wide
covers every project; (e) **both hosts need a new session after an MCP or settings change** —
nothing re-reads either mid-session; (f) any fresh-clone rehydrate command from step 6; (g) step 7's
figures — every measurement step 7 lists, not a subset named here; (h) anything the Profile
recipe defers to an interactive editor step.

## Migrate mode

For a project already on the Chunk library whose `CLAUDE.md` was written by the previous engine —
chunk imports, the knob blocks inline below them, the project's own rules below those. It moves what
belongs in the contract into the contract and leaves an adapter behind. It **moves prose; it never
authors any**, and it **never rewrites a line to fix it** — a line that needs fixing is flagged for
the user. **Transcribing is moving, not authoring**: lifting a name or a value the moved prose
already carries into a Template slot that asks for it is in scope; inventing one is not.

**The project name is not asked for in this mode.** Take it from the existing `CLAUDE.md`'s own H1
and use the same string in all three emitted files — a project that already has a heading has
already answered `{{PROJECT_NAME}}`.

**0. Stop if it is already migrated.** If `docs/agents/project-workflow.md` exists *and* `CLAUDE.md`
carries no `<!-- knobs:` marker, report "already migrated, nothing to move" and stop. Only past this
check does step 2's refusal mean anything: a migrated project has no knob blocks in `CLAUDE.md` by
design, so refusing it for that would make migrate fail on its own output.

**1. Refuse what this is not for.** No `@~/.claude/chunks/dev-base.md` line in `CLAUDE.md` means
this is not a chunk-library project: say so and stop — the right tool is init.

**2. Require every knob block that should exist.** Same membership as the init pass: every
value-variant id the file imports **or** a Skill reads by marker — `verify-gate` (it rides
dev-base) and `parallel-work` (a Skill now, imported by nothing, still read by marker), plus
`backlog-core` where it is imported — its `<!-- knobs:<id> -->` block must be present. If one is
missing, **refuse and name it**. Never synthesise a knob value: the values are measured facts about
that project, and a guessed gate command is worse than no migration. **`implement-run` is the
exemption** — that Skill states
that its defaults apply where the block is absent, so a project stamped before it existed has none:
a fact about when the project was stamped, not a gap the user must fill. Migrate it without one and
say so.

**3. Move the knob blocks verbatim** into the new `docs/agents/project-workflow.md`, under the
engine's header, in the order they appeared.

**4. Move every project section verbatim** into the contract, after the knob blocks — same order,
same prose.

- **The unit of movement is a whole bullet or a whole paragraph**, never a sentence cut out of one.
  A paragraph mixing host mechanics with a project rule is not split: it **stays in the contract**,
  flagged for the user to split by hand.
- **The only structural change is promotion.** A wrapper heading (`## Project-specific
  (inline-leaf)` and the like) disappears and its children rise one level to `##`, as top-level
  sections of a file of their own. Nothing is demoted and nothing is reworded.
- **A moved section replaces an engine stub by the prefix rule**, keeping the project's fuller
  heading: `## Working in this repo — Godot domain & MCP workflow` replaces the `## Working in this
  repo` stub; likewise `## Running`.
- **Whole bullets that are only host mechanics move to the adapter instead** — the
  `.claude/settings.local.json` baseline, `.mcp.json`, `.claude/agents/`, the `/name` spelling, any
  "skills auto-load here" claim — into `## Claude Code mechanics (this host only)`, not a shared
  contract. The Template's generic `.claude/agents/` bullet is unconditional and always stands,
  because migrate stamps nothing and both the directory and the gate seat arrive with the init run
  this mode closes by asking for; a moved bullet naming a subagent the project actually has wins
  over it.

**Flag, never rewrite.** Four classes, each reported in step 8's ledger with its file and its line,
and left exactly as it was. **They apply to moved prose only** — the engine's own header and Template
bullets name `CLAUDE.md`, `AGENTS.md` and both chunk roots by design, and flagging the boilerplate
you just wrote buries the findings that matter:

- A moved line still in the contract naming a host or a host path — `Claude Code`, `.claude/`,
  `~/.claude`, `.mcp.json`, `~/.claude.json`, or the Codex equivalents (`Codex`, `.codex/`,
  `~/.codex`). Host mechanics, or a project rule that merely mentions one, is the user's judgement.
- A `~/.claude/skills/<skill>/scripts/…` path inside a knob value: it resolves on one host and
  silently misses on the other, so the user replaces it with a host-neutral entry point in the repo.
- A cross-reference to a heading whose level the promotion changed (`see **### Running**` when
  `Running` is now `##`).
- **A moved knob block whose keys do not match the Profile's key set** — a renamed key
  (`test-roster` where the Profile names `test_roster`) or a missing one (a six-key `verify-gate`
  where the Profile fixes eight). Report the block, the keys that differ, the keys that are absent,
  and the Profile's list beside them. Do not rename and do not fill a gap: the keys are how the
  chunks find the values, and only the user knows the project's measured facts.

**5. Rewrite `CLAUDE.md` as the thin adapter** — the header and mechanics section from
`templates/CLAUDE.md`, the import-block comment and import lines the file already had (that comment
is the project's own record of why each import is there: keep it) plus
`@docs/agents/project-workflow.md`, and, folded into the mechanics section, whatever step 4 moved
out of the contract. The Profile's `claude` fragment goes in here too, each bullet under **the
fragment target check** step 6 states.

**The project's wording wins, and its facts survive.** Where a moved line and a Template bullet
cover the same ground, keep the project's line and append whatever fact the Template's carries that
it lacks — dropping it is how a migration loses content nobody notices missing. **The header is
otherwise replaced wholesale**, so carry across any fact the old one stated that the Template's does
not, such as where the Chunk library is single-sourced on this machine. And **never emit both**
against an inserted Profile fragment: where a fragment bullet covers ground a bullet step 4 moved
**into the same adapter** already covers, keep the moved one and record the fragment's version in
the ledger as the Profile's current wording — two bullets on one subject is how a stale claim
outlives the line that corrected it. A fragment can cover an **adapter** bullet this way but never
a **contract** one: the host mechanics that would have covered a contract bullet were themselves
moved to the adapter in the same step.

**The imports carry over as they are, including the fork.** Migrate does not choose a git-flow
variant, and **flags** a fork line that disagrees with what the repo's history shows — switching a
project's integration model as a migration side effect is what the Profile's `fork:` note forbids,
and that note is not reachable from this mode.

**6. Emit `AGENTS.md`** as init step 1 does, from the imports the file already carries — including
the Profile's **`codex` adapter fragment**, host mechanics this project has never had and could not
have written down. Same for the `claude` fragment in step 5.

**The fragment target check** gates each adapter bullet, here and in step 5, and runs **after**
step 5's never-emit-both rule, on the survivors: a bullet dropped because a moved bullet covers its
ground gets that rule's ledger row and no target check. For each survivor, resolve every target its
`<!-- requires: -->` comment names (§ What a Profile is has the grammar) against the tree **as this
run leaves it** — migrate stamps nothing, so "exists" means exists now, and a target init would
write counts as absent. Every target resolves → insert the bullet whole. Any target fails →
**withhold the bullet whole**: nothing else in the fragment is stripped, the bullet is not reworded,
no placeholder stands in for it, and it leaves no blank line behind, because "not present here" is a
claim about this project that this mode may not author and a fresh session pays for on every launch.
The ledger gets one row per withheld bullet instead: `adapter bullet withheld — <the requires text>`,
then on its own line `found: <what the check found, per target>`, then the bullet verbatim as the
Profile's current wording, then, where an offered contract-fragment section would create the target,
that section's heading. A fragment section all of whose bullets are withheld is withheld whole,
heading included (`adapter section withheld — every bullet failed its target`). **What makes the
check observable:** no emitted bullet whose `requires:` failed, and exactly one ledger row per
bullet withheld.

**The Skills fill prompt is filled by transcription or not at all.** Step 7 fails on a surviving
`*<Fill at init:` prompt and this mode may not author one, so transcribe into that bullet the skill
names the moved prose already carries, spelled `$name`. Where it names none, **leave the prompt
standing and record it in the ledger as a fill the user owes** — a prompt the user can see beats a
list you made up, and step 7's failure is the correct outcome until they answer it. Say in the
ledger which of the two happened.

**Do not insert the `contract` fragment**: the project already has its own prose for those sections,
and this mode moves prose rather than replacing it. Offer it in the ledger instead — the Profile's
contract fragment, and any conditional fragment its recipe would insert where the condition already
holds here (the godot recipe's Board section where `backlog/` exists) — in both kinds:

- A fragment section whose heading **matches** one the migration moved (by the prefix rule) —
  offered as the Profile's current wording for that section, to adopt by hand.
- A fragment section with **no counterpart** in the moved prose — offered as an addition. This is
  the one that silently vanishes otherwise: a board section exists in no pre-contract `CLAUDE.md`,
  so nothing it carries would ever reach a migrated project.

**7. Run verify-after-write** (init step 7) **in full** — every measurement it lists, gates included.
Named as the whole step rather than as a list of the parts that carry over, because a list here goes
stale in silence each time step 7 gains a measurement, and this line is the one migrate mode reads.

**8. Hand off with the ledger and the init handoff.** The ledger: every line moved and where it
went, every line flagged and why, every contract-fragment section offered for hand-adoption — a
reader who disagrees with a move needs to see it, not diff for it. It lives in the project: the
board row for this migration where one exists, never a row created here, else the project's notes
file; the Profile's parity check reads the withheld and never-emit-both rows from there. Then init
step 8's items (a), (b), (c) and (e) plus step 7's byte figures — a migrated project is a first
launch on the second host, so none of those has been answered yet.

**Then tell them to run init once.** Migrate stamps no Templates, so every file the emitted contract
and adapters now point at — a gotcha-scan wrapper, a reference guide, a domain pointer, a test
harness, the Codex MCP config — is still absent, and until init runs the contract names files that
are not there. **The gate seat is absent for the same reason, and nothing points at it**:
`.claude/agents/gate-runner.md` is an engine Template too, and the adapter's `.claude/agents/`
bullet names the directory, never the seat. Init is idempotent and skip-if-exists, so over a
migrated project it stamps exactly the missing ones and touches nothing this mode wrote.

**Two things that init run does not do, and the handoff says both.** It lands no stamp that an
offered contract section does not name: no migrated contract carries the
`<!-- profile:contract-sections -->` marker, so no recipe step can insert a section into it, every
offered section is adopted by hand, and the Profile's migration section says which stamp each
offered section names — until they are adopted those files are present and named by nothing. And it
restores no withheld adapter bullet: init runs no target check and re-inserts nothing at a consumed
marker, and migrate cannot be re-run over its own output (step 0), so a bullet whose target the user
later creates returns through the Profile's parity check, not through either mode.

## Profiles

Read `profiles/` for the roster. Today: `backlog.md` (board-driven — dev-base plus `backlog-core`,
the fork named as a Skill in both adapters), `github.md` (GitHub-issue-driven — `tracker-github`, the two pointer Templates, a
remote check before the first write and the thirteen-label mint), `web.md` (the npm-shaped toolchain
gate; app directory, secrets location and task-branch convention answered at apply time), `godot.md`
(the heavy bespoke recipe — MCP install, `project.godot` edits, lockfile-freeze — and its own
Template assets).
