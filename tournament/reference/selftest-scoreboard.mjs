#!/usr/bin/env node
// Dev tool (plain Node, runs OUTSIDE the Workflow runtime). Executes the CANONICAL scoreboard
// tournament stage out of `stages.md` against a fixture panel of known-bad judge payloads, so a
// regression in the tally is caught here rather than in a 100-agent run.
//
//   node reference/selftest-scoreboard.mjs [path/to/stages.md]   (default: the sibling stages.md)
//
// It extracts the `### Scoreboard mode (generate → judge panel` code fence, deletes every line tagged
// `STANDALONE PARSE ONLY — DELETE at assembly` (exactly as an assembler does), wraps the remainder in an
// async function over the bindings the stage consumes, and runs it once per fixture with a fake `agent`
// that answers by `opts.label` (`gen:<name>` / `judge:<name>:<judge-key>`).
//
// RUNTIME SEMANTICS MODELLED HERE (checked against the Workflow authoring reference, 2026-09-05 — not
// assumptions):
//   * `pipeline(items, s1, s2, ...)` passes every stage callback `(prevResult, originalItem, index)`;
//     for the first stage prevResult IS the item. "A stage that throws drops that item to `null` and
//     skips its remaining stages" — hence the trailing `.filter(Boolean)` in the stage.
//   * `parallel(thunks)` is a barrier and resolves POSITIONALLY: result[k] is thunk k's value, or `null`
//     if that thunk threw or its agent errored. The call itself never rejects.
//
// KNOWN-BADS FROM THE CODEX INSTRUMENT (`codex-skills/tournament/scripts/tourney.mjs` selftest) THAT ARE
// NOT PORTED, and why — the runtime cannot produce them:
//   * "duplicate sent id" — that instrument addresses votes by `<judge>__<candidate>` id in a directory.
//     Here the electorate is a positional `parallel()` over `JUDGES`, so there is no id to duplicate.
//   * "unassigned file in the judge dir" — same reason: there are no files, only array positions, so a
//     vote nobody asked for has nowhere to arrive from.
// Everything else in that selftest is ported below (score 100 / null / string / 7.5-under-integer,
// swapped candidate, wrong judge, empty electorate, uncovered candidate, tie at the top), each with its
// control beside it.
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = dirname(fileURLToPath(import.meta.url))
const mdPath = process.argv[2] || join(HERE, 'stages.md')

// ---------------------------------------------------------------- extract

const HEADING = '### Scoreboard mode (generate → judge panel'
const STANDALONE = 'STANDALONE PARSE ONLY — DELETE at assembly'

function extractStage(md) {
  const h = md.indexOf(HEADING)
  if (h < 0) throw new Error(`harness: heading not found in ${mdPath}: ${HEADING}`)
  const open = md.indexOf('```js', h)
  if (open < 0) throw new Error('harness: no ```js fence after the scoreboard heading')
  const bodyStart = md.indexOf('\n', open) + 1
  const close = md.indexOf('\n```', bodyStart)
  if (close < 0) throw new Error('harness: unterminated ```js fence for the scoreboard stage')
  const lines = md.slice(bodyStart, close).split('\n')
  const kept = lines.filter(l => !l.includes(STANDALONE))
  if (kept.length === lines.length) throw new Error('harness: no STANDALONE stub lines found — extraction is off')
  return kept.join('\n')
}

// Source-level mutations. Two fixtures need a slot the stage declares as a `const`, so the harness edits
// that one declaration and ASSERTS the edit matched — a silent no-op would turn the fixture green for the
// wrong reason.
const MUTATIONS = {
  integerScale: {
    what: 'SCORE_SCALE.integer := true',
    apply: (b) => {
      const re = /(const\s+SCORE_SCALE\s*=\s*\{[^}]*?integer\s*:\s*)false/
      if (!re.test(b)) return null
      return b.replace(re, '$1true')
    },
  },
  noJudges: {
    what: 'JUDGES := [] (empty electorate)',
    apply: (b) => {
      const re = /const\s+JUDGES\s*=\s*\[[\s\S]*?\n\]/
      if (!re.test(b)) return null
      return b.replace(re, 'const JUDGES = []')
    },
  },
}

// ---------------------------------------------------------------- fake runtime

const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor
const harnessError = (msg) => Object.assign(new Error('harness: ' + msg), { __harness: true })

// A `return` the pre-fix stage can survive: bindings it never declares read as undefined instead of
// throwing a ReferenceError that would flatten every fixture into the same uninformative RED.
const TAIL = `
;return {
  board: typeof board === 'undefined' ? undefined : board,
  winner: typeof winner === 'undefined' ? undefined : winner,
  needsAdjudication: typeof needsAdjudication === 'undefined' ? undefined : needsAdjudication,
  reconciliation: typeof reconciliation === 'undefined' ? undefined : reconciliation,
}
`

async function runStage(body, fx) {
  const logs = []
  const log = (m) => logs.push(String(m))
  const agent = async (_prompt, opts) => {
    const label = opts && opts.label
    if (!Object.prototype.hasOwnProperty.call(fx.answers, label))
      throw harnessError(`fixture "${fx.name}" has no answer for label ${JSON.stringify(label)}`)
    return fx.answers[label]
  }
  const parallel = async (fns) => Promise.all(fns.map(async (f) => {
    try { return await f() } catch (e) { if (e && e.__harness) throw e; return null }
  }))
  const pipeline = async (items, ...stages) => Promise.all(items.map(async (item, i) => {
    let prev = item
    for (const s of stages) {
      try { prev = await s(prev, item, i) } catch (e) { if (e && e.__harness) throw e; return null }
    }
    return prev
  }))
  const renderConcept = (c) => JSON.stringify(c)
  const JUDGE_SCHEMA = { type: 'object', properties: {}, required: [] }
  const fn = new AsyncFunction(
    'candidates', 'shortlist', 'renderConcept', 'JUDGE_SCHEMA',
    'agent', 'parallel', 'pipeline', 'log', 'WORKHORSE', body + TAIL)
  const out = await fn(fx.candidates, fx.shortlist, renderConcept, JUDGE_SCHEMA,
    agent, parallel, pipeline, log, 'claude-opus-5')
  return { ...out, logs }
}

// ---------------------------------------------------------------- fixtures

const PERSONAS = ['[Judge A role]', '[Judge B role]', '[Judge C role]']
const KEYS = ['judge-a', 'judge-b', 'judge-c']
const CANDS = [{ name: 'alpha' }, { name: 'beta' }]

const generated = (name) => ({ candidates: [{ name, body: 'generated output for ' + name }] })
const ballot = (cand, k, score, over) => ({
  persona: PERSONAS[k], candidate: cand, score,
  breakdown: 'b', critique: 'c', mustFix: 'm', wouldChoose: true, ...over,
})

// answers table: alpha gets `a` (array of three ballots-or-null), beta gets `b`; `gen` overrides a
// generation result (use `null` for a failed generation).
function answers(a, b, gen = {}) {
  const t = {
    'gen:alpha': 'alpha' in gen ? gen.alpha : generated('alpha'),
    'gen:beta': 'beta' in gen ? gen.beta : generated('beta'),
  }
  a.forEach((v, k) => { t[`judge:alpha:${KEYS[k]}`] = v })
  b.forEach((v, k) => { t[`judge:beta:${KEYS[k]}`] = v })
  return t
}
const scores = (cand, ...ss) => ss.map((s, k) => (s === null ? null : ballot(cand, k, s)))

const row = (res, name) => (res.board || []).find(x => x && x.name === name)
const idxOf = (res, name) => (res.board || []).findIndex(x => x && x.name === name)

const FIXTURES = [
  // ---- control: a clean panel. Every assertion here must hold both before and after the fix EXCEPT the
  // needsAdjudication one, which the pre-fix stage does not compute at all. If this fixture ever goes
  // fully red the harness itself is broken, not the stage.
  {
    name: 'CONTROL clean panel (3 valid judges, distinct means)',
    candidates: CANDS, shortlist: [0, 1],
    answers: answers(scores('alpha', 9, 9, 9), scores('beta', 5, 5, 5)),
    expect: (r) => [
      ['winner is alpha (index 0)', r.winner === 0],
      ['alpha mean is 9', row(r, 'alpha')?.score === 9],
      ['beta mean is 5', row(r, 'beta')?.score === 5],
      ['needsAdjudication === false', r.needsAdjudication === false],
    ],
  },
  // ---- L1: score type / scale
  {
    name: 'L1 score 100 (out of scale)',
    candidates: CANDS, shortlist: [0, 1],
    answers: answers(scores('alpha', 9, 9, 9), scores('beta', 5, 5, 100)),
    expect: (r) => [
      ['out-of-scale 100 is not tallied — beta mean stays 5', row(r, 'beta')?.score === 5],
      ['winner is still alpha (index 0)', r.winner === 0],
      ['beta has an errored vote from judge-c', (row(r, 'beta')?.errored || []).some(e => e.judge === 'judge-c')],
      ['beta votesSent 3 / votesReturned 3', row(r, 'beta')?.votesSent === 3 && row(r, 'beta')?.votesReturned === 3],
      ['needsAdjudication === true', r.needsAdjudication === true],
    ],
  },
  {
    name: 'L1 score null',
    candidates: CANDS, shortlist: [0, 1],
    answers: answers(scores('alpha', 8, 8, 8), [ballot('beta', 0, 9), ballot('beta', 1, 9), ballot('beta', 2, null)]),
    expect: (r) => [
      ['null score is not coerced to 0 — beta mean stays 9', row(r, 'beta')?.score === 9],
      ['winner is beta (index 1), not demoted by the null', r.winner === 1],
      ['beta has an errored vote from judge-c', (row(r, 'beta')?.errored || []).some(e => e.judge === 'judge-c')],
      ['needsAdjudication === true', r.needsAdjudication === true],
    ],
  },
  {
    name: 'L1 score "7" (string)',
    candidates: CANDS, shortlist: [0, 1],
    answers: answers(scores('alpha', 8, 8, 8), [ballot('beta', 0, 9), ballot('beta', 1, 9), ballot('beta', 2, '7')]),
    expect: (r) => [
      ['string score is not concatenated — beta mean stays 9', row(r, 'beta')?.score === 9],
      ['beta mean is a finite number inside 0..10', Number.isFinite(row(r, 'beta')?.score) && row(r, 'beta')?.score <= 10],
      ['beta has an errored vote from judge-c', (row(r, 'beta')?.errored || []).some(e => e.judge === 'judge-c')],
      ['needsAdjudication === true', r.needsAdjudication === true],
    ],
  },
  {
    name: 'CONTROL L1 score 7.5 is valid on the default (non-integer) scale',
    candidates: CANDS, shortlist: [0, 1],
    answers: answers(scores('alpha', 8, 8, 8), scores('beta', 7.5, 7.5, 7.5)),
    expect: (r) => [
      ['beta mean is 7.5', row(r, 'beta')?.score === 7.5],
      ['beta has no errored vote', (row(r, 'beta')?.errored || []).length === 0],
      ['winner is alpha (index 0)', r.winner === 0],
      ['needsAdjudication === false', r.needsAdjudication === false],
    ],
  },
  {
    name: 'L1 score 7.5 under SCORE_SCALE.integer',
    mutation: 'integerScale',
    candidates: CANDS, shortlist: [0, 1],
    answers: answers(scores('alpha', 8, 8, 8), scores('beta', 7.5, 7.5, 7.5)),
    expect: (r) => [
      ['all three beta votes errored', (row(r, 'beta')?.errored || []).length === 3],
      ['beta score is null (no valid vote), not 0', row(r, 'beta')?.score === null],
      ['beta ranks below alpha', idxOf(r, 'alpha') < idxOf(r, 'beta')],
      ['needsAdjudication === true', r.needsAdjudication === true],
    ],
  },
  // ---- L2: payload identity
  {
    name: 'L2 swapped candidate (beta ballot claims alpha)',
    candidates: CANDS, shortlist: [0, 1],
    answers: answers(scores('alpha', 6, 6, 6), [ballot('beta', 0, 5), ballot('beta', 1, 5), ballot('alpha', 2, 10)]),
    expect: (r) => [
      ['the misattributed 10 is not tallied — beta mean stays 5', row(r, 'beta')?.score === 5],
      ['winner is alpha (index 0)', r.winner === 0],
      ['beta has an errored vote from judge-c', (row(r, 'beta')?.errored || []).some(e => e.judge === 'judge-c')],
      ['needsAdjudication === true', r.needsAdjudication === true],
    ],
  },
  {
    name: 'L2 wrong persona (judge-c ballot signed Judge A)',
    candidates: CANDS, shortlist: [0, 1],
    answers: answers(scores('alpha', 6, 6, 6), [ballot('beta', 0, 5), ballot('beta', 1, 5), ballot('beta', 2, 10, { persona: PERSONAS[0] })]),
    expect: (r) => [
      ['the misattributed 10 is not tallied — beta mean stays 5', row(r, 'beta')?.score === 5],
      ['winner is alpha (index 0)', r.winner === 0],
      ['beta has an errored vote from judge-c', (row(r, 'beta')?.errored || []).some(e => e.judge === 'judge-c')],
      ['needsAdjudication === true', r.needsAdjudication === true],
    ],
  },
  // ---- L3: the electorate
  {
    name: 'L3 empty electorate (JUDGES = [])',
    mutation: 'noJudges',
    candidates: CANDS, shortlist: [0, 1],
    answers: answers([], []),
    expect: (r) => [
      ['alpha score is null (no vote), not 0', row(r, 'alpha')?.score === null],
      ['beta score is null (no vote), not 0', row(r, 'beta')?.score === null],
      ['votesSent is 0 for every candidate', (r.board || []).every(b => b.votesSent === 0)],
      ['needsAdjudication === true', r.needsAdjudication === true],
    ],
  },
  {
    name: 'L3 empty shortlist',
    candidates: CANDS, shortlist: [],
    answers: answers([], []),
    expect: (r) => [
      ['the stage completes without throwing', !r.__threw],
      ['board is empty', Array.isArray(r.board) && r.board.length === 0],
      ['needsAdjudication === true', r.needsAdjudication === true],
    ],
  },
  // ---- L4: dropped votes and failed generation
  {
    name: 'L4 a judge returns null (dropped vote)',
    candidates: CANDS, shortlist: [0, 1],
    answers: answers(scores('alpha', 4, 4, 4), [ballot('beta', 0, 5), ballot('beta', 1, 5), null]),
    expect: (r) => [
      ['beta mean is the mean of the VALID votes (5)', row(r, 'beta')?.score === 5],
      ['beta records dropped === 1', row(r, 'beta')?.dropped === 1],
      ['beta records votesSent 3 / votesReturned 2', row(r, 'beta')?.votesSent === 3 && row(r, 'beta')?.votesReturned === 2],
      ['needsAdjudication === true', r.needsAdjudication === true],
    ],
  },
  {
    name: 'L4 generation fails for one candidate',
    candidates: CANDS, shortlist: [0, 1],
    answers: answers(scores('alpha', 4, 4, 4), [], { beta: null }),
    expect: (r) => [
      ['beta stays ON the board instead of vanishing', (r.board || []).length === 2 && !!row(r, 'beta')],
      ['beta score is null', row(r, 'beta')?.score === null],
      ['beta is flagged generationFailed', row(r, 'beta')?.generationFailed === true],
      ['beta ranks below alpha', idxOf(r, 'alpha') < idxOf(r, 'beta')],
      ['needsAdjudication === true', r.needsAdjudication === true],
    ],
  },
  // ---- L5: tie at the top
  {
    name: 'L5 tie at the top',
    candidates: CANDS, shortlist: [0, 1],
    answers: answers(scores('alpha', 7, 7, 7), scores('beta', 7, 7, 7)),
    expect: (r) => [
      ['winner breaks to the LOWER index (alpha)', r.winner === 0],
      ['both means are 7', row(r, 'alpha')?.score === 7 && row(r, 'beta')?.score === 7],
      ['needsAdjudication === true', r.needsAdjudication === true],
    ],
  },
]

// ---------------------------------------------------------------- run

const md = readFileSync(mdPath, 'utf8')
const base = extractStage(md)
let fails = 0, total = 0
const check = (label, cond) => {
  total++
  if (!cond) fails++
  console.log(`${cond ? 'PASS' : 'FAIL'}  ${label}`)
}

for (const fx of FIXTURES) {
  let body = base
  if (fx.mutation) {
    const m = MUTATIONS[fx.mutation]
    const mutated = m.apply(base)
    if (mutated === null) {
      check(`${fx.name} — harness mutation "${m.what}" found nothing to edit in the stage source`, false)
      continue
    }
    body = mutated
  }
  let res
  try {
    res = await runStage(body, fx)
  } catch (e) {
    if (e && e.__harness) { console.error(e.message); process.exit(2) }
    res = { __threw: true, error: String(e && e.message || e) }
  }
  if (res.__threw) console.log(`      (stage threw: ${res.error})`)
  for (const [label, cond] of fx.expect(res)) check(`${fx.name} — ${label}`, cond)
}

console.log(fails
  ? `VERDICT: RED — ${fails} of ${total} selftest assertion(s) failed`
  : `VERDICT: GREEN (selftest-scoreboard) — ${total} assertions over ${FIXTURES.length} fixtures`)
process.exit(fails ? 1 : 0)
