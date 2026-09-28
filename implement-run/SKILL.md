---
name: implement-run
description: How one ticket is run — the run profile posted from the plan and its add-ons, the seats, the advisor's slots, the gates, the review lenses, the closing run record and the kickoff. Slash-only (/implement-run); the third-party /implement stub carries none of it.
disable-model-invocation: true
---

Loaded by name, or by path by a delegated coordinator (§ Inside a batch). A "(§ Inside a batch)"
pointer applies only inside a batch, where the delegate stands in for the owner; outside one, never
open `batch.md`. The third-party `/implement` stub carries none of this.

The files below sit beside `SKILL.md`: in the directory the loader names (`Base directory for this
skill: <path>` on a slash load), else the directory of the path `SKILL.md` was read from.

| File | Read when |
|---|---|
| `batch.md` — § Inside a batch | first, where a brief states the owner's delegation |
| `cross-repo.md` — § Cross-repo gate-runner: the target project's contract, the gate-runner substitute dispatch | where the session is rooted outside the ticket's project, or the project's `gate_runner` seat was stamped since the session started — first in the first case, at the plan step before the shape is chosen in the second; after `batch.md` where both hold |
| `defaults.yaml` — every default value, knobs and dials | at Start, every run |
| `profile.md` — § Run profile: the dial table, A light plan, An instruction file, Effort, Pins, The ratchet, Caps (the fix-round cap stop, A plan pin), The profile block, The stop | at the plan step, before posting the profile |
| `workflow-shape.md` — § Workflow shape: Launch, Resume, At return, Adoption | where `shape` resolves to `workflow` |
| `review.md` — § Review: Re-verify a fix, A command block in an instruction file, Bug hunter (the Correctness charter), Codex lens, Critic seat | when the implementer returns, before its diff is committed or any review dispatched; under `workflow`, when the script returns, and its gate-runner dispatch paragraph before launch |
| `close.md` — § Close: steps 1–4 (the kickoff, step 4), the run record, the re-cost rule | before offering the Close approval |

**Knobs**: `<!-- knobs:implement-run -->` in the project contract your host adapter names, read
from the file on disk, never an injected copy: Claude Code strips HTML-comment lines from what it
injects, so the block reads absent there though its value lines survive unmarked. A contract that cannot be read is a stop: name the path.
**Precedence**, stated here and nowhere else: a knob takes the project contract's key where
present, else `defaults.yaml`'s, per key, so a contract with no block takes every key from the file;
a `light_set` is one value either way, a numbered list in
the contract and a YAML list in the file. A dial starts at `defaults.yaml`'s value, is
derived for the plan where `profile.md` says so (the bug hunter's light-plan value, the gate tier,
`scope`'s deliverable count), is raised by a pin, and is lowered only by the owner. **Reading
`defaults.yaml`**: from disk at Start, every run, beside this file. An unreadable file, a missing
key the Skill expects, or a value outside its comment's range is a stop naming the file, key and
value — never a guess or a silent fallback. The knob statement § Start asks for names both sources
per key: `knobs: <keys> from <contract path>; <keys> from
implement-run/defaults.yaml`, every key from the file where the contract has no block.
`shape` (`subagents` | `coordinator-pane` | `workflow`), `layout` (`parallel-when-disjoint` |
`serial`), `gate_runner` (a seat or `coordinator`), `advisor` (a seat or `none`), `light_set`
(repository-relative globs, `**` matching any depth and a bare filename matching at the repository
root only, written as a numbered list under its bullet). `subagents` is described in full in these
files, `workflow`'s hand-off points in § Workflow shape; the other shapes and the
heartbeat recipes are in `multi-agent-policy`'s `COORDINATOR-PANE.md` and `WORKFLOWS.md`, read only
where that Skill's directory exists under `~/.claude/skills` or `~/.agents/skills`.

## Seats

Each from a pinned definition, dispatched by name: the `-medium` name is the `medium` dispatch, the bare
name the `high`; a seat's effort is `dials.effort` in `defaults.yaml`, raised by a pin or an add-on
(§ Run profile). A dispatch never passes `model` where the definition pins one, and passes it where
it pins none (§ Cross-repo gate-runner); a second model family on a diff is the `codex` bug-hunter
value, never an override.

- **Coordinator** — the main loop: drafts the per-phase execution spec (prose in the dispatch
  prompt, never committed unless the ticket names a home for it), dispatches, adjudicates every
  finding against source, merges. Writes no implementation diff; runs no gate where a runner
  resolves. Under a batch, a depth-1 dispatch of the `coordinator` definition (§ Inside a batch).
- **Implementer** — `implementer-medium` or `implementer` (`high`); one fully specified phase,
  returning a handoff report. `layout` says only whether two phases may be in flight at once:
  `parallel-when-disjoint` when their files are disjoint, `serial` never. Worktrees are
  `parallel-work`'s decision: one phase in flight is its single-task case and takes none; a second
  is its explicit signal, each implementer in its own tree.
- **Advisor** — `advisor`, `high` only, dialled as a whole by the `advisor` dial; slot 1, one consult
  (ticket, spec, first question); slot 3 continues it by message or spawns fresh.
- **Reviewer** — `code-reviewer-medium` or `code-reviewer` (`high`), filling
  the Spec axis, the Standards axis, the Correctness charter and the critic (§ Review), each a
  fresh dispatch with its charge named; `/code-review`'s sub-agents are this seat only when
  dispatched by the definition names the profile's `effort` line gives, for the dials that are on.
- **Gate-runner** — the project's `.claude/agents/gate-runner.md`, `medium` only. Whoever re-runs a
  gate never wrote the diff. Out of a session's reach when rooted elsewhere: § Cross-repo
  gate-runner. Its dispatch: § Review.

**Toggles**: `solo` turns delegation off, review stays on; `orchestrate` turns it back on.

A long-running seat needs a heartbeat: `COORDINATOR-PANE.md`'s recipes, under the Knobs install gate.

## Start

The chain is **pick → plan → profile → stop, only on an add-on or pin → implement → verify →
sign-off**. Every run, whatever its size, posts a plan: 1–5 chat bullets naming the
changed paths, the deliverable count and the expected implementer calls, which the profile reads.
Read the ticket's `Pins:` line and any tier sentence, set the profile (§ Run profile), and post
plan and profile block together; where the stop fires, get approval before code. Verify is the
`verify-gate` Chunk; sign-off is the Done gate the project's tracker chunk sets, or its own inline
rule.

State the knob values in force, asking only where the ticket cannot fit them, and this session's
role; if it is not Builder, ask the owner to switch (§ Inside a batch), and stay on Planner (the
metered role) only on their say-so.

**Close any stateful editor for the dispatch window**: it is a second writer whose in-memory flush
lands after the gates read the tree, so stale state passes green. Reopen it after standdown; under
a worktree this lapses.

## Advisor slots

Announce each.

1. **Pre-dispatch**, spawned wherever the `advisor` dial is on, held otherwise (Fallback). After
   checking the drafted spec's premises against source, one pass looks for a false or unverified
   premise, a missing hard limit, an observable that cannot go red, and — pasted verbatim — *what
   will this run raise that the ticket does not list?* Check the spec's *mechanisms* against its
   stated *intent* too: no review or gate written from the spec can catch a mechanism that contradicts it. **A prose deliverable** (record, Skill, Chunk) loads in no
   gate: its observable is an independent reader given the source rows, not the writer's table,
   calibrated by one planted absent row whose count is read, beside a fresh agent's playthrough of
   it.
2. Retired: pre-merge is the critic seat (§ Review).
3. **Floating**, wherever the `advisor` dial is on — a reading you would otherwise decide silently
   or put to the owner: a review finding you want to reject, one that would change an acceptance
   criterion, a ticket premise reading false against source, a gate still red after one
   `diagnosing-bugs` loop. A fourth need goes to the owner (§ Inside a batch).

Never the advisor: gates, reading a diff for conformance, prose records, git mechanics, a task
scoped to named files. Read the meter before spawning; the owner decides a tight one
(§ Inside a batch).

**Fallback.** A tight meter funds slot 1; slot 3's triggers then go to the owner
(§ Inside a batch), and the critic, a Builder seat, spends no Planner meter. Advisor off (the owner
lowered it), or unavailable (no definition this host can dispatch, meter spent, knob `none`):
hold the judgment yourself, ask the owner at the same triggers (§ Inside a batch), say so. That is
self-review unless slot 1's observable that cannot go red becomes a question the implementer's
dispatch prompt asks before it writes code. Gate-runner unavailable (the target project stamps
none) or knob `coordinator` (the target project's where the session is rooted elsewhere, § Cross-repo
gate-runner): run the gates yourself, say so.

## Handoffs

Give every constrained seat the reason for each constraint: only a *why* can be refuted, often by
that seat alone.

Passing work to the user mid-slice, restate the invariants it depends on (the state that must not
move, the step that must precede a save, how many things may be in flight), even if a prior round
covered them, since the handoff is read alone; then verify the returned state against those
invariants, since the user reports the instruction they followed, not the invariant.

**Claude Code only.** A seat inherits the session's MCP servers and permission mode, so its dispatch
prompt forbids any MCP server the project keeps to the coordinator and restates the contract's hard
limits. A seat can also be handed stale copies: its definition until the host's lazy refresh lands,
and the `@`-imported contract as the parent's session-start snapshot. Where the run's diff so far
changes either, the dispatch prompt has the seat read it off disk and say whether it differed; the
coordinator re-reads a changed contract too.
