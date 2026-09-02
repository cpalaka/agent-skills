# Multi-Agent Policy — Claude Code mechanics reference

The API-level detail behind the rules in `SKILL.md`. Read this when you are **writing or editing a
workflow script**, or **dispatching an external vendor lens**; the rules themselves live in
`SKILL.md` and are what govern. Nothing here relaxes anything there — this file only says *how* to
express it.

Codex equivalents are noted where they exist; where they don't, the rule still holds and the
mechanism is the host's own dispatch surface.

## Scarce-tier posture ladder — the arg surface

`SKILL.md` defines the ladder (`none | critic | insight | full`) and what each rung buys. The
mechanics:

- **`scarce: "none"|"critic"|"insight"|"full"`** — the opt-in arg in saved adversarial-review
  workflows. Reference implementation: the consuming project's own
  `.claude/workflows/adversarial-review.js`.
- **`fable: true` stays accepted as an alias for `critic`.** Live launch snippets and plan docs
  still use it, so removing it would break them silently.
- **An unrecognized posture falls back to `none` with a LOGGED warning**, never silently.
- **`stages: {<stage>: {model, effort}}` outranks the ladder.** This is how a deliberate one-off is
  expressed — including a scarce verify — and it is why the ladder itself needs no special cases.
  The projection warning a scarce verify obliges is in `SKILL.md` § Scarce-tier usage.
- **Model IDs are concrete and probe-resolved**, never short aliases — see the alias rule in
  `SKILL.md` § Tier roles. `tournament/reference/lint.mjs` ERRORs on a bare alias in any script.

## Sizing a fan-out — the `budget` global

`SKILL.md`'s budget-tier exception says "a SMALL agent count." When the user set a token target
(`+500k`-style), that has a mechanism rather than an eyeball:

- `budget.total` — the target, or `null` if none was set.
- `budget.spent()` — output tokens spent this turn across the main loop **and all workflows** (one
  shared pool, not per-workflow).
- `budget.remaining()` — `max(0, total - spent())`, or `Infinity` when no target is set.

The target is a **hard ceiling**: `agent()` throws once spent reaches it. Two shapes:

```js
const FLEET = budget.total ? Math.floor(budget.total / 100_000) : 5   // static scaling
while (budget.total && budget.remaining() > 50_000) { … }             // loop until nearly dry
```

**Guard on `budget.total` in any such loop.** With no target set `remaining()` is `Infinity`, and the
loop runs to the 1000-agent backstop. When no target is set the exception is still a judgment call
and still gets announced.

## Other spawn-time knobs

- **`agentType`** — `agent(prompt, {agentType: 'general-purpose' | 'code-reviewer' | …})` runs a
  stage as a *definition-backed* agent instead of the default workflow subagent, resolved from the
  same registry as the Agent tool. Composes with `schema`. The workflow-side equivalent of the
  `opus-implementer` dispatch, and subject to `SKILL.md`'s stale-registry rule for edited defs.
- **Per-agent `effort`** — overrides effort for a single call, independent of `model`. This is what
  makes "modest = high, full = xhigh" enforceable per *stage* rather than per run. Use `low` only
  for mechanical stages, never for a verify or critic slot.
- **`workflow(nameOrRef, args)`** — runs another workflow inline as a sub-step, sharing this run's
  concurrency cap, agent counter, abort signal, and token budget. Its agents count toward **your**
  projection and **your** size ceiling, so a nested call is a spending decision, not a refactor.
  Nesting is one level only.

## Vendor lenses: call the CLIs directly, not the plugin bridges

`SKILL.md` § Verification structure requires external vendor lenses on any reasonably-sized diff.
This is how to actually get findings out of them.

> **Version caveat, unresolved.** Everything in this section was measured against **grok-build
> 0.2.0 and the Codex companion plugin as they stood in July 2026**. Verbs, state-dir paths, and
> timeout behaviour are plugin-version-specific and have already shifted once *within* that month
> (see the `show` correction below). **Re-verify a verb before depending on it**, and treat a
> disagreement between this section and the live CLI as this section being stale.

**The plugin bridges are fire-and-forget and return nothing.** `grok-build:grok-delegate` and
`codex:codex-rescue` forward the prompt to a background runtime and are *forbidden from polling*, so
the Claude-side wrapper returns a schema-valid **placeholder** ("launched in background — no findings
yet"). Slot one as a Workflow finder lens and the run's sent-vs-returned reconciliation reads
**CLEAN while vendor coverage is zero** — the exact blind spot `SKILL.md`'s reconciliation rules
cannot cover, because a placeholder *is* a return. Both wrappers are launch-only and refuse
follow-up work: resuming one via SendMessage with "now poll the job" gets a scope refusal.

**Prefer the direct CLIs.** Both are installed, return real findings synchronously, and were
validated 2026-07-27/28 (~6–8 min, 10–12 KB on a 410-line spec):

```sh
grok  --cwd <dir> --always-approve -p "$(cat PROMPT.txt)"
codex exec --skip-git-repo-check -s read-only -C <dir> "$(cat PROMPT.txt)" < /dev/null
```

- **`codex exec` fails TWICE, both times silently, before it will run.** (1) It **hangs on stdin**
  even with the prompt passed as an argument — stderr sits on `Reading additional input from
  stdin...` forever; fix with `< /dev/null`. (2) It then **exits 0 producing ZERO bytes**, because
  it refuses to run outside a git repo — and that message is invisible until stdin is closed; fix
  with `--skip-git-repo-check`.
- **The exit code is worthless here — assert `wc -c` on the output file.** Both failures presented
  as "completed, exit 0". Trusting absence-of-error reads as "the vendor found nothing" and drops
  coverage to one lens, which is the failure the direct-CLI rule exists to prevent. Arm a bounded
  watcher that reports the byte count either way, not only on success.
- **The stdin hang bites only in BACKGROUND Bash, so a foreground probe does not validate a
  background invocation.** The harness appends `< /dev/null` to foreground evals automatically: a
  foreground probe ran clean while the byte-identical background command hung 23 minutes at ~0 CPU
  with no rollout file (2026-07-30). Write `< /dev/null` explicitly in every background vendor call.
- `codex exec` writes its whole working transcript to **stderr** and only the final report to
  stdout, so 0-byte stdout mid-run is normal. `-s read-only` structurally prevents stray files.
- **Hand vendors a read-only SNAPSHOT, not the live repo**: `git archive <sha> | tar -x -C
  $TMPDIR/…` plus a `git diff` patch file. This pins the review SHA by construction (satisfying the
  hold-fix-commits rule in `SKILL.md`) and makes it impossible for a vendor to mutate the diff under
  review. It is also *why* `--skip-git-repo-check` is needed at all — the snapshot is deliberately
  not a git repo.
- **Run vendor calls sandbox-off** (xAI hosts are not network-allowlisted, and the bridges write job
  logs under `~/.claude/plugins/`, which is on the sandbox write-deny list → `EPERM`). **Liveness is
  a growing rollout file, never a process check** — `ps`/`pgrep`/`kill -0` report a live process dead
  under the sandbox (`sandbox-and-permissions` skill).
- Vendor findings **skip the workflow's skeptic panels entirely** — adjudicate each against source in
  the main loop, spawning scoped xhigh verifiers for deep HIGHs. Both vendors have carried real
  errors (2026-07-24: one misread a task's pins, the other overstated a missing-bench HIGH). The
  payoff is still there: 2026-07-27 the Codex lens caught a 2.61× calibration error the Grok lens had
  explicitly rubber-stamped as verified.

**If you must use a bridge anyway**, these are its failure modes:

- **A Codex job's JSON can stay `status=running` forever after the work finished** — the process
  completed and wrote its final report into the session rollout
  (`~/.codex/sessions/<date>/rollout-*-<sessionId>.jsonl`), then the bridge died before flipping the
  job JSON. A status-file poll monitor **never fires** in this mode. Check the job's `pid`
  (unsandboxed) and tail the rollout; the deliverable is usually all there. Intermittent, not
  universal.
- **A Grok bridge foreground timeout orphans and then KILLS the run with no output.** The wrapper
  waits 600s, the bridge process dies, the orphaned CLI works a few more minutes and then dies
  mid-inference; the job JSON is stale (dead pids) and the promised "parent will be notified" never
  comes. The wrapper's claim that "the underlying job continues" is false past a few minutes.
  *Distinct and healthy:* when the **harness** backgrounds the run and reports a task id, that run
  can complete fine — `TaskOutput(block=true)` returns the full review.
- Harvest verbs, all unsandboxed: `grok-bridge.mjs runs` (status / phase / elapsed);
  `grok-bridge.mjs show <run-id>`; `codex-companion.mjs status|result <job-id>`. **`show` is the
  verb whose behaviour moved**: on 2026-07-18 it did not resolve a `run-*` delegate id, on
  2026-07-19 (grok-build 0.2.0) it did and returned the full report. Try `show`, fall back to the
  state-dir job log `…/state/<ws>/jobs/<run-id>.log`.
- **Do not let a data-dir name tell you which vendor ran.** grok-build ≥0.2.x has its own dir, but a
  codex run dispatched in the same session can be recorded there too (forked plumbing, job titled
  "Codex Task"). The log header names the actual runtime; the listing's resume cosmetics do not.
- The `grok-build:grok-delegate` agent type only appears in sessions started **after** the plugin was
  installed — same session-start registry cache as edited agent defs (below).

## Session-level: ultracode

When a session reminder says ultracode is on, the orchestration opt-in is *standing* — workflows
become the default for substantive tasks. It changes **the opt-in, not the tier rules**: workhorse
default, scarce still opt-in per launch, budget tier still barred from correctness-bearing work, and
both agent-count ceilings still bind. Read the reminder rather than assuming; the pins hold either
way.

## `args` does not arrive the way you passed it

Three measured failures, all silent, all in the same surface. Treat `args` as untrusted on the way
in and re-passed by hand on the way back.

- **A resume DROPS `args` entirely.** `Workflow({scriptPath, resumeFromRunId})` does **not** carry
  the original invocation's `args` — the script gets `args === undefined`, and a named workflow
  errors ("No research question provided"). **Always re-pass the original `args` verbatim on
  resume.** An identical string is also what keeps the journal cache keys matching, so getting this
  right is what makes the cache-hit claim below true at all. (measured 2026-06-06)
- **An object `args` can arrive STRINGIFIED**, so `args.X` is `undefined`. Measured 2026-06-06 on a
  deep-research run: `args: {today, notesDir, reportPath}` reached the script as a JSON string;
  agents were told to write to literal `undefined/...` paths, and the run went for hours before the
  damage was visible. Hardcode critical constants (dates, paths, output locations) as
  `const` literals in the script body; if dynamic data must flow in, template it into the script
  text and launch with `scriptPath`.
- **The same stringification silently disables a mode toggle.** `args: {smoke: true}` arriving as a
  string makes `!!(args && args.smoke)` evaluate **false**, so the script runs at FULL scale — all
  five research briefs, web on, high effort — instead of the cheap smoke path. This one costs real
  money. Two defences, use both:

  ```js
  const SMOKE = (typeof args === 'string')
    ? (args === 'smoke' || args.includes('smoke'))
    : !!(args && args.smoke)
  ```

  and launch the smoke run with a plain string — `Workflow({scriptPath, args: "smoke"})`. Then
  **verify from `journal.jsonl` that the toggle engaged** (exactly one research-schema result)
  before scaling up. Measured 2026-06-19 on a research run: the journal showed 5 research agents,
  not 1.

## A usage-limit hit masquerades as a schema failure

If every subagent in a run completes instantly with **"completed without calling
StructuredOutput"** and the sources come back empty or unreliable, do not debug the schema. Open a
failed agent transcript and look for **"You've hit your session limit"** — a mid-run usage-limit
hit presents as a schema/fetch failure at the orchestration layer. The same limit hit at a *verify*
stage presents differently again — rate-limited verifiers return 0-0 abstains, which read as kills.

## Reading a completed run's return value

A finished Workflow/Task `.output` file — path given in the `<task-notification>` as
`output-file`, under `/private/tmp/.../tasks/<taskid>.output` — is **not** the bare return object.
It is a wrapper:

```json
{ "summary": "...", "agentCount": 111, "logs": [...], "result": { ...the workflow's return... } }
```

Parse the file, then read `wrapper.result` (and `if (typeof result === 'string') JSON.parse(result)`
to be safe). The `<task-notification>`'s inline `<result>` is the same object but **truncated**
(~the first 50–380k chars) — for a big run always read the full `.output` file rather than trusting
the inline copy.

Extraction is a normal dev-tool Node script; `fs` is allowed. The runtime ban on `node:fs` /
`Date.now()` applies to the Workflow **script body** only, not to a helper you run separately.

## Resume and the transcript files

`Workflow({scriptPath, resumeFromRunId})` replays the longest unchanged prefix of `agent()` calls
from cache and re-runs from the first edited call onward. Same script + **the same args, which you
must re-pass yourself** (see above — a resume drops them) = 100% cache hit — which is also the
trap: a resumed run can report results no agent produced this session.

A stopped run is reusable: `TaskStop` it, then relaunch with `resumeFromRunId` and unchanged agent
prompts for an instant cache hit (a top-of-file `const` edit does not invalidate downstream
agent-call caches).

Two different files in the run's transcript dir, neither substituting for the other:

| File | Holds | Read it for |
|---|---|---|
| `journal.jsonl` | each call's **return value** | drop reconciliation; diagnosing a thin result |
| `agent-<id>.jsonl` | each agent's **spawn config** + raw turn stream | verifying `"model"` actually applied; fallback when no journal exists |
