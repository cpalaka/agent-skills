#!/usr/bin/env bash
# Bootstrap the Chunk library on a new macOS/Linux machine.
#
# Prereq: this repository is already cloned. The clone may live anywhere — the script takes the
# location from its own path, so run it from wherever you put the clone:
#
#     ./bootstrap.sh
#
# It creates two symlinks into this clone's chunks/ directory, one per host:
#
#     ~/.claude/chunks   so Claude Code's @~/.claude/chunks/<name>.md imports resolve
#     ~/.codex/chunks    so a Codex AGENTS.md read directive for ~/.codex/chunks/<name>.md resolves
#                        (Codex does not expand @-imports; it is pointed at the files explicitly)
#
# Idempotent: a link already pointing at this clone is left alone. A link pointing somewhere else,
# or a real file or directory in the way, is reported and left alone — clearing it is your call.
# Each host is attempted independently, so a failure on one still reports the state of the other.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHUNKS="$REPO_DIR/chunks"

warn() { echo "$*" >&2; }

if [ ! -d "$CHUNKS" ]; then
	warn "error: $CHUNKS not found — run this from the clone."
	exit 1
fi

# Every step that can fail is checked. Calling this in a `|| rc=1` context disables errexit for
# the whole body, so an unchecked mkdir or ln would fall through to the success message and
# report a link it never created — measured, before the checks were added.
link_chunks() {
	local link="$1"
	local cur

	if ! mkdir -p "$(dirname "$link")"; then
		warn "error: cannot create $(dirname "$link")."
		return 1
	fi

	if [ -L "$link" ]; then
		cur="$(readlink "$link")"
		if [ "$cur" = "$CHUNKS" ]; then
			echo "ok: $link already -> $CHUNKS"
			return 0
		fi
		warn "error: $link is a symlink to $cur (not $CHUNKS). Remove it and re-run."
		return 1
	elif [ -e "$link" ]; then
		warn "error: $link exists and is not a symlink. Move it aside and re-run."
		return 1
	fi

	if ! ln -s "$CHUNKS" "$link"; then
		warn "error: could not link $link -> $CHUNKS."
		return 1
	fi
	echo "linked $link -> $CHUNKS"
}

rc=0
link_chunks "$HOME/.claude/chunks" || rc=1
link_chunks "$HOME/.codex/chunks" || rc=1
[ "$rc" -eq 0 ] || exit 1

echo
echo "Claude Code: the imports are external includes, so each consuming project asks for approval"
echo "once on first launch; approve, then restart the session so they load."
echo "Codex: no approval — its AGENTS.md names the files and reads them directly."
