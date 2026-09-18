# Workflow-tool scripts, vendor lenses, and fan-out discipline

The Workflow tool's own era has largely ended, and nothing loads this file by default. It holds
what a run still needs when the seats are a saved script rather than Agent-tool sub-agents: how to
place the Planner role in one, the spawn knobs, the fan-out → verify discipline, and the vendor
lenses. The `multi-agent-policy` Skill governs; nothing here relaxes it. The Workflow tool's API
itself (`agent()` options, `pipeline`/`parallel`, `workflow()`, resume) belongs to the
`workflow-authoring` skill — this file carries only the policy overlay and the gotchas that
reference lacks.

Codex equivalents are noted where they exist. Where they don't, the rule still holds and the
mechanism is the host's own dispatch surface.

## Planner placement in a saved workflow

[ADR 0011](../docs/adr/0011-roles-not-cost-tiers.md) retired the cost-ordered posture the older
scripts encoded, along with the opt-in argument that selected it. What survives is the mechanism
that always outranked it and the measurement that explains where the Planner role earns its place.

- **`stages: {<stage>: {model, effort}}` is the pin, per stage.** It is how a deliberate placement
  is expressed, and it is why no posture argument is needed: a stage either names a role or runs on
  the script's default. **Model IDs are concrete and probe-resolved**, never short aliases;
  `tournament/reference/lint.mjs` ERRORs on a bare alias in any script.
- **Planner belongs only on a stage whose agent count is fixed**, never on one that scales with the
  bracket. The completeness critic and its counter-critic are fixed at one or two agents regardless
  of diff size; a tournament's final synthesis is fixed at exactly one. Finders scale with the lens
  count, and were measured to gain nothing from the role (2026-08-08).
- **Verify never takes Planner.** Verification is scoped diligence against named files, which is
  not what the role buys, and it is the only stage whose count is unbounded at launch — so a pin
  there cannot be projected. If a script allows one anyway, it must warn that its projection
  excludes it.
- **Announce the projected Planner-agent count with a pre-selected recommendation.** A count the
  owner can disagree with beats a question that makes him do the arithmetic. Log by name anything
  the projection excludes.

The measurement behind the placement rule is ADR 0006 (see `docs/adr/README.md`), superseded by
0011 but standing as the record of why rationing became pricing.

## Spawn-time knobs

- **`budget`** caps a run against a token target. Guard every loop on `budget.total`: with no
  target set, `remaining()` is `Infinity` and the loop runs to the 1000-agent backstop.
- **`agentType`** is the workflow-side equivalent of a seat dispatch, resolved from the same
  registry as the Agent tool, so it is subject to the stale-registry rule below for edited
  definitions.
- **Per-agent `effort`** is what makes the `high` pin enforceable per *stage* rather than per run.
  `low` is for mechanical stages only, never a verify or critic slot.
- **`workflow()` nesting** shares this run's agent counter and token budget. The child's agents
  count toward **your** projection and **your** size limit, so a nested call is a spending
  decision, not a refactor.

## Fan-out → verify discipline

- **Severity-tier the verification.** 3-vote panels for HIGH only; MEDIUM gets one verifier that
  escalates on uncertainty; LOW is main-loop judgment. Panels on vague findings amplify noise.
- **Always run a dedicated completeness critic** in a diff review ("what did the finders miss"), a
  slot distinct from the finders. Inside an implementation run this is not an extra agent: it is the
  advisor's second slot, one consult covering this critic and the counter-critic below, because part
  of what a fresh agent would need buying is the ticket context that seat already holds.
- **Pair it with a counter-critic aimed at the review, not the subject**, hunting method error:
  category errors, speculative-generality remedies, stage-inappropriate standards, absence claims
  whose refuting evidence sat outside the finders' scope. A scoped verifier is the wrong tool here —
  scoping is right for checking a fact and blind to a scope error (2026-07-25). Task it explicitly
  with **auditing the refuters** (a bad kill costs what a bad finding costs), **hunting duplicate
  clusters**, and **hunting asymmetry**: "check every survivor against the other arm; if the other
  arm has the same property and was not charged, say so".
- **Expect the counter-critic to correct you.** Its kills of the coordinator's own measurements were
  premise errors: right numbers, wrong reading. Budget one on any review where you also wrote the
  spec; it is the only slot pointed at you. Its kills are still claims to verify, since one was its
  own error.
- **Assert the input layer arrived before trusting any stage output.** Agents reverse-engineer missing context from the repo, so an input-starved run completes "successfully": a brief that arrived as `"undefined"` produced an on-theme run that only pool-size arithmetic caught (2026-07-30). Parse `args` defensively (`typeof args === 'string' ? JSON.parse(args) : args`), hard-throw on a missing required field, and give every smoke run a pre-derived expected input count so a missing layer reads as a number mismatch.
- **Reconcile items sent against verdicts returned, not `survived` against `refuted`.** A `.catch(()=>null)` or `.filter(Boolean)` drops an item while survived+refuted still reconcile. Emit a `dropped`/`errored` bucket; when sent ≠ verdicts, recover each drop from `journal.jsonl` and verify it in the main loop. Treat a cached or replayed result as empty until you have read it.
- **Reconciliation recurses to the vote level.** With N-skeptic panels, reconcile `votesReturned` against `votesSent` per finding: one dropped vote flips a refute-majority into a tie that "survives". Adjudicate any survivor that passed on a tie or a missing vote.
- **Reconcile output artifacts against assignments by name, not count.** Duplicate agent instances can run outside a workflow's accounting and write extra files under self-chosen names (2026-08-27). After any file-writing fan-out, list the target dir and match each file to its assignment. Keep unmatched files until adjudicated, since duplicate pairs disagree on real figures.
- **Merge semantically between find and verify, and adjudicate defect by defect.** Sent-vs-returned is blind to duplicates; a structural key (`route + target + claim-prefix`) merges nothing across lanes; and a refuter kill binds only the copy it ran against, so the twin survives at HIGH and carries a false correction into a durable artifact (2026-07-30). Cluster by title+claim similarity with the threshold tuned against the real corpus rather than chosen by eye, because over-merging destroys distinct spec claims. Give each defect one severity and one route owner before verification. Where a merge stage is impractical, the counter-critic hunts clusters.
- **Nobody in the fan-out can see asymmetry in the harness you built**, such as a battery run on one arm and not the other; each agent sees only what it was pointed at. Before synthesising, re-read your own fan-out design for coverage given to one subject and not the other, and close the gap yourself.

## Vendor lenses: call the CLIs directly, not the plugin bridges

- **Run external vendor lenses on any reasonably-sized diff.** After the internal pass, run Grok and Codex reviews framed for refutation; vendor diversity catches what same-family redundancy cannot (2026-07-17). Adjudicate every finding against source before acting, and hold fix commits until every lens returns. The implementing delegate reviewing its own diff is a conflict of interest; the other vendor is the independent lens. Dispatch through the direct CLIs, since the plugin bridges return placeholders; the invocations and their silent failures are the rest of this section.

> **Version caveat.** Everything here was measured against grok-build 0.2.0 and the Codex companion
> plugin as of July 2026, and verbs shifted once *within* that month. Re-verify a verb before
> depending on it, and treat a disagreement between this section and the live CLI as this section
> being stale. **Confirm each binary resolves before launching** (`command -v grok codex`): on
> 2026-09-02 the `grok` symlink was dangling, which reads as command-not-found only at launch.

**The plugin bridges return nothing.** `grok-build:grok-delegate` and `codex:codex-rescue` forward
the prompt to a background runtime, are forbidden from polling, and return a schema-valid
**placeholder**. Slot one as a finder lens and sent-vs-returned reads **clean at zero vendor
coverage**, because a placeholder is a return. Both refuse follow-up work via SendMessage.

**The direct CLIs return real findings synchronously** (validated 2026-07-27/28: ~6–8 min, 10–12 KB
on a 410-line spec):

```sh
grok  --cwd <dir> --always-approve -p "$(cat PROMPT.txt)"
codex exec --skip-git-repo-check -s read-only -C <dir> "$(cat PROMPT.txt)" < /dev/null
```

- **`codex exec` fails twice, silently, before it runs.** It hangs on stdin even with the prompt as
  an argument (stderr sits on `Reading additional input from stdin...`), so pass `< /dev/null`. It
  then exits 0 with zero bytes because it refuses to run outside a git repo, invisible until stdin
  is closed, so pass `--skip-git-repo-check`.
- **The exit code is worthless. Assert `wc -c` on the output file.** Both failures present as
  "completed, exit 0"; trusting absence-of-error drops coverage to one lens, the failure this rule
  exists to prevent. Arm a bounded watcher that reports the byte count either way.
- **The stdin hang bites in background Bash and in foreground compound commands alike.** A
  foreground probe ran clean while the byte-identical background command hung 23 minutes at ~0 CPU
  (measured 2026-07-30), which read as "the harness appends `< /dev/null` to foreground evals"; on
  2026-09-04 a foreground `;`-chained command hung 300 s at the same call, so that carve-out is not
  reliable. Write `< /dev/null` explicitly on every `codex exec`, foreground or background. The
  stderr line "Reading additional input from stdin…" prints on completed runs too, so it is not the
  tell; no hook or output line after it is.
- `codex exec` writes its working transcript to **stderr** and only the final report to stdout, so
  0-byte stdout mid-run is normal. `-s read-only` structurally prevents stray files.
- **Hand vendors a read-only snapshot**: `git archive <sha> | tar -x -C $TMPDIR/…` plus a
  `git diff` patch. This pins the review SHA by construction and makes the diff immutable under
  review; it is also why `--skip-git-repo-check` is needed at all. Hold fix commits until every lens
  returns, or a lens re-reports fixed defects as live.
- **Run vendor calls sandbox-off** (xAI hosts are not network-allowlisted; the bridges write under
  `~/.claude/plugins/`, on the sandbox write-deny list). **Liveness is a growing rollout file, never a
  process check**: `ps`/`pgrep`/`kill -0` report a live process dead under the sandbox
  (`sandbox-and-permissions` skill).
- Vendor findings **skip the workflow's skeptic panels**. Adjudicate each against source in the
  main loop, spawning scoped verifiers for deep HIGHs. Both vendors have carried real errors
  (measured 2026-07-24), and one lens has caught a real defect the other rubber-stamped as verified
  (measured 2026-07-27).

**If a bridge ran anyway**, harvest unsandboxed: `grok-bridge.mjs runs` / `show <run-id>` (falling
back to the state-dir job log `…/state/<ws>/jobs/<run-id>.log`), `codex-companion.mjs status|result
<job-id>`. A Codex job's JSON can stay `status=running` forever after the work finished. The report
is in the session rollout (`~/.codex/sessions/<date>/rollout-*-<sessionId>.jsonl`), so tail that
rather than polling the status file. A Grok bridge foreground timeout (600s) orphans and then kills
the run with no output; the wrapper's "the underlying job continues" is false past a few minutes.
A run the *harness* backgrounded with a task id is healthy, and `TaskOutput(block=true)` returns
it. A data-dir name does not tell you which vendor ran: the log header names the actual runtime.
The `grok-build:grok-delegate` agent type appears only in sessions started after the plugin was
installed (§ Stale-registry and cache gotchas).

## `args` does not arrive the way you passed it

Three measured failures, all silent. Treat `args` as untrusted on the way in and re-passed by hand
on the way back.

- **A resume drops `args`.** `Workflow({scriptPath, resumeFromRunId})` does not carry the original
  invocation's `args`: the script gets `undefined`, and a named workflow errors. **Re-pass the
  original `args` verbatim on resume.** The identical string is also what keeps the journal cache
  keys matching (measured 2026-06-06).
- **An object `args` can arrive stringified**, so `args.X` is `undefined`. Agents were told to
  write to literal `undefined/...` paths and the run went for hours before the damage showed.
  Hardcode critical constants (dates, paths, output locations) as `const` literals in the script
  body; if dynamic data must flow in, template it into the script text and launch with `scriptPath`.
- **The same stringification silently disables a mode toggle.** `args: {smoke: true}` arriving as a
  string makes `!!(args && args.smoke)` false, so the script runs at full scale. Two defences, both:

  ```js
  const SMOKE = (typeof args === 'string')
    ? (args === 'smoke' || args.includes('smoke'))
    : !!(args && args.smoke)
  ```

  and launch the smoke run with a plain string, `Workflow({scriptPath, args: "smoke"})`. Then
  **verify from `journal.jsonl` that the toggle engaged** before scaling up (measured 2026-06-19:
  the journal showed 5 research agents, not 1).

## A usage-limit hit masquerades as a schema failure

If every subagent completes instantly with **"completed without calling StructuredOutput"** and the
sources come back empty, leave the schema alone: open a failed agent transcript and look for
**"You've hit your session limit"**. The same hit at a *verify* stage presents as 0-0 abstains, which
read as kills.

## WebSearch is a session-shared pool

The pool (default 200) is drained by every subagent and nothing warns at dispatch; the error fires
when the main loop needs a search and the cost is sunk (measured 2026-08-26). Reserve main-loop
searches for post-hoc verification, or raise `CLAUDE_CODE_MAX_WEB_SEARCHES_PER_SESSION` before a
research fan-out. A fresh session refills the pool, so hand deferred searches to the next session.

## Reading a completed run's return value

The `.output` file named in the `<task-notification>` (`/private/tmp/.../tasks/<taskid>.output`) is
a wrapper, not the bare return:

```json
{ "summary": "...", "agentCount": 111, "logs": [...], "result": { ...the workflow's return... } }
```

Parse it and read `wrapper.result` (`JSON.parse` it if it is a string). The notification's inline
`<result>` is the same object **truncated**, so for a big run read the file. The extraction helper
is a normal Node script; the runtime ban on `node:fs` / `Date.now()` applies to the Workflow script
body only.

## Resume and the transcript files

Same script plus the same args (re-passed by hand, above) is a 100% cache hit, which is also the
trap: a resumed run can report results no agent produced this session. A stopped run is reusable:
`TaskStop`, then relaunch with `resumeFromRunId`; a top-of-file `const` edit does not invalidate
downstream agent-call caches.

A running workflow uses the script as loaded at launch. Edits take effect only on `resumeFromRunId`,
and appending to a stage you will not re-run invalidates the cache for everything downstream. Codex:
the active task/subagent messaging surface reaches a live agent; the appendable-artifact habit is
host-independent.

A `SendMessage` to an agent that is finishing its turn is dropped: the tool reports "queued for
delivery at its next tool round" and no round comes. Verify the addendum landed in the diff; if not,
resend it as a resume of that agent (2026-09-12).

| File | Holds | Read it for |
|---|---|---|
| `journal.jsonl` | each call's **return value** | drop reconciliation; diagnosing a thin result |
| `agent-<id>.jsonl` | each agent's **spawn config** + raw turn stream | verifying `"model"` actually applied; fallback when no journal exists |

## Stale-registry and cache gotchas

- **After editing a `.claude/workflows/` script, launch via `scriptPath`, never by `name`.** By-name
  resolution can serve a session-start-cached copy, and the run "succeeds" under the wrong config.
  Verify a run's configuration by grepping its `agent-*.jsonl` transcripts for `"model"`; per-agent
  spawn evidence beats a canary line the script prints.
- **A NEW `.claude/agents/*.md` definition registers mid-session; an EDITED one is not known to
  reload.** Three new definitions (user- and project-scope) appeared as dispatchable agent types in
  the session that wrote them, the harness announcing each (2026-09-14). Whether a dispatch reads an
  edited body fresh is unmeasured, so for an edit made this session validate the def by executing
  its procedure directly, or defer literal dispatch to a fresh session. Narrows the 2026-07-02
  reading that nothing hot-loads.
- **Codex agent definitions and installed skill metadata are session inputs.** After changing
  `~/.codex/agents/*.toml`, `~/.agents/skills/`, or a skill's `agents/openai.yaml`, validate
  discovery in a newly started Codex task.

