# Triage labels

<!-- HAND-WRITTEN, not stamped (project-workflow.md § Hand-written, and it stays that way).
     When the github Profile exists (#28) its Template home is
     init-project/profiles/github/templates/triage-labels.md. The vocabulary is defined once in
     chunks/tracker-github.md § Two label axes — this file maps, it does not define. -->

Skills speak in five triage roles. This tracker routes on two label axes instead, so the roles map
onto the **gate** axis:

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

The second axis is **origin**, saying why an issue exists. Its values, the wayfinder labels that
replace it, and the rule that a `Spec:` or `Map:` parent carries neither axis are the Chunk's
§ Two label axes and § Parents.
