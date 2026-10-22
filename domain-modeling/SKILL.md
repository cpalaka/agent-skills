---
name: domain-modeling
description: Keep a project's domain language and decisions written down. Use when a term is coined, contested or used two ways, when creating or refreshing CONTEXT.md, when a decision passes the three-gate ADR test (hard to reverse, surprising without context, a real trade-off), or when asked whether the glossary is current.
---

# Domain modeling

`CONTEXT.md` is the project's glossary: the words it uses and the words it has decided against.
`docs/adr/` holds the decisions a reader would otherwise reverse by accident. Both are created
lazily and written the moment a thing resolves, never batched for session end. Formats:
[`CONTEXT-FORMAT.md`](CONTEXT-FORMAT.md) and [`ADR-FORMAT.md`](ADR-FORMAT.md); a root
`CONTEXT-MAP.md` means several contexts and names where each glossary lives.

## While designing

- A term that conflicts with the glossary is called out in the same turn: "`CONTEXT.md` defines
  X as A; you mean B. Which?"
- An overloaded word gets one canonical term; the others go under `_Avoid_`.
- A relationship between concepts is stress-tested with a concrete edge case before it is written.
- A claim about how the code works is checked against the code, and a contradiction surfaced.

## The glossary-only gate, per entry

An entry is a one-sentence noun definition of what the thing IS: no file path, identifier, port,
count, algorithm or flow narration, which belong in the design doc the entry points to. `_Avoid_`
lists real in-repo collisions with the reason in parentheses, never obvious near-words. Inherited
vocabulary (HTTP, MCP, Resource) enters only where this project overloads it. The test: would a
competent domain developer be confused without this entry?

## Refreshing

Scope from git, never by rereading the repo: `git log -1 --format=%H -- CONTEXT.md` is the
baseline, `git diff --name-only <base>..HEAD` plus `git status --porcelain` the change set; an
empty baseline means scope by exploration. Read `docs/` before coining a label the project may
already have named. Scoping is done when every changed source file is mapped to a term or
dismissed as noise. No source changes ends the refresh: report the glossary current, with the
diff as proof.

## Decisions

An ADR is offered, never written unasked, when all three hold: hard to reverse, surprising
without context, a real trade-off. One paragraph: context, decision, why. A reversed decision
gets a new ADR naming the sentences it supersedes and the old one a `Status: superseded by NNNN`
line; its text stays as written.

## Wiring

The repo's `AGENTS.md` names `CONTEXT.md` and `docs/adr/` in one line; add it when missing.
