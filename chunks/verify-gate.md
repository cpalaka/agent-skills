<!-- chunk:verify-gate | kind: value-variant | single-source: agent-skills/chunks/verify-gate.md -->
<!-- Delivered by Claude @import or a Codex AGENTS.md explicit read through the host's chunk symlink.
     Edit here only — no per-project copies, no parity. -->

## Verify gate (run before any commit or handoff)

Before committing, opening a handoff, or claiming work done, run this project's
**verify gate** and confirm it from *fresh* evidence — not "should pass", not a
previous run. Evidence before assertions, always (the `dev-practice`
verification-before-completion rule): if you didn't run it in this turn, you can't
claim it passes. The gate is invariant; the exact commands are a knob.

**The sequence (run in order, all must pass).**

1. **typecheck** — the type/compile step.
2. **test** — the project's test suite.
3. **build** — a real production build (it catches what typecheck and tests miss;
   include any output/artifact sanity check the build is supposed to produce).
4. **smoke** — bring the app up and confirm the affected surface actually renders /
   responds, then bring it back down. A green build is not a working app.
5. **secret-scan** — grep the working tree for leaked credentials; expect **zero**
   matches before the change leaves your machine. Secrets are read from the environment
   or a secret manager at runtime, never written into source or committed config — and
   the same goes for environment-specific server paths, hosts and IPs, which resolve
   from config/DNS/SSH rather than literals.

The exact commands, the directory they run in, the build's output check, the
secret-scan grep pattern, and any env are project-specific — read them from the
`<!-- knobs:verify-gate -->` block in the project contract file named by your host adapter, never hardcode
them here. That block may also carry **further named gate lines after `secret-scan`**;
they are part of the invariant, run in the order listed and held to the same pass bar as
the five above.

**Clean output, not just exit 0.** A run that exits 0 with new warnings or noise is
**not** a pass — investigate the warning rather than ignoring it. "Passing" means the
output is clean *and* the exit code is 0.

**WHERE the gate runs is part of the gate.** A gate run in the same worktree that
produced the artifacts is structurally blind to anything that only bites after a fresh
checkout re-materializes them. One case (measured 2026-07-17 on a project): the
repo's `* text=auto eol=lf` rewrote CRLF source files to LF at commit time, so a
size-compare asset sync re-copied them on every run of a fresh clone — while the
worktree's own "re-run → copied=0" idempotency gate passed **honestly** and was still
wrong on main. Nothing in that run could have caught it, because the worktree's copies
were never re-checked-out.

So: for any gate over files git normalizes, generates, or re-materializes (EOL/`text`
attributes, filters, LFS, generated assets, a byte-mirror directory), run it once from a
**clean clone or a fresh worktree of the commit**, not only from the tree you built in.
And exempt byte-mirror directories from normalization (`assets/** -text`) so the
comparison has something stable to compare.

**Docs synced.** Before the commit, confirm the project's design docs (e.g.
`CONTEXT.md`, ADRs, any PRD/spec the project keeps) are updated for any new domain
language or load-bearing decision the change introduces. Synced docs are part of the
gate, not a follow-up.

**Evidence kept is evidence something still READS.** Where a criterion is proven by a
committed artifact — a screenshot pair, a capture set, a probe's output — the artifact
earns its place in the repo only while something **other than its own closed task**
points at it: an open task, an ADR, a standing doc, a sibling row that cites it by
name. What survives only as proof of a check whose *result* is already written down in
prose has done its job and goes; the prose is the durable record, and a full-resolution
capture of a surface still under change is a baseline nothing will ever diff against.
Apply it when the artifact is created (name in the notes what will later justify
keeping it) and again when its task closes — otherwise a wave that commits evidence per
ticket accumulates it forever, because each file is cited by exactly one task and that
task is always Done. Prune **before** the branch merges where the integration model
makes that free (`git-flow-squash` (a)).

Only after the full gate is clean do you commit (per `git-commit-format`) or hand off.
