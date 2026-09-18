# `agents/` — the seat definitions, versioned

A **Seat** is a named position in a run filled by one pinned agent definition (`CONTEXT.md`
§ Multi-agent runs). The definitions live here, one file per seat per host:
`agents/claude/<name>.md` for Claude Code, `agents/codex/<name>.toml` for Codex.

They are versioned beside the policy that names them because a seat without a resolvable
definition is not an unpinned seat you can see — it is an unpinned seat you cannot. A name the
host cannot resolve dispatches on the parent's model, and the Agent tool reports that only if
the caller looks. That is the leak the review-seat pin exists to close, measured in 3 of 4
sessions on 2026-09-14. A second machine or a reinstall without these files reproduces it
silently.

## Seat → definition

| Seat | Claude Code | Codex |
|---|---|---|
| Implementer | `claude/implementer.md` | `codex/implementer.toml` |
| Advisor (Planner role, one spawn per ticket, continued by `SendMessage`) | `claude/advisor.md` | — none, by design |
| Reviewer, dispatched twice — one Standards axis, one Spec axis | `claude/code-reviewer.md` | `codex/code-reviewer.toml` |
| Gate-runner | the project's own `.claude/agents/gate-runner.md` | — none |

The gate-runner stays in its project: it carries that project's gate commands, so a shared copy
would drift from the gate the coordinator would otherwise have run. Where a host cannot resolve
the advisor or the gate-runner, the coordinator holds that judgment or runs those gates itself
and says so.

## Install

Run this from anywhere inside the clone. It takes the clone's location from git rather than
assuming one, because nothing in this repository may assume where the clone lives.

```sh
REPO="$(git rev-parse --show-toplevel)"
mkdir -p "$HOME/.claude/agents" "$HOME/.codex/agents"
for n in implementer advisor code-reviewer; do
  ln -sfn "$REPO/agents/claude/$n.md" "$HOME/.claude/agents/$n.md"
done
for n in implementer code-reviewer; do
  ln -sfn "$REPO/agents/codex/$n.toml" "$HOME/.codex/agents/$n.toml"
done
```

Check: `ls -l ~/.claude/agents ~/.codex/agents` — every entry should be a symlink into this
clone, and no entry should name a seat that no longer exists.

## Editing here is live

Same rule as the Skills (`CLAUDE.md` § Load-bearing facts): the installed definition *is* this
file, so an edit lands immediately, and a checkout onto a ref without this directory breaks
every seat with no error. A **new** `.claude/agents/*.md` registers mid-session; whether a
dispatch re-reads an **edited** body in the session that edited it is unmeasured — validate an
edit in a fresh session, not the one that made it. The Codex side is a session input: after
touching a `.toml`, check discovery in a newly started task. Codex rejects an unknown key in a
role file with a startup warning rather than a failed dispatch, so a typo there is quiet unless
you look for it.

## Why there is no Codex advisor

The advisor seat exists to spend the Planner role — a different, rate-limited capability — on
unscoped judgment. The Codex account has one role, so a twin there would be a second Builder
opinion wearing a name that claims otherwise. A Codex coordinator takes the fallback instead.

`codex/code-reviewer.toml` also carries no equivalent of the `.md`'s `tools:` restriction; the
role file has no key for one, and an unknown key is rejected. Read-only on Codex is enforced by
the dispatch's sandbox, not by the role file.

## Not covered by the install-surface verifier

The verifier in the private companion repository checks `~/.claude/skills`, `~/.agents/skills`
and the two Chunk links. It does not observe `~/.claude/agents` or `~/.codex/agents`; this
surface is checked by hand with the `ls -l` line above.
