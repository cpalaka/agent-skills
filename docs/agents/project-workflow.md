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
frontier of the later bloat and redundancy review; a close-out commit never moves it, and the
review moves it with `git tag -f reviewed HEAD` and pushes it with `-f`.

**A prose deliverable is verified by an agent following it, never by re-reading it.** Everything
here is prose an agent executes, so a ticket that changes a Skill, a Chunk or a Template closes on
a playthrough against a throwaway target — "where did you guess, where did the text contradict
itself, what did it name that does not exist" — and the Claude arm names the global instruction
file as a confound, with file attribution as the discriminator.

## Issue tracker

Work lives in GitHub issues on [cpalaka/agent-skills](https://github.com/cpalaka/agent-skills/issues),
through the `gh` CLI. There is no board and no PR surface.

- **Reading.** Open work is `gh issue list --label ready-for-agent`. Ignore every issue whose title
  begins `Spec: ` — those are parents and close when their children do. The next ticket is the
  lowest-numbered issue left whose `blockedBy` issues are all closed
  (`gh issue view <n> --json blockedBy`, nested under `.blockedBy.nodes`). `gh issue list` lags a
  fresh creation by seconds and returns a partial list silently, so confirm a new issue with
  `gh issue view <n>`.
- **Writing.** Progress, evidence and run records are **issue comments**, under the `implement-run`
  chunk's rules for the closing record. Bodies and comments go through a temporary UTF-8 file and
  `--body-file`.
- **The leak guard does not see a `gh` write.** It scans the git object store only, so grep any
  body or comment file against both pattern lists before posting (`CLAUDE.md` § Load-bearing
  facts). Every `gh` write is a human-gated action.
- **Closing.** The squash-merge and the run record close the ticket together, in one approval with
  the push; a ticket whose acceptance needs the owner's own run stays open until they accept. The
  git flow is unchanged — squash, per `chunks/git-flow-squash.md`.
