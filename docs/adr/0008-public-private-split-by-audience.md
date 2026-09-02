# 8. The Skill library is split into two repos by audience, not by kind

## Status
Accepted — 2026-09-01.

## Context
One repository held every hand-authored Skill, the Chunk library, and the `init-project` engine.
Most of that is general-purpose and worth publishing; some of it is only meaningful on the
author's own machines — it names private projects, local paths, and machine-specific tooling.
Publishing the repo whole was not an option, and neither was scrubbing the machine-specific
Skills into uselessness.

## Decision
Two repositories, split by **audience**:

- **this repo** (`cpalaka/agent-skills`, public) — the general-purpose Skills, the Chunk library,
  the `init-project` engine and its Profiles, the Codex host adapters, and the Codex session-start
  bridge script.
- a **private companion repo**, which the author keeps for Skills that are only useful on their own
  machines. It installs exactly the same way: one symlink per Skill per host.

Each repo is single-source for the Skills it owns. Nothing is mirrored between them, and no Skill
body exists in both. A Skill is installed by symlinking its directory into the host's user skills
directory (`~/.claude/skills` for Claude Code, `~/.agents/skills` for Codex) from whichever repo
owns it, so the two repos coexist in one install surface without either knowing about the other.

**This repo owns the Chunk library.** That amends ADR 0001's consequence, which now reads: every
project's `CLAUDE.md` is incomplete without *this* repo cloned and linked on that machine.

**ADRs duplicate across the repos as records.** An ADR is a record of a decision, not a procedure
that has to run in one place, so the decisions governing public content are copied here, keeping
their original numbers. From 0009 each repo numbers independently; a decision that governs both is
recorded here and referenced from the private one by URL.

**The private repo is the default home for anything unclassified.** New material is private until
someone decides it is public — the safe direction, since the other default leaks by inaction.

## Consequences
A public artifact may not hard-require a private one. Where public content wants to call a private
Skill, the reference is **existence-gated**: it checks whether the Skill's directory exists under
`~/.claude/skills` or `~/.agents/skills` (the two hosts resolve Skills through different roots, so
a gate testing only one would silently skip for the other host's users) and otherwise skips the
step. A gate on only one root would skip the step for every Codex consumer on a machine where the
Skill is installed.

A consuming project's dev-process rules now resolve into a *public* repo. Per-project variation
must therefore continue to live in knobs and inline-leaves, never in a Chunk — a Chunk that grows
one project's specifics publishes them.

Two clones and two `core.hooksPath` settings to arm instead of one, and a decision to make for
each new Skill about which repo it belongs to. The default answer (private) makes that decision
cheap to defer and safe to get wrong.
