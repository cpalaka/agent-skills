## Godot toolchain on this host

- **Run `tests/run_tests.sh` inside the sandbox** — it needs no bypass; its captures go under
  `$TMPDIR`, which the sandbox permits.
- **`.mcp.json` lists godot-mcp and minimal-godot only.** The godot-ai stdio entry lives at USER
  scope in `~/.claude.json`, with its ports hardcoded there — if the dock walks to another port,
  re-run the dock's client setup rather than editing that file by hand, and apply the same fix to
  every other host (contract, § godot-ai addon).
- **`godot-export-verifier`** (`.claude/agents/`) is the export smoke-tester the contract's `build`
  knob names — dispatch it with the `Agent` tool.
- **The four Godot skills the contract names** — `godot-gdscript-patterns`,
  `godot-animation-tree-mastery`, `godot-gotchas`, `godot-personal-preferences` — auto-load on their
  own contexts in this host, so there is no invocation rule to follow for them here.
