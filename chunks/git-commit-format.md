<!-- chunk:git-commit-format | invariant | edit only at agent-skills/chunks/git-commit-format.md — no per-project copies -->

## Commit format & hygiene

**Subject `<type>(<scope>): <imperative summary>`, ≤~72 chars; never drop the task id to make
room.** `<type>` matches the *dominant* change; `<scope>` is the slice/subsystem — task-id and
footer forms: the tracker chunk. **Body: what changed and why**, plus deviations.

**Body through `-F <file>`, never `-m`: that file's FIRST LINE is the subject, then a blank line,
then the body.** Either mistake exits 0 (2026-09-18). Write that file inside the repo, never
`$TMPDIR` (`sandbox-and-permissions`).

**One logical change per commit.**

**Stage by explicit file path — never `git add <dir>/`**; the whole index ships, so read
`git diff --cached --stat` first: a path you did not change means stop — **do not unstage it**.

**Re-verify the branch immediately before every commit** — a peer can switch it under you and the
commit *succeeds*; the tell is the branch name in `git commit`'s first line, so read it. Landed on
the wrong branch: `parallel-work`.

**Never bypass hooks**: no `--no-verify`.

Shared checkouts: `parallel-work`; sandbox: `sandbox-and-permissions`, or
`codex-sandbox-and-approvals` on Codex; integration: `git-flow-squash`.
