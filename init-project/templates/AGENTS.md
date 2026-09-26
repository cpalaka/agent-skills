# {{PROJECT_NAME}} — the Codex adapter

**Read these completely, before any work.** Codex expands no import directives, so this list is the
mechanism, not a convenience:

1. `CONTEXT.md` — the project's domain glossary, where the repo root carries one. Use its exact
   terms.
2. `docs/agents/project-workflow.md` — **the shared project contract**: every project rule, the knob
   blocks, the verify gate, and the process this repo runs on. The same file `CLAUDE.md` loads:
   project rules live there once, host mechanics here.
3. {{CHUNK_READ_LIST}}

Read those chunk files by those names. **Do not read `dev-base.md` instead** — it is a bundle of
import lines for the other host, not a chunk, and carries none of their content. Where a chunk says
`~/.claude/chunks/<name>`, resolve it as `~/.codex/chunks/<name>`.

## Skills

Spelling on this host is `$name` — `$to-spec`, not `/to-spec`.

- **Explicit-only skills are invoked by name.** The list below says *which* ones this project uses
  on this host; the global `~/.codex/AGENTS.md` routing table says *when* each one fires. Read that
  table for the triggers — this file does not repeat them.
- *<Fill at init: the git-flow fork and the other explicit-only skills this project uses on this
  host, as `$name`, plus any project-specific trigger the global routing table does not already
  cover.>*
- **A skill that fires from context on the other host does not fire here.** Where the contract names
  a skill to read when you touch the work it covers, read it explicitly, by name, yourself.
- **Invoke a skill when it holds knowledge you don't** — project gotchas, tool quirks, a procedure
  with a known failure mode — never to be told how to work. Its description naming your
  situation is the signal; weigh the read against what you'd otherwise get wrong.

## MCP

- The project-scope MCP config for this host is `.codex/config.toml` — **gitignored, absolute paths,
  and it may not exist in your checkout yet**. Re-create it per clone, as the other host does its own
  gitignored settings file. While it is absent this repo's project-scope servers are not
  connected; say so rather than reporting them failed.
- **Two reasons you may see no project servers, and neither reports an error.** That file is
  missing, or **this repo has no `[projects."<absolute path>"] trust_level = "trusted"` entry in
  `~/.codex/config.toml`** — without it the project file is not loaded at all. Answering the
  directory-trust prompt on first launch writes that entry; a `-c` override does not. Check both,
  and read `$codex-sandbox-and-approvals` for the measurements, before calling a server broken.
- MCP servers connect **at session start** — nothing re-reads a config change mid-session; start a
  new session.

## Sandbox, approvals, git gates

- Expected profile in this repo: sandbox `workspace-write`, approval policy `on-request`. The repo
  is trusted because you answered the directory-trust prompt on first launch here.
- **The `codex-sandbox-and-approvals` Skill is the shape** — read it rather than expecting the
  other host's settings file to exist. The profile that binds you is the one above.
- **The human git gates bind whatever the approval policy allows.** `git-confirm-destructive`
  names what stops and asks a human; a tracker Chunk in the read list above may narrow its `gh`
  writes. What the approval mode or the sandbox would let through is not permission to run it, and
  never a sign-off.

## Child agents

- **One writer per repository main.** A child works its own worktree (the prefix is the contract's
  `parallel-work` knob); the coordinator is the only seat that merges and runs the gates.
- **A child may not merge or run the gates**, whatever its sandbox permits. Role-file mechanics —
  inheritance, disabling a server, when a role file is read — are in the
  `codex-sandbox-and-approvals` Skill; personal roles live in `~/.codex/agents/`.

<!-- profile:codex-mechanics -->

Canary: parity-adapter-v1 loaded
