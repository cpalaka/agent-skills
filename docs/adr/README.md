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
| [0009](0009-init-project-emits-contract-and-two-adapters.md) | `init-project` emits one shared contract and two thin host adapters (amended by 0020) |
| [0010](0010-fragment-bullets-declare-their-targets.md) | Fragment bullets declare their targets; migrate withholds a failing bullet whole, never rewrites it (superseded by 0020) |
| [0011](0011-roles-not-cost-tiers.md) | Capability roles, not cost tiers, decide which model fills a seat (supersedes 0006) |
| [0012](0012-issue-status-is-derived.md) | Issue status is derived from open state, gate label and blocked-by; never from a board or a body rewrite |
| [0013](0013-retire-unused-chunks.md) | Three Chunks retire on a zero-importer measurement; the git-flow fork keeps one side (supersedes 0002 in part; extended by 0022) |
| [0014](0014-floor-is-a-location.md) | The floor is a location: `chunks/` holds always-on rules only, and a situational body is a Skill (amends 0001, 0009) |
| [0015](0015-chunk-cap-250-ceiling-2900.md) | The condensed-Chunk cap is 250 words and the floor ceiling is 2,900 (amends 0014) |
| [0016](0016-floor-ceiling-is-acceptance-time.md) | The floor ceiling is acceptance-time, and every standing number names its reader (amends 0014 § 7, 0015 § 2; amended by 0021) |
| [0017](0017-seats-pin-family-aliases.md) | Seats and workflow scripts pin a family alias, not a versioned model ID (amends 0011) |
| [0018](0018-run-profile-derived-from-plan.md) | A run's profile is derived from its plan; the ticket pins dials, never levels; effort is a dial (amends 0011; superseded by 0023) |
| [0019](0019-delegated-batch-over-subagent-coordinators.md) | A delegated batch runs per-ticket coordinators as subagents from one main session |
| [0020](0020-migrate-retired.md) | Migrate mode is retired; an engine Template asserts engine facts only (supersedes 0010, amends 0009) |
| [0021](0021-mechanical-stamping-is-a-script.md) | Mechanical stamping is a script; prose keeps judgment (amends 0016 § 4) |
| [0022](0022-tracker-is-an-engine-step.md) | The tracker is an engine step; a Chunk may be frozen with importers (extends 0013) |
| [0023](0023-light-default-run-profile.md) | A run posts a light default profile; the owner turns add-ons on; `xhigh` is retired (supersedes 0018) |

**0012 is now taken.** It was claimed rather than free while it sat empty: spec issue #23 reserved
it for the tracker ADR and cited that number in a public issue body, so the entry written first
took 0013 instead — when two hand-numbered sequences collide and theirs is already cited outside
its branch, yours renumbers. The reservation has now been filled by the entry it was held for.

**0004 is deliberately absent.** These numbers are the original ones from the single repo this
library was split out of (ADR 0008), kept so a reference to "ADR 0002" means the same document in
both. 0004 governs content that stayed private, so there is nothing here to copy. The gap is the
record, not an error — do not reuse 0004 for something else.

Numbering continues from 0009 independently in each repo.
