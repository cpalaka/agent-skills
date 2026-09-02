---
name: tournament
description: Tournament workflows — generate → judge → verify → synthesize in any domain, from a persisted reusable spec. Use to "run a tournament", do a "generate-and-judge" pass, "pick the best X via fan-out", or build a "bracket/scoreboard of candidates".
---

# Tournament

Turn a recurring "generate a bunch, judge them, pick and refine a winner" job into an editable, reusable **spec** and a self-contained **Workflow** script. This skill is a code generator, not a library: the Workflow runtime forbids several JS built-ins (the §6 lint list), so each run emits a fresh literal script.

## 1. When to use & the invariant pipeline

Use when the task is: produce many candidates, screen and rank them, run a judge tournament, stress-test the winner, and synthesize a final answer. Domains are open (game concepts, recipes, research options, skill audits) — only the content changes; the mechanics are invariant:

```
context/research → [verify dubious claims] → generate (N lens-generators + guaranteed "seed" candidates)
  → filter (hard-constraint kill + multi-axis screen → shortlist/bracket)
  → tournament (judge panel; bracket OR scoreboard) → verify champion (adversarial skeptics)
  → synthesize (graft winner + runner-up grafts + skeptic fixes) → [QA red-team + patch]
```

Bracketed stages (`[...]`) are per-spec toggles. Everything else is always present.

## 2. Reuse model (new vs reuse)

Every run **persists a resolved spec** so the design thinking — lenses, judges, axes, domain framing — is saved, not just boilerplate. Runs are reproducible and diffable.

- **Spec path:** `<archive>/<name>.spec.md`, where `<archive>` is a single directory the user picks for this purpose — one central location outside any one project, so a spec is discoverable for reuse from any cwd. Ask once, record the choice in the spec, and reuse it for every run (`$TOURNAMENT_ARCHIVE`, or a fixed path such as `~/tournaments/`, both work).
- **New run:** interview (§3) → write spec → assemble (§5) → gate (§6) → launch (§7).
- **Reuse run:** load an existing `<name>.spec.md`, optionally tweak fields, regenerate. **Reuse skips elicitation entirely** (§3).
- **Spec format:** small YAML frontmatter (scalars/enums/keys: `name`, `domain`, `tags`, `mode: bracket|scoreboard`, counts, `claimVerify`/`qa` toggles, lens/judge/axis keys) + prose under stable `##` headings (domain/constraints block, each lens prompt, each judge persona+rubric, each axis instruction, candidate-field list). See `reference/example-spec.md` for a complete worked example.

At run end, results are written beside the spec as `<archive>/<name>.result-<date>.md` (§7).

## 3. Elicitation (three depths)

The interview fills gaps from the free-form brief, then confirms a compact spec. Strong overridable defaults mean the user supplies only the non-default; the interview **actively elicits domain + lenses + judges + mode** (candidate schema is inferred, §4), and everything else defaults silently but is written into the spec for editing.

Depths are realized by **replicating the posture inline**. If a separate interview skill (`grilling`, `grill-with-docs` or similar) is installed, do NOT sub-invoke it — its hard gates and terminal states fight the tournament flow:

- **quick** (default) — the structured interview: ask only for the missing required fields, propose defaults for the rest, confirm.
- **brainstorm** — collaborative, one question at a time, scoped strictly to producing the `.spec.md` (no design-doc or plan-writing detour).
- **+grill** (opt-in add-on) — a relentless one-at-a-time stress pass over the drafted spec before generating.

**Escalation-suggest heuristic:** default to `quick`, but *suggest* escalating to brainstorm/+grill when stakes are high — many lenses/judges, large estimated agent-count, or the user signals a real decision. Suggest; don't force.

**Reuse skips elicitation** — loading an existing spec goes straight to optional tweak → regenerate.

## 4. Candidate schema (infer + propose)

The candidate shape varies per domain and a flat config can't express it. Strategy: **infer + propose, archetype-seeded.** Carry ~3 archetypes — `creative-concept`, `procedure/recipe`, `evaluated-option` — infer the best-fit field set from objective + domain, and propose it for one-line edits. Default shape = a handful of **structured comparable fields** + an optional **freeform `body` markdown field**.

**Coherence check (during the interview):** verify every axis and judge maps to at least one candidate field; flag any judge with nothing to grade.

## 5. Assembly

Compose the script from the catalog — never write stage boilerplate from scratch.

1. **Read `reference/stages.md`** — the complete stage catalog (meta · schema-builders · render helpers · context · claim-verify · generate · filter · bracket/scoreboard · verify-champion · synthesize · QA · result-shape).
2. **Obey the Binding Contract** at the top of `stages.md` — the verbatim table of binding NAMES + TYPES (`DOMAIN`, `briefs`, `candidates`, `seedIndices`, `kept`, `ranked`, `bracket`/`shortlist`, `champion`/`runnerUp`, `board`/`winner`, etc.). These exact names are what wire stages together and make machine-assembly safe.
3. **Compose ONLY the stages the spec needs**, in pipeline order (drop claim-verify/QA when toggled off; pick bracket *or* scoreboard variant).
4. **Fill each `// FILL:` slot** from the spec.
5. **DELETE any line marked `// STANDALONE PARSE ONLY — DELETE at assembly`** — those exist only so each snippet parses in isolation.
6. **Model policy — every `agent()` pins an explicit, CONCRETE `model:` (never inherit the session model, never a short alias).** Resolve the ID by probe at authoring time and write it out (`WORKHORSE = 'claude-opus-5'`, measured 2026-08-08) — an alias can lag a release and keep serving the prior generation while the rule still reads correct. All stages run the workhorse tier; the single final synthesis agent may opt into `SYNTH_MODEL` on the scarce tier for max-insight synthesis. **Why only that one slot, at this scale:** a tournament fans out 89–111 agents, so scarce placement here is governed by cost *shape*, not by a permission list — every other stage's count scales with the bracket, and only synthesis is fixed at exactly one agent. (This is the `full` rung of the `multi-agent-policy` posture ladder; that skill owns the general rule, and a session-model default silently inheriting into 100+ agents is the blowout this pin exists to stop.) The catalog stages ship pinned; keep them pinned.
7. **Vote-tallying stages reconcile SENT vs RETURNED** (bracket, claim-verify, champion-skeptic): compute `dropped = sent − returned`, log it, and flag any tie or dropped vote as `needsAdjudication` (measured 2026-06-28: a dropped vote silently flips a winner/consensus/fatalCount). The catalog stages already do this; preserve it when filling slots.
8. **Inter-phase bulk data (chained / multi-phase runs): embed, never inline.** When a later phase consumes a prior phase's output beyond a few KB, do not pass it through Workflow `args` — build a `.run.js` from the phase template with the data `JSON.stringify`-ed into the `const` slot, replace the args guard with an embedded-count assertion, re-lint, and launch by `scriptPath`. Oversized inline args spend main-loop output tokens and degrade with no error signal (measured 2026-08-27 on a project: ~270KB phase input).
9. **Kill-panel calibration pins (measured 2026-08-27, one run, all three failed silently):** (a) skeptic/verify schemas carry **≥4 severity tiers** (fatal / near-fatal / serious-fixable / minor) with a prompt that forces discrimination — a flat one-value severity column is the observed failure and it hid two near-refutations behind fatalCount=0; (b) an "evidence-fit" screening axis measures **quote fidelity, not claim support** — split it (verbatim accuracy vs support for the top-3 load-bearing claims) or never report a high score as "claims verified" (a 10 coexisted with a corpus-refuted mechanism); (c) **funders (net-negative-hour candidates) and 0-cost options get their own presented class** — impact-summed ranking structurally buries the enablers every adoption bundle depends on.

**Never hand-edit a generated script.** It is a build artifact; a hand-edit diverges from the spec that produced it and is lost at the next regeneration. To change behavior, **edit the spec and regenerate.**

## 6. Safety gate (lint always; smoke-run on new/edited)

Before any full launch, self-lint the emitted script against the runtime's hard constraints:

```
node reference/lint.mjs <script.js>
```

Exit **0** = clean, **1** = errors (must fix), **2** = usage. It prints `WARN:`/`ERROR:` lines and checks: literal `export const meta`, `meta.phases` match `phase()` calls, **no `Date.now()`/`Math.random()`/argless `new Date()`**, no `import`/`require`/fs, `parallel()` guarded by `.filter(Boolean)`, **every `agent()` pins an explicit `model:` (ERROR if missing)**, **vote-tallying stages reconcile sent-vs-returned (WARN if a `winner`/`consensus`/`fatalCount` stage filters results without `dropped`/`votesSent`/`needsAdjudication`)**, and `node --check` syntax. Resolve every `ERROR:` before proceeding.

**Required tiny smoke-run** on a **new or edited** script before full scale: 1 lens / 2 candidates / 1 judge / no web / low effort — a green dry-run proves the wiring. **Skip the smoke-run when re-running an unchanged, previously-green spec.** Never auto-run an unseen full-scale script.

## 7. Launch & relay

1. **Recap:** show the spec recap + the phase outline + the estimated agent-count / cost (§8).
2. **On approval, the main agent launches the assembled script via the Workflow tool (background).** Do not launch without approval.
3. **Relay results:** report + leaderboard/bracket in chat.
4. **Write the result file:** `<archive>/<name>.result-<date>.md`, beside the spec (§2).
5. **Note the `resumeFromRunId` recovery path** — big runs can hit limits mid-flight; resuming from the run id continues rather than restarting.

## 8. Budget

Counts are **explicit in the spec**, so cost is predictable. The launch gate estimates agent-count and, if a `budget.total` target is set, flags whether the run fits and where it would truncate (budget-aware gate). Opt-in **`--scale-to-budget`** derives fleet sizes from `budget.total` for "throw everything at it" runs. Predictable by default, elastic on demand.
