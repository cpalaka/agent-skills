#!/usr/bin/env node
// Dev tool (plain Node, runs OUTSIDE the Workflow runtime). Lints a generated
// tournament workflow script against the runtime's hard constraints.
import { readFileSync, readdirSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = dirname(fileURLToPath(import.meta.url))
const file = process.argv[2]
if (!file) { console.error('usage: lint.mjs <script.js> | lint.mjs --selftest'); process.exit(2) }

// --selftest: run this linter over every fixture in reference/fixtures/ and check the naming contract —
// `bad-*.js` must exit 1, `good-*.js` must exit 0 with no WARN. The fixtures ARE the linter's calibration
// (a rule nothing reds is a rule nobody has measured); before this they had no runner and drifted unnoticed.
if (file === '--selftest') {
  const dir = join(HERE, 'fixtures')
  let names
  try { names = readdirSync(dir).filter(f => f.endsWith('.js')).sort() }
  catch (e) { console.error(`selftest: cannot read ${dir}: ${e.message}`); process.exit(2) }
  if (!names.length) { console.error(`selftest: no .js fixtures in ${dir}`); process.exit(2) }
  let fails = 0
  for (const n of names) {
    const expectBad = n.startsWith('bad-')
    if (!expectBad && !n.startsWith('good-')) {
      console.log(`FAIL  ${n} — fixture name must start with bad- or good-`); fails++; continue
    }
    let out = '', code = 0
    try { out = execFileSync('node', [fileURLToPath(import.meta.url), join(dir, n)], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }) }
    catch (e) { out = (e.stdout || '') + (e.stderr || ''); code = e.status ?? 1 }
    const warned = /^WARN: /m.test(out)
    const ok = expectBad ? code === 1 : code === 0 && !warned
    if (!ok) fails++
    console.log(`${ok ? 'PASS' : 'FAIL'}  ${n} — exit ${code}${warned ? ', WARN present' : ''} (expected ${expectBad ? 'exit 1' : 'exit 0, no WARN'})`)
  }
  console.log(fails ? `VERDICT: RED — ${fails} of ${names.length} lint fixture(s) off contract`
    : `VERDICT: GREEN (lint --selftest) — ${names.length} fixtures`)
  process.exit(fails ? 1 : 0)
}

const src = readFileSync(file, 'utf8')
const errors = [], warns = []

try { execFileSync('node', ['--check', file], { stdio: 'pipe' }) }
catch (e) { errors.push('node --check failed: ' + (e.stderr?.toString() || e.message)) }

const forbid = [
  [/\bDate\.now\s*\(/, 'Date.now() unavailable in runtime'],
  [/\bMath\.random\s*\(/, 'Math.random() unavailable in runtime'],
  [/\bnew\s+Date\s*\(\s*\)/, 'argless new Date() unavailable in runtime'],
  [/^\s*import\s+/m, 'import statements not allowed in workflow scripts'],
  [/\brequire\s*\(/, 'require() not allowed in workflow scripts'],
  [/\bnode:(fs|child_process|path|os)\b/, 'Node APIs not available in workflow scripts'],
]
for (const [re, msg] of forbid) if (re.test(src)) errors.push(msg)

if (!/export\s+const\s+meta\s*=\s*\{/.test(src)) errors.push('missing literal `export const meta = {`')

const pb = src.match(/phases\s*:\s*\[([\s\S]*?)\]/)
const metaPhases = pb ? [...pb[1].matchAll(/title\s*:\s*['"`]([^'"`]+)['"`]/g)].map(m => m[1]) : []
const called = [...src.matchAll(/\bphase\(\s*['"`]([^'"`]+)['"`]\s*\)/g)].map(m => m[1])
for (const p of new Set(called)) if (!metaPhases.includes(p)) warns.push(`phase("${p}") has no matching meta.phases entry`)

if (/await\s+parallel\(/.test(src) && !/\.filter\(Boolean\)/.test(src))
  warns.push('parallel() used but no .filter(Boolean) — guard against null agent results')

// Every agent() call must pin an explicit model: — no silent session-model inheritance (measured 2026-07-01).
// Heuristic: scan each agent() call's span (up to the next agent() call) for a model: key.
const agentStarts = [...src.matchAll(/\bagent\(/g)].map(m => m.index)
for (let i = 0; i < agentStarts.length; i++) {
  const span = src.slice(agentStarts[i], agentStarts[i + 1] ?? src.length)
  if (!/\bmodel\s*:/.test(span)) {
    const line = src.slice(0, agentStarts[i]).split('\n').length
    errors.push(`agent() call at line ${line} has no explicit model: — pin it to a concrete ID (model: WORKHORSE, or SYNTH_MODEL for the single synthesis agent)`)
  }
}

// Model IDs must be CONCRETE, never short tier aliases (measured 2026-07-24): a CLI alias can lag
// a release and keep serving the prior generation while every rule still reads correct. Catches the
// literal at any model: site — agent() opts, meta.phases display annotations, and const decls alike.
const ALIASES = /\b(?:model|SYNTH_MODEL|WORKHORSE|SCARCE)\s*(?::|=)\s*['"`](opus|fable|sonnet|haiku|mythos)['"`]/g
for (const m of src.matchAll(ALIASES)) {
  const line = src.slice(0, m.index).split('\n').length
  errors.push(`line ${line}: model pinned to the short alias '${m[1]}' — resolve the concrete ID by probe (\`claude -p --output-format json\` reports canonicalModel) and write it out, e.g. 'claude-opus-5'`)
}

// Vote-tallying stages must reconcile SENT vs RETURNED (measured 2026-06-28): a dropped vote can silently flip a winner/consensus/fatalCount.
if (/\b(winner|consensus|fatalCount)\b/.test(src) && /\.filter\(Boolean\)/.test(src)
    && !/\b(dropped|votesSent|votesReturned|needsAdjudication)\b/.test(src))
  warns.push('vote-tallying stage (winner/consensus/fatalCount) filters agent results but has no sent-vs-returned reconciliation (dropped/votesSent/needsAdjudication) — a dropped vote can silently flip the outcome (measured 2026-06-28)')

// A SCOREBOARD stage is the same rule at ERROR strength, scoped to the stage (measured 2026-09-05, ticket 14).
// Two reasons it is not the WARN above: a scoreboard ranks by a MEAN, so one invalid or dropped ballot
// reorders the board rather than adding noise; and the whole-file test is suppressed by a `dropped` token in
// ANY other stage, which is exactly how an unreconciled scoreboard linted clean.
//
// DETECTOR — every occurrence of the canonical marker line gets its own region (a script may run more than
// one scoreboard). With no marker at all, ONE fallback region is derived from the `board` binding: walk
// BACKWARDS from it to the nearest preceding `pipeline(` / `const judged` / `Promise.all(`, so an earlier
// stage's tokens stay outside. REGION END: the LAST `winner =` assignment (declared or bare) before the next
// stage marker/heading comment or EOF — not the first, or an early `let winner = null` collapses the region
// and a fully reconciled tally reads as unreconciled.
//
// TOKEN TEST — run on CODE ONLY (comments and string/template literal TEXT stripped; the expressions inside
// `${…}` are kept, they are code). A stage that merely mentions "dropped" in a comment or a log string has
// not reconciled anything. The regex is case-insensitive and unanchored so a script reconciling under its own
// identifier names (`judgesDropped`, `candidatesDropped`) counts — that is a real reconciliation in code.
//
// BLIND SPOTS — both are false NEGATIVES; neither can produce a false ERROR:
// (1) A hand-rolled scoreboard with neither the marker nor a `board` binding is not detected here, and it
//     reaches the whole-file WARN above ONLY if the file also uses `.filter(Boolean)` and one of
//     winner/consensus/fatalCount — otherwise nothing fires at all.
// (2) Ending the region at the LAST `winner =` (which is what stops an early `let winner = null` from
//     collapsing it) is paid for here. Exact shape that escapes: a MARKED, unreconciled scoreboard, followed
//     — with no stage banner comment between them — by a later block that both reassigns `winner` and uses a
//     reconciliation token IN CODE. The region then swallows that block and borrows its token. The catalog's
//     own stages all carry banners, so this is reachable only in a hand-rolled script; the honest cost of
//     fixing (1)'s sibling false positive. Widen the DETECTOR, never the region, if it shows up for real.
const SB_TOKENS = /(dropped|errored|votesSent|votesReturned|needsAdjudication)/i
const MARKER = /^[ \t]*\/\/ Tournament stage — scoreboard mode[ \t]*$/gm
// A stage banner in this catalog's convention: `// <Name> stage …` / `// <Name>-<x> stage …`. Deliberately
// narrow — a prose comment that merely contains the word "stage" (`// GATE: after editing this stage run …`)
// must NOT end a region, or the region collapses to nothing and a reconciled stage reads as unreconciled.
const NEXT_STAGE = /^[ \t]*\/\/ [A-Z][\w-]*(?: [\w-]+)? stage\b[^\n]*$/gm
const WINNER_ASSIGN = /(?:(?:const|let|var)\s+)?\bwinner\s*=[^=]/g
const HAS_WINNER = /(?:(?:const|let|var)\s+)?\bwinner\s*=[^=]/
const BOARD_BIND = /(?:(?:const|let|var)\s+)?\bboard\s*=[^=]/

// Strip comments and string/template literal TEXT, keeping the code (including `${…}` interiors). A lint
// heuristic, not a parser: it does not tell a regex literal from division, which cannot change this test.
function codeOnly(s) {
  let out = '', i = 0
  const stack = []
  while (i < s.length) {
    const top = stack[stack.length - 1]
    if (top && top.kind === 'tpl') {
      if (s[i] === '\\') { i += 2; continue }
      if (s[i] === '`') { stack.pop(); i++; continue }
      if (s[i] === '$' && s[i + 1] === '{') { stack.push({ kind: 'expr', depth: 0 }); i += 2; out += ' '; continue }
      if (s[i] === '\n') out += '\n'
      i++
      continue
    }
    const c = s[i], d = s[i + 1]
    if (c === '/' && d === '/') { while (i < s.length && s[i] !== '\n') i++; continue }
    if (c === '/' && d === '*') { i += 2; while (i < s.length && !(s[i] === '*' && s[i + 1] === '/')) i++; i = Math.min(i + 2, s.length); continue }
    if (c === "'" || c === '"') { const q = c; i++; while (i < s.length && s[i] !== q) { if (s[i] === '\\') i++; i++ } i++; out += ' '; continue }
    if (c === '`') { stack.push({ kind: 'tpl' }); i++; out += ' '; continue }
    if (top && top.kind === 'expr') {
      if (c === '{') top.depth++
      else if (c === '}') { if (top.depth === 0) { stack.pop(); i++; out += ' '; continue } top.depth-- }
    }
    out += c
    i++
  }
  return out
}

const idxAll = (re, s) => [...s.matchAll(re)].map(m => m.index)
const sbStarts = idxAll(MARKER, src)
if (!sbStarts.length) {
  const boardAt = src.search(BOARD_BIND)
  if (boardAt >= 0 && HAS_WINNER.test(src)) {
    const anchors = idxAll(/(?:const|let|var)\s+judged\s*=|\bpipeline\s*\(|\bPromise\.all\s*\(/g, src.slice(0, boardAt))
    if (anchors.length) sbStarts.push(anchors[anchors.length - 1]) // NEAREST preceding anchor, never the first in the file
  }
}
const stageBanners = idxAll(NEXT_STAGE, src)
for (const [n, start] of sbStarts.entries()) {
  // Boundary: the next scoreboard marker, or the next stage banner after this one, or EOF.
  const nextMarker = sbStarts[n + 1] ?? src.length
  const heading = stageBanners.find(i => i > start)
  const boundary = Math.min(nextMarker, heading ?? src.length)
  const span = src.slice(start, boundary)
  const was = idxAll(WINNER_ASSIGN, span)
  let region = span
  if (was.length) {
    const last = was[was.length - 1]
    const eol = span.indexOf('\n', last)
    region = span.slice(0, eol < 0 ? span.length : eol)
  }
  if (!SB_TOKENS.test(codeOnly(region))) {
    const line = src.slice(0, start).split('\n').length
    errors.push(`scoreboard tally starting line ${line} ranks candidates by a mean with no sent-vs-returned reconciliation in the stage — record dropped/errored/votesSent/votesReturned per candidate and set needsAdjudication (a reconciliation token in a comment, in a log string, or in another stage does NOT cover this stage)`)
  }
}

for (const w of warns) console.error('WARN: ' + w)
for (const e of errors) console.error('ERROR: ' + e)
process.exit(errors.length ? 1 : 0)
