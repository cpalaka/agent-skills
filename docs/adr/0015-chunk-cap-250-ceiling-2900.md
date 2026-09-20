# The condensed-Chunk cap is 250 words and the floor ceiling is 2,900

**Status:** accepted — 2026-09-20. Amends [ADR 0014](0014-floor-is-a-location.md) on the per-Chunk
target (§ 1) and the ceiling (§ 7). Everything else in ADR 0014 stands, including that the floor
is a location and that a situational body is a Skill.

**The measurement.** ADR 0014 § 1 asked for "the region of 60 to 100 words" per condensed Chunk;
#47 implemented against 150, a relaxation no ADR recorded. Neither number survived contact with
the files. After a line-by-line disposition of every rule in the two worst offenders — each clause
tested for a destination by grep with a canary and a control, rules moved where a destination
existed and cut only where a structural rule already covered them — the four stand at:

| Chunk | words | was | vs 150 | vs 250 |
|---|---|---|---|---|
| `git-sync-branch-start` | 192 | 192 | +42 | −58 |
| `git-commit-format` | 185 | 251 | +35 | −65 |
| `git-confirm-destructive` | 172 | 172 | +22 | −78 |
| `verify-gate` | 249 | 349 | +99 | −1 |
| `dev-base` | 76 | 76 | (80) | (80) |

**150 collides with this work's own acceptance criterion.** #47 AC 1 requires that "no rule whose
failure is silent is dropped" — the bar ADR 0013 set, and the reason each of these rules is on the
floor at all. `verify-gate`'s constructed minimum, with every knob-duplicating gloss cut and
nothing left to move, measures well above 150. A 150 cap and AC 1 cannot both be satisfied, and
the cap is the arbitrary one: it was chosen before any file had been measured.

**200 was attempted and rejected on measurement, not preference.** `verify-gate` came from 349 to
285 by disposition, then to **249** by cutting every step gloss the `verify-gate` knob block
already stores — the engine fixes that key set at eight and a Profile varies the commands, never
the keys, so each gloss was a second store. What remains is six rules, each verified by grep to
have exactly one store in the repository. Reaching 200 would require relocating the clean-checkout
and gate-scope rules to `verification-discipline` (#52), and even then the one-line pointer ADR
0014 § 1 requires puts the file at **202**. `verify-gate` is structurally a file of about 250
words.

**The ceiling follows from the cap, not the other way round.** A project's floor is adapter +
contract + `dev-base` + the four Chunks. Measured against what `init-project` emits (adapter 478 =
213 shared + 265 profile fragment; contract 1,304 = 264 + 1,040), the fixed part is **1,782**:

```
cap 150:  1,782 + (4×150 + 80 =   680)  =  2,462   under ADR 0014's 2,500 — but unreachable
cap 250:  1,782 + (4×250 + 80 = 1,080)  =  2,862   requires 2,900
actual:   1,782 + (874 measured)        =  2,656   over 0014's 2,500 by 156; under 2,900
```

**The floor as built exceeds ADR 0014's ceiling by 156 words, and that is the honest reading.**
2,500 was derived from a per-Chunk number no file could meet, so it measured nothing: it was 2,500
because 150 was 150. The pair above is derived the same way but from a cap the files can meet, and
the 206 words between the permitted maximum (2,862) and the built floor (2,656) is the room a
future Chunk edit has before the gate fires. A cap is a guard against silent growth; it is set
above the measured shape of the files rather than below it, so that meeting it never requires
dropping a rule whose failure is silent.

**Decision.**

1. **Each condensed Chunk is at most 250 words by `wc -w`**, `dev-base` at most 80. This replaces
   both ADR 0014 § 1's "60 to 100 words" and #47's 150. The number is a cap, not a target: a Chunk
   that condenses below it stays below it, and three of the four sit 58 to 78 words under.
2. **A project's floor ceiling is 2,900 words**, on the same basis ADR 0014 § 7 named — adapter,
   contract, `dev-base` and the four Chunks, with the global file and the tracker Chunks excluded
   and each reported beside it.
3. **One cap for all four, no per-file exemption, now or later.** Where a Chunk cannot meet it,
   the closing record names that as a red reading and says what was decided; it does not earn a
   carve-out.
4. **Both numbers are reported as a pair.** The per-file cap and the four-plus-bundle sum are read
   together, because four files at 249 pass per-file while the floor grows — the failure ADR 0014
   § 7 exists to catch.

**Considered options.**

- **Keep 150 and delete rules to reach it.** Rejected: it requires dropping a rule whose failure is
  silent, which #47 AC 1 forbids and which is the whole basis on which these four files were
  chosen. The cap would be buying words with the thing the floor exists for.
- **200 for all four.** Rejected on the measurement above: `verify-gate` reaches 249 with every
  duplicated gloss gone and 202 only by exporting two rules and paying for the pointer. A cap set
  below the measured floor of its files converts every future edit into a fight with the gate.
- **250 for three Chunks and 300 for `verify-gate` alone.** Rejected, and this was the live
  proposal. An enumerated exemption is the shape this repository's conventions forbid: it sits far
  from the clauses that add members, nothing couples the two, and it goes stale in silence — the
  documented case had one such sentence invert its own polarity, then exclude the very operation it
  existed to exempt, then miss one added a line below it. Naming the gated set and relaxing all of
  it delivers the same relief with nothing to go stale. A cap with one carve-out is not a cap.
- **Keep the per-file number and raise only the sum.** Rejected: the per-file number is the binding
  constraint here. The sum already passes at 150.
- **Lower the contract target instead, keeping 2,500.** Rejected for this decision, not on merit:
  the contract is per-project and ADR 0014 assigns its condensation to that project's own ticket.
  #47 cannot move it, so trading against it here would make this ticket's acceptance depend on work
  it does not own.

**Consequences.**

- **All four Chunks and `dev-base` pass as they stand** — 192, 185, 172, 249 and 76 — and the
  four-plus-bundle sum is 874. No further condensation is required by this decision.
- **This repository's contract changes 150 to 250** in the floor check beside the leak-guard scan.
  `dev-base` at 80 and the tracker Chunks reported without a target are unchanged.
- **#52 keeps its scope.** Moving the clean-checkout and gate-scope rules to
  `verification-discipline` is no longer needed to pass a gate, so it is decided on its own merits
  as a floor-versus-Skill question, after #47 lands.
- **#47's AC 2 and AC 8 name 150 and are superseded by this decision.** They are not rewritten:
  the issue body is the owner's, and the supersession is recorded by comment with the measurement
  that forced it. The checkboxes stay the owner's to tick.
- **`CONTEXT.md`'s floor entry** is re-pointed to name this decision as the amendment.
- **The live numbers for a stamped project are larger and out of scope**: `3d-anim-lab`'s adapter
  measures 1,121 and its contract 7,160, both pending that project's own ticket under ADR 0014.
  The arithmetic above is against what the engine emits, which is the shape #47 is accountable for.
