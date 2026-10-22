# Recipes

Bodies for the rows in [`SKILL.md`](SKILL.md) whose fix is longer than a line. Ids match.

## A1 Two temp directories

Sandboxed commands see `$TMPDIR` as `/tmp/claude-<uid>`; sandbox-off commands see
`/var/folders/…/T/`. A file written in one mode is invisible in the other, and a stale file from an
earlier session can sit at the same name in either. So a draft, a commit-message file, a scan body,
anything a later command reads, lives at a path inside the repo (untracked, removed after), or is
written and read in the same sandbox mode within one call. A verdict naming a file you cannot `ls`
from the mode that produced it is about some other file.

## A2 Heredocs outside the write set

Bash writes a heredoc or here-string to a temp file before the command runs. It tries `/tmp`,
`/var/tmp`, then the current directory, never `$TMPDIR`. In the checkout, or with the cwd under
`$TMPDIR`, this works sandboxed. From a sibling worktree, `~/.claude/projects`, or any plain
directory under `$HOME`, every attempt is denied: a `while read` fed by `<<<` runs zero times, and a
gate built from such loops exits 0 having run almost nothing. In order: run the script sandbox-off;
or feed loops with `< <(printf '%s\n' "$VAR")` (process substitution as stdin is allowed, A5) and
pass bodies as `python3 -c` arguments. Read a gate's executed-check count beside its verdict (E2).

## A8 Commands that need the bypass

Their errors never say "sandbox". Bypass from the first attempt:

- `npm install`, `bun install`: EPERM in the cache temp dir
- anything that listens on a port, agent-browser included (socket dir): reads as a server bug
- Blender: Metal crash. Godot headless: SIGSEGV, or `ERROR:` lines a runner reads as FAIL
- Playwright launch: hangs silently for minutes
- `gh` anything: `x509: OSStatus -26276` (keychain)
- write-side git from a worktree: `index.lock` under `.git/worktrees/`

Plain `git push`, `fetch` and `pull` over HTTPS run sandboxed.

## C10 Squash without taking main

When another worktree holds `main`, or a sibling has unpushed local `main` commits that must stay
out of your push, build the squash on `origin/main` and push the SHA:

```sh
git fetch origin
git merge-base --is-ancestor origin/main HEAD   # must exit 0, immediately before the next line
SQ=$(git commit-tree "$(git rev-parse HEAD^{tree})" -p origin/main -F msg.txt)
git push origin "${SQ}:main"
```

If `origin/main` moved after your last rebase, `SQ` silently reverts what the peer landed, and
`git diff $SQ HEAD` passes by construction. The ancestor check is the only thing that catches it.
`msg.txt` lives at the repo root (A1, C7).

The ordinary case, with `main` free: `git status -sb` in its own call (C1); `git cherry -v main
<branch>` (C4); `git status --porcelain` lists only your files (C5); `git checkout main && git merge
--squash <branch>`; review the staged diff, since no merge commit will exist to review later;
commit; `git log origin/main..main` shows one commit (C11); push; `git diff --quiet <sha> <branch>
&& git branch -D <branch>` (C3).

## C14 The destructive-gate hook

`~/.claude/hooks/git-destructive-gate.py` is a PreToolUse hook on Bash. It classifies the git verb
by regex in `classify_git`, so a form it has not seen passes: `git -C /path reset --hard` passed
while `git reset --hard` was listed. `git add <path>` is ungated on purpose. Paths under the
scratchpad are exempt through `scratchpad_only()`. To extend it: add the form to `classify_git`,
run the script with `--test`, then confirm by side effect in a scratch repo (G2). `gh` globs never
go in `permissions.allow`: `Bash(gh issue *)` cannot tell `list` from `edit`.

## D1 Which model a subagent runs on

A bare `Agent` call inherits the parent's model. So does an `Agent` call naming a definition that
does not resolve: no error, the parent's model, the parent's price. The tool result reports
neither. Before dispatching, `ls -l ~/.claude/agents` for the name, or pass `model` explicitly.
Afterwards the truth is in the transcript: the model and `.effort` on every assistant record of
`<session>/subagents/agent-<id>.jsonl`.

## E1 Red it first

A check that cannot fail cannot pass either. Before believing a post-fix number: reproduce the
known-bad to the figure on record, then show the fix turns the same instrument green. For every
predicate an acceptance criterion names, name the mutation that reds it and run it. A control that
fails for some other reason (a composite verdict, a fault absorbed by a clamp or a default, an
expected value read from the thing under test) is not a control for that predicate. Two agreeing
readings from one instrument are one reading (E7).

## E3 Oracles that say success

Each of these returned success while nothing happened: `systemctl show` reporting `success` after a
dependency refused the unit; `tailscale ping` answering pong with all traffic blocked; `ffmpeg -v
error` exit 0 with zero frames decoded; HTTP 200 with the error in the response body. The oracle
reports its own state. Read the artifact the operation was supposed to produce: the log line, the
byte count, the `time=` reached, the file on disk.

## E4 Absence claims

"Not in the repo", "dead code", "nothing owns X", "no regression" are claims about the whole
project made with an instrument that reached part of it. Before filing one: push a known-present
needle through the same pipeline and see it come out (B6, B7, E10); `git check-ignore -v <path>`
before "not present"; `git ls-remote` rather than `git branch -r` for remote branches. Then write
the instrument's reach into the claim: "no match in tracked files under `src/`".

## G2 Testing a permission rule

A rule beginning with `*` is a substring match on the raw command text, so `Bash(*&& git stash
push*)` fires on a `grep` whose pattern contains those words. Anchor the rule to the command start.
Test any rule by its side effect: run the gated command in a scratch repo and look at what changed,
since the hook's exit code and the dialog text read the same for allow and deny (D4).
