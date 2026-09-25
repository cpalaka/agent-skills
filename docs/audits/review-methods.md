# What four outside review methods offer the implement run's review stage

Research for #103 (map #102), 2026-09-24. It catalogues the checks in `/code-review`,
ponytail-review, Claude Code's `/simplify` and Google's "What to look for in a code review", and
for each one names the current check that already covers it, or what it adds. The grilling tickets
make the decisions: #105 (the Spec brief), #106 (the Standards brief and the smell list) and #107
(which check owns over-engineering). This note gives each row only one of three dispositions:
**worth taking**, **already covered** or **not applicable**.

Tags: **[measured]** means read off a command run for this note, with its instrument named.
**[doc-read]** means read from a source file or page, not exercised. **[unmeasured]** means
neither. The catalogue is **doc-read throughout**, so a cell carries a tag only where it differs.
Every example finding is **[unmeasured]**: it illustrates the check and was not seen on a run,
unless it is marked otherwise.

Security checks are left out, because the owner reviews security at deploy time (map #102, Out of
scope).

## Answer

- **The largest uncovered class is cleanup.** No current check reviews a diff for dead weight,
  duplication, reuse, speculative generality, altitude, naming or stale surrounding text.
  - The Codex lens's own prompt rules it out: "Do not include style feedback, naming feedback,
    low-value cleanup" (Codex companion 1.0.6, `prompts/adversarial-review.md:40`).
  - The Correctness charter hunts defects: "what can go wrong, why the path is vulnerable"
    (`implement-run/SKILL.md:250`).
  - The critic's clause on generality is aimed at the reviewers' remedies, not at the diff:
    "which remedies add generality the spec never asked for" (`SKILL.md:294`).
  - A grep of the three current-check files for `dead`, `stdlib`, `tooling`, `scope creep`,
    `not asked` and `consisten` found 0 hits for each. A known-present needle (`rejecting path`)
    hit once in the same scope, so the instrument was live. **[measured]**
- **The Spec axis reads in one direction only.** It asks "does the diff meet the ticket's
  acceptance criteria and the execution spec?" (`implement-run/workflow.js:160`). It never asks the
  reverse, `/code-review`'s (b): behaviour in the diff that nothing asked for.
- **Test validity is checked on the spec but never on the diff.** Advisor slot 1 hunts "an
  observable that cannot go red" in the spec (`SKILL.md:200`). No reviewer asks Google's "Will
  the tests actually fail when the code is broken?" of the tests or checks a diff adds.
- **Already covered:** whole-file reading, spec-line citation, the hard/judgment split, explicit
  null verdicts, read-only reviewers, per-axis reporting, and "implemented but wrong" above the
  light plan.
- **Where the current text is missing, not just thin.** `implement-run/SKILL.md` names the Spec
  and Standards axes (`:62`, `:239`) but gives neither a brief. **[measured: grep]** The only
  written briefs are `workflow.js:159–160`, one line each, for the `workflow` shape (map #102,
  Notes). Under `subagents`, every "already covered" cell below that quotes `workflow.js` holds
  only if the coordinator happens to write the same thing.

## Sources

| Source | Read | Version | Licence, and where confirmed |
|---|---|---|---|
| `/code-review`, third-party Skill | `~/.agents/skills/code-review/SKILL.md`, 1,064 words | Folder hash `d8e341c`, updated 2026-09-17 (`~/.agents/.skill-lock.json`) | **MIT**. The upstream is the one this repository's `README.md` roster names in its `code-review` row. Confirmed from that repository's `LICENSE` and GitHub's licence field. |
| ponytail-review | `skills/ponytail-review/SKILL.md` in the ponytail repository linked from #103's body, 339 words | File last changed `bd6176a` (2026-06-19); `main` at `e3ba2aa` | **MIT**, from the repository's `LICENSE` and GitHub's licence field |
| `/simplify`, Claude Code built-in | The prompt constants in the installed binary, `~/.local/share/claude/versions/2.1.282`, read by byte offset with `dd` and never run. The published entry is at `code.claude.com/docs/en/commands` (`/simplify [target]`). | **2.1.282** | **Proprietary**: "© Anthropic PBC. All rights reserved. Use is subject to Anthropic's Commercial Terms of Service" (the `anthropics/claude-code` repository, `LICENSE.md`) |
| Google eng-practices, "What to look for in a code review" | `review/reviewer/looking-for.md` in `google/eng-practices`, 1,909 words. The published page's fourteen headings match the source file (WebFetch). | File last changed `3e6ba5c` (2022-03-31) | **CC BY 3.0**, from `LICENSE` ("Attribution 3.0 Unported") and the README ("The documents in this project are licensed under the CC-By 3.0 License"). GitHub's licence field reads `NOASSERTION`. |

**`/simplify`'s text.** It is paraphrased here, never quoted, because its text carries no
licence to reuse. The fan-out variant sends four cleanup agents out in parallel, then applies
their fixes, and frames the job as improving the changed code's quality rather than hunting
bugs.

It names four angles, Reuse, Simplification, Efficiency and Altitude, and a Phase 2 that
applies the fixes. The angle bodies are shared constants that the binary also splices into its
built-in review prompt. Their binding is inferred from minified identifiers, which change between
versions, so re-read them against the version in hand before relying on them. The published docs agree:
"Four review agents run in parallel, covering reuse of existing helpers, simplification,
efficiency, and whether the change is at the right level of abstraction. The review doesn't look
for correctness bugs."

**What adapting each source requires.**

- MIT: "The above copyright notice and this permission notice shall be included in all copies or
  substantial portions of the Software" (each `LICENSE`).
- CC BY 3.0: attribution.
- `/simplify`: its text carries no licence to reuse, so only its ideas can be taken. This note
  paraphrases it and quotes only its published documentation.
- This repository is MIT (`LICENSE`).

## The current checks

| Check | Where its text lives | When it runs |
|---|---|---|
| **Spec axis** | `workflow.js:160`: "does the diff meet the ticket's acceptance criteria and the execution spec?" | Always (`SKILL.md:84`) |
| **Standards axis** | `workflow.js:159`: "does the diff follow the coding standards this repository documents?" | Only on an instruction file in the diff, or a pin (`SKILL.md:85`) |
| **Correctness charter** | `SKILL.md:249–252` and `workflow.js:154–157`: "for each defect, what can go wrong, why the path is vulnerable, the likely impact, one clause of remedy" | Above the light plan (`SKILL.md:88`) |
| **Critic seat** | `SKILL.md:289–294`: "completeness critic … counter-critic" | Above the light plan (`SKILL.md:87`) |
| **Codex lens** | `SKILL.md:258–287`, plus the companion's `prompts/adversarial-review.md` (Codex plugin 1.0.6, Apache-2.0) | By pin only (`SKILL.md:88`) |
| **Reviewer rules R1–R7** | `agents/claude/code-reviewer.md:15–27`; the Codex twin is `agents/codex/code-reviewer.toml` | Every Reviewer dispatch |

The coverage column also cites four instruments that are not review checks, and names them where it
leans on one:

- advisor slot 1 (`SKILL.md:198–208`), which reads the spec before code exists;
- the playthrough (`docs/agents/project-workflow.md:60–63`), which verifies a prose deliverable;
- the floor check (`project-workflow.md:37–44`), which is a gate;
- `CLAUDE.md` § Conventions, a standards source that nothing yet hands to the Standards axis.

## Catalogue

### A. `/code-review` (third-party Skill; MIT)

| # | Source | What it looks for | Applies to | Current coverage, and what it adds | Disposition | Example finding |
|---|---|---|---|---|---|---|
| A1 | Step 3, standards sources | "Anything in the repo that documents how code should be written, such as `CODING_STANDARDS.md` or `CONTRIBUTING.md`". The list is handed to the Standards sub-agent. | Both. In a prose repository the sources are its conventions, such as `CLAUDE.md` § Conventions. | **Partly covered.** `workflow.js:159` names the target, "the coding standards this repository documents", but not where to look. Under `subagents` no brief is written at all. **Adds:** a step that lists the sources before dispatch. #104 and #106 decide what the sources are. | worth taking | "Standards: the diff hand-edits the `README.md` roster; `CLAUDE.md:129` says the roster is derived, not stored." |
| A2 | Step 3, "The repo overrides" | "A documented repo standard always wins; where it endorses something the baseline would flag, suppress the smell." | Both | **None.** No baseline exists to override. **Adds:** the precedence rule a baseline needs, so it matters only together with A3. | worth taking (with A3) | "Suppressed: the new host adapter reads as Middle Man, but ADR 0009 prescribes thin adapters." |
| A3 | Step 3, the smell baseline | Twelve Fowler smells from *Refactoring* ch. 3, applied "even when a repo documents nothing" | Code. For prose, 8 of 12 have a meaningful analogue (§ Fowler smells). | **Partly covered.** Only Speculative Generality has a current relative, the critic's "which remedies add generality the spec never asked for" (`SKILL.md:294`), and that clause reads remedies, not the diff. **Adds:** a floor for the axis in a repository with no standards document. That is the condition the axis was measured under (map #102, Notes). | worth taking | Data Clumps in prose: the two-root existence gate, "under `~/.claude/skills` or `~/.agents/skills`", is spelled out on 12 lines across 9 files outside `docs/`. **[measured]** `grep -rIc`, line-level; a phrase broken across two lines is not counted, so 12 is a lower bound. |
| A4 | Step 3, "Always a judgement call" | "Each smell is a labelled heuristic ('possible Feature Envy'), never a hard violation" | Both | **Already covered.** R4: "tagged hard (a documented standard or a spec requirement) or judgment (a heuristic)". `workflow.js:164` sets `hard` "only where the finding shows the diff violating an acceptance criterion, a hard limit of the execution spec, or a standard the repository states as a must". | already covered | "judgment: possible Feature Envy. `order_total()` at `cart.py:40` reads four fields of `Order` and none of `Cart`'s." |
| A5 | Step 3, "skip anything tooling already enforces" | Drops a finding that a linter, formatter or gate already catches | Both. Here the tooling is the leak-guard scan and the floor check. | **None.** 0 hits for `tooling`, `enforce` or `lint` in the three check files. **[measured: grep]** **Adds:** keeps a reading off a defect that a gate already fails. | worth taking | "Dropped: the Chunk is 262 words against its 250 cap, which the floor check already reports." |
| A6 | Step 4, Spec brief (a), plus "Quote the spec line for each finding" | "requirements the spec asked for that are missing or partial" | Both | **Already covered.** The Spec axis asks "does the diff meet the ticket's acceptance criteria and the execution spec?" (`workflow.js:160`), and R4 requires "the rule or spec line it violates". | already covered | "AC 3, 'every dial appears in the profile block', is partial: the block at `profile.md:14` omits `scope`." |
| A7 | Step 4, Spec brief (b) | "behaviour in the diff that wasn't asked for (scope creep)" | Both | **None on the diff.** The Spec axis reads toward the criteria only. `scope`'s stop counts deliverables in the plan ("Work past the deliverable count is a stop", `SKILL.md:151–152`), not behaviour inside a deliverable. The critic's generality clause reads remedies. 0 hits for `not asked`, `scope creep` or `unrequested`. **[measured: grep]** **Adds:** the reverse direction of the Spec axis. #105 decides it, and #107 its overlap with over-engineering. | worth taking | "Not asked for: `run.sh:30–44` adds a `--dry-run` flag. No acceptance criterion or spec line mentions one." |
| A8 | Step 4, Spec brief (c) | "requirements that look implemented but where the implementation looks wrong" | Both | **Already covered above the light plan.** The Correctness charter's `hard` is "true where the defect, when the code runs, would make the diff fail an acceptance criterion" (`workflow.js:157`). For prose, the playthrough asks "where did you guess, where did the text contradict itself". On a light plan the charter is off (`SKILL.md:88`), so the Spec axis's "meet" stands alone. | already covered | "The criterion 'rejects a value above range' looks met, but `parse.py:22` compares with `>=`, so the top valid value is rejected too." |
| A9 | Step 5, "Do **not** merge or rerank findings" | Keeps one axis's findings from masking another's | Both | **Already covered.** `workflow.js:227` tags each finding with its axis (`{ ...f, axis }`), and `:230–237` send every hard finding to the fix round with no ranking. The coordinator "adjudicates every finding against source" (`SKILL.md:51–52`). No finding is dropped by rank, so the masking this rule prevents cannot happen. | already covered | Not applicable: a reporting rule, not a finder. |
| A10 | Steps 1–2, a pinned fixed point and a spec search | Fails early on a bad ref or an empty diff, then looks for the spec | Both | **Empty diff: already covered.** `workflow.js:183–192` returns before review when the implementer made no commits or left the tree dirty. **Bad ref: none.** `workflow.js:23` checks only that `fixedPoint` is present, not that it resolves, so a bad ref fails inside each reviewer's diff command. **The spec search does not apply**, because a run always carries its ticket and execution spec. | already covered (empty diff); worth taking (ref check); the spec search not applicable | "Stop: the implementer made no commits, so nothing is reviewed." |

### B. ponytail-review (MIT)

| # | Source | What it looks for | Applies to | Current coverage, and what it adds | Disposition | Example finding (ponytail's own format) |
|---|---|---|---|---|---|---|
| B1 | `delete:` | "dead code, unused flexibility, speculative feature. Replacement: nothing." | Both. In prose: a clause no reader acts on, a superseded rule left in place, a knob nobody sets. | **None on the diff.** 0 hits for `dead` in the check files. **[measured: grep]** The Codex lens rules out "low-value cleanup". | worth taking | `SKILL.md:L40-44: delete: fallback paragraph for a shape the contract no longer offers. Nothing replaces it.` |
| B2 | `stdlib:` | "hand-rolled thing the standard library ships. Name the function." | Code. Prose has no standard library; its nearest relative, restating a rule a shared Chunk owns, is C1. | **None.** 0 hits for `stdlib` or `standard library`. **[measured: grep]** | worth taking (code) | `paths.py:L12-25: stdlib: hand-rolled join with separator handling. os.path.join, 1 line.` |
| B3 | `native:` | "dependency or code doing what the platform already does. Name the feature." | Both. In prose: a step that tells an agent to do by hand what a host tool already does. | **None.** | worth taking | `SKILL.md:L50-52: native: builds a file list with find and sort before searching it. The Grep tool walks the tree.` |
| B4 | `yagni:` | "abstraction with one implementation, config nobody sets, layer with one caller" | Both. In prose: a knob with one value in use, a Chunk with one consumer, an indirection file. | **Partly covered.** The critic's "which remedies add generality the spec never asked for" (`SKILL.md:294`) reads remedies, not the diff. Also hunted by D5 and Fowler's Speculative Generality (§ Overlaps). #107 decides it. | worth taking | `contract.md:L12: yagni: knob review_order with one value and no reader that branches on it. Inline the value until a second exists.` |
| B5 | `shrink:` | "same logic, fewer lines. Show the shorter form." | Both. In prose: the same rule in fewer words, which is the unit the floor check caps. | **Partly covered.** The floor check measures words against caps (`project-workflow.md:37`), but it reads only `chunks/` and proposes no shorter form. No review check asks for one. | worth taking | `chunk.md:L20-27: shrink: three sentences restate the gate. One: "the step skips unless either root holds the directory."` |
| B6 | Format: "`L<line>: <tag> <what>. <replacement>.`" | One line per finding | Both | **Already covered: location and remedy.** R4 requires "`file:line`", and R6 allows "At most one clause of remedy per finding", which the replacement fits. **Conflict:** the one-line form drops R4's "the quoted hunk" and "the rule or spec line it violates". A single finding format is on the map's "Not yet specified" list. | already covered (location, remedy); conflicts with R4 | Not applicable: a format. |
| B7 | Score: "`net: -<N> lines possible.`" | One figure: the lines the diff could lose | Both. For prose the unit is words, the floor check's unit. | **None.** R7's `FINDINGS: <n>` counts findings, not size, and the floor check measures what is on disk, not what could go. The figure is the reviewer's estimate, never a measurement. **[unmeasured]** | worth taking | `net: -38 lines possible.` |
| B8 | "If there is nothing to cut, say `Lean already. Ship.` and stop." | An explicit null verdict | Both | **Already covered.** R7 has "`FINDINGS: 0`". `workflow.js:157` and `:164` have "No findings: an empty array". The Codex prompt has "If the change looks safe, say so directly and return no findings" (`adversarial-review.md:71`). | already covered | `FINDINGS: 0` |
| B9 | Boundaries: protected test minimum | "A single smoke test or `assert`-based self-check is the ponytail minimum, not bloat, never flag it for deletion." | Code. This repository has "no test suite and no typecheck" (`project-workflow.md:36`). | **None.** It is needed only beside B1 or B4. There it stops a cleanup pass from cutting the test that the Codex focus line asks for, "does each guard have a test for its rejecting path" (`SKILL.md:271`). | worth taking (with B1 or B4) | "Suppressed: `test_parse.py:L90: delete: smoke test` is the protected minimum." |
| B10 | Boundaries: lists fixes without applying them; one concern per pass | "Does not apply the fixes, only lists them." Correctness bugs, security holes and performance are out of scope. | Both | **Already covered.** R1: "**Read-only**". Each seat holds "one reading — the axis or charter your prompt names" (`code-reviewer.md:11`). | already covered | Not applicable: a rule of conduct. |

### C. Claude Code's `/simplify` (built-in, 2.1.282; proprietary, so paraphrased)

| # | Source | What it looks for | Applies to | Current coverage, and what it adds | Disposition | Example finding |
|---|---|---|---|---|---|---|
| C1 | Reuse | New code that re-implements something the codebase already has: search the shared modules and the files near the change, and name the existing helper to call instead | Both. In prose: a Skill restating a rule a Chunk owns, where a Chunk is "single-source and referenced" (`CLAUDE.md`, Chunk vs Template). | **Partly covered, before code only.** Implementer rule 4 surfaces a false "reuse the existing X" premise (`agents/claude/implementer.md:19–21`), and advisor slot 1 audits the spec's premises. Neither asks whether the diff re-implements something it was never told existed. | worth taking | "`skill/SKILL.md:40–52` restates the tracker Chunk's claim procedure. Point at the Chunk's § Frontier and claim instead." |
| C2 | Simplification | State that is redundant or could be derived, near-duplicate code, deep nesting, and dead code a change leaves behind, each with the simpler form named | Both. In prose: a stored list that could be derived (`CLAUDE.md:129`), near-duplicate clauses, nested conditions inside one rule. | **None.** 0 hits for `dead`. **[measured: grep]** Overlaps B1, B5 and Fowler's Duplicated Code. | worth taking | "`profile.md:18` stores a list of the dials the table at `:5` already gives. Derive it." |
| C3 | Efficiency | Repeated computation or I/O, independent operations run one after another, blocking work added to startup or a hot path, and closures that hold a whole scope alive | Code. In prose, the analogue is a step that runs independent tool calls one after another, or re-reads a file the agent already holds. | **None for code; partly covered for prose.** The `scope` cap counts calls after the fact: "60 tool calls per implementer dispatch, counted from its transcript" (`SKILL.md:146`). § Review's own ordering came from "the serial first pass was the largest phase in half the measured runs" (`SKILL.md:241–242`). Both are design decisions and caps, not review checks. ponytail puts performance out of scope, and Google's page has no such section. | worth taking | "`sync.py:30–41` awaits three independent fetches one after another. `asyncio.gather`." |
| C4 | Altitude | Whether the change fixes the root cause at the right depth or patches a symptom; special cases stacked on shared infrastructure signal a fix that is too shallow | Both. In prose: an exemption clause bolted onto a rule instead of a corrected rule. `CLAUDE.md:134` documents one instance: "Never write a rule as a list of exemptions — name the gated set and relax the rest." | **Partly covered.** Advisor slot 1 checks "the spec's *mechanisms* against its stated *intent*" (`SKILL.md:203–204`) before code exists, and the critic hunts "category errors" in reviews (`:293`). No check asks this of the diff. `CLAUDE.md:134` reaches the Standards axis only when the axis runs and reads that file. | worth taking | "`gate.md:44` adds 'except under `docs/`' to the gate. What is wrong is the gated set at `:30`." |
| C5 | A cleanup finding states its cost | Each finding names its concrete cost: what is duplicated, wasted or made harder to maintain | Both | **Partly covered.** The Correctness charter asks for "the likely impact" (`SKILL.md:250`), but of defects only. R4 asks for a citation, not a cost. **Adds:** a filter against cleanup findings that are only taste. | worth taking | "Cost: the same six-line gate sits in three files, so an edit to one misses two." |
| C6 | Phase 2: skip and dedup | Skip a fix that would change intended behaviour, reach well outside the reviewed diff, or rests on a false positive; merge findings that point at the same line or mechanism. | Both | **Partly covered.** The coordinator adjudicates every finding (`SKILL.md:51–52`), and R4's "appears once" dedups within one reviewer. No text makes a cleanup remedy preserve behaviour. **Applying the fixes does not apply here**, because every reviewer is read-only (R1). | worth taking (the skip test); applying fixes not applicable | "Skipped: `shrink` on `L12–20` would drop the empty-list branch the spec requires." |
| C7 | Phase 0: uncommitted changes are in scope | Uncommitted changes are reviewed too, through `git diff HEAD` | Both | **Not applicable.** The run reviews commits only, by design: "commit the implementer's diff first" (`SKILL.md:277–278`), and `workflow.js:187–192` refuses a dirty tree. | not applicable | Not applicable |

### D. Google eng-practices, "What to look for in a code review" (CC BY 3.0)

| # | Source | What it looks for | Applies to | Current coverage, and what it adds | Disposition | Example finding |
|---|---|---|---|---|---|---|
| D1 | Design | "Do the interactions of various pieces of code in the CL make sense? Does this change belong in your codebase, or in a library? Does it integrate well with the rest of your system? Is now a good time to add this functionality?" | Both. In prose: whether a rule belongs in this Skill, a Chunk, a contract or an ADR (`CLAUDE.md`, Chunk vs Template, and "No public artifact may hard-require a private one"). | **Partly covered, before code only.** Advisor slot 1 audits the spec's premises and mechanisms (`SKILL.md:199–204`). Nothing reviews design the implementer adds inside a phase. | worth taking | "`implement-run/SKILL.md` gains a rule every tracker consumer needs. It belongs in the tracker Chunk." |
| D2 | Functionality | "Does this CL do what the developer intended? Is what the developer intended good for the users of this code?" Also edge cases, concurrency, and "bugs that you see just by reading the code". | Both. For prose, the user is the agent following the text. | **Already covered.** The Spec axis (`workflow.js:160`), the Correctness charter (`SKILL.md:250`), and for prose the playthrough (`project-workflow.md:62–63`). Concurrency is named only in the Codex prompt, "race conditions, ordering assumptions, stale state, and re-entrancy" (`adversarial-review.md:24`), which runs by pin. Whether the charter's general question reaches concurrency is **[unmeasured]**. | already covered | "`queue.py:55` reads, then writes, `count` without the lock the two workers share." |
| D3 | Functionality, UI | "the time when it's most important for a reviewer to check a CL's behavior is when it has a user-facing impact, such as a **UI change**" | Code (UI). In prose, the analogue is the playthrough. | **Partly covered, at planning only.** § Start has "look-and-feel doubt → a minimal build and an `agent-browser` screenshot loop" (`SKILL.md:181–182`). `chunks/verify-gate.md` has no screenshot, browser or UI text. **[measured: grep]** No review or gate exercises a UI diff. Prose is covered by the playthrough. | worth taking (UI code); already covered (prose) | "A menu change was never run. Its screenshot shows the new button clipped at 1280×720." |
| D4 | Complexity | "'Too complex' usually means **'can't be understood quickly by code readers.'** It can also mean **'developers are likely to introduce bugs when they try to call or modify this code.'**" | Both | **Prose: already covered** by the playthrough ("where did you guess"). **Code: none.** The Codex prompt rules cleanup out, and the Correctness charter hunts defects that are present, not ones the code invites. | worth taking (code); already covered (prose) | "`route.py:10–60` branches on `mode` in five nested places. A caller adding a mode must edit all five." |
| D5 | Complexity, over-engineering | "made the code more generic than it needs to be, or added functionality that isn't presently needed by the system" | Both | **Partly covered.** Only the critic's remedy clause (`SKILL.md:294`). The same defect is hunted by B4, A7 and Fowler's Speculative Generality (§ Overlaps). #107 decides it. | worth taking | "`loader.py:8` takes a `format=` parameter; the one caller passes `'json'`." |
| D6 | Tests, presence | "Ask for unit, integration, or end-to-end tests as appropriate for the change … in the same CL as the production code" | Code. This repository has no test suite (`project-workflow.md:36`). | **Partly covered.** The Codex focus line asks "does each guard have a test for its rejecting path as well as its accepting path?" (`SKILL.md:271`), but only for the lens, which runs by pin. On #90's fixture the Correctness charter named the missing negative-path test unprompted, at n=1 (measured in #90, not here). The charter's text does not ask for it. | worth taking | "`parser.py` adds `reject_above_range()`, but `test_parser.py` tests only accepted values." |
| D7 | Tests, validity | "Will the tests actually fail when the code is broken? If the code changes beneath them, will they start producing false positives? Does each test make simple and useful assertions?" It also asks that test complexity be reviewed. | Both. In prose: a check or gate a Skill instructs that cannot go red, the core concern of `verification-discipline`. | **Partly covered, before code only.** Advisor slot 1 hunts "an observable that cannot go red" in the spec (`SKILL.md:200`). Nothing asks it of the tests or checks a diff adds. | worth taking | "`test_cap.py:14` asserts `len(batches) > 0`, so a cap of 265 where the spec says 256 still passes." |
| D8 | Naming | "Did the developer pick good names for everything?" | Both. In prose: a term used outside its glossary sense, or an alias `CONTEXT.md` lists under `_Avoid_`. | **None.** The Codex prompt rules out "naming feedback" (`adversarial-review.md:40`). Overlaps Fowler's Mysterious Name. | worth taking | "`SKILL.md:30` calls the critic seat 'slot 2', which `CONTEXT.md:290` lists under `_Avoid_`." |
| D9 | Comments | "Are all of the comments actually necessary? Usually comments are useful when they **explain why** some code exists, and should not be explaining *what* some code is doing." | Both. In prose: a constraint without its reason. § Handoffs says "a bare constraint is followed silently, and only its *why* can be refuted" (`SKILL.md:229–230`). | **None as a review check.** § Handoffs binds the coordinator writing a dispatch, not a reviewer reading a diff. | worth taking | "`gate.md:12` says 'Never pass `--force`' and gives no reason, so a seat cannot tell when the rule stops applying." |
| D10 | Comments made stale | "look at comments that were there before this CL. Maybe there is a TODO that can be removed now, a comment advising against this change being made" | Both. In prose: a pointer, a § reference or a "see X" that the diff invalidates. | **Partly covered.** R2 reads "every touched file in full" (`code-reviewer.md:16–18`), which puts the stale text in front of the reviewer, but no brief asks about it. | worth taking | "`SKILL.md:88` still says 'the lens runs third'. The diff moved it beside the axes." |
| D11 | Documentation | "If a CL changes how users build, test, interact with, or release code, check to see that it also updates associated documentation … If the CL deletes or deprecates code, consider whether the documentation should also be deleted." | Both. In prose: the `README.md` roster, `CONTEXT.md` and Templates (`CLAUDE.md:125–128`). | **Partly covered.** `CLAUDE.md` § Conventions states the rule for Skill renames. A Standards axis that read `CLAUDE.md` could cite it, but the axis is off on code-only diffs (`SKILL.md:85`) and has no written list of sources. | worth taking | "Skill `foo` is renamed `bar`; the `README.md` roster and `CONTEXT.md` still say `foo`." |
| D12 | Style | "Make sure the CL follows the appropriate style guides". Mark an optional point "Nit:". "Don't block CLs from being submitted based only on personal style preferences." | Both | **Already covered.** The Standards axis checks "the coding standards this repository documents" (`workflow.js:159`) when it runs. "Nit:" is R4's judgment tag. "Don't block" is `workflow.js:164`, under which only a standard "the repository states as a must" is hard. | already covered | "judgment: `L14` wraps at 120 columns; the rest of the file wraps at 100." |
| D13 | Style mixed with change | "The author of the CL should not include major style changes combined with other changes." | Both. In prose: a reflowed paragraph that hides one changed rule among rewrapped lines. | **None.** | worth taking | "`SKILL.md:40–70` rewraps 30 lines and, on one of them, changes 'must' to 'may'." |
| D14 | Consistency | "the style guide is the absolute authority". Where it only recommends, it is a judgment call. "If no other rule applies, the author should maintain consistency with the existing code." | Both | **Partly covered.** Precedence is A2's rule. Consistency with undocumented practice lies outside the Standards brief, which reads only "the coding standards this repository documents" (`workflow.js:159`). | worth taking | "`new_helper.py` returns `None` on error, where every sibling raises `ValueError`. No document states either." |
| D15 | Every line, and scoped reviewers | "look at *every* line of code that you have been assigned to review … you should at least be sure that you *understand* what all the code is doing". A reviewer given part of a change should "note in a comment which parts you reviewed". | Both | **Already covered.** R2: "read every touched file in full". R4: "One you are unsure of is marked uncertain". Each seat holds "one reading — the axis or charter your prompt names", and R5 has "An absence claim names its instrument — the `grep` you ran and its scope". | already covered | Not applicable: a rule of conduct. |
| D16 | Context and code health | Read the whole file, and then the system: "**Don't accept CLs that degrade the code health of the system.** Most systems become complex through many small changes that add up" | Both. In prose: a Skill that grows one rule at a time. | **Whole-file context: already covered** by R2. **Cumulative health: partly covered.** The floor check caps word counts in `chunks/` only (`project-workflow.md:37–44`), and it exists because "nothing warned while it grew" (`:41–42`). No check reads growth in a Skill. `docs/audits/verification-discipline-rule-census.md` records one Skill growing from 2,424 to 10,186 words, "almost entirely" through one-rule appends. | worth taking (health); already covered (whole-file context) | "`SKILL.md` gains 180 words for a rule drawn from one incident, and Skills are outside the floor check." |
| D17 | Good things | "If you see something nice in the CL, tell the developer" | Both | **Not applicable.** Praise has no reader that acts on it here. The fix round hands the implementer only hard findings (`workflow.js:230–239`), and each run's seats are fresh dispatches. That praise changes nothing is **[unmeasured]**. | not applicable | Not applicable |

## The twelve Fowler smells against a prose diff

Source: `/code-review` step 3. "Prose" means a Skill, Chunk or contract diff. Eight smells have a
meaningful analogue. Two have one that this repository's own documented design endorses, so under
"the repo overrides" they would be suppressed. Two have nothing to match.

| Smell | Prose analogue | Band |
|---|---|---|
| Mysterious Name | A coined label with no definition, or a term used against its `CONTEXT.md` sense or listed under `_Avoid_` | meaningful |
| Duplicated Code | One rule stated in two Skills or Chunks, against the single-source Chunk (`CLAUDE.md`, Chunk vs Template) | meaningful |
| Feature Envy | A clause mostly about another Skill's subject: it lives where it is not read | meaningful |
| Data Clumps | The same run of qualifiers repeated together, such as the two-root existence gate on 12 lines in 9 files **[measured]** (A3). It wants one defined term. | meaningful |
| Repeated Switches | The same per-host split (Claude Code, then Codex) restated clause after clause instead of one table | meaningful |
| Shotgun Surgery | One rule change forcing edits across many Skills. `CLAUDE.md:125` lists the places a rename touches, and the contract gives a worktree to "a change editing many Chunks at once" (`project-workflow.md`, layout) | meaningful |
| Divergent Change | One Skill edited for unrelated reasons. The `verification-discipline` census found it held "four different kinds of material" (`docs/audits/verification-discipline-rule-census.md`) | meaningful |
| Speculative Generality | A knob nobody sets, or a clause for a case that has not occurred | meaningful |
| Middle Man | A file that mostly delegates onward | analogue exists, but the repo endorses the pattern: every Profile emits "two thin host adapters over" the shared contract (`CLAUDE.md`, citing ADR 0009), which delegate on purpose. |
| Message Chains | A reader walking a chain of "see §…" pointers to reach a rule | analogue exists, but the repo endorses the pattern: "A pointer carrying the destination and no part of the resolution costs a wasted detour when stale, never a wrong answer" (`CLAUDE.md`, Conventions). A chain of several hops has no ruling. **[unmeasured]** |
| Primitive Obsession | Nothing to match. Prose has no types. Its nearest case, one literal restated in several places, is Duplicated Code. | none |
| Refused Bequest | Nothing to match. Prose has no inheritance. A contract that imports a Chunk and then contradicts it is a contradiction, which the Spec axis or the playthrough reads. | none |

The band for each smell is a judgment about an analogue, not a measurement. **[unmeasured]**

## Overlaps

1. **Over-engineering is hunted by five candidate checks and one current check.** ponytail's `yagni:` and
   `delete:` ("speculative feature") (B1, B4), Google's over-engineering (D5), Fowler's
   Speculative Generality (A3), and `/code-review`'s "behaviour in the diff that wasn't asked for"
   (A7) all look for code or text the need does not call for. The critic's "remedies add
   generality the spec never asked for" hunts the same defect in the reviewers' output. A7 keys
   on the spec, and the others key on present need. #107 decides which check owns it.
2. **Altitude runs the other way.** `/simplify`'s Altitude (C4) prefers a simpler, more general
   change to the underlying mechanism over added special cases. The checks in item 1 penalise
   generality. A special case might be flagged by C4 while its general replacement is flagged by
   B4, so a brief that takes both needs a rule for which one wins.
3. **Duplication is hunted at four scopes.** Fowler's Duplicated Code looks inside the change.
   `/simplify`'s Simplification looks for near-duplicate code. `/simplify`'s Reuse
   compares the diff with the existing codebase. ponytail's `stdlib:` and `native:` compare it with
   the standard library and the platform. One Chunk-restating Skill paragraph can be a finding
   under C1, C2 and A3 (Duplicated Code) at once.
4. **Dead weight.** ponytail's `delete:` (B1), `/simplify`'s leftover dead code (C2) and
   `shrink:` (B5) overlap. D10's stale comments are the same defect in the text around the code.
5. **Hard to read.** Google's Complexity (D4), `/simplify`'s Simplification (C2) and ponytail's
   `shrink:` (B5) all hunt it. For prose the playthrough already catches it.
6. **Names.** Fowler's Mysterious Name and Google's Naming (D8) are the same check.
7. **Tests.** Google's presence and validity questions (D6, D7), the Codex focus's test-gap line,
   and the Correctness charter overlap. On #90's fixture the charter named the missing
   negative-path test unprompted; the lens named it only once its focus carried the test-gap line. Advisor slot 1 hunts the same defect as D7 ("an
   observable that cannot go red"), but in the spec. ponytail's protected test minimum (B9) is the
   counterweight: without it, B1 and B4 can flag the very test D6 asks for.
8. **Precedence.** `/code-review`'s "The repo overrides" (A2) and Google's "the style guide is the
   absolute authority" (D14) are one rule.
9. **Judgment versus hard.** `/code-review`'s "Always a judgement call" (A4), Google's "Nit:"
   (D12) and R4's hard/judgment tag are one mechanism, already in place.
10. **Implemented but wrong.** `/code-review`'s Spec (c) (A8) and the Correctness charter's
    AC-failing `hard` find the same defect. On a light plan only the Spec axis runs.
11. **Design.** Google's Design (D1), `/simplify`'s Altitude (C4) and advisor slot 1's mechanism
    check overlap. Slot 1 reads the spec before code, and D1 and C4 read the diff after.
12. **Documentation.** Google's Documentation (D11), its stale comments (D10) and the `CLAUDE.md`
    rename convention hunt the same thing. The convention is a standards source; D10 and D11 would
    be briefs.
13. **Cleanup against correctness.** ponytail ("Correctness bugs, security holes, and performance
    are explicitly out of scope") and `/simplify` (its published entry: "doesn't look for correctness bugs") both keep
    cleanup in a pass of its own. The Codex prompt excludes cleanup from the other side. They
    differ on performance: `/simplify` has Efficiency (C3), ponytail rules it out, and Google's
    page has no such section.

## Seen in passing, outside the four

Claude Code 2.1.282's built-in review prompt reuses `/simplify`'s four angle constants. It adds a
conventions angle over `CLAUDE.md`, paraphrased: flag a violation only where the exact rule and the
exact line that breaks it can both be quoted, never a style preference or an inference from a
document's spirit. Its
published entry says: "Depending on your model and effort level, the review also covers cleanup
opportunities" (`code.claude.com/docs/en/commands`). That makes it a fifth source for #106's
question of what the Standards axis reads. It is not catalogued here.

## Confounds

- **Nothing was run.** Every coverage call reads the check's text, not its behaviour. A charter
  that does not name a defect may still find it, as the Correctness charter found #90's
  test-gap plant. So "none" and "partly covered" mean *not asked*, not *never found*.
  **[unmeasured]**
- **The `subagents` shape has no written Spec or Standards brief**, so coverage there depends on
  what each coordinator writes that run.
- **`/simplify`'s prompt text** was read from one binary version, through minified identifiers.
  The published description is the stable reference.
