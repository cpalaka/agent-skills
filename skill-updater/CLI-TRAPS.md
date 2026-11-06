# `npx skills` CLI traps

Read from the source of `skills` 1.7.6 and rehearsed against a throwaway `$HOME`, 2026-11-06. The
engine pins nothing and runs `skills@latest`, so re-measure anything load-bearing on a newer
version: rehearse with `HOME=<scratch dir>` and diff the folders.

## Changing things you did not ask to change

- **`update --dry-run` runs a real update.** `update` ignores flags it does not know. `--dry-run`
  belongs to `sync` and `install`. `update --help` is safe.
- **`update` links each skill into the host it runs from.** A lock-managed skill you left unlinked
  gets a new `~/.claude/skills/<name>`, which shadows a built-in of the same name. From a plain
  terminal it targets every agent it detects. `apply-skills` undoes this; a hand run does not.
- **`update` does `rm -rf` and recopies**, so a hand edit to a lock-managed skill is lost with no
  warning. A personal rule belongs in a personal skill.
- **Named `update` without `-g`** covers global and project scope together.

## Reading its output

- **`check -g` is read-only** for GitHub sources and exits 1 when updates exist, which is not a
  failure. Older versions applied updates here. It compares upstream to the lock and never reads
  the folder, so it cannot see a stale folder or a hand edit.
- **`✓ Updated` has been printed over a stale folder.** On 2026-09-04 an `update` advanced the lock
  hash and left the folder one upstream version behind. It did not reproduce on 1.7.6.
- **`-y` keeps a skill deleted upstream**, printing "Skipping deletion in non-interactive mode".
- **Noise:** "PromptScript does not support global skill installation" during `add`; and a
  SHA-pinned plugin showing an update that `claude plugin update` calls already-latest. Trust the
  CLI on that one.

## `add`

- **`--skill a,b,c` takes the comma string as one name and installs nothing.** Space-separate
  (`--skill a b c`) or repeat the flag.
- **The agent id is `claude-code`.** `-a claude` fails.
- **`add` resolves no dependencies**, so name every sibling skill in the one call. Keep the default
  symlink install mode: the engine reads only `~/.agents/skills/<name>`.
