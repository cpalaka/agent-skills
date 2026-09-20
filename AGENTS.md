# Codex repository instructions

Before changing this repository, read [CLAUDE.md](CLAUDE.md), [CONTEXT.md](CONTEXT.md), and any
relevant decision in [docs/adr/](docs/adr/). `CLAUDE.md` is the canonical operating guide and
carries the load-bearing facts in full — the checkout-is-the-install rule, the two opt-in hooks,
the leak-guard's identity file, the no-attribution commit policy, and the existence gate on
private Skills. This file is the Codex entry point, not a duplicate of it.

**Read three more files before running a ticket here**, since Codex expands no import directives:
`docs/agents/project-workflow.md` (this repository's contract — the knob values for both chunks
below, and its own rules: the wrap-commit push carve-out and the playthrough that closes a prose
deliverable), `~/.codex/chunks/implement-run.md` (the procedure the `implement-run` knobs
configure) and `~/.codex/chunks/tracker-github.md` (the tracker convention the `tracker-github`
knobs configure). `CLAUDE.md` reaches all three by `@import`, the last one nested inside the
contract; on this host the read is the mechanism.

This repository is the canonical source for the Skills and Chunks it contains. Claude Code
discovers Skills through `~/.claude/skills/`; Codex discovers them through `~/.agents/skills/`.
Preserve both hosts, and prefer symlinks back to this repository over copied Skill bodies.

Codex reads Chunks through `~/.codex/chunks`, not `~/.claude/chunks`, and it does not expand
Claude Code's recursive `@path` import syntax — a Codex `AGENTS.md` names the Chunk files and
reads them explicitly ([ADR 0005](docs/adr/0005-codex-chunks-use-explicit-read-directives.md)).
When a Chunk's own `@` lines list children, read every listed child completely and resolve
`~/.claude/chunks/<name>` as `~/.codex/chunks/<name>`.

Codex invokes Skills as `$skill-name`. Claude Code's `/skill-name` spelling in a body here is
source-host notation; do not mechanically rewrite it. When a body names another Skill as
`/skill-name`, load the corresponding `$skill-name` in Codex, and never send the slash form to the
Codex CLI.

Two Skills ship a Codex host adapter under `codex-skills/`. An adapter reads its canonical body
and states only what its host needs differently; it must never copy the procedure.

The hooks are armed per clone with `git config core.hooksPath .githooks`, and `leak-guard` blocks
personal provenance from entering this public repository. Run `.githooks/leak-guard.sh scan`
before a push.

Do not stage, commit, or push changes unless the user explicitly requests it. This working tree
may already contain the user's changes; preserve them and keep them distinct from the current
task's edits.
