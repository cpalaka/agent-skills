#!/usr/bin/env node
// Dev tool (plain Node, runs OUTSIDE the Workflow runtime). Lints a generated
// tournament workflow script against the runtime's hard constraints.
import { readFileSync } from 'node:fs'
import { execFileSync } from 'node:child_process'

const file = process.argv[2]
if (!file) { console.error('usage: lint.mjs <script.js>'); process.exit(2) }
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
// DETECTOR: the canonical marker line, else the first `const judged`/`pipeline(` in a script that also binds
// `board` and assigns `winner`. REGION: that start → the end of the first later `winner` assignment.
// BLIND SPOT: a hand-rolled scoreboard with neither the marker nor a `board` binding is not detected here and
// falls through to the whole-file WARN above. Widen the detector rather than the region if that shows up.
// The token test deliberately carries NO leading \b, so a script that reconciles under its own names
// (`judgesDropped`, `candidatesDropped`) counts as reconciled.
const SB_TOKENS = /(dropped|errored|votesSent|votesReturned|needsAdjudication)/
const marker = src.match(/^[ \t]*\/\/ Tournament stage — scoreboard mode[ \t]*$/m)
let sbStart = marker ? marker.index : -1
if (sbStart < 0 && /\bboard\b/.test(src) && /(?:const|let|var)\s+winner\s*=/.test(src)) {
  const fallback = src.match(/(?:const|let|var)\s+judged\s*=|\bpipeline\s*\(/)
  if (fallback) sbStart = fallback.index
}
if (sbStart >= 0) {
  const rest = src.slice(sbStart)
  const wa = rest.search(/(?:const|let|var)\s+winner\s*=/)
  const eol = wa >= 0 ? rest.indexOf('\n', wa) : -1
  const region = wa < 0 ? rest : rest.slice(0, eol < 0 ? rest.length : eol)
  if (!SB_TOKENS.test(region)) {
    const line = src.slice(0, sbStart).split('\n').length
    errors.push(`scoreboard tally starting line ${line} ranks candidates by a mean with no sent-vs-returned reconciliation in the stage — record dropped/errored/votesSent/votesReturned per candidate and set needsAdjudication (a reconciliation token elsewhere in the script does NOT cover this stage)`)
  }
}

for (const w of warns) console.error('WARN: ' + w)
for (const e of errors) console.error('ERROR: ' + e)
process.exit(errors.length ? 1 : 0)
