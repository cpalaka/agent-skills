## Godot commands here

- **The steps the contract's `env` knob marks unsandboxed run with the Bash tool's sandbox dropped
  on that call** (`dangerouslyDisableSandbox`), never by changing the session's permission profile.
  Read the knob for which steps those are and why; take neither more nor fewer. The shortcut is not
  available to you: sandboxed, Godot prints an `ERROR:` line for each thing it is denied
  (godot-gotchas #88), and a Godot gate's own grep counts those as failures — such a run does not
  merely fail, it lies. Gates that are not Godot commands — a Python suite, a `git grep` secret
  scan — stay sandboxed.
- **The stamped gotcha scan runs unsandboxed too, for a different reason.** Sandboxed,
  `tools/agent/godot-gotchas-scan.sh` is denied the temp file each of its checks writes, so the
  checks are counted `skipped` and it reports `VERDICT: CLEAN` off the handful that ran: it fails
  open rather than failing (measured on a stamped project, 2026-09-17). Quote the scan's
  `N of M checks executed` line beside its verdict, always — that count is the only thing on
  stdout separating a real clean from a fail-open one.
  **Read it against the fail-open floor, not against `M`.** `N < M` is the ordinary case and not a
  failure: a check whose files are not in scope returns early and is counted as a skip
  (`N_EXEC = N_RUN - N_SKIP`), so an honest `--all` run is routinely short of its total — a project
  with no `export_presets.cfg`, for instance, will never satisfy `N == M`. A denied heredoc instead
  kills every check that matches files against a scope, leaving only the handful that survive
  without matching, so the failure signature is `N` **at the floor**. For an `--all` scope:
  `M - N <= 1` is the PASS, `N <= 2` is `NOT RUN` whatever the verdict says, and an `N` between the
  two is `NOT RUN` for the coordinator to adjudicate. A diff scope cannot use the count at all —
  most checks legitimately skip there — so quote both lines and leave that verdict to the
  coordinator. (Earlier revisions of this fragment made `N == M` the bar; no honest run can meet
  it, and the false red recurred three times on one project before being measured out.)
- **A cooperative lock is a wait, not a race.** A headless Godot run and an open editor share the
  project lock, so a gate's tool may take one of its own. When a lock wait times out, report that
  gate `NOT RUN` with the tool's own message as the verdict line. Kill nothing, and start nothing
  that would take the lock from another session.
