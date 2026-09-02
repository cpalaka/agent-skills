# 7. Third-party skills with no distribution channel are vendored into this repo

## Status
Accepted — 2026-08-19.

## Context
Every third-party skill so far arrives through a channel that owns its body: `npx skills` into
`~/.agents/skills/`, or `claude plugin` into `~/.claude/plugins/`. `skill-updater` refreshes those,
and this repo holds only hand-authored bodies — the split the README and `CLAUDE.md` both state.
`unslop` breaks the assumption. It lives in `cursor/plugins`, a **Cursor** plugin repo shipping
`.cursor-plugin/plugin.json` and no `.claude-plugin/marketplace.json`, so the plugin CLI cannot
resolve it and no `npx skills` package publishes it. The body is format-compatible and loads fine;
only distribution is missing. Leaving it loose outside the repo (a directory of vendored skills
outside version control was the first attempt) puts a live skill outside git and outside every
audit that walks this repo.

## Decision
A third-party skill with no distribution channel is vendored at the repo root like any other skill
directory, and is required to carry a sibling `PROVENANCE.md` naming the upstream URL, the pinned
commit, the license, every local modification with its rationale, and the manual update procedure.
The "everything here is hand-authored" invariant narrows to "everything here without a
`PROVENANCE.md`". `skill-updater` still does not touch these; `PROVENANCE.md` is the marker that
tells a reader the body has an upstream even though nothing automated tracks it.

## Consequences
Live skills stay in git and inside the repo's audits, at the cost of a manual diff-and-re-apply on
each upstream sync — acceptable for a small number, and the `PROVENANCE.md` requirement is what
keeps local edits from being silently reverted by a future sync. The cost scales badly, so this is a
fallback for skills with no channel, never a general vendoring policy: anything installable through
`npx skills` or `claude plugin` still goes through its channel. First instance: `unslop/`.
