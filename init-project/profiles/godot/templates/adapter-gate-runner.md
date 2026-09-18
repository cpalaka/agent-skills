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
  `N of M checks executed` line beside its verdict, always — a `CLEAN` with fewer checks executed
  than the scan names is `NOT RUN`, never a `PASS`.
- **A cooperative lock is a wait, not a race.** A headless Godot run and an open editor share the
  project lock, so a gate's tool may take one of its own. When a lock wait times out, report that
  gate `NOT RUN` with the tool's own message as the verdict line. Kill nothing, and start nothing
  that would take the lock from another session.
