<!-- chunk:implement-run | kind: value-variant | single-source: agent-skills/chunks/implement-run.md -->
<!-- Delivered by Claude @import or a Codex AGENTS.md explicit read through the host's chunk symlink.
     Edit here only — no per-project copies, no parity. -->

## Implementation runs (`/implement`)

Where the `/implement` stub and this chunk differ, this chunk wins.

**Knobs** (`<!-- knobs:implement-run -->` in the project contract file named by your host adapter):
`shape` (`subagents`, `coordinator-pane`, `workflow`; default `subagents`), `layout`
(`parallel-when-disjoint`, `serial`; default `parallel-when-disjoint`), `gate_runner` (a seat name
or `coordinator`; default `gate-runner`), `advisor` (a seat name or `none`; default `advisor`).
**The defaults apply where the block is absent.** Only `subagents` is described here; the others
are in `multi-agent-policy`'s `COORDINATOR-PANE.md` and `WORKFLOWS.md`.

**The seats**, each from a pinned definition.

- **Coordinator** — the main loop: drafts the per-phase execution spec, dispatches the other
  seats, adjudicates every finding against source, merges on the project's `git-flow-*` chunk's terms; it
  writes no implementation diff, and runs no gate where a runner resolves.
- **Implementer** — one fully specified phase, returning a handoff report; under `layout`, the
  `parallel-work` chunk's decision rule says whether it takes a worktree.
- **Advisor** — one spawn per ticket (the ticket, the spec, the first question), continued by
  message.
- **Reviewer** — the `code-reviewer` seat dispatched twice, its axis (Standards or Spec) named in
  the prompt; `/code-review`'s sub-agents are this seat.
- **Gate-runner** — the project's own `.claude/agents/gate-runner.md`; the seat re-running a gate
  never wrote the diff.

**Start sequence.** State the knob values in force, and ask only where the ticket cannot fit them.
State the role this session is on — Planner is the metered one — and if it is not
Builder, ask the owner to switch, continuing on Planner only if they say so. Read the body
for the slot-2 marker.

**Three slots**, each announced.

1. **Pre-dispatch**, always: one pass over the drafted spec, whose premises you checked against
   the source first.
2. **Pre-merge**: completeness critic and counter-critic in one consult — on unless the ticket
   body carries `Advisor: pre-dispatch only` anywhere in it (a local-file ticket carries
   it in the file).
3. **Floating**: a reading you would otherwise decide silently or put to the owner — a review
   finding you want to reject, one that would change an acceptance criterion, a ticket premise
   that reads false against the source, a gate still red after one `diagnosing-bugs` loop. A
   fourth need goes to the owner.

Never the advisor: gates, reading a diff for conformance, prose records, git mechanics,
a task scoped to named files. Read the meter before spawning it (`/usage`, or the host's
usage tool); the owner decides a tight one.

**Fallback.** Advisor unavailable — no definition this host can dispatch, meter
spent, knob `none` — hold the judgment yourself, ask the owner at the same triggers, say so.
Gate-runner unavailable: run the gates yourself and say so.

**Review.** Hand the reviewers the measurements a spec summarises, not just the spec; re-check a
refuted finding about safety or data loss; a finding proves the defect, not the remedy.

**Toggles.** `solo` turns delegation off, review stays on; `orchestrate` back on.

**After any fan-out**, sweep `git status` in every checkout the run touched before merging. A
long-running child needs a heartbeat; recipes in `COORDINATOR-PANE.md`.

**The run record.** One closing comment on the ticket — in it, where the ticket is a file — under
four headings: `Slots`, `Gates`, `Review`, `Deviations`. Post it at handoff; close in the same
approval as the push, unless acceptance needs the owner's attended run, which keeps it open.
**Leave the acceptance-criteria checkboxes unticked**; `gh issue edit --body`
replaces a body wholesale.
