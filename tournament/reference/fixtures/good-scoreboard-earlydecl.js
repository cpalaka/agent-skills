// Fixture: a fully reconciled scoreboard that declares `let winner = null` BEFORE the tally and assigns it
// after. Ending the region at the FIRST winner assignment collapses it to two lines and reports this
// reconciled stage as unreconciled — the region has to run to the LAST assignment. Expected: exit 0, no WARN.
export const meta = {
  name: 'sb-earlydecl',
  description: 'reconciled scoreboard with an early winner declaration',
  phases: [{ title: 'Tournament', detail: 'judge panel' }],
}
const JUDGE_SCHEMA = {
  type: 'object',
  properties: { persona: { type: 'string' }, candidate: { type: 'string' }, score: { type: 'number', minimum: 0, maximum: 10 } },
  required: ['persona', 'candidate', 'score'],
}

phase('Tournament')
// Tournament stage — scoreboard mode
const candidates = [{ name: 'alpha' }, { name: 'beta' }]
const shortlist = [0, 1]
const SCORE_SCALE = { min: 0, max: 10, integer: false }
const JUDGES = [
  { key: 'judge-a', persona: 'Judge A', rubric: 'AXIS A' },
  { key: 'judge-b', persona: 'Judge B', rubric: 'AXIS B' },
]
let winner = null
const sameId = (a, b) => String(a ?? '').trim().toLowerCase() === String(b ?? '').trim().toLowerCase()
const voteFault = (v, judge, cand) => {
  if (!sameId(v.persona, judge.persona)) return 'persona mismatch'
  if (!sameId(v.candidate, cand.name)) return 'candidate mismatch'
  if (typeof v.score !== 'number' || !Number.isFinite(v.score)) return 'score is not a finite number'
  if (v.score < SCORE_SCALE.min || v.score > SCORE_SCALE.max) return 'score out of scale'
  return null
}
const rawJudged = await pipeline(
  shortlist,
  (idx) => agent(`generate ${candidates[idx].name}`, { model: 'claude-opus-5', label: `gen:${idx}` }),
  (generated, idx) => {
    const c = candidates[idx]
    if (!generated) return { index: idx, name: c.name, score: null, votesSent: 0, votesReturned: 0, dropped: 0, errored: [], generationFailed: true }
    return parallel(JUDGES.map(j => () => agent(`judge ${c.name} as ${j.persona}: ${j.rubric}`, { model: 'claude-opus-5', schema: JUDGE_SCHEMA })))
      .then(js => {
        const valid = [], errored = []
        let dropped = 0
        js.forEach((v, k) => {
          if (!v) { dropped++; return }
          const why = voteFault(v, JUDGES[k], c)
          if (why) errored.push({ judge: JUDGES[k].key, why })
          else valid.push(v)
        })
        const score = valid.length ? valid.reduce((s, x) => s + x.score, 0) / valid.length : null
        if (dropped || errored.length) log(`${c.name}: ${valid.length}/${js.length} valid`)
        return { index: idx, name: c.name, score, votesSent: js.length, votesReturned: valid.length, dropped, errored, generationFailed: false }
      })
  }
)
const stageDropped = rawJudged.length - rawJudged.filter(Boolean).length
const judged = rawJudged.map((r, k) => r || { index: shortlist[k], name: candidates[shortlist[k]].name, score: null, votesSent: 0, votesReturned: 0, dropped: 0, errored: [], generationFailed: true, stageThrew: true })
const rank = (x) => (x.score === null ? -Infinity : x.score)
const board = judged.sort((a, b) => (rank(a) === rank(b) ? a.index - b.index : rank(b) - rank(a)))
const tieAtTop = board.length > 1 && board[0].score !== null && board[0].score === board[1].score
const needsAdjudication = shortlist.length === 0 || stageDropped > 0 || tieAtTop
  || board.some(b => b.score === null || b.dropped > 0 || b.errored.length > 0)
winner = board.length ? board[0].index : null
const reconciliation = board.map(b => ({ name: b.name, votesSent: b.votesSent, votesReturned: b.votesReturned, dropped: b.dropped, errored: b.errored }))
return { winner: needsAdjudication ? null : candidates[winner].name, provisionalWinner: board.length ? board[0].name : null, needsAdjudication, reconciliation, board }
