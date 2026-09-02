---
name: sandbox-and-permissions
description: Claude Code sandbox denials and permission-allowlist safety. Use when a Bash or git command fails "Operation not permitted", when a branch switch half-completes and the next merge aborts, when a sandboxed command returns a clean answer that is wrong, BEFORE adding any entry to `permissions.allow` or writing a `.claude/settings.local.json`, and when a background job must edit files (worktree isolation, EnterWorktree, compound-Bash refusals).
---

# Sandbox denials & permission-allowlist safety

The `sandbox-auto` chunk carries the session-init baseline (sandbox on, `auto` mode, where the
settings file lives). This Skill carries what you need only once a denial fires, or you are about
to edit permissions.

## A git op half-switched the tree

The sandbox's `denyWithinAllow` blocks writes to `.claude/` (and `.git/config` / `.git/hooks`)
but **not** `.git/objects` / `.git/refs`. So `git commit` succeeds under the sandbox, while a
`checkout` / `switch` / `merge` / `rebase` / `stash pop` that must modify a **tracked** file under
`.claude/` fails `Operation not permitted` and **half-switches**:

- HEAD moves to the target
- other files revert to the target branch
- the denied file is left dirty — so the next `merge` aborts

**Recover:** `git checkout -- <denied-file>` with the sandbox off, then redo the operation with
the sandbox off. Read-only git (`status` / `log` / `diff`) is always safe — assess first, don't
guess at the state. (Measured 2026-07-03.)

## Background-job worktree isolation

Background sessions isolate into a git worktree under `.claude/worktrees/` by default; a project
opts out with `worktree.bgIsolation: "none"` in its `.claude/settings.json` — few projects set
this, check before assuming. (Key name verified against the official docs 2026-08-31.)

**The opt-out must PRE-EXIST THE SESSION.** Settings load at session start, so in a dir that
wasn't yet a repo the setting reads as absent no matter when you write it — a bg job that
`git init`s mid-session is isolation-locked for that whole session. Plan for the consequences
instead of fighting them: `EnterWorktree` becomes the only sanctioned way to edit, and the guard
refuses compound Bash (heredocs, `&&` chains, `agent-browser eval`, `for` loops) — budget one
command at a time and Write throwaway scripts to a file.

Merging back is the user's call; on an unmoved base it's `git merge --ff-only <branch>` from the
main checkout after `ExitWorktree`. (Measured 2026-08-10.)

## A denial that reads as a bug in your own code

**`socket.bind` is denied even on 127.0.0.1.** Any local dev server — `python -m http.server`,
anything that listens — dies at startup with
`PermissionError: [Errno 1] Operation not permitted`. The network policy is host-allowlist-based
with no carve-out for *listening* sockets, so the failure surfaces inside your own server code and
reads as a server bug on first look.

Use `dangerouslyDisableSandbox` from the **first** attempt for any local-server launch; don't burn
the sandboxed try. Curl/reads against an already-running server needed unsandboxed runs too, in
practice. (Measured 2026-07-18 on a project.)

The error string varies by runtime and none of them say "sandbox": Node/vite reports
`Error: listen EPERM: operation not permitted ::1:5173` on `npm run dev`, Python reports
`PermissionError: [Errno 1]`. Same denial, same fix. Build / test / typecheck / lint do **not**
need the bypass — only the listen. (Measured 2026-06 on a project.)

## The bypass catalog — what actually needs `dangerouslyDisableSandbox`

The writable allowlist is roughly `.`, `$TMPDIR`, `/tmp/claude`, `~/.npm/_logs`, `~/.claude/debug`.
Anything a tool caches under `$HOME` outside that list is denied. These are `$HOME` facts — true in
every project, not per-repo:

| Command | Denial | Scope of the bypass |
|---|---|---|
| `npm install` / `npm i <pkg>` | `EPERM open ~/.npm/_cacache/tmp/…` | install/add only |
| `bun install` / `bun add` | `bun is unable to write files to tempdir: PermissionDenied` (`~/.bun/install/cache`) | install/add only — `bun run` / `bun build` are fine |
| `agent-browser <any subcommand>` | `Socket directory '~/.agent-browser' is not writable` | every invocation — it needs its control socket |
| `gh <anything>` | `tls: failed to verify certificate: x509: OSStatus -26276` | every invocation, see below |
| `git add` / `git commit` **in a worktree** | `fatal: Unable to create '<main>/.git/worktrees/<name>/index.lock'` | every write-side git op from a worktree |
| any process that `listen`s | `EPERM` / `Operation not permitted` on bind | the launch |

**`gh` is not read-vs-write.** `api.github.com` is on the network allowlist, so this is not host
blocking: `OSStatus -26276` is macOS Security refusing gh's Go TLS stack access to the keychain
trust store. It was recorded as a writes-only need until **2026-07-28**, when `gh issue list
--state open` — a pure read — failed identically. **The discriminator is the graphql endpoint, not
the verb.** Assume any `gh` call needs the bypass; any doc still saying "writes only" is wrong.

**Plain `git` over HTTPS is NOT affected.** `git push` / `git fetch` use git's own TLS, not gh's
keychain path — do not pre-emptively disable the sandbox for them. (Measured 2026-06-08.)

**A worktree is the exception that catches people**, because the sandbox grants the main
`<repo>/.git` but not `<repo>/.git/worktrees/<name>/`. Anything touching `index.lock` or
`FETCH_HEAD` under `worktrees/` hard-fails, including the `backlog` CLI's automatic
`git fetch origin --prune`. Where worktrees are the normal working mode, that is every commit.

## Cosmetic denials — the operation SUCCEEDED, do not retry

The counterpart to the catalog above, and the pair is the point: **read the payload line, not the
`fatal:`.**

- **`fatal: failed to store: 100001`** on `git fetch` / `pull` / `push`. The transport worked; the
  denied write is git's credential-helper / commit-graph cache. Ground truth is the ref-update line
  (`f1540d8..6db63c0  main -> main`) or `Already up to date`; confirm with `git status -sb`. Do NOT
  bypass — the op already ran, and a retry can double-apply. (Measured 2026-07-02.)
- **`could not write config file .git/config: Operation not permitted`** on `git branch -d/-D` and
  other ref edits. The ref operation succeeds; only the optional config prune is blocked.
- **zoxide's `chpwd` hook** can't write `~/Library/Application Support/zoxide/…`, and under zsh that
  **aborts the whole compound command** — `cd web && npx vitest …` exits non-zero *before* vitest
  runs. This is **not** a bypass case: vitest is fine sandboxed, only the `cd` side effect fails.
  Fix by dropping the login shell (`bash -c 'cd /abs/path && …'`, no chpwd hook) or by relying on
  the Bash tool's persistent cwd instead of `cd`.

**Tell the two classes apart by the path in the message.** `index.lock` / `FETCH_HEAD` under
`worktrees/` = real failure that wrote nothing, bypass and retry. Commit-graph, credential cache,
`.git/config`, zoxide DB = cosmetic, ignore.

## `$TMPDIR` is not one directory

A sandboxed Bash call sees `/tmp/claude-<uid>`; a `dangerouslyDisableSandbox` call sees the real
user `$TMPDIR` (`/var/folders/…`). **A file written by one is not visible to the other** — and the
failure wears the costume of a much scarier bug: a calibration that backs up a file, runs the
sandbox-off test, restores, then verifies with a sandboxed `cmp` reports a *missing backup*, which
reads exactly like "the restore never happened and a corrupted source is in the tree".
(Measured 2026-08-01.)

**The worse form returns wrong content, not missing content.** `$TMPDIR` is also shared *between
sessions*: a squash SHA written to `$TMPDIR/sq.txt` sandboxed and read back sandbox-off returned an
unrelated session's leftover commit message, and the push died `fatal: invalid refspec`. It failed
loudly only because a commit message cannot parse as a refspec — a stale file holding a plausible
SHA would have pushed the wrong tree under a sign-off that never covered it.
(Measured 2026-08-02.)

This directly qualifies the general "write the commit body to `$TMPDIR/f.txt` in its own call and
`-F` it in the next" rule: correct for the heredoc problem it solves, unsafe the moment the two
calls straddle a sandbox boundary. **Keep write → use → verify in calls of the same sandbox mode**,
better in one call; or use an absolute path under the repo; or give the temp file a session-unique
name. Never let a `git push` argument come from a `$TMPDIR` file written by a differently-sandboxed
call.

## Process substitution as a path ARGUMENT is denied

`cmd <(…)` fails `"/dev/fd/63: Operation not permitted"`. Redirected to **stdin** (`< <(…)` — the
documented loop workaround) `/dev/fd` is readable; handed to a command as a **path argument** it is
not. So `diff <(git show REF:file) other` looks safe by analogy with the working form and fails at
run time. Use tool-native forms (`git diff REF -- file`) or `$TMPDIR` files — subject to the
`$TMPDIR` rule above. (Measured 2026-08-03.)

## Silent Bash traps — no denial, no error, wrong result

The sandbox or harness causes each of these, but none prints a denial.

- **Here-strings (`<<<`) and heredocs need a `/tmp` temp file the sandbox denies**, so a loop
  fed by one runs ZERO times with no loop-level error. Use `< <(printf '%s\n' "$VAR")`.
- **A heredoc inside `$(...)` dies when the command is `&&`-chained** — the harness's `eval`
  wrapper can't parse it and the error is a useless "unexpected EOF". Write the body to
  `$TMPDIR/f.txt` in its own call, then `-F`/`$(cat …)` in the next — subject to the
  `$TMPDIR` sandbox-boundary rule above.
- **An UNQUOTED heredoc delimiter (`<<PY`) expands backticks and `$(…)` inside the body** —
  words silently vanish from what you write while the script prints success. Quote it
  (`<<'PY'`) and pass vars via the environment.
- **Background jobs:** `$CLAUDE_JOB_DIR/tmp` is DENIED even though the bg-job prompt directs
  you to it — use `$TMPDIR`. And the harness appends `< /dev/null` to FOREGROUND evals only,
  so a stdin-reading CLI hangs silently in a background command while the identical foreground
  probe passes. Write `< /dev/null` explicitly, on the FIRST stage (or `exec < /dev/null` at
  the top) — appended to a pipeline it redirects only the last stage, so
  `ls … | head < /dev/null` prints nothing and reads as an empty directory.
- **A sandboxed `mktemp -d` FAILS leaving the variable EMPTY, and `cd ""` SUCCEEDS staying
  put** — any script shaped `D="$(mktemp -d)"; cd "$D"` builds its fixtures, or runs its
  `git init`, in the repo you are standing in, with every later step reporting success
  (`set -u` can't catch a set-but-empty var). Treat any mktemp-and-cd script as carrying this
  bug until read; guard `[ -z "$D" ] || [ ! -d "$D" ]` and refuse, naming the dir at risk.
  Recover via `git reset --soft` + `git checkout <commit> -- <file>`, checking
  `git log`/`reflog` before assuming loss.
- **Locale:** macOS system bash is 3.2 (no `declare -A`); `sort` dies on non-ASCII input
  without `LC_ALL=C`, and `comm`/`join` must run under the SAME locale as the sort that fed
  them — mismatched collation silently misaligns.

(Measured 2026-07-26, 07-29, 07-30, 08-02, 08-25, 08-30; each burned a real session.)

## Not every hang is a denial

Before reaching for the bypass, check whether the tool is broken here independent of the sandbox.
**Chrome `--headless --screenshot` hangs indefinitely on macOS** — measured against a 64px
solid-colour page with a fresh `--user-data-dir` and the **sandbox off**. Don't burn a flag-tuning
loop on it. The working SVG→PNG rasterizer is `qlmanage -t -s <size> -o <dir> file.svg` (output
lands as `<name>.svg.png`); note it composites over **opaque white** while still reporting
`hasAlpha: yes`, so verify transparency by decoding pixels, never by `sips -g hasAlpha`.
(Measured 2026-08-25.)

## Sandbox FALSE READS — the answer comes back clean and is wrong

These are worse than a denial, because a denial announces itself and these do not.

- **`ps -p` / `pgrep` cannot read the process list** under the sandbox (`sysmond service not
  found; Cannot get process list`). A `ps || echo dead` fallback then reports a **LIVE** process
  as dead. Re-check liveness with the sandbox **off** before declaring any process dead or
  re-dispatching its work. **`kill -0 <pid>` fails the same way** — the measured probe table
  covers all three, so switching probes does not escape it.

  **Remedy for a Monitor or heartbeat: watch output-file SIZE GROWTH instead** — reads are
  unrestricted, so this needs no bypass. Require N consecutive stable samples before declaring done,
  and calibrate against a known-alive PID first. What caught the 2026-07-27 case was that "finished in
  1 minute, 0 bytes stdout, 221 KB stderr" is *incoherent* — a plain "finished" would have passed,
  and the recovery action (relaunch) would have clobbered two healthy running reviews.
- **`git status` / `git diff` can return a stale phantom-dirty view** at session start: files
  committed hours earlier showed as modified + untracked, then the same commands read clean minutes
  later. Root cause unproven; suspect a denied index-refresh write, so status is computed against a
  cold index. Before acting on a surprising dirty tree — **especially before committing what looks
  like "someone's uncommitted work"** — re-run it and reconcile against `git log` / `git ls-tree`.

  This is the empirical half of the rule against destructive git recovery on a dirty tree that
  isn't yours: the tree you are about to "recover" may not be dirty at all.

(Both measured 2026-07-18 on a project.)

## Allowlist hygiene — keep destructive globs OUT

`permissions.allow` **overrides the classifier**. Anything it matches runs silently with no
gate, in every session and every subagent. That is the whole risk model:

- **Keep `git push` off the allowlist.** Pushes must surface to the classifier or a prompt,
  so no autonomous loop or subagent can ever push without scrutiny.
- **Keep `gh` write globs off.** `Bash(gh pr *)` or `Bash(gh issue *)` pre-authorizes
  `gh pr create`/`merge` and `gh issue create`/`edit` — a `*` glob cannot tell a read from a
  write. Allowlist only the specific read subcommands (`gh pr view`, `gh issue list`, …) and
  let every write fall through.
- **General rule:** never allowlist a broad or destructive glob. Specific, safe, read-shaped
  commands only. The destructive ops themselves (force-push, tag/remote deletion, `gh`
  writes) are gated by the `git-confirm-destructive` chunk.

**Audit an existing allowlist against this** before adding to it — an entry that predates the
rule is exactly as dangerous as one you'd add today.

## `settings.local.json` merge contract — union, never clobber

Any time you add to `.claude/settings.local.json`, at init or later:

- **Union `permissions.allow` with strict exact-string dedup.** Do NOT semantically merge
  overlapping `Bash(...)` patterns: `"Bash(lsof -nP -iTCP -sTCP:LISTEN)"` and
  `"Bash(lsof -nP -iTCP:6550*)"` are different commands — keep both. Collapsing them changes
  the permission surface.
- **Preserve every other top-level key** (`model`, `theme`, `hooks`, `enabledMcpjsonServers`,
  and the `sandbox` / `defaultMode` baseline) untouched.
- **Never overwrite the file wholesale.** Read → union → write back.

The same contract applies to the user-level `~/.claude/settings.json`.
