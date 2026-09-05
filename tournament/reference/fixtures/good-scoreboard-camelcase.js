// Fixture: a scoreboard that reconciles under its OWN identifier names — `judgesDropped`,
// `candidatesDropped`, no lowercase `dropped` anywhere in the tally. This is the shape a real recorded
// tournament script uses, and a case-sensitive token test reports it as unreconciled. Expected: exit 0, no WARN.
export const meta = {
  name: 'sb-camelcase',
  description: 'scoreboard reconciled under camelCase identifier names',
  phases: [{ title: 'Tournament', detail: 'judge panel' }],
}
const JUDGE = { type: 'object', properties: { score: { type: 'number' } }, required: ['score'] }

phase('Tournament')
// Tournament stage — scoreboard mode
const CANDIDATES = [{ name: 'alpha' }, { name: 'beta' }]
const JUDGES = [{ key: 'j1' }, { key: 'j2' }]
const judged = (await pipeline(
  CANDIDATES.map((c, i) => i),
  (idx) => agent(`generate ${CANDIDATES[idx].name}`, { model: 'claude-opus-5', label: `gen:${idx}` }),
  (generated, idx) => parallel(JUDGES.map(j => () => agent(`judge ${j.key}`, { model: 'claude-opus-5', schema: JUDGE })))
    .then(js => {
      const jj = js.filter(Boolean)
      const judgesDropped = js.length - jj.length
      const score = jj.length ? jj.reduce((s, x) => s + x.score, 0) / jj.length : null
      if (judgesDropped > 0) log(`${CANDIDATES[idx].name}: ${judgesDropped}/${js.length} judge(s) lost`)
      return { index: idx, name: CANDIDATES[idx].name, score, judgesSent: js.length, judgesReturned: jj.length, judgesDropped }
    })
)).filter(Boolean)
const candidatesDropped = CANDIDATES.length - judged.length
if (candidatesDropped > 0) log(`scoreboard: ${candidatesDropped}/${CANDIDATES.length} candidate(s) lost before scoring`)
const board = judged.sort((a, b) => (b.score ?? -Infinity) - (a.score ?? -Infinity))
const winner = board.length ? board[0].index : null
return { winner, board, candidatesDropped }
