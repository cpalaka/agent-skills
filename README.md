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

**Two Skills ship a Codex host adapter** — `godot-architecture-review` and `refresh-context`. A
host adapter is a thin directory that reads the canonical body and states only what its host
needs differently (invocation spelling, tool surface). For those two, point the Codex link at the
adapter rather than the root directory:

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

### godot-architecture-review

A convergent, re-runnable architecture review and refactor campaign for Godot projects — *A
Philosophy of Software Design* (deep modules, depth-as-leverage, information hiding) adapted so it
does not fight Godot's idioms. Each run leaves artifacts that make the next run cheaper and
quieter: re-runs find *less*, never loop, never re-raise settled items. One phase per fresh
session.

**When to use:** a Godot project needs an architecture review, a refactor or deepening campaign,
or you want to set up the review loop.

[`SKILL.md`](godot-architecture-review/SKILL.md) · Codex adapter: [`codex-skills/`](codex-skills/godot-architecture-review/SKILL.md)

### init-project

The single engine that scaffolds (or migrates) a project onto the Chunk library — it writes the
chunk `@import`s, the knob blocks, stamps Templates, merges `settings.local.json`, and runs a
project-type **Profile**'s bespoke recipe. Adding a project type means adding a
`profiles/<type>.md`; the engine never changes ([ADR 0003](docs/adr/0003-single-init-project-engine.md)).
Ships `backlog`, `web`, and `godot` Profiles.

**When to use:** setting up a new project, adopting the Chunk library in an existing one, or
adding a new project type.

[`SKILL.md`](init-project/SKILL.md)

### multi-agent-policy

Model/effort tiers and orchestration procedure for multi-agent work — per-stage pins,
severity-tiered verification, fan-out → verify discipline, the orchestrator-delegate procedure,
peer-session coordination, and the stale-cache gotchas. Names capability *tiers* (`workhorse` /
`budget` / `scarce`) rather than model names, so it survives model churn.

**When to use:** before any subagent spawn, workflow, fan-out, adversarial review, tournament, or
orchestrator-delegate handoff; when reconciling a fan-out's results; when sharing a live system
with a peer session; and before dispatching an external vendor lens.

[`SKILL.md`](multi-agent-policy/SKILL.md)

### refresh-context

Creates or refreshes a project's `CONTEXT.md` domain glossary (and any ADRs) through a
docs-aware interview. A thin wrapper over `grilling` + `domain-modeling`, adding the four things
those do not do reliably: scope the change set from git, mine the existing docs, gate every entry
to glossary-only, and exit cleanly when nothing changed. Slash-only.

**When to use:** a project has no `CONTEXT.md`, or one that has drifted behind the code.

[`SKILL.md`](refresh-context/SKILL.md) · Codex adapter: [`codex-skills/`](codex-skills/refresh-context/SKILL.md)

### sandbox-and-permissions

Claude Code sandbox denials and permission-allowlist safety. The `sandbox-auto` Chunk carries the
session-init baseline; this Skill carries what you need only once a denial actually fires, or you
are about to edit `permissions.allow` — where a broad glob silently disables a gate in every
session and every subagent.

**When to use:** a Bash or git command fails "Operation not permitted", a branch switch
half-completes and the next merge aborts, or before adding any permission entry.

[`SKILL.md`](sandbox-and-permissions/SKILL.md)

### skill-updater

Checks every installed Skill for upstream updates and installs them, across both ecosystems on a
machine — Claude Code plugins (`claude plugin`) and agent-skills (`npx skills`, under
`~/.agents`). Auto-applies updates from trusted sources and confirms community ones. Hand-authored
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

[`SKILL.md`](tournament/SKILL.md)

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
**Template** (`init-project/profiles/<type>/templates/`), which is *copied* into a project at init
and thereafter diverges. The discriminator is one question: does the project edit the bytes after
delivery? No → Chunk. Yes → Template.

| Chunk | Covers |
|---|---|
| `dev-base.md` | The bundle every Profile imports; recursively includes seven universal base Chunks. |
| `dev-practice.md` | Dev practice defaults — planning, diagnosis, TDD, browser QA. |
| `code-hygiene.md` | What's off-limits in code, and when to ask. |
| `verify-gate.md` | The gate to run before any commit or handoff. |
| `git-commit-format.md` | Commit format and hygiene. |
| `git-sync-branch-start.md` | Sync main, then branch off it, at task start. |
| `git-flow-squash.md` / `git-flow-noff.md` | The two git-flow variants — squash is the default, `--no-ff` is opt-in ([ADR 0002](docs/adr/0002-git-flow-structural-fork.md)). |
| `git-confirm-destructive.md` | Confirm with a human before any hard-to-reverse or outward-facing git/gh action. |
| `backlog-core.md` | Task tracking with backlog.md. |
| `parallel-work.md` | Parallel work — waves and solo worktrees. |
| `sandbox-auto.md` | Sandbox session-init baseline (see the `sandbox-and-permissions` Skill for denials). |
| `codegraph.md` | Code intelligence — opt-in and self-gating on `.codegraph/`. |

Per-project variation belongs in **knobs** (an engine-written tagged block in the project's
`CLAUDE.md`) or an **inline-leaf** (hand-authored, project-specific prose) — never in a Chunk.
`CONTEXT.md` defines all of these terms.

## Skills these bodies name

Several Skills here delegate to third-party Skills by name. They are not bundled; install the
ones you want from their own repos.

| Named by | Skill | Install from |
|---|---|---|
| `spec-review`, `multi-agent-policy` | `to-spec`, `to-tickets`, `implement`, `code-review`, `tdd` | [`mattpocock/skills`](https://github.com/mattpocock/skills) |
| `refresh-context`, `godot-architecture-review`, `tournament`, `chunks/dev-practice.md` | `grilling`, `grill-with-docs`, `domain-modeling`, `codebase-design`, `diagnosing-bugs`, `prototype` | [`mattpocock/skills`](https://github.com/mattpocock/skills) |
| `godot-architecture-review`, the `godot` Profile | `godot-gdscript-patterns` | [`wshobson/agents`](https://github.com/wshobson/agents) |

Every one of these is optional. Where a body calls a Skill that may not be installed, the
reference is existence-gated and the step skips.

## Docs

- [`CONTEXT.md`](CONTEXT.md) — the domain glossary (Skill, Chunk, Template, Profile, knob,
  inline-leaf, …). Read it before renaming anything.
- [`CLAUDE.md`](CLAUDE.md) / [`AGENTS.md`](AGENTS.md) — operating notes for working *in* this
  repo.
- [`docs/adr/`](docs/adr/) — the architecture decisions behind the above.

## License

MIT. See [LICENSE](LICENSE). `unslop/` is vendored third-party work and carries its own notice.
