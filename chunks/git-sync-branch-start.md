<!-- chunk:git-sync-branch-start | kind: invariant | single-source: agent-skills/chunks/git-sync-branch-start.md -->
<!-- Delivered by @import via ~/.claude/chunks/. Edit here only — no per-project copies, no parity. -->

## Sync main, then branch off it (task start)

At the start of any task, get onto a **fresh `main`** before you branch — never branch
off a stale base. The default branch is `main`.

**Sync `main` first — before reading the task or anything else.** The first technical
action of a task is, once the paragraph below has cleared the working tree:

```sh
git checkout main && git pull origin main
```

Do this **even if you think you're already on `main` and up to date.** Sibling work may
have merged since the previous session, and branching from a stale base silently builds
on outdated code and forces avoidable rebases later. The pull costs nothing when main is
already current; skipping it is the only way to lose. Do not skip because the previous
session "ended cleanly."

**If the dirty work is yours, commit (or stash) it FIRST.** Before `git checkout main`,
deal with anything *you* left in the working tree on the branch you're leaving, staging by
explicit path (`git-commit-format`):

```sh
git status -sb          # is the working tree dirty — and is all of it yours?
git add <the files you changed> && git commit -m "…"   # on this branch (or: git stash push -- <those files>)
```

If any of it is not yours — another session shares this checkout — leave their files exactly as
they are (`parallel-work` § "One clone per interactive session" names the operations that would
move them) and do not switch branches: the checkout is theirs until they hand it off, even once
it is clean (`git-commit-format`, the re-verify-the-branch paragraph). Commit your own files by
explicit path only after `git branch --show-current` confirms the branch is yours; otherwise ask
the peer to commit and wait, or take your own worktree on an explicit parallel-work signal.

Uncommitted, non-conflicting changes **follow a branch switch** — so checking out `main`
with a dirty tree silently carries that work onto `main`. The damage compounds: the
source branch then has *no* commit to merge, a squash-merge of it is a no-op, and a later
push can publish a different, already-committed change instead of yours. Committing (or
stashing) on the branch before you leave it is what keeps the work attached to the right
branch and the eventual merge non-empty.

**Then branch off the freshly-pulled `main`.** Create the feature branch only once
`git checkout main && git pull origin main` has completed, so the new branch's base is
current. (Branch *naming* is the integration model's concern — see `git-flow-squash`
[default] or `git-flow-noff`. Wiring the branch to a task id and the board is
`backlog-core`'s.)
