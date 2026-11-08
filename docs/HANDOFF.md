# Handoff

Current state in one page. Rules and user decisions: [AGENTS.md](../AGENTS.md).
Per-screen progress: [UI gap ledger](LOAM_UI_GAP_LEDGER.ja.md). Daily-use summary:
[cutover diff ledger](CUTOVER_DIFF_LEDGER.ja.md). What actually ran:
[VERIFICATION](VERIFICATION.md). The previous long handoff (per-feature evidence up
to 2026-10-19) is in Git at `9c3246c:docs/HANDOFF.md`.

## Where things stand (2026-11-08)

The dated log of earlier passes is in Git at `5b48008:docs/HANDOFF.md`; evidence is in
[VERIFICATION](VERIFICATION.md) (older entries at the commits it names).

- **Daily use.** The household is `../bakhlo-data` since the 2026-10-21 cutover, recorded
  only by the user through `./tools/household`, which runs the pushed `origin/main` (built
  in `.run/src`, binary `.run/bakhlo_tui.exe`, the last good binary kept when offline) and
  then commits and pushes the book to the private backup, reporting any backup failure.
  Restoring that backup was drilled on 2026-10-23. `../loam-data` is the frozen LOAM record.
- **Storage.** One `book.txt` in the common format with LOAM (`docs/COMMON_FORMAT.ja.md`,
  reader/printer `book_txt/`), rewritten whole on every save after `Book_txt.change` admits
  only what changed; saves flush with `F_FULLFSYNC` (~21 ms). Synthetic save 48 ms at
  1,000 entries, 90 ms at 45,000, 164 ms at 109,500 (over the 100 ms target there); cold
  load 1.9 s at 109,500 (startup work deferred by the user).
- **Household core.** `household/` owns every household rule: `Book` (entries, plans,
  balances, Daily Pace, past paces), `Record` (the Record form), `Amount`, `Day`, `Period`
  and the reports (`Income_expense`, `Transactions_flow`, `Stock_flow`, `Trend`,
  `Liquidity`, `Multicurrency_spend`). Refusals are codes; screens only word and format.
  User decisions (2026-11-08): HIDDEN only blocks new money flows (a correction keeping
  its Loci and a refund to its target's Loci are saved, unlike LOAM), and the refund of
  a plan's payment counts with the plan in History and Income & Expense.
- **Specification for the rewrite.** `test/` holds language-neutral, hand-written answer
  samples in one format (`test/README.md`): `amounts`, `common_format`, `periods`,
  `reports`, `records`, `scheduled`. A rewrite in another language is done when it
  passes them; `test/samples.ml` is the one reader.
- **TUI.** English Notty TUI (user decision 2026-10-21) in the main Dune build, covered by
  `./tools/check` and CI: bonsai Home, hierarchical Commands, Record/Preview, Actual with
  period windows, Scheduled, Selected Day, Balances/Observe, Daily Pace, Manage Loci,
  Exchange, Attention, settlements and reports. The typography series (Actual, Balances,
  Scheduled List, Daily Pace, Record/Preview) is published. Remaining gaps and acceptance
  are in the [UI gap ledger](LOAM_UI_GAP_LEDGER.ja.md). Latest-data speed (2026-10-23):
  Home ~51 ms (LOAM ~242), Actual All `j` 8.8 / 7.3 ms, Daily Pace `d` 9.5 / 6.6 ms;
  synthetic 109.5k Actual Down+paint is still ~235 ms.
- **Trial (2026-11-08):** `bk r` and `bk pay` record and pay with one-line answers, and
  `bk bal` / `bk pace` print balances and today's pace, instead
  of the TUI. The user tries them for a week or two; TUI screens not opened in that time
  are candidates for removal.
- **Unqualified:** P7 (persistent post-save acknowledgement), power loss, real macOS
  IME, human acceptance.

## Code map

- `household/`: every household rule (see above); `book.ml(i)` is the book on book.txt
  (an admitted `Book_txt.book` and its TXs as entries, the changes the Shell publishes,
  roles and Attention; `read` and `print`).
- `book_txt/book_txt.ml(i)`: the common `book.txt` format (read, admit, print, balance).
- `store/book_file.ml`: the single writer of `book.txt` (load, whole-file publish,
  conflict and uncertain outcomes, copies).
- `tui/`: `shell/` (state, dispatch, publication, files), `screens/<screen>/` (per-screen
  state, input, painting), `book/` (screen wording and display data), `protocol/screen.mli`
  (Shell ↔ screen contract), `app/` (Notty terminal + CLI entry), `scenarios/`
  (cross-screen checks). Keys, recovery commands and UI rules: [tui/README](../tui/README.md).
- `test/`: the answer samples, and Core tests (`book_cold_reload_tests.ml`,
  `book_txt_tests.ml`, `book_file_tests.ml` guard storage); the TUI self-check.
- Removed code and docs (old CLI, typed Effect layer, application layer, LOAM import,
  migration tools, studies) are listed with their last commits in Git at
  `5b48008:docs/HANDOFF.md` (Code map).

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

1. The TUI is about 43,000 lines against a ~5,300-line core: shrink it in OCaml, or build
   small screens in the Zig rewrite (the user's decision, pending).
2. Daily-use parity in the five areas of the cutover diff ledger, ordered by
   `tasks/todo.md`.
3. Startup snapshot only when startup is felt slow.
4. Performance: profile the remaining Actual scan/sort costs before indexing; GADT
   expansion showed no benefit (study in Git at
   `5b48008:docs/PERFORMANCE_AND_GADT_STUDY.ja.md`).
5. Admitted Measure / Locus types (stopped at design on 2026-10-28): restart from the
   study in Git at `5b48008:docs/ADMITTED_TYPES_STUDY.ja.md`.
