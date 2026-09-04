# Triage labels

<!-- Stamped by init-project (profiles/backlog/templates/triage-labels.md). The label vocabulary for
     this repo's board (Backlog.md, `backlog/`); both host adapters point here. -->

This file holds one thing: the five triage labels and what each hands off to. How labels behave —
free-form and multiple per item, the config's `labels:` list as suggestions rather than a closed
vocabulary, the provenance label set at `-l` time, drafts setting their labels at `draft create -l`
because they have no edit verb — is the `backlog-core` chunk's, which your host adapter loads. Read
it there; this file does not restate it.

Enumerating the five below in `backlog/config.yml` is for discoverability, not enforcement: probed
on backlog 1.45.2 (2026-09-03), an unlisted label passed to `draft create -l`, and again to
`task create -l` (a throwaway task, removed before commit), was accepted and written to the item's
frontmatter unchanged.

## The five triage labels

- **`needs-triage`** — arrived unsorted. Nobody has decided yet whether it is real, who owns it, or
  what it blocks. Every new row from outside a planning session starts here.
- **`needs-info`** — triaged and real, but not actionable as written: a missing repro, an unstated
  acceptance criterion, an unanswered design question. It waits on an answer, not on capacity.
- **`ready-for-agent`** — fully specified and claimable by a delegated session with no human in the
  loop: the acceptance criteria are machine-checkable and the dependencies are resolved. This is the
  frontier a hands-off run works.
- **`ready-for-human`** — fully specified but requires a person: a judgment call, a visual call, a
  sign-off, or a credential. An agent may prepare it, never close it.
- **`wontfix`** — decided against. Kept as a row rather than deleted so the decision stays findable;
  the reason belongs in the row's notes.

Beside these five sit the provenance label `backlog-core` names, and whatever topic labels emerge.

*<Fill at init, where the project wants them: a `human` label marking rows that need a person, and
a `checkpoint` label for the run-stopping rows a delegated run must not work past. Both are
optional — add them only if this project runs delegated sessions against the board.>*
