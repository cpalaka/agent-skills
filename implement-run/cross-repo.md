## Cross-repo gate-runner

Where the session is rooted elsewhere, the Knobs read and every other read of the project contract
in this Skill is the target project's (the paragraph below).

**Cross-repo gate-runner.** A project-local seat resolves only in a session rooted in its project,
and nothing names the cause: working on project X from a session rooted elsewhere, a dispatch of X's
seat returns `Agent type '<name>' not found` — or, unmeasured, reaches a seat of that name your own
project or user scope holds. So the test is never the error: it is the session's root, or, in a
session rooted in X, a seat stamped since the session started. Where X's `gate_runner` knob names a
seat and X's `.claude/agents/<seat>.md` exists, X's contract keeps the gate apart from its judge,
and running the gates yourself would overrule it. Dispatch `general-purpose` instead, with `model`
set to the definition's frontmatter `model:`, its body below the frontmatter verbatim, then the
checkout, whatever else that body asks its prompt to name, and a request to name each path its gates
wrote. `general-purpose` pins no model and would inherit yours. The Agent tool takes no effort, and
`general-purpose` holds tools the definition's `tools:` withholds, so the seat's effort is not kept
and nothing enforces its read-only rule: read the effort off its `agent-<id>.jsonl` (`.effort`), and
before and after it take `git -C <X's checkout>` `rev-parse HEAD`, `status --porcelain` and
`diff HEAD | shasum`. They see X's HEAD, tracked contents and path list — not ignored paths, an
untracked file rewritten, or anything outside X. A change other than an untracked path its report
names as a gate's output is a write: its verdicts do not count, you revert nothing, and the write
goes to the owner (§ Inside a batch). Record under `Deviations` the substitution, the model passed,
the effort read and the before and after reads. A workflow run cannot substitute — its script passes
no `model` and writes its own gate prompt — so a cross-repo run takes `subagents`.
