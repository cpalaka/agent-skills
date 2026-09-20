<!-- chunk:git-sync-branch-start | kind: invariant | single-source: agent-skills/chunks/git-sync-branch-start.md -->
<!-- Delivered by Claude @import or a Codex AGENTS.md explicit read through the host's chunk symlink.
     Edit here only — no per-project copies, no parity. -->

## Sync main, then branch off it (task start)

At the start of any task, get onto a **fresh `main`** before you branch. The default branch is
`main`.

**Sync `main` before the first *write*, not before the first read.** Listing the board or the
issue frontier that the tracker chunk (`backlog-core` or `tracker-github`) names, reading the
task and running `git status -sb` all stay available — they are how you learn whose work is in
the tree. What the sync must precede is the new task's *writes*: its branch, its tracker write,
its commits.

**Clear your own leftovers first.** Before `git checkout main`, commit (or stash) anything *you*
left in the working tree on the branch you are leaving, staging by explicit path
(`git-commit-format`):

```sh
git status -sb          # is the working tree dirty — and is all of it yours?
git add <the files you changed> && git commit -m "…"   # on this branch (or: git stash push -- <those files>)
```

Uncommitted, non-conflicting changes **follow a branch switch**, so checking out `main` with a
dirty tree silently carries that work onto `main`. The damage compounds: the source branch then
has *no* commit to merge, a squash-merge of it is a no-op, and a later push can publish a
different, already-committed change instead of yours.

**If any of the dirty work is not yours, stop.** Another session shares this checkout: leave their
files exactly as they are, and do not switch branches — the checkout is theirs until they hand it
off, even once it is clean (`parallel-work` § "One clone per interactive session" names the
operations that would move their work, a branch switch among them). Commit your own files by
explicit path only after `git branch --show-current` confirms the branch is yours; otherwise ask
the peer to commit and wait, or take your own worktree on an explicit parallel-work signal.

**Then sync, then branch off the freshly-pulled `main`.**

```sh
git checkout main && git pull origin main
```

Run it **even if you think you're already on `main` and up to date.** Sibling work may have merged
since the previous session, and branching from a stale base silently builds on outdated code.
Create the feature branch only once that has completed, so the new branch's base is current.
(Branch *naming* is the integration model's concern — see `git-flow-squash`. Wiring the branch to
a task id and the tracker is the tracker chunk's — `backlog-core` or `tracker-github`.)
