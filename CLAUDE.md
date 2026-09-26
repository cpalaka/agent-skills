# CLAUDE.md — agent-skills

Operating notes for working **in this repo**. For what each Skill is and how to install one, see
[`README.md`](README.md). For the vocabulary (Skill, Chunk, Template, Profile, knob, inline-leaf,
…) read [`CONTEXT.md`](CONTEXT.md) — it is not auto-loaded. Check [`docs/adr/`](docs/adr/) when a
decision in your area may already be settled.

This repository runs its own tickets under the same procedure it ships. **The procedure itself is
not imported**: `implement-run` is a Skill, slash-only, so a run loads it by name and a session
that never starts one never carries it. One import is named here — this repository's own contract,
hand-written rather than engine-stamped, which says why:

@docs/agents/project-workflow.md

That is an external import, so it needs this project's one-time approval on a fresh session
before it expands ([ADR 0001](docs/adr/0001-import-from-home-chunk-delivery.md)); until then the
line is inert text, which looks identical to a loaded import. **A dispatched seat is handed its
parent's memoized hierarchy**, not a fresh walk — which is why #37's seats read the Chunk absent
(their parent predated approval) while seven seats here received both hops, and why one
dispatched after an edit was handed the paragraph that edit removed. Measured at the harness's
own delivery record (#35). The seat boundary was never the variable.

So a seat need not re-open the contract or the Chunk — but **check, and know what the check
cannot tell you.** The block's presence (the contract's § Issue tracker test; if you cannot reach
that file, absence is your answer) says the import expanded, never that it is fresh: the copy is
the parent's session-start snapshot, so read disk for anything touching an edit made since.
Reading absent, suspect approval first, a walk memoized before it second, the boundary last.
Two things reached no payload: the `implement-run` Skill, which a seat needing the procedure
opens itself, and block-level HTML comments — so a `<!-- knobs:… -->` marker *line* is disk-only (the string still arrives
inline, inside a code span).

## Load-bearing facts

**Editing a file here is live.** This clone is usually also the install: entries under
`~/.claude/skills` and `~/.agents/skills` symlink *into* it, and `~/.claude/chunks` /
`~/.codex/chunks` point at `chunks/`. A change to a `SKILL.md`, a Chunk, or a host adapter changes
what the agent reads immediately — there is no install step, so verify a change in every affected
host rather than by re-reading the file. The same mechanism applies on the git side: **the
checkout is the install**, so leaving the working tree on a ref that lacks a Skill directory
silently breaks that Skill with no error. Do ref surgery in a temporary worktree.

**The hooks are opt-in per clone.** `git config core.hooksPath .githooks` arms both of them, and
that is local config, not tracked — a fresh clone has neither until someone sets it.

- **`leak-guard`** (`pre-commit`, `commit-msg`, `pre-push`, plus a `scan` mode for the whole tree)
  blocks personal provenance from entering a public repository. It runs two pattern sources: a
  built-in, identity-free list that ships here, and an **identity list that does not** — the
  author's names, machine names and private project names. The guard finds that file through
  `AGENT_SKILLS_IDENTITY_FILE`, defaulting to `~/.config/agent-skills/identity-patterns`. If it is
  missing, the hook modes still run the built-in list but warn loudly, and `scan` **fails**
  outright, because an import audit on the built-in list alone certifies nothing. A contributor
  who has no such file will see that warning; it is expected, not a misconfiguration. **The
  guard sees only the git object store.** An issue body or comment written with `gh` on this
  public repository is never scanned, so grep the body file against both pattern lists before
  any `gh` write (39 identity hits landed in three public issues on 2026-09-17 that way).
  **Screen it through the guard rather than a hand-rolled grep** — copy the body into the tree,
  `scan`, delete — where **into the tree means a path the scan walks**: `scan` skips every
  gitignored path, so a body drafted in `.scratch/` returns `scan clean` whatever it contains
  (measured 2026-09-19, a planted known-bad there: `scan clean` over 156 files, exit 0; the same
  file at the repo root returned 2) — and plant the configured git author name first, which the guard blocks by each
  of its parts, so the list is known live before a clean result is believed. A `grep -f` over that
  file can apply none of its patterns and prints exactly what a clean body prints
  (`verification-discipline` § Prove the needle first; measured again 2026-09-18).
  **The likeliest hit is the sentence reporting the calibration**, not the technical content: a run
  record that says which known-bad was planted names an identity string to say it. Plant the canary
  *beside* the draft bodies in one scan, so a single run proves the list live and the bodies clean —
  and read the match *count*, since the exit status cannot separate your canary from a real hit
  (2026-09-18: four run-record bodies, one templated calibration sentence, `5 match(es)` where 1
  was expected) — and wire that count to the write: the `gh` call runs inside a test of the
  count, never `&&`-chained after a printed one (2026-09-19: a body at three matches went up on
  #44 that way). The shape is `out="$(scan)"; n="$(printf '%s' "$out" | grep -c BLOCKED)";
  [ "$n" = 1 ] && gh …` — a test, not an `echo` of the count. Write it as "a known-bad drawn from
  the configured author's name", never the literal.
  **A calibration that plants a pattern's own text certifies nothing.** The identity entries
  reach `grep -E` as regexes and 43 of the 48 do not match their own text, so planting one raw
  read `scan clean` over the tree holding it (measured 2026-09-17 gating issue #4). A known-bad
  that fires has to be a string the regex *matches*: strip `\b`, take an alternation's first
  branch, and confirm the candidate with `grep -iqE -e <pattern>` before planting it.
- **the backstop** (`post-checkout`, `post-merge`) warns when a checkout or merge leaves the tree
  behind `main`, for the checkout-is-the-install reason above. Neither hook can fail a checkout or
  a merge, and neither catches a lost uncommitted edit — they diff after the fact.

**Exemptions are an owner decision.** `.leak-guard-allow` takes one `<path>:<literal>` pair per
line with a required reason, never a line number. It starts empty and should stay that way; an
entry is a per-line judgment, not a way to turn a red scan green.

**Commits here carry no attribution and no session trailer.** `.claude/settings.json` is tracked
on purpose and sets `attribution.commit` and `attribution.pr` empty and `attribution.sessionUrl`
false, so the policy holds on any machine rather than depending on one user's settings. The
`commit-msg` hook strips a `Claude-Session` trailer that arrives anyway and warns — a stripped
trailer is a regression signal, not a failed commit — and `pre-push` blocks one already committed.
Check `git log -1 --format=%B` after the first commit in a fresh clone.

**Everything here without a `PROVENANCE.md` is hand-authored.** A directory carrying one is a
vendored third-party body kept here because its upstream ships no install channel
([ADR 0007](docs/adr/0007-vendor-unchanneled-third-party-skills.md)); its `PROVENANCE.md` lists
local edits that a manual upstream sync must re-apply. Today that is `unslop/` alone.

**Chunk vs Template.** A **Chunk** (`chunks/`) is single-source and referenced — editing it
updates every consuming project at next launch. A **Template** is *copied* into a project at init
and thereafter drifts: `init-project/templates/` holds the four files every Profile emits, which
no parity check reads at all, and `init-project/profiles/<type>/templates/` a Profile's own
assets, only some of which one does. Know which you are editing; `CONTEXT.md` has the
discriminator and the coverage.

**The `init-project` engine is generic.** Adding a project type means adding a
`profiles/<type>.md` Profile — plus, where the type has host specifics, its four `adapters:`
fragments — never editing the engine
([ADR 0003](docs/adr/0003-single-init-project-engine.md)). Every Profile emits the same four
files: the shared contract, two thin host adapters over it
([ADR 0009](docs/adr/0009-init-project-emits-contract-and-two-adapters.md)), and the project's
gate-runner seat ([ADR 0011](docs/adr/0011-roles-not-cost-tiers.md)).

**No public artifact may hard-require a private one.** Where a body calls a Skill that may not be
installed, the reference is existence-gated on the Skill's directory existing under *either*
`~/.claude/skills` *or* `~/.agents/skills` — Claude Code and Codex resolve Skills through
different roots, so a gate on one silently skips the step for the other host's users. The step
skips when the gate fails; it never errors.

**A private companion repo exists.** The author keeps Skills that are only meaningful on their own
machines in a separate private repository; it installs the same way, one symlink per Skill per
host, and nothing here depends on it ([ADR 0008](docs/adr/0008-public-private-split-by-audience.md)).

## Conventions

- Renaming or retiring a Skill means updating every live reference (other Skills, `README.md`,
  `CONTEXT.md`, the `init-project` Templates and Profiles) and re-pointing its
  `~/.claude/skills` / `~/.agents/skills` symlinks. Leave historical records alone — an ADR
  records what was decided when, and rewriting it to chase a rename destroys the record.
- `README.md`'s Skill roster is **derived** from the directories present, not stored. Re-derive it
  rather than editing a line.
- Both bootstrap scripts take the clone location from their own path. Nothing here may assume
  where the clone lives.
- Run `.githooks/leak-guard.sh scan` before a push you care about, not only on the hook path.
- **Never write a rule as a list of exemptions — name the gated set and relax the rest.** An
  enumerated "these are exempt" sentence sits far from the clauses that add members, nothing
  couples the two, and it goes stale in silence. In one ticket the same sentence inverted its own
  polarity, then excluded the very operation it existed to exempt, then missed one added a line
  below it, and an enumeration found four more — each caught by a different reader, none by a
  check. A small closed gated set survives a clause being added; an allowlist does not. Where one
  already exists, the cheap guard is a grep that enumerates the operations the body instructs and
  asserts each is named on one side or the other.
- **A governing sentence still needs a pointer at each clause it governs.** The predicate above
  is read by whoever reads a Chunk top to bottom and by nobody who arrives at one clause cited
  from another file, and for them a missing pointer degrades not to the governing rule but to
  nothing, leaving the clause reading as a direct instruction. Measured on #26: a seat that had the
  predicate in hand applied it to one clause and not the next. A pointer carrying the destination
  and no part of the resolution costs a wasted detour when stale, never a wrong answer, so it is
  not a second store of the rule. **Never enumerate the citing clauses in this bullet** — the
  enumeration that used to sit here went stale on #47, when `verify-gate` stopped citing
  `git-flow-squash` § (a) and started pointing at the Skill to load at integration instead.
  Derive membership instead — per lettered clause, the marker set must equal the governed-noun hit
  set, so it is a command's output rather than a judgment that accretes exceptions. For
  `git-flow-squash`, whose governing sentence defers task ids, the board, Done-marking and
  the notes to the tracker chunk:

  ```sh
  awk '/^\*\*\([a-z]\)/{c=substr($0,1,5)} c&&/task id|task-NNN|backlog|notes|Done/{n[c]=1}
       c&&/resolves this/{m[c]=1} END{for(k in n) print (k in m?"ok  ":"GAP ") k}' \
      git-flow-squash/SKILL.md | sort
  ```

  **Calibrate before believing a clean run** — strip one marker, or append a clause naming a
  governed noun; both were measured to report `GAP` (#47). `grep -rn '§ ('` finds *citations*, not
  markers, and as of #47 returns no `chunks/` hit at all, so it can never perform this derivation;
  it is the census that bounds a **renumber** instead — one citing consumer is outside this
  repository and no grep here can see it, so a clause letter is never renumbered on an in-repo
  count alone.
