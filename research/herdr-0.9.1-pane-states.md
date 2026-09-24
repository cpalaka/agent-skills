# What herdr 0.9.1 tells a coordinator about a Claude Code pane

Research for #83, feeding #81's permission-dialog rule and polling contract.

**Tags.** **[measured]** means observed in a live probe on 2026-09-23. **[doc-read]** means read
from a primary source: herdr's own agent skill (`herdr --skill`), CLI help, the API schema
(`herdr api schema --json`), herdr's Claude detection manifest, or the Claude hook script herdr
installs.

**Versions.** herdr client and server 0.9.1 (protocol 22). The Claude detection manifest is
`claude.toml` 2026.09.11.1, a remote manifest cached under `~/.local/state/herdr/agent-detection/remote/`.
The herdr Claude integration is v10. Claude Code is 2.1.281, launched as
`claude --permission-mode default --model sonnet` in a throwaway git repo under `$TMPDIR`, in one
scratch pane split from the coordinator's own pane. No other pane was read or written.

## Headline

1. **herdr's Claude status comes entirely from screen scraping, with no hook.** [doc-read] The
   installed Claude hook (`~/.claude/hooks/herdr-agent-state.sh`, v10) runs only on `SessionStart`
   and sends only `pane.report_agent_session`, which carries session identity and never a state.
   Every `idle` / `working` / `blocked` / `done` value for Claude comes from herdr's regex manifest
   applied to the pane's screen and terminal title. So `blocked` is itself a pane-text judgment made
   by herdr. It only looks structural.
2. **`blocked` does not separate a permission dialog from a question form.** [measured] Four
   dialog kinds all read `agent_status: "blocked"`:
   - a Bash permission dialog;
   - a background subagent's permission dialog, surfaced in the parent pane;
   - the folder-trust dialog at startup;
   - an `AskUserQuestion` form.

   A plain-chat question that ends the turn reads `done`, then `idle`, and never `blocked`.
3. **Input can land in an open dialog.** [measured] `agent prompt` is refused while the pane is
   `blocked`. `agent send-keys` and `pane send-text` are not refused, and both answered a live
   permission dialog with a single digit and no Enter.

## Per-state table

The latency column is measured from the prompt's submission, or from the state change, to the
first herdr signal. The event column is the `events.subscribe` stream (`pane.agent_status_changed`).
Every row is **[measured]**.

| State | `agent wait --until blocked` | `agent get` → `agent_status` | `agent explain` rule | `agent read` (verbatim tail) | Latency | Status reliable for this state? |
|---|---|---|---|---|---|---|
| **1a. Bash permission dialog** | returned `"agent_status":"blocked"` | `blocked` | `bash_permission_prompt (region=whole_recent priority=850)` | `Bash command` … `Do you want to proceed?` / `❯ 1. Yes` … `4. No` / `Esc to cancel · Tab to amend` | working→blocked event 1.46 s after submission; the wait returned 0.09 s after the event; `prompt --wait` returned `blocked` in 1.8 s | **yes** for "some dialog is open"; **no** for "it is a permission dialog" (see 1c, 2a) |
| **1b. Subagent's permission dialog** (a background subagent ran `wait`) | not run; `agent get` sampled at 3 s | `blocked` | `bash_permission_prompt` | `Bash command · from the general-purpose agent` / `wait` / `This command requires approval` / `Do you want to proceed?` | appeared about 9 s into a background wait, while the parent read `working` | yes, same caveat. **A background wait can turn into a dialog.** |
| **1c. Folder-trust dialog** (startup) | — | `blocked`, `launch_pending: true` | `live_blocked_form (region=after_last_horizontal_rule priority=980)` | `Quick safety check: Is this a project you created or one you trust?` / `❯ No, exit` / `Yes, I trust this folder` / `Enter to confirm · Esc to cancel` | `agent start` returned `{"code":"agent_not_ready","message":"agent probe is blocked during startup and is not ready for prompts"}` after 3.6 s | yes; its rule is the **same** as the question form's (2a) |
| **2a. Chat question via `AskUserQuestion` form** | returned `blocked` in 2.2 s | `blocked` | `live_blocked_form (…priority=980)` | `☐ Colour` / `Which colour do you prefer?` / `❯ 1. Red` … `4. Chat about this` / `Enter to select · ↑/↓ to navigate · Esc to cancel` | 2.2 s | status: **indistinguishable from a permission dialog** |
| **2b. Chat question in plain text, turn ended** | **timeout** at 20 s (and at 60 s in a second, unplanned instance): `{"error":{"code":"timeout","message":"timed out waiting for agent status"}}` | `done` (unseen), later `idle` | `live_prompt_box (region=prompt_box_body priority=950)` | `⏺ … what would you like me to actually do next?` / `✻ Worked for 1s · done 9:49 PM` / `❯` | working→done 1.3 s | **no.** Identical to any finished turn; only the text says it is a question |
| **3a. Background shell running, turn ended** | not run | `idle` for 25 s of sampling (every 3 s) | `live_prompt_box` | `✻ Baked for 2s · done 9:49 PM · 1 shell still running`; footer `⏸ manual mode on · 1 shell` | — | **no.** Reads as a real stop. The session **woke itself** (`working`, no input) 44 s later when the shell finished |
| **3b. Background subagent running, turn ended** | not run | `working` | `osc_title_working (region=osc_title priority=1100)` | `⏺ LAUNCHED` / `✻ Waiting for 1 background agent to finish` | — | **yes here** (reads `working`). **Contradicts test run 1 on #81**, which saw `idle`; see Open questions |
| **4. Working** | — | `working` | `osc_title_working` or `live_turn_working` | spinner line, `esc to interrupt` | working event about 0.15–0.5 s after submission | yes |

### Other measured behaviour of the waits

- **`agent wait --until idle` never matches `done`.** [measured] With the pane at `done`,
  `--until idle --timeout 15000` timed out after 15.02 s. herdr's skill says `done` flips to `idle`
  only once the completion is *seen*: an explicit focus command marks it, and reads do not
  [doc-read]. In the probe, `done→idle` flips happened 3.6 s and 30 s after the turn with no
  coordinator action, most likely from a TUI client viewing the pane. That is the probable cause of
  test run 1's "long `--until idle` calls returned late": they returned when a human looked.
- **`agent wait` is level-triggered, not edge-triggered.** [measured]
  - `agent prompt` without `--wait`, followed by `agent wait --until idle`, returned in 0.37 s,
    before the turn had started. The PONG turn went `working` about 1 s later.
  - After `send-keys esc`, a plain `agent wait` returned `blocked` at once, which was the stale
    state before Esc registered.
  - Either wait any state change first, or use `agent prompt --wait`. The prompt's `--wait` requires
    observed `working`/`blocked` activity within 5 s ([doc-read], skill), and it returned `done` in
    1.78 s for a one-word reply [measured].
- **Transient `blocked` flashes.** [measured] Answering a dialog produced `blocked → idle` or
  `blocked → done` about 0.3 s after the key. A poller that samples only on a fixed tick can miss a
  dialog that someone else answered quickly. This does not matter for safety, but it matters for
  audit.
- **Ghost text in reads.** [measured] Claude Code renders a dimmed prompt suggestion in the input
  box (`❯ just run it, it's fine`, `❯ check on it`), styled `ESC[2m`. A text read with
  `--format text` shows it as if typed. A coordinator matching on the `❯` line can misread it.

## Is a dialog structurally distinguishable?

**Not by `agent_status`.** [measured] A permission dialog and an `AskUserQuestion` form are both
`blocked`.

**Partly by `agent explain`'s rule id**, which is still text-derived [measured + doc-read]:

- `bash_permission_prompt` (priority 850) and `generic_permission_prompt` (840) match permission
  dialogs only. Their manifest predicates are "do you want to proceed?" plus yes/no option lines.
- `live_blocked_form` (980) matched **both** the `AskUserQuestion` form and the harness's
  folder-trust dialog. It is a generic "select/confirm form" rule.
- `mcp_elicitation_prompt` and `dynamic_workflow_prompt` are further `blocked` rules [doc-read].
- `legacy_no_prompt_blocker` (300) is a catch-all that fires on phrases like "do you want to" or
  "would you like to" together with "yes". Chat prose containing those words could trigger it
  [doc-read].

So the rule id tells a Bash/tool permission dialog apart from a form. But the form bucket mixes an
owner question with a harness dialog (trust). The rule id is also only as stable as a
remote-updated manifest (`remote_update_result`, versioned `2026.09.11.1`).

**A truly structural signal is possible but not installed.** [measured on the herdr side,
doc-read on the Claude side]
- herdr accepts per-pane metadata from any reporter. `herdr pane report-metadata <pane> --source
  probe:test --agent claude --token dialog=permission --ttl-ms 60000` made `agent get` return
  `"tokens": {"dialog": "permission"}`, and `--clear-token dialog` removed it [measured].
- `pane report-agent --state blocked --message …` exists too [doc-read, CLI help].
- The Claude Code 2.1.281 binary contains the hook and notification names `PermissionRequest`,
  `PermissionDenied`, `permission_prompt`, `idle_prompt` and `elicitation_dialog` (a strings match
  in the binary, not a behavioural test).
- A coordinator-owned hook on `PermissionRequest` that posts a `dialog=permission` token (and
  clears it on the next `PreToolUse`/`PostToolUse`/`PermissionDenied`) would give a
  hook-sourced, non-text discriminator. That hook is **not built or tested** here.

## Can input land in a dialog?

| Path | While a dialog is open | Evidence |
|---|---|---|
| `agent prompt <t> <text>` (with or without `--wait`) | **Refused before any byte is sent**: `{"error":{"code":"agent_blocked","message":"agent probe is blocked and requires interactive input"}}`, exit 1 | [measured], twice on a Bash dialog and once on the `AskUserQuestion` form; matches the skill's "rejects an agent already waiting at an approval or question dialog with `agent_blocked` before sending any input" [doc-read] |
| `agent send-keys <t> esc` | **Delivered.** Cancelled the dialog (`Interrupted · What should Claude do instead?`) | [measured] |
| `agent send-keys <t> 4` | **Delivered.** Selected option 4 "No" with no Enter | [measured]. By the same mechanism, `1` would approve |
| `pane send-text <pane> "4"` | **Delivered.** Selected "No" with no Enter; no file was created | [measured]. By the same mechanism, `"1"` would approve |

**The guard is a race, not a lock.** [inferred from the measurements] `agent prompt` checks the
status at submission. A dialog that renders in the ~1.5 s after a check that read `idle`/`working`
is not covered, and nothing stops `send-keys` or `pane send-text` at all. The only refusal is on
`agent prompt`.

## What herdr's own agent skill says about a blocked approval

[doc-read, `herdr --skill`, verbatim]

- On `agent prompt`: "It rejects an agent already waiting at an approval or question dialog with
  `agent_blocked` before sending any input. **Inspect the blocked UI and ask the user before
  answering it.**"
- "`blocked` means Herdr recognized an approval or question UI." The skill itself groups approvals
  and questions under one status.
- "If a wait fails or returns `blocked`, inspect `agent get` and `agent read` before deciding what
  input to send."
- "Use logical keys for interactive agent UI controls: `herdr agent send-keys reviewer esc`." That
  is the path the skill offers for answering such UI.

So herdr's own guidance is "ask the user" for *both* approvals and questions. It gives no rule for
telling them apart.

## Event surface that could replace polling

[measured + doc-read]

- **The API has one.** `events.subscribe` over the Unix socket (`$HERDR_SOCKET_PATH`,
  newline-delimited JSON; request `{"method":"events.subscribe","params":{"subscriptions":[{"type":"pane.agent_status_changed","pane_id":"wA:pA"}]}}`)
  streamed every transition in the probe. Examples:
  - `{"data":{"agent":"claude","agent_status":"blocked","pane_id":"wA:pA","workspace_id":"wA"},"event":"pane.agent_status_changed"}`
  - `pane_agent_detected` at launch
  - `pane_closed` on close

  The CLI's own `agent wait` returned 0.09 s after the matching event. So the stream is at least as
  fast as the wait, because both sit behind the same detector.
- **No CLI verb exposes it.** `herdr api` offers only `snapshot` and `schema`. A subscriber is a
  small script on the socket, and it must run unsandboxed.
- **Other subscription types** [doc-read, schema]: `pane.output_matched` (literal or regex on a read
  source, with `lines` and `strip_ansi`), `pane.exited`, `pane.closed`, `pane.agent_detected`.
  `events.wait` is a one-shot matcher with `timeout_ms`.
- **Limit:** the stream carries only herdr's text-derived `agent_status`. It has the same blind
  spots as `agent get`: 2b and 3a read as stops, and a form is not told apart from a permission
  dialog. It replaces the *latency* of polling, not the *judgment*.
- A first subscribe on a pane that had just died returned
  `{"error":{"code":"pane_not_found",…}}` and closed the stream. A subscriber must handle that and
  resubscribe after the pane closes.

## Recommended polling contract

This is for a coordinator driving one fresh Claude Code session per pane, answering only chat
questions. The intervals are from the latencies above. The predicates are listed in the order the
coordinator evaluates them.

1. **Submit** with `agent prompt <t> <text> --wait --timeout <T>`, never a bare prompt followed by a
   separate `wait`. That avoids the level-triggered race. Treat `agent_blocked` on submit as state D
   below. Treat `timeout` / `agent_prompt_stalled` as "delivery unknown": read, don't resend (skill).
2. **Watch** with an `events.subscribe` stream on `pane.agent_status_changed` if a subscriber
   script is available. Otherwise poll `agent get` every **5 s** (a dialog appears about 1.5 s into
   a turn, and a 5 s tick costs nothing).
   - **Never use `--until idle` alone.** A finished turn parks at `done` until someone views it.
   - If a wait is used, it is `--until idle --until done --until blocked` with a timeout of at most
     **30 s**, looped.
3. **Classify on every `blocked`**, and on every `idle`/`done`:
   - **D, dialog, the owner's:** `agent_status == "blocked"`. The coordinator sends nothing to the
     pane, no `send-keys` and no `pane send-text`, and notifies the owner. Mixed cases fall on the
     owner's side:
     - `explain` rule `live_blocked_form` whose read shows `☐` and `Chat about this` is an
       `AskUserQuestion` form, which is an owner question. The coordinator may answer it only
       through a non-pane channel, or leave it to the owner.
     - Never infer "it's only a question" from text in order to press a key.
   - **B, busy in the background, not a stop:** `idle`/`done`, and the last ~15 lines
     (`agent read --source recent-unwrapped --lines 40`) contain `shell still running`, a footer
     `· N shell`, `Waiting for N background agent`, or `MCP tasks still running`. Keep watching. The
     session can wake itself, or raise a subagent's dialog (1b).
   - **Q, turn ended:** `idle`/`done`, rule `live_prompt_box`, and none of B's markers. Only now is
     the pane's last assistant message read as a possible chat question. Strip dimmed text: read
     with `--format ansi` and drop `ESC[2m` runs, or ignore the `❯` line entirely.
   - **W:** `working`. Keep watching.
4. **Debounce:** require the same classification on two consecutive reads **2 s** apart before
   acting on Q. That absorbs the 0.3 s `blocked→idle` flashes and a turn that restarts on a
   background completion.
5. **Answer:** only through `agent prompt`, whose `agent_blocked` refusal is the one herdr-side
   guard, and never through `send-keys` / `pane send-text` once the session is running. The residual
   race between the check and a dialog rendering is not closed by herdr. Closing it needs the
   hook-sourced token above, or a Claude-side `PermissionRequest` hook that refuses or holds
   pane input.

## Open questions

- **Run 1's `idle` during a background-agent wait.** The probe read `working` (title spinner,
  `Waiting for 1 background agent to finish`). Test run 1 on #81 saw `idle`. Two candidate causes:
  - a different Claude Code version, manifest version or screen layout (the
    `background_agents_working` rule needs that line to be the last non-empty line above the prompt
    box);
  - the `done`-versus-`idle` wait semantics misread as status.

  This needs a longer background-agent run to settle.
- **Is a hook-sourced dialog token reliable?** It needs a `PermissionRequest` hook in a scratch
  session posting `report-metadata --token`, measured for ordering against the screen rule and for
  clearing on every exit path (approve, deny, Esc, subagent dialog).
- **Can anything make herdr refuse `send-keys` while `blocked`?** No flag was found in the CLI help
  or the schema [doc-read]. A coordinator discipline or a wrapper would have to supply it.
- **Does `generic_permission_prompt` cover MCP and file-edit permission dialogs** as well as Bash?
  Only Bash dialogs were provoked. The trust dialog showed that not every harness dialog lands in a
  `*_permission_prompt` rule.
- **Probe hygiene note:** the first scratch pane's shell exited by itself 9 s after the split (exit
  0, before any agent started). The folder-trust dialog on the second pane was dismissed from a TUI
  client 1.6 s before the probe's own prompt, so the probe's prompt never reached that dialog
  (event timeline: `blocked` at +0 s, `idle` at +9.4 s, prompt submitted at +11 s). A human-attended
  herdr session can change pane state under a coordinator. Every probe decision here was re-read
  after the fact.
