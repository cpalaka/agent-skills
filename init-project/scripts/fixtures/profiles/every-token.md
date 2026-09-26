---
type: every-token
imports: []
templates:
  - { src: tokens.txt, dest: out/tokens.txt }
knobs:
  verify-gate:
    dir: "repo root"        # a literal: written from the Profile
    test: "<the test suite>"  # a shape: the answers file must give it
---

Fixture Profile: a Template copy carrying every token kind.
