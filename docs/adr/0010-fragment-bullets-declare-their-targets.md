# Fragment bullets declare their targets; migrate withholds, never rewrites

**Status:** accepted

A Profile's adapter fragments (ADR 0009) were written for a fresh init, where every file, heading,
contract section and knob value they name exists because init just wrote it. Migrate mode inserts
the same fragments over a project whose contract is the moved `CLAUDE.md` and whose Templates are
skip-if-exists, so nothing the bullets presuppose is guaranteed. Four migrations produced the same
cluster of dangling pointers — a guide section the project's guide predates, a contract section the
project never had, a skill roster the contract does not name, a subagent the `build` knob does not
call — each one inserted with no error, read by every fresh session, and true nowhere.

**Decision.** A fragment bullet, or an engine Template bullet, may carry one `<!-- requires: -->`
comment naming what it presupposes, in four target families (a path, a heading in a file, a fact
about the emitted contract, a claim about a file's behaviour — the grammar is `init-project/SKILL.md`
§ What a Profile is). The comment is the Profile's: **every mode strips it on insertion.** Init
inserts every bullet, because it writes the targets. Migrate runs the **fragment target check**:
every target resolves against the tree as the run leaves it → the bullet goes in whole; any fails →
the bullet is **withheld whole** to the ledger with its Profile wording and the offered contract
section that would create the target. A withheld bullet is never rewritten and never replaced by a
placeholder — that would be authoring a claim about the project, which migrate may not do.

**Considered options:** (a) rewrite a failing bullet into a placeholder ("not present here").
Rejected: it is authoring, and an adapter line that says nothing is present is load a fresh session
pays on every launch. (b) let the engine infer what each bullet presupposes from its text. Rejected:
that is a guess per bullet per run, and the four migrations show the guesses were not made. (c)
host-neutral fragments that presuppose nothing. Rejected: the fragments are host-specific by nature —
which file registers a server on this host, how a subagent is dispatched here — and a bullet with no
presupposition is a bullet with no content.

**Consequences.**

- Every Profile with `adapters:` fragments annotates the bullets that presuppose something; a bullet
  with no comment is always inserted, so an unannotated presupposition is a defect in the Profile.
- Re-insertion is owned by the Profile's parity check (for godot, `audit-godot-parity` pair 9),
  which reads the ledger's withheld rows: migrate cannot re-run over its own output and init
  re-inserts nothing at a consumed marker.
- The engine Templates may carry comments too — the check treats a Template bullet and a fragment
  bullet alike.
