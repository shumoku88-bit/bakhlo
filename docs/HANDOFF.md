# Handoff

## Current task

Build an ordinary household ledger, not a LOAM research port or an OCaml textbook
project. Required household functions remain recording/editing, account/category
addition, payment plans, budgets and reports.

The user approved trying a private Bakhlo-native data candidate from current LOAM:

- corrected historical entries, without carrying correction-version chains;
- explicit payment plans and their meaningful payment links;
- actual refunds/reversals retained as transactions, not mistaken for input edits;
- exact currency interpretation and independently supplied quantity support.

Keep the old LOAM originals and exact capture separately. This is NOT operational
cutover or a claim of full-household migration. Missing evidence stays unknown.

## Present state

- Main OCaml engine, ordinary S-expression Book and read/staging CLI exist.
  Book does not yet represent payment plans or all LOAM evidence.
- The user's working-tree `record` shortcut and Japanese interface explanations
  are recent additions. They are not evidence that real-data recording is safe.
- Existing synthetic Notty/Bonsai screens are in ignored scratch. Their presence
  does not select a permanent UI/store or require further backend experiments.
- LOAM was stopped with the user's confirmation. Scoped read-only capture, native
  source admission, candidate conversion and an independent-process cold read passed.
  The candidate is `scratch/daily_book_candidate_v1/household.sexp`, with a small
  native reader and exact source copies beside it. The original scoped files still
  match the capture. Private payloads/counts stay out of these public documents.
- Synthetic corrected-entry/date, refund, plan-frontier/payment-link, unknown/support,
  exact-value and refusal checks passed; current `./tools/check` also passed.

## Next action

Let the user inspect the readable candidate and choose the simplest useful shape.
Native source/candidate quantity/support comparison passed; synthetic expectations
cover corrected dates, refunds and plan/payment links. This is not an executed LOAM
runtime-parity or production-safety claim. Connect the accepted shape to ordinary
use next, not another framework, backend or infrastructure qualification campaign.

Other LOAM families remain in the original/capture; before any full replacement,
resolve their necessary household information. Plans/budgets/reports are required
product functions, not permission to copy every research implementation.

## Maintenance revisit decisions

Revisit a mechanism when the current task exposes a bug, measured cost or actual
maintenance burden. There is no periodic blanket refactor or obligatory task note.
Existing interfaces and [verification](VERIFICATION.md) own their local contracts
and evidence. Historical experiments/roadmaps are not today's work queue.

S-expression text remains the data direction. Unix is the current runtime;
MirageOS is a future goal, not a daily-use prerequisite. Learning notes are optional.
[AGENTS.md](../AGENTS.md) owns data safety and development rules.
