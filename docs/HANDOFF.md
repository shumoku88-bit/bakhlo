# Handoff

Current state in one page. Rules and user decisions: [AGENTS.md](../AGENTS.md).
Per-screen progress: [UI gap ledger](LOAM_UI_GAP_LEDGER.ja.md). Daily-use summary:
[cutover diff ledger](CUTOVER_DIFF_LEDGER.ja.md). What actually ran:
[VERIFICATION](VERIFICATION.md). The previous long handoff (per-feature evidence up
to 2026-10-19) is in Git at `9c3246c:docs/HANDOFF.md`.

## Where things stand (2026-10-21)

- Cut over on 2026-10-21 (user decision): the household is `../bakhlo-data`, recorded
  only by the user through `./tools/household` (TUI, then commit and push to the private
  GitHub backup).
  `../loam-data` is the frozen LOAM record. Saves flush with `F_FULLFSYNC` (~21 ms);
  a physical power-loss test was not run.
- Goal: reproduce LOAM's non-budget functionality and interaction (see AGENTS.md
  Product). English Bonsai TUI: Calendar Home (Day/Month/Year), hierarchical Commands,
  Record/Preview, Actual, Scheduled (Series Calendar, Months, List, create/edit/cancel/
  complete, batch, generation), Selected Day, Balances/Observe, Daily Pace (current,
  What-if, Pool, Trend), Manage Loci/roles, Exchange, Attention, limited settlements,
  reports. Remaining gaps and acceptance state live in the UI gap ledger.
- Record quick capture now uses LOAM's bounded frame with its footer inside.
  Synthetic terminal comparison covered 80×24 / 120×36 and compact 48×14 / 32×9;
  resize, Tab, Esc and long Japanese drafts retain input. Household warnings take
  priority over the frame. Core, native self-check and the PTY matrix passed.
  This slice did not access household data or repeat the latest-data comparison.
- Comparison capture now derives `config/accounting-roles.tsv` from the required
  household `AccountingRole` section, preserving raw config and trial overrides.
  Synthetic refresh and TUI proved payer-role replacement through Preview and cold
  reopen after copy cleanup. Missing/malformed roles refuse without changing CURRENT.
  Latest-data paired comparison was not executed; household data was not accessed.
- Storage (rebuilt 2026-10-20): one book file = single-file S-expression snapshot +
  appended `Book_log` records. Every `Daily_book` mutation is in place except
  corrections that change a Reversal link or touch an opening/presence witness. At
  ~110k synthetic entries: save 0.6 ms, record/refund/exchange <0.01 ms, correction
  4 ms, observation 6 ms, startup 2.2 s (deferred by the user). Details:
  [long-term storage study](LONG_TERM_STORAGE_STUDY.ja.md) stages 5–9.
- The 2026-10-20 storage work was checked on the latest real-data copy: Core identical
  to pre-today code; Balances and Daily Pace match LOAM; trial saves in TUI (record,
  correction, date correction, merchant, reversal) and 200-record exit compaction
  (keeping byte-identical `.prev`, `records = 0`, matching cold reload and `Full`)
  verified on an isolated real-data copy (5.90 ms/save incl. `fsync`). For entries
  whose Loci are no longer in `approved-loci`, both LOAM and Bakhlo refuse `c`
  (including memo-only) and reversal. Bakhlo now has dedicated metadata operations
  for `d` (date-only, `correct-entry-date` log record) and `m` (merchant), preserving
  identity, Effects, links, original amount and plans without reapproving historical
  Loci (4.1 ms each at ~110k synthetic entries). On the latest real-data copy at
  120×36 and 80×24 both UIs reach the same `d`/`m` Previews; Bakhlo saves on an
  isolated copy matched cold reload and `Full`.
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
  contract), `app/` (Bonsai terminal + CLI entry), `scenarios/` (cross-screen checks).
  Keys, recovery commands and UI rules: [tui/README](../tui/README.md).
- `loam_read/`, `migrate/`: read-only LOAM input and its pure conversion, used only by
  `./tools/compare` (the cutover import is done).
- Removed 2026-10-21 (in Git at `dfd03d1`): old CLI (`cli/`, `bin/`, `presentation/`,
  `text/`, `sexp/book.ml`), `tools/import-loam`, `experiments/`, `formal/`.
- Tests: `test/` (Core; `daily_book_oracle_tests.ml`, `book_log_tests.ml`,
  `daily_file_tests.ml` guard the storage work) and the TUI self-check.

## Verify and continue

```sh
./tools/check                 # Core build, tests, architecture check
./tools/tui --self-check      # Bonsai build + all synthetic TUI suites
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
