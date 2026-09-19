<!-- chunk:verify-gate | kind: value-variant | single-source: agent-skills/chunks/verify-gate.md -->
<!-- Delivered by Claude @import or a Codex AGENTS.md explicit read through the host's chunk symlink.
     Edit here only — no per-project copies, no parity. -->

## Verify gate (run before any commit or handoff)

Before committing, opening a handoff, or claiming work done, run this project's **verify gate**
and confirm it from *fresh* evidence: if you didn't run it in this turn, you can't claim it
passes. The gate is invariant; the exact commands are a knob.

**The sequence (run in order, all must pass).**

1. **typecheck** — the type/compile step.
2. **test** — the project's test suite.
3. **build** — a real production build, including any output/artifact sanity check the build is
   supposed to produce.
4. **smoke** — bring the app up, confirm the affected surface actually renders / responds, then
   bring it back down. A green build is not a working app.
5. **secret-scan** — grep the working tree for leaked credentials; expect **zero** matches before
   the change leaves your machine. Secrets are read from the environment or a secret manager at
   runtime, never written into source or committed config — and the same goes for
   environment-specific server paths, hosts and IPs, which resolve from config/DNS/SSH rather
   than literals.

The commands, the directory they run in, the build's output check, the secret-scan grep pattern
and any env are knobs: read them from the `<!-- knobs:verify-gate -->` block in the project
contract file named by your host adapter, never hardcode them here. That block may also carry
**further named gate lines after `secret-scan`** — part of the invariant, run in the order
listed, held to the same pass bar.

**Clean output, not just exit 0.** A run that exits 0 with new warnings or noise is **not** a
pass — investigate the warning.

**A new top-level dependency is declared, or the gate is lying.** It goes in the manifest *and*
the lockfile, and the change adding it says why, in the commit message or the handoff. An implicit
or local-only install passes every step above on the machine that installed it and breaks on a
clean clone — the first place nobody is watching. (Rehomed from the retired `code-hygiene`,
2026-09-19.)

**WHERE the gate runs is part of the gate.** A gate run in the tree that produced the artifacts
is blind to anything that only bites once a fresh checkout re-materializes them, and the
worktree's own run passes *honestly* while being wrong on main (measured 2026-07-17). So for any
gate over files git normalizes, generates or re-materializes (EOL/`text` attributes, filters,
LFS, generated assets, a byte-mirror directory), run it once from a **clean clone or a fresh
worktree of the commit**, not only from the tree you built in. And exempt byte-mirror directories
from normalization (`assets/** -text`) so the comparison has something stable to compare.

**WHICH gates you run is part of the gate too, and it is derived, not assumed.** A gate's name
says what it is *for*, never what it *reads*. So before dropping any gate from a round, grep for
what actually references the changed path and name the gate that loads it; a suite that loads a
file's *siblings* reads like coverage and is not, and a gate whose knob the project documents as
not seeing a class of defect does not cover that class however apt its name. Where no gate loads
the changed file, say so, and either add the one that does or record the coverage as inspection
rather than as a pass — and prefer running the full gate whenever the derivation would cost more
than the round. The tell: a comment-only edit scoped to four gates, where nothing under the test
tree loaded the edited file and the only two gates that did were the two the narrowing had
excluded (measured 2026-09-19). This is the `verification-discipline` absence-claim failure
wearing a scheduling costume.

**Tell a runner seat your narrowing reasoning, not just the resulting scope.** (`implement-run`
carries the general form, for every constrained seat.)

**Docs synced.** Before the commit, confirm the project's design docs (e.g. `CONTEXT.md`, ADRs,
any PRD/spec the project keeps) are updated for any new domain language or load-bearing decision
the change introduces. Synced docs are part of the gate, not a follow-up.

**Evidence kept is evidence something still READS.** A committed artifact proving a criterion — a
screenshot pair, a probe's output — earns its place in the repo only while something **other than
its own closed task** points at it: an open task, an ADR, a standing doc, a sibling row that cites
it by name. Apply that at creation, naming in the notes what will later justify keeping it, and
again when its task closes — each file is cited by exactly one task and that task is always Done.
Prune **before** the branch merges, where the integration model makes that free
(`git-flow-squash` (a)).

Only after the full gate is clean do you commit (per `git-commit-format`) or hand off.
