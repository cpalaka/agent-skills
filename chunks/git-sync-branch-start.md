<!-- chunk:git-sync-branch-start | invariant | edit only at agent-skills/chunks/git-sync-branch-start.md — no per-project copies -->

## Sync main, then branch off it (task start)

**Sync before the first *write*, not before the first read.** The board and `git status -sb` stay
open; branch, tracker write and commits wait.

**Clear your own leftovers first.** Commit or stash what *you* left behind, by explicit path
(`git-commit-format`) — a branch switch carries it onto `main`.

**If the dirty work is not yours, stop.** Run nothing that moves or discards tree state — a branch
switch, `stash`, `reset --hard`, `clean`, `checkout -- <path>`, `branch -D`, any of that class
(`parallel-work` § "One clone per interactive session" names the set). The checkout is theirs
until they hand it off, **even once it is clean**; ask the peer to commit.

```sh
git checkout main && git pull origin main   # run it even if you think you are current
git switch -c <branch>                      # only once that pull has SUCCEEDED
```

**A failed pull is a stop**: resolve or report it, never branch anyway.

Branch naming: load `git-flow-squash` at task start. Tracker wiring: `backlog-core` or
`tracker-github`. Shared checkouts: `parallel-work`.
