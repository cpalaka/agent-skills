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
| Advisor (Planner role, slots 1 and 3; slot 3 continues slot 1 by `SendMessage` or spawns fresh) | `claude/advisor.md` | — none, by design |
| Reviewer — Standards axis, Spec axis, Correctness fallback, critic seat; each a fresh dispatch | `claude/code-reviewer.md` | `codex/code-reviewer.toml` |
| Gate-runner | the project's own `.claude/agents/gate-runner.md`, once a project stamps one | — none |

The gate-runner stays in its project: it carries that project's gate commands, so a shared copy
would drift from the gate the coordinator would otherwise have run. Where a host cannot resolve
the advisor or the gate-runner, the coordinator holds that judgment or runs those gates itself
and says so.

## Install

Run this from anywhere inside the clone. It takes the clone's location from git rather than
assuming one, because nothing in this repository may assume where the clone lives.

```sh
REPO="$(git rev-parse --show-toplevel)"
# Stand in the wrong clone and the loop would link five names at nothing, silently.
[ -f "$REPO/agents/claude/implementer.md" ] || { echo "not the agent-skills clone: $REPO" >&2; exit 1; }
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

## Model fields

The Claude seats pin a family alias — `opus` for the Builder seats, `fable` for the advisor — so a
new release reaches them with no edit ([ADR 0017](../docs/adr/0017-seats-pin-family-aliases.md)).
The Codex seats still pin `gpt-6-astra`, resolved by probe on 2026-09-17 from `codex doctor`'s
resolved model and the CLI's built-in catalog; re-probe it on a Codex model release.

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
about ten minutes (2026-09-22). The Codex side is a session input:
after touching a `.toml`, check discovery in a newly started task.

Codex validates the role file's *shape* but not its *values*, measured on 0.153.3 by planting each
in turn and counting `codex doctor`'s startup warnings: an unknown key raises one warning, and a
`model` set to a name no model has raises none. So a misspelled key is merely quiet, but a
misspelled model ID is completely silent — the field that decides which model fills the seat is
the one nothing checks. Change it by copying a slug, never by typing one.

## Why there is no Codex advisor

The advisor seat exists to spend the Planner role — a different, rate-limited capability — on
unscoped judgment. The Codex account has one role, so a twin there would be a second Builder
opinion wearing a name that claims otherwise. A Codex coordinator takes the fallback instead.

`codex/code-reviewer.toml` also carries no equivalent of the `.md`'s `tools:` restriction; the
role file has no key for one, and inventing one only earns the startup warning above. Read-only
on Codex is enforced by the dispatch's sandbox, not by the role file.

## Not covered by the install-surface verifier

The verifier in the private companion repository checks `~/.claude/skills`, `~/.agents/skills`
and the two Chunk links. It does not observe `~/.claude/agents` or `~/.codex/agents`; this
surface is checked by hand with the `ls -l` line above.
