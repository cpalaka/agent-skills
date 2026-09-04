## Godot toolchain on this host

- **The expected content of `.codex/config.toml` is the block in `docs/godot-mcp-guide.md`
  § Host adapters** — copy it in at the clone root and replace the placeholder with this clone's
  absolute path. A wrong or unreplaced path fails silently, because the entries are
  `required = false`.
- **godot-ai is not in that file.** It is registered at USER scope in `~/.codex/config.toml`, with
  its ports hardcoded there — see the contract's godot-ai section, including the rule that a port fix
  is applied to every host's user-scope config.
- **The four Godot skills the contract names, and when each one fires here:**
  `$godot-gdscript-patterns` on GDScript work, `$godot-animation-tree-mastery` on AnimationTree work,
  `$godot-gotchas` before hand-editing a `.tscn`/`.tres`, before a risky editor operation, and before
  any commit, `$godot-personal-preferences` at session start.
- **The `build` step's export smoke-tester has no Codex dispatch yet.** Until one exists, run exports
  from a Claude Code session or by hand, and say which of the two you did.
- **One writer per editor instance**, and the godot-mcp bridge accepts **one client**: a session
  already holding the bridge blocks this session's reads through it, which reads as a dead server
  and is not one. Report that it is held, not that it failed.
