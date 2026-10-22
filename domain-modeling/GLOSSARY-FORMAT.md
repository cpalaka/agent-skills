# GLOSSARY.md format

```md
# {Project} — domain language

{One or two sentences: what this context is and why it exists.}

## Language

**Order**:
A customer's request for goods, from placement to fulfilment.
_Avoid_: purchase (the payment, not the request), transaction (the database word).

**Invoice**:
A request for payment sent to a customer after delivery.
_Avoid_: bill (what the customer calls it; the code never does).
```

## Rules

- One entry per concept: a bold headword, a one-sentence what-it-IS definition, and an
  `_Avoid_` line only when the project has a real collision to record, each rejected word with
  its reason in parentheses.
- Only terms specific to this project. A general programming concept (timeout, retry, cache)
  belongs here only when the project overloads it.
- Group under `###` subheadings when clusters emerge; a flat list is fine until then.
- The file points into design docs and ADRs; it never summarises them.

## Several contexts

A `GLOSSARY-MAP.md` at the repo root lists each context, where its `GLOSSARY.md` lives, and how the
contexts relate (which events or shared types cross each boundary). System-wide decisions stay in
the root `docs/adr/`; a context's own decisions sit beside its glossary. Infer the context from
the topic at hand; ask when unclear.
