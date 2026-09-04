# Issue tracker

<!-- Stamped by init-project (profiles/backlog/templates/issue-tracker.md). This file is the
     canonical tracker pointer for skills that look up docs/agents/issue-tracker.md
     (code-review's Spec axis, triage, to-tickets). Conventions stay authoritative in the
     backlog-core chunk, which your host adapter loads (CLAUDE.md for Claude Code, AGENTS.md for
     Codex) — this is a pointer, not a second copy. -->

Issues live in **Backlog.md**: task files under `backlog/` in this repo, driven by the
`backlog` CLI. Never hand-edit files under `backlog/` — the CLI owns IDs, naming, and
frontmatter (`backlog/config.yml` is the one hand-editable file).

- **Fetch an issue:** `backlog task <id> --plain`. Ids are zero-padded (`task-019`, never
  `task-19`); commits reference tasks by that full id.
- **List / search:** `backlog task list --plain` · `backlog search <query>`.
- **Create / edit:** `backlog task create` (main session only) / `backlog task edit` — follow
  the AC-vs-DoD, labeling, and sign-off conventions in the `backlog-core` chunk. `--ac`
  appends; `--desc` clobbers.
- **PRs are not a request surface** for this repo — triage covers board tasks only.
