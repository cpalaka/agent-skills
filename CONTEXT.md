# agent-skills — domain language

The shared vocabulary for this library of hand-authored Claude Code and Codex Skills and the
machinery (adapters, updater, scaffolding engine) that keeps them in step with the projects that
use them. It grows lazily — only terms that have actually come up belong here, and every term
below is used somewhere in this repo.

## Language

### Skills

**Skill**:
A capability defined by a `SKILL.md` (plus any supporting files) that an agent host loads and
follows — implicitly selected from matching context, or explicitly invoked as `/skill-name` in
Claude Code and `$skill-name` in Codex. How it was installed is orthogonal to what it is:
hand-authored in this repo, bundled in a host plugin, or installed through `npx skills` — all are
Skills.
_Avoid_: plugin (a distribution *bundle* that delivers skills, hooks, and MCP servers — the
container, not a synonym for the skill inside it), agent-skill (a Skill delivered through the
`npx skills` / `~/.agents` channel — same concept, different install path), command /
slash-command (the *invocation surface* of a Skill, not the Skill itself).

**Personal skill**:
A Skill authored and owned by the repo's author. This repo is its source of truth; the
`~/.claude/skills/*` and `~/.agents/skills/*` entries that expose it are symlinks into this repo
or into a thin **Host adapter** here. Protected — `skill-updater` never rewrites it.
_Avoid_: hand-authored (fine as an adjective, but the noun is "Personal skill"), my skill.

**Vendored skill**:
A Skill sourced from upstream and copied into this repo because its upstream ships no install
channel, marked by a sibling `PROVENANCE.md` naming the upstream, the pinned commit, and every
local edit ([ADR 0007](docs/adr/0007-vendor-unchanneled-third-party-skills.md)). `skill-updater`
does not track it; the update is a manual diff-and-re-apply. The invariant "everything here is
hand-authored" therefore reads "everything here *without* a `PROVENANCE.md`".
_Avoid_: third-party skill, external skill (a Skill installed through a channel is not vendored —
it lives under `~/.agents` or `~/.claude/plugins`, not here).

**Ecosystem**:
One of the channels a Skill is installed through — the two update channels **Claude Code
plugins** (the `claude plugin` CLI) and **agent-skills** (`npx skills`, living under `~/.agents`
and discoverable by Codex), plus **Codex plugins** (`codex plugin`, under `~/.codex/plugins`),
which has no update command. `skill-updater` reconciles the first two and enumerates the third;
a Personal skill belongs to none of them (it is hand-authored, not installed).
_Avoid_: marketplace, registry; source (a *source* is a specific origin within an ecosystem, not
the channel itself).

**Host adapter**:
A thin host-specific file that reads one canonical body and states only the substitutions its host
needs — invocation spelling, tool surface, sandbox and MCP registration, workflow router. It must
not copy the canonical procedure. Two instances of the same idea:

- **For a Skill**, a directory that reads the canonical `SKILL.md`. They live in `codex-skills/`.
- **For a project**, the `CLAUDE.md` and `AGENTS.md` that `init-project` emits over the **project
  contract**, `docs/agents/project-workflow.md` — the canonical body both adapters read, which holds
  every project rule and every knob block, once, for both hosts ([ADR 0009](docs/adr/0009-init-project-emits-contract-and-two-adapters.md)).

_Avoid_: fork, port, duplicate skill, compatibility copy; project contract (the canonical body an
adapter reads, not an adapter).

### Catalog content

**Gotcha**:
A non-obvious failure observed first-hand and indexed by *symptom*, not component — typically "I
set X, no error fired, nothing changed." Many have no error signal, so they must be recognised,
not grepped. Body shape: Symptom / Cause / Fix / Detect proactively / Confirmed by. A gotcha is
either **universal** — reproducible on any project given the same engine, tooling or addon, so it
belongs in a cross-project catalog — or **project-local**, bound to one project's own code,
scenes, assets or tuning, so it lives in that project's `docs/godot-gotchas.md`. (A *convention* —
an axis flip, a naming rule — is not a gotcha; it belongs in an ADR.)
_Avoid_: known issue (a gotcha is a field observation, not a release note), trap, edge case (an
edge case is expected; a gotcha is surprising); mirroring a universal catalog into a project doc
(single-source — the catalog is authoritative, the project doc holds only project-local entries).

### Sync & propagation

**Parity**:
The alignment between a project's docs and the source Skill that seeded them. A *parity check* is
the audit; a *parity table* is its output, presented for approval before any write. Applies to
**Templates** only — a **Chunk** has no parity lifecycle, which is why every Chunk header says so —
and of those, only a Profile's own assets have a check that exists (see **Template**).
_Avoid_: equivalence, feature-parity.

**Drift**:
The mismatch a parity check surfaces — usually a project has learned something (a new Gotcha, a
process rule) that the source Skill does not yet carry.
_Avoid_: divergence, staleness.

**Propagate**:
To lift a project-discovered learning *up* into the source Skill. Strictly one-directional:
**project → skill, never skill → project** (the Skill may already be ahead from other projects).
Only *generalizable* knowledge propagates; project-specific decisions stay in the project.
_Avoid_: sync (implies bidirectional — it is not), merge, backport.

**Template**:
A Skill-owned file **copied** into a *new* project at init time — the *copied-and-customized*
delivery mechanism, contrast **Chunk** (referenced, single-source). Reserved for artifacts a
project genuinely edits after the copy. Two owners: `init-project/templates/` holds the four
**engine-owned** ones every Profile emits (`CLAUDE.md`, `AGENTS.md`,
`docs/agents/project-workflow.md`, `.claude/agents/gate-runner.md`), and
`init-project/profiles/<type>/templates/` holds a Profile's own assets — its `docs/` files plus the
four `adapters:` fragments the engine inserts into those four at their markers. Realignment after
the copy is partial and Profile-side only: godot's parity check diffs some of its `docs/` assets
and the `claude` and `codex` fragments, while the `contract` and `gate_runner` fragments and all
four engine-owned Templates are checked by nothing and drift unwatched in every stamped project
([issue #17](https://github.com/cpalaka/agent-skills/issues/17)).
_Avoid_: scaffold, boilerplate; Chunk (the referenced, single-source mechanism — they coexist).

**Fragment target check**:
Migrate mode's gate on a fragment or Template bullet. The bullet's `<!-- requires: -->` comment
names its *targets* — what must already exist in the project for the bullet to be true. Every
target resolves → the bullet is inserted, comment stripped; any fails → the bullet is *withheld*
whole to the migration ledger, never reworded ([ADR 0010](docs/adr/0010-fragment-bullets-declare-their-targets.md)).
Init strips the comments and inserts every bullet, because it writes the targets they name.
_Avoid_: fill gate, existence check.

### Chunks & composition

**Chunk**:
A single-source, invariant dev-process instruction file committed in `chunks/`, delivered to
Claude Code by `@import` and to Codex by an explicit `AGENTS.md` read through the host's chunk
symlink (reference, not copy). Because exactly one copy exists, a Chunk has **no parity/propagate
lifecycle** — editing it updates every consumer at next launch. Holds invariant content only;
per-project variation is handled by knobs, fork selection, or an inline-leaf, never by editing the
Chunk. Discriminator vs **Template**: does the project edit the bytes after delivery? No → Chunk
(referenced); yes → Template (copied).
_Avoid_: Template (the copied mechanism — they coexist), snippet, include,
partial, fragment.

**dev-base**:
The bundle Chunk every dev Profile imports: a single `chunks/dev-base.md` that recursively
includes the eight universal base Chunks (git-sync-branch-start, git-commit-format,
git-confirm-destructive, sandbox-auto, parallel-work, verify-gate, dev-practice, implement-run). Claude Code
expands its `@import` lines; Codex follows the bundle's explicit read directive. The git-flow fork
and the tracker chunk (`backlog-core` or `tracker-github`) are deliberately NOT in it — the
Profile imports each explicitly, because `@import` cannot be undone.
_Avoid_: base chunk (it is a *bundle* of Chunks), boilerplate.

**Profile**:
The declarative recipe for a project TYPE — which Chunks it imports (always **dev-base** plus its
extras), which git-flow fork it selects, which Templates it stamps, and its per-project knob and
inline-leaf prompts. Data consumed by the single `init-project` engine, not a Skill itself. Adding
a new project type = adding a Profile; the engine never changes
([ADR 0003](docs/adr/0003-single-init-project-engine.md)).
_Avoid_: project type (a Profile is the *recipe* for a type), generator (that is `init-project`;
the Profile is its input), Template.

**knob**:
A per-project value for a *value-variant* Chunk (backlog version, plans directory, acceptance-
criteria verify examples, definition-of-done items), written by the `init-project` engine into a
tagged inline block (`<!-- knobs:<chunk> --> … <!-- /knobs:<chunk> -->`) in the project contract,
`docs/agents/project-workflow.md` — never into a **Host adapter**, and never into the Chunk itself.
Tagged so a re-run updates just that block idempotently. Pure-invariant Chunks have no knob block.
_Avoid_: placeholder (`{{…}}` is the copied-Template substitution; a knob is an engine-written
inline block beside a *referenced* Chunk), variable, config.

**inline-leaf**:
Free-form, hand-authored content in the project contract that is genuinely specific to that one
project and is never extracted into a Chunk — a deploy target, a project's own toolchain pins, its
list of relevant Skills. It lives in the contract's **project sections**, below the engine-written
knob blocks and the engine never edits it. Because Chunks are shared and public, this is where
anything project-specific has to live.
_Avoid_: leaf (fine as shorthand), custom; Zone 3 (the retired name from when a project's rules
lived in `CLAUDE.md` beside its imports).

### Multi-agent runs

The `multi-agent-policy` Skill and the implementation Chunk share these terms. A run is any
session that dispatches more than itself: a delegated implementation ticket, a review with
sub-agents, a fan-out from a planning session.

**Planner**:
The capability role for judgment over an ambiguous subject — the main-loop model for wayfinder,
grill, spec, spec-review and to-tickets sessions, and the model behind the **advisor** seat inside
an implementation run. Defined by a property, never a model name: the role that draws on its own
weekly meter.
_Avoid_: scarce / scarce tier (the retired cost-rationing name), Fable (a model name; the role
outlives the model), thinking model.

**Builder**:
The capability role for correctness-bearing, fully specified work — the **coordinator** of an
implementation run and every seat it dispatches except the advisor: implementer, reviewers,
gate-runner. Defined by property: the strongest role with no meter of its own.
_Avoid_: workhorse / workhorse tier (the retired name), budget tier (retired; no cheaper third
role exists), Opus (a model name), executor.

**Seat**:
A named position in a run filled by one pinned agent definition — implementer, advisor,
reviewer (Standards or Spec), gate-runner. The definition carries the model and effort; the seat
name says what the position does. A seat is never a bare spawn, because a bare spawn inherits the
parent's model.
_Avoid_: delegate (acceptable shorthand for the implementer seat only), subagent (the host
mechanism that fills a seat, not the seat), agent type (the host's field name).

**Coordinator**:
The main-loop session running an implementation ticket: it writes the per-phase execution spec,
dispatches the seats, adjudicates every finding against source, and merges. It writes no
implementation diff and, where a gate-runner seat exists, runs no gate itself.
_Avoid_: orchestrator (the older name; "orchestrate" survives only as the toggle word paired
with "solo"), main session (true but says nothing about the role), driver.

**Slot**:
One budgeted consult of the advisor seat within a ticket. Two are fixed — the pre-dispatch pass
over the execution spec, and the pre-merge critic — and one floats for whatever the coordinator
would otherwise ask the user or decide silently. A fourth need goes to the user.
_Avoid_: trigger (the condition that may spend a slot, not the slot), consult (the act of
spending one), call.

### Issue tracking

The `tracker-github` Chunk and the pipeline Skills (wayfinder, to-spec, to-tickets, implement)
share these terms. Status is never stored: it is read off an issue's open state, its gate label
and its blocked-by edges.

**gate label**:
The one `gate:*` label on a workable issue, saying what a session may do with it — `gate:agent`
(start and close alone), `gate:accept` (do the work; the owner accepts before it closes) or
`gate:decide` (a decision or grill comes first; no session starts it). It also picks the commit
footer: `Closes` under `gate:agent`, `Refs` under `gate:accept`.
_Avoid_: status, column, stage (a board's words; there is no board), ready-for-agent (the
upstream role name that maps onto `gate:agent`), hitl / afk.

**origin label**:
The one `origin:*` label saying why an issue exists — `origin:spec` (a child of a `Spec:`
parent), `origin:review` (spun out of a ticket's code review), `origin:spec-review` (filed from a
spec's review, outside its chain), `origin:found` (a defect met while doing other work) or
`origin:chore` (maintenance and housekeeping). A wayfinder ticket carries its `wayfinder:<type>`
label instead of an origin.
_Avoid_: kind, type, category (bug vs feature is title prose, not a label), follow-up (a title
prefix that origin labels retired).

**parent**:
An issue that exists to hold children — a `Spec:` issue whose sub-issues are its tickets, or a
`Map:` issue whose sub-issues are wayfinder tickets. Never workable, so it carries no gate label
and no origin label; its title prefix is its only marker, and it closes when its last child does.
_Avoid_: epic, umbrella, tracking issue.

**frontier**:
The open `gate:agent` issues whose blocked-by issues are all closed and that no one has claimed.
The next ticket is the lowest-numbered one on it. Wayfinder's word, adopted for every chain.
_Avoid_: backlog, queue, todo column.

**closing record**:
The comment a session posts when it closes an issue: each acceptance criterion by number with its
evidence, the reviewed tree's SHA, and, on a `gate:accept` issue, the owner's accepting reply
quoted. It is the tick — the issue body's checkboxes are never rewritten for state.
_Avoid_: sign-off (the owner's reply, which the record quotes), run record (the `implement-run`
Chunk's name for the same comment on an implementation ticket — same thing, that Chunk's word).

### MCP tooling

The `godot` Profile's Templates encode a division of labour between the Godot editor MCP servers,
and get it wrong silently if the two are confused.

**Write-side server**:
The one MCP server that performs all writes to a running Godot editor — `godot-ai`
(scene/node/script/property writes, `project_run`, `logs_read`). There is exactly **one writer per
editor instance**: both servers drive the same `EditorInterface`, so a second editor — on a
worktree, say — is a second independent writer.
_Avoid_: `godot-mcp` / Read-side server (its write path silently no-ops some property types and
still reports success).

**Read-side server**:
The MCP server used only for reads and tests against a running editor — `godot-mcp`
(runtime-state probes, `godot_docs`, editor log and stack reads). Never write through it.
_Avoid_: `godot-ai` / Write-side server.
