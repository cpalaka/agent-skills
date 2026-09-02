---
name: spec-review
description: Fresh-context adversarial review of a spec before it fans out into tickets. Run between /to-spec and /to-tickets.
disable-model-invocation: true
---

# Spec review

Review the spec with fresh-context subagents before /to-tickets fans it out. The spec is the source of a 1:1 mechanical fan-out: a hole in it replicates into every ticket, each /implement session trusts its ticket as ground truth, and /code-review checks the diff against the spec — so a spec error is the one class of error nothing downstream catches.

You wrote the spec, so you read what you meant, not what it says. Every reviewer runs in a fresh context; your window stays unbroken for /to-tickets.

The same review fits any artifact about to be mechanically fanned out — a spec collapsed from a wayfinder map, an externally supplied spec, a schema feeding migrations.

**Skip when** the work is going straight to /implement in this session: with no fan-out and no fresh session trusting the document, the review has nothing to protect.

## 1. Gather the inputs

- **Spec path.** Reviewers read it cold from disk.
- **Goal statement.** One paragraph stating what the work must achieve. It must come from outside the spec — the grilling thread, the originating ticket, or the user. A goal derived from the spec turns the blindspot sweep into checking the document against itself; if the spec is the only source, stop and ask the user for a goal.
- **Fence.** The decisions settled during grilling (architecture choices, scope cuts, trade-offs), plus whatever the spec's out-of-scope section names.

**Done when:** all three exist and the goal's provenance is confirmed independent of the spec.

## 2. Dispatch the reviewers

Invoke `multi-agent-policy` first — this is a fan-out, and the model/effort pins come from there.

Launch three subagents in parallel. Each receives the fence and only the inputs its charter names; pass nothing else from this thread.

Fence text for every reviewer:

> The decisions in this spec were made deliberately by the user and are fixed constraints. In scope: completeness, internal consistency, unverified premises, ambiguity. Out of scope: whether the decisions are good. Report only in-scope findings.

**Blindspot sweep** (gets: goal statement, fence): From the goal alone, derive what a complete spec must cover — deliverables, states, failure modes, edge cases — before opening the spec. Then read the spec and diff the two lists. Report only what the spec never names.

**Reuse verification** (gets: spec path, repo access): Tag every claim the spec makes about existing code [reuse]/[extend]/[new]. Grep/read-verify each [reuse] and [extend] claim against the source: the thing exists, does what the spec says, supports what the spec assumes. Verdict per claim: VERIFIED with file:line, or FAILED with what the source actually says. Specs over-claim reuse; that is the failure mode this reviewer exists to catch.

**Cold read** (gets: spec path): Read as an implementer with no access to any prior discussion. List every point where proceeding requires a guess or a question — each is a hole a fresh /implement session will fill on its own. Name them precisely; propose no answers.

**Done when:** all three reports are back.

## 3. Triage the findings

A reviewer's finding is itself an unverified upstream fact. Disposition every finding into exactly one of:

- **Fix.** Confirmed against the spec or the source. Re-verify FAILED reuse verdicts against the code before accepting them; a correction can be wronger than the claim it replaced.
- **Reject.** Record why. Check "missing" items against the fence and the out-of-scope section first: deliberately excluded is a decision, not a hole.
- **Escalate.** Anything decision-shaped goes to the user as a question. Deciding it yourself breaks the fence from the inside.

**Settle, don't defer.** A premise the spec itself flags as unverified is SETTLED NOW with a throwaway probe — never written into a ticket as an assumption. An assumption inside a ticket is a premise nobody re-checks; the ticket reads as decided. A probe up front costs less than a slice built on a false premise and discovered mid-implementation.

**Done when:** every finding across all three reports carries a disposition, and no unverified premise survives into the revised spec.

## 4. Revise and gate

Apply the fixes to the spec, persist it to the plan doc, and report to the user: what changed, what was rejected and why, what needs their answer. /to-tickets runs on the revised spec, after their go-ahead.

**Hand /to-tickets its blocking edges.** A spec constraint of the form "decided in the artifact this ticket produces" is a BLOCKING edge, not a note on the dependent ticket — flag every one you find in the revised spec so the slice order falls out of it rather than being reconstructed later.

_(Both rules were promoted to the `to-tickets` skill and silently clobbered by an npx update (measured 2026-07-27). They live here because this skill is hand-authored and upstream cannot overwrite it.)_
