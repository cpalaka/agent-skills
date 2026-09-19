<!-- chunk:dev-base | kind: bundle | single-source: agent-skills/chunks/dev-base.md -->
<!-- The dev-process base every dev Profile imports: it recursively @imports the eight universal
     base chunks listed below, implement-run among them, and that list is the bundle. -->
<!-- Codex expands no @ line: when a Codex AGENTS.md sends you here, read every child listed below
     completely, resolving ~/.claude/chunks/<name> as ~/.codex/chunks/<name>. -->
<!-- Two chunks stay OUT of the bundle and the Profile imports them explicitly, because @import
     cannot be undone: the git-flow fork (git-flow-squash) and the tracker chunk — backlog-core
     or tracker-github, exactly one. The manifest selects both
     (`init-project` § What a Profile is). -->

@~/.claude/chunks/git-sync-branch-start.md
@~/.claude/chunks/git-commit-format.md
@~/.claude/chunks/git-confirm-destructive.md
@~/.claude/chunks/sandbox-auto.md
@~/.claude/chunks/parallel-work.md
@~/.claude/chunks/verify-gate.md
@~/.claude/chunks/dev-practice.md
@~/.claude/chunks/implement-run.md
