<!-- chunk:git-confirm-destructive | invariant | edit only at agent-skills/chunks/git-confirm-destructive.md — no per-project copies -->

## Confirm with a human before any hard-to-reverse or outward-facing git/gh action

Each below **surfaces for explicit human approval BEFORE it runs** — no loop, wave, subagent or
coordinator excepted; a permissive mode is not sign-off.

**Force-push — confirm**: `--force`/`--force-with-lease`, any branch. The default branch is no
confirm case: **never force-push it at all**, confirmed or not.

**Deletion escaping the local repo — confirm**: a pushed tag, a remote branch
(`git push origin --delete`). Deleting a merged *local* branch needs no confirmation.

**Every `gh` WRITE — confirm**: `gh pr create`/`merge`, `gh issue` writes, `gh api` writes; money
or rate limits too. The `gh` reads run without prompting; only the writes gate.

**Allowlist hygiene.** A glob like `Bash(gh pr *)` on `permissions.allow` overrides the classifier
and runs these silently in every session and subagent — keep such globs off; allow read-shaped
commands only. Editing one: read whichever of `sandbox-and-permissions` (Claude Code) or
`codex-sandbox-and-approvals` (Codex) is under `~/.claude/skills` or `~/.agents/skills`.
