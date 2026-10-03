# Reference and correspondence map

Sibling `../loam` is design evidence, not a build dependency or an OCaml proof.
Consult narrow owners, not the whole workspace/private data. Do not copy source
without resolving licensing/provenance; do not write/build the sibling repository.
Public source identified by its README: https://github.com/shumoku88-bit/loam

## Observed revisions

- Bootstrap: `180707c58647dc7cad3361458c1801be184d15af`.
- Endpoint/frontier: `80e50c7c20ee35d9d22ec95ff5e6626e1286ab82`; Core Event,
  EventMemory and EventCorrection inspected unchanged against bootstrap.
- Planning/root/current-anchor: `4d7a29a5`; inspected Event/frontier/anchor and
  falsification-progress owners unchanged against the earlier revision.
- Base validity/admission/support: `dca1aac7`, later `6e8015c3`; the five inspected
  NormalizedActualAdmission, ActualDate, ActualValidity, CurrentBalanceReview and
  CurrentSupportRouting owners were unchanged across those last two observations.
- Opening/presence review: `5dd27f435219c21424f915f8a045c4c1b711528d`; Core OpeningSupport,
  Application CurrentQuantityPresence/CurrentSupportRouting and Review CurrentBalanceReview
  unchanged from `6e8015c3`. Unrelated sibling TUI work is outside this comparison.
- Presence implementation review: `0a290fe2b293ec5a81e19d4344f251abdbaee13b`; those four
  owners unchanged from `5dd27f43`. No upstream build/proof rerun or whole-tree claim.

These are narrow comparisons, not whole-checkout equivalence, proof reruns or a
frozen upstream protocol. Check live revision before using a changed owner.

## Meaning → owner → present gap

Paths are relative to `../loam`. Missing OCaml operations do not invalidate earned
Core expressiveness. Separate upstream result, representational sufficiency and
actually qualified OCaml behavior; do not turn this map into a whole-feature backlog.

| Meaning | Narrow upstream owner | OCaml boundary / remaining gap |
| --- | --- | --- |
| Independent minimal evidence | `DESIGN_PHILOSOPHY.md`, `docs/SEMANTIC_BLUEPRINT.md` | Semantic contract; no Account/Transaction-kind/Month ontology by habit |
| Exact Quantity, narrower Movement | `Loam/Core/Quantity.lean`, `BalancedMovement.lean`, `Loam/Application/PracticalMovement.lean` | Exact/structural entrance; not world publication |
| Event beyond Movement | `Loam/Core/Event.lean` | Neutral anonymous Effects remain general; stable within-Event keys/uniqueness and independently referenced metadata NOT represented |
| Retained identity and correction | `Loam/Core/EventMemory.lean`, `EventCorrection.lean`, `Loam/Application/CorrectionFrontierSemantics.lean`, `CorrectionFrontierIndexed.lean` | Conditional disjoint paths, roots/cuts qualified; not full normalized authority |
| Independent Actual occurrence | `Loam/Core/ActualValidity.lean`, `ActualEvidence.lean`, `Loam/ActualDate.lean`, `Loam/Persistence/NormalizedActualAdmission.lean` | Ordinary anonymous/base-validity subset only; revisions, metadata, Exchange/Reversal, relations/settlement remain unsupported |
| Independent origin | `Loam/Core/ZeroOriginCoverage.lean`, `Loam/Review/BalanceReview.lean` | Explicit current origin gate; no activity-derived origin/history completeness |
| Exact current assertions and stable cuts | `Loam/Application/CurrentQuantityAnchor.lean` | Independent cuts, exclusive ownership, explicit re-observation; not timestamp-plus-later-Movements or durable history |
| Four support families | `Loam/Review/CurrentBalanceReview.lean`, `Loam/Application/CurrentSupportRouting.lean`, `CurrentQuantityPresence.lean`, `Loam/Core/OpeningSupport.lean` | All four over one ordinary source; presence's ANY unreflected Effect touch invalidates without arithmetic. Synthetic whole-input admission checks even empty-coordinate presence cuts, unlike upstream lazy lookup |
| Authority/decoding versus preview | `Loam/Authority/ActualAuthority.lean`, `Loam/Persistence/NormalizedActualPersistence.lean` | Synthetic grammar only; no canonical loader/cutover |
| Current ownership/publication/retry | `Loam/Application/MovementAdmission.lean`, `Loam/Publisher/MovementPublisher.lean` | Unimplemented. Ordinary retry returns first retained result without retry-payload comparison; not a general policy |
| Prior research/status | `docs/EVIDENCE_ATLAS.md`, `docs/research/falsification/LOAM_FALSIFICATION_PROGRESS.md` | Follow exact observation/PR and current status: reviewed, absorbed, counterexample, research-only, implemented differ |
| Question-driven instruments | `docs/AI_WORKBENCH.md`, `docs/OBLIGATION_SCAFFOLD_METHOD.md`, `docs/drakon/ARCHITECTURE_LAWS.md`, `docs/d2/README.md` | Local selective assurance; no automatic upstream-tool verdict |
| Storage trade-offs | `docs/research/external-pressure/LOAM_TEXT_SQLITE_PERSISTENCE_STUDY_2026-10.md` (E3.3) | Storage OPEN. Encoder improvement does not decide durability/backup/migration |

[Optional local specification](../formal/README.md) is independently authored, imports
only Std and does not revalidate upstream proofs or formally refine OCaml.

Existing operational data (`../loam-data`) is not a fixture source. Never inspect,
copy, migrate or mutate it for ordinary development. Existing LOAM stays authority;
private data, migration and operational cutover require separately scoped approval.
