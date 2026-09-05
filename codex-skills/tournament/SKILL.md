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
runtime, so the substitutions below replace those two sections; of §6 only the lint is dropped
(`reference/stages.md` and `reference/lint.mjs` concern that script — ignore them on this host),
and **§6's smoke run stands** at the parameters §6 names. Load `$multi-agent-policy` before the
first spawn; its pins and its fan-out → verify discipline govern.

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

3. **Dispatch surface: `collaboration.spawn_agent`**, one child per item, then `wait_agent`.
   Every call sets `fork_turns: "none"`, an explicit `model`, an explicit `reasoning_effort`, and
   a `task_name` of `<stage>_<id>` (lowercase, digits, underscores). The `message` is the whole
   brief — domain block, the item's lens or rubric, the candidate text for judges, and the exact
   output path `<rundir>/<stage>/<id>.json` with the JSON shape it must write — because a
   `fork_turns: "none"` child inherits nothing of the parent's context. Before each spawn, write
   that message verbatim to `<rundir>/dispatch/<task_name>.md`, so a re-dispatch is diffable
   against the original (rollouts store spawn payloads encrypted). The child replies with
   the path only. **The file is the verdict; the child's reply is not.** A judge item is one
   vote, `<judge>__<candidate>`, so a judge child writes one file per candidate it scores and
   the judge stage reconciles at the vote level. Measured 2026-09-04 (codex-cli 0.153.3): the
   `model` and `reasoning_effort` overrides apply only with `fork_turns: "none"` (or an integer);
   a full-history fork inherits the parent's model and effort **silently**.

4. **Reconcile every fan-out stage before reading it**, with the instrument this adapter ships
   (paths are the installed adapter's, e.g. `~/.agents/skills/tournament/scripts/tourney.mjs`):

   ```sh
   node scripts/tourney.mjs selftest                                   # once per session, first
   node scripts/tourney.mjs reconcile <rundir>/<stage> --sent <rundir>/<stage>.sent --expect <N>
   node scripts/tourney.mjs board <rundir>/judge --sent <rundir>/judge.sent --candidates <rundir>/candidates.txt
   ```

   `reconcile` prints `sent / returned / dropped / errored / unassigned` and `VERDICT: RED` when
   any sent id has no parseable JSON object file. On RED: re-dispatch the dropped and errored ids
   once (fresh `task_name`, same message), reconcile again, and if still RED carry
   `needsAdjudication` into the board and the result file — never tally over a short set.
   `board` refuses to name a winner while any vote is missing or the top is tied. The `selftest`
   builds known-bad fixtures and must print `VERDICT: GREEN (selftest)` before any GREEN from the
   other two is believed.

5. **Pins are verified from rollouts, not from the parent's account.** After the run:

   ```sh
   node scripts/tourney.mjs rollouts <parent thread id>
   ```

   lists every child of that session with its model, effort, role and sandbox, read from the
   child's own rollout under `~/.codex/sessions/`. The parent thread id is the `thread.started`
   line of `codex exec --json`, or the interactive session id. The result file records each
   stage's pin **as dispatched and as observed**; a stage whose observed effort differs from the
   plan is reported as "inherits, silently" and the run is not green. The workhorse model id is
   read from `~/.codex/config.toml` (`model =`) at authoring time and written into `plan.json`;
   never into this file.

6. **Size the sandbox before launch; never escalate from inside the run.** Children inherit the
   parent's sandbox. Verdict files land under the run directory, so the parent session must be
   able to write there: interactively, start it with `-s workspace-write -C <archive>`; via
   `codex exec`, `-s workspace-write -C <rundir>`. If the archive is outside every writable root,
   the run is **report-only**: write the spec and `plan.json` to the reply, say why nothing was
   dispatched, and stop. Do not request escalation.

7. **Agent count.** Project it before launch and write it into `plan.json`:
   generators + judges + skeptics + 1 synthesis, plus one re-dispatch per stage for recovery.
   Claude Code's dynamic workflow-size setting does not govern a Codex run; `multi-agent-policy`'s
   20-agent announce ceiling does. Spawns dispatch a few seconds apart and run concurrently.

8. **Smoke run and elicitation.** Canonical §6's smoke run, at the parameters it names, still
   gates a new or edited spec. Canonical §3's interview is the same, but a
   `codex exec` run that asks a question ends on it (measured 2026-09-04, ticket 07) — under
   `codex exec` the brief must carry every non-default, or run interactively.

9. **Result and recovery.** Write `<archive>/<name>.result-<date>.md` per canonical §7, with the
   scoreboard, every `RECONCILE` line, the pins as dispatched and observed, and the
   `needsAdjudication` items. There is no `resumeFromRunId`; the run directory is the checkpoint —
   re-running from `plan.json` reconciles what exists and dispatches only what is missing.
