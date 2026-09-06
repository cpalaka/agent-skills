// Fixture: a script that is clean on every other rule and does not PARSE — one unbalanced paren on the
// last line. `node --check` (the gate this replaced) exited 0 on exactly this file: a workflow script
// ends in a top-level `return`, illegal in both script and module mode, and because the file opens
// `export const meta = {` Node detects module syntax and checks it as a module, where the tail below is
// swallowed. Measured 2026-09-05. Expected: exit 1, one `syntax error:` ERROR.
export const meta = { name: 'syntax', description: 'unparseable tail', phases: [{ title: 'A' }] }
phase('A')
const r = (await parallel([() => agent('hi', { model: 'claude-opus-5' })])).filter(Boolean)
const OOPS = ((((
return r
