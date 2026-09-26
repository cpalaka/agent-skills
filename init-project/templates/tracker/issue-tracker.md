# Issue tracker

<!-- Stamped by init-project (templates/tracker/issue-tracker.md). This file is the
     canonical tracker pointer for skills that look up docs/agents/issue-tracker.md
     (code-review's Spec axis reads it by that path; triage, to-tickets and wayfinder expect it by
     description). Conventions stay authoritative in the tracker-github chunk, which your host
     adapter loads (CLAUDE.md for Claude Code, AGENTS.md for Codex) — this is a pointer, not a
     second copy. -->

GitHub issues, all through `gh`; the repository is the `REPO` knob in
`docs/agents/project-workflow.md`. The convention — the two label axes, parents and relations, the
frontier, the closing record, which writes are gated — is the **`tracker-github`** chunk, reached
through your host adapter. Read it there.

**What this file restates, and why.** It is a pointer, so it names sections rather than copying
them — with three deliberate exceptions, each a rule whose *cost of being missed* is higher than the
cost of it living in two places: where the body file goes, that `--add-assignee` adds rather than
sets, and that the next ticket is the lowest-numbered. Each is a rule a reader who skips the chunk
gets silently wrong. **Everywhere else the chunk wins**, including against these three if they ever
disagree with it.

**Multi-line bodies and comments go through a UTF-8 file and `--body-file`**, never `--body` with
an embedded newline (the chunk's § Task tracking says why).

**Where that file goes depends on how this project's leak guard reads the tree.** Never the
session scratchpad, under any guard or none: a scratchpad path is invisible to every tree-walking
check the project will ever add. Beyond that:

- **A guard that walks the working tree and honours `.gitignore`**: the repository root, not a
  gitignored path such as `.scratch/` — such a scan skips a gitignored path and returns clean on
  anything inside it, whatever it contains.
- **A guard that reads tracked files only** (a `git grep` with no `--untracked`): a gitignored path
  is allowed. The body file is written, passed to `gh` and deleted without ever being tracked, so
  that guard never sees it wherever it sits, and ignoring the path keeps `git status` clear.

Delete the file after the write.

**Where this project runs a leak guard**, one step is added on top: screen each body through the
guard before the write, because a guard scans the git object store and **never sees a `gh` write**.
Plant a known-bad beside the body in the same scan and read the match **count** rather than the
exit status. The screen needs a path the guard reads, so under a tracked-only guard point its
pattern check at the body file directly (or stage the file intent-to-add for the screen and unstage
it after). Where this project runs no leak guard, that screening step does not apply and nothing
replaces it — the scratchpad ban above holds either way.

## When a skill says "publish to the issue tracker"

Create a GitHub issue: `gh issue create`. Its labels and its gated-write status are the chunk's
(§ Two label axes; § Commit forms, and clauses deferred here), and so are the four verbatim body
sections an unplanned ticket takes (§ Unplanned tickets). A spec child takes the body the skill
filing it gives.

## When a skill says "fetch the relevant ticket"

`gh issue view <n>` for the body, which is the spec, then `gh issue view <n> --comments` for the
comments — outside a terminal `--comments` prints the comments alone, so it never stands in for the
first call. Per the chunk's § Frontier and claim, read the live issue before the session's first
write — a cached summary, a dispatch prompt or a prior session's handoff is not the issue.

## Relationships

Native flags, verified on gh 2.101.0, replacing the older `gh api` recipe:

- `gh issue create --parent <n> --blocked-by <n or URL>` · `gh issue edit <n> --add-blocked-by <n or URL>`
- `gh issue view <n> --json blockedBy` (nested under `.blockedBy.nodes`) · `--json subIssues`

What may block what is the chunk's § Parents and § Unplanned tickets.

## Wayfinding operations

Used by `/wayfinder`. The **map** is one issue, its tickets **child** issues: a `Map:` title prefix
and `wayfinder:map`, children carrying `wayfinder:research`/`prototype`/`grilling`/`task` and the
gate the chunk gives each (§ Wayfinder, and boards). Link and order them with the flags above.

- **Frontier:** the query is the chunk's § Frontier and claim; the next ticket is the
  lowest-numbered, not first in map order.
- **Claim:** `gh issue edit <n> --add-assignee @me` — the flag adds rather than sets, and that same
  section has the race and the stand-down.
- **Resolve:** `gh issue comment <n> --body-file <f>`, then close. That comment, the footer and the
  body-write rule are the chunk's (§ Footer by gate, and the closing record).

## Pull requests as a triage surface

*<Fill at init: `PRs as a request surface: yes` or `PRs as a request surface: no`. `/triage` reads
this flag and cannot derive it — `no` means triage covers issues only; `yes` means the same roles
and states apply to incoming PRs too, through the `gh pr` equivalents. A public repository taking
outside contributions usually wants `yes`; a private or solo one usually wants `no`.>*
