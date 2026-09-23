// The RED control for the literal-meta requirement. The declaration this file is missing is the one
// the Workflow runtime parses statically before it runs anything, so a script without it never starts
// — which is why the rule is an ERROR and not a WARN. Deliberately not spelled anywhere in this file,
// including in this comment: the rule tests raw src, so writing the literal here would suppress it.
// Single-reason — no stage is announced either, so the phase/meta cross-check WARN stays out of
// the way. Do not add one: a second diagnostic here would stop this fixture from establishing that
// removing the meta rule, and only that, flips it.
const r = (await parallel([() => agent('hi', { model: 'opus' })])).filter(Boolean)
return r
