# agent-skills

Hand-authored Skills for [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) and
[Codex](https://developers.openai.com/codex), plus the two things that keep them useful across
many projects: a **Chunk library** of single-source dev-process instructions that projects
reference rather than copy, and the **`init-project`** engine that scaffolds a project onto it.

A Skill is a `SKILL.md` (plus supporting files) that an agent host loads — implicitly when the
context matches its `description`, or explicitly as `/skill-name` in Claude Code and
`$skill-name` in Codex. Nothing here is a framework: each Skill is a document you can read in one
sitting, and most of them exist because something failed silently once and the fix had to be
written down.

## Install

Per Skill, through the [`skills` CLI](https://github.com/vercel-labs/skills):

```sh
npx skills add cpalaka/agent-skills -s verification-discipline
```

Repeat `-s` for each Skill you want; it takes several in one invocation.

Or clone once and symlink whichever Skills you want into your host's user skills directory —
this is what the author's own machines do, so a change in the clone is live in every host with no
reinstall step:

```sh
git clone https://github.com/cpalaka/agent-skills.git
cd agent-skills

ln -s "$PWD/verification-discipline" ~/.claude/skills/verification-discipline   # Claude Code
ln -s "$PWD/verification-discipline" ~/.agents/skills/verification-discipline   # Codex
```

**Three Skills ship a Codex host adapter** — `godot-architecture-review`, `refresh-context` and
`tournament`. A host adapter is a thin directory that reads the canonical body and states only
what its host needs differently (invocation spelling, tool surface, the fan-out surface). For
those three, point the Codex link at the adapter rather than the root directory:

```sh
ln -s "$PWD/refresh-context"              ~/.claude/skills/refresh-context
ln -s "$PWD/codex-skills/refresh-context" ~/.agents/skills/refresh-context
```

### The Chunk library

Chunks are not Skills and are not installed per-Skill. Run the bootstrap once per machine:

```sh
./bootstrap.sh          # PowerShell: ./bootstrap.ps1
```

It creates `~/.claude/chunks` and `~/.codex/chunks`, both pointing at this clone's `chunks/`. The
clone may live anywhere — the script takes the location from its own path. Claude Code resolves
`@~/.claude/chunks/<name>.md` imports from there; Codex has no `@import` syntax, so its
`AGENTS.md` names the files and reads them explicitly ([ADR 0005](docs/adr/0005-codex-chunks-use-explicit-read-directives.md)).

Chunk imports are *external includes*: Claude Code asks for approval once per consuming project
on first launch, and the session must be restarted before they load.

### The seat definitions

A third install surface, and the only one the verifier never sees. `agents/` holds one pinned agent
definition per seat and effort value, all for Claude Code — `implementer`, `advisor`,
`code-reviewer` and `coordinator`, plus a `-medium` or `-xhigh` suffix where a seat reaches another
value. Codex has no named seats; [`agents/README.md`](agents/README.md) says why. The definitions
install as one symlink each, exactly like a Skill; that README carries the seat table and the loop.

They matter more than their size suggests: a seat whose definition the host cannot resolve does
not fail, it dispatches on whoever spawned it. Check with `ls -l ~/.claude/agents`.

### Setting up a clone

Git hooks are opt-in per clone, so run this once after cloning:

```sh
git config core.hooksPath .githooks
```

That arms two things:

- **`leak-guard`** (`pre-commit`, `commit-msg`, `pre-push`) — blocks content that does not belong
  in a public repository. Run `.githooks/leak-guard.sh scan` by hand to audit the whole tree.
- **the backstop** (`post-checkout`, `post-merge`) — warns when a checkout or merge leaves the
  working tree behind `main`, because a clone of this repo is usually also a live Skill install:
  the entries under `~/.claude/skills` and `~/.agents/skills` are symlinks into it, so landing on
  an older ref silently changes what your agent reads.

`core.hooksPath` is local config and is not tracked. A fresh clone has no hooks until someone
sets it.

`skill-updater` is the only Skill here that ships a test suite for its own code. The suite needs
`pytest`, which a system `python3` usually cannot install into — run it from a virtualenv. The
exact command lives in [`skill-updater/SKILL.md`](skill-updater/SKILL.md), which is where it is
maintained; it is not repeated here.

## The Skills

### git-flow-squash

The default git-flow fork: integration is a local **squash-merge** to `main`, no PRs, no merge
commit. That last part is why the rest of it exists — with no merge commit to inspect afterwards,
the pause at the staged squash is the only review surface the change will ever get, so the Skill
spells out what has to be true at that moment. The three rules that ride the fork together —
squash-merge, the typed `<type>/<task id>` branch prefix, no commit SHA in the tracker notes — are
coupled by [ADR 0002](docs/adr/0002-git-flow-structural-fork.md) and must not be taken apart; a
fourth covers local review and the `main` push gate. Around them sit the measured footguns: the
squash carries the branch's final tree and nothing else, a sign-off approves a tree rather than a
branch name, a second writer can spill into `git status` between approval and merge, and `main`
held by another worktree is merged into without taking it. Other bodies cite the four as § (a) to
§ (d).

**When to use:** at task start when naming a branch, and at integration — before any squash-merge
to `main`, any push of `main`, any PR, or deleting a merged branch.

[`SKILL.md`](git-flow-squash/SKILL.md)

### godot-architecture-review

A convergent, re-runnable architecture review and refactor campaign for Godot projects — *A
Philosophy of Software Design* (deep modules, depth-as-leverage, information hiding) adapted so it
does not fight Godot's idioms. Each run leaves artifacts that make the next run cheaper and
quieter: re-runs find *less*, never loop, never re-raise settled items. One phase per fresh
session.

**When to use:** a Godot project needs an architecture review, a refactor or deepening campaign,
or you want to set up the review loop.

[`SKILL.md`](godot-architecture-review/SKILL.md) · Codex adapter: [`codex-skills/`](codex-skills/godot-architecture-review/SKILL.md)

### implement-batch

How the owner's delegate works tickets hands-off: the main session stands in for the owner, takes a
batch grant at kickoff, screens each ticket before it starts, and dispatches one `coordinator` seat
per ticket to run `implement-run`. The delegate answers a closed set of stops — the plan, the
Close approval, the caps, a slot-3 need, a false premise satisfied in form — and parks every other
one for the owner; a permission dialog is never its to answer. A failed landing check, a changed
instruction file, a dirty checkout and two consecutive parks are among the signals that end a batch.
Claude Code only; a project where neither the contract nor a host adapter imports the
`tracker-github` Chunk is out of scope. Slash-only.

**When to use:** working a frontier, or one ticket, hands-off while the owner is away.

[`SKILL.md`](implement-batch/SKILL.md)

### implement-run

How one ticket is actually run: the seats and what each one may not do (the coordinator writes no
diff, the gate-runner never wrote the diff it re-runs), the advisor's two slots, the review (native
axes, the bug hunter, the critic seat), and the closing run record under four fixed
headings. The seat boundaries are the point — a run where the writer also grades its own
output has no measurement in it, only a claim. It reads the project contract's
`knobs:implement-run` block by marker, so `shape`, `layout`, `gate_runner`, `advisor` and
`light_set` vary per project without the body changing. Named `implement-run` rather than
`implement` so it sits beside the third-party `/implement` stub instead of shadowing it
([ADR 0014](docs/adr/0014-floor-is-a-location.md)). Slash-only.

**When to use:** running one ticket end to end — dispatching implementers, consulting the advisor,
taking the review, writing the run record.

[`SKILL.md`](implement-run/SKILL.md)

### init-project

The single engine that scaffolds a project onto the Chunk library. Every project type
gets the same four files: `docs/agents/project-workflow.md`, the shared contract holding the
project's rules and the engine-written knob blocks, two thin host adapters over it — `CLAUDE.md`
carrying the chunk `@import`s and Claude Code mechanics, `AGENTS.md` naming the same chunks for
Codex to read ([ADR 0009](docs/adr/0009-init-project-emits-contract-and-two-adapters.md)) — and
`.claude/agents/gate-runner.md`, the seat that re-runs the verify gate for a coordinator that did
not write the diff ([ADR 0011](docs/adr/0011-roles-not-cost-tiers.md)). It also
stamps Templates, merges `settings.local.json`, and runs a project-type **Profile**'s bespoke
recipe. Adding a project type means adding a `profiles/<type>.md`; the engine never changes
([ADR 0003](docs/adr/0003-single-init-project-engine.md)). Ships `github`, `godot`, and `web`
Profiles.

**When to use:** setting up a new project, adopting the Chunk library in an existing one, or
adding a new project type.

[`SKILL.md`](init-project/SKILL.md)

### multi-agent-policy

Which capability role fills which seat in a multi-agent run. Two roles — **Planner** and
**Builder** — each defined by a property (does it draw on its own weekly meter?) rather than a
model name, so a model release does not silently invalidate the routing. Carries the pin rule
(every seat is a definition; a bare spawn inherits the parent), the meter check, effort by
definition — Builder-role seats `medium | high | xhigh` where their definitions reach, the
Planner-role advisor `high` only, and no seat dispatch passes `model` — and the rule that model
names live in run artifacts, as family aliases, and never in
durable prose ([ADR 0011](docs/adr/0011-roles-not-cost-tiers.md),
[ADR 0017](docs/adr/0017-seats-pin-family-aliases.md),
[ADR 0018](docs/adr/0018-run-profile-derived-from-plan.md)). The procedure an implementation run
follows is not here — it is the `implement-run` Skill, which is slash-only: a run loads it by name.

**When to use:** before a delegated implementation (even a single implementer), a review with
sub-agents, or any fan-out. Not for a single read-only sub-agent.

Two sibling files nothing loads by default: `WORKFLOWS.md` (Workflow-tool scripts, vendor
lenses, fan-out → verify discipline) and `COORDINATOR-PANE.md` (run shapes, interactive child
sessions, heartbeats, peer coordination). Hands-off execution is the `implement-batch` Skill.

[`SKILL.md`](multi-agent-policy/SKILL.md)

### parallel-work

What to do when more than one writer touches a repository. Two sessions sharing a checkout is the
failure the Skill exists to avoid, so it carries the tell and the git commands that silently
destroy a peer's uncommitted work. Beyond that, a decision rule picks between two modes, both
entered on an explicit signal only — **waves** (a dependency-free fan-out to background subagents)
and **attended worktrees** (a human driving two or more tasks hands-on). It also carries what a
worktree does *not* buy you: git writes in one fail under the sandbox, filesystem isolation is not
tool-state isolation, and a fresh interactive worktree inherits none of the gitignored host
config. Merge and Done are delegated to `git-flow-squash`.

**When to use:** when a checkout turns out to have a second writer, on an explicit parallel-work
signal — running 2+ tasks concurrently, fanning background subagents out over dependency-free
work — and before any `git worktree` setup.

[`SKILL.md`](parallel-work/SKILL.md)

### refresh-context

Creates or refreshes a project's `CONTEXT.md` domain glossary (and any ADRs) through a
docs-aware interview. A thin wrapper over `grilling` + `domain-modeling`, adding the four things
those do not do reliably: scope the change set from git, mine the existing docs, gate every entry
to glossary-only, and exit cleanly when nothing changed. Slash-only.

**When to use:** a project has no `CONTEXT.md`, or one that has drifted behind the code.

[`SKILL.md`](refresh-context/SKILL.md) · Codex adapter: [`codex-skills/`](codex-skills/refresh-context/SKILL.md)

### sandbox-and-permissions

Claude Code sandbox denials and permission-allowlist safety. The session-init baseline is a
one-line bullet in each project's Claude adapter; this Skill carries its shape, and what you need
once a denial actually fires, or you
are about to edit `permissions.allow` — where a broad glob silently disables a gate in every
session and every subagent.

**When to use:** a Bash or git command fails "Operation not permitted", a branch switch
half-completes and the next merge aborts, or before adding any permission entry.

[`SKILL.md`](sandbox-and-permissions/SKILL.md)

### codex-sandbox-and-approvals

The Codex sibling of the entry above, and the two disagree where it matters most: under Codex's
`workspace-write` the whole of `.git/` is read-only, so `git add`, `git commit` and `git checkout`
all fail 128 on a lock file, where Claude Code's sandbox lets a commit through. Codex has no
permission allowlist at all — it has an approval policy, and `codex exec` cannot escalate. Carries
the measured denial catalogue, the four sandbox-widening knobs, the project-trust gate, and a
side-by-side table of every point where a rule for one host is wrong on the other.

**When to use:** a command under Codex fails "Operation not permitted", a git write fails on
`index.lock`, the network looks down inside a session, or before widening a sandbox or reaching for
`--dangerously-bypass-approvals-and-sandbox`.

[`SKILL.md`](codex-sandbox-and-approvals/SKILL.md)

### skill-updater

Checks every installed Skill for upstream updates and installs them, across the two update
channels on a machine — Claude Code plugins (`claude plugin`) and agent-skills (`npx skills`, under
`~/.agents`) — and enumerates the third, Codex plugins (`codex plugin`), which has no update
command. Auto-applies updates from trusted sources and confirms community ones. Hand-authored
Skills are never touched. The deterministic work is in `scripts/skillsync.py`, which ships with a
pytest suite.

**When to use:** "check my skills for updates".

[`SKILL.md`](skill-updater/SKILL.md)

### spec-review

Fresh-context adversarial review of a spec before it fans out into tickets. A spec is the source
of a 1:1 mechanical fan-out, so a hole in it replicates into every ticket and nothing downstream
catches it. Three parallel subagent charters (blindspot sweep, reuse verification, cold read)
behind a decision fence, findings triaged as unverified upstream facts. Slash-only.

**When to use:** between writing a spec and breaking it into tickets, on any multi-session build.

[`SKILL.md`](spec-review/SKILL.md)

### stem-split

Splits a song into four production-ready stems (vocals, drums, bass, other) as 24-bit WAV, by
chaining **Mel-Band Roformer** for the vocal with **htdemucs_ft** for everything else — neither
tool gives both on its own. Verifies the source decodes before spending GPU on it, checks the
stems are full-length and non-empty, and writes detected BPM and key alongside them. Needs
`demucs`, `audio-separator` and `ffmpeg`; see [`TROUBLESHOOTING.md`](stem-split/TROUBLESHOOTING.md).

**When to use:** separating or extracting stems, isolating or removing vocals, producing an
acapella or an instrumental.

[`SKILL.md`](stem-split/SKILL.md)

### tournament

Turns a recurring "generate a bunch, judge them, pick and refine a winner" job into an editable,
reusable spec and a self-contained Workflow script. A code generator, not a library: the Workflow
runtime forbids several JS built-ins, so each run emits a fresh literal script, linted by
`reference/lint.mjs` before launch.

**When to use:** produce many candidates, screen and rank them, run a judge bracket, stress-test
the winner, synthesize a final answer.

[`SKILL.md`](tournament/SKILL.md) · Codex adapter: [`codex-skills/`](codex-skills/tournament/SKILL.md)
(no Workflow runtime there — the fan-out runs on `collaboration.spawn_agent`, and
`codex-skills/tournament/scripts/tourney.mjs` reconciles every stage's sent-vs-returned)

### unslop

Cuts AI tells from prose and rewrites it in a human voice — docs, READMEs, essays, release notes,
commit bodies. Not for code, logs, or terminal replies. **Vendored third-party work**, not
hand-authored: see [`PROVENANCE.md`](unslop/PROVENANCE.md) for its upstream, pinned commit and
local edits, and [`unslop/LICENSE`](unslop/LICENSE) for the notice that governs it.

**When to use:** "this reads like AI".

[`SKILL.md`](unslop/SKILL.md)

### verification-discipline

How to trust a measurement, and how to file a negative claim. Two failure families, both silent: a
bad instrument reports success, and a negative claim is false the moment anything outside your
review scope contradicts it. Neither produces an error signal, so both need a procedure.

**When to use:** before believing any post-fix number, benchmark or pass/fail verdict; before
writing a check, gate or eval harness; before claiming anything is dead, unused, untested or
absent; before a 1:1 fan-out from a source.

[`SKILL.md`](verification-discipline/SKILL.md)

## The Chunk library

A **Chunk** is a single-source dev-process instruction file in `chunks/`. Projects *reference* it
rather than copying it, so editing a Chunk here updates every consuming project at its next
launch ([ADR 0001](docs/adr/0001-import-from-home-chunk-delivery.md),
[ADR 0005](docs/adr/0005-codex-chunks-use-explicit-read-directives.md)). This is the opposite of a
**Template** (`init-project/templates/` for the four files every Profile emits,
`init-project/profiles/<type>/templates/` for a Profile's own assets), which is *copied* into a
project at init and thereafter diverges. The discriminator is one question: does the project edit the bytes after
delivery? No → Chunk. Yes → Template.

| Chunk | Covers |
|---|---|
| `dev-base.md` | The bundle every Profile imports; includes the four universal base Chunks below. |
| `git-sync-branch-start.md` | Sync main, then branch off it, at task start. |
| `git-commit-format.md` | Commit format and hygiene. |
| `git-confirm-destructive.md` | Confirm with a human before any hard-to-reverse or outward-facing git/gh action. |
| `verify-gate.md` | The gate to run before any commit or handoff. |
| `backlog-core.md` | Frozen: task tracking with backlog.md, kept for its existing importers; stamped by nothing, takes no edits. |
| `tracker-github.md` | Task tracking with GitHub Issues — gate and origin labels, no board. |

Per-project variation belongs in **knobs** (an engine-written tagged block in the project's
`CLAUDE.md`) or an **inline-leaf** (hand-authored, project-specific prose) — never in a Chunk.
`CONTEXT.md` defines all of these terms.

## Skills these bodies name

Bodies here — Skills, Profiles, Templates and seat definitions — name third-party Skills as
things an agent runs. They are not bundled; install the ones you want from their own repos. One
row per third-party Skill, because a body may name some of a repo's Skills and not others.

| Skill | Named by | Install from |
|---|---|---|
| `to-spec` | `spec-review`, `multi-agent-policy`, the `AGENTS.md` Template | [`mattpocock/skills`](https://github.com/mattpocock/skills) |
| `to-tickets` | `spec-review`, `multi-agent-policy`, the `github`/`godot` Profiles and their contract + issue-tracker Templates | [`mattpocock/skills`](https://github.com/mattpocock/skills) |
| `implement` | `multi-agent-policy`, `implement-run`, the `implementer` seat | [`mattpocock/skills`](https://github.com/mattpocock/skills) |
| `code-review` | `spec-review`, `implement-run`, the `code-reviewer` seat, the `github`/`godot` Profiles and their contract + issue-tracker Templates | [`mattpocock/skills`](https://github.com/mattpocock/skills) |
| `grilling` | `refresh-context` (both hosts), `godot-architecture-review`, `tournament`, `implement-run` | [`mattpocock/skills`](https://github.com/mattpocock/skills) |
| `grill-with-docs` | `multi-agent-policy`, `tournament` | [`mattpocock/skills`](https://github.com/mattpocock/skills) |
| `domain-modeling` | `refresh-context` (both hosts), `godot-architecture-review`, the `godot` Profile's domain Template | [`mattpocock/skills`](https://github.com/mattpocock/skills) |
| `codebase-design` | `godot-architecture-review` | [`mattpocock/skills`](https://github.com/mattpocock/skills) |
| `diagnosing-bugs` | `implement-run` | [`mattpocock/skills`](https://github.com/mattpocock/skills) |
| `prototype` | `implement-run` | [`mattpocock/skills`](https://github.com/mattpocock/skills) |
| `godot-gdscript-patterns` | `godot-architecture-review`, the `godot` Profile | [`wshobson/agents`](https://github.com/wshobson/agents) |

Derived, not stored: sweep the shipped bodies for each name, then read every hit — a
`wayfinder:grilling` label value and a JavaScript `Object.prototype` share a spelling with a Skill
and are not one.

Every one of these is optional. Where a body calls a Skill that may not be installed, the
reference is existence-gated and the step skips.

## Docs

- [`CONTEXT.md`](CONTEXT.md) — the domain glossary (Skill, Chunk, Template, Profile, knob,
  inline-leaf, …). Read it before renaming anything.
- [`CLAUDE.md`](CLAUDE.md) / [`AGENTS.md`](AGENTS.md) — operating notes for working *in* this
  repo.
- [`agents/README.md`](agents/README.md) — the seat definitions: which seat each file
  fills, how they install, and why editing one is live.
- [`docs/adr/`](docs/adr/) — the architecture decisions behind the above.

## License

MIT. See [LICENSE](LICENSE). `unslop/` is vendored third-party work and carries its own notice.
