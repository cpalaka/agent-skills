<!-- chunk:tracker-github | value-variant | edit only at agent-skills/chunks/tracker-github.md — no per-project copies -->
## Task tracking (GitHub Issues)

Issues on **REPO** are the **single source of progress**; `docs/adr/` stays the only decision
system.

**Load the `tracker-github` Skill before any `gh issue` or `gh label` write.** Every other
section moved there under its old heading, so a "§ <heading>" citation of this
Chunk resolves there.

**Bodies.** Multi-line bodies and comments go through a UTF-8 file **inside the
repository** and `--body-file`, removed after — shells disagree on `$TMPDIR`, so `"$(cat …)"` can
post an empty body while `gh` reports success. A leak guard never sees a `gh` write: where one
exists, scan each body from a path the scan walks, beside a known-bad confirmed to match its list,
and read the match **count**, not the exit status — anything above the plant's own is a real hit.
`gh issue list` lags a fresh creation and truncates silently; confirm with `gh issue view <n>`.

**Gated writes** (`git-confirm-destructive`'s gate): creating, closing, reopening, deleting or
transferring an issue; rewriting a body; editing or deleting a comment; editing a label
(`gh label create --force` included) or deleting one. Other issue and label writes, and reads,
need no approval — but a ticket's gate and whether to mint stay the owner's.

**Search first.** Before filing an unplanned ticket, run
`gh issue list --state open -L 200 --search '<a noun from the finding>'`; on a match, comment new
evidence instead of filing a duplicate.
