---
name: implement-run
description: How one ticket is run — the run profile derived from the plan, the seats, the advisor's slots, the gates, the review lenses, the closing run record and the kickoff. Slash-only (/implement-run); the third-party /implement stub carries none of it.
disable-model-invocation: true
---

Loaded by name, or by path by a delegated coordinator (§ Inside a batch). The third-party
`/implement` stub carries none of this and stays unedited, unshadowed and unwrapped.

**Knobs**: `<!-- knobs:implement-run -->` in the project contract your host adapter names, read
from the file on disk, never from a copy injected into your context: Claude Code strips every
HTML-comment line from what it injects, so the marker, and with it the block, reads absent there,
though its value lines survive unmarked. A contract that cannot be read is a stop: name the path.
One that reads with no block takes the defaults, and the knob statement § Start asks for says so:
`no knobs:implement-run block in <path>; defaults`. Where the session is rooted elsewhere, this and
every other read of the project contract here is the target project's (§ Advisor slots,
Cross-repo gate-runner).
`shape` (`subagents` | `coordinator-pane` | `workflow`; default `subagents`), `layout`
(`parallel-when-disjoint` | `serial`; default `parallel-when-disjoint`), `gate_runner` (a seat or
`coordinator`; default `gate-runner`), `advisor` (a seat or `none`; default `advisor`), `light_set`
(repository-relative globs, `**` matching any depth and a bare filename matching at the repository
root only, written as a numbered list under its bullet; default `docs/**`, `CONTEXT.md`,
`README.md`). `subagents` is described here in full, and `workflow`'s hand-off points in § Workflow
shape; the other shapes and the heartbeat recipes are in `multi-agent-policy`'s
`COORDINATOR-PANE.md` and `WORKFLOWS.md`, read only where that Skill's directory exists under
`~/.claude/skills` or `~/.agents/skills`.

**Inside a batch.** A brief that states the owner's delegation means this run is one ticket of a
delegated batch, dispatched by the delegate, the main session standing in for the owner. There the
shape is `subagents` whatever the knob says — the Workflow tool is absent at depth 1, and a pane
driven from a subagent is unmeasured — and every stop this Skill gives the owner goes to the
delegate, handed back in the form the brief names: `STOP <kind>`, nothing pending (`implement-batch`
§ Hand-back and resume, read only where that Skill's directory exists under `~/.claude/skills` or
`~/.agents/skills`). In a `coordinator` dispatch the role is that definition's pin and the meter is
the delegate's read, so neither is asked. A herdr pane child whose prompt states the delegation, the
fallback transport, is a main session instead: it reads its own role and meter as § Start and
§ Advisor slots say, and a Planner pane asks the delegate, which parks it, since a role switch is
not among the delegate's stops. The delegate answers the plan stop; the Close approval; the two cap
stops, each handed back as `STOP plan`, since a cap raise is a plan pin, which fires the plan stop
(§ Run profile); a slot-3 need, where an advisor runs, only after the advisor and only for what the
advisor cannot settle; and a false premise met mid-run whose disposition leaves every acceptance
criterion satisfied in form with the failed premise named — after the advisor where one runs,
handed back as `STOP slot-3` where none runs (the dial off, or the advisor unavailable, as Fallback
lists). Every other stop parks the ticket for the owner, such as a re-cost, a judgment the project's
contract reserves, a `gate:decide`-shaped question or a gated write outside the batch grant. A gated
write the grant names is no stop: the grant is its approval, and the run record names that write
under `Slots` beside the grant. Load this file by path: the Skill tool's refusal of a slash-only
Skill, with its text against replicating the workflow by other means, addresses a session
replicating it for itself, not a coordinator the owner delegated.

## Seats

Each from a pinned definition, dispatched by name: the bare name carries the default effort, a
suffix any other (§ Run profile). No dispatch of a definition that pins a model passes `model`: the
model is pinned by role in the definition, and a second model family on a diff is the `codex`
bug-hunter value, never an override. One whose definition pins none passes it (§ Advisor slots,
Cross-repo gate-runner).

- **Coordinator** — the main loop: drafts the per-phase execution spec (prose in the dispatch
  prompt, never committed unless the ticket names a home for it), dispatches, adjudicates every
  finding against source, merges. Writes no implementation diff; runs no gate where a runner
  resolves. Under a batch, a depth-1 dispatch of the `coordinator` definition (§ Inside a batch).
- **Implementer** — `implementer` (`high`) or `implementer-medium`; one fully specified phase,
  returning a handoff report. `layout` says only whether two phases may be in flight at once:
  `parallel-when-disjoint` when their files are disjoint, `serial` never. Worktrees are
  `parallel-work`'s decision: one phase in flight is its single-task case and takes none; a second
  is its explicit signal, each implementer in its own tree.
- **Advisor** — `advisor`, `high` only; slot 1, one consult (ticket, spec, first question); slot 3
  continues it by message or spawns fresh.
- **Reviewer** — `code-reviewer` (`high`), `code-reviewer-medium` or `code-reviewer-xhigh`, filling
  the Spec axis, the Standards axis, the Correctness charter and the critic (§ Review), each a
  fresh dispatch with its charge named; `/code-review`'s sub-agents are this seat only when
  dispatched by the definition names the profile's `effort` line gives, for the dials that are on.
- **Gate-runner** — the project's `.claude/agents/gate-runner.md`, `medium` only. Whoever re-runs a
  gate never wrote the diff. Out of a session's reach when rooted elsewhere: § Advisor slots. In
  every shape its dispatch (§ Workflow shape, `gateTier`) names the checkout and the profile's
  `gate tier` spelled out as only the gates to run: each of `verify-gate`'s five it takes by its
  knob key, `build` carrying `build_check`, which is never listed as its own gate; any other gate (a
  project gate, a trigger-table pull, a key of the `<!-- knobs:verify-gate -->` block beyond the
  eight the engine stamps — the five, `build_check`, `dir`, `env`) by name with its command as given
  (the contract's trigger table or knob value, or the seat's `## Project gates`), reading that
  block's keys and values alike on disk, as Knobs says. It lists none left out: the seat derives
  none and marks those itself.

**Toggles**: `solo` turns delegation off, review stays on; `orchestrate` turns it back on.

A long-running seat needs a heartbeat; the recipes are in `COORDINATOR-PANE.md`, under the Knobs
install gate.

## Run profile

Plan first, then derive the run profile from the plan, one dial at a time. Each dial has a default
and one trigger, read off what the plan shows: its changed paths against `light_set` and the
project contract's trigger table, an instruction file among them, and its expected implementer calls. Your
confidence in the ticket's premises is no input: you cannot see your own false premise, which is
why slot 1 runs on every plan above the light plan. The first column's tokens name the dials in a
pin, the profile block and the workflow script's `args.profile`.

| Dial (token) | Range | Default | Turned by |
|---|---|---|---|
| `implementer`, `gate-runner`, `spec` | on | on | always |
| `standards` | off, on | off | an instruction file in the diff, or a pin |
| `advisor` (slot 1; slot 3 available) | off, on | off | any plan above the light plan |
| `critic` | off, on | off | any plan above the light plan |
| `bug hunter` | `off` < `correctness` < `codex` | `off` | any plan above the light plan, as `correctness`; `codex` by pin |
| `gate tier` | a named tier of the project contract plus any trigger-table pulls; where the contract names none, one full gate less `verify-gate`'s derived skips | the lowest tier plus every trigger-table pull for the changed paths | a pin only |
| `effort <seat>` | `medium` < `high` < `xhigh`, each seat within the definitions § Seats lists for it | `high`; the gate-runner `medium`, its only value | a light plan derives `medium` for `implementer` and `spec`; an instruction file in the diff or a red gate derives `xhigh` for `critic` and the Correctness charter, where on |
| `fix rounds` | 2, or a higher integer with a reason | 2 | a plan pin with a reason |
| `scope` | the plan's deliverable count; 60 tool calls per implementer dispatch | the plan's count; 60 | a plan pin with a reason |
| plan stop | none, stop | none | any dial above its default, a pin above default included |

**A light plan** is one whose every changed path matches `light_set`, is loaded by no gate, and is
no instruction file; any other plan is above the light plan. The instruction-file test runs first,
so no glob makes one light. "Loaded by no gate" is `verify-gate`'s derivation: grep what references
the path and name the gate that loads it. On a light plan every unpinned dial sits at or below its
default, so only a pin above default stops the run.

**An instruction file** is whatever a host injects (a host adapter, the project contract, every
contract or Chunk they import), every file under a Skill's directory, every seat definition, and
every file one of those names as a read. *Named as a read* means named to be followed as
instructions — a Chunk, a Skill, a contract, a seat body, a procedure — not a glossary, README, ADR
or results record cited for reference: a host adapter or contract may name `CONTEXT.md` or `README.md`, and
the default `light_set` holds both on purpose. One in the diff turns every dial the table gives an
instruction file or a plan above the light plan. It changes the instrument the next run reads, and
the Standards axis found 10 of its 11 measured findings on such diffs.

**Effort** is dispatched as a definition name (§ Seats). A light plan's `medium` sits below the
default and fires no stop, since speed is preferred where no gate loads the diff. The Codex lens
takes no effort, and on a Codex host the role files keep `high`, so a seat there dispatches its role
file bare: the block posts each `fixed by host`. Expected implementer calls turns no dial: it
sizes phases and sets the `scope` cap.

**Pins.** The ticket author pins a dial on its own line directly above the acceptance heading, or
anywhere in the body where the tracker's ticket has none, `Pins: <token>: <value>`, several
separated by `;`: `Pins: critic: on; gate tier: 2; effort critic: xhigh`. The `<seat>` of an effort
token is one of the seat tokens above. A pin is a lower bound: the dial takes the higher of pin and
derivation, nothing lowers it, and a decision to lower a dial has no pin. A line naming an unknown
token, `fix rounds` or `scope` (only a plan pin raises those, its reason on the block line), or a
value outside its range reads as absent, noted under `Deviations`. Adding a pin to a ticket not yet
started is the tracker Chunk's body write for adding an acceptance criterion. Two retired forms read
as absent, a `Seats: light` or `Seats: full` line (the retired seat tier) and the
`Advisor: pre-dispatch only` marker: no pin is inferred, the run derives, and the record notes the
line was present and read as absent. A body sentence naming a gate tier in prose ("runs tier 2",
"Gate: tier 1") reads as a pin on `gate tier` alone, marked `pin (tier sentence)`. No open ticket's
body is rewritten to remove either.

**The ratchet** only raises, under `Deviations`, and reopens no stop. A diff path outside the plan's
changed-path set re-derives the profile with that path in (for the gate tier, its default
recomputed as the lowest tier plus the new set's trigger-table pulls, not the dial turned, which only
a pin does), unless it adds a deliverable the plan did
not count, which is `scope`'s stop; a material finding turns on an off seat that runs after its
finder in § Review's order, so on a light plan a material Spec-axis finding turns the critic on; a
red gate re-runs that gate and raises `effort critic` and the Correctness charter's effort to
`xhigh` where those dials are on, turning no seat on and never the gate tier. Nothing mid-run lowers
a dial. An `advisor` raised after dispatch opens slot 3 only: slot 1's moment has passed, and the
record says so.

**Caps** are constants, not risk-derived. `fix rounds`: two material rounds; a third is a stop.
Wording-only findings ride the last material round or form one closing round that counts toward no
cap; it re-runs every gate `verify-gate`'s skip rule cannot skip for its paths and every scan that
reads prose, since a scan can match prose a fix round wrote, and takes no targeted re-review — you
check the wording diff against the findings you accepted. `scope`: the plan's deliverable count, and
60 tool calls per implementer dispatch, counted from its transcript; one past 60, in any shape, goes
under `Deviations`. Cost is near-linear in calls, 0.15–0.20 USD each; in the token-usage audit behind
cpalaka/agent-skills#68, phases at or under 60 calls cost 1–9 USD, 60–85 cost 8–10 USD, past 85,
13–32 USD. A
continued dispatch keeps its count, so one at 60 is never continued by message: its next leg, a fix
round or the phase's remainder, goes to a fresh implementer handed the findings and the diff,
counting from zero. A phase the plan expects to exceed 60 is split before dispatch. Work past the
deliverable count is a stop, never a ratchet: more work is the reader's scope question. **A plan
pin** raises `fix rounds` or `scope` in your own plan, its reason on that dial's block line,
`fix rounds: 3 — a migration and its revert are two rounds by construction`; it sits above default,
so it fires the stop.

**The profile block** is one line per dial, `token: value — the fact that set it`, pins marked
`(pin)`; the effort dials share one line naming the definition dispatched per seat, the
gate-runner's fixed value unlisted:

```
effort: implementer-medium, code-reviewer-medium (spec) — light plan
effort: implementer, code-reviewer (spec), code-reviewer (standards), code-reviewer-xhigh (critic), code-reviewer-xhigh (bug hunter), advisor — instruction file in the diff
```

Post it in the run's first message, whatever the plan; inside a batch that message is the brief's
first output, which the delegate reads at the first hand-back or at Close. The run record repeats it
as dispatched (§ Close), and every ratchet goes under `Deviations`.

**The stop** fires only when a dial sits above its default: the reader approves the profile before
any dispatch. The reader is the owner, or the delegate inside a batch. At or below default, post
and go on.

## Start

The chain is **pick → plan → profile → stop, only above default → implement → verify →
sign-off**. Every run plans and posts the plan, whatever its size: 1–5 chat bullets naming the
changed paths, the deliverable count and the expected implementer calls, which the profile reads.
Read the ticket's `Pins:` line and any tier sentence, derive the profile (§ Run profile), and post
plan and profile block together; where the stop fires, get approval before code. Plan by question
type: fuzzy idea → `grilling`; data-model or state-machine doubt → `prototype`; look-and-feel doubt
→ a minimal build and an `agent-browser` screenshot loop; codebase-bound, clear what, unclear how →
plan mode. Verify is the `verify-gate` Chunk; sign-off is the Done gate the project's tracker chunk
sets, or its own inline rule.

State the knob values in force, asking only where the ticket cannot fit them, and this session's
role; if it is not Builder, ask the owner to switch (§ Inside a batch), and stay on Planner (the
metered role) only on their say-so.

**Close any stateful editor for the dispatch window**: it is a second writer whose in-memory flush
lands after the gates read the tree, so stale state passes green. Commit nothing inside the
window; reopen it after standdown. Under a worktree this lapses.

## Advisor slots

Announce each.

1. **Pre-dispatch**, wherever the `advisor` dial is on, always, spawned or held (Fallback). After
   checking the drafted spec's premises against source, one pass looks for a false or unverified
   premise, a missing hard limit, an observable that cannot go red, and — pasted verbatim — *what
   will this run raise that the ticket does not list?* It names no claim of yours, so it audits
   your world, not your sentence. The advisor definition's fourth differs — a finding it supplies,
   not a question you ask; never sync the lists. Check the spec's *mechanisms* against its stated
   *intent* too: no review or gate written from the spec can catch a mechanism that contradicts
   it, since the deliverable matches. **A prose deliverable** (record, Skill, Chunk) loads in no
   gate: its observable is an independent reader given the source rows, not the writer's table,
   calibrated by one planted absent row whose count is read, beside a fresh agent's playthrough of
   it.
2. **Pre-merge** — now the critic seat, a Builder dispatch (§ Review); no advisor consult.
3. **Floating**, wherever the `advisor` dial is on — a reading you would otherwise decide silently
   or put to the owner: a review finding you want to reject, one that would change an acceptance
   criterion, a ticket premise reading false against source, a gate still red after one
   `diagnosing-bugs` loop. A fourth need goes to the owner (§ Inside a batch).

Never the advisor: gates, reading a diff for conformance, prose records, git mechanics, a task
scoped to named files. Read the meter before spawning; the owner decides a tight one
(§ Inside a batch).

**Fallback.** A tight meter funds slot 1; slot 3's triggers then go to the owner
(§ Inside a batch), and the critic, a Builder seat, spends no Planner meter. Advisor unavailable
(no definition this host can dispatch, meter spent, knob `none`): hold the judgment yourself, ask
the owner at the same triggers (§ Inside a batch), say so. That is self-review unless slot 1's
observable that cannot go red becomes a question the implementer's dispatch prompt asks before it
writes code — a spec's author is the last reader to see that an observable does not mean what they
intended. Gate-runner unavailable (the target project stamps none) or knob `coordinator` (the target
project's; see Knobs): run the gates yourself, say so.

**Cross-repo gate-runner.** A project-local seat resolves only in a session rooted in its project,
and nothing names the cause: working on project X from a session rooted elsewhere, a dispatch of X's
seat returns `Agent type '<name>' not found` — or, unmeasured, reaches a seat of that name your own
project or user scope holds. So the test is never the error: it is the session's root, or, in a
session rooted in X, a seat stamped since the session started. Where X's `gate_runner` knob names a
seat and X's `.claude/agents/<seat>.md` exists, X's contract keeps the gate apart from its judge,
and running the gates yourself would overrule it. Dispatch `general-purpose` instead, with `model`
set to the definition's frontmatter `model:`, its body below the frontmatter verbatim, then the
checkout, whatever else that body asks its prompt to name, and a request to name each path its gates
wrote. `general-purpose` pins no model and would inherit yours. The Agent tool takes no effort, and
`general-purpose` holds tools the definition's `tools:` withholds, so the seat's effort is not kept
and nothing enforces its read-only rule: read the effort off its `agent-<id>.jsonl` (`.effort`), and
before and after it take `git -C <X's checkout>` `rev-parse HEAD`, `status --porcelain` and
`diff HEAD | shasum`. They see X's HEAD, tracked contents and path list — not ignored paths, an
untracked file rewritten, or anything outside X. A change other than an untracked path its report
names as a gate's output is a write: its verdicts do not count, you revert nothing, and the write
goes to the owner (§ Inside a batch). Record under `Deviations` the substitution, the model passed,
the effort read and the before and after reads. A workflow run cannot substitute — its script passes
no `model` and writes its own gate prompt — so a cross-repo run takes `subagents`.

## Handoffs

Give every constrained seat the reason for each constraint: a bare constraint is followed
silently, and only its *why* can be refuted, often by that seat alone.

Passing work to the user mid-slice, restate the invariants it depends on — the state that must not
move, the step that must precede a save, how many things may be in flight — even if a prior round
covered them; the handoff is read alone. Verify the returned state against those invariants: the
user reports the instruction they followed, not the invariant.

## Review

Wherever the profile runs them: **Spec axis, Standards axis and bug hunter, dispatched together →
critic → adjudication → fix commits → merge**. Under
`subagents` the bug hunter, where on, goes out with the axes whatever its value, since the serial first pass
was the largest phase in half the measured runs; the critic runs last because it reads every
review. Each dispatch is the definition the profile's `effort` line names. Hand reviewers the
measurements a spec summarises, not just the spec. Re-check a refuted finding about safety or data
loss. A finding proves the defect, not the remedy. After material fixes, re-run the affected checks
and take a targeted review; reopen the full one only where scope or assumptions changed. Fix
rounds, the wording-only round and the 60-call ceiling are § Run profile's caps.

**Bug hunter.** `correctness` is the Correctness charter, a Reviewer dispatch over the same diff:
*for each defect, what can go wrong, why the path is vulnerable, the likely impact, one clause of
remedy; material findings only; end with `FINDINGS: n`*, recorded
`LENS correctness: FINDINGS: <n>`. One clause of remedy, because a finding proves the defect, not
the remedy; material only, because you adjudicate each; `FINDINGS: n`, so the record reads a
count, not an impression. `codex`, by pin only, is the Codex lens below, and **any NOT RUN fires
the Correctness charter** as its fallback: above the light plan the loop is never without a bug
hunter and never runs two.

**Codex lens**, dispatched beside the axes once the implementer's diff is committed:

```
node "<installPath>/scripts/codex-companion.mjs" adversarial-review --json --base <fixed point> -- "$(cat <focus file>)" < /dev/null
```

`<installPath>` is read at run time, since a version bump moves it: the `user`-scope element, or the
sole one, of the `plugins["codex@openai-codex"]` list in `~/.claude/plugins/installed_plugins.json`.
Sandbox off: sandboxed, the companion failed before reaching Codex, on EPERM creating its state
directory under `$CLAUDE_PLUGIN_DATA` (2026-09-23); network egress, never reached, is unmeasured.
Focus: the ticket's acceptance criteria verbatim plus the execution spec's hard limits, then this
line verbatim, which closed the one planted defect every Codex variant missed
(cpalaka/agent-skills#90):
`Also check: does each guard have a test for its rejecting path as well as its accepting path?`
Stage the focus in a file inside the repository and remove it after. The script takes focus only as
positional text, with no focus-file flag, and acceptance criteria carry backticks and quotes that an
inline argument would execute or end on; content read through `$(cat …)` is not re-parsed, and `--`
ends the options, so a focus beginning with a flag name is still read as text. Inside the
repository, because sandboxed and unsandboxed shells resolve different temporary directories.
`--base` reviews only commits while Codex reads the live tree, so commit the implementer's diff
first, and **fix commits wait for the lens**. It has no timeout of its own: take the host's longest
foreground timeout or its background mode, capturing stdout, never the plugin's
`--background`/`result` route (its job record nests the payload differently); a timeout under a
shorter budget is yours to re-run.

Record `LENS codex: <verdict> — <n> findings — <bytes> bytes` under `Review` (`.result.verdict`, the
count of `.result.findings`, output bytes). A null `.result`, a `.parseError`, zero bytes, a
non-zero exit, or a failure before output (binary absent, not authenticated, registry unreadable —
no such key or element — quota, timeout at the longest budget) is `LENS codex: NOT RUN — <why>`. Its
recommendations are hypotheses; adjudicate every finding against source.

**Critic seat**, last — after every review and lens, before the merge — wherever the `critic` dial
is on, in every shape: a fresh Reviewer dispatch given the diff since the fixed point, the ticket,
the execution spec and every review's output, charged: *completeness critic — what the reviewers
and the lens missed and where their method erred: absence claims refuted by evidence outside a
finder's scope, category errors, a survivor one arm shares and was not charged with; counter-critic
— which findings source refutes, and which remedies add generality the spec never asked for.*
Recorded `CRITIC: <n> findings`. A Builder seat after the lenses reads the real diff and every
review, and spends no Planner meter.

## Workflow shape

This section is the contract a `workflow` run takes.

Before the script, you draft the execution spec, check out the run's branch in the checkout (the
script commits on whatever branch is checked out and never switches), post the profile, take the
stop where it fires and run slot 1 where `advisor` is on; it runs the implementer, the certifying
gate, the native axes with the Correctness charter beside them where `bug hunter` is `correctness`,
and at most one fix round. The stages the profile's `effort` value names (the implementer, the Spec
and Standards axes, the Correctness charter) are each dispatched by that definition name, or the one
the ratchet raises it to, their stage `effort` set from the same name so the two carriers cannot
disagree; the gate-runner is dispatched by the `gate_runner` knob at `medium`. A red certifying gate
raises the Correctness call to `code-reviewer-xhigh` inside the script, which logs the raise; you
read the raise from that call's `agent-<id>.meta.json`, never from the log line, which lands only in
the Workflow's `.output` wrapper, and record it under `Deviations`. Raising the critic stays yours.
On its return you run the Codex lens where `bug hunter` is `codex`, dispatch the critic, adjudicate,
merge and write the record. A Codex lens reading NOT RUN fires the Correctness charter after return
too, yours (§ Review's fallback), at the Correctness charter's effort from § Run profile, derived
as though `bug hunter` were `correctness`. It never merges, writes the tracker or asks a question:
none reaches a human turn from inside it. Its fix round precedes the lens, so it leaves its work
committed (`--base` reads only commits); fix commits after the lens are yours, and a lens after
return departs from § Review's concurrent ordering, which the record notes under `Deviations`. A
second material round and the wording round are yours after return, under § Run profile's caps.

**Launch `workflow.js` beside this file by path**,
`Workflow({scriptPath: "<this Skill's directory>/workflow.js", args})`, from a session started
with this Skill's directory added (`--add-dir`): the tool refuses a `scriptPath` outside the
working directory and added directories, even after a Read of the file. Without that, run
`subagents`; a mid-session `/add-dir` is unmeasured. Never inline it: an inline `script` is a
transcription — measured, the transcribing session dropped comments — not the file.
`args`: `{ticket, checkout, fixedPoint, specPath, gateTier, profile, gateRunner?}`, the script's
field names, any other field throwing — `ticket` the issue reference; `gateTier` the profile's
`gate tier` spelled out for the gate-runner; `profile` the posted block transcribed to an object,
keyed by the dial tokens verbatim, spaces included, except that the `effort <seat>` dials nest as
one `effort` object mapping each seat token to its definition name: `{standards: "off",
"bug hunter": "correctness", effort: {implementer: "implementer", spec: "code-reviewer",
"bug hunter": "code-reviewer-xhigh"}}`; `gateRunner` the `gate_runner` knob's seat when it is not
`gate-runner`; `specPath` outside the checkout or ignored there, since the implementer commits
everything and the spec stays uncommitted (§ Seats). It returns
`{gates, findings, implementerReport, fixRound, dropped, gateReports}`. **Resume**: stop the run,
relaunch with `resumeFromRunId` and the original `args` verbatim — a resume drops them, and
identical ones keep the journal's cache keys. **It needs a gate-runner seat the launching session
can dispatch**, and a project-local seat resolves only in a session rooted in that project; a
project on `gate_runner: coordinator` has none, so runs `subagents`.

**At return**, read the checkout's `git status --porcelain` yourself: non-empty, less any untracked
(`??`) path the gate-runner's report names as a gate's own output, means the script's work is not all committed, so the scripted run does not count and you finish the ticket under
`subagents` from the commits already made, committing nothing on its behalf. `fixRound.ran` with
`gatesAfter` empty means no gate saw the fix work (a dropped fix seat may have committed): dispatch
the gate-runner on it before the lens. Reconcile `dropped` against `journal.jsonl`, which gives each
call's label, `agentId` and return value (the `started` records carry the label): the definition
each stage was dispatched by is `agentType` in that agent's `agent-<id>.meta.json` beside it
(`workflow-subagent` there is what an omitted `agentType` records), its model and effort are on its
`agent-<id>.jsonl` assistant records, and an implementer's calls are the `tool_use` blocks in that
transcript other than `StructuredOutput`, the schema return a `subagents` implementer never makes
(the `scope` cap), one past 60 under `Deviations`. Check the diff's paths against the plan's
changed-path set: a path outside it ratchets (§ Run profile). Inside the script a dropped gate
reads green and a dropped review clean, so at return you make up what they would have run: for a
`gate` label in `dropped` you dispatch the gate-runner before the lens, and before the critic you
dispatch each review the profile now calls for that the script did not return, at its definition
(both read off the profile as § Run profile's ratchet leaves it at return). A dropped
`review:correctness` is never recorded as `FINDINGS: 0`, since above the light plan the loop is
never without a bug hunter (§ Review).

**Adoption**: `subagents` stays every project's default until three clean scripted runs —
certifying `OVERALL: PASS` (a project's `(tier)` or `(judgment)` NOT RUN line never moves it) with
each of the five gates on a `GATE` line or a line below `OVERALL`, and every `OWNED ELSEWHERE:` line
closed by its seat's verdict or its not-due clause, quoted in the record,
calls sent reconciled against results returned in `journal.jsonl`, each agent's model read from
its `agent-<id>.jsonl` — counted from the project's run records.

## Close

1. Sweep `git status` in every checkout the run touched, after any fan-out.
2. **Load `git-flow-squash`**, or the `git-flow-*` Skill the project's Profile `fork:` names,
   before the merge. Nothing fires it from context (description-matched triggering: 1 invocation
   in 105 sessions, measured on another Skill), and a squash without its clauses fails silently
   toward a lost tree: a peer's unpushed commit riding the push, a branch deleted against a moved
   `main`, an approval spent on a tree that no longer exists.
3. **One approval covers posting the run record, the merge and the close**, given by the owner, or
   by the delegate inside a batch. Offer the diff, the record and the close in one message, naming
   the acceptance reading you took and why; act on the single yes. A ticket whose acceptance needs
   the owner's attended run stays open: the push is not the acceptance.
4. **Emit the kickoff** once step 3's actions land, a ticket left open for the owner included, as
   its own message, unfenced: `/implement-run <n>` for the lowest ticket on the tracker chunk's
   frontier. An empty frontier takes the contract's frontier-empty instruction; where it names
   none, say the frontier is empty — and where the tracker's query cannot tell an empty frontier
   from an unminted label, run its label check and report which. Nothing else follows — no other
   query, no grill, no wrap: the run record is the tracker write, the kickoff the handoff.

**The run record is the tracker's closing record**: one comment on the ticket (in the file, for a
file ticket) carrying both structures — the headings `Slots`, `Gates`, `Review`, `Deviations`, and
each acceptance criterion by number with its evidence and the reviewed commit SHA. `Slots` repeats
the profile block as dispatched, followed by `approved: owner` or
`approved: owner's delegate — <what the delegate read>` where the stop fired; inside a batch it
also names the batch grant. The body is the spec, and a run never rewrites its own ticket's body —
`gh issue edit --body` and its equivalents replace it wholesale, so ticking one checkbox can take
the spec with it. Checkboxes are the owner's; every observation, verdict and piece of evidence goes
in a comment.

**A criterion your run missed is the owner's to re-cost (§ Inside a batch); the ask must not make
your reading the default.** *The criterion was wrong* is an overrun's predictable output, and
sometimes true; with the deliverable already on disk, *land it and decide later* installs your
preference by silence. Produce the alternative as an artifact the owner can diff, not a number you
describe, and leave the criterion unticked either way.
