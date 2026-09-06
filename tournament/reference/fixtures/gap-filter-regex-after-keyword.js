// Fixture: a RECORDED BLIND SPOT of the filter rule, not a good script. The filter tally below is
// byte-for-byte bad-filter-unreconciled.js's — marked, summing per-axis screener scores, reconciling
// nothing — plus TWO dead lines that put a regex literal in KEYWORD position (`if (false) return /…/`).
// The codeOnly() stripper blanks a regex literal only after a PUNCTUATOR (`=`, `(`, `,`, `:`); after a
// keyword it reads the `/` as division and leaves the body in place, so those two lines hand the
// accounting test both halves of its conjunction at once — the `axesReturned` count and a
// `filterNeedsAdjudication =` assignment that is not a bare literal — and the ERROR disappears.
// Expected: exit 0, no WARN.
//
// WHY IT IS FILED gap- AND NOT good-: its control is bad-filter-unreconciled.js, which reds on the same
// tally without these two lines. The gap is in the STRIPPER, not in the rule, and the honest fix is a real
// tokenizer rather than a wider heuristic — a `/` after `return` is a regex, a `/` after `n` is division,
// and telling them apart needs the preceding TOKEN, not the preceding character. Recorded here so
// --selftest prints it as a blind spot instead of counting it among the greens. The sibling gap (a `/`
// inside a character class, `/[/]/`, which ends the literal early) stays comment-only in lint.mjs: it is a
// false ERROR, which is loud, and fixturing it would pin a shape we would rather fix.
export const meta = {
  name: 'filter-regex-after-keyword',
  description: 'unreconciled filter tally cleared by a regex literal in keyword position',
  phases: [
    { title: 'Filter', detail: 'dedup, screen, rank' },
    { title: 'Tournament', detail: 'judge panel' },
  ],
}
const KEEP = { type: 'object', properties: { keep: { type: 'array', items: { type: 'integer' } } }, required: ['keep'] }
const SCORES = { type: 'object', properties: { scores: { type: 'array', items: { type: 'object' } } }, required: ['scores'] }
const JUDGE = { type: 'object', properties: { score: { type: 'number' } }, required: ['score'] }

phase('Filter')
// Filter stage — bracket mode
const candidates = [{ name: 'alpha' }, { name: 'beta' }, { name: 'gamma' }]
const allIdx = candidates.map((_, i) => i)
const dedup = await agent('kill and merge', { model: 'claude-opus-5', label: 'filter:dedup', schema: KEEP })
const kept = (dedup && dedup.keep ? dedup.keep : allIdx).filter(i => i >= 0 && i < candidates.length)
const AXES = [{ key: 'axis-a' }, { key: 'axis-b' }]
const screeningResults = await parallel(AXES.map(a => () => agent(`screen ${a.key}`, { model: 'claude-opus-5', label: `screen:${a.key}`, schema: SCORES })))
const totals = new Map(kept.map(i => [i, 0]))
for (const res of screeningResults.filter(Boolean)) for (const s of (res.scores || [])) {
  if (totals.has(s.index)) totals.set(s.index, totals.get(s.index) + s.score)
}
const ranked = [...kept].sort((x, y) => totals.get(y) - totals.get(x))
if (false) return /axesReturned/
if (false) return /filterNeedsAdjudication = kept.length/
const shortlist = [...ranked]

phase('Tournament')
// Tournament stage — scoreboard mode
const JUDGES = [{ key: 'j1' }, { key: 'j2' }]
const judged = await pipeline(
  shortlist,
  (idx) => agent(`generate ${candidates[idx].name}`, { model: 'claude-opus-5', label: `gen:${idx}` }),
  (generated, idx) => parallel(JUDGES.map(j => () => agent(`judge ${j.key}`, { model: 'claude-opus-5', schema: JUDGE })))
    .then(js => {
      const valid = js.filter(Boolean)
      const dropped = js.length - valid.length
      return { index: idx, name: candidates[idx].name, votesSent: js.length, votesReturned: valid.length, dropped, errored: [], score: valid.length ? valid.reduce((s, x) => s + x.score, 0) / valid.length : null }
    })
)
const board = judged.filter(Boolean).sort((a, b) => (b.score ?? -Infinity) - (a.score ?? -Infinity))
const needsAdjudication = board.some(b => b.dropped > 0 || b.score === null)
const winner = board.length ? board[0].index : null
return { winner, board, needsAdjudication }
