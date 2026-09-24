# Seat time and yield across every implement run since #69

Research for #84, on map #82. The baseline under test is test run 1's per-seat comment on #81
(six 3d-anim-lab tickets run by one delegate) and its three readings. Measured 2026-09-23 from the
Claude Code transcripts on the one machine that holds them, and from each ticket's closing record.

## Answer first

| # | Test run 1's reading | Verdict | Why, in one line |
|---|---|---|---|
| 1a | The critic has the best yield per minute | **Breaks** under this note's classification; holds only under #81's narrower one | The advisor's pre-dispatch pass yields about 3× the critic per minute (1.40 against 0.46 unique material findings per active minute). The Spec axis and targeted reviews also rank above the critic, within overlapping intervals. |
| 1b | The Codex lens has the worst yield | **Holds** (n = 9 runs) | 2 findings in 9 runs and 15.3 min: one duplicated the Spec axis, and one was unique and material (#76). |
| 2 | Standards-axis wording findings drive fix → re-review → re-gate loops, the largest single sink | **Breaks** (n = 12) | The fix loop was the largest phase in 2 of 12 runs, and both loops carried material findings. The largest phase is the serial first-pass review block (axes → lens → critic, median 9.6 min), in 6 of 12. Wording-only loops were all short (0.7–3.1 min). |
| 3a | Implementer time tracks scope, not seats | **Holds** (n = 12) | Spearman ρ = 0.75 against diff lines and 0.84 against continuation legs, but 0.12 against reviewer dispatches. |
| 3b | The gate-runner is a near-constant 3.5–4 min | **Holds, one project only** (n = 9 dispatches, 8 runs, all 3d-anim-lab) | 3.3–5.2 min, median 4.0. agent-skills has no gate-runner seat; its coordinator runs the gates. |

Tier comparison (light against full) is **insufficient n**: the two light runs are both 3d-anim-lab
tickets under the delegate, one of them with a scope overrun.

**The sample is small, and it is not the one the ticket hoped for.** Every implement run since #69
landed took place on one day, in two projects: 12 runs with seats, 4 in agent-skills and 8 in
3d-anim-lab. Six of the eight 3d-anim-lab runs are test run 1 itself. So the widening is 6 runs:
4 agent-skills tickets and 2 3d-anim-lab tickets, all attended by the owner. No other project on
this machine ran `implement-run` after #69 landed, and no Codex-host session ran it at all in the
window. Owner against delegate attendance, and agent-skills against 3d-anim-lab, are almost
perfectly confounded: every delegate run is 3d-anim-lab, and every agent-skills run is
owner-attended.

## Sample

Runs were found by scanning every project directory in the transcript store for sessions whose
user messages expand `/implement-run` (the slash command, or a pasted prompt that starts with it),
then cross-checked against each ticket's closing record. #69 landed as `0b53860` at
2026-09-23 00:15 −07:00. A run counts as "under the new rules" if its session loaded the Skill after
that moment.

| Run | Project | Tier | Stops held by | Wall | Waiting at stops | Working wall | Cost | Implementer min | Implementer calls (first leg / all legs) |
|---|---|---|---|---|---|---|---|---|---|
| #70 | agent-skills | full | owner | 29.8 | 4.5 | 25.3 | $6.99 | 5.1 | 17 / 27 |
| #71 | agent-skills | full | owner | 678.4 | 640.4 (overnight) | 38.0 | $10.96 | 4.8 (×3) | 17 / 27 |
| #72 | agent-skills | full | owner | 67.6 | 21.4 | 46.2 | $12.41¹ | 7.7 (×3) | 23 / 47 |
| #76 | agent-skills | full | owner | 61.5 | 19.2 | 42.3 | $14.36 | 12.6 | 37 / 68 |
| 3d-anim-lab#92 | 3d-anim-lab | full² | owner | 32.8 | 7.2 | 25.6 | $7.08 | 2.3 (×2) | 10 / 19 |
| 3d-anim-lab#71 | 3d-anim-lab | full | owner | 44.5 | 9.2 | 35.3 | $9.06 | 9.9 (×2) | 34 / 56 |
| 3d-anim-lab#41 | 3d-anim-lab | full | delegate | 35.5 | 1.7 | 33.8 | $10.59 | 6.1 | 20 / 44 |
| 3d-anim-lab#42 | 3d-anim-lab | full | delegate | 38.2 | 10.1 | 28.1 | $8.21 | 4.4 | 20 / 20 |
| 3d-anim-lab#48 | 3d-anim-lab | full, advisor and lens struck | delegate | 47.4 | 2.6 | 44.8 | $11.92 | 17.6 | 16 / 71 |
| 3d-anim-lab#49 | 3d-anim-lab | light + Spec | delegate | 39.6 | 14.8 | 24.8 | $6.84 | 13.9 | 17 / 67 |
| 3d-anim-lab#94 | 3d-anim-lab | full | delegate | 41.2 | 10.6 | 30.7 | $9.05 | 4.6 (×2) | 26 / 34 |
| 3d-anim-lab#97 | 3d-anim-lab | light | delegate | 8.4 | 0.0 | 8.4 | $2.52 | 0.9 | 7 / 7 |

Minutes throughout. "Working wall" is wall minus waiting at the stops. For owner-attended runs,
wall ends at the `/wrap-session` prompt, and cost is cut at the same point; test run 1's sessions
had no wrap and are whole. Costs are API-equivalent at Opus 5.5 list rates for every model, which
is the tools' convention, so Fable and Sonnet turns are priced as Opus. They exclude the Codex lens
and any delegate session.

1. Plus about $3.7, at the same rates, for eight headless playthrough sessions #72 ran in a scratch
   repository. They ran on a smaller model, so the true figure is lower.
2. 3d-anim-lab#92's `Seats:` line was inline, so the Skill read it as malformed and ran full.

**Excluded.** A 3d-anim-lab#73 session that only recorded the owner's acceptance of work done on
09-21 (no seats, 4.9 min). Also #72's playthrough probes, which are part of #72's evidence, not
runs of their own.

**Pre-landing runs, reported apart and used in no verdict.** Four sessions loaded the Skill 6–38
minutes before `0b53860` landed, concurrently with it. The last column is each run's total cost
over the whole session:

| Run | Project | Working wall | Waiting | Cost |
|---|---|---|---|---|
| #69 | agent-skills | 34.7 | 10.8 | $11.36 |
| 3d-anim-lab#91 | 3d-anim-lab | 21.8 | 40.2 | $7.20 |
| project C #23 | project C | 24.6 | 6.9 | $6.84 |
| project C #13 | project C | 24.6 | 1.4 | $5.15 |

None had a critic seat or a Codex lens. Earlier baseline-era runs, from 09-20 and 09-21, were not
read; the audit baseline is #93's.

## Method

- **Tools.** `seat_yield.py` and `ticket_timeline.py` from the owner's local token-usage tools,
  run unmodified. One gap needed a copy: `seat_yield.py` globs `subagents/agent-*.jsonl` only, so it
  cannot see a seat dispatched through the Workflow tool, whose transcript sits one level deeper
  under `subagents/workflows/<run>/`. #72's advisor ran that way (9.0 active min, $1.43) and is
  missing from the unmodified tool's output. The copy changes that one glob to a recursive one;
  nothing else. Everything else here (phase splits, calls per continuation leg, the union of
  seat-active time, the cost cut) came from small read-only scripts over the same transcripts, with
  the same 90-second idle-gap rule.
- **Active minutes** follow the tools: a seat's transcript split at idle gaps over 90 s. The
  Codex lens is the wall time of its Bash call. **Waiting at stops** is the tools' measure: the gap
  before each typed prompt, whether the owner or the delegate typed it.
- **Implementer calls** are unique assistant messages (API calls) in an implementer transcript,
  split at each `The coordinator sent a message` continuation. The first leg is the dispatched
  phase; the later legs are fix rounds and scope extensions sent to the same agent.
- **Phases** per run: plan (start to the first implementer dispatch), implement (to the first
  review dispatch), first-pass review (to the end of the last axis, lens or critic), fix loop (to the
  final gate's start, or the last seat activity where the coordinator runs the gates), gate, and
  close.

### Finding classification (this note's, not the owner's)

The findings are read from each closing record, and from the seat's own reply where the record
does not itemize them. The classification is mine. The rule extends #81's definition with explicit
boundaries, because #81's own counts are not reproducible from its definition (see below):

- **M, material:** acted on, and it changed
  (a) a test, assert, control, plant, gate command or a check's expected result;
  (b) runtime or tool code;
  (c) in prose that agents execute (a Skill, a Chunk, a project contract, a seat definition, an
  instruction file, or the execution spec handed to an implementer), what a follower would do;
  or (d) an evidence claim, meaning a statement in the run record, a results or decision document,
  or the ticket about what was measured, verified or decided, that was false, overstated,
  unsupported or missing.
- **D, deferred material:** an (a)–(d) defect homed elsewhere instead of fixed.
- **W, wording:** acted on, but it changed only comments, glossary format, pointers, phrasing,
  duplication, naming or hygiene. Code comments are never evidence claims.
- **X, no change:** refuted, rejected, declined, not acted on, or adjudication only.

"Unique" material drops a finding that an earlier seat in the run's sequence, or a concurrent
axis, had already raised.

**The second reader.** A fresh agent was given only the rule and the one-line finding and outcome
for a random sample of 40 of the 199 non-adjudication findings (seed 84). It was not told which seat
raised each one or how I had classed it.
- It decided 34 of the 40 and agreed with me on 33: 97%, Cohen's κ = 0.95.
- It disagreed on one (71L-A4: I classed it wording, and it read it as material).
- It marked six as undecidable from the text. In every case my class was one of the two it named,
  and four sat on the M/W boundary.
- Counting every undecided item as a disagreement, agreement is 33 of 40 (83%).

The sample was 40 findings: 41-C2 41-T1 48-S1 48-S2 48-S4 49-R1 49-R2 49-S4 70-A10 70-A2 70-A4
70-T1 71-A10 71-C6 71-T4 71L-A1 71L-A2 71L-A4 71L-A6 71L-T2 72-A11 72-A12 72-C1 72-R3 72-S1 72-T2
76-A1 76-A8 76-R2 76-R4 76-S4 76-T2 92-A8 92-C1 92-C6 92-C9 92-S2 92-T1 92-T5 94-A4.

Two limits on what this agreement shows:
- It tests the rule's application to my one-line summaries, not the summarizing itself.
- The reader is from the same model family as the classifier.

**Where this departs from #81's counts, on the same six tickets:**
- **The advisor on 3d-anim-lab#41 and #42.** #81 recorded that the advisor "duplicated the
  delegate's plan-stop checks". It did not. The delegate's plan-stop messages checked the literals
  (the −π/12 correction on #41, and a re-derivation on #42). The advisor's material findings were
  different ones:
  - on both tickets, the control's expected check count could not come true, because the pin check
    counts itself;
  - on #42, plants were checked as reverted only at handoff;
  - on #42, the tolerance constant had no stated basis;
  - on #42, a yaw-wrap seam arm with its own plant.
  On the rule, that is 5 material findings where #81 found none.
- **The Spec axis on 3d-anim-lab#48 and #49.** The two tickets' Spec axes raised 10 first-pass
  findings, and #81 counted 2 of them as material. Both tickets deliver results documents, and each
  of the other 8 also corrected an evidence claim: a verdict's scope, an unsupported route
  attribution, a coverage status stated without saying it was inferred, or a missing limit. By the
  rule's own "evidence claim" clause, all 10 are material.

On test run 1 alone, #81's counts give the critic 0.24 material findings per minute, ahead of the
Spec axis (0.17) and the advisor (0.11). My counts give the critic 0.30, the Spec axis 0.86 and the
advisor 0.85. Reading 1a turns on this classification boundary, not on the wider sample.

## Per-seat time and yield (12 runs under the new rules)

| Seat | Runs it ran on | Active min, total (median/run) | Findings | M (unique) | D | W | X | Unique M per active min (90% run-bootstrap) | Runs with no unique M |
|---|---|---|---|---|---|---|---|---|---|
| Advisor, slot 1 | 9 | 35.0 (3.0) | 75 | 49 (49) | 7 | 14 | 5 | **1.40** (1.14–1.67) | 0 of 9 |
| Spec axis | 12 | 29.0 (2.3) | 24 | 20 (18) | 0 | 0 | 4 | 0.62 (0.28–0.98) | 6 of 12 |
| Targeted re-review | 8 | 14.4 (1.3) | 14 | 10 (10) | 0 | 3 | 1 | 0.69 (0.21–1.10) | 5 of 8 |
| Critic | 10 | 45.4 (4.7) | 46³ | 22 (21) | 5 | 9 | 10 | 0.46 (0.32–0.61) | 1 of 10 |
| Standards axis | 10 | 29.6 (2.8)⁴ | 43 | 16 (11) | 2 | 14 | 11 | 0.37 (0.15–0.62) | 5 of 10 |
| Codex lens | 9 | 15.3 (1.7) | 2 | 2 (1) | 0 | 0 | 0 | **0.07** (0.00–0.19) | 8 of 9 |
| Gate-runner (3d-anim-lab only) | 8 | 36.1 (4.0 per dispatch; 9 dispatches) | 1 red, on 3d-anim-lab#48: the scan matched prose a fix round had written | — | — | — | — | — | — |
| Implementer | 12 | 89.9 (5.6) | — | — | — | — | — | — | — |

3. Includes 10 adjudication-only items (re-classifying or refuting other seats' findings), which
   #81 counted as findings. Without them, the critic's material rate is 22 of 36.
4. Includes a 2.1-min dispatch on 3d-anim-lab#94 that returned only a 429 (the weekly limit); the
   re-dispatch is counted too.

**By project** (unique M per active minute):

| Seat | agent-skills (4 runs) | 3d-anim-lab (8 runs) | 3d-anim-lab code tickets only (#41, #42, #48, #94) |
|---|---|---|---|
| Advisor | 1.56 | 1.17 | 0.85 |
| Spec | 0.46 | 0.75 | 0.51 |
| Critic | 0.42 | 0.49 | 0.30 |
| Standards | 0.56 | 0.23 | 0.08 |
| Codex | 0.16 | 0.00 | 0.00 |

The Standards axis earns its material findings in agent-skills, where a sentence in a Skill is
operative (7 unique material findings in 4 runs). In 3d-anim-lab it is the weakest native seat.
Its 4 unique material findings there were one negative-path test (3d-anim-lab#48) and three
contract and results-record fixes on 3d-anim-lab#71.

**Confound on the advisor.** In 7 of its 9 spawns, the advisor ran on the Builder-family model
rather than its pinned Planner model, at the owner's instruction: agent-skills #71, #72 (at `xhigh`,
through the Workflow tool), and #76, and 3d-anim-lab#92, #41, #42 and #94. On the two spawns that ran
on the pinned model, it yielded 7 unique material findings (#70) and 5 (3d-anim-lab#71).

## Reading 1: critic best, Codex worst

- **Codex worst: holds.**
  - Across 9 runs the lens returned 2 findings. #72's duplicated the Spec axis's clean-tree finding,
    and its proposed remedy overreached. #76's was unique and material: the re-gate added edges from
    the undecided body. It is still the lowest seat on every cut, and 8 of its 9 runs added nothing.
  - One out-of-sample fact cuts against it. #71's deliverable was a Codex run over the 3d-anim-lab#85
    commit, and that run found a real runtime defect: a respawn in Air with a held stick falls
    through the floor. 3d-anim-lab#85 had shipped through the baseline-era review, which had no
    lens. The defect was fixed as 3d-anim-lab#94. The lens can catch what the native seats miss on
    runtime code. In-sample, it did not, on the three code diffs it read (#41, #42, #94).
- **Critic best: breaks on this classification.**
  - The advisor's pre-dispatch pass yields 1.40 unique material findings per active minute, and its
    lower bound (1.14) clears the critic's upper bound (0.61). Most of those findings are checks that
    could not go red, or expected results that could not come true. They are corrected before any
    code exists, so they trigger no fix loop.
  - Among the post-implementation seats, the critic (0.46) sits with the Spec axis (0.62) and the
    targeted re-reviews (0.69). The bootstrap intervals overlap, so they cannot be ranked. All three
    rank above Standards (0.37) and Codex (0.07).
  - What still sets the critic apart is consistency: it produced a unique material finding in
    9 of 10 runs. The Spec and Standards axes each drew a blank in half their runs.

## Reading 2: wording findings drive fix loops, the largest sink

Phase minutes, excluding waiting at stops:

| Run | Plan | Implement | First-pass review | Fix loop | Gate | Close | Largest |
|---|---|---|---|---|---|---|---|
| #70 | 8.3 | 4.0 | 9.7 | 2.0 | (coord.) | 1.3 | review |
| #71 | 17.9 | 4.4 | 9.4 | 3.0 | (coord.) | 3.2 | plan |
| #72 | 17.3 | 4.8 | 12.6 | 7.8 | (coord.) | 3.7 | plan |
| #76 | 9.3 | 6.9 | 12.0 | 12.2 | (coord.) | 1.8 | fix loop |
| 3d-anim-lab#92 | 5.3 | 1.4 | 9.9 | 1.7 | 4.0 | 3.2 | review |
| 3d-anim-lab#71 | 6.4 | 7.4 | 9.0 | 4.9 | 4.3 | 3.3 | review |
| 3d-anim-lab#41 | 7.1 | 3.8 | 8.2 | 7.8 | 4.1 | 2.8 | review |
| 3d-anim-lab#42 | 7.7 | 5.1 | 8.8 | 0.7 | 3.3 | 2.6 | review |
| 3d-anim-lab#48 | 2.9 | 9.9 | 10.9 | 13.8 | 4.5 | 2.9 | fix loop |
| 3d-anim-lab#49 | 2.5 | 10.2 | 5.6 | 1.1 | 3.5 | 1.9 | implement |
| 3d-anim-lab#94 | 6.8 | 4.2 | 11.8⁵ | 3.1 | 3.5 | 1.3 | review |
| 3d-anim-lab#97 | 1.4 | 1.1 | 0.8 | 0.1 | 3.7 | 1.4 | gate |

5. Excludes the 6.8-min weekly-limit stall, which the tools count as waiting.

Medians: plan 7.0, first-pass review 9.6, fix loop 3.1. The coordinator working alone, with no
seat active and no stop pending, is 18–52% of working wall (median 35%). It covers drafting, the
Codex lens call, adjudication, the agent-skills gates and the record, and it is the largest cost line
in every run (41–64% of cost in the owner-attended runs; #81 measured 40–56% in test run 1).

- **Largest single sink: breaks.** The fix loop was the largest phase in 2 of 12 runs: #48 (13.8)
  and #76 (12.2, level with its review at 12.0). The first-pass review block was the largest in 6.
  It runs serially: axes in parallel (about 2–4 min), then the lens (1.4–2.2), then the critic
  (median 4.7), then adjudication.
- **Driven by wording: breaks.** The four longest loops, #48, #76, #72 and #41, each carried at
  least one material finding that forced a round anyway:
  - #48: a negative-path test, a class-specific needle and a fixture change, plus a red gate caused
    by a comment the fix round wrote;
  - #76: operative gated-set and edge-order defects from the lens, the critic and the targeted
    reviews;
  - #72: the clean-tree boundary;
  - #41: the `top_speed` assert pair.
  The loops that carried only wording, #94 (3.1), #42 (0.7) and nearly so #70 (2.0), were short.
  In 3d-anim-lab, a re-gate happened once, on #48's red gate. Every other run reviewed before its
  single certifying gate.

## Reading 3: implementer tracks scope; gate-runner near-constant

- **Implementer: holds.** Over the 12 runs, implementer active minutes correlate with diff size
  (ins + del at the squash, Spearman ρ = 0.75) and with the number of continuation legs (ρ = 0.84),
  not with the number of reviewer dispatches (ρ = 0.12). Over the 10 full-tier runs the figures are
  0.78, 0.75 and 0.18. The continuation legs mix scope extensions with fix rounds: 3d-anim-lab#49
  took 5 extra legs, 3 of them more plants.
- **Gate-runner: holds, in 3d-anim-lab only.** Per dispatch: 4.0, 4.3, 4.1, 3.3, 5.2 and 4.5
  (3d-anim-lab#48's two rounds, one red, the first with the tooling tier), then 3.5, 3.5 and 3.7.
  3d-anim-lab#71's round also carried the tooling tier and took 4.3. On the two light runs the gate
  is 14% of 3d-anim-lab#49's working wall and 44% of #97's. agent-skills has no gate-runner seat to
  measure.

## Implementer calls against the 60-call target

No dispatched phase exceeded 60 calls. The first legs ran 7–37, median 18.5. But one implementer
agent, continued by message through fix rounds, passed 60 in three runs: #76 (68 over 5 legs),
3d-anim-lab#48 (71 over 5) and 3d-anim-lab#49 (67 over 6). The Skill's target reads per phase, so
none is a breach as written. But every call in a later leg reads the agent's whole grown context,
which is the cost the target exists to cap.

## Wall and cost by tier

| Tier | n | Working wall, median (range) | Cost, median (range) |
|---|---|---|---|
| Full | 10 | 34.6 (25.3–46.2) | $9.83 ($6.99–$14.36) |
| Light | 2 | 24.8 and 8.4 | $6.84 and $2.52 |

Full-tier cost by project: agent-skills mean $11.18 (n = 4), 3d-anim-lab mean $9.32 (n = 6).
**Light is insufficient n**. Both light runs are 3d-anim-lab under the delegate, and one (#49)
overran its scope by three plants.

## Who held the stops

| Stops held by | Runs | Plan-stop wait | Close wait |
|---|---|---|---|
| Owner | #70, #71, #72, #76, 3d-anim-lab#92, 3d-anim-lab#71 | 1.4, 2.7, 17.0, 17.7, 1.5, 7.4 | 0.5, 633.7 (overnight), 1.9, 1.1, 5.8, 1.8 |
| Delegate (test run 1) | 3d-anim-lab#41, #42, #48, #49, #94, #97 | 0.5, 0.5, 0.6, 8.7, 0.4, none (light) | 0.6, 9.6, 0.6, 5.3, 3.4, none |

Owner waits ranged from 0.5 to 17.7 min, and one Close waited overnight. Delegate waits ranged from
0.4 to 9.6 min. The long delegate waits were a slow watcher (3d-anim-lab#49) and a Close blocked on
the finding-home rule (3d-anim-lab#42). On agent-skills #71 the owner also ran two shell probes by
hand inside the plan phase. **Waiting time, attendance and project are confounded in this sample.** No
attendance comparison is valid on it.

## Coverage of #93

**It does not cover #93's measurement.** The data overlaps #93's window but misses its required
cases and its instrument. #93 asks for the first five 3d-anim-lab runs after every other child of
#68 has landed, read by the audit's own transcript instrument. Those children were last to land at
3d-anim-lab#92 (`b4d4504`). The five runs that followed are 3d-anim-lab#71, #41, #42, #48 and #49.
Against #93's list:

- **A run under `shape: workflow`.** None exists. No 3d-anim-lab run used the workflow shape (its
  knob is still `subagents`), and #72's scripted runs were in a scratch repository.
- **At least one light ticket.** Present: 3d-anim-lab#49.
- **The compressed-brief trial** (two consecutive full-tier tickets with an advisor, cache writes
  per spawn against the 225k median). Not a clean trial:
  - The candidates are 3d-anim-lab#71 → #41 → #42.
  - #41 and #42 ran the advisor on the Builder-family model, not the Planner model the trial
    measures, and 3d-anim-lab#71's Planner-model advisor hit its usage limit on reporting.
  - The advisors' cache writes per spawn were 64.6k (3d-anim-lab#71), 84.1k (#41) and 91.5k (#42).
    All are under 150k, but only the first is a Planner-model figure.
  - No owner promotion decision exists to quote.
- **Dollars per run.** Here they are in the owner's local token-usage tools' convention. The audit's
  $41-per-run baseline came from a different instrument, so the two scales are not comparable until
  #93's `CUTOFF` run exists.
- **Calls per wrap** were not measured. Test run 1's sessions had no wrap.

What this note does give #93: each run's roster, as read from its record, is in the Sample table
above, and the light tier was honoured on 3d-anim-lab#49 and #97.

## What a design ticket can take from this, and how far

- **Keep:**
  - the advisor's slot 1, which is the cheapest material yield in the sample;
  - the critic, which is the only post-implementation seat that rarely draws a blank;
  - the Spec axis on record-shaped tickets.
- **Candidates to cut or gate by plan risk:**
  - the Codex lens, whose single in-sample hit was one unique finding in 9 runs;
  - the Standards axis on code tickets outside prose projects (0.08 per minute on 3d-anim-lab's
    code tickets).
- **The time lever is the serial first-pass review block, not the fix loop.**
- **None of this rests on more than 12 runs over one day, in two projects, under one
  classifier.**
  - Every per-minute rate has a bootstrap interval spanning roughly a factor of 2.
  - The M/W boundary is where the second reader hesitated.
  - Seats with fewer than 10 runs (the advisor, the lens and the targeted re-reviews) should be
    re-read after the next batch.

## Appendix: every finding, classified

Run labels: `#n` is an agent-skills ticket; `3d#n` is a 3d-anim-lab ticket. Seats: `advisor` is
slot 1 (and slot 3 where it shared the consult), `spec` and `standards` are the native axes,
`codex` the lens, `critic` the critic seat, `targeted` a re-review of a fix commit, and
`playthrough` a follow-the-text agent on #76. Codex runs that returned 0 findings have no rows:
#70, #71, 3d#92, 3d#71, 3d#41, 3d#42 and 3d#94. Nor do seats that returned 0: the Spec axis on
#70, 3d#41, 3d#42, 3d#94 and 3d#97; the Standards axis on 3d#42; the targeted re-reviews on 3d#71
and 3d#94.

| ID | Run | Seat | Finding | Outcome | Class |
|---|---|---|---|---|---|
| 70-A1 | #70 | advisor | Acceptance criterion 4 had no home in the execution spec | adopted into the spec before dispatch | M |
| 70-A2 | #70 | advisor | The spec's word ceilings contradicted its own replacement text | became per-file ceilings | M |
| 70-A3 | #70 | advisor | The stale-string grep read a gitignored path, and the spec's own example text would have tripped it | became git grep | M |
| 70-A4 | #70 | advisor | The diff-stat observable would read a peer session's uncommitted edit | re-pointed at main HEAD | M |
| 70-A5 | #70 | advisor | The slot numbering had to stay explicit | adopted | W |
| 70-A6 | #70 | advisor | The README edit had no observable | observable O7 added | M |
| 70-A7 | #70 | advisor | The AC 5 independent reader needed sentence-level rows plus a planted row | adopted | M |
| 70-A8 | #70 | advisor | The agent registry reads definitions lazily, so the validating check must re-read the file from disk | adopted | M |
| 70-A9 | #70 | advisor | Footer placement | adopted | W |
| 70-A10 | #70 | advisor | The Seat glossary entry should cover the Correctness fallback | adopted | W |
| 70-A11 | #70 | advisor | Historical is a new glossary entry form and needs a note | adopted | W |
| 70-T1 | #70 | standards | The retired term's _Avoid_ line listed no alternative term | line deleted | W |
| 70-T2 | #70 | standards | The Slot glossary entry restated the Skill's Fallback rule | replaced with a pointer | W |
| 70-T3 | #70 | standards | The glossary preamble ("every term is used") is contradicted by the Historical entry | declined | X |
| 70-C1 | #70 | critic | Re-classed the Standards findings as judgment calls; refuted one remedy | adjudication only | X |
| 70-C2 | #70 | critic | (adjudication of Standards 2) | adjudication only | X |
| 70-C3 | #70 | critic | (adjudication of Standards 3) | adjudication only | X |
| 70-C4 | #70 | critic | The AC 2 grep cannot see the Skill's paraphrased sentence | the record now quotes the sentence and the wider grep | M |
| 70-C5 | #70 | critic | The comment AC 4 requires on another issue was still unposted | posted with the record | M |
| 70-R1 | #70 | targeted | The Slot pointer named no section, and the Skill has two bold Fallback paragraphs | section named | W |
| 71-A1 | #71 | advisor | The sandbox failure was recorded against the wrong cause (another plugin's data directory) | Skill sentence now states only the measured denial | M |
| 71-A2 | #71 | advisor | The run did not meet the owner's condition that the review output echo the focus text | lens re-run with an echo line; plain run kept as control | M |
| 71-A3 | #71 | advisor | Edit 1 places a note beside a --base route the file does not have | one sentence added | M |
| 71-A4 | #71 | advisor | The ticket's single-line grep breaks if the paragraph wraps and cannot see the heading | per-line AC3 check | M |
| 71-A5 | #71 | advisor | A line still dates the section's measurements to an older plugin version | dating corrected | M |
| 71-A6 | #71 | advisor | The companion keeps its state in whichever plugin last exported the data variable | filed as its own gate:decide issue | D |
| 71-A7 | #71 | advisor | Background broker processes outlive the call | recorded in the run record's Raised section | D |
| 71-A8 | #71 | advisor | The lens found a real bug in another project's commit (respawn with a held stick falls through the floor) | filed on that project | D |
| 71-A9 | #71 | advisor | The Codex reviewer read the author's own review Skill, weakening vendor diversity | recorded, not acted on | X |
| 71-A10 | #71 | advisor | Another project's memory note repeats the old claim | not edited | X |
| 71-A11 | #71 | advisor | What the sandbox blocks with the variable unset is unknown | left unmeasured | X |
| 71-T1 | #71 | standards | The "never forward a lens" rule rests on a reason the caller can avoid; the source bars both forwarding agents from review commands | rule now names the bar on both agents | M |
| 71-T2 | #71 | standards | Two plugin version numbers read as stale under the section's own rule | refuted | X |
| 71-T3 | #71 | standards | A checkout detached at it does not say which checkout; detaching this one breaks the installed Skills | now "a temporary worktree" | M |
| 71-T4 | #71 | standards | A dangling "them" after an edit | declined as not worth the words | X |
| 71-T5 | #71 | standards | The --background claim cites a run that did not use --background (read from source, not measured) | parenthetical moved to cover only the measured half | M |
| 71-T6 | #71 | standards | its data directory reads as the companion's own | refuted | X |
| 71-T7 | #71 | standards | fix commits wait for the lens repeated three times | rejected | X |
| 71-S1 | #71 | spec | The record must name the exact focus used and cite the plain run as the control | applied in the record | M |
| 71-C1 | #71 | critic | (verdicts on four Standards findings) | adjudication only | X |
| 71-C2 | #71 | critic | (refutation of Standards 2) | adjudication only | X |
| 71-C3 | #71 | critic | (refutation of Standards 6) | adjudication only | X |
| 71-C4 | #71 | critic | (Standards 4 not worth the words) | adjudication only | X |
| 71-C5 | #71 | critic | The closing record would leak an identity string by quoting a home path | path redacted before posting | W |
| 71-C6 | #71 | critic | The Codex approval covers little: it never saw the owner's condition | record scopes the approval to two criteria and the word count | M |
| 71-R1 | #71 | targeted | review commands covers both plugins on one line and only Codex on the next | now "the companion's review commands" | W |
| 72-A1 | #72 | advisor | The spec's fixed point was stale; a false hard finding was guaranteed | fixed point corrected | M |
| 72-A2 | #72 | advisor | Whether the seat definition sets the model inside a workflow was unmeasured, and the planned probe could not go red | non-opus probe run before dispatch | M |
| 72-A3 | #72 | advisor | AC1's grep cannot go red on other model names | wider grep | M |
| 72-A4 | #72 | advisor | The gate schema has no place for parts of the report or NOT RUN kinds | verbatim report field and per-gate kind | M |
| 72-A5 | #72 | advisor | The verification plan never exercises the fix round or the drop path | fix-round plant added | M |
| 72-A6 | #72 | advisor | The Skill prose gets no playthrough | playthrough added | M |
| 72-A7 | #72 | advisor | The seat-tier upgrade has no home in the script | at-return tier check | M |
| 72-A8 | #72 | advisor | AC2 reads labels, not seats | join through agentId to agentType | M |
| 72-A9 | #72 | advisor | An implementer that stops still gets gated and reviewed | early end on no commits | M |
| 72-A10 | #72 | advisor | A failing sequential call may abort the script with nothing returned | try/catch into dropped | M |
| 72-A11 | #72 | advisor | The owner's effort request cannot reach seats inside the script | left as the owner's call; nothing changed | X |
| 72-A12 | #72 | advisor | A policy doc will contradict the shipped script | follow-up ticket | D |
| 72-A13 | #72 | advisor | The gate_runner knob is ignored; the seat name is hard-coded | optional gateRunner arg | M |
| 72-A14 | #72 | advisor | The section's word target is too tight to meet | content-wins clause applied | W |
| 72-A15 | #72 | advisor | The implementer's commit could land in the wrong tree | checkout input added | M |
| 72-T1 | #72 | standards | Bare "tier" is a glossary avoid-term | now code literals | W |
| 72-T2 | #72 | standards | The section's opening line is stale | corrected (half refuted) | W |
| 72-T3 | #72 | standards | roster means two things, so a check passes without testing anything | roster means only the plan-stop list, passed as an array | M |
| 72-T4 | #72 | standards | gateRunner is never explained; a missing seat drops the gate silently | explained | M |
| 72-T5 | #72 | standards | The measurement ticket points nowhere outside one project | adoption counted from the project's run records | M |
| 72-T6 | #72 | standards | An ADR and a policy doc still say a script pins a model alias | follow-up ticket | D |
| 72-S1 | #72 | spec | The script never reads the implementer's porcelain, so the gate can test uncommitted work | clean-tree boundary | M |
| 72-S2 | #72 | spec | The upgrade sentence contradicts the tier section | pointer to the tier section | M |
| 72-S3 | #72 | spec | The spec file's location is unstated and would dirty the tree | specPath placement stated | M |
| 72-S4 | #72 | spec | The Spec reviewer gets the ticket with no repository | refuted | X |
| 72-K1 | #72 | codex | A dirty implementer tree still gets gated | same fix as 72-S1 | M (dup of 72-S1) |
| 72-C1 | #72 | critic | The coordinator's notes misreport a probe as launched by path; it was refused and ran inline | corrected before the record | M |
| 72-C2 | #72 | critic | An inline launch does not run the Skill's file | never-inline and its reason | M |
| 72-C3 | #72 | critic | The return-time tree check has no consequence | a dirty tree at return voids the run | M |
| 72-C4 | #72 | critic | The adoption condition departs from the ticket's wording | put under Deviations for the owner | M |
| 72-R1 | #72 | targeted | Fix commits can go ungated when the fix implementer returns nothing | coordinator gates ungated fix work | M |
| 72-R2 | #72 | targeted | The at-return reason no longer matches the script's branches | reworded to match | M |
| 72-R3 | #72 | targeted | The --add-dir rule arrives too late and names no way forward | subagents fallback added | M |
| 72-R4 | #72 | targeted | The refusal claim may be too absolute | refuted | X |
| 76-A1 | #76 | advisor | Stamp census missing | applied to the spec | M |
| 76-A2 | #76 | advisor | Hard-to-reverse issue and label writes were relaxed by "every other write" | applied | M |
| 76-A3 | #76 | advisor | The playthrough needed a redesign | applied | M |
| 76-A4 | #76 | advisor | re-gating appears on both sides of the gated set | applied | M |
| 76-A5 | #76 | advisor | Placement stated only as placement | applied | W |
| 76-A6 | #76 | advisor | The mint stop conflicts with minting being ungated | applied | M |
| 76-A7 | #76 | advisor | The operation list should be derived, not typed | applied | M |
| 76-A8 | #76 | advisor | Edges should be re-checked at the re-gate | applied | M |
| 76-A9 | #76 | advisor | The floor check was missing | applied | M |
| 76-T1 | #76 | standards | Bare "tier" | applied | W |
| 76-T2 | #76 | standards | No gated-set pointer on the body-writes sentence | applied | W |
| 76-T3 | #76 | standards | A misplaced Seats line | applied | W |
| 76-T4 | #76 | standards | The mint stop against the ungated list | applied | M (dup of 76-A6) |
| 76-T5 | #76 | standards | Comment edit and delete were ungated | applied | M |
| 76-T6 | #76 | standards | Restore the childless-parent clause | refuted by source | X |
| 76-T7 | #76 | standards | Move the placement sentence | refuted by source | X |
| 76-S1 | #76 | spec | Comment edit/delete and label --force belong in the gated set | applied | M (dup of 76-T5) |
| 76-S2 | #76 | spec | The grep regex needed widening with a backtick calibration | applied | M |
| 76-S3 | #76 | spec | Per-section word counts were not recorded | recorded | M |
| 76-S4 | #76 | spec | A "relabel waits" hold | refuted: nothing would release it | X |
| 76-S5 | #76 | spec | The spec-child re-gate edge case | ruled rare; the reorder covers it | X |
| 76-K1 | #76 | codex | The re-gate adds edges from the undecided body and never removes the rejected branch's | applied in part: edge step after the cut, removes an edge only the cut branch named | M |
| 76-C1 | #76 | critic | Stale "§ Parents" pointers in two tracker pointer files | fixed | W |
| 76-C2 | #76 | critic | The edge step read the body before the cut | fixed | M (dup of 76-K1) |
| 76-C3 | #76 | critic | No pointer from the relabel-on-say-so clause to the re-gate order | fixed | W |
| 76-C4 | #76 | critic | Offset cuts | applied | W |
| 76-C5 | #76 | critic | Playthrough clauses left unexercised | second playthrough set run | M |
| 76-R1 | #76 | targeted | The "once it exists" trigger | fixed | M |
| 76-R2 | #76 | targeted | names a place | fixed | M |
| 76-P1 | #76 | playthrough | --force over an existing label | fixed (recorded as a wording defect) | W |
| 76-P2 | #76 | playthrough | its own ticket's body | fixed (recorded as a wording defect) | W |
| 76-P3 | #76 | playthrough | Edges for the decided branch | fixed (recorded as a wording defect) | W |
| 76-P4 | #76 | playthrough | A garbled finding-home clause | fixed (recorded as a wording defect) | W |
| 76-R3 | #76 | targeted | The re-gate edge step's "only the cut branch named" could not fire while the body still named that branch | whole body cut to the decided branch | M |
| 76-R4 | #76 | targeted | The unplanned-tickets section then re-required the edge | fixed at the source | M |
| 76-R5 | #76 | targeted | Listing the sections to cut left some uncut | fixed | M |
| 92-A1 | 3d#92 | advisor | The gate-runner's re-read cannot go red for a frontmatter edit | record the served model, labelled | M |
| 92-A2 | 3d#92 | advisor | The reader test and byte figures belong on the record | taken into the spec | M |
| 92-A3 | 3d#92 | advisor | A hedge on the light set | rejected: the owner ruled at the plan stop | X |
| 92-A4 | 3d#92 | advisor | Critic tier wording | taken, later superseded | W |
| 92-A5 | 3d#92 | advisor | grep critic as the concrete check | taken | M |
| 92-A6 | 3d#92 | advisor | A README is absent, and the ticket's own inline Seats line reads full | recorded | W |
| 92-A7 | 3d#92 | advisor | Coverage is by inspection: no gate loads the changed files | recorded on the record | M |
| 92-A8 | 3d#92 | advisor | Another seat definition has no model pin | filed as its own ticket | D |
| 92-S1 | 3d#92 | spec | gate line is undefined in the contract sentence | fixed | M |
| 92-S2 | 3d#92 | spec | The tier qualifier sits on one clause only | fixed | M |
| 92-S3 | 3d#92 | spec | Same as advisor finding 1 | accepted | M (dup of 92-A1) |
| 92-T1 | 3d#92 | standards | Reader test on the record | accepted | M (dup of 92-A2) |
| 92-T2 | 3d#92 | standards | Same as Spec 1 | accepted | M (dup of 92-S1) |
| 92-T3 | 3d#92 | standards | knob block's should be "Skill's" | narrowed and fixed | W |
| 92-T4 | 3d#92 | standards | Same as Spec 2 | accepted | M (dup of 92-S2) |
| 92-T5 | 3d#92 | standards | The light set | rejected | X |
| 92-T6 | 3d#92 | standards | A "duplication" that is the ticket's own specified text | rejected | X |
| 92-C1 | 3d#92 | critic | Drop "on the full tier" from the adapter: tier policy is the Skill's | fixed | M |
| 92-C2 | 3d#92 | critic | The measurement ticket's inline Seats line reads full under this rule | comment on that ticket | D |
| 92-C3 | 3d#92 | critic | The fresh-session model check belongs to the measurement ticket, not this run | record corrected | M |
| 92-C4 | 3d#92 | critic | Re-measure the bytes after the fix round | re-measured | M |
| 92-C5 | 3d#92 | critic | (supports a rejection already made) | adjudication only | X |
| 92-C6 | 3d#92 | critic | the line naming the gate tier is the glossary term; the other definition points at the wrong line | fixed | M |
| 92-C7 | 3d#92 | critic | (supports a rejection already made) | adjudication only | X |
| 92-C8 | 3d#92 | critic | Another seat definition has no model pin | routed to the same ticket as advisor 8 | D (dup of 92-A8) |
| 92-C9 | 3d#92 | critic | A contract claim outside the diff (the scan skips untracked files) is stale | comment on another ticket | D |
| 71L-A1 | 3d#71 | advisor | The approved expected-skip set is unreachable at the gate's severity | clause became "SKIPPED: none" | M |
| 71L-A2 | 3d#71 | advisor | Clause 1 has no failure disposition for a missing suffix | folded into the spec | M |
| 71L-A3 | 3d#71 | advisor | Missing hard limit: the gate-runner must re-read its edited seat file | folded into the spec | M |
| 71L-A4 | 3d#71 | advisor | The acceptance-list clause has no red state; write it as reporting | folded in | W |
| 71L-A5 | 3d#71 | advisor | A results record cites stale line numbers and asserts markers the diff removes | folded in | M |
| 71L-A6 | 3d#71 | advisor | The fail-open record carries live-voiced predicate prose beyond the bullets being superseded | folded in | M |
| 71L-T1 | 3d#71 | standards | The contract, seat and record disagree on a missing suffix | contract fixed | M |
| 71L-T2 | 3d#71 | standards | Cutting "stage every added file" also blinded the secret scan to new files | clause restored on the secret_scan knob with its real reason | M |
| 71L-T3 | 3d#71 | standards | A results record's sentence is now false because of this commit | put in the past tense, dated | M |
| 71L-T4 | 3d#71 | standards | A Skill outside the repo still teaches the old rule | handed to the owner | D |
| 71L-T5 | 3d#71 | standards | Mixed tense in another record | refuted (historical) | X |
| 71L-S1 | 3d#71 | spec | every acceptance is listed cannot hold | refuted by the critic | X |
| 71L-C1 | 3d#71 | critic | A calibration record still said "cannot see untracked files" in the imperative | fixed | M |
| 71L-C2 | 3d#71 | critic | CLAUDE.md named one clause of the three | fixed | M |
| 71L-C3 | 3d#71 | critic | No arm for a missing SKIPPED: line | arm added | M |
| 71L-C4 | 3d#71 | critic | The record's "Owner decision" heading covered a clause the run corrected | fixed | M |
| 41-A1 | 3d#41 | advisor | The control's expected count (18/18) cannot happen: the pin check counts itself | 19/19 and 18/19 | M |
| 41-A2 | 3d#41 | advisor | after tick 1 … facing runs every tick invites a 4-step reading | wording fixed | W |
| 41-A3 | 3d#41 | advisor | The same gap exists for three air rows | listed as an issue to file | D |
| 41-A4 | 3d#41 | advisor | A git restore hard limit | added to the spec | W |
| 41-T1 | 3d#41 | standards | The ramp comment duplicates an earlier comment | became a pointer | W |
| 41-C1 | 3d#41 | critic | (ramp-line remedy) | adjudication of Standards 1 | X |
| 41-C2 | 3d#41 | critic | A sim that copies the rows once passes the suite, against the sim's own comment | listed as an issue to file | D |
| 41-C3 | 3d#41 | critic | top_speed was caught only by float32 rounding | fourth assert pair added | M |
| 41-C4 | 3d#41 | critic | An oracle comment's count of base-oracle sims was made false by the diff | comment rewritten | W |
| 41-C5 | 3d#41 | critic | The acceleration derivation comment gave the wrong reason | comment reworded | W |
| 41-R1 | 3d#41 | targeted | The next comment sentence listed specific checks and was now incomplete | names categories instead | W |
| 42-A1 | 3d#42 | advisor | 21 of 21 cannot come true: the pin counts itself | 22/22 | M |
| 42-A2 | 3d#42 | advisor | Plants are only checked as reverted at handoff, not between plants | clean-tree check before every plant | M |
| 42-A3 | 3d#42 | advisor | The decelerating arm will likely miss the tolerance bar; the constant has no basis | tolerance basis named | M |
| 42-A4 | 3d#42 | advisor | Guess points: the west drive, a variable that does not exist, message shape | resolved in the spec | W |
| 42-A5 | 3d#42 | advisor | A seam arm for yaw wrap | arm and plant P9 added | M |
| 42-A6 | 3d#42 | advisor | The ticket's "three are checked against values" is false for two outputs | homed in a new ticket | D |
| 42-C1 | 3d#42 | critic | A bare glossary avoid-term in a new comment | fixed | W |
| 42-C2 | 3d#42 | critic | An oracle comment's inventory of what base-oracle checks read went stale | fixed | W |
| 42-C3 | 3d#42 | critic | A sim dividing by a hard-coded 1/60 passes both new asserts | accepted as known blindness, homed in a new ticket | D |
| 48-S1 | 3d#48 | spec | A doc sentence says a gotcha is stale | superseded in place | M |
| 48-S2 | 3d#48 | spec | The verdict must be scoped to the settings it was measured under | scoped | M |
| 48-S3 | 3d#48 | spec | A doc claims the typecheck import sees a promoted warning class | corrected: it cannot | M |
| 48-S4 | 3d#48 | spec | Controls should be quoted verbatim | narrowed: controls quoted | M |
| 48-T1 | 3d#48 | standards | A stale "three neighbours" comment | fixed | W |
| 48-T2 | 3d#48 | standards | No negative-path test | test added | M |
| 48-T3 | 3d#48 | standards | Fixture header too long | cut to two lines | W |
| 48-T4 | 3d#48 | standards | Duplications | two real ones cut | W |
| 48-T5 | 3d#48 | standards | Same as Spec 2 | accepted | M (dup of 48-S2) |
| 48-C1 | 3d#48 | critic | The known-bad as a tracked .gd against the inert-.txt fixture precedent | fixture switched to inert, precondition measured | M |
| 48-C2 | 3d#48 | critic | The check's needle is not class-specific | class-specific needle | M |
| 48-C3 | 3d#48 | critic | Three more stale claims in docs | superseded in place | M |
| 49-S1 | 3d#49 | spec | The verdict and count columns are relayed stdout, not retained-log content | record says so | M |
| 49-S2 | 3d#49 | spec | Plant C's second route is missing | added | M |
| 49-S3 | 3d#49 | spec | No row B and no citation of the gotcha behind plants C-E | explained and cited | M |
| 49-S4 | 3d#49 | spec | A file's coverage status is stated without saying it is inferred | marked as inferred from plant D | M |
| 49-S5 | 3d#49 | spec | The limits list misses a gap | bullet added | M |
| 49-S6 | 3d#49 | spec | No re-run instruction for an engine change | added | M |
| 49-R1 | 3d#49 | targeted | Plant C's diagnostics are attributed to a single route the source does not support | fixed | M |
| 49-R2 | 3d#49 | targeted | The minimum re-calibration plant is the one that reds either way | changed to plant E | M |
| 94-A1 | 3d#94 | advisor | The spec's physics-oracle step had the skin backwards | corrected before dispatch | M |
| 94-A2 | 3d#94 | advisor | Named the respawn predicate lines | added to the spec | W |
| 94-A3 | 3d#94 | advisor | Named the drive direction for the new guard | added to the spec | M |
| 94-A4 | 3d#94 | advisor | Named the expected red: three FAILs | added to the spec | M |
| 94-A5 | 3d#94 | advisor | Named the hard limits | added to the spec | W |
| 94-T1 | 3d#94 | standards | held used against the glossary's Held | rejected | X |
| 94-T2 | 3d#94 | standards | An oracle comment overstates what no test checks | fixed | W |
| 94-T3 | 3d#94 | standards | A comment names a start height no guard uses | fixed | W |
| 94-C1 | 3d#94 | critic | The physics oracle's one-tick dip is unrecorded | recorded under AC2 and in comments | M |
| 94-C2 | 3d#94 | critic | The respawn guard's comment claims a carry check its predicate does not make | comment reworded | W |
