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

**Every session on both hosts loads this file whole.**

Before a line enters the contract, answer three questions, one sentence each, on the record:

1. **Who reads it?** The coordinator, an implementer seat, the gate-runner, a host adapter, a
   human.
2. **At what moment — and is the contract the narrowest carrier guaranteed loaded then?** A rule
   that fires only inside a slash-only Skill belongs in that Skill, which is always explicitly
   loaded. A rule that fires on a commit or a branch start belongs in a Chunk. A rule true of one
   host belongs in that host's adapter. The contract earns a rule only when the moment it fires
   can arrive in any session, unannounced.
3. **Would they act differently without it?** Where the tool already prints it, refuses it or
   enforces it, the sentence is a second copy of a verdict the reader already holds.

Question 3 is the one that deletes rather than shortens, and it has a precondition: **read the
tool's source before writing prose about how the tool behaves.** A procedure someone performed
once can outlive its reason, or never have had one. A doc instructing a reader to redo what the
tool already did is worse than bloat: it is a false premise they will act on.

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
