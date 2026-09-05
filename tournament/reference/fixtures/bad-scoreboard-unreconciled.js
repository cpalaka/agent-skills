// Fixture: a scoreboard tally with NO reconciliation inside the stage, and a `dropped` token in a
// DIFFERENT stage. Under the old whole-file rule that stray token suppressed the warning entirely, so
// this file linted clean; the scoped rule must ERROR on it. Expected: exit 1, scoreboard ERROR.
export const meta = {
  name: 'sb-unreconciled',
  description: 'scoreboard tally with no sent-vs-returned reconciliation in the stage',
  phases: [
    { title: 'Verify', detail: 'claim check' },
    { title: 'Tournament', detail: 'judge panel' },
  ],
}
const VERDICT = { type: 'object', properties: { ok: { type: 'boolean' } }, required: ['ok'] }
const JUDGE = { type: 'object', properties: { score: { type: 'number' } }, required: ['score'] }

phase('Verify')
// This stage DOES reconcile — its `dropped` token is the one that suppressed the old whole-file warning.
const claims = ['a', 'b']
const checks = (await parallel(claims.map(c => () => agent(`check ${c}`, { model: 'claude-opus-5', schema: VERDICT })))).filter(Boolean)
const dropped = claims.length - checks.length
log(`claim-verify: ${dropped} dropped`)

phase('Tournament')
// Tournament stage — scoreboard mode
const candidates = [{ name: 'alpha' }, { name: 'beta' }]
const shortlist = [0, 1]
const JUDGES = [{ key: 'j1', persona: 'A' }, { key: 'j2', persona: 'B' }]
const judged = (await pipeline(
  shortlist,
  (idx) => agent(`generate ${candidates[idx].name}`, { model: 'claude-opus-5', label: `gen:${idx}` }),
  (generated, idx) => parallel(JUDGES.map(j => () => agent(`judge ${j.key}`, { model: 'claude-opus-5', schema: JUDGE })))
    .then(js => {
      const jj = js.filter(Boolean)
      return { index: idx, name: candidates[idx].name, score: jj.length ? jj.reduce((s, x) => s + (x.score || 0), 0) / jj.length : 0 }
    })
)).filter(Boolean)
const board = judged.sort((a, b) => b.score - a.score)
const winner = board[0].index
return { winner, board }
