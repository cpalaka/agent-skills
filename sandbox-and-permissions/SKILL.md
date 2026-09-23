---
name: sandbox-and-permissions
description: Claude Code sandbox denials and permission-allowlist safety. Use when a Bash or git command fails "Operation not permitted", when a branch switch half-completes and the next merge aborts, when a sandboxed command returns a clean answer that is wrong, BEFORE adding any entry to `permissions.allow` or writing a `.claude/settings.local.json`, and when a background job or a sibling worktree must edit or commit files (worktree isolation, EnterWorktree, compound-Bash refusals).
---

# Sandbox denials & permission-allowlist safety

Each stamped project states the session baseline (sandbox on, `auto` mode) as one bullet in its
`CLAUDE.md` adapter. This Skill carries the baseline's shape, what the sandbox then denies, and
how to change permissions without opening a hole.

## The baseline

Both settings sit in gitignored `.claude/settings.local.json`:

```jsonc
{
  "permissions": { "defaultMode": "auto" /*, "allow": [...] */ },
  "sandbox": { "enabled": true }
}
```

Both are read once at session start, like MCP servers: if the file lacks them, fix it and
**restart**. Being gitignored, it travels with no clone and no new worktree (how defaults reach
subagents vs. fresh worktree sessions: `parallel-work`).

Reads are unrestricted. Writes are allowed under roughly `.`, `$TMPDIR`, `/tmp/claude`,
`~/.npm/_logs` and `~/.claude/debug`; `denyWithinAllow` then blocks `.claude/`, `.git/config` and
`.git/hooks` but not `.git/objects` or `.git/refs`, so a sandboxed `git commit` in the session's
own checkout succeeds. For a Bash write outside the repo, use the Write/Edit tools or the bypass.
A denial fails `Operation not permitted`; don't burn a retry on it.

## What needs `dangerouslyDisableSandbox`

Bypass from the **first** attempt. Few of these errors mention the sandbox.

| Command | Denial | Bypass scope |
|---|---|---|
| `git checkout`/`switch`/`merge`/`rebase`/`stash pop` that must modify a **tracked file under `.claude/`** | `Operation not permitted`, and a **half-switch** (below) | that op |
| `npm install` / `npm i <pkg>` | `EPERM open ~/.npm/_cacache/tmp/…` | install/add only |
| `bun install` / `bun add` | `bun is unable to write files to tempdir: PermissionDenied` | install/add only; `bun run`/`build` are fine |
| `agent-browser <any subcommand>` | `Socket directory '~/.agent-browser' is not writable` | every invocation |
| any process that listens, even on 127.0.0.1 | Python `PermissionError: [Errno 1]`, Node `listen EPERM … ::1:5173` — reads as a bug in your server | the launch, and in practice requests to it; build/test/lint need none |
| Blender, including Godot's `.blend` import spawning it | crash before Python runs: `MTLBackend::metal_is_supported`, `Writing: $TMPDIR/blender.crash.txt` | every launch. A sandboxed Godot import writes `valid=false` into the `.blend.import` sidecar and never retries: delete the sidecar, reimport unsandboxed |
| Playwright `browser.launch()` | **nothing** — no output, not even the script's own `catch`, for minutes; reads as a slow browser | every launch |
| `gh <anything>`, reads included | `x509: OSStatus -26276` — macOS denying gh's TLS stack the keychain trust store, not host blocking | every invocation (reads measured failing 2026-07-28) |
| write-side git **from a worktree** — `add`, `commit`, `fetch`, the `backlog` CLI's automatic fetch | `Unable to create '<main>/.git/worktrees/<name>/index.lock'` | every write-side op there |

Plain `git push`/`fetch` over HTTPS uses git's own TLS and needs no bypass.

**Half-switch recovery.** The denied op moves HEAD and reverts every other file to the target,
leaving the denied file dirty, so the next `merge` aborts. Assess with read-only git
(`status`/`log`/`diff`), then with the sandbox off run `git checkout -- <denied-file>` and redo
the op.

**Running a worktree's gate from the main session.** The auto-mode classifier refused
`cd <worktree> && <gate>` sandbox-off and allowed the same gate by absolute path (2026-09-12):
invoke by absolute path, with no `cd` in the command. A runner that `cd`s to its own `dirname` is
then safe; a tool that resolves "the project" from `$PWD` scans the main checkout and reports under
the worktree's name. Read its `project=` / `logs:` line before believing the verdict.

**Confirm it is a denial.** Before bypassing a hang, check the tool fails sandbox-off too: Chrome
`--headless --screenshot` hangs on macOS regardless. Rasterize SVG with
`qlmanage -t -s <size> -o <dir> file.svg` instead, which composites onto opaque white while
reporting `hasAlpha: yes`.

## Cosmetic denials — the op succeeded; don't retry

Read the payload line, not the `fatal:`.

- **`fatal: failed to store: 100001`** on `fetch`/`pull`/`push`: only the credential or
  commit-graph cache write failed. The ref-update line (`f1540d8..6db63c0  main -> main`) or
  `Already up to date` is ground truth; confirm with `git status -sb`. A retry can double-apply.
- **`could not write config file .git/config`** on `git branch -d/-D` and other ref edits: the
  ref op landed.
- **zoxide's `chpwd` hook** can't write its database, and under zsh that aborts the whole compound
  command (`cd web && npx vitest …` exits before vitest runs). Not a bypass case: rely on the Bash
  tool's persistent cwd, or `bash -c 'cd /abs/path && …'`.

The path in the message tells the classes apart: `index.lock` or `FETCH_HEAD` under `worktrees/`
wrote nothing, so bypass and retry; commit-graph, credential cache, `.git/config` and the zoxide
database are cosmetic.

## False reads — a clean answer that is wrong

Worse than a denial, which at least announces itself.

- **`$TMPDIR` is two directories.** Sandboxed calls see `/tmp/claude-<uid>`, sandbox-off calls
  the real `/var/folders/…/T/`, and both outlive the session. A file written in one mode reads
  back in the other as missing, or as a stale file from another session: a well-formed
  `VERDICT: CLEAN` about a different checkout, an unrelated commit message handed to `git push` as
  a refspec. Keep write → use → verify in one sandbox mode, and put anything a verdict, commit or
  push rests on at a path inside the repo. When a tool prints its own subject (project path,
  commit, run id), check it is the one you meant.
- **With no sandbox configured, a "sandboxed" attempt succeeds and measures nothing.** The
  baseline sits in gitignored settings, so a checkout or machine without it runs Bash unsandboxed
  (2026-09-23: `touch ~/…` and an outbound `curl` both succeeded). Before quoting a sandbox result,
  read `.sandbox` in every settings file. To measure under it anyway, run headless:
  `echo "<prompt>" | claude -p --settings '{"sandbox":{"enabled":true,"allowUnsandboxedCommands":false}}' --allowedTools=Bash`.
  Keep the `=` and the piped prompt: the flag is variadic, so `--allowedTools Bash "<prompt>"`
  swallows the prompt and exits `Input must be provided`.
- **`ps`, `pgrep` and `kill -0` cannot see processes** (`sysmond service not found`), so
  `ps || echo dead` reports a live process dead. Recheck sandbox-off before re-dispatching its
  work. A monitor watches output-file **size growth** instead — reads are unrestricted — over N
  stable samples, calibrated on a known-alive PID; read the numbers for coherence ("finished in
  1 minute, 0 bytes stdout, 221 KB stderr" is not finished).
- **`git status`/`diff` at session start can show phantom-dirty files** that read clean minutes
  later (suspected: a denied index refresh). Re-run and reconcile against `git log` /
  `git ls-tree` before acting on a surprising dirty tree.
- **Heredocs and here-strings fail in a sibling worktree.** bash 3.2 does not put their temp file
  in `$TMPDIR`: it tries `/tmp` and `/var/tmp`, denied everywhere, then the working directory, which
  the sandbox grants for the session's own checkout and not for a sibling worktree.
  There a heredoc-backed gate printed `cannot create temp file for here document` on stderr,
  exited 0, and printed a clean verdict with 1 of 28 checks run; a loop fed by one runs zero times.
  Run such scripts sandbox-off, read a gate's executed-check count, and feed loops with
  `< <(printf '%s\n' "$VAR")`. A heredoc working in the main checkout is not evidence against this.
- **Process substitution as a path argument** (`diff <(git show REF:f) f`) fails
  `/dev/fd/63: Operation not permitted`; as stdin (`< <(…)`) it works. Use tool-native forms
  (`git diff REF -- f`).
- **A sandboxed `mktemp -d` can return empty, and `cd ""` succeeds in place**, so
  `D="$(mktemp -d)"; cd "$D"` builds its fixtures or runs `git init` in the repo you stand in, every
  step reporting success. Guard with `[ -z "$D" ] || [ ! -d "$D" ]` and refuse. Recover with
  `git reset --soft` + `git checkout <commit> -- <file>`, reading `git reflog` first. A probe that
  runs gated git in that directory: § Allowlist hygiene, the git gate.
- **Background jobs:** `$CLAUDE_JOB_DIR/tmp` is denied although the job prompt points there; use
  `$TMPDIR`. The harness appends `< /dev/null` to foreground commands only, so a stdin-reading
  CLI hangs in a background one: put `< /dev/null` on the **first** stage (on a pipeline's last
  it redirects only that stage).

## Shell traps the sandbox doesn't cause

The same silent shape, from plain shell or the harness:

- `VAR=value cmd "$VAR"` expands `$VAR` in the current shell before the prefix applies, handing
  `cmd` an empty argument; a grep over the dead run's output reads clean. `export VAR=value` on
  its own line first.
- A heredoc inside `$(...)` in an `&&` chain dies "unexpected EOF" in the harness wrapper. Write
  the body to a file inside the repo with the Write tool, then `-F` it.
- An unquoted delimiter (`<<PY`) expands `$(…)` and backticks inside the body; quote it
  (`<<'PY'`).
- macOS bash is 3.2 (no `declare -A`). Run `sort` over non-ASCII input, and the `comm`/`join` it
  feeds, under one `LC_ALL=C`. Pin `LC_ALL=C` on any `awk` reading prose too: in a UTF-8 locale
  it can die `towc: multibyte conversion failure`, printing nothing and exiting 0. Bracket ranges
  are collation-ordered there (`case $s in *[A-Z]*)` matches `abc`); use `LC_ALL=C grep '[A-Z]'`.
  A harness with `LANG` unset reads green on both.

## Background-job worktree isolation

Background sessions isolate into a worktree under `.claude/worktrees/` unless the project's
`.claude/settings.json` sets `worktree.bgIsolation: "none"` (key verified 2026-08-31; few projects
set it). Settings load at session start, so the opt-out must **pre-exist the session**: a bg job
that `git init`s mid-session is isolation-locked for its whole run. `EnterWorktree` is then the
only sanctioned way to edit, and the guard refuses compound Bash (heredocs, `&&` chains, `for`
loops, `agent-browser eval`): one command per call, throwaway scripts written to a file first.
Merging back is the user's call; from an unmoved base it is `git merge --ff-only <branch>` in the
main checkout after `ExitWorktree`.

## Allowlist hygiene

`permissions.allow` overrides the classifier: whatever it matches runs ungated in every session
and every subagent. Allow only specific, read-shaped commands. `git push` stays off, and so does
every `gh` glob — `Bash(gh issue *)` cannot tell `list` from `edit` — so name the reads
(`gh issue list`, `gh pr view`). Audit the entries already there before adding one.

**Matching.** Rules anchor at the command start: `Bash(git reset --hard*)` misses
`git -C /path reset --hard`, which discarded a working tree (v2.1.220). Compound commands match
per subcommand. Stripped before matching: `timeout time nice nohup stdbuf command builtin noglob`
and bare `xargs`; **not** `npx`, `docker exec`, `direnv exec`, `mise exec`, `watch`, `setsid`,
`flock`, `find -exec`. Precedence is `deny > ask > allow`, and a hook's `"ask"` outranks an allow
(v2.1.261). A leading-`*` rule is a raw substring match: `Bash(*&& git stash push*)` fired on
`grep -c 'git stash push --'`. Test a rule by **side effect** in a scratch repo — did the file
revert? — never by exit code or self-report.

**The git gate hook, where `~/.claude/hooks/git-destructive-gate.py` exists.** It is a
`PreToolUse` `Bash` hook that gates git only in **command position**, by parsing the shell; extend
its `classify_git` rather than adding `permissions.ask` rules, then run it with `--test`. Probe
rather than trust a list —
`printf '{"tool_name":"Bash","tool_input":{"command":"git add src/"}}' | python3 <hook>` prints
nothing when the command is not gated. Ungated: plain `git push` (unless `GIT_GATE_PLAIN_PUSH=1`),
`git add <path>` (only `-A`/`--all`/`-u`/`.` are parsed, which is why staging by explicit path is a
rule), and `git remote remove/rm/rename/set-url`. `scratchpad_only()` exempts a command whose
every absolute path lies under `/tmp/claude-<uid>/`; that is how fixture work gets `branch -D`, so
keep the exemption scoped. It reads the command **text**: `P="$(mktemp -d)"` names no path, and
one `~` or other absolute path anywhere in the command voids it, so both prompt. A throwaway-repo
probe writes the root literally — `mktemp -d /tmp/claude-<uid>/probe.XXXXXX`, since `$(id -u)`
hides it too — and keeps every other path relative. A probe asking only what `add -A` would stage
runs no `add`: `git ls-files --others --exclude-standard` lists the same untracked set, ungated
(all three measured 2026-09-23). `GIT_GATE_DISABLE=1` is the control. Under auto mode Claude
cannot edit the hook or `permissions.ask`, even with a verbal grant: hand the owner an apply script.

## `settings.local.json` merge contract

Adding to `.claude/settings.local.json` or `~/.claude/settings.json`: read, union, write back —
never overwrite wholesale. Union `permissions.allow` by exact-string dedup; overlapping patterns
such as `Bash(lsof -nP -iTCP -sTCP:LISTEN)` and `Bash(lsof -nP -iTCP:6550*)` are different
commands, so keep both. Preserve every other top-level key (`model`, `theme`, `hooks`,
`enabledMcpjsonServers`, the baseline).
