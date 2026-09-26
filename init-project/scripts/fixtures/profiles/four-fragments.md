---
type: four-fragments
imports:
  - extra-chunk
templates: []
adapters:
  contract: contract.md
  claude: adapter-claude.md
  codex: adapter-codex.md
  gate_runner: adapter-gate-runner.md
knobs:
  verify-gate:
    dir: "repo root"
    light_set:
      - "docs/**"
---

Fixture Profile: a fragment at each of the four markers; the contract one replaces the Running stub only.
