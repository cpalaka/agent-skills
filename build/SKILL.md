---
name: build
description: Build a project from its brief, one milestone at a time, with a verify command and the owner's look and play as the only gates.
disable-model-invocation: true
---

# Build from the brief

You are starting a build session. The brief is the spec and the task list. Nothing else is.

## The brief

A file in `docs/` (the grill's output, or a plan the owner wrote). It holds the problem, the
solution, the decisions, what is out of scope, and **numbered milestones, each with a done
check**. Read it whole before touching code, along with `GLOSSARY.md` and the repo's `AGENTS.md`.

Kept repos may hold tickets instead: one file each in `docs/tickets/NN-slug.md`, with a
`Status:` line. Treat a ticket exactly like a milestone.

## Where to start

Read the "where the work stands" section of `AGENTS.md` (with tickets, their `Status:` lines).
Start at the first milestone it does not record as done. If it records that milestone as
partly built, resume at the first unfinished part it names, and never rebuild a part it records
as done. A milestone recorded as built and awaiting the owner's verdict resumes at step 6 and is
not rebuilt. With no such record, start at milestone 1. Read `git log` as well: a milestone's
commits name the lines of its done check that are already green.

## The loop

For each milestone, in order:

1. **First look.** Where the owner's play decides the milestone (step 6), build the least that
   shows its picture before anything else: on screen and playable, with no done check, probe
   or measured number behind it. The brief may name it. Look at it yourself by the project's
   visual channel, commit it, then stop and hand it to the owner in five lines or fewer: how
   to open it and the one thing to judge. Their yes starts step 2; anything else is the
   requirement for another first look. The owner corrects on sight, and a wrong picture costs
   least here.
2. Build the rest. A milestone can outlast one context, and after a compaction only the repo
   and the brief are whole: commit at each line of the done check that goes green, the
   milestone and the line in the subject, and put a draft or a measured number in a file when
   you make it.
3. Run its done check and the project's verify command. Both green, or it is not done. A done
   check's owner play is step 6; everything else in it is green here.
4. Commit, with the milestone in the subject. Throwaway repos commit on `main`; kept repos
   work on a branch per ticket.
5. Update the "where the work stands" section of `AGENTS.md` (and the ticket's `Status:` line),
   naming any milestone left partly built and the part to resume at.
6. Where feel matters, stop and hand it to the owner at F5, naming the numbers they can change
   and where those live. Their verdict decides whether the
   milestone is done, and it goes into the brief under that milestone. A rejected milestone goes
   back to step 1 with the verdict as its requirement; an accepted one gets its step 5 record
   updated to done.
7. Kept repos: squash-merge the branch locally once the milestone is done (load
   `claude-code-gotchas` first). Where step 6 applies, that is after the owner's verdict, never
   before, with the verdict and the updated `AGENTS.md` committed on the branch first.
8. Compact, then the next milestone.

**When the brief is wrong or silent, fix the brief in place.** Never guess silently and never
trim the thing a milestone exists to test. A superseded decision is rewritten where it stands,
not appended below.

## Unattended runs

When the owner says to run several milestones unattended, the run is one unit on one branch (a
kept repo names the branch for the run, not for a ticket).

- For each milestone in order, do steps 2 to 5, then compact. Commit the `AGENTS.md` update with
  the milestone. Skip steps 1, 6 and 7: the owner is not there to look.
- Step 5 records a milestone with no owner play as done, and one with an owner play as **built,
  awaiting verdict**.
- At the end, hand over one list: each play that is waiting, by milestone, with the numbers worth
  changing. That list is the session's closing line.
- A rejected milestone is fixed on the same branch, with the verdict as its requirement. Then
  re-run the done check of every later milestone, and the verify command, because they were built
  on top of it; one that goes red is reopened.
- Squash-merge the branch once every waiting verdict is accepted, with the milestones it covers
  in the subject. A run with no play waiting is squash-merged at its end.

## Ending a session

Make the "where the work stands" section of `AGENTS.md` true: what landed, what is open, the next
milestone. Write no dated note; a measured number or a verdict goes in the brief under its
milestone. End with one line the owner can paste to start the next session.

## Not here

No tracker, no reviewer seats, no gates beyond the verify command and the owner's look and play, no closing
records. A small change the owner asks for directly, once a milestone is accepted, is not a
milestone: build it, run the verify command, commit. When milestones are independent and you want them built in parallel, ask the owner for a
Workflow rather than coordinating subagents yourself.
