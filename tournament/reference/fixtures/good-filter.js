// Fixture: both filter markers in one script — the bracket-mode banner and the scoreboard-mode banner with
// its trailing parenthetical — each with a real per-candidate reconciliation in code. Every marked region
// must go green, including the one whose banner does not end at the marker text. Expected: exit 0, no WARN.
export const meta = {
  name: 'filter-reconciled',
  description: 'filter tallies that reconcile axes sent vs axes returned per candidate',
  phases: [{ title: 'Filter', detail: 'dedup, screen, rank' }],
}
const SCORES = { type: 'object', properties: { scores: { type: 'array', items: { type: 'object' } } }, required: ['scores'] }

phase('Filter')
// Filter stage — bracket mode
const candidates = [{ name: 'alpha' }, { name: 'beta' }, { name: 'gamma' }]
const kept = candidates.map((_, i) => i)
const keptSet = new Set(kept)
const AXES = [{ key: 'axis-a' }, { key: 'axis-b' }]
const SCREEN_SCALE = { min: 0, max: 10, integer: false }
const screeningResults = await parallel(AXES.map(a => () => agent(`screen ${a.key}`, { model: 'claude-opus-5', label: `screen:${a.key}`, schema: SCORES })))
const axesAnswered = screeningResults.filter(Boolean).length // run-level: how many axes came back at all
const rows = new Map(kept.map(i => [i, { index: i, axesSent: AXES.length, axesReturned: 0, dropped: 0, errored: [], missing: 0, total: null }]))
screeningResults.forEach((res) => {
  if (!res) { for (const r of rows.values()) r.dropped += 1; return }
  const seen = new Set()
  for (const s of (res.scores || [])) {
    if (!keptSet.has(s.index) || seen.has(s.index) || typeof s.score !== 'number' || s.score < SCREEN_SCALE.min || s.score > SCREEN_SCALE.max) {
      const row = rows.get(s.index)
      if (row) row.errored.push(`bad entry for ${s.index}`)
      continue
    }
    seen.add(s.index)
    const row = rows.get(s.index)
    row.axesReturned += 1
    row.total = (row.total === null ? 0 : row.total) + s.score
  }
  for (const r of rows.values()) if (!seen.has(r.index)) r.missing += 1
})
const filterReconciliation = kept.map(i => rows.get(i))
const totals = new Map(filterReconciliation.map(r => [r.index, r.total]))
const rankOf = (i) => (totals.get(i) === null ? -Infinity : totals.get(i))
const ranked = [...kept].sort((x, y) => (rankOf(x) === rankOf(y) ? x - y : rankOf(y) - rankOf(x)))
const filterNeedsAdjudication = filterReconciliation.some(r => r.axesReturned < r.axesSent || r.errored.length > 0)
if (filterNeedsAdjudication) log('⚠ filter needsAdjudication — the seeding below is PROVISIONAL')
const bracket = ranked.slice(0, 8)

// Filter stage — scoreboard mode (dedup + screening identical to bracket mode)
const keptSB = candidates.map((_, i) => i)
const AXES_SB = [{ key: 'axis-a' }, { key: 'axis-b' }]
const screeningResultsSB = await parallel(AXES_SB.map(a => () => agent(`screen ${a.key}`, { model: 'claude-opus-5', label: `screen2:${a.key}`, schema: SCORES })))
const rowsSB = new Map(keptSB.map(i => [i, { index: i, axesSent: AXES_SB.length, axesReturned: 0, dropped: 0, errored: [], missing: 0, total: null }]))
screeningResultsSB.forEach((res) => {
  if (!res) { for (const r of rowsSB.values()) r.dropped += 1; return }
  const seen = new Set()
  for (const s of (res.scores || [])) {
    if (typeof s.score !== 'number' || seen.has(s.index) || !rowsSB.has(s.index)) { const row = rowsSB.get(s.index); if (row) row.errored.push('bad'); continue }
    seen.add(s.index)
    const row = rowsSB.get(s.index)
    row.axesReturned += 1
    row.total = (row.total === null ? 0 : row.total) + s.score
  }
  for (const r of rowsSB.values()) if (!seen.has(r.index)) r.missing += 1
})
const filterReconciliationSB = keptSB.map(i => rowsSB.get(i))
const totalsSB = new Map(filterReconciliationSB.map(r => [r.index, r.total]))
const rankedSB = [...keptSB].sort((x, y) => (totalsSB.get(y) ?? -Infinity) - (totalsSB.get(x) ?? -Infinity))
const filterNeedsAdjudicationSB = filterReconciliationSB.some(r => r.axesReturned < r.axesSent)
const shortlist = [...rankedSB]
return { bracket, shortlist, axesAnswered, filterReconciliation, filterNeedsAdjudication, filterReconciliationSB, filterNeedsAdjudicationSB }
