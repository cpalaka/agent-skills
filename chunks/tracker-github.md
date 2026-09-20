<!-- chunk:tracker-github | kind: value-variant | single-source: agent-skills/chunks/tracker-github.md -->
<!-- Delivered by Claude @import or a Codex AGENTS.md explicit read through the host's chunk symlink.
     Edit here only — no per-project copies, no parity. -->
<!-- The tracker fork's GitHub side: a project imports this OR backlog-core, never both. -->

## Task tracking (GitHub Issues)

Issues on **REPO** are the **single source of progress**, not memory files or doc ledgers;
`docs/adr/` stays the only decision system. They are as public as the repository: same hygiene
rules as code. All through `gh`; no PR surface; comments are the evidence.

**Multi-line bodies and comments go through a temporary UTF-8 file inside the repository and
`--body-file`, removed after the write** — sandboxed and unsandboxed shells resolve different
`$TMPDIR`, so `"$(cat …)"` collapses to empty and `gh` still reports success. **A leak guard
never sees a `gh` write**; it scans the git object store. Where one exists, screen each body
through it from a path the scan walks, with a known-bad planted beside it, and read the match
**count**, not the exit status: the expected count is the plant's own matches, and anything above
it is a real hit. Confirm a candidate plant actually matches the guard's list before trusting a
clean result. `gh issue list` lags a fresh creation and truncates silently — confirm with
`gh issue view <n>`.

### Two label axes

- **gate**, one per workable issue: `gate:agent` (a session starts and closes it alone),
  `gate:accept` (a session works it; the owner accepts before it closes), `gate:decide` (a
  decision or grill first; no session starts the work, though a session may relabel it on the
  owner's say-so).
- **origin**, one per non-wayfinder workable issue: `origin:spec` (child of a `Spec:` parent),
  `origin:review` (out of a code review), `origin:spec-review` (out of a spec review, off-chain),
  `origin:found` (a defect met while doing other work), `origin:chore` (maintenance and
  housekeeping).
- A `Map:` parent carries `wayfinder:map`; a wayfinder ticket under it carries
  `wayfinder:research`, `wayfinder:prototype`, `wayfinder:grilling` or `wayfinder:task`
  **instead of** an origin.

Thirteen labels per repository, and all thirteen must exist before the first ticket is filed or
the first map charted. The Profile that stamps a project mints them, skipping any already
present; `gh label create <name>` is the manual fallback.

### Parents

A `Spec:` or `Map:` title prefix marks a parent, which carries **no gate and no origin label**, so
gate queries return only claimable work. Create every spec child in one `gh issue create`:
`--parent` takes the `Spec:` parent, `--blocked-by` takes prerequisite **siblings** and never the
parent — a child blocked by its own parent is permanently off the frontier — and a first child
with no prerequisite passes no `--blocked-by` at all. A parent closes with its last child in the
same approval; `gh issue view <parent> --json subIssues --jq '[.subIssues.nodes[].state] |
length > 0 and all(. == "CLOSED")'` says whether that was the last one, and reads false for a
childless parent rather than true. A completed chain's parent closes plain
(`gh issue close <n>`); one whose chain was never filed closes not planned
(`gh issue close <n> --reason "not planned"`); closed any other way, it is reopened
(`gh issue reopen <n>`).

**Decomposition — filing a parent's chain of children — needs an explicit go-ahead before the
first `gh issue create`**: propose titles plus one-liners, wait for a yes. A single unplanned
ticket is not decomposition. A standing CLI authorization removes permission prompts on
mechanics, not decision authority over scope or structure.

### Frontier and claim

The **frontier** is the open, unassigned `gate:agent` issues whose blocked-by issues are all
closed; the next ticket is the lowest-numbered.

```sh
gh issue list --label gate:agent --search "no:assignee" -L 200 --json number,blockedBy \
  --jq '[.[]|select([.blockedBy.nodes[].state]|all(.=="CLOSED"))]|min_by(.number)'
```

`-L 200` is load-bearing: the default 30, newest-first, truncates the **oldest** — the issue
`min_by` returns. The same query with `--label gate:accept` lists those instead. An empty result
means an empty frontier **or** a label that was never minted, since a missing label lists as zero
issues at exit 0 — `gh label list -L 200` tells the two apart, and defaults to 30 itself.
**Read the live issue before the session's first write**; a cached summary, a dispatch prompt
or a prior session's handoff is not the issue. Then claim it with
`gh issue edit <n> --add-assignee @me`. That flag **adds** rather than sets, so two sessions can
both succeed: re-read the assignees after the write, and if there is more than one, remove your
own (`--remove-assignee @me`) and stand down.

### Footer by gate, and the closing record

The squash commit's footer is chosen by gate label: `Closes #<n>` under `gate:agent`, closing the
issue atomically with the merge; `Refs #<n>` under `gate:accept`, leaving it open for the owner;
no footer under `gate:decide`, never worked. **That close lands with a lag** — a session reading
back its own push can still see `OPEN` seconds afterwards. Re-read
`gh issue view <n> --json state` rather than closing by hand or re-pushing.

**The closing record is a comment** — `gh issue comment <n> --body-file <f>` — carrying each
acceptance criterion by number with its evidence, and the **commit SHA** of the tree that was
reviewed — a SHA, never a branch name, so a base that moved after review is visible. **Post it
after the last commit mutation**: an amend — the common one is fixing the footer to match the
gate after the squash — rewrites the SHA, and one already posted to a sibling ticket is then
dead, with the comment well-formed, `gh` reporting success and nothing resolving it. Re-read
`git rev-parse --short HEAD` between the last commit and the first tracker write that cites it.
The record is the tick. `gh issue edit --body` replaces a body wholesale and **the body is the
spec**, so **state** never goes back into it. Two body writes are permitted, both spec
changes rather than state: supersede-in-place, since citations resolve by number —
`SUPERSEDED by #<n>. Was: "<original text>". <why it can no longer be observed>` — and adding
an acceptance criterion to a ticket that has not started, which is how the rule below lands a
hard requirement.

**A finding never goes homeless.** Before the producing ticket closes, a hard requirement becomes
an acceptance criterion on the ticket it constrains and a pointer a comment naming the source; one
constraining no ticket still needs an owner — a new ticket, an ADR or a named note.

### Acceptance and re-gating

Closing a `gate:accept` ticket quotes the owner's accepting reply and the commit SHA they saw, in
the same approval as the close: acceptance is transcribed, never inferred. A rejection is quoted
in a comment, the ticket left open, gate unchanged. A `gate:decide` ticket is re-gated by the
owner relabelling it, or by a session quoting their reply and applying the gate they named. A
decline closes it **not planned** with the reply quoted; abandoned work takes that exit too,
never `completed`.

### Unplanned tickets

A session may file `origin:found`, `origin:review`, `origin:spec-review` and `origin:chore`
tickets alone; **filed alone, they are always `gate:decide`**, so the frontier holds only what the
owner put there. One the owner approves at creation carries the gate they name.

**Search the open issues before creating one** — `gh issue list --state open -L 200 --search
'<a noun from the finding>'`, plus the frontier query's own output where you have run it. A defect
met mid-ticket is exactly the kind an earlier session already filed; `gh issue create` succeeds
either way, and a duplicate buried inside an otherwise-sound multi-part ticket leaves no trace.
Where one exists, **comment on it with the new evidence instead** — a second sighting, on a
different subject and independently measured, is worth more to that ticket than a second ticket is.

Four sections, verbatim: `## Found while`, `## Evidence`, `## What a fix has to weigh`
(or `## What to build`), `## Acceptance`. On an `origin:review` or `origin:spec-review` ticket,
`## Evidence` links the review and names the commit SHA it was taken against. **No internal date
window in a body** — an issue is not a calendar and a stale date flags nothing; schedule lives in
the plan doc or ADR that owns it.

### Wayfinder, and boards

A wayfinder ticket gets its gate in the same create call: `research` → `gate:agent`, `prototype`
and `grilling` → `gate:decide`, `task` → `gate:accept` unless the owner says otherwise at chart
time. A board a project keeps alongside this tracker is a view: **an agent never writes a board
field**, which would be a second source of status.

### Commit forms, and clauses deferred here

Scope `<type>(<area>/#<n>)`, branch `<type>/<n>-<slug>`, footer by gate; work with no issue omits
both and branches `<type>/<slug>`. Another repository's issue is `owner/repo#<n>` — a bare number
resolves in the wrong one. Anchor a log search, `git log -E --grep '#<n>([^0-9]|$)'`, because
`#25` also matches `#250`.

`git-flow-squash` is a Skill — load it at task start and at integration; it resolves here:

- merge model unchanged; the branch prefix takes the issue number in place of `task-NNN`;
- **nothing is marked Done on the branch** — the closing record is a comment posted after the
  merge, so the integration commit carries code only: no Done-marking and no board change rides
  along, though its message still carries the footer;
- no board notes, so the notes-SHA policy has no subject; the reviewed commit's SHA is in the
  closing record;
- a project importing this chunk is **not** board-less — board-less means no task ids, and here
  the issue numbers are the ids — so that exception does not fire;
- no tracker files in the tree: no board-grooming push analogue, and no rows to stage;
- the pre-push audit predicate rides the fork, untouched.

The `implement-run` Skill's Done gate resolves here to the closing record. Under `parallel-work`
the coordinator alone writes issues, excepting an attended worktree session on the issue it owns.
`git-confirm-destructive`'s gate resolves here to a **gated set**, not a list of exemptions:
creating an issue, closing one, reopening one and rewriting a body are gated. Every other write
this convention instructs — assigning and releasing, labelling and re-gating, minting a label,
commenting — needs no approval. The set is stated as what is gated because an exemption list
goes stale every time a clause adds a write. Reads were never gated.

### Knobs

`<!-- knobs:tracker-github -->` carries exactly **REPO** (`owner/repo`) and **RESULTS_DIR** — the
path, relative to the repository root, where a `gate:accept` ticket's result note goes, or `none`
for comments only. A contract still naming `PROJECT`, `COLUMNS`, `AGENT_LABEL` or `RECORDS_DIR`
is on the retired five-knob shape: those four move into the project's own policy file, never back
into this chunk.
