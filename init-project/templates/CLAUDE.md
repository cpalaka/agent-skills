# {{PROJECT_NAME}} — the Claude Code adapter

This file guides Claude Code (claude.ai/code) in this repository. It is a **thin host adapter**:
**every project rule lives in `docs/agents/project-workflow.md`**, the one shared contract this repo
keeps for all agent hosts (`AGENTS.md` is the Codex adapter over the same file). Dev-process rules
come from the shared Chunk library, delivered via `~/.claude/chunks` — edit a rule THERE, not here.
What stays in this file is Claude Code mechanics and nothing else.

{{IMPORT_LINES}}

## Claude Code mechanics (this host only)

- **Session baseline:** sandbox on, `permissions.defaultMode: auto`, in gitignored
  `.claude/settings.local.json`, which no clone or worktree carries; shape and recovery: the
  `sandbox-and-permissions` Skill.
- **MCP registration:** `.mcp.json` (project) and `~/.claude.json` (user) take effect only on
  **restart**.
- **Project-local subagents:** `.claude/agents/`, via the `Agent` tool.
- **Skills fire from context here, spelled `/name`** — the contract drops the prefix. One it names
  for work you touch fires; anything else you invoke. This project's git-flow fork is *<`/name`,
  filled at init>*. **Invoke a skill when it holds knowledge you don't** — project gotchas, tool
  quirks, a procedure with a known failure mode — never to be told how to work. Its description
  naming your situation is the signal; weigh the read against what you'd otherwise get wrong.

<!-- profile:claude-mechanics -->
