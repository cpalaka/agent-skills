export const meta = { name: 'x', description: 'y', phases: [{ title: 'A' }] }
phase('A')
// The RED control for CommonJS loading. Unlike the ESM keyword — which is also a SyntaxError inside
// the function body the parse gate compiles, so its own rule can never red a legal script alone (see
// COVERAGE_GAPS in lint.mjs) — this one parses fine and reds on its own rule only.
const fs = require('fs')
const r = (await parallel([() => agent('hi', { model: 'claude-opus-5' })])).filter(Boolean)
return r
