## Board

Work is tracked on the board under `backlog/`, driven by the `backlog` CLI. Two pointers, both
host-neutral, and both worth reading **before you create or triage a row** rather than after:

- **`docs/agents/issue-tracker.md`** — how the tracker is driven from an agent session: the fetch,
  list and search commands, the id format commits reference, and the rule that the CLI owns every
  file under `backlog/`. It is also the path skills look up when they need this project's tracker
  (code-review's Spec axis, triage, to-tickets).
- **`docs/agents/triage-labels.md`** — the five triage labels and what each one hands off to, so a
  row lands where someone will actually pick it up.

**Acceptance criteria are this task's verification; the Definition of Done is every task's.** Phrase
AC as the specific checks that prove *this* change — the shape they take is the `VERIFY_EXAMPLES`
knob above. Standing gates belong in the DoD defaults in `backlog/config.yml`, not repeated per
task, and the DoD always ends in the explicit user sign-off. The full convention — when to check a
criterion, drafts versus tasks, milestones — is the `backlog-core` chunk's, which your host adapter
loads.

**Before you claim something is absent, check the board.** `backlog task list --plain` to see what
exists, then `backlog task <id> --plain` on the row that would own the thing you are about to call
missing. **"Nothing owns this" is a claim that needs a search behind it, not an impression** — the
board first, then `docs/`, then the repo's own notes.
