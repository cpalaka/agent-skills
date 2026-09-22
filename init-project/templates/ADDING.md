# Adding to the shared contract

`project-workflow.md` is loaded into every session on every host — an `@` import on Claude Code,
item 2 of the mandatory read list on Codex. Nothing about it is lazy. A sentence added here is
re-read by every session for the rest of the project, whether or not it ever fires.

## The test: name the reader

Before a line enters the contract, answer three questions, one sentence each, on the record:

1. **Who reads it?** The coordinator, an implementer seat, the gate-runner, a host adapter, a
   human.
2. **At what moment — and is the contract the narrowest carrier guaranteed loaded then?** A rule
   that fires only inside a slash-only Skill belongs in that Skill, which is always explicitly
   loaded. A rule that fires on a commit or a branch start belongs in a Chunk. A rule true of one
   host belongs in that host's adapter. The contract earns a rule only when the moment it fires
   can arrive in any session, unannounced.
3. **Would they act differently without it?** Where the tool already prints it, refuses it or
   enforces it, the sentence is a second copy of a verdict the reader already holds.

Question 3 is the one that deletes rather than shortens, and it has a precondition: **read the
tool's source before writing prose about how the tool behaves.** A procedure someone performed
once can outlive its reason, or never have had one. A doc instructing a reader to redo what the
tool already did is worse than bloat: it is a false premise they will act on.

## The budget: 16,384 bytes

`wc -c docs/agents/project-workflow.md` must be **≤ 16,384**. Init's step 7 gates it, and it is
the project's to hold between stamps.

That is half the 32,768-byte adapter cap, and the two measure different things. The adapter cap
comes from Codex's `project_doc_max_bytes` and exists to prevent silent *truncation*. This one is
a context-cost budget and exists to prevent silent *accretion*. Do not reconcile them.

A fresh stamp lands well under, so the cap never blocks day zero. It bites later, which is the
point. **At the cap an addition is admitted only by retiring something** — propose the retirement
with the candidate, or withdraw the candidate. Record the before and after figures in the commit.

Measured on the project this protocol came from: the contract went 1,500 words at its scaffold to
7,263 in thirteen days, 4.8×. Across its first 45 commits, 38 added and 6 removed, and every one
of the 6 was a deliberate cleanup campaign. Routine work never cut it once. Assume the same here
until measurement says otherwise.

## When a ticket's acceptance criterion says to record it here

Satisfy the form, invert the substance: file the fact at the destination the reader test names,
then write into the ticket that the contract was not the destination and why. Do not perform the
literal edit, and do not silently drop the criterion.

This clause exists because ticket work, not session close-out, was the larger source on the
project measured — 3,666 of the 6,680 words added after the initial scaffold arrived under a
ticket id, including the three largest single additions. An acceptance criterion carries its
approval with it, so nobody argues with it, which is exactly why the test has to reach there too.

## Retiring a rule

Cut it, then sweep the inbound direction as its own pass: grep the adapters, the seat definitions
under `.claude/agents/`, and the Skills for anything that names the section, quotes it, or makes a
claim about what it says. A consumer that *quotes* leaves no pointer to find, so a check keyed on
section names and file paths will not see the break, and the break is silent.

Where a whole group of rules exists because of a goal or a mechanism that has since lapsed, record
that it lapsed in a file that survives the deletion, and cite that record from the change.
Otherwise the next session restores the group from the same still-live instruction that produced
it, correctly, having no way to know the reason is gone.
