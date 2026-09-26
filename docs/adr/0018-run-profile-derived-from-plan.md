# A run's profile is derived from its plan; the ticket pins dials, never levels; effort is a dial

**Status:** accepted — 2026-09-24. Amends [ADR 0011](0011-roles-not-cost-tiers.md) § Decision on
effort ("pinned `high` on every seat, with no higher path"). Everything else there stands: two
roles read off the meter, a model name in run artifacts only, every seat a pinned definition.
Decided on cpalaka/agent-skills#85, under map #82, from the measurements on #81, #84 and #89.
**Amended 2026-09-24 on #86**, the settings catalogue: § 1's Standards, bug-hunter and gate-tier
rows and its floor paragraph, § 4, § 5, § 6 and § 8, each marked. The glossary names this ADR's
floor a **light plan** and a pin a **lower bound**; this record keeps its own words.
**Amended 2026-09-24 on #87**, the model-and-effort pin question: § 7, one Considered option and
one Consequence, each marked.
**Amended 2026-09-26 on #112**, the gate's place in the run: § 7's `xhigh` trigger, marked.

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
   | Standards axis | off | no trigger of its own: an instruction file in the diff, or a pin (amended on #86) |
   | advisor slot 1; slot 3 available | off | anything above the floor |
   | critic | off | anything above the floor |
   | bug hunter (`codex` \| `correctness` \| `off`) | off | anything above the floor; `correctness`, or `codex` by pin (value resolved 2026-09-24 on #90, trigger amended on #86; § Consequences) |
   | gate tier | the project's lowest tier, plus every gate its trigger table pulls for the changed paths | a pin only (amended on #86, § 6) |
   | plan stop | none | any dial above its default |

   The **floor** is a plan whose every changed path is in the project's light set, is loaded by no
   gate, and is no instruction file. The light set is an `implement-run` knob of path globs,
   `docs/**`, `CONTEXT.md` and `README.md` where the contract names none. An **instruction file**
   is whatever a host injects (a host adapter, the project contract, and every contract or Chunk
   they import), every file under a Skill's directory, every seat definition, and every file one
   of those names as a read. One in the diff turns every seat and effort dial on, whatever else
   the plan says, and no light-set glob makes it light: the diff changes the instrument the next
   run reads. It never turns the gate tier (§ 6). That replaces the tier's "no Skill, seat
   definition or Chunk body is light" sentence. (Amended on #86: the set was four kinds, while ADR
   0019's instrument set also named the adapters.)

2. **The ticket pins dials, never levels.** A pin is a floor on one dial (`critic: on`,
   `gate tier: 2`), written beside the acceptance criteria, and the coordinator never lowers a
   pinned dial. There is no whole-level floor: a level bundles a good seat with a bad one, and
   the author's knowledge at filing is intent, which one dial carries. `Seats: light | full` is
   retired; an existing line reads as absent, and the run derives.

3. **The profile is posted in the run's first message, always.** The stop for a reader fires
   only when a dial sits above its default. A profile at the floor is posted and the run goes
   on, which generalises #79's decided B rule. The reader is the owner, or under #81 the
   **owner's delegate**, attributed as such in the record.

4. **Signals are the three the coordinator can observe**: changed paths against the project's
   light set and trigger table, an instruction file in the diff, and expected implementer calls.
   Expected calls turns no dial; it sizes phases and sets § 8's scope cap. (Amended on #86, which
   dropped runtime surface: it was never defined, and the bug hunter now shares the floor
   trigger.) Confidence in the ticket's premises and novelty are not the coordinator's to grade,
   since it cannot see its own false premise; they are why slot 1 runs on every profile above the
   floor, not inputs to it.

5. **The ratchet is monotone.** Mid-run evidence raises a dial and nothing lowers one: a diff
   path outside the plan's changed-path set, a red gate, or a material finding while a downstream
   seat is off. A red gate re-runs that gate and raises review effort under § 7, never the gate
   tier (amended on #86). A raise goes under `Deviations` with its trigger and reopens no stop.
   One exception: an instruction file in the diff that the plan did not name ends a delegated
   batch after this ticket (#89).

6. **The project's gate tier is a dial.** The glossary kept seat tier and gate tier apart so
   neither drifted; one derivation setting both removes the drift. The project's trigger table
   stays where it is, as the input the derivation reads. Its range is the project's named tiers,
   or one full gate less `verify-gate`'s derived skips where the contract names none. Its default
   is the lowest tier plus every trigger-table pull the changed paths hit, and only a pin raises
   it: a higher tier's own trigger, in 3d-anim-lab a workload boundary or a milestone push, shows
   in no changed path. (Amended on #86.)

7. **Effort is a dial; the model is not.** A seat's model stays pinned by role (ADR 0011, 0017),
   and a run never overrides it, though the Agent tool's `model` parameter would let it: a model
   choice is role routing, the role is the owner's rationing of the Planner meter, read at the
   account and not re-derived from a plan, and a second model family on a diff is a distinct
   seat, `bug hunter: codex`, never a rewritten pin. (Decided on #87.) Its effort is chosen per
   run among `medium`, `high` and `xhigh`, `high` the default on every seat: a Planner-role seat
   runs `high` only; a Builder-role seat `medium`, `high` or `xhigh`. (Amended on #87: `medium`
   left the Planner range, since slot 3 continues slot 1 and nothing measured wants a fresh
   advisor below `high`; the host's `max` stays out until `xhigh` has a measurement.) The
   heuristics as decided: `medium` where speed is preferred, so the implementer and Spec axis at
   the floor; the gate-runner runs Builder `medium` always, since its minutes are command time;
   `xhigh` where a review should go deeper, reserved to the critic and the Correctness fallback
   until measured, on an instruction file in the diff, or for the critic alone a red gate in the
   run; slot 1 never `medium`. (Amended on #112; the clause read "or a red gate in the run" for
   both seats: the certifying gate now runs after the review's fixes land, so the Correctness
   charter goes out before any gate reads, and raising it would take a second dispatch and a second
   reading of the one bug hunter; the Codex lens's fallback, dispatched later, is that one reading
   too.) **The dial has two carriers** (amended on #87). On the Agent tool, which pins only
   `model`, **an effort dial's value is a definition name**: each reachable seat-and-effort pair is
   its own pinned definition, the bare seat name carrying the default and every other value a
   suffix (`implementer-medium`, `code-reviewer-medium`, `code-reviewer-xhigh`; `gate-runner`
   bare, at its only value), so the run record naming the definition names the effort with it —
   one for the advisor, two for the implementer, three for `code-reviewer`, one for the
   gate-runner. Under `shape: workflow` the stage's `effort` field carries the same value for a
   stage that fills a seat; a stage filling no seat is not a dial and keeps `WORKFLOWS.md`'s
   rule. **Every seat definition carries `effort:` explicitly** — an omitted field inherits the
   parent session's, the bare-spawn leak on a second field — and the field joins the
   `context-hygiene` reverse pass beside `model:`. Two things sit outside the dial and are posted
   `fixed by host`: the Codex lens, whose `adversarial-review` command takes no effort and runs at
   Codex's global config, and the Codex role files, which keep `high` until a Codex-hosted
   coordinator run exists to measure on.

8. **Two caps are constants, not risk-derived.** Fix rounds: two material rounds, and a third is
   a stop to the reader. Wording-only findings ride the last material round, or form one closing
   round that counts toward no cap; that round re-runs every gate `verify-gate`'s skip rule cannot
   skip for its paths, a scan that reads prose always, and takes no targeted re-review, the
   coordinator checking the wording diff against the findings it accepted. Scope: the plan states
   its deliverable count and expected calls. The 60-call ceiling is per implementer, continuations
   included: one at the ceiling is never continued by message, and its next leg, a fix round or the
   phase's remainder, goes to a fresh implementer handed the findings and the diff. Work past the
   deliverable count is a stop, never a ratchet, since more work is a scope question the reader
   owns. The plan may pin either cap higher with a reason. (Amended on #86: as first written,
   three of #84's twelve runs would have stopped at the ceiling, two of them on fix rounds.)

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
  effort field (confirmed on #87 against the host's subagent reference: a definition's `effort`
  is the only Agent-tool carrier, and a workflow stage's `effort` the only other, § 7).
  **Dropping effort from the profile and leaving it to #73** was the fallback; the
  definition-per-pair mechanism makes the dial reachable now, and #73's effort question closes
  on it.
- **A per-run model override.** Available on the Agent tool's `model` parameter; rejected on #87
  for the ground § 7 names. A Planner-role critic, if #84's slot-1 yield ever argues for one, is a
  new seat with its own definition and dial, filed on data, not a run rewriting a pin.

## Consequences

- Every effort value other than `high` is a hypothesis: all of #84's data is at `high`. The record
  carries the definition name so the yield tools can read the effort per seat later.
- The `implement-run` Skill, the tracker Chunk's re-gate write ("adding the seat tier"), the
  `seat tier` glossary entry, every project contract's `Seats:` sentence and light set, the seat
  definitions and the stamped gate-runner Template all change. None of that is done here: the
  map's `Spec:` parent files it as children.
- The pair definitions' names reach `implement-run`'s dispatch lines and `agents/README.md`'s
  seat table; the Spec child that adds the definitions re-points both, and the bare names stay
  valid throughout since each carries the default (amended on #87).
- #73's first acceptance criterion lands with this entry; its second lands with the child that
  edits the definitions. #79's B criterion is superseded by § 3 and § 9; its A criterion stands.
- The bug-hunter default was provisional on a research ticket into the Codex lens's use.
  **Resolved 2026-09-24 on #90:** against four planted defects the Skill's feed was not the weak
  part, and a Correctness-charter `code-reviewer` dispatch matched or beat the lens on every plant
  at about half the wall, so `correctness` is the default above the floor and `codex` a pinnable
  value for a second model family on a diff; the lens focus gains the test-gap charter line, the
  one plant every Codex variant missed. Recall on large real diffs stays unmeasured.
- **Amended 2026-09-24 on #86**, from #84's per-project split. The Standards axis yielded 0.56
  unique material findings per active minute on this repository's Skill and Chunk diffs and 0.08
  on 3d-anim-lab's four code tickets, and 10 of its 11 came on diffs editing an instruction file,
  so it runs where every dial runs. The serial first-pass review was the largest phase in 6 of 12
  runs (median 9.6 min), and the lens's place after both axes had no recorded reason: the bug
  hunter is dispatched with the native axes, whichever value, and the critic stays last because it
  reads every review. That is ordering, not a dial. On 3d-anim-lab#48 a scan matched prose a fix
  round wrote, which is why a wording round re-gates. The Spec's children carry the rest: the
  `light_set` knob, 3d-anim-lab's light-set sentence losing its two adapters, and how the
  `workflow` shape reaches a concurrent bug hunter.
