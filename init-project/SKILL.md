---
name: init-project
description: Scaffold a dev project onto the Chunk library, driven by a declarative project-type Profile. Use when setting up a new dev project, adopting the chunk library in an existing one, adding a new project type, or when a workflow skill falls back to writing local ticket files because the project declares no tracker.
---

# init-project — the Chunk-library scaffolding engine

**ONE engine, many Profiles.** The engine is a uniform apply-algorithm; a **Profile**
(`profiles/<type>.md`) is the *data* for one project type. A new project type is a new Profile.
The engine and the `dev-base` bundle are stable; only Profiles grow. (ADR 0003.)

**Every Profile emits the same four agent-facing files:** one shared **contract**, two thin
**host adapters** over the contract (ADR 0009), and the project's **gate-runner seat** at
`.claude/agents/gate-runner.md`, which re-runs the verify gate for a coordinator that did not write
the diff (ADR 0011). Knob blocks live in the contract, host mechanics live in the adapters, and
neither adapter carries a project rule.

**The mechanics have a script: `scripts/engine.sh`** in this Skill's directory, with five
subcommands — `selftest`, `stamp`, `verify`, `check`, `host-setup` — and its `--help` for the
answers file it reads and the output lines it prints (ADR 0021). The steps below still describe those mechanics by hand
until the prose rework.

## What a Profile is (the manifest contract)

A Profile is `profiles/<type>.md`: a YAML frontmatter **manifest** + an optional
`## Bespoke setup` recipe. The manifest fields the engine reads:

```yaml
---
type: <name>
imports:            # chunk ids to @import BEYOND dev-base (dev-base is always imported)
fork: git-flow-squash      # exactly one git-flow variant, and squash is the only one today
                           # (ADR 0002, ADR 0013). The key names the integration model the project
                           # selects, so a merge-commit variant can still arrive later. It is NOT
                           # imported: the fork is a Skill, emitted into BOTH adapters' skill
                           # lists — `/git-flow-squash` on Claude, `$git-flow-squash` on Codex.
templates: []              # Template assets to stamp: [{src, dest, refresh?}]
adapters:                  # optional: this type's fragments for the four Templates that take one.
  claude: adapter-claude.md   #   inserted at <!-- profile:claude-mechanics --> in CLAUDE.md
  codex:  adapter-codex.md    #   inserted at <!-- profile:codex-mechanics --> in AGENTS.md
  contract: contract.md       #   inserted at <!-- profile:contract-sections --> in the contract
  gate_runner: adapter-gate-runner.md   # inserted at <!-- profile:gate-runner-mechanics --> in the gate-runner starter
settings:                  # optional: this type's settings.local.json delta, merged in step 4
  allow: []                #   extra permissions.allow globs
  enabled_mcp_servers: []  #   added to enabledMcpjsonServers
knobs:                     # per value-variant chunk → the values to write into its knob block
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
command for says so in its value rather than going missing, written `none — <why>`, which the
gate-runner reads as declared absent.

`adapters:` names four files under the Profile's own `templates/`. **Every `<!-- profile:… -->`
marker is consumed** — replaced by its fragment, or deleted where the field or the key is absent.

**A fragment is a section, not loose bullets.** It carries its own `##` headings, because it lands
at one marker near the end of the file, where loose bullets would read as part of whatever section
sits above it. Two placements:

- A heading the engine Template already stubs (`## Working in this repo`, `## Running`)
  **replaces** that stub, in place.
- Any other heading is **appended** at the marker, as its own section.

Either way a fragment *adds* — it sharpens the engine's generic bullets with this type's specifics
rather than restating them. Two bullets on one subject is how a stale claim outlives the line that
corrected it.

**The gate-runner starter has no stub heading**, so a `gate_runner` fragment always appends.
`## Project gates` is the project's to fill, never a stub a fragment may replace — and because the
replace rule is a prefix match, a fragment heading that prefix-matches a starter heading swallows
the starter's own section: a Profile bug.

**A `## Bespoke setup` section may declare itself a precondition.** One HTML comment on the line
above its heading, `<!-- precondition -->`, moves that section out of step 5 and into **step 0**,
before anything is written. Step 0 states its rule and its grep.

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

- **`{{PROJECT_NAME}}`** — the project's own name. Asked **once**, reused in every Template that
  carries the token.
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
target — `ls CLAUDE.md AGENTS.md docs/agents/project-workflow.md
.claude/agents/gate-runner.md .claude/settings.local.json`, plus any path the Profile's
`templates`/recipe touches — and for each
thing that exists, plan to merge or skip. **A `CLAUDE.md` that carries knob blocks or project
sections, where no `docs/agents/project-workflow.md` exists, is a pre-contract project: stop.**
Migrate mode is retired (ADR 0020).

**One tracker per project — step 0's tracker rule.** The tracker is the Chunk `tracker-github`; a
project imports it or none. **A Profile's own tracker** is the tracker Chunk its `imports` names,
or none: today `web.md` and `github.md` → `tracker-github`, and `godot.md` → none, its tracker
being chosen by its recipe. **A tracker's setup** is its Templates, its contract fragment and its
recipe steps (the label mint) — everything but its import line, its read-list entry and its knob
block. **A tracker Profile's whole `## Bespoke setup` is its tracker's setup**, so where that setup
does not run, no section of it runs. **Read what the target already holds before any precondition
runs**, from its contract, anchored so a prose mention of a marker in backticks does not match:

```sh
grep -oE '^<!-- knobs:(tracker-github|backlog-core) -->$' docs/agents/project-workflow.md
```

No contract means nothing is held. Then:

- **Any match but `tracker-github` → stop before anything is written** and report the marker:
  that Chunk is frozen for its existing importers, and no init run touches a project on it (ADR
  0020).
- **One held → the project stays on it.** Every precondition section that checks or offers a
  tracker is skipped, so no remote check runs and no offer is put — **even where the held tracker
  is the Profile's own**: a `github.md` or `web.md` re-run over `tracker-github` runs no remote or
  `gh` auth check at step 0. A held tracker needs no fit check, and re-running one would put the
  offer against a tracker the project already holds, which no pick can honour; remote or auth
  trouble surfaces instead at that tracker's own recipe step (the label list in
  `profiles/github.md` § B), and the run stops there. The held tracker's import line, read-list
  entry and knob block are kept. **Its setup runs again only where it is the Profile's
  own tracker** — an ordinary re-run (today `web.md` or `github.md` over `tracker-github`), where
  each part is idempotent. Otherwise **no tracker setup runs**, and step 8 gives the `Tracker:` line
  below — so a `godot.md` re-run over a held tracker runs no tracker setup and gives the line.
- **Nothing held →** the Profile's own tracker path decides, including the owner's pick at an
  offer a precondition puts — today: none after `profiles/github.md` § A's stage-1 `no`, or
  `godot.md`'s choice — and the tracker it settles on gets its setup.

**Whatever this settles — the held tracker, the Profile's, the owner's pick, or none — is the only
tracker steps 1–5 write, and step 1 writes it whether or not the Profile's `imports` lists it.**
Step 1's `CLAUDE.md` import block and `AGENTS.md` item-3 read list carry it and no other tracker, so
a godot stamp, whose `imports` is empty, gets its tracker in both adapters from step 1 rather than
from a recipe line that would reach `CLAUDE.md` alone. Its knob block is kept where it exists, or
written — values from the Profile's `knobs` entry for it, answered from the project. Step 1's
retired-block deletion spares the settled tracker's block. Steps 1, 3 and 5 insert, stamp and run
the settled tracker's setup only where the bullets above let it run.

**Wherever a held tracker is not the Profile's own, step 8 gives this line**, filled in, as one
line:

```
Tracker: this project stays on <held> — its contract holds a <!-- knobs:<held> --> block, so init ran no tracker choice and no tracker setup (<each skipped part>). Moving it to another tracker is the owner's decision; no init run makes it.
```

**Why here and not at step 1.** The `github` remote check is itself a step-0 precondition, so a
rule first read at step 1 fires after the offer has already been put. And a wrong tracker, once
written, stays: the `CLAUDE.md` import merge removes no line, a stamped Template is never deleted,
and a minted label stays minted.

**A Profile's recipe may declare a precondition step, and it runs here**, before step 1 writes
anything. The engine fixes the position; the recipe says only what the step checks and what happens
when the check fails. **This is the inverse of step 6's freeze**, which runs where the recipe puts
it — a precondition's place is not the recipe's to choose, because **the writes step 0's *Why
here* names are never taken back** — the `CLAUDE.md` import merge removes no line, a stamped
Template is never deleted, a minted label stays minted — so a check whose failure should stop the
stamp is worth nothing once the first write has landed.

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

**The engine reads preconditions only off the stamped Profile's own file**, never through a
reference, so a Profile that reaches another Profile's precondition by reference marks its own
calling section. Unmarked, that section is an ordinary recipe step, and the check it calls runs at
step 5, after step 1 has written the tracker import.

**1. Write the contract, the two adapters and the gate seat.** Fragments go in whole.

- **`docs/agents/project-workflow.md` — the shared project contract.** Order: the engine's header,
  the **knob blocks**, then the project sections. **More than one fragment can write into
  `<!-- profile:contract-sections -->`, so the section order is fixed:** the engine's own stubs
  (Project, Working in this repo, Running — each replaced in place where a fragment supplies it),
  then the type Profile's contract fragment, then any conditional fragment a recipe step inserts
  later. **A fragment section that is not a stub replacement keeps its position in its own
  fragment's order**: a fragment running Working in this repo → godot-ai addon → Running emits
  the addon section between those two, not after both.
  **A tracker Profile's contract fragment is that tracker's setup**, so it is withheld wherever
  step 0 runs no setup for its tracker — step 0's tracker rule.

  **Write a tagged block `<!-- knobs:<id> -->` … `<!-- /knobs:<id> -->` for each id in `knobs` that
  is either actually imported** (it rides dev-base, or it is in `imports` — for a tracker, the one
  step 0 settled, by step 0's tracker rule) **or read by marker by a
  Skill — today `parallel-work` and `implement-run`, which are Skills no project imports and which
  read their block out of this contract exactly as the Chunks did (ADR 0014 § decision 2).**
  Today's `fork` is neither — `git-flow-squash` declares no knobs — so it gets no block; a later
  one that reads a block by marker qualifies under that second limb like any other Skill, and the
  test decides it, not the key it arrived under.
  On re-run, replace *only* the content between the tags, and insert the block if absent. **Delete,
  tags and all, every `<!-- knobs:<id> -->` block whose id the Profile's `knobs` does not list and
  that is not the tracker block step 0 settled** (step 0's tracker rule) — a chunk the library has
  retired, which a re-run would otherwise preserve forever (ADR 0014 § decision 3).
  **The values inside an existing block are this project's own answers, not the manifest's:** a
  re-run keeps them and fills from the manifest only an absent block. What it does change between
  existing tags is the key set — a key the Profile has added or renamed since the last stamp is
  added or renamed in place, its value answered from the project as at apply time.
  Never synthesise a knob value: the values are measured facts about that project, and a guessed
  gate command is worse than none. A `~/.claude/skills/<skill>/scripts/…` path inside a knob value
  resolves on one host and silently misses on the other, so the user replaces it with a
  host-neutral entry point in the repo. **Never write knob values into a chunk file**: they live
  here, and the chunks and Skills read them out by marker. **A tracker's block comes from this
  pass, as step 0 settled it** (step 0's tracker rule), at the settled tracker's entry in the
  Profile's `knobs` order, or first where the Profile lists none for it. **The engine owns the
  header and the knob blocks and nothing else here:** it never edits a project section it did not
  write.

  **The inner shape of a knob block is fixed**, because a chunk reads it by marker out of a file it
  never sees whole: **one bullet per key, `- <key>: <value>`, the key spelled exactly as the Profile
  names it, keys in the Profile's order, no heading and no nesting between the markers.** A
  multi-item value is a numbered list indented under its bullet:

  ```
  <!-- knobs:parallel-work -->
  - worktree_path_prefix: `../<proj>-<n>-<slug>`
  - install: `npm ci`
  <!-- /knobs:parallel-work -->
  ```
- **`CLAUDE.md` — the thin Claude Code adapter.** The import block, in order:
  `@~/.claude/chunks/dev-base.md`, then each `imports` entry — its tracker entry being the one
  step 0 settled, written here even where `imports` lists none (step 0's tracker rule) — then
  **`@docs/agents/project-workflow.md`** — an `@` import, not a prose pointer, so the project rules
  stay always-loaded. **The `fork` is not in the import block at all**: it is a Skill, and the
  engine writes it into the Template's skill-list slot as `/<fork>` — `/git-flow-squash` today.
  If `CLAUDE.md` exists, merge into the existing import
  block with **exact-line dedup**; never duplicate or reorder hand-placed imports. Below it, the
  Template's one section — `## Claude Code mechanics (this host only)` — carrying host mechanics
  only, its `.claude/agents/` bullet unconditional because every Profile stamps the gate seat there.
  **No knob block and no project rule may remain in this file.**
- **`AGENTS.md` — the Codex adapter.** Derive `{{CHUNK_READ_LIST}}` first, from `CLAUDE.md`'s
  merged import block: the chunks `~/.claude/chunks/dev-base.md` bundles — read it for the list —
  plus each `@~/.claude/chunks/<name>.md` import in the `CLAUDE.md` import block this step just
  wrote or merged, `dev-base.md` itself aside (the contract's `@docs/…` import is not a chunk). So a
  hand-placed import `CLAUDE.md` keeps is read on Codex too, and the tracker on the list is the one
  step 0 settled, as in `CLAUDE.md`. **The `fork` is not on that list**: it is a Skill, written
  instead into the Template's skill-list slot as `$<fork>` — `$git-flow-squash` today. The read
  list expands into **item 3**, not a free-standing sentence, and it carries the count so a reader
  can tell a short read from a complete one:
  `These <count> files under ~/.codex/chunks/ (the dev-process rules, shared with the other host):`
  then the file names with their `.md` suffixes. `<count>` is the length of the list you just
  derived, spelled as a word. **On a re-run over an existing `AGENTS.md`, item 3's read list is
  re-derived that way and replaced in place, its count re-spelled; nothing else in the file is
  touched.** **Keep the file under 8 KiB before Profile fragments**; step 7's byte gate caps the
  pair that is actually loaded.

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
freeze, because they point into a tree that does not exist yet. **Stamp a tracker's Templates only
where step 0's tracker rule runs its setup** — listed here or stamped by a recipe by reference.

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
point was to fire before the first write buys nothing. **Skip, too, every recipe section or step
that is a tracker's setup, wherever step 0's tracker rule runs none for that tracker.** Everything
else in `## Bespoke setup` runs here, in the order the recipe gives it.

**6. Lockfile-freeze (when the recipe declares pinned installs).** Install once into a local tree,
**commit the lockfile, not the modules**, gitignore the module tree (append with exact-string
dedup), and record the fresh-clone rehydrate command in the handoff. The *payload* — which packages,
which versions — is Profile-leaf; only the godot Profile needs the mechanic today, and nothing is
promoted until a second type does. **This is a mechanic, not a position in the sequence:** it runs
where the recipe puts it, so read the recipe for the order and this step for what the freeze does.

**7. Verify-after-write.** Re-inventory the expected outputs: the four emitted files exist; each
`@import` path resolves through the symlink; no stamped file still carries a `{{` token, an
unconsumed `<!-- profile:… -->` marker or a surviving `*<Fill at init:` prompt; no `##` heading in
an emitted adapter has nothing under it. If the Profile sets a `verify-gate`, run it.

**Two verdicts a scaffold produces that are neither pass nor fail**, and both have been read as a
pass. A **gate step that hangs** — no exit, banner only — is a **stamp failure**: kill it, report the
command and that it did not return, and fix the knob rather than recording the step as green. And on
day zero a project has no tests, so the test step prints `no tests match` or its equivalent: that is
an empty run, not a green one. Quote the harness's own self-check as the real test verdict (for the
`godot` Profile, `tests/run_tests.sh --selftest` ending `selftest: 8/8 verdicts correct`), and say
the suite was empty.

Then two measurements:

- **The adapter byte gate (it FAILS the stamp).** `wc -c AGENTS.md ~/.codex/AGENTS.md`; **each**
  figure must be **≤ 32,768**, because the cap is per file, not across the loaded pair (measured
  2026-09-04).
  Over the cap, report both figures and **stop**: no silent trim, and not a stamp reported done.
  Codex's `project_doc_max_bytes` governs each auto-loaded file and truncates past it with no error.
- **The contract byte gate (it FAILS the stamp).** `wc -c docs/agents/project-workflow.md`;
  **≤ 16,384**. Same stop, same no-silent-trim. **This is a different kind of limit from the one
  above and the two must not be reconciled**: the adapter cap prevents Codex truncating a file it
  auto-loads, while the contract is never auto-loaded by that mechanism — it arrives through an
  `@` import on one host and a mandatory read-list item on the other, so it can grow without limit
  and pays full context cost in every session either way. The figure is a cost budget, not a
  truncation guard. A fresh stamp lands around 10–11 KB, so this never fails day zero; it fails a
  re-run over an already-bloated project, which is when it is worth knowing.
  Measured 2026-09-21 on the project this gate came from: the contract reached **47,873 bytes**,
  46% over the *adapter* cap, while every figure step 7 collected stayed green — the gate was
  measuring the 6 KB file and ignoring the 48 KB one it pointed at.
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
recipe defers to an interactive editor step; (i) wherever a held tracker is not the Profile's own,
the `Tracker:` line step 0's tracker rule gives, filled in.

## Profiles

Read `profiles/` for the roster. Today: `github.md` (GitHub-issue-driven — `tracker-github`, the
two pointer Templates, a remote check before the first write and the thirteen-label mint), `web.md`
(the npm-shaped toolchain gate; app directory, secrets location and task-branch convention answered
at apply time; lands on the GitHub tracker by reference to `github.md`), `godot.md` (the heavy
bespoke recipe — MCP install, `project.godot` edits, lockfile-freeze — and its own Template assets;
offers github or none).
