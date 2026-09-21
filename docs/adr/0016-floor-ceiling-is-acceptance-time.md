# The floor ceiling is acceptance-time, and every standing number names its reader

**Status:** accepted — 2026-09-20. Amends [ADR 0014](0014-floor-is-a-location.md) § 7 and
[ADR 0015](0015-chunk-cap-250-ceiling-2900.md) § 2 on the ceiling. Everything else in both stands:
the floor is a location (0014), the condensed-Chunk cap is 250 words and `dev-base` 80 (0015 § 1),
one cap with no per-file exemption (0015 § 3), and the per-file number and the sum are read as a
pair (0015 § 4).

The title carries no count of the gates below. An earlier draft of this entry said "three", and the
count went stale inside the ticket that wrote it.

## The measurement that forced this

#50's acceptance run summed the Claude floor for ten importers. **Seven of ten exceed 2,500, and
the same seven exceed ADR 0015's amended 2,900.** The three that clear are exactly the three
carrying no project contract. The floor work itself is not in question: on the one row with a
like-for-like before-number the always-loaded text went 16,763 → 9,901 words (41%), and the seat
probe 32,995 → ~21,900 tokens against a measured 104-token tolerance.

**1. 2,900 is 2,900 because 1,350 was 1,350, and 1,350 was falsified by arithmetic.** ADR 0015
built the ceiling as adapter 478 + contract 1,304 + the bundle cap 1,080 = 2,862, rounded to 2,900.
The live instantiation of that pair is the stamped godot project's 450 + 1,350, and that contract
target cannot be met: a sibling criterion freezes three knob blocks byte-identical and they measure
**1,592 words** in that project, so deleting the title, the intro and all five sections still
overshoots by 242. (That 1,592 is the *live* project's blocks, which accrete per-project values; it
is not a figure reachable from this repository, and no path here carries it.) ADR 0015 diagnosed
2,500 as *"it was 2,500 because 150 was 150"* and then derived its replacement from a number no
file could reach.

**2. Three bases have been in play, and no document said which it was using.** A floor can be
measured on the **source** basis (the Templates and fragments as they sit here, with `{{…}}` tokens
unexpanded), the **emitted** basis (after the engine's step 1 renders them), or the **live** basis
(after a project grows). ADR 0015 § "The ceiling follows from the cap" labels its arithmetic "what
`init-project` emits" while measuring source files — `init-project/templates/project-workflow.md`
is 264 words only because `{{KNOB_BLOCKS}}` is one unexpanded token. #50's sweep measured live
projects. The two were compared as though they were the same reading.

**3. The gap is not one token.** `{{IMPORT_LINES}}` expands the same way, and five
`*<Fill at init: …>*` prompts are replaced at stamp by owner-written prose of no bounded length.
Godot's knob entries alone render to 429 words board-less and 590 board-driven. **The emitted pair
is therefore not a number**: three independent assemblies of it during this ticket read 2,145,
2,247 and ~2,370 — a 10% spread that is a property of the assembly method, not of the files. Any
future budget must come from a stamp with its method recorded, never from an assembly.

**4. No general per-project contract or adapter target ever existed.** 1,350 and 450 are scoped in
#44 to one project — *"The stamped godot project's contract … at most 1,350 words and the Claude
adapter at most 450 words"* — and #44 § Out of Scope fences the rest. `grep -rn -E '1,?350|450
words'` over `docs/`, `CONTEXT.md`, `CLAUDE.md`, `init-project/` and `chunks/` returns only the ADR
index row. What bound every row was a combined budget by subtraction: #44 gated each floor sum
against 2,500 with the bundle at its spec-time cap (4×150 + 80 = 680), leaving adapter + contract
≤ **1,820** — the figure ADR 0015 preserved as 2,900 − 1,080.

**5. 1,820 is the diagnosed shape, one generation on.** It is 1,820 because 2,500 was 2,500 because
1,350 was 1,350. #44 set 2,500 so one row's live targets fit (450 + 1,350 + 680 = 2,480); ADR 0015
re-derived the same figure on the source basis by coincidence (1,782 + 38). A gate table that
installed 1,820 would carry the number this entry's finding 1 diagnoses. It appears here in the
record and in no gate.

**6. And 2,900 is gated by nothing, anywhere.** This repository's floor check
(`docs/agents/project-workflow.md`) is `wc -w` over `chunks/`: no adapter and no contract enters it,
so it cannot compute a per-project sum and cannot go red on any ceiling. The ceiling has been
measured exactly once in its life, by #50.

**7. The spec gated a sum it fenced out the means to meet.** #44's Testing Decision 1 gates all ten
floor sums; its Out of Scope forbids touching nine of the contracts and adapters those sums are made
of. The headline acceptance was unmeetable for nine rows by the spec's own scope.

## Decision

1. **The floor ceiling is acceptance-time, not a standing gate.** ADR 0014 § 7 already said so in
   its own words — 2,500 was *"the acceptance for the tickets under this decision"*, and the check
   it required to stand afterwards is the `chunks/` check, not the per-project sum. 2,900 is
   recorded as what #44's chain was accepted against and is not carried forward. A ticket that sets
   out to condense a floor states its own target, on a named basis, and measures against it; no
   standing number is inherited.

2. **Every standing number names the instrument that reads it and the trigger it fires on.** A
   number whose reader is unnamed is the state that produced this decision. Two stand today:

   | gate | number | reader | trigger |
   |---|---|---|---|
   | per condensed Chunk | 250 (`dev-base` 80) | this repository's floor check | before any commit here |
   | four-plus-bundle sum | **1,080** | this repository's floor check | before any commit here |

   Both are read by the same instrument because that instrument is the only one this repository can
   make go red. A number this repository cannot read is not listed as a gate here.

3. **The four-plus-bundle sum is targeted at 1,080, by construction.** Four Chunks at the 250 cap
   plus `dev-base` at 80 is 1,080: the constructed maximum of gates already in force, not a figure
   fitted to the measured 877. The 203 words between them is the room a future Chunk edit has, and
   ADR 0015 § 4 already requires the per-file number and the sum to be read together — this gives
   the second half of that pair something to fail against.

4. **No adapter-plus-contract gate is installed by this decision, and the reason is a disqualifier
   rather than a preference.** Three candidate numbers were considered and each fails at the trigger
   it would fire on, not on its value:
   - A stamp-time gate on any absolute number is red on day zero for the live basis. `init-project`
     runs step 7 in **migrate** mode against a project's own contract, so a migrate gate goes red
     immediately on all seven red rows — which is the disqualifier this entry applies to 450/1,350,
     and it also contradicts § 5 below, which hands a project's floor to that project.
   - The number it would gate is not measurable from here (finding 3): fill-ins are unbounded and
     assemblies disagree by 10%.
   - 1,820 itself is the diagnosed shape (finding 5).

   **Where such a gate belongs is a live question with a named home**, not a gap: the growth it
   would catch originates in commits to *this* repository — two Templates, the Profile fragments,
   the knob manifests — so the trigger that sees it first is this repository's floor check, and the
   budget is a Profile's to declare in the shape [ADR 0010](0010-fragment-bullets-declare-their-targets.md)
   already uses for fragment targets. That is a hypothesis to derive against the engine's step 1
   with a calibration stamp, not a patch, and it is its own ticket.

5. **The floor sum is composed per adapter**: the Claude adapter plus **every** contract that
   adapter `@`-imports, then `dev-base` and the four Chunks, with the global file and the tracker
   Chunk excluded and each reported beside it. Both prior ADRs say "the contract", singular, and the
   engine emits exactly one contract import — a second is hand-placed and survives through the merge
   rule's refusal to reorder hand-placed imports. #50 met a two-contract project and summed both;
   that method is now the rule, recorded because the shape exists in the wild and neither ADR
   answered it. It changes no verdict in #50's table: the two-contract row reads 3,222 or 3,235 with
   either contract alone, red on 2,900 either way.

6. **A project whose floor exceeds what its own ticket set is that project's ticket**, under
   ADR 0014's standing consequence. Nothing here condenses another project's contract or adapter.

7. **A measurement states its basis.** Source, emitted or live, per finding 2. A floor figure quoted
   without one is not comparable to another, which is how 2,862 and #50's sweep came to be read as
   the same kind of number.

## Considered options

- **Keep 2,900 and let every red row become a per-project ticket.** The spec's designed response,
  rejected on what 2,900 is made of: a target falsified by arithmetic on the one project that
  carried it. The per-project ticketing survives (§ 6); the inherited number does not.
- **Re-cost the ceiling against the ten measured live sums.** Rejected on the ticket's own
  objection: a ceiling fitted to current sums makes every live contract look independently
  justified, which is how 1,200 survived #49's refutation of the sentence that produced it. It also
  leaves the reader problem untouched.
- **Install 1,820 as a stamp-time gate.** Rejected on finding 5 and § 4. This was the live proposal
  and it was drafted into this entry before a playthrough measured the emitted pair; the draft
  justified it with "1,782 clears 1,820 with 38 words of room", which is a source-basis reading of
  an emitted-basis gate.
- **Report the pair at stamp without gating it.** Not adopted and not rejected — it is the reporting
  half of § 4's live question, and it belongs to that ticket rather than being half-installed here.
- **A machine-local sweep as the reader.** Rejected as a gate, not as a report: one clone on one
  machine, and #56 records that the `find`-based project derivation under-reads. It stays available
  for an acceptance-time measurement, which is the status § 1 gives the ceiling.
- **Carry the sum in each stamped project's gate-runner seat.** Not adopted, not rejected: the right
  shape, but it reaches only the stamped rows and it is those projects' change to make (§ 6).

## Consequences

- **This repository's contract gains a target on the four-plus-bundle sum** — 1,080 — beside the
  per-file 250. Today's reading is 877, green with 203 words of room. Calibrated: a 210-word plant
  reads 1,087 and fires.
- **`init-project` step 7 is unchanged by this decision**, beyond two enumerations corrected below.
  It gains no measurement, because § 4 declines to install one there.
- **Two stale enumerations in `init-project/SKILL.md` are corrected**, both the shape `CLAUDE.md`
  § Conventions forbids: migrate mode's step 7 line named one measurement ("byte gate included")
  out of the set, and handoff item (g) enumerated two figures by name. Both now name the whole step.
- **#44's headline acceptance is marked unmet, and #44 closes anyway.** The floor work landed and is
  measured; the acceptance was unmeetable for nine of ten rows by the spec's own scope (finding 7).
  It is dispositioned in a comment, not rewritten — the body is the owner's.
- **`CONTEXT.md`'s floor entry points at this decision rather than restating its numbers.** A
  glossary that copies a gate's value is a second store that changes every time the gate does.
- **ADR 0015 § 2 is superseded in full; § 1, § 3 and § 4 stand.** ADR 0014 § 7's ceiling sentence is
  superseded; its requirement that a check stand after the tickets close is honoured by § 2.
- **#52 is unaffected.** `verify-gate` at 252 against the 250 cap and the bundle at 877 against the
  recorded 874 are inside every one of the ten sums and remain that ticket's.
- **The gate-runner caps are not re-cost here.** #44's first comment asks for 800 / 300 / 1,200 —
  measured at ~1,190 / ~330 / ~2,700 — to be re-cost together, the same shape as this decision.
  Folding them in would settle three numbers in a decision none was costed against; they get their
  own ticket.
