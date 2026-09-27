## Review

Wherever the profile runs them: **Spec axis, bug hunter and any Standards axis, dispatched together
→ adjudication → fix round, re-verified by a check aimed at it → targeted review (the critic, where
on) → certifying gate, on the final tree → merge**, in both shapes where the Skill controls the
order. Under `subagents` the bug hunter, where on, goes out with the axes whatever its value, since
the serial first pass was the largest phase in half the measured runs. The gate runs once, last,
because a fix invalidates a gate round that ran before it: eight of 3d-anim-lab's readable runs paid
such a round, at 205–340 s each (cpalaka/agent-skills#112). After a material round, one targeted
review at `code-reviewer-medium` reads the fix diff, handed the accepted findings, with no Codex
re-run. The critic, where on, is that review, run whether or not a round ran (Critic seat). Its
material finding is a round under the caps; reopen the full review only where scope or assumptions
changed. Only a red certifying reading re-runs the gate: its fix is a round under the caps,
re-checked by an aimed check, then certified once more. Hand reviewers the measurements a spec
summarises, not just the spec. Re-check a refuted finding about safety or data loss. A finding
proves the defect, not the remedy. Fix rounds, the wording-only round and the 60-call ceiling are
§ Run profile's caps.

**Re-verify a fix, not the world.** A fix round re-verifies with a check aimed at it: the failing
cases, any cases the findings name, and a sample of what passed. A verification whose cost scales
with the whole suite or matrix runs once, on the final tree, before Close: the certifying gate. A
new defect a review finds mid-run is recommended as a split-off ticket unless its fix is small. **A
command block in an instruction file is code**: it ships, and a fix-round remedy adding or changing
one is adopted, only after a fixture run in which a known-bad input turns it red, since a
playthrough runs no embedded command against a known-bad and one that no-ops passes it.

**Bug hunter.** `codex`, the default above the light plan, is the Codex lens below, and **any NOT
RUN fires the Correctness charter** as its fallback, so the loop never lacks the bug hunter its
profile names and never runs two. `correctness`, that fallback or the owner's choice in place of
`codex` at the stop, is the Correctness charter, a Reviewer dispatch over the same diff: *for each
defect, what can go wrong, why the path is vulnerable, the likely impact, one clause of remedy;
material findings only; end with `FINDINGS: n`*, recorded `LENS correctness: FINDINGS: <n>`. One
clause of remedy, because a finding proves the defect, not the remedy; material only, because you
adjudicate each; `FINDINGS: n`, so the record reads a count, not an impression.

**Codex lens**, dispatched beside the axes once the implementer's diff is committed:

```
node "<installPath>/scripts/codex-companion.mjs" adversarial-review --json --base <fixed point> -- "$(cat <focus file>)" < /dev/null
```

`<installPath>` is read at run time, since a version bump moves it: the `user`-scope element, or the
sole one, of the `plugins["codex@openai-codex"]` list in `~/.claude/plugins/installed_plugins.json`.
Sandbox off: sandboxed, the companion failed before reaching Codex, on EPERM creating its state
directory under `$CLAUDE_PLUGIN_DATA` (2026-09-23); network egress, never reached, is unmeasured.
Focus: the ticket's acceptance criteria verbatim plus the execution spec's hard limits, then this
line verbatim, which closed the one planted defect every Codex variant missed
(cpalaka/agent-skills#90):
`Also check: does each guard have a test for its rejecting path as well as its accepting path?`
Stage the focus in a file inside the repository and remove it after. The script takes focus only as
positional text, with no focus-file flag, and acceptance criteria carry backticks and quotes that an
inline argument would execute or end on; content read through `$(cat …)` is not re-parsed, and `--`
ends the options, so a focus beginning with a flag name is still read as text. Inside the
repository, because sandboxed and unsandboxed shells resolve different temporary directories.
`--base` reviews only commits while Codex reads the live tree, so commit the implementer's diff
first, and **fix commits wait for the lens**. It has no timeout of its own: take the host's longest
foreground timeout or its background mode, capturing stdout, never the plugin's
`--background`/`result` route (its job record nests the payload differently); a timeout under a
shorter budget is yours to re-run.

Record `LENS codex: <verdict> — <n> findings — <bytes> bytes` under `Review` (`.result.verdict`, the
count of `.result.findings`, output bytes). A null `.result`, a `.parseError`, zero bytes, a
non-zero exit, or a failure before output (binary absent, not authenticated, registry unreadable —
no such key or element — quota, timeout at the longest budget) is `LENS codex: NOT RUN — <why>`. Its
recommendations are hypotheses; adjudicate every finding against source.

**Critic seat**, an add-on and the targeted review, in every shape wherever the `critic` dial is on
— after every review, lens and fix round, and before the certifying gate where the Skill controls
the order: a fresh Reviewer dispatch
given the diff since the fixed point, the ticket, the execution spec and every review's output,
charged: *completeness critic — what the
reviewers and the lens missed and where their method erred: absence claims refuted by evidence
outside a finder's scope, category errors, a survivor one arm shares and was not charged with;
counter-critic — which findings source refutes, and which remedies add generality the spec never
asked for.* Recorded `CRITIC: <n> findings`.
