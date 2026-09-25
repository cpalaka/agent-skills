---
name: implement-batch
description: How the owner's delegate works tickets hands-off — the batch grant, screening before each start, one coordinator dispatch per ticket, the stops it answers and the ones it parks, the batch's end and its record. Slash-only (/implement-batch); a ticket the owner attends runs /implement-run in a fresh session instead.
disable-model-invocation: true
---

Loaded by name, by the owner, from a **fresh session** rooted in the target project; the decisions
are [ADR 0019](../docs/adr/0019-delegated-batch-over-subagent-coordinators.md)'s. Fresh, because a
dispatched seat is handed its parent's session-start instruction hierarchy: an edit made between
session start and kickoff would reach the coordinators stale, while the snapshot, taken at kickoff
(§ Kickoff), never sees it. Two cases are out of scope, and in either you say so and stop. A Codex
host or a headless session (ADR § 10): the transport below is measured only in an attended Claude
Code session, and a dialog needs the owner at its terminal. A project where neither the contract
nor a host adapter imports the `tracker-github` Chunk — the `@` line usually sits in the adapter:
a batch is defined over that Chunk's operations — the frontier query, the claim, the gate labels,
the closing record.

## The delegate

This session is the **delegate**: the main session standing in for the owner across the batch,
defined by that stand-in and never by a ticket count. A batch of one is legitimate, and a single
ticket the owner wants run hands-off runs here. Run on the Builder role, read off the usage tool
and never the model name (the model with its own weekly line is Planner, any other Builder); if
this session is not Builder, ask the owner to switch, and stay on Planner only on their say-so.
You write no diff and run no ticket's procedure yourself: each ticket is one coordinator's, and
you are its reader.

## Kickoff

**The batch grant** is the owner's, given at kickoff before the first dispatch; where they have not
given one, ask. It names:

- (a) the batch's gated writes, its coordinators being the writers (§ The stops) — at minimum
  `gh issue create` for `gate:decide` finding tickets, so no finding goes homeless at Close
  (ADR § 4);
- (b) whether `gate:accept` tickets are in: by default a batch takes `gate:agent` only, and on the
  owner's say-so a `gate:accept` ticket runs to a `Refs` push and is left open;
- (c) a ticket count, where the owner sets one; there is no cap by default. It counts tickets
  dispatched to a coordinator, so a screening park, never dispatched, is not one.

Quote the grant verbatim in every brief; every run record names it under `Slots`. **The grant names
writes and waives no gate**: the verify gate, the bans on force-push and `--no-verify`, and
`git-flow-squash`'s pre-push audit (§ (d): `git log origin/main..main` lists only the
coordinator's squash commit) stay in force — a foreign commit riding the push is still a stop,
since under the grant it would publish someone else's work.

Record three more things at kickoff:

- the meter — the usage window and the Planner role's weekly line — read again before each
  dispatch, because a Planner line read tight ends the batch (§ Batch end); ask the owner now what
  they call tight, where they have not said. A subagent has no usage read, so a coordinator never
  needs one: the `coordinator` definition's pin states its role, and your reading stands for its
  meter;
- the permission mode the session started in, as the owner started it, asking if you do not know
  it: you cannot see a later switch (§ Dialogs), so the record states the mode at start. Where that
  mode prompts, tell the owner now that every dialog — sandbox-off `gh` writes included, if their
  mode asks for them — waits for them, so a Close may stall until they return;
- the snapshot of the run's instruction files, the baseline for § Batch end's mtime stop: run the
  two blocks under **The snapshot** below, the kickoff block first.

**The snapshot** is a (path, mtime) listing of the run's instruction files, kept under the git
directory and never in the tree, so the checkout stays clean. Run each block as written, from
anywhere in the project, in `bash` or `zsh`: both are written for either, and `command find` and
`command grep` bypass any shell function a host puts in their place. Only the kickoff block's
`need` line is yours to fill in, by hand: the contract, then every file it names as a read
(§ Screening's sense), since only a reader tells a read from a reference; a placeholder left in
place, or any path there that does not exist, stops the block. A read that lives outside the
project, such as a Chunk the contract names under `~/.claude/chunks/`, is spelled from `$HOME`,
not `$top`. The other named files are watched
where they exist: `~/.claude/CLAUDE.md`, which the host injects into every seat; the host adapters;
`~/.claude/chunks/`; `~/.claude/agents/`; the project's `.claude/agents/`. The memory index is
not one: every session writes it mid-run by design.

The Skill roots start at `implement-run` and `implement-batch` and close to a fixpoint: a Skill
directory under `~/.claude/skills/` or the project's `.claude/skills/` becomes a root where its name
appears between backticks or slashes, as these files spell a Skill, in a named file or in any file
under a root, and passes repeat until one adds none. The match is a heuristic — a Skill named in
bare prose escapes it, and a directory named only as a path segment is caught — and the roots are
derived rather than listed because a hand list goes stale in silence, while the whole of
`~/.claude/skills/` fires within minutes on writers that are not instructions, such as a
host-managed sync manifest. Hidden directories are pruned throughout: they hold host state. The
block prints the roots and goes red, with a message and a non-zero exit, where `git-flow-squash`,
which `implement-run` names at every Close, is no root: the derivation is broken, and the batch
does not start.

```sh
(
g="$(git rev-parse --absolute-git-dir)" && top="$(git rev-parse --show-toplevel)" || exit 1
rm -f "$g/implement-batch-watch" "$g/implement-batch-snapshot" "$g/implement-batch-now"
# Fill in by hand: the contract, then every file it names as a read.
need=("$top/<contract>" "$top/<read>")
opt=("$HOME/.claude/CLAUDE.md" "$top/CLAUDE.md" "$top/AGENTS.md" "$HOME/.claude/chunks"
  "$HOME/.claude/agents" "$top/.claude/agents")
named=()
for f in "${need[@]}"; do
  [ -e "$f" ] || { echo "implement-batch: no named file $f" >&2; exit 1; }
  named+=("$f")
done
for f in "${opt[@]}"; do [ -e "$f" ] && named+=("$f"); done
roots=("$HOME/.claude/skills/implement-run" "$HOME/.claude/skills/implement-batch")
cands=()
for p in "$HOME/.claude/skills" "$top/.claude/skills"; do
  [ -d "$p" ] || continue
  while IFS= read -r d; do cands+=("$d"); done < <(command find -L "$p" -mindepth 1 \
    -maxdepth 1 -type d ! -name '.*')
done
more=1
while [ "$more" = 1 ]; do
  more=0; text=()
  while IFS= read -r f; do text+=("$f"); done < <(command find -L "${named[@]}" \
    "${roots[@]}" -name '.*' -prune -o -type f -print)
  for d in "${cands[@]}"; do
    printf '%s\n' "${roots[@]}" | command grep -qxF -e "$d" && continue
    command grep -qIE -e '[`/]'"${d##*/}"'[`/]' "${text[@]}" || continue
    roots+=("$d"); more=1
  done
done
printf '%s\n' "${roots[@]}"
printf '%s\n' "${roots[@]}" | command grep -q '/git-flow-squash$' ||
  { echo "implement-batch: git-flow-squash is no root; the derivation is broken" >&2; exit 1; }
printf '%s\n' "${named[@]}" "${roots[@]}" > "$g/implement-batch-watch"
)
```

The snapshot block then runs once to save the baseline, printing its line count, and again before
each dispatch over the same paths — never re-derived, since an edited file ends the batch before a
re-derivation would matter. It lists every regular file under those paths with its mtime, and goes
red on an empty listing.

```sh
(
g="$(git rev-parse --absolute-git-dir)" || exit 1
[ -s "$g/implement-batch-watch" ] || { echo "implement-batch: run the kickoff block" >&2; exit 1; }
st=(-L -c '%Y %n'); command stat -L -f '%m %N' / >/dev/null 2>&1 && st=(-L -f '%m %N')
while IFS= read -r w; do
  command find -L "$w" -name '.*' -prune -o -type f -exec stat "${st[@]}" {} +
done < "$g/implement-batch-watch" | LC_ALL=C sort -u > "$g/implement-batch-now"
[ -s "$g/implement-batch-now" ] || { echo "implement-batch: the snapshot is empty" >&2; exit 1; }
if [ ! -e "$g/implement-batch-snapshot" ]; then
  mv "$g/implement-batch-now" "$g/implement-batch-snapshot"
  wc -l < "$g/implement-batch-snapshot"; exit 0
fi
command diff "$g/implement-batch-snapshot" "$g/implement-batch-now" |
  sed -n 's/^[<>] [0-9]* //p' | awk '{d = $(0); sub(/\/[^\/]*$/, "", d)
  print d "\t" substr($(0), length(d) + 2)}' | LC_ALL=C sort -u |
  awk -F '\t' '$(1) != p {print $(1) "/"; p = $(1)} {print "  " $(2)}'
)
```

A later run prints every path edited, added, deleted or renamed since kickoff, grouped by
directory; no output is a clean reading. The block exits 0 when it prints changed paths too, so
its output is the reading, never its exit status. **Read each path, never count it**: an
instruction file ends the batch (§ Batch end). A file no reader follows as instructions — a
Skill's own results, logs, manifests, generated data, caches, compiled or harness output — is no
stop, and the batch record names it by directory. That is an exception this Skill makes to
`implement-run`'s set, which counts every file under a Skill's directory: the batch-end check
exists to catch text a coordinator will follow.

**The checkout checks**, before every dispatch, the first included: the checkout is on `main`;
`git status --porcelain` is empty; and after `git fetch`, `git rev-list origin/main..main` is empty.
The last tests local `main` ahead of `origin`, not equal to it, so a peer's push cannot false-stop
the batch. At kickoff a failure means the batch does not start: tell the owner. Later it ends the
batch (§ Batch end).

## Screening, before each start

Keep the batch's **parked set**: every ticket parked this batch. Re-derive the frontier with the
tracker Chunk's frontier query, plus its `--label gate:accept` variant where the grant takes those,
with the parked set filtered out before `min_by`: inside the query's array, after its blocker
`select`, insert `select(.number as $n | [<parked numbers>] | index($n) | not)`. The query ends in
`min_by(.number)` and returns one ticket, so excluding afterwards leaves nothing; and a parked
ticket stays open, unassigned and gated, so without the filter every park is followed by a second
park of the same ticket, and two consecutive parks, a screening park counting, end the batch. The
previous coordinator's kickoff line is a cross-check, never the source.

Then read that ticket's live body. Any of these parks it (§ Park) with a comment naming the
defect, the gate label staying the owner's:

- an open question: a choice the body leaves to someone, `gate:decide`-shaped;
- no heading beginning `## Acceptance` (`to-tickets` emits `## Acceptance criteria`);
- among the paths the body names, an instruction file of the run, as `implement-run` § Run profile
  defines one — any file under a Skill's directory, any Chunk or seat definition, the project's
  contract and host adapters, and every file one of those names as a read, where *named as a read*
  means named to be followed as instructions (a Chunk, a Skill, a contract, a seat body, a
  procedure), never a glossary, README, ADR or results record cited for reference — since a run
  that edits one changes the text the next coordinator reads (ADR § 6);
- a criterion only a human can check (a look, a feel, an audible result), which is the owner's
  judgment — unless it has been demoted to a non-gating committed artifact (screenshots, their
  paths recorded on the ticket) **and** an upstream, approved design-reference ticket carries the
  frozen feel verdict.

For ticket authors: convert every human-eye criterion into a machine probe before a ticket enters a
batch — "audio audibly stops" becomes the adapter receiving destroy and the element leaving the
DOM.

## The dispatch and the brief

One `coordinator` dispatch per ticket, by that definition name and with no `model` parameter, at
depth 1, its seats at depth 2; one ticket in flight at a time. If the Agent tool reports the name
not found, stop the batch and tell the owner: a bare spawn would run on your model, unpinned. The
brief carries exactly four things:

1. the ticket reference;
2. the delegation statement, verbatim: `You run this ticket for the owner's delegate: hand back at
   every stop with STOP <kind> and nothing pending; the owner is not present`;
3. the grant, verbatim;
4. the absolute path of `implement-run/SKILL.md`, resolved through the Skill root's symlink
   (`readlink -f ~/.claude/skills/implement-run`, then `/SKILL.md`), so the coordinator reads the
   file the install actually points at.

The coordinator loads the procedure from that path, never through the Skill tool, whose refusal of
a slash-only Skill addresses a session replicating the workflow for itself (ADR § 2). Inside a
batch the run's shape is `subagents` whatever the project's knob says: the Workflow tool is absent
at depth 1, and a pane driven from a subagent is unmeasured. The coordinator hands back at every
stop and, after your Close approval, performs the Close and ends.

## The stops

Two closed sets.

**You answer these**, the delegated stops, and nothing else:

- the plan stop;
- the Close approval;
- the two cap stops: a third fix round, and work past the plan's deliverable count. Each hands back
  as `STOP plan`, since a cap raise is a plan pin, which fires the plan stop (`implement-run`
  § Run profile, Caps);
- a slot-3 need, only after the advisor and only for what the advisor cannot settle; with no
  advisor running, it parks;
- a false premise met mid-run, only where its disposition leaves every acceptance criterion
  satisfied in form with the failed premise named (ADR § 3): after the advisor where one runs;
  where none runs — the `advisor` dial off, as on a light plan, or the advisor unavailable (meter
  spent, no definition, knob `none`) — it reaches you directly as `STOP slot-3`.

So `STOP slot-3` has two preconditions, and the `coordinator` definition carries both: a slot-3
need after the advisor, where one runs; the false-premise disposition alone, where none runs. A
coordinator reading "only after the advisor" alone would park a false premise wherever no advisor
runs.

**Parks**, the owner's stops: a re-cost, meaning any answer that would leave a criterion unticked
or rewritten; any judgment the project's contract reserves to the owner (feel, camera, pose, where
a contract reserves them); a `gate:decide`-shaped question met in a body; a gated write outside the
grant. Every other stop a run meets is the owner's too, and parks.

**A gated write the grant names is no stop**: the grant is its approval. The coordinator is the
writer and performs it — filing a finding ticket at its Close, say — and its run record names it
under `Slots` beside the grant. Your own tracker writes are park comments and claim releases only.

**Read the facts from git and the tracker, never from the report**, by whether the ticket's branch
has commits yet, never by the stop's kind. None yet, as at the usual plan stop: read the live issue,
and the plan and profile block the hand-back carries against it. From the first commit on — every
Close, and every cap stop, which hands back as `STOP plan` after fix rounds — read the diff too,
`git diff main...<branch>` (three dots: the branch against its merge base with `main`), with the
commits and the live issue; at Close, also the draft record and the acceptance reading the
coordinator names. `<branch>` comes from git as well, never from the report: the ticket's branch by
the tracker Chunk's name form `<type>/<n>-<slug>`, found with `git branch --list '*/<n>-*'`.
More than one match — a branch a parked run left for the owner, say — parks the ticket, and the
report never picks between them.

## Hand-back and resume

The coordinator ends its turn with `STOP <plan | close | slot-3 | park>` and what it needs,
**nothing pending**: no seat still running, no background task. A cap stop arrives as `STOP plan`
and a false premise with no advisor running as `STOP slot-3` (§ The stops). Resume it by message
(`SendMessage` to its agent id) with `owner's delegate: <approved | answer | park> — <the SHA or
fact you read from git or the tracker>`: a fact from the tracker while its branch has no commits,
and from the first commit on one read against the diff (§ The stops). `park` tells it to stop the
ticket there, by § Park's mechanics.

## Park

The coordinator acts on git. On `owner's delegate: park` it commits any uncommitted work on its own
branch as a WIP commit — the branch is the owner's to read, and the commit never rides a push —
checks out `main`, confirms `git status --porcelain` is empty, reports the branch and head SHA, and
ends. Then you run § Kickoff's three checkout checks yourself, from git and not the report — a
park raised mid-Close can leave an unpushed squash on local `main`, which a clean tree on `main`
does not show; comment on the ticket naming the stop, what the owner has to decide and the branch
left, if any, writing the body file the tracker Chunk puts inside the repository and removing it
before the next checkout check, which would read it as dirt; release the claim
(`gh issue edit <n> --remove-assignee @me`); leave the gate label untouched; add the ticket to the
parked set; and take the next ticket. A screening park has no coordinator and no claim, so it is the
comment and the parked set alone. A failed checkout check ends the batch.

## Dialogs are never yours, on any transport

ADR § 5; the readings are cpalaka/agent-skills#93's, measured 2026-09-24 on Claude Code 2.1.281:

- A seat's permission request surfaces as a dialog in the owner's main-session UI, labelled with
  the seat's definition name — not the ticket, the depth or the coordinator. It is never
  auto-denied and never routed to the coordinator, so no model in the chain can take it.
- It holds until a key is pressed in that terminal; no timeout was observed, over a hold of 3 min
  47 s. An unattended dialog stalls the batch until the owner returns.
- No model in the chain is told, the coordinator included: it waits on its seat, blind —
  #93 measured the depth-1 relay kept alive, not handed back, while its seat's dialog was open —
  and you have either ended your turn or keep working blind. A quiet coordinator may be held by a
  dialog; silence is no failure and no reason to re-dispatch.
- The answer returns as an ordinary hand-back or tool result, and an approval and a denial are
  indistinguishable in origin (Esc and No gave byte-identical denial text), so never infer the
  owner's answer from the result.
- Nothing in the chain answers a dialog, and the one untested path is forbidden: never send keys or
  text to your own pane through herdr, tmux or any other multiplexer.
- The dialog offers `Yes, and switch to auto mode`. Choosing it moves the rest of the batch out of
  the permission mode it started in; that choice is the owner's, and you cannot see which option
  was taken, so the batch record states the mode the batch started in.
- Under herdr a nested dialog reads `blocked`, the same as a main-session dialog, and `blocked`
  does not mean you have stopped.

## Batch end

No further dispatch after the first of:

- an instruction file in a landed diff: `git diff --name-only` over the squash, against
  § Screening's set;
- an instruction file among the snapshot's changed paths, read before each dispatch (§ Kickoff), so
  no coordinator runs on text a previous ticket changed; a Skill's own output among them is no
  stop, and the record names it by directory;
- a **failed landing check**, run after each Close: `git fetch`, then red on any of three. The tree
  at `origin/main` differs from the reviewed commit (`git diff --quiet <reviewed SHA> origin/main`
  exits non-zero). Local `main` and `origin/main` differ (`git rev-parse main origin/main` — a
  squash whose push failed leaves local `main` equal to the reviewed tree, so local `main` alone
  cannot go red on it). The tracker disagrees: red unless the squash's footer
  (`git log -1 --format=%B <squash>`, `<squash>` being the head of `origin/main` after the fetch,
  read from git and never from the report) is the one the tracker Chunk's § Footer by gate gives
  the ticket's gate label — `gate:agent` → `Closes`, `gate:accept` → `Refs` — **and** the
  issue reads that footer's state: `CLOSED` under `Closes` after a bounded re-read
  (`gh issue view <n> --json state`, up to 6 reads 10 s apart, for the Chunk's close lag), `OPEN`
  under `Refs`;
- a 429 or meter stall, in a coordinator's report or in your own tools, or the Planner role's weekly
  line read tight before a dispatch, tight being the owner's word, which this Skill's § Kickoff
  asks for and `implement-run`'s § Advisor slots leaves to the owner — so no ticket starts on a
  tight line, and a coordinator can spawn the advisor on your read;
- a dirty checkout after a run (`git status --porcelain` non-empty), or any of § Kickoff's checkout
  checks failing before a dispatch;
- two consecutive parks, screening parks included: every park counts;
- the host usage tool's window at 80%;
- the owner's count reached, counting dispatched tickets only (§ Kickoff);
- an empty frontier.

## The batch record

Chat only, never a tracker write: the landed tickets with their squash SHAs, each closed or left
open for the owner's acceptance; the parked tickets with their reasons; the findings filed, by
issue number; the usage window at start and end; the permission mode at start; the Skill outputs
the snapshot showed, by directory; the reason the batch ended; `git worktree list`.

## herdr, the named fallback

Where live takeover is wanted, a ticket is Codex-hosted, or a crash kills a coordinator
unrecoverably, drive that ticket through a herdr pane instead, following the herdr section of
`multi-agent-policy`'s `COORDINATOR-PANE.md`, read only where that Skill's directory exists under
`~/.claude/skills` or `~/.agents/skills`; without it, park the ticket. The pane child's prompt
carries the brief's four items, so the child knows it runs for you; answer in the pane exactly the
stops § The stops gives you, and park the rest. Every `blocked` pane and every dialog there stays
the owner's (§ Dialogs).
