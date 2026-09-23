---
name: git-flow-squash
description: Integration as a local squash-merge to main with no PRs, the typed branch prefix, and no commit SHA in the tracker notes. Use at task start when naming a branch, and at integration — before any squash-merge to main, before pushing main, before opening a PR, before deleting a merged branch, and before committing a heavy or generated artifact.
---

## git-flow — squash

Integration is a local **squash-merge** to `main`, with no PRs. **(a)**, **(b)** and **(c)** are
coupled and stay together (ADR 0002, kept by ADR 0013). Sync and branch per
`git-sync-branch-start`; write commit messages per `git-commit-format`.

**Board-less projects** (neither `backlog-core` nor `tracker-github` imported) have no task ids:
branches are `<type>/<slug>`, and every `task-NNN` form and (c) drop out. A `tracker-github`
project is **not** board-less: a clause naming a task id, a board, Done or `--notes` resolves as
that chunk's deferred-clauses section says. The integration mechanics stay the same either way.

**(a) Integration = squash-merge: code and Done land as ONE commit on `main`.** Once (d)'s diff
approval is in, mark the task Done **on the branch** and commit it there (`tracker-github`
resolves this). Then squash.

- **The squash carries only the branch's final tree**, so a file added and then deleted on the
  branch never reaches `main`. Prune heavy or throwaway artifacts (screenshots, fixtures,
  generated output) on the branch **before** the merge. Deleted after the merge, their bytes stay
  in `main`'s history, recoverable only by a rewrite. Git reports nothing either way.
- **Keep an artifact only while something other than its own closed task reads it** (an open
  task, an ADR, a standing doc), and that reader has to be live itself. Name the reader when you
  create the artifact. With no reader it is output, not evidence: prune it before the merge.
  Liveness and bulk deletions: `verification-discipline`.
- **If another session committed on YOUR branch, cherry-pick that commit to `main` first, then
  squash.** In a shared checkout a peer commits to whatever branch is checked out, and (d)'s
  `origin/main..main` check cannot see your branch. A plain squash folds their commit in under your
  subject and silently destroys its message, while the merge, the commit and the diff all look
  right. Verify with `git cherry -v main <branch>`: their commit prints `-`, yours print `+`.
- **A sign-off approves a tree, not a branch name.** If the base moved after approval, rebase and
  re-run the verify gate before merging. The conflict-free rebase is the case nothing warns about:
  `git merge-base --is-ancestor` answers "can this merge cleanly", never "is this what was
  reviewed".
- `git checkout main && git merge --squash <branch>`, then **review the staged changes**. No merge
  commit exists afterwards, so this pause is the only review surface. Then `git commit`, or abort
  with `git reset --merge`. Push per (d).
- **Merging from a worktree: run `git checkout --detach` (or remove the worktree) right after the
  push.** A branch can be checked out in only one worktree at a time, so holding `main` silently
  blocks every other session's merge.
- **If another worktree holds `main`, merge without taking it.** Build the squash on `origin/main`
  and push the SHA. This also keeps a sibling's unpushed local `main` commits out of your push:

  ```sh
  git fetch origin
  git merge-base --is-ancestor origin/main HEAD   # the verdict: must exit 0 first
  SQ=$(git commit-tree "$(git rev-parse HEAD^{tree})" -p origin/main -F msg.txt)
  git push origin ${SQ}:main
  ```

  If the base has moved, `SQ` reverts what the peer landed. A parent check or `git diff $SQ HEAD`
  passes by construction, so neither one catches this.

**(b) Branch = `<type>/task-NNN`.** Use a conventional-commit type (`feat`, `fix`, `chore`,
`docs`, `refactor`, `test`) and the task id zero-padded to 3 digits, optionally followed by a
kebab description, e.g. `feat/task-003`. (`tracker-github` resolves this.)

**(c) No commit SHA in the backlog `--notes`.** Done is marked before the squash exists, and no
SHA is appended afterwards. The commit scope and the `Refs task-NNN` footer are the link
(`git log --grep`). (`tracker-github` resolves this.)

**(d) No PRs: review locally, and push `main` only on per-branch diff approval.**

- Report the ready branch in chat: what's on it, what's verified, and what deserves a close look.
  Approval of the **diff** authorises exactly one squash-merge and the push of `main` that goes
  with it, nothing more.
- **Board-grooming-only pushes are pre-authorised**: `chore(backlog): …` commits and nothing else.
  Prove it before pushing, with `git log origin/main..main` and a `--stat` that touches only
  `backlog/`. If anything else rides along, the ordinary gate applies.
  (`tracker-github` resolves this.)
- **Before the push, `git log origin/main..main` must list only your squash commit.** Anything
  else, such as another session's unpushed work, would ride on your approval. Stop and ask; never
  reset or rebase it out of the way.
- **Immediately before the merge, `git status --porcelain` must list only the files you
  intended.** An open GUI editor (Godot, Unity) is a second writer that never announces its writes.
  It flushes its in-memory copies on its own schedule, baking preview state into assets and
  overwriting files you restored. The result is valid syntax, so nothing flags it. Revert any
  asset change you did not make, and reload the editor from disk.
- **Delete the branch after the merge**, plus its remote copy if you pushed one (pushing it is
  optional and plays no part in review). `git branch -d` refuses a squash-merged branch, so diff
  against the squash commit, never against current `main`. Once `main` moves, a diff against it
  reports the new commits as missing from the branch:

  ```sh
  git diff --quiet <squash-sha> <branch> && git branch -D <branch>
  ```
