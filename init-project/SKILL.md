---
name: init-project
description: Scaffold a dev project onto the Chunk library, driven by a declarative project-type Profile. Use when setting up a new dev project, adopting the chunk library in an existing one, adding a new project type, or when a workflow skill falls back to writing local ticket files because the project declares no tracker.
---

# init-project — the Chunk-library scaffolding engine

**ONE engine, many Profiles** (ADR 0003). A **Profile** (`profiles/<type>.md`) is the *data* for one
project type; a new project type is a new Profile, never an engine edit. A stamp emits **six files
plus one fragment, two of the files and the fragment conditional**: always the shared **contract**
(`docs/agents/project-workflow.md`), the two thin **host adapters** over it (`CLAUDE.md`,
`AGENTS.md` — ADR 0009) and the project's **gate-runner seat** (`.claude/agents/gate-runner.md`,
ADR 0011); where the tracker is `github`, also the issue-tracker pointer and the triage-labels map
under `docs/agents/`, and the contract's `## Issue tracker` section. `stamp` also reports
`.claude/settings.local.json`: a per-clone settings merge, no Template, never committed. Knob blocks
live in the contract, host mechanics in the adapters, and neither adapter carries a project rule.

**The script writes; this file judges.** `scripts/engine.sh` (ADR 0021) makes every mechanical
write and read-back, and `"$E" --help` is its interface — the answers file, the output lines, the
exit codes. The prose does not restate its rules; where a step needs one, it points at `--help`.
This file keeps the judgment: the interview, the knob values, the fills, the `gh` writes, the
adoption commit and the handoff. **`E`** is the script's absolute path in this Skill's own
directory — `~/.claude/skills/init-project/scripts/engine.sh` on Claude Code,
`~/.agents/skills/init-project/scripts/engine.sh` on Codex — and **`A`** is the answers file,
`A="$(git rev-parse --git-dir)/init-project-answers.md"` (step 1); every step runs from the
target's root.

**Three writes are never taken back**: the tracker a stamp writes is the one every re-run reads back
from the contract, a stamped Template is never deleted, and a minted label stays minted. So a check
whose failure should stop the stamp is worth nothing once the first write has landed — it runs at
step 0, before any.

## Profiles

A Profile is a YAML frontmatter **manifest** plus an optional `## Bespoke setup` recipe. The script
reads exactly these keys:

- **`imports`** — Chunk ids to `@`-import beyond `dev-base`, which every stamp imports. The tracker
  is never one: it is the engine's (step 0).
- **`fork`** — the one git-flow Skill, imported nowhere; defaulted by the engine (ADR 0002,
  ADR 0013). Step 1 says where the adapters name it.
- **`templates`** — the Profile's own assets, entries `{src, dest, after_freeze?}`. `src` is rooted
  at `profiles/<type>/templates/`, the declared root where the Profile ships Templates; `dest` is target-relative, or starts `~/` for
  a machine-wide write that `host-setup` makes (step 8). **`after_freeze: true`** marks an entry that
  points into a tree the recipe's lockfile-freeze creates: the plain stamp skips it, and step 3
  writes it after the freeze.
- **`adapters`** — the four fragments, under the same root: `claude`, `codex`, `contract`,
  `gate_runner`, each inserted at its Template's `<!-- profile:… -->` marker as an engine zone.
- **`settings`** — the `.claude/settings.local.json` delta: `allow` globs and
  `enabled_mcp_servers`. Destructive and `gh`-write globs stay off it (`git-confirm-destructive`).
- **`knobs`** — overrides of the engine defaults, by key.

In the body, two markers: the `## Bespoke setup` heading, and `<!-- precondition -->` (below).
`--help` says what the script does with any other key.

**Engine defaults.** `defaults.md` carries the fork and every knob block, with the one gloss each
key has; a Profile overrides by key and repeats no gloss. `godot` and `web` take the rest silently.
**`none`** is the named empty Profile, for a project no Profile fits: every value is the defaults',
so the owner answers each shape there, as `defaults.md` glosses it. **The manifest carries shape;
the project carries values**: a `<…>` value is a shape step 1 answers, a literal is written as is.

**A fragment is a section, not loose bullets.** It carries its own `##` headings, because it lands
at one marker near the end of its file, where loose bullets would read as part of the section
above. In the contract, **a fragment `##` heading whose text begins with a stub heading's text,
followed by the end or a character that is not a letter or digit, replaces that stub in place**
(`## Working in this repo`, `## Running`); every other heading is appended, in the fragment's own
order. Either way a fragment *adds* — it sharpens the engine's generic bullets with this type's
specifics rather than restating them. Two bullets on one subject is how a stale claim outlives the
line that corrected it. **The gate-runner starter has no stub**: its fragment appends at its marker,
after `## Report`, and `## Project gates` is the project's own section, outside every zone — so a
`gate_runner` fragment heading that repeats a starter heading splits the seat's own section in two,
as the old prefix rule once swallowed it whole: a Profile bug.

**A fill prompt in a Profile Template is this procedure's to ask**, like the engine's, at step 1.

**A `## Bespoke setup` section may declare itself a precondition.** The line `<!-- precondition -->`
immediately above a `##`/`###` heading makes that section one, and step 0 runs it before anything is
written; a section without the marker is an ordinary recipe step at step 3, however its heading
reads. **Read the set off a command, not off the recipe's intent** — a heading that merely *says* it
runs early is the failure this marker exists to prevent, reading as a precondition to a careful
reader and as an ordinary step to a literal one:

```sh
grep -A1 '^<!-- precondition -->$' profiles/<type>.md | grep '^#'
```

**The adjacency is the whole check**, so never a bare `grep -c` for the marker: a Profile that
*mentions* the marker in its own prose matches that and declares nothing. The marker is read off
the stamped Profile's own file and is never emitted.

**Retired knob blocks survive.** A re-run deletes a knob block only where `scripts/knob-changes`
carries a `retire-block` row for it, and keeps every other block no default or Profile lists. So
retiring a Chunk or Skill that reads a block means adding that row, or the block outlives it in
every project (ADR 0014 § decision 3).

## The run

A re-run is the same run: the script refreshes only the engine's zones and keeps the rest, and the
steps below say where a re-run differs.

**0. Preconditions** — all pass before anything is written, because of the three writes above.
**A re-run** is a target whose `docs/agents/project-workflow.md` exists — the script's own test.

- **Both Chunk symlinks**: `readlink ~/.claude/chunks` and `readlink ~/.codex/chunks`, each → the
  skills repo's `chunks/`; where either is missing, run `bootstrap.sh` / `bootstrap.ps1`. **Both, on
  either host:** a stamp names `~/.claude/chunks/…` in `CLAUDE.md` and `~/.codex/chunks/…` in
  `AGENTS.md` whichever host runs it, so checking only your own leaves the other adapter pointing at
  nothing, with no error at stamp time and none at that host's next launch.
- **The script's own verdict**: `"$E" selftest`. Quote its `selftest: <k>/<N> verdicts correct`
  line in the run report; k < N is a stop.
- **The type** — the Profile to stamp, `none` where no Profile fits — picked here, because the next
  bullet runs that Profile's sections; step 1 writes it into `A`. On a re-run it is the type the
  contract records (`<!-- init-project:type <t> -->`) where it records one.
- **The Profile's precondition sections**, in the recipe's order.
- **The tracker outcome, `github` or `none`** (ADR 0022). **A re-run never re-asks** and runs none
  of the stages below: the script reads the outcome from the contract and ignores the answers file's
  `tracker`, so a project stamped `none` stays `none` after a remote is added; moving it to
  `github` is a separate, owner-invoked run that no re-run makes. A contract holding the frozen
  `backlog-core` block reads `held` — the project stays on it, and the run report gives the
  Tracker line under step 9. **A fresh stamp** settles it here:
  - **Outside a git work tree, stop** (`git rev-parse --is-inside-work-tree` fails): the owner runs
    `git init -b main` — a bare `git init` may default to `master` — and init re-runs from the top.
  - **Stage 1, offline — is there a GitHub remote at all?**
    `git remote -v | grep -q 'github\.com' && echo yes || echo no`. **`no`** — a repository with no
    remote included — settles `none` in this run, with no offer; the run report says the project was
    stamped with no tracker.
  - **Stage 2, on `yes` — its `owner/repo`**: `gh repo view --json nameWithOwner -q .nameWithOwner`,
    which resolves both the SSH and the HTTPS remote forms. **A failure is a stop naming what `gh`
    printed, never `none`**: `gh` exits non-zero when unauthenticated, offline or rate-limited —
    `HTTP 401: Bad credentials`, exit 1, on a clone whose remote is perfectly good (measured on gh
    2.101.0) — and reading that as "no GitHub remote" would strip a project of its tracker over an
    expired token. The remedy is `gh auth login` or a network, then a re-run at no cost.
  - **On success the owner picks**: `github`, the default — `REPO` is stage 2's value, confirmed
    with the owner before it is written — or `none`, for a prototype or sketch.
- **A pre-contract layout** — a `CLAUDE.md` carrying knob blocks with no contract — is the
  script's stop at step 2 (ADR 0020); report it, and the owner decides.

**1. The interview → the answers file.** Write `A` in the target's git directory (`.git` is a
file in a linked worktree, hence `--git-dir`), in the shape `--help` gives: inside the repository,
so sandboxed and unsandboxed shells read the same file, and never committed or shown by
`git status`. Keep it: the next re-run starts from it. It carries:

- **`project_name`** — the `{{PROJECT_NAME}}` token, asked once;
- **`type`** — step 0's pick; kept in `A` on a re-run too, since `host-setup` has no target to
  read the recorded one from;
- **`tracker`** — step 0's outcome, on a fresh stamp;
- **every knob the merged key set leaves a `<…>` shape**, and every key whose literal still carries
  a `<…>` inside it, which the script passes through as written;
- **every other `{{TOKEN}}`** a written file carries (`{{PROJECT_ROOT}}` is derived, never asked);
- **the fills** — each `*<Fill at init: …>*` prompt's answer. **This is when fills are asked**:
  every prompt the Profile's recipe names, here, before the stamp, unless a recipe step decides the
  answer: the recipe names that step, and step 5 asks it. A prompt nothing named surfaces at
  step 5 as a `fill-prompt` FAIL and is asked then, into `A` the same way. The engine fills
  `CLAUDE.md`'s fork slot (`/<fork>`); `AGENTS.md` names the fork in its `#Skills` fill, spelled
  `$<fork>`.

**Never synthesise a knob value**: the values are measured facts about the project, and a guessed
gate command is worse than none. A value read off the repo — a `package.json` script, a lockfile —
is a measurement you may propose, confirmed with the owner before it is written, and so
is a command you write from a fact the owner gave but did not give verbatim; a value neither
measured nor answered is never written. A `~/.claude/skills/<skill>/scripts/…` path inside a knob
value resolves on one host and silently misses on the other, so the owner replaces it with a
host-neutral entry point in the repo. **A re-run asks only for what the contract lacks**: the script
keeps every existing knob value, reads back the recorded type, and reads each in-zone fill back
from the fill markers it wrote around it (`--help`, under `stamp`, "Fill markers"); its stops name
anything still owed.

**2. Stamp.** `"$E" stamp --target . --answers "$A"`. A `STOP` wrote nothing: answer what it names
in `A` and stamp again. `NOTE`, `KNOB`, `ZONE`, `SETTINGS` and `held:` lines go to the run report.

**3. The Profile's recipe.** Run its `## Bespoke setup`, minus the precondition sections step 0 ran,
in the recipe's order. **The lockfile-freeze is a mechanic, not a position**: where a recipe pins
installs, it installs once into a local tree, **commits the lockfile, not the modules**, and ignores
the tree by its own command; the payload — which packages, which versions — is the Profile's. Where
the Profile marks any entry `after_freeze: true`, write those once the recipe is done:
`"$E" stamp --target . --answers "$A" --after-freeze`. Where the recipe names a fresh-clone
rehydrate command, it goes to the run report.

**4. The label mint — tracker `github` only**, after the recipe and before `verify`. All thirteen
labels must exist before the first ticket or map, because a missing label lists zero issues at
exit 0. List first, then create only what is missing:

1. **List**: `gh label list -L 200 --json name,description`. `-L 200` is load-bearing: the default
   is 30, so on a repository with more an existing label reads as missing and its create then
   fails. **A failing list is a stop naming what `gh` printed** — on a re-run, which ran no stage
   2, this is where auth or network trouble surfaces.
2. **The missing subset** of the table below, by name.
3. **One approval for the batch** — a minted label stays minted (above): the names to create, each with its colour and description, and
   beside them the names skipped because they exist. Never per label.
4. **On a yes**, for the missing only: `gh label create <name> -c <color> -d "<description>"`.
   **Never `--force` / `-f`**: it rewrites an existing label's colour and description, silently
   overwriting one the project customised, and makes "the second run errors on nothing" true by
   overwriting rather than by skipping. Skipping is the mechanism.
5. **Confirm by listing, not by exit code**: the same list again shows all thirteen with the
   descriptions below — a loop whose one failing create goes unchecked still exits green. A re-run
   finds all thirteen, creates nothing and errors on nothing.

**Which gate the approval is.** Init's own interaction gate, over a batch of writes to the owner's
repository — **not** `git-confirm-destructive`'s: the tracker Chunk's § Commit forms puts minting a
label among the writes that need no approval under *that* gate. Both hold, because they are about
different gates; named so a reader holding both does not report a contradiction.

| Label | Colour | Description |
|---|---|---|
| `gate:agent` | `0E8A16` | A session starts and closes it alone |
| `gate:accept` | `1D76DB` | A session works it; the owner accepts before it closes |
| `gate:decide` | `B60205` | A decision or grill first; no session starts the work |
| `origin:spec` | `5319E7` | Child of a Spec: parent |
| `origin:found` | `D93F0B` | A defect met while doing other work |
| `origin:review` | `8A63D2` | Out of a code review |
| `origin:spec-review` | `A371F7` | Out of a spec review, off-chain |
| `origin:chore` | `C2E0C6` | Maintenance and housekeeping |
| `wayfinder:map` | `0052CC` | The map parent of a wayfinder chain |
| `wayfinder:grilling` | `6F42C1` | A wayfinder ticket resolved by grilling the owner |
| `wayfinder:prototype` | `0E7490` | A wayfinder ticket answering a question by building |
| `wayfinder:research` | `0366D6` | A wayfinder ticket answering a question from sources |
| `wayfinder:task` | `0969DA` | A wayfinder ticket that is ordinary work |

Three gate, five origin, five wayfinder. **The Description column is the `-d` string the mint
passes, not a definition**: the Chunk's § Two label axes is authoritative, and a description here
that has drifted from it is this table's bug (§ Maintaining the label table). Beyond the names,
restate no label's meaning here, in a stamped file, or in the approval.

**5. Verify.** `"$E" verify --target . --answers "$A"`. A `fill-prompt` FAIL names each prompt still
to answer: ask it as step 1 says, and go back to step 2. Then read the rest:

- **A `CHECK` counts only beside its `CONTROL`**, which proves the check can see its known-bad.
- **The byte `GATE`s fail the stamp, per file**, at the caps `--help` gives under `verify`. Over a
  cap, report the figure and stop — no silent trim, and not a stamp reported done. **The adapter cap
  and the contract cap are different kinds of limit and must not be reconciled.** The adapter cap is
  Codex's `project_doc_max_bytes`, which governs each auto-loaded file on its own and truncates past
  it with no error (measured 2026-09-04). The contract is never auto-loaded by that mechanism — it
  arrives through an `@` import on one host and a mandatory read-list item on the other — so it can
  grow without limit and pays full context cost in every session either way: its figure is a cost
  budget, not a truncation guard, and it fails a re-run over a bloated project, which is when it is
  worth knowing. Measured 2026-09-21 on the project this gate came from: the contract reached
  **47,873 bytes**, 46% over the *adapter* cap, while every figure the verify step then collected
  stayed green — the gate was measuring the 6 KB file and ignoring the 48 KB one it pointed at.
- **The `LOAD` lines are reported, never gated** (ADR 0016 § 4): they go to the run report, so a
  later reader knows what the adapters cost when followed.
- **The canary is the truncation signal.** `AGENTS.md` ends in its canary zone: the canary is the
  last line inside it, and the zone's close tag is the file's last line. A fresh Codex session that
  cannot quote the canary did not receive the whole file — over the cap, or never loaded — so it is
  the one test that tells "read and ignored" from "never arrived". Its `v1` names the adapter
  Template's shape; bump it only when that shape changes, never per project.

**Then run the project's `verify-gate`**, which the script does not (`VERIFY-GATE: NOT RUN by this
script`): every step whose value is not `none — …`, in its `dir`. **Two verdicts are neither pass nor
fail**, and both have been read as a pass. A **step that hangs** — no exit, banner only — is a
**stamp failure**: kill it, report the command and that it did not return, and fix the knob rather
than record the step green. And on day zero a project has no tests, so the test step prints `no
tests match` or its equivalent: that is an empty run, not a green one — quote the harness's own
self-check as the real test verdict and say the suite was empty. **The stamp is done once `verify`
is clean and every gate step that ran passed**; a step that could not run yet (an install not done)
is named NOT RUN in the run report; only a clean gate permits a commit (`verify-gate`), so the
adoption commit waits until it runs unless the owner explicitly accepts committing with it NOT RUN
— the owner's call. The seat running init runs the gate.

**6. Drift.** `"$E" check --target . --answers "$A"`. On a fresh stamp every zone reads `same`;
report any `differs` with the `NOTE` that says why.

**7. The adoption commit**, once step 5's gate permits it and before the handoff, on the
checked-out branch — the adoption is no ticket's work, so no task branch and no issue footer, and a
fresh repository whose remote has no branches has nothing to pull first. Stage by explicit path the
files `stamp` reported `WROTE` and the files the recipe created or edited — except any path step 8's
machine-wide excludes cover: a per-clone host file never enters git, whether or not step 8 has run
yet — and make one commit under the project's own commit rules (its Chunks'). A re-run commits
only where a line read `WROTE`, `ZONE … refreshed` or a `KNOB` change; with none, there is no
commit.

**8. Machine-wide setup.** `"$E" host-setup --answers "$A"`, once per machine: the ignore lines for
the two per-clone host files, `.codex/config.toml` and `.claude/settings.local.json`, go into the
machine-wide git excludes — one line each covers every project, where a project's `.gitignore` would
cover one — and the Profile's `~/` Templates are written. Quote each line with its undo in the run
report; a `differs` is left for the owner.

**9. The handoff: only what the owner alone can do.**

- **(a) Claude Code: approve the external-includes prompt** on first launch, then restart so the
  imports load. The approval is one-time and per project (ADR 0001), and **headless runs key off
  it too**: without it `claude -p` and cron leave the `@…` lines as raw text and the Chunks never
  load (measured 2026-09-01; `--add-dir ~/.claude/chunks` changes nothing either way). The engine
  never edits `~/.claude.json`.
- **(b) Codex: answer the directory-trust prompt** on first launch — **load-bearing for MCP, not
  only for config loading.** Answering writes `[projects."<absolute path>"] trust_level = "trusted"`
  into `~/.codex/config.toml`, and until that entry exists the project's own `.codex/config.toml`
  does not load at all: `codex mcp list` from the project root shows only the user-scope servers,
  with no error (measured 2026-09-03). A `-c projects."<path>".trust_level="trusted"` override does
  **not** substitute for the entry. The engine never writes `~/.codex/config.toml`.
- **(c) A new session on both hosts after an MCP or settings change** — nothing re-reads either
  mid-session.
- **(d) Any owner-only item the Profile's recipe adds.**

**The run report carries the rest**: the `selftest` line; the tracker outcome — for a stage-1 `no`,
that the project was stamped with no tracker; the lines steps 2 and 8 route to it; `verify`'s
figures and gate verdicts; the `check` result; any rehydrate command; any recipe run-report items;
the adoption commit's SHA. For a `held` tracker, one line, filled in from the `held:` line:

```
Tracker: this project stays on backlog-core (frozen) — its contract holds a <!-- knobs:backlog-core --> block, so init ran no tracker choice and no tracker setup (<the parts held: names>). Moving it to another tracker is the owner's decision; no init run makes it.
```

## Profiles roster

Read `profiles/`: today `web`, `godot` and `none`.

## Maintaining the label table

A maintainer's check when step 4's table or the tracker Chunk changes, never a stamp step. Run it
**from this Skill's directory** — from anywhere else both greps read missing files and `diff`
prints nothing, which looks like agreement — and in one shell, which reads its own `$TMPDIR`:

```sh
t="${TMPDIR:-/tmp}"
grep -oE '^\| `(gate|origin|wayfinder):[a-z-]+`' SKILL.md | tr -d '|` ' | sort -u > "$t/labels-skill"
grep -oE '(gate|origin|wayfinder):[a-z-]+' ../chunks/tracker-github.md | sort -u > "$t/labels-chunk"
wc -l "$t/labels-skill" "$t/labels-chunk"; diff "$t/labels-skill" "$t/labels-chunk"
rm -f "$t/labels-skill" "$t/labels-chunk"
```

Expect no `diff` output, and **13** lines on each side in the `wc -l` counts — a zero means the
extraction broke, not that the sets agree.
