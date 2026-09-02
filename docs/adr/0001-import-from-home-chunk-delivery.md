# Chunks delivered via `@import`-from-home, not copy-and-parity

**Status:** accepted

Dev-process rules were duplicated and drifting across projects and the per-type init skills.
Because the author is a solo developer with no collaboration (so repos need not be
self-contained), we commit reusable **Chunks** in this repo's `chunks/`, symlink that directory
to `~/.claude/chunks`, and have each project's `CLAUDE.md` reference them with
`@~/.claude/chunks/<name>.md` — a single source of truth, so editing a Chunk updates every
project at next launch and there is no per-project copy to drift (no parity/propagate lifecycle
for Chunks, unlike copied **Templates**).

**Consequences:** every project's `CLAUDE.md` is incomplete without this repo cloned and linked
on that machine (Windows uses a directory junction). If collaboration or CI ever required
self-contained project repos, this would have to revert to the stamp-and-parity (Template) model.
