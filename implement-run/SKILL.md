---
name: implement-run
description: How one ticket is run — the seat tier, the seats, the advisor's slots, the gates, the review lenses, the closing run record and the kickoff. Slash-only (/implement-run); the third-party /implement stub carries none of it.
disable-model-invocation: true
---

Loaded only by name. The third-party `/implement` stub carries none of this and stays unedited,
unshadowed and unwrapped.

**Knobs**: `<!-- knobs:implement-run -->` in the project contract your host adapter names; defaults
apply where it is absent. `shape` (`subagents` | `coordinator-pane` | `workflow`; default
`subagents`), `layout` (`parallel-when-disjoint` | `serial`; default `parallel-when-disjoint`),
`gate_runner` (a seat or `coordinator`; default `gate-runner`), `advisor` (a seat or `none`;
default `advisor`). `subagents` is described here in full, and `workflow`'s hand-off points in
§ Workflow shape; the other shapes and the heartbeat recipes are in `multi-agent-policy`'s
`COORDINATOR-PANE.md` and `WORKFLOWS.md`, read only where that Skill's directory exists under
`~/.claude/skills` or `~/.agents/skills`.

## Seats

Each from a pinned definition.

- **Coordinator** — the main loop: drafts the per-phase execution spec (prose in the dispatch
  prompt, never committed unless the ticket names a home for it), dispatches, adjudicates every
  finding against source, merges. Writes no implementation diff; runs no gate where a runner
  resolves. Phase-size target: **60 implementer calls**; a phase the drafter expects to exceed it
  is split before dispatch. Cost is near-linear in calls, $0.15–0.20 each; in the token-usage
  audit behind cpalaka/agent-skills#68, phases at or under 60 calls cost $1–9, 60–85 cost $8–10,
  past 85 $13–32.
- **Implementer** — one fully specified phase, returning a handoff report. `layout` says only
  whether two phases may be in flight at once: `parallel-when-disjoint` when their files are
  disjoint, `serial` never. Worktrees are `parallel-work`'s decision: one phase in flight is its
  single-task case and takes none; a second is its explicit signal, each implementer in its own
  tree.
- **Advisor** — slot 1, one consult (ticket, spec, first question); slot 3 continues it by message
  or spawns fresh.
- **Reviewer** — `code-reviewer`, dispatched twice with its axis (Standards, Spec) named;
  `/code-review`'s sub-agents are this seat. The same seat fills the Correctness fallback and the
  critic (§ Review), each a fresh dispatch.
- **Gate-runner** — the project's `.claude/agents/gate-runner.md`. Whoever re-runs a gate never
  wrote the diff.

**Toggles**: `solo` turns delegation off, review stays on; `orchestrate` turns it back on.

A long-running seat needs a heartbeat; the recipes are in `COORDINATOR-PANE.md`, under the Knobs
install gate.

## Seat tier

`Seats: light` or `Seats: full` sits on its own line in the ticket body, placed by the project
contract's convention. Absent, malformed, or contradicted by the ticket's named files (checked
before dispatch) or by the implementer's diff (checked at the certifying round) reads full; every
upgrade goes under `Deviations`. A light line the named files contradict takes the plan stop after
all: the run is full.

**Light** is a documentation-and-records diff: every changed path is documentation, a decision
record, a results record or tracker prose, none loaded by a gate or named by a trigger; a project
contract may name its light set. Refactors, tooling and configuration never qualify by kind, and no
Skill, seat definition or Chunk body a session loads is light, prose though it is. Light keeps the
implementer, gate-runner and Spec-axis reviewer only, striking every advisor slot, the Standards
axis, the bug hunter (Codex lens and fallback) and the critic: a diff no gate loads has no runtime
surface to hunt, the Standards axis cost a full dispatch (8 calls) on the one measured docs run
while the project's gate scans still run, and a docs ticket should spend no Planner consult. A
certifying-round upgrade adds the Standards axis, lens and critic; slot 1's moment has passed, and
the record says so.

A ticket body still carrying `Advisor: pre-dispatch only` runs full: the marker is retired, noted
under `Deviations`.

## Start

The chain is **pick → plan approval → implement → verify → sign-off**. Plan approval is a gate:
for non-trivial scope, plan in 1–5 chat bullets and get approval before code; one-line fixes,
token tweaks and doc edits skip it. Plan by question type: fuzzy idea → `grilling`; data-model or
state-machine doubt → `prototype`; look-and-feel doubt → a minimal build and an `agent-browser`
screenshot loop; codebase-bound, clear what, unclear how → plan mode. Verify is the `verify-gate`
Chunk;
sign-off is the Done gate the project's tracker chunk sets, or its own inline rule.
Light tickets (§ Seat tier) skip plan approval, as one-line fixes and doc edits already do. The
approval message carries the roster line with the tier defaults applied:
`Seats: implementer, gate-runner, reviewer (Standards), reviewer (Spec), advisor, codex — strike by name`
A struck seat goes under `Deviations`; striking `codex` strikes its fallback too (§ Review). The
critic is not on the line: it runs on every full-tier ticket.

State the knob values in force, asking only where the ticket cannot fit them, and this session's
role; if it is not Builder, ask the owner to switch, and stay on Planner (the metered role) only on
their say-so. Read the ticket's `Seats:` line (§ Seat tier).

**Close any stateful editor for the dispatch window**: it is a second writer whose in-memory flush
lands after the gates read the tree, so stale state passes green. Commit nothing inside the
window; reopen it after standdown. Under a worktree this lapses.

## Advisor slots

Announce each.

1. **Pre-dispatch**, on the full tier, always, spawned or held (Fallback). After checking the
   drafted spec's premises against source, one pass looks for a false or unverified premise, a
   missing hard limit, an observable that cannot go red, and — pasted verbatim — *what will this run
   raise that the ticket does not list?* It names no claim of yours, so it audits your world, not
   your sentence. The advisor definition's fourth differs — a finding it supplies, not a question
   you ask; never sync the lists. Check the spec's *mechanisms* against its stated *intent* too: no
   review or gate written from the spec can catch a mechanism that contradicts it, since the
   deliverable matches. **A prose deliverable** (record, Skill, Chunk) loads in no gate: its
   observable is an independent reader given the source rows, not the writer's table, calibrated by
   one planted absent row whose count is read, beside a fresh agent's playthrough of it.
2. **Pre-merge** — now the critic seat, a Builder dispatch (§ Review); no advisor consult.
3. **Floating**, on the full tier — a reading you would otherwise decide silently or put to the
   owner: a review finding you want to reject, one that would change an acceptance criterion, a
   ticket premise reading false against source, a gate still red after one `diagnosing-bugs` loop.
   A fourth need goes to the owner.

Never the advisor: gates, reading a diff for conformance, prose records, git mechanics, a task
scoped to named files. Read the meter before spawning; the owner decides a tight one.

**Fallback.** A tight meter funds slot 1; slot 3's triggers then go to the owner, and the critic,
a Builder seat, spends no Planner meter. Advisor unavailable (no definition this host can
dispatch, meter spent, knob `none`): hold the judgment yourself, ask the owner at the same
triggers, say so. That is self-review unless slot 1's observable that cannot go red becomes a
question the implementer's dispatch prompt asks before it writes code — a spec's author is the last
reader to see that an observable does not mean what they intended. Gate-runner unavailable or knob
`coordinator`: run the gates yourself, say so.

## Handoffs

Give every constrained seat the reason for each constraint: a bare constraint is followed
silently, and only its *why* can be refuted, often by that seat alone.

Passing work to the user mid-slice, restate the invariants it depends on — the state that must not
move, the step that must precede a save, how many things may be in flight — even if a prior round
covered them; the handoff is read alone. Verify the returned state against those invariants: the
user reports the instruction they followed, not the invariant.

## Review

Full tier: **native axes → Codex lens (or its fallback) → critic → adjudication → fix commits →
merge**; light takes the Spec axis alone. Hand reviewers the measurements a spec summarises, not
just the spec. Re-check a refuted finding about safety or data loss. A finding proves the defect,
not the remedy. After fixes, re-run the affected checks and take a targeted review; reopen the full
one only where scope or assumptions changed.

**Codex lens**, once both native axes return:

```
node "<installPath>/scripts/codex-companion.mjs" adversarial-review --json --base <fixed point> -- "$(cat <focus file>)" < /dev/null
```

`<installPath>` is read at run time, since a version bump moves it: the `user`-scope element, or the
sole one, of the `plugins["codex@openai-codex"]` list in `~/.claude/plugins/installed_plugins.json`.
Sandbox off: the Codex CLI needs network egress and the certificate store, which the sandbox denies.
Focus: the ticket's acceptance criteria verbatim plus the execution spec's hard limits, staged in a
file inside the repository and removed after. The script takes focus only as positional text, with
no focus-file flag, and acceptance criteria carry backticks and quotes that an inline argument would
execute or end on; content read through `$(cat …)` is not re-parsed, and `--` ends the options, so a
focus beginning with a flag name is still read as text. Inside the repository, because sandboxed and
unsandboxed shells resolve different temporary directories. `--base` reviews only commits while
Codex reads the live tree, so commit the implementer's diff first, and **fix commits wait for the
lens**. It has no timeout of its own: take the host's longest foreground timeout or its background
mode, capturing stdout, never the plugin's `--background`/`result` route (its job record nests the
payload differently); a timeout under a shorter budget is yours to re-run.

Record `LENS codex: <verdict> — <n> findings — <bytes> bytes` under `Review` (`.result.verdict`, the
count of `.result.findings`, output bytes). A null `.result`, a `.parseError`, zero bytes, a
non-zero exit, or a failure before output (binary absent, not authenticated, registry unreadable —
no such key or element — quota, timeout at the longest budget) is `LENS codex: NOT RUN — <why>`. Its
recommendations are hypotheses; adjudicate every finding against source.

**Fallback: any NOT RUN fires the Correctness charter** — another `code-reviewer` dispatch over the
same diff: *for each defect, what can go wrong, why the path is vulnerable, the likely impact, one
clause of remedy; material findings only; end with `FINDINGS: n`*, recorded
`LENS correctness: FINDINGS: <n>`. One clause of remedy, because a finding proves the defect, not
the remedy; material only, because you adjudicate each; `FINDINGS: n`, so the record reads a count,
not an impression. The loop is never without a bug hunter and never runs two by default. One
exception: the owner's plan-stop strike, `LENS codex: STRUCK — owner, plan stop`, is not NOT RUN and
fires no fallback.

**Critic seat**, after every lens, before the merge, on every full-tier ticket in every shape: a
fresh `code-reviewer` given the diff since the fixed point, the ticket, the execution spec and every
review's output, charged: *completeness critic — what the reviewers and the lens missed and where
their method erred: absence claims refuted by evidence outside a finder's scope, category errors, a
survivor one arm shares and was not charged with; counter-critic — which findings source refutes,
and which remedies add generality the spec never asked for.* Recorded `CRITIC: <n> findings`. A
Builder seat after the lenses reads the real diff and every review, and spends no Planner meter.

## Workflow shape

Hand-off points only. Before the script, you draft the execution spec and take the plan stop; it
runs the implementer, the certifying gate, the native axes and at most one fix round; on its return
you run the Codex lens over its result, dispatch the critic, adjudicate, merge and write the record.
It never merges, writes the tracker or asks a question — none of those reaches a human turn from
inside it. The script's fix round precedes the lens, so the script leaves its work committed —
`--base` reads only commits — and fix commits after the lens are yours. Its launch, resume and
adoption rules land with the script, a later ticket; until then `subagents` runs.

## Close

1. Sweep `git status` in every checkout the run touched, after any fan-out.
2. **Load `git-flow-squash`**, or the `git-flow-*` Skill the project's Profile `fork:` names,
   before the merge. Nothing fires it from context (description-matched triggering: 1 invocation
   in 105 sessions, measured on another Skill), and a squash without its clauses fails silently
   toward a lost tree: a peer's unpushed commit riding the push, a branch deleted against a moved
   `main`, an approval spent on a tree that no longer exists.
3. **One approval covers posting the run record, the merge and the close.** Offer the diff, the
   record and the close in one message, naming the acceptance reading you took and why; act on
   the single yes. A ticket whose acceptance needs the owner's attended run stays open: the push
   is not the acceptance.
4. **Emit the kickoff** once step 3's actions land, a ticket left open for the owner included, as
   its own message, unfenced: `/implement-run <n>` for the lowest ticket on the tracker chunk's
   frontier. An empty frontier takes the contract's frontier-empty instruction; where it names
   none, say the frontier is empty — and where the tracker's query cannot tell an empty frontier
   from an unminted label, run its label check and report which. Nothing else follows — no other
   query, no grill, no wrap: the run record is the tracker write, the kickoff the handoff.

**The run record** is one closing comment on the ticket (in the file, for a file ticket) under
`Slots`, `Gates`, `Review`, `Deviations`. The body is the spec: append, never rewrite —
`gh issue edit --body` and its equivalents replace it wholesale, so ticking one checkbox can take
the spec with it. Checkboxes are the owner's; every observation, verdict and piece of evidence
goes in a comment.

**A criterion your run missed is the owner's to re-cost; the ask must not make your reading the
default.** *The criterion was wrong* is an overrun's predictable output, and sometimes true; with
the deliverable already on disk, *land it and decide later* installs your preference by silence.
Produce the alternative as an artifact the owner can diff, not a number you describe, and leave
the criterion unticked either way.
