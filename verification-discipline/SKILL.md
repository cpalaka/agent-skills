---
name: verification-discipline
description: How to trust a reading and how to file a negative claim. Use before believing any post-fix number, benchmark, or pass/fail verdict; before writing or re-running a check, gate, or eval harness; before filing an absence claim ("dead code", "nothing owns X", "not in the repo", "no regression"); before a destructive act resting on an all-clear; and before any 1:1 fan-out from a source. Triggers: calibrate, control, known-bad, noise floor.
---

# Verification discipline

One question sits under every rule here: **could more than one true state of the world produce this same reading?** A check that cannot go red discriminates nothing, and it reports success. The cure is a **control**: a known-bad the instrument must catch, a known-present needle the search must find. Until the detector has shown it can disagree with you, its agreement is evidence for nothing.

## Red it first

**Reproduce the known-bad before believing the post-fix number.** Reproduce it exactly, to the figure on record, as its own plan stage. An instrument that cannot reproduce the defect cannot certify its absence. Then feed the instrument its own reference as a candidate. A grader once scored the source document it was grading against 9/10.

**Calibrating the instrument and falsifying the claim are different acts. Do both.** Write the one-line corruption of the deliverable's central claim, confirm the suite reds, keep whatever check reds. The corruption breaks exactly *one* branch of the rule under test; a coarse one reds the suite for the wrong reason. Commit before you corrupt, so the revert lands on the state under test: `git checkout -- <file>` restores HEAD and deletes an uncommitted diff. Then re-run the gate against the tree that ships.

**Something must consume the check's result.** Derive the verdict line from the check rather than echoing it beside the check; an unconditional pass line suppresses the violations printed above it. An action chained after a check runs whatever the check printed unless the exit status gates it (`&&`, an `if`, or a separate invocation after you have read the output). Measured: a `mv` behind a `;` ran past a printed `PRESENT` and truncated a session transcript. A check nothing consumes is decoration.

**Derive tolerances from the measured noise floor.** Measure the residual on a known-good run, set the bound just above it, state the ratio.

**Sweep for identity claims. Sampling cannot establish bitwise or float equality.** A counter reporting 100% failure is as suspect as one reporting 0%.

**A path is not an identity, and a count is not a set.** Hash bytes at write time, never re-stat the name later, and never assert two files identical without running the diff. Ask **"N what?"** of every count and answer it from the instrument, not the prose beside it; a field wholly reproducible from its siblings is derived — compute it, never store it. For probes, plant a token that can *only* be present if the layer under test was exercised.

**A null reading is evidence only once the subject is inside the measurement window.** Calibrating on one subject does not validate the instrument for another. Before believing "no effect", show that the thing the change moves is observable at all. Then exclude the rival causes. The *form* of the failure discriminates, not the fact of it: "port unreachable" comes identically from a firewall DROP and from nothing listening, and only timeout-vs-RST separates them.

**A reading from inside the trust boundary cannot establish a property of that boundary.** Public-ness, reachability and permission are properties of the *least*-privileged caller. `gh repo view --json visibility`, or a `curl` carrying your session, answers a different question and answers it green. Re-run unauthenticated or as the least-privileged principal, and assert the complement: the thing that must stay closed fails the same probe.

**When a spec names the metric, also measure what the metric cannot see.** `scrollWidth === clientWidth` counts start-side padding only.

**A saved review or eval harness rots with no error signal.** Its pinned positions and golden answers describe files it does not own. Once those files are corrected it flags the fix as a regression and runs clean. Re-read its embedded context against the target before every re-run.

**The installed artifact and the repo file are two files. Diff them by digest, and check *which way* they differ.** A symlinked store inverts the usual drift: the checkout *is* the install, so a `git checkout` to test a branch silently downgrades every other skill. Test by extraction (`git archive <ref> <dir> | tar -x -C <scratch>`) and digest-match against the branch blob.

### Read the artifact, not the oracle

A status field, health endpoint, summary line, or your own report is computed from state that outlives the failure, so it stays green while the work does not happen. None of these emitted an error:

| oracle | reported | while |
|---|---|---|
| `systemctl show -p Result` | `success` | a dependency refused the unit and it never ran |
| `tailscale ping` | `pong … 3ms` | **all** IP traffic on the host was blocked. Disco runs in userspace over any path and never touches routing or the firewall |
| `git rev-parse HEAD` during a paused rebase | the upstream commit, matching `origin/<branch>` | your commit sat unapplied in the rebase; the rejection was three lines up |
| the harness's "user rejected" on a tool call | rejected, not run | an interrupt arrived mid-flight and the write had already landed — a retried append duplicates silently |

- **A path-mediated check reads a payload byte.** Assert content-type and a byte count against the file on disk. A status code, a ping endpoint or a metadata query cannot stand in for that byte. HTTP 200 is not success; Subsonic puts the error in the body. An absent `nofail` mount resolves every path-shaped check against an empty directory on the root filesystem, so *all* observables pass and nothing works.
- **A capability manifest is not a run record.** A log lists what the binary *could* do beside what it did, and a substring match cannot tell them apart. Ask: *is this string here because of what happened, or because of what is installed?* Measured: grepping `h264_nvenc` in an ffmpeg log passes whatever ran, because the banner lists it too. The discriminating artifact is the output-stream metadata plus absence of the rival codec on the invocation line.
- **A race fix is not proven by the outcome it produces.** A lucky run with the bug still present produces the same outcome. Measured: a bind-order fix was read as working on a boot with no guard installed at all. Three arms, ascending: (1) the fix's own log line ordered *before* the thing it guards, which is necessary and never sufficient; (2) a non-zero wait, because a guard that returned in ~0 s never exercised the race, which is why restarting a service cannot close a boot-race criterion; (3) an independent process that hit the same failure inside the window, since a witness you did not construct cannot have been built to agree with you. Then state the counterfactual, labelled, never as the criterion.
- **Read the diff back, not the exit code.** An all-or-nothing multi-edit script drops every edit on one drifted anchor, and the commit message still describes them. Write per edit; read `git show --stat` and the diff against what you intended. A failed `git add` on a bad pathspec stages nothing and does not stop the `git commit` chained after it. Confirm HEAD is attached (`git status`) before comparing it with anything.

### Assert the complement

For any "X must never happen" rule, also assert the nearby behaviour that must still work, pinned with its measured margin. A one-sided check is satisfied best of all by a deleted feature. What the complement still misses:

- **A value nothing reads passes never-X and must-work together.** Grep for the production consumer and assert at that boundary; producer plus test is inert.
- **A probe that samples before the system settles measures timing, not the property**, and it fails in the direction that looks like a real bug. Assert steady state first; keep probe code byte-identical across compared runs.
- **One artifact answering a class of inputs is checked per sub-class**, partitioned by what the system does *differently*. The host is part of the domain: a skip branch "passed" on macOS only because it lacked the `/mnt` that broke it on Linux.
- **Partition by reachable state as well as input.** A snapshot gate over a stateful artifact tests only the state it captured and passes every rule that needs an interaction to apply.

## An absence claim carries the scope of the instrument

"Nothing owns X", "dead code", "not in the repo", "these are all the branches" assert over the *whole* project. Your review scope and your instrument's reach become part of the claim, and they vanish from the sentence unless you write them in. A positive claim survives anything outside the file you read; a negative one does not.

- **Name the instrument's reach inside the claim**, and prefer the authoritative query over the cached one. `git ls-remote` asks the remote; `git branch -r` reads a local cache of a past fetch, and once certified three branches safe to delete while a fourth, local to another machine, held 11 commits that existed nowhere else.
- **Put the intent layer in scope first.** Read the board or tracker. A review scoped to code and architecture docs converts *planned* into *broken*, most confidently on active work. This binds solo review as much as fan-out.
- **The filesystem is a second invisible layer.** Read `.gitignore` and run `git check-ignore -v` before filing "not in the repo". *Not tracked* and *not present* are different claims.
- **Settle runtime-state questions with a live probe**, never a repo read.
- **A peer's claim about a per-machine artifact** (`~/.claude`, `~/.config`, service units, mounts) carries its machine as unstated scope in either polarity; re-run it on yours. Re-verify any peer all-clear before a destructive act. A correction is itself an upstream fact.
- **Two passes agreeing through the same instrument is one reading** — and two docs agreeing is none when one copied the other.
- **A "fixed" note is a claim at the site it names.** Re-verify at every sibling site, and read the replacement against the record: a correction accepted is not thereby applied.
- **In a test, an absence claim enumerates every writer of the resource and drives the assertion through each.** Exercised only through its owner, the check guards the one door that was never the threat.
- **Verify a large deletion by set-difference, not read-through.** "Nothing load-bearing was lost" is an absence claim over everything removed. Diff the token sets, old file against new file plus wherever content moved, and read the residue. The failure a read-through cannot see is a surviving clause that now points at nothing.

### Prove the needle first

A control finds a known-present needle through the *same pipeline* before the absence is believed. A flag guesses one cause of blindness; the control detects blindness whatever the cause. The flag list is unbounded, the control is one line. Measured:

- **Compression defeats every text reader, and `-a` does not help.** `strings <cache> | command grep -c <subject>` returned 0, the expected answer, and 0 again for a subject known to be present. The file was zlib behind an 8-byte header; `-a` answers NUL bytes only.
- **`cmd | grep X || echo "no X"` reports clean when `cmd` fails.** A teardown check printed *no blackhole routes* because `ip netns exec` needed root and `2>/dev/null` removed the only evidence. Print the table and read it, or check `cmd`'s own exit status. The absence of output is never the evidence.

In Claude Code, `grep` is a shell function that execs the harness binary as `ugrep … -I --ignore-files`, so its negative is unreliable three ways. One NUL byte makes the whole file silently unsearchable (no output, exit 1, identical to a miss; `file` saying `data` is the tell). `--ignore-files` skips ignored paths. Over raw HTML a tag-bounded pattern misses tag-split phrases, so strip to text first (`textutil -convert txt -stdout` on macOS). It never false-positives. Use `command grep`, `awk` or `rg` whenever a negative is load-bearing. That is necessary, not sufficient, per the compression case above.

**Right by accident is worse than wrong.** A wrong answer eventually collides with something. A correct-sounding answer from a dead instrument never prompts a re-check and hardens into the record. **Close-out checks are where this bites.** Teardown sweeps and "confirm it's clean before we finish" expect the answer *clean*, so a broken check and a passing one are indistinguishable. Put the control on the *last* check, not just the first, and re-derive the cleanup list from what the run produced. A criterion written before the run cannot know which artifacts carry its proof.

## Blindspot the source before a 1:1 fan-out

Spec→tasks, schema→migrations: a hole in the source replicates into all N outputs, and an output review is structurally blind to a deliverable the source never named. Source-pass and output-pass catch different failures; run both. The discovery-side sibling: sweep the real corpus before authoring a taxonomy, catalog or checklist from intuition. A from-memory seed systematically undercounts.
