// Fixture: the canonical scoreboard stage assembled minimally — identity + scale validation, dropped and
// errored buckets, a deterministic winner and needsAdjudication. Expected: exit 0, no WARN.
export const meta = {
  name: 'sb-reconciled',
  description: 'scoreboard tally that validates and reconciles every judge ballot',
  phases: [{ title: 'Tournament', detail: 'judge panel' }],
}
const JUDGE_SCHEMA = {
  type: 'object',
  properties: { persona: { type: 'string' }, candidate: { type: 'string' }, score: { type: 'number' } },
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
const voteFault = (v, judge, cand) => {
  if (v.persona !== judge.persona) return `persona '${v.persona}' != assigned '${judge.persona}'`
  if (v.candidate !== cand.name) return `candidate '${v.candidate}' != assigned '${cand.name}'`
  if (typeof v.score !== 'number' || !Number.isFinite(v.score)) return `score is not a finite number`
  if (SCORE_SCALE.integer && !Number.isInteger(v.score)) return `score ${v.score} is not an integer`
  if (v.score < SCORE_SCALE.min || v.score > SCORE_SCALE.max) return `score ${v.score} out of scale`
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
        if (dropped || errored.length) log(`⚠ ${c.name}: ${valid.length}/${js.length} valid`)
        return { index: idx, name: c.name, score, votesSent: js.length, votesReturned: js.length - dropped, dropped, errored, generationFailed: false }
      })
  }
)
const judged = rawJudged.filter(Boolean)
const stageDropped = rawJudged.length - judged.length
const rank = (x) => (x.score === null ? -Infinity : x.score)
const board = judged.sort((a, b) => (rank(a) === rank(b) ? a.index - b.index : rank(b) - rank(a)))
const tieAtTop = board.length > 1 && board[0].score !== null && board[0].score === board[1].score
const needsAdjudication = JUDGES.length === 0 || shortlist.length === 0 || stageDropped > 0 || tieAtTop
  || board.some(b => b.score === null || b.dropped > 0 || b.errored.length > 0)
const winner = board.length ? board[0].index : null
return { winner: needsAdjudication ? null : candidates[winner].name, provisionalWinner: board.length ? board[0].name : null, needsAdjudication, board }
