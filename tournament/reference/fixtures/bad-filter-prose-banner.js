// Fixture: a MARKED, unreconciled filter tally with one PROSE comment line between the marker and the
// tally — a line of the shape the catalog itself ships ("// The FILTER stage carries its own flag: …").
// The first cut of the banner grammar matched it, so the region truncated before `totals … .set(`, the
// tally test bailed out, and the whole filter rule went SILENT on a script it is meant to catch — a false
// NEGATIVE, strictly worse than the false positive the banner narrowness was guarding against.
// Expected: exit 1, exactly one filter ERROR. This is `bad-filter-unreconciled.js` plus one comment line.
export const meta = {
  name: 'filter-prose-banner',
  description: 'unreconciled filter tally with a prose comment between the marker and the tally',
  phases: [{ title: 'Filter', detail: 'dedup, screen, rank' }],
}
const KEEP = { type: 'object', properties: { keep: { type: 'array', items: { type: 'integer' } } }, required: ['keep'] }
const SCORES = { type: 'object', properties: { scores: { type: 'array', items: { type: 'object' } } }, required: ['scores'] }

phase('Filter')
// Filter stage — bracket mode
// The FILTER stage carries its own flag: the screening totals chose this shortlist, so a provisional
// shortlist makes a provisional board no matter how clean the panel was.
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
return { shortlist, ranked }
