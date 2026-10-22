# agent-skills

Operating notes for working in this repo. What each Skill is and how to install one: `README.md`.
The vocabulary: `CONTEXT.md`. Settled decisions, including the retired ones: `docs/adr/`.

## The checkout is the install

Entries under `~/.claude/skills` and `~/.agents/skills` are symlinks into this clone. Editing a
`SKILL.md` changes what every host reads immediately, with no install step, so verify a change by
running it in a fresh session rather than by re-reading the file. The same holds on the git side:
leaving the working tree on a ref that lacks a Skill directory silently breaks that Skill. Do ref
surgery in a temporary worktree.

## Hooks

Opt-in per clone: `git config core.hooksPath .githooks`. That arms two things.

**`leak-guard`** (`pre-commit`, `commit-msg`, `pre-push`, and `scan` for the whole tree) blocks
personal provenance from entering this public repository: the owner's names, machine names and
private project names, from an identity list at `~/.config/agent-skills/identity-patterns` that
is not shipped here. Without that file the hooks run a built-in list and warn; `scan` fails
outright. Three things the guard cannot see:

- Anything written with `gh`. Screen an issue body by copying it into the tree, running `scan`,
  and deleting it. `.scratch/` is gitignored and the scan skips it, so a body drafted there reads
  clean whatever it contains.
- Its own liveness. Plant a known-bad beside the body in the same scan and read the match
  *count*: one hit is the canary, two is a real hit. Most identity patterns are regexes that do
  not match their own text, so build the canary from what the pattern matches, not from the
  pattern.
- A `Claude-Session` trailer. `commit-msg` strips one and warns; `pre-push` blocks one already
  committed. Commits here carry no attribution: `.claude/settings.json` is tracked and sets the
  attribution fields empty.

**The backstop** (`post-checkout`, `post-merge`) warns when the tree lands behind `main`. It
cannot fail the operation and cannot catch a lost uncommitted edit.

Exemptions go in `.leak-guard-allow` as `<path>:<literal>` with a reason. It starts empty; an
entry is a per-line owner decision, never a way to turn a red scan green.

## Conventions

- Everything here without a `PROVENANCE.md` is hand-authored. A directory carrying one is
  vendored third-party work ([ADR 0007](docs/adr/0007-vendor-unchanneled-third-party-skills.md));
  its `PROVENANCE.md` lists the local edits a manual upstream sync must re-apply. Today: `unslop/`.
- A Skill that names another Skill which may not be installed gates the step on that Skill's
  directory existing under `~/.claude/skills` or `~/.agents/skills`, and skips when it does not.
- Renaming or retiring a Skill means updating every live reference (other Skills, `README.md`,
  `CONTEXT.md`) and re-pointing its symlinks. Leave ADRs alone; they record what was decided when.
- `README.md`'s Skill roster is derived from the directories present. Re-derive it rather than
  editing a line.
- A Skill is prose an agent executes, so a change to one is verified by a fresh session following
  it against a throwaway target, never by re-reading the diff.
- Run `.githooks/leak-guard.sh scan` before any push.

## Working here

Verify command: `.githooks/leak-guard.sh scan`. There is no test suite. Work runs under the `build`
Skill from a brief in `docs/`; this repo keeps no tracker. Codex reviews here and does not build.
