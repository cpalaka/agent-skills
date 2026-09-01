# agent-skills

Reusable Skills for Claude Code and Codex, plus the Chunk library and the `init-project` engine
that go with them.

This is a stub. The full README — what each Skill does, and how to install one — lands with the
import.

## Setting up a clone

Git hooks are opt-in per clone, so run this once after cloning:

```sh
git config core.hooksPath .githooks
```

That arms two things:

- **`leak-guard`** (`pre-commit`, `commit-msg`, `pre-push`) — blocks content that does not belong
  in a public repository. Run `.githooks/leak-guard.sh scan` by hand to audit the whole tree.
- **the backstop** (`post-checkout`, `post-merge`) — warns when a checkout or merge leaves the
  working tree behind `main`, because a clone of this repo is usually also a live Skill install:
  the entries under `~/.claude/skills` and `~/.agents/skills` are symlinks into it, so landing on
  an older ref silently changes what your agent reads.

`core.hooksPath` is local config and is not tracked. A fresh clone has no hooks until someone
sets it.
