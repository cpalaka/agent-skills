---
name: skill-updater
description: Check installed skills for upstream updates and install them, across every ecosystem on this machine. Use when the user asks to check or update their skills, or invokes /skill-updater in Claude Code or $skill-updater in Codex. Does NOT touch hand-authored personal skills.
---

# Skill Updater

Detects and installs updates for every installed skill the engine can manage, and names every
ecosystem it looked at. The deterministic work is done by the bundled `scripts/skillsync.py`;
you orchestrate.

**Engine path** — `ENGINE` in the commands below stands for the one that matches your host:

```bash
# Claude Code
~/.claude/skills/skill-updater/scripts/skillsync.py
# Codex
~/.agents/skills/skill-updater/scripts/skillsync.py
```

Whatever each path resolves to, the engine reads `trusted-sources.json` from beside its own
resolved location, so one copy of the engine, its tests and that file serves both hosts.
`python3` must be on PATH; the engine shells out to `git`, `claude` and `npx`.

## Ecosystems

This is a machine-wide updater, whichever host runs it. Three ecosystems exist here; name
each one in the report, with what you did about it:

1. **Claude Code plugins** — `claude plugin` CLI, state under `~/.claude/plugins/`. The
   engine detects and applies. Checked from either host: the data is on disk and the CLI is on
   PATH; Codex does not load these plugins, but that is not a reason to leave them stale.
2. **agent-skills** — `npx skills`, the lock at `~/.agents/.skill-lock.json`, folders under
   `~/.agents/skills/`. The engine detects and applies. Shared by both hosts.
3. **Codex plugins** — `codex plugin` CLI, cache under
   `~/.codex/plugins/cache/<marketplace>/<plugin>/<version>/`, registry in `~/.codex/config.toml`
   (`[marketplaces.*]`, `[plugins.*]`). A third ecosystem, not the agent-skills channel under
   another name. **Enumerated, not updated**: codex-cli 0.153.3 has no plugin `update`
   subcommand (`add`, `list`, `remove`, `marketplace {add,list,upgrade,remove}` — measured
   2026-09-04), and the app-managed marketplaces (`openai-bundled`, `openai-primary-runtime`)
   are refreshed by the Codex app itself. When `codex` is on PATH, list the installed set:

   ```bash
   codex plugin list --json < /dev/null | python3 -c 'import json,sys
   for p in json.load(sys.stdin)["installed"]: print(p["pluginId"], p["version"])'
   ```

   (The plain `codex plugin list` also prints every *available* marketplace plugin — hundreds
   of lines; the JSON filter is the readable form. Both are read-only: tree hashes of
   `~/.codex/plugins` and `~/.agents` were identical before and after.) Report it as
   "enumerated, not updated — no update command in this CLI"; with no `codex` on PATH, report
   "skipped: no codex CLI".

## Steps

### 1. Announce and detect

Tell the user which ecosystems you are checking (all three above) and that this fetches from
GitHub (marketplace metadata + a shallow clone per agent-skill repo). Then run:

```bash
python3 ENGINE detect --refresh
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
> `python3 ENGINE diff-skill <name>`, then re-home the edit (upstream, or into a personal
> skill) before updating.

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
empty, report "✓ All skills are up to date" (still naming the three ecosystems) and stop.

Always surface anything in `errors` (e.g. a repo that failed to clone) — report it but
keep going with what succeeded.

**Codex sandbox.** The engine needs network (the clones) and writes under `~/.claude/plugins`
(`--refresh`) and `~/.agents` (`apply-skills`); under `workspace-write` the first `--refresh`
returns `marketplace update failed: … EPERM`. In an interactive `codex` session, ask for the
approval and continue. In a non-interactive `codex exec` run, **do not request escalation
yourself** — writing to those roots from a dispatched run is a decision the person launching it
makes, by launching unsandboxed on purpose (`--dangerously-bypass-approvals-and-sandbox`).
Otherwise the run is report-only from Step 2 on: name the step the denial stopped, print the
exact `apply-plugin` / `apply-skills` commands, and stop. (Why the rule is explicit:
`codex-sandbox-and-approvals` — an exec run's own escalation request is granted with no human.)

### 2. Auto-apply trusted updates

Collect the trusted entries with `updateAvailable: true` and `localEdited` not `true`:

- **Plugins** (`trusted: true`): for each, run `python3 ENGINE apply-plugin <id>`.
- **Skills** (`trusted: true`): collect their `name`s and run ONE batched call:
  `python3 ENGINE apply-skills <name1> <name2> ...`.

Record each result (success/failure from exit code and output).

### 3. Confirm community updates

For the entries with `updateAvailable: true`, `trusted: false` and `localEdited` not
`true`, present them to the user with their source and `diffstat`/`availableLabel`, and let the
user pick which to apply — the surface differs per host:

- **Claude Code:** the `AskUserQuestion` tool with `multiSelect: true`.
- **Codex:** ask in your reply and end the turn; the picks arrive as the next message. In
  `codex exec` there is no next message — the run ends on the question, unanswered (measured
  2026-09-04: the model asked, applied nothing, and the run stopped). So a non-interactive run
  is **report-only** for this step: list the exact `apply-plugin` / `apply-skills` commands per
  pick and stop.

Include the option to see a full diff first — if asked, run for that skill:

```bash
python3 ENGINE diff-skill <name>
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

Summarize grouped by ecosystem — all three, each with what was applied, skipped (declined,
held back for local edits — name those, with the `diff-skill` command — or not updatable, with
the reason), and failed. Then end with this note, in the host's spelling:

> **Restart Claude Code / start a new Codex session to load the updated skills.** Plugin
> updates explicitly require a restart; agent-skills are loaded at session start.

## Notes

- **Never touches personal skills.** A skill is managed by this engine only if it has a row in
  `~/.agents/.skill-lock.json` **and** `~/.agents/skills/<name>` is a real directory (the
  installer's copy). Everything else — hand-authored or vendored — is invisible to the engine by
  construction (`skillsync.py detect_skills()` iterates `lock.get("skills", {})` and nothing
  else). **"Is it a symlink?" is NOT the test** — hand-authored skills are usually symlinks too,
  into a local checkout of the repo that authors them, on both hosts (Claude Code reaches a
  managed skill through `~/.claude/skills/<name>` → `../../.agents/skills/<name>`; Codex reads
  `~/.agents/skills` directly). Measured on one maintainer install, 2026-09-04: 52 lock rows, 52
  real directories with one, 14 symlinks with none, one real directory with no row (invisible
  to the engine, as it should be) — your own numbers will differ, the shape will not. Check the
  lock row and the folder, never the symlink-ness.
- **Trusted vs. community** is defined in `trusted-sources.json` beside the engine —
  `skill-updater/trusted-sources.json` in the checkout both host entries resolve into. The
  engine derives that path from its own resolved location, so both hosts read one file. To
  promote a source to auto-apply, add its marketplace name to `marketplaces` or its `owner/*`
  glob to `repos`.
- Set `GITHUB_TOKEN` in the environment to avoid GitHub rate limits on the clones.
- **The engine needs only `python3`; the suite needs `pytest`, which a system `python3` often
  refuses to install.** From the skill directory (either host's path resolves to it):
  `python3 -m venv .venv && .venv/bin/pip install pytest && .venv/bin/python -m pytest scripts/`.
