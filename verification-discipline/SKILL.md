---
name: verification-discipline
description: How to trust a measurement and how to file a negative claim. Use BEFORE believing any post-fix number, benchmark, profile, or pass/fail verdict; before writing a check, gate, assertion, or eval harness; before re-running a saved review/eval harness; and before filing any absence claim ("dead code", "nothing owns X", "not in the repo", "untested", "no effect", "no regression"). Triggers: calibrate, known-bad, control, tolerance, noise floor, regression check, "verify the fix", "confirm it's gone", "nothing uses this", "safe to delete".
---

# Verification Discipline

Two failure families, both silent. A bad instrument reports success. A negative claim is false the moment anything outside your review scope contradicts it. Neither produces an error signal.

## I. Calibrate the instrument before trusting any reading

**Reproduce the known-bad value first.** Before believing a post-fix number, reproduce the defect you intend to remove — exactly, to the figure on record. Make that control its own plan stage. An instrument that cannot reproduce the defect cannot certify its absence.

**Known-bad is necessary but not sufficient — also score the instrument against its own INPUT.** A grader once scored the source document it was grading *against* 9/10.

**Calibrating the INSTRUMENT and falsifying the CLAIM are different acts — do both.** Write the one-line corruption of the deliverable's central claim, confirm the suite reds, and keep whatever check reds.

**A corruption must break exactly ONE branch of the rule under test.** A coarse corruption reds the suite for the wrong reason and certifies coverage that does not exist.

**A corruption must be reversible to the STATE UNDER TEST, not to HEAD.** `git checkout -- <file>` restores from HEAD and silently deletes an uncommitted diff. Commit before you corrupt, or revert in place, and re-run the gate against the tree that ships.

**A cleanup criterion written BEFORE a run cannot know which artifacts carry its proof.** Re-derive the cleanup list from what the run actually produced.

**Never verify a bitwise/float-identity claim by sampling — sweep.** A counter reporting 100% failure is as suspect as one reporting 0%.

**A summary verdict must be DERIVED from the check result, never echoed beside it.** This covers throwaway one-liners: an unconditional pass line suppresses the violations printed above it.

**Derive tolerances from the measured noise floor, never intuition.** Measure the residual on a known-good run, set the bound just above it, state the ratio.

**A NULL reading is evidence only once the SUBJECT is inside the measurement window.** Calibrating on one subject does not validate the instrument for another. Before believing "no effect", prove the thing the change moves is observable at all.

**And once the reading IS real, a negative is only a pass when its RIVAL CAUSES are excluded — the FORM of the failure discriminates, not the fact of it.** "Port unreachable" is produced identically by a firewall DROP and by nothing listening there, and only timeout-vs-RST separates them; crediting the wrong cause certifies a rule that was never enforced.

**A reading taken from INSIDE the trust boundary cannot establish a property OF that boundary.** Public-ness, reachability and permission are properties of the *least*-privileged caller, so a credentialed probe answers a different question and answers it green: `gh repo view --json visibility`, `curl` carrying your session, `aws s3 ls` under your own role. Re-run the check unauthenticated, or as the least-privileged principal, and assert the complement — the thing that must stay closed has to fail the same probe.

**When a spec NAMES the metric, ask what the metric cannot see.** Satisfy it *and* measure the stronger thing directly — e.g. `scrollWidth === clientWidth` counts start-side padding only.

**A saved review/eval harness rots with no error signal.** Its pinned positions and golden answers describe files it does not own, go false when those are corrected, and then instruct N agents to flag the fix as a regression. A stale one runs clean. Re-read its embedded context against the target before every re-run.

### A status oracle answers from state that survives the breakage

**Never accept a success report from the thing under test, or from yourself — read the artifact.** A status field, health endpoint or summary line is computed from state that often outlives the failure, so it stays green while the work does not happen. **None of these emitted an error:**

| oracle | reported | while |
|---|---|---|
| `systemctl show -p Result` | `success` | the unit's dependency refused it and it never ran |
| Subsonic `ping.view` / `search3` | `status: ok`, full metadata, byte-identical to healthy | the library root did not exist and nothing could stream |
| `tailscale ping` | `pong … 3ms` | **all** IP traffic on the host was blocked — it is userspace disco over any available path, and never touches kernel routing or the firewall |
| a git **commit message** | an item-by-item verification | that change was absent from its own diff |

- **For anything path-mediated, read a payload byte.** Assert content-type and a byte count against the file on disk. Never a status code, a ping endpoint, or a metadata query — those are answered from an intact database or an intact process while the storage beneath them is wrong. HTTP 200 is not success: Subsonic returns 200 with the error in the body.
- **Beware the `nofail` shape.** Where a mount can be legitimately absent, every path-shaped check still resolves — against an empty directory on the root filesystem — so *all* observables pass and nothing works. That is why the rule keys on the payload rather than on the service.
- **READING THE ARTIFACT IS NOT ENOUGH WHEN THE ARTIFACT ALSO DECLARES CAPABILITIES.** Logs and tool output routinely carry, beside the record of what happened, a manifest of what the binary *could* do — a build banner, a capability dump, a codec or feature list. A substring match cannot tell the two apart, so the check goes green regardless and **can never go red**. Measured: grepping `h264_nvenc` in an ffmpeg transcode log passes whatever ran, because the banner also contains `--enable-libx264`; the discriminating artifact is the **output-stream metadata** (`encoder : … h264_nvenc`) plus absence of the rival codec **on the invocation line**. Ask: *is this string here because of what happened, or because of what is installed?* Then assert on the part that records the RUN. Beware the second-order version — a narrowed pattern (`' libx264'` with a leading space) that misses the banner by accident is still luck, not construction.
- **A FIX FOR A RACE IS NOT PROVEN BY THE OUTCOME IT PRODUCES.** When the defect is a race, the passing outcome is exactly what a *lucky* run produces with the bug still present — so the outcome cannot be the evidence, however clean it looks. Measured: a service's tailnet-only bind was read as fixed on a boot that had **no guard installed at all** (won by 3.99 s); the previous boot lost by 1.46 s with the identical unit. **Three arms, ascending in strength:** (1) the fix's **own log line**, ordered *before* the thing it guards — necessary, never sufficient; (2) a **non-zero wait** — if the guard returned in ~0 s the easy path ran and the race was never exercised, which is why restarting a service can never close a boot-race criterion; (3) an **independent process that hit the same failure inside the window** — the strongest arm and usually **free**, since something else on the box is normally racing the same resource and logging it (here, `syncthing` failing to bind the same address twice inside the guarded service's start window). A witness you did not construct cannot have been constructed to agree with you. With all three you may state the counterfactual quantitatively — measure the service's own fork→bind interval on the guarded run and compare against when the resource appeared — but **label it a counterfactual and never let it be the criterion.** The criterion is the measured outcome; the three arms are what license reading that outcome as *caused* rather than coincidental.
- **A multi-edit script that validates before writing is all-or-nothing.** One drifted anchor raises and discards every earlier successful edit in the same run; the natural response — fix that anchor, re-run — silently drops the rest, and the commit afterwards still succeeds with a message describing them. **Write per edit**, and **read `git show --stat` and the diff back against what you intended**, never the exit code. A failed `git add` on a nonexistent pathspec likewise stages *nothing* and does not stop the `git commit` chained after it — and the shape is general: **a destructive command chained after a check runs whatever the check printed**, unless it is conditioned on the check's exit status (`&&`, an `if`, or a separate invocation issued after reading the output). Measured 2026-09-02: a collision check printed `PRESENT`, the `mv` chained behind it with `;` ran anyway, and the earlier, larger part of a session transcript was replaced by its tail — no error, no recoverable copy. A check whose result nothing consumes is decoration.
- **During a PAUSED rebase, `git rev-parse HEAD` reports the UPSTREAM commit**, so the standard "verify the push landed by comparing `HEAD` to `origin/<branch>`" check prints *confirmed* while your commit sits unapplied in the rebase. The rejection was three lines earlier in the same output. Check `git status` for a rebase in progress, or compare against the commit you expected to create — never against a `HEAD` you have not confirmed is attached.

The general test underneath all of these: *could more than one true state of the world produce this same reading?* Counts and names fail it as proxies for identity; a status oracle fails it because the subject is reporting on itself.

### The installed artifact and the repo file are not the same file

**Never assume they are — and check WHICH way they differ.** Usually they are separate copies drifting with no error signal: diff by digest before believing any green result about deployed behaviour. But a SYMLINKED store inverts it: the checkout IS the install, so `git checkout` to *test* a branch silently downgrades every other skill, and a `core.hooksPath` hook cannot warn — it is itself branch state. Test by EXTRACTION (`git archive <ref> <dir> | tar -x -C <scratch>`) and digest-match against the branch blob.

### Assert the complement

For any "X must never happen" rule, also assert the nearby behaviour that must still work, pinned with its measured margin. A one-sided check is satisfied best of all by a **deleted feature**.

Blind spots the complement rule still misses:

- **A value nothing reads passes never-X and must-work together.** Grep for the production consumer and assert at that boundary. Producer + test only = inert.
- **A probe that samples before the system SETTLES measures timing, not the property** — and fails in the direction that looks like a real bug. Assert steady state first, and keep probe code byte-identical across compared runs.
- **One artifact answering a whole CLASS of inputs must be checked per SUB-CLASS, never one representative.** Partition the input domain by what the system does *differently* — and the HOST is part of that domain: a control run on a machine that structurally cannot produce the failure is not a control (a skip branch "passed" only because macOS lacks the `/mnt` that broke it on Linux).
- **Partition by reachable STATE as well as input.** A snapshot gate over a stateful artifact only tests the state it captured, and passes every rule that needs an interaction to apply.

## II. Absence claims

An absence claim — "nothing owns X", "dead code", "unmanaged", "untested", "not in the repo" — asserts over the WHOLE project, so **your review scope silently becomes part of the claim**. A positive claim survives anything outside the file you read; a negative one does not.

- **Put the intent layer in scope before filing one.** Read the board/tracker first: a review scoped to code + architecture docs converts *planned* into *broken*, most confidently on active work. Solo review as much as fan-out.
- **The filesystem is a second invisible layer.** Read `.gitignore` and run `git check-ignore -v` before filing "not in the repo" — *not tracked* and *not present* are different claims.
- **Settle server/runtime-state questions with a live probe, never a repo read.**
- **Two passes agreeing is not corroboration when both used the same instrument.**
- **A PEER AGENT'S claim about a PER-MACHINE artifact (`~/.claude`, `~/.config`, service units, mount points) carries ITS machine as unstated scope in EITHER polarity.** A positive travels no better than a negative; re-run it on yours.
- **The same asymmetry governs absence claims asserted in TESTS.** Enumerate everything that WRITES the resource and drive the assertion through each writer — a claim exercised only through its owning feature checks the one door that was never the threat.

**Verify a large deletion with a set-difference, not a read-through.** When content is cut or relocated in bulk, "nothing load-bearing was lost" is an absence claim over everything you removed. Diff the token sets — old file vs. new file *plus wherever content moved* — and read the residue. The failure a read-through cannot see is a surviving clause that refers to something you deleted: it parses, it reads fine, and it now points at nothing.

In Claude Code, `grep` is a shell function execing the harness binary as `ugrep … -I --ignore-files`, so a grep NEGATIVE is unreliable three ways: one NUL byte makes the whole file silently unsearchable (no output, exit 1, like a real miss; `file` saying `data` is the tell); `--ignore-files` skips ignored paths; and over raw HTML a tag-bounded pattern misses tag-split phrases (`textutil -convert txt -stdout page.html | grep …` first). Never a false positive. Use `command grep`, `awk`, or `/usr/bin/rg` whenever a negative is load-bearing — **and that is necessary, not sufficient**: even `-a` reads 0 on a compressed blob. See below.

### A FLAG is a guess about the CAUSE of blindness; a CONTROL detects blindness whatever the cause

**Prove the pipeline finds a known-present needle, then believe an absence.** Measured 2026-08-31, twice in one session, in unrelated mechanisms:

- **Compression defeats every text reader, and `-a` does not help.** Checking whether a service still advertised deleted files, `strings <cache> | command grep -c '<subject>'` returned **0** — the expected answer. The control returned **0** for a directory browsed minutes earlier. The file was **zlib behind an 8-byte header**; `command grep -a` scored 0 for the control, for `Music`, and for `.mp3`. `-a` answers NUL bytes and says nothing about compression, encryption, UTF-16, or a format that never stored the string.
- **`cmd | grep X || echo "no X"` reports clean when `cmd` FAILS.** A teardown check for leftover routes printed *no blackhole routes* because `ip netns exec` needed root and the command errored; `2>/dev/null` removed the only evidence, and **the failure message and the clean result are the same string**. Never let the ABSENCE of output be the evidence — print the table and read it, or check `cmd`'s own exit status.

**The flag list is unbounded and every entry on it is a fresh way to be confidently blind; the control is one line.** That is why the remedy is a control and not a longer flag list.

**⚠ RIGHT BY ACCIDENT IS WORSE THAN WRONG, and it is what this rule exists to stop.** A wrong answer eventually collides with something. A *correct-sounding* answer from a dead instrument never prompts a re-check and hardens into the record. **Agreement between a detector and a prior belief is evidence for neither until the detector has been shown capable of disagreeing.**

**⭐ Close-out checks are the highest-risk place for a dead instrument.** Teardown sweeps, final verifications and "confirm it's clean before we finish" checks all expect the answer *clean* — so a broken check and a passing one are indistinguishable — and they are the checks **nobody ever re-runs**. A close-out check is trusted more and scrutinised less than any other kind. **Put the control on the LAST check, not just the first.** Both instances above bit at exactly that moment.

### An absence or completeness claim carries the SCOPE OF THE INSTRUMENT that produced it

...and that scope vanishes from the sentence unless it is written in. Measured 2026-08-31: a peer enumerated ticket branches with `git branch -r` in its own checkout and reported *"all three fully contained in main; deleting them is safe."* A fourth branch existed — **local-only, on a different machine, with 11 commits that existed nowhere else.** `git branch -r` on one machine structurally cannot see it. The list was scoped to one host's remote refs and written as though it were global; acting on it would have destroyed the commits.

- **Name the instrument's reach inside the claim.** "These are the branches" is a claim about the project; `git branch -r` on one machine cannot support it.
- **Prefer the authoritative query over the cached one.** `git ls-remote` asks the remote; `git branch -r` reads a local cache of a past fetch, and can show branches that no longer exist or miss ones that do.
- **Re-verify a peer's completeness claim before any destructive act.** A correction or an all-clear from a peer is itself an upstream fact to be re-verified, and a destructive action is exactly where that discipline pays.

## III. Fan-out

**Blindspot the SOURCE before any 1:1 mechanical fan-out** (spec→tasks, doc-rows→board, schema→migrations). A hole in the source replicates into all N outputs, and an output-review is structurally blind to a deliverable the source never named. Source-pass and output-pass catch different failure modes — run both.

Discovery-side sibling: before authoring a taxonomy, catalog, or checklist from intuition, sweep the real corpus first. A from-memory seed systematically undercounts.
