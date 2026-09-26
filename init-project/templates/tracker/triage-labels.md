# Triage labels

<!-- Stamped by init-project (templates/tracker/triage-labels.md). The map from the triage
     roles skills speak in to this project's label strings; both host adapters reach it through the
     contract. The vocabulary is defined once in the tracker-github chunk § Two label axes, which
     your host adapter loads — this file maps, it does not define. -->

Skills speak in seven triage roles: two **category** roles and five **state** roles. This tracker
routes on two label axes instead, so the two groups map differently — the state roles onto the
**gate** axis, the category roles onto neither.

## State roles → the gate axis

| Triage role in a skill | In this tracker                   |
| ---------------------- | --------------------------------- |
| `needs-triage`         | `gate:decide`                     |
| `needs-info`           | `gate:decide`                     |
| `ready-for-agent`      | `gate:agent`                      |
| `ready-for-human`      | `gate:accept`                     |
| `wontfix`              | no label — close as not planned   |

`needs-triage` and `needs-info` both land on `gate:decide`, which says only that no session starts
the work; why it is waiting is the issue's own text.

`ready-for-human` reads backwards here: it means the owner must accept the **result**, not that an
agent may not do the work — a session works it and stops at the close.

`wontfix` maps to no label because a decline is an exit rather than a state — the chunk's
§ Acceptance and re-gating closes it not planned with the owner's reply quoted. GitHub's default
label set, which ships with every repository, includes a literal `wontfix`; it is not part of this
mapping, and seeing it on an issue does not mean the decline path was taken.

## Category roles → no label

| Triage role in a skill | In this tracker                    |
| ---------------------- | ---------------------------------- |
| `bug`                  | no label — say it in the title     |
| `enhancement`          | no label — say it in the title     |

**What kind of thing an issue is lives in its title here, not in a label.** Neither role maps onto
either axis: the gate label says what a session may do with an issue and the origin label says why
it exists, and neither is a statement about whether the thing is broken or new. So a skill that
would apply a category role applies nothing, and writes the distinction into the title instead.

This is the same shape as `wontfix` above, and it has the same trap. GitHub's default label set
ships literal `bug` and `enhancement` labels on every new repository, so both names exist here
whatever this file says; that is an accident of the defaults, not part of this mapping, and seeing
one on an issue does not mean a category role was applied.

## The other axis

The second axis is **origin**, saying why an issue exists. Its values, the `wayfinder:*` labels that
replace it on a wayfinder ticket, and the rule that a `Spec:` or `Map:` parent carries neither axis
are the chunk's § Two label axes and § Parents.
