export const meta = { name: 'x', description: 'y', phases: [{ title: 'A' }] }
phase('A')
// The other two LINE-NUMBER controls, in one fixture because one fix and one assertion cover both.
// codeOnly's regex-literal branch ended its scan AT the newline and then stepped past it (and ran its
// flag scan into the next line's identifier); its quoted-string branch scanned to the closing quote
// across any number of newlines. So a `/` codeOnly reads as a regex while the parser reads it as
// division, and a `\`-continued string literal, each cost the STRIPPED source a line the raw source
// has. Only the explicit-pin rule counts its reported line in that source, and this fixture exits 1
// either way, so the `selftest: error-lines` line below is what measures the fix: before it this
// reported line 15 for the call on line 17. Both shapes are valid JS the syntax gate accepts
// (measured 2026-09-18) — neither needs a malformed script, so neither is unreachable.
let n = 6
const half = n++ /2
const label = "one long \
continued literal"
// selftest: error-lines 17
const r = (await parallel([() => agent(label, { note: half })])).filter(Boolean)
return r
