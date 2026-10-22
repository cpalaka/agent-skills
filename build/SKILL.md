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

## Where to start

Read the "where the work stands" section of `AGENTS.md` (with tickets, their `Status:` lines).
Start at the first milestone it does not record as done. If it records that milestone as
partly built, resume at the first unfinished part it names, and never rebuild a part it records
as done. With no such record, start at milestone 1.

## The loop

For each milestone, in order:

1. Build it.
2. Run its done check and the project's verify command. Both green, or it is not done. A done
   check's owner play is step 5; everything else in it is green here.
3. Commit, with the milestone in the subject. Throwaway repos commit on `main`; kept repos
   work on a branch per ticket.
4. Update the "where the work stands" section of `AGENTS.md`, naming any milestone left partly
   built and the part to resume at.
5. Where feel matters, stop and hand it to the owner at F5. Their verdict decides whether the
   milestone is done, and it goes into the brief under that milestone.
6. Kept repos: squash-merge the branch locally once the milestone is done (load
   `claude-code-gotchas` first). Where step 5 applies, that is after the owner's verdict, never
   before, with the verdict and the updated `AGENTS.md` committed on the branch first.
7. Compact, then the next milestone.

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
