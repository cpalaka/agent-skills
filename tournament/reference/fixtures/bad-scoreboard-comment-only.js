// Fixture: a scoreboard tally whose only "reconciliation" is the WORD — in a comment and inside a log
// string. Nothing is counted, nothing is flagged. The first version of the scoped rule tested the region's
// raw text, so prose like this satisfied it; the token test now runs on code only. Expected: exit 1.
export const meta = {
  name: 'sb-comment-only',
  description: 'scoreboard tally whose reconciliation exists only in prose',
  phases: [{ title: 'Tournament', detail: 'judge panel' }],
}
const JUDGE = { type: 'object', properties: { score: { type: 'number' } }, required: ['score'] }

phase('Tournament')
// Tournament stage — scoreboard mode
const candidates = [{ name: 'alpha' }, { name: 'beta' }]
const shortlist = [0, 1]
const JUDGES = [{ key: 'j1' }, { key: 'j2' }]
const judged = (await pipeline(
  shortlist,
  (idx) => agent(`generate ${candidates[idx].name}`, { model: 'claude-opus-5', label: `gen:${idx}` }),
  (generated, idx) => parallel(JUDGES.map(j => () => agent(`judge ${j.key}`, { model: 'claude-opus-5', schema: JUDGE })))
    .then(js => {
      // any ballot that errored, or was dropped by a judge, is reconciled below and sets needsAdjudication
      const jj = js.filter(Boolean)
      log(`panel: 0 dropped, 0 errored, votesSent === votesReturned, needsAdjudication false`)
      return { index: idx, name: candidates[idx].name, score: jj.length ? jj.reduce((s, x) => s + (x.score || 0), 0) / jj.length : 0 }
    })
)).filter(Boolean)
const board = judged.sort((a, b) => b.score - a.score)
const winner = board[0].index
return { winner, board }
