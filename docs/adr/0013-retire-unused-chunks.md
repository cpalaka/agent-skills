# Three Chunks retire on a zero-importer measurement; the git-flow fork keeps one side

**Status:** accepted — 2026-09-19. Supersedes [ADR 0002](0002-git-flow-structural-fork.md) on the
two-variant structure only.

A Chunk costs nothing to keep and nothing warns when it stops being read, so the library
accumulates files no project imports. An import sweep (2026-09-19) over every `CLAUDE.md` and
`AGENTS.md` under the three project roots on this machine found three:

- **`git-flow-noff`** — **zero importers.** All ten chunk-library projects import
  `git-flow-squash`. The opt-in fork ADR 0002 created was never once opted into.
- **`code-hygiene`** — **zero importers** since it left the `dev-base` bundle on 2026-08-08. Its
  four rules are standard practice a current model already follows, and the one enforcement that
  mattered — the repo-root secret scan — is a `verify-gate` step.
- **`codegraph`** — **one importer**, in a repository outside this one, which re-points it as its
  own follow-up.

**The sweep's scope, stated rather than glossed:** `CLAUDE.md` and `AGENTS.md` only, under three
roots, on one machine. The private companion repo ([ADR 0008](0008-public-private-split-by-audience.md))
and the second machine were not searched. The owner accepted that scope; a later importer found
there restores the file from history rather than invalidating this decision.

**Decision.** Delete the three files and update every live reference. `git-flow-squash` becomes the
only git-flow Chunk. `fork:` stays a manifest key with one value, because a manifest that names its
integration model is how a second one would ever arrive.

**ADR 0002 is superseded on the two-variant side and stands everywhere else.** What retires is the
structure — two variant Chunks a project imports exactly one of — and the cross-ship defences that
existed to police it. What survives, and still governs `git-flow-squash`: **three rules ride the
fork together** (merge model, branch-name prefix, notes-SHA policy), and **the notes-SHA policy is
chosen per merge model rather than derived from it**, which is why it lives in the fork file while
`backlog-core` stays merge-agnostic and defers to it. 0002's body is not edited — it records what
was decided in August and why, and rewriting it to match today destroys the record.

**Considered options.**

- **(a) Keep `git-flow-noff` parked in case a merge-commit project appears.** Rejected: a file
  nobody reads goes wrong silently. 0002's original claim that `--no-ff` produces a merge SHA at
  Done-marking time was false and survived until ticket 16 caught it (amended 2026-09-05). An
  unread fork is not a spare part, it is a wrong answer waiting for its first reader.
- **(b) Fold `git-flow-squash`'s rules into `dev-base` now that nothing forks.** Rejected:
  `@import` cannot be undone, so a bundled integration model cannot be dropped by the project that
  wants a different one. That is the reason the fork was ever a separate file, and it outlives the
  second variant.
- **(c) Delete, and recover from history if the need returns.** Chosen. A retired Chunk needs no
  symlink surgery — both hosts link the whole `chunks/` directory, not one entry per file — so the
  cost of reversing this is one `git show`.

**Consequences.**

- `git-flow-squash` sheds the sentences that existed only to keep the variants from cross-shipping.
  Its **(a)**/**(b)**/**(c)**/**(d)** labels are unchanged, in the same order, each carrying the
  rule it carried before: another repository cites `§ (a)` and `§ (d)`, and `verify-gate` cites
  `(a)`.
- `dev-base`'s header describes the library as it is, not as a history of departures. Two Chunks
  stay out of the bundle — the git-flow fork and the tracker chunk — and the manifest selects both.
- **Recovery is `git show ccb249c:chunks/git-flow-noff.md`** (likewise `code-hygiene.md`,
  `codegraph.md`). A merge-commit project restores the file and adds the manifest value; it does
  not re-derive the rules from scratch.
- `README.md`'s Chunk table is derived from `chunks/`, so it re-derives to twelve rows.
- **Two of `code-hygiene`'s four rules now live nowhere in `chunks/`**, by owner decision on
  2026-09-19 after reading all four: **no debug logging left in production code**, because that
  failure is visible in the diff and in review rather than silent, which is the bar the rest of
  the library is held to; and **ask-when-unsure over small reversible steps**, because
  `git-confirm-destructive` already owns the destructive half and `dev-practice` the
  route-the-planning-method half, and what remained had no observable attached. No project loses
  either, because none imported the file.
- **The other two were rehomed rather than dropped.** The secrets rule lives in `verify-gate`'s
  **secret-scan** step, which carries the environment-specific paths/hosts/IPs clause too. **No
  undeclared top-level dependencies** is now a standalone rule in `verify-gate`, outside the
  numbered sequence so the invariant stays five steps: it was kept because its failure *is* silent
  in the way the library exists to catch — an implicit or local-only install passes every gate on
  the machine that installed it and breaks on a clean clone.
