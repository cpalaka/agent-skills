# Multi-agent policy: mechanics reference

The API-level detail behind the rules in `SKILL.md`, which governs; nothing here relaxes anything
there. Read this when **writing or editing a workflow script**, **dispatching an external vendor
lens**, **choosing the shape of a delegated run**, **coordinating interactive child sessions in a
terminal multiplexer**, **re-launching after a mid-session edit to a script, agent definition or
skill metadata**, **sharing a live system with a peer session**, **arming a heartbeat on a long
delegate**, or **launching a research fan-out**. The Workflow tool's own API (`agent()` options,
`pipeline`/`parallel`, `budget`, `workflow()`, resume) is documented by the `workflow-authoring`
skill; this file carries only the policy overlay and the gotchas that reference lacks.

Codex equivalents are noted where they exist. Where they don't, the rule still holds and the
mechanism is the host's own dispatch surface.

## Scarce-tier posture ladder: the arg surface

`SKILL.md` § Scarce tier defines the ladder (`none | critic | insight | full`). In saved
adversarial-review workflows:

- **`scarce: "none"|"critic"|"insight"|"full"`** is the opt-in arg. Reference implementation: the
  consuming project's own `.claude/workflows/adversarial-review.js`.
- **`fable: true` stays accepted as an alias for `critic`**, because live launch snippets and plan
  docs still use it.
- **An unrecognized posture falls back to `none` with a LOGGED warning**, never silently.
- **`stages: {<stage>: {model, effort}}` outranks the ladder.** It is how a deliberate one-off is
  expressed, including a scarce verify, and why the ladder needs no special cases. A script that
  allows a scarce verify **must warn that its projection excludes it**.
- **Model IDs are concrete and probe-resolved**, never short aliases (`SKILL.md` § Tier roles).
  `tournament/reference/lint.mjs` ERRORs on a bare alias in any script.

## Spawn-time knobs: the policy overlay

- **`budget`** is how the budget-tier exception's "small agent count" gets a mechanism when the
  user set a `+500k`-style token target. Guard every loop on `budget.total`: with no target set,
  `remaining()` is `Infinity` and the loop runs to the 1000-agent backstop. With no target the
  exception is still a judgment call and still gets announced.
- **`agentType`** is the workflow-side equivalent of the `opus-implementer` dispatch, resolved from
  the same registry as the Agent tool, so it is subject to the stale-registry rule below for edited
  definitions.
- **Per-agent `effort`** is what makes "modest = high, full = xhigh" enforceable per *stage*. `low`
  is for mechanical stages only, never a verify or critic slot.
- **`workflow()` nesting** shares this run's agent counter and token budget. The child's agents
  count toward **your** projection and **your** size ceiling, so a nested call is a spending
  decision, not a refactor.
- **Ultracode** (a session reminder says it is on) makes the orchestration opt-in *standing*. It
  changes the opt-in and none of the tier rules: workhorse default, scarce still opt-in per launch,
  budget tier still barred from correctness-bearing work, both agent-count ceilings still bind.

## Vendor lenses: call the CLIs directly, not the plugin bridges

`SKILL.md` § Verification structure requires external vendor lenses on any reasonably-sized diff.

> **Version caveat.** Everything here was measured against grok-build 0.2.0 and the Codex companion
> plugin as of July 2026, and verbs shifted once *within* that month. Re-verify a verb before
> depending on it, and treat a disagreement between this section and the live CLI as this section
> being stale. **Confirm each binary resolves before launching** (`command -v grok codex`): on
> 2026-09-02 the `grok` symlink was dangling, which reads as command-not-found only at launch.

**The plugin bridges return nothing.** `grok-build:grok-delegate` and `codex:codex-rescue` forward
the prompt to a background runtime, are forbidden from polling, and return a schema-valid
**placeholder**. Slot one as a finder lens and sent-vs-returned reads **clean at zero vendor
coverage**, because a placeholder is a return. Both refuse follow-up work via SendMessage.

**The direct CLIs return real findings synchronously** (validated 2026-07-27/28: ~6–8 min, 10–12 KB
on a 410-line spec):

```sh
grok  --cwd <dir> --always-approve -p "$(cat PROMPT.txt)"
codex exec --skip-git-repo-check -s read-only -C <dir> "$(cat PROMPT.txt)" < /dev/null
```

- **`codex exec` fails twice, silently, before it runs.** It hangs on stdin even with the prompt as
  an argument (stderr sits on `Reading additional input from stdin...`), so pass `< /dev/null`. It
  then exits 0 with zero bytes because it refuses to run outside a git repo, invisible until stdin
  is closed, so pass `--skip-git-repo-check`.
- **The exit code is worthless. Assert `wc -c` on the output file.** Both failures present as
  "completed, exit 0"; trusting absence-of-error drops coverage to one lens, the failure this rule
  exists to prevent. Arm a bounded watcher that reports the byte count either way.
- **The stdin hang bites in background Bash and in foreground compound commands alike.** A
  foreground probe ran clean while the byte-identical background command hung 23 minutes at ~0 CPU
  (measured 2026-07-30), which read as "the harness appends `< /dev/null` to foreground evals"; on
  2026-09-04 a foreground `;`-chained command hung 300 s at the same call, so that carve-out is not
  reliable. Write `< /dev/null` explicitly on every `codex exec`, foreground or background. The
  stderr line "Reading additional input from stdin…" prints on completed runs too, so it is not the
  tell; no hook or output line after it is.
- `codex exec` writes its working transcript to **stderr** and only the final report to stdout, so
  0-byte stdout mid-run is normal. `-s read-only` structurally prevents stray files.
- **Hand vendors a read-only snapshot**: `git archive <sha> | tar -x -C $TMPDIR/…` plus a
  `git diff` patch. This pins the review SHA by construction and makes the diff immutable under
  review; it is also why `--skip-git-repo-check` is needed at all. Hold fix commits until every lens
  returns, or a lens re-reports fixed defects as live.
- **Run vendor calls sandbox-off** (xAI hosts are not network-allowlisted; the bridges write under
  `~/.claude/plugins/`, on the sandbox write-deny list). **Liveness is a growing rollout file, never a
  process check**: `ps`/`pgrep`/`kill -0` report a live process dead under the sandbox
  (`sandbox-and-permissions` skill).
- Vendor findings **skip the workflow's skeptic panels**. Adjudicate each against source in the
  main loop, spawning scoped xhigh verifiers for deep HIGHs. Both vendors have carried real errors
  (measured 2026-07-24), and one lens has caught a real defect the other rubber-stamped as verified
  (measured 2026-07-27).

**If a bridge ran anyway**, harvest unsandboxed: `grok-bridge.mjs runs` / `show <run-id>` (falling
back to the state-dir job log `…/state/<ws>/jobs/<run-id>.log`), `codex-companion.mjs status|result
<job-id>`. A Codex job's JSON can stay `status=running` forever after the work finished. The report
is in the session rollout (`~/.codex/sessions/<date>/rollout-*-<sessionId>.jsonl`), so tail that
rather than polling the status file. A Grok bridge foreground timeout (600s) orphans and then kills
the run with no output; the wrapper's "the underlying job continues" is false past a few minutes.
A run the *harness* backgrounded with a task id is healthy, and `TaskOutput(block=true)` returns
it. A data-dir name does not tell you which vendor ran: the log header names the actual runtime.
The `grok-build:grok-delegate` agent type appears only in sessions started after the plugin was
installed (§ Stale-registry and cache gotchas).

## `args` does not arrive the way you passed it

Three measured failures, all silent. Treat `args` as untrusted on the way in and re-passed by hand
on the way back.

- **A resume drops `args`.** `Workflow({scriptPath, resumeFromRunId})` does not carry the original
  invocation's `args`: the script gets `undefined`, and a named workflow errors. **Re-pass the
  original `args` verbatim on resume.** The identical string is also what keeps the journal cache
  keys matching (measured 2026-06-06).
- **An object `args` can arrive stringified**, so `args.X` is `undefined`. Agents were told to
  write to literal `undefined/...` paths and the run went for hours before the damage showed.
  Hardcode critical constants (dates, paths, output locations) as `const` literals in the script
  body; if dynamic data must flow in, template it into the script text and launch with `scriptPath`.
- **The same stringification silently disables a mode toggle.** `args: {smoke: true}` arriving as a
  string makes `!!(args && args.smoke)` false, so the script runs at full scale. Two defences, both:

  ```js
  const SMOKE = (typeof args === 'string')
    ? (args === 'smoke' || args.includes('smoke'))
    : !!(args && args.smoke)
  ```

  and launch the smoke run with a plain string, `Workflow({scriptPath, args: "smoke"})`. Then
  **verify from `journal.jsonl` that the toggle engaged** before scaling up (measured 2026-06-19:
  the journal showed 5 research agents, not 1).

## A usage-limit hit masquerades as a schema failure

If every subagent completes instantly with **"completed without calling StructuredOutput"** and the
sources come back empty, leave the schema alone: open a failed agent transcript and look for
**"You've hit your session limit"**. The same hit at a *verify* stage presents as 0-0 abstains, which
read as kills.

## WebSearch is a session-shared pool

The pool (default 200) is drained by every subagent and nothing warns at dispatch; the error fires
when the main loop needs a search and the cost is sunk (measured 2026-08-26). Reserve main-loop
searches for post-hoc verification, or raise `CLAUDE_CODE_MAX_WEB_SEARCHES_PER_SESSION` before a
research fan-out. A fresh session refills the pool, so hand deferred searches to the next session.

## Reading a completed run's return value

The `.output` file named in the `<task-notification>` (`/private/tmp/.../tasks/<taskid>.output`) is
a wrapper, not the bare return:

```json
{ "summary": "...", "agentCount": 111, "logs": [...], "result": { ...the workflow's return... } }
```

Parse it and read `wrapper.result` (`JSON.parse` it if it is a string). The notification's inline
`<result>` is the same object **truncated**, so for a big run read the file. The extraction helper
is a normal Node script; the runtime ban on `node:fs` / `Date.now()` applies to the Workflow script
body only.

## Resume and the transcript files

Same script plus the same args (re-passed by hand, above) is a 100% cache hit, which is also the
trap: a resumed run can report results no agent produced this session. A stopped run is reusable:
`TaskStop`, then relaunch with `resumeFromRunId`; a top-of-file `const` edit does not invalidate
downstream agent-call caches.

A running workflow uses the script as loaded at launch. Edits take effect only on `resumeFromRunId`,
and appending to a stage you will not re-run invalidates the cache for everything downstream. Codex:
the active task/subagent messaging surface reaches a live agent; the appendable-artifact habit is
host-independent.

| File | Holds | Read it for |
|---|---|---|
| `journal.jsonl` | each call's **return value** | drop reconciliation; diagnosing a thin result |
| `agent-<id>.jsonl` | each agent's **spawn config** + raw turn stream | verifying `"model"` actually applied; fallback when no journal exists |

## Stale-registry and cache gotchas

- **After editing a `.claude/workflows/` script, launch via `scriptPath`, never by `name`.** By-name
  resolution can serve a session-start-cached copy, and the run "succeeds" under the wrong config.
  Verify a run's configuration by grepping its `agent-*.jsonl` transcripts for `"model"`; per-agent
  spawn evidence beats a canary line the script prints.
- **Edited `.claude/agents/*.md` definitions are NOT hot-loaded.** The registry caches at session
  start. Validate a def changed this session by executing its procedure directly; defer literal
  dispatch to a fresh session.
- **Codex agent definitions and installed skill metadata are session inputs.** After changing
  `~/.codex/agents/*.toml`, `~/.agents/skills/`, or a skill's `agents/openai.yaml`, validate
  discovery in a newly started Codex task.

## Heartbeat recipes

`SKILL.md` § Orchestrator-delegate procedure sets the threshold (~10 minutes), the liveness probe and
the transcript-key check; these are the per-host loops.

- **Claude Code:** a Monitor, `sleep 600` loop, one status line per tick (implementers: elapsed +
  `git log -1 --oneline` + `git status --porcelain | wc -l`; workflows: elapsed + `agent-*.jsonl`
  count). Relay each tick as one line, TaskStop when the delegate reports, re-arm per delegate,
  timeout 3600s. To wait on a delegate without a Monitor, poll its transcript file for the
  report's final heading with a bounded `sleep 15` loop; a blocking `TaskOutput` that times out
  pastes the whole transcript into context (2026-09-04). Without a Monitor, `stat` the subagent transcript (`~/.claude/projects/<proj>/<session>/subagents/agent-<id>.jsonl`): a 40-minute-static mtime whose last tool call was a multi-line `echo`/heredoc Bash command was a hang (2026-09-05). `TaskStop`, then re-dispatch with a heredoc ban and a time budget in the brief.
- **Codex:** bounded task/agent waits carrying the same payload, relayed at ~10-minute cadence.
  A blocking sleep stalls communication instead of reporting it.

## Choosing the orchestration shape

Three shapes deliver a delegated implementation run. `SKILL.md` § Orchestrator-delegate procedure
requires asking the user which one before the first spawn, recommendation pre-selected; this table
is what the pre-selection reads from. All three burn the same usage window.

| Shape | Fits | Costs |
|---|---|---|
| **Agent-tool subagents** (`opus-implementer`, worktree isolation) | fan-out nobody needs to watch; short tickets; a parallel pair spawned in one message; inherits sandbox, permission mode and MCP config with no setup | opaque in flight: no dialog reaches the user, steering only by orchestrator message; nothing survives but the report, so no session to resume; every gate needing the sandbox off or an open editor runs in the orchestrator |
| **Coordinator pane + interactive child sessions** (§ below) | a mostly linear chain committing to real repositories that a human wants to watch, interrupt and resume; a child stops and asks at a grant boundary; its permission dialogs reach the user, so it can run a sandbox-off gate itself; the exact session resumes later | sequential, one writer per repository `main`; per-ticket pane, prompt-file and worktree setup with the settings file copied in; the multiplexer socket needs the sandbox bypass on every call; permission rules trip on prose until the standing clauses are in place |
| **Saved workflow script** | a fixed fan-out → verify pipeline that will run more than once; per-stage model and effort pins; resume from a run id | script authoring and the `args` channel (§ above); the dynamic workflow-size ceiling; least steerable in flight |

Pre-select by three questions, in order. *Will a human watch a ticket, or need to resume its
session?* The pane. *Does the work fan out wider than a pair and need no eyes?* Subagents, or a
workflow if it is a pipeline you will run again. *Neither?* Subagents, the shape with no setup.
State the pick and the question that decided it, then ask.

## Coordinating interactive child sessions in a terminal multiplexer (herdr)

A **coordinator** session drives *interactive* child sessions in sibling panes, one ticket per
child, each child writing its own closing note. Measured on **herdr**, a multiplexer that recognises
coding agents in panes and exposes `idle` / `working` / `blocked` / `done` states over a CLI; the
procedure transfers to any multiplexer with those two properties. **`herdr --skill` is the syntax
authority and tracks the installed binary; nothing below restates a flag.** (measured
2026-09-01/02) `PROCEDURES.md` § Hands-off ticket design governs the execution grant the children
read; this is the coordination layer above it.

**Partition, and give every child its cwd.**

- **One writer per repository `main`.** Two children committing to the same repo race the index
  lock and the pre-commit hook, so tickets writing the same repo run sequentially even where their
  blocking edges allow parallelism. Partition parallel children by repo, never by ticket order.
- **Set each child's cwd explicitly at the split.** The coordinator sits *outside* any tree a ticket
  renames or moves, which is exactly the case where an inherited cwd puts the child in the wrong
  place, or in a directory that stops existing mid-run.
- One child pane at a time, closed when its ticket closes. A fresh split per ticket kept the layout
  legible across 20 children.

**Start and prompt.**

- **Confirm the pins in the child's status line before the first prompt.** Model, effort and
  permission mode all take as native agent arguments after the separator, but a start that reports
  the agent not ready leaves a session that answers to its name while carrying none of them.
- **Keep the prompt in a file and paste from there.** Nested quoting is the one thing that reliably
  mangles between the coordinator's shell and the child's input box, and the file is the record of
  what the child actually executed.
- **The prompt carries the standing clauses, not just the ticket path.** Four earned their place,
  each removing exactly the interruption class it names: stage by explicit path in every repo and in
  any subagent; keep a guarded subcommand out of echo strings, comments and commit messages; write
  file contents with the editor tools rather than shell heredocs or redirects; revert a marker in a
  scratch clone by deleting and re-cloning rather than with a git verb.
- **Prose trips permission rules.** An unanchored `Ask` pattern matches the whole command text, so a
  child echoing a warning about a destructive verb, or a heredoc quoting the grant, blocks on a rule
  no git command triggered. This binds the coordinator's own prompt- and ledger-writing calls too,
  which is why coordinator prose goes through the editor tools. Measured: most of the first run's
  blocked returns were prose false positives; the clauses removed the classes they named, and
  re-anchoring the rules to the head of the command removed the rest. The wording lever is bounded;
  only the rule set closes the class.

**Ticks, and `blocked`.**

- **Ten-minute bounded waits.** Each wait returns on a settled state (ready, finished, blocked) or on
  its timeout, and the timeout is the heartbeat tick (payload per `SKILL.md` § Orchestrator-delegate
  procedure, Heartbeat). Every block across three runs surfaced *inside* a tick, so the cadence cost
  no responsiveness. Keep the tick cheap: a full verifier inside one overran the coordinator's own
  output limit.
- **`blocked` is the only interruption, and it can be stale.** Read the dialog before escalating;
  twice the pane was working again by the time it was read.
- **Never answer a permission dialog on the user's behalf.** Post its text, focus the child, wait.
  Answer only a *question* whose answer is stated literally in the ticket or the grant, and record
  the question with the line you answered it from. Confirm the notification surface actually
  reaches the user; where notifications were disabled, focusing the child was the only signal a
  human ever saw.
- **A child stopping at a grant boundary with a question is the shape to want, not a failure.**

**The handoff is the ticket file.**

- **Keep a child's transcript out of the coordinator's context.** The closing note plus the
  coordinator's own gate output is the whole handoff; cap every pane read (80 lines held across three
  runs). A note whose calibration section carries verbatim output lets the coordinator reproduce a
  verdict line for line.
- **Re-run the ticket's gate yourself, from the instrument, never from the note**, then verify what
  the child actually committed. A child's commit subject can mimic the coordinator's own ledger
  form, and twice read as a ledger touch the diff did not contain.
- **Hand children facts with pointers (a file, a line range, a command to re-derive), never
  decisions and never counts.** Every fact handed off came back as a decision with its reasoning in
  the note. **Every count handed off was wrong**, and the one that was right was confirmed only by a
  re-count.
- **Derive a gate's expected figure from the instrument's own gating, not the spec's prose.**
  "Exactly one failure", "green, every assertion" and "zero each" were each contradicted by an
  assertion the verifier runs unconditionally, a list the change itself invalidates, and a registry
  the spec never named. Read the verifier for unguarded assertions and list what the target state
  cannot clear *before* writing a verdict into a gate.
- **A red the child predicts in its note before the destructive step is the right shape.** The
  coordinator recognised it on sight instead of investigating it.
- **Verify "that section printed nothing" against the unfiltered instrument.** A coordinator's own
  tidy-up filter dropped the very assertion lines it was checking for.
- **A criterion no instrument can verify from where the child stands is reported *not run*, never
  passed.** Criteria that stay human (a read, a taste judgment) batch at the run's end rather than
  blocking each child. That is what keeps a hands-off chain hands-off without converting a human
  gate into a machine one.

**Close.**

- **The exit signal is the agent's disappearance from the live list, not a clean-looking pane.** A
  finished child's input box often shows the host's dimmed suggested prompt, grey text that reads
  like a typed command awaiting Enter. Enter against it does nothing; the exit command types over it,
  and the not-running error within a second is the confirmation. Get that before closing the pane.
- **Record each child's session name in the run's notes** so the user can resume that exact session.
  The name is released the moment its agent exits.

**Tickets that move or rename the ground under a session.**

- **A session writes its project-registry entry under its *start* cwd on exit, and re-creates its own
  project directory on its next transcript write.** A mover cannot clean up after itself: dropping
  the stale key and directory is a *later* session's step, and the verifier stays red until then.
  Schedule it that way in the ticket instead of reading the red as a defect.
- **Poll for the precondition rather than asking a human to confirm it.** Before starting a child
  whose ticket destroys a path, a 5-second poll over the live agent list matching cwd prefixes,
  posted once, cost three minutes and no attention.
- **A ticket whose last step destroys the session's cwd must name which criteria are read after it
  and where those readings land**, which is the child's final message, since the note can no longer
  be written. Without that, a complete note reads as an abandoned one.
- **A shared registry file that every live session writes cannot be asserted byte-wise.** 24
  seconds after one atomic edit it already differed. Assert over the structure you care about (the
  map, the key set), never the document's bytes or digest.

**Run end.**

- **Sweep for strays with a newer-than-marker walk over the parent directories**, not only the
  repos: touch a marker at the run's start, list what is newer at its close. It is the only thing
  that sees a file a child wrote outside every tree anyone was watching.
- **A close-out artifact can red the very check it reports on.** A closing note quoting the forbidden
  string a repo-wide check hunts turns that check red on the note itself. The fix is the check's own
  documented exclusion path, regenerated and committed; regeneration is a normal closing step for
  any document that must name the thing.
- **Record the session usage window at each child's start and exit.** Above roughly 80%, say so
  and expect the next ticket to stall: a child that hits the limit stalls the coordinator with it
  until the window resets (measured 2026-09-02).

## Cross-session coordination (peers on a shared mutable system)

- **Announce a state change BEFORE making it, never after.** Restarting a daemon, killing a
  process, editing shared config, deleting files: a peer's unannounced mutation *manufactures
  evidence*. A probe launched seconds after a peer's kill read as a clean reproduction of a fault
  that did not exist (2026-08-27). Post intent, target and window; on the receiving side, treat any
  anomaly whose onset coincides with a peer's activity as unattributed until confirmed.
- **Verify a peer's claim about a layer you cannot see, and say which layers are invisible to you.**
  Peer reports are upstream facts (Claude Code: the `verification-discipline` skill); an absence
  claim over a system you can only partly observe is not a claim about the system.
- **A peer repeating your own claim back is one source arriving twice, not corroboration.** The
  copy carries a second name. **Relaying is asserting:** before handing a status claim back to the
  seat that authored it, verify it against the artifact, not the handoff. An "owed / not done /
  missing" claim is an absence claim: grep the artifact and name the scope (2026-08-29).
