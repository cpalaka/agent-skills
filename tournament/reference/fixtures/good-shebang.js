#!/usr/bin/env node
// Fixture: an otherwise clean workflow script carrying a leading `#!` line. Node strips a shebang before
// parsing a file, so this is valid input; the syntax gate wraps the source in an async function body and
// `new Function` does NOT strip it, which reported `syntax error: Invalid or unexpected token` on a script
// that parses fine (measured 2026-09-05, on a gate that had shipped the same day).
// Expected: exit 0, no WARN.
//
// THIS IS NOT AN ENDORSEMENT OF SHEBANGS. A workflow script is loaded by the runtime, never executed by a
// kernel, so it has no reason to carry one. What the fixture pins is the GATE'S BLAST RADIUS: the syntax
// gate replaced `node --check`, and a gate that reports a syntax error where its predecessor reported none
// is a regression whether or not anyone wanted the shape. Removing the strip was measured to red nothing
// until this fixture existed.
export const meta = {
  name: 'shebang',
  description: 'clean workflow script with a leading shebang line',
  phases: [{ title: 'Generate', detail: 'fan out' }],
}

phase('Generate')
const r = (await parallel([
  () => agent('draft a name', { model: 'claude-opus-5', label: 'gen:0' }),
])).filter(Boolean)
return { names: r }
