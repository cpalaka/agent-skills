export const meta = { name: 'x', description: 'y', phases: [{ title: 'A' }] }
phase('A')
/* The LINE-NUMBER control, and the only fixture here whose comment spans lines as a block. The line
   the explicit-pin rule reports is counted in the STRIPPED source — alone among the rules — so a
   construct codeOnly consumed WITHOUT re-emitting its newlines makes it read low. No exit test sees
   that — this fixture exits 1 either way — so the `selftest: error-lines` line below pins the
   NUMBER in the message rather than the verdict alone: before the 2026-09-18 fix to codeOnly's
   block-comment branch it said line 5 for the call on line 11, and --selftest stayed green. That
   unpinned call is the one and only reason this fixture reds. */
// selftest: error-lines 11
const r = (await parallel([() => agent('hi', {})])).filter(Boolean)
return r
