## Close

1. Sweep `git status` in every checkout the run touched, after any fan-out.
2. **Load `git-flow-squash`**, or the `git-flow-*` Skill the project's Profile `fork:` names,
   before the merge. Nothing fires it from context.
3. **One approval covers posting the run record, the merge and the close**, given by the owner, or
   by the delegate inside a batch. Offer the diff, the record and the close in one message, naming
   the acceptance reading you took and why; act on the single yes. A ticket whose acceptance needs
   the owner's attended run stays open.
4. **Emit the kickoff** once step 3's actions land, a ticket left open for the owner included, as
   its own message, unfenced: the command the tracker's attended pick names, its rule after it
   (on `tracker-github`, the Skill's § Frontier and claim, the attended pick). The ticket is the
   invocation's first number, what follows it the rule. **Inside a batch** (§ Inside a batch) the
   kickoff is the tracker's frontier query under the batch's grant, never the attended pick. An
   attended pick that finds nothing pickable takes the contract's frontier-empty instruction;
   where it names none, the tracker's own empty-result rule (on `tracker-github`, the attended
   pick's) — and where the tracker's query cannot tell an empty result from an unminted label, run
   its label check and report which. Nothing else follows (no other
   query, grill or wrap): the run record is the tracker write, the kickoff the handoff.

**The run record is the tracker's closing record**: one comment on the ticket (in the file, for a
file ticket) carrying both structures — the headings `Slots`, `Gates`, `Review`, `Deviations`, and
each acceptance criterion by number with its evidence and the reviewed commit SHA (where `git-flow-squash` § (c)
applies, the commit scope and footer instead). `Slots` repeats
the profile block as dispatched, followed by `approved: owner` or
`approved: owner's delegate — <what the delegate read>` where the stop fired; inside a batch it
also names the batch grant. The body is the spec, and a run never rewrites its own ticket's body:
`gh issue edit --body` and its equivalents replace it wholesale. Checkboxes are the owner's; every observation, verdict and piece of evidence goes
in a comment.

**A green gate report covers the gates' own verdicts and nothing else.** Beside it — a gate-runner's
`OVERALL: PASS`, or your own run where `gate_runner` is `coordinator` — affirm in `Gates` the
`verify-gate` Chunk's rules other than its five gates. Check its `## Matches` lines against the
Chunk's clean-output rule, since only you know which warnings are new, and record each `(tier)` line
with why the dispatched gate tier left that gate out, a derived skip as the Chunk's full-gate rule
records one. A failed affirmation is a red certifying reading (§ Review): its fix is a round under
the caps.

**A criterion your run missed is the owner's to re-cost (§ Inside a batch); the ask must not make
your reading the default.** Produce the alternative as an artifact the owner can diff, not a number you
describe, and leave the criterion unticked either way.
