// Fixture: a MARKED filter stage that sums per-axis screener scores with NO reconciliation, followed by a
// fully reconciled scoreboard stage whose `dropped` token sits in code. That later token is what the old
// whole-file rule borrowed to stay quiet; the marker-scoped filter rule must ERROR on the filter stage
// anyway. Expected: exit 1, exactly one filter ERROR and no scoreboard ERROR.
export const meta = {
  name: 'filter-unreconciled',
  description: 'filter tally with no axes-sent-vs-returned reconciliation in the stage',
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
