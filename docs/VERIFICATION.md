# Verification

Types, finite tests, models, proofs and operational evidence establish different things.
None automatically certifies handwritten OCaml, external premise truth or household use.
Ordinary qualification is macOS x86_64 and isolated Ubuntu 24.04 x86_64 with the locked
toolchain; bounded Solo5/SPT engine execution is below, not production support. Other
targets, storage, full normalized Actual admission, recovery and migration remain open.

## First CI automation on direct main pushes (2026-10-18)

- Added `push: main` trigger to the previously PR-only Core workflow, including changes under `tui/` and Core contracts. Existing locked OCaml 5.3 tests remain unchanged.
- Added `.github/workflows/tui.yml` with a **separate** OxCaml 5.2.0+ox switch, frozen Ox/default opam registry checkpoints from the prior synthetic trial, Bonsai_term pinned to `2457232d3aa144fb887a053748a920544db60f72`, generated exact tracked-source native build, and `./tools/tui --self-check`. Build script CI opt-in does not change the default private macOS Bonsai switch.
- Tracked initial workflow run IDs: Core `39091982586` and Bonsai TUI `39092011892`. They were **in progress** at initial inspection, not successful qualifications. Consult their final conclusions and the specific test logs before updating this verdict. TUI CI depends on a potentially costly Ox opam bootstrap; if dependency solving/build fails, repair that failure rather than ignoring it.
- This is a Linux build/native synthetic-check entrance, **not** a PTY 4-size matrix, real IME, paired LOAM runtime test, power-loss/P7 or cutover. No private household data is used.

## Balances medium layout and Print refusal: source only (2026-10-18)

- Baseline `main` was `8bc490f3a43c8c8e8869062c1bcd3779e361d558` (already included the locally qualified Daily Pace history and UI-24-B2 grouped observation work).
- Direct-to-main source commits `79b0f19` and `9ae06b4` modify only `tui/daily_interaction.ml` and `tui/daily_interaction_checks.ml`. New layout: in Balances, terminals 72..119 cells wide and at least 18 rows tall render the same current list above the Selected Balance details, with native `Panel.frame` and the existing selected row, detail focus and scroll. Width >=120 retains the two-column layout, and very small terminals retain the previous focused-pane fallback.
- New Current Print guard refuses a malformed, unreadable or otherwise unavailable `balance-view.tsv` instead of offering its error message as a printable balance projection. Accounting Print remains on the existing role-based route; normal Current print has the existing unbounded exact amounts and 200-row preview limit.
- Added synthetic check cases: at 80x24 the list and Selected Balance appear on distinct rows with the full `+74,500 jpy` amount; a malformed view refuses Print without changing config bytes.
- **Validation status: source and test assertions were added remotely; no OCaml build, self-check, paired LOAM binary, terminal resize/IME or filesystem-failure test was executed for these new commits in this environment.** Do not promote this to `T/P successful` or human acceptance until a later worker runs `./tools/check`, `./tools/tui --self-check` and the affected synthetic screen matrix. Prior UI-24-B2 evidence remains valid only for the earlier bounded code.
- LOAM remains production authority; no household files accessed. P7, current role safety, full Accounting/Print parity and cutover remain open.

## Annual S-expression ledger completion (2026-10-17)

`76cb22a` plus `Annual_book`, `Daily_file` chain verification/rollover, `Annual_backup` and TUI annual lifecycle integration. Local macOS x86_64: Core OCaml 5.3.0, isolated Bonsai 5.2.0+ox, synthetic files only.

- `rtk test ./tools/check` passed, including `annual_file_tests.ml`, `annual_lifecycle_tests.ml` and `annual_backup_tests.ml`: rollover + 2027 payment of an overdue 2026 plan with unchanged 2026 bytes, repeat payment/cancellation refusal, cold 2027 balance and Daily Pace agreement with an independent monolithic Core oracle across a Dec/Jan pension cycle, Exact 0 vs Zero-origin vs Known-present vs Unknown and reflected root-cut preservation, tampered/missing/corrupt/unfinished predecessor refusal, frozen predecessor refusal (including unscoped numeric path loads), 2026→2027→2028 closed-plan monotonicity, `Selected_replaced` checkpoint uncertainty + `inspect_recovery` / `confirm_current`, deterministic fork/pipe lock collision + SIGKILL release, and exact-byte backup/restore validation before directory creation.
- `rtk err ./tools/build-bonsai-tui` and native `bonsai_daily.exe --self-check` passed, including `annual_lifecycle_checks` (Keep default, narrow-terminal refusal + Keep reset, rollover, cold Balances/Daily Pace, overdue payment and stale-provenance route blocking).
- Owned 120×36 tmux smoke on synthetic `2025.sexp`→`2026.sexp` confirmed TUI rollover, unchanged `2025.sexp` SHA-256, overdue plan completion in 2026, Current Balances (`wallet +1700 jpy`, `food +300 jpy`), Daily Pace (`29 jpy/day` across `2025-12-15..2026-10-15`), `--annual-check`, `--annual-list`, and byte-identical `--annual-backup` / `--annual-restore`.
- Unqualified: true power loss, post-save Ack loss (P7), noncooperative external writers, paired LOAM runtime/IME acceptance and operational cutover.

## Annual S-expression and read-only rollover preview

2026-10-17, base `2f65925` plus the annual-preview change. Local macOS x86_64:
Core OCaml 5.3.0, existing isolated Bonsai compiler 5.2.0+ox. Synthetic files only,
under a fresh `/tmp/bakhlo-annual-34.*` directory; isolated UI configuration.
No LOAM/private/previous trial data, new dependency or GitHub Actions run.

- Baseline `./tools/check`, `./tools/build-bonsai-tui` and native
  `bonsai_daily.exe --self-check` passed before editing.
- Final change: `./tools/check` (full Core build/inline/cram checks),
  `./tools/build-bonsai-tui`, native `--self-check` and the six-coordinate native
  preview smoke passed. Added regressions cover independent reflected cuts,
  all closing states, stable open-plan identity, changed-source re-derivation,
  cross-year ID collisions, unresolved artifacts and deterministic fork/pipe
  writer-lock contention. Initial new-test type/exception expectations were
  corrected before this successful full run; no runtime refusal was bypassed.
- Real Bonsai in an owned 120×36 tmux session: explicit first-run creation of
  separate `2026.sexp` and `2027.sexp`; a separately seeded synthetic 2026 book
  recorded `2026-12-31`, wallet −37 / food +37, then corrected to `2026-12-30`.
  Publication/readback and cold Actual reopen retained the same entry ID and quanta.
- Changing that Actual to `2027-01-01` reached Preview but publication refused
  with `annual-entry-outside-year`, retained the input and preserved SHA-256
  `d6004ec84a40e9211cf95e8c0f2a6f43e035374f918692fc5f9ece43257893c7`.
  Creating, browsing, listing and cold-opening 2027 did not change 2026.
  The cold 2027 Calendar selected `2027-01-01`; Balances refused unqualified carry.
- Native `--annual-rollover-preview 2027 --directory DIR --coordinate LOCUS jpy`
  exercised six coordinates: an observation reflecting the spending root returned
  Exact 10 (not 7), Exact 0 remained distinct from Zero-origin, a nonzero origin
  returned Exact 3, presence returned Known-present, and missing support Unknown.
  Only overdue and future open plans survived, with original IDs/dates/quantities;
  paid and cancelled plans were absent. Both input SHA-256 values were unchanged.
- Missing target year, no predecessor (`0001`) and an empty coordinate exited 1
  with no stdout/partial preview. The command reports prior closing evidence only.

This is not persisted rollover, target-year current balances, plan import/payment,
multi-file mutation/recovery, noncooperative-writer protection, power-loss/P7,
paired LOAM/IME acceptance or operational adoption. The preview may create existing
protocol `.lock` files; ledger bytes, backups and plans are not rewritten.

## Retained draft discard confirmation

Bakhlo `6b676c5` plus the local Record/Actual controller changes. Browsing Ctrl-N
previously cleared the held draft immediately; the new native regression reproduced
this at `discard-shortcut-must-not-delete-without-confirmation`.

- Reused the existing Ui_form buttons and existing `discard` guard. Keep draft is
  the initial cancel button; Enter/Escape retain input and parent context. Explicit
  Discard requests local draft removal only. No writer, codec or UI framework change.
- Confirmation requires at least 48 columns and 12 body rows. A tiny refusal resets
  Keep; it does not replace an existing blocked/uncertain warning. Existing pending
  publication/recovery refusals remain authoritative even after explicit confirmation.
- Permanent checks cover default Keep/Escape, explicit non-saving discard, empty-draft
  no-op, shrink/refuse/restore, uncertain-evidence retention and warning preservation.
  The modal is included in existing renderer cases across dimensions/themes.
- Core `./tools/check`, native build and native `--self-check` passed.
- Native tmux at 80×24 on a dedicated socket, `TERM=xterm-256color`, used a fresh
  synthetic `examples/daily-book.sexp` copy under ignored `scratch/draft-discard.IOomlv/`.
  `Keep this draft` survived default Keep and a 32×9 refusal followed by restoration
  to 80×24/Enter. Explicit Right/Enter discarded it, and reopening Record was blank.
  The selected book's SHA-256 remained unchanged throughout. Escape was sent separately
  from the following shortcut to avoid terminal escape-sequence ambiguity.
  UI binary SHA-256: `47642e4e88fe68e8d4a4269d77360616a4722c407b469f49d42b27803553e200`.

This intentional draft-loss protection is not a new paired LOAM runtime comparison,
manual IME acceptance, restart-persistent draft support or power-loss/P7 qualification.
No production input, dependency or operational authority changed.

## Actual correction publication return

Bakhlo `6b676c5` plus this controller/check change and pre-existing documentation edits.
No LOAM executable, source build, private household input or new dependency was used.

- A new native regression first failed at
  `actual-correction-return-follows-id-not-old-row`: Record correction from Actual
  changed the date enough to reorder the list, but the Actual workspace kept its
  old row while the parallel browser followed the ID. The two selections disagreed.
- Publication now reuses `Act.returned_from_detail` and the existing browser sync;
  the Date-only handler's duplicate restoration is removed. Success messages retain
  the helper's explicit notice when a selected item leaves the filter/scope.
- Permanent checks exercise real Record correction Preview/non-write, publication,
  same ID/detail focus after row 1 → 17, unchanged postings, and cold-load date/memo.
  Separate state-level checks cover filtered/sorted/Locus-selected scrolled return
  and a selected item leaving search (empty selection, reset scroll, visible notice).
- `./tools/check`, `./tools/build-bonsai-tui` and native `--self-check` passed.
- Native tmux on a dedicated socket, `TERM=xterm-256color`, used a fresh synthetic
  two-entry book under ignored `scratch/actual-correction-return.i7wxmj/`.
  At 80×24: Actual → Details → `c`, append `!` to `Return target`, change
  2026-10-15 → 2026-09-01, Ctrl-S. Preview left the book hash unchanged;
  End/Enter published, selected `target` in its new second row and retained Details.
  Shrinking to 48×14 retained the same -37/+37 jpy detail. After Ctrl-Q and a fresh
  process, Actual → second row → Details showed `target`, the corrected date and
  `Return target!`. `--check` admitted the saved book.
  UI binary SHA-256: `2c57aa5ac060e0eae2981772aa4cd7f82a8465696dc5602186bdc35a81fef6c0`.

This is bounded synthetic return/cold-reopen evidence, not paired LOAM parity,
IME/user acceptance, new failure-path qualification, power-loss/P7 or cutover approval.

## Selected Day Record date and return

Bakhlo `6b676c5` plus the local correction-return and Selected Day Record changes.
The new native regression first failed at
`selected-day-record-inherits-route-date-not-background-calendar`.
`open_record` now uses the Selected Day route's date for a fresh draft, as
`open_plan_record` and `open_exchange` already do; held drafts are not retargeted.
Read-only LOAM `SelectedDaySession.lean` `.recordNew` uses `state.focusDate` too;
this source observation is not a new paired executable comparison.

- Permanent native checks use a background calendar of 2024-02-29 and an Actual
  drilled into 2026-10-17. They cover initial date, Escape/no-write, exact draft
  resume, Preview/no-write, same parent selection, cold-load date/memo/-37/+37 jpy,
  and drill-back to the original Actual ID/detail focus.
- At 80×24 on a dedicated tmux socket (`TERM=xterm-256color`), a fresh synthetic
  copy under ignored `scratch/selected-day-record.H4lKEE/` opened Actual → Details
  → Selected Day 2026-10-01 → Record, while the background calendar was 2026-10-16.
  Record and Preview both showed 2026-10-01. `Selected-day snack`, wallet -19 and
  food +19 survived Escape/resume; both Escape and Preview left the book hash
  unchanged. Publish returned to the same Selected Day/`earlier` selection;
  `q` restored Actual/Details on `earlier`. A fresh process showed the new entry
  with 2026-10-01 and -19/+19 jpy; `--check` admitted the saved book.
- Core `./tools/check`, native build and native `--self-check` passed.
  UI binary SHA-256: `529ab2f18f5829cdc6c66497545869c5f686390b423c5b19dd393c6ca99e4098`.

No original data, LOAM build/runtime or dependency changes. Paired LOAM runtime,
manual IME acceptance, new failure/power-loss/P7 evidence and full lifecycle acceptance
remain open; no operational cutover is implied.

## First-run comparison (2026-10-16)

Bounded paired startup check for the same absent-household condition at 80×24.
No financial records or household facts were needed; both destinations were unique,
new paths under ignored Bakhlo `scratch/first-run-comparison.A4A2nu/`.

- Sources: Bakhlo `6b676c5` (inventory documentation changes present; UI source unchanged);
  LOAM `bb208173` (worktree clean).
- Existing LOAM executable, `../loam/.lake/build/bin/loam`:
  SHA-256 `04f018707d45d483907f6d9dd19efe9fb702b6d22fb55e5192df65accd7c705b`.
- Bakhlo executable, `_build/daily-bonsai/_build/default/ui/bonsai_daily.exe`,
  built by the existing `./tools/tui` entrance:
  SHA-256 `fa3bd48b4493d22fd62aa91f5b2afb0cb3e2b3e3b250e563b32c88800eb63912`.
- LOAM was invoked directly as `loam tui <absent scratch directory>`: it displayed
  `LOAM / Start a household`, identified the selected missing path, and offered a
  separate create/review flow.
- Bakhlo was invoked as `bonsai_daily.exe --book <absent scratch file>`: it exited
  with `TUI/recovery refused: input/file/terminal unavailable; no empty fallback.`
- Neither target path was created. No live household path was supplied.

This establishes the visible startup difference only: LOAM offers explicit first-run
creation, while Bakhlo fails closed. The LOAM process already open in another terminal
was left untouched; no `./ui --refresh` or private household capture was attempted.
The LOAM screen was observed, but the Expect PTY did not confirm a clean Escape return;
cancel handling is unqualified. Binary-to-source correspondence, other startup failure
cases, shared financial fixtures, and broader screen parity remain unqualified.

## Record lifecycle synthetic smoke (2026-10-16)

Built with `./tools/build-bonsai-tui`; native `--self-check` passed. A fresh
`scratch/record-follow-orhjO7/book.sexp` was copied from the synthetic
`examples/daily-book.sexp`; no household original or LOAM executable was used.
At 80×24 on a private tmux socket (`TERM=xterm-256color`), Home `r` opened
Record with Description focused and today's date. Entered `Smoke purchase`,
wallet `-37` and food `+37` jpy. `Ctrl-S` showed the exact two-posting Preview
without publishing; Enter on Publish wrote an Actual. Opening Actual with `a`
showed the same description, date, signed postings and ID
`entry-d8dd9fcde24e0ba926df2e0d`.

From Actual, `n` opened a second Record; entering `Discard me` and Esc retained
the draft without changing the book SHA-256
`7204f52e0fc93d1a253e2e2a9116686ff3060cbfc5d8f224f48fcc7b090115ce`.
`r` resumed that draft. After leaving the editor and restarting the TUI,
Actual still contained the first entry and the book hash was unchanged.
This qualifies one Bakhlo native happy path and one cancellation; it does not
establish matching LOAM behavior, preview Edit/Cancel choice, narrow-screen
publication gates, save failures, or manual IME acceptance. The existing
Record lifecycle acceptance item remains open.

## Paired Record happy path and cancellation (2026-10-16)

Existing LOAM binary `../loam/.lake/build/bin/loam` SHA-256
`04f018707d45d483907f6d9dd19efe9fb702b6d22fb55e5192df65accd7c705b`;
Bakhlo `_build/daily-bonsai/_build/default/ui/bonsai_daily.exe` SHA-256
`fa3bd48b4493d22fd62aa91f5b2afb0cb3e2b3e3b250e563b32c88800eb63912`.
LOAM source/binary correspondence was not requalified. Both ran at 80×24,
`TERM=xterm-256color`, on a private tmux socket. All data were synthetic under
ignored `scratch/record-paired-FSlkTk/`. LOAM's existing first-run UI created
`initialized/` from an unused path; its Manage Loci UI explicitly admitted
`wallet` and `food`. Bakhlo used a separate empty Daily v3 book with JPY
scale 0, those two approved loci and no balances/plans. The two storage formats
and generated IDs differ by design; no original household was opened.

Home `r`, Description `paired snack`, wallet `-37` and food `+37` jpy reached
Preview in both. LOAM required Enter after the last Amount; its Record ignored
`Ctrl-S`, which Bakhlo accepts as an additional Preview shortcut. Before
publication, Esc left both authority hashes unchanged (Bakhlo
`dff138a1464dc620257b72a0d6b0d3d6bfaddaa947c850b7af8ad5d090f8a597`,
LOAM `1a1a6d1319343bc8ef755c94493c07f4c8c8040d480c709379fdeadd05d39333`).
Reopening Record started a blank LOAM editor but resumed Bakhlo's held draft.
Re-entering the same LOAM fields and selecting Publish with Enter in each UI
saved one Actual. `a` showed the same date, description and signed postings;
after both processes were stopped and restarted, Actual still showed one
`paired snack` entry with those postings, and the published book hashes were
unchanged (`5e7a68517fe6fb2cf1b3a8094590249d9cf7222ff7bf11c02886e5731da2457c`
for Bakhlo, `5e638f7b62e7c25e38ce7d3755a1246fb07ae8ee5a1c7f861593e2ee62e5a0c2`
for LOAM).

Observed differences: LOAM's Record and Preview fill the 80×24 surface;
Bakhlo floats a narrower pane over Home. LOAM Preview lists date, description,
then compact signed postings; Bakhlo lists detailed postings first and includes
the generated ID. LOAM Actual gives a full-width dated/amounted row and a
bottom Details pane; Bakhlo uses three panes with a separate Loci list and
the amount in Details. Draft retention on Esc is intentional Bakhlo data-loss
protection, not a reason to discard a draft merely for screen parity. No layout
or key change was made without a bounded review of the other Record modes and
Actual consumers. This is one paired new-Record case, not acceptance of
Correction, Scheduled completion, Original Amount, narrow/resize, failure,
locale/IME, or full visual parity.

## Paired Record Edit/Cancel and narrow Preview gates (2026-10-16)

Same existing executables/hashes as the paired Record section above. Fresh
synthetic copies of its published authorities under ignored
`scratch/record-gate-QEq17T/`, private tmux socket, `TERM=xterm-256color`.
Initial SHA-256: LOAM HouseholdImage
`5e638f7b62e7c25e38ce7d3755a1246fb07ae8ee5a1c7f861593e2ee62e5a0c2`;
Bakhlo book `5e7a68517fe6fb2cf1b3a8094590249d9cf7222ff7bf11c02886e5731da2457c`.
Both accepted `gate check` with wallet `-19` / food `+19` jpy at 80×24.
Preview Tab→Enter returned to Edit with the same fields; Enter at the final
Amount reopened Preview. Tab→Tab→Enter selected Cancel and left both hashes
unchanged. Reopening started blank in LOAM and resumed the Bakhlo draft.

After recreating the same LOAM draft and reopening both Previews at 80×24,
resizing to 32×9 hid *all* of LOAM's seven confirmation lines. Enter on its
default Publish nonetheless saved `record-2` (HouseholdImage hash became
`8aace20f9562ccfdb3c3e1dbde1dda5adabdd398b6b04d4fac3683301906c3f2`).
Bakhlo instead refused with `Not enough room to review publication; enlarge
the terminal.` and its book hash remained unchanged. At 48×14, Bakhlo End
showed the last preview lines, but Enter still refused because the complete
preview did not fit; the hash remained unchanged. After restoring 80×24,
End displayed all 11/11 lines and Enter published that retained Bakhlo draft
(hash `ad25774dcfcfde6e47d1cfa4adede1e87ff388019e61cb3f5d0f063b9958af6f`).
On LOAM at 48×14, its separate `gate forty eight` Preview showed 4/7 lines,
End showed 7/7, and Enter published `record-3`. That is a different, partial
review policy, not evidence that the content is visible all at once.

**Safety decision:** Do not copy LOAM's observed 32×9 behavior into Bakhlo.
This comparison used synthetic authorities only; it does not modify LOAM
source or originals. Bakhlo's conservative tiny/full-preview refusal is
intentional. No product code changed. Paired save-failure comparison, long
multi-page confirmation, resize while typing, other Record-shaped modes,
source/binary correspondence and manual IME acceptance remain open.

## Record native pre-write filesystem failure (2026-10-16)

Only Bakhlo was run here, at 80×24 on a private tmux socket. A fresh copy of
the synthetic published book under ignored `scratch/record-failure-yBJb8N/`
started at SHA-256
`5e7a68517fe6fb2cf1b3a8094590249d9cf7222ff7bf11c02886e5731da2457c`.
A regular writer-lock file was prepared before launch. The `failed save`
draft (wallet `-11`, food `+11` jpy) reached a full 11/11-line Preview. The
scratch directory was changed from mode 0700 to 0500 immediately before
Publish, preventing creation of the first candidate file; it was restored
to 0700 immediately afterward. The TUI reported an uncertain publication
outcome, retained the draft and stopped writes. The selected book hash was
unchanged. Repeating Enter after permission restoration displayed `Writes
are stopped; the draft is retained.` and still did not write. Esc returned
to Home; Ctrl-R there reported `previous publication is still unconfirmed.
No retry`, with the same book hash. After stopping and cold-reopening, Actual
contained only the earlier `paired snack` entry, not `failed save`.

The writer marks its attempt before candidate-file creation, so even this
pre-write I/O error is reported as uncertain; this is a conservative stop,
not a claim of durable Saved or knowledge of every failure outcome. No
automatic retry, household original, LOAM runtime or product code change.
Failure after replacing the selected book, power loss/P7, and paired LOAM
save-failure behavior remain unqualified.

## Attention administration

Bakhlo `896fb7f` plus local UI work and this slice.
Read-only source consultation: LOAM `AttentionAdministration.lean` (Mode browse/newContext/newDue/newDate/confirmClose,
dueWidth and contextWidth layout, overdue indicator `!`, kindLabel resolved/dropped) and
`Home.lean` (attentionSummary, overdueCount, attentionBadge `(! N overdue)` / `(today)` / `(N)`).
No LOAM build, source copying, runtime comparison or production input.

`attention_data.ml/.mli` and `daily_interaction.ml` implement Attention administration:
- Route: `W.Attention`, accessible via Home `i` or Commands -> `Attention`.
- Dynamic Home footer badge:
  - Computes `summarize ~today attention`: `open_count`, `overdue_count`, `due_today_count`.
  - Renders `[i] attention (! N overdue)` if overdue, `(today)` if due today, or `(N)`.
- Aligned table presentation:
  - Left pane displays `Due` and `Matter / Context` columns separated by header rule.
  - Overdue items flagged with `! YYYY-MM-DD`.
- Right pane detail:
  - Matter description, Urgency analysis, Item ID, Lifecycle, and shortcuts.
- Lifecycle operations:
  - `n` opens Add form supporting 3 due models (No due date, Due undetermined, Due on date).
  - `r` opens Resolve confirmation modal, records `Resolved` closure.
  - `x` opens Drop confirmation modal, records `Dropped` closure.
  - Atomic disk persistence with writer lock and draft preservation.
- Navigation: `j`/`k` select row, `Tab`/`i` toggle detail focus, `q`/`Esc` return to Home.

Executed native build/`--self-check` and `./tools/check`; passed.
Checks cover Home indicator badge, modal add with overdue date, overdue flag in list and detail,
`Tab` focus toggle, `x` drop, `r` resolve, and clean Home return.

Native tmux (`TERM=xterm-256color`, 120×36), synthetic fixture `scratch/bulk-smoke-dyzB0U/book.sexp`:
- Initial Home screen: `i` opened Attention.
- `n` added "Renew car insurance" due 2026-10-10 (overdue relative to 2026-10-16).
- Table displayed `! 2026-10-10  Renew car insurance` under `Attention (1 open • ! 1 overdue)`.
- Detail pane displayed `Urgency / Due: ! OVERDUE (due 2026-10-10, today 2026-10-16)`.
- `Escape` returned to Home; footer displayed `[i] attention (!1)`.
- Re-entered `i`, pressed `r` -> `Enter` to confirm resolve.
- Open items became 0; `q` returned to Home where footer badge was cleared cleanly.

This qualifies the bounded Attention administration slice (UI-26).

## Stock–Flow report

Earlier recorded smoke output for Stock–Flow is withdrawn as invalid financial
correctness evidence. It described cross-currency selection and a “Balanced” Net Savings
reconciliation, neither of which is a supported claim. Do not use that output to certify
the report. No current Stock–Flow verification or financial correctness certification is
claimed here.

The bounded view uses the explicit `balance-view.tsv` coordinate selection and requires
one measure throughout: empty, duplicate, or mixed-measure selections are refused, not
filtered, and no currency/measure switch is offered. It reconstructs historical balances
from zero-origin event history, not archival snapshots. Exact current support and
independent historical evidence are both required for each selected coordinate; absent
evidence or unknown/unsupported current quantity prevents a report. This view does not
reconcile Stock against Income & Expense, establish a balanced state, or complete LOAM
parity. Future verification must establish those bounded behaviors independently; none
is asserted as passed here.
## Transactions Flow report

Bakhlo `c742152` plus local UI work and this slice.
Read-only source consultation: LOAM `TransactionsFlowReview.lean` (incidence relation,
RowActivity positive/negative/net/gross, rowActivities, contributions) and
`TransactionsFlowPane.lean` (table layout, gross-salience sort order, contributions detail,
and summaryLines). No LOAM build, source copying, runtime comparison or production input.

`transactions_flow_report.ml/.mli` and `daily_interaction.ml` implement coordinate activity incidence review:
- Route: `W.Transactions_flow`, accessible via Commands -> `Analysis` -> `Transactions Flow`.
- Period presets: `1` (Month), `2` (Cycle), `3` (Previous Cycle), `4` (Year), `5` (All Time).
- Cycle resolution: evaluates active cycle windows and historical cycles from `boundary-presets.tsv`.
- Period shifting: `[` / `]` shifts months or cycles backward / forward.
- Incidence calculation:
  - Nonzero Effects grouped by `(locus, measure)`.
  - Inflows (+In), Outflows (-Out), Net, Gross volume, and active Event counts.
  - Rows sorted by `Gross` volume descending.
- Detail pane: shows all contributing transactions (`date, signed_amount measure, memo [id]`)
  for the selected coordinate; updates synchronously as `j`/`k` moves selection.
- Print preview: `p` opens plain-text summary modal.
- Navigation: `Tab` toggles between table and detail scroll; `Esc`/`q` returns to report pane or Home.

Executed native build/`--self-check` and `./tools/check`; passed.
Checks cover route navigation, period presets (Month, Cycle, Prev Cycle, Year, All-Time),
period shifting, coordinate row selection, contributing transactions update, Detail toggle,
Print preview modal, and Home return.

Native tmux (`TERM=xterm-256color`, 120×36), synthetic fixture `scratch/bulk-smoke-dyzB0U/book.sexp`:
- Initial Home screen: `Space j j Enter j j j Enter` opened `Transactions Flow • Month`.
- Window showed `2026-10-01 .. 2026-11-01 (exclusive)` with 3 active coordinates.
- Sorted by gross quantity: `wallet/eur` (Gross 80.00, Net +20.00, 3 events), `bank/eur` (Gross 50.00), `food/eur` (Gross 30.00).
- Right pane immediately displayed contributing transactions for `wallet/eur`.
- `j` moved cursor to `bank/eur`; right pane updated to show ATM withdrawal event.
- `p` opened `Transactions Flow / Print Preview` modal showing table summary.
- `Escape` closed modal; second `Escape` returned cleanly to Home.

This qualifies the bounded Transactions Flow report slice (UI-25/Flow). It does not establish
Stock-Flow, real IME/user acceptance, or operational cutover.

## Income & Expense report

Bakhlo `3f953b7f5495305666abd876c60eb700d5d93297` plus local UI work and this slice.
Read-only source consultation: LOAM `ReportsView.lean` (incomeExpenseResultLines,
incomeExpenseMeasureLines, incomeExpenseBreakdownLines, and unresolvedIncomeExpenseLine),
`Reports.lean` (incomeExpenseFromRoleFlow), and `ReportWindow.lean` (calendarMonth and
preset boundary cycle sources). No LOAM build, source copying, runtime comparison or production input.

`income_expense_report.ml/.mli` and `daily_interaction.ml` implement period-based P/L analysis:
- Route: `W.Income_expense`, accessible via Commands -> `Analysis` -> `Income & Expense`.
- Period presets: `1` (Month), `2` (Cycle), `3` (Previous Cycle), `4` (Year), `5` (All Time).
- Cycle resolution: evaluates active cycle windows (`start <= today < end_exclusive`) and
  adjacent historical cycles from `boundary-presets.tsv`.
- Period shifting: `[` / `]` shifts months or cycles backward / forward.
- Accounting logic:
  - Credit postings on `Income` accounts -> positive income (`-quanta`).
  - Debit postings on `Expense` accounts -> positive expense (`quanta`).
  - Separate accounting of Scheduled-linked bills vs ordinary spending.
  - Unclassified loci reported explicitly under `Unresolved Role Effects`.
  - Exact Net Savings calculation per currency: `Total Income - Total Expense`.
- Print preview: `p` opens plain-text summary modal.
- Navigation: `Tab`/`i` focuses detail pane; `Esc`/`q` returns to report pane or Home.

Executed native build/`--self-check` and `./tools/check`; passed.
Checks cover route navigation, period presets (Month, Cycle, Prev Cycle, Year, All-Time),
period shifting, Detail expansion, Print preview modal, and Home return.

Native tmux (`TERM=xterm-256color`, 120×36), synthetic fixture `scratch/bulk-smoke-dyzB0U/book.sexp`:
- Initial Home screen: `Space j j Enter j j Enter` opened `Income & Expense • Month`.
- Window showed `2026-10-01 .. 2026-11-01 (exclusive)`.
- `2` switched to `Income & Expense • Cycle` (`2026-10-15 .. 2026-12-15` from `boundary-presets.tsv`).
- `p` opened `Income & Expense / Print Preview` modal showing complete summary.
- `Escape` closed modal; second `Escape` returned to Home.

This qualifies the bounded Income & Expense report slice (UI-25). It does not establish
Transactions Flow, Stock-Flow, real IME/user acceptance, or operational cutover.

## Daily Pace Trend analysis

Bakhlo `3f953b7f5495305666abd876c60eb700d5d93297` plus local UI work and this slice.
Read-only source consultation: LOAM `DailyPaceTrend.lean` (presets 1–5, line/dots graph styles,
timeline samples, daily pace delta, remaining days, pool balance, and detail disclosure) and
`DailyPacePeriods.lean` (range resolution, historical reconstruction without separate snapshot).
No LOAM build, source copying, runtime comparison or production input.

`daily_pace_trend.ml/.mli` and `daily_interaction.ml` implement retrospective daily pace analysis:
- Presets: `1` (10d), `2` (30d), `3` (Month), `4` (Cycle), `5` (Previous Cycle).
- Reconstructed daily pace: computes pool balance at each date `D` by subtracting subsequent
  postings from current truth, and evaluates remaining days to cycle end with exact Euclidean division.
- Graph rendering: responsive ASCII plot with Y-axis tick values, axis rule, and timeline rows.
- Style toggle: `v` cycles graph style between `line` and `dots`.
- Navigation: `h`/`l` day step, `Home`/`End` range bounds.
- Detail pane: shows day-to-day change, remaining days, available through end, pool balance,
  scheduled deductions, and source attribution (`config/daily-pace.tsv` and `config/boundary-presets.tsv`).

Executed native build/`--self-check` and `./tools/check`; passed.
Checks cover preset switching, graph rendering, detail calculation, what-if retention,
pool configuration, and boundary preset handling.

Native tmux (`TERM=xterm-256color`, 120×36), synthetic fixture `scratch/bulk-smoke-dyzB0U/book.sexp`:
- Initial Home screen: `d` opened `Daily Pace / Trend • 10d [line]`.
- Plot rows displayed Y-axis ticks, `│`, and plot line with `^` at selection.
- `v` toggled graph style to `[dots]`.
- `3` switched preset to `Daily Pace / Trend • Month [dots]`, displaying `2026-10-01` through `2026-10-16 (Today)`.
- Right pane showed `Pace Detail & Evidence`, including `Through end:`, `Period progress:`, and source configuration.
- `Escape` returned to Home cleanly.

This qualifies the bounded Daily Pace Trend analysis slice. It does not establish
multi-currency spend trend, broader Reports (UI-25), real IME/user acceptance,
or operational cutover.

## Scheduled occurrence generation

Bakhlo `3f953b7f5495305666abd876c60eb700d5d93297` plus local UI work and this slice.
Read-only source consultation: LOAM `ScheduledGeneration.lean` (fill limits, cadence slots,
candidate planning, month shifting and nominal day clamping) and `ScheduledGenerationSession.lean`
(generation preview, candidate review, Cancel default, atomic creation). No LOAM build,
source copying, runtime comparison or production input.

`scheduled_generation_session.ml/.mli` and `Daily_actions.commit_plan_batch ~replace:false`
implement reviewed periodic Scheduled creation:
- Source plan supplies anchor date, measure, and exact changes.
- Parameters form inputs exclusive Through date and Cadence (Monthly, Every 2 months,
  Every 3 months, Every 6 months, Yearly).
- Candidate occurrences step forward by the cadence, clamping non-existent days (e.g. 31st
  in shorter months or leap-year February) to valid Gregorian month ends.
- Preview displays all proposed occurrences with dates, amounts, and Loci. Cancel is the
  protective default action (zero disk writes).
- Publication requires reviewing to the end and meeting dimension gates (width >= 46, height >= 14).
- All generated occurrences receive fresh unique IDs and are published together in a single
  atomic write with zero partial state.

Executed native build/`--self-check` and `./tools/check`; passed.
Checks cover parameter validation, through date boundaries, invalid Gregorian dates refusal,
cadence stepping, Cancel protective default, scroll and dimension gates, atomic publication
of 15 monthly occurrences, cold reload verifying all plans on disk, stale reload refusal,
and held record draft protection.

Native tmux (`TERM=xterm-256color`, 120×36), synthetic fixture `scratch/bulk-smoke-dyzB0U/book.sexp`:
- Initial open plan: `batch-a` (2026-10-15, EUR 300.00).
- `s j j g` opened `Scheduled / Generate Plans` prefilled with `2027-04-15` and `Monthly`.
- `Enter` generated 5 occurrences (`2026-11-15`, `2026-12-15`, `2027-01-15`, `2027-02-15`, `2027-03-15`).
- `Enter` on default `[Cancel]` closed session with zero disk writes (SHA-256 matched `before_gen.sexp`).
- Re-opened `g Enter Tab End Enter` published all 5 occurrences atomically.
- List updated to 8 plans; disk showed all 5 new plans with exact EUR amounts and fresh IDs.
- Executable SHA-256: `7d1f56a226303fea1dae916abeacffad6e3676128586dcd5f4f728f1f0c21fff`.

This qualifies the bounded Scheduled generation slice (UI-21). It does not establish
coverage cadence monitoring (UI-23), real IME/user acceptance, or operational cutover.

## Balances Current view

Bakhlo `3f953b7f5495305666abd876c60eb700d5d93297` plus local UI work and this slice.
Read-only source consultation: LOAM `Balances.lean` (initial Current mode, balance-view
order, exact / present-unknown / unsupported states, detail pane, preparePrint header
and 200-row cap, Page/Home/End selection) and `Cli.lean` (`b` launches Balances, `p` print).
No LOAM build, source copying, runtime comparison or production input.

`daily_interaction.ml` and `daily_overlays.ml` align Balances with LOAM's Current view:
- Initial mode on route open is `Balances / Current` (neutral Locus × Measure coordinates
  in `balance-view.tsv` order).
- Key navigation: `j/k` row move, `PageUp/Down` page jumps, `Home`/`End` range bounds in List pane.
- Pane switching: `Enter`/`i`/`Tab`/`h`/`l` focuses Detail pane; `Esc`/`q` in Detail returns to
  List pane without dropping to Home.
- Mode toggle: `v` cycles between `Balances / Current` and `Balances / Accounting` (RoleBalances).
- Print preview: `p` generates canonical LOAM plain-text preview with exact 4-line header
  and 200-line refusal gate.
- Detail text includes canonical LOAM statements:
  `Unsupported: No current quantity support is justified for this coordinate. Do not infer zero.`
  `Known present: Presence is known; the exact current amount is unknown, not zero.`
  `Locus × Measure; not an Account taxonomy.`

Executed native build/`--self-check` and `./tools/check`; passed.
Checks cover initial Current mode, balance-view ordering, PageDown/Home/End selection,
Detail expansion and Esc return to list, `v` toggle to Accounting and back, Print modal title
and header, and Observe prefill.

Native tmux (`TERM=xterm-256color`, 120×36), synthetic fixture `scratch/bulk-smoke-dyzB0U/book.sexp`:
- Initial Home screen: `b` opened `Balances / Current`.
- Header showed `Selected Locus × Measure; balance-view order only.`
- `j j Enter` selected wallet and opened Detail pane (`Selected Balance`).
- `Escape` returned to List pane (`Balances / Current`) without leaving Balances.
- `End` jumped selection to the last row (`銀行 [bank] ? unsupported`).
- `Home` jumped selection back to row 0.
- `p` opened Print Preview modal with LOAM's 4-line header.
- `Escape` closed Print Preview modal.
- `v` toggled to `Balances / Accounting`, footer showed `v current`.
- `v` toggled back to `Balances / Current`, footer showed `v accounting`.
- `Escape` returned to Home screen.

This qualifies the bounded Balances Current view slice (UI-24). It does not establish
full Reports parity (UI-25), role-setting persistence safety, real IME/user acceptance,
or operational cutover.

## Scheduled batch amount editing

Bakhlo `3f953b7f5495305666abd876c60eb700d5d93297` plus local UI work and this slice.
Read-only source consultation: LOAM `ScheduledBulkEdit.lean` (parameters, candidate
matching by measure + signed Locus sets, simple amount 2-posting contract, split refusal,
unchanged omission, Back default, list pane) and `ScheduledBulkEditSession.lean`
(workspace key `b`, batch draft publication, cancel and error notices). No LOAM build,
source copying, runtime comparison or production input.

`scheduled_bulk_session.ml/.mli` and `Daily_actions.commit_plan_batch` implement the
atomic multi-plan amount update:
- Candidates require exact current-open status, matching Measure, and identical positive
  and negative Locus sets. Split postings (>2 rows or non-opposite signs) are refused
  without guessing allocation.
- All candidates start unchecked (`[ ]`); Space toggles, `a` checks all, `d` clears,
  `e` returns to parameter editing.
- Unchanged amounts are excluded; all-unchanged or empty selection refuses.
- Preview displays before -> after signed amounts for each target. Back is the default
  choice and performs no write.
- Publication requires reaching the end of the preview and meeting dimension gates
  (width >= 46, height >= 14).
- All validated replacements are folded into a single candidate book and passed to the
  existing single-candidate atomic publisher.

Executed native build/`--self-check` and `./tools/check`; passed.
Checks cover parameter validation, start/end dates, candidate filtering by Loci and measure,
empty period safety, Home/End selection, split posting refusal, unchanged omission,
Back protective default, dimension and scroll gates, atomic publication of exact huge EUR
quanta, unselected/different-currency plan preservation, late invalid plan refusal with zero
writes, duplicate plan refusal, stale base refusal, and Records format refusal.

Native tmux (`TERM=xterm-256color`, 120×36), synthetic fixture
`scratch/bulk-smoke-dyzB0U/book.sexp`:
- Initial open plans: `batch-a` (EUR 123.45), `batch-b` (EUR 678.90), `batch-unrelated` (JPY 200).
- `s j j b` opened Scheduled / Bulk amount on `batch-a`.
- Typed `300.00` -> `Enter` advanced to Candidates view:
  `[ ] batch-a  2026-10-15  123.45  eur  wallet, food`,
  `[ ] batch-b  2026-11-15  678.90  eur  wallet, food`.
  `batch-unrelated` (JPY) was correctly omitted.
- `a` checked all candidates (`[x]`).
- `Enter` advanced to Preview showing before -> after for both EUR plans with `[Back]` default.
- `Enter` chose Back: returned to selection with zero disk writes (SHA-256 matched `before.sexp`).
- `Enter Tab End Enter` scrolled to the end of Preview and chose `[Publish all]`.
- Published atomically: both `batch-a` and `batch-b` updated to EUR 300.00 on disk, while
  `batch-unrelated` remained untouched at JPY 200.
- Cold restart re-loaded the exact updated amounts and preserved all plan metadata.
- Executable SHA-256: `867a152660e4c0f3c76aac92be21280d669426a9c136ddb7668110c3197f3fc2`.

This qualifies the bounded batch amount replacement slice. It does not establish
recurring generation (UI-21), coverage cadence (UI-23), real IME/user acceptance,
or operational cutover.

## Scheduled continuation awareness

Bakhlo `3f953b7f5495305666abd876c60eb700d5d93297` plus local UI work and this slice.
Read-only source consultation: LOAM `ScheduledContinuationSession.lean` (post-completion
trigger, later same-positive-Locus candidate matching, Keep/Add/Review and Done/Defer/Add
options, deferred Attention draft) and `ScheduledReview.lean` (similar open plan selector).
No LOAM build, source copying, runtime comparison or production input.

`scheduled_continuation_session.ml/.mli` triggers immediately after atomic Scheduled
completion publishes. If a later open plan has the identical positive Locus set, it is
presented as a candidate; otherwise the prompt offers Done, Defer to Attention, or Add next.
Keep/Done is the protective default and writes nothing. Review provides scrollable
candidate details. Defer records an Attention item with `due = Due_undetermined` without
creating a Scheduled occurrence. Add next opens `Scheduled_create` with the same Measure
and changes, leaving the due date empty for explicit user input. No recurrence, cadence,
or series identity is asserted.

Executed native build/`--self-check` and `./tools/check`; passed.
Checks cover prompt emergence after confirmed completion, candidate selection by positive
Loci, Keep non-creation, Review scroll and resize, Add next with empty due date and exact
EUR quantities, Escape cancellation of Add keeping completion, successful publication of
independent next plan, stale reload refusal, Done non-creation, Defer writing to Attention,
empty prompt tiny bounds, and refusal to open awareness on unconfirmed/uncertain completion.
Both candidate and no-candidate prompt views are in the native 8-size × 3-theme matrix.

Native tmux (`TERM=xterm-256color`, private socket), synthetic fixture
`examples/daily-book.sexp` copied to `scratch/continuation-smoke-5VqtoE/book.sexp`:
- Initial open plan: `planned-food` (2026-10-10, wallet −200, food +200 jpy).
- `s c Enter C-s End Enter` completed the plan atomically.
- Post-completion prompt immediately appeared:
  "Scheduled / Completion / Next Plan", "Completed: planned-food",
  "No similar later current-open plan found.", "Defer keeps an unfinished intent in Attention."
  Options: `> Done`, `  Defer to Attention`, `  Add next`.
- `Tab Tab Enter` chose `Add next`. The Scheduled creation editor opened with
  `wallet -200` and `food +200` pre-filled, cursor at `Due: |`, and notice:
  "Completion is already published. Enter the next due date, or Esc for completion only."
- `Escape` cancelled creating an additional plan.
- Verified disk state: `planned-food` was paid by the new entry, and no additional
  Scheduled occurrence was created.
- Hash before completion:
  `2ffc331709f9e729e9beac4609d6548513085d412d5a4fc020e3a1d2379b247b`.
  Hash after completion + cancelled Add next:
  `25a31407299f3618af4e950f3c040d7aff117356e625dd64cc50226a62fa0980`.
- Exercised executable SHA-256:
  `351ad45acdfec4a55c70f221ebab53472935880f8875b6ca55bd6acf2a023157`.

This qualifies the bounded post-completion continuation awareness slice. It does
not establish recurrence rule inference, periodic generation (UI-21), coverage
setup (UI-23), real IME/user acceptance, or operational cutover.

## Scheduled Months projection

Bakhlo `3f953b7f5495305666abd876c60eb700d5d93297` plus local UI work and this slice.
Read-only LOAM source consultation: `ScheduledWorkspace.lean` futureBoard month
window/following, month cards, receiving/split quantity and compact surface;
`ScheduledWorkspaceSession.lean` view/selection/action keys. No LOAM build, source
copying, runtime pairing or production input.

`scheduled_months.ml/.mli` owns the validated month window and pure six-month
projection using Daily_calendar, Ui_panel and native styled Columns. Ui_workspace
has independent List/Months browsers; unused Groups/cycle API is removed. The
controller connects `v`, month/selection movement, full details and existing
create/edit/complete/cancel operations. Initial Scheduled remains List; coverage
and Series are not synthesized. Months ignores retained List filters; returning
selects the same ID only when visible under those filters, otherwise keeps the
List selection. No new writer, configuration or storage format.

Executed native build/`--self-check` and `./tools/check`; passed.
Permanent checks cover year-crossing six-month ranges, current-month floor,
9999-12 and extreme integer shifts, current-open filtering, retained List query/ID,
selection-following horizon/card viewport, split and huge quantities, exact EUR
details, zero/one-cell surfaces and four controller resize sizes. Enter opens the
selected completion draft without saving; closing retains it and its parent.
Keep is non-saving. An explicit cancellation from Months is cold-loaded against
the selected ID and clamps selection to the next open plan without changing Actuals.
Months is included in the native 8-size × 3-theme render matrix.

Native tmux (`TERM=xterm-256color`, private socket),
`scratch/scheduled-months-smoke-yT7XOD/book.sexp`, copied from the synthetic Months
check fixture. This fixture contains current-open plans across 2026/2027, a EUR
plan, a split plan and retained cancelled plans:
- 120×36: `s /`, search `month-03`, Enter, `v l` displayed the six cards
  2026-11 through 2027-04. January selected `month-03` with 1234.56 eur; April
  showed `split (3)`; empty cards said “No explicit plan.”
- 80×24 kept all six cards and selected exact details. End selected `month-06`,
  due 2027-12-31, and followed to the 2027-07..12 window.
- 48×14 and 32×9 showed compact `v opens List` guidance. `v` and restoration to
  80×24 returned to the retained one-row List query and `month-03`, not the
  out-of-filter December selection.
- `v Enter` opened the selected EUR completion draft without publication.
  A batched Escape/Ctrl-N/x sequence did not close the editor and inserted `x`;
  Escape sent separately returned to Months with draft retained. Separate Ctrl-N
  explicitly discarded this synthetic draft. Escape timing/IME is not qualified.
- `x Enter` then showed cancellation Preview for `month-03`, the correct due date
  and signed ±1234.56 eur; default Keep returned without saving.
- Book SHA-256 was unchanged throughout:
  `a0a5d3ac8760e0ee0b94b87336a9af3fd694e564e3fbdca188e67c682124424c`.
  Exercised executable SHA-256:
  `73a89c8e349ba4c88542909509bd9a58c544d54400958d0c6148abb5deaf7899`.

This qualifies the bounded explicit-plan Months slice, not Series/coverage,
recurrence/continuation, full LOAM visual/key parity, real IME/user acceptance,
P7/power loss or operational cutover. Bakhlo still uses its existing `e` Edit and
scaled Measure presentation, rather than claiming exact LOAM interaction identity.

## Scheduled cancellation Preview

Bakhlo `3f953b7f5495305666abd876c60eb700d5d93297` plus the local UI work and this
cancellation slice. Read-only source consultation: LOAM `ScheduledCancellation.lean`
(target/due/expected review, protective Keep, live-bounds capacity) and
`Publisher/ScheduledTerminalPublisher.lean` (target-only cancellation intent).
No LOAM build, source copying, runtime comparison or production input.

`scheduled_cancellation_session.ml/.mli` replaces the old immediate-submit modal
with captured-target/base date input and an independent Preview. Keep defaults,
scroll/end/tiny gates, preserved cancellation date and failure-time choice reset
are local. Publication still uses `Daily_actions.commit_cancel_plan` and the same
whole-book lifecycle/refusal checks. Captured-base reload cannot rebase a stale
confirmation. A retained Record draft blocks cancellation entry rather than being
cleared by successful publication. No new writer or storage format.

Executed native build/`--self-check` and `./tools/check`; passed.
Checks cover read-only Preview/default Keep, invalid/normalized dates, edit/keep,
tiny confirmation, paste, retained Record draft, storage failure with choice reset,
Records refusal, stale/reload refusal, long identity/huge Effects review-to-end,
shrink after End and cold retention of the cancelled plan without Actual/balance
changes. Existing terminal-plan checks still refuse reopening/edit/payment/cancel.
Both date and Preview surfaces are in the native 8-size × 3-theme render matrix.

Native tmux (`TERM=xterm-256color`, private socket), synthetic fixture
`examples/daily-book.sexp` copied to `scratch/scheduled-cancel-smoke-KtgY4Y/book.sexp`:
- 80×24: `s x Enter` showed cancellation date 2026-10-15, target `planned-food`,
  due 2026-10-10, exact wallet −200 / food +200 jpy and selected Keep.
- Enter kept the plan and returned to the same open list. Book SHA-256 unchanged:
  `2ffc331709f9e729e9beac4609d6548513085d412d5a4fc020e3a1d2379b247b`.
- Reopen `x Enter Tab`, shrink to 32×9, Enter: enlarge refusal, same book hash.
- Restore 80×24, Enter with Cancel Scheduled selected: published/read back, open
  list became empty. Exit and start a new process: open list still empty; `x`
  refused with no selected open plan and no further file change.
- Retained S-expression has the same ID, due date, Measure and changes, with
  `(cancelled-on (some \"2026-10-15\"))`; it was not deleted.
  Saved SHA-256:
  `e82559cd2f1964c7dd7093dc2d6285946d6d013c6cc6e6dcef586175b670eec7`.
- Exercised executable SHA-256:
  `ddbf1cb88f2dea0fcc4595097e3621f940ace868f07a464ff29b21cd772c1e75`.

Bakhlo retains cancellation-date input required by its existing dated-cancel
contract; LOAM's inspected confirmation emits a target-only intent. Bakhlo also
requires end review and refuses blind tiny confirmation. This bounded safety slice
does not establish full LOAM interaction/visual parity, real IME/user acceptance,
Series/Months/continuation, sidecar power loss, P7 or operational cutover.

## Actual date-only correction

Bakhlo `3f953b7f5495305666abd876c60eb700d5d93297` plus the local UI work and this
date-only slice. Read-only LOAM source consultation: `ActualDateCorrection.lean`
(editing/preview, real-date validation, tiny gate), `SelectedDaySession.lean`
(`d`, publish and refresh). No LOAM build, source copying or paired execution.

`date_correction_session.ml/.mli` captures one entry and base bytes, reuses Ui_form,
Daily_overlays and Ui_panel, and returns a replacement transaction with only `day`
changed. `daily_interaction.ml` connects `d` in Actual and Selected Day, the existing
commit/result/reload path, and parent-ID restoration. No new writer or storage format.
The existing flexible Bakhlo date parser remains (including slash/full-width input);
this is not a claim of byte-for-byte LOAM input behavior.

Executed `./tools/build-bonsai-tui`, native `--self-check`, and `./tools/check`; passed.
Permanent checks cover invalid Gregorian dates, normalized Preview, edit/cancel,
tiny confirmation, long target review-to-end, terminal-control escaping, paste,
retained Record drafts, stale base/reload refusal, storage failure, Records refusal,
and cold readback of unchanged ID/memo/Effects/keys/paid-plan links with only the
date replaced. Both direct Actual save and Selected Day save → parent Actual
follow the ID after its row changes. Edit/Preview are in the 8-size × 3-theme native
render matrix. Existing uncertainty/recovery checks remain bounded evidence for
the reused publisher; this slice does not add new power-loss qualification.

Native tmux, `TERM=xterm-256color`, private socket, synthetic
`scratch/date-correction-smoke-uwZj5d/book.sexp`:
- Start with `date-target` dated 2026-10-12, signed ±123 jpy, keys `out`/`in`,
  completed plan `date-paid-plan` due 2026-10-01, and a second Actual.
- At 80×24: `a j Enter Enter d`, replace the date with 2026-10-11, Enter Preview.
  Current/proposed dates and full target ID were visible. `q` cancelled.
- SHA-256 before and after cancel:
  `3324facd4852638d4641cb64506941f4cb53273dc329070672f73df23685c22d`.
- Reopen/re-enter Preview, resize to 32×9, Enter: enlarge refusal; same book hash.
- Resize back to 80×24, Enter: published/read back; old Selected Day became empty.
  `q` returned to active Actual Detail with the same ID, new date, both keys and
  the original completed Scheduled link visible.
- Exit and launch a new process on the saved book. `a j Enter` showed those same
  facts. Saved SHA-256:
  `a03c84df5fa1a2b8f00e54415bfd1c606595be9c9202c0248fd93509e53e2b47`.

The lifecycle smoke executable SHA-256 was
`f4f55bbe8a1faf9fa513c3384f1ae9b8848ebe56ac7dfd378338f3e457e25a73`.
After adding visible escaping of control characters in target IDs, final self-check
passed and a new native process opened the saved target/date Preview at 80×24;
final executable SHA-256:
`82f047ccf8c84098d29f9180925dd78102e1ecda76ae44100638f0e8074e919c`.

No production input, LOAM paired acceptance, real IME, full linked-shape matrix,
power-loss/P7 or operational cutover was exercised. UI-03/04 acceptance remains open.

## List/detail capacity and drill-down/back cutover

2026-10-15: Bakhlo `3f953b7f5495305666abd876c60eb700d5d93297` plus step 4.
Actual workspace `terminal_geometry` delegates directly to `panel_geometry`,
eliminating navigation-paint dimensional drift. Transactions `page_size` uses
`tx_height` (`tx_height` when wide, `panel_height` when compact), matching the
exact painted visible transaction list capacity and fixing PageDown jumping past
unseen rows on 80×24 / 120×36.

The controller passes `actual_dimensions` (`width, max 0 (body_height - 2)`) to
`Act.handle`, matching `Act.screen`. The first drill-back checks covered only a
same-book return and selected row; they did not establish retained pane/scroll or
changed-book behavior. A subsequent regression failed before the fix at
`actual-return-restores-detail-focus-and-scroll`.

The repair makes `sync_actual_to_workspace` update only `workspace.actual`.
`back` enters Actual before restoring the browser, pane and scroll, without a
subsequent `W.sync` resetting the scroll or changing the module's ordering.
The blocked-Reversal footer again says writes are stopped rather than offering
normal confirmation controls. Selected Day's footer names Actual when it is the parent.

Executed `./tools/build-bonsai-tui`, native `--self-check` and `./tools/check`; passed.
Added controller checks cover:
- Return to the same detail focus/scroll without overwriting Selected Day's browser.
- A replaced in-memory book with the selected entry moved to another date: return
  follows its ID to row 17, rather than retaining the old row 1.
- A Japanese query, ascending order, selected Locus and nonzero detail scroll survive return.
- A stale blocked Reversal displays the stopped-writing warning on its actual screen.

Native tmux (`TERM=xterm-256color`, private socket, synthetic copy under
`scratch/actual-return-smoke-vvK6K7`): `a`, Enter, End displayed the bottom of
`actual-17`'s long Japanese description, date and ID at 80×24. Enter opened
Selected Day 2026-10-18; `q` restored the same active Actual Detail and bottom
content. Repeating the drill, shrinking to 48×14 and returning retained the active
detail with the same ID/date visible. The copy was synthetic; no household data used.

The date-correction return check substitutes an in-memory book, not a UI date-only
edit or save/restart scenario. No LOAM paired comparison, real macOS IME/preedit,
or user acceptance was run. P7, power loss, writers and storage remain unchanged.

## Shared editor input / Scheduled geometry cutover

2026-10-15: Bakhlo `3f953b7f5495305666abd876c60eb700d5d93297` plus this slice.
Record `field_text` migrated to shared `Daily_overlays.input_text ~caret:"|"`,
and wide side-by-side layout directly uses native `O.Columns` with child-local
styles, eliminating `combine_side_by_side`. The controller extracts carets
recursively via `Daily_overlays.cursor_in_rows`.

Scheduled creation migrated to `Daily_overlays.input_text`, UTF-8 cursor navigation
via `Daily_form.move_cursor`, field windowing via `Ui_panel`, 1-line notice
reservation with explicit `… more` overflow, and uniform row-width padding.
`Sch.cursor_position` was removed from API and checks; the controller derives
carets from painted rows. `Scheduled_create` was added to `render_cases` and
passed the full 8-dimension × 3-theme renderer matrix without row-width mismatches.

Executed `./tools/build-bonsai-tui`, `./_build/daily-bonsai/_build/default/ui/bonsai_daily.exe --self-check`,
and `./tools/check`. All passed.

tmux smoke (TERM=xterm-256color, trial copy under `scratch/editor-cutover-MhQ7YK`):
- Scheduled `n`: at 80×24, long ASCII/CJK locus displayed insertion tail with caret
  at (59, 4). Resizing to 32×9 kept focused Posting 1 visible via field windowing,
  with caret at (29, 2) inside the terminal. Escape returned to parent without write.
- Record `r`: at 80×24, caret was inside Amount at (21, 8). Resizing to 120×36
  rendered side-by-side Columns with independent Postings/Candidates styles and
  caret at (39, 13). Escape returned to Home holding the draft.
  This attempted entry filled the wrong fields; it qualifies only the observed
  caret/resize/cancel behavior, not a valid Record Preview/Publish lifecycle.

No LOAM paired comparison, real macOS IME/preedit, or manual acceptance was run.
P7, power loss, operational authority, writers and storage remain unchanged.

## Shared form / styled frame cutover

2026-10-15: Bakhlo `3f953b7f5495305666abd876c60eb700d5d93297`
plus this local form cutover. Ui_form.render_rows now accepts content dimensions
and native width, renders bounded input tails with Input metadata, follows focused
fields/buttons and reserves one local-notice row. Long summary/notice text wraps;
hidden rows are signalled by `… more`. Ui_panel.frame_rows shares the existing
frame and translates the input inset once. Modal_form, Jump, Search overlay and
Reversal Date use it; cursor_offset and Reversal's independent cursor API are removed.
Record/Scheduled sessions, writers and publication gates are unchanged.

Executed `./tools/build-bonsai-tui`, native `--self-check` and `./tools/check`.
All passed. Permanent form/controller checks cover widths 0/1/6/12/40,
heights 0/1/3/20, retained 80-character+CJK/literal-border values, native CJK width,
focus-following, short-notice stability, long-warning overflow, overlay coordinates
and Escape parent/bytes preservation at 80×24, 120×36, 48×14 and 32×9.
The renderer's existing 8-dimension/3-theme matrix now includes generic Modal_form.

An attempted Scheduled-create matrix case failed at 140×40: raw rows had widths
22, 80, 49 and 51. Its current screen is not a uniformly fitted overlay; that
case awaits the next Scheduled input/focus/notice migration. No cropping workaround
was added and Scheduled rendering is not certified by the passing matrix.

Actual native tmux smoke used TERM=xterm-256color and a fresh synthetic trial
under ignored `scratch/shared-form-SHaE5e`, never a household capture.
Before: `/` plus `abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz末尾`
painted a clipped prefix with no insertion marker at 80×24; real cursor was (17,9).
After: the tail and `|` were visible with cursor (64,9). Resizing to 32×9
kept `…klmnopqrstuvwxyz末尾|` and cursor (27,1); 120×36 gave (84,15).
Attention `i`→`n` showed the long Context tail at 48×14, Tab reached buttons;
submitting empty Context displayed the wrapped refusal without publication.
Calendar→`/` showed Jump's insertion cell at (6,4). Escape returned to parents.
Coordinates are zero-based. The attempted reversal walk had no selected Actual
and correctly refused; reversal Date/Preview remains covered by native session/
renderer checks, not by that PTY walk. Copy creation serializes the synthetic
fixture, so source-vs-copy byte equality is not a valid nonpublication check.

The final rebuilt binary SHA-256 is
`9e2cb6a2c3012291825c424d444579893ae5b62afd5ff26c4635cc2e7c41d506`.
Its final 32×9 Search→long input→Escape→q smoke again showed cursor (27,1).
Trial-book SHA-256 before/after that walk matched:
`269e616273b98a2009a4beeb7b22d6c5bd7b7675dd975405b8ab95395bace986`.

No paired LOAM walk, real macOS IME/preedit or manual visual acceptance was run.
G-1/G-3 are improved for these form consumers, not closed for Record/Scheduled.
P7/power-loss, operational adoption, config/fixtures/dependencies remain unchanged.

## Native build warning cleanup

2026-10-15: removed unreachable `Unix._exit 2` after the writer-lock fixture's
infinite wait in `tui/recovery_checks.ml`. The child still acquires the real
writer lock, signals readiness and waits for the parent's SIGKILL; no warning
attribute, timeout change or weakened lock assertion was introduced.

The linker warning came from the isolated Zarith `1.12+ox3` recipe, not Bakhlo:
its macOS flags embedded absent `-L/opt/local/lib` in zarith.cmxa. The user
explicitly approved repairing/rebuilding the same version inside this switch.
Checksummed `opam source` extracted the same release with existing Ox patches.
The local recipe removes the nonexistent MacPorts library/include paths and
declares the release license; it is retained as an ignored local pin.
Normal opam reinstall rebuilt Zarith, bignum, incr_map, bonsai_concrete, bonsai
and bonsai_term. Before/after switch exports have identical installed versions;
the diff only adds the Zarith pin/package recipe. No new package or global
environment change. Reproduction and retained paths are in
[Development](DEVELOPMENT.md#bonsai-isolated-linker-recipe).

`ocamlobjinfo` now reports `-lzarith -L/usr/local/lib -lgmp`, with unchanged
Zarith module implementation CRCs. `otool -L` still resolves the executable's
GMP to `/usr/local/opt/gmp/lib/libgmp.10.dylib`.
After cleaning only the generated `_build/daily-bonsai` target with Dune,
`./tools/build-bonsai-tui` completed with neither warning (no compiler/linker
warning output). The final native `--self-check` passed, including the real
writer-lock/SIGKILL recovery fixture and shared-input checks.
Executable SHA-256:
`0c27c22563638038e2393f2ac0f586017083afb7314f4943a5df9833c1fd0c2a`;
recovery_checks.ml:
`8460e83c1eaa83c70a54efd98c06806b2c8e6931fe60b0f2c074cff583529265`.
No main-switch/Core test rerun, new PTY, original household access, UI cutover
or power-loss/IME certification follows from this warning cleanup.

## Shared input / recursive metadata slice

2026-10-15: migration unit 1 of the shared-UI responsibility design only.
`tui/daily_overlays.ml` adds `input_text`, `input_cell` and `cursor_in_rows`.
The first reuses Daily_form byte offsets and the existing visible/tail/clip approach;
the other two resolve child-local Input positions through nested Columns and hide
positions outside pane width or painted text. Existing screen consumers are unchanged.

`daily_interaction_checks.ml` now exercises empty/exact-fit/overflow, start/middle/end
editing, 80 ASCII characters plus CJK, literal bars/box glyphs, blank insertion cells,
zero/negative/one-cell widths, left/right/nested panes, clipped rows and machine-width
offset bounds, all with the frontend's actual width_of.

Executed successfully in the existing isolated environments:
`./tools/check`, `./tools/build-bonsai-tui`,
`./_build/daily-bonsai/_build/default/ui/bonsai_daily.exe --self-check`.
The native self-check prints `PASS: shared input windows, retained UTF-8 bytes, insertion
cells and recursive Columns caret bounds.` Build emitted warning 21 in unchanged
recovery_checks.ml and the missing `/opt/local/lib` linker search path warning.

A throwaway compiled OCaml smoke directly called the new helpers with native Bonsai
width. Long input at width 120 had local/parent caret 90/98; shrinking to 8 gave 7/15.
Moving one UTF-8 scalar left and inserting `中` retained the complete edited value;
expanding to 120 painted `日本語末中|尾` after the 80 ASCII prefix, with caret 90/98.
Nested Columns parent translation and zero-width hiding assertions passed. The smoke
did not call filesystem publication; its source/compiler artifacts were removed afterward.

Exercised executable SHA-256:
`35d62ced8804004ea363099ddf2daf2d536bb8cfcd6750ca16e60f92babe582e`.
Source SHA-256: daily_overlays.ml
`4768f601add4c413919c85559efb9cb32c72b5b9e1612b4472f8462ecff90be1`;
daily_interaction_checks.ml
`0f1a984ab941a6549e49632a61c405e7b1d9e1f7a07143e782a1698d7398201b`.

No UI cutover, PTY, LOAM runtime comparison/build, original household read, dependency
installation or writer/gate change. G-1/G-3/G-4 remain open until consumer migrations.
No grapheme/IME, physical terminal width, live race, performance or P7 certification.

## Actual search paired-runtime slice

2026-10-15: the user fixed the target at all LOAM user-facing non-budget behavior,
not paint-only parity. Budget implementation is deferred until needed. The ordered
plan and screen status remain in `tasks/todo.md` and `LOAM_UI_GAP_LEDGER.ja.md`.

Baseline: Bakhlo `cfed58304f9f58c329f6e36352981fed60a6ec66` plus the current
uncommitted `actual_workspace.ml/.mli`, controller/search regression and shared-tail
changes. LOAM source inspected at `da4dfb65b11055dc0af65ce4e3d5595ffa67be77`.
LOAM was neither built nor modified; its existing binary/source correspondence is
unqualified. SHA-256 of the executed binaries:

- LOAM `.lake/build/bin/loamTui`: `75f91da92cc5170a641521b1d967c79aac4890ef3326e26b5e1e36e5cef003a3`.
- Bakhlo before: `0d0246bc18e93bbb6fc555369bbf94606c94b8c5c24d154bfe761c3d492607d2`.
- Bakhlo final: `a8c3f86e5137aa7019be0f272bb3e7626116605c435c39eb8b5e14450527482c`.

Both native programs ran on a private tmux socket with TERM=xterm-256color and
separate synthetic empty authorities: Bakhlo Daily v3 (JPY scale 0, explicitly
empty labels/approved loci/entries/plans/support) and a LOAM HouseholdImage v2
containing only empty normalized Actual v4. No original household/config was read.
Retained text captures are under ignored `scratch/parity-search-ODwKVq/`.

Operation: start at 80×24 → `a` → `/` →
`abcdefghijklmnopqrstuvwxyz0123456789末尾` → resize 32×9 → resize 120×36 →
Enter → `/` → Esc → `q` → `q`.
Before the change, Bakhlo painted the search prefix and tmux reported caret (31,1);
LOAM painted the insertion tail at (30,1). Positions are zero-based.
The final paired walk asserted identical search rows at 32×9:
` Search: /…vwxyz0123456789末尾`, with a real blank insertion cell at (30,1).
At 120×36 both retained the full query and caret (50,1). Enter kept the complete
query and hid the caret; Esc cleared the new search. Both authority-file SHA-256
values were unchanged after each walk. All of these assertions passed.

Implementation: `Actual_workspace.search_line` owns the visible query tail and
insertion cell; both controller rendering and `cursor_position` use it.
The prior Record tail helper moved unchanged into `Daily_overlays.tail_text`,
and Record now calls it. No query value, filter, writer or publication gate changed.
Permanent controller regression covers long ASCII/CJK search at 32×9, 48×14,
80×24 and 120×36, caret/paint agreement, retained full query, Enter and hidden
caret when the input cell is unavailable.

Executed: `./tools/build-bonsai-tui`, final native `--self-check`, paired tmux
walk above, and `./tools/check` all passed. The build emitted warning 21 in the
unchanged recovery-check nonreturning fixture and a missing `/opt/local/lib`
link search path warning; neither stopped the build.
The native self-check also exercised the existing Record, Scheduled and recovery paths.

This closes the long-search insertion-window defect only. The paired captures still
differ in workspace header, frame decoration, empty-row/count/footer geometry and
broader pane layout. Generic-form geometry G-1/G-3 and Record styling G-4 remain
separate gaps. No full Actual acceptance, actual macOS IME/preedit/manual acceptance,
performance result, power-loss/P7 qualification or operational cutover is inferred.

## Current non-budget UI safety slice

Baseline: Bakhlo `d2e2f5f` plus the current sidecar/Pace repair; LOAM `9dbe2496`
was inspected read-only, not built or executed. On the existing macOS x86_64
isolated environments, `./tools/check` and `./tools/tui --self-check` passed.
The existing `daily_interaction_checks.ml` now checks malformed Attention/settlement
rows, duplicate IDs, bad dates/quantities/references, nonregular/dangling inputs,
cooperative lock/save failure with retained UI drafts, stale-state refusal,
exact huge-quantity cold readback and explicit sidecar reload. It also checks
missing/malformed/duplicate/mixed-Measure Pace pools, malformed/ambiguous periods,
negative What-if floor division and Pool-only edits that preserve every preset
byte-for-byte without creating missing period evidence. Native renderer checks
and existing monolithic recovery checks remain in the same UI self-check.

This is synthetic local qualification, not all-screen LOAM runtime parity,
manual visual/IME acceptance, a new UI CI gate, role-setting persistence safety,
multi-file atomicity, power-loss durability or persistent acknowledgement/P7.
No production inputs, migration, new dependencies or storage adoption were used.
Current scope/remaining gaps belong to [the cutover inventory](CUTOVER_CHECKLIST.ja.md).

## Actual browsing interaction slice

Bakhlo `d2e2f5f` plus the safety and Actual UI changes; LOAM `94ceb072` source/docs
were inspected read-only. `tools/check`, `tools/tui --self-check` and direct compiled
UI self-check passed. Existing controller checks cover aligned signed/grouped amounts,
explicit zero/missing/split/multi summaries, huge-value detail fallback, Japanese
ellipsis, live Search filtering, viewport-sized pages, detail Home/End without
reselection, immediate upward movement from the bottom, resize clamping and exact
Record draft/parent restoration. Dimensions: 32×9, 48×14, 80×24 and 120×36.

The existing Expect approach was used in ignored `scratch/actual-pty-e5NC0c/check.exp`
with the controller's synthetic fixture. Native PTY walks at all four sizes, resizing,
search and Record cancel/resume completed without writing the book; terminal settings
were restored except the previously qualified macOS PENDIN bit. Initial walks timed
out because the harness expected the obsolete literal `Home` on the bonsai launcher;
correcting that expectation to its actual heading made the walks pass. ANSI transcripts
are synthetic scratch evidence, not paired LOAM screenshots or manual acceptance.
The two-pane layout, modal search and missing Locus filter/date-change/Merchant UI
remain explicit gaps; UI-03 is not complete. No writer, canonical format or authority
boundary changed, and P7/power loss remain unqualified.

## Shared panel / viewport slice

`ui_panel.ml/.mli` extracts the existing framed painter and supplies shared data
capacity, selection-following windows and overflow-safe clamped offset movement.
Actual and Scheduled use the same rules for rendering and navigation; their
content, selection identities, filters, action semantics and publishers stay outside
the component. Other existing panels/overlays retain the framed painter, with no
new per-workspace branches in its API. The sharing review is in `tui/README.md`.

`tools/check`, `tools/tui --self-check` and the direct compiled UI self-check passed.
Independent checks cover empty/zero-height views, hidden low-height headings,
`min_int`/`max_int` offsets, Unicode dimensions and inactive selection vs focus.
Scheduled regression checks add real list endpoints, visible-row pages, detail
Home/End without reselection, immediate upward movement at the bottom, focus/resize,
filter/reload resets, retained edit drafts and cancellation return context. Existing
Actual, Home, Preview tiny-publication refusal, storage-conflict and recovery checks
remain in the same harness. No new dependency or test framework was introduced.

Ignored `scratch/shared-panels-9rXAq8/pty.exp` walks each workspace at 80×24, 120×36,
48×14 and 32×9 using only controller-generated synthetic copies. Paging/endpoints,
focus, resize, draft cancellation/resumption and exit completed; all eight books
were byte-identical afterwards. Terminal settings restored except macOS PENDIN.
These native walks are not paired LOAM screenshot comparison or human acceptance,
and do not qualify power loss/P7. No operational data, canonical format or writer
was changed. Full Scheduled Series/Months and the remaining Actual UI gaps are
not supplied by a reusable panel.

## Reversal Preview / resize safety slice (P05)

`reversal_session.ml/.mli` owns local Date/fixed-snapshot Preview and an explicit
publication intent; `daily_actions.commit_reverse_entry` remains unchanged. The
controller retains the target/date/base on refusal, rejects held Record drafts,
stops on changed reload or uncertain outcomes, and closes a confirmed intent
without another write. Synthetic checks cover invalid/normalized dates, Ctrl-Enter
and paste non-publication, exact signed/decimal/huge original and inverse quantities,
end/tiny gates, parent return, storage/Records refusal, stale base, simulated lost
acknowledgement/reload and cold coordinate/key/relation preservation.

A real synthetic PTY counterexample admitted publication after End followed by a
32×9 shrink: the Bonsai handler carried older dimensions into the action. The shared
frontend now uses `state_machine_with_input`, reading dimensions at action application;
no Record/form/paint/writer change was made by P05. The failing transcript and candidate
remain in ignored `scratch/reversal-safety-2XGqv1/run-1791971542109685/`. Initial harness
scope and multiline-S-expression assertions were separately repaired, not product fixes.

Final integration at Bakhlo `0f611cd` plus the uncommitted shared-panel/P05 work passed
`tools/check`, UI build and compiled `--self-check`. P02's independent Record changes
were preserved; a transient Record-width failure during its edits is not a current
pass claim (its earlier binary/manifests are preserved under `record-in-progress-binary/`).
Concurrent generation had removed a UI executable, so native walks use a pinned copy
and identical pre/post-build source manifests. Final binary SHA-256:
`45cfca7e31193f488fdfbdd7fc31818158d4682935cfab6a3eca22f40ea2716c`.

`scratch/reversal-safety-2XGqv1/pty.exp` passed six walks: cancellation/resize at
80×24, 120×36, 48×14 and 32×9 without changing bytes or writer artifacts; long Japanese
and 227-digit EUR-quanta review at the normal sizes, end/tiny refusal and explicit
publication of exactly the original plus linked inverse. Final evidence is
`run-1791972570478934/`. The eight Actual/Scheduled navigation/draft regressions in
`scratch/reversal-regression-GDzD0b/pty.exp` also passed (`run-1791972585846832/`), with
unchanged books. Every walk restored terminal settings except the previously qualified
macOS PENDIN bit. These are synthetic PTY observations, not paired LOAM screenshots,
human visual/IME acceptance, all-operation modal safety or persistent Ack/power-loss/P7.
LOAM `db631763` reversal source was inspected read-only; no LOAM writes were made by P05.
Its HEAD independently advanced to `cbd5db86`; the reversal view/session/publisher files
are unchanged from the inspected revision. The final LOAM working tree is clean.

## Find the relevant evidence

- [Simple S-expression UI loop](#simple-s-expression-ui-loop): existing native screens write/reopen/
  correct Book evidence; synthetic only, no new UI/backend or durable Saved.
- [Minimal ordinary S-expression book](#minimal-ordinary-s-expression-book): main Parsexp adoption,
  native exact/history/absence/refusal and fresh cold staging; NOT a store or durable Saved.
- [Explicit initial quantities](#explicit-synthetic-initial-quantities): BOTH native synthetic
  consumers start from supplied signed/zero/huge Wallet/Bank observations; no real-data/Saved claim.
- [Safe interchange design](#safe-data-interchange-design-review): readable schema rules and
  export/import profile/refusal boundaries; documentation ONLY, no executed hledger compatibility.
- [Plain-text candidate pairs](#delimiter-free-plain-text-candidate-pairs): same four synthetic
  evidence examples without structural delimiters; NO parser/writer/migration implementation.
- [Synthetic S-expression candidates](#synthetic-s-expression-v1-candidates): four human-review
  evidence-generation examples; NO new parser/writer/migration or executed schema admission.
- [Stopped private comparison](#stopped-private-representation-comparison): scoped read-only
  capture/profile and private format views; NOT full extraction, codec or migration qualification.
- [Canonical evidence review](#canonical-evidence--inherited-format-review): sourced retained
  information versus format debt; NO private-data inventory, codec adoption or migration.
- [Native Unix I/O failures](#native-unix-io-failure-boundaries): kernel-errno/returned-error
  connections, short writes, cleanup and complete-but-uncertain copies; NOT physical durability.
- [Closed synthetic backup/restore](#synthetic-closed-backuprestore): whole family/receipts,
  fresh namespaces, damage/lease/actual create collision/process-kill refusal; NOT durable Saved.
- [Synthetic TUI income](#synthetic-tui-income): explicit counterpart/receiver, mixed cold
  correction/history and uncertainty; old Bank/source remain unknown, no income total guessed.
- [Same-currency TUI transfer](#same-currency-synthetic-tui-transfer): mixed expenses,
  explicit endpoints, old Bank unknown, cold correction and detail-only IDs; synthetic only.
- [Synthetic TUI recording](#synthetic-tui-recordreopencorrection): BOTH native UIs,
  cross-language cold corrections/original history, uncertain receipt checks; no durable Saved.
- [Experimental Movement proposals](#experimental-ordinary-movement-proposals): new-row
  encoding/base preservation and whole-candidate refusal; not recording or storage adoption.
- [Friendly projected quantity answers](#friendly-projected-quantity-answers): typed narrowing,
  no raw provenance/input diagnostics in summary, not an auth/sandbox qualification.
- [Quantity explanations](#terminal-quantity-evidence-explanation) and
  [one-image CLI questions](#one-image-quantity-cli-questions), including answer-bound cuts.
- Current [native LOAM-input reader](#scoped-native-loam-input-reader) and
  [experimental text reader](#experimental-versioned-text-read-ordinary-actual-profile).
- [Engine tests, models and type boundaries](#retained-executable-evidence);
  [structured-operation audit](#structured-operation--diagnostic-readiness-audit-no-new-features).
- [Historical private read](#latest-loam-contract-private-conditional-quantity-experiment):
  results retained, retired probe code; not a runnable/current household acquisition.
- [Synthetic text scale/history cost](#synthetic-text-scale-and-history-cost): 10k/100k native
  phase/worker measurements, not an SLO, lifetime retention or storage adoption.
- [Native Unix text publication consumer](#unix-text-publication-consumer-synthetic-no-saved):
  synthetic record/select/reopen/correction and receipts, not durable Saved/store adoption.
- [Unix SQLite trial](#unixsqlite-synthetic-persistence-bounded-outer-trial-no-saved-qualification)
  and [Linux synchronization/lifecycle counterexample](#linux-sqlite-syscall-failures-and-retained-journal-lifecycle-control).
- [Guarded Irmin/block trials and limits](#irmin-block-persistence-bounded-two-trial-dependency-fixes-required),
  [interruption/restore controls](#guarded-block-retention-interrupted-publication-and-offline-restore-controls),
  [Linux/Mirage engine trial](#linux-native-replay-and-mirageossolo5-spt-engine-bounded-trial-guard-required).

These are scoped observations at their recorded revisions/hosts, not a cumulative production
certificate. Keep negative controls and counterexamples; do not erase history to shorten this
file. [Handoff](HANDOFF.md#maintenance-revisit-decisions) owns when cleanup is worth revisiting.

## Instrument review gate

Use the smallest check that answers the current question. Existing tests and narrow
source owners come first. A task note or D/P/R review is optional when it clarifies a
concrete cross-boundary risk, not required ceremony for every change. Report actual
results and remaining limits; do not turn historical qualification into today's backlog.

Select by risk, not directory or a per-slice checklist. Reuse independent models/oracles;
ordinary consumers test connection and failure boundaries. No mandatory all-tools pipeline,
new document, theorem or 10,000-case campaign for each change. User prefers direct native OCaml;
no new Python bridge or extra test harness without a concrete unresolved need. Existing native
checks remain available, not a reason to grow scaffolding first. A needed unavailable check
is a limitation/blocker, not silently replaced by compile success.

| Residual question | Instrument / trigger |
| --- | --- |
| What meaning/prior evidence must survive? | Semantic contract, narrow references, D/P/R review |
| Structural counterexample? | Small finite model/enumeration or Alloy; state scope and correspondence |
| Durable general law? | Optional Lean/specification with assumptions and mapping, not OCaml refinement by association |
| Procedure/authority ambiguity? | DRAKON for refusal/operation order, D2 for dependency/source topology; simple explicit code may suffice |
| Retry/crash/interleaving outcomes? | TLA+/TLC or SPIN when real write/failure contracts exist; targeted fault injection |
| Scale/cost uncertainty? | Named synthetic workload/benchmark; no universal inference or invented target |
| Duplication/dependency/security drift? | Focused repository audit with exact evidence |

Formal tools remain development-only. Ordinary build/test/release must be Lean-free.
Checker independence needs a separate question; neither standard Lean nor token scans
establish it. Tool selection does not authorize dependencies or source copying.

## Synthetic Locus addition and recording

Approved at 8221c57: add 科目 → select → record → reopen → correction in the SAME trial screens.
SOURCE-only reference f82f4c4: Core LocusAdmission, Presentation LocusCatalog and Tui admission
session establish that new-write vocabulary, labels, role/routing and history support are distinct.
No source copied/built, private or operational data inspected. User-provided exact Locus tokens
are the current fallback display, not a new account/Purpose ontology or label/config framework.
Book v2 adds ONE required explicit policy record; v1 remains its original pure format/API, not
approval for a policy-qualified consumer. Whole historical source admission never consults current
new-write permission; new v2 proposals require EVERY Effect's Locus allowed. Adding vocabulary
preserves all support/history and supplies neither Event nor zero. Unsupported policy refuses.

Existing native expect check adds exact space/Unicode vocabulary identity, immutable base and
whole add/print/reread; balanced record, original source/cuts/support, no implicit zero/alias/role,
empty versus absent policy, duplicate/empty/unapproved and eight malformed/missing/version controls,
historical-read independence and append/correction refusal under no current approval. Existing cram
now cold-stages/reads v2 and vocabulary/1000→900/unknown category; exact profile heading is v1/v2.
Main 181 expect/five cram and local release @install/format pass with nonexistent LEAN/LAKE;
captured Domain/Application hashes and exact 51 main names/versions unchanged, strict/fatal 8/9/11.

Both native builds/pure form/render smokes and reused recording checks pass: Ctrl-A editor add,
Ctrl-D select, cold children at 1000/category added/900/850, retained original category/memo/day/edge,
unchanged old generation files and independent cuts. Duplicate/empty/unapproved requests produce
no filesystem changes and retain the name; historical-only/v1 rows read without inferred approval.
Category conflict retains editor; OLD/NEW uncertain publication/reconciliation uses the unchanged
publisher/pending mechanism, never blind retry or a second writer. Same-date/older-date histories
and the previous four-currency transfer/income/180-bit/precision/route/correction gates remain.
Existing Expect driver adds only category keys/assertion: nine real PTYs cross BOTH native UIs,
add/select/record → exit/reopen/correct/recorrect/original history → read, old/new uncertainty,
missing-before-TTY refusal and full stty restoration. No new harness/model/tool installation.

Ignored raw evidence and preserved prototype sources/binaries: `scratch/tui_comparison_review/loci-v11`.
Failed PTY v1 returned on a PARTIAL rendered frame before completion; existing driver now appends
chunks until its bounded timeout and fresh v2 passes (failure/store retained, not relabeled).
First extended cram lacked declared sandbox fixture dependency; next showed deliberate CLI byte
escaping rather than literal UTF-8. Both corrected against exact native evidence, no codec fallback.
A separate fresh `sexp-v10/stores/loci-demo` is initial 1000/no Events for the user to try.
Dedicated backup/role/routing/display-label editing/plans/budgets/reports are NOT qualified by this
slice. No new store/dependency, existing-store upgrade/write, real recording, recovery/durable Saved,
Mirage/Linux replay or push. Existing LOAM remains authority; required remaining household functions
stay in scope. [Current handoff](HANDOFF.md)
links the small demo, not a feature-cut-down product.

## Simple S-expression UI loop

User rejects backup/publisher-first scheduling and approves the small existing-UI path at b5ee924.
Ignored Workbench/Recording now retain Book directly, with no image-to-book projection or new UI.
Existing Unix publisher's document-only parameter/distinct layout connects both concrete codecs;
original text controls and reuse/interleaving controls pass, including conflict/replay/BUSY/eight
uncertain checkpoints/two real SIGKILL/180-bit cold reads. No new publisher/model/harness/dependency.
All original trial source/images/counterexamples retained; only new `sexp-v10/stores` roots used.

Both stock Notty and already-installed Ox/Bonsai builds and existing pure/view smokes pass unchanged
focus/layout/arithmetic/decimal/180-bit/currency/route/date/history boundaries. A NEW Book seed has
no Pantry presence (unsupported by v1), therefore UNKNOWN; old text sources are never converted.
Focused reused recording checks pass initial 1000 → expense 900 → cold older-date correction 850,
original memo/date/Event/Effects/correction edge and initial independent cuts, unchanged old physical
generations, existing-root refusal, incomplete/duplicate/precision input before effects, whole
Measure/scale/key/missing-memo UI refusal, conflict draft retention and OLD/NEW read-only uncertainty.
Raw native logs show separate child states at 1000/900/850; later conflict control's extra Event is
not confused with that primary witness. A separate `simple-demo` remains at initial 1000/no Events.

The SAME installed Expect driver, changing only fresh store/evidence namespace, passes nine real
PTY children: Notty ja input → Bonsai en reopen/correction/four currencies → Notty ja recorrection/
original history → Bonsai en read; OLD interrupted block/NEW receipt reconciliation, missing-store
refusal before terminal acquisition and full stty restoration. No new keyboard/renderer/harness.
Current selected Book export is directly accepted by the main S-expression reader. Both native
pure complete proposal bytes match; native cross-format ownership/backup/physical failure portability
or power-loss safety are NOT inferred. Main tools/check: 180 expect/five cram, local release @install,
format; captured 64 Domain/Application/Book source hashes and exact main 51 names/versions unchanged.
Bonsai already had Parsexp; no installs/compiler changes/sibling or private input.

Evidence/baselines: ignored `scratch/tui_comparison_review/sexp-v10`. Failures retained: parallel edit
request had a non-unique exact match and refused atomically; non-executable build script invoked via
sh; Ox directory discovery initially omitted sexp and then passed with explicit inclusion. Original
text control initially lacked its fresh parent directory (provision returned uncertainty), then
passed after explicit parent creation; no fallback/cleanup. A guessed Measure query correctly returned
unknown/exit 3; the exact supplied ID returned 1000. rtk hid terminal-frame output, so fresh direct
native runs and raw logs establish results, not wrapper summaries.

Limits: fresh synthetic prototype only; no real/legacy writes/migration, UI/store production adoption,
full-household profile, dedicated canonical backup/restore, all I/O/device/interruption/concurrency
coverage, durable Saved, Linux/Mirage replay or public release/push. Existing LOAM remains authority.
Next: human feedback using [short trial README](../scratch/tui_comparison_review/README.md), not
another infrastructure prerequisite. Do not add missing support or claim production safety to simplify.

## Minimal ordinary S-expression book

Approved at clean 33d947d: Parsexp v0.17.0 and the smallest main synthetic initial → expense →
correction → fresh S-expression file → separate-process read. Existing native Model/Application
oracles own arithmetic, Actual/date/correction and independent support; no new model, harness,
Python bridge, Lean execution or private input. [Book interface](../sexp/book.mli) and
[Architecture](ARCHITECTURE.md#minimal-ordinary-s-expression-book) own the bounded profile/contract.

On macOS x86_64 / OCaml 5.3.0 / Dune 3.24.2: install and lock diffs add ONLY Parsexp v0.17.0;
installed 50 → 51, all previous names/versions/compiler unchanged. Locked bootstrap passes;
existing opam missing authors/homepage/bug-reports/license warnings remain, not release permission.
All 70 captured Domain/Application ML/MLI hashes remain byte-identical. Strict sequencing/fatal
8/9/11 unchanged. No inherited trials, sibling or private payloads were edited/executed.

Five focused native expect connections pass: independent literal quantities `1000 → 900 → 850`,
Food `0 → 100 → 150`, unsupported Bank; originals/dates/text/keys/Effect order/history; independent
reflected cuts with forward references (`996`/`204`); signed 180-bit quanta, separate Measures/scales,
exact control/invalid-UTF8/quoted/Japanese bytes, explicit empty vs not-supplied and anonymous
net-zero multiplicity. Fourteen wire controls plus syntax/support/Movement/Event/source controls
refuse whole inputs/proposals; no missing input/default zero, inheritance or date-order winner.
Native cram separately stages/reopens/corrects and verifies original source/history bytes, unknown,
existing target/symlink refusal, malformed flags, whole unsupported/missing input before creation,
conservative uncertain create failure, and genuine compiler rejection of forged opaque Book.
Normal tools/check passes 180 expect/five cram; forced package tests, release-profile local @install,
pinned formatting and fresh absolute-build-directory engine-only targets pass. No outer adapter/
Presentation/CLI/bin compiled artifacts in that engine build. Nonexistent LEAN/LAKE checks pass.

Failures retained in ignored `scratch/ordinary_sexp_review`: OCaml 5.3 reserved `effect`, ambiguous
doc comments and unavailable List.iter_result/validity record API fixed before execution; first
cram expectations/help/closing parentheses corrected against actual native output, sandbox read-only
fixture copy explicitly made writable before unsupported-row insertion, forge error checked as the
actual quoted-field compiler diagnostic. Relative nested Dune build directory refused; absolute
ignored build path passed. rtk scoped git diff refused; raw exact diff used. These failures are NOT
successful qualification. Final native raw check contains all 180 execution markers.

Scope ends at whole-admitted candidates and fresh close/byte-readback, not operational recording,
selected-generation publication, receipts, fsync/device/power-loss, all syscall failures, source
capture concurrency, full-household codec/config retention or canonical backup/restore. Stable
supplied inputs/cooperative parents assumed. No real data, UI/store adoption, hledger, migration,
recovery, Linux/Mirage replay, public release/push or authority cutover. Existing Lean LOAM remains
sole operational authority; successful cold synthetic read is NEVER durable Saved.

## Safe data interchange design review

At clean fbd6d84 user approves readable/maintainable/extensible S-expression evidence, hledger
journal export and trustworthy imports. [Interchange design](ARCHITECTURE.md#safe-data-interchange)
records D/P/R and selected instruments; [Architecture](ARCHITECTURE.md#safe-data-interchange)
owns requirements and planned qualification cases. Reuse existing currentness/date/exactness/
support/publication evidence as constraints, not proof of an unwritten adapter.
This increment changes existing documentation only. Exact diff review, new link targets/anchors
and whitespace checks pass; code/interfaces/tests, main lock/dependencies and synthetic fixture
bytes remain unchanged. No private input, sibling execution/source copy, dependency installation,
hledger execution, import/export semantic roundtrip or main-suite rerun. Compatibility, escaping,
source-specific mapping and actual failure behavior remain UNQUALIFIED until implemented and
independently checked; a successful codec trial does not establish any of them.

## Canonical evidence / inherited-format review

User requests reviewing LOAM's inherited shape before more prototype UI/store work. D/P/R,
instruments and privacy boundary recorded at clean c7da7a3 before detailed review. Read SOURCE
and docs only at clean sibling `f82f4c45498ce9b3c51a76acb7189588a5f74718`: operating mode,
blueprint/workbench/evidence map, then nearest authority/codec/projection owners. No repository
wide generated audit, new model/theorem/test/parser, upstream build/command/source copy,
operational/current-user payload/metadata inspection, private fixtures or format migration.
Maintenance table reviewed: no refactor now; future profile/field changes must reopen adapter
coverage. [Architecture](ARCHITECTURE.md#canonical-evidence--inherited-format-review) owns the
family classification and candidate boundaries; this section owns the source evidence/limits.

| Observed source boundary (paths under sibling `Loam/`) | Finding |
| --- | --- |
| `Authority/ActualAuthority.lean`: `actualPathFromRootOrFile`, `loadHouseholdObserved?`, `publishActual?` | Production root selects required Actual inside `household.loam`; explicit standalone Actual remains diagnostic/migration, never an automatic root fallback. Historical Actual lock identity remains explicitly temporary |
| `Authority/HouseholdAuthority.lean`: `knownSectionNames`, `qualifyKnownSections`, `publishObserved?` | 13 registered payload families; absent is not invented empty, known present bodies qualify, unknown/unmarked sections are preserved exactly. Observed-byte gate/staging/previous retention are publication mechanics, not household fact families |
| `Persistence/HouseholdImagePersistence.lean`: `encodeSection`, `decode?`, `body?` | Opaque payload length uses Lean String Unicode scalars, not bytes/graphemes. Absent != present-empty; duplicates/truncation/version mismatch refuse. Outer v2 numbering reflects research history; v1 never production |
| `Persistence/NormalizedActualPersistence.lean`: `encodeNormalizedActual?`; `Core/ActualEvidence.lean`, `Core/Settlement.lean` | Current encoder chooses v1-v4 by retained settlement/revision/extinguishment evidence. Actual carries more than current signed Effects; settlement quantity/Measure is independent of source-bounded RelationUnit. Old version numbers do not prove dead data |
| `Persistence/ScheduledLifecyclePersistence.lean`: `ScheduledLifecycleImage`, encoder/decoder; `ScheduledPersistence.lean` | Semantic occurrences + one typed terminal memory are serialized as four fixed substreams, including three former terminal kinds. Concrete simplification candidate in physical factoring, not deletion of completion/replacement/retirement distinctions |
| Registered Capacity/Attention/routing/role/Locus codecs | Explicit allocations, due/unknown/closure facts, historical Purpose routing, partial roles and NEW-write policy, rather than reconstructable report labels. Similar row shapes do not earn semantic merger |
| ZeroOrigin/OpeningSupport/CurrentQuantityAnchor/Presence/BoundedHistorySupport codecs; `Application/CurrentQuantityAnchor.lean`, `Core/BoundedHistorySupport.lean` | Explicit support/coverage, opening reference, assertion-to-cut ownership, presence without scalar, bounded-history claim. ASSERT is not a cached balance; opening quantity is already stored in Actual, not repeated in OpeningSupport. Anonymous group identity/order is unnecessary but cut ownership is not |
| `Core/MovementOperationEvidence.lean`; Bakhlo `loam_read/read.mli`/`input.ml` | Request -> original Event is idempotency provenance, not payment/chronology. Current native entrance qualifies it outside Core, retains other opaque sections and refuses settlement/unknown Actual rows rather than filtering richer evidence |
| `Presentation/MeasurePresentation.lean`, `Authority/MeasurePresentationAuthority.lean` | Exact quanta presentation/input scale is external metadata; changing a used Measure's scale requires migration. Missing-scale 0 is historical LOAM convention, not permission to infer a Bakhlo default. Other external configs remain unclassified |
| `Review/ActualJournalProjection.lean`, `Cli/JournalExportCli.lean`, `Export/BeancountExport*.lean` | Only correction-aware current Events/dates/descriptions reach export; plain journal omits Effect keys too. No support/history/policy codec. Beancount Open dates are scaffolding; projection is one-way, not information-preserving canonical extraction |
| Upstream `README.md`, `docs/BEANCOUNT_FAVA.md` versus current authority/export pipeline | Canonical filename descriptions/examples still show older standalone authorities. Source-selected current root route overrides these descriptions; no claim about deployed binary or user's selected data version |

Qualification is **source inspection**, not freshly executed LOAM tests/proofs or a private
usage census. Existing Bakhlo group/quantity tests and native-reader refusal/type boundaries,
plus upstream outer-framing/journal tests, were inspected only; no rerun was needed for doc-only
work. Two synthetic explanatory contrasts (different superseded history with identical current journal; same
assertion/Effects but different reflected cut) illustrate the already-earned non-reconstruction
boundary; they are not a new experiment/harness. No claim that hledger's full format/extensions
cannot encode this evidence: no hledger trial was run.

Confirmed costs: outer-length editing burden, old Scheduled physical decomposition, stale
canonical-path documentation/legacy entrypoints. Our trial's all-ancestor snapshot chain is
also not a household semantic requirement; preserving originals/receipts does not automatically
choose its physical layout. These findings are not evidence that all retained families are excess.
No family/field is marked operationally unused; no safe deletion, canonical encoding, frozen config bundle, extraction completeness or migration is earned.
Native reader's partial admission and text proposal's ordinary profile still block treating
those experiments as complete household representation. A coherent separately authorized
private sample is needed for actual family/metadata use and next representative format choice.

Selected source/docs (39 nearest owners) and revision/status recorded as digests in ignored
`scratch/canonical_evidence_review`; no upstream implementation copied there. Scope checks:
all selected owner hashes/revision/clean source status unchanged, Bakhlo lock/exact 50-package
set unchanged, tracked executable/interface/test files untouched, new local documentation links
and whitespace checked. No main/compiler/test result is inferred from this review; prior
native qualification remains scoped to its own increments. No dependencies, UI/store/format
adoption, parser/source changes, real recording, recovery, cleanup, publication or push.

## Delimiter-free plain-text candidate pairs

At 1a2ce2b user requests a lighter plain-text comparison with no parentheses/brackets/braces.
[Paired candidate README](../examples/plain-v1-candidate/README.md) owns provisional spelling;
D/P/R and no-code/private-access boundary recorded in Handoff before hand-authoring four `.txt`
files. Same synthetic payloads, declarations, record/effect order, independent cuts, explicit
relations and original request mappings as corresponding S-expression candidates. No copied
operational data, new DTO/parser/translator/writer/migration or permanent dual-codec commitment.
Nonempty records explicitly supply their collection; empty/not-supplied remain explicit, never
implicit absence defaults. Scope/conditional expectations/receipt gaps remain the S-expression
README's, including the invalid flattened case and no original-result/Saved proof.

One-off static checks: exact QUOTED/NUMERIC LITERAL SEQUENCE equality per pair; absence of six
structural delimiter characters, keyword/end block balance, manual state/reference review and
01/04 intended-loss diff. These do NOT parse trees, decode schema, establish information-
preserving roundtrip or execute semantic admission/refusal. Original four `.sexp` file bytes,
tracked executable/interface/test paths and exact main 50/lock unchanged; links/whitespace
checked. No main-suite rerun inferred, dependency installation, private reads/clipboard export,
upstream execution/build/copy, original write, migration, cleanup or push. User review follows;
S-expression preference versus plain syntax is reopened, not silently switched/implemented.

## Synthetic S-expression v1 candidates

At e58594a user clarifies selected current book is a self-contained canonical EVIDENCE generation,
not flattened state, and requests only a few synthetic fixtures BEFORE implementation. D/P/R,
maintenance decision and explicit no-parser/writer/migration boundary recorded in Handoff first.
[Candidate README](../examples/sexp-v1-candidate/README.md) owns vocabulary/expected outcomes;
Architecture owns the evidence-generation clarification. Four hand-authored `.sexp` files use
ONLY constructed examples/public semantic requirements, never operational copies/results.

01 retains original/child Events, independent occurrence revision (same spelling/different ID
role), source-Effect relation/discharge, two distinct reflected cuts, explicit origin/presence,
NEW-write vocabulary and original request associations. 02 reorders these same payloads/forward
references without changing Effect order. 03 adds exact >machine-int quanta, separate Measures,
opening Event designation rather than duplicate quantity, UTF-8/quoted/newline/empty memos and
provided-empty versus not-supplied. 04 deliberately drops only 01's original Event while retaining
its dependents; expected whole refusal, never reference stripping or ancestor salvage.

Previously earned owners inspected: `test/relation_tests.ml`, `test/discharge_tests.ml`,
`test/current_query_tests.ml`, `test/current_quantity_tests.ml`, `test/validity_history_tests.ml`
and `application/open_relations.mli`. Manual arithmetic/reference expectations use their existing
laws, not a new model/test harness. Collection states do not imply real-world completeness;
request origins are not full candidate/base receipts or Saved. Missing other families/config/
receipt scope remains unresolved; no full-household schema or migration parity claimed.

Executed checks: one-off lexical quotation/parenthesis balance only; 01/02 identical atom/string/
delimiter MULTISETS (not tree equality/semantic proof); 01/04 exact diff of intended Event loss;
manual payload/reference/conditional arithmetic review; local links/whitespace and exact main
50/lock unchanged; all tracked code/interfaces/tests untouched. No new S-expression parser
installed/implemented; no AST/schema decode, DTO/writer/serializer, readback/roundtrip/admission/
refusal execution or fresh main-suite result is inferred. No implementation, dependency changes, private reads/exports,
upstream execution/build/copy, original writes, cleanup, migration/cutover or push. Next is user
review, not auto-continuation into the previously proposed codec work.

## Stopped private representation comparison

At clean 21ca9c1 user confirms the exact operational data root and cooperative stopped capture.
D/P/R/source scope/instruments recorded before access. One ignored native OCaml consumer calls
EXISTING Envelope/Read; no sibling execution/build/source copy, new dependency/model or
canonical/semantic-admission parser, parallel maintained harness or broader failure campaign. Fatal 8/9/11/strict sequencing kept.
Residual risk is acquisition/field correspondence, not a newly claimed arithmetic law.

Before private access, seven fresh synthetic controls reused the existing LOAM input fixture:
exact household copy with absent metadata preserved; exact present metadata; existing-target
refusal retaining sentinel; deliberate source change after copy; malformed frame; missing current
household; symbolic-link file. Expected refusals produce no new complete marker; artifacts remain.
Reader refusal never becomes empty/zero; no legacy/current-prev fallback or original writer lock.
Capture uses O_RDONLY, regular/canonical path checks, descriptor/path metadata comparison, full
copy readback and repeated full source bytes/metadata after copying and before scoped completion.
Absent metadata stays absent, not an empty file/default scale; opaque/unrecognized sections retain
all bytes. A 32 MiB per-file review budget refuses excess; it is not a storage/domain range limit.

Actual acquisition observed no named LOAM process and assumes cooperative stopped writers;
this is NOT hostile-race exclusion/live snapshot isolation. Metadata comparison excludes atime,
which read-only access may update. Scope is current household.loam + config/measure-presentation.tsv
and their directory/presence states, not every external catalog/config, historical deployment or
backup. Existing native profile ADMITTED the supplied image's Actual/four-support/origin scope;
other payload semantics/scale decoding are NOT thereby admitted. No household quantity answers
requested or emitted.
No claim about deployed binary/source equivalence, actual unused fields or full-family parity.

The same existing synthetic admitted fixture exercised excerpt/illustration rendering first.
Private view then pairs full selected Event rows (or explicit no-example) and original/child
correction references plus an independent observation/cut with fact-oriented illustrative text.
Encounter order chooses examples, not chronology/currentness. Effect multiplicity/identity roles,
exact raw quanta and optional metadata are not summed/normalized; occurrence revisions remain
separate from Event corrections. Unknown/unsupported render records refuse, not disappear.
Unselected parts remain in the complete captured household. No new grammar decoder, all-field
roundtrip, canonical encoding, lossless full extraction or migration is earned by these views.

Raw copies/inventory/views and incomplete synthetic controls remain in ignored
`scratch/canonical_evidence_review` (private directories 0700/files 0600). No private quantities,
IDs, dates, names, counts, fingerprints or raw errors emitted/committed; only generic boundary
outcomes reported. One same-host scoped copy is not off-host backup, restore or durable Saved.
Pinned sibling source/doc hashes/revision/clean status, main exact 50/lock and all tracked code/
interfaces/tests unchanged; documentation links/whitespace checked. No main-suite rerun inferred;
compile/focused controls concern this ignored native consumer only. No original write/recovery,
cleanup, synchronization/dual authority, migration/cutover, UI/store adoption, publication or push.

## Explicit synthetic initial quantities

User reprioritizes ordinary record/reopen/correct/backup before interchange, not full LOAM parity.
D/P/R and selected instruments recorded at clean 591f6d5 before code; reuse the SAME ignored
native consumers/checks, existing exact/currentness/support/receipt/backup owners and independent
literal initial/expected quanta. [Architecture](ARCHITECTURE.md#client-access-direction) owns scope.

Both stock OCaml 5.3/Notty and isolated OxCaml/Bonsai builds, pure/view smokes and native connection
suites pass: explicit signed/zero/180-bit quantities in all four Measures and both locations, two separate
empty-cut groups, no invented Events, missing/duplicate/syntax/precision refusal before target
effects, and admitted-but-incomplete/extra-group profile refusal. Custom initial quantities survive
expense/income/transfer, cold non-last correction with an older date, retained original support,
complete backup verification and fresh restore. Existing old-seed UNKNOWN/changed-support/unsupported
shape, stale/conflict/replay, OLD/NEW uncertain receipts and backup/refusal/kill controls still pass.
Both CLIs pass 18 malformed/partial/duplicate/probe controls with exact nonzero exits and absent
targets; two existing-target controls preserve complete original files. Wrapper init + opposite
compiler cold-read checks match complete bytes/summaries despite reversed currency argument order.
Default complete proposals are byte-identical across stock/Ox and to preserved baseline binaries.

Ordinary @all FIRST failed because root Dune included the isolated experiment and requested
missing Parsexp. Excluding `experiments` alongside `scratch`, with explicit local --root in trial
CI/docs, restores main 175 expect/four cram checks; release @install also passes without changing
the exact 50/lock or installing anything. Main workspace discovery excludes both trials;
explicit isolated target discovery still lists codec_trial.exe. This is NOT an executed isolated codec build or CI result.
Two initial raw-log attempts via `rtk test sh -c` invoked the native UI without its test arguments
and refused for lack of TTY before store effects; retain these failures. Direct native fresh-v3
runs pass with full raw evidence, not those failed wrapper runs. Main first-failure/filter logs,
raw final checks, source diffs/images and originals remain ignored in `scratch/tui_comparison_review/initial-v9`.
Store/Backup/Locale hashes, main engine/interfaces/tests, default seed and full proposal bytes
remain unchanged. No operational/current-user input read/written, sibling execution/source copy,
new dependency/model/harness, canonical codec/store promotion, renderer/key change, PTY rerun,
physical I/O/power-loss/durable Saved, off-device/live backup, recovery or cutover qualification.

## Native Unix I/O failure boundaries

User approves synthetic failure review. Owners/D/P/R/instruments recorded at 27de66d before
changes; previous sources/images retained in ignored `scratch/tui_comparison_review/io-v8/baseline`.
Existing Store/Backup/Recording implementations, engine and support meanings are UNCHANGED.
Both native consumers gain only consumed test-only connection commands before TTY acquisition;
dedicated `io-v8-` scope is checked before payload/fingerprints, publication checks require a
fresh empty synthetic store, and malformed expectations/operations refuse before effects.
Renderers, normal interaction, defaults and publisher checks remain unchanged. A small ignored
Darwin C interposer, built by existing clang with fatal warnings/no new package, is loaded ONLY
in named child invocations. Exact explicitly fresh trial paths and call occurrence select each
error; exact stderr/exit and hit log are required, not an untriggered environment flag.

Native kernel-error controls are deliberately bounded: fsync(-1)/close(-1) return EBADF; the
close probe first successfully closes the owned handle. Child-only temporary RLIMIT_FSIZE=7
and SIGXFSZ handling, restored before return/logging, produce a genuine 7-byte short write then
EFBIG. An existing publication checkpoint removes ONLY that fresh test's prepared head temporary,
so actual rename returns ENOENT while original CURRENT/evidence remain. These are NOT storage
media errors. EIO/ENOSPC are explicitly injected libc return values; partial-space controls
perform a real 7-byte write before injecting ENOSPC. No host disk filling, mount/VM/global
settings, new dependencies, Python, device/capacity or power-loss experiment.

Scope-qualified `io-v8/v3` passes 70 selected paired cases (64 failure + six short-write success):

| Existing owner | Cases, both consumers | Observable outcomes |
| --- | ---: | --- |
| Store -> Recording | 24 | Generation short/error/sync/close, paired cleanup, namespace sync before/after selection, head close, rename, lease close, genuine missing temp; OLD/NEW receipts, retained/frozen pending draft, no blind retry, original bytes/support and cold interruption |
| Backup capture/copy | 26 | Source read+close, parent/target sync, partial write/EFBIG, file sync/close, seal partial write/close, lease close; pre-effect refusal or post-start Uncertain, unchanged source, partial seal refusal, complete ambiguous artifact independently verifies, repeat refuses |
| Restore copy | 20 | Marker write/sync/close, parent sync, file close, CURRENT sync, pre-removal namespace sync, marker unlink and final namespace sync; incomplete cold load refuses, complete marker-blocked target refuses recording, post-removal complete-but-Uncertain target independently reads, all targets refuse overwrite/resume |

Paired primary/cleanup failures retain BOTH causes. Copy failures exit 1 pre-target/3 after
start with empty success stdout. Native connection commands exit 0 ONLY after independently
checking the intended failure, original-byte retention, quantities/support, read-only receipt
resolution and blocked submission. Short-write-only controls keep writing until complete;
whole exact copies/proposals survive. Fresh nonmatching probes in BOTH consumers intentionally
fail that expectation (exit 1, no hit/no success), not a false control pass. First v1 lease-close
probe incorrectly hit an earlier read-only Digest.file LOCK fingerprint; failure/source/image
retained. Selecting only the actual O_RDWR publisher/backup lease handle fixes the instrument,
not Store; fresh v2 passes and scope-qualified v3 repeats all 70 cases. Both scope/reused-root
and malformed-argument controls refuse without writes; final builds also pass the native errno
connection/smokes/exact proposal controls. Source LOCK capture still uses the same held descriptor.

A completed backup after seal close, final directory sync or source-lease close error can
verify without making the failed call successful/durable. Restore final-sync error AFTER marker
removal can leave a complete readable/writable-by-trial target, still Uncertain. No marker
recreation, automatic retry, cleanup, older-world fallback or inference of Saved. Original
source/archive fingerprints stay exact through faults, cold reads and repeated-target refusals.
Existing native mixed/history/180-bit/old Bank UNKNOWN, damage, Busy/lease and process-kill
controls pass; complete stock/Ox proposal bytes equal each other and the preceding backup trial.
Main raw `tools/check` passes 175 expect/four cram; main exact 50 names/versions, lock and
Store/Money/Workbench hashes unchanged. Physical PTY tests are NOT rerun for test-only entrances.
Sources/images/shim/raw main output/exit files/matrix/complete and refused artifacts remain ignored.

Retention review reuses current missing-ancestor/receipt/closed-set controls and previous scale
evidence, not another large workload. The tested mixed family retains 35 complete envelopes,
169,478 total envelope bytes, largest 8,976 bytes. Every selected ancestor remains a required
original/receipt/admission input; deleting it is corruption, not compaction. Decision: retain
ALL generations/originals/receipts and refused artifacts, no automatic pruning/cleanup or new
retention policy. This small observation is not a daily/lifetime capacity budget; existing
100k three-generation measurements do not qualify lifetime growth.

Remaining gaps: real ENOSPC/EIO/short-or-torn media writes, physical close-error descriptor
ownership (the probe deliberately closes it), host/device power loss/F_FULLFSYNC, creation of
ancestor parents, uncooperative namespace loss, explicit recovery/retention, other hosts/Mirage,
off-device backup/security and real recording. Stable cooperative parents and immutable archives
are still assumed; no main storage/format/UI adoption or durable Saved. Revisit before those
choices, not by broadening an errno campaign until green.

## Synthetic closed backup/restore

User approves synthetic backup/restore, not operational adoption. Owners/D/P/R/instruments
recorded before code at clean e581a6e; previous sources/binaries retained ignored in
`backup-v7/baseline`. BOTH native CLIs consume a small outer `backup.ml/.mli`: unchanged Store
family grammar, explicit scoped source/backup/fresh-target paths, no TTY or dependency needed.
Every selected ancestor's whole engine/UI profile and all closed regular files qualify before
target creation. Backup holds publisher-compatible source lease through exact capture/copy/
recheck; LOCK reads via SAME fd, never another descriptor whose close releases POSIX locks.
No source file-content/namespace writes, lost originals, reencoding, guessed support or fallback.

Backup-only seal is last: captured head + exact inventory/length/MD5, accidental corruption
indicator NOT authentication/security/durability. Restore requires nonexistent dedicated store,
own in-progress marker first/CURRENT last, copied full byte equality and whole source/profile
recheck before marker removal. Retained marker blocks Recording/UI publication; existing
store never overwritten/initialized/resumed. Source tokens cannot authorize restored namespace.
Uncaught process death retains artifacts; caught pre-target failure Refused/post-start failure
Uncertain. Failure has no success stdout. Completion before lost acknowledgement may be valid
on independent read, not proof of failure or durable Saved. No automatic cleanup/retry/cutover.

Both native recording consumers pass ALL prior controls and new closed-copy connections:
complete mixed family files/selected quantities/4 Measures/support/original date/route/memo/
corrections, original receipt != current with read-only reconciliation, fresh-namespace refusal
of source token, cold restored-only correction leaving source/archive unchanged, old Bank
UNKNOWN after income and exact 180-bit Bank income. Existing-target/repeated-copy refuses;
missing seal/ancestor, truncation, valid admitted same-length memo mutation, older head with
extra descendants, extra file, symlink, unsupported seal version all refuse before target
creation with no repairs. Unresolved source income orphan refuses, never becomes selected.
Cross-process publisher after ALL LOCK reads is Busy (lease retained); independently held
lease blocks backup without target creation. Source/backup fingerprints remain unchanged.

Native prewrite returned refusal creates no target; three backup post-effect returned errors
are Uncertain, partial seals reject/complete lost-ack seal verifies without Saved, never resume.
Actual new-target PROFILE-directory collision makes Unix open(O_EXCL) return EEXIST and yields
Uncertain/incomplete artifact; this is ONE actual syscall result, not EIO/ENOSPC/fsync/close
coverage. Returned restore error after CURRENT leaves marker/read-only UI with writes blocked.
Two real child SIGKILL controls after CURRENT copy retain unsealed backup and marker-blocked
restored store; no process-survival/power-loss/namespace/device guarantee inferred.

Actual quiet-drained PTY `backup-v7/pty-v2` passes five 100x25 children: Notty ja expense 10,
Wallet->Bank 100, Wallet income 200/Bank income 50 -> native Notty backup/Bonsai verification/
restore -> Bonsai en correct Wallet income to 250, inspect original, add EUR expense 12.34 ->
Notty source unchanged -> second Bonsai backup/Notty restore -> Notty ja correct original
JPY expense to 15/inspect original -> Bonsai ja/en cold reopen. Final twice-restored JPY Wallet
1135/Bank 150/Food 15, EUR Wallet 87.66/Bank 0; original remains JPY Wallet 1090/Bank 150 and
EUR Wallet 100.00. All five exit 0/full stty restored; shell wrapper read-only check and
restore-to-source refuse. First PTY Tcl parameter named `args` nested native argv, causing
argument refusal before backup; retained failure/source/reproduction, rename/fresh v2 passes.
Initial parallel stock build/main check hit Dune's lock, NOT a code failure; serialized stock
build/controls pass. Main `tools/check` passes (175 expect/four cram), exact main 50/lock/Store/
Money/Workbench unchanged; Locale remains pure Stdlib. Final native smokes pass; complete
stock/Ox proposal bytes identical to prior Tab trial, backup checks/restored answers identical.

Source/images/logs/closed archives/partial refusals/killed targets/final PTYs/hashes remain ignored
in `backup-v7`/trial scope. No user's current store or operational payload read/copied/mutated.
[Retained synthetic trial README](../scratch/tui_comparison_review/README.md) owns explicit commands.
Cooperative stable paths, immutable archive ownership and publisher-compatible lease assumed,
not a security sandbox or live/uncooperative/filesystem snapshot. Same-device experiment is
NOT off-device disaster backup; no encryption, real-data use, canonical store/UI/retention
adoption, original replacement/migration, cleanup/recovery, broad syscall/sync/close/space or
power-loss/durable Saved, other-host/Mirage/human IME/performance qualification. These remain
separate bounded decisions; an apparently complete selected file is not enough for recovery.

## TUI Tab order fix

User reports a visible navigation mismatch at Operation/Date (79beac5): BOTH renderers show
Kind -> Date -> Currency, shared Interaction advances Date -> Kind -> Currency. Scope/owners/
D/P/R recorded before code; retain initial Amount focus, layout, stored meaning and guards.
Added an independent literal visible-field witness to SAME native smoke: five routes x4
currencies x2 languages, forward/reverse/wrap/inverse Tab key dispatch, unchanged draft/bytes.
BOTH original-edge binaries fail that check. Corrected only shared focus edges; BOTH final
isolated builds/native smokes and existing geometry/amount/correction/unknown checks pass.
Complete stock/Ox proposal outputs agree; removing only the new success line yields exact
prior income proposal output. Workbench/Recording/Store/renderers/Money/Locale/lock hashes
unchanged; ignored `tab-order-v6` retains baseline/source/image/failure/result evidence.
No user-store read/write/init, dependency change, main test or new physical PTY/failure campaign,
storage/durability/operational/Mirage qualification. [Retained synthetic trial README](../scratch/tui_comparison_review/README.md)
owns restart instructions; revisit if visible form fields/order change.

## Synthetic TUI income

User approves Income in BOTH existing native UIs. Owners/D/P/R/instruments recorded before
code at clean 10c7ec3; baseline sources/binaries retained in ignored `income-v5/baseline`.
Pure Workbench maps explicitly selected Income to `income-source` negative / Wallet or Bank
positive same-Measure ordinary Effects. No Core account/transaction-kind/party ontology,
provider/employment/tax metadata, source origin, income balance/total or support inferred.
Income activity does NOT establish missing Bank support. Both exact supported seed profiles,
init bytes/request, default store, original expense/transfer bytes, correction/currency/route
locks, whole-document refusal and existing Recording/Store owner remain unchanged. Locale
stays Stdlib-only; typed operation/destination collection shared, both palettes unchanged.

BOTH final native builds/smokes pass four currencies x2 receivers x2 display languages:
independently expected per-locus signed quanta, same-Measure two-Effect conservation/negative
counterpart, unrelated-currency invariance, exact 180-bit amounts, original date/amount/memo/
route, explicit source support UNKNOWN, amount/precision/currency/route/stale refusal and
three-operation/destination selection WITHOUT recording. Geometry checks retain original-history
room at 80x25 and small-view behavior. Complete stock/Ox controlled mixed proposal bytes agree
(40 retained Events/20 correction edges), not checksum-only equality. Initial stock compiler
refused `effect` as a 5.3 reserved test-variable name while isolated Ox 5.2 accepted; renamed
those variables without compiler or warning suppression, failed evidence retained.

Extended SAME native recording checks pass in BOTH consumers, retaining all prior expense/
transfer/currentness/receipt/refusal cases. Income covers all four currencies/both receivers,
cold bytes/original amount/route/memo/date (including 1900 correction, not inferred chronology),
non-last lineage selection, old Bank/source UNKNOWN after income, richer receiver/raw changed
correction route refusal, and cold 180-bit EUR Bank credit with Wallet unchanged. Synthetic
Generation-ready OLD/Selected NEW returned-error checkpoints retain exact frozen income forms,
block destination editing and reconcile read-only with unchanged file fingerprints. OLD stays
pending; NEW independently reloads selected Bank credit, preserving unknown source support.
No actual syscall/entropy failure or power-loss qualification follows.

Reused quiet-drained real PTY `income-v5/pty-v1` passes eight children at 100x25: Notty ja
expense 10 + Wallet income 1000/Bank income 500 -> Bonsai en correct both to 1200/600 plus
expense 20 and transfer 100 -> Notty ja correct NON-last Bank income to 650, inspect both
retained originals, refuse EUR 1.005 without rounding and record EUR Bank income 12.34 ->
Bonsai en/ja correct EUR to 15.01/inspect original/show-hide full detail. Final JPY Wallet
2070/Bank 750/Food 30; EUR Wallet 100.00/Bank 15.01; other currencies unchanged. OLD income
uncertainty/No receipt visibly remains pending in Notty, cold Bonsai interruption blocks
recording. NEW Bank income uncertainty visibly appears in Bonsai BEFORE Ctrl-R; receipt check
and cold Notty show Wallet 1000/Bank 25. All eight exit 0/full stty restored. ORIGINAL eight-child
transfer and nine-child expense PTYs also pass on fresh roots; no previous store reset.

Main `tools/check` passes (175 expect/four cram); exact main 50/lock, Store and Money hashes
unchanged. Final native recording/smoke checks pass. Same native-control and final PTY store
cold answers/generation/request/session bytes agree across stock/Ox consumers. Source/image
hashes, compile error, outputs, fresh synthetic stores and terminal traces remain ignored under
`income-v5`/trial scope; no current user's store or operational payload was read/copied/mutated.
[Retained synthetic trial README](../scratch/tui_comparison_review/README.md) owns launch/next actions.
No real-data use, FX/richer income categories, canonical store/UI adoption, migration, backup/
restore/recovery/cleanup, actual syscall/device/power-loss/durable Saved, human IME/grapheme/
resize/latency, other-host or Mirage qualification. These remain separate decisions/work.

## Same-currency synthetic TUI transfer

User approves Transfer in BOTH existing UIs and retaining their look with long internal IDs
moved to explicit detail. Owners/D/P/R/instruments recorded before code at clean 36ae42f.
Previous sources/binaries retained in ignored `scratch/tui_comparison_review/transfer-v4/baseline`.
No new main code/package/compiler/framework, storage layout, operational input or Mirage build.

Pure trial Workbench now maps Expense Wallet->Food and Transfer Wallet<->Bank onto EXISTING
two opposite anonymous signed Effects. One currency supplies BOTH Measures, exact positive
input/no FX; self-transfer refuses. Route is reconstructed from complete retained Effects,
not memo/translated label or a new Core transaction-kind/account ontology. Currency/route
changes during correction refuse at both form and direct Workbench entrances. Every retained
row, supported seed/support and correction edge still qualifies; no partial-row salvage.
Fresh explicit synthetic init adds Bank zero origins for all four versioned currency Measures;
older supported seed bytes remain readable unchanged with Bank UNKNOWN, never filled/migrated.
Transfer/nonzero/net-zero activity still cannot supply missing independent Bank support.

Both frontends share Kind/From/To collection, independent selectors and localized typed states.
Typed amounts and corrections cannot silently change operation/direction. Correction of a
non-last root now keeps its lineage selected rather than jumping to the final root (a concrete
connection bug found while adding mixed rows). Normal view omits generation/request/Event IDs;
Ctrl-G shows full identities, preserving draft/bytes/pending/receipt gates. Session diagnostics
retain full IDs; an ID is NOT a content hash, chronology or proof of durable recording.
Shared Locale remains Stdlib-only, no Unix/Async/widget imports. Palettes unchanged; compact
layout/geometry leaves original-history room at 80x25 in both languages/operations. No human
IME/grapheme/live resize/large-list/latency or permanent toolkit verdict.

Reused native pure smoke passes 4 currencies x2 directions x2 display languages: exact opposite
signs, independently expected per-locus quanta and same-currency conservation, unrelated-currency
invariance, cents/180-bit transfers, route/amount/memo originals, currency/stale/route/self refusal
and selector-vs-recording boundary. Complete controlled stock/Ox mixed expense/transfer proposal
outputs are byte-identical (24 retained Events/12 correction edges), not checksum-only equality.
Reused native recording checks pass in BOTH binaries: all prior expense/receipt/load/refusal
controls, JPY/EUR both-direction cold transfer/correction, mixed original bytes/date/route/memo,
non-last expense correction, normal/detail ID correspondence and original receipt/current reload.
Explicit older synthetic seed remains byte-readable with Bank unknown after transfer AND return
to net zero. Whole-admitted richer balanced multi-Measure shape and raw changed-route correction
refuse the UI profile. Transfer Generation-ready OLD/Selected NEW returned-error checkpoints
retain frozen exact drafts/routes; read-only reconciliation has unchanged file fingerprints,
OLD stays pending/NEW independently reloads BOTH endpoint quantities. Actual syscall/entropy/
power-loss failures are NOT injected or qualified by these connection controls.

Actual fully quiet-drained transfer `pty-v2` passes eight native UI children at 100x25: Notty ja
expense 10 + Wallet->Bank 100 -> exit -> Bonsai en correct transfer to 120, Bank->Wallet 20,
independent From/To picks/self-refusal and another deposit 10 -> exit -> Notty ja correct the
NON-last withdrawal to 25, inspect original reverse route, add EUR 12.34 -> exit -> Bonsai en/ja
correct EUR to 15.01, inspect original route/memo and show/hide full ID detail. Final JPY Wallet
885/Bank 105/Food 10; EUR Wallet 84.99/Bank 15.01; other currency quantities unchanged. OLD
transfer uncertainty/No receipt/blocked route displays in Notty, cold Bonsai interruption blocks
recording; NEW uncertainty displays in Bonsai BEFORE Ctrl-R, cold Notty reads Wallet 975/Bank
25. All eight exit 0 and full stty matches after canonical resume. Initial transfer `pty-v1`
FAILED a detail assertion because one-frame draining left older Notty frames queued. Retain its
trace/store; quiet-until-no-output draining fixes the instrument, not a relabeled UI failure.
The ORIGINAL nine-child expense PTY consumer also passes on freshly named synthetic stores.

Main `tools/check` passes (175 expect/four cram). Exact main 50/lock, Money source/policies and
original reuse Store hashes unchanged. Final native smoke/geometry/recording checks pass;
same-store stock/Ox cold quantity/generation/request/session outputs are byte-identical.
No current user's trial-store or operational payload was read/reset/copied; all controls use
fresh self-generated synthetic roots, and previous sources/images/trials remain intact. Sources,
images, native stores, failures, logs, PTYs and hashes stay ignored in `transfer-v4`/trial scope.
[Retained synthetic trial README](../scratch/tui_comparison_review/README.md) owns launch/next
work; default store path stays unchanged, fresh Bank zero support requires EXPLICIT new init.
No real-data recording, migration, main canonical storage/UI adoption, recovery/cleanup,
backup/restore, actual failing syscall/namespace/device/power-loss/Saved, other host or Mirage
qualification. Broader routes, income and changing a correction's route require a new bounded
entrance/decision; no missing support may be guessed for product convenience.

## Synthetic TUI record/reopen/correction

User approves connecting BOTH existing native trials to the EXISTING ignored Unix text
publication consumer; bounded owners/D/P/R/instruments recorded before code at clean 492efde.
Current source/binaries/controls retained in ignored `scratch/tui_comparison_review/recording-v3/baseline`;
main exact 50/lock and `text_publication_reuse/store.ml/.mli` remain byte-unchanged. No new
package/framework/compiler, operational input, canonical store/layout, recovery or Mirage build.

Pure Workbench now prepares opaque proposals and reconstructs the WHOLE narrower synthetic
expense UI profile from an admitted document. Explicit original seed/support, every retained
expense's Effects/date/description and currency-bound correction path must fit; unsupported
rows, absent descriptions, old `jpy`, changed support or richer shape refuse wholesale.
Reopened trial Event allocation checks ALL retained identities; dates/root order are not
chronology. Ctrl-P cycles actual path originals with original ID/date/currency/amount/memo.
Locale remains pure Stdlib/no Unix/Async/frontend dependency. Shared display meanings do not
translate identities/memos or establish a universal keyboard convention. Broader language
switching/preferences/other UIs are deferred; this does not qualify a Mirage publisher.

A small consumed outer Recording owner symlinks/uses the unchanged Store. Explicit init only;
missing/invalid read never creates, repairs or falls back. Only dedicated trial-directory direct
children are allowed, root symlinks/outside roots refuse (cooperative stable namespace, NOT an
adversarial security service). UI publication retains current snapshot/base gates. Pre-effect
refusal, Conflict, Busy, mismatch, visible-unacknowledged selection and post-effect uncertainty
stay distinct. Success clears amount/memo to prevent immediate accidental repeat. Uncertainty
retains exact request/base/candidate and freezes edit/write; Ctrl-R reconciles read-only, then
separately reloads currently selected evidence. An original replay/receipt never becomes current
by itself. No receipt remains uncertainty, NOT failure or retry permission. Unexpected cold
files conservatively block writes without cleanup; selected evidence stays available, not empty.

Focused connection checks consumed by BOTH native binaries pass: 4 currencies x2 languages,
exact cents/signed 180-bit cold quantities, original bytes/8 Events/4 edges/date/memo, explicit
init/read-only scope/unsupported whole-profile refusal, failed reload/draft retention, stale
correction after refresh, Conflict, original replay after later correction and CURRENT reload.
Captured pre-write returned error leaves files unchanged/no pending result. Generation-ready
OLD and Selected NEW returned errors preserve form/model/uncertainty; no blind repeat. Read-only
reconciliation has identical before/after files; OLD/no-receipt and cold orphan block writes;
NEW/observed receipt independently reloads later selected correction if present. These are
connection/checkpoint controls, not new engine or syscall/power-loss qualification. Initial
native v1 conflict check FAILED: deterministic request IDs collided across sessions and yielded
mismatch rather than Conflict. Fixed with outer 12-byte Unix entropy request allocation; entropy
failure refuses and Store still checks collisions, not a production uniqueness service. Native
v2/v3 checks pass; initial failures/stores retained, not deleted or relabeled.

Real drained `pty-v4` traces pass: Notty ja EUR 12.34/memo -> exit -> Bonsai en reopen/correct
15.01, language switch, USD cent and ILS/JPY precision refusals/additions -> exit -> Notty ja
reopen/recorrect EUR 16.00 -> exit -> Bonsai en/ja cycles BOTH originals 12.34/15.01 and their
memos. Final wallet JPY 998 / EUR 84.00 / USD 199.99 / ILS 298.77, source checksum equal.
OLD uncertainty/No receipt/blocked edit visibly render in Notty; cold Bonsai shows read-only
interruption. NEW uncertainty visibly renders in Bonsai BEFORE Ctrl-R receipt observation;
cold Notty reads 990. Missing-store UI refuses before terminal acquisition, exit 1/no store
creation. Eight successful UI children exit 0; all nine full stty checks pass after canonical
resume. Earlier PTY v2 was functional-only (empty trace capture), v3 had undrained/coalesced
Bonsai transitions: preserve them, but only drained v4 qualifies visible intermediate warnings.
No IME/human editing/large-list/latency/SIGKILL/power-loss verdict follows from these traces.

Final stock/Ox pure proposal outputs and cold same-store quantity/receipt/session outputs are
byte-identical; checksums are observations, never an admission/currentness/security gate.
Main `tools/check` (175 expect/four cram) passes; exact 50/lock/source Store hashes unchanged.
Original paired/money/publication artifacts remain. TRY: `try-ui init` ONCE, then `try-ui notty ja`
and `try-ui bonsai en`; [Retained synthetic trial README](../scratch/tui_comparison_review/README.md)
owns current launch/next work. Sources, images, hashes, logs, native stores and PTYs stay ignored.
Qualified ONLY synthetic native normal-exit loops and named controls on current macOS; no main
storage/UI adoption, live/off-device backup/restore, recovery/cleanup, actual failing syscalls,
namespace/device/power loss, durable Saved, real data, other host or Mirage qualification.

## Paired Notty / Bonsai_term synthetic draft UI trial

User explicitly requests trying/building BOTH desktop candidates, informed of OxCaml scope;
HANDOFF records question/owners/D/P/R BEFORE code. CURRENT 0438384 engine, Darwin x86_64.
Ignored `scratch/tui_comparison_review` now has TWO runnable native draft workbenches, not a
browser imitation, adopted UI or main writer. `workbench.ml` owns ephemeral trial Event IDs,
complete admitted documents/proposals and existing narrow exact/presence/unknown projections.
Shared `interaction.ml` owns the SAME tiny form/focus/list/scalar/paste controls, not household
arithmetic. Notty uses its own I renderer/Unix event loop; Bonsai_term uses its own View renderer,
typed event conversion, real Bonsai state machine and Async lifecycle. No copied old engine,
parallel model/oracle, Python bridge, protocol framework or generated payload. Both retain
original source/correction edges and never claim Saved; exit loses all ephemeral candidate work.

Dependency preflight: frozen default ac27950e5eac6c981ad809dff370c937820b7893; Ox registry
f1bd228dda31430bf6271f0f9adb2e604c6957ca. Direct Notty uses notty-community 0.2.4 to compare
the same family of renderer as Bonsai, not silently adopted main Notty. Isolated system-5.3.0
compiler aliases: nine baseline packages + seven additions, 16 actual total. Main compiler,
exact 50 versions/lock/dependency directions unchanged. Bonsai_term is pinned to source
2457232d3aa144fb887a053748a920544db60f72 / v0.18~preview.130.106+341; its closure conflicts
with Ox 5.4, so the isolated consumer uses OxCaml 5.2.0minus40 / Base v0.18 preview, 249 ACTUAL
installed packages including empty guards (initial simultaneous dry solve planned 254).
First solve timed out at 60s; one precise 120s retry succeeds, actual compiler/library builds
succeed. Current engine SOURCE SYMLINKS compile in that scratch-only Dune root without source
changes: NOT full main-engine qualification on another compiler. No OS/global install, main
lock/package changes, VM/Lean/operational inputs, canonical storage/UI/runtime adoption or push.
Trial trees ~8.7GiB, binaries ~4.6/53MiB stock/Bonsai: setup observations, NOT runtime memory/
latency/usability evidence. Both link native libraries only; pinned package/link/hash records,
source/build logs/export and failed controls remain ignored. No unreviewed cleanup.

Same controlled workbench checks pass in BOTH: synthetic wallet 1000 -> append 990 -> correction
985, retained byte prefix/original Event/memo and explicit edge; 180-bit positive quantity;
zero/exponent/invalid-date refusal without lost admitted draft; stale row refusal; scalar
Backspace, bracketed-paste control rejection/no implicit submit; known presence and unknown
not scalar/zero. Render width for Japanese '財布' is four; 80x30 and narrow geometry checked.
Exact complete stock/Ox controlled proposal/answer output compares byte-identically; observational
MD5 checksums are NOT a security/currentness gate. No new main tests/framework added by habit.

Real `/usr/bin/script` PTYs at 100x30 pass UTF-8 key input, Tab, Enter, Ctrl-E correction,
Ctrl-U replacement amount and Ctrl-Q in BOTH. Final wallet 985/source checksum identical;
child exits 0. Raw immediate `stty -g` probes v1/v2 report only lflag PENDIN 0x20000000,
not missing user flags: local SDK defines it as pending-input STATE; Darwin tty.c sets it
on canonical-mode restoration and ttypend() clears it when input resumes. v3 compares FULL
stty state after one normal canonical input: exact match for both (v4 repeats with final
source/image hashes). Non-TTY mode refuses in both with exit 1 and no answer stdout. Failed probes remain,
not a relaxed all-flags comparison or a patched vendor. The common launch shell owns terminal
restoration and propagates failure; SIGKILL/exotic terminals/OS-wide cleanup are unqualified.
These PTY traces inject already-converted Unicode, NOT actual macOS IME conversion tests.

Try from repository root in a real >=64x25 terminal, SYNTHETIC input only:

```sh
./scratch/tui_comparison_review/try-ui notty
./scratch/tui_comparison_review/try-ui bonsai
```

Quantity is initially focused: 10, Tab, synthetic memo, Enter; then Ctrl-E/Ctrl-U/15/Enter.
Ctrl-N new, arrows list, Tab/Shift-Tab focus, Ctrl-Q quit. Date is a visible fixed synthetic
value, not a hidden clock; quantities remain jpy quanta, no invented display-scale convention.
Ordinary main check still passes 175 expect/four cram; pinned format/whitespace and source/50
preservation checks pass. Choice stays OPEN: Bonsai ALSO has app-managed focus; no rich form
components, per-field incremental optimization/speed or more maintainable architecture inferred
from this small state machine. Human IME/keyboard feel, grapheme/cursor editing, resize interactions,
large-list performance, mouse/accessibility and persistent record/reopen remain next gaps.
No real data was needed; user feedback on BOTH is next, not automatic Notty/Bonsai adoption.

## Bilingual four-currency draft UI

User approves extending BOTH synthetic UIs with ja/en display and JPY/EUR/USD/ILS selection/
exact decimals; task/owners/D/P/R recorded BEFORE code at d865bfa. Human feedback: Bonsai looks
slightly richer (color/style), not a permanent choice or performance conclusion. Existing
paired source/image hashes and controls retained in ignored `paired-v1` before editing.
No dependency/compiler/framework/model/store changes: main 50/lock unchanged; same isolated
Notty/stock-5.3 and Bonsai/Ox consumers of CURRENT engine source, not another authority.

New ignored `money.ml/.mli` is a concrete text-to-quanta adapter, NOT balances or a currency
ontology. Explicit TRIAL policy announced: JPY 1 yen/quantum; EUR/USD/ILS 0.01/quantum. FRESH
Measure IDs `ui-money-v2:CODE:10^-SCALE` encode code/version/scale; old jpy is not recognized or
reinterpreted. Fresh explicit synthetic support: wallet JPY 1000, EUR 100.00, USD 200.00,
ILS 300.00, each food zero origin/pantry presence; no absent-data zero. ASCII stable loci have
ja/en DISPLAY labels, never translated identities. `locale.ml/.mli` renders closed typed UI
status/errors; memos/dates/quantities/currency are unchanged by language switch. No translation
service, global region defaults, Hebrew/RTL or main CLI localization is claimed.

Dot-decimal syntax in BOTH languages: JPY integer only; others 0..2 fractional digits (one
padded exactly). Positive expense inputs only; signed engine/answer quantities remain unbounded.
No float/rounding/grouping/trim/symbol/exponent/comma/sign coercion. Invalid grammar, excess
precision and nonpositive amounts have separate localized refusals. Too many digits refuse
EVEN trailing zero (`1.230`), not silently round. Currency switch refuses nonempty amounts or
ANY correction; direct Workbench correction also binds owner/currency. Start a new empty draft
rather than reinterpreting 12 as another currency. Entire document/proposals still use CURRENT
engine admission; UI never computes balances or invents support/FX. Rate/home-currency valuation,
production scale/catalog/store/format/migration/recorded receipt/Saved remain separate decisions.

Both native 4 currencies x2 languages smoke checks pass: append/correct, independently expected
integer quanta and unrelated-currency invariance; exact cents/signed display/180-bit decimal
roundtrip and engine quantities; old jpy refusal, invalid grammar/date/stale/currency refusal;
retained 8 Events/4 edges/original memo/base prefix; language preserves draft/bytes/memo, current
refusal relocalizes, unknown/presence stay scalar-free/not zero; paste no-submit and 4x2 renderer
geometry. COMPLETE controlled stock/Ox proposal/answer outputs compare byte-identically. Main
175 expect/four cram and pinned formatting/whitespace pass; original paired hashes/exact main
50/lock preserved. No added main framework/test campaign or alternate-compiler general claim.

Real PTY trace in BOTH starts English, selects EUR, enters 12.34/Japanese synthetic memo,
corrects to 15.01 with currency-change attempt refused, switches language mid-draft, adds USD
0.01, refuses ILS 1.005/JPY 2.0 without changing admitted quantities and then accepts 1.23/2.
Final wallet quanta JPY 998, EUR 8499, USD 19999, ILS 29877 (human 998/84.99/199.99/298.77),
same complete-source checksum; exits 0, full terminal state matches after canonical input resumes.
Bad language refuses BEFORE terminal acquisition, exit 2/no answer stdout; non-TTY exit 1/no
answer stdout. `money-v2` retains logs/source/image/link/package/lock/snapshots/PTYS. MD5 is an
observational checksum, not a security/publication gate. Actual IME conversion, grapheme/cursor
editing, rich widgets, live resize/long-list performance/RTL/other hosts/storage remain unqualified.

Launch `./scratch/tui_comparison_review/try-ui notty ja` or `.../try-ui bonsai en`. Ctrl-L toggles
language; Ctrl-K cycles currency on EMPTY new draft (Ctrl-N); Tab/Shift-Tab focus including
currency Left/Right; Ctrl-E correct/Ctrl-U clear/Enter validate/Ctrl-Q quit. Same original palettes,
no automatic framework adoption; compare both with human input next. No real data was accessed.

## Friendly projected quantity answers

User delegates small explicit household questions without a required AI/model. HANDOFF records
owners/D/P/R and bounds before code. `Current_quantity_answer.project` copies only the permitted
values/support family from an existing outcome; no lookup/arithmetic/source weakening. Japanese
Presentation consumes only this distinct opaque projection. Existing CLI `--summary` is the
concrete consumer; owner `--explain`/ordinary inspection remain separate. This does NOT implement
principal/coordinate authorization, a public protocol, sandbox, live capture or production service.

Four focused existing expect connections cover all exact support families/coordinate roles,
negative 180-bit quantity, known zero vs presence/net-zero-stale/unknown and owner-evidence positive
controls; native LOAM success omits request origins/keys/text/opaque sections, while six text and
seven native input-failure controls retain original 1/2 classes and no partial stdout/raw diagnostics.
Existing planner tests now cover competing/repeated views before acquisition. Existing cram tests
both CLI paths, Japanese 0/4/3 outputs, duplicates, unsupported/source/support/read errors, and
byte-equal inputs. Public scoped compiler clients accept the narrowed answer and reject forged
exact, raw-premise access, presence arithmetic and nonexistent source access. These check nominal
abstraction, not unsafe OCaml or hostile in-process/native code; projections remain sensitive.

macOS `tools/check` and forced package `runtest -p bakhlo` pass (170 expect cases, retained campaigns,
four cram), as does release `@install`. Optional pinned formatting passes; main compiler/50 lock
and dependency direction unchanged. A missing renderer result annotation made an error constructor
unbound, and one deliberately empty expect snapshot was filled after review. No warning suppression,
blind expectation promotion, new model/framework/Python/campaign/dependency, original data read,
sibling build, Linux/Mirage/proof/storage replay or recording/persistence qualification. Typed
unknown guidance remains a check suggestion, not a claim that the starting balance is missing.

## Terminal quantity evidence explanation

HANDOFF records the bounded continuation review. Application now retains exact admitted correction
paths and each assertion answer's owning cut; pure Presentation consumes them without changing
source/support gates or existing typed outcomes. Three focused existing expect cases connect
reversed declaration order/multihop paths, terminal keyed/anonymous multiplicity and Event-local
positions, independent assertion cuts (99/208), unknown/net-zero/presence versus explicit zero,
opening witness, 180-bit signed quantity and escaped exact identities. Cut correspondence reuses
the earned original-Effect oracle; existing retention helpers now compare paths too. The existing
10k-node lineage check additionally verifies every traversal edge in both declaration orders.

macOS native `tools/check` passes (163 expect cases, retained campaigns, four cram suites), as does
release `@install`; optional pinned formatting and exact diff/whitespace review pass. Initial
missing implementation, a test's nonexistent `Quantity.is_zero` name, and two deliberately empty
new expect snapshots were resolved; no admission weakening, warning suppression or blind promotion.
No dependency/lock change, new model/framework/campaign, private input, sibling build, Linux/Mirage,
proof/storage replay or live acquisition qualification. CLI consumption is qualified separately below.

## One-image quantity CLI questions

Stage 2 starts from clean d2b59f4 and the existing pure explanation/163 expect evidence. Both
explicit-file commands now accept optional `--explain` and one or more coordinate pairs. A small
CLI-only abstract nonempty planner/renderer shares identical pair/exit mechanics, not reader
profiles or Core meanings. Deterministic owner review confirms each shell branch plans ALL
questions before its ONE `read_text` call and each evaluator invokes its own `Read.of_string`
ONCE before batch rendering; no instrumentation harness or live-capture claim was added.

Three focused existing expect connections cover both planners' late-pair refusal/exact identities,
ordered duplicate/exact/presence/unknown results and 0/4/3 precedence in both mixed orders, plus
native explanations/whole unsupported/missing/source/support refusal. Existing cram adds both
synthetic read-only examples, Measure separation, duplicate rows, explanation paths/Effect keys,
late syntax before missing-file acquisition, whole-read refusal with no partial stdout and
byte-equal inputs. Single non-explained golden outputs remain unchanged. Terminal helper consumes
the existing typed outcomes once per question; no new quantity arithmetic or subtotal.

macOS native `tools/check` and forced package `runtest -p bakhlo` pass (166 expect cases, retained
campaigns/four cram), as does release `@install`. Optional pinned formatting, main installed count
50 and unchanged dependency/lock review pass. One test omitted Base's required `may_overlap` label;
a new deliberately empty expect snapshot was filled after exact evidence review. No source/support
weakening, warning suppression, new model/framework/Python/dependency, private data, sibling build,
Linux/Mirage/proof/storage replay or acquisition qualification. Fresh original reads still require
an explicit human question and separate coherent-capture owner/evidence.

## Readability and optional formatter qualification

User approved entry-document cleanup and evidence-triggered maintenance decisions, not DRY/
performance refactors. HANDOFF recorded D/P/R before code. README 184 -> 68 lines; navigation
links retain historical negative controls. Related-work triggers now cover invariant lookups,
empty commands, parser/fixture retirement, ID abstraction and measured reconstruction costs;
not an automatic calendar-based refactor or dependency permission.

Adopt **optional** ocamlformat 0.29.0, target 5.3.0, default/100 columns, no comment/docstring
rewrite. Separate ignored tool root/switch, frozen registry ac27950e5eac6c981ad809dff370c937820b7893,
39 selections, source archive sha256 dac77f0a957ae782bb4b869b07b9803a872a34f8c1eae8901b42d21b623c9db5
(MIT plus vendored LGPL exception). Main OCaml 5.3.0/Dune 3.24.2/exact 50 and lock unchanged;
no global/compiler/editor/CI change or vendor patch. Setup is tied to the existing local
compiler, not a newly bootstrapped platform closure. Initial borrowing attempts selected the
cached/global 5.4.1 and were honestly refused; incomplete compiler aliases then exposed global
`.opt`/Unix linkage and missing ocamlmklib failures. Complete ignored native-compiler aliases
resolved them, with actual 5.3.0 checks and vendor configuration validation, not version spoofing.
[Development](DEVELOPMENT.md#optional-formatting) owns the working recipe; no vendor-test claim.

Five representative Event/ID/LOAM parser/UTF-8 expect/interface samples passed unchanged native
AST comparison and repeatable layout. Reused the earlier OCaml compiler-libs AST instrument,
adding interface parsing in ignored scratch only: all **137** tracked ml/mli trees identical
with locations erased, including exact literal/doc attribute contents. Equal control passes;
changed constant refuses. This is bounded syntax-tree evidence, not household or formal
refinement proof. Dune-only whitespace diff reviewed; fatal policy/strict sequencing still
exercised. Long tracked lines >120: 672 -> 29; >200: 28 -> 0; remaining literals/comments are
not rewritten merely to meet a column count. Payload example hashes unchanged (synthetic only).

Formatter clean check/reapply and wrapper missing/wrong-version refusal passed; Dune's promoted
-diff exit 1 is accepted ONLY after a clean subsequent @fmt check. Main `tools/check` (160 expect,
retained campaigns/four cram) and release @install passed without formatter in the main switch.
No new framework/campaign, source semantics, operational read, Linux/Mirage/storage/proof replay.
One cached clean @fmt check observed 0.53s real / 0.12s user / 0.08s sys on this host; not a
cold-build or universal latency target. Setup paid the separate 39-selection download/build
and the explicitly retained retries above. Formatting stays separate from semantic refactoring;
tool upgrades need a representative review.

## Scoped native LOAM-input reader

Question/owners/D/P/R recorded before code in HANDOFF. New pure `bakhlo.loam_read` decodes
one supplied HouseholdImage v2 directly in OCaml; explicit-file `inspect-loam-quantity`
consumes retained input/origins plus existing opaque quantity image. [Architecture](ARCHITECTURE.md#scoped-native-loam-input-read)
owns scope and [interfaces](../loam_read/read.mli) refusal staging. Core, quantities, source/
support gates, manifests/lock/tools/compiler policy unchanged; no external dependency, Python,
generated OCaml data, new framework/oracle/model/campaign or operational payload fixture.

Three focused existing-ppx_expect cases address new risks: explicit Unicode scalar lengths
(two multibyte glyphs, combining scalar, four-byte scalar, NUL/opaque empty section), original
bytes/section order; direct mapping of every representable Actual family and independently
supplied origin/opening/assertion/presence/correction/date history; exact whitespace identities
and superseded request origins; 990/160/7/0 and assertion delta -10 with earned original-Effect
oracle connection, signed 180-bit quantity and v1 anchor lift. Typed read refusals for missing
coverage, settlement, repeated request, broken source, support overlap, duplicate section,
trailing/invalid UTF-8/truncated scalar extent and overflowing length precede lookup. Terminal
exact/presence/unknown retain 0/4/3 and stream separation. Existing CLI help golden updated.

Direct CLI file reads of the own synthetic LOAM-input example yielded wallet/jpy 990
(asserted 1000/delta -10) and food/jpy zero-origin 10; help/scope visible, no operational input.
Native library/CLI and `tools/check` passed on qualified macOS/OCaml 5.3.0: 160 expect cases
(three added), retained campaigns and four cram suites. Dev and release `@install` passed;
strict sequencing/fatal 8/9/11 preserved. Early test-only list/string producer mismatch,
Base stdout deprecation and expect indentation corrected, no warning suppression. No ordinary
OCaml dependency or Core change; no new Linux/Mirage/proof/storage/performance/private-data
replay. File reader is existing shell I/O, NOT native coherent/live/no-follow acquisition;
no household truth, full known-family qualification, migration/authority or durable Saved.

## User-authorized LOAM read-only metadata preflight

Pre-task question/owners/D/P/R and narrow permission exception recorded in HANDOFF/AGENTS.
Narrow source-only inspection of current and metadata-pinned read contracts found different
root-selection policies. Metadata shows competing authority files, not qualified complete
layouts or the actual everyday runtime. Stopped BEFORE household fact content/copy/query; no chosen current
world, new operational answer, corruption claim or unsupported-profile filtering.

An ignored own Python probe uses no-follow directory/file descriptors, regular-file checks,
strict revision syntax, before/after stat identity and repeated metadata-only observations.
Synthetic valid/invalid revision, unchanged read and symlink refusals passed. Private operational
metadata observation passed those stability checks; it does NOT establish atomic household
snapshot acquisition, backup/durability or all-file unchanged-content hashes. No original write,
entrypoint/recovery invocation, sibling build/modification/source copy or network operation.
Only policy/docs changed; engine/manifests/lock/tools/tests unchanged, no fresh executable-suite
claim. Public record omits private paths/hashes/identities/amounts; exact private observations
remain ignored, not fixtures or public provenance. This preflight stopped at selection;
the user subsequently resolved it and authorized the bounded continuation below.

## Latest LOAM contract: private conditional quantity experiment

User selected checkout-based `tools/loam tui` and then latest LOAM contract during unfinished
old-layout cleanup, which the user will perform themselves. Narrow source-only inspection
followed wrapper/CLI/TUI root/current-authority/persistence/support owners. No LOAM entrypoint,
sibling build/source copy, pin edit, original recovery/write/delete/migration or network action.

An own ignored reader acquired ONLY current HouseholdImage: no-follow directory/file FDs,
regular-file and explicit 16 MiB research bound, descriptor/path identity before/after, repeated
full-byte equality, exclusive private copy and final original-byte recheck. Copy/result access
restricted to private owner; exact hashes/paths/payloads not in public output or committed facts.
Synthetic framing controls exercised strict UTF-8, Unicode CHARACTER lengths (not bytes),
opaque unknown/empty versus missing sections, malformed/version/duplicate/truncated/trailing
input, symlinks and no old-file fallback. Stability is not atomic filesystem snapshot, durable
backup, all-private-file content isolation or security certification; reads may change atime.

Initial opaque inventory correctly refused OPERATION as unrepresented. Narrow source owner
identified one-to-one logical publication-request ID -> retained Event provenance, not payment
truth/group/transaction/amount or Saved. Own read profile represents and checks every such
mapping OUTSIDE Core (exact uniqueness, unique Event owner, retained-reference closure), retains
superseded mappings without transfer, and keeps full original opaque generation. All Actual
rows within this declared profile mapped without filtering; unknown/settlement/version/missing
profile coverage refuses. Existing whole source/four-support gates precede lookup. Other household
sections remain retained but unadmitted; no full normalized-LOAM/household qualification claim.

Synthetic compiled controls: older-dated explicit Event correction, exact cut/assertion and
original description bytes, stable links, duplicate/unknown mapping refusals, unsupported raw
families, signed 180-bit quanta, source-closure refusal and support-overlap refusal. Strict
sequencing/fatal warnings 8/9/11 preserved. Then the private candidate passed all read-profile
gates; one question chosen from explicit supplied support returned typed Exact with premise
and exact decomposition matching independent original-list correction traversal/integer Effect
summation. Private values/identities remain local; original current bytes rechecked unchanged.
This establishes a useful CONDITIONAL read-profile answer, not execution/numeric parity with
LOAM, external factual completeness, durable Saved, spending permission or production decoder
refinement. Changed data needs fresh capture, not stale answer reuse. No main module/API/test/
manifest/lock/tool change or ordinary-suite/VM/proof/storage/performance replay in this increment.

After the user reported authoritative data updated to latest, acquired a NEW current-only copy
under the same explicitly selected read contract (narrow source owners unchanged). Reused the
reviewed probes with new private artifact names, freshly replayed synthetic acquisition/profile/
compiled exact/huge-quantity/refusal controls before acquisition. New candidate again passed
whole read-profile source/support/provenance gates; one explicit-support question returned
conditional Exact agreeing with the original-list oracle. Original whole bytes AND identity
signature rechecked equal afterward. Previous artifacts preserved, not fallback/query input;
no inference that cleanup must change household blob bytes or qualifies full migration. Same
privacy/scope/no-write/no-main-change limits; no ordinary-suite/proof/VM/storage replay claim.

User subsequently requested removal of Python/anticipatory test scaffolding. Recent read-review
Python, generated OCaml payload/runners and compiled probe/control artifacts were deleted;
private inputs/results retained. Above records historical execution, not a replayable reader.
Existing OCaml source/tests/lock unchanged; no replacement harness or new suite run. Next needed
read path is native OCaml, not a translation of this retired pipeline.

## Experimental ordinary Movement proposals

Bounded question/D/P/R/owners recorded before code in HANDOFF at 2331eeb. Pure `text/Propose`
consumes existing reader/Movement/source gates; no Core/Application/CLI/filesystem change,
new dependency/model/campaign or whole-world codec. Only new explicit Movement/description/
correction rows are encoded into the already admitted ordinary profile; base bytes remain
unchanged around the insertion. A proposal is not publication permission or a selected snapshot.

Three focused existing native expect connections qualify: all 256 bytes together in ID/key/
Locus/Measure/description and signed 180-bit quantities, original ordered Effect multiplicity,
base lexemes/indentation/trailing whitespace and all four support families; correction keeps
old/new observations/edge/text and independent reflected cut (90 -> 80), chooses explicit edge
rather than later occurrence date and invents no support; staged unsupported-base/duplicate-key/
empty/zero/unbalanced/mixed-Measure/date/duplicate-ID/missing-or-superseded-target/opening refusals.
Explicit empty versus absent description stays distinct. Existing public type clients compile
without runtime/CLI/Presentation, reject forged candidate and read-image substitution. Unsafe
OCaml escape hatches are outside that check. The fixed-profile end locator depends on the
reader's earned complete framing, not a second parser or arbitrary text patch capability.
Initial compile errors (OCaml 5 `effect` keyword, fixture parentheses and misnamed accessors)
were corrected without suppressing warnings or weakening admission. Unix publication/lifecycle
qualification remains a separate ignored synthetic consumer; no durable Saved/full household/
operational recording/format adoption follows from these pure controls. Main macOS
`tools/check` (173 expect/four cram), forced package tests, release @install, pinned format and
whitespace review pass; installed set stays 50, no manifest/lock or inward dependency change.

## Unix text publication consumer (synthetic, no Saved)

Named consumer/owners/D/P/R/instruments recorded before code at 2331eeb; pure proposal qualified
in 3d0e0dd before this trial. Fresh ignored `scratch/text_publication_review`, native OCaml 5.3.0,
compiler Unix and EXISTING main Base/Zarith/artifacts only. No copied stale engine/switch,
third-party/upstream source, dependency/lock/global install, VM/Lean, operational data or main
store/UI/adoption. Dune excludes scratch; its actual workspace description contains no trial.

Disposable layout v1: explicit provisioning, permanent cooperative LOCK, atomically replaced
CURRENT pointer, immutable complete generation files carrying original parent/request and byte-
length-framed ordinary-profile text. Request IDs are explicit synthetic bytes (hex filename,
96-byte TRIAL path budget), not Event IDs/date/quantities or adopted allocation. Opaque tokens
bind canonical namespace path + generation; cross-store/restored-root token reuse refuses.
Assume single-threaded cooperative processes, stable exclusively owned namespace/parent path,
all writers taking the same retained lease and no mutation/deletion of retained generations.
Read captures ONE selected head and fully admits every required ancestor, never initializes,
repairs or falls back. Candidate whole admission precedes acquisition; complete stored admission
precedes write-open AND repeats under lease. Expected head is gated there, exact base bytes bind
the candidate, and new bytes are re-admitted rather than trusting preview. Generation file sync/
close -> checked namespace sync -> head file sync/close -> rename -> checked namespace sync;
provision also checks immediate parent sync. Caught errors after effects may begin, including
close/cleanup, remain Uncertain. No automatic deletion/recovery. No success hides a required
sync return; ordinary fsync is NOT Darwin F_FULLFSYNC/stable-media qualification.

Final native v3 controls pass: separate-process initial/select/reopen/correct loop 1000 -> 990 ->
985 with all four support distinctions/Measure separation, old source bytes/parents/Events/edge/
description and independent cut; exact 180-bit cold query + complete-byte round-trip. Stale
expected token conflicts, real two-process lease contention is BUSY (not Conflict), mismatched
base spelling/cross-root token/empty request refuse. Identical replay after a later correction
returns ORIGINAL receipt, not current/fresh; changed candidate/base refuses with unchanged file
bytes. Reconciliation only observes receipts on the SELECTED parent chain: complete prepared
files are not receipts. Explicit exact prepared-candidate retry works; changed prepared bytes
refuse, retained partial head temporary blocks retry without implicit cleanup. No-receipt means
not observed in that captured chain, not universal non-recording or permission for blind retry.

Eight named returned-error checkpoints report Uncertain/no success; cold processes and receipts
show 6 OLD/2 NEW. Two actual process SIGKILL controls immediately before/after head rename have
empty success stdout, OLD/NEW cold admission and unchanged reconciliation bytes. This is API-
checkpoint/process evidence, NOT syscall EIO/ENOSPC/short/torn writes, exhaustive kill timing,
host/power loss or device completion. Closed same-host complete-family copy preserves all bytes/
history/receipts and cold query; only newly captured namespace tokens may be used. Not live or
off-device backup/restore qualification. Invalid selected evidence blocks read/write activation;
unsupported layout, malformed header, truncated payload, dangling head, missing ancestor and
incomplete provision refuse without salvage, initialization, repair or older-world fallback.
Initial header review separated malformed corruption from unsupported versions; v1/v2 images/
logs kept and fresh v3 passed. Selected history is the declared admission scope, not every orphan.

Strict rebuild, source/image/linkage digests and v1-v3 controls retained in ignored evidence;
image SHA256 195f12763fa74b61c23476349f1bf69cc6daf9da68507d601bbb53a69c438f85.
Links existing GMP/libSystem only. Exact main 50 names/versions and lock SHA256 unchanged.
All trial child processes/handles finish/are waited; VM remains stopped. No canonical layout/
store/schema/production identity, full household/richer codec, principal isolation, valid-tamper
integrity, multi-threaded/malicious namespace concurrency, maintenance/cleanup/recovery service,
actual failing syscall/close controls, ancestor-directory lifecycle or durable Saved earned.
Whole-generation/history copy/reconstruction cost was UNMEASURED at this increment; the bounded
review below now supplies 10k/100k observations. Lifetime cost and production strategy remain OPEN.

## Synthetic text scale and history cost

Question/D/P/R/assumptions/review budgets recorded BEFORE code at 260950b. One disposable native
`cost.ml` consumer alongside the existing ignored Unix trial; CURRENT engine/Store reused, no
historical harness port or framework/model/random campaign/package/VM/Lean/operational data.
Host Darwin x86_64, Intel i5-8259U 2.30GHz, 16GiB; OCaml 5.3.0/Base/Zarith and exact main 50
unchanged. Native CPU/wall phase timers, `/usr/bin/time -l` worker wall/user/sys/peak RSS, three
fresh-process repetitions per ordinary shape. Filesystem caches UNCONTROLLED (likely warm);
no cache eviction, fresh-host, cold-media, other-host or universal latency claim. External
worker time/RSS includes start-up and correctness checks, not just the named timed phase.

Inputs: 10k/100k measured ordinary Events + TWO fixed USD/opening/net-zero-touch Events, two
ordered Effects each, Event-local key reused across Events, 1% supplied recognizer text. Flat
singleton roots versus disjoint four-Event/three-edge correction paths; replacement dates
older than roots, amount 1/2/3/4 so retained sums differ from selected terminals. Half-root
wallet cut with independently asserted signed 180-bit quantity; food/quiet origins, USD
opening, presence/unknown retained. Separate stress adds 100 independent empty-cut groups with
no matching physical activity. Native text producer is synthetic input, not generated OCaml
payload or a chosen canonical encoder. No failed/missing source becomes a successful quantity.

Ranges below are EXTERNAL worker seconds, three repetitions; input read/reopen v2 consumes
observable answer checksums, append/correct v1 operations are unchanged. Unsupported-input
negative control exits 1 with no CHECK PASS. v1 discard-only query loops were not accepted as
final query-cost evidence: v2 counts 572 Exact/143 presence/285 unknown plus exact checksum for
1,000 lookups, then checks expected original quantities; all source/reopen shapes rerun. Cached
image batch (INCLUDING checksum addition) takes 0.120-0.224ms here, not a per-question guarantee.

| Shape / measured Events | One input read | Append worker | Correction worker | Three-generation reopen | Largest lifecycle RSS |
| --- | --- | --- | --- | --- | --- |
| Flat / 10k | 0.11-0.57s | 0.61-0.64s | 0.88-1.00s | 0.36-0.38s | 88.8MiB |
| Four-Event paths / 10k | 0.12-0.14s | 0.68-0.69s | 1.02s | 0.39s | 83.8MiB |
| Flat / 100k | 1.01-1.05s | 6.43-6.55s | 9.46-9.53s | 3.63-3.64s | 759.2MiB |
| Four-Event paths / 100k | 1.21-1.23s | 7.59-7.65s | 11.23-11.40s | 4.23-4.25s | 765.3MiB |

Initial admit/write/sync workers: 10k 0.12-0.13s, 100k 1.16-1.37s, visible-unacknowledged only.
Representative 100k flat phases: acquire ~0.018s, decode ~0.356s, source ~0.385s, support ~0.255s.
Path source admission ~0.73s, support ~0.07s (fewer roots). Correction's read-before-proposal
~2.14/2.45s, proposal ~2.00/2.41s, publisher ~5.29/6.30s flat/path: repeated complete admission,
not indexed lookup, dominates. Each publication revalidates candidate and full selected history
before activation and under its lease; none of those gates were removed for speed.
100 extra groups: single sensitivity samples 10k ~0.77s/81.4MiB, 100k v2 ~8.52s/773.1MiB;
100k support phase alone ~7.69s versus ~0.255s, input adds only 4,390 bytes. Nearest owners confirm
per-group root-set/filter and original-Effect aggregation walks, retaining independent cuts.

Exact original bytes/three-generation parent associations/old recognizer text/correction edge/cut/current
selection/Measure separation/zero/presence/unknown checked after each operation and reopen.
Three complete snapshots occupy 3,708,370/4,203,370 bytes at 10k flat/path and
37,064,173/42,014,173 bytes at 100k (initial text 12,354,481/14,004,481). A small added Movement
still retains a COMPLETE new image; ~3x for three generations is NOT linear lifetime retention.
Unbounded publications, many-generation reconstruction, off-device backups/cleanup and storage
exhaustion are not measured or qualified. Entire retained test tree ~346MiB; original v3 sources/
image/digests intact, all cost source/image/raw logs preserved separately in ignored cost-v1/v2.
No trial enters Dune workspace. Ordinary check (173 expect/four cram) passes; lock and exact
50-name/version set identical. Process alarms 120s, observed-RSS stop 2GiB did not fire.

All EXPLORATORY review budgets (10k read 2s, 100k read 10s, proposal+publish 30s, RSS 1GiB)
met, not user SLOs/product readiness or Saved. Decision: defer main optimization/adoption until
concrete daily recording latency/group/retention requirements name the trade-off. Query reuse is
already earned; repeated whole admission and per-group walks/copies are the observed seams,
not license for partial admission, merged support meanings or speculative caching. Actual
returned I/O/sync/cleanup failures and namespace/power-loss lifecycle qualification remain
separate. Existing LOAM is sole authority; no real inputs were needed for this cost review.

## Direct Daily_book native append and correction cost (2026-10-09)

Question: does the **current corrected-entries Daily_book** need more
incremental machinery, or is its existing simplest valid full fallback
acceptable at ordinary history sizes? This is distinct from the prior
generic Actual source/publication measurements above.

A one-off release-compiled native OCaml 5.3 probe was run on GitHub-hosted
Ubuntu, with the existing synthetic `examples/daily-book.sexp` fixture,
**two reflected quantity-support groups**, 1k and 10k new balanced JPY
wallet/food Events, and an unrelated EUR balance kept unchanged. The same
admitted baseline is reused for each append/edit operation; no live LOAM
source or user records are opened. Three within-process wall-clock samples
per operation, median reported; GC/host load and warm caches uncontrolled.

| In-memory operation | 1,000 entries | 10,000 entries |
| --- | ---: | ---: |
| Build baseline by ordinary incremental recording (total) | 1.813 ms | 14.418 ms |
| Append one ordinary Event: existing incremental path | 0.0010 ms | 0.0019 ms |
| Append same Event: independent full-admission path | 2.549 ms | 30.863 ms |
| Edit middle Event amount/date: existing full path | 2.285 ms | 33.282 ms |
| Decode and fully qualify a serialized in-memory snapshot | 6.799 ms | 80.541 ms |
| Serialized snapshot size | 204,799 bytes | 2,040,799 bytes |
| Whole benchmark process max RSS (GNU time) | 18,308 KiB | 61,300 KiB |

Executable evidence: [CI 37947797058](https://github.com/shumoku88-bit/bakhlo/actions/runs/37947797058)
(successful release compilation and both bounded sizes). Archived source of
the temporary probe and PR-only workflow:
[commit a17ad400](https://github.com/shumoku88-bit/bakhlo/commit/a17ad400d02de1915f31a2e832d74a1b3dc7315d).
The executable and CI workflow were deliberately removed from the final PR
diff. Reproduction requires the archived commit, not today's main.

For both sizes, the incremental and full append paths serialized to
**identical bytes**; edited-event results agreed with `put_entry_full`;
wallet/food JPY totals were asserted, wallet EUR was unmodified, duplicate
identity and unbalanced Event were rejected with the **same reasons**, and
the original admitted book remained unchanged. This does not constitute
a proof for every input/refusal mode, only these synthetic witnesses.

**Interpretation:** in this small-support scenario the existing ordinary
incremental append is already cheap and the 10k full fallback is tens of
milliseconds. The ~1–2 microsecond append numbers are near timer sensitivity;
do **not** turn them into universal speedup ratios. The benchmark EXCLUDES
filesystem read/write/fsync, record append/reopen, publication conflict and
uncertain acknowledgement, TUI latency, real workload distributions, mass
correction chains, FX, group-count sensitivity, and 100k/1M Daily_book scaling.
Full publication may remain more expensive than in-memory admission.

Do not add a new cache, replacement admission engine or persistent index on
this evidence. The existing `Current_quantity_groups.with_added_effects`
rebuilds derived owners across qualified support groups; only if a real
high-group-count household input exhibits pressure should its incremental
cost be measured separately. Keep the full qualified oracle and refusal
correspondence as non-negotiable gates.

## Support-group count sensitivity in corrected-entry Daily_book (2026-10-09)

Following the merged direct Daily_book trial above, ask whether ordinary
incremental recording depends materially on **number of independent supported
quantity groups**, as `Current_quantity_groups.with_added_effects` updates
every qualified group and recreates its owners map on each append.

Bounded native OCaml 5.3 release probe, GitHub-hosted Ubuntu, synthetic
version-3 monolithic Daily_book with exactly the same 1k or 10k balanced
wallet/food JPY Events within each group-count sweep. Every added independent
group holds exactly one nonoverlapping zero-valued assertion on an untouched
`probe-NNNN/jpy` coordinate and an empty reflected-root cut; the first group
asserts the exact `wallet/jpy` balance. `food/jpy` has zero-origin support.
No duplicate assertion owner, missing source or real household data.

| History | Independent groups | One incremental append (ms) | Parse + full qualification (ms) |
| ---: | ---: | ---: | ---: |
| 1,000 | 1 | 0.000615 | 5.844 |
| 1,000 | 10 | 0.001657 | 8.453 |
| 1,000 | 100 | 0.017241 | 32.352 |
| 1,000 | 400 | 0.090420 | 114.523 |
| 10,000 | 1 | 0.000664 | 69.359 |
| 10,000 | 10 | 0.001694 | 102.911 |
| 10,000 | 100 | 0.016932 | 447.688 |

Qualified measurements: [CI 37949609636](https://github.com/shumoku88-bit/bakhlo/actions/runs/37949609636);
temporary compiled source: [commit 2dc5a534](https://github.com/shumoku88-bit/bakhlo/commit/2dc5a53423bda6df495ddfb8cc24906e5a0620f4).
The temporary executable, Dune stanza and PR-only workflow are absent from the
final PR. Executable was release-compiled; append figures are per operation,
medians across five batches, where shorter operations use more repetitions;
admission figures are three full parses/admissions on prebuilt in-memory text
per case. All scenarios checked equality of append bytes against full
`put_entry_full`, wallet/food totals, untouched group assertion and exactly
retained independent support evidence. **Every case reported CHECK=PASS**.
Whole-workload peak RSS was 215,712 KiB, not a per-case footprint.

Result: in these deliberately many-independent-groups fixtures the cost of
incremental append rises with support-group count but is nearly invariant
between 1k and 10k history. At 100 groups the measured single append was
still ~0.017ms; 400 groups ~0.090ms at 1k history. **No daily-use slowdown
or new cache requirement was established.** The whole-admission path rises
more visibly: 10k entries / 100 groups ~448ms vs ~69ms at one group.
This is consistent with per-group projected whole-history aggregation in
`Current_quantity_projection.create`, but the benchmark is not a call-by-call
profile proving the exact split.

Do not rewrite or bypass qualified support group semantics. The extra
groups assert otherwise-unused loci, an intentionally upper-pressure fixture,
not a measured household distribution. No file I/O, record publication, fsync,
crash/ack recovery, FX, correction chains, heavy group reflection, cold-media,
user-visible TUI steps, or mobile/Intel Mac timings are covered. The tiny
microsecond append numbers are sensitive to timer/runtime noise. If actual
household use ever requires dozens/hundreds of independent support groups,
first profile full opening/admission and real save latency, and consider
transient reuse inside existing admission only with refusal-equivalent tests.
Otherwise retain the current simple implementation.

## Whole-admitted document reuse and fresh publication gates

Question/D/P/R/bounds recorded BEFORE code at 8ea1cc9. User requests the measured save seam;
no canonical adoption/production writer follows. Pure `text/Read.document` seals original
bytes+EXACT existing query image via the unchanged complete Input -> Source -> Support gates.
`Propose.append_document`/`correct_document` reuse that base and still whole-admit ALL NEW
candidate bytes; raw entrances keep Base -> Event -> Movement -> Candidate refusals. Candidates
retain base/new documents, not recording permission/currentness. Two focused expect connections
check immutable old answers, identical raw/typed encodings, correction and new validity/opening
refusal; all prior byte/180-bit/multiplicity/cut controls remain. Public type clients accept the
sealed consumer and reject forged bytes/image documents and image-as-document substitution.
Unsafe OCaml escapes/principal isolation are outside this seam, just as for existing images.

Ignored `scratch/text_publication_reuse` is a versioned copy of OWN existing trial/consumer, not
a second engine, backend framework or maintained benchmark. Original v3/cost sources/images/
stores are unchanged. Actual PROFILE/CURRENT and every selected ancestor file are freshly read
before LOCK write-open; under lease all are freshly read AGAIN. Operation-local captured
admission is reused ONLY after exact canonical namespace/generation/FULL envelope-byte equality.
For a freshly validated envelope, identical complete sealed base/candidate document bytes also
reuse pure admission. Changed bytes get the complete normal reader, not partial filtering or
an older successful capture. No persistent/global/mtime/digest-only cache, inferred support,
cut merging, file repair/cleanup/fallback, new representation, dependency, VM/Lean or real data.
Expected selection/base/scope and original-receipt lookup still gate conditional publication;
they do not supply principal authorization.

Reused controls pass: 1000 -> 990 -> correction 985; retained bytes/text/cut/edge; Measure/zero/
presence/unknown, signed 180-bit quantity, original receipt replay/changed-request/base/conflict,
cross-namespace, actual two-process Busy, prepared-vs-selected, malformed/truncated/missing
history/layout and closed restore. Eight post-effect returned checkpoints remain Uncertain
(6 OLD/2 NEW), two real SIGKILL controls OLD/NEW, no success stdout and read-only reconciliation.
Ten NEW deliberate pre-lease interleavings check same-token changed bytes, invalid source,
changed-parent/same-body, cycle, missing selected, truncation, changed profile, valid concurrent
head, missing/invalid ancestor. All refuse or conflict with no further publisher changes;
Captured returned-error control is pre-write Error, not Uncertain. These synthetic mutations
are adversarial TEST changes, not qualification for malicious concurrency/stable-namespace loss.
A disposable negative binary OMITTING full-envelope equality fails the first same-token/new-byte
control (exit 1, unexpected publication effects); qualified binary passes. No production/cache
source was weakened for this control. Actual syscall/sync/close/cleanup errors and power-loss
namespace lifecycle remain separate: no Saved result, permission/security or recovery service.

Controlled comparison: byte-identical ORIGINAL cost inputs, unchanged native cost correctness/
checksum workload, fresh separate stores/workers; baseline is byte-identical original Store/cost
source relinked to the SAME CURRENT pure engine. Reuse differs only in typed-base entrance and
call-local publication reuse. 10k one paired repetition, 100k THREE (order reversed in repeat 2),
flat and four-Event paths. Full baseline/reuse retained store trees are byte-identical after each
lifecycle. Same Darwin x86_64 i5/16GiB/OCaml 5.3.0, uncontrolled likely warm filesystem cache;
not cold-media/user SLOs. Raw wall/CPU/RSS/phase/check logs and `summary.tsv`, source/image
hashes, package/workspace/link records and weak control retained under ignored `evidence-v1`.

| 100k Events | Baseline append | Reuse append | Baseline correction | Reuse correction | Reuse append / correction peak RSS |
| --- | --- | --- | --- | --- | --- |
| Flat | 6.69-6.70s | 2.42-2.45s | 9.96-10.10s | 4.54-4.75s | 409.8 / 561.5MiB |
| Four-Event paths | 7.91-7.99s | 2.83-2.86s | 11.86-12.00s | 5.44-5.54s | 429.6 / 584.5MiB |

10k append flat/path 0.63/0.72 -> 0.23/0.26s; correction 0.93/1.07 -> 0.43/0.49s.
Current baseline peaks flat/path append ~729/733MiB, correction ~945/979MiB. NOT directly the
old 8ea1cc9 RSS: raw proposals now retain their admitted base image as well as bytes; relinking
both variants isolates this from the reuse comparison. Reuse saves ~64% append/~53-54%
correction worker time. New candidate whole admission ~1.05/1.29s, not ~2.0/2.4s; representative
flat publisher ~1.51s vs ~5.29s in original review. Read-before-correction ~2.13s unchanged;
whole retained-history reopen ~3.7/4.3s unchanged. Capturing full envelopes adds reopen memory
(~11MiB flat/~28MiB paths vs paired baseline); original checks/consumed checksums still pass.
Three complete generations remain 37,064,173/42,014,173 bytes: no lifetime-retention improvement.

Decision: retain the small pure sealed-document seam and qualified TRIAL reuse only. Stronger
REVIEW hypotheses <=5s/<=512MiB are PARTLY met: append meets both, flat correction meets time
but not RSS, path correction meets neither. No lowering/relabeling those bounds or expanding
optimization/campaign now. Fresh-process history, per-group support walks and full retained
copies remain costs requiring a concrete daily workload/retention/host requirement. Main check
175 expect/four cram, forced package tests/release install/format/whitespace and exact main 50/
lock preservation qualify this increment; no operational-data read, storage adoption or push.

## Experimental versioned-text read (ordinary Actual profile)

Question/owners/D/P/R before code in HANDOFF. A pure outer `bakhlo.text` reader admits one
complete supplied byte string through existing source and four-support gates; no engine change,
terminal API promotion, runtime/store dependency or canonical-format adoption. Contract/grammar
owned by [Architecture](ARCHITECTURE.md#experimental-versioned-text-read) and `.mli` links there.
Fixture inputs supplied independently for this bounded profile; no richer evidence filtering.

Executed on qualified macOS x86_64 / OCaml 5.3.0 / Dune 3.24.2, unchanged exact 50 versions:
- Six new expect tests connect 990/160/7/0, abstract presence/typed unknown, original retained
  Events/keys/multiplicity/descriptions, explicit correction (older-dated replacement selected
  ONLY through the correction), forward references and three independent group/presence cuts.
  Independent fixture comparison and existing original-Effect Zarith oracle reused.
- All 256 escaped singleton bytes plus a complete all-byte payload through Event/key/Locus/
  Measure/description; literal UTF-8/space/nrt/quote/backslash, absent vs empty, no trimming,
  exact signed 180-bit quanta and anonymous multiplicity. Byte preservation is not UTF-8 validation
  or a production lossless encoder/round-trip certification.
- Reused 847 byte/sign/short-literal shapes, 68 token successes against independent digit
  arithmetic + explicit space/tab token boundaries. Different from the fixture's 42 field-byte
  successes: whitespace separates tokens here, never trims quoted identities/text.
- Version/profile, 13 unsupported record/comment shapes, 20 malformed frames/quotes/fields,
  every proper byte prefix of one complete escaped document, trailing evidence and CRLF refuse.
  Typed Input -> Source -> Support staging, duplicate Event/key, zero/unbalanced physical facts,
  missing/bad validity, dangling/cyclic corrections, equal-zero overlap and empty-cut closure.
  None/Some empty presence remain distinct; empty/unsupported lookup never becomes zero.
- New cram: standalone public reader client WITHOUT CLI/Presentation CMIs, unadmitted-input
  rejection and private lexer exclusion (three compiler specimens); Unix help/acquisition,
  exact/presence/unknown/version/profile/whole-refusal streams/exits and unchanged-file controls.
  Tests assume exclusive stable synthetic file ownership, not filesystem snapshot isolation.

`./tools/check`, forced package tests, local `@install`, clean engine-only build (no Text/CLI/
Presentation/bin targets) and ordinary check with nonexistent LEAN passed. Package and final
exact logs each contain 157 inline execution markers; ten existing campaigns/100,000 generated
cases and four cram suites retained/run. 84 prior compiler specimens + three new = 87. Main
installed 50 selections equal the recovered baseline; manifests/lock/tools/compiler policy and
Domain/Application unchanged. No operational data, SQLite/Irmin/VM/old trial mutation or new
Linux/Mirage/proof/performance/storage replay. Prior platform evidence is historical, not a
fresh qualification of the text adapter there.

Corrected before final qualification: `effect` is reserved in OCaml 5.3 (helper renamed), one
ambiguous doc-comment attachment, literal oracle initially assumed fixture field whitespace
rather than this profile's token separators, and two cram diagnostic expectations (quoted
module name / overlap wording). Public wrapper explicitly excludes the private lexer, not
merely omission of its CMI from test dependencies. Failed runs were not promoted as evidence.
Exact final logs/own scratch control remain in ignored `scratch/text_read_review`; initial RTK
logs retained privately. No new model/theorem/campaign/benchmark framework for this consumer.

Bounds: synthetic conditional ordinary-Actual profile only, not full household coverage,
canonical codec/writer/store/identity/upgrade, atomic filesystem generation selection, durable
Saved, diagnosis/partial-world service, parser resource/security/performance certification,
AI/UI or spending permission. Revisit before broader evidence/encoding or physical publication;
read success must not be promoted into recording or external factual truth.

## Backend-neutral reference direction (contract/tests planned)

After a78b478 user explicitly selected Unix + SQLite as the practical reference TO BUILD,
with Irmin/Mirage/Solo5 experimental and no technology-bound core/Admission/Publication.
Question/D/P/R recorded before alignment. Documentation/dependency-direction/metadata review
only in this step; no SQLite adapter/install/lock/schema/shared test runner/VM boot. Historical
Mirage/SPT evidence below remains earned, neither deleted nor qualification of this reference.
Architecture owns the minimal contract; tests must not call backend storage history household
corrections or turn unsupported durability into Saved. The later [bounded Unix/SQLite trial](#unixsqlite-synthetic-persistence-bounded-outer-trial-no-saved-qualification)
now exercises a concrete ignored consumer; the production adapter/shared multi-backend runner
remain to build, rather than SQLite still being wholly metadata-only.

| Planned common scenario | Assertion / physical mapping boundary |
| --- | --- |
| Save -> close/reopen -> read | Same complete versioned source/support bytes, exact 180-bit/zero/presence/unsupported/provenance answers; no mixed generations or stored derived balances |
| Expected-generation conflict | Atomic check/publish, no stale authorisation or auto-merge; BUSY/I/O error is not a fabricated conflict |
| Replay / uncertain result | Explicit operation/candidate association; identical qualified replay refers to original receipt, changed payload/base refuses; failed/lost response may have published |
| Corrupt/missing/unsupported format | Distinct load failure/absence, no init/default/drop/decode-to-None/older truth fallback |
| Diagnostic readiness / scoped availability (future host/partial consumer) | Structured faults remain accessible; missing support is not storage corruption. Unaffected answers require explicit qualified coverage/closure; affected answers unavailable, not zero/filtering/mixed generations. Not a current runnable service test |
| Interrupted publication / retained history | Old acknowledged state retained, complete selected generation or explicit failure; SQLite transaction/commit hooks versus Irmin/block hooks, NOT transplanting 95 API indices |
| Backup -> restore -> query | Declared stopped/live consistency and backup scope, exact bytes/history/support/answers; same-guest disk copy is not off-device/power-loss qualification |
| Durable Saved | Actual configured sync/order/receipt guarantees under named failure model; unqualified experimental capability remains a visible blocker, not a green skip |

First SQLite binding metadata preflight (frozen ac27950): sqlite3 5.4.2 (MIT), OCaml >=4.12,
Dune >=2.7 direct gates fit main 5.3.0/3.24.2. Requires dune-compiledb, dune-configurator and
build conf-sqlite3; with-test ppx_inline_test, with-doc odoc. System SQLite headers/library
remain external costs and actual version/configuration must be recorded. No transitive
closure/OS availability/compatibility/durability inferred from metadata. Named consumer:
outer Unix reference synthetic coherent snapshot save/reopen; thin bindings versus own C/SQL
FFI or an ORM/umbrella, with experimental Irmin retained. Review source/license/solved closure
and actual fault/recovery path before dependency adoption. Quantity never enters SQLite
machine integer/REAL arithmetic as authoritative quanta. Fixture v2 is not canonical schema.

## Structured-operation / diagnostic-readiness audit (no new features)

At 6673026, nearest owners inspected: engine Dune/.mli/implementations, CLI evaluator/shell,
Presentation and existing typed-client/application/query/decoder tests; pre-task D/P/R in
HANDOFF. User's future operation/health/reason names are examples, not added APIs.

| Finding category | Current evidence / bounded action |
| --- | --- |
| Already fits | Domain: Base + Zarith; Application: Domain + Base only. Movement_check.run is command -> typed preview/refusals; current quantity query exposes exact Quantity/Measure/coordinate/premise versus abstract presence/unsupported. Discharges expose conditional typed remainders. Rendering and actual I/O remain outside |
| Coupling to avoid | Current_fixture_command.evaluate turns read/decode/admission/query results into terminal Response; read failures and syntax details include strings. Synthetic decoder lives in CLI, whose library also depends on Presentation. Future canonical loader/shared operation must not inherit terminal exits/stderr or treat fixture v2 as storage/API schema; extract only for a concrete consumer |
| Real gap, not a defect to hide | Whole Actual/support gates refuse unrelated invalid evidence; decoder has no partial result and gates generally report first refusal. No diagnostic host, structured storage health or qualified partial-world operation exists. Scoped degraded answers need coverage/closure/generation qualification, not dropping failed rows |
| Small change now | Architecture distinguishes typed operations, diagnosis availability, partial-read guarantees and publication outcomes; three .mli comments mark terminal versus semantic results and image refusal versus host liveness. Declarations/executable implementations/locks/dependencies/tests unchanged |
| Defer | No placeholder Get* operations, generic answer/health/command bus, parser relocation, source-admission weakening, physical section schema, voice/LLM/chat/UI/Mirage implementation or dependency adoption |

Implementation lexical audit found no external-effect/formatting modules or explicit
mutation/raise/failwith in Domain/Application. Two Map.find_exn aggregate lookups consume
keys inserted for those SAME admitted rows earlier in the SAME immutable construction
(Open_relations/Relation_discharges); no fallback zero or new universal error added. This
inspection is not a purity/refinement proof or a guarantee that bugs/resource exhaustion
always yield structured diagnostics. Ordinary typed failures are not all possible host faults.
Clean native engine-only build passed with no compiled CLI/Presentation/bin artifacts;
./tools/check passed on the existing macOS lock, reusing earned campaigns/type/CLI controls.
No Linux/VM/Mirage/storage/proof replay or new fault campaign. This qualifies only current
boundaries/comments, NOT health-service startup, partial-read recovery or future operations.
Revisit with the SQLite representation/read-failure/publication consumer; expose structured
outer failures then, retaining faults and diagnostic inspection without false household truth.
Contract owner: [structured operations and diagnostic availability](ARCHITECTURE.md#structured-operations-and-diagnostic-availability).

## Retained executable evidence

Tests are executable documentation; names, seeds and counts live in the test source and
forced runner output, not duplicated status inventories. `./tools/check` runs all OCaml
checks. Existing generated campaigns retain independent expected-value logic and execution
counters; shared construction helpers are in `fixtures.ml`, never another test-case module.

| Seam | Independent evidence and limit |
| --- | --- |
| Quantity / Movement / application | Exact Zarith oracles, signed/huge values, replay and structural refusals; not publication |
| Effect keys | 81 four-Effect None/a/b patterns (21 admitted) against original-token-prefix oracle, exact spellings, Event-local reuse, physical generality, retained keys and anonymous controls for four supports; not metadata/overlay admission |
| Identity / correction / lineage | Original-list/fuel oracle and immutable integer Warshall closure; all 512 three-node and 65,536 four-node simple relations (73 admitted four-node paths). No missing IDs/parallel edges in enumeration; separately tested |
| Reflected cuts | List declaration model, 1,168 four-node relation/subset cases (304 cuts), selected fresh tails, prefix/source changes and old-terminal leak witness; not arbitrary-edit stability |
| Assertion arithmetic | 4,864 graph/cut/support cases, original-Effect Zarith sum, unknown/zero, translation and reflected/unreflected seams |
| Group ownership/re-observation | Independent two-coordinate/two-group list model: 256 construction and 2,304 update/replay seams; preserve whole premises, ordered refusals and old values; not durable retry |
| Event descriptions | 64 three-slot omission/a/b/unknown patterns (13 admitted) against original-token-prefix oracle; exact/empty/control text, retained source/order, permutation, correction-tail noninheritance, prefix requalification and four-support noninterference. Combined declaration-order duplicate/reference gate, not upstream refusal-order parity or text truth |
| Event merchants | 512 three-slot omission/provider-p/provider-q/nonmerchant/retained/unknown-Event combinations (52 admitted), original-token-prefix oracle and independent pre-code enumeration; exact/control/shared party IDs, general neutral Events, source/order retention, permutation, date/text/key/four-support independence with earned original-Effect arithmetic/touch oracles, correction-tail noninheritance, prefix requalification and immutable old source; not provider truth/coverage, a party registry or report routing |
| Exchange selection/source exemption | Independent original-token/list/Zarith model before product code and independent Python counts: 9,216 selected-Measure/sign/two-extra-Effect shapes, 122 selection / 74 nonzero source / 80 ordinary no-claim admissions. Curated selected-vs-net sign, third Measure, anonymous/missing/exact keys, duplicate/unknown/order, huge values, correction endpoints/open raw interference, retained payload/immutability and metadata/date/original-amount/four-support seams with earned Effect sum/touch oracles; no rate/fee/valuation truth or correction replacement. Existing 625 physical cases/generated tests also qualify private per-Measure arithmetic extraction |
| Actual Reversal | Independent original-token/list-remove-one physical multiset model checked before product code, independent Python counts: 7,225 two-Measure +/-1 length-0..3 pairs (289 exact / 9 ordinary source) and 273 four-ID 0/1/2-fact collections (37 globally disjoint). Model-only aggregate/regrouping/duplicate/coordinate counterexamples retained. Product correspondence, all 9,216 earned Exchange shapes with inverses (74 source pairs), reversal-side-only claims cannot rescue targets, reordered/key-free payloads, huge/control/zero/closure/refusal/replay/immutability; ordinary correction/prefix retaining original endpoints and current +1 counterexample, four-family independent cuts and cancellation-touch controls with original-Effect oracles. No factual truth/current universal cancellation, lifecycle/reporting/publication or arbitrary-size guarantee |
| Effect-backed relation units | Independent original-token/list/Zarith model checked before product code and Python counts: 40,401 two-slot ID/source/endpoint/quantity cases, 265 whole-family/source admissions. Explicit direction vs sign, equal-field independent units, opposite-direction/party overcoverage, same-coordinate different keys and cross-Event key reuse counterexamples retained. Product source/payload/index correspondence, exact/control/huge/zero/general Event, concatenation collision, ordered global-ID/local/aggregate refusals, immutable old source/replay/permutation/tail/prefix/omission; date/text/Merchant/original-amount/Exchange/Reversal/four-support seams with original-Effect sum/touch oracles. No arbitrary-size/refinement proof, external relation truth, target-local residue/completeness, discharge/remaining debt, lifecycle or publication |
| Closed discharge / snapshot remainder | Independent original-token/list/Zarith model checked before product code and Python enumeration: 5,776 two-slot Event/target/quantity/omission cases, 109 discharge/source admissions. Earned Relation_model premises; product raw/source/admitted/bucket/remainder order, full/partial/no-row/unknown and arithmetic correspondence. Curated exact/control/180-bit partial/full/over-total, source vs unrelated discharge Measure, typed-pair concatenation collision, empty occurrence/no Event budget, closure/self/duplicate/ordered/aggregate, replay/permutation/omission/target shrink/old-value immutability, corrected/reversed/noncurrent endpoints and prefix/earlier-date controls; metadata/date/Exchange/Reversal/four-support independence with original-Effect sum/touch oracles. No external fulfillment completeness, arbitrary-size/refinement proof, inactive-residue activation, write/crash/recovery or physical balance support |
| Original amounts | Earned integer Warshall pairs: 13 admitted three-node relations x 64 omission/negative/zero/positive declarations = 832 cases (44 admitted), independent pre-code enumeration and current lookup/order correspondence. Separate duplicates/unknown/guard-order/huge/control/Measure specimens, retained source, replay/permutation, fresh-tail projection and prefix/omission requalification; earned original-Effect arithmetic/touch oracles for four-support noninterference. Not amount truth/completeness, FX/basis or publication |
| Date history | Independent integer extension of earned Warshall model; 16,384 four-fact subsets/two-revision Event assignments/revision-only replacement relations (36 admitted), model-only counterexamples before product correspondence. Tagged-same-token IDs, revision-only evidence, retained invalid dates, ordered open/cross-Event/branch/merge/cycle/current conflicts, representation/tail/prefix/immutability and 10,000-revision chain/cycle; not arbitrary-size proof or temporal truth |
| Actual source / support routing | 625 two-Measure physical predicates; 16,384 two-coordinate/four-family seams (1,600 admitted), independent two group cuts/shared presence cut and original-list/Effect oracle; ordinary-source base-date inputs in that table; date-history/four-support noninterference tested separately |
| Explicit opening | Current/coordinate/duplicate closure, same Event for distinct coordinates, supported zero/huge signed multiplicity, representation/date permutation and stale-tail rebuild; retain original source/premises, no auto-retarget or historical truth |
| Presence | 1,024 three-Event/two-Measure touch/cut/declaration cases with ALL deltas zero (576 known-present answers), original Effect-membership oracle, selected vs retained activity, tail/prefix rebuilds, global stale overlap and retained premises; not historical/external truth |
| Origin queries | Original-Effect generated arithmetic transferred to the current admitted-source query; repeated payloads use distinct Event IDs, not implicit deduplication |
| Validity / decoder / shell | Calendar/reference counterexamples, exact tokens/quanta, unknown/obsolete/truncated/unsupported rows, escaped diagnostics, real CLI exit/stream and unchanged-file checks; no arbitrary corruption/authenticity guarantee |

Shared CLI quantity lexing is checked against independent byte/sign/digit arithmetic:
847 specimens (all eight-symbol strings of length 0–3, all 256 singleton bytes and six
zero/huge literals), 42 lexical successes. Both consumers retain exact values, original
syntax witnesses and their different neutral-zero/Movement admission. Not all strings.
Compiler-command cleanup retains all 48 client bodies, include scopes/options, expected
statuses and diagnostic assertions; positive/negative controls still execute. A one-shot
pinned compiler-parser check found identical location-free ASTs for four layout-only
implementations; this is representation evidence, not a new formal refinement proof.

Large chain/cycle and generated cases supplement, not universally extend, finite bounds.
External compiler clients test public abstractions, wrong qualified source types and private
arithmetic exclusion. Key/Event roles and unqualified/forged Events are rejected;
structural key refusal (exit 1) is distinct from syntax (exit 2). Merchant clients reject
Locus/party/Event role confusion, unqualified lists and incomplete disposition matching;
decoder/real CLI check exact forward references, equal/contradictory duplicates and dangling
Events (admission 1), malformed/misplaced/empty-party syntax 2, unknown quantity 3 without
support, escaped Event diagnostics and unchanged files. The combined per-declaration
duplicate/reference gate and nonempty practical party identity are declared upstream gaps,
not full raw-Core shape/refusal-order parity. Original-amount clients reject unqualified
Event memory, forged amount memories/current associations and original-to-current-quantity
conversion. Decoder/real CLI test exact forward roots/Measures/huge values, semantic
nonpositive/duplicate/unknown/non-root admission 1 vs malformed/misplaced syntax 2,
unsupported quantity 3, escaped root diagnostics and unchanged files. Practical per-row
ordering is not upstream separate-gate diagnostic parity.
Exchange clients reject Event-to-key confusion, forged memories, incomplete endpoint
handling and public Measure_totals access; decoder/real CLI test exact forward claims/keys,
missing/anonymous selectors, duplicate/unknown/third-Measure/net-zero/correction/zero-extra
admission 1 vs malformed/misplaced syntax 2, no-support 3, signed per-Measure outputs,
escaped provenance and unchanged files. Ordinary-only output labels were removed;
this is not full normalized Actual.
Reversal clients reject key/Event confusion, forged memory/pairs, pair-to-quantity conversion
and incomplete role handling; decoder/real CLI test forward exact endpoint facts, key/order
independence, earlier reversal dates, huge quantities, aggregate-only/regrouped mismatch,
open/reused/self/cyclic endpoints, nonzero and independently balanced target admission 1
vs malformed/misplaced/empty syntax 2, unsupported at net zero 3, escaped roles and unchanged
files. Diagnostic ordering is the declared local per-fact/pre-physical gate, not upstream
parity. No theorem was added or rerun; exact-list/source correspondence is bounded evidence,
not a proof of handwritten sorting/arithmetic refinement.
Relation clients reject Event/Relation-ID confusion, unqualified Event lists, forged memories/
positive views, positive-view-to-current-quantity conversion and incomplete endpoint handling.
Decoder/real CLI preserve exact forward IDs/keys/endpoints and huge values; resolve literal
External token HOUSEHOLD without guessing, reject duplicate/open/anonymous/nonpositive/
individual/aggregate/endpoint admission 1 vs malformed/empty/misplaced syntax 2, no-support 3,
escaped source/role/ID diagnostics and unchanged files. SETTLEMENT/PURPOSE refuse,
not silently discarded. Staged whole-family gate is not upstream diagnostic parity; no new
formal artifact/campaign or refinement/truth/operational claim.
Discharge clients reject independent Event-memory generation, Event/Relation target confusion,
forged whole/admitted/remainder views, remainder-to-physical-quantity conversion and incomplete
error matching. Decoder/real CLI preserve exact forward Event/Relation/huge quantities and
plain earlier empty Events; whole-source duplicate/open/self/nonpositive/individual/aggregate
admission 1 vs malformed/misplaced/empty syntax 2, no-support 3, all seven escaped error
variants and unchanged files. Former unsupported DISCHARGE witness became open-reference
admission control; malformed arity and unsupported settlement/purpose controls remain.
Closed acquisition is stricter than upstream target-local crash projection, not a replay of
its activation semantics. No new formal artifact/campaign or external truth/operational claim.
Description clients reject Effect-key/Event role confusion and unqualified lists; parser/real CLI exercise literal/empty
forward-reference text, duplicate/unknown admission 1 vs malformed/unsupported syntax 2,
no inferred support, escaped IDs and unchanged files. Date clients reject Event/revision
role confusion, forged history, omitted Revision handling and public cycle-helper access.
Reader/real CLI test tagged forward references, optional explicit bases/revision-only
sources, missing/ambiguous/open/invalid dates and admission 1 vs syntax 2. Existing Event
models/cycle witnesses qualify the private cycle-mechanism extraction. Clients reject
presence-to-quantity and incomplete outcome matching;
known-present 4 / unsupported 3 are separate real-CLI stdout outcomes. Unsafe casts/
internal-unit access are outside these guarantees.
`compiler_policy.t` checks complete controls and four diagnostic counterexamples in
both dev/release. Strict sequencing and fatal warnings 8/9/11 are not a purity checker.

## Qualification and limits

Normal checks, forced package tests, install and clean engine-only builds are exercised at
relevant semantic checkpoints. Engine builds must leave outer libraries unbuilt. Product
checks pass with nonexistent LEAN. Lock/tooling/platform changes require separate replay;
earlier fresh-switch equality is prior evidence, not a fresh replay for every code edit.

### Main environment rebuilt after Bakhlo directory rename

After PR #2/main 19e1842, compiled main environment retained old loam-ocaml absolute paths;
new switch execution failed with exit 50. User authorized archive/recreate, not path rewriting.
Old _opam/.opam-root/_build moved without deletion under ignored scratch/rename_recovery/
bakhlo-env-v1; task/evidence recorded there. Existing checked manager reused; ./tools/bootstrap
created a fresh root/switch at /Users/user/Projects/moko/bakhlo, fixed registry/OCaml 5.3.0 and
EXACT same 50 package names/versions. Manifest/lock/wrappers/manager hashes unchanged; compiler
stdlib/findlib/registered switch now use Bakhlo path. No source-side rename reverted.

Normal check, forced package tests (-p bakhlo), @install, clean renamed engine-only (no outer
compiled artifacts), final nonexistent-LEAN check and bakhlo CLI help/fixture quantity 990 passed.
Exact package/final logs contain all 151 inline-test execution markers; existing campaigns/cram
retained. Nested RTK/shell package outputs were incomplete (opam usage/empty log), NOT evidence;
raw exact commands were rerun with checked exit statuses. Bootstrap's unresolved release metadata
warnings remain, not fabricated authors/license. 58 synthetic SQLite file hashes and 12 VM file
metadata entries unchanged; archived main environment kept. No OS/global config, source/schema/
semantics, lock/compiler upgrade, optional proof, Linux/VM/outer-trial replay or operational data.
Historical outer switches/VM launch paths were NOT rewritten/requalified by main recovery;
review/recreate those only for a concrete later trial, preserving original storage evidence.

### Unix/SQLite synthetic persistence (bounded outer trial, no Saved qualification)

Question/D/P/R/assumptions recorded before code/install at 930b3ac. Named consumer: supplied
whole synthetic generation -> conditional save -> close/new process -> query/history/receipt.
Ignored scratch/sqlite_review only; no main package/source/lock, global configuration, OS
prerequisite, operational data or VM change. Official sqlite3-ocaml 5.4.2 archive checked,
SHA256 32f68f078f4beaed51ebc279fef46145205fd98cf6c79fe955218601f202621c; MIT source/API/
C-handle/statement/error and discovery review. Thin binding chosen for this trial over owning
C FFI/lifetime/error logic or an ORM/umbrella; no permanent dependency/format adoption.

Separate opam root/switch uses frozen ac27950 registry and EXISTING main OCaml 5.3.0 via
ocaml-system, not a fresh compiler/platform qualification. 35 installed outer packages,
including Base v0.17.3/Zarith 1.14/Dune+configurator 3.24.2/sqlite3 5.4.2; common package
versions match main. 17 outer-only names (including ocaml-system instead of main compiler):
sqlite3/conf-sqlite3, dune-compiledb 0.6.0 and its astring/fpath/ezjsonm/hex/cstruct/fmt/jsonm/
uutf/sexplib/parsexp/num/ocamlbuild/topkg closure. dune-compiledb declares LGPL-2.1-or-later;
SQLite OCaml library has no OCaml library dependencies and links native SQLite, not these
build-tool libraries. No Jane Street endorsement inferred. Main exact 50 packages/lock stayed
identical. Observed root/switch/probe/reference ~118460/83240/8784/572 KiB, not cost guarantees.
Native binary links /usr/lib/libsqlite3.dylib, existing GMP and libSystem. Actual SDK/vendor
SQLite reports 3.43.2, source ID ending 709aapl; pkg-config matches. It is not an independently
pinned upstream SQLite build. Extension loading is disabled by stock Darwin binding discovery.

64 own source/build digests matched current engine plus ONLY the synthetic decoder/quantity
lexer. No CLI/Presentation library linked; only fixture module namespace is used outside the
engine. Reused Irmin synthetic payload/oracle, not third-party/Lean source. Trial outer files:
run/{persistence.ml,publication.ml/.mli,sqlite_store.ml,main.ml,payload.ml}; run-controls.py.
The synchronous publication seam takes coherent-read/conditional-publish functions returning
backend-neutral structured values; source/support admission is separate from SQL and terminal
rendering. Current immutable generation is semantically requalified before the atomic SQL gate
(assumed exclusive trial publisher; legitimate head changes still conflict). No Core I/O/runtime,
dummy health/world, generic command bus, effect monad or household recording operation added.

Trial storage uses explicit provision versus READONLY/NO_CREATE open, application/version header,
STRICT generations/receipts/singleton head, foreign keys and immutable-row triggers. BEGIN
IMMEDIATE compares supplied expected head and stores complete BLOB + parent/request/receipt/
head in ONE transaction. BLOB preserves exact input, including NUL/quote/space/UTF-8 request
and recognizer text; no household quantity enters SQLite INTEGER/REAL arithmetic. Tokens derive
from supplied trial request IDs, scoped to this store, NOT production identity allocation or
household chronology. Fixture v2/schema v1 is a synthetic control, NOT canonical storage.
Exact replay returns the ORIGINAL receipt even with a newer current head; changed payload/base
refuses. Missing store/provisioned empty/version/corruption/busy/input/stored-evidence failures
stay distinct; no init, zero, older-generation fallback or blind republish. No-receipt means
only not observed at this read, not universal proof of non-recording. Resource/transaction
mutation belongs to the adapter; cleanup failure stays explicit.

Final controls-v4 passed: seed/new-process read/update/history; retained old bytes/parent and
180-bit/four-support/zero-versus-touch/unknown/correction/relation provenance/remainder 3->2;
stale expected head, identical replay, changed candidate/base, syntax/over-discharge refusals,
immutable-row checks and two-connection BUSY (not fabricated Conflict). Complete rich example
round-trips byte-for-byte, retaining eight validity facts/Exchange/Reversal; binary payload/
request/receipt control passes. Unsupported schema 99, damaged SQLite header and physically
valid-but-invalid stored evidence yield structured faults; invalid selected evidence blocks
publication. Read/refusal/reconciliation disk hashes unchanged; native process can report these
faults without a healthy household answer. Not an implemented diagnostic host or partial world.

Five synthetic failed-return checkpoints: after generation/receipt/head SQL, before COMMIT,
after COMMIT. All return Uncertain, no publication PASS; next process sees 4 OLD/1 NEW with
old generation and receipt retained. Two REAL process SIGKILL checkpoints before/after COMMIT
reconcile OLD/NEW with no success reply. These are named API checkpoints, NOT SQLite syscall/
sector/torn-write/exhaustive kill or host/power-loss controls. Closed DELETE-mode complete DB
copied to a separate same-host file; bytes/history/receipts/query match, no live/off-device backup.
Initial v1 corrupted-header diagnostic was wrongly classified as generic backend/open failure:
stock prepare raises Sqlite3.Error, so classification now occurs while handle/errcode exist,
not only for SqliteError. v1 source/image/disks/logs preserved; fresh v2/v3/v4 controls passed.
A publication-interface record-label inference mismatch was corrected with explicit snapshot
annotations; no engine/compiler/semantic weakening. No dependency patch required.

Every write connection checks journal_mode=DELETE, synchronous=EXTRA(3), fullfsync=ON(1),
foreign_keys=ON. Official SQLite pragma/atomic-commit/corruption docs reviewed: EXTRA includes
journal-unlink directory sync; Darwin fullfsync requests F_FULLFSYNC. These are real supported
mechanism/configuration candidates, not dummy flushes, but queried flags/COMMIT/readback do NOT
verify this vendor VFS/syscall/device completion, provisioning-directory durability or stable
media. Result deliberately remains Visible_unacknowledged, never Saved. Actual I/O/full-disk,
cache spill/internal writes, crash/power-loss, folder/restore ordering, valid tampering detection,
production version/identity/upgrade/retention/backup and multi-process races remain unqualified.
Supported Linux SQLite path and a durable acknowledgement need separate bounded qualification;
no runtime/filesystem fork is required by this trial.

Clean strict release rebuild and ./tools/check passed; main list/lock and 64 digests unchanged,
no optional Lean/Lima/Linux/SPT/proof replay. Final native image SHA256
 efade4ad2cdb3869fbfa0c194272be8154994aaec193bf9434027beb487d800d.
Final disk digests/control logs/source/outer-switch export retained privately under scratch/
sqlite_review/evidence; v1 classification failure preserved. All final trial handles/processes
closed; VM remained stopped. No permanent adapter/common multi-backend runner/canonical schema,
full Actual, real recording, UI/voice/network or household adoption claimed.

### Linux SQLite syscall failures and retained-journal lifecycle control

Question/owners/D/P/R recorded in HANDOFF at main 0fc0937 before VM/install/code. Named ignored
scratch/sqlite_linux_review and guest /home/loam/sqlite-linux-review; old SQLite/Irmin/SPT trial
sources and disks not reused/rewritten. Scoped moved HOME/LIMA_HOME successfully starts existing
approved VM without YAML/config edits; no shares/agent/X11/public forwards, userns sandbox/global
restriction retained. Guest Ubuntu 24.04.5/x86_64/kernel 6.8.0-142/ext4. Only missing libsqlite3-dev
installed guest-only at existing libsqlite3-0 version 3.45.1-1ubuntu2.8, no runtime upgrade; strace
6.8 already installed. No global host installation/main dependency adoption or compiler change.

Current 64 own Bakhlo engine/decoder/build bytes copied/checked; new namespaces/fixture marker
used, not historical input rewritten. Backend-neutral publication/values reused; adapter SQL
schema remains a SYNTHETIC control, not canonical storage. Fresh ignored ocaml-system switch
uses existing guest native OCaml 5.3.0 and frozen ac27950 registry: exact same 35 names/versions
as reviewed Darwin trial, native guest/main 50 unchanged. Native binary links system
/lib/x86_64-linux-gnu/libsqlite3.so.0 (3.45.1, vendor source ID ending 57ccalt1), GMP/libc; no
CLI/Presentation/Core/Async/Lwt/Lean. Full earlier logical save/read/history/conflict/replay/
BUSY/refusal/rich/binary/failed-return/SIGKILL/closed-copy baseline passed with Bakhlo marker.
Not a fresh full Linux ordinary suite or production adapter/representation qualification.

DELETE/EXTRA/fullfsync settings: successful trace observes journal fdatasync, creation-directory
fdatasync, journal fdatasync, database fdatasync, journal unlink, deletion-directory fdatasync.
Returned-error injection covers 5 fdatasync EIO + all 34 pwrite64 EIO + all 34 pwrite64 ENOSPC
points of that one update (73 cases). 72 Uncertain: 71 reconcile OLD, 1 NEW after deletion-dir
error; remaining case is visible-unacknowledged NEW despite creation-dir EIO. Entire DB/sidecar
family unchanged by cold read/reconciliation. EIO maps IOERR; ENOSPC maps FULL; finalize/rollback
secondary errors retained, including SQLite already-auto-rolled-back cases (not silently
corruption/zero or proof of non-recording). Injection is syscall RESULT failure, not physical
I/O/full-device exhaustion, short/torn writes, sector reordering or exhaustive timing.

Counterexample preserved: stock SQLite ignores its one-time creation-directory sync error and
COMMIT can succeed. Version-tagged official SQLite 3.45.1 os_unix.c unixSync inspection explicitly
confirms that behavior (directory fsync portability fallback); not a full vendor-patch refinement
or new public issue claim. fullfsync=ON is no Darwin F_FULLFSYNC qualification on Linux.
Successful COMMIT/flags are therefore insufficient for the required all-sync-failures contract.

One separate STANDARD PERSIST mode control, no SQLite patch/custom VFS/filesystem/fork: retained
journal file, checked outer Unix directory fsync after provisioning/before write-open, refuse
missing journal rather than recreate it, synchronous=EXTRA and same immutable-generation SQL.
Assume exclusive namespace owner/prequalified durable parent path; this is NOT adopted policy.
Successful trace has checked directory fsync + five fdatasync calls and no unlink. 76 returned
faults: 1 pre-candidate directory EIO refuses with unchanged family/OLD; 74 Uncertain (71 OLD,
1 NEW, 2 read-only acquisition refusals); 1 visible NEW on redundant SQLite creation-dir EIO,
with required existing namespace independently synced before publication. This supplies a
maintained-path candidate, NOT proof of stable media/complete lifecycle or durable Saved.

Two final journal-header write failures (EIO/ENOSPC) leave hot journals: read-only open returns
structured READONLY/no complete household answer, not stale/empty fallback. Separate copied
families undergo EXPLICIT writable SQLite recovery; both cold-requalify/reconcile OLD, original
fault images unchanged. Trial handle-first shell is not a production admission-before-effects
entrance; valid named controls do not qualify rejected input with pending recovery. Production
must admit before effectful open/activation. Write-open can perform recovery then refuse MISSING_JOURNAL because
SQLite recovery removed it: that error is NOT proof nothing changed. Missing journal alone
refuses writes but valid independently admitted DB read remains available. PERSIST stopped
DB+journal-family restore/history and before/after-COMMIT SIGKILL OLD/NEW passed; no live,
off-device restore or universal diagnosis host. No automatic repair/retry/current-world fallback.

Both clean strict release rebuilds identical; graceful VM stop/start cold restore/history and
isolation passed (not power loss). Source/archive checksums, exact package exports, syscall
traces, all failing/successful families, structured refusal/recovery logs retained privately.
Checked guest-to-host own-source/evidence archive excludes disks/builds/environments/third-party
source. VM stopped, final loopback management listener absent; main Mac ordinary check passed.
No main executable/dependency/schema/semantic change, optional proof/new model/campaign, UI/
voice/network entrance, operational data/cutover, public issue/PR/release/push. Visible remains
unacknowledged; provision/restore ancestor-directory ordering, lifecycle/cleanup contract,
actual device-error/power-loss and maintained production identity/encoding/Saved remain open.

### MirageOS hosted feasibility (one-shot, not production support)

Engine 1b81a2d on Darwin x86_64; official Mirage 4.11.2 source/target APIs inspected,
archive SHA256 `2cbd7924f82d85ad8ed6bab2f8dc95e6bd15a723532193b56af01813ab20b1a7` checked.
Pinned registry ac27950e5eac6c981ad809dff370c937820b7893; independent ignored scratch
root/switch, reused ocaml-system 5.3.0 compiler (not fresh compiler qualification), Dune
3.24.2/Base v0.17.3/Zarith 1.14/intrinsics v0.17.2/sexplib0 v0.17.0. Trial-only Mirage/
mirage-runtime 4.11.2, mirage-unix 5.0.1, Lwt 6.1.2, cmdliner-stdlib 1.0.1 and mirage-sleep
4.1.0 have a concrete outer configure/entry consumer; 51 trial installed selections
(40 initial dry-run installs + two startup dependencies + compiler/base packages), not
51 additions to main. No Core/Async/Irmin/overlay/OS install/main dependency adoption.

60 own lib/application source/build files copied byte-equal. Config main local_libs are
loam_ocaml.domain/application with exact Base/Zarith constraints; configure macosx/no-depext/
no-extra-repo, no argv/reporter/ptime/mtime/random, default_sleep for generated startup.
Built with installed scratch dependencies, NOT monorepo lock/pull/freestanding build;
executed Mirage-generated Unix_os.Main.run, no Presentation/CLI compiled artifacts.
Passed 180-bit addition/inversion, exact corrected source, origin/opening/assertion/presence,
net-zero touch/unknown refusal, retained relation source/remainder 3 and unknown/self/
missing/zero-Effect refusals. Wrong remainder expectation 4 failed at runtime (2, empty
stdout, conditional-remainder witness); restoration passed. Initial no_sleep configuration
failed at generated Mirage_sleep startup-delay reference; default_sleep + proper package
passed without editing generated runtime/engine. Not all device configurations qualified.

Recipe: tools/opam subcommand then explicit --root/--switch; expose main _opam/bin for
reused compiler and trial-bin-before-main PATH plus trial OPAMROOT/OPAMSWITCH for nested
Mirage/Dune commands. Configure in ignored scratch probe,
`dune build --root . dist/loam-mirage-probe`, run native output. Private selection/logs/downloads/generated
metadata/probe remain disposable scratch, not committed adapter or maintained smoke suite.
Host GMP 6.3.0 libgmp.10.dylib/libSystem linkage is NOT Solo5/static-GMP evidence.
Solo5 0.13.0 + ocaml-solo5 1.2.0 Darwin availability dry-run failed (5); metadata accepts
5.3.0 but requires Linux/BSD host. No suitable VM/container/HVT runner on PATH; no Solo5
link/boot, freestanding Base intrinsic/GMP C-stub qualification, full suite in Mirage,
network/storage/recovery/performance/household-use claim. Main 50 selections unchanged,
ordinary/Lean-free checks pass. Next: supported Linux x86_64/Solo5 with explicit static
closure, actual boot, same queries and negative controls; revisit versions/target changes.

Subsequent target preflight read Solo5 v0.13.0 README/docs building/architecture from the
opam-checksummed release (SHA512 cb2f9ea7140d09796dfe2cd5496d9bab858ce1f2144ecaf62cd8f5c9291bcfde8547cd2f42382dea07bd8dcc1ea7173b86ef2ca35247a92a5ed6bfa2ccf056f2).
Linux HVT requires usable KVM access; merely having a VM/container does not establish
nested virtualization. SPT is a freestanding guest under a Linux seccomp process tender,
not hardware-virtualized HVT; upstream labels it experimental and requires libseccomp
>= 2.3.3 on x86_64. It is a possible initial test without KVM, not an endorsed production
substitute or proof of HVT support. First smoke needs no disk/network/TAP setup. Both
require an agreed supported Linux environment; neither was configured/built/booted here.

### Isolated Linux VM and Solo5/SPT preflight

User approved a disposable development VM after confirming no Linux environment.
Observation branch at ff3202c; local Lima 2.2.1 Darwin x86_64 release SHA256
`6b776e4bc41f358e6ee01fefcc78e2eb26f11635a0fcff632234af77a566c6c4` matched published
release asset digest. macOS 15.7.9/Intel i5/16 GiB RAM/native VZ; alternatives UTM/manual
or global brew/QEMU setup were considered, not benchmarked. Keep-observing tool status,
not measured superiority/general CI adoption. Fixed Ubuntu noble release-20260926 image
SHA256 `6a81c37564db9b1ee84e141922625e1d7c5b389b99bb3c572e0243607d5bb4d2`, no fallback;
actual guest Ubuntu 24.04.5 LTS/kernel 6.8.0-142-generic/x86_64. 2 vCPU/4 GiB/24 GiB sparse
virtual disk. Private LIMA_HOME/plain mode, no workspace/home mounts or inherited host
SSH keys/agent/X11, containerd or guest-agent service; guest mountinfo and host-path/agent
absence checked after restart. Managed SSH listened only on 127.0.0.1; outbound package
networking allowed. Not an air gap or a comprehensive malicious-guest/supply-chain audit.

Boot, guest-only signed apt prerequisites (GCC 13.3.0, make 4.3, GMP 6.3.0, libseccomp
2.5.5), seccomp CONFIG_SECCOMP/CONFIG_SECCOMP_FILTER=y verified; no /dev/kvm as expected.
Only selected Solo5 v0.13.0 source archive transferred, SHA512 checked in guest against
opam digest recorded above; configured/built with -j2. Upstream standalone C test_hello.spt
executed via solo5-spt --mem=32, reported bindings v0.13.0/hello/solo5_exit(0); non-ELF
synthetic input refused (1, empty stdout, invalid-executable/ELF-header diagnostic).
Graceful stop/restart and repeated isolation/hello checks passed, stopped at handoff.
Cold image download ~597 MiB; one final allocation ~2.3 GiB guest disk/4.9 GiB trial tree,
not workload/latency guarantees. Prerequisite package versions are mutable distro evidence,
not a hermetic OS lock. No host brew/OS installation/login hooks or main lock changes.

Initial XDG_CACHE_HOME did not redirect Lima's macOS Go cache: the owned image-cache
bucket was moved from ~/Library/Caches/lima into scratch, future commands scope HOME as
well as LIMA_HOME. Restart verified with scoped HOME; only that owned bucket moved.
Empty findmnt output returned success, so absence evidence uses raw mountinfo rather
than that status. Negative-control diagnostic-case and unset-variable harness errors
were corrected and checks repeated; they were not hidden as passing isolation results.
Downloads/keys/VM/config/private logs/build artifacts remain ignored, no upstream source
copied into product. This confirms Linux build-host and C/Solo5-SPT plumbing ONLY:
no Linux ordinary OCaml suite, Mirage/Base/Zarith engine SPT image/static GMP C stubs,
HVT/KVM/network/disk guest, Irmin/storage/crash/recovery or household use qualified.
[Development](DEVELOPMENT.md#approved-isolated-linux-vm-development-trial) owns local
start/stop/teardown recipe; next consumer is actual unchanged engine static link/boot.

### Linux native replay and MirageOS/Solo5-SPT engine (bounded, trial guard required)

At a36c584, user approved actual engine boot before early Irmin persistence evaluation.
133 selected own source/build/test files + synthetic example transferred with SHA256;
no git/environment/operational data. Guest fresh tools/bootstrap compiled OCaml 5.3.0,
installed all 50 lock selections exactly. tools/check: 151 expect tests/unchanged ten
campaigns/100,000 generated cases/three cram suites; forced package tests, @install,
nonexistent-LEAN check and clean native engine-only passed, no outer compiled artifacts.
Bubblewrap was missing; guest-only apt installed it. Ubuntu AppArmor then denied uid-map;
its distro /usr/bin/opam profile does not match local tool. Same userns allowance scoped
to /home/loam/engine-native/.tools/opam, global restriction and opam sandbox remain enabled.
No host OS/config changes; Linux baseline selections stayed unchanged after cross trial.

Separate guest scratch root/43-package switch reuses that fresh compiler via ocaml-system;
Mirage 4.11.2, ocaml-solo5 1.2.0, ocaml-src 5.3.0, Dune 3.24.2, opam-monorepo 0.4.3.
Initial Solo5 0.13.0 did not match generated Mirage bound <0.13.0: selected 0.12.1 and
rebuilt cross compiler, did not bypass constraint. Main manifest/50-entry lock unchanged.
Official dune-universe overlay fixed at 632df22c65362cb34fd792f701d7d2a6518cdb60 (archive
SHA256 41d610eeb7c0bc2ed77c0db989bf20c18627d70e2fe67f19124d914218dfbece) + frozen ac27950
registry. Cross closure 64 entries/25 source pins: Base v0.17.3, ocaml_intrinsics_kernel
v0.17.2, sexplib0 v0.17.0, Lwt 6.1.2, mirage-runtime 4.11.2, mirage-solo5 0.10.0.
Trial Zarith 1.14+dune+mirage1 SHA256 915bd53ebb608729eb76b4e5bc0580090d8428fe919c9bf9a5dcd39f739b49f7:
z.ml/.mli, q.ml/.mli, big_int_Z.ml/.mli and caml_z.c byte-equal to upstream 1.14; configure/Dune
packaging differs, not claimed a general refinement. GMP 6.3.0-1 Dune cross package SHA256
cafe5beff5f35cb4451e341e1c07a019ac7047dd280ff55410e42ccc133bb757; underlying GMP 6.3.0.
Both roots isolated, explicit main compiler PATH/trial opam exec + nested env needed.
Monorepo 0.5.0 AND 0.4.3 stock lock failed current-switch detection here; explicit frozen
repositories and actual guest global-opam-vars (including monorepo marker) resolved.
A marker-absent lock omitted engine deps and was rejected, not boot evidence. Compiler/
core package pins verified before pull/build; no invented defaults/availability bypass.

mirage configure -t spt, no depext/disk/network/argv/reporter/time/random, default_sleep;
monorepo lock/pull, dune release cross build -j2 with original strict-sequence/8/9/11 flags.
60 engine source/build files byte-equal. No engine or generated runtime source edits.
UNMODIFIED vendored Lwt build first pulled in unselected lwt_runtime_events and failed
fstat from OCaml runtime-events consumer. Dune --only-packages cannot mask vendored libs.
Trial-only duniverse/lwt/src/runtime_events/dune adds (enabled_if (<> %{context_name} solo5)):
stock Lwt select uses its existing without-events implementation, no dummy fstat/no
numerical weakening. Clean rebuild confirmed no tracing CMXs/outer libraries. Thus this
is NOT stock dependency-closure support or a maintained/release-ready Mirage adapter;
revisit proper package-selection/upstream fix before permanent adoption. Shell PS1 warning
was scoped away for final clean build, no guest global shell edits.

Actual generated Solo5_os.Main.run loaded by matching solo5-spt --mem=128: 180-bit add/
inverse/signed corrected source, four supports, unknown/net-zero-touch refusals, retained
relation source/partial remainder 3 and missing/self/zero-Effect refusals passed (0).
Wrong expected remainder 4 failed (2, conditional-remainder witness, NO PASS; diagnostics
on guest stdout), restored 3 passed. Restored image matched its pre-control SHA256;
clean build/static inspection and VM stop/restart with same image/isolation passed.
ELF x86_64 EXEC/Solo5 SPT ABI 2/empty devices, no dynamic section/undefined symbols;
GMP code linked in image, no host GMP dylib. PT_INTERP is intentional /nonexistent/solo5/
sentinel, not a Linux dynamic loader (initial no-INTERP check corrected). Image 7,872,208
bytes, SHA256 b1d24be5139f428157139eb443ae1b7d31404d4e00dbf57f2eebe9072ac9c66a; one
restoration hash equality is not universal reproducibility. VM stopped; ignored private
logs/scripts/sources/lock/image retained, nothing third-party/generated committed.
No full test suite IN SPT, HVT/KVM, target choice, devices/I/O, Irmin/storage/crash/recovery,
real data/household use, source-install client qualification or optional proof replay.
Next named consumer: bounded Irmin backend durable record/reopen, with concrete generation/
admission/retry/recovery contracts; no storage format/authority follows from this boot.

### Irmin block persistence (bounded, two trial dependency fixes required)

At fa113a6 user approved continuation toward MirageOS + Irmin, not main dependency/schema/
data adoption. Question/owner and D/P/R/instruments recorded in HANDOFF before prototype;
additional stock retention failure/reachability-control question recorded before patching.
Only selected own/synthetic source; no household data or sibling build/modification/source
copying. Read-only f441f91 sibling status/remaining-cutover route is a historical reference,
not full parity or operational migration evidence. Ordinary engine/parser evidence reused;
no new model/theorem/random campaign for outer plumbing.

Official Irmin 3.11.0 archive SHA256
`09996fbcc2c43e117a9bd8e9028c635e81cccb264d5e02d425ab8b06bbacdbdb`,
Chamelon 0.2.1 `782b84fc81d7bf34fe10442437c6c507ca7ada2c9c822970cc23261be6a5178c`
checked; both declare ISC. Irmin Mirage helper supplies clock-based info, not storage;
examined Git.Mem-oriented wrapper did not establish guest-local persistence (remote push/
sync out of scope). Mem cannot persist; Unix pack/fs does not establish freestanding I/O.
Irmin-fs logs bad value decode and returns None; bad keys may be skipped, unacceptable as
an unqualified LOAM boundary. Trial consumer instead uses Irmin CA/AW makers over Chamelon
KV + Solo5 BLOCK_BASIC, with a small owned backend: strict binary decode/hash verification,
byte-identical append-only collision check, one borrowed FS/mutex, closed handles, serialized
local CAS. Watch/clear explicitly unsupported, not fake success. Batch is NOT a transaction;
no multi-process/multiwriter/crash atomicity claim.

Same approved Ubuntu guest/root/compiler/43-package host switch, no new OS prerequisites.
Frozen registry/official overlay and explicit actual monorepo variables as above. Cross
closure 93 entries/65 package-source pins (59 distinct URLs), not installed-package counts;
core/compiler/runtime/GMP/Zarith pins unchanged. New consumed selections include irmin/
ppx_irmin 3.11.0, chamelon 0.2.1, repr/ppx_repr 0.8.0, digestif 1.3.1, checkseum 0.5.3,
cstruct/ppx_cstruct 6.3.0, mirage-kv 6.1.1, mirage-block 3.0.2/block-solo5 0.8.1,
mirage-ptime 5.2.0, optint 0.3.0, ocamlgraph 2.2.0, JSON/UTF/PPX support, parsexp/sexplib
v0.17.0; no Core/Async. Vendor selection changes ocamlfind 1.9.8 -> 1.9.5+dune and uutf
1.0.4 -> 1.0.3+dune in CROSS lock only, not native switches. Native macOS/Linux lists remain
all 50 main lock entries exactly; main manifest/lock/tools/formal untouched. Dependency
cost is meaningful: no implicit adoption merely because a freestanding build succeeds.

Mirage configure SPT/default argv/sleep/ptime, no reporter/mtime/random/network. Actual
POSIX clock needed for FS write metadata, not household date/commit chronology; supplying
no_ptime failed Ptime_clock unsupported-platform, corrected through SDK, not dummy time.
One exclusively owned 32 MiB synthetic disk, one process/tender at a time, --mem=256;
explicit format with program-block size 16 (upstream tests), NOT the sector size 512.
Initial 512 caused allocation abort even at --mem=512; direct root-write/bounded GC controls
passed, corrected configuration proceeded. Long 128-hex-character hashes exceeded FS's
32-character name bound; shard full hash into 16-character components, never truncate.
Trial main-branch key bound is explicit; not arbitrary branch/path support.

76 own engine/CLI/Presentation source/build files byte-equal; selected CLI archive and final
probe archive checksums verified in guest and extracted file digests matched. Engine and
parser unchanged, no generated-runtime edits. Trial storage is ONE Contents.String fixture
blob at snapshot per immutable commit, including raw source/support/provenance, synthetic
v2 marker only; no canonical format/unknown-section/full Actual claim. Read exact commit
once, then decode/source/query admit from those same bytes, recompute quantities/remainders.
Publisher qualifies before writes, checks expected head, creates immutable objects/parent
then head CAS; stale update refuses without auto-merge/retry/retarget. Missing/unformatted
read refuses, never auto-formats/initializes. Commit info timestamp 0 is explicit synthetic
storage metadata, not Event/date evidence; derived answers not persisted.

**Stock Chamelon FAILED retention.** Initial save/process reopen passed. Update changed
head and new generation reopened, BUT old Contents lookup failed Irmin hash verification;
no successful update marker. Independent KV-only first-file save -> new process -> second
file write -> first-file reread reproduced changed old bytes (2, no retention PASS).
Fs_internal.Traverse.get_ctz_pointers stopped at index 1, while File.last_block_index starts
at 0; two-sector values left first data block out of reachability/free-space accounting.
Trial-only change `| Ok l, 1 -> ...` to `| Ok l, 0 -> ...` then passed SAME independent
control and new-disk Irmin old/current retention. This strongly isolates the bounded issue,
not a general filesystem correctness proof. Unmodified 0.2.1 is disqualified for this
workload; do not call the guarded result stock/production storage support. Prior Lwt
runtime-events Solo5 Dune guard also retained. Neither third-party patch is committed or
adopted; maintained resolution/alternatives/patch ownership must precede promotion.

Guarded controls passed: 180-bit signed corrected arithmetic, all four support families,
net-zero touch/unsupported versus supported zero, retained original relation source and
remainder 3 -> 2, unknown relation not zero; exact bytes/history/parent retained. Separate
process save/read/update and cold old/current history after graceful VM stop/restart passed
with same disk/image SHA256. Unsupported fixture syntax, invalid over-discharge, stale
expected-head/CAS and unsupported watch refused; before/after whole-disk hashes identical.
Deliberately malformed head on separate synthetic disk refused 2/invalid hash-size witness,
NO read PASS, unchanged corrupt disk; no decode-to-None. A failure after publication may
have changed head (stock counterexample did); abort/no success, not blind retry or rollback.
This does not implement a production uncertain-result/recovery protocol.

Clean release cross rebuild with original strict-sequence/fatal 8/9/11 flags passed;
no tracing CMXs, ELF x86_64 EXEC/Solo5 SPT ABI 2, one store BLOCK_BASIC manifest/no NET,
no dynamic section/undefined symbols; expected nonexistent Solo5 INTERP sentinel. Image
12,671,416 bytes SHA256 `8c7705573a1c6381eb944ef9f36e13024824b8e6d84bffef957658bf1b95f76d`;
lock `ee466c3cca82215cb795a437af37523242addd60161d500297dd7f0037dd413f`.
Clean rebuild matched image hash and boot/history controls; not universal reproducibility.
Nonfatal /etc/bash.bashrc PS1 diagnostics remain in this clean build log; scoped ENV/PS1
attempts did not remove all, no global shell change. Original engine-probe image unchanged.
macOS ordinary suite passes; no full suite IN SPT/source-install/other-platform/proof replay.
VM STOPPED, logs/archives/locks/disk/source/build private ignored scratch, no listener.
No abrupt process kill/power-loss, device flush/barrier, torn-write/disk-full/I/O-error,
backup/restore/migration, large/many-block reliability, useful input UI or household authority
qualified. Revisit those failure models, backend/format/runtime/device/clock/scale before
adoption; success here establishes only a guarded bounded storage/reopen path.

### Storage route preflight (source/metadata only; UI deferred)

User prioritized storage/reliability and deferred Bonsai. Question/D/P/R recorded before
inspection; no VM boot/build/dependency adoption. Official GitHub/read-only source checks:
Chamelon latest release remains v0.2.1; non-archived main 3cb012b65c63df9b5d84ba995c04fcf625b4cf09
(2025-10-09) still stops CTZ traversal at index 1. That main commit fixes directory size,
not our independent first-data-block counterexample. Maintenance timestamps/non-archive
status are observations, not support guarantees. Issue #21 reports different model-found
bugs; maintainer says those were fixed before v0.2.1, so open issue label is NOT evidence
that the reported bugs remain or that our issue is already reported. No issue/PR filed.

Bounded alternative check, not an exhaustive search: Wodan main
fd70abdb45fa176557178435217e0ab114e4e4d0 (2021-09-16) has Irmin backend, but published
README targets Mirage 3/OCaml 4.08–4.11 and hardening remains open; manifests pin forked
block APIs/nocrypto, lru 0.3.0, Unix packages in Irmin binding. Not in frozen registry;
port/closure/key-size/value-size/flush cost is substantial, not a drop-in maintained choice.
Frozen fat-filesystem 0.15.1 requires Mirage_kv >=4 <5 and Unix block dependency, versus
trial KV 6.1.1; no compatibility/retention claim. git-kv 0.2.3 is Git-oriented with network/
sync closure, not demonstrated local block storage; SNKV metadata describes SQLite-engine
FFI, not freestanding I/O. These observations do not rule out every alternative or choose
one. Do not implement a new filesystem just to avoid an explicit dependency decision.

Matching Solo5 v0.12.1 source raises an INDEPENDENT durability gap: common block_attach
opens O_RDWR (no O_SYNC/O_DSYNC); SPT block write calls pwrite64 and returns on full length.
Public ABI has read/write/acquire, no flush; SPT block seccomp setup admits pread64/pwrite64,
not an added fsync/fdatasync boundary. Hence current file-backed clean restart evidence is
NOT durable acknowledgement after host crash/power loss, regardless of the CTZ fix.
First guessed tender-source path returned 404, corrected to spt_module_block.c; no empty
file used as source evidence. Sources read at explicit tag/HEAD where cited, no patch/build.
Next define saved/rejected/conflict/uncertain outcomes and required persistence ordering/
barriers, then qualify a maintained target/backend/fix route with retention + fault/restore
controls. No dummy sync, compiler downgrade, semantic weakening or adoption follows.

### Guarded block retention, interrupted publication and offline restore controls

After 683dbd5 user reaffirmed MirageOS + Irmin/new-value exploration WITH maintainability,
then approved continuation, not SQLite pivot/new FS/main dependency/fork/public reporting.
Question/D/P/R/failure bounds recorded before scratch code; same approved guest, 93-entry
cross lock, compiler/core/engine unchanged. 76 own source/build digests matched, original
Irmin image unchanged. No new OS prerequisites or package install. CTZ/Lwt trial guards
still REQUIRED, unmodified tender; no new sync primitive or stable-media claim.

New separate guest /home/loam/storage-controls and fresh 32 MiB synthetic disks; original
success/counterexample disks never formatted. Direct KV byte oracle, 16 sizes 0/1/127/254/
255/256/257/507/508/509/1023/4095/4096/8192/32768/65536: first generation checked after
writes, next process append of another generation rechecks ALL old/new bytes, cold process
and graceful VM restart reread passed. Only bounded shapes/allocator history, not general
FS correctness, arbitrary size, overwrite/delete/disk-full or torn sectors.

Same synthetic Irmin seed/update source and parent: 180-bit/four-support/unknown/provenance/
remainder 3 -> 2 checks reused. Update made 95 Mirage_block.write API calls. Every before/
after call point injected a failed promise without FS close: all 190 refused with no
publication PASS, next-process actual head decoded/hash-checked as supplied old OR new,
retained old commit/blob always exact. 186 OLD / 4 NEW: failed call can follow publication,
so "failure means not recorded" is falsified. Driver may split ONE API call into multiple
512-byte writes; this does NOT cover interruption inside a call/partial-sector I/O or all
ordering/interleavings. No fallback/merge/repair. Recovery disk digests remained unchanged.
Four actual tender SIGKILL controls paused before/after selected API calls (1,94,95):
2 OLD / 2 NEW, no publication success, same next-process checks/read-only digests passed.
These are process-failure evidence under a live guest OS/cache, NOT host/VM power loss.

Tender-stopped complete disk copied to separate file, exact bytes/digest and old/current
history verified, then repeated after graceful VM restart with same disk/image hashes.
This is offline same-guest copy/restore, not live-consistent/off-device backup or hardware
failure recovery. Clean strict release rebuild matched final image SHA256
0eb115af5b7ed237252f76d0d689a538d36b436e2d2ec92033f7f15cfd1122ce; SPT ABI2/static/no undefined
symbols/no tracing CMXs, one BLOCK_BASIC/no NET, prior lock SHA256 unchanged. Original
8c770557 image unchanged. Archive transfers/checksums, macOS tools/check and isolation passed;
VM STOPPED. PS1/cross-configure diagnostics and macOS archive provenance-xattr warnings
retained. First shell harness mutated caller label, causing missing digest filename; corrected
using positional args/new disk/evidence names. Initial elftool PATH and driver source-path
checks corrected before inspection; failures are NOT storage counterexamples.

Official Solo5 issue #330 remains open and discusses ordering/durable barriers, including
2025-10 discussion; no supported flush earned from issue text or maintainer promise, no
public issue/PR filed. Source/clock/device/package provenance assumptions remain. Maintained
CTZ/Lwt selection AND actual durability boundary/ownership remain prerequisites; current
contracts separate visible/reconciled state from Saved. No household authority/production
API, idempotency/retry protocol, power loss, real I/O error/torn-write/full-disk campaign,
backup policy/migration, full suite IN SPT or full Linux native/proof replay newly qualified.
Ignored source/logs/images/disks retained; no permanent dependency/third-party source commit.

### Client toolkit preflight (metadata only, not a UI qualification)

After 28541ba user requested laptop/phone/AI-chat recording and viewing, desktop Notty
preferred, optional Bonsai browser trial. Named consumer/question/instruments recorded in
HANDOFF before review; no installs/build/browser/network test or main lock changes.
Frozen ac27950 registry: notty 0.2.3 (ISC) permits OCaml >=4.08 <5.4, Dune >=1.7,
cppo/uutf, optional Lwt; direct gates fit current OCaml 5.3.0/Dune 3.24.2, not solved-closure
or terminal/platform evidence. bonsai v0.17.0 (MIT) requires OCaml >=5.1, Base/Jane Street
v0.17 and substantial Core/Async/ppx_jane/Incr_dom/Virtual_dom/RPC/web dependencies.
Dune >=3.11 <3.24 excludes main 3.24.2; js_of_ocaml >=5.1.1 <5.7 admits compiler versions
5.1.1/5.2.0/5.3.0/5.4.0/5.5.2/5.6.0 in this registry, ALL exclude OCaml 5.3 (latest two
allow <5.2). Thus stock Bonsai v0.17 cannot simply be installed into the qualified main
switch. Revisit a separately reviewed browser-only toolchain or compatible maintained
release/alternative, not silent backend downgrade/constraint bypass/Number-based quantities.
js_of_ocaml 5.6.0 binds compiler = version and declares GPL-2.0-or-later / LGPL-2.1-or-later
WITH OCaml-LGPL-linking-exception; distribution/component obligations need separate review.
Full transitive closure, browser behavior/mobile ergonomics and any independent frontend
compiler remain unqualified. UI deps must stay outer; no Jane Street endorsement inferred.

[Optional specification](../formal/README.md) states nine row-selection, signed-delta and
whole-premise lookup laws. It does not prove graph admission, group indexes, Actual/support
truth, OCaml/Base/Zarith refinement, loading or durability. Recheck artifact/assumption/
correspondence changes, not every unrelated consumer edit.

A prior one-shot native synthetic probe at `1d3de2f` measured source/image/query CPU costs
for 1,000/10 and 10,000/100 Events/groups, singleton roots, empty cuts and 10,000 alternating
queries. The larger image took about 1s on this host; parsing/I/O excluded. This is not a
maintained benchmark, target or current latency guarantee. Group construction repeats
source walks; revisit with named workloads/limits before optimizing or choosing a cache.

Storage/publication, other Linux/Apple Silicon targets, full evidence families, household
authority and large-history operational reliability remain open. Do not relabel absences as coverage.

## First-run empty-book creation

The interactive `--book FILE` entrance now offers explicit initialization after
the selected book fails to load. A missing path is initially suggested as the
destination; an existing unreadable source starts with an empty destination.
`Daily_book.empty` validates one Measure and scale (0–9), and starts with an
explicit empty Locus policy so the existing Manage Loci path can admit the
first Locus. It creates no Actual, Scheduled plan, opening support, or observation.

`Daily_file.create_empty` serializes the v3 monolithic candidate, uses the existing
exclusive `write_new` path (mode 0600, file fsync and read-back), syncs the parent,
then cold-loads and compares the exact bytes. It does not create the parent directory.
Existing `Daily_file.load`, `--check`, recovery and non-TTY startup remain fail-closed.
An uncertain/failed create is not retried automatically.

- `./tools/check`, `./tools/build-bonsai-tui` and `./tools/tui --self-check` passed.
  Permanent self-checks cover empty-book roundtrip/admission, first-Locus admission,
  Measure/scale refusal, missing-path prefill, unreadable-source blank destination,
  review without writes, review Escape/Edit returning to retained inputs, editing Escape
  cancellation, tiny-review refusal, existing-target refusal/byte preservation, and
  exclusive creation/cold reopen.
- At 80×24 with a fresh synthetic scratch path, entered `jpy`, scale 2. Review
  showed the exact destination and explicit absence of records/support; the file did
  not exist before confirmation. At 20×5, Enter did not create the file and displayed
  the resize notice. After restoring 80×24, Enter created the book and opened Home;
  a separate `./tools/tui --check` cold load passed.
- A separate 80×24 PTY opened a malformed synthetic source with the destination
  blank. Escape exited without creating a destination; the source SHA-256 remained
  `cce23fc81392be8d73602089eb439f29a016d9cef3db139924058cc7a330478b`.
- Non-TTY startup for a missing `--book` returned the existing fail-closed refusal:
  `input/file/terminal unavailable; no empty fallback`.

No LOAM source/binary comparison or live data was used. This is local first-run
behavior evidence, not LOAM parity acceptance, manual IME acceptance, P7 durability,
or operational-cutover approval.

### Paired first-run review cancellation (2026-10-17)

At 80×24 on a private tmux socket, the existing LOAM binary
(`0ed043cf04349d2a66afe84e2a12837557df8d873450dc487afa88cf354fca97`)
opened a missing synthetic root under ignored `scratch/first-run-parity-KMSzp4/`.
Enter showed its independent-household confirmation; Escape returned to editing
with the destination intact. Editing Escape then exited; the root was absent.
LOAM source/binary correspondence was not established.

Before this fix, Bakhlo's first-run review showed `jpy` scale 0 but Escape exited
directly. After the change, review Escape returned to editing with destination,
Measure and scale intact; editing Escape exited. The review button now says Edit:
selecting it returned to editing and Enter reopened the same review without
writing. The synthetic book and LOAM root were absent after both cancellations.
`./tools/tui --self-check` (including retained-input and Edit-button regression
checks) and `./tools/check` passed. This comparison covers the missing-root
review/cancel path only, not existing-unreadable-root parity, creation durability,
other dimensions, IME or operational adoption.

### Paired existing-unreadable-root first run (2026-10-17)

At 80×24 on a private tmux socket, LOAM source was
`a4c5d7b87e17e3ff38a9e2517fa81ddda75e12fc` and its existing binary
SHA-256 was `0ed043cf04349d2a66afe84e2a12837557df8d873450dc487afa88cf354fca97`
(source/binary correspondence unverified). Bakhlo HEAD was
`58f8bdc0db4b94a1bc4eab98e8a82c9292e6cdcc` with the local first-run
change uncommitted; its built binary SHA-256 was
`47f36d16fd59b0aceb73f7850f767082c855415fe00ddefacc72dfb2eba7c27d`.
Only private synthetic inputs under ignored `scratch/first-run-unreadable-f1qv1p/`
were used: an existing LOAM directory lacking household authority with a
sentinel file, and a Bakhlo book file containing invalid bytes.

Both first-run editors left the new destination blank, rather than prefill an
existing unreadable selection. After choosing a *different* unused destination
(and `jpy`, scale 0 for Bakhlo), both showed a non-writing review. Escape returned
to editing with the chosen destination intact; a second Escape exited. Neither
destination was created. The LOAM sentinel SHA-256 remained
`7e45282f56548180e307ffa642a98e3c3bd604e23727e48bbfccf0719b825173`;
the invalid Bakhlo source remained
`d117a2e75ce27b87e2d04daa6c93070e4b71d83501a90cfb2ee4b58cbae74f09`.

A second run chose each existing source *as* destination. LOAM displayed
review then refused creation and returned to editing with a distinct
`destination already exists` error; Bakhlo refused before review with
`That file already exists`. Source hashes remained unchanged, and the LOAM
directory still contained only the sentinel. The earlier Bakhlo local
`./tools/tui --self-check` covered exclusive-create refusal; no new code
or test suite was run for this comparison. This is not a paired successful
create, malformed-household parity, failure injection, other dimensions,
IME, durability/P7 or operational acceptance.

## Paired fixture setup smoke (2026-10-16)

Private synthetic trial under ignored `scratch/paired-ui.IY8lDe/`; no LOAM source
build, original household, or `./ui --refresh` was used. Existing LOAM binary and
Bakhlo's `./tools/tui` entrance ran in separate tmux sockets at 80×24.

- LOAM `init` created a new root; `loam doctor` reported `Status: ready`. In the
  TUI, Manage Loci admitted `wallet` and `food`; a Record draft was opened and
  cancelled without publishing.
- Bakhlo's interactive `--book` first-run created an empty JPY scale-0 book after
  review. Manage Loci admitted `wallet` and `food`. Record Preview showed
  `paired snack`, `wallet -37 jpy`, `food +37 jpy`; explicit Publish returned to
  Home with `Published and read back`.
- `./tools/tui --check` admitted the separate copied synthetic
  `examples/daily-book.sexp`; both TUI launchers displayed Home. These checks do
  not establish equal persisted household fixtures: LOAM's new Record was not
  published in this trial, and the copied Bakhlo example contains unrelated
  Scheduled/support evidence.

The previously recorded [paired Record run](#paired-record-happy-path-and-cancellation-2026-10-16)
is the evidence for matching new-Record behavior across both UIs. This setup
smoke does not expand that case to plans, observations, roles, correction,
refunds, multiple currencies, rejection modes, save failure, or broader parity.
Generated scratch files remain private and are not fixtures for publication.

## Fresh-root paired Record and cold reopen (2026-10-16)

At 80×24, `TERM=xterm-256color`, private tmux sockets; no original household
or LOAM build. LOAM source `a4c5d7b87e17e3ff38a9e2517fa81ddda75e12fc`
had a clean worktree; Bakhlo source was `8eece1c8f7dbc4791bc81e263fbf02b21c4b2aa2`.
Existing LOAM binary SHA-256:
`0ed043cf04349d2a66afe84e2a12837557df8d873450dc487afa88cf354fca97`.
Bakhlo binary SHA-256:
`1c27dfc5ec23c2aa2c1e3594dd8243b9b404fed2b7535e70f6d4002f26b3f3a8`.
LOAM source/binary correspondence was not established.

Fresh independent synthetic roots under ignored
`scratch/paired-ui-20261016.qIuxy3/` (Bakhlo) and
`scratch/paired-ui-20261016.RIrblW/` (LOAM). Bakhlo `--book` first-run created
the reviewed empty JPY scale-0 v3 book; both UIs admitted `wallet` and `food`
through Manage Loci. On 2026-10-16 each Record used description `paired snack`,
`wallet -37 jpy`, `food +37 jpy`. Both Preview surfaces showed the same date,
description, exact signed postings and 37 jpy balanced total. In LOAM the Edit
action returned to the retained draft; the subsequent Preview's selected
Publish + Enter recorded `record-1`. Bakhlo selected Publish + Enter reported
`Published and read back`.

Actual showed one entry with the same date, description and postings in both
UIs. After clean exit and cold reopen, opening Actual again showed that same
single entry. Final synthetic authority SHA-256:
Bakhlo `eab1a441d02956204cd093941b423ddef237e8b644df7d0bdc75728cb4116d90`;
LOAM `5e638f7b62e7c25e38ce7d3755a1246fb07ae8ee5a1c7f861593e2ee62e5a0c2`.
IDs and bytes differ by format; no cross-format byte equality is claimed.

This qualifies only the fresh-root JPY Record happy path and ordinary restart.
No roles, balances, observations, plans, errors, save failures, other dimensions,
IME, source/binary equivalence, power-loss/P7 or operational adoption were tested.

## Paired Actual search (2026-10-17)

At initial paired search, Bakhlo source HEAD was
`8eece1c8f7dbc4791bc81e263fbf02b21c4b2aa2`; LOAM source HEAD was
`a4c5d7b87e17e3ff38a9e2517fa81ddda75e12fc` (clean worktree). Existing LOAM
binary SHA-256 `0ed043cf04349d2a66afe84e2a12837557df8d873450dc487afa88cf354fca97`;
initial Bakhlo binary SHA-256
`1c27dfc5ec23c2aa2c1e3594dd8243b9b404fed2b7535e70f6d4002f26b3f3a8`.
No LOAM build; source/binary correspondence remains unqualified.

Separate roots under ignored `scratch/paired-search-20261017.8Yj16c/` held the
synthetic `paired snack` entry from the prior paired comparison. From Actual,
both UIs created and published a second entry, `other meal`, dated 2026-10-17
with `wallet -11 jpy` and `food +11 jpy`. Both ran at 80×24 with
`TERM=xterm-256color` on a private tmux socket. Before search the two entries
matched semantically: `paired snack` on 2026-10-16 (`wallet -37`, `food +37`)
and `other meal` on 2026-10-17 (`wallet -11`, `food +11`); format-specific IDs
and bytes differed.

From Actual, `/` opened search in both UIs. `paired` showed only the first of
two entries; replacing it with `other` showed only the second. `zzzz` showed
zero matches. Escape cleared the query and restored both entries. After clean
exit and cold restart, Actual reopened unfiltered with both entries. Before
search and after the cold restart, hashes matched: Bakhlo book
`5c4f32f10f2b83e73419d32a33ad217ebce6e2621564b21235eef96a4092c8ae`;
LOAM `household.loam`
`f6b9182aa7e379e55ea1ac72d73ca84d51bc3208ba7d67fcbd4e97e305565a96`;
`household.loam.prev`
`5e638f7b62e7c25e38ce7d3755a1246fb07ae8ee5a1c7f861593e2ee62e5a0c2`.

Follow-up on the same synthetic authorities with fresh TUI processes: active
`paired` search remained visible and matched one entry through 48×14 and 32×9.
At 32×9, replacing it with `other` still selected the second entry; restoring
48×14 and 80×24 preserved the query until Escape restored both. At 48×14
Bakhlo's row showed `+11 j…` while LOAM showed `11 jpy`; at 32×9 both used a
description-only row and clipped surrounding text. The three authority hashes
above remained unchanged after this resize run.

The compact amount clipping was fixed by reserving the panel borders and
`Panel.frame`'s two-cell selection prefix in `Actual_workspace.tx_panel`
(`row_width = w - 6`). The regression check uses the Bonsai renderer's
`Bonsai_term.View.width`, not byte length. `./tools/tui --self-check` passed.
The rebuilt Bakhlo binary SHA-256 is
`414da795262cfb07db0aa7c386913b65a76493b7c8286e3d0482bad0cedcd86d`.
With the rebuilt binary, a fresh 48×14 Actual view showed `other meal` with the
complete `+11 jpy`; restoring 80×24 returned to the split layout with both
entries and exact `±11 jpy` details. A post-fix active-search smoke started
`/paired` at 80×24, then resized to 48×14; the query remained active and the
single `paired snack` row showed the complete `+37 jpy`. At 48×14, clearing
that query and entering `/other` showed the single `other meal` row with
`+11 jpy`; Escape followed by restoring 80×24 showed both entries again. The
synthetic book and LOAM copies' three hashes above remained unchanged.

The 32×9 Description-only/clipped result is from the earlier binary and was
not rerun after the amount fix. Earlier 32×9 search observations are historical;
the post-fix interactive amount/search smoke covered 80×24 and 48×14.

This is bounded search/amount evidence at 80×24, 48×14 and 32×9 only. It does
not qualify caret coordinates, other geometry, long/CJK input, scope or sort
interaction, IME, broader shared-input acceptance, visual parity or operational
acceptance.

### Paired unreadable-source creation and cold reopen (2026-10-17)

At 80×24 with `TERM=xterm-256color`, separate private tmux sockets opened
synthetic unreadable selections under ignored
`scratch/first-run-success-20261017.SYSso3/`: LOAM's `loam-bad/` directory
contained only `keep.txt`, and Bakhlo's `bakhlo-bad.sexp` contained invalid
bytes. Existing LOAM binary SHA-256 was
`0ed043cf04349d2a66afe84e2a12837557df8d873450dc487afa88cf354fca97`;
Bakhlo binary SHA-256 was
`47f36d16fd59b0aceb73f7850f767082c855415fe00ddefacc72dfb2eba7c27d`.
LOAM source was `a4c5d7b87e17e3ff38a9e2517fa81ddda75e12fc`
with a clean worktree; Bakhlo HEAD was
`58f8bdc0db4b94a1bc4eab98e8a82c9292e6cdcc` with the existing
uncommitted first-run and documentation changes.
LOAM source/binary correspondence was not established. No LOAM build or
production input was used.

Each editor started with a blank destination. An unused `loam-new/` directory
or `book-new.sexp` file was entered; Bakhlo additionally selected `jpy`,
scale 0. Enter opened each review without creating the destination. A second
Enter created the new authority and opened Home in each UI. The Bakhlo file
was mode 0600. Both exited with `q` and reopened the newly created authority
in fresh TUI processes, reaching Home without first-run again.

The original sentinel and invalid input retained their before/after SHA-256
hashes, respectively `2b7847b7b705781d7cf21a05e9c1bb37cbf078aea103bc3edcc6aca52ab65453`
and `f1234d75178d892a133a410355a5a990cf75d2f33eba25d575943d4df632f3a4`.
The new LOAM `household.loam` and Bakhlo book retained hashes across cold
reopen, respectively `348d745c9ea32e2830156ec85fb58f995954086a540b56603e16a192b893dd65`
and `34d4130478662d8301e6a8660cbe08fd71a2fd8c9f13510f47b5b415ac1134f3`.
Formats differ; equal bytes are not expected. This covers the successful
unreadable-source branch and ordinary restart only. No failure injection,
contents/admission comparison, other dimensions, IME, P7 or operational
acceptance was tested.

### Paired narrow first-run and hidden-destination gate (2026-10-17)

Separate synthetic missing paths under ignored
`scratch/first-run-narrow-20261017.ZSu64j/`, `TERM=xterm-256color`,
existing LOAM binary SHA-256 `0ed043cf04349d2a66afe84e2a12837557df8d873450dc487afa88cf354fca97`.
LOAM source was `a4c5d7b87e17e3ff38a9e2517fa81ddda75e12fc`
(clean worktree); Bakhlo HEAD was
`58f8bdc0db4b94a1bc4eab98e8a82c9292e6cdcc` with local changes.
At 32×9, LOAM entered its truncated review with Enter; Escape returned to
editing, then Escape exited. Bakhlo displayed `Resize or Esc.` and Enter did
not advance. Escape exited. Neither destination was created; no LOAM
confirmation at 32×9 was attempted.

At 48×14, Bakhlo's review displayed `… more` instead of the destination but
the *prior binary* (`47f36d16fd59b0aceb73f7850f767082c855415fe00ddefacc72dfb2eba7c27d`)
accepted Enter and created `book48.sexp`. This contradicted its full-review
gate. `First_run.ready_to_create` counted the two border rows but omitted the
two additional rows reserved by `First_run.screen` for its form. It now
requires every wrapped review row to fit inside that actual viewport.
The permanent native check refuses a long destination at 48×14 and permits it
at 80×24; `./tools/tui --self-check` and `./tools/check` passed.

The rebuilt Bakhlo binary SHA-256
`753d0b89e1d3781a43d64fcbd6357dde89d917fb580760dd34f9bba3ead2abf0`
showed `… more` at 48×14 for `book48-fixed.sexp`. Enter displayed the
resize refusal and left that destination absent. After resizing to 80×24,
the full destination and meaning were visible; Enter created the book.
Separately LOAM created `loam48/` from its 48×14 review (the displayed path
was truncated). Both then exited and cold-reopened at 48×14 into Home; the
new authority hashes before/after cold reopen were respectively
`348d745c9ea32e2830156ec85fb58f995954086a540b56603e16a192b893dd65`
and `34d4130478662d8301e6a8660cbe08fd71a2fd8c9f13510f47b5b415ac1134f3`.
This is narrow synthetic comparison, not LOAM source/binary equivalence,
manual/IME acceptance, permission failure, power-loss/P7 or cutover approval.

## Actual empty search and CJK resize follow-up

Bakhlo baseline `77baa1e` (clean), then only the Actual display/check changes;
LOAM source `c366dcbe88458f49aa21701ad315970651cc63f3` (clean). Existing LOAM
`loamTui` SHA-256 `e5e125238385cd795a59207a53870257adb5da63ac1d2da7c9fbcb516353ad25`;
no LOAM build or source/binary equivalence claim. Bakhlo final native SHA-256
`d5690cea91d342b72b9a4d4ef3ef4c30091e71f4bd1903bc84a96a672f313e19`.

Fresh copies of the earlier **synthetic** two-entry search fixture were placed
under ignored `scratch/search-acceptance.OKKxIl`; no household capture was used.
Both ran on private tmux socket `bakhlo-search-new`, `TERM=xterm-256color`.
At 80×24, the active query `検索語あいうえおかきくけこさしすせそ1234567890検索語`
matched zero entries in both; both terminal carets were `(62,1)` (zero-based).
After shrinking to 32×9, both showed the same tail `…そ1234567890検索語`, caret
`(29,1)`. Backspace removed the final Japanese character in both and exposed
`…せそ1234567890検索`, still at `(29,1)`. This is injected Unicode, not IME acceptance.

The initial Bakhlo empty panel incorrectly counted its explanation as a row
(`1–1 / 1`, despite header count 0); LOAM showed `0/0`. The Actual caller now
uses its existing non-selected panel renderer for this explanation and an
explicit `0–0 / 0` range; no shared panel API, storage or selection logic changed.
The added regression failed with `empty-range-is-zero` before the fix.
Empty-book and no-match checks now pass at 120×36, 80×24, 48×14, 32×9 and 32×7.
`./tools/check`, `./tools/build-bonsai-tui` and final `./tools/tui --self-check` passed.

Fresh final-binary processes in both UIs: `/zzzz` remained empty through
80×24 → 48×14 → 32×9 → 80×24, with zero ranges throughout. Replacing the query
with `other` and shrinking to 32×9 retained the single Description-only row.
Escape and restore to 80×24 returned both entries. Exit/reopen between the
CJK and final runs also restored an unfiltered two-entry Actual view.
Authority SHA-256 before/after all runs remained Bakhlo
`5c4f32f10f2b83e73419d32a33ad217ebce6e2621564b21235eef96a4092c8ae`
and LOAM `f6b9182aa7e379e55ea1ac72d73ca84d51bc3208ba7d67fcbd4e97e305565a96`.
Geometry/header/footer differences and clipped narrow surrounding text remain;
scope/sort, other consumers, manual acceptance, IME and P7 are not qualified.

## Actual single Enter and filtered return

Baseline Bakhlo HEAD `77baa1e` plus the preceding empty-range display/check and
documentation changes (not committed). LOAM source remained clean at
`c366dcbe88458f49aa21701ad315970651cc63f3`; its existing `loamTui` SHA-256 remained
`e5e125238385cd795a59207a53870257adb5da63ac1d2da7c9fbcb516353ad25`.
Source/binary correspondence is not qualified; no LOAM build was performed.
Final Bakhlo native SHA-256
`1511a1cde8a24c4459ad650780797558790e45da210306567bfb73cf2a2e3981`.

Fresh synthetic two-entry copies: ignored `scratch/actual-scope-acceptance.H7VpyS`,
private tmux socket `bakhlo-scope`, `TERM=xterm-256color`; dates 2026-10-16/17,
`paired snack` ±37 jpy / `other meal` ±11 jpy. At 80×24, `/paired`, Enter,
`f` produced zero entries for Focus Day 2026-10-17 in both UIs. Enter refused
with `No current Actual is selected to open.`; it neither changed pane nor wrote.
`f`, `s` restored All Current / oldest-first with the query retained.

The initial comparison exposed a key-flow difference: current LOAM source
`ActualWorkspace.updateIntent .openSelected` and its existing binary open from
Transactions directly; Bakhlo only focused Details on the first Enter.
The added controller check failed with `actual-single-enter-opens-with-parent`.
After sharing the existing open branch between Transactions and Details,
the same-day/retained-filter check failed with
`actual-drill-opens-exact-id-despite-same-day-and-old-filters`: the controller
opened the day without anchoring its child selection. It now uses the existing
browser/sync helpers to select the explicit Actual ID and clear old child filters.
No writer, accounting predicate or shared panel API changed. Existing preview/
scroll checks now enter the Details pane explicitly with `i`.

With the rebuilt binary, Enter once opened `paired snack` in both UIs. Resize
to 48×14 and Escape returned to the one-row list, retaining `/paired` and
oldest-first. Starting an empty search and accepting it restored two rows;
sort showed other→paired (newest-first) and paired→other (oldest-first) in both.
At 32×9, Enter once and Escape returned to the selected `paired snack` list row.
At 48×14, `i`, Enter, Escape returned to the active Details pane in both.
Child surfaces still differ: Bakhlo Selected Day versus LOAM Transaction detail.
Bakhlo also showed the background Calendar date in the child's context line;
the route title and selected entry date were correct. This difference remains open.

Core `./tools/check` and final `./tools/tui --self-check` (including native build)
passed. Synthetic controller regression covers same-day target ID with old child
query/Locus/day filters, direct-list return at 80×24/48×14/32×9, non-writing entry,
and prior explicit Details/filter/order/scroll and correction-return checks.
Same-day/old-child-filter behavior is self-check evidence, not paired runtime evidence.
Both synthetic authority hashes were unchanged after clean exit:
Bakhlo `5c4f32f10f2b83e73419d32a33ad217ebce6e2621564b21235eef96a4092c8ae`,
LOAM `f6b9182aa7e379e55ea1ac72d73ca84d51bc3208ba7d67fcbd4e97e305565a96`.
Full Locus/scope/sort combinations, child-screen parity, human/IME acceptance,
failure injection for this slice and power-loss/P7 remain open.

## Selected Day context date and zoom

Bakhlo `77baa1e` plus the preceding uncommitted Actual changes and this bounded
display/check fix. Native binary SHA-256
`76606f95c03131d65cf4eff84534fc672f0e2e6fed5bfc730b21e78b813b02b4`.
The context line previously showed the background Calendar date/zoom even when
Selected Day and new Record correctly used a different route date. Expected
behavior is independently derived from the selected route, not LOAM output.
The new check failed with `selected-day-context-uses-route-date-and-day-zoom`
before the fix. It passes at 32×9/48×14/80×24/120×36, for background Day/Month/Year,
with and without a retained draft; existing Record initial-date/cold-save checks
remain passing. `./tools/check` and `./tools/tui --self-check` passed.

Fresh synthetic book under ignored `scratch/selected-day-context.nBTfNI`;
private tmux `bakhlo-context`, `TERM=xterm-256color`. From Home: Enter, z, z,
a, /paired, Enter (keep search), Enter (open). Selected Day showed
`2026-10-16   Day view` at 80×24 → 48×14 → 32×9 → 80×24. Record opened with
date 2026-10-16; description `context-only draft`, then Escape retained the
draft and showed the correct date plus `Draft retained`. Return to Actual and
clear search showed the untouched background `2026-10-17   Year view`.
After clean exit, book SHA-256 remained
`5c4f32f10f2b83e73419d32a33ad217ebce6e2621564b21235eef96a4092c8ae`.
No writer, admission or Calendar state change; no fresh LOAM comparison was needed
to establish this local display inconsistency. Human/IME acceptance, broader
Selected Day parity and power-loss/P7 remain unqualified.

## Exact calculator amount input (2026-10-17)

`Daily_book.parse_amount` evaluates `+ - * /` and parentheses as exact rationals,
then requires positive integer quanta at the selected Measure scale. Plain
decimal inputs retain their former precision/refusal behavior. Core expectations
cover precedence, left association, full-width operators/digits, grouping,
fractional intermediate values, non-integral results, zero division and syntax
refusal. Native Record checks cover exact Preview/publication, Scheduled creation
and retained expression text on error. `./tools/check` and
`./tools/tui --self-check` passed.

Actual Bonsai TUI smoke at 100×30 used a fresh synthetic copy under ignored
`scratch/calculator-smoke.L0CUjj`. Record entered `-(500+300)/2` and `+200*2`;
Preview displayed `-400 jpy` and `+400 jpy`. Enter on Publish reported
`Published and read back`; cold `--check` admitted the book and its single
new entry retained those two integer quanta. A second draft containing
`-500/0` remained visible with `row-1: The amount expression divides by zero.`;
no second entry appeared in the saved file. No LOAM runtime comparison,
human/IME acceptance, injected writer failure or power-loss/P7 qualification
is claimed from this slice.

## Balances visible-account setup (2026-10-17)

LOAM source `BalanceViewSetupSession.lean`/`BalanceViewConfig.lean` requires
whole-file config decoding, keeps prior selections from other Measures, admits
previously selected historical Loci, checks stale config/admission and keeps
unknown quantities as `?`. Bakhlo's old `Balance_view_data.of_string` silently
discarded malformed rows, and `load_file` returned `[]` on read failure; its
Current view also treated an explicitly empty selection as the default all-Loci
list. These weaker behaviors were removed in the bounded Bakhlo setup path.

The native synthetic check covers review/cancel/Edit nonwrites, refusal at
48×14, stale config refusal without replacement, preservation of another
Measure and row order, explicit empty selection, malformed config Unavailable,
and cold reloading an unknown coordinate. `./tools/check` and
`./tools/tui --self-check` passed.

The actual Bonsai UI ran at 100×30 with a fresh ignored synthetic copy in
`scratch/balance-view-smoke.fj1SPJ`: Home `b` → Balances `c` → `bank, wallet`
→ Review; Escape twice wrote no config. Re-entering and saving produced
`bank<TAB>jpy`, `wallet<TAB>jpy`; source book SHA-256 stayed
`2ffc331709f9e729e9beac4609d6548513085d412d5a4fc020e3a1d2379b247b`.
After exit and cold TUI reopen, Current listed bank as `? unsupported` and
wallet as `+1000 jpy` in the chosen order.

One rapid tmux resize-to-48×14 immediately followed by Enter saved while
the last displayed review had still been at 100×30. The synthetic controller
refuses confirmation when invoked with 48×14 dimensions, but the queued
terminal resize/Enter timing is not qualified by that check. LOAM paired
interaction, independent failure injection, IME/user acceptance and
power-loss/P7 remain open.

## Cycle boundary setup & Household setup commands (2026-10-17)

Household setup in Commands (`Space` → `Household setup`) exposes:
- Theme
- Manage Loci / Admitted vocabulary
- Daily Pace / spendable accounts (`daily-pace.tsv`)
- Daily Pace / cycle dates (`boundary-presets.tsv`)
- Balances / visible accounts (`balance-view.tsv`)
- Home / Bonsai

The cycle boundary editor (`b` in Daily Pace, or via Commands → Household setup → Daily Pace / cycle dates) supports:
- Editing explicit cycle dates for the named preset covering today.
- Input validation (requires token name and at least two strictly increasing real dates covering today, up to 32 boundaries).
- Full Review screen with explicit boundary listing, requiring confirmation before writing.
- Two-tier Escape/Cancel handling: Escape on Review returns to the input form with edited values preserved; Escape on input cancels without writing.
- Atomic config save to `boundary-presets.tsv` preserving other named presets and original book.
- Terminal geometry gate refusing confirmation if boundaries don't fit or width < 48.

`./tools/check` and `./tools/tui --self-check` passed with zero warnings.

Actual Bonsai TUI smoke at 100×30 (`TERM=xterm-256color`) used a fresh synthetic copy under ignored `scratch/cycle-setup-smoke.X7U7H8`:
- Commands (`Space`) → `Household setup` → `Daily Pace / cycle dates` opened the modal form.
- Input `pension`, `2026-10-01, 2026-11-01` → Review.
- Escape returned to input form with dates preserved; second Escape cancelled back to Home.
- Verified `boundary-presets.tsv` was not created.
- Navigated to Daily Pace (`d`), opened cycle dates editor via `b`, entered `2026-10-01, 2026-11-01` → Review → Enter to save.
- Verified `boundary-presets.tsv` contains `pension\t2026-10-01\t2026-11-01\n`.
- Daily Pace updated immediately to show 24 days remaining and cycle end `2026-11-01`.
- Cold TUI reopen confirmed persistence and accurate display of the 2026-11-01 cycle end.

LOAM paired execution, IME/preedit, power loss/P7, and human acceptance remain unexercised.

## Locus display names & Exchange preview gate (2026-10-17)

- **UI-30 Locus display names & descriptions**:
  - `Daily_book.help` and `Daily_book.set_locus_label` validate admitted Locus tokens, non-empty printable labels (<= 80 chars) and optional help descriptions, preserving existing help when omitted and updating `(labels (provided ...))` across S-expression roundtrips.
  - `Daily_actions.commit_set_locus_label` publishes to monolithic books and refuses Records format without mutating bytes.
  - `Space` → `Household setup` → `Account / category display names` and `Manage Loci` (`l` / `e`) open the display-name editor → full Review (`Save display name` / `Edit`) with a terminal geometry gate (`pane_w >= 48` and full rows visible).
- **UI-29 Exchange 2-step Preview gate**:
  - Submitting the Exchange form validates date, distinct Measures, positive exact amounts and admitted Loci, then opens `Exchange / Preview` showing exact signed source/destination Effects and the non-inferred FX note before publication.
  - Escape or `Edit` returns to the retained input form without writing; narrow terminals (`< 48` cols or overflowing rows) refuse confirmation; `Publish Exchange` commits against the captured `base_bytes`.
- `./tools/check` (including `daily_book_tests.ml` roundtrip/validation tests) and `./tools/tui --self-check` (including narrow-terminal refusal, Escape draft retention, and cold reload checks) passed with zero warnings; synthetic tmux smoke ran in `scratch/smoke_ui_29_30`. LOAM paired runtime comparison, IME acceptance and P7 remain open.

## UI-33 Daily Pace / Trend fail-closed and bounded verification (2026-10-17)

- **Fail-closed fixes (`daily_pace_trend.ml`, `daily_pace_trend.mli`, `daily_interaction.ml`)**:
  - **Current pace & balance errors**: `Trend.format_pace_error` translates internal error tokens (`daily-pace-balance-support-unknown:LOCUS:MEASURE`, `daily-pace-balance-amount-unknown:LOCUS:MEASURE`, `daily-pace-non-positive-horizon`, `daily-pace-duplicate-coordinate`, `daily-pace-pool-measure-mismatch`, `unknown-measure`) into clear, human-readable causes (`Pool locus balance is unknown: ...`, `Pool locus balance support is unknown: ...`).
  - **Pool balance verification (`query_pool_balance`)**: Queries `B.image book` for each coordinate using `Q.query`. Exact balances are summed; coordinates with `Known_present` or `Support_unknown` immediately return formatted refusal errors. Silent conversion of calculation failures to `Z.zero` is completely eliminated.
  - **Boundary presets verification (`resolve_end_exclusive`)**: `10d`, `30d`, and `Month` presets require an explicit containing cycle window in `boundary-presets.tsv` to establish a true horizon. Missing `boundary-presets.tsv`, malformed rows, out-of-range dates, and ambiguous overlapping windows covering today immediately return exact refusal errors (`Period not configured...`, `Malformed boundary-presets.tsv...`, `Multiple boundary presets contain today; selection is ambiguous.`, `No explicit boundary preset contains today.`). Silent 1-day fallback (`through_day + 1`) is eliminated.
  - **Config load handling**: `workspace_rows` binds `resolve_pace_pool` and `read_pace_config "boundary-presets.tsv"` without silent fallbacks to `[]` or `None`.
  - **What-if simulator**: Refuses simulation with exact cause when current pace is unavailable (`Daily pace unavailable (...); simulation is disabled.`), preventing fictitious purchase projections.
  - **Responsive Unavailable display**: Unavailable messages wrap with `left_width - 6` room to respect inner padding and borders across all viewport sizes without text truncation.

- **Automated verification (`daily_interaction_checks.ml`)**:
  - Missing pool config: 80×24, 48×14, 32×9 show `Daily Pace unavailable:` and `Daily Pace pool not configured (daily-pace.tsv missing).`; What-if form and submit display exact cause; plot and calculated numbers absent.
  - Malformed pool config: `Malformed daily-pace.tsv or mismatched Measure` displayed and verified.
  - Empty pool config: `Daily Pace pool is empty.` displayed and verified.
  - Unknown coordinate balance: `Pool locus balance support is unknown: bank jpy` displayed; What-if simulation disabled with exact cause.
  - Missing `boundary-presets.tsv`: `Period not configured (boundary-presets.tsv missing).` displayed across all presets `1`..`4`.
  - Malformed `boundary-presets.tsv`: `Malformed boundary-presets.tsv; no period was inferred.` displayed.
  - Ambiguous `boundary-presets.tsv`: `Multiple boundary presets contain today; selection is ambiguous.` displayed.
  - Out-of-window `boundary-presets.tsv`: `No explicit boundary preset contains today.` displayed.
  - Normal operations: 80×24, 48×14, 32×9 display `Daily Pace` and `Pace Detail & Evidence`; `Period progress:` and `Through end:` metrics shown; presets `1`..`4` switch smoothly; graph style `v` toggles Line/Dots; timeline `h`/`l` steps selection; `i`/`Tab` opens detail pane, `j`/`k` scrolls, `q`/`Esc` returns to timeline; What-if simulates `2000` JPY purchase; `q` returns cleanly to Home.

- **LOAM read-only comparison**:
  - Read-only source consultation of LOAM `Loam/Tui/DailyPaceTrend.lean`, `Loam/Review/DailyPacePeriods.lean`, and `Loam/Review/CycleSpendingPaceReview.lean`.
  - Verified parity on fail-closed policy: LOAM raises `Except String` on missing/malformed `boundary-presets.tsv`, empty/unreadable `daily-pace.tsv`, and non-exact balances, displaying `unavailable (i: cause)` / `History unavailable: <cause>` without zero substitution.

- **Test execution**:
  - `./tools/check`: all 354 inline and unit tests passed in 8.00s.
  - `./tools/build-bonsai-tui` and `_build/daily-bonsai/_build/default/ui/bonsai_daily.exe --self-check`: all checks passed with `PASS: UI-33 Daily Pace / Trend fail-closed and bounded verification (unknown balances, corrupted configs, ambiguous periods, multi-dimensions) passed.`

LOAM paired execution, physical terminal IME/preedit, power loss/P7, and human operational acceptance remain unexercised.
## Daily Pace paired comparison and Braille graph (2026-10-18)

- **Paired synthetic comparison against existing LOAM binary**:
  - Binaries: LOAM `04f0187...` / `.lake/build/bin/loam` (sha256 `9b17146cdc1e003e3a80d435212691c031efe57d0cccb923fc754c3113752379`), Bakhlo `bonsai_daily.exe` (sha256 `7079a5aaa43cf670b2cc89e3f7a267f009c68cc16c1fae13b8182994e5f426f9`).
  - Matched synthetic facts: observed on `2026-10-18`, pool `wallet` with `74,500` JPY, Scheduled payment `utility` on `2026-10-19` for `12,000` JPY, cycle window `2026-10-01 .. 2026-11-01` (14 days remaining). Both UIs calculated identical current truth: `4,464 jpy/day` and identical 10-day retrospective history (`3,782`, `3,727`, `3,904`, `3,975`, `3,657`, `3,861`, `3,911`, `4,081`, `4,300`, `4,464`).
  - Terminal matrix: `120×36`, `80×24`, `48×14`, `32×9` in private tmux sessions (`TERM=xterm-256color`).
  - Identified 9 UI differences:
    1. Graph lines: LOAM uses Braille 2×4 continuous line; Bakhlo used ASCII asterisk blocks (`*`).
    2. Ticks/Axis: LOAM uses integer 1/2/5×10ⁿ nice ticks (`3,500`, `4,000`, `4,500`); Bakhlo used literal min/max fractional steps without grouping.
    3. Date axis: LOAM shows start/end dates on axis line (`2026-10-09 ... 2026-10-18`); Bakhlo had no date axis.
    4. Selected day: LOAM keeps selected day and amount in header/summary across all sizes; Bakhlo lost selected day in 48×14.
    5. Truncation: Bakhlo left pane had `…` on right borders due to passing unpadded width.
    6. Layout: LOAM uses top chart + bottom history/details; Bakhlo uses side-by-side split pane.
    7. History columns: LOAM shows Day, Quanta/day, Spent, Pace diff; Bakhlo shows Day, Quanta/day (change).
    8. Fail-closed: Both correctly refuse unobserved pool with `Unavailable` (no zero substitution).
    9. Edge cases: Zero (`0 jpy/day`), negative (`-1,000 jpy/day`), 400-digit integer spans verified without float overflow.

- **Implementation improvements (`daily_pace_trend.ml`, `daily_pace_trend.mli`, `daily_interaction.ml`)**:
  - Replaced float/staircase chart with integer-only nice tick calculation (`nice_ceiling`, `ceil_div`) and Braille 2×4 subcell raster.
  - Line interpolation connects adjacent valid days sharing the same `end_exclusive`; holes, unobserved days, and cycle boundaries break the line without interpolation.
  - Dots mode plots sample points (`●`) and selected point (`◆`) without line ink.
  - Rule line displays short start/end dates (`MM-DD ─── MM-DD`).
  - Selection summary row displays `YYYY-MM-DD (today) ◆ 4,464 jpy/day` and degrades gracefully on narrow terminals.
  - Corrected Panel capacity and content width passed from controller (`left_width - 6`), eliminating row truncation `…`.
  - Amounts formatted using `B.format` with Measure scale and 3-digit comma grouping.

- **Verification results**:
  - `rtk test ./tools/check`: all tests passed in 8.20s.
  - `rtk test ./tools/tui --self-check`: all checks passed in 9.77s (including new `daily_pace_graph_render_checks`, `pool_review_checks`, `daily_pace_today_sample_checks`, `daily_pace_selection_clamp_checks`).
  - PTY captures verified across 120×36, 80×24, 48×14, and 32×9.
  - Zero pace (`0 jpy/day`), deficit pace (`-1,000 jpy/day`), and unobserved balance (`Unavailable`) verified on synthetic PTY.
  - Mac physical terminal IME/preedit and operational adoption remain unqualified; LOAM remains production authority.

## Pace history and narrow Balances paired (2026-10-18)

### Baseline and synthetic inputs

- Bakhlo source `168c3f38ad98be4240d9cd44d78017abb3f848f7` plus this uncommitted slice; initially clean worktree. Read-only LOAM source checkpoint `11f806d4b61121dffee744de0a14f93e2dd17441`, clean at inspection. Existing LOAM binary SHA-256 `9b17146cdc1e003e3a80d435212691c031efe57d0cccb923fc754c3113752379`; source/binary correspondence is not established and LOAM was not built.
- Fresh synthetic-only roots: ignored `scratch/parity-display-20261018.c44xx8/{loam,bakhlo,supported-loam,supported-bakhlo}`. No production household, retained capture or private comparison copy was opened.
- Both formats contain JPY scale 0, daily wallet → food Actuals of 100, 200, …, 1,000 on October 9–18, one open utility plan of 12,000 on October 19, explicit wallet Pool and October 1–November 1 cycle. Current wallet is 74,500; zero is exactly 0; bank lacks support. Current balance-view order is wallet, zero, bank, food.
- The current-only pair has an undated wallet assertion of 80,000 with no reflected roots; the ten Actuals reduce it to 74,500. Wallet has no historical zero-origin support. Food has zero-origin support and current quantity 5,500.
- The separate supported pair removes the wallet assertion, admits wallet zero-origin and records an explicit October 1 income of 80,000 into wallet, balanced by food −80,000. This preserves the same wallet/Pace facts while supplying genuine historical support; food is −74,500 in this pair. The pairs are not silently interchanged.

### Reproduced failures and changes

- Before editing, the current-only pair gave LOAM 1/10 supported Pace days, with the nine older days unknown. Bakhlo instead printed 2,952…4,464 for all ten. Current exact quantity alone was being used as a historical premise. `compute_samples` now requires admitted zero-origin for every Pool coordinate before reconstructing an older day. The current Core answer remains intact. Unsupported samples retain independent day activity but their dummy balance fields are never painted.
- Before editing, Balances initially selected a description `Header_row`, not wallet. At 32×9 only that header and a blank were visible. Current now contains actual coordinate rows only; empty selection is zero rows rather than a counted placeholder. Width-aware amount fitting preserves full grouped signed/scaled values or emits a detail cue; the unbounded Print path retains full values.
- Daily activity is classified from each entry's net Pool effect in the selected Measure. Paid-plan identities and their reversals are Scheduled-settled, intra-Pool transfers net to zero, and same-day reversal pairs contribute neither discretionary leg. Reserved amounts use the completed plan's Measure and actual payment date. Spent is discretionary outflow; same-day Pace diff is Pace − Spent, not prior-day change.
- The chart/history renderer is split directly into `render_chart` and `render_history`; the obsolete `render_trend` API is removed. A full-width chart sits above History / Selected day, with chart-first compact views and full-screen detail. History columns are aligned; initial 10d selection is today. Adjacent-day explanations use guarded exact integer time/free-money decomposition.

### Exercised results

- `rtk err ./tools/build-bonsai-tui`, direct native `bonsai_daily.exe --self-check`, and `rtk test ./tools/check` passed. Native checks cover currency isolation, discretionary vs Scheduled activity, intra-Pool cancellation, same-/cross-day reversals, exact change decomposition, unsupported vs supported history, chart/table geometry, huge amounts, exact zero vs unknown/presence, first-coordinate selection and empty counts. Old pane-title/source-label snapshots were deleted, not rewritten to the new labels.
- Owned tmux comparison used `TERM=xterm-256color`, 120×36, 80×24, 48×14 and 32×9. The full matrix used Bakhlo SHA-256 `a8108072c27c96f21937baac6d5da5da3471c4787b2afb580d6688ccbb4fee3d`. After final test-strengthening/unused-argument cleanup, binary SHA-256 `fba71be4cb7216136628f4fc48ae6feec03653f97b8eb985189cc2fec14aa4a7` passed native self-check again and a new cold 80×24 Pace → 32×9 Balances smoke.
- Both UIs report current Pace 4,464 jpy/day, Spent 1,000, same-day difference +3,464. In the current-only pair both expose 1/10 supported days, no past Pace line, and unavailable October 17. Bakhlo additionally displays the independently justified October 17 Spent 900 without zero balances.
- In the zero-origin pair both report the ten Paces 2,952 / 3,077 / 3,209 / 3,350 / 3,500 / 3,661 / 3,835 / 4,025 / 4,233 / 4,464. Spent is 100…1,000; corresponding margins are +2,852 / +2,877 / +2,909 / +2,950 / +3,000 / +3,061 / +3,135 / +3,225 / +3,333 / +3,464. Bakhlo's selected October 18 detail separates prior-day change +231 from margin +3,464 and shows time passage +302, free-money effect −71, Pool delta −1,000 and protection release 0.
- Actual keyboard smoke exercised day selection, End, line/dots toggle, detail open/scroll/resize/return. Balances exercised ordered first selection, exact zero, bank unsupported, detail scroll/return and 32×9 complete wallet `+74,500 jpy`. Both cold-reopened at 80×24 with Pace 4,464 / partial 1/10 and wallet 74,500.
- Current-only authority SHA-256 stayed unchanged through viewing, navigation, resize and cold restart: LOAM `d6fab24e3dde40e401b2c28ab4c4954e03e22316d77547f343fa5b4682449839`, Bakhlo `ec66d29e8e9300c89da35adb436f960a504c9966415164050ec197dd6e33f9fe`. Captures remain under the same ignored root, including `*-pace-final-*`, `*-balances-final-*`, unknown-day/detail captures and `final-binary-*`. Only owned tmux sessions were stopped.

### Limits and remaining acceptance

This is bounded display/safety evidence, not full UI-24/UI-33 acceptance. Zero-origin qualification is conservative: LOAM dated bounded-history support is not added. Historical protection around paid/cancelled plans is not qualified by these fixtures. Remaining visible differences include context/footer text, selected focus styling, chart/table counters, single-point chart scale, detail ordering and some keys; Balances still differs in column headings and 80-column stacked layout. Accounting, picker/setup, Print/output, real IME/human acceptance, power loss/P7 and operational cutover remain open. No writer/schema, dependency, production data, push or merge changed.

Read-only independent review checked the Measure/completion/reversal classifier, historical-support guard through the detail renderer, and exact-amount fitting; it found no must-fix issue in that bounded scope. A proposed additional Scheduled-refund line was not added: LOAM's `activityDetail` likewise displays discretionary inflow and settled outflow/reserved variance, while a supported cross-day refund contributes to the existing Pool/free-through-end delta. This does not qualify broader completed-plan history.

## UI-24-B2 Balances picker and grouped observation (2026-10-18)

### Baseline, reference and scope

- Started on `main` with 11 already-modified files from the Daily Pace/history and narrow Balances work. Preserved binary worktree/index patches and status at `/tmp/bakhlo-ui24-b2-baseline.QQXLW3`; no reset, stash, commit, push or merge. Those earlier results and their unqualified history cases remain intact.
- The requested label UI-24-B2 was not present in the existing plan; this names the user's visible-account settings / multiple-coordinate observation slice, not the unrelated headings/layout residuals.
- Read-only LOAM reference: `BalanceViewSetupSession.lean` prepare/save, `DailyPacePoolSetup.lean` choose/review, `CurrentQuantityAnchor.lean` collector/Preview, and the existing grouped Core contract. Existing LOAM executable SHA-256 `9b17146cdc1e003e3a80d435212691c031efe57d0cccb923fc754c3113752379`; no build or source/binary correspondence claim.
- Before editing, actual Bakhlo displayed only a comma-input visible-account form and a single-row immediate Observe. LOAM binary offered j/k/Space selection and Add/Preview/Publish for a group. The production LOAM meaning is **preserve unmentioned observations**, not replace the entire evidence file.
- Changed only `daily_interaction.ml` and its native checks, plus current documentation. Reused `Ui_form`, `Ui_panel`, `Balance_view_data`, guarded config publication, `Daily_book.observe_quantities` and `Daily_file.publish`; no Core, codec, schema, dependency or writer change.

### Synthetic interaction and persistence evidence

- Fresh ignored copies under `scratch/ui24-b2.Q4w9bH/{loam,bakhlo,bakhlo-final}` came only from the earlier explicitly synthetic `parity-display-20261018.c44xx8` fixture. No production authority, retained household capture or private comparison input was opened.
- Owned tmux socket `b2pit`, `TERM=xterm-256color`: paired normal picker/Observe at 100×30 and/or 80×24, picker selection-following at 48×14 / 32×9, Bakhlo 48×14 review refusal. Captures include `loam-picker*`, `loam-observe-preview`, `loam-duplicate-refusal`, `loam-origin-refusal-80x24`, `bakhlo-before-comma-settings`, `bakhlo-picker*`, `bakhlo-observe*` and `final-*`.
- Picker: both offered prior selections first, then remaining admitted Loci. Space removed wallet; Review showed zero/bank/food; Escape returned with that choice retained. Explicit save wrote identical `zero<TAB>jpy`, `bank<TAB>jpy`, `food<TAB>jpy` (SHA-256 `a8abac7557eee1177955ee45ee09b07aa4d46d2ecad6833b854ab87c32e4f866`) without changing household quantities. Bakhlo returned to the launching Balances route; LOAM returned to its launching Calendar. Narrow Bakhlo Enter retained Review and original config bytes; resize/Edit/review then saved.
- Observe: wallet 1234 jpy + bank 0 jpy were added without writes, reviewed together, edited without losing rows, then explicitly published. Both yielded wallet 1234, bank 0, unmentioned zero 0 and food 5500. Cold TUI reopening preserved quantities and selected visible order. LOAM authority hash after publish `b8be7abef8bce9b04fb2a414690a31393efe3e58f20ba9e997e47c77bc8b1642`; Bakhlo `772c54901e2db0cf728b85e119bc063688da048c1c9a8b8d97e042324f24fc60`. Preview retained the original Bakhlo hash `ec66d29e8e9300c89da35adb436f960a504c9966415164050ec197dd6e33f9fe`.
- Both refused a group with wallet 1 + wallet 2, kept the Preview and left authority hashes unchanged. LOAM also refused food 9 because food has zero-origin support. Bakhlo's native check covers the same atomic support collision; narrow Preview publication refused before any write.
- Actual failure injection: with Bakhlo's synthetic parent directory temporarily mode 0500, Publish of wallet 7 returned `Uncertain`. Restored mode 0700, Ctrl-r, Enter still refused the retained image, with unchanged `772c…fc60` authority. This exercises conservative writer-result handling, not durable Ack/P7 qualification. No original or prior trial was changed.

### Checks and limits

- `rtk test ./tools/check`, `rtk err ./tools/build-bonsai-tui`, native `bonsai_daily.exe --self-check`, and final `rtk test ./tools/tui --self-check` passed. Native checks exercise picker toggle/order/empty/historical/other-Measure preservation, malformed/unreadable/missing/stale config and cold reads; Observe multi-row nonwrites/Edit/cold, exact zero/negative/scale-2 EUR, duplicates/unapproved/zero-origin/invalid amount, tiny/blocked/conflict/stale-reload and missing-source save refusal.
- Integration binary SHA-256 `f35e731f98478c4a05b00be4859cd3c4b3d4315d26b341f270940ce8c8c6f19b` was cold-launched on fresh `bakhlo-final`: keyboard-only Add wallet 1234 + bank 0 → Preview (hash unchanged) → Publish → Balances showed all four expected quantities; picker resized to 32×9 followed food, restored 80×24 and saved the wallet-hidden choice; cold reopen showed zero/bank/food. This binary also refused duplicate publication and uncertain-save retry.
- Focused independent review found a dropped pre-existing lowercase normalization of typed Measures. Actual `bank / JPY / 0` reproduced the Add refusal; normalization was restored and the native multi-row cold test now uses `JPY`. Final binary SHA-256 `e853c9baeb23ce8edc57f3fc9a9285aecf37c9580b40609471457e24ea311bdf` passed the documented TUI self-check and actual 80×24 `bank / JPY / 0` → Preview (`bank 0 jpy`) → Publish → Balances. Its Household setup picker Review → Escape → Escape returned to the launching Calendar without changing book/config bytes. Only owned `b2pit` sessions were stopped.
- Intentional safety differences: Bakhlo requires the entire Review at the event's dimensions; it does not copy LOAM's clipped confirmation text. Existing exact signed/scaled amount input is retained rather than imposing LOAM's raw integer-quanta input. Bakhlo uses existing framed modal appearance, not LOAM's unframed collector.
- Not full UI-24/UI-31 acceptance: Current headings/80-column stacked layout, Accounting/Print, broad annual/Records/support-family paired cases, real IME/human acceptance and rapid queued resize/Enter timing remain open. Daily Pace dated bounded-history and completed/cancelled-plan history remain **unqualified and unchecked in this slice**. Power loss/P7, noncooperative writers and operational adoption remain separate unresolved conditions.
