# `agents/` — the seat definitions, versioned

A **Seat** is a named position in a run filled by one pinned agent definition (`CONTEXT.md`
§ Multi-agent runs). The definitions live here, one file per seat and effort value:
`agents/claude/<name>.md` for Claude Code. Codex has no named seats — the `agents/codex/` role
files never registered (Codex's `spawn_agent` answered `agent type is currently not available`
on 0.153.3 and 0.156.1, since only an `[agents.<name>]` table in `config.toml` registers a role),
and Codex acts here only as a reviewer (the Codex lens and `codex exec` from a Claude Code
coordinator), which goes through no seat.

They are versioned beside the policy that names them because a seat without a resolvable
definition is not an unpinned seat you can see — it is an unpinned seat you cannot. A name the
host cannot resolve dispatches on the parent's model, and the Agent tool reports that only if
the caller looks. That is the leak the review-seat pin exists to close, measured in 3 of 4
sessions on 2026-09-14. A second machine or a reinstall without these files reproduces it
silently.

## Seat → definition

| Seat | Claude Code |
|---|---|
| Coordinator (inside a delegated batch, one per ticket, depth 1; dispatched by `implement-batch`'s delegate) | `claude/coordinator.md` |
| Implementer | `claude/implementer.md`, `claude/implementer-medium.md` |
| Advisor (Planner role, slots 1 and 3; slot 3 continues slot 1 by `SendMessage` or spawns fresh) | `claude/advisor.md` |
| Reviewer — Standards axis, Spec axis, Correctness fallback, critic seat; each a fresh dispatch | `claude/code-reviewer.md`, `claude/code-reviewer-medium.md` |
| Gate-runner | the project's own `.claude/agents/gate-runner.md`, once a project stamps one; the stamped Template runs at `effort: medium` |

The gate-runner stays in its project: it carries that project's gate commands, so a shared copy
would drift from the gate the coordinator would otherwise have run. Where a host cannot resolve
the advisor or the gate-runner, the coordinator holds that judgment or runs those gates itself
and says so.

## Install

Run this from anywhere inside the clone. It takes the clone's location from git rather than
assuming one, because nothing in this repository may assume where the clone lives.

```sh
REPO="$(git rev-parse --show-toplevel)"
# Stand in the wrong clone and the loop would link six names at nothing, silently.
[ -f "$REPO/agents/claude/implementer.md" ] || { echo "not the agent-skills clone: $REPO" >&2; exit 1; }
mkdir -p "$HOME/.claude/agents"
for n in coordinator implementer implementer-medium advisor code-reviewer code-reviewer-medium; do
  ln -sfn "$REPO/agents/claude/$n.md" "$HOME/.claude/agents/$n.md"
done
```

Check: `ls -l ~/.claude/agents` — every entry should be a symlink into this clone, and no entry
should name a seat that no longer exists.

## Model fields

The Claude seats pin a family alias — `opus` for the Builder seats, `fable` for the advisor — so a
new release reaches them with no edit ([ADR 0017](../docs/adr/0017-seats-pin-family-aliases.md)).

## Effort fields

Every Claude definition carries `effort:` explicitly
([ADR 0023](../docs/adr/0023-light-default-run-profile.md), superseding
[ADR 0018](../docs/adr/0018-run-profile-derived-from-plan.md) § 7). A profile seat's `-medium` name
is the default dispatch and its bare name, `high`, the add-on; the advisor and the `coordinator`
keep their one `high` definition, and the gate-runner runs `medium`. The table above shows which
values each seat reaches. A suffixed file is its bare file with only
`name:`, `effort:` and one leading sentence changed. Re-apply an edit to a bare body to its
suffixes by hand, then run this check. It prints one `diff` hunk per suffix, whose `<` lines are
exactly that suffix's leading sentence and blank line, and nothing else:

```sh
REPO="$(git rev-parse --show-toplevel)"
for p in implementer-medium:implementer code-reviewer-medium:code-reviewer; do
  diff <(grep -vE '^(name|effort):' "$REPO/agents/claude/${p%%:*}.md") <(grep -vE '^(name|effort):' "$REPO/agents/claude/${p##*:}.md")
done
```

A changed `effort:` line, like a changed `model:` line, is verified from a fresh session. Every
assistant record in the seat's transcript,
`~/.claude/projects/<project-slug>/<session-id>/subagents/agent-<id>.jsonl` in the parent session's
transcript directory, carries the applied `effort`, and a definition's value overrides the parent
session's (measured 2026-09-24). Run the parent at a value the seat does not carry
(`claude -p --effort low`), so an inherited value cannot pass for the definition's; a bare
`claude -p` ran at the CLI's own default, above every seat's value.

## Editing here is live

Same rule as the Skills (`CLAUDE.md` § Load-bearing facts): the installed definition *is* this
file, so an edit lands immediately, and a checkout onto a ref without this directory breaks
every seat with no error.

On Claude Code 2.1.269 the registry re-reads the directory during a session, but lazily: a rename
took several minutes and several tool calls to show up, and until it did, dispatches were still
served the old roster — the retired name answered and the new one was reported not found, both
wrongly. An **edited** body, once the refresh lands, is served fresh (measured 2026-09-17 by
having the seat quote its own changed line back). So a dispatch that contradicts what is on disk
means the refresh has not happened yet, not that the file is wrong; the cost of assuming
otherwise is re-editing a file that was already correct. A changed `model:` line is verified from a
fresh session (`claude -p`): the editing session kept serving the old pin for three dispatches over
about ten minutes (2026-09-22).

## Not covered by the install-surface verifier

The verifier in the private companion repository checks `~/.claude/skills`, `~/.agents/skills` and
the two Chunk links. It does not observe `~/.claude/agents`; this surface is checked by hand with
the `ls -l` line above.
