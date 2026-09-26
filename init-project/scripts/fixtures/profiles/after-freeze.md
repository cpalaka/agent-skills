---
type: after-freeze
imports: []
templates:
  - { src: late.md, dest: late.md, after_freeze: true }
knobs:
  verify-gate:
    dir: "repo root"
---

Fixture Profile: one after_freeze template carrying a fill prompt (the after-freeze-fill case).
