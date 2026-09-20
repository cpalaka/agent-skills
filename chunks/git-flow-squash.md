<!-- chunk:git-flow-squash | kind: fork | single-source: agent-skills/chunks/git-flow-squash.md -->
<!-- Delivered by Claude @import or a Codex AGENTS.md explicit read through the host's chunk symlink.
     Edit here only — no per-project copies, no parity. -->

## git-flow — squash (default variant)

This is the **default** git-flow variant: integration is a local **squash-merge** to `main` with
no PRs. The three rules below — **(a)** squash-merge, **(b)** the typed branch prefix, **(c)**
no-SHA-in-notes — ride this fork **together** and must stay coupled (ADR 0002). Start a task on a
fresh `main` and a correctly-named branch per `git-sync-branch-start`; write commit subjects and
footers per `git-commit-format`.

**Board-less projects** (neither `backlog-core` nor `tracker-github` imported — e.g. a
prototype with no tracker at all): there are no task ids, so branches are `<type>/<slug>`
(e.g. `feat/vacuum-suction`) and every `task-NNN` reference drops — the branch-name id, the
`Refs task-NNN` footer, the `<area>/task-NNN` commit scope, and (c)'s notes policy. The
integration mechanics apply unchanged. A project importing `tracker-github` is **not**
board-less, and every clause below that names a task id, a board, Done-marking or `--notes`
resolves as that chunk's deferred-clauses section says; the integration mechanics stay this
fork's.

**(a) Integration = squash-merge — code + Done collapse into ONE commit on `main`.** After the
diff is approved per (d), mark the task Done **on the branch**, commit it there.
(`tracker-github` resolves this.) Then squash-merge.

- **The squash carries the branch's FINAL TREE and nothing else — a file added and then deleted on
  the branch never enters `main`'s history at all.** Prune heavy or throwaway artifacts
  (screenshots, fixtures, generated output) **before** the merge, on the branch, as an ordinary
  commit. The same deletion **after** the merge only tidies the working tree: the bytes are
  already in `main`'s history, recoverable by a rewrite alone. Git reports nothing either way.
- **Another session's commit on YOUR branch: cherry-pick it to `main` FIRST, then squash.** (d)
  checks `git log origin/main..main` for a peer's work on local `main`; the branch is the blind
  spot, and in a shared checkout a peer commits to whatever branch is checked out — yours. A plain
  squash then folds their unrelated change into your commit under your task's subject, and the
  failure is silent in the worst way: the merge succeeds, the commit is well-formed, the diff is
  correct, and only their *message* is destroyed — the one artifact that said why the change
  exists. Measured 2026-09-20 (skills #3): the absorbed commit's message recorded the incident
  that motivated it, and nothing in the merge would have mentioned it. So: `git cherry-pick <sha>`
  onto `main`, then `git merge --squash <branch>` — their content is already in, so it contributes
  nothing to the squash, and no history of theirs is rewritten. Verify rather than assume, with
  `git cherry -v main <branch>`: the cherry-picked commit prints `-` (present by content) while
  your squashed commits print `+`. `git branch -d` will then refuse the branch as "not fully
  merged", which is normal after any squash — confirm with an empty `git diff <branch> main`
  before forcing, never on the strength of the merge having succeeded.
- **A sign-off approves a TREE, not a branch name. If the base moved between approval and merge,
  rebase and RE-RUN THE VERIFY GATE on the rebased result before merging.** The conflict-free
  rebase is the dangerous case: nothing warns, and the pre-rebase green measured a combination
  that no longer exists. `git merge-base --is-ancestor` answers "can this merge cleanly", never
  "is this still the thing that was reviewed". (measured 2026-08-02)
- `git checkout main && git merge --squash <branch>` → **review the staged changes** →
  `git commit` (message per `git-commit-format`), or `git reset --merge` to abort. Then push
  `main`, per (d).
- **This squash-merge pause is the review surface** — no merge commit exists to inspect
  afterwards.
- **Merging from a worktree? Release `main` right after the push.** Git allows a branch in only
  ONE worktree at a time, so while your worktree sits on `main` no other checkout can take it —
  **silently blocking** the parallel session the moment it tries to merge. `git checkout --detach`
  in the worktree (or remove it) immediately after the push.
- **`main` already checked out somewhere else? Merge WITHOUT taking it** (`parallel-work`). Git
  refuses `git checkout main` while another worktree holds the branch, and taking it would inflict
  that same block. The squash result is by definition your branch's tree parented on `origin/main`, so
  build it directly and push the SHA — which also stops a sibling's unpushed commit on your local
  `main` riding along:

  ```sh
  git fetch origin
  git merge-base --is-ancestor origin/main HEAD    # must exit 0 BEFORE you build SQ
  SQ=$(git commit-tree "$(git rev-parse HEAD^{tree})" -p origin/main -F msg.txt)
  git push origin ${SQ}:main            # fast-forward; never touches the local `main` ref
  ```

  `--is-ancestor` is the verdict: `SQ` carries your branch's tree, so pushing it on a moved base
  reverts what the peer landed. The parent-equals and empty-`git diff $SQ HEAD` checks hold by
  construction for any input, so they are paste guards, not verdicts.

**(b) Branch name = typed prefix `<type>/task-NNN`.** A conventional-commit `<type>/` prefix
(`feat`, `fix`, `chore`, `docs`, `refactor`, `test`) followed by the backlog task id zero-padded to
3 digits — e.g. `feat/task-003`, optionally with a short kebab description.
(`tracker-github` resolves this.)

**(c) NO commit SHA in the backlog `--notes`.** Done is marked on the branch before the merge,
so no squash SHA exists at marking time — and none is appended afterwards: `--notes` carries the
summary only, never a hash. The task↔commit link is the subject scope + the `Refs task-NNN`
footer (`git log --grep`), so a recorded SHA buys nothing. (`tracker-github` resolves this.)

**(d) No PRs — review locally; push to `main` only on per-branch diff approval.**

- **Never open a PR for new work** — integration is a local squash-merge. The per-PR `gh` writes
  are gated by `git-confirm-destructive`.
- When a branch is ready, report it in chat: what's on it, what's verified, and anything the
  reviewer should look at closely.
- The reviewer approves the **diff** before any merge. That approval authorises **exactly one**
  squash-merge to `main` and the accompanying push of `main` — nothing more.
- **Board-grooming-only pushes are pre-authorised.** A push whose entire content is board
  maintenance — `chore(backlog): …` commits with no code or asset change — needs no per-branch
  diff approval. Verify the claim rather than asserting it (`git log origin/main..main` and a
  `--stat` showing only `backlog/`); the moment anything else rides along, the ordinary gate
  applies again. (`tracker-github` resolves this.)
- **Before that push, `git log origin/main..main` must contain only your squash commit.** In a
  multi-session repo your local `main` can already carry another session's unpushed work, and
  your push publishes it with the approver having no way to know. If the list is not just yours,
  STOP and ask; never reset or rebase another session's commit out of the way.
- **Immediately before the merge, `git status --porcelain` must list ONLY the files you intended
  — a GUI editor open on the project is a SECOND WRITER that does not announce its writes.** An
  editor (Godot, Unity, a design tool) holds **in-memory** copies of every asset you touched and
  flushes them on its own schedule, persisting runtime/preview state as authored data and
  re-clobbering a file you already restored with `git checkout --`. The spill is syntactically
  legal, so nothing flags it. Revert any unexpected asset modification and force the editor to
  reload from disk. (measured 2026-08-02)
- **Pushing the feature branch to origin is optional** (backup / multi-machine) and no part of
  the review flow.
- **Delete the feature branch after merge** (locally, and remotely if it was pushed).
- **Verify the branch landed by diffing it against the SQUASH COMMIT, not against current
  `main`.** `git branch -d` refuses a squash-merged branch by design (there is no merge record),
  so the delete is a `-D` and the safety check is yours to run:

  ```sh
  git diff --quiet <squash-sha> <branch> && git branch -D <branch>   # RIGHT
  git diff --quiet main <branch>                                     # WRONG once main moved
  ```

  `git diff main <branch>` reports everything `main` gained **after** the merge as
  branch-content-missing-from-main, so the WRONG form fires a **false alarm on a correct merge**
  and invites re-pushing something that already landed.
