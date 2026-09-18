# CLAUDE.md — agent-skills

Operating notes for working **in this repo**. For what each Skill is and how to install one, see
[`README.md`](README.md). For the vocabulary (Skill, Chunk, Template, Profile, knob, inline-leaf,
…) read [`CONTEXT.md`](CONTEXT.md) — it is not auto-loaded. Check [`docs/adr/`](docs/adr/) when a
decision in your area may already be settled.

This repository runs its own tickets under the same procedure it ships. Two imports carry it — the
implementation chunk, and this repository's own contract, which is hand-written rather than
engine-stamped and says why:

@~/.claude/chunks/implement-run.md
@docs/agents/project-workflow.md

The first is an external import, so it needs this project's one-time approval on a fresh session
before it expands ([ADR 0001](docs/adr/0001-import-from-home-chunk-delivery.md)); until then the
line is inert text, which looks identical to a loaded import. **A sub-agent has it worse**: this
file reaches a dispatched seat with both import lines *deleted*, so nothing marks the gap at all
(measured 2026-09-17 by having a seat quote back what it received). A seat that needs the
procedure or the knob values opens those two files itself.

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
  who has no such file will see that warning; it is expected, not a misconfiguration. **The
  guard sees only the git object store.** An issue body or comment written with `gh` on this
  public repository is never scanned, so grep the body file against both pattern lists before
  any `gh` write (39 identity hits landed in three public issues on 2026-09-17 that way).
  **Screen it through the guard rather than a hand-rolled grep** — copy the body into the tree,
  `scan`, delete — and plant the configured git author name first, which the guard blocks by each
  of its parts, so the list is known live before a clean result is believed. A `grep -f` over that
  file can apply none of its patterns and prints exactly what a clean body prints
  (`verification-discipline` § Prove the needle first; measured again 2026-09-18).
  **A calibration that plants a pattern's own text certifies nothing.** The identity entries
  reach `grep -E` as regexes and 43 of the 48 do not match their own text, so planting one raw
  read `scan clean` over the tree holding it (measured 2026-09-17 gating issue #4). A known-bad
  that fires has to be a string the regex *matches*: strip `\b`, take an alternation's first
  branch, and confirm the candidate with `grep -iqE -e <pattern>` before planting it.
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
updates every consuming project at next launch. A **Template** is *copied* into a project at init
and thereafter drifts: `init-project/templates/` holds the four files every Profile emits, which
no parity check reads at all, and `init-project/profiles/<type>/templates/` a Profile's own
assets, only some of which one does. Know which you are editing; `CONTEXT.md` has the
discriminator and the coverage.

**The `init-project` engine is generic.** Adding a project type means adding a
`profiles/<type>.md` Profile — plus, where the type has host specifics, its four `adapters:`
fragments — never editing the engine
([ADR 0003](docs/adr/0003-single-init-project-engine.md)). Every Profile emits the same four
files: the shared contract, two thin host adapters over it
([ADR 0009](docs/adr/0009-init-project-emits-contract-and-two-adapters.md)), and the project's
gate-runner seat ([ADR 0011](docs/adr/0011-roles-not-cost-tiers.md)).

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
