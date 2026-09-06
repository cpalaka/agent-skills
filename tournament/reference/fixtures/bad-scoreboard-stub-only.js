// Fixture: bad-scoreboard-unreconciled.js's tally, unchanged, plus the two STUB declarations the catalog
// itself carries under `// STANDALONE PARSE ONLY — DELETE at assembly`. Neither counts anything. Under the
// earlier one-of-five-names token test either line ALONE turned this file clean — measured 2026-09-05, by
// `awk 'NR==36{print "const needsAdjudication = false"}'` on the control, exit 1 → exit 0. The sibling
// filter rule had already been given an accounting test for exactly this bypass; the scoreboard rule
// shipped the same hole for a day longer. The accounting test deletes bare-literal declarations before
// looking, and requires a returned COUNT and a fault bucket rather than either alone.
// Expected: exit 1, scoreboard ERROR. Control: bad-scoreboard-unreconciled.js (same file without the two
// stub lines) also exit 1, so the pair pins that the stubs are what the rule refuses to accept, not that
// the tally changed.
export const meta = {
  name: 'sb-stub-only',
  description: 'unreconciled scoreboard tally with bare stub declarations of the reconciliation names',
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
const needsAdjudication = false
const votesReturned = 0
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
return { winner, board, needsAdjudication, votesReturned }
