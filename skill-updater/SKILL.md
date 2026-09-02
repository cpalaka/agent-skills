---
name: skill-updater
description: Check installed Claude skills for upstream updates and install them, across both ecosystems (Claude Code plugins and npx-skills agent-skills). Use when the user asks to check or update their skills, or invokes /skill-updater. Does NOT touch hand-authored personal skills.
---

# Skill Updater

Detects and installs updates for every installed skill across both ecosystems. The
deterministic work is done by the bundled `scripts/skillsync.py`; you orchestrate.

**Engine path:** `~/.claude/skills/skill-updater/scripts/skillsync.py`
(`python3` must be on PATH; `git`, `claude`, and `npx` are used by the engine.)

## Steps

### 1. Announce and detect

Tell the user you're checking both ecosystems and that this fetches from GitHub
(marketplace metadata + a shallow clone per agent-skill repo). Then run:

```bash
python3 ~/.claude/skills/skill-updater/scripts/skillsync.py detect --refresh
```

Parse the JSON. It has four keys: `plugins`, `skills`, `newSkills`, `errors`. Each
plugin/skill entry has `trusted` (bool), `updateAvailable` (bool), an identifier (`id`
for plugins, `name` for skills), `availableLabel`/`diffstat`, and an optional `note`.
Skill entries also carry `localTreeHash` and `localEdited`.

Two `note` values need a decision from the user (the rest are reported, not decided):
- **moved upstream** — the skill's folder moved in the source repo (e.g. out of
  `in-progress/`). `updateAvailable`/`diffstat` are computed against the NEW path, but
  `apply-skills` may not follow the move; the note carries the reinstall command
  (`npx skills@latest add <repo> -g -y --skill <name>`) that also fixes the lock path.
- **removed upstream** — the folder is gone from the source repo (often a rename;
  check `newSkills` for a likely successor). Nothing is auto-applied; ask the user
  whether to keep the frozen local copy or remove it
  (`npx skills@latest remove <name> -g -y`).

**`localEdited: true` — never update that skill.** Its folder no longer matches the tree
hash the lock recorded at install, so it was hand-edited in place. `npx skills update`
does `rm -rf` and recopies, so an update over a local edit destroys it silently: that is
data loss, not an update. Exclude every such skill from `apply-skills` — **trusted sources
included**, since trust says the upstream is safe, not that the local edit is expendable —
and report each one by name:

> `<name>` has local edits and was NOT updated. Inspect them with
> `python3 ~/.claude/skills/skill-updater/scripts/skillsync.py diff-skill <name>`, then
> re-home the edit (upstream, or into a personal skill) before updating.

`localEdited: false` is pristine. A root-repo skill (one whose `skillPath` is `SKILL.md` at
the repo root) reports `false` with a `note` saying the check doesn't apply to it. `null` means
there was no usable baseline to compare against (legacy entries) — say that, rather than
reporting it as pristine.

`newSkills` lists upstream skills with no local install, each with an `installCmd`.
Only repos the user tracks wholesale (>= half the repo's skills installed) are scanned,
so cherry-picked catalog repos don't flood this list. Before offering an install, check
the name doesn't collide with an already-installed skill from a DIFFERENT source repo
(`~/.agents/.skill-lock.json`) — flag collisions instead of installing over them.

If every entry has `updateAvailable: false`, `newSkills` is empty, and `errors` is
empty, report "✓ All skills are up to date" and stop.

Always surface anything in `errors` (e.g. a repo that failed to clone) — report it but
keep going with what succeeded.

### 2. Auto-apply trusted updates

Collect the trusted entries with `updateAvailable: true` and `localEdited` not `true`:

- **Plugins** (`trusted: true`): for each, run
  `python3 ~/.claude/skills/skill-updater/scripts/skillsync.py apply-plugin <id>`.
- **Skills** (`trusted: true`): collect their `name`s and run ONE batched call:
  `python3 ~/.claude/skills/skill-updater/scripts/skillsync.py apply-skills <name1> <name2> ...`.

Record each result (success/failure from exit code and output).

### 3. Confirm community updates

For the entries with `updateAvailable: true`, `trusted: false` and `localEdited` not
`true`, present them to the user with their source and `diffstat`/`availableLabel`. Use
the `AskUserQuestion` tool with `multiSelect: true` so the user can pick which to apply.
Include the option to see a full diff first — if asked, run for that skill:

```bash
python3 ~/.claude/skills/skill-updater/scripts/skillsync.py diff-skill <name>
```

(Plugin community updates have no per-file diff; present them by
version/`availableLabel` and confirm the same way.)

Apply only the chosen ones using the same `apply-plugin` / `apply-skills` commands as
Step 2.

In the same confirmation, present the `newSkills` entries (with source and path) and any
moved/removed-upstream skills, and apply the user's picks with each entry's
`installCmd` / the note's reinstall or remove command. New installs and moves/removals
are ALWAYS confirmed, even from trusted sources — trusted auto-apply covers only
in-place updates to skills the user already chose to install.

### 4. Report

Summarize grouped by ecosystem: what was applied, skipped (declined or held back for
local edits — name those, with the `diff-skill` command), and failed. Then
end with this note verbatim:

> **Restart Claude Code (or start a new session) to load the updated skills.** Plugin
> updates explicitly require a restart; agent-skills are loaded at session start.

## Notes

- **Never touches personal skills.** A skill is managed by this engine only if it has a row in
  `~/.agents/.skill-lock.json` **and** its `~/.claude/skills/<name>` entry resolves under
  `~/.agents/skills/`. Everything else — hand-authored or vendored — is invisible to the engine by
  construction (`skillsync.py detect_skills()` iterates `lock.get("skills", {})` and nothing else).
  **"Is it a symlink?" is NOT the test** — hand-authored skills are usually symlinks too, into a
  local checkout of the repo that authors them (measured on one maintainer install, 2026-09-01:
  19 of its 21 out-of-scope entries were symlinks, and none had a lock row — your own numbers will
  differ, the shape will not). Check the lock row and the symlink *target*, never the symlink-ness.
- **Trusted vs. community** is defined in `~/.claude/skills/skill-updater/trusted-sources.json`.
  To promote a source to auto-apply, add its marketplace name to `marketplaces` or its
  `owner/*` glob to `repos`.
- Set `GITHUB_TOKEN` in the environment to avoid GitHub rate limits on the clones.
- **The engine needs only `python3`; the suite needs `pytest`, which a system `python3` often
  refuses to install.** From this directory:
  `python3 -m venv .venv && .venv/bin/pip install pytest && .venv/bin/python -m pytest scripts/`.
