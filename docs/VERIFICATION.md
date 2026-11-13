# Verification

Types, finite tests, models, proofs and operational evidence establish different things.
None automatically certifies handwritten OCaml, external premise truth or household use.
Ordinary qualification is macOS x86_64 and Ubuntu 24.04 x86_64 (CI) with the locked
toolchain. This file keeps the last week's entries (from 2026-11-02); entries from 2026-10-20 to
2026-10-31 are in Git at `5b48008:docs/VERIFICATION.md`, earlier ones (including the bounded
Solo5-SPT engine boot) at `90a5867:docs/VERIFICATION.md`.

From 2026-11-09 (user decision) an entry names its commit (or comes in it) and says what ran and its
result, keeping synthetic checks, CI, latest-data checks, physical terminal/IME,
human acceptance and P7/power loss apart. What changed and why is that commit's message.

## TUI: unused draft wording removed, Stock–Flow uses the shared footer (2026-11-13)

- `./tools/check` and `./tools/format --check` passed (exit 0). No check reads
  Stock–Flow's footer; the removed literal was byte-identical to `Report_frame.footer`
  (compared in the diff).
- Latest-data check not needed: no displayed text or behaviour changed.
- Physical terminal/IME and P7/power loss **not executed**.

## TUI Exchange and Record Ctrl-O: the same offered Measures (2026-11-13)

- `./tools/check` and `./tools/format --check` passed (exit 0), with the new
  `exchange-offers-measures`, `orig-integration-offers-other-measure` and
  `orig-amount-offers-other-measure` checks; the original-amount checks that typed a
  Measure into the empty field now clear the offered one first or take it with Enter.
- Latest-data check on a throwaway copy of the household copy (deleted afterwards),
  after one `bk fx` into ils: `bk` in tmux at 120×40 showed the Exchange form with
  `Source Measure: jpy` / `Destination Measure: ils`, and Record → Tab → Ctrl-O showed
  `Measure: ils|`. The copy was written; the household was not.
- CI for `f40cc97` passed, the Linux PTY lane included
  ([run 43421318573](https://github.com/shumoku88-bit/bakhlo/actions/runs/43421318573)).
- Physical terminal/IME and P7/power loss **not executed**.

## bk fx / original amount: the Measure used last is offered (2026-11-13)

- `./tools/check` and `./tools/format --check` passed (exit 0), with the new
  `bk-offers-the-measure-used-last` check; the existing `bk-fx-records-an-exchange`
  and `bk-r-adds-an-original-amount` still pass unchanged.
- Latest-data check on a throwaway copy of the household copy (deleted afterwards):
  after one exchange into ils, `bk fx` offered `Into Measure [ils]` and `bk r` → `o`
  offered `Original Measure [ils]`. The copy was written; the household was not.
- Before this change, a read-only travel rehearsal on a throwaway copy ran `bk fx`
  (jpy→ils twice), `bk r` in ils, `bk r` with an ils original amount, `bk check`
  of an ils wallet and the Multicurrency Spend screen (tmux, 140×42): all saved
  and displayed; the ils wallet balance stays unknown until a `bk check`.
- CI for `f3a2e80` passed, the Linux PTY lane included
  ([run 43420032923](https://github.com/shumoku88-bit/bakhlo/actions/runs/43420032923)).
- Physical terminal/IME and P7/power loss **not executed**.

## Daily Pace: average spent over the displayed days (2026-11-13)

- `./tools/check` and `./tools/format --check` passed (exit 0), with the new
  `pace-history-average-spent-*` and `pace-detail-average-spent` checks and the three
  updated Selected day line-order checks.
- Latest-data check: `./tools/household-copy refresh`, then `./ui` in tmux at 97×46 on
  the copy: Daily Pace / 10d showed the full `Average spent` line unclipped in History
  and in Selected day (amounts not recorded); the household's `book.txt` MD5 was the
  same before and after; `clean-copies` kept the one copy.
- CI for `2071634` passed, the Linux PTY lane included
  ([run 43357838162](https://github.com/shumoku88-bit/bakhlo/actions/runs/43357838162)).
- Physical terminal/IME and P7/power loss **not executed**.

## The TUI restored (2026-11-11)

- `./tools/check` passed: build of `@all`, every sample and core test, the bk command
  checks, the synthetic TUI checks (`tui/`), `arch_check: ok` with
  `test/arch.t`, `test/household.t` on the launcher's new target, and the privacy scan
  (233 changed files; `./tools/privacy-scan --all`, 527 files, no match).
  `./tools/format --check` passed.
- `tools/ci-tui-pty _build/default/tui/app/bakhlo_tui.exe examples/book.txt` passed on
  macOS x86_64 (four PTY sizes, keys, resize, Ctrl-Q, cold reopen, bytes unchanged).
- On a synthetic copy of `examples/book.txt` the program printed `bk help` (first line:
  open the screens) and `bk bal`, and plain `--book` opened the Home screen in tmux.
- Latest-data check: `./tools/household-copy refresh`, then `./ui` in tmux on the copy
  opened Home, Actual, Balances, Daily Pace and Scheduled and left with exit 0, no
  refusal text on any of them (screen contents not recorded); the household's
  `book.txt` MD5 was the same before and after; `clean-copies` kept the one copy.
- `bakhlo.opam.locked` is the file of `a346668` again, not a fresh `opam lock`.
- CI for `09c2380` passed, the Linux PTY lane included
  ([run 43029052997](https://github.com/shumoku88-bit/bakhlo/actions/runs/43029052997)).
- Not executed: a physical terminal with the macOS IME, human acceptance, a write through the screens on household data,
  P7 and power loss.

## Blank line after the launcher's Running line (2026-11-09)

- moko ran `bk` with the edited `tools/household` and saw the blank line. `dune runtest
  test` showed `test/household.t` one blank line short in 14 runs; `dune promote`
  accepted them. `./tools/check` and `./tools/format --check` passed.

## Unused dependencies removed (2026-11-09)

- Product libraries (household, store, cli, the probe) no longer list base or sexplib0;
  parsexp is out of bakhlo.opam. `./tools/opam lock .` regenerated the lock: parsexp
  gone, base, sexplib0, csexp, dune-configurator and ocaml_intrinsics_kernel now
  with-test (50 locked, 34 with-test). `./tools/check` and `./tools/format --check`
  passed. Not executed: a fresh switch installed without test packages.

## Tab completion instead of fzf (2026-11-09)

- The fzf picker on plain `bk` (`092594a`) is removed: plain `bk` again prints today's
  pace and the list and exits. `cli/test/completion.expected`, written by hand from the
  command table, matched what `tools/bk-completion.bash` offers for eight typings, under
  bash 5.3 (dune) and the system bash 3.2. `./tools/check` and `./tools/format --check`
  passed. Not executed: Tab in the household's own shell (it needs the `source` line and
  the launcher's next build, which brings `--commands`).

## The save Preview as every list (2026-11-09)

- The hand-built `bk pay` Preview (plan line, heading, one passbook line), worked out
  from the widths first, matched; `./tools/check` and `./tools/format --check` passed;
  `views.expected` unchanged. `bk r` on a scratch book showed a split as two lines.

## Ctrl-C still backs up (2026-11-09)

- Synthetic household with a local bare remote, in a `script` pseudo-terminal: one record
  saved, `y` to another, Ctrl-C at its Date prompt. New launcher: "Interrupted: …",
  committed and pushed, exit 130. The previous launcher, run the same way, left the saved
  record uncommitted; its next ordinary run committed and pushed it.

## Picking a command with fzf (2026-11-09)

- Hand-built checks with a stand-in fzf: the picked line gives its words; the menu
  holds every command and fzf is told to match the words only (`--nth=1`); Esc (exit
  130) runs nothing. `./tools/check` and `./tools/format --check` passed.
- Real fzf 0.70.0, `--filter` with the same options on the command list: `sh` gives shop,
  `to` the four todo commands, `reg` reg, `cash` nothing (it is only in descriptions).
- Real fzf in a `script` pseudo-terminal: the menu draws (32/32) and Esc runs nothing;
  typed letters did not reach the query there (fzf's cursor-position query gets no
  answer without a terminal emulator). **Not executed:** typing in a real terminal.

## One house style for bal, plans, month, report ie and footers (2026-11-09)

- `views.expected` changed only where intended: bal gained a heading and lost `+`,
  plans reads from-to, month names its first column, report ie separates Measures by a
  blank line, and the last footer reads "10 of 305 records". Hand-built bal, plans,
  month and last lines were worked out from the widths first; two were wrong (the
  heading `account` is the widest cell; `カード` is 6 cells) and were corrected by
  recounting, not by copying the output. `./tools/check` and `./tools/format --check`
  passed.

## bk loci in each account's Measures (2026-11-09)

- A hand-built `bk loci` (dollars only, both Measures, a new account), worked out from
  the column widths first, matched. `views.expected` changed only in `bk loci`: USD cash
  75.00 usd, Travel a second line in usd. `./tools/check` and `./tools/format --check`
  passed.

## bk reg in two passbook columns (2026-11-09)

- The hand-built `reg wallet` lines, worked out from the column widths first, matched the
  output. `views.expected` changed only in the three `reg` views. `./tools/check` and
  `./tools/format --check` passed. Not executed: physical terminal and IME.

## Records as a passbook writes them (2026-11-09)

- `views.expected` diff read line by line: `find`, `last` and `day` gained a heading and
  lost the signs and repeated Measures; the exchange is two lines (Bank 16,000 jpy,
  USD cash 100.00 usd); no other view changed. `./tools/check` (with the updated
  hand-built `find`, `day` and `last` lines) and `./tools/format --check` passed.
- `bakhlo --book … edit` on a scratch book with a split, an exchange and a plain
  record: numbers on each record's first line only, continuation lines aligned.
- Not executed: physical terminal and IME.

## Every view against a synthetic year (2026-11-09)

- `cli/test/views.ml` generated its year (305 records, 33 plans, an exchange, an
  original amount, a refund, matters and the four settings files) and printed 18
  read-only commands; all admitted and ran, 272 lines, written to `views.expected`.
- `./tools/check` passed with it; with one character of `views.expected` changed it
  failed (exit 1) on the diff, and `dune promote` restored the reference.
  `./tools/format --check` and `./tools/privacy-scan` passed.
- Found by reading the output: `bk loci` shows a dollar account as "unknown jpy"
  (in tasks/todo.md).

## A barrier before the rename, one full flush (2026-11-09)

- Throwaway step timings (scratch, median of 21, two runs each): the first sync as
  `F_BARRIERFSYNC` took 1.0 ms at 1,000 entries and 1.9–2.4 ms at 109,500, against
  20.5–26.7 ms as `F_FULLFSYNC`; the directory's full flush rose from 20.4 to 23.4–23.7 ms
  at 109,500. Save totals 45.1–45.5 → 25.0–26.4 ms and 154.7–155.8 → 137.4–142.6 ms.
- `startup_probe detail` on the change (real `Book_file.publish`): 25.9 ms at 1,000
  entries (47.9 ms before), 150.3 ms at 109,500 (163.1 ms before).
- `./tools/check` (incl. interrupted and killed writer tests) and `./tools/format --check`
  passed. CI runs fsync on Ubuntu, as before (no `F_BARRIERFSYNC` there).
- **Not executed:** power loss (P7/power-loss stays unqualified).

## Where a save's time goes (2026-11-09)

- A throwaway program in ignored scratch repeated `Book_file.publish`'s steps on synthetic
  books from `startup_probe gen` (macOS x86_64, OCaml 5.4.1, median of 21 saves, ms):

  | step | 1,000 (0.1 MiB) | 36,500 (3.6 MiB) | 109,500 (11.0 MiB) |
  |---|---:|---:|---:|
  | admit (`Book.apply`) | 0.1 | 0.4 | 3.2 |
  | print (`Book_txt.print`) | 0.3 | 8.4 | 22.7 |
  | digest of the new bytes | 0.3 | 7.3 | 20.9 |
  | unchanged check (read + digest) | 0.5 | 9.8 | 31.9 |
  | create and write the temporary file | 0.3 | 2.0 | 7.9 |
  | full sync of the file | 20.8 | 23.9 | 27.0 |
  | read back the temporary file | 0.2 | 4.3 | 15.4 |
  | link `.prev`, rename | 2.0 | 1.9 | 2.7 |
  | full sync of the directory | 20.5 | 20.3 | 20.6 |
  | read back book.txt | 0.3 | 4.6 | 13.9 |
  | sum | 45.3 | 82.8 | 166.1 |

- At 109,500 entries the live book is 94.9 MiB; `startup_probe detail` there gives a
  163.1 ms save, matching the sum.
- qemacs's save (read in `buffer.c`): renames the old file to `file~`, writes in place,
  requests no flush and detects outside changes by mtime and size only. None of it is
  adopted: Bakhlo's flushes and content checks are user decisions or intentional.
- Not executed: a save on a copy of the household book (a write flow).

## Display widths against Unicode 16.0 (2026-11-09)

- Compared `Width.cells` with widths from Unicode 16.0.0 `EastAsianWidth.txt` (SHA-256
  `43adc76c…5d5b`; W/F two, Mn/Me none, the rest one, as qemacs's generator): about
  10,900 code points in 464 ranges differ (scripts and file in ignored scratch).
- Latest-data check, read only: a fresh `./tools/compare refresh` copy of the household
  book.txt and config has no character whose width differs. The household was unchanged;
  `clean-copies` ran afterwards.
- Not executed: alignment in a physical terminal (WezTerm's own width rules).

## The startup probe is built by dune (a15187d, 2026-11-09)

- `./tools/check` and `./tools/format --check` passed; CI for `a15187d` succeeded.
- `./tools/startup-probe 1000` ran from the dune-built probe (synthetic, macOS x86_64):
  save with full sync 47.9 ms (median of 21), `Book_txt.read` 7.4 ms, cold load
  8.5–12.8 ms.

## One way to choose in every bk command (858b489, 2026-11-09)

- `./tools/check` passed (build, samples, bk command checks, privacy scan), with new checks
  `bk-r-enter-takes-the-first-locus`, `bk-r-letters-narrow-the-loci` and
  `bk-todo-done-narrows-by-text`. CI for `858b489` succeeded.
- `./tools/format --check` was not run before that commit (it was wrongly taken to be
  unavailable); its formatting came in the next commit, after which the check is clean.
- **Not executed:** latest-data paired comparison (no Core change), physical terminal and IME.

## The TUI is removed (2026-11-09)

- User decisions: the TUI goes once the bk commands cover what the household uses
  (2026-11-08); settlements, never used here, are dropped; the remaining reports are not
  added for now. `tui/` (about 43,800 lines with its checks), `tools/tui`,
  `tools/ci-tui-pty`, `tools/arch` with `test/arch.t`, the paired-UI example and the CI PTY
  lane are deleted (in Git up to `a346668`). Notty and uutf are no longer dependencies.
- `cli/` holds the commands and the few pure helpers they used from the TUI (Draft
  wording, Book_display, Locus roles, Attention, coverage rules, balance view), plus
  `Width` (an own East Asian width table instead of Notty), `Config` (settings files beside
  the book) and `Pace` (today's pace, What-if and target plans, moved from the Daily Pace
  screens). The pace breakdown is printed as a table. Plain `bk` prints today's pace and
  the command list. `tools/household` builds and runs `cli/bakhlo.exe`; its cram test
  follows; `./ui` runs bk commands on comparison copies or the synthetic preview.
- `./tools/check` exited 0: all samples, the launcher cram test and every bk check (now
  `cli/test/cli_checks.exe`) pass, including the hand-built Japanese table lines with
  the new width table. Real-terminal IME use is not qualified.
- Docs follow (same day): the TUI-only docs (TUI ownership, UI direction, the per-screen
  LOAM gap ledger, the five-area diff ledger, the cutover checklist) are in Git up to
  `6453e14`; ARCHITECTURE describes cli/store/household/book_txt; `tasks/todo.md` keeps the
  plan and open decisions. cppo, ocamlbuild and topkg (Notty's build tools) left the lock
  too: 51 locked packages.

## bk reg, month, report ie, day (2026-11-08)

- `bk reg <account> [terms]` lists an account's records with the balance at the end of
  each day from `Book.pools_at_end_of_days` (`?` where unsupported, never guessed);
  `bk month [period]` income/expense by month (`Income_expense`), `bk report ie` one
  window by account (default the current cycle), `bk day [date]` records and due plans.
  `Query.days` exposes period words. Tried on synthetic books; `./tools/check` exited 0
  (the every-command check runs each).
- Follow-up: hand-built expected lines for all four views on a book with roles (a
  supported and an unknown day-end balance, a month, a window by account, a day with
  an overdue plan) passed on the first run; a wrong balance made the check fail.

## bk todo (2026-11-08)

- `bk todo` lists open Attention matters with their due state; `add`, `done` and `drop`
  add, resolve and drop one, saved as the book's Attention section through the single
  writer (`Attention_data`'s rules). A CLI check pins the list (a past due marked `!`)
  before and after a matter is done; a wrong line failed. `./tools/check` exited 0.
- Settlements (the commitment trial sidecar) were not moved: the household has no
  `settlements.tsv` (only the file's presence was checked, not read), so whether to keep
  or drop the feature is left to the user.

## bk fx and original amounts (2026-11-08)

- `bk fx` records an exchange; its construction moved from the Exchange screen into
  `Record.exchange` (keys `exchange-source` / `exchange-destination`, refusals
  `same-measure` and `non-positive-amount`), which the screen now calls; the screen's
  own same-Measure check went, the core's refusal keeps its wording. `o` at Save in
  `bk r` / `bk pay` adds an original amount and reviews the same rows again.
- Four hand-written FX samples in `test/records/forms.answers` (with and without memo,
  same Measure, a hidden Locus refused by Book) passed on the first run. CLI checks pin
  the saved exchange and original amount; a wrong amount failed. The pay Preview check
  was updated for the longer Save prompt. `./tools/check` exited 0.

## Daily Pace settings as commands (2026-11-08)

- `bk pace pool` chooses the pool from `Book.pool_candidates` (exact-current balances
  grouped by support; moved from the pool picker, which now calls it), `bk pace cycle`
  edits the current preset through `Period.set_preset` (moved from the cycle editor:
  replace or add a preset, refuse unless today's single cycle is that preset's, new
  refusal `other-preset:<name>`; `Period.print` writes the file back), `bk pace if`
  and `bk pace target` reuse the What-if and target-plan functions. Settings files are
  replaced only if they still hold what was read (`Shell_files.write_config`, now
  addressed by the book path).
- Samples: `test/periods/set.answers` (9 hand-written edits: extend, no cycle,
  another preset, malformed, new file, two presets) and a pool candidates line in
  `test/loci`; all passed on the first run. CLI checks pin both saved files and a
  hand-computed what-if (-4,995 a day); a wrong answer made it fail. `./tools/check`
  exited 0.

## bk check and bk loci (2026-11-08)

- `bk check` saves balances seen outside (Observe). A balance resting on the records (zero
  origin or an opening) is not overwritten: book txt refuses that overlap
  (`support-admission`), so the command compares it and shows the difference to record
  instead; `Book.observation_refusal` owns that rule. `bk loci` lists accounts with role and
  balance; `add`, `name`, `role` add an account, rename it and give it a role once
  (`Book.role_refusal`, now also used by the Loci screen with its wording). Hiding an
  account existed neither in Book nor in the TUI and is not added.
- `test/loci/rules.answers`: 7 hand-written answers (roles once, suspense, seen balances
  over zero origin, opening, counted and unknown), all passing on the first run; a wrong
  OBSERVE answer failed at its line. CLI checks pin the comparison table (built by hand),
  a saved seen balance and each Loci change. `./tools/check` exited 0.

## Record corrections as commands (2026-11-08)

- `bk edit` / `date` / `refund` / `shop` choose a record with `bk find` terms, newest first
  (number, or more terms to narrow). Edit corrects rows (keys kept), memo and date through
  Record; date moves only the date; shop sets the shop once. The refund rule moved from
  `tui/shell/publication.ml` into `Record.refund` (the TUI calls it, wording unchanged);
  its memo is now "Refund: <memo>" instead of naming the original's internal ID (the
  link stays in `REVERSAL-OF`). Book refusals are worded in one place in the CLI.
- Samples: six hand-written REFUND answers in `test/records/forms.answers` (refund with
  keys, without memo, with original and shop not carried, unknown, already refunded, a
  refund itself), all passing on the first run. CLI checks pin each correction's book
  text and a worded refusal; a wrong refund memo made the check fail. The command table
  now builds commands from the words after them, so help and dispatch stay one table.
  `./tools/check` exited 0.

## bk find (2026-11-08)

- User decision: TUI replaced by `bk` commands (AGENTS Product, `tasks/todo.md`). First
  of the remaining commands: `bk find` lists records matching every term, hledger-style:
  a plain word in a Locus name/ID or memo, `acct:`, `memo:`, periods (`2026`, `2026-10`,
  `2026-10-05`, `A..B`, `date:`), amounts (`amt:1200`, ranges `amt:1000..` that need no
  shell quoting, `>`/`<` forms). Rules in `household/query.ml`; a word shaped like a period
  but invalid is refused, never searched for.
- `test/queries/find.answers` pins 32 hand-written queries (first run: 0 failures after
  the expect count; dropping one expected record failed at its line). CLI checks pin the
  printed table, the count and a worded refusal. `./tools/check` exited 0.

## bk plans (2026-11-08)

- User request: the Scheduled operations as commands. `bk plans` prints each series (to,
  from, next amount, next and last day filled, open count; overdue, and the cadence and
  first missing month when `scheduled-coverage.tsv` watches it). `bk plans more` fills the
  coming months from the last plan (a month without its day is dated by the person or
  skipped), `amount` re-prices a series from a day on, `cancel` cancels chosen plans
  (numbers and ranges). Each previews and saves its changes together through
  `Book_file.publish`; rules are `Schedule`'s.
- Synthetic checks with hand-built lines: the series list with its heading, filling with
  a missing 31st, a re-price from a day, an unchanged re-price writing nothing, and a
  chosen cancellation. All passed on the first run; a wrong missing month made the list
  check fail. `./tools/check` exited 0. Not executed: household use.
- Follow-up from first household use (a transfer copied from earlier rows with a new
  amount, and trying `q` to leave the plan list): the last earlier row now offers the
  balance of the rows above it, earlier-row amounts are grouped, and an answer that
  matches no plan or series says how to quit (Ctrl-D) without reprinting the list.
  Checks pin both; a wrong hand line count was replaced by the whole expected text.
  CI for `8d172e7` passed on its fifth attempt (attempts 1-4 failed at `setup-ocaml`
  with HTTP 504, before any build step).
- Follow-up (user request): after a saved record or payment, `bk r` / `bk pay` ask
  "Record another?" / "Pay another?" (Enter: no). The next one works on the book as saved,
  so its earlier rows include the one just saved and no conflict arises; a check pins
  this, and using the book from before the save made it fail.
- Follow-up (user request): `bk help` lists every command, and an unknown command prints
  the same list (exit 2). One table in `tui/app/command_line.ml` both dispatches and
  lists them; a check requires every listed command in the help and runs each on a
  synthetic book (no answers: it stops and writes nothing). Adding a command missing
  from the help made it fail.
  CI for `77555f9` first failed in the Linux PTY matrix ("TUI exited with code 1", no
  other output); the same matrix passed locally on macOS and the rerun of that job
  passed. Recorded as an unexplained one-off, not a fix.

## Plans in series move to the core (2026-11-08)

- Before the `bk plans` commands: grouping open plans into series (same Measure and
  signed Loci), the batch amount change and the replenishment date rule moved from the
  Scheduled editors into `household/schedule.ml`; the bulk and generation editors call it
  and keep their wording. An unreachable refusal went (an admitted plan always has both
  sides). `test/scheduled/series.answers` pins 17 hand-written answers (series, a series
  from a plan, five amount changes, eight dates incl. leap years and missing days); the
  first run had 0 sample failures (only the count in the expect line was off), and a
  wrong leap-day answer failed at its line. TUI self-check exited 0.

## Line commands bk r and bk pay (2026-11-08)

- User request: try recording without the TUI first. `bk r` records an Actual and `bk pay`
  pays a plan with one-line answers (`tui/app/line_commands.ml`): Locus by the screens'
  prefix candidates (one is taken, several are numbered), Enter on an amount balances
  the rows, a memo recorded before offers its earlier rows, plans are listed oldest first
  (overdue marked) and Enter through the Preview pays as planned; `e` edits the rows.
  Rules are `Record`'s, refusals and the Preview are the screens' (`Draft`,
  `Book_display`), the save is `Book_file.publish` against the loaded session.
  `tools/household` passes its arguments to the binary, so commit and backup are unchanged.
- Synthetic checks in the TUI self-check: prefix and numbered picks, the balancing
  default, earlier rows, a refused amount worded as on the screen then fixed, EOF and
  `n` writing nothing, paying as planned and with an edited amount (PAID-BY written), and
  a book changed meanwhile refused as a conflict. `./tools/check` exited 0. A first run
  failed on the refusal case because the editor duplicated the balance rule; the rule
  was left to the core. Not executed: IME composition in a real terminal, household use.
- Follow-up (user request): `bk bal` prints the Balances Current rows and `bk pace` today's
  Daily Pace with its `?` breakdown, from the same config files (the screens' pool/window
  resolution and Current rows are now callable without a screen). A synthetic check
  pins hand-worked answers (-83,900 free over 17 days, -4,936 a day); changing that
  answer made the check fail.
  One `./tools/check` run right after editing `tools/household` failed in the architecture
  check (`Sys_error ../../tools/household`): it walks the whole tree but declares only
  `tui/` and dune files as inputs, so it raced Dune refreshing that copy. The rerun
  exited 0; the check's inputs are not changed in this slice.
- Follow-up (user report: `bk bal` and the plan lists were hard to read): lists are now
  tables padded by display width (a wide character takes two cells), text left and
  amounts right, so Japanese names no longer shift the columns and long names are not
  cut. Covers `bk bal`, the plan list of `bk pay`, the Locus choices and earlier rows of
  `bk r`. The synthetic checks pin hand-built lines, including a Japanese-named Locus;
  one extra space there made the check fail.
- Follow-up (user: the `[ID]` after each name made the columns ragged): `bk` lists name
  a Locus by its display name only; the ID (the book's internal name) is added only when
  two Loci share a label, and a Locus whose label is its ID shows the ID. Pinned by a
  synthetic book with a shared label; one extra space there made the check fail.
- Follow-up (user decision): the `bk pay` list drops the plan ID (internal, e.g. an
  imported `scheduled-NN`): a plan is its day, Loci and amounts, and typing narrows to
  plans moving a Locus whose display name or ID starts with the answer. Narrowing by a
  plan ID prefix no longer selects (checked by reverting the check's input). The
  Preview still names the plan, as on the screen.
- Follow-up (user request): `bk` has its own Preview without IDs: the plan it pays by
  its due day, the day and memo, and each row by display name (the screens' Preview,
  with plan, entry and Locus IDs, is unchanged in the TUI); "Saved." no longer names
  the new entry ID. A hand-written Preview is pinned; a wrong due day made it fail.

## Lighter docs (2026-11-08)

- User request: make the docs lighter. VERIFICATION keeps the last week (from 2026-11-02);
  older entries stay in Git at `5b48008`, and every link to them in docs, `tasks/todo.md`
  and examples became a permalink at that commit. HANDOFF is a short current state (its
  dated log is in Git at `5b48008`). The finished performance/GADT study and the stopped
  admitted-types study are in Git only (pointers in HANDOFF and `tasks/todo.md`).
  tui/README lost stale scope, sharing-plan and Stock–Flow text now owned by the
  ledgers and samples. Docs and tui/README: about 7,250 -> 3,200 lines.
- `./tools/check` exited 0; `./tools/privacy-scan --all` found no match.

## One sample format and reader (2026-11-08)

- The six sample folders share one format (`test/README.md`): `#` notes, `USE <name> <file|->`
  context, one-line or `END<KIND>` block questions, reprint-and-compare by
  `test/samples.ml(i)`; runners keep only their per-kind answers. Every `cases.tsv`,
  `.changes` and `.pace` file went (95 files): notes became `#` lines, change samples
  became `APPLY` blocks in one `changes.answers` per folder. A script compared every
  APPLY block with the old change lines, expected code, before-book and pace answers
  (no difference). Counts unchanged: amounts 78, periods 73, reports 102, common
  format 5+59, Scheduled 14/14/27, Actual changes 13/41.
- Record: `OPEN ENTRY|PLAN` replaces EDITABLE, POSTINGS and PAY-DRAFT (10 questions);
  MOVEMENT went. An admitted book has no empty, zero or unbalanced Movement or undeclared
  Measure, and a form has one Measure and positive amounts, so `movement_fault`,
  `of_effects`, `pair` and their screen messages were unreachable and were removed
  (`Record.open_edit` / `open_plan` remain; `movement:unbalanced` is now `unbalanced`).
  Dropped as unreachable: EDITABLE unknown-scale, POSTINGS invalid / unknown-scale and
  five MOVEMENT faults. Record questions: 37 -> 28 (10 OPEN, 18 FORM).
- Breaking one answer each in reports, scheduled, records changes and forms gave four
  `FAIL <file>:<line>` lines; restored. `./tools/check` and `./tools/tui --self-check`
  exited 0. Started by omp, which stopped on its usage limit; finished by hand.

## Record form tidy and one amount rule (2026-11-08)

- User decision: the Original field reads amounts with `Amount.parse_positive`, as the
  Record rows do. `12,34.5` is now refused (it was read as 1234.5), and arithmetic
  and full-width digits are accepted; saved Original amounts are unchanged. The
  separate Original parser and its 19 `ORIGINAL-INPUT` answers were removed; the
  rule is pinned by `test/amounts/`, and two screen checks pin the field wiring
  (misgrouped comma refused, `(10+20)/2` gives 15.00 eur); breaking the second failed.
- `Record.mode` holds only Actual modes; Scheduled modes are the screen form's
  (`Draft.mode`), so `build_plan` takes `~editing` and lost its impossible branch.
  The one-case `Multiple` became the record `Record.content`; the unreachable
  `day-invalid` was removed (`Day.normalize` returns real days only).
- `./tools/check` and `./tools/tui --self-check` exited 0. Latest-data paired
  comparison not executed.

## Actual recording answer samples (2026-11-08)

- Hand-written, synthetic contracts: `test/records/` has 54 Book changes
  (13 exact after-books, 41 refusals) and 56 Record questions; `test/amounts/`
  has 78 parse/format answers. Scheduled and Actual share one change runner.
  Reasoning was written before execution in ignored `scratch/omp-briefs/records-notes.md`.
- `household/record.ml` owns form construction, movement faults, edit eligibility,
  plan prefill and the Original field's distinct decimal grammar. Screens keep
  their messages; Book_txt admission and saved bytes remain unchanged.
  Put_entry now carries `entry-admission:<code>`; publication keeps its old wording.
  Follow-up: Merchant refusals are Book codes (`merchant-classified`, `merchant-unknown`,
  `merchant-token`, which now also refuses a space), and date corrections and
  classifications carry `entry-admission:<code>` too; the runner no longer translates.
- First command: compilation stopped on two docstrings; the next on two missing
  wrapper exports. First executing run: zero new-sample mismatches, one obsolete
  coarse-code assertion. Three deliberately wrong answers each failed, then were
  restored. Covered old assertions/dead bindings were removed; no test module or
  dune stanza was deleted. UI/key/draft/no-write/cold-reload checks remain.
- Format/apply, full check and TUI self-check exited 0. The real synthetic PTY
  smoke passed four sizes, startup keys and narrow Record Preview refusal with
  unchanged book bytes. The gates and `privacy-scan --all` were rerun independently
  before commit and exited 0. Latest-data paired comparison not executed (no displayed
  answer changed; Record screen text is pinned by the TUI checks); no IME or P7 claim.

## Remaining report calculation samples (2026-11-08)

- User request: move the report calculation rules still asserted by old tui checks
  into the samples. Delegated to omp (parent Codex, deepseek subagents) in Rex with
  a written brief; omp did not commit. 46 report questions (102 in all) and 15
  period lines (73) were written by hand with the arithmetic noted before running,
  including `TREND-CATALOG`, `ELAPSED` and `SAME-AGE`. The only production change
  moves I&E's comparison windows into `Period.elapsed` / `Period.same_age`,
  unchanged.
- First run: every answer that ran matched; one sample book refused
  `section-order` (HISTORY-FROM after ANCHOR) and was reordered without touching
  its answers. Three deliberately wrong answers each failed, then were restored.
- The matching calculation assertions and dead fixtures left the Liquidity,
  Multicurrency, Stock–Flow, Trend projection and I&E frame checks; screen text,
  formatting, the twelve painted Liquidity rows, no-write, cache and cold-reload
  checks remain, and omp's reviewer added explicit checks for the painted
  Liquidity dates and exchange memo.
- Claude re-derived four samples by hand (Liquidity path, Stock–Flow bounded and
  whole-history windows, Trend history start and negative floor, the leap year),
  read the diff, and ran the gates itself (below). Synthetic only.
- `./tools/check`, `./tools/tui --self-check`, `./tools/format --check`,
  `./tools/privacy-scan --all`: exit 0 (102 report answers, 73 period answers). No
  displayed answer changed, so no screen capture was taken.

## Scheduled answer samples (2026-11-08)

- User request: before a later Zig rewrite, pin plan creation, replacement,
  cancellation, payment by an Actual and today's Daily Pace as language-neutral
  answers. `test/scheduled/` holds one synthetic base book and 22 samples
  (10 applied with exact `book.txt` after, 12 refusals with reason, 11 Pace
  questions with exact answers); `test/scheduled/README.md` defines the files.
- The after files and Pace numbers were written by hand from the rules, not
  printed from Bakhlo. `test/scheduled_tests.ml` runs them through `Book.apply`
  and `Book.daily_pace`: all 22 matched on the first run. Three deliberately
  wrong answers (a Pace day value, a refusal code, a CANCELLED date) each
  produced a failure, then were restored.
- `./tools/check`, `./tools/tui --self-check` and `./tools/format --check`: exit 0.
- Not covered: the past-day Pace (History) treatment of paid, reversed and
  cancelled plans still lives in `tui/screens/pace/daily_pace_trend.ml`.
- Follow-up, user decision A: `COMMON_FORMAT` said HIDDEN never refuses
  corrections or refunds, but `Book.put_entry` refused them. Now a correction may
  keep its entry's own Loci and a reversal may use its target's; any other HIDDEN
  Locus is still `locus-unapproved`. Four hand-written samples were added
  (12 applied, 14 refused, 11 Pace answers, 0 failures). `book_cold_reload_tests`
  now expects the correction and refund to save and a correction into a new HIDDEN
  Locus to refuse; the Actual scenario reaches the correction Preview and saves
  the refund on its own copy, keeping the plan paid. LOAM still refuses both;
  this is recorded as an intentional difference. Real-data comparison of this
  change **not executed**.
- Follow-up, at the user's request: History's plan rules moved from
  `tui/screens/pace/daily_pace_trend.ml` into `household/book.ml`. `past_paces`
  owns the past-day guide (a paid plan stays protected until its payment day; a
  cancelled plan is never protected) and `day_activities` the per-day split
  (Scheduled payments and their refunds, the protection released on the paying
  day, same-day reversal pairs cancelled). Today's guide and past days share
  one `protected_plans` rule. The screen keeps period resolution and wording.
  Samples gained `PAST` and `ACTIVITY` questions written by hand (14 applied,
  14 refused, 27 Pace answers, 0 failures on the first run); a wrong PAST pace
  and a wrong released amount each failed, then were restored.
- `./tools/check`, `./tools/tui --self-check` (existing Daily Pace History,
  activity and change checks unchanged), `./tools/format --check` and
  `./tools/privacy-scan --all`: exit 0.
- Before (`c9a14ae` export) and after binaries; fresh `./tools/compare refresh`.
  `scratch/history-core-20261108/capture.sh` at synthetic and latest-copy
  120×36/80×24: all five presets, a day seven days back, its Selected day detail
  and its End scroll read byte-identical before/after; presets, the past day and
  the detail differ from each other, so the flows were reached. Original, copy and
  synthetic digests unchanged; owned tmux closed; `clean-copies`: exit 0. LOAM
  was not driven (no displayed answer changed).
- Follow-up, at the user's request: periods. `Day` moved from `tui/book` into
  `household/`; Book and History now count days through it instead of their own
  copies. `household/period.ml` owns boundary-presets.tsv reading, the cycle of a
  day, Day/Month/Year/Cycle/Previous/All windows and the Daily Pace History
  ranges; `Boundary_presets` and History's and the Trend report's own copies were
  removed, and `Period_window` only adds report labels. One rule changed: Actual
  and the reports picked the first preset covering today, while Daily Pace and
  the Trend report refused; all now refuse (`ambiguous:<day>`). The household's
  presets do not overlap. Wording: "Cycle not configured…" and Daily Pace's
  missing previous cycle now read as the shared Period messages.
- `test/periods/` (README, 10 samples, 58 question/answer lines) written by hand;
  `test/periods_tests.ml` agreed on the first run, and two wrong answers each
  failed before being restored. The old `boundary_presets_checks` cases are now
  samples. `./tools/check`, `./tools/tui --self-check`, `./tools/format --check`,
  `./tools/privacy-scan --all`: exit 0.
- `scratch/period-core-20261108/capture.sh`, before (`5d905a1` export) and after,
  fresh `./tools/compare refresh`: Daily Pace presets 1–5, Actual at its window,
  `[`, `]]`, `{`, and the period picker with `l`, `l`, `hhh`, at synthetic and
  latest-copy 120×36/80×24. Latest copy: byte-identical throughout. Synthetic: the
  only difference is the missing-previous-cycle message (and its wrap); every
  other capture is byte-identical. Digests unchanged; owned tmux closed;
  `clean-copies`: exit 0.
- Report period screens, same binaries, fresh generation (`reports.sh`, `trend.sh`):
  Income & Expense, Transactions Flow and Stock–Flow through periods 1–5, Cycle
  `[` `]]`, Month `[`; Income & Expense table and compare picker; Trend / Locus
  open, `←` `←` `→→→`, finer grain and `←`; Liquidity and Multicurrency open,
  Multicurrency `[` `]]`. Synthetic and latest copy 120×36/80×24 (Trend / Locus
  moves on the latest copy only): 36 + 6 flows per size, all byte-identical
  before/after; the moves change the screen, so they were reached. Synthetic
  Stock–Flow and Trend / Locus stay unavailable (no balance-view.tsv or Locus
  selection) identically before and after. Digests unchanged; owned tmux closed;
  `clean-copies`: exit 0.
- Follow-up, at the user's request: reports and Actual's totals. `test/reports/`
  (README, one synthetic book with two currencies, an exchange, a refund, a
  role-less Locus and three plans; a separate book of Original-amount witnesses)
  holds 29 hand-written questions: EXPENSE-TOTAL (Actual day header and period
  windows), INCOME-EXPENSE, TRANSACTIONS-FLOW, STOCK-FLOW, TREND, TREND-DEFAULT,
  LIQUIDITY and MULTICURRENCY. `tui/app/test/report_answers.ml` reprints each
  block from the report screens' calculations (Actual now exposes
  `expense_sums` under its text total): 29 answers, 0 failures; every hand answer
  matched, the only fixes being in the sample files (a section order in the witness
  book; an answer line read as the block end, now `BALANCE-START`/`BALANCE-END`); three
  deliberately wrong answers each failed, then were restored. No displayed
  answer changed, so no screen capture was taken.
- `./tools/check` (runs the 29 answers), `./tools/tui --self-check`,
  `./tools/format --check` and `./tools/privacy-scan --all`: exit 0.
- Pinned as current behavior: report refusal reasons are English sentences, not codes.
- User decision (2026-11-08): the samples showed Income & Expense counting the
  refund of a plan's payment as other spending while History counted it with the
  plan. Now `Book.settles_plan` (pays a plan or reverses such a payment) owns the
  rule for both; the February window answers Scheduled −80000, other 0, and the
  old answer fails (1 failure), 29 answers, 0 failures. The I&E help line now
  reads "Scheduled: paid for a plan, or its refund" (a longer first try wrapped
  mid-word at 120×36, so it was shortened). LOAM links Scheduled by the payment's
  correction root; whether a refund falls under it was not checked, and LOAM was
  not driven.
- Before (`974d7e4` export) and after binaries, fresh `./tools/compare refresh`,
  `scratch/ie-refund-20261108/capture.sh` at 120×36/80×24. Synthetic (the
  test/reports book): the February summary split and the February and March
  tables move the refund from other to Scheduled, and the help line changes;
  the other flows are byte-identical. Latest copy: Income & Expense open,
  periods 2–5 and twelve months back with their tables (31 flows) are
  byte-identical; only the help line differs. Digests unchanged; owned tmux
  closed; `clean-copies`: exit 0. `./tools/check`, `./tools/tui --self-check`,
  `./tools/format --check`, `./tools/privacy-scan --all`: exit 0.
- Follow-up, at the user's request: report calculations move into the core so that
  the core and its samples hold every rule. `household/income_expense.ml`,
  `transactions_flow.ml`, `liquidity.ml` and `multicurrency_spend.ml` own them and
  read the book's own roles; the screens keep labels, order by label and text.
  The answer runner calls the core for these four. 29 answers, 0 failures;
  `./tools/check`, `./tools/tui --self-check`, `./tools/format --check`: exit 0.
  Then `household/trend.ml` (the screen copy is removed; grain and scope names
  stay in the screen), `stock_flow.ml` (the screen passes its window label) and
  `Income_expense.spending` for Actual's day and window totals; Actual and Trend
  read the book's roles, not a separate list. The answers moved to
  `test/reports_tests.ml`, which needs only the core; a wrong BALANCE-START
  failed there, then was restored. 29 answers, 0 failures; `./tools/check`,
  `./tools/tui --self-check`, `./tools/format --check`: exit 0.
- Before (`d6200ef`) and after binaries, fresh `./tools/compare refresh`,
  `scratch/report-core-20261108/capture.sh`: all six reports through their
  period keys, four months back and ahead, the I&E table and compare picker, the
  Transactions Flow detail, Trend moves, and Actual's window, `[` `]]` `{` and
  period picker, on the test/reports book (with balance-view), the synthetic
  book and the latest copy at 120×36/80×24: 69 flows each, 414 captures, all
  byte-identical; 49 and 64 distinct screens per size (samples, latest), so the
  flows were reached. Digests unchanged; owned tmux closed; `clean-copies`: exit 0.
- Follow-up, at the user's request: report refusals as codes. Liquidity,
  Multicurrency Spend, Stock–Flow and Trend / Locus refuse with a variant whose
  `code` is language-neutral (`overdue:<plan>`, `no-cycle:<day>`, …) and whose
  `message` is the screen's sentence, unchanged except two Stock–Flow date
  sentences that still began with "loam:". Refusals an admitted book cannot reach
  (an invalid plan or entry day, a missing exchange leg) were removed instead of
  coded; Book refuses those on read and save. Samples: TRACK and LOCUS lines now
  name their Measure (the TREND header lost its own), 25 new refusal questions (28 in
  all) and two cases (no presets; two overlapping presets, with one day only one
  covers) were written by hand. 55 report
  answers, 0 failures on the first run; a wrong code failed, then was restored.
- `./tools/check`, `./tools/tui --self-check`, `./tools/format --check`: exit 0.
  Before (`4a01e8a` build) and after, fresh `./tools/compare refresh`, the same
  `capture.sh`: 414 captures byte-identical (69 flows per dataset and size). The
  copy and fixture digests are unchanged. The original book.txt digest changed
  during the run: the user recorded through `./tools/household` (file 11:17:43,
  its commit 11:17:45, the user's session still open); the AI only opened copies.
  Owned tmux closed; `clean-copies`: exit 0.
- Follow-up, at the user's request: Stock–Flow's support reasons as codes.
  `Stock_flow.missing_support` (`no-support`, `empty-cell`, or a Book history code)
  has `missing_code` and `missing_message`; the screen and print preview keep the
  same sentences. The samples name `no-support` and gained an `empty-cell` question
  written by hand: 56 report answers, 0 failures on the first run; a wrong reason
  failed, then was restored. Combinations Book refuses on read (support-overlap,
  history-unanchored) never reach a report.
- `./tools/check`, `./tools/tui --self-check`, `./tools/format --check`: exit 0.
  Before (`362dfcd` build) and after, fresh `./tools/compare refresh`, the same
  `capture.sh`: 414 captures byte-identical; original, copy and fixture digests
  unchanged; owned tmux closed; `clean-copies`: exit 0. No captured Stock–Flow
  selection has an unsupported cell, so the reason sentence itself was compared
  by its unchanged text, not on screen.
- Follow-up, at the user's request: old report checks that the samples pin were
  deleted. The work was delegated to omp (parent Codex, deepseek subagents) in Rex
  with a written brief; omp only edited, and Claude checked each deletion against
  its sample, read the diff and ran the gates. 4 files, 229 lines removed
  (Liquidity, Multicurrency Spend, Stock–Flow and Trend refusals and answers that
  test/reports holds). Kept, as no sample covers them: screen, text and formatting
  checks; non-canonical dates and empty tokens; negative, huge and other-Measure
  amounts; display limits; inside/after-window openings, bounded history,
  observation and other-Measure openings in Stock–Flow; leap days, scope clamps,
  catalog and mutation checks in Trend; I&E comparison windows; cold reloads.
- Claude's own run: `./tools/check`, `./tools/tui --self-check`,
  `./tools/format --check`, `./tools/privacy-scan --all`: exit 0. Only test files
  changed, so no screen capture was taken.

## Record and Preview typography (2026-11-07)

- The user approved continuing the typography series to Record/Preview and asked
  to finish it at a clean point and push it together with the local Daily Pace
  commit `c83645c`. A previous assistant left the slice uncommitted; this pass
  reviewed that diff, ran it and completed the evidence. Remote HEAD was `0153434`.
- `Book_display` now builds Preview rows as `(style, text)` from book fields, never
  from parsing a memo or label: exact Effect quantities (with keys), Date, Original
  amount, Original due date (kept) and Balanced total use Heading; the Effects
  heading, ID and Measure use Chrome; descriptions, Merchant, links and status
  stay Plain. `entry_lines`/`plan_lines` keep their exact text for Actual, Selected
  Day and Scheduled details. The Record form makes a filled, inactive Amount
  Heading; the active field keeps its caret. Wrapped continuations keep the style.
  No text, row order, wrapping, geometry, keys, calculation or save path changes.
- Added checks in `record_session_checks.ml`: exact Preview text and styles for a
  new Movement, a Scheduled plan (open/cancelled/completed) and a Scheduled
  completion; a memo that looks like labels stays Plain prose; Original amount
  and EUR scale stay exact; keyed postings and the completion backlink; 120×36,
  80×24 geometry; a 32×9 huge-quantity continuation keeps Heading; inactive
  filled Amount is strong and the active caret remains at 48×14/80×24/120×36.
- `rtk test ./tools/check`, `rtk test ./tools/tui --self-check` and
  `./tools/format --check`: exit 0.
- Before (`HEAD` export) and after binaries built in ignored scratch.
  `./tools/compare refresh`: exit 0, fresh generation. A scratch tmux script
  drove Record full form → Preview → End → Escape (draft held, never published)
  at synthetic 120×36/80×24/48×14/32×9 and latest-copy 120×36/80×24: plaintext of
  all four flows matches before/after (generated entry ID masked); Preview ANSI
  differs at every size except 32×9, where only the action line is visible.
  Same-generation LOAM reaches Record / Preview at both latest-copy sizes; its
  existing layout difference is unchanged here and LOAM shows no bold.
- Follow-up the same day, at the user's request: Scheduled Previews in a PTY with
  the same before/after binaries and a fresh `./tools/compare refresh`. From
  Scheduled List, Edit (`r`, same ID) and Complete (`Enter`) advance field by field,
  checking for the Preview title before every Enter so nothing is confirmed;
  New (`n`) has its own editor, not `Book_display`, and serves as a control.
  At synthetic 120×36/80×24/48×14/32×9 and latest-copy 120×36/80×24 all three
  reach Preview; form, Preview and End plaintext match before/after (entry ID
  masked). Edit/Complete Preview ANSI changes (at 32×9 only after End, where the
  rows are visible); New stays byte-identical. Newly bold rows are the posting
  quantities, Due/Original due date and Balanced total. LOAM was not driven for
  Scheduled here. Digests unchanged, owned tmux closed, `clean-copies`: exit 0.
- CI for `4473f91` (`core.yml`, including the Linux PTY smoke): success.
- Original, both copies and synthetic book/config digests unchanged; owned tmux
  servers closed; `./tools/compare clean-copies`: exit 0. Private captures stay in
  ignored scratch. Physical terminal/font, IME, human acceptance and P7/power-loss
  **not executed**.

## Daily Pace local commit qualification (2026-11-07)

- User gave favorable feedback on both typography trials and requested committing
  before continuing to Record/Preview. Reviewed scope is the seven Daily Pace
  source/test/policy/ledger/evidence files; no unrelated changes were staged.
- Fresh `rtk test ./tools/check`, `rtk test ./tools/tui --self-check`,
  `./tools/format --check`, `./tools/privacy-scan --all` and `git diff --check`:
  exit 0. The prior synthetic/latest-copy comparisons and scoped static reviews
  are recorded below, not rerun or upgraded into full acceptance in this commit pass.
- This is a local commit only. No push was requested; remote HEAD remains
  `0153434`, so daily `bk` remains unchanged. No matching-new-SHA CI claim.
  Physical terminal/font/IME and P7/power-loss remain unqualified.

## Daily Pace Selected day typography trial (2026-11-07)

- After favorable feedback on History, the user requested continuing with Selected
  day. Remote HEAD remains `0153434`; the prior uncommitted History slice is retained.
  The before executable was rebuilt and byte-matches that History trial's after
  binary. No commit, push, dependency, format, font, palette or launcher change.
- Only `Daily_pace_trend.render_detail` styles change: Selected date, Pace and Spent
  lines use Heading; Pool/deductions/Available, activity inflows/settlements/reversals
  and day-to-day money terms use Plain. Periods, provenance and disclosure remain
  Chrome. Unknown pace and its cause, and unavailable day-to-day breakdown, use
  Status. Existing whole-line wrapping keeps the same style on continuation lines;
  no span/wrapping engine, extra rows, changed text, calculations or save path.
- Existing exact full/partial/unknown detail assertions now specify those styles
  without dropping their text/order checks. Added tests cover ordinary inflows,
  scheduled-linked reversals, settlement variance, negative 400-digit quantities,
  cycle-reset refusal, and exact text/style wrapping at widths 8/26/42/74/114.
  The added detail checks use JPY; other currency formatting is unchanged and the
  existing broader scale checks still pass, not new detail-specific scale coverage.
- `rtk test ./tools/opam exec -- dune runtest tui/app/test --force`: exit 0.
  `rtk test ./tools/opam exec -- dune build tui/app/bakhlo_tui.exe`: exit 0.
  `rtk test ./tools/check`, `rtk test ./tools/tui --self-check` and
  `./tools/format --check`: exit 0. Pinned local ocamlformat ran on the two touched
  source files. Read-only independent review found no blocker and confirmed History
  unchanged; that reviewer did not run tests or inspect private comparisons.
- `./tools/compare refresh`: exit 0, fresh generation for this follow-up.
  `sh scratch/pace-detail-type-20261107/capture.sh`: exit 0. Before/after Trend,
  focused Detail, End-scroll and return plaintext/geometry match at synthetic
  120x36/80x24/48x14/32x9 and latest-copy 120x36/80x24; focused Detail ANSI differs.
  Same-generation LOAM positively reaches Trend and focused Detail at both sizes.
  This is not all-five-period or full styling/operation parity acceptance.
- Owned capture sessions closed; original, both copy and synthetic book/config
  digests stay unchanged. `./tools/compare clean-copies`: exit 0. All private
  captures/results remain in ignored scratch. No operational-household TUI/write.
  Physical terminal/font, IME and Selected day human acceptance **not executed**;
  daily `bk` is not updated and P7/power-loss remain unqualified.

## Daily Pace History typography trial (2026-11-07)

- User asked to continue the typography work. Starting local main and remote HEAD
  were clean `0153434`. This trial changes only `Daily_pace_trend.render_history`
  and its existing scenario checks; no dependency, format, font or palette change.
- History's non-active dates and exact Pace/Spent/diff cells use Heading. `current`
  and absent-activity dashes use Chrome; unknown and overflow substitutions use
  Status. Column headings remain Chrome. Focused selection still paints the whole
  padded row Active; inactive `*` and partial narrow-history `>` behavior remain.
  Chart, Selected day, context/footer, keys, calculations and save paths are unchanged.
- Regression checks exercise widths 26/43/46/70/114, both focus states, span/text
  agreement, canonical table text, zero/negative/scaled quantities, unknown and
  400-digit overflow. Existing partial-history selection and exact detail tests pass.
  Read-only independent diff review found no blocker; it did not run checks or
  inspect private captures. Tiny widths and absent activity have less focused style
  coverage; existing geometry checks remain, not exhaustive byte-for-byte proof.
- `rtk test ./tools/opam exec -- dune runtest tui/app/test --force`: exit 0.
  Initial `./tools/format --check`: exit 1 for formatting only; the pinned local
  ocamlformat corrected the two changed source files. Subsequent
  `./tools/format --check`: exit 0. One overlapping executable build exited 1 on
  Dune's existing-process lock; serialized rebuild passed, exit 0.
- `rtk test ./tools/check` and `rtk test ./tools/tui --self-check`: exit 0.
  The checks include admission/saving regressions and the changed-files privacy scan.
  After the ledger/evidence updates, `./tools/privacy-scan --all`, `git diff --check`
  and `./tools/format --check`: exit 0; no private-token matches.
- Ignored scratch retains disposable before/after binaries, synthetic fixture and
  tmux captures. Before binary was rebuilt from `0153434`; after is that base plus
  this diff. Synthetic Trend, focused Detail, End-scroll and return captures at
  120x36/80x24/48x14/32x9 have identical complete plaintext before/after. Wide History
  ANSI changes; small geometries still hide History as before. No geometry change.
- `./tools/compare refresh`: exit 0, fresh household generation on this pass.
  The same generation supplies Bakhlo before/after and the existing LOAM binary.
  `sh scratch/pace-typography-20261107/capture.sh`: exit 0. At 120x36/80x24 Bakhlo's
  four flows retain complete text; LOAM positively reaches Trend and focused Detail.
  This scopes the paired check, not full operation/style parity or human acceptance.
  All private captures/digests stay in ignored scratch; no private facts recorded here.
- After closing owned sessions, original and both copy book/config digests remain
  identical, as does the synthetic fixture. `./tools/compare clean-copies`: exit 0.
  No operational-household TUI session/write, commit or push. Physical terminal/font,
  IME and human acceptance **not executed**; P7/power-loss remain unqualified.

## PTY readiness after quiet Balance titles (2026-11-04)

- Publication `d147b90` [CI run](https://github.com/shumoku88-bit/bakhlo/actions/runs/41798186668)
  failed in the Linux PTY lane: `expected terminal text absent: Balances [active]`.
  Linux setup, build and contract/regression/synthetic TUI checks all succeeded.
  `gh run watch 41798186668 --exit-status`: exit 1, not a successful qualification.
- The smoke retained two obsolete title waits, in ordinary Balances navigation
  and the startup-queue check. Both now wait for Current's unique `Selected Locus`
  context; bare `Balances` would incorrectly match the Home menu. Exact `1,000`,
  all four dimensions, key/resize/cold-reopen/exit, queued-input and non-writing
  assertions remain unchanged. No product code, workflow, dependency or gate change.
- With isolated UI settings, `rtk test ./tools/ci-tui-pty _build/default/tui/app/bakhlo_tui.exe examples/book.txt`:
  exit 0 locally on macOS. All four PTYs, startup type-ahead discard, exact unchanged
  authority, and 32x9 Preview publication refusal pass. This does not substitute
  for the next matching-SHA Linux CI run or qualify physical font/IME behavior.
- Before this smoke correction, ordinary `bk` fetched/built `d147b90`, showed Home
  and Balances with an isolated synthetic Git household/local backup remote, and
  exited 0. Synthetic book checksum and repository remained unchanged; main,
  origin/main, run worktree and installed stamp matched. No operational-household
  write or TUI session. New-commit CI/installed-revision checks are separate evidence.

## Typography series publication qualification (2026-11-04)

- User explicitly requested committing/pushing the remaining work and closing this
  pass. Starting remote HEAD was `2b03863`; local HEAD was the accepted Balances
  pilot `a0b7e6e`. No unrelated staged or untracked work was included.
- Fresh `rtk test ./tools/opam exec -- dune runtest tui/screens/balances/test tui/app/test --force`,
  `rtk test ./tools/check` and `rtk test ./tools/tui --self-check`: exit 0.
  Independent static review of the complete 11-file follow-up diff found no
  publication blocker, no apparent private material and no unintended quantity,
  action-target, save, key or geometry changes. That reviewer did not execute tests
  or independently repeat prior private comparisons.
- Scoped source/test commits: `9521d44` restores focused whole-row selection in
  Actual/Balances; `3f47bec` refines Scheduled List typography. They follow the
  earlier `a0b7e6e` pilot; current policy/evidence are committed separately. No
  format, dependency, launcher or backup-policy change and no history rewrite.
- This is local pre-publication qualification, not a remote CI or installed-binary
  claim. Matching published-SHA CI and an end-to-end `bk` check with an isolated
  synthetic Git household/local backup remote are separate post-push evidence.
  Operational-household writes are not authorized by this rollout. Physical
  font/terminal/IME and full human acceptance remain unqualified.

## Full-row selection and Scheduled List typography (2026-11-04)

- User requested committing the accepted Balances pilot and continuing. Seven
  reviewed files became local commit `a0b7e6e`; focused Balances checks, formatting,
  full privacy scan and diff checks passed before commit. No push or history edit.
  During the Scheduled work the user explicitly preferred highlighted whole rows
  over marker-only selection. That newer preference supersedes the prior pilots.
- Current follow-up: Actual and Balances Current focused selections use one Active
  span across the interior row, including padding, with separate borders. Inactive
  markers, unselected field hierarchy and exact quantity text remain. Non-account
  Balances configuration errors keep Status; selected unknown accounts retain their
  literal unknown value/state and strong detail reasons, never an inferred zero.
- Scheduled changes are limited to List painting: full-row focused occurrence/Locus
  selection, strong unselected dates/quantity text, ordinary Shape and Chrome column
  headers. `split` and `too wide` remain explicit; inactive overflow is Status.
  Series Calendar, Months, Plan, pace, full detail, keys, action targets, geometry,
  calculations, admission, dependencies and publication behavior are unchanged.
- Static review found two Scheduled display regressions in an intermediate draft:
  fitting Locus labels missed visible escaping, and an exact span boundary could
  lose the old ellipsis. The corrected local helper preserves authoritative whole-
  line `clip_text`, sanitizes spans with `visible` and falls back to plain canonical
  text only when tiny clipping boundaries differ. Owner checks at widths 14/15/16/24
  compare the previous strings; an admitted control-bearing identity remains visibly
  escaped. Follow-up static review found both issues resolved and no blocker.
- Native owner/app checks cover full-row focus and inactive restoration, four normal
  geometries, zero/negative/scaled/unknown/huge amounts, long identities/Measures,
  retained selection, action targets and non-writing paths. Initial focused checks
  exited 1 for old Actual fallback-style expectations, an unabridged 48-column Shape
  assumption and a fixture that left monitoring config undeclared. These expectations
  and the fixture were corrected without changing their old display/safety rules.
- `rtk test ./tools/opam exec -- dune runtest tui/screens/balances/test tui/app/test --force`,
  `rtk test ./tools/check` and `rtk test ./tools/tui --self-check` pass. The build also
  passes. One combined command later exited 1 copying over a read-only Dune-derived
  preview artifact; `install -m 755` fixed only that ignored working copy.
- Public synthetic tmux before/after captures cover Actual, Balances and Scheduled
  List/detail at 120x36, 80x24, 48x14 and 32x9, with Loci focus additionally exercised
  for Actual/Scheduled. Complete plaintext and geometry match; list ANSI differs.
  Book and config checksums remain unchanged. Failed readiness attempts assumed a
  shared Actual header or full period tabs at every width; those were rejected.
  Final captures require the Actuals frame and explicit focus/detail transitions.
- One freshly copied household generation supplies before/after and the existing
  LOAM binary. All three screens at 120x36/80x24 retain complete list/detail text;
  LOAM captures positively show Actual Workspace, Current Balances and Scheduled
  List, not Home. Bounded private review confirms full-interior selection and no
  stale inactive band, consistent with the reference. Private focused-Loci captures
  were not taken; synthetic checks/captures cover them. No accounting/operation-
  parity or physical contrast/IME acceptance is inferred.
- After closing only AI-owned capture processes, original book/config and both
  copies compare identical; `./tools/compare clean-copies`: exit 0. Private material
  remains in ignored scratch. No operational-household writes or TUI session.
  At that trial checkpoint the follow-ups were uncommitted/unpushed and daily `bk`
  remained `2b03863`; they are included in the closing publication qualified above.
  Physical font/terminal/IME and full human acceptance **not executed**.

## Balances Current typography trial (2026-11-04)

- User asked to extend the Actual typography work to another area. Baseline main
  and locally recorded origin/main were clean `2b03863`. Scope: Current rendering
  and its existing owner checks; no dependency, format, palette or font change.
- Exact list amounts use Heading, names remain Plain, list Measures/exact states
  use Chrome, and only the focused selection marker uses Active. Current frame
  titles omit `[active]`; active frames and inactive selection markers remain.
  Detail Amount intentionally emphasizes its unit too, as one reading unit;
  separate Measure metadata remains quiet. Unsupported amounts/states/reasons
  and overflow placeholders use Status, never inferred zeros or partial digits.
  Accounting, text order, geometry, footer, navigation, Observe/Print and save
  semantics stay unchanged. Static review found no source-safety blocker; its
  question about the detail unit was resolved as that intentional distinction.
- Existing focused owner checks passed before editing. Added tests cover exact
  zero, negative/scale-2 amounts, unknown, huge values, long/unidentifiable units,
  malformed display config, marker-only selection, focus, span/text agreement,
  and unchanged Observe/Print/Accounting. Test cell widths are fixture-only
  ASCII/box/CJK widths, not full Notty or physical-font qualification.
- Initial focused checks exited 1: compact Measure styling was missing, then
  test assumptions overestimated the old 32-column footer and expected an
  unsupported value when its unit could not be identified. The compact style
  was corrected and those two expectations now preserve the pre-existing
  display/safety behavior. Final focused owner checks pass.
- `rtk test ./tools/check` and `rtk test ./tools/tui --self-check`: exit 0,
  including existing native Notty cell-width/geometry checks. RTK summarizes
  the existing commands; it does not replace them.
- Final `rtk test ./tools/opam exec -- dune runtest tui/screens/balances/test --force`,
  `./tools/format --check`, `./tools/privacy-scan --all` and `git diff --check`:
  exit 0. Formatting was applied only to the two changed OCaml files.
- Public synthetic tmux before/after captures cover list/detail at 120x36,
  80x24, 48x14 and 32x9. Excluding intentionally changed frame-title rows, body
  text matches exactly; ANSI presentation differs. Book and display-config
  checksums remain unchanged. The synthetic book is admitted by `--check`.
- One fresh read-only household generation was used for before/after and the
  existing LOAM binary, at 120x36/80x24, list and focused detail. Body text
  matches before/after. Initial synthetic/LOAM readiness conditions were wrong
  (Home menu text was mistaken for LOAM Balances); those attempts were rejected.
  Final captures positively require Current context and inactive selection after
  detail focus. A bounded private review confirmed corrected LOAM Current states.
  Reference differences include marker-only versus row-wide selection, money
  emphasis and existing Shell/Amount-versus-Quanta geometry; no full accounting
  or operation-parity claim. No unknown warning is visible in these latest-copy
  captures; warning style is qualified only by synthetic checks in this pass.
- All AI-owned capture processes are closed. Original book/config and both copies
  compare identical; `./tools/compare clean-copies`: exit 0. Private material stays
  only in ignored scratch. No AI operational-household writes, commit or push.
  Daily `bk` remains `2b03863`; this trial has no pushed-SHA CI claim. Physical
  font/terminal/IME and full human acceptance **not executed**. The user subsequently
  responded favorably and requested committing the trial, then continuing with
  Scheduled. This feedback does not establish exhaustive physical-terminal acceptance.

## bk publication preparation (2026-11-04)

- User request: make the changes available through ordinary `bk`; after inspecting
  its pushed-only launcher, the user explicitly selected committing/pushing the
  entire series, not just the Actual changes. No launcher policy was bypassed.
- Remote HEAD and the starting local main both named `ede3d21`. Independent
  read-only review of all 18 changed files found no blocker; it verified that
  Amount/Book_file/Publication production changes are comments/whitespace only.
  That review did not execute tests or reproduce historical private comparisons.
- Fresh `rtk test ./tools/check`, `rtk test ./tools/tui --self-check`,
  `./tools/format --check`, `./tools/privacy-scan --all` and `git diff --check`:
  exit 0. The first two execute the existing qualification commands; RTK only
  summarizes their output. Private payload did not enter files or commit messages.
- Four scoped source/test commits: `96f6de6` (Amount), `ce55121` (Book_file),
  `5060525` (Publication), `2117aa0` (Actual typography). Policy and evidence are
  published in a following documentation slice. No format or dependency change.
- `/Users/user/.local/bin/bk` delegates to `tools/household`; that script fetches
  `origin/main`, builds its dedicated worktree and keeps the last good binary
  when unavailable. Neither wrapper was changed. This entry records pre-push
  qualification only: matching GitHub CI and an installed-revision/full-launcher
  check are separate post-push evidence, not inferred from local green.
  The operational household was not opened or written during this preparation.
- Post-push completion: `2b038634f63db2749e0c6eaad21e3aaffc8f8d0f` was published.
  [Matching CI](https://github.com/shumoku88-bit/bakhlo/actions/runs/41754910195)
  concluded success, including Linux PTY; `gh run watch 41754910195 --exit-status`
  exited 0. The real `bk` wrapper fetched/built this revision using an isolated
  synthetic Git household and local bare backup remote. Updated Actual was visible;
  exit 0, book checksum unchanged, synthetic repository clean. Main, origin/main,
  dedicated run worktree and installed stamp matched. No operational-household TUI
  session in that deployment. Existing Actions deprecation annotations were non-fatal.

## Actual headings and width-fitted help (2026-11-03)

- Follow-up after the user reported a slight improvement and asked to continue.
  Baseline is the prior uncommitted typography pilot on `ede3d21`; snapshots of
  the two Actual files and the baseline binary were kept in ignored scratch.
  Earlier work is preserved. Changes remain in Actual rendering/checks only:
  no geometry, accounting, bindings, publication, theme, font or dependency change.
- Pane titles omit redundant `[active]` text and the duplicate sort code. The
  focused frame and active/inactive selection markers remain. Browse/detail/search
  choose complete two-row legends that fit the native cell width; compact legends
  prioritize important hints rather than being a full key reference. All bindings
  remain available, including hints omitted at narrower widths.
- Window warnings lead with the cause, not date metadata. Long causes explicitly
  truncate while reserving the retained-draft suffix. Review found and corrected
  an initial lost draft badge and an omitted 48-column period hint; regression
  checks cover both. Final read-only source review found no blocker; no tests were
  executed by that reviewer.
- Added checks for seven footer widths (120, 80, 48, 32, 24, 1 and 0), three modes,
  two-row/cell bounds, complete key groups and exit/open hints at supported widths,
  period discovery from 48 columns, short titles and unchanged selection. Four
  native-width warning checks also require the complete short cause first and a
  retained-draft suffix under long warning truncation.
- `./tools/opam exec -- dune runtest tui/app/test --force` failed against the old
  display (exit 1, `typography-warning-cause-first`) and passes after the changes
  (exit 0). Final `./tools/check`, `./tools/tui --self-check`,
  `./tools/format --check` and `git diff --check`: exit 0. The pinned formatter
  was applied only to the two Actual OCaml files. Logs are in ignored scratch.
- Synthetic tmux before/after captures at 120x36, 80x24, 48x14 and 32x9 cover
  browse, detail and search. Final accepted captures use fresh starts/mode checks:
  body rows compare identical, while titles/help intentionally differ; book checksum
  is unchanged. Early scripts were discarded after startup input timing, Escape/i
  batching, search's pane reset and a clipped old search hint invalidated mode
  assumptions. Those attempts are not evidence for the final comparison.
- `./tools/compare refresh` produced a fresh household generation. Bounded private
  capture review observed less crowded titles and complete two-row help at normal
  and compact widths, retaining existing LOAM differences. A later identity check
  found current config different from both agreeing comparison copies (book still
  identical). No original was rewritten: refresh was repeated, then all three
  Actual modes were recaptured at 120x36/80x24 on the new generation. Body rows
  compare identical before/after; LOAM opens its own same-generation copy. No
  claim of full visual/operation parity or exhaustive help discovery.
- After closing only AI-owned processes, original book/config and both copies
  compare identical. `./tools/compare clean-copies`: exit 0. Private captures and
  configuration diagnostics stay only in ignored scratch; no private payload or
  data counts are recorded here. No AI household writes, commit or push; daily
  `bk` has not adopted these edits. Physical-terminal/font/IME and full human
  acceptance, persistent acknowledgement and power-loss checks **not executed**.

## Actual typography pilot (2026-11-03)

- User-approved first typography slice, limited to Actual. HEAD/local `origin/main`
  stayed `ede3d21`; the earlier literate-style edits were preserved. Only Actual's
  rendering and owner checks changed in production/test code. No new style enum,
  renderer, palette, font setting, dependency, geometry, key or publication path.
- Existing spans separate day dates and exact amounts (Heading) from counts,
  column/window labels (Chrome) and descriptions (Plain). Amount-order dates are
  context, not group headings. Active selection reverses only the existing three-cell
  marker; inactive selection keeps its existing marker. Aligned and wrapped detail
  amounts are emphasized; window warnings use Status, not subdued context styling.
  Off-screen entry formatting remains lazy. No runtime-performance claim was measured.
- Owner checks exercise 120x36, 80x24, 48x14 and 32x9 with the native cell-width
  function: styled text/span consistency, localized active and retained inactive
  selection, focus round-trips, day/count/money roles, period/context and warnings,
  Japanese clipping, amount-order columns, huge fully scrollable wrapped quantities
  and separate-Measure summaries. Existing assertions remain, with the old whole-row
  heading assertion updated to check the date span itself.
- Initial `./tools/opam exec -- dune runtest tui/app/test --force` attempts exited 1:
  direct Uutf/Z references were unavailable in this check library; test-only code was
  rewritten using standard UTF-8 and Book amount APIs, without adding dependencies.
  Further test failures exposed a byte-width stand-in used by an old assertion and
  an expectation of an unabridged narrow Description. The old date-heading assertion
  now reads the span directly, while the new tests use actual cell widths and check
  the visible description prefix. No production gate or money expectation was weakened.
  Final focused command: exit 0.
- Pinned formatter applied only to the two changed OCaml files. Final
  `./tools/format --check`, `git diff --check`, `./tools/check` and
  `./tools/tui --self-check`: exit 0, including synthetic safety/recovery checks and
  the standard changed-file privacy scan. Logs are in ignored scratch.
- Synthetic before/after tmux captures at all four sizes: plain text and geometry
  compare byte-identical; ANSI captures differ as intended. Light and Dark captures
  at 120x36/80x24 have the same text too. The synthetic book's checksum is unchanged.
  Initial capture attempts used an incorrect tmux window index; verified captures
  were taken after discovering the actual pane. These are PTY/ANSI checks, not
  physical-font acceptance; no claim fixes the separate terminal-palette remapping issue.
- `./tools/compare refresh`: exit 0, selecting one fresh household generation.
  Before/after Actual and Details text at 120x36/80x24 compares identical. LOAM was
  opened read-only on its own copy of that same generation. Independent private-capture
  review observed the intended weight/marker changes and no new clipping; existing
  LOAM differences (per-row dates, full-row selection, top controls and compact Details)
  remain. This is bounded comparison, not full visual/operation parity. No private
  payload, dates, quantities, identities or data counts are recorded here.
- Original book/config and both comparison copies were checked byte-identical;
  only AI-owned comparison processes were closed, followed by
  `./tools/compare clean-copies` (exit 0). The LOAM process needed its owned tmux
  session closed after Ctrl-Q did not exit it. Private captures remain only in ignored
  scratch. No household edits, commit or push; daily `bk` has not adopted these edits.
  Physical-terminal/font/IME and human acceptance, persistent acknowledgement and
  physical power-loss checks **not executed**.

## Publication as a readable review boundary (2026-11-03)

- Continued the approved reading style in `tui/shell/publication.ml` and `.mli`.
  HEAD/local `origin/main` remained `ede3d21`; the existing Amount/Book_file,
  AGENTS and evidence edits were preserved. Production changes are comments only:
  no request, admission, publication, reload, API or storage behavior changed.
- A plan reviewed against A, followed by a session/file at B, introduces the
  difference between `Conflict_base_changed` and the writer's `Conflict`.
  Commentary also explains retained uncertain evidence, one-save batches,
  real reversals, session-only section updates, Locus/role admission in one
  save and why pending evidence precedes edit-staleness checks during reload.
- Added `check_reviewed_base` to the existing
  `tui/scenarios/book_publication_recovery_checks.ml` runner. A role update
  interrupted at `Replaced` supplies actual uncertain evidence. Cancellation
  from an old session yields file conflict; a current session with the old
  reviewed base yields base conflict. Reload with that evidence confirms B;
  without it the same stale Plan_edit yields `Edit_base_changed`. Book bytes
  remain unchanged after each refused request and reload. Existing landed and
  unlanded recovery scenarios remain unchanged.
- `./tools/opam exec -- dune runtest tui/app/test --force`: exit 0 before and
  after the edit, including the new scenario's PASS line after the edit.
  The subsequent `./tools/format --check` initially exited 1 for one match layout
  in the changed scenario; that layout alone was corrected. Final
  `./tools/format --check`, `git diff --check`, `./tools/check` and
  `./tools/tui --self-check`: exit 0. Full checks include architecture,
  synthetic recovery/UI checks and the standard changed-file privacy scan.
- Independent read-only review found no blocker and passed a scoped
  `git diff --check` (exit 0); it did not run tests. Byte equality alone cannot
  exclude same-byte rewrites; the read-only claim also follows the inspected
  reload path. No household edits, commit or push. Latest-data paired comparison,
  physical-terminal/IME acceptance, persistent acknowledgement and physical
  power-loss checks **not executed**.

## Book file as a readable save story (2026-11-03)

- Continued the user-approved Amount reading style in `store/book_file.ml` and
  `.mli`. Baseline HEAD/local `origin/main` was `ede3d21`, with the prior Amount,
  test and evidence edits still uncommitted; those edits were preserved.
- The opening example distinguishes an uncertain save from a refusal. The
  numbered reading path explains file identity, the stable lock name, flushing
  contents versus directory names, stale sessions, hard-linking the old book
  before replacement, conservative outcomes and fresh recovery copies.
  `full_sync_stubs.c`'s comment now describes flush requests without claiming
  physical power-loss qualification. All production changes are comments only;
  no syscall order, algorithm, API, format or dependency changed.
- One new expect test in `test/book_file_tests.ml` predicts a revision without
  writing, injects `Sys_error` at `Replaced`, checks the retained candidate
  revision, confirms exactly one added entry by reload and verifies that repeating
  from the old session conflicts without changing the reloaded revision. This
  is a deterministic interruption example, not persistent acknowledgement or
  physical power-loss evidence. Existing interruption/SIGKILL checks are unchanged.
- `./tools/opam exec -- dune runtest test --force`: exit 0 before and after the
  edit, including the new example. The first subsequent `./tools/format --check`
  exited 1 for doc-comment/test layout in two changed files; only those layouts
  were corrected. Final `./tools/format --check`, `git diff --check`,
  `./tools/check` and `./tools/tui --self-check`: exit 0. The full check includes
  architecture checks, synthetic recovery/UI scenarios and a changed-file privacy scan.
- Independent read-only source/diff review found no blocker; it did not run tests.
  The approved literate-style preference is recorded in AGENTS. No household edits,
  commit or push. Latest-data paired comparison, physical-terminal/IME acceptance,
  persistent acknowledgement and physical power-loss checks **not executed**.

## Amount as a small readable chapter (2026-11-03)

- User request: try a bounded literate-programming-style pass, explaining why
  the code is needed rather than paraphrasing each instruction. Baseline was
  clean `ede3d21` (also the locally recorded `origin/main`).
- `household/amount.ml` now reads from receipt examples through integer display,
  notation/grouping, exact expression evaluation and literal/signed input rules.
  `.mli` gives the caller's unit/scale contract and concrete accepted/refused
  examples. Existing English comment conventions and the pinned layout are retained.
  Production changes are comments only: no algorithm, API, storage or dependency change.
- Two added expect tests in `test/amount_boundary_tests.ml` exercise the examples
  through Book: exact intermediate thirds, final indivisibility, left associativity,
  zero division/nonpositive results, literal versus expression precision, full-width
  notation and malformed comma grouping. Existing entry-policy and scales 0..9
  round-trip checks remain unchanged.
- `./tools/opam exec -- dune runtest test --force`: exit 0 before and after the edit;
  both new tests passed after the edit. `./tools/check` and
  `./tools/tui --self-check`: exit 0, including architecture checks, synthetic
  recovery/UI scenarios and the standard changed-file privacy scan in `tools/check`.
  `./tools/format --check` and `git diff --check`: exit 0.
- Independent read-only source/diff review found no blocker in prose accuracy or
  test expectations; that review did not execute tests. No household edits, commit
  or push. Latest-data paired comparison, physical-terminal/IME acceptance and
  power-loss testing **not executed**; this pass makes no new claim about them.

## Readability: named balance groups and comments (2026-11-02)

- Daily Pace Pool's internal `0`/`1`/`2` support groups are named variants.
  Local names describe groups and Loci rather than routes; comments explain why
  grouping preserves first appearance and why group order is not reliability.
  No public API, storage format, dependency or intended UI behavior change.
- Removed a duplicated I&E comment and corrected the terminal loop's layout.
- Added synthetic painted-row assertions at widths 120, 80 and 32: zero-origin,
  opening and observed groups retain their order; first appearance wins over
  alphabetical/admitted order within a group, unused supported Loci follow,
  and unknown balances are excluded. These assertions and the existing Pool
  review/save checks passed during both suite runs.
- `./tools/format --check`: exit 0 after running sequentially (the first attempt
  overlapped the TUI checks and exited 1 because another Dune instance was running).
  `git diff --check`: exit 0.
- `./tools/tui --self-check` and `./tools/check`: both exit 1 at the unchanged
  `reports_integration_checks.ml:310`, `flow-shift-back`. That test expects
  September/October 2026 for relative month navigation; the report uses the
  real current day. At that point the suites were not green; the final privacy-scan step
  of `tools/check` was not reached. A separate `./tools/privacy-scan` over the six
  changed files passed (exit 0, no match). No test expectation was weakened.
- Initial pass: latest-data paired comparison, physical-terminal/IME acceptance
  and power-loss testing **not executed**. Household data was not accessed; no
  commit or push during that pass.
- Follow-up at the user's request to commit in small slices: terminal layout is
  isolated in `15920f8`; report scenario date assumptions in `b8c1a9f`. The latter
  checks the actual current month and its previous month, and gives Stock–Flow
  a configured cycle containing today. January's year transition is handled in
  the expectation calculation but was not separately executed.
  Before the second fix, the suite reached Stock–Flow and refused because its
  October-only boundary did not contain today. No production date logic changed.
- Follow-up `./tools/format --check`, `./tools/check` and
  `./tools/tui --self-check`: exit 0, including Pool assertions, report scenarios
  and privacy scan. Independent read-only review
  found no blocker in the code/test diff; it did not execute tests.
- Pushed 2026-11-02 after `./tools/privacy-scan --all` (no match), `./tools/check`
  and `./tools/tui --self-check` (exit 0) on `bc80bd1`; matching CI passed
  ([run 41419809527](https://github.com/shumoku88-bit/bakhlo/actions/runs/41419809527)).
  Latest-data paired comparison, human/IME and power-loss checks remain **not executed**.
