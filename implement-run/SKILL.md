---
name: implement-run
description: How one ticket is run — the run profile posted from the plan and its add-ons, the seats, the advisor's slots, the gates, the review lenses, the closing run record and the kickoff. Slash-only (/implement-run); the third-party /implement stub carries none of it.
disable-model-invocation: true
---

Loaded by name, or by path by a delegated coordinator (§ Inside a batch). The third-party
`/implement` stub carries none of this and stays unedited, unshadowed and unwrapped.

The files below sit beside `SKILL.md`: in the directory the loader names (`Base directory for this
skill: <path>` on a slash load), else the directory of the path `SKILL.md` was read from (a delegated
coordinator reads it by path).

| File | Read when |
|---|---|
| `defaults.yaml` — every default value, knobs and dials | at Start, every run |
| `profile.md` — § Run profile: the dial table, A light plan, An instruction file, Effort, Pins, The ratchet, Caps (the fix-round cap stop, A plan pin), The profile block, The stop | at the plan step, before posting the profile |
| `review.md` — § Review: Re-verify a fix, A command block in an instruction file, Bug hunter (the Correctness charter), Codex lens, Critic seat | when the implementer returns, before its diff is committed or any review dispatched; under `workflow`, when the script returns |
| `close.md` — § Close: steps 1–4 (the kickoff, step 4), the run record, the re-cost rule | before offering the Close approval |
| `batch.md` — § Inside a batch | first, where a brief states the owner's delegation |
| `cross-repo.md` — § Cross-repo gate-runner: the target project's contract, the gate-runner substitute dispatch | where the session is rooted outside the ticket's project, or the project's `gate_runner` seat was stamped since the session started — first in the first case, at the plan step before the shape is chosen in the second; after `batch.md` where both hold |
| `workflow-shape.md` — § Workflow shape: Launch, Resume, At return, Adoption | where `shape` resolves to `workflow` |

**Knobs**: `<!-- knobs:implement-run -->` in the project contract your host adapter names, read
from the file on disk, never from a copy injected into your context: Claude Code strips every
HTML-comment line from what it injects, so the marker, and with it the block, reads absent there,
though its value lines survive unmarked. A contract that cannot be read is a stop: name the path.
**Precedence**, stated here and nowhere else: a knob takes the project contract's key where
present, else `defaults.yaml`'s — per key, so a contract with no block, or a block lacking a key,
takes the file's value for each key it lacks; a `light_set` is one value either way, a numbered
list in the contract and a YAML list in the file. A dial starts at `defaults.yaml`'s value, is
derived for the plan where `profile.md` says so (the bug hunter's light-plan value, the gate tier,
`scope`'s deliverable count), is raised by a pin, and is lowered only by the owner. **Reading
`defaults.yaml`**: read it from disk at Start, every run, beside this file by the rule above. A file
that cannot be read, a key the Skill expects that is missing, or a value outside the range its
comment gives is a stop naming the file, the key and the value — never a guess and never a silent
fallback, since no other file holds a value to fall back on. The knob statement § Start asks for
names both sources per key: `knobs: <keys> from <contract path>; <keys> from
implement-run/defaults.yaml`, every key from the file where the contract has no block.
`shape` (`subagents` | `coordinator-pane` | `workflow`), `layout`
(`parallel-when-disjoint` | `serial`), `gate_runner` (a seat or
`coordinator`), `advisor` (a seat or `none`), `light_set`
(repository-relative globs, `**` matching any depth and a bare filename matching at the repository
root only, written as a numbered list under its bullet). `subagents` is described in full in this Skill's files, and `workflow`'s hand-off
points in § Workflow shape; the other shapes and the heartbeat recipes are in `multi-agent-policy`'s
`COORDINATOR-PANE.md` and `WORKFLOWS.md`, read only where that Skill's directory exists under
`~/.claude/skills` or `~/.agents/skills`.

§ Inside a batch: read `batch.md` first, where a brief states the owner's delegation.

§ Cross-repo gate-runner: read `cross-repo.md` where the session is rooted outside the ticket's project, or the project's `gate_runner` seat was stamped since the session started — first in the first case, at the plan step before the shape is chosen in the second; after `batch.md` where both hold.

## Seats

Each from a pinned definition, dispatched by name: the `-medium` name is the `medium` dispatch and the
bare name the `high`, which one a seat gets being `dials.effort` in `defaults.yaml`, raised by a pin
or an add-on (§ Run profile). No dispatch of a definition that pins a model passes `model`: the
model is pinned by role in the definition, and a second model family on a diff is the `codex`
bug-hunter value, never an override. One whose definition pins none passes it (§ Cross-repo
gate-runner).

- **Coordinator** — the main loop: drafts the per-phase execution spec (prose in the dispatch
  prompt, never committed unless the ticket names a home for it), dispatches, adjudicates every
  finding against source, merges. Writes no implementation diff; runs no gate where a runner
  resolves. Under a batch, a depth-1 dispatch of the `coordinator` definition (§ Inside a batch).
- **Implementer** — `implementer-medium` or `implementer` (`high`); one fully specified phase,
  returning a handoff report. `layout` says only whether two phases may be in flight at once:
  `parallel-when-disjoint` when their files are disjoint, `serial` never. Worktrees are
  `parallel-work`'s decision: one phase in flight is its single-task case and takes none; a second
  is its explicit signal, each implementer in its own tree.
- **Advisor** — `advisor`, `high` only, dialled as a whole by the `advisor` dial (`dials.advisor` in `defaults.yaml`); slot 1, one consult (ticket, spec, first question); slot 3
  continues it by message or spawns fresh.
- **Reviewer** — `code-reviewer-medium` or `code-reviewer` (`high`), filling
  the Spec axis, the Standards axis, the Correctness charter and the critic (§ Review), each a
  fresh dispatch with its charge named; `/code-review`'s sub-agents are this seat only when
  dispatched by the definition names the profile's `effort` line gives, for the dials that are on.
- **Gate-runner** — the project's `.claude/agents/gate-runner.md`, `medium` only. Whoever re-runs a
  gate never wrote the diff. Out of a session's reach when rooted elsewhere: § Cross-repo gate-runner. In
  every shape its dispatch (§ Workflow shape, `gateTier`) names the checkout and the profile's
  `gate tier` spelled out as only the gates to run: each of `verify-gate`'s five it takes by its
  knob key, `build` carrying `build_check`, which is never listed as its own gate; any other gate (a
  project gate, a trigger-table pull, a key of the `<!-- knobs:verify-gate -->` block beyond the
  eight the engine stamps — the five, `build_check`, `dir`, `env`) by name with its command as given
  (the contract's trigger table or knob value, or the seat's `## Project gates`), reading that
  block's keys and values alike on disk, as Knobs says. It lists none left out: the seat derives
  none and marks those itself.

**Toggles**: `solo` turns delegation off, review stays on; `orchestrate` turns it back on.

A long-running seat needs a heartbeat; the recipes are in `COORDINATOR-PANE.md`, under the Knobs
install gate.

§ Run profile: read `profile.md` at the plan step, before posting the profile.

## Start

The chain is **pick → plan → profile → stop, only on an add-on or pin → implement → verify →
sign-off**. Every run plans and posts the plan, whatever its size: 1–5 chat bullets naming the
changed paths, the deliverable count and the expected implementer calls, which the profile reads.
Read the ticket's `Pins:` line and any tier sentence, set the profile (§ Run profile), and post
plan and profile block together; where the stop fires, get approval before code. Plan by question
type: fuzzy idea → `grilling`; data-model or state-machine doubt → `prototype`; look-and-feel doubt
→ a minimal build and an `agent-browser` screenshot loop; codebase-bound, clear what, unclear how →
plan mode. Verify is the `verify-gate` Chunk; sign-off is the Done gate the project's tracker chunk
sets, or its own inline rule.

State the knob values in force, asking only where the ticket cannot fit them, and this session's
role; if it is not Builder, ask the owner to switch (§ Inside a batch), and stay on Planner (the
metered role) only on their say-so.

**Close any stateful editor for the dispatch window**: it is a second writer whose in-memory flush
lands after the gates read the tree, so stale state passes green. Commit nothing inside the
window; reopen it after standdown. Under a worktree this lapses.

## Advisor slots

Announce each.

1. **Pre-dispatch**, spawned wherever the `advisor` dial is on, held otherwise (Fallback). After
   checking the drafted spec's premises against source, one pass looks for a false or unverified
   premise, a missing hard limit, an observable that cannot go red, and — pasted verbatim — *what
   will this run raise that the ticket does not list?* It names no claim of yours, so it audits
   your world, not your sentence. The advisor definition's fourth differs — a finding it supplies,
   not a question you ask; never sync the lists. Check the spec's *mechanisms* against its stated
   *intent* too: no review or gate written from the spec can catch a mechanism that contradicts
   it, since the deliverable matches. **A prose deliverable** (record, Skill, Chunk) loads in no
   gate: its observable is an independent reader given the source rows, not the writer's table,
   calibrated by one planted absent row whose count is read, beside a fresh agent's playthrough of
   it.
2. **Pre-merge** — now the critic seat, a Builder dispatch under the `critic` dial (§ Review); no advisor consult.
3. **Floating**, wherever the `advisor` dial is on — a reading you would otherwise decide silently
   or put to the owner: a review finding you want to reject, one that would change an acceptance
   criterion, a ticket premise reading false against source, a gate still red after one
   `diagnosing-bugs` loop. A fourth need goes to the owner (§ Inside a batch).

Never the advisor: gates, reading a diff for conformance, prose records, git mechanics, a task
scoped to named files. Read the meter before spawning; the owner decides a tight one
(§ Inside a batch).

**Fallback.** A tight meter funds slot 1; slot 3's triggers then go to the owner
(§ Inside a batch), and the critic, a Builder seat, spends no Planner meter. Advisor off (the owner
lowered it), or unavailable (no definition this host can dispatch, meter spent, knob `none`): hold the
judgment yourself, ask
the owner at the same triggers (§ Inside a batch), say so. That is self-review unless slot 1's
observable that cannot go red becomes a question the implementer's dispatch prompt asks before it
writes code — a spec's author is the last reader to see that an observable does not mean what they
intended. Gate-runner unavailable (the target project stamps none) or knob `coordinator` (the target
project's where the session is rooted elsewhere, § Cross-repo gate-runner): run the gates yourself, say so.

## Handoffs

Give every constrained seat the reason for each constraint: a bare constraint is followed
silently, and only its *why* can be refuted, often by that seat alone.

Passing work to the user mid-slice, restate the invariants it depends on — the state that must not
move, the step that must precede a save, how many things may be in flight — even if a prior round
covered them; the handoff is read alone. Verify the returned state against those invariants: the
user reports the instruction they followed, not the invariant.

§ Review: read `review.md` when the implementer returns, before its diff is committed or any review dispatched; under `workflow`, when the script returns.

§ Workflow shape: read `workflow-shape.md` where `shape` resolves to `workflow`.

§ Close: read `close.md` before offering the Close approval.
