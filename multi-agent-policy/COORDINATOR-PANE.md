# Coordinating a run through panes and child sessions

Read this when choosing a delegated run's shape, arming a heartbeat on a seat expected to run past
~10 minutes, driving tickets through interactive child sessions in a terminal multiplexer, or
sharing a live system with a peer session. The `implement-run` Skill governs the run itself; this
file relaxes nothing there.

## Choosing the orchestration shape

`implement-run` takes the shape from the project's `shape` knob and asks only where a ticket cannot
fit it; this table is what that question reads from. All three burn the same usage window.

| Shape | Fits | Costs |
|---|---|---|
| `subagents` — Agent-tool seats | fan-out nobody watches; short tickets; a parallel pair spawned in one message; inherits sandbox, permission mode and MCP config | opaque in flight, steered only by coordinator message; nothing survives but the report; sandbox-off Bash works from a sub-agent (2026-09-14), so a gate-runner seat carries those gates where the project defines one; a gate needing an open editor stays with the coordinator |
| `coordinator-pane` — interactive child sessions (§ below) | a mostly linear chain committing to real repos that a human wants to watch, interrupt and resume; a child stops and asks at a grant boundary; its permission dialogs reach the user | sequential, one writer per repo `main`; per-ticket pane, prompt file and worktree setup, the settings file copied in; the multiplexer socket needs the sandbox bypass on every call; prose trips permission rules until the standing clauses are in place |
| `workflow` — a saved script (`WORKFLOWS.md`) | a fixed fan-out → verify pipeline run more than once; per-stage model and effort pins; resume from a run id | script authoring and the `args` channel; the workflow-size ceiling; least steerable |

With no saved `shape`, or a ticket that cannot fit it, ask in order: *will a human watch a ticket or
resume its session?* The pane. *Does it fan out wider than a pair with no eyes needed?* Sub-agents,
or a workflow if it is a pipeline you will rerun. *Neither?* Sub-agents. State the pick and the
question that decided it, then ask.

## Heartbeat recipes

Only a seat expected to run past ~10 minutes gets one. Before declaring a hang on no growth and no
commit, run one liveness probe (`find <scope> -mmin -12`): a static tree is also what a gate run
looks like. Check the monitor's transcript key against one real journal line first — a monitor
grepping the wrong field reports `completed=0` forever while agents finish.

- **Claude Code:** the harness notifies you when a sub-agent or background task finishes, so a
  heartbeat is for liveness, not completion. Arm a Monitor that emits one status line per ~10
  minutes (implementers: elapsed + `git log -1 --oneline` + `git status --porcelain | wc -l`;
  workflows: elapsed + `agent-*.jsonl` count), relay each tick as one line, stop it when the
  delegate reports; one Monitor per delegate, timeout 3600 s. A sub-agent transcript
  (`~/.claude/projects/<proj>/<session>/subagents/agent-<id>.jsonl`) static for 40 minutes after a
  multi-line `echo`/heredoc Bash call was a hang (2026-09-05): `TaskStop`, then re-dispatch with a
  heredoc ban and a time budget in the brief.
- **Codex:** bounded task/agent waits carrying the same payload, relayed at ~10-minute cadence. A
  blocking sleep stalls communication instead of reporting it.

## Coordinating interactive child sessions in a terminal multiplexer (herdr)

A coordinator session drives interactive child sessions in sibling panes, one ticket per child,
each child writing its own closing note. Measured on **herdr** (2026-09-01/02, three runs), which
recognises coding agents in panes and exposes `idle` / `working` / `blocked` / `done` over a CLI;
the procedure transfers to any multiplexer that does both. **`herdr --skill` is the syntax
authority; nothing below restates a flag.** `GRANTS.md` governs the execution grant the children
read.

**Partition and start.**

- **One writer per repository `main`** — two children committing to one repo race the index lock
  and the pre-commit hook. Partition parallel children by repo, never by ticket order.
- **Set each child's cwd explicitly at the split.** An inherited cwd lands wrong exactly when a
  ticket renames or moves a tree.
- **One child pane at a time**, closed when its ticket closes.
- **Confirm the pins in the child's status line before the first prompt.** A start that reports the
  agent not ready leaves a session answering to its name with none of its model, effort or
  permission-mode arguments.
- **Keep the prompt in a file and paste from there** — nested quoting mangles between shells, and
  the file records what the child executed.
- **The prompt carries four standing clauses**, each removing one interruption class: stage by
  explicit path, in every repo and sub-agent; keep a guarded subcommand out of echo strings,
  comments and commit messages; write file contents with the editor tools, not heredocs or
  redirects; revert a marker in a scratch clone by re-cloning, not with a git verb.
- **Prose trips permission rules.** An unanchored `Ask` pattern matches the whole command text, so
  a child echoing a warning about a destructive verb blocks on a rule no git command triggered —
  most of the first run's blocks. This binds the coordinator's own writes too, hence the editor
  tools. The clauses shrink the class; only anchoring the rules to the head of the command closes
  it.

**Ticks and `blocked`.**

- **Ten-minute bounded waits**, each returning on a settled state or on its timeout, which is the
  heartbeat tick. Every block across three runs surfaced inside a tick. Keep the tick cheap: a full
  verifier inside one overran the coordinator's output limit.
- **`blocked` is the only interruption, and it can be stale** — read the dialog before escalating.
- **Never answer a permission dialog on the user's behalf.** Post its text, focus the child, wait.
  Answer only a *question* whose answer the ticket or grant states literally, recording the line
  you answered from. Confirm the notification surface reaches the user; with notifications off,
  focusing the child was the only signal anyone saw.
- **A child stopping at a grant boundary with a question is the shape to want.**

**The handoff is the ticket file.**

- **Keep a child's transcript out of the coordinator's context**: the closing note plus your own
  gate output is the handoff. Cap every pane read (80 lines held).
- **Re-run the ticket's gate yourself, from the instrument, never from the note**, then check what
  the child committed — a child's commit subject twice mimicked the coordinator's ledger form for a
  change the diff did not contain.
- **Hand children facts with pointers** (a file, a line range, a command to re-derive), **never
  decisions and never counts.** Every fact handed off came back as a decision; every count handed
  off was wrong.
- **Derive a gate's expected figure from the verifier's own gating, not the spec's prose.** Read
  the verifier for unguarded assertions and list what the target state cannot clear before writing
  a verdict into a gate.
- **Check "that section printed nothing" against unfiltered output** — a tidy-up filter once
  dropped the very lines being checked for.
- **A criterion no instrument can verify from the child's position is reported *not run*, never
  passed.** Human criteria batch at the run's end rather than blocking each child.
- **A red the child predicts in its note before a destructive step is the right shape.**

**Close and run end.**

- **The exit signal is the agent leaving the live list**, not a clean-looking pane: a finished
  child's input box shows a dimmed suggested prompt that Enter does nothing to. Type the exit
  command over it; a not-running error within a second confirms.
- **Record each child's session name in the run's notes** before it exits, so the user can resume
  it.
- **Tickets that move the ground under a session**: a session writes its registry entry under its
  start cwd on exit and re-creates its project directory on its next transcript write, so cleanup
  is a later session's step and the verifier stays red until then — schedule it, don't read it as a
  defect. Before starting a child whose ticket destroys a path, poll the live agent list for
  matching cwd prefixes rather than asking a human to confirm (a 5-second poll cost three minutes
  and no attention). A ticket whose last step destroys the cwd names which criteria are read after
  it, reported in the child's final message. Assert a shared registry file by structure, never
  bytes — it differed 24 seconds after one edit.
- **Sweep for strays with a newer-than-marker walk over the parent directories**, not only the
  repos: touch a marker at the start, list what is newer at the close.
- **A close-out note quoting a string a repo-wide check hunts turns that check red on itself.** Use
  the check's documented exclusion path, regenerated and committed.
- **Record the session usage window at each child's start and exit.** Above ~80%, say so: a child
  hitting the limit stalls the coordinator until the reset (2026-09-02).

## Cross-session coordination (peers on a shared mutable system)

- **Announce a state change before making it.** A peer's unannounced restart, kill, config edit or
  deletion manufactures evidence: a probe seconds after a peer's kill read as a clean reproduction
  of a fault that did not exist (2026-08-27). Post intent, target and window; on receipt, treat an
  anomaly coinciding with a peer's activity as unattributed until confirmed.
- **Verify a peer's claim about a layer you cannot see, and name the layers invisible to you.**
  Peer reports are upstream facts (`verification-discipline`).
- **A peer repeating your own claim back is one source arriving twice**, not corroboration. Before
  relaying a status claim to the seat that authored it, verify it against the artifact; an "owed /
  not done / missing" claim is an absence claim — grep the artifact and name the scope
  (2026-08-29).
