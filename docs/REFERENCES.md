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
- Effect-key review: `83bc471e9305dfa8a0a2aa781102e558a3d96991`; Core Effect/Event,
  ActualEvidence and NormalizedActualAdmission unchanged from `6e8015c3`. EventDescription
  inspected for the next independent metadata gate, not implemented by this key increment.
- Description review: `f96d143a843b644f1e2e99f1ec5f4895c1e2b117`; EventDescription,
  ActualEvidence and NormalizedActualAdmission unchanged from `83bc471e`. Narrow read-only
  consultation, not whole-tree parity, source reuse or proof rerun.
- Date-history review at the same `f96d143a`: Core ActualValidityHistory, Application
  ActualValidityFrontier and NormalizedActualAdmission; tagged Event-rooted base/later
  revision references, closed same-Event paths, unique current projection and retained
  reference/current completeness. No upstream proof/build or whole-tree comparison.

- Merchant review: `2438ef50a363ef06491da7b62f8537f52e25031a`; Core ExternalParty,
  EventMerchantEvidence, ActualEvidence and NormalizedActualAdmission narrowly read.
  Role-free external identity, optional Event-scoped provider/nonmerchant evidence,
  unique retained Event references; no source copying/build/proof rerun.

- Original-amount review at the same `2438ef50a363ef06491da7b62f8537f52e25031a`:
  Core OriginalAmountEvidence, Application OriginalAmountFrontier and Persistence
  NormalizedActualAdmission; positive unique stable-root facts and current terminal
  projection without rewriting. Core MovementOperationEvidence read as a deferred
  alternative; no write/retry consumer or publication qualification follows.

- Exchange review at the same `2438ef50a363ef06491da7b62f8537f52e25031a`:
  Core ExchangeEvidence, Application ExchangeEvidenceFrontier/ExchangeAdmission and
  Persistence NormalizedActualAdmission. Explicit key selection, distinct Measures,
  selected/net signs, no third Measure or Event correction participation; extra Effects
  allowed. New-publication world/Locus/token/allocation rules are not read admission.

- Reversal review at the same `2438ef50a363ef06491da7b62f8537f52e25031a`:
  Core ActualReversal/ActualReversalBalance and Persistence NormalizedActualAdmission.
  Globally unique endpoints, retained Event closure, exact physical multiset inversion
  ignoring Effect keys; ordinary target balance or admitted target Exchange justifies
  reversal-side admission (ordinary balance or Exchange-inverse exception). Separate corrections still own Event selection; no current/root
  endpoint exclusion observed. Upstream proof was consulted, not rerun or imported.
  Later observed clean HEAD `dccbb2d9e17c6f5e92d8b6fb3390dbfd9ab2b926`; these three
  owners are byte-unchanged from the consultation revision, not a whole-tree review.

- Relation-unit review at `dccbb2d9e17c6f5e92d8b6fb3390dbfd9ab2b926`: Core OpenRelation,
  Application OpenRelationFrontier and Persistence NormalizedActualAdmission. Independent
  IDs, retained Event/key closure, explicit Household/external endpoints, positive units
  and individual/aggregate absolute source bounds. RelationDischargeFrontier narrowly
  consulted for deferral: target-local activation/crash residue, exact fulfillment and
  remaining quantities are not this whole-source relation-unit increment. Core Purpose
  inspected as an alternative: routing/capacity coordinate, not Actual classification.
  Later observed clean HEAD `4298827cab7d742c7430d858bdcb4d84dce51fc2`; all five
  consulted owners unchanged from the consultation revision, not a whole-tree review.

- Closed discharge/remainder review at `ed2cff4279c51f83d31bf60d16e168d9f73b082e`:
  Core OpenRelation, Application OpenRelationFrontier/RelationDischargeFrontier and
  Persistence NormalizedActualAdmission unchanged from `dccbb2d9`. Exact Event/Relation/
  quantity rows, target-local pair/self/positive/individual/aggregate bounds and derived
  remainder. Normalized acquisition additionally closes EVERY raw Event/target; only
  that closed boundary selected, not inert pre-Event crash-residue activation. Completion
  observation `d02d2f0b0e351167a4aa951c8dc8043ed67f32f5` (production Attention HouseholdImage
  cutover): these four owners unchanged from initial review; no whole-tree parity implied.
  Upstream storage progress does not freeze OCaml persistence or authorize its migration.

- Canonical evidence / inherited-format review at
  `f82f4c45498ce9b3c51a76acb7189588a5f74718`: current Household/Actual authority,
  13 registered payload codecs, Scheduled terminal factoring, quantity/policy support,
  external Measure scale and current journal/Beancount projection inspected SOURCE-only.
  Older README/Beancount canonical-path descriptions do not override current source root
  selection. [Review evidence](VERIFICATION.md#canonical-evidence--inherited-format-review)
  names the selected owners/limits; no private usage inventory, execution, full-family parity
  or upstream implementation reuse follows. Historical owners/revisions above remain evidence.

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
| Event beyond Movement | `Loam/Core/Effect.lean`, `Event.lean` | Optional exact keys/within-Event uniqueness and general neutral Effects; other structured classifications/overlays NOT yet qualified |
| Event recognizer text | `Loam/Core/EventDescription.lean`, `Loam/Persistence/NormalizedActualAdmission.lean` | Optional unique exact retained-ID/text facts; no classification or inheritance. Combined per-declaration duplicate/reference gate differs from upstream's separate gates; accepted shape matches this narrow scope |
| Event Merchant disposition | `Loam/Core/ExternalParty.lean`, `EventMerchantEvidence.lean`, `Loam/Persistence/NormalizedActualAdmission.lean` | Exact role-free nonempty party ID; optional provider/nonmerchant facts against retained Events, absence unresolved, no inference/inheritance. Combined per-declaration duplicate/reference gate differs from upstream separate gates; practical nonempty identities are narrower than unrestricted upstream raw tokens. No registry, provider truth/coverage or report routing |
| Original presented/charged amount | `Loam/Core/OriginalAmountEvidence.lean`, `Loam/Application/OriginalAmountFrontier.lean`, `Loam/Persistence/NormalizedActualAdmission.lean` | Optional unique positive root/Measure/Quantity facts and same-frontier current associations; original root fact/order retained, absent stays None. Practical duplicate/positive/retained/root per-row gate differs from upstream separate gates; no valuation/FX/basis, report routing, amount truth/coverage or publication |
| Selected cross-Measure exchange | `Loam/Core/ExchangeEvidence.lean`, `Loam/Application/ExchangeEvidenceFrontier.lean`, `ExchangeAdmission.lean`, `Loam/Persistence/NormalizedActualAdmission.lean` | Unique exact selected-key claims with full Measure/sign/total shape and correction-interference refusal. Only admitted subjects bypass source balance, never nonzero/support. Local per-row errors and Exchange-before-physical source order differ from upstream separate gates/nonzero-first; no correction replacement, rate/fee/basis meaning or publication/Locus-policy/ID-allocation qualification |
| Explicit Actual Reversal | `Loam/Core/ActualReversal.lean`, `ActualReversalBalance.lean`, `Loam/Persistence/NormalizedActualAdmission.lean` | Globally disjoint retained endpoints and exact physical multiset inversion ignoring keys/order, preserving multiplicity. Source independently admits ordinary/Exchange targets before admitting inverse sides (ordinary balance or explicit Exchange-inverse exception); no automatic deletion/support or current/root-only restriction. Per-fact uniqueness/closure/inverse and pre-physical source ordering differ from upstream separate gates/nonzero-first; no reversal truth/coverage, lifecycle/report/publication qualification |
| Directional relation units | `Loam/Core/OpenRelation.lean`, `Loam/Application/OpenRelationFrontier.lean`, `Loam/Persistence/NormalizedActualAdmission.lean` | Independent nonempty Relation IDs, exact retained Event/key source, one Household/one External endpoint, positive per-unit/aggregate absolute source bounds and retained source-derived Measure. Local staged identity/local/aggregate diagnostics differ from upstream indexed per-row totals. Whole-source admission, no orphan acquisition/target-local state, completeness, discharge/remaining amount, revision/lifecycle or publication |
| Closed discharge / conditional remainder | `Loam/Core/OpenRelation.lean`, `Loam/Application/RelationDischargeFrontier.lean`, `Loam/Persistence/NormalizedActualAdmission.lean` | One opaque relation/Event generation, ALL raw references closed, unique Event/Relation pair, no source-Event self-discharge, positive individual/aggregate target bounds, ordered retained rows and exact snapshot subtraction. Local per-row/aggregate diagnostics differ from upstream target-order checks. No target-local inactive residue/activation/recovery, fulfillment truth/completeness, lifecycle/retraction, physical support or publication |
| Retained identity and correction | `Loam/Core/EventMemory.lean`, `EventCorrection.lean`, `Loam/Application/CorrectionFrontierSemantics.lean`, `CorrectionFrontierIndexed.lean` | Conditional disjoint paths, roots/cuts qualified; not full normalized authority |
| Independent Actual occurrence | `Loam/Core/ActualValidityHistory.lean`, `Loam/Application/ActualValidityFrontier.lean`, `Loam/ActualDate.lean`, `Loam/Persistence/NormalizedActualAdmission.lean` | Retained ISO history, tagged refs, same-Event paths, unique/complete current facts (revision-only allowed). Practical declaration-order diagnostic gate, not raw Core history or full normalized admission; other structured metadata/exceptional families remain unqualified |
| Independent origin | `Loam/Core/ZeroOriginCoverage.lean`, `Loam/Review/BalanceReview.lean` | Explicit current origin gate; no activity-derived origin/history completeness |
| Exact current assertions and stable cuts | `Loam/Application/CurrentQuantityAnchor.lean` | Independent cuts, exclusive ownership, explicit re-observation; not timestamp-plus-later-Movements or durable history |
| Four support families | `Loam/Review/CurrentBalanceReview.lean`, `Loam/Application/CurrentSupportRouting.lean`, `CurrentQuantityPresence.lean`, `Loam/Core/OpeningSupport.lean` | All four over one qualified Actual-subset source; presence's ANY unreflected Effect touch invalidates without arithmetic. Synthetic whole-input admission checks even empty-coordinate presence cuts, unlike upstream lazy lookup |
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
