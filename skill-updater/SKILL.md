---
name: skill-updater
description: Check installed skills and plugins for upstream updates and apply them. Use when asked to update or check skills, or to find what is out of date.
---

# Skill Updater

Brings lock-managed skills and plugins up to date and reports everything else.
`scripts/skillsync.py` in this skill's directory (`ENGINE` below) does the deterministic work and
gives every entry an `action`. You run it, take the user's picks, and relay its verdicts.

Running under Codex: read [`CODEX.md`](CODEX.md) first.

## Sources

Name every row in the report, including the ones with nothing to do.

| Source | Where | Treatment |
|---|---|---|
| Lock-managed skills | `~/.agents/.skill-lock.json`, `~/.agents/skills/` | Detected and applied |
| Claude Code plugins | `~/.claude/plugins/` | Detected and applied; `directory-managed` ones refresh themselves, so listed only |
| Personal and vendored skills | Symlinks into git checkouts | Reported in `personalRepos`; the owner pulls |
| Codex plugins | `~/.codex/plugins/` | Listed in step 1; "skipped: no codex CLI" when `codex` is off PATH |
| Account-synced and built-in skills | `~/.claude/{skills,plugins}/synced/`, Claude Code itself | Delivered by the claude.ai account and by Claude Code releases; nothing to update here |

## Steps

### 1. Detect

Say that this fetches from GitHub, then run:

```bash
python3 ENGINE detect --refresh
```

When `codex` is on PATH, also run the listing command in [`CODEX.md`](CODEX.md). Complete when you
hold the JSON and the listing, and have queued every `errors` line for the report. When every
`action` is `none` and `newSkills` and `errors` are empty, go straight to step 5.

### 2. Sort by `action`

| `action` | Meaning | What to do |
|---|---|---|
| `none` | Current, or nothing to compare | Count it in the report |
| `auto` | Trusted source, local folder verified | Apply in step 3 without asking |
| `confirm` | Community source, or moved or removed upstream | Ask in step 3 |
| `hold-edited` | The folder matches no upstream version: a hand edit | Report by name with `python3 ENGINE diff-skill <name>`, so the edit can be re-homed before updating |
| `hold-unverified` | No lock baseline, or the skill is a whole repo | Report by name with the `--force` command for the user to run once they have looked |

A `stale:` note means the installer left the folder on an older upstream version. No edit is at
risk, and the update repairs it. Complete when every entry has a bucket.

### 3. Apply

**`auto`**, with no prompt:

```bash
python3 ENGINE apply-plugin <id>                # once per plugin
python3 ENGINE apply-skills <name> <name> ...   # all skills in one call
```

**`confirm`**, as one `AskUserQuestion` with `multiSelect: true`, showing each entry's source and
`diffstat` or `availableLabel`, and offering `python3 ENGINE diff-skill <name>` first. Then apply
the picks with the same two commands.

Put these in the same question, and always ask, trusted source or not:

- `newSkills`, installed with each `installCmd`. Flag a name that collides with an installed skill
  from a different source. `previouslyRemoved` names were parked by the owner: report the count.
- Moved skills, reinstalled with the command in the `note`.
- Removed skills: keep the frozen copy, or `npx skills@latest remove <name> -g -y`.

`--force` discards local edits, so it needs the user's word for that skill by name. Complete when
every `auto` entry and every pick has been run.

### 4. Read back

`apply-skills` prints JSON read from the folders themselves, and that JSON is the result:

| Key | Meaning |
|---|---|
| `applied` | Folder changed and matches the lock |
| `unchanged` | The installer left the folder as it was: report as not updated |
| `failed` | Folder and lock disagree: report with `diff-skill`, whatever the installer printed |
| `refused` | Blocked by the engine's guard, with the reason |
| `unlinked` | A link the installer added and the engine removed, keeping a skill unexposed where it was |
| `newEntriesLeft` | Something new in a host folder that the engine left alone: show the user |

For plugins, run `python3 ENGINE detect` again and confirm each applied one reads `none`. Complete
when every applied entry has a verdict from one of these two.

### 5. Report

Group by the source table: applied, held, skipped and failed, each by name. Then add:

- `personalRepos` entries that are dirty, ahead, behind, off their default branch, or
  `remoteMoved`. Leave pulling to the owner: these checkouts are live installs and may have another
  writer.
- `brokenLinks`, and anything in `errors`.

End with the restart line for the host: **Restart Claude Code to load the updated skills.** Plugin
updates require it, and skills load at session start.

## Reference

- **What the engine manages:** a skill with a row in the lock and a real directory at
  `~/.agents/skills/<name>`. `apply-skills` refuses any other name, so personal skills stay out of
  reach by construction. A symlink proves nothing either way, since managed skills reach hosts
  through symlinks too.
- **Trust** lives in `trusted-sources.json` beside this file. Promote a source by adding its
  marketplace name or `owner/*` glob. Community confirmation for `kepano/obsidian-skills` and
  manual-only cadence are deliberate: check before changing either.
- **Running `npx skills` by hand, or a result that surprises you:** read
  [`CLI-TRAPS.md`](CLI-TRAPS.md) first.
- `GITHUB_TOKEN` in the environment avoids rate limits on the clones.
- **Tests** need `pytest` from a venv: `python3 -m venv .venv && .venv/bin/pip install pytest &&
  .venv/bin/python -m pytest scripts/`.
