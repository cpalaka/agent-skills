#!/usr/bin/env bash
#
# godot-gotchas-scan.sh — the project's host-neutral entry point to the godot-gotchas
# pre-commit scan.
#
# The gotchas skill is installed per host under a different root, so no project rule can
# name one of those roots and stay true on the other. The DoD and VERIFY_EXAMPLES name
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
# Exit 2 with a single stderr line naming both roots tried means the scan did NOT run:
# neither root holds a RUNNABLE `scripts/precommit-scan.sh`. That is a broken install to
# fix, never a clean verdict.
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

exec "$scan" "$@"
