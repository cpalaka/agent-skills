export const meta = {
  name: 'implement-run',
  description: 'implement-run workflow shape: implementer, the review calls the profile turns on, at most one fix round, the certifying gate after the review\'s fixes',
  phases: [
    { title: 'Implement', detail: 'the implementer seat, committing on the checked-out branch' },
    { title: 'Review', detail: 'the review calls the profile turns on: Spec always, Standards where on, the Correctness charter where bug hunter is correctness' },
    { title: 'Fix', detail: 'at most one round: the implementer on the hard findings, or, where there were none, on a red gate, then the gate again' },
    { title: 'Gate', detail: 'the gate-runner seat, certifying round, after the review\'s fixes land' },
  ],
}

// A launch can deliver args as a JSON string (multi-agent-policy WORKFLOWS.md).
let a = args
if (typeof a === 'string') {
  try { a = JSON.parse(a) } catch (e) { throw new Error(`args is a string that is not JSON: ${e.message}`) }
}
if (!a || typeof a !== 'object') throw new Error('args missing: pass {ticket, checkout, fixedPoint, specPath, gateTier, profile, gateRunner?}')
// A caller passing a retired shape fails loudly rather than running on half its intent.
const FIELDS = ['ticket', 'checkout', 'fixedPoint', 'specPath', 'gateTier', 'profile', 'gateRunner']
for (const k of Object.keys(a)) {
  if (!FIELDS.includes(k)) throw new Error(`args.${k} is not a field this script reads (if the Workflow runtime itself added it, the field list here needs it)`)
}
for (const k of ['ticket', 'checkout', 'fixedPoint', 'specPath', 'gateTier', 'profile']) {
  if (a[k] === undefined || a[k] === null || a[k] === '') throw new Error(`args.${k} missing — nothing is dispatched on a starved input`)
}
const { ticket, checkout, fixedPoint, specPath } = a
const gateTier = typeof a.gateTier === 'string' ? a.gateTier : JSON.stringify(a.gateTier)
const gateRunner = a.gateRunner === undefined || a.gateRunner === null || a.gateRunner === '' ? 'gate-runner' : a.gateRunner
if (gateRunner === 'coordinator') {
  throw new Error('gate_runner is coordinator: a script cannot hand a gate back to the coordinator mid-run, so this project runs the subagents shape')
}

// Profile: keyed by the Skill's dial tokens, verbatim. Dials the script does not fill (advisor,
// critic, ...) are the coordinator's and pass unread; so does `gate tier`, since the gate is
// briefed from args.gateTier, the same tier spelled out.
let p = a.profile
if (typeof p === 'string') {
  try { p = JSON.parse(p) } catch (e) { throw new Error(`args.profile is a string that is not JSON: ${e.message}`) }
}
if (!p || typeof p !== 'object' || Array.isArray(p)) throw new Error('args.profile must be an object keyed by the dial tokens')
const RANGE = { 'standards': ['on', 'off'], 'bug hunter': ['off', 'correctness', 'codex'] }
for (const [dial, range] of Object.entries(RANGE)) {
  if (!range.includes(p[dial])) throw new Error(`args.profile["${dial}"] is ${JSON.stringify(p[dial])}: allowed ${range.join(' | ')}`)
}
if (!p.effort || typeof p.effort !== 'object' || Array.isArray(p.effort)) {
  throw new Error('args.profile.effort missing or not an object: it maps each seat token to a definition name')
}

// Each definition name → the effort its frontmatter carries. A stage's agentType and its effort
// option are both read from the one profile value, so the two carriers can never disagree.
const IMPLEMENTERS = { 'implementer': 'high', 'implementer-medium': 'medium' }
const REVIEWERS = { 'code-reviewer': 'high', 'code-reviewer-medium': 'medium', 'code-reviewer-xhigh': 'xhigh' }
const FAMILY = { 'implementer': IMPLEMENTERS, 'spec': REVIEWERS, 'standards': REVIEWERS, 'bug hunter': REVIEWERS }
const used = ['implementer', 'spec']
if (p.standards === 'on') used.push('standards')
if (p['bug hunter'] === 'correctness') used.push('bug hunter')
const seat = {}
for (const s of used) {
  const name = p.effort[s], family = FAMILY[s]
  if (!Object.keys(family).includes(name)) {
    throw new Error(`args.profile.effort["${s}"] is ${JSON.stringify(name)}: the ${s} seat takes ${Object.keys(family).join(' | ')}`)
  }
  seat[s] = { agentType: name, effort: family[name] }
}
// medium is the gate-runner's only value (the Skill's § Seats).
const GATE_SEAT = { agentType: gateRunner, effort: 'medium' }

const dropped = []
// agent() returns null on a skip or a terminal error and can throw (a usage limit is the
// likely cause); either way the call is dropped, so the script always returns a full shape.
async function call(label, phaseTitle, dispatch, prompt, schema) {
  let r = null, why = 'returned null'
  try { r = await agent(prompt, { label, phase: phaseTitle, agentType: dispatch.agentType, effort: dispatch.effort, schema }) } catch (e) { why = `threw: ${e && e.message}` }
  if (r === null || r === undefined) { dropped.push(label); log(`${label} dropped: ${why}`); return null }
  return r
}

const IMPL_SCHEMA = {
  type: 'object',
  properties: {
    report: { type: 'string', description: 'your whole handoff report' },
    commits: { type: 'array', items: { type: 'string' }, description: 'short SHA and subject of each commit you made, oldest first; empty if you stopped without committing' },
    porcelain: { type: 'string', description: 'git status --porcelain --untracked-files=all verbatim, run after your last commit' },
  },
  required: ['report', 'commits', 'porcelain'],
}
const GATE_SCHEMA = {
  type: 'object',
  properties: {
    gates: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          kind: { type: 'string', enum: ['gate', 'tier', 'judgment'] },
          verdict: { type: 'string', enum: ['PASS', 'FAIL', 'NOT RUN'] },
          log: { type: 'string' },
        },
        required: ['name', 'kind', 'verdict', 'log'],
      },
    },
    overall: { type: 'string' },
    report: { type: 'string' },
    porcelain: { type: 'string' },
    outputs: { type: 'array', items: { type: 'string' }, description: 'each path your ## Commands names as added by a gate, repository-relative: a file, or an outermost directory' },
  },
  required: ['gates', 'overall', 'report', 'porcelain', 'outputs'],
}
const REVIEW_SCHEMA = {
  type: 'object',
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          file: { type: 'string' },
          line: { type: ['integer', 'null'] },
          summary: { type: 'string' },
          hard: { type: 'boolean' },
        },
        required: ['file', 'line', 'summary', 'hard'],
      },
    },
  },
  required: ['findings'],
}

const RULES = `Constraints, each with its reason:
- Work only in the checkout ${checkout}, and run every git command as \`git -C ${checkout} ...\`: your shell starts in the launching session's root, which need not be this checkout.
- Never switch branches: the run's branch is the one checked out.
- Commit all your work on the checked-out branch before you return: the coordinator's Codex lens reviews \`--base ${fixedPoint}\`, which sees commits only, so uncommitted work is invisible to it.
- Never push, never merge, never write the tracker: the coordinator owns all three.
- Never ask a question: no human turn reaches an agent inside a workflow. Where the spec is ambiguous or contradicts the source, take the smallest defensible reading and surface it in your report.
- After your last commit, run \`git -C ${checkout} status --porcelain --untracked-files=all\` and return its output verbatim as \`porcelain\`.`

function gatePrompt(afterFix) {
  return `Run the verify gate in the checkout ${checkout}, from its root.
Gate tier for this ticket (the profile's \`gate tier\`, spelled out by the coordinator): ${gateTier}
This is a certifying round${afterFix ? ', following a fix round' : ''}. The run's fixed point is ${fixedPoint}; the diff under test is \`git -C ${checkout} diff ${fixedPoint}...HEAD\`.

Return your report through the schema:
- \`report\`: your whole text report, verbatim, every part of it (CONTROL lines, Matches, Inspections, Commands, OVERALL, and the OWNED ELSEWHERE, DECLARED ABSENT, UNCLASSIFIED KEY and OUTSTANDING JUDGMENT lines below it): they have no other home.
- \`overall\`: the value on your OVERALL line.
- \`gates\`: one entry per GATE line, in order. \`kind\` is \`gate\` for a plain \`GATE <name>:\` line, \`judgment\` for a \`GATE <name> (judgment):\` line, \`tier\` for a \`GATE <name> (tier):\` line; \`log\` is the log file or directory that line names.
- \`porcelain\`: after your gates, run \`git -C ${checkout} status --porcelain --untracked-files=all\` (read-only) and return its output verbatim. This is the script's requirement beside your report shape, not a gate: it gets no GATE line and does not move OVERALL.
- \`outputs\`: every path your \`## Commands\` names as a line the second status capture adds — each file, or each outermost directory where you named one — repository-relative, without a status prefix. Empty where no gate wrote anything. The script subtracts the untracked files your \`porcelain\` lists under these, so a gate's own output never reads as uncommitted work.`
}

function reviewPrompt(axis) {
  const scope = `Checkout: ${checkout}. Diff: \`git -C ${checkout} diff ${fixedPoint}...HEAD\`.
Ticket: ${ticket} (read it; never write the tracker). Execution spec: ${specPath}.`
  // Its own hard rule: the axes' rule keys on a criterion violated on the page, which a runtime
  // defect rarely shows, so under it this call would never reach the fix round it exists to feed.
  if (axis === 'Correctness') return `Correctness charter — for each defect in the diff: what can go wrong, why the path is vulnerable, the likely impact, and one clause of remedy (a finding proves the defect, not the remedy). Material findings only: each one is adjudicated against source.
${scope}

Return every finding through the schema: \`file\`, \`line\` (an integer, or null where no line applies), \`summary\` (what can go wrong, why the path is vulnerable, the likely impact, one clause of remedy), and \`hard\`. \`hard\` is true where the defect, when the code runs, would make the diff fail an acceptance criterion or a hard limit of the execution spec, or would lose or corrupt state or data; everything else is false. The array's length is your \`FINDINGS: n\` count. No findings: an empty array.`
  const charter = axis === 'Standards'
    ? 'Standards: does the diff follow the coding standards this repository documents?'
    : 'Spec: does the diff meet the ticket\'s acceptance criteria and the execution spec?'
  return `Review axis — ${charter}
${scope}

Return every finding through the schema: \`file\`, \`line\` (an integer, or null where no line applies), \`summary\` (the quoted hunk and the rule or spec line it violates), and \`hard\`. \`hard\` is true only where the finding shows the diff violating an acceptance criterion, a hard limit of the execution spec, or a standard the repository states as a must; everything else is false. No findings: an empty array.`
}

phase('Implement')
const impl = await call('implementer', 'Implement', seat.implementer, `Implement ticket ${ticket} in the checkout ${checkout}, following the execution spec at ${specPath}.

${RULES}

Report through the schema: \`report\` is your handoff report, \`commits\` your commits, \`porcelain\` as above.`, IMPL_SCHEMA)

const result = {
  gates: [],
  findings: [],
  implementerReport: impl,
  fixRound: { ran: false, gatesAfter: [], implementerReport: null },
  dropped,
  gateReports: [],
}

if (!impl || !impl.commits || impl.commits.length === 0) {
  log(impl ? 'implementer made no commits (it stopped): nothing to gate or review' : 'implementer dropped: nothing to gate or review')
  return result
}
// A gate reads the live tree while the axes and the Codex lens read only the committed range,
// so a gate over uncommitted bytes certifies what nobody reviewed and the squash may not carry.
if (impl.porcelain && impl.porcelain.trim()) {
  log(`implementer left the tree dirty: nothing to gate or review. porcelain: ${impl.porcelain.trim()}`)
  return result
}

// A gate's own output is an untracked path its own porcelain lists, under a path its report names
// (a file, or a directory it wrote into): only those exact paths are subtracted, never a named
// directory as a whole, since a gate may name `src` for a cache and a seat's forgotten `src/x.py`
// must still read dirty. Every gate follows a tree its seat reported clean, so what its porcelain
// adds is taken as its own; a stale seat report is outside what the script can read. Porcelain is read with --untracked-files=all, one line per file. A quoted path with escapes
// never matches and stays in: a false dirty reading costs a run, a false clean one certifies what
// nobody committed. The Skill's § At return subtracts the same set.
const gateOwned = new Set()
const untracked = porcelain => (porcelain || '').split('\n')
  .filter(l => l.startsWith('?? ')).map(l => l.slice(3).replace(/^"(.*)"$/, '$1'))
function owned(g) {
  const named = (g.outputs || []).map(o => o.replace(/^\.\//, '').replace(/\/+$/, '')).filter(Boolean)
  return untracked(g.porcelain).filter(path => named.some(o => path === o || path.startsWith(o + '/')))
}
function uncommitted(porcelain) {
  return (porcelain || '').split('\n').filter(l => l.trim()).filter(l =>
    !(l.startsWith('?? ') && gateOwned.has(l.slice(3).replace(/^"(.*)"$/, '$1')))).join('\n')
}

async function gateRound(label, phaseTitle, afterFix) {
  const g = await call(label, phaseTitle, GATE_SEAT, gatePrompt(afterFix), GATE_SCHEMA)
  const mine = g ? owned(g) : []
  mine.forEach(path => gateOwned.add(path))
  result.gateReports.push(g
    ? { label, overall: g.overall, report: g.report, porcelain: g.porcelain, outputs: mine }
    : { label, overall: null, report: null, porcelain: null, outputs: [] })
  return g
}

// The gate runs after the review's fixes land, as under subagents (the Skill's § Review): a fix
// invalidates a gate round that ran before it. A red gate raises no review here — the Correctness
// call has already returned, and the critic, which the ratchet raises, is the coordinator's.
phase('Review')
const reviewCalls = [
  ...(seat.standards ? [['Standards', seat.standards]] : []),
  ['Spec', seat.spec],
  ...(seat['bug hunter'] ? [['Correctness', seat['bug hunter']]] : []),
]
// The Codex lens reads commits, and this script's fix round precedes it.
if (p['bug hunter'] === 'codex') log('bug hunter is codex: the Codex lens is the coordinator\'s after return, not a stage here')
const reviews = await parallel(reviewCalls.map(([axis, s]) => () =>
  call(`review:${axis.toLowerCase()}`, 'Review', s, reviewPrompt(axis), REVIEW_SCHEMA)))
reviewCalls.forEach(([axis], i) => {
  const r = reviews[i]
  if (r && r.findings) result.findings.push(...r.findings.map(f => ({ ...f, axis })))
})

// One fix round at most, on the hard findings or, where there were none, on a red gate; either
// way a gate follows it. The coordinator's critic reviews its commits after return. True when the
// tree is ready to gate.
async function fixRound(items, outputs) {
  phase('Fix')
  result.fixRound.ran = true
  const leave = outputs.length
    ? `\n\nThese untracked paths are a gate's own output, not your work: leave them uncommitted and in place, since a committed build output ships in the squash:\n${outputs.map(o => `- ${o}`).join('\n')}`
    : ''
  result.fixRound.implementerReport = await call('fix:implementer', 'Fix', seat.implementer, `Fix round for ticket ${ticket} in the checkout ${checkout}; execution spec at ${specPath}.

These items (hard review findings, or where there were none, gate failures) are UNADJUDICATED — nobody has checked them against source:
${items}

Verify each against source first. Fix what source confirms; refuse what source refutes and report the refutation with its evidence. One round only: no review runs inside this script after it; the coordinator's critic reviews these commits after return.${leave}

${RULES}

Report through the schema: \`report\` covers every item above (fixed or refused, and why), \`commits\` your commits this round, \`porcelain\` as above.`, IMPL_SCHEMA)
  const fix = result.fixRound.implementerReport
  const dirty = fix && uncommitted(fix.porcelain)
  if (!fix) {
    log('fix:implementer dropped: fix:gate skipped')
    return false
  }
  if (dirty) {
    log(`fix:implementer left the tree dirty: fix:gate skipped. porcelain, less a gate's own output: ${dirty}`)
    return false
  }
  return true
}

const hard = result.findings.filter(f => f.hard)
if (hard.length) {
  // No gate has run yet, so no gate output is subtracted from the fix seat's porcelain.
  if (await fixRound(hard.map(f => `- [${f.axis}] ${f.file}${f.line === null ? '' : `:${f.line}`} — ${f.summary}`).join('\n'), [])) {
    phase('Gate')
    const after = await gateRound('fix:gate', 'Gate', true)
    result.fixRound.gatesAfter = after ? after.gates : []
  }
} else {
  phase('Gate')
  const gate = await gateRound('gate', 'Gate', false)
  result.gates = gate ? gate.gates : []
  const failed = result.gates.filter(g => g.verdict === 'FAIL')
  // NOT RUN alone never triggers a fix: it is usually a person's step.
  if (failed.length && await fixRound(failed.map(g => `- GATE ${g.name}: FAIL — log: ${g.log}`).join('\n'), [...gateOwned])) {
    const after = await gateRound('fix:gate', 'Fix', true)
    result.fixRound.gatesAfter = after ? after.gates : []
  }
}

const last = result.gateReports[result.gateReports.length - 1]
const lastDirty = last && uncommitted(last.porcelain)
if (lastDirty) {
  log(`WARNING: tree not clean at the last gate round (${last.label}), less a gate's own output: ${lastDirty}`)
}

return result
