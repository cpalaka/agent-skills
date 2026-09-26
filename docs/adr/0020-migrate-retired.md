# Migrate mode is retired; an engine Template asserts engine facts only

**Status:** accepted — 2026-09-25. Supersedes
[ADR 0010](0010-fragment-bullets-declare-their-targets.md) whole; amends
[ADR 0009](0009-init-project-emits-contract-and-two-adapters.md) in part.

`init-project` carried a second mode for moving a pre-contract project onto the contract layout.
Measured for spec #124: Migrate mode was 2,139 words, plus about 326 of `requires:` grammar, in a
7,473-word Skill, and it has not run since the four godot migrations that produced it. The
**fragment target check** it owned exists only for it: init writes every target a `requires:`
comment names and inserts every bullet, so the check has nothing to withhold there.

**Decision 1.** Migrate mode, the `requires:` grammar, the fragment target check and the eight
`<!-- requires: -->` comments are deleted (issue #125). A pre-contract layout — knob blocks or
project sections in `CLAUDE.md`, and no contract — is a stop. Three sentences Migrate carried
survive in the init steps they govern: never synthesise a knob value; a one-host `scripts/` path in
a knob value resolves on one host only; two bullets on one subject let a stale claim outlive its
correction.

**Decision 2. An engine Template asserts engine facts only** — a fact true of one Profile rides in
that Profile's fragment. The instance that surfaced it: the Codex adapter Template's MCP
writer/reader bullet moved into godot's Codex fragment, since only godot's contract states that
split and every `web` stamp inherited a pointer at nothing (#63).

**ADR 0010 is superseded whole**: its decision governed only Migrate. **ADR 0009 is amended in
part.** Its consequence "existing projects need a migrate mode" retires: a pre-contract project is
a stop, and moving one is the owner's hand work. Its byte-gate consequence reads "caps the
auto-loaded pair", but the gate is per file (measured 2026-09-04, `init-project` step 7), so the
pair wording is amended to per file. The bodies of 0009 and 0010 are not edited — they record what
was decided and why.

**Considered options.**

- **(a) Keep Migrate parked for the six pre-contract projects.** Rejected: an unread mode goes
  wrong silently, the reasoning of [ADR 0013](0013-retire-unused-chunks.md).
- **(b) Keep the `requires:` grammar for init.** Rejected: init writes every target, so the check
  can never fail there.
- **(c) Delete, and recover from history if the need returns.** Chosen.

**Consequences.**

- **Recovery is `git show 2e475dd:init-project/SKILL.md`** (likewise
  `init-project/profiles/backlog.md` and `init-project/templates/ADDING.md`).
- The private companion's godot parity check reads the `requires:` grammar and the migrate ledger;
  it gets a follow-up on the private companion's tracker.
- **Fragment target check** is marked retired in `CONTEXT.md`.

**Two stated gaps**, each owned by a later ticket of spec #124:

1. **A current-layout `backlog-core` importer is a stop at step 0**, kept at the owner's decision
   on issue #125: the engine has no held handling for a frozen tracker until the stamping script
   lands it (#126, #127), and without the stop a re-run would read no tracker held — adding a
   second tracker import, minting labels, and deleting the knob block the frozen Chunk still
   reads. Spec #124 § Out of Scope leaves those projects untouched either way.
2. Three surviving engine sentences (two in `init-project/SKILL.md` step 1's `AGENTS.md` bullet,
   one in `profiles/github.md` § B's closing paragraph) still say the Codex byte gate caps "the
   pair" against step 7's per-file gate. #127 corrects them; this ADR does not claim the
   engine already agrees.
