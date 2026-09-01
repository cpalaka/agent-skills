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
#   pre-commit   staged content of added/modified files
#   commit-msg   the commit message file (strips a Claude-Session trailer, warns, does not fail)
#   pre-push     the tree at each pushed tip, every commit message in the pushed range, and
#                every blob any commit in that range introduces (see scan_introduced_blobs)
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
# (`/[U]sers/`), which matches the same text but keeps this file from matching itself. The
# guard scans its own source like any other file; that is deliberate.

set -uo pipefail

PROG=leak-guard

# ---------------------------------------------------------------------------- built-in patterns
# Extended regular expressions. Matched case-sensitively.
BUILTIN_PATTERNS=(
	'/[U]sers/[A-Za-z0-9._-]+'
	'/[h]ome/[A-Za-z0-9._-]+'
	'~/[C]laude/'
	'[i]mprovements\.md'
	'\[[i]mp:'
	'[R]ationale:'
	'\.[t]s\.net'
	'[s]sh +[A-Za-z0-9._-]+@[A-Za-z0-9._-]+'
	'claude\.ai/code/[s]ession_'
)

# Paths never scanned, because their whole purpose is to hold the strings we look for.
SELF_EXCLUDE=('.leak-guard-allow')

TRAILER_KEY='Claude-Session'
ATTRIBUTION_SETTING='attribution.sessionUrl'

IDENTITY_FILE="${AGENT_SKILLS_IDENTITY_FILE:-$HOME/.config/agent-skills/identity-patterns}"

warn() { printf '%s: %s\n' "$PROG" "$*" >&2; }
die() { warn "$*"; exit 1; }

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git repository"
cd "$REPO_ROOT" || die "cannot enter $REPO_ROOT"

TMPDIR_LG="$(mktemp -d "${TMPDIR:-/tmp}/leak-guard.XXXXXX")" || die "cannot create a temp directory"
[ -n "$TMPDIR_LG" ] && [ -d "$TMPDIR_LG" ] || die "mktemp -d returned an unusable path"
cleanup() { rm -rf "$TMPDIR_LG"; }
trap cleanup EXIT

# ---------------------------------------------------------------------------- identity patterns
IDENT_FILE_PRESENT=0
IDENT_PATTERNS=()
IDENT_ARGS=()

# Both pattern sets are handed to grep as -e arguments, one invocation per set per file.
BUILTIN_ARGS=()
for _p in "${BUILTIN_PATTERNS[@]}"; do BUILTIN_ARGS+=(-e "$_p"); done
unset _p

load_identity_patterns() {
	[ -e "$IDENTITY_FILE" ] || return 1
	local line
	while IFS= read -r line; do
		case "$line" in
			'' | '#'*) continue ;;
		esac
		IDENT_PATTERNS+=("$line")
		IDENT_ARGS+=(-e "$line")
	done < "$IDENTITY_FILE"
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
ALLOW_FILE="$REPO_ROOT/.leak-guard-allow"
ALLOW_ENTRIES="$TMPDIR_LG/allow"
: > "$ALLOW_ENTRIES"
# Entry syntax: <path>:<literal><TAB><reason>
#
# The reason is on the entry's own line, deliberately. An earlier draft took it from the comment
# line above, and its own calibration caught the hole: the file's header comment silently counted
# as the reason for the first entry, so an unexplained exemption passed. A tab cannot appear in a
# match — no built-in pattern matches one — so splitting on the first tab is unambiguous.
load_allowlist() {
	[ -f "$ALLOW_FILE" ] || return 0
	local tab line pair reason lineno=0
	tab="$(printf '\t')"
	while IFS= read -r line; do
		lineno=$((lineno + 1))
		case "$line" in
			'' | '#'*) continue ;;
			*"$tab"*) ;;
			*) die ".leak-guard-allow line $lineno has no reason. An entry is <path>:<literal>, a TAB, then why it is safe: $line" ;;
		esac
		pair="${line%%"$tab"*}"
		reason="${line#*"$tab"}"
		case "$pair" in
			*:*) ;;
			*) die ".leak-guard-allow line $lineno is not a <path>:<literal> pair: $pair" ;;
		esac
		case "$reason" in
			*[![:space:]]*) ;;
			*) die ".leak-guard-allow line $lineno has a blank reason: $pair" ;;
		esac
		printf '%s\n' "$pair" >> "$ALLOW_ENTRIES"
	done < "$ALLOW_FILE"
}

is_allowed() { # <path-key> <literal>
	grep -Fqx -- "$1:$2" "$ALLOW_ENTRIES" 2>/dev/null
}

SKIPPED=0
is_self_excluded() { # <path-key>
	local p
	for p in "${SELF_EXCLUDE[@]}"; do
		if [ "$1" = "$p" ]; then
			SKIPPED=$((SKIPPED + 1))
			warn "not matched against (it is the exemption list itself): $p"
			return 0
		fi
	done
	return 1
}

# ---------------------------------------------------------------------------- scanning
HITS=0

# scan_file <file-on-disk> <path-key> <label-for-report>
scan_file() {
	local file="$1" key="$2" label="$3"
	is_self_excluded "$key" && return 0
	[ -f "$file" ] || return 0

	# One grep per pattern SET, not per pattern. An earlier draft looped a process substitution
	# per pattern — forty per file — and bash 3.2 aborted (signal 6) on roughly one run in five.
	# It failed closed, so no leak could have slipped through, but a gate that crashes is not a
	# gate. Two invocations per file also happen to be far quicker.
	local hits="$TMPDIR_LG/hits"
	: > "$hits"
	grep -I -n -o -E "${BUILTIN_ARGS[@]}" "$file" >> "$hits" 2>/dev/null
	if [ "$IDENT_FILE_PRESENT" -eq 1 ] && [ "${#IDENT_ARGS[@]}" -gt 0 ]; then
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

# ---------------------------------------------------------------------------- modes
mode_pre_commit() {
	local path n=0
	while IFS= read -r path; do
		[ -n "$path" ] || continue
		n=$((n + 1))
		local blob="$TMPDIR_LG/staged.$n"
		git show ":$path" > "$blob" 2>/dev/null || continue
		scan_file "$blob" "$path" "$path"
	done < <(git diff --cached --name-only --diff-filter=ACMR)
	printf '%s: pre-commit scanned %d staged file(s)\n' "$PROG" "$n" >&2
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

# Every blob a commit introduces, scanned once each across the whole pushed range.
#
# The tip's tree is not enough. Publishing a repository publishes every reachable object, so a
# marker added in one commit and deleted in the next still ships — the tip is clean and the blob
# is still there. Demonstrated during this hook's own calibration, which is why it is here.
# Deduplicated by blob id, so the overlap with the tip tree costs nothing.
SEEN_BLOBS=''
scan_introduced_blobs() { # <commit>
	local sha="$1" blob path n=0
	while IFS= read -r blob && IFS= read -r path; do
		[ -n "$blob" ] || continue
		case "$blob" in *[!0]*) ;; *) continue ;; esac # all-zero: a deletion
		case "$SEEN_BLOBS" in *" $blob "*) continue ;; esac
		SEEN_BLOBS="$SEEN_BLOBS $blob "
		n=$((n + 1))
		local file="$TMPDIR_LG/blob.$blob"
		git cat-file blob "$blob" > "$file" 2>/dev/null || continue
		scan_file "$file" "$path" "$path (introduced by ${sha:0:12})"
	done < <(git diff-tree -r --root --no-commit-id --raw --abbrev=40 "$sha" |
		awk '{ print $4; sub(/^[^\t]*\t/, ""); print }')
	printf '%s: scanned %d new blob(s) from %s\n' "$PROG" "$n" "${sha:0:12}" >&2
}

# scan_tree <commit-ish> <label-prefix>
scan_tree() {
	local rev="$1" prefix="$2" path n=0
	while IFS= read -r path; do
		[ -n "$path" ] || continue
		n=$((n + 1))
		local blob="$TMPDIR_LG/tree.$n"
		git show "$rev:$path" > "$blob" 2>/dev/null || continue
		scan_file "$blob" "$path" "$prefix$path"
	done < <(git ls-tree -r --name-only "$rev")
	printf '%s: scanned %d file(s) in tree %s\n' "$PROG" "$n" "$prefix" >&2
}

mode_pre_push() {
	local zero='0000000000000000000000000000000000000000'
	local local_ref local_sha remote_ref remote_sha
	local seen=0
	while read -r local_ref local_sha remote_ref remote_sha; do
		[ -n "${local_sha:-}" ] || continue
		case "$local_sha" in "$zero" | '') continue ;; esac
		seen=$((seen + 1))

		scan_tree "$local_sha" "${local_ref}@"

		local range_cmd sha n=0
		case "$remote_sha" in
			"$zero" | '') range_cmd="git rev-list $local_sha --not --remotes" ;;
			*) range_cmd="git rev-list $remote_sha..$local_sha" ;;
		esac
		while IFS= read -r sha; do
			[ -n "$sha" ] || continue
			n=$((n + 1))
			local msg="$TMPDIR_LG/msg.$n"
			git log -1 --format=%B "$sha" > "$msg"
			if grep -q "^${TRAILER_KEY}:" "$msg"; then
				printf '%s: BLOCKED  commit %s carries a %s trailer\n' "$PROG" "${sha:0:12}" "$TRAILER_KEY" >&2
				HITS=$((HITS + 1))
			fi
			scan_file "$msg" "commit:$sha" "message of ${sha:0:12}"
			scan_introduced_blobs "$sha"
		done < <($range_cmd)
		printf '%s: scanned %d commit message(s) for %s\n' "$PROG" "$n" "$local_ref" >&2
	done
	[ "$seen" -gt 0 ] || printf '%s: pre-push had no refs to check\n' "$PROG" >&2
}

mode_scan() {
	if [ "$IDENT_FILE_PRESENT" -ne 1 ]; then
		announce_missing_identity
		die "scan refuses to certify a tree without the identity list. Restore $IDENTITY_FILE, or point AGENT_SKILLS_IDENTITY_FILE at it."
	fi
	local path n=0
	while IFS= read -r path; do
		[ -n "$path" ] || continue
		n=$((n + 1))
		scan_file "$path" "$path" "$path"
	done < <(git ls-files; git ls-files --others --exclude-standard)
	printf '%s: walked %d file(s) in the working tree, matched %d of them\n' "$PROG" "$n" "$((n - SKIPPED))" >&2
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
	warn "<path>:<literal> pair to .leak-guard-allow with a reason. That is an owner decision."
	exit 1
fi

printf '%s: %s clean\n' "$PROG" "$mode" >&2
exit 0
