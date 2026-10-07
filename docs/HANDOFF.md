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
Reuse LOAM's expressive core, not its research infrastructure or implementation
layout. TUI-first; small must not foreclose foreign currencies, exchange or settlement.

The first travel/multicurrency slice stays deliberately small: ordinary same-Measure
recording remains the normal path; v3 Book adds only explicit two-Measure Exchange
evidence using the already-qualified neutral Event/Effect/Measure core. The CLI records
both exact sides of an exchange, then local-currency spending uses ordinary `record`.
Reverse exchange is another explicit Event. No inferred rate, valuation, home currency,
fee policy or delayed foreign-card-to-JPY settlement relation is introduced by this slice.

## Present state

- Main OCaml engine, ordinary S-expression Book and read/staging CLI exist.
  v3 Book additionally represents explicit selected-key exchange Events for travel/multicurrency use.
  Book does not yet represent payment plans or all LOAM evidence.
- The user's working-tree `record` shortcut and Japanese interface explanations
  are recent additions. They are not evidence that real-data recording is safe.
- `tools/tui [notty|bonsai]` connects both screens to `Bakhlo_sexp.Daily_book`.
  `tui/daily_interaction.ml` and `daily_file.ml` own shared actions/publication;
  each frontend only adapts events and draws the same screen lines. The existing
  isolated environments are reused; Bonsai rebuilds the same current Core sources
  under its separate compiler ABI, never from the archived ox-build source copy. Record/save/exit/cold reopen/edit, separate pre-edit
  backups, vocabulary addition and explicit plan payment work in the trial.
  Main tests and native self-checks passed. Real synthetic PTYs also passed
  Notty record -> Bonsai reopen/edit -> Notty cold read, plus Bonsai plan payment,
  Japanese vocabulary, exact foreign input and paste refusal, with full terminal restoration.
  No new dependency or production-store qualification is implied.
  New source files pass the pinned formatter; repository-wide formatting still
  reports pre-existing Book/CLI layout differences, left untouched.
- Both daily screens now use terminal-default foreground/background: focus is
  reverse + bold with a textual `>` marker; headings/status are bold without fixed
  colors. No theme detection, RGB support or terminal preference changes are needed.
  Style self-checks and synthetic basic-ANSI/light and 256-color/dark-profile PTYs
  passed; emitted attributes contain no fixed colors and terminal state is restored.
  The user confirmed that the visibility issue is fixed.
- Daily_book reads the v1 candidate and writes v2 with selected-key Exchange evidence.
  IDs, exact multi-Measure postings, refunds, plans/payment links and independent
  support remain explicit. Ordinary Book/CLI formats are unchanged and separate.
- LOAM was stopped with the user's confirmation. Scoped read-only capture, native
  source admission, candidate conversion and an independent-process cold read passed.
  The candidate is `scratch/daily_book_candidate_v1/household.sexp`, with a small
  native reader and exact source copies beside it. The original scoped files still
  match the capture. Private payloads/counts stay out of these public documents.
- Synthetic corrected-entry/date, refund, plan-frontier/payment-link, unknown/support,
  exact-value and refusal checks passed; current `./tools/check` also passed.

## Next action

The user requested an inventory to decide the minimum before leaving LOAM.
[The cutover checklist](CUTOVER_CHECKLIST.ja.md) compares household operations,
current LOAM entry points and Bakhlo's daily UI/data gaps. It is a source-reading
inventory, not runtime-parity evidence or an automatic implementation backlog.
Discuss multiple-posting input, plan management/completion and balance checking
first; recurrence, exchange/settlement, budgets and reports still need scope choices.

The recording cutover inventory also has a user-facing cognitive-load requirement:
do not require the user to remember the current Locus vocabulary. Before cutover,
decide and qualify an overview/search/picker for existing accounts/categories,
a separate whole-transaction preview before publication, and focus-driven context
that shows only information relevant to the current cursor. Prefer transient
floating/overlay panes for picker, search, add, detail and preview where that keeps
Home small. Bonsai_term and Notty may implement these differently, but focus/pane
state remains presentation-only and must not create household meaning or a second
publication path.
Agree the essential operations and order before implementing the next slice.
The inventory task changed documentation only; it did not read household data or start migration.

The existing trial is `./tools/tui bonsai --book scratch/daily-ui/household.sexp`
(or omit `bonsai` for Notty). Both use the SAME private trial file; exit one before
switching screens. This is a separate private trial copy; the earlier candidate and
LOAM originals remain unchanged. See `tui/README.md` for controls and limits.
Improve agreed daily use, not a further inventory or research campaign.

The simple form handles same-Measure two-posting moves and edits date/amount/memo.
Foreign currencies work at their supplied scales. Exchange/refund/multi-posting
entries are preserved and displayed, but their UI input/editing is still missing.
Reimbursement/settlement evidence remains unimplemented: add concrete operations
without flattening their correspondence into ordinary expenses. Saving uses one
selected file, separate backups and a cooperative-writer check, not the old
research store. This is not runtime parity, durable-storage qualification or cutover.

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
