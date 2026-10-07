# Handoff

## Current task

Build an ordinary household ledger, not a LOAM research port or an OCaml textbook
project. Required household functions remain recording/editing, account/category
addition, payment plans, budgets and reports. The user explicitly requires plans,
various balances, a daily spending guide, budget functions and Attention for the
LOAM replacement; detailed operations and initial-cutover scope remain under discussion.

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
- Both daily screens share Space -> Command Palette -> Theme and UI-only preferences
  in `daily_interaction.ml` / `ui_preferences.ml`. Terminal remains the safe default:
  no fixed foreground/background, reverse + bold focus and textual `>` markers.
  Bakhlo Light/Dark share one semantic xterm-256 palette (indices 16..255, annotated
  canonical RGB), not unconditional 24-bit SGR. Dark follows the earlier Bonsai
  trial's blue selection/cyan heading/yellow status on charcoal; Light uses a white
  background and dark text. Standard text/panel/selection contrast is checked at
  4.5:1 or better, and both renderers test matching indexed emission with no truecolor.
  Arrow live preview, Esc restore/return, Enter atomic UI-setting save and cold-start restore work.
  ASCII Space and U+0020 are recognized in shared interaction; memo/new-Locus spaces
  stay text. Modal keys/paste cannot reach the form. Theme notices are independent
  of household warnings; blocked-write warnings remain visible below overlays.
  Full checks, both self-checks (including actual centered/front overlay rendering),
  and both real TTYs passed preview/cancel/save/restart with isolated UI settings.
  The specified private trial's bytes/file list stayed unchanged; private screen
  payloads were not logged. TTY tests alone do not certify native Terminal pixels
  or subjective colors. After indexed output replaced the first draft's truecolor
  incompatibility, the user visually accepted Terminal/Light/Dark in native macOS
  Terminal. Later themes can extend the shared palette/selector; official
  Bonsai_term theme import is not implemented. See `tui/README.md` for controls
  and fallback limits.
- Source/Destination Enter now opens a shared Locus picker: approved vocabulary
  only, display label plus stable ID, substring search (ASCII case-insensitive and
  literal Unicode/spaces), arrows/Page/Home/End, and selected current quantity in
  the draft's Measure. No inferred account/category roles or invented zero.
  Enter applies only the exact ID to the target draft field; Esc preserves context.
  Amount/edit/blocked guards remain read-only, empty/missing vocabulary invents no
  choices, and modal keys cannot reach the form. Single-line paste searches only;
  control/newline paste never selects or publishes. Layout stays shared; renderers
  supply cell-width measurement for UTF-8-safe marked clipping and bounded panes.
  Shared checks and both renderer checks pass long Unicode/duplicate labels,
  search/scroll/cancel/guards and household bytes/artifact invariance. Synthetic
  real TTYs pass both frontends/all themes, including resize and terminal restoration,
  using shell/tmux, not Python. No new dependency, accounting API/format or publication path.
- Daily_book reads v1..v4. It writes `bakhlo-daily 4` when budget definitions are
  explicitly supplied, otherwise v3; Exchange and plan `cancelled-on` remain explicit.
  Reading does not rewrite an input; explicit copy/publication keeps prior bytes separately. Ordinary Book/CLI is unchanged.
  Pure `put_plan` now creates/replaces an open same-ID occurrence with exact balanced
  multiple signed changes and current vocabulary checks. `cancel_plan` retains the
  occurrence with a supplied real closure date, without altering physical quantities.
  `open_plans` excludes paid/cancelled occurrences, not unknown real-world obligations.
  Closed plans cannot be edited/reopened/reused for payment. Terminal fields cannot
  be supplied as a create/edit draft. Current-entry edits preserve existing payment links.
  No new UI controls: the old trial only labels/refuses cancelled plans correctly.
  Synthetic lifecycle, codec/refusal and support/metadata preservation tests, full
  `tools/check`, and both UI self-checks passed. Existing file publication was reused
  for synthetic plan create/update/cancel cold reads; no durable-store qualification.
  Bonsai linking still warns about the absent `/opt/local/lib` search directory.
- `Daily_book.daily_pace` now answers the current LOAM Home `d` balance-pool
  calculation without UI/budget/storage changes. Measure, unique same-Measure
  coordinates, observation date and exclusive end are explicit; no clock/defaults.
  Exact balances and open-plan per-occurrence net drains come from ONE immutable
  book. The result includes coordinate quantities, deducted plan IDs/amounts,
  totals, positive calendar horizon and integer-quanta daily guide. Unknown support
  and nonzero/amount-unknown both refuse, with distinct reasons; explicit empty
  selection is empty, never missing configuration. Negative division floors via
  Zarith Euclidean division, not truncation or zero clamping. Synthetic tests cover
  lifecycle/refunds, overdue/internal/inflow/boundary cases, currency separation,
  huge quantities and Gregorian/leap-century day counts. This is current evidence
  composition, not balance freshness, plan completeness, historical replay or a
  LOAM runtime-parity claim. The query does not change format; no private inputs were read.
- Pure `put_budget`, `rebalance_budget` and `budget_review` now cover explicit
  period/Measure/purpose allocations, declared expense loci, separate Actual-locus
  and plan-ID/locus routing, recorded spending, open-plan pressure and residuals.
  Missing route and explicit unmanaged are distinct item lists; missing budget
  information is None, not empty/zero. Definitions apply across their selected
  period, not dated LOAM routing history. Signed expense-side actuals reduce spent
  for refunds; positive per-plan/Purpose net pressure protects open obligations
  (including overdue before period start), without spending future refunds.
  Payment closes plan pressure without copying its routing to Actual. Plan edits
  that strand supplied budget references refuse; no silent route deletion.
  Budget definition replacement is explicit, not inferred historical reclassification.
  Total-preserving positive reallocation is separate from physical funding and
  safe-to-spend authority. No carryover, funding/grant engine, full expense catalog,
  completeness claims or operational parity. Synthetic tests and both UI self-checks
  passed, including v4 publication/cold read; no new controls/dependencies/files.
- LOAM was stopped with the user's confirmation. Scoped read-only capture, native
  source admission, candidate conversion and an independent-process cold read passed.
  The candidate is `scratch/daily_book_candidate_v1/household.sexp`, with a small
  native reader and exact source copies beside it. The original scoped files still
  match the capture. Private payloads/counts stay out of these public documents.
- Synthetic corrected-entry/date, refund, plan-frontier/payment-link, unknown/support,
  exact-value and refusal checks passed; current `./tools/check` also passed.

## Next action

[The cutover checklist](CUTOVER_CHECKLIST.ja.md) owns the inventory and small-step
preparation. Plans, various balances, today's spending guide, budgets and Attention
are required areas, not optional substitutes for other tools. This does not make
every operation in those areas mandatory for the first cutover. Multiple-posting
input remains a prior focus. Today's amount is now selected: LOAM Home `d`,
Daily Pace / Trend, not the purpose-budget per-day guide. Its current amount uses
an explicit single-Measure balance pool less open-plan net drains before the
exclusive cycle end, divided by remaining calendar days. Overdue open plans still
count, internal pool transfers deduct zero, and planned inflows are not yet money.
Use LOAM's local-today observation and integer-quanta calculation; do not substitute
the navigated calendar date or clamp a deficit to zero. Pool/boundary configuration
must be supplied explicitly. Whether the initial slice also shows `d`'s seven-day
current-truth reconstruction remains a display-scope question, not a different formula.

The user also selected focus-based TUI visibility and floating panes to keep Home
uncluttered. The checklist owns the detailed screen proposal and acceptance cases;
`../tui/README.md` distinguishes this target from the current always-visible trial.
Do not hide necessary fields within a single transaction or safety-critical errors.

The recording cutover inventory also has a user-facing cognitive-load requirement:
do not require the user to remember the current Locus vocabulary. Before cutover,
decide and qualify an overview/search/picker for existing accounts/categories,
a separate whole-transaction preview before publication, and focus-driven context
that shows only information relevant to the current cursor. Prefer transient
floating/overlay panes for picker, search, add, detail and preview where that keeps
Home small. Bonsai_term and Notty may implement these differently, but focus/pane
state remains presentation-only and must not create household meaning or a second
publication path.

The user has now selected small daily recording UI improvements in this order:
Locus picker, multiple-posting input, then a separate whole-transaction preview.
The picker is implemented; next is the multiple-posting draft/editor, not another
UI framework or a new publication path. Keep role/quantity support and payment links
explicit, preserve all transaction fields, and qualify one usable step at a time.
Home-wide focus/context remains unfinished, as does in-picker vocabulary addition.
Plan updates, Daily Pace and the first explicit-period budget slice are implemented
with synthetic checks. Attention remains a later small pure data/API candidate:
explicit context, due/none/undetermined, dated resolve/drop and save/cold read.
Observation updates and broader budget operations remain gaps. Multiple-posting
input/recurrence are separate from retained data. Do not treat Daily Pace or
recorded budget residuals as physical funds, invent purpose assignments or promote
this limited expense selection to household completeness. Reuse existing admission
and file publication, not UI layout/history prerequisites or a full feature queue.

Keep preparation in the existing checklist, not new per-feature plans or scaffolds.
No generic scheduler/workflow, extra backend, duplicated frontend calculations,
new dependency or research-port pipeline. Extend formats only when an actual slice
needs independent evidence, preserving refusal and explicit version transitions.
The pure budget slice added native definitions/API/codec and synthetic tests without
UI controls. The later Theme/picker slices change UI-only interaction/rendering.
The picker did not read household data, run/modify LOAM, convert private candidates,
introduce dependencies, or start operational cutover.

The existing trial is `./tools/tui bonsai --book scratch/daily-ui/household.sexp`
(or omit `bonsai` for Notty). Both use the SAME private trial file; exit one before
switching screens. This is a separate private trial copy; the earlier candidate and
LOAM originals remain unchanged. See `tui/README.md` for controls and limits.
Use the prepared scope to improve agreed daily use, not another broad inventory
or research campaign.

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
