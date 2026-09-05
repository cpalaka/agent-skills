# {{PROJECT_NAME}} — the Claude Code adapter

This file guides Claude Code (claude.ai/code) in this repository. It is a **thin host adapter**:
**every project rule lives in `docs/agents/project-workflow.md`**, the one shared contract this repo
keeps for all agent hosts (`AGENTS.md` is the Codex adapter over the same file). Dev-process rules
come from the shared Chunk library, delivered via `~/.claude/chunks` — edit a rule THERE, not here.
What stays in this file is Claude Code mechanics and nothing else.

{{IMPORT_LINES}}

## Claude Code mechanics (this host only)

- **Session baseline:** sandbox on, `permissions.defaultMode: auto`, both in
  `.claude/settings.local.json` (gitignored, so it does not travel with a clone or a worktree).
  Shape and recovery: the `sandbox-auto` chunk.
- **MCP registration:** `.mcp.json` is this adapter's project-scope MCP config. It takes effect only
  after a Claude Code **restart**; so does any change to the user-scope `~/.claude.json`.
<!-- requires: .claude/agents -->
- **Project-local subagents live in `.claude/agents/`** — dispatch them with the `Agent` tool.
- **Skills fire from context here.** Where the contract names a skill to read when you touch the
  work it covers, this host loads it on its own; everything else is invoked explicitly.
- **Skill and command spelling on this host is `/name`** (`/refresh-context`, `/implement`, …). The
  contract names skills without a prefix; add the slash here.

<!-- profile:claude-mechanics -->
