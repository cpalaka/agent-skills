---
type: knobs-v2
imports:
  - extra-chunk
templates: []
knobs:
  verify-gate:
    root_dir: "<the directory the gate runs in>"   # a shape: the renamed value must survive
    light_set:
      - "docs/**"
    test_cmd: "make test"
  parallel-work:
    install: "none"
---

Fixture Profile: four-fragments's verify-gate block after a key rename, a respelling, an added key and a new block.
