---
name: implement-run
description: How one ticket is run — the seats, the advisor's three slots, the gates, the review and the closing run record. Slash-only (/implement-run); the third-party /implement stub carries none of it.
disable-model-invocation: true
---

Loaded only by name. The third-party `/implement` stub carries none of this and stays unedited,
unshadowed and unwrapped.

**Knobs**: `<!-- knobs:implement-run -->` in the project contract your host adapter names; defaults
apply where it is absent. `shape` (`subagents` | `coordinator-pane` | `workflow`; default
`subagents`), `layout` (`parallel-when-disjoint` | `serial`; default `parallel-when-disjoint`),
`gate_runner` (a seat or `coordinator`; default `gate-runner`), `advisor` (a seat or `none`;
default `advisor`). Only `subagents` is described here; the other shapes and the heartbeat recipes
are in `multi-agent-policy`'s `COORDINATOR-PANE.md` and `WORKFLOWS.md`, read only where that
Skill's directory exists under `~/.claude/skills` or `~/.agents/skills`.

## Seats

Each from a pinned definition.

- **Coordinator** — the main loop: drafts the per-phase execution spec (prose in the dispatch
  prompt, never committed unless the ticket names a home for it), dispatches, adjudicates every
  finding against source, merges. Writes no implementation diff; runs no gate where a runner
  resolves.
- **Implementer** — one fully specified phase, returning a handoff report. `layout` says only
  whether two phases may be in flight at once: `parallel-when-disjoint` when their files are
  disjoint, `serial` never. Worktrees are `parallel-work`'s decision: one phase in flight is its
  single-task case and takes none; a second is its explicit signal, each implementer in its own
  tree.
- **Advisor** — spawned once per ticket (ticket, spec, first question), continued by message.
- **Reviewer** — `code-reviewer`, dispatched twice with its axis (Standards, Spec) named;
  `/code-review`'s sub-agents are this seat.
- **Gate-runner** — the project's `.claude/agents/gate-runner.md`. Whoever re-runs a gate never
  wrote the diff.

**Toggles**: `solo` turns delegation off, review stays on; `orchestrate` turns it back on.

A long-running seat needs a heartbeat; the recipes are in `COORDINATOR-PANE.md`, under the Knobs
install gate.

## Start

The chain is **pick → plan approval → implement → verify → sign-off**. Plan approval is a gate:
for non-trivial scope, plan in 1–5 chat bullets and get approval before code; one-line fixes,
token tweaks and doc edits skip it. Plan by question type: fuzzy idea → `grilling`; data-model or
state-machine doubt → `prototype`; look-and-feel doubt → a minimal build and an `agent-browser`
screenshot loop; codebase-bound, clear what, unclear how → plan mode. Verify is the `verify-gate`
Chunk;
sign-off is the Done gate the project's tracker chunk sets, or its own inline rule.

State the knob values in force, asking only where the ticket cannot fit them, and this session's
role; if it is not Builder, ask the owner to switch, and stay on Planner (the metered role) only on
their say-so. Read the ticket body for slot 2's `Advisor: pre-dispatch only` marker.

**Close any stateful editor for the dispatch window**: it is a second writer whose in-memory flush
lands after the gates read the tree, so stale state passes green. Commit nothing inside the
window; reopen it after standdown. Under a worktree this lapses.

## Advisor slots

Announce each.

1. **Pre-dispatch**, always, spawned or held (Fallback). After checking the drafted spec's premises
   against source, one pass looks for a false or unverified premise, a missing hard limit, an
   observable that cannot go red, and — pasted verbatim — *what will this run raise that the ticket
   does not list?* It names no claim of yours, so it audits your world, not your sentence. The
   advisor definition's fourth differs — a finding it supplies, not a question you ask; never sync
   the lists. Check the spec's *mechanisms* against its stated *intent* too: no review or gate
   written from the spec can catch a mechanism that contradicts it, since the deliverable matches.
   **A prose deliverable** (record, Skill, Chunk) loads in no gate: its observable is an independent
   reader given the source rows, not the writer's table, calibrated by one planted absent row whose
   count is read, beside a fresh agent's playthrough of it.
2. **Pre-merge** — completeness critic and counter-critic in one consult. On unless that marker
   appears anywhere in the ticket body (a local-file ticket's file). Only the marker cancels it; a
   meter moves it (Fallback).
3. **Floating** — a reading you would otherwise decide silently or put to the owner: a review
   finding you want to reject, one that would change an acceptance criterion, a ticket premise
   reading false against source, a gate still red after one `diagnosing-bugs` loop. A fourth
   need goes to the owner.

Never the advisor: gates, reading a diff for conformance, prose records, git mechanics, a task
scoped to named files. Read the meter before spawning; the owner decides a tight one.

**Fallback.** One affordable slot: keep slot 1 and ask it for the pre-merge reading too; given
before the diff exists, the record calls it the capped form, never slot 2. Advisor unavailable
(no definition this host can dispatch, meter spent, knob `none`): hold the judgment yourself, ask
the owner at the same triggers, say so. That is self-review unless slot 1's observable that cannot
go red becomes a question the implementer's dispatch prompt asks before it writes code — a spec's
author is the last reader to see that an observable does not mean what they intended. Gate-runner
unavailable or knob `coordinator`: run the gates yourself, say so.

## Handoffs

Give every constrained seat the reason for each constraint: a bare constraint is followed
silently, and only its *why* can be refuted, often by that seat alone.

Passing work to the user mid-slice, restate the invariants it depends on — the state that must not
move, the step that must precede a save, how many things may be in flight — even if a prior round
covered them; the handoff is read alone. Verify the returned state against those invariants: the
user reports the instruction they followed, not the invariant.

## Review

Hand reviewers the measurements a spec summarises, not just the spec. Re-check a refuted finding
about safety or data loss. A finding proves the defect, not the remedy. After fixes, re-run the
affected checks and take a targeted review; reopen the full one only where scope or assumptions
changed. A third-party review is optional, for a specific remaining question; absent external
tooling never blocks the native pair.

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
