# Running under Codex

The engine and the steps in `SKILL.md` are the same. Three things differ.

## Confirming

Replace `AskUserQuestion` with a question in your reply, and end the turn: the picks arrive as the
next message. `codex exec` has no next message, so a non-interactive run is **report-only** from
step 3 on: list the exact commands per pick and stop.

## Sandbox

The engine needs network for the clones and writes under `~/.claude/plugins` (`--refresh`) and
`~/.agents` (`apply-skills`). Under `workspace-write` the first `--refresh` returns
`marketplace update failed: … EPERM`. In an interactive session, ask for the approval and continue.

In `codex exec`, stay inside the sandbox you were given. Writing to those roots from a dispatched
run is a choice for whoever launches it, by launching unsandboxed on purpose, because an exec run's
own escalation request is granted with no human. Name the step the denial stopped, print the exact
commands, and stop.

## Codex plugins

Enumerated, not updated: `codex plugin` has `add`, `list`, `marketplace` and `remove`, with no
`update` (codex-cli 0.159.2, 2026-11-06). The app refreshes its own marketplaces, `openai-bundled`
and `openai-primary-runtime`. List the installed set, which works from either host:

```bash
codex plugin list --json < /dev/null | python3 -c 'import json,sys
for p in json.load(sys.stdin)["installed"]: print(p["pluginId"], p["version"])'
```

Report it as "enumerated, not updated: no update command in this CLI".
