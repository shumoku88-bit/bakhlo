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
| Effect / Event | Optional independent Effect keys, unique within Event; anonymous multiplicity/general neutral observations retained; Event is not Movement |
| Movement | Nonempty/nonzero, one Measure, exact conservation for this narrower entrance |
| Event memory / correction closure | Identity uniqueness, retained order, ordered endpoint resolution |
| Correction frontier | Closed disjoint paths; duplicate targets/replacements, branches, merges and cycles refuse; retain source and edges |
| Lineages / reflected cut | Root-to-terminal associations; independent unique represented-root declarations; retain source, exclude whole lineages |
| Current assertion groups | Exact assertions + unreflected Effects; independent cuts, one coordinate owner; ordered whole-group qualification |
| Actual validity | Tagged base/revision ISO history, closed disjoint same-Event date corrections; retain all facts/edges, exactly one current date per retained Event; no date/list winners |
| Event descriptions | Optional unique retained Event reference + exact recognizer text; no classification, completeness or inheritance |
| Actual source | Ordinary/base-validity subset: every retained Effect nonzero, each Measure independently balanced, date-history/Event-corrections then whole descriptions admission |
| Current quantity query | One source; origin, opening (unique coordinate/current Event/matching Effect), assertions and presence, globally separated; Exact / Known_present / unsupported |

Public `.mli` files own exact inputs, diagnostics and ordering. Indexes are disposable
mechanisms, not canonical evidence. Helpers such as `Effect_sum` are omitted from the
curated Application namespace. Replacement_cycle shares only cycle detection between
Event/date relations; each owns closure/association/uniqueness/selection. No fake Events
or encoded identities adapt date references to Event admission. Arithmetic zero is exposed
only after a support gate.

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

Origin and opening answers sum the whole ordinary terminal frontier; opening does not
sum only its witness or store another scalar/date/cut. The explicitly named Event must
remain current and contain the exact coordinate; no automatic retarget after corrections.
Assertions reuse independent cuts. Shared coordinates across families refuse even with
equal amounts; never union cuts, infer support from activity/net zero, or fabricate zero.
Presence retains one independent shared root cut and unique coordinates, no scalar/date.
ANY matching Effect among its remaining terminal Events invalidates current presence,
including cancelling activity. Raw stale premises survive; only current lookup loses support.
Overlap uses all declarations, not just still-current presence. Even an explicit empty
presence premise qualifies its roots. Only the abstract Exact payload has a Quantity;
known-present has its own abstract coordinate/evidence/cut payload, never arithmetic.

## Read boundary

CLI pure parsing creates typed inputs. Quantity_literal shares only the signed-decimal
lexical rule across the two existing commands; each retains its own diagnostics/admission.
Event structural key admission occurs at END-EVENT;
syntax and structural refusals stay distinct. Source/support admission precedes lookup/text.
Only the shell reads a named synthetic file. Failure/malformed/unsupported input never
becomes an empty image. Domain remains general even when a practical source entrance is
narrower. There is one current fixture grammar, not a legacy protocol/backend matrix.

Descriptions remain independent of Event shape/occurrence/support. Their qualified memory
retains its supplied source and original declarations; indexed exact-ID lookup distinguishes
absent from empty text. Superseded Events may still have descriptions; a new terminal does
not inherit its predecessor's text. Invalid unrelated references refuse the whole source.
The fixture's top-level DESCRIPTION takes one literal field; engine text can contain tabs/
newlines but this noncanonical reader has no encoding for them. Never guess escapes.

Date facts are Base(Event ID) or Revision(distinct revision ID, Event ID); same-token
base/revision references do not alias. Replacement names only a revision. Current facts
are non-targets in original fact order after path admission, unique/complete by retained
Event; revision-only evidence need not invent a base. Date correction never chooses an
Event terminal, changes quantities, invalidates presence or transfers descriptions.
Both raw history and current fact/ref lookup remain inspectable. All retained dates are
calendar-checked, including superseded dates.

The current source is NOT full normalized Actual: structured metadata, Exchange/Reversal
and relations/settlement remain unqualified. Date evidence is not proof of occurrence
truth, recording chronology or historical completeness.
Queries do not establish household authority, purchasing power or spendability.

## Future operational work

Before storage/writes, specify operation admission, current ownership, identity/retry,
conflicting payloads, uncertain outcomes, atomic visibility versus durability, diagnostics,
backup/restore and migration. Then select storage and transition/fault instruments.
Do not infer these from a structurally valid preview or ordinary Movement retry behavior.

UI is not implemented; future clients consume semantic answers rather than recomputing
meaning. TUI/GUI/Web toolkit, remote protocol and compatibility need actual consumers and
approval. No speculative load/navigation state, cache or framework belongs in the engine.
