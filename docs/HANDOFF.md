# Handoff

Current state in one page. Rules and user decisions: [AGENTS.md](../AGENTS.md).
Per-screen progress: [UI gap ledger](LOAM_UI_GAP_LEDGER.ja.md). Daily-use summary:
[cutover diff ledger](CUTOVER_DIFF_LEDGER.ja.md). What actually ran:
[VERIFICATION](VERIFICATION.md). The previous long handoff (per-feature evidence up
to 2026-10-19) is in Git at `9c3246c:docs/HANDOFF.md`.

## Where things stand (2026-10-27)

- Code-quality pass (2026-10-27): exact amount text has one pure owner; Scheduled
  Ctrl-U shares Preview's parsing and preserves balanced rows; Record choices use
  named variants. Store sessions are private records, auxiliary writers share only
  file replacement, and Observe/roles/Attention retain uncertain revision evidence
  for reload confirmation. Full checks and fault-injection regressions pass; latest
  copies at 120×36/80×24 preserve the inspected Bakhlo frames except candidate IDs.
  [Evidence and limits](VERIFICATION.md#book-publications-retain-one-kind-of-recovery-evidence-2026-10-27).

- Common format with LOAM (user decision 2026-10-24): spec `docs/COMMON_FORMAT.ja.md`,
  fixtures `test/common_format/`, reader/printer `book_txt/` (stage 3, 2026-10-25,
  [evidence](VERIFICATION.md#common-format-reader-and-printer-against-the-conformance-fixtures-2026-10-25)).
  Stage 4a done (2026-10-25): `migrate/daily_to_book_txt` and `./tools/book-txt trial`
  convert a copy of the household and compare every entry, plan and current quantity
  ([evidence](VERIFICATION.md#household-copy-converts-to-booktxt-with-every-answer-equal-2026-10-25)).
  Stage 4b (2026-10-25, user-approved): `Daily_txt` converts both ways, `Daily_file` reads and
  rewrites `book.txt` whole, roles and Attention are sections of the book, and the tools,
  example and docs use `book.txt`
  ([evidence](VERIFICATION.md#the-store-reads-and-rewrites-booktxt-stage-4b-2026-10-25)).
  The household was migrated the same day (`./tools/book-txt migrate`,
  [evidence](VERIFICATION.md#household-migrated-to-booktxt-2026-10-25)): `../bakhlo-data` is
  now `book.txt`; the last S-expression book is its parent commit. The user opened it and
  reported the screens look fine (2026-10-25). Core A, step 1 (2026-10-25): a save checks and
  prints only what it changes (`Book_txt.change`); 90 ms at 45,000 synthetic entries,
  164 ms at 109,500 (over the target there; I/O-bound)
  ([evidence](VERIFICATION.md#a-save-checks-and-prints-only-what-it-changes-core-a-step-1-2026-10-25)).
  Old layers removed the same day: the book.txt migration tool and append log, the LOAM
  import comparison (both UIs now open copies of the household `book.txt`,
  `tools/compare`) and the S-expression book format
  ([evidence](VERIFICATION.md#the-s-expression-book-format-is-removed-core-a-2026-10-25)).
  Presence evidence (nonzero, amount unknown) was removed the same day: `book.txt` cannot
  hold it and the household never used it. `Daily_book` now runs on book.txt itself (an
  admitted `Book_txt.book`, changes through `Book_txt.change`, balances from the totals it
  keeps); its answers equal the previous core on random operations and on a household
  copy, and a cold load is about 40% faster
  ([evidence](VERIFICATION.md#daily-book-runs-on-booktxt-core-a-2026-10-25)). Next in A:
  the application layer's correction/lineage machinery was then removed
  ([evidence](VERIFICATION.md#the-application-layer-is-removed-core-a-2026-10-25)).
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
- Storage (2026-10-25): one `book.txt`, rewritten whole on every save; the session keeps
  the admitted book, so a save checks and prints only what it changes. Every
  `Daily_book` mutation is in place except corrections that change a Reversal link or
  touch an opening witness. Synthetic save 48 ms at 1,000 entries, 90 ms at 45,000,
  164 ms at 109,500 (over the target there); cold load 168 ms at 10,950 and 1.9 s at
  109,500 (deferred by the user). Entries whose Loci are hidden keep dedicated date
  (`d`) and Merchant (`m`) operations; correction and reversal refuse, as in LOAM.
  Earlier storage designs and their checks: VERIFICATION entries up to 2026-10-25.
- TUI terminal: Notty since 2026-10-21 (user decision; Bonsai_term and its OxCaml switch
  removed, Bonsai is explored outside Bakhlo). The TUI is part of the main Dune build, so
  `./tools/check` and the single CI workflow cover it. The user ran it on a household copy
  and reported it works; IME and paste were not reported separately.
- Unqualified: P7 (persistent post-save acknowledgement), power loss, real macOS IME,
  human acceptance.

## Code map

- `lib/`: identifiers, exact quantities, Effects, Events, Movements. No I/O. The former
  `application/` (correction frontier, cuts, sources, relations) is in Git up to `42ce0fc`.
- `sexp/daily_book.ml(i)`: the household book on book.txt (an admitted `Book_txt.book`
  and its TXs as entries; changes, balances, Daily Pace, past-day pools);
  `sexp/book_log.ml(i)`: the publication operations; `sexp/daily_txt.ml(i)`: the roles
  and Attention sections in their text formats, and fixture helpers.
- `book_txt/book_txt.ml(i)`: the common `book.txt` format (read, admit, print, balance).
- `store/daily_file.ml`: the single writer of `book.txt` (load, whole-file publish,
  conflict and uncertain outcomes, copies).
- `tui/`: `shell/` (state, dispatch, publication, files), `screens/<screen>/` (per-screen
  state, input, painting), `book/` (pure UI data), `protocol/screen.mli` (Shell ↔ screen
  contract), `app/` (Notty terminal + CLI entry), `scenarios/` (cross-screen checks).
  Keys, recovery commands and UI rules: [tui/README](../tui/README.md).
- Removed 2026-10-25 (in Git at `502d570`): `loam_read/`, `migrate/` and the LOAM import
  comparison (`tools/compare_capture.ml`); `tools/compare` now copies the household
  `book.txt` for both UIs. The book.txt migration tool is in Git at `6a22ba6`.
- Removed 2026-10-21 (in Git at `dfd03d1`): old CLI (`cli/`, `bin/`, `presentation/`,
  `text/`, `sexp/book.ml`), `tools/import-loam`, `experiments/`, `formal/`.
- Docs removed 2026-10-21 (in Git at `90a5867`): `docs/archive/`, storage and geometry
  research, capability ledger, LOAM core inventory, references, ADR 0003, and
  VERIFICATION entries before 2026-10-20. Links to them are permalinks at that commit.
- Tests: `test/` (Core; `daily_book_oracle_tests.ml`, `book_txt_tests.ml`,
  `daily_file_tests.ml` guard the storage work) and the TUI self-check.

## Verify and continue

```sh
./tools/check                 # Core build, tests, architecture check
./tools/tui --self-check      # all synthetic TUI suites (also in ./tools/check)
./tools/startup-probe         # synthetic load, save and response timings (1k / 36.5k / 109.5k)
./tools/privacy-scan [--all]  # no private household text in the repository (in check)
./tools/compare refresh       # fresh copies of the household book.txt (see AGENTS.md)
./ui  /  ./ui loam            # Bakhlo and LOAM on those copies
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
