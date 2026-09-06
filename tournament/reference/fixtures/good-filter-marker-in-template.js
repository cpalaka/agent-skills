// Fixture: a script with NO filter stage at all, whose synthesis prompt quotes one — the marker line and
// a `totals.set(` both sit inside a template literal, as example text for the agent. Detecting markers
// and banners in raw source opened a filter region over this prompt and ERRORed on a script that sums
// nothing; a banner quoted inside a REAL filter's prompt truncated that region the other way. Both are
// fixed by searching the string-blanked source, which keeps comments and blanks string text.
// Expected: exit 0, no WARN.
export const meta = {
  name: 'filter-marker-in-template',
  description: 'a prompt that quotes a filter stage — no filter stage in the script',
  phases: [{ title: 'Synthesize', detail: 'write the assembly note' }],
}

phase('Synthesize')
const EXAMPLE = `Here is the shape an assembled filter stage takes, for reference:

// Filter stage — bracket mode
const totals = new Map(kept.map(i => [i, null]))
totals.set(0, 8)

// Tournament stage — bracket mode
Do not copy it verbatim; fill the slots from the spec.`
const note = await agent(`Write the assembly note.\n\n${EXAMPLE}`, { model: 'claude-opus-5', label: 'assembly-note', phase: 'Synthesize' })
return { note }
