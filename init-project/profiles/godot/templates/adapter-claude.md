## Godot toolchain on this host

- **`tests/run_tests.sh` runs inside the sandbox only while it stays as scaffolded.** Its captures
  go under `$TMPDIR`, which the sandbox permits, and its fatal grep is `^SCRIPT ERROR` alone. Two
  things end that: a tree with a `.blend` (Blender crashes at GPU detection inside the sandbox,
  godot-gotchas #47), or tightening the grep to `^ERROR:` — sandboxed, Godot is denied `user://logs`
  and the CA store and prints `ERROR:` for each, so a green suite reads as red (#88). Past either
  point, escalate **per command** with the Bash tool's sandbox-off option, never by changing the
  session's permission profile.
- **`.mcp.json` lists godot-mcp and minimal-godot only.** The godot-ai stdio entry lives at USER
  scope in `~/.claude.json`, with its ports hardcoded there — if the dock walks to another port,
  re-run the dock's client setup rather than editing that file by hand, and apply the same fix to
  every other host (contract, § godot-ai addon).
- **`godot-export-verifier`** (`.claude/agents/`) is the export smoke-tester the contract's `build`
  knob names — dispatch it with the `Agent` tool.
- **The four Godot skills the contract names** are `godot-gdscript-patterns`,
  `godot-animation-tree-mastery`, `godot-gotchas` and `godot-personal-preferences`.
