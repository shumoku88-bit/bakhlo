# Architecture

A modular monolith with an independently usable immutable OCaml engine.

```text
bin/main -> CLI -> Presentation -> Application -> Domain
            |-------------------->|------------->|
```

CLI also consumes the pure outer Text adapter, which depends inward on Application/Domain,
never Presentation/CLI. Clients also use Domain types; dependencies never point outward.
Engine native targets build without Text/Presentation/CLI or UI packages.
Runtime dependencies are Base + Zarith.
There is no canonical storage, clock, mutable business state or generic service framework.

## Selected product direction

After 07cd41f, user approved putting data sovereignty and a human-readable canonical
representation before physical store adoption, with MirageOS an explicit future product goal.
This pauses the previous Unix+SQLite canonical-reference adoption route, not its earned trials.
The goal remains a long-lived backend-neutral household application, not a Lean layout clone.
Core, Admission and Publication meanings must not depend on a particular database/filesystem/
runtime. Domain/Application stay immutable and Base + Zarith-only; outer publication consumes
the [minimal Persistence contract](#minimal-persistence-contract), not backend transactions.

### Properties to preserve

- Human-readable, lossless, versioned canonical evidence, not merely a text export generated
  by a working app. Quantities/Measures, independent support, original text and all correction/
  date/Reversal provenance remain explicit; readability does not license normalization/loss.
- Data outlives its app/VM: documented extraction/inspection and information-preserving restore/
  transfer must work without launching the original runtime. Text inside a DB BLOB is NOT
  equivalent to directly inspectable plain-text-accounting workflow; container/access matters.
- Meaning, logical representation, physical publication layout and runtime are separate choices.
  Draft/manual text edits pass shared admission and conditional publication, not bypass gates;
  Git/backend history or textual merge is not household correction or recording permission.
- MirageOS is a future goal, not only an accidental portability escape hatch. Keep a meaningful
  runtime-neutral route; guest persistence/update/recovery still need their own qualification.
- Exactness, unknown-versus-zero and independent evidence cannot be traded for UI, indexing or
  speed. One operational authority remains; existing Lean LOAM owns it until qualified cutover.

These are product requirements, NOT an implemented codec, extraction tool, store or recovery
promise. Public specification/licensing/release remain separate decisions.

| Axis / choice | Current role |
| --- | --- |
| Versioned canonical text | First representation/authority candidate to evaluate; grammar, identity, grouping and physical store NOT adopted |
| SQLite as canonical authority | Main adapter/package adoption PAUSED; [native evidence](VERIFICATION.md#unixsqlite-synthetic-persistence-bounded-outer-trial-no-saved-qualification) and [Linux counterexamples](VERIFICATION.md#linux-sqlite-syscall-failures-and-retained-journal-lifecycle-control) retained as comparison assets |
| SQLite as derived index/search | Optional only for a concrete consumer; rebuildable from qualified canonical evidence, never a second authority or automatic dependency |
| Unix runtime | Near-term implementation/measurement baseline, not a choice of canonical storage format |
| MirageOS/Solo5 runtime | Explicit future goal; current guarded feasibility remains experimental, durable barrier/maintenance unresolved |
| Irmin store adapter | Retained experimental option; commit/history is not household correction or semantic merge |

A derived index must identify its canonical generation and interpretation version; stale,
corrupt or missing indexes cannot authorize publication or supply household truth. Rebuild
only from qualified canonical evidence; no cross-generation fallback or subtotal-as-balance.
Text authority does not remove atomicity, request/receipt, synchronization or backup burdens.
No casual custom filesystem, runtime fork, shared effect framework or cache is selected.

Runtime and store are independent axes; no promise that every combination works (SQLite under
Solo5 remains unqualified). Do not delete trials/promote guards, or make experimental fixes
prerequisites for ordinary progress. Minimal composition is not a security/always-on claim.

The [experimental text read](#experimental-versioned-text-read) now exercises a bounded
synthetic profile, using independently supplied fixture inputs only as an oracle. Next compare
Unix text publication/reopen/recovery and synthetic long-term reconstruction/memory/history
growth against retained storage evidence before choosing physical authority/index roles.
[HANDOFF](HANDOFF.md#next-bounded-implementation) owns sequence. User approved a bounded private
read-only LOAM comparison before publication work: establish the actual selected revision/input,
then test one quantity/evidence question. Existing implementation/layout/answers are comparison
evidence, not automatic design requirements or a full-parity oracle. Original operational
facts stay under LOAM authority; ordinary tests remain synthetic and private payloads never enter
fixtures/commits. HOBS1 is a derived comparison surface, not canonical Bakhlo evidence or write
permission. User selected the checkout-based `tools/loam tui` read contract, then explicitly
requested latest interpretation while retaining responsibility for their own data cleanup.
No implicit older-file fallback, original repair/migration or CI-pin change. The private
current-only experiment demonstrated one conditional quantity/premise, not operational authority
or full-household admission. Its Python/generated-test scaffolding is retired; the
[scoped native reader](#scoped-native-loam-input-read) supplies the read boundary directly in
OCaml, not a parallel harness. Its logical
publication-request -> retained Event links were represented/qualified in the OUTER read
profile, not new Core ontology, payment truth or Saved.
All Actual rows/profile gates are handled before lookup; unsupported evidence still refuses,
and opaque other-family sections stay retained but unadmitted. The scoped read API is not
an omnibus compatibility or stable external-protocol promise. [Verification](VERIFICATION.md#latest-loam-contract-private-conditional-quantity-experiment)
owns limits; quantities agree with an original-list oracle, not a claimed LOAM runtime result.
No production canonical codec/store, writer/index/benchmark or Mirage/UI feature, full parity
prerequisite, original mutation/migration, main-lock change or implicit Saved.

## Minimal Persistence contract

Production requirements, not an implemented main module/stable API. An ignored synchronous
SQLite consumer now consumes coherent-read/conditional-publish functions and backend-neutral
snapshot/receipt/failure values; history/reconciliation are concrete trial operations. Its
admission/orchestration uses no SQLite types. This earns a small seam, NOT the trial schema/
IDs/durability or a shared multi-backend runner. No generic DB/FS service, effects framework,
branch/merge API or dummy State. Open/close/provision/fault injection are outer
resource concerns. Synchronous Unix and Lwt/Mirage adapters need not impose their effect
runtime on the immutable core.

- **Read:** one selected generation token with its complete versioned evidence bytes;
  retained-generation lookup as needed for history/reconciliation. Missing store, explicitly
  provisioned empty store, malformed/unsupported format and I/O failure stay distinguishable;
  reads never initialise, silently skip records or fall back to empty/older household truth.
  Diagnostic acquisition may expose faults and explicitly unadmitted readable fragments;
  it is not a successful complete household read. See [diagnostic availability](#structured-operations-and-diagnostic-availability).
- **Conditional publish:** supplied expected generation, explicit operation/request identity
  and complete candidate bytes. Publication owns whole-image admission/current-evidence
  revalidation; adapter owns atomic expected-head check/publication and persisted ordering.
  Keep retained immutable generations; physical token/revision/row ID is not Event identity,
  a household date or Quantity. No backend auto-merge, inferred facts or stored derived balances.
- **Resolve uncertain result:** inspect a retained operation receipt/candidate association
  without blindly republishing. Duplicate request + different supplied candidate/base refuses;
  a qualified identical replay refers to the ORIGINAL receipt, not a fresh household write
  or assertion that its generation is still current. Exact encoding/allocation/lookup interface
  is fixed with the first consumer, not invented by UI or an adapter-specific default.

Saved means the entire selected generation and required receipt/history survive the declared
failure model via an actual durable boundary. Conflict means the supplied expected generation
failed the atomic gate, not merely a busy database/I/O error. Input refusal is pre-effect;
load/corruption failures are not unsupported quantities. Errors/termination/lost responses
once writes may have begun are Uncertain unless the qualified adapter can establish otherwise.
A backend lacking the required durable capability explicitly remains unqualified for Saved;
never weaken the common meaning to make an experiment green. Readback may only see cache.
Required sync errors need an actually propagated completion contract, not just queried flags;
creation/replacement/deletion of required files needs qualified namespace/directory lifecycle.
Input admission must precede any acquisition/activation that can write or recover, not just
the final INSERT/commit. Opening a store for writing may already perform backend recovery
before candidate publication; a storage/lifecycle refusal there is not a universal assertion
that no physical effects occurred.
Read-only acquisition may refuse when recovery needs writes; diagnosis is not permission for
implicit recovery, and explicit recovery still requires complete evidence requalification.

Versioned household representation, physical schema, request identity, retention/upgrade and
backup format remain concrete implementation decisions. Backend changes need information-
preserving export/import and requalification, not implicit migration or cross-store token reuse.
Exact signed quanta/Measures,
correction/date/Reversal provenance and independent support survive round-trip; synthetic
fixture v2 is an oracle, NOT chosen canonical storage. Compare adapters with the same logical
save/restart/conflict/recovery scenarios plus backend-specific fault hooks and declared host/
device assumptions; same scenario is not identical fault mechanics or universal qualification.

## Client access direction

Requested product goal: one user's laptop, phone and AI chat can both record and inspect
household state. Native Notty TUI is the desktop preference; browser UI serves phone and
can also serve desktop. Evaluate Bonsai for that named consumer if compiler/dependency/
interaction costs are acceptable, with a simpler web view as an alternative. This extends
the eventual access goal, not authorization to deploy a public service or use real data.

```text
Notty desktop / phone browser (Bonsai candidate) / AI-chat adapter
                   -> authenticated application entrance
                   -> admission + current-generation publication / coherent query
                   -> one selected authority through Persistence
                      canonical representation/store to qualify; Unix now, MirageOS goal
```

Transport/API and auth design remain open. Clients never implement another authoritative
ledger, allocate durable identities or bypass admission; drafts/offline caches are not main.
Queries expose generation and qualified Exact/Known_present/unsupported/refusal, never stale
cache as current truth or failed load as empty. Publication rechecks current evidence and
expected generation; UI preview/Irmin 3-way merge is not authorization. AI retains supplied
input/uncertainty; missing payment/date/support facts cannot be filled as truth. Confirmation/
automation policy needs its own qualified operation; not all clients require manual review
by an invented universal rule. Branch names are not access control; restrict bot/client
capabilities and qualify authentication, replay/idempotency and uncertain results separately.

UI libraries/Core/Async, if required by an accepted browser candidate, stay in its outer
package/build environment, not Domain/Application or automatically in the Mirage guest.
A browser frontend may use a separately reviewed toolchain without changing the qualified
backend compiler. Protocol quantities must preserve unbounded exact decimal values/Measures
and evidence roles, never coerce to JavaScript Number or manufacture zero. No canonical
wire format, separate frontend compiler, toolkit install or permanent dependency is selected.
Bonsai/secondary UI exploration is deferred by current priority; no full LOAM parity first.
A useful record/save/query path needs qualified reference persistence. MirageOS minimal
composition is not a claim of ultra-security or qualified always-on deployment.

## Structured operations and diagnostic availability

> LOAM Core must answer household questions structurally, without knowing how those
> questions were asked or how the answers will be presented.

Domain owns evidence/arithmetic; Application owns concrete household operations and typed
answers/refusals. Natural-language interpretation, speech, LLMs, UI and runtime are outer
adapters. Retained description/message text is evidence, not a Core language interpreter.
Use small operation functions, not a universal command bus or all-purpose answer record.
GetUsableToday, GetBalance, GetScheduled, DiagnoseHousehold and RecordTransaction are future
use-case examples, NOT implemented APIs or new fundamental Transaction/Budget types.
Current conditional quantities are not today's spending permission; absent Scheduled is not
an empty schedule. A "today" operation must receive explicit date/context, not read a hidden
clock. Time/entropy/I/O are owned outside the engine; supplied inputs still need admission.

Answers keep exact Quantity + explicit Measure/coordinate, outcome and evidence, with
operation-specific warnings/next-payment data only when meaningful and qualified. Measure
is not necessarily currency; display scale/FX must not be invented. Exact, Known_present and
unsupported are not one optional amount defaulting to zero. Presentation/CLI/Web/conversation
render structured values; human strings/exit codes are not the shared household protocol.
Transport preserves exact decimal quanta, not floats/JavaScript Number. Existing .mli APIs
already provide the core pattern; no omnibus response schema is needed now.

Mutations take typed commands through shared admission and the outer publication orchestration.
AI/voice input is an untrusted proposal, preserving original supplied text and uncertainty;
clients never write internal/canonical state or invent missing payment/date/support facts.
Validated/accepted for admission is NOT recorded. A recording receipt must identify the request
and generation with its qualified publication guarantee; Saved, pre-effect Rejected, Conflict
and post-effect Uncertain cannot be collapsed into Accepted/Rejected. Reconciliation follows
[Persistence](#minimal-persistence-contract), not blind retry. No universal manual-review policy.

A future host should remain available for structured diagnosis/read-only inspection when
household loading fails, without claiming that every fault permits every answer. Startup
liveness, query availability, household-evidence sufficiency and durable publication are
separate. Prospective Healthy/Degraded/RecoveryRequired labels need checked scope/generation
(where known) and structured causes, not one boolean or a mandatory global health enum.
MissingEvidence/InvalidAnchor concern semantic support; UnsupportedVersion/CorruptStorage
concern acquisition; StaleDerivedState concerns rebuildable projections; PartialWorld concerns
incomplete coverage. These are design examples, not currently implemented codes. A normal
unsupported query or absence of an optional fact is not by itself corruption/service failure.

Partial reads must identify readable/unreadable scopes from one coherent generation, retain
faults/unsupported evidence and qualify each answer's required coverage, reference closure and
support. No silent row filtering, cross-generation mixing or presenting a readable subtotal as
an exact current balance. A missing correction could change even a readable Event's terminal.
Unaffected independently qualified answers/inspection may remain available; affected answers
fail closed. If complete query prerequisites cannot be established, return unavailable, not
zero. A stale derived index may be rebuilt only from qualified canonical evidence, never used
as fallback authority. Publication remains blocked unless that operation's full prerequisites
and current-generation/durability gates are established; read-only liveness is not permission
to mutate. Recovery/older-generation inspection must be explicit, never implicit current truth.

Current Actual_source/Current_quantity_query admit whole images and the synthetic decoder
refuses malformed input; none implements partial-world admission or a health service. Keep
these guarantees. Diagnostic acquisition and future scoped operations are separate capabilities,
not filtering until an existing gate accepts. No physical section layout, recovery service,
Voice/LLM/Mirage implementation or new dependency follows from this direction.

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
| Actual source | Ordinary + Exchange/Reversal subset: identity, Exchange, Reversal, all Effects nonzero; independently qualify targets, admit inverse sides; dates, Event corrections, descriptions, Merchants, root original amounts, relation units, closed discharge facts |
| Open relation units | Independent IDs, exact retained Event/key source, explicit Household/External direction, positive per-unit/aggregate absolute source bounds; no discharge/completeness/remaining amount |
| Relation discharges / remainder | One opaque relation generation; closed Event/target refs, unique pair, no self, positive individual/aggregate target bounds; exact conditional remainder, not physical support/completeness |
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

## Terminal quantity evidence explanation

[Presentation explanation](../presentation/current_quantity_explanation.mli) queries ONE admitted
quantity image and returns its existing typed outcome alongside terminal text. It displays supplied
premises, exact answer-bound assertion cuts, selected/excluded terminal Effect occurrences with
Event-local positions/keys, and actual retained correction edges in root-to-terminal traversal order.
Application derives paths only after whole graph admission and retains each assertion answer's own
cut; no consumer pairs it with another group. Root order is enumeration, not chronology. Original
and superseded Events remain retained; excluded occurrences do not contribute to the delta.

The view never recomputes the answer or infers support from activity. Presence has no scalar;
unreflected touch invalidates a supplied presence even at net zero. Unsupported quantities stay
unknown. Escaped identities/keys and unbounded signed quanta survive presentation. Traversal/rendering
cost is additional to indexed lookup, not a new cached fact, shared answer ontology or authority.
No file acquisition, metadata inheritance, recording, clock or live-snapshot qualification.

## Experimental versioned-text read

Concrete consumer: `bakhlo inspect-current-text` acquires a named synthetic document; pure
outer `bakhlo.text` / `Bakhlo_text.Read.of_string` decodes and wholly admits it to the existing
opaque `Current_quantity_query.t`. Text depends only on Application/Domain + Base/Zarith,
not CLI/Presentation/filesystem/runtime. Domain/Application remain unchanged; no new command
bus, answer/health schema or external dependency. CLI renders typed outcomes, not a shared API.
Exact answers carry Quantity/coordinate/premise; source/frontier/group/presence accessors retain
original Events, correction edges, descriptions and independent cuts. Presence has no scalar;
missing/stale support is typed unavailable, not failed-load/default zero.

[Input interface](../text/input.mli) owns the complete bounded grammar and escaping contract:
`bakhlo-read 1 ordinary-actual-quantity`, quoted exact bytes, unbounded decimal tokens, explicit
end/newline. Ordinary Actual + base validity + Event corrections/descriptions + four support
families ONLY; other facts/families/versions/profiles refuse. This is not a full-household world,
canonical storage/wire grammar, automatic richer-fixture projection, generation allocator or
production parser security/performance qualification. Future profile broadening needs its own
information-preserving review; no metadata may be filtered to make this profile accept it.
[Read interface](../text/read.mli) owns Input -> Source -> Support refusal staging and conditional
answer scope. Shell alone owns read-only file acquisition/errors; no write/activation/recovery,
older-world fallback, Saved or spending permission. Tests assume one exclusive stable synthetic
file owner; this is not a concurrent-filesystem/coherent-generation acquisition protocol.
The [synthetic example](../examples/ordinary-quantity.bakhlo) is directly inspectable without a DB
or original runtime. That does not establish durable
canonical publication, extraction/backup/upgrade, lossless encoder or production adoption.

## Scoped native LOAM-input read

The pure `bakhlo.loam_read` / `Bakhlo_loam_read.Read.of_string` now decodes a supplied
HouseholdImage v2 byte string directly into retained outer evidence plus the EXISTING opaque
conditional quantity image. [Read interface](../loam_read/read.mli) owns staged errors/accessors;
[Input](../loam_read/input.mli) is unadmitted, [Envelope](../loam_read/envelope.mli) is physical
framing only. No Python, generated OCaml payload, second answer ontology or Core changes.
Base/Zarith + native OCaml UTF-8 decoder only; no new package or filesystem/runtime dependency.

Framing validates UTF-8 and counts Unicode scalars, never UTF-8 bytes or graphemes; raw original
bytes and ordered opaque sections survive, including unknown, empty and absent distinctions.
The read profile requires physically present Actual and all FOUR supported quantity-section
frames; missing is profile-unavailable, not corruption or automatically empty support. Actual
v1-v4 representable Events/keys/date history/corrections/descriptions/Merchant/original amounts/
Exchange/Reversal/relations/discharges map directly to existing types. Settlement or unknown
Actual records refuse wholesale. No row filtering, date winner or implicit support.
Logical Movement publication-request -> retained Event origins stay qualified at this OUTER
boundary (exact unique tokens/owners/closed references), including superseded Event identities;
not payment truth, Core ontology, inherited correction metadata or durable Saved/retry protocol.

Envelope/decode -> whole Actual -> origins -> whole support precedes lookup. Other household
sections remain opaque and UNADMITTED; this is not full normalized LOAM/household qualification
or Bakhlo canonical storage/encoder. `quantity_image` exposes existing typed Exact/presence/
unknown outcomes, quantities/Measures/premises and retained source/cuts. The terminal-only
`inspect-loam-quantity FILE LOCUS MEASURE` uses an explicit file, never discovers an operational
root, consults a pin, falls back to previous/legacy files, repairs or writes. The directly
inspectable [synthetic LOAM-input example](../examples/loam-quantity.loam-input) yields wallet/jpy 990
with supplied assertion 1000 and unreflected delta -10; it is NOT an operational fixture.
File acquisition
uses the existing shell reader; it DOES NOT establish coherent live capture/no-follow/stability,
external completeness, household authority or physical durability. Caller must supply one
coherent evidence generation; native acquisition qualification remains separate. No new
operational-data execution or fresh acquisition was needed to qualify this synthetic increment.

## Read boundary

CLI pure parsing creates typed inputs. Quantity_literal shares only the signed-decimal
lexical rule across the two existing commands; each retains its own diagnostics/admission.
Event structural key admission occurs at END-EVENT;
syntax and structural refusals stay distinct. Source/support admission precedes lookup/text.
Only the shell reads an explicit fixture/text or LOAM-input file. Failure/malformed/unsupported input never
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

Open_relations qualifies independent relation units against retained keyed Effects,
including superseded observations. Exactly one Household and one role-free External party
supply debtor/creditor direction; source sign, Locus, Merchant or descriptions supply none.
No duplicate Measure: admitted source Effect retains it. Positive quantity is individually
bounded by source magnitude, and ALL units sharing exact (Event, key), regardless of
party/direction, are bounded in aggregate. Typed transient source keys never concatenate
identity strings; same-coordinate/different-key and cross-Event reused keys stay distinct.
Separate relation IDs allow otherwise equal independent units; any ID reuse refuses.
Global identity gate precedes per-declaration Event/key/endpoints/positivity/individual
bounds, then aggregate totals in original declaration order. This differs from upstream
indexed per-row aggregate diagnostics, not this narrow accepted whole-family shape.
Raw facts/order/Event memory and abstract admitted rows retain exact Event/Effect payloads;
indexed ID lookup None is unresolved/unsupplied, not known-none, zero or completeness.
Source gate follows original amounts, before support/query; unrelated errors refuse the
whole source. No physical exemptions, selection, correction/Reversal inheritance/retargeting
or inferred fulfillment. Corrections can leave relation sources historical; views are
positive observed units, not remaining debt. No target-local orphan/crash-residue acquisition
or completeness consumer is qualified. RELATION id event key <debtor> <creditor> quantity
uses explicit HOUSEHOLD / EXTERNAL party endpoint fields and allows forward references.
SETTLEMENT/PURPOSE stay unsupported in the synthetic reader.

Relation_discharges consumes ONE opaque Open_relations image, deriving retained Event memory
and targets from it; it cannot accept independent Event/target generations or manually forged
admitted target lists. Per fact: Event -> target closure -> exact correspondence uniqueness
-> Event differs from target's source Event -> positive -> individual target bound. After
all local facts qualify, full sums per target are checked in original discharge order.
Local diagnostic order differs from upstream target-order checks, not accepted closed
shape. Identical pair repeats refuse; one Event can fulfill different targets without a
new global Event budget. No DischargeId, duplicated Measure, Effect matching/allocation,
physical sign/destination inference or date chronology. Plain empty/unrelated-Measure
Events are allowed as explicitly supplied fulfillment occurrences, not inferred payments.
Whole-source acquisition refuses every missing raw Event/target, unlike upstream target-local
inert pre-Event crash projection; no activation/recovery path is qualified here.
Source gate follows whole relation admission before support/query. Raw facts/order/source
and exact admitted Event/target views survive, including noncurrent observations.
Corrections/Reversal do not transfer/deactivate retained correspondences. Abstract remainders
retain target plus admitted rows/exact sum in original relation order. Quantity subtraction
is a read projection, never a new canonical balance: known target/no rows retains initial
quantity within this snapshot; unknown ID is None, not zero. This does not establish external
fulfillment truth/completeness or physical exact support; zero remainder is not a paid-status
primitive or recording permission. DISCHARGE event target signed-decimal is synthetic only.

The current source is NOT full normalized Actual: other structured metadata,
relation completeness/lifecycle, target-local crash activation and settlement remain unqualified. Date evidence is not proof of occurrence
truth, recording chronology or historical completeness.
Queries do not establish household authority, purchasing power or spendability.

## Future operational work

[Persistence requirements](#minimal-persistence-contract) own coherent read, conditional
publication and uncertain-result reconciliation across adapters. Bind operation admission,
current ownership, identity/retry, atomic visibility versus durability, diagnostics and
backup/upgrade to the first reference consumer and relevant fault instruments; structural
preview is not recording permission. SQLite transactions/WAL/synchronisation settings are
adapter mechanisms to qualify, not replacement household semantics or automatic power-loss
proof. Irmin CAS/batch and experimental FS/runtime barriers face the SAME contract.
A local mutex CAS is neither multi-process nor crash atomicity. Offline copy/reopen is
bounded restore evidence, not a live backup/off-device policy. No shadow canonical balances.

UI is not implemented; CLI is the development/read entrance. [Client access direction](#client-access-direction)
records desktop Notty preference/optional Bonsai browser evaluation; toolchains, protocol,
authentication and compatibility need concrete qualification before adoption. Clients consume
semantic answers rather than recomputing meaning. Prior hosted, guarded SPT engine and
block-persistence evidence belongs to VERIFICATION, not production support. No permanent
adapter or main Lwt/SQLite dependency yet; the ignored native SQLite consumer is now exercised.
[Current direction](#selected-product-direction) pauses SQLite canonical adoption while
human-readable canonical text is evaluated; optional indexes need concrete consumers.
MirageOS is an explicit future goal with experimental support today; no runtime/store
combination becomes a prerequisite for semantics/publication.
No speculative load/navigation state, adapter, cache or framework belongs in the engine.
