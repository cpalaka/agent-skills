# Architecture decisions

One file per decision, `NNNN-slug.md`. Read the relevant one before revisiting or contradicting
it; ADRs are scope-fences, and a change that crosses one needs an amendment or a superseding
entry, not a quiet edit.

| # | Decision |
|---|---|
| [0001](0001-import-from-home-chunk-delivery.md) | Chunks delivered via `@import`-from-home, not copy-and-parity |
| [0002](0002-git-flow-structural-fork.md) | git-flow is a structural fork (`squash` default), with three coupled rules per variant |
| [0003](0003-single-init-project-engine.md) | Single `init-project` engine + declarative Profiles, not per-type init skills |
| [0005](0005-codex-chunks-use-explicit-read-directives.md) | Codex chunks use explicit read directives |
| [0006](0006-scarce-tier-posture-ladder.md) | Scarce-tier placement is a cost-ordered posture ladder, not a permission list |
| [0007](0007-vendor-unchanneled-third-party-skills.md) | Third-party skills with no distribution channel are vendored into this repo |
| [0008](0008-public-private-split-by-audience.md) | The Skill library is split into two repos by audience, not by kind |
| [0009](0009-init-project-emits-contract-and-two-adapters.md) | `init-project` emits one shared contract and two thin host adapters |

**0004 is deliberately absent.** These numbers are the original ones from the single repo this
library was split out of (ADR 0008), kept so a reference to "ADR 0002" means the same document in
both. 0004 governs content that stayed private, so there is nothing here to copy. The gap is the
record, not an error — do not reuse 0004 for something else.

Numbering continues from 0009 independently in each repo.
