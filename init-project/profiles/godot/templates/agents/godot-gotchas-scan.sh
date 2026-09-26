#!/usr/bin/env bash
#
# godot-gotchas-scan.sh — the project's host-neutral entry point to the godot-gotchas
# pre-commit scan.
#
# The gotchas skill is installed per host under a different root, so no project rule can
# name one of those roots and stay true on the other. The project contract's gotcha-scan rule names
# THIS file; this file resolves the skill and hands off.
#
# Resolution order: ~/.agents/skills/godot-gotchas, then ~/.claude/skills/godot-gotchas.
# The host-neutral root is tried first so that, when the two ever stop pointing at the
# same tree, the shared install wins rather than one host's copy.
#
# Everything else belongs to scripts/precommit-scan.sh: this wrapper `exec`s it, so the
# arguments (`--all`, `--worktree`, …), the working directory it scans, stdout — the
# `VERDICT:` line — and the exit code pass through untouched, and it prints nothing of
# its own on success. Read the VERDICT line, never `$?` (the scan's own house rule).
#
# Give it a scope. With no arguments on a clean tree the scan has nothing to check and
# prints `VERDICT: VACUOUS — 0 checks executed against this scope; this is NOT a pass`
# (exit 0). Pass `--all` for the whole project, or the scan's own diff/ref arguments for a
# change; a VACUOUS line in a gate record is a scope mistake, not a clean result.
#
# Exit 2 means the scan did NOT run, and there are two ways to earn it. A single stderr
# line naming both roots tried: neither root holds a RUNNABLE `scripts/precommit-scan.sh`,
# a broken install to fix. A line naming the working directory: this shell cannot create
# heredoc temp files here, so the scan would have run almost nothing. Neither is a clean
# verdict.
#
# The heredoc guard exists because a scan that still uses heredocs FAILS OPEN: its
# per-check file matching reads its file list from a heredoc, and where the temp file that
# heredoc needs is denied, every one of those checks dies and is counted as `skipped (no
# matching files in scope)` — so the scan prints `1 of 28 checks executed` and
# `VERDICT: CLEAN`, a pass that measured almost nothing while its own skip accounting names
# the wrong cause. The verdict line alone never says the scan did not run.
#
# Upstream fixed the cause on 2026-09-14 by converting the heredoc sites to `< <(printf …)`,
# so an up-to-date skill has no such failure mode and the guard skips itself. The guard
# stays for a stale copy on some other host: this entry point resolves the scanner at
# runtime and cannot know which one it got, so it tests the precondition rather than
# assuming it, and retires itself once every install has the fix.
#
# The denial is conditional, so testing it once from the repo root proves nothing. bash 3.2
# does not place heredoc temp files in `$TMPDIR`, and with `/tmp` and `/var/tmp` denied it
# falls back to the working directory — which an agent sandbox may make writable for the
# session's own checkout and NOT for a sibling worktree. Measured 2026-09-14 on macOS, same
# `--all` command: 27 of 28 checks sandboxed from the repo root, 1 of 28 sandboxed from a
# worktree, 27 of 28 unsandboxed from either. Gates run in the worktree under review, so the
# failing cell is the normal one.
#
# The guard is a real heredoc rather than a writability test on a guessed directory: only
# bash knows where it would put the file. bash prints its own `cannot create temp file for
# here document` line to stderr before this script's, which is kept — it names the OS error
# this script only summarizes.
#
# What this guard is NOT: a check that every check ran. A healthy `--all` on a project with
# no `export_presets.cfg` legitimately reports 27 of 28, so "fewer than all checks executed"
# cannot be the failure condition without crying wolf on every honest run. Read the
# `N of M checks executed` line alongside the VERDICT line; CLEAN maps to PASS only when N
# equals M.
#
# The probe is `-f` AND `-x`, not `-f` alone: a present-but-non-executable scanner (a
# copy restored without its mode bit, a checkout on a filesystem that dropped it) would
# otherwise be selected and then die in `exec` with bash's 126 and bash's wording —
# an exit code this script never documents, from a message that names neither root. It
# has to take the same exit-2 path as an absent one. `-f` is kept beside `-x` because a
# directory with the execute bit satisfies `-x` on its own.

set -u

roots=(
	"${HOME:-}/.agents/skills/godot-gotchas"
	"${HOME:-}/.claude/skills/godot-gotchas"
)

scan=""
for root in "${roots[@]}"; do
	if [ -f "$root/scripts/precommit-scan.sh" ] && [ -x "$root/scripts/precommit-scan.sh" ]; then
		scan="$root/scripts/precommit-scan.sh"
		break
	fi
done

if [ -z "$scan" ]; then
	printf 'godot-gotchas-scan.sh: no runnable scripts/precommit-scan.sh under %s or %s; the scan did not run\n' \
		"${roots[0]}" "${roots[1]}" >&2
	exit 2
fi

# Fail closed where the scan would otherwise fail open — see the heredoc note above.
#
# Guarded on the resolved scanner actually USING a heredoc, because the upstream fix landed
# (2026-09-14) and a fixed scan runs correctly in the very cell this guard refuses. An
# unconditional probe would then block a working scan and push people to run unsandboxed for
# no reason — a fail-closed false alarm, which trains the same "ignore it" reflex a
# fail-open one does, just more slowly.
#
# It degrades safely in both directions. If the grep ever misses a heredoc form, the result
# is the old fail-open, no worse than before this guard existed; if it matches something
# harmless, the result is a conservative refusal with an actionable message.
if grep -q '<<[A-Za-z_]' "$scan" 2>/dev/null && ! ( cat <<'HEREDOC_PROBE' >/dev/null 2>&1
probe
HEREDOC_PROBE
) ; then
	printf 'godot-gotchas-scan.sh: this shell cannot create heredoc temp files with cwd %s, so the scan would skip nearly every check and still print VERDICT: CLEAN; the scan did not run. Re-run it outside the agent sandbox.\n' \
		"$PWD" >&2
	exit 2
fi

exec "$scan" "$@"
