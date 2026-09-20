# agent-skills — the project contract

The rules for running work **in this repository**, shared by both hosts. `CLAUDE.md` imports it;
`AGENTS.md` names it as a read. Operating facts about the repository itself — the
checkout-is-the-install rule, the hooks, the leak guard, the commit-attribution policy — live in
[`CLAUDE.md`](../../CLAUDE.md) and are not repeated here.

**Hand-written, and it stays that way.** Every other project gets this file stamped by
`init-project`. This repository is where that engine lives, and running it here would make the
engine's output a source file of the engine. So there is no engine run here, now or later: the knob
block below is maintained by hand, in the shape the engine writes, and the `chunks/` bodies that
read it are imported one at a time rather than through `dev-base`.

## Execution and review defaults

The `implement-run` chunk carries the procedure. This block carries what varies here.

<!-- knobs:implement-run -->
- shape: subagents
- layout: serial — one checkout, prose deliverables, no fan-out to keep disjoint. A worktree here is
  for ref surgery (`CLAUDE.md` § Load-bearing facts), not for an implementer — **except that a
  change editing many Chunks at once takes one, because the checkout is the install and a
  half-rewritten library is live in every project the moment it touches disk.** It stages the edits
  into one squash; it is not isolation. Both hosts' symlinks keep pointing at the main checkout
  while it runs, so a resolution check against them proves nothing until after the merge. Remove it
  once it has landed and show `git worktree list` in the closing record.
- gate_runner: coordinator — this repository stamps no project-local agents, so no gate-runner seat
  resolves and the coordinator runs the gates and says so. The gates are the leak-guard scan
  (`.githooks/leak-guard.sh scan`), the word and count checks a ticket names, and resolution checks
  on both hosts' symlinks; there is no test suite and no typecheck.
- advisor: advisor
<!-- /knobs:implement-run -->

**Wrap-commit push carve-out.** An end-of-session close-out that commits a promotion here — a
Chunk or Skill edit written from a session rooted in another project — may push `main` without a
separate approval, after the leak-guard scan. The checkout is the install on every machine, so an
unpushed promotion is live on one box and absent on the other. The `reviewed` tag marks the
frontier of the later bloat review (`/review-promotions`); a close-out commit never moves it.

**A prose deliverable is verified by an agent following it, never by re-reading it.** Everything
here is prose an agent executes, so a ticket that changes a Skill, a Chunk or a Template closes on
a playthrough against a throwaway target — "where did you guess, where did the text contradict
itself, what did it name that does not exist" — and the Claude arm names the global instruction
file as a confound, with file attribution as the discriminator.

## Issue tracker

Work lives in GitHub issues, driven through the `gh` CLI; the convention is the Chunk's, and the
values under it are this repository's.

@~/.claude/chunks/tracker-github.md

That import is external and carries the same one-time-approval caveat as the one in
[`CLAUDE.md`](../../CLAUDE.md) ([ADR 0001](../adr/0001-import-from-home-chunk-delivery.md)); a
seat opens `chunks/tracker-github.md` itself.

The block below is maintained by hand, for the reason at the top of this file.

<!-- knobs:tracker-github -->
- REPO: cpalaka/agent-skills
- RESULTS_DIR: none
<!-- /knobs:tracker-github -->

Two pointers sit beside it, hand-written here for the same reason:

- **`docs/agents/issue-tracker.md`** — the canonical tracker pointer. `code-review`'s Spec axis
  reads it by path; `triage`, `to-tickets` and `wayfinder` expect it by description.
- **`docs/agents/triage-labels.md`** — the map from the triage-label roles skills speak in to this
  tracker's gate labels.
