#!/usr/bin/env node
// tourney.mjs — the Codex-side tournament instrument. Plain Node, run by the parent Codex
// session (never by a child). It does the one thing a fan-out cannot be trusted to do for
// itself: reconcile what was SENT against what came BACK, by file, and refuse to tally a
// scoreboard over a short, malformed or ambiguous set.
//
//   reconcile <stage-dir> --sent <ids-file> [--expect N]
//       sent      one item id per line (the parent writes this BEFORE dispatching); a
//                 duplicate id in the list is RED on its own (the accounting would count one
//                 file twice)
//       returned  <stage-dir>/<id>.json exists and parses as a JSON object
//       errored   the file exists but is empty or not a JSON object
//       dropped   the file is absent
//       unassigned  a <stage-dir>/*.json nobody asked for — listed, never counted; `board`
//                 treats any as needsAdjudication until the parent dispositions it
//       --expect  the pre-derived input count; a mismatch is RED (an input-starved run
//                 completes "successfully" otherwise — multi-agent-policy § Fan-out → verify)
//       The buckets are disjoint and sum to sent. Exit 0 GREEN, 1 RED, 2 usage.
//
//   board <judge-dir> --sent <ids-file> --candidates <ids-file> [--scale MIN..MAX] [--integer]
//       judge item id = "<judge>__<candidate>", file = {judge, candidate, score, rationale}
//       A vote counts only if: its `judge` and `candidate` fields equal the filename's two
//       parts (payload identity), and `score` is a JSON number within --scale (default
//       0..10; the canonical JUDGE_SCHEMA is `number`, so integer-ness is NOT required unless
//       --integer is passed — pass it when the spec says integer). Anything else → errored
//       with the reason printed, never tallied.
//       Scoreboard per candidate: votesSent, votesReturned, total, mean. needsAdjudication
//       (no winner, exit 1) when any vote is missing or errored, the top is tied, any
//       candidate has votesSent == 0, the sent list is empty, or unassigned files exist
//       (a dropped vote flips a winner silently, measured 2026-06-28).
//
//   rollouts <parent-thread-id> [--sessions <dir>]
//       every child rollout whose session_meta names this parent: task path, nickname, role,
//       model, effort, sandbox — read from TYPED records: the last `turn_context` whose
//       turn_id != root_turn_id (the child's own turn, not a copied parent turn), falling
//       back to the `thread_settings_applied` event; `?` only when neither exists. This is
//       how a per-stage pin is VERIFIED rather than reported — the parent's own account of
//       what it dispatched is a claim.
//
//   selftest
//       builds known-bad and known-good fixtures under $TMPDIR (removed afterwards) and
//       asserts each verdict. Run it before believing any GREEN from reconcile/board.

import { readFileSync, writeFileSync, existsSync, readdirSync, mkdtempSync, mkdirSync, rmSync } from 'node:fs'
import { join, basename } from 'node:path'
import { tmpdir, homedir } from 'node:os'

const argv = process.argv.slice(2)
const cmd = argv[0]

function opt(name) {
  const i = argv.indexOf(name)
  return i >= 0 && i + 1 < argv.length ? argv[i + 1] : undefined
}
// Returns { ids, dups }. A duplicate id is a defect in the sent list itself: the same file
// would satisfy two assignments and --expect would still balance.
function readIdsChecked(file) {
  const ids = readFileSync(file, 'utf8').split('\n').map(s => s.trim()).filter(s => s && !s.startsWith('#'))
  const seen = new Set(), dups = []
  for (const id of ids) { if (seen.has(id)) { if (!dups.includes(id)) dups.push(id) } else seen.add(id) }
  return { ids, dups }
}
function readIdsOrDie(file, label) {
  const { ids, dups } = readIdsChecked(file)
  if (dups.length) {
    console.log(`FAIL  duplicate ${label} id(s): ${dups.join(', ')} — one file would satisfy two assignments`)
    console.log('VERDICT: RED — fix the sent list before dispatching or reconciling')
    process.exit(1)
  }
  return ids
}
function parseScale(s) {
  const m = /^(-?\d+)\.\.(-?\d+)$/.exec(s ?? '0..10')
  if (!m) { console.error(`bad --scale '${s}', want MIN..MAX`); process.exit(2) }
  return { min: Number(m[1]), max: Number(m[2]) }
}
function usage() {
  console.error('usage: tourney.mjs reconcile <stage-dir> --sent <file> [--expect N]\n' +
    '       tourney.mjs board <judge-dir> --sent <file> --candidates <file> [--scale MIN..MAX] [--integer]\n' +
    '       tourney.mjs rollouts <parent-thread-id> [--sessions <dir>]\n' +
    '       tourney.mjs selftest')
  process.exit(2)
}

// ---------------------------------------------------------------- reconcile

function reconcileStage(dir, sent) {
  const returned = [], dropped = [], errored = [], reasons = {}
  for (const id of sent) {
    const f = join(dir, id + '.json')
    if (!existsSync(f)) { dropped.push(id); continue }
    try {
      const txt = readFileSync(f, 'utf8')
      const v = JSON.parse(txt)
      if (v && typeof v === 'object' && !Array.isArray(v)) returned.push(id)
      else { errored.push(id); reasons[id] = 'not a JSON object' }
    } catch { errored.push(id); reasons[id] = 'empty or unparseable' }
  }
  // Files nobody asked for: a duplicate or self-named child wrote outside the accounting
  // (measured 2026-08-27). Listed, never counted as returned.
  const unassigned = existsSync(dir)
    ? readdirSync(dir).filter(n => n.endsWith('.json')).map(n => n.slice(0, -5)).filter(n => !sent.includes(n))
    : []
  return { sent, returned, dropped, errored, reasons, unassigned }
}

// Move an id from returned to errored with a reason; keeps the buckets disjoint.
function demote(r, id, reason) {
  const i = r.returned.indexOf(id)
  if (i >= 0) r.returned.splice(i, 1)
  if (!r.errored.includes(id)) r.errored.push(id)
  r.reasons[id] = reason
}

function printReconcile(label, r, expect) {
  const lines = []
  let red = false
  if (expect !== undefined) {
    if (r.sent.length === Number(expect)) lines.push(`PASS  sent=${r.sent.length} matches --expect ${expect}`)
    else { lines.push(`FAIL  sent=${r.sent.length} but --expect ${expect} — the input layer did not arrive as planned`); red = true }
  }
  lines.push(`RECONCILE ${label}: sent=${r.sent.length} returned=${r.returned.length} dropped=${r.dropped.length} errored=${r.errored.length} unassigned=${r.unassigned.length}`)
  if (r.dropped.length) { lines.push(`FAIL  dropped: ${r.dropped.join(', ')}`); red = true }
  if (r.errored.length) { lines.push(`FAIL  errored: ${r.errored.map(id => `${id} (${r.reasons[id] ?? '?'})`).join(', ')}`); red = true }
  if (r.unassigned.length) lines.push(`      unassigned (not counted; disposition before the board): ${r.unassigned.join(', ')}`)
  if (!r.dropped.length && !r.errored.length) lines.push(`PASS  every sent item returned a JSON object`)
  lines.push(red ? `VERDICT: RED — re-dispatch the dropped/errored items, then reconcile again` : `VERDICT: GREEN (${label})`)
  return { text: lines.join('\n'), red }
}

function cmdReconcile() {
  const dir = argv[1]; const sentFile = opt('--sent'); const expect = opt('--expect')
  if (!dir || !sentFile) usage()
  const r = reconcileStage(dir, readIdsOrDie(sentFile, 'sent'))
  const out = printReconcile(basename(dir), r, expect)
  console.log(out.text)
  process.exit(out.red ? 1 : 0)
}

// ---------------------------------------------------------------- board

function validVote(v, judge, cand, scale) {
  if (v.judge !== judge) return `payload judge '${v.judge}' != assignment '${judge}'`
  if (v.candidate !== cand) return `payload candidate '${v.candidate}' != assignment '${cand}'`
  if (typeof v.score !== 'number' || !Number.isFinite(v.score)) return `score is ${v.score === null ? 'null' : typeof v.score}, not a number`
  if (scale.integer && !Number.isInteger(v.score)) return `score ${v.score} is not an integer (--integer)`
  if (v.score < scale.min || v.score > scale.max) return `score ${v.score} outside ${scale.min}..${scale.max}`
  return null
}

function buildBoard(dir, sent, candidates, scale = { min: 0, max: 10 }) {
  const r = reconcileStage(dir, sent)
  const rows = candidates.map(c => ({ candidate: c, votesSent: 0, votesReturned: 0, total: 0, scores: [] }))
  const byCand = Object.fromEntries(rows.map(x => [x.candidate, x]))
  const unknownCand = []
  for (const id of sent) {
    const sep = id.indexOf('__')
    const judge = sep >= 0 ? id.slice(0, sep) : ''
    const cand = sep >= 0 ? id.slice(sep + 2) : id
    if (!byCand[cand]) { unknownCand.push(id); continue }
    byCand[cand].votesSent++
    if (r.returned.includes(id)) {
      const v = JSON.parse(readFileSync(join(dir, id + '.json'), 'utf8'))
      const why = validVote(v, judge, cand, scale)
      if (why) demote(r, id, why)
      else { byCand[cand].votesReturned++; byCand[cand].total += v.score; byCand[cand].scores.push(v.score) }
    }
  }
  for (const x of rows) x.mean = x.votesReturned ? x.total / x.votesReturned : null
  const ranked = [...rows].sort((a, b) => (b.mean ?? -Infinity) - (a.mean ?? -Infinity))
  const missing = rows.filter(x => x.votesReturned < x.votesSent)
  const uncovered = rows.filter(x => x.votesSent === 0)
  const tie = ranked.length > 1 && ranked[0].mean !== null && ranked[0].mean === ranked[1].mean
  const needsAdjudication = sent.length === 0 || missing.length > 0 || uncovered.length > 0 || tie
    || unknownCand.length > 0 || r.errored.length > 0 || r.unassigned.length > 0
  return { r, ranked, missing, uncovered, tie, unknownCand, needsAdjudication, winner: needsAdjudication ? null : ranked[0]?.candidate ?? null }
}

function printBoard(b) {
  const lines = [printReconcile('judge', b.r).text, '']
  lines.push('SCOREBOARD  (mean of valid votes; votesReturned/votesSent)')
  for (const x of b.ranked) {
    const flag = x.votesSent === 0 ? '  <- no votes assigned' : x.votesReturned < x.votesSent ? '  <- missing/errored vote(s)' : ''
    lines.push(`  ${String(x.mean === null ? '-' : x.mean.toFixed(2)).padStart(6)}  ${x.votesReturned}/${x.votesSent}  ${x.candidate}${flag}`)
  }
  if (b.r.sent.length === 0) lines.push('FAIL  the sent list is empty — nothing was assigned')
  if (b.uncovered.length) lines.push(`FAIL  candidate(s) with no assigned vote: ${b.uncovered.map(x => x.candidate).join(', ')}`)
  if (b.unknownCand.length) lines.push(`FAIL  votes for a candidate not in the list: ${b.unknownCand.join(', ')}`)
  if (b.r.unassigned.length) lines.push(`FAIL  unassigned file(s) in the judge dir need a disposition: ${b.r.unassigned.join(', ')}`)
  if (b.tie) lines.push(`FAIL  tie at the top: ${b.ranked[0].candidate} and ${b.ranked[1].candidate}`)
  if (b.needsAdjudication) {
    lines.push('needsAdjudication: true — do not report a winner; recover the missing votes or adjudicate in the main loop')
    lines.push('VERDICT: RED (board)')
  } else {
    lines.push('needsAdjudication: false')
    lines.push(`WINNER: ${b.winner}`)
    lines.push('VERDICT: GREEN (board)')
  }
  return lines.join('\n')
}

function cmdBoard() {
  const dir = argv[1]; const sentFile = opt('--sent'); const candFile = opt('--candidates')
  if (!dir || !sentFile || !candFile) usage()
  const scale = parseScale(opt('--scale')); scale.integer = argv.includes('--integer')
  const b = buildBoard(dir, readIdsOrDie(sentFile, 'sent'), readIdsOrDie(candFile, 'candidate'), scale)
  console.log(printBoard(b))
  process.exit(b.needsAdjudication ? 1 : 0)
}

// ---------------------------------------------------------------- rollouts

function* walk(dir) {
  let ents = []
  try { ents = readdirSync(dir, { withFileTypes: true }) } catch { return }
  for (const e of ents) {
    const p = join(dir, e.name)
    if (e.isDirectory()) yield* walk(p)
    else if (e.isFile() && e.name.startsWith('rollout-') && e.name.endsWith('.jsonl')) yield p
  }
}

// Typed-record reading of one child rollout. Returns null when the file is not a child of
// `parent`. `ownTurns` counts the child's own turn_context records (a fork_turns "none" child
// carries exactly one; a full fork also carries the parent's copied turn, root_turn_id == turn_id).
function readChildRollout(file, parent) {
  let first
  try { first = readFileSync(file, 'utf8').split('\n', 1)[0] } catch { return null }
  if (!first.includes(parent)) return null
  let meta
  try { meta = JSON.parse(first) } catch { return null }
  if (meta.type !== 'session_meta' || meta.payload?.parent_thread_id !== parent) return null
  let own = null, ownTurns = 0, copied = 0, settings = null, sandbox = null
  for (const line of readFileSync(file, 'utf8').split('\n')) {
    if (!line) continue
    let e; try { e = JSON.parse(line) } catch { continue }
    const p = e.payload ?? {}
    if (e.type === 'turn_context') {
      if (p.turn_id && p.root_turn_id && p.turn_id !== p.root_turn_id) { own = p; ownTurns++ } else copied++
      sandbox = p.sandbox_policy?.type ?? sandbox
    } else if (e.type === 'event_msg' && p.type === 'thread_settings_applied') {
      settings = p.thread_settings ?? null
    }
  }
  const spawn = meta.payload.source?.subagent?.thread_spawn ?? {}
  const src = own ? 'own-turn' : settings ? 'thread-settings' : 'none'
  return {
    file, id: meta.payload.id, started: meta.timestamp,
    path: spawn.agent_path ?? meta.payload.agent_path ?? '?',
    nickname: spawn.agent_nickname ?? '?', role: spawn.agent_role ?? '-',
    model: own?.model ?? settings?.model ?? '?',
    effort: own?.effort ?? settings?.reasoning_effort ?? '?',
    sandbox: sandbox ?? '?', src, ownTurns, copied,
  }
}

function rolloutsReport(parent, root) {
  const found = []
  for (const f of walk(root)) { const c = readChildRollout(f, parent); if (c) found.push(c) }
  found.sort((a, b) => a.started.localeCompare(b.started))
  const lines = [`children of ${parent}: ${found.length}  (scanned ${root})`]
  for (const c of found) lines.push(`  ${c.started}  ${c.path.padEnd(28)} role=${c.role.padEnd(18)} model=${c.model.padEnd(14)} effort=${c.effort.padEnd(7)} sandbox=${c.sandbox.padEnd(16)} from=${c.src} ownTurns=${c.ownTurns} copiedTurns=${c.copied}  ${c.id}`)
  const blind = found.filter(c => c.src === 'none')
  if (blind.length) lines.push(`WARN  ${blind.length} child(ren) have neither an own-turn turn_context nor thread_settings_applied — pins unverified for them`)
  return { found, text: lines.join('\n') }
}

function cmdRollouts() {
  const parent = argv[1]
  if (!parent) usage()
  const root = opt('--sessions') ?? join(homedir(), '.codex', 'sessions')
  console.log(rolloutsReport(parent, root).text)
}

// ---------------------------------------------------------------- selftest

function cmdSelftest() {
  const root = mkdtempSync(join(tmpdir(), 'tourney-selftest-'))
  let fails
  try { fails = runSelftest(root) } finally { rmSync(root, { recursive: true, force: true }) }
  console.log(fails ? `VERDICT: RED — ${fails} selftest assertion(s) failed` : 'VERDICT: GREEN (selftest)')
  process.exit(fails ? 1 : 0)
}

function runSelftest(root) {
  let fails = 0
  const check = (name, cond) => { console.log(`${cond ? 'PASS' : 'FAIL'}  ${name}`); if (!cond) fails++ }
  const vote = (dir, j, c, extra) => writeFileSync(join(dir, `${j}__${c}.json`), JSON.stringify({ judge: j, candidate: c, rationale: 'x', ...extra }))

  // known-bad reconcile: a valid, b malformed, c absent, z unassigned
  const bad = join(root, 'gen'); mkdirSync(bad)
  writeFileSync(join(bad, 'a.json'), '{"body":"ok"}')
  writeFileSync(join(bad, 'b.json'), '{not json')
  writeFileSync(join(bad, 'z.json'), '{"body":"nobody asked"}')
  const r1 = reconcileStage(bad, ['a', 'b', 'c'])
  const p1 = printReconcile('gen', r1, 3)
  check('known-bad: dropped=[c]', r1.dropped.join() === 'c')
  check('known-bad: errored=[b]', r1.errored.join() === 'b')
  check('known-bad: returned=[a]', r1.returned.join() === 'a')
  check('known-bad: unassigned=[z] not counted', r1.unassigned.join() === 'z' && r1.returned.length === 1)
  check('known-bad: VERDICT RED', p1.red && p1.text.includes('VERDICT: RED'))
  const p1e = printReconcile('gen', reconcileStage(bad, ['a']), 3)
  check('known-bad: --expect mismatch is RED even with every item returned', p1e.red)

  // L3: duplicate sent ids are refused before any counting
  const dupFile = join(root, 'dup.sent'); writeFileSync(dupFile, 'j1__a\nj1__b\nj1__a\nj2__b\n')
  const d = readIdsChecked(dupFile)
  check('duplicate sent id -> refused (dups=[j1__a])', d.dups.join() === 'j1__a')
  const cleanFile = join(root, 'clean.sent'); writeFileSync(cleanFile, 'j1__a\nj1__b\n')
  check('clean sent list -> no dups', readIdsChecked(cleanFile).dups.length === 0)

  // known-good reconcile
  const good = join(root, 'gen-good'); mkdirSync(good)
  for (const id of ['a', 'b', 'c']) writeFileSync(join(good, id + '.json'), JSON.stringify({ body: id }))
  const p2 = printReconcile('gen-good', reconcileStage(good, ['a', 'b', 'c']), 3)
  check('known-good: VERDICT GREEN', !p2.red && p2.text.includes('VERDICT: GREEN'))

  // board: one missing vote must block the winner; complete votes must name it
  const jd = join(root, 'judge'); mkdirSync(jd)
  const judges = ['j1', 'j2'], cands = ['c1', 'c2']
  const sent = []
  for (const j of judges) for (const c of cands) sent.push(`${j}__${c}`)
  const score = { c1: 8, c2: 6 }
  for (const id of sent) {
    if (id === 'j2__c2') continue // the deliberately dropped vote
    const [j, c] = id.split('__'); vote(jd, j, c, { score: score[c] })
  }
  const b1 = buildBoard(jd, sent, cands)
  check('board: missing vote -> needsAdjudication, no winner', b1.needsAdjudication && b1.winner === null && b1.missing.length === 1 && b1.missing[0].candidate === 'c2')
  vote(jd, 'j2', 'c2', { score: 6 })
  const b2 = buildBoard(jd, sent, cands)
  check('board: recovered vote -> winner c1, no adjudication', !b2.needsAdjudication && b2.winner === 'c1')
  vote(jd, 'j2', 'c2', { score: 10 })
  const b3 = buildBoard(jd, sent, cands)
  check('board: tie at the top -> needsAdjudication', b3.needsAdjudication && b3.tie)
  writeFileSync(join(jd, 'j2__c2.json'), JSON.stringify({ judge: 'j2', candidate: 'c2', rationale: 'no score field' }))
  const b4 = buildBoard(jd, sent, cands)
  check('board: vote without a score -> errored, needsAdjudication', b4.needsAdjudication && b4.r.errored.includes('j2__c2'))
  const p4 = printReconcile('judge', b4.r)
  check('board: buckets disjoint on the printed line (returned=3 errored=1 of sent=4)', p4.text.includes('sent=4 returned=3 dropped=0 errored=1') && !b4.r.returned.includes('j2__c2'))

  // L1: invalid scores are errored, never tallied — each would otherwise flip c2 over c1
  for (const [label, s] of [['score 100', 100], ['score null', null], ['score "7" (string)', '7']]) {
    vote(jd, 'j2', 'c2', { score: s })
    const b = buildBoard(jd, sent, cands)
    const line = printBoard(b)
    check(`L1 ${label} -> errored, RED (${b.r.reasons['j2__c2'] ?? 'no reason'})`, b.needsAdjudication && b.r.errored.includes('j2__c2') && line.includes('VERDICT: RED (board)') && b.ranked.find(x => x.candidate === 'c2').votesReturned === 1)
  }
  vote(jd, 'j2', 'c2', { score: 7.5 })
  check('L1 score 7.5 -> GREEN by default (canonical JUDGE_SCHEMA score is number)', !buildBoard(jd, sent, cands).needsAdjudication)
  const b75 = buildBoard(jd, sent, cands, { min: 0, max: 10, integer: true })
  check(`L1 score 7.5 -> errored, RED under --integer (${b75.r.reasons['j2__c2'] ?? 'no reason'})`, b75.needsAdjudication && b75.r.errored.includes('j2__c2'))
  vote(jd, 'j2', 'c2', { score: 6 })
  check('L1 control: valid number in scale -> GREEN again', !buildBoard(jd, sent, cands).needsAdjudication)
  vote(jd, 'j2', 'c2', { score: 42 })
  check('L1 --scale 0..50 admits 42', !buildBoard(jd, sent, cands, { min: 0, max: 50 }).needsAdjudication)
  vote(jd, 'j2', 'c2', { score: 6 })

  // L2: payload identity — a file in j1__c1's slot claiming candidate c2 (score 10) must not credit c1
  writeFileSync(join(jd, 'j1__c1.json'), JSON.stringify({ judge: 'j1', candidate: 'c2', score: 10, rationale: 'swapped' }))
  const b5 = buildBoard(jd, sent, cands)
  check(`L2 swapped candidate -> errored, RED (${b5.r.reasons['j1__c1'] ?? 'no reason'})`, b5.needsAdjudication && b5.r.errored.includes('j1__c1') && b5.ranked.find(x => x.candidate === 'c1').total === 8)
  writeFileSync(join(jd, 'j1__c1.json'), JSON.stringify({ judge: 'j2', candidate: 'c1', score: 8, rationale: 'wrong judge' }))
  const b5j = buildBoard(jd, sent, cands)
  check(`L2 wrong judge -> errored, RED (${b5j.r.reasons['j1__c1'] ?? 'no reason'})`, b5j.needsAdjudication && b5j.r.errored.includes('j1__c1'))
  vote(jd, 'j1', 'c1', { score: 8 })
  check('L2 control: identity restored -> GREEN', !buildBoard(jd, sent, cands).needsAdjudication)

  // L4: empty electorate / uncovered candidate
  const b6 = buildBoard(jd, [], cands)
  check('L4 empty sent list -> needsAdjudication, no winner', b6.needsAdjudication && b6.winner === null && printBoard(b6).includes('sent list is empty'))
  const b7 = buildBoard(jd, ['j1__c1', 'j2__c1'], cands)
  check('L4 candidate with votesSent=0 -> needsAdjudication', b7.needsAdjudication && b7.uncovered.map(x => x.candidate).join() === 'c2')

  // L5: an unassigned file blocks the board until dispositioned
  writeFileSync(join(jd, 'j9__c1.json'), JSON.stringify({ judge: 'j9', candidate: 'c1', score: 10, rationale: 'unsolicited' }))
  const b8 = buildBoard(jd, sent, cands)
  check('L5 unassigned file -> needsAdjudication, RED', b8.needsAdjudication && b8.r.unassigned.join() === 'j9__c1' && printBoard(b8).includes('need a disposition'))
  rmSync(join(jd, 'j9__c1.json'))
  check('L5 control: disposition (removed) -> GREEN', !buildBoard(jd, sent, cands).needsAdjudication)

  // rollouts: typed records. Child A of parent P: a copied parent turn (high) then its own turn (low),
  // plus thread_settings_applied low — the full-fork shape; child B: own turn only (medium);
  // child C: no typed record at all -> '?'. A stranger under parent Q must not appear.
  const sess = join(root, 'sessions', '2026', '09', '04'); mkdirSync(sess, { recursive: true })
  const meta = (id, parent, path) => JSON.stringify({ timestamp: '2026-09-04T00:00:0' + id.slice(-1) + 'Z', type: 'session_meta', payload: { id, parent_thread_id: parent, source: { subagent: { thread_spawn: { parent_thread_id: parent, agent_path: path, agent_nickname: 'N', agent_role: null } } } } })
  const ctx = (turn, rootTurn, m, e) => JSON.stringify({ type: 'turn_context', payload: { turn_id: turn, root_turn_id: rootTurn, model: m, effort: e, sandbox_policy: { type: 'read-only' } } })
  const settings = (m, e) => JSON.stringify({ type: 'event_msg', payload: { type: 'thread_settings_applied', thread_settings: { model: m, reasoning_effort: e } } })
  const loose = JSON.stringify({ type: 'event_msg', payload: { type: 'agent_message', text: '"reasoning_effort":"xhigh" "model":"decoy"' } })
  writeFileSync(join(sess, 'rollout-a.jsonl'), [meta('child-1', 'P', '/root/a'), ctx('T0', 'T0', 'm-x', 'high'), settings('m-x', 'low'), ctx('T1', 'T0', 'm-x', 'low'), loose].join('\n') + '\n')
  writeFileSync(join(sess, 'rollout-b.jsonl'), [meta('child-2', 'P', '/root/b'), ctx('T2', 'T0', 'm-x', 'medium'), loose].join('\n') + '\n')
  writeFileSync(join(sess, 'rollout-c.jsonl'), [meta('child-3', 'P', '/root/c'), loose].join('\n') + '\n')
  writeFileSync(join(sess, 'rollout-x.jsonl'), [meta('child-9', 'Q', '/root/x'), ctx('T9', 'T0', 'm-x', 'high')].join('\n') + '\n')
  const rr = rolloutsReport('P', join(root, 'sessions'))
  const byPath = Object.fromEntries(rr.found.map(c => [c.path, c]))
  check('rollouts: three children of P, stranger excluded', rr.found.length === 3 && !rr.text.includes('child-9'))
  check('rollouts: full-fork child reads its OWN turn (low), not the copied parent turn (high)', byPath['/root/a']?.effort === 'low' && byPath['/root/a']?.src === 'own-turn' && byPath['/root/a']?.copied === 1 && byPath['/root/a']?.ownTurns === 1)
  check('rollouts: none-fork child reads medium from its single own turn', byPath['/root/b']?.effort === 'medium' && byPath['/root/b']?.copied === 0)
  check('rollouts: decoy text in a message record is ignored (no xhigh anywhere)', !rr.text.includes('xhigh') && !rr.text.includes('decoy'))
  check('rollouts: child with no typed record -> ? and WARN', byPath['/root/c']?.effort === '?' && byPath['/root/c']?.src === 'none' && rr.text.includes('WARN  1 child'))

  return fails
}

// ---------------------------------------------------------------- main

switch (cmd) {
  case 'reconcile': cmdReconcile(); break
  case 'board': cmdBoard(); break
  case 'rollouts': cmdRollouts(); break
  case 'selftest': cmdSelftest(); break
  default: usage()
}
