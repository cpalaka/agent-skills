# ADR format

ADRs live in `docs/adr/`, numbered `0001-slug.md`, `0002-slug.md`: scan for the highest number
and add one. Create the directory with the first ADR.

```md
# {Short title of the decision}

**Status:** accepted — {date}

{One paragraph: the context, what was decided, and why.}
```

Optional sections, each only when it earns its lines: **Considered options** when a rejected
alternative will be proposed again otherwise; **Consequences** when a downstream effect is not
obvious from the decision.

## The three gates

Offer an ADR only when all three hold:

1. **Hard to reverse**: changing course later costs something real.
2. **Surprising without context**: a future reader will look at the code and ask why.
3. **A real trade-off**: there were genuine alternatives and one was chosen for reasons.

Easy to reverse: just reverse it. Not surprising: nobody will ask. No alternative: nothing to
record beyond the obvious.

## What qualifies

Architectural shape; integration patterns between contexts; technology choices that carry
lock-in (the ones that take a quarter to swap, not every library); boundary and ownership
decisions, the explicit no as much as the yes; deliberate deviations from the obvious path, so the
next engineer does not "fix" them; constraints invisible in the code; rejected alternatives whose
rejection is non-obvious.

## Reversal

A reversed decision gets a new ADR that names the sentences it supersedes, and the old one gains
`**Status:** superseded by [ADR NNNN](NNNN-slug.md)`. The old body is never edited: it records
what was decided when.
