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
#   pre-push     the tree at each pushed tip, plus every commit message in the pushed range
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
# each immediately preceded by a `#` line giving the reason. Never a line number — those drift.
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
load_identity_patterns() {
	[ -e "$IDENTITY_FILE" ] || return 1
	local line
	while IFS= read -r line; do
		case "$line" in
			'' | '#'*) continue ;;
		esac
		IDENT_PATTERNS+=("$line")
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
load_allowlist() {
	[ -f "$ALLOW_FILE" ] || return 0
	local line reason='' lineno=0
	while IFS= read -r line; do
		lineno=$((lineno + 1))
		case "$line" in
			'')
				reason=''
				continue
				;;
			'#'*)
				reason="$line"
				continue
				;;
		esac
		if [ -z "$reason" ]; then
			die ".leak-guard-allow line $lineno has no reason: every entry needs a '#' comment line directly above it"
		fi
		case "$line" in
			*:*) ;;
			*) die ".leak-guard-allow line $lineno is not a <path>:<literal> pair: $line" ;;
		esac
		printf '%s\n' "$line" >> "$ALLOW_ENTRIES"
		reason=''
	done < "$ALLOW_FILE"
}

is_allowed() { # <path-key> <literal>
	grep -Fqx -- "$1:$2" "$ALLOW_ENTRIES" 2>/dev/null
}

is_self_excluded() { # <path-key>
	local p
	for p in "${SELF_EXCLUDE[@]}"; do
		[ "$1" = "$p" ] && return 0
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

	local pat out lineno literal
	for pat in "${BUILTIN_PATTERNS[@]}"; do
		while IFS= read -r out; do
			[ -n "$out" ] || continue
			lineno="${out%%:*}"
			literal="${out#*:}"
			is_allowed "$key" "$literal" && continue
			printf '%s: BLOCKED  %s:%s: %s\n' "$PROG" "$label" "$lineno" "$literal" >&2
			HITS=$((HITS + 1))
		done < <(grep -I -n -o -E -- "$pat" "$file" 2>/dev/null)
	done

	if [ "$IDENT_FILE_PRESENT" -eq 1 ] && [ "${#IDENT_PATTERNS[@]}" -gt 0 ]; then
		for pat in "${IDENT_PATTERNS[@]}"; do
			while IFS= read -r out; do
				[ -n "$out" ] || continue
				lineno="${out%%:*}"
				literal="${out#*:}"
				is_allowed "$key" "$literal" && continue
				printf '%s: BLOCKED  %s:%s: %s\n' "$PROG" "$label" "$lineno" "$literal" >&2
				HITS=$((HITS + 1))
			done < <(grep -I -i -n -o -E -- "$pat" "$file" 2>/dev/null)
		done
	fi
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
	warn "<path>:<literal> pair to .leak-guard-allow with a reason. That is an owner decision."
	exit 1
fi

printf '%s: %s clean\n' "$PROG" "$mode" >&2
exit 0
