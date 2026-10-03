# Architecture proposal

Status: implemented boundaries for the current Movement slice; future persistence
and broader architecture remain PROPOSED. Initial scope/dependencies are in ADR
0001, preparation-only UI scope and boundaries in ADR 0003. No UI implementation
or framework is authorized in this phase. Storage remains open.

## Direction

Use a modular monolith with an independently usable OCaml engine. Runtime call
flow and source dependency direction are not the same thing:

```text
implemented source dependencies:

loam_cli -> loam_presentation -> loam_application -> loam_domain
loam_cli --------------------> loam_application -> loam_domain
bin/main -> loam_cli

future clients/test harnesses can use loam_application directly
```

Clients/projections also use Domain types and conversion accessors; there are no
reverse dependencies. The application and domain do not depend on text
presentation/CLI. Internal Dune libraries make those boundaries independently
buildable without UI dependencies. Implemented operations take explicit immutable
inputs; there is no canonical storage, clock or business mutation. `bin/main.ml`
now explicitly reads a named synthetic fixture; decoding stays pure in CLI.
Do not add placeholders; later storage/effects require concrete contracts.

Domain has no dependencies on UI, HTTP, database bindings, clocks, filesystem, or
an asynchronous runtime. Application owns use-case orchestration, not screen
state. Storage contracts should express needed operations, not imitate a generic
ORM. The eventual injection mechanism is undecided; a functor is not mandatory.

Future UI toolkit choice stays replaceable. Physical names are not an external
compatibility promise.

## Domain design

- Abstract identifiers and admitted values behind `.mli` interfaces.
- Exact arithmetic, immutable evidence, explicit unknown/refusal cases.
- Separate parser validity, semantic admission, and current-world authorization.
- Smart constructors protect construction paths but are not mathematical proofs.
- Phantom types or GADTs only when a concrete misuse is prevented at reasonable
  cost. Avoid unsafe escape hatches that invalidate the public contract.

For example, an admitted Movement can carry a conservation invariant, but that
value alone cannot authorize a later write after the world has changed.

## Supplied observations and correction closure

`Event` retains an explicit Event identity and anonymous neutral Effects. It is
not a synonym for ordinary Movement: empty/zero/mixed-Measure observations remain
representable at this layer. Event memory rejects repeated identity and preserves
input order while building one immutable matching lookup index.

`Correction_check.run` uses that memory to resolve both raw endpoints, returning
both observations and the explicit edge or ordered missing-Event errors. Closure
is not frontier/currentness admission, graph traversal, correction application,
or publication; see `CORRECTION_ENDPOINT_SLICE.md`. No dates or authority follow
from ID spelling, list order, or a later replacement record.

`Correction_frontier.create` subsequently checks all supplied edges for closure,
unique targets/replacements, and acyclicity. Abstract success retains the original
memory/relations and materializes untargeted Events in original order. Temporary
persistent maps/sets are discarded; this is not a canonical replacement history,
current Actual, root-cut implementation, or publication permission. It now also
materializes abstract root/terminal associations after that same admission, using
already-resolved observations; no second constructor or default lookup is added.
Lineage rows preserve root representation order, whereas frontier rows preserve
terminal representation order. See `CORRECTION_FRONTIER_SLICE.md` and
`ROOT_LINEAGE_SLICE.md`.

`Reflected_root_cut.create` consumes that qualified frontier and independent
reflected root IDs. It validates unique/represented-root declarations, retains
both source and declaration list, and materializes unreflected rows/terminal Events
in root order. It never reconstructs/adopts a raw graph or deletes source facts.
A cut is source-bound; rebinding declarations requires a new checked construction.
Optional row-selection proofs live outside the product toolchain. See
`ROOT_CUT_SLICE.md`; current support/Actual admission remain separate.

## Future write path — not implemented

```text
collect draft
 -> acquire relevant write ownership / transaction
 -> establish current evidence and policy
 -> admit operation and allocate required identity
 -> publish according to the durability contract
 -> return receipt
```

Operation-specific semantics stay distinct. Reusable transaction mechanics must
not turn every publisher into one generic semantic operation.

Specify retry identity and conflicting-payload behavior before exposing retryable
writes. The existing Lean ordinary Movement retry returns the first result for a
retained operation ID without comparing the retry payload. Do not accidentally
claim payload equality or generalize that policy to all operations.

Specify uncertain outcomes: a connection may fail after a durable commit. A UI
must not blindly resubmit as a new logical operation.

## Read path

The current `Movement_check.run` command materializes a structured, abstract
preview from a validated Movement: Measure, original Effects, and exact positive
total. It forwards ordered domain refusals. The aggregate is computed once per
command, not by rendering; this answer is not a cache or canonical evidence.
There is no dummy state parameter for this stateless operation.

`Zero_origin_projection.create` now materializes an immutable coordinate index
from explicitly supplied Movements. Queries use independent zero-origin membership
and one indexed lookup, returning conditional quantities or `Origin_unknown`.
No activity or zero net change supplies origin evidence. This is not a cache,
current Actual image, correction selection, or chronological history service.
See `BALANCE_SLICE.md`; never relabel its answer as current/spendable quantity.

`Current_quantity_projection.create` now retains one qualified cut and original
exact coordinate assertions as one anonymous group. It rejects coordinate repeats,
materializes exact assertion/delta/total answers, and exposes lookup-only queries.
Unasserted coordinates stay unsupported even with activity or zero delta. Private
`Effect_sum` shares arithmetic with zero-origin projection, not support meaning;
`loam_application.ml/.mli` explicitly omit it from the public namespace. There is
no group ID, source mutation, implicit time or full Actual/multi-group admission.
See `CURRENT_QUANTITY_SLICE.md` before quantity composition.

`Current_quantity_groups.create` now qualifies multiple anonymous declarations
against ONE explicit frontier. Each group's cut stays independent; the ownership
index refuses overlapping live coordinates instead of choosing list-order winners.
`reobserve` qualifies incoming premises before reducing old assertions, keeps every
unrelated cut/assertion, drops empty residual groups and appends incoming. Old
images and source facts remain immutable; this is neither canonical assertion
history nor a publication workflow. Lookups reuse qualified one-group answers.
See `CURRENT_GROUPS_SLICE.md`; full Actual/support-family admission remains separate.

`Actual_quantity_preview.run` admits only synthetic base validity (one real ISO
occurrence date per retained Event, independently unique/closed/complete), then
reuses frontier/groups against that same source. Neutral Events stay general;
validity is retained separately, not an Event date field or winner rule. Queries
reuse qualified exact answers; dates do not replace reflected roots. This is NOT
normalized household Actual admission or other support-family routing. The pure
CLI decoder rejects unknown/versioned/metadata/keyed/support rows and incomplete
blocks; shell read errors never become empty input. See public interfaces and
`examples/actual-preview.fixture`; no canonical persistence format is selected.

`Actual_source.create` now separately admits the ordinary anonymous/base-validity
subset: every retained Event has nonzero Effects and exact per-Measure balance,
then independent base validity and correction admission. Empty and balanced mixed-
Measure Events remain valid; Domain Event and the legacy preview stay general.
`Actual_validity` owns the shared date/unique/closed/complete base facts. This is
not full normalized admission: no keyed Effects, other metadata, validity history,
Exchange/Reversal, relation or settlement qualification. No source authority follows.

`Current_quantity_query.create` takes ONE `Actual_source.t`, raw origin coordinates
and raw exact groups. It qualifies both families then refuses all cross-family overlap,
including equal amounts. Origin answers sum the ordinary terminal frontier; assertions
reuse their independent qualified cuts, never a union. `premise` distinguishes origin
from actual assertion decomposition, without inventing an assertion at zero. Missing
support stays typed unknown. Arithmetic indexes remain private/disposable. Queries
need only membership/owner lookups; `inspect-current-fixture` reads ONLY synthetic v2
(same blocks plus ZERO-ORIGIN), independently of the preserved general v1 preview.
Opening/presence and full normalized admission remain separate/unimplemented.

For future admitted queries, use question-specific boundaries (Actual, balance,
Scheduled, etc.). Those full reports/histories are not implemented in OCaml yet.
Shared read answers are presentation-neutral, but do not require a universal
query service or generic DTO family.

Establish a query's evidence/consistency scope before projecting. A cached read
model is disposable and must have a detectable relationship to the authority it
represents. Do not mix generations merely because each individual read is valid.

## UI and transport

UI owns selection, editing drafts, focus, layout, pending requests, and disposable
preferences. It does not reconstruct correction/currentness or balance semantics.

CLI parses input and submits typed `Movement_check.command` values; other clients
use that operation without argv. Semantic values precede `Movement_text` formatting.
The text projection accepts only structured answers/refusals, without revalidation,
aggregate recalculation, or effects. Help, syntax errors, streams, and exit codes
remain CLI responsibilities. The preview is explicitly not a household write.

No TUI/web/dashboard/component system, UI state, dimensions, input events, or
UI-specific JSON is introduced. Current scope is preparation, not layout design
or toolkit selection; see `UI_DIRECTION.md`.

An in-process OCaml API and a wire protocol are distinct contracts. If independent
clients require a wire protocol, explicitly encode exact quantities, unknowns,
errors, versions, and compatibility. Do not serialize private OCaml records as a
permanent public API by accident. Decimal integer strings are a candidate for
exact transport to JavaScript clients, not a selected schema yet.

A local library adapter can precede HTTP. A browser UI does not imply public
network exposure, multiple users, or offline synchronization. Remote access
requires a separate threat model and authentication/authorization decisions.

## Storage is an open decision

Compare text authority and SQLite using the whole operational design:

- Transaction boundaries across related evidence.
- Crash recovery, durability, competing processes, backup and restore.
- Human inspection, diagnostics, portability, migration cost.
- Maintainer familiarity, dependencies, measured scale and query demands.

Existing LOAM's encoder study removed one measured reason to replace text for
performance. That does not settle the new product's operational trade-offs.
Nor does SQLite automatically provide semantic validity or a backup policy.

Distinguish atomic visibility from power-loss durability. Record filesystem,
platform, flush, and transaction assumptions in whichever design is selected.
Avoid implementing a hypothetical matrix of storage backends.

## Slice progress

Quantity and structural ordinary Movement validation are implemented, exercised
from a minimal CLI with success/refusal cases. This is not admission against a
world, policy catalog, or persisted Event. The boundary preserves represented
Effects and avoids numeric aggregation across mismatched Measures.

The application command/read model is now independent of the CLI/text projection.
Synthetic persistence, publication, correction/current queries, and any interface
remain separately scoped work. Do not proceed automatically to interactive traces
or screens; the latest user instruction explicitly postpones UI implementation.

The conditional projection demonstrates separate construction and query costs
without rebuilding every supplied Movement on each lookup. Event memory similarly
separates index construction from endpoint resolution. Neither structure establishes
history latency, graph admission, or operational completeness.

When actual time-dependent/history queries arrive, pass coordinates and admitted
input inward explicitly. Keep query construction separate from client selection,
formatting, and navigation. No global now, hidden I/O/randomness, cache, or
incremental framework is needed for the current timeless check. Measure concrete
history/query workloads later; this phase makes no large-history latency claim.
