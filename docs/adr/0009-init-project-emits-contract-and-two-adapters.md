# `init-project` emits one shared contract and two thin host adapters

**Status:** accepted

A project's `CLAUDE.md` used to hold everything at once: the chunk `@import`s, the engine-written
knob blocks, and every project rule. That shape has exactly one host. Codex reads `AGENTS.md`,
expands no `@` imports, and fires no skill from context, so a second host either got nothing or got
a copy — and a copy of the project rules is a second source of truth that drifts the week it is
written.

**Decision.** Every Profile emits three files. `docs/agents/project-workflow.md` is the **shared
contract**: the engine's header, every knob block by marker, and the project sections. `CLAUDE.md`
and `AGENTS.md` are **thin host adapters** over it, carrying host mechanics only — invocation
spelling, sandbox and approval settings, MCP registration, child-agent shape, restart semantics —
and no project rule between them. **Knob blocks live in the contract**, which is what let the
value-variant chunks stop naming `CLAUDE.md` and start naming "the project contract file named by
your host adapter". The Claude adapter reaches the contract with `@docs/agents/project-workflow.md`,
an import rather than a prose pointer, so rules that were always-loaded stay always-loaded; the
Codex adapter names it in an explicit read list, per ADR 0005.

**Considered options:** (a) a per-host copy of the whole file — `CLAUDE.md` and `AGENTS.md` each
complete, kept in step by a parity check. Rejected: parity is for **Templates** a project edits
after delivery, and the project rules are exactly the content both hosts must agree on field by
field; a check that fires after the drift is a worse mechanism than not duplicating. (b) an import
bridge for Codex — teach it Claude's recursive `@path` syntax, or flatten the chunks into
`AGENTS.md` at stamp time. Rejected by ADR 0005 for the first and by ADR 0001 for the second: the
syntax is undefined on that host, so it would look configured and silently load nothing, and
flattening re-creates the per-project copies the Chunk library exists to remove.

**Consequences.**

- Existing projects need a **migrate mode**, not a re-init: their knob values are measured facts
  about that project, so the engine moves the blocks and refuses when one is missing rather than
  synthesising a value.
- The engine gains a **byte gate**. Codex's `project_doc_max_bytes` caps the auto-loaded pair — the
  repo's `AGENTS.md` plus `~/.codex/AGENTS.md` — and truncates past it with no error, so the stamp
  fails at 32 KiB rather than emitting a file whose tail is silently dropped. The chunk files the
  adapter names are tool-read, outside that cap, and are recorded but not gated.
- Because Codex reads those chunks only when told to (ADR 0005), the read list is derived and
  enumerated by name in `AGENTS.md`, with the warning that reading the `dev-base` bundle instead
  loads none of them.
