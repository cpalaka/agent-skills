# Godot 4.x Gotchas — project-local

> This file holds only gotchas bound to *this* project's own code, scenes, assets, or
> param-tuning. If the `godot-gotchas` skill is installed (its directory exists under
> `~/.claude/skills` or `~/.agents/skills` — Claude Code and Codex resolve Skills through
> different roots, so a gate that checks one skips the step for every consumer on the other
> host), **universal** Godot / godot-ai / godot-mcp / GDScript / tooling / addon gotchas live
> there instead, as the single source, and are never copied here. Otherwise skip that split and
> keep every gotcha in this file, marking the universal ones as such.

When you hit a new gotcha, classify it:

- **Universal** — reproduces on any Godot project given the same engine / tooling / addon →
  file it in the `godot-gotchas` skill (its "Adding new gotchas" section) if that skill is
  installed (its directory exists under `~/.claude/skills` or `~/.agents/skills`); otherwise
  skip that step and append it below, marked universal.
- **Project-local** — bound to this project's own code/scenes/assets/tuning → append it below.
- A *convention* (axis-flip, naming, a design rule) is not a gotcha → record it as a `docs/adr/`
  entry.

Entry shape: **Symptom → Cause → Fix** (optional: Detect proactively / Confirmed by).

---

## (No project-local gotchas yet)
