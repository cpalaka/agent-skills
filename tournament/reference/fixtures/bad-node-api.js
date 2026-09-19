export const meta = { name: 'x', description: 'y', phases: [{ title: 'A' }] }
phase('A')
// The RED control for the Node builtin namespace. It loads the namespace for real rather than merely
// naming it in a string: the rule reads RAW src and so a bare mention would red too, but pinning THAT
// would assert a false positive is correct, which is the reason `forbid-import` is a declared gap in
// lint.mjs rather than a fixture. A dynamic import is not caught by the ESM-keyword rule (that one
// needs the keyword at the start of a line) and compiles cleanly, so nothing else in this file reds.
const fs = await import('node:child_process')
const r = (await parallel([() => agent('hi', { model: 'claude-opus-5' })])).filter(Boolean)
return r
