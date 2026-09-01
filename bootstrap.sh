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
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHUNKS="$REPO_DIR/chunks"

[ -d "$CHUNKS" ] || { echo "error: $CHUNKS not found — run this from the clone." >&2; exit 1; }

link_chunks() {
  link="$1"
  mkdir -p "$(dirname "$link")"

  if [ -L "$link" ]; then
    cur="$(readlink "$link")"
    if [ "$cur" = "$CHUNKS" ]; then echo "ok: $link already -> $CHUNKS"; return 0; fi
    echo "error: $link is a symlink to $cur (not $CHUNKS). Remove it and re-run." >&2
    return 1
  elif [ -e "$link" ]; then
    echo "error: $link exists and is not a symlink. Move it aside and re-run." >&2
    return 1
  fi

  ln -s "$CHUNKS" "$link"
  echo "linked $link -> $CHUNKS"
}

rc=0
link_chunks "$HOME/.claude/chunks" || rc=1
link_chunks "$HOME/.codex/chunks" || rc=1
[ "$rc" -eq 0 ] || exit 1

echo
echo "Per consuming project: approve the external-includes prompt once on first launch (then restart"
echo "so the imports load). Headless/automation runs must pass: --add-dir ~/.claude/chunks"
