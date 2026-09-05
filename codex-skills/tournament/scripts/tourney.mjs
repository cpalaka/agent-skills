#!/usr/bin/env node
// tourney.mjs — the Codex-side tournament instrument. Plain Node, run by the parent Codex
// session (never by a child). It does the one thing a fan-out cannot be trusted to do for
// itself: reconcile what was SENT against what came BACK, by file, and refuse to tally a
// scoreboard over a short set.
//
//   reconcile <stage-dir> --sent <ids-file> [--expect N]
//       sent      one item id per line (the parent writes this BEFORE dispatching)
//       returned  <stage-dir>/<id>.json exists and parses as a JSON object
//       errored   the file exists but is empty or not a JSON object
//       dropped   the file is absent
//       --expect  the pre-derived input count; a mismatch is RED (an input-starved run
//                 completes "successfully" otherwise — multi-agent-policy § Fan-out → verify)
//       exit 0 GREEN, 1 RED, 2 usage
//
//   board <judge-dir> --sent <ids-file> --candidates <ids-file>
//       judge item id = "<judge>__<candidate>", file = {judge, candidate, score, rationale}
//       scoreboard per candidate: votesSent, votesReturned, total, mean; needsAdjudication
//       when any vote is missing or the top is tied (a dropped vote flips a winner silently,
//       measured 2026-06-28). Exit 1 when needsAdjudication.
//
//   rollouts <parent-thread-id> [--sessions <dir>]
//       every child rollout whose session_meta names this parent: task path, nickname, role,
//       model, reasoning_effort, sandbox. This is how a per-stage pin is VERIFIED rather than
//       reported — the parent's own account of what it dispatched is a claim.
//
//   selftest
//       builds known-bad and known-good fixtures under $TMPDIR and asserts each verdict.
//       Run it before believing any GREEN from reconcile/board.

import { readFileSync, writeFileSync, existsSync, readdirSync, mkdtempSync, mkdirSync, statSync } from 'node:fs'
import { join, basename } from 'node:path'
import { tmpdir, homedir } from 'node:os'

const argv = process.argv.slice(2)
const cmd = argv[0]

function opt(name) {
  const i = argv.indexOf(name)
  return i >= 0 && i + 1 < argv.length ? argv[i + 1] : undefined
}
function readIds(file) {
  return readFileSync(file, 'utf8').split('\n').map(s => s.trim()).filter(s => s && !s.startsWith('#'))
}
function usage() {
  console.error('usage: tourney.mjs reconcile <stage-dir> --sent <file> [--expect N]\n' +
    '       tourney.mjs board <judge-dir> --sent <file> --candidates <file>\n' +
    '       tourney.mjs rollouts <parent-thread-id> [--sessions <dir>]\n' +
    '       tourney.mjs selftest')
  process.exit(2)
}

// ---------------------------------------------------------------- reconcile

function reconcileStage(dir, sent) {
  const returned = [], dropped = [], errored = []
  for (const id of sent) {
    const f = join(dir, id + '.json')
    if (!existsSync(f)) { dropped.push(id); continue }
    try {
      const txt = readFileSync(f, 'utf8')
      const v = JSON.parse(txt)
      if (v && typeof v === 'object' && !Array.isArray(v)) returned.push(id)
      else errored.push(id)
    } catch { errored.push(id) }
  }
  // Files nobody asked for: a duplicate or self-named child wrote outside the accounting
  // (measured 2026-08-27). Listed, never counted as returned.
  const unassigned = existsSync(dir)
    ? readdirSync(dir).filter(n => n.endsWith('.json')).map(n => n.slice(0, -5)).filter(n => !sent.includes(n))
    : []
  return { sent, returned, dropped, errored, unassigned }
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
  if (r.errored.length) { lines.push(`FAIL  errored: ${r.errored.join(', ')}`); red = true }
  if (r.unassigned.length) lines.push(`      unassigned (not counted): ${r.unassigned.join(', ')}`)
  if (!r.dropped.length && !r.errored.length) lines.push(`PASS  every sent item returned a JSON object`)
  lines.push(red ? `VERDICT: RED — re-dispatch the dropped/errored items, then reconcile again` : `VERDICT: GREEN (${label})`)
  return { text: lines.join('\n'), red }
}

function cmdReconcile() {
  const dir = argv[1]; const sentFile = opt('--sent'); const expect = opt('--expect')
  if (!dir || !sentFile) usage()
  const r = reconcileStage(dir, readIds(sentFile))
  const out = printReconcile(basename(dir), r, expect)
  console.log(out.text)
  process.exit(out.red ? 1 : 0)
}

// ---------------------------------------------------------------- board

function buildBoard(dir, sent, candidates) {
  const r = reconcileStage(dir, sent)
  const rows = candidates.map(c => ({ candidate: c, votesSent: 0, votesReturned: 0, total: 0, scores: [] }))
  const byCand = Object.fromEntries(rows.map(x => [x.candidate, x]))
  const unknownCand = []
  for (const id of sent) {
    const sep = id.indexOf('__')
    const cand = sep >= 0 ? id.slice(sep + 2) : id
    if (!byCand[cand]) { unknownCand.push(id); continue }
    byCand[cand].votesSent++
    if (r.returned.includes(id)) {
      const v = JSON.parse(readFileSync(join(dir, id + '.json'), 'utf8'))
      const s = Number(v.score)
      if (Number.isFinite(s)) { byCand[cand].votesReturned++; byCand[cand].total += s; byCand[cand].scores.push(s) }
      else r.errored.push(id)
    }
  }
  for (const x of rows) x.mean = x.votesReturned ? x.total / x.votesReturned : null
  const ranked = [...rows].sort((a, b) => (b.mean ?? -Infinity) - (a.mean ?? -Infinity))
  const missing = rows.filter(x => x.votesReturned < x.votesSent)
  const tie = ranked.length > 1 && ranked[0].mean !== null && ranked[0].mean === ranked[1].mean
  const needsAdjudication = missing.length > 0 || tie || unknownCand.length > 0 || r.errored.length > 0
  return { r, ranked, missing, tie, unknownCand, needsAdjudication, winner: needsAdjudication ? null : ranked[0]?.candidate ?? null }
}

function cmdBoard() {
  const dir = argv[1]; const sentFile = opt('--sent'); const candFile = opt('--candidates')
  if (!dir || !sentFile || !candFile) usage()
  const b = buildBoard(dir, readIds(sentFile), readIds(candFile))
  console.log(printReconcile(basename(dir), b.r).text)
  console.log('')
  console.log('SCOREBOARD  (mean of returned votes; votesReturned/votesSent)')
  for (const x of b.ranked) {
    const flag = x.votesReturned < x.votesSent ? '  <- missing vote(s)' : ''
    console.log(`  ${String(x.mean === null ? '-' : x.mean.toFixed(2)).padStart(6)}  ${x.votesReturned}/${x.votesSent}  ${x.candidate}${flag}`)
  }
  if (b.unknownCand.length) console.log(`FAIL  votes for a candidate not in the list: ${b.unknownCand.join(', ')}`)
  if (b.tie) console.log(`FAIL  tie at the top: ${b.ranked[0].candidate} and ${b.ranked[1].candidate}`)
  if (b.needsAdjudication) {
    console.log(`needsAdjudication: true — do not report a winner; recover the missing votes or adjudicate in the main loop`)
    console.log(`VERDICT: RED (board)`)
    process.exit(1)
  }
  console.log(`needsAdjudication: false`)
  console.log(`WINNER: ${b.winner}`)
  console.log(`VERDICT: GREEN (board)`)
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

function cmdRollouts() {
  const parent = argv[1]
  if (!parent) usage()
  const root = opt('--sessions') ?? join(homedir(), '.codex', 'sessions')
  const found = []
  for (const f of walk(root)) {
    let first
    try { first = readFileSync(f, 'utf8').split('\n', 1)[0] } catch { continue }
    if (!first.includes(parent)) continue
    let meta
    try { meta = JSON.parse(first) } catch { continue }
    if (meta.type !== 'session_meta' || meta.payload?.parent_thread_id !== parent) continue
    const txt = readFileSync(f, 'utf8')
    const effort = [...txt.matchAll(/"reasoning_effort":"([a-z]+)"/g)].map(m => m[1])
    const model = [...txt.matchAll(/"model":"([^"]+)"/g)].map(m => m[1])
    const sandbox = txt.match(/"sandbox_policy":\{"type":"([^"]+)"/)?.[1] ?? '?'
    const spawn = meta.payload.source?.subagent?.thread_spawn ?? {}
    found.push({
      file: f,
      id: meta.payload.id,
      path: spawn.agent_path ?? meta.payload.agent_path ?? '?',
      nickname: spawn.agent_nickname ?? '?',
      role: spawn.agent_role ?? '-',
      model: [...new Set(model)].join('|') || '?',
      effort: [...new Set(effort)].join('|') || '?',
      sandbox,
      started: meta.timestamp,
    })
  }
  found.sort((a, b) => a.started.localeCompare(b.started))
  console.log(`children of ${parent}: ${found.length}  (scanned ${root})`)
  for (const c of found) console.log(`  ${c.started}  ${c.path.padEnd(28)} role=${c.role.padEnd(18)} model=${c.model.padEnd(14)} effort=${c.effort.padEnd(7)} sandbox=${c.sandbox}  ${c.id}`)
  const multi = found.filter(c => c.effort.includes('|') || c.model.includes('|'))
  if (multi.length) console.log(`WARN  ${multi.length} child(ren) carry more than one model/effort value in their rollout — read the file`)
}

// ---------------------------------------------------------------- selftest

function cmdSelftest() {
  let fails = 0
  const check = (name, cond) => { console.log(`${cond ? 'PASS' : 'FAIL'}  ${name}`); if (!cond) fails++ }
  const root = mkdtempSync(join(tmpdir(), 'tourney-selftest-'))

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
    const [j, c] = id.split('__')
    writeFileSync(join(jd, id + '.json'), JSON.stringify({ judge: j, candidate: c, score: score[c], rationale: 'x' }))
  }
  const b1 = buildBoard(jd, sent, cands)
  check('board: missing vote -> needsAdjudication, no winner', b1.needsAdjudication && b1.winner === null && b1.missing.length === 1 && b1.missing[0].candidate === 'c2')
  writeFileSync(join(jd, 'j2__c2.json'), JSON.stringify({ judge: 'j2', candidate: 'c2', score: 6, rationale: 'x' }))
  const b2 = buildBoard(jd, sent, cands)
  check('board: recovered vote -> winner c1, no adjudication', !b2.needsAdjudication && b2.winner === 'c1')
  writeFileSync(join(jd, 'j2__c2.json'), JSON.stringify({ judge: 'j2', candidate: 'c2', score: 10, rationale: 'x' }))
  const b3 = buildBoard(jd, sent, cands)
  check('board: tie at the top -> needsAdjudication', b3.needsAdjudication && b3.tie)
  writeFileSync(join(jd, 'j2__c2.json'), JSON.stringify({ judge: 'j2', candidate: 'c2', rationale: 'no score field' }))
  const b4 = buildBoard(jd, sent, cands)
  check('board: vote without a numeric score -> errored, needsAdjudication', b4.needsAdjudication && b4.r.errored.includes('j2__c2'))

  // rollouts: a fixture session dir with one child of parent P and one stranger
  const sess = join(root, 'sessions', '2026', '09', '04'); mkdirSync(sess, { recursive: true })
  const meta = (id, parent, extra = {}) => JSON.stringify({ timestamp: '2026-09-04T00:00:00Z', type: 'session_meta', payload: { id, parent_thread_id: parent, source: { subagent: { thread_spawn: { parent_thread_id: parent, agent_path: '/root/gen_1', agent_nickname: 'N', agent_role: null, ...extra } } } } })
  const ctx = (m, e) => JSON.stringify({ type: 'turn_context', payload: { model: m, reasoning_effort: e, sandbox_policy: { type: 'workspace-write' } } })
  writeFileSync(join(sess, 'rollout-x-child.jsonl'), meta('child-1', 'P') + '\n' + ctx('m-x', 'low') + '\n')
  writeFileSync(join(sess, 'rollout-x-other.jsonl'), meta('child-2', 'Q') + '\n' + ctx('m-x', 'high') + '\n')
  const saved = argv.slice()
  argv.length = 0; argv.push('rollouts', 'P', '--sessions', join(root, 'sessions'))
  let captured = ''
  const origLog = console.log; console.log = (...a) => { captured += a.join(' ') + '\n' }
  try { cmdRollouts() } finally { console.log = origLog; argv.length = 0; argv.push(...saved) }
  check('rollouts: finds the one child of P with effort=low, not the stranger', captured.includes('children of P: 1') && captured.includes('effort=low') && !captured.includes('child-2'))

  console.log(fails ? `VERDICT: RED — ${fails} selftest assertion(s) failed` : 'VERDICT: GREEN (selftest)')
  process.exit(fails ? 1 : 0)
}

// ---------------------------------------------------------------- main

switch (cmd) {
  case 'reconcile': cmdReconcile(); break
  case 'board': cmdBoard(); break
  case 'rollouts': cmdRollouts(); break
  case 'selftest': cmdSelftest(); break
  default: usage()
}
