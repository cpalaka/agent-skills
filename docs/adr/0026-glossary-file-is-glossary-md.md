# The glossary file is `GLOSSARY.md`, following upstream's rename

**Status:** accepted — 2026-10-23. Does not edit ADRs 0014–0024, which name the file `CONTEXT.md`:
an accepted ADR is a record, and the file they describe is the same file under a new name.

The domain glossary every kept project carries was `CONTEXT.md`, the name the third-party
`domain-modeling` Skill used when this library adopted the convention. Upstream renamed it to
`GLOSSARY.md` in August 2026, on the argument that a file which is "a glossary and nothing else"
should say so, and its installed Skills (`tdd`, `pr`, `diagnosing-bugs`, `wait-what`) read only the
new name. Keeping `CONTEXT.md` meant those Skills silently skipped the glossary wherever no
SessionStart hook injected it, and meant this library's own `domain-modeling` carried the name as a
fork rather than for any reason of its own. The alternative, pinning the upstream Skills at their
pre-rename version, was rejected as a maintenance line with no end. So the file is `GLOSSARY.md`,
`CONTEXT-MAP.md` is `GLOSSARY-MAP.md`, and the format file is `domain-modeling/GLOSSARY-FORMAT.md`.
Trees not yet renamed keep working: the owner's SessionStart hook looks for `GLOSSARY.md` first and
falls back to `CONTEXT.md` until each is renamed on its next open.
