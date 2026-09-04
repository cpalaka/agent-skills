---
name: multi-agent-policy
description: Model/effort tiers and orchestration procedure for multi-agent work. Use before spawning any agent (a subagent, workflow, fan-out, adversarial review, tournament, or orchestrator-delegate handoff); when reconciling a fan-out's results; when a peer session shares the live system; and before dispatching an external vendor lens.
---

# Multi-agent policy

**Hard pins**, mirrored in the host's global instructions so they hold unloaded: workhorse tier for all agent work; the budget tier only for work that bears no correctness; scarce tier opt-in per launch; a scarce main loop orchestrates implementation by default.

**Two agent-count ceilings, and the smaller binds.** This skill's ceiling: a projection over 20 agents gets announced. Claude Code's dynamic workflow size (`/config`, default *medium*, under 15): a design over it, such as a full adversarial review or any tournament, needs the setting raised before launch, and announcing the count does not substitute. Project from the current args; a count recorded at authoring time is stale by definition.

Rules here are host-independent. A recipe written for one host says nothing about whether the other host exposes the same tool.

## Before the first spawn

1. **Pin model and effort per stage** (§ Model & effort pins). Done when every stage names both.
2. **A delegated implementation run: ask which orchestration shape, and record the answer** (§ Orchestrator-delegate procedure).
3. **Project the agent count and the scarce posture, and confirm scarce headroom on both usage windows** (§ Scarce tier).
4. **Announce** each ceiling crossing by name, the scarce projection with a recommendation, and any budget-tier composition with its de-risk.
5. **Persist the approved spec** to the artifact the run reads.
6. **Give every smoke run a pre-derived expected input count** (§ Fan-out → verify discipline).

## Tier roles

This skill names tiers, never models:

- **workhorse**: the strongest model with no weekly cap. Default for all agent work.
- **budget**: cheaper, faster models. Non-correctness-bearing sweeps only, under § Budget-tier exception.
- **scarce**: the weekly-limited premium tier. The rate limit decides membership, not the vendor's "generally available" label, and it may be the session default. Opt-in per launch.

No durable role-to-model mapping exists anywhere, because a stale one misroutes silently. A run's script still names a concrete model ID, resolved by probe at authoring time. Memory and aliases both fail this: an alias lagged a release and kept serving the prior generation (2026-07-24). `opus-implementer` and the `fable` arg are a filename and a script parameter, not tier claims; they stay verbatim because renaming breaks live pointers.

## Model & effort pins

- **Set model and effort explicitly on every stage.** Inheritance is silent. Before launching a saved workflow you did not author, grep it for per-stage `model:` pins.
- **Claude Code's Agent tool pins only `model`.** It cannot pin effort and cannot override a definition's pin. Pin effort through the Workflow tool, `agent(prompt, {model, effort})`, or through a definition whose frontmatter carries both, such as `~/.claude/agents/opus-implementer.md`. Codex: subagents or definition-backed agents from `~/.codex/agents/*.toml`, with `reasoning_effort` pinned on the dispatch where the surface permits.
- **Implementation stages run the delegate at `high`; `xhigh` is the user's call.** Ask (AskUserQuestion: high vs xhigh, one line on why this phase might warrant it) and dispatch the answer. On Claude Code `xhigh` means the Workflow tool: `agent(spec, {agentType: 'opus-implementer', effort: 'xhigh'})`.
- **Verification effort follows the review mode:** modest = `high`, full = `xhigh`.

## Scarce tier

**Confirm headroom on both usage windows**, the weekly one and the five-hour session window, before committing the tier to a stage. A fan-out of N xhigh scarce agents can drain the session window in minutes. The failure is clean (journal rows read `failed`), so relaunch fresh after the reset rather than resuming (2026-09-01). When a window is about to expire with budget unspent, the guard inverts: spend it.

**Placement is a cost ladder, not a permission list.** Derive it per stage from cost per slot against value at that slot. A rationing rule expires when the ration changes; the ladder does not. Choose a *posture*; rungs are cumulative.

| Posture | Adds | Buys | Cost shape |
|---|---|---|---|
| `none` | nothing | nothing | 0 agents. The default. |
| `critic` | completeness critic + counter-critic | the absence and method-error slots, where insight beats diligence most sharply | 1–2 agents, **fixed** regardless of diff size. **Recommend here.** |
| `insight` | finders | **no gain (2026-08-08)** | scales with lens count (8–12), the first rung whose cost is not fixed |
| `full` | synthesis | cross-finding narrative | +1 agent |

**`insight` is measured and unsupported. Stop at `critic` unless this run differs in a way you can name.** Scarce finders found fewer findings and no HIGH. A shader- or spec-heavy subject may invert that, and vendor lenses buy the same diversity more cheaply. Method, limits and the kind-split: ADR 0006 (`docs/adr/0006-scarce-tier-posture-ladder.md` in the repo this skill ships from).

**Verify stays workhorse at every rung.** Verification is scoped diligence against named files, and the scarce tier's edge is unscoped judgment. It is also the only stage whose count is unbounded at launch, so a scarce pin there cannot be projected. An override may still force it; the script must then warn that the projection excludes it.

**Announce the projected scarce-agent count with a pre-selected recommendation.** "Recommend `critic`, 2 scarce agents" can be disagreed with. "fable or not?" makes the user do the arithmetic. Log by name anything the projection excludes. Arg surface (`scarce`, `fable`, `stages`): `MECHANICS.md`.

## Budget-tier exception

When the user flags low usage or asks to conserve, a non-correctness-bearing fan-out (cataloging, extraction, a doc-reading sweep) may run on the budget tier with a small agent count (the `budget` global, `MECHANICS.md`). De-risk it by reading the dense sources yourself and validating the cheap output. Correctness-bearing work (code review, load-bearing verification) stays on the workhorse tier, always. Announce the composition and the de-risk, and offer the trade-off before spending workhorse capacity on a big fan-out.

## Verification structure

- **Scope each verifier prompt** to the named files, lines and spec refs it must check. An unscoped xhigh verifier roams the repo and misjudges.
- **Severity-tier the verification.** 3-vote panels for HIGH only; MEDIUM gets one verifier that escalates on uncertainty; LOW is main-loop judgment. Panels on vague findings amplify noise.
- **Always run a dedicated completeness critic** in a diff review ("what did the finders miss"), a slot distinct from the finders, at the premium effort: scarce at xhigh when opted in with headroom, otherwise workhorse at xhigh.
- **Pair it with a counter-critic aimed at the review, not the subject**, at the same effort, hunting method error: category errors, speculative-generality remedies, stage-inappropriate standards, absence claims whose refuting evidence sat outside the finders' scope. A scoped verifier is the wrong tool for this slot: scoping is right for checking a fact and blind to a scope error (2026-07-25). Task it explicitly with:
  - **auditing the refuters**: a bad kill costs what a bad finding costs;
  - **hunting duplicate clusters** (§ Fan-out → verify discipline);
  - **hunting asymmetry**: "check every survivor against the other arm; if the other arm has the same property and was not charged, say so".
- **Expect the counter-critic to correct you.** Its kills of the orchestrator's own measurements were premise errors: right numbers, wrong reading. Budget one on any review where you also wrote the spec; it is the only slot pointed at you. Its kills are still claims to verify, since one was its own error.
- **Nobody in the fan-out can see asymmetry in the harness you built**, such as a battery run on one arm and not the other; each agent sees only what it was pointed at. Before synthesising, re-read your own fan-out design for coverage given to one subject and not the other, and close the gap yourself.
- **Adjudicate each finding in the main loop, per finding, never once per session.** Before accepting a finding as novel or as an absence: `git show main:<file>` (pre-existing?) and grep the sibling tasks' notes and AC (already owned?). Reading the board at session start does not count. Every miss came from adjudicating against code while skipping the intent layer.
- **A criterion that predicts behaviour is checked against the measurement, never against the fact that a measurement was recorded.** When the record refutes the prediction, supersede the criterion in place with what was proven and carry the refutation into the parent's criteria; a sibling "recorded in the notes" criterion is not evidence for the behavioural one (2026-09-03: a "stops at the git gate" AC stayed checked across two tickets after the pilot record said the child pushed; only the counter-critic caught it).
- **Run external vendor lenses on any reasonably-sized diff.** After the internal pass, run Grok and Codex reviews framed for refutation; vendor diversity catches what same-family redundancy cannot (2026-07-17). Adjudicate every finding against source before acting, and hold fix commits until every lens returns. The implementing delegate reviewing its own diff is a conflict of interest; the other vendor is the independent lens. Dispatch through the direct CLIs, since the plugin bridges return placeholders; invocations and silent failures: `MECHANICS.md` § Vendor lenses.

## Fan-out → verify discipline

- **Assert the input layer arrived before trusting any stage output.** Agents reverse-engineer missing context from the repo, so an input-starved run completes "successfully": a brief that arrived as `"undefined"` produced an on-theme run that only pool-size arithmetic caught (2026-07-30). Parse `args` defensively (`typeof args === 'string' ? JSON.parse(args) : args`), hard-throw on a missing required field, and give every smoke run a pre-derived expected input count so a missing layer reads as a number mismatch.
- **Reconcile items sent against verdicts returned, not `survived` against `refuted`.** A `.catch(()=>null)` or `.filter(Boolean)` drops an item while survived+refuted still reconcile. Emit a `dropped`/`errored` bucket; when sent ≠ verdicts, recover each drop from `journal.jsonl` and verify it in the main loop. Treat a cached or replayed result as empty until you have read it.
- **Reconciliation recurses to the vote level.** With N-skeptic panels, reconcile `votesReturned` against `votesSent` per finding: one dropped vote flips a refute-majority into a tie that "survives". Adjudicate any survivor that passed on a tie or a missing vote.
- **Reconcile output artifacts against assignments by name, not count.** Duplicate agent instances can run outside a workflow's accounting and write extra files under self-chosen names (2026-08-27). After any file-writing fan-out, list the target dir and match each file to its assignment. Keep unmatched files until adjudicated, since duplicate pairs disagree on real figures.
- **Merge semantically between find and verify, and adjudicate defect by defect.** Sent-vs-returned is blind to duplicates; a structural key (`route + target + claim-prefix`) merges nothing across lanes; and a refuter kill binds only the copy it ran against, so the twin survives at HIGH and carries a false correction into a durable artifact (2026-07-30). Cluster by title+claim similarity with the threshold tuned against the real corpus rather than chosen by eye, because over-merging destroys distinct spec claims. Give each defect one severity and one route owner before verification. Where a merge stage is impractical, the counter-critic hunts clusters.
- **A refuted finding about a protected invariant gets a second look** (a11y, reduced-motion, security, data loss, irreversibility). A refutation resting on one narrow premise can hold for the scenario raised and fail for one not raised; re-check it against other layouts, routes, settings and inputs. A kill that feels authoritative is exactly when a wrong one ships.
- **A confirmed finding proves the defect, not the remedy.** Finder fix-hints are drive-by hypotheses; re-derive any fix against the real system model before pinning it.

## Orchestrator-delegate procedure

A scarce main loop given an implementation task (a correctness-bearing code or data diff) orchestrates by default. Exceptions (trivial edits, visual/feel work, editor-MCP writes) are judged on a ticket's total implementation surface, not edit by edit. Toggles: `"solo"` disables delegation, `"orchestrate"` re-enables it. The delegate is `~/.claude/agents/opus-implementer.md` (Codex: `~/.codex/agents/opus-implementer.toml`). `/implement` runs under this pattern: the delegate executes the `/tdd` red-green slices from the ticket spec, and the closing `/code-review` stays in the main loop.

- **Ask which orchestration shape the run takes before the first spawn, on every delegated run in every project.** Three shapes: Agent-tool subagents, a coordinator pane driving interactive child sessions, a saved workflow. Pre-select from `MECHANICS.md` § Choosing the orchestration shape, state the deciding question in one line, and put it to the user (AskUserQuestion) with the recommendation first. Record the answer in the artifact the run reads (the parent ticket's notes) so a resumed session inherits it (2026-09-02).
- **Where a project has asked for per-ticket delegate control, ask which delegate writes the diffs** at each implementation ticket's start (after plan approval, before any spawn), via AskUserQuestion over the available lenses. External-CLI writers get the same handoff re-verification as Claude subagents (2026-07-17).
- **The main loop writes the per-phase execution spec; the delegate writes the diffs at its pinned `high`** (§ Model & effort pins for `xhigh`). The main loop re-verifies every handoff against source and runs all gates (tests, typecheck, smoke, scans) itself.
- **A command written into a delegate spec carries your unverified premises, and the delegate cannot audit one the spec presents as settled.** Name the goal and let the delegate establish the command, or verify it yourself first. A help, dry-run or status flag is inert by convention, not by guarantee: read the CLI's source before invoking its binary to learn it (an `npx` tool is already unpacked in `~/.npm/_npx`). `npx impeccable skills update --help` performed a real update, honouring `--help` only as `argv[0]` and treating EOF at the confirm prompt as yes (2026-08-29).
- **On every feature branch, delegated or solo, after the gates and before the user handoff, run the two-axis code-review** (Standards + Spec sub-agents in parallel) against the merge-base. Adjudicate every finding against source in the main loop, route confirmed ones back to the original implementer, re-run the gate on the fix, and include the outcome in the handoff. `"solo"` turns off delegation and leaves this review on: the orchestrator reviewing its own delegation or diff is a conflict of interest, and this is the independent lens when no vendor pass runs (2026-08-24).
- **Check `git status` after every fan-out.** Subagents on either host write scratch probes into the working tree even when told to stay clean and even when their report claims they did. Sweep before any commit, and inspect before deleting; a stray sometimes holds a real measurement.
- **Heartbeat.** A background delegate expected to exceed ~10 minutes gets a calibrated liveness check; solo and interactive work need none. No growth and no commit earns one liveness probe (`find <scope> -mmin -12`) before you declare a hang, since a static tree is also what a gate run looks like. Verify the monitor's transcript key against one real journal line before reporting from it: a monitor grepping the wrong field reports `completed=0` forever while agents finish (Claude Code: the `verification-discipline` skill). Recipes per host: `MECHANICS.md` § Heartbeat recipes.
- **Inject mid-run context by editing the script for a resume, and reach live agents through the artifacts they were told to read.** Point every agent at the task row rather than inlining the brief: a finding measured after dispatch reaches an in-flight agent only through a file its prompt already named. Mechanics: `MECHANICS.md` § Resume and the transcript files.

## Sibling files

**`PROCEDURES.md`**, read when you are:

- granting an orchestrator hands-off execution of a ticket (convert the gates rather than skipping them);
- starting a planning session over a multi-session doc corpus (sweep it for rot first).

**`MECHANICS.md`**, read when you are:

- writing or editing a workflow script (`scarce`/`stages` args, `budget`, spawn knobs, the `args` channel, resume and transcript files, ultracode);
- dispatching a vendor lens (§ Vendor lenses);
- about to make the first spawn of a delegated run (§ Choosing the orchestration shape);
- driving tickets through interactive child sessions in a terminal multiplexer (§ Coordinating interactive child sessions);
- arming a heartbeat on a long delegate (§ Heartbeat recipes);
- launching a research fan-out (§ WebSearch pool);
- re-launching after a mid-session edit to a workflow script, agent definition or Codex skill metadata (§ Stale-registry and cache gotchas);
- sharing the live system you mutate or observe with a peer session (§ Cross-session coordination).
