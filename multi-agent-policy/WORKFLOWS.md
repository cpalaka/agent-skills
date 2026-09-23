# Workflow-tool scripts, vendor lenses, and fan-out discipline

Read this when a run's seats are a saved Workflow script rather than Agent-tool sub-agents, or when
a fan-out's results need reconciling. The `multi-agent-policy` Skill governs; nothing here relaxes
it. The Workflow tool's API (`agent()` options, `pipeline`/`parallel`, `workflow()`, resume) is the
`workflow-authoring` skill's; this file is the policy overlay and the gotchas that reference lacks.
Where a Codex equivalent exists it is noted; where not, the rule holds on the host's own dispatch
surface.

## Planner placement in a saved workflow

- **`stages: {<stage>: {model, effort}}` is the pin, per stage** — a stage names a role or runs on
  the script's default. The pin is a family alias (`opus`, `fable`)
  ([ADR 0017](../docs/adr/0017-seats-pin-family-aliases.md)).
- **Planner only on a stage whose agent count is fixed**: the completeness critic and
  counter-critic (one or two agents), a tournament's final synthesis (exactly one). Finders scale
  with the lens count and were measured to gain nothing from the role (2026-08-08).
- **Verify never takes Planner.** It is scoped diligence, and its count is unbounded at launch, so
  a pin there cannot be projected. A script that allows one anyway warns that its projection
  excludes it.
- **Announce the projected Planner-agent count with a pre-selected recommendation**, and log by
  name anything the projection excludes.

Why rationing became pricing: ADR 0006, superseded by
[ADR 0011](../docs/adr/0011-roles-not-cost-tiers.md).

## Spawn-time knobs

- **`budget`**: guard every loop on `budget.total`. With no target, `remaining()` is `Infinity` and
  the loop runs to the 1000-agent backstop.
- **`agentType`** resolves from the same registry as the Agent tool, so an edited definition can
  serve stale (Skill § Spawning).
- **Per-agent `effort`** makes the `high` pin enforceable per stage. `low` is for mechanical stages
  only, never a verify or critic slot.
- **`workflow()` nesting** shares the parent's agent counter and token budget: a nested call counts
  toward your projection and size limit.

## Fan-out → verify discipline

- **Severity-tier the verification.** 3-vote panels for HIGH only; MEDIUM gets one verifier that
  escalates on uncertainty; LOW is main-loop judgment. Panels on vague findings amplify noise.
- **Always run a completeness critic** in a diff review ("what did the finders miss"), distinct from
  the finders. Inside an implementation run it is the critic seat, a fresh Builder `code-reviewer`
  dispatch covering this critic and the counter-critic below (`implement-run` § Review).
- **Pair it with a counter-critic aimed at the review, not the subject**, hunting method error:
  category errors, speculative-generality remedies, stage-inappropriate standards, absence claims
  whose refuting evidence sat outside the finders' scope. A scoped verifier is blind to a scope
  error (2026-07-25). Task it with auditing the refuters, hunting duplicate clusters, and hunting
  asymmetry: "if the other arm has the same property and was not charged, say so". Budget one on
  any review where you also wrote the spec — it is the only slot pointed at you, and its kills of
  your measurements were premise errors. Its kills are still claims to verify.
- **Assert the input layer arrived before trusting any stage output.** An input-starved run
  completes "successfully": a brief that arrived as `"undefined"` produced an on-theme run that only
  pool-size arithmetic caught (2026-07-30). Parse `args` defensively, hard-throw on a missing
  required field, and give every smoke run a pre-derived expected input count.
- **Reconcile items sent against verdicts returned**, not survived against refuted: a
  `.catch(()=>null)` or `.filter(Boolean)` drops an item while those two still reconcile. Emit a
  `dropped`/`errored` bucket and verify each drop from `journal.jsonl`. **Recurse to the vote
  level**: one dropped vote turns a refute-majority into a surviving tie, so adjudicate any survivor
  that passed on a tie or a missing vote. Treat a cached or replayed result as empty until read.
- **Reconcile output files against assignments by name, not count.** Duplicate agent instances can
  run outside the workflow's accounting and write extra files (2026-08-27); keep unmatched files
  until adjudicated.
- **Merge semantically between find and verify.** A refuter kill binds only the copy it ran
  against, so a duplicate's twin survives at HIGH (2026-07-30), and a structural key
  (`route + target + claim-prefix`) merges nothing across lanes. Cluster by title+claim similarity
  with the threshold tuned on the real corpus, since over-merging destroys distinct claims. Give
  each defect one severity and one owner before verification; where no merge stage is practical,
  the counter-critic hunts clusters.
- **Nobody in the fan-out can see asymmetry in the harness you built.** Before synthesising,
  re-read your own design for coverage given to one subject and not the other.

## Vendor lenses: the direct CLIs, never the plugin bridges

On any reasonably sized diff, after the internal pass, run Grok and Codex reviews framed for
refutation; vendor diversity catches what same-family redundancy cannot (2026-07-17). The
implementing delegate reviewing its own diff is a conflict of interest. Hold fix commits until every
lens returns, or a lens re-reports fixed defects as live.

Measured on grok-build 0.2.0 and the Codex companion as of July 2026; a disagreement with the live
CLI means this section is stale. Confirm each binary resolves first (`command -v grok codex`).

**The bridges (`grok-build:grok-delegate`, `codex:codex-rescue`) return a schema-valid
placeholder**, so as a finder lens they read clean at zero coverage. The direct CLIs return real
findings synchronously (~6–8 min):

```sh
grok  --cwd <dir> --always-approve -p "$(cat PROMPT.txt)"
codex exec --skip-git-repo-check -s read-only -C <dir> "$(cat PROMPT.txt)" < /dev/null
```

- **Both `codex exec` flags are load-bearing and their absence is silent.** Without
  `< /dev/null` it hangs on stdin, background or foreground (23 min background, 2026-07-30; 300 s
  in a foreground compound command, 2026-09-04); the "Reading additional input from stdin…" line
  prints on completed runs too, so it is not the tell. Without `--skip-git-repo-check` it exits 0
  with zero bytes outside a git repo.
- **The exit code is worthless; assert `wc -c` on the output.** Arm a bounded watcher that reports
  the byte count either way. `codex exec` writes its transcript to stderr and only the report to
  stdout, so 0-byte stdout mid-run is normal.
- **Hand vendors a read-only snapshot** — `git archive <sha> | tar -x -C $TMPDIR/…` plus a
  `git diff` patch — which pins the reviewed SHA.
- **Run them sandbox-off** (xAI hosts are not allowlisted). Liveness is a growing rollout file,
  never `ps`/`pgrep`, which report a live process dead under the sandbox.
- **Vendor findings skip the skeptic panels**: adjudicate each against source in the main loop,
  spawning scoped verifiers for deep HIGHs.
  Both vendors have carried real errors (2026-07-24), and one caught a defect the other passed
  (2026-07-27).

## `args` does not arrive the way you passed it

- **A resume drops `args`.** Re-pass the original `args` verbatim with `resumeFromRunId`; the
  identical string also keeps the journal cache keys matching (2026-06-06).
- **An object `args` can arrive stringified**, so `args.X` is `undefined` — agents once wrote to
  literal `undefined/...` paths for hours. Hardcode critical constants in the script body; template
  dynamic data into the script text and launch by `scriptPath`.
- **Stringification silently disables a mode toggle** — `args: {smoke: true}` ran at full scale.
  Launch the smoke run with a plain string (`args: "smoke"`), test
  `typeof args === 'string' ? args.includes('smoke') : !!(args && args.smoke)`, and confirm from
  `journal.jsonl` that the toggle engaged before scaling up (2026-06-19).

## Symptoms that mislead

- **Every agent "completed without calling StructuredOutput" with empty sources** is a usage limit,
  not a schema bug: look for "You've hit your session limit" in a failed transcript. At a verify
  stage the same hit reads as 0-0 abstains, which look like kills.
- **WebSearch is one pool per session** (default 200), drained by every sub-agent with no warning
  (2026-08-26). Reserve main-loop searches for verification, or raise
  `CLAUDE_CODE_MAX_WEB_SEARCHES_PER_SESSION` before a research fan-out. A fresh session refills
  it, so hand deferred searches to the next one.
- **A `SendMessage` to an agent finishing its turn is dropped** despite "queued for delivery".
  Verify the addendum landed; if not, resend it as a resume of that agent (2026-09-12).

## Reading a run

The `.output` file named in the `<task-notification>` is a wrapper
(`{summary, agentCount, logs, result}`); read `wrapper.result`, `JSON.parse`-ing it if a string.
The inline `<result>` is the same object truncated. The runtime's `node:fs` / `Date.now()` ban
covers the script body only, not a Node helper that parses the file.

A running workflow uses the script as loaded at launch; edits apply only on `resumeFromRunId`
(`TaskStop`, then relaunch with it — a stopped run is reusable). The
same script plus the same `args` is a 100% cache hit, so a resumed run can report results no agent
produced this session. Appending to a stage you will not re-run invalidates everything downstream;
a top-of-file `const` edit does not.

| File | Holds | Read it for |
|---|---|---|
| `journal.jsonl` | each call's **return value** | drop reconciliation; a thin result |
| `agent-<id>.jsonl` | each agent's **spawn config** + raw turns | whether `"model"` applied; fallback with no journal |

## Stale registries

- **After editing a `.claude/workflows/` script, launch by `scriptPath`, never by `name`**: by-name
  can serve a session-start copy. Verify the configuration by grepping `agent-*.jsonl` for
  `"model"`, not from a line the script prints.
- **Codex agent definitions and skill metadata are session inputs.** After changing
  `~/.codex/agents/*.toml`, `~/.agents/skills/` or an `agents/openai.yaml`, validate discovery in a
  new Codex task.
