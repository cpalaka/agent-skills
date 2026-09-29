## Workflow shape

Before the script, you draft the execution spec, check out the run's branch in the checkout (the
script commits on whatever branch is checked out and never switches), post the profile, take the
stop where it fires and run slot 1 (§ Advisor slots). Every stage's prompt is fixed in the script,
so § Handoffs' Claude Code seat instructions reach a seat only through the spec: write them under a
`## Seat notes` heading, from the plan's changed paths, since the spec is drafted before any diff
exists; every stage's prompt names the spec, and the gate-runner's confines it to that section. The
script runs the implementer, the native axes with the Correctness charter beside them where
`bug hunter` is `correctness`, at most one fix round whatever `fix rounds` holds (its mechanism, not
a default) and a gate after it, here before the targeted review. With hard findings, the fix round
takes them and the gate follows it (`fixRound.gatesAfter`, `gates` empty); with none, the gate runs
(`gates`), and where it is red the fix round takes its failures and the gate runs again
(`fixRound.gatesAfter`). The script's certifying reading is `fixRound.gatesAfter` where
`fixRound.ran`, else `gates`, until a gate you run after return supersedes it (§ Review: the last
gate before the merge certifies). The stages the profile's `effort` value names (the implementer,
the Spec and Standards axes, the Correctness charter) are each dispatched by that definition name,
their stage `effort` set from the same name; the gate-runner is dispatched by the `gate_runner` knob
at `medium`. The script raises nothing: a `FAIL` in either list is a red gate, which turns nothing
on (§ Run profile's ratchet). The script never merges, writes the tracker or asks a question.

On its return you run the Codex lens where `bug hunter` is `codex`, adjudicate, fix, take the
targeted review (the critic, where on), run the certifying gate once more on the final tree where a
fix of yours landed (the script's gate no longer certifies), merge and write the record. The
script's fix round takes the hard findings unadjudicated, its seat checking each against source; you
adjudicate every finding, the rest and the lens's included, before the targeted review. So here the
fix round and its gate precede your adjudication and the targeted review: a standing property of
this shape, not a `Deviations` entry. **The targeted review** (§ Review; the critic, where on):
where `fixRound.ran`, its charge names every fix since the implementer by commit range,
`<implementer's last commit>..HEAD`, HEAD read at its dispatch and the implementer's last commit the
first token of the last `implementerReport.commits` entry, so a fix seat that was dropped or
committed nothing, and your own fixes after return, are covered; where only your lens fixes form
the round, the range runs from the commit before your first fix to HEAD. A Codex lens reading NOT
RUN fires the Correctness charter after return too, yours (§ Review's fallback), at the definition
the profile's `effort` line gives the bug hunter. The script's fix round precedes the lens, so it
leaves its work committed (`--base` reads only commits); fixes for the lens's findings are yours
(§ Review). The script's fix round and your lens fixes together are the run's first material round
(§ Run profile's caps); any round up to `fix rounds` past it is yours after the script returns, a
round past `fix rounds` is the fix-round cap stop, and it and the wording round are yours.

**Launch `workflow.js` beside this file by path**,
`Workflow({scriptPath: "<this Skill's directory>/workflow.js", args})`, from a session started
with this Skill's directory added (`--add-dir`): the tool refuses a `scriptPath` outside the
working directory and added directories, even after a Read of the file. Without that, run
`subagents`. Never inline it: an inline `script` is a transcription, not the file.
`args`: `{ticket, checkout, fixedPoint, specPath, gateTier, profile, gateRunner?}`, the script's
field names, any other field throwing — `ticket` the issue reference; `gateTier` the profile's
`gate tier` spelled out as `review.md`'s gate-runner dispatch paragraph says — read that paragraph
before launch; `profile` the posted block
transcribed to an object, keyed by the dial tokens verbatim, spaces included, except that the
`effort <seat>` dials nest as one `effort` object mapping each seat token to its definition name:
`{standards: "off", "bug hunter": "codex", effort: {implementer: "implementer-medium", spec: "code-reviewer-medium"}}`;
`gateRunner` the `gate_runner` knob's seat when it is not `gate-runner`; `specPath` outside the
checkout or ignored there, since the implementer commits everything and the spec stays uncommitted
(§ Seats). It returns `{gates, findings, implementerReport, fixRound, dropped, gateReports}`.
**Resume**: stop the run, relaunch with `resumeFromRunId` and the original `args` verbatim — a
resume drops them, and identical ones keep the journal's cache keys. **It needs a gate-runner seat
the launching session can dispatch** (§ Cross-repo gate-runner); a project on
`gate_runner: coordinator` has none, so runs `subagents`.

**At return**, read the checkout's `git status --porcelain --untracked-files=all` yourself:
non-empty, less any untracked (`??`) path a gate wrote, means the script's work is not all
committed, so the scripted run does not count and you finish the ticket under `subagents` from the
commits already made, committing nothing on its behalf. A path a gate wrote is one listed in a
`gateReports` entry's `outputs`: the exact untracked files that gate's own porcelain listed under a
path its report named, never a named directory as a whole. Read each `gateReports` entry's
`seatNotes` as well: where the spec's seat notes had the gate-runner re-read a changed file,
whether the file differed is there, and the record quotes it; `null` is a dropped gate. `fixRound.ran` with
`gatesAfter` empty means no gate saw the fix work (a dropped fix seat may have committed): the
certifying gate you run last covers it (§ Review). Reconcile `dropped` against `journal.jsonl`,
which gives each call's label, `agentId` and return value (the `started` records carry the label):
the definition each stage was dispatched by is `agentType` in that agent's `agent-<id>.meta.json`
beside it (`workflow-subagent` there is what an omitted `agentType` records), its model and effort
are on its `agent-<id>.jsonl` assistant records, and an implementer's calls are the `tool_use`
blocks in that transcript other than `StructuredOutput`, the schema return a `subagents` implementer
never makes (the `scope` cap), one past the cap under `Deviations`. Check the diff's paths against
the plan's changed-path set: a path outside it ratchets (§ Run profile). Inside the script a dropped
gate reads green and a dropped review clean, so at return: for a `gate` or `fix:gate` label in
`dropped` you run the certifying gate last, and before the targeted review you dispatch each review
the profile now calls for that the script did not return, at its definition (both read off the
profile as § Run profile's ratchet leaves it at return). A dropped `review:correctness` is never
recorded as `FINDINGS: 0` (§ Review).

**Adoption**: `knobs.shape` in `defaults.yaml` does not change to `workflow` until three clean
scripted runs — certifying `OVERALL: PASS` (a project's `(tier)`, `(judgment)` or `(prescribed)`
NOT RUN line never moves it) with each of the five gates on a `GATE` line or a line below
`OVERALL`, and every `OWNED ELSEWHERE:` line closed by its seat's verdict or its not-due clause,
quoted in the record, calls sent reconciled against results returned in `journal.jsonl`, each
agent's model read from its `agent-<id>.jsonl` — counted from the project's run records.
