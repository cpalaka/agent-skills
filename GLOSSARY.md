# agent-skills — domain language

The shared vocabulary for this library of hand-authored Skills. It grows lazily: only terms that
have come up belong here, and every term below is used somewhere in this repo. Terms the retired
pipeline needed (Chunk, Template, Profile, knob, Seat, dial, gate label and the rest) live in the
ADRs that decided them and in `git log` before October 2026.

## Language

### Skills

**Skill**:
A capability defined by a `SKILL.md` (plus any supporting files) that an agent host loads and
follows, either selected from matching context or invoked as `/skill-name` in Claude Code and
`$skill-name` in Codex. How it was installed is orthogonal to what it is.
_Avoid_: plugin (a distribution bundle that delivers skills, hooks and MCP servers; the container,
not the skill inside it), command / slash-command (the invocation surface, not the Skill).

**Personal skill**:
A Skill authored and owned by the repo's author. This repo is its source of truth; the entries
under `~/.claude/skills` and `~/.agents/skills` that expose it are symlinks into this repo.
_Avoid_: hand-authored (fine as an adjective; the noun is Personal skill), my skill.

**Vendored skill**:
A Skill copied here from an upstream that ships no install channel, marked by a sibling
`PROVENANCE.md` naming the upstream, the pinned commit and every local edit
([ADR 0007](docs/adr/0007-vendor-unchanneled-third-party-skills.md)). The invariant "everything
here is hand-authored" therefore reads "everything here without a `PROVENANCE.md`".
_Avoid_: third-party skill, external skill (a Skill installed through a channel is not vendored).

**Gotcha**:
A non-obvious failure observed first-hand and indexed by symptom, not component: "I set X, no
error fired, nothing changed." Many have no error signal, so they must be recognised, not grepped.
Body shape: Symptom / Cause / Fix. A gotcha is **universal** (reproducible on any project with the
same tooling, so it belongs in a cross-project catalog) or **project-local** (bound to one
project's code or assets, so it lives in that project's docs). A convention is not a gotcha; it
belongs in an ADR.
_Avoid_: known issue (a gotcha is a field observation), trap, edge case (an edge case is expected;
a gotcha is surprising).

### Building

**Brief**:
The one file in a project's `docs/` that the `build` Skill works from: the problem, the solution,
the decisions, what is out of scope, and the numbered Milestones. It is the spec and the task list;
a wrong Brief is fixed in place, never guessed around.
_Avoid_: spec, plan, PRD (all three are what the Brief replaces as separate artifacts), ticket (a
Ticket is one unit of a Brief in a kept repo, not the whole).

**Milestone**:
One numbered unit of work in a Brief, carrying its own Done check. Built in order; a Milestone is
done when its Done check and the project's Verify command are both green, and where feel matters,
when the owner has played it.
_Avoid_: task, phase, step (a step is one action inside a Milestone).

**Ticket**:
A Milestone kept as its own file, `docs/tickets/NN-slug.md`, with a `Status:` line as the only
progress record. Kept repos use Tickets; throwaway repos keep Milestones inside the Brief.
_Avoid_: issue (this repo and the projects it serves keep no tracker).

**Done check**:
The observable a Milestone names as its own exit condition: a command's output, a probe's printed
line, a thing the owner can see at F5. Written into the Brief before the Milestone is built.
_Avoid_: acceptance criterion (the old pipeline's term; a Done check is one line, not a list),
gate (that word belongs to the Verify command).

**Verify command**:
The one command a project exposes that runs before anything is called done: typecheck, tests,
build, smoke, whatever the project has, behind one name. Here it is `.githooks/leak-guard.sh scan`.
_Avoid_: gate runner, verify gate, CI (a Verify command runs locally and is the only gate).

**Kept repo**:
One of the two project kinds the `build` Skill distinguishes; the other is the Throwaway repo. A kept repo carries `GLOSSARY.md`, lazy
`docs/adr/`, one `AGENTS.md`, Tickets, and a branch per Ticket squash-merged locally.
_Avoid_: production (a kept repo may be a game that never ships).

**Throwaway repo**:
A project that exists to answer one question. It commits on `main`, keeps its Milestones in the
Brief, and is forked into a Kept repo only if the answer is yes.
_Avoid_: prototype (a throwaway may be large; what makes it throwaway is the single question).
