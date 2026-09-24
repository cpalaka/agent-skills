# A permission dialog under `default` mode, depth-1 to depth-2, and in a herdr pane

Research for #93, child of Spec #91, feeding the `implement-batch` Skill's dialog paragraph
(ADR 0019 § 5).

**Tags.** **[measured]** means observed in a live probe on 2026-09-24 between 04:47 and 04:58 PDT,
read from the pane's screen, a transcript `.jsonl`, or herdr's own output. **[doc-read]** means
text the harness itself wrote into a transcript or dialog. **[inferred]** is reasoning over those.

**Versions.** Claude Code 2.1.281. herdr 0.9.1, Claude detection manifest `claude.toml`
2026.09.11.1. tmux 3.6b. macOS (Darwin 24.6.0). Every main session ran on `opus` (Opus 5.5) at
`--effort low`. Every depth-1 relay was `general-purpose` pinned `model: "opus"` on the dispatch.
Depth-2 was `general-purpose` pinned `opus` in run A and the user-level `implementer` definition
(`model: opus`) in runs B, C1 and C2.

## Setup

- **Throwaway directory.** `mktemp -d /tmp/probe93.XXXXXX` → `/tmp/probe93.siuxRR`, then
  `git init`. Its `.claude/settings.json` was
  `{"permissions":{"defaultMode":"default","allow":["Bash(echo:*)"]}}`.
- **Permission mode.** The user-level `defaultMode` is `auto`, so every probe session launched
  with `--permission-mode default` explicitly. The footer read `⏸ manual mode on`, and the
  transcript's user entries read `"permissionMode":"default"`. No user-level `sandbox` block is
  set. The user-level `PreToolUse` Bash hook gates only git commands, and the probe command was not
  git.
- **The command outside the allowlist.** `touch probe93-marker-<run>.txt`. The marker file exists
  if and only if the call ran.
- **The chain.** One typed prompt told the main session to dispatch a depth-1 relay, which
  dispatched the depth-2 seat, which ran the one command with no retry.
- **Main session outside herdr** (runs A and B). The session ran in a detached tmux session with
  every `HERDR_*` variable unset:

  ```sh
  tmux new-session -d -s probe93 -x 180 -y 50 -c /tmp/probe93.siuxRR \
    "env -u HERDR_ENV -u HERDR_PANE_ID … claude --permission-mode default --model opus --effort low"
  ```

  The screen was read with `tmux capture-pane -p` and answered with `tmux send-keys`. The
  folder-trust dialog was accepted once, by keystroke, before run A.
- **Main session in a herdr pane** (runs C1 and C2). A sibling pane was split with
  `herdr pane split --current --direction down --cwd /tmp/probe93.siuxRR --no-focus`, and the
  session started with
  `herdr agent start probe93 --kind claude --pane <id> -- --permission-mode default --model opus --effort low`.
  It was driven with `herdr agent prompt … --wait`. The state was read with `herdr agent get`
  (sampled every 1 s in C1 and every 0.5 s in C2), `agent explain` and `agent read`. The dialog was
  answered with `herdr agent send-keys`.
- **Two variants.**
  - **Idle main** (runs A and C1): the main session ends its turn after dispatching.
  - **Busy main** (runs B and C2): after dispatching, the main session makes twelve allowlisted
    `echo tick-N` Bash calls, one per message.
- **Answers.** A: Esc. B: `1` (Yes). C1: `4` (No). C2: Esc.

## Reading 1 — does a dialog surface in the main session?

**Yes.** [measured, all four runs] The depth-2 seat's Bash call raised a permission dialog in
the main session's own terminal UI. It appeared 10–11 s after the prompt was submitted: sent
04:47:44, dialog on screen by 04:47:54 in run A; 04:53:38 → 04:53:49 in run B. The dialog read,
verbatim:

```
 Bash command · from the general-purpose agent
 Tip: auto mode handles these prompts for you — choose "switch to auto mode" below
   touch probe93-marker-A.txt
   Create marker file
 Do you want to proceed?
 ❯ 1. Yes
   2. Yes, and always allow access to /private/tmp/probe93.siuxRR from this project
   3. Yes, and switch to auto mode · auto mode handles these prompts for you
   4. No
 Esc to cancel · Tab to amend
```

- **The label names the seat's definition**, not its dispatch description, its depth, or the
  agent that dispatched it. Runs B, C1 and C2 read `from the implementer agent`, and run A read
  `from the general-purpose agent`. Nothing on screen names the depth-1 relay. [measured]
- **The call was not auto-denied**, even though both subagents' `meta.json` carries
  `"requestShape":"background","requestNonInteractive":true`. [measured]
- **Option 3 switches the whole session to auto mode**, and option 2 writes a standing
  allow-rule for the directory. Neither was pressed. [doc-read, the dialog's own text]

## Reading 2 — what the main session sees while it is open

**Nothing.** [measured] While the dialog is open, no model in the chain receives any signal of it.

- **Idle main** (runs A and C1): every turn in the chain had ended.
  - The main session ended its turn 2 s after dispatching, saying the relay was "running in the
    background". The TUI above the dialog showed `✻ Waiting for 1 background agent to finish`.
  - The depth-1 relay ended its own turn at 11:47:54 UTC, 3 s after its dispatch. It reported that
    no prompt appeared at its level. It was kept alive rather than handed back. The harness's
    task-notification text explains why: "A task-notification fires each time this agent stops
    with no live background children of its own." [doc-read]
  - The depth-2 seat's transcript ended at its `tool_use`, with no `tool_result`.
  - In run A, all three transcripts gained no line between 04:47:54 and the Esc at 04:51:41, a
    3 min 47 s hold. The dialog did not time out, and the marker file did not appear.
- **Busy main** (runs B and C2): the main session kept working the whole time.
  - In run B the dialog was on screen from 04:53:49. The main session then made ten more `echo`
    calls, tick-3 to tick-12, through 11:54:06 UTC. Each returned only its own output. After each
    one the model answered "only the echo output came back". It then ended its turn, still
    "waiting" on the relay.
  - The dialog stayed pinned below the scrolling transcript, and the TUI counted
    `Waiting for 2 background agents to finish`: the relay and the seat together.
- **So from inside, a dialog shows up only as silence.** The delegate cannot tell a coordinator
  held by a dialog from a coordinator that is slow. [inferred]

## Reading 3 — can anything in the chain answer it?

**Nothing in the chain answered it in any run. Only a keystroke in the main session's terminal
did.** [measured]

- **No model acted on the dialog.** No tool call at any depth, in any run, touched it. The
  busy-main runs show that the main session's own tool calls succeed while it is open and carry
  no handle to it.
- **No tool in the chain answers a dialog.** #89 measured the tool lists at depths 1 and 2: none
  has AskUserQuestion, and none has a tool that answers one.
- **How an answer reached the seat** [measured]:

  | Run | Keystroke (local time) | Seat's `tool_result` | Main received the hand-back |
  |---|---|---|---|
  | A | Esc, 04:51:41 | same second, `is_error: true` | 11:51:54 UTC, 13 s later |
  | B | `1` Yes, 04:54:18 | same second, `(Bash completed with no output)`; marker file created | 11:54:29 UTC, 11 s later |
  | C1 | `4` No, 04:55:15 | same second, `is_error: true` | 11:55:24 UTC, 9 s later |
  | C2 | Esc, 04:57:24 | same second, `is_error: true` | 11:57:33 UTC, 9 s later |

- **A denial is opaque to the seat.** All three denials, Esc twice and No once, returned
  byte-identical text: "Permission for this tool use was denied. The tool use was rejected (eg.
  if it was a file edit, the new_string was NOT written to the file). Try a different approach or
  report the limitation to complete your task." The seat cannot tell an owner's No from an Esc,
  and says it cannot tell either from a rule or a hook.
- **An approval is invisible to the seat.** Its result is an ordinary success, with no mention
  that anyone was asked.
- **A denial does not stop the seat.** Every denied seat reported and handed back normally, which
  matches the harness doc #89 quoted ("press Esc to deny that one tool call without stopping the
  subagent").
- **Unmeasured: a session typing into its own dialog through a multiplexer.** When the main
  session itself runs inside herdr or tmux, its own Bash has the multiplexer CLI and its pane id
  (`$HERDR_PANE_ID` is in the environment). A `herdr pane send-text "$HERDR_PANE_ID" 1` from the
  busy main session would land a keystroke in its own open dialog, by #83's measurement that
  `pane send-text` answers a live dialog. [inferred] A probe of exactly that was prepared, with
  `Bash(herdr:*)` allowlisted in the throwaway project only. The probe's *parent* session (auto
  mode) refused to launch it: its classifier denied the prompt submission as "Tmux Self Drive".
  Nothing was sent to the probe pane. So whether it works is **not measured**. What was measured
  is that one auto-mode classifier treats a session driving its own dialog through a
  multiplexer as an action to refuse.

## Reading 4 — the same chain in a herdr pane, read through `agent get`

[measured, runs C1 and C2; herdr 0.9.1, manifest 2026.09.11.1]

- **The status reads `blocked`, by rule `bash_permission_prompt`.** `agent explain` returned
  `rule: bash_permission_prompt (region=whole_recent priority=850)`. This is the same rule #83
  measured for a dialog in the pane's own session. A depth-2 dialog is not told apart from a
  main-session dialog.
- **`agent prompt --wait` settles on the nested dialog.** C1's prompt was sent at 04:54:59 and
  `--wait` returned `"agent_status":"blocked"` at 04:55:09. `agent wait --until blocked` then
  returned at once. The C1 sampler read `working` ×8 and then `blocked` from 04:55:09.
- **`agent prompt` is refused while the dialog is open.** It returned
  `{"error":{"code":"agent_blocked","message":"agent probe93 is blocked and requires interactive input"}}`.
- **`agent send-keys` is not refused.** `agent send-keys probe93 4` returned `{"type":"ok"}` and
  denied the call, and `agent send-keys probe93 esc` did the same in C2. This repeats #83.
- **`blocked` masks a session that is still working.** In C2, the 0.5 s sampler read `blocked`
  from 04:56:45 until the Esc. Over that window the main session's transcript shows `echo`
  tick-3 to tick-12 running from 11:56:46 to 11:57:05 UTC. `agent prompt --wait` for that turn
  also returned `blocked` at 04:56:45, mid-turn. So a herdr `blocked` on a pane running a batch
  does not mean the delegate has stopped.
- **After an answer, the pane goes `done` and then `idle`** once the hand-back chain completes.
  C1 was answered at 04:55:15 and settled `done` at 04:55:29. C2 was answered at 04:57:24 and
  settled `idle` at 04:57:37.

## What the batch Skill's dialog paragraph may now assert

Measured on Claude Code 2.1.281, with the batch on the subagent transport in any prompting mode
(`default` measured):

1. **A seat's permission request surfaces as a dialog in the owner's main-session UI.** It is
   neither auto-denied nor routed to the coordinator. It is labelled with the seat's definition
   name (`from the implementer agent`), not the ticket, the coordinator or the depth. With one
   ticket in flight the label is enough. With two, it would not tell them apart. [inferred]
2. **It holds until someone presses a key in that terminal.** No timeout was seen in 3 min 47 s.
3. **No model in the chain is told a dialog is open.**
   - The coordinator's turn has ended.
   - The delegate either has ended its turn or keeps working with no sign of the dialog in any
     tool result.
   - So a coordinator that goes quiet may be held by a dialog, and the delegate must not read the
     silence as a failure or a crash.
4. **No tool in the chain answers a dialog.** The Skill should forbid the one path that might:
   the delegate or any seat sending keys to its own pane through herdr, tmux or any other
   multiplexer. That path is unmeasured. One classifier already refuses it.
5. **The seat learns only approved or denied, and nothing about how or by whom.** An owner's
   answer reaches the delegate as an ordinary hand-back 9–13 s later, so the batch needs no
   special resume.
6. **The dialog offers "Yes, and switch to auto mode".** An owner who picks it moves the rest of
   the batch into auto mode. The Skill should say so, because ADR 0019 § 5 has the batch "run in
   whatever permission mode it was started in".
7. **Under herdr, `blocked` covers a nested seat's dialog too**, by the same
   `bash_permission_prompt` rule. It persists while the pane's session is still working.
   `agent prompt` is refused and `send-keys` is not, so § 5's "every `blocked` is the owner's"
   stands, and a herdr watcher cannot treat `blocked` as "the delegate has stopped".

## Unmeasured

- A session answering its own dialog through a multiplexer's CLI (Reading 3's last bullet).
- A main-session tool call that needs permission while a nested seat's dialog is already open:
  whether the two queue, stack or replace each other.
- Two seats' dialogs open at once.
- File-edit, MCP and web permission dialogs; only Bash was provoked.
- Modes other than `default` and `auto`, such as `acceptEdits` and `plan`; Codex hosts; headless
  sessions (out of scope in #91).

## Probe hygiene

- **One run needed a second prompt.** In C2 the long prompt arrived wrapped as pasted content.
  The session asked whether to act on it rather than acting, so a short typed
  `yes, run it as written` followed. C2's status sampler restarted at that second prompt.
  The `❯ yes, run it as written` shown in the input box beforehand was a dimmed prompt
  suggestion, not input (#83's ghost-text note).
- **Timestamps.** Screen, sampler and `date` times are PDT. Transcript times are UTC, 7 h ahead.
- **Cleanup.** The two probe panes (the C1/C2 pane and the unsent D pane) and the tmux session
  were closed. The throwaway directory's allowlist was restored before closing.
