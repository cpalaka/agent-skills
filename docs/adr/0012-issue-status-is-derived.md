# Issue status is derived from open state, gate label and blocked-by; never from a board or a body rewrite

**Status:** accepted — 2026-09-19

The GitHub tracker Chunk stored status in two places, and neither could be read without first
being written. A private Project board held a column per issue, so a session's first act was a
board write and its last was another; and acceptance criteria lived in the issue body as a
checklist, so ticking one meant `gh issue edit --body`, which replaces the body wholesale. Both
are stores, and both drift. A column says nothing that a closed state and a label do not, and it
says it only to whoever opens the board. The body rewrite is worse than redundant: the body is the
specification the ticket was filed with, GitHub has no per-checkbox write, and a concurrent edit
is clobbered with nothing reporting it. Meanwhile the two things a session actually needs — may I
start this, and is it next — were stored nowhere at all, and each repository inferred them
differently: one from a title prefix, one from prose, one from a wayfinder label.

**Decision.** Status is **derived**, never stored, from three native inputs: the issue's open
state, its **gate label** and its **blocked-by** edges. The assignee is not a fourth input; it is
the claim marker, saying that a session has taken the issue, not where the issue stands. Two label axes carry
everything a session routes on — a gate label (`gate:agent`, `gate:accept`, `gate:decide`) saying
what a session may do with an issue, and an **origin** label saying why the issue exists —
thirteen labels per repository, wayfinder's five included. The **frontier** is a query over those
inputs, and a session **claims by assignment**: `--add-assignee @me` is its first write, so a
concurrent session skips the issue. The gate label also picks the commit footer: `Closes` under
`gate:agent`, so the issue closes atomically with the merge and no failed push strands it; `Refs`
under `gate:accept`, leaving it open for the owner; no footer under `gate:decide`, which is never
worked. Progress is recorded in a **closing record** comment, never in the body — the body is the
spec, and the one permitted rewrite is supersede-in-place, because citations resolve by number.
**A board is a view**: where a project runs one, an agent never writes a board field.

**Considered options.**

- **(a) Keep the board columns and the body checklist.** Rejected: both are writes that record
  what a read already answers, and the body write risks clobbering the ticket's own
  specification. The column has no reader either — nothing in the pipeline Skills queries a
  Project field, while every one of them can query a label.
- **(b) Derive status, but tick the checklist as a courtesy to a human reader.** Rejected: two
  stores of one fact diverge, and the cheaper one to update silently wins. The closing record
  gives a human reader strictly more than a tick — each criterion, its evidence, and the commit
  SHA of the tree that was reviewed — in a write that appends rather than replaces.
- **(c) Derive from native state alone.** Chosen. It is the shape two repositories had already
  converged on by hand, and every input is something the tracker itself enforces rather than
  something a convention asks an agent to remember.

**Consequences.**

- **[ADR 0002](0002-git-flow-structural-fork.md)'s coupled-rules test, answered for GitHub.**
  [ADR 0013](0013-retire-unused-chunks.md) left one git-flow variant, and the three rules that
  ride it still ride it. Under this tracker the merge model is unchanged; the branch-name prefix
  takes the issue number in place of the board's task id; and the notes-SHA policy **has no
  subject**, because there are no board notes — the reviewed commit's SHA lives in the closing
  record instead. A fourth resolution falls out of the footer rule: there is nothing to mark Done
  on the branch, so the integration commit carries code only. The pre-push audit predicate rides
  the fork and is untouched by the tracker.
- **A project importing the tracker Chunk is not board-less**, so the variant's board-less
  exception does not fire; and its board-grooming push exception has no analogue, because this
  tracker keeps no files in the tree.
- **The heavy convention is relocated, not deleted.** Its start-authorization comment, its
  per-issue records directory, its agent provenance label and its five-class approval list are a
  real policy that one project runs on. They move into that project's own policy file, where they
  bind one repository instead of every adopter. Four knob keys retire with them, and the Chunk
  names all four so a contract still carrying them is recognisable at a glance.
- **Thirteen labels are a vocabulary, and a vocabulary has to be minted — and an unminted one
  fails asymmetrically.** Applying a label that does not exist errors, so the write path fails
  loudly. The read path does not: `gh issue list --label <missing>` returns an empty set at exit
  0, so the frontier query answers `null`, which is indistinguishable from an empty frontier —
  and the read is the first thing a session runs. The Chunk therefore pairs the query with
  `gh label list` as the discriminator. It defines the values once; the Profile's mint and this
  ADR cite them and redefine none.
- **A derived status keeps no history of its own.** It is computed from the current labels,
  edges and open state, and the derivation remembers no previous answer. The underlying events
  are recorded — the issue timeline carries `labeled`, `assigned` and `closed` with timestamps —
  so a reader who wants the history reads the timeline. Storing a status field to hold it would
  be a new decision, and it would not be a board column.
