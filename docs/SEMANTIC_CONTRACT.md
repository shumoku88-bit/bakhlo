# Semantic contract

Preservation obligations distilled from existing LOAM policy. These constrain
implementation choices; they are not a claim that every OCaml operation is qualified.

## S1 — One operational authority

Exactly one selected system/data authority owns ordinary household recording.
During development the existing LOAM remains that authority. The OCaml repository
is not an operational replacement until an explicit qualified cutover.

Implementation changes, representation migration, identity normalization, and
corrections of household facts are distinct operations. Do not silently invent,
discard, or reinterpret evidence during any of them.

## S2 — Minimal independent evidence

Retain information that cannot be reconstructed from other retained evidence.
Balances, remaining amounts, report rows, and status labels remain projections
unless a concrete independent information requirement earns canonical storage.

Do not impose Account, Transaction kind, Budget, or Month as fundamental types
merely because another accounting system uses those names.

## S3 — Exact quantities and explicit Measures

Quantities are signed integer quanta without machine-overflow or floating-point
rounding semantics. A representation must preserve the existing unbounded range
or explicitly declare and qualify a changed contract.

Different Measures must not be silently summed or converted. Exchange, valuation,
display scale, and rounding require separate evidence or explicit policy.

## S4 — Ordinary Movement conservation

The ordinary single-Measure movement entrance admits balanced signed effects.
UI labels such as purchase, transfer, or income do not replace conservation.

Do not infer that every Event is an ordinary balanced Movement. Cross-Measure
exchange and other evidence families have separate admission obligations.
A zero-sum mathematical list alone need not meet all practical entry rules.

## S5 — Correction provenance and currentness

Retained history and the current answer are distinct. Corrections and lifecycle
changes must follow their qualified frontiers; a convenient UI status or cached
row cannot bypass them. Preserve provenance through explicit transformations.

Do not conflate occurrence dates, recording order, and correction timestamps.
Do not manufacture historical time evidence that was never retained. Occurrence-date
corrections and Event corrections are distinct relations; neither silently transfers
or changes the other's evidence.

Explicit Reversal is another independent retained relation, not Event correction/deletion.
Exact physical inversion preserves coordinate/quanta/multiplicity, not Effect key or order;
combined net zero alone is insufficient. Target admission cannot be inferred backwards
from its reversal. Neither endpoint is automatically removed from quantities or presence
activity. Corrections/cuts still own selection, so retained inversion need not mean current
cancellation when they select different observations.

Explicit relation discharge is independent Event/Relation/quantity provenance, not an
extra physical Effect or relation retraction. Remainders are conditional projections over
qualified supplied evidence; they do not establish physical balance support or real-world
fulfillment completeness. Corrections/Reversal do not silently transfer/deactivate those
retained references. Unknown relation identity never becomes zero remaining quantity.

## S6 — Unknown is not zero

Absence, uncertainty, incompleteness, unsupported questions, invalid input, and
storage failure are not successful empty answers. In particular, balance
answerability may require explicit origin evidence beyond observed activity.

Known nonzero with an unknown exact amount is weaker than an exact Quantity;
never substitute a scalar or feed that evidence to arithmetic. Expose useful
distinctions in typed results without one universal error or completeness model.

## S7 — UI and projections do not own household meaning

UI collects drafts and renders answers. Shared application boundaries own
admission and publication. UI must not allocate durable identity, choose canonical
files, implement recovery, or independently compute authoritative household facts.

Exports and caches remain disposable unless separately promoted by an explicit
semantic decision. Target-format convenience does not license guessed facts.

## S8 — Share mechanisms, not accidental ontology

Similar shapes justify shared algorithms only when independent meanings and
change boundaries remain intact. Keep Actual, Scheduled, policy, and presentation
concerns distinct where merging changes an observable answer.

## S9 — No stale authorization

A draft preview is not permission to commit. The publisher must establish the
relevant current evidence and ownership conditions at publication time.

A composed answer must not silently mix incompatible generations of the same
source. Define the consistency scope of each query; do not claim global snapshot
isolation without providing it.

## S10 — Evidence claims are scoped

Lean proofs, bounded models, tests, diagrams, benchmarks, and AI analysis are
evidence of different kinds. None automatically proves the intended OCaml
implementation correct. State assumptions and the implementation correspondence.

## Review questions

For any meaningful change ask:

1. Did we create another source of authority or retain a derived fact?
2. Did we hide uncertainty, weaken admission, or lose provenance?
3. Did we merge meanings because their data representations matched?
4. Did we change stored meaning without a qualified transition?
5. Did we claim more than the evidence supports?

Intentional semantic changes require an explicit decision and qualification;
these commitments are not an excuse to freeze accidental implementation details.
