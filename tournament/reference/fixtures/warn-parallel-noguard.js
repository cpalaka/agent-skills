// Fixture: a `parallel()` result consumed with no null guard of any kind — `r.map(x => x.name)` throws the
// moment one thunk returns null, which is exactly what parallel() does when an agent errors. This is the
// WARN the null-guard rule exists to raise. It is filed `warn-` and not `bad-` because the rule is a WARN,
// not an ERROR: the script still lints to exit 0, and the only evidence the rule fired is the WARN line.
// Without a fixture class that can red on a MISSING WARN, a WARN rule that quietly stops firing looks
// identical to a clean run — which is how the whole-file version of this rule went unfirable on every
// script assembled from the catalog and nothing noticed (measured 2026-09-05).
// Expected: exit 0, WARN present.
export const meta = {
  name: 'parallel-noguard',
  description: 'parallel() result consumed with no null guard',
  phases: [{ title: 'Generate', detail: 'fan out' }],
}

phase('Generate')
const r = await parallel([
  () => agent('draft a name', { model: 'claude-opus-5', label: 'gen:0' }),
  () => agent('draft another name', { model: 'claude-opus-5', label: 'gen:1' }),
])
const names = r.map(x => x.name)
return { names }
