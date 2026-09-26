#!/bin/sh
# engine.sh — init-project's mechanical stamping script (#126). POSIX sh + the system awk.
# Run `engine.sh --help` for the interface. Portability rules this file keeps: no bashisms, no data
# through `awk -v` (it processes backslash escapes), printf never echo, every write atomic, all
# rendering in a staging directory before the first write.

unset CDPATH # an exported CDPATH makes every cd below resolve (and echo) somewhere else
# ---- asset locations (physical, so either host's Skill symlink reaches the real init-project/) ----
SKILL_DIR=$(cd "$(dirname "$0")/.." && pwd -P) || { printf 'STOP: cannot locate the Skill directory\n'; exit 2; }
SCRIPT_DIR=$SKILL_DIR/scripts
SELF=$SCRIPT_DIR/$(basename "$0")
TEMPLATE_DIR=$SKILL_DIR/templates
PROFILE_DIR=${INIT_PROJECT_PROFILE_DIR:-$SKILL_DIR/profiles}
FIXTURE_DIR=$SCRIPT_DIR/fixtures
# The tracker's assets. Ticket 3 moves these; keep them in this one block.
TRACKER_PROFILE=$PROFILE_DIR/github.md
TRACKER_ASSETS=$PROFILE_DIR/github/templates
TRACKER_CONTRACT=$TRACKER_ASSETS/contract.md
TRACKER_POINTERS='issue-tracker.md=docs/agents/issue-tracker.md triage-labels.md=docs/agents/triage-labels.md'
# Target-relative engine files.
CONTRACT=docs/agents/project-workflow.md
GATE_RUNNER=.claude/agents/gate-runner.md
FORK_DEFAULT=git-flow-squash
KNOB_CHANGES=${INIT_PROJECT_KNOB_CHANGES:-$SCRIPT_DIR/knob-changes}

TAB=$(printf '\t')
NL='
'
SUB=
TMP_LIST=
INFLIGHT=

# TMP_LIST is newline-separated, so a TMPDIR holding a space still cleans up. INFLIGHT is the one
# atomic-write temp that exists in a destination directory between its cp and its mv.
cleanup() { [ -z "$INFLIGHT" ] || rm -f "$INFLIGHT"; set -f; _ifs=$IFS; IFS=$NL; for _d in $TMP_LIST; do [ -n "$_d" ] && rm -rf "$_d"; done; IFS=$_ifs; set +f; }
trap cleanup EXIT
# RESULT stays the last line, printed through fd 3 (this run's stdout, duplicated here) because the
# signal can land while a function's stdout is redirected into a staging file cleanup deletes.
exec 3>&1
trap 'result stopped 2 >&3' INT TERM HUP

result() { printf 'RESULT: %s %s (exit %s)\n' "${SUB:-engine.sh}" "$1" "$2"; exit "$2"; }
stop() { printf 'STOP: %s\n' "$1"; result stopped 2; }
note() { printf 'NOTE %s\n' "$1"; }

usage() {
  printf '%s\n' \
    'usage: engine.sh selftest' \
    '       engine.sh stamp       --target <dir> --answers <file> [--after-freeze]' \
    '       engine.sh verify      --target <dir> --answers <file>' \
    '       engine.sh check       --target <dir> --answers <file>' \
    '       engine.sh host-setup  --answers <file>' \
    '       engine.sh --help'
}
usage_stop() { usage; stop "$1"; }

help() {
  usage
  printf '%s\n' '' \
'Exit codes: 0 clean, 1 a gate or check failed or could not run, 2 a stop (nothing half-written: all' \
'rendering and validation happen in a staging directory before the first write, and each write is a' \
'temp file beside its destination renamed over it; an interrupt (INT, TERM, HUP) removes the temp in' \
'flight, while a SIGKILL, which no script can trap, can leave one <dest>.tmp.<pid> behind).' \
'' \
'Subcommands' \
'  selftest    run the fixture cases; prints one line per wrong verdict, then' \
'              "selftest: <k>/<N> verdicts correct". Exit 0 only when k = N.' \
'  stamp       write the four engine files (contract, CLAUDE.md, AGENTS.md, the gate-runner seat),' \
'              the Profile templates and, for tracker github, the two pointer files, into --target.' \
'              --after-freeze writes only the Profile entries marked after_freeze: true.' \
'              A fresh stamp (no contract) takes the tracker from the answers file: github or none,' \
'              anything else (held included) a stop. A RE-RUN (the' \
'              contract exists) reads it from the contract: knobs:tracker-github -> github,' \
'              knobs:backlog-core -> held (frozen: its block and any line it already has are kept,' \
'              nothing added), neither -> none. On a re-run each engine file present in the target' \
'              has only its tagged zones replaced from the render; a zone the target does not tag' \
'              reads absent and is not inserted; a file with no zone tag (a v1 stamp) has no zone' \
'              refreshed, but a v1 contract still takes the knob-block rewrite below (a v1 stamp tags' \
'              its knob blocks), and every file takes the outside fill.' \
'              The one write outside a zone: a *<Fill at init ...>* prompt that survives outside every' \
'              zone of a file already in the target (an engine file, a Profile template, a pointer)' \
'              and whose fill:<dest>#<heading> the answers file gives is replaced by it, exactly that' \
'              span (FILLED <dest>#<heading>); a prompt inside fenced code, or inside an inline code' \
'              span closed on the same line, is prose and never filled. On a re-run, a fill key for a' \
'              file already in the target that fills no prompt there is a NOTE where its heading is in' \
'              that file, its render or its source Template, and a stop, as on a fresh stamp, where the' \
'              heading is in none of them.' \
'              Tags inside fenced code are prose, never read as tags: a fence opens on three or' \
'              more ` or ~ and closes only on a run of the same character at least as long, alone on' \
'              its line (CommonMark), so ~~~ inside a ``` block is content.' \
'              A refreshed zone that would gain a *<Fill at init ...>* prompt it does not carry is a' \
'              stop naming the fill:<dest>#<heading> to give. Knob blocks keep every existing value' \
'              (an answers-file value that differs from it is not used, and a NOTE says so):' \
'              keys are respelled to the Profile (-, _ and space match), renamed or retired per the' \
'              knob-changes file, added per the value rule below; a key the Profile does not list and' \
'              no retire row names is the project'"'"'s own and is kept. A listed block the contract' \
'              lacks is inserted after its last knob block. A block is deleted only where knob-changes' \
'              has a retire-block <id> row; any other unlisted block (a hand-imported Chunk'"'"'s, or one' \
'              a type-none answers file does not repeat) is kept verbatim and reported. A listed block' \
'              with a line that is not "- <key>: <value>" or an indented continuation is a stop.' \
'              A destination that is a symlink is a stop before the first write wherever a write would' \
'              change its bytes: the engine never replaces a link with a file (an unchanged one reads' \
'              UNCHANGED, the link intact).' \
'              Last, .claude/settings.local.json is merged with jq (a plain stamp stops before any' \
'              write when jq is not installed, naming the install command): absent, it is created from' \
'              {"permissions":{"defaultMode":"auto"},"sandbox":{"enabled":true}} plus the Profile delta;' \
'              a Profile allow entry already in permissions.deny is not added (deny wins); an entry in' \
'              both allow and deny is reported and left for the owner; missing enabled_mcp_servers are' \
'              added to enabledMcpjsonServers; every other key is kept. The file is rewritten only when' \
'              an entry or server is added, never for formatting; malformed JSON is a stop.' \
'              A second stamp with the same inputs changes no byte.' \
'  host-setup  the machine-wide pieces, kept out of stamp so stamp and verify run sandboxed: the ignore' \
'              lines **/.codex/config.toml and **/.claude/settings.local.json into the git global' \
'              excludes file (core.excludesFile, else $XDG_CONFIG_HOME or ~/.config, /git/ignore), and' \
'              the Profile templates whose dest starts ~/ (copied verbatim; executable where the source' \
'              is or the parent directory is bin). Absent -> written; identical -> present; different ->' \
'              differs, left, never overwritten. Each line carries its undo.' \
'  verify      read-only, over --target. Five residue checks, each run first over a known-bad it must' \
'              match (CONTROL), then over the stamped files (CHECK): braces ({{ left), marker' \
'              (<!-- profile: left), fill-prompt (fill at init / filled at init, any case, in any file but' \
'              the fork slot below, outside fenced code and inline code spans closed on their line, as' \
'              the outside fill reads them), fork-slot (filled at init in CLAUDE.md), empty-heading (in the four' \
'              engine files, a heading with nothing but blank lines, comments or zone tags before the' \
'              next heading of its level or higher, or the end). A CHECK FAIL names file:line (the' \
'              first three; fill-prompt names every one). A control that ran and missed its known-bad' \
'              is FAIL; a detector that errored, or no file to scan, is NOT RUN, which exits 1 too.' \
'              Byte gates, per file: CLAUDE.md and AGENTS.md 32768 each, ~/.codex/AGENTS.md 32768 where' \
'              it exists, the contract 16384. imports-resolve: every @ line reached from CLAUDE.md is a' \
'              readable file. Then the resolved load, one LOAD line per file and a TOTAL per host,' \
'              REPORTED, NEVER GATED: Claude = CLAUDE.md plus its @ lines outside fences, transitively' \
'              (five hops, each physical file once); Codex = AGENTS.md, CONTEXT.md, the contract and' \
'              the read list'"'"'s names under ~/.codex/chunks/. The verify-gate Chunk'"'"'s own gates are' \
'              not run here (the VERIFY-GATE line). Exit 1 on any CHECK or GATE FAIL, else 0.' \
'  check       read-only: renders what stamp would write (with the answers file'"'"'s fills) and' \
'              compares each zone of the four engine files: same | differs | absent (untagged, or' \
'              the file is missing; a v1 stamp reads absent throughout) | orphan (tagged, not' \
'              rendered; kept, not drift). Knob blocks compare by key set and scalar/list shape,' \
'              never by value,' \
'              after the knob-changes file: a key the Profile lacks and no retire row names is the' \
'              project'"'"'s own (a NOTE, not drift); a missing Profile key or a retired key present' \
'              differs; an unlisted block reads orphan (kept, a NOTE), one a retire-block row names' \
'              differs; backlog-core reads held; a listed block with a line that' \
'              is not "- <key>: <value>" or an indented continuation reads unparsed. A NOTE says why' \
'              each block differs. Exit 1 on any differs or unparsed, else 0.' \
'' \
'A run: write the answers file; stamp; verify (a fill-prompt FAIL names each prompt still to' \
'answer: add its fill: block and stamp again); check; host-setup once per machine.' \
'' \
'Answers file (markdown; only these tagged blocks are read, each tag alone on its line):' \
'  <!-- answers:meta -->' \
'  - project_name: Demo' \
'  - type: web                (a Profile name under profiles/, or none)' \
'  - tracker: github          (github | none; read on a fresh stamp only)' \
'  <!-- /answers:meta -->' \
'  <!-- answers:tokens -->' \
'  - SOME_TOKEN: its value    (any {{NAME}} a written file carries beyond PROJECT_NAME/PROJECT_ROOT)' \
'  <!-- /answers:tokens -->' \
'  <!-- knobs:<id> -->        (the exact inner shape the contract gets, copied verbatim)' \
'  - <key>: <value>' \
'  - <list-key>:' \
'    1. <item>' \
'  <!-- /knobs:<id> -->' \
'  <!-- fill:<dest>#<heading> -->' \
'  Any markdown, verbatim; replaces the *<Fill at init: ...>* prompt under that heading in <dest>.' \
'  <dest> is target-relative (docs/agents/project-workflow.md, AGENTS.md, a Profile template'"'"'s' \
'  dest, a tracker pointer); <heading> is the nearest heading above the prompt, #s and edge spaces' \
'  dropped (fill:AGENTS.md#Skills). Text before *< and after >* on its line is kept. A fill for a' \
'  file the run does not write is a NOTE; one that matches no prompt in a file it writes stops' \
'  (a re-run over a file already in the target follows the fill-key rule under stamp).' \
'  CLAUDE.md'"'"'s fork slot is filled by the engine, never from the answers file.' \
'  <!-- /fill:<dest>#<heading> -->' \
'  The parenthesised notes above are illustration: a value is everything after "<key>: ".' \
'' \
'Knob values, per key: the answers value; else the Profile value when it is a literal; else a' \
'stop naming <id>.<key>. A Profile value that is wholly "<...>" is a shape, not a literal. An answers' \
'key or block the Profile does not list is a stop. For type none the answers blocks are the key sets.' \
'' \
'Fragments: each <!-- profile:<m> --> marker becomes a <!-- zone:<m> --> pair holding the Profile' \
'fragment (empty where it has none). A contract fragment ## heading that prefix-matches a Template' \
'stub (## Working in this repo, ## Running) replaces that stub; a fragment that would leave an' \
'unreplaced stub inside its zone is a shape this engine does not support, and stops.' \
'' \
'Output lines (stdout, fixed; paths target-relative, ~/-relative under $HOME):' \
'  WROTE <path> | UNCHANGED <path> | SKIPPED <path> — <reason> | NOTE <text> | STOP: <reason>' \
'  FILLED <path>#<heading>                             (stamp re-run: a fill applied outside a zone)' \
'  ZONE <path> <zone> <same|refreshed|absent|orphan>     (stamp re-run; printed before any write)' \
'  ZONE <path> <zone> <same|differs|absent|orphan|held|unparsed>   (check; a knob block'"'"'s zone is' \
'                                                        knobs:<id>)' \
'  KNOB <id> <kept|added|renamed|respelled|retired|block-inserted|block-deleted> [<detail>]' \
'  held: backlog-core (frozen) — <the parts found>' \
'  SETTINGS <created-from-baseline|allow-added|deny-wins|in-both|mcp-added> [<entry>]' \
'  HOST-SETUP <added|present|differs|wrote> <what> — undo: <command>' \
'  CONTROL <check>: known-bad matched <n> — target matched <m>' \
'  CHECK <check>: PASS|FAIL|NOT RUN — <detail>' \
'  GATE bytes <path>: PASS|FAIL — <bytes> <=|> <cap>     GATE imports-resolve: PASS|FAIL — <detail>' \
'  LOAD <claude|codex> <path> <bytes>                  LOAD <claude|codex> TOTAL <bytes> — reported, not gated' \
'  VERIFY-GATE: NOT RUN by this script — <reason>' \
'  SELFTEST <case>: expected <x>, got <y> | selftest: <k>/<N> verdicts correct' \
'  RESULT: <subcommand> <clean|failed|stopped> (exit <n>)   (always the last line)' \
'' \
'Test seams (selftest and calibration only):' \
'  INIT_PROJECT_PROFILE_DIR    read Profiles from this directory instead of profiles/' \
'  INIT_PROJECT_KNOB_CHANGES   the knob-changes file a re-run reads (default scripts/knob-changes; rows:' \
'                              rename <id> <old> <new> | retire <id> <key> | retire-block <id>)' \
'  INIT_PROJECT_NO_LOCALE_PIN=1  skip the UTF-8 locale pin'
}

# ---- locale pin ------------------------------------------------------------------------------------
pin_locale() {
  [ "${INIT_PROJECT_NO_LOCALE_PIN:-}" = 1 ] && return 0
  _pinned=
  for _c in C.UTF-8 C.utf8 en_US.UTF-8 en_US.utf8; do
    if [ "$(LC_ALL=$_c locale charmap 2>/dev/null)" = UTF-8 ]; then _pinned=$_c; break; fi
  done
  [ -n "$_pinned" ] || stop "no UTF-8 locale found (tried C.UTF-8, C.utf8, en_US.UTF-8, en_US.utf8)"
  LC_ALL=$_pinned; LANG=$_pinned; export LC_ALL LANG
}

# ---- temp space: a sandboxed mktemp -d can print empty and exit 0 --------------------------------
mk_tmpdir() {
  MKD=$(mktemp -d 2>/dev/null) || MKD=
  if [ -z "$MKD" ] || [ ! -d "$MKD" ]; then stop "mktemp -d returned no directory — nothing written"; fi
  TMP_LIST="$TMP_LIST$MKD$NL"
}

# ---- atomic write: temp in the destination's own directory, then mv -f ---------------------------
write_failed() { stop "write failed $1 — files written before it are complete; re-run to recover"; }
# 0 when writing <staged> over <file> would change no byte: identical, or <file> lacks a final newline
# and differs from the staged one by that newline alone (it stays as it is).
same_bytes() { # <staged> <file>
  [ -f "$2" ] || return 1
  cmp -s "$1" "$2" && return 0
  [ -s "$2" ] && [ "$(tail -c 1 "$2" | wc -l | tr -d ' ')" = 0 ] && { cat "$2"; printf '\n'; } | cmp -s - "$1"
}
write_file() { # <staged file> <target-relative dest> [<source whose executable bit to keep>]
  _dest=$TARGET/$2
  if [ -d "$_dest" ]; then stop "$2 exists as a directory — files written before it are complete; re-run to recover"; fi
  if same_bytes "$1" "$_dest"; then printf 'UNCHANGED %s\n' "$2"; return 0; fi
  mkdir -p "$(dirname "$_dest")" 2>/dev/null || write_failed "$2"
  _tmp=$_dest.tmp.$$; INFLIGHT=$_tmp
  if cp "$1" "$_tmp" 2>/dev/null &&
     { [ -z "${3:-}" ] || [ ! -x "$3" ] || chmod +x "$_tmp"; } &&
     mv -f "$_tmp" "$_dest" 2>/dev/null; then
    INFLIGHT=; printf 'WROTE %s\n' "$2"
  else
    rm -f "$_tmp"; INFLIGHT=; write_failed "$2"
  fi
}

# ---- zones -----------------------------------------------------------------------------------------
# Every reader of a zone or knob tag skips fenced code (``` or ~~~): a tag shown as an example in a
# code block is prose, never a tag. The fence rule is CommonMark's, shared by every reader through
# FENCEFN: a run of three or more ` or ~ opens (a backtick opener's info string holds no backtick);
# only a run of the opener's character at least as long, with nothing but whitespace after it,
# closes, so a ~~~ inside a ``` block, or ``` inside ````, is content. fence_line returns 1 on an
# opener, 2 on a closer, else 0; fch is the open fence's character, "" outside a fence.
FENCEFN='
    function fence_line(s,   t, c, n, r) {
      t = s; sub(/^[ \t]+/, "", t); c = substr(t, 1, 1)
      if (c != "`" && c != "~") return 0
      n = 1; while (substr(t, n + 1, 1) == c) n++
      if (n < 3) return 0
      r = substr(t, n + 1)
      if (fch == "") { if (c == "`" && index(r, "`")) return 0; fch = c; flen = n; return 1 }
      if (c == fch && n >= flen && r ~ /^[ \t]*$/) { fch = ""; return 2 }
      return 0
    }
'
# Inline code spans, shared by the outside fill pass and verify's fill-prompt detector: a run of n
# backticks opens one, closed by the next run of exactly n on the same line (a span that wraps onto
# the next line is not seen). codespan returns the index just past the span, or 0 when unclosed,
# with CSRUN the opening run's length; uncode returns a line with each closed span replaced by a space.
CODESPANFN='
    function spanend(r, n,   p, q, m) { # just past the first run of exactly n backticks in r, else 0
      p = 0
      while ((q = index(substr(r, p + 1), "`")) > 0) {
        q += p; m = 1; while (substr(r, q + m, 1) == "`") m++
        if (m == n) return q + m
        p = q + m - 1
      }
      return 0
    }
    function codespan(s, b,   n, j) { # a backtick run starts at b in s
      n = 1; while (substr(s, b + n, 1) == "`") n++
      CSRUN = n; j = spanend(substr(s, b + n), n)
      return j ? b + n + j - 1 : 0
    }
    function uncode(s,   out, b, e) {
      out = ""
      while ((b = index(s, "`")) > 0) {
        e = codespan(s, b)
        if (e) { out = out substr(s, 1, b - 1) " "; s = substr(s, e) }
        else { out = out substr(s, 1, b + CSRUN - 1); s = substr(s, b + CSRUN) }
      }
      return out s
    }
'
# FENCE is the fragment each tag reader starts its body with; it sets fk (fence_line's verdict) and
# fz (inside a fence, the fence lines included).
FENCE="$FENCEFN"'{ fk = fence_line($0); fz = (fk || fch != "") }'
# Print the content between <!-- zone:<name> --> and <!-- /zone:<name> --> (tags excluded).
zone_extract() { # <file> <zone>
  ZN=$2 awk "$FENCE"'
    BEGIN { o = "<!-- zone:" ENVIRON["ZN"] " -->"; c = "<!-- /zone:" ENVIRON["ZN"] " -->" }
    { t = $0; sub(/^[ \t]+/, "", t); sub(/[ \t]+$/, "", t) }
    !fz && t == c { f = 0 }
    f { print }
    !fz && t == o { f = 1 }' "$1" || return 2
}
# Print one line naming the first zone-tag defect (duplicate, unclosed, nested, stray close), or nothing.
zone_check() { # <file>
  awk "$FENCE"'
    { t = $0; sub(/^[ \t]+/, "", t); sub(/[ \t]+$/, "", t) }
    !fz && t ~ /^<!-- \/?zone:[^ ]+ -->$/ {
      nm = t; sub(/^<!-- \/?zone:/, "", nm); sub(/ -->$/, "", nm)
      if (substr(t, 6, 1) != "/") {
        if (cur != "") { print "zone " nm " opens inside zone " cur; bad = 1; exit }
        if (nm in seen) { print "zone " nm " is tagged twice"; bad = 1; exit }
        seen[nm] = 1; cur = nm
      } else {
        if (cur != nm) { print "zone " nm " closes without its open tag"; bad = 1; exit }
        cur = ""
      }
    }
    fk == 1 { fl = NR }
    END { if (!bad && fch != "") print "the code fence opened on line " fl " is never closed, so no tag after it can be read"
          else if (!bad && cur != "") print "zone " cur " is not closed" }' "$1" || { printf 'awk failed reading its zone tags\n'; return 2; }
}
has_zone_tag() { # 0 tagged, 1 untagged; an awk error stops rather than reading as "untagged"
  awk "$FENCE"'!fz && /^[ \t]*<!-- \/?zone:[^ ]+ -->[ \t]*$/ { f = 1; exit } END { exit !f }' "$1"; _hz=$?
  [ "$_hz" -le 1 ] || stop "awk failed reading $1"
  return "$_hz"
}
zone_names() { # <file> → each zone:<name> open tag's name, in order
  awk "$FENCE"'{ t = $0; sub(/^[ \t]+/, "", t); sub(/[ \t]+$/, "", t) }
    !fz && t ~ /^<!-- zone:[^ ]+ -->$/ { sub(/^<!-- zone:/, "", t); sub(/ -->$/, "", t); print t }' "$1"
}
tag_count() { # <ERE> <file> → the number of lines outside fenced code matching; awk's status is the function's
  PAT=$1 awk "$FENCE"'!fz && $0 ~ ENVIRON["PAT"] { n++ } END { print n + 0 }' "$2"
}

# ---- parsers ---------------------------------------------------------------------------------------
# Profile frontmatter subset → tab-separated records: IMP id | FORK f | TPL src dest after_freeze |
# ADP role file | ALLOW entry | MCP name | KB id | K id key S|L value | I id key item | NOTE text | E text
parse_profile() { # <profile.md> → stdout
  awk '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function perr(m) { if (!bad) printf "E\t%s line %d: %s\n", FILENAME, NR, m; bad = 1 }
    function strip_comment(s,   i, c, inq, prev) {
      inq = 0; prev = " "
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (inq) { if (c == "\\") { i++; prev = "x"; continue } if (c == "\"") inq = 0 }
        else if (c == "\"") inq = 1
        else if (c == "#" && (prev == " " || prev == "\t")) return substr(s, 1, i - 1)
        prev = c
      }
      return s
    }
    function unq(s,   i, c, out, n) {
      s = trim(s)
      if (substr(s, 1, 1) != "\"") return s
      out = ""; n = length(s)
      for (i = 2; i <= n; i++) {
        c = substr(s, i, 1)
        if (c == "\\") {
          i++; c = substr(s, i, 1)
          if (c == "\\" || c == "\"") { out = out c; continue }
          perr("unsupported escape \\" c " (only \\\\ and \\\" are read)"); return ""
        }
        if (c == "\"") { if (trim(substr(s, i + 1)) != "") perr("text after a closing quote"); return out }
        out = out c
      }
      perr("unclosed double quote"); return ""
    }
    function tabfree(v) { if (index(v, "\t")) perr("a tab inside a value"); return v }
    function flowlist(v, kind,   inner, n, parts, i) {
      if (v !~ /^\[.*\]$/) { perr("expected a flow list [ ... ]"); return }
      inner = substr(v, 2, length(v) - 2)
      if (trim(inner) == "") return
      n = split(inner, parts, ",")
      for (i = 1; i <= n; i++) printf "%s\t%s\n", kind, tabfree(unq(parts[i]))
    }
    function flowmap(v,   inner, n, parts, i, k, x, src, dest, af) {
      inner = substr(v, 2, length(v) - 2); src = ""; dest = ""; af = 0
      n = split(inner, parts, ",")
      for (i = 1; i <= n; i++) {
        x = trim(parts[i]); if (x == "") continue
        if (!index(x, ":")) { perr("templates entry field without a colon: " x); return }
        k = trim(substr(x, 1, index(x, ":") - 1)); x = unq(substr(x, index(x, ":") + 1))
        if (k == "src") src = x
        else if (k == "dest") dest = x
        else if (k == "after_freeze") { if (x == "true") af = 1; else if (x != "false") perr("after_freeze must be true or false") }
        else if (k != "refresh") { perr("templates entry key " k " is not read"); return }
      }
      if (src == "" || dest == "") { perr("templates entry needs src and dest"); return }
      printf "TPL\t%s\t%s\t%d\n", tabfree(src), tabfree(dest), af
    }
    function kv() { k = trim(substr(c, 1, index(c, ":") - 1)); v = trim(substr(c, index(c, ":") + 1)) }
    NR == 1 { if ($0 != "---") perr("no YAML frontmatter (first line is not ---)"); started = 1; next }
    done || bad { next }
    $0 == "---" { done = 1; next }
    {
      if ($0 ~ /^\t/) { perr("tab indentation"); next }
      line = strip_comment($0)
      if (line ~ /^[ \t]*$/) next
      match(line, /^ */); ind = RLENGTH; c = trim(line)
      if (ind == 0) {
        if (c !~ /^[A-Za-z_][A-Za-z0-9_-]*:/) { perr("not a key: " c); next }
        kv(); top = k; kid = ""; kkey = ""; sub2 = ""
        if (k == "type") next
        if (k == "imports") { if (v != "") flowlist(v, "IMP"); next }
        if (k == "templates") { if (v != "" && v != "[]") perr("templates: expected [] or a block list"); next }
        if (k == "fork") { printf "FORK\t%s\n", tabfree(unq(v)); next }
        if (k == "adapters" || k == "settings" || k == "knobs") { if (v != "") perr(k ": expected a nested block"); next }
        printf "NOTE\tprofile key %s is not read\n", k; top = "?"; next
      }
      if (top == "?") next
      if (top == "imports") { if (ind == 2 && c ~ /^- /) printf "IMP\t%s\n", tabfree(unq(substr(c, 3))); else perr("imports: expected \"  - <id>\""); next }
      if (top == "templates") { if (ind == 2 && c ~ /^- \{.*\}$/) flowmap(trim(substr(c, 3))); else perr("templates: expected \"  - { src: ..., dest: ... }\""); next }
      if (top == "adapters") { if (ind == 2 && c ~ /^[A-Za-z_]+:/) { kv(); printf "ADP\t%s\t%s\n", k, tabfree(unq(v)) } else perr("adapters: expected \"  <role>: <file>\""); next }
      if (top == "settings") {
        if (ind == 2 && c ~ /^[A-Za-z_]+:/) {
          kv(); sub2 = ""
          if (k == "allow") { sub2 = "allow"; if (v != "") flowlist(v, "ALLOW") }
          else if (k == "enabled_mcp_servers") flowlist(v, "MCP")
          else perr("settings." k " is not read")
          next
        }
        if (ind == 4 && sub2 == "allow" && c ~ /^- /) { printf "ALLOW\t%s\n", tabfree(unq(substr(c, 3))); next }
        perr("settings: unsupported line"); next
      }
      if (top == "knobs") {
        if (ind == 2) { if (c !~ /^[A-Za-z0-9_-]+:$/) { perr("knobs: expected \"  <id>:\""); next } kid = substr(c, 1, length(c) - 1); kkey = ""; printf "KB\t%s\n", kid; next }
        if (ind == 4 && kid != "" && index(c, ":")) {
          kv()
          if (v == "") { printf "K\t%s\t%s\tL\t\n", kid, k; kkey = k }
          else { printf "K\t%s\t%s\tS\t%s\n", kid, k, tabfree(unq(v)); kkey = "" }
          next
        }
        if (ind == 6 && kkey != "" && c ~ /^- /) { printf "I\t%s\t%s\t%s\n", kid, kkey, tabfree(unq(substr(c, 3))); next }
        perr("knobs: unsupported indentation or line"); next
      }
    }
    END { if (!bad && !done) perr("unclosed frontmatter") }' "$1"
}

# Answers file → records: M key value | T name value | KA id | KL id rawline | F n key | NOTE t | E t.
# Fill bodies land in $FILLDIR/<n>.
parse_answers() { # <answers.md> → stdout
  awk "$FENCEFN"'
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function aerr(m) { if (!bad) printf "E\tanswers line %d: %s\n", NR, m; bad = 1 }
    bad { next }
    {
      t = trim($0); fk = fence_line($0); isf = (fk || fch != ""); if (fk == 1) fline = NR
      if (!isf && t ~ /^<!-- \/?(answers|knobs|fill):[^ ].* -->$/ && (blk == "" || substr(t, 6, 1) == "/")) {
        inner = substr(t, 6, length(t) - 9)
        if (substr(inner, 1, 1) == "/") {
          if (substr(inner, 2) != blk) { aerr("closing tag " inner " does not close " (blk == "" ? "any open block" : blk)); next }
          if (kind == "F") close(fpath)
          blk = ""; kind = ""; next
        }
        if (inner in seen) { aerr("block " inner " appears twice"); next }
        seen[inner] = 1; blk = inner
        if (inner == "answers:meta") kind = "M"
        else if (inner == "answers:tokens") kind = "T"
        else if (inner ~ /^answers:/) { aerr("unknown block " inner); next }
        else if (inner ~ /^knobs:/) { kind = "K"; kid = substr(inner, 7); if (kid !~ /^[A-Za-z0-9_-]+$/) aerr("bad knob id " kid); printf "KA\t%s\n", kid }
        else {
          kind = "F"; key = substr(inner, 6)
          if (!index(key, "#")) { aerr("fill key " key " has no #<heading>"); next }
          nf++; fpath = ENVIRON["FILLDIR"] "/" nf; printf "" > fpath; printf "F\t%d\t%s\n", nf, key
        }
        next
      }
      if (blk == "") next
      if (kind == "F") { print $0 > fpath; next }
      if (t == "") next
      if (kind == "K") { printf "KL\t%s\t%s\n", kid, $0; next }
      if ($0 !~ /^- [^:]+:( |$)/) { aerr("in " blk ": expected \"- <key>: <value>\""); next }
      k = trim(substr($0, 3, index($0, ":") - 3)); v = substr($0, index($0, ":") + 1)
      sub(/^ /, "", v); sub(/[ \t]+$/, "", v)
      if (index(v, "\t")) { aerr("a tab inside a value"); next }
      if (kind == "T" && k !~ /^[A-Za-z0-9_]+$/) { aerr("token name " k " is not [A-Za-z0-9_]+"); next }
      if ((kind, k) in have) { aerr(blk " key " k " appears twice"); next }
      have[kind, k] = 1
      printf "%s\t%s\t%s\n", kind, k, v
    }
    END { if (!bad && fch != "") aerr("the code fence opened on line " fline " is never closed, so no tag after it is read")
          if (!bad && blk != "") aerr("block " blk " is not closed") }' "$1"
}

rec_get() { # <records> <kind> <key> → value of the first "<kind>\t<key>\t<value>"
  RK=$2 RN=$3 awk '{ i = index($0, "\t"); if (substr($0, 1, i - 1) != ENVIRON["RK"]) next
    r = substr($0, i + 1); j = index(r, "\t"); if (substr(r, 1, j - 1) == ENVIRON["RN"]) { print substr(r, j + 1); exit } }' "$1" || return 2
}
rec_field2() { awk -F "$TAB" -v k="$2" '$1 == k { print $2 }' "$1"; } # kind names only, never data through -v

# ---- render passes ---------------------------------------------------------------------------------
# {{NAME}} substitution from $ST/tokens (NAME<TAB>value); structural tokens are left for the
# structural pass; an unknown name is written to $ST/missing.
tok_pass() { # <in> <out>
  : > "$ST/missing"
  TOKF=$ST/tokens MISSF=$ST/missing awk '
    BEGIN { f = ENVIRON["TOKF"]; while ((getline l < f) > 0) { i = index(l, "\t"); tv[substr(l, 1, i - 1)] = substr(l, i + 1) } close(f)
            st["KNOB_BLOCKS"] = 1; st["IMPORT_LINES"] = 1; st["CHUNK_READ_LIST"] = 1 }
    {
      s = $0; out = ""
      while ((i = index(s, "{{")) > 0) {
        out = out substr(s, 1, i - 1); r = substr(s, i + 2); j = index(r, "}}")
        nm = (j > 0) ? substr(r, 1, j - 1) : ""
        if (j > 0 && nm ~ /^[A-Za-z0-9_]+$/) {
          if (nm in tv) out = out tv[nm]
          else { out = out "{{" nm "}}"; if (!(nm in st) && !(nm in miss)) { miss[nm] = 1; print nm > ENVIRON["MISSF"] } }
          s = substr(r, j + 2); continue
        }
        out = out "{{"; s = r
      }
      print out s
    }' "$1" > "$2" || stop "awk failed substituting tokens in $3"
  if [ -s "$ST/missing" ]; then
    stop "token {{$(head -n 1 "$ST/missing")}} has no value — in $3; give it in the answers file's answers:tokens block"
  fi
}

# Fork slot and fill prompts. Keys are <dest>#<nearest preceding heading>.
# Render mode records each used key with the zone it sits in (empty outside one) in fills.used.
# Outside mode (a re-run over a file already in the target, O2) replaces only the prompts outside
# every zone, leaves the fork slot alone, and writes one FILLED line per key used to filled.now.
fill_pass() { # <in> <out> <dest> [outside]
  : > "$ST/err"; : > "$ST/filled.now"
  DEST=$3 OUTSIDE=${4:-} FILLIDX=$ST/fills.idx FILLDIR=$ST/fills FORK=$FORK USEDF=$ST/fills.used FILLEDF=$ST/filled.now ERRF=$ST/err awk "$FENCEFN$CODESPANFN"'
    BEGIN {
      f = ENVIRON["FILLIDX"]; while ((getline l < f) > 0) { i = index(l, "\t"); fn[substr(l, i + 1)] = substr(l, 1, i - 1) } close(f)
      dest = ENVIRON["DEST"]; fork = ENVIRON["FORK"]; heading = ""; outside = (ENVIRON["OUTSIDE"] != ""); z = ""
    }
    function norm(s) { gsub(/[ \t\n]+/, " ", s); return s }
    function filltext(n,   p, l, t, first) {
      p = ENVIRON["FILLDIR"] "/" n; t = ""; first = 1
      while ((getline l < p) > 0) { t = first ? l : t "\n" l; first = 0 } close(p); return t
    }
    function span(body,   nb, k) {
      nb = norm(body)
      if (nb == "`/name`, filled at init") return outside ? "*<" body ">*" : "`/" fork "`"
      if (substr(nb, 1, 12) == "Fill at init") {
        k = dest "#" heading; cnt[k]++
        if (cnt[k] == 2 && (!outside || (k in fn))) print "more than one fill prompt under heading \"" heading "\" in " dest " — fill:" k " is ambiguous" > ENVIRON["ERRF"]
        if (outside && z != "") return "*<" body ">*"
        if (k in fn) { used[k] = outside ? "-outside" : z; return filltext(fn[k]) }
      }
      return "*<" body ">*"
    }
    function scan(s,   out, i, r, j, b, e) {
      out = ""
      while ((i = index(s, "*<")) > 0) {
        b = outside ? index(s, "`") : 0
        if (b && b < i) { # the outside pass copies an inline code span verbatim: a quoted prompt is prose
          e = codespan(s, b); if (!e) e = b + CSRUN
          out = out substr(s, 1, e - 1); s = substr(s, e); continue
        }
        r = substr(s, i + 2)
        if (substr(r, 1, 12) == "Fill at init" || substr(r, 1, 7) == "`/name`") {
          j = index(r, ">*")
          if (j > 0) { out = out substr(s, 1, i - 1) span(substr(r, 1, j - 1)); s = substr(r, j + 2); continue }
          pre = out substr(s, 1, i - 1); buf = r; collecting = 1; return ""
        }
        out = out substr(s, 1, i + 1); s = r
      }
      return out s
    }
    {
      line = $0
      if (collecting) {
        j = index(line, ">*")
        if (!j) { buf = buf "\n" line; next }
        collecting = 0
        head = pre span(buf "\n" substr(line, 1, j - 1))
        res = scan(substr(line, j + 2))
        if (collecting) { pre = head pre; next }
        print head res; next
      }
      t = line; sub(/^[ \t]+/, "", t); sub(/[ \t]+$/, "", t)
      fk = fence_line(line); fz = (fk || fch != "")
      if (!fz && t ~ /^<!-- zone:[^ ]+ -->$/) { z = t; sub(/^<!-- zone:/, "", z); sub(/ -->$/, "", z) }
      else if (!fz && t ~ /^<!-- \/zone:[^ ]+ -->$/) z = ""
      else if (!fz && line ~ /^#+[ \t]/) { h = line; sub(/^#+[ \t]+/, "", h); sub(/[ \t]+$/, "", h); heading = h }
      if (outside && fz) { print line; next } # fenced text is prose: the outside pass neither fills nor counts it
      res = scan(line)
      if (!collecting) print res
    }
    END {
      if (collecting) printf "%s*<%s\n", pre, buf
      for (k in used) { print k "\t" used[k] >> ENVIRON["USEDF"]; if (outside) print "FILLED " k >> ENVIRON["FILLEDF"] }
    }' "$1" > "$2" || stop "awk failed applying fills in $3"
  [ -s "$ST/err" ] && stop "$(head -n 1 "$ST/err")"
  return 0
}

# Structural pass over a token-substituted engine Template: knob blocks, imports zone, read-list
# zone, marker zones (D5 stub replacement for the contract), canary zone, gate-runner seat zones.
struct_pass() { # <kind> <in> <out>
  : > "$ST/err"
  KIND=$1 ERRF=$ST/err KNOBS=$ST/knobs.md IMPORTS=$ST/imports.md READLIST=$ST/readlist.md \
  FRAG_CONTRACT=$FRAG_CONTRACT FRAG_CLAUDE=$FRAG_CLAUDE FRAG_CODEX=$FRAG_CODEX FRAG_GATE=$FRAG_GATE \
  TRACKER_FRAG=$TRACKER_FRAG awk "$FENCEFN"'
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function fail(m) { if (!failed) print m > ENVIRON["ERRF"]; failed = 1 }
    function cat(p,   l) { if (p == "") return; while ((getline l < p) > 0) print l; close(p) }
    function zone(nm, p) { print "<!-- zone:" nm " -->"; cat(p); print "<!-- /zone:" nm " -->" }
    function ismarker(s) { return trim(s) ~ /^<!-- profile:[A-Za-z0-9_-]+ -->$/ }
    function mname(s) { s = trim(s); sub(/^<!-- profile:/, "", s); sub(/ -->$/, "", s); return s }
    function frag(m) {
      if (m == "contract-sections") return ENVIRON["FRAG_CONTRACT"]
      if (m == "claude-mechanics") return ENVIRON["FRAG_CLAUDE"]
      if (m == "codex-mechanics") return ENVIRON["FRAG_CODEX"]
      if (m == "gate-runner-mechanics") return ENVIRON["FRAG_GATE"]
      fail("the Template carries a marker this engine does not know: profile:" m); return ""
    }
    function out(i,   t, m) {
      t = trim(L[i])
      if (t == "{{KNOB_BLOCKS}}") { cat(ENVIRON["KNOBS"]); return }
      if (t == "{{IMPORT_LINES}}") { zone("imports", ENVIRON["IMPORTS"]); return }
      if (t == "3. {{CHUNK_READ_LIST}}") { zone("read-list", ENVIRON["READLIST"]); return }
      if (ismarker(L[i])) { m = mname(L[i]); zone(m, frag(m)); return }
      print L[i]
    }
    function pmatch(f, s) { return substr(f, 1, length(s)) == s && (length(f) == length(s) || substr(f, length(s) + 1, 1) !~ /[A-Za-z0-9]/) }
    { L[++n] = $0 }
    END {
      kind = ENVIRON["KIND"]
      if (kind == "contract") {
        for (i = 1; i <= n; i++) { if (ismarker(L[i]) && mname(L[i]) == "contract-sections") mi = i; if (L[i] == "## Project") pj = i }
        if (!mi || !pj || pj > mi) { fail("the contract Template has no ## Project before its contract-sections marker"); exit }
        for (i = pj + 1; i < mi; i++) if (L[i] ~ /^## /) { ns++; ss[ns] = i; sh[ns] = trim(L[i]) }
        fp = ENVIRON["FRAG_CONTRACT"]; nf = 0
        if (fp != "") { while ((getline l < fp) > 0) { if (!fence_line(l) && fch == "" && l ~ /^## /) fh[++nf] = trim(l) } close(fp) }
        first = 0
        for (s = 1; s <= ns; s++) { rep[s] = 0; for (j = 1; j <= nf; j++) if (pmatch(fh[j], sh[s])) rep[s] = 1; if (rep[s] && !first) first = s }
        zs = mi
        if (first) {
          zs = ss[first]
          for (s = first; s <= ns; s++) if (!rep[s]) { fail("the contract fragment replaces a stub before \"" sh[s] "\" but not that stub — a fragment shape this engine does not support"); exit }
        }
        for (i = 1; i < zs; i++) out(i)
        zone("contract-sections", fp)
        for (i = mi + 1; i <= n; i++) out(i)
        if (ENVIRON["TRACKER_FRAG"] != "") { print ""; zone("issue-tracker", ENVIRON["TRACKER_FRAG"]) }
      } else if (kind == "agents") {
        last = n; while (last > 0 && trim(L[last]) == "") last--
        if (!last || L[last] !~ /^Canary: /) { fail("the AGENTS.md Template does not end in a Canary: line"); exit }
        for (i = 1; i < last; i++) out(i)
        print "<!-- zone:canary -->"; print L[last]; print "<!-- /zone:canary -->"
      } else if (kind == "gate") {
        fe = 0; if (L[1] == "---") for (i = 2; i <= n; i++) if (L[i] == "---") { fe = i; break }
        for (i = fe + 1; i <= n; i++) {
          if (L[i] == "## Project gates") pg = i; else if (L[i] == "## Report") rp = i
          else if (ismarker(L[i]) && mname(L[i]) == "gate-runner-mechanics") gm = i
        }
        if (!fe || !pg || !rp || !gm || !(pg < rp && rp < gm)) { fail("the gate-runner Template lacks frontmatter, ## Project gates, ## Report or its marker, in that order"); exit }
        for (i = 1; i <= fe; i++) print L[i]
        print "<!-- zone:seat-body -->"; for (i = fe + 1; i < pg; i++) out(i); print "<!-- /zone:seat-body -->"
        for (i = pg; i < rp; i++) out(i)
        print "<!-- zone:seat-report -->"; for (i = rp; i < gm; i++) out(i); print "<!-- /zone:seat-report -->"
        for (i = gm; i <= n; i++) out(i)
      } else for (i = 1; i <= n; i++) out(i)
    }' "$2" > "$3" || stop "awk failed rendering $4"
  [ -s "$ST/err" ] && stop "$(head -n 1 "$ST/err")"
  if grep -Eq '[{][{](KNOB_BLOCKS|IMPORT_LINES|CHUNK_READ_LIST)[}][}]' "$3"; then
    stop "a structural token survives outside its place in the Template for $4"
  fi
  return 0
}

# Knob blocks, D1 precedence, into $ST/knobs.md.
render_knobs() {
  : > "$ST/err"; : > "$ST/knobs.md"
  _len=$RERUN; [ "$SUB" = check ] && _len=1
  LENIENT=$_len TYPE=$TYPE TRACKER=$TRACKER PREC=$PREC GREC=$GREC AREC=$ST/answers.rec OUT=$ST/knobs.md ERRF=$ST/err awk '
    function rest(l, n,   k) { for (k = 0; k < n; k++) l = substr(l, index(l, "\t") + 1); return l }
    function fail(m) { if (!failed) print m > ENVIRON["ERRF"]; failed = 1 }
    function isshape(v) { return v ~ /^<.*>$/ }
    function load(p, want, tr,   l, f, id) {
      if (p == "") return
      while ((getline l < p) > 0) {
        split(l, f, "\t"); id = f[2]
        if (f[1] == "KB" && !tr) { pn++; pid[pn] = id; plisted[id] = 1; continue }
        if ((id == "tracker-github") != tr) continue
        if (f[1] == "K") { nk[id]++; key[id, nk[id]] = f[3]; shp[id, f[3]] = f[4]; val[id, f[3]] = rest(l, 4) }
        else if (f[1] == "I") { ni[id, f[3]]++; item[id, f[3], ni[id, f[3]]] = rest(l, 3) }
      }
      close(p)
    }
    function add(id) { if (id in inset) return; nb++; blk[nb] = id; inset[id] = 1 }
    BEGIN {
      type = ENVIRON["TYPE"]; tracker = ENVIRON["TRACKER"]; o = ENVIRON["OUT"]
      lenient = (ENVIRON["LENIENT"] == "1")   # a re-run: the contract keeps its values; rewrite_knobs applies D1
      load(ENVIRON["PREC"], "", 0)
      if (tracker == "github") load(ENVIRON["GREC"], "", 1)
      a = ENVIRON["AREC"]
      while ((getline l < a) > 0) {
        split(l, f, "\t")
        if (f[1] == "KA") { an++; aid[an] = f[2]; cur = ""; continue }
        if (f[1] != "KL") continue
        id = f[2]; line = rest(l, 2)
        if (line ~ /^- [^:]+:( |$)/) {
          k = substr(line, 3, index(line, ":") - 3)
          if ((id, k) in araw) { fail("answers knobs:" id " lists " k " twice"); continue }
          ank[id]++; akey[id, ank[id]] = k; araw[id, k] = line; cur = k
        } else if (line ~ /^[ \t]+[^ \t]/ && cur != "") araw[id, cur] = araw[id, cur] "\n" line
        else fail("answers knobs:" id ": a line that is neither \"- <key>: <value>\" nor an indented continuation")
      }
      close(a)
      if (tracker == "github" && (type == "none" || !("tracker-github" in plisted))) add("tracker-github")
      if (type != "none") { for (i = 1; i <= pn; i++) { id = pid[i]; if (id == "tracker-github" && tracker != "github") continue; add(id) } }
      else for (i = 1; i <= an; i++) if (aid[i] != "tracker-github") add(aid[i])
      for (i = 1; i <= an; i++) if (!(aid[i] in inset)) fail("answers block knobs:" aid[i] " names no knob block this stamp writes")
      for (b = 1; b <= nb; b++) {
        id = blk[b]; fromans = (type == "none" && id != "tracker-github")
        if (!fromans) {
          for (j = 1; j <= nk[id]; j++) listed[id, key[id, j]] = 1
          for (j = 1; j <= ank[id]; j++) if (!((id, akey[id, j]) in listed)) fail("answers key " id "." akey[id, j] " is not in the Profile block knobs:" id)
        }
        if (b > 1) print "" > o
        print "<!-- knobs:" id " -->" > o
        cnt = fromans ? ank[id] : nk[id]
        for (j = 1; j <= cnt; j++) {
          k = fromans ? akey[id, j] : key[id, j]
          if ((id, k) in araw) { print araw[id, k] > o; continue }
          if (shp[id, k] == "S") {
            if (isshape(val[id, k]) && !lenient) { fail("knob " id "." k " has no value — the Profile gives the shape " val[id, k] "; answer it in the answers file block knobs:" id); continue }
            print "- " k ": " val[id, k] > o; continue
          }
          for (m = 1; m <= ni[id, k]; m++) if (isshape(item[id, k, m]) && !lenient) fail("knob " id "." k " has no value — a Profile list item is the shape " item[id, k, m])
          print "- " k ":" > o
          for (m = 1; m <= ni[id, k]; m++) print "  " m ". " item[id, k, m] > o
        }
        print "<!-- /knobs:" id " -->" > o
      }
      if (!nb) print "no knob blocks: the Profile lists none and the answers file gives none" > (ENVIRON["ERRF"] ".note")
    }' || stop "awk failed rendering the knob blocks"
  [ -s "$ST/err" ] && stop "$(head -n 1 "$ST/err")"
  [ -s "$ST/err.note" ] && note "$(head -n 1 "$ST/err.note")"
  return 0
}

count_word() { # <n> → English word one..twenty, or empty
  awk -v n="$1" 'BEGIN { split("one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty", w, " "); if (n >= 1 && n <= 20) print w[n] }'
}
chunk_names() { # <file> → the <name>.md of each @~/.claude/chunks/<name>.md line outside fences
  awk "$FENCEFN"'fence_line($0) || fch != "" { next }
       /^@~\/\.claude\/chunks\/[^ \/]+\.md[ \t]*$/ { n = $0; sub(/^@~\/\.claude\/chunks\//, "", n); sub(/[ \t]+$/, "", n); print n }' "$1"
}

# Render a non-engine file (Profile template, pointer): tokens, then fills; keeps the exec bit.
render_plain() { # <src> <target-relative dest>
  _out=$ST/render/$2
  mkdir -p "$(dirname "$_out")" || stop "cannot create staging for $2"
  if grep -q '{{' "$1" || grep -q '\*<' "$1"; then
    tok_pass "$1" "$ST/t1.tmp" "$2"
    fill_pass "$ST/t1.tmp" "$_out" "$2"
  else
    cp "$1" "$_out" || stop "cannot stage $2"
  fi
  [ -x "$1" ] && chmod +x "$_out"
  printf 'W\t%s\t%s\n' "$2" "$1" >> "$ST/plan"
}

check_dest() { # a manifest dest must stay inside the target
  case $1 in /*|../*|*/../*|*/..|..) stop "Profile template dest $1 leaves the target" ;; esac
}

# ---- re-run: zone refresh, the D8 fill guard, the knob rewrite -------------------------------------
# A present engine file → $ST/final/<dest>: each zone tagged in the target takes the staged render's
# content; nothing outside a zone moves. ZONE lines go to $ST/log.
refresh_file() { # <kind> <dest>
  _rt=$TARGET/$2; _rr=$ST/render/$2; _ro=$ST/final/$2
  mkdir -p "$(dirname "$_ro")" || stop "cannot create staging for $2"
  zone_names "$_rr" > "$ST/zn" || stop "awk failed reading the staged render of $2"
  printf '%s\n' "$2" >> "$ST/present"
  zone_names "$_rt" | D=$2 awk '{ print ENVIRON["D"] "\t" $0 }' >> "$ST/tzones" || stop "awk failed reading $2"
  if ! has_zone_tag "$_rt"; then # v1: every non-knob zone reads absent; only a fill (O2) is applied
    cp "$_rt" "$_ro" || stop "cannot stage $2"
    while IFS= read -r _zn; do printf 'ZONE %s %s absent\n' "$2" "$_zn"; done < "$ST/zn" >> "$ST/log"
    fill_outside "$_ro" "$2"
    return 0
  fi
  d8_guard "$2"
  : > "$ST/err"
  RENDER=$_rr FRONT=$([ "$1" = gate ] && printf 1) DEST=$2 LOGF=$ST/log ERRF=$ST/err awk "$FENCE"'
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function tagname(t) { sub(/^<!-- \/?zone:/, "", t); sub(/ -->$/, "", t); return t }
    BEGIN {
      r = ENVIRON["RENDER"]; front = (ENVIRON["FRONT"] == "1"); dest = ENVIRON["DEST"]; lg = ENVIRON["LOGF"]
      ln = 0; cur = ""
      while ((getline l < r) > 0) {
        ln++
        if (front && ln == 1 && l == "---") { infm = 1; rf = l "\n"; continue }
        if (infm) { rf = rf l "\n"; if (l == "---") { infm = 0; hasrf = 1 } continue }
        t = trim(l); rfz = (fence_line(l) || fch != "")
        if (!rfz && t ~ /^<!-- zone:[^ ]+ -->$/) { cur = tagname(t); nz++; zo[nz] = cur; zc[cur] = ""; inr[cur] = 1; continue }
        if (!rfz && t ~ /^<!-- \/zone:[^ ]+ -->$/) { cur = ""; continue }
        if (cur != "") zc[cur] = zc[cur] l "\n"
      }
      close(r); cur = ""; fch = "" # the target file starts outside any fence
    }
    front && NR == 1 && $0 == "---" { tin = 1; tf = $0 "\n"; next }
    tin {
      tf = tf $0 "\n"
      if ($0 == "---") {
        tin = 0; hastf = 1
        if (hasrf) { printf "%s", rf; fst = (tf == rf) ? "same" : "refreshed" } else printf "%s", tf
      }
      next
    }
    { t = trim($0) }
    !fz && t ~ /^<!-- zone:[^ ]+ -->$/ { print; cur = tagname(t); buf = ""; next }
    !fz && t ~ /^<!-- \/zone:[^ ]+ -->$/ {
      if (cur in inr) { printf "%s", zc[cur]; st[cur] = (buf == zc[cur]) ? "same" : "refreshed" }
      else { printf "%s", buf; orph[++no] = cur }
      seen[cur] = 1; print; cur = ""; next
    }
    cur != "" { buf = buf $0 "\n"; next }
    { print }
    END {
      if (tin) { print "the frontmatter opened on line 1 is never closed" > ENVIRON["ERRF"]; exit }
      if (front && hasrf) printf "ZONE %s frontmatter %s\n", dest, (hastf ? fst : "absent") >> lg
      for (i = 1; i <= nz; i++) printf "ZONE %s %s %s\n", dest, zo[i], ((zo[i] in seen) ? st[zo[i]] : "absent") >> lg
      for (i = 1; i <= no; i++) printf "ZONE %s %s orphan\n", dest, orph[i] >> lg
    }' "$_rt" > "$_ro" || stop "awk failed refreshing the zones of $2"
  [ -s "$ST/err" ] && stop "$2: $(head -n 1 "$ST/err") — nothing written"
  fill_outside "$_ro" "$2"
  return 0
}

# O2: on a stamp re-run, a fill whose prompt survives outside every zone of a file already in the
# target replaces exactly that span — the one write outside a zone a re-run makes. 0 when one did.
fill_outside() { # <staged file, rewritten in place> <dest>
  [ "$SUB" = stamp ] || return 1
  D=$2# awk -F "$TAB" 'index($2, ENVIRON["D"]) == 1 { f = 1 } END { exit !f }' "$ST/fills.idx" || return 1
  fill_pass "$1" "$1.o" "$2" outside
  [ -s "$ST/filled.now" ] || { rm -f "$1.o"; return 1; }
  mv -f "$1.o" "$1" || stop "cannot stage $2"
  cat "$ST/filled.now" >> "$ST/log"
}

# Each Fill-at-init prompt inside a zone: <zone> TAB <nearest preceding heading> TAB <prompt, spaces folded>.
prompts_of() { # <file>
  awk "$FENCEFN"'
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function emit(b) { gsub(/[ \t\n]+/, " ", b); if (pz != "") print pz "\t" ph "\t" trim(b) }
    {
      line = $0; t = trim(line)
      if (coll) {
        j = index(line, ">*")
        if (!j) { buf = buf " " line; next }
        emit(buf " " substr(line, 1, j - 1)); coll = 0; line = substr(line, j + 2)
      } else if (fence_line(line) || fch != "") fz = 1
      else if (t ~ /^<!-- zone:[^ ]+ -->$/) { z = t; sub(/^<!-- zone:/, "", z); sub(/ -->$/, "", z); next }
      else if (t ~ /^<!-- \/zone:[^ ]+ -->$/) { z = ""; next }
      else if (line ~ /^#+[ \t]/) { h = line; sub(/^#+[ \t]+/, "", h); sub(/[ \t]+$/, "", h); heading = h }
      while ((i = index(line, "*<Fill at init")) > 0) {
        r = substr(line, i + 2); j = index(r, ">*"); pz = z; ph = heading
        if (j) { emit(substr(r, 1, j - 1)); line = substr(r, j + 2) } else { buf = r; coll = 1; break }
      }
    }' "$1"
}

# D8: a refreshed zone must not gain a Fill-at-init prompt its target zone does not carry.
d8_guard() { # <dest>
  [ "$SUB" = stamp ] || return 0
  prompts_of "$ST/render/$1" > "$ST/p.r" || stop "awk failed reading the staged render of $1"
  prompts_of "$TARGET/$1" > "$ST/p.t" || stop "awk failed reading $1"
  zone_names "$TARGET/$1" > "$ST/p.z" || stop "awk failed reading $1"
  _g=$(PR=$ST/p.r PT=$ST/p.t PZ=$ST/p.z awk 'BEGIN {
      FS = "\t"
      while ((getline l < ENVIRON["PZ"]) > 0) inz[l] = 1
      while ((getline l < ENVIRON["PT"]) > 0) { split(l, f, "\t"); have[f[1] "\t" f[3]] = 1 }
      while ((getline l < ENVIRON["PR"]) > 0) {
        split(l, f, "\t")
        if ((f[1] in inz) && !((f[1] "\t" f[3]) in have)) { print f[1] "\t" f[2]; exit }
      }
    }') || stop "awk failed comparing the fill prompts of $1"
  [ -z "$_g" ] || stop "zone ${_g%%"$TAB"*} of $1 would gain a Fill at init prompt its target zone does not carry, and the answers file has no fill:$1#${_g#*"$TAB"} — give that fill (nothing written)"
}

# D2: a re-run's contract. Existing values stay verbatim; only the key set changes. KNOB lines → $ST/log.
rewrite_knobs() { # <in> <out>
  [ -f "$KNOB_CHANGES" ] || stop "the knob-changes file $KNOB_CHANGES is not found"
  : > "$ST/err"
  IN=$1 OUT=$2 TYPE=$TYPE TRACKER=$TRACKER PREC=$PREC GREC=$GREC AREC=$ST/answers.rec KCH=$KNOB_CHANGES \
  LOGF=$ST/log ERRF=$ST/err awk "$FENCEFN"'
    function rest(l, n,   k) { for (k = 0; k < n; k++) l = substr(l, index(l, "\t") + 1); return l }
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function fail(m) { if (!failed) print m > ENVIRON["ERRF"]; failed = 1 }
    function normk(s) { gsub(/[-_ ]/, "_", s); return s }
    function isshape(v) { return v ~ /^<.*>$/ }
    function klog(m) { print m >> ENVIRON["LOGF"] }
    function load(p, tr,   l, f, id) {
      if (p == "") return
      while ((getline l < p) > 0) {
        split(l, f, "\t"); id = f[2]
        if (f[1] == "KB" && !tr) { pn++; pid[pn] = id; plisted[id] = 1; continue }
        if ((id == "tracker-github") != tr) continue
        if (f[1] == "K") { kc[id]++; key[id, kc[id]] = f[3]; shp[id, f[3]] = f[4]; val[id, f[3]] = rest(l, 4) }
        else if (f[1] == "I") { ni[id, f[3]]++; item[id, f[3], ni[id, f[3]]] = rest(l, 3) }
      }
      close(p)
    }
    function add(id) { if (id in inset) return; nw++; want[nw] = id; inset[id] = 1 }
    function d1(id, p,   m, s) { # the value of a key being written fresh: answers, else a Profile literal
      if ((id, p) in araw) return araw[id, p]
      if (shp[id, p] == "S") {
        if (isshape(val[id, p])) { fail("knob " id "." p " has no value — the Profile gives the shape " val[id, p] "; answer it in the answers file block knobs:" id " (nothing written)"); return "" }
        return "- " p ": " val[id, p]
      }
      if (shp[id, p] != "L") { fail("knob " id "." p " has no value — answer it in the answers file block knobs:" id " (nothing written)"); return "" }
      s = "- " p ":"
      for (m = 1; m <= ni[id, p]; m++) {
        if (isshape(item[id, p, m])) { fail("knob " id "." p " has no value — a Profile list item is the shape " item[id, p, m] " (nothing written)"); return "" }
        s = s "\n  " m ". " item[id, p, m]
      }
      return s
    }
    function pkeys(b, id,   j, p) { # the listed keys of block b, in order, into pk[b, j]; count into pc[b]
      fromans = (type == "none" && id != "tracker-github")
      pc[b] = fromans ? ank[id] : kc[id]
      for (j = 1; j <= pc[b]; j++) { p = fromans ? akey[id, j] : key[id, j]; pk[b, j] = p; pmap[b, normk(p)] = p }
    }
    function blocktext(id,   i, t) { t = ""; for (i = bs[id]; i <= be[id]; i++) t = t L[i] "\n"; return t }
    function firstval(b, j,   v) { v = trim(substr(eh[b, j], 2)); if (v == "" && ec[b, j] != "") { v = substr(ec[b, j], 2); if (index(v, "\n")) v = substr(v, 1, index(v, "\n") - 1); v = trim(v) } return v }
    BEGIN {
      type = ENVIRON["TYPE"]; tracker = ENVIRON["TRACKER"]; o = ENVIRON["OUT"]
      load(ENVIRON["PREC"], 0)
      if (tracker == "github") load(ENVIRON["GREC"], 1)
      a = ENVIRON["AREC"]
      while ((getline l < a) > 0) {
        split(l, f, "\t")
        if (f[1] == "KA") { an++; aid[an] = f[2]; cur = ""; continue }
        if (f[1] != "KL") continue
        id = f[2]; line = rest(l, 2)
        if (line ~ /^- [^:]+:( |$)/) { k = substr(line, 3, index(line, ":") - 3); ank[id]++; akey[id, ank[id]] = k; araw[id, k] = line; cur = k }
        else if (cur != "") araw[id, cur] = araw[id, cur] "\n" line
      }
      close(a)
      c = ENVIRON["KCH"]; cn = 0
      while ((getline l < c) > 0) {
        cn++; t = trim(l)
        if (t == "" || substr(t, 1, 1) == "#") continue
        m = split(t, w, /[ \t]+/)
        if (w[1] == "rename" && m == 4) { ren[w[2], normk(w[3])] = w[4]; continue }
        if (w[1] == "retire" && m == 3) { ret[w[2], normk(w[3])] = 1; continue }
        if (w[1] == "retire-block" && m == 2) { retblk[w[2]] = 1; continue }
        fail("knob-changes line " cn ": expected \"rename <chunk-id> <old-key> <new-key>\", \"retire <chunk-id> <key>\" or \"retire-block <chunk-id>\""); exit
      }
      close(c)
      if (tracker == "github" && (type == "none" || !("tracker-github" in plisted))) add("tracker-github")
      if (type != "none") { for (i = 1; i <= pn; i++) { id = pid[i]; if (id == "tracker-github" && tracker != "github") continue; add(id) } }
      else for (i = 1; i <= an; i++) if (aid[i] != "tracker-github") add(aid[i])
      for (x = 1; x <= nw; x++) if (want[x] in retblk) { fail("knob-changes retires knobs:" want[x] " (retire-block), which " (type == "none" ? "the answers file" : "the Profile") " still lists — resolve it by hand (nothing written)"); exit }
    }
    { L[++n] = $0 }
    END {
      if (failed) exit
      for (i = 1; i <= n; i++) {
        if (fence_line(L[i]) || fch != "") continue
        if (L[i] ~ /^<!-- knobs:[A-Za-z0-9_-]+ -->$/) {
          id = substr(L[i], 12, length(L[i]) - 15)
          if (cid != "") { fail("knobs:" id " opens inside knobs:" cid " in the contract (nothing written)"); exit }
          if (id in bs) { fail("the contract carries knobs:" id " twice (nothing written)"); exit }
          bs[id] = i; cid = id; nb++; bo[nb] = id; continue
        }
        if (L[i] ~ /^<!-- \/knobs:[A-Za-z0-9_-]+ -->$/) {
          id = substr(L[i], 13, length(L[i]) - 16)
          if (id != cid) { fail("knobs:" id " closes without its open tag in the contract (nothing written)"); exit }
          be[id] = i; cid = ""; bstart[bs[id]] = id; if (i > lastclose) lastclose = i
        }
      }
      if (cid != "") { fail("knobs:" cid " is not closed in the contract (nothing written)"); exit }
      for (b = 1; b <= nb; b++) {
        id = bo[b]
        if (id == "backlog-core" && tracker == "held") { newtext[id] = blocktext(id); continue } # frozen: never parsed, never rewritten
        if (!(id in inset)) { # O1: a block goes only on a declared retire-block row; any other is kept verbatim, unparsed
          if (id in retblk) { klog("KNOB " id " block-deleted (" (be[id] - bs[id] + 1) " lines)"); del[id] = 1 }
          else { newtext[id] = blocktext(id); klog("KNOB " id " kept — not a block this stamp lists, and no retire-block row names it") }
          continue
        }
        ne = 0
        for (i = bs[id] + 1; i < be[id]; i++) {
          if (L[i] ~ /^- [^:]+:( |$)/) { ne++; ek[b, ne] = trim(substr(L[i], 3, index(L[i], ":") - 3)); eh[b, ne] = substr(L[i], index(L[i], ":")); ef[b, ne] = L[i]; ec[b, ne] = ""; continue }
          if (ne && L[i] ~ /^[ \t]+[^ \t]/) { ec[b, ne] = ec[b, ne] "\n" L[i]; continue }
          fail("knobs:" id " in the contract has a line that is neither \"- <key>: <value>\" nor an indented continuation (contract line " i ") — unparsed text is never rewritten; fix it by hand (nothing written)"); exit
        }
        pkeys(b, id); chg = 0
        for (j = 1; j <= ne; j++) { # pass 1: a listed key, however spelled
          nkk = normk(ek[b, j]); if (!((b, nkk) in pmap)) continue
          p = pmap[b, nkk]
          if ((b, p) in took) { fail("knobs:" id " in the contract carries " p " twice (as " ek[b, took[b, p]] " and " ek[b, j] ") — resolve it by hand (nothing written)"); exit }
          took[b, p] = j; done[b, j] = 1
          if (ek[b, j] != p) { klog("KNOB " id " respelled " ek[b, j] " -> " p); chg++ }
        }
        no = 0
        for (j = 1; j <= ne; j++) { # pass 2: declared renames and retirements; the rest is the project own
          if ((b, j) in done) continue
          nkk = normk(ek[b, j])
          if ((id, nkk) in ren) {
            nwk = ren[id, nkk]
            if (!((b, normk(nwk)) in pmap)) { fail("knob-changes renames " id "." ek[b, j] " to " nwk ", which the Profile does not list in knobs:" id " (nothing written)"); exit }
            p = pmap[b, normk(nwk)]
            if ((b, p) in took) { fail("knobs:" id " in the contract carries both " ek[b, j] " and " ek[b, took[b, p]] ", which knob-changes renames onto one key — resolve it by hand (nothing written)"); exit }
            took[b, p] = j; klog("KNOB " id " renamed " ek[b, j] " -> " p); chg++; continue
          }
          if ((id, nkk) in ret) { klog("KNOB " id " retired " ek[b, j] " (value was: " firstval(b, j) ")"); chg++; continue }
          own[++no] = j; klog("KNOB " id " kept " ek[b, j] " — not in the Profile")
        }
        t = L[bs[id]] "\n"
        for (j = 1; j <= pc[b]; j++) {
          p = pk[b, j]
          if ((b, p) in took) {
            e = took[b, p]; t = t ((ek[b, e] == p) ? ef[b, e] : "- " p eh[b, e]) ec[b, e] "\n"
            if (((id, p) in araw) && substr(araw[id, p], index(araw[id, p], ":")) != eh[b, e] ec[b, e]) klog("NOTE knobs:" id " " p ": the contract'"'"'s value is kept; the answers file'"'"'s differs")
            continue
          }
          v = d1(id, p); if (failed) exit
          t = t v "\n"; klog("KNOB " id " added " p); chg++
        }
        for (j = 1; j <= no; j++) t = t ef[b, own[j]] ec[b, own[j]] "\n"
        t = t L[be[id]] "\n"; newtext[id] = t
        if (t == blocktext(id)) klog("KNOB " id " kept")
        else if (!chg) klog("NOTE knobs:" id " keys reordered to the Profile order, values kept")
      }
      ins = ""
      for (x = 1; x <= nw; x++) {
        id = want[x]; if (id in bs) continue
        if (!nb) { fail("the contract carries no knob block to insert knobs:" id " after — add the block by hand (nothing written)"); exit }
        pkeys(nb + x, id); t = "<!-- knobs:" id " -->\n"
        for (j = 1; j <= pc[nb + x]; j++) { v = d1(id, pk[nb + x, j]); if (failed) exit; t = t v "\n" }
        ins = ins "\n" t "<!-- /knobs:" id " -->\n"; klog("KNOB " id " block-inserted")
      }
      for (i = 1; i <= n; i++) {
        if (i in bstart) {
          id = bstart[i]; if (!(id in del)) printf "%s", newtext[id] > o
          i = be[id]; if (i == lastclose) printf "%s", ins > o
          continue
        }
        print L[i] > o
      }
    }' "$1" || stop "awk failed rewriting the knob blocks of $CONTRACT"
  [ -s "$ST/err" ] && stop "$(head -n 1 "$ST/err")"
  [ -f "$2" ] || : > "$2"
  return 0
}

# ---- stamp -----------------------------------------------------------------------------------------
cmd_stamp() {
  target_setup
  chunk_roots

  [ "$AFTER_FREEZE" = 1 ] || probe_jq

  mk_tmpdir; ST=$MKD
  mkdir -p "$ST/fills" "$ST/frag" "$ST/t" "$ST/render" "$ST/final" || stop "cannot create staging"
  : > "$ST/plan"; : > "$ST/fills.used"
  load_inputs
  stamp_body
}

target_setup() { # --target and --answers present and real; TARGET made absolute
  [ -n "$TARGET" ] || usage_stop "$SUB needs --target"
  [ -n "$ANSWERS" ] || usage_stop "$SUB needs --answers"
  [ -d "$TARGET" ] || stop "target $TARGET is not a directory"
  [ -f "$ANSWERS" ] || stop "answers file $ANSWERS not found"
  TARGET=$(cd "$TARGET" && pwd) || stop "cannot enter target"
  PROJECT_ROOT=$TARGET
}
chunk_roots() {
  CL=$HOME/.claude/chunks; CX=$HOME/.codex/chunks
  [ -d "$CL" ] || stop "chunk root ~/.claude/chunks not found"
  [ -d "$CX" ] || stop "chunk root ~/.codex/chunks not found"
  [ -f "$CL/dev-base.md" ] || stop "~/.claude/chunks/dev-base.md not found"
}

# The answers file and the Profile it names → the records in $ST, PROJECT_NAME, TYPE, TRACKER, PREC, FORK.
load_inputs() {
  FILLDIR=$ST/fills parse_answers "$ANSWERS" > "$ST/answers.rec" || stop "awk failed reading the answers file"
  _e=$(rec_field2 "$ST/answers.rec" E | head -n 1); [ -z "$_e" ] || stop "$_e"
  awk -F "$TAB" '$1 == "F" { print $2 "\t" $3 }' "$ST/answers.rec" > "$ST/fills.idx"
  for _k in $(rec_field2 "$ST/answers.rec" M); do
    case $_k in project_name|type|tracker) ;; *) note "answers meta key $_k is not read" ;; esac
  done
  PROJECT_NAME=$(rec_get "$ST/answers.rec" M project_name) || stop "awk failed reading the answers records"
  TYPE=$(rec_get "$ST/answers.rec" M type) || stop "awk failed reading the answers records"
  TRACKER=$(rec_get "$ST/answers.rec" M tracker) || stop "awk failed reading the answers records"
  [ -n "$PROJECT_NAME" ] || stop "answers:meta has no project_name"
  [ -n "$TYPE" ] || stop "answers:meta has no type"

  # Profile
  PREC=; GREC=
  case $TYPE in
    github) stop "github is the tracker, not a type (spec #124): stamp type none with tracker github" ;;
    none) ;;
    *[!A-Za-z0-9_-]*) stop "type $TYPE is not a Profile name" ;;
    *)
      [ -f "$PROFILE_DIR/$TYPE.md" ] || stop "no Profile $TYPE (profiles: $(cd "$PROFILE_DIR" && ls *.md 2>/dev/null | sed 's/\.md$//' | tr '\n' ' ')none)"
      PREC=$ST/profile.rec
      parse_profile "$PROFILE_DIR/$TYPE.md" > "$PREC" || stop "awk failed reading Profile $TYPE"
      _e=$(rec_field2 "$PREC" E | head -n 1); [ -z "$_e" ] || stop "Profile $_e"
      rec_field2 "$PREC" NOTE | while IFS= read -r _n; do note "$_n"; done ;;
  esac
  FORK=$FORK_DEFAULT
  if [ -n "$PREC" ]; then _f=$(rec_field2 "$PREC" FORK | head -n 1); [ -z "$_f" ] || FORK=$_f; fi
  case $FORK in *[!A-Za-z0-9_-]*) stop "fork $FORK is not a Skill name" ;; esac
}

prep_target() {
  # tracker: a fresh stamp takes the answers file's; a re-run reads the contract's
  RERUN=0
  if [ -e "$TARGET/$CONTRACT" ] || [ -L "$TARGET/$CONTRACT" ]; then
    [ -f "$TARGET/$CONTRACT" ] || stop "$CONTRACT exists but is not a regular file — nothing written"
    RERUN=1
    _tg=$(tag_count '^<!-- knobs:tracker-github -->$' "$TARGET/$CONTRACT") || stop "awk failed reading $CONTRACT"
    _bc=$(tag_count '^<!-- knobs:backlog-core -->$' "$TARGET/$CONTRACT") || stop "awk failed reading $CONTRACT"
    [ "$_tg" = 0 ] || _tg=1; [ "$_bc" = 0 ] || _bc=1
    _ans=$TRACKER
    case $_tg$_bc in
      00) TRACKER=none; _said=none ;;
      10) TRACKER=github; _said=github ;;
      01) TRACKER=held; _said=backlog-core ;;
      *) stop "$CONTRACT carries knob blocks for both tracker-github and backlog-core — the tracker cannot be read from it; remove one by hand" ;;
    esac
    [ -z "$_ans" ] || [ "$_ans" = "$_said" ] || note "tracker: the contract says $_said; the answers file's $_ans is not used"
  else
    [ -n "$TRACKER" ] || stop "answers:meta has no tracker"
    case $TRACKER in github|none) ;; *) stop "tracker $TRACKER on a fresh stamp — the answers file takes github or none (held is read from an existing contract only)" ;; esac
  fi
  case $TRACKER in
    github)
      [ -f "$TRACKER_PROFILE" ] || stop "tracker github: $TRACKER_PROFILE not found"
      GREC=$ST/github.rec
      parse_profile "$TRACKER_PROFILE" > "$GREC" || stop "awk failed reading the tracker Profile"
      _e=$(rec_field2 "$GREC" E | head -n 1); [ -z "$_e" ] || stop "tracker Profile $_e"
      [ -f "$TRACKER_CONTRACT" ] || stop "tracker github: $TRACKER_CONTRACT not found" ;;
    none|held) ;;
    *) stop "tracker $TRACKER is neither github nor none" ;;
  esac

  # layout stops
  for _f in CLAUDE.md AGENTS.md "$GATE_RUNNER"; do
    if { [ -e "$TARGET/$_f" ] || [ -L "$TARGET/$_f" ]; } && [ ! -f "$TARGET/$_f" ]; then
      stop "$_f exists but is not a regular file — nothing written"
    fi
  done
  if [ "$RERUN" = 0 ]; then
    _pc=0; [ ! -f "$TARGET/CLAUDE.md" ] || _pc=$(tag_count '^<!-- knobs:' "$TARGET/CLAUDE.md") || stop "awk failed reading CLAUDE.md"
    if [ "$_pc" != 0 ]; then
      stop "pre-contract layout — CLAUDE.md carries knob blocks and there is no contract; init does not stamp, re-run or migrate it (ADR 0020)"
    fi
    for _f in CLAUDE.md AGENTS.md "$GATE_RUNNER"; do
      if [ -f "$TARGET/$_f" ]; then
        has_zone_tag "$TARGET/$_f" || stop "$_f exists with no zone tag and there is no contract — the engine does not merge into untagged text"
      fi
    done
  fi
  # every present engine file's zone tags are sound before anything is read from them
  for _f in "$CONTRACT" CLAUDE.md AGENTS.md "$GATE_RUNNER"; do
    [ -f "$TARGET/$_f" ] || continue
    _z=$(zone_check "$TARGET/$_f") || stop "$_f: $_z"; [ -z "$_z" ] || stop "$_f: $_z — nothing written"
  done
  : > "$ST/log"; : > "$ST/present"; : > "$ST/present.src"; : > "$ST/tzones"
  HELD_IMPORT=0; HELD_READ=0
  if [ "$TRACKER" = held ]; then
    _parts='knob block'
    if [ -f "$TARGET/CLAUDE.md" ]; then
      zone_extract "$TARGET/CLAUDE.md" imports > "$ST/held.z" || stop "awk failed reading CLAUDE.md"
      if grep -q '^[[:space:]]*@~/\.claude/chunks/backlog-core\.md[[:space:]]*$' "$ST/held.z"; then HELD_IMPORT=1; _parts="$_parts, imports line"; fi
    fi
    if [ -f "$TARGET/AGENTS.md" ]; then
      zone_extract "$TARGET/AGENTS.md" read-list > "$ST/held.z" || stop "awk failed reading AGENTS.md"
      if grep -qF '`backlog-core.md`' "$ST/held.z"; then HELD_READ=1; _parts="$_parts, read-list entry"; fi
    fi
    printf 'held: backlog-core (frozen) — %s\n' "$_parts" >> "$ST/log"
  fi

  # tokens: derived, then the answers file's
  { printf 'PROJECT_NAME\t%s\n' "$PROJECT_NAME"; printf 'PROJECT_ROOT\t%s\n' "$PROJECT_ROOT"; } > "$ST/tokens"
  for _k in $(rec_field2 "$ST/answers.rec" T); do
    case $_k in PROJECT_NAME|PROJECT_ROOT|KNOB_BLOCKS|IMPORT_LINES|CHUNK_READ_LIST) stop "answers token $_k is engine-derived; remove it" ;; esac
    _v=$(rec_get "$ST/answers.rec" T "$_k") || stop "awk failed reading the answers records"
    printf '%s\t%s\n' "$_k" "$_v" >> "$ST/tokens"
  done

}

stamp_body() {
  prep_target
  if [ "$AFTER_FREEZE" != 1 ]; then
    render_engine
  fi
  plan_templates
  [ "$AFTER_FREEZE" = 1 ] || [ "$TRACKER" != github ] || plan_pointers
  check_fills
  [ "$AFTER_FREEZE" = 1 ] || plan_settings

  # every planned dest is writable in shape before the first write; a link stops only where a write
  # would land on it (U, and a W whose bytes are already there, write nothing)
  while IFS="$TAB" read -r _a _d _s; do
    case $_a in W) ;; *) continue ;; esac
    if [ -L "$TARGET/$_d" ]; then
      _sf=$ST/render/$_d; [ -f "$ST/final/$_d" ] && _sf=$ST/final/$_d
      same_bytes "$_sf" "$TARGET/$_d" && continue
      stop "$_d is a symlink — the engine never replaces a link with a file; resolve it by hand (nothing written)"
    fi
    [ -d "$TARGET/$_d" ] && stop "$_d exists as a directory — nothing written"
    _p=$(dirname "$_d")
    while [ "$_p" != . ] && [ "$_p" != / ]; do
      if { [ -e "$TARGET/$_p" ] || [ -L "$TARGET/$_p" ]; } && [ ! -d "$TARGET/$_p" ]; then stop "$_p is not a directory, so $_d cannot be written — nothing written"; fi
      _p=$(dirname "$_p")
    done
  done < "$ST/plan"
  cat "$ST/log"

  # writes, in order
  while IFS="$TAB" read -r _a _d _s; do
    case $_a in
      W) if [ -f "$ST/final/$_d" ]; then write_file "$ST/final/$_d" "$_d" "$_s"; else write_file "$ST/render/$_d" "$_d" "$_s"; fi ;;
      S) printf 'SKIPPED %s — %s\n' "$_d" "$_s" ;;
      L) cat "$ST/$_d" ;;
      U) printf 'UNCHANGED %s\n' "$_d" ;;
    esac
  done < "$ST/plan"
  result clean 0
}

# ---- settings (.claude/settings.local.json): merged by jq, written last -----------------------------
jq_install() {
  case $(uname 2>/dev/null) in
    Darwin) printf 'brew install jq' ;;
    Linux) if command -v pacman >/dev/null 2>&1; then printf 'sudo pacman -S jq'; else printf 'sudo apt-get install jq'; fi ;;
    *) printf 'jq from this system'"'"'s package manager' ;;
  esac
}
probe_jq() { command -v jq >/dev/null 2>&1 || stop "jq not found — the settings merge needs it. Install: $(jq_install)"; }

SETTINGS=.claude/settings.local.json
SETTINGS_BASELINE='{"permissions":{"defaultMode":"auto"},"sandbox":{"enabled":true}}'
# Input: the existing file (or the baseline). $allow / $mcp: the Profile delta. Output: {out, log, delta}.
# Deny wins; an entry in both lists is reported and left; every other key is preserved.
SETTINGS_JQ='
  [inputs] | if length != 1 then error("the file does not hold exactly one JSON value") else .[0] end
  | if type != "object" then error("the top level is not a JSON object") else . end
  | if has("permissions") and (.permissions | type) != "object" then error("permissions is not an object") else . end
  | (.permissions.allow // []) as $al0 | (.permissions.deny // []) as $dn | (.enabledMcpjsonServers // []) as $ms0
  | if ([$al0, $dn, $ms0] | map(type == "array") | all) then . else error("permissions.allow, permissions.deny and enabledMcpjsonServers must be arrays") end
  | (reduce $allow[] as $e ({al: $al0, log: []};
      if any($dn[]; . == $e) then .log += ["deny-wins " + $e]
      elif any(.al[]; . == $e) then .
      else .al += [$e] | .log += ["allow-added " + $e] end)) as $A
  | (reduce $mcp[] as $n ({ms: $ms0, log: []};
      if any(.ms[]; . == $n) then . else .ms += [$n] | .log += ["mcp-added " + $n] end)) as $M
  | [$al0[] | . as $x | select(any($dn[]; . == $x)) | "in-both \(.) — left for the owner"] as $both
  | (($A.al | length) != ($al0 | length)) as $addA | (($M.ms | length) != ($ms0 | length)) as $addM
  | (if $addA then .permissions.allow = $A.al else . end)
  | (if $addM then .enabledMcpjsonServers = $M.ms else . end)
  | {out: ., log: ($A.log + $both + $M.log), delta: ($addA or $addM)}'

# Compute the merge in staging (before the first write of the run); plan its lines and its write last.
plan_settings() {
  _sd=$TARGET/$SETTINGS
  if [ -e "$_sd" ] || [ -L "$_sd" ]; then
    [ -f "$_sd" ] || stop "$SETTINGS exists but is not a regular file — nothing written"
    _sin=$_sd; _created=0
  else
    printf '%s\n' "$SETTINGS_BASELINE" > "$ST/settings.base" || stop "cannot stage $SETTINGS"
    _sin=$ST/settings.base; _created=1
  fi
  : > "$ST/allow.txt"; : > "$ST/mcp.txt"
  if [ -n "$PREC" ]; then rec_field2 "$PREC" ALLOW > "$ST/allow.txt"; rec_field2 "$PREC" MCP > "$ST/mcp.txt"; fi
  jq -R . < "$ST/allow.txt" > "$ST/allow.json" && jq -R . < "$ST/mcp.txt" > "$ST/mcp.json" ||
    stop "jq failed reading the Profile's settings delta"
  if ! jq -n --slurpfile allow "$ST/allow.json" --slurpfile mcp "$ST/mcp.json" "$SETTINGS_JQ" < "$_sin" > "$ST/settings.res" 2> "$ST/settings.err"; then
    stop "$SETTINGS cannot be merged — $(head -n 1 "$ST/settings.err") — nothing written"
  fi
  { [ "$_created" = 0 ] || printf 'SETTINGS created-from-baseline\n'
    jq -r '.log[] | "SETTINGS " + .' < "$ST/settings.res"; } > "$ST/settings.log" || stop "jq failed reading the settings merge"
  _delta=$(jq -r '.delta' < "$ST/settings.res") || stop "jq failed reading the settings merge"
  printf 'L\tsettings.log\t\n' >> "$ST/plan"
  if [ "$_created" = 1 ] || [ "$_delta" = true ]; then
    mkdir -p "$ST/final/.claude" && jq '.out' < "$ST/settings.res" > "$ST/final/$SETTINGS" || stop "cannot stage $SETTINGS"
    printf 'W\t%s\t\n' "$SETTINGS" >> "$ST/plan"
  else
    printf 'U\t%s\t\n' "$SETTINGS" >> "$ST/plan" # no semantic delta: never rewritten for formatting alone
  fi
}

# ---- host-setup: the machine-wide pieces, outside any target (so stamp and verify stay sandboxable) --
hrel() { case $1 in "$HOME"/*) printf '~/%s' "${1#"$HOME"/}" ;; *) printf '%s' "$1" ;; esac; }
host_write() { # <staged> <absolute dest> [exec] — atomic, in the destination's own directory
  _hd=$1; _hp=$2
  mkdir -p "$(dirname "$_hp")" 2>/dev/null || write_failed "$(hrel "$_hp")"
  _tmp=$_hp.tmp.$$; INFLIGHT=$_tmp
  if cp "$_hd" "$_tmp" 2>/dev/null && { [ -z "${3:-}" ] || chmod +x "$_tmp"; } && mv -f "$_tmp" "$_hp" 2>/dev/null; then INFLIGHT=; return 0; fi
  rm -f "$_tmp"; INFLIGHT=; write_failed "$(hrel "$_hp")"
}
cmd_host_setup() {
  [ -n "$ANSWERS" ] || usage_stop "host-setup needs --answers"
  [ -f "$ANSWERS" ] || stop "answers file $ANSWERS not found"
  mk_tmpdir; ST=$MKD
  mkdir -p "$ST/fills" || stop "cannot create staging"
  load_inputs

  # the git global excludes file: git's own setting, else git's default path
  command -v git >/dev/null 2>&1 || stop "git not found — host-setup reads the global excludes file from git config"
  _x=$(git config --global core.excludesFile 2>/dev/null); _rc=$?
  case $_rc in 0) ;; 1) _x= ;; *) stop "git config --global failed (exit $_rc) — fix the global git config, then re-run" ;; esac
  case $_x in '') _x=${XDG_CONFIG_HOME:-$HOME/.config}/git/ignore ;; "~/"*) _x=$HOME/${_x#"~/"} ;; esac
  case $_x in /*) ;; *) stop "core.excludesFile $_x is not an absolute path — host-setup does not guess what it is relative to" ;; esac
  _i=0 # a symlinked excludes file (a dotfiles checkout) is written at its target, never replaced
  while [ -L "$_x" ]; do
    _i=$((_i + 1)); [ "$_i" -le 8 ] || stop "$(hrel "$_x"): more than eight symlink hops"
    _l=$(readlink "$_x") || stop "cannot read the symlink $(hrel "$_x")"
    case $_l in /*) _x=$_l ;; *) _x=$(dirname "$_x")/$_l ;; esac
  done
  if [ -d "$(dirname "$_x")" ]; then _x=$(cd "$(dirname "$_x")" && pwd)/$(basename "$_x") || stop "cannot enter the directory of $(hrel "$_x")"; fi
  [ -d "$_x" ] && stop "$(hrel "$_x") exists as a directory — nothing written"
  : > "$ST/hs.plan"; : > "$ST/ign.add"
  for _line in '**/.codex/config.toml' '**/.claude/settings.local.json'; do
    if [ -f "$_x" ] && grep -qxF -e "$_line" "$_x"; then
      printf 'HOST-SETUP present %s in %s — undo: none needed\n' "$_line" "$(hrel "$_x")" >> "$ST/hs.plan"
    else
      printf '%s\n' "$_line" >> "$ST/ign.add"
      printf "HOST-SETUP added %s to %s — undo: grep -vxF '%s' %s > %s.tmp && mv %s.tmp %s\\n" "$_line" "$(hrel "$_x")" \
        "$_line" "$(hrel "$_x")" "$(hrel "$_x")" "$(hrel "$_x")" "$(hrel "$_x")" >> "$ST/hs.plan"
    fi
  done
  if [ -s "$ST/ign.add" ]; then
    if [ -f "$_x" ]; then
      cp "$_x" "$ST/ign.new" || stop "cannot read $(hrel "$_x")"
      [ ! -s "$_x" ] || [ "$(tail -c 1 "$_x" | wc -l | tr -d ' ')" = 1 ] || printf '\n' >> "$ST/ign.new"
    else : > "$ST/ign.new"; fi
    cat "$ST/ign.add" >> "$ST/ign.new" || stop "cannot stage the excludes file"
  fi

  # the Profile's ~/ template entries: written when absent, never overwritten
  : > "$ST/tpl.w"
  if [ -n "$PREC" ]; then
    awk -F "$TAB" '$1 == "TPL" { print $2 "\t" $3 }' "$PREC" > "$ST/tpl.list" || stop "awk failed reading the Profile records"
    while IFS="$TAB" read -r _src _dest; do
      case $_dest in "~/"*) ;; *) continue ;; esac
      case $_dest in *'/../'*|*/..) stop "Profile template dest $_dest leaves the home directory" ;; esac
      _s=$PROFILE_DIR/$TYPE/templates/$_src; _p=$HOME/${_dest#"~/"}
      [ -f "$_s" ] || stop "Profile $TYPE template $_src not found"
      if [ -d "$_p" ]; then stop "$_dest exists as a directory — nothing written"
      elif [ -e "$_p" ] || [ -L "$_p" ]; then
        if [ -f "$_p" ] && cmp -s "$_s" "$_p"; then printf 'HOST-SETUP present %s — undo: none needed\n' "$_dest" >> "$ST/hs.plan"
        else printf 'HOST-SETUP differs %s — left, not overwritten — undo: none needed\n' "$_dest" >> "$ST/hs.plan"; fi
      else
        _ex=; { [ -x "$_s" ] || [ "$(basename "$(dirname "$_p")")" = bin ]; } && _ex=1
        printf '%s\t%s\t%s\n' "$_s" "$_p" "$_ex" >> "$ST/tpl.w"
        printf 'HOST-SETUP wrote %s — undo: rm %s\n' "$_dest" "$_dest" >> "$ST/hs.plan"
      fi
    done < "$ST/tpl.list"
  fi

  # every check passed: write, then report
  [ ! -s "$ST/ign.add" ] || host_write "$ST/ign.new" "$_x"
  while IFS="$TAB" read -r _s _p _ex; do host_write "$_s" "$_p" "$_ex"; done < "$ST/tpl.w"
  cat "$ST/hs.plan"
  result clean 0
}

render_engine() {
  # imports — validated before the redirect below, so a stop reaches stdout
  if [ -n "$PREC" ]; then
    for _i in $(rec_field2 "$PREC" IMP); do
      case $_i in *[!A-Za-z0-9_-]*) stop "Profile import $_i is not a chunk name" ;; esac
    done
  fi
  { printf '@~/.claude/chunks/dev-base.md\n'
    if [ -n "$PREC" ]; then
      for _i in $(rec_field2 "$PREC" IMP); do
        [ "$_i" = tracker-github ] || printf '@~/.claude/chunks/%s.md\n' "$_i"
      done
    fi
    [ "$TRACKER" = github ] && printf '@~/.claude/chunks/tracker-github.md\n'
    [ "$HELD_IMPORT" = 1 ] && printf '@~/.claude/chunks/backlog-core.md\n'
    printf '@docs/agents/project-workflow.md\n'; } > "$ST/imports.md"
  render_knobs

  # fragments
  FRAG_CONTRACT=; FRAG_CLAUDE=; FRAG_CODEX=; FRAG_GATE=; TRACKER_FRAG=
  if [ -n "$PREC" ]; then
    while IFS="$TAB" read -r _k _role _file; do
      [ "$_k" = ADP ] || continue
      _src=$PROFILE_DIR/$TYPE/templates/$_file
      [ -f "$_src" ] || stop "Profile $TYPE adapter $_role: $_src not found"
      case $_role in
        contract) _dst=$CONTRACT; FRAG_CONTRACT=$ST/frag/contract ;;
        claude) _dst=CLAUDE.md; FRAG_CLAUDE=$ST/frag/claude ;;
        codex) _dst=AGENTS.md; FRAG_CODEX=$ST/frag/codex ;;
        gate_runner) _dst=$GATE_RUNNER; FRAG_GATE=$ST/frag/gate_runner ;;
        *) stop "Profile $TYPE adapter role $_role is not one of contract, claude, codex, gate_runner" ;;
      esac
      tok_pass "$_src" "$ST/frag/$_role" "$_dst"
    done < "$PREC"
  fi
  if [ "$TRACKER" = github ]; then TRACKER_FRAG=$ST/frag/tracker; tok_pass "$TRACKER_CONTRACT" "$TRACKER_FRAG" "$CONTRACT"; fi
  : > "$ST/readlist.md"

  # contract, CLAUDE.md, then the read list from the rendered CLAUDE.md, AGENTS.md, gate-runner
  for _spec in "contract:project-workflow.md:$CONTRACT" "claude:CLAUDE.md:CLAUDE.md" "agents:AGENTS.md:AGENTS.md" "gate:gate-runner.md:$GATE_RUNNER"; do
    _kind=${_spec%%:*}; _rest=${_spec#*:}; _tpl=${_rest%%:*}; _dest=${_rest#*:}
    [ "$_kind" = agents ] && build_readlist
    tok_pass "$TEMPLATE_DIR/$_tpl" "$ST/t/$_kind.1" "$_dest"
    struct_pass "$_kind" "$ST/t/$_kind.1" "$ST/t/$_kind.2" "$_dest"
    mkdir -p "$(dirname "$ST/render/$_dest")"
    fill_pass "$ST/t/$_kind.2" "$ST/render/$_dest" "$_dest"
    _z=$(zone_check "$ST/render/$_dest") || stop "staged render of $_dest: $_z"; [ -z "$_z" ] || stop "staged render of $_dest: $_z"
    if [ -f "$TARGET/$_dest" ]; then refresh_file "$_kind" "$_dest"
    elif [ "$SUB" = check ]; then
      note "$_dest is not in the target"
      zone_names "$ST/render/$_dest" | while IFS= read -r _zn; do printf 'ZONE %s %s absent\n' "$_dest" "$_zn"; done >> "$ST/log"
    fi
    if [ "$SUB" = check ] && [ "$_kind" = contract ]; then check_knobs; cat "$ST/knobs.chk" >> "$ST/log"; fi
    if [ "$_kind" = contract ] && [ "$RERUN" = 1 ] && [ "$SUB" = stamp ]; then
      rewrite_knobs "$ST/final/$_dest" "$ST/final/$_dest.k"
      mv -f "$ST/final/$_dest.k" "$ST/final/$_dest" || stop "cannot stage $_dest"
    fi
    printf 'W\t%s\t\n' "$_dest" >> "$ST/plan"
  done
}

build_readlist() { # from the CLAUDE.md this run leaves on disk: the refreshed target's, else the render
  _cl=$ST/render/CLAUDE.md; [ -f "$ST/final/CLAUDE.md" ] && _cl=$ST/final/CLAUDE.md
  chunk_names "$HOME/.claude/chunks/dev-base.md" > "$ST/names.1" || stop "awk failed reading ~/.claude/chunks/dev-base.md"
  chunk_names "$_cl" >> "$ST/names.1" || stop "awk failed reading CLAUDE.md"
  # a held backlog-core stays on the list only where the target's list already carried it
  HELD=$([ "$TRACKER" = held ] && printf 1) HELD_READ=$HELD_READ awk '
    $0 == "dev-base.md" || seen[$0]++ { next }
    ENVIRON["HELD"] == "1" && $0 == "backlog-core.md" { if (ENVIRON["HELD_READ"] == "1") had = 1; else next }
    { print }
    END { if (ENVIRON["HELD"] == "1" && ENVIRON["HELD_READ"] == "1" && !had) print "backlog-core.md" }' "$ST/names.1" > "$ST/readnames" ||
    stop "awk failed deriving the Codex read list"
  _n=$(wc -l < "$ST/readnames" | tr -d ' ')
  _w=$(count_word "$_n")
  [ -n "$_w" ] || stop "the Codex read list has $_n files; this engine spells one to twenty"
  { printf '3. These %s files under `~/.codex/chunks/` (the dev-process rules, shared with the other host):\n' "$_w"
    awk 'BEGIN { ORS = "" } { printf "%s`%s`", (NR > 1 ? ", " : "   "), $0 } END { print ".\n" }' "$ST/readnames"; } > "$ST/readlist.md"
}

plan_templates() {
  [ -n "$PREC" ] || return 0
  awk -F "$TAB" '$1 == "TPL" { print $2 "\t" $3 "\t" $4 }' "$PREC" > "$ST/tpl.list"
  while IFS="$TAB" read -r _src _dest _af; do
    case $_dest in "~/"*) printf 'S\t%s\thost-setup writes it\n' "$_dest" >> "$ST/plan"; continue ;; esac
    check_dest "$_dest"
    if [ "$AFTER_FREEZE" = 1 ]; then [ "$_af" = 1 ] || continue
    elif [ "$_af" = 1 ]; then printf 'S\t%s\tafter_freeze\n' "$_dest" >> "$ST/plan"; continue; fi
    if [ -e "$TARGET/$_dest" ] && [ ! -d "$TARGET/$_dest" ]; then plan_existing "$_dest" "$PROFILE_DIR/$TYPE/templates/$_src"; continue; fi
    [ -f "$PROFILE_DIR/$TYPE/templates/$_src" ] || stop "Profile $TYPE template $_src not found"
    render_plain "$PROFILE_DIR/$TYPE/templates/$_src" "$_dest"
  done < "$ST/tpl.list"
}

plan_pointers() {
  for _p in $TRACKER_POINTERS; do
    _src=${_p%%=*}; _dest=${_p#*=}
    if [ -e "$TARGET/$_dest" ] && [ ! -d "$TARGET/$_dest" ]; then plan_existing "$_dest" "$TRACKER_ASSETS/$_src"; continue; fi
    [ -f "$TRACKER_ASSETS/$_src" ] || stop "tracker github: $TRACKER_ASSETS/$_src not found"
    render_plain "$TRACKER_ASSETS/$_src" "$_dest"
  done
}

# A skip-if-exists file already in the target: skipped, unless a fill applies to a prompt it still
# carries (O2), which is then written with only that span replaced.
plan_existing() { # <dest> <source Template>
  printf '%s\n' "$1" >> "$ST/present"; printf '%s\t%s\n' "$1" "$2" >> "$ST/present.src"
  [ -f "$TARGET/$1" ] && mkdir -p "$(dirname "$ST/final/$1")" && cp "$TARGET/$1" "$ST/final/$1" 2>/dev/null &&
    fill_outside "$ST/final/$1" "$1" && { printf 'W\t%s\t%s\n' "$1" "$TARGET/$1" >> "$ST/plan"; return 0; }
  rm -f "$ST/final/$1"; printf 'S\t%s\texists\n' "$1" >> "$ST/plan"
}

has_heading() { # <file> <heading> [tokens] → 0 when a heading outside fenced code reads <heading> (#s and edge spaces dropped)
  [ -f "$1" ] || return 1 # with [tokens], each known {{NAME}} in a heading is substituted first (a source Template)
  HD=$2 TOKF=${3:-} awk "$FENCEFN"'
    BEGIN { f = ENVIRON["TOKF"]; if (f != "") { while ((getline l < f) > 0) { i = index(l, "\t"); tv[substr(l, 1, i - 1)] = substr(l, i + 1) } close(f) }; f = 0 }
    function subst(s,   out, i, r, j) {
      out = ""
      while ((i = index(s, "{{")) > 0) {
        out = out substr(s, 1, i - 1); r = substr(s, i + 2); j = index(r, "}}")
        if (j > 0 && (substr(r, 1, j - 1) in tv)) { out = out tv[substr(r, 1, j - 1)]; s = substr(r, j + 2) } else { out = out "{{"; s = r }
      }
      return out s
    }
    fence_line($0) || fch != "" { next }
    /^#+[ \t]/ { h = $0; sub(/^#+[ \t]+/, "", h); sub(/[ \t]+$/, "", h); h = subst(h); if (h == ENVIRON["HD"]) { f = 1; exit } }
    END { exit !f }' "$1"; _hh=$?
  [ "$_hh" -le 1 ] || stop "awk failed reading $1"
  return "$_hh"
}
check_fills() { # every fill key fills a prompt, or names a file this run does not write or finds already filled
  awk -F "$TAB" '$1 == "W" { print $2 }' "$ST/plan" > "$ST/written"
  # a key counts as used where its text lands: anywhere in a file written fresh; in a file already in
  # the target, only by the outside pass or inside a zone the target tags
  P=$ST/present TZ=$ST/tzones awk -F "$TAB" '
    FILENAME == ENVIRON["P"] { p[$0] = 1; next }
    FILENAME == ENVIRON["TZ"] { tz[$1 "\t" $2] = 1; next }
    { d = $1; sub(/#.*/, "", d); if (!(d in p) || $2 == "-outside" || ($2 != "" && ((d "\t" $2) in tz))) print $1 }' \
    "$ST/present" "$ST/tzones" "$ST/fills.used" > "$ST/fills.ok" || stop "awk failed reading the fill records"
  { printf '%s\n' "$CONTRACT" CLAUDE.md AGENTS.md "$GATE_RUNNER"
    [ -z "$PREC" ] || awk -F "$TAB" '$1 == "TPL" { print $3 }' "$PREC"
    [ "$TRACKER" != github ] || for _p in $TRACKER_POINTERS; do printf '%s\n' "${_p#*=}"; done; } > "$ST/known"
  while IFS="$TAB" read -r _n _key; do
    grep -qxF -e "$_key" "$ST/fills.ok" && continue
    _d=${_key%%#*}
    if grep -qxF -e "$_d" "$ST/present"; then # already answered, or a key that could never match
      # the heading is looked up in the target file, its render, and the source Template of a
      # Profile template or pointer (no render is made for one), so a heading renamed since is a NOTE
      _h=${_key#*#}
      _src=$(D=$_d awk -F "$TAB" '$1 == ENVIRON["D"] { print $2; exit }' "$ST/present.src") || stop "awk failed reading the fill records"
      if cut -f 1 "$ST/fills.used" | grep -qxF -e "$_key" || has_heading "$ST/render/$_d" "$_h" || has_heading "$TARGET/$_d" "$_h" ||
         { [ -n "$_src" ] && has_heading "$_src" "$_h" "$ST/tokens"; }; then
        note "fill:$_key not used — no fill prompt under that heading survives in $_d"; continue
      fi
      stop "fill:$_key matches no heading in $_d, so no fill prompt there can take it"
    fi
    if ! grep -qxF -e "$_d" "$ST/written" && grep -qxF -e "$_d" "$ST/known"; then
      note "fill:$_key not used — this run does not write $_d"; continue
    fi
    stop "fill:$_key matches no fill prompt in a file this stamp writes"
  done < "$ST/fills.idx"
}

# ---- check: drift in what the engine wrote, never in the owner's text or values ---------------------
# Knob blocks by key set and shape (scalar | list), after stamp's key normalisation and knob-changes.
check_knobs() { # → ZONE and NOTE lines on stdout
  [ -f "$KNOB_CHANGES" ] || stop "the knob-changes file $KNOB_CHANGES is not found"
  _ct=$TARGET/$CONTRACT; [ -f "$_ct" ] || _ct=/dev/null
  : > "$ST/err"
  DEST=$CONTRACT TYPE=$TYPE TRACKER=$TRACKER PREC=$PREC GREC=$GREC AREC=$ST/answers.rec KCH=$KNOB_CHANGES ERRF=$ST/err awk "$FENCEFN"'
    function rest(l, n,   k) { for (k = 0; k < n; k++) l = substr(l, index(l, "\t") + 1); return l }
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function normk(s) { gsub(/[-_ ]/, "_", s); return s }
    function fail(m) { if (!failed) print m > ENVIRON["ERRF"]; failed = 1 }
    function z(id, st) { printf "ZONE %s knobs:%s %s\n", dest, id, st }
    function load(p, tr,   l, f, id) {
      if (p == "") return
      while ((getline l < p) > 0) {
        split(l, f, "\t"); id = f[2]
        if (f[1] == "KB" && !tr) { pn++; pid[pn] = id; plisted[id] = 1; continue }
        if ((id == "tracker-github") != tr) continue
        if (f[1] == "K") { kc[id]++; key[id, kc[id]] = f[3]; shp[id, f[3]] = f[4] }
      }
      close(p)
    }
    function add(id) { if (id in inset) return; nw++; want[nw] = id; inset[id] = 1 }
    BEGIN {
      dest = ENVIRON["DEST"]; type = ENVIRON["TYPE"]; tracker = ENVIRON["TRACKER"]
      load(ENVIRON["PREC"], 0)
      if (tracker == "github") load(ENVIRON["GREC"], 1)
      a = ENVIRON["AREC"]
      while ((getline l < a) > 0) {
        split(l, f, "\t")
        if (f[1] == "KA") { an++; aid[an] = f[2]; cur = ""; continue }
        if (f[1] != "KL") continue
        id = f[2]; line = rest(l, 2)
        if (line ~ /^- [^:]+:( |$)/) { k = substr(line, 3, index(line, ":") - 3); ank[id]++; akey[id, ank[id]] = k; ashp[id, k] = (trim(substr(line, index(line, ":") + 1)) == "") ? "L" : "S" }
      }
      close(a)
      c = ENVIRON["KCH"]; cn = 0
      while ((getline l < c) > 0) {
        cn++; t = trim(l)
        if (t == "" || substr(t, 1, 1) == "#") continue
        m = split(t, w, /[ \t]+/)
        if (w[1] == "rename" && m == 4) { ren[w[2], normk(w[3])] = w[4]; continue }
        if (w[1] == "retire" && m == 3) { ret[w[2], normk(w[3])] = 1; continue }
        if (w[1] == "retire-block" && m == 2) { retblk[w[2]] = 1; continue }
        fail("knob-changes line " cn ": expected \"rename <chunk-id> <old-key> <new-key>\", \"retire <chunk-id> <key>\" or \"retire-block <chunk-id>\""); exit
      }
      close(c)
      if (tracker == "github" && (type == "none" || !("tracker-github" in plisted))) add("tracker-github")
      if (type != "none") { for (i = 1; i <= pn; i++) { id = pid[i]; if (id == "tracker-github" && tracker != "github") continue; add(id) } }
      else for (i = 1; i <= an; i++) if (aid[i] != "tracker-github") add(aid[i])
      for (x = 1; x <= nw; x++) if (want[x] in retblk) { fail("knob-changes retires knobs:" want[x] " (retire-block), which " (type == "none" ? "the answers file" : "the Profile") " still lists — resolve it by hand (nothing written)"); exit }
    }
    { L[++n] = $0 }
    END {
      if (failed) exit
      for (i = 1; i <= n; i++) {
        if (fence_line(L[i]) || fch != "") continue
        if (L[i] ~ /^<!-- knobs:[A-Za-z0-9_-]+ -->$/) {
          id = substr(L[i], 12, length(L[i]) - 15)
          if (cid != "" || (id in bs)) { fail(dest ": knobs:" id " is opened inside another block or twice — fix the tags by hand"); exit }
          bs[id] = i; cid = id; nb++; bo[nb] = id; continue
        }
        if (L[i] ~ /^<!-- \/knobs:[A-Za-z0-9_-]+ -->$/) {
          id = substr(L[i], 13, length(L[i]) - 16)
          if (id != cid) { fail(dest ": knobs:" id " closes without its open tag — fix the tags by hand"); exit }
          be[id] = i; cid = ""
        }
      }
      if (cid != "") { fail(dest ": knobs:" cid " is not closed — fix the tags by hand"); exit }
      for (b = 1; b <= nb; b++) {
        id = bo[b]
        if (id == "backlog-core" && tracker == "held") { z(id, "held"); continue }
        if (!(id in inset)) {
          if (id in retblk) { z(id, "differs"); print "NOTE knobs:" id ": retired by knob-changes (retire-block), still present; a stamp re-run deletes it" }
          else { z(id, "orphan"); print "NOTE knobs:" id ": not a block this stamp lists — kept, not drift" }
          continue
        }
        ne = 0; bad = 0
        for (i = bs[id] + 1; i < be[id]; i++) {
          if (L[i] ~ /^- [^:]+:( |$)/) { ne++; ek[b, ne] = trim(substr(L[i], 3, index(L[i], ":") - 3)); es[b, ne] = (trim(substr(L[i], index(L[i], ":") + 1)) == "") ? "L" : "S"; continue }
          if (ne && L[i] ~ /^[ \t]+[^ \t]/) continue
          bad = 1; break
        }
        if (bad) { z(id, "unparsed"); print "NOTE knobs:" id ": contract line " i " is neither \"- <key>: <value>\" nor an indented continuation"; continue }
        fromans = (type == "none" && id != "tracker-github"); pc = fromans ? ank[id] : kc[id]
        split("", pmap); split("", took); dif = 0
        for (j = 1; j <= pc; j++) { p = fromans ? akey[id, j] : key[id, j]; pmap[normk(p)] = p; psh[p] = fromans ? ashp[id, p] : shp[id, p] }
        for (j = 1; j <= ne; j++) {
          nk = normk(ek[b, j]); p = ""
          if (nk in pmap) p = pmap[nk]
          else if ((id, nk) in ren && (normk(ren[id, nk]) in pmap)) { p = pmap[normk(ren[id, nk])]; print "NOTE knobs:" id " " ek[b, j] ": knob-changes renames it " p "; a stamp re-run rewrites the key" }
          else if ((id, nk) in ret) { dif = 1; print "NOTE knobs:" id " " ek[b, j] ": retired by knob-changes, still present"; continue }
          else { print "NOTE knobs:" id " " ek[b, j] ": the project'"'"'s own key, not drift"; continue }
          if (p in took) { dif = 1; print "NOTE knobs:" id " " p ": carried twice"; continue }
          took[p] = 1
          if (es[b, j] != psh[p]) { dif = 1; print "NOTE knobs:" id " " p ": " (es[b, j] == "L" ? "a list" : "a scalar") " in the contract, " (psh[p] == "L" ? "a list" : "a scalar") " in the Profile" }
        }
        for (j = 1; j <= pc; j++) { p = fromans ? akey[id, j] : key[id, j]; if (!(p in took)) { dif = 1; print "NOTE knobs:" id " " p ": missing" } }
        z(id, dif ? "differs" : "same")
      }
      for (x = 1; x <= nw; x++) if (!(want[x] in bs)) z(want[x], "absent")
    }' "$_ct" > "$ST/knobs.chk" || stop "awk failed comparing the knob blocks of $CONTRACT"
  [ -s "$ST/err" ] && stop "$(head -n 1 "$ST/err")"
  return 0
}

cmd_check() {
  target_setup
  chunk_roots
  mk_tmpdir; ST=$MKD
  mkdir -p "$ST/fills" "$ST/frag" "$ST/t" "$ST/render" "$ST/final" || stop "cannot create staging"
  : > "$ST/plan"; : > "$ST/fills.used"
  load_inputs
  prep_target
  render_engine
  sed 's/^\(ZONE .*\) refreshed$/\1 differs/' "$ST/log" > "$ST/check.out" || stop "cannot read the comparison"
  cat "$ST/check.out"
  if grep -Eq '^ZONE .* (differs|unparsed)$' "$ST/check.out"; then result failed 1; fi
  result clean 0
}

# ---- verify: residue checks behind their controls, byte gates, imports, the resolved-load report ------
# One "<file>:<line>" per hit, over the files named (relative to the cwd). The controls run this same
# function over a known-bad, so a detector that cannot see its own residue fails its check.
detect() { # <check> <file>...
  DC=$1; shift
  DC=$DC awk "$FENCEFN$CODESPANFN"'
    function flush() { if (pend != "") print pend; pend = "" }
    BEGIN { m = ENVIRON["DC"] }
    m == "braces" { if (index($0, "{{")) print FILENAME ":" FNR; next }
    m == "marker" { if (index($0, "<!-- profile:")) print FILENAME ":" FNR; next }
    m == "fill-prompt" { if (FNR == 1) fch = "" # a prompt in fenced code or a closed inline code span is prose, as the outside fill pass reads it
                         if (fence_line($0) || fch != "") next
                         s = tolower(uncode($0)); if (FILENAME == "CLAUDE.md") gsub(/filled at init/, "", s) # fork-slot owns that one
                         if (s ~ /fill(ed)? at init/) print FILENAME ":" FNR; next }
    m == "fork-slot" { if (tolower($0) ~ /filled at init/) print FILENAME ":" FNR; next }
    m != "empty-heading" { exit 2 }
    FNR == 1 { flush(); fch = ""; com = 0; fm = ($0 == "---"); if (fm) next }
    fm { if ($0 == "---") fm = 0; next }
    { t = $0; sub(/^[ \t]+/, "", t); sub(/[ \t]+$/, "", t) }
    com { if (index(t, "-->")) com = 0; next }
    fence_line($0) || fch != "" { pend = ""; next }
    t == "" { next }
    substr(t, 1, 4) == "<!--" { if (!index(t, "-->")) com = 1; else if (t !~ /-->$/) pend = ""; next }
    /^#+[ \t]/ { match($0, /[^#]/); lv = RSTART - 1; if (pend != "" && lv <= plv) print pend; pend = FILENAME ":" FNR; plv = lv; next }
    { pend = "" }
    END { flush() }' "$@"
}
# The known-bads: residue as a stamp leaves it, each line one the detector must match, and no more.
known_bad() { # <check> → the file on stdout; KB_WANT = how many hits it must give
  case $1 in
    braces) KB_WANT=1; printf '%s\n' '# Demo' 'Residue: {{PROJECT_NAME}} was never substituted.' ;;
    marker) KB_WANT=1; printf '%s\n' '# Demo' '<!-- profile:contract-sections -->' ;;
    fill-prompt) KB_WANT=2; printf '%s\n' '## Project' '*<Fill at init: what this project is.>*' '- The fork is *<`/name`, filled at init>*.' \
      '```md' '*<Fill at init: a fenced example, prose.>*' '```' 'Quoted: `*<Fill at init: an inline example, prose.>*`.' ;; # the last two must not count
    fork-slot) KB_WANT=1; printf '%s\n' '# Demo' 'Its fork is *<`/name`, filled at init>*.' ;;
    empty-heading) KB_WANT=2; printf '%s\n' '# Demo' 'Text.' '## Left empty' '<!-- zone:x -->' '<!-- /zone:x -->' \
      '## Has only a subheading' '### Sub' 'Sub text.' '<!-- a comment' '     over two lines -->' '## Empty at the end' '' ;;
  esac
}
residue_check() { # <check> <file list> ; FAILED=1 on a fail
  known_bad "$1" > "$ST/kb/$1.md"
  (cd "$ST/kb" && detect "$1" "$1.md") > "$ST/kb/$1.hits" || { printf 'CHECK %s: NOT RUN — the detector failed on its known-bad\n' "$1"; FAILED=1; return; }
  _kn=$(wc -l < "$ST/kb/$1.hits" | tr -d ' ')
  if [ -s "$2" ]; then
    set -f; _ifs=$IFS; IFS=$NL
    (cd "$TARGET" && detect "$1" $(cat "$2")) > "$ST/hits" 2>/dev/null || { IFS=$_ifs; set +f; printf 'CHECK %s: NOT RUN — the detector failed on the target\n' "$1"; FAILED=1; return; }
    IFS=$_ifs; set +f
  else : > "$ST/hits"; fi
  _tn=$(wc -l < "$ST/hits" | tr -d ' ')
  printf 'CONTROL %s: known-bad matched %s — target matched %s\n' "$1" "$_kn" "$_tn"
  if [ "$_kn" != "$KB_WANT" ]; then
    printf 'CHECK %s: FAIL — the control matched %s of its %s known-bad lines, so a clean target proves nothing\n' "$1" "$_kn" "$KB_WANT"; FAILED=1
  elif [ ! -s "$2" ]; then printf 'CHECK %s: NOT RUN — no file to scan\n' "$1"; FAILED=1
  elif [ "$_tn" = 0 ]; then printf 'CHECK %s: PASS — no match in %s file(s)\n' "$1" "$(wc -l < "$2" | tr -d ' ')"
  else # fill-prompt names every hit: it is the list of what is left to answer
    printf 'CHECK %s: FAIL — %s match(es): %s\n' "$1" "$_tn" "$(if [ "$1" = fill-prompt ]; then cat "$ST/hits"; else head -n 3 "$ST/hits"; fi | tr '\n' ' ' | sed 's/ $//; s/ /, /g')"; FAILED=1; fi
}
vdisp() { # an absolute path → target-relative, ~/-relative under $HOME, else as is
  case $1 in "$TARGET"/*) printf '%s' "${1#"$TARGET"/}" ;; *) hrel "$1" ;; esac
}
phys() { # the physical path of a file (symlinks followed), for "each physical file once"
  _p=$1; _i=0
  while [ -L "$_p" ] && [ "$_i" -lt 8 ]; do
    _i=$((_i + 1)); _l=$(readlink "$_p") || break
    case $_l in /*) _p=$_l ;; *) _p=$(dirname "$_p")/$_l ;; esac
  done
  printf '%s/%s' "$(cd "$(dirname "$_p")" && pwd -P)" "$(basename "$_p")"
}
load_add() { # <host> <absolute path> <depth> — queued once per physical file
  _pp=$(phys "$2"); grep -qxF -e "$_pp" "$ST/seen.$1" && return 0
  printf '%s\n' "$_pp" >> "$ST/seen.$1"; printf '%s\t%s\n' "$3" "$2" >> "$ST/q.$1"
}
import_lines() { # <file> → each @<path> line's path, outside fences
  awk "$FENCEFN"'fence_line($0) || fch != "" { next }
       /^@[^ \t]+[ \t]*$/ { s = $0; sub(/^@/, "", s); sub(/[ \t]+$/, "", s); print s }' "$1"
}
readlist_names() { # AGENTS.md → the backticked <name>.md of its read list (the zone, else item 3)
  if [ "$(tag_count '^[[:space:]]*<!-- zone:read-list -->[[:space:]]*$' "$1")" != 0 ]; then zone_extract "$1" read-list
  else awk '/^3\. / { f = 1; print; next } f && /^[ \t]+[^ \t]/ { print; next } { f = 0 }' "$1"; fi |
  awk '{ s = $0; while ((i = index(s, "`")) > 0) { r = substr(s, i + 1); j = index(r, "`"); if (!j) break
         n = substr(r, 1, j - 1); if (n ~ /^[A-Za-z0-9_.-]+\.md$/) print n; s = substr(r, j + 1) } }'
}
gate_bytes() { # <absolute path> <cap>
  _gd=$(vdisp "$1")
  if [ ! -f "$1" ]; then printf 'GATE bytes %s: FAIL — absent\n' "$_gd"; FAILED=1; return; fi
  _b=$(wc -c < "$1" | tr -d ' ')
  if [ "$_b" -le "$2" ]; then printf 'GATE bytes %s: PASS — %s <= %s\n' "$_gd" "$_b" "$2"
  else printf 'GATE bytes %s: FAIL — %s > %s\n' "$_gd" "$_b" "$2"; FAILED=1; fi
}

cmd_verify() {
  target_setup
  mk_tmpdir; ST=$MKD
  mkdir -p "$ST/fills" "$ST/kb" || stop "cannot create staging"
  load_inputs
  # the tracker as stamp reads it: the contract's, else (no contract) the answers file's
  if [ -f "$TARGET/$CONTRACT" ]; then
    _tg=$(tag_count '^<!-- knobs:tracker-github -->$' "$TARGET/$CONTRACT") || stop "awk failed reading $CONTRACT"
    if [ "$_tg" = 0 ]; then TRACKER=none; else TRACKER=github; fi
  fi
  # the stamped files present: the four engine files, the tracker pointers, the Profile's in-target templates
  : > "$ST/files"; : > "$ST/engine"
  for _f in "$CONTRACT" CLAUDE.md AGENTS.md "$GATE_RUNNER"; do
    if [ -f "$TARGET/$_f" ]; then printf '%s\n' "$_f" >> "$ST/files"; printf '%s\n' "$_f" >> "$ST/engine"; else note "$_f is not in the target"; fi
  done
  if [ "$TRACKER" = github ]; then
    for _p in $TRACKER_POINTERS; do [ ! -f "$TARGET/${_p#*=}" ] || printf '%s\n' "${_p#*=}" >> "$ST/files"; done
  fi
  if [ -n "$PREC" ]; then
    awk -F "$TAB" '$1 == "TPL" { print $3 }' "$PREC" | while IFS= read -r _d; do
      case $_d in "~/"*) continue ;; esac
      [ ! -f "$TARGET/$_d" ] || grep -qxF -e "$_d" "$ST/files" || printf '%s\n' "$_d" >> "$ST/files"
    done
  fi
  grep -qxF CLAUDE.md "$ST/files" && printf 'CLAUDE.md\n' > "$ST/claude" || : > "$ST/claude"
  FAILED=0
  residue_check braces "$ST/files"
  residue_check marker "$ST/files"
  residue_check fill-prompt "$ST/files"
  residue_check fork-slot "$ST/claude"
  residue_check empty-heading "$ST/engine"

  gate_bytes "$TARGET/CLAUDE.md" 32768
  gate_bytes "$TARGET/AGENTS.md" 32768
  [ ! -f "$HOME/.codex/AGENTS.md" ] || gate_bytes "$HOME/.codex/AGENTS.md" 32768
  gate_bytes "$TARGET/$CONTRACT" 16384

  # Claude: CLAUDE.md and its @ lines, transitively (five hops), each physical file once
  : > "$ST/seen.claude"; : > "$ST/q.claude"; : > "$ST/unres"; : > "$ST/load"; _nimp=0; _tot=0
  [ ! -f "$TARGET/CLAUDE.md" ] || load_add claude "$TARGET/CLAUDE.md" 0
  _i=1
  while _row=$(sed -n "${_i}p" "$ST/q.claude") && [ -n "$_row" ]; do
    _d=${_row%%"$TAB"*}; _f=${_row#*"$TAB"}
    _b=$(wc -c < "$_f" | tr -d ' '); _tot=$((_tot + _b))
    printf 'LOAD claude %s %s\n' "$(vdisp "$_f")" "$_b" >> "$ST/load"
    import_lines "$_f" > "$ST/imp" || stop "awk failed reading $(vdisp "$_f")"
    if [ -s "$ST/imp" ] && [ "$_d" -ge 5 ]; then
      printf 'NOTE %s: its imports are five hops deep and are not followed\n' "$(vdisp "$_f")" >> "$ST/load"
    else
      while IFS= read -r _x; do
        _nimp=$((_nimp + 1))
        case $_x in "~/"*) _r=$HOME/${_x#"~/"} ;; /*) _r=$_x ;; *) _r=$(dirname "$_f")/$_x ;; esac
        if [ -d "$(dirname "$_r")" ]; then _r=$(cd "$(dirname "$_r")" && pwd)/$(basename "$_r"); fi
        if [ -f "$_r" ] && [ -r "$_r" ]; then load_add claude "$_r" $((_d + 1))
        else printf '%s @%s' "$(vdisp "$_f")" "$_x" >> "$ST/unres"; printf '\n' >> "$ST/unres"; fi
      done < "$ST/imp"
    fi
    _i=$((_i + 1))
  done
  printf 'LOAD claude TOTAL %s — reported, not gated\n' "$_tot" >> "$ST/load"
  if [ ! -f "$TARGET/CLAUDE.md" ]; then printf 'GATE imports-resolve: FAIL — CLAUDE.md is absent\n'; FAILED=1
  elif [ -s "$ST/unres" ]; then
    printf 'GATE imports-resolve: FAIL — %s of %s unresolved: %s\n' "$(wc -l < "$ST/unres" | tr -d ' ')" "$_nimp" "$(head -n 3 "$ST/unres" | tr '\n' ';' | sed 's/;$//; s/;/; /g')"; FAILED=1
  else printf 'GATE imports-resolve: PASS — %s import(s) resolve\n' "$_nimp"; fi

  # Codex: AGENTS.md, CONTEXT.md, the contract and the read list's names under ~/.codex/chunks (no expansion)
  : > "$ST/seen.codex"; : > "$ST/q.codex"; _tot=0
  for _f in AGENTS.md CONTEXT.md "$CONTRACT"; do [ ! -f "$TARGET/$_f" ] || load_add codex "$TARGET/$_f" 0; done
  if [ -f "$TARGET/AGENTS.md" ]; then
    readlist_names "$TARGET/AGENTS.md" > "$ST/rl" || stop "awk failed reading the AGENTS.md read list"
    while IFS= read -r _n; do
      if [ -f "$HOME/.codex/chunks/$_n" ]; then load_add codex "$HOME/.codex/chunks/$_n" 1
      else printf 'NOTE the AGENTS.md read list names %s, which is not under ~/.codex/chunks/\n' "$_n" >> "$ST/load"; fi
    done < "$ST/rl"
  fi
  while IFS="$TAB" read -r _d _f; do
    _b=$(wc -c < "$_f" | tr -d ' '); _tot=$((_tot + _b))
    printf 'LOAD codex %s %s\n' "$(vdisp "$_f")" "$_b" >> "$ST/load"
  done < "$ST/q.codex"
  printf 'LOAD codex TOTAL %s — reported, not gated\n' "$_tot" >> "$ST/load"
  cat "$ST/load"
  printf 'VERIFY-GATE: NOT RUN by this script — the seat runs the verify-gate Chunk'"'"'s gates from the contract'"'"'s knob block, as step 7 does\n'
  [ "$FAILED" = 0 ] || result failed 1
  result clean 0
}

# ---- selftest --------------------------------------------------------------------------------------
st_env() { # build a fixture home + target; sets H and T
  mk_tmpdir; H=$MKD; mk_tmpdir; T=$MKD
  mkdir -p "$H/.claude/chunks" "$H/.codex/chunks"
  cp "$FIXTURE_DIR"/chunks/*.md "$H/.claude/chunks/" && cp "$FIXTURE_DIR"/chunks/*.md "$H/.codex/chunks/" ||
    stop "selftest: cannot build the fixture home"
}
# ST_KC / ST_PD override the knob-changes file / Profile directory; ST_LOC sets the child's LC_ALL and
# LANG (else the parent's pinned ones are inherited); ST_NOPIN=1 turns the child's pin off.
st_run() { # <subcommand args...> → OUT, RC
  OUT=$(HOME=$H XDG_CONFIG_HOME=$H/.config GIT_CONFIG_GLOBAL=$H/.gitconfig INIT_PROJECT_PROFILE_DIR=${ST_PD:-$FIXTURE_DIR/profiles} INIT_PROJECT_KNOB_CHANGES=${ST_KC:-$FIXTURE_DIR/knob-changes/none} \
    LC_ALL=${ST_LOC:-${LC_ALL:-}} LANG=${ST_LOC:-${LANG:-}} INIT_PROJECT_NO_LOCALE_PIN=${ST_NOPIN:-${INIT_PROJECT_NO_LOCALE_PIN:-}} \
    "$SELF_SH" "$SELF" "$@" < /dev/null 2>&1)
  RC=$?
}
st_snapshot() { (cd "$1" && find . -print | sort && find . -type f -exec cksum {} \; | sort); }
st_count() { grep -c -e "$2" "$1" 2>/dev/null || true; }

case_template_every_token() {
  st_env
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/every-token.md"
  [ "$RC" = 0 ] || { GOT=exit$RC; return; }
  _root=$(cd "$T" && pwd)
  printf '%s\n' 'name=Démo Ω' "root=$_root" 'custom=custom \\value & more' > "$H/want"
  cmp -s "$H/want" "$T/out/tokens.txt" || { GOT=token-mismatch; return; }
  if grep -rq '{{' "$T"; then GOT=braces-left; return; fi
  grep -qxF '# Démo Ω — the Claude Code adapter' "$T/CLAUDE.md" || { GOT=name-missing; return; }
  grep -qxF -e '- test: ./run-tests --all' "$T/$CONTRACT" || { GOT=knob-answer-missing; return; }
  grep -qxF -e '- dir: repo root' "$T/$CONTRACT" || { GOT=knob-literal-missing; return; }
  grep -qF 'fork is `/git-flow-squash`.' "$T/CLAUDE.md" || { GOT=fork-unfilled; return; }
  GOT=substituted
}

case_fragment_each_marker() {
  st_env
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/four-fragments.md"
  [ "$RC" = 0 ] || { GOT=exit$RC; return; }
  _fd=$FIXTURE_DIR/profiles/four-fragments/templates
  for _z in "contract-sections:$CONTRACT:contract.md" "claude-mechanics:CLAUDE.md:adapter-claude.md" \
            "codex-mechanics:AGENTS.md:adapter-codex.md" "gate-runner-mechanics:$GATE_RUNNER:adapter-gate-runner.md"; do
    _zn=${_z%%:*}; _r=${_z#*:}; _file=${_r%%:*}; _frag=${_r#*:}
    zone_extract "$T/$_file" "$_zn" > "$H/zone"
    cmp -s "$H/zone" "$_fd/$_frag" || { GOT=bad-$_zn; return; }
  done
  for _file in "$CONTRACT" CLAUDE.md AGENTS.md "$GATE_RUNNER"; do
    [ -n "$(zone_check "$T/$_file")" ] && { GOT=unbalanced-$_file; return; }
    [ "$(st_count "$T/$_file" '<!-- zone:')" = "$(st_count "$T/$_file" '<!-- /zone:')" ] || { GOT=count-$_file; return; }
  done
  [ "$(st_count "$T/$CONTRACT" '^## Running$')" = 0 ] || { GOT=stub-kept; return; }
  [ "$(st_count "$T/$CONTRACT" '^## Working in this repo$')" = 1 ] || { GOT=stub-lost; return; }
  grep -qxF 'A fixture project.' "$T/$CONTRACT" || { GOT=fill-missing; return; }
  grep -qF 'These five files under' "$T/AGENTS.md" || { GOT=readlist-count; return; }
  grep -qF '`verify-gate.md`, `extra-chunk.md`.' "$T/AGENTS.md" || { GOT=readlist-names; return; }
  [ "$(tail -n 1 "$T/AGENTS.md")" = '<!-- /zone:canary -->' ] || { GOT=canary; return; }
  GOT=inserted
}

st_stop_case() { # <answers> ; a target prepared by the caller in $T must be left untouched
  _before=$(st_snapshot "$T")
  st_run stamp --target "$T" --answers "$1"
  _after=$(st_snapshot "$T")
  [ "$RC" = 2 ] || { GOT=exit$RC; return; }
  [ "$_before" = "$_after" ] || { GOT=target-changed; return; }
  printf '%s\n' "$OUT" | grep -q "^STOP: $2" || { GOT=wrong-stop; return; }
  GOT=stopped-untouched
}
case_pre_contract_stop() {
  st_env
  printf '%s\n' '# Old' '<!-- knobs:verify-gate -->' '- dir: repo root' '<!-- /knobs:verify-gate -->' > "$T/CLAUDE.md"
  st_stop_case "$FIXTURE_DIR/answers/four-fragments.md" 'pre-contract layout'
}
case_untagged_stop() {
  st_env
  printf '%s\n' '# A hand-written Codex adapter' > "$T/AGENTS.md"
  st_stop_case "$FIXTURE_DIR/answers/four-fragments.md" 'AGENTS.md exists with no zone tag'
}

st_knob() { # <file> <id> → the knob block, tags included
  BID=$2 awk 'BEGIN { o = "<!-- knobs:" ENVIRON["BID"] " -->"; c = "<!-- /knobs:" ENVIRON["BID"] " -->" }
    $0 == o { f = 1 } f { print } $0 == c { f = 0 }' "$1"
}
st_replace_block() { # <file> <id> <replacement file> — the block, open through close tag
  BID=$2 REP=$3 awk 'BEGIN { o = "<!-- knobs:" ENVIRON["BID"] " -->"; c = "<!-- /knobs:" ENVIRON["BID"] " -->" }
    $0 == o { while ((getline l < ENVIRON["REP"]) > 0) print l; skip = 1; next }
    skip { if ($0 == c) skip = 0; next } { print }' "$1" > "$1.new" && mv "$1.new" "$1"
}
st_has() { printf '%s\n' "$OUT" | grep -qxF -e "$1"; }

case_tracker_github_fresh() {
  st_env
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/tracker-github.md"
  [ "$RC" = 0 ] || { GOT=exit$RC; return; }
  printf '%s\n' '<!-- knobs:tracker-github -->' '- REPO: owner/fixture' '- RESULTS_DIR: none' '<!-- /knobs:tracker-github -->' > "$H/want"
  st_knob "$T/$CONTRACT" tracker-github > "$H/got"; cmp -s "$H/want" "$H/got" || { GOT=knob-block; return; }
  [ "$(awk '/^<!-- knobs:/ { print; exit }' "$T/$CONTRACT")" = '<!-- knobs:tracker-github -->' ] || { GOT=knob-not-first; return; }
  printf '%s\n' '## Issue tracker' '' 'FRAG-TRACKER: work for Fixture lives in GitHub issues.' > "$H/want"
  zone_extract "$T/$CONTRACT" issue-tracker > "$H/got"; cmp -s "$H/want" "$H/got" || { GOT=tracker-zone; return; }
  [ "$(tail -n 1 "$T/$CONTRACT")" = '<!-- /zone:issue-tracker -->' ] || { GOT=tracker-zone-not-last; return; }
  zone_extract "$T/CLAUDE.md" imports > "$H/got"
  printf '%s\n' '@~/.claude/chunks/dev-base.md' '@~/.claude/chunks/extra-chunk.md' '@~/.claude/chunks/tracker-github.md' '@docs/agents/project-workflow.md' > "$H/want"
  cmp -s "$H/want" "$H/got" || { GOT=imports; return; }
  grep -qF 'These six files under' "$T/AGENTS.md" && grep -qF '`extra-chunk.md`, `tracker-github.md`.' "$T/AGENTS.md" || { GOT=readlist; return; }
  grep -qxF '# Issue tracker — Fixture' "$T/docs/agents/issue-tracker.md" || { GOT=pointer-issue-tracker; return; }
  grep -qxF 'FIXTURE-POINTER triage labels.' "$T/docs/agents/triage-labels.md" || { GOT=pointer-triage; return; }
  GOT=tracker-stamped
}

case_rerun_idempotent() {
  st_env
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/tracker-github.md"
  [ "$RC" = 0 ] || { GOT=fresh-exit$RC; return; }
  _before=$(st_snapshot "$T")
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/tracker-github.md"
  [ "$RC" = 0 ] || { GOT=exit$RC; return; }
  [ "$_before" = "$(st_snapshot "$T")" ] || { GOT=target-changed; return; }
  printf '%s\n' "$OUT" | grep -q '^WROTE ' && { GOT=wrote; return; }
  [ "$(printf '%s\n' "$OUT" | grep -c '^ZONE ')" = 11 ] || { GOT=zone-count; return; }
  [ "$(printf '%s\n' "$OUT" | grep -c '^ZONE .* same$')" = 11 ] || { GOT=zone-not-same; return; }
  st_has 'KNOB tracker-github kept' && st_has 'KNOB verify-gate kept' || { GOT=knob-not-kept; return; }
  GOT=idempotent
}

case_knob_added_renamed_retired() {
  st_env
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/four-fragments.md"
  [ "$RC" = 0 ] || { GOT=fresh-exit$RC; return; }
  printf '%s\n' '<!-- knobs:verify-gate -->' '- dir: repo root' '- light-set:' '  1. docs/**' '- old_flag: yes' \
    '- custom_gate:' '  1. make lint' '<!-- /knobs:verify-gate -->' '' '<!-- knobs:stale -->' '- a: b' '<!-- /knobs:stale -->' > "$H/blk"
  st_replace_block "$T/$CONTRACT" verify-gate "$H/blk" || { GOT=fixture-edit; return; }
  ST_KC=$FIXTURE_DIR/knob-changes/v2
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/knobs-v2.md"
  [ "$RC" = 0 ] || { GOT=exit$RC; return; }
  _i=0
  for _l in 'KNOB verify-gate respelled light-set -> light_set' 'KNOB verify-gate renamed dir -> root_dir' \
            'KNOB verify-gate retired old_flag (value was: yes)' 'KNOB verify-gate kept custom_gate — not in the Profile' \
            'KNOB verify-gate added test_cmd' 'KNOB stale block-deleted (3 lines)' 'KNOB parallel-work block-inserted'; do
    _i=$((_i + 1)); st_has "$_l" || { GOT=knob-line-$_i; return; }
  done
  printf '%s\n' '<!-- knobs:verify-gate -->' '- root_dir: repo root' '- light_set:' '  1. docs/**' '- test_cmd: make test' \
    '- custom_gate:' '  1. make lint' '<!-- /knobs:verify-gate -->' > "$H/want"
  st_knob "$T/$CONTRACT" verify-gate > "$H/got"; cmp -s "$H/want" "$H/got" || { GOT=verify-gate-block; return; }
  printf '%s\n' '<!-- knobs:parallel-work -->' '- install: none' '<!-- /knobs:parallel-work -->' > "$H/want"
  st_knob "$T/$CONTRACT" parallel-work > "$H/got"; cmp -s "$H/want" "$H/got" || { GOT=inserted-block; return; }
  grep -q '^<!-- knobs:stale -->$' "$T/$CONTRACT" && { GOT=stale-kept; return; }
  _before=$(st_snapshot "$T")
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/knobs-v2.md"
  [ "$RC" = 0 ] && [ "$_before" = "$(st_snapshot "$T")" ] || { GOT=second-run-changed; return; }
  st_has 'KNOB verify-gate kept' || { GOT=second-run-not-kept; return; }
  GOT=rewritten
}

case_held_backlog_core() {
  st_env
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/four-fragments.md"
  [ "$RC" = 0 ] || { GOT=fresh-exit$RC; return; }
  printf '%s\n' '<!-- knobs:verify-gate -->' '- dir: repo root' '- light_set:' '  1. docs/**' '<!-- /knobs:verify-gate -->' '' \
    '<!-- knobs:backlog-core -->' '- board: backlog/' 'Frozen prose a rewrite could not parse.' '<!-- /knobs:backlog-core -->' > "$H/blk"
  st_replace_block "$T/$CONTRACT" verify-gate "$H/blk" || { GOT=fixture-edit; return; }
  awk '$0 == "@docs/agents/project-workflow.md" { print "@~/.claude/chunks/backlog-core.md" } { print }' "$T/CLAUDE.md" > "$H/c" &&
    cp "$H/c" "$T/CLAUDE.md" || { GOT=fixture-edit; return; }
  _before=$(st_snapshot "$T")
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/four-fragments.md"
  [ "$RC" = 0 ] || { GOT=exit$RC; return; }
  [ "$_before" = "$(st_snapshot "$T")" ] || { GOT=target-changed; return; }
  st_has 'held: backlog-core (frozen) — knob block, imports line' || { GOT=held-line; return; }
  st_has "NOTE tracker: the contract says backlog-core; the answers file's none is not used" || { GOT=tracker-note; return; }
  st_has 'ZONE CLAUDE.md imports same' && st_has 'ZONE AGENTS.md read-list same' || { GOT=zones-not-same; return; }
  grep -q 'backlog-core' "$T/AGENTS.md" && { GOT=read-list-added; return; }
  printf '%s\n' "$OUT" | grep -q '^KNOB backlog-core' && { GOT=held-block-rewritten; return; }
  [ -e "$T/docs/agents/issue-tracker.md" ] && { GOT=pointer-written; return; }
  st_check "$FIXTURE_DIR/answers/four-fragments.md" # check side: the frozen block reads held, nothing fails
  [ "$RC" = 0 ] || { GOT=check-exit$RC; return; }
  st_has "ZONE $CONTRACT knobs:backlog-core held" && st_has "ZONE $CONTRACT knobs:verify-gate same" || { GOT=check-not-held; return; }
  GOT=held
}

case_v1_absent() {
  st_env
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/four-fragments.md"
  [ "$RC" = 0 ] || { GOT=fresh-exit$RC; return; }
  for _f in "$CONTRACT" CLAUDE.md AGENTS.md "$GATE_RUNNER"; do # a v1 stamp: knob-block tags only
    grep -v '^[[:space:]]*<!-- /\{0,1\}zone:' "$T/$_f" > "$H/v1" && cp "$H/v1" "$T/$_f" || { GOT=fixture-edit; return; }
  done
  grep -vxF '@~/.claude/chunks/extra-chunk.md' "$T/CLAUDE.md" > "$H/v1" && cp "$H/v1" "$T/CLAUDE.md" # a refresh would restore it
  _before=$(st_snapshot "$T")
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/four-fragments.md"
  [ "$RC" = 0 ] || { GOT=exit$RC; return; }
  [ "$_before" = "$(st_snapshot "$T")" ] || { GOT=target-changed; return; }
  [ "$(printf '%s\n' "$OUT" | grep -c '^ZONE ')" = 9 ] || { GOT=zone-count; return; }
  [ "$(printf '%s\n' "$OUT" | grep -c '^ZONE .* absent$')" = 9 ] || { GOT=zone-not-absent; return; }
  st_has 'KNOB verify-gate kept' || { GOT=knob-not-kept; return; }
  st_check "$FIXTURE_DIR/answers/four-fragments.md" # check side: every non-knob zone absent, nothing fails
  [ "$RC" = 0 ] || { GOT=check-exit$RC; return; }
  [ "$(printf '%s\n' "$OUT" | grep -c '^ZONE .* absent$')" = 9 ] && st_has "ZONE $CONTRACT knobs:verify-gate same" || { GOT=check-not-absent; return; }
  [ "$(printf '%s\n' "$OUT" | grep -c '^ZONE ')" = 10 ] || { GOT=check-zone-count; return; }
  GOT=absent-untouched
}

case_fill_guard() {
  st_env # control: a zone whose prompt was never filled refreshes without a stop
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/fill-guard-bare.md"
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/fill-guard-bare.md"
  [ "$RC" = 0 ] || { GOT=control-exit$RC; return; }
  st_env
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/fill-guard-filled.md"
  [ "$RC" = 0 ] || { GOT=fresh-exit$RC; return; }
  grep -qxF 'Guarded by the owner.' "$T/$CONTRACT" || { GOT=fill-missing; return; }
  st_stop_case "$FIXTURE_DIR/answers/fill-guard-bare.md" 'zone contract-sections of docs/agents/project-workflow.md would gain'
  [ "$GOT" = stopped-untouched ] || return
  printf '%s\n' "$OUT" | grep -qF 'fill:docs/agents/project-workflow.md#Guarded' || GOT=key-not-named
}

case_dest_is_directory() {
  st_env
  mkdir -p "$T/out/tokens.txt"
  st_stop_case "$FIXTURE_DIR/answers/every-token.md" 'out/tokens.txt exists as a directory'
}

case_readlist_hand_import() { # advisor M2: the read list comes from the CLAUDE.md left on disk
  st_env
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/four-fragments.md"
  [ "$RC" = 0 ] || { GOT=fresh-exit$RC; return; }
  printf '%s\n' '' '@~/.claude/chunks/hand-chunk.md' >> "$T/CLAUDE.md"
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/four-fragments.md"
  [ "$RC" = 0 ] || { GOT=exit$RC; return; }
  st_has 'ZONE AGENTS.md read-list refreshed' || { GOT=not-refreshed; return; }
  grep -qF 'These six files under' "$T/AGENTS.md" && grep -qF '`extra-chunk.md`, `hand-chunk.md`.' "$T/AGENTS.md" || { GOT=hand-import-missing; return; }
  [ "$(tail -n 1 "$T/CLAUDE.md")" = '@~/.claude/chunks/hand-chunk.md' ] || { GOT=claude-md-moved; return; }
  GOT=derived-from-target
}

case_knob_answer_differs() { # a re-run keeps the contract's value and says the answers file differs
  st_env
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/every-token.md"
  [ "$RC" = 0 ] || { GOT=fresh-exit$RC; return; }
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/every-token.md" # control: equal values, no NOTE
  [ "$RC" = 0 ] || { GOT=control-exit$RC; return; }
  printf '%s\n' "$OUT" | grep -q '^NOTE knobs:' && { GOT=control-noted; return; }
  printf '%s\n' '<!-- knobs:verify-gate -->' '- dir: repo root' '- test: make check' '<!-- /knobs:verify-gate -->' > "$H/blk"
  st_replace_block "$T/$CONTRACT" verify-gate "$H/blk" || { GOT=fixture-edit; return; }
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/every-token.md"
  [ "$RC" = 0 ] || { GOT=exit$RC; return; }
  st_has "NOTE knobs:verify-gate test: the contract's value is kept; the answers file's differs" || { GOT=no-note; return; }
  [ "$(printf '%s\n' "$OUT" | grep -c '^NOTE knobs:')" = 1 ] || { GOT=note-count; return; }
  grep -qxF -e '- test: make check' "$T/$CONTRACT" || { GOT=value-overwritten; return; }
  GOT=kept-noted
}

# settings: a target whose .claude/settings.local.json is <json> (or absent when empty), stamped with $1
st_settings_run() { # <answers> <json or empty>
  st_env
  if [ -n "$2" ]; then mkdir -p "$T/.claude" && printf '%s' "$2" > "$T/.claude/settings.local.json" || { GOT=fixture-edit; return 1; }; fi
  st_run stamp --target "$T" --answers "$1"
  [ "$RC" = 0 ] || { GOT=exit$RC; return 1; }
}
st_jq() { jq -r "$1" < "$T/.claude/settings.local.json" 2>/dev/null; }
st_settings_verdict() { # deny-wins | allow-added, from what the file holds and what stdout named
  [ "$(st_jq '.model')" = keep-me ] || { GOT=key-lost; return; }
  st_has 'SETTINGS allow-added Bash(fixture-b:*)' && [ "$(st_jq '.permissions.allow | index("Bash(fixture-b:*)") != null')" = true ] || { GOT=b-not-added; return; }
  st_has 'SETTINGS mcp-added fixture-mcp' && [ "$(st_jq '.enabledMcpjsonServers == ["other","fixture-mcp"]')" = true ] || { GOT=mcp; return; }
  _in=$(st_jq '.permissions.allow | index("Bash(fixture-a:*)") != null')
  if st_has 'SETTINGS deny-wins Bash(fixture-a:*)' && [ "$_in" = false ] && ! st_has 'SETTINGS allow-added Bash(fixture-a:*)'; then GOT=deny-wins
  elif st_has 'SETTINGS allow-added Bash(fixture-a:*)' && [ "$_in" = true ] && ! printf '%s\n' "$OUT" | grep -q '^SETTINGS deny-wins'; then GOT=allow-added
  else GOT=inconsistent; fi
}
case_settings_deny_wins() {
  st_settings_run "$FIXTURE_DIR/answers/settings.md" \
    '{"model":"keep-me","permissions":{"allow":["Bash(ls:*)"],"deny":["Bash(fixture-a:*)"]},"enabledMcpjsonServers":["other"]}' || return
  [ "$(st_jq '.permissions.deny == ["Bash(fixture-a:*)"]')" = true ] || { GOT=deny-changed; return; }
  st_settings_verdict
}
case_settings_allow_added() { # the same fixture without the deny: the calibration of deny-wins
  st_settings_run "$FIXTURE_DIR/answers/settings.md" \
    '{"model":"keep-me","permissions":{"allow":["Bash(ls:*)"]},"enabledMcpjsonServers":["other"]}' || return
  st_settings_verdict
}
case_settings_in_both() {
  st_settings_run "$FIXTURE_DIR/answers/settings.md" \
    '{"permissions":{"allow":["Bash(both:*)"],"deny":["Bash(both:*)"]}}' || return
  st_has 'SETTINGS in-both Bash(both:*) — left for the owner' || { GOT=not-reported; return; }
  [ "$(st_jq '(.permissions.allow | index("Bash(both:*)") != null) and .permissions.deny == ["Bash(both:*)"]')" = true ] || { GOT=changed; return; }
  GOT=reported-left
}
case_settings_no_rewrite() { # everything already present, formatted unlike jq: not one byte moves
  _j='{"enabledMcpjsonServers":["fixture-mcp"],   "permissions":{"allow":["Bash(fixture-b:*)","Bash(fixture-a:*)"]}}'
  st_settings_run "$FIXTURE_DIR/answers/settings.md" "$_j" || return
  [ "$(cat "$T/.claude/settings.local.json")" = "$_j" ] || { GOT=rewritten; return; }
  [ "$(jq . < "$T/.claude/settings.local.json")" != "$_j" ] || { GOT=fixture-is-jq-format; return; } # the control
  st_has 'UNCHANGED .claude/settings.local.json' || { GOT=no-unchanged-line; return; }
  printf '%s\n' "$OUT" | grep -q '^SETTINGS ' && { GOT=delta-reported; return; }
  GOT=not-rewritten
}
case_settings_created_from_baseline() { # a Profile with no settings delta still gets the baseline file
  st_settings_run "$FIXTURE_DIR/answers/four-fragments.md" '' || return
  st_has 'SETTINGS created-from-baseline' && st_has 'WROTE .claude/settings.local.json' || { GOT=not-reported; return; }
  [ "$(st_jq '. == {"permissions":{"defaultMode":"auto"},"sandbox":{"enabled":true}}')" = true ] || { GOT=not-baseline; return; }
  [ "$(printf '%s\n' "$OUT" | tail -n 2 | head -n 1)" = 'WROTE .claude/settings.local.json' ] || { GOT=not-last; return; }
  GOT=baseline
}

case_jq_absent() { # a PATH of symlinks to every tool the script uses, minus jq (/usr/bin/jq cannot be renamed)
  st_env; mkdir -p "$H/bin" "$H/binjq" || { GOT=fixture-edit; return; }
  for _t in "$SELF_SH" awk basename cat chmod cksum cmp cp cut dirname find grep head locale ls mkdir mktemp mv ps rm sed sort tail tr uname wc; do
    _w=$(command -v "$_t") || { GOT=no-$_t; return; }
    ln -s "$_w" "$H/bin/$_t" && ln -s "$_w" "$H/binjq/$_t" || { GOT=fixture-edit; return; }
  done
  ln -s "$(command -v jq)" "$H/binjq/jq" || { GOT=fixture-edit; return; }
  OUT=$(PATH=$H/binjq HOME=$H INIT_PROJECT_PROFILE_DIR=$FIXTURE_DIR/profiles INIT_PROJECT_KNOB_CHANGES=$FIXTURE_DIR/knob-changes/none \
    "$SELF_SH" "$SELF" stamp --target "$T" --answers "$FIXTURE_DIR/answers/settings.md" < /dev/null 2>&1); RC=$?
  [ "$RC" = 0 ] || { GOT=control-exit$RC; return; } # the same PATH with jq: every other tool is there
  mk_tmpdir; T=$MKD
  OUT=$(PATH=$H/bin HOME=$H INIT_PROJECT_PROFILE_DIR=$FIXTURE_DIR/profiles INIT_PROJECT_KNOB_CHANGES=$FIXTURE_DIR/knob-changes/none \
    "$SELF_SH" "$SELF" stamp --target "$T" --answers "$FIXTURE_DIR/answers/settings.md" < /dev/null 2>&1); RC=$?
  [ "$RC" = 2 ] || { GOT=exit$RC; return; }
  [ -z "$(ls -A "$T")" ] || { GOT=target-written; return; }
  st_has "STOP: jq not found — the settings merge needs it. Install: $(jq_install)" || { GOT=no-install-line; return; }
  GOT=stopped-install-named
}

case_host_setup_idempotent() {
  st_env; _ig=$H/.config/git/ignore; _hp=$H/.local/bin/fixture-helper
  mkdir -p "$H/.config/git" && printf '%s' '*.swp' > "$_ig" || { GOT=fixture-edit; return; } # no final newline
  st_run host-setup --answers "$FIXTURE_DIR/answers/settings.md"
  [ "$RC" = 0 ] || { GOT=exit$RC; return; }
  st_has "HOST-SETUP added **/.codex/config.toml to ~/.config/git/ignore — undo: grep -vxF '**/.codex/config.toml' ~/.config/git/ignore > ~/.config/git/ignore.tmp && mv ~/.config/git/ignore.tmp ~/.config/git/ignore" ||
    { GOT=no-added-codex; return; }
  st_has 'HOST-SETUP wrote ~/.local/bin/fixture-helper — undo: rm ~/.local/bin/fixture-helper' || { GOT=no-wrote; return; }
  printf '%s\n' '*.swp' '**/.codex/config.toml' '**/.claude/settings.local.json' > "$H/want"
  cmp -s "$H/want" "$_ig" || { GOT=ignore-content; return; }
  cmp -s "$FIXTURE_DIR/profiles/settings/templates/fixture-helper" "$_hp" && [ -x "$_hp" ] || { GOT=helper; return; }
  _before=$(st_snapshot "$H")
  st_run host-setup --answers "$FIXTURE_DIR/answers/settings.md"
  [ "$RC" = 0 ] && [ "$_before" = "$(st_snapshot "$H")" ] || { GOT=second-run-changed; return; }
  [ "$(printf '%s\n' "$OUT" | grep -c '^HOST-SETUP present .* — undo: none needed$')" = 3 ] || { GOT=not-present; return; }
  printf '%s\n' 'echo edited by the owner' > "$_hp"; _before=$(st_snapshot "$H")
  st_run host-setup --answers "$FIXTURE_DIR/answers/settings.md"
  [ "$RC" = 0 ] && [ "$_before" = "$(st_snapshot "$H")" ] || { GOT=differing-overwritten; return; }
  st_has 'HOST-SETUP differs ~/.local/bin/fixture-helper — left, not overwritten — undo: none needed' || { GOT=no-differs; return; }
  GOT=idempotent
}

# verify and check: a stamp with every fill answered is the base every residue case plants into
st_vbase() { st_env; st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/verify-clean.md"; [ "$RC" = 0 ] || { GOT=fresh-exit$RC; return 1; }; }
st_verify() { st_run verify --target "$T" --answers "$FIXTURE_DIR/answers/verify-clean.md"; }
st_check() { st_run check --target "$T" --answers "$1"; }
st_failset() { # the failing CHECK and GATE names, space-joined, in output order
  printf '%s\n' "$OUT" | sed -n -e 's/^CHECK \([^:]*\): FAIL — .*/\1/p' -e 's/^GATE \([^:]*\): FAIL — .*/\1/p' | tr '\n' ' ' | sed 's/ $//'
}
st_residue() { # <file> <line planted at its end> → GOT=fails-<failing set, +-joined>
  st_vbase || return
  printf '%s\n' "$2" >> "$T/$1"
  st_verify
  [ "$RC" = 1 ] || { GOT=exit$RC; return; }
  GOT=fails-$(st_failset | tr ' ' '+')
}
case_residue_braces() { st_residue CLAUDE.md 'Residue {{UNSUBSTITUTED}} left behind.'; }
case_residue_marker() { st_residue CLAUDE.md '<!-- profile:codex-mechanics -->'; }
case_residue_fill_prompt() { st_residue "$CONTRACT" '*<Fill at init: what this project is.>*'; }
case_residue_fill_prompt_fork_spelling() { st_residue AGENTS.md '- *<`/name`, filled at init>*'; } # outside CLAUDE.md: fill-prompt alone
case_residue_fork_slot() { st_residue CLAUDE.md 'The fork is *<`/name`, filled at init>*.'; } # fill-prompt leaves this one to fork-slot
case_residue_empty_heading() { st_residue "$CONTRACT" '## Left empty'; }

case_verify_clean() {
  st_vbase || return
  _before=$(st_snapshot "$T")
  st_verify
  [ "$RC" = 0 ] || { GOT=exit$RC; return; }
  [ "$_before" = "$(st_snapshot "$T")" ] || { GOT=target-changed; return; }
  for _c in braces marker fill-prompt fork-slot empty-heading; do
    printf '%s\n' "$OUT" | grep -q "^CONTROL $_c: known-bad matched [1-9][0-9]* — target matched 0\$" || { GOT=control-$_c; return; }
    printf '%s\n' "$OUT" | grep -q "^CHECK $_c: PASS — " || { GOT=check-$_c; return; }
  done
  st_has 'GATE imports-resolve: PASS — 8 import(s) resolve' || { GOT=imports; return; }
  st_has "VERIFY-GATE: NOT RUN by this script — the seat runs the verify-gate Chunk's gates from the contract's knob block, as step 7 does" || { GOT=verify-gate-line; return; }
  GOT=clean
}

case_resolved_load_figure() { # CLAUDE.md 122 → contract 110 → chunks 26 + 32; a fenced import and a symlinked alias do not count
  st_env; mkdir -p "$T/docs/agents" || { GOT=fixture-edit; return; }
  printf '%s\n' '# Load fixture' '@docs/agents/project-workflow.md' '@~/.claude/chunks/extra-chunk.md' '```' '@~/.claude/chunks/verify-gate.md' '```' > "$T/CLAUDE.md"
  printf '%s\n' '# Contract' '@~/.claude/chunks/extra-chunk.md' '@~/.claude/chunks/alias.md' '@~/.claude/chunks/git-commit-format.md' > "$T/$CONTRACT"
  printf '%s\n' '# Codex' '<!-- zone:read-list -->' '3. These two files:' '   `extra-chunk.md`, `git-commit-format.md`.' '<!-- /zone:read-list -->' > "$T/AGENTS.md"
  printf '%s\n' '# Context' > "$T/CONTEXT.md"
  ln -s extra-chunk.md "$H/.claude/chunks/alias.md" || { GOT=fixture-edit; return; }
  st_verify
  printf '%s\n' "$OUT" | grep '^LOAD claude ' > "$H/got"
  printf '%s\n' 'LOAD claude CLAUDE.md 122' 'LOAD claude docs/agents/project-workflow.md 110' 'LOAD claude ~/.claude/chunks/extra-chunk.md 26' \
    'LOAD claude ~/.claude/chunks/git-commit-format.md 32' 'LOAD claude TOTAL 290 — reported, not gated' > "$H/want"
  cmp -s "$H/want" "$H/got" || { GOT=claude-load; return; }
  st_has 'LOAD codex TOTAL 300 — reported, not gated' && st_has 'LOAD codex CONTEXT.md 10' || { GOT=codex-load; return; }
  st_has 'GATE imports-resolve: PASS — 5 import(s) resolve' || { GOT=imports; return; }
  GOT=total-exact
}

case_load_total_not_gated() { # every gated file under its cap; a chunk takes the total past 48 KiB
  st_vbase || return
  awk 'BEGIN { for (i = 0; i < 1000; i++) print "padding padding padding padding padding padding pad" }' >> "$H/.claude/chunks/extra-chunk.md"
  st_verify
  [ "$RC" = 0 ] || { GOT=exit$RC; return; }
  _t=$(printf '%s\n' "$OUT" | sed -n 's/^LOAD claude TOTAL \([0-9]*\) — reported, not gated$/\1/p')
  [ -n "$_t" ] && [ "$_t" -gt 49152 ] || { GOT=total-not-over; return; }
  GOT=reported-exit0
}

case_contract_over_cap() { # a 48 KB contract exits 1 through its own gate, never through the total
  st_vbase || return
  awk 'BEGIN { for (i = 0; i < 1000; i++) print "an over-long contract line, padding padding padding" }' >> "$T/$CONTRACT"
  st_verify
  [ "$RC" = 1 ] || { GOT=exit$RC; return; }
  [ "$(st_failset)" = "bytes $CONTRACT" ] || { GOT=failset-$(st_failset | tr ' ' '+'); return; }
  printf '%s\n' "$OUT" | grep -q '^LOAD claude TOTAL [0-9]* — reported, not gated$' || { GOT=no-total; return; }
  GOT=contract-gate-only
}

case_check_same() { # a fresh stamp reads same everywhere; a project key of the owner's is not drift
  st_vbase || return
  st_check "$FIXTURE_DIR/answers/verify-clean.md"
  [ "$RC" = 0 ] || { GOT=exit$RC; return; }
  [ "$(printf '%s\n' "$OUT" | grep -c '^ZONE ')" = 13 ] && [ "$(printf '%s\n' "$OUT" | grep -c '^ZONE .* same$')" = 13 ] || { GOT=not-all-same; return; }
  awk '$0 == "<!-- /knobs:verify-gate -->" { print "- custom_gate: make lint" } { print }' "$T/$CONTRACT" > "$H/c" && cp "$H/c" "$T/$CONTRACT" || { GOT=fixture-edit; return; }
  _before=$(st_snapshot "$T")
  st_check "$FIXTURE_DIR/answers/verify-clean.md"
  [ "$RC" = 0 ] || { GOT=own-key-exit$RC; return; }
  [ "$_before" = "$(st_snapshot "$T")" ] || { GOT=target-changed; return; }
  st_has "NOTE knobs:verify-gate custom_gate: the project's own key, not drift" && st_has "ZONE $CONTRACT knobs:verify-gate same" || { GOT=own-key; return; }
  GOT=same
}

case_zone_differs() {
  st_vbase || return
  awk '$0 == "<!-- /zone:claude-mechanics -->" { print "An edit inside the zone." } { print }' "$T/CLAUDE.md" > "$H/c" && cp "$H/c" "$T/CLAUDE.md" || { GOT=fixture-edit; return; }
  st_check "$FIXTURE_DIR/answers/verify-clean.md"
  [ "$RC" = 1 ] || { GOT=exit$RC; return; }
  [ "$(printf '%s\n' "$OUT" | grep '^ZONE .* differs$')" = 'ZONE CLAUDE.md claude-mechanics differs' ] || { GOT=wrong-zones; return; }
  GOT=differs-named
}

case_check_unparsed() {
  st_vbase || return
  printf '%s\n' '<!-- knobs:verify-gate -->' '- dir: repo root' 'A prose line no rewrite can parse.' '<!-- /knobs:verify-gate -->' > "$H/blk"
  st_replace_block "$T/$CONTRACT" verify-gate "$H/blk" || { GOT=fixture-edit; return; }
  st_check "$FIXTURE_DIR/answers/verify-clean.md"
  [ "$RC" = 1 ] || { GOT=exit$RC; return; }
  st_has "ZONE $CONTRACT knobs:verify-gate unparsed" || { GOT=not-unparsed; return; }
  [ "$(printf '%s\n' "$OUT" | grep -Ec '^ZONE .* (differs|unparsed)$')" = 1 ] || { GOT=other-drift; return; }
  GOT=unparsed-fails
}

case_after_freeze_fill() { # a fill for a file this mode does not write is a NOTE, never a stop
  st_env
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/after-freeze.md"
  [ "$RC" = 0 ] || { GOT=plain-exit$RC; return; }
  st_has 'SKIPPED late.md — after_freeze' && st_has 'NOTE fill:late.md#Late not used — this run does not write late.md' || { GOT=plain-lines; return; }
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/after-freeze.md" --after-freeze
  [ "$RC" = 0 ] || { GOT=exit$RC; return; }
  st_has "NOTE fill:$CONTRACT#Project not used — this run does not write $CONTRACT" && st_has 'WROTE late.md' || { GOT=freeze-lines; return; }
  grep -qxF 'Written after the freeze.' "$T/late.md" || { GOT=fill-missing; return; }
  printf '%s\n' "$OUT" | grep -q "^WROTE $CONTRACT" && { GOT=contract-written; return; }
  GOT=noted-not-stopped
}

st_answers() { # <file> <type> <tracker> [<fill key> <fill line>]... — an answers file built in the case
  _af=$1; printf '%s\n' '<!-- answers:meta -->' '- project_name: Fixture' "- type: $2" "- tracker: $3" '<!-- /answers:meta -->' > "$_af"; shift 3
  while [ $# -ge 2 ]; do printf '%s\n' '' "<!-- fill:$1 -->" "$2" "<!-- /fill:$1 -->" >> "$_af"; shift 2; done
}

case_silent_stops() { # a stop inside a redirect used to print into a staging file and exit 2 silently
  st_env; mkdir -p "$H/profiles" || { GOT=fixture-edit; return; }
  printf '%s\n' '---' 'imports:' '  - foo.bar' '---' > "$H/profiles/bad-import.md"
  st_answers "$H/a.md" bad-import none
  ST_PD=$H/profiles; st_run stamp --target "$T" --answers "$H/a.md"; ST_PD=
  [ "$RC" = 2 ] || { GOT=import-exit$RC; return; }
  st_has 'STOP: Profile import foo.bar is not a chunk name' && [ "$(printf '%s\n' "$OUT" | tail -n 1)" = 'RESULT: stamp stopped (exit 2)' ] || { GOT=import-silent; return; }
  st_vbase || return
  ST_KC=$H/no-such-knob-changes; st_check "$FIXTURE_DIR/answers/verify-clean.md"; ST_KC=
  [ "$RC" = 2 ] || { GOT=check-exit$RC; return; }
  st_has "STOP: the knob-changes file $H/no-such-knob-changes is not found" && [ "$(printf '%s\n' "$OUT" | tail -n 1)" = 'RESULT: check stopped (exit 2)' ] || { GOT=check-silent; return; }
  GOT=stop-printed
}

case_fill_prompt_names_all() { # verify's fill-prompt FAIL is the list of what is left to answer: all of it
  st_vbase || return
  printf '%s\n' '*<Fill at init: one.>*' '*<Fill at init: two.>*' '*<Fill at init: three.>*' '*<Fill at init: four.>*' >> "$T/$CONTRACT"
  st_verify
  [ "$RC" = 1 ] || { GOT=exit$RC; return; }
  _l=$(printf '%s\n' "$OUT" | grep '^CHECK fill-prompt: FAIL — 4 match(es): ')
  [ "$(printf '%s\n' "$_l" | tr ',' '\n' | grep -c "$CONTRACT:[0-9]")" = 4 ] || { GOT=named-$(printf '%s\n' "$_l" | tr ',' '\n' | grep -c "$CONTRACT:[0-9]"); return; }
  GOT=names-all-4
}

case_check_not_run() { # a control that could not run is NOT RUN, never PASS, and exits 1
  st_vbase || return
  rm -f "$T/CLAUDE.md"; chmod 000 "$T/docs/agents/issue-tracker.md" || { GOT=fixture-edit; return; }
  st_verify
  chmod 644 "$T/docs/agents/issue-tracker.md"
  [ "$RC" = 1 ] || { GOT=exit$RC; return; }
  st_has 'CHECK fork-slot: NOT RUN — no file to scan' || { GOT=no-file-not-not-run; return; }
  st_has 'CHECK braces: NOT RUN — the detector failed on the target' || { GOT=detector-error-not-not-run; return; }
  st_has 'RESULT: verify failed (exit 1)' || { GOT=result; return; }
  GOT=not-run-exit1
}

case_interrupt_no_temp() { # a TERM between the temp's cp and its mv leaves no <dest>.tmp.<pid> in the target
  st_env; mkdir -p "$H/bin" || { GOT=fixture-edit; return; }
  for _t in "$SELF_SH" awk basename cat chmod cksum cmp cp cut dirname find grep head jq locale ls mkdir mktemp ps readlink rm sed sort tail tr uname wc; do
    _w=$(command -v "$_t") || { GOT=no-$_t; return; }
    ln -s "$_w" "$H/bin/$_t" || { GOT=fixture-edit; return; }
  done
  printf '%s\n' '#!/bin/sh' 'for a; do case $a in *.tmp.*) [ -f "$a" ] && : > "$0.saw-temp" ;; esac; done' 'kill -TERM $PPID' 'exit 1' > "$H/bin/mv"
  chmod +x "$H/bin/mv" || { GOT=fixture-edit; return; }
  OUT=$(PATH=$H/bin HOME=$H INIT_PROJECT_PROFILE_DIR=$FIXTURE_DIR/profiles INIT_PROJECT_KNOB_CHANGES=$FIXTURE_DIR/knob-changes/none \
    "$SELF_SH" "$SELF" stamp --target "$T" --answers "$FIXTURE_DIR/answers/four-fragments.md" < /dev/null 2>&1); RC=$?
  [ -f "$H/bin/mv.saw-temp" ] || { GOT=never-interrupted; return; } # the control: a temp existed when the signal came
  [ "$RC" = 2 ] || { GOT=exit$RC; return; }
  [ "$(printf '%s\n' "$OUT" | tail -n 1)" = 'RESULT: stamp stopped (exit 2)' ] || { GOT=no-result-line; return; }
  [ -z "$(find "$T" -name '*.tmp.*' -print)" ] || { GOT=temp-left; return; }
  GOT=temp-removed
}

case_locale_pin() { # the child pins UTF-8 itself: an ASCII locale in its env changes no byte of output or tree
  st_env; mk_tmpdir; _t2=$MKD
  _asc=en_US.US-ASCII; locale -a 2>/dev/null | grep -qx "$_asc" || _asc=C # no US-ASCII locale (glibc): C
  st_answers "$H/a.md" four-fragments none "$CONTRACT#Project" 'Démo Ω, a café fixture — non-ASCII on purpose.'
  st_run stamp --target "$T" --answers "$H/a.md"; _o1=$OUT
  [ "$RC" = 0 ] || { GOT=utf8-exit$RC; return; }
  ST_LOC=$_asc; st_run stamp --target "$_t2" --answers "$H/a.md"; ST_LOC=
  [ "$RC" = 0 ] || { GOT=ascii-exit$RC; return; }
  [ "$OUT" = "$_o1" ] || { GOT=output-differs; return; }
  [ "$(st_snapshot "$T")" = "$(st_snapshot "$_t2")" ] || { GOT=tree-differs; return; }
  if [ "$_asc" = en_US.US-ASCII ]; then # the control: unpinned, this locale does change the run
    mk_tmpdir; ST_LOC=$_asc; ST_NOPIN=1; st_run stamp --target "$MKD" --answers "$H/a.md"; ST_LOC=; ST_NOPIN=
    [ "$OUT" != "$_o1" ] || { GOT=control-did-not-bite; return; }
  fi
  GOT=pinned
}

case_fenced_tags() { # a tag inside fenced code is prose: no tracker switch, no block, no zone, v1 stays v1
  st_env
  # the answers file shows a second meta block in a fence: read, it would be "appears twice"
  { cat "$FIXTURE_DIR/answers/four-fragments.md"
    printf '%s\n' '' '```md' '<!-- answers:meta -->' '- project_name: Example' '<!-- /answers:meta -->' '```'; } > "$H/a.md" || { GOT=fixture-edit; return; }
  st_run stamp --target "$T" --answers "$H/a.md"
  [ "$RC" = 0 ] || { GOT=fresh-exit$RC; return; }
  # knobs:verify-gate is a block the Profile lists and the contract already carries: read, it opens twice
  printf '%s\n' '' '```md' '<!-- knobs:tracker-github -->' '- REPO: example/example' '<!-- /knobs:tracker-github -->' \
    '<!-- knobs:verify-gate -->' '- dir: example' '<!-- /knobs:verify-gate -->' \
    '<!-- knobs:example -->' '- a: b' '<!-- /knobs:example -->' '<!-- zone:example -->' '<!-- /zone:example -->' '```' >> "$T/$CONTRACT"
  grep -v '^[[:space:]]*<!-- /\{0,1\}zone:' "$T/CLAUDE.md" > "$H/v1" && cp "$H/v1" "$T/CLAUDE.md" || { GOT=fixture-edit; return; }
  printf '%s\n' '' '~~~' '<!-- zone:imports -->' '<!-- /zone:imports -->' '~~~' >> "$T/CLAUDE.md"
  _before=$(st_snapshot "$T")
  st_run stamp --target "$T" --answers "$H/a.md"
  [ "$RC" = 0 ] || { GOT=exit$RC; return; }
  [ "$_before" = "$(st_snapshot "$T")" ] || { GOT=target-changed; return; }
  printf '%s\n' "$OUT" | grep -q -e '^KNOB tracker-github' -e '^KNOB example' -e ' orphan$' && { GOT=fenced-tag-read; return; }
  st_has 'ZONE CLAUDE.md imports absent' || { GOT=v1-not-absent; return; }
  st_check "$H/a.md"
  [ "$RC" = 0 ] || { GOT=check-exit$RC; return; }
  GOT=fences-ignored
}

case_symlink_dest_stop() { # a link a write would land on stops before any write; one no write touches is left
  st_env
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/four-fragments.md"
  [ "$RC" = 0 ] || { GOT=fresh-exit$RC; return; }
  # the control: CLAUDE.md with every zone same, settings with no delta, both links, re-run clean
  mv "$T/CLAUDE.md" "$T/claude-real.md" && ln -s claude-real.md "$T/CLAUDE.md" &&
    mv "$T/.claude/settings.local.json" "$T/settings-real.json" && ln -s ../settings-real.json "$T/.claude/settings.local.json" || { GOT=fixture-edit; return; }
  _before=$(st_snapshot "$T")
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/four-fragments.md"
  [ "$RC" = 0 ] || { GOT=noop-exit$RC; return; }
  [ "$_before" = "$(st_snapshot "$T")" ] && [ -L "$T/CLAUDE.md" ] && [ -L "$T/.claude/settings.local.json" ] &&
    st_has 'UNCHANGED CLAUDE.md' && st_has 'UNCHANGED .claude/settings.local.json' || { GOT=noop-link-touched; return; }
  awk '$0 == "<!-- /zone:codex-mechanics -->" { print "An edit a refresh would undo." } { print }' "$T/AGENTS.md" > "$T/agents-real.md" &&
    rm "$T/AGENTS.md" && ln -s agents-real.md "$T/AGENTS.md" || { GOT=fixture-edit; return; }
  st_stop_case "$FIXTURE_DIR/answers/four-fragments.md" 'AGENTS.md is a symlink'
}

case_cdpath_unset() { # an exported CDPATH must not move a relative --target
  st_env; mk_tmpdir; _w=$MKD; mkdir -p "$_w/proj" "$_w/decoy/proj" || { GOT=fixture-edit; return; }
  OUT=$(cd "$_w" && CDPATH=$_w/decoy HOME=$H INIT_PROJECT_PROFILE_DIR=$FIXTURE_DIR/profiles INIT_PROJECT_KNOB_CHANGES=$FIXTURE_DIR/knob-changes/none \
    "$SELF_SH" "$SELF" stamp --target proj --answers "$FIXTURE_DIR/answers/four-fragments.md" < /dev/null 2>&1); RC=$?
  [ "$RC" = 0 ] || { GOT=exit$RC; return; }
  [ -f "$_w/proj/CLAUDE.md" ] && [ -z "$(ls -A "$_w/decoy/proj")" ] || { GOT=wrong-target; return; }
  GOT=target-resolved
}

case_fresh_held_stop() { # held is read from a contract, never taken from the answers file
  st_env; st_answers "$H/a.md" four-fragments held
  st_stop_case "$H/a.md" 'tracker held on a fresh stamp'
}

case_no_final_newline() { # a file whose zones are all same is not rewritten for a final newline
  st_env
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/four-fragments.md"
  [ "$RC" = 0 ] || { GOT=fresh-exit$RC; return; }
  for _f in AGENTS.md "$CONTRACT"; do printf '%s' "$(cat "$T/$_f")" > "$H/nn" && cp "$H/nn" "$T/$_f" || { GOT=fixture-edit; return; }; done
  [ "$(tail -c 1 "$T/AGENTS.md" | wc -l | tr -d ' ')" = 0 ] || { GOT=fixture-has-newline; return; }
  _before=$(st_snapshot "$T")
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/four-fragments.md"
  [ "$RC" = 0 ] || { GOT=exit$RC; return; }
  [ "$_before" = "$(st_snapshot "$T")" ] || { GOT=rewritten; return; }
  st_has 'UNCHANGED AGENTS.md' && st_has "UNCHANGED $CONTRACT" || { GOT=not-unchanged; return; }
  GOT=kept-as-is
}

case_unlisted_block_kept() { # O1: a block is deleted only on a declared retire-block row
  st_env
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/four-fragments.md"
  [ "$RC" = 0 ] || { GOT=fresh-exit$RC; return; }
  awk '{ print } $0 == "<!-- /knobs:verify-gate -->" { print ""; print "<!-- knobs:hand-chunk -->"; print "Hand-written prose no rewrite parses."; print "<!-- /knobs:hand-chunk -->" }' \
    "$T/$CONTRACT" > "$H/c" && cp "$H/c" "$T/$CONTRACT" || { GOT=fixture-edit; return; }
  st_knob "$T/$CONTRACT" verify-gate > "$H/vg"; st_knob "$T/$CONTRACT" hand-chunk > "$H/hc"
  st_answers "$H/meta.md" none none # a meta-only type-none answers file lists no block
  st_run stamp --target "$T" --answers "$H/meta.md"
  [ "$RC" = 0 ] || { GOT=exit$RC; return; }
  st_has 'KNOB verify-gate kept — not a block this stamp lists, and no retire-block row names it' &&
    st_has 'KNOB hand-chunk kept — not a block this stamp lists, and no retire-block row names it' || { GOT=not-reported; return; }
  st_knob "$T/$CONTRACT" verify-gate | cmp -s - "$H/vg" && st_knob "$T/$CONTRACT" hand-chunk | cmp -s - "$H/hc" || { GOT=block-changed; return; }
  st_check "$H/meta.md"
  [ "$RC" = 0 ] && st_has "ZONE $CONTRACT knobs:hand-chunk orphan" || { GOT=check-drift; return; }
  printf '%s\n' 'retire-block hand-chunk' > "$H/kc"; ST_KC=$H/kc
  st_check "$H/meta.md"
  [ "$RC" = 1 ] && st_has "ZONE $CONTRACT knobs:hand-chunk differs" || { ST_KC=; GOT=declared-not-differs; return; }
  st_run stamp --target "$T" --answers "$H/meta.md"; ST_KC=
  [ "$RC" = 0 ] && st_has 'KNOB hand-chunk block-deleted (3 lines)' || { GOT=declared-not-deleted; return; }
  grep -q '^<!-- knobs:hand-chunk -->$' "$T/$CONTRACT" && { GOT=declared-kept; return; }
  GOT=kept-unless-declared
}

case_rerun_fill_outside() { # O2: add the fill, stamp again, and verify converges
  st_env
  st_answers "$H/bare.md" four-fragments none
  st_answers "$H/full.md" four-fragments none "$CONTRACT#Project" 'A fixture project.' "$CONTRACT#Working in this repo" 'Nothing beyond the Chunks.' \
    'AGENTS.md#Skills' '`$git-flow-squash` only.'
  st_run stamp --target "$T" --answers "$H/bare.md"
  [ "$RC" = 0 ] || { GOT=fresh-exit$RC; return; }
  st_run stamp --target "$T" --answers "$H/full.md"
  [ "$RC" = 0 ] || { GOT=exit$RC; return; }
  st_has "FILLED $CONTRACT#Project" && st_has "FILLED $CONTRACT#Working in this repo" && st_has 'FILLED AGENTS.md#Skills' || { GOT=not-filled; return; }
  st_run verify --target "$T" --answers "$H/full.md"
  [ "$RC" = 0 ] || { GOT=verify-exit$RC; return; }
  _before=$(st_snapshot "$T")
  st_run stamp --target "$T" --answers "$H/full.md"
  [ "$RC" = 0 ] && [ "$_before" = "$(st_snapshot "$T")" ] || { GOT=third-run-changed; return; }
  [ "$(printf '%s\n' "$OUT" | grep -c '^NOTE fill:.* not used — no fill prompt under that heading survives in ')" = 3 ] || { GOT=no-note; return; }
  st_env # a skip-if-exists Profile template already in the target takes its fill the same way
  st_answers "$H/bare.md" after-freeze none
  st_run stamp --target "$T" --answers "$H/bare.md" --after-freeze
  [ "$RC" = 0 ] && grep -q 'Fill at init' "$T/late.md" || { GOT=late-fresh; return; }
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/after-freeze.md" --after-freeze
  [ "$RC" = 0 ] && st_has 'FILLED late.md#Late' && st_has 'WROTE late.md' && grep -qxF 'Written after the freeze.' "$T/late.md" || { GOT=late-not-filled; return; }
  GOT=filled-converged
}

case_fill_key_typo_rerun() { # a re-run key whose heading the file never had stops, as a fresh stamp does
  st_env
  st_answers "$H/bare.md" four-fragments none
  st_answers "$H/typo.md" four-fragments none 'AGENTS.md#Skils' 'A typo.'
  st_run stamp --target "$T" --answers "$H/typo.md"
  [ "$RC" = 2 ] && st_has 'STOP: fill:AGENTS.md#Skils matches no fill prompt in a file this stamp writes' || { GOT=fresh-did-not-stop; return; }
  st_run stamp --target "$T" --answers "$H/bare.md"
  [ "$RC" = 0 ] || { GOT=bare-exit$RC; return; }
  st_stop_case "$H/typo.md" 'fill:AGENTS.md#Skils matches no heading in AGENTS.md'
}

case_outside_fill_skips_code() { # O2 neither fills nor counts a prompt quoted in a fence or an inline code span
  st_env
  st_answers "$H/bare.md" four-fragments none
  st_answers "$H/full.md" four-fragments none "$CONTRACT#Project" 'A fixture project.'
  st_run stamp --target "$T" --answers "$H/bare.md"
  [ "$RC" = 0 ] || { GOT=fresh-exit$RC; return; }
  awk '{ print } $0 == "## Project" { print ""; print "```md"; print "*<Fill at init: a quoted example.>*"; print "```"
    print "Quoted inline: `*<Fill at init: an inline example.>*`, as prose." }' "$T/$CONTRACT" > "$H/c" && cp "$H/c" "$T/$CONTRACT" || { GOT=fixture-edit; return; }
  st_run stamp --target "$T" --answers "$H/full.md"
  [ "$RC" = 0 ] || { GOT=exit$RC; return; }
  st_has "FILLED $CONTRACT#Project" && grep -qxF 'A fixture project.' "$T/$CONTRACT" || { GOT=not-filled; return; }
  grep -qxF '*<Fill at init: a quoted example.>*' "$T/$CONTRACT" || { GOT=fenced-filled; return; }
  grep -qxF 'Quoted inline: `*<Fill at init: an inline example.>*`, as prose.' "$T/$CONTRACT" || { GOT=inline-filled; return; }
  GOT=code-kept
}

case_fence_closing_rule() { # CommonMark: ~~~ inside ``` is content; ``` inside ```` is content
  st_env
  { printf '%s\n' '````md' '```' '<!-- answers:meta -->' '- project_name: Example' '<!-- /answers:meta -->' '```' '````' ''
    printf '%s\n' '<!-- answers:meta -->' '- project_name: Fixture' '- type: four-fragments' '- tracker: none' '<!-- /answers:meta -->' \
      '' "<!-- fill:$CONTRACT#Project -->" '```text' '~~~ also content' '```' "<!-- /fill:$CONTRACT#Project -->"; } > "$H/a.md" || { GOT=fixture-edit; return; }
  st_run stamp --target "$T" --answers "$H/a.md"
  [ "$RC" = 0 ] || { GOT=fresh-exit$RC; return; }
  grep -qxF '~~~ also content' "$T/$CONTRACT" && grep -qxF -e '- project_name: Example' "$H/a.md" || { GOT=fill-lost; return; }
  _before=$(st_snapshot "$T")
  st_run stamp --target "$T" --answers "$H/a.md"
  [ "$RC" = 0 ] && [ "$_before" = "$(st_snapshot "$T")" ] || { GOT=rerun-exit$RC; return; }
  st_check "$H/a.md"
  [ "$RC" = 0 ] || { GOT=check-exit$RC; return; }
  GOT=commonmark-fences
}

case_fill_heading_renamed_rerun() { # a re-run key whose heading was renamed in a Profile template or pointer is a NOTE; a typo stops
  st_env
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/after-freeze.md" --after-freeze
  [ "$RC" = 0 ] && grep -qxF 'Written after the freeze.' "$T/late.md" || { GOT=template-fresh-exit$RC; return; }
  awk 'NR == 1 { print "# Later, renamed by the owner"; next } { print }' "$T/late.md" > "$H/l" && cp "$H/l" "$T/late.md" || { GOT=fixture-edit; return; }
  _before=$(st_snapshot "$T")
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/after-freeze.md" --after-freeze
  [ "$RC" = 0 ] || { GOT=template-exit$RC; return; }
  st_has 'NOTE fill:late.md#Late not used — no fill prompt under that heading survives in late.md' || { GOT=template-no-note; return; }
  [ "$_before" = "$(st_snapshot "$T")" ] || { GOT=template-changed; return; }
  st_answers "$H/typo.md" after-freeze none 'late.md#Lat' 'A typo.'
  st_run stamp --target "$T" --answers "$H/typo.md" --after-freeze
  [ "$RC" = 2 ] && st_has 'STOP: fill:late.md#Lat matches no heading in late.md, so no fill prompt there can take it' || { GOT=template-typo-exit$RC; return; }
  st_env # a pointer: its source heading carries {{PROJECT_NAME}}, which the key names substituted
  st_run stamp --target "$T" --answers "$FIXTURE_DIR/answers/tracker-github.md"
  [ "$RC" = 0 ] || { GOT=pointer-fresh-exit$RC; return; }
  awk 'NR == 1 { print "# Our tracker"; next } { print }' "$T/docs/agents/issue-tracker.md" > "$H/p" && cp "$H/p" "$T/docs/agents/issue-tracker.md" || { GOT=fixture-edit; return; }
  { cat "$FIXTURE_DIR/answers/tracker-github.md"; printf '%s\n' '' '<!-- fill:docs/agents/issue-tracker.md#Issue tracker — Fixture -->' 'Renamed away.' \
      '<!-- /fill:docs/agents/issue-tracker.md#Issue tracker — Fixture -->'; } > "$H/renamed.md" || { GOT=fixture-edit; return; }
  st_run stamp --target "$T" --answers "$H/renamed.md"
  [ "$RC" = 0 ] || { GOT=pointer-exit$RC; return; }
  st_has 'NOTE fill:docs/agents/issue-tracker.md#Issue tracker — Fixture not used — no fill prompt under that heading survives in docs/agents/issue-tracker.md' || { GOT=pointer-no-note; return; }
  { cat "$FIXTURE_DIR/answers/tracker-github.md"; printf '%s\n' '' '<!-- fill:docs/agents/issue-tracker.md#Issue trackr -->' 'A typo.' \
      '<!-- /fill:docs/agents/issue-tracker.md#Issue trackr -->'; } > "$H/ptypo.md" || { GOT=fixture-edit; return; }
  st_stop_case "$H/ptypo.md" 'fill:docs/agents/issue-tracker.md#Issue trackr matches no heading in docs/agents/issue-tracker.md'
  [ "$GOT" = stopped-untouched ] || { GOT=pointer-typo-$GOT; return; }
  GOT=renamed-note-typo-stops
}

case_interrupt_in_staging() { # a TERM while a function's stdout goes to a staging file: RESULT still reaches stdout, last
  st_env; mkdir -p "$H/bin" || { GOT=fixture-edit; return; }
  for _t in "$SELF_SH" basename cat chmod cksum cmp cp cut dirname find grep head jq locale ls mkdir mktemp mv ps readlink rm sed sort tail tr uname wc; do
    _w=$(command -v "$_t") || { GOT=no-$_t; return; }
    ln -s "$_w" "$H/bin/$_t" || { GOT=fixture-edit; return; }
  done
  _aw=$(command -v awk) || { GOT=no-awk; return; }
  # the shim TERMs the script when awk is handed the answers file (parse_answers, stdout into $ST/answers.rec)
  printf '%s\n' '#!/bin/sh' 'for a; do [ "$a" = "$ST_ANS" ] && [ ! -f "$0.sent" ] && : > "$0.sent" && kill -TERM $PPID; done' 'exec "$ST_AWK" "$@"' > "$H/bin/awk"
  chmod +x "$H/bin/awk" || { GOT=fixture-edit; return; }
  OUT=$(PATH=$H/bin HOME=$H ST_AWK=$_aw ST_ANS=$FIXTURE_DIR/answers/four-fragments.md INIT_PROJECT_PROFILE_DIR=$FIXTURE_DIR/profiles \
    INIT_PROJECT_KNOB_CHANGES=$FIXTURE_DIR/knob-changes/none "$SELF_SH" "$SELF" stamp --target "$T" --answers "$FIXTURE_DIR/answers/four-fragments.md" < /dev/null 2>&1); RC=$?
  [ -f "$H/bin/awk.sent" ] || { GOT=never-interrupted; return; } # the control: the signal came during parse_answers
  [ "$RC" = 2 ] || { GOT=exit$RC; return; }
  [ "$(printf '%s\n' "$OUT" | tail -n 1)" = 'RESULT: stamp stopped (exit 2)' ] || { GOT=no-result-line; return; }
  [ -z "$(find "$T" -type f -print)" ] || { GOT=target-written; return; }
  GOT=result-printed
}

case_fill_prompt_skips_code() { # verify reads a prompt in fenced code or a closed inline code span as prose, as the fill pass does
  st_vbase || return
  printf '%s\n' '' '```md' '*<Fill at init: a fenced example.>*' '```' '' 'Quoted: `*<Fill at init: an inline example.>*`.' '' \
    '*<Fill at init: still to answer.>*' >> "$T/$CONTRACT" || { GOT=fixture-edit; return; }
  _fl=$(wc -l < "$T/$CONTRACT" | tr -d ' ')
  st_verify
  [ "$RC" = 1 ] || { GOT=exit$RC; return; }
  st_has 'CONTROL fill-prompt: known-bad matched 2 — target matched 1' || { GOT=control-or-count; return; }
  st_has "CHECK fill-prompt: FAIL — 1 match(es): $CONTRACT:$_fl" || { GOT=wrong-hits; return; }
  GOT=quoted-skipped
}

cmd_selftest() {
  _exp=$FIXTURE_DIR/expected
  [ -f "$_exp" ] || stop "selftest: $_exp not found"
  SELF_SH=$(ps -o comm= -p $$ 2>/dev/null | sed 's|.*/||; s/^-//')
  case $SELF_SH in sh|dash|bash|ksh|mksh|posh|yash) ;; *) SELF_SH=sh ;; esac
  _k=0; _n=0
  while read -r _case _want; do
    case $_case in ''|'#'*) continue ;; esac
    _n=$((_n + 1)); GOT=unknown-case; ST_KC=; ST_PD=; ST_LOC=; ST_NOPIN=
    _fn=case_$(printf '%s' "$_case" | tr '-' '_')
    case $_case in
      template-every-token|fragment-each-marker|pre-contract-stop|untagged-stop|tracker-github-fresh|\
      rerun-idempotent|knob-added-renamed-retired|held-backlog-core|v1-absent|fill-guard|dest-is-directory|\
      readlist-hand-import|knob-answer-differs|settings-deny-wins|settings-allow-added|settings-in-both|\
      settings-no-rewrite|settings-created-from-baseline|jq-absent|host-setup-idempotent|\
      residue-braces|residue-marker|residue-fill-prompt|residue-fill-prompt-fork-spelling|residue-fork-slot|\
      residue-empty-heading|verify-clean|resolved-load-figure|load-total-not-gated|contract-over-cap|\
      check-same|zone-differs|check-unparsed|after-freeze-fill|silent-stops|fill-prompt-names-all|check-not-run|\
      interrupt-no-temp|locale-pin|fenced-tags|symlink-dest-stop|cdpath-unset|fresh-held-stop|no-final-newline|\
      unlisted-block-kept|rerun-fill-outside|fill-key-typo-rerun|outside-fill-skips-code|fence-closing-rule|\
      fill-heading-renamed-rerun|interrupt-in-staging|fill-prompt-skips-code) "$_fn" ;;
    esac
    if [ "$GOT" = "$_want" ]; then _k=$((_k + 1)); else printf 'SELFTEST %s: expected %s, got %s\n' "$_case" "$_want" "$GOT"; fi
  done < "$_exp"
  printf 'selftest: %s/%s verdicts correct\n' "$_k" "$_n"
  if [ "$_k" = "$_n" ]; then result clean 0; else result failed 1; fi
}

# ---- main ------------------------------------------------------------------------------------------
[ $# -gt 0 ] || usage_stop "no subcommand"
case $1 in
  --help|-h|help) SUB=help; help; exit 0 ;;
  selftest|stamp|verify|check|host-setup) SUB=$1; shift ;;
  *) usage_stop "unknown subcommand $1" ;;
esac
pin_locale
TARGET=; ANSWERS=; AFTER_FREEZE=0
while [ $# -gt 0 ]; do
  case $1 in
    --target) [ "$SUB" != selftest ] && [ "$SUB" != host-setup ] || usage_stop "$SUB takes no --target"
              [ $# -ge 2 ] || usage_stop "--target needs a value"; TARGET=$2; shift 2 ;;
    --answers) [ "$SUB" != selftest ] || usage_stop "selftest takes no --answers"
               [ $# -ge 2 ] || usage_stop "--answers needs a value"; ANSWERS=$2; shift 2 ;;
    --after-freeze) [ "$SUB" = stamp ] || usage_stop "--after-freeze is a stamp flag"; AFTER_FREEZE=1; shift ;;
    *) usage_stop "unknown flag $1" ;;
  esac
done
case $SUB in
  selftest) cmd_selftest ;;
  stamp) cmd_stamp ;;
  verify) cmd_verify ;;
  check) cmd_check ;;
  host-setup) cmd_host_setup ;;
esac
