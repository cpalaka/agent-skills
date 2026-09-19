<!-- chunk:implement-run | kind: value-variant | single-source: agent-skills/chunks/implement-run.md -->
<!-- Delivered by Claude @import or a Codex AGENTS.md explicit read through the host's chunk symlink.
     Edit here only — no per-project copies, no parity. -->

## Implementation runs (`/implement`)

Where the `/implement` stub and this chunk differ, this chunk wins.

**Knobs** (`<!-- knobs:implement-run -->` in the project contract file named by your host adapter):
`shape` (`subagents`, `coordinator-pane`, `workflow`; default `subagents`), `layout`
(`parallel-when-disjoint`, `serial`; default `parallel-when-disjoint`), `gate_runner` (a seat name
or `coordinator`; default `gate-runner`), `advisor` (a seat name or `none`; default `advisor`).
**The defaults apply where the block is absent.** Only `subagents` is described here;
`coordinator-pane` and `workflow` are in `multi-agent-policy`'s `COORDINATOR-PANE.md` and
`WORKFLOWS.md`, where that skill is installed (its directory exists under `~/.claude/skills` or
`~/.agents/skills`); where it is not, skip that read.

**The seats**, each from a pinned definition.

- **Coordinator** — the main loop: drafts the per-phase execution spec, dispatches the other
  seats, adjudicates every finding against source, merges on the project's `git-flow-*` chunk's
  terms; it writes no implementation diff, and runs no gate where a runner resolves. **The
  execution spec is prose in the dispatch prompt, not a file** — nothing commits it; a ticket that
  wants a durable spec says so and names where it goes.
- **Implementer** — one fully specified phase, returning a handoff report. `layout` says only
  whether two phases may be in flight at once: `parallel-when-disjoint` allows it where the phases
  touch disjoint files, `serial` never does. **Neither value is a worktree decision** — one phase
  in flight is `parallel-work`'s single-task case and takes no worktree, and putting a **second**
  in flight is itself the explicit parallel-work signal, so both resolve on that chunk's decision
  rule and each implementer is confined to its own tree.
- **Advisor** — one spawn per ticket (the ticket, the spec, the first question), continued by
  message.
- **Reviewer** — the `code-reviewer` seat dispatched twice, its axis (Standards or Spec) named in
  the prompt; `/code-review`'s sub-agents are this seat.
- **Gate-runner** — the project's own `.claude/agents/gate-runner.md`; the seat re-running a gate
  never wrote the diff.

**Start sequence.** State the knob values in force, asking only where the ticket cannot fit them.
State the role this session is on — Planner is the metered one — and if it is not Builder, ask the
owner to switch, continuing on Planner only if they say so. Read the body for the slot-2 marker.

**Three slots**, each announced.

1. **Pre-dispatch**, always: one pass over the drafted spec, whose premises you checked against
   the source first — looking for a false or unverified premise, **a missing hard limit, an
   observable that cannot go red, and a fourth you paste verbatim:** *what will this run raise that
   the ticket does not list?* — it names no claim of yours, so it audits your world, not your
   sentence. Check the spec's prescribed *mechanisms* against its own stated *intent*, not only its
   premises against the source: neither a conformance review nor a gate written from that spec can
   catch a mechanism that contradicts it, because the code matches. **A prose deliverable** (a
   record, a Skill, a Chunk) loads in no gate: its observable is an independent reader given the
   source rows, not the writer's table, calibrated by one planted absent row whose count is read,
   beside a playthrough by a fresh agent following it.
2. **Pre-merge**: completeness critic and counter-critic in one consult — on unless the ticket
   body carries `Advisor: pre-dispatch only` anywhere in it (a local-file ticket carries
   it in the file).
3. **Floating**: a reading you would otherwise decide silently or put to the owner — a review
   finding you want to reject, one that would change an acceptance criterion, a ticket premise
   that reads false against the source, a gate still red after one `diagnosing-bugs` loop. A
   fourth need goes to the owner.

Never the advisor: gates, reading a diff for conformance, prose records, git mechanics,
a task scoped to named files. Read the meter before spawning it; the owner decides a tight one.

**Fallback.** **One affordable slot:** keep slot 1 and ask the advisor for its pre-merge reading —
given before the diff exists, so the record names it the capped form, never slot 2.
Advisor unavailable — no definition this host can dispatch, meter spent, knob `none` — hold the
judgment yourself, ask the owner at the same triggers, say so.
Holding it yourself **is** self-review unless slot 1's **observable that cannot go red** goes to
the implementer as a question its dispatch prompt asks before it writes code — a spec's author is
the last reader who can see that an observable does not mean what they intended.
Gate-runner unavailable: run the gates yourself and say so.

**Every constrained seat gets the reasoning behind the constraint, not just the constraint.** A
constraint arrives as an instruction the seat follows silently; only its *why* can be refuted, and
the seat is often the one reader positioned to refute it (measured 2026-09-19).

**Review.** Hand the reviewers the measurements a spec summarises, not just the spec; re-check a
refuted finding about safety or data loss; a finding proves the defect, not the remedy. After
fixes, re-run the affected checks and take a targeted review, reopening the full one only where
the scope or the assumptions changed. A third-party review is optional and answers a specific
remaining question; absent external tooling never blocks the native pair.

**Toggles.** `solo` turns delegation off, review stays on; `orchestrate` back on.

**After any fan-out**, sweep `git status` in every checkout the run touched before merging. A
long-running child needs a heartbeat; recipes are in `multi-agent-policy`'s `COORDINATOR-PANE.md`
under the Knobs paragraph's install gate.

**The run record.** One closing comment on the ticket — in it, where the ticket is a file — under
four headings: `Slots`, `Gates`, `Review`, `Deviations`.

**Posting it, the merge and the close are one approval, not three** — separate asks buy round
trips and gate nothing the first approval covered. Offer the diff, the record and the close
in one message, saying which acceptance reading you took and why, and act on the single yes.
A ticket whose acceptance needs the owner's attended run stays open: the push is not the
acceptance.

**Never rewrite the ticket's body — append a comment.** `gh issue edit --body` and its equivalents
replace a body wholesale, and the body is the spec, so an edit to tick one acceptance checkbox can
silently take the spec with it. Leave the checkboxes for the owner, and put every observation,
verdict and piece of evidence in an append-only comment.
