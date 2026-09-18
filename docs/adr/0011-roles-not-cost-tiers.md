# Capability roles, not cost tiers, decide which model fills a seat

**Status:** accepted — 2026-09-17. Supersedes [ADR 0006](0006-scarce-tier-posture-ladder.md).

ADR 0006 replaced a rationing rule with a cost-ordered ladder: price each slot, buy the posture
whose cost shape fits. That was the right correction to make in August, and the ladder's own
measurement is what retires it. The `insight` rung was measured and unsupported; the `full` rung
survives in exactly one place, a tournament's single synthesis agent; and `critic` — the one rung
the ladder recommended — turned out to describe a *seat*, the advisor, whose cost is fixed at one
persistent agent per ticket regardless of diff size. A ladder with one live rung is not a ladder.

Worse, the vocabulary was wrong about what the owner decides. `workhorse`, `budget` and `scarce`
name what a model *costs*. Nobody routes on cost. The question at every dispatch is what kind of
thinking the seat needs: unscoped judgment over an ambiguous subject, or correctness-bearing work
against a specification that already exists. Cost correlates with that and does not constitute it,
so the tier names forced a translation step at every read — and 36 percent of spawning sessions
skipped the Skill that defined them entirely. A third tier (`budget`) existed for
non-correctness-bearing sweeps and was never once the deciding factor in a live run.

**Decision.** Two capability roles, each defined by a property rather than a model name.
**Planner** is the role that draws on its own weekly meter; **Builder** is the strongest role with
no meter of its own. A run routes by role: Planner for wayfinder, grill, spec, spec-review and
to-tickets sessions and for the advisor seat inside an implementation run; Builder for the
coordinator and every other seat. The definitions live in `CONTEXT.md` § Multi-agent runs and the
routing rules in the `multi-agent-policy` Skill. Effort is pinned `high` on every seat, with no
higher path: the one slot that argued for more was the completeness critic, and inside a run that
slot is filled by a seat already carrying the ticket's context, which is most of what the higher
effort was buying a fresh agent.

**Considered options.**

- **(a) Keep the cost tiers and re-derive the ladder against the current window.** Rejected: it
  re-runs the 0006 exercise on the same mistaken axis. The ladder's rungs were already measured —
  one unsupported, one vestigial — and re-pricing them answers a question nobody asks at dispatch
  time. It also leaves the translation step that the non-load measurement blames.
- **(b) One dated binding line mapping each tier to a concrete model.** Rejected: a durable
  rule naming a model goes stale silently. This failed in production on 2026-08-25, when a seat
  definition kept dispatching a retired model against a rule that still read correct. A date on
  the line records when it was true, not when it stopped being.
- **(c) Roles defined by property.** Chosen. "Draws on its own weekly meter" and "strongest with no
  meter of its own" are facts about the account, checkable at any moment, and they survive a model
  release without an edit. The property is also the thing the owner is actually rationing.

**Consequences.**

- ADR 0006 is superseded. Its body stands as the record of why rationing became pricing; the
  posture ladder it specifies no longer binds, and the `multi-agent-policy` Skill no longer
  describes one.
- **The budget tier is retired with no replacement.** There is no cheaper third role. Work that is
  not correctness-bearing either runs on Builder or does not run.
- **Model IDs live in run artifacts only** — seat definitions and workflow scripts, one concrete
  probe-resolved ID per artifact, never an alias. No durable rule (Skill prose, Chunk, project
  contract, ADR, either host's global instruction file) names a model. A model-family change is
  therefore one edit per run artifact, and the seat definitions' model fields join the
  `context-hygiene` reverse pass so a stale pin is found rather than waited for.
- **[ADR 0009](0009-init-project-emits-contract-and-two-adapters.md)'s three engine-owned files
  become four.** The gate-runner seat is stamped per project like the contract and the two host
  adapters, because the independence rule — a seat that did not write the diff re-runs the gate —
  has to hold in every project, not only where someone remembered to define one.
- The Skill that carried the tiers keeps its name and loses its procedure: the procedure becomes
  the `implement-run` Chunk, loaded by every dev project, and the Workflow-era material becomes
  sibling files nothing loads by default.
