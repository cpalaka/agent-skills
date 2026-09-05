// Fixture: a hand-rolled scoreboard with NO canonical marker, preceded by a screening stage that does
// reconcile. The detector has to fall back — and the fallback must anchor on the pipeline NEAREST BEFORE
// the `board` binding, not the first one in the file, or the screening stage's `dropped` lands inside the
// scoreboard's region and suppresses the error exactly the way the old whole-file rule did.
// Expected: exit 1, scoreboard ERROR.
export const meta = {
  name: 'sb-unmarked',
  description: 'unmarked scoreboard tally after a reconciled screening stage',
  phases: [
    { title: 'Screen', detail: 'hard-constraint pass' },
    { title: 'Tournament', detail: 'judge panel' },
  ],
}
const KEEP = { type: 'object', properties: { keep: { type: 'boolean' } }, required: ['keep'] }
const JUDGE = { type: 'object', properties: { score: { type: 'number' } }, required: ['score'] }
const candidates = [{ name: 'alpha' }, { name: 'beta' }, { name: 'gamma' }]

phase('Screen')
const screened = (await pipeline(
  candidates.map((c, i) => i),
  (i) => agent(`screen ${candidates[i].name}`, { model: 'claude-opus-5', label: `screen:${i}`, schema: KEEP })
)).filter(Boolean)
const dropped = candidates.length - screened.length
const votesSent = candidates.length
log(`screen: ${votesSent} sent, ${dropped} dropped`)
const shortlist = [0, 1]

phase('Tournament')
const JUDGES = [{ key: 'j1' }, { key: 'j2' }]
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
