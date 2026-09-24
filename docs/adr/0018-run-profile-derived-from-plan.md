# A run's profile is derived from its plan; the ticket pins dials, never levels; effort is a dial

**Status:** accepted — 2026-09-24. Amends [ADR 0011](0011-roles-not-cost-tiers.md) § Decision on
effort ("pinned `high` on every seat, with no higher path"). Everything else there stands: two
roles read off the meter, a model name in run artifacts only, every seat a pinned definition.
Decided on cpalaka/agent-skills#85, under map #82, from the measurements on #81, #84 and #89.

## Context

A ticket's run was shaped by a **seat tier**, `Seats: light | full`, declared by the ticket's
author at filing time and readable only upward: evidence could raise light to full, nothing could
lower full. The two bundles moved seats together that the measurements move apart. Over the twelve
runs #84 read: the critic seat found a material defect in 9 of 10 runs; the Codex lens found one
unique material defect in 9, and that one on a Chunk edit, prose; the Standards axis produced
mostly wording rounds; the slot-1 advisor out-yielded every seat per active minute; the
gate-runner took 3.5–4 min whatever the diff, 44% of the wall on a seven-line docs run. A light
line was wrong at filing more than once (#79, #55), and the author at filing time has read less
of the source than the coordinator has after planning. ADR 0011 pinned effort `high` with no
higher path on a premise #73 shows no longer holds: the critic is now a fresh seat.

## Decision

1. **The coordinator derives a run profile from its own plan, one dial at a time.** There are no
   named levels. Each dial has a default and one trigger that turns it, read off the plan:

   | Dial | Default | Turned by |
   |---|---|---|
   | implementer, gate-runner, Spec axis | on | nothing: always |
   | Standards axis | off | any changed path outside the project's light set |
   | advisor slot 1; slot 3 available | off | anything above the floor |
   | critic | off | anything above the floor |
   | bug hunter (`codex` \| `correctness` \| `off`) | off | runtime surface or an instruction file in the diff; `codex` above the floor until the research on the lens lands |
   | gate tier | derived | `verify-gate`'s skip rule over the project's trigger table |
   | plan stop | none | any dial above its default |

   The **floor** is a plan whose every changed path is in the project's light set and which no
   gate loads. An **instruction file** in the diff (a Skill, Chunk, seat definition or contract)
   turns every dial on, whatever else the plan says: the diff changes the instrument the next run
   reads. That replaces the tier's "no Skill, seat definition or Chunk body is light" sentence.

2. **The ticket pins dials, never levels.** A pin is a floor on one dial (`critic: on`,
   `gate tier: 2`), written beside the acceptance criteria, and the coordinator never lowers a
   pinned dial. There is no whole-level floor: a level bundles a good seat with a bad one, and
   the author's knowledge at filing is intent, which one dial carries. `Seats: light | full` is
   retired; an existing line reads as absent, and the run derives.

3. **The profile is posted in the run's first message, always.** The stop for a reader fires
   only when a dial sits above its default. A profile at the floor is posted and the run goes
   on, which generalises #79's decided B rule. The reader is the owner, or under #81 the
   **owner's delegate**, attributed as such in the record.

4. **Signals are the four the coordinator can observe**: changed paths against the project's
   trigger table, runtime surface, an instruction file in the diff, and expected implementer
   calls. Confidence in the ticket's premises and novelty are not the coordinator's to grade,
   since it cannot see its own false premise; they are why slot 1 runs on every profile above the
   floor, not inputs to it.

5. **The ratchet is monotone.** Mid-run evidence raises a dial and nothing lowers one: a diff
   path outside the plan's changed-path set, a red gate, or a material finding while a downstream
   seat is off. A raise goes under `Deviations` with its trigger and reopens no stop. One
   exception: an instruction file in the diff that the plan did not name ends a delegated batch
   after this ticket (#89).

6. **The project's gate tier is a dial.** The glossary kept seat tier and gate tier apart so
   neither drifted; one derivation setting both removes the drift. The project's trigger table
   stays where it is, as the input the derivation reads.

7. **Effort is a dial; the model is not.** A seat's model stays pinned by role (ADR 0011, 0017).
   Its effort is chosen per run among these values, `high` the default on every seat: a
   Planner-role seat runs `medium` or `high`; a Builder-role seat `medium`, `high` or `xhigh`.
   The heuristics as decided: `medium` where speed is preferred, so the implementer and Spec
   axis at the floor; the gate-runner runs Builder `medium` always, since its minutes are
   command time; `xhigh` where a review should go deeper, reserved to the critic and the
   Correctness fallback until measured, on an instruction file in the diff or a red gate in the
   run; slot 1 never `medium`. The host's Agent tool pins only `model`, so **an effort dial's value
   is a definition name**, and each reachable seat-and-effort pair is its own pinned definition:
   one for the advisor, two for the implementer, three for `code-reviewer`, one for the
   gate-runner. The definition's name carries the effort, so the run record naming the definition
   names the effort with it.

8. **Two caps are constants, not risk-derived.** Fix rounds: two, wording-only findings batched
   into one, and a third round is a stop to the reader. Scope: the plan states its deliverable
   count and expected calls; the 60-call ceiling holds per dispatch, continuations included; and
   exceeding either is a stop, never a ratchet, since more work is a scope question the reader
   owns. The plan may pin either higher with a reason.

9. **The roster line is replaced by a profile block**: one line per dial, `dial: value — the
   fact that set it`, pins marked. The run record repeats it as dispatched, and every ratchet
   goes under `Deviations`.

## Considered options

- **Named levels with derived defaults.** Rejected: #84's seats move independently, so any bundle
  carries a seat the diff does not need or drops one it does.
- **The author's line as a whole-level floor** (today's rule). Rejected: it has been wrong at
  filing, and it is read by a coordinator that has already read more than the author had. The pin
  keeps the one thing the author knows, intent, and nothing else.
- **Nothing declarable on the ticket; the plan-stop reader is the only check.** Rejected: it
  discards the author's intent, and the stop does not fire at the floor.
- **Effort passed on the dispatch, overriding the pin.** Not available: the Agent tool carries no
  effort field. **Dropping effort from the profile and leaving it to #73** was the fallback; the
  definition-per-pair mechanism makes the dial reachable now, and #73's effort question closes
  on it.

## Consequences

- Every effort value other than `high` is a hypothesis: all of #84's data is at `high`. The record
  carries the definition name so the yield tools can read the effort per seat later.
- The `implement-run` Skill, the tracker Chunk's re-gate write ("adding the seat tier"), the
  `seat tier` glossary entry, every project contract's `Seats:` sentence and light set, the seat
  definitions and the stamped gate-runner Template all change. None of that is done here: the
  map's `Spec:` parent files it as children.
- #73's first acceptance criterion lands with this entry; its second lands with the child that
  edits the definitions. #79's B criterion is superseded by § 3 and § 9; its A criterion stands.
- The bug-hunter default is provisional on a research ticket into the Codex lens's use: focus,
  mode and base against a planted known defect.
