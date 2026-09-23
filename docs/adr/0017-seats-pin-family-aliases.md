# Seats and workflow scripts pin a family alias, not a versioned model ID

**Status:** accepted — 2026-09-22. Amends [ADR 0011](0011-roles-not-cost-tiers.md) § Consequences,
"Model IDs live in run artifacts only", on the form of the pin. Everything else there stands: model
names live in run artifacts and never in durable rules, roles are read off the meter, and every seat
is a pinned definition. [ADR 0006](0006-scarce-tier-posture-ladder.md)'s record of the alias rule
stays as written.

## Context

ADR 0011 required "one concrete probe-resolved ID per artifact, never an alias", on a 2026-07-24
measurement that a CLI short alias lagged a release on the Workflow path. The cost of that rule is
the opposite lag: a versioned pin stays on its version until someone re-probes it, and nothing
prompts the re-probe.

Measured 2026-09-22, the day a new Opus version first served sessions here:

- Over the preceding week, every `implementer` (24) and `code-reviewer` (12) dispatch served the
  pinned `claude-opus-5` — the prior version, from the moment the new one shipped.
- On the Agent tool's `model` parameter, `opus` served `claude-opus-5-5` and `fable` served
  `claude-fable-5-1`, each read from the dispatch transcript.
- With `model: opus` in `code-reviewer`'s frontmatter, a fresh headless session's dispatch served
  `claude-opus-5-5`. Three dispatches from the session that made the edit, over about ten minutes,
  still served `claude-opus-5`: the registry's lazy refresh (`agents/README.md` § Editing here is
  live), not the alias.

No record of the 2026-07-24 measurement survives beyond the sentences citing it.

## Decision

1. **A Claude seat definition and a workflow script pin a family alias** — `opus`, `fable` — never
   a versioned ID. The owner's requirement is the family; the version is whatever is latest.
2. **The role-to-family mapping is still read off the meter**
   ([`multi-agent-policy`](../../multi-agent-policy/SKILL.md) § Which role a session runs on). A
   new version needs no edit; a role moving to a different family is one edit per run artifact,
   and that is what the `context-hygiene` reverse pass now looks for.
3. **`tournament/reference/lint.mjs` drops its `model-alias` rule** and its two fixtures;
   `agent-explicit-pin`, which forbids inheriting the session model, stays.
4. **The Codex role files keep a concrete ID.** Whether Codex resolves an alias in a role file is
   unmeasured, and its `model` field is checked by nothing (`agents/README.md`), so a guess there
   would fail silently.

## Consequences

- An alias that lags a release serves the prior version until the host updates it, with no signal
  here. Accepted: that lag is bounded by the host, while a pin's is bounded by someone noticing.
- Verify a seat's model from a **fresh** session, never the one that edited the file.
- Projects already stamped by `init-project` carry a copied `gate-runner.md` with the old pin; the
  Template changes, the copies do not, until each project is re-stamped or edited.
