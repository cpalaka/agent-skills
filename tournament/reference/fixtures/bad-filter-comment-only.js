// Fixture: a MARKED filter stage whose only "reconciliation" is the WORD — in a comment and inside a log
// string. Nothing is counted, nothing is flagged, and the ranking is still a raw sum. The token test runs
// on code only, so prose like this must not satisfy it. Expected: exit 1, filter ERROR.
export const meta = {
  name: 'filter-comment-only',
  description: 'filter tally whose reconciliation exists only in prose',
  phases: [{ title: 'Filter', detail: 'dedup, screen, rank' }],
}
const SCORES = { type: 'object', properties: { scores: { type: 'array', items: { type: 'object' } } }, required: ['scores'] }

phase('Filter')
// Filter stage — scoreboard mode
const candidates = [{ name: 'alpha' }, { name: 'beta' }, { name: 'gamma' }]
const kept = candidates.map((_, i) => i)
const AXES = [{ key: 'axis-a' }, { key: 'axis-b' }]
const screeningResults = await parallel(AXES.map(a => () => agent(`screen ${a.key}`, { model: 'claude-opus-5', label: `screen:${a.key}`, schema: SCORES })))
const totals = new Map(kept.map(i => [i, 0]))
for (const res of screeningResults.filter(Boolean)) for (const s of (res.scores || [])) {
  // axesSent vs axesReturned is reconciled below and any shortfall sets filterNeedsAdjudication
  if (totals.has(s.index)) totals.set(s.index, totals.get(s.index) + s.score)
}
log(`screening: axesSent === axesReturned for every candidate, filterReconciliation clean, filterNeedsAdjudication false`)
const ranked = [...kept].sort((x, y) => totals.get(y) - totals.get(x))
const shortlist = [...ranked]
return { shortlist, ranked }
