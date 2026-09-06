# git-flow is a structural fork (`squash` default), with three coupled rules per variant

**Status:** accepted

A web project evolved to **squash-merge** (code + Done collapse into one commit on main) while
the backlog init template used **`--no-ff`** merge commits — mutually exclusive integration
models, not value tweaks. So git-flow ships as two variant Chunks a project imports exactly one
of: **`git-flow-squash`** (the new default) and **`git-flow-noff`** (opt-in). Three rules ride
the fork *together* and must never cross-ship: merge model, branch-name prefix
(`<type>/task-NNN` vs plain `task-NNN`), and the backlog `--notes` SHA policy.

**Consequences (the non-obvious coupling):** **the notes-SHA policy is not derived from the merge
model — it is a convention chosen per merge model, and it rides the fork** with the rest, which is
why the SHA rule lives in the git-flow variant files, **not** in `backlog-core` (which
stays merge-agnostic and defers to "your git-flow variant"). Emitting the squash no-SHA rule into
a `--no-ff` project — or vice versa — would be a bug. **Amended 2026-09-05 (ticket 16):** Done is
marked **on the branch, before the merge, in both variants** (`backlog-core`'s rule), so no merge
SHA exists at marking time in either — the original "`--no-ff` produces a real merge SHA at
marking time" was false. Under `--no-ff` the SHA is instead **appended after the merge**, in a
`chore(backlog/task-NNN)` commit on `main`: the merge commit *is* the task's unit in history
there, so its SHA is the thing worth recording. Squash omits it **by policy, not by structure** —
a trailing board chore is allowed under squash too, but there the task↔commit link is already the
subject scope + `Refs task-NNN` footer, so a recorded SHA buys nothing. A **fourth** rule rides
the fork alongside the three above: the pre-push audit predicate — under `--no-ff` it must be
`git log --first-parent origin/main..main`, because the branch's own commits stay in history and
squash's plain `git log origin/main..main` form could never pass there.
