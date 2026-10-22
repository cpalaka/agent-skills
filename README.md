# agent-skills

Hand-authored Skills for [Claude Code](https://docs.claude.com/en/docs/claude-code/overview), each
one a document you can read in one sitting. Most exist because something failed silently once and
the fix had to be written down. Codex reads them too where its `.agents/skills` root is linked at
the same directories.

A Skill is a `SKILL.md` (plus supporting files) that an agent host loads: implicitly when the
context matches its `description`, or explicitly as `/skill-name` in Claude Code and
`$skill-name` in Codex. Nothing here is a framework.

## Install

Per Skill, through the [`skills` CLI](https://github.com/vercel-labs/skills):

```sh
npx skills add cpalaka/agent-skills -s verification-discipline
```

Repeat `-s` for each Skill you want; it takes several in one invocation.

Or clone once and symlink whichever Skills you want into your host's user skills directory. This
is what the author's own machines do, so a change in the clone is live in every host with no
reinstall step:

```sh
git clone https://github.com/cpalaka/agent-skills.git
cd agent-skills

ln -s "$PWD/verification-discipline" ~/.claude/skills/verification-discipline   # Claude Code
ln -s "$PWD/verification-discipline" ~/.agents/skills/verification-discipline   # Codex
```

### Setting up a clone

Git hooks are opt-in per clone, so run this once after cloning:

```sh
git config core.hooksPath .githooks
```

That arms two things:

- **`leak-guard`** (`pre-commit`, `commit-msg`, `pre-push`): blocks content that does not belong
  in a public repository. Run `.githooks/leak-guard.sh scan` by hand to audit the whole tree.
- **the backstop** (`post-checkout`, `post-merge`): warns when a checkout or merge leaves the
  working tree behind `main`, because a clone of this repo is usually also a live Skill install:
  the entries under `~/.claude/skills` and `~/.agents/skills` are symlinks into it, so landing on
  an older ref silently changes what your agent reads.

`core.hooksPath` is local config and is not tracked. A fresh clone has no hooks until someone
sets it.

## The Skills

### build

The one process Skill. Starts a build session from a brief in `docs/`: numbered milestones, each
with a done check, built in order, each closed by the done check plus the project's verify command
and committed with the milestone in the subject. Kept repos take a branch per ticket and squash
locally; throwaways commit on `main`. A wrong brief is fixed in place, never guessed around. It
replaces a spec → tickets → implement chain with one file the owner already writes. Slash-only.

**When to use:** at the start of any build session, once the brief exists.

[`SKILL.md`](build/SKILL.md)

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

[`SKILL.md`](godot-architecture-review/SKILL.md)

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

[`SKILL.md`](refresh-context/SKILL.md)

### sandbox-and-permissions

Claude Code sandbox denials and permission-allowlist safety. The session-init baseline is a
one-line bullet in each project's Claude adapter; this Skill carries its shape, and what you need
once a denial actually fires, or you
are about to edit `permissions.allow` — where a broad glob silently disables a gate in every
session and every subagent.

**When to use:** a Bash or git command fails "Operation not permitted", a branch switch
half-completes and the next merge aborts, or before adding any permission entry.

[`SKILL.md`](sandbox-and-permissions/SKILL.md)

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

## Skills these bodies name

Bodies here name third-party Skills as things an agent runs. They are not bundled; install the
ones you want from their own repos.

| Skill | Named by | Install from |
|---|---|---|
| `grilling` | `refresh-context`, `godot-architecture-review` | [`mattpocock/skills`](https://github.com/mattpocock/skills) |
| `domain-modeling` | `refresh-context`, `godot-architecture-review` | [`mattpocock/skills`](https://github.com/mattpocock/skills) |
| `codebase-design` | `godot-architecture-review` | [`mattpocock/skills`](https://github.com/mattpocock/skills) |
| `godot-gdscript-patterns` | `godot-architecture-review` | [`wshobson/agents`](https://github.com/wshobson/agents) |

Derived, not stored: sweep the shipped bodies for each name. Every one of these is optional; where
a body calls a Skill that may not be installed, the step skips.

## History

Until October 2026 this repository also shipped a spec-to-tickets-to-implementation pipeline
(`implement-run`, `implement-batch`, `multi-agent-policy`, `tracker-github`, `spec-review`), a
Chunk library of imported dev-process rules, pinned subagent seat definitions, and the
`init-project` engine that stamped projects onto all of it. They were retired in favour of the
`build` Skill and a brief per project; `git log` before that date has every file, and
[`docs/adr/`](docs/adr/) keeps the decisions as they were made.

## Docs

- [`CONTEXT.md`](CONTEXT.md): the domain glossary. Read it before renaming anything.
- [`AGENTS.md`](AGENTS.md): operating notes for working *in* this
  repo.
- [`docs/adr/`](docs/adr/): the architecture decisions, including the retired ones.

## License

MIT. See [LICENSE](LICENSE). `unslop/` is vendored third-party work and carries its own notice.
