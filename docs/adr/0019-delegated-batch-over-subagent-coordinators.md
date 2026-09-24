# A delegated batch runs per-ticket coordinators as subagents from one main session

**Status:** accepted — 2026-09-24. Decided on cpalaka/agent-skills#81, under map #82, from test
run 1 on that ticket and the measurements on #83 and #89. Reads with
[ADR 0018](0018-run-profile-derived-from-plan.md), whose plan stop and `owner's delegate`
attribution this entry gives a reader.

## Context

The routing rule says one `/implement-run` per fresh session, and every owner stop in that Skill
assumes a human answers: the plan stop, the Close step's one approval, a slot-3 fourth need, a
missed criterion's re-cost. Asked to work a `gate:agent` frontier end to end, no Skill described a
session that runs several tickets and stands in for the owner at those stops. Test run 1 (#81,
six tickets over herdr panes) showed the stand-in earns its seat at the plan stop, that the
delegation boundary was unwritten in four places, and that the delegate's own polling latency was
the largest avoidable cost. #83 measured that herdr cannot tell a permission dialog from an
AskUserQuestion stop and that keystrokes can land in an open dialog. #89 measured that a subagent
at depths 1 and 2 carries the Agent tool and depth 3 does not, that a hand-back is pushed to the
parent and a resume reaches the child in about a second, and that the Skill tool refuses the
slash-only `implement-run` with text against replicating it by other means.

## Decision

1. **The mode is its own slash-only Skill, `implement-batch`**, loaded by name from a session
   rooted in the target project. It is defined by the **delegate**, the main session standing in
   for the owner, not by the ticket count: a batch of one is legitimate. `multi-agent-policy`'s
   `GRANTS.md` retires into it, since a hands-off ticket is a batch of one; `COORDINATOR-PANE.md`'s
   herdr section stays as the fallback transport's procedure.
2. **Transport: a per-ticket coordinator as a depth-1 subagent, its seats at depth 2.** The
   coordinator is a pinned definition, `coordinator`, Builder alias, effort high, the full tool
   list. Its brief states the owner's delegation, loads the procedure from `implement-run`'s
   `SKILL.md` by path and never through the Skill tool, whose refusal addresses a session
   replicating the workflow for itself; hands back at every stop; ends at the Close approval.
   Inside a batch the inner run's `shape` is `subagents` whatever the project's knob says: the
   Workflow tool is absent at depth 1, and a pane driven from a subagent is unmeasured. herdr is
   the named fallback when live takeover is wanted, for Codex-hosted tickets, or after a crash
   that kills a coordinator unrecoverably.
3. **The delegated stops.** The delegate answers the plan stop, the Close approval, and a slot-3
   need only after the advisor and only for what the advisor cannot settle. A false premise met
   mid-run is the delegate's when its disposition leaves every criterion satisfied in form with
   the failed premise named; an answer that would leave a criterion unticked or rewritten is a
   re-cost and the owner's. Feel, camera, pose, any judgment a project's contract reserves, and a
   `gate:decide`-shaped question in a body are the owner's. An owner stop **parks** the ticket.
4. **The batch grant.** At kickoff the owner names the gated writes the delegate may perform, at
   minimum `gh issue create` for `gate:decide` finding tickets, so no finding goes homeless at
   Close; every other write in `git-confirm-destructive`'s gated set parks the ticket. The grant is
   quoted verbatim in every coordinator's brief, and each run record names it under `Slots`. A
   batch takes `gate:agent` tickets; `gate:accept` only on the owner's say-so per batch, run to a
   `Refs` push and left open.
5. **A dialog is never the delegate's, on any transport.** Under subagents nothing in the chain can
   type into one. Under herdr every `blocked` is the owner's, AskUserQuestion stops included, until a
   `PermissionRequest` hook publishes a structural signal. The batch runs in whatever permission
   mode it was started in; a dialog that surfaces blocks until the owner answers.
6. **Screening before start.** The delegate re-derives the frontier with the tracker Chunk's
   query, treating the coordinator's emitted kickoff as a cross-check, then reads the live body for
   an open question, a missing `## Acceptance`, and any path in the run's instrument set (this
   library's Skills, Chunks and seat definitions, the project's contract and adapters). A hit
   parks the ticket with a comment naming the defect; the gate label stays the owner's.
7. **Park versus stop.** Park on an owner stop, a gated write outside the grant, or a screening
   hit. Stop the batch on an instruction file in a landed diff (ADR 0018 § 5), any instrument-set
   mtime change since batch start, a failed landing check (tree inequality against the reviewed
   commit, or the issue's state wrong), a 429 or meter stall, a dirty checkout after a run, or two
   consecutive parks. No ticket-count cap by default; the usage window at 80% ends the batch; the
   owner may set a count at kickoff.
8. **The hand-back form.** The coordinator ends its turn with `STOP <plan | close | slot-3 |
   park>` and what it needs, nothing pending; the delegate resumes by message with
   `owner's delegate: <approved | answer | park> — <the SHA or fact it read>`, having read the diff
   from git, never from the report.
9. **The delegate runs Builder by default**, Planner only on the owner's say-so, as an
   `implement-run` session does. Its batch record is chat only: closed tickets with SHAs, parked
   tickets with reasons, findings filed, the usage window at start and end, `git worktree list`.
10. **Terms.** *delegate* names this session, and its implementer-shorthand allowance in the
    glossary is struck; *batch* is the tickets one delegate session works; *park* is the exit
    that leaves a ticket open for the owner. Codex-hosted and headless batches are out of scope.

## Considered options

- **herdr as the primary transport** (test run 1's shape). Rejected: status is text-derived, a
  dialog and a delegable question read the same, and input can land in an open dialog; the
  freshness advantage rarely pays because the batch ends on an instruction-file edit anyway.
- **A mode of `implement-run`.** Rejected: the delegate never runs one, and the Skill is already
  at 2,748 words.
- **A section of `multi-agent-policy`.** Rejected: that Skill is description-matched, so every
  session would carry a procedure only a batch runs.
- **A named note as the home for a finding, instead of a grant.** Rejected: a note is a home in
  form only; the follow-up still has no owner.
- **Building the `PermissionRequest` hook first.** Deferred: worth a ticket only if herdr becomes
  the primary transport.

## Consequences

- Children of the map's `Spec:` parent: the `implement-batch` Skill; the `coordinator` seat
  definition; retiring `GRANTS.md` and re-pointing its four references (`README.md`,
  `parallel-work`, `multi-agent-policy` § Elsewhere, `COORDINATOR-PANE.md`); correcting the herdr
  section's polling to #83's contract; the routing line in `multi-agent-policy` § Which role and
  the shape override and path-load rule in `implement-run`; a research probe of default
  permission mode. The owner's global routing line changes by hand.
- The Skill-tool refusal text stands; the path load is a rule of the batch Skill, not a per-brief
  argument.
- Every batch feeds cpalaka/3d-anim-lab#93's measurement: the run records carry the definition
  names and the `owner's delegate` attribution.
