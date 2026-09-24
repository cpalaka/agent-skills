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
**Templates** only — a **Chunk** is referenced, never copied, so nothing of it can drift and it has
no parity lifecycle; every Chunk header names the one file to edit — and of those, only a Profile's
own assets have a check that exists (see **Template**).
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
([issue #17](https://github.com/cpalaka/agent-skills/issues/17)). One pair is unchecked by
decision rather than by omission: the `github` Profile's `issue-tracker.md` and `triage-labels.md`
Templates mirror this repository's hand-written `docs/agents/` pair and are deliberately divergent —
both sides are pointers plus one table over the single-sourced `tracker-github` Chunk, so there is no
second source for a convention to drift from, and a check would cost more than it saves
([issue #43](https://github.com/cpalaka/agent-skills/issues/43)).
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
(referenced); yes → Template (copied). **Always-on by definition**: every file in `chunks/`
reaches every session and every seat of each importing project on every turn, so the library
holds only the rules that must bind before any Skill could fire; a body read on a signal — a
merge, a parallel-work signal, an implementation run — is a **Skill**, not a Chunk
([ADR 0014](docs/adr/0014-floor-is-a-location.md)).
_Avoid_: Template (the copied mechanism — they coexist), snippet, include,
partial, fragment; situational chunk (a contradiction — that body is a Skill).

**floor**:
The text a session or a seat receives on every turn without asking for it: the global instruction
file, the project's Host adapter, the project contract and the Chunks they import. Measured in
words per project by `wc -w`, global file excluded. Composed **per adapter**: the Host adapter plus
every contract it `@`-imports, then `dev-base` and the four Chunks
([ADR 0016](docs/adr/0016-floor-ceiling-is-acceptance-time.md) § 5). Its **ceiling is
acceptance-time** — a condensing ticket states and measures its own target, and no standing number
is inherited (ADR 0016 § 1, amending ADR 0014 § 7 and ADR 0015 § 2). A measurement also states its
**basis** — source, emitted or live (ADR 0016 § 7). The standing gates and their numbers are ADR
0016 § 2's table and this repository's floor check; they are not restated here, because a glossary
that copies a gate's value is a second store that changes every time the gate does. Distinct from
the **host floor** — the system prompt, tool schemas and skill roster
a host adds regardless, which this repo cannot cut and which a seat-token probe reports beside
the floor, never inside it.
_Avoid_: always-on set, baseline, preamble; overhead (the host's part, not this one).

**dev-base**:
The bundle Chunk every dev Profile imports: a single `chunks/dev-base.md` that recursively
includes the four floor Chunks (git-sync-branch-start, git-commit-format,
git-confirm-destructive, verify-gate). Claude Code expands its `@import` lines; Codex follows the
bundle's explicit read directive. Its membership *is* the always-on list — the engine derives the
Codex read list from it, and no other manifest or header field routes a Chunk (ADR 0014). The
tracker chunk (`backlog-core` or `tracker-github`) is deliberately NOT in it — the Profile imports
it explicitly, because `@import` cannot be undone; the git-flow fork is a Skill the Profile names,
not a Chunk it imports.
_Avoid_: base chunk (it is a *bundle* of Chunks), boilerplate.

**Profile**:
The declarative recipe for a project TYPE — which Chunks it imports (always **dev-base** plus its
extras), which git-flow fork it selects (a Skill named in both adapters since ADR 0014), which
Templates it stamps, and its per-project knob and inline-leaf prompts. Data consumed by the single `init-project` engine, not a Skill itself. Adding
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
inline block beside a *referenced* Chunk), variable, config, dial (a per-run value the coordinator
derives from its plan; a knob is per-project and engine-written).

**inline-leaf**:
Free-form, hand-authored content in the project contract that is genuinely specific to that one
project and is never extracted into a Chunk — a deploy target, a project's own toolchain pins, its
list of relevant Skills. It lives in the contract's **project sections**, below the engine-written
knob blocks and the engine never edits it. Because Chunks are shared and public, this is where
anything project-specific has to live.
_Avoid_: leaf (fine as shorthand), custom; Zone 3 (the retired name from when a project's rules
lived in `CLAUDE.md` beside its imports).

### Multi-agent runs

The `multi-agent-policy` and `implement-run` Skills share these terms. A run is any
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
A named position in a run filled by a pinned agent definition — implementer, advisor,
gate-runner, and reviewer: the Standards and Spec axes, the Correctness fallback and the **critic
seat**, each a `code-reviewer` dispatch. A definition carries the model and effort, one definition
per effort value the seat can reach, the bare seat name carrying the default; the seat name says
what the position does. A seat is never a bare spawn, because a bare spawn inherits the
parent's model. The plan-stop roster's `codex` is a lens struck like a seat, not a seat: no agent
definition fills it.
_Avoid_: delegate (the session standing in for the owner across a **batch**, never a seat),
subagent (the host mechanism that fills a seat, not the seat), agent type (the host's field name).

**run profile**:
The set of per-run values the **Coordinator** derives from its own plan before dispatch — which
seats run, the bug hunter, the gate tier, each seat's effort, the fix-round and scope caps, and
whether a reader stops the run — one **dial** each, posted as a profile block in the run's first
message and repeated in the run record ([ADR 0018](docs/adr/0018-run-profile-derived-from-plan.md)).
_Avoid_: seat tier (the retired declared form), posture (the retired ADR 0006 ladder), run plan
(collides with the execution spec), level / tier (a profile has no named levels).

**dial**:
One member of a **run profile**: a default, the plan fact that turns it, and a value. A ticket may
**pin** a dial, a **lower bound** the coordinator never lowers, beside its acceptance criteria;
mid-run evidence only ever raises one. An effort dial's value names a seat definition, or sets a
workflow stage's effort where the stage fills a seat.
_Avoid_: knob (per-project and engine-written, never per-run), lever, setting, strike (the retired
act of removing a seat from the roster line); floor, for a pin (the glossary's **floor** is the
always-on context text).

**light plan**:
A plan whose every changed path is in the project's light set, is loaded by no gate, and is no
**instruction file**; on one, every unpinned **dial** sits at its default and no reader stops the
run. The light set is a project **knob** (cpalaka/agent-skills#86).
_Avoid_: floor, "above the floor" (ADR 0018's words for this; the glossary's **floor** is the
always-on context text), base profile, light tier, docs mode.

**instruction file**:
A file a session or seat follows as instructions: whatever a host injects (a **Host adapter**, the
project contract, and every contract or **Chunk** they import), every file under a **Skill**'s
directory, every seat definition, and every file one of those names as a read. One in a diff
raises every seat and effort **dial**, never the gate tier, and no light set makes one light
(cpalaka/agent-skills#86).
_Avoid_: instrument set (ADR 0019's name for the same set; ADR 0016's "instrument" is the tool that
reads a number), prompt file, config.

**seat tier**:
Historical: which seats a ticket's run dispatched, declared as `Seats: light` or `Seats: full` in
the ticket body and readable only upward. Retired by cpalaka/agent-skills#85 for the **run
profile**, which the coordinator derives and the ticket pins one dial of; an existing line reads
as absent. A project's **gate tier** is now a dial of the profile rather than a separate field.
_Avoid_: gate label (the tracker label for what a session may do with the ticket), bare "tier"
(ambiguous with the gate tier and with the retired cost tiers), docs mode / lite run.

**Coordinator**:
The main-loop session running an implementation ticket: it writes the per-phase execution spec,
dispatches the seats, adjudicates every finding against source, and merges. It writes no
implementation diff and, where a gate-runner seat exists, runs no gate itself. Under a **batch** it
is a depth-1 dispatch of the `coordinator` definition, and the **delegate** is its reader.
_Avoid_: orchestrator (the older name; "orchestrate" survives only as the toggle word paired
with "solo"), main session (true but says nothing about the role), driver.

**Slot**:
One of three numbered positions for judgment within a ticket, numbered as the `implement-run`
Skill numbers them. Slot 1, the pre-dispatch pass over the execution spec, and slot 3, floating for
whatever the coordinator would otherwise put to the owner or decide silently, are the advisor's,
filled by consulting the seat or, where it cannot be spawned, by holding the judgment yourself.
Slot 2, pre-merge, is filled by the **critic seat**, not the advisor. The `implement-run` Skill's
§ Advisor slots Fallback paragraph says what a tight meter funds. A fourth need goes to the owner.
_Avoid_: trigger (the condition that may spend a slot, not the slot), consult (the act of
spending one), call.

**critic seat**:
The fresh `code-reviewer` dispatch after every lens and before the merge on every full-tier
ticket, charged as completeness critic and counter-critic; the `implement-run` Skill's § Review
carries the charter. A Builder seat, so it spends no Planner meter.
_Avoid_: slot 2 (the numbered position it fills, not its name), pre-merge consult, advisor critic
(the retired arrangement).

**capped form**:
Historical: what a run record called the advisor's pre-merge reading when a tight meter left one
affordable slot, given before the diff existed. Retired by cpalaka/agent-skills#68, which moved the
pre-merge critic off the advisor onto the **critic seat**, so no reading stands in for a diff that
did not exist.

**delegate**:
The main session that stands in for the owner across a **batch**: it answers the plan stop, the
Close approval and a slot-3 need the advisor cannot settle, reads every diff from git, and
**parks** a ticket at any stop the owner keeps. Attributed `owner's delegate` in every run record
([ADR 0019](docs/adr/0019-delegated-batch-over-subagent-coordinators.md)).
_Avoid_: owner (the human it stands in for), outer coordinator / outer session (the test-run name),
proxy, steward.

**batch**:
The tickets one **delegate** session works under a single grant, run one at a time through
per-ticket **Coordinator** dispatches; a batch of one is legitimate. Defined by the delegate, never
by the count.
_Avoid_: chain (a blocked-by sequence, which a batch need not follow), run (one ticket's), loop.

**park**:
The **batch** exit that leaves a ticket open for the owner: a comment naming the stop, the claim
released, the delegate moving to the next ticket. Two consecutive parks end the batch.
_Avoid_: skip (says nothing was recorded), defer, block.

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
evidence, the reviewed commit's SHA, and, on a `gate:accept` issue, the owner's accepting reply
quoted. It is the tick — the issue body's checkboxes are never rewritten for state.
_Avoid_: sign-off (the owner's reply, which the record quotes), run record (the `implement-run`
Skill's name for the same comment on an implementation ticket — same thing, that Skill's word).

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
