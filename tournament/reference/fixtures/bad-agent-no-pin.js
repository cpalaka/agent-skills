export const meta = { name: 'x', description: 'y', phases: [{ title: 'A' }] }
phase('A')
// The explicit-pin heuristic's RED control, which the catalog had none of: no fixture reds this
// rule, so narrowing its input could have switched the rule off in silence and --selftest would
// have stayed green (measured 2026-09-18). The call below inherits the session model, the one
// thing the rule exists to catch; nothing else in this file reds.
const r = (await parallel([() => agent('hi', {})])).filter(Boolean)
return r
