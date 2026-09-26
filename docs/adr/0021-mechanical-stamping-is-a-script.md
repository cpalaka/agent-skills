# Mechanical stamping is a script; prose keeps judgment

**Status:** accepted — 2026-09-25. Amends [ADR 0016](0016-floor-ceiling-is-acceptance-time.md)
§ 4, on where an adapter-plus-contract budget would belong. Everything else there stands: § 4's
refusal to install such a gate and the disqualifiers behind it, and §§ 1–3 and 5–7 whole.

## Context

`init-project`'s mechanical steps — copy a Template, substitute a token, insert a fragment at a
marker, union an allowlist, grep for residue — were prose a seat performed by hand, and #63 is the
list of what that cost: a re-run re-widened an allowlist a project had deliberately narrowed; an
engine Template asserted a fact only one Profile writes; the engine's enumeration of its own fill
prompts was short by one; a size gate stayed green while the contract it pointed at reached 47,873
bytes (2026-09-21); and the absence checks had no control, so a wrong grep read exactly like a
clean one. Templates are skip-if-exists and every marker was consumed on insertion, so no fix
reached a project already stamped, and nothing could locate what the engine wrote there. Spec #124
measured the Skill at 7,473 words, with eleven projects on this machine importing the Chunk library.

## Decision

1. **The mechanical subset is one executable, `init-project/scripts/engine.sh`**: POSIX `sh` and
   the system `awk`, UTF-8 pinned inside it, finding its Templates and Profiles from its own
   physical path so it resolves through either host's Skill root. Five subcommands — `selftest`,
   `stamp`, `verify`, `check`, `host-setup` — and `--help` as its manual. **The prose keeps
   judgment**: the interview, the knob values, the fills, every `gh` write, the handoff and the
   adoption commit. Values cross in one answers file the prose writes in the knob-block shape; the
   script synthesises none, and a knob key with neither an answer nor a literal Profile value is a
   stop.
2. **Zone tags.** Every engine zone a stamp writes sits between `<!-- zone:<name> -->` and
   `<!-- /zone:<name> -->`, each tag alone on its line; the `<!-- knobs:<id> -->` pair is the
   existing instance of the pattern and keeps its spelling. Each `<!-- profile:<m> -->` marker
   becomes a zone holding the Profile's fragment, empty where it has none. The gate-runner seat's
   frontmatter is the one untagged zone, bounded by its `---` fences because a comment above
   frontmatter breaks it, and counts only in a file carrying a tag. A re-run replaces what lies
   between each pair the target carries and nothing outside one; a zone the target does not tag
   reads `absent` and is not inserted, since no boundary is guessed. A **v1 stamp** — any stamp
   before the script — tags its knob blocks only, so its other zones read `absent`, never
   refreshed or compared. A tag inside fenced code is prose, never a tag.
   **The one write outside a zone** a re-run makes is a fill: where a file already in the target
   still carries a `*<Fill at init …>*` prompt outside every zone and the answers file gives its
   `fill:<dest>#<heading>`, exactly that span is replaced (`FILLED <dest>#<heading>`), so adding a
   fill and stamping again converges; a prompt inside fenced code, or inside an inline code span
   closed on the same line, is prose, never filled. On a re-run, a fill key for a file already in
   the target that fills no prompt there is a `NOTE` where its heading is in that file, its render
   or its source Template, and a stop, as on a fresh stamp, where the heading is in none of them —
   so an answered prompt, or a heading renamed since, is never a silent drop and never a stop.
3. **Knob blocks keep every existing value.** A re-run changes only the key set: a respelling
   (`-`, `_` and space match), the renames and retirements declared in `scripts/knob-changes`, a
   key the Profile adds. A key the Profile does not list and no `retire` row names is the
   project's own and is kept. **A block is deleted only where `knob-changes` declares it** with a
   `retire-block <chunk-id>` row: any other block the Profile (for type `none`, the answers file)
   does not list — a hand-imported Chunk's, or one a meta-only answers file does not repeat — is
   kept verbatim and reported, and `check` reads it `orphan`, not drift; a declared-retired block
   still present reads `differs`. `check` compares a block by key set and shape, never by value.
4. **`jq` for the settings merge only.** `permissions.deny` wins over a Profile `allow` entry, an
   entry already in both is reported and left, and the file is rewritten only on a semantic delta.
   `jq` missing is a stop naming the install command, never a fallback.
5. **Exit 0 clean, 1 a gate or check failed, 2 a stop**, in fixed stdout line shapes the seat
   quotes. Rendering and validation finish in staging before the first write, and each write is a
   temp file beside its destination renamed over it, so a failed run leaves each file untouched or
   complete and recovery is a re-run. The script never runs `gh` and never writes a host state
   file; only `host-setup` writes outside the target, each line with its undo.
6. **The load total is reported, never gated** (#60, ADR 0016 § 4). The per-file caps stay gates —
   32 KiB for each adapter, 16 KiB for the contract, per file, never per pair — and `verify`
   reports each host's resolved load per file and as a total that never moves the exit code.
   **No adapter-plus-contract budget is installed, at stamp time or in this repository.** That
   retires § 4's hypothesis that "the budget is a Profile's to declare in the shape
   [ADR 0010](0010-fragment-bullets-declare-their-targets.md) already uses for fragment targets":
   #60 decided report-only at triage, and 0010 is superseded by
   [ADR 0020](0020-migrate-retired.md).

## Considered options

- **Keep the prose procedure.** Rejected: #63 is its measured cost, and prose could not find what
  it wrote in a stamped project, so no fix reached one.
- **A rewrite in another language.** Rejected: #124 is a prune and a rework, not a rewrite, and a
  stamp must not depend on a runtime the machine may lack. `jq` is required for the one JSON step.
- **Gate the total.** Rejected at #60's triage and by 0016 § 4, which disqualified each candidate
  at the trigger it would fire on: a stamp-time gate on any absolute number is red on day zero for
  the live basis; the number it would gate is not measurable from here, since fill-ins are
  unbounded and assemblies disagree by 10%; and 1,820 itself is the diagnosed shape.

## Consequences

- **The total never moves the exit code.** A 48 KB contract exits 1 through its own per-file gate;
  a fixture with every file under its cap and a large total exits 0. The selftest cases
  `contract-over-cap` and `load-total-not-gated` pin each.
- **`verify` does not run the verify-gate.** It prints `VERIFY-GATE: NOT RUN by this script` and
  leaves that run to the seat, from the contract's knob block, as step 7 does — the reading taken
  of #124's "the `verify-gate` run as today".
- **A key renamed in a Profile makes a stale answers key a stop** (`answers key <id>.<key> is not
  in the Profile block`) until the answers file follows; the contract's value moves under the
  `rename` row.
- **This repository's gates gain the selftest** for any diff touching `init-project/`.
- **The Skill's prose is not rewritten here**: `init-project/SKILL.md` gains one pointer, and its
  steps still describe the mechanics by hand until #127.

**Known limits, handed on:**

1. godot's recipe edits text inside its contract fragment per project (the Blender bullet, the
   no-`godot-ai` edits); such a project reads `differs` on `check`, and a re-run restores the text.
   #127 decides.
2. `after_freeze:` is read, but no live Profile carries it yet, so `stamp` writes godot's
   `.mcp.json` and `.codex/config.toml` with the rest (#127).
3. The Linux half — GNU `awk`, glibc locale names, `jq` there — is unmeasured until that machine is
   online.
4. The canary zone's close tag is now an adapter's last line, while `SKILL.md` still calls the
   canary the last line (#127).
5. A live v1 knob block carrying a prose line reads `unparsed` on `check` and stops a re-run
   `stamp`: text the script cannot parse is never rewritten.
6. A shape inside a literal Profile value (web's `secret_scan`) passes through as a literal; the
   prose has to answer it.
7. An owner's fill inside a zone is never read back from the target, and nothing persists the
   answers file: unless the answers file given to a later run repeats that fill, `check` reads the
   zone `differs` and a re-run `stamp` stops on the D8 fill guard (#127).
8. A re-run takes the type from the answers file, never from the target, so a wrong type refreshes
   the fragment zones to that type's fragments (to empty zones, for `none`) and applies its knob
   key set, without a stop (#127).
9. The inline-code-span reading is one line at a time: a span that wraps onto a second line and
   quotes a `*<Fill at init …>*` prompt is filled on a re-run, and `verify`'s fill-prompt check
   counts it. A follow-up ticket owns it.
