# Handoff

## Current parity pass (2026-10-19)

The #42 reconstruction was integrated into main at `18af340`; its matching Core
and TUI CI passed. #38/#39/#41 are closed; #40 remains open independently.
`tasks/issue42/HANDOFF.ja.md` is the reconstruction reference, not a pending merge.
The bounded Daily Pace/Balances context/navigation pass is on main at `f5ac74a`,
with matching Core/TUI CI, paired four-size synthetic native walks and cold reads.
Period/Today/Spent context, wide detail neighbours, Current columns and detail
return are improved; exact full-screen/Accounting and physical IME/human
acceptance remain open. `tasks/todo.md`, the UI gap ledger and `VERIFICATION.md`
own scope and evidence; this is not whole-screen parity acceptance.
The latest Daily Pace probe covers zero-origin/current-anchor-only paired four-size
walks, cold explicit Previous Cycle and separate LOAM bounded/opening observations.
A bounded presentation follow-up (`d696d80`) aligns Selected/change rows, full-date graph
endpoints and partial fallback History heading/selection. Grid/Braille, Detail
wording/order, target, missing-Previous-Cycle behavior and bounded-history evidence
remain gaps; arithmetic, support and publication gates are unchanged.
Other-screen publication now preserves a held Record/Pay draft; only its own
confirmed publication clears it. Operational cutover is not authorized. The user
authorized fresh read-only household/config copies and private paired observation for
AI development; raw private data must stay in restricted ignored scratch.

The AI must compare the latest ordinary LOAM data itself at each day's development
start and when resuming after ordinary LOAM updates; the optional human `./ui --daily` entrance does not satisfy
this requirement. Inspect source/remote status and pending edits, then run
`./tools/compare refresh` before that day's development. LOAM may remain open;
the existing before/after source checks refuse changes during copying and retain
the previous CURRENT. No new lock protocol is needed. Never terminate user processes
or write originals. Build current Bakhlo in the existing isolated environment
and walk the relevant screens before/after changes (including Core answers and
Daily Pace/Balances when relevant) with the existing LOAM executable on separate copies
from the same fresh capture, at normal user geometry and narrow geometry as relevant.
Reuse that generation within the pass; a small tool action does not need another
refresh. Use read-only navigation/details/resize/return flows and verify household/config
bytes are unchanged; no real household actions or writes without an explicit request.
Record only non-private findings, source/build identity, freshness, geometry and
limitations in existing verification/ledger sections. Refused/
unsupported conversion or missing executable means **latest-data paired comparison
not executed**, with the reason. Independent development may continue; neither
stale captures nor synthetic checks qualify as a fresh real-data comparison.
Keep synthetic regression, paired real-data observation, human/IME and P7 acceptance
separate. No unattended synchronization or scheduler is requested.

## Storage direction (2026-10-17)

The user selected **calendar-year S-expression files as the first implementation path**; see [decision](YEARLY_SEXP_IMPLEMENTATION_DECISION.ja.md) and [issue #34](https://github.com/shumoku88-bit/bakhlo/issues/34). Source-linked annual envelopes (`bakhlo-annual 1`), explicit rollover in TUI (`Household setup` → `Annual books / Start next year`) and CLI (`--annual-rollover`), current-year Balances/Daily Pace across pension cycles, single-authority cross-year plan discharge, frozen-predecessor and stale-provenance refusals, bounded multi-year reports, and exact-byte `--annual-backup` / `--annual-restore` are connected and verified on synthetic files. Power-loss/P7, noncooperative writers, real IME/human acceptance and operational cutover remain unqualified; LOAM stays production authority. See [verification](VERIFICATION.md#annual-sexp-ledger-completion-2026-10-17).

## Current task

The user selected systematic reproduction of all LOAM user-facing functionality,
appearance, interaction and fine details. Only budget allocation/transfer/consumption/
routing and Budget Window are deferred until actually needed; do not prebuild budget hooks.
Daily Pace, plans and bonsai behavior remain in scope. Internal structures and proof/
storage machinery need not match. LOAM remains production authority; no cutover is authorized.
`tasks/todo.md` owns the ordered acceptance plan, `docs/LOAM_UI_GAP_LEDGER.ja.md` owns
per-screen F/O/V/Q progress, and `docs/VERIFICATION.md` owns exercised evidence.
The user explicitly excluded Fava and hledger export from parity and cutover
requirements. Other external output and Print/diagnostics remain separate,
not implicitly excluded. Historical interchange designs are not current
implementation instructions for hledger.

UI-24-B2 connects the visible-account picker (`c` / Household setup) and
multi-coordinate Observe. Picker uses j/k, Space, Enter Review, Esc/e Edit;
it preserves other Measures, historical selections, empty vs missing and
unknown quantities. Only `balance-view.tsv` changes, with stale/admission checks.
Observe uses Add → Preview → Publish/Edit/Cancel and the existing grouped Core
and writer; unmentioned observations remain intact. Duplicate/support conflict,
hidden review, stale base and uncertain-save retry are refused without dropping
the retained Preview. Synthetic Core/native checks, paired LOAM binary interaction,
normal save/cold reopen and an actual permission-failure/uncertain-reload refusal
passed for this bounded scope; see [B2 evidence](VERIFICATION.md#ui-24-b2-balances-picker-and-grouped-observation-2026-10-18).
Daily Pace/Balances responsive sprint now has local Core/native self-check and
four-size synthetic PTY evidence. Pace uses a separate Today summary, compact
exact basis rows, date-preserving period switches and full-width focused detail.
Balances keeps the selected coordinate across Current/Accounting, retains Measure
on unknown/overflow rows, and fixes End→Up/resize motion. Print Preview is scrollable,
closes on Enter/Escape, keeps parent context and refuses >200 lines/>32768 UTF-8 bytes.
The existing 80-column stacked layout and malformed-view Print refusal are exercised.
See [sprint evidence](VERIFICATION.md#daily-pace-and-balances-responsive-completion-sprint-2026-10-18).
Full Accounting/output parity, dated Pace support and paid/cancelled-plan history,
physical IME/human acceptance, power loss/P7 and adoption remain open.

UI-33 / UI-02 Daily Pace cycle boundaries and Household setup commands are now
connected: `Space` → `Household setup` exposes `Daily Pace / spendable accounts`,
`Daily Pace / cycle dates`, and `Balances / visible accounts`, and pressing `b` in
Daily Pace opens the cycle boundary editor (`name`, comma-separated increasing
YYYY-MM-DD dates covering today, up to 32 boundaries) → full Review → save only
`boundary-presets.tsv` while preserving other named presets. Review Escape/Edit
returns to the retained input; narrow views refuse confirmation. Native synthetic
checks and a cold Bonsai trial passed; see
[cycle boundary evidence](VERIFICATION.md#cycle-boundary-setup--household-setup-commands-2026-10-17).
LOAM paired UI, IME and operational acceptance remain open.

UI-30 Locus display names (`B.set_locus_label`, `B.help`, `A.commit_set_locus_label`)
and UI-29 Exchange 2-step Preview are connected: `Space` → `Household setup` →
`Account / category display names` (and `l`/`e` in Manage Loci) edits a Locus's
display name and optional help description through a full-visibility Review gate
before updating the monolithic book's `labels`. Exchange (`Space` → `Transactions`
→ `Exchange`) now validates inputs and transitions to `Exchange / Preview` with
Escape/Edit draft retention and a narrow-terminal confirmation gate before
publishing. Core and native self-checks passed; see
[evidence](VERIFICATION.md#locus-display-names--exchange-preview-gate-2026-10-17).

UI-34 first-run initialization is connected for an interactive `--book FILE` startup:
missing paths may be prefilled; existing unreadable paths start with a blank destination.
The user supplies one Measure/scale, reviews the exact destination and empty-book meaning,
then confirms creation. `Daily_book.empty` admits one Measure/scale and an explicit empty
Locus policy; existing Manage Loci can admit the first Locus. `Daily_file.create_empty`
uses exclusive mode-0600 creation, file sync/readback, parent sync and cold reload.
Loaders, `--check`, and non-TTY paths remain fail-closed; existing source/destination
bytes are protected. A fresh paired 80×24 first-run/one-Record/cold-reopen
scenario is recorded; broader LOAM parity and operational acceptance remain open.

The first-run review now matches LOAM's missing-root cancellation flow: Escape
or Edit returns to the retained destination/Measure/scale editor; Escape there
cancels without creating the book. A paired 80×24 synthetic execution and native
self-check cover this bounded path. A subsequent paired 80×24 synthetic
existing-unreadable-root check confirmed blank destinations, retained input
after review Escape, cancellation without writes and existing-target refusal.
LOAM refuses an existing target after review; Bakhlo refuses before review.
See [missing-root evidence](VERIFICATION.md#paired-first-run-review-cancellation-2026-10-17)
and [unreadable-root cancellation evidence](VERIFICATION.md#paired-existing-unreadable-root-first-run-2026-10-17).
Creation from a different existing-unreadable synthetic root has since been
paired at 80×24: both reviews were non-writing, explicit confirmation created
new authorities, and cold TUI reopen reached Home; source and new-authority
hashes were unchanged. At 32×9, both missing-root paths were cancelled
without creation. A 48×14 comparison exposed Bakhlo creating a new book while
the destination was hidden by `… more`; `First_run.ready_to_create` now checks
the actual form viewport. The rebuilt UI refused at 48×14, allowed full review
after resize to 80×24, and cold-reopened at 48×14. LOAM created at 48×14 with
a truncated displayed path. Failure injection, IME and P7 remain open; see
[creation evidence](VERIFICATION.md#paired-unreadable-source-creation-and-cold-reopen-2026-10-17)
and [narrow evidence](VERIFICATION.md#paired-narrow-first-run-and-hidden-destination-gate-2026-10-17).

This bounded implementation does not close the broader first-run acceptance.

A separate synthetic Actual search comparison showed one row for each of
`paired` and `other`, zero for `zzzz`, and both after Escape at 80×24. In the
rebuilt Bakhlo binary, active `/paired` survived resize to 48×14 with `+37 jpy`
fully visible; `/other` at 48×14 showed full `+11 jpy`, then Escape and restore
to 80×24 returned both entries. A subsequent fresh synthetic comparison confirmed
32×9 Description-only rows, retained `/other`, Escape restoring both entries,
and matching long-CJK search tail/caret coordinates. Empty Actual views now show
`0–0 / 0`, not a counted placeholder; empty-book/no-match checks cover five sizes.
This remains bounded search evidence, not cross-screen or human acceptance. See
[verification](VERIFICATION.md#actual-empty-search-and-cjk-resize-follow-up).

Actual Enter now opens the selected entry directly from Transactions or Details,
matching the current LOAM source and existing binary; `i` remains pane preview.
The controller anchors Selected Day by ID and clears its old filters, avoiding
wrong/absent selection among same-day entries. Direct-list return and explicit
Details return preserve their respective parent pane, query, order and selection.
Core/native checks and bounded synthetic paired scope/sort, empty refusal and
32×9/48×14 return flows passed; see [evidence](VERIFICATION.md#actual-single-enter-and-filtered-return).
The child remains Bakhlo's Selected Day, not full LOAM transaction-detail parity;
its context now uses the route date and Day view, without changing the background
Calendar date/zoom. Checks cover four sizes × three background zooms, with/without
a retained Record draft; a synthetic native resize/draft smoke passed. Other UI-04
gaps and human acceptance remain open. See [context evidence](VERIFICATION.md#selected-day-context-date-and-zoom).

The shared-UI responsibility design is now fixed in
[TUI共有部品の責務設計と移行順序](TUI_LAYOUT_STABILITY_ROADMAP.ja.md), replacing the
old renderer-refresh roadmap. Bonsai/Notty, native Columns composition, frontend width,
final fit and after-display cursor stay. No custom renderer/Unicode table, layered raw
ANSI, scene engine or state framework is adopted. Editing stays in Daily_form; display
windows/recursive Input metadata belong in Daily_overlays; panel/form geometry is shared,
while IDs, query/selection, drafts, review/publication gates and refusal recovery stay local.
Ui_workspace and Actual_workspace remain separate. returned_from_detail is connected
to controller drill-back, with bounded synthetic evidence, not full parity acceptance.

The first migration unit is implemented: Daily_overlays.input_text shares the existing
Record tail/insertion-cell approach; input_cell recursively translates Columns metadata;
cursor_in_rows hides caret positions outside the supplied painted row/width. Permanent
boundary checks live in daily_interaction_checks.ml and use frontend width_of.
tools/check, build-bonsai-tui and the native self-check passed. A direct compiled smoke
also exercised 120→8→edit→120 cell windows and nested parent caret translation using
native Bonsai width. See [verification](VERIFICATION.md#shared-input--recursive-metadata-slice).

The subsequent warning cleanup removed unreachable code in recovery_checks.ml
and, with explicit user approval, rebuilt the same isolated Zarith version and
five reverse dependencies from a corrected macOS package recipe. The generated
native target was cleaned/rebuilt without either compiler/linker warning; its
self-check including the real writer-lock/SIGKILL fixture passed. No installed
package version changed. Keep the ignored local Zarith pin source directory;
see [reproduction](DEVELOPMENT.md#bonsai-isolated-linker-recipe) and
[evidence](VERIFICATION.md#native-build-warning-cleanup). Main/global environments
and household data were not changed.

The third migration unit is connected: Record and Scheduled creation use shared
input windows and painted Input metadata. Record's combine_side_by_side is removed
in favor of native Columns composition with independent child styles, and its
controller extracts recursive carets via cursor_in_rows. Scheduled creation uses
Daily_overlays.input_text, Daily_form.move_cursor for UTF-8 navigation, Ui_panel
field windowing, 1-line notice reservation with explicit `… more` overflow, and
uniform row width padding. Sch.cursor_position is removed. Scheduled creation is now
included in the 8-dimension × 3-theme render_cases matrix and passes without row-width
failures. Core suite (tools/check) and native build/self-check passed. Synthetic tmux
walks covered editor carets/resize/cancel only; the attempted Record entry sequence
filled the wrong fields and did not qualify publication or lifecycle acceptance.
The fourth migration unit is connected: Actual workspace geometry and drill-down/
back routes are unified. terminal_geometry delegates to panel_geometry, and
Transactions page_size uses tx_height (matching the painted 3-pane height at 80×24 /
120×36 and panel_height when compact). Controller passes actual_dimensions to
Act.handle matching Act.screen. Drilling down from Actual into Selected_day via Details
captures the parent book. A subsequent regression check exposed return-time writes into
the Selected Day browser and lost detail focus/scroll. sync_actual_to_workspace now
updates only workspace.actual; back enters Actual before restoring its pane/scroll,
without W.sync re-sorting or resetting them. Synthetic checks cover ID-preserving return
after an in-memory date correction, filtered/sorted/Locus-selected scrolled return,
and the blocked-Reversal safety footer. Native tmux confirmed the scrolled detail
return at 80×24 and after shrinking to 48×14. See
[evidence](VERIFICATION.md#listdetail-capacity-and-drill-downback-cutover).
Direct Actual publication also restores selection by ID through the same existing helper,
including Record correction after date reordering; search/scope exit is explicitly notified.
See [correction return evidence](VERIFICATION.md#actual-correction-publication-return).
Fresh Record from Selected Day now inherits the route's date, not the background
calendar; held drafts remain unchanged. Cancel/resume, save/cold and drill-back have
bounded [synthetic evidence](VERIFICATION.md#selected-day-record-date-and-return).
Browsing Ctrl-N now opens a Keep-default confirmation for held Record drafts;
explicit Discard alone clears local input. Tiny refusal resets Keep, and uncertain
publication/recovery guards remain in `discard`; see [evidence](VERIFICATION.md#retained-draft-discard-confirmation).
Steps 1–4 are connected with limited checks, not accepted as full LOAM parity.
The ordered acceptance items for shared UI, Record and Actual/Selected Day remain open;
role-aware totals, Merchant/OriginalAmount and Scheduled gaps remain in scope.
Date-only correction is now connected through `date_correction_session.ml/.mli`:
`d` from Actual/Selected Day opens a captured-target Date → Preview flow; the existing
`commit_transaction` replaces only the date and retains ID, Effects/keys and paid-plan links.
Tiny/unreviewed-target confirmation refuses, retained Record drafts block entry, and
stale reload cannot bless the captured base. Records replacement remains refused.
Core/native checks and synthetic tmux cancel, shrink/refuse, publish, parent-ID return
and cold restart passed; see [date evidence](VERIFICATION.md#actual-date-only-correction).
Paired LOAM execution, IME and user acceptance are not supplied by these checks.

Scheduled cancellation now has a local `scheduled_cancellation_session.ml/.mli`:
`x` → retained cancellation-date input → independent expected-effects Preview.
Keep is the protective default; explicit selection and Enter alone cancel.
Shared Ui_form/Ui_panel handle display, while target/base, choice, end/tiny gates
and refusal recovery remain local. The old immediate-submit modal is removed.
Retained Record drafts block entry; storage refusal preserves evidence and resets
the choice to Keep, and reload cannot bless stale confirmation. Core/native checks
and synthetic tmux Keep/no-write, shrink/refuse, explicit cancel and cold restart passed.
See [cancellation evidence](VERIFICATION.md#scheduled-cancellation-preview).
No new writer/schema, LOAM runtime acceptance or broader Scheduled parity is claimed.

Scheduled Months is connected through `scheduled_months.ml/.mli` and independent
List/Months browsers in Ui_workspace. `v` toggles views while preserving List filters
and visible selected IDs; `h/l` moves the six-month window, `j/k` follows selection.
Only explicit current-open plans are projected; no Series/coverage/recurrence inference.
The native 2×3 board has exact receiving amounts or split markers, selection-following
card windows, selected details and a compact `v opens List` fallback. `i/Tab` opens
full scrollable details; Enter/c uses existing completion, r/e edit, x cancellation.
Unused Groups/cycle API is removed; initial Scheduled remains List.
Core/native checks and synthetic tmux at 120×36/80×24/48×14/32×9 passed for this slice;
[Months evidence](VERIFICATION.md#scheduled-months-projection) records boundaries and
the non-saving smoke. LOAM paired/user acceptance and full Scheduled parity remain open.

Post-completion Scheduled continuation awareness is connected through
`scheduled_continuation_session.ml/.mli`. After atomic completion publishes, a
prompt surfaces any later open plan with the same positive Locus set. The user
chooses Keep/Done (protective default; no-op), Review (scrollable candidate details),
Defer (adds a Due_undetermined Attention item without Scheduled mutation), or
Add next (opens the Scheduled creation editor with the same structure and empty date).
No series, recurrence, cadence, or date is inferred.
Core/native checks and synthetic tmux (Done, Keep, Add next, Escape cancel, and cold
restart) passed; see [continuation evidence](VERIFICATION.md#scheduled-continuation-awareness).

Scheduled batch amount editing (UI-20) is connected through `scheduled_bulk_session.ml/.mli`
and `Daily_actions.commit_plan_batch`. Pressing `b` from Scheduled (List, Months, or detail)
or Selected Day on an open plan opens the 3-stage flow:
1. Parameters: exact positive amount in the target measure, from date, optional through date.
2. Candidates: advisory match on identical measure and sorted positive/negative Locus sets,
   initially all unchecked (`[ ]`), Space toggle, `a` all, `d` clear, `e` parameters, split
   postings excluded without guessed allocation, unchanged amounts omitted.
3. Preview: before -> after signed details, Back protective default, current dimension
   and review-to-the-end gates.
All selected replacements are folded into a single candidate book and committed via the
existing publisher in a single atomic write.
Core/native self-checks and synthetic tmux walks (Parameters, candidates `a`, Preview,
Back read-only proof, `Publish all`, cold restart, and unchanged unrelated plan preservation)
passed; see [batch amount evidence](VERIFICATION.md#scheduled-batch-amount-editing).

Scheduled occurrence generation (UI-21) is connected through `scheduled_generation_session.ml/.mli`
and `Daily_actions.commit_plan_batch ~replace:false`. Pressing `g` on an open plan in Scheduled
opens the generation workflow:
1. Parameters: Through date (exclusive) and Cadence (Monthly, 2m, 3m, 6m, Yearly).
2. Generation: Proposes explicit dates stepping by cadence, clamping nominal days to valid month ends.
3. Preview: Lists all generated candidate occurrences with dates and amounts.
   Cancel is the protective default (zero disk writes).
4. Atomic publication: All generated occurrences are created with fresh IDs and committed
   together in a single atomic transaction. No recurrence rule is persisted.
Core/native self-checks and synthetic tmux walks (Cancel non-writing, 5 occurrences generation,
atomic cold restart, exact EUR quanta preservation) passed;
see [Generation evidence](VERIFICATION.md#scheduled-occurrence-generation).


Balances Current view (UI-24) is connected to match LOAM's `Balances.lean` model:
- Home `b` opens `Balances / Current` directly in neutral coordinate mode using `balance-view.tsv`.
- List pane supports `j/k`, `PageUp/Down`, `Home`, and `End` for fast coordinate selection.
- `Enter`, `i`, `Tab`, or `h/l` expands the scrollable Detail pane (`Selected Balance`).
- `Esc` or `q` in Detail returns to the List pane without exiting Balances; `Esc`/`q` in List returns to Home.
- `v` toggles between `Balances / Current` and `Balances / Accounting` (RoleBalances).
- `p` opens a scrollable, preview-only Current/Accounting report (200 lines / 32768 UTF-8 bytes including headings/newlines); Enter/Esc/q closes without losing parent selection/scroll.
- `o` opens the selected Locus/Measure collector (exact amount is only a hint); Add → Preview → Publish observes one or more coordinates together.
Core/native self-checks and synthetic tmux walks (opening Current, Page/Home/End navigation,
detail expand/collapse, Print modal, `v` accounting toggle, and Home return) passed;
see [Balances evidence](VERIFICATION.md#balances-current-view).

Daily Pace Trend is connected through `daily_pace_trend.ml/.mli` and `daily_interaction.ml`:
- Home `d` initially selects today. Presets `1`–`5`, qualified Braille line/dots (`v`), bounded day navigation, What-if and explicit Pool/cycle setup remain connected.
- The chart is above History / Selected day; compact views prioritize the chart and open full-screen details. History separates discretionary Spent and same-day Pace diff from prior-day change.
- Day activity nets each entry across the Pool, separates Scheduled completions and reversals, ignores same-day reversal pairs, and keeps Measures distinct. Adjacent-day explanations use exact integer arithmetic and refuse cycle resets/unsupported days.
- A current quantity observation alone no longer manufactures historical Pace. Older days require zero-origin support for every Pool coordinate; unsupported days retain independently known activity but do not paint dummy zero balances.
- Paired synthetic current-only and zero-origin books, four terminal sizes, detail/return and cold reopen passed for this bounded display slice. Broader dated history, completed/cancelled-plan history, LOAM geometry/keys and human acceptance remain open.
See [paired history and narrow Balances evidence](VERIFICATION.md#pace-history-and-narrow-balances-paired-2026-10-18).

Income & Expense Report (UI-25) is connected through `income_expense_report.ml/.mli` and `daily_interaction.ml`:
- Launched via Commands (`Space` -> `Reports and analysis` -> `Income & Expense`) or `open_route W.Income_expense`.
- Period presets: `1` (Month), `2` (Cycle), `3` (Previous Cycle), `4` (Year), `5` (All Time).
- Cycle periods resolve directly from `boundary-presets.tsv` windows (`a <= today < b`).
- `[` and `]` shift periods backward and forward (months or adjacent cycles).
- Evaluates P/L from entries matching `start_day <= e.day < end_exclusive`:
  - Income: negative quanta on `Income` loci (credit) -> positive income display (`-quanta`).
  - Expense: positive quanta on `Expense` loci (debit) -> positive expense display (`quanta`).
  - Disentangles Scheduled-linked expenses from ordinary ad-hoc expenses.
  - Identifies unassigned loci under `Unresolved Role Effects` without assuming zero or income.
  - Net Savings = Total Income - Total Expense per currency.
- Print preview modal (`p`) and Detail pane expansion (`Tab`/`i`).
Core/native self-checks and synthetic tmux walks (launch via Commands, Month display,
Cycle switch, Print modal, and Home return) passed;
see [Income & Expense evidence](VERIFICATION.md#income--expense-report).

Transactions Flow Report (UI-25/Flow) is connected through `transactions_flow_report.ml/.mli` and `daily_interaction.ml`:
- Launched via Commands (`Space` -> `Reports and analysis` -> `Transactions Flow`) or `open_route W.Transactions_flow`.
- Period presets: `1` (Month), `2` (Cycle), `3` (Previous Cycle), `4` (Year), `5` (All Time).
- Period shifting via `[` / `]`.
- Incidence matrix computes exact two-sided coordinate activity:
  - `positive`: sum of positive quanta (+In).
  - `negative`: sum of negative quanta (-Out).
  - `net = positive + negative`.
  - `gross = positive - negative` (total movement volume).
  - `active_events`: count of contributing transactions.
- Sorted by `gross` descending (salience order), followed by coordinate lexical order.
- Left pane displays tabular summary; right pane displays contributing transactions for the selected coordinate.
- `j`/`k` moves selection and updates contributing transactions immediately.
- Print preview modal (`p`) and Detail pane toggle (`Tab`).
Core/native self-checks and synthetic tmux walks (launch via Commands, Month/Cycle/All-Time,
row selection with detail update, Print modal, and Home return) passed;
see [Transactions Flow evidence](VERIFICATION.md#transactions-flow-report).

Stock–Flow Report (UI-25/StockFlow) is a bounded tracked-balance view connected through
`stock_flow_report.ml/.mli` and `daily_interaction.ml`:
- Launched via Commands (`Space` -> `Reports and analysis` -> `Stock–Flow`) or `open_route W.Stock_flow`.
- Period presets: `1` (Month), `2` (Cycle), `3` (Previous Cycle), `4` (Year), `5` (All Time);
  `[` / `]` shift the period.
- Selection is the explicit `balance-view.tsv` coordinate list. Every selected coordinate
  must use the requested single measure; mixed-measure selections are refused, never filtered.
  No currency/measure switch is offered.
- Historical start/end balances are reconstructed from zero-origin event history. Exact
  current support and independent historical evidence are both required for every selected
  coordinate; unknown or unsupported current quantities and missing historical evidence
  prevent a report. This is not an archival snapshot.
- Displays selected-coordinate increases, decreases, net change and reconstructed balances;
  it does not reconcile against Income & Expense or prove accounting balance.
- Print preview (`p`) and Detail pane toggle (`Tab`).
Earlier recorded smoke output described a cross-currency view and a balanced Net Savings
reconciliation; that evidence is invalid for financial correctness and is withdrawn. No
current Stock–Flow verification or financial correctness certification is claimed. This
bounded view is not LOAM-complete; broader report parity remains open.

Attention Administration (UI-26) is connected through `attention_data.ml/.mli` and `daily_interaction.ml`:
- Launched via Home `i` or Commands (`Space` -> `Attention`).
- Home footer dynamic indicator badge:
  - Overdue items: `[i] attention (! N overdue)`.
  - Due today: `[i] attention (today)`.
  - Open items: `[i] attention (N)`.
  - Empty: clean `[i] attention`.
- Tabular left pane layout matching LOAM: `Due` and `Matter / Context` columns.
- Due dates: `! YYYY-MM-DD` for overdue, `today`, `due YYYY-MM-DD`, `no due date`, and `due unknown`.
- Right pane displays full matter description, urgency analysis, item ID, and lifecycle state.
- Actions:
  - `n` (New): modal form with 3 due types (No due date, Due undetermined, Due on date).
  - `r` (Resolve): modal confirmation, records resolved closure with today's date.
  - `x` (Drop): modal confirmation, records dropped closure with today's date.
- Navigation: `j`/`k` move selection, `Tab`/`i` focus detail scroll, `q`/`Esc` return.
Core/native self-checks and synthetic tmux walks (Home badge display, add overdue item,
overdue flag in table and detail, resolve, and Home badge removal) passed;
see [Attention evidence](VERIFICATION.md#attention-administration).











The preceding six-document design-only task checked source consumers and relative links
without product changes. The geometry research continues to own counterexamples/external
research/uncertified boundaries: G-1/G-3 are earlier synthetic executions, G-4 is source
evidence, and the fixed G-2 Actual-search slice remains bounded evidence. G-1/G-3/G-4
are not closed by standalone helper checks. Auto-wrap, grapheme, macOS IME/preedit,
live-output races and P7 are not certified. Production protections below remain unchanged.

### Historical bounded evidence
The following earlier slices are historical, bounded evidence, not current parity certification.

The first safety slice qualifies synthetic Attention/settlement sidecar input and
save refusals, stale-state refusal under the existing cooperative writer lock,
draft preservation, explicit Pace pool/unique period selection, negative What-if
integer arithmetic, and Pool-only configuration edits that preserve every period
preset. No cross-file transaction or new storage framework was added. Existing
`tools/check` and `tools/tui --self-check` passed locally; full LOAM execution
comparison, native PTY/manual UX acceptance, power loss and P7 are still open.

The next bounded Actual browsing slice adds aligned exact/grouped receiving amounts,
explicit split/multi/see-details summaries, live filtering inside the existing Search
modal, visible-capacity paging, clamped detail endpoints/resize and Record draft/parent
restoration tests. Synthetic Core/UI and native PTY checks passed at 80×24, 120×36,
48×14 and 32×9. LOAM `94ceb072` was inspected read-only; paired visual/manual acceptance
is still open. Actual still uses two panes, not LOAM's Loci/Actuals/Details layout;
inline search, Locus filtering UI and separate date-change/Merchant actions remain gaps.

The user then approved shared UI mechanics before further screen expansion.
`ui_panel.ml/.mli` now owns framed capacity/window painting and integer-safe offset
movement; Actual and Scheduled use it for list/detail navigation, with their content,
identity, keys and publication decisions still owned by the controller/application.
The duplicate Actual pane composition was removed. Scheduled gains clamped detail
Home/End/paging and focus/resize behavior; its writer/actions remain unchanged.
Independent panel and both-workspace tests plus eight synthetic native PTY walks
passed. See `tui/README.md` and the current responsibility design for KEEP/integration/LOCAL
boundaries. That earlier slice did not newly generalize Record Preview,
pickers, floating surfaces or amount formatting.

The user requested an inventory suitable for delegating visual/specific-surface work
to other pits in parallel. [The UI gap ledger](LOAM_UI_GAP_LEDGER.ja.md) now separates
F (feature/retained data), O (interaction/wiring), V (visual), and Q (verification/safety),
keeps UI-01..33 identities, and supplies P01..P08 delegation cards with allowed files,
shared boundaries, evidence and integration rules. The feature/cutover table agrees:
Series Calendar/Months and Pace history are unconnected, not screenshot-only gaps.
This organization used Bakhlo `b21b30c` plus the uncommitted shared-panel work and
LOAM `db631763` source/contracts; it did not run a new LOAM comparison or change code.

The user assigned P02 Record appearance to another pit and approved this pit's P05
reversal-safety slice. `reversal_session.ml/.mli` now owns Date/fixed-target Preview,
exact signed original/inverse quantities, end/tiny gates and local cancel/edit.
The controller retains the captured base/date on failure or changed reload, blocks
held Record drafts, and closes confirmed uncertain intents without retry. The writer,
canonical format, shared form and Record implementation were not changed by P05.
A native resize counterexample required one shared frontend fix: read dimensions via
`Bonsai.state_machine_with_input` at action application, not an older handler closure.
Synthetic reversal/controller checks and six reversal plus eight shared-panel PTY
walks qualify this bounded slice; LOAM paired visual/manual acceptance and P7 do not.
P02 advanced HEAD independently to `0f611cd`; preserve its Record and ledger work.
Verification records the source/binary pinning and integration evidence.

The user closed today's work and authorized a main/remote checkpoint and removal of
unneeded merged branches. Both repositories already have only main locally/remotely;
LOAM is fast-forwarded to its already-merged remote source without rebuilding or
changing household data. The remaining Bakhlo UI/doc/Record paint changes were reviewed
and Core/build/UI self-checks passed on an unchanged source manifest before committing.
P02's final polish is committed independently as `7ba68de`. Final integration caught
its Preview paint/gate capacity mismatch: End allowed publication before the final
lines were visible. `review_geometry` now reserves the painted title/gate/action rows,
with a regression requiring the full N/N review counter on the publishable end page.

Following user feedback on interactive Record entry and overlay behavior, five targeted
commits further aligned Bakhlo with LOAM and resolved critical TUI interaction bugs:
- `12a8f13`: Typing in posting accounts resets candidate selection to top (`candidate=0`),
  enforces 6-row posting maximum on `add_row`, and allows advancing focus even when 0 candidates match.
- `de7cc92`: Ultra-compact (height < 21) Fields panel borders and margins were aligned with
  LOAM standard (`sub_border`, `inner_line`, `sub_bottom`).
- `43e03e0`: Implemented `Ctrl-U` shortcut in Record session to balance remaining posting amount
  with an unresolved suspense locus (UI-08), automatically creating, adjusting, or removing
  the suspense line when balanced, adhering strictly to the 6-row cap.
- `5a41147`: Converted Locus picker search from substring matching to prefix matching (LOAM
  `LocusCatalog.search` / `isPrefixOf` parity) with exact matches sorted first. Added strict input
  guards on Date field against non-date characters (preventing corruption from IME input). Fixed
  draft isolation between Record and Scheduled so that opening Record never resumes a Scheduled draft.
- `6316822`: Unified floating overlay geometry and cursor tracking via `resolve_overlay` in
  `daily_interaction.ml`. Solved terminal cursor and macOS Japanese IME candidate window
  displacement by establishing a single source of truth for pane coordinates `(origin_x, origin_y)`,
  content rows, and physical cursor positioning across all overlays.
- `07b922e`: Decoupled Scheduled creation into dedicated session `scheduled_session.ml` (UI-16 / P09)
  matching LOAM `ScheduledPostingForm.lean` / `ScheduledCreation.lean`. Description is completely
  excluded; enforces Due date, fixed currency measure, 2-6 rows limit, strict numeric Date input guards,
  Locus prefix matching with exact matches first, `Ctrl-U` suspense auto-balancing, tiny terminal
  gate (`previewCapacity < 2` rejection), and complete isolation from Record drafts. Registered with
  `resolve_overlay` for single-source cursor positioning. Added full synthetic test suite
  `scheduled_session_checks.ml`.
- **Actual Workspace Parity (UI-03 / UI-04, P03/P04)**:
  Implemented LOAM-compatible 3-pane Actuals Workspace (`tui/actual_workspace.ml/.mli`, `actual_workspace_checks.ml/.mli`)
  matching LOAM `ActualWorkspace.lean`:
  - 3-pane layout: Loci filter list (top-left), Actuals transactions list (bottom-left), and Details panel (right).
  - Locus live filtering with count headers (`Loci (N)`), cycle filter scope (`f`: Focus Day / All Current), sort order toggle (`s`: Asc / Desc).
  - Inline live search (`/`) with real-time text matching, backspace, and cursor tracking via `Act.cursor_position` on headers (macOS IME friendly).
  - Details panel scrolling (`j/k`, `PageUp/Down`, `Home/End`) with scroll indicator (`▲▼`).
  - Two-step Enter behavior (Transactions -> Details -> `Selected_day` drill-down).
  - Dynamic geometry normalization (`normalize_for_bounds`) preserving Details scroll limit across terminal resizes without re-selection.
  - Comprehensive test suite in `actual_workspace_checks.ml` covering all 10 navigation, selection, search, and boundary properties. All tests and regression checks passing.

Existing private/synthetic scratch and detached qualification worktrees are retained.
This source checkpoint does not qualify runtime parity, power loss/P7 or cutover.

The latest work starts the ordered runtime-comparison plan with Actual inline search.
Two isolated empty synthetic authorities were opened using native Bakhlo and existing LOAM
binaries: Home → Actual → `/` → long ASCII/CJK query → shrink → enlarge → Enter →
`/` → Esc → parent → quit. Bakhlo previously painted the query prefix while LOAM kept
the insertion tail visible. Actual now derives its visible search line and physical caret
from one width calculation, with a blank insertion cell and the final terminal column reserved.
The existing Record tail helper moved to `Daily_overlays.tail_text`; Record uses the same logic.
Query/filter values and all publication paths are unchanged.

The current geometry research remains relevant: generic-form G-1 (pane/caret mismatch),
G-3 (short-notice movement) and Record G-4 (mixed-pane styling) are not fixed by the
Actual search slice. Do not claim `resolve_overlay` alone proves visible-caret correctness.
Continue the shared-input boundary before Record lifecycle, Actual/Selected Day, Scheduled,
and the remaining non-budget inventory. Scheduled cancellation/replacement still need
independent review gates; role-aware summaries and missing retained facts are functional gaps,
not paint-only work. Central controller edits remain serialized.

Source/binary identifiers, exact smoke results and remaining visual differences belong to
the Actual search comparison section in `VERIFICATION.md`. Full-workspace parity, real
macOS IME/manual acceptance and P7/power-loss/cutover remain open.

## Storage research context

The historical [year-partition comparison plan](YEAR_PARTITIONED_SEXP_RESEARCH.ja.md)
records Jan 1–Dec 31 storage, current-year + qualified opening evidence, independent
analysis/cycle boundaries, cross-year references and past-correction invalidation.
The current implementation direction and exercised slice are at the top of this handoff.
The first synthetic comparison is 2025-10-15 through 2026-10-14, six two-month cycles;
actual adopted payment dates define cycles, never an implicit always-the-15th rule.
Compare meaning, answers and refusals against the existing single-file Core/Daily_book oracle.
Persisted rollover/multi-file atomicity and recovery remain unresolved. The historical
comparison is not a requirement to repeat research before completing usable slices.

Irmin [Phase 1](IRMIN_STORAGE_RESEARCH.ja.md) and [Phase 2](IRMIN_PHASE2_RESULTS.ja.md)
are complete within their stated scopes. Partial branch writes followed by EIO/SIGKILL
left an existing branch with no resolvable HEAD. Normal atomic-generation/restart/limited
archive checks passed, but durable Saved/power-loss/P7 remain unqualified. Irmin product integration
is **on hold**; no root manifest. SQLite remains a comparison candidate, not an installed
product dependency or an executed Bakhlo backend comparison.
Synthetic Irmin sources and frozen dependency recipe are preserved in the Phase 2 appendix;
raw/failure evidence and its separate opam environment remain ignored and must not be pruned.

[Canonical design](CANONICAL_DATA_DESIGN.ja.md) owns retained facts/reference roles, LOAM
reuse and logical/native/formal residuals; [storage study](LONG_TERM_STORAGE_STUDY.ja.md)
owns baseline/save decomposition/direct-printer/quote-length measurements. Neither printer
trial is adopted. Do not repeat earned semantics or turn a conditional Alloy/Lean slice
into a proof of combined C, OpeningSupport inheritance, archive completeness or durability.
Historical decode is not writer permission. Current-use-first, identity/evidence preservation
and equal-operation cost/recovery/maintenance remain the constraints, not manual syntax polish.
The earlier private inventory is complete at `scratch/operation-inventory-leEhTN` (scope in
canonical design); its counts/findings stay private and are not a UI frequency log.
This next study uses synthetic data only. LOAM remains operational authority; preserve all
originals/trials/backups/uncertainty artifacts. No format/backend/UI adoption or data cutover.

## UI context

Reproduce LOAM's appearance and usability in Bakhlo. The target is Calendar Home
with Day / Month / Year, hierarchical Commands, and matching entry points,
navigation, confirmation, cancellation and return behavior for shared capabilities:
recording, Actual, Scheduled, Balances and Daily Pace. Build the new UI in English
with LOAM's labels first. Japanese UI is undecided. Implement Bonsai first;
a later Notty implementation remains an option, not an excluded frontend.
The English foundation is connected; full LOAM parity remains a target.
Home and basic Record / Preview polish have reached a verified checkpoint.
The comparison helper copies current LOAM data read-only into separate private
copies, short Bakhlo/LOAM launch commands, and direct root-palette theme selection.
These remain available; the current storage investigation does not authorize cutover
or expansion into accounting features.
The usage inventory used a separate verified fresh stopped capture. It did not update
comparison CURRENT or any prior writable trial. A selected comparison capture exists,
but its currentness/full compatibility has not been requalified here; inventory success
is not a successful fresh paired-UI conversion or operational cutover.
Home uses nearby/side-by-side Detail and a compact Calendar; Record floats while
retaining the parent date, with full-screen tiny input, border-only semantic colors
and explicit caret cell metadata. Tiny overflowing previews refuse publication;
ordinary paged previews require the final viewport before selected Publish + Enter.
Consult
LOAM's research on the limits of sharing before choosing reusable components;
do not assume every editing screen should be shared. Read [UI_DIRECTION.ja.md](UI_DIRECTION.ja.md) for the scope and rules,
including quiet terminal-owned colors, thin rounded frames, focused selection,
stable geometry, contextual bottom operations and wrapping feedback.

Bakhlo is not yet used as the operational household ledger. Old UI layouts,
themes and unused helpers may be replaced or deleted without compatibility.
Calendar Home is selected. Preserve Bakhlo's accounting contracts; this UI work
does not restore budgets, authorize new accounting assumptions, require LOAM's
entire accounting feature set, or introduce a new frontend framework.
Calculator UX-3 now accepts exact arithmetic in positive amount fields via
`Daily_book.parse_amount`; signed Posting prefixes apply to the entire expression.
Core/native Record checks cover precedence, quanta, refusal and retained drafts.
Paired LOAM UI, IME and real terminal acceptance remain open.

Scope lesson: “LOAM-compatible UI” means its appearance and interaction, including
the Home structure and navigation; do not reduce it to styling or treat English
labels as an optional translation of the old Japanese UI.

## Authority and private data

- LOAM remains the operational authority; normal recording and its original
  household/config files stay there. No cutover, write, recovery, synchronization,
  reconstruction or migration of those originals is authorized by UI work.
- The earlier approved read-only capture and Bakhlo-native candidate are separate
  from cutover. Corrected entries may omit correction chains, but exact currency
  quantities, actual refunds/reversals, quantity support and plan-payment links
  must not be guessed or discarded.
- The private trial `scratch/daily-ui/household.sexp` and earlier candidate
  `scratch/daily_book_candidate_v1/household.sexp` exist. UI work/tests use
  synthetic copies instead. Do not put private contents, counts, screenshots
  or logs into fixtures, commits or public output.
- Approval also covers bounded read-only inventory of retained operation
  evidence in LOAM canonical history, using fresh copies and stability
  checks. Preserve old captures/trials; LOAM may remain open during copying,
  but changed inputs refuse. Do not silently substitute older evidence. Unknown/imported/current-only
  evidence is not a full count of user actions. No private counts in public docs.
- Private inputs/results remain ignored, with restrictive permissions. Do not
  copy LOAM implementation source, install dependencies or adopt a production
  storage/UI entrance by implication.

## Current implementation

- `lib/` and `application/` contain the neutral exact-quantity/admission/query
  engine. Accounting calculations remain pure; terminal and filesystem effects
  stay outside it. Normal builds are Lean-free.
- The ordinary `bakhlo 1/2/3 ordinary-quantity` Book and `record`/`exchange`
  CLI are separate from Daily_book. v3 Book records explicit two-Measure
  exchanges; it does not represent all Daily plans or LOAM household families.
- `sexp/daily_book.mli` owns Daily's current contract: corrected entries,
  explicit plans and independent quantity support; reads monolithic v1..v3
  and Records v1, writes monolithic v3. Experimental budget allocation/routing
  APIs and trial v4 support were removed. Old budget-only trials may be recreated.
- Ordinary same-Measure recording, multi-posting drafts, date/amount/memo edits,
  browsing, admitted-Locus candidates, transaction preview and explicit plan
  payment are connected to the trial UI. Editing preserves stable IDs, posting
  structure/keys and payment links; unsupported Exchange/Reversal-related edits
  refuse instead of dropping their relationships.
  Replacement and Scheduled completion publication are supported by the monolithic
  path only. Records refuses both before append because its protocol cannot persist
  the replacement/completion link atomically; it must not append a partial Actual.
- `put_plan`/`cancel_plan` are connected to single-occurrence create/edit/cancel UI.
  Paid/cancelled plans cannot be edited or paid again; cancellation retains the
  occurrence and does not change physical quantities. Records refuses these writes.
  The browser exposes current-open occurrences, not full Series/Months/completed views.
- `daily_pace` computes an explicit one-Measure balance pool less open-plan net
  drains before a supplied exclusive end, divided by remaining calendar days.
  It is not spending permission, budget residual, historical replay, proof of
  complete plans or fresh balances. Current Pace and read-only What-if are connected;
  pool/period absence, malformed inputs, mixed Measures and ambiguous presets refuse.
  The Pool editor changes only daily-pace.tsv; boundary-presets.tsv is read-only
  here. Historical Trend remains unavailable; no month/account defaults are invented.
- Daily Exchange, Observe, Manage Loci/explicit roles, Attention lifecycle and a
  limited cumulative-commitment settlement trial are connected. OriginalAmount,
  Merchant, full Settlement correspondence and broader reports remain incomplete.
  Attention/settlement read failures render Unavailable and block their writes;
  save failures retain the submitted form and old in-memory state.

## UI and direct owners

AI daily development review follows the standing latest-data workflow above:
`./tools/compare refresh`, then current Bakhlo and existing LOAM on the selected
same-generation private copies (`./ui` / `./ui loam`). The AI performs this review.
After the walk, stop only the AI's comparison processes and run
`./tools/compare clean-copies`; it removes the selected raw source/LOAM view,
retaining Bakhlo book/imported baseline/config and all earlier trials. A later
LOAM comparison requires a fresh copy, with no fallback to originals.
Optional manual review uses `./ui --daily` (`./bakhlo/ui --daily` from moko),
without closing LOAM. It requires
interactive stdin/stdout before acquisition and opens Bakhlo only after a successful
refresh; refusal never opens the previous selection. Every refresh creates a new
generation. Previous Bakhlo and LOAM trial edits remain in their old copies and
are not merged into the new one. `./ui` revisits the selected copy and
`./ui --refresh` acquires only.

The refresh copies household/config read-only using the existing private Daily
conversion trial, retaining exact inputs, a fresh supported Daily v3 book,
a private entry/plan delta, and previous captures under `scratch/loam-comparison`.
It does not date-filter/append blindly, merge trial edits, or update originals.
Unsupported Actual/profile data and changed acquisition refuse without advancing
CURRENT. This local helper needs the earlier ignored converter; it is not full
household migration, atomic multi-file snapshot, complete backup or canonical-store adoption.
`./ui` opens the selected Bakhlo trial copy; `./ui loam` opens a separate LOAM trial
copy of the same capture using the already-built executable, never building LOAM
or falling back to live originals. UI theme settings are isolated in `ui-config`.
`./ui --demo` retains the synthetic preview. `./tools/tui` remains the explicit
selected-file Bonsai entrance. The old standalone Notty frontend,
paired UI benchmark and old Bonsai layout lab are removed. Notty remains a
transitive rendering library used by native renderer checks; product dependencies have
not been removed or expanded. Irmin research used a separate switch only. This is the current
implementation, not a permanent Bonsai-only product decision; a new Notty renderer may follow.

Home is Calendar with Day / Month / Year and a period Detail region. Commands is
hierarchical. Actual, current-open Scheduled, Selected Day, Balances and current
Daily Pace use English labels. The Calendar counts Actual and open Scheduled;
role-aware income/expense Calendar totals remain unconnected even with supplied roles.
Attention and limited settlement workspaces, Exchange and Observe inputs are connected.
Full Series management, historical Trend and Japanese switching remain unimplemented. Theme offers Terminal (default, terminal-owned background/text
and ANSI colors including editor borders) and original Bakhlo Light / Dark
(fixed xterm 256 colors). Commands > Theme (also under Household setup) previews
with j/k or arrows, cancels to the exact parent menu with Esc/q, and saves UI-only
settings with Enter for the next
launch. Drafts, navigation and safety warnings are retained; failed settings saves
are session-only and reported. LOAM's dim styling remains a Bonsai API limitation.
Recording uses one transient Record model with Description,
Measure and signed postings. Esc/Cancel retain the draft; Preview offers Publish,
Edit and Cancel. Only Enter on selected Publish uses the existing publisher;
Ctrl-S opens a preview and never confirms publication.

- `daily_actions.ml`: draft/transaction conversion, validation, commit/reload.
- `daily_calendar.ml` / `ui_workspace.ml` / `ui_commands.ml`: Gregorian navigation,
  workspace selection and hierarchical Commands.
- `record_session.ml` / `daily_form.ml`: one Record draft/preview and UTF-8 caret helpers.
- `daily_overlays.ml` / `ui_text.ml`: terminal geometry, details and message catalog entrance.
- `daily_interaction.ml`: shared state, keys, focus and presentation.
- `daily_file.ml`: selected-file I/O/publication/recovery integration.
- `bonsai_daily.ml`: terminal rendering and event adapter.

Keep unknown versus zero, currency separation, complete quantities, draft
retention and visible conflict/uncertainty errors. Modal input/paste must not
reach the background or silently publish. Tiny preview panes must refuse
confirmation rather than hide required evidence. See [tui/README](../tui/README.md)
for current keys and recovery commands.

## Storage and unresolved safety

`Bakhlo_sexp.Year_read` adds an opt-in annual validation boundary only; see
[YEAR_READ_BOUNDARY.ja.md](YEAR_READ_BOUNDARY.ja.md). Its authoritative verified
selection source is connected only for the locked, read-only rollover preview described above.
It checks original bytes and Core admission, derives opaque prior-year carry, and rejects stale/mixed inputs.
It does not synthesize current balances, persist annual data or alter default
single-S-expression operation. Do not advertise it as a usable annual store.

Monolithic publication performs full admission/printer checks, cooperative writer
locking, expected-base comparisons, synced attempt/pending/pre-edit backup writes,
selected rename and readback. Remaining/malformed/nonregular attempt/pending
artifacts or unavailable artifact inspection freeze writes across restart/reset/
reload; no automatic retry, adoption or backup pruning. Explicit acknowledgement
is limited to a candidate exactly matching the selected file now and does not
prove the outcome of an earlier publication. Restore-copy uses a fresh path;
copy success does not select a new operational ledger.

Records uses the existing append engine, request tokens and LSN checks instead
of monolithic attempt/pending files. Opening Records can recover a torn final
write; corruption refuses. Scheduled completion and replacement of an existing
Actual are refused before append; their bytes and cold state remain unchanged.
Do not describe every open/recovery operation as
read-only. Persistent client acknowledgement after restart/Ack loss (P7) remains
an independent unresolved safety boundary; monolithic recovery is not its proof.

Stable parent namespaces and cooperative writers are assumptions. Process-kill
tests do not certify power loss, media failure, hostile/noncooperative writers
or a fresh-host recovery environment. Backup retention, separate-media copies,
and reconciliation/adoption of differing or unreadable candidates remain undecided.
Full-before backups accumulate; whole-file admission/publication retains linear
costs. UI completion is not durable-store qualification or cutover approval.

## Verify and continue

Use the existing isolated tools; do not change global environments or use Python:

```sh
./tools/check
./tools/tui --self-check
./tools/compare self-check
./tools/tui --copy-from examples/daily-book.sexp --book scratch/FRESH_TRIAL/book.sexp
./tools/tui --book scratch/FRESH_TRIAL/book.sexp
```

Create a fresh ignored trial directory first; never overwrite a previous trial.
The launcher installs nothing, refuses unavailable isolated environments, and
`--self-check` runs shared contract checks and the native Bonsai renderer checks.

For the next storage experiment consult the year-partition plan before implementation.
Existing `./tools/storage-study` / `./tools/storage-breakdown` and recovery/refusal tests
remain baseline entrances, not a request to repeat scale measurements now.
Keep results in their owning reports; install nothing or start a backend by implication.

When UI work resumes, review its exact diff and compare the resulting screens
and supported-operation key flows with current LOAM. Check relevant synthetic
cases: normal/compact geometry, Japanese/long text/huge amounts, empty/unknown
states, focus/viewport, resize, cancel, confirm, reopen and terminal restoration.
Use `tui/record_session_checks.ml`, `daily_interaction_checks.ml`,
`recovery_checks.ml` and the nearest `test/` owner for concrete boundaries.

[VERIFICATION.md](VERIFICATION.md) owns historical qualification and limits;
[CAPABILITY_LEDGER.ja.md](CAPABILITY_LEDGER.ja.md) is a wider capability/evidence
index, whose current claims must be checked against source. Git retains obsolete
UI roadmaps, budget experiments and milestone history. [AGENTS.md](../AGENTS.md)
owns standing development/data rules; the [cutover checklist](CUTOVER_CHECKLIST.ja.md)
does not authorize cutover merely because a trial UI works.
