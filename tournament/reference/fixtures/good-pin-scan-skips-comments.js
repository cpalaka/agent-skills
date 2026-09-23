export const meta = { name: 'x', description: 'y', phases: [{ title: 'A' }] }
phase('A')
// The explicit-pin heuristic's CONTROL for reading COMMENTS as code. A `model:` pin belongs in the
// options object of an agent( call, and saying so in prose must not open a pin-span: this mention
// has no pin after it, and before the heuristic ran over code only it closed at the real call
// below and reported that call's line as unpinned (measured for real while writing a single-reason
// fixture, whose comment had to be written around both spellings).
const r = (await parallel([() => agent('hi', { model: 'opus' })])).filter(Boolean)
// The other arm: a trailing mention in agent( form, with no later call for its span to borrow a
// pin from at all. That span ran to end of file.
return r
