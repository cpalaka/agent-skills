# Provenance — `unslop`

**This skill is not hand-authored.** It is a vendored third-party body living at the repo root
alongside the authored skills, which is an exception to the repo's usual invariant. See
[ADR 0007](../docs/adr/0007-vendor-unchanneled-third-party-skills.md) for why.

## Upstream

- Source: <https://github.com/cursor/plugins/tree/main/pstack/skills/unslop>
- Plugin: `pstack` v0.14.1, by Lauren Tan. MIT.
- Pinned commit: `60c641e4fad674784b30abcf9f8915dea39df38d`
- Vendored: 2026-08-19
- Licence: MIT. The upstream notice is reproduced verbatim in [`LICENSE`](./LICENSE) beside this
  file — copyright Lauren Tan. Upstream keeps it at `pstack/LICENSE`, not at the repo root, so
  copy it from there on a sync. The repo-root `LICENSE` covers everything else and points here.

`cursor/plugins` ships `.cursor-plugin/plugin.json` and **no** `.claude-plugin/marketplace.json`, so
`claude plugin marketplace add cursor/plugins` fails and the plugin CLI can never resolve it. The
skill body is nonetheless plain `SKILL.md` + YAML frontmatter and loads unmodified in both hosts.
There is no `npx skills` channel for it either. Hence a hand-managed copy.

## Local modifications — re-apply after any upstream sync

1. **`description:` rewritten.** Upstream reads `Cut AI tells from any writing. Must always apply.`
   "Must always apply" is a Cursor always-rule idiom with no meaning in Claude Code or Codex; all it
   does here is make the skill match aggressively on prose that is not a writing task. Replaced with
   an explicit trigger list and a "not for code, logs, or terminal replies" exclusion.
2. **Rule 13 (em dashes) relaxed.** Upstream bans em dashes outright and forbids parentheses as a
   substitute. The user's ruling: em dashes are permitted; the tell is frequency and reflex, not the
   mark. Rewritten as an overuse rule (2+ per paragraph, or one per bullet) and marked `LOCAL EDIT`
   inline so a future sync does not silently revert it.
3. **Rule 16 (inline-header lists) narrowed — keep lists.** `LOCAL EDIT (2026-08-25)` inline.
   Upstream's rule reads as licence to flatten lists into prose; the user's ruling is that it targets
   one bullet *shape* (the bold label that restates its own line), not list structure. Genuinely
   enumerable content — steps, arithmetic chains, timelines, term glossaries — stays as bullets.
   **This one was missing from this list until 2026-08-31**, which meant the update procedure below
   would have silently reverted it. The rule's closing clause reads "The user prefers bullets for
   scannability"; a sync must not restore the author's name there.
4. **Rule 32 (no honesty performatives) added — net-new, not upstream.** `LOCAL EDIT (2026-08-31)`
   inline. The user edits honesty meta-commentary out of decision docs ("honestly", "the honest
   read", "stated plainly", "no softening"); a document that announces its own candor reads as
   protesting too much. Observed on a concept edit pass (measured 2026-08-27). Relocated into this
   skill from a project's memory store, where it fired on nothing else.

## Updating

`skill-updater` does **not** track this — it only refreshes the plugin and `~/.agents` channels, and
this body is in neither. Update by hand:

```bash
curl -sL https://github.com/cursor/plugins/archive/refs/heads/main.tar.gz | tar xz -C "$TMPDIR"
diff -u unslop/SKILL.md "$TMPDIR"/plugins-main/pstack/skills/unslop/SKILL.md
```

Review the diff, copy forward what you want, then re-apply **every** local modification listed
above — check the list, do not work from memory of how many there are — and bump the pinned commit
in this file. Second check: `grep -n 'LOCAL EDIT' SKILL.md` should return the rule-body edits (13,
16, 32 as of 2026-08-31). It returns one fewer than the list, because item 1 is a frontmatter
`description:` rewrite and carries no inline marker — that is the expected gap, not a miss.

## Replaces

`english-humanizer` (kambleakash0/agent-skills), whose descriptions collided with this one and made
routing between them a coin-flip. Its `~/.claude/skills` symlink was removed on 2026-08-19.
