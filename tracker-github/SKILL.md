---
name: tracker-github
description: "GitHub Issues convention: gate and origin labels, parents, the frontier query and claim, footer by gate, closing record, re-gating, unplanned tickets. Use before any `gh issue` or `gh label` write, and before picking, claiming or closing a ticket."
---

# tracker-github

Everything goes through `gh`; no PR surface; comments are the evidence. Issues are as public as the
repository, with the same hygiene rules as code. The always-on rules — single source of progress,
bodies through `--body-file` with the leak screen and the list lag, the gated set, search first —
are the `tracker-github` Chunk, which the project's host adapter imports; where it is not in
context, read `~/.claude/chunks/tracker-github.md` (Codex: `~/.codex/chunks/tracker-github.md`).
Every section below keeps the heading it had in the Chunk, so an older "the Chunk's § X" citation
lands here.

## Two label axes

- **gate**, one per workable issue: `gate:agent` (a session starts and closes it alone),
  `gate:accept` (a session works it; the owner accepts before it closes), `gate:decide` (a
  decision or grill first; no session starts the work, though one may relabel it on the owner's
  say-so — see § Acceptance and re-gating).
- **origin**, one per non-wayfinder workable issue: `origin:spec` (child of a `Spec:` parent),
  `origin:review` (out of a code review), `origin:spec-review` (out of a spec review, off-chain),
  `origin:found` (a defect met during other work), `origin:chore` (maintenance).
- A `Map:` parent carries `wayfinder:map`; a wayfinder ticket under it carries
  `wayfinder:research`, `wayfinder:prototype`, `wayfinder:grilling` or `wayfinder:task`
  **instead of** an origin.

All thirteen must exist before the first ticket or map; `init-project`'s label mint (its step 4)
mints them, skipping any present. **A missing one is a stop**: tell the owner; `gh label create <name>` runs on their
go.

## Parents

A `Spec:` or `Map:` title prefix marks a parent, which carries **no gate and no origin label**.
Create each spec child in one `gh issue create` with `--parent`, and `--blocked-by` naming only
prerequisite **siblings** — never the parent, and omitted when there are none.

A parent closes with its last child, in the same approval; this says whether it was the last:
`gh issue view <parent> --json subIssues --jq '[.subIssues.nodes[].state] | length > 0 and all(. == "CLOSED")'`.
A completed chain's parent closes plain (`gh issue close <n>`); one whose chain was never filed
closes `--reason "not planned"`; one closed any other way is reopened (`gh issue reopen <n>`).

**Decomposition** — filing a parent's children — needs an explicit go-ahead before the first child's
`gh issue create` (§ Commit forms gates each create as well): propose titles plus one-liners, wait
for a yes. A single unplanned ticket is not decomposition. A standing CLI authorization covers
mechanics, not scope or structure.

## Frontier and claim

The **frontier** is the open, unassigned `gate:agent` issues whose blocked-by issues are all
closed; the next ticket is the lowest-numbered (`--label gate:accept` lists those instead). It is
the **unattended** pick, a batch's or any delegate's, and a batch adds the `gate:accept` variant
only where its grant takes those (`implement-batch` § Kickoff (b)):

```sh
gh issue list --label gate:agent --search "no:assignee" -L 200 --json number,blockedBy \
  --jq '[.[]|select([.blockedBy.nodes[].state]|all(.=="CLOSED"))]|min_by(.number)'
```

Keep `-L 200`; the default 30 drops the oldest. `all` over an empty list is true: the frontier
wants that (no blockers means free), and § Parents' test guards it with `length > 0` (no children
means not done). An empty result is an empty frontier **or** an unminted label, which lists zero at
exit 0 — `gh label list -L 200` tells them apart; for the second, see § Two label axes.

**The attended pick** is the kickoff an attended session hands on at its close (`implement-run`'s
Close, a `wrap-session` kickoff no artifact owns), and it keeps the owner on the work in hand. A
ticket is **pickable** when it is open, unassigned, gated `gate:agent` or `gate:accept`, and every
issue blocking it is closed. The **track** is the just-worked ticket's `Spec:` or `Map:` parent
(`gh issue view <n> --json parent`), whose children form it; with no parent, the issues it blocks
(`--json blocking`), read forward because a pickable ticket's own blockers are closed by
definition; with neither, there is no track. A track is **exhausted** when no open ticket is left
on it (a `Map:` track: every child closed). The first rule that names a ticket picks it:

1. **On a track, stay on it**: the lowest-numbered pickable ticket on it — `next on Spec #<p>`, or
   on a chain `next after #<n>`. A `Map:` track not exhausted hands on
   `/wayfinder #<map> — next on Map #<map>`, and wayfinder picks from the map's frontier
   (§ Wayfinder, and boards).
2. **A pickable open blocker outside the track** comes ahead of rule 3, within this repository
   only: `unblocks Spec #<p>` (on a chain, `unblocks #<t>`, the chain ticket it blocks). It applies
   only on a track; with no track, go straight to rule 3 and skip the collection below.
3. **Earliest open**, where no earlier rule names one: the lowest-numbered pickable ticket.

```sh
gh issue list --search 'no:assignee label:"gate:agent","gate:accept" SEARCH' -L 200 \
  --json number,labels,blockedBy --jq '[.[] | select(TRACK)
  | select([.blockedBy.nodes[].state] | all(. == "CLOSED"))]
  | min_by(.number) | select(. != null) | {number, labels: [.labels[].name]}'
```

An empty result prints nothing at exit 0 (the `select(. != null)`). The gate filter is a search
qualifier (the comma is OR), not a jq test, because `-L 200` applies
after the search filter, as the unattended query's `--label` does. On a `Spec:` track SEARCH is
`parent-issue:REPO#<p>` and TRACK `true`; on a chain SEARCH is empty and TRACK
`.number | IN(<b1>, <b2>)` (the `blocking` numbers, inlined: `--jq` takes no `--argjson`), taken
only from nodes whose `url` starts with `https://github.com/REPO/` — another repository's #N would
put this one's #N on the track —
`gh issue view <n> --json blocking --jq '[.blocking.nodes[] | select(.url | startswith("https://github.com/REPO/")) | .number]'`,
where an empty list means no chain, so no `IN()` is ever built empty; for
rule 3 SEARCH is empty and TRACK `true`. For rule 2, collect the open blockers of the track's open
tickets in this repository, less those on the track, with the same SEARCH and TRACK:

```sh
gh issue list --search 'SEARCH' -L 200 --json number,blockedBy --jq '[.[] | select(TRACK)]
  | [.[].number] as $t | [.[].blockedBy.nodes[] | select(.state == "OPEN")
  | select(.url | startswith("https://github.com/REPO/")) | .number | select(IN($t[]) | not)]
  | unique'
```

then run the first query with SEARCH empty and TRACK `.number | IN(<those>)`. Where the collected
set is empty, rule 2 names nothing: go to rule 3, never run the query with an empty `IN()`, which
gh's jq rejects with a parse error at exit 1.

The kickoff is the command with its rule after it — `/implement-run 141 — next on Spec #140`,
`/implement-run 135 — next after #147`, `/implement-run 51 — earliest open; gate:accept, needs the
owner's acceptance before close` — and a `gate:accept` pick always carries that note. Text after
the command reaches the invoked Skill as its arguments: the ticket is its first number, what
follows the rule. **`gate:decide` is never the attended pick**; a Map hand-off is wayfinder's pick,
which may take a map's grillings. Where rule 3 returns nothing, read it by the label check above
first; with every label present, say that nothing pickable remains, give the open `gate:decide`
count (`gh issue list --label gate:decide -L 200 --json number --jq length`), and where it is above
zero suggest a triage session.

**Read the live issue before the session's first write**; a summary, dispatch or handoff is not
the issue. Claim with `gh issue edit <n> --add-assignee @me`, which adds rather than sets: re-read
the assignees (`gh issue view <n> --json assignees --jq '[.assignees[].login]'`), and if there is
more than one, `--remove-assignee @me`, report the collision to the owner and wait. The re-read
sees only a collision between different accounts: two sessions under one account add one login, so
there the owner never starts two sessions on one ticket.

## Footer by gate, and the closing record

The squash commit's footer is `Closes #<n>` under `gate:agent`, `Refs #<n>` under `gate:accept`
(left open for the owner), none under `gate:decide`. The close lags: re-read
`gh issue view <n> --json state` rather than closing by hand or re-pushing.

**The closing record is a comment** (`gh issue comment <n> --body-file <f>`): each acceptance
criterion by number with its evidence, and the reviewed tree's **commit SHA**, never a branch
name. Post it after the last commit mutation (an amend rewrites the SHA, silently orphaning a
posted record): re-read `git rev-parse --short HEAD` before the first tracker write citing it. The
record is the tick.

**The body is the spec**; `gh issue edit --body` replaces it wholesale, so state never goes into
it. Three body writes are allowed, each a body rewrite (§ Commit forms): supersede-in-place
(`SUPERSEDED by #<n>. Was: "<original text>". <why it can no longer be observed>`); adding an
acceptance criterion to a ticket not yet started, which is how the rule below lands a hard
requirement; and the re-gate write (§ Acceptance and re-gating).

**A finding never goes homeless.** Before the producing ticket closes (under a `Closes` footer,
before the merge), a hard requirement becomes an acceptance criterion on the ticket it constrains,
and a comment there names the source; one constraining no ticket gets an owner — a new
ticket, an ADR or a named note. The closing record points at each home.

## Acceptance and re-gating

Closing a `gate:accept` ticket quotes the owner's accepting reply and the SHA they saw, in the same
approval as the close — transcribed, never inferred. A rejection is quoted in a comment; the ticket
stays open, gate unchanged. A decline closes **not planned** with the reply quoted; abandoned work
takes that exit too, never `completed`.

A `gate:decide` ticket is re-gated by the owner relabelling it, or by a session working in order:
quote their reply in a comment; where the decision kills an acceptance branch or raises a pinnable dial,
make the **re-gate write**, a body rewrite (§ Commit forms) whose approval shows the new text,
cutting the body to the decided branch and adding the `Pins:` line the decision fixes (the
`implement-run` Skill's § Run profile); give each prerequisite the body now
names an edge it lacks (§ Unplanned tickets), and remove (`--remove-blocked-by`) an edge that only
the cut branch named; and last, apply the gate they named, since a ticket
relabelled before its edges can reach the frontier with a blocker open. A `Pins:` line sits on its
own line directly above the acceptance heading.

## Unplanned tickets

A session may file `origin:found`, `origin:review`, `origin:spec-review` and `origin:chore`
tickets alone — scoping them itself, not skipping approval (§ Commit forms) — always as
`gate:decide`; one the owner approves at creation carries the gate they name. Before filing, the
Chunk's **Search first** applies, over any frontier output you have as well.

A prerequisite the body names becomes a `--blocked-by` edge, by URL when it lives in another
repository: at filing, or with `gh issue edit <n> --add-blocked-by` once one filed later exists,
at the re-gate at the latest.

Four sections, verbatim: `## Found while`, `## Evidence`, `## What a fix has to weigh` (or
`## What to build`), `## Acceptance`. On `origin:review` and `origin:spec-review`, `## Evidence`
links the review and names the commit SHA it was taken against. No date window in a body; schedule
belongs to the plan doc or ADR that owns it.

## Wayfinder, and boards

A wayfinder ticket gets its gate in the same create call: `research` → `gate:agent`, `prototype`
and `grilling` → `gate:decide`, `task` → `gate:accept` unless the owner says otherwise at chart
time. A board kept alongside is a view: **an agent never writes a board field**.

A map's **frontier** (wayfinder's word) is its open, unassigned children of any gate whose
blockers are all closed, and wayfinder's next ticket is the lowest-numbered on it, not first in map
order — so a map takes its own query, not § Frontier and claim's `gate:agent` one:

```sh
gh issue list --search 'no:assignee parent-issue:REPO#<map>' -L 200 --json number,blockedBy \
  --jq '[.[] | select([.blockedBy.nodes[].state] | all(. == "CLOSED"))] | min_by(.number)
  | select(. != null) | .number'
```

A map with no free child prints nothing at exit 0 (the `select(. != null)`).

## Commit forms, and clauses deferred here

Scope `<type>(<area>/#<n>)`, branch `<type>/<n>-<slug>`, footer by gate; work with no issue omits
both and branches `<type>/<slug>`. Another repository's issue is `owner/repo#<n>`. Anchor log
searches: `git log -E --grep '#<n>([^0-9]|$)'` (a bare `#25` matches `#250`).

`git-flow-squash` is a Skill — load it at task start and at integration. Its merge model and
pre-push audit stand, and the project is **not** board-less, since the issue numbers are the task
ids. **Nothing is marked Done on the branch**: the integration commit carries code and the footer,
no board change, and the closing record follows the merge. There are no board notes, so the
notes-SHA policy has no subject; the reviewed SHA is in the closing record. No tracker files live in
the tree, so there is nothing to stage.

The `implement-run` Skill's Done gate resolves here to the closing record. Under `parallel-work`
the coordinator alone writes issues, except an attended worktree session on the issue it owns.
For issue and label writes, `git-confirm-destructive`'s gate resolves to the Chunk's **Gated
writes**; the re-gate write is a body rewrite, so it is gated (§ Acceptance and re-gating). Any
other `gh` write keeps `git-confirm-destructive`'s own gate.

## Knobs

`<!-- knobs:tracker-github -->`, read from the contract file on disk (an injected copy has lost its
marker lines; a contract that cannot be read is a stop that names the path), carries exactly
**REPO** (`owner/repo`) and **RESULTS_DIR** — the repository-relative path for a `gate:accept`
ticket's result note, or `none` for comments only.
`PROJECT`, `COLUMNS`, `AGENT_LABEL` and `RECORDS_DIR` are retired; a contract still naming them
moves them to the project's own policy file, never back into the Chunk or this Skill.
