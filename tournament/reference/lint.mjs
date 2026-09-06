#!/usr/bin/env node
// Dev tool (plain Node, runs OUTSIDE the Workflow runtime). Lints a generated
// tournament workflow script against the runtime's hard constraints.
import { readFileSync, readdirSync } from 'node:fs'
import { spawnSync } from 'node:child_process'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = dirname(fileURLToPath(import.meta.url))
const file = process.argv[2]
if (!file) { console.error('usage: lint.mjs <script.js> | lint.mjs --selftest'); process.exit(2) }

// --selftest: run this linter over every fixture in reference/fixtures/ and check the naming contract.
// FOUR name classes, because two were not enough to say what a fixture MEANS:
//   bad-*  must exit 1                     — a script this linter is supposed to catch.
//   good-* must exit 0 with no WARN        — a script this linter is supposed to pass.
//   warn-* must exit 0 WITH a WARN present — a script this linter is supposed to WARN about and not
//          reject. Without this class a WARN rule had no fixture that could red when it stopped firing,
//          which is how the whole-file `parallel()` null-guard test went unfirable on every script
//          assembled from this catalog and nothing noticed (measured 2026-09-05).
//   gap-*  must exit 0 with no WARN, and that is a RECORDED BLIND SPOT, not an endorsement — a script the
//          linter SHOULD catch and deliberately does not. Filing one under `good-` (the only option
//          before) printed it as a PASS and counted it among the greens, so the output claimed the
//          detector covered ground it does not. All four are counted apart in the VERDICT line.
// The fixtures ARE the linter's calibration (a rule nothing reds is a rule nobody has measured); before
// this they had no runner and drifted unnoticed. stderr is captured on BOTH paths: `WARN:` goes to
// stderr, so reading only stdout on a passing fixture made a WARN on a `good-`/`gap-` script invisible
// and the "no WARN" half of their contract unenforceable.
if (file === '--selftest') {
  const dir = join(HERE, 'fixtures')
  let names
  try { names = readdirSync(dir).filter(f => f.endsWith('.js')).sort() }
  catch (e) { console.error(`selftest: cannot read ${dir}: ${e.message}`); process.exit(2) }
  if (!names.length) { console.error(`selftest: no .js fixtures in ${dir}`); process.exit(2) }
  let fails = 0, bads = 0, goods = 0, gaps = 0, warnFixtures = 0
  for (const n of names) {
    const expectBad = n.startsWith('bad-')
    const isGap = n.startsWith('gap-')
    const expectWarn = n.startsWith('warn-')
    if (!expectBad && !isGap && !expectWarn && !n.startsWith('good-')) {
      console.log(`FAIL  ${n} — fixture name must start with bad-, good-, warn- or gap-`); fails++; continue
    }
    if (expectBad) bads++; else if (isGap) gaps++; else if (expectWarn) warnFixtures++; else goods++
    const r = spawnSync('node', [fileURLToPath(import.meta.url), join(dir, n)], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] })
    const out = (r.stdout || '') + (r.stderr || '')
    const code = r.status ?? 1
    const warned = /^WARN: /m.test(out)
    const ok = expectBad ? code === 1 : expectWarn ? code === 0 && warned : code === 0 && !warned
    if (!ok) fails++
    const contract = expectBad ? 'exit 1'
      : expectWarn ? 'exit 0, WARN present'
        : isGap ? 'exit 0, no WARN — a recorded blind spot, NOT a good script'
          : 'exit 0, no WARN'
    console.log(`${ok ? 'PASS' : 'FAIL'}  ${n} — exit ${code}${warned ? ', WARN present' : ', no WARN'} (expected ${contract})`)
  }
  console.log(fails ? `VERDICT: RED — ${fails} of ${names.length} lint fixture(s) off contract`
    : `VERDICT: GREEN (lint --selftest) — ${names.length} fixtures (${bads} bad, ${goods} good, ${warnFixtures} warn, ${gaps} known gaps)`)
  process.exit(fails ? 1 : 0)
}

const src = readFileSync(file, 'utf8')
const errors = [], warns = []

// SYNTAX GATE. `node --check` cannot validate a workflow script and never could (measured 2026-09-05):
// the script ends in a top-level `return`, which is illegal in script mode AND in module mode, so the
// only way it parses at all is as a function body — and because the file opens `export const meta = {`,
// Node detects module syntax and `--check` returned 0 even for a tail of `const OOPS = ((((`. Parse it
// the way the runtime does instead: drop the `export` keyword off the meta line (nothing else in a
// workflow script is exported) and COMPILE the whole body as an async function, where the trailing
// `return` and every `await` are legal. `new Function` compiles and never runs the body — the script is
// not executed here, and nothing in it is evaluated. A leading `#!` line is dropped first: Node strips a
// shebang before parsing a file, so keeping it here would report `Invalid or unexpected token` on a script
// `node --check` accepted (measured 2026-09-05). A workflow script has no reason to carry one; this only
// keeps the gate's blast radius where the gate's own evidence is.
const parseSrc = src.replace(/^#![^\n]*/, '').replace(/^([ \t]*)export[ \t]+const[ \t]+meta\b/m, '$1const meta')
try { new Function('async function __wf() {\n' + parseSrc + '\n}') }
catch (e) { errors.push('syntax error: ' + ((e && e.message) || String(e))) }

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

// `parallel()` results must be null-guarded, and the guard has to NAME the result it guards. The first
// two cuts were WHOLE-FILE — `.filter(Boolean)` anywhere, then `.filter(Boolean)` OR `if (!x` anywhere —
// and the second is unfirable on anything assembled from this catalog: the catalog ships nine `if (!ident`
// lines of its own, so every assembled script carried the escape hatch for free whether or not a single
// `parallel()` result was guarded (measured 2026-09-05). Keyed per BINDING instead. For every
// `const NAME = await parallel(`, one of these NAME-anchored shapes must appear in the CODE (comments and
// prompt text stripped by codeOnly, so a guard quoted in a prompt does not count):
//   * `NAME.filter(Boolean)` — the canonical form;
//   * `NAME.filter(v => v && …)` — the same test hand-rolled, the shape the bracket vote tally uses;
//   * `NAME[k] || …` / `NAME[k] ?? …` — a positional default, the shape the context stage uses;
//   * `NAME.length - …` — a sent-vs-returned count taken on the RAW array, the shape the skeptic panel
//     uses (`skepticResults.length - skeptics.length`);
//   * `NAME.forEach(` / `NAME.map(` / `for (… of NAME)` with an `if (!<ident>` inside the next 15 CODE
//     lines — the positional guard, and the correct shape wherever the null has to be attributed to its
//     sender: the filter stage buckets a whole dropped AXIS that way, and `parallel()` resolves
//     positionally precisely so that it can.
// RECORDED GAP (a false NEGATIVE, never a false ERROR): only a plain `const/let NAME = await parallel(`
// binding is checked. A destructuring bind (`const [qf1, qf2] = await parallel([…])`) and an
// immediately-consumed one (`const r = (await parallel(…)).filter(Boolean)`) are not — naming the guard
// needs a name, and neither shape has one. Both occur in this catalog, both already guarded.
const parallelCode = codeOnly(src)
const parallelLines = parallelCode.split('\n')
const reEsc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
function parallelGuarded(name) {
  const n = reEsc(name)
  if (new RegExp(`\\b${n}\\s*\\.filter\\(\\s*Boolean\\s*\\)`).test(parallelCode)) return true
  if (new RegExp(`\\b${n}\\s*\\.filter\\(\\s*\\(?\\s*(\\w+)[^)]*\\)?\\s*=>[^\\n]*(?:!\\s*\\1\\b|\\b\\1\\s*(?:&&|\\?|\\)))`).test(parallelCode)) return true
  if (new RegExp(`\\b${n}\\s*\\[[^\\]\\n]*\\]\\s*(?:\\|\\||\\?\\?)`).test(parallelCode)) return true
  if (new RegExp(`\\b${n}\\s*\\.length\\s*-|-\\s*${n}\\s*\\.length`).test(parallelCode)) return true
  const iter = new RegExp(`\\b${n}\\s*\\.(?:forEach|map)\\s*\\(|\\bfor\\s*\\([^)\\n]*\\bof\\s+${n}\\b`, 'g')
  for (const it of parallelCode.matchAll(iter)) {
    const from = parallelCode.slice(0, it.index).split('\n').length - 1
    const window = parallelLines.slice(from).filter(l => l.trim()).slice(0, 15).join('\n')
    if (/if\s*\(\s*!\s*[A-Za-z_$][\w$]*/.test(window)) return true
  }
  return false
}
const PARALLEL_BIND = /\b(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=\s*await\s+parallel\s*\(/g
for (const name of new Set([...parallelCode.matchAll(PARALLEL_BIND)].map(m => m[1])))
  if (!parallelGuarded(name)) warns.push(`parallel() result \`${name}\` has no null guard that names it — filter it (\`${name}.filter(Boolean)\`), default it positionally (\`${name}[k] || …\`), count it (\`${name}.length - …\`), or guard positionally (\`${name}.forEach((res, k) => { if (!res) … })\`) if the null has to be attributed to its sender`)

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
// ACCOUNTING TEST — run on CODE ONLY (comments and string/template literal TEXT stripped; the expressions
// inside `${…}` are kept, they are code). A stage that merely mentions "dropped" in a comment or a log
// string has not reconciled anything. It demands ACCOUNTING rather than a name, and it stays
// IDENTIFIER-AGNOSTIC while doing so — the property the filter rule below cannot have. Two parts:
//   (a) BARE-LITERAL STUB DECLARATIONS ARE DELETED FIRST. A single line was enough to clear the earlier
//       one-of-five-names test: inserting `const votesReturned = 0`, or `const needsAdjudication = false`
//       (the STANDALONE stub the catalog itself carries), into an unreconciled tally turned it clean
//       (measured 2026-09-05). A name that is only ever declared as a stub is not accounting.
//   (b) A CONJUNCTION, because either half alone is one line to fake: a per-candidate COUNTER (anything
//       ending `…Returned`) AND a FAULT bucket (`…Dropped` / `errored` / `needsAdjudication`). Both
//       halves are case-insensitive and unanchored, so a script reconciling under its own identifier
//       names (`judgesReturned` + `judgesDropped`, `candidatesDropped`) counts — that is a real
//       reconciliation in code, and it is what the recorded golden and the camelCase fixture actually do.
//
// BLIND SPOTS — both are false NEGATIVES; neither can produce a false ERROR:
// (1) A hand-rolled scoreboard with neither the marker nor a `board` binding is not detected here, and it
//     reaches the whole-file WARN above ONLY if the file also uses `.filter(Boolean)` and one of
//     winner/consensus/fatalCount — otherwise nothing fires at all.
// (2) Ending the region at the LAST `winner =` (which is what stops an early `let winner = null` from
//     collapsing it) is paid for here. Exact shape that escapes: a MARKED, unreconciled scoreboard, followed
//     — with no stage banner comment between them — by a later block that both reassigns `winner` and does
//     its own accounting IN CODE. The region then swallows that block and borrows its counter and its fault
//     bucket. `fixtures/gap-scoreboard-prose-then-winner.js` pins it. The window is slightly WIDER than it
//     was before the NEXT_STAGE narrowing below: a prose comment carrying the word "stage" used to end the
//     region and now does not, which is right for the filter rule and is a cost here. The catalog's own
//     stages all carry real banners, so this stays reachable only in a hand-rolled script. Widen the
//     DETECTOR, never the region, if it shows up for real.
const SB_STUB_DECL = /^[ \t]*(?:const|let|var)[ \t]+\w+[ \t]*=[ \t]*(?:true|false|null|undefined|0|\[[ \t]*\]|\{[ \t]*\})?[ \t]*;?[ \t]*$/gm
const SB_COUNTED = /[A-Za-z]*returned\b/i
const SB_FAULT = /[A-Za-z]*(?:dropped|errored)\b|needsAdjudication/i
const MARKER = /^[ \t]*\/\/ Tournament stage — scoreboard mode[ \t]*$/gm
// A stage banner in this catalog's convention, derived from the fences' actual first lines rather than
// from the shape of the phrase: `// Filter stage — bracket mode`, `// Generate stage`, `// QA stage
// (optional)`, `// Result shape — bracket mode`. So after the word "stage" the line must END or continue
// with an em-dash or an opening parenthesis. Deliberately narrow, and narrower than it first shipped: a
// PROSE comment that merely contains the word "stage" must NOT end a region, or the region collapses and
// a reconciled stage reads as unreconciled. The first cut only excluded `// GATE: after editing this
// stage run …`; it still matched `// The FILTER stage carries its own flag: …` — a line this very
// catalog ships — and one such line between a filter marker and its tally made the tally test `continue`
// and the whole filter rule vanish in silence (measured 2026-09-05). FOR THE FILTER RULE, a false NEGATIVE
// from a truncated region is strictly worse than the false positive this narrowness costs. That trade does
// NOT carry over to the scoreboard rule, and the sentence used to assert it for both: the scoreboard region
// runs to the LAST `winner =` inside the span, so a WIDER span borrows a later block's accounting instead
// of losing its own. Narrowing this grammar therefore bought the scoreboard blind spot (2) above a little
// more room, not a false positive — `fixtures/gap-scoreboard-prose-then-winner.js` is that cost, measured.
const NEXT_STAGE = /^[ \t]*\/\/ (?:[A-Z][\w-]*(?: [\w-]+)? stage(?:[ \t]*$|[ \t]*[—(])|Result shape[ \t]*[—(])/gm
const WINNER_ASSIGN = /(?:(?:const|let|var)\s+)?\bwinner\s*=[^=]/g
const HAS_WINNER = /(?:(?:const|let|var)\s+)?\bwinner\s*=[^=]/
const BOARD_BIND = /(?:(?:const|let|var)\s+)?\bboard\s*=[^=]/

// Strip comments and string/template literal TEXT, keeping the code (including `${…}` interiors). A lint
// heuristic, not a parser. It DOES blank simple regex literals: a `/…/` in an operand position (after
// `=`, `(`, `,`, `:` and friends) is treated as a literal and blanked, because otherwise `const prose =
// /axesSent/` counted as accounting and turned an unreconciled tally from ERROR to clean (measured
// 2026-09-05 — the earlier claim here that a regex "cannot change this test" was false). A `/` in any
// other position is division and is kept. KNOWN GAPS, both narrow and both recorded rather than fixed:
// a `/` inside a character class (`/[/]/`) ends the literal early — a false ERROR, not a false pass; and
// a regex after a KEYWORD rather than a punctuator (`return /axesSent/`) is read as division and left in
// place, so that one shape can still satisfy an accounting test. Neither occurs in this catalog. The
// second one is a COMPLETE bypass of the filter rule — two `if (false) return /…/` lines supply both
// halves of its conjunction at once — so it is fixtured rather than left in this comment alone:
// `fixtures/gap-filter-regex-after-keyword.js`, filed `gap-` so --selftest prints it as the blind spot it
// is. The character-class gap stays comment-only: a false ERROR is loud, and a fixture pinning it would
// pin a shape we would rather fix than keep.
function codeOnly(s) {
  let out = '', i = 0, prev = ''
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
    if (c === '/' && /[=(,:[!&|?{;+\-*%<>~^]/.test(prev)) { // operand position → regex literal, not division
      i++
      while (i < s.length && s[i] !== '/' && s[i] !== '\n') { if (s[i] === '\\') i++; i++ }
      i++
      while (i < s.length && /[a-z]/.test(s[i])) i++
      out += ' '; prev = ' '
      continue
    }
    if (c === "'" || c === '"') { const q = c; i++; while (i < s.length && s[i] !== q) { if (s[i] === '\\') i++; i++ } i++; out += ' '; prev = ' '; continue }
    if (c === '`') { stack.push({ kind: 'tpl' }); i++; out += ' '; prev = ' '; continue }
    if (top && top.kind === 'expr') {
      if (c === '{') top.depth++
      else if (c === '}') { if (top.depth === 0) { stack.pop(); i++; out += ' '; prev = ' '; continue } top.depth-- }
    }
    out += c
    if (!/\s/.test(c)) prev = c
    i++
  }
  return out
}

// The MIRROR of codeOnly, for the MARKER and BANNER searches: it blanks string and template TEXT to
// spaces while KEEPING comments and preserving every byte offset and newline, so a match index in the
// blanked source is the same index in the real source. Markers and banners are comments, and the only
// place a comment-looking line can appear that is NOT a comment is inside a prompt string — a template
// containing `// Filter stage — bracket mode` as example text was opening a filter region over a script
// with no filter stage, and a `// Tournament stage …` line inside a real filter's prompt was truncating
// that region before its reconciliation (measured 2026-09-05). Searching the blanked source fixes both
// directions at once and leaves the marker-only detector exactly as narrow as it was.
function blankStrings(s) {
  const out = s.split('')
  const blank = (k) => { if (k < out.length && out[k] !== '\n') out[k] = ' ' }
  let i = 0
  const stack = []
  while (i < s.length) {
    const top = stack[stack.length - 1]
    if (top && top.kind === 'tpl') {
      if (s[i] === '\\') { blank(i); blank(i + 1); i += 2; continue }
      if (s[i] === '`') { stack.pop(); blank(i); i++; continue }
      if (s[i] === '$' && s[i + 1] === '{') { stack.push({ kind: 'expr', depth: 0 }); i += 2; continue }
      blank(i); i++
      continue
    }
    const c = s[i], d = s[i + 1]
    if (c === '/' && d === '/') { while (i < s.length && s[i] !== '\n') i++; continue } // comments KEPT
    if (c === '/' && d === '*') { i += 2; while (i < s.length && !(s[i] === '*' && s[i + 1] === '/')) i++; i = Math.min(i + 2, s.length); continue }
    if (c === "'" || c === '"') {
      const q = c
      blank(i); i++
      while (i < s.length && s[i] !== q) { if (s[i] === '\\') { blank(i); i++ } blank(i); i++ }
      blank(i); i++
      continue
    }
    if (c === '`') { stack.push({ kind: 'tpl' }); blank(i); i++; continue }
    if (top && top.kind === 'expr') {
      if (c === '{') top.depth++
      else if (c === '}') { if (top.depth === 0) { stack.pop(); i++; continue } top.depth-- }
    }
    i++
  }
  return out.join('')
}

const idxAll = (re, s) => [...s.matchAll(re)].map(m => m.index)
// Marker and banner searches run on the string-blanked source; every index is still an index into `src`.
const commentSrc = blankStrings(src)
const sbStarts = idxAll(MARKER, commentSrc)
if (!sbStarts.length) {
  const boardAt = src.search(BOARD_BIND)
  if (boardAt >= 0 && HAS_WINNER.test(src)) {
    const anchors = idxAll(/(?:const|let|var)\s+judged\s*=|\bpipeline\s*\(|\bPromise\.all\s*\(/g, src.slice(0, boardAt))
    if (anchors.length) sbStarts.push(anchors[anchors.length - 1]) // NEAREST preceding anchor, never the first in the file
  }
}
const stageBanners = idxAll(NEXT_STAGE, commentSrc)
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
  const regionCode = codeOnly(region).replace(SB_STUB_DECL, '')
  if (!(SB_COUNTED.test(regionCode) && SB_FAULT.test(regionCode))) {
    const line = src.slice(0, start).split('\n').length
    errors.push(`scoreboard tally starting line ${line} ranks candidates by a mean with no sent-vs-returned reconciliation in the stage — record a returned COUNT (votesReturned/judgesReturned) AND a fault bucket (dropped/errored) per candidate and set needsAdjudication from them (a reconciliation token in a comment, in a log string, in another stage, or a bare \`const votesReturned = 0\` / \`const needsAdjudication = false\` declaration, does NOT cover this stage)`)
  }
}

// A FILTER stage is the same rule again, one stage EARLIER (measured 2026-09-05, ticket 15). The filter
// ranks by a SUM of per-axis screener scores, and that ranking IS the bracket seeding and the shortlist —
// so a lost axis, a duplicate index or an out-of-scale score reorders everything downstream rather than
// adding noise. Measured on the pre-fix catalog stage: one axis returning nothing moved a candidate from
// rank 1 to rank 4, a duplicate index double-counted, and a single score of 1000 took the top.
//
// DETECTOR — MARKER ONLY, unlike the scoreboard rule's `board`-binding derivation. What actually forces
// that, stated precisely, because the earlier wording here over-claimed it: a private golden
// (`the private repo's tournament/reference/golden/incremental-concept-tournament.js`) IS an unmarked,
// unreconciled filter tally of exactly this shape, and the golden clause pins its ERROR count, its WARN
// count and its exit code. So the clause forbids a fallback that reports at ERROR or at WARN strength —
// those move a pinned number — and it forbids nothing else. A report at a THIRD severity moves none of
// the three (the exit code is already 1 from the existing ERRORs); that option is AVAILABLE AND
// UNEXPLORED, not foreclosed. What the golden really is here is the RECORDED BLIND SPOT: the one shape
// in the corpus this rule knowingly misses, and the reason to widen the detector deliberately rather than
// by accident. Re-minting the golden to fit a linter rule is what would destroy the only recorded
// calibration this linter has; the counts themselves live in that private repo's ticket record, not here,
// because a figure repeated in a comment nothing can check is a figure that drifts. Control for the
// documented gap: the same tally WITH the marker added — `fixtures/bad-filter-unreconciled.js` reds while
// `fixtures/gap-filter-unmarked-golden-shape.js`, the unmarked twin, stays green (and is filed under
// `gap-`, not `good-`, so --selftest reports it as the blind spot it is).
//
// REGION — marker to the next stage banner (NEXT_STAGE already matches `// Filter stage …`) or EOF, both
// located in the STRING-BLANKED source so a banner quoted inside a prompt template neither opens a region
// nor truncates one. No `winner =`-style narrowing: a filter stage has no such landmark, and the banner
// boundary is what stops a LATER scoreboard's `dropped` from covering this stage, which is exactly how an
// unreconciled filter tally linted clean.
//
// TALLY TEST — the rule only fires where there IS a sum to reconcile (`totals` plus a `.set(` or a `+=`
// in the region's CODE); a marked filter block that only dedups has nothing to reconcile. That `continue`
// is why NEXT_STAGE had to be narrowed: a truncated region fails the tally test and the rule then says
// nothing at all.
//
// ACCOUNTING TEST — code only (the codeOnly() stripper, which blanks regex literals too), and it demands
// ACCOUNTING rather than a NAME: `axesReturned` must appear, AND `filterNeedsAdjudication` (or a suffixed
// variant like `filterNeedsAdjudicationSB`) must be assigned something other than a bare `true`/`false`.
// Requiring one of four names was satisfiable by a single line — `const filterNeedsAdjudication = false`,
// the STANDALONE stub the catalog itself carries — which turned a marked, unreconciled tally clean
// (measured 2026-09-05). Either half alone is one line to fake — `const votesReturned = 0` was measured
// doing exactly that to the scoreboard rule the same day — so the pair is what has to be checked.
//
// AND IT IS NAME-KEYED, where the scoreboard rule twenty lines up is identifier-agnostic. That asymmetry
// is deliberate, not an oversight: an accounting test needs a NAME to anchor on, the scoreboard rule can
// key on a suffix (`…Returned` + `…Dropped`) because its accounting has two independent halves to require,
// and this rule's second half is a single FLAG whose suffix (`…NeedsAdjudication`) is too generic to match
// safely. The cost is a false POSITIVE on a fully reconciled filter stage written under other names
// (`screeningDoubt`, `axesBack` — measured, it ERRORs). The reason that is acceptable and not silent: the
// rule is MARKER-keyed, so it only fires on a script that already copied this catalog's banner verbatim,
// which means it copied the catalog's binding names too — and the failure mode is a loud ERROR naming the
// line, not a miss. If a script legitimately renames them, rename them here in the same edit.
//
// The banner is matched by PREFIX, not to end-of-line: the catalog's scoreboard-mode filter marker carries
// a trailing parenthetical (`… scoreboard mode (dedup + screening identical to bracket mode)`), so an
// end-anchored marker like the scoreboard rule's would match neither the catalog nor a script built from it.
const FILTER_MARKER = /^[ \t]*\/\/ Filter stage — (?:bracket|scoreboard) mode\b[^\n]*$/gm
const FLAG_ASSIGN = /\bfilterNeedsAdjudication\w*\s*=\s*([^\n;]+)/gi
for (const start of idxAll(FILTER_MARKER, commentSrc)) {
  const heading = stageBanners.find(i => i > start)
  const region = codeOnly(src.slice(start, heading ?? src.length))
  if (!(/totals/i.test(region) && /(\.set\s*\(|\+=)/.test(region))) continue // nothing is summed here
  const counted = /axesReturned/i.test(region)
  const flagged = [...region.matchAll(FLAG_ASSIGN)].some(m => !/^(?:true|false)$/i.test(m[1].trim()))
  if (!(counted && flagged)) {
    const line = src.slice(0, start).split('\n').length
    errors.push(`filter stage starting line ${line} sums per-axis screener scores into a ranking with no axes-sent-vs-returned reconciliation in the stage — record axesSent/axesReturned/dropped/errored per kept candidate AND compute filterNeedsAdjudication from them (a reconciliation token in a comment, in a log string, in a regex, in another stage, or a bare \`filterNeedsAdjudication = false\` declaration, does NOT cover this stage)`)
  }
}

for (const w of warns) console.error('WARN: ' + w)
for (const e of errors) console.error('ERROR: ' + e)
process.exit(errors.length ? 1 : 0)
