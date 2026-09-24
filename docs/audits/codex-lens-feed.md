# Is the Codex lens fed well? Focus, mode and base against four planted defects

Research for cpalaka/agent-skills#90 (map #82), 2026-09-24. It answers the bug-hunter dial's
default in [ADR 0018](../adr/0018-run-profile-derived-from-plan.md) § 1: `codex`, `correctness`,
or both on runtime surface.

Tags: **[measured]** read off a run recorded here; **[doc-read]** read from source or config, not
exercised; **[unmeasured]** neither.

## Answer

The lens is not a weak reviewer and the Skill's feed is not a weak feed, on this fixture. With the
focus as the `implement-run` Skill stages it, `adversarial-review --base` named three of the four
plants in both rounds, including the one whose contract lives only in the focus. **[measured]**
None of the alternatives beat it: the execution spec plus native findings added nothing, the
companion's other mode cannot take a focus and emits no `.result`, and a working-tree base found
exactly what the commit base found. **[measured]** The one miss every variant shared, the missing
negative-path test, was closed by one charter line appended to the focus. **[measured]**

So #84's twelve-run tally (one unique material finding, none on a runtime diff) is not explained
by focus, mode or base. What it is explained by stays **[unmeasured]**: the runtime diffs may have
carried no defect of these kinds, the native axes may have found them first (#84 counted unique
findings only), or real diffs are larger than a 40-line fixture.

For the dial, one Correctness-charter arm ran on the discriminating round (b5). It named all four
plants, (d) included, unprompted, in 43 s against the lens's 72–88 s. **[measured]** On this
fixture the two hunters tie on (a)–(c), and the Correctness charter beats the lens as currently fed
on (d); the lens ties it once the focus carries one test-gap question (b3). **[measured]** Nothing
here shows either hunter finding a plant the other missed with the same feed, so nothing measured
supports running **both** by default. Which one to default to turns on things this fixture cannot
show: recall on large real diffs, and the value of a reviewer from a different model family.
**[unmeasured]**

## The fixture

Two rounds, each a committed diff of two new Python files, tests green (`python3 -m unittest`, 5
tests, OK) **[measured]**. The plant registry was written before any run:
[`codex-lens-feed/plants-registry.txt`](codex-lens-feed/plants-registry.txt).

| Plant | Round A — `fixtures/metrics-batcher/` (4b0b086) | Round B — `fixtures/metrics-uploader/` (c5a294a) |
|---|---|---|
| (a) wrong literal vs stated constant | `batcher.py:18` slices by 265; cap 256 stated at `:11` and in the docstring | `uploader.py:7` `BATCH_SIZE = 265`; the 256 cap is stated **in the focus only** |
| (b) guard passing by float rounding | `batcher.py:24-25`; `test_batcher.py:23` accepts `[0.3, 0.3, 0.3]`, exact reserve 0.1, float reserve 0.10000000000000009 | `uploader.py:19-20`; `test_uploader.py:23` |
| (c) unsupported evidence claim | `batcher.py:7-8` claims a tracemalloc-measured < 4 MB peak; `:17-18` materialise everything | `uploader.py:3-4`; `:13-14` |
| (d) missing negative-path test | `test_batcher.py:18-23`, accepting-path tests only | `test_uploader.py:18-23` |

Round A states every contract inside the diff, so it cannot tell a feed from no feed. Round B moves
the batch cap out of the diff and into the acceptance criteria, which is the real run's situation:
the implementer's diff seldom restates the ticket. Round B's commit is reviewed on branch
`research/codex-lens-b`; the same files are cherry-picked onto `research/codex-lens`.

## Runs

Command shape as the Skill gives it (`implement-run/SKILL.md` § Review, "Codex lens"), companion
1.0.6 resolved from `installed_plugins.json`, sandbox off, cwd the reviewed worktree, 600 000 ms
budget, stdout captured. No run timed out; every exit was 0; no `parseError`. **[measured]** Model
and effort are the Codex config defaults (`--model` was not passed) **[doc-read]**.

| Run | Variant | Verdict | Findings | (a) | (b) | (c) | (d) | Bytes | Wall |
|---|---|---|---|---|---|---|---|---|---|
| [v1](codex-lens-feed/v1-skill-feed.json) | A (i) Skill feed: ACs + hard limits, `--base main` | needs-attention | 3 | yes | yes | yes | remedy only | 8 701 | 77 s |
| [v2](codex-lens-feed/v2-spec-and-native.json) | A (ii) + execution spec + native findings | needs-attention | 3 | yes | yes | yes | remedy only | 9 852 | 65 s |
| [v3](codex-lens-feed/v3-native-review.json) | A (iii) native `review --base main`, no focus possible | no `.result` (P1 + 2×P2 in text) | 3 | yes | yes | yes | no | 2 265 | 62 s |
| [v4](codex-lens-feed/v4-working-tree.json) | A (iv) `--scope working-tree`, files untracked, Skill feed | needs-attention | 3 | yes | yes | yes | remedy only | 8 662 | 85 s |
| [v5](codex-lens-feed/v5-no-focus.json) | A control: adversarial, no focus | needs-attention | 3 | yes | yes | yes | remedy only | 8 850 | 66 s |
| [b0](codex-lens-feed/b0-no-focus.json) | B control: adversarial, no focus | needs-attention | 2 | **no** | yes | yes | no | 6 854 | 88 s |
| [b1](codex-lens-feed/b1-skill-feed.json) | B (i) Skill feed | needs-attention | 3 | yes | yes | yes | remedy only | 9 188 | 82 s |
| [b2](codex-lens-feed/b2-spec-and-native.json) | B (ii) + execution spec + native findings | needs-attention | 3 | yes | yes | yes | remedy only | 9 209 | 72 s |
| [b3](codex-lens-feed/b3-feed-plus-test-charter.json) | B Skill feed + one test-charter line | needs-attention | 4 | yes | yes | yes | **yes** | 10 444 | 83 s |
| [b4](codex-lens-feed/b4-native-review.json) | B native `review --base main` | no `.result` (2×P2 in text) | 2 | **no** | yes | yes | no | 1 867 | 63 s |
| [b5](codex-lens-feed/b5-correctness-charter.md) | B **Correctness charter** (`code-reviewer` seat), same ACs + hard limits | `FINDINGS: 6` | 6 | yes | yes | yes | yes | — | 43 s |

Focus files: [A (i)](codex-lens-feed/focus-a-i-skill-feed.txt),
[A (ii)](codex-lens-feed/focus-a-ii-spec-and-native.txt),
[B (i)](codex-lens-feed/focus-b1-skill-feed.txt),
[B (ii)](codex-lens-feed/focus-b2-spec-and-native.txt),
[B + charter](codex-lens-feed/focus-b3-feed-plus-test-charter.txt). The round-B files were
regenerated here by the same transforms used at staging.

"Remedy only" scores (d) as missed: the absence of a rejecting-path test is never a finding, and
appears only inside plant (b)'s recommendation ("replace the three-equal-shares acceptance test
with rejection and cover reserves below, at and above 10%"). A coordinator fixing (b) may add the
test; nothing in the record makes it. Bytes are before path redaction (below). **[measured]**

## What each variable did

- **Focus.** The only variable that moved plant (a): b0 and b4, with no focus, never said 265 is
  wrong, because nothing in the diff says the cap is 256; b1 named it at confidence 1. **[measured]**
  In round A, where the diff states the cap, focus made no difference (v1 = v5). **[measured]**
- **Execution spec and native findings in the focus.** No gain in either round, and no harm: a
  planted "Spec axis: PASS, AC1–4 met" did not stop v2 or b2 from naming three plants against it.
  **[measured]**
- **Mode.** The companion has two review modes: `adversarial-review` and `review`, which maps to
  Codex's built-in reviewer and **rejects focus text** outright (`validateNativeReviewRequest`)
  **[doc-read]**. Its JSON carries no `.result`, only `.codex.stdout`, so under the Skill's record
  rule ("a null `.result` … is NOT RUN") a native run is recorded NOT RUN and fires the fallback
  even when it found three defects. **[measured]** v3 matched v1 on round A; b4 matched the
  no-focus control on round B. Not a better mode.
- **Base.** `--base <ref>` reviews `merge-base..HEAD`; `--scope working-tree` reviews staged,
  unstaged and untracked files (untracked inlined whole) **[doc-read]**. v4 found what v1 found.
  **[measured]** The working-tree scope would let the lens run before the implementer's commit,
  but it also sweeps in any untracked file the run has lying about; nothing here argues for it.
- **Test gaps.** Every variant without the charter line missed (d); b3's single added question
  ("does each guard have a test for its rejecting path as well as its accepting path?") produced
  a finding at `test_uploader.py:18-23` that also argued it by mutation ("replacing
  `check_quota_split` with an unconditional reserve calculation still passes all five tests").
  **[measured]** The adversarial prompt's attack surface lists auth, data loss, races, degraded
  dependencies and the like, and its finding bar excludes "low-value cleanup"; test coverage is
  not on it **[doc-read]**, which is consistent with the miss but does not prove the cause.

## Confounds and limits

- **n = 1 per cell.** No variant was repeated; a single run's miss is one draw. The (a) miss in
  b0/b4 is structural (the information was absent), the (d) miss is 9 of 9 runs without the line.
- **The fixture is small and its plants are loud.** 40 lines, four defects, each reproducible by a
  two-line probe; Codex ran such probes in most runs (tracemalloc peaks, batch lengths). A real
  diff buries a defect in hundreds of lines. Recall on real runtime diffs is **[unmeasured]**.
- **The commit subject names the ticket.** b0 reported "Issue #90 could not be fetched" and b4
  "the referenced issue could not be retrieved": the no-focus runs tried to read the ticket, whose
  body describes the four plant kinds. Both fetches failed (read-only sandbox), so nothing leaked,
  but a probe on a networked host must keep ticket numbers out of the reviewed commit.
- **Paths say `fixtures/`**, which may read as test data. Every variant still treated the code as
  shipping.
- **b5 is a different instrument.** The Correctness arm is a Claude `code-reviewer` seat handed
  this session's instruction hierarchy (both instruction files, this repository's contract, the
  memory index), and its prompt was written by the prober, who knew the plants; the prompt added
  "give each finding a file:line" and nothing plant-specific. Its (d) sits inside finding 4 as
  "Also missing: no test covers the raising path", with a grep as evidence, and is scored named.
  Its raw output is prose, so it has no byte count comparable to the lens's JSON.
- **Raw outputs are redacted**: the worktree's absolute path is replaced by `<worktree>` /
  `<worktree-b>` for the public repository; nothing else is changed.
- Codex model and effort come from the owner's Codex config; a config change can move every
  number here **[doc-read]**.

## Implications for the Skill (not edited here)

1. Keep `adversarial-review --base` and the focus as staged; do not switch to `review` (loses the
   focus and the `.result` the record rule reads).
2. Adding the execution spec and native findings to the focus buys nothing measured here.
3. A one-line test-gap question in the focus closed the only shared miss. It is the cheapest feed
   change with a measured effect.
4. Bug-hunter dial (ADR 0018 § 1): the evidence here supports **one** hunter on runtime surface,
   not both. The Correctness charter matched or beat the lens as fed today, at about half the wall
   time. The lens matches it only with implication 3 applied. The choice between them rests on the
   **[unmeasured]** items under Confounds.
