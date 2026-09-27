## Run profile

Plan first, then post the run profile: every dial at its default, read off the plan's changed paths
(against `light_set` and the project contract's trigger table, an instruction file among them) and
its expected implementer calls, plus the add-ons you recommend. An **add-on** is a dial value above
its default that you may recommend with a named reason, turned on only by the owner's approval or a
pin. The first column's
tokens name the dials in a pin, the profile block and the workflow script's `args.profile`. Every
default lives in `defaults.yaml`, beside `SKILL.md`; the Default column names its key there, or says
how the plan derives it.

| Dial (token) | Range | Default | Add-on, recommended when |
|---|---|---|---|
| `implementer`, `gate-runner`, `spec` | on | always on | none |
| `standards` | off, on | `dials.standards` | on, where an instruction file is in the diff |
| `advisor` (slot 1; slot 3 only where on) | off, on | `dials.advisor` | none |
| `critic` | off, on | `dials.critic` | on |
| `bug hunter` | `off`, `codex`, `correctness` | `dials.bug hunter`: its `above light plan` value, its `light plan` value on a light plan | `codex` on a light plan; `correctness` only in place of `codex` (§ Review) |
| `gate tier` | a named tier of the project contract plus any trigger-table pulls; where the contract names none, one full gate less `verify-gate`'s derived skips | the lowest tier plus every trigger-table pull for the changed paths | a higher tier, by pin only |
| `effort <seat>` | `medium` < `high`, each seat within the definitions § Seats lists for it | `dials.effort`, per seat; the gate-runner `medium` only, the advisor `high` only | `high` |
| `fix rounds` | 1, or a higher integer with a reason | `dials.fix rounds` | none: raised only at the fix-round cap stop or by a plan pin with a reason |
| `scope` | the plan's deliverable count; a number of tool calls per implementer dispatch | the plan's count; `dials.scope`'s `calls per implementer dispatch` | a plan pin with a reason |
| plan stop | none, stop | none | fires on a recommended add-on or a pin above default |

**A light plan** is one whose every changed path matches `light_set`, is loaded by no gate, and is
no instruction file; any other plan is above the light plan. The instruction-file test runs first,
so no glob makes one light. "Loaded by no gate" is `verify-gate`'s derivation: grep what references
the path and name the gate that loads it.

**An instruction file** is whatever a host injects (a host adapter, the project contract, every
contract or Chunk they import), every file under a Skill's directory, every seat definition, and
every file one of those names as a read. *Named as a read* means named to be followed as
instructions — a Chunk, a Skill, a contract, a seat body, a procedure — not a glossary, README, ADR
or results record cited for reference: a host adapter or contract may name `CONTEXT.md` or `README.md`, and
`defaults.yaml`'s `light_set` holds both on purpose. One in the diff makes you recommend the Standards
axis, which found 10 of its 11 measured findings on such diffs (ADR 0018's #86 amendment), since it
changes the instrument the next run reads; it turns nothing on by itself.

**Effort** is dispatched as a definition name (§ Seats): each seat at its `dials.effort` value,
`high` above it an add-on;
the advisor, a dial as a whole, and the batch `coordinator`, the main loop rather than a dial,
keep their one `high` definition. The Codex lens takes no effort. Expected implementer calls turns
no dial: it sizes phases and sets the `scope` cap.

**Pins.** The ticket author pins a dial on its own line directly above the acceptance heading, or
anywhere in the body where the tracker's ticket has none, `Pins: <token>: <value>`, several
separated by `;`: `Pins: critic: on; gate tier: 2; effort critic: high`. The `<seat>` of an effort
token is one of the seat tokens above. A pin is a lower bound on you: the dial takes the higher of
pin and default, and only the owner lowers one (the stop, below). A line naming an unknown
token, `fix rounds` or `scope` (only a plan pin raises those, its reason on the block line), or a
value outside its range reads as absent, noted under `Deviations`. Adding a pin to a ticket not yet
started is the tracker Chunk's body write for adding an acceptance criterion. Two retired forms read
as absent, a `Seats: light` or `Seats: full` line (the retired seat tier) and the
`Advisor: pre-dispatch only` marker: no pin is inferred, the run takes its defaults, and the record notes the
line was present and read as absent. A body sentence naming a gate tier in prose ("runs tier 2",
"Gate: tier 1") reads as a pin on `gate tier` alone, marked `pin (tier sentence)`. No open ticket's
body is rewritten to remove either.

**The ratchet** raises defaults only, under `Deviations`, and reopens no stop. A diff path outside
the plan's changed-path set re-derives the defaults with that path in — a plan leaving the light
plan gives `bug hunter` its `above light plan` value where the dial is `off`, and one already running keeps its value; the gate tier's default is recomputed as the lowest tier plus the
new set's trigger-table pulls, the dial itself turned only by a pin — unless it adds a deliverable
the plan did not count, which is `scope`'s stop. It turns no add-on on: a red gate re-runs its gate
as a round (§ Review) and turns nothing on; only a material finding that argues for another seat
becomes an add-on recommendation, carried to the next owner stop, the fix-round cap stop or the
Close approval. An `advisor` turned on after dispatch opens slot 3 only: slot 1's moment has
passed, and the record says so.

**Caps** are constants, not risk-derived. `fix rounds`: that many material rounds; a round past
`fix rounds` is **the fix-round cap stop**, whose ask names both options, *land and file the residue* and *one more
round*, and states which way the residue fails. Residue that fails safe, its failure ending in a
stop or a refusal, never a silent pass, defaults to landing; residue that fails open carries no
default, the ask presenting both options evenly. Wording-only findings ride a material round or
form one closing round that counts toward no cap: every scan that reads prose checks its diff,
since a scan can match prose a fix round wrote, the certifying gate runs after it where it lands
after that gate, and it takes no targeted re-review — you check the wording diff against the
findings you accepted. `scope`: the plan's deliverable count, and
`dials.scope`'s `calls per implementer dispatch` (the call cap), counted from its transcript; one
past the cap, in any shape, goes under `Deviations`. Cost is near-linear in calls, 0.15–0.20 USD each, and a phase past 85 cost 13–32
USD (the token-usage audit behind cpalaka/agent-skills#68). A continued dispatch keeps its count, so one at the cap is never continued by message: its next leg, a fix
round or the phase's remainder, goes to a fresh implementer handed the findings and the diff,
counting from zero. A phase the plan expects to exceed the cap is split before dispatch. Work past the
deliverable count is a stop, never a ratchet: more work is the reader's scope question. **A plan
pin** raises `fix rounds` or `scope` in your own plan, its reason on that dial's block line,
`fix rounds: 2 — a migration and its revert are two rounds by construction`; it sits above default,
so it fires the stop.

**The profile block** is one line per dial, `token: value — the fact that set it`, pins marked
`(pin)`, then one `recommend <token>: <value> — <reason>` line per recommended add-on; the effort
dials share one line naming the definition dispatched per seat, the gate-runner's fixed value
unlisted:

```
effort: implementer-medium, code-reviewer-medium (spec), advisor — default
effort: implementer-medium, code-reviewer-medium (spec), code-reviewer (critic), advisor — critic and its high pinned
recommend standards: on — an instruction file in the diff
```

Post it in the run's first message, whatever the plan; inside a batch that message is the brief's
first output, which the delegate reads at the first hand-back or at Close. The run record repeats it
as dispatched (§ Close), and every ratchet goes under `Deviations`.

**The stop** fires only on a recommended add-on or a pin above default: the reader approves the
profile before any dispatch. The reader is the owner, or the delegate inside a batch (§ Inside a
batch). Otherwise post and go on. At the stop, or by interrupting after the
posted profile, the owner may lower any dial but `spec`, a pinned one included, recorded under
`Deviations` as the owner's decision; nothing else lowers a dial.
