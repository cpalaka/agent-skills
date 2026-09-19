<!-- chunk:git-confirm-destructive | kind: invariant | single-source: agent-skills/chunks/git-confirm-destructive.md -->
<!-- Delivered by Claude @import or a Codex AGENTS.md explicit read through the host's chunk symlink.
     Edit here only — no per-project copies, no parity. -->

## Confirm with a human before any hard-to-reverse or outward-facing git/gh action

Each action below **surfaces for explicit human approval before it runs** — never autonomously.
No loop, wave, background subagent or coordinator may execute one on its own; they pause and ask.
A sandbox or approval mode that lets one through is not a sign-off for it: these gates are
instruction-level and bind whatever the mode permits.

**Force-push — always confirm.** `git push --force` or `--force-with-lease`, to any branch.
Force-pushing the default branch is **never** OK, with or without confirmation.

**Deletion that escapes the local repo — confirm.** A tag, or a remote branch
(`git push origin --delete …`, `git tag -d` on a pushed tag). Deleting a *local* feature branch
after its approved merge is fine and needs no prompt.

**Every `gh` WRITE command — confirm.** `gh pr create`, `gh pr merge`, `gh issue` writes, `gh api`
against a write endpoint: human-gated, full stop. The `gh` reads (`gh pr view`, `gh issue list`, …)
run without prompting; only the writes gate. Anything that costs money or hits a third-party rate
limit belongs in the same confirm-first bucket.

**Allowlist hygiene — keep these gates off the permission allowlist.** A broad glob like
`Bash(gh pr *)` or `Bash(git push *)` on `permissions.allow` overrides the classifier and runs the
actions above silently in every session and subagent, defeating the gate. Keep `git push`,
force-push and `gh` write globs OFF the allowlist; allow only specific read-shaped commands. Before
editing an allowlist, read the `sandbox-and-permissions` skill where it is installed (its directory
exists under `~/.claude/skills` or `~/.agents/skills`); where it is not, skip that read.
