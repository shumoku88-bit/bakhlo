# Preserve earned Core expressiveness — correspondence and proposed sequence

Status: initial correspondence map. User accepted root, cut and one-group quantity
slices, now locally tested; later implementation sequence remains PROPOSED, not a feature-
parity certificate or approval to implement all referenced capabilities.

## Starting point

The user explains that LOAM research/verification has already established that its
Core can support most household/personal-accounting OSS functionality, including
capabilities intentionally not implemented. The OCaml task is to preserve that
expressive capacity and its meaningful distinctions in a maintainable executable
product, not rediscover a minimal CRUD ontology or duplicate every product feature.

Keep three statements separate:

1. An upstream model/law/counterexample establishes something in its stated scope.
2. A representation is sufficient to implement a question under explicit assumptions.
3. The OCaml operation is implemented and qualified for actual use.

Neither missing OCaml operations nor upstream research-only work alone invalidate
Core expressiveness. Conversely, a catalogue entry or reviewed specimen is not a
proof that every related product behavior is covered. Do not narrow the Core to
ordinary Movements or add familiar product nouns simply to emulate another app.

## Instrument review for this planning step

- D at the original planning baseline: OCaml contracts/interfaces, prior reference
  map and inspected upstream owners; no full Actual admission/root-cut operation,
  anonymous Effects only. Later slices below update implemented correspondence.
- P: semantic preservation obligations S1–S10, D21 instrument review, upstream
  results within their own assumptions, existing executable slice qualification.
- R at planning time: minimal correspondence map and implementation sequence;
  VR-01 was OPEN. The later [lineage contract](ROOT_LINEAGE_SLICE.md) records its
  pre-implementation selection and bounded results. The later [cut contract](ROOT_CUT_SLICE.md)
  resolves VR-02 with bounded seams/optional selection laws. The [one-group quantity
  contract](CURRENT_QUANTITY_SLICE.md) resolves VR-03; VR-04 multi-group review is OPEN.
- Use: source/evidence inspection and this small correspondence table. No separate
  DRAKON/D2 view adds a distinct answer to the present linear planning question.
  No new formal run, dependency, benchmark, or implementation is selected here.
- Revisit: VR-04 before multi-group ownership/re-observation; transition/failure review before publishing;
  performance instruments only for a named workload. Formal results must state
  model-to-code mapping/gaps rather than borrowing upstream guarantees.

## Initial correspondence map

References are relative to the sibling LOAM checkout; see [reference map](REFERENCES.md).
This is deliberately not a complete module/feature inventory. Expand one row only
when a real question selects it; preserve already-earned distinctions meanwhile.

| Meaning to preserve | Upstream evidence owner | Current OCaml correspondence / remaining seam |
| --- | --- | --- |
| Exact quantities, explicit Measure, narrower ordinary Movement | `Loam/Core/Quantity.lean`, `Loam/Core/BalancedMovement.lean`, `Loam/Application/PracticalMovement.lean` | Quantity/Effect/Movement contracts and tests; structural validation is not world admission |
| Event observation versus Movement; identity only where independently referenced | `Loam/Core/Event.lean` | Event/identity-unique memory implemented for anonymous Effects; stable Effect keys and their within-Event uniqueness are NOT represented. Never drop referenced keys to fit this subset |
| Order-free correction frontier and stable root lineage | `Loam/Application/CorrectionFrontierSemantics.lean`, `CorrectionFrontierIndexed.lean` | Conditional frontier/lineages and source-bound reflected-root exclusion implemented and bounded-tested; optional general row-selection laws are not graph/OCaml refinement; quantity uses retained cuts |
| Unknown versus zero; current support distinct from historical origin | `Loam/Core/ZeroOriginCoverage.lean`, `Loam/Review/CurrentBalanceReview.lean`, `Loam/Application/CurrentQuantityAnchor.lean` | Conditional zero-origin arithmetic and one anonymous exact-assertion group over a checked cut implemented; multi-group ownership, support-family routing and full Actual selection unimplemented. No timestamp shortcut, history-completeness or broad current-support claim |
| Admission versus preview; publication observes current evidence under ownership | `Loam/Application/MovementAdmission.lean`, `Loam/Publisher/MovementPublisher.lean` | Validation-only application/CLI. Actual admission, identity allocation, retry, storage/recovery/receipts require separate contracts |
| Wider expressiveness, independent evidence, intentional research-only capabilities | `docs/SEMANTIC_BLUEPRINT.md`, `docs/EVIDENCE_ATLAS.md`, `docs/research/falsification/LOAM_FALSIFICATION_PROGRESS.md` and its exact observation/PR links | Use as design/evidence map, not a backlog. Select exact representative witnesses/owners before adding routing, Scheduled, relation, recognition, valuation, or temporal capabilities |

Reference observation for this plan: `4d7a29a5` (checkout moved from `80e50c7c`).
Event, correction-frontier, current-anchor, and falsification-progress files in this
review are unchanged against the earlier revision; no broader equivalence claimed.
No upstream build/proof run, code copy, private-data access, or upstream write.

The progress ledger distinguishes reviewed, absorbed, counterexample, research-only,
and implemented states. Preserve those labels and exact question scopes rather
than treating all research as unqualified or all reviewed items as proved.

## Proposed implementation order

### 1. Close one correspondence seam at a time

For the next selected question, name retained evidence and its upstream owner,
write the OCaml input/answer/refusal contract and one synthetic distinguishing
specimen. Check that simplifying representation does not erase a future consumer's
independent information. Do not finish a whole-corpus audit before useful coding.

The existing anonymous Event subset can support the next correction question;
it cannot be advertised as complete Event/effect-reference parity. Introduce stable
Effect keys only when a concrete independently referenced consumer selects them.

### 2. Roots and reflected-root exclusion locally tested

VR-01 selection and root/terminal implementation checks are complete within the
[lineage contract](ROOT_LINEAGE_SLICE.md)'s stated bounds. The supplied relation now supports:

- exactly one original root and terminal for each disjoint lineage;
- retained root identity through later replacement and unchanged source provenance;
- untouched Events as singleton lineages; invalid relations never yield fallback;
- order-independent membership, with representation order explicitly separate.

VR-02 now qualifies exclusion of complete reflected roots in a separate
[cut slice](ROOT_CUT_SLICE.md), refusing duplicate/unknown/non-root declarations.
The cut retains its immutable source; reuse on changed evidence is checked again.
Witness: after `a -> b`, reflecting root `a` must still exclude its lineage when
`b -> c` is later added; filtering only the previously observed terminal `b` fails.

The cut/model/code witness now passes; a generic Lean specification proves
terminal-only changes commute with root selection. It does not establish arbitrary
graph-edit stability, OCaml refinement, reflection truth, or current quantity.

### 3. One-group conditional quantity locally tested; next is ownership/consistency

VR-03 now qualifies one anonymous group's exact current assertions plus matching
unreflected terminal Effects. It retains one immutable source cut and original
premises; queries expose exact components or typed unsupported. See
[one-group contract](CURRENT_QUANTITY_SLICE.md) for bounded seams and optional laws.
Before multi-group ownership/re-observation code, resolve OPEN VR-04: preserve
independent cuts, unique live coordinate ownership, unrelated assertions and one
source-consistency owner. Do not coerce general Events into ordinary Movements
or manufacture dates/completeness to reuse the current Movement-only projection.
Full selected-current-Actual admission is a separate condition before operational
balance claims; an anchor group is evidence factoring, not invented identity.

### 4. Earn operational reliability without expanding ontology

Select storage only after specifying admission/publication, identity/retry,
uncertain outcomes, atomicity/durability assumptions, diagnostics, and recovery.
Revisit TLA+/TLC or SPIN where transitions/interleavings add a distinct answer.
Qualify synthetic fault points, backup/restore, and migration before any real-data
cutover; existing LOAM remains sole household authority.

### 5. Grow only selected derived capabilities

Routing, Scheduled/realization, relations/discharge, recognition, and valuation
are candidate consumers of the earned Core, not automatic canonical nouns or a
feature-parity roadmap. For each selected capability link its exact evidence,
independent facts, OCaml contract, distinguishing tests, and excluded scope.

UI/public release/multi-user scope remains unchanged. Performance and wider
platform qualification are separate evidence work, not inferred from purity or
small source size. The high quality target applies regardless of adoption.

## Completion of each selected slice

Record `upstream question/evidence -> preserved distinctions -> OCaml contract ->
executable witnesses/oracle -> qualified scope and remaining gaps`. Use the
[instrument review gate](VERIFICATION.md#instrument-review-gate). Keep source/model
correspondence inspectable; do not maintain a permanent duplicate engine or claim
that more passing generated cases prove the Core's entire expressive capacity.
