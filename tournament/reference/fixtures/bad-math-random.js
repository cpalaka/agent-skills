export const meta = { name: 'x', description: 'y', phases: [{ title: 'A' }] }
phase('A')
// The RED control for the runtime's second unavailable global. `bad-daterandom.js` is named for both
// halves and reds on only one of them — the clock — so this rule had no fixture at all until
// 2026-09-18 (ticket 20). Single-reason on purpose: nothing else in this file reds.
const t = Math.random()
const r = (await parallel([() => agent('hi', { model: 'opus' })])).filter(Boolean)
return r
