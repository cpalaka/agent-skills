---
name: multi-agent-policy
description: Which capability role fills which seat in a multi-agent run. Use before a delegated implementation, a review with sub-agents, or any fan-out from a planning session. Not for a single read-only sub-agent.
---

# Multi-agent policy

Two roles, each defined by a property, not a model name — a rule naming a model goes stale silently
([ADR 0011](../docs/adr/0011-roles-not-cost-tiers.md)).

- **Planner** — the role that draws on its own weekly meter. Judgment over an ambiguous subject.
- **Builder** — the strongest role with no meter of its own. The default for every seat, including
  one whose subject is still being specified.

No third role exists, and nothing cheaper. The meter, not the work's difficulty, is what you
ration — which is why Builder is the default and Planner the exception.

## Which role a session runs on

**Read it off the meter, not off the model name.** The roles are defined by meter ownership, and no
durable rule here may name a model, so the model you are running under maps to no role by anything
written down — the usage tool is the only instrument that answers it. A per-model weekly line in
the host's usage read names the Planner model; a session on that model is on Planner, and any other
is on Builder. Where the host gives a sub-agent no usage read, it cannot observe its own role and
says so rather than guessing; the dispatching coordinator states the pin instead.

**Planner sessions:** wayfinder, grill and grill-with-docs, to-spec, spec-review, to-tickets.

**The moment to switch is before `/implement`.** A model switch keeps the context window, so the
grill → spec → tickets chain stays unbroken. The **advisor** — the seat holding unscoped judgment
for a coordinator — is the only Planner seat inside an implementation run.

## Spawning

- **No seat is ever a bare spawn.** A seat is a named position; fill it from a pinned definition
  wherever one exists. A
  bare spawn inherits the parent's model, and the host says so only if you look: review seats were
  measured leaking onto a Planner parent in three of four sessions (2026-09-14). Definitions live in
  this repo's `agents/`; confirm they resolve (`ls -l ~/.claude/agents ~/.codex/agents`) first.
- **Check the meter before spawning the advisor or fanning out from a Planner session** — both the
  weekly window and the session one. A wide fan-out drains the parent's own window: every dispatch
  and returned report spends its turns. The failure is clean — relaunch after the reset.
- **A sub-agent spawned from a Planner session pins Builder — one of them or a fan-out of them —
  and states the pin before dispatching.** The exception is a judgment-shaped question, whose
  subject is ambiguous rather than merely unwritten; pin Planner there and say so. Research is
  judgment-shaped only when its question is, not because it is called research. Where no seat
  definition fits, pin the role on the dispatch itself.
- **Effort is `high` on every seat** — in the definition's frontmatter, or on the dispatch where
  none fits. The Agent tool pins only `model`. No higher path. A seat dispatch never passes
  `model`: the parameter takes family aliases only, and overrides the definition's probe-resolved
  ID (the alias lag below).
- **Drive `agent-browser` yourself, in the parent session — never a subagent.** A subagent's
  screenshot is never returned to the parent, so a visually-AC'd task comes back reporting success
  with nobody having seen the page, and the acceptance passes unverified. Visual and feel work is
  therefore the one class that runs **attended**, not in a wave: do the browser pass yourself
  rather than punting "eyeball this" to the owner. Load `agent-browser-gotchas` before driving it:
  several of its failures report success.
- **A seat runs its definition as it stood at session start.** The snapshot survives a mid-session
  edit, and survives that edit merging to `main`. Nothing warns, because a seat applying a stale
  body reports nothing unusual. So a run that changes a seat definition can still validate it. Tell
  the seat in the dispatch prompt to read the rule off disk and report whether it differed from the
  body it started with. A gate-runner did that twice on 2026-09-18, taking the on-disk version
  instead of a false red the same diff had already fixed. Narrows "defer the literal dispatch to a
  fresh session", which still holds for `.claude/workflows/*.js`, where the harness runs the script
  and nothing can choose to re-read.

## Model names: rules never, run artifacts always

No durable rule — this Skill, a Chunk, a project contract, an ADR, either host's global file —
names a model. A **run artifact** does: a seat definition and a workflow script each carry one
concrete model ID, probe-resolved at authoring time, never an alias, which lagged a release and
kept serving the prior generation (2026-07-24).

**Re-audit trigger.** On a model-family change, `context-hygiene`'s reverse pass walks the seat
definitions' model fields beside the global-file rules it covers. A stale pin kept a retired seat
dispatchable for weeks (2026-08-25); nothing else reads those fields.

## The run itself

The `implement-run` Skill carries the procedure — seat roster, the advisor's three slots, the
fallback when a seat does not resolve, the run record. It is slash-only: no project loads it, a
run invokes it by name.

## Sibling files

Nothing loads these by default.

- **[`WORKFLOWS.md`](WORKFLOWS.md)** — Workflow-tool scripts; vendor lenses; reconciling a
  fan-out's results.
- **[`COORDINATOR-PANE.md`](COORDINATOR-PANE.md)** — a run's shape; interactive child sessions in a
  multiplexer; heartbeats; sharing a live system with a peer.
- **[`GRANTS.md`](GRANTS.md)** — hands-off execution of a ticket.
