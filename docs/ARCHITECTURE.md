# Architecture

A modular monolith with an independently usable immutable OCaml engine.

```text
bin/main -> CLI -> Presentation -> Application -> Domain
            |-------------------->|------------->|
```

Clients also use Domain types; dependencies never point outward. Engine native targets
build without Presentation/CLI or UI packages. Runtime dependencies are Base + Zarith.
There is no canonical storage, clock, mutable business state or generic service framework.

## Invariant owners

| Boundary | Responsibility |
| --- | --- |
| Quantity / identifiers | Exact signed quanta; distinct exact nonempty identities, no coercion/normalization |
| Effect / Event | Neutral observations, represented multiplicity; Event is not Movement |
| Movement | Nonempty/nonzero, one Measure, exact conservation for this narrower entrance |
| Event memory / correction closure | Identity uniqueness, retained order, ordered endpoint resolution |
| Correction frontier | Closed disjoint paths; duplicate targets/replacements, branches, merges and cycles refuse; retain source and edges |
| Lineages / reflected cut | Root-to-terminal associations; independent unique represented-root declarations; retain source, exclude whole lineages |
| Current assertion groups | Exact assertions + unreflected Effects; independent cuts, one coordinate owner; ordered whole-group qualification |
| Actual validity | Independent base ISO facts, unique/closed/complete for all supplied retained Events; no chronology/winners |
| Actual source | Ordinary anonymous subset: every retained Effect nonzero, each Measure independently balanced, validity and correction admission |
| Current quantity query | One admitted source; explicit origin and exact assertion support, globally separated; typed unknown otherwise |

Public `.mli` files own exact inputs, diagnostics and ordering. Indexes are disposable
mechanisms, not canonical evidence. Helpers such as `Effect_sum` are omitted from the
curated Application namespace. Arithmetic zero is exposed only after a support gate.

## Selection and consistency

Retained and selected observations differ. Frontier Events follow terminal representation
order; lineage/cut rows follow root order. Neither order establishes chronology or priority.
A fresh tail preserves the root; prefixes/removals/arbitrary source changes need rechecking.
A cut cannot be rebound implicitly. Old terminal exclusion is not root exclusion.

Groups qualify against ONE supplied frontier, not separate projection snapshots. Each
assertion retains its own group's cut. Explicit `reobserve` qualifies incoming before
reducing old premises, preserves unrelated assertion/cut pairs, drops empty residual groups
and appends incoming. The old value/source stay immutable. This is not persisted history,
retry identity, publication or a list-order winner.

Origin answers sum the whole ordinary terminal frontier. Assertions reuse their independent
cuts. Shared live coordinates across families refuse even with equal amounts; never union
cuts, infer support from activity/net zero, or fabricate an assertion at zero.

## Read boundary

CLI pure parsing creates typed inputs; source/support admission precedes lookup and text.
Only the shell reads a named synthetic file. Failure/malformed/unsupported input never
becomes an empty image. Domain remains general even when a practical source entrance is
narrower. There is one current fixture grammar, not a legacy protocol/backend matrix.

The current source is NOT full normalized Actual: keyed Effects, metadata, validity
revisions, Exchange/Reversal, relations/settlement and opening/presence remain unqualified.
Base validity is external evidence, not proof of occurrence truth or historical completeness.
Queries do not establish household authority, purchasing power or spendability.

## Future operational work

Before storage/writes, specify operation admission, current ownership, identity/retry,
conflicting payloads, uncertain outcomes, atomic visibility versus durability, diagnostics,
backup/restore and migration. Then select storage and transition/fault instruments.
Do not infer these from a structurally valid preview or ordinary Movement retry behavior.

UI is not implemented; future clients consume semantic answers rather than recomputing
meaning. TUI/GUI/Web toolkit, remote protocol and compatibility need actual consumers and
approval. No speculative load/navigation state, cache or framework belongs in the engine.
