# Stage Catalog

## Binding Contract (the key to safe assembly)

Every stage snippet reads/writes these exact bindings, so composed stages wire together. Later tasks depend on these names being identical.

| Produced by | Binding | Type |
|---|---|---|
| domain block | `DOMAIN` | `string` |
| context stage | `briefs` | `Record<string,string>` |
| claim-verify stage | `verifiedDigest` | `string` (assembler threads this into the SHARED_* prompt strings by hand — not auto-referenced by downstream snippet bodies) |
| generate stage | `candidates` | `Candidate[]` |
| generate stage | `seedIndices` | `number[]` |
| render helpers | `renderConcept(c)`, `renderIndexed(idxs)` | fns → `string` |
| filter stage | `kept` | `number[]` (indices) |
| filter stage | `totals` | `Map<number,number>` |
| filter stage | `ranked` | `number[]` (indices, desc) |
| filter stage (bracket mode) | `bracket` | `number[]` (indices, seeded) |
| filter stage (scoreboard mode) | `shortlist` | `number[]` (indices) |
| tournament/bracket | `champion`, `runnerUp` | `number` (index) |
| tournament/bracket | `matchLog` | `object[]` |
| tournament/scoreboard | `board` | `{index,name,score,votesSent,votesReturned,dropped,errored,generationFailed,stageThrew,...}[]` (desc; `score` is `null`, never `0`, when no ballot was valid. The three vote buckets are DISJOINT: `votesSent = votesReturned + dropped + errored.length`, so `votesReturned` counts only ballots that passed validation) |
| tournament/scoreboard | `winner` | `number` (index; ties break to the lower index. `null` only when the board is empty — every consumer that indexes `candidates[winner]` must handle that) |
| tournament/scoreboard | `needsAdjudication` | `boolean` (any dropped/errored ballot, any unscored candidate, a candidate lost to a throwing stage, a tie at the top, or an empty electorate/shortlist) |
| tournament/scoreboard | `reconciliation` | `object[]` (one row per shortlist entry, including candidates whose stage threw: `votesSent`/`votesReturned`/`dropped`/`errored`/`generationFailed`/`stageThrew`) |
| verify-champion | `skeptics` | `object[]` |
| verify-champion | `fatalCount` | `number` |
| synthesize | `report` (text mode) or `synth` (schema mode) | `string`/`object` |
| qa | `qa`, `patched` | `object`, `string` |

Each snippet is valid JS with default slot values; the skill replaces `// FILL:`-marked slots. Compose only the stages the spec needs, in pipeline order.

The snippets were normalized out of real tournament scripts. Those scripts are **environment-specific** — local corpus paths, one domain's field names, one machine's layout — so they are not shipped here and nothing in this catalog depends on them. Read `reference/example-spec.md` for the end-to-end worked example, and `reference/fixtures/` for the tiny scripts `lint.mjs` is calibrated against (`node reference/lint.mjs --selftest` runs the whole directory).

---

## Meta Builder

```js
export const meta = {
  name: 'my-tournament', // FILL: tournament name (kebab-case slug)
  description: 'A generate-and-filter tournament', // FILL: one-sentence description of what is being decided
  phases: [
    { title: 'Context', detail: 'distill background research' }, // FILL: adjust or add phases as needed
    { title: 'Generate', detail: 'produce candidates' },
    { title: 'Filter', detail: 'dedup, screen, rank' },
    { title: 'Tournament', detail: 'bracket or scoreboard' },
    { title: 'Verify', detail: 'adversarial skeptic attack on champion' },
    { title: 'Synthesize', detail: 'final recommendation' },
  ],
}

// MODEL TIER PINS — every stage below references one of these consts, never a bare alias.
// Resolve each ID by PROBE at assembly time, not from memory: a CLI short alias (`opus`, `fable`)
// can lag a release and keep serving the prior generation while every rule still reads correct
// (measured 2026-07-24). Probe with `claude -p --output-format json` and read `canonicalModel`.
// `lint.mjs` ERRORs on a bare alias anywhere in the emitted script.
const WORKHORSE = 'claude-opus-5' // FILL: re-probe at assembly time
const SCARCE = 'claude-fable-5'   // FILL: re-probe; used only by SYNTH_MODEL, see Synthesize Stage
```

---

## Schema Builders

### buildCandidateSchema

The `fields` argument is a plain object mapping field name to `{ type, description }` (same shape as JSON Schema property definitions). The function returns a `CANDIDATE_SCHEMA`-equivalent wrapping those fields in an array under the key `candidates` — the binding-contract name, so downstream stages wire up unchanged.

```js
// FILL: replace defaultFields with the field set appropriate for your domain
const defaultFields = {
  name: { type: 'string' },
  premise: { type: 'string', description: '1-2 sentence elevator pitch incl. theme/tone' }, // FILL: adjust description
  core_loop: { type: 'string', description: 'the moment-to-moment loop and how it evolves' }, // FILL: rename/remove if not applicable
  hook: { type: 'string', description: 'the single memorable moment + positioning' }, // FILL: adjust description
  scope_notes: { type: 'string', description: 'rough effort sanity check' }, // FILL: adjust description
  risks: { type: 'string', description: 'top 2-3 ways this fails' }, // FILL: adjust description
}

function buildCandidateSchema(fields) {
  return {
    type: 'object',
    properties: {
      candidates: {
        type: 'array',
        items: {
          type: 'object',
          properties: fields,
          required: Object.keys(fields),
        },
      },
    },
    required: ['candidates'],
  }
}

const CANDIDATE_SCHEMA = buildCandidateSchema(defaultFields)
```

---

### KEEP_SCHEMA

Consumed by the filter stage's dedup agent.

```js
const KEEP_SCHEMA = {
  type: 'object',
  properties: {
    keep: { type: 'array', items: { type: 'integer' }, description: 'indices of concepts to keep' },
    notes: { type: 'string', description: 'what was merged/killed and why, briefly' },
  },
  required: ['keep', 'notes'],
}
```

---

### SCORES_SCHEMA

Consumed by the filter stage's per-axis screeners.

```js
const SCORES_SCHEMA = {
  type: 'object',
  properties: {
    scores: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          index: { type: 'integer' },
          score: { type: 'number', description: '0-10, use the full range' },
          reason: { type: 'string', description: 'one sentence' },
        },
        required: ['index', 'score', 'reason'],
      },
    },
  },
  required: ['scores'],
}
```

---

### MATCH_SCHEMA

Consumed by the bracket-mode head-to-head judges.

```js
const MATCH_SCHEMA = {
  type: 'object',
  properties: {
    winner: { type: 'string', enum: ['A', 'B'] },
    reason: { type: 'string', description: '2-3 sentences: the decisive factor, incl. any fatal flaw in the loser' },
  },
  required: ['winner', 'reason'],
}
```

---

### JUDGE_SCHEMA

Consumed by the scoreboard-mode judge panel. The scale and the two domain-flavoured fields are FILL slots — rename or swap them for your domain's scoring axis.

`persona` and `candidate` are the **identity echo**: the scoreboard stage compares both against the assignment before the score is allowed to move a mean, so a payload that arrives in the wrong slot is bucketed instead of counted. Keep them required, and keep `score`'s scale identical to the stage's `SCORE_SCALE`.

```js
const JUDGE_SCHEMA = {
  type: 'object',
  properties: {
    persona: { type: 'string', description: 'YOUR assigned role, echoed verbatim' },
    candidate: { type: 'string', description: 'the CANDIDATE NAME you were given, echoed verbatim' },
    score: { type: 'number', minimum: 0, maximum: 10, description: '0-10 score from this judge\'s perspective' }, // FILL: adjust scale/name (a wider scale, e.g. 0-50, spreads a clustering panel) — keep `minimum`/`maximum` in step with SCORE_SCALE
    breakdown: { type: 'string' },
    critique: { type: 'string' },
    mustFix: { type: 'string' }, // FILL: rename to match your domain's critical-issue label
    wouldChoose: { type: 'boolean' }, // FILL: rename to your domain's adoption question, or remove
  },
  required: ['persona', 'candidate', 'score', 'critique', 'mustFix', 'wouldChoose'],
}
```

---

### SKEPTIC_SCHEMA

Consumed by the verify-champion skeptics. **Calibration pin
(measured 2026-08-27, SKILL.md §5 item 9):** prefer widening `severity` to ≥4 tiers (`fatal`,
`near-fatal`, `serious-fixable`, `minor`) and force discrimination in the skeptic prompt — a run
of 15 skeptics returned a uniform `serious` that hid two near-refutations behind `fatalCount=0`.

```js
const SKEPTIC_SCHEMA = {
  type: 'object',
  properties: {
    refuted: { type: 'boolean', description: 'true if the concept has a FATAL flaw through your lens' },
    severity: { type: 'string', enum: ['fatal', 'serious', 'minor'] },
    concerns: { type: 'array', items: { type: 'string' } },
    fixes: { type: 'array', items: { type: 'string' }, description: 'concrete mitigations if any' },
  },
  required: ['refuted', 'severity', 'concerns', 'fixes'],
}
```

---

### VERDICT_SCHEMA

Used in the claim-verify stage to produce `verifiedDigest`.

```js
const VERDICT_SCHEMA = {
  type: 'object',
  properties: {
    verdict: { type: 'string', enum: ['confirmed', 'refuted', 'partly', 'unknown'] },
    reasoning: { type: 'string' },
    correctedStatement: { type: 'string' },
    keyEvidence: { type: 'string' },
    confidence: { type: 'string', enum: ['high', 'moderate', 'low'] },
  },
  required: ['verdict', 'reasoning', 'correctedStatement', 'keyEvidence', 'confidence'],
}
```

---

### SYNTH_SCHEMA

A domain-neutral synthesis output matching the binding contract (`synth` → synthesize output object). The structural pattern is: one primary output field, one or more domain-specific dial/parameter fields (FILL slots), a changelog, and the sources grafted from.

```js
const SYNTH_SCHEMA = {
  type: 'object',
  properties: {
    summaryMarkdown: { type: 'string', description: 'the final synthesized recommendation or output' }, // FILL: rename to your domain's primary deliverable
    parametersMarkdown: { type: 'string', description: 'key tunable parameters or dials for the output' }, // FILL: rename, split into several dial fields, or remove
    changeLog: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          change: { type: 'string' },
          why: { type: 'string' },
          verifiedBy: { type: 'string' },
        },
        required: ['change', 'why'],
      },
    },
    graftedFrom: { type: 'array', items: { type: 'string' } }, // FILL: remove if not applicable
  },
  required: ['summaryMarkdown', 'changeLog'],
}
```

---

### QA_SCHEMA

A domain-neutral QA shape matching the binding contract (`qa` → object): domain gate booleans (FILL slots — expand `gatesPassed` into one named boolean per hard gate), an issues list with severity/issue/fix, and a verdict string.

```js
const QA_SCHEMA = {
  type: 'object',
  properties: {
    gatesPassed: { type: 'boolean', description: 'true if all domain-specific hard gates pass' }, // FILL: expand into one named boolean per hard gate in your domain
    issues: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          severity: { type: 'string' },
          issue: { type: 'string' },
          fix: { type: 'string' },
        },
        required: ['severity', 'issue', 'fix'],
      },
    },
    verdict: { type: 'string' },
  },
  required: ['gatesPassed', 'issues', 'verdict'],
}
```

---

## Render Helpers

`renderConcept` iterates `Object.entries(c)` rather than naming fields, so it works for any candidate schema without modification — do not replace it with a hardcoded field list.

```js
const candidates = [] // STANDALONE PARSE ONLY — DELETE this line at assembly; the generate stage declares candidates

const renderConcept = (c) =>
  Object.entries(c)
    .map(([k, v]) => `${k}: ${v}`)
    .join('\n')

const renderIndexed = (idxs) => idxs.map(i => `[${i}] ${renderConcept(candidates[i])}`).join('\n\n')
```

---

## Context Stage

Pick ONE variant; both produce `briefs` (`Record<string,string>`). Brief keys (topicA, topicB, …) are illustrative — fill the lens/skeptic `briefs.<key>` accessors to match the spec's actual researchBriefKeys; the `|| ''` fallbacks keep an unmatched key harmless.

### Variant A — Local-file distillation

Each brief key calls `agent()` to read local research files and distill them. Replace all `// FILL:` items for your domain.

```js
// Context stage — local-file distillation variant
// FILL: replace briefSpec, parallel entries, and briefs key names for your domain
const briefSpec = 'Return ONLY a dense, design-actionable brief of AT MOST 600 words: terse bullets, concrete numbers/examples preserved, no fluff or meta-commentary. Your final message IS the brief.' // FILL: adjust word-count and style instructions

const DOMAIN = 'your domain here' // FILL: one-phrase description of what is being decided (used in prompts)
const ROOT = '/path/to/research' // FILL: absolute path to the research corpus root

const briefResults = await parallel([
  () => agent(`Read ${ROOT}/research/topic-a.md. Extract everything relevant to ${DOMAIN}. ${briefSpec}`, { model: WORKHORSE, label: 'brief:topic-a', phase: 'Context' }), // FILL: replace file path, topic, and extraction goal
  () => agent(`Read ${ROOT}/research/topic-b.md. Extract everything relevant to ${DOMAIN}. ${briefSpec}`, { model: WORKHORSE, label: 'brief:topic-b', phase: 'Context' }), // FILL: replace file path, topic, and extraction goal
])

const briefs = { // FILL: key names must match what downstream generate/filter stages reference
  topicA: briefResults[0] || '',
  topicB: briefResults[1] || '',
}
```

### Variant B — Web-search research

Each brief key calls `agent()` with web-search instructions to ground findings in live sources. Replace all `// FILL:` items for your domain.

```js
// Context stage — web-search research variant
// FILL: replace researchBriefs entries and briefs key names for your domain
const DOMAIN = 'your domain here' // FILL: one-phrase description of what is being decided

const researchBriefs = [
  { key: 'subtopic-a', prompt: `You are an expert in ${DOMAIN}. Use WebSearch/WebFetch (first run ToolSearch with query "select:WebSearch,WebFetch" to load the schemas) to research subtopic A. Return concrete findings (with confidence levels) and flag your most load-bearing or dubious claims for adversarial verification.` }, // FILL: replace subtopic-a and prompt body
  { key: 'subtopic-b', prompt: `You are an expert in ${DOMAIN}. Use WebSearch/WebFetch (first run ToolSearch with query "select:WebSearch,WebFetch" to load the schemas) to research subtopic B. Return concrete findings (with confidence levels) and flag your most load-bearing or dubious claims for adversarial verification.` }, // FILL: replace subtopic-b and prompt body
]

const researchResults = (await parallel(researchBriefs.map(b => () =>
  agent(b.prompt, { model: WORKHORSE, label: `research:${b.key}`, phase: 'Context', effort: 'high' })
))).filter(Boolean)

const briefs = Object.fromEntries( // FILL: key names must match what downstream stages reference
  researchBriefs.map((b, i) => {
    const r = researchResults[i]
    if (!r) return [b.key, '']
    // Serialize each research object to readable markdown: summary as heading + findings as bullet list
    // FILL: r.summary and r.findings match RESEARCH_SCHEMA; if you rename those fields, update here too
    const heading = `### ${r.summary || '(no summary)'}`
    const bullets = Array.isArray(r.findings)
      ? r.findings.map(f => `- (${f.confidence}) ${f.topic}: ${f.detail}`).join('\n')
      : ''
    return [b.key, bullets ? `${heading}\n${bullets}` : heading]
  })
)
```

---

## Claim-Verify Stage (optional)

Run this only when the context stage uses web-search and returns `claimsToVerify` arrays. Consumes `researchResults` (from the web-search context variant). Produces `verifiedDigest` (`string`).

```js
// Claim-verify stage (optional — use with web-search context variant only)
// FILL: replace LENSES if your domain calls for different skeptic perspectives
const VERIFY_LENSES = [
  'peer-reviewed literature or authoritative primary sources (cite real findings)', // FILL: adjust for your domain's primary-evidence type
  'a practitioner giving a real-world reality-check',
  'a skeptical myth-buster actively hunting for overstatement, folk wisdom, or hidden nuance that makes the naive claim wrong',
]

let claims = []
// ASSEMBLY NOTE: researchResults must be in scope from the web-search context variant (Variant B). Do NOT add a standalone const here; do NOT rename researchResults.
researchResults.forEach((r, ri) => (r && r.claimsToVerify || []).forEach((c, ci) =>
  claims.push({ id: `R${ri}-${ci}`, claim: c.claim, whyDubious: c.whyDubious })
))
claims = claims.slice(0, 12) // FILL: raise/lower cap as budget allows

const verified = (await parallel(claims.map(c => () =>
  parallel(VERIFY_LENSES.map((lens, li) => () =>
    agent(
      `A research agent (working on: ${DOMAIN}) asserted this claim:\n"${c.claim}"\nWhy it was flagged as dubious: ${c.whyDubious}\n\nVERIFY IT THROUGH THIS LENS: ${lens}. Use WebSearch/WebFetch (load via ToolSearch "select:WebSearch,WebFetch") to ground your check in real sources where you can. Be ADVERSARIAL — actively try to refute the claim or surface the nuance that makes it misleading. If evidence is thin, default to skepticism. Then give your verdict (confirmed / refuted / partly / unknown), a corrected precise statement of what is actually true, and your single strongest piece of evidence.`,
      { model: WORKHORSE, label: `verify:${c.id}:${li}`, phase: 'Verify', schema: VERDICT_SCHEMA, effort: 'medium' }
    )
  )).then(vs => {
    const v = vs.filter(Boolean)
    const dropped = vs.length - v.length // verify lenses that errored/returned null
    const count = k => v.filter(x => x.verdict === k).length
    const consensus = count('refuted') >= 2 ? 'REFUTED' : count('confirmed') >= 2 ? 'CONFIRMED' : 'NUANCED'
    // Reconcile SENT vs RETURNED (measured 2026-06-28): a dropped lens can flip a real quorum, so a short panel is never resolved silently.
    const needsAdjudication = dropped > 0
    if (needsAdjudication) log(`⚠ claim ${c.id}: ${dropped}/${vs.length} verify lens(es) dropped — consensus "${consensus}" rests on a short panel; flagging for main-loop adjudication`)
    return { id: c.id, claim: c.claim, consensus, verdicts: v, votesSent: vs.length, votesReturned: v.length, dropped, needsAdjudication }
  })
))).filter(Boolean)

const verifiedDigest = verified.map(x => {
  const corrected = x.verdicts.map(d => d.correctedStatement).filter(Boolean)
  const ev = x.verdicts.map(d => d.keyEvidence).filter(Boolean).join(' | ')
  return `[${x.consensus}] CLAIM: ${x.claim}\n   TRUTH: ${corrected.join(' / ').slice(0, 600)}\n   EVIDENCE: ${ev.slice(0, 500)}`
}).join('\n\n')
```

---

## Generate Stage

Produces `candidates` (`Candidate[]`) and `seedIndices` (`number[]`). The `// FILL:` slots cover: domain context strings, LENSES array, per-lens prompt body, and seed prompts.

```js
// Generate stage
// FILL: replace DOMAIN, genContext, LENSES, lens prompts, seedPrompts for your domain
// DOMAIN is declared in the context stage; reference it here directly.

const genContext = `${DOMAIN}

` + Object.entries(briefs).map(([k, v]) => `${k.toUpperCase()} BRIEF:\n${v}`).join('\n\n') // FILL: adjust key labels if brief keys have non-obvious names

const LENSES = [ // FILL: replace lens keys and prompts for your domain
  { key: 'lens-a', prompt: 'Lens: DIMENSION A. [Describe the creative angle through which candidates should be generated through this lens.]' }, // FILL: replace
  { key: 'lens-b', prompt: 'Lens: DIMENSION B. [Describe the creative angle for this lens.]' }, // FILL: replace
]

const genResults = await parallel(LENSES.map(l => () =>
  agent(
    `You are an expert generating candidates for a tournament deciding: ${DOMAIN}. ${l.prompt}\n\n${genContext}\n\nGenerate exactly 4 DISTINCT candidates through your lens. Each must satisfy all hard constraints and have one undeniably strong differentiator.`, // FILL: adjust count and constraint framing
    { model: WORKHORSE, label: `gen:${l.key}`, phase: 'Generate', schema: CANDIDATE_SCHEMA }
  )
))

// FILL: add seed prompts below — one entry per user-supplied seed idea; delete this block if no seeds
const seedPrompts = [
  `You are an expert. Develop this user-supplied seed idea into its STRONGEST single tournament-ready candidate for: ${DOMAIN}.\n\nSEED: [describe the seed idea here]\n\n${genContext}\n\nReturn exactly 1 candidate.`, // FILL: replace seed description
]
const seedDevs = await parallel(seedPrompts.map((prompt, si) => () =>
  agent(prompt, { model: WORKHORSE, label: `gen:seed-${si}`, phase: 'Generate', schema: CANDIDATE_SCHEMA })
))

const candidates = []
const seedIndices = []
for (const r of genResults.filter(Boolean)) for (const c of (r.candidates || [])) candidates.push(c) // FILL: r.candidates must match the top-level array key in CANDIDATE_SCHEMA; if you rename that key, update this access
for (const r of seedDevs.filter(Boolean)) for (const c of (r.candidates || [])) { seedIndices.push(candidates.length); candidates.push(c) }
```

---

## Filter Stage

Consumes `candidates`, `seedIndices`, `briefs`, `renderIndexed`. Produces `kept` (`number[]`), `totals` (`Map<number,number>`), `ranked` (`number[]` desc), and either `bracket` (`number[]` seeded, bracket mode) **or** `shortlist` (`number[]`, scoreboard mode). Seeds are force-kept in both modes.

### Bracket mode (select a fixed-size bracket for head-to-head tournament)

```js
// Filter stage — bracket mode
// FILL: replace AXES, DOMAIN, HARD, bracket size (default 8), and prompt bodies
const DOMAIN = 'your domain here' // FILL: one-phrase description (already declared at assembly; here for standalone parse)
const candidates = [] // STANDALONE PARSE ONLY — DELETE at assembly
const seedIndices = [] // STANDALONE PARSE ONLY — DELETE at assembly
const briefs = {} // STANDALONE PARSE ONLY — DELETE at assembly
const renderIndexed = (idxs) => idxs.map(i => `[${i}] ${JSON.stringify(candidates[i])}`).join('\n\n') // STANDALONE PARSE ONLY — DELETE at assembly

const HARD = `HARD CONSTRAINTS for ${DOMAIN}: [list must-satisfy constraints here]` // FILL: replace with your domain's hard constraints

const allIdx = candidates.map((_, i) => i)
const dedup = await agent(
  `You are the gatekeeper for a tournament deciding: ${DOMAIN}. Below are ${candidates.length} candidates, each with an index.\n\n${HARD}\n\nTASKS:\n1. KILL any candidate that violates a hard constraint.\n2. MERGE near-duplicates: when two candidates share the same core idea, keep only the better-articulated one.\n3. Indices ${JSON.stringify(seedIndices)} are the user's own seed ideas — they MUST be kept regardless (flag concerns in notes instead of killing).\n\nReturn the indices to keep.\n\n${renderIndexed(allIdx)}`,
  { model: WORKHORSE, label: 'filter:dedup', phase: 'Filter', schema: KEEP_SCHEMA }
)

let kept = (dedup && dedup.keep ? dedup.keep : allIdx).filter(i => i >= 0 && i < candidates.length)
for (const s of seedIndices) if (!kept.includes(s)) kept.push(s)
kept = [...new Set(kept)]

const AXES = [ // FILL: replace axes for your domain; each axis has key, brief (context string), and instr (scoring instruction)
  { key: 'axis-a', brief: briefs.topicA || '', instr: 'AXIS A: [describe what to score on this axis]' }, // FILL: replace
  { key: 'axis-b', brief: briefs.topicB || '', instr: 'AXIS B: [describe what to score on this axis]' }, // FILL: replace
]

const screeningResults = await parallel(AXES.map(a => () =>
  agent(
    `You are a tournament screener scoring candidates on ONE axis: ${a.instr}\n\nCONTEXT: ${DOMAIN}\n\nREFERENCE BRIEF:\n${a.brief}\n\nScore EVERY candidate below 0-10 on your axis ONLY. Use the full range — be a harsh discriminator, no clustering at 7. One sentence of reasoning each.\n\n${renderIndexed(kept)}`,
    { model: WORKHORSE, label: `screen:${a.key}`, phase: 'Filter', schema: SCORES_SCHEMA }
  )
))

const totals = new Map(kept.map(i => [i, 0]))
for (const res of screeningResults.filter(Boolean)) for (const s of (res.scores || [])) {
  if (totals.has(s.index)) totals.set(s.index, totals.get(s.index) + s.score)
}
const ranked = [...kept].sort((x, y) => totals.get(y) - totals.get(x))

// bracket: seeds guaranteed + top-scoring others fill remaining slots
const BRACKET_SIZE = 8 // FILL: adjust bracket size (must be a power of 2 for standard single-elimination)
const bracket = []
for (const s of seedIndices) bracket.push(s)
for (const i of ranked) { if (bracket.length >= BRACKET_SIZE) break; if (!bracket.includes(i)) bracket.push(i) }
bracket.sort((x, y) => totals.get(y) - totals.get(x))
```

### Scoreboard mode (rank all survivors for a scoring-panel tournament)

```js
// Filter stage — scoreboard mode (dedup + screening identical to bracket mode)
// FILL: same slots as bracket mode above; delete bracket block, add shortlist
const DOMAIN = 'your domain here' // FILL: one-phrase description (already declared at assembly; here for standalone parse)
const candidates = [] // STANDALONE PARSE ONLY — DELETE at assembly
const seedIndices = [] // STANDALONE PARSE ONLY — DELETE at assembly
const briefs = {} // STANDALONE PARSE ONLY — DELETE at assembly
const renderIndexed = (idxs) => idxs.map(i => `[${i}] ${JSON.stringify(candidates[i])}`).join('\n\n') // STANDALONE PARSE ONLY — DELETE at assembly

const HARD_SB = `HARD CONSTRAINTS for ${DOMAIN}: [list must-satisfy constraints here]` // FILL: replace (renamed to HARD_SB to avoid collision in standalone parse)

const allIdxSB = candidates.map((_, i) => i)
const dedupSB = await agent(
  `You are the gatekeeper for a tournament deciding: ${DOMAIN}. Below are ${candidates.length} candidates, each with an index.\n\n${HARD_SB}\n\nTASKS:\n1. KILL any candidate that violates a hard constraint.\n2. MERGE near-duplicates: keep only the better-articulated one.\n3. Indices ${JSON.stringify(seedIndices)} are user seeds — keep regardless.\n\nReturn the indices to keep.\n\n${renderIndexed(allIdxSB)}`,
  { model: WORKHORSE, label: 'filter:dedup', phase: 'Filter', schema: KEEP_SCHEMA }
)

let keptSB = (dedupSB && dedupSB.keep ? dedupSB.keep : allIdxSB).filter(i => i >= 0 && i < candidates.length)
for (const s of seedIndices) if (!keptSB.includes(s)) keptSB.push(s)
keptSB = [...new Set(keptSB)]

const AXES_SB = [ // FILL: replace axes for your domain
  { key: 'axis-a', brief: briefs.topicA || '', instr: 'AXIS A: [describe what to score on this axis]' },
  { key: 'axis-b', brief: briefs.topicB || '', instr: 'AXIS B: [describe what to score on this axis]' },
]

const screeningResultsSB = await parallel(AXES_SB.map(a => () =>
  agent(
    `You are a tournament screener scoring candidates on ONE axis: ${a.instr}\n\nCONTEXT: ${DOMAIN}\n\nREFERENCE BRIEF:\n${a.brief}\n\nScore EVERY candidate below 0-10 on your axis ONLY. Use the full range — no clustering at 7. One sentence of reasoning each.\n\n${renderIndexed(keptSB)}`,
    { model: WORKHORSE, label: `screen:${a.key}`, phase: 'Filter', schema: SCORES_SCHEMA }
  )
))

const totalsSB = new Map(keptSB.map(i => [i, 0]))
for (const res of screeningResultsSB.filter(Boolean)) for (const s of (res.scores || [])) {
  if (totalsSB.has(s.index)) totalsSB.set(s.index, totalsSB.get(s.index) + s.score)
}
const rankedSB = [...keptSB].sort((x, y) => totalsSB.get(y) - totalsSB.get(x))

// Export scoreboard-mode bindings (alias to contract names for assembly)
const kept = keptSB
const totals = totalsSB
const ranked = rankedSB

// shortlist: seeds guaranteed + all ranked survivors (scoreboard tournament needs all)
const shortlist = [...new Set([...seedIndices, ...ranked])]
```

---

## Tournament Stage

### Bracket mode (single-elimination, 8-slot default)

```js
// Tournament stage — bracket mode
// Consumes: candidates (Candidate[]), bracket (number[], seeded desc), renderConcept, MATCH_SCHEMA
// Produces: champion (number/index), runnerUp (number/index), matchLog (object[])
// FILL: replace JUDGE_LENSES with judge lenses appropriate for your domain; each lens has key/brief/instr
const candidates = [] // STANDALONE PARSE ONLY — DELETE at assembly
const bracket = [] // STANDALONE PARSE ONLY — DELETE at assembly
const renderConcept = (c) => JSON.stringify(c) // STANDALONE PARSE ONLY — DELETE at assembly
const MATCH_SCHEMA = { type: 'object', properties: { winner: { type: 'string', enum: ['A','B'] }, reason: { type: 'string' } }, required: ['winner','reason'] } // STANDALONE PARSE ONLY — DELETE at assembly
const agent = async () => null // STANDALONE PARSE ONLY — DELETE at assembly
const parallel = async (fns) => Promise.all(fns.map(f => f())) // STANDALONE PARSE ONLY — DELETE at assembly
const log = () => {} // STANDALONE PARSE ONLY — DELETE at assembly

const DOMAIN = 'your domain here' // FILL: one-phrase description (already declared at assembly; here for standalone parse)
const HARD = `HARD CONSTRAINTS for ${DOMAIN}: [list must-satisfy constraints here]` // FILL: replace with your hard constraints (already declared at assembly; here for standalone parse)
const briefs = {} // STANDALONE PARSE ONLY — DELETE at assembly

const JUDGE_LENSES = [ // FILL: replace with lenses for your domain
  { key: 'lens-a', brief: () => briefs.topicA || '', instr: 'LENS A: [describe what this judge evaluates above all]' },
  { key: 'lens-b', brief: () => briefs.topicB || '', instr: 'LENS B: [describe what this judge evaluates above all]' },
  { key: 'lens-c', brief: () => briefs.topicC || '', instr: 'LENS C: [describe what this judge evaluates above all]' },
]

const matchLog = []
const runMatch = async (ai, bi, round) => {
  const a = candidates[ai], b = candidates[bi]
  const votes = await parallel(JUDGE_LENSES.map(j => () =>
    agent(
      `You are one of three judges in a single-elimination tournament deciding: ${DOMAIN}.\n\n${HARD}\n\n${j.instr} The other must-haves are hard pass/fail criteria — a candidate that fails one loses regardless of your lens.\n\nREFERENCE BRIEF:\n${j.brief()}\n\nCANDIDATE A:\n${renderConcept(a)}\n\nCANDIDATE B:\n${renderConcept(b)}\n\nBe adversarial: hunt for the fatal flaw in each before weighing strengths. Pick the better CHOICE, not the more impressive idea on paper.`,
      { model: WORKHORSE, label: `judge:${round}:${j.key}`, phase: 'Tournament', schema: MATCH_SCHEMA }
    )
  ))
  const valid = votes.filter(Boolean)
  const dropped = votes.length - valid.length // judges that errored/returned null
  const aVotes = valid.filter(v => v.winner === 'A').length
  const bVotes = valid.length - aVotes
  const tie = aVotes === bVotes
  const winner = aVotes >= bVotes ? ai : bi // deterministic seed tie-break (higher seed = A); a bracket must still advance someone — surfaced via the flag below
  // Reconcile SENT vs RETURNED (measured 2026-06-28): a bracket that advances the wrong finalist corrupts the whole result, so a tie or a dropped judge is surfaced loudly, never silent.
  const needsAdjudication = dropped > 0 || tie
  if (needsAdjudication) log(`⚠ ${round}: ${a.name} vs ${b.name} advanced ${candidates[winner].name} on ${tie ? 'a TIE' : 'a majority'}${dropped ? ` with ${dropped}/${votes.length} judge vote(s) DROPPED` : ''} → decided by seed tie-break; FLAGGED for main-loop review`)
  matchLog.push({
    round,
    a: a.name,
    b: b.name,
    winner: candidates[winner].name,
    votesSent: votes.length,
    votesReturned: valid.length,
    dropped,
    tie,
    needsAdjudication,
    votes: JUDGE_LENSES.map((j, k) => votes[k]
      ? `${j.key}: ${votes[k].winner === 'A' ? a.name : b.name} — ${votes[k].reason}`
      : `${j.key}: (no vote)`)
  })
  log(`${round}: ${a.name} vs ${b.name} → ${candidates[winner].name} (A ${aVotes} / B ${bVotes}${dropped ? `, ${dropped} dropped` : ''})`)
  return winner
}

// pairings avoid top seeds meeting early: 1v8, 4v5, 3v6, 2v7 (bracket is sorted desc by score = seed 1 at index 0)
log('Quarterfinals...')
const [qf1, qf2, qf3, qf4] = await parallel([
  () => runMatch(bracket[0], bracket[7], 'QF1'),
  () => runMatch(bracket[3], bracket[4], 'QF2'),
  () => runMatch(bracket[2], bracket[5], 'QF3'),
  () => runMatch(bracket[1], bracket[6], 'QF4'),
])
log('Semifinals...')
const [sf1, sf2] = await parallel([
  () => runMatch(qf1, qf2, 'SF1'),
  () => runMatch(qf3, qf4, 'SF2'),
])
log('Final...')
const champion = await runMatch(sf1, sf2, 'FINAL')
const runnerUp = champion === sf1 ? sf2 : sf1
log(`CHAMPION: ${candidates[champion].name}`)
```

---

### Scoreboard mode (generate → judge panel → average score → ranked board)

```js
// Tournament stage — scoreboard mode
// Consumes: candidates (Candidate[]), shortlist (number[], indices), renderConcept, JUDGE_SCHEMA
// Produces: board ({index,name,score,votesSent,votesReturned,dropped,errored,generationFailed,stageThrew,...}[], sorted desc),
//           winner (number/index = board[0].index; `null` ONLY when the board is empty — downstream stages
//           must handle that, see the verify-champion and synthesize guards), needsAdjudication (boolean),
//           reconciliation (object[], one row per shortlist entry)
// FILL: replace JUDGES with judge personas/rubrics for your domain; set SCORE_SCALE from the spec
// NOTE: pipeline(items, stage1, stage2, ...) passes every stage callback (prevResult, originalItem, index).
// So pipeline(shortlist, genFn, judgeFn) gives each stage the candidate index as originalItem — no outer map needed.
// GATE: after editing this stage run `node reference/selftest-scoreboard.mjs` (SKILL.md §6) — it executes
// this exact block against the known-bad judge payloads that would otherwise flip a winner in silence.
const candidates = [] // STANDALONE PARSE ONLY — DELETE at assembly
const shortlist = [] // STANDALONE PARSE ONLY — DELETE at assembly
const renderConcept = (c) => JSON.stringify(c) // STANDALONE PARSE ONLY — DELETE at assembly
const JUDGE_SCHEMA = { type: 'object', properties: { persona: { type: 'string' }, candidate: { type: 'string' }, score: { type: 'number', minimum: 0, maximum: 10 }, breakdown: { type: 'string' }, critique: { type: 'string' }, mustFix: { type: 'string' }, wouldChoose: { type: 'boolean' } }, required: ['persona','candidate','score','critique','mustFix','wouldChoose'] } // STANDALONE PARSE ONLY — DELETE at assembly; keep minimum/maximum in step with SCORE_SCALE
const agent = async () => null // STANDALONE PARSE ONLY — DELETE at assembly
const parallel = async (fns) => Promise.all(fns.map(f => f())) // STANDALONE PARSE ONLY — DELETE at assembly
const log = () => {} // STANDALONE PARSE ONLY — DELETE at assembly

const DOMAIN_SB = 'your domain here' // FILL: one-phrase description (already declared at assembly as DOMAIN; rename at assembly)
const SHARED_SB = `[shared background context for ${DOMAIN_SB}]` // FILL: compose from briefs/verifiedDigest/researchDigest at assembly

const SCORE_SCALE = { min: 0, max: 10, integer: false } // FILL: from the spec; keep JUDGE_SCHEMA's description and every rubric on the same scale

const JUDGES = [ // FILL: replace with judge personas + rubrics for your domain
  { key: 'judge-a', persona: '[Judge A role]', rubric: 'AXIS A: [what this judge scores on, 0–10]' }, // FILL: keep the scale here identical to SCORE_SCALE and JUDGE_SCHEMA's (0-10 as shipped)
  { key: 'judge-b', persona: '[Judge B role]', rubric: 'AXIS B: [what this judge scores on, 0–10]' },
  { key: 'judge-c', persona: '[Judge C role]', rubric: 'AXIS C: [what this judge scores on, 0–10]' },
]

// Validate a ballot against its ASSIGNMENT before it can move a mean, and return the reason it is
// unusable (or null when it is usable). A scoreboard ranks by the mean, so an out-of-scale, non-numeric
// or misattributed score does not merely add noise — it reorders the board. `x.score || 0` counted all
// three: `null` scored a zero (demoting its own candidate), a string concatenated
// ("9" + "7" → mean 62.3), and 100 on a 0–10 scale carried a candidate to the top on one vote.
// The identity echo is compared AFTER normalising both sides: a judge that echoes its role with a
// trailing space or a different case has still identified itself, and voiding that ballot would throw
// away a valid vote for a formatting difference. A different name still fails.
const sameId = (a, b) => String(a ?? '').trim().toLowerCase() === String(b ?? '').trim().toLowerCase()
const voteFault = (v, judge, cand) => {
  if (!sameId(v.persona, judge.persona)) return `persona '${v.persona}' != assigned '${judge.persona}'`
  if (!sameId(v.candidate, cand.name)) return `candidate '${v.candidate}' != assigned '${cand.name}'`
  if (typeof v.score !== 'number' || !Number.isFinite(v.score)) return `score is ${v.score === null ? 'null' : typeof v.score}, not a finite number`
  if (SCORE_SCALE.integer && !Number.isInteger(v.score)) return `score ${v.score} is not an integer`
  if (v.score < SCORE_SCALE.min || v.score > SCORE_SCALE.max) return `score ${v.score} outside ${SCORE_SCALE.min}..${SCORE_SCALE.max}`
  return null
}

const rawJudged = await pipeline(
  shortlist,
  (idx) => {
    const c = candidates[idx]
    return agent(
      `${SHARED_SB}\n\nYou are developing ONE tournament candidate.\nCANDIDATE: ${c.name}\n\nProduce a complete, detailed output for this candidate. Put full content in the appropriate schema fields.`, // FILL: tailor prompt for your domain
      { model: WORKHORSE, label: `gen:${c.name}`, phase: 'Tournament', schema: { type: 'object', properties: { candidates: { type: 'array', items: { type: 'object' } } }, required: ['candidates'] }, effort: 'high' } // FILL: replace inline schema with your domain's generation schema (e.g. CANDIDATE_SCHEMA)
    )
  },
  (generated, idx) => {
    const c = candidates[idx]
    // A failed generation is a BUCKET, not a silent drop: the candidate stays on the board unscored and
    // sets needsAdjudication, so a vanished candidate can never read as one that simply lost.
    if (!generated) {
      log(`⚠ ${c.name}: generation returned nothing — candidate kept on the board UNSCORED; FLAGGED for main-loop review`)
      return { index: idx, name: c.name, generated: null, judges: [], score: null, votesSent: 0, votesReturned: 0, dropped: 0, errored: [], generationFailed: true, stageThrew: false }
    }
    return parallel(JUDGES.map(j => () =>
      agent(
        `${SHARED_SB}\n\nYou are judging a tournament candidate. YOUR ROLE: ${j.persona}.\n${j.rubric}\n\nCANDIDATE NAME: ${c.name}\nCANDIDATE OUTPUT:\n${renderConcept(generated)}\n\nScore it ${SCORE_SCALE.min}-${SCORE_SCALE.max} through YOUR lens only${SCORE_SCALE.integer ? ', as a whole number' : ''}. Be tough, specific, and do NOT inflate. Give a breakdown, a sharp critique, the single most important fix (mustFix), and whether YOU personally would choose it. Echo YOUR ROLE verbatim in \`persona\` and the CANDIDATE NAME verbatim in \`candidate\` — a mismatch voids your vote.`, // FILL: adjust the rubric wording; the scale text is derived from SCORE_SCALE, leave it
        { model: WORKHORSE, label: `judge:${c.name}:${j.key}`, phase: 'Tournament', schema: JUDGE_SCHEMA, effort: 'high' }
      )
    )).then(js => {
      // parallel() resolves POSITIONALLY: js[k] is JUDGES[k]'s ballot, or null if that judge errored.
      const valid = [], errored = []
      let dropped = 0
      js.forEach((v, k) => {
        if (!v) { dropped++; return }
        const why = voteFault(v, JUDGES[k], c)
        if (why) errored.push({ judge: JUDGES[k].key, why })
        else valid.push(v)
      })
      // score is null, NEVER 0, when nothing valid came back — a zero is a real rank, an absence is not.
      const score = valid.length ? valid.reduce((s, x) => s + x.score, 0) / valid.length : null
      if (dropped || errored.length) log(`⚠ ${c.name}: ${js.length} vote(s) sent, ${valid.length} valid${dropped ? `, ${dropped} DROPPED` : ''}${errored.length ? `, ${errored.length} ERRORED (${errored.map(e => `${e.judge}: ${e.why}`).join('; ')})` : ''}; FLAGGED for main-loop review`)
      // The three buckets are DISJOINT: votesSent = votesReturned + dropped + errored.length. An invalid
      // ballot came BACK but is not a RETURNED VOTE — counting it as one hides the void from every consumer
      // that reads the reconciliation (the Codex instrument keeps the same split, tourney.mjs buildBoard).
      return { index: idx, name: c.name, generated, judges: valid, score, votesSent: js.length, votesReturned: valid.length, dropped, errored, generationFailed: false, stageThrew: false }
    })
  }
)
// pipeline() nulls an item only when a stage THROWS, and the buckets above no longer throw — but an
// unexpected runtime error still can. pipeline() resolves POSITIONALLY, so rawJudged[k] belongs to
// shortlist[k]: rebuild the row from that index rather than filtering it away, or the reconciliation
// cannot NAME the candidate it lost and a vanished candidate reads as one that simply lost.
const stageDropped = rawJudged.length - rawJudged.filter(Boolean).length
const judged = rawJudged.map((r, k) => r || {
  index: shortlist[k], name: (candidates[shortlist[k]] || {}).name || `(shortlist position ${k})`,
  generated: null, judges: [], score: null, votesSent: 0, votesReturned: 0, dropped: 0, errored: [],
  generationFailed: true, stageThrew: true,
})
if (stageDropped) log(`⚠ ${stageDropped}/${rawJudged.length} candidate(s) fell out of the judging pipeline (a stage threw) — kept on the board UNSCORED; FLAGGED for main-loop review`)

// Rank: an unscored candidate (null) sorts LAST, never as a zero; equal scores break to the lower index.
const rank = (x) => (x.score === null ? -Infinity : x.score)
const board = judged.sort((a, b) => (rank(a) === rank(b) ? a.index - b.index : rank(b) - rank(a)))
// Reconcile SENT vs RETURNED (measured 2026-06-28; identity/scale validation added 2026-09-05): as in
// bracket mode, the tournament still names a DETERMINISTIC winner — downstream stages index
// candidates[winner] — and the doubt rides on needsAdjudication rather than on a null nobody checks.
const tieAtTop = board.length > 1 && board[0].score !== null && board[0].score === board[1].score
const needsAdjudication = JUDGES.length === 0 || shortlist.length === 0 || stageDropped > 0 || tieAtTop
  || board.some(b => b.score === null || b.dropped > 0 || b.errored.length > 0)
const winner = board.length ? board[0].index : null // null ONLY when the board is empty — there is no index to name
const reconciliation = board.map(b => ({ name: b.name, votesSent: b.votesSent, votesReturned: b.votesReturned, dropped: b.dropped, errored: b.errored, generationFailed: b.generationFailed, stageThrew: b.stageThrew }))
if (needsAdjudication) log('⚠ scoreboard needsAdjudication — the leaderboard below is PROVISIONAL; do not crown a winner without main-loop review')
log(`Leaderboard: ${board.map(b => `${b.name} ${b.score === null ? '(unscored)' : b.score.toFixed(1)}`).join(' | ')}. ${needsAdjudication ? 'Provisional winner' : 'Winner'}: ${board.length ? board[0].name : '(none)'}.`)
```

---

## Verify-Champion Stage

Runs skeptic lenses in `parallel` (genuine barrier — all skeptics must complete before consensus). Produces `skeptics` (`object[]`) and `fatalCount` (`number`). Slot: SKEPTIC_LENSES array + refute threshold for swap-to-runner-up rule (default: swap if `fatalCount >= 2`).

```js
// Verify-champion stage
// Consumes: candidates (Candidate[]), champion (number/index), briefs, renderConcept, SKEPTIC_SCHEMA
// Produces: skeptics (object[]), fatalCount (number)
// FILL: replace SKEPTIC_LENSES with lenses appropriate for your domain
// SWAP RULE (default): if fatalCount >= 2, downstream synthesize should recommend runnerUp instead
const candidates = [] // STANDALONE PARSE ONLY — DELETE at assembly; produced by generate stage
const champion = 0 // STANDALONE PARSE ONLY — DELETE at assembly; produced by tournament/bracket stage (scoreboard mode: bind champion = winner, which is `null` on an empty board)
const renderConcept = (c) => JSON.stringify(c) // STANDALONE PARSE ONLY — DELETE at assembly
const SKEPTIC_SCHEMA = { type: 'object', properties: { refuted: { type: 'boolean' }, severity: { type: 'string', enum: ['fatal','serious','minor'] }, concerns: { type: 'array', items: { type: 'string' } }, fixes: { type: 'array', items: { type: 'string' } } }, required: ['refuted','severity','concerns','fixes'] } // STANDALONE PARSE ONLY — DELETE at assembly; produced by Schema Builders section
const agent = async () => null // STANDALONE PARSE ONLY — DELETE at assembly
const parallel = async (fns) => Promise.all(fns.map(f => f())) // STANDALONE PARSE ONLY — DELETE at assembly
const log = () => {} // STANDALONE PARSE ONLY — DELETE at assembly

const DOMAIN = 'your domain here' // FILL: one-phrase description (already declared at assembly; here for standalone parse)
const HARD = `HARD CONSTRAINTS for ${DOMAIN}: [list must-satisfy constraints here]` // FILL: replace (already declared at assembly; here for standalone parse)
const briefs = {} // STANDALONE PARSE ONLY — DELETE at assembly

const SKEPTIC_LENSES = [ // FILL: replace with lenses for your domain; each has key, brief(), and instr
  { key: 'lens-a', brief: () => briefs.topicA || '', instr: 'Attack DIMENSION A: [describe the adversarial angle for this skeptic lens]' }, // FILL: replace
  { key: 'lens-b', brief: () => briefs.topicB || '', instr: 'Attack DIMENSION B: [describe the adversarial angle for this skeptic lens]' }, // FILL: replace
  { key: 'lens-c', brief: () => briefs.topicC || '', instr: 'Attack DIMENSION C: [describe the adversarial angle for this skeptic lens]' }, // FILL: replace
]

// A scoreboard run binds champion = winner, and winner is `null` on an empty board. There is nothing to
// refute then: skip the fan-out rather than interpolating `undefined` into every skeptic prompt and
// reading the resulting fatalCount of 0 as "no fatal flaw found". Bracket mode always names an index.
const noChampion = champion === null || champion === undefined || !candidates[champion]
if (noChampion) log('⚠ verify-champion: no champion to refute (empty/unresolved board) — skeptic panel SKIPPED; fatalCount 0 here means UNTESTED, not clean. FLAGGED for main-loop review')
const skepticResults = noChampion ? [] : await parallel(SKEPTIC_LENSES.map(s => () =>
  agent(
    `You are a professional skeptic. Your job is to REFUTE this champion before committing to it. Default to refuted=true only for genuinely FATAL flaws; use severity for the rest. Always propose concrete fixes where they exist.\n\n${HARD}\n\n${s.instr}\n\nREFERENCE BRIEF:\n${s.brief()}\n\nTHE CHAMPION:\n${renderConcept(candidates[champion])}`,
    { model: WORKHORSE, label: `skeptic:${s.key}`, phase: 'Verify', schema: SKEPTIC_SCHEMA }
  )
))
const skeptics = SKEPTIC_LENSES.map((s, k) => ({ lens: s.key, result: skepticResults[k] })).filter(x => x.result)
const skepticsDropped = skepticResults.length - skeptics.length // skeptic lenses that errored/returned null
const fatalCount = skeptics.filter(x => x.result.refuted).length
// Reconcile SENT vs RETURNED (measured 2026-06-28): a dropped refuter UNDERcounts fatalCount, so a bad champion could survive a flaw it shouldn't. Never trust the swap on a short panel.
if (skepticsDropped > 0) log(`⚠ champion skeptic panel: ${skepticsDropped}/${skepticResults.length} lens(es) dropped — fatalCount ${fatalCount} rests on a short panel; a missing refuter can hide a fatal flaw. Flag for main-loop adjudication before trusting the swap.`)
log(`Skeptic verdicts: ${skeptics.map(x => `${x.lens}=${x.result.severity}${x.result.refuted ? ' (REFUTED)' : ''}`).join(', ')}`)
// SWAP RULE: if fatalCount >= 2, the synthesize stage should recommend runnerUp instead of champion // FILL: adjust threshold (default: 2 of 3 lenses)
```

---

## Synthesize Stage

Two variants — pick the one matching your tournament mode. Both graft winner + runner-up ideas + skeptic fixes into a final recommendation.

### Variant A — Text report (bracket mode → `report`)

Produces `report` (`string`). No schema; the agent's final message IS the report. Sections are fully slotted for your domain.

```js
// Synthesize stage — text report variant (bracket mode)
// Consumes: candidates (Candidate[]), champion (number), runnerUp (number), seedIndices (number[]),
//           matchLog (object[]), skeptics (object[]), fatalCount (number), briefs, renderConcept
// Produces: report (string)
// FILL: replace HARD, brief references, and section prompts for your domain
const candidates = [] // STANDALONE PARSE ONLY — DELETE at assembly; produced by generate stage
const champion = 0 // STANDALONE PARSE ONLY — DELETE at assembly; produced by tournament/bracket stage
const runnerUp = 0 // STANDALONE PARSE ONLY — DELETE at assembly; produced by tournament/bracket stage
const seedIndices = [] // STANDALONE PARSE ONLY — DELETE at assembly; produced by generate stage
const matchLog = [] // STANDALONE PARSE ONLY — DELETE at assembly; produced by tournament/bracket stage
const skeptics = [] // STANDALONE PARSE ONLY — DELETE at assembly; produced by verify-champion stage
const fatalCount = 0 // STANDALONE PARSE ONLY — DELETE at assembly; produced by verify-champion stage
const renderConcept = (c) => JSON.stringify(c) // STANDALONE PARSE ONLY — DELETE at assembly
const agent = async () => null // STANDALONE PARSE ONLY — DELETE at assembly
const log = () => {} // STANDALONE PARSE ONLY — DELETE at assembly

const DOMAIN = 'your domain here' // FILL: one-phrase description (already declared at assembly; here for standalone parse)
const HARD = `HARD CONSTRAINTS for ${DOMAIN}: [list must-satisfy constraints here]` // FILL: replace (already declared at assembly; here for standalone parse)
const briefs = {} // STANDALONE PARSE ONLY — DELETE at assembly

log('Writing final recommendation...')
const SYNTH_MODEL = WORKHORSE // OPT-IN: set to SCARCE for max-insight final synthesis. This is the one stage whose agent count is fixed at exactly 1 regardless of bracket size, which is the cost argument for placing scarce here and nowhere else in a tournament (multi-agent-policy posture ladder, `full` rung); every other stage stays WORKHORSE.
const report = await agent(
  `You are the synthesis lead for a tournament deciding: ${DOMAIN}. Write the FINAL RECOMMENDATION REPORT in markdown. Your final message IS the report — no meta-commentary.\n\n${HARD}\n\nCHAMPION:\n${renderConcept(candidates[champion])}\n(user-seed concept: ${seedIndices.includes(champion)})\n\nRUNNER-UP:\n${renderConcept(candidates[runnerUp])}\n(user-seed concept: ${seedIndices.includes(runnerUp)})\n\nFULL MATCH LOG (judge reasoning):\n${JSON.stringify(matchLog, null, 1)}\n\nADVERSARIAL SKEPTIC FINDINGS ON CHAMPION (${fatalCount}/${skeptics.length} voted fatal):\n${JSON.stringify(skeptics, null, 1)}\n\nWrite these sections:\n1. **Recommendation** — the choice to make and the one-paragraph case. If ${fatalCount >= 2 ? fatalCount : 0}+ skeptics voted fatal, recommend the runner-up instead and say why.\n2. **The winner in full** — refined pitch incorporating skeptic FIXES and the best grafts from runner-up (name each graft and its source).\n3. **Why it beat the field** — the decisive judge arguments, honestly including close calls.\n4. **Skeptic findings & mitigations** — every serious+ concern with its concrete mitigation.\n5. **Scope sketch** — milestone outline against your time/budget yardstick, with the hardest constraint explicitly budgeted.\n6. **Kill criteria** — 3 testable conditions early in execution that should kill/pivot the project.\n7. **The full bracket** — one-line results of every match.`, // FILL: adjust section list, scope yardstick, and kill-criteria framing for your domain
  { model: SYNTH_MODEL, label: 'synthesis', phase: 'Synthesize' }
)
```

### Variant B — Schema synth (scoreboard mode → `synth`)

Produces `synth` (`object`, typed by `SYNTH_SCHEMA`). Grafts winner + runner-up ideas + all judge mustFix items into a structured output.

```js
// Synthesize stage — schema synth variant (scoreboard mode)
// Consumes: candidates (Candidate[]), board ({index,score,...}[]), winner (number/index),
//           needsAdjudication (boolean), skeptics (object[]), fatalCount (number), SYNTH_SCHEMA
// Produces: synth (object — typed by SYNTH_SCHEMA)
// FILL: replace SHARED, board field references, and prompt body for your domain
const candidates = [] // STANDALONE PARSE ONLY — DELETE at assembly; produced by generate stage
const board = [] // STANDALONE PARSE ONLY — DELETE at assembly; produced by tournament/scoreboard stage
const winner = 0 // STANDALONE PARSE ONLY — DELETE at assembly; produced by tournament/scoreboard stage
const needsAdjudication = false // STANDALONE PARSE ONLY — DELETE at assembly; produced by tournament/scoreboard stage
const skeptics = [] // STANDALONE PARSE ONLY — DELETE at assembly; produced by verify-champion stage
const fatalCount = 0 // STANDALONE PARSE ONLY — DELETE at assembly; produced by verify-champion stage
const SYNTH_SCHEMA = { type: 'object', properties: { summaryMarkdown: { type: 'string' }, parametersMarkdown: { type: 'string' }, changeLog: { type: 'array', items: { type: 'object', properties: { change: { type: 'string' }, why: { type: 'string' } }, required: ['change','why'] } }, graftedFrom: { type: 'array', items: { type: 'string' } } }, required: ['summaryMarkdown','changeLog'] } // STANDALONE PARSE ONLY — DELETE at assembly; produced by Schema Builders section
const agent = async () => null // STANDALONE PARSE ONLY — DELETE at assembly
const log = () => {} // STANDALONE PARSE ONLY — DELETE at assembly

const DOMAIN_SYNTH = 'your domain here' // FILL: one-phrase description (already declared at assembly as DOMAIN; rename at assembly)
const SHARED_SYNTH = `[shared background context for ${DOMAIN_SYNTH}]` // FILL: compose from briefs/verifiedDigest at assembly

log('Producing final synthesized output...')
const SYNTH_MODEL = WORKHORSE // OPT-IN: set to SCARCE for max-insight final synthesis. This is the one stage whose agent count is fixed at exactly 1 regardless of bracket size, which is the cost argument for placing scarce here and nowhere else in a tournament (multi-agent-policy posture ladder, `full` rung); every other stage stays WORKHORSE.
const fmtScore = (s) => (s === null || s === undefined ? '(unscored)' : s.toFixed(1)) // an unscored candidate has no mean to print — never render it as 0.0
// winner is `null` on an empty board (stages.md contract) — never index candidates[winner] unguarded.
const leader = winner === null || winner === undefined ? null : candidates[winner]
const leaderName = leader ? leader.name : '(no leader — the board is empty)'
// Name only the causes that are ACTUALLY set: a prompt that asserts "ballots were dropped" when the real
// cause was a tie teaches the synthesis agent a fact the run never measured.
const ADJ_REASONS = [ // FILL: keep in step with the scoreboard stage's needsAdjudication expression if you edit it
  [board.some(b => b.dropped > 0), 'one or more ballots were DROPPED (a judge returned nothing)'],
  [board.some(b => (b.errored || []).length > 0), 'one or more ballots were VOIDED as invalid (wrong persona/candidate echo, or a score off type or scale)'],
  [board.some(b => b.score === null), 'at least one candidate has NO valid score'],
  [board.some(b => b.stageThrew), 'at least one candidate was lost to a stage that threw'],
  [board.length > 1 && board[0].score !== null && board[0].score === board[1].score, 'the top two candidates are TIED'],
  [board.length === 0, 'the board is EMPTY'],
].filter(([on]) => on).map(([, why]) => why)
const synth = await agent(
  `${SHARED_SYNTH}\n\nTOURNAMENT RESULTS (best first):\n${board.map(b => `- ${candidates[b.index].name}: ${fmtScore(b.score)} | judges: ${(b.judges || []).map(j => `[${j.persona}] score ${j.score}, critique: ${j.critique} (mustFix: ${j.mustFix})`).join('  ||  ')}`).join('\n')}\n\n${needsAdjudication ? 'PROVISIONAL LEADER' : 'WINNER'}: ${leaderName}${needsAdjudication ? `\n\nRECONCILIATION: needsAdjudication is TRUE for this scoreboard — ${ADJ_REASONS.join('; ') || 'the run flagged itself for review'}. Say this plainly at the top of summaryMarkdown, present the board and the leader as PROVISIONAL, and do NOT crown a winner.` : ''}\n\nADVERSARIAL SKEPTIC FINDINGS ON ${needsAdjudication ? 'PROVISIONAL LEADER' : 'WINNER'} (${fatalCount}/${skeptics.length} voted fatal):\n${JSON.stringify(skeptics, null, 1)}\n\nALL CANDIDATES (for grafting the best ideas):\n${board.map(b => `\n===== ${candidates[b.index].name} (${fmtScore(b.score)}) =====\n${JSON.stringify(b.generated || candidates[b.index], null, 1)}`).join('\n')}\n\nNow produce the FINAL synthesized output. ${needsAdjudication ? 'Start from the PROVISIONAL LEADER and label it as such throughout — name no winner' : 'Start from the WINNER'}, GRAFT IN the best verified ideas from other candidates, and resolve EVERY judge mustFix. Output summaryMarkdown (complete, detailed, ready-to-use), parametersMarkdown (key tunable parameters), changeLog (each change with why and what it came from), and graftedFrom (source concept names). If ${fatalCount >= 2 ? fatalCount : 0}+ skeptics voted fatal, address their concerns explicitly in the changeLog.`, // FILL: tailor prompt — replace field names (b.thesis, b.generated etc.) to match your scoreboard-mode tournament's actual output shape
  { model: SYNTH_MODEL, label: 'synthesize', phase: 'Synthesize', schema: SYNTH_SCHEMA, effort: 'max' }
)
```

---

## QA Stage (optional)

Red-team the synthesized output, then patch it. Produces `qa` (`object`, typed by `QA_SCHEMA`) and `patched` (`string`). Use only when correctness/safety gates are worth the extra call.

```js
// QA stage (optional)
// Consumes: synth (object from synthesize/schema variant), QA_SCHEMA
// NOTE: for text-report (bracket) mode, replace synth.summaryMarkdown with report
// Produces: qa (object — typed by QA_SCHEMA), patched (string)
// FILL: replace CONSTRAINTS, QA checks list, and synth field references for your domain
const synth = { summaryMarkdown: '', parametersMarkdown: '', changeLog: [], graftedFrom: [] } // STANDALONE PARSE ONLY — DELETE at assembly; produced by synthesize/schema stage
const QA_SCHEMA = { type: 'object', properties: { gatesPassed: { type: 'boolean' }, issues: { type: 'array', items: { type: 'object', properties: { severity: { type: 'string' }, issue: { type: 'string' }, fix: { type: 'string' } }, required: ['severity','issue','fix'] } }, verdict: { type: 'string' } }, required: ['gatesPassed','issues','verdict'] } // STANDALONE PARSE ONLY — DELETE at assembly; produced by Schema Builders section
const agent = async () => null // STANDALONE PARSE ONLY — DELETE at assembly
const log = () => {} // STANDALONE PARSE ONLY — DELETE at assembly

const DOMAIN_QA = 'your domain here' // FILL: one-phrase description (already declared at assembly as DOMAIN; rename at assembly)
const CONSTRAINTS_QA = `[hard constraints for ${DOMAIN_QA}]` // FILL: replace with your domain's hard constraints (already declared at assembly; here for standalone parse)

log('QA red-team + patch...')
const qa = await agent(
  `Red-team this final output BEFORE it ships. Be ruthless.\n\nCONSTRAINTS:\n${CONSTRAINTS_QA}\n\nFINAL OUTPUT:\n${synth.summaryMarkdown}\n\nPARAMETERS:\n${synth.parametersMarkdown || '(none)'}\n\nCheck HARD for: (1) domain-specific hard gates (${DOMAIN_QA}); (2) internal contradictions, missing quantities, or ambiguous steps; (3) does it overshoot the constraint budget?; (4) any claims that contradict verified findings; (5) is every judge mustFix actually resolved? List every issue with a concrete fix.`, // FILL: replace checklist items with your domain's QA gates
  { model: WORKHORSE, label: 'qa-redteam', phase: 'QA', schema: QA_SCHEMA, effort: 'high' }
)

const patched = await agent(
  `Apply these QA fixes to the output, changing as LITTLE as possible and preserving its structure, formatting, and voice. Return ONLY the corrected full output markdown (no preamble).\n\nQA VERDICT: ${qa.verdict}\nQA ISSUES:\n${JSON.stringify(qa.issues, null, 2)}\n\nCURRENT FINAL OUTPUT:\n${synth.summaryMarkdown}`, // FILL: replace synth.summaryMarkdown with the correct field for your synth output (e.g. report for text-mode)
  { model: WORKHORSE, label: 'qa-patch', phase: 'QA', effort: 'medium' }
)
```

---

## Result Shape

The final top-level `return {...}` that exposes all outputs. Two variants matching the tournament modes. Pick the one that matches your tournament.

### Variant A — Bracket mode result shape

Exposes `champion` (object), `runnerUp` (name string), `bracket` (array), `matchLog`, `skeptics`, `fatalCount`, `report`.

```js
// Result shape — bracket mode
// Consumes all upstream bindings: candidates, champion, runnerUp, seedIndices, bracket, totals,
//          matchLog, skeptics, fatalCount, report
// FILL: add/remove fields as your spec requires; keep binding names verbatim
const candidates = [] // STANDALONE PARSE ONLY — DELETE at assembly; produced by generate stage
const champion = 0 // STANDALONE PARSE ONLY — DELETE at assembly; produced by tournament/bracket stage
const runnerUp = 0 // STANDALONE PARSE ONLY — DELETE at assembly; produced by tournament/bracket stage
const seedIndices = [] // STANDALONE PARSE ONLY — DELETE at assembly; produced by generate stage
const bracket = [] // STANDALONE PARSE ONLY — DELETE at assembly; produced by filter/bracket stage
const totals = new Map() // STANDALONE PARSE ONLY — DELETE at assembly; produced by filter stage
const matchLog = [] // STANDALONE PARSE ONLY — DELETE at assembly; produced by tournament/bracket stage
const skeptics = [] // STANDALONE PARSE ONLY — DELETE at assembly; produced by verify-champion stage
const fatalCount = 0 // STANDALONE PARSE ONLY — DELETE at assembly; produced by verify-champion stage
const report = '' // STANDALONE PARSE ONLY — DELETE at assembly; produced by synthesize/text stage

return {
  champion: candidates[champion],
  championIsUserSeed: seedIndices.includes(champion),
  runnerUp: candidates[runnerUp].name, // FILL: emits the runnerUp name; use candidates[runnerUp] if you need the full object
  bracket: bracket.map(i => ({ name: candidates[i].name, screenScore: totals.get(i), isSeed: seedIndices.includes(i) })),
  matchLog,
  skeptics,
  fatalCount,
  report,
}
```

### Variant B — Scoreboard mode result shape

Exposes `leaderboard` (array), `winner` (name string, **`null` when the run needs adjudication**), `provisionalWinner`, `needsAdjudication`, `reconciliation`, `candidates` (full detail array), `skeptics`, `fatalCount`, `synth` (fields), `qa`, `patched`.

`winner` is the caller-facing refusal: a consumer that reads it gets nothing to crown until a human has looked at `reconciliation`. `provisionalWinner` is the deterministic top of the board for a non-empty board, and `null` when the board is empty — so the result stays inspectable without ever pretending a leader exists.

```js
// Result shape — scoreboard mode
// Consumes all upstream bindings: candidates, board, winner, needsAdjudication, reconciliation,
//          skeptics, fatalCount, synth, qa, patched
// FILL: adjust field names/shapes to match your scoreboard tournament's actual judge/generated output shape
const candidates = [] // STANDALONE PARSE ONLY — DELETE at assembly; produced by generate stage
const board = [] // STANDALONE PARSE ONLY — DELETE at assembly; produced by tournament/scoreboard stage
const winner = 0 // STANDALONE PARSE ONLY — DELETE at assembly; produced by tournament/scoreboard stage
const needsAdjudication = false // STANDALONE PARSE ONLY — DELETE at assembly; produced by tournament/scoreboard stage
const reconciliation = [] // STANDALONE PARSE ONLY — DELETE at assembly; produced by tournament/scoreboard stage
const skeptics = [] // STANDALONE PARSE ONLY — DELETE at assembly; produced by verify-champion stage
const fatalCount = 0 // STANDALONE PARSE ONLY — DELETE at assembly; produced by verify-champion stage
const synth = { summaryMarkdown: '', parametersMarkdown: '', changeLog: [], graftedFrom: [] } // STANDALONE PARSE ONLY — DELETE at assembly; produced by synthesize/schema stage
const qa = { gatesPassed: true, issues: [], verdict: '' } // STANDALONE PARSE ONLY — DELETE at assembly; produced by QA stage
const patched = '' // STANDALONE PARSE ONLY — DELETE at assembly; produced by QA stage

const round1 = (s) => (s === null || s === undefined ? null : Number(s.toFixed(1))) // an unscored candidate stays null — never rounds to 0
const leaderName = winner === null || winner === undefined ? null : candidates[winner].name // `null` on an empty board

return {
  leaderboard: board.map(b => ({ name: candidates[b.index].name, score: round1(b.score), votesSent: b.votesSent, votesReturned: b.votesReturned, dropped: b.dropped, errored: (b.errored || []).length })),
  winner: needsAdjudication ? null : leaderName, // withheld until a human reconciles
  provisionalWinner: leaderName,
  needsAdjudication,
  reconciliation,
  candidates: board.map(b => ({
    name: candidates[b.index].name,
    score: round1(b.score),
    judges: (b.judges || []).map(j => ({ persona: j.persona, score: j.score, critique: j.critique, mustFix: j.mustFix, wouldChoose: j.wouldChoose })), // FILL: match judge field names to your JUDGE_SCHEMA if you renamed any
    generated: b.generated || null, // FILL: replace with the actual generated-output field name from your scoreboard tournament stage
  })),
  skeptics,
  fatalCount,
  summaryMarkdown: synth.summaryMarkdown,
  parametersMarkdown: synth.parametersMarkdown,
  changeLog: synth.changeLog,
  graftedFrom: synth.graftedFrom,
  qa,
  patched,
}
```
