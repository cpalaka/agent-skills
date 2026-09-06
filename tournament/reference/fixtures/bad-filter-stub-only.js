// Fixture: a MARKED, unreconciled filter tally that DECLARES the flag and computes nothing —
// `const filterNeedsAdjudication = false`, which is the STANDALONE stub the catalog itself carries in
// three places and the line an assembler is most likely to leave behind. A rule satisfied by the mere
// presence of a name is satisfied by this, so the token test has to demand ACCOUNTING: `axesReturned`
// counted, and the flag assigned something other than a bare literal.
// Expected: exit 1, exactly one filter ERROR. This is `bad-filter-unreconciled.js` plus one declaration.
export const meta = {
  name: 'filter-stub-only',
  description: 'unreconciled filter tally that declares the flag as a bare literal',
  phases: [{ title: 'Filter', detail: 'dedup, screen, rank' }],
}
const KEEP = { type: 'object', properties: { keep: { type: 'array', items: { type: 'integer' } } }, required: ['keep'] }
const SCORES = { type: 'object', properties: { scores: { type: 'array', items: { type: 'object' } } }, required: ['scores'] }

phase('Filter')
// Filter stage — bracket mode
const candidates = [{ name: 'alpha' }, { name: 'beta' }, { name: 'gamma' }]
const allIdx = candidates.map((_, i) => i)
const dedup = await agent('kill and merge', { model: 'claude-opus-5', label: 'filter:dedup', schema: KEEP })
const kept = (dedup && dedup.keep ? dedup.keep : allIdx).filter(i => i >= 0 && i < candidates.length)
const AXES = [{ key: 'axis-a' }, { key: 'axis-b' }]
const axesSent = AXES.length
const screeningResults = await parallel(AXES.map(a => () => agent(`screen ${a.key}`, { model: 'claude-opus-5', label: `screen:${a.key}`, schema: SCORES })))
const totals = new Map(kept.map(i => [i, 0]))
for (const res of screeningResults.filter(Boolean)) for (const s of (res.scores || [])) {
  if (totals.has(s.index)) totals.set(s.index, totals.get(s.index) + s.score)
}
const ranked = [...kept].sort((x, y) => totals.get(y) - totals.get(x))
const filterNeedsAdjudication = false
const shortlist = [...ranked]
return { shortlist, ranked, axesSent, filterNeedsAdjudication }
