# Triage labels

<!-- Stamped by init-project (profiles/backlog/templates/triage-labels.md). The label vocabulary for
     this repo's board (Backlog.md, `backlog/`); both host adapters point here. -->

Labels are free-form and multiple per item (`-l a,b`); the `labels:` list in `backlog/config.yml` is
a **suggestions list for the web UI, not a gate** — probed on backlog 1.45.2 (2026-09-03): an
unlisted label passed to `draft create -l`, and again to `task create -l` (a throwaway task, removed
before commit), was accepted and written to the item's frontmatter unchanged. Enumerating the five
below in the config is therefore for discoverability, not enforcement.

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

## The project's own conventions

- **A provenance label** set at `-l` time on every task or draft an agent creates. The discriminator
  is the creation *mechanism*, not where the idea came from; rows the owner enters directly stay
  unlabeled.
- **`human`** — this row needs a person. A ticket whose dependency carries `human` is a checkpoint: a
  delegated run stops there and does not work past it.
- **`checkpoint`** — the run-stopping rows themselves, lifted by the owner marking them Done.
- Topic labels are added organically as themes emerge.
- A draft's labels must be set at `draft create -l` time — drafts have no CLI edit verb.
