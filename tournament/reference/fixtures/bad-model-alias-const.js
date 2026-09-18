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
// This comment carries neither a literal call nor that key's name because the explicit-pin heuristic's
// span scan once ran over the RAW source, where either one red this fixture for a second, unrelated
// reason (measured while writing it). That scan reads CODE ONLY since 2026-09-18 and
// `good-pin-scan-skips-comments.js` is its control, so the avoidance no longer carries the
// single-reason property — the fixture's own contents below do, and they are what must not change.
const SCREENER = 'opus'
const r = (await parallel([() => agent('hi', { model: SCREENER })])).filter(Boolean)
return r
