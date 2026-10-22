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
npx skills add cpalaka/agent-skills -s claude-code-gotchas
```

Repeat `-s` for each Skill you want; it takes several in one invocation.

Or clone once and symlink whichever Skills you want into your host's user skills directory. This
is what the author's own machines do, so a change in the clone is live in every host with no
reinstall step:

```sh
git clone https://github.com/cpalaka/agent-skills.git
cd agent-skills

ln -s "$PWD/claude-code-gotchas" ~/.claude/skills/claude-code-gotchas   # Claude Code
ln -s "$PWD/claude-code-gotchas" ~/.agents/skills/claude-code-gotchas   # Codex
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

### claude-code-gotchas

Claude Code failures that report success, one symptom per row: the sandbox's two `$TMPDIR`s and
denied heredocs, the harness `grep`, squash-merges that drop a peer's commit, subagents that
inherit the parent's model, oracles that say success while nothing happened, permission rules
that match a `grep` pattern. Each row carries its cause and fix; the ten fixes longer than a line
have recipes in `RECIPES.md`. Model-invoked: it fires before a squash-merge, a subagent dispatch, an
absence claim, or trusting a clean reading from a sandboxed command.

**When to use:** a command behaves unexpectedly under Claude Code, or before any of the four
moments the description names.

[`SKILL.md`](claude-code-gotchas/SKILL.md)

### godot-architecture-review

A convergent, re-runnable architecture review and refactor campaign for Godot projects — *A
Philosophy of Software Design* (deep modules, depth-as-leverage, information hiding) adapted so it
does not fight Godot's idioms. Each run leaves artifacts that make the next run cheaper and
quieter: re-runs find *less*, never loop, never re-raise settled items. One phase per fresh
session.

**When to use:** a Godot project needs an architecture review, a refactor or deepening campaign,
or you want to set up the review loop.

[`SKILL.md`](godot-architecture-review/SKILL.md)

### refresh-context

Creates or refreshes a project's `CONTEXT.md` domain glossary (and any ADRs) through a
docs-aware interview. A thin wrapper over `grilling` + `domain-modeling`, adding the four things
those do not do reliably: scope the change set from git, mine the existing docs, gate every entry
to glossary-only, and exit cleanly when nothing changed. Slash-only.

**When to use:** a project has no `CONTEXT.md`, or one that has drifted behind the code.

[`SKILL.md`](refresh-context/SKILL.md)

### unslop

Cuts AI tells from prose and rewrites it in a human voice — docs, READMEs, essays, release notes,
commit bodies. Not for code, logs, or terminal replies. **Vendored third-party work**, not
hand-authored: see [`PROVENANCE.md`](unslop/PROVENANCE.md) for its upstream, pinned commit and
local edits, and [`unslop/LICENSE`](unslop/LICENSE) for the notice that governs it.

**When to use:** "this reads like AI".

[`SKILL.md`](unslop/SKILL.md)

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
`build` Skill and a brief per project. Four lesson Skills went with them (`verification-discipline`,
`sandbox-and-permissions`, `git-flow-squash`, `parallel-work`), condensed into the symptom table of
`claude-code-gotchas`. `git log` before that date has every file, and [`docs/adr/`](docs/adr/) keeps
the decisions as they were made.

## Docs

- [`CONTEXT.md`](CONTEXT.md): the domain glossary. Read it before renaming anything.
- [`AGENTS.md`](AGENTS.md): operating notes for working *in* this
  repo.
- [`docs/adr/`](docs/adr/): the architecture decisions, including the retired ones.

## License

MIT. See [LICENSE](LICENSE). `unslop/` is vendored third-party work and carries its own notice.
