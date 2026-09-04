# {{PROJECT_NAME}} — the shared project contract

This is the one shared project contract: every rule that is true of this repo whatever agent host
you are running in. It is read by `CLAUDE.md` (the Claude Code adapter) and by `AGENTS.md` (the
Codex adapter). **Project rules live here, once. Host mechanics — invocation spelling, sandbox and
approval settings, MCP registration, child-agent shape, restart semantics — live in the adapter
that consumes them.** Where a rule here says "your host adapter says how", the verb is in that
file, not this one.

Dev-process rules are not here either: they come from the shared Chunk library, delivered as
`~/.claude/chunks` and `~/.codex/chunks` — edit a rule THERE, not here, and the edit reaches every
project. The knob blocks below are what those Chunks read out of this file, by marker.

{{KNOB_BLOCKS}}

## Project

*<Fill at init: 1–2 sentences on what this project actually IS — what it does, who runs it, what
makes it distinctive. This is the highest-value line in the file; never leave it generic.>*

## Working in this repo

*<Fill at init: the project rules that are true on every host — the domain-vocabulary pointer, the
docs to read before touching a given surface, the conventions the toolchain does not enforce. Host
mechanics do not belong here; name the behaviour and say "your host adapter says how".>*

## Running

*<Fill at init: how to run this project and its test suite, and what a trustworthy verdict looks
like. Include the fresh-clone rehydrate steps a checkout needs before any of it works.>*

<!-- profile:contract-sections -->
