#!/usr/bin/env node
// Dev tool (plain Node, runs OUTSIDE the Workflow runtime). Executes the CANONICAL filter stage out of
// `stages.md` — BOTH mode blocks — against a fixture panel of known-bad screener payloads, plus the
// bracket tournament stage's vote tally, so a regression in either is caught here rather than in a
// 100-agent run.
//
//   node reference/selftest-filter.mjs [path/to/stages.md]   (default: the sibling stages.md)
//
// It extracts the `### Bracket mode (select a fixed-size bracket` and `### Scoreboard mode (rank all
// survivors` fences (the two filter blocks) and the `### Bracket mode (single-elimination` fence (the
// tournament tally), deletes every line tagged `STANDALONE PARSE ONLY — DELETE at assembly` exactly as an
// assembler does, prepends the real `### SCORES_SCHEMA` block to each filter block (that block declares
// SCREEN_SCALE and SCORES_SCHEMA for real — same reason the scoreboard harness prepends JUDGE_SCHEMA: a
// wrapper parameter of the same name would be a SyntaxError, and passing them in would let the stage pass
// while the schema block drifted off the scale), wraps the remainder in an async function over the
// bindings the stage consumes, and runs it once per fixture with a fake `agent` that answers by
// `opts.label` (`filter:dedup` → the keep list, `screen:<axis-key>` → that axis's payload,
// `judge:<round>:<lens-key>` → that judge's ballot).
//
// EXTRACTION IS FULL, not partial: the bracket tournament fence runs end to end (all seven matches), so
// fixture B1 below exercises the real `runMatch` rather than a copy of its tally lines.
//
// RUNTIME SEMANTICS MODELLED HERE (same reading as selftest-scoreboard.mjs, checked 2026-09-05):
//   * `parallel(thunks)` is a barrier and resolves POSITIONALLY: result[k] is thunk k's value, or `null`
//     if that thunk threw or its agent errored. The call itself never rejects. That positional guarantee
//     is what lets the stage map screeningResults[k] back to AXES[k] and bucket a whole axis as dropped.
//   * An agent whose schema retries are exhausted returns `null` — the stage never sees a partial payload.
//
// WHICH KNOWN-BADS ARE LIVE IN THE RUNTIME, AND WHAT THE SCHEMA LAYER ACTUALLY DOES TO THE REST (state
// this honestly or the panel over-claims):
//   * LIVE — the runtime can produce these today and no schema constrains them: a whole axis returning
//     `null` or a malformed container (F1, F10, F17, F18); a screener emitting two entries for one index
//     on one axis (F2, F22, F23); a screener skipping a candidate (F9); a screener scoring an index that
//     dedup killed (F4); a dedup keep-list or a seed list carrying something that is not a candidate
//     index (F14, F15, F16); an empty axis list (F11); an empty kept set (F24); a tie across the realised
//     bracket cut line (F12, F21); a bracket that is not BRACKET_SIZE long (F19, F20); an unscored
//     candidate that must not outrank a real zero (F13). `SCORES_SCHEMA` constrains the SHAPE of one
//     entry — never the coverage, the uniqueness, or the sanity of the set they are scored against.
//   * NOT A FREE EXTRA LAYER — A CHANGE OF BLAST RADIUS. `SCORES_SCHEMA` now carries `minimum`/`maximum`
//     and the numeric type from SCREEN_SCALE, so on the Claude runtime an off-scale or mistyped entry
//     (F3, F5, F6, F7, F8) does not reach the stage. But schema validation there is WHOLE-PAYLOAD: the
//     axis fails, retries, comes back `null` and lands in `dropped` for EVERY candidate — F1's outcome —
//     where pre-fix the same entry cost one candidate a wrong total, F3's outcome. So these five model a
//     RAW-JSON runner (a Codex bracket, a hand-rolled script that drops the schema); the Claude-runtime
//     path for the same input is F1/F17. They are kept because the bound is only as good as the layer
//     that enforces it: the pre-fix schema had NO bounds at all (that is how a 1000 took the top of a
//     measured bracket), and JSON cannot carry NaN, so F7 models a stage fed by hand-built objects rather
//     than by the wire. The corollary for a spec author is in stages.md's SCREEN_SCALE prose — the common
//     failure is not a scale that DISAGREES between the two layers, it is one the screeners overshoot.
//   * The bracket tally's non-enum vote (B1) is the same class: `MATCH_SCHEMA`'s enum forecloses it on
//     the Claude runtime and it stays live for any raw-JSON bracket runner.
//
// CALIBRATION: every known-bad below REDs against the pre-fix stage
// (`git show 5cbf21d:tournament/reference/stages.md`) — but read that RED for what it is, fixture by
// fixture. Most have a pre-fix FAIL line specific to their own defect (F2's "counts the duplicate ONCE",
// F3's "the 1000 is NOT tallied", F13's "the genuine 0 outranks the unscored candidate"). F1 — the
// ticket's headline "a dropped axis moved a candidate from rank 1 to rank 4" — does NOT: its own rank and
// total rows PASS pre-fix, and what reds it is the universal reconciliation rows, which red for a clean
// CONTROL too. That is by design: the fix cannot restore a score no screener returned, so the RANKING is
// identical before and after and the 1 → 4 move is unchanged by the fix; what the fix adds is that the
// run SAYS the axis was lost. The thing that shows `dropped` and `missing` are genuinely discriminated is
// the post-fix corruption round — renaming the dropped bucket to missing, or neutralising it while
// leaving missing alone, reds the four DROPPED-AXIS fixtures (F1, F10, F17, F18) and nothing else. The
// list said "F1 and F10" until it was re-run against the whole panel: F17 and F18 are dropped-axis cases
// too — a malformed CONTAINER is a lost axis, not a skipped candidate — so a bucket mutation has to red
// them, and a list that omits them under-reports the mutation's reach. Re-run the round before editing
// this sentence; the counts belong in the VERDICT line, and the fixture NAMES belong here because they
// are what makes the calibration claim legible at all.
// The fixtures named `CONTROL …` are the known-goods; their ORDERING and TOTAL assertions hold on the
// pre-fix stage too — what reds there is the reconciliation (the pre-fix stage computes no
// `filterReconciliation` and no flag at all), which is why a control is not "green pre-fix" as a whole
// fixture. That whole-panel calibration, not a paired control per row, is what says these fixtures
// discriminate. Counts are printed in the VERDICT line; keep them there rather than in this comment,
// which cannot be checked.
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = dirname(fileURLToPath(import.meta.url))
const mdPath = process.argv[2] || join(HERE, 'stages.md')

// ---------------------------------------------------------------- extract

const H_FILTER_BRACKET = '### Bracket mode (select a fixed-size bracket'
const H_FILTER_SB = '### Scoreboard mode (rank all survivors'
const H_SCHEMA = '### SCORES_SCHEMA'
const H_TOURNEY = '### Bracket mode (single-elimination'
const STANDALONE = 'STANDALONE PARSE ONLY — DELETE at assembly'

function fenceAfter(md, heading, what) {
  const h = md.indexOf(heading)
  if (h < 0) throw new Error(`harness: heading not found in ${mdPath}: ${heading}`)
  const open = md.indexOf('```js', h)
  if (open < 0) throw new Error(`harness: no \`\`\`js fence after the ${what} heading`)
  const bodyStart = md.indexOf('\n', open) + 1
  const close = md.indexOf('\n```', bodyStart)
  if (close < 0) throw new Error(`harness: unterminated \`\`\`js fence for the ${what}`)
  return md.slice(bodyStart, close)
}

function deleteStubs(fence, what) {
  const lines = fence.split('\n')
  const kept = lines.filter(l => !l.includes(STANDALONE))
  if (kept.length === lines.length) throw new Error(`harness: no STANDALONE stub lines in the ${what} — extraction is off`)
  return kept.join('\n')
}

// Whether SCREEN_SCALE exists at all, and which block declares it, is the thing UNDER TEST (the coupling
// checks at the end), never an extraction precondition: the pre-fix catalog this harness is calibrated
// against declares no SCREEN_SCALE anywhere, and a harness that cannot run its own known-bad is not
// calibrated. Extraction only has to find the fences and the stub convention.
function extractFilter(md, heading, what) {
  const schema = fenceAfter(md, H_SCHEMA, 'SCORES_SCHEMA block')
  return schema + '\n' + deleteStubs(fenceAfter(md, heading, what), what)
}
const extractTourney = (md) => deleteStubs(fenceAfter(md, H_TOURNEY, 'bracket tournament stage'), 'bracket tournament stage')

// Source-level mutations. Two fixtures need a slot the catalog declares as a `const`, so the harness edits
// that one declaration and ASSERTS the edit matched — a silent no-op would turn the fixture green for the
// wrong reason. Both regexes accept the scoreboard block's `_SB` suffix so one mutation serves both modes.
const MUTATIONS = {
  integerScale: {
    what: 'SCREEN_SCALE.integer := true',
    apply: (b) => {
      const re = /(const\s+SCREEN_SCALE\s*=\s*\{[^}]*?integer\s*:\s*)false/
      return re.test(b) ? b.replace(re, '$1true') : null
    },
  },
  noAxes: {
    what: 'AXES := [] (no screening axes at all)',
    apply: (b) => {
      const re = /const\s+AXES(_SB)?\s*=\s*\[[\s\S]*?\n\]/
      return re.test(b) ? b.replace(re, (m, sfx) => `const AXES${sfx || ''} = []`) : null
    },
  },
}

// ---------------------------------------------------------------- fake runtime

const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor
const harnessError = (msg) => Object.assign(new Error('harness: ' + msg), { __harness: true })

// A `return` the pre-fix stage can survive: bindings it never declares read as undefined instead of
// throwing a ReferenceError that would flatten every fixture into the same uninformative RED. The `_SB`
// fallbacks are how one TAIL serves both mode blocks — scoreboard mode aliases the contract names at the
// end of its block, but its mode-local bindings keep the suffix.
const TAIL_FILTER = `
;return {
  kept: typeof kept === 'undefined' ? undefined : kept,
  totals: typeof totals === 'undefined' ? undefined : totals,
  ranked: typeof ranked === 'undefined' ? undefined : ranked,
  bracket: typeof bracket === 'undefined' ? undefined : bracket,
  shortlist: typeof shortlist === 'undefined' ? undefined : shortlist,
  filterReconciliation: typeof filterReconciliation === 'undefined' ? undefined : filterReconciliation,
  filterNeedsAdjudication: typeof filterNeedsAdjudication === 'undefined' ? undefined : filterNeedsAdjudication,
  orphans: typeof filterOrphans !== 'undefined' ? filterOrphans : (typeof filterOrphansSB === 'undefined' ? undefined : filterOrphansSB),
  axes: typeof AXES !== 'undefined' ? AXES : (typeof AXES_SB === 'undefined' ? undefined : AXES_SB),
  bracketSize: typeof BRACKET_SIZE === 'undefined' ? undefined : BRACKET_SIZE,
  screenScale: typeof SCREEN_SCALE === 'undefined' ? undefined : SCREEN_SCALE,
  scoresSchema: typeof SCORES_SCHEMA === 'undefined' ? undefined : SCORES_SCHEMA,
}
`
const TAIL_TOURNEY = `
;return {
  matchLog: typeof matchLog === 'undefined' ? undefined : matchLog,
  champion: typeof champion === 'undefined' ? undefined : champion,
  runnerUp: typeof runnerUp === 'undefined' ? undefined : runnerUp,
}
`

const fakeParallel = async (fns) => Promise.all(fns.map(async (f) => {
  try { return await f() } catch (e) { if (e && e.__harness) throw e; return null }
}))

async function runFilter(body, fx) {
  const logs = []
  const log = (m) => logs.push(String(m))
  const agent = async (_prompt, opts) => {
    const label = (opts && opts.label) || ''
    if (label === 'filter:dedup') return fx.dedup === undefined ? { keep: fx.candidates.map((_, i) => i), notes: '' } : fx.dedup
    const m = /^screen:(.+)$/.exec(label)
    if (m) {
      if (!Object.prototype.hasOwnProperty.call(fx.axes, m[1]))
        throw harnessError(`fixture "${fx.name}" has no payload for axis ${JSON.stringify(m[1])}`)
      return fx.axes[m[1]]
    }
    throw harnessError(`fixture "${fx.name}" got an unexpected agent label ${JSON.stringify(label)}`)
  }
  const renderIndexed = (idxs) => idxs.map(i => `[${i}] ${JSON.stringify(fx.candidates[i])}`).join('\n\n')
  const KEEP_SCHEMA = { type: 'object', properties: { keep: { type: 'array', items: { type: 'integer' } }, notes: { type: 'string' } }, required: ['keep', 'notes'] }
  // NOTE: SCREEN_SCALE and SCORES_SCHEMA are NOT parameters — the assembled body declares both.
  const fn = new AsyncFunction(
    'candidates', 'seedIndices', 'briefs', 'renderIndexed',
    'agent', 'parallel', 'log', 'WORKHORSE', 'KEEP_SCHEMA', body + TAIL_FILTER)
  const out = await fn(fx.candidates, fx.seedIndices || [], {}, renderIndexed,
    agent, fakeParallel, log, 'claude-opus-5', KEEP_SCHEMA)
  return { ...out, logs }
}

async function runTourney(body, fx) {
  const logs = []
  const log = (m) => logs.push(String(m))
  const agent = async (_prompt, opts) => fx.vote((opts && opts.label) || '')
  const renderConcept = (c) => JSON.stringify(c)
  const MATCH_SCHEMA = { type: 'object', properties: { winner: { type: 'string', enum: ['A', 'B'] }, reason: { type: 'string' } }, required: ['winner', 'reason'] }
  const fn = new AsyncFunction(
    'candidates', 'bracket', 'briefs', 'renderConcept', 'MATCH_SCHEMA',
    'agent', 'parallel', 'log', 'WORKHORSE', body + TAIL_TOURNEY)
  const out = await fn(fx.candidates, fx.bracket, {}, renderConcept, MATCH_SCHEMA,
    agent, fakeParallel, log, 'claude-opus-5')
  return { ...out, logs }
}

// ---------------------------------------------------------------- fixture helpers

const named = (n) => Array.from({ length: n }, (_, i) => ({ name: `c${i}` }))
const CANDS5 = named(5)
const CANDS10 = named(10)
const CANDS8 = named(8)

// A screener payload: `P([0, 9], [1, 4])` → two entries; a raw object passes through untouched so a
// fixture can emit a malformed entry the helper would not build.
const P = (...entries) => ({ scores: entries.map(e => (Array.isArray(e) ? { index: e[0], score: e[1], reason: 'r' } : e)) })
// Half of each total on each of the two axes, so `spread([20, 18])` gives c0 total 20 and c1 total 18.
const spread = (totals) => [
  P(...totals.map((t, i) => [i, t / 2])),
  P(...totals.map((t, i) => [i, t / 2])),
]
const axes2 = ([a, b]) => ({ 'axis-a': a, 'axis-b': b })

const rowOf = (r, i) => (r.filterReconciliation || []).find(x => x && x.index === i)
const totalOf = (r, i) => (r.totals instanceof Map ? r.totals.get(i) : undefined)
const eq = (a, b) => JSON.stringify(a) === JSON.stringify(b)
const namedInWarn = (r, i) => (r.logs || []).some(l => l.includes('⚠') && l.includes(`[${i}]`))
const adjWarn = (r) => (r.logs || []).some(l => l.includes('⚠') && l.includes('needsAdjudication'))

// The measured 1 → 4 known-bad. With BOTH axes c0 leads on 16.5; with axis-a gone it falls to fourth.
const RANK_MOVE_A = P([0, 10], [1, 2], [2, 3], [3, 4], [4, 1])
const RANK_MOVE_B = P([0, 6.5], [1, 8], [2, 7], [3, 5], [4, 9])

// Asserted on EVERY filter fixture in BOTH modes: these are stage-wide properties, so they are checked
// once here instead of being restated per fixture. A silent reconciliation is worth as little as none.
const universal = (r) => {
  const rows = Array.isArray(r.filterReconciliation) ? r.filterReconciliation : null
  const kept = Array.isArray(r.kept) ? r.kept : null
  const shaped = (x) => !!x && Number.isInteger(x.axesSent) && Number.isInteger(x.axesReturned)
    && Number.isInteger(x.dropped) && Number.isInteger(x.missing) && Array.isArray(x.errored)
    && (x.total === null || Number.isFinite(x.total))
  const noisy = rows ? rows.filter(x => x.axesReturned < x.axesSent || x.errored.length > 0) : []
  const rank = (i) => { const t = totalOf(r, i); return t === null || t === undefined ? -Infinity : t }
  const sortedRight = Array.isArray(r.ranked) && r.ranked.every((v, k) => {
    if (k === 0) return true
    const p = r.ranked[k - 1]
    return rank(p) > rank(v) || (rank(p) === rank(v) && p < v)
  })
  return [
    ['[all] filterReconciliation has one row per kept index, in kept order', !!rows && !!kept && eq(rows.map(x => x.index), kept)],
    ['[all] every row carries axesSent/axesReturned/dropped/errored/missing/total', !!rows && rows.every(shaped)],
    // The disjointness invariant: per axis a kept index is returned, dropped or missing — never two of them.
    ['[all] axis buckets are disjoint (axesSent = axesReturned + dropped + missing)',
      !!rows && rows.every(x => x.axesSent === x.axesReturned + x.dropped + x.missing)],
    ['[all] totals has exactly the kept keys and matches each row total',
      r.totals instanceof Map && !!rows && r.totals.size === rows.length && rows.every(x => totalOf(r, x.index) === x.total)],
    ['[all] ranked is a permutation of kept', !!kept && Array.isArray(r.ranked) && eq([...r.ranked].sort((a, b) => a - b), [...kept].sort((a, b) => a - b))],
    ['[all] ranked is null-last, desc by total, ties to the LOWER index', sortedRight],
    ['[all] the needsAdjudication ⚠ log appears iff the flag is set', adjWarn(r) === (r.filterNeedsAdjudication === true)],
    ['[all] every shortfallen/errored row is NAMED in a ⚠ log', noisy.every(x => namedInWarn(r, x.index))],
  ]
}

// ---------------------------------------------------------------- filter fixtures

const FIXTURES = [
  {
    name: 'CONTROL clean panel (2 full axes, distinct totals)',
    candidates: CANDS5, axes: axes2([RANK_MOVE_A, RANK_MOVE_B]),
    expect: (r) => [
      ['c0 leads on the full panel (total 16.5)', totalOf(r, 0) === 16.5 && r.ranked[0] === 0],
      ['ranked is the full-panel order', eq(r.ranked, [0, 1, 2, 4, 3])],
      ['every row got both axes', (r.filterReconciliation || []).every(x => x.axesReturned === 2 && x.dropped === 0 && x.missing === 0)],
      ['no row has an errored entry', (r.filterReconciliation || []).every(x => x.errored.length === 0)],
      ['no orphan entries', Array.isArray(r.orphans) && r.orphans.length === 0],
    ],
    // The SCREENING is clean here and the BRACKET is not: five candidates cannot fill eight slots, and
    // the tournament stage indexes bracket[0..7] unguarded. The control records that fault rather than
    // certifying a producer output that crashes its own consumer — which is why the flag row lives per
    // mode. Scoreboard mode shortlists everyone and has no bracket to come up short, so it stays false.
    expectBracket: (r) => [
      ['bracket holds all five kept candidates', eq(r.bracket, [0, 1, 2, 4, 3])],
      ['the SHORT bracket sets the flag even though every reconciliation row is clean', r.filterNeedsAdjudication === true],
      ['the ⚠ log names the bracket length, not a screening fault', (r.logs || []).some(l => l.includes('⚠') && l.includes('bracket is 5 long'))],
    ],
    expectSB: (r) => [
      ['scoreboard mode has no bracket to come up short — the clean panel does NOT flag', r.filterNeedsAdjudication === false],
    ],
  },
  {
    // The measured known-bad: one axis returns nothing and c0 goes from rank 1 to rank 4. The RANKING is
    // the same before and after the fix — that is the point. What the fix adds is that the run SAYS an
    // axis was lost instead of presenting a half-screened order as a finished one.
    name: 'F1 a whole axis returns null — the measured rank 1 → 4 move',
    candidates: CANDS5, axes: axes2([null, RANK_MOVE_B]),
    expect: (r) => [
      ['c0 has fallen to rank 4 (index 3 of ranked)', r.ranked.indexOf(0) === 3],
      ['ranked follows the surviving axis', eq(r.ranked, [4, 1, 2, 0, 3])],
      ['c0 total is the surviving axis only (6.5), not a silent 16.5', totalOf(r, 0) === 6.5],
      ['every row records dropped === 1', (r.filterReconciliation || []).every(x => x.dropped === 1)],
      ['every row records axesSent 2 / axesReturned 1', (r.filterReconciliation || []).every(x => x.axesSent === 2 && x.axesReturned === 1)],
      ['the lost axis is NOT counted as missing', (r.filterReconciliation || []).every(x => x.missing === 0)],
      ['filterNeedsAdjudication === true', r.filterNeedsAdjudication === true],
    ],
  },
  {
    name: 'F2 duplicate index on one axis (the second entry must not double-count)',
    candidates: CANDS5,
    axes: axes2([P([0, 9], [0, 9], [1, 2], [2, 3], [3, 4], [4, 1]), RANK_MOVE_B]),
    expect: (r) => [
      ['c0 total counts the duplicate ONCE (9 + 6.5 = 15.5), not twice', totalOf(r, 0) === 15.5],
      ['c0 records exactly one errored entry', rowOf(r, 0)?.errored.length === 1],
      ['the errored entry names the duplicate', /duplicate/.test((rowOf(r, 0)?.errored || [])[0] || '')],
      ['the FIRST entry still stands — c0 got both axes', rowOf(r, 0)?.axesReturned === 2 && rowOf(r, 0)?.missing === 0],
      ['no other row errored', (r.filterReconciliation || []).filter(x => x.errored.length).length === 1],
      ['filterNeedsAdjudication === true', r.filterNeedsAdjudication === true],
    ],
  },
  {
    name: 'F3 score 1000 (the measured out-of-scale entry that took the top)',
    candidates: CANDS5,
    axes: axes2([P([0, 1000], [1, 2], [2, 3], [3, 4], [4, 1]), RANK_MOVE_B]),
    expect: (r) => [
      ['the 1000 is NOT tallied — c0 total is the other axis only (6.5)', totalOf(r, 0) === 6.5],
      ['c0 does NOT take the top', r.ranked[0] !== 0],
      ['ranked puts c0 LAST on its one surviving axis', eq(r.ranked, [1, 2, 4, 3, 0])],
      ['c0 has an errored entry naming the scale', (rowOf(r, 0)?.errored || []).some(e => /outside 0\.\.10/.test(e))],
      ['c0 records axesReturned 1 and missing 1', rowOf(r, 0)?.axesReturned === 1 && rowOf(r, 0)?.missing === 1],
      ['filterNeedsAdjudication === true', r.filterNeedsAdjudication === true],
    ],
  },
  {
    name: 'F4 an index outside the kept set (dedup killed it)',
    candidates: CANDS5, dedup: { keep: [0, 1, 2, 3], notes: '' },
    axes: axes2([P([0, 10], [1, 2], [2, 3], [3, 4], [4, 1]), P([0, 6.5], [1, 8], [2, 7], [3, 5], [4, 9])]),
    expect: (r) => [
      ['kept is exactly the dedup list', eq(r.kept, [0, 1, 2, 3])],
      ['the killed index never creates a totals key', r.totals instanceof Map && !r.totals.has(4)],
      ['the killed index gets no reconciliation row', !rowOf(r, 4)],
      ['both stray entries are recorded as orphans', Array.isArray(r.orphans) && r.orphans.length === 2],
      ['an orphan reason names the kept set as a MEMBERSHIP fault, not a type fault', (r.orphans || []).some(e => /index 4 is not in the kept set/.test(e))],
      ['a ⚠ log reports the out-of-kept-set entries', (r.logs || []).some(l => l.includes('⚠') && l.includes('outside the kept set'))],
      ['the surviving four are fully screened', (r.filterReconciliation || []).every(x => x.axesReturned === 2)],
      ['filterNeedsAdjudication === true', r.filterNeedsAdjudication === true],
    ],
  },
  {
    name: 'F5 a negative score (below the scale minimum)',
    candidates: CANDS5,
    axes: axes2([P([0, -1], [1, 2], [2, 3], [3, 4], [4, 1]), RANK_MOVE_B]),
    expect: (r) => [
      ['the -1 is NOT tallied — c0 total is 6.5, not 5.5', totalOf(r, 0) === 6.5],
      ['c0 has an errored entry naming the scale', (rowOf(r, 0)?.errored || []).some(e => /outside 0\.\.10/.test(e))],
      ['c0 records axesReturned 1 and missing 1', rowOf(r, 0)?.axesReturned === 1 && rowOf(r, 0)?.missing === 1],
      ['filterNeedsAdjudication === true', r.filterNeedsAdjudication === true],
    ],
  },
  {
    name: 'F6 a string score "8" (defence in depth — the schema pins number)',
    candidates: CANDS5,
    axes: axes2([P([0, '8'], [1, 2], [2, 3], [3, 4], [4, 1]), RANK_MOVE_B]),
    expect: (r) => [
      ['the string is not concatenated — c0 total is 6.5', totalOf(r, 0) === 6.5],
      ['c0 total is a finite number', Number.isFinite(totalOf(r, 0))],
      ['c0 has an errored entry naming the type', (rowOf(r, 0)?.errored || []).some(e => /not a finite number/.test(e))],
      ['filterNeedsAdjudication === true', r.filterNeedsAdjudication === true],
    ],
  },
  {
    name: 'F7 NaN and Infinity scores (defence in depth — JSON cannot carry either)',
    candidates: CANDS5,
    axes: axes2([P([0, NaN], [1, Infinity], [2, 3], [3, 4], [4, 1]), RANK_MOVE_B]),
    expect: (r) => [
      ['the NaN is not tallied — c0 total is 6.5, not NaN', totalOf(r, 0) === 6.5],
      ['the Infinity is not tallied — c1 total is 8, not Infinity', totalOf(r, 1) === 8],
      ['no total is NaN or Infinite', (r.filterReconciliation || []).every(x => x.total === null || Number.isFinite(x.total))],
      ['both rows carry an errored entry', rowOf(r, 0)?.errored.length === 1 && rowOf(r, 1)?.errored.length === 1],
      ['filterNeedsAdjudication === true', r.filterNeedsAdjudication === true],
    ],
  },
  {
    name: 'F8 a non-integer score under SCREEN_SCALE.integer',
    mutation: 'integerScale',
    candidates: CANDS5, axes: axes2([RANK_MOVE_A, RANK_MOVE_B]),
    expect: (r) => [
      ['the harness mutation reached the stage', r.screenScale && r.screenScale.integer === true],
      // The one declaration reaches BOTH layers: the schema's `type` follows SCREEN_SCALE.integer the way
      // its bounds follow min/max, so an integer scale is enforced by the runtime as well as by the stage.
      ['the mutated scale reaches the SCHEMA too — SCORES_SCHEMA score.type is "integer"',
        r.scoresSchema?.properties?.scores?.items?.properties?.score?.type === 'integer'],
      ['the one fractional score in the panel (c0 on axis-b) errored, and only it', (r.filterReconciliation || []).filter(x => x.errored.length).length === 1],
      ['c0 (6.5 on axis-b) keeps only its integer axis', totalOf(r, 0) === 10 && rowOf(r, 0)?.axesReturned === 1],
      ['c1 (whole numbers on both axes) is untouched', totalOf(r, 1) === 10 && rowOf(r, 1)?.errored.length === 0],
      ['filterNeedsAdjudication === true', r.filterNeedsAdjudication === true],
    ],
  },
  {
    name: 'F9 a screener skips a candidate entirely',
    candidates: CANDS5,
    axes: axes2([P([0, 10], [1, 2], [3, 4], [4, 1]), RANK_MOVE_B]),
    expect: (r) => [
      ['c2 records missing === 1', rowOf(r, 2)?.missing === 1],
      ['c2 records axesReturned 1 of 2, and NOT as a drop', rowOf(r, 2)?.axesReturned === 1 && rowOf(r, 2)?.dropped === 0],
      ['c2 has no errored entry — nothing came back to void', rowOf(r, 2)?.errored.length === 0],
      ['c2 total is the one axis it did get (7)', totalOf(r, 2) === 7],
      ['every other row got both axes', (r.filterReconciliation || []).filter(x => x.index !== 2).every(x => x.axesReturned === 2)],
      ['filterNeedsAdjudication === true', r.filterNeedsAdjudication === true],
    ],
  },
  {
    name: 'F10 every screener returns null',
    candidates: CANDS5, axes: axes2([null, null]),
    expect: (r) => [
      ['every total is null, never 0', (r.filterReconciliation || []).every(x => x.total === null)],
      ['every row records dropped === 2', (r.filterReconciliation || []).every(x => x.dropped === 2)],
      ['ranked is deterministic by index when nothing scored', eq(r.ranked, [0, 1, 2, 3, 4])],
      ['filterNeedsAdjudication === true', r.filterNeedsAdjudication === true],
    ],
  },
  {
    name: 'F11 no screening axes at all (AXES = [])',
    mutation: 'noAxes',
    candidates: CANDS5, axes: {},
    expect: (r) => [
      ['the harness mutation reached the stage', Array.isArray(r.axes) && r.axes.length === 0],
      ['every total is null', (r.filterReconciliation || []).every(x => x.total === null)],
      ['axesSent is 0 for every row', (r.filterReconciliation || []).every(x => x.axesSent === 0)],
      ['ranked is deterministic by index', eq(r.ranked, [0, 1, 2, 3, 4])],
      ['filterNeedsAdjudication === true', r.filterNeedsAdjudication === true],
    ],
  },
  {
    // c7 and c8 tie on 10 across the 8-slot cut, so which of them makes the bracket rests on index order
    // alone. Scoreboard mode shortlists everyone and has no cut line, which is why it must NOT flag here —
    // that asymmetry is the discriminator for the cut-line term.
    name: 'F12 a tie in total across the bracket cut line',
    candidates: CANDS10, axes: axes2(spread([20, 19, 18, 17, 16, 15, 14, 10, 10, 5])),
    expect: (r) => [
      ['c7 and c8 really are tied on 10', totalOf(r, 7) === 10 && totalOf(r, 8) === 10],
      ['ranked breaks the tie to the LOWER index', r.ranked.indexOf(7) < r.ranked.indexOf(8)],
      ['no row is short of its axes', (r.filterReconciliation || []).every(x => x.axesReturned === 2)],
      ['no row errored', (r.filterReconciliation || []).every(x => x.errored.length === 0)],
    ],
    expectBracket: (r) => [
      ['the bracket is still 8 long', (r.bracket || []).length === 8],
      ['the bracket is the deterministic top 8', eq(r.bracket, [0, 1, 2, 3, 4, 5, 6, 7])],
      ['filterNeedsAdjudication === true (the cut line is arbitrary)', r.filterNeedsAdjudication === true],
    ],
    expectSB: (r) => [
      ['scoreboard mode shortlists everyone, so there is no cut line to tie', (r.shortlist || []).length === 10],
      ['filterNeedsAdjudication === false in scoreboard mode', r.filterNeedsAdjudication === false],
    ],
  },
  {
    name: 'CONTROL a 7.5 is valid on the default (non-integer) scale',
    candidates: CANDS5, axes: axes2(spread([15, 14, 12, 10, 8])),
    expect: (r) => [
      ['c0 total is 15 from two 7.5s', totalOf(r, 0) === 15],
      ['c0 has an errored ARRAY and it is empty', Array.isArray(rowOf(r, 0)?.errored) && rowOf(r, 0).errored.length === 0],
      ['ranked is the total order', eq(r.ranked, [0, 1, 2, 3, 4])],
      ['no row is short of its axes and none errored', (r.filterReconciliation || []).every(x => x.axesReturned === 2 && x.errored.length === 0)],
    ],
    // Same five-candidate/eight-slot split as the clean-panel control above.
    expectBracket: (r) => [['only the short bracket flags', r.filterNeedsAdjudication === true && (r.bracket || []).length === 5]],
    expectSB: (r) => [['filterNeedsAdjudication === false', r.filterNeedsAdjudication === false]],
  },
  {
    // A real 0 and "no valid score" are different facts. c0 is deliberately the LOWER index: a sentinel of
    // 0 instead of -Infinity would tie the two and hand the top to the unscored one on the index tie-break.
    // Named as a known-bad, not a CONTROL, because it MEASURABLY reds on the pre-fix stage: there the two
    // 99s were tallied and c0 took the top. Same fixture and same name convention as the scoreboard
    // harness's `L4 an unscored candidate must rank BELOW a candidate that genuinely scored 0`.
    name: 'F13 an unscored candidate must rank BELOW a candidate that genuinely scored 0',
    candidates: CANDS5,
    axes: axes2([P([0, 99], [1, 0], [2, 3], [3, 2], [4, 1]), P([0, 99], [1, 0], [2, 3], [3, 2], [4, 1])]),
    expect: (r) => [
      ['c1 total is 0 — a real score, not an absence', totalOf(r, 1) === 0],
      ['c0 is unscored (null) with both entries voided', totalOf(r, 0) === null && rowOf(r, 0)?.errored.length === 2],
      ['the genuine 0 outranks the unscored candidate', r.ranked.indexOf(1) < r.ranked.indexOf(0)],
      ['the unscored candidate is LAST', r.ranked[r.ranked.length - 1] === 0],
      ['filterNeedsAdjudication === true', r.filterNeedsAdjudication === true],
    ],
  },
  {
    name: 'CONTROL a seed dedup killed is force-kept and lands in the bracket',
    candidates: CANDS10, seedIndices: [9], dedup: { keep: [0, 1, 2, 3, 4, 5, 6, 7, 8], notes: '' },
    axes: axes2(spread([20, 18, 16, 14, 12, 10, 8, 6, 4, 2])),
    expect: (r) => [
      ['the seed is back in kept despite dedup dropping it', (r.kept || []).includes(9)],
      ['the seed is ranked on its own (last) total', r.ranked[r.ranked.length - 1] === 9],
      ['no row is short of its axes', (r.filterReconciliation || []).every(x => x.axesReturned === 2)],
      ['filterNeedsAdjudication === false', r.filterNeedsAdjudication === false],
    ],
    expectBracket: (r) => [
      ['the bracket is 8 long', (r.bracket || []).length === 8],
      ['the seed is IN the bracket regardless of total', (r.bracket || []).includes(9)],
      ['it displaced the highest-scoring non-seed below the cut (c7)', !(r.bracket || []).includes(7)],
      ['the bracket is ordered desc by total (the pairing contract), so the seed sits LAST', eq(r.bracket, [0, 1, 2, 3, 4, 5, 6, 9])],
    ],
  },
  {
    name: 'CONTROL dedup returns nothing — kept falls back to every candidate',
    candidates: CANDS5, dedup: null, axes: axes2([RANK_MOVE_A, RANK_MOVE_B]),
    expect: (r) => [
      ['kept is every index', eq(r.kept, [0, 1, 2, 3, 4])],
      ['ranked is the full-panel order', eq(r.ranked, [0, 1, 2, 4, 3])],
      ['no row is short of its axes and none errored', (r.filterReconciliation || []).every(x => x.axesReturned === 2 && x.errored.length === 0)],
    ],
    // Same five-candidate/eight-slot split as the clean-panel control above.
    expectBracket: (r) => [['only the short bracket flags', r.filterNeedsAdjudication === true && (r.bracket || []).length === 5]],
    expectSB: (r) => [['filterNeedsAdjudication === false', r.filterNeedsAdjudication === false]],
  },
  {
    // The stage validates every screener entry against the kept set and never validated the kept set
    // itself: `.filter(i => i >= 0 && i < candidates.length)` admits `null` (`null >= 0` is true), `1.5`
    // and `true`, each of which then gets a phantom reconciliation row, is misdiagnosed as `missing`, and
    // reaches `candidates[i]` in the result shape, where it throws.
    name: 'F14 the dedup keep-list carries a non-integer index',
    candidates: CANDS5, dedup: { keep: [0, 1.5, 2], notes: '' },
    axes: axes2([P([0, 8], [2, 6]), P([0, 7], [2, 5])]),
    expect: (r) => [
      ['the non-integer index never enters kept', eq(r.kept, [0, 2])],
      ['it gets no reconciliation row', !rowOf(r, 1.5)],
      ['it never creates a totals key', r.totals instanceof Map && !r.totals.has(1.5)],
      ['no row is falsely reported as missing an axis', (r.filterReconciliation || []).every(x => x.axesReturned === 2 && x.missing === 0)],
      ['nothing errored — the fault was in the keep-list, not in a screener entry', (r.filterReconciliation || []).every(x => x.errored.length === 0)],
    ],
    expectBracket: (r) => [['only the short bracket flags', r.filterNeedsAdjudication === true && (r.bracket || []).length === 2]],
    expectSB: (r) => [['a repaired keep-list is not itself an adjudication cause', r.filterNeedsAdjudication === false]],
  },
  {
    // seedIndices is pushed straight into kept with no predicate at all, so a seed of 99 over 5
    // candidates survives into `bracket` and `shortlist` and kills the result shape.
    name: 'F15 a seed index that is not a candidate index',
    candidates: CANDS5, seedIndices: [99], axes: axes2([RANK_MOVE_A, RANK_MOVE_B]),
    expect: (r) => [
      ['the bogus seed is NOT force-kept', !(r.kept || []).includes(99)],
      ['kept is exactly the real candidates', eq(r.kept, [0, 1, 2, 3, 4])],
      ['it never creates a totals key', r.totals instanceof Map && !r.totals.has(99)],
      ['the rejection is recorded in filterOrphans', (r.orphans || []).some(e => /seed 99 is not a valid candidate index/.test(e))],
      ['a ⚠ log names the rejected seed', (r.logs || []).some(l => l.includes('⚠') && l.includes('seed index(es) REJECTED'))],
      ['filterNeedsAdjudication === true', r.filterNeedsAdjudication === true],
    ],
    expectBracket: (r) => [['the bogus seed is not in the bracket', !(r.bracket || []).includes(99)]],
    expectSB: (r) => [['the bogus seed is not in the shortlist', !(r.shortlist || []).includes(99)]],
  },
  {
    // `dedup.keep` was tested for truthiness, not for being an array, so a string `keep` reached
    // `.filter` and threw before the stage produced anything at all.
    name: 'F16 dedup returns a non-array keep',
    candidates: CANDS5, dedup: { keep: '012', notes: '' }, axes: axes2([RANK_MOVE_A, RANK_MOVE_B]),
    expect: (r) => [
      ['the stage does not throw', !r.__threw],
      ['kept falls back to every candidate', eq(r.kept, [0, 1, 2, 3, 4])],
      ['the fallback panel screens normally', (r.filterReconciliation || []).every(x => x.axesReturned === 2)],
    ],
    expectBracket: (r) => [['only the short bracket flags', r.filterNeedsAdjudication === true && (r.bracket || []).length === 5]],
    expectSB: (r) => [['a repaired keep-list is not itself an adjudication cause', r.filterNeedsAdjudication === false]],
  },
  {
    // The drop guard was `if (!res)`, so any truthy non-payload passed it and `res.scores || []` yielded
    // nothing — filing "the axis was LOST" as "the axis SKIPPED this candidate" for every row, which is
    // the exact distinction the disjointness law exists to record.
    name: 'F17 an axis returns a truthy non-payload',
    candidates: CANDS5, axes: { 'axis-a': 'ok', 'axis-b': RANK_MOVE_B },
    expect: (r) => [
      ['the lost axis is a DROP for every row', (r.filterReconciliation || []).every(x => x.dropped === 1)],
      ['it is NOT filed as missing', (r.filterReconciliation || []).every(x => x.missing === 0)],
      ['every row still got the surviving axis', (r.filterReconciliation || []).every(x => x.axesReturned === 1)],
      ['c0 total is the surviving axis only (6.5)', totalOf(r, 0) === 6.5],
      ['a ⚠ log says the payload had no scores ARRAY', (r.logs || []).some(l => l.includes('⚠') && l.includes('no scores ARRAY'))],
      ['filterNeedsAdjudication === true', r.filterNeedsAdjudication === true],
    ],
  },
  {
    // A non-iterable `scores` threw inside screeningResults.forEach — AFTER parallel()'s barrier, where
    // neither the runtime's null-catch nor the harness's can see it, so the whole workflow died.
    name: 'F18 an axis returns a non-iterable scores',
    candidates: CANDS5, axes: { 'axis-a': { scores: 5 }, 'axis-b': RANK_MOVE_B },
    expect: (r) => [
      ['the stage does not throw', !r.__threw],
      ['the malformed axis is a DROP for every row', (r.filterReconciliation || []).every(x => x.dropped === 1 && x.missing === 0)],
      ['c0 total is the surviving axis only (6.5)', totalOf(r, 0) === 6.5],
      ['filterNeedsAdjudication === true', r.filterNeedsAdjudication === true],
    ],
  },
  {
    // As many reserved seeds as slots: the seed loop had no length guard, so `bracket` overflowed
    // BRACKET_SIZE, the flag stayed false, and the pairings (hard-wired to bracket[0..7]) never played
    // the tail — those seeds appear in the emitted bracket and in no match.
    name: 'F19 more reserved seeds than bracket slots',
    candidates: named(12), seedIndices: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    axes: axes2(spread([20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9])),
    expect: (r) => [
      ['every seed is kept', [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].every(i => (r.kept || []).includes(i))],
      ['no row is short of its axes', (r.filterReconciliation || []).every(x => x.axesReturned === 2)],
    ],
    expectBracket: (r) => [
      ['the seeds are NOT truncated to fit', (r.bracket || []).length === 10],
      ['the overflow sets the flag', r.filterNeedsAdjudication === true],
      ['a ⚠ log names the overflow', (r.logs || []).some(l => l.includes('⚠') && l.includes('bracket is 10 long') && l.includes('never plays'))],
    ],
    expectSB: (r) => [
      ['scoreboard mode shortlists everyone and has no size fault', r.filterNeedsAdjudication === false && (r.shortlist || []).length === 12],
    ],
  },
  {
    // The other direction: dedup left fewer survivors than there are slots. The tournament stage reads
    // `bracket[7].name` unguarded, so this is a crash downstream, not a cosmetic shortfall.
    name: 'F20 fewer survivors than bracket slots',
    candidates: CANDS10, dedup: { keep: [0, 1, 2, 3, 4], notes: '' },
    axes: axes2([P([0, 10], [1, 9], [2, 8], [3, 7], [4, 6]), P([0, 10], [1, 9], [2, 8], [3, 7], [4, 6])]),
    expect: (r) => [
      ['kept is the dedup list', eq(r.kept, [0, 1, 2, 3, 4])],
      ['no row is short of its axes and none errored', (r.filterReconciliation || []).every(x => x.axesReturned === 2 && x.errored.length === 0)],
      ['no orphan entries', Array.isArray(r.orphans) && r.orphans.length === 0],
    ],
    expectBracket: (r) => [
      ['the bracket is 5 long, not 8', (r.bracket || []).length === 5],
      ['the shortfall sets the flag', r.filterNeedsAdjudication === true],
      ['a ⚠ log says the tournament stage will THROW', (r.logs || []).some(l => l.includes('⚠') && l.includes('bracket is 5 long') && l.includes('THROW'))],
    ],
    expectSB: (r) => [['scoreboard mode has no fixed size, so it does not flag', r.filterNeedsAdjudication === false]],
  },
  {
    // A reserved seed is admitted regardless of total, so it MOVES the cut line: with one seed the
    // ranking decides seven slots, not eight. Checked at ranked[7] vs ranked[8] the real tie between c6
    // and c7 — the pair the cut actually separates — is invisible.
    name: 'F21 a tie across the REALISED cut line, moved by a reserved seed',
    candidates: CANDS10, seedIndices: [9],
    axes: axes2(spread([20, 19, 18, 17, 16, 15, 10, 10, 5, 2])),
    expect: (r) => [
      ['c6 and c7 really are tied on 10', totalOf(r, 6) === 10 && totalOf(r, 7) === 10],
      ['no row is short of its axes and none errored', (r.filterReconciliation || []).every(x => x.axesReturned === 2 && x.errored.length === 0)],
      ['no orphan entries', Array.isArray(r.orphans) && r.orphans.length === 0],
    ],
    expectBracket: (r) => [
      ['the bracket is 8 long, so no size fault can be doing the work', (r.bracket || []).length === 8],
      ['the seed took the eighth slot and c7 is out', eq(r.bracket, [0, 1, 2, 3, 4, 5, 6, 9])],
      ['the tie at the realised cut sets the flag', r.filterNeedsAdjudication === true],
      ['the ⚠ log names the cut line', (r.logs || []).some(l => l.includes('⚠') && l.includes('TIED across the bracket cut line'))],
    ],
    expectSB: (r) => [['no cut line in scoreboard mode', r.filterNeedsAdjudication === false]],
  },
  {
    // The converse control for F21: c7 and c8 tie, but BELOW the realised cut, so neither is in
    // contention and flagging it would report a doubt the run does not have.
    name: 'CONTROL a tie BELOW the realised cut line does not flag',
    candidates: CANDS10, seedIndices: [9],
    axes: axes2(spread([20, 19, 18, 17, 16, 15, 14, 10, 10, 2])),
    expect: (r) => [
      ['c7 and c8 really are tied on 10', totalOf(r, 7) === 10 && totalOf(r, 8) === 10],
      ['no row is short of its axes', (r.filterReconciliation || []).every(x => x.axesReturned === 2)],
    ],
    expectBracket: (r) => [
      ['the bracket is 8 long', (r.bracket || []).length === 8],
      ['both tied candidates are excluded', !(r.bracket || []).includes(7) && !(r.bracket || []).includes(8)],
      ['a tie between two EXCLUDED candidates does not flag', r.filterNeedsAdjudication === false],
    ],
    expectSB: (r) => [['no cut line in scoreboard mode', r.filterNeedsAdjudication === false]],
  },
  {
    // F2's duplicate entries carry the SAME score, so it cannot tell first-wins from last-wins. These
    // differ: 2 then 9. If the second stood, c0 would total 15.5 — F2's own expected number.
    name: 'F22 a duplicate whose scores DIFFER — the first entry must stand',
    candidates: CANDS5,
    axes: axes2([P([0, 2], [0, 9], [1, 2], [2, 3], [3, 4], [4, 1]), RANK_MOVE_B]),
    expect: (r) => [
      ['c0 totals the FIRST entry (2 + 6.5 = 8.5), not the second', totalOf(r, 0) === 8.5],
      ['c0 records exactly one errored entry', rowOf(r, 0)?.errored.length === 1],
      ['the errored entry names the duplicate', /duplicate/.test((rowOf(r, 0)?.errored || [])[0] || '')],
      ['the first entry still counts as a returned axis', rowOf(r, 0)?.axesReturned === 2 && rowOf(r, 0)?.missing === 0],
      ['filterNeedsAdjudication === true', r.filterNeedsAdjudication === true],
    ],
  },
  {
    // The stage comment says "a first entry which is itself invalid errors, and then the second errors as
    // a duplicate". It did not: the invalid branch `continue`d before reserving the index, so the second
    // entry validated and scored. Two entries for one index on one axis is a screener that lost track of
    // its assignment — neither reading of it is trustworthy.
    name: 'F23 an invalid first entry reserves its index, so the second errors as a duplicate',
    candidates: CANDS5,
    axes: axes2([P([0, 1000], [0, 10], [1, 2], [2, 3], [3, 4], [4, 1]), P([0, 2], [1, 8], [2, 7], [3, 5], [4, 9])]),
    expect: (r) => [
      ['c0 total is the OTHER axis only (2) — neither entry scored', totalOf(r, 0) === 2],
      ['c0 records TWO errored entries on the one axis', rowOf(r, 0)?.errored.length === 2],
      ['the first names the scale', (rowOf(r, 0)?.errored || []).some(e => /outside 0\.\.10/.test(e))],
      ['the second names the duplicate', (rowOf(r, 0)?.errored || []).some(e => /duplicate/.test(e))],
      ['c0 records axesReturned 1 and missing 1 — the axis answered but never validly scored it', rowOf(r, 0)?.axesReturned === 1 && rowOf(r, 0)?.missing === 1],
      ['filterNeedsAdjudication === true', r.filterNeedsAdjudication === true],
    ],
  },
  {
    // `kept.length === 0` was a flag term with no fixture. Everything downstream must survive an empty
    // panel without throwing, and the flag must fire.
    name: 'F24 dedup keeps nothing',
    candidates: CANDS5, dedup: { keep: [], notes: '' }, axes: axes2([P(), P()]),
    expect: (r) => [
      ['the stage does not throw', !r.__threw],
      ['kept is empty', eq(r.kept, [])],
      ['totals is empty', r.totals instanceof Map && r.totals.size === 0],
      ['ranked is empty', eq(r.ranked, [])],
      ['filterReconciliation is empty', eq(r.filterReconciliation, [])],
      ['filterNeedsAdjudication === true', r.filterNeedsAdjudication === true],
    ],
    expectBracket: (r) => [['the bracket is empty', eq(r.bracket, [])]],
    expectSB: (r) => [['the shortlist is empty', eq(r.shortlist, [])]],
  },
  {
    // F23's reservation law and `rowFor`'s coercion disagreed about what a STRING index means. The fault
    // was ROUTED by the coerced value (`'1'` → candidate 1's row) but RESERVED by the raw one, so a later
    // `{index: 1}` on the same axis looked fresh, validated and was TALLIED — F23's defect re-created one
    // layer out. Both mode blocks now reserve by the row's index. F22/F23 use numeric indices throughout,
    // so this is the only fixture where the coercion is in play at all.
    name: 'F25 a STRING index reserves the ROW it names, so a later integer entry errors as a duplicate',
    candidates: CANDS5,
    axes: axes2([P(['1', 9], [1, 5]), P([1, 2], [0, 3], [2, 4])]),
    expect: (r) => [
      ['c1 total is the OTHER axis only (2) — neither axis-a entry scored', totalOf(r, 1) === 2],
      ['c1 records TWO errored entries on the one axis', rowOf(r, 1)?.errored.length === 2],
      ['the first names a TYPE fault, not a membership fault', (rowOf(r, 1)?.errored || []).some(e => /is not an integer/.test(e))],
      ['the second names the duplicate', (rowOf(r, 1)?.errored || []).some(e => /duplicate/.test(e))],
      ['c1 records axesReturned 1 and missing 1', rowOf(r, 1)?.axesReturned === 1 && rowOf(r, 1)?.missing === 1],
      ['the type fault is routed to c1, never to the orphan list', !(r.filterOrphans || []).some(e => /is not an integer/.test(e))],
      ['filterNeedsAdjudication === true', r.filterNeedsAdjudication === true],
    ],
  },
]

// ---------------------------------------------------------------- bracket-stage fixtures

const B_CANDS = named(8)
const B_BRACKET = [0, 1, 2, 3, 4, 5, 6, 7]
const A_VOTE = { winner: 'A', reason: 'r' }
const qf1 = (r) => (r.matchLog || []).find(m => m.round === 'QF1')

const B_FIXTURES = [
  {
    name: 'CONTROL bracket match with three clean A/B ballots',
    candidates: B_CANDS, bracket: B_BRACKET,
    vote: () => A_VOTE,
    expect: (r) => [
      ['QF1 records errored === 0', qf1(r)?.errored === 0],
      ['QF1 records dropped === 0', qf1(r)?.dropped === 0],
      ['QF1 records votesSent 3 / votesReturned 3', qf1(r)?.votesSent === 3 && qf1(r)?.votesReturned === 3],
      ['QF1 is not flagged', qf1(r)?.needsAdjudication === false],
      ['QF1 advanced A (c0)', qf1(r)?.winner === 'c0'],
      ['the champion is c0', r.champion === 0],
    ],
  },
  {
    // Pre-fix, `valid.length - aVotes` made this a vote for B: A 1 / B 2, and c7 advanced. MATCH_SCHEMA's
    // enum forecloses it on the Claude runtime; a raw-JSON bracket runner has no such guarantee.
    name: 'B1 a ballot whose winner is off the A/B enum',
    candidates: B_CANDS, bracket: B_BRACKET,
    vote: (label) => (label === 'judge:QF1:lens-c' ? { winner: 'C', reason: 'r' }
      : label === 'judge:QF1:lens-b' ? { winner: 'B', reason: 'r' } : A_VOTE),
    expect: (r) => [
      ['QF1 records errored === 1', qf1(r)?.errored === 1],
      ['the voided ballot is NOT counted as dropped', qf1(r)?.dropped === 0],
      ['QF1 records votesSent 3 / votesReturned 2 (the void is not a returned vote)', qf1(r)?.votesSent === 3 && qf1(r)?.votesReturned === 2],
      ['the void makes it a TIE, not a B majority', qf1(r)?.tie === true],
      ['QF1 advances c0 on the seed tie-break, NOT c7 on a phantom B vote', qf1(r)?.winner === 'c0'],
      ['QF1 sets needsAdjudication', qf1(r)?.needsAdjudication === true],
      ['a ⚠ log names the voided ballot', (r.logs || []).some(l => l.includes('⚠') && l.includes('VOIDED'))],
      ['the voted-lines list marks it VOIDED rather than crediting a candidate', (qf1(r)?.votes || []).some(v => /VOIDED/.test(v))],
    ],
  },
  {
    name: 'B2 a judge returns null (dropped, still distinct from errored)',
    candidates: B_CANDS, bracket: B_BRACKET,
    vote: (label) => (label === 'judge:QF1:lens-c' ? null : A_VOTE),
    expect: (r) => [
      ['QF1 records dropped === 1', qf1(r)?.dropped === 1],
      ['QF1 records errored === 0', qf1(r)?.errored === 0],
      ['QF1 records votesSent 3 / votesReturned 2', qf1(r)?.votesSent === 3 && qf1(r)?.votesReturned === 2],
      ['QF1 sets needsAdjudication', qf1(r)?.needsAdjudication === true],
    ],
  },
]

const bUniversal = (r) => {
  const rows = Array.isArray(r.matchLog) ? r.matchLog : null
  return [
    ['[all] matchLog has one row per match (7 in an 8-slot bracket)', !!rows && rows.length === 7],
    ['[all] every match row carries votesSent/votesReturned/dropped/errored',
      !!rows && rows.every(m => Number.isInteger(m.votesSent) && Number.isInteger(m.votesReturned) && Number.isInteger(m.dropped) && Number.isInteger(m.errored))],
    ['[all] vote buckets are disjoint (sent = returned + dropped + errored)',
      !!rows && rows.every(m => m.votesSent === m.votesReturned + m.dropped + m.errored)],
    ['[all] every flagged match is named in a ⚠ log',
      !!rows && rows.filter(m => m.needsAdjudication).every(m => (r.logs || []).some(l => l.includes('⚠') && l.includes(m.round)))],
  ]
}

// ---------------------------------------------------------------- run

// Extraction failures are a USAGE class (exit 2), never a RED (exit 1): a renamed heading or a moved
// fence means the harness pointed at the wrong thing, and reporting that as "the stage is broken" is the
// failure mode this gate exists to prevent. Same convention as lint.mjs and selftest-scoreboard.mjs.
let md, baseBracket, baseSB, baseTourney
try {
  md = readFileSync(mdPath, 'utf8')
  baseBracket = extractFilter(md, H_FILTER_BRACKET, 'filter stage (bracket mode)')
  baseSB = extractFilter(md, H_FILTER_SB, 'filter stage (scoreboard mode)')
  baseTourney = extractTourney(md)
} catch (e) {
  const msg = String((e && e.message) || e)
  console.error(msg.startsWith('harness:') ? msg : `harness: ${msg}`)
  console.error('VERDICT: HARNESS ERROR — the filter stage could not be extracted; no assertion was run')
  process.exit(2)
}

let fails = 0, total = 0
const check = (label, cond) => {
  total++
  if (!cond) fails++
  console.log(`${cond ? 'PASS' : 'FAIL'}  ${label}`)
}

const mutate = (base, key, where) => {
  const m = MUTATIONS[key]
  const out = m.apply(base)
  if (out === null) { check(`${where} — harness mutation "${m.what}" found nothing to edit`, false); return null }
  return out
}

let pristine = null // the first UNMUTATED bracket-mode result, used for the scale-coupling checks below

for (const fx of FIXTURES) {
  const modes = [['bracket', baseBracket, fx.expectBracket], ['scoreboard', baseSB, fx.expectSB]]
  const seen = {}
  for (const [mode, base, extra] of modes) {
    let body = base
    if (fx.mutation) {
      body = mutate(base, fx.mutation, `${fx.name} [${mode}]`)
      if (body === null) continue
    }
    let res
    try { res = await runFilter(body, fx) }
    catch (e) {
      if (e && e.__harness) { console.error(e.message); process.exit(2) }
      res = { __threw: true, error: String((e && e.message) || e) }
    }
    if (res.__threw) console.log(`      (stage threw: ${res.error})`)
    if (mode === 'bracket' && !fx.mutation && !pristine) pristine = res
    seen[mode] = res
    const rows = [...fx.expect(res), ...(extra ? extra(res) : []), ...universal(res)]
    for (const [label, cond] of rows) check(`${fx.name} [${mode}] — ${label}`, cond)
  }
  // Both mode blocks carry the SAME validation and reconciliation, by design — the scoreboard block is
  // the bracket block plus aliases minus the cut line. Divergence between them is the drift this checks.
  const a = seen.bracket, b = seen.scoreboard
  check(`${fx.name} [modes] — both modes agree on ranked`, !!a && !!b && eq(a.ranked, b.ranked))
  check(`${fx.name} [modes] — both modes agree on filterReconciliation`,
    !!a && !!b && eq(a.filterReconciliation, b.filterReconciliation))
}

for (const fx of B_FIXTURES) {
  let res
  try { res = await runTourney(baseTourney, fx) }
  catch (e) {
    if (e && e.__harness) { console.error(e.message); process.exit(2) }
    res = { __threw: true, error: String((e && e.message) || e) }
  }
  if (res.__threw) console.log(`      (stage threw: ${res.error})`)
  for (const [label, cond] of [...fx.expect(res), ...bUniversal(res)]) check(`${fx.name} — ${label}`, cond)
}

// SCALE COUPLING — the same argument as selftest-scoreboard.mjs's, one layer up. Two layers enforce a
// screener score (the runtime's schema validation and the stage's screenFault) and they must read ONE
// declaration; when they disagree the failure is silent and misdiagnosed, because every payload fails
// validation, retries, returns null and lands in `dropped`, which reads as flaky screeners. The VALUE
// checks catch a live disagreement; the SOURCE check catches a copy that happens to agree TODAY and turns
// into a dead screening panel at the next scale change.
const sc = pristine && pristine.screenScale
const ss = pristine && pristine.scoresSchema && pristine.scoresSchema.properties
  && pristine.scoresSchema.properties.scores && pristine.scoresSchema.properties.scores.items
  && pristine.scoresSchema.properties.scores.items.properties
  && pristine.scoresSchema.properties.scores.items.properties.score
check('[coupling] the assembled body exposes SCREEN_SCALE and the SCORES_SCHEMA score property', !!sc && !!ss)
check('[coupling] SCORES_SCHEMA score.minimum agrees with SCREEN_SCALE.min', !!sc && !!ss && ss.minimum === sc.min)
check('[coupling] SCORES_SCHEMA score.maximum agrees with SCREEN_SCALE.max', !!sc && !!ss && ss.maximum === sc.max)
// The TYPE is part of the same declaration: an integer scale the stage enforces and the schema does not
// is a bound the runtime never applies, and the harness classified F8 as schema-blocked on exactly that
// false premise. F8 pins the mutated direction; this pins the shipped one.
check('[coupling] SCORES_SCHEMA score.type follows SCREEN_SCALE.integer', !!sc && !!ss && ss.type === (sc.integer ? 'integer' : 'number'))
check('[coupling] the schema READS SCREEN_SCALE rather than repeating a literal bound or type',
  /minimum:\s*SCREEN_SCALE\.min/.test(baseBracket) && /maximum:\s*SCREEN_SCALE\.max/.test(baseBracket)
  && /type:\s*SCREEN_SCALE\.integer\s*\?\s*'integer'\s*:\s*'number'/.test(baseBracket))
check('[coupling] the screener prompt interpolates SCREEN_SCALE rather than a literal range',
  /\$\{SCREEN_SCALE\.min\}-\$\{SCREEN_SCALE\.max\}/.test(baseBracket) && /\$\{SCREEN_SCALE\.min\}-\$\{SCREEN_SCALE\.max\}/.test(baseSB))

const ALL = [...FIXTURES, ...B_FIXTURES]
const controls = ALL.filter(f => f.name.startsWith('CONTROL')).length
console.log(fails
  ? `VERDICT: RED — ${fails} of ${total} selftest assertion(s) failed`
  : `VERDICT: GREEN (selftest-filter) — ${total} assertions over ${ALL.length} fixtures (${ALL.length - controls} known-bads, ${controls} controls)`)
process.exit(fails ? 1 : 0)
