---
type: github
imports:
  - tracker-github
templates:
  - { src: issue-tracker.md, dest: docs/agents/issue-tracker.md }
  - { src: triage-labels.md, dest: docs/agents/triage-labels.md }
adapters:
  contract: contract.md
knobs:
  tracker-github:
    REPO: "<owner/repo>"
    RESULTS_DIR: "none"
---

Fixture tracker Profile: the key shape and the three assets the tracker-github stamp reads.
