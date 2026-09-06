// Fixture: the same unguarded `parallel()` result as warn-parallel-noguard.js, plus ONE unrelated line —
// `if (!DOMAIN) throw …` — that has nothing to do with the parallel result. The whole-file version of the
// null-guard rule accepted any `if (!ident` anywhere in the source, so this single line silenced it
// (measured 2026-09-05); the catalog itself ships nine such lines, which made the rule unfirable on
// anything assembled from it. The guard must NAME the binding it guards, so this must still WARN.
// Expected: exit 0, WARN present.
export const meta = {
  name: 'parallel-unrelated-guard',
  description: 'parallel() result unguarded, with an unrelated null check elsewhere in the file',
  phases: [{ title: 'Generate', detail: 'fan out' }],
}
const DOMAIN = 'a domain'

phase('Generate')
if (!DOMAIN) throw new Error('no domain')
const r = await parallel([
  () => agent(`draft a name for ${DOMAIN}`, { model: 'claude-opus-5', label: 'gen:0' }),
  () => agent(`draft another name for ${DOMAIN}`, { model: 'claude-opus-5', label: 'gen:1' }),
])
const names = r.map(x => x.name)
return { names }
