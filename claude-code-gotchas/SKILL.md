---
name: claude-code-gotchas
description: Claude Code failures that report success, by symptom: sandbox, shell, git, subagents, reading a result, Codex, permissions. Consult before trusting a clean reading from a sandboxed command, before any squash-merge or push of main, before dispatching a subagent, before filing an absence claim ("not in the repo", "dead code", "no regression"), when a command fails `Operation not permitted`, when a gate passes on a tree you expected red, and when a settings key has no effect in a desktop-app session.
---

# Claude Code gotchas

Failures of the Claude Code harness, its sandbox, and the git and shell under it, each observed
first-hand. Most rows share one shape: the command exited 0, the output looked right, and the world
was in another state.

## How to use

Find the row whose symptom matches; its Fix column is the fix. A Fix ending in `→ R` has a recipe
in [`RECIPES.md`](RECIPES.md) under the same id. When a row is close but not exact, read its whole
section: neighbours share a cause.

One question sits under every row: **could more than one state of the world produce this reading?**
A check that cannot go red proves nothing (E1).

## A. Sandbox

| # | Symptom | Cause | Fix |
|---|---|---|---|
| A1 | A file you just wrote reads back missing or stale; a well-formed clean verdict about a different checkout; a commit message handed to `git push` as a refspec | `$TMPDIR` is two directories: `/tmp/claude-<uid>` sandboxed, `/var/folders/…/T` not | Write, use and verify in one sandbox mode; anything a verdict, commit or push rests on lives at a path inside the repo → R |
| A2 | `cannot create temp file for here document`; a heredoc-fed loop runs zero times; a gate exits 0 with 1 of 28 checks run | Heredocs need a temp file; bash tries `/tmp`, `/var/tmp`, then the cwd, never `$TMPDIR`, and all three are denied when the cwd is outside the sandbox write set | Run sandbox-off, or feed loops with `< <(printf '%s\n' "$VAR")` and bodies through `python3 -c`; read a gate's executed-check count → R |
| A3 | Fixtures or a `git init` appear in the repo you stand in, every step green | A sandboxed `mktemp -d` can return empty, and `cd ""` succeeds in place | Guard `[ -n "$D" ] && [ -d "$D" ]` before use; recover with `git reflog`, `git reset --soft`, `git checkout <commit> -- <file>` |
| A4 | `ps`, `pgrep`, `kill -0` report a live process dead (`sysmond service not found`) | The sandbox hides processes | Re-check sandbox-off before re-dispatching, or watch the output file grow, calibrated on a PID you know is alive |
| A5 | `diff <(git show REF:f) f` fails `/dev/fd/63: Operation not permitted` | Process substitution is denied as a path argument, allowed as stdin | `git diff REF -- f`, or `< <(…)` |
| A6 | A background job's temp writes fail; a stdin-reading CLI hangs in a background command | `$CLAUDE_JOB_DIR/tmp` is denied; the harness appends `< /dev/null` to foreground commands only | Write to `$TMPDIR`; put `< /dev/null` on the first stage of a background pipeline |
| A7 | `git status` at session start lists dirty files that read clean minutes later | A denied index refresh, by the evidence | Re-run and reconcile against `git log` before acting on a surprising dirty tree |
| A8 | A command fails from the first attempt with an error that never mentions the sandbox | It needs the bypass | Bypass the commands in the recipe; plain `git push` and `fetch` over HTTPS need none → R |
| A9 | `fatal: failed to store: 100001` on fetch, pull or push; `could not write config file` on `branch -d` | Only the credential cache, commit-graph or config write failed; the ref operation landed | Read the ref-update line, confirm with `git status -sb`, do not retry (a retry double-applies). zoxide's chpwd hook aborting `cd x && …` is the same class: use the tool's persistent cwd or `bash -c` |
| A10 | A "sandboxed" probe succeeds and proves nothing; a fresh worktree session runs unsandboxed and nobody notices | The sandbox baseline lives in gitignored `settings.local.json`, which no clone or worktree carries | Read `.sandbox` in every settings file before quoting a result; `cp .claude/settings.local.json <worktree>/.claude/` before launching there |
| A12 | A branch switch half-completes and the next merge aborts | A denied checkout of a tracked file under `.claude/` moves HEAD and reverts everything else | Assess with read-only git, then sandbox-off `git checkout -- <file>` and redo |
| A13 | A command that must always bypass is still sandboxed | `sandbox.excludedCommands` matches only a command that starts with the entry | A PreToolUse hook on Bash that sets `dangerouslyDisableSandbox`, gated on `cwd` |
| A14 | `cd <worktree> && <gate>` is refused sandbox-off; the same gate by absolute path is allowed | Auto mode classifies compound commands | Invoke by absolute path without `cd`; then read the tool's own `project=` line, since a tool resolving from `$PWD` scans the wrong checkout |
| A15 | Two Bash calls in one message, each `cd <dir> && cat > FILE`; the second write lands in the first directory, both reporting the expected size | Parallel Bash calls share one shell cwd | Write by absolute path, or in one sequential call; verify each file's first lines before committing (measured 2026-10-22) |

## B. Shell

| # | Symptom | Cause | Fix |
|---|---|---|---|
| B1 | `VAR=value cmd "$VAR"` hands `cmd` an empty argument; a grep over the dead run reads clean | Expansion happens before the prefix applies | `export VAR=value` on its own line first |
| B2 | `unexpected EOF` from a heredoc inside `$(...)` in an `&&` chain | The harness wrapper | Write the body to a file inside the repo and `-F` it |
| B3 | `$(…)` and backticks inside a heredoc body expand | Unquoted delimiter | `<<'EOF'`, always |
| B4 | `sort`, `comm`, `join` disagree; `awk` dies `towc: multibyte conversion failure` with exit 0 and nothing printed; `[A-Z]` matches `abc` | Locale: macOS bash 3.2 collation and UTF-8 awk | One `LC_ALL=C` over the whole pipeline, `awk` over prose included |
| B5 | An unattended tool (launchd, a hook) mangles non-ASCII | No UTF-8 locale there | Pin the encoding in the tool (`encoding="utf-8"`, `ruby -E UTF-8`); red-test with `LANG=en_US.US-ASCII`, since Python 3.7+ turns on UTF-8 mode under `LC_ALL=C` |
| B6 | `grep -c` over a transcript dies `exceeds complexity limits`; a count comes back empty rather than zero; a NUL byte makes a file unsearchable | The harness `grep` is ugrep (`-I --ignore-files`); `/usr/bin/grep` rejects `{N}` above 255; a path starting with `-` (every `~/.claude/projects/-Users-…`) parses as an option; `grep -c` exits 1 on zero | `/usr/bin/grep` for long alternations; `./`, `--`, `-e` for paths; `c=$(grep -c … 2>/dev/null); c=${c:-0}`; `command grep`, `awk` or `rg` where a negative is load-bearing |
| B7 | A recursive search over `~/.claude/skills` or `~/.agents/skills` finds nothing | Both greps skip symlinked directories under `-r`; `rg` needs `-L` | ugrep `-R`, `/usr/bin/grep -RS`, or glob the files so the shell resolves the link |
| B8 | `cmd \| grep X \|\| echo "no X"` reports clean when `cmd` failed | `2>/dev/null` hid why; absent output is not evidence | Check `cmd`'s exit status first; print the table and read it |

## C. Git

| # | Symptom | Cause | Fix |
|---|---|---|---|
| C1 | A peer's staged files rode onto `main` and back | `git status; git checkout main && …` in one call runs the checkout before you read the status | `git status -sb` in its own call; act on it before any switch |
| C2 | Heavy screenshots or fixtures live in `main`'s history forever | A squash carries only the branch's final tree; deleted after the merge, the bytes stay | Prune throwaway artifacts on the branch before the squash |
| C3 | `git branch -d` refuses a branch you just squash-merged; a diff against `main` says commits are missing | A squash leaves no merge commit, and once `main` moves a diff against it is wrong | `git diff --quiet <squash-sha> <branch> && git branch -D <branch>` |
| C4 | A peer's commit on your branch vanishes under your squash subject; merge, commit and diff all look right | In a shared checkout a peer commits to whatever branch is checked out | `git cherry -v main <branch>` first; their commits print `-`; cherry-pick them to `main` before squashing |
| C5 | Asset files you restored come back with preview state; valid syntax, nothing flags it | An open Godot or Unity editor flushes in-memory copies on its own schedule | `git status --porcelain` immediately before the merge must list only your files; close the editor for the merge window; reload from disk after |
| C6 | A commit lands on the wrong branch and succeeds | A peer switched the branch under you | Read the branch name in `git commit`'s first output line, every commit |
| C7 | `git commit -F file` produces a one-line or body-less commit, exit 0 | The file's first line is the subject, then a blank line, then the body | Write the file at the repo root (A1), untracked, and remove it after |
| C9 | A sign-off approves a tree that is not the one you merge | The base moved after approval; `merge-base --is-ancestor` answers "can it merge", never "is this what was reviewed" | Rebase and re-run the verify command before merging |
| C10 | Another worktree holds `main`, so your merge is blocked; or your push carries a sibling's unpushed commits | A branch is checked out in one worktree at a time | Build the squash on `origin/main` and push the SHA → R |
| C11 | Before pushing `main`, `git log origin/main..main` lists more than your squash | Another session's unpushed work | Stop and ask. Never reset or rebase it away |
| C13 | A dirty tree you did not make | A second writer on the checkout | Run nothing from {`stash`, `reset --hard`, `clean`, `checkout -- <file>`, `restore`, `rebase`, any branch switch, `branch -D`}; park and ask the peer to commit |
| C14 | A destructive git command passes the destructive-gate hook | The hook classifies by regex, so an unlisted form passes; `git add <path>` is ungated by design; scratchpad paths are exempt | Extend the classifier and run its `--test`; never add `gh` globs to `permissions.allow` → R |
| C15 | Half a branch's commits vanished from a "rebase" | `git rev-parse HEAD` in a paused rebase shows the upstream commit; the rejection was three lines up | Read the whole output, and `git status` before trusting HEAD |

## D. Subagents

| # | Symptom | Cause | Fix |
|---|---|---|---|
| D1 | A review subagent ran on the parent's expensive model | A bare `Agent` spawn inherits the parent's model, and so does an unresolvable agent name, silently | Name a definition that exists or pass `model` explicitly; the tool reports neither → R |
| D2 | An edited agent definition is served stale for minutes; a renamed one answers under the old name | Lazy registry refresh | Have the agent quote its changed line back; verify a changed `model:` from a fresh session |
| D3 | A visual acceptance "passed" with nobody having seen the page | A subagent's screenshot never reaches the parent | Drive the browser and any eyeballing in the parent |
| D4 | A subagent's permission dialog holds forever; approval and denial return byte-identical text | Dialogs surface in the owner's main UI, never routed to the dispatcher | Read the facts from git and the filesystem, never from the subagent's report; keep subagents on pre-allowed commands |
| D5 | A subagent reports an `@import` block that is stale or absent | It receives its parent's memoized import walk | Settle with a live probe: the body is in the injected context or it is not |
| D6 | `<!-- markers -->` your tool looks for are gone from the injected copy | The harness strips HTML-comment lines from injected files | Read markers from disk |
| D7 | A Workflow script's `args` list arrives as a string | Stringified JSON | Pass arrays as real JSON values |
| D8 | A subagent's self-reported metric is wrong | It is a claim | Re-run the gate yourself, never by the agent that wrote the diff |

## E. Reading a result

| # | Symptom | Cause | Fix |
|---|---|---|---|
| E1 | A post-fix number looks right | A check that cannot go red reports success and discriminates nothing | Red it first → R |
| E2 | `0 failures over 0 checked` prints a pass; `jq all()` is true on `[]`; `gh issue list` stops at 30 | Zero denominator | Print the item count beside the verdict; read a zero denominator as not run |
| E3 | An oracle says success while the thing never happened | Oracles report their own state, not the artifact's | Read the artifact: the log line, the byte count, the `time=` reached → R |
| E4 | "Not in the repo", "dead code", "nothing owns X" is wrong | The claim spans the project; the instrument's reach was smaller | Name the instrument's reach in the claim → R |
| E5 | A criterion quoting `27 of 28` can never pass again | The number belongs to one run of one tree | Criteria quote the predicate, never a gate's printed count |
| E6 | Reviewers read eleven acceptance criteria and missed five defective ones | Reading cannot see what executing does | Execute every criterion against the live system |
| E7 | Two passes agree | Same instrument, or one copied the other: one reading | Ask what single artifact both read |
| E8 | A compaction summary's figure enters a commit | Compaction keeps conclusions and drops derivations | Re-derive any figure before it enters a record |
| E9 | A multi-edit "succeeded" | An all-or-nothing edit dropped on one drifted anchor; a failed `git add` did not stop the chained `git commit` | Read `git show --stat` and the diff back, never the exit code |
| E10 | A regex list does not catch its own text | Most patterns do not match their own source (43 of 48 identity regexes) | Build the canary from what the pattern matches; read the match count |
| E11 | A leak scan over `.scratch/` reports clean on anything | Gitignored paths are outside the object store the guard scans | Scan the bytes you are about to send, not the store |

## F. Codex

| # | Symptom | Cause | Fix |
|---|---|---|---|
| F1 | `codex exec` hangs | stdin left open | `< /dev/null` on the call |
| F2 | `codex exec` exits 0 with zero bytes | Missing `--skip-git-repo-check`, not authenticated, or quota | Assert `wc -c` on the output; the exit code is worthless |

## G. Settings and permissions

| # | Symptom | Cause | Fix |
|---|---|---|---|
| G1 | A rule in `permissions.allow` runs destructive writes ungated in every session and subagent | Allow overrides the classifier; `Bash(gh issue *)` cannot tell `list` from `edit` | Allow only specific read-shaped commands, named |
| G2 | `Bash(*&& git stash push*)` fires on `grep -c 'git stash push --'` | A leading-`*` rule is a raw substring match on the command text | Anchor rules; test a rule by side effect in a scratch repo, never by exit code → R |
| G3 | A settings edit clobbers `model`, `hooks`, `theme` | Wholesale overwrite | Read, union, write back; dedup `permissions.allow` by exact string |
| G4 | A rule you expected to fire did not | `deny > ask > allow`; a hook's `ask` outranks an allow; `timeout nice nohup env` are stripped before matching, `npx docker exec find -exec` are not | Match against the stripped command |
| G5 | A `PostToolUse` hook never sees a failed Bash call | A non-zero exit fires `PostToolUseFailure` | Register both |
| G6 | `deniedMcpServers` names a claude.ai connector (`"claude.ai Gmail"`), yet a desktop-app session has it connected with every tool | The desktop app delivers connectors in-process as `sdk` servers; no MCP setting or `managed-mcp.json` reaches them. The key acts only where Claude Code fetches connectors itself (terminal) | Desktop: the composer's + menu connector switch, or `set_session_connector_enabled`, which also sets the default for new sessions; or disconnect at claude.ai/customize/connectors (measured 2026-10-25) |
| G7 | `skillOverrides` sets `docs: off`, `pdf: off`; the skills listing still carries `anthropic-skills:docs` with its full description | `anthropic-skills:*` are claude.ai-synced skills, delivered to the desktop app as a plugin; `skillOverrides` matches local skill names and skips plugin skills | Turn the skill off at claude.ai > Settings > Skills; `pdf` and `xlsx` always sync. `/doctor` prices the listing |
