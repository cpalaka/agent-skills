// Fixture: a RECORDED BLIND SPOT of the scoreboard rule, not a good script. A MARKED, unreconciled
// scoreboard tally is followed — with only a PROSE comment between them, no real stage banner — by a later
// block that reassigns `winner` and does its own accounting. The region ends at the LAST `winner =` in the
// span, so it swallows that later block and borrows its counter (`lateVotesReturned`) and its fault bucket
// (`lateDropped`); the tally itself reconciles nothing. Expected: exit 0, no WARN.
//
// WHY IT IS FILED gap- AND NOT good-: the scoreboard tally below is exactly the shape
// bad-scoreboard-unreconciled.js reds on. The only difference is the trailing block, and nothing in this
// file makes that block part of the scoreboard stage. This is the cost, measured, of two decisions taken
// deliberately and recorded in lint.mjs: ending the region at the LAST `winner =` (so an early
// `let winner = null` cannot collapse a reconciled stage into two lines — see good-scoreboard-earlydecl.js),
// and narrowing the stage-banner grammar so a prose comment containing the word "stage" no longer ends a
// region (which the FILTER rule needs, and which widens this window a little further — measured 2026-09-05).
// The catalog's own stages all carry real banners, so this is reachable only in a hand-rolled script.
// Widen the DETECTOR if it shows up for real; do not narrow the region, and do not re-file this as good-.
export const meta = {
  name: 'sb-prose-then-winner',
  description: 'unreconciled scoreboard whose region swallows a later block and borrows its accounting',
  phases: [
    { title: 'Verify', detail: 'claim check' },
    { title: 'Tournament', detail: 'judge panel' },
  ],
}
const VERDICT = { type: 'object', properties: { ok: { type: 'boolean' } }, required: ['ok'] }
const JUDGE = { type: 'object', properties: { score: { type: 'number' } }, required: ['score'] }

phase('Verify')
const claims = ['a', 'b']
const checks = (await parallel(claims.map(c => () => agent(`check ${c}`, { model: 'claude-opus-5', schema: VERDICT })))).filter(Boolean)
const claimsDropped = claims.length - checks.length
log(`claim-verify: ${claimsDropped} dropped`)

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
let winner = board[0].index
// The FILTER stage carries its own flag: the screening totals chose this shortlist
const lateVotesSent = 3
const lateVotesReturned = lateVotesSent - 1
const lateDropped = lateVotesSent - lateVotesReturned
if (lateDropped > 0) winner = board[1].index
return { winner, board }
