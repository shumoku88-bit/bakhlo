# Reference map

These references are design evidence, not build dependencies or OCaml guarantees.
Do not copy upstream code before resolving licensing and provenance.

## Existing LOAM

Local reference checkout at bootstrap: sibling `../loam`.
Observed commit: `180707c58647dc7cad3361458c1801be184d15af`.
Later endpoint-closure review observed `80e50c7c20ee35d9d22ec95ff5e6626e1286ab82`.
The three Core Event/EventMemory/EventCorrection files below are unchanged against
the bootstrap reference; no claim is made that the whole checkout is unchanged.
Public source location referenced by its README:
https://github.com/shumoku88-bit/loam

Paths below are relative to that repository. A moving checkout can diverge from
this baseline; check the revision before relying on a particular finding.

| Question | Narrow reference |
| --- | --- |
| Design philosophy and minimal evidence | `DESIGN_PHILOSOPHY.md` |
| Existing authority and operational data continuity | `docs/HOUSEHOLD_OPERATING_MODE.md` |
| Semantic commitments | `docs/SEMANTIC_BLUEPRINT.md` |
| Architectural laws and frontend boundaries | `docs/drakon/ARCHITECTURE_LAWS.md` |
| How to select prior evidence/tools | `docs/AI_WORKBENCH.md`, `docs/EVIDENCE_ATLAS.md` |
| Deterministic / prior / residual obligations | `docs/OBLIGATION_SCAFFOLD_METHOD.md` |
| Thin command boundary and question-specific reviews | `docs/research/HOUSEHOLD_COMMAND_BOUNDARY_2026-09.md`, `Loam/HouseholdCommand.lean` |
| Existing read-only GUI and exact transport | `gui/README.md` |
| Exact unbounded quanta | `Loam/Core/Quantity.lean` |
| Single-Measure balance proof boundary | `Loam/Core/BalancedMovement.lean` |
| Practical nonempty/nonzero/single-Measure movement boundary | `Loam/Application/PracticalMovement.lean` |
| Draft versus admitted world | `Loam/Application/MovementAdmission.lean` |
| Re-read under ownership, publication, retry policy | `Loam/Publisher/MovementPublisher.lean` |
| Independent coordinate-local zero-origin support and balance gate | `Loam/Core/ZeroOriginCoverage.lean`, `Loam/Review/BalanceReview.lean` |
| Current support versus historical coverage; amount-unknown distinctions | `Loam/Review/CurrentBalanceReview.lean` |
| Current exact anchor requires correction-root cuts, not a guessed time boundary | `Loam/Application/CurrentQuantityAnchor.lean` |
| Event versus Movement, identity-unique memory, raw correction endpoint closure | `Loam/Core/Event.lean`, `Loam/Core/EventMemory.lean`, `Loam/Core/EventCorrection.lean` |
| Disjoint-path correction admission, frontier membership, root-cut neighbor | `Loam/Application/CorrectionFrontierSemantics.lean`, `Loam/Application/CorrectionFrontierIndexed.lean` (admission/projection definitions; observed `80e50c7c`) |
| Current Actual authority and decoding | `Loam/Authority/ActualAuthority.lean`, `Loam/Persistence/NormalizedActualPersistence.lean` |
| Small retained proof selection | `Loam/DurableProofs.lean` |
| Storage trade-offs and encoder results | `docs/research/external-pressure/LOAM_TEXT_SQLITE_PERSISTENCE_STUDY_2026-10.md` (especially E3.3) |

## Important qualifications

- The existing GUI is documented as read-only, not a completed multi-UI write API.
- Existing `HouseholdCommand` primarily selects canonical paths; do not mistake
  it for a ready-made general application service or a frozen external protocol.
- An `Admitted` name does not necessarily mean the value carries a Lean proof.
- `PracticalMovement` checks represented shape/conservation, not policy, date,
  or world publication. The new OCaml validation slice has that limited scope.
- `Loam/Persistence/TokenSyntax.lean` is text-field representability, not a reason
  to impose that storage grammar on every opaque domain identity.
- Existing ordinary Movement idempotency returns the first retained Event for an
  operation identity without revalidating the retry payload.
- The text/SQLite study removed a measured encoder bottleneck; it did not prove
  that SQLite can never simplify operational responsibilities.
- The OCaml zero-origin projection is conditional arithmetic over supplied
  Movements, not the full admitted Actual read path or current-anchor semantics.
  Origin support is never inferred from activity; a timestamp is not an anchor cut.
- OCaml's endpoint-closure slice implements only anonymous-Effect observations;
  do not erase retained keys or other independent fields to fit this subset. Closed
  endpoints do not admit self/cyclic/competing relations as a current frontier.
  The later OCaml frontier slice checks the whole supplied relation under a
  disjoint-path policy, not full Actual admission or root-cut/quantity semantics.
- Existing results have not been rerun for this documentation bootstrap.
- Upstream policy treats operational LOAM data as authoritative and non-disposable.

## Private data

The sibling `../loam-data` is current operational household data, not a fixture
source. Its contents were not inspected or copied for this bootstrap. Reference
its existence only to protect the authority boundary; ordinary development here
must use synthetic evidence.
