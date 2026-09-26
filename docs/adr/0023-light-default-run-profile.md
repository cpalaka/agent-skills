# A run posts a light default profile; the owner turns add-ons on; `xhigh` is retired

**Status:** accepted — 2026-09-26. Supersedes [ADR 0018](0018-run-profile-derived-from-plan.md).
0018's amendment of [ADR 0011](0011-roles-not-cost-tiers.md)'s effort clause stands as amended
here: `medium` the default on every profile seat, `high` an add-on, `xhigh` retired. Decided on
cpalaka/agent-skills#101 in a grill on 2026-09-26; the owner's replies are quoted in the ticket's
re-gate comment. It absorbs #98's Codex-command question.

## Context

ADR 0018 derived each dial from the plan, and one instruction file in the diff turned every seat
and effort dial on. In this repository every Skill, Chunk and seat definition is an instruction
file, so nearly every ticket derived the heaviest profile: the derivation could not tell a 10-line
pointer fix from a new 3,700-word Skill.

#96, the `implement-batch` Skill, measured what that costs. It ran about 1 h 40 min, of which
implementation took 7 min and verification about 75%. The first review wave paid for itself, but
its three arms overlapped: the defects that mattered were each found by one to three sources, one of
them a $1.42 playthrough, and the Standards and Spec axes mostly added duplicates and wording. Fix
rounds 2 and 3 took 34 min and fixed defects the previous round's remedies introduced, all in one
embedded shell block that a playthrough passed because it never ran the block against a known-bad.
At the cap stop the coordinator recommended a third round though the residue failed safe.

Four more runs said the same from the other side. On #29 and #112 the owner cut an instruction-file
profile at the plan stop, and each reduced run held: on #29 nothing showed a finding only an `xhigh`
seat or the critic could have caught, and on #112 the one hard finding came from the Correctness
charter kept because part of the diff was code. #30's playthrough derived the heavy profile for a
one-file `CONTRIBUTING.md` outside every default `light_set` glob, on a `gate:agent` ticket; the
owner asked for a lighter run and the session could not comply, since 0018 gave no dial a way down.
#29's and #30's records both lowered dials as an owner override the Skill gave no standing to. #121
is the fourth such cut. A cost review of five runs over $20 added one more cause no dial reached: a
fix round that re-ran whole measurement matrices, and a mid-run defect fixed in the ticket rather
than split off.

## Decision

1. **Reviews.** The default review set is the Spec axis and the Codex lens (`bug hunter: codex`);
   a light plan gets the Spec axis alone. The Standards axis, the critic seat and the Correctness
   charter are add-ons. A run never has more than one bug hunter: the Correctness charter is the
   Codex lens's fallback on NOT RUN, or the owner's choice in place of Codex at the stop. The
   fallback runs at `code-reviewer-medium` unless the profile raised `effort bug hunter`.
2. **Codex command (#98).** The lens keeps `adversarial-review` with the staged focus and the
   test-gap line. It took the focus, returned a recordable `.result`, and found 3 of 4 planted
   defects on #90's fixture (4 of 4 with the test-gap line), against native `review`'s 2 of 4 with
   no `.result`. Known confound: one fixture, never measured on real diffs. With the critic off by
   default, its design-challenge framing partly covers the critic's charge of asking whether a
   remedy overreaches.
3. **Advisor.** Off by default. The coordinator recommends slot 1 only by naming the premise or
   design question it cannot settle alone; slot 3 opens only where the advisor is on. The existing
   fallback for a run with no advisor, holding the judgment and asking the owner at the same
   triggers, now covers the default.
4. **Effort.** Every profile seat defaults to `medium`; `high` is an add-on; `xhigh` is retired, its
   definition deleted with its link, and the red-gate raise of the critic removed. Two definitions
   keep `high`: the advisor, an add-on as a whole, and the batch `coordinator`, the main loop rather
   than a dial. The mechanism is 0018 § 7's: an effort value is a definition name. The `-medium`
   name is now the default dispatch and the bare name the `high` add-on; no definition is renamed.
5. **Fix rounds.** One by default. A second is the **fix-round cap stop**, whose ask offers "land
   and file the residue" beside "one more round" and states which way the residue fails; residue
   that fails safe (its failure ends in a stop or a refusal, never a silent pass) defaults to
   landing; residue that fails open carries no default. A second round is never an add-on: the
   `fix rounds` dial rises only at that stop or by a plan pin with a reason. The order is axes and
   bug hunter → adjudication → fix round, re-verified by a check aimed at the fix → targeted review
   → certifying gate on the final tree, the last step before the merge. The targeted review is one
   `code-reviewer-medium` review of the fix diff, handed the accepted findings, with no Codex
   re-run; where the critic is on, it is that review, run over the whole diff whether or not a
   round ran. Only a red certifying reading re-runs the gate, its fix a round under the cap. Under
   `workflow` the script's fix round and the coordinator's fixes for the lens after return are
   together the one material round, and a fix landing after the script's gate re-runs the
   certifying gate on the final tree, a standing cost of that shape. The wording-only round stays
   uncapped, takes no re-review, and is checked by the scans that read prose, the certifying gate
   following it where it lands after the gate.
6. **Plan stop.** The plan and profile block are always posted. The stop fires only on a
   recommended add-on or a pin above default. At the stop, or by interrupting after the posted
   profile, the owner may lower any dial except the Spec axis, a pinned one included, recorded under
   `Deviations` as the owner's decision. A pin stays a lower bound on the coordinator: only the
   owner lowers one.
7. **Instruction files.** One in the diff makes the coordinator recommend the Standards axis, where
   its measured yield is (0018's #86 amendment: 10 of its 11 findings on such diffs). It turns
   nothing on by itself.
8. **Inside a batch.** The delegate declines every recommended add-on; the ticket runs the default
   and the record names each declined recommendation. A pin still applies, since it is the owner's
   own decision made at filing, not a recommendation. The delegate still answers the fix-round cap
   stop on its merits: the decline covers recommended add-ons only.
9. **Playthroughs**, in this repository's contract: one per Skill, Chunk or Template change; more
   only on the coordinator's recommendation or where the acceptance criteria name them.
10. **A command block in an instruction file is code.** It ships only after a fixture run in which
    a known-bad input turns it red, and a fix-round remedy that adds or changes one is measured the
    same way before adoption — in the contract's prose-deliverable paragraph and one clause of
    `implement-run` § Review. A fix round re-verifies with a check aimed at the fix (the failing
    cases, those the findings name, a sample of what passed); a verification whose cost scales with
    the whole suite or matrix runs once, on the final tree, as the certifying gate (§ 5's order); a
    new defect a review finds mid-run is recommended as a split-off ticket unless its fix is small.
11. **Scope.** Global, since `implement-run` is one Skill. No per-project knob.

**The ratchet raises defaults only.** A diff path outside the plan re-derives the defaults with it
in — a plan leaving the light plan turns `bug hunter` to `codex`, the gate tier's default is
recomputed — and a deliverable the plan did not count stays `scope`'s stop. It turns no add-on on:
a red gate re-runs its gate as a round and turns nothing on; only a material finding that argues for
another seat becomes an add-on recommendation, carried to the next owner stop, the fix-round cap
stop or the Close approval.

**Carried forward from 0018 unchanged:** the light plan and instruction-file definitions (§ 1, less
the dials an instruction file turned), pins beside the acceptance criteria and never levels (§ 2),
the gate tier as a dial raised by pin only (§ 6), the model outside the profile and effort's two
carriers (§ 7), the scope cap and the 60-call ceiling (§ 8), and the profile block (§ 9), which now
adds one `recommend <token>: <value> — <reason>` line per recommended add-on.

## Considered options

- **The four options, (a) to (d), the ticket first listed.** Superseded in the grill by the design
  above; the ticket's body now carries only the decided branch.
- **Keep 0018's derivation and widen `light_set`**, the route #30's owner took for
  `CONTRIBUTING.md`. Rejected as not enough: a glob reaches only files that are no instruction file,
  and in this repository nearly every diff is one, so the heavy derivation stands wherever it cost
  most; and it still leaves the owner no way to lower a dial on a run, which #29, #30, #112 and #121
  each did anyway.
- **Keep `xhigh` for the critic and the Correctness charter.** Rejected: 0018's own Consequences
  call every effort other than `high` a hypothesis, and no run on the ticket showed a finding only an
  `xhigh` seat caught.

## Consequences

- The default run costs less: one axis and one lens at `medium`, no advisor, no critic, one fix
  round. What is accepted with it: the critic's measured yield, a material defect in 9 of 10 of
  #84's runs, is now opt-in, and the Codex lens as default rests on one fixture.
- The owner has a sanctioned lever: lowering at the stop, recorded as a decision rather than an
  override.
- #105 and #107, whose briefs are for seats this decision makes add-ons, are blocked by #101. #109
  measures the Standards axis on a code diff; any change to its instruction-file recommendation
  waits on that evidence.
- `implement-run`, `workflow.js`, the seat definitions and their README, `multi-agent-policy`, the
  contract and the glossary change on #101. ADR 0018 and every earlier ADR naming `xhigh` stay as
  written.
