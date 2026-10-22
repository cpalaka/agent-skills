---
name: build
description: Build a project from its brief, one milestone at a time, with a verify command and the owner's play as the only gates.
disable-model-invocation: true
---

# Build from the brief

You are starting a build session. The brief is the spec and the task list. Nothing else is.

## The brief

A file in `docs/` (the grill's output, or a plan the owner wrote). It holds the problem, the
solution, the decisions, what is out of scope, and **numbered milestones, each with a done
check**. Read it whole before touching code, along with `CONTEXT.md` and the repo's `AGENTS.md`.

Kept repos may hold tickets instead: one file each in `docs/tickets/NN-slug.md`, with a
`Status:` line. Treat a ticket exactly like a milestone.

## The loop

For each milestone, in order:

1. Build it.
2. Run its done check and the project's verify command. Both green, or it is not done.
3. Commit, with the milestone in the subject. Throwaway repos commit on `main`; kept repos
   work on a branch per ticket and squash-merge locally (load `claude-code-gotchas` first).
4. Update the "where the work stands" section of `AGENTS.md`.
5. Where feel matters, stop and hand it to the owner at F5. Their verdict decides whether the
   milestone is done, and it goes into the brief under that milestone.
6. Compact, then the next milestone.

**When the brief is wrong or silent, fix the brief in place.** Never guess silently and never
trim the thing a milestone exists to test. A superseded decision is rewritten where it stands,
not appended below.

## Ending a session

Write a dated note in `docs/` saying what landed, what is open, and the next milestone. End
with one line the owner can paste to start the next session.

## Not here

No tracker, no reviewer seats, no gates beyond the verify command and the owner's play, no closing
records. When milestones are independent and you want them built in parallel, ask the owner for a
Workflow rather than coordinating subagents yourself.
