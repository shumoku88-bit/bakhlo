# Handoff

Current state in one page. Rules and user decisions: [AGENTS.md](../AGENTS.md).
Per-screen progress: [UI gap ledger](LOAM_UI_GAP_LEDGER.ja.md). Daily-use summary:
[cutover diff ledger](CUTOVER_DIFF_LEDGER.ja.md). What actually ran:
[VERIFICATION](VERIFICATION.md). The previous long handoff (per-feature evidence up
to 2026-10-19) is in Git at `9c3246c:docs/HANDOFF.md`.

## Where things stand (2026-10-20)

- Bakhlo is a trial: LOAM remains the operational authority; no cutover is authorized.
- Goal: reproduce LOAM's non-budget functionality and interaction (see AGENTS.md
  Product). English Bonsai TUI: Calendar Home (Day/Month/Year), hierarchical Commands,
  Record/Preview, Actual, Scheduled (Series Calendar, Months, List, create/edit/cancel/
  complete, batch, generation), Selected Day, Balances/Observe, Daily Pace (current,
  What-if, Pool, Trend), Manage Loci/roles, Exchange, Attention, limited settlements,
  reports. Remaining gaps and acceptance state live in the UI gap ledger.
- Storage (rebuilt 2026-10-20): one book file = single-file S-expression snapshot +
  appended `Book_log` records. Every `Daily_book` mutation is in place except
  corrections that change a Reversal link or touch an opening/presence witness. At
  ~110k synthetic entries: save 0.6 ms, record/refund/exchange <0.01 ms, correction
  4 ms, observation 6 ms, startup 2.2 s (deferred by the user). Details:
  [long-term storage study](LONG_TERM_STORAGE_STUDY.ja.md) stages 5–9.
- Not yet done for the 2026-10-20 storage work: a latest-data paired comparison and
  trial saves on a private copy (writes need the user's explicit request).
- Unqualified: P7 (persistent post-save acknowledgement), power loss, real macOS IME,
  human acceptance.

## Code map

- `lib/`, `application/`: pure exact-quantity, admission and query semantics
  (`SEMANTIC_CONTRACT.md`). No I/O.
- `sexp/daily_book.ml(i)`: the household book (entries, plans, support), staged
  admission, in-place mutations, `Full` whole-book reference; `sexp/book_log.ml(i)`:
  operations, record lines, snapshot+log load. `sexp/book.ml` is the older CLI `Book`.
- `store/daily_file.ml`: the single writer (load, append, compaction, torn-tail
  discard, recovery report, copies).
- `tui/`: `shell/` (state, dispatch, publication, files), `screens/<screen>/` (per-screen
  state, input, painting), `book/` (pure UI data), `protocol/screen.mli` (Shell ↔ screen
  contract), `app/` (Bonsai terminal + CLI entry), `scenarios/` (cross-screen checks).
  Keys, recovery commands and UI rules: [tui/README](../tui/README.md).
- `cli/`, `presentation/`, `bin/`, `loam_read/`: older CLI and read-only LOAM input.
- Tests: `test/` (Core; `daily_book_oracle_tests.ml`, `book_log_tests.ml`,
  `daily_file_tests.ml` guard the storage work) and the TUI self-check.

## Verify and continue

```sh
./tools/check                 # Core build, tests, architecture check
./tools/tui --self-check      # Bonsai build + all synthetic TUI suites
./tools/startup-probe         # synthetic storage timings (1k / 36.5k / 109.5k)
./tools/compare refresh       # fresh read-only LOAM copy (see AGENTS.md)
./ui  /  ./ui loam            # paired private copies
```

Use a fresh ignored trial directory for manual runs; never overwrite a previous one.
After pushing, check CI for the matching commit SHA.

## Next candidates

1. Latest-data paired check of the storage work (read-only now; trial saves if the
   user asks).
2. Daily-use parity in the five areas of the cutover diff ledger, ordered by
   `tasks/todo.md`.
3. Startup snapshot only when startup is felt slow.
