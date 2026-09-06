<!-- chunk:git-flow-noff | kind: fork | single-source: agent-skills/chunks/git-flow-noff.md -->
<!-- Delivered by @import via ~/.claude/chunks/. Edit here only — no per-project copies, no parity. -->

## git-flow: `--no-ff` merge variant (opt-in)

This is the **opt-in** git-flow fork — a project imports exactly one git-flow variant, this
one *or* `git-flow-squash` (the default), never both. The three rules below ride this fork
**together**; do not mix any one of them with the squash variant's opposite rule. (The
structural-fork reasoning is in ADR-0002.)

**Integration = a `--no-ff` merge commit.** After the diff is approved, mark the task Done
**on the branch** and commit that there (`backlog-core`), then
`git checkout main && git merge --no-ff task-NNN-<slug>` (message per `git-commit-format`) —
**one real merge commit per task**, so the task reads as a single unit in history (merge
SHA ↔ task ID) and `main` stays at a known-good state between tasks. Do not squash and do not
fast-forward; the merge commit is the point. (Non-task chores — board/docs housekeeping — may
still commit straight to `main`.) **A sign-off approves a TREE, not a branch name:** if the base
moved between approval and merge — routine in a multi-session repo, and `--no-ff` reaches that
state often — rebase onto it and **re-run the verify gate** on the rebased result before merging.
A conflict-free rebase is exactly the dangerous case: nothing warns you, and the pre-rebase green
measured a combination that no longer exists.

**Shared checkout? Do not take `main` — build the merge commit and push its SHA.** If another
session shares this checkout, `git checkout main` moves *their* working tree, so don't
(`parallel-work` § "One clone per interactive session"). The `--no-ff` result is your branch's
tree with `origin/main` and your branch as its two parents **only while your branch is a linear
descendant of `origin/main`** — so derive that, and derive it first:

```sh
git fetch origin
git merge-base --is-ancestor origin/main HEAD   # MUST exit 0 — this is the verdict
M=$(git commit-tree "$(git rev-parse HEAD^{tree})" -p origin/main -p HEAD -F msg.txt)
git push origin ${M}:main            # fast-forward; never touches the local `main` ref
```

If `--is-ancestor` exits non-zero, `origin/main` moved while you were in review: rebase onto it,
**RE-RUN THE VERIFY GATE** on the rebased result, and only then build `M`. Do not skip it —
`M` carries *your branch's* tree, so pushing it on a moved base silently reverts the peer's landed
files while leaving their commit visible in the graph, and the push is a clean fast-forward that
git will not question (measured). `git diff $M HEAD` must be **empty** and `git rev-parse ${M}^1`
must equal `origin/main`, but both hold by construction for any input — they are paste guards
against a mistyped tree or parent, and that is all they are. Pushing the SHA rather than the
branch also means a sibling's unpushed commit sitting on your local `main` cannot ride along. The
notes chore below then waits until you hold `main` again on your next pull — that later
board-only push is the second half of the same authorisation, not a new one. **The task is not
closed on the board until that chore lands**: say so in the handoff and land it at your next pull.

**Branch name = plain `task-NNN`.** Feature branches are named `task-NNN-<slug>` with **no
typed prefix** — created before the first commit of the task's work. (This is the deliberate
opposite of the squash variant's typed `<type>/task-NNN` form; never emit the typed prefix in
a `--no-ff` project.)

**SHA-in-notes is REQUIRED — appended AFTER the merge, not at marking time.** Done is marked
on the branch, so no merge SHA exists then; capture it in a second step. Immediately after the
merge, on `main`: `backlog task edit NNN --append-notes "Merged <full merge SHA>"` — write a
whole sentence with the **full** hash, because each appended string lands as its own
**paragraph** (measured, backlog 1.45.2), never inline — so a ` — merged …` continuation lands as
an orphan-dash line. (**`--notes` REPLACES the whole field** and would drop the summary —
`backlog-core`'s replace-vs-append trap.) Commit that as
`chore(backlog/task-NNN): record merge SHA` with a `Refs task-NNN` footer — the owning task
goes in the **scope** (`backlog-core`'s `<area>/task-NNN` rule); a plain `chore(backlog):`
subject is reserved for grooming no single task owns. It is a **board** commit, not a second
task commit, so **one real merge commit per task** stays true. The SHA is recorded here because
the merge commit *is* the task's unit in history under this variant. The squash variant omits it
**by policy, not because it has no room**: there the task↔commit link is already the subject
scope plus the `Refs task-NNN` footer, so a recorded SHA buys nothing. Never carry its no-SHA
rule into a `--no-ff` project. (`backlog-core` stays merge-agnostic and defers the notes-SHA
policy here.)

**Audit the working tree immediately before the merge — `git status --porcelain` must list only
the files you intended.** A GUI editor open on the project is a second writer that flushes its own
in-memory copies on its own schedule, so the diff that ships is not necessarily the diff that was
approved; treat any unexpected modification as editor spill, revert it, and make the editor reload
from disk before merging.

**Push authorisation — one merge, one push, no PRs.** Integration is a local merge, never a PR.
Never merge a branch that has not been reviewed, and never push `main` without that per-branch
diff approval. When a branch is ready, report it in chat: what's on it, what's verified, and
anything the reviewer should look at closely. The reviewer's sign-off on the diff authorises
**exactly one** `--no-ff` merge and **one** push of `main` carrying that merge commit and the
notes chore sitting on top of it — nothing more (the shared-checkout path above splits that one
push in two — same authorisation, not a second one); force-pushing `main` is never OK
(`git-confirm-destructive`). So push once, after the chore commit, and check both sides of the
merge first. On the ordinary path, **`git log --first-parent origin/main..main` must list only
those two commits.** `--first-parent` is not optional here — a `--no-ff` merge keeps
the branch's own commits in history, so a plain `git log origin/main..main` always lists them
too and the audit could never pass. A peer's unpushed commit sits on the integration line, so
`--first-parent` still shows it: if anything but your merge and its chore is in that list, STOP
and ask — never reset or rebase it out of the way. It sees nothing on the branch side, so note the
branch tip SHA at sign-off and check `git rev-parse <merge>^2` before pushing: it must be that SHA
or the Done-marking commit sitting directly on it, and nothing else — anything else is a commit
added after the sign-off, shipping unreviewed (measured). (A rebase rewrites both, so re-note the
tip on the rebased result once the verify gate is green again. In the shared path there is no
local `main` to audit: that SHA push is covered by the `--is-ancestor` verdict and the same `^2`
check.) Then delete the feature branch: `git branch -d task-NNN-<slug>`
locally (a real merge record exists, so plain `-d` verifies the merge for you; it refuses while
you are still standing on that branch), **and remotely if it was pushed** — that half is gated
by `git-confirm-destructive`.
