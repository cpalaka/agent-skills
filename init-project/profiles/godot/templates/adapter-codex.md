## Godot toolchain on this host

- **The expected content of `.codex/config.toml` is the block in `docs/godot-mcp-guide.md`
  § Host adapters** — copy it in at the clone root and replace the placeholder with this clone's
  absolute path. A wrong or unreplaced path fails silently, because the entries are
  `required = false`.
- **godot-ai is not in that file.** It is registered at USER scope in `~/.codex/config.toml`, with
  its ports hardcoded there — see the contract's godot-ai section, including the rule that a port fix
  is applied to every host's user-scope config.
- **Read the four Godot skills explicitly**, by name, when you touch the work they cover:
  `$godot-gdscript-patterns` (GDScript), `$godot-animation-tree-mastery` (AnimationTree),
  `$godot-gotchas` (engine/editor quirks — before hand-editing a `.tscn`/`.tres`, before a risky
  editor operation, and before any commit), `$godot-personal-preferences` (workflow rules — at
  session start). They fire from context on the other host; here nothing loads them for you.
- **The `build` step's export smoke-tester has no Codex dispatch yet.** Until one exists, run exports
  from a Claude Code session or by hand, and say which of the two you did.
- **One writer per editor instance**, and the godot-mcp bridge accepts **one client**: a second
  editor — on a worktree, say — is a second independent writer, and any other session already
  holding the bridge blocks your reads through it. Say which it was rather than reporting the server
  as failed.
