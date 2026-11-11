# Handoff

Current state in one page. Rules and user decisions: [AGENTS.md](../AGENTS.md).
The commands: [cli/README](../cli/README.md). What actually ran:
[VERIFICATION](VERIFICATION.md). The previous long handoff (per-feature evidence up
to 2026-10-19) is in Git at `9c3246c:docs/HANDOFF.md`.

## Where things stand (2026-11-11)

The dated log of earlier passes is in Git at `5b48008:docs/HANDOFF.md`; evidence is in
[VERIFICATION](VERIFICATION.md) (older entries at the commits it names).

- **Daily use.** The household is `../bakhlo-data` since the 2026-10-21 cutover, recorded
  only by the user through `./tools/household`, which runs the pushed `origin/main` (built
  in `.run/src`, binary `.run/bakhlo.exe`, the last good binary kept when offline) and
  then commits and pushes the book to the private backup, reporting any backup failure.
  Restoring that backup was drilled on 2026-10-23. `../loam-data` is the frozen LOAM record.
- **Storage.** One `book.txt` in the common format with LOAM (`docs/COMMON_FORMAT.ja.md`,
  reader/printer `book_txt/`), rewritten whole on every save after `Book_txt.change` admits
  only what changed; a save orders the new file with `F_BARRIERFSYNC` and flushes the drive
  cache once with `F_FULLFSYNC` (~21 ms). Synthetic save 26 ms at 1,000 entries, 150 ms at 109,500
  (the target is 100 ms at the household's size; the 30-year size is recorded only); cold load 1.9 s at
  109,500 (reviewed only when felt slow).
- **Household core.** `household/` owns every household rule: `Book` (entries, plans,
  balances, Daily Pace, past paces), `Record` (the Record form), `Amount`, `Day`, `Period`
  and the reports (`Income_expense`, `Transactions_flow`, `Stock_flow`, `Trend`,
  `Liquidity`, `Multicurrency_spend`). Refusals are codes; screens only word and format.
  User decisions (2026-11-08): HIDDEN only blocks new money flows (a correction keeping
  its Loci and a refund to its target's Loci are saved, unlike LOAM), and the refund of
  a plan's payment counts with the plan in History and Income & Expense.
- **Specification.** `test/` holds language-neutral, hand-written answer
  samples in one format (`test/README.md`): `amounts`, `common_format`, `periods`,
  `reports`, `records`, `scheduled`. Any implementation is right when it passes them;
  `test/samples.ml` is the one reader.
- **Screens and commands.** User decision (2026-11-11): the TUI is back after daily use
  with `bk` commands alone (decided 2026-11-08, removed 2026-11-09). `tui/` is
  restored from `a346668` as it was (settlements and every report screen included), built
  on today's `household/`, `store/` and `cli/`. One program, `tui/app/bakhlo_tui.exe`: plain
  `bk` opens the screens, `bk COMMAND` runs the `cli/` command (the TUI's own older copy
  of the commands is not restored). The wording and view data both use have one owner in
  `cli/` (`Draft`, `Book_display`, `Attention_data`, `Balance_view_data`, `Locus_roles`,
  `Scheduled_coverage`); the screens' detail and Preview lines are `tui/book/book_detail.ml`.
  `tools/arch`, `test/arch.t`, `tools/ci-tui-pty`, the CI PTY lane, `docs/TUI_OWNERSHIP.md`
  and `docs/UI_DIRECTION.ja.md` are back with it; the LOAM ledgers, the cutover checklist
  and the LOAM side-by-side tools are not. Notty, uutf and parsexp are dependencies again.
- **Unqualified:** P7 (persistent post-save acknowledgement), power loss, real macOS
  IME, human acceptance.

## Code map

- `household/`: every household rule (see above); `book.ml(i)` is the book on book.txt
  (an admitted `Book_txt.book` and its TXs as entries, the changes the Shell publishes,
  roles and Attention; `read` and `print`).
- `book_txt/book_txt.ml(i)`: the common `book.txt` format (read, admit, print, balance).
- `store/book_file.ml`: the single writer of `book.txt` (load, whole-file publish,
  conflict and uncertain outcomes, copies).
- `cli/`: the bk commands (`line_commands.ml`, `command_line.ml`), their wording (`draft.ml`),
  display width, settings files and Daily Pace from them; `cli/test/` checks every command.
- `tui/`: the screens ([tui/README](../tui/README.md), layers in
  [TUI_OWNERSHIP](TUI_OWNERSHIP.md)): `kit` → `book` → `protocol` → `screens/*` → `shell` →
  `app` (Notty and the program's entry), with `scenarios` and per-layer checks.
- `test/`: the answer samples, and Core tests (`book_cold_reload_tests.ml`,
  `book_txt_tests.ml`, `book_file_tests.ml` guard storage).
- Removed code and docs (old CLI, typed Effect layer, application layer, LOAM import,
  migration tools, studies) are listed with their last commits in Git at
  `5b48008:docs/HANDOFF.md` (Code map).

## Verify and continue

```sh
./tools/check                 # build, samples, bk command and TUI checks, privacy scan
./tools/tui --self-check      # the synthetic TUI checks alone
./tools/startup-probe         # synthetic load, save and response timings (1k / 36.5k / 109.5k)
./tools/privacy-scan [--all]  # no private household text in the repository (in check)
./tools/household-copy refresh  # a fresh copy of the household book.txt (see AGENTS.md)
./ui [COMMAND]                  # the screens, or a bk command, on that copy
```

Use a fresh ignored trial directory for manual runs; never overwrite a previous one.
After pushing, check CI for the matching commit SHA.

## Next

[tasks/todo.md](../tasks/todo.md) is the one list of what comes next, first things first;
an item is deleted by the commit that finishes it (as qemacs keeps its TODO.md).
