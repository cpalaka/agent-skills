---
name: api-rate-limiting
domain: api-infrastructure
tags: [backend, capacity, public-api]
mode: scoreboard
archive: ~/tournaments
claimVerify: true
qa: true

# counts
candidateCount: 4
judgeCount: 3
researchBriefCount: 4
claimVerifyLensCount: 3

# keys (lens, judge, axis)
researchBriefKeys: [algorithms, distributed-state, client-experience, ops-burden]
judgeKeys: [fairness, operability, client-experience]
axisKeys: [fairness, operability, client-experience]
candidateNames: [Token Bucket at the Edge, Sliding Window in Redis, Concurrency Cap, Control (Fixed Window)]
---

# Rate-Limiting Strategy Tournament

Pick a rate-limiting strategy for a public read-heavy HTTP API that is starting to be abused by a
handful of clients. Full pipeline: web-grounded research → adversarial claim verification (3 lenses
per claim) → 4-candidate scoreboard tournament (3-judge panel, 0–10 each) → synthesis grafting the
winner plus the best runner-up ideas → QA red-team + patch.

This is a **worked example of the spec format**, not a recommendation. Every field below is the
kind of thing the §3 interview elicits; copy the shape, replace the content.

## Domain Block

**THE SYSTEM (what is being rate-limited):**

A public JSON API, roughly 40 endpoints, ~95% GET. Steady state is about 3,000 requests/second
across 12 stateless application instances behind a load balancer. Authenticated clients present an
API key; a small fraction of traffic is unauthenticated and keyed by source address. Median
response time is 40 ms; the slowest endpoint is a search route at ~600 ms p99 because it fans out
to a second service.

There is a Redis cluster already in the path, used today only for response caching. There is no
API gateway product in front of the load balancer.

**THE PROBLEM:**

Four API keys out of about 9,000 generate 60% of load. They are not malicious — they poll a
changes endpoint in a tight loop instead of using its cursor. When one of them retries a failure
storm, the search route saturates the downstream service and every other client sees timeouts. The
team has no lever short of revoking a key.

**CONSTRAINTS:**

- HARD: no new infrastructure component. The strategy must run inside the existing application
  instances and/or the existing Redis cluster.
- HARD: a limited client must receive `429` with a `Retry-After` header, and the limit state must
  be visible to the client before it is exceeded (a header, per the draft `RateLimit-*` fields).
- HARD: the limiter's own added latency must stay under 5 ms at p99, and it must fail **open** —
  if Redis is unreachable, requests are served, not dropped.
- HARD: burst tolerance is required. Well-behaved clients legitimately fire ~50 requests when a
  page loads; a strategy that punishes that is a failure regardless of its other merits.
- SOFT: prefer a strategy whose limit a client can reason about from the headers alone, without
  reading documentation.
- SOFT: the team is four people and on-call is shared. Operational surface area is a real cost.
- OUT OF SCOPE: authentication, quota billing, and per-endpoint pricing tiers. Assume one limit
  policy per key, applied across all endpoints.

## Candidate Fields

Each candidate is structured with the following fields (the `evaluated-option` archetype):

- **name** (string) — short label for leaderboard display (e.g. "Token Bucket at the Edge")
- **thesis** (string) — one-sentence framing of the candidate's core design bet
- **algorithm** (string) — the counting/admission algorithm, its parameters, and where the state
  lives; include the exact Redis operations or in-process data structure
- **failureBehaviour** (string) — what happens when Redis is slow, partitioned, or empty; how the
  fail-open requirement is met; what a cold start looks like
- **clientContract** (string) — the exact response headers a client sees under and over the limit,
  and what a client must do to stay inside it
- **changesFromToday** (string array) — explicit bulleted diff against the current no-limiter
  system; every new moving part called out
- **designMarkdown** (string) — the complete proposal in markdown: parameters with numbers, the
  request path step by step, rollout plan, and the reasoning behind each choice

All candidate fields are required. `designMarkdown` is the rich freeform body; the others are
structured comparables the judges use to locate the key decisions quickly.

Coherence note: every judge axis maps to at least one structured field — fairness →
`algorithm` + `changesFromToday`; operability → `failureBehaviour` + `changesFromToday`;
client-experience → `clientContract`.

## Context and Research Briefs

Four parallel web-grounded research agents, each returning `{summary, findings[], claimsToVerify[]}`.

**algorithms** — distributed-systems researcher. Compare fixed window, sliding window log, sliding
window counter, token bucket, leaky bucket, and concurrency limiting (in-flight cap) on: burst
tolerance, boundary effects at window edges, memory per key, and arithmetic cost per request. Give
the concrete failure each one is known for, not just its definition. Flag any claim about
throughput or memory that rests on a single vendor's blog post.

**distributed-state** — engineer who has run shared counters across a fleet. Research how a limiter
keeps state consistent across 12 instances: Redis Lua scripts for atomic check-and-decrement,
`INCR` with expiry, `CL.THROTTLE`-style modules, local-approximate counters with periodic
reconciliation, and consistent-hashing a key to one owning instance. For each: added latency,
behaviour under a Redis failover, and what "fail open" actually costs. Flag claims about
round-trip latency that omit the network they were measured on.

**client-experience** — API-design specialist. Research what limited clients actually do: which
response headers well-behaved SDKs read, whether `Retry-After` is honoured in practice, how the
draft `RateLimit-*` header fields are specified, and how retry storms form when every limited
client wakes at the same instant. Cover jitter and backoff as an obligation the *server* can
encourage through its headers. Flag any claim about client library behaviour that you cannot tie to
a specific library's source or documentation.

**ops-burden** — SRE optimizing for a four-person on-call rotation. Deliver a RANKED list of the
operational costs each strategy family imposes: parameters to tune, dashboards and alerts to
create, the shape of a misconfiguration incident, and how each strategy is rolled out safely
(shadow mode, per-key overrides, kill switch). Include what it takes to answer "why was this
client limited?" three days later.

All four run in parallel at `effort: high`. Claims from all four are extracted and deduplicated,
capped at 12 for the verify stage.

## Claim-Verify Lenses

Three adversarial lenses run in parallel against every extracted dubious claim. Each returns
`{verdict: confirmed|refuted|partly|unknown, reasoning, correctedStatement, keyEvidence,
confidence: high|moderate|low}`. Consensus: ≥2 `refuted` → REFUTED; ≥2 `confirmed` → CONFIRMED;
otherwise NUANCED.

1. **primary sources — specifications, RFCs and drafts, and library source code.** Cite the actual
   document or file. Be adversarial: try to find the sentence that contradicts the claim, and note
   when a claim describes a draft as though it were a ratified standard.

2. **an operator giving a production reality-check.** Test the claim against what happens on a real
   fleet under load. Does the benchmark's assumption hold when the cache is cold, the network is
   congested, or the key space is 9,000 wide instead of 10?

3. **a skeptical myth-buster hunting for overstatement or a hidden variable.** Assume the claim is
   probably wrong. Look for the vendor incentive, the missing units, the benchmark run on one
   machine, and the "X is always faster than Y" that is true only in one regime.

The verified digest is passed to every downstream stage. `[REFUTED]` claims are flagged as myths to
avoid in every generation prompt; `[NUANCED]` claims carry their caveats forward.

## Generation Candidates

Four candidates generated in a pipelined scoreboard (generate → judge in sequence per candidate,
all four in parallel). Each uses the full shared context: system description + constraints +
verified digest.

**Token Bucket at the Edge** — Per-key token bucket evaluated in-process on each application
instance, with buckets replenished from a Redis-held allowance on a short interval. Bets that burst
tolerance is the binding requirement and that approximate fairness is worth sub-millisecond
admission decisions. Must show its work on how 12 instances split one allowance without either
over-admitting badly or starving a client that lands on a cold instance.

**Sliding Window in Redis** — Per-key sliding window counter in a single atomic Redis Lua script.
Bets that exactness and explainability beat latency: one round trip, one number, a header a client
can trust. Must confront the p99 latency budget and the fail-open path honestly.

**Concurrency Cap** — Limit in-flight requests per key rather than requests per unit time, with a
small extra cap dedicated to the expensive search route. Bets that the real failure is downstream
saturation, not request count, and that a concurrency limit is the only strategy that directly
bounds it. Must explain what a client sees when it is limited by concurrency rather than by rate,
and whether that can be expressed in the required headers at all.

**Control (Fixed Window)** — A disciplined CONTROL: per-key fixed window counter, `INCR` with a
60-second expiry, one parameter, roughly 20 lines of code. Deliberately accepts the boundary
effect (up to 2× the limit across a window edge). This baseline tests whether the other three EARN
their complexity. If the control wins, that is the honest answer.

Each generation agent runs at `effort: high`. Output is the full CANDIDATE_SCHEMA.

## Judges

Three judges score each candidate 0–10 through their lens only, in parallel per candidate — the scale
is `SCORE_SCALE`, set **once** in the JUDGE_SCHEMA block, and the schema's `minimum`/`maximum`, the
rubric text and the stage's validation all read it (widen it there and nowhere else; a schema pinned to
a stale bound fails every ballot into `dropped` with no readable reason). Final
score = mean of the **valid** ballots (a candidate with none scores `null`, never `0`). Scoreboard
sorted descending; winner = highest mean, ties broken to the lower index, and any dropped or voided
ballot sets `needsAdjudication` so the result withholds the winner until a human has read the
reconciliation.

**Judge: fairness** (`key: fairness`)
Persona: Distributed-systems engineer who has debugged a limiter that admitted 3× its configured
rate.
Rubric: Cares ONLY whether the limit the design claims is the limit the system actually enforces,
across 12 instances, under failover, and at a window boundary. Rewards a design that states its
own error bound. Penalizes hand-waving about "eventually consistent" counters, any strategy whose
worst case is unbounded, and burst handling that punishes the legitimate 50-request page load.

**Judge: operability** (`key: operability`)
Persona: SRE on a four-person shared rotation.
Rubric: Cares about the 3 a.m. version of this system: how many parameters must be tuned, what the
misconfiguration incident looks like, whether it fails open as required, whether there is a kill
switch, and whether "why was this client limited?" is answerable three days later from what the
design records. Heavily penalizes new moving parts and any dependency the HARD constraints forbid.

**Judge: client-experience** (`key: client-experience`)
Persona: Developer integrating against this API from a third-party SDK.
Rubric: Cares whether a competent client can stay inside the limit using only the response headers,
whether the `429` contract is honest and actionable, and whether the design actively discourages
retry storms (jitter, spread expiry) rather than merely surviving them. Penalizes limits that
cannot be expressed in the required headers and anything that requires reading documentation to
predict.

Judge schema output: `{persona, candidate, score, breakdown, critique, mustFix, wouldChoose}`. All
fields required except `breakdown`. `persona` and `candidate` are the **identity echo**: the judge
repeats its assigned role and the candidate name it was given, verbatim, and the scoreboard stage
buckets any ballot whose echo, type or scale disagrees with the assignment as `errored` — never
tallied. Judges see the shared context plus the candidate's `designMarkdown`.

## Synthesize Spec

Input: all four judged candidates sorted best-to-worst; the winner's `designMarkdown`; the full
shared context including the verified digest.

Task: start from the WINNER, GRAFT IN the best verified ideas from the others, and resolve EVERY
judge `mustFix`. The final design MUST satisfy every HARD constraint explicitly, state its own
enforcement error bound, and name the rollout order. Where a decision rests on a verified finding,
say so briefly; where it rests on a REFUTED claim, it must not be there at all.

Output schema `SYNTH_SCHEMA`:

- `summaryMarkdown` — the complete design: parameters with numbers, the request path step by step,
  header contract, failure behaviour, rollout plan, and a "what changed vs. today & why" section
- `parametersMarkdown` — the tunable dials, each with its default, its safe range, and the symptom
  that says it is set wrong
- `changeLog` — array of `{change, why, verifiedBy}` tracing each departure to a verified finding
- `graftedFrom` — the candidate names that contributed grafted ideas

Runs at `effort: max` as the single most important agent in the pipeline.

## QA Checklist

A two-step red-team + patch stage, run sequentially after synthesis.

**Red-team agent** (`effort: high`) — check HARD for:

1. HARD-constraint compliance, one by one: no new infrastructure; `429` + `Retry-After` + limit
   headers; under 5 ms p99 added latency; fails open; tolerates a 50-request burst.
2. Does the stated enforcement bound survive a Redis failover and a cold instance?
3. Any parameter given without units, or a number that contradicts another number in the document.
4. Retry-storm safety: does anything in the design cause every limited client to wake at once?
5. Does any claim in the document contradict a `[REFUTED]` or `[NUANCED]` verified finding?
6. Is every judge `mustFix` actually resolved, or merely acknowledged?

Output schema `QA_SCHEMA`: `{gatesPassed, issues[], verdict}`. Each issue: `{severity, issue, fix}`.

**Patch agent** (`effort: medium`) — apply the QA fixes, changing as LITTLE as possible and
preserving structure, formatting, and voice. Returns only the corrected full design markdown.

The patched design replaces `summaryMarkdown` in the result; the unpatched version is preserved for
diffing.
