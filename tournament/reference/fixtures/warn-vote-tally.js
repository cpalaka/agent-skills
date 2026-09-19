export const meta = { name: 'x', description: 'y', phases: [{ title: 'A' }] }
phase('A')
// The WARN control for the whole-file vote reconciliation rule — the oldest of the three
// reconciliation rules (measured 2026-06-28) and, until 2026-09-18, the only one of them with no
// fixture. A tally that filters its ballots and then names a single victor, with no accounting of how
// many were sent against how many came back: one lost ballot silently changes who won.
// Kept to ONE warning, which is what makes the rule falsifiable here. Two things hold that. The
// binding is consumed immediately rather than bound raw, so the parallel() null-guard rule does not
// also fire; and no stage marker and no `board` binding appear, so the scoreboard ERROR rule finds no
// region. The reconciliation tokens this rule looks for are, necessarily, absent from the prose too.
const ballots = (await parallel([
  () => agent('vote', { model: 'claude-opus-5' }),
  () => agent('vote', { model: 'claude-opus-5' }),
])).filter(Boolean)
const winner = ballots.sort((a, b) => b.score - a.score)[0]
return winner
