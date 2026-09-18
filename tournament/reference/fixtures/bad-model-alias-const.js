export const meta = { name: 'x', description: 'y', phases: [{ title: 'A' }] }
phase('A')
// The alias check's CONTROL for its non-suffix-anchored alternation. The pin here is a plain
// SCREAMING_CASE const carrying no MODEL suffix, and it is the ONLY reason this fixture exits 1 —
// the call below pins that const rather than a literal, so nothing else in the file reds.
// Re-narrowing the alternation to names ending in MODEL turns this fixture GREEN (measured
// 2026-09-17: that reading missed every screaming-case const without the suffix, and a bare `MODEL`
// besides), which is the regression it exists to catch. The specific name is not the point — any
// suffix-less screaming-case binding exercises the same path. `bad-model-alias.js` is the other
// arm's control, a quoted alias at a key site.
// Keep this comment free of a literal call and of that key's name: both appear in the explicit-pin
// heuristic's span scan, which runs over the raw source, and either one reds this fixture for a
// second, unrelated reason (measured while writing it).
const SCREENER = 'opus'
const r = (await parallel([() => agent('hi', { model: SCREENER })])).filter(Boolean)
return r
