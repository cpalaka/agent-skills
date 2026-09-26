# The tracker is an engine step; a Chunk may be frozen with importers

**Status:** accepted — 2026-09-26. Extends [ADR 0013](0013-retire-unused-chunks.md)'s retirement
rule with a second end state for a Chunk that still has importers. Everything in 0013 stands.

## Context

`init-project` knew two trackers: the `tracker-github` Chunk, and the older `backlog-core` Chunk
with its local ticket files. GitHub Issues arrived as a Profile, `profiles/github.md`, which ran by
reference — the other Profiles pointed a seat at its sections mid-recipe, and its two Templates,
the issue-tracker pointer and the triage-labels map, lived under that Profile. A tracker is not a
project type: every type needs one, and a Profile that is also consulted by every other Profile is
engine code kept in the wrong place. Meanwhile no new project is stamped onto `backlog-core`, but
eight projects still import it (counted for spec #124), so 0013's zero-importer measurement cannot
retire it, and nothing said what a Chunk with importers and no future is.

## Decision

1. **The tracker is an engine step, `github` or `none`**, taken by no Profile. `profiles/github.md`
   is deleted; its Templates move under the engine, `init-project/templates/tracker/`.
2. **The remote check is a precondition**, run before the first write, with three outcomes: outside
   a git work tree, a **stop**; a work tree with no GitHub remote, **`none`**, settled in the same
   run with no offer; a GitHub remote whose `gh repo view` fails, a **stop** naming what `gh`
   printed — never `none`, since an expired token must not strip a project of its tracker. On
   success the owner picks `github` (the default) or `none`.
3. **The thirteen-label mint runs after the Profile's recipe and before `verify`**, for `github`
   only; a failing `gh label list` is a stop.
4. **`stamp` writes the tracker**: the `tracker-github` import, its knob block first, the two
   pointer files, and the contract's `## Issue tracker` section appended last. Under `none` it
   writes none of them.
5. **A re-run reads the outcome from the contract** — `knobs:tracker-github` is `github`,
   `knobs:backlog-core` is `held`, neither is `none` — and never re-asks, so a `none` project stays
   `none` after a remote is added.
6. **One tracker, not a manifest key.** The engine knows exactly `github` and `none`. A second
   tracker reopens this ADR; it does not arrive as a Profile or a key.
7. **A Chunk may be frozen with importers.** A frozen Chunk is kept in `chunks/` for its existing
   importers only, carries a one-line frozen header, takes no other edits, is stamped by nothing,
   and is reported by the floor check as frozen with no target. `backlog-core` is the first: a
   re-run over a project holding its block reads `held: backlog-core (frozen)` and keeps the block,
   the import and the read-list entry verbatim. When its last importer leaves, 0013's rule retires
   it.

## Considered options

- **Keep `github` a Profile.** Rejected: the other Profiles already ran it by reference, so it was
  engine code under a Profile's name.
- **A `tracker:` manifest key per Profile.** Rejected: every Profile would carry the same value,
  and a key with one value invites a second nobody has built.
- **Retire `backlog-core` now.** Rejected: 0013 retires on zero importers, and eight projects would
  lose a Chunk their contract still reads.
- **Migrate the eight onto `tracker-github`.** Out of scope for spec #124, which leaves those
  projects untouched; moving one is the owner's decision.

## Consequences

- **`init-project` emits six files plus one fragment, two of the files and the fragment
  conditional** on `github`; `CLAUDE.md` and `CONTEXT.md` give that count.
- **The body-file rule in the pointer Template is conditional** on the project guard's shape
  (issue #80): root placement where the guard walks the working tree honouring `.gitignore`, a
  gitignored path allowed where it reads tracked files only, the scratchpad ban in both.
- **[ADR 0021](0021-mechanical-stamping-is-a-script.md)'s known limits 1, 2, 4, 7 and 8 are closed
  by #127:**
  - **1** — godot's recipe edits no text inside its contract fragment: what varies per project is
    a fill prompt there, answered through the answers file, so `check` no longer reads the zone
    `differs` for a recipe edit and a re-run has nothing to restore.
  - **2** — godot's manifest marks `.mcp.json` and `.codex/config.toml` `after_freeze: true`, so
    the plain `stamp` skips them and the Skill's step 3 writes them with `stamp --after-freeze`
    once the lockfile-freeze is done.
  - **4** — the Skill now says what the adapter does: the canary is the last line inside its zone,
    and the zone's close tag is the file's last line.
  - **7** — `stamp` writes each in-zone fill between engine fill markers, and `stamp` and `check`
    read it back from the target's marker pair byte for byte; a boundary inferred from the new
    render could not tell the owner's text from Template text deleted beside the prompt. A prompt
    with no pair reads unfilled, so the D8 stop names the fill to give — an in-zone fill written
    before the markers included.
  - **8** — the contract records the stamped type on its first zone line, a re-run reads it, and an
    answers file naming a different type stops before any write.
- **godot's Blender pair is still a hand copy** in its recipe, with a `{{WORKSPACE_ROOT}}`
  substitution, because the manifest has no conditional-entry key; a follow-up ticket owns it.
- **A pre-#127 contract records no type**, so `check` reads its contract-sections zone `differs`
  until a re-run stamps the type line.
- ADR 0020's first stated gap — a current-layout `backlog-core` importer stopping at step 0 — is
  replaced by the `held` outcome above.
