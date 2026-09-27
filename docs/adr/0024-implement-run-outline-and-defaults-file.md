# `implement-run` is an outline plus stage files, and its defaults live in one file

**Status:** accepted — 2026-09-27. Decided on cpalaka/agent-skills#140, whose § Decisions records
the owner's choices; this entry records its decisions 1, 4, 6, 7 and 9. ADR 0023 § 11 (dials
global, knobs per project) stands. The layout lands on #141; the defaults file, its reading rule,
the precedence and the inheritance land on #142.

## Context

`implement-run/SKILL.md` was 6,207 words, all injected when the Skill loads (#140 § Source, which
gives the per-section counts). A coordinator received how to close, how to run the `workflow`
shape, and how to act inside a batch or across repositories before it had written a plan, and by
the review or the close the rules for that step were the oldest text in its context. A run the
owner attends, in the default `subagents` shape and rooted in the ticket's own project, never uses
§ Workflow shape, the batch paragraph or the cross-repo paragraph: 1,937 words, 31%.

Default values were restated outside the Skill. `8ceb612` changed one default, edited four files,
and still missed a fifth copy (`CONTEXT.md`'s **add-on** entry). `init-project/defaults.md` held a
second copy of the five knob defaults, stamped into each project's contract, where the copy then
overrode the Skill, so a changed default never reached a stamped project.

## Decision

1. **The layout.** `SKILL.md` is an outline: frontmatter, the opening lines, a file table, the
   Knobs paragraph, § Seats, § Start, § Advisor slots with its Fallback, and § Handoffs. The rest
   moves to stage files beside it, each read at its trigger:

   | File | Read |
   |---|---|
   | `profile.md` (§ Run profile) | at the plan step, before posting the profile |
   | `review.md` (§ Review) | when the implementer returns, before its diff is committed or any review dispatched; under `workflow`, when the script returns |
   | `close.md` (§ Close, the run record, the re-cost rule) | before offering the Close approval |
   | `batch.md` (§ Inside a batch) | first, where a brief states the owner's delegation |
   | `cross-repo.md` (§ Cross-repo gate-runner) | where the session is rooted outside the ticket's project, or the project's `gate_runner` seat was stamped since the session started — first in the first case, at the plan step before the shape is chosen in the second; after `batch.md` where both hold |
   | `workflow-shape.md` (§ Workflow shape) | where `shape` resolves to `workflow` |

   The split moves text and changes no rule. **Where the files are:** beside `SKILL.md`, in the
   directory the loader names (`Base directory for this skill: <path>` on a slash load), else the
   directory of the path `SKILL.md` was read from, since a delegated coordinator reads it by path.
   `SKILL.md` states this once, beside the table.
2. **Citations keep resolving through the table.** The file table maps each section heading and
   the paragraph anchors under it to its file, so a live citation such as "`implement-run`
   § Run profile" needs no edit. A later change may rename, merge or cut a cited heading, anchor or
   term only by re-pointing every live citation of it. Citations outside this repository (the
   private companion, stamped projects) are not all visible to a grep here, so such a rename is
   never made on an in-repo count alone.
3. **One defaults file, values only.** Every default knob and dial value lives in
   `implement-run/defaults.yaml`, which #142 lands, each value with a comment giving its range and
   keyed by the knob name or dial token verbatim. Judgment stays in prose: when to recommend an
   add-on, what a stop means, which plan is light, how the gate tier is derived. No other live
   text states a default's value; it names the key. The coordinator reads the file at Start, every
   run.
4. **Its failure rule.** A file that cannot be read, a key the Skill expects that is missing, or a
   value outside its range is a stop naming the file, the key and the value — never a guess and
   never a silent fallback, since the prose no longer holds a value to fall back on.
5. **Precedence** is stated once in `SKILL.md`, landing with the defaults file on #142. A knob takes the project contract's key where
   present, else the file's — per key, where before only a missing block was defined. A dial
   starts at the file's value, is derived for the plan where `profile.md` says so, is raised by a
   pin, and is lowered only by the owner.
6. **A value change needs no ADR.** Editing `defaults.yaml` is the decision and its git history is
   the record. ADRs record mechanisms, not current values.
7. **Projects inherit the knob defaults.** `init-project` stops writing an `implement-run` knob
   block. A project overrides a knob by writing that key into its own contract; one that writes
   nothing follows the file.

## Considered options

- **Keep one file and shorten it.** Rejected as the whole answer: a shorter file still injects the
  close, batch, cross-repo and `workflow` rules before the plan. The trim is a separate child of
  #140, applied after the split.
- **Re-point every citation to a file instead of resolving through the table.** Rejected: the
  citing files include the private companion and stamped projects, which no grep here fully sees,
  and one table row is cheaper to keep true than a citation set spread across repositories.
- **Keep defaults in prose with a census that finds the copies.** Rejected: `8ceb612`'s missed
  copy is what a census over prose misses, and the owner could still not change a value without an
  agent to find it.
- **Keep the stamped knob block and re-stamp on a default change.** Rejected: the copy overrides
  the Skill, so every stamped project silently diverges until someone re-stamps it; per-key
  override gives a project that means to differ the same power without the copy.

## Consequences

- A default-shape run reads `profile.md`, `review.md` and `close.md` at their steps and never the
  other three stage files; that is the playthrough observable on #141.
- The coordinator definition reads `SKILL.md`, then `batch.md` beside it, deriving the path from
  the one its brief hands it; the brief does not change.
- `defaults.yaml` sits in a Skill's directory, so it is an instruction file: a ticket editing it is
  above the light plan, and an owner edit mid-batch ends a batch at `implement-batch`'s snapshot.
  Both are intended.
- A typo in the file stops the next run with the key named rather than running on a guess.
- Existing knob blocks are removed where they only restate the file's values; this repository's
  hand-written block keeps the keys it deliberately overrides (`layout`, `gate_runner`). A block a
  re-run finds is kept verbatim and read `orphan` by `check`, so no deliberate override is deleted.
- ADR 0023's values become history; the live ones are the file's (#142 adds the pointer to 0023's
  status line). ADRs and `.scratch/` records are not rewritten to match.
