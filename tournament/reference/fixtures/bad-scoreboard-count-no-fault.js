// Fixture: a scoreboard tally that COUNTS what came back — `votesReturned` computed from a real
// expression, not a stub — and records no fault bucket at all: nothing dropped, nothing errored, no
// needsAdjudication. A returned count with nothing to compare it against is not a reconciliation; it
// cannot tell a full panel from a short one, which is the whole point of the rule.
// Expected: exit 1, scoreboard ERROR.
//
// WHAT THIS FIXTURE PINS, AND WHY IT EXISTS SEPARATELY FROM bad-scoreboard-stub-only.js: the accounting
// test is a CONJUNCTION (a counter AND a fault bucket). Weakening it to a disjunction was measured to red
// NOTHING — stub-only has both halves deleted as stubs, so it fails either way, and no other fixture had
// one half without the other. A check nothing can red is a check nobody has measured. This one supplies
// the counter and withholds the fault bucket, so the conjunction is the only thing standing between it
// and a clean lint.
export const meta = {
  name: 'sb-count-no-fault',
  description: 'scoreboard tally that counts returned votes but records no dropped/errored bucket',
  phases: [{ title: 'Tournament', detail: 'judge panel' }],
}
const JUDGE = { type: 'object', properties: { score: { type: 'number' } }, required: ['score'] }

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
      const votesReturned = jj.length
      return { index: idx, name: candidates[idx].name, votesReturned, score: jj.length ? jj.reduce((s, x) => s + (x.score || 0), 0) / jj.length : 0 }
    })
)).filter(Boolean)
const board = judged.sort((a, b) => b.score - a.score)
const winner = board[0].index
return { winner, board }
