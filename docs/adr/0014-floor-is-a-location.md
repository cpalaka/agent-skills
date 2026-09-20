# The floor is a location: `chunks/` holds always-on rules only, and a situational body is a Skill

**Status:** accepted — 2026-09-19. Amends [ADR 0001](0001-import-from-home-chunk-delivery.md) on
what a Chunk may contain and [ADR 0009](0009-init-project-emits-contract-and-two-adapters.md) on
what the Claude adapter imports. [ADR 0013](0013-retire-unused-chunks.md)'s `fork:` key survives
with a different delivery.

**The measurement.** A session in a stamped godot project pays, on every turn, the global
instruction file, the host adapter, the project contract and nine Chunks: **16,763 words**
(2026-09-19, `wc -w`; the source handoff summed the same rows to 20,223, which is an arithmetic
error), about 110 KB, about 27k tokens. Every seat an implementation run dispatches inherits the
same hierarchy: a haiku subagent told to read nothing measured **70,623 tokens** before its first
tool call in that project, and **49,558** in this repository, where the external imports were not
in effect and it received no Chunk at all. So the Chunks are roughly a third of what a seat costs;
the rest is the host's own system prompt, tool schemas and skill roster, which nothing here can
cut. Of the 16.8k words, the contract was 7.1k and the nine Chunks 7.0k, and most of both was
explanation: measured-failure stories, calibration records, the reasoning behind a rule. The
library had drifted from the principle its own global file states, that always-loaded text is the
last resort and a lesson goes to the Skill that loads when needed.

**Decision.**

1. **A Chunk is always-on by definition.** `chunks/` holds only the rules that must bind a
   session or a seat *before any Skill could fire*: sync `main` then branch at task start
   (`git-sync-branch-start`), the commit subject and body shape (`git-commit-format`), the human
   git gates (`git-confirm-destructive`) and the five verify-gate step names plus the
   no-undeclared-dependencies rule (`verify-gate`). Each is condensed to its load-bearing rules,
   in the region of 60 to 100 words, with a one-line pointer to the Skill that now holds the
   detail it shed. `dev-base` bundles these four. The tracker Chunks (`backlog-core`,
   `tracker-github`) stay Chunks: they are always-on for the projects that import them.
2. **A body that fires on a signal is a Personal skill, not a Chunk.** `implement-run` (an
   implementation run), `parallel-work` (the explicit parallel-work signal) and `git-flow-squash`
   (integration and merge) each become a Skill directory in this repository, symlinked into both
   host roots like every other Personal skill, and the chunk file is deleted rather than left
   beside its successor. The `implement-run` Skill keeps that name: the third-party `/implement`
   stub installed on the author's machines is not edited, shadowed or wrapped. Their knob blocks
   stay where they are in every contract; the Skills read them by marker exactly as the Chunks
   did.
3. **Two Chunks retire.** `sandbox-auto`'s one rule (sandbox on, `auto` mode) is already the
   adapter Template's "Session baseline" bullet; its settings shape and recovery move to
   `sandbox-and-permissions` and `codex-sandbox-and-approvals`. `dev-practice`'s "invoke a Skill
   that holds knowledge you don't" sentence moves to the adapter Template; its two named loops
   die with the file, no run record having shown either firing; its knob block is removed from
   every contract.
4. **Routing is location.** No header field, no manifest: a file in `chunks/` is always-on, a
   Skill directory is situational, a seat file is seat-owned. `dev-base` membership is the
   always-on list, which is what the engine already derives the Codex read list from, so the
   engine does not change for this.
5. **The `fork:` key names a Skill.** The engine emits it into both adapters' skill lists
   (`/git-flow-squash` fires from context on Claude Code, `$git-flow-squash` is listed for Codex)
   instead of an `@` import line. The Claude adapter's import block becomes `dev-base`, then each
   `imports` entry, then the contract.
6. **An evicted measured-failure story goes to the Skill that fires on that failure**, else it is
   cut and the rule keeps a dated citation; git history is the archive. No `docs/results/` corpus
   here, and no edit to an accepted ADR to house one.
7. **The floor has a ceiling.** A project's floor on the Claude host — adapter, contract,
   `dev-base` and the four Chunks — is under **2,500 words**, with the global file and the tracker
   Chunk excluded and each reported beside it; that number is the acceptance for the tickets
   under this decision, by `wc -w`. The tracker Chunks (1,703 and 1,853 words) are always-on and
   not condensed here, so a ceiling that counted them could not be reached by condensing what
   this decision condenses. The seat probe is re-run and reported as a delta with the host floor
   named beside it, never as a target, because the residual is the host's and would otherwise be
   read as a failure. **The check stands after the tickets close:** this repository's contract
   gains a `wc -w` gate over `chunks/` beside the leak-guard scan, because the Problem this
   decision answers is that nothing warned while the floor grew.

**Considered options.**

- **A routing value per chunk header** (`always-on | skill | seat`), the source handoff's
  proposal. Rejected: nothing reads chunk headers, so it is a second store of a fact the file's
  location already states, and it goes stale in silence the way every unread list here has.
- **A manifest the engine reads to emit only always-on imports.** Rejected: machinery for a list
  of four, and `dev-base` is that manifest already.
- **One merged Chunk, `dev-base` holding all four rule groups as sections.** Rejected: ten
  projects' `AGENTS.md` read lists and three other Chunks cite the four by file name, and
  `verify-gate` cites `git-flow-squash § (a)`; a read list of one file also loses the count a
  Codex reader uses to tell a short read from a complete one.
- **A Personal skill named `implement`, shadowing the third-party stub.** Rejected by the owner:
  the name is a channel-installed skill's, `skill-updater` holds a registry row for it, and a
  distinct name costs one re-pointing sweep, once.
- **`omitClaudeMd: true` on every seat**, which Claude Code documents as removing the whole
  CLAUDE.md hierarchy from a custom subagent. Neither adopted nor rejected here: it is unverified
  on this machine, it is orthogonal (this ADR governs what the hierarchy contains, that flag
  governs whether a seat receives it at all), and a seat that silently lost the git gates is the
  failure class the library exists to catch. A precursor ticket measures it with a flagged seat
  and a flagless twin; adoption is a follow-on decided on the numbers.

**Consequences.**

- **Every importer's Codex read list goes stale the moment the chunk files are deleted**, because
  each `AGENTS.md` enumerates the nine by name. One sweep ticket in this repository re-derives
  the list in each importer on this machine (nine, grep-derived, listed in the ticket body),
  removes each dead `dev-practice` knob block, and re-points every live reference to
  `implement-run` as a Chunk (the global instruction file among them, reference edits only). The
  other machine's clones receive the edits on pull; the scope is stated as ADR 0013 stated its
  own.
- **The chunk edits land in one squash from a worktree**, per this repository's contract: the
  checkout is the install, and a half-rewritten library is live in every project the moment it
  touches disk.
- `git-flow-squash`'s **(a)** to **(d)** labels survive the move unchanged, for the citations
  ADR 0013 lists.
- **The gate-runner Template shrinks** to its commands with the rest pointed at the contract, and
  the godot Profile's gate-runner fragment, which is where the fail-open predicates live, keeps
  those and sheds the rest; the three seats under `~/.claude/agents` are already short and are
  not touched. `verification-discipline` and `godot-gotchas` are read on a trigger, not on
  every turn, and are a separate audit.
- **The global instruction file is out of scope.** It has its own procedure (`context-hygiene`)
  and its pass follows once the Chunks demonstrate the shape.
- **A stamped project's contract is its own ticket in that project**, under the same principle:
  keep every knob line and rule, move each measurement and calibration paragraph to the
  `docs/results/` owner that project already keeps. 3d-anim-lab's goes from 7.1k words to under
  1.6k.
- `README.md`'s Chunk table is derived from `chunks/` and re-derives to seven rows.
- `CONTEXT.md` gains **floor** and amends **Chunk** and **dev-base**.
