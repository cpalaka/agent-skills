# Issue tracker

<!-- HAND-WRITTEN. This repository stamps nothing
     (project-workflow.md § Hand-written, and it stays that way).
     Template home when the github Profile exists (#28):
     init-project/profiles/github/templates/issue-tracker.md. Conventions are authoritative in
     chunks/tracker-github.md — a pointer, not a second copy. -->

GitHub issues, all through `gh`; the repository is the `REPO` knob in
`docs/agents/project-workflow.md`. The convention (the label axes, the frontier, the closing
record, which writes are gated) is `chunks/tracker-github.md` — read it there.

A leak guard runs here, so every `--body-file` body is screened before the write, and **the body
file goes at the repository root** — not the session scratchpad, and not a gitignored path such
as `.scratch/`, which `scan` skips, returning clean on anything inside it. The scan command, the
identity file, the planted known-bad and reading the match count are
[`CLAUDE.md`](../../CLAUDE.md) § Load-bearing facts.

## When a skill says "publish to the issue tracker"

Create a GitHub issue: `gh issue create`. Its labels, its four verbatim body sections and its
gated-write status are the Chunk's (§ Unplanned tickets; § Two label axes; § Commit forms, and
clauses deferred here).

## When a skill says "fetch the relevant ticket"

`gh issue view <n> --comments`. Per the Chunk's § Frontier and claim, read the live issue before
the session's first write.

## Relationships

Native flags, verified on gh 2.101.0, replacing the older `gh api` recipe:

- `gh issue create --parent <n> --blocked-by <n>` · `gh issue edit <n> --add-blocked-by <n>`
- `gh issue view <n> --json blockedBy` (nested under `.blockedBy.nodes`) · `--json subIssues`

What may block what is the Chunk's § Parents.

## Wayfinding operations

Used by `/wayfinder`. The **map** is one issue, its tickets **child** issues: a `Map:` title
prefix and `wayfinder:map`, children carrying `wayfinder:research`/`prototype`/`grilling`/`task`
and the gate the Chunk gives each (§ Wayfinder, and boards). Link and order them with the flags
above.

- **Frontier:** the query is the Chunk's § Frontier and claim; the next ticket is the
  lowest-numbered, not first in map order.
- **Claim:** `gh issue edit <n> --add-assignee @me` — the flag adds rather than sets, and that
  same section has the race and the stand-down.
- **Resolve:** `gh issue comment <n> --body-file <f>`, then close. That comment, the footer and
  the body-write rule are the Chunk's (§ Footer by gate, and the closing record).

## Pull requests as a triage surface

**PRs as a request surface: no.** _(`/triage` reads this flag.)_
