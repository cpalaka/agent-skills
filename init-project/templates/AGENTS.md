# {{PROJECT_NAME}} — the Codex adapter

**Read these completely, before any work.** Codex expands no import directives, so this list is the
mechanism, not a convenience:

1. `CONTEXT.md` — the project's domain glossary, where the repo root carries one. Use its exact
   terms.
2. `docs/agents/project-workflow.md` — **the shared project contract**: every project rule, the knob
   blocks, the verify gate, and the process this repo runs on. It is the same file `CLAUDE.md`
   loads; project rules live there once, host mechanics live here.
3. {{CHUNK_READ_LIST}}

Read those chunk files by those names. **Do not read `dev-base.md` instead** — it is a bundle of
import lines for the other host, not a chunk, and reading it in their place loads none of their
content. Where a chunk says `~/.claude/chunks/<name>`, resolve it as `~/.codex/chunks/<name>`.

## Skills

Spelling on this host is `$name` — `$to-spec`, not `/to-spec`.

- **Explicit-only skills are invoked by name.** The list below says *which* ones this project uses
  on this host; the global `~/.codex/AGENTS.md` routing table says *when* each one fires. Read that
  table for the triggers — this file does not repeat them.
- *<Fill at init: the explicit-only skills this project uses on this host, as `$name`, plus any
  project-specific trigger the global routing table does not already cover.>*
- **A skill that fires from context on the other host does not fire here.** Where the contract names
  a skill to read when you touch the work it covers, read it explicitly, by name, yourself.

## MCP

- The project-scope MCP config for this host is `.codex/config.toml` — **gitignored, absolute paths,
  and it may not exist in your checkout yet**. Re-create it per clone the way the other host
  re-creates its own gitignored settings file. While it is absent this repo's project-scope servers
  are simply not connected; say so rather than reporting them as failed.
- **Two reasons you may see no project servers, and neither reports an error.** The file above is
  missing, or **this repo has no `[projects."<absolute path>"] trust_level = "trusted"` entry in
  `~/.codex/config.toml`** — without that entry the project file is not loaded at all, and
  `codex mcp list` from the repo root shows only the user-scope servers (measured 2026-09-03 on
  Codex 0.153.1). Answering the directory-trust prompt on first launch here is what writes it; a
  `-c` override on the command line does not substitute for it. Check both before concluding a
  server is broken.
- MCP servers connect **at session start**. After any config change, start a new session; nothing
  re-reads it mid-session.
<!-- requires: contract states: which MCP server writes and which only read -->
- Which server writes and which ones only read is in the contract, § Working in this repo. That
  division is not host-specific; only the tool-name prefix you see is.

## Sandbox, approvals, git gates

- Expected profile in this repo: sandbox `workspace-write`, approval policy `on-request`. The repo
  is trusted because you answered the directory-trust prompt on first launch here.
- **The `sandbox-auto` chunk's Host differences block is the shape** — read it there rather than
  expecting the other host's settings file to exist. The profile that binds you is the one above.
- **The human git gates bind whatever the approval policy allows.** Force-push, remote deletion and
  every `gh` write stop and ask a human — see `git-confirm-destructive`. An approval mode that would
  let a command through is not permission to run it, and a sandbox that permits an action is not a
  sign-off.

## Child agents

- **One writer per repository main.** A child works its own worktree (the prefix is the contract's
  `parallel-work` knob); the coordinator is the only seat that merges, runs the gates, and writes any
  board row but the child's own.
- **A child may not merge and may not run the gates**, whatever its sandbox permits. Role-file
  mechanics — what a child inherits, how a server is disabled, when a role file is read — are in the
  `parallel-work` chunk's Host differences block; personal roles live in `~/.codex/agents/`.

<!-- profile:codex-mechanics -->

Canary: parity-adapter-v1 loaded
