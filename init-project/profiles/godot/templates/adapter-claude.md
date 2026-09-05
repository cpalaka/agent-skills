## Godot toolchain on this host

<!-- requires: tests/run_tests.sh states: captures are written under $TMPDIR when it is set -->
- **Run `tests/run_tests.sh` inside the sandbox** — it needs no bypass; its captures go under
  `$TMPDIR`, which the sandbox permits.
<!-- requires: .mcp.json states: the servers are godot-mcp and godot (minimal-godot) and there is no godot-ai entry; contract § godot-ai addon; contract states: the dock registers godot-ai at user scope; contract states: a port fix is applied to every host's user-scope config -->
- **`.mcp.json` lists godot-mcp and minimal-godot only.** The godot-ai stdio entry lives at USER
  scope in `~/.claude.json`, with its ports hardcoded there — if the dock walks to another port,
  re-run the dock's client setup rather than editing that file by hand, and apply the same fix to
  every other host (contract, § godot-ai addon).
<!-- requires: .claude/agents/godot-export-verifier.md; contract knob build names godot-export-verifier -->
- **`godot-export-verifier`** (`.claude/agents/`) is the export smoke-tester the contract's `build`
  knob names — dispatch it with the `Agent` tool.
<!-- requires: contract names godot-gdscript-patterns, godot-animation-tree-mastery, godot-gotchas, godot-personal-preferences -->
- **The four Godot skills the contract names** are `godot-gdscript-patterns`,
  `godot-animation-tree-mastery`, `godot-gotchas` and `godot-personal-preferences`.
