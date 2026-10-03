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
| Event merchants | Optional unique retained Event disposition: Merchant(role-free external identity) / Nonmerchant; absence unresolved, no registry/inference/inheritance |
| Original amounts | Unique positive root fact + explicit Measure; same-frontier current terminal association, raw fact unchanged; no FX/balance/support meaning |
| Exchange evidence | Unique Event + selected source/destination keys; distinct Measures, selected and net signs, no third Measure/correction participation; extra Effects retained, no rates/fees |
| Actual Reversals | Explicit disjoint target/reversal endpoints in retained memory, exact physical multiset inversion ignoring keys/order; no correction/deletion/support |
| Actual source | Ordinary + Exchange/Reversal subset: identity, Exchange, Reversal, all Effects nonzero; independently qualify targets, admit inverse sides; dates, Event corrections, descriptions, Merchants, root original amounts |
| Current quantity query | One source; origin, opening (unique coordinate/current Event/matching Effect), assertions and presence, globally separated; Exact / Known_present / unsupported |

Public `.mli` files own exact inputs, diagnostics and ordering. Indexes are disposable
mechanisms, not canonical evidence. Helpers such as `Effect_sum` are omitted from the
curated Application namespace. Replacement_cycle shares only cycle detection between
Event/date relations; each owns closure/association/uniqueness/selection. No fake Events
or encoded identities adapt date references to Event admission. Measure_totals privately shares exact per-Measure sums for two concrete admission consumers;
its mathematical empty sum is not external support. Public answer arithmetic zero is exposed
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

Origin and opening answers sum the whole qualified terminal frontier; opening does not
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

Merchant dispositions are independently supplied optional facts, not parsed descriptions
or guessed Effect/payment roles. Their memory retains the same supplied Event source and
original facts/order, including superseded observations. Exact-ID lookup distinguishes
None (unresolved), Some Nonmerchant and Some Merchant(party). Shared party IDs across
Events are allowed; identity itself is role-free, exact and nonempty, without a registry,
display-name authority or aliases. The concrete Event_merchants boundary stays separate
from descriptions; similar association mechanics do not make their meanings interchangeable.
Whole Merchant admission follows descriptions and precedes original amounts/support/query; even an
unrelated bad row refuses. Top-level MERCHANT event party / NONMERCHANT event are the only
new rows, with forward references and no inferred defaults/correction inheritance.

Original amounts are independent presented/charged observations, one positive Quantity
per stable correction root in an explicit Measure. The Measure need not occur in Effects
or differ from their Measures; no exchange rate, balance contribution or basis is inferred.
Original_amounts reuses the already qualified frontier's root/terminal associations.
Its abstract current rows retain the original root fact and exact terminal Event; indexed
terminal-ID lookup returns None when absent/noncurrent, not zero. Declaration order is
preserved, without chronology/priority. Fresh tails require explicit requalification and
change only the derived association; arbitrary prefixes/omissions can invalidate subjects.
Unlike text/Merchant inheritance, this root-to-terminal projection is the declared meaning.
Raw facts/order/frontier remain inspectable. Whole amount admission follows prior source
gates/Merchants; top-level ORIGINAL-AMOUNT root measure signed-decimal shares existing
lexing, while duplicates/positivity/retained/root membership are source admission.

Exchange_evidence qualifies selected Effects against one retained memory/raw correction
relation, without graph-admitting that relation. Exact keys are not coordinates/positions;
Event structure already guarantees within-Event key uniqueness. Selected Measures differ,
source Effect AND source total are negative, destination Effect AND destination total
positive, and every Effect uses one of those two Measures. Additional Effects retain order
and multiplicity, without assigning fee meaning. Any correction endpoint mentions refuses,
including open raw edges, until Effect replacement semantics earns qualification.
Its abstract selection retains original Event/Effects/fact and raw memory/relation.
Source grants Exchange balance exemption ONLY through successfully admitted whole Exchange
memory; all Effects must still be nonzero, including unselected ones. Ordinary targets and
non-reversal/non-Exchange Events keep per-Measure conservation. Local source gates Exchange
and Reversal before physical checks (upstream checks all nonzero first); no-claim ordinary
order remains unchanged. Date/frontier/metadata
and support gates follow, so no malformed relation or missing dates can become a source.
Top-level EXCHANGE event source-key destination-key admits forward references, never keys,
rates, ownership or support by inference. Movement stays the narrower entrance.

Actual_reversals qualifies explicit target/reversal facts against retained Event memory.
Every endpoint is globally unique across both roles: self-links, identical duplicates,
chains/cycles and cross-role reuse refuse. Closure and exact inversion follow per fact;
local combined gate differs from upstream separate uniqueness/closure/inverse gates.
Transient sorted physical rows compare exact Locus/Measure/Quantity and occurrence counts,
not keys, net coordinate totals or chronology. Raw facts/order/Events remain unchanged,
including keys and anonymous repeated Effects. Abstract pairs/role-specific indexed lookup
retain both original Events; absence is unresolved. No nonzero/balance/date/frontier gate
in this standalone boundary. The full source checks ALL retained Effects nonzero and every
non-Exchange target per-Measure balanced. Inversion derives ordinary reversal balance;
qualified Exchange inverses remain explicit Reversal exceptions, not per-Measure balanced.
Disjoint roles guarantee a target cannot itself borrow reversal-side exemption. Exchange
claims on reversal sides never qualify their targets backwards. There is no automatic
pair deletion, root merging, metadata inheritance or quantity/presence support. Independent
corrections/cuts still select observations; endpoints need not be current/roots, and only
existing Exchange-subject correction exclusion applies (no new Reversal-only exclusion),
so current cancellation is conditional on BOTH original endpoints remaining selected.
Top-level REVERSAL target reversal supports forward references without ID allocation.

The current source is NOT full normalized Actual: other structured metadata
and relations/settlement remain unqualified. Date evidence is not proof of occurrence
truth, recording chronology or historical completeness.
Queries do not establish household authority, purchasing power or spendability.

## Future operational work

Before storage/writes, specify operation admission, current ownership, identity/retry,
conflicting payloads, uncertain outcomes, atomic visibility versus durability, diagnostics,
backup/restore and migration. Then select storage and transition/fault instruments.
Do not infer these from a structurally valid preview or ordinary Movement retry behavior.

UI is not implemented; CLI is the development/read entrance, not a TUI-first commitment.
Future clients consume semantic answers rather than recomputing meaning. First usable UI
is undecided; TUI/GUI/Web toolkit, remote protocol and compatibility need actual consumers and
approval. MirageOS may later host the engine through external I/O adapters; target/runtime
and Base/Zarith/GMP/C-stub compatibility are unqualified, not a current dependency promise.
No speculative load/navigation state, adapter, cache or framework belongs in the engine.
