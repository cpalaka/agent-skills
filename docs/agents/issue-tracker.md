# Issue tracker

<!-- HAND-WRITTEN, and authoritative for THIS repository. This repository stamps nothing
     (project-workflow.md § Hand-written, and it stays that way), so nothing generates this file.
     init-project/templates/tracker/issue-tracker.md stamps the same file into a project
     that IS stamped; it is the shape this one mirrors, not its source, and neither is generated
     from the other. Conventions are authoritative in chunks/tracker-github.md (the always-on
     core) and tracker-github/SKILL.md (the rest) for both — a pointer, not a second copy. -->

GitHub issues, all through `gh`; the repository is the `REPO` knob in
`docs/agents/project-workflow.md`. The convention (the label axes, the frontier, the closing
record, which writes are gated) is the always-on core in `chunks/tracker-github.md` and the
`tracker-github` Skill (`tracker-github/SKILL.md`), loaded before any `gh issue` or `gh label`
write — read them there.

A leak guard runs here, so every `--body-file` body is screened before the write, and **the body
file goes at the repository root** — not the session scratchpad, and not a gitignored path such
as `.scratch/`, which `scan` skips, returning clean on anything inside it. The scan command, the
identity file, the planted known-bad and reading the match count are
[`CLAUDE.md`](../../CLAUDE.md) § Load-bearing facts.

## When a skill says "publish to the issue tracker"

Create a GitHub issue: `gh issue create`. Its labels are the Skill's (§ Two label axes), its
gated-write status the Chunk's (**Gated writes**), and the four verbatim body sections an unplanned
ticket takes are the Skill's (§ Unplanned tickets). A spec child takes the body the skill
filing it gives.

## When a skill says "fetch the relevant ticket"

`gh issue view <n>` for the body, which is the spec, then `gh issue view <n> --comments` for the
comments — outside a terminal `--comments` prints the comments alone, so it never stands in for the
first call. Per the Skill's § Frontier and claim, read the live issue before the session's first
write.

## Relationships

Native flags, verified on gh 2.101.0, replacing the older `gh api` recipe:

- `gh issue create --parent <n> --blocked-by <n or URL>` · `gh issue edit <n> --add-blocked-by <n or URL>`
- `gh issue view <n> --json blockedBy` (nested under `.blockedBy.nodes`) · `--json subIssues`

What may block what is the Skill's § Parents and § Unplanned tickets.

## Wayfinding operations

Used by `/wayfinder`. The **map** is one issue, its tickets **child** issues: a `Map:` title
prefix and `wayfinder:map`, children carrying `wayfinder:research`/`prototype`/`grilling`/`task`
and the gate the Skill gives each (§ Wayfinder, and boards). Link and order them with the flags
above.

- **Frontier:** the query is the Skill's § Wayfinder, and boards; the next ticket is the
  lowest-numbered, not first in map order. The kickoff an attended session hands on is the Skill's
  § Frontier and claim, the attended pick.
- **Claim:** `gh issue edit <n> --add-assignee @me` — the flag adds rather than sets, and that
  same section has the race and the stand-down.
- **Resolve:** `gh issue comment <n> --body-file <f>`, then close. That comment, the footer and
  the body-write rule are the Skill's (§ Footer by gate, and the closing record).

## Pull requests as a triage surface

**PRs as a request surface: no.** _(`/triage` reads this flag.)_
