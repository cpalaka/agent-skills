## Review

Wherever the profile runs them: **Spec axis, bug hunter and any Standards axis, dispatched together
→ adjudication → fix round, re-verified by a check aimed at it → targeted review (the critic, where
on) → certifying gate, on the final tree → merge**, in both shapes where the Skill controls the
order. Under `subagents` the bug hunter, where on, goes out with the axes whatever its value. The
gate runs once, last, because a fix invalidates a gate round that ran before it. After a material
round, one targeted review at `code-reviewer-medium` reads the fix diff, handed the accepted findings, with no Codex
re-run. The critic, where on, is that review, run whether or not a round ran (Critic seat). Its
material finding is a round under the caps; reopen the full review only where scope or assumptions
changed. Only a red certifying reading re-runs the gate: its fix is a round under the caps,
then certified once more. Hand reviewers the measurements a spec
summarises, not just the spec. Re-check a refuted finding about safety or data loss. A finding
proves the defect, not the remedy. Fix rounds, the wording-only round and `scope`'s call cap are
§ Run profile's caps.

**Re-verify a fix, not the world.** A fix round re-verifies with a check aimed at it: the failing
cases, any cases the findings name, and a sample of what passed. A verification whose cost scales
with the whole suite or matrix runs once, on the final tree, before Close: the certifying gate. A
new defect a review finds mid-run is recommended as a split-off ticket unless its fix is small. **A
command block in an instruction file is code**: it ships, and a fix-round remedy adding or changing
one is adopted, only after a fixture run in which a known-bad input turns it red, since a
playthrough runs no embedded command against a known-bad and one that no-ops passes it.

In every shape the gate-runner's dispatch (§ Workflow shape, `gateTier`) names the checkout and the
profile's `gate tier` spelled out as only the gates to run: each of `verify-gate`'s five it takes by
its knob key, `build` carrying `build_check`, which is never listed as its own gate; any other gate
(a project gate, a trigger-table pull, a key of the `<!-- knobs:verify-gate -->` block beyond the
eight the engine stamps — the five, `build_check`, `dir`, `env`) by name with its command as given
(the contract's trigger table or knob value, or the seat's `## Project gates`), reading that block's
keys and values alike on disk, as `SKILL.md`'s Knobs says. It lists none left out: the seat derives
none and marks those itself.

**Bug hunter.** `codex` is the Codex lens below, and **any NOT
RUN fires the Correctness charter** as its fallback, so the loop never lacks the bug hunter its
profile names and never runs two. `correctness`, that fallback or the owner's choice in place of
`codex` at the stop, is the Correctness charter, a Reviewer dispatch over the same diff: *for each
defect, what can go wrong, why the path is vulnerable, the likely impact, one clause of remedy;
material findings only; end with `FINDINGS: n`*, recorded `LENS correctness: FINDINGS: <n>`. One
clause of remedy, for the first paragraph's reason; material only, because you
adjudicate each; `FINDINGS: n`, so the record reads a count, not an impression.

**Codex lens**, dispatched beside the axes once the implementer's diff is committed:

```
CLAUDE_PLUGIN_DATA=<dataDir> node "<installPath>/scripts/codex-companion.mjs" adversarial-review --json --base <fixed point> -- "$(cat <focus file>)" < /dev/null
printf '{"cwd":"%s"}' "<checkout>" | env -u CODEX_COMPANION_SESSION_ID CLAUDE_PLUGIN_DATA=<dataDir> node "<installPath>/scripts/session-lifecycle-hook.mjs" SessionEnd
```

`<installPath>` is read at run time, since a version bump moves it: the `user`-scope element, or the
sole one, of the `plugins["codex@openai-codex"]` list in `~/.claude/plugins/installed_plugins.json`.
`<dataDir>` is replaced by
`"$HOME/.claude/plugins/data/$(printf %s 'codex@openai-codex' | tr -c 'A-Za-z0-9_-' '-')"` as
written, quotes included, so it is derived at run time rather than copied from one machine;
`<checkout>` is the review's checkout, whose git toplevel keys the companion's state. The review
leaves a detached broker recorded in that state. Unpinned, the record lands wherever
`CLAUDE_PLUGIN_DATA` points, or under `os.tmpdir()`, which differs sandboxed and unsandboxed, and a
broker recorded anywhere but Codex's own data directory is stopped by nothing. The second line stops
it: run it as its own call once the first returns, fails or is killed, since a timeout that kills a
shared call kills it too, and record the first line's exit, not the second's. It shuts the
checkout's broker down whatever else is using it, so no other companion call runs in that checkout
meanwhile; `env -u` keeps it from ending the session's companion jobs. Both run sandbox off:
sandboxed, the companion would fail before reaching Codex, on EPERM creating its state directory
under `<dataDir>`, outside the sandbox's write set.
Focus: the ticket's acceptance criteria verbatim plus the execution spec's hard limits, then this
line verbatim:
`Also check: does each guard have a test for its rejecting path as well as its accepting path?`
Stage the focus in a file, since the script takes focus only as positional text and acceptance
criteria carry backticks and quotes an inline argument would execute or end on — `$(cat …)` output
is not re-parsed, and `--` keeps a focus beginning with a flag name as text. Keep the file inside
the repository, since sandboxed and unsandboxed shells resolve different temporary directories, and
remove it after.
`--base` reviews only commits while Codex reads the live tree, so commit the implementer's diff
first, and **fix commits wait for the lens**. It has no timeout of its own: take the host's longest
foreground timeout or its background mode, capturing stdout, never the plugin's
`--background`/`result` route; a timeout under a
shorter budget is yours to re-run.

Record `LENS codex: <verdict> — <n> findings — <bytes> bytes` under `Review` (`.result.verdict`, the
count of `.result.findings`, output bytes). A null `.result`, a `.parseError`, zero bytes, a
non-zero exit, or a failure before output (binary absent, not authenticated, registry unreadable —
no such key or element — quota, timeout at the longest budget) is `LENS codex: NOT RUN — <why>`.
Adjudicate every finding against source.

**Critic seat**, the `critic` dial and the targeted review, in every shape wherever the dial is on
— after every review, lens and fix round, and before the certifying gate where the Skill controls
the order: a fresh Reviewer dispatch
given the diff since the fixed point, the ticket, the execution spec and every review's output,
charged: *completeness critic — what the
reviewers and the lens missed and where their method erred: absence claims refuted by evidence
outside a finder's scope, category errors, a survivor one arm shares and was not charged with;
counter-critic — which findings source refutes, and which remedies add generality the spec never
asked for.* Recorded `CRITIC: <n> findings`.
