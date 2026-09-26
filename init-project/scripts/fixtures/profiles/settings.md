---
type: settings
imports: []
templates:
  - { src: fixture-helper, dest: ~/.local/bin/fixture-helper }   # host-setup writes it; stamp skips it
knobs:
  verify-gate:
    dir: "repo root"
settings:
  allow:
    - "Bash(fixture-a:*)"
    - "Bash(fixture-b:*)"
  enabled_mcp_servers: [ fixture-mcp ]
---

Fixture Profile: a settings delta and one ~/ template entry (the settings and host-setup cases).
