---
imports: []
templates: []
knobs:
  verify-gate:
    secret_scan: "grep -rEn '<Fill at init: the secret-leak pattern>' . — expect ZERO matches"
    scene: "open [<scene>] in the editor"
---

Fixture Profile: web's secret_scan spelling (a literal carrying a `<Fill at init: …>` shape, which verify
fails on until the key is answered) beside a `[<scene>]` literal that must read clean.
