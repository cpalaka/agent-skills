# verification-discipline — rule census

Every rule in `verification-discipline/SKILL.md` **as of `bfa3915`** (the compaction to 3,888
words), sorted into four categories so the owner can decide, rule by rule, what to keep, move or
drop. Line numbers are that commit's. The file will move; re-derive anything below against the live
file before acting on it.

## Why this census exists

The Skill is read rarely and written often. Measured over the host's session transcripts from
2026-08-20 to 2026-09-22 (about 1,100 main sessions and 924 sub-agent transcripts; Codex not
counted): the Skill tool loaded it **22 times**, about 2% of sessions. Roughly 17 of those loads
came inside orchestration runs, right after an implementation or multi-agent-policy load, and almost
all were in the Skill-authoring repositories; two were in a game project. The last load was
2026-09-20, before the file reached 10,186 words, so no agent has read it at that size.

Over the same window it grew 2,424 → 4,641 → 9,905 → 10,186 words (09-05, 09-18, 09-20, 09-22),
almost entirely by end-of-session promotions appending one incident-derived rule at a time. Counting
loads measures reach, not effect: whether a load changed behaviour (did the agent then plant a
control?) is **unmeasured**.

The content is four different kinds of material, and only one of them works as a Skill read on a
trigger. The rest bind at a moment this Skill is not loaded — when a criterion is written, when a
review is adjudicated, when a check reads clean.

## Counting rule

One row per bold-led paragraph or bullet, per oracle-table row, per section-opening rule, plus the
ugrep paragraph. The opening paragraph counts as three rules. † marks a narrow rule — generalized
from a single incident. **Total: 88.**

| Category | Count | Where it would bind |
|---|---|---|
| 1. Core — building and trusting checks, absence claims | 53 | this Skill |
| 2. Tool traps | 16 | a symptom-keyed lookup ("a check read clean or empty") |
| 3. Acceptance criteria, specs, tickets | 9 | `to-tickets`, `to-spec` |
| 4. Review seats, consults, peers | 10 | `code-review`, `implement-run` |

## 1. Core — 53

**The principle**

| # | Line | Rule |
|---|---|---|
| 1 | 8 | A check that can't go red proves nothing; the cure is a control (known-bad, known-present needle) |
| 2 | 14 | A before/after comparison changes the subject, never the instrument |
| 3 | 19 | Reproduce the known-bad exactly before believing the post-fix number; feed the instrument its own reference |

**Controls that can't go red**

| # | Line | Rule |
|---|---|---|
| 4 | 29 | For every predicate, name the mutation that reds it and run it |
| 5 | 32 | Composite verdict: each arm needs a control that fires on it alone |
| 6 | 35 | Absorbed fault: clamps and defaults eat the fault; confirm it changed behaviour |
| 7 | 38 | Moving oracle: an expected value read from the source moves with the mutation |
| 8 | 41 | Generated fixture: a fixture built from the data validates the matcher only; needs an external oracle |
| 9 | 49 | Wrong form: an instrument that can't express the question returns a clean zero |
| 10 | 54 | By construction: a verdict derived from its own input is a paste guard |
| 11 | 62 | A predicate over tool output keys on identity, not phrasing; count the output shapes |
| 12 | 67 | Calibrate the instrument *and* falsify the claim; sha256 for untracked files |
| 13 | 74 | Something must consume the result; gate actions on exit status |

**Gates and numbers**

| # | Line | Rule |
|---|---|---|
| 14 | 81 | A guard fires on a cause, not a correlate; a fail-closed false alarm is not safe |
| 15 | 86 | A permanently non-zero verdict: remove the findings or accept them visibly, per check |
| 16 | 98 | Derive tolerances from the measured noise floor |
| 17 | 101 | † A derived ceiling has a side; state the worst case beside the constant |
| 18 | 106 | Sweep identity claims; 100% failure is as suspect as 0% |
| 19 | 109 | A path is not an identity, a count not a set; "N what?"; compute derived fields |
| 20 | 114 | A count keyed by position (file:line) overcounts; count the live tree |
| 21 | 119 | A probe token present only if the layer ran; probe self-contamination; a shipped doc can't quote its sentinel |
| 22 | 126 | A null reading needs the subject inside the measurement window; the failure's form discriminates |
| 23 | 130 | A probe answers only the question it exercised |
| 24 | 134 | A call site shows that a call happens; read the callee to its returns |
| 25 | 137 | † Trust-boundary properties are measured as the least-privileged caller |
| 26 | 144 | Saved harnesses and in-context gate commands go stale; re-read from disk |

**Read the artifact, not the oracle**

| # | Line | Rule |
|---|---|---|
| 27 | 157 | Status fields and summaries outlive the failure; read the artifact |
| 28 | 170 | A figure from a summary of your own work is a claim; re-derive it |
| 29 | 172 | A generator is an oracle; open the consumed form and prior review dispositions |
| 30 | 180 | † A race fix needs three arms: log order, a non-zero wait, an independent witness |
| 31 | 184 | Read the diff back, not the exit code; write per edit |
| 32 | 188 | A cross-reference that resolves is a claim about scope; read the sentence it lands on |

**Assert the complement**

| # | Line | Rule |
|---|---|---|
| 33 | 208 | For "X must never happen", also assert what must still work |
| 34 | 212 | A value nothing reads passes both; assert at the consumer |
| 35 | 214 | A probe sampling before the system settles measures timing |
| 36 | 216 | Check per sub-class, the host included |
| 37 | 218 | Partition by reachable state as well as input |
| 38 | 236 | A fact corrected at its source leaves copies stale; grep every phrasing |

**Absence claims**

| # | Line | Rule |
|---|---|---|
| 39 | 241 | An absence claim carries the instrument's scope; write it in |
| 40 | 244 | Name the reach; prefer the authoritative query (`ls-remote`) |
| 41 | 247 | Put the intent layer (tracker) in scope first |
| 42 | 249 | Filesystem layer: `.gitignore`, `check-ignore`; not tracked is not not present |
| 43 | 251 | Settle runtime state with a live probe (the `@import` / `claude -p` detail is harness-specific) |
| 44 | 264 | A "fixed" note is a claim at the site it names; check sibling sites |
| 45 | 266 | In a test, drive the assertion through every writer |
| 46 | 267 | A dead reader keeps nothing alive; test liveness from the live set |
| 47 | 269 | A bulk deletion lasts only once its premise is retired in writing |
| 48 | 272 | "Nothing lost" needs three instruments: presence, force, evidence |
| 49 | 279 | A source's claim about its own evidentiary status is a claim; grep the rarest token |
| 50 | 282 | A per-item verdict carries its denominator; zero items is not run |
| 51 | 289 | Prove the needle first: a known-present needle through the same pipeline |
| 52 | 309 | A control licenses only the stage it ran at; branch on the harness exit status |
| 53 | 318 | Right by accident is worse than wrong; put the control on the last close-out check |

## 2. Tool traps — 16

| # | Line | Rule |
|---|---|---|
| 54 | 148 | Installed artifact ≠ repo file; symlinked store; test a ref by `git archive` extraction |
| 55 | 153 | † A Skill's trigger reliability: count Skill calls in transcripts |
| 56 | 164 | `systemctl show -p Result` says success when the unit never ran |
| 57 | 165 | `tailscale ping` pongs while all IP traffic is blocked |
| 58 | 166 | `git rev-parse HEAD` in a paused rebase shows the upstream commit |
| 59 | 167 | Harness "user rejected" after the write already landed |
| 60 | 168 | `ffmpeg` / `ffprobe` exit 0 at full duration with zero frames decoded |
| 61 | 174 | A path-mediated check reads a payload byte (HTTP 200, Subsonic, `nofail` mounts) |
| 62 | 177 | A capability manifest isn't a run record (the `h264_nvenc` banner) |
| 63 | 291 | Compression defeats text readers; `-a` doesn't help |
| 64 | 292 | `cmd \| grep X \|\| echo "no X"` reports clean when `cmd` fails |
| 65 | 294 | A path starting with `-` is parsed as an option; the count comes back empty |
| 66 | 296 | `grep -c`'s three traps: multi-line patterns, wrapped phrases, exit 1 on zero |
| 67 | 301 | Recursive search skips symlinked directories (BSD `-RS`, `rg -L`, `awk` doesn't recurse) |
| 68 | 306 | A regex list's own text isn't a needle for it |
| 69 | 313 | The Claude Code `grep` wrapper (ugrep): NUL bytes, ignored paths, tag-split HTML |

## 3. Acceptance criteria, specs, tickets — 9

| # | Line | Rule |
|---|---|---|
| 70 | 12 | A criterion that can't go green reads as a finding; ask what a pass looks like |
| 71 | 24 | A "before" a sibling ticket already moved is that ticket's *after*; rebuild the instrument from git |
| 72 | 45 | Wrong axis: the assertion and fixture must vary along the axis the criterion names |
| 73 | 58 | A sibling fix can put a criterion out of reach; run each criterion's mutation |
| 74 | 92 | A criterion quotes the predicate, never a printed count |
| 75 | 141 | † When a spec names the metric, measure what it can't see (`scrollWidth`) |
| 76 | 193 | A criterion predicting behaviour is checked against the measurement |
| 77 | 201 | Counts and globs written into instructions or dispatches are untested; run the command first |
| 78 | 323 | Blindspot the source before a 1:1 fan-out (spec → tasks) |

## 4. Review seats, consults, peers — 10

| # | Line | Rule |
|---|---|---|
| 79 | 190 | Checking a consult's evidence is not checking its recommendation |
| 80 | 196 | Prose for agents is verified by a fresh agent following it (playthrough) |
| 81 | 223 | Two passes through the same instrument are one reading; ask what they both read |
| 82 | 226 | Seats that can't execute converge on the same runtime inference; spend the run first |
| 83 | 228 | Seats converge on an unstated convention; write the convention down |
| 84 | 230 | A classification you defined is an instrument; have a seat quote back the key term |
| 85 | 232 | A verifying seat checks inside the claim's stated scope; vary the question |
| 86 | 234 | Two findings can be right and jointly destructive; note each fix's dependencies |
| 87 | 256 | What a sub-agent received is the harness's answer (the transcript attachment line) |
| 88 | 261 | A peer's claim about a per-machine artifact carries that machine as scope |

## Judgement calls in the sort

- **#38** sits under "Count agreeing readings once" in the file but is about stale copies — core.
- **#9, #10, #31, #50** use tool examples, but the rule is general — core.
- **#43** is a core rule carrying harness-specific detail; it could split into core plus a tool trap.
- **#70–73** are check-writing rules phrased around acceptance criteria; they could stay core.

## Not in the census

Two candidates are routed at this Skill from outside it and are not rules in the file yet: the two
`chunks/verify-gate.md` rules #52 asks to absorb, and #52's comment proposing "when a premise falls,
re-cost every number derived from it". Each needs an explicit keep-or-decline in the same pass.
