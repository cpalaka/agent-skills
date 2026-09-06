// Fixture: an UNMARKED, unreconciled filter tally in the exact shape of the private golden
// `the private repo's tournament/reference/golden/incremental-concept-tournament.js` (L206–216 at minting).
// It stays GREEN, and that is a RECORDED BLIND SPOT, not an endorsement — hence the `gap-` prefix, which
// --selftest counts apart from the genuine `good-` fixtures. The filter rule is marker-scoped precisely
// because the golden clause pins that file's lint output (the recorded counts live in the private
// repo's ticket record, not here), and a fallback keyed on `totals` would red a golden to satisfy a
// linter rule. This fixture is the control for that decision: it is byte-for-byte the same tally as
// `bad-filter-unreconciled.js`'s FILTER TALLY, minus the `// Filter stage — bracket mode` banner (the
// two files' stage TAILS differ — a bracket loop here, a shortlist line there — which is outside the
// span the rule reads). So the pair measures that the marker, and only the marker, is what the rule keys
// on.
// Expected: exit 0, no WARN. That expectation says the golden clause is still in force — it does NOT say
// the detector is right to miss this. Widen the detector only together with a re-mint of the private
// golden, and change this fixture's contract in the same commit.
export const meta = {
  name: 'filter-unmarked-golden-shape',
  description: 'unmarked filter tally in the golden shape — the rule cannot see it, by design',
  phases: [{ title: 'Filter', detail: 'dedup, screen, rank' }],
}
const KEEP = { type: 'object', properties: { keep: { type: 'array', items: { type: 'integer' } } }, required: ['keep'] }
const SCORES = { type: 'object', properties: { scores: { type: 'array', items: { type: 'object' } } }, required: ['scores'] }

phase('Filter')
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
const bracket = []
for (const i of ranked) { if (bracket.length >= 8) break; if (!bracket.includes(i)) bracket.push(i) }
return { bracket, ranked }
