# Multi-Agent Policy — Claude Code mechanics reference

The API-level detail behind the rules in `SKILL.md`. Read this when you are **writing or editing a
workflow script**, **dispatching an external vendor lens**, or **coordinating interactive child
sessions in a terminal multiplexer**; the rules themselves live in `SKILL.md` and are what govern.
Nothing here relaxes anything there — this file only says *how* to express it.

Codex equivalents are noted where they exist; where they don't, the rule still holds and the
mechanism is the host's own dispatch surface.

## Scarce-tier posture ladder — the arg surface

`SKILL.md` defines the ladder (`none | critic | insight | full`) and what each rung buys. The
mechanics:

- **`scarce: "none"|"critic"|"insight"|"full"`** — the opt-in arg in saved adversarial-review
  workflows. Reference implementation: the consuming project's own
  `.claude/workflows/adversarial-review.js`.
- **`fable: true` stays accepted as an alias for `critic`.** Live launch snippets and plan docs
  still use it, so removing it would break them silently.
- **An unrecognized posture falls back to `none` with a LOGGED warning**, never silently.
- **`stages: {<stage>: {model, effort}}` outranks the ladder.** This is how a deliberate one-off is
  expressed — including a scarce verify — and it is why the ladder itself needs no special cases.
  A script that allows a scarce verify **must warn that its projection excludes it** (`SKILL.md`
  § Scarce-tier usage says why).
- **Model IDs are concrete and probe-resolved**, never short aliases — see the alias rule in
  `SKILL.md` § Tier roles. `tournament/reference/lint.mjs` ERRORs on a bare alias in any script.

## Sizing a fan-out — the `budget` global

`SKILL.md`'s budget-tier exception says "a SMALL agent count." When the user set a token target
(`+500k`-style), that has a mechanism rather than an eyeball:

- `budget.total` — the target, or `null` if none was set.
- `budget.spent()` — output tokens spent this turn across the main loop **and all workflows** (one
  shared pool, not per-workflow).
- `budget.remaining()` — `max(0, total - spent())`, or `Infinity` when no target is set.

The target is a **hard ceiling**: `agent()` throws once spent reaches it. Two shapes:

```js
const FLEET = budget.total ? Math.floor(budget.total / 100_000) : 5   // static scaling
while (budget.total && budget.remaining() > 50_000) { … }             // loop until nearly dry
```

**Guard on `budget.total` in any such loop.** With no target set `remaining()` is `Infinity`, and the
loop runs to the 1000-agent backstop. When no target is set the exception is still a judgment call
and still gets announced.

## Other spawn-time knobs

- **`agentType`** — `agent(prompt, {agentType: 'general-purpose' | 'code-reviewer' | …})` runs a
  stage as a *definition-backed* agent instead of the default workflow subagent, resolved from the
  same registry as the Agent tool. Composes with `schema`. The workflow-side equivalent of the
  `opus-implementer` dispatch, and subject to `SKILL.md`'s stale-registry rule for edited defs.
- **Per-agent `effort`** — overrides effort for a single call, independent of `model`. This is what
  makes "modest = high, full = xhigh" enforceable per *stage* rather than per run. Use `low` only
  for mechanical stages, never for a verify or critic slot.
- **`workflow(nameOrRef, args)`** — runs another workflow inline as a sub-step, sharing this run's
  concurrency cap, agent counter, abort signal, and token budget. Its agents count toward **your**
  projection and **your** size ceiling, so a nested call is a spending decision, not a refactor.
  Nesting is one level only.

## Vendor lenses: call the CLIs directly, not the plugin bridges

`SKILL.md` § Verification structure requires external vendor lenses on any reasonably-sized diff.
This is how to actually get findings out of them.

> **Version caveat, unresolved.** Everything in this section was measured against **grok-build
> 0.2.0 and the Codex companion plugin as they stood in July 2026**. Verbs, state-dir paths, and
> timeout behaviour are plugin-version-specific and have already shifted once *within* that month
> (see the `show` correction below). **Re-verify a verb before depending on it**, and treat a
> disagreement between this section and the live CLI as this section being stale.

**The plugin bridges are fire-and-forget and return nothing.** `grok-build:grok-delegate` and
`codex:codex-rescue` forward the prompt to a background runtime and are *forbidden from polling*, so
the Claude-side wrapper returns a schema-valid **placeholder** ("launched in background — no findings
yet"). Slot one as a Workflow finder lens and the run's sent-vs-returned reconciliation reads
**CLEAN while vendor coverage is zero** — the exact blind spot `SKILL.md`'s reconciliation rules
cannot cover, because a placeholder *is* a return. Both wrappers are launch-only and refuse
follow-up work: resuming one via SendMessage with "now poll the job" gets a scope refusal.

**Prefer the direct CLIs.** Both are installed, return real findings synchronously, and were
validated 2026-07-27/28 (~6–8 min, 10–12 KB on a 410-line spec):

```sh
grok  --cwd <dir> --always-approve -p "$(cat PROMPT.txt)"
codex exec --skip-git-repo-check -s read-only -C <dir> "$(cat PROMPT.txt)" < /dev/null
```

- **`codex exec` fails TWICE, both times silently, before it will run.** (1) It **hangs on stdin**
  even with the prompt passed as an argument — stderr sits on `Reading additional input from
  stdin...` forever; fix with `< /dev/null`. (2) It then **exits 0 producing ZERO bytes**, because
  it refuses to run outside a git repo — and that message is invisible until stdin is closed; fix
  with `--skip-git-repo-check`.
- **The exit code is worthless here — assert `wc -c` on the output file.** Both failures presented
  as "completed, exit 0". Trusting absence-of-error reads as "the vendor found nothing" and drops
  coverage to one lens, which is the failure the direct-CLI rule exists to prevent. Arm a bounded
  watcher that reports the byte count either way, not only on success.
- **The stdin hang bites only in BACKGROUND Bash, so a foreground probe does not validate a
  background invocation.** The harness appends `< /dev/null` to foreground evals automatically: a
  foreground probe ran clean while the byte-identical background command hung 23 minutes at ~0 CPU
  with no rollout file (measured 2026-07-30). Write `< /dev/null` explicitly in every background vendor call.
- `codex exec` writes its whole working transcript to **stderr** and only the final report to
  stdout, so 0-byte stdout mid-run is normal. `-s read-only` structurally prevents stray files.
- **Hand vendors a read-only SNAPSHOT, not the live repo**: `git archive <sha> | tar -x -C
  $TMPDIR/…` plus a `git diff` patch file. This pins the review SHA by construction (satisfying the
  hold-fix-commits rule in `SKILL.md`) and makes it impossible for a vendor to mutate the diff under
  review. It is also *why* `--skip-git-repo-check` is needed at all — the snapshot is deliberately
  not a git repo.
- **Run vendor calls sandbox-off** (xAI hosts are not network-allowlisted, and the bridges write job
  logs under `~/.claude/plugins/`, which is on the sandbox write-deny list → `EPERM`). **Liveness is
  a growing rollout file, never a process check** — `ps`/`pgrep`/`kill -0` report a live process dead
  under the sandbox (`sandbox-and-permissions` skill).
- Vendor findings **skip the workflow's skeptic panels entirely** — adjudicate each against source in
  the main loop, spawning scoped xhigh verifiers for deep HIGHs. Both vendors have carried real
  errors (measured 2026-07-24: one misread a task's pins, the other overstated a missing-bench HIGH). The
  payoff is still there — measured 2026-07-27, the Codex lens caught a 2.61× calibration error the Grok lens had
  explicitly rubber-stamped as verified.

**If you must use a bridge anyway**, these are its failure modes:

- **A Codex job's JSON can stay `status=running` forever after the work finished** — the process
  completed and wrote its final report into the session rollout
  (`~/.codex/sessions/<date>/rollout-*-<sessionId>.jsonl`), then the bridge died before flipping the
  job JSON. A status-file poll monitor **never fires** in this mode. Check the job's `pid`
  (unsandboxed) and tail the rollout; the deliverable is usually all there. Intermittent, not
  universal.
- **A Grok bridge foreground timeout orphans and then KILLS the run with no output.** The wrapper
  waits 600s, the bridge process dies, the orphaned CLI works a few more minutes and then dies
  mid-inference; the job JSON is stale (dead pids) and the promised "parent will be notified" never
  comes. The wrapper's claim that "the underlying job continues" is false past a few minutes.
  *Distinct and healthy:* when the **harness** backgrounds the run and reports a task id, that run
  can complete fine — `TaskOutput(block=true)` returns the full review.
- Harvest verbs, all unsandboxed: `grok-bridge.mjs runs` (status / phase / elapsed);
  `grok-bridge.mjs show <run-id>`; `codex-companion.mjs status|result <job-id>`. **`show` is the
  verb whose behaviour moved**: on 2026-07-18 it did not resolve a `run-*` delegate id, on
  2026-07-19 (grok-build 0.2.0) it did and returned the full report. Try `show`, fall back to the
  state-dir job log `…/state/<ws>/jobs/<run-id>.log`.
- **Do not let a data-dir name tell you which vendor ran.** grok-build ≥0.2.x has its own dir, but a
  codex run dispatched in the same session can be recorded there too (forked plumbing, job titled
  "Codex Task"). The log header names the actual runtime; the listing's resume cosmetics do not.
- The `grok-build:grok-delegate` agent type only appears in sessions started **after** the plugin was
  installed — same session-start registry cache as edited agent defs (`SKILL.md` § Stale-registry
  and cache gotchas).

## Session-level: ultracode

When a session reminder says ultracode is on, the orchestration opt-in is *standing* — workflows
become the default for substantive tasks. It changes **the opt-in, not the tier rules**: workhorse
default, scarce still opt-in per launch, budget tier still barred from correctness-bearing work, and
both agent-count ceilings still bind. Read the reminder rather than assuming; the pins hold either
way.

## `args` does not arrive the way you passed it

Three measured failures, all silent, all in the same surface. Treat `args` as untrusted on the way
in and re-passed by hand on the way back.

- **A resume DROPS `args` entirely.** `Workflow({scriptPath, resumeFromRunId})` does **not** carry
  the original invocation's `args` — the script gets `args === undefined`, and a named workflow
  errors ("No research question provided"). **Always re-pass the original `args` verbatim on
  resume.** An identical string is also what keeps the journal cache keys matching, so getting this
  right is what makes the cache-hit claim below true at all. (measured 2026-06-06)
- **An object `args` can arrive STRINGIFIED**, so `args.X` is `undefined`. On a separate
  deep-research run the same day: `args: {today, notesDir, reportPath}` reached the script as a JSON string;
  agents were told to write to literal `undefined/...` paths, and the run went for hours before the
  damage was visible. Hardcode critical constants (dates, paths, output locations) as
  `const` literals in the script body; if dynamic data must flow in, template it into the script
  text and launch with `scriptPath`.
- **The same stringification silently disables a mode toggle.** `args: {smoke: true}` arriving as a
  string makes `!!(args && args.smoke)` evaluate **false**, so the script runs at FULL scale — all
  five research briefs, web on, high effort — instead of the cheap smoke path. This one costs real
  money. Two defences, use both:

  ```js
  const SMOKE = (typeof args === 'string')
    ? (args === 'smoke' || args.includes('smoke'))
    : !!(args && args.smoke)
  ```

  and launch the smoke run with a plain string — `Workflow({scriptPath, args: "smoke"})`. Then
  **verify from `journal.jsonl` that the toggle engaged** (exactly one research-schema result)
  before scaling up. Measured 2026-06-19 on a research run: the journal showed 5 research agents,
  not 1.

## A usage-limit hit masquerades as a schema failure

If every subagent in a run completes instantly with **"completed without calling
StructuredOutput"** and the sources come back empty or unreliable, do not debug the schema. Open a
failed agent transcript and look for **"You've hit your session limit"** — a mid-run usage-limit
hit presents as a schema/fetch failure at the orchestration layer. The same limit hit at a *verify*
stage presents differently again — rate-limited verifiers return 0-0 abstains, which read as kills.

## Reading a completed run's return value

A finished Workflow/Task `.output` file — path given in the `<task-notification>` as
`output-file`, under `/private/tmp/.../tasks/<taskid>.output` — is **not** the bare return object.
It is a wrapper:

```json
{ "summary": "...", "agentCount": 111, "logs": [...], "result": { ...the workflow's return... } }
```

Parse the file, then read `wrapper.result` (and `if (typeof result === 'string') JSON.parse(result)`
to be safe). The `<task-notification>`'s inline `<result>` is the same object but **truncated**
(~the first 50–380k chars) — for a big run always read the full `.output` file rather than trusting
the inline copy.

Extraction is a normal dev-tool Node script; `fs` is allowed. The runtime ban on `node:fs` /
`Date.now()` applies to the Workflow **script body** only, not to a helper you run separately.

## Resume and the transcript files

`Workflow({scriptPath, resumeFromRunId})` replays the longest unchanged prefix of `agent()` calls
from cache and re-runs from the first edited call onward. Same script + **the same args, which you
must re-pass yourself** (see above — a resume drops them) = 100% cache hit — which is also the
trap: a resumed run can report results no agent produced this session.

A stopped run is reusable: `TaskStop` it, then relaunch with `resumeFromRunId` and unchanged agent
prompts for an instant cache hit (a top-of-file `const` edit does not invalidate downstream
agent-call caches).

Two different files in the run's transcript dir, neither substituting for the other:

| File | Holds | Read it for |
|---|---|---|
| `journal.jsonl` | each call's **return value** | drop reconciliation; diagnosing a thin result |
| `agent-<id>.jsonl` | each agent's **spawn config** + raw turn stream | verifying `"model"` actually applied; fallback when no journal exists |

## Coordinating interactive child sessions in a terminal multiplexer (herdr)

A third orchestration shape beside workflows and the Agent tool: a **coordinator** session drives
*interactive* child sessions in sibling panes, one ticket per child, each child writing its own
closing note. Reach for it when the work is a chain of tickets committing to real repositories: each
child is a full interactive session, so it can stop at a grant boundary and ask, its dialogs reach a
human, and the user can resume that exact session afterwards. Measured on **herdr**, a terminal
multiplexer that recognises coding agents in panes and exposes `idle` / `working` / `blocked` /
`done` lifecycle states over a CLI; the procedure transfers to any multiplexer with those two
properties. **herdr's
own `--skill` output is the syntax authority and tracks the installed binary — nothing below
restates a flag.** (measured 2026-09-01/2026-09-02 on a project: three runs, 20 child sessions,
18 tickets.)

Everything in `SKILL.md` still governs — tier pins, the heartbeat rule, `git status` after every
fan-out with explicit-path staging, and "a command you write into a delegate spec carries your
unverified premises". `PROCEDURES.md` § Hands-off ticket design governs the execution grant the
children read. This is only the coordination layer above them.

**Partition, and give every child its cwd.**

- **One writer per repository `main`.** Two children committing to the same repo race the index lock
  and the pre-commit hook, so tickets writing the same repo run sequentially even where their
  blocking edges would allow parallelism. Partition parallel children by repo, never by ticket order.
- **Set each child's cwd explicitly at the split; never let it inherit the coordinator's.** The
  coordinator should sit *outside* any tree a ticket renames or moves — which is exactly the case
  where an inherited cwd puts the child in the wrong place, or in a directory that stops existing
  mid-run.
- One child pane at a time, closed when its ticket closes. A fresh split per ticket kept the layout
  legible across 20 children and returned the coordinator's pane to full width every time.

**Start and prompt.**

- **Confirm the pins in the child's status line before the first prompt; do not assume them from the
  start call.** Model, effort and permission mode all take when passed as native agent arguments
  after the separator, but a start that reports the agent not ready leaves a session that still
  answers to its name while carrying none of them.
- **Keep the prompt in a file and paste from there whenever it carries quotes.** A coordinator's
  prompt is several sentences of standing clauses plus the ticket's hand-offs, and nested quoting is
  the one thing that reliably mangles between the coordinator's shell and the child's input box. The
  file is also the record of what the child actually executed.
- **The prompt carries the standing clauses, not just the ticket path.** Four earned their place,
  each measured to remove exactly the class of interruption it named and no more: stage by explicit
  path in every repo and in any subagent; do not spell a guarded subcommand in echo strings,
  comments, or commit messages; write file contents with the editor tools, never shell heredocs or
  redirects; revert a marker in a scratch clone by deleting and re-cloning rather than with a git
  verb.
- **Prose trips permission rules.** An unanchored `Ask` pattern matches the whole command text, so a
  child echoing a warning about a destructive verb — or a heredoc body quoting the grant — blocks on
  a rule no git command triggered. This binds the coordinator too: its own prompt- and
  ledger-writing calls block the same way, which is why coordinator prose goes through the editor
  tools. Measured: 16 of the first run's 26 blocked returns were prose false positives; the prompt
  clauses removed the classes they named, and re-anchoring the rules to the head of the command
  removed the rest — **0 blocked returns across the following 6 children and 15 ticks**, over
  children that moved and removed 73 files in one step and rewrote a registry. The wording lever is
  bounded; only the rule set closes the class.

**Ticks, and `blocked`.**

- **Ten-minute bounded waits.** Each wait returns on a settled state — ready for input, finished, or
  blocked — or on its own timeout, and that timeout is the heartbeat tick (payload per `SKILL.md`
  § Heartbeat). Every block across three runs surfaced *inside* a tick rather than at its boundary,
  so the cadence cost no responsiveness. Keep the tick cheap: running a full verifier inside one
  overran the coordinator's own output limit and had to be dropped from later ticks.
- **`blocked` is the only interruption, and it can be stale.** Read the dialog before escalating —
  two reads found a working pane, the dialog having cleared between the wait returning and the read.
- **Never answer a permission dialog on the user's behalf.** Post its text, focus the child, wait.
  Answer only a *question* whose answer is stated literally in the ticket or the grant, and record
  the question with the line you answered it from. Confirm the notification surface actually reaches
  the user before relying on it; where notifications were disabled, focusing the child was the only
  signal a human ever saw.
- **A child stopping at a grant boundary with a question is the shape to want, not a failure.**

**The handoff is the ticket file.**

- **Never read a child's transcript into the coordinator's context.** The closing note plus the
  coordinator's own gate output is the whole handoff; cap every pane read (80 lines held across
  three runs). A note whose calibration section carries verbatim output lets the coordinator
  reproduce a verdict line-for-line without the transcript.
- **Re-run the ticket's gate yourself, from the instrument, never from the note** — then verify what
  the child actually committed. A child's commit subject can mimic the coordinator's own ledger
  form; twice it read as though the ledger had been touched when the diff said otherwise.
- **Hand children facts with pointers — a file, a line range, a command to re-derive — never
  decisions and never counts.** Every hand-off that was a fact came back as a decision with its
  reasoning in the note. **Every hand-off that carried a count was wrong:** six stated figures of 5,
  9, 16, 1, 1 and 27 re-derived as 3, 7, 21, 3, 3 and 28, and the one stated figure that was right
  was confirmed only by a re-count that found twice as many occurrences of the thing counted.
- **Derive a gate's expected figure from the instrument's own gating, not from the spec's prose.**
  "Exactly one failure", "green, every assertion" and "zero each" were each contradicted by an
  assertion the verifier runs unconditionally, a list the change itself invalidates, and a registry
  the spec never named. Read the verifier for unguarded assertions, and list what the target state
  cannot clear, *before* writing a verdict into a gate.
- **A red the child predicts in its note before the destructive step is the right shape** — the
  coordinator recognised it on sight instead of investigating it.
- **Verify "that section printed nothing" against the unfiltered instrument.** A coordinator's own
  tidy-up filter dropped the very assertion lines it was checking for, and the gate read as a gap.
- **A criterion no instrument can verify from where the child stands is reported *not run*, never
  passed** — and criteria that stay human (a read, a taste judgment) are batched at the run's end
  rather than blocking each child. That is what keeps a hands-off chain hands-off without converting
  a human gate into a machine one.

**Close.**

- **The exit signal is the agent's disappearance from the live list, not a clean-looking pane.** A
  finished child's input box often shows the host's **dimmed suggested prompt** — grey text that
  reads exactly like a typed command awaiting Enter. Sending Enter against it does nothing; sending
  the exit command types over it, and the not-running error within a second is the confirmation.
  Get that before closing the pane.
- **Record each child's session name in the run's notes** so the user can resume that exact session
  afterwards; the name itself is released the moment its agent exits.

**Tickets that move or rename the ground under a session.**

- **A session writes its project-registry entry under its *start* cwd when it exits, and re-creates
  its own project directory on its next transcript write.** A mover therefore cannot clean up after
  itself: dropping the stale key and the stale directory is a *later* session's step, and the
  verifier stays red until then. Schedule it that way in the ticket instead of reading the red as a
  defect.
- **Poll for the precondition rather than asking a human to confirm it.** Before starting a child
  whose ticket destroys a path, a 5-second poll over the live agent list matching cwd prefixes,
  posted once and left to fire, cost three minutes and no attention.
- **A ticket whose last step destroys the session's cwd must name which criteria are read after it
  and where those readings land** — in the child's final message, since the note can no longer be
  written. Without that, a complete note reads as an abandoned one.
- **A shared registry file that every live session writes cannot be asserted byte-wise.** 24 seconds
  after one atomic edit the file already differed, another session having bumped an unrelated
  counter. Assert over the structure you care about — the map, the key set — never the document's
  bytes or its digest.

**Run end.**

- **Sweep for strays with a newer-than-marker walk over the parent directories**, not only over the
  repos: touch a marker at the run's start, list what is newer at its close. Cheap, and it is the
  only thing that sees a file a child wrote outside every tree anyone was watching.
- **A close-out artifact can red the very check it reports on.** A closing note that quotes the
  forbidden string a repo-wide check hunts turns that check red on the note itself. The fix is the
  check's own documented exclusion path, regenerated and committed — which makes regeneration a
  normal closing step for any document that must name the thing.
- **Record the session usage window at each child's start and exit.** Three consecutive workhorse
  children took a five-hour window from 33% to 95%; the next child hit the limit within a minute of
  its prompt and stalled the coordinator with it for about 80 minutes. Above roughly 80%, say so and
  expect the next ticket to stall, rather than discovering it mid-turn.
