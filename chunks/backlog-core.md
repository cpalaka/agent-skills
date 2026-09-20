<!-- chunk:backlog-core | kind: value-variant | single-source: agent-skills/chunks/backlog-core.md -->
<!-- Delivered by Claude @import or a Codex AGENTS.md explicit read through the host's chunk symlink.
     Edit here only — no per-project copies, no parity. -->

## Task tracking (backlog.md)

The project board (Backlog.md, under `backlog/`) is the **single source of progress** for all
forward-looking work — not memory files, doc ledgers, or an external issue tracker. `docs/adr/`
stays the only decision system and design docs, specs and plans stay in `docs/`; backlog's own
`decisions/` and `docs/` folders are unused. Per-project values — the pinned **VERSION**, the
plan-doc directory (**PLANS_DIR**), the **VERIFY_EXAMPLES** that illustrate AC, and the standing
**DoD items** — live in this project's `<!-- knobs:backlog-core -->` block, not in this chunk.

**Session start: list the board, then set your task In Progress.** `backlog task list --plain` (or
`backlog board`) to orient, then `backlog task edit <id> -s "In Progress"`. A task silently worked
while still "To Do" is invisible to the board.

**Drive the board through the `backlog` CLI only, always passing `--plain`.** The MCP server is
off: it resolves repo root once at startup and writes task files to the wrong repo from a
worktree. Backlog's generated agent-instruction files are off too — these chunks are the agent's
instructions. Never hand-edit files under `backlog/`; the CLI owns IDs, naming and frontmatter.
(`backlog/config.yml` is the one file fine to hand-edit, because `backlog config set` does not
expose `definition_of_done`.)

### Creating tasks

**Only the coordinator creates or edits tasks** — never parallel subagents or workflow agents. ID
generation is a max+1 scan, so concurrent creation collides. One exception: an attended
interactive worktree session writes board fields for the task it owns; only `task create` stays
main-repo-only (`parallel-work`).

**Create from a fresh board view — a feature branch is a stale board.** `backlog draft create` and
`task create` assign ids by a max+1 scan of the **current branch's** `backlog/`, so a branch is
blind to items added on `main` since it diverged, and the colliding id survives the merge as a
silent **duplicate**: the two files carry different name-slugs, so nothing flags a textual
conflict. Groom on `main`, or re-sync the branch with `main` before creating and re-check the ids
right before the merge.

**The same hazard owns every hand-numbered sequence in the repo** — ADRs
(`docs/adr/NNNN-slug.md`), migrations, numbered gotchas — all max+1-by-eye against the current
branch, and silent in the same way. Check the number against `main` *and* any sibling worktree
before minting one on a branch, and renumber **yours** when theirs is committed or already cited
anywhere outside its own branch: a live reference costs far more to chase than a rename.

**Populating or seeding the board, and any task decomposition, require an explicit go-ahead in
chat before the first `backlog task create` runs.** Propose the list — titles plus one-liners —
and wait for a yes. A spec that says "decompose this into tasks" names the eventual work; it does
not pre-approve a decomposition now, and a standing CLI authorization removes permission clicks on
mechanics, not decision authority over board scope. A checkpoint announced in a plan is binding
whatever the permissions allow.

### AC and DoD

- **AC (acceptance criteria) = task-specific verification**, the per-task Done-gate (e.g. the
  project's VERIFY_EXAMPLES). Check a criterion (`--check-ac N`) only as it is empirically proven;
  one that needs the user's eyes waits for them. `verify-gate` owns what the verification pass
  runs.
- **DoD (definition of done) = the standing gates that apply to every task**, held in
  `backlog/config.yml` and stamped at task-creation time — config changes do not back-propagate
  (`task edit --check-dod`/`--dod` retrofits). **The DoD list always ends in an explicit user
  sign-off item.**
- **Done requires explicit user sign-off** — never auto-close on an AC/DoD pass. Human-in-the-loop
  at all four gates: task pick → plan approval (before code) → verification → final sign-off.

### Editing a task

**Know which way an edit verb writes.** Whether a verb appends or replaces the whole field is not
readable from its name:

- `--ac` appends one criterion. **`--acceptance-criteria` appends too, despite reading as a
  setter** ("set acceptance criteria") — and it silently swallows near-duplicates (measured on
  1.45.2).
- `--append-notes` appends; **`--notes` and `--desc` replace the whole field.**
- **`--dep` and `--doc` replace their entire list** — pass the complete set.
- `--remove-ac` renumbers every criterion below the one it removes.

**Retiring one criterion? Supersede it in place.** Notes on a task and on its siblings routinely
cite criteria by index ("only AC#5 is blocked"), and removing #5 shifts #6→#5 under every one of
those citations, with no error and nothing validating the link. So rewrite an unreachable criterion as a
marker — `SUPERSEDED by task-NNN — was: '<original text>'. <why it can no longer be observed>.` To
genuinely renumber, remove indices in **descending** order and then re-add in order:

```sh
backlog task edit NNN --remove-ac 8 --remove-ac 7 --remove-ac 6 --remove-ac 5   # descending
backlog task edit NNN --ac "<new #5>" --ac "<old #6>" --ac "<old #7>" --ac "<old #8>"
```

**Task files are git-tracked: check `git status --porcelain` on the file before an edit verb, and
recover a misfire with `git checkout -- "backlog/tasks/task-NNN - ….md"`** — only when that file
was clean before the call. Otherwise the same command discards a peer's uncommitted edit to the
row along with your misfire.

### Marking Done

**Mark Done ON THE BRANCH, before the merge.** After the user signs off on the diff, run
`backlog task edit <id> --check-ac N … --check-dod 1 … -s Done` on the feature branch and commit
the task-file change there (`auto_commit` stays false, so the edit batches with code — one
task-file change per code commit). Merging never auto-closes a task; Done is set by `task edit`
only, after sign-off. Whether the task notes carry a commit SHA, and when, is a merge-model
decision this chunk defers to the `git-flow-squash` Skill — load it at integration.

With two sessions on one checkout, each session commits only the task-file edits **it made** — its
own row and any dependent rows it pinned — by explicit path; `git add -A` or `git add backlog/`
sweeps the peer's row and its In Progress edit into your commit (`git-commit-format`).

**The task↔commit link is the commit subject's `<area>/task-NNN` scope — the slice or subsystem
`<area>` plus the owning task id — and a `Refs task-NNN` footer**, which together make
`git log --grep "task-NNN"` resolve either direction. Always put the owning task in the scope so
it shows on every `git log --oneline` line, and **zero-pad the task id to 3 digits everywhere it
appears, scope and footer alike** (`task-019`, never `task-19`). Subject and footer mechanics:
`git-commit-format`.

**Board grooming not owned by one task takes a plain area scope.** New milestones, drafts,
cross-task guardrail pins: a `chore(backlog): …` subject with **no `task-NNN`**, batched into one
commit rather than one per edit.

### Standing board rules

**An open-ended trial gets an OWNING TASK, a hard timebox, and a "verdict recorded" AC.** Play,
spikes, prototypes and "see how it feels" explorations are still work; without a row they end by
drifting rather than by deciding. Put the timebox in the description ("3 days of play") and make
the AC the verdict itself — *recorded by day N whatever the state*. An inconclusive verdict
converts to registered options plus leanings, which is a result, not a failure; a soft intention
to wrap up soon is not an exit gate, the AC is.

**No internal date windows in task descriptions.** A date written into a description ("ship by
Oct 5") goes stale silently the moment the plan moves and nothing on the board flags it — one
postponement voids a whole re-dated task set while every row still reads as current. Schedule
lives in the plan doc or the ADR that owns it.

**Propagate a downstream finding onto the board before the producing task closes.** When a task —
a spike especially — produces a result that constrains or informs *other* tasks, pin it onto each
dependent: a hard requirement becomes an `--ac` there (a Done-gate), a pointer an
`--append-notes`, each naming the source task and doc. The dependent's own AC and description are
what a future session reads first; an ADR it might never open is not enough. **A finding never
goes homeless** — one that constrains no existing row still needs an owner, a new task, an ADR or
a named note, before the producing task closes.

**`dependencies:` is INERT DOCUMENTATION, not an enforced gate — never design a control on it.**
Backlog defines exactly three statuses (`To Do` / `In Progress` / `Done`), has no `Blocked` state,
computes no blocked set, and prints no blocked marker in `task list --plain`. A task whose
blockers are all open is fully claimable, and **closing a blocker sets it `Done`, which satisfies
its dependents rather than severing them** (measured 2026-07-30). "Frontier = unblocked" is
therefore a convention the humans and agents must honour — write the sequencing intent into the
AC text where a session will read it. And a row **archived** rather than closed leaves its
dependents pointing at an id that no longer resolves *and* frees that id for silent reuse, so
prefer close-in-place whenever anything depends on the row.

**The pin target must be a TASK — an AC that pins a finding onto a DRAFT is unsatisfiable by
construction.** Drafts have no edit verb at all (`backlog draft` is
`list|create|archive|promote|view`), and `task edit draft-NNN` is refused with `Task draft-NNN not
found`. The trap is the *timing*: the criterion reads as ordinary board hygiene when written, and
is discovered to be impossible only at CLOSE time, after all the work it gated is already done. So
before writing "pin X onto draft-NNN" into an `--ac`, either `draft promote` it first — which
mints a fresh task id and makes the pin reachable — or name in the AC's own text where the pin
will actually land: the owning ADR, or the producing task's notes.

**Plan docs are scratch; the board is truth.** A multi-task slice keeps a plan doc under PLANS_DIR
linked via `--doc`, with a `Tracked by: task-NNN` header, but plan-doc checkboxes are in-session
scratch and a completed plan gets a STATUS banner (executed/merged, refs) instead of trusting
ticks. Single-session tasks plan in-task via `--plan`.

**Drafts, labels, milestones.**

- **Drafts = ungrilled ideas.** `backlog draft create` captures a phase-head; promote to a task
  only once acceptance criteria are written. With no edit verb, labels are set at
  `draft create -l` time and cannot be retrofitted.
- **Labels = free-form**, multiple per item via `-l a,b`, added organically as themes emerge (the
  config `labels:` list is suggestions, not a closed vocabulary). `backlog task list` has no label
  filter — label-slicing is web-UI or grep territory.
- **Provenance: every task or draft created through an agent carries `claude-generated`**, set in
  `-l` at create time. The discriminator is the creation *mechanism*, not the idea's origin; items
  the user enters directly (web UI) stay unlabeled.
- **Milestones = phases** (`-m <phase>`, auto-created on first use).

**Public repo:** task files are repo content — same hygiene rules as code.
