<!-- chunk:verify-gate | value-variant | edit only at agent-skills/chunks/verify-gate.md — no per-project copies -->

## Verify gate (run before any commit or handoff)

On *fresh* evidence: if you did not run it this turn, you cannot claim it passes.

**The gate set, in order: typecheck, test, build, smoke, secret-scan.** Each runs its key's value
in `<!-- knobs:verify-gate -->`, in the on-disk contract your host adapter names, not context, and
must pass when due; `none — <why>` declares it absent. **build** is a production build,
`build_check` its output assertion; a green build is not a working app,
so **smoke** brings the affected surface up and back down;
**secret-scan** expects **zero** matches: secrets and env-specific hosts, paths and IPs come
from the environment at runtime, never source or config.

**Clean output, not just exit 0**: a new warning fails.

**A new top-level dependency is declared, or the gate is lying.** Manifest *and* lockfile.

**Run the gate once from a clean checkout of the commit**, not just your build tree, wherever git
normalizes or generates a file.

**Run the full gate** unless you derive the skip: grep what references the changed path and name
the gate that loads it. Where none does, that is coverage **as inspection**, not a pass.

**Docs synced** before the commit: `CONTEXT.md`, ADRs, any spec the project keeps, for new domain
language or a load-bearing decision. Part of the gate.

Only a clean gate permits a commit (`git-commit-format`) or handoff. Integration: load
`git-flow-squash`. Run procedure: `implement-run` (slash-only, unlisted).
