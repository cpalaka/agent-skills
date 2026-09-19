<!-- chunk:git-commit-format | kind: invariant | single-source: agent-skills/chunks/git-commit-format.md -->
<!-- Delivered by @import via ~/.claude/chunks/. Edit here only — no per-project copies, no parity. -->

## Commit format & hygiene

**Subject line — conventional-commit shape.** Write the subject as
`<type>(<scope>): <imperative summary>`. Pick the one `<type>` that matches the
*dominant* change (`feat`, `fix`, `chore`, `docs`, `refactor`, `test`). Keep the
whole subject ≤~72 chars including the scope — tighten the summary rather than
overflow, and on a task-tracked project **never drop the task id to make room**
(tighten the summary instead). The `<scope>` is the slice/subsystem the change
lives in; on a task-tracked project it also carries the owning task id (see
`backlog-core` for the `<area>/task-NNN` scope convention and the `Refs task-NNN`
footer that links commit ↔ task).

**Body — what and why.** State what changed and, more importantly, *why*. Call
out notable deviations from the plan/spec (and the reason) so a reviewer is not
surprised. Footers carry traceability links.

**Pass a body with backticks through `-F <file>`, never `-m "…"`.** Inside double
quotes the shell command-substitutes every backtick span and puts the *empty*
result in its place, so a body naming code (`result.foo = foo`, a flag, a path)
commits with those spans **deleted**. Bash prints `command not found` to stderr
and `git commit` still exits 0, so the only evidence is stderr noise beside a
green commit — and a commit message is an artifact nothing re-reads, so the loss
surfaces, if ever, when someone goes looking for the reasoning it was supposed to
carry. Write the body to a file **inside the repo** and pass `-F` (the same
remedy `gh` needs via `--body-file`, for a different mechanism: a sandboxed and an
unsandboxed shell resolve different `$TMPDIR`, so a file written by one is empty
to the other). Caught while unpushed, `git commit --amend -F <file>` is the fix.

**That file's FIRST LINE is the subject — write it, then a blank line, then the
body.** `-F` takes the whole file as the message verbatim, so a file holding only
the body silently promotes its entire opening paragraph to the subject line: a
multi-sentence subject hundreds of characters long, blowing the ≤~72 rule and
taking the `<type>(<scope>):` prefix with it. Nothing warns. `git commit` exits 0
and prints the runaway subject in its own first line, which is the only tell —
read it, the same way the branch name on that line is read. The shape that cannot
fail is to build the file with the subject printed separately from the body
(`{ printf '%s\n\n' "$SUBJECT"; cat body.txt; } > msg.txt`) rather than trusting a
heredoc to have started with it. Unpushed, the fix is again
`git commit --amend -F <file>`. Measured 2026-09-18.

**One logical change per commit.** Each commit should be a single coherent unit
of work whenever possible. Multiple commits on a branch are fine — how a branch
is integrated (squash vs. merge commit) is the git-flow fork's concern, not this
chunk's.

**Stage by explicit file path — never `git add <dir>/`.** Directory-level staging
silently sweeps in untracked strays near your write paths (a concurrent session's
files, editor droppings), and multi-session repos make strays the expected case.
The commit takes the whole index, so a peer's already-staged file rides a commit
that names only your paths: read `git diff --cached --stat` before committing and
stop — do not unstage it — if it lists a path you did not change. Backstop: read
the commit's `--stat` output before any push.

**Re-verify the current branch immediately before every commit.** In a shared
checkout a parallel session can create and switch branches under you, so the
branch you confirmed at session start does **not** bind at commit time. The
commit then *succeeds* on the wrong branch, and the only signal is the branch
name in `git commit`'s own first line — read it. Work stranded on a foreign
feature branch rides that branch's eventual squash-merge under someone else's
message: the content survives, the provenance does not, and nothing flags it.
If a commit landed wrong **and** the branch is the integration branch plus your
commit only, recover with a pure fast-forward —
`git merge-base --is-ancestor main <sha> && git branch -f main <sha>` — guarding
on the ancestor test so the verdict is *derived*, not assumed. Never
`git checkout main` to fix it while another session holds the checkout; that
inflicts the same harm in the opposite direction.

**Never amend an already-pushed commit without confirming.** Once a commit is on
`origin/<branch>`, do not `git commit --amend` (or otherwise rewrite that
history) without explicit confirmation — it forces a non-fast-forward push that
can clobber shared history. Rewriting *unpushed* local commits is fine. (The
force-push that a confirmed rewrite then requires is itself gated — see
`git-confirm-destructive`.)

**Never bypass hooks.** Do not pass `--no-verify`, `--no-gpg-sign`, or any
equivalent flag that skips a configured commit/push hook. The hooks are the gate;
suppressing them defeats the verification they exist to enforce. If a hook fails,
fix the cause — never silence the check.
