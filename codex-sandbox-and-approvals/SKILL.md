---
name: codex-sandbox-and-approvals
description: Codex sandbox denials and the approval policy that escalates them. Use when a shell command under Codex fails "Operation not permitted", when a git write fails with an index.lock or ref-lock error, when the network appears down inside a Codex session, BEFORE widening a sandbox with writable_roots / --add-dir / network_access or reaching for --dangerously-bypass-approvals-and-sandbox, and when a project's .codex/config.toml or its MCP servers appear not to load.
---

# Codex sandbox denials & approvals

The Codex sibling of `sandbox-and-permissions`, which carries the same ground for Claude Code.
**Read that one only for Claude Code.** The two hosts diverge most sharply on exactly the thing you
reach for first — git — and a rule carried across is wrong in both directions. The contrast table at
the end is the part to read if you already know the other host.

Everything below was measured on **Codex CLI 0.153.1, macOS (Darwin 24.6.0), 2026-09-04**, through
`codex exec` with the sandbox mode named on each run. Each claim has a control that fired the other
way; where one does not, it says so.

## The three sandbox modes

`-s` / `--sandbox` on `codex` and `codex exec`, or `sandbox_mode` in `~/.codex/config.toml`:
`read-only`, `workspace-write`, `danger-full-access`.

**`read-only`** — reads succeed anywhere, every write fails.

| Command | rc | Message |
|---|---|---|
| `git status --short` | 0 | (no error) |
| `cat a.txt` | 0 | (no error) |
| `touch ./probe.txt` | 1 | `touch: ./probe.txt: Operation not permitted` |

**`workspace-write`** — the workspace root, `/tmp` and `$TMPDIR` are writable; everything else is
not; `.git/` is not, either (next section). Reads stay unrestricted **outside** the workspace:
`ls -d ~/.ssh` returned 0.

| Target | rc | Message |
|---|---|---|
| `./probe_cwd.txt` (inside the workspace) | 0 | (no error) |
| `$HOME/x` | 1 | `touch: /Users/<user>/x: Operation not permitted` |
| `/tmp/x` | 0 | (no error) |
| `$TMPDIR/x` | 0 | (no error) |
| `./.git/probe` | 1 | `touch: ./.git/probe: Operation not permitted` |

**`danger-full-access`** — no sandbox. Distinct from
`--dangerously-bypass-approvals-and-sandbox`, which turns off the approval prompt as well.

## `.git/` is read-only under `workspace-write`, so git cannot write at all

This is the headline, and it is the **opposite** of Claude Code. Every write-side git operation
fails, including the ones that look like they only touch the index:

| Command | rc | First error line |
|---|---|---|
| `git status --short` | 0 | (no error) |
| `git add a.txt` | 128 | `fatal: Unable to create '<abs>/.git/index.lock': Operation not permitted` |
| `git commit -m probe` | 128 | same `index.lock` line |
| `git checkout -b probebranch` | 128 | same `index.lock` line |
| `git tag probe-tag` | 128 | `fatal: cannot lock ref 'refs/tags/probe-tag': Unable to create '<abs>/.git/refs/tags/probe-tag.lock': Operation not permitted` |
| `touch .git/objects/x` | 1 | `touch: .git/objects/x: Operation not permitted` |
| `touch .git/refs/x` | 1 | `touch: .git/refs/x: Operation not permitted` |
| `printf '\n' >> .git/config` | 1 | `zsh:1: operation not permitted: .git/config` |

**There is no half-switched tree here**, which is the trap on the other host. `checkout` cannot move
HEAD, because it cannot take `index.lock`, so it fails whole rather than partway. Do not go looking
for the half-switch recovery — the tree is untouched.

**The remedy is `writable_roots`, and it is measured.** Adding the repo's own `.git` back:

```bash
codex exec -s workspace-write -c 'sandbox_workspace_write.writable_roots=["/abs/path/repo/.git"]' …
```

The identical `git commit` that returned 128 without it returned 0 with it, and the commit was
verified in the tree afterwards by `git log` rather than from the agent's own report. Note the path
must be absolute and must name `.git` itself; the workspace root already being writable is what
makes this necessary rather than redundant.

## The network denial wears a DNS costume

Under `workspace-write` the network is off, and it does **not** report a permission error:

```
curl -sS -m 8 -o /dev/null -w '%{http_code}' https://example.com
→ 000, rc=6, "curl: (6) Could not resolve host: example.com"
```

`rc=6` is curl's *resolution* failure. Read that as "DNS is broken" or "the host is down" and you
will debug the wrong system. Any tool that resolves a name will report its own flavour of
name-resolution failure, none of which says "sandbox".

The control fired both ways: with `-c sandbox_workspace_write.network_access=true` the same command
returned rc 0.

## `socket.bind` is denied even on 127.0.0.1

```
python3 -c "import socket; s=socket.socket(); s.bind(('127.0.0.1',0))"
→ PermissionError: [Errno 1] Operation not permitted
```

Identical to Claude Code, and it surfaces the same way — inside your own server code, reading as a
bug in the server. Any local dev server needs the sandbox widened before its first launch; don't
burn the sandboxed attempt.

## Widening the sandbox — the four real knobs

Validated by name under `--strict-config`, with `sandbox_workspace_write.bogus_key_xyz=true` as the
known-bad control (rejected: ``unknown configuration field `sandbox_workspace_write.bogus_key_xyz`
in -c/--config override``). All four are accepted:

| Knob | Effect |
|---|---|
| `sandbox_workspace_write.writable_roots=["…"]` | extra absolute paths made writable — the git remedy above |
| `sandbox_workspace_write.network_access=true` | lifts the network denial |
| `sandbox_workspace_write.exclude_tmpdir_env_var=true` | removes `$TMPDIR` from the writable set |
| `sandbox_workspace_write.exclude_slash_tmp=true` | removes `/tmp` from the writable set |

`--add-dir <DIR>` does the same job as `writable_roots` from the command line, per invocation, and
was verified by a file landing in a directory outside the workspace.

**Prefer the narrowest of these to the bypass flag.** `--dangerously-bypass-approvals-and-sandbox`
turns off the sandbox *and* every confirmation, for the whole session, and its own help text says it
is meant only for an environment that is already externally sandboxed.

## Approvals are an escalation path, not an allowlist

This is the structural difference from Claude Code, which gates by matching a command against
`permissions.allow`. Codex has no allowlist. It has a policy for **when the model must ask**:

- `-a` / `--ask-for-approval` — `on-request` (the model decides when to ask) or `never` (never ask;
  execution failures are returned to the model).
- `--approve-for-me` — routes approval requests through automatic review using the `workspace-write`
  sandbox.
- `approvals_reviewer` in `~/.codex/config.toml` selects the reviewer (`auto_review` on this
  machine).

**`codex exec` has no `--ask-for-approval` flag at all** — measured: `-a` returns
`error: unexpected argument '-a' found`. That does **not** mean a non-interactive run has no
escalation path. Measured 2026-09-04 (codex-cli 0.153.3, this machine, `approvals_reviewer =
"auto_review"` in `~/.codex/config.toml`): a `codex exec -s workspace-write` run — header
`approval: on-request` — was told to write a file under `~/Library/Caches/` (outside every
writable root) and to retry once with escalation if denied. Observed from outside the model:
the first attempt failed `zsh:1: operation not permitted: …/t07-escalation-probe.txt`, the retry
ran as an ordinary `exec` line with exit 0, and the file existed afterwards (6 bytes; absent
before). Control: the same write with no retry instruction is the denial itself. No human was
present. What the transcript does **not** carry is a tool-parameter record — the parameter name
(`sandbox_permissions: "require_escalated"`) and the reviewer's identity (`auto_review`) are the
model's self-report, in its prose before the retry and in its final message. The same shape
appeared unprompted in a real skill run the same day: `EPERM` on a write to `~/.claude/plugins`,
then the identical command succeeding on a retry, the file's mtime confirming the write.

So a denial comes back to the model as an ordinary command failure, and the model can ask for
escalation — which, with `auto_review`, the automatic reviewer grants or refuses; nothing asks
*you*. That is the caution, not a licence: **a dispatched run must have its sandbox sized up
front and must not self-escalate to write outside the workspace.** Whether a run may write to a
root you did not open is the launcher's decision, made by launching it unsandboxed on purpose;
a run that requests it for itself moves that decision to a reviewer you do not see.

The interactive escalation — what `on-request` prompts for in the TUI — is still **not measured
here**.

## Project trust gates the project's own config

A project-scope `.codex/config.toml` does not load until that project has an entry in
`~/.codex/config.toml`:

```toml
[projects."/absolute/path/to/project"]
trust_level = "trusted"
```

With no entry, `codex mcp list` from the project root showed only the user-scope servers, **with no
error and nothing to say the project file was skipped**. With the entry appended, both project
servers appeared; removed, they vanished again. A `-c projects."<path>".trust_level="trusted"`
override on the command line does **not** substitute for the file entry. (Measured 2026-09-04 on a
freshly stamped project; the same measurement is in `init-project`'s handoff and ADR 0009's
consequences.)

So "the project's MCP servers aren't there" has two causes that look identical from inside a
session: the servers are misconfigured, or the directory-trust prompt was never answered. Check the
`[projects."…"]` entry before debugging the server.

## `codex sandbox` is not a usable probe here

The `codex sandbox` subcommand looks like the right instrument for testing a policy without
spending a model turn. On a machine with no permission profile configured it refuses every
invocation:

```
codex sandbox -P workspace-write -C <dir> -- /bin/echo ok
→ Error: default_permissions requires a `[permissions]` table
```

It needs a `[permissions]` table in the config stack, which is a separate profile system from
`sandbox_mode`. Measure through `codex exec -s <mode>` instead — that is also the path a real
session takes.

## Where Codex and Claude Code disagree

Carry nothing across without checking this table. The left column is what `sandbox-and-permissions`
records for Claude Code.

| Subject | Claude Code | Codex |
|---|---|---|
| Gate model | `permissions.allow` allowlist matched per command | approval policy: the model asks, or it doesn't |
| `git commit` sandboxed | **succeeds** — `.git/objects` and `.git/refs` are writable | **fails 128** on `index.lock` — all of `.git/` is read-only |
| `git checkout` / `merge` | half-switches the tree when a tracked file under `.claude/` is denied; leaves a dirty file that aborts the next merge | fails whole; nothing moves |
| `.git/config` | denied (cosmetic on `branch -d`, the ref op still lands) | denied, and the ref op does not land either |
| Network denial | host-allowlist, and `gh` fails on a keychain TLS error | off entirely under `workspace-write`; surfaces as **DNS resolution failure**, rc 6 |
| `socket.bind` 127.0.0.1 | denied, `Operation not permitted` | denied, identical |
| `$TMPDIR` | sandboxed and unsandboxed calls see **different** directories | writable; the two-directory split is **not measured here** |
| Widening | edit `permissions.allow`, or `dangerouslyDisableSandbox` per call | `writable_roots` / `--add-dir` / `network_access`, or the bypass flag |
| Per-project trust | not a concept | `[projects."<abs>"] trust_level = "trusted"` gates the project's own config and its MCP servers |

## Limits of this document

- **macOS seatbelt only.** The Arch box (Landlock/seccomp) is unmeasured; do not assume the same
  paths are denied there.
- **`codex exec` only.** Interactive-session approval behaviour is not measured.
- **One machine, one day.** Re-measure before leaning on any of it more than a few weeks out; the
  probe battery is three `codex exec` runs and reproduces in about five minutes.
