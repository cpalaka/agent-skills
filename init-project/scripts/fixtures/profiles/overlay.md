---
imports: []
templates: []
knobs:
  gamma:
    g: "pg"
  beta:
    b2: "pb2"
  alpha:
    two: "p2"
    extra: "pe"
    lst:
      - "p-item"
    zeta: "pz"
  delta:
    d: "pd"
---

Fixture Profile: one scalar and one list override, two Profile-only keys listed around a default
key, and two Profile-only blocks listed around the defaults' blocks.
