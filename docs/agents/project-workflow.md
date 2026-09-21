# agent-skills — the project contract

The rules for running work **in this repository**, shared by both hosts. `CLAUDE.md` imports it;
`AGENTS.md` names it as a read. Operating facts about the repository itself — the
checkout-is-the-install rule, the hooks, the leak guard, the commit-attribution policy — live in
[`CLAUDE.md`](../../CLAUDE.md) and are not repeated here.

**Hand-written, and it stays that way.** Every other project gets this file stamped by
`init-project`. This repository is where that engine lives, and running it here would make the
engine's output a source file of the engine. So there is no engine run here, now or later: the knob
block below is maintained by hand, in the shape the engine writes, and the bodies that read it are
reached one at a time rather than through `dev-base`: the tracker Chunk by import, the
`implement-run` Skill by name.

## Execution and review defaults

The `implement-run` **Skill** carries the procedure — it is slash-only, so a run loads it by name
and reads the block below by marker — **from the file, never from context**, because the loader
strips every HTML comment on its own line from every injected copy (`CLAUDE.md` § the import
paragraph). This block carries what varies here.

<!-- knobs:implement-run -->
- shape: subagents
- layout: serial — one checkout, prose deliverables, no fan-out to keep disjoint. A worktree here is
  for ref surgery (`CLAUDE.md` § Load-bearing facts), not for an implementer — **except that a
  change editing many Chunks at once takes one, because the checkout is the install and a
  half-rewritten library is live in every project the moment it touches disk.** It stages the edits
  into one squash; it is not isolation. Both hosts' symlinks keep pointing at the main checkout
  while it runs, so a resolution check against them proves nothing until after the merge. It is also
  a different absolute path — before trusting what a session rooted in one has loaded, read
  § Issue tracker below, on external-include approval. Remove the worktree once it has landed and
  show `git worktree list` in the closing record.
- gate_runner: coordinator — this repository stamps no project-local agents, so no gate-runner seat
  resolves and the coordinator runs the gates and says so. The gates are the leak-guard scan
  (`.githooks/leak-guard.sh scan`), **the floor check** below, the word and count checks a ticket
  names, and resolution checks on both hosts' symlinks; there is no test suite and no typecheck.
  **The floor check**, run before any commit here: `wc -w` over every file in `chunks/`, each
  condensed Chunk against 250 and `dev-base` against 80, the two tracker Chunks reported with no
  target — **and the four-plus-bundle sum against 1,080**, because a per-file reading passes with
  four files at 249 while the floor grows, and ADR 0014 § 7 (amended by ADR 0015, then by
  [ADR 0016](../adr/0016-floor-ceiling-is-acceptance-time.md)) exists because nothing warned while
  it grew. 1,080 is the constructed maximum of the per-file caps, not a number fitted to the
  measurement, so the two are read as the pair ADR 0015 § 4 requires. The per-project floor ceiling
  is **not** read here and is read nowhere else either: ADR 0016 § 1 makes it acceptance-time, and
  § 4 declines to install an adapter-plus-contract gate anywhere until one has a trigger that can
  go green. A red reading is a decision the closing record names, not a block.
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
itself, what did it name that does not exist" — and the **dispatch** names the confound set,
rather than leaving the arm to volunteer it. A Claude seat is handed the whole instruction
hierarchy — both instruction files, this contract, the memory index, and the tracker Chunk where
the path is approved — so the dispatch reads the seat's own delivery record and names what is in
it, with file attribution as the discriminator. A Codex arm expands no `@` line and its set
differs; read it rather than reciting this one.

## Issue tracker

Work lives in GitHub issues, driven through the `gh` CLI; the convention is the Chunk's, and the
values under it are this repository's.

@~/.claude/chunks/tracker-github.md

**That import expands only where the host has approved external includes for this project path** —
per absolute path, per machine, recorded as `hasClaudeMdExternalIncludesApproved` under this
project's absolute-path entry in `~/.claude.json`, never in this repository.
[ADR 0001](../adr/0001-import-from-home-chunk-delivery.md) settles how Chunks are delivered, not
whether they load.

**Claude Code: read the shape of your context, not its words.** Expanded, the Chunk arrives as an
injected block of its own, under a `Contents of …` header ending in `chunks/tracker-github.md` —
spelled absolute, never the `~/` form the `@` line uses. Unexpanded, no such block exists anywhere
in your context. Any phrase quoted here would be in your context because this file is, so the
block is the only honest discriminator. Present, the tracker convention is loaded and you may rely
on it; absent, it is not, and you open `chunks/tracker-github.md` yourself. A seat dispatched
from a session that carries the block is handed it too (#35, measured at the delivery record);
where one reads absent, suspect approval first, a parent walk memoized before it second, the
seat boundary last. (Codex expands no `@` line and reads the Chunk explicitly; nothing to check
there.)

The knob block below is maintained by hand, for the reason at the top of this file.

<!-- knobs:tracker-github -->
- REPO: cpalaka/agent-skills
- RESULTS_DIR: none
<!-- /knobs:tracker-github -->

Two pointers sit beside it, hand-written here for the same reason:

- **`docs/agents/issue-tracker.md`** — the canonical tracker pointer. `code-review`'s Spec axis
  reads it by path; `triage`, `to-tickets` and `wayfinder` expect it by description.
- **`docs/agents/triage-labels.md`** — the map from the triage-label roles skills speak in to this
  tracker's gate labels.
