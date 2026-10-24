# Handoff

Current state in one page. Rules and user decisions: [AGENTS.md](../AGENTS.md).
Per-screen progress: [UI gap ledger](LOAM_UI_GAP_LEDGER.ja.md). Daily-use summary:
[cutover diff ledger](CUTOVER_DIFF_LEDGER.ja.md). What actually ran:
[VERIFICATION](VERIFICATION.md). The previous long handoff (per-feature evidence up
to 2026-10-19) is in Git at `9c3246c:docs/HANDOFF.md`.

## Where things stand (2026-10-21)

- Common format with LOAM (user decision 2026-10-24): spec `docs/COMMON_FORMAT.ja.md`,
  fixtures `test/common_format/`, reader/printer `book_txt/` (stage 3, 2026-10-25,
  [evidence](VERIFICATION.md#common-format-reader-and-printer-against-the-conformance-fixtures-2026-10-25)).
  Next is stage 4: map `Daily_book` to `Book_txt`, convert a copy of the household and
  compare every balance, entry and plan, then a user-approved migration. The household
  still uses `book.sexp`.
- Cut over on 2026-10-21 (user decision): the household is `../bakhlo-data`, recorded
  only by the user through `./tools/household` (TUI, then commit and push to the private
  GitHub backup).
  `../loam-data` is the frozen LOAM record. Saves flush with `F_FULLFSYNC` (~21 ms);
  a physical power-loss test was not run.
- `tools/household` now stops and reports backup failures (including missing upstream
  and pending-log errors), preserving Git's reason and any nonzero TUI exit status.
  Synthetic local-Git tests cover failed commit/push, no-edit retry and config backup;
  restoring the private off-site backup was drilled on 2026-10-23 (see below).
- `tools/household` runs pushed code only (user decision 2026-10-22): it fetches
  `origin/main`, builds it in an ignored worktree at `.run/src` and installs the built
  binary at `.run/bakhlo_tui.exe` (copied to a temporary name and renamed), never the
  shared tree; it names the commit it runs, prints the build it starts, keeps the last
  installed binary when offline or the build fails, and refuses without any binary.
  The launcher script itself runs from the working tree; only the TUI binary is pinned
  to `origin/main`.
- Calendar removed (user decision 2026-10-22): the bonsai Home opens Actual, whose period
  windows (Cycle / Month / Year) are where periods are browsed and chosen; `g`, the
  Calendar route, `Screen.env.calendar` and the ambient Calendar input are gone. The Shell
  keeps one `focus_day` (session start) for new Records and plans. Actual now has a
  period bar and an `f` period picker (every window with its count and EXPENSE total,
  user choice 2026-10-22); at 109.5k synthetic entries moving in it takes 11 ms, opening
  or switching 60–166 ms. Verification: [Calendar removed](VERIFICATION.md#calendar-removed-2026-10-22),
  [period bar and picker](VERIFICATION.md#actual-period-bar-and-picker-2026-10-22).
- Terminal-theme chart series are blue, magenta, yellow, then cyan (user choices
  2026-10-24: cyan was too close to blue, red too loud).
- Trend / Locus is painted like LOAM's full-screen Trend (user report 2026-10-24: it looked
  and scrolled nothing like it): no frame, two-row series rack, source and Selected lines,
  one coloured value row per series, LOAM's period axis and compact layout; the selected
  markers sit over the line (`◎` when two share a cell) and the Day window moves only when
  the selection leaves it. The owner keeps its projection while the book value and config
  are the same, and the renderer measures each span once per row: `←` in Day takes 13.7 /
  7.0 ms at 120×36 / 80×24 (was 36.0 / 25.9; LOAM 17.9 / 7.9). Opening or changing grain
  still projects once (~0.15–0.36 s at 109,500 synthetic entries). Pointer scrub remains
  absent. Verification: [Trend like LOAM](VERIFICATION.md#trend-looks-and-scrolls-like-loam-2026-10-24).
- Stock–Flow leaves the whole opening entry out of the window's flows: the counterpart
  posting (e.g. opening equity) is not a decrease any more, so the tracked increases
  and decreases cancel again. Start and End still carry that entry, so the motion is
  unknown: the Net cell of every affected row, of the Total row and of the "Net
  change in tracked balance" line stays `—`, and the note names each excluded entry
  and says that Start and End include it while `+In` and `-Out` do not. The
  exclusion is keyed by (Measure, entry). Synthetic checks cover each rule and fail
  against the previous code; `check` and `--self-check` passed. No household access.
- Paired speed on the latest data (2026-10-23): Bakhlo reaches Home in ~51 ms against
  LOAM's ~242 ms and opens Balances and Daily Pace several times faster; moving in
  Actual's All view was slower (18 / 16 ms against 11 / 8 ms at 120×36 / 80×24) and
  at or above the 16 ms target until the change below; the Cycle view was under it.
  [Evidence](VERIFICATION.md#paired-speed-bakhlo-and-loam-on-the-latest-data-2026-10-23).
- Actual All view moves (2026-10-23): day totals and row text are built only for
  shown rows, one key resolves the list once and the amount scan stops at its cap.
  On the latest data `j` in All fell to 8.8 / 7.3 ms (LOAM 12.6 / 8.3 ms); output
  is unchanged over a 3,540-state sweep. Synthetic 109.5k All is still ~0.3 s.
  [Evidence](VERIFICATION.md#actual-all-view-faster-list-moves-2026-10-23).
- Daily Pace opens faster (2026-10-23): one view computes today's pace and the
  samples once (the Workspace layout paints no subtitle, which no longer
  recomputes them), past pools for all sample days come from one pass
  (`Daily_book.pools_at_end_of_days`) and paid plans use `find_entry`. On the
  latest data `d` fell from 23.7 / 21.7 ms to 9.5 / 6.6 ms (LOAM ~130 ms); output
  is unchanged over a 200-step sweep.
  [Evidence](VERIFICATION.md#daily-pace-opens-faster-2026-10-23).
- Trial saves and restore drill (2026-10-23): on a byte-identical copy of the
  household, a memo correction, a date-only correction, a Merchant classification,
  a new entry and compaction through the single writer each matched cold reload
  and `Full`. A fresh clone of the private backup restored a byte-identical book;
  every backed-up version passes `--check`.
  [Evidence](VERIFICATION.md#household-trial-saves-and-backup-restore-drill-2026-10-23).
- Actual now reuses scoped/filtered rows within a render; common empty-query search
  skips text construction. The 1,440-state synthetic frame comparison is unchanged.
  At 109.5k synthetic entries, native Actual Down+paint fell 466→235 ms (80×24);
  the 16 ms goal is still unmet. No persistent cache or household access was added.
- Goal: reproduce LOAM's non-budget functionality and interaction (see AGENTS.md
  Product). English Notty TUI: bonsai Home, hierarchical Commands,
  Record/Preview, Actual, Scheduled (Series Calendar, Months, List, create/edit/cancel/
  complete, batch, generation), Selected Day, Balances/Observe, Daily Pace (current,
  What-if, Pool, Trend), Manage Loci/roles, Exchange, Attention, limited settlements,
  reports. Remaining gaps and acceptance state live in the UI gap ledger.
- Record quick capture now uses LOAM's bounded frame with its footer inside.
  Synthetic terminal comparison covered 80×24 / 120×36 and compact 48×14 / 32×9;
  resize, Tab, Esc and long Japanese drafts retain input. Household warnings take
  priority over the frame. Core, native self-check and the PTY matrix passed.
  This slice did not access household data or repeat the latest-data comparison.
- Accounting now discovers represented coordinates from current corrected entries,
  not the admitted source that lags incremental saves. Synthetic append and a
  correction after reopening match cold reload and `Full`; unsupported stays unknown.
  Core/TUI checks and the four-size PTY smoke passed. No household access or paired
  comparison in this slice; the underlying `Daily_book.image` source lag remains.
- Comparison capture now derives `config/accounting-roles.tsv` from the required
  household `AccountingRole` section, preserving raw config and trial overrides.
  Synthetic refresh and TUI proved payer-role replacement through Preview and cold
  reopen after copy cleanup. Missing/malformed roles refuse without changing CURRENT.
  Latest-data paired comparison was not executed; household data was not accessed.
- Storage (rebuilt 2026-10-20): one book file = single-file S-expression snapshot +
  appended `Book_log` records. Every `Daily_book` mutation is in place except
  corrections that change a Reversal link or touch an opening/presence witness. At
  ~110k synthetic entries: save 0.6 ms, record/refund/exchange/correction <0.01 ms
  (2026-10-23, was ~4.8 ms), observation 6 ms, startup 2.2 s (deferred by the user). Details:
  [long-term storage study](https://github.com/shumoku88-bit/bakhlo/blob/90a5867/docs/LONG_TERM_STORAGE_STUDY.ja.md) stages 5–9.
- The 2026-10-20 storage work was checked on the latest real-data copy: Core identical
  to pre-today code; Balances and Daily Pace match LOAM; trial saves in TUI (record,
  correction, date correction, merchant, reversal) and 200-record exit compaction
  (keeping byte-identical `.prev`, `records = 0`, matching cold reload and `Full`)
  verified on an isolated real-data copy (5.90 ms/save incl. `fsync`). For entries
  whose Loci are no longer in `approved-loci`, both LOAM and Bakhlo refuse `c`
  (including memo-only) and reversal. Bakhlo now has dedicated metadata operations
  for `d` (date-only, `correct-entry-date` log record) and `m` (merchant), preserving
  identity, Effects, links, original amount and plans without reapproving historical
  Loci (<0.01 ms each at ~110k synthetic entries since [2026-10-23](VERIFICATION.md#entry-corrections-without-rebuilding-the-entry-list-2026-10-23)). On the latest real-data copy at
  120×36 and 80×24 both UIs reach the same `d`/`m` Previews; Bakhlo saves on an
  isolated copy matched cold reload and `Full`.
- TUI terminal: Notty since 2026-10-21 (user decision; Bonsai_term and its OxCaml switch
  removed, Bonsai is explored outside Bakhlo). The TUI is part of the main Dune build, so
  `./tools/check` and the single CI workflow cover it. The user ran it on a household copy
  and reported it works; IME and paste were not reported separately.
- Unqualified: P7 (persistent post-save acknowledgement), power loss, real macOS IME,
  human acceptance.

## Code map

- `lib/`, `application/`: pure exact-quantity, admission and query semantics
  (`SEMANTIC_CONTRACT.md`). No I/O.
- `sexp/daily_book.ml(i)`: the household book (entries, plans, support), staged
  admission, in-place mutations, `Full` whole-book reference; `sexp/book_log.ml(i)`:
  operations, record lines, snapshot+log load.
- `store/daily_file.ml`: the single writer (load, append, compaction, torn-tail
  discard, recovery report, copies).
- `tui/`: `shell/` (state, dispatch, publication, files), `screens/<screen>/` (per-screen
  state, input, painting), `book/` (pure UI data), `protocol/screen.mli` (Shell ↔ screen
  contract), `app/` (Notty terminal + CLI entry), `scenarios/` (cross-screen checks).
  Keys, recovery commands and UI rules: [tui/README](../tui/README.md).
- `loam_read/`, `migrate/`: read-only LOAM input and its pure conversion, used only by
  `./tools/compare` (the cutover import is done).
- Removed 2026-10-21 (in Git at `dfd03d1`): old CLI (`cli/`, `bin/`, `presentation/`,
  `text/`, `sexp/book.ml`), `tools/import-loam`, `experiments/`, `formal/`.
- Docs removed 2026-10-21 (in Git at `90a5867`): `docs/archive/`, storage and geometry
  research, capability ledger, LOAM core inventory, references, ADR 0003, and
  VERIFICATION entries before 2026-10-20. Links to them are permalinks at that commit.
- Tests: `test/` (Core; `daily_book_oracle_tests.ml`, `book_log_tests.ml`,
  `daily_file_tests.ml` guard the storage work) and the TUI self-check.

## Verify and continue

```sh
./tools/check                 # Core build, tests, architecture check
./tools/tui --self-check      # all synthetic TUI suites (also in ./tools/check)
./tools/startup-probe         # synthetic storage timings (1k / 36.5k / 109.5k)
./tools/privacy-scan [--all]  # no private household text in the repository (in check)
./tools/compare refresh       # fresh read-only LOAM copy (see AGENTS.md)
./ui  /  ./ui loam            # paired private copies
```

Use a fresh ignored trial directory for manual runs; never overwrite a previous one.
After pushing, check CI for the matching commit SHA.

## Next candidates

1. Daily-use parity in the five areas of the cutover diff ledger, ordered by
   `tasks/todo.md`.
2. Startup snapshot only when startup is felt slow.
3. Performance optimization, memory tuning, and GADT investigation updated
   2026-10-23: [study](PERFORMANCE_AND_GADT_STUDY.ja.md) and
   [pre-optimization Actual CPU evidence](VERIFICATION.md#actual-cpu-baseline-and-bounded-width-experiment-2026-10-23).
   The entry-map change shortens mutations, but the first list materialization
   remains linear. Bounded amount-width scanning, one resolution per key and
   visible-row formatting shipped in `7a7dc9e`; see the
   [integrated measurements](VERIFICATION.md#actual-all-view-faster-list-moves-2026-10-23).
   Further work starts with profiling the remaining scan/sort costs; range indexing
   remains conditional. GADT expansion has no demonstrated benefit. String sharing
   needs a heap breakdown; startup optimization stays deferred.
