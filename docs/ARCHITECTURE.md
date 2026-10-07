# Architecture

A modular monolith with an independently usable immutable OCaml engine.

```text
bin/main -> CLI -> Presentation -> Application -> Domain
            |-------------------->|------------->|
```

CLI also consumes the pure outer Text/LOAM-read/S-expression adapters, which depend inward
on Application/Domain, never Presentation/CLI. Clients also use Domain types; dependencies
never point outward. Engine native targets build without these adapters/Presentation/CLI/UI.
Engine runtime dependencies are Base + Zarith; approved Parsexp is outer only.
There is no canonical storage, clock, mutable business state or generic service framework.

## Selected product direction

After 07cd41f, user approved putting data sovereignty and a human-readable canonical
representation before physical store adoption, with MirageOS an explicit future product goal.
This pauses the previous Unix+SQLite canonical-reference adoption route, not its earned trials.
The goal remains a long-lived backend-neutral household application, not a Lean layout clone.
Core, Admission and Publication meanings must not depend on a particular database/filesystem/
runtime. Domain/Application stay immutable and Base + Zarith-only; outer publication consumes
the [minimal Persistence contract](#minimal-persistence-contract), not backend transactions.

### Everyday household questions, not a language model

The product should be an ordinary, friendly household machine that works without AI: small
explicit questions answered by deterministic operations over admitted evidence. Helpful replies
explain what is known, unknown and worth checking; they do not invent missing facts or silently
add a zero origin. AI/NL interpretation is optional and outer, never a specialist LLM/SLM or
required runtime. Daily-use record/save/reopen/correct remains unqualified. The ignored
synthetic TUI consumer now connects record/select/reopen/correction; it is not an operational
store, canonical format or durable Saved implementation.

Retain full evidence for the owner and information-preserving extraction. External recipients
receive only authorized operation-specific projections, not raw history/credentials by default;
even quantities/coordinates can be sensitive. Detailed explanation and ordinary quantity access
need distinct disclosure decisions. An OCaml signature narrows typed reachability, not principal
authorization or process isolation. A production composition should omit developer shell/general
file entrances and expose household operations only; this is a goal, not a current deployment.
Unix and Mirage may enforce capabilities differently; neither removes admission/durability or
host/device/network threat obligations. Do not delete internal provenance to hide it from clients.

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
| Versioned canonical text | S-expression selected; [minimal development profile](#minimal-ordinary-s-expression-book) implemented; whole-household schema/physical store NOT adopted |
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
synthetic profile, using independently supplied fixture inputs only as an oracle. Publication,
scale/reuse and bounded I/O trials now supply comparison evidence, not an adopted layout.
User now prioritizes a minimal ordinary record/reopen/correct/backup loop over interchange.
Reuse existing native consumers, not a full LOAM feature rebuild; [safe interchange profiles](#safe-data-interchange)
remain future preservation constraints. S-expression canonical design and the
[canonical evidence review](#canonical-evidence--inherited-format-review) remain in force;
experimental text storage is not promoted by this sequence. [HANDOFF](HANDOFF.md) owns next steps.
User approved a bounded private read-only LOAM comparison before publication work: establish the actual selected revision/input,
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
No production canonical codec/store, writer/index/maintained benchmark or Mirage/UI feature,
full parity prerequisite, original mutation/migration, main-lock change or implicit Saved.
The ignored native text trial and [bounded scale review](VERIFICATION.md#synthetic-text-scale-and-history-cost)
now provide selection/receipt and 10k/100k copy/reopen observations. Query lookup is cheap once
one image is admitted; repeated whole admission, per-group cuts/aggregation and retained complete
snapshots are measured costs. No cache/index/layout selection follows automatically: preserve
current evidence requalification, independent cuts and original answer-bound paths/history.

`text/Read.document` now seals the COMPLETE admitted original bytes with their existing query
image; no caller-supplied bytes/image pairing. `Propose.append_document`/`correct_document`
consume that exact admitted base and WHOLE-admit new candidate bytes. Raw-string entrances
retain their staged refusals. A candidate exposes its sealed base/new documents for one concrete
native consumer, not file/currentness/publication authority or an authorization projection.
The ignored [reuse review](VERIFICATION.md#whole-admitted-document-reuse-and-fresh-publication-gates)
freshly reads every actual envelope before activation AND under the lease: only complete exact
bytes with the same namespace/generation/frame may reuse captured admission inside one call.
Changed frames/documents must qualify afresh, missing files refuse, and selected generation/base/
receipt gates still apply. Pure immutable reuse is not a persistent cache, frozen live read or
permission to publish. Whole source/support admission is never shortened to the asked coordinate.
This removes repeated reconstruction, not complete generation retention or startup history walks;
its stronger time/RSS hypotheses were only PARTLY met. No production writer/store/Saved follows.

## Canonical evidence / inherited-format review

Source-only review at LOAM `f82f4c45498ce9b3c51a76acb7189588a5f74718`; not an inventory of
which families the user's data actually contains. [Evidence](VERIFICATION.md#canonical-evidence--inherited-format-review)
owns owners/scope, [References](REFERENCES.md) provenance. Inherit retained meanings and useful
counterexamples, not every LOAM filename, wire delimiter, old runtime aggregate or research
version number. No canonical grammar/store, deletion or migration is selected by this review.
User permits representation migration when a better design is demonstrated; permanent LOAM
wire compatibility is not required. Actual transition still needs selected scope/representation,
original preservation, information/interpretation/receipt correspondence and refusal qualification,
then explicit authority cutover. This permission does not authorize guessed facts, identity
normalization, immediate original writes, dual authority or automatic legacy cleanup.

### What must not disappear

The current HouseholdAuthority registers these 13 named payload families. Registration is not
proof they are all present, all required for every question, or all supported by Bakhlo. Family
names/physical section splits may change; the independent distinctions below may not silently
merge. `Unknown`/unadmitted payloads remain unresolved, never classified as disposable.

| Current LOAM family | Independent information / consequence of loss |
| --- | --- |
| Actual | Retained Event identities, every signed Effect/Measure/Locus/key occurrence, base dates and separate date-revision edges, Event corrections, descriptions, Merchant/nonmerchant evidence, Exchange selections, original amounts, Reversal, relations/discharges and settlement provenance. A current transaction alone cannot reconstruct these |
| Scheduled | Retained occurrence identity/day/Measure/signed changes and typed terminal source/target: Actual completion, Scheduled replacement or retirement. Not inferred from physical activity |
| Capacity | Allocation Movement identity/Measure/signed Purpose-or-unallocated changes and independent effective date. Not a physical wallet balance |
| Attention | Context, explicit due/none/undetermined distinction and dated resolved/dropped closure. Not merely a current UI badge |
| ActualRouting | Locus -> Purpose or explicit unmanaged at initial/dated effective coordinates. Historical selection is not recoverable from a current label |
| ScheduledRouting | ScheduledId x Locus -> Purpose/unmanaged at an effective date. Similar mechanics do not make it Actual routing |
| AccountingRole | Explicit partial Locus -> role assignment. Missing role is unresolved, not guessed from flow direction/name |
| LocusAdmission | Explicit allowed NEW-write vocabulary. Historical occurrence is not permission to record there now |
| ZeroOrigin | Explicit Locus x Measure completeness-from-zero claim. Activity/net zero/catalog membership cannot recreate it |
| OpeningSupport | Coordinate -> independently designated opening Event. Quantity lives in that Event, not duplicated in this relation; an opening-looking Event does not itself authorize support |
| CurrentQuantityAnchor | Exact observed assertions bound to each independent reflected-root cut. Anonymous groups factor representation; assertion/cut binding matters, stable group identity/order does not |
| CurrentQuantityPresence | Known nonzero coordinate plus reflected cut, exact amount unknown. No invented scalar/sign or arithmetic |
| BoundedHistorySupport | Coordinate/start-day completeness claim enabling bounded historical reconstruction with other evidence. Not inferred from oldest Event or endpoint equality |

Actual's `OPERATION` maps a logical request to its ORIGINAL retained Event. It is publication
provenance, not payment identity or Event chronology. Preserve its one-to-one association where
supplied; it can live in a separate logical receipt layer, not be discarded with temporary files.
Settlement's independently measured commitments, attribution/netting, revisions/retractions and
quantity-bearing extinguishment are not automatically redundant with source-Effect-bounded
relations. Bakhlo currently refuses settlement rows; opaque retention is not their admission.

Outside the household payload, Measure decimal-scale metadata affects how human input/output
interprets exact quanta. LOAM prevents changing a used Measure's scale without migration; its
historical missing-metadata scale-0 convention is NOT a Bakhlo inference rule. Preserve explicit
interpretation policy/version in any complete extraction. Other external config/catalog contents
are not exhaustively classified here: file placement alone does not make them disposable.

### Separate facts, policy, publication and views

- Retained facts/observations/relations and independently supplied write/classification policy
  are canonical inputs; reports, current frontiers, totals, remainders and encoder indexes are
  derived. An `ASSERT` amount is an independent observation, NOT a cached report balance.
- Writer ownership, observed-generation gates, receipt association, staging/readback and honest
  interruption/recovery outcomes remain requirements. Exact `.prev`, stage/lock filenames and
  whole-snapshot layout are implementation choices, not household facts or qualified Saved.
- Manual text changes are proposals through whole admission/current-generation publication,
  not permission to edit live authority, merge by Git or manufacture recording time.

### Confirmed shape costs, not blanket deletions

1. **Owner editing:** HouseholdImage stores opaque section bodies with Unicode-scalar lengths.
   An inner edit requires updating its outer length; wrong/truncated frames refuse. Preserve
   exact untouched/unknown payloads and absent != present-empty, not necessarily length fields.
2. **Old physical factoring:** Scheduled has one semantic terminal relation but encodes three
   mandatory Completion/Retirement/Replacement substreams and headers. A clearer representation
   could state the typed target once; it must preserve target meaning and conflict refusal.
3. **Legacy entrypoints/documentation:** current root Actual selects `household.loam`/Actual,
   while explicit `actual.loam` remains diagnostic/migration input and a historical lock identity.
   Upstream README/Beancount guide still describe older canonical filenames. Do not copy those
   descriptions or mistake a leftover path for another authority; no sibling cleanup here.
4. **Versions are not automatically dead:** the Actual encoder actively chooses v1/v2/v3/v4
   by retained settlement families. Anchor v1 reads lift into v2 groups; Household outer v1 never
   became production. New Bakhlo need not inherit every spelling, but old operational bytes
   cannot be dropped merely by their version label. No actual unused-data claim is earned.
5. **Our prototype is not a new requirement:** Bakhlo trial keeps complete generations and
   admits all selected ancestors; LOAM's source layout selects one complete household plus
   `.prev`, while original Actual corrections remain inside the evidence. Neither layout is
   the household ontology. A future layout need not clone our snapshot chain, but must preserve
   original evidence/receipts/currentness; existing trial gates must not be weakened or cleaned.

### Journal readability without journal-as-truth

LOAM's existing readable journal/Beancount views select current Events; they omit superseded
originals/date history, support and policy families. The plain journal also omits Effect keys.
Two histories with original amount 10 versus 12 and the same corrected 15 can yield the same
current journal but require different history answers. The same wallet Effect -10 and assertion
1000 yield 990 with an empty reflected cut, 1000 when that root is reflected: a journal alone
cannot distinguish them. These are synthetic illustrations of earned boundaries, not new tests
or facts about the user's data. Beancount Open dates are target scaffolding, not source origins.
This proves loss in THESE projections, not inability of every hledger journal/metadata extension.

The stopped scoped private comparison now has local current/candidate excerpts, generated with
the existing native read profile gate first. [Evidence](VERIFICATION.md#stopped-private-representation-comparison)
records limits: excerpts are not an encoder/grammar or full-household migration qualification.
Compare retaining the current lossless container against this **recommended logical candidate**:

- An owner-readable fact book, not a current journal or chronological command-replay log.
  Event records retain every Effect/key occurrence and base metadata; corrections, occurrence
  revisions, reversals and fulfillment keep their distinct explicit references. No historical
  recording clock or normalized identity is invented; current frontiers/totals are derived.
- Independently supplied observations with reflected-root cuts, opening/coverage/history/presence
  claims remain visible beside activity, not cached balances. Cut factoring is allowed; anonymous
  group syntax does not become stable household identity. Absence/declarations/empty still differ.
- Explicit routing/classification/NEW-write policy and other retained families remain distinct
  typed parts, not overloaded Event/Account/Budget/Month types or guessed defaults. Unknown parts
  remain unadmitted/retained until resolved, not erased because a current UI ignores them.
- Exact unbounded integer quanta and interpretation policy/scale belong to one coherent publication
  scope; UI may show human units only with qualified scale. Current capture retains external scale
  bytes/absence, not a frozen complete config bundle or a license to infer missing-scale 0.
- Request -> original Event association remains explicit logical publication provenance. A journal
  is a separate useful view. Readable delimiters/escaping should remove outer scalar-length editing,
  but no exact grammar/codec, physical file split, append/replace, full-snapshot chain or store is chosen.

This candidate avoids freezing old wire structure without discarding meaning. It is not yet
proved cheaper/lossless for the complete household. Resolve the field/interpretation scope and
unknown families before canonical codec/migration; keep original archives and earned trials
intact. Further trial UI/setup and physical-store expansion stays paused meanwhile.
For independent syntax review, the [synthetic-only pasteable comparison](FORMAT_COMPARISON_PROMPT.ja.md)
pairs S-expressions + minimal Parsexp with custom fact text under the SAME logical obligations.
User now selects S-expression syntax; braces and both comparison grammars were illustrative.
Package metadata is not measured runtime cost/portability or codec qualification; internal derived
sexps are not the storage schema. Exact grammar/schema/production library installation remain separate.

### Selected S-expression direction — long-term boundaries

Long-term constraints, not a full-household codec/store or cutover; the bounded implemented
profile below exercises only its declared subset:

- **Stable protocol:** one explicit data-format version independent of app/OCaml/library versions.
  Named fields/typed references and explicit absence states; no automatic unknown-field dropping,
  duplicate singleton fields, missing -> empty/zero defaults, identity normalization or host-int/
  float quantities. Parser accepts syntax; versioned unadmitted Wire DTOs then whole semantic
  admission authorize queries/proposals. Minimal Parsexp belongs outside Core; installing it is
  a separate dependency decision. Do not derive the canonical protocol from private domain types.
- **Fact book, not replay:** retain originals, Effect/key multiplicity, correction/date/Reversal/
  fulfillment distinctions, independent observations/cuts/coverage, policy and interpretation.
  Current frontiers/totals/indexes are derived. Occurrence dates/publication tokens are not a
  manufactured historical recording clock. Unknown/unsupported inputs stay retained/unadmitted.
- **Selected evidence generation, not flattened state:** current book is the currently selected,
  self-contained CANONICAL EVIDENCE generation. Retain ALL supplied in-scope facts, including
  superseded Events, explicit relations, observation/cut ownership and necessary policy/provenance;
  current views/consumer questions do not define deletion. Separately retain immutable generations/
  archives and original-result receipt evidence. Ordinary admission need not walk every physical
  ancestor in a NEW design; this does not weaken existing trial checks or justify pruning artifacts.
  Exact file names/splitting/append versus replacement and lifetime retention are still undecided.
  Do not claim original Event alone reconstructs an original receipt's whole source/result.
- **Publication separate:** edit a candidate, whole-admit/read back, revalidate expected generation
  and ownership, then publish at a qualified boundary. Uncertain interruption/sync/close outcomes
  remain uncertain; readback/valid S-expression alone is not durable Saved. No automatic fallback
  to older state, startup recovery/upgrade, dual writer or blind retry under a reused request.
- **Human management:** deterministic readable UTF-8 printing and diagnostics with source positions;
  quantities remain exact, unit display needs qualified interpretation. Essential memos are explicit
  data; comment/format preservation via raw text/CST is a separate editing requirement, not assumed
  from generic AST reprinting. Preserve meaningful list order/multiplicity; sorted output is not time.
- **Evolution/assurance:** explicit version-to-version conversion into a FRESH target, originals and
  receipts retained, independently checked information/interpretation correspondence before cutover.
  Reuse synthetic roundtrip/refusal/correction/support laws; only add tests for unresolved boundaries.
  Full-family/unknown/config gaps still block claiming lossless household migration. Measure load/
  rewrite/memory before adding indexes/shards; rebuildable caches never replace admission or facts.

Before production codec implementation, user requested [four synthetic v1 candidates](../examples/sexp-v1-candidate/README.md)
for reviewing retained evidence, ordering independence, precision/absence and the invalid flattened
counterexample. These are hand-authored human-review inputs, not an adopted schema, decoder or
executed admission/roundtrip test. No private capture/result is used in these fixtures.
User subsequently requested [paired delimiter-free plain text](../examples/plain-v1-candidate/README.md)
and a [minimal syntax comparison](../examples/syntax-bakeoff/README.md) to review readability.
After comparison, user confirms **S-expressions as the canonical evidence syntax**; plain text
and journal remain comparison artifacts, not a second maintained codec. Field spelling,
collection declarations, full-family/receipt/interpretation scope still need schema review.
The [isolated codec trial](../experiments/sexp-codec-trial/README.md) is experimental evidence only;
whole-household Parser/DTO/writer, further dependencies and migration need separately bounded decisions.
User now approves main Parsexp v0.17.0 and the minimal ordinary profile below only.
No new storage framework, permanent legacy syntax matrix, event-sourcing command bus or
every-generation full-world startup reconstruction.

### Minimal ordinary S-expression book

[`bakhlo.sexp`](../sexp/book.mli) owns the development-only `(bakhlo 1 ordinary-quantity)`
profile. [Synthetic walkthrough/schema](../examples/ordinary-sexp/README.md) owns its shallow
named field spelling. Explicit provided/empty/not-supplied declarations cover each supported
collection exactly once. Measure IDs/scales, retained ordinary Actual Events/base dates/optional
text/ordered keyed or anonymous Effects, Event corrections, independent exact observations/cuts
and zero origins survive print/reopen. Unknown/missing/duplicate fields and richer evidence refuse;
excluded families are NOT supplied, not asserted empty household facts. No richer-image converter.
The adapter calls existing Event/Actual-source/quantity admission; new Event proposals additionally
call Movement admission. Domain/Application and their closed semantic gates are unchanged.

Opaque Books retain original input bytes and one admitted image. Opaque candidates retain the
immutable base and complete admitted printed/reread document. Printing is schema-owned, not derived
from OCaml records: valid UTF-8 remains readable, invalid/control bytes escape without normalization.
Comments/whitespace are not canonical data; essential memos are explicit text. Per-family order and
Effect/cut multiplicity remain; canonical family ordering is not chronology.
`inspect-current-sexp` reuses one admitted image and existing answer/explanation/summary owners.
`stage-current-sexp` prepares whole candidates before exclusive fresh-file creation. Existing files/
symlinks refuse; no overwrite, selected root, repair, implicit support, receipt or authority.
The Unix shell closes and checks exact readback bytes; uncertain create/write/close/readback keeps
any artifacts and forbids blind retry. This is candidate staging, NEVER durable Saved. Stable supplied
files/cooperative parents are assumptions, not concurrent capture/publication guarantees. Wider
family/interpretation preservation, qualified publisher, backup/restore and real-use cutover remain
separate gates. [Verification](VERIFICATION.md#minimal-ordinary-s-expression-book) owns executed limits.

### Readability and extension rules

User prioritizes owner readability and long-term maintenance/extension, not shortest spelling.
Use the [minimal S-expression candidate](../examples/syntax-bakeoff/01-minimal.sexp) as review input,
not an adopted schema:

- Independent facts use shallow top-level records. Named fields expose meaningful roles; do not
  add redundant wrappers, ambiguous positional shorthand, magic strings or record-specific mini-languages.
- One readable deterministic layout owns indentation, field order and line breaking. Keep short
  leaves compact and substantial records multiline; a semantic edit should produce a local diff.
  Printer ordering is presentation, not chronology; meaningful Effect order/multiplicity survives.
- Preserve explicit empty/not-supplied/unknown variants even when removing them would be shorter.
  Essential text belongs in data fields, not solely comments. Lexical preservation is a separate need.
- Extend through explicit versioned record/field definitions, not internal OCaml deriving or a
  generic property bag. Missing/duplicate/unsupported known fields refuse; retained opaque evidence
  is not admitted meaning. A new family must not acquire implicit empty state in older inputs.

## Safe data interchange

Approved future design direction, DEFERRED behind the ordinary-use loop; NOT implemented
export/import or proven hledger compatibility.
S-expressions remain canonical evidence; adapters remain outer and format-specific. Share exact
arithmetic, admission and publication mechanisms, not an invented universal import ontology.

### hledger journal export profile

The first bounded candidate is a **current ordinary single-Measure Movement projection**:

- Resolve current Events and their occurrence dates using existing qualified relations over one
  whole-admitted coherent source. Never choose by file order/latest date or include both superseded
  and replacement Events as current activity. Sorting the output does not change source meaning.
- Supply explicit Locus -> account and Measure -> commodity/decimal-scale mappings. Refuse unmapped
  or colliding mappings; a target account label is not a new fundamental Core Account type.
- Render every selected Effect occurrence as an explicit posting with exact signed decimal amount.
  Preserve order/multiplicity, including net-zero pairs; use integer scaling, never floats, rounding,
  inferred posting amounts, balancing/suspense postings or unsupported exchange/valuation guessing.
- Missing occurrence date, unsupported selected Event shape or target-unrepresentable value/text
  refuses the complete requested projection before successful output. Escaping/names/target syntax
  require an explicit tested profile; do not silently truncate descriptions or normalize identities.
- Declare source/interpretation/mapping scope and intentional evidence omissions with the result.
  Superseded history, Effect keys, independent support/cuts, policy and publication receipts are not
  promised by this plain posting view. Do not disguise observations as postings/balance assertions.
  Exported activity totals are not automatically supported Bakhlo balances or spending permission.

A journal is a disposable one-way view, not a second authority, full backup, migration or household
roundtrip format. Complete restore needs a separately qualified canonical evidence/interpretation/
receipt bundle; merely choosing S-expressions does not implement it. The custom `.journal` in
[syntax bake-off](../examples/syntax-bakeoff/README.md) is NOT a hledger compatibility example.

### Staged import profile

Each supported source format/version has an explicit bounded decoder and conversion profile:

1. Retain original supplied bytes and acquisition/source context before conversion. Ordinary checks
   use synthetic inputs; private originals/copies/results remain under existing authorization and
   ignored-scratch rules. Encoding, delimiters, dates, signs and decimal/Measure scale are explicit.
2. Decode into unadmitted source records with locations and retained external identity/metadata.
   Unsupported rows/fields, ambiguous dates, unmapped identities or unrepresentable quantities
   refuse the declared complete import, not success with skipped rows. Diagnostic fragments may be
   shown as unadmitted only. Exact known quantities do not establish origin/completeness/support.
3. Build a reviewable candidate using supplied mappings and rules, retaining provenance for every
   transformation. No default currency/date, guessed counterpart, invented observation/support or
   inferred correction relation. Any later richer conversion needs its own explicit qualified rule.
4. Distinguish stable external identity within its source namespace from coincident equal content.
   Identical date/amount/text can be legitimate separate occurrences; do not deduplicate by hash or
   content alone. Conflicting reuse of an external identity is a review/refusal, not automatic update.
5. Preview the complete candidate, conversion scope, unsupported evidence and duplicate uncertainty.
   Whole-admit before publication and freshly revalidate selected generation, mappings/interpretation,
   identities and ownership at the shared publisher. Preview is not authority; no auto-record,
   blind retry, implicit repair or operational cutover. Preserve honest uncertain write outcomes.

An exported journal reimported as new facts does not reconstruct original IDs, cuts, corrections
or receipts. Export provenance is not sufficient authority for automatic deduplication/replay.

### Qualification boundaries

Planned checks, not executed evidence:

| Boundary | Required independent observation |
| --- | --- |
| hledger syntax | Declared target version actually reads emitted journal; Bakhlo reparse alone is insufficient |
| Exact posting fidelity | Per-Event/per-Effect coordinate, signed quanta and multiplicity match independently supplied expectations, not only net totals |
| Currentness/date | Replacement with an older date and separate occurrence revision select the qualified Event/date, never maximum date |
| Representation refusal | Missing date/scale/mapping, collisions, unsupported Event/text and malformed input produce no successful partial export/import |
| Retention versus projection | Same current journal with different history/cuts remains distinct canonical evidence; journal roundtrip is not book roundtrip |
| Import identity/publication | Equal-content separate occurrences survive; conflicting external IDs and stale preview refuse without authorizing publication |

[Verification](VERIFICATION.md#safe-data-interchange-design-review) owns actual checks/limits.
Fix the export target/version and one named import source before implementing their adapters.

## Minimal Persistence contract

Production requirements, not an implemented main module/stable API. An ignored synchronous
SQLite consumer consumes coherent-read/conditional-publish functions and backend-neutral
snapshot/receipt/failure values; a native Unix text trial now also consumes ordinary proposals
with a selected head, complete retained generations and scoped receipts. Both remain experiments;
[Verification](VERIFICATION.md#unix-text-publication-consumer-synthetic-no-saved) owns the text
lifecycle controls/limits, not a main adapter or durable acknowledgement. The SQLite trial's
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

Primary product goal: one user's laptop/phone can record and inspect household state without AI;
an AI-chat adapter is optional. Desktop candidates are direct Notty and Bonsai_term, now under
an explicitly user-approved synthetic comparison; neither is adopted. Browser UI serves phone
and can also serve desktop. Evaluate Bonsai for that named consumer if compiler/dependency/
interaction costs are acceptable, with a simpler web view as an alternative. This extends
the eventual access goal, not authorization to deploy a public service or use real data.

```text
Notty or Bonsai_term desktop / phone browser (Bonsai candidate) / AI-chat adapter
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
Browser/secondary access remains deferred; no full LOAM parity first. The ignored
[paired desktop trial](VERIFICATION.md#paired-notty--bonsai_term-synthetic-draft-ui-trial)
uses identical in-memory proposals/inputs with separate renderers/runtimes. Existing main
OCaml 5.3/engine/50 are unchanged; the Bonsai consumer alone uses an isolated OxCaml/Base preview
and CURRENT engine source symlinks, not a new engine or qualified main backend. UI focus is
app-owned in BOTH candidates; this trial does not prove turnkey forms or incremental speed.
The [bilingual/four-currency extension](VERIFICATION.md#bilingual-four-currency-draft-ui)
separates Japanese/English DISPLAY labels from stable identities, memos and typed results.
An explicit trial-only decimal adapter binds versioned Measure IDs to quanta (JPY 1 yen,
EUR/USD/ILS 0.01); it neither reinterprets old jpy evidence nor defines a production scale,
locale/FX/catalog. Both frontends consume that SAME exact text conversion and engine gates.
Language changes no draft bytes; currency changes require an empty new draft, and corrections
bind the existing currency/owner. No GUI-side balances, rounding or cross-currency subtotal.

The [synthetic TUI recording connection](VERIFICATION.md#synthetic-tui-recordreopencorrection)
now consumes the EXISTING ignored Unix Store in BOTH frontends. Pure Workbench whole-qualifies
the narrower expense UI profile and reconstructs every retained original/correction, refusing
unsupported rows/support rather than salvaging a display. A small outer Recording owner binds
proposals to selected snapshots and receipts, explicit trial-only provision/namespace, fresh
conditional publication and read-only uncertainty checks. Pending requests cannot blindly retry;
original receipts are freshly separated from the displayed current generation. Unexpected cold
store files block recording without automatic repair. Normal exit/reopen is not power-loss Saved.
Shared Locale is pure Stdlib display data, independent of Unix/Async/frontend widgets; language
is presentation policy, never stored household meaning. TUI-specific key help stays distinct from
universal status meanings. Other UIs/Mirage can later consume that pure boundary, not inherit
this Unix publisher/runtime qualification. Broader localization/settings persistence and permanent
module/UI/store adoption remain deferred until concrete consumers need them.
Latest [simple S-expression UI loop](VERIFICATION.md#simple-s-expression-ui-loop) connects BOTH
existing frontends directly to Book, not a richer-image conversion. Workbench retains Book's exact
Measure/scale/initial support and every retained compatible row; unsupported UI evidence refuses.
The existing ignored publisher is parameterized ONLY by admitted document operations and a distinct
layout marker; old text consumers retain their original implementation/byte contracts. New trial
roots are `sexp-v10/stores`; old roots never migrate or fall back. Book v1 cannot represent presence:
a NEW explicit seed has Pantry UNKNOWN, not an erased old assertion or guessed zero. Main Core/Book
and package selections remain unchanged. Dedicated backup work is deferred behind human use of the
simple start→input→write→exit/reopen→correction loop; no permanent UI/store or Saved adoption.
The [科目 connection](VERIFICATION.md#synthetic-locus-addition-and-recording) extends that SAME UI:
Book v2 additionally owns an explicit exact new-write Locus vocabulary, independent of retained
historical Events/support, labels, AccountingRole and Purpose/routing. Version 2's required singleton
record states approved identities (possibly none) or not-supplied; omission never permits recording.
Pure vocabulary candidates add no Event/origin/history claim. All proposed Effects require approval;
whole historical read does not infer or require current permission. Version 1 remains its original
pure read/proposal format, but the updated trial cannot record on absent policy or auto-upgrade it.
Stable tokens are display fallback, no catalog/alias/rename framework. Workbench qualifies the full
book and an explicitly chosen expense endpoint; the form's category editor/selector consumes the
SAME Recording publication/pending/reconciliation boundary. Existing support/unknown/history remain.
Earlier increments below describe their qualified OLD text revisions, not automatic new-format claims.
The [same-currency transfer increment](VERIFICATION.md#same-currency-synthetic-tui-transfer)
extends ONLY that ignored UI profile: Expense Wallet->Food and Transfer Wallet<->Bank map onto
existing ordinary single-Measure Effects. One form currency binds both endpoints; self-transfer
refuses. Operation/endpoints/currency stay locked during this bounded correction entrance, not
as a new universal Core transaction-kind rule. Whole retained original/current route reconstruction
and old expense bytes remain; unsupported richer shape still refuses wholesale. Fresh synthetic
provisions explicitly include Bank zero origins, while supported old seeds retain Bank UNKNOWN,
even after transfer/net-zero activity. No read inserts support or silently migrates/initializes.
Normal presentation hides long internal IDs; an explicit detail toggle reveals complete identities
without changing source/receipt/currentness gates. Default store, currency scales, Store and main
engine/dependencies remain unchanged; no income/FX/canonical adoption follows.
The [synthetic income entrance](VERIFICATION.md#synthetic-tui-income) adds explicit
`income-source` -> Wallet/Bank to that SAME trial profile: negative counterpart/positive receiver
of one Measure. This concrete UI choice is not a Core income/account/party ontology, provider/
salary/tax fact or inferred metadata. Operation cycles through Expense/Transfer/Income; Income
collects one receiving Locus, while correction still locks complete route/currency. No income
source origin/balance/total is invented; receiving income cannot establish missing Bank support.
Whole retained qualification, existing seed bytes/default path, old expenses/transfers and
unchanged publication/receipt owner remain. No new store format or canonical adoption.
The [explicit initial-quantity increment](VERIFICATION.md#explicit-synthetic-initial-quantities)
adds optional setup on that SAME ignored native trial: all four existing currencies require
explicit signed/zero/huge Wallet AND Bank quantities. Pure Workbench qualifies them before
Recording can create a fresh store. Two independent empty-cut assertion groups retain initial
support, not balancing Events or inferred zero origins; synthetic Food/pantry provisions remain
explicit. The new narrow shape does not relax old-seed checks, change default bytes, fill old
Bank UNKNOWN, edit support on open or overwrite existing targets. The existing text Store,
publication/receipt gates, currency scales and renderers are unchanged. This is not the selected
canonical S-expression codec/store or permission for real-data recording.
The [closed synthetic backup/restore](VERIFICATION.md#synthetic-closed-backuprestore) adds an
outer Backup owner consumed by BOTH existing native CLIs, before TTY acquisition. It uses
Recording's dedicated namespace check and unchanged Store grammar, whole all-ancestor UI
qualification, publisher-compatible source lease and complete physical byte copies. Source
LOCK reads use the SAME fd to avoid POSIX process-lock release by closing another descriptor.
Backup-only last completion seal binds inventory/length/MD5 for accidental corruption, not
hostile authenticity or an adopted canonical format. Restore creates ONLY a fresh store,
CURRENT last and own temporary marker until exact validation; Recording treats retained
marker as interruption, never publication permission or cleanup request. Source tokens do
not transfer namespaces; old receipt remains separate from current after restoration. No
original bytes/support/default path change, fallback, overwrite/resume, automatic authority
switch, source cleanup or device/power-loss Saved. Cooperative immutable artifacts/stable
paths and same-device native trial qualify neither live nor off-device backup or Mirage.
A useful operational record/save/query path still needs qualified reference persistence. MirageOS minimal
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

## Small quantity answer / disclosure seam

The concrete question is “how much at this exact Locus/Measure in this supplied image?”
[Current_quantity_answer](../application/current_quantity_answer.mli) projects an EXISTING typed
query result, not another query/admission/arithmetic engine. Its distinct opaque exact payload
contains only coordinate, signed Quantity and support FAMILY (origin/opening/assertion); present
contains only coordinate, and unsupported retains its coordinate/reason. No raw answer/image,
Event witness, cut, Effect, description, request origin or opaque-section reference survives in
these payloads. Full evidence and independent cuts stay in the original owner image. This is a
concrete consumed disclosure projection, not a universal answer ontology, canonical fact or auth API.

[Japanese summary](../presentation/current_quantity_summary.mli) accepts only that projected
answer. Known zero, known nonzero/unknown amount and unsupported stay distinct; guidance suggests
checks without asserting a particular missing fact or silently repairing it. Exact decimal quanta
and escaped exact identities survive; no currency/scale/FX or LLM inference.

Both existing explicit-file CLI readers accept ONE leading `--summary` OR `--explain`, or ordinary
inspection. Planning/whole-source admission/one-image query order and 0/4/3 remain unchanged.
Summary withholds raw provenance from successful answers AND raw input diagnostics from failed
acquisition/decoding/source/support; failed inputs retain their existing 1/2 exit and no question
stdout. Detailed owner inspection remains available separately, not erased from the engine.

This is NOT permission enforcement, a network protocol or safe external service. The developer
CLI can still read an explicit file and select detailed mode. A future host must authorize each
coordinate/operation, own coherent acquisition, withhold loading faults/logs appropriately and
pass ONLY approved projections to recipients, never an admitted image/file handle. Quantities,
coordinates and support families can still be sensitive; no generic confidentiality claim.

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

The two explicit-file commands accept `[--summary | --explain] FILE LOCUS MEASURE [LOCUS MEASURE ...]`.
[CLI pair planning/rendering](../cli/quantity_questions.mli) shares only identical terminal
mechanisms, not source grammars/admission. Its abstract question list is nonempty and retains
order/duplicates. ALL pairs qualify before the shell's one acquisition; each reader admits the
supplied bytes once before querying that SAME immutable image for every coordinate. Admission
failure yields no question output; per-question unsupported is retained alongside other outcomes.
Mixed exit is 3 if any unsupported, else 4 if any presence, else 0; no subtotal, support priority,
re-read, mixed generations or partial-source salvage. Single ordinary query text remains unchanged.
This is one supplied-image consistency, NOT coherent/live filesystem acquisition qualification.

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

## Experimental ordinary Movement proposal

`bakhlo.text` / [Propose](../text/propose.mli) is a pure, consumed proposal builder for the
EXISTING experimental ordinary profile, not canonical encoding or a publication service.
Explicit supplied ID/date/effects/optional description, no allocation/clock/inferred support.
Base whole-read -> Event keys -> practical Movement -> candidate whole-read. Add/correct only
encodes NEW rows, inserting before the admitted profile's final top-level `end`; every base
byte/lexeme and independent support declaration stays retained. The private locator depends
on this fixed profile's end/whitespace grammar, not a generic text edit/parser. Revisit together
with any grammar expansion. New byte fields use the existing escape language; no normalization.
Correction adds a fresh Event/edge without deleting old facts or inheriting date/description;
source closure/terminal checks and WHOLE support still gate the result. An invalidated opening
refuses, never retargets/drops itself. No support editing or richer-family filter/codec.

Opaque candidate exposes base bytes, complete new bytes and the existing admitted image to its
trusted producer, NOT a client projection, generation token, authorization or saved receipt.
The named synthetic Unix trial consumes it outside the ordinary workspace; publisher owns
coherent expected-generation/base binding, current evidence requalification and lifecycle.
Domain/Application, read-only CLI and dependency direction remain unchanged. No filesystem/
Unix/Mirage/backend types or effects enter this adapter or the Core.

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

No production UI is adopted; CLI is the main development/read entrance. The ignored paired
Notty/Bonsai_term synthetic recording trial is implemented, not a permanent toolkit choice.
[Client access direction](#client-access-direction) records both desktop candidates and eventual
phone/browser access; toolchains, protocol, authentication and compatibility need concrete
qualification before adoption. Clients consume
semantic answers rather than recomputing meaning. Prior hosted, guarded SPT engine and
block-persistence evidence belongs to VERIFICATION, not production support. No permanent
adapter or main Lwt/SQLite dependency yet; the ignored native SQLite consumer is now exercised.
[Current direction](#selected-product-direction) pauses SQLite canonical adoption while
human-readable canonical text is evaluated; optional indexes need concrete consumers.
MirageOS is an explicit future goal with experimental support today; no runtime/store
combination becomes a prerequisite for semantics/publication.
No speculative load/navigation state, adapter, cache or framework belongs in the engine.
