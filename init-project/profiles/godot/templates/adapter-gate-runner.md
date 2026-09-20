## Godot commands here

- **The steps the contract's `env` knob marks unsandboxed run with the Bash tool's sandbox dropped
  on that call** (`dangerouslyDisableSandbox`), never by changing the session's permission profile.
  Read the knob for which steps those are and why; take neither more nor fewer. A Godot gate run
  sandboxed does not merely fail, it lies (godot-gotchas #88). Gates that are not Godot commands —
  a Python suite, a `git grep` secret scan — stay sandboxed.
- **The stamped gotcha scan runs unsandboxed too, for a different reason.** Sandboxed,
  `tools/agent/godot-gotchas-scan.sh` is denied the temp file each check writes, so those checks
  are counted `skipped` and it reports `VERDICT: CLEAN` off the handful that ran — it fails open
  rather than failing. Quote its `N of M checks executed` line beside the verdict, always: that
  count is the only thing on stdout separating a real clean from a fail-open one.
  **Read it against the fail-open floor, not against `M`.** `N < M` is ordinary and not a failure —
  a check whose files are out of scope counts as a skip, so an honest `--all` run is short of its
  total. A denied heredoc instead kills every check that matches files against a scope, so the
  failure signature is `N` **at the floor**. For an `--all` scope:
  `M - N <= 1` is the PASS, `N <= 2` is `NOT RUN` whatever the verdict says, and an `N` between the
  two is `NOT RUN` for the coordinator to adjudicate (`N == M` was the bar until three false reds
  measured it out). A diff scope cannot use the count at all, most checks legitimately skipping
  there: quote both lines and leave that verdict to the coordinator.
- **A cooperative lock is a wait, not a race.** A headless Godot run and an open editor share the
  project lock, so a gate's tool may take one of its own. When a lock wait times out, report that
  gate `NOT RUN` with the tool's own message as the verdict line. Kill nothing, and start nothing
  that would take the lock from another session.
