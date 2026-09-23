---
name: verification-discipline
description: How to trust a reading and how to file a negative claim. Use before believing any post-fix number, benchmark, or pass/fail verdict; before writing or re-running a check, gate, or eval harness; before filing an absence claim ("dead code", "nothing owns X", "not in the repo", "no regression"); before a destructive act resting on an all-clear; and before any 1:1 fan-out from a source. Triggers: calibrate, control, known-bad, noise floor.
---

# Verification discipline

One question sits under every rule here: **could more than one true state of the world produce this
same reading?** A check that cannot go red reports success and discriminates nothing. The cure is a
**control**: a known-bad the instrument must catch, a known-present needle the search must find.
Until the detector has shown it can disagree with you, its agreement is evidence for nothing. **The
mirror hides better: a criterion that cannot go green** reads red against a correct deliverable and
presents as a finding, not a broken instrument — ask what a pass would look like and whether the
sources can produce one. A before/after comparison changes the subject, never the instrument: re-run
the control under the same prompt and rubric as the live arm.

## Red it first

**Reproduce the known-bad, to the figure on record, before believing the post-fix number** — as its
own plan stage. Then feed the instrument its own reference as a candidate (a grader once scored its
own source document 9/10). The control must fail on the predicate the acceptance criterion names,
not merely on some known-bad.

**A "before" that a sibling ticket already moved is the sibling's *after*.** Reporting that half as
the other ticket's leaves the criterion permanently half-satisfied. Check the instrument out of git
at the commit before the sibling's, and license the rebuild by matching a figure the sibling
published; unmatched, a reconstruction is one more unvalidated reading.

**For every predicate, name the mutation that reds it and run it.** A control can run and still
prove nothing:

- **Composite verdict.** Over an AND of checks, each arm needs a control that fires on it *and on
  no other*, or an arm can be deleted with the suite green. Read the failure reasons, not the
  verdict: a control naming several is evidence about the whole, never an arm.
- **Absorbed fault.** Clamps, validators, defaults, retries and fallbacks eat an injected fault
  and the control fails green. Confirm the fault changed observable behaviour before reading the
  verdict.
- **Moving oracle.** An expected value read from the source under test moves with any mutation of
  that source. Assert the property the predicate names (a sign, a bound), which the mutation
  cannot follow.
- **Generated fixture.** A fixture derived from the table it checks validates the matcher, never
  the data; no mutation can red it. Ask: if this row were simply wrong, what in this repository
  would ever say so? Use an external oracle (a real log, a live run) and say in the artifact that
  the suite cannot catch a wrong row.
- **Wrong axis.** The assertion must vary along the axis the criterion names, and the fixture must
  make it vary: assert every state the sentence enumerates, assert containment by the window
  between two markers rather than a whole-output grep, build fixtures where the rival references
  (index vs HEAD) disagree.
- **Wrong form.** A check whose form cannot express the question returns the zero an honest
  all-clear returns: line-oriented search over a cross-line question (join the file and search a
  window instead), `\b` in `git grep -E` (matched nothing on this machine, exiting 1), a
  hand-rolled stand-in for a real tool. The known-bad must share the question's shape, and only a
  different instrument repairs the form; calibrate a stand-in against the real tool.
- **By construction.** `git diff $M HEAD` is empty for every input when `M` was built from
  `HEAD^{tree}`. Name the input that makes a derived verdict false; if none exists, it is a paste
  guard, not a verdict — and check the precondition that carries the safety instead (for a merge,
  linear descent: `git merge-base --is-ancestor`).
- **Put out of reach by a sibling fix.** One criterion's fix can pre-empt another's defect,
  leaving the second with no arm that can red; a deleted implementation then satisfies it. Only
  running each criterion's mutation finds this.

**A predicate over a tool's output keys on the thing's identity, never on the tool's phrasing.** Run
the command and count the distinct output shapes the predicate must survive, rather than confirming
the happy case; ask what happens when the tool adds a shape. A false red is not the safe side — it
teaches the reader to skim.

**Calibrating the instrument and falsifying the claim are different acts. Do both.** Write the
one-line corruption of the central claim that breaks exactly one branch, confirm the suite reds,
keep whatever check reds. Commit first so the revert lands on the state under test
(`git checkout -- <file>` restores HEAD and deletes an uncommitted diff), then re-run the gate on
the tree that ships. On an untracked file git cannot prove the revert: take its `sha256` before
corrupting, require equality after, and make the green run the last entry in the record.

**Something must consume the check's result.** Derive the verdict line from the check rather than
echoing it beside it. An action after a check runs unless the exit status gates it (`&&`, `if`, or a
separate invocation after you read the output): a `mv` behind a `;` ran past a printed `PRESENT` and
truncated a transcript.

## Gates and numbers

**A guard fires on a CAUSE, or it is noise.** Ask what it does on a known-good input and what it
does once the cause is fixed: a trigger correlated with the failure cries wolf on healthy runs, one
that assumes the failure cries wolf forever. Test the precondition at runtime so the guard retires
itself. A fail-closed false alarm is not the safe side; it trains the same ignore-it reflex.

**A permanently non-zero verdict carries no information.** Remove the findings or accept them — per
check, never per line — and print the accepted count and sites on every run, CLEAN included, so
acceptance leaves a trace. Calibrate the marker both ways: an over-accepting one (wrong id, prefix
match, whole-line blanket) passes a positives-only test. A human override needed every run is a
standing red.

**A criterion quotes the predicate, never a gate's printed count.** The number belongs to one run of
one tree and expires when the instrument changes (`27 of 28` became a correct `26 of 27`); the
predicate (`M - N <= 1`) survives. Whoever inherits a dead number satisfies the form and inverts the
substance rather than ticking it. A count written into prose as illustration drifts the same way:
name the shape, leave the measurement in the record that owns it.

**Derive tolerances from the measured noise floor.** Measure the residual on a known-good run, set
the bound just above it, state the ratio.

**A ceiling derived from a documented cap has a side.** Too slack never fires; too tight reds on
legal input and reads as a finding, and live readings sitting far from the bound cannot tell you
which. State the worst case, put the constant beside it, say which side it lands on. Here the
arithmetic *is* the claim, unlike a reuse premise, where the anchor is what to re-verify.

**Sweep identity claims; sampling cannot establish bitwise or float equality.** A counter reporting
100% failure is as suspect as one reporting 0%.

**A path is not an identity, and a count is not a set.** Hash bytes at write time rather than
re-stat the name, and run the diff before asserting two files identical. Ask **"N what?"** of every
count and answer from the instrument. A field reproducible from its siblings is derived: compute it,
never store it.

**A count keyed by position is not a count of things.** File:line pairs from a log or transcript
re-count one site as several once files shift. Before sizing an eval set, a fixture set or a
"distinct sites" claim, count in the live tree (`command grep -rn`, exclusions named) and treat the
log figure as an upper bound.

**A probe plants a token that can only be present if the layer under test ran.** A probe that names
the strings you then count reads its own words back: name each string once, so a count of 1 is the
probe alone and 2 is probe plus real content — a bare 1 read as presence is your own question. A
*shipped* document telling a reader to search their context cannot quote the string, since it is
loaded into that context — make the observable structural (does the body arrive as its own block?)
and say why no phrase is named.

**A null reading is evidence only once the subject is inside the measurement window.** Show the
thing the change moves is observable at all, then exclude rival causes by the *form* of the failure:
"port unreachable" from a firewall DROP and from nothing listening differ only as timeout vs RST.

**A probe answers only the question it exercised.** A green precondition (the adapter exists) says
nothing about the capability (the device survives rendering). Probe the operation, over the duration
the claim covers.

**A call site shows that a call happens, never what it does.** Read the callee to its return
statements and name the conditions it exits on beside the claim.

**A reading from inside a trust boundary cannot establish a property of it.** Public-ness,
reachability and permission belong to the least-privileged caller: re-run unauthenticated, and
assert that what must stay closed fails the same probe.

**When a spec names the metric, also measure what it cannot see.** `scrollWidth === clientWidth`
counts start-side padding only.

**Saved instruments go stale silently.** A review or eval harness pins positions and golden answers
in files it does not own; re-read its embedded context against the target before each re-run. A gate
command loaded into context is a copy: re-read it from disk after any pull or checkout.

**The installed artifact and the repo file are two files.** Diff them by digest and check which way
they differ. Where the checkout is the install (a symlinked store), a `git checkout` downgrades
every installed skill; test a ref by extraction (`git archive <ref> <dir> | tar -x -C <scratch>`)
and digest-match against the branch blob.

**A skill's trigger reliability is a measurement.** Before retiring an explicit-invocation rule on
"it fires from context now", count `"skill":"<name>"` calls against sessions in that project's
transcripts (`~/.claude/projects/<cwd-slug>/*.jsonl`, via `/usr/bin/grep`).

### Read the artifact, not the oracle

A status field, health endpoint, summary line or your own report is computed from state that
outlives the failure. None of these emitted an error:

| oracle | reported | while |
|---|---|---|
| `systemctl show -p Result` | `success` | a dependency refused the unit and it never ran |
| `tailscale ping` | `pong … 3ms` | all IP traffic was blocked; disco runs in userspace, off routing and firewall |
| `git rev-parse HEAD` in a paused rebase | the upstream commit | your commit sat unapplied; the rejection was three lines up |
| the harness's "user rejected" | rejected, not run | the write had landed mid-flight; a retried append duplicates |
| `ffmpeg -v error -i X -f null -`, `ffprobe` | exit 0, full duration | zero frames decoded; gate on the `time=` reached |

- **A figure recovered from a summary of your own work is a claim.** Compaction keeps conclusions
  and drops derivations; re-derive any figure before it enters a ticket, record or commit.
- **A generator is an oracle for what it once produced.** Open the form the runtime consumes, at
  the revision in use, and grep prior review dispositions for the same premise.
- **A path-mediated check reads a payload byte:** content-type and a byte count against the file.
  HTTP 200 is not success (Subsonic errors arrive in the body); an absent `nofail` mount makes
  every path check pass against an empty root-filesystem directory.
- **A capability manifest is not a run record.** Ask whether a string is there because of what
  happened or what is installed: `h264_nvenc` is in the banner of any ffmpeg build that has it.
  Read the output-stream metadata, and the rival codec's absence from the invocation line.
- **A race fix is not proven by its outcome.** Three arms: the fix's log line precedes what it
  guards (necessary, never sufficient); a non-zero wait (a restart cannot close a boot race); an
  independent process hitting the failure inside the window. State the counterfactual, labelled,
  never as the criterion.
- **Read the diff back, not the exit code.** An all-or-nothing multi-edit drops every edit on one
  drifted anchor; a failed `git add` does not stop the chained `git commit`. Write per edit, read
  `git show --stat` and the diff against what you intended, and confirm HEAD is attached
  (`git status`) before comparing it with anything.
- **A cross-reference that resolves is a claim about scope.** Read the sentence it lands on; one
  scoped "to fix it" does not carry a general rule.
- **Checking a consult's evidence is not checking its recommendation.** Adjudicate the
  recommendation against the source it claims to follow, or hand it to a lens that did not read
  the consult.
- **A criterion predicting behaviour is checked against the measurement,** never against a record
  of one being taken. When the record refutes it, supersede it in place and carry the refutation
  to the parent.
- **Prose an agent will follow is verified by a fresh agent following it,** never by reviewing its
  diff. Run it against a throwaway target, and ask "where did you guess, where did the text
  contradict itself, what did it name that does not exist". The host's instruction files are a
  confound on every arm: use a scratch config, or name the confound and make file attribution the
  discriminator.
- **A count, glob or "the N places" written into instructions is an untested claim** that one
  command checks — including a coordinator's dispatch text, which no playthrough reaches. Run it
  first; an undercount reads as simplification and licenses skipping steps. Prefer a worked
  instance to a rule.

### Assert the complement

For any "X must never happen" rule, also assert the nearby behaviour that must still work, pinned
with its measured margin. A one-sided check is satisfied best of all by a deleted feature. What the
complement still misses:

- **A value nothing reads passes both.** Grep for the production consumer and assert there;
  producer plus test is inert.
- **A probe that samples before the system settles measures timing**, and fails like a real bug.
  Assert steady state first; keep probe code byte-identical across compared runs.
- **Check per sub-class**, partitioned by what the system does differently — the host included: a
  skip branch "passed" on macOS only because it lacked the `/mnt` that broke it on Linux.
- **Partition by reachable state as well as input.** A snapshot gate passes every rule that needs
  an interaction to apply.

### Count agreeing readings once

**Two passes agreeing through the same instrument are one reading**, and two docs agreeing are none
when one copied the other. Seats agree the same way — ask what single artifact they both read:

- **Seats that cannot execute converge on the same runtime inference.** Where a finding turns on
  runtime behaviour, spend the run before adjudicating, and count read-only seats as one lens.
- **Seats converge on an unstated convention** (sign, unit, handedness). Re-derive from the source
  data, then write the convention where both seats read.
- **A classification you defined is an instrument.** Have one seat quote back what a key term
  meant; when seats' numbers agree *and* disappoint, change the definition and re-run one seat.
- **A verifying seat checks inside the scope the claim states.** Vary the question, not the seat:
  "trace each value to its producer" audits the world; "is this right?" audits your sentence.
- **Two findings can each be right and jointly destructive.** Write down what each fix depends on,
  and re-read the whole edited region, not the hunks.
- **A fact corrected at its source leaves derived copies stale.** Grep the number and each
  phrasing of it across the tree; prefer deriving the second mention to restating it.

## An absence claim carries the scope of the instrument

"Nothing owns X", "dead code", "not in the repo" assert over the whole project, so your review scope
and your instrument's reach are part of the claim and must be written into it.

- **Name the instrument's reach, and prefer the authoritative query.** `git ls-remote` asks the
  remote; `git branch -r` reads a past fetch, and once certified branches safe to delete while a
  machine-local one held commits that existed nowhere else.
- **Put the intent layer in scope first:** the board or tracker. Otherwise *planned* reads as
  *broken*, most confidently on active work. This binds solo review as much as fan-out.
- **The filesystem is a second layer.** Before filing "not in the repo", read `.gitignore` and run
  `git check-ignore -v`; *not tracked* is not *not present*.
- **Settle runtime state with a live probe**, never a repo read. Whether an `@import` expanded is
  runtime state that your own injected context answers: the body is there or it is not. A headless
  `claude -p` probe needs a known-absent control and can return 429 while exiting 0; it earns its
  place for a settings question (`claude -p --settings '<json>'`: flip one key both ways, keep a
  known-present entry as control).
- **What a sub-agent received is the harness's answer, not the seat's.** Read the transcript line
  with `.type=="attachment"` and `.attachment.type=="instructions"`, selected by type — a
  positional miss returns null, whose counts print as a clean zero. A control string planted in
  the dispatch prompt and reading 0 in the payload separates delivery from echo. A seat gets its
  parent's *memoized* walk, so a present block can be stale.
- **A peer's claim about a per-machine artifact** carries its machine as unstated scope; re-run it
  on yours, and re-verify any peer all-clear before a destructive act. A correction is itself an
  upstream fact.
- **A "fixed" note is a claim at the site it names.** Re-verify every sibling site; a correction
  accepted is not thereby applied.
- **In a test, enumerate every writer of the resource** and drive the assertion through each.
- **A dead reader keeps nothing alive.** Name the live set, follow what it reads outward; a
  cluster no live file reaches is dead however densely it cites itself.
- **A bulk deletion lasts only once its premise is retired in writing** — in a file that outlives
  the deletion, cited from the change — or the next session restores it from the instruction that
  produced it.
- **"Nothing load-bearing was lost" needs three instruments.** *Presence*: diff token sets, old
  against new plus wherever content moved, and read the residue. *Force*: give an independent
  reader the old rules as rows, without your mapping, and ask which the new text still binds — a
  word count cannot see a rule that survived and stopped binding: an imperative recast as a
  possessive or a description, a dropped tell word (*silently*), a lost term tying it to a
  sibling. *Evidence*: re-run any command kept as proof and read its output against the claim's
  exact words, disposing of every apparent counterexample.
- **A source's claim about its own evidentiary status is a claim.** "This is the only record" and
  "X is recorded in `<doc>`" both fail silently. Grep the rarest token in the sentence, never its
  topic: the topic finds the conclusion, not the evidence.
- **A per-item verdict carries its denominator.** `0 failures over 0 checked` prints a pass, and
  `jq`'s `all()` is true on an empty array. Print the item count beside the verdict, and read a
  zero denominator as *not run*.

### Prove the needle first

A known-present needle must come back through the *same pipeline* before an absence is believed. A
flag guesses one cause of blindness; the control detects any. Measured:

- **Compression defeats every text reader**, and `-a` answers only NUL bytes.
- **`cmd | grep X || echo "no X"` reports clean when `cmd` fails**, and `2>/dev/null` hides why.
  Print the table and read it, or check `cmd`'s exit status; absence of output is never evidence.
- **A path starting with `-` is parsed as an option** and the count comes back empty, not zero —
  every Claude Code transcript directory is named `-Users-…`. Use `./`, `--`, and `-e`.
- **`grep -c` answers narrower questions than it looks.** A multi-line pattern becomes independent
  needles, which `-ge 1` passes and `-eq 1` catches (assert no newline in it); a phrase wrapped
  across lines returns 0, a phantom *green* on an absence check (normalise with
  `tr -s ' \n' '  '`); and it exits 1 on zero, so `$(grep -c … || echo 0)` yields two zeros — use
  `c=$(grep -c … 2>/dev/null); c=${c:-0}`.
- **Recursive search can skip a symlinked directory and exit 1.** The harness's ugrep follows one
  under `-R`; BSD `grep` follows only with `-RS` (`-r` and `-R` alike skip it), so a bare `-R`
  plus the switch-binary rule below yields exactly this silent zero. `rg` needs `-L`; `awk` does
  not recurse. Resolve roots with `readlink -f` or glob the files so the shell resolves the link,
  and confirm traversal before reading a zero.
- **A regex list's own text is not a needle for it**: most patterns do not match their own source.
  Build the needle from what the pattern matches (strip `\b`, take an alternation's first branch),
  confirm with `grep -iqE -e <pattern>`, or calibrate the tool that owns the list.
- **A control licenses only the stage it ran at.** Branch on the harness's exit status before
  parsing its output; a harness failure is the absence of an answer, never a negative one.

In Claude Code, `grep` is a shell function running ugrep with `-I --ignore-files`: one NUL byte
makes a file silently unsearchable (`file` says `data`), ignored paths are skipped, and a
tag-bounded pattern misses tag-split HTML (strip to text first: `textutil -convert txt -stdout`). It
never false-positives. Where a negative is load-bearing use `command grep`, `awk` or `rg`, carrying
the symlink flag above.

**Right by accident is worse than wrong.** A correct-sounding answer from a dead instrument never
prompts a re-check. Close-out checks — teardown sweeps, "confirm it's clean" — expect *clean*, so
put the control on the *last* check too, and re-derive the cleanup list from what the run produced;
a criterion written before the run cannot know which artifacts carry its proof.

## Blindspot the source before a 1:1 fan-out

Spec→tasks, schema→migrations: a hole in the source replicates into all N outputs, and an output
review cannot see a deliverable the source never named. Run a source pass and an output pass. Before
authoring a taxonomy, catalog or checklist, sweep the real corpus; a from-memory seed undercounts.

The incident behind each rule is in this file's git history (`git log -- verification-discipline`).
