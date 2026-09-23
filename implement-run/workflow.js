export const meta = {
  name: 'implement-run',
  description: 'implement-run workflow shape: implementer, certifying gate, the roster\'s review axes, at most one fix round',
  phases: [
    { title: 'Implement', detail: 'the implementer seat, committing on the checked-out branch' },
    { title: 'Gate', detail: 'the gate-runner seat, certifying round' },
    { title: 'Review', detail: 'the review axes the roster names' },
    { title: 'Fix', detail: 'at most one round: implementer, then the gate again' },
  ],
}

// A launch can deliver args as a JSON string (multi-agent-policy WORKFLOWS.md).
let a = args
if (typeof a === 'string') {
  try { a = JSON.parse(a) } catch (e) { throw new Error(`args is a string that is not JSON: ${e.message}`) }
}
if (!a || typeof a !== 'object') throw new Error('args missing: pass {ticket, checkout, fixedPoint, specPath, gateTier, roster, gateRunner?}')
for (const k of ['ticket', 'checkout', 'fixedPoint', 'specPath', 'gateTier', 'roster']) {
  if (a[k] === undefined || a[k] === null || a[k] === '') throw new Error(`args.${k} missing — nothing is dispatched on a starved input`)
}
if (!Array.isArray(a.roster)) throw new Error('args.roster must be an array of plan-stop roster entries')
const { ticket, checkout, fixedPoint, specPath } = a
const gateTier = typeof a.gateTier === 'string' ? a.gateTier : JSON.stringify(a.gateTier)
const gateRunner = a.gateRunner === undefined || a.gateRunner === null || a.gateRunner === '' ? 'gate-runner' : a.gateRunner
if (gateRunner === 'coordinator') {
  throw new Error('gate_runner is coordinator: a script cannot hand a gate back to the coordinator mid-run, so this project runs the subagents shape')
}

// Roster: the plan-stop line after strikes. Only these four are the script's seats.
const OURS = { 'implementer': 'implementer', 'gate-runner': 'gate', 'reviewer(standards)': 'Standards', 'reviewer(spec)': 'Spec' }
const seats = new Set()
for (const entry of a.roster) {
  const key = String(entry).toLowerCase().replace(/\s+/g, '')
  if (OURS[key]) seats.add(OURS[key])
  else log(`roster entry "${entry}" is the coordinator's, not the script's: skipped`)
}
if (!seats.has('implementer')) throw new Error('roster names no implementer')
if (!seats.has('gate')) throw new Error('roster names no gate-runner')
const axes = ['Standards', 'Spec'].filter(x => seats.has(x))

const dropped = []
// agent() returns null on a skip or a terminal error and can throw (a usage limit is the
// likely cause); either way the call is dropped, so the script always returns a full shape.
async function call(label, phaseTitle, agentType, prompt, schema) {
  let r = null, why = 'returned null'
  try { r = await agent(prompt, { label, phase: phaseTitle, agentType, schema }) } catch (e) { why = `threw: ${e && e.message}` }
  if (r === null || r === undefined) { dropped.push(label); log(`${label} dropped: ${why}`); return null }
  return r
}

const IMPL_SCHEMA = {
  type: 'object',
  properties: {
    report: { type: 'string', description: 'your whole handoff report' },
    commits: { type: 'array', items: { type: 'string' }, description: 'short SHA and subject of each commit you made, oldest first; empty if you stopped without committing' },
    porcelain: { type: 'string', description: 'git status --porcelain verbatim, run after your last commit' },
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
  },
  required: ['gates', 'overall', 'report', 'porcelain'],
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
- After your last commit, run \`git -C ${checkout} status --porcelain\` and return its output verbatim as \`porcelain\`.`

function gatePrompt(afterFix) {
  return `Run the verify gate in the checkout ${checkout}, from its root.
Gate tier for this ticket (the project's own field, verbatim): ${gateTier}
This is a certifying round${afterFix ? ', following a fix round' : ''}. The run's fixed point is ${fixedPoint}; the diff under test is \`git -C ${checkout} diff ${fixedPoint}...HEAD\`.

Return your report through the schema:
- \`report\`: your whole text report, verbatim, every part of it (CONTROL lines, Matches, Inspections, Commands, OVERALL, OUTSTANDING JUDGMENT): they have no other home.
- \`overall\`: the value on your OVERALL line.
- \`gates\`: one entry per GATE line, in order. \`kind\` is \`gate\` for a plain \`GATE <name>:\` line, \`judgment\` for a \`GATE <name> (judgment):\` line, \`tier\` for a \`GATE <name> (tier):\` line; \`log\` is the log file or directory that line names.
- \`porcelain\`: after your gates, run \`git -C ${checkout} status --porcelain\` (read-only) and return its output verbatim. This is the script's requirement beside your report shape, not a gate: it gets no GATE line and does not move OVERALL.`
}

function reviewPrompt(axis) {
  const charter = axis === 'Standards'
    ? 'Standards: does the diff follow the coding standards this repository documents?'
    : 'Spec: does the diff meet the ticket\'s acceptance criteria and the execution spec?'
  return `Review axis — ${charter}
Checkout: ${checkout}. Diff: \`git -C ${checkout} diff ${fixedPoint}...HEAD\`.
Ticket: ${ticket} (read it; never write the tracker). Execution spec: ${specPath}.

Return every finding through the schema: \`file\`, \`line\` (an integer, or null where no line applies), \`summary\` (the quoted hunk and the rule or spec line it violates), and \`hard\`. \`hard\` is true only where the finding shows the diff violating an acceptance criterion, a hard limit of the execution spec, or a standard the repository states as a must; everything else is false. No findings: an empty array.`
}

phase('Implement')
const impl = await call('implementer', 'Implement', 'implementer', `Implement ticket ${ticket} in the checkout ${checkout}, following the execution spec at ${specPath}.

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

async function gateRound(label, phaseTitle, afterFix) {
  const g = await call(label, phaseTitle, gateRunner, gatePrompt(afterFix), GATE_SCHEMA)
  result.gateReports.push(g
    ? { label, overall: g.overall, report: g.report, porcelain: g.porcelain }
    : { label, overall: null, report: null, porcelain: null })
  return g
}

phase('Gate')
const gate = await gateRound('gate', 'Gate', false)
result.gates = gate ? gate.gates : []

if (axes.length) {
  phase('Review')
  const reviews = await parallel(axes.map(axis => () =>
    call(`review:${axis.toLowerCase()}`, 'Review', 'code-reviewer', reviewPrompt(axis), REVIEW_SCHEMA)))
  axes.forEach((axis, i) => {
    const r = reviews[i]
    if (r && r.findings) result.findings.push(...r.findings.map(f => ({ ...f, axis })))
  })
}

const failed = result.gates.filter(g => g.verdict === 'FAIL')
const hard = result.findings.filter(f => f.hard)
// NOT RUN alone never triggers a fix: it is usually a person's step.
if (failed.length || hard.length) {
  phase('Fix')
  result.fixRound.ran = true
  const items = [
    ...failed.map(g => `- GATE ${g.name}: FAIL — log: ${g.log}`),
    ...hard.map(f => `- [${f.axis}] ${f.file}${f.line === null ? '' : `:${f.line}`} — ${f.summary}`),
  ].join('\n')
  result.fixRound.implementerReport = await call('fix:implementer', 'Fix', 'implementer', `Fix round for ticket ${ticket} in the checkout ${checkout}; execution spec at ${specPath}.

These gate failures and hard review findings are UNADJUDICATED — nobody has checked them against source:
${items}

Verify each against source first. Fix what source confirms; refuse what source refutes and report the refutation with its evidence. One round only: reviews are not re-run after it.

${RULES}

Report through the schema: \`report\` covers every item above (fixed or refused, and why), \`commits\` your commits this round, \`porcelain\` as above.`, IMPL_SCHEMA)
  const fix = result.fixRound.implementerReport
  if (!fix) {
    log('fix:implementer dropped: fix:gate skipped')
  } else if (fix.porcelain && fix.porcelain.trim()) {
    log(`fix:implementer left the tree dirty: fix:gate skipped. porcelain: ${fix.porcelain.trim()}`)
  } else {
    const after = await gateRound('fix:gate', 'Fix', true)
    result.fixRound.gatesAfter = after ? after.gates : []
  }
}

const last = result.gateReports[result.gateReports.length - 1]
if (last && last.porcelain && last.porcelain.trim()) {
  log(`WARNING: tree not clean at the last gate round (${last.label}): ${last.porcelain.trim()}`)
}

return result
