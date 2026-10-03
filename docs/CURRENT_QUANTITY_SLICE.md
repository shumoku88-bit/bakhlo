# Conditional exact quantity from one asserted reconciliation group

Status: implemented and locally tested. VR-03 contract/instrument selection was
recorded before implementation; user accepted supported-quantity engine work. This is a supplied-evidence
operation, not operational current balances, full Actual admission, history, storage,
UI/CLI, publication, zero-origin inference, or a complete multi-group support image.

## Question, evidence and consistency owner

Given one immutable `Reflected_root_cut.t` and an independently supplied finite
list of exact assertions for `Locus × Measure`, what does that one group imply?

`answer(c) = asserted(c) + sum of matching Effects in unreflected terminal Events`

Only explicitly asserted coordinates are supported. Unknown stays unknown even
with activity, zero net change, absent Effects, an empty/all-reflected cut, or
zero-origin coverage existing elsewhere. Known zero requires an assertion and the
exact equation, not a successful empty loader or graph result.

- D: exact Quantity and exact distinct identifier roles; source-bound cut with
  retained graph, declaration list, qualified root/terminal observations. Events
  retain neutral Effects, including empty/zero/mixed/nonconserving observations.
- P: S2–S6/S9/S10; existing correction/cut scopes and optional selection laws.
  Upstream current anchors have anonymous groups, a shared root cut per group,
  exact coordinate assertions, and at most one live group per coordinate. Current
  support is not historical origin; CurrentBalanceReview separately selects Actual
  and prevents overlaps among independent support families.
- R: one group's duplicate-coordinate admission, exact coordinate-local arithmetic,
  typed unsupported query, retained premises/source, independent implementation
  oracle, and arithmetic/noninterference specification laws. Full Actual selection,
  multi-group ownership/re-observation and support-family routing remain separate.

## VR-03 — instruments selected before code

Use narrow source inspection at upstream `4d7a29a5`:
`Loam/Application/CurrentQuantityAnchor.lean` (group/quantity equation, lines 33–236),
`Loam/Review/CurrentBalanceReview.lean` (support separation and Actual image seams).
No upstream implementation text imported, proof rerun, write, or private-data read.
Do not repeat the already-earned root-versus-terminal information question.

Reuse the independent integer transitive-closure/list cut model for a new bounded
seam: every admitted four-node relation, every admissible reflected subset, and
all 16 assertion-support subsets over four distinct coordinates (304 × 16 = 4,864
model/code group cases), with a fixed mixed/signed/zero/huge payload specimen.
This does not exhaust quantities, coordinate vocabularies, duplicated assertions,
absent IDs or larger graphs; fixtures/generated cases cover selected additional seams.
No distinct Alloy run is selected; it would repeat the chosen finite structure.

Extend the small optional Lean specification with general signed-Int laws:
absence of an assertion is unsupported for ANY delta; translating an assertion
translates the result equally; changing only reflected contributions cannot alter
the supported delta (roots fixed; unreflected contributions equal). Reuse the installed
Lean 4.33.1 binary and existing optional recipe. This adds an arithmetic/answerability
question not proved by earlier row-filter laws. It is not Zarith/Base refinement,
graph correctness, reflection truth, unit conversion, or Actual admission.

Use direct Zarith/source-list oracles, not the private production aggregate, for
10,000 generated groups with seed `loam-current-quantity-v1`, up to 10,000 shrink
attempts, actual count asserted. Compare assertion admission/support, exact
components, permutations/replay, and fresh terminal updates on reflected and
unreflected roots. Requalify if aggregation, support or root policy changes.

DRAKON/D2 remain deferred: one coordinate-admission pass, explicit construction,
lookup-only query and inward dependencies suffice now. Revisit multi-group ownership
or multi-family fallback routing when introduced. TLA+/SPIN/failure injection stay
for actual publication/loading/recovery transitions, absent here. Proof-checker
independence is not claimed. No tool installation, new dependency, or production
Lean requirement; wider-platform/latency qualification remains independent work.

## Minimal API — `Current_quantity_projection`

One Application model represents **one anonymous reconciliation group**, not a
stable household identity, replacement policy, or whole current-support image.
Do not duplicate assertion/root evidence independently for every coordinate or
merge differing cuts into a fictitious common baseline.

- public immutable `assertion = { coordinate; quantity }` for independently supplied
  exact observations; no Event allocation or synthetic Effect;
- abstract `t`, `create ~cut ~assertions : (t, error) result`;
- `Duplicate_coordinate { coordinate; first_position; position }`, first repeat
  in declaration order, one-based; equal-value repeats also refuse;
- `source_cut` and `assertions` retain the original cut and assertion order/values;
- abstract `answer`; `query t coordinate : (answer, unavailable) result`;
- `Assertion_unknown { coordinate }` is unsupported by THIS group, not malformed
  input, zero, known-present/unknown-amount, or absence of activity;
- answer accessors: `coordinate`, `asserted_quantity`, `delta`, `quantity`.

An empty assertion list supports no coordinate. Negative/zero/huge assertions are
valid exact premises; no implicit nonnegative/purchasing-power rule. Duplicate
checks precede aggregate construction. Root declaration/graph validity is already
owned by the abstract input cut and cannot be bypassed with raw/closed values.

Construction sums every matching represented Effect occurrence from remaining
terminal Events; superseded Events/reflected lineages never contribute. Measures
and Loci match exactly; no floats, rounding, conversion, clamp, Event-kind guess,
or ordinary-Movement validation. Materialize each supported answer once, including
its exact decomposition. Queries/renderers do not traverse/recalculate evidence.

**Share arithmetic, not support meaning:** extract a private Application
`Effect_sum` mechanism with named consumers Zero_origin_projection and this new
projection. Its missing key is a mathematical zero only AFTER each consumer's
independent support gate. It is not a public balance/origin/current-support API,
canonical fact or mutable cache. Existing zero-origin semantics/CLI must be unchanged.

All query components use the SAME supplied immutable cut. No extra Event/frontier
argument or global now can mix snapshots at query time. Callers remain responsible
for truthful, compatible assertion/reflection premises and for selecting Actual.
Reusing assertions on changed source requires explicit construction with a newly
checked cut; this does not authorize stale facts. Source and old answers remain
unchanged. No clock, group ID, loader, dates, transport/renderer or mutable state.

## Acceptance before implementation

- Run three new optional specification laws before product changes; report exact
  Lean version/axioms and keep ordinary OCaml checks Lean-free.
- Unknown with activity/net-zero/empty/all-reflected bases; known zero by explicit
  assertion; negative/huge quantities, explicit Locus/Measure, delimiter/token cases.
- Exact decomposition and original premise/source order retained; repeated Effects
  count, general Events not narrowed; duplicates refused with ordered diagnostics.
- Shared reflected cut across multiple coordinates; fresh correction/reclassification
  of reflected roots changes no delta; unreflected terminal update changes only its
  matching coordinate contributions. Old immutable answers persist.
- Bounded 4,864 model/code cases; 10,000 source-list generated cases with count;
  translation/noninterference, replay/permutation and supported-coordinate locality.
- Valid external client; forged group/answer, wrong cut source, and attempted public
  access to private aggregate fail with expected compiler diagnostics.
- Existing zero-origin/CLI goldens, normal/package/install/clean engine-only checks,
  unchanged dependency lock/product tooling; no operational data or upstream writes.

## Executed local qualification

macOS x86_64: three new Lean specification laws passed before product changes,
with installed Lean 4.33.1, warnings fatal, no custom axiom/proof hole. Their
inventories are: unsupported `[]`, translation `[propext, Quot.sound]`, reflected
contribution noninterference `[propext]`. Existing three root-selection laws also
remain checked. [Reproduction/mapping](../formal/README.md); not graph correctness
or OCaml/Zarith refinement.

Nine new expect tests pass: all 4,864 bounded graph/cut/assertion-support cases
match independent closure/cut and original-Effect Zarith arithmetic; 10,000 actual
generated cases with the stated seed/counts pass, including raw duplicate admission,
a separately constructed unique specimen, source/payload decomposition, unknown,
replay/permutation, translation and reflected/unreflected fresh terminal updates.
Unknown with activity/net-zero/all-reflected input, signed/huge cancellation,
exact-token keys, shared-cut coordinates and original source/assertion order pass.

At this VR-03 milestone, complete normal/package/install checks pass: **68 expect tests**, **90,000 generated
cases** over nine seeds, **three cram suites**. Clean engine-only build leaves
presentation/CLI native libraries/CMIs unbuilt. Ordinary checks also passed with
`LEAN` pointing to a nonexistent binary. Existing zero-origin cases and CLI goldens
are unchanged after arithmetic extraction; no package/lock/product-tooling change.

Valid public client compiles; forged group/answer, wrong cut source and access to
`Loam_application.Effect_sum` refuse with expected diagnostics. Dune private-module
marking alone leaves an alias in the generated root namespace; explicit
At this milestone `loam_application.ml/.mli` export only the six public operations
(the later multi-group slice adds one deliberate public export). Public CMI
specimens include Dune's intermediary wrapper CMI. Direct internal-unit aliases
were rejected by the clean-build check and replaced by normal logical aliases:
no missing-CMI warning suppression or incremental-build-only assumption. Internal
unit names/CMI layouts are still Dune integration details, not a compatibility or
security boundary against deliberate access to implementation files/unsafe casts.

VR-03 is complete within the one-group supplied-basis scope. VR-04 was OPEN at
this milestone; the later [multi-group contract](CURRENT_GROUPS_SLICE.md) qualifies
one source-consistency owner, duplicate live coordinate refusal and independent
cuts/re-observation for unrelated premises. VR-05 full Actual/family composition
remains OPEN before operational balance claims. Preserve earned expressiveness
without presenting either slice as the complete admitted current-support family.
