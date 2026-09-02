# CLAUDE.md — agent-skills

Operating notes for working **in this repo**. For what each Skill is and how to install one, see
[`README.md`](README.md). For the vocabulary (Skill, Chunk, Template, Profile, knob, inline-leaf,
…) read [`CONTEXT.md`](CONTEXT.md) — it is not auto-loaded. Check [`docs/adr/`](docs/adr/) when a
decision in your area may already be settled.

## Load-bearing facts

**Editing a file here is live.** This clone is usually also the install: entries under
`~/.claude/skills` and `~/.agents/skills` symlink *into* it, and `~/.claude/chunks` /
`~/.codex/chunks` point at `chunks/`. A change to a `SKILL.md`, a Chunk, or a host adapter changes
what the agent reads immediately — there is no install step, so verify a change in every affected
host rather than by re-reading the file. The same mechanism applies on the git side: **the
checkout is the install**, so leaving the working tree on a ref that lacks a Skill directory
silently breaks that Skill with no error. Do ref surgery in a temporary worktree.

**The hooks are opt-in per clone.** `git config core.hooksPath .githooks` arms both of them, and
that is local config, not tracked — a fresh clone has neither until someone sets it.

- **`leak-guard`** (`pre-commit`, `commit-msg`, `pre-push`, plus a `scan` mode for the whole tree)
  blocks personal provenance from entering a public repository. It runs two pattern sources: a
  built-in, identity-free list that ships here, and an **identity list that does not** — the
  author's names, machine names and private project names. The guard finds that file through
  `AGENT_SKILLS_IDENTITY_FILE`, defaulting to `~/.config/agent-skills/identity-patterns`. If it is
  missing, the hook modes still run the built-in list but warn loudly, and `scan` **fails**
  outright, because an import audit on the built-in list alone certifies nothing. A contributor
  who has no such file will see that warning; it is expected, not a misconfiguration.
- **the backstop** (`post-checkout`, `post-merge`) warns when a checkout or merge leaves the tree
  behind `main`, for the checkout-is-the-install reason above. Neither hook can fail a checkout or
  a merge, and neither catches a lost uncommitted edit — they diff after the fact.

**Exemptions are an owner decision.** `.leak-guard-allow` takes one `<path>:<literal>` pair per
line with a required reason, never a line number. It starts empty and should stay that way; an
entry is a per-line judgment, not a way to turn a red scan green.

**Commits here carry no attribution and no session trailer.** `.claude/settings.json` is tracked
on purpose and sets `attribution.commit` and `attribution.pr` empty and `attribution.sessionUrl`
false, so the policy holds on any machine rather than depending on one user's settings. The
`commit-msg` hook strips a `Claude-Session` trailer that arrives anyway and warns — a stripped
trailer is a regression signal, not a failed commit — and `pre-push` blocks one already committed.
Check `git log -1 --format=%B` after the first commit in a fresh clone.

**Everything here without a `PROVENANCE.md` is hand-authored.** A directory carrying one is a
vendored third-party body kept here because its upstream ships no install channel
([ADR 0007](docs/adr/0007-vendor-unchanneled-third-party-skills.md)); its `PROVENANCE.md` lists
local edits that a manual upstream sync must re-apply. Today that is `unslop/` alone.

**Chunk vs Template.** A **Chunk** (`chunks/`) is single-source and referenced — editing it
updates every consuming project at next launch. A **Template**
(`init-project/profiles/<type>/templates/`) is *copied* into a project at init and thereafter kept
aligned by a parity check. Know which you are editing; `CONTEXT.md` has the discriminator.

**The `init-project` engine is generic.** Adding a project type means adding a
`profiles/<type>.md` Profile, never editing the engine
([ADR 0003](docs/adr/0003-single-init-project-engine.md)).

**No public artifact may hard-require a private one.** Where a body calls a Skill that may not be
installed, the reference is existence-gated on the Skill's directory existing under *either*
`~/.claude/skills` *or* `~/.agents/skills` — Claude Code and Codex resolve Skills through
different roots, so a gate on one silently skips the step for the other host's users. The step
skips when the gate fails; it never errors.

**A private companion repo exists.** The author keeps Skills that are only meaningful on their own
machines in a separate private repository; it installs the same way, one symlink per Skill per
host, and nothing here depends on it ([ADR 0008](docs/adr/0008-public-private-split-by-audience.md)).

## Conventions

- Renaming or retiring a Skill means updating every live reference (other Skills, `README.md`,
  `CONTEXT.md`, the `init-project` Templates and Profiles) and re-pointing its
  `~/.claude/skills` / `~/.agents/skills` symlinks. Leave historical records alone — an ADR
  records what was decided when, and rewriting it to chase a rename destroys the record.
- `README.md`'s Skill roster is **derived** from the directories present, not stored. Re-derive it
  rather than editing a line.
- Both bootstrap scripts take the clone location from their own path. Nothing here may assume
  where the clone lives.
- Run `.githooks/leak-guard.sh scan` before a push you care about, not only on the hook path.
