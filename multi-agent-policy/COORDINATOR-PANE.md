# Coordinating a run through panes and child sessions

The two shapes a run can take when the seats are not Agent-tool sub-agents: a **coordinator** pane
driving interactive child sessions, and the heartbeat that keeps any long-running seat honest.
Nothing loads this by default. Read it when you are

- choosing the shape of a delegated run (§ Choosing the orchestration shape);
- arming a heartbeat on a seat expected to run past ~10 minutes (§ Heartbeat recipes);
- driving tickets through interactive child sessions in a terminal multiplexer (§ Coordinating
  interactive child sessions);
- sharing a live system you mutate or observe with a peer session (§ Cross-session coordination).

The `implement-run` Skill governs the run itself — the seat roster, the slots, the run record. This
file carries only the pane mechanics that Skill points at, and relaxes nothing there.

## Choosing the orchestration shape

Three shapes deliver a delegated implementation run. The `implement-run` Skill takes the pick from
the project's `shape` knob and asks only where the ticket cannot fit it; this table is what that
question reads from. All three burn the same usage window.

| Shape | Fits | Costs |
|---|---|---|
| `subagents` — **Agent-tool subagents** (`implementer`, worktree isolation) | fan-out nobody needs to watch; short tickets; a parallel pair spawned in one message; inherits sandbox, permission mode and MCP config with no setup | opaque in flight: no dialog reaches the user, steering only by coordinator message; nothing survives but the report, so no session to resume; a gate needing an open editor still runs in the coordinator, but sandbox-off Bash works from a subagent (measured 2026-09-14), so a gate-runner delegate carries those gates where the project defines one |
| `coordinator-pane` — **a coordinator pane + interactive child sessions** (§ below) | a mostly linear chain committing to real repositories that a human wants to watch, interrupt and resume; a child stops and asks at a grant boundary; its permission dialogs reach the user, so it can run a sandbox-off gate itself; the exact session resumes later | sequential, one writer per repository `main`; per-ticket pane, prompt-file and worktree setup with the settings file copied in; the multiplexer socket needs the sandbox bypass on every call; permission rules trip on prose until the standing clauses are in place |
| `workflow` — **a saved workflow script** | a fixed fan-out → verify pipeline that will run more than once; per-stage model and effort pins; resume from a run id | script authoring and the `args` channel (`WORKFLOWS.md`); the dynamic workflow-size ceiling; least steerable in flight |

Where a project has no saved `shape`, or the ticket cannot fit the one it has, pick by three
questions, in order. *Will a human watch a ticket, or need to resume its session?* The pane. *Does
the work fan out wider than a pair and need no eyes?* Subagents, or a workflow if it is a pipeline
you will run again. *Neither?* Subagents, the shape with no setup. State the pick and the question
that decided it, then ask.

## Heartbeat recipes

A seat expected to run past ~10 minutes gets a calibrated liveness check; solo and interactive work
need none. No growth and no commit earns one liveness probe (`find <scope> -mmin -12`) before you
declare a hang, since a static tree is also what a gate run looks like. Verify the monitor's
transcript key against one real journal line before reporting from it: a monitor grepping the wrong
field reports `completed=0` forever while agents finish (`verification-discipline`). These are the
per-host loops.

- **Claude Code:** a Monitor, `sleep 600` loop, one status line per tick (implementers: elapsed +
  `git log -1 --oneline` + `git status --porcelain | wc -l`; workflows: elapsed + `agent-*.jsonl`
  count). Relay each tick as one line, TaskStop when the delegate reports, re-arm per delegate,
  timeout 3600s. To wait on a delegate without a Monitor, poll its transcript file for the
  report's final heading with a bounded `sleep 15` loop; a blocking `TaskOutput` that times out
  pastes the whole transcript into context (2026-09-04). Without a Monitor, `stat` the subagent transcript (`~/.claude/projects/<proj>/<session>/subagents/agent-<id>.jsonl`): a 40-minute-static mtime whose last tool call was a multi-line `echo`/heredoc Bash command was a hang (2026-09-05). `TaskStop`, then re-dispatch with a heredoc ban and a time budget in the brief.
- **Codex:** bounded task/agent waits carrying the same payload, relayed at ~10-minute cadence.
  A blocking sleep stalls communication instead of reporting it.

## Coordinating interactive child sessions in a terminal multiplexer (herdr)

A **coordinator** session drives *interactive* child sessions in sibling panes, one ticket per
child, each child writing its own closing note. Measured on **herdr**, a multiplexer that recognises
coding agents in panes and exposes `idle` / `working` / `blocked` / `done` states over a CLI; the
procedure transfers to any multiplexer with those two properties. **`herdr --skill` is the syntax
authority and tracks the installed binary; nothing below restates a flag.** (measured
2026-09-01/02) `GRANTS.md` governs the execution grant the children
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
  its timeout, and the timeout is the heartbeat tick (payload per § Heartbeat recipes
  above). Every block across three runs surfaced *inside* a tick, so the cadence cost
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
