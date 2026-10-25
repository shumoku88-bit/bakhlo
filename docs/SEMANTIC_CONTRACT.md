# Semantic contract

Preservation obligations distilled from existing LOAM policy. These constrain
implementation choices; they are not a claim that every OCaml operation is qualified.

## The core

The household book is `book.txt`. Its specification (`docs/COMMON_FORMAT.ja.md`, with the
conformance fixtures in `test/common_format/`) defines what a book may hold and how a
balance is answered; `Book_txt.change` admits a change by exactly those rules. On top of
them, Bakhlo applies its own write policies (`sexp/daily_book.ml`):

- new entries, plans and counts use only Loci offered for new entries (not `HIDDEN`);
  a date-only or Merchant-only change keeps a Locus that is no longer offered;
- only an open plan can be paid, replaced or cancelled; payment and cancellation are final;
- a Merchant, once classified, is not replaced (user decision 2026-10-24 allows changing
  it later; not yet implemented);
- an empty memo is no memo;
- an entry is saved only if its TX reads back as the same entry.

## S1 — One operational authority

Exactly one selected system/data authority owns ordinary household recording.
Bakhlo has held that authority since the user-approved 2026-10-21 cutover.
LOAM is a frozen reference, not a second recording authority.

Implementation changes, representation migration, identity normalization, and
corrections of household facts are distinct operations. Do not silently invent,
discard, or reinterpret evidence during any of them.

## S2 — Minimal independent evidence

Retain information that cannot be reconstructed from other retained evidence.
Balances, remaining amounts, report rows, and status labels remain projections
unless a concrete independent information requirement earns canonical storage.

Use ordinary household notions such as account, category, budget or month when
an actual feature needs them. Do not add a generalized ontology merely to mirror
LOAM or another accounting system.

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

## S5 — Corrected entries and real household changes

Correction-version history is not a mandatory part of the new daily canonical
data. An explicitly converted candidate may retain the corrected entry/date and
keep earlier versions in the original data or separate backups. Verify the selected
entries, quantities and meaningful links; this is not full evidence-history parity.

book.txt keeps the current state; earlier versions live in Git, not in a correction graph.
Actual refunds, reversals, cancellations and payment-plan fulfillment are not input
correction history and must not disappear during simplification.

Do not conflate occurrence dates, recording order, and correction timestamps.
Do not manufacture historical time evidence that was never retained. Occurrence-date
corrections and Event corrections are distinct relations; neither silently transfers
or changes the other's evidence.

Explicit Reversal is another independent retained relation, not Event correction/deletion.
Exact physical inversion preserves coordinate/quanta/multiplicity, not Effect key or order;
combined net zero alone is insufficient. Target admission cannot be inferred backwards
from its reversal. Neither endpoint is automatically removed from quantities.

Settlement and relation discharges are not in book.txt v0; adding them is a format change
(`COMMON_FORMAT.ja.md`, D1) to qualify with LOAM's verification first.

## S6 — Unknown is not zero

Absence, uncertainty, incompleteness, unsupported questions, invalid input, and
storage failure are not successful empty answers. In particular, balance
answerability may require explicit origin evidence beyond observed activity.

Expose useful distinctions in typed results without one universal error or
completeness model.

## S7 — UI and projections do not own household meaning

UI collects drafts and renders answers. The book (`Daily_book` over `Book_txt`) owns
admission and the store (`Daily_file`) owns publication. UI must not allocate durable identity, choose canonical
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
