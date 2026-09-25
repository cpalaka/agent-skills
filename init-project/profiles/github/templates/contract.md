## Issue tracker

Work is tracked as **GitHub issues** on the repository named by the `REPO` knob above, driven by the
`gh` CLI. Two pointers, both host-neutral, and both worth reading **before you file, claim or close
an issue** rather than after:

- **`docs/agents/issue-tracker.md`** — how the tracker is driven from an agent session: the create,
  fetch and list commands, the native flags for parent and blocked-by relations, the body-file rule
  and where the body file goes, and whether external PRs are a request surface here. It is also the
  path skills look up when they need this project's tracker (code-review's Spec axis, triage,
  to-tickets, wayfinder).
- **`docs/agents/triage-labels.md`** — the map from the triage roles skills speak in to this
  tracker's labels, so a skill applies the label this repository actually holds instead of minting
  one of its own.

The convention itself — the two label axes, parents and relations, the frontier and the claim, the
footer chosen by gate label, the closing record and the rule that a body is never rewritten for
state — is the **`tracker-github`** chunk, which your host adapter loads. Neither pointer above
restates it, and this section adds the frontier-empty instruction below. `RESULTS_DIR` above
says where a `gate:accept` ticket's result note goes, or `none` for comments only.

**Frontier empty.** This is the frontier-empty instruction `implement-run`'s kickoff reads; inside a
batch, the kickoff keeps to the batch's grant. Where the chunk's frontier query returns nothing, run
its label check first: a missing label is the chunk's stop, reported to the owner. With every label
present, run the same query with `--label gate:accept` in place of `gate:agent`. Its lowest takes
the kickoff, since a session works a `gate:accept` ticket and the owner accepts it. Where that is
empty too, say that nothing workable remains.

**Before you claim something is absent, check the tracker.** `gh issue list --state all -L 200` to
see what exists, then `gh issue view <n>` on the issue that would own the thing you are about to
call missing. **"Nothing owns this" is a claim that needs a search behind it, not an impression** —
the tracker first, then `docs/`, then the repo's own notes. `gh issue list` lags a fresh creation
and truncates silently (the chunk's § Task tracking), so a just-filed issue may be missing from the
list while `gh issue view <n>` returns it: confirm by number, never by absence from a list.
