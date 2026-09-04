# Domain model

Host-neutral pointer file: where this project's domain model lives and how to use it. It holds no
copy of the model — the files below are authoritative.

- **`CONTEXT.md`** (repo root) — the **vocabulary**. A pinned glossary: each term with what it IS,
  plus an `_Avoid_` line naming the synonyms that are wrong here. Maintained by the
  `godot-architecture-review` skill.
- **`docs/adr/`** — the **decisions**. One numbered file per load-bearing choice, kept lazily: a
  decision earns an ADR when it constrains future work.
- *<Fill at init, where the project keeps one: the **design source** — the single doc every design
  or build decision is read out of, and the rule for editing it (edited in place, never appended to
  with a superseding design). Name the ADR that pins it. Where the project has none, say so here in
  one line rather than naming a path that does not exist — an invented design source is worse than
  an admitted absence.>*

How to use it:

- **Read `CONTEXT.md` before naming anything** — a class, a node, a signal, a file, a ticket title, a
  commit subject. Use its exact terms; the `_Avoid_` synonyms are not stylistic preferences, they are
  the names this project decided against.
- **Read it again before renaming anything.** A rename that ignores the glossary re-introduces a term
  the project already retired, and nothing in the toolchain flags that.
- **New domain language is a doc change, not a code comment.** If a slice introduces a term the
  glossary does not carry, add it to `CONTEXT.md` in the same change (the `domain-modeling` skill has
  the format and the three-gate test for whether the decision behind it also earns an ADR).
- Before minting a numbered ADR file, follow the `backlog-core` chunk's rule for hand-numbered
  sequences — it owns the max+1 hazard and the renumbering call.
