---
name: spec-review
description: Fresh-context adversarial review of a spec before it fans out into tickets. Run between /to-spec and /to-tickets.
disable-model-invocation: true
---

# Spec review

A spec is the source of a 1:1 fan-out: a hole in it replicates into every ticket, each
/implement-run session trusts its ticket as ground truth, and /code-review checks the diff against
the spec — so nothing downstream catches a spec error. You wrote it and read what you meant;
fresh-context reviewers read what it says, and your window stays unbroken for /to-tickets.

**Skip when** the work goes straight to implementation in this session: with no fan-out, the
review protects nothing.

## 1. Gather the inputs

- **Spec path.** Reviewers read it cold from disk.
- **Goal statement.** One paragraph of what the work must achieve, taken from outside the spec —
  the grilling thread, the originating ticket, or the user. A goal derived from the spec turns the
  blindspot sweep into checking the document against itself; if the spec is the only source, ask
  the user for one.
- **Fence.** The decisions settled during grilling (architecture, scope cuts, trade-offs), plus
  the spec's out-of-scope section.

**Done when:** all three exist and the goal's provenance is independent of the spec.

## 2. Dispatch the reviewers

Launch three in parallel, each as the `code-reviewer` seat. Each receives the fence text and only
the inputs its charter names — nothing else from this thread.

> The decisions in this spec were made deliberately by the user and are fixed constraints. In scope: completeness, internal consistency, unverified premises, ambiguity. Out of scope: whether the decisions are good. Report only in-scope findings.

**Blindspot sweep** (gets: goal statement, fence): From the goal alone, derive what a complete
spec must cover — deliverables, states, failure modes, edge cases — before opening the spec. Then
read the spec and diff the two lists. Report only what the spec never names.

**Reuse verification** (gets: spec path, repo access): Tag every claim the spec makes about
existing code [reuse]/[extend]/[new]. Grep/read-verify each [reuse] and [extend] claim against the
source: the thing exists, does what the spec says, supports what the spec assumes. Verdict per
claim: VERIFIED with file:line, or FAILED with what the source actually says. Specs over-claim
reuse; that is the failure mode this reviewer exists to catch.

**Cold read** (gets: spec path): Read as an implementer with no access to any prior discussion.
List every point where proceeding requires a guess or a question — each is a hole a fresh
implementation session will fill on its own. Name them precisely; propose no answers.

## 3. Triage the findings

A reviewer's finding is itself an unverified upstream fact. Give every finding exactly one
disposition:

- **Fix.** Confirmed against the spec or the source. Re-verify a FAILED reuse verdict against the
  code before accepting it; a correction can be wronger than the claim it replaced.
- **Reject.** Record why. Check a "missing" item against the fence and the out-of-scope section
  first: deliberately excluded is a decision, not a hole.
- **Escalate.** Anything decision-shaped goes to the user as a question. Deciding it yourself
  breaks the fence from the inside.

**Settle every premise now.** A premise the spec itself flags as unverified gets a throwaway
probe before any ticket exists. Written into a ticket as an assumption, it reads as decided and
nobody re-checks it.

**Execute every acceptance criterion.** A criterion that names a literal output, a command's
result or a state the artifact must reach predicts a system that exists now — run it and read
what comes back. Reading it confirms only that it is plausible, and plausible is what a defective
criterion looks like: on one ticket (2026-09-14) execution caught all five of eleven criteria that
were defective, and four review seats reading them caught none. The shapes it caught:

- unsatisfiable by construction — the artifact must name a value that exists only after it is
  written (a commit cannot contain its own SHA);
- a quoted string the tool does not emit;
- a query ("the lowest open ticket") that returns something else against the live tracker;
- an absence asserted through an instrument blind to the shape it asserts about.

**Done when:** every finding across all three reports carries a disposition, and no unverified
premise survives into the revised spec.

## 4. Revise and gate

Apply the fixes, persist the spec to the plan doc, and report to the user: what changed, what was
rejected and why, what needs their answer. /to-tickets runs on the revised spec after their
go-ahead. A real finding outside this spec's fence gets an owner under the project's tracker
convention before the session ends.

**Hand /to-tickets its blocking edges.** A constraint of the form "decided in the artifact this
ticket produces" is a blocking edge, not a note on the dependent ticket — flag every one in the
revised spec so the slice order falls out of it.
