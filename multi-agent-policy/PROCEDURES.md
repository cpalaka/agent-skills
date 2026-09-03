# Multi-agent policy: situational procedures

Two procedures that fire only when a specific kind of multi-agent session is being set up, kept
out of `SKILL.md` so a normal fan-out does not pay for them. Everything in `SKILL.md` still applies;
these narrow it and override nothing. Read this when you are:

- **granting an orchestrator hands-off execution of a ticket**: *Hands-off ticket design*
- **about to run a planning or decision session over a multi-session doc corpus**: *Doc-corpus
  consistency sweep*

## Hands-off ticket design (autonomous execution grants)

When the user wants a ticket, or a chain of them, executed by an orchestrator with zero involvement,
merges, pushes, cleanup and Done included, convert the ticket's gates rather than skipping them
(established 2026-08-03):

- **Record the grant in the artifact the executing session will read**, the task's own notes, and
  not only chat. State what is waived (sign-off and review DoD items; merge, push and
  branch/worktree cleanup confirmations), what stays in force (force-push, PR/`gh` writes,
  `--no-verify`, the verify gate itself), and the case that still escalates: a foreign commit
  riding the push would publish someone else's work under the grant, so stop and ask.
- **Convert every human-eye AC into a machine probe.** "Audio audibly stops" becomes the adapter
  receiving destroy and the element leaving the DOM; "feels right after clicking" becomes
  dispatched events asserted on observable effects. An AC only a human can check makes the ticket
  structurally hands-on whatever the grant says. Conversion has a ceiling: what the machine cannot
  self-certify batches into one deliberately human ticket at the end of the chain, rather than
  every AC being forced into a probe.
- **Demote look-checks to non-gating committed artifacts** (screenshots plus paths appended to the
  task's notes) for async review. This is legitimate only when an upstream approved
  design-reference task carries the frozen feel verdict. It narrows the standing rule that
  visual/feel work runs solo and never as a background wave, without displacing it: the feel
  verdict moves upstream, and only the implementation tickets become wave-able.
- **Make the close-out an explicit AC** (gate green, merge, push, cleanup, Done) so the autonomous
  finish is checkable rather than improvised.

## Doc-corpus consistency sweep

Before a planning or decision session that consumes a multi-session doc corpus, run a cheap
workhorse-tier consistency sweep first: per-doc auditors, a cross-doc reconciler, and a
surviving-open-inventory agent. Verify, then apply only provenance-derivable fixes; an `[open]`
stays open. The planning session should never be the thing that discovers doc rot, and the
inventory doubles as the wall of items it must not silently resolve.
