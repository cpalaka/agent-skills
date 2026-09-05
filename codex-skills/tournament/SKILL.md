---
name: tournament
description: Tournament workflows on Codex: generate, judge, verify, synthesize from a persisted spec, fanned out on spawn_agent and reconciled per stage. Use to "run a tournament", "generate-and-judge" or "pick the best X via fan-out".
---

# Tournament — Codex adapter

This is a thin **Host adapter** for the canonical skill at
[`../../tournament/SKILL.md`](../../tournament/SKILL.md). Read that file completely. Its §1
(pipeline), §2 (spec + archive), §3 (elicitation), §4 (candidate schema) and §8 (budget) are
canonical and apply unchanged; `../../tournament/reference/example-spec.md` is the worked spec.

Its §5 and §7 assemble and launch a **Claude Code Workflow script**, and Codex has no Workflow
runtime, so the substitutions below replace those two sections' *mechanics*; of §6 the lint and the
scoreboard selftest are dropped (`reference/stages.md`, `reference/lint.mjs` and
`reference/selftest-scoreboard.mjs` concern that script — ignore them on this host), and **§6's
smoke run stands** at the parameters §6 names. §5's host-neutral rules
still bind on Codex: item 6 (model and effort pinned on every agent — here the configured model
and an explicit per-call `reasoning_effort` on every spawn), item 7 (vote-tallying stages
reconcile SENT vs RETURNED — here it is the instrument below), item 9 (skeptic/verify schemas carry ≥4 severity tiers; an "evidence-fit" axis
measures quote fidelity, not claim support; funders and 0-cost options get their own class), and
§1's bracket-or-scoreboard choice (this adapter's `board` is the scoreboard variant; a bracket run
reconciles each match's votes the same way per file, but no bracket runner ships here yet). Load
`$multi-agent-policy` before the first spawn; its pins and its fan-out → verify discipline govern.

## Substitutions

1. **Invocation.** `$tournament`, `$multi-agent-policy` — Codex `$name` syntax throughout.

2. **The run is a plan plus files, not a script.** After the spec is written (canonical §2),
   create a run directory beside it, `<archive>/<name>.run-<date>/`, holding `plan.json` and one
   subdirectory per fan-out stage (`generate/`, `judge/`, `verify/`, `synthesize/`). `plan.json`
   lists every stage with its `model`, `reasoning_effort` and `items` (the ids to dispatch), and
   is the artifact the run reads — persist it before dispatching anything. Before each stage,
   write its id list to `<rundir>/<stage>.sent`, one id per line; that file is the pre-derived
   expected input count, written **before** the fan-out so a short stage reads as a number
   mismatch.

3. **Dispatch surface: `collaboration.spawn_agent`**, then `wait_agent`. The dispatch unit is
   the child; the reconciliation unit is the file, whatever the grouping. Generate, verify and
   synthesize dispatch one child per item. The judge stage dispatches **one child per judge
   persona** that writes one vote file per candidate (run 1: 3 judge children, 9 vote files);
   one child per vote is allowed and reconciles identically. `<rundir>/candidates.txt` is the
   generate stage's **returned** ids, one per line, written after that stage's reconcile is GREEN
   (a dropped candidate must never reach the board unnoticed). Every call sets
   `fork_turns: "none"`, an explicit `model`, an explicit `reasoning_effort`, and a `task_name`
   of `<stage>_<id>` (lowercase, digits, underscores). The `message` is the whole
   brief — domain block, the item's lens or rubric, the candidate text for judges, and the exact
   output path `<rundir>/<stage>/<id>.json` with the JSON shape it must write — because a
   `fork_turns: "none"` child inherits nothing of the parent's context. Before each spawn, write
   that message verbatim to `<rundir>/dispatch/<task_name>.md`, so a re-dispatch is diffable
   against the original (rollouts store spawn payloads encrypted). The child replies with
   the path only. **The file is the verdict; the child's reply is not.** A judge item is one
   vote, `<judge>__<candidate>`; the file must carry `judge` and `candidate` equal to its name and
   a `score` that is a JSON number on the spec's scale (pass `--integer` when the spec says
   integer), or the instrument errors it (§4). Why
   `fork_turns: "none"` (measured 2026-09-04, codex-cli 0.153.3, two child rollouts under
   `~/.codex/sessions/2026/09/04/`): a `"none"` child (run-1 `01a06f2f-8def-7760-…`) carries
   exactly one `turn_context`, its own, so its pin is single-valued and unambiguous; a
   full-history fork (critic control `01a06f47-ae2f-7672-…`) carries the parent's copied turn
   (`turn_id == root_turn_id`, effort high) **and** its own turn (effort low) — the *effort*
   override applied on the full fork too (the control pinned only `reasoning_effort`; the model
   half is unmeasured), so the grounds are context isolation and a clean rollout, not
   inheritance. `wait_agent` returns on mailbox activity, not on every assignment being done —
   so: wait, then reconcile. §4's reconcile → re-dispatch once → reconcile **is** the completion
   check; there is no second loop.

4. **Reconcile every fan-out stage before reading it**, with the instrument this adapter ships
   (paths are the installed adapter's, e.g. `~/.agents/skills/tournament/scripts/tourney.mjs`):

   ```sh
   node scripts/tourney.mjs selftest                                   # once per session, first
   node scripts/tourney.mjs reconcile <rundir>/<stage> --sent <rundir>/<stage>.sent --expect <N>
   node scripts/tourney.mjs board <rundir>/judge --sent <rundir>/judge.sent --candidates <rundir>/candidates.txt --scale 0..10
   ```

   `reconcile` prints `sent / returned / dropped / errored / unassigned` (disjoint, summing to
   sent) and `VERDICT: RED` when any sent id has no parseable JSON object file; a duplicate id in
   a sent list is RED before anything is counted. On RED: re-dispatch the dropped and errored ids
   once (fresh `task_name`, same message), reconcile again, and if still RED carry
   `needsAdjudication` into the board and the result file — never tally over a short set.
   `board` validates every vote before tallying — `judge` and `candidate` fields equal to the
   filename's parts, `score` a JSON number within `--scale` (the spec's scale; default `0..10`;
   add `--integer` when the spec says integer) — and errors anything else with the reason; it refuses a winner while any vote is missing or
   errored, the top is tied, a candidate has no assigned vote, the sent list is empty, or an
   **unassigned** file sits in the judge directory. Unassigned files are a child writing outside
   the accounting: before the board, disposition each one in the result file (a duplicate of an
   assigned vote — keep the assigned copy and note the twin; a vote nobody asked for — move it to
   `<rundir>/unassigned/` and say why) and only then re-run `board`. The `selftest` builds the
   known-bad fixtures (invalid scores, swapped identity, duplicate ids, empty electorate,
   unassigned file, full-fork rollout) and must print `VERDICT: GREEN (selftest)` before any GREEN
   from the other two is believed.

5. **Pins are verified from rollouts, not from the parent's account.** After the run:

   ```sh
   node scripts/tourney.mjs rollouts <parent thread id>
   ```

   lists every child of that session with its model, effort, role and sandbox, read from typed
   records in the child's own rollout under `~/.codex/sessions/`: the last `turn_context` whose
   `turn_id != root_turn_id` (the child's own turn — a copied parent turn has them equal), else
   the `thread_settings_applied` event, else `?` with a WARN. The parent thread id is the
   `thread.started` line of `codex exec --json`, or the interactive session id. The result file
   records each stage's pin **as dispatched and as observed**; a child whose own-turn effort or
   model differs from `plan.json`, or reads `?`, makes the run not green — say which children and
   why. The model id is read from `~/.codex/config.toml` (`model =`) at authoring time and
   written into `plan.json`, never into this file. **Tier is unmapped on Codex:**
   `multi-agent-policy`'s workhorse/scarce vocabulary is decided by rate-limit membership, which
   nothing here measures; every stage of a Codex run is on the one configured model, and whether
   that is the workhorse or the scarce tier is not decided by this adapter. The result file and
   the `rollouts` output hold session ids and local paths — keep the archive out of public
   repositories.

6. **Size the sandbox before launch; never escalate from inside the run.** Children inherit the
   parent's sandbox. Verdict files land under the run directory, so the parent session must be
   able to write there: interactively, start it with `-s workspace-write -C <archive>`; via
   `codex exec`, `-s workspace-write -C <rundir>`. If the archive is outside every writable root,
   the run is **report-only**: write the spec and `plan.json` to the reply, say why nothing was
   dispatched, and stop. Do not request escalation.

7. **Agent count.** Project it before launch and write it into `plan.json`, in **children**
   (the dispatch unit), derived from the actual dispatch groups: generate = number of lens
   items; judge = number of judge children under the grouping chosen in §3 (one per persona, or
   one per vote = judges × candidates); verify = number of skeptics; synthesize = 1; plus the
   recovery allowance = one child per fan-out stage (one recovery wave re-dispatching that
   stage's dropped/errored ids to one child each counts per id — state which). Run 1: 3 + 3 + 2 +
   1 = 9 base, +4 allowance = 13 projected, 10 spawned. Two ceilings, and the smaller binds:
   `multi-agent-policy`'s 20-child announce ceiling (Claude Code's dynamic workflow-size setting
   does not govern a Codex run), and Codex's own concurrency ceiling — config keys
   `agents.max_concurrent_threads_per_session` / `features.multi_agent_v2.max_concurrent_threads_per_session`,
   thread status `agent_limit_reached`. No CLI command prints the effective default, but the
   binary's own hint — "Consider setting `features.multi_agent_v2.max_concurrent_threads_per_session`
   below 8" — is printable evidence it is ≥ 8 (`~/.codex/config.toml` sets neither key). A stage
   that hits `agent_limit_reached` waves: wait for a running child, then dispatch the next, and
   reconcile at the end as §4 says.
   Under non-interactive `codex exec` there is nobody to announce to: a projection over the
   announce ceiling stops **report-only** (write `plan.json` and the projection to the reply,
   dispatch nothing). Spawns dispatch a few seconds apart and run concurrently.

8. **Smoke run and elicitation.** Canonical §6's smoke run, at the parameters it names, still
   gates a new or edited spec. Canonical §3's interview is the same, but a
   `codex exec` run that asks a question ends on it (measured 2026-09-04, ticket 07) — under
   `codex exec` the brief must carry every non-default, or run interactively.

9. **Result and recovery.** Write `<archive>/<name>.result-<date>.md` per canonical §7, with the
   scoreboard, every `RECONCILE` line, the pins as dispatched and observed, and the
   `needsAdjudication` items. There is no `resumeFromRunId`; the run directory is the checkpoint —
   re-running from `plan.json` reconciles what exists and dispatches only what is missing.
