<!-- chunk:tracker-github | kind: value-variant | single-source: agent-skills/chunks/tracker-github.md -->
<!-- Delivered by Claude @import or a Codex AGENTS.md explicit read through the host's chunk symlink.
     Edit here only — no per-project copies, no parity. -->
<!-- The tracker fork's GitHub side: a project imports this OR backlog-core, never both. It is a
     drop-in owner for every clause git-sync-branch-start, git-commit-format, git-flow-squash,
     parallel-work and dev-practice defer to "the tracker chunk". -->

## Task tracking (GitHub Issues + Project)

GitHub Issues in the **REPO** repository are the **single source of progress** for all
forward-looking work, not memory files, doc ledgers, or a second board. `docs/adr/` stays the only
decision system; design docs, specs and plans stay in `docs/`. The **repository-qualified issue URL**
(`https://github.com/<owner>/<repo>/issues/<number>`) is an issue's durable identity: use it
wherever an issue is named, never a bare `#<number>`, which resolves differently in another
repository. Per-project values live in this project's
`<!-- knobs:tracker-github -->` block, not in this chunk: the repository (**REPO**), the private
Project's title and number (**PROJECT**), its four column names (**COLUMNS**: todo, in progress,
review, done), the agent provenance label (**AGENT_LABEL**), and where per-issue records live
(**RECORDS_DIR**).

**Nothing on the board authorizes work.** Project membership, a label, an open state, an assignee
and a status value all describe where work stands. None is a grant, and an issue sitting in the
todo column is not claimable until it has its own start record.

**Session start: read the live issue and its Project status, then set the in-progress column.**
Read the issue live before the session's first write, with its start-authorization comment and the
documents it links; a cached summary, a plan doc or a prior session's handoff is not the issue.
Once the start record checks out, the coordinator sets the in-progress column **before**
implementation begins or resumes, and the review column when a concrete result is ready. Never
leave underway work in the todo column, and never read a status update as authorization for the
work it describes.

**Start authorization is an issue comment, and an agent transcribes it, never originates it.** The
comment quotes the human's authorization, names the exact scope or revision it covers, and links
the source conversation or retained decision record. Each issue needs its own, and an approval of
one concrete result never covers the next. Per-issue records (start record, verification, review,
handoff) live under **RECORDS_DIR** so the issue body keeps resolving after the branch is gone.

**Routine updates are pre-authorized. Every other write is not.** During authorized work on an
issue that has an active authorization record, an agent may update the issue description, append
comments, assign the issue, and move it among non-done statuses without asking again. The grant
covers the GitHub mechanics for those exact updates and nothing else. Explicit human approval stays
required for:

- new scope or new acceptance criteria;
- queue creation or issue decomposition;
- marking work complete, closing as completed, and moving to the done column;
- deleting records or remote refs;
- integration, merge, force-push, and deployment.

`git-confirm-destructive`'s gate on `gh` **writes** stands; this chunk narrows it for the routine
updates above and for nothing else. Reads (`gh issue view`, `gh issue list`, Project reads) were
never gated and still are not.

**Completion: sign-off recorded in a comment against the reviewed result.** The comment names what
was reviewed (the revision or SHA of the reviewed tree), not the branch, so a base that moved after
review is visible. Only then may the issue close as completed and move to the done column. **The
project's contract says what one sign-off covers**; absent that statement, completion, integration
and the push are three separate approvals. A green gate, a review result or a status change never
substitutes for it. Retirement is the other exit: work abandoned rather than finished closes as
**not planned** and leaves the board after approval, never as done.

**Branch, commit and footer forms: this chunk owns them.**

- Branch name is `<type>/gh-<number>-<slug>`, `<type>` being the conventional-commit type.
  `git-sync-branch-start` delegates branch naming to the tracker and git-flow pairing; this is its
  tracker half. Existing branches keep their current names.
- `git-commit-format` **defers the commit scope and footer here**: subject
  `<type>(<area>/gh-<number>): <summary>`, footer `Refs https://github.com/<owner>/<repo>/issues/<number>`.
  `git log --grep gh-<number>` then resolves issue to commits.
- **No automatic-closing keywords** (`Fixes #N`, `Closes #N`, and the rest). Closing is a human
  gate, and a keyword closes the issue on merge without one.
- Work with no issue omits the issue scope and the footer, and branches as `<type>/<slug>`.
- The git-flow variant's `task-NNN` branch form and its board-notes policy are the other tracker's;
  ignore them, and there is no board-grooming push exception here. A project importing this chunk
  is **not** board-less, so `git-flow-squash`'s board-less exception does not fire either. Where a
  variant says "mark it Done on the branch before the merge", **there is nothing to mark on the
  branch**: closing the issue and moving it to the done column are GitHub writes made after
  sign-off, so the integration commit carries code only. The rest of the variant applies
  unchanged, including base revalidation, the gate rerun after a rebase, and per-integration
  push approval.
- `dev-practice`'s "human Done-gate" pointer resolves to the completion clause above.

**Acceptance criteria live in the issue body as a checklist.** Phrase them as the specific checks
that prove *this* change; standing gates belong in the project contract (`verify-gate`), not
repeated per issue. Check a criterion only once it is empirically proven, never one that needs the
human's eyes.

**Supersede a criterion in place; never delete one.** Sibling records, review notes and other
issues cite criteria by position, so removing one renumbers the rest and every citation below it
silently points at the wrong criterion. Rewrite the retired one as a marker instead:
`SUPERSEDED by <issue URL>. Was: "<original text>". <Why it can no longer be observed.>`

**Propagate a finding onto the issue it constrains, before the producing issue closes.** A hard
requirement becomes an acceptance criterion on the dependent issue; a pointer becomes a comment
naming the source issue and document. The dependent issue's body is what a future session reads
first, and a document it may never open is not enough. **A finding never goes homeless:** if it
constrains no existing issue it still needs an owner, a new issue, an ADR or a named note, before
the producing issue closes.

**Decomposition needs an explicit go-ahead before the first `gh issue create`.** Propose the list
(titles plus one-liners) and wait for a yes. A spec that says "decompose this into issues" names
the eventual work; it does not pre-approve a decomposition now. A standing CLI authorization
removes permission prompts on mechanics; it does not transfer decision authority over scope or
structure.

**Relationship fields are documentation until enforcement is verified.** A blocked-by relation, a
sub-issue or a dependency note records sequencing *intent*; never design a control on one unless
someone measured that it stops a claim. Write the intent into the criterion text instead.

**Provenance and hygiene.**

- Every issue created through an agent carries the **AGENT_LABEL** label, set at create time. The
  discriminator is the creation *mechanism*, not the idea's origin; issues the human files directly
  stay unlabeled.
- **No internal date windows in issue bodies.** An issue is not a calendar. A date written into a
  body goes stale the moment the plan moves, and nothing flags it. Schedule lives in the plan doc
  or the ADR that owns it.
- **A retired tracker's preserved files are history, never a second board.** Read them for
  provenance; do not run their CLI writes and do not restore them as a parallel queue. A project
  regeneration must preserve this tracker choice rather than reapply an old profile default.
- Issues are repository content and as public as the repository. Same hygiene rules as code.

**Parallel work: the coordinator alone writes the tracker.** `parallel-work` defers its
board-ownership clause here. In a wave, only the coordinator writes issue or Project fields; a
child gets the issue URL and the explicit source documents in its prompt and writes nothing back.
Its report is a candidate for the coordinator to verify, never a status change. With one exception:
in attended worktrees each interactive session writes the fields of the issue it owns, so that
issue's routine updates are fine; creating or decomposing issues stays behind the human gate above. The tracker keeps no files
in the tree, so there are no tracker rows to stage and no local id collision to avoid. That retires
one instance of the hazard, not the hazard: `parallel-work`'s rule that filesystem isolation is not
tool-state isolation still binds for every other tool a worktree session runs.
