# `tracker-github` splits into an always-on core Chunk and a Skill

**Status:** accepted — 2026-09-28. Amends [ADR 0014](0014-floor-is-a-location.md) § 1 ("The
tracker Chunks (`backlog-core`, `tracker-github`) stay Chunks") and the § 7 sentence calling the
tracker Chunks not condensed, and [ADR 0015](0015-chunk-cap-250-ceiling-2900.md)'s Consequences
sentence reporting the tracker Chunks without a target, for `tracker-github` only. Does not edit
0014, 0015 or 0016: an accepted ADR is a record, so this entry names the sentences it supersedes
instead.

## The measurement that forced this

`chunks/tracker-github.md` was **10,768 bytes / 1,694 words**, loaded at every session start in
each importing project. In one importing game project, **127 of 266 sessions ran no `gh issue` or
`gh label` command at all**. Of the 139 that did, 122 ran inside a tracker-driving slash command,
which can load what it needs itself; 17 did not, and 11 of those 17 wrote to the tracker. A
headless first call in that project measured **43,137 prompt tokens** before the split
(2026-09-28); the after figure is in #147's closing record.

So most of the Chunk is read by sessions that never touch the tracker, but a minority write to it
with no tracker Skill loaded, and those need the rules that keep a write safe.

## Decision

1. **The core stays `chunks/tracker-github.md`**, filename kept so every `@` import resolves
   unedited. It holds four rules — issues as the single source of progress with `docs/adr/` the
   only decision system; the `--body-file` rule with the leak-guard screen and the `gh issue list`
   lag; the gated set; search-first before filing an unplanned ticket — plus one sentence naming the
   Skill and one redirect: every other section is in the Skill under the same heading, so an
   existing stamp's "the chunk's § X" citation still resolves. The claim moves to the Skill.
2. **A `tracker-github` Skill** holds everything else, verbatim or tighter, headings kept: the label
   axes, parents and decomposition, frontier and claim, footer and closing record, acceptance and
   re-gating, unplanned tickets, wayfinder and boards, commit forms, knobs. A rule that moved into
   the core is a pointer at its old spot in the Skill, never a second copy.
3. **Three routes load it.** Its description fires from context before any `gh issue` or `gh label`
   write; the core names it; and the tracker-driving Skills (`implement-run`, `implement-batch`,
   `parallel-work`, the private companion's `wrap-session`) load it explicitly, with the pointer
   Template (`init-project/templates/tracker/issue-tracker.md`) naming it for third-party Skills
   that reach the convention only through that pointer.
4. **`backlog-core` does not follow.** It is frozen ([ADR 0022](0022-tracker-is-an-engine-step.md)
   § 7), and its no-target reading stands.
5. **The core is held to the 250-word condensed-Chunk cap** ([ADR 0015](0015-chunk-cap-250-ceiling-2900.md)
   § 1), counted by `wc -w` over the whole file, header included, and read by this repository's
   floor check before every commit. It stays **outside** the four-plus-bundle sum, which remains
   the four Chunks `dev-base` imports plus `dev-base`.
6. **This ADR** records the split and the cap.

### Sentences superseded, by file

- `docs/adr/0014-floor-is-a-location.md` § 1: "The tracker Chunks (`backlog-core`,
  `tracker-github`) stay Chunks: they are always-on for the projects that import them." —
  superseded for `tracker-github`, which is now a core Chunk plus a Skill.
- `docs/adr/0014-floor-is-a-location.md` § 7: "The tracker Chunks (1,703 and 1,853 words) are
  always-on and not condensed here" — superseded for `tracker-github`, whose core is now condensed
  and capped.
- `docs/adr/0015-chunk-cap-250-ceiling-2900.md` Consequences: "`dev-base` at 80 and the tracker
  Chunks reported without a target are unchanged." — `tracker-github` is now read against 250.
- `docs/adr/0015-chunk-cap-250-ceiling-2900.md` § 2 and `docs/adr/0016-floor-ceiling-is-acceptance-time.md`
  § 5 exclude "the tracker Chunks" / "the tracker Chunk" from the per-project floor sum and report
  each beside it. That exclusion stands; what changes is that the `tracker-github` core reported
  beside the sum now has a 250-word cap of its own.

`backlog-core`'s no-target reading stands everywhere it is stated.

## Considered options

- **Keep the Chunk whole.** Rejected on the session counts: 127 of 266 sessions paid 1,694 words
  for a convention they never used.
- **Skill only, no core.** Rejected: the gated set and the body rule must bind the 17 sessions that
  drove `gh` outside any tracker Skill, 11 of which wrote. A description firing from context is
  not a guarantee, so the rules that keep a write safe stay always-on.
- **`backlog-core` follows.** Rejected: it is frozen (ADR 0022 § 7), and a frozen Chunk is not
  reworked.

## Consequences

- A stamp's older "the chunk's § X" citations resolve through the core's redirect, so no stamped
  project needs a re-stamp for the split to read correctly; the pointer Templates are updated for
  new stamps.
- A machine needs the new `tracker-github` Skill symlinked into both `~/.claude/skills` and
  `~/.agents/skills`: `bootstrap.sh` links `chunks/` only, so the Skill is linked like every other
  Skill here.
- This repository's floor check reads `tracker-github` against 250 beside the condensed Chunks,
  but outside the four-plus-bundle sum.
