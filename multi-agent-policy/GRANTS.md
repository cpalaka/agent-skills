# Hands-off execution grants

Read this when the owner wants a ticket, or a chain of them, executed with zero involvement —
merges, pushes, cleanup and Done included. Nothing loads it by default, and it narrows the
`implement-run` Chunk rather than overriding it: a grant converts a ticket's gates, it never
skips them (established 2026-08-03).

- **Record the grant in the artifact the executing session will read**, the task's own notes, and
  not only chat. State what is waived (sign-off and review DoD items; merge, push and
  branch/worktree cleanup confirmations), what stays in force (force-push, PR/`gh` writes,
  `--no-verify`, the verify gate itself), and the case that still escalates: a foreign commit
  riding the push would publish someone else's work under the grant, so stop and ask.
- **Under a grant, commit the ticket's In Progress edit on the feature branch, not on `main`.**
  The Done stamp lands on the branch (`git-flow-squash`), so an In Progress commit on `main`
  guarantees the squash-merge conflicts on the task file every time — two edits to one row
  from two sides of the merge base. Farm the worktree, move the row inside it, commit there.
  Only the pin onto a dependent row (an edit to a DIFFERENT file) stays on `main`.
- **Convert every human-eye AC into a machine probe.** "Audio audibly stops" becomes the adapter
  receiving destroy and the element leaving the DOM; "feels right after clicking" becomes
  dispatched events asserted on observable effects. An AC only a human can check makes the ticket
  structurally hands-on whatever the grant says. Conversion has a ceiling: what the machine cannot
  self-certify batches into one deliberately human ticket at the end of the chain, rather than
  every AC being forced into a probe.
- **Demote look-checks to non-gating committed artifacts** (screenshots plus paths appended to the
  task's notes) for async review. This is legitimate only when an upstream approved
  design-reference task carries the frozen feel verdict. It narrows the standing rule that
  visual/feel work runs attended and never as a background wave, without displacing it: the feel
  verdict moves upstream, and only the implementation tickets become wave-able.
- **Make the close-out an explicit AC** (gate green, merge, push, cleanup, Done) so the autonomous
  finish is checkable rather than improvised.
