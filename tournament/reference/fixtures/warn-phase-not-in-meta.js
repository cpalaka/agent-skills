export const meta = { name: 'x', description: 'y', phases: [{ title: 'A' }] }
phase('B')
// The WARN control for the phase/meta cross-check. `phase('B')` is announced at runtime but declared
// nowhere in meta.phases, so the progress UI has no title for it. A WARN and not an ERROR because the
// run still completes. Filed `warn-` so the class contract (exit 0, WARN present) is what makes this
// rule falsifiable: the file must stay at exactly ONE warning, or removing this rule leaves another
// behind and the coverage check reports the rule uncovered.
const r = (await parallel([() => agent('hi', { model: 'claude-opus-5' })])).filter(Boolean)
return r
