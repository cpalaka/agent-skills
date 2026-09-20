# Triage labels

<!-- HAND-WRITTEN, and authoritative for THIS repository; not stamped (project-workflow.md
     § Hand-written, and it stays that way). init-project/profiles/github/templates/triage-labels.md
     stamps the same file into a project that IS stamped; it is the shape this one mirrors, not its
     source, and neither is generated from the other. The vocabulary is defined once in
     chunks/tracker-github.md § Two label axes — this file maps, it does not define. -->

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

`wontfix` maps to no label because a decline is an exit rather than a state — the Chunk's
§ Acceptance and re-gating closes it not planned with the owner's reply quoted. GitHub's default
label set, which ships with every repository, includes a literal `wontfix`; it is not part of this
mapping, and seeing it on an issue does not mean the decline path was taken.

## Category roles → no label

| Triage role in a skill | In this tracker                 |
| ---------------------- | ------------------------------- |
| `bug`                  | no label — say it in the title  |
| `enhancement`          | no label — say it in the title  |

**What kind of thing an issue is lives in its title here, not in a label** —
[`CONTEXT.md`](../../CONTEXT.md) § origin label settles it: "bug vs feature is title prose, not a
label". Neither role maps onto either axis: the gate label says what a session may do with an issue
and the origin label says why it exists, and neither is a statement about whether the thing is
broken or new. A skill that would apply a category role applies nothing here.

Same shape as `wontfix` above, and the same trap: GitHub's default label set ships literal `bug`
and `enhancement` labels on every repository, so both names exist here whatever this file says.
That is an accident of the defaults, not part of this mapping.

## The other axis

The second axis is **origin**, saying why an issue exists. Its values, the wayfinder labels that
replace it, and the rule that a `Spec:` or `Map:` parent carries neither axis are the Chunk's
§ Two label axes and § Parents.
