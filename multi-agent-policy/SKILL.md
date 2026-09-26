---
name: multi-agent-policy
description: Which capability role fills which seat in a multi-agent run. Use when a planning session (grill, spec, tickets) is handed implementation, before a delegated implementation (even a single implementer), a review with sub-agents, or any fan-out. Not for a single read-only sub-agent.
---

# Multi-agent policy

Two roles, each defined by a property, never a model name
([ADR 0011](../docs/adr/0011-roles-not-cost-tiers.md)):

- **Planner** — draws on its own weekly meter. Judgment over an ambiguous subject.
- **Builder** — the strongest role with no meter of its own. The default for every seat.

No third role, nothing cheaper. Ration the meter, not difficulty: a Planner main loop delegates
exploration, reads only what adjudication needs and keeps reports short.

## Which role a session runs on

Read it off the usage tool, never the model name: the model with its own weekly line is Planner,
any other is Builder. A sub-agent with no usage read says so rather than guessing; its dispatcher
states the pin.

**Planner sessions:** wayfinder, grill-me, grill-with-docs, to-spec, spec-review, to-tickets, in one
unbroken context window. Each ticket then runs `/implement-run` in a fresh Builder session (that
Skill asks the owner to switch if it is not). Outside a run, a Planner main loop handed
implementation delegates it to the `implementer` seat. Inside a run the **advisor** — the seat
holding unscoped judgment for the coordinator — is the only Planner seat. A frontier worked
hands-off runs `/implement-batch`, where installed (§ Elsewhere), which the owner invokes, from a
Builder main session — the **delegate** — which dispatches one `coordinator` per ticket to run
`implement-run`.

## Spawning

- **No bare spawn.** Fill each seat from a pinned definition (this repo's `agents/`; confirm
  `ls -l ~/.claude/agents` resolves). A bare spawn silently inherits the parent's model: review
  seats leaked onto a Planner parent in three of four sessions (2026-09-14). Where no definition
  fits, pin the role on the dispatch.
- **From a Planner session, pin Builder and say so before dispatching** — one sub-agent or a
  fan-out. Only a judgment-shaped question (ambiguous, not merely unwritten) pins Planner, said
  aloud; research qualifies only when its question does.
- **Check the meter, weekly and session, before spawning the advisor or fanning out from Planner.**
  Every dispatch and returned report spends the parent's window.
- **A Builder-role seat runs `medium | high | xhigh` where its definitions reach, the Planner-role
  advisor `high` only** (list: [`agents/README.md`](../agents/README.md);
  [ADR 0018](../docs/adr/0018-run-profile-derived-from-plan.md) § 7). The dispatched name carries
  it — the bare name the seat's default, `high`, except the gate-runner's `medium` — or a workflow
  stage's `effort`; the Agent tool pins only `model`. Never pass `model` on a seat dispatch: it
  overrides the pin; a run never changes a seat's model.
- **Drive `agent-browser` in the parent, never a sub-agent** (load `agent-browser-gotchas`). A
  sub-agent's screenshot never reaches you, so a visual acceptance passes with nobody having seen
  the page. Do the pass yourself rather than handing "eyeball this" to the owner.
- **A seat may run a stale definition after an edit.** The registry refreshes lazily
  ([`agents/README.md`](../agents/README.md) § Editing here is live), and on 2026-09-18 twice served
  the old body after the edit had merged. To validate an edited seat, have it read the rule off
  disk and report any difference; verify a changed `model:` from a fresh session. A workflow
  dispatching an edited seat cannot be steered that way, so run it from a fresh session.

## Model names

No durable rule — Skill, Chunk, contract, ADR, either host's global file — names a model. A run
artifact does: a seat definition or workflow script pins a family alias (`opus`, `fable`), which
follows its family's latest release, never a versioned ID, which stays behind until someone
re-probes it ([ADR 0017](../docs/adr/0017-seats-pin-family-aliases.md)). A new version needs no
edit. When the meter moves a role to another family, `context-hygiene`'s reverse pass (where
installed) re-audits the seats' model fields; nothing else reads them.

## Elsewhere

- **The run procedure** — the run profile, the advisor's slots, the unresolved-seat fallback, the
  run record — is the slash-only `implement-run` Skill.
- **[`WORKFLOWS.md`](WORKFLOWS.md)** — saved Workflow scripts, fan-out → verify, vendor lenses.
- **[`COORDINATOR-PANE.md`](COORDINATOR-PANE.md)** — choosing a run's shape, heartbeats, child
  sessions in a multiplexer, peers on a shared system.
- **Hands-off execution** of one or more tickets by the owner's delegate is the slash-only
  `implement-batch` Skill, where its directory exists under `~/.claude/skills` or
  `~/.agents/skills`: suggest `/implement-batch` to the owner, who invokes it.
