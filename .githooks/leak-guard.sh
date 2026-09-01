#!/usr/bin/env bash
# leak-guard — blocks personal provenance from entering this public repository.
#
# Installed as three symlinks in this directory (pre-commit, commit-msg, pre-push) and armed
# per clone with:
#
#     git config core.hooksPath .githooks
#
# That is local config, not tracked, so every fresh clone repeats it. A fourth mode, `scan`,
# audits the whole working tree and is meant to be run by hand before a push or a release.
#
#     .githooks/leak-guard.sh scan
#
# Modes and their scope:
#   pre-commit   the staged content of added/modified files
#   commit-msg   the commit message file (strips a Claude-Session trailer, warns, does not fail)
#   pre-push     the tree at each pushed tip, every commit message in the pushed range, and
#                every blob any commit in that range introduces
#   scan         every tracked file plus every untracked, non-ignored file
#
# Two pattern sources:
#   1. The built-in list below — identity-free, so it can ship in a public repo.
#   2. An identity list that never ships here. It is found through AGENT_SKILLS_IDENTITY_FILE,
#      defaulting to ~/.config/agent-skills/identity-patterns. Without it the hook modes still
#      run the built-in list but warn loudly; `scan` fails outright, because an import audit on
#      the built-in list alone certifies nothing.
#
# Exemptions live in .leak-guard-allow at the repo root: one `<path>:<literal>` pair per line,
# a TAB, then the one-line reason it is safe. Never a line number — those drift.
#
# Note on the built-in patterns: each writes one letter as a single-character class
# (`/[Uu]sers/`), which matches the same text but keeps this file from matching itself. The
# guard scans its own source like any other file; that is deliberate.
#
# Three things this script is careful about, because each one produced a silent false green
# during calibration and each would have let a leak through while reporting "clean":
#
#   * Content always comes from a BLOB ID, never from a path handed back to git. Paths with
#     non-ASCII bytes come back quoted, `git show ":$path"` then fails, and a swallowed failure
#     reads exactly like a clean file. Blob ids also sidestep submodules.
#   * An identity file that exists but yields no patterns is a HARD error, not an empty list.
#     Empty and unreadable both used to certify a tree clean.
#   * `git diff-tree` on a merge commit prints nothing without `-m`, so an evil merge's blobs
#     were invisible to the pushed-range scan.

set -uo pipefail

# Byte semantics, so \b, [[:space:]] and -i folding mean the same thing on every machine. The
# sibling verifier in the private repo pins this for the same reason.
export LC_ALL=C

PROG=leak-guard

# ---------------------------------------------------------------------------- built-in patterns
# Extended regular expressions, matched case-sensitively — the path forms spell both cases
# themselves rather than the whole list running with -i, because `[R]ationale:` is a capitalised
# label and lowercase "rationale:" is ordinary prose.
BUILTIN_PATTERNS=(
	'/[Uu]sers/[A-Za-z0-9._-]+'
	'/[Hh]ome/[A-Za-z0-9._-]+'
	'~/[Cc]laude/'
	'[i]mprovements\.md'
	'\[[i]mp:'
	'[R]ationale:'
	'\.[t]s\.net'
	'[s]sh +(-[^ ]+ +|[^ @]+ +)*[A-Za-z0-9._-]+@[A-Za-z0-9._-]+'
	'claude\.ai/code/[s]ession_'
)

# .leak-guard-allow necessarily contains the strings it exempts, so it cannot be matched like any
# other file. It is NOT blanket-exempt: inside it, only the literals it itself lists are allowed.
# A new marker smuggled into one of its comments still blocks.
ALLOW_FILE_NAME='.leak-guard-allow'

TRAILER_KEY='Claude-Session'
ATTRIBUTION_SETTING='attribution.sessionUrl'
ZERO_SHA='0000000000000000000000000000000000000000'
GITLINK_MODE='160000'

IDENTITY_FILE="${AGENT_SKILLS_IDENTITY_FILE:-$HOME/.config/agent-skills/identity-patterns}"

warn() { printf '%s: %s\n' "$PROG" "$*" >&2; }
die() { warn "$*"; exit 1; }

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git repository"
cd "$REPO_ROOT" || die "cannot enter $REPO_ROOT"

TMPDIR_LG="$(mktemp -d "${TMPDIR:-/tmp}/leak-guard.XXXXXX")" || die "cannot create a temp directory"
[ -n "$TMPDIR_LG" ] && [ -d "$TMPDIR_LG" ] || die "mktemp -d returned an unusable path"
cleanup() { rm -rf "$TMPDIR_LG"; }
trap cleanup EXIT

HITS=0

# Anything the guard cannot read is a hit, never a shrug. A scanner that skips what it cannot
# open is a scanner that certifies whatever it failed on.
unreadable() { # <label> <why>
	printf '%s: BLOCKED  %s: %s\n' "$PROG" "$1" "$2" >&2
	HITS=$((HITS + 1))
}

# ---------------------------------------------------------------------------- identity patterns
IDENT_FILE_PRESENT=0
IDENT_ARGS=()

BUILTIN_ARGS=()
for _p in "${BUILTIN_PATTERNS[@]}"; do BUILTIN_ARGS+=(-e "$_p"); done
unset _p

load_identity_patterns() {
	[ -e "$IDENTITY_FILE" ] || return 1
	[ -r "$IDENTITY_FILE" ] || die "identity file exists but cannot be read: $IDENTITY_FILE"
	local line
	while IFS= read -r line; do
		case "$line" in
			'' | '#'*) continue ;;
		esac
		IDENT_ARGS+=(-e "$line")
	done < "$IDENTITY_FILE"
	# Present-but-empty is worse than absent: absent warns, empty used to read as "all clear".
	[ "${#IDENT_ARGS[@]}" -gt 0 ] ||
		die "identity file has no patterns: $IDENTITY_FILE. Refusing to run — an empty list matches nothing and would certify any tree clean."
	IDENT_FILE_PRESENT=1
	return 0
}

announce_missing_identity() {
	warn ""
	warn "############################################################"
	warn "#  IDENTITY PATTERN FILE MISSING                            "
	warn "#  looked for: $IDENTITY_FILE"
	warn "#  override with: AGENT_SKILLS_IDENTITY_FILE=<path>"
	warn "#  Running the built-in list ONLY. Names, machine names and"
	warn "#  private project names are NOT being checked."
	warn "############################################################"
	warn ""
}

# ---------------------------------------------------------------------------- allowlist
ALLOW_FILE="$REPO_ROOT/$ALLOW_FILE_NAME"
ALLOW_ENTRIES="$TMPDIR_LG/allow"
ALLOW_LITERALS="$TMPDIR_LG/allow_literals"
: > "$ALLOW_ENTRIES"
: > "$ALLOW_LITERALS"

# Entry syntax: <path>:<literal><TAB><reason>
#
# The reason is on the entry's own line, deliberately. An earlier draft took it from the comment
# line above, and its own calibration caught the hole: this file's header comment silently counted
# as the reason for the first entry, so an unexplained exemption passed. A tab cannot appear in a
# match — no pattern matches one — so splitting on the first tab is unambiguous.
load_allowlist() {
	[ -f "$ALLOW_FILE" ] || return 0
	local tab line pair reason lineno=0
	tab="$(printf '\t')"
	while IFS= read -r line; do
		lineno=$((lineno + 1))
		case "$line" in
			'' | '#'*) continue ;;
			*"$tab"*) ;;
			*) die "$ALLOW_FILE_NAME line $lineno has no reason. An entry is <path>:<literal>, a TAB, then why it is safe: $line" ;;
		esac
		pair="${line%%"$tab"*}"
		reason="${line#*"$tab"}"
		case "$pair" in
			*:*) ;;
			*) die "$ALLOW_FILE_NAME line $lineno is not a <path>:<literal> pair: $pair" ;;
		esac
		case "$reason" in
			*[![:space:]]*) ;;
			*) die "$ALLOW_FILE_NAME line $lineno has a blank reason: $pair" ;;
		esac
		printf '%s\n' "$pair" >> "$ALLOW_ENTRIES"
		printf '%s\n' "${pair#*:}" >> "$ALLOW_LITERALS"
	done < "$ALLOW_FILE"
}

is_allowed() { # <path-key> <literal>
	grep -Fqx -- "$1:$2" "$ALLOW_ENTRIES" 2>/dev/null && return 0
	[ "$1" = "$ALLOW_FILE_NAME" ] || return 1
	grep -Fqx -- "$2" "$ALLOW_LITERALS" 2>/dev/null
}

# ---------------------------------------------------------------------------- scanning
# scan_file <file-on-disk> <path-key> <label-for-report>
scan_file() {
	local file="$1" key="$2" label="$3"
	[ -f "$file" ] || return 0

	# One grep per pattern SET, not per pattern. An earlier draft looped a process substitution
	# per pattern — forty per file — and bash 3.2 aborted (signal 6) on roughly one run in five.
	# It failed closed, so nothing could have slipped through, but a gate that crashes is not a
	# gate. Two invocations per file are also far quicker.
	local hits="$TMPDIR_LG/hits"
	: > "$hits"
	grep -I -n -o -E "${BUILTIN_ARGS[@]}" "$file" >> "$hits" 2>/dev/null
	if [ "$IDENT_FILE_PRESENT" -eq 1 ]; then
		grep -I -i -n -o -E "${IDENT_ARGS[@]}" "$file" >> "$hits" 2>/dev/null
	fi

	local out lineno literal
	while IFS= read -r out; do
		[ -n "$out" ] || continue
		lineno="${out%%:*}"
		literal="${out#*:}"
		is_allowed "$key" "$literal" && continue
		printf '%s: BLOCKED  %s:%s: %s\n' "$PROG" "$label" "$lineno" "$literal" >&2
		HITS=$((HITS + 1))
	done < "$hits"
}

# scan_blob <blob-id> <path-key> <label>
scan_blob() {
	local file="$TMPDIR_LG/blob.$1"
	if [ ! -f "$file" ] && ! git cat-file blob "$1" > "$file" 2>/dev/null; then
		rm -f "$file"   # the redirect created it; a cached empty file would read as a clean blob
		unreadable "$3" "cannot read blob $1 — refusing to treat an unreadable object as clean"
		return
	fi
	scan_file "$file" "$2" "$3"
}

# Reads git's NUL-delimited `--raw` output and scans the destination blob of every entry.
# Sources: `git diff --cached --raw`, `git diff-tree --raw`. Blob ids rather than paths, so a
# path with non-ASCII bytes (which git hands back quoted) cannot silently drop out.
#
# Sets RAW_N to the number of blobs scanned. Deliberately NOT a command substitution: that runs
# in a subshell and every HITS increment inside would be discarded, which is the exact
# report-clean-anyway failure this whole script exists to avoid.
#
# scan_raw_z <file-of-raw-z-output> <label-suffix> [<seen-file>]
RAW_N=0
scan_raw_z() {
	local raw="$1" suffix="$2" seen="${3:-}"
	local meta path dstmode dstsha status n=0
	while IFS= read -r -d '' meta && IFS= read -r -d '' path; do
		set -- $meta
		dstmode="$2" dstsha="$4" status="$5"
		# A rename or copy carries a second path; the destination is the one that ships.
		case "$status" in
			R* | C*) IFS= read -r -d '' path || break ;;
		esac
		[ "$dstsha" = "$ZERO_SHA" ] && continue   # deletion
		[ "$dstmode" = "$GITLINK_MODE" ] && continue   # submodule, not a blob
		if [ -n "$seen" ]; then
			grep -Fqx -- "$dstsha" "$seen" 2>/dev/null && continue
			printf '%s\n' "$dstsha" >> "$seen"
		fi
		n=$((n + 1))
		scan_blob "$dstsha" "$path" "$path$suffix"
	done < "$raw"
	RAW_N="$n"
}

# ---------------------------------------------------------------------------- modes
mode_pre_commit() {
	local raw="$TMPDIR_LG/staged.raw"
	git diff --cached --raw -z --abbrev=40 --diff-filter=ACMR > "$raw" || die "cannot read the index"
	scan_raw_z "$raw" ''
	printf '%s: pre-commit scanned %s staged file(s)\n' "$PROG" "$RAW_N" >&2
}

mode_commit_msg() {
	local msgfile="$1"
	[ -f "$msgfile" ] || die "commit-msg: no message file at $msgfile"

	if grep -q "^${TRAILER_KEY}:" "$msgfile"; then
		local stripped="$TMPDIR_LG/msg"
		grep -v "^${TRAILER_KEY}:" "$msgfile" > "$stripped" || true
		cat "$stripped" > "$msgfile"
		warn "stripped a ${TRAILER_KEY} trailer from the commit message."
		warn "That trailer should never be generated here — set ${ATTRIBUTION_SETTING} to false"
		warn "(.claude/settings.json in this repo already does; check your user settings)."
	fi

	scan_file "$msgfile" 'commit-msg' 'commit message'
}

# scan_tree <commit-ish> <label-prefix>
scan_tree() {
	local rev="$1" prefix="$2" entries="$TMPDIR_LG/tree.$$" meta path type sha n=0
	git ls-tree -r -z "$rev" > "$entries" || die "cannot read the tree at $rev"
	while IFS= read -r -d '' meta; do
		path="${meta#*	}"
		set -- ${meta%%	*}
		type="$2" sha="$3"
		[ "$type" = blob ] || continue
		n=$((n + 1))
		scan_blob "$sha" "$path" "$prefix$path"
	done < "$entries"
	printf '%s: scanned %d file(s) in tree %s\n' "$PROG" "$n" "$prefix" >&2
}

# Every blob a commit introduces, scanned once each across the whole pushed range.
#
# The tip's tree is not enough. Publishing a repository publishes every reachable object, so a
# marker added in one commit and deleted in the next still ships — the tip is clean and the blob
# is still there. Demonstrated during this hook's own calibration, which is why it is here.
# `-m` matters as much: without it, `diff-tree` prints NOTHING for a merge commit, so an evil
# merge's blobs are invisible. It emits one diff per parent, hence the dedup by blob id.
scan_introduced_blobs() { # <commit> <seen-file>
	local sha="$1" seen="$2" raw="$TMPDIR_LG/introduced.raw"
	git diff-tree -m -r --root --no-commit-id --raw -z --abbrev=40 "$sha" > "$raw" ||
		die "cannot read the diff of $sha"
	scan_raw_z "$raw" " (introduced by ${sha:0:12})" "$seen"
	printf '%s: scanned %s new blob(s) from %s\n' "$PROG" "$RAW_N" "${sha:0:12}" >&2
}

mode_pre_push() {
	local local_ref local_sha remote_ref remote_sha seen="$TMPDIR_LG/seen"
	: > "$seen"
	local pushed=0
	while read -r local_ref local_sha remote_ref remote_sha; do
		[ -n "${local_sha:-}" ] || continue
		case "$local_sha" in "$ZERO_SHA" | '') continue ;; esac
		pushed=$((pushed + 1))

		scan_tree "$local_sha" "${local_ref}@"

		local revs=(rev-list "$local_sha")
		case "${remote_sha:-}" in
			"$ZERO_SHA" | '') revs+=(--not --remotes) ;;
			*) revs=(rev-list "$remote_sha..$local_sha") ;;
		esac
		local commits="$TMPDIR_LG/commits" sha
		git "${revs[@]}" > "$commits" || die "cannot enumerate the pushed range"
		n=0
		while IFS= read -r sha; do
			[ -n "$sha" ] || continue
			n=$((n + 1))
			local msg="$TMPDIR_LG/msg.$sha"
			git log -1 --format=%B "$sha" > "$msg"
			if grep -q "^${TRAILER_KEY}:" "$msg"; then
				printf '%s: BLOCKED  commit %s carries a %s trailer\n' "$PROG" "${sha:0:12}" "$TRAILER_KEY" >&2
				HITS=$((HITS + 1))
			fi
			scan_file "$msg" "commit:$sha" "message of ${sha:0:12}"
			scan_introduced_blobs "$sha" "$seen"
		done < "$commits"
		printf '%s: scanned %d commit message(s) for %s\n' "$PROG" "$n" "$local_ref" >&2
	done
	[ "$pushed" -gt 0 ] || printf '%s: pre-push had no refs to check\n' "$PROG" >&2
}

mode_scan() {
	if [ "$IDENT_FILE_PRESENT" -ne 1 ]; then
		announce_missing_identity
		die "scan refuses to certify a tree without the identity list. Restore $IDENTITY_FILE, or point AGENT_SKILLS_IDENTITY_FILE at it."
	fi
	local paths="$TMPDIR_LG/paths" path n=0
	{ git ls-files -z && git ls-files --others --exclude-standard -z; } > "$paths" ||
		die "cannot enumerate the working tree"
	while IFS= read -r -d '' path; do
		[ -n "$path" ] || continue
		n=$((n + 1))
		if [ -f "$path" ] && [ ! -r "$path" ]; then
			unreadable "$path" "cannot be read"
			continue
		fi
		scan_file "$path" "$path" "$path"
	done < "$paths"
	printf '%s: scanned %d file(s) in the working tree\n' "$PROG" "$n" >&2
}

# ---------------------------------------------------------------------------- entry point
invoked_as="$(basename -- "$0")"
case "$invoked_as" in
	leak-guard.sh)
		mode="${1:-}"
		[ -n "$mode" ] || die "usage: leak-guard.sh {pre-commit|commit-msg <file>|pre-push|scan}"
		shift
		;;
	*)
		mode="$invoked_as"
		;;
esac

load_allowlist
if ! load_identity_patterns && [ "$mode" != scan ]; then
	announce_missing_identity
fi

case "$mode" in
	pre-commit) mode_pre_commit ;;
	commit-msg) mode_commit_msg "${1:?commit-msg needs the message file}" ;;
	pre-push) mode_pre_push ;;
	scan) mode_scan ;;
	*) die "unknown mode: $mode" ;;
esac

if [ "$HITS" -gt 0 ]; then
	warn ""
	warn "$HITS match(es). This content is not allowed in a public repository."
	warn "Fix the lines above, or — if a match is genuinely fine — add a"
	warn "<path>:<literal> pair to $ALLOW_FILE_NAME with a reason. That is an owner decision."
	exit 1
fi

printf '%s: %s clean\n' "$PROG" "$mode" >&2
exit 0
